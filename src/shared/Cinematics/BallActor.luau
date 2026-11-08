--!strict
-- La pelota y la cámara lenta de la cinemática del Juego de pelota (Fase 25, G9a). BallActor.install(Sequencer)
-- registra dos eventos:
--   ballPath { samples, times?, from?, to?, team? }  la pelota recorre `samples` (posiciones relativas al anchor,
--       sin simular nada en el cliente: las precalcula Data/Cinematics con BallSim al construir la escena). Con `times`
--       (un segundo de escena por muestra, creciente) cada muestra sale en su momento; sin él, se reparten a partes
--       iguales entre `from` y `to` (por defecto, desde t del evento). Antes de la primera muestra la pelota no se ve,
--       y al acabar el tramo se queda en la última hasta que otro `ballPath` la mueva. `team` ("Jaguar" o "Quetzal")
--       da el color de la estela. La cámara lenta no es del Sequencer (no tiene escala de tiempo): va metida en los
--       datos, repartiendo las muestras del tiro en más segundos de escena.
--   animSpeed { speed }  cambia la velocidad de todas las pistas de animación que suenan en los actores (la cámara
--       lenta de los maniquíes). Las pistas que empiecen después no se ven afectadas, y al acabar la escena todas
--       vuelven a 1.
-- La pelota es la del juego (esfera de 2 studs, Data/Ballgame.BallColor) con la estela del color del bando, como la
-- de la repetición del aro (BallReplayController). Se guarda en ctx._ball y se borra al acabar la escena.

local Config = require(script.Parent.Parent.Config)
local CourtGeometry = require(script.Parent.Parent.CourtGeometry)
local Data = require(script.Parent.Parent.Data.Ballgame)
local Sequencer = require(script.Parent.Sequencer)

local BallActor = {}

local TRAIL_SECONDS = 0.5
local DEFAULT_TEAM = "Jaguar"

type Path = { times: { number }, samples: { Vector3 }, team: string }
type BallState = { part: Part, trail: Trail, paths: { Path }, known: { [any]: boolean }, current: Path? }

-- La pelota con su estela. Sin padre.
local function makeBall(): (Part, Trail)
	local part = Instance.new("Part")
	part.Name = "CinematicBall"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * (2 * CourtGeometry.BALL_RADIUS)
	part.Color = Data.BallColor
	part.Material = Data.BallMaterial
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, CourtGeometry.BALL_RADIUS * 0.6, 0)
	top.Parent = part
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -CourtGeometry.BALL_RADIUS * 0.6, 0)
	bottom.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = TRAIL_SECONDS
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 0.4
	trail.Parent = part
	return part, trail
end

local function teamColor(team: string): Color3
	local def = Config.Arena.Teams[team]
	return if def then def.color else Data.BallColor
end

-- Posición de la pelota en el segundo t de una trayectoria (lineal entre muestras; se queda en la última).
local function positionAt(path: Path, t: number): Vector3
	local times, samples = path.times, path.samples
	local count = #samples
	if t <= times[1] then
		return samples[1]
	end
	if t >= times[count] then
		return samples[count]
	end
	-- Búsqueda binaria del tramo [lo, lo + 1] que contiene t.
	local lo, hi = 1, count
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if times[mid] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	local span = times[hi] - times[lo]
	return samples[lo]:Lerp(samples[hi], if span > 0 then (t - times[lo]) / span else 1)
end

-- Crea la pelota de la escena (una vez) y la función por cuadro que la coloca.
local function ensure(ctx: Sequencer.Context): BallState
	local existing = ctx._ball
	if existing then
		return existing
	end
	local part, trail = makeBall()
	local state: BallState = { part = part, trail = trail, paths = {}, known = {}, current = nil }
	ctx._ball = state
	local hooks = ctx.frameHooks or {}
	ctx.frameHooks = hooks
	table.insert(hooks, function(t: number)
		-- La trayectoria vigente: la última que ya empezó.
		local chosen: Path? = nil
		for _, path in state.paths do
			if path.times[1] <= t and (chosen == nil or path.times[1] >= (chosen :: Path).times[1]) then
				chosen = path
			end
		end
		if not chosen then
			part.Parent = nil
			state.current = nil
			return
		end
		if chosen ~= state.current then
			state.current = chosen
			trail.Color = ColorSequence.new(teamColor(chosen.team))
			trail:Clear()
		end
		local anchor: CFrame = ctx.anchor or CFrame.identity
		part.Position = anchor:PointToWorldSpace(positionAt(chosen, t))
		part.Parent = workspace
	end)
	return state
end

-- Pone a "speed" todas las pistas que suenan en los actores y apunta cuáles para devolverlas a 1 al acabar.
local function setSpeed(ctx: Sequencer.Context, speed: number)
	local slowed: { [AnimationTrack]: boolean } = ctx._slowedTracks or {}
	ctx._slowedTracks = slowed
	for _, actor in ctx.actors or {} do
		local humanoid = (actor :: Model):FindFirstChildOfClass("Humanoid")
		local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:AdjustSpeed(speed)
				slowed[track] = true
			end
		end
	end
end

function BallActor.install(sequencer: typeof(Sequencer))
	sequencer.registerHandler("ballPath", function(event: Sequencer.Event, ctx: Sequencer.Context)
		local samples: { Vector3 } = event.samples
		local count = #samples
		if count < 1 then
			return
		end
		local state = ensure(ctx)
		if state.known[event] then
			return -- un seek hacia atrás repite los eventos: la trayectoria ya está
		end
		state.known[event] = true
		local times: { number }
		if event.times then
			times = event.times
		else
			local from: number = event.from or event.t
			local to: number = event.to or from
			times = {}
			for index = 1, count do
				times[index] = if count > 1 then from + (to - from) * (index - 1) / (count - 1) else from
			end
		end
		table.insert(state.paths, { times = times, samples = samples, team = event.team or DEFAULT_TEAM })
	end)

	sequencer.registerHandler("animSpeed", function(event: Sequencer.Event, ctx: Sequencer.Context)
		setSpeed(ctx, event.speed or 1)
	end)

	sequencer.addHooks({
		finish = function(_, ctx)
			local state: BallState? = ctx._ball
			if state then
				state.part:Destroy()
				ctx._ball = nil
			end
			local slowed: { [AnimationTrack]: boolean }? = ctx._slowedTracks
			if slowed then
				for track in slowed do
					pcall(function()
						track:AdjustSpeed(1)
					end)
				end
				ctx._slowedTracks = nil
			end
		end,
	})
end

return BallActor
