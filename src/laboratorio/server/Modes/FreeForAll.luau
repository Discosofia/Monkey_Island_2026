--!strict
-- Todos contra todos del Laboratorio (docs/LABORATORIO.md §3): sin bandos, cada baja suma a quien
-- derriba ("ArenaKills", que cuenta LabRespawnService). Gana el primero en llegar a
-- Config.Lab.FreeForAllKills. Al acabar el tiempo gana el líder; con empate en cabeza, SuddenDeath sin
-- hora de fin: gana el primero que quede solo en cabeza. Si quedan menos de FreeForAllMinPlayers, gana el
-- que queda (no en la prueba en solitario).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LabRespawnService = require(script.Parent.Parent.Services.LabRespawnService)
local LabWorldService = require(script.Parent.Parent.Services.LabWorldService)
local Types = require(script.Parent.Types)

local FreeForAll = {}

local function stat(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

-- Los jugadores de más a menos bajas (con menos caídas delante, a igualdad).
local function ranking(): { Player }
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		local killsA, killsB = stat(a, "ArenaKills"), stat(b, "ArenaKills")
		if killsA ~= killsB then
			return killsA > killsB
		end
		return stat(a, "ArenaDeaths") < stat(b, "ArenaDeaths")
	end)
	return list
end

-- El líder si va solo en cabeza; nil si hay empate arriba (o no hay nadie).
local function soleLeader(list: { Player }): Player?
	local first, second = list[1], list[2]
	if not first then
		return nil
	end
	if second and stat(second, "ArenaKills") == stat(first, "ArenaKills") then
		return nil
	end
	return first
end

function FreeForAll.format(_requested: number): number
	return Config.Lab.FreeForAllPlayers
end

function FreeForAll.publish(_format: number)
	ReplicatedStorage:SetAttribute("LabKillsToWin", Config.Lab.FreeForAllKills)
	ReplicatedStorage:SetAttribute("LabRoundsToWin", nil)
end

function FreeForAll.full(): boolean
	return #Players:GetPlayers() >= Config.Lab.FreeForAllPlayers
end

function FreeForAll.enough(): boolean
	return #Players:GetPlayers() >= Config.Lab.FreeForAllMinPlayers
end

function FreeForAll.abandoned(ctx: Types.Context): boolean
	return not ctx.isSolo() and #Players:GetPlayers() < Config.Lab.FreeForAllMinPlayers
end

function FreeForAll.start(ctx: Types.Context)
	ctx.setPhase("Battle", Config.Lab.MatchSeconds)
	LabWorldService.setGates(true)
	LabRespawnService.respawnAll()
	Remotes.Notify:FireAllClients("⚔️ ¡Todos contra todos! Gana el primero en llegar a {kills} bajas", {
		kills = Config.Lab.FreeForAllKills,
	})
end

function FreeForAll.tick(ctx: Types.Context, phase: Arena.Phase)
	local list = ranking()
	local leader = list[1]
	-- Llega a las bajas, o se van tantos que solo queda uno (o ninguno): gana el líder.
	if (leader and stat(leader, "ArenaKills") >= Config.Lab.FreeForAllKills) or FreeForAll.abandoned(ctx) then
		ctx.finish(leader)
	elseif phase == "SuddenDeath" then
		local sole = soleLeader(list)
		if sole then
			ctx.finish(sole)
		end
	elseif phase == "Battle" then
		local endsAt = ReplicatedStorage:GetAttribute("ArenaPhaseEndsAt")
		if Workspace:GetServerTimeNow() >= (if typeof(endsAt) == "number" then endsAt else 0) then
			local sole = soleLeader(list)
			if sole then
				ctx.finish(sole)
			else
				ctx.setPhase("SuddenDeath", nil)
				Remotes.Notify:FireAllClients("⚡ ¡Empate! Muerte súbita: la siguiente baja gana")
			end
		end
	end
end

-- Las bajas ya las cuenta LabRespawnService en "ArenaKills"; aquí no hay marcador de bando.
function FreeForAll.onKnockedOut(_victim: Player, _attacker: Player) end

function FreeForAll.stop() end

function FreeForAll.debugScore(player: Player)
	player:SetAttribute("ArenaKills", stat(player, "ArenaKills") + 1)
end

return FreeForAll :: Types.Mode
