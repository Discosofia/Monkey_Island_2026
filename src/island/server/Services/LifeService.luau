--!strict
-- Caído → reanimación → Espíritu → reaparición (GDD §6.2, Fase 1.5).
--
--   - Un golpe mortal no mata: el jugador queda Caído (se arrastra, no ataca ni recolecta).
--   - Un aliado lo reanima manteniendo pulsado su aviso "Reanimar".
--   - Si nadie llega a tiempo, deja una mochila con parte de sus materiales y pasa a Espíritu:
--     no recibe daño y puede marcar enemigos para sus aliados.
--   - El Espíritu reaparece en el Basecamp tras un tiempo que crece con cada caída del día
--     (Config.Life.SpiritSeconds…), o al amanecer si llega antes.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BasecampService = require(script.Parent.BasecampService)
local DayNightService = require(script.Parent.DayNightService)
local InventoryService = require(script.Parent.InventoryService)

local SPIRIT_TRANSPARENCY = 0.65
local VISUALS = { "RevivePrompt", "DownedBillboard", "DownedHighlight", "SpiritHighlight" }

local LifeService = {}

-- Cambia con cada caída: así un temporizador viejo no convierte en Espíritu a quien ya se levantó.
local downedToken: { [Player]: number } = {}
-- Igual para los Espíritus: una reaparición vieja no afecta a una muerte nueva.
local spiritToken: { [Player]: number } = {}
-- Veces que cada jugador ha pasado a Espíritu desde el último amanecer.
local deathsToday: { [Player]: number } = {}
local lastMarkAt: { [Player]: number } = {}
local backpacks: Folder? = nil

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

-- Velocidad y salto normales, guardados al caer para restaurarlos después.
local function restoreMovement(humanoid: Humanoid)
	local walkSpeed = humanoid:GetAttribute("NormalWalkSpeed")
	local jumpHeight = humanoid:GetAttribute("NormalJumpHeight")
	local jumpPower = humanoid:GetAttribute("NormalJumpPower")
	humanoid.WalkSpeed = if typeof(walkSpeed) == "number" then walkSpeed else 16
	humanoid.JumpHeight = if typeof(jumpHeight) == "number" then jumpHeight else 7.2
	humanoid.JumpPower = if typeof(jumpPower) == "number" then jumpPower else 50
end

local function setGhost(character: Model, ghost: boolean)
	for _, descendant in character:GetDescendants() do
		if (descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart") or descendant:IsA("Decal") then
			local part = descendant :: any
			if ghost then
				if part:GetAttribute("NormalTransparency") == nil then
					part:SetAttribute("NormalTransparency", part.Transparency)
				end
				part.Transparency = math.max(part.Transparency, SPIRIT_TRANSPARENCY)
			else
				local normal = part:GetAttribute("NormalTransparency")
				if typeof(normal) == "number" then
					part.Transparency = normal
				end
			end
		end
	end
	if ghost then
		local highlight = Instance.new("Highlight")
		highlight.Name = "SpiritHighlight"
		highlight.FillColor = Color3.fromRGB(140, 220, 255)
		highlight.FillTransparency = 0.6
		highlight.OutlineColor = Color3.fromRGB(200, 240, 255)
		highlight.Parent = character
	end
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
	for itemId in Items do
		local amount = math.floor(Inventory.count(player, itemId) * Config.Life.DropFraction)
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
	prompt.ObjectText = bag.Name
	prompt.HoldDuration = 1.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = bag
	prompt.Triggered:Connect(function(picker: Player)
		if picker ~= player or not LifeState.isAlive(picker) then
			Remotes.Notify:FireClient(picker, "Solo su dueño puede recoger esta mochila.")
			return
		end
		for itemId, amount in contents do
			InventoryService.add(player, itemId, amount)
		end
		bag:Destroy()
	end)
end

local function respawnSpirit(player: Player)
	if LifeState.get(player) ~= "Spirit" then
		return
	end
	spiritToken[player] = (spiritToken[player] or 0) + 1
	local character, humanoid = characterParts(player)
	if character and humanoid then
		clearVisuals(character)
		setGhost(character, false)
		humanoid.Health = humanoid.MaxHealth
		-- Si tiene cama en su parcela (BuildingService), reaparece junto a ella.
		local bed = player:GetAttribute("RespawnCFrame")
		character:PivotTo(if typeof(bed) == "CFrame" then bed else spawnPoint())
	end
	player:SetAttribute("SpiritEndsAt", nil)
	setState(player, "Alive")
	Remotes.Notify:FireClient(player, "☀️ Has vuelto a la vida en el Basecamp")
end

local function becomeSpirit(player: Player)
	local character, humanoid, root = characterParts(player)
	if not (character and humanoid and root) then
		return
	end
	dropBackpack(player, root.Position - Vector3.new(0, 2, 0))
	clearVisuals(character)
	restoreMovement(humanoid)
	humanoid.Health = humanoid.MaxHealth
	setGhost(character, true)

	local deaths = (deathsToday[player] or 0) + 1
	deathsToday[player] = deaths
	local seconds = math.min(
		Config.Life.SpiritSeconds + (deaths - 1) * Config.Life.SpiritExtraSecondsPerDeath,
		Config.Life.SpiritMaxSeconds
	)
	player:SetAttribute("SpiritEndsAt", Workspace:GetServerTimeNow() + seconds)
	setState(player, "Spirit")
	Remotes.Notify:FireClient(player, `👻 Eres un Espíritu. Reaparecerás en el Basecamp en {seconds} s.`)

	local token = (spiritToken[player] or 0) + 1
	spiritToken[player] = token
	task.delay(seconds, function()
		if spiritToken[player] == token then
			respawnSpirit(player)
		end
	end)
end

local function revive(player: Player, rescuer: Player)
	local character, humanoid = characterParts(player)
	if not (character and humanoid) or LifeState.get(player) ~= "Downed" then
		return
	end
	downedToken[player] = (downedToken[player] or 0) + 1
	clearVisuals(character)
	restoreMovement(humanoid)
	humanoid.Health = math.max(1, humanoid.MaxHealth * Config.Life.ReviveHealthFraction)
	setState(player, "Alive")
	Remotes.Notify:FireClient(player, `💚 {rescuer.DisplayName} te ha reanimado`)
	Remotes.Notify:FireClient(rescuer, `💚 Has reanimado a {player.DisplayName}`)
end

-- Llamado por CombatService ante un golpe mortal.
function LifeService.down(player: Player)
	local character, humanoid, root = characterParts(player)
	if not (character and humanoid and root) or not LifeState.isAlive(player) then
		return
	end
	humanoid.Health = 1
	humanoid:UnequipTools()
	humanoid:SetAttribute("NormalWalkSpeed", humanoid.WalkSpeed)
	humanoid:SetAttribute("NormalJumpHeight", humanoid.JumpHeight)
	humanoid:SetAttribute("NormalJumpPower", humanoid.JumpPower)
	humanoid.WalkSpeed = Config.Life.CrawlSpeed
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	player:SetAttribute("DownedEndsAt", Workspace:GetServerTimeNow() + Config.Life.DownedSeconds)
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
		label.Text = "🆘 Caído"
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
	task.delay(Config.Life.DownedSeconds, function()
		if downedToken[player] == token and LifeState.get(player) == "Downed" then
			becomeSpirit(player)
		end
	end)
end

-- Al amanecer reaparecen todos los Espíritus y se reinicia la cuenta de caídas del día.
local function onDawn()
	table.clear(deathsToday)
	for _, player in Players:GetPlayers() do
		respawnSpirit(player)
	end
end

-- Marca de Espíritu: resalta para todos el enemigo al que apunta (nada más: ni árboles ni rocas).
local function onSpiritMark(player: Player, aim: any)
	if LifeState.get(player) ~= "Spirit" or typeof(aim) ~= "Vector3" or aim.Magnitude < 0.5 then
		return
	end
	local now = os.clock()
	if now - (lastMarkAt[player] or -math.huge) < Config.Life.SpiritMarkCooldownSeconds then
		return
	end
	lastMarkAt[player] = now

	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	if not (character and head and head:IsA("BasePart")) then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = Workspace:Raycast(head.Position, aim.Unit * Config.Life.SpiritMarkRange, params)
	if not result then
		return
	end

	-- Sube por los modelos hasta encontrar un enemigo.
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	while model do
		if CollectionService:HasTag(model, Config.Combat.EnemyTag) then
			local highlight = Instance.new("Highlight")
			highlight.FillTransparency = 1
			highlight.OutlineColor = Color3.fromRGB(255, 80, 60)
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Parent = model
			Debris:AddItem(highlight, Config.Life.SpiritMarkSeconds)
			return
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
end

local function onCharacterAdded(player: Player, character: Model)
	-- Si el personaje se recrea (por ejemplo, al caer al vacío), conserva el estado de Espíritu.
	local state = LifeState.get(player)
	if state == "Downed" then
		setState(player, "Alive")
	elseif state == "Spirit" then
		character:WaitForChild("HumanoidRootPart")
		setGhost(character, true)
	end
end

function LifeService:Init()
	DayNightService.onPhaseStarted(function(_day: number, phase: MatchState.Phase)
		if phase == "Day" then
			onDawn()
		end
	end)
end

function LifeService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Mochilas"
	folder.Parent = Workspace
	backpacks = folder

	Remotes.SpiritMark.OnServerEvent:Connect(onSpiritMark)

	local function onPlayer(player: Player)
		setState(player, "Alive")
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		downedToken[player] = nil
		spiritToken[player] = nil
		deathsToday[player] = nil
		lastMarkAt[player] = nil
		-- Sus mochilas ya no las puede recoger nadie.
		for _, bag in folder:GetChildren() do
			if bag:GetAttribute("OwnerUserId") == player.UserId then
				bag:Destroy()
			end
		end
	end)
end

return LifeService
