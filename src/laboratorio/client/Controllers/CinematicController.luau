--!strict
-- Cinemáticas del juego (Fase 25). La lógica está en Shared/Cinematics/CinematicClient. En el Laboratorio solo hay escenas
-- locales (LabCineController): no hay CinematicService, así que Remotes.Cinematic nunca llega.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CinematicClient = require(ReplicatedStorage.Shared.Cinematics.CinematicClient)

local CinematicController = {}

function CinematicController:Start()
	CinematicClient.start("Laboratorio")
end

return CinematicController
