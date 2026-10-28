--!strict
-- Rondas del Laboratorio (docs/LABORATORIO.md §3): rondas cortas por bandos, sin reaparecer dentro de la
-- ronda. Gana el primer bando en llegar a Config.Lab.RoundsToWin rondas.
--   Ronda        (fase Battle, RoundSeconds) gana el bando que deja al otro con 0 jugadores en pie; si al
--                empezar el otro ya tenía 0 (la prueba en solitario), no cuenta. A los AlarmAtSeconds, alarma
--                ("LabAlarm": el cliente dibuja el contorno de todos). Al acabar el tiempo: más vida sumada,
--                después más jugadores en pie y, si siguen iguales, ronda nula.
--   Pausa        (fase Intermission, RoundIntermissionSeconds) compuertas cerradas y todos reaparecen
--                (pueden cambiar de arma). Tras la ronda SideSwapAfterRound jugada (las nulas cuentan) las
--                bases cambian de dueño (LabWorldService.setSwapped): cada uno sigue en su bando.
--   Final        al llegar a RoundsToWin, o al pasar "LabMatchEndsAt" (MatchSeconds desde el principio): al
--                acabar la ronda en curso, gana el que lleva más rondas. Con empate, la ronda siguiente
--                (fase SuddenDeath) decide; si sale nula, otra.
-- El marcador es "ArenaScore_<bando>" (rondas ganadas). Atributos de ReplicatedStorage: "LabRound",
-- "LabMatchEndsAt", "LabAlarm", "LabSidesSwapped" y "LabRoundsToWin". Quien cae en plena ronda queda con
-- "LabOut" y no reaparece hasta la pausa (LabRespawnService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LabRespawnService = require(script.Parent.Parent.Services.LabRespawnService)
local LabWorldService = require(script.Parent.Parent.Services.LabWorldService)
local Types = require(script.Parent.Types)

-- Al empezar una ronda, los segundos en que no se mira quién queda en pie: los personajes aún están
-- apareciendo y uno sin cargar no es uno derribado.
local ROUND_GRACE_SECONDS = 2

local Rounds = {}

local running = false
local roundNumber = 0
local played = 0
local sudden = false
local swapped = false
local alarmed = false
local roundStartedAt = 0
local matchEndsAt = 0
-- Jugadores de cada bando al empezar la ronda.
local startCounts: { [string]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function setScore(teamId: string, value: number)
	ReplicatedStorage:SetAttribute(`ArenaScore_{teamId}`, value)
end

local function teamSize(teamId: string): number
	return #Arena.membersOf(teamId)
end

-- Sigue en la ronda: ni eliminado ni con la vida a 0 (uno que aún no ha aparecido cuenta como en pie).
local function isStanding(player: Player): boolean
	if player:GetAttribute("LabOut") == true then
		return false
	end
	local character = player.Character
	if not character then
		return true
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid == nil or humanoid.Health > 0
end

local function standing(teamId: string): number
	local count = 0
	for _, player in Arena.membersOf(teamId) do
		if isStanding(player) then
			count += 1
		end
	end
	return count
end

-- La vida sumada de los que siguen en pie.
local function totalHealth(teamId: string): number
	local total = 0
	for _, player in Arena.membersOf(teamId) do
		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid and humanoid.Health > 0 and isStanding(player) then
			total += humanoid.Health
		end
	end
	return total
end

local function phaseEndsAt(): number
	local endsAt = ReplicatedStorage:GetAttribute("ArenaPhaseEndsAt")
	return if typeof(endsAt) == "number" then endsAt else 0
end

-- El bando con más rondas ganadas; nil si empatan.
local function roundsLeader(): string?
	local first, second = Arena.TEAM_IDS[1], Arena.TEAM_IDS[2]
	local firstScore, secondScore = Arena.score(first), Arena.score(second)
	if firstScore == secondScore then
		return nil
	end
	return if firstScore > secondScore then first else second
end

local function raiseAlarm()
	alarmed = true
	ReplicatedStorage:SetAttribute("LabAlarm", true)
	Remotes.Notify:FireAllClients("🔔 ¡Alarma! Todos quedan a la vista")
end

local function beginRound(ctx: Types.Context)
	roundNumber += 1
	roundStartedAt = now()
	alarmed = false
	ReplicatedStorage:SetAttribute("LabRound", roundNumber)
	ReplicatedStorage:SetAttribute("LabAlarm", false)
	for _, teamId in Arena.TEAM_IDS do
		startCounts[teamId] = teamSize(teamId)
	end
	ctx.setPhase(if sudden then "SuddenDeath" else "Battle", Config.Lab.RoundSeconds)
	LabWorldService.setGates(true)
	LabRespawnService.respawnAll()
	if sudden then
		Remotes.Notify:FireAllClients("⚡ ¡Ronda decisiva! La gana quien la gane")
	elseif roundNumber > 1 then
		Remotes.Notify:FireAllClients("⚔️ ¡Ronda {round}!", { round = roundNumber })
	end
end

-- Acaba la ronda: la gana "winner" (nil: nula). Decide si acaba la partida o si hay pausa.
local function endRound(ctx: Types.Context, winner: string?)
	played += 1
	if winner then
		setScore(winner, Arena.score(winner) + 1)
		local team = Arena.TEAMS[winner]
		Remotes.Notify:FireAllClients("Ronda {round} para {icon} {name}", {
			round = roundNumber,
			icon = team.icon,
			name = { team.name },
		})
	else
		Remotes.Notify:FireAllClients("Ronda {round} nula: nadie la gana", { round = roundNumber })
	end
	if winner and (Arena.score(winner) >= Config.Lab.RoundsToWin or sudden) then
		ctx.finish(winner)
		return
	end
	if now() >= matchEndsAt then
		local leader = roundsLeader()
		if leader then
			ctx.finish(leader)
			return
		elseif not sudden then
			sudden = true
			Remotes.Notify:FireAllClients("⚡ ¡Empate a rondas! La siguiente ronda decide")
		end
	end
	if not swapped and played >= Config.Lab.SideSwapAfterRound then
		swapped = true
		LabWorldService.setSwapped(true)
		ReplicatedStorage:SetAttribute("LabSidesSwapped", true)
		Remotes.Notify:FireAllClients("🔀 ¡Cambio de lado! Cada bando pasa a la base contraria")
	end
	ReplicatedStorage:SetAttribute("LabAlarm", false)
	ctx.setPhase("Intermission", Config.Lab.RoundIntermissionSeconds)
	LabWorldService.setGates(false)
	LabRespawnService.respawnAll()
end

-- Al acabar el tiempo de la ronda: más vida, después más en pie; igual en todo, nula.
local function timeUpWinner(): string?
	local first, second = Arena.TEAM_IDS[1], Arena.TEAM_IDS[2]
	local firstHealth, secondHealth = totalHealth(first), totalHealth(second)
	if firstHealth ~= secondHealth then
		return if firstHealth > secondHealth then first else second
	end
	local firstStanding, secondStanding = standing(first), standing(second)
	if firstStanding ~= secondStanding then
		return if firstStanding > secondStanding then first else second
	end
	return nil
end

function Rounds.format(requested: number): number
	return math.clamp(math.floor(requested), 1, #Config.Lab.ModeFormats.Rounds)
end

function Rounds.publish(_format: number)
	ReplicatedStorage:SetAttribute("LabKillsToWin", nil)
	ReplicatedStorage:SetAttribute("LabRoundsToWin", Config.Lab.RoundsToWin)
end

function Rounds.full(): boolean
	local format = Arena.format()
	return teamSize(Arena.TEAM_IDS[1]) == format and teamSize(Arena.TEAM_IDS[2]) == format
end

function Rounds.enough(): boolean
	return teamSize(Arena.TEAM_IDS[1]) > 0 and teamSize(Arena.TEAM_IDS[2]) > 0
end

function Rounds.abandoned(ctx: Types.Context): boolean
	return not ctx.isSolo() and (teamSize(Arena.TEAM_IDS[1]) == 0 or teamSize(Arena.TEAM_IDS[2]) == 0)
end

function Rounds.start(ctx: Types.Context)
	running = true
	roundNumber = 0
	played = 0
	sudden = false
	swapped = false
	matchEndsAt = now() + Config.Lab.MatchSeconds
	for _, teamId in Arena.TEAM_IDS do
		setScore(teamId, 0)
	end
	ReplicatedStorage:SetAttribute("LabMatchEndsAt", matchEndsAt)
	ReplicatedStorage:SetAttribute("LabSidesSwapped", false)
	Remotes.Notify:FireAllClients(
		"⚔️ ¡Que empiecen las rondas! Gana el primer bando en llegar a {rounds} rondas",
		{
			rounds = Config.Lab.RoundsToWin,
		}
	)
	beginRound(ctx)
end

function Rounds.tick(ctx: Types.Context, phase: Arena.Phase)
	local first, second = Arena.TEAM_IDS[1], Arena.TEAM_IDS[2]
	-- Alguien llegó a las rondas necesarias (también con el panel de pruebas).
	for _, teamId in Arena.TEAM_IDS do
		if Arena.score(teamId) >= Config.Lab.RoundsToWin then
			ctx.finish(teamId)
			return
		end
	end
	if Rounds.abandoned(ctx) then
		ctx.finish(if teamSize(first) > 0 then first elseif teamSize(second) > 0 then second else nil)
		return
	end
	if phase == "Intermission" then
		if now() >= phaseEndsAt() then
			beginRound(ctx)
		end
		return
	end
	-- Ronda (Battle o, en la decisiva, SuddenDeath).
	local elapsed = now() - roundStartedAt
	if elapsed >= ROUND_GRACE_SECONDS then
		local firstOut = (startCounts[first] or 0) > 0 and standing(first) == 0
		local secondOut = (startCounts[second] or 0) > 0 and standing(second) == 0
		if firstOut and secondOut then
			endRound(ctx, nil)
			return
		elseif firstOut then
			endRound(ctx, second)
			return
		elseif secondOut then
			endRound(ctx, first)
			return
		end
	end
	if not alarmed and elapsed >= Config.Lab.AlarmAtSeconds then
		raiseAlarm()
	end
	if now() >= phaseEndsAt() then
		endRound(ctx, timeUpWinner())
	end
end

-- Los puntos son rondas ganadas, y se dan al final de cada una (endRound): aquí no hay nada que hacer.
function Rounds.onKnockedOut(_victim: Player, _attacker: Player) end

function Rounds.stop()
	local wasRunning = running
	running = false
	for _, attribute in { "LabRound", "LabMatchEndsAt", "LabAlarm", "LabSidesSwapped" } do
		ReplicatedStorage:SetAttribute(attribute, nil)
	end
	if swapped then
		swapped = false
		LabWorldService.setSwapped(false)
	end
	-- Los eliminados de la última ronda vuelven a verse en su base (si no, seguirían de espectadores).
	if wasRunning then
		LabRespawnService.respawnAll()
	end
end

function Rounds.debugScore(player: Player)
	local teamId = Arena.teamOf(player)
	if teamId then
		setScore(teamId, Arena.score(teamId) + 1)
	end
end

-- Primero la alarma y después el final de la ronda.
function Rounds.debugSkip(_ctx: Types.Context): boolean
	local phase = Arena.phase()
	if not running or (phase ~= "Battle" and phase ~= "SuddenDeath") then
		return false
	end
	if alarmed then
		ReplicatedStorage:SetAttribute("ArenaPhaseEndsAt", now())
	else
		raiseAlarm()
	end
	return true
end

return Rounds :: Types.Mode
