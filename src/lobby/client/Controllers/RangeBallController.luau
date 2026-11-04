--!strict
-- Panel del cañón de pelotas del campo de tiro (Fase 23d, RangeBallService). Se abre al activar el aviso del
-- cañón: cuatro filas (elasticidad, gravedad, tamaño y velocidad) con «−» y «+», el botón «Disparar pelota» y
-- «Cerrar». Va a la derecha, a media altura, para no tapar los botones de combate del teléfono (abajo) ni
-- el joystick (abajo a la izquierda). El servidor guarda los valores y los reenvía tras cada cambio. Se
-- cierra solo al alejarse del cañón. Colores del HUD del Lobby: madera oscura, dorado y naranja.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local T = Strings.t
local later = Strings.later

local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local BUTTON_COLOR = Color3.fromRGB(88, 70, 50)
local GOLD = Color3.fromRGB(255, 215, 90)
local ORANGE = Color3.fromRGB(255, 122, 26)
local WHITE = Color3.new(1, 1, 1)
local PANEL_WIDTH = 280
local ROW_HEIGHT = 36
local STEP_BUTTON = 36
-- Distancia al cañón a partir de la cual se cierra el panel.
local CLOSE_DISTANCE = Config.Range.Balls.PanelReach + 6

type Row = { key: string, title: string, format: (number) -> string, value: TextLabel }

local RangeBallController = {}

local panel: Frame
local rows: { Row } = {}
local latest: { [string]: number } = {}

local function render()
	for _, row in rows do
		local value = latest[row.key]
		if value then
			row.value.Text = row.format(value)
		end
	end
end

local function round1(value: number): string
	return string.format("%.1f", value)
end

local function addRow(key: string, title: string, format: (number) -> string, order: number)
	local frame = Instance.new("Frame")
	frame.Name = key
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	frame.LayoutOrder = order
	frame.Parent = panel

	local name = Widgets.label(T(title), frame)
	name.TextScaled = false
	name.TextSize = 15
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Size = UDim2.new(0, 90, 1, 0)

	local function stepButton(text: string, direction: number, x: number)
		local button = Instance.new("TextButton")
		button.Name = if direction < 0 then "Menos" else "Mas"
		button.Text = text
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = 24
		button.TextColor3 = WHITE
		button.BackgroundColor3 = BUTTON_COLOR
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(0, x, 0.5, 0)
		button.Size = UDim2.fromOffset(STEP_BUTTON, STEP_BUTTON)
		button.Parent = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		button.Activated:Connect(function()
			Remotes.RangeBalls:FireServer("Adjust", key, direction)
		end)
	end
	-- Fila: nombre | − | valor | +
	local plusRight = PANEL_WIDTH - 24
	stepButton("+", 1, plusRight)
	stepButton("−", -1, plusRight - STEP_BUTTON - 60)

	local value = Widgets.label("", frame)
	value.TextScaled = false
	value.TextSize = 17
	value.TextColor3 = GOLD
	value.AnchorPoint = Vector2.new(0.5, 0.5)
	value.Position = UDim2.new(0, plusRight - STEP_BUTTON - 30, 0.5, 0)
	value.Size = UDim2.fromOffset(56, ROW_HEIGHT)
	table.insert(rows, { key = key, title = title, format = format, value = value })
end

local function addButton(text: string, color: Color3, order: number, action: () -> ())
	local button = Instance.new("TextButton")
	button.Text = T(text)
	button.Font = Enum.Font.BuilderSansBold
	button.TextSize = 18
	button.TextColor3 = WHITE
	button.BackgroundColor3 = color
	button.Size = UDim2.new(1, 0, 0, 40)
	button.LayoutOrder = order
	button.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Activated:Connect(action)
end

local function cannonBase(): BasePart?
	local range = Workspace:FindFirstChild("CampoDeTiro")
	local cannon = range and range:FindFirstChild("Canon")
	local base = cannon and cannon:FindFirstChild("Base")
	return if base and base:IsA("BasePart") then base else nil
end

local function onBalls(kind: any, data: any)
	if typeof(data) ~= "table" then
		return
	end
	for key, value in data do
		if typeof(key) == "string" and typeof(value) == "number" then
			latest[key] = value
		end
	end
	if kind == "Open" then
		panel.Visible = true
	end
	render()
end

function RangeBallController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Widgets.screen("RangeBalls", playerGui)
	gui.DisplayOrder = 0

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = CARD_COLOR
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	local title = Widgets.label(T("Cañón de pelotas"), panel)
	title.TextScaled = false
	title.TextSize = 20
	title.TextColor3 = GOLD
	title.Size = UDim2.new(1, 0, 0, 26)
	title.LayoutOrder = 0

	addRow("Elasticity", later("Elasticidad"), function(value)
		return string.format("%.1f", value)
	end, 1)
	addRow("Gravity", later("Gravedad"), function(value)
		return string.format("%d", math.round(value))
	end, 2)
	addRow("Size", later("Tamaño"), round1, 3)
	addRow("Speed", later("Velocidad"), function(value)
		return string.format("%d", math.round(value))
	end, 4)
	addButton(later("Disparar pelota"), ORANGE, 5, function()
		Remotes.RangeBalls:FireServer("Fire")
	end)
	addButton(later("Cerrar"), BUTTON_COLOR, 6, function()
		panel.Visible = false
	end)

	Remotes.RangeBalls.OnClientEvent:Connect(onBalls)
	Strings.onChanged(function()
		-- Los textos fijos se tradujeron al crear el panel: se rehace con el idioma nuevo.
		for _, child in panel:GetChildren() do
			if child:IsA("TextButton") then
				child.Text = T(if child.LayoutOrder == 5 then "Disparar pelota" else "Cerrar")
			end
		end
		for _, row in rows do
			local label = (row.value.Parent :: Instance):FindFirstChildWhichIsA("TextLabel")
			if label and label ~= row.value then
				label.Text = T(row.title)
			end
		end
		render()
	end)

	-- Se cierra al alejarse del cañón.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < 0.5 or not panel.Visible then
			return
		end
		elapsed = 0
		local base = cannonBase()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			not (base and root and root:IsA("BasePart"))
			or (root.Position - base.Position).Magnitude > CLOSE_DISTANCE
		then
			panel.Visible = false
		end
	end)
end

return RangeBallController
