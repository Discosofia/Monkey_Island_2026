--!strict
-- Premios del bucle de retención (octubre de 2026): cómo se escriben para el jugador. Los reparten el
-- calendario y las misiones (ServerShared/Retention); las provisiones se guardan en el perfil y se
-- entregan al empezar la siguiente partida en la Isla (ServerShared/Supplies).

local Config = require(script.Parent.Config)
local EggIncubation = require(script.Parent.EggIncubation)
local Items = require(script.Parent.Data.Items)
local Rarities = require(script.Parent.Data.Rarities)

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

local function eggLabel(weights: { [string]: number }): string
	-- La rareza más baja posible: "Huevo Raro o mejor" (o solo "Huevo Épico" si es la única).
	local lowest: string? = nil
	local count = 0
	for rarity, weight in weights do
		if Rarities[rarity] and weight > 0 then
			count += 1
			if not lowest or Rarities[rarity].order < Rarities[lowest].order then
				lowest = rarity
			end
		end
	end
	if not lowest then
		return "Huevo"
	end
	return `Huevo {Rarities[lowest].name}{if count > 1 then " o mejor" else ""}`
end

-- Cada parte de un premio, de lo más valioso a lo menos: "🥚 Huevo Raro o mejor", "500 ✨ Ámbar",
-- "⏩ 2 h para tu huevo", "5 🍌 Banano"…
function Rewards.parts(reward: Config.Reward): { string }
	local parts = {}
	if reward.egg then
		table.insert(parts, `🥚 {eggLabel(reward.egg)}`)
	end
	if reward.amber then
		table.insert(parts, `{reward.amber} ✨ Ámbar`)
	end
	if reward.eggSeconds then
		table.insert(parts, `⏩ {EggIncubation.formatTime(reward.eggSeconds)} para tu huevo`)
	end
	if reward.items then
		local items = Rewards.describeItems(Rewards.sanitizeItems(reward.items))
		if items ~= "" then
			table.insert(parts, `🎒 {items}`)
		end
	end
	return parts
end

function Rewards.describe(reward: Config.Reward): string
	return table.concat(Rewards.parts(reward), " · ")
end

-- Versión corta para una casilla pequeña: "100 ✨  5 🍌", "🥚 Raro+  500 ✨".
function Rewards.compact(reward: Config.Reward): string
	local parts = {}
	if reward.egg then
		-- (string.gsub devuelve dos valores: por eso va en dos pasos.)
		local label = string.gsub(eggLabel(reward.egg), "^Huevo ", "")
		label = string.gsub(label, " o mejor$", "+")
		table.insert(parts, `🥚 {label}`)
	end
	if reward.amber then
		table.insert(parts, `{reward.amber} ✨`)
	end
	if reward.eggSeconds then
		table.insert(parts, `⏩ {reward.eggSeconds // 3600} h`)
	end
	if reward.items then
		local items = Rewards.sanitizeItems(reward.items)
		local ids = {}
		for itemId in items do
			table.insert(ids, itemId)
		end
		table.sort(ids, function(a, b)
			return Items[a].order < Items[b].order
		end)
		for _, itemId in ids do
			table.insert(parts, `{items[itemId]} {Items[itemId].icon}`)
		end
	end
	return table.concat(parts, "  ")
end

return Rewards
