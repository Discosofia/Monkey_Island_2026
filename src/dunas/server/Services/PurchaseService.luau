--!strict
-- Compras con Developer Products (Fase 9): el ProcessReceipt de este place. La lógica está en
-- ServerShared/Purchases; cada sistema registra sus productos en su propio Start.

local ServerScriptService = game:GetService("ServerScriptService")

local Purchases = require(ServerScriptService.ServerShared.Purchases)

local PurchaseService = {}

function PurchaseService:Start()
	Purchases.start()
end

return PurchaseService
