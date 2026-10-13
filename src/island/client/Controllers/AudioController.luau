--!strict
-- Música de la Isla (Fase 6): elige la pista según lo que pasa (jefe cerca, asedio, noche final,
-- noche o día). Las pistas se configuran en Shared/Data/Sounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Music = require(ReplicatedStorage.Shared.UI.Music)

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

function AudioController:Start()
	Music.bindMuteKey()
	while true do
		Music.play(chooseTrack())
		task.wait(1)
	end
end

return AudioController
