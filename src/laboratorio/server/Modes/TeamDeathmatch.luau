--!strict
-- Duelo por equipos del Laboratorio (docs/LABORATORIO.md §3): cada baja suma un punto a su bando. Gana el
-- primero en llegar a KillsToWin[formato] o el que más tenga a los MatchSeconds; con empate, SuddenDeath
-- (la siguiente baja gana). Si un bando se queda vacío, gana el otro. Es la lógica de L2, sacada de
-- LabMatchService sin cambios.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LabRespawnService = require(script.Parent.Parent.Services.LabRespawnService)
local LabWorldService = require(script.Parent.Parent.Services.LabWorldService)
local Types = require(script.Parent.Types)

local TeamDeathmatch = {}

local function setScore(teamId: string, value: number)
	ReplicatedStorage:SetAttribute(`ArenaScore_{teamId}`, value)
end

local function teamSizes(): (number, number)
	return #Arena.membersOf(Arena.TEAM_IDS[1]), #Arena.membersOf(Arena.TEAM_IDS[2])
end

-- Bajas que hacen falta para ganar con el formato "format".
local function killsToWin(format: number): number
	local kills = Config.Lab.KillsToWin
	return kills[math.clamp(format, 1, #kills)]
end

function TeamDeathmatch.format(requested: number): number
	return math.clamp(math.floor(requested), 1, #Config.Lab.KillsToWin)
end

function TeamDeathmatch.publish(format: number)
	ReplicatedStorage:SetAttribute("LabKillsToWin", killsToWin(format))
	ReplicatedStorage:SetAttribute("LabRoundsToWin", nil)
end

function TeamDeathmatch.full(): boolean
	local first, second = teamSizes()
	local format = Arena.format()
	return first == format and second == format
end

function TeamDeathmatch.enough(): boolean
	local first, second = teamSizes()
	return first > 0 and second > 0
end

function TeamDeathmatch.abandoned(ctx: Types.Context): boolean
	local first, second = teamSizes()
	return not ctx.isSolo() and (first == 0 or second == 0)
end

function TeamDeathmatch.start(ctx: Types.Context)
	for _, teamId in Arena.TEAM_IDS do
		setScore(teamId, 0)
	end
	ctx.setPhase("Battle", Config.Lab.MatchSeconds)
	LabWorldService.setGates(true)
	LabRespawnService.respawnAll()
	Remotes.Notify:FireAllClients("⚔️ ¡Que empiece el duelo! Gana el primer bando en llegar a {kills} bajas", {
		kills = killsToWin(Arena.format()),
	})
end

function TeamDeathmatch.tick(ctx: Types.Context, phase: Arena.Phase)
	local first, second = teamSizes()
	local firstId, secondId = Arena.TEAM_IDS[1], Arena.TEAM_IDS[2]
	local firstScore, secondScore = Arena.score(firstId), Arena.score(secondId)
	local target = killsToWin(Arena.format())
	if firstScore >= target or (phase == "SuddenDeath" and firstScore > secondScore) then
		ctx.finish(firstId)
	elseif secondScore >= target or (phase == "SuddenDeath" and secondScore > firstScore) then
		ctx.finish(secondId)
	elseif TeamDeathmatch.abandoned(ctx) then
		ctx.finish(if first > 0 then firstId elseif second > 0 then secondId else nil)
	elseif phase == "Battle" then
		local endsAt = ReplicatedStorage:GetAttribute("ArenaPhaseEndsAt")
		if Workspace:GetServerTimeNow() >= (if typeof(endsAt) == "number" then endsAt else 0) then
			if firstScore == secondScore then
				ctx.setPhase("SuddenDeath", nil)
				Remotes.Notify:FireAllClients("⚡ ¡Empate! Muerte súbita: la siguiente baja gana")
			else
				ctx.finish(if firstScore > secondScore then firstId else secondId)
			end
		end
	end
end

-- Un rival ha derribado a "victim" (LabRespawnService): un punto para el bando de "attacker".
function TeamDeathmatch.onKnockedOut(_victim: Player, attacker: Player)
	local teamId = Arena.teamOf(attacker)
	if teamId and Arena.inBattle() then
		setScore(teamId, Arena.score(teamId) + 1)
	end
end

function TeamDeathmatch.stop() end

function TeamDeathmatch.debugScore(player: Player)
	local teamId = Arena.teamOf(player)
	if teamId then
		setScore(teamId, Arena.score(teamId) + 1)
	end
end

return TeamDeathmatch :: Types.Mode
