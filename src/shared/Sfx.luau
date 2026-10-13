--!strict
-- Efectos de sonido en el mundo (Fase 6). Los efectos se configuran en Shared/Data/Sounds.Effects.
-- Desde el servidor se oyen en todos los clientes (el sonido se replica); desde un cliente, solo en él.
--   Sfx.play("Chop", parte)      suena pegado a la parte (y la sigue si se mueve)
--   Sfx.play("Thunder", posición) suena en ese punto del mundo

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Sounds = require(script.Parent.Data.Sounds)

local DEFAULT_RANGE = 90
local LIFETIME = 6

local Sfx = {}

local rng = Random.new()

function Sfx.play(key: string, at: Vector3 | Instance)
	local effect = Sounds.Effects[key]
	if not effect or effect.id == "" then
		return
	end
	local parent: Instance
	if typeof(at) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.Name = `Sfx_{key}`
		attachment.Parent = Workspace.Terrain
		attachment.WorldPosition = at
		Debris:AddItem(attachment, LIFETIME)
		parent = attachment
	else
		parent = at
	end
	local sound = Instance.new("Sound")
	sound.Name = `Sfx_{key}`
	sound.SoundId = effect.id
	sound.Volume = effect.volume
	sound.PlaybackSpeed = effect.pitch * (1 + rng:NextNumber(-1, 1) * (effect.jitter or 0))
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = effect.range or DEFAULT_RANGE
	sound.PlayOnRemove = false
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, LIFETIME)
end

return Sfx
