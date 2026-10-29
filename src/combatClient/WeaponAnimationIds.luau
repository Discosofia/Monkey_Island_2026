--!strict
-- Id de cada animación de arma (Shared/Data/WeaponAnimations): el publicado o, en Studio y mientras esté
-- vacío, uno temporal de la secuencia que deja en ReplicatedStorage el generador
-- (ServerStorage.Tools.WeaponAnimationBuilder). Lo usan WeaponController (el propio jugador) y
-- AbilityFxController / RemoteWeaponPoseController (los demás).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponAnimations = require(ReplicatedStorage.Shared.Data.WeaponAnimations)

local STUDIO_FOLDER = "WeaponAnimations"

local WeaponAnimationIds = {}

-- Ids temporales de Studio de las secuencias generadas, por clave (se registran una vez).
local studioIds: { [string]: string } = {}

-- Id de la animación "key"; nil si no hay ninguno.
function WeaponAnimationIds.get(key: string): string?
	local data = WeaponAnimations[key]
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
		warn(`[WeaponAnimationIds] No se pudo usar la animación "{key}" generada: {result}`)
		return nil
	end
	studioIds[key] = result
	return result
end

return WeaponAnimationIds
