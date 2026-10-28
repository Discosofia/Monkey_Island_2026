--!strict
-- La mascota activa acompaña a su dueño en el Laboratorio, solo de adorno (no pelea ni da ventajas). La
-- lógica está en Shared/UI/PetFollowers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetFollowers = require(ReplicatedStorage.Shared.UI.PetFollowers)

local PetController = {}

function PetController:Start()
	PetFollowers.start()
end

return PetController
