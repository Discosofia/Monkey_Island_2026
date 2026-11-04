--!strict
-- Reglas del combate en el Lobby (ServerScriptService.Combat.CombatRules): las habilidades y las
-- armas del rol se pueden probar en la plaza y contra los muñecos de práctica (LobbyDummyService),
-- pero nunca afectan a otros jugadores:
--   - No se puede herir a nadie (canHitPlayer se queda en el valor neutro: nunca), así que tampoco se
--     aturde, duerme, ralentiza, marca, empuja ni atrapa en el cepo a otro jugador.
--   - Nadie es aliado: curaciones, escudos, el Grito de guerra y el Tótem sanador solo van a uno mismo.
-- Lo demás se queda en los valores neutros: munición infinita, sin fiebre ni telemetría, y practicar
-- no cuenta para las misiones del día.
-- Modo shooter del campo de tiro (Fase 24b, RangeShooterService): con el atributo "ShooterWeapon" (un arma del
-- Laboratorio colgada en el Armero) el jugador lleva solo esa arma, con el cargador, la recarga y la dispersión
-- del Laboratorio (Combat/LabMagazine), y sin habilidades ni guardia. Sin él, todo igual que antes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LabSpread = require(ReplicatedStorage.Shared.LabSpread)
local LabWeapons = require(ReplicatedStorage.Shared.Data.LabWeapons)
local CombatRules = require(ServerScriptService.Combat.CombatRules)
local LabMagazine = require(ServerScriptService.Combat.LabMagazine)

local LobbyCombatRules = {}

-- El arma del Laboratorio que lleva "player" en el modo shooter, o nil.
local function shooterWeapon(player: Player): string?
	local weaponId = player:GetAttribute("ShooterWeapon")
	if typeof(weaponId) == "string" and table.find(LabWeapons.ORDER, weaponId) then
		return weaponId
	end
	return nil
end

function LobbyCombatRules:Init()
	CombatRules.set({
		-- En la plaza se corre sin gastar estamina.
		movement = {
			staminaFree = true,
			slide = true,
			dodgeStyle = "Roll",
			slideKey = "LeftAlt",
			slideFromWalk = false,
		},
		zones = true,
		roleWeapons = function(player: Player): { string }?
			local weaponId = shooterWeapon(player)
			return if weaponId then { weaponId } else nil
		end,
		takeShot = function(player: Player, weaponId: string, weapon: any, zoomed: boolean): number?
			if shooterWeapon(player) and LabWeapons.weapons[weaponId] then
				return LabMagazine.takeShot(player, weaponId, weapon, zoomed)
			end
			return LabSpread.hip(weapon, zoomed)
		end,
		abilities = function(player: Player): boolean
			return shooterWeapon(player) == nil
		end,
		guard = function(player: Player): boolean
			return shooterWeapon(player) == nil
		end,
		isAlly = function(): boolean
			return false
		end,
	})
end

return LobbyCombatRules
