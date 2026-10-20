--!strict
-- Ventana "Antes de la batalla" de la arena: se abre sola mientras se espera (fases Waiting y
-- Countdown) y se cierra al empezar la partida. Se puede plegar para pasear por la base; queda un
-- botón "🛡️ Equipo y rol" debajo de la línea de la fase para volver a abrirla.
--   - Equipo: Jaguar o Quetzal, con cuántos hay de cuántos caben (Remotes.ArenaPickTeam).
--   - Rol: los cuatro; el tuyo, marcado en dorado; los que ya están completos en tu equipo, apagados
--     (Shared/Arena.roleAllowed; Remotes.ArenaPickRole).
--   - "¡Listo!": cuando lo pulsan todos y los equipos están completos, empieza la cuenta atrás
--     (Remotes.ArenaReady). Debajo, cuántos están listos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local WINDOW_COLOR = Color3.fromRGB(25, 20, 15)
local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local SQUARE_COLOR = Color3.fromRGB(40, 34, 28)
local GOLD = Color3.fromRGB(242, 178, 36)
local SECONDARY_TEXT = Color3.fromRGB(210, 200, 185)
local DISABLED_COLOR = Color3.fromRGB(90, 90, 90)
local ROW_HEIGHT = 50
-- Tope del texto de las casillas: con TextScaled, cada nombre saldría de un tamaño ("Mago" enorme,
-- "Guerrero" pequeño); así salen todos iguales.
local TEAM_TEXT_MAX = 24
local ROLE_TEXT_MAX = 20
-- La ventana y el botón para reabrirla van debajo del marcador y de la línea de la fase
-- (ArenaHUDController: marcador, fila de las banderas y línea de la fase, que acaba a 110 px), para
-- no tapar la cuenta atrás.
local REOPEN_TOP = 116

local ArenaLobbyController = {}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

-- Fila horizontal de casillas que se reparten el ancho.
local function row(parent: Instance, order: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

-- Casilla que se pulsa (equipo o rol). El borde dorado marca la elegida.
local function card(parent: Instance, order: number, widthScale: number, maxText: number): (TextButton, UIStroke)
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.new(widthScale, -6, 1, 0)
	button.BackgroundColor3 = CARD_COLOR
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeTransparency = 0.5
	button.Font = Enum.Font.BuilderSansBold
	button.TextScaled = true
	button.AutoButtonColor = true
	button.Parent = parent
	corner(button, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = button
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = maxText
	textLimit.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = GOLD
	stroke.Thickness = 3
	stroke.Enabled = false
	stroke.Parent = button
	return button, stroke
end

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

function ArenaLobbyController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("ArenaLobby", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 6

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0)
	window.Position = UDim2.new(0.5, 0, 0, REOPEN_TOP)
	window.Size = UDim2.new(0.6, 0, 1, -REOPEN_TOP - 12)
	window.BackgroundColor3 = WINDOW_COLOR
	window.BackgroundTransparency = 0.1
	window.Parent = gui
	corner(window, 14)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(320, 200)
	sizeLimit.MaxSize = Vector2.new(640, 264)
	sizeLimit.Parent = window

	local title = Widgets.label("⚔️ Antes de la batalla", window)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -80, 0, 34)

	local fold = Instance.new("TextButton")
	fold.Name = "Fold"
	fold.AnchorPoint = Vector2.new(1, 0)
	fold.Position = UDim2.new(1, -6, 0, 6)
	fold.Size = UDim2.fromOffset(44, 44)
	fold.BackgroundColor3 = SQUARE_COLOR
	fold.BackgroundTransparency = 0.2
	fold.Text = "—"
	fold.TextColor3 = Color3.new(1, 1, 1)
	fold.Font = Enum.Font.BuilderSansExtraBold
	fold.TextScaled = true
	fold.Parent = window
	corner(fold, 12)

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromOffset(12, 54)
	content.Size = UDim2.new(1, -24, 1, -62)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.ScrollBarThickness = 6
	content.Parent = window
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = content

	-- Equipos.
	local teamRow = row(content, 1)
	local teamCards: { [string]: { button: TextButton, stroke: UIStroke } } = {}
	for index, teamId in Arena.TEAM_IDS do
		local button, stroke = card(teamRow, index, 0.5, TEAM_TEXT_MAX)
		button.BackgroundColor3 = Config.Arena.Teams[teamId].color
		button.BackgroundTransparency = 0.25
		button.Activated:Connect(function()
			Remotes.ArenaPickTeam:FireServer(teamId)
		end)
		teamCards[teamId] = { button = button, stroke = stroke }
	end

	-- Roles.
	local roleRow = row(content, 2)
	local roleCards: { [string]: { button: TextButton, stroke: UIStroke } } = {}
	for index, roleId in rolesInOrder() do
		local button, stroke = card(roleRow, index, 0.25, ROLE_TEXT_MAX)
		local role = Roles[roleId]
		button.Text = `{role.icon} {role.name}`
		button.Activated:Connect(function()
			Remotes.ArenaPickRole:FireServer(roleId)
		end)
		roleCards[roleId] = { button = button, stroke = stroke }
	end

	-- "¡Listo!" y cuántos lo están.
	local ready = Widgets.button("✅ ¡Listo!", content)
	ready.Name = "Ready"
	ready.LayoutOrder = 3
	ready.Size = UDim2.new(0.6, 0, 0, 48)
	ready.Activated:Connect(function()
		Remotes.ArenaReady:FireServer(player:GetAttribute("ArenaReady") ~= true)
	end)

	local status = Widgets.label("", content)
	status.Name = "Status"
	status.LayoutOrder = 4
	status.Size = UDim2.new(1, 0, 0, 22)
	status.TextColor3 = SECONDARY_TEXT

	local reopen = Widgets.button("🛡️ Equipo y rol", gui)
	reopen.Name = "Reopen"
	reopen.AnchorPoint = Vector2.new(0.5, 0)
	reopen.Position = UDim2.new(0.5, 0, 0, REOPEN_TOP)
	reopen.Size = UDim2.fromOffset(200, 48)

	local folded = false
	fold.Activated:Connect(function()
		folded = true
	end)
	reopen.Activated:Connect(function()
		folded = false
	end)

	local lastPhase: Arena.Phase? = nil
	RunService.Heartbeat:Connect(function()
		local phase = Arena.phase()
		-- Al volver a la espera (otra partida), se abre sola.
		if phase ~= lastPhase and phase == "Waiting" then
			folded = false
		end
		lastPhase = phase
		local open = phase == "Waiting" or phase == "Countdown"
		window.Visible = open and not folded
		reopen.Visible = open and folded
		if not window.Visible then
			return
		end

		local myTeam = Arena.teamOf(player)
		local format = Arena.format()
		for teamId, item in teamCards do
			local team = Config.Arena.Teams[teamId]
			local count = #Arena.membersOf(teamId)
			item.button.Text = `{team.icon} {team.name}  {count}/{format}`
			item.stroke.Enabled = myTeam == teamId
		end
		local myRole = player:GetAttribute("Role")
		for roleId, item in roleCards do
			local allowed = myTeam == nil or myRole == roleId or Arena.roleAllowed(player, myTeam, roleId)
			item.stroke.Enabled = myRole == roleId
			item.button.BackgroundColor3 = if allowed then CARD_COLOR else DISABLED_COLOR
			item.button.TextTransparency = if allowed then 0 else 0.5
		end

		local isReady = player:GetAttribute("ArenaReady") == true
		local canReady = phase == "Waiting" and myTeam ~= nil
		ready.Visible = canReady
		ready.Text = if isReady then "⏳ Esperando… (quitar Listo)" else "✅ ¡Listo!"
		local readyCount, total = 0, 0
		for _, other in Players:GetPlayers() do
			total += 1
			if other:GetAttribute("ArenaReady") == true then
				readyCount += 1
			end
		end
		status.Text = if phase == "Countdown"
			then "Aún puedes cambiar de rol"
			elseif myTeam == nil then "Elige equipo para empezar"
			else `Listos: {readyCount}/{math.max(total, format * 2)}`
	end)
end

return ArenaLobbyController
