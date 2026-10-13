--!strict
-- Música del Lobby (Fase 6). La pista se configura en Shared/Data/Sounds (Music.Lobby).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Music = require(ReplicatedStorage.Shared.UI.Music)

local AudioController = {}

function AudioController:Start()
	Music.bindMuteKey()
	Music.play("Lobby")
end

return AudioController
