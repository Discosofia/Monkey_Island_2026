--!strict
-- Marca la cinemática de bienvenida «Shipwreck» (Fase 25, G6a) como vista. La escena la decide y la reproduce el cliente
-- (ShipwreckController del Lobby); cuando la ve entera avisa con CinematicDone("Shipwreck", true) y aquí se apunta en
-- el perfil (cinematicsSeen, el mismo campo que usa CinematicService en la Isla) por PlayerData.update. Cualquier otro
-- id, o una escena a medias, se ignora.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

local SCENE_ID = "Shipwreck"

local ShipwreckService = {}

function ShipwreckService:Start()
	Remotes.CinematicDone.OnServerEvent:Connect(function(player: Player, id: any, watchedFully: any)
		if id ~= SCENE_ID or watchedFully ~= true then
			return
		end
		-- Sin perfil cargado (o con los datos aún por llegar) no hay dónde marcarla: la verá otra vez.
		local profile = PlayerData.get(player)
		if not profile or profile.cinematicsSeen[SCENE_ID] == true then
			return
		end
		PlayerData.update(player, function(current)
			current.cinematicsSeen[SCENE_ID] = true
		end)
	end)
end

return ShipwreckService
