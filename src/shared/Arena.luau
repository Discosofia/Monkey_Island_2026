--!strict
-- Estado de la partida de la arena de Dunas (captura la bandera), que lee cualquiera y solo cambia
-- el servidor (ArenaMatchService, TeamService…). Va en atributos para que llegue solo a los clientes:
--   ReplicatedStorage:
--     "ArenaPhase"        fase (Phase, abajo)
--     "ArenaPhaseEndsAt"  hora del servidor en que acaba la fase (nil si no tiene fin fijo)
--     "ArenaFormat"       jugadores por equipo (1..5)
--     "ArenaScore_<id>"   capturas de cada equipo
--     "ArenaWinner"       equipo ganador en los resultados ("" si es empate)
--   Jugador:
--     "Team"              equipo ("Jaguar" | "Quetzal"), nil mientras no elige
--     "ArenaReady"        ha pulsado "Listo"
--     "RespawnAt"         hora del servidor en que reaparece (nil si está vivo)
--     "ArenaKills", "ArenaDeaths", "ArenaCaptures"  sus números de esta partida

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

-- Waiting: elegir equipo, rol y equipo; Countdown: cuenta atrás con las puertas cerradas;
-- Battle: la partida; SuddenDeath: empate al acabar el tiempo, la siguiente captura gana;
-- Results: resultados y votación.
export type Phase = "Waiting" | "Countdown" | "Battle" | "SuddenDeath" | "Results"

local Arena = {}

Arena.TEAM_IDS = { "Jaguar", "Quetzal" }

function Arena.phase(): Phase
	local phase = ReplicatedStorage:GetAttribute("ArenaPhase")
	return if typeof(phase) == "string" then phase :: Phase else "Waiting"
end

-- Segundos que le quedan a la fase (0 si no tiene fin fijo).
function Arena.secondsLeft(): number
	local endsAt = ReplicatedStorage:GetAttribute("ArenaPhaseEndsAt")
	if typeof(endsAt) ~= "number" then
		return 0
	end
	return math.max(0, endsAt - Workspace:GetServerTimeNow())
end

-- true mientras se puede pelear (y capturar).
function Arena.inBattle(): boolean
	local phase = Arena.phase()
	return phase == "Battle" or phase == "SuddenDeath"
end

function Arena.format(): number
	local format = ReplicatedStorage:GetAttribute("ArenaFormat")
	return if typeof(format) == "number" then format else Config.Arena.StudioFormat
end

function Arena.isTeam(teamId: any): boolean
	return typeof(teamId) == "string" and Config.Arena.Teams[teamId] ~= nil
end

function Arena.teamOf(player: Player): string?
	local teamId = player:GetAttribute("Team")
	return if Arena.isTeam(teamId) then teamId else nil
end

function Arena.otherTeam(teamId: string): string
	return if teamId == "Jaguar" then "Quetzal" else "Jaguar"
end

function Arena.membersOf(teamId: string): { Player }
	local members = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Team") == teamId then
			table.insert(members, player)
		end
	end
	return members
end

function Arena.score(teamId: string): number
	local score = ReplicatedStorage:GetAttribute(`ArenaScore_{teamId}`)
	return if typeof(score) == "number" then score else 0
end

-- true si "player" puede llevar "roleId" en "teamId": en los formatos grandes, como mucho
-- Config.Arena.MaxSameRole del mismo rol por equipo (sin contarle a él).
function Arena.roleAllowed(player: Player, teamId: string, roleId: string): boolean
	local settings = Config.Arena
	if Arena.format() < settings.SameRoleLimitFromFormat then
		return true
	end
	local count = 0
	for _, member in Arena.membersOf(teamId) do
		if member ~= player and member:GetAttribute("Role") == roleId then
			count += 1
		end
	end
	return count < settings.MaxSameRole
end

return Arena
