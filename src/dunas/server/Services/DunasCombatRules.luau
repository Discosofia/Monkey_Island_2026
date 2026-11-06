--!strict
-- Reglas del combate de la arena (ServerScriptService.Combat.CombatRules):
--   - Solo se pelea durante la partida y contra el otro equipo; los del mismo equipo son aliados
--     (las curaciones y escudos del médico solo van a ellos).
--   - Un golpe mortal no deja caído: cuenta la baja y se reaparece en la base (RespawnService).
--   - Munición infinita (el arco no gasta flechas) y sin dardos venenosos, hacha ni pico.
--   - El daño de armas y habilidades y la duración de los aturdimientos contra jugadores son los de
--     Config.Arena, y funciona todo lo que contra los monos: veneno, ralentizar, marcas, expuesto y
--     los pasos del combo (pvpStatus).
--   - Telemetría: solo la de las mecánicas de combate (ArenaTelemetryService, Fase 10, C7).
--   - Juego de pelota (Fase 26f): se consulta el modo en cada uso (Shared/ArenaModes), no se re-registra. Ningún
--     daño entre jugadores (canHitPlayer), sin guardia, sin armas ni herramientas (roleWeapons vacío, se repartan
--     de nuevo al cambiar el modo) y una sola habilidad por rol (Shared/RoleAbilities).
-- Lo demás (fiebre, misiones, zona segura) se queda en los valores neutros.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local ArenaModes = require(ReplicatedStorage.Shared.ArenaModes)
local Config = require(ReplicatedStorage.Shared.Config)
local CombatRules = require(ServerScriptService.Combat.CombatRules)
local CombatService = require(ServerScriptService.Combat.Services.CombatService)
local ArenaTelemetryService = require(script.Parent.ArenaTelemetryService)
local RespawnService = require(script.Parent.RespawnService)

local DunasCombatRules = {}

local function inBallgame(): boolean
	return ArenaModes.current() == "Ballgame"
end

function DunasCombatRules:Init()
	-- La telemetría neutra, salvo la de las mecánicas de combate.
	local telemetry = table.clone(CombatRules.get().telemetry)
	telemetry.mechanic = ArenaTelemetryService.mechanic
	CombatRules.set({
		movement = {
			staminaFree = false,
			slide = true,
			dodgeStyle = "Roll",
			slideKey = "LeftAlt",
			slideFromWalk = false,
		},
		canHitPlayer = function(attacker: Player, victim: Player): boolean
			local attackerTeam = Arena.teamOf(attacker)
			local victimTeam = Arena.teamOf(victim)
			return not inBallgame()
				and Arena.inBattle()
				and attackerTeam ~= nil
				and victimTeam ~= nil
				and attackerTeam ~= victimTeam
		end,
		isAlly = function(healer: Player, player: Player): boolean
			local team = Arena.teamOf(healer)
			return team ~= nil and team == Arena.teamOf(player)
		end,
		knockOut = RespawnService.knockOut,
		guard = function(): boolean
			return not inBallgame()
		end,
		-- Sin armas en el Juego de pelota; nil: las del rol.
		roleWeapons = function(): { string }?
			return if inBallgame() then {} else nil
		end,
		pvpDamageMultiplier = Config.Arena.AbilityDamageMultiplier,
		pvpControlMultiplier = Config.Arena.AbilityControlMultiplier,
		pvpUltimateMultiplier = Config.Arena.UltimateDamageMultiplier,
		pvpWeaponMultiplier = Config.Arena.WeaponDamageMultiplier,
		pvpWeaponMultipliers = Config.Arena.WeaponMultipliers,
		healMultiplier = Config.Arena.HealingMultiplier,
		pvpStatus = true,
		zones = true,
		telemetry = telemetry,
	})
end

-- Al cambiar el modo (el primero en llegar lo trae del Lobby) se reparten de nuevo las armas del rol: ninguna en
-- el Juego de pelota, las de siempre fuera de él.
function DunasCombatRules:Start()
	Workspace:GetAttributeChangedSignal("ArenaMode"):Connect(function()
		for _, player in Players:GetPlayers() do
			if player.Character then
				task.spawn(CombatService.refreshRoleWeapons, player)
			end
		end
	end)
end

return DunasCombatRules
