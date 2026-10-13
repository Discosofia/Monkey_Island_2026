--!strict
-- Fin de la partida (GDD §5.3, Fase 2.7).
--   - Derrota: de noche, si todos los jugadores están caídos o son Espíritus a la vez durante
--     Config.Match.DefeatGraceSeconds seguidos.
--   - Al terminar: se para el ciclo de día y noche, cada jugador ve su resumen (días, monos,
--     reanimaciones, caídas y Ámbar ganado) y a los Config.Match.ResultsSeconds todos vuelven al Lobby.
--   - Otros servicios (el guardado de datos, 2.8) se enteran con MatchService.onMatchEnded.
-- La victoria (baliza de rescate) llega en la Fase 5.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MatchStats = require(ReplicatedStorage.Shared.MatchStats)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)
local DayNightService = require(script.Parent.DayNightService)

export type Result = "Defeat" | "Victory"

export type Summary = {
	result: Result,
	days: number,
	kills: number,
	revives: number,
	deaths: number,
	amber: number,
}

local MatchService = {}

local ended = false
local listeners: { (player: Player, summary: Summary) -> () } = {}

-- Llama a "callback" con cada jugador y su resumen cuando termina la partida. Regístralo en Init.
function MatchService.onMatchEnded(callback: (player: Player, summary: Summary) -> ())
	table.insert(listeners, callback)
end

function MatchService.isOver(): boolean
	return ended
end

local function summaryFor(player: Player, result: Result, days: number): Summary
	local kills = MatchStats.get(player, MatchStats.KILLS)
	local revives = MatchStats.get(player, MatchStats.REVIVES)
	local settings = Config.Match
	return {
		result = result,
		days = days,
		kills = kills,
		revives = revives,
		deaths = MatchStats.get(player, MatchStats.DEATHS),
		amber = days * settings.AmberPerDay + kills * settings.AmberPerKill + revives * settings.AmberPerRevive,
	}
end

function MatchService.endMatch(result: Result)
	if ended then
		return
	end
	ended = true
	DayNightService.stop()
	local state = MatchState.read()
	-- Días sobrevividos: el día actual cuenta si se llegó a su noche.
	local days = if state then (if state.phase == "Night" then state.day else state.day - 1) else 0
	ReplicatedStorage:SetAttribute("MatchOver", result)

	for _, player in Players:GetPlayers() do
		local summary = summaryFor(player, result, days)
		for _, listener in listeners do
			task.spawn(listener, player, summary)
		end
		Remotes.MatchEnded:FireClient(player, summary)
	end

	task.delay(Config.Match.ResultsSeconds, function()
		local players = Players:GetPlayers()
		if #players > 0 then
			Teleporter.send(players, Config.PlaceIds.Lobby, "el Lobby")
		end
	end)
end

local function everyoneDown(): boolean
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		if LifeState.isAlive(player) then
			return false
		end
	end
	return true
end

function MatchService:Start()
	local downSince: number? = nil
	while not ended do
		task.wait(1)
		local state = MatchState.read()
		local night = state ~= nil and state.phase == "Night"
		if night and everyoneDown() then
			downSince = downSince or os.clock()
			if os.clock() - (downSince :: number) >= Config.Match.DefeatGraceSeconds then
				MatchService.endMatch("Defeat")
			end
		else
			downSince = nil
		end
	end
end

return MatchService
