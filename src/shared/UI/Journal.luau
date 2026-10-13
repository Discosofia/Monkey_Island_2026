--!strict
-- Diario de campo (bestiario, Fase 4): una fila por especie. Las que has derrotado muestran su
-- descripción, horario, zona, botín (con el color de su rareza) y cuántas llevas; las demás, "???".
-- Lo usan la Isla (tecla J) y el Lobby (pestaña "Diario").

local Items = require(script.Parent.Parent.Data.Items)
local Monkeys = require(script.Parent.Parent.Data.Monkeys)
local Rarities = require(script.Parent.Parent.Data.Rarities)
local Widgets = require(script.Parent.Widgets)

local ZONE_NAMES: { [string]: string } = {
	Selva = "Selva",
	Basecamp = "Alrededores del Basecamp",
	Playa = "Playas",
	Rios = "Ríos y manglar",
	Montanas = "Montañas",
	Volcan = "Volcán",
}
local SCHEDULES = { Day = "Día", Night = "Noche", Both = "Día y noche" }

local Journal = {}

local function hex(color: Color3): string
	return string.format("#%02x%02x%02x", color.R * 255, color.G * 255, color.B * 255)
end

local function lootText(definition: Monkeys.MonkeyDefinition): string
	local parts = {}
	for _, entry in definition.loot do
		local item = Items[entry.itemId]
		local rarity = Rarities[item.rarity or "Common"]
		table.insert(parts, `<font color="{hex(rarity.color)}">{item.icon} {item.name}</font>`)
	end
	return table.concat(parts, ", ")
end

-- Ids de especies ordenados por categoría y nombre.
function Journal.sortedSpecies(): { string }
	local ids = {}
	for id in Monkeys do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local da, db = Monkeys[a], Monkeys[b]
		if da.tier ~= db.tier then
			return da.tier < db.tier
		end
		return da.name < db.name
	end)
	return ids
end

-- Rellena "list" (con un UIListLayout) con las filas del diario. Devuelve cuántas has descubierto.
function Journal.fill(list: Instance, bestiary: { [string]: number }): number
	local discovered = 0
	for index, speciesId in Journal.sortedSpecies() do
		local definition = Monkeys[speciesId]
		local kills = bestiary[speciesId] or 0
		local known = kills > 0
		if known then
			discovered += 1
		end

		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -10, 0, if known then 104 else 46)
		row.BackgroundColor3 = Color3.fromRGB(45, 38, 30)
		row.BackgroundTransparency = 0.15
		row.Parent = list
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = row

		local stars = string.rep("⭐", definition.tier)
		local title = Widgets.label(
			if known then `{definition.name}  {stars}  ·  derrotados: {kills}` else `❓ ???  {stars}`,
			row
		)
		title.Position = UDim2.fromOffset(10, 6)
		title.Size = UDim2.new(1, -20, 0, 30)
		title.TextXAlignment = Enum.TextXAlignment.Left

		local zone = ZONE_NAMES[definition.zone or "Selva"] or "Selva"
		if known then
			local detail = Widgets.label("", row)
			detail.RichText = true
			detail.TextScaled = false
			detail.TextSize = 15
			detail.TextWrapped = true
			detail.Font = Enum.Font.BuilderSans
			detail.TextXAlignment = Enum.TextXAlignment.Left
			detail.TextYAlignment = Enum.TextYAlignment.Top
			detail.Position = UDim2.fromOffset(10, 38)
			detail.Size = UDim2.new(1, -20, 0, 62)
			detail.Text =
				`{SCHEDULES[definition.activeAt]} · {zone}\n{definition.description}\nBotín: {lootText(definition)}`
		else
			title.Text ..= `  ·  {zone}, de {string.lower(SCHEDULES[definition.activeAt])}`
		end
	end
	return discovered
end

return Journal
