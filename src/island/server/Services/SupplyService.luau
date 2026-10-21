--!strict
-- Cajas de suministro (GDD §7 y §12, Fase 5). De día, cada Config.Supply.IntervalSeconds llega una
-- caja a una playa (si no queda otra sin abrir). Se ve de lejos por una columna de luz y se anuncia
-- con su dirección. Abrirla (mantener pulsado) activa el PvP de quien la abre y da botín de
-- naufragio. Los monos de cola larga rondan la caja.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Compass = require(ReplicatedStorage.Shared.Compass)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Retention = require(ServerScriptService.ServerShared.Retention)
local BasecampService = require(script.Parent.BasecampService)
local InventoryService = require(script.Parent.InventoryService)
local MonkeyService = require(script.Parent.MonkeyService)
local PvPService = require(script.Parent.PvPService)

local SupplyService = {}

local rng = Random.new()
local activeCrate: Model? = nil

local function announce(text: string)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text)
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
	PvPService.forceOn(player, Config.PvP.ForcedSeconds, "has abierto una caja de suministro")
	for _, entry in rollLoot() do
		InventoryService.collect(player, entry.itemId, entry.amount)
	end
	announce(`📦 {player.DisplayName} ha abierto la caja de suministro`)
	Retention.progress(player, "Supply")
	crate:Destroy()
end

function SupplyService.spawnCrate()
	local spot = beachSpot()
	if not spot then
		return
	end
	local crate = Instance.new("Model")
	crate.Name = "Caja de suministro"
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = Vector3.new(4, 3, 4)
	box.Position = spot + Vector3.new(0, 1.5, 0)
	box.Anchored = true
	box.Color = Color3.fromRGB(150, 110, 60)
	box.Material = Enum.Material.WoodPlanks
	box.Parent = crate
	for _, x in { -1, 1 } do
		local strap = Instance.new("Part")
		strap.Size = Vector3.new(0.3, 3.1, 4.1)
		strap.Position = box.Position + Vector3.new(x * 1.2, 0, 0)
		strap.Anchored = true
		strap.CanCollide = false
		strap.Color = Color3.fromRGB(70, 70, 75)
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
	beam.Color = Color3.fromRGB(255, 210, 90)
	beam.Transparency = 0.5
	beam.Parent = crate
	crate.PrimaryPart = box

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Abrir (activa PvP)"
	prompt.ObjectText = "Caja de suministro"
	prompt.HoldDuration = Config.Supply.OpenHoldSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	prompt.Triggered:Connect(function(player)
		onOpen(crate, player)
	end)

	crate.Parent = Workspace
	activeCrate = crate
	local direction = Compass.direction(BasecampService.getCenter(), spot)
	announce(`📦 ¡Ha llegado una caja de suministro a la playa de {direction}! Abrirla activa el PvP`)

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
