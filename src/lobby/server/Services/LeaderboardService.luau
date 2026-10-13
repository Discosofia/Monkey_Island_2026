--!strict
-- Clasificaciones en el Lobby (Fase 6): cada Config.Data.LeaderboardRefreshSeconds lee el top 10 de
-- cada clasificación y lo publica en ReplicatedStorage ("Leaderboard_<stat>", JSON con nombre y valor)
-- para la pestaña "Ranking".

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

local function refresh()
	for _, stat in Leaderboards.STATS do
		local rows = {}
		for _, entry in Leaderboards.top(stat, 10) do
			table.insert(rows, { name = nameOf(entry.userId), value = entry.value })
		end
		ReplicatedStorage:SetAttribute(`Leaderboard_{stat}`, HttpService:JSONEncode(rows))
	end
end

function LeaderboardService:Start()
	while true do
		refresh()
		task.wait(Config.Data.LeaderboardRefreshSeconds)
	end
end

return LeaderboardService
