--!strict
-- Resultados de una partida de la arena (Remotes.ArenaResults, de ArenaRewardService), con el mismo
-- aspecto que los de la Isla (ResultsController): victoria, derrota o empate, el marcador, una tabla
-- con las capturas, bajas y caídas de cada jugador y el Ámbar ganado (con el tope diario).
-- Abajo, dos botones: "🔁 Revancha" (cierra la ventana: la siguiente partida empieza sola en este
-- servidor con quienes se queden) y "🏝️ Volver al Lobby". Se cierra sola al acabar los resultados.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local PANEL_COLOR = Color3.fromRGB(30, 24, 18)
local SHADE_COLOR = Color3.fromRGB(10, 8, 6)
local ROW_COLOR = Color3.fromRGB(45, 38, 30)
local PLAIN = Color3.fromRGB(230, 220, 200)
local GOLD_TEXT = Color3.fromRGB(255, 210, 120)
local AMBER_TEXT = Color3.fromRGB(255, 200, 80)
local LOSS_TEXT = Color3.fromRGB(240, 110, 90)
local SECONDARY_BUTTON = Color3.fromRGB(90, 90, 110)
local ROW_HEIGHT = 30

local ArenaResultsController = {}

local current: ScreenGui? = nil

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function line(parent: Instance, text: string, top: number, height: number, color: Color3): TextLabel
	local label = Widgets.label(text, parent)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, top)
	label.Size = UDim2.new(1, -24, 0, height)
	label.TextColor3 = color
	return label
end

local function titleOf(summary: { [string]: any }): (string, Color3)
	if summary.test then
		return "🧪 Partida de prueba", PLAIN
	elseif summary.result == "Win" then
		return "🏆 ¡Victoria!", GOLD_TEXT
	elseif summary.result == "Loss" then
		return "💀 Derrota", LOSS_TEXT
	end
	return "🤝 Empate", PLAIN
end

local function amberText(summary: { [string]: any }): string
	if summary.test then
		return "No cuenta para el Ámbar ni el ranking"
	end
	local text = `✨ +{summary.amber} de Ámbar`
	local lost = (summary.earned or 0) - (summary.amber or 0)
	if lost > 0 then
		text ..= ` (tope diario {summary.today}/{summary.dailyCap}: {lost} sin cobrar)`
	end
	return text
end

-- Fila de la tabla: icono del equipo, nombre y sus números.
local function playerRow(parent: Instance, order: number, row: { [string]: any }, mine: boolean)
	local team = Config.Arena.Teams[row.team]
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = if team then team.color:Lerp(ROW_COLOR, 0.65) else ROW_COLOR
	frame.Parent = parent
	corner(frame, 8)
	if mine then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(242, 178, 36)
		stroke.Thickness = 2
		stroke.Parent = frame
	end
	local name = Widgets.label(`{if team then team.icon else ""} {row.name}`, frame)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Position = UDim2.fromOffset(8, 4)
	name.Size = UDim2.new(0.5, -8, 1, -8)
	local numbers = Widgets.label(`🚩 {row.captures}   ⚔️ {row.kills}   💀 {row.deaths}`, frame)
	numbers.TextXAlignment = Enum.TextXAlignment.Right
	numbers.AnchorPoint = Vector2.new(1, 0)
	numbers.Position = UDim2.new(1, -8, 0, 4)
	numbers.Size = UDim2.new(0.5, -8, 1, -8)
end

local function close()
	if current then
		current:Destroy()
		current = nil
	end
end

local function show(summary: { [string]: any })
	close()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("ArenaResults", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = true
	current = gui

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = SHADE_COLOR
	shade.BackgroundTransparency = 0.25
	shade.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.6, 0.86)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.Parent = gui
	corner(panel, 16)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(320, 300)
	sizeLimit.MaxSize = Vector2.new(560, 480)
	sizeLimit.Parent = panel

	local titleText, titleColor = titleOf(summary)
	local title = line(panel, titleText, 12, 44, titleColor)
	local scale = Instance.new("UIScale")
	scale.Scale = 1.35
	scale.Parent = title
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	local scores = summary.scores or {}
	local jaguar, quetzal = Config.Arena.Teams.Jaguar, Config.Arena.Teams.Quetzal
	line(
		panel,
		`{jaguar.icon} {jaguar.name} {scores.Jaguar or 0} · {scores.Quetzal or 0} {quetzal.name} {quetzal.icon}`,
		60,
		28,
		Color3.new(1, 1, 1)
	)
	line(panel, amberText(summary), 92, 26, if summary.test then PLAIN else AMBER_TEXT)

	-- Tabla de jugadores (con desplazamiento si son muchos).
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.AnchorPoint = Vector2.new(0.5, 0)
	list.Position = UDim2.new(0.5, 0, 0, 126)
	list.Size = UDim2.new(1, -24, 1, -126 - 112)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for index, row in summary.players or {} do
		playerRow(list, index, row, row.name == player.DisplayName)
	end

	local countdown = Widgets.label("", panel)
	countdown.AnchorPoint = Vector2.new(0.5, 1)
	countdown.Position = UDim2.new(0.5, 0, 1, -70)
	countdown.Size = UDim2.new(1, -24, 0, 24)
	countdown.TextColor3 = PLAIN

	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0.5, 1)
	buttons.Position = UDim2.new(0.5, 0, 1, -12)
	buttons.Size = UDim2.new(1, -24, 0, 52)
	buttons.Parent = panel
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.Padding = UDim.new(0, 10)
	row.Parent = buttons
	local rematch = Widgets.button("🔁 Revancha", buttons)
	rematch.Size = UDim2.fromScale(0.48, 1)
	local leave = Widgets.button("🏝️ Volver al Lobby", buttons)
	leave.Size = UDim2.fromScale(0.48, 1)
	leave.BackgroundColor3 = SECONDARY_BUTTON
	leave.TextColor3 = Color3.new(1, 1, 1)

	rematch.Activated:Connect(close)
	leave.Activated:Connect(function()
		leave.Text = "⏳ Viajando…"
		Remotes.ArenaLeave:FireServer()
	end)

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if current ~= gui then
			connection:Disconnect()
			return
		end
		if Arena.phase() ~= "Results" then
			connection:Disconnect()
			close()
			return
		end
		countdown.Text = `La revancha empieza en {math.ceil(Arena.secondsLeft())} s con quienes se queden`
	end)
end

function ArenaResultsController:Start()
	Remotes.ArenaResults.OnClientEvent:Connect(function(summary: any)
		if typeof(summary) == "table" then
			show(summary)
		end
	end)
end

return ArenaResultsController
