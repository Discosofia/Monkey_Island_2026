--!strict
-- Lectura del inventario de un jugador. Cada ítem es un atributo del Player ("Inv_Wood" = 12…).
-- Solo el servidor lo modifica (InventoryService); Roblox replica los atributos a los clientes.

local PREFIX = "Inv_"

local Inventory = {}

function Inventory.attributeName(itemId: string): string
	return PREFIX .. itemId
end

function Inventory.count(player: Player, itemId: string): number
	local value = player:GetAttribute(PREFIX .. itemId)
	return if typeof(value) == "number" then value else 0
end

return Inventory
