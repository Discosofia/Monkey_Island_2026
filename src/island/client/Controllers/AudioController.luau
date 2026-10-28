--!strict
-- Música de la Isla (Fase 6): elige la pista según lo que pasa (jefe peleando cerca, asedio, noche
-- final, noche o día). Las pistas se configuran en Shared/Data/Sounds; la que no tenga ID usa la más
-- parecida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Music = require(ReplicatedStorage.Shared.UI.Music)
local Sounds = require(ReplicatedStorage.Shared.Data.Sounds)
local Strings = require(ReplicatedStorage.Shared.Strings)

-- El tema del jefe suena mientras pelea ("BossFighting", BossService) y estás a esta distancia.
local BOSS_MUSIC_DISTANCE = 250

-- Si una situación no tiene pista, usa la más parecida (La Gran Tropa → Asedio → Noche → Día). Con
-- una sola pista (Day) suena siempre la misma sin reiniciarse al cambiar de situación.
local FALLBACK: { [string]: string } = {
	FinalNight = "Siege",
	Siege = "Night",
	Night = "Day",
}

local AudioController = {}

local function hasId(id: string?): boolean
	return id ~= nil and id ~= ""
end

-- Tema del jefe si está peleando cerca: el suyo propio (Sounds.BossMusic) o, si no tiene, Music.Boss.
local function bossTrack(): (string?, string?)
	if ReplicatedStorage:GetAttribute("BossFighting") ~= true then
		return nil, nil
	end
	local character = Players.LocalPlayer.Character
	local bossPosition = ReplicatedStorage:GetAttribute("BossPosition")
	if
		not character
		or typeof(bossPosition) ~= "Vector3"
		or (character:GetPivot().Position - bossPosition).Magnitude > BOSS_MUSIC_DISTANCE
	then
		return nil, nil
	end
	local bossId = ReplicatedStorage:GetAttribute("BossId")
	local theme = if typeof(bossId) == "string" then Sounds.BossMusic[bossId] else nil
	if hasId(theme) then
		return `Boss_{bossId}`, theme
	end
	if hasId(Sounds.Music.Boss) then
		return "Boss", nil
	end
	return nil, nil
end

local function situationTrack(): string
	if ReplicatedStorage:GetAttribute("FinalNight") == true then
		return "FinalNight"
	end
	local siege = ReplicatedStorage:GetAttribute("SiegeStatus")
	if typeof(siege) == "string" and string.find((Strings.unpacked(siege)), "⚔️", 1, true) then
		return "Siege"
	end
	local state = MatchState.read()
	return if state and state.phase == "Night" then "Night" else "Day"
end

local function withFallback(track: string): string
	local music = Sounds.Music :: { [string]: string }
	local current = track
	while current ~= "Day" do
		if hasId(music[current]) then
			return current
		end
		current = FALLBACK[current] or "Day"
	end
	return "Day"
end

function AudioController:Start()
	Music.setVolume(Sounds.IslandMusicVolume)
	Music.bindMuteKey()
	while true do
		local track, id = bossTrack()
		if track then
			Music.play(track, id)
		else
			Music.play(withFallback(situationTrack()))
		end
		task.wait(1)
	end
end

return AudioController
