--!strict
-- Guardado de datos en el Lobby (Fase 2.8): carga el perfil de cada jugador para mostrar su Ámbar
-- y su récord (atributos "Amber" y "BestDays"), y lo guarda al salir.

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

local DataService = {}

function DataService:Start()
	PlayerData.start()
end

return DataService
