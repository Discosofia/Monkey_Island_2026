--!strict
-- Premios del bucle de retención (octubre de 2026): cómo se escriben para el jugador. Los reparten el
-- calendario, las misiones (ServerShared/Retention) y el pase de temporada (ServerShared/SeasonPass,
-- que además da cosméticos); las provisiones se guardan en el perfil y se entregan al empezar la
-- siguiente partida en la Isla (ServerShared/Supplies).

local Config = require(script.Parent.Config)
local Cosmetics = require(script.Parent.Data.Cosmetics)
local EggIncubation = require(script.Parent.EggIncubation)
local Items = require(script.Parent.Data.Items)
local Rarities = require(script.Parent.Data.Rarities)
local Strings = require(script.Parent.Strings)

local T = Strings.t
local later = Strings.later

local Rewards = {}

-- Tipo de cosmético en una palabra, para las casillas pequeñas (Rewards.compact).
local KIND_NAMES: { [string]: string } = {
	Trail = later("Estela"),
	Title = later("Título"),
	Aura = later("Aura"),
	Outfit = later("Traje"),
	WeaponSkin = later("Arma"),
	PetSkin = later("Mascota"),
	Emote = later("Emote"),
	Frame = later("Marco"),
	NumberStyle = later("Números"),
	BurstStyle = later("Estallido"),
	NestDecor = later("Nido"),
}

-- El tipo de un cosmético en una palabra ("Estela", "Traje"…), en el idioma del jugador.
function Rewards.kindName(kind: string): string
	return if KIND_NAMES[kind] then T(KIND_NAMES[kind]) else kind
end

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

-- Los objetos como argumento de una frase (Shared/Strings): "5 🍌 Banano, 2 ➕ Venda", en el orden del
-- inventario. El servidor lo manda así por un remoto para que el cliente lo traduzca.
function Rewards.itemsArg(items: { [string]: number }): { list: { any } }
	local ids = {}
	for itemId in items do
		if Items[itemId] then
			table.insert(ids, itemId)
		end
	end
	table.sort(ids, function(a, b)
		return Items[a].order < Items[b].order
	end)
	local list = {}
	for _, itemId in ids do
		local item = Items[itemId]
		table.insert(
			list,
			{ later("{n} {icon} {name}"), { n = items[itemId], icon = item.icon, name = { item.name } } }
		)
	end
	return { list = list }
end

-- "5 🍌 Banano, 2 ➕ Venda" en el idioma del jugador (vacío si no hay nada).
function Rewards.describeItems(items: { [string]: number }): string
	return Strings.arg(Rewards.itemsArg(items))
end

-- La rareza más baja posible del huevo y si puede salir mejor ("Huevo Raro o mejor", o solo "Huevo
-- Épico" si es la única). nil si no hay ninguna.
local function eggRarity(weights: { [string]: number }): (string?, boolean)
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
	return lowest, count > 1
end

local function eggLabel(weights: { [string]: number }): string
	local lowest, better = eggRarity(weights)
	if not lowest then
		return T("Huevo")
	end
	local rarity = T(Rarities[lowest].name)
	return if better then T("Huevo {rarity} o mejor", { rarity = rarity }) else T("Huevo {rarity}", { rarity = rarity })
end

-- Cada parte de un premio, de lo más valioso a lo menos: "🎨 Título: Señor del Volcán",
-- "🥚 Huevo Raro o mejor", "500 ✨ Ámbar", "⏩ 2 h para tu huevo", "5 🍌 Banano", "⭐ 150 XP de pase"…
-- "cosmetic" solo lo llevan los premios del pase (Data/Seasons).
function Rewards.parts(reward: Config.Reward & { cosmetic: string? }): { string }
	local parts = {}
	local cosmetic = if reward.cosmetic then Cosmetics[reward.cosmetic] else nil
	if cosmetic then
		table.insert(parts, `{cosmetic.icon} {T(cosmetic.name)}`)
	end
	if reward.egg then
		table.insert(parts, `🥚 {eggLabel(reward.egg)}`)
	end
	if reward.amber then
		table.insert(parts, T("{n} ✨ Ámbar", { n = reward.amber }))
	end
	if reward.eggSeconds then
		table.insert(parts, T("⏩ {time} para tu huevo", { time = EggIncubation.formatTime(reward.eggSeconds) }))
	end
	if reward.items then
		local items = Rewards.describeItems(Rewards.sanitizeItems(reward.items))
		if items ~= "" then
			table.insert(parts, `🎒 {items}`)
		end
	end
	if reward.xp then
		table.insert(parts, T("⭐ {n} XP de pase", { n = reward.xp }))
	end
	return parts
end

function Rewards.describe(reward: Config.Reward & { cosmetic: string? }): string
	return table.concat(Rewards.parts(reward), " · ")
end

-- Versión corta para una casilla pequeña: "100 ✨  5 🍌", "🥚 Raro+  500 ✨", "⭐ 200 XP  40 ✨".
function Rewards.compact(reward: Config.Reward & { cosmetic: string? }): string
	local parts = {}
	if reward.xp then
		table.insert(parts, `⭐ {reward.xp} XP`)
	end
	local cosmetic = if reward.cosmetic then Cosmetics[reward.cosmetic] else nil
	if cosmetic then
		table.insert(
			parts,
			`{cosmetic.icon} {if KIND_NAMES[cosmetic.kind] then T(KIND_NAMES[cosmetic.kind]) else T(cosmetic.name)}`
		)
	end
	if reward.egg then
		local lowest, better = eggRarity(reward.egg)
		local label = if lowest then T(Rarities[lowest].name) else T("Huevo")
		table.insert(parts, `🥚 {label}{if lowest and better then "+" else ""}`)
	end
	if reward.amber then
		table.insert(parts, `{reward.amber} ✨`)
	end
	if reward.eggSeconds then
		table.insert(
			parts,
			if reward.eggSeconds >= 3600
				then `⏩ {reward.eggSeconds / 3600 // 0.5 * 0.5} h`
				else `⏩ {reward.eggSeconds // 60} min`
		)
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
