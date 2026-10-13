--!strict
-- Asedio nocturno v1 (GDD §10, Fase 2.5).
--   - Cada noche llegan Config.Siege.WavesPerNight oleadas de monos por uno o dos portones al azar.
--   - El tamaño crece con el día y con el número de jugadores (Config.Siege).
--   - Los monos rompen las piezas que les cierran el paso (muros, estacas…) y, si entran,
--     atacan también dentro del Basecamp. Las estacas hieren a los monos que las cruzan.
--   - Al amanecer los que quedan se retiran.
-- El estado se publica en ReplicatedStorage ("SiegeStatus") para el HUD.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Building = require(ReplicatedStorage.Shared.Building)
local Buildables = require(ReplicatedStorage.Shared.Data.Buildables)
local Config = require(ReplicatedStorage.Shared.Config)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BasecampService = require(script.Parent.BasecampService)
local BuildingService = require(script.Parent.BuildingService)
local CombatService = require(script.Parent.CombatService)
local DayNightService = require(script.Parent.DayNightService)
local MonkeyService = require(script.Parent.MonkeyService)

local STATUS_ATTRIBUTE = "SiegeStatus"
local SPIKE_TICK_SECONDS = 0.5
-- Portones en el mismo orden que los construye MapBuilder: este, sur, oeste y norte.
local GATE_NAMES = { "el este", "el sur", "el oeste", "el norte" }

local SiegeService = {}

local nightToken = 0
local rng = Random.new()

local function setStatus(text: string)
	ReplicatedStorage:SetAttribute(STATUS_ATTRIBUTE, text)
end

local function announce(text: string)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text)
	end
end

local function waveSize(day: number): number
	local settings = Config.Siege
	local size = settings.BaseWaveSize
		+ (day - 1) * settings.ExtraPerDay
		+ #Players:GetPlayers() * settings.ExtraPerPlayer
	return math.min(size, settings.MaxWaveSize)
end

-- Especie al azar entre las desbloqueadas para este día (Config.Siege.SpeciesByDay).
local function pickSpecies(day: number): string
	local unlocked = {}
	for _, entry in Config.Siege.SpeciesByDay do
		if day >= entry.day then
			table.insert(unlocked, entry.species)
		end
	end
	return if #unlocked > 0 then unlocked[rng:NextInteger(1, #unlocked)] else "AulladorRojo"
end

local function gateDirection(index: number): Vector3
	local angle = (index - 1) * math.pi / 2
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local function launchWave(day: number, wave: number)
	-- Centro a ras de suelo (BuildingService lo publica); si no, el de la zona.
	local flatCenter = Building.center() or BasecampService.getCenter()
	local total = waveSize(day)
	-- Uno o dos portones al azar; los monos se reparten entre ellos.
	local first = rng:NextInteger(1, 4)
	local gates = { first }
	if total >= 8 and rng:NextNumber() < 0.5 then
		table.insert(gates, (first + rng:NextInteger(0, 2)) % 4 + 1)
	end
	local names = {}
	for index, gate in gates do
		local direction = gateDirection(gate)
		local gatePoint = flatCenter + direction * (Config.Building.PerimeterRadius - 10)
		local spawnPoint = flatCenter + direction * (Config.Building.PerimeterRadius + Config.Siege.SpawnDistance)
		local count = if index == 1 then total - (#gates - 1) * (total // #gates) else total // #gates
		MonkeyService.spawnSiegeGroup(pickSpecies(day), spawnPoint, gatePoint, count)
		table.insert(names, GATE_NAMES[gate])
	end
	announce(
		`🐒 ¡Asedio! Oleada {wave}/{Config.Siege.WavesPerNight}: {total} monos desde {table.concat(names, " y ")}`
	)
end

local function runNight(day: number)
	nightToken += 1
	local token = nightToken
	task.spawn(function()
		task.wait(Config.Siege.FirstWaveDelaySeconds)
		for wave = 1, Config.Siege.WavesPerNight do
			if nightToken ~= token then
				return
			end
			launchWave(day, wave)
			if wave < Config.Siege.WavesPerNight then
				task.wait(Config.Siege.WaveIntervalSeconds)
			end
		end
	end)
	-- Estado para el HUD mientras dura la noche.
	task.spawn(function()
		while nightToken == token do
			local alive = MonkeyService.siegeAlive()
			setStatus(if alive > 0 then `⚔️ Asedio: {alive} monos atacan el Basecamp` else "🌙 Noche de asedio")
			task.wait(1)
		end
	end)
end

local function onPhaseStarted(day: number, phase: MatchState.Phase)
	if phase == "Night" then
		announce("🌙 Cae la noche: los monos asediarán el Basecamp. ¡Cerrad los portones!")
		runNight(day)
	else
		nightToken += 1
		MonkeyService.endSiege()
		setStatus("")
	end
end

-- Estacas: hieren a los enemigos encima y se desgastan con cada golpe.
local function tickSpikes()
	local structures = BuildingService.getStructures()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { structures }
	local size = Buildables.Spikes.size + Vector3.new(0, 4, 0)
	for _, model in structures:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("BuildableId") == "Spikes" then
			local hit: { [Model]: boolean } = {}
			for _, part in Workspace:GetPartBoundsInBox(model:GetPivot(), size, params) do
				local enemy = part:FindFirstAncestorOfClass("Model")
				local speciesId = if enemy then enemy:GetAttribute("MonkeyType") else nil
				local species = if typeof(speciesId) == "string" then Monkeys[speciesId] else nil
				local immune = species ~= nil and species.disarmsTraps == true
				if
					enemy
					and not hit[enemy]
					and not immune
					and CollectionService:HasTag(enemy, Config.Combat.EnemyTag)
				then
					local humanoid = enemy:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then
						hit[enemy] = true
						CombatService.damage(enemy, humanoid, Config.Siege.SpikeDamagePerSecond * SPIKE_TICK_SECONDS)
					end
				end
			end
			for _ in hit do
				if BuildingService.damageStructure(model, Config.Siege.SpikeWearPerHit) then
					break
				end
			end
		end
	end
end

function SiegeService:Init()
	DayNightService.onPhaseStarted(onPhaseStarted)
end

function SiegeService:Start()
	setStatus("")
	while true do
		task.wait(SPIKE_TICK_SECONDS)
		tickSpikes()
	end
end

return SiegeService
