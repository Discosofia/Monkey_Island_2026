--!strict
-- Id de cada animación de los brazos en primera persona (Shared/Data/ViewModelAnimations): el publicado o, en
-- Studio y mientras esté vacío, uno temporal de la secuencia "<arma>_<clave>" que deja en ReplicatedStorage el
-- generador (ServerStorage.Tools.ViewModelAnimationBuilder). Como CombatClient/WeaponAnimationIds.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ViewModelAnimations = require(ReplicatedStorage.Shared.Data.ViewModelAnimations)

local STUDIO_FOLDER = "ViewModelAnimations"

local ViewModelAnimationIds = {}

-- Ids temporales de Studio de las secuencias generadas, por nombre (se registran una vez).
local studioIds: { [string]: string } = {}

-- Id de la animación "key" del arma "weaponId"; nil si no hay ninguno (entonces se usa el respaldo por código).
function ViewModelAnimationIds.get(weaponId: string, key: string): string?
	local published = ViewModelAnimations.ids[weaponId]
	local id = if published then published[key] else nil
	if id and id ~= "" then
		return id
	end
	if not RunService:IsStudio() then
		return nil
	end
	local name = `{weaponId}_{key}`
	local cached = studioIds[name]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:FindFirstChild(STUDIO_FOLDER)
	local sequence = if folder then folder:FindFirstChild(name) else nil
	if not (sequence and sequence:IsA("KeyframeSequence")) then
		return nil
	end
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	if not ok then
		warn(`[ViewModelAnimationIds] No se pudo usar la animación "{name}" generada: {result}`)
		return nil
	end
	studioIds[name] = result
	return result
end

return ViewModelAnimationIds
