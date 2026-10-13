--!strict
-- Hambre, sed y regeneración de vida (GDD §6.1, Fase 2.1).
--   - Hambre y sed (atributos "Hunger" y "Thirst" del Player, de 0 a 100) bajan con el tiempo
--     mientras el jugador está vivo. A 0, cada una quita vida; un golpe "mortal" deja caído.
--   - La vida solo se regenera con hambre y sed altas y sin daño reciente (el script de
--     regeneración de Roblox está desactivado: ver src/island/character/Health.server.luau).
--   - Comer (Remotes.Eat): el servidor elige la comida que más llena de las que lleva el jugador.
--   - Beber (Remotes.Drink): el servidor comprueba que haya agua del terreno cerca.
--   - Al reaparecer tras ser Espíritu, hambre y sed suben al menos a Config.Survival.RespawnMinStat.
-- La estamina es del cliente (Client/Stamina.luau): solo afecta a correr y esquivar.
-- Fase 2.6: fiebre del mono ("Fever"). Baja sola muy despacio; a 100 quita vida. Al reaparecer como
-- Espíritu se cura. Los mordiscos (CombatService) y la carne cruda la suben; el antídoto la quita.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Survival = require(ReplicatedStorage.Shared.Survival)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local InventoryService = require(script.Parent.InventoryService)
local LifeService = require(script.Parent.LifeService)

local TICK_SECONDS = 1

local SurvivalService = {}

local canEat = RequestCooldown.new(Config.Survival.EatCooldownSeconds)
local canDrink = RequestCooldown.new(Config.Survival.DrinkCooldownSeconds)
local lastDamagedAt: { [Player]: number } = {}
local previousState: { [Player]: LifeState.State } = {}
-- Avisos de hambre o sed baja ya mostrados (para no repetirlos cada segundo).
local warned: { [Player]: { [string]: boolean } } = {}

local function setStat(player: Player, attribute: string, value: number)
	player:SetAttribute(attribute, math.clamp(value, 0, Survival.MAX))
end

local function livingHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function warnLow(player: Player, attribute: string, value: number, message: string)
	local flags = warned[player]
	if not flags then
		return
	end
	if value <= Config.Survival.LowThreshold and not flags[attribute] then
		flags[attribute] = true
		Remotes.Notify:FireClient(player, message)
	elseif value > Config.Survival.LowThreshold then
		flags[attribute] = false
	end
end

-- Hambre o sed a 0 quitan vida. Igual que el daño de los monos, no mata: deja caído.
local function starve(player: Player, humanoid: Humanoid, amount: number)
	if humanoid.Health - amount <= 0 then
		LifeService.down(player)
	else
		humanoid:TakeDamage(amount)
	end
end

local function tick(player: Player)
	if not LifeState.isAlive(player) then
		return
	end
	local humanoid = livingHumanoid(player)
	if not humanoid then
		return
	end
	local minutes = TICK_SECONDS / 60
	local hunger = Survival.get(player, Survival.HUNGER) - Config.Survival.HungerPerMinute * minutes
	local thirst = Survival.get(player, Survival.THIRST) - Config.Survival.ThirstPerMinute * minutes
	setStat(player, Survival.HUNGER, hunger)
	setStat(player, Survival.THIRST, thirst)
	warnLow(player, Survival.HUNGER, hunger, "🍖 Tienes hambre: come algo (C o el botón Comer)")
	warnLow(player, Survival.THIRST, thirst, "💧 Tienes sed: bebe en el río (F o el botón Beber)")

	-- Fiebre: baja despacio; a tope quita vida.
	local fever = Survival.fever(player)
	if fever > 0 then
		Survival.addFever(player, -Config.Fever.DecayPerMinute * minutes)
	end
	if fever >= Survival.MAX then
		starve(player, humanoid, Config.Fever.DamagePerSecondAtMax * TICK_SECONDS)
	end
	-- Aviso con fiebre alta (al bajar de 75 se rearma, igual que el de hambre).
	warnLow(
		player,
		Survival.FEVER,
		Survival.MAX - fever,
		"🤒 Tienes fiebre del mono: busca un antídoto (taller del curandero)"
	)

	local empty = (if hunger <= 0 then 1 else 0) + (if thirst <= 0 then 1 else 0)
	if empty > 0 then
		starve(player, humanoid, Config.Survival.StarvationDamagePerSecond * TICK_SECONDS * empty)
		return
	end

	local fed = hunger >= Config.Survival.RegenMinStat and thirst >= Config.Survival.RegenMinStat
	local calm = os.clock() - (lastDamagedAt[player] or -math.huge) >= Config.Survival.RegenDelayAfterDamage
	if fed and calm and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.Survival.RegenPerSecond * TICK_SECONDS)
	end
end

local function onEat(player: Player)
	if not LifeState.isAlive(player) or not livingHumanoid(player) then
		return
	end
	local hunger = Survival.get(player, Survival.HUNGER)
	local thirst = Survival.get(player, Survival.THIRST)
	if hunger >= Survival.MAX - 1 and thirst >= Survival.MAX - 1 then
		Remotes.Notify:FireClient(player, "No tienes hambre ni sed")
		return
	end
	local itemId = Survival.bestFood(player)
	if not itemId or not canEat(player) then
		return
	end
	local food = Items[itemId].food
	if food and InventoryService.remove(player, itemId, 1) then
		setStat(player, Survival.HUNGER, hunger + food.hunger)
		setStat(player, Survival.THIRST, thirst + food.thirst)
		if itemId == "Meat" then
			Survival.addFever(player, Config.Fever.RawMeat)
			Remotes.Notify:FireClient(player, "🤢 La carne cruda sube la fiebre: mejor asarla en la hoguera")
		end
	end
end

local function onDrink(player: Player)
	if not LifeState.isAlive(player) or not canDrink(player) then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) or not Survival.isNearWater(root.Position) then
		return
	end
	setStat(player, Survival.THIRST, Survival.get(player, Survival.THIRST) + Config.Survival.DrinkThirst)
end

-- Al pasar de Espíritu a vivo, hambre y sed no empiezan casi vacías.
local function onLifeStateChanged(player: Player)
	local state: LifeState.State = LifeState.get(player)
	if previousState[player] == "Spirit" and state == "Alive" then
		local minimum = Config.Survival.RespawnMinStat
		setStat(player, Survival.HUNGER, math.max(Survival.get(player, Survival.HUNGER), minimum))
		setStat(player, Survival.THIRST, math.max(Survival.get(player, Survival.THIRST), minimum))
		player:SetAttribute(Survival.FEVER, 0)
	end
	previousState[player] = state
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health: number)
		if health < lastHealth then
			lastDamagedAt[player] = os.clock()
		end
		lastHealth = health
	end)
end

local function onPlayer(player: Player)
	setStat(player, Survival.HUNGER, Survival.MAX)
	setStat(player, Survival.THIRST, Survival.MAX)
	warned[player] = {}
	previousState[player] = LifeState.get(player)
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(function()
		onLifeStateChanged(player)
	end)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function SurvivalService:Start()
	Remotes.Eat.OnServerEvent:Connect(onEat)
	Remotes.Drink.OnServerEvent:Connect(onDrink)

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastDamagedAt[player] = nil
		previousState[player] = nil
		warned[player] = nil
	end)

	while true do
		task.wait(TICK_SECONDS)
		for _, player in Players:GetPlayers() do
			tick(player)
		end
	end
end

return SurvivalService
