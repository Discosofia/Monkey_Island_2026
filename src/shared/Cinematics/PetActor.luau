--!strict
-- Mascotas como actores de las cinemáticas (Fase 25, G7a). Se usa como actor `kind = "prop"`:
--   actors = { perro = { kind = "prop", build = function() return PetActor.build("Perro", skin) end } }
-- PetActor.build construye la mascota (PetModels), espera a sus mallas, la deja sin colisión y la anima en un bucle
-- Heartbeat propio, que se corta solo cuando el modelo se destruye (Actors.cleanup destruye los props al acabar la
-- escena). No son seguidores: PetFollowers.setHidden solo esconde su carpeta "Mascotas", y estas cuelgan del Workspace.
--   PetActor.preload(petId)               pide las mallas antes de la escena (build espera como mucho MESH_WAIT segundos).
--   PetActor.play(model, clip, loop?)     pone un clip desde su principio; sin loop, al acabar vuelve a ninguno.
--   PetActor.setMoving(model, moving)     0 a 1: cuánto anda; sin clip, mezcla "Run" y "Walk" como PetFollowers.
--   PetActor.stop(model)                  quita el clip y deja de andar.
-- PetActor.install(Sequencer) registra el evento
--   petClip { actor, clip?, loop?, moving? }  clip = nombre del clip (play) o false (stop); moving = setMoving.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetModels = require(script.Parent.Parent.PetModels)
local Sequencer = require(script.Parent.Sequencer)

local PetActor = {}

local MESH_WAIT = 6 -- segundos como mucho esperando a las mallas
local MESH_POLL = 0.05
local RUN_FROM = 0.5 -- moving a partir del cual empieza a mezclarse "Run" (y "Walk" cede)
local RUN_RATE = 5 -- rapidez con que se funde Run/Walk
local CADENCE_MIN, CADENCE_MAX = 0.7, 1.7 -- reloj de zancada, como PetFollowers
local CADENCE_PER_MOVING = 12 / 14 -- PetFollowers: moving = velocidad/12 y cadencia = velocidad/14

type State = {
	clip: string?,
	clipTime: number,
	loop: boolean,
	moving: number,
	clock: number,
	stride: number,
	run: number, -- peso suavizado de "Run"
}

local states: { [Model]: State } = {}
local connection: RBXScriptConnection? = nil

local function layersOf(model: Model, state: State, dt: number): { PetModels.Layer }
	local clips = PetModels.clips(model)
	local layers: { PetModels.Layer } = {}
	local clipName = state.clip
	local clipLength = if clipName then clips[clipName] else nil
	if clipName and clipLength then
		local time = if state.loop then state.clipTime % clipLength else state.clipTime
		table.insert(layers, { clip = clipName, time = time, weight = 1 })
		if not state.loop and state.clipTime >= clipLength then
			state.clip = nil -- el clip acabó: vuelve a ninguno
		end
	elseif clipName then
		state.clip = nil -- la mascota no tiene ese clip
	end
	-- Sin clip puesto, andar mezcla Run (galope) y Walk según moving, igual que PetFollowers.
	local walking = state.clip == nil and state.moving > 0
	local runGoal = if walking and clips.Run then math.clamp((state.moving - RUN_FROM) / (1 - RUN_FROM), 0, 1) else 0
	state.run += (runGoal - state.run) * math.clamp(dt * RUN_RATE, 0, 1)
	if state.run > 0.01 then
		table.insert(layers, { clip = "Run", time = state.stride, weight = state.run })
	end
	if walking and clips.Walk then
		local weight = state.moving * (1 - state.run)
		if weight > 0.01 then
			table.insert(layers, { clip = "Walk", time = state.stride, weight = weight })
		end
	end
	return layers
end

local function step(dt: number)
	for model, state in states do
		state.clock += dt
		state.clipTime += dt
		state.stride += dt * math.clamp(state.moving * CADENCE_PER_MOVING, CADENCE_MIN, CADENCE_MAX)
		local layers = layersOf(model, state, dt)
		PetModels.animate(model, state.clock, state.moving, layers, state.stride, 0)
	end
end

local function track(model: Model)
	states[model] = { clip = nil, clipTime = 0, loop = false, moving = 0, clock = 0, stride = 0, run = 0 }
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
	model.Destroying:Connect(function()
		states[model] = nil
		if connection and next(states) == nil then
			connection:Disconnect()
			connection = nil
		end
	end)
end

function PetActor.preload(petId: string)
	PetModels.preload(petId)
end

-- Construye la mascota "petId" (con la skin "skinId" si le vale) ya animándose. Espera a las mallas hasta MESH_WAIT
-- segundos (yield): para que no se note, llama antes a PetActor.preload. Si no existe, devuelve un Model vacío con aviso.
function PetActor.build(petId: string, skinId: string?): Model
	PetModels.preload(petId)
	local waited = 0
	while PetModels.meshStatus(petId) == "loading" and waited < MESH_WAIT do
		task.wait(MESH_POLL)
		waited += MESH_POLL
	end
	local pet = PetModels.build(petId, skinId)
	if not pet then
		warn(`PetActor: no se puede construir la mascota {petId}`)
		local empty = Instance.new("Model")
		empty.Name = `Mascota_{petId}`
		pet = empty
	end
	for _, descendant in pet:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	pet.Parent = Workspace
	track(pet)
	return pet
end

function PetActor.play(model: Model, clip: string, loop: boolean?)
	local state = states[model]
	if state then
		state.clip = clip
		state.clipTime = 0
		state.loop = loop == true
	end
end

function PetActor.setMoving(model: Model, moving: number)
	local state = states[model]
	if state then
		state.moving = math.clamp(moving, 0, 1)
	end
end

function PetActor.stop(model: Model)
	local state = states[model]
	if state then
		state.clip = nil
		state.moving = 0
	end
end

function PetActor.install(sequencer: typeof(Sequencer))
	sequencer.registerHandler("petClip", function(event: Sequencer.Event, ctx: Sequencer.Context)
		local actors = ctx.actors
		local model: Model? = if actors and event.actor then actors[event.actor] else nil
		if not model then
			warn(`PetActor: petClip pide un actor que no existe ({event.actor})`)
			return
		end
		if event.clip == false then
			PetActor.stop(model)
		elseif event.clip then
			PetActor.play(model, event.clip, event.loop)
		end
		if event.moving ~= nil then
			PetActor.setMoving(model, event.moving)
		end
	end)
end

return PetActor
