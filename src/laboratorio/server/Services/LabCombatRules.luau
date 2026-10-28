--!strict
-- Reglas del combate del Laboratorio en ruinas (Fase 13, docs/LABORATORIO.md §2;
-- ServerScriptService.Combat.CombatRules):
--   - Sin roles, habilidades, combos, talentos ni guardia: cada uno lleva las armas del Laboratorio
--     (Data/LabWeapons) y los disparos entran sin esperar un parry.
--   - Los números de las armas ya son los de PvP: los multiplicadores contra jugadores, a 1. Funciona
--     todo lo que contra los monos: veneno, ralentizar y enredar (pvpStatus).
--   - Un golpe mortal no deja caído: cuenta la baja y se reaparece (LabRespawnService).
--   - Munición infinita.
-- Grupo L1 (sin partida aún): todos contra todos fuera de la protección de salida, y las cuatro armas en
-- la mochila. En la L2 serán por equipos y se elegirá una.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LabWeapons = require(ReplicatedStorage.Shared.Data.LabWeapons)
local CombatRules = require(ServerScriptService.Combat.CombatRules)
local LabRespawnService = require(script.Parent.LabRespawnService)

local LabCombatRules = {}

function LabCombatRules:Init()
	CombatRules.set({
		canHitPlayer = function()
			return true
		end,
		isAlly = function()
			return false
		end,
		knockOut = LabRespawnService.knockOut,
		roleWeapons = function()
			return LabWeapons.ORDER
		end,
		abilities = false,
		guard = false,
		pvpDamageMultiplier = 1,
		pvpControlMultiplier = 1,
		pvpUltimateMultiplier = 1,
		pvpWeaponMultiplier = 1,
		pvpStatus = true,
	})
end

return LabCombatRules
