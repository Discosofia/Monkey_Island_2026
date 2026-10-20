--!strict
-- Tienda del equipamiento de la arena en el Lobby (pestaña Arena): la misma que en la base de Dunas
-- (ServerShared/ArenaShop). Aquí se puede comprar y cambiar siempre.

local ServerScriptService = game:GetService("ServerScriptService")

local ArenaShop = require(ServerScriptService.ServerShared.ArenaShop)

local ArenaShopService = {}

function ArenaShopService:Start()
	ArenaShop.start(function()
		return true
	end, function() end)
end

return ArenaShopService
