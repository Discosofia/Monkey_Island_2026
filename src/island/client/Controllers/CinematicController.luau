--!strict
-- Cinemáticas del juego (Fase 25). La lógica está en Shared/Cinematics/CinematicClient.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CinematicClient = require(ReplicatedStorage.Shared.Cinematics.CinematicClient)

local CinematicController = {}

function CinematicController:Start()
	CinematicClient.start("Island")
end

return CinematicController
