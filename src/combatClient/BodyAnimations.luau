--!strict
-- Animaciones del cuerpo del jugador local que no son de armas (Shared/Data/PlayerAnimations):
-- gestos de las habilidades, comer, beber, curarse, arrastrarse caído y reanimar. Las reproduce
-- este cliente en su propio personaje, así que los demás también las ven. Solo R15.
-- Como en WeaponController, si un id está vacío y se juega en Studio usa la secuencia generada por
-- ServerStorage.Tools.PlayerAnimationBuilder (ReplicatedStorage.PlayerAnimations).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerAnimations = require(ReplicatedStorage.Shared.Data.PlayerAnimations)

local STUDIO_FOLDER = "PlayerAnimations"

local BodyAnimations = {}

-- Pistas cargadas en el Animator actual (al reaparecer el personaje se cargan de nuevo).
local tracks: { [string]: AnimationTrack } = {}
local tracksAnimator: Animator? = nil
local studioIds: { [string]: string } = {}

local function animationId(key: PlayerAnimations.Key): string?
	local data = PlayerAnimations.Animations[key]
	if data and data.id ~= "" then
		return data.id
	end
	if not RunService:IsStudio() then
		return nil
	end
	local cached = studioIds[key]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:FindFirstChild(STUDIO_FOLDER)
	local sequence = if folder then folder:FindFirstChild(key) else nil
	if not (sequence and sequence:IsA("KeyframeSequence")) then
		return nil
	end
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	if not ok then
		warn(`[BodyAnimations] No se pudo usar la animación "{key}" generada: {result}`)
		return nil
	end
	studioIds[key] = result
	return result
end

local function track(key: PlayerAnimations.Key): AnimationTrack?
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not (humanoid and animator and humanoid.RigType == Enum.HumanoidRigType.R15) then
		return nil
	end
	if animator ~= tracksAnimator then
		tracks = {}
		tracksAnimator = animator
	end
	local cached = tracks[key]
	if cached then
		return cached
	end
	local id = animationId(key)
	if not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, loaded = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		warn(`[BodyAnimations] No se pudo cargar la animación "{key}": {loaded}`)
		return nil
	end
	local data = PlayerAnimations.Animations[key]
	loaded.Priority = data.priority
	loaded.Looped = data.looped == true
	tracks[key] = loaded
	return loaded
end

-- true si "key" se puede reproducir (tiene id publicado o, en Studio, secuencia generada). Da lo
-- mismo en todos los clientes: AbilityFxController lo usa para no duplicar la pose del grito.
function BodyAnimations.has(key: PlayerAnimations.Key): boolean
	return animationId(key) ~= nil
end

-- Reproduce "key" desde el principio. Las de bucle (Crawl, Revive) siguen hasta stop().
function BodyAnimations.play(key: PlayerAnimations.Key, speed: number?)
	local loaded = track(key)
	if loaded then
		loaded:Play(if loaded.Looped then 0.25 else 0.08, 1, speed or 1)
	end
end

function BodyAnimations.stop(key: PlayerAnimations.Key)
	local loaded = tracks[key]
	if loaded and loaded.IsPlaying then
		loaded:Stop(0.25)
	end
end

function BodyAnimations.isPlaying(key: PlayerAnimations.Key): boolean
	local loaded = tracks[key]
	return loaded ~= nil and loaded.IsPlaying
end

function BodyAnimations.setSpeed(key: PlayerAnimations.Key, speed: number)
	local loaded = tracks[key]
	if loaded and loaded.IsPlaying then
		loaded:AdjustSpeed(speed)
	end
end

-- Gesto de una habilidad de Data/Roles, si tiene. Con "castSeconds" (su preparación, C8), el que marca
-- su golpe ("impactSeconds" en Data/PlayerAnimations) se estira para que el golpe caiga cuando sale.
function BodyAnimations.playAbility(abilityId: string, castSeconds: number?)
	local key = PlayerAnimations.Abilities[abilityId]
	if not key then
		return
	end
	local impact = PlayerAnimations.Animations[key].impactSeconds
	local speed = if impact and castSeconds and castSeconds > 0 then impact / castSeconds else 1
	BodyAnimations.play(key, speed)
end

-- Para el gesto de una habilidad (el amago, C8).
function BodyAnimations.stopAbility(abilityId: string)
	local key = PlayerAnimations.Abilities[abilityId]
	if key then
		BodyAnimations.stop(key)
	end
end

return BodyAnimations
