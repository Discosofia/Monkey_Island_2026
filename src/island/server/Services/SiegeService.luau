--!strict
-- Asedio nocturno v1 (GDD §10, Fase 2.5).
--   - Cada noche llegan Config.Siege.WavesPerNight oleadas de monos, repartidas entre los 4 portones.
--     Dentro, cada mono se abre hacia un lado y va a su hueco alrededor de la hoguera (MonkeyService).
--   - El tamaño crece con el día y con el número de jugadores (Config.Siege).
--   - Los monos rompen las piezas que les cierran el paso (muros, portones…) y, si entran,
--     atacan también dentro del Basecamp. Las estacas no cierran el paso: los monos las cruzan y
--     se pinchan (salvo el macaco, que las desarma).
--   - Al amanecer los que quedan se retiran.
-- El estado se publica en ReplicatedStorage ("SiegeStatus") para el HUD.
-- Fase 6: la noche tras encender la baliza ("FinalNight") es La Gran Tropa: una oleada por especie de
-- Config.Siege.FinalNightSpecies, repartidas para que todas lleguen antes del amanecer. Cada oleada es
-- un FinalNightGrowth más grande que la anterior y lo que crece es una especie nueva y más fuerte.
-- Fase 9 (G7): en la noche de macacos saboteadores (MidEventService, setSaboteurs) cada oleada trae
-- además macacos que van a por las trampas, los muros y las estaciones (Config.MidEvents.Saboteurs).
-- Fase 9 (G8): en la Gran Tropa, parte de los mandriles, orangutanes y gorilas de cada oleada va a por
-- la baliza (Config.Siege.BeaconRaid); si la derriban no hay rescate esa noche (BeaconService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Building = require(ReplicatedStorage.Shared.Building)
local Buildables = require(ReplicatedStorage.Shared.Data.Buildables)
local Config = require(ReplicatedStorage.Shared.Config)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BasecampService = require(script.Parent.BasecampService)
local BuildingService = require(script.Parent.BuildingService)
local CombatService = require(ServerScriptService.Combat.Services.CombatService)
local DayNightService = require(script.Parent.DayNightService)
local MonkeyService = require(script.Parent.MonkeyService)
local Status = require(ServerScriptService.Combat.Status)

local STATUS_ATTRIBUTE = "SiegeStatus"

-- Corto para no perderse a un mono rápido que cruza la estaca entre dos comprobaciones.
local SPIKE_TICK_SECONDS = 0.25

local SiegeService = {}

local nightToken = 0
local debugGreatTroop = false
local saboteurNight = false
local rng = Random.new()
-- Último pinchazo de estaca a cada mono (os.clock): como mucho uno cada SpikeHitCooldownSeconds.
local lastPinch: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

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

local function isFinalNight(): boolean
	return ReplicatedStorage:GetAttribute("FinalNight") == true
end

local function wavesTonight(): number
	return if isFinalNight() then #Config.Siege.FinalNightSpecies else Config.Siege.WavesPerNight
end

-- La Gran Tropa: la oleada "wave" trae lo mismo que la anterior más un FinalNightGrowth extra de una
-- especie nueva y más fuerte (aulladores; + macacos; + mandriles; + orangutanes; + gorilas).
local function finalWaveMix(day: number, wave: number): { { species: string, count: number } }
	local settings = Config.Siege
	local first = math.round(waveSize(day) * settings.FinalNightSizeMultiplier)
	local mix = { { species = settings.FinalNightSpecies[1], count = first } }
	local total = first
	for index = 2, wave do
		local extra = math.max(1, math.round(total * settings.FinalNightGrowth))
		table.insert(mix, { species = settings.FinalNightSpecies[index], count = extra })
		total += extra
	end
	return mix
end

-- Parte de "count" que va al portón "index" de "parts": el primero se lleva lo que sobre al dividir.
local function share(count: number, parts: number, index: number): number
	return if index == 1 then count - (parts - 1) * (count // parts) else count // parts
end

local SABOTEURS: MonkeyService.Raid = {
	targets = Config.MidEvents.Saboteurs.Targets,
	searchRadius = Config.MidEvents.Saboteurs.SearchRadius,
	damageMultiplier = Config.MidEvents.Saboteurs.DamageMultiplier,
	bubble = "🔧",
}

local BEACON_RAIDERS: MonkeyService.Raid = {
	targets = { "Beacon" },
	searchRadius = Config.Siege.BeaconRaid.SearchRadius,
	bubble = "📡",
}

local function launchWave(day: number, wave: number)
	-- Centro a ras de suelo (BuildingService lo publica); si no, el de la zona.
	local flatCenter = Building.center() or BasecampService.getCenter()
	local mix = if isFinalNight() then finalWaveMix(day, wave) else nil
	local total = 0
	if mix then
		for _, entry in mix do
			total += entry.count
		end
	else
		total = waveSize(day)
	end
	-- Por los 4 portones a la vez: la oleada se reparte entre todos (empezando por uno al azar, que
	-- se lleva lo que sobre al dividir). Dentro, cada mono se abre hacia un lado (MonkeyService).
	local first = rng:NextInteger(1, 4)
	local gates = {}
	for offset = 0, 3 do
		table.insert(gates, (first + offset - 1) % 4 + 1)
	end
	for index, gate in gates do
		local direction = gateDirection(gate)
		local gatePoint = flatCenter + direction * (Config.Building.PerimeterRadius - 10)
		local spawnPoint = flatCenter + direction * (Config.Building.PerimeterRadius + Config.Siege.SpawnDistance)
		if mix then
			-- Cada especie de la mezcla se reparte entre todos los portones; de las de BeaconRaid, una
			-- parte va a por la baliza.
			for _, entry in mix do
				local count = share(entry.count, #gates, index)
				local raiders = if table.find(Config.Siege.BeaconRaid.Species, entry.species)
					then math.round(count * Config.Siege.BeaconRaid.Share)
					else 0
				if raiders > 0 then
					MonkeyService.spawnSiegeGroup(entry.species, spawnPoint, gatePoint, raiders, BEACON_RAIDERS)
				end
				if count - raiders > 0 then
					MonkeyService.spawnSiegeGroup(entry.species, spawnPoint, gatePoint, count - raiders)
				end
			end
		else
			local count = share(total, #gates, index)
			if count > 0 then
				MonkeyService.spawnSiegeGroup(pickSpecies(day), spawnPoint, gatePoint, count)
			end
		end
	end
	-- Noche de saboteadores: además, macacos que van a por las piezas, repartidos entre los portones.
	local saboteurs = 0
	if saboteurNight and not mix then
		local settings = Config.MidEvents.Saboteurs
		saboteurs = math.max(settings.MinPerWave, math.round(total * settings.ShareOfWave))
		for index, gate in gates do
			local count = share(saboteurs, #gates, index)
			if count > 0 then
				local direction = gateDirection(gate)
				MonkeyService.spawnSiegeGroup(
					settings.Species,
					flatCenter + direction * (Config.Building.PerimeterRadius + Config.Siege.SpawnDistance),
					flatCenter + direction * (Config.Building.PerimeterRadius - 10),
					count,
					SABOTEURS
				)
			end
		end
	end
	local from = "los 4 portones"
	if mix then
		local parts = {}
		for _, entry in mix do
			table.insert(parts, `{entry.count} {Monkeys[entry.species].name}`)
		end
		announce(
			`🌕 ¡La Gran Tropa! Oleada {wave}/{wavesTonight()}: {total} monos desde {from} ({table.concat(
				parts,
				", "
			)})`
		)
	elseif saboteurs > 0 then
		announce(
			`🔧 ¡Asedio! Oleada {wave}/{wavesTonight()}: {total} monos y {saboteurs} macacos saboteadores desde {from}`
		)
	else
		announce(`🐒 ¡Asedio! Oleada {wave}/{wavesTonight()}: {total} monos desde {from}`)
	end
end

local function runNight(day: number)
	nightToken += 1
	local token = nightToken
	local currentWave = 0
	task.spawn(function()
		-- Un respiro para que BeaconService marque antes "FinalNight" (los dos se enteran a la vez).
		task.wait()
		local settings = Config.Siege
		local waves = wavesTonight()
		local firstDelay = settings.FirstWaveDelaySeconds
		local interval = settings.WaveIntervalSeconds
		if isFinalNight() then
			-- Todas las oleadas caben antes del amanecer y a la última le quedan FinalNightLastWaveSeconds
			-- para pelear. Se mide con lo que queda de noche (el panel de pruebas puede empezarla tarde).
			local state = MatchState.read()
			local remaining = if state
				then state.phaseEndsAt - Workspace:GetServerTimeNow()
				else Config.Match.NightLengthSeconds
			firstDelay = math.min(settings.FinalNightFirstWaveDelaySeconds, remaining * 0.05)
			local spread = remaining - firstDelay - settings.FinalNightLastWaveSeconds
			interval = math.max(settings.FinalNightMinIntervalSeconds, spread / math.max(waves - 1, 1))
		end
		task.wait(firstDelay)
		for wave = 1, waves do
			if nightToken ~= token then
				return
			end
			currentWave = wave
			launchWave(day, wave)
			if wave < waves then
				task.wait(interval)
			end
		end
	end)
	-- Estado para el HUD mientras dura la noche.
	task.spawn(function()
		while nightToken == token do
			local alive = MonkeyService.siegeAlive()
			if isFinalNight() then
				local wave = if currentWave > 0 then ` · oleada {currentWave}/{wavesTonight()}` else ""
				setStatus(
					if alive > 0
						then `🌕 La Gran Tropa{wave}: {alive} monos atacan el Basecamp`
						else `🌕 La Gran Tropa{wave}`
				)
			elseif saboteurNight then
				setStatus(
					if alive > 0
						then `🔧 Asedio con saboteadores: {alive} monos atacan el Basecamp`
						else "🔧 Noche de macacos saboteadores"
				)
			else
				setStatus(
					if alive > 0 then `⚔️ Asedio: {alive} monos atacan el Basecamp` else "🌙 Noche de asedio"
				)
			end
			task.wait(1)
		end
	end)
end

local function onPhaseStarted(day: number, phase: MatchState.Phase)
	if phase == "Night" then
		if debugGreatTroop then
			ReplicatedStorage:SetAttribute("FinalNight", true)
		end
		announce("🌙 Cae la noche: los monos asediarán el Basecamp. ¡Cerrad los portones!")
		runNight(day)
	else
		nightToken += 1
		saboteurNight = false
		MonkeyService.endSiege()
		setStatus("")
		-- La Gran Tropa del panel de pruebas no enciende la baliza: al amanecer todo sigue como antes.
		if debugGreatTroop then
			debugGreatTroop = false
			if ReplicatedStorage:GetAttribute("BeaconLit") ~= true then
				ReplicatedStorage:SetAttribute("FinalNight", nil)
			end
		end
	end
end

-- Esta noche las oleadas traen macacos saboteadores (MidEventService, al anochecer). Al amanecer se
-- quita sola.
function SiegeService.setSaboteurs()
	saboteurNight = true
end

-- Panel de pruebas: una oleada ya (de noche), con saboteadores si es su noche.
function SiegeService.debugWave()
	local state = MatchState.read()
	if state and state.phase == "Night" then
		launchWave(state.day, 1)
	end
end

-- Panel de pruebas: La Gran Tropa ya. De noche empieza en este momento (repartida en lo que queda de
-- noche); de día se salta al anochecer. No cuenta como encender la baliza: al amanecer no hay rescate.
function SiegeService.debugGreatTroop()
	debugGreatTroop = true
	local state = MatchState.read()
	if state and state.phase == "Night" then
		ReplicatedStorage:SetAttribute("FinalNight", true)
		announce("🌕 ¡LA GRAN TROPA! (prueba) Toda la isla viene a por el Basecamp")
		runNight(state.day)
	else
		DayNightService.skipPhase()
	end
end

-- Los que desarman trampas (el macaco) no se pinchan.
local function disarmsTraps(enemy: Model): boolean
	local speciesId = enemy:GetAttribute("MonkeyType")
	local species = if typeof(speciesId) == "string" then Monkeys[speciesId] else nil
	return species ~= nil and species.disarmsTraps == true
end

-- Estacas: el mono que las pisa recibe un pinchazo (que las desgasta), daño mientras sigue encima y
-- va más lento (Config.Siege.Spike*).
local function tickSpikes()
	local structures = Workspace:FindFirstChild(Building.STRUCTURES_FOLDER)
	if not structures then
		return
	end
	local settings = Config.Siege
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { structures }
	local margin = settings.SpikeReachMargin * 2
	local size = Buildables.Spikes.size + Vector3.new(margin, 4, margin)
	local clock = os.clock()
	-- Cada mono cuenta una vez por comprobación aunque pise varias estacas a la vez.
	local seen: { [Model]: boolean } = {}
	for _, model in structures:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("BuildableId") == "Spikes" then
			for _, part in Workspace:GetPartBoundsInBox(model:GetPivot(), size, params) do
				local enemy, humanoid = CombatService.enemyFromPart(part)
				if enemy and humanoid and not seen[enemy] and not disarmsTraps(enemy) then
					seen[enemy] = true
					local damage = settings.SpikeDamagePerSecond * SPIKE_TICK_SECONDS
					local fresh = clock - (lastPinch[enemy] or -math.huge) >= settings.SpikeHitCooldownSeconds
					if fresh then
						lastPinch[enemy] = clock
						damage += settings.SpikeHitDamage
					end
					-- Sin rebajar una ralentización más fuerte (la nova del mago).
					if Status.speedFactor(enemy) > settings.SpikeSlowFactor then
						Status.slow(enemy, settings.SpikeSlowSeconds, settings.SpikeSlowFactor)
					end
					CombatService.damage(enemy, humanoid, damage)
					-- Cada pinchazo la desgasta; si se rompe, ya no pincha a nadie más.
					if fresh and BuildingService.damageStructure(model, settings.SpikeWearPerHit) then
						break
					end
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
