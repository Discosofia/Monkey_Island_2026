--!strict
-- Equipo de la arena para un rol (Data/ArenaGear): lo usan la ventana "Antes de la batalla" de Dunas
-- (ArenaLobbyController) y la pestaña Arena del Lobby. Arriba, tu Ámbar; debajo, las tres ranuras
-- (arma, armadura y amuleto) con lo que llevas en cada una. Al pulsar una se despliegan sus tres
-- opciones (lo básico y dos variantes) con qué ganas y qué pierdes, y un botón para ponerla o
-- comprarla (Remotes.ArenaEquipGear / ArenaBuyGear; ServerShared/ArenaShop). Lo comprado y lo puesto
-- llegan en el atributo "Arena" del jugador (JSON, PlayerData).

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
local SLOT_ICONS = { Weapon = "🗡️", Armor = "🛡️", Amulet = "📿" }
local BASIC_TEXT = "Básico"
-- Alto de las ranuras y de las filas de opciones; en pantallas bajas ("compact"), lo justo para el dedo.
local SLOT_HEIGHT = 50
local OPTION_HEIGHT = 58
local COMPACT_SLOT_HEIGHT = 44
-- En el teléfono las opciones se ven solas (la ventana oculta lo demás): más altas para que la
-- descripción quepa en dos líneas legibles.
local COMPACT_OPTION_HEIGHT = 62
local NAME_HEIGHT = 22

-- "isOpen": si hay una ranura desplegada (en un teléfono, la ventana oculta lo demás mientras tanto).
export type Picker = { frame: Frame, update: () -> (), isOpen: () -> boolean }

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

-- Crea la pieza dentro de "parent" (en "order" de su UIListLayout). "roleOf": el rol cuyo equipo se
-- enseña (el que llevas en Dunas, el elegido en el Lobby). "compact": filas más bajas (pantallas de
-- poco alto, como un teléfono apaisado). Sin "compact" (PC) empieza desplegada en el arma y siempre
-- hay una ranura abierta (pulsar otra cambia a esa); en compacto empieza cerrada y pulsar la abierta la
-- cierra. Llama a "update" para refrescarla.
function ArenaGearPicker.new(parent: Instance, order: number, roleOf: () -> string, compact: boolean?): Picker
	local player = Players.LocalPlayer
	local slotHeight = if compact then COMPACT_SLOT_HEIGHT else SLOT_HEIGHT
	local optionHeight = if compact then COMPACT_OPTION_HEIGHT else OPTION_HEIGHT
	local nameHeight = NAME_HEIGHT
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

	-- Ranuras.
	local slotRow = Instance.new("Frame")
	slotRow.LayoutOrder = 2
	slotRow.BackgroundTransparency = 1
	slotRow.Size = UDim2.new(1, 0, 0, slotHeight)
	slotRow.Parent = frame
	local slotLayout = Instance.new("UIListLayout")
	slotLayout.FillDirection = Enum.FillDirection.Horizontal
	slotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	slotLayout.Padding = UDim.new(0, 6)
	slotLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slotLayout.Parent = slotRow
	local slotButtons: { [string]: { button: TextButton, stroke: UIStroke } } = {}

	-- Opciones de la ranura abierta.
	local options = Instance.new("Frame")
	options.Name = "Options"
	options.LayoutOrder = 3
	options.BackgroundTransparency = 1
	options.Size = UDim2.fromScale(1, 0)
	options.AutomaticSize = Enum.AutomaticSize.Y
	options.Visible = false
	options.Parent = frame
	local optionsLayout = Instance.new("UIListLayout")
	optionsLayout.Padding = UDim.new(0, 4)
	optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	optionsLayout.Parent = options

	local openSlot: string? = if compact then nil else ArenaGear.SLOTS[1]
	local shownKey = ""

	local function equipped(arena: ArenaData, roleId: string, slot: string): string?
		local loadout = arena.loadout[roleId]
		local id = if typeof(loadout) == "table" then loadout[slot] else nil
		return if typeof(id) == "string" and ArenaGear.items[id] then id else nil
	end

	-- Una fila de opción: nombre y descripción a la izquierda, botón a la derecha.
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
		rowFrame.Size = UDim2.new(1, -8, 0, optionHeight)
		rowFrame.BackgroundColor3 = INFO_COLOR
		rowFrame.BackgroundTransparency = 0.25
		rowFrame.Parent = options
		corner(rowFrame, 8)
		local name = Widgets.label(if item then `{item.icon} {item.name}` else `⬜ {BASIC_TEXT}`, rowFrame)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position = UDim2.fromOffset(8, 4)
		name.Size = UDim2.new(1, -150, 0, nameHeight)
		textLimit(name, 20)
		local description = Widgets.label(if item then item.description else "Sin cambios", rowFrame)
		description.Font = Enum.Font.BuilderSans
		description.TextXAlignment = Enum.TextXAlignment.Left
		description.TextWrapped = true
		description.TextColor3 = SECONDARY_TEXT
		description.Position = UDim2.fromOffset(8, 4 + nameHeight)
		description.Size = UDim2.new(1, -150, 0, optionHeight - 8 - nameHeight)
		textLimit(description, 14)

		local current = equipped(arena, roleId, slot)
		local owned = gearId == nil or arena.owned[gearId] == true
		local action = Instance.new("TextButton")
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Position = UDim2.new(1, -6, 0.5, 0)
		action.Size = UDim2.fromOffset(132, 44)
		action.Font = Enum.Font.BuilderSansBold
		action.TextScaled = true
		action.Parent = rowFrame
		corner(action, 12)
		textLimit(action, 18)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.Parent = action
		if current == gearId then
			action.Text = "✔ Puesto"
			action.BackgroundColor3 = CARD_COLOR
			action.TextColor3 = SECONDARY_TEXT
			action.AutoButtonColor = false
		elseif owned then
			action.Text = "Poner"
			action.BackgroundColor3 = GOLD
			action.TextColor3 = Color3.fromRGB(40, 25, 5)
			action.Activated:Connect(function()
				Remotes.ArenaEquipGear:FireServer(roleId, slot, gearId or "")
			end)
		else
			local cost = if item then item.cost else 0
			local affordable = amber >= cost
			action.Text = `✨ {cost}`
			action.BackgroundColor3 = if affordable then GOLD else SECONDARY_BUTTON
			action.TextColor3 = if affordable then Color3.fromRGB(40, 25, 5) else Color3.new(1, 1, 1)
			action.Activated:Connect(function()
				if gearId then
					Remotes.ArenaBuyGear:FireServer(gearId)
				end
			end)
		end
	end

	local function rebuildOptions(roleId: string, arena: ArenaData, amber: number)
		for _, child in options:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local slot = openSlot
		options.Visible = slot ~= nil
		if not slot then
			return
		end
		optionRow(1, roleId, slot, nil, arena, amber)
		for index, gearId in ArenaGear.options(roleId, slot :: ArenaGear.Slot) do
			optionRow(index + 1, roleId, slot, gearId, arena, amber)
		end
	end

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
			openSlot = if openSlot == slot and compact then nil else slot
			shownKey = ""
		end)
		slotButtons[slot] = { button = button, stroke = stroke }
	end

	local function update()
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
			item.stroke.Enabled = openSlot == slot
		end
		-- Las opciones solo se rehacen si algo cambia (no en cada vuelta: los botones se recrearían).
		local key = `{roleId}|{openSlot or ""}|{amber}|{player:GetAttribute("Arena") or ""}`
		if key ~= shownKey then
			shownKey = key
			rebuildOptions(roleId, arena, amber)
		end
	end

	return {
		frame = frame,
		update = update,
		isOpen = function(): boolean
			return openSlot ~= nil
		end,
	}
end

return ArenaGearPicker
