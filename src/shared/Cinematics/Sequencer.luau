--!strict
-- Secuenciador de cinemáticas (Fase 25). Reproduce una escena (datos de Data/Cinematics): mueve la cámara
-- por sus puntos con tiempo y reparte los eventos a las funciones registradas con registerHandler. Un solo
-- bucle RunService.PreRender para todas las escenas en marcha. Sin dependencias de Remotes, Settings ni
-- CombatClient: corre en modo edición. Quien necesita algo del juego (franjas, animaciones, efectos) lo
-- registra desde fuera (Presentation.install, Actors.install y el controlador de cada place).
--
--   scene = { duration, camera = { { t, pos, look, fov? } … }, events = { { t, kind, … } … },
--             actors = { … }, anchor? }
--   Las posiciones de la cámara y de los eventos son relativas a ctx.anchor (CFrame, por defecto identidad).
--   ctx es una tabla libre de quien llama (también la ven los handlers): anchor, onFinished(completed),
--   seeking (lo pone el Sequencer mientras hace seek) y lo que quieran guardar los handlers (ctx.actors…).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraPath = require(script.Parent.CameraPath)

local Sequencer = {}

export type Event = { t: number, kind: string, [string]: any }
export type Scene = {
	duration: number,
	camera: { CameraPath.Point }?,
	events: { Event }?,
	actors: { [string]: any }?,
	anchor: any?,
	[string]: any,
}
export type Context = { [string]: any }
export type Handle = {
	stop: () -> (),
	seek: (t: number) -> (),
	skip: () -> (),
	isPlaying: () -> boolean,
	time: () -> number,
	scene: Scene,
	ctx: Context,
}
export type Handler = (event: Event, ctx: Context, handle: Handle) -> ()
export type Hooks = {
	start: ((scene: Scene, ctx: Context, handle: Handle) -> ())?,
	finish: ((scene: Scene, ctx: Context, completed: boolean) -> ())?,
}

local handlers: { [string]: Handler } = {}
local warned: { [string]: boolean } = {}
local hooks: { Hooks } = {}

-- Escenas en marcha, con su estado interno; el bucle de PreRender existe mientras haya alguna.
type Run = { handle: Handle, update: (dt: number) -> () }
local running: { Run } = {}
local loop: RBXScriptConnection? = nil

-- Registra la función de un tipo de evento. Registrar de nuevo el mismo tipo sustituye al anterior.
function Sequencer.registerHandler(kind: string, fn: Handler)
	handlers[kind] = fn
end

-- Funciones que se llaman al empezar y al terminar cualquier escena (Actors crea y borra sus actores así).
function Sequencer.addHooks(h: Hooks)
	table.insert(hooks, h)
end

local function stopLoopIfIdle()
	if #running == 0 and loop then
		loop:Disconnect()
		loop = nil
	end
end

local function startLoop()
	if loop then
		return
	end
	loop = RunService.PreRender:Connect(function(dt: number)
		for _, run in table.clone(running) do
			run.update(dt)
		end
	end)
end

local function dispatch(event: Event, ctx: Context, handle: Handle)
	local fn = handlers[event.kind]
	if not fn then
		if not warned[event.kind] then
			warned[event.kind] = true
			warn(`Sequencer: evento sin handler registrado ({event.kind}); se ignora`)
		end
		return
	end
	local ok, err = pcall(fn, event, ctx, handle)
	if not ok then
		warn(`Sequencer: falla el evento {event.kind}: {err}`)
	end
end

-- Reproduce "scene". Devuelve el manejador; al terminar (por duración, stop o skip) llama a
-- ctx.onFinished(completed), con completed = true solo si llegó al final.
function Sequencer.play(scene: Scene, ctx: Context?): Handle
	local context: Context = ctx or {}
	local anchor: CFrame = context.anchor or CFrame.identity
	context.anchor = anchor
	context.seeking = false

	-- Eventos ordenados por t (estable: a igual t, el orden en que se escribieron).
	local events: { Event } = {}
	for _, event in scene.events or {} do
		table.insert(events, event)
	end
	local order: { [Event]: number } = {}
	for i, event in events do
		order[event] = i
	end
	table.sort(events, function(a, b)
		if a.t ~= b.t then
			return a.t < b.t
		end
		return order[a] < order[b]
	end)

	-- Cámara en el mundo (la escena la escribe relativa al anchor).
	local points: { CameraPath.Point } = {}
	for i, p in scene.camera or {} do
		points[i] =
			{ pos = anchor:PointToWorldSpace(p.pos), look = anchor:PointToWorldSpace(p.look), fov = p.fov, t = p.t }
	end
	local camera = Workspace.CurrentCamera
	local useCamera = camera ~= nil and #points > 0
	local savedType = if camera then camera.CameraType else Enum.CameraType.Custom
	local savedFov = if camera then camera.FieldOfView else CameraPath.DEFAULT_FOV

	local elapsed = 0
	local cursor = 1
	local playing = true
	local run: Run
	local handle: Handle

	local function placeCamera()
		if not (useCamera and camera) then
			return
		end
		local pos, look, fov = CameraPath.sampleTimed(points, elapsed)
		camera.FieldOfView = fov
		camera.CFrame = CFrame.lookAt(pos, look)
	end

	-- Reparte los eventos con t <= elapsed que aún no se han lanzado.
	local function fireDue()
		while cursor <= #events and events[cursor].t <= elapsed do
			local event = events[cursor]
			cursor += 1
			dispatch(event, context, handle)
		end
	end

	local function finish(completed: boolean)
		if not playing then
			return
		end
		playing = false
		local index = table.find(running, run)
		if index then
			table.remove(running, index)
		end
		stopLoopIfIdle()
		if useCamera and camera then
			camera.FieldOfView = savedFov
			if RunService:IsEdit() then
				camera.CameraType = Enum.CameraType.Fixed
			else
				camera.CameraType = if savedType == Enum.CameraType.Scriptable
					then Enum.CameraType.Custom
					else savedType
			end
		end
		for _, h in hooks do
			if h.finish then
				h.finish(scene, context, completed)
			end
		end
		local onFinished = context.onFinished
		if onFinished then
			onFinished(completed)
		end
	end

	handle = {
		scene = scene,
		ctx = context,
		isPlaying = function()
			return playing
		end,
		time = function()
			return elapsed
		end,
		stop = function()
			finish(false)
		end,
		skip = function()
			finish(false)
		end,
		seek = function(t: number)
			if not playing then
				return
			end
			t = math.clamp(t, 0, scene.duration)
			if t < elapsed then
				cursor = 1 -- hacia atrás: se repiten los eventos hasta t
			end
			elapsed = t
			context.seeking = true
			fireDue()
			context.seeking = false
			placeCamera()
		end,
	}
	run = {
		handle = handle,
		update = function(dt: number)
			if not playing then
				return
			end
			elapsed = math.min(elapsed + dt, scene.duration)
			placeCamera()
			fireDue()
			if playing and elapsed >= scene.duration then
				finish(true)
			end
		end,
	}

	if useCamera and camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	table.insert(running, run)
	startLoop()
	for _, h in hooks do
		if h.start then
			h.start(scene, context, handle)
		end
	end
	placeCamera()
	fireDue() -- los eventos de t = 0 salen ya, sin esperar al primer cuadro
	return handle
end

return Sequencer
