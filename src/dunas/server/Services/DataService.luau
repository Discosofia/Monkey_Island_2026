--!strict
-- Datos guardados del jugador en la arena (ServerShared/PlayerData, el mismo perfil que en el Lobby y
-- la Isla): Ámbar, rol de la arena, cosméticos y mascota.

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

local DataService = {}

function DataService:Start()
	PlayerData.start()
end

return DataService
