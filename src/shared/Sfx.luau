--!strict
-- Efectos de sonido en el mundo (Fase 6). Los efectos se configuran en Shared/Data/Sounds.Effects.
-- Desde el servidor se oyen en todos los clientes (el sonido se replica); desde un cliente, solo en él.
--   Sfx.play("Chop", parte)      suena pegado a la parte (y la sigue si se mueve)
--   Sfx.play("Thunder", posición) suena en ese punto del mundo
--   Sfx.playLocal("HitBody", 0.6) suena en 2D, solo en este cliente
-- Si el efecto tiene varias variantes en "id", cada vez suena una al azar.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Sounds = require(script.Parent.Data.Sounds)

local DEFAULT_RANGE = 90
local LIFETIME = 6

local Sfx = {}

local rng = Random.new()

-- El ID que suena: el único, o uno al azar de la lista de variantes (saltando los vacíos).
local function pickId(id: string | { string }): string?
	if typeof(id) == "string" then
		return if id ~= "" then id else nil
	end
	local options = {}
	for _, option in id do
		if option ~= "" then
			table.insert(options, option)
		end
	end
	return if #options > 0 then options[rng:NextInteger(1, #options)] else nil
end

function Sfx.play(key: string, at: Vector3 | Instance)
	local effect = Sounds.Effects[key]
	local soundId = if effect then pickId(effect.id) else nil
	if not effect or not soundId then
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
	sound.SoundId = soundId
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

-- Suena en 2D, sin posición, solo en este cliente (confirmaciones de impacto, avisos de la interfaz).
-- "volume" sustituye al del efecto.
function Sfx.playLocal(key: string, volume: number?)
	local effect = Sounds.Effects[key]
	local soundId = if effect then pickId(effect.id) else nil
	if not effect or not soundId then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = `Sfx_{key}`
	sound.SoundId = soundId
	sound.Volume = volume or effect.volume
	sound.PlaybackSpeed = effect.pitch * (1 + rng:NextNumber(-1, 1) * (effect.jitter or 0))
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, LIFETIME)
end

return Sfx
