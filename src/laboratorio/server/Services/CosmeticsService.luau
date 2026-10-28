--!strict
-- Cosméticos (estelas, auras, títulos): los mismos que en el Lobby, la Isla y Dunas. La lógica está en
-- ServerShared/CosmeticsServer. Aquí no se luce el equipo de la Isla: en el Laboratorio todos empiezan
-- igual y solo llegan los cosméticos (docs/LABORATORIO.md §2).

local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)

local CosmeticsService = {}

function CosmeticsService:Start()
	CosmeticsServer.start()
end

return CosmeticsService
