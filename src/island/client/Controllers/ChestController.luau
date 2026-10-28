--!strict
-- Ventana del cofre de una parcela permanente (Fase 12, P4; ChestService). La abre el aviso «Abrir» del
-- cofre (Plot.CHEST_PROMPT), que todos ven:
--   - Al dueño, dos columnas: su Bolsa (lo que se puede guardar, Data/Items "storable"; tocar guarda en lo
--     privado o en lo compartido, según el selector) y el cofre entero (tocar saca a la Bolsa), con las
--     casillas usadas de su nivel.
--   - A los demás, solo lo compartido del dueño (tocar lo coge para su Bolsa de la partida).
--   - Abajo, cuánto mueve cada toque (1, 10 o todo) y el detalle del último objeto tocado o señalado.
-- Lo guardado se lee del atributo "Plot" del dueño (Shared/Plot), que ven todos los clientes. Sin
-- desplazamiento: las casillas encogen para caber; en pantallas bajas (teléfono) ocupa toda la pantalla.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Plot = require(ReplicatedStorage.Shared.Plot)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local T = Strings.t
local later = Strings.later

local CLOSE_ACTION = "CloseChest"
local GAP = 6
local PADDING = 12
local HEADER_HEIGHT = 44
local COLUMN_TITLE = 32
local FOOTER_HEIGHT = 44
-- Casilla en PC y en pantallas bajas (teléfono apaisado); nunca más estrecha que MIN_TILE (el dedo).
local TILE = Vector2.new(64, 76)
local TILE_SMALL = Vector2.new(54, 64)
local MIN_TILE = 44
-- Columnas de casillas en PC: dos columnas de 5 al dueño, una de 6 a los demás.
local OWNER_COLUMNS = 5
local GUEST_COLUMNS = 6
local SMALL_SCREEN = 500
local MAX_HEIGHT = 0.86
-- Margen extra (studs) sobre la distancia del aviso antes de cerrar al alejarse.
local CLOSE_MARGIN = 3
-- "Todo": el servidor lo recorta a lo que hay y a lo que cabe.
local ALL = 1e6
local AMOUNTS = { { text = "1", amount = 1 }, { text = "10", amount = 10 }, { text = later("Todo"), amount = ALL } }
-- Ventana que se abre a ratos, por encima de los botones táctiles de combate (ActionButtons, 5).
local DISPLAY_ORDER = 6

local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local TILE_COLOR = Color3.fromRGB(45, 38, 30)
local OFF_COLOR = Color3.fromRGB(70, 60, 48)
local SOFT_COLOR = Color3.fromRGB(210, 200, 185)
local CLOSE_COLOR = Color3.fromRGB(150, 60, 50)
local GOLD = Color3.fromRGB(255, 205, 70)
local ACTION_COLOR = Color3.fromRGB(242, 178, 36)
local ACTION_TEXT = Color3.fromRGB(40, 25, 5)

local PART_BADGE = { private = "🔒", shared = "🤝" }

type Tile = { button: TextButton, count: TextLabel, key: string }

local ChestController = {}

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

-- Botón pequeño de elegir (cantidad, parte del cofre): dorado el elegido, madera los demás.
local function toggleButton(text: string, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Text = text
	button.Font = Enum.Font.BuilderSansBold
	button.TextScaled = true
	button.AutoButtonColor = true
	button.Parent = parent
	corner(button, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = button
	return button
end

local function setToggle(button: TextButton, on: boolean)
	button.BackgroundColor3 = if on then ACTION_COLOR else OFF_COLOR
	button.TextColor3 = if on then ACTION_TEXT else Color3.new(1, 1, 1)
end

-- Casilla de un objeto (como las de la Bolsa): icono, cantidad arriba a la derecha, nombre abajo y, en
-- las del cofre, 🔒/🤝 arriba a la izquierda.
local function newTile(itemId: string, badge: string?, parent: Instance): Tile
	local item = Items[itemId]
	local rarityColor = (Rarities[item.rarity or "Common"] or Rarities.Common).color
	local button = Instance.new("TextButton")
	button.Name = itemId
	button.Text = ""
	button.AutoButtonColor = true
	button.BackgroundColor3 = TILE_COLOR
	button.Parent = parent
	corner(button, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = rarityColor
	stroke.Thickness = if item.rarity and item.rarity ~= "Common" then 2 else 1
	stroke.Transparency = if item.rarity and item.rarity ~= "Common" then 0 else 0.6
	stroke.Parent = button

	local icon = Widgets.label(item.icon, button)
	icon.Position = UDim2.fromScale(0.1, 0.1)
	icon.Size = UDim2.fromScale(0.8, 0.5)

	local count = Widgets.label("0", button)
	count.Font = Enum.Font.BuilderSansExtraBold
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -3, 0, 1)
	count.Size = UDim2.fromScale(0.6, 0.24)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.TextStrokeTransparency = 0.2
	count.ZIndex = 2

	if badge then
		local mark = Widgets.label(badge, button)
		mark.Position = UDim2.fromOffset(2, 1)
		mark.Size = UDim2.fromScale(0.34, 0.24)
		mark.TextXAlignment = Enum.TextXAlignment.Left
		mark.ZIndex = 2
	end

	local name = Widgets.label(T(item.name), button)
	name.Font = Enum.Font.BuilderSans
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -2)
	name.Size = UDim2.new(1, -4, 0.34, 0)
	name.TextColor3 = rarityColor
	name.TextWrapped = true
	name.TextStrokeTransparency = 0.6
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 12
	limit.Parent = name

	return { button = button, count = count, key = itemId }
end

-- Columna con su título arriba y una cuadrícula de casillas debajo (se desplaza solo si ni encogiendo
-- caben, lo que no debería pasar).
local function newColumn(parent: Instance): (Frame, Frame, ScrollingFrame, UIGridLayout)
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.Parent = parent
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, COLUMN_TITLE)
	header.Parent = column
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromOffset(0, COLUMN_TITLE + 4)
	grid.Size = UDim2.new(1, 0, 1, -(COLUMN_TITLE + 4))
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.ScrollBarImageColor3 = SOFT_COLOR
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = column
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(GAP, GAP)
	layout.Parent = grid
	return column, header, grid, layout
end

-- La casilla más grande (hasta "base") con la que caben "count" casillas en "area".
local function fitTile(area: Vector2, count: number, base: Vector2): Vector2
	local tile = base
	while tile.X > MIN_TILE do
		local columns = math.max(1, math.floor((area.X + GAP) / (tile.X + GAP)))
		if math.ceil(count / columns) * (tile.Y + GAP) - GAP <= area.Y then
			break
		end
		tile *= 0.92
	end
	local width = math.max(MIN_TILE, math.floor(tile.X))
	return Vector2.new(width, math.floor(width * base.Y / base.X))
end

local function sortByOrder(ids: { string })
	table.sort(ids, function(a, b)
		return Items[a].order < Items[b].order
	end)
end

function ChestController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("ChestHUD", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = DISPLAY_ORDER

	local panel = Instance.new("Frame")
	panel.Name = "ChestWindow"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.08
	panel.Active = true
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, PADDING)
	padding.PaddingRight = UDim.new(0, PADDING)
	padding.Parent = panel

	local title = Widgets.label(T("📦 Cofre"), panel)
	title.Name = "Title"
	title.Size = UDim2.new(1, -56, 0, HEADER_HEIGHT - 6)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = GOLD

	-- "X" y no "✕": BuilderSans no tiene ese signo y sale una caja vacía.
	local closeButton = Widgets.button("X", panel)
	closeButton.Name = "Close"
	closeButton.Font = Enum.Font.BuilderSansExtraBold
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, 4, 0, -2)
	closeButton.Size = UDim2.fromOffset(44, 44)
	closeButton.BackgroundColor3 = CLOSE_COLOR
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	local closeLimit = closeButton:FindFirstChildOfClass("UISizeConstraint")
	if closeLimit then
		closeLimit:Destroy()
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
	body.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + FOOTER_HEIGHT + 4))
	body.Parent = panel

	-- Columna de la Bolsa (solo el dueño): título y a qué parte se guarda.
	local bagColumn, bagHeader, bagGrid, bagLayout = newColumn(body)
	bagColumn.Name = "Bag"
	local bagTitle = Widgets.label(T("🎒 Guardar en"), bagHeader)
	bagTitle.Size = UDim2.fromScale(0.34, 1)
	bagTitle.TextXAlignment = Enum.TextXAlignment.Left
	bagTitle.TextColor3 = SOFT_COLOR
	local partButtons: { [string]: TextButton } = {}
	for index, part in Plot.CHEST_PARTS do
		local button = toggleButton(if part == "private" then T("🔒 Privado") else T("🤝 Compartido"), bagHeader)
		button.Name = part
		button.Position = UDim2.new(0.34 + (index - 1) * 0.33, 4, 0, 0)
		button.Size = UDim2.new(0.33, -4, 1, 0)
		partButtons[part] = button
	end

	local chestColumn, chestHeader, chestGrid, chestLayout = newColumn(body)
	chestColumn.Name = "Chest"
	local chestTitle = Widgets.label("", chestHeader)
	chestTitle.Size = UDim2.fromScale(1, 1)
	chestTitle.TextXAlignment = Enum.TextXAlignment.Left
	chestTitle.TextColor3 = SOFT_COLOR

	-- Abajo: el detalle a la izquierda y cuánto mueve cada toque a la derecha.
	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT)
	footer.Parent = panel
	local detail = Widgets.label("", footer)
	detail.Name = "Detail"
	detail.Font = Enum.Font.BuilderSans
	detail.Size = UDim2.new(1, -184, 1, 0)
	detail.TextWrapped = true
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = SOFT_COLOR
	local detailLimit = Instance.new("UITextSizeConstraint")
	detailLimit.MaxTextSize = 15
	detailLimit.Parent = detail
	local amountButtons: { TextButton } = {}
	for index, option in AMOUNTS do
		local button = toggleButton(if option.amount == ALL then T(option.text) else option.text, footer)
		button.Name = `Amount{option.text}`
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = UDim2.new(1, -(#AMOUNTS - index) * 60, 0, 0)
		button.Size = UDim2.fromOffset(56, FOOTER_HEIGHT)
		amountButtons[index] = button
	end

	local owner: Player? = nil
	local prompt: ProximityPrompt? = nil
	local amountIndex = 2
	local storePart = "private"
	local tiles: { [string]: Tile } = {}
	local connections: { RBXScriptConnection } = {}

	local function isOwner(): boolean
		return owner == player
	end

	local function hint(): string
		local touch = UserInputService.TouchEnabled
		if isOwner() then
			return if touch
				then T("Toca un objeto para guardarlo o sacarlo")
				else T("Pulsa un objeto para guardarlo o sacarlo")
		end
		return if touch
			then T("Toca un objeto para cogerlo: va a tu Bolsa")
			else T("Pulsa un objeto para cogerlo: va a tu Bolsa")
	end

	local function describe(itemId: string, count: number, where: string)
		local item = Items[itemId]
		detail.Text = T(
			"{icon} {name} ×{n} · {where}",
			{ icon = item.icon, name = { item.name }, n = count, where = { where } }
		)
	end

	local function refreshToggles()
		for index, button in amountButtons do
			setToggle(button, index == amountIndex)
		end
		for part, button in partButtons do
			setToggle(button, part == storePart)
		end
	end

	-- Tamaño de la ventana (PC: a su contenido; pantalla baja: entera) y de las casillas para que quepan.
	local function layout()
		if not panel.Visible then
			return
		end
		local screen = gui.AbsoluteSize
		local small = screen.Y < SMALL_SCREEN
		local base = if small then TILE_SMALL else TILE
		local mine = isOwner()
		local columns = if mine then OWNER_COLUMNS else GUEST_COLUMNS
		local bagCount, chestCount = #bagGrid:GetChildren() - 1, #chestGrid:GetChildren() - 1
		bagColumn.Visible = mine
		if small then
			panel.Size = UDim2.fromScale(0.97, 0.94)
		else
			-- Con mucho que enseñar, la ventana se ensancha (más columnas) antes de encoger las casillas.
			local chrome = 16 + HEADER_HEIGHT + COLUMN_TITLE + 4 + 4 + FOOTER_HEIGHT
			local most = math.max(if mine then bagCount else 0, chestCount)
			local maxRows = math.max(1, math.floor((screen.Y * MAX_HEIGHT - chrome + GAP) / (base.Y + GAP)))
			local maxColumns = math.floor((screen.X * 0.95 / (if mine then 2 else 1) + GAP) / (base.X + GAP))
			columns = math.clamp(math.ceil(most / maxRows), columns, math.max(columns, maxColumns))
			local columnWidth = columns * base.X + (columns - 1) * GAP
			local rows = math.max(2, math.ceil(most / columns))
			local gridHeight = rows * (base.Y + GAP) - GAP
			local width = (if mine then 2 * columnWidth + 2 * GAP else columnWidth) + 2 * PADDING
			panel.Size =
				UDim2.fromOffset(math.max(width, 420), math.min(gridHeight + chrome, math.floor(screen.Y * MAX_HEIGHT)))
		end
		if mine then
			bagColumn.Size = UDim2.new(0.5, -GAP, 1, 0)
			chestColumn.Position = UDim2.new(0.5, GAP, 0, 0)
			chestColumn.Size = UDim2.new(0.5, -GAP, 1, 0)
		else
			chestColumn.Position = UDim2.new()
			chestColumn.Size = UDim2.fromScale(1, 1)
		end
		local bagTile = fitTile(bagGrid.AbsoluteSize, bagCount, base)
		local chestTile = fitTile(chestGrid.AbsoluteSize, chestCount, base)
		-- Las dos columnas con la misma casilla: la más pequeña de las dos.
		local tile = if mine and bagTile.X < chestTile.X then bagTile else chestTile
		bagLayout.CellSize = UDim2.fromOffset(tile.X, tile.Y)
		chestLayout.CellSize = UDim2.fromOffset(tile.X, tile.Y)
	end

	local function take(part: string, itemId: string)
		if owner then
			Remotes.ChestTake:FireServer(owner.UserId, part, itemId, AMOUNTS[amountIndex].amount)
		end
	end

	local function store(itemId: string)
		Remotes.ChestStore:FireServer(itemId, AMOUNTS[amountIndex].amount, storePart)
	end

	-- Crea, pone al día o quita la casilla "key" con "count" (0 la quita).
	local function setTile(key: string, itemId: string, count: number, order: number, part: string?)
		local tile = tiles[key]
		if count <= 0 then
			if tile then
				tile.button:Destroy()
				tiles[key] = nil
			end
			return
		end
		if not tile then
			local newOne = newTile(itemId, if part then PART_BADGE[part] else nil, if part then chestGrid else bagGrid)
			tiles[key] = newOne
			tile = newOne
			local where = if part == "private"
				then later("🔒 en tu cofre privado")
				elseif part == "shared" then later("🤝 en lo compartido")
				else later("🎒 en tu Bolsa")
			newOne.button.MouseEnter:Connect(function()
				describe(itemId, tonumber(newOne.count.Text) or 0, where)
			end)
			newOne.button.Activated:Connect(function()
				describe(itemId, tonumber(newOne.count.Text) or 0, where)
				if part then
					take(part, itemId)
				else
					store(itemId)
				end
			end)
		end
		local current = tile :: Tile
		current.button.LayoutOrder = order
		current.count.Text = tostring(count)
	end

	local function refresh()
		if not (panel.Visible and owner) then
			return
		end
		local state = Plot.of(owner)
		local level = owner:GetAttribute(Plot.CHEST_ATTRIBUTE)
		local slots = Plot.chestSlots(if typeof(level) == "number" then level else 0)
		local mine = isOwner()
		local before = 0
		for _ in tiles do
			before += 1
		end

		local ids = {}
		for itemId in Items do
			table.insert(ids, itemId)
		end
		sortByOrder(ids)
		for position, itemId in ids do
			local item = Items[itemId]
			setTile(
				`bag:{itemId}`,
				itemId,
				if mine and item.storable then Inventory.count(player, itemId) else 0,
				position
			)
			-- Lo privado primero; lo privado de otro no se enseña.
			local private = if mine then state.chest.private[itemId] or 0 else 0
			setTile(`private:{itemId}`, itemId, private, position, "private")
			setTile(`shared:{itemId}`, itemId, state.chest.shared[itemId] or 0, 1000 + position, "shared")
		end

		if mine then
			title.Text = T("📦 Tu cofre")
			chestTitle.Text =
				T("📦 Cofre · {used}/{slots} casillas", { used = Plot.slotsUsed(state.chest), slots = slots })
		else
			title.Text = T("📦 Cofre de {player}", { player = owner.DisplayName })
			chestTitle.Text = T("🤝 Lo compartido")
		end
		local after = 0
		for _ in tiles do
			after += 1
		end
		if after ~= before then
			layout()
		end
	end

	local function close()
		if not panel.Visible then
			return
		end
		panel.Visible = false
		owner, prompt = nil, nil
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		for _, tile in tiles do
			tile.button:Destroy()
		end
		table.clear(tiles)
		ContextActionService:UnbindAction(CLOSE_ACTION)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
			GuiService.SelectedObject = nil
		end
	end

	local function open(chestPrompt: ProximityPrompt)
		local userId = chestPrompt:GetAttribute("OwnerUserId")
		local chestOwner = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		if not chestOwner then
			return
		end
		close()
		owner, prompt = chestOwner, chestPrompt
		panel.Visible = true
		detail.Text = hint()
		refreshToggles()
		-- Cambia lo guardado (o el nivel del cofre) del dueño, o tu Bolsa.
		table.insert(
			connections,
			chestOwner.AttributeChanged:Connect(function(attribute: string)
				if attribute == "Plot" or attribute == Plot.CHEST_ATTRIBUTE then
					refresh()
				end
			end)
		)
		table.insert(
			connections,
			player.AttributeChanged:Connect(function(attribute: string)
				if attribute == LifeState.ATTRIBUTE and not LifeState.isAlive(player) then
					close()
				elseif chestOwner == player and string.sub(attribute, 1, 4) == "Inv_" then
					refresh()
				end
			end)
		)
		-- Roto o reconstruido (al mejorarlo): el aviso se apaga o desaparece, y la ventana se cierra.
		table.insert(
			connections,
			chestPrompt:GetPropertyChangedSignal("Enabled"):Connect(function()
				if not chestPrompt.Enabled then
					close()
				end
			end)
		)
		table.insert(
			connections,
			chestPrompt.AncestryChanged:Connect(function()
				if not chestPrompt:IsDescendantOf(game) then
					close()
				end
			end)
		)
		refresh()
		layout()
		-- B en mando cierra la ventana (por encima de la esquiva mientras está abierta).
		ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
	end

	for index, button in amountButtons do
		button.Activated:Connect(function()
			amountIndex = index
			refreshToggles()
		end)
	end
	for part, button in partButtons do
		button.Activated:Connect(function()
			storePart = part
			refreshToggles()
		end)
	end
	closeButton.Activated:Connect(close)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	bagGrid:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	chestGrid:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	Players.PlayerRemoving:Connect(function(leaving: Player)
		if leaving == owner then
			close()
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(triggered: ProximityPrompt)
		if triggered.Name == Plot.CHEST_PROMPT and LifeState.isAlive(player) then
			open(triggered)
		end
	end)

	-- Cerrar al alejarse del cofre.
	task.spawn(function()
		while gui.Parent do
			local anchor = if prompt then prompt.Parent else nil
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if panel.Visible and anchor and anchor:IsA("BasePart") then
				local far = not (root and root:IsA("BasePart"))
					or (anchor.Position - (root :: BasePart).Position).Magnitude
						> Config.Crafting.UseDistance + CLOSE_MARGIN
				if far then
					close()
				end
			end
			task.wait(0.3)
		end
	end)
end

return ChestController
