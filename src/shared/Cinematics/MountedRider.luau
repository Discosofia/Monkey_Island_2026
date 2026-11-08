--!strict
-- Jinete en su montura para las escenas (Fase 25, «Sobrevuelo»). MountedRider.build(mountId, character?, options?)
-- devuelve UN Model con la montura (Shared/MountModels.build, PrimaryPart = Root) y encima una copia del personaje
-- del jugador (sin personaje, un R15 de HumanoidDescription vacía) sentada en su asiento, como en el juego
-- (UI/MountRiders.sync): la raíz del avatar soldada con un Weld al attachment «Seat» del hueso Body, RIDER_LIFT sobre él, y
-- la pose «Ride» de Data/PlayerAnimations puesta en su Animator (en el juego la pone CombatClient/BodyAnimations; aquí se
-- carga directo, porque Shared/Cinematics no depende de CombatClient).
-- Todo sin colisión ni consulta; solo el Root de la montura va anclado, así que el modelo entero se mueve con
-- PivotTo / Tween (evento «move» de Actors). Una escena lo usa como actor «prop»: `build = function() return MountedRider.build(…) end`.
-- Carga todas las pistas de la montura con id (Run, Idle, Jump, Glide, Gesture) y las guarda por modelo.
-- options.pose: «Glide» (por defecto; plano con las alas abiertas), «Idle», «Run» o «Jump»; si la pista no existe, Idle.
--   MountedRider.setPose(model, pose)  fundido de 0,2 s a otra pose (Jump suena una vez y vuelve a la anterior).
--   MountedRider.gesture(model)        la pista Gesture una vez; en su marcador lanza MountModels.gesture (sin pista, el
--                                      efecto directo). Al acabar vuelve a la pose.
--   MountedRider.install(Sequencer)    registra los eventos mountPose { actor, pose } y mountGesture { actor }.
-- Mientras el modelo exista, cada Heartbeat avisa a MountModels.animate (plumas, remolinos, aura; run = 1 si corre,
-- glide = 1 si planea). Se desconecta cuando el modelo se destruye.
-- ¡MountModels.build espera a cargar las mallas! Quien llame no puede reentrar mientras tanto.
-- Solo cliente (las escenas corren en el cliente); sin Remotes, Settings ni CombatClient.

local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local Mounts = require(script.Parent.Parent.Data.Mounts)
local MountModels = require(script.Parent.Parent.MountModels)
local PlayerAnimations = require(script.Parent.Parent.Data.PlayerAnimations)
local RescueCrew = require(script.Parent.RescueCrew)
local Sequencer = require(script.Parent.Sequencer)

local MountedRider = {}

export type Options = { pose: string? }

-- Altura del centro del HumanoidRootPart del jinete sobre el asiento (studs); la misma que UI/MountRiders.
local RIDER_LIFT = 0.35
local DEFAULT_POSE = "Glide"
local FADE = 0.2 -- fundido entre pistas (segundos)

type State = {
	tracks: { [string]: AnimationTrack },
	loaded: boolean, -- las pistas se cargan cuando el modelo ya está en el mundo (ver fillTracks)
	wanted: string, -- pose que se pondrá al cargarlas
	pose: string, -- pose de fondo (la última pedida que no es Jump)
	current: string?, -- pista que suena ahora
	mountId: string,
	glide: number,
	run: number,
}

local states: { [Model]: State } = {}

local LOOPED = { Run = true, Idle = true, Glide = true }

-- Registra el estado del modelo (sin pistas todavía; las carga fillTracks).
local function newState(model: Model, mountId: string, wanted: string): State
	local state: State = {
		tracks = {},
		loaded = false,
		wanted = wanted,
		pose = "Idle",
		current = nil,
		mountId = mountId,
		glide = 0,
		run = 0,
	}
	states[model] = state
	model.Destroying:Connect(function()
		states[model] = nil
	end)
	return state
end

-- Carga todas las pistas de la montura que tengan id (Run, Idle, Jump, Glide, Gesture). Tiene que ser con el modelo ya
-- dentro del DataModel: una pista cargada antes de parentar el modelo solo suena si se reproduce antes de parentarlo, y
-- después se queda con peso 0 y sin avanzar (el Idle del montaje se veía, pero Run, Jump y el gesto no).
local function fillTracks(model: Model, state: State)
	local mountId = state.mountId
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = if controller then controller:FindFirstChildOfClass("Animator") else nil
	if animator then
		for name, id in Mounts[mountId].animations :: { [string]: string } do
			if id ~= "" then
				local animation = Instance.new("Animation")
				animation.AnimationId = id
				local ok, track = pcall(function()
					return (animator :: Animator):LoadAnimation(animation)
				end)
				if ok then
					track.Looped = LOOPED[name] == true
					state.tracks[name] = track
				end
			end
		end
	end
	state.loaded = true
end

-- Pone la pista `name` en bucle con fundido de FADE; para la anterior. Actualiza run y glide del Heartbeat.
local function playLoop(state: State, name: string)
	local track = state.tracks[name] or state.tracks.Idle
	if not state.tracks[name] then
		name = "Idle"
	end
	state.pose = name
	state.run = if name == "Run" then 1 else 0
	state.glide = if name == "Glide" then 1 else 0
	local previous = if state.current then state.tracks[state.current] else nil
	if previous and previous ~= track then
		previous:Stop(FADE)
	end
	if track then
		if not track.IsPlaying then
			track:Play(FADE, 1)
		end
		state.current = name
	else
		state.current = nil
	end
end

-- Reproduce una pista de una sola vez sobre la pose actual; al acabar vuelve a ella. `onMarker` sale en `marker`.
local function playOnce(state: State, name: string, marker: string?, onMarker: (() -> ())?): boolean
	local track = state.tracks[name]
	if not track then
		return false
	end
	local previous = if state.current then state.tracks[state.current] else nil
	local back = state.pose
	if previous and previous ~= track then
		previous:Stop(FADE)
	end
	state.current = name
	if marker and onMarker then
		local signal = track:GetMarkerReachedSignal(marker)
		local connection
		connection = signal:Connect(function()
			connection:Disconnect()
			onMarker()
		end)
	end
	local ended
	ended = track.Stopped:Connect(function()
		ended:Disconnect()
		if state.current == name then
			playLoop(state, back)
		end
	end)
	track:Play(FADE, 1)
	return true
end

-- Pose «Ride» del jinete (a horcajadas, con las riendas). Sin id publicado (vacío) no hay pose y queda de pie.
local function playRiderPose(avatar: Model)
	local ride = PlayerAnimations.Animations.Ride
	if not (RunService:IsRunning() and ride.id ~= "") then
		return
	end
	pcall(function()
		local humanoid = avatar:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			local created = Instance.new("Animator")
			created.Parent = humanoid
			animator = created
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = ride.id
		local track = (animator :: Animator):LoadAnimation(animation)
		track.Looped = true
		track.Priority = ride.priority
		track:Play(0.1, 1)
	end)
end

local function setNoCollision(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
end

function MountedRider.build(mountId: string, character: Model?, options: Options?): Model?
	local pose = if options and options.pose then options.pose else DEFAULT_POSE
	local model = MountModels.build(mountId)
	if not model then
		return nil
	end
	local mountRoot = model.PrimaryPart
	if not mountRoot then
		model:Destroy()
		return nil
	end
	mountRoot.Anchored = true
	setNoCollision(model)

	local seat = model:FindFirstChild("Seat", true)
	if seat and seat:IsA("Attachment") then
		local avatar = RescueCrew.cloneCharacter(character)
		local avatarRoot = if avatar then avatar:FindFirstChild("HumanoidRootPart") else nil
		if avatar and avatarRoot and avatarRoot:IsA("BasePart") then
			avatar.Name = "Jinete"
			RescueCrew.toMotors(avatar)
			RescueCrew.freeze(avatar)
			avatar.PrimaryPart = avatarRoot
			-- El asiento, RIDER_LIFT bajo el centro del HumanoidRootPart; el jinete mira hacia donde la montura.
			local seatLocal = mountRoot.CFrame:PointToObjectSpace(seat.WorldPosition)
			local offset = CFrame.new(seatLocal + Vector3.new(0, RIDER_LIFT, 0))
			avatar:PivotTo(mountRoot.CFrame * offset)
			local weld = Instance.new("Weld")
			weld.Name = "SeatWeld"
			weld.Part0 = mountRoot
			weld.Part1 = avatarRoot
			weld.C0 = offset
			weld.Parent = avatarRoot
			setNoCollision(avatar)
			avatar.Parent = model
			playRiderPose(avatar)
		elseif avatar then
			avatar:Destroy()
		end
	else
		warn(`[MountedRider] La montura {mountId} no tiene el attachment Seat: sin jinete`)
	end

	local state = newState(model, mountId, pose)
	local function start()
		fillTracks(model, state)
		if state.wanted == "Jump" then
			playLoop(state, "Idle")
			playOnce(state, "Jump", nil, nil)
		else
			playLoop(state, state.wanted)
		end
	end
	if model:IsDescendantOf(game) then
		start()
	else
		-- Quien llama lo parenta después (Actors.spawn): se espera a que esté en el mundo.
		local connection
		connection = model.AncestryChanged:Connect(function()
			if model:IsDescendantOf(game) then
				connection:Disconnect()
				start()
			end
		end)
	end

	-- Plumas, remolinos y aura de la montura; el jinete no cuenta como suelo para su sombra.
	local ignore: { Instance } = { model }
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		MountModels.animate(model, deltaTime, state.run, state.glide, ignore)
	end)
	model.Destroying:Connect(function()
		connection:Disconnect()
	end)
	return model
end

-- Baja de antemano las mallas y las texturas de estas monturas, para el campo `prepare` de una escena (como
-- PetActor.preloadAll). Las construye todas a la vez (cada MountModels.build pide sus mallas en paralelo, pero una
-- montura tras otra sumaba sus esperas), sin colgarlas del mundo, precarga el modelo entero con ContentProvider y lo
-- destruye: las mallas quedan en caché y los `build` de la escena ya no esperan. Espera (yield) como mucho
-- PRELOAD_BUILD_WAIT s a las mallas y PRELOAD_CONTENT_WAIT s a las texturas.
local PRELOAD_BUILD_WAIT = 12
local PRELOAD_CONTENT_WAIT = 3

function MountedRider.preloadAll(mountIds: { string })
	local models: { Instance } = {}
	local pending = #mountIds
	for _, mountId in mountIds do
		task.spawn(function()
			local ok, model = pcall(MountModels.build, mountId)
			if ok and model then
				table.insert(models, model)
			end
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < PRELOAD_BUILD_WAIT do
		waited += task.wait()
	end
	if pending > 0 then
		warn("MountedRider: alguna montura no terminó de construirse a tiempo; saldrá a bloques o tardará")
	end
	if #models > 0 then
		local done = false
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(models)
			end)
			done = true
		end)
		local contentWaited = 0
		while not done and contentWaited < PRELOAD_CONTENT_WAIT do
			contentWaited += task.wait()
		end
	end
	for _, model in models do
		model:Destroy()
	end
end

function MountedRider.setPose(model: Model, pose: string)
	local state = states[model]
	if not state then
		return
	end
	if not state.loaded then
		if pose ~= "Jump" then
			state.wanted = pose -- aún sin pistas: se pondrá al cargarlas
		end
		return
	end
	if pose == "Jump" then
		if not playOnce(state, "Jump", nil, nil) then
			return
		end
	else
		playLoop(state, pose)
	end
end

function MountedRider.gesture(model: Model)
	local state = states[model]
	if not (state and state.loaded) then
		return
	end
	local info = Mounts[state.mountId].gesture
	local function effect()
		MountModels.gesture(model, info.effect)
	end
	if not playOnce(state, "Gesture", info.marker, effect) then
		effect()
	end
end

function MountedRider.install(sequencer: typeof(Sequencer))
	local function actorOf(event: Sequencer.Event, ctx: Sequencer.Context, kind: string): Model?
		local actors = ctx.actors
		local model: Model? = if actors and event.actor then actors[event.actor] else nil
		if not model then
			warn(`MountedRider: {kind} pide un actor que no existe ({event.actor})`)
		end
		return model
	end
	sequencer.registerHandler("mountPose", function(event: Sequencer.Event, ctx: Sequencer.Context)
		local model = actorOf(event, ctx, "mountPose")
		if model then
			MountedRider.setPose(model, event.pose or DEFAULT_POSE)
		end
	end)
	sequencer.registerHandler("mountGesture", function(event: Sequencer.Event, ctx: Sequencer.Context)
		local model = actorOf(event, ctx, "mountGesture")
		if model then
			MountedRider.gesture(model)
		end
	end)
end

return MountedRider
