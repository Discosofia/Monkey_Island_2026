--!strict
-- Ventana "Antes de la batalla" de la arena: se abre sola mientras se espera (fases Waiting y
-- Countdown) y se cierra al empezar la partida. Se puede plegar para pasear por la base; queda un
-- botón "🛡️ Equipo y rol" debajo de la línea de la fase para volver a abrirla. Su alto se ajusta a
-- lo que tiene dentro (también con una ranura del equipo abierta), así en un PC se ve todo sin
-- desplazarse; solo si no cabe en la pantalla (un teléfono) se desplaza.
--   - Equipo: Jaguar o Quetzal, con cuántos hay de cuántos caben (Remotes.ArenaPickTeam).
--   - Rol: los cuatro, con su ventaja en combate debajo del nombre ("edge" en Data/Roles); el tuyo,
--     marcado en dorado; los que ya están completos en tu equipo, apagados
--     (Shared/Arena.roleAllowed; Remotes.ArenaPickRole).
--   - Equipo de la arena de tu rol: arma, armadura y amuleto, para ponerlo o comprarlo con Ámbar
--     (Shared/UI/ArenaGearPicker). En una pantalla baja, mientras una ranura está desplegada se
--     ocultan las filas de equipos, roles y "¡Listo!" para que quepan sus opciones sin desplazarse.
--   - "¡Listo!": cuando lo pulsan todos y los equipos están completos, empieza la cuenta atrás
--     (Remotes.ArenaReady). Debajo, cuántos están listos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local ArenaGearPicker = require(ReplicatedStorage.Shared.UI.ArenaGearPicker)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local WINDOW_COLOR = Color3.fromRGB(25, 20, 15)
local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local SQUARE_COLOR = Color3.fromRGB(40, 34, 28)
local GOLD = Color3.fromRGB(242, 178, 36)
local SECONDARY_TEXT = Color3.fromRGB(210, 200, 185)
local DISABLED_COLOR = Color3.fromRGB(90, 90, 90)
local ROW_HEIGHT = 50
-- En pantallas de poco alto (un teléfono apaisado), filas y huecos más bajos para que quepa todo.
local COMPACT_BELOW = 500
local COMPACT_ROW_HEIGHT = 44
-- Tope del texto de las casillas: con TextScaled, cada nombre saldría de un tamaño ("Mago" enorme,
-- "Guerrero" pequeño); así salen todos iguales.
local TEAM_TEXT_MAX = 24
local ROLE_TEXT_MAX = 20
local ROLE_EDGE_TEXT_MAX = 13
-- La fila de los roles es más alta: debajo del nombre va su ventaja.
local ROLE_ROW_EXTRA = 24
-- La ventana y el botón para reabrirla van debajo de la línea de la fase (ArenaHUDController, que
-- acaba a 34 px), para no tapar la cuenta atrás. El marcador está arriba a la derecha, en la barra de
-- Roblox.
local REOPEN_TOP = 40
-- Margen de arriba y de abajo dentro de la ventana. No lleva título: el botón "—" de plegar va en la
-- esquina de arriba a la derecha, junto a la fila de los equipos (que le deja FOLD_ROOM).
local HEADER_HEIGHT = 8
local FOLD_ROOM = 52
local BOTTOM_MARGIN = 6

local ArenaLobbyController = {}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

-- Fila horizontal de casillas que se reparten el ancho.
local function row(parent: Instance, order: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
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
	-- Al arrancar la cámara aún no tiene el tamaño de la pantalla (sale de 1 x 1): se espera a que lo tenga.
	local camera = Workspace.CurrentCamera
	while camera.ViewportSize.Y <= 1 do
		task.wait()
	end
	local compact = camera.ViewportSize.Y < COMPACT_BELOW
	local rowHeight = if compact then COMPACT_ROW_HEIGHT else ROW_HEIGHT

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0)
	window.Position = UDim2.new(0.5, 0, 0, REOPEN_TOP)
	window.Size = UDim2.new(0.6, 0, 0, 300)
	window.BackgroundColor3 = WINDOW_COLOR
	window.BackgroundTransparency = 0.1
	window.Parent = gui
	corner(window, 14)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(320, 0)
	sizeLimit.MaxSize = Vector2.new(640, math.huge)
	sizeLimit.Parent = window

	local fold = Instance.new("TextButton")
	fold.Name = "Fold"
	fold.AnchorPoint = Vector2.new(1, 0)
	fold.Position = UDim2.new(1, -12, 0, HEADER_HEIGHT)
	fold.Size = UDim2.fromOffset(44, 44)
	fold.ZIndex = 2
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
	content.Position = UDim2.fromOffset(12, HEADER_HEIGHT)
	content.Size = UDim2.new(1, -24, 1, -HEADER_HEIGHT - BOTTOM_MARGIN)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.ScrollBarThickness = 6
	content.Parent = window
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, if compact then 4 else 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = content
	-- El alto justo para lo que hay dentro, sin pasar del borde de abajo de la pantalla.
	local function fit()
		local needed = HEADER_HEIGHT + list.AbsoluteContentSize.Y + BOTTOM_MARGIN
		local available = gui.AbsoluteSize.Y - REOPEN_TOP - BOTTOM_MARGIN
		window.Size = UDim2.new(0.6, 0, 0, math.min(needed, available))
	end
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	-- Equipos.
	local teamRow = row(content, 1, rowHeight)
	local foldRoom = Instance.new("UIPadding")
	foldRoom.PaddingRight = UDim.new(0, FOLD_ROOM)
	foldRoom.Parent = teamRow
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
	local roleRow = row(content, 2, rowHeight + ROLE_ROW_EXTRA)
	type RoleCard = { button: TextButton, stroke: UIStroke, name: TextLabel, edge: TextLabel }
	local roleCards: { [string]: RoleCard } = {}
	for index, roleId in rolesInOrder() do
		local button, stroke = card(roleRow, index, 0.25, ROLE_TEXT_MAX)
		local role = Roles[roleId]
		button.Text = ""
		local name = Widgets.label(`{role.icon} {role.name}`, button)
		name.Size = UDim2.fromScale(1, 0.45)
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MaxTextSize = ROLE_TEXT_MAX
		nameLimit.Parent = name
		local edge = Widgets.label(role.edge, button)
		edge.Font = Enum.Font.BuilderSans
		edge.TextColor3 = SECONDARY_TEXT
		edge.Position = UDim2.fromScale(0, 0.45)
		edge.Size = UDim2.fromScale(1, 0.55)
		local edgeLimit = Instance.new("UITextSizeConstraint")
		edgeLimit.MaxTextSize = ROLE_EDGE_TEXT_MAX
		edgeLimit.Parent = edge
		button.Activated:Connect(function()
			Remotes.ArenaPickRole:FireServer(roleId)
		end)
		roleCards[roleId] = { button = button, stroke = stroke, name = name, edge = edge }
	end

	-- Equipo de la arena del rol que llevas.
	local gear = ArenaGearPicker.new(content, 3, function(): string
		local roleId = player:GetAttribute("Role")
		return if typeof(roleId) == "string" then roleId else ""
	end, compact)

	-- "¡Listo!" y cuántos lo están.
	local ready = Widgets.button("✅ ¡Listo!", content)
	ready.Name = "Ready"
	ready.LayoutOrder = 4
	ready.Size = UDim2.new(0.6, 0, 0, rowHeight)
	ready.Activated:Connect(function()
		Remotes.ArenaReady:FireServer(player:GetAttribute("ArenaReady") ~= true)
	end)

	local status = Widgets.label("", content)
	status.Name = "Status"
	status.LayoutOrder = 5
	status.Size = UDim2.new(1, 0, 0, 22)
	status.TextColor3 = SECONDARY_TEXT

	task.defer(fit)

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
			item.name.TextTransparency = if allowed then 0 else 0.5
			item.edge.TextTransparency = if allowed then 0 else 0.5
		end
		gear.update()
		local picking = compact and gear.isOpen()
		teamRow.Visible = not picking
		roleRow.Visible = not picking
		-- Mientras eliges, la ranura se cierra pulsándola otra vez: "—" taparía la línea del Ámbar.
		fold.Visible = not picking

		local isReady = player:GetAttribute("ArenaReady") == true
		local canReady = phase == "Waiting" and myTeam ~= nil
		ready.Visible = canReady and not picking
		ready.Text = if isReady then "⏳ Esperando… (quitar Listo)" else "✅ ¡Listo!"
		local readyCount, total = 0, 0
		for _, other in Players:GetPlayers() do
			total += 1
			if other:GetAttribute("ArenaReady") == true then
				readyCount += 1
			end
		end
		status.Visible = not picking
		status.Text = if phase == "Countdown"
			then "Aún puedes cambiar de rol y de equipo"
			elseif myTeam == nil then "Elige equipo para empezar"
			else `Listos: {readyCount}/{math.max(total, format * 2)}`
	end)
end

return ArenaLobbyController
