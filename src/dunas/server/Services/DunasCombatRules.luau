--!strict
-- Reglas del combate de la arena (ServerScriptService.Combat.CombatRules):
--   - Solo se pelea durante la partida y contra el otro equipo; los del mismo equipo son aliados
--     (las curaciones y escudos del médico solo van a ellos).
--   - Un golpe mortal no deja caído: cuenta la baja y se reaparece en la base (RespawnService).
--   - Munición infinita (el arco no gasta flechas) y sin dardos venenosos, hacha ni pico.
--   - El daño de armas y habilidades y la duración de los aturdimientos contra jugadores son los de
--     Config.Arena, y funciona todo lo que contra los monos: veneno, ralentizar, marcas, expuesto y
--     los pasos del combo (pvpStatus).
-- Lo demás (fiebre, misiones, telemetría, zona segura) se queda en los valores neutros.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local CombatRules = require(ServerScriptService.Combat.CombatRules)
local RespawnService = require(script.Parent.RespawnService)

local DunasCombatRules = {}

function DunasCombatRules:Init()
	CombatRules.set({
		canHitPlayer = function(attacker: Player, victim: Player): boolean
			local attackerTeam = Arena.teamOf(attacker)
			local victimTeam = Arena.teamOf(victim)
			return Arena.inBattle() and attackerTeam ~= nil and victimTeam ~= nil and attackerTeam ~= victimTeam
		end,
		isAlly = function(healer: Player, player: Player): boolean
			local team = Arena.teamOf(healer)
			return team ~= nil and team == Arena.teamOf(player)
		end,
		knockOut = RespawnService.knockOut,
		pvpDamageMultiplier = Config.Arena.AbilityDamageMultiplier,
		pvpControlMultiplier = Config.Arena.AbilityControlMultiplier,
		pvpUltimateMultiplier = Config.Arena.UltimateDamageMultiplier,
		pvpWeaponMultiplier = Config.Arena.WeaponDamageMultiplier,
		pvpWeaponMultipliers = Config.Arena.WeaponMultipliers,
		healMultiplier = Config.Arena.HealingMultiplier,
		pvpStatus = true,
	})
end

return DunasCombatRules
