--!strict
-- Compras con Developer Products (Fase 9): el ProcessReceipt de este place. La lógica está en
-- ServerShared/Purchases; cada sistema registra sus productos en su propio Start. También los
-- regalos de cosméticos (ServerShared/Gifts): sus productos y el buzón de quien entra.

local ServerScriptService = game:GetService("ServerScriptService")

local Gifts = require(ServerScriptService.ServerShared.Gifts)
local Purchases = require(ServerScriptService.ServerShared.Purchases)

local PurchaseService = {}

function PurchaseService:Start()
	Purchases.start()
	Gifts.start()
end

return PurchaseService
