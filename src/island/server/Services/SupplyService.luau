--!strict
-- Cajas de suministro (GDD §7 y §12, Fase 5). De día, cada Config.Supply.IntervalSeconds llega una
-- caja a una playa (si no queda otra sin abrir). Se ve de lejos por una columna de luz y se anuncia
-- con su dirección. Abrirla (mantener pulsado) activa el PvP de quien la abre y da botín de
-- naufragio. Los monos de cola larga rondan la caja.
-- Fase 9 (G7): en la erupción preliminar caen cajas militares en las zonas altas (MidEventService):
-- verdes y con columna roja, tardan más en abrirse, el PvP dura más y dan obsidiana, una esquirla de
-- jefe y provisiones (Config.MilitaryCrate). Cuentan como caja ("Supply") con la clave "Military".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Compass = require(ReplicatedStorage.Shared.Compass)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Retention = require(ServerScriptService.ServerShared.Retention)
local BasecampService = require(script.Parent.BasecampService)
local InventoryService = require(script.Parent.InventoryService)
local MonkeyService = require(script.Parent.MonkeyService)
local PvPService = require(script.Parent.PvPService)

local SupplyService = {}

local rng = Random.new()
local activeCrate: Model? = nil

-- Aviso a todos: plantilla en español y sus argumentos, que traduce cada cliente.
local function announce(text: string, args: { [string]: any }?)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text, args)
	end
end

-- Un punto de arena lejos del Basecamp, o nil si el mapa no tiene playas.
local function beachSpot(): Vector3?
	local center = BasecampService.getCenter()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	for _ = 1, 120 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = rng:NextNumber(400, 1200)
		local point = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		local hit = Workspace:Raycast(Vector3.new(point.X, 400, point.Z), Vector3.new(0, -800, 0), params)
		if hit and hit.Material == Enum.Material.Sand then
			return hit.Position
		end
	end
	return nil
end

local function rollLoot(): { { itemId: string, amount: number } }
	local pool = Config.Supply.Loot
	local total = 0
	for _, entry in pool do
		total += entry.weight
	end
	local result = {}
	for _, entry in Config.Supply.Always do
		table.insert(result, { itemId = entry.itemId, amount = rng:NextInteger(entry.min, entry.max) })
	end
	for _ = 1, Config.Supply.ItemsPerCrate do
		local pick = rng:NextNumber(0, total)
		for _, entry in pool do
			pick -= entry.weight
			if pick <= 0 then
				table.insert(result, { itemId = entry.itemId, amount = rng:NextInteger(entry.min, entry.max) })
				break
			end
		end
	end
	return result
end

local function onOpen(crate: Model, player: Player)
	if activeCrate ~= crate or not LifeState.isAlive(player) then
		return
	end
	activeCrate = nil
	PvPService.forceOn(player, Config.PvP.ForcedSeconds, Strings.later("has abierto una caja de suministro"))
	for _, entry in rollLoot() do
		InventoryService.collect(player, entry.itemId, entry.amount)
	end
	announce("📦 {player} ha abierto la caja de suministro", { player = player.DisplayName })
	Retention.progress(player, "Supply")
	crate:Destroy()
end

type CrateStyle = {
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	strapColor: Color3,
	beamColor: Color3,
	holdSeconds: number,
}

-- Caja en "spot" con su columna de luz y el aviso para abrirla (mantener pulsado).
local function buildCrate(spot: Vector3, style: CrateStyle, onTriggered: (crate: Model, player: Player) -> ()): Model
	local crate = Instance.new("Model")
	crate.Name = style.name
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = style.size
	box.Position = spot + Vector3.new(0, style.size.Y / 2, 0)
	box.Anchored = true
	box.Color = style.color
	box.Material = style.material
	box.Parent = crate
	for _, x in { -1, 1 } do
		local strap = Instance.new("Part")
		strap.Size = Vector3.new(0.3, style.size.Y + 0.1, style.size.Z + 0.1)
		strap.Position = box.Position + Vector3.new(x * style.size.X * 0.3, 0, 0)
		strap.Anchored = true
		strap.CanCollide = false
		strap.Color = style.strapColor
		strap.Material = Enum.Material.Metal
		strap.Parent = crate
	end
	-- Columna de luz visible desde lejos.
	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Size = Vector3.new(1.2, 120, 1.2)
	beam.Position = spot + Vector3.new(0, 60, 0)
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = style.beamColor
	beam.Transparency = 0.5
	beam.Parent = crate
	crate.PrimaryPart = box

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir (activa PvP)"
	prompt.ObjectText = style.name
	prompt.HoldDuration = style.holdSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	prompt.Triggered:Connect(function(player)
		onTriggered(crate, player)
	end)
	crate.Parent = Workspace
	return crate
end

local SUPPLY_STYLE: CrateStyle = {
	name = Strings.later("Caja de suministro"),
	size = Vector3.new(4, 3, 4),
	color = Color3.fromRGB(150, 110, 60),
	material = Enum.Material.WoodPlanks,
	strapColor = Color3.fromRGB(70, 70, 75),
	beamColor = Color3.fromRGB(255, 210, 90),
	holdSeconds = Config.Supply.OpenHoldSeconds,
}

local MILITARY_STYLE: CrateStyle = {
	name = Strings.later("Caja militar"),
	size = Vector3.new(5, 3.4, 4),
	color = Color3.fromRGB(78, 96, 58),
	material = Enum.Material.DiamondPlate,
	strapColor = Color3.fromRGB(40, 40, 42),
	beamColor = Color3.fromRGB(255, 80, 60),
	holdSeconds = Config.MilitaryCrate.OpenHoldSeconds,
}

local function onOpenMilitary(crate: Model, player: Player)
	if crate:GetAttribute("Opened") == true or not LifeState.isAlive(player) then
		return
	end
	crate:SetAttribute("Opened", true)
	local settings = Config.MilitaryCrate
	PvPService.forceOn(player, settings.PvPSeconds, Strings.later("has abierto una caja militar"))
	for _, entry in settings.Loot do
		InventoryService.collect(player, entry.itemId, rng:NextInteger(entry.min, entry.max))
	end
	InventoryService.collect(player, settings.Shards[rng:NextInteger(1, #settings.Shards)], 1)
	announce("🎖️ {player} ha abierto una caja militar", { player = player.DisplayName })
	Retention.progress(player, "Supply", 1, "Military")
	crate:Destroy()
end

-- Caja militar en "spot" (una zona alta, MidEventService), con babuinos de guardia.
function SupplyService.spawnMilitaryCrate(spot: Vector3)
	buildCrate(spot, MILITARY_STYLE, onOpenMilitary)
	local guards = Config.MilitaryCrate.Guards
	local nearest: Player? = nil
	for _, player in Players:GetPlayers() do
		nearest = nearest or player
	end
	if nearest then
		MonkeyService.spawnAmbush(guards.species, spot + Vector3.new(8, 0, 8), guards.count, nearest)
	end
end

function SupplyService.spawnCrate()
	local spot = beachSpot()
	if not spot then
		return
	end
	local crate = buildCrate(spot, SUPPLY_STYLE, onOpen)
	activeCrate = crate
	announce(
		"📦 ¡Ha llegado una caja de suministro a la playa {direction}! Abrirla activa el PvP",
		{ direction = { Compass.directionOf(BasecampService.getCenter(), spot) } }
	)

	-- Monos de cola larga rondando la caja: atacan a quien se acerque.
	local nearest: Player? = nil
	for _, player in Players:GetPlayers() do
		nearest = nearest or player
	end
	if nearest then
		MonkeyService.spawnAmbush("ColaLarga", spot + Vector3.new(10, 0, 10), 2, nearest)
	end
end

function SupplyService:Start()
	task.wait(Config.Supply.FirstDelaySeconds)
	while true do
		local state = MatchState.read()
		if state and state.phase == "Day" and not (activeCrate and activeCrate.Parent) then
			SupplyService.spawnCrate()
		end
		task.wait(Config.Supply.IntervalSeconds)
	end
end

return SupplyService
