--!strict
-- Fin de la partida (GDD §5.3, Fase 2.7).
--   - Derrota: de noche, si todos los jugadores están caídos a la vez durante
--     Config.Match.DefeatGraceSeconds seguidos.
--   - Al terminar: se para el ciclo de día y noche, cada jugador ve su resumen (días, monos,
--     reanimaciones, caídas y Ámbar ganado) y a los Config.Match.ResultsSeconds todos vuelven al Lobby.
--   - Otros servicios (el guardado de datos, 2.8) se enteran con MatchService.onMatchEnded.
--   - Victoria (la baliza, BeaconService): si el jugador tiene un huevo incubando en el nido del Lobby,
--     le toca una tirada que le quita horas o lo deja listo (ServerShared/Eggs); el resultado va en su
--     resumen ("eggRoll") y la pantalla de resultados lo enseña con una ruleta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MatchStats = require(ReplicatedStorage.Shared.MatchStats)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Eggs = require(ServerScriptService.ServerShared.Eggs)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)
local DayNightService = require(script.Parent.DayNightService)

export type Result = "Defeat" | "Victory"

export type Summary = {
	result: Result,
	days: number,
	kills: number,
	revives: number,
	deaths: number,
	bosses: number,
	amber: number,
	eggRoll: Eggs.RescueOutcome?,
	-- Terminada con el panel de pruebas de Studio: no cuenta para el récord, los rescates ni el ranking.
	test: boolean?,
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

local function summaryFor(player: Player, result: Result, days: number, test: boolean): Summary
	local kills = MatchStats.get(player, MatchStats.KILLS)
	local revives = MatchStats.get(player, MatchStats.REVIVES)
	local bosses = MatchStats.get(player, MatchStats.BOSSES)
	local settings = Config.Match
	local amber = days * settings.AmberPerDay
		+ kills * settings.AmberPerKill
		+ revives * settings.AmberPerRevive
		+ bosses * settings.AmberPerBoss
		+ MatchStats.get(player, MatchStats.BOUNTIES) * settings.AmberPerBounty
		+ MatchStats.get(player, MatchStats.EGGS) * settings.AmberPerEgg
		+ (if result == "Victory" then settings.AmberForRescue else 0)
	return {
		result = result,
		days = days,
		kills = kills,
		revives = revives,
		deaths = MatchStats.get(player, MatchStats.DEATHS),
		bosses = bosses,
		amber = amber,
		eggRoll = if result == "Victory" then Eggs.rescueRoll(player) else nil,
		test = if test then true else nil,
	}
end

-- "test": la termina el panel de pruebas (DebugService), para que no cuente en el ranking.
function MatchService.endMatch(result: Result, test: boolean?)
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
		local summary = summaryFor(player, result, days, test == true)
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
	-- Quien entre en una partida ya terminada vuelve al Lobby.
	Players.PlayerAdded:Connect(function(player)
		if ended then
			Remotes.Notify:FireClient(player, "Esta partida ha terminado: volviendo al Lobby")
			task.wait(3)
			Teleporter.send({ player }, Config.PlaceIds.Lobby, "el Lobby")
		end
	end)
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
