--!strict
-- Clasificaciones en el Lobby (Fase 6): cada Config.Data.LeaderboardRefreshSeconds lee el top 10 de
-- cada clasificación y lo publica en ReplicatedStorage ("Leaderboard_<stat>", JSON con nombre, valor y
-- el marco que lleva puesto, "frame", Shared/UI/PlayerFrames) para la ventana del ranking
-- (LobbyUIController), y escribe los primeros en el cartel del ranking de la plaza (supervivencia y,
-- con Leaderboards.ARENA_STATS y LAB_STATS, la arena de Dunas y el Laboratorio).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Leaderboards = require(ServerScriptService.ServerShared.Leaderboards)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

local LeaderboardService = {}

-- Puestos que se publican (la ventana del ranking enseña 10) y cuántos se piden de más por si hay
-- que saltarse alguno.
local TOP_SIZE = 10
local TOP_SPARE = 10

local names: { [number]: string } = {}

-- Nombre del jugador, o nil si no lo tiene: los jugadores de prueba de Studio (ids negativos) o si
-- Roblox no lo da ahora (se vuelve a pedir la próxima vez). Así el ranking solo enseña nombres.
local function nameOf(userId: number): string?
	if userId <= 0 then
		return nil
	end
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if not (ok and typeof(name) == "string") then
		return nil
	end
	names[userId] = name
	return name
end

-- Marco puesto de cada jugador del top, leído una vez por actualización (si está en este servidor, de
-- su atributo; si no, de su perfil guardado).
local function frameOf(userId: number, frames: { [number]: string | false }): string?
	if frames[userId] == nil then
		local online = Players:GetPlayerByUserId(userId)
		local frame: any = if online then online:GetAttribute("Frame") else nil
		if not online then
			local cosmetics = PlayerData.peekCosmetics(userId)
			frame = if cosmetics then cosmetics.Frame else nil
		end
		frames[userId] = if typeof(frame) == "string" then frame else false
	end
	local frame = frames[userId]
	return if frame then frame else nil
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
				if row or position ~= 1 then
					line:SetAttribute("TextKey", nil)
					line:SetAttribute("TextArgs", nil)
					line.Text = if row then `{place} {row.name} — {row.value}` else ""
				else
					Strings.setWorldText(line, "Aún no hay datos")
				end
			end
		end
	end
end

local function refresh()
	local stats = table.clone(Leaderboards.STATS)
	table.move(Leaderboards.ARENA_STATS, 1, #Leaderboards.ARENA_STATS, #stats + 1, stats)
	table.move(Leaderboards.LAB_STATS, 1, #Leaderboards.LAB_STATS, #stats + 1, stats)
	local frames: { [number]: string | false } = {}
	for _, stat in stats do
		local rows = {}
		for _, entry in Leaderboards.top(stat, TOP_SIZE + TOP_SPARE) do
			local name = nameOf(entry.userId)
			if name and #rows < TOP_SIZE then
				table.insert(rows, { name = name, value = entry.value, frame = frameOf(entry.userId, frames) })
			end
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
