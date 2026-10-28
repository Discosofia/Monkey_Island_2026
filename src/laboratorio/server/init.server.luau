--!strict
-- Punto de entrada del servidor del Laboratorio en ruinas (Fase 13): carga todos los módulos de la
-- carpeta Services y los del combate compartido (ServerScriptService.Combat.Services; sus reglas del
-- Laboratorio están en Services/LabCombatRules).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Loader = require(ReplicatedStorage.Shared.Loader)

Loader.load({ script.Services, ServerScriptService:WaitForChild("Combat"):WaitForChild("Services") })
