--!strict
-- La pelota del Juego de pelota de Dunas en este cliente (Fase 26c). Dibuja una pelota local (un Part esférico
-- anclado, sin colisión) con su sombra, solo mientras ReplicatedStorage "BallActive" sea true. Lleva su propia
-- copia de la simulación (Shared/BallSim, la misma que corre el servidor):
--   - Cada paquete de Remotes.BallState (a 20 Hz, puede llegar desordenado) fija el estado y lo avanza el tiempo
--     que ha tardado en llegar (hasta Net.MaxCatchUp), para compensar la latencia.
--   - Cada fotograma avanza la predicción con pasos fijos.
--   - Lo dibujado = lo predicho + un desvío que se disuelve en Net.SmoothSeconds (así no hay saltos al llegar
--     un paquete); si el desvío pasa de Net.SnapDistance, salta de golpe.
--   - Golpes (Fase 26d): predictHit fija la velocidad del golpe propio al pulsar (sin esperar al servidor) y el
--     BallEvent "hit" de otro jugador (o un roce propio) fija posición y velocidad. predictedState y part las usa
--     BallHitController para el alcance y el anillo de tiempo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local BallSim = require(ReplicatedStorage.Shared.BallSim)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Data = require(ReplicatedStorage.Shared.Data.Ballgame)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RADIUS = CourtGeometry.BALL_RADIUS
local CENTER = CourtGeometry.CENTER
-- Pasos fijos máximos por fotograma al avanzar (si no, el cliente se atrasa y se salta lo que sobra).
local MAX_FRAME_STEPS = 8
-- La sombra: un disco aplastado un poco por encima de la superficie; más transparente y pequeño con la altura.
local SHADOW_LIFT = 0.06
local SHADOW_THICKNESS = 0.1
local SHADOW_MIN_TRANSPARENCY = 0.35
local SHADOW_SHRINK = 0.5

local BallController = {}

local sim = BallSim.new(Vector3.zero)
local layout: CourtGeometry.Layout = CourtGeometry.forFormat(Arena.format())
local layoutFormat = Arena.format()
local ball: Part? = nil
local shadow: Part? = nil
local hasState = false -- ha llegado al menos un paquete desde que se activó
local lastT = -math.huge
local accumulator = 0
local offset = Vector3.zero -- lo que lo dibujado se aparta de lo predicho
local drawn: Vector3? = nil -- última posición local dibujada

local function currentLayout(): CourtGeometry.Layout
	local format = Arena.format()
	if format ~= layoutFormat then
		layoutFormat = format
		layout = CourtGeometry.forFormat(format)
	end
	return layout
end

local function makePart(name: string, shape: Enum.PartType): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- El modelo de la pelota (sin padre). BallReplayController lo usa para su copia de la repetición.
local function newBallPart(): Part
	local newBall = makePart("Ball", Enum.PartType.Ball)
	newBall.Size = Vector3.one * (2 * RADIUS)
	newBall.Color = Data.BallColor
	newBall.Material = Data.BallMaterial
	return newBall
end

local function ensureParts()
	if ball == nil then
		ball = newBallPart()
	end
	if shadow == nil then
		local newShadow = makePart("BallShadow", Enum.PartType.Cylinder)
		newShadow.Color = Color3.new(0, 0, 0)
		newShadow.Material = Enum.Material.SmoothPlastic
		shadow = newShadow
	end
end

local function hide()
	if ball then
		ball.Parent = nil
	end
	if shadow then
		shadow.Parent = nil
	end
	drawn = nil
end

-- Avanza la predicción con pasos fijos mientras quede tiempo acumulado.
local function advance(maxSteps: number)
	local steps = 0
	local current = currentLayout()
	while accumulator >= BallSim.STEP do
		if sim.resting or sim.dead or steps >= maxSteps then
			accumulator = 0
			break
		end
		accumulator -= BallSim.STEP
		steps += 1
		BallSim.step(sim, current, BallSim.STEP)
	end
end

-- Dónde se dibuja la pelota (local): lo predicho, adelantado lo que sobra del paso fijo, más el desvío.
local function predictedPosition(): Vector3
	if sim.resting or sim.dead then
		return sim.pos
	end
	return sim.pos + sim.vel * accumulator
end

local function render(position: Vector3)
	ensureParts()
	local theBall, theShadow = ball :: Part, shadow :: Part
	theBall.Position = CENTER + position
	theBall.Parent = Workspace

	-- La sombra va sobre el suelo que hay debajo (0 en las cabeceras); sobre el muro no hay.
	local ground: number? = 0
	if math.abs(position.X) <= currentLayout().halfLength then
		ground = CourtGeometry.surfaceY(position.Z)
	end
	if ground == nil then
		theShadow.Parent = nil
		return
	end
	local t = math.clamp((position.Y - ground) / Data.ShadowMaxHeight, 0, 1)
	local diameter = 2 * RADIUS * (1 - SHADOW_SHRINK * t)
	theShadow.Size = Vector3.new(SHADOW_THICKNESS, diameter, diameter)
	theShadow.Transparency = SHADOW_MIN_TRANSPARENCY + (1 - SHADOW_MIN_TRANSPARENCY) * t
	theShadow.CFrame = CFrame.new(CENTER + Vector3.new(position.X, ground + SHADOW_LIFT, position.Z))
		* CFrame.Angles(0, 0, math.pi / 2)
	theShadow.Parent = Workspace
end

-- Fija el estado a lo que dice el servidor en el instante "t" y lo pone al día de la latencia.
local function setAuthoritative(t: number, pos: Vector3, vel: Vector3, resting: boolean, dead: boolean, curve: number)
	lastT = t
	local before = if hasState then drawn else nil
	BallSim.restore(sim, { pos = pos, vel = vel, resting = resting, curveLeft = curve })
	sim.dead = dead
	hasState = true

	-- Compensa lo que ha tardado el paquete.
	accumulator = math.clamp(Workspace:GetServerTimeNow() - t, 0, Data.Net.MaxCatchUp)
	advance(math.ceil(Data.Net.MaxCatchUp / BallSim.STEP) + 1)

	-- El desvío entre lo que se veía y lo nuevo predicho se disuelve; si es grande, salta.
	offset = Vector3.zero
	if before then
		local gap = before - predictedPosition()
		if gap.Magnitude <= Data.Net.SnapDistance then
			offset = gap
		end
	end
end

local function onState(packet: any)
	if typeof(packet) ~= "table" or typeof(packet.t) ~= "number" then
		return
	end
	if typeof(packet.pos) ~= "Vector3" or typeof(packet.vel) ~= "Vector3" then
		return
	end
	if packet.t <= lastT or ReplicatedStorage:GetAttribute("BallActive") ~= true then
		return -- antiguo, repetido o con la pelota apagada
	end
	local curve = if typeof(packet.curve) == "number" then packet.curve else 0
	setAuthoritative(packet.t, packet.pos, packet.vel, packet.resting == true, packet.dead == true, curve)
end

-- Un golpe (Remotes.BallEvent, kind "hit"). El propio ya se predijo al pulsar: solo se descartan los paquetes
-- de estado anteriores (que traerían la velocidad vieja); un roce propio (Passive) sí se aplica.
local function onHitEvent(event: any)
	if typeof(event.t) ~= "number" or typeof(event.pos) ~= "Vector3" or typeof(event.vel) ~= "Vector3" then
		return
	end
	if event.t <= lastT or ReplicatedStorage:GetAttribute("BallActive") ~= true then
		return
	end
	if event.userId == Players.LocalPlayer.UserId and event.quality ~= "Passive" then
		lastT = event.t
		return
	end
	local curve = if typeof(event.curve) == "number" then event.curve else 0
	setAuthoritative(event.t, event.pos, event.vel, false, false, curve)
end

local function onRender(dt: number)
	if not hasState then
		return
	end
	if sim.dead then
		hide()
		return
	end
	accumulator += dt
	advance(MAX_FRAME_STEPS)
	offset *= math.exp(-dt / Data.Net.SmoothSeconds)
	local position = predictedPosition() + offset
	drawn = position
	render(position)
end

local function onActiveChanged()
	if ReplicatedStorage:GetAttribute("BallActive") == true then
		return
	end
	hasState = false
	lastT = -math.huge
	accumulator = 0
	offset = Vector3.zero
	hide()
end

-- Fija la velocidad (y la curva del Viento, en segundos) de un golpe propio en la pelota predicha (sin esperar al servidor). La posición se queda donde
-- se veía, así que el suavizado no lo toma por un desvío.
function BallController.predictHit(velocity: Vector3, curve: number)
	if not hasState or sim.dead then
		return
	end
	sim.pos = predictedPosition()
	accumulator = 0
	sim.vel = velocity
	sim.curveLeft = curve
	sim.resting = false
end

-- Una copia del estado predicho ahora (con la posición adelantada lo que sobra del paso fijo); nil si no hay.
function BallController.predictedState(): BallSim.State?
	if not hasState or sim.dead then
		return nil
	end
	local copy = BallSim.clone(sim)
	copy.pos = predictedPosition()
	return copy
end

-- Una pelota nueva igual a la del juego, sin padre ni simulación (la repetición del aro la mueve a mano).
function BallController.newBall(): Part
	return newBallPart()
end

-- La pelota que se dibuja (para colgarle el anillo de tiempo); nil si no se ve.
function BallController.part(): Part?
	if ball and ball.Parent then
		return ball
	end
	return nil
end

function BallController:Start()
	Remotes.BallState.OnClientEvent:Connect(onState)
	Remotes.BallEvent.OnClientEvent:Connect(function(event: any)
		if typeof(event) == "table" and event.kind == "hit" then
			onHitEvent(event)
		end
		-- Los sonidos de los eventos: BallSfxController; los avisos de raya: BallgameHUD.
	end)
	ReplicatedStorage:GetAttributeChangedSignal("BallActive"):Connect(onActiveChanged)
	RunService.RenderStepped:Connect(onRender)
end

return BallController
