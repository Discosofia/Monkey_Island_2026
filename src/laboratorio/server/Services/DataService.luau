--!strict
-- Datos guardados del jugador en el Laboratorio (ServerShared/PlayerData, el mismo perfil que en el
-- Lobby, la Isla y Dunas). Aquí solo cuentan los cosméticos y la mascota de adorno.

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

local DataService = {}

function DataService:Start()
	PlayerData.start()
end

return DataService
