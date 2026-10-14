--!strict
-- Reproductor de música del cliente (Fase 6): cambia de pista con un fundido suave. La tecla M la
-- silencia o la vuelve a activar.

local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sounds = require(script.Parent.Parent.Data.Sounds)

local FADE_SECONDS = 2

local Music = {}

local current: Sound? = nil
local currentTrack: string? = nil
local muted = false
local volume = Sounds.MusicVolume

local function fadeOut(sound: Sound)
	local tween = TweenService:Create(sound, TweenInfo.new(FADE_SECONDS), { Volume = 0 })
	tween.Completed:Connect(function()
		sound:Destroy()
	end)
	tween:Play()
end

-- Pone la pista "track" (clave de Sounds.Music). Si no tiene ID, se queda en silencio.
function Music.play(track: string)
	if track == currentTrack then
		return
	end
	currentTrack = track
	if current then
		fadeOut(current)
		current = nil
	end
	local id = (Sounds.Music :: { [string]: string })[track]
	if not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = `Music_{track}`
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(FADE_SECONDS), { Volume = if muted then 0 else volume }):Play()
	current = sound
end

-- Volumen de este place (por defecto, Sounds.MusicVolume). Llamar antes de la primera pista.
function Music.setVolume(newVolume: number)
	volume = newVolume
end

-- Tecla M para silenciar.
function Music.bindMuteKey()
	ContextActionService:BindAction("ToggleMusic", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			muted = not muted
			if current then
				current.Volume = if muted then 0 else volume
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.M)
end

return Music
