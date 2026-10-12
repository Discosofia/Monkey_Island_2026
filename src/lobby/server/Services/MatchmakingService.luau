--!strict
-- Envía a los jugadores del Lobby a la Isla.
-- Fase 0: viaje directo a un servidor público de la Isla (Roblox elige uno con hueco).
-- Fase 3: aquí irá el matchmaking real (grupos de amigos, partidas en curso con hueco).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)

local MatchmakingService = {}

function MatchmakingService:Start()
	local canRequest = RequestCooldown.new(Config.Teleport.CooldownSeconds)

	Remotes.RequestJoinIsland.OnServerEvent:Connect(function(player: Player)
		if not canRequest(player) then
			return
		end
		Teleporter.send({ player }, Config.PlaceIds.Island, "la Isla")
	end)
end

return MatchmakingService
