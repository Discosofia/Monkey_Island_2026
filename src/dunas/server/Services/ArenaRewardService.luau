--!strict
-- Lo que se gana al terminar una partida de la arena (Config.Arena.Amber), para quien sigue en ella:
--   - Ámbar por el resultado (victoria, empate, derrota), por cada captura y por cada baja (estas,
--     con tope por partida). Con un tope diario (perfil "arena.daily"): lo que pase del tope no se
--     cobra, y los resultados lo dicen.
--   - Estadísticas guardadas (perfil "arena.stats") y rankings de la arena (victorias y capturas).
--   - XP del pase de temporada (Config.Season.ArenaXp, ServerShared/SeasonPass), con el tope de hoy de
--     las partidas, que comparte con la Isla.
-- A cada jugador le manda sus resultados (Remotes.ArenaResults) para la pantalla final. Las partidas
-- de prueba (panel de pruebas, un solo equipo) no dan nada. También atiende "Volver al Lobby".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Daily = require(ReplicatedStorage.Shared.Daily)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(ServerScriptService.ServerShared.Analytics)
local Leaderboards = require(ServerScriptService.ServerShared.Leaderboards)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local SeasonPass = require(ServerScriptService.ServerShared.SeasonPass)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)
local ArenaMatchService = require(script.Parent.ArenaMatchService)

local ArenaRewardService = {}

local function stat(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

-- Ámbar que ha ganado "player" en esta partida (antes del tope diario).
local function earned(player: Player, result: "Win" | "Tie" | "Loss"): number
	local amber = Config.Arena.Amber
	local fromKills = math.min(stat(player, "ArenaKills") * amber.PerKill, amber.MaxFromKills)
	return amber[result] + stat(player, "ArenaCaptures") * amber.PerCapture + fromKills
end

-- Cobra hasta el tope diario y guarda las estadísticas. Devuelve lo cobrado y lo que lleva hoy.
local function grant(player: Player, amount: number, result: "Win" | "Tie" | "Loss"): (number, number)
	local granted, todayTotal = 0, 0
	local today = Daily.today(os.time())
	PlayerData.update(player, function(profile)
		local arena = profile.arena
		local daily = if typeof(arena.daily) == "table" and arena.daily.day == today
			then arena.daily
			else { day = today, amber = 0 }
		granted = math.clamp(Config.Arena.Amber.DailyCap - daily.amber, 0, amount)
		daily.amber += granted
		arena.daily = daily
		todayTotal = daily.amber
		profile.amber += granted

		local stats = if typeof(arena.stats) == "table" then arena.stats else {}
		stats.matches = (stats.matches or 0) + 1
		stats.wins = (stats.wins or 0) + (if result == "Win" then 1 else 0)
		stats.losses = (stats.losses or 0) + (if result == "Loss" then 1 else 0)
		stats.captures = (stats.captures or 0) + stat(player, "ArenaCaptures")
		stats.kills = (stats.kills or 0) + stat(player, "ArenaKills")
		arena.stats = stats
	end)
	local profile = PlayerData.get(player)
	if profile then
		if granted > 0 then
			Analytics.amber(player, "Source", granted, profile.amber, "Arena")
		end
		local stats = profile.arena.stats
		task.spawn(function()
			Leaderboards.record(player.UserId, "ArenaWins", stats.wins or 0)
			Leaderboards.record(player.UserId, "ArenaCaptures", stats.captures or 0)
		end)
		task.spawn(PlayerData.saveNow, player)
	end
	return granted, todayTotal
end

-- Los números de todos, para la tabla de los resultados.
local function scoreboard(): { { [string]: any } }
	local rows = {}
	for _, player in Players:GetPlayers() do
		local teamId = Arena.teamOf(player)
		if teamId then
			table.insert(rows, {
				name = player.DisplayName,
				team = teamId,
				kills = stat(player, "ArenaKills"),
				deaths = stat(player, "ArenaDeaths"),
				captures = stat(player, "ArenaCaptures"),
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.captures ~= b.captures then
			return a.captures > b.captures
		end
		return a.kills > b.kills
	end)
	return rows
end

local function onFinished(winner: string?)
	local test = ArenaMatchService.isSolo()
	local rows = scoreboard()
	for _, player in Players:GetPlayers() do
		local teamId = Arena.teamOf(player)
		if teamId then
			local result: "Win" | "Tie" | "Loss" = if winner == nil
				then "Tie"
				elseif winner == teamId then "Win"
				else "Loss"
			local amount = if test then 0 else earned(player, result)
			local granted, todayTotal = 0, 0
			local pass: SeasonPass.Gain? = nil
			if not test then
				granted, todayTotal = grant(player, amount, result)
				local xp = Config.Season.ArenaXp
				pass = SeasonPass.addXp(player, "Match", xp[result] + stat(player, "ArenaCaptures") * xp.PerCapture)
			end
			Remotes.ArenaResults:FireClient(player, {
				result = result,
				winner = winner,
				team = teamId,
				test = test,
				earned = amount,
				amber = granted,
				today = todayTotal,
				dailyCap = Config.Arena.Amber.DailyCap,
				pass = pass,
				scores = { Jaguar = Arena.score("Jaguar"), Quetzal = Arena.score("Quetzal") },
				players = rows,
			})
		end
	end
end

function ArenaRewardService:Init()
	ArenaMatchService.onFinished(onFinished)
end

function ArenaRewardService:Start()
	Remotes.ArenaLeave.OnServerEvent:Connect(function(player: Player)
		-- Se guarda antes de viajar, para que el Lobby cargue el Ámbar recién ganado.
		PlayerData.saveNow(player)
		Teleporter.send({ player }, Config.PlaceIds.Lobby, "el Lobby")
	end)
end

return ArenaRewardService
