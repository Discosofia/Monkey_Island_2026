--!strict
-- Eventos de mitad de partida (Fase 9, G7; Data/MidEvents, Config.MidEvents).
--   - Al arrancar el servidor cada evento elige uno de sus días. Los de día empiezan
--     DayStartDelaySeconds después del amanecer; los de noche, al anochecer.
--   - Al anochecer se avisa de los de mañana, que se quedan en la línea de estado del HUD toda la
--     noche ("MidEventStatus" de ReplicatedStorage); mientras dura un evento, la línea dice cuál es.
--   - Lluvia tóxica: clima "ToxicRain" (WeatherService.force) durante DurationSeconds; el agua del río
--     y los mordiscos dan fiebre (SurvivalService, IslandCombatRules); cada médico recibe antídotos y
--     su Ungüento en área baja la fiebre.
--   - Macacos saboteadores: SiegeService.setSaboteurs para esa noche.
--   - Erupción preliminar: piroclastos sobre las zonas altas (WeatherService.pyroclasts) y cajas
--     militares en ellas (SupplyService.spawnMilitaryCrate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Compass = require(ReplicatedStorage.Shared.Compass)
local Config = require(ReplicatedStorage.Shared.Config)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MidEvents = require(ReplicatedStorage.Shared.Data.MidEvents)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local BasecampService = require(script.Parent.BasecampService)
local DayNightService = require(script.Parent.DayNightService)
local InventoryService = require(script.Parent.InventoryService)
local SiegeService = require(script.Parent.SiegeService)
local SupplyService = require(script.Parent.SupplyService)
local WeatherService = require(script.Parent.WeatherService)

local STATUS_ATTRIBUTE = "MidEventStatus"
-- Radio de la isla (studs) y paso de la cuadrícula al buscar las zonas altas.
local ISLAND_RADIUS = 950
local GRID_STEP = 25
-- Sitios al azar que se miran para cada caja militar después de la primera, y distancia a las guaridas
-- de los jefes a la que no se ponen.
local CRATE_SAMPLES = 40
local LAIR_CLEARANCE = 40

local MidEventService = {}

local rng = Random.new()
-- Día que le toca a cada evento en esta partida.
local schedule: { [MidEvents.EventId]: number } = {}
local statusToken = 0
-- Puntos de terreno de las zonas altas (todos, y los llanos donde cabe una caja); se buscan una vez.
local highGround: { Vector3 }? = nil
local flatHighGround: { Vector3 } = {}

-- Aviso a todos: plantilla en español y sus argumentos, que traduce cada cliente.
local function announce(text: string, args: { [string]: any }?)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text, args)
	end
end

-- Pone la línea de estado (Strings.pack: la traduce cada cliente); con "seconds", se borra sola después
-- (si nadie la ha cambiado).
local function setStatus(text: string, seconds: number?)
	statusToken += 1
	local token = statusToken
	ReplicatedStorage:SetAttribute(STATUS_ATTRIBUTE, text)
	if seconds then
		task.delay(seconds, function()
			if statusToken == token then
				ReplicatedStorage:SetAttribute(STATUS_ATTRIBUTE, "")
			end
		end)
	end
end

local function findHighGround(): { Vector3 }
	if highGround then
		return highGround
	end
	local found: { Vector3 } = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local minY = Config.MidEvents.Eruption.HighGroundY
	local lairs: { Vector3 } = {}
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, 1, 8) == "Guarida_" then
			table.insert(lairs, descendant.Position)
		end
	end
	local function nearLair(position: Vector3): boolean
		for _, lair in lairs do
			if (lair - position).Magnitude < LAIR_CLEARANCE then
				return true
			end
		end
		return false
	end
	for x = -ISLAND_RADIUS, ISLAND_RADIUS, GRID_STEP do
		for z = -ISLAND_RADIUS, ISLAND_RADIUS, GRID_STEP do
			local hit = Workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -1600, 0), params)
			if hit and hit.Position.Y >= minY and hit.Material ~= Enum.Material.Water then
				table.insert(found, hit.Position)
				-- Sin lava ni cuestas fuertes, para que la caja se pueda alcanzar, y fuera de las guaridas.
				if
					hit.Material ~= Enum.Material.CrackedLava
					and hit.Normal.Y >= 0.85
					and not nearLair(hit.Position)
				then
					table.insert(flatHighGround, hit.Position)
				end
			end
		end
		task.wait()
	end
	highGround = found
	return found
end

-- "count" sitios llanos de las zonas altas, lo más separados posible (el primero al azar; cada uno
-- de los siguientes, el más lejano a los ya elegidos de unos cuantos al azar): así cae uno en el volcán
-- y otro en las montañas.
local function crateSpots(count: number): { Vector3 }
	local spots: { Vector3 } = {}
	if #flatHighGround == 0 then
		return spots
	end
	table.insert(spots, flatHighGround[rng:NextInteger(1, #flatHighGround)])
	while #spots < count do
		local best: Vector3? = nil
		local bestDistance = -1
		for _ = 1, CRATE_SAMPLES do
			local candidate = flatHighGround[rng:NextInteger(1, #flatHighGround)]
			local nearest = math.huge
			for _, spot in spots do
				nearest = math.min(nearest, ((spot - candidate) * Vector3.new(1, 0, 1)).Magnitude)
			end
			if nearest > bestDistance then
				best = candidate
				bestDistance = nearest
			end
		end
		table.insert(spots, best :: Vector3)
	end
	return spots
end

local function startToxicRain()
	local settings = Config.MidEvents.ToxicRain
	WeatherService.force("ToxicRain", settings.DurationSeconds)
	local antidotes = settings.MedicAntidotes
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Role") == "Medico" then
			InventoryService.add(player, "Antidote", antidotes)
			local amount = if antidotes == 1
				then { Strings.later("1 antídoto") }
				else { Strings.later("{n} antídotos"), { n = antidotes } }
			Remotes.Notify:FireClient(
				player,
				"⛑️ Como médico recibes {amount}, y tu Ungüento en área baja la fiebre de los que curas",
				{ amount = amount }
			)
		end
	end
	return settings.DurationSeconds
end

local function startEruption()
	local settings = Config.MidEvents.Eruption
	local spots = findHighGround()
	local center = BasecampService.getCenter()
	local places = {}
	for _, spot in crateSpots(settings.Crates) do
		SupplyService.spawnMilitaryCrate(spot)
		local direction = Compass.direction(center, spot)
		if not table.find(places, direction) then
			table.insert(places, direction)
		end
	end
	local placeArgs = {}
	for _, direction in places do
		table.insert(placeArgs, { direction })
	end
	WeatherService.pyroclasts(spots, settings.DurationSeconds)
	if #places > 0 then
		announce(
			"🎖️ Cajas militares en las zonas altas, hacia {places}: abrirlas activa el PvP",
			{ places = { list = placeArgs, sep = { Strings.later(" y ") } } }
		)
	end
	return settings.DurationSeconds
end

-- Arranca el evento; devuelve cuánto dura su línea de estado (nil: hasta el amanecer).
local function start(event: MidEvents.MidEvent)
	announce(event.start)
	local seconds: number? = nil
	if event.id == "ToxicRain" then
		seconds = startToxicRain()
	elseif event.id == "Saboteurs" then
		SiegeService.setSaboteurs()
	elseif event.id == "Eruption" then
		seconds = startEruption()
	end
	setStatus(Strings.pack(event.status), seconds)
end

local function eventsOn(day: number, phase: MatchState.Phase?): { MidEvents.MidEvent }
	local found = {}
	for _, event in MidEvents do
		if schedule[event.id] == day and (phase == nil or event.phase == phase) then
			table.insert(found, event)
		end
	end
	return found
end

local function onPhaseStarted(day: number, phase: MatchState.Phase)
	if phase == "Night" then
		local tonight = eventsOn(day, "Night")
		for _, event in tonight do
			start(event)
		end
		-- Aviso de mañana (si esta noche ya hay evento, la línea de estado es la suya).
		local texts = {}
		for _, event in eventsOn(day + 1) do
			table.insert(texts, { Strings.later("{icon} {text}"), { icon = event.icon, text = { event.eve } } })
		end
		if #texts > 0 then
			local args = { texts = { list = texts, sep = " · " } }
			announce("📅 {texts}", args)
			if #tonight == 0 then
				setStatus(Strings.pack("📅 {texts}", args))
			end
		elseif #tonight == 0 then
			setStatus("")
		end
	else
		setStatus("")
		local today = eventsOn(day, "Day")
		if #today > 0 then
			task.delay(Config.MidEvents.DayStartDelaySeconds, function()
				local state = MatchState.read()
				if state and state.day == day and state.phase == "Day" then
					for _, event in today do
						start(event)
					end
				end
			end)
		end
	end
end

-- Panel de pruebas: el evento "id" ya. Los saboteadores, de noche, con una oleada ahora mismo; de día
-- se salta al anochecer y esa noche es la suya.
function MidEventService.debugStart(id: string)
	for _, event in MidEvents do
		if event.id == id then
			local state = MatchState.read()
			if event.phase == "Night" and not (state and state.phase == "Night") then
				schedule[event.id] = if state then state.day else 1
				DayNightService.skipPhase()
			else
				start(event)
				if id == "Saboteurs" then
					SiegeService.debugWave()
				end
			end
			return
		end
	end
end

-- Panel de pruebas: en qué día cae cada evento en esta partida.
function MidEventService.describe(): string
	local parts = {}
	for _, event in MidEvents do
		local phase = if event.phase == "Night" then "noche" else "día"
		table.insert(parts, `{event.icon} {event.name}: {phase} {schedule[event.id] or "?"}`)
	end
	return table.concat(parts, " · ")
end

function MidEventService:Init()
	for _, event in MidEvents do
		schedule[event.id] = event.days[rng:NextInteger(1, #event.days)]
	end
	DayNightService.onPhaseStarted(onPhaseStarted)
end

function MidEventService:Start()
	ReplicatedStorage:SetAttribute(STATUS_ATTRIBUTE, "")
	-- Las zonas altas se buscan ya, sin esperar a la erupción (son unos miles de rayos).
	task.spawn(findHighGround)
end

return MidEventService
