--!strict
-- La pelota del Juego de pelota de Dunas (Fase 26c): el servidor es la única fuente de verdad. Simula con
-- Shared/BallSim a paso fijo (sin Parts de física ni NetworkOwnership; el servidor ni siquiera la dibuja),
-- manda el estado a todos los clientes a Data/Ballgame.Net.StateHz por Remotes.BallState (no fiable) y cada
-- evento de la simulación por Remotes.BallEvent (fiable) y a los oyentes del servidor (26e se suscribe).
-- Todo va en coordenadas LOCALES de la cancha (Shared/CourtGeometry); el cliente las pasa al mundo.
-- Mientras no está activa (setActive) no simula ni manda nada. El atributo "BallActive" de ReplicatedStorage
-- avisa a los clientes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local BallSim = require(ReplicatedStorage.Shared.BallSim)
local Config = require(ReplicatedStorage.Shared.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Data = require(ReplicatedStorage.Shared.Data.Ballgame)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Pasos fijos máximos por fotograma: si el servidor se atrasa, no se pone al día (la pelota va más lenta).
local MAX_STEPS_PER_FRAME = 4

local BallService = {}

local active = false
local state: BallSim.State = BallSim.new(Vector3.new(0, Data.Serve.Height, 0))
local accumulator = 0
local sendTimer = 0
local sentRestingAt = -math.huge -- cuándo se mandó por última vez el estado parado
local needsSend = true
local listeners: { (event: BallSim.Event) -> () } = {}
local cachedLayout: CourtGeometry.Layout? = nil
local cachedFormat = -1
-- Buffer circular de las últimas posiciones (Fase 27f, repetición del aro): una por fotograma mientras la pelota está
-- activa. bufferTimes[i] es el os.clock() de la muestra i y bufferPositions[i] su posición local.
local bufferTimes: { number } = {}
local bufferPositions: { Vector3 } = {}
local bufferHead = 0 -- índice de la última muestra escrita
local bufferCount = 0

local function bufferCapacity(): number
	return math.ceil(Config.Arena.Ballgame.Replay.BufferSeconds * 70) -- 70 > 60 fotogramas/s: cabe también con fotogramas más rápidos
end

local function clearBuffer()
	bufferHead = 0
	bufferCount = 0
end

local function record()
	local capacity = bufferCapacity()
	bufferHead = bufferHead % capacity + 1
	bufferTimes[bufferHead] = os.clock()
	bufferPositions[bufferHead] = state.pos
	bufferCount = math.min(bufferCount + 1, capacity)
end

-- Las medidas de la cancha del formato en curso.
function BallService.layout(): CourtGeometry.Layout
	local format = Arena.format()
	local layout = cachedLayout
	if layout == nil or cachedFormat ~= format then
		layout = CourtGeometry.forFormat(format)
		cachedLayout = layout
		cachedFormat = format
	end
	return layout :: CourtGeometry.Layout
end

local function send()
	needsSend = false
	local snapshot = BallSim.snapshot(state)
	if state.resting or state.dead then
		sentRestingAt = Workspace:GetServerTimeNow()
	end
	Remotes.BallState:FireAllClients({
		t = Workspace:GetServerTimeNow(),
		pos = snapshot.pos,
		vel = snapshot.vel,
		resting = snapshot.resting,
		dead = state.dead,
		curve = state.curveLeft,
	})
end

local function dispatch(event: BallSim.Event)
	event.t = Workspace:GetServerTimeNow()
	Remotes.BallEvent:FireAllClients(event)
	for _, listener in listeners do
		local ok, err = pcall(listener, event)
		if not ok then
			warn(`[BallService] Un oyente falló: {err}`)
		end
	end
end

-- Activa o desactiva la pelota (y se lo dice a los clientes).
function BallService.setActive(value: boolean)
	if active == value then
		return
	end
	active = value
	ReplicatedStorage:SetAttribute("BallActive", value)
	accumulator = 0
	needsSend = true
	if value then
		clearBuffer()
	end
end

function BallService.isActive(): boolean
	return active
end

-- Deja la pelota en un punto local con su velocidad (la simulación sigue desde ahí).
function BallService.place(localPos: Vector3, localVel: Vector3?)
	state = BallSim.new(localPos, localVel)
	accumulator = 0
	needsSend = true
	clearBuffer() -- el salto de posición no se interpola en la repetición
end

-- La trayectoria de los últimos "seconds" segundos muestreada a "hz" (posiciones LOCALES, la última es la actual). La
-- repetición del aro (Fase 27f) la manda a los clientes. Sin historial suficiente repite la primera muestra.
function BallService.recentTrack(seconds: number, hz: number): { Vector3 }
	local track = {}
	local count = bufferCount
	if count == 0 then
		table.insert(track, state.pos)
		return track
	end
	local capacity = bufferCapacity()
	-- La muestra k (1 = la más vieja) vive en el índice circular de abajo.
	local function indexOf(k: number): number
		return (bufferHead - count + k - 1) % capacity + 1
	end
	local last = os.clock()
	local steps = math.max(1, math.floor(seconds * hz))
	local k = 1
	for s = 0, steps do
		local at = last - seconds + s / hz
		while k < count and bufferTimes[indexOf(k + 1)] <= at do
			k += 1
		end
		local current = indexOf(k)
		local position = bufferPositions[current]
		if k < count and bufferTimes[current] < at then
			local nextIndex = indexOf(k + 1)
			local span = bufferTimes[nextIndex] - bufferTimes[current]
			if span > 0 then
				position = position:Lerp(bufferPositions[nextIndex], (at - bufferTimes[current]) / span)
			end
		end
		table.insert(track, position)
	end
	-- La última muestra es la posición exacta de ahora (la embocada ocurre dentro del subpaso, tras la última grabada).
	track[#track] = state.pos
	return track
end

-- Saque: la pelota sale del centro del pasillo con un lob suave hacia el campo del equipo indicado (o de uno al azar).
function BallService.serve(teamId: string?)
	local serve = Data.Serve
	local direction = if teamId == "Jaguar"
		then -1
		elseif teamId == "Quetzal" then 1
		elseif math.random() < 0.5 then -1
		else 1
	local side = (math.random() * 2 - 1) * serve.SideSpeed
	BallService.place(Vector3.new(0, serve.Height, 0), Vector3.new(direction * serve.Horizontal, serve.Vertical, side))
end

-- Una copia del estado actual.
function BallService.state(): BallSim.State
	return BallSim.clone(state)
end

-- Suma una velocidad a la pelota (la despierta si estaba parada). Lo usará el golpe de 26d.
function BallService.applyImpulse(velocity: Vector3)
	if state.dead then
		return
	end
	state.vel += velocity
	if state.vel.Magnitude > Data.MaxSpeed then
		state.vel = state.vel.Unit * Data.MaxSpeed
	end
	state.resting = false
	needsSend = true
end

-- Pone los segundos de curva de la pelota (Viento, Fase 26f; 0 = recta). Cada golpe lo fija: uno sin viento la
-- endereza. Viaja en el estado y en el evento del golpe para que el cliente lo respete al predecir.
function BallService.setCurve(seconds: number)
	state.curveLeft = seconds
	needsSend = true
end

-- Se suscribe a los eventos de la pelota. Devuelve la función que desconecta.
function BallService.onEvent(listener: (event: BallSim.Event) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

local function onHeartbeat(dt: number)
	if not active then
		return
	end
	record()
	if not (state.resting or state.dead) then
		accumulator += dt
		local layout = BallService.layout()
		local steps = 0
		while accumulator >= BallSim.STEP and steps < MAX_STEPS_PER_FRAME do
			accumulator -= BallSim.STEP
			steps += 1
			for _, event in BallSim.step(state, layout, BallSim.STEP) do
				dispatch(event)
			end
			if state.resting or state.dead then
				needsSend = true -- el último estado (parado o fuera) tiene que llegar
				break
			end
		end
		if steps == MAX_STEPS_PER_FRAME then
			accumulator = 0
		end
		if not (state.resting or state.dead) then
			needsSend = true
		end
	else
		accumulator = 0
	end

	sendTimer += dt
	if sendTimer < 1 / Data.Net.StateHz then
		return
	end
	sendTimer = 0
	-- Parada, se repite cada tanto para quien llega tarde.
	local resendDue = Workspace:GetServerTimeNow() - sentRestingAt >= Data.Net.RestResendSeconds
	if needsSend or ((state.resting or state.dead) and resendDue) then
		send()
	end
end

function BallService:Init()
	ReplicatedStorage:SetAttribute("BallActive", false)
end

function BallService:Start()
	RunService.Heartbeat:Connect(onHeartbeat)
	-- Si cambia el formato (la cancha cambia de largo), la pelota se repone en el centro.
	ReplicatedStorage:GetAttributeChangedSignal("ArenaFormat"):Connect(function()
		BallService.place(Vector3.new(0, Data.Serve.Height, 0))
	end)
end

return BallService
