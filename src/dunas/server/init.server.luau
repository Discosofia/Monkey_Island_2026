--!strict
-- Punto de entrada del servidor de la arena de Dunas: carga todos los módulos de la carpeta Services
-- y los del combate compartido con la Isla (ServerScriptService.Combat.Services; sus reglas de la
-- arena están en Services/DunasCombatRules).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Loader = require(ReplicatedStorage.Shared.Loader)

Loader.load({ script.Services, ServerScriptService:WaitForChild("Combat"):WaitForChild("Services") })
