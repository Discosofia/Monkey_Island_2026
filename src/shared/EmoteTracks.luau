--!strict
-- La animación de cada emote (Fase 9, G11c): su "animationId" publicado de Data/Cosmetics o, si está vacío
-- y se juega en Studio, la secuencia que genera ServerStorage.Tools.PlayerAnimationBuilder en
-- ReplicatedStorage.EmoteAnimations (Data/EmoteAnimations), como hace Client/BodyAnimations con los
-- gestos. Lo usan la rueda (UI/EmoteWheel), el Armario (UI/WardrobePanel) y los efectos (UI/EmoteFx).

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)

local STUDIO_FOLDER = "EmoteAnimations"

local EmoteTracks = {}

-- Ids registrados en Studio (cosmético → id) y su inverso.
local studioIds: { [string]: string } = {}
local byId: { [string]: string } = {}

for cosmeticId, cosmetic in Cosmetics do
	if cosmetic.kind == "Emote" and cosmetic.animationId and cosmetic.animationId ~= "" then
		byId[cosmetic.animationId] = cosmeticId
	end
end

-- El id de la animación del emote "cosmeticId", o nil si no tiene (sin publicar fuera de Studio).
function EmoteTracks.id(cosmeticId: string): string?
	local cosmetic = Cosmetics[cosmeticId]
	if not (cosmetic and cosmetic.kind == "Emote") then
		return nil
	end
	if cosmetic.animationId and cosmetic.animationId ~= "" then
		return cosmetic.animationId
	end
	if not RunService:IsStudio() then
		return nil
	end
	local cached = studioIds[cosmeticId]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:FindFirstChild(STUDIO_FOLDER)
	local sequence = if folder then folder:FindFirstChild(cosmeticId) else nil
	if not (sequence and sequence:IsA("KeyframeSequence")) then
		return nil
	end
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	if not ok then
		warn(`[EmoteTracks] No se pudo usar la animación generada de "{cosmeticId}": {result}`)
		return nil
	end
	studioIds[cosmeticId] = result
	byId[result] = cosmeticId
	return result
end

-- El emote al que pertenece una animación que suena (por su AnimationId), o nil.
function EmoteTracks.cosmeticOf(animationId: string): string?
	return byId[animationId]
end

return EmoteTracks
