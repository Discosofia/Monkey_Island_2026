--!strict
-- Diario de campo (bestiario, Fase 4): una fila por especie y, debajo, una por jefe (Data/Bosses).
-- Los que has derrotado muestran su descripción, horario o guarida, zona, botín (con el color de su
-- rareza) y cuántas veces; los demás, "???". Lo usan la Isla (tecla J) y el Lobby (pestaña "Diario").

local Bosses = require(script.Parent.Parent.Data.Bosses)
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
	Cuevas = "Cuevas",
}
local SCHEDULES = { Day = "Día", Night = "Noche", Both = "Día y noche" }

local Journal = {}

local function hex(color: Color3): string
	return string.format("#%02x%02x%02x", color.R * 255, color.G * 255, color.B * 255)
end

local function itemText(itemId: string): string
	local item = Items[itemId]
	local rarity = Rarities[item.rarity or "Common"]
	return `<font color="{hex(rarity.color)}">{item.icon} {item.name}</font>`
end

local function lootText(definition: Monkeys.MonkeyDefinition): string
	local parts = {}
	for _, entry in definition.loot do
		table.insert(parts, itemText(entry.itemId))
	end
	return table.concat(parts, ", ")
end

-- Ids de jefes ordenados de menos a más vida.
function Journal.sortedBosses(): { string }
	local ids = {}
	for id in Bosses do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Bosses[a].maxHealth < Bosses[b].maxHealth
	end)
	return ids
end

-- Cuántas entradas tiene el diario (especies y jefes).
function Journal.total(): number
	return #Journal.sortedSpecies() + #Journal.sortedBosses()
end

-- Una fila del diario: título y, si ya lo conoces, el detalle debajo. La fila crece con el detalle (en
-- una columna estrecha, como el Diario del Lobby repartido en columnas, ocupa más líneas).
local function addRow(list: Instance, order: number, titleText: string, detailText: string?)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -10, 0, if detailText then 0 else 46)
	row.AutomaticSize = if detailText then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	row.BackgroundColor3 = Color3.fromRGB(45, 38, 30)
	row.BackgroundTransparency = 0.15
	row.Parent = list
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = row

	local title = Widgets.label(titleText, row)
	title.Position = UDim2.fromOffset(10, 6)
	title.Size = UDim2.new(1, -20, 0, 30)
	title.TextXAlignment = Enum.TextXAlignment.Left

	if detailText then
		local detail = Widgets.label("", row)
		detail.RichText = true
		detail.TextScaled = false
		detail.TextSize = 15
		detail.TextWrapped = true
		detail.Font = Enum.Font.BuilderSans
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextYAlignment = Enum.TextYAlignment.Top
		detail.Position = UDim2.fromOffset(10, 38)
		detail.Size = UDim2.new(1, -20, 0, 0)
		detail.AutomaticSize = Enum.AutomaticSize.Y
		detail.Text = detailText
		local padding = Instance.new("UIPadding")
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = row
	end
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

-- Rellena "list" (con un UIListLayout) con las filas del diario: especies, el título "Jefes" y los
-- jefes. Devuelve cuántas entradas has descubierto.
function Journal.fill(list: Instance, bestiary: { [string]: number }): number
	local discovered = 0
	local order = 0
	for _, speciesId in Journal.sortedSpecies() do
		local definition = Monkeys[speciesId]
		local kills = bestiary[speciesId] or 0
		local stars = string.rep("⭐", definition.tier)
		local zone = ZONE_NAMES[definition.zone or "Selva"] or "Selva"
		local schedule = SCHEDULES[definition.activeAt]
		order += 1
		if kills > 0 then
			discovered += 1
			addRow(
				list,
				order,
				`{definition.name}  {stars}  ·  derrotados: {kills}`,
				`{schedule} · {zone}\n{definition.description}\nBotín: {lootText(definition)}`
			)
		else
			addRow(list, order, `❓ ???  {stars}  ·  {zone}, de {string.lower(schedule)}`)
		end
	end

	order += 1
	local heading = Widgets.label("👑 Jefes", list)
	heading.LayoutOrder = order
	heading.Size = UDim2.new(1, -10, 0, 34)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = Color3.fromRGB(255, 210, 120)

	for _, bossId in Journal.sortedBosses() do
		local boss = Bosses[bossId]
		local defeats = bestiary[bossId] or 0
		local zone = ZONE_NAMES[boss.biome] or boss.biome
		order += 1
		if defeats > 0 then
			discovered += 1
			addRow(
				list,
				order,
				`👑 {boss.name}  ·  derrotado: {defeats}`,
				`Guarida: {zone}\n{boss.description}\nBotín: {itemText(boss.lootItemId)} y una pieza de la baliza`
			)
		else
			addRow(list, order, `❓ ???  👑  ·  guarida: {zone}`)
		end
	end
	return discovered
end

return Journal
