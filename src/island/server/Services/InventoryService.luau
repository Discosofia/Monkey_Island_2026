--!strict
-- Inventario de cada jugador durante la partida. Solo el servidor lo cambia.
-- Fase 1.5: al pasar a Espíritu se dejará parte del inventario en una mochila.
-- Fase 1.6: el crafteo gastará materiales.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)

local InventoryService = {}

function InventoryService.add(player: Player, itemId: string, amount: number)
	assert(Items[itemId], `Ítem desconocido: {itemId}`)
	player:SetAttribute(Inventory.attributeName(itemId), Inventory.count(player, itemId) + amount)
end

return InventoryService
