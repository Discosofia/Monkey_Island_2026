--!strict
-- Reproduce las animaciones de los monos y los jefes (Data/MonkeyAnimations) en el servidor; el
-- Animator del Humanoid las replica solo a los clientes.
--   - Idle, Walk y Run cambian solas según la velocidad del mono.
--   - Las acciones (Attack, Roar…) las lanza MonkeyService / BossService con MonkeyAnimator.play.
--   - Los jefes cambian de animaciones al cambiar de fase (atributo "BossPhase", ver
--     MonkeyAnimations.Phases).
--   - Si el modelo tiene expresiones de la cara (spec.faces de un mono voxel), mientras suena una
--     acción se ve la suya (el grito del aullador al llamar a la tropa) y al acabar vuelve la normal.
-- Las que no tienen ID todavía se ignoran sin error. Las pistas se cargan la primera vez que se usan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonkeyAnimations = require(ReplicatedStorage.Shared.Data.MonkeyAnimations)
local MonkeyModels = require(script.Parent.MonkeyModels)

export type Action = MonkeyAnimations.Action

type Rig = {
	model: Model,
	animator: Animator,
	ids: { [string]: string }, -- acción → ID ya resuelto (especie/jefe o Default)
	tracks: { [string]: AnimationTrack },
	locomotion: AnimationTrack?, -- Idle, Walk o Run, la que suena ahora
	speed: number, -- la última velocidad (para volver a elegir Idle/Walk/Run al cambiar de fase)
	faces: boolean, -- tiene expresiones de la cara que cambian con la acción
}

local LOOPED: { [string]: boolean } = { Idle = true, Walk = true, Run = true }
-- Acciones en bucle (con prioridad de acción) que para quien las lanza con MonkeyAnimator.stop.
local LOOPED_ACTIONS: { [string]: boolean } = { Invoke = true }

local MonkeyAnimator = {}

local rigs: { [Model]: Rig } = {}
local animations: { [string]: Animation } = {}

local function resolveIds(model: Model): { [string]: string }
	local ids: { [string]: string } = table.clone(MonkeyAnimations.Default)
	local function apply(overrides: MonkeyAnimations.AnimationSet?)
		for action, id in overrides or {} do
			if id ~= "" then
				ids[action] = id
			end
		end
	end
	-- La especie primero, el jefe encima (es más concreto) y luego cada fase que ya alcanzó.
	for _, attribute in { "MonkeyType", "Boss" } do
		local key = model:GetAttribute(attribute)
		apply(if typeof(key) == "string" then MonkeyAnimations.Overrides[key] else nil)
	end
	local boss = model:GetAttribute("Boss")
	local phases = if typeof(boss) == "string" then MonkeyAnimations.Phases[boss] else nil
	local phase = model:GetAttribute("BossPhase")
	if phases and typeof(phase) == "number" then
		for index = 2, phase do
			apply(phases[index])
		end
	end
	return ids
end

-- Pone la expresión de la acción que suena (si alguna tiene) o la normal.
local function refreshFace(rig: Rig)
	local playing: { string } = {}
	for action, loaded in rig.tracks do
		if loaded.IsPlaying and not LOOPED[action] then
			table.insert(playing, action)
		end
	end
	MonkeyModels.showFace(rig.model, playing)
end

local function track(rig: Rig, action: Action): AnimationTrack?
	local loaded = rig.tracks[action]
	if loaded then
		return loaded
	end
	local id = rig.ids[action]
	if not id or id == "" then
		return nil
	end
	local animation = animations[id]
	if not animation then
		animation = Instance.new("Animation")
		animation.AnimationId = id
		animations[id] = animation
	end
	local newTrack = rig.animator:LoadAnimation(animation)
	newTrack.Looped = LOOPED[action] == true or LOOPED_ACTIONS[action] == true
	newTrack.Priority = if action == "Idle"
		then Enum.AnimationPriority.Idle
		elseif LOOPED[action] then Enum.AnimationPriority.Movement
		elseif action == "Death" then Enum.AnimationPriority.Action4
		else Enum.AnimationPriority.Action
	rig.tracks[action] = newTrack
	if rig.faces and not LOOPED[action] then
		newTrack.Stopped:Connect(function()
			refreshFace(rig)
		end)
	end
	return newTrack
end

local function setLocomotion(rig: Rig, speed: number)
	rig.speed = speed
	local action: Action = "Idle"
	local reference = MonkeyAnimations.WalkReferenceSpeed
	if speed > 0.5 then
		action = "Walk"
		if speed >= MonkeyAnimations.RunThreshold and (rig.ids.Run or "") ~= "" then
			action = "Run"
			reference = MonkeyAnimations.RunReferenceSpeed
		end
	end
	local nextTrack = track(rig, action)
	if nextTrack and nextTrack ~= rig.locomotion then
		if rig.locomotion then
			rig.locomotion:Stop(0.2)
		end
		nextTrack:Play(0.2)
		rig.locomotion = nextTrack
	end
	if nextTrack and action ~= "Idle" then
		nextTrack:AdjustSpeed(math.clamp(speed / reference, 0.5, 2.5))
	end
end

-- Prepara un mono (o jefe) recién aparecido. Llamar después de ponerle sus atributos (MonkeyType, Boss).
function MonkeyAnimator.attach(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not (humanoid and animator) then
		return
	end
	local rig: Rig = {
		model = model,
		animator = animator,
		ids = resolveIds(model),
		tracks = {},
		locomotion = nil,
		speed = 0,
		faces = MonkeyModels.showFace(model, {}),
	}
	rigs[model] = rig
	setLocomotion(rig, 0)
	humanoid.Running:Connect(function(speed)
		if humanoid.Health > 0 then
			setLocomotion(rig, speed)
		end
	end)
	-- Nueva fase del jefe: las pistas cuyo ID cambia se descargan y se vuelven a cargar al usarlas.
	model:GetAttributeChangedSignal("BossPhase"):Connect(function()
		local ids = resolveIds(model)
		for action, loaded in rig.tracks do
			if ids[action] ~= rig.ids[action] then
				if loaded == rig.locomotion then
					rig.locomotion = nil
				end
				loaded:Stop(0.2)
				loaded:Destroy()
				rig.tracks[action] = nil
			end
		end
		rig.ids = ids
		if humanoid.Health > 0 then
			setLocomotion(rig, rig.speed)
		end
	end)
	model.Destroying:Connect(function()
		rigs[model] = nil
	end)
end

-- Reproduce una acción una vez (si tiene animación).
function MonkeyAnimator.play(model: Model, action: Action)
	local rig = rigs[model]
	local actionTrack = if rig then track(rig, action) else nil
	if actionTrack then
		-- Las de bucle (Invoke) entran despacio: pasan del reposo a los brazos en alto.
		actionTrack:Play(if LOOPED_ACTIONS[action] then 0.3 else 0.1)
		if rig and rig.faces then
			refreshFace(rig)
		end
	end
end

-- Para una acción en bucle (Invoke) o una que hay que cortar.
function MonkeyAnimator.stop(model: Model, action: Action)
	local rig = rigs[model]
	local playing = if rig then rig.tracks[action] else nil
	if playing then
		playing:Stop(0.25)
	end
end

-- Al ser derrotado: corta todo. No reproduce Death: el mono desaparece con un "¡puf!" (Combat/Poof)
-- en vez de caerse muerto, para que la violencia sea de caricatura (cuestionario de madurez).
function MonkeyAnimator.die(model: Model)
	local rig = rigs[model]
	if not rig then
		return
	end
	for _, playing in rig.tracks do
		playing:Stop(0.1)
	end
	rig.locomotion = nil
end

return MonkeyAnimator
