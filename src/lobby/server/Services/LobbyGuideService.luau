--!strict
-- Guía de la primera vez en el Lobby (LobbyGuideController): cuando el cliente la termina, se apunta
-- en el perfil ("lobbyGuideDone") para que no vuelva a salir. Su paso de la guardia (parar el golpe del
-- muñeco de sparring, Fase 10, C12) se apunta aparte ("combatGuideDone", el remoto con "Combat").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

local LobbyGuideService = {}

function LobbyGuideService:Start()
	Remotes.LobbyGuideDone.OnServerEvent:Connect(function(player, part)
		local profile = PlayerData.get(player)
		if part == "Combat" then
			if profile and not profile.combatGuideDone then
				PlayerData.update(player, function(changed)
					changed.combatGuideDone = true
				end)
			end
			return
		end
		if profile and not profile.lobbyGuideDone then
			PlayerData.update(player, function(changed)
				changed.lobbyGuideDone = true
			end)
		end
	end)
end

return LobbyGuideService
