--!strict
-- Música de la Isla (Fase 6): elige la pista según lo que pasa (jefe cerca, asedio, noche final,
-- noche o día). Las pistas se configuran en Shared/Data/Sounds; la que no tenga ID usa la de Day.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Music = require(ReplicatedStorage.Shared.UI.Music)
local Sounds = require(ReplicatedStorage.Shared.Data.Sounds)

local BOSS_MUSIC_DISTANCE = 200

local AudioController = {}

local function chooseTrack(): string
	local character = Players.LocalPlayer.Character
	local bossPosition = ReplicatedStorage:GetAttribute("BossPosition")
	if
		character
		and typeof(bossPosition) == "Vector3"
		and (character:GetPivot().Position - bossPosition).Magnitude <= BOSS_MUSIC_DISTANCE
	then
		return "Boss"
	end
	if ReplicatedStorage:GetAttribute("FinalNight") == true then
		return "FinalNight"
	end
	local siege = ReplicatedStorage:GetAttribute("SiegeStatus")
	if typeof(siege) == "string" and string.find(siege, "⚔️", 1, true) then
		return "Siege"
	end
	local state = MatchState.read()
	return if state and state.phase == "Night" then "Night" else "Day"
end

-- Con una sola pista (Day) suena siempre la misma sin reiniciarse al cambiar de situación.
local function withFallback(track: string): string
	local id = (Sounds.Music :: { [string]: string })[track]
	return if id and id ~= "" then track else "Day"
end

function AudioController:Start()
	Music.setVolume(Sounds.IslandMusicVolume)
	Music.bindMuteKey()
	while true do
		Music.play(withFallback(chooseTrack()))
		task.wait(1)
	end
end

return AudioController
