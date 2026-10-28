--!strict
-- Reglas del combate del Laboratorio en ruinas (Fase 13, docs/LABORATORIO.md §2;
-- ServerScriptService.Combat.CombatRules):
--   - Sin roles, habilidades, combos, talentos ni guardia: cada uno lleva el arma del Laboratorio que ha
--     elegido (atributo "LabWeapon", LabLoadoutService) y los disparos entran sin esperar un parry.
--   - Solo se pelea durante la partida y contra el otro bando (Shared/Arena); en Todos contra todos, contra
--     cualquiera que no sea uno mismo. En la zona de salida nadie
--     hace ni recibe daño: ni se dispara a quien está dentro ni desde dentro (LabWorldService.inBase).
--   - Los números de las armas ya son los de PvP: los multiplicadores contra jugadores, a 1. Funciona
--     todo lo que contra los monos: veneno, ralentizar y enredar (pvpStatus).
--   - Un golpe mortal no deja caído: cuenta la baja y se reaparece (LabRespawnService). Cada golpe anota
--     quién hirió a quién (onPvPHit), para acreditar al último atacante si la víctima cae del mapa.
--   - Munición infinita.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local LabModes = require(ReplicatedStorage.Shared.LabModes)
local LabWeapons = require(ReplicatedStorage.Shared.Data.LabWeapons)
local CombatRules = require(ServerScriptService.Combat.CombatRules)
local LabRespawnService = require(script.Parent.LabRespawnService)
local LabWorldService = require(script.Parent.LabWorldService)

local LabCombatRules = {}

-- true si "player" está en la zona de salida de su bando.
local function inOwnBase(player: Player, teamId: string): boolean
	local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil and root:IsA("BasePart") and LabWorldService.inBase(teamId, root.Position)
end

function LabCombatRules:Init()
	CombatRules.set({
		movement = { staminaFree = false, slide = true, dodgeStyle = "Dash", slideKey = "C" },
		canHitPlayer = function(attacker: Player, victim: Player): boolean
			if LabModes.isFreeForAll() then
				return Arena.inBattle() and attacker ~= victim
			end
			local attackerTeam = Arena.teamOf(attacker)
			local victimTeam = Arena.teamOf(victim)
			if not (Arena.inBattle() and attackerTeam and victimTeam and attackerTeam ~= victimTeam) then
				return false
			end
			return not (inOwnBase(attacker, attackerTeam) or inOwnBase(victim, victimTeam))
		end,
		isAlly = function(healer: Player, player: Player): boolean
			local team = Arena.teamOf(healer)
			return team ~= nil and team == Arena.teamOf(player)
		end,
		knockOut = LabRespawnService.knockOut,
		onPvPHit = LabRespawnService.recordHit,
		roleWeapons = function(player: Player)
			local weaponId = player:GetAttribute("LabWeapon")
			return {
				if typeof(weaponId) == "string" and LabWeapons.weapons[weaponId]
					then weaponId
					else Config.Lab.DefaultWeapon,
			}
		end,
		abilities = false,
		guard = false,
		pvpDamageMultiplier = 1,
		pvpControlMultiplier = 1,
		pvpUltimateMultiplier = 1,
		pvpWeaponMultiplier = 1,
		pvpStatus = true,
		headshots = true,
	})
end

return LabCombatRules
