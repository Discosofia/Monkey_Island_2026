--!strict
-- Equipo de la arena para un rol (Data/ArenaGear): lo usan la ventana "Antes de la batalla" de Dunas
-- (ArenaLobbyController) y la pestaña Arena del Lobby. Arriba, tu Ámbar; debajo, las tres ranuras
-- (arma, armadura y amuleto), cada una con lo básico y dos variantes, y un botón para ponerla o
-- comprarla (Remotes.ArenaEquipGear / ArenaBuyGear; ServerShared/ArenaShop). Lo comprado y lo puesto
-- llegan en el atributo "Arena" del jugador (JSON, PlayerData). Dos formas:
--   - PC: una fila con las tres ranuras y lo que llevas en cada una; debajo, las tres opciones de la
--     ranura elegida, con qué ganas y qué pierdes y su botón.
--   - Pantalla baja ("compact", un teléfono): las tres ranuras en columnas con sus tres opciones a la
--     vista (9 botones). Al tocar una, la barra de abajo dice qué hace y da su botón: comprar pide dos
--     toques, así un toque suelto no gasta Ámbar.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaGear = require(ReplicatedStorage.Shared.Data.ArenaGear)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local INFO_COLOR = Color3.fromRGB(25, 20, 15)
local GOLD = Color3.fromRGB(242, 178, 36)
local AMBER_TEXT = Color3.fromRGB(255, 200, 80)
local SECONDARY_TEXT = Color3.fromRGB(210, 200, 185)
local SECONDARY_BUTTON = Color3.fromRGB(90, 90, 110)
local DARK_TEXT = Color3.fromRGB(40, 25, 5)
local SLOT_ICONS = { Weapon = "🗡️", Armor = "🛡️", Amulet = "📿" }
local BASIC_TEXT = "Básico"
-- PC: alto de las ranuras y de las filas de opciones.
local SLOT_HEIGHT = 50
local OPTION_HEIGHT = 58
local NAME_HEIGHT = 22
-- Teléfono: alto de cada opción de la cuadrícula (lo justo para el dedo), del título de cada columna
-- y de la barra de abajo.
local GRID_OPTION_HEIGHT = 44
local GRID_TITLE_HEIGHT = 18
local GRID_INFO_HEIGHT = 48
local HINT_TEXT = "Toca una opción para ver qué hace y ponerla o comprarla"

export type Picker = { frame: Frame, update: () -> () }

local ArenaGearPicker = {}

type ArenaData = { owned: { [string]: boolean }, loadout: { [string]: { [string]: string } } }

local function readArena(player: Player): ArenaData
	local raw = player:GetAttribute("Arena")
	local ok, decoded = pcall(function()
		return if typeof(raw) == "string" then HttpService:JSONDecode(raw) else nil
	end)
	local data = if ok and typeof(decoded) == "table" then decoded else {}
	return {
		owned = if typeof(data.owned) == "table" then data.owned else {},
		loadout = if typeof(data.loadout) == "table" then data.loadout else {},
	}
end

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function textLimit(parent: Instance, max: number)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = max
	limit.Parent = parent
end

local function equipped(arena: ArenaData, roleId: string, slot: string): string?
	local loadout = arena.loadout[roleId]
	local id = if typeof(loadout) == "table" then loadout[slot] else nil
	return if typeof(id) == "string" and ArenaGear.items[id] then id else nil
end

local function isSlot(value: string): boolean
	return table.find(ArenaGear.SLOTS, value :: ArenaGear.Slot) ~= nil
end

-- Lo que se ve de una opción: "🦴 Maza de hueso grueso" o "⬜ Básico".
local function optionName(gearId: string?): string
	local item = if gearId then ArenaGear.items[gearId] else nil
	return if item then `{item.icon} {item.name}` else `⬜ {BASIC_TEXT}`
end

-- Botón de una opción: "✔ Puesto", "Poner" o su precio (comprar).
local function actionButton(
	parent: Instance,
	roleId: string,
	slot: string,
	gearId: string?,
	arena: ArenaData,
	amber: number
): TextButton
	local item = if gearId then ArenaGear.items[gearId] else nil
	local owned = gearId == nil or arena.owned[gearId] == true
	local action = Instance.new("TextButton")
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.new(1, -6, 0.5, 0)
	action.Size = UDim2.fromOffset(132, 44)
	action.Font = Enum.Font.BuilderSansBold
	action.TextScaled = true
	action.Parent = parent
	corner(action, 12)
	textLimit(action, 18)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = action
	if equipped(arena, roleId, slot) == gearId then
		action.Text = "✔ Puesto"
		action.BackgroundColor3 = CARD_COLOR
		action.TextColor3 = SECONDARY_TEXT
		action.AutoButtonColor = false
	elseif owned then
		action.Text = "Poner"
		action.BackgroundColor3 = GOLD
		action.TextColor3 = DARK_TEXT
		action.Activated:Connect(function()
			Remotes.ArenaEquipGear:FireServer(roleId, slot, gearId or "")
		end)
	else
		local cost = if item then item.cost else 0
		local affordable = amber >= cost
		action.Text = `✨ {cost}`
		action.BackgroundColor3 = if affordable then GOLD else SECONDARY_BUTTON
		action.TextColor3 = if affordable then DARK_TEXT else Color3.new(1, 1, 1)
		action.Activated:Connect(function()
			if gearId then
				Remotes.ArenaBuyGear:FireServer(gearId)
			end
		end)
	end
	return action
end

-- Crea la pieza dentro de "parent" (en "order" de su UIListLayout). "roleOf": el rol cuyo equipo se
-- enseña (el que llevas en Dunas, el elegido en el Lobby). "compact": la cuadrícula del teléfono (ver
-- arriba). "startSlot" y "onSlot": para quien la vuelve a crear a menudo (el menú del Lobby se
-- redibuja al cambiar algo), lo elegido con lo que empieza y un aviso cada vez que cambia: en PC, la
-- ranura abierta ("Weapon"); en la cuadrícula, la opción tocada ("Weapon:BoneMaul", o "Weapon:" para
-- lo básico). "hideHeader": sin la línea de arriba (rol y Ámbar), donde ya se ven en otro sitio (el
-- menú del Lobby). Llama a "update" para refrescarla.
function ArenaGearPicker.new(
	parent: Instance,
	order: number,
	roleOf: () -> string,
	compact: boolean?,
	startSlot: string?,
	onSlot: ((slot: string?) -> ())?,
	hideHeader: boolean?
): Picker
	local player = Players.LocalPlayer
	local frame = Instance.new("Frame")
	frame.Name = "ArenaGear"
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = parent
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, if compact then 4 else 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local header = Widgets.label("", frame)
	header.Name = "Header"
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, 22)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = AMBER_TEXT
	header.Visible = not hideHeader

	-- Lo que se rehace al cambiar algo (las opciones de PC o la cuadrícula del teléfono).
	local body = Instance.new("Frame")
	body.Name = if compact then "Grid" else "Options"
	body.LayoutOrder = 3
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Parent = frame

	-- Lo elegido: en PC la ranura abierta (siempre hay una); en el teléfono, la opción tocada.
	local chosen: string? = startSlot
	if compact then
		chosen = if chosen and string.find(chosen, ":", 1, true) then chosen else nil
	elseif not (chosen and isSlot(chosen)) then
		chosen = ArenaGear.SLOTS[1]
	end
	local shownKey = ""
	local update: () -> ()

	local function choose(value: string?)
		chosen = value
		shownKey = ""
		if onSlot then
			onSlot(value)
		end
		update()
	end

	local function clear(container: Instance)
		for _, child in container:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	-- PC: una fila de opción con nombre y descripción a la izquierda y el botón a la derecha.
	local function optionRow(
		index: number,
		roleId: string,
		slot: string,
		gearId: string?,
		arena: ArenaData,
		amber: number
	)
		local item = if gearId then ArenaGear.items[gearId] else nil
		local rowFrame = Instance.new("Frame")
		rowFrame.LayoutOrder = index
		rowFrame.Size = UDim2.new(1, -8, 0, OPTION_HEIGHT)
		rowFrame.BackgroundColor3 = INFO_COLOR
		rowFrame.BackgroundTransparency = 0.25
		rowFrame.Parent = body
		corner(rowFrame, 8)
		local name = Widgets.label(optionName(gearId), rowFrame)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position = UDim2.fromOffset(8, 4)
		name.Size = UDim2.new(1, -150, 0, NAME_HEIGHT)
		textLimit(name, 20)
		local description = Widgets.label(if item then item.description else "Sin cambios", rowFrame)
		description.Font = Enum.Font.BuilderSans
		description.TextXAlignment = Enum.TextXAlignment.Left
		description.TextWrapped = true
		description.TextColor3 = SECONDARY_TEXT
		description.Position = UDim2.fromOffset(8, 4 + NAME_HEIGHT)
		description.Size = UDim2.new(1, -150, 0, OPTION_HEIGHT - 8 - NAME_HEIGHT)
		textLimit(description, 14)
		actionButton(rowFrame, roleId, slot, gearId, arena, amber)
	end

	-- PC: fila de ranuras (se crea una vez) y opciones de la abierta.
	local slotButtons: { [string]: { button: TextButton, stroke: UIStroke } } = {}
	if not compact then
		local slotRow = Instance.new("Frame")
		slotRow.LayoutOrder = 2
		slotRow.BackgroundTransparency = 1
		slotRow.Size = UDim2.new(1, 0, 0, SLOT_HEIGHT)
		slotRow.Parent = frame
		local slotLayout = Instance.new("UIListLayout")
		slotLayout.FillDirection = Enum.FillDirection.Horizontal
		slotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		slotLayout.Padding = UDim.new(0, 6)
		slotLayout.SortOrder = Enum.SortOrder.LayoutOrder
		slotLayout.Parent = slotRow
		local optionsLayout = Instance.new("UIListLayout")
		optionsLayout.Padding = UDim.new(0, 4)
		optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		optionsLayout.Parent = body
		for index, slot in ArenaGear.SLOTS do
			local button = Instance.new("TextButton")
			button.LayoutOrder = index
			button.Size = UDim2.new(1 / 3, -6, 1, 0)
			button.BackgroundColor3 = CARD_COLOR
			button.TextColor3 = Color3.new(1, 1, 1)
			button.TextStrokeTransparency = 0.5
			button.Font = Enum.Font.BuilderSansBold
			button.TextScaled = true
			button.TextWrapped = true
			button.Parent = slotRow
			corner(button, 8)
			textLimit(button, 16)
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 4)
			padding.PaddingBottom = UDim.new(0, 4)
			padding.PaddingLeft = UDim.new(0, 6)
			padding.PaddingRight = UDim.new(0, 6)
			padding.Parent = button
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = GOLD
			stroke.Thickness = 3
			stroke.Enabled = false
			stroke.Parent = button
			button.Activated:Connect(function()
				choose(slot)
			end)
			slotButtons[slot] = { button = button, stroke = stroke }
		end
	else
		local columns = Instance.new("UIListLayout")
		columns.FillDirection = Enum.FillDirection.Horizontal
		columns.HorizontalAlignment = Enum.HorizontalAlignment.Center
		columns.Padding = UDim.new(0, 4)
		columns.SortOrder = Enum.SortOrder.LayoutOrder
		columns.Parent = body
	end

	-- Teléfono: una opción de la cuadrícula. Borde dorado = la que llevas; blanco = la tocada.
	local function gridOption(
		column: Frame,
		index: number,
		slot: string,
		gearId: string?,
		arena: ArenaData,
		current: string?
	)
		local key = `{slot}:{gearId or ""}`
		local owned = gearId == nil or arena.owned[gearId] == true
		local item = if gearId then ArenaGear.items[gearId] else nil
		local button = Instance.new("TextButton")
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0, GRID_OPTION_HEIGHT)
		button.BackgroundColor3 = CARD_COLOR
		button.Text = ""
		button.Parent = column
		corner(button, 8)
		local name = Widgets.label(optionName(gearId), button)
		name.Position = UDim2.fromOffset(4, 2)
		name.Size = UDim2.new(1, -8, 0.56, -2)
		name.TextWrapped = true
		textLimit(name, 14)
		local state = Widgets.label(
			if current == gearId then "✔ Puesto" elseif owned then "Tuyo" else `✨ {if item then item.cost else 0}`,
			button
		)
		state.Font = Enum.Font.BuilderSans
		state.Position = UDim2.new(0, 4, 0.56, 0)
		state.Size = UDim2.new(1, -8, 0.44, -2)
		state.TextColor3 = if current == gearId then GOLD elseif owned then SECONDARY_TEXT else AMBER_TEXT
		textLimit(state, 13)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 2
		stroke.Color = if chosen == key then Color3.new(1, 1, 1) else GOLD
		stroke.Enabled = chosen == key or current == gearId
		stroke.Parent = button
		button.Activated:Connect(function()
			choose(key)
		end)
	end

	-- Teléfono: las tres columnas y la barra de la opción tocada.
	local function rebuildGrid(roleId: string, arena: ArenaData, amber: number)
		clear(body)
		local slotOfChoice, gearOfChoice = nil, nil
		if chosen then
			local slot, gearId = string.match(chosen, "^(%a+):(%w*)$")
			local valid = slot ~= nil
				and isSlot(slot)
				and (gearId == "" or table.find(ArenaGear.options(roleId, slot :: ArenaGear.Slot), gearId) ~= nil)
			if valid then
				slotOfChoice, gearOfChoice = slot, if gearId == "" then nil else gearId
			end
		end
		for index, slot in ArenaGear.SLOTS do
			local column = Instance.new("Frame")
			column.LayoutOrder = index
			column.BackgroundTransparency = 1
			column.Size = UDim2.new(1 / 3, -4, 0, 0)
			column.AutomaticSize = Enum.AutomaticSize.Y
			column.Parent = body
			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0, 4)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = column
			local title = Widgets.label(`{SLOT_ICONS[slot]} {ArenaGear.SLOT_NAMES[slot]}`, column)
			title.LayoutOrder = 0
			title.Size = UDim2.new(1, 0, 0, GRID_TITLE_HEIGHT)
			title.TextColor3 = SECONDARY_TEXT
			textLimit(title, 14)
			local current = equipped(arena, roleId, slot)
			gridOption(column, 1, slot, nil, arena, current)
			for optionIndex, gearId in ArenaGear.options(roleId, slot :: ArenaGear.Slot) do
				gridOption(column, optionIndex + 1, slot, gearId, arena, current)
			end
		end
		-- La barra va debajo de las columnas (fuera de su fila horizontal): en el marco de la pieza.
		local info = frame:FindFirstChild("Info")
		if info then
			info:Destroy()
		end
		local bar = Instance.new("Frame")
		bar.Name = "Info"
		bar.LayoutOrder = 4
		bar.Size = UDim2.new(1, 0, 0, GRID_INFO_HEIGHT)
		bar.BackgroundColor3 = INFO_COLOR
		bar.BackgroundTransparency = 0.25
		bar.Parent = frame
		corner(bar, 8)
		local text = Widgets.label(HINT_TEXT, bar)
		text.Font = Enum.Font.BuilderSans
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextWrapped = true
		text.TextColor3 = SECONDARY_TEXT
		text.Position = UDim2.fromOffset(8, 2)
		text.Size = UDim2.new(1, -8, 1, -4)
		textLimit(text, 14)
		if slotOfChoice then
			local item = if gearOfChoice then ArenaGear.items[gearOfChoice] else nil
			text.Text = `{optionName(gearOfChoice)}: {if item then item.description else "sin cambios"}`
			text.Size = UDim2.new(1, -150, 1, -4)
			actionButton(bar, roleId, slotOfChoice, gearOfChoice, arena, amber)
		end
	end

	local function rebuildOptions(roleId: string, arena: ArenaData, amber: number)
		clear(body)
		local slot = chosen
		if not slot then
			return
		end
		optionRow(1, roleId, slot, nil, arena, amber)
		for index, gearId in ArenaGear.options(roleId, slot :: ArenaGear.Slot) do
			optionRow(index + 1, roleId, slot, gearId, arena, amber)
		end
	end

	function update()
		local roleId = roleOf()
		local role = Roles[roleId]
		if not role then
			return
		end
		local arena = readArena(player)
		local amberValue = player:GetAttribute("Amber")
		local amber = if typeof(amberValue) == "number" then amberValue else 0
		header.Text = `{role.icon} Equipo de {role.name} en la arena · ✨ {amber} de Ámbar`
		for slot, item in slotButtons do
			local id = equipped(arena, roleId, slot)
			local gear = if id then ArenaGear.items[id] else nil
			item.button.Text = `{SLOT_ICONS[slot]} {ArenaGear.SLOT_NAMES[slot]}\n{if gear
				then `{gear.icon} {gear.name}`
				else BASIC_TEXT}`
			item.stroke.Enabled = chosen == slot
		end
		-- Se rehace solo si algo cambia (no en cada vuelta: los botones se recrearían).
		local key = `{roleId}|{chosen or ""}|{amber}|{player:GetAttribute("Arena") or ""}`
		if key ~= shownKey then
			shownKey = key
			if compact then
				rebuildGrid(roleId, arena, amber)
			else
				rebuildOptions(roleId, arena, amber)
			end
		end
	end

	return { frame = frame, update = update }
end

return ArenaGearPicker
