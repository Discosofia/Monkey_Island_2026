--!strict
-- Clasificaciones en el Lobby (Fase 6): cada Config.Data.LeaderboardRefreshSeconds lee el top 10 de
-- cada clasificación y lo publica en ReplicatedStorage ("Leaderboard_<stat>", JSON con nombre y valor)
-- para la pestaña "Ranking", y escribe los primeros en los carteles de la playa (el del ranking y el
-- de la arena de Dunas, con Leaderboards.ARENA_STATS).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Leaderboards = require(ServerScriptService.ServerShared.Leaderboards)

local LeaderboardService = {}

local names: { [number]: string } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and typeof(name) == "string" then name else `#{userId}`
	names[userId] = result
	return result
end

local MEDALS = { "🥇", "🥈", "🥉" }

-- Los primeros puestos en el cartel de la playa (World/LobbyBuilder): una línea por puesto.
local function fillBoards(stat: string, rows: { { name: string, value: number } })
	for _, board in CollectionService:GetTagged(Config.Lobby.RankingBoardTag) do
		local list = board:FindFirstChild(stat, true)
		if not list then
			continue
		end
		for position = 1, Config.Lobby.RankingBoardSize do
			local line = list:FindFirstChild(tostring(position))
			if line and line:IsA("TextLabel") then
				local row = rows[position]
				local place = MEDALS[position] or `{position}.`
				line.Text = if row
					then `{place} {row.name} — {row.value}`
					elseif position == 1 then "Aún no hay datos"
					else ""
			end
		end
	end
end

local function refresh()
	local stats = table.clone(Leaderboards.STATS)
	table.move(Leaderboards.ARENA_STATS, 1, #Leaderboards.ARENA_STATS, #stats + 1, stats)
	for _, stat in stats do
		local rows = {}
		for _, entry in Leaderboards.top(stat, 10) do
			table.insert(rows, { name = nameOf(entry.userId), value = entry.value })
		end
		ReplicatedStorage:SetAttribute(`Leaderboard_{stat}`, HttpService:JSONEncode(rows))
		fillBoards(stat, rows)
	end
end

function LeaderboardService:Start()
	while true do
		refresh()
		task.wait(Config.Data.LeaderboardRefreshSeconds)
	end
end

return LeaderboardService
