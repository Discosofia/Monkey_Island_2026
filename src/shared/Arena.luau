--!strict
-- Estado de una partida por equipos, que lee cualquiera y solo cambia el servidor: la arena de Dunas
-- (captura la bandera; ArenaMatchService, TeamService…) y el duelo por equipos del Laboratorio
-- (LabMatchService, LabTeamService…). Cada place tiene sus dos equipos: Dunas, los de
-- Config.Arena.Teams (los de siempre, sin llamar a nada); el Laboratorio llama a Arena.configure con
-- los suyos en el Init de un servicio y de un controlador, antes de que nadie lea los equipos.
-- Va en atributos para que llegue solo a los clientes:
--   ReplicatedStorage:
--     "ArenaPhase"        fase (Phase, abajo)
--     "ArenaPhaseEndsAt"  hora del servidor en que acaba la fase (nil si no tiene fin fijo)
--     "ArenaFormat"       jugadores por equipo (1..5); en Todos contra todos del Laboratorio, el total
--     "ArenaScore_<id>"   puntos de cada equipo (capturas en Dunas, bajas en el Laboratorio)
--     "ArenaWinner"       equipo ganador en los resultados ("" si es empate)
--   Jugador:
--     "Team"              equipo (un id de Arena.TEAM_IDS), nil mientras no tiene
--     "ArenaReady"        ha pulsado "Listo"
--     "RespawnAt"         hora del servidor en que reaparece (nil si está vivo)
--     "ArenaKills", "ArenaDeaths", "ArenaCaptures"  sus números de esta partida (sin capturas en el
--                         Laboratorio)
--     "KilledBy"          UserId de quien la derribó (nil sin atacante, o ya reaparecida); lo pone
--                         Arena.markKiller antes de dejarla sin vida, para la killcam (CombatClient/SpectateCamera)
--     "KilledWith"        id del arma que llevaba en la mano ese atacante (nil si no llevaba ninguna)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

-- Waiting: elegir equipo, rol y equipo; Countdown: cuenta atrás con las puertas cerradas;
-- Battle: la partida; SuddenDeath: empate al acabar el tiempo, la siguiente captura gana;
-- Results: resultados y votación; Intermission: la pausa entre rondas del modo Rondas del Laboratorio
-- (sin daño, se puede cambiar de arma; Dunas no la usa, y inBattle() da false).
export type Phase = "Waiting" | "Countdown" | "Battle" | "SuddenDeath" | "Intermission" | "Results"

local Arena = {}

export type Team = { name: string, icon: string, color: Color3 }

-- Los dos equipos del place: el orden de TEAM_IDS es el del marcador (el primero, a la izquierda).
Arena.TEAM_IDS = { "Jaguar", "Quetzal" }
Arena.TEAMS = Config.Arena.Teams :: { [string]: Team }

-- Cambia los equipos del place. Se rellenan las tablas en el sitio: quien guardó TEAM_IDS o TEAMS al
-- cargar ve los nuevos.
function Arena.configure(teams: { [string]: Team }, teamIds: { string })
	table.clear(Arena.TEAM_IDS)
	for _, teamId in teamIds do
		table.insert(Arena.TEAM_IDS, teamId)
	end
	Arena.TEAMS = teams
end

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
	return typeof(teamId) == "string" and Arena.TEAMS[teamId] ~= nil
end

function Arena.teamOf(player: Player): string?
	local teamId = player:GetAttribute("Team")
	return if Arena.isTeam(teamId) then teamId else nil
end

function Arena.otherTeam(teamId: string): string
	local first, second = Arena.TEAM_IDS[1], Arena.TEAM_IDS[2]
	return if teamId == first then second else first
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

-- Solo el servidor: apunta en "victim" quién la derribó y con qué arma ("KilledBy", "KilledWith"), o lo
-- borra con attacker = nil (o si es ella misma). El arma es el "WeaponId" de la herramienta que el atacante
-- tiene en la mano en ese momento.
function Arena.markKiller(victim: Player, attacker: Player?)
	if not attacker or attacker == victim then
		victim:SetAttribute("KilledBy", nil)
		victim:SetAttribute("KilledWith", nil)
		return
	end
	local tool = if attacker.Character then attacker.Character:FindFirstChildOfClass("Tool") else nil
	local weaponId = if tool then tool:GetAttribute("WeaponId") else nil
	victim:SetAttribute("KilledBy", attacker.UserId)
	victim:SetAttribute("KilledWith", if typeof(weaponId) == "string" then weaponId else nil)
end

return Arena
