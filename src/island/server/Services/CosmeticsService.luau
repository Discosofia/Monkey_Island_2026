--!strict
-- Cosméticos de pago (Fase 6). La lógica está en ServerShared/CosmeticsServer.

local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)

local CosmeticsService = {}

function CosmeticsService:Start()
	CosmeticsServer.start()
end

return CosmeticsService
