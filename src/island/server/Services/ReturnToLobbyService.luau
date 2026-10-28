--!strict
-- Devuelve al Lobby a los jugadores que lo piden.
-- Fase 2+: el fin de partida (derrota o rescate) también enviará a todos al Lobby.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)

local ReturnToLobbyService = {}

function ReturnToLobbyService:Start()
	local canRequest = RequestCooldown.new(Config.Teleport.CooldownSeconds)

	Remotes.RequestReturnToLobby.OnServerEvent:Connect(function(player: Player)
		if not canRequest(player) then
			return
		end
		Teleporter.send({ player }, Config.PlaceIds.Lobby, Strings.later("el Lobby"))
	end)
end

return ReturnToLobbyService
