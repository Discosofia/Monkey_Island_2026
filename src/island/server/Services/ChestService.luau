--!strict
-- Cofre de la parcela permanente (Fase 12, P4; Shared/Plot "chest"). Lo guardado está en el perfil del
-- dueño, así que viaja con él de una partida a otra; lo que se queda en la Bolsa se pierde al acabar.
--   - Solo se usa con el cofre en pie (BuildingService.plotLevel; roto, su aviso se apaga) y estando cerca.
--   - Guardar (Remotes.ChestStore): solo el dueño, de su Bolsa a lo privado o a lo compartido. Solo lo
--     "storable" de Data/Items y hasta llenar las casillas de su nivel (Config.Plot.ChestSlots).
--   - Sacar (Remotes.ChestTake): el dueño, de las dos partes; los demás de la partida, solo de lo
--     compartido y sin límite. Va a la Bolsa de quien lo coge, nunca a su perfil, y el dueño recibe un aviso.
--   - Sin esperas entre comprobar y cambiar. Cuando lo coge otro, primero se resta del perfil del dueño y
--     se espera a que quede guardado (PlayerData.saveNow) antes de dárselo: si el servidor cae en medio se
--     puede perder, pero nunca duplicar. Si no se guarda, vuelve al cofre.
--   - Si el dueño sale, su cofre se va con su parcela (BuildingService.releasePlayer). El bloqueo de sesión
--     de PlayerData impide tocar el mismo perfil desde dos servidores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Plot = require(ReplicatedStorage.Shared.Plot)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local BuildingService = require(script.Parent.BuildingService)
local InventoryService = require(script.Parent.InventoryService)

-- Margen extra (studs) sobre la distancia del aviso, por el retraso de la red.
local DISTANCE_TOLERANCE = 4

local ChestService = {}

local canUse = RequestCooldown.new(Config.Plot.ChestCooldownSeconds)
-- Quien espera a que se guarde lo que ha cogido de un cofre ajeno (una cosa cada vez).
local waiting: { [Player]: boolean } = {}

local function itemText(itemId: string, amount: number): string
	local item = Items[itemId]
	return `{item.icon} {amount} {item.name}`
end

-- El cofre en pie de "owner" si "player" está vivo y a su lado; si no, nil.
local function chestInReach(owner: Player, player: Player): Model?
	local model = BuildingService.plotStructure(owner, "Chest")
	if not (model and model.PrimaryPart) or BuildingService.isBroken(model) or not LifeState.isAlive(player) then
		return nil
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local distance = (root.Position - (model.PrimaryPart :: BasePart).Position).Magnitude
	return if distance <= Config.Crafting.UseDistance + DISTANCE_TOLERANCE then model else nil
end

-- Cantidad pedida por el cliente: un entero positivo, o nil.
local function validAmount(amount: any): number?
	if typeof(amount) ~= "number" or amount ~= amount or amount < 1 then
		return nil
	end
	return math.floor(math.min(amount, 1e6))
end

local function onStore(player: Player, itemId: any, amount: any, part: any)
	local count = validAmount(amount)
	if typeof(itemId) ~= "string" or not count or not table.find(Plot.CHEST_PARTS, part) or not canUse(player) then
		return
	end
	local item = Items[itemId]
	local profile = PlayerData.get(player)
	if not (item and profile and chestInReach(player, player)) then
		return
	end
	if not item.storable then
		Remotes.Notify:FireClient(player, `{item.icon} {item.name} no se puede guardar en el cofre`)
		return
	end
	local state = Plot.normalize(profile.plot)
	local level = BuildingService.plotLevel(player, "Chest")
	local room = Plot.roomFor(state, level, part, itemId)
	count = math.min(count, Inventory.count(player, itemId), room)
	if count <= 0 then
		if room <= 0 then
			Remotes.Notify:FireClient(player, `📦 El cofre está lleno ({Plot.chestSlots(level)} casillas)`)
		end
		return
	end
	-- Desde aquí no hay esperas: se quita de la Bolsa y se suma al cofre en el mismo paso.
	InventoryService.remove(player, itemId, count)
	PlayerData.update(player, function(current)
		local plot = Plot.normalize(current.plot)
		local stored = (plot.chest :: any)[part] :: { [string]: number }
		stored[itemId] = (stored[itemId] or 0) + count
		current.plot = plot :: any
	end)
end

-- Resta "count" de "itemId" de la parte "part" del cofre de "owner" (o suma, con un número negativo).
local function changeStored(owner: Player, part: string, itemId: string, count: number)
	PlayerData.update(owner, function(current)
		local plot = Plot.normalize(current.plot)
		local stored = (plot.chest :: any)[part] :: { [string]: number }
		local left = (stored[itemId] or 0) - count
		stored[itemId] = if left > 0 then left else nil
		current.plot = plot :: any
	end)
end

local function onTake(player: Player, ownerUserId: any, part: any, itemId: any, amount: any)
	local count = validAmount(amount)
	if typeof(ownerUserId) ~= "number" or typeof(itemId) ~= "string" or not count or not Items[itemId] then
		return
	end
	if not table.find(Plot.CHEST_PARTS, part) or not canUse(player) then
		return
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	local profile = if owner then PlayerData.get(owner) else nil
	if not (owner and profile and chestInReach(owner, player)) then
		return
	end
	local isOwner = owner == player
	if part ~= "shared" and not isOwner then
		return
	end
	if waiting[player] then
		Remotes.Notify:FireClient(player, "📦 Espera: aún se está guardando lo anterior")
		return
	end
	local stored = ((Plot.normalize(profile.plot).chest :: any)[part] :: { [string]: number })[itemId] or 0
	count = math.min(count, stored)
	if count <= 0 then
		return
	end
	-- Sin esperas: se resta del cofre en el mismo paso en que se comprueba.
	changeStored(owner, part, itemId, count)
	if isOwner then
		InventoryService.add(player, itemId, count)
		return
	end
	-- De un cofre ajeno: el objeto no se da hasta que el perfil del dueño queda guardado sin él. Con datos
	-- temporales (sin DataStore) no hay nada que guardar ni que duplicar.
	waiting[player] = true
	task.spawn(function()
		local saved = not PlayerData.isSaveable(owner) or PlayerData.saveNow(owner)
		waiting[player] = nil
		if not saved then
			changeStored(owner, part, itemId, -count)
			if player.Parent then
				Remotes.Notify:FireClient(player, "📦 No se ha podido coger: inténtalo otra vez")
			end
			return
		end
		if not player.Parent then
			-- Se ha ido mientras esperaba: vuelve al cofre (sin darlo, no hay duplicado).
			changeStored(owner, part, itemId, -count)
			return
		end
		InventoryService.add(player, itemId, count)
		if owner.Parent then
			Remotes.Notify:FireClient(
				owner,
				`📦 {player.DisplayName} ha cogido {itemText(itemId, count)} de tu cofre compartido`
			)
		end
	end)
end

-- Aviso de abrir en el cofre de una parcela (todos lo ven), apagado mientras está roto: así sale el de
-- repararlo (PlotService), que usa la misma tecla.
local function addPrompt(owner: Player)
	local model = BuildingService.plotStructure(owner, "Chest")
	local anchor = if model then model.PrimaryPart else nil
	if not (model and anchor) or anchor:FindFirstChild(Plot.CHEST_PROMPT) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Plot.CHEST_PROMPT
	prompt.ActionText = "Abrir"
	prompt.ObjectText = `📦 Cofre de {owner.DisplayName}`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Crafting.UseDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = not BuildingService.isBroken(model)
	prompt:SetAttribute("OwnerUserId", owner.UserId)
	prompt.Parent = anchor
	model:GetAttributeChangedSignal("Broken"):Connect(function()
		prompt.Enabled = not BuildingService.isBroken(model)
	end)
end

function ChestService:Init()
	BuildingService.onPlotBuilt(addPrompt)
end

function ChestService:Start()
	Remotes.ChestStore.OnServerEvent:Connect(onStore)
	Remotes.ChestTake.OnServerEvent:Connect(onTake)
	Players.PlayerRemoving:Connect(function(player)
		waiting[player] = nil
	end)
end

return ChestService
