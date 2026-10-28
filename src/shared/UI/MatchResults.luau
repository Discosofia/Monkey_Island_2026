--!strict
-- Resultados de una partida por equipos (Remotes.ArenaResults): la arena de Dunas (ArenaRewardService)
-- y el duelo del Laboratorio (LabMatchService), con el mismo aspecto que los de la Isla
-- (ResultsController): victoria, derrota o empate, el marcador, una tabla con los números de cada
-- jugador, el Ámbar ganado (con el tope diario) y la XP del pase de temporada. Cada fila lleva el marco
-- del jugador (Shared/UI/PlayerFrames). Los equipos, sus iconos y sus colores son los del place
-- (Shared/Arena.TEAMS).
-- Lo que solo tiene un place sale solo si llega en el resumen: los altares de la pirámide de Dunas
-- ("altars"), la columna de capturas (🚩, "captures" en cada fila) y la línea del Ámbar ("amber"; en
-- el Laboratorio aún no hay recompensas).
-- Abajo, dos botones: "🔁 Revancha" (cierra la ventana: la siguiente partida empieza sola en este
-- servidor con quienes se queden) y "🏝️ Volver al Lobby". Se cierra sola al acabar los resultados.
-- La pone en marcha el controlador de cada place (MatchResults.start); "onToggle" le avisa al abrirse
-- y al cerrarse (el Laboratorio suelta ahí el ratón de la primera persona).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Arena = require(ReplicatedStorage.Shared.Arena)
local PlayerFrames = require(ReplicatedStorage.Shared.UI.PlayerFrames)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local T = Strings.t

local PANEL_COLOR = Color3.fromRGB(30, 24, 18)
local SHADE_COLOR = Color3.fromRGB(10, 8, 6)
local ROW_COLOR = Color3.fromRGB(45, 38, 30)
local PLAIN = Color3.fromRGB(230, 220, 200)
local GOLD_TEXT = Color3.fromRGB(255, 210, 120)
local AMBER_TEXT = Color3.fromRGB(255, 200, 80)
local LOSS_TEXT = Color3.fromRGB(240, 110, 90)
local SECONDARY_BUTTON = Color3.fromRGB(90, 90, 110)
local ROW_HEIGHT = 30

export type Options = { onToggle: ((open: boolean) -> ())? }

local MatchResults = {}

local current: ScreenGui? = nil
local onToggle: ((open: boolean) -> ())? = nil

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
		return T("🧪 Partida de prueba"), PLAIN
	elseif summary.result == "Win" then
		return T("🏆 ¡Victoria!"), GOLD_TEXT
	elseif summary.result == "Loss" then
		return T("💀 Derrota"), LOSS_TEXT
	end
	return T("🤝 Empate"), PLAIN
end

-- Sin Ámbar en el resumen (ni partida de prueba), nil: no hay línea.
local function amberText(summary: { [string]: any }): string?
	if summary.test then
		return T("No cuenta para el Ámbar ni el ranking")
	elseif summary.amber == nil then
		return nil
	end
	local lost = (summary.earned or 0) - (summary.amber or 0)
	if lost > 0 then
		return T(
			"✨ +{amber} de Ámbar (tope diario {today}/{cap}: {lost} sin cobrar)",
			{ amber = summary.amber, today = summary.today, cap = summary.dailyCap, lost = lost }
		)
	end
	return T("✨ +{amber} de Ámbar", { amber = summary.amber })
end

-- Fila de la tabla: icono del equipo, nombre y sus números.
local function playerRow(parent: Instance, order: number, row: { [string]: any }, mine: boolean)
	local team = Arena.TEAMS[row.team]
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = if team then team.color:Lerp(ROW_COLOR, 0.65) else ROW_COLOR
	frame.Parent = parent
	corner(frame, 8)
	-- Su marco; sin marco, la tuya va con el borde dorado de siempre.
	if typeof(row.frame) == "string" and PlayerFrames.has(row.frame) then
		PlayerFrames.apply(frame, row.frame)
	elseif mine then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(242, 178, 36)
		stroke.Thickness = 2
		stroke.Parent = frame
	end
	local name = Widgets.label(`{if team then team.icon else ""} {row.name}`, frame)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Position = UDim2.fromOffset(8, 4)
	name.Size = UDim2.new(0.5, -8, 1, -8)
	local captures = if row.captures ~= nil then `🚩 {row.captures}   ` else ""
	local numbers = Widgets.label(`{captures}⚔️ {row.kills}   💀 {row.deaths}`, frame)
	numbers.TextXAlignment = Enum.TextXAlignment.Right
	numbers.AnchorPoint = Vector2.new(1, 0)
	numbers.Position = UDim2.new(1, -8, 0, 4)
	numbers.Size = UDim2.new(0.5, -8, 1, -8)
end

local function close()
	if current then
		current:Destroy()
		current = nil
		if onToggle then
			onToggle(false)
		end
	end
end

local function show(summary: { [string]: any })
	close()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("ArenaResults", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = true
	current = gui
	if onToggle then
		onToggle(true)
	end

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
	local first, second = Arena.TEAM_IDS[1], Arena.TEAM_IDS[2]
	local left, right = Arena.TEAMS[first], Arena.TEAMS[second]
	line(
		panel,
		`{left.icon} {T(left.name)} {scores[first] or 0} · {scores[second] or 0} {T(right.name)} {right.icon}`,
		60,
		28,
		Color3.new(1, 1, 1)
	)
	-- Debajo del marcador, una línea por cada cosa que traiga el resumen; la tabla empieza después.
	local top = 88
	-- Altares de la pirámide que ha tomado cada equipo (Dunas, Fase 10, C11).
	local altars = summary.altars
	if typeof(altars) == "table" then
		line(
			panel,
			T(
				"⛩️ Altares: {jaguar} · {quetzal}",
				{ jaguar = `{left.icon} {altars[first] or 0}`, quetzal = `{altars[second] or 0} {right.icon}` }
			),
			top,
			20,
			Color3.fromRGB(255, 205, 90)
		)
		top += 22
	end
	local amber = amberText(summary)
	if amber then
		line(panel, amber, top, 26, if summary.test then PLAIN else AMBER_TEXT)
		top += 28
	end
	-- XP del pase de temporada (si hay una en marcha).
	local passText = SeasonPass.gainText(summary.pass)
	if passText then
		line(panel, passText, top, 20, Color3.fromRGB(255, 150, 80))
		top += 26
	end
	local listTop = top + 6

	-- Tabla de jugadores (con desplazamiento si son muchos).
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.AnchorPoint = Vector2.new(0.5, 0)
	list.Position = UDim2.new(0.5, 0, 0, listTop)
	list.Size = UDim2.new(1, -24, 1, -listTop - 112)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	-- El borde de los marcos va por fuera de la fila: que la lista no lo corte arriba.
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 3)
	listPadding.Parent = list
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
	local rematch = Widgets.button(T("🔁 Revancha"), buttons)
	rematch.Size = UDim2.fromScale(0.48, 1)
	local leave = Widgets.button(T("🏝️ Volver al Lobby"), buttons)
	leave.Size = UDim2.fromScale(0.48, 1)
	leave.BackgroundColor3 = SECONDARY_BUTTON
	leave.TextColor3 = Color3.new(1, 1, 1)

	rematch.Activated:Connect(close)
	leave.Activated:Connect(function()
		leave.Text = T("⏳ Viajando…")
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
		countdown.Text =
			T("La revancha empieza en {seconds} s con quienes se queden", { seconds = math.ceil(Arena.secondsLeft()) })
	end)
end

function MatchResults.start(options: Options?)
	onToggle = if options then options.onToggle else nil
	Remotes.ArenaResults.OnClientEvent:Connect(function(summary: any)
		if typeof(summary) == "table" then
			show(summary)
		end
	end)
end

return MatchResults
