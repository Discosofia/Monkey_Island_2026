--!strict
-- Reproductor de música del cliente (Fase 6): cambia de pista con un fundido suave. La tecla M la
-- silencia o la vuelve a activar; es el mismo ajuste "Música" del panel de Ajustes (Shared/Settings),
-- así que se guarda en el perfil.

local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Settings = require(script.Parent.Parent.Settings)
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

-- Pone la pista "track" (clave de Sounds.Music, o cualquier nombre si se le pasa su "id"). Si no tiene
-- ID, se queda en silencio.
function Music.play(track: string, id: string?)
	if track == currentTrack then
		return
	end
	currentTrack = track
	if current then
		fadeOut(current)
		current = nil
	end
	local soundId = id or (Sounds.Music :: { [string]: string })[track]
	if not soundId or soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = `Music_{track}`
	sound.SoundId = soundId
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

local function setMuted(value: boolean)
	muted = value
	if current then
		current.Volume = if muted then 0 else volume
	end
end

-- Tecla M para silenciar; sigue también el ajuste "Música" del panel de Ajustes.
function Music.bindMuteKey()
	setMuted(not Settings.get().music)
	Settings.onChanged(function(values)
		setMuted(not values.music)
	end)
	ContextActionService:BindAction("ToggleMusic", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			Settings.set("music", muted)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.M)
end

return Music
