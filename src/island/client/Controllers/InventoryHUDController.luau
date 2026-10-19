--!strict
-- Materiales y botín del jugador (la mochila de Roblox solo muestra herramientas):
--   - Panel "Bolsa": tecla B en PC, Y en mando o el botón táctil "Bolsa".
--   - Casillas en cuadrícula (icono, cantidad y nombre corto), agrupadas por secciones (Materiales,
--     Comida, Curación, Botín, Tesoros, Equipo) y con el borde del color de su rareza. Con mucho botín la
--     cuadrícula se desplaza en vez de salirse de la pantalla.
--   - Abajo, el detalle del objeto bajo el ratón (o el último tocado): nombre entero, rareza y para
--     qué sirve.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local ActionButtons = require(script.Parent.Parent.ActionButtons)

local ACTION = "ToggleMaterials"
local COLUMNS = 7
local GAP = 6
local PADDING = 12
local HEADER_HEIGHT = 40
local SECTION_TITLE = 20
local FOOTER_HEIGHT = 38
-- Casilla en PC y en pantallas bajas (teléfono apaisado).
local TILE = Vector2.new(64, 76)
local TILE_SMALL = Vector2.new(54, 64)
local SMALL_SCREEN = 500
-- Parte del alto de la pantalla que puede ocupar el panel entero.
local MAX_HEIGHT = 0.8

local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local TILE_COLOR = Color3.fromRGB(45, 38, 30)
local TILE_SELECTED = Color3.fromRGB(70, 58, 42)
local SOFT_COLOR = Color3.fromRGB(210, 200, 185)
local EMPTY_COLOR = Color3.fromRGB(140, 130, 120)
local CLOSE_COLOR = Color3.fromRGB(150, 60, 50)
-- Ventana que se abre a ratos: por encima del HUD (las casillas Z X C V, las barras), como la mesa de
-- fabricación.
local DISPLAY_ORDER = 5

-- Secciones en orden; un objeto va a la suya por "group" (Data/Items) o por lo que hace.
local GROUPS = {
	{ id = "Materials", title = "🌲 Materiales" },
	{ id = "Food", title = "🍖 Comida" },
	{ id = "Healing", title = "➕ Curación" },
	{ id = "Loot", title = "🐾 Botín" },
	{ id = "Treasure", title = "👑 Tesoros de jefe" },
	{ id = "Gear", title = "🧰 Equipo" },
}

local InventoryHUDController = {}

local function sortedItemIds(): { string }
	local ids = {}
	for id in Items do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Items[a].order < Items[b].order
	end)
	return ids
end

local function groupOf(item: Items.ItemDefinition): string
	if item.group then
		return item.group
	elseif item.food then
		return "Food"
	elseif item.heal then
		return "Healing"
	elseif item.alwaysShow then
		return "Materials"
	end
	return "Loot"
end

-- "Pelaje dorado · Poco común · Come: +35 🍖 +5 💧"
local function describe(item: Items.ItemDefinition, count: number): string
	local rarity = Rarities[item.rarity or "Common"] or Rarities.Common
	local parts = { `{item.icon} {item.name} ×{count}`, rarity.name }
	if item.food then
		local gains = `+{item.food.hunger} 🍖`
		if item.food.thirst > 0 then
			gains ..= ` +{item.food.thirst} 💧`
		end
		table.insert(parts, `Comer (G): {gains}`)
	end
	if item.heal then
		table.insert(parts, `Curar (H): +{item.heal} ❤️`)
	end
	if item.note then
		table.insert(parts, item.note)
	end
	return table.concat(parts, " · ")
end

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

type Tile = { button: TextButton, icon: TextLabel, count: TextLabel, name: TextLabel, group: string }

local function newTile(item: Items.ItemDefinition, parent: Instance): Tile
	local rarityColor = (Rarities[item.rarity or "Common"] or Rarities.Common).color
	local button = Instance.new("TextButton")
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = TILE_COLOR
	button.LayoutOrder = item.order
	button.Parent = parent
	corner(button, 8)
	-- Borde del color de la rareza: lo raro se ve de un vistazo aunque la bolsa esté llena.
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = rarityColor
	stroke.Thickness = if item.rarity and item.rarity ~= "Common" then 2 else 1
	stroke.Transparency = if item.rarity and item.rarity ~= "Common" then 0 else 0.6
	stroke.Parent = button

	local icon = Widgets.label(item.icon, button)
	icon.Name = "Icon"
	icon.Position = UDim2.fromScale(0.1, 0.06)
	icon.Size = UDim2.fromScale(0.8, 0.54)

	local count = Widgets.label("0", button)
	count.Name = "Count"
	count.Font = Enum.Font.BuilderSansExtraBold
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -3, 0, 1)
	count.Size = UDim2.fromScale(0.6, 0.24)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.TextStrokeTransparency = 0.2
	count.ZIndex = 2

	local name = Widgets.label(item.name, button)
	name.Name = "ItemName"
	name.Font = Enum.Font.BuilderSans
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -2)
	name.Size = UDim2.new(1, -4, 0.36, 0)
	name.TextColor3 = rarityColor
	name.TextWrapped = true
	name.TextStrokeTransparency = 0.6
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 12
	limit.Parent = name

	return { button = button, icon = icon, count = count, name = name, group = groupOf(item) }
end

local function newSection(order: number, title: string, parent: Instance): (Frame, Frame)
	local section = Instance.new("Frame")
	section.Name = title
	section.LayoutOrder = order
	section.BackgroundTransparency = 1
	section.Size = UDim2.fromScale(1, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = section

	local heading = Widgets.label(title, section)
	heading.LayoutOrder = 0
	heading.Size = UDim2.new(1, 0, 0, SECTION_TITLE)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = SOFT_COLOR

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.LayoutOrder = 1
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Parent = section
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.CellPadding = UDim2.fromOffset(GAP, GAP)
	gridLayout.CellSize = UDim2.fromOffset(TILE.X, TILE.Y)
	gridLayout.Parent = grid
	return section, grid
end

function InventoryHUDController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("InventoryHUD", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = DISPLAY_ORDER

	local panel = Instance.new("Frame")
	panel.Name = "MaterialsPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.08
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, PADDING)
	padding.PaddingRight = UDim.new(0, PADDING)
	padding.Parent = panel

	local title = Widgets.label("🎒 Bolsa", panel)
	title.Name = "Title"
	title.Size = UDim2.new(1, -52, 0, HEADER_HEIGHT)
	title.TextXAlignment = Enum.TextXAlignment.Left

	-- "X" y no "✕": BuilderSans no tiene ese signo y sale una caja vacía.
	local close = Widgets.button("X", panel)
	close.Name = "Close"
	close.Font = Enum.Font.BuilderSansExtraBold
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 4, 0, -2)
	close.Size = UDim2.fromOffset(44, 44)
	close.BackgroundColor3 = CLOSE_COLOR
	close.TextColor3 = Color3.new(1, 1, 1)
	close.ZIndex = 3
	local closeLimit = close:FindFirstChildOfClass("UISizeConstraint")
	if closeLimit then
		closeLimit.MinSize = Vector2.new(44, 44)
	end
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"
	scroll.Position = UDim2.fromOffset(0, HEADER_HEIGHT + 4)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = SOFT_COLOR
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Parent = scroll
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 8)
	contentLayout.Parent = content

	local footer = Widgets.label("", panel)
	footer.Name = "Detail"
	footer.Font = Enum.Font.BuilderSans
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT)
	footer.TextWrapped = true
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.TextColor3 = SOFT_COLOR
	local footerLimit = Instance.new("UITextSizeConstraint")
	footerLimit.MaxTextSize = 15
	footerLimit.Parent = footer

	local sections: { [string]: Frame } = {}
	local grids: { [string]: Frame } = {}
	for index, group in GROUPS do
		sections[group.id], grids[group.id] = newSection(index, group.title, content)
	end

	local tiles: { [string]: Tile } = {}
	local counts: { [string]: number } = {}
	local selected: string? = nil

	local function hint(): string
		return if UserInputService.TouchEnabled
			then "Toca un objeto para ver qué es"
			else "Pasa el ratón por un objeto para ver qué es"
	end

	local function selectItem(itemId: string?)
		if selected and tiles[selected] then
			tiles[selected].button.BackgroundColor3 = TILE_COLOR
		end
		selected = itemId
		if itemId and tiles[itemId] then
			tiles[itemId].button.BackgroundColor3 = TILE_SELECTED
			footer.Text = describe(Items[itemId], counts[itemId] or 0)
		else
			footer.Text = hint()
		end
	end

	-- Las secciones sin nada que enseñar se ocultan.
	local function refreshSections()
		for groupId, section in sections do
			local any = false
			for _, tile in tiles do
				if tile.group == groupId and tile.button.Visible then
					any = true
					break
				end
			end
			section.Visible = any
		end
	end

	-- Tamaño de las casillas según la pantalla y alto del panel: crece con lo que hay hasta
	-- MAX_HEIGHT y, a partir de ahí, la cuadrícula se desplaza.
	local function resize()
		local screenHeight = gui.AbsoluteSize.Y
		local tile = if screenHeight < SMALL_SCREEN then TILE_SMALL else TILE
		for _, grid in grids do
			local gridLayout = grid:FindFirstChildOfClass("UIGridLayout")
			if gridLayout then
				gridLayout.CellSize = UDim2.fromOffset(tile.X, tile.Y)
			end
		end
		-- Sitio para la barra de desplazamiento a la derecha.
		local width = COLUMNS * tile.X + (COLUMNS - 1) * GAP + scroll.ScrollBarThickness + 4
		local contentHeight = contentLayout.AbsoluteContentSize.Y
		local chrome = HEADER_HEIGHT + 4 + FOOTER_HEIGHT + 4 + 16
		local listHeight = math.max(tile.Y, math.min(contentHeight, screenHeight * MAX_HEIGHT - chrome))
		scroll.Size = UDim2.fromOffset(width, listHeight)
		scroll.CanvasSize = UDim2.fromOffset(0, contentHeight)
		panel.Size = UDim2.fromOffset(width + 2 * PADDING, listHeight + chrome)
	end

	for _, itemId in sortedItemIds() do
		local item = Items[itemId]
		local tile = newTile(item, grids[groupOf(item)])
		tile.button.Name = itemId
		tiles[itemId] = tile

		local function refresh()
			local count = Inventory.count(player, itemId)
			counts[itemId] = count
			tile.count.Text = tostring(count)
			-- Los materiales básicos se ven siempre (apagados con 0); el botín, cuando tienes alguno.
			local empty = count <= 0
			tile.icon.TextTransparency = if empty then 0.6 else 0
			tile.count.TextColor3 = if empty then EMPTY_COLOR else Color3.new(1, 1, 1)
			local visible = item.alwaysShow == true or not empty
			if tile.button.Visible ~= visible then
				tile.button.Visible = visible
				refreshSections()
			end
			if selected == itemId then
				footer.Text = describe(item, count)
			end
		end
		player:GetAttributeChangedSignal(Inventory.attributeName(itemId)):Connect(refresh)
		tile.button.MouseEnter:Connect(function()
			selectItem(itemId)
		end)
		tile.button.Activated:Connect(function()
			selectItem(itemId)
		end)
		refresh()
	end
	refreshSections()
	selectItem(nil)

	contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()

	local function refreshTitle()
		title.Text = if UserInputService.TouchEnabled then "🎒 Bolsa" else "🎒 Bolsa (B)"
	end
	refreshTitle()

	ActionButtons.bind(ACTION, "Bolsa", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			panel.Visible = not panel.Visible
			if panel.Visible then
				refreshTitle()
				selectItem(selected)
				resize()
			end
		end
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.B, Enum.KeyCode.ButtonY)
end

return InventoryHUDController
