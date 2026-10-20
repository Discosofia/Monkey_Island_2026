--!strict
-- Punto de entrada del servidor del Lobby: carga todos los módulos de la carpeta Services y los del
-- combate compartido con la Isla y Dunas (ServerScriptService.Combat.Services), para probar las
-- habilidades en la plaza (sus reglas del Lobby están en Services/LobbyCombatRules).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Loader = require(ReplicatedStorage.Shared.Loader)

Loader.load({ script.Services, ServerScriptService:WaitForChild("Combat"):WaitForChild("Services") })
