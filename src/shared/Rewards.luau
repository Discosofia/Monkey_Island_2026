--!strict
-- Premios del bucle de retención (octubre de 2026): cómo se escriben para el jugador. Los reparten el
-- calendario y las misiones (ServerShared/Retention); las provisiones se guardan en el perfil y se
-- entregan al empezar la siguiente partida en la Isla (ServerShared/Supplies).

local Items = require(script.Parent.Data.Items)

local Rewards = {}

-- Solo los ítems que existen y en cantidades enteras positivas.
function Rewards.sanitizeItems(raw: any): { [string]: number }
	local items: { [string]: number } = {}
	if typeof(raw) ~= "table" then
		return items
	end
	for itemId, amount in raw do
		if typeof(itemId) == "string" and Items[itemId] and typeof(amount) == "number" and amount >= 1 then
			items[itemId] = math.floor(amount)
		end
	end
	return items
end

-- "5 🍌 Banano, 2 ➕ Venda", en el orden del inventario (vacío si no hay nada).
function Rewards.describeItems(items: { [string]: number }): string
	local ids = {}
	for itemId in items do
		if Items[itemId] then
			table.insert(ids, itemId)
		end
	end
	table.sort(ids, function(a, b)
		return Items[a].order < Items[b].order
	end)
	local parts = {}
	for _, itemId in ids do
		local item = Items[itemId]
		table.insert(parts, `{items[itemId]} {item.icon} {item.name}`)
	end
	return table.concat(parts, ", ")
end

return Rewards
