--!strict
-- Cosméticos (estelas, auras, títulos): los mismos que en el Lobby y la Isla. La lógica está en
-- ServerShared/CosmeticsServer.

local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)

local CosmeticsService = {}

function CosmeticsService:Start()
	CosmeticsServer.start()
end

return CosmeticsService
