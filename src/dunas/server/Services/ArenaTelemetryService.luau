--!strict
-- Telemetría de combate de la arena (Fase 10, C7): cuántas veces se usan las mecánicas de defensa y
-- escape (parry, bloqueo, guardia rota, Evasivo, remate de la cadena…), para ver si se usan de verdad en
-- el PvP. La registra DunasCombatRules en CombatRules.telemetry.mechanic; el resto de la telemetría de
-- combate es de la Isla (island/TelemetryService).
-- Como en la Isla, se cuenta durante la partida y se manda junto al terminarla (o al salir el jugador),
-- un evento por cosa con su total (Analytics.event).
--
-- Eventos (valor · campos):
--   Parries, Blocks, GuardBreaks, Evasives, ChainFinishers, Feints, WallBangs, ShotsHit, ShotsMissed,
--   ShotFinishers
--                       veces en la partida · Rol, Place ("Dunas"; los de la Isla llevan "Isla")
--   ArenaMatchPlayed    1 por partida terminada · Rol (para pasar lo demás a "por partida")

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Analytics = require(ServerScriptService.ServerShared.Analytics)
local ArenaMatchService = require(script.Parent.ArenaMatchService)

local ArenaTelemetryService = {}

-- Por jugador: "evento|rol" → veces.
local tallies: { [Player]: { [string]: number } } = {}

local function roleOf(player: Player): string
	local role = player:GetAttribute("Role")
	return if typeof(role) == "string" then role else "SinRol"
end

-- Una mecánica de combate (CombatRules.Mechanic).
function ArenaTelemetryService.mechanic(player: Player, mechanic: string)
	if player.Parent == nil then
		return
	end
	local tally = tallies[player] or {}
	tallies[player] = tally
	local key = `{mechanic}|{roleOf(player)}`
	tally[key] = (tally[key] or 0) + 1
end

local function flush(player: Player)
	local tally = tallies[player]
	tallies[player] = nil
	for key, value in tally or {} do
		local mechanic, role = string.match(key, "^(.-)|(.*)$")
		if mechanic and role then
			Analytics.event(player, mechanic, value, { role, "Dunas" })
		end
	end
end

function ArenaTelemetryService:Start()
	ArenaMatchService.onFinished(function()
		for _, player in Players:GetPlayers() do
			Analytics.event(player, "ArenaMatchPlayed", 1, { roleOf(player) })
			flush(player)
		end
	end)
	Players.PlayerRemoving:Connect(flush)
end

return ArenaTelemetryService
