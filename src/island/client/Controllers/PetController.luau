--!strict
-- Mascotas que siguen a los jugadores (Fase 5). La lógica está en Shared/UI/PetFollowers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetFollowers = require(ReplicatedStorage.Shared.UI.PetFollowers)

local PetController = {}

function PetController:Start()
	PetFollowers.start()
end

return PetController
