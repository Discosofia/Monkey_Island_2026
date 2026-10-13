--!strict
-- Inventario de cada jugador durante la partida. Solo el servidor lo cambia.
-- Lo usan la recolección, el botín, la mochila del Espíritu (1.5) y el crafteo (1.6).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)

local InventoryService = {}

function InventoryService.add(player: Player, itemId: string, amount: number)
	assert(Items[itemId], `Ítem desconocido: {itemId}`)
	player:SetAttribute(Inventory.attributeName(itemId), Inventory.count(player, itemId) + amount)
end

-- Quita "amount" del ítem si hay suficiente. Si no alcanza, no quita nada y devuelve false.
function InventoryService.remove(player: Player, itemId: string, amount: number): boolean
	local current = Inventory.count(player, itemId)
	if current < amount then
		return false
	end
	player:SetAttribute(Inventory.attributeName(itemId), current - amount)
	return true
end

return InventoryService
