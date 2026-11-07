--!strict
-- Mascotas como actores de las cinemáticas (Fase 25, G7a). Se usa como actor `kind = "prop"`:
--   actors = { perro = { kind = "prop", build = function() return PetActor.build("Perro", skin) end } }
-- PetActor.build construye la mascota (PetModels), espera a sus mallas, la deja sin colisión y la anima en un bucle
-- Heartbeat propio, que se corta solo cuando el modelo se destruye (Actors.cleanup destruye los props al acabar la
-- escena). No son seguidores: PetFollowers.setHidden solo esconde su carpeta "Mascotas", y estas cuelgan del Workspace.
--   PetActor.preload(petId)               pide las mallas antes de la escena (build espera como mucho MESH_WAIT segundos).
--   PetActor.preloadAll(petIds)           lo mismo para varias, esperando a que carguen (campo `prepare` de la escena).
--   PetActor.propBuilder(petId, skin?, ground, yaw, flying?)  la función `build` de un actor `prop`: la mascota ya en el
--                                         suelo (rayo al Terrain) y lista para el evento `move` de Actors.
--   PetActor.play(model, clip, loop?)     pone un clip desde su principio; sin loop, al acabar vuelve a ninguno.
--   PetActor.setMoving(model, moving)     0 a 1: cuánto anda; sin clip, mezcla "Run" y "Walk" como PetFollowers.
--   PetActor.stop(model)                  quita el clip y deja de andar.
-- PetActor.install(Sequencer) registra el evento
--   petClip { actor, clip?, loop?, moving? }  clip = nombre del clip (play) o false (stop); moving = setMoving.

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetMeshes = require(script.Parent.Parent.Data.PetMeshes)
local PetModels = require(script.Parent.Parent.PetModels)
local Sequencer = require(script.Parent.Sequencer)

local PetActor = {}

local MESH_WAIT = 6 -- segundos como mucho esperando a las mallas
local MESH_POLL = 0.05
local RETRY_SECONDS = 1 -- cada cuánto se reintenta la malla que no ha cargado (PetModels no reintenta solo)
local CONTENT_WAIT = 2.5 -- segundos como mucho bajando las texturas (PreloadAsync)
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

-- Descarga las mallas y las texturas de estas mascotas con ContentProvider:PreloadAsync, con tope MESH_WAIT. Tener la
-- malla en caché (PetModels.meshStatus) no basta: su textura se baja al verla por primera vez y, con cortes de medio
-- segundo, la mascota salía como manchas de color liso o sin textura. Se construye cada una sin colgarla del mundo y
-- se precarga el modelo entero (malla y textura de cada pieza, como las va a pedir la escena); luego se destruye.
local function preloadContent(petIds: { string }, maxSeconds: number)
	local models: { Instance } = {}
	for _, petId in petIds do
		if PetMeshes[petId] then
			local ok, model = pcall(PetModels.build, petId)
			if ok and model then
				table.insert(models, model)
			end
		end
	end
	if #models == 0 then
		return
	end
	local done = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(models)
		end)
		done = true
	end)
	local waited = 0
	while not done and waited < maxSeconds do
		task.wait(MESH_POLL)
		waited += MESH_POLL
	end
	for _, model in models do
		model:Destroy()
	end
end

-- Mascotas que preloadAll ya esperó: PetActor.build no las espera otra vez (con siete mascotas, esperarlas una a una
-- sumaba hasta 42 s con la pantalla en negro cuando una malla no llegaba a cargar).
local prepared: { [string]: boolean } = {}

-- Espera (yield) a que las mallas de estas mascotas estén en caché, como mucho "seconds". PetModels.preload no reintenta
-- una malla cuya primera carga falló («Asset content representation is being generated», lo normal la primera vez tras
-- subirla), así que se vuelve a pedir cada RETRY_SECONDS. Devuelve true si cargaron todas.
local function waitMeshes(petIds: { string }, seconds: number): boolean
	local deadline = os.clock() + seconds
	local nextRetry = os.clock() + RETRY_SECONDS
	while true do
		local loading = false
		for _, petId in petIds do
			if PetModels.meshStatus(petId) == "loading" then
				loading = true
				break
			end
		end
		if not loading then
			return true
		end
		if os.clock() >= deadline then
			return false
		end
		if os.clock() >= nextRetry then
			nextRetry += RETRY_SECONDS
			for _, petId in petIds do
				PetModels.preload(petId)
			end
		end
		task.wait(MESH_POLL)
	end
end

function PetActor.preload(petId: string)
	PetModels.preload(petId)
end

-- Pide las mallas de varias mascotas a la vez y espera (yield) a que carguen, como mucho MESH_WAIT segundos en total
-- (con reintentos) y CONTENT_WAIT más para las texturas. Para el campo `prepare` de una escena: así los `build` de sus
-- actores ya no esperan: lo que no haya cargado a tiempo sale a bloques en vez de dejar la pantalla en negro.
function PetActor.preloadAll(petIds: { string })
	for _, petId in petIds do
		PetModels.preload(petId)
	end
	local ready = waitMeshes(petIds, MESH_WAIT)
	if not ready then
		warn("PetActor: alguna malla no cargó a tiempo; esa mascota saldrá a bloques")
	end
	-- Con las mallas en caché, se bajan también sus texturas antes de que arranque la escena.
	preloadContent(petIds, CONTENT_WAIT)
	for _, petId in petIds do
		prepared[petId] = true
	end
end

-- Suelo bajo un punto del mundo (rayo solo contra el Terrain, como snapToTerrain de Actors); sin suelo, el mismo punto.
local SNAP_RAY_UP = 40
local SNAP_RAY_DOWN = 120
local DEFAULT_LIFT = 0.6 -- altura de la raíz si el modelo no dice la suya (como PetFollowers)

local function groundBelow(world: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(world + Vector3.new(0, SNAP_RAY_UP, 0), Vector3.new(0, -SNAP_RAY_DOWN, 0), params)
	return if hit then Vector3.new(world.X, hit.Position.Y, world.Z) else world
end

-- Construye la mascota "petId" (con la skin "skinId" si le vale) ya animándose. Espera a las mallas hasta MESH_WAIT
-- segundos (yield): para que no se note, llama antes a PetActor.preload. Si no existe, devuelve un Model vacío con aviso.
function PetActor.build(petId: string, skinId: string?): Model
	PetModels.preload(petId)
	if not prepared[petId] then
		waitMeshes({ petId }, MESH_WAIT)
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

-- Función `build` para un actor `prop` (ver Actors): la mascota "petId" de pie en "ground" (relativa al anchor, con la
-- Y de reserva si aún no hay terreno), girada "yaw" grados. Deja en el modelo CinematicLift (su Height: raíz a suelo)
-- para que el evento `move` de Actors lo mueva sobre el suelo y, salvo con flying = true (el Quetzal en el aire), le
-- pone CinematicSnap: cada `move` apoya sus pies en el Terrain, con la Y de la escena como reserva.
function PetActor.propBuilder(
	petId: string,
	skinId: string?,
	ground: Vector3,
	yaw: number,
	flying: boolean?
): (anchor: CFrame) -> Model
	return function(anchor: CFrame): Model
		local model = PetActor.build(petId, skinId)
		local height = model:GetAttribute("Height")
		local lift = if typeof(height) == "number" then height else DEFAULT_LIFT
		model:SetAttribute("CinematicLift", lift)
		local world = anchor:PointToWorldSpace(ground)
		if not flying then
			model:SetAttribute("CinematicSnap", true)
			world = groundBelow(world)
		end
		model:PivotTo(
			CFrame.new(world + Vector3.new(0, lift, 0)) * anchor.Rotation * CFrame.Angles(0, math.rad(yaw), 0)
		)
		return model
	end
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
