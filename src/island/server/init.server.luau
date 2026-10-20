--!strict
-- Punto de entrada del servidor de la Isla: carga todos los módulos de la carpeta Services y los del
-- combate compartido con la arena (ServerScriptService.Combat.Services; sus reglas de la Isla están
-- en Services/IslandCombatRules).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Loader = require(ReplicatedStorage.Shared.Loader)

Loader.load({ script.Services, ServerScriptService:WaitForChild("Combat"):WaitForChild("Services") })
