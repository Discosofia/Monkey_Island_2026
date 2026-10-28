--!strict
-- Caído → reanimación o reaparición (GDD §6.2, Fase 1.5).
--
--   - Un golpe mortal no mata: el jugador queda Caído (se arrastra, no ataca ni recolecta).
--   - Un aliado lo reanima manteniendo pulsado su aviso "Reanimar". Con un kit de reanimación (del
--     médico) se gasta uno: basta con pulsar (RoleController) y se levanta con más vida.
--   - Si nadie llega a tiempo (Config.Life.DownedSeconds), o si el propio caído se rinde
--     (Remotes.Surrender, a partir de Config.Life.SurrenderAfterSeconds), deja una mochila con parte
--     de sus materiales donde cayó y reaparece al momento en su cama o en el Basecamp, con toda la
--     vida. Ya no hay fase de Espíritu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchStats = require(ReplicatedStorage.Shared.MatchStats)
local PlotStructures = require(ReplicatedStorage.Shared.Data.PlotStructures)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local BasecampService = require(script.Parent.BasecampService)
local BuildingService = require(script.Parent.BuildingService)
local InventoryService = require(script.Parent.InventoryService)
local TelemetryService = require(script.Parent.TelemetryService)
local CombatText = require(ServerScriptService.Combat.CombatText)

local VISUALS = { "RevivePrompt", "DownedBillboard", "DownedHighlight" }
-- Ítem que se gasta al reanimar y levanta al momento con más vida (Config.Life.ReviveKit*).
local REVIVE_KIT = "ReviveKit"

local LifeService = {}

-- Cambia con cada caída: así un temporizador viejo no hace reaparecer a quien ya se levantó.
local downedToken: { [Player]: number } = {}
-- Cuándo cayó cada jugador (os.clock), para no dejarle rendirse nada más caer.
local downedAt: { [Player]: number } = {}
local respawnListeners: { (player: Player) -> () } = {}
local backpacks: Folder? = nil

-- Llama a "callback" cada vez que un caído reaparece sin que lo reanimen (SurvivalService le sube el
-- hambre y la sed y le quita la fiebre). Regístralo en Init.
function LifeService.onRespawned(callback: (player: Player) -> ())
	table.insert(respawnListeners, callback)
end

local function characterParts(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (character and humanoid and root and root:IsA("BasePart")) then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function setState(player: Player, state: LifeState.State)
	player:SetAttribute(LifeState.ATTRIBUTE, state)
end

local function clearVisuals(character: Model)
	for _, name in VISUALS do
		local visual = character:FindFirstChild(name, true)
		if visual then
			visual:Destroy()
		end
	end
end

-- Salto normal, guardado al caer para restaurarlo después. La velocidad (gateo incluido) la pone el
-- cliente (CombatClient/Movement).
local function restoreMovement(humanoid: Humanoid)
	local jumpHeight = humanoid:GetAttribute("NormalJumpHeight")
	local jumpPower = humanoid:GetAttribute("NormalJumpPower")
	humanoid.JumpHeight = if typeof(jumpHeight) == "number" then jumpHeight else 7.2
	humanoid.JumpPower = if typeof(jumpPower) == "number" then jumpPower else 50
end

local function spawnPoint(): CFrame
	local spawns = {}
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			table.insert(spawns, descendant)
		end
	end
	if #spawns > 0 then
		local spawn = spawns[math.random(1, #spawns)]
		return spawn.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(BasecampService.getCenter())
end

-- Mochila en el suelo con parte de los materiales; solo su dueño puede recogerla.
local function dropBackpack(player: Player, position: Vector3)
	local contents: { [string]: number } = {}
	local total = 0
	for itemId, item in Items do
		-- El equipo ("keep", la antorcha) no se pierde.
		local amount = if item.keep then 0 else math.floor(Inventory.count(player, itemId) * Config.Life.DropFraction)
		if amount > 0 and InventoryService.remove(player, itemId, amount) then
			contents[itemId] = amount
			total += amount
		end
	end
	if total == 0 then
		return
	end

	local bag = Instance.new("Part")
	bag.Name = `Mochila de {player.DisplayName}`
	bag.Size = Vector3.new(2, 2.2, 1.4)
	bag.Color = Color3.fromRGB(120, 85, 50)
	bag.Material = Enum.Material.Fabric
	bag.Anchored = true
	bag.CanCollide = false
	bag.Position = position
	bag:SetAttribute("OwnerUserId", player.UserId)
	bag.Parent = backpacks

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recoger"
	Strings.setText(prompt, "ObjectText", "Mochila de {player}", { player = player.DisplayName })
	prompt.HoldDuration = 1.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = bag
	prompt.Triggered:Connect(function(picker: Player)
		if picker ~= player or not LifeState.isAlive(picker) then
			Remotes.Notify:FireClient(picker, "Solo su dueño puede recoger esta mochila.")
			return
		end
		for itemId, amount in contents do
			InventoryService.collect(player, itemId, amount)
		end
		bag:Destroy()
	end)
end

-- Nadie lo ha reanimado (o se ha rendido): deja la mochila donde cayó y reaparece al momento en su
-- cama o en el Basecamp, con toda la vida.
local function respawnDowned(player: Player, surrendered: boolean)
	local character, humanoid, root = characterParts(player)
	if not (character and humanoid and root) or LifeState.get(player) ~= "Downed" then
		return
	end
	downedToken[player] = (downedToken[player] or 0) + 1
	downedAt[player] = nil
	MatchStats.add(player, MatchStats.DEATHS)
	dropBackpack(player, root.Position - Vector3.new(0, 2, 0))
	clearVisuals(character)
	restoreMovement(humanoid)
	humanoid.Health = humanoid.MaxHealth
	-- Si tiene cama en su parcela (BuildingService), reaparece junto a ella.
	local bed = player:GetAttribute("RespawnCFrame")
	character:PivotTo(if typeof(bed) == "CFrame" then bed else spawnPoint())
	player:SetAttribute("DownedEndsAt", nil)
	setState(player, "Alive")
	for _, listener in respawnListeners do
		task.spawn(listener, player)
	end
	local where = { if typeof(bed) == "CFrame" then Strings.later("en tu cama") else Strings.later("en el Basecamp") }
	Remotes.Notify:FireClient(
		player,
		if surrendered
			then Strings.later("🏳️ Te has rendido: reapareces {where}. Tu mochila se ha quedado donde caíste")
			else Strings.later(
				"☠️ Nadie te reanimó a tiempo: reapareces {where}. Tu mochila se ha quedado donde caíste"
			),
		{ where = where }
	)
end

local function revive(player: Player, rescuer: Player)
	local character, humanoid = characterParts(player)
	if not (character and humanoid) or LifeState.get(player) ~= "Downed" then
		return
	end
	downedToken[player] = (downedToken[player] or 0) + 1
	downedAt[player] = nil
	clearVisuals(character)
	restoreMovement(humanoid)
	-- El kit de reanimación y "Segundo aliento" (talento del médico) levantan con más vida.
	local kit = InventoryService.remove(rescuer, REVIVE_KIT, 1)
	local base = if kit then Config.Life.ReviveKitHealthFraction else Config.Life.ReviveHealthFraction
	local fraction = math.min(1, base + Progression.perk(rescuer, "ReviveHealth"))
	local before = humanoid.Health
	humanoid.Health = math.max(1, humanoid.MaxHealth * fraction)
	player:SetAttribute("DownedEndsAt", nil)
	setState(player, "Alive")
	CombatText.heal(player, humanoid.Health - before, false, rescuer)
	Sfx.play("Revive", character.PrimaryPart or character)
	MatchStats.add(rescuer, MatchStats.REVIVES)
	Remotes.Notify:FireClient(player, "💚 {player} te ha reanimado", { player = rescuer.DisplayName })
	Remotes.Notify:FireClient(
		rescuer,
		if kit
			then Strings.later("🧰 Has reanimado a {player} con un kit ({n} más)")
			else Strings.later("💚 Has reanimado a {player}"),
		{ player = player.DisplayName, n = Inventory.count(rescuer, REVIVE_KIT) }
	)
end

-- Panel de pruebas (DebugService): el caído vuelve a la vida al momento, donde está y con toda la
-- vida. Devuelve false si ya estaba vivo.
function LifeService.debugRevive(player: Player): boolean
	local character, humanoid = characterParts(player)
	if not (character and humanoid) or LifeState.get(player) ~= "Downed" then
		return false
	end
	-- Anula la reaparición pendiente.
	downedToken[player] = (downedToken[player] or 0) + 1
	downedAt[player] = nil
	clearVisuals(character)
	restoreMovement(humanoid)
	humanoid.Health = humanoid.MaxHealth
	player:SetAttribute("DownedEndsAt", nil)
	setState(player, "Alive")
	Sfx.play("Revive", character.PrimaryPart or character)
	return true
end

-- Llamado por CombatService ante un golpe mortal. "cause": qué le ha tumbado, para la telemetría
-- (TelemetryService.causeOf, "PvP", "Hambre").
-- Segundos caído antes de reaparecer: menos con la cama de la parcela en pie (Data/PlotStructures).
local function downedSeconds(player: Player): number
	local level = BuildingService.plotLevel(player, "Bed")
	local factor = if level > 0 then PlotStructures.Bed.levels[level].downedFactor else nil
	return Config.Life.DownedSeconds * (factor or 1)
end

function LifeService.down(player: Player, cause: string)
	local character, humanoid, root = characterParts(player)
	if not (character and humanoid and root) or not LifeState.isAlive(player) then
		return
	end
	TelemetryService.downed(player, cause)
	humanoid.Health = 1
	humanoid:UnequipTools()
	humanoid:SetAttribute("NormalJumpHeight", humanoid.JumpHeight)
	humanoid:SetAttribute("NormalJumpPower", humanoid.JumpPower)
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	local seconds = downedSeconds(player)
	player:SetAttribute("DownedEndsAt", Workspace:GetServerTimeNow() + seconds)
	downedAt[player] = os.clock()
	setState(player, "Downed")

	local highlight = Instance.new("Highlight")
	highlight.Name = "DownedHighlight"
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.FillTransparency = 0.5
	highlight.Parent = character

	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "DownedBillboard"
		billboard.Size = UDim2.fromOffset(90, 36)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = Strings.later("🆘 Caído")
		label.TextColor3 = Color3.fromRGB(255, 110, 110)
		label.TextStrokeTransparency = 0.2
		label.Font = Enum.Font.BuilderSansBold
		label.TextScaled = true
		label.Parent = billboard
	end

	-- Aviso para que los aliados lo reanimen (el propio caído lo oculta en su pantalla).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Reanimar"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = Config.Life.ReviveHoldSeconds
	prompt.MaxActivationDistance = Config.Life.ReviveDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(rescuer: Player)
		if rescuer ~= player and LifeState.isAlive(rescuer) then
			revive(player, rescuer)
		end
	end)

	Remotes.Notify:FireClient(player, "🆘 ¡Has caído! Un aliado puede reanimarte.")
	local token = (downedToken[player] or 0) + 1
	downedToken[player] = token
	task.delay(seconds, function()
		if downedToken[player] == token then
			respawnDowned(player, false)
		end
	end)
end

-- El caído se rinde (mantener pulsado "Rendirse", LifeController): reaparece ya, con la mochila.
local function onSurrender(player: Player)
	local since = downedAt[player]
	if LifeState.get(player) ~= "Downed" or not since then
		return
	end
	if os.clock() - since < Config.Life.SurrenderAfterSeconds then
		return
	end
	respawnDowned(player, true)
end

local function onCharacterAdded(player: Player)
	-- Si el personaje se recrea (por ejemplo, al caer al vacío), vuelve vivo.
	if LifeState.get(player) == "Downed" then
		downedToken[player] = (downedToken[player] or 0) + 1
		downedAt[player] = nil
		player:SetAttribute("DownedEndsAt", nil)
		setState(player, "Alive")
	end
end

function LifeService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Mochilas"
	folder.Parent = Workspace
	backpacks = folder

	Remotes.Surrender.OnServerEvent:Connect(onSurrender)

	local function onPlayer(player: Player)
		setState(player, "Alive")
		player.CharacterAdded:Connect(function()
			onCharacterAdded(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		downedToken[player] = nil
		downedAt[player] = nil
		-- Sus mochilas ya no las puede recoger nadie.
		for _, bag in folder:GetChildren() do
			if bag:GetAttribute("OwnerUserId") == player.UserId then
				bag:Destroy()
			end
		end
	end)
end

return LifeService
