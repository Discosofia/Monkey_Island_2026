--!strict
-- Tarjetas de los cuatro roles para la arena: icono y nombre, y debajo su ventaja en combate ("edge"
-- en Data/Roles). Las usan la ventana "Antes de la batalla" de Dunas (ArenaLobbyController: el rol que
-- llevas a la partida) y la ventana de la arena del Lobby (LobbyUIController: de qué rol se ve el
-- equipo). La elegida lleva el borde dorado. En una fila de cuatro o, en una pantalla baja
-- ("compact", un teléfono), en 2 × 2.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local DISABLED_COLOR = Color3.fromRGB(90, 90, 90)
local GOLD = Color3.fromRGB(242, 178, 36)
local SECONDARY_TEXT = Color3.fromRGB(210, 200, 185)
-- Tope del texto: con TextScaled, "Mago" saldría enorme y "Guerrero" pequeño; así salen iguales.
local NAME_TEXT_MAX = 20
local EDGE_TEXT_MAX = 13
-- La tarjeta es más alta que una fila normal: debajo del nombre va su ventaja.
local EDGE_EXTRA = 24

export type Cards = {
	frame: Frame,
	-- "selected": el rol marcado. "allowed": si se puede elegir cada uno (los demás salen apagados);
	-- sin él, todos.
	update: (selected: string?, allowed: ((roleId: string) -> boolean)?) -> (),
}

type Card = { button: TextButton, stroke: UIStroke, name: TextLabel, edge: TextLabel }

local ArenaRoleCards = {}

local function rolesInOrder(): { string }
	local ids = {}
	for roleId in Roles do
		table.insert(ids, roleId)
	end
	table.sort(ids, function(a, b)
		return Roles[a].order < Roles[b].order
	end)
	return ids
end

local function textLimit(parent: Instance, max: number)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = max
	limit.Parent = parent
end

-- Crea las tarjetas dentro de "parent" (en "order" de su UIListLayout). "rowHeight": el alto de una
-- fila normal de la ventana (la tarjeta le suma EDGE_EXTRA). "onPick": al pulsar una.
function ArenaRoleCards.new(
	parent: Instance,
	order: number,
	rowHeight: number,
	compact: boolean,
	onPick: (roleId: string) -> ()
): Cards
	local cardHeight = rowHeight + EDGE_EXTRA
	local frame = Instance.new("Frame")
	frame.Name = "ArenaRoles"
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, if compact then cardHeight * 2 + 6 else cardHeight)
	frame.Parent = parent
	if compact then
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0.5, -3, 0, cardHeight)
		grid.CellPadding = UDim2.fromOffset(6, 6)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = frame
	else
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = frame
	end

	local cards: { [string]: Card } = {}
	for index, roleId in rolesInOrder() do
		local role = Roles[roleId]
		local button = Instance.new("TextButton")
		button.LayoutOrder = index
		button.Size = UDim2.new(0.25, -6, 1, 0)
		button.BackgroundColor3 = CARD_COLOR
		button.Text = ""
		button.AutoButtonColor = true
		button.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 6)
		padding.PaddingBottom = UDim.new(0, 6)
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = GOLD
		stroke.Thickness = 3
		stroke.Enabled = false
		stroke.Parent = button

		local name = Widgets.label(`{role.icon} {role.name}`, button)
		name.Size = UDim2.fromScale(1, 0.45)
		textLimit(name, NAME_TEXT_MAX)
		local edge = Widgets.label(role.edge, button)
		edge.Font = Enum.Font.BuilderSans
		edge.TextColor3 = SECONDARY_TEXT
		edge.Position = UDim2.fromScale(0, 0.45)
		edge.Size = UDim2.fromScale(1, 0.55)
		textLimit(edge, EDGE_TEXT_MAX)

		button.Activated:Connect(function()
			onPick(roleId)
		end)
		cards[roleId] = { button = button, stroke = stroke, name = name, edge = edge }
	end

	local function update(selected: string?, allowed: ((roleId: string) -> boolean)?)
		for roleId, card in cards do
			local canPick = allowed == nil or allowed(roleId)
			card.stroke.Enabled = selected == roleId
			card.button.BackgroundColor3 = if canPick then CARD_COLOR else DISABLED_COLOR
			card.name.TextTransparency = if canPick then 0 else 0.5
			card.edge.TextTransparency = if canPick then 0 else 0.5
		end
	end

	return { frame = frame, update = update }
end

return ArenaRoleCards
