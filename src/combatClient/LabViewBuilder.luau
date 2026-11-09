--!strict
-- Monta el arma y los brazos de la primera persona del Laboratorio (Fase 19 W10, extraído en Fase 25 G12 de
-- FirstPersonController.refresh para que lo use también el motor de cinemáticas, Cinematics/LabActor, evento
-- fpView). Hace lo mismo que hacía el controlador:
--   - Construye el arma (Shared/LabWeaponModels) con su modelo de apuntado (Shared/LabAimModels) en una Tool suelta
--     y pasa sus piezas a un modelo, sin las "LabBack" de la espalda (taparían la mira) ni las partículas.
--   - Reparte las piezas entre las de perfil (hipParts) y las del modelo de apuntado (aimParts); sin modelo de
--     apuntado, hipParts queda vacío y el arma de perfil no cambia.
--   - Monta el rig de brazos (Shared/LabViewModelRig), lo cuelga de "parent", lo escala con Config.Lab.ViewScale
--     y carga las pistas de ViewModelAnimations del arma (las que tienen id).
-- Quien lo llama coloca rig.root cada fotograma (el controlador, pegado a la cámara) y destruye rig.model.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LabAimModels = require(ReplicatedStorage.Shared.LabAimModels)
local LabViewModelRig = require(ReplicatedStorage.Shared.LabViewModelRig)
local LabWeaponModels = require(ReplicatedStorage.Shared.LabWeaponModels)
local ViewModelAnimations = require(ReplicatedStorage.Shared.Data.ViewModelAnimations)
local ViewModelAnimationIds = require(script.Parent.ViewModelAnimationIds)

export type View = {
	rig: LabViewModelRig.Rig,
	tracks: { [string]: AnimationTrack },
	hipParts: { BasePart },
	aimParts: { BasePart },
	viewMuzzle: Instance?,
}

local LabViewBuilder = {}

-- Dónde va la mano respecto a la cámara en reposo (derecha, arriba, delante) y cuánto se gira el arma hacia el
-- centro: los usa FirstPersonController y la vista de la cinemática, para que coincidan.
LabViewBuilder.HIP_OFFSET = Vector3.new(1.25, -1.45, -3.0)
LabViewBuilder.HIP_YAW = math.rad(16)
LabViewBuilder.HIP_PITCH = 0.08

-- Carga las pistas de ViewModelAnimations del arma "weaponId" en el Animator del rig (las que tienen id).
local function loadTracks(rig: LabViewModelRig.Rig, weaponId: string): { [string]: AnimationTrack }
	local tracks: { [string]: AnimationTrack } = {}
	for _, key in ViewModelAnimations.KEYS do
		local id = ViewModelAnimationIds.get(weaponId, key)
		if id then
			local animation = Instance.new("Animation")
			animation.Name = `{weaponId}_{key}`
			animation.AnimationId = id
			local ok, track = pcall(function()
				return rig.animator:LoadAnimation(animation)
			end)
			if ok then
				tracks[key] = track
			else
				warn(`[LabViewBuilder] No se pudo cargar la animación "{animation.Name}": {track}`)
			end
		end
	end
	return tracks
end

-- La boca del arma de la vista (su pieza o Attachment "Muzzle" o, si no, el Handle).
function LabViewBuilder.muzzleOf(model: Instance): Instance?
	return model:FindFirstChild("Muzzle", true) or model:FindFirstChild("Handle", true)
end

-- Monta la vista del arma "weaponId" con la facción y la skin dadas ("skinColor": el tono de piel de las manos).
-- El rig queda colgado de "parent" (la cámara); rig.root se coloca fuera.
function LabViewBuilder.build(
	weaponId: string,
	faction: LabViewModelRig.Faction,
	skinId: string?,
	skinColor: Color3,
	parent: Instance
): View
	-- Las piezas se hacen en una Tool suelta y se pasan a un modelo pegado a la cámara.
	local holder = Instance.new("Tool")
	local handle = LabWeaponModels.build(holder, weaponId, faction, skinId)
	LabAimModels.add(handle, weaponId, faction, skinId)
	local weaponModel = Instance.new("Model")
	for _, part in holder:GetChildren() do
		-- Las piezas de la espalda de la skin taparían la mira: solo las ven los demás.
		if part:GetAttribute("LabBack") then
			part:Destroy()
		else
			part.Parent = weaponModel
		end
	end
	holder:Destroy()
	local hipParts: { BasePart } = {}
	local aimParts: { BasePart } = {}
	for _, descendant in weaponModel:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			table.insert(if descendant:GetAttribute("LabAim") then aimParts else hipParts, descendant)
		end
	end
	if #aimParts == 0 then
		hipParts = {}
	end
	-- El rig se queda con las piezas del arma (soldadas al Handle) y les pone los brazos.
	local rig = LabViewModelRig.build(weaponModel, handle, faction, skinColor)
	rig.model.Parent = parent
	-- Las armas y los brazos de la vista se ven más pequeños (Config.Lab.ViewScale), alrededor de la mano.
	rig.model:ScaleTo(Config.Lab.ViewScale)
	return {
		rig = rig,
		tracks = loadTracks(rig, weaponId),
		hipParts = hipParts,
		aimParts = aimParts,
		viewMuzzle = LabViewBuilder.muzzleOf(rig.model),
	}
end

return LabViewBuilder
