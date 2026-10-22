--!strict
-- Cosméticos de pago (Fase 6). La lógica está en ServerShared/CosmeticsServer.
-- Aquí se luce el mejor equipo fabricado en la Isla con cada rol (solo el aspecto).

local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)

local CosmeticsService = {}

function CosmeticsService:Start()
	CosmeticsServer.start({ showBestGear = true })
end

return CosmeticsService
