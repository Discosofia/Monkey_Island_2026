--!strict
-- Reglas del combate en el Lobby (ServerScriptService.Combat.CombatRules): las habilidades y las
-- armas del rol se pueden probar en la plaza y contra los muñecos de práctica (LobbyDummyService),
-- pero nunca afectan a otros jugadores:
--   - No se puede herir a nadie (canHitPlayer se queda en el valor neutro: nunca), así que tampoco se
--     aturde, duerme, ralentiza, marca, empuja ni atrapa en el cepo a otro jugador.
--   - Nadie es aliado: curaciones, escudos, el Grito de guerra y el Tótem sanador solo van a uno mismo.
-- Lo demás se queda en los valores neutros: munición infinita, sin fiebre ni telemetría, y practicar
-- no cuenta para las misiones del día.

local ServerScriptService = game:GetService("ServerScriptService")

local CombatRules = require(ServerScriptService.Combat.CombatRules)

local LobbyCombatRules = {}

function LobbyCombatRules:Init()
	CombatRules.set({
		-- En la plaza se corre sin gastar estamina.
		movement = { staminaFree = true, slide = true, dodgeStyle = "Roll" },
		isAlly = function(): boolean
			return false
		end,
	})
end

return LobbyCombatRules
