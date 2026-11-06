--!strict
-- Captura la bandera de Dunas: cada captura (FlagService) suma un punto a su equipo. Gana el primero en
-- llegar a CapturesToWin o el que más tenga al acabar el tiempo; con empate, SuddenDeath (la siguiente
-- captura gana). Si un equipo se queda vacío, gana el otro. Es la lógica de siempre, sacada de
-- ArenaMatchService sin cambios.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ArenaWorldService = require(script.Parent.Parent.Services.ArenaWorldService)
local RespawnService = require(script.Parent.Parent.Services.RespawnService)
local Types = require(script.Parent.Types)

local CaptureFlag = {}

local function setScore(teamId: string, value: number)
	ReplicatedStorage:SetAttribute(`ArenaScore_{teamId}`, value)
end

local function resetScores()
	for _, teamId in Arena.TEAM_IDS do
		setScore(teamId, 0)
	end
end

local function teamSizes(): (number, number)
	return #Arena.membersOf("Jaguar"), #Arena.membersOf("Quetzal")
end

function CaptureFlag.format(requested: number): number
	return math.clamp(math.floor(requested), Config.Arena.MinFormat, Config.Arena.MaxFormat)
end

function CaptureFlag.publish(_format: number) end

function CaptureFlag.full(): boolean
	local jaguar, quetzal = teamSizes()
	local format = Arena.format()
	return jaguar == format and quetzal == format
end

function CaptureFlag.enough(): boolean
	local jaguar, quetzal = teamSizes()
	return jaguar > 0 and quetzal > 0
end

function CaptureFlag.abandoned(ctx: Types.Context): boolean
	local jaguar, quetzal = teamSizes()
	return not ctx.isSolo() and (jaguar == 0 or quetzal == 0)
end

function CaptureFlag.reset()
	resetScores()
end

function CaptureFlag.start(ctx: Types.Context)
	resetScores()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("ArenaCaptures", 0)
	end
	ctx.setPhase("Battle", Config.Arena.MatchSeconds)
	ArenaWorldService.setGates(true)
	RespawnService.respawnAll()
	Remotes.Notify:FireAllClients("⚔️ ¡Que empiece la batalla! Roba la bandera rival y tráela a tu base")
end

function CaptureFlag.tick(ctx: Types.Context, phase: Arena.Phase)
	local jaguar, quetzal = teamSizes()
	local jaguarScore, quetzalScore = Arena.score("Jaguar"), Arena.score("Quetzal")
	local target = Config.Arena.CapturesToWin
	if jaguarScore >= target or (phase == "SuddenDeath" and jaguarScore > quetzalScore) then
		ctx.finish("Jaguar")
	elseif quetzalScore >= target or (phase == "SuddenDeath" and quetzalScore > jaguarScore) then
		ctx.finish("Quetzal")
	elseif CaptureFlag.abandoned(ctx) then
		ctx.finish(if jaguar > 0 then "Jaguar" elseif quetzal > 0 then "Quetzal" else nil)
	elseif phase == "Battle" then
		local endsAt = ReplicatedStorage:GetAttribute("ArenaPhaseEndsAt")
		if Workspace:GetServerTimeNow() >= (if typeof(endsAt) == "number" then endsAt else 0) then
			if jaguarScore == quetzalScore then
				ctx.setPhase("SuddenDeath", nil)
				Remotes.Notify:FireAllClients("⚡ ¡Empate! Muerte súbita: la siguiente captura gana")
			else
				ctx.finish(if jaguarScore > quetzalScore then "Jaguar" else "Quetzal")
			end
		end
	end
end

-- Un equipo ha capturado la bandera rival (FlagService).
function CaptureFlag.capture(teamId: string)
	if not Arena.inBattle() then
		return
	end
	setScore(teamId, Arena.score(teamId) + 1)
end

function CaptureFlag.stop() end

return CaptureFlag :: Types.Mode
