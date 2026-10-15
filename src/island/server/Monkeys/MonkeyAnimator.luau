--!strict
-- Reproduce las animaciones de los monos y los jefes (Data/MonkeyAnimations) en el servidor; el
-- Animator del Humanoid las replica solo a los clientes.
--   - Idle, Walk y Run cambian solas según la velocidad del mono.
--   - Las acciones (Attack, Roar…) las lanza MonkeyService / BossService con MonkeyAnimator.play.
-- Las que no tienen ID todavía se ignoran sin error. Las pistas se cargan la primera vez que se usan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonkeyAnimations = require(ReplicatedStorage.Shared.Data.MonkeyAnimations)

export type Action = MonkeyAnimations.Action

type Rig = {
	animator: Animator,
	ids: { [string]: string }, -- acción → ID ya resuelto (especie/jefe o Default)
	tracks: { [string]: AnimationTrack },
	locomotion: AnimationTrack?, -- Idle, Walk o Run, la que suena ahora
}

local LOOPED: { [string]: boolean } = { Idle = true, Walk = true, Run = true }

local MonkeyAnimator = {}

local rigs: { [Model]: Rig } = {}
local animations: { [string]: Animation } = {}

local function resolveIds(model: Model): { [string]: string }
	local ids: { [string]: string } = table.clone(MonkeyAnimations.Default)
	-- La especie primero y el jefe encima, que es más concreto.
	for _, attribute in { "MonkeyType", "Boss" } do
		local key = model:GetAttribute(attribute)
		local overrides = if typeof(key) == "string" then MonkeyAnimations.Overrides[key] else nil
		for action, id in overrides or {} do
			ids[action] = id
		end
	end
	return ids
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
	newTrack.Looped = LOOPED[action] == true
	newTrack.Priority = if action == "Idle"
		then Enum.AnimationPriority.Idle
		elseif LOOPED[action] then Enum.AnimationPriority.Movement
		elseif action == "Death" then Enum.AnimationPriority.Action4
		else Enum.AnimationPriority.Action
	rig.tracks[action] = newTrack
	return newTrack
end

local function setLocomotion(rig: Rig, speed: number)
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
	local rig: Rig = { animator = animator, ids = resolveIds(model), tracks = {}, locomotion = nil }
	rigs[model] = rig
	setLocomotion(rig, 0)
	humanoid.Running:Connect(function(speed)
		if humanoid.Health > 0 then
			setLocomotion(rig, speed)
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
		actionTrack:Play(0.1)
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
