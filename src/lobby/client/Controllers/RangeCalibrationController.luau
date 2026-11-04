--!strict
-- Panel de calibración del tiro del campo de tiro (Fase 24d, RangeCalibrationService). Se abre y se cierra con
-- el aviso «Abrir» de la consola «Calibración» (CalibracionPrompt), con ✕, con Ctrl en primera persona y al salir
-- del recinto. Bajo la cabecera lleva los controles del muñeco de calibración (distancia y movimiento, del campo
-- entero; los lee de los atributos CalibrationDistance y CalibrationMoving) y «Borrar datos» (vacía las estadísticas
-- y las marcas del jugador); todos mandan Remotes.RangeCalibrationControl. Una fila por arma o habilidad que ha
-- disparado el jugador (las más antiguas salen si hay más de 6 en PC o 3 en teléfono) y tres columnas por la distancia del tirador al impacto: Cerca, Media y Lejos
-- (Config.Range.Calibration). Cada celda dice los tiros, el acierto sobre el muñeco de calibración (sin contar los
-- tiros que acaban en una pantalla; «—» si no queda ninguno) y el vuelo medio, y debajo la distancia media
-- recorrida (studs), el desvío medio y la dispersión sobre las pantallas de ajuste y la ayuda media del táctil
-- (grados). El panel va anclado arriba a la derecha para no tapar las dianas. En
-- las armas del Laboratorio, la fila trae también su dispersión configurada, como referencia. En Studio hay un
-- botón «Exportar» (el servidor deja el JSON en ServerStorage.CalibracionExportada). En primera persona (modo
-- shooter) el panel suelta el ratón mientras está abierto (FirstPersonController.freeCursor).
-- Colores del HUD del Lobby: madera oscura, dorado y naranja; el color de cada fila es el de su arma (Data/RangeSources).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local RangeSources = require(ReplicatedStorage.Shared.Data.RangeSources)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local FirstPersonController = require(ReplicatedStorage.CombatClient.Controllers.FirstPersonController)
local ViewMode = require(ReplicatedStorage.CombatClient.ViewMode)

local T = Strings.t
local SETTINGS = Config.Range.Calibration

local OPEN_PROMPT = "CalibracionPrompt"
local CURSOR_REASON = "Calibration"
local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local BUTTON_COLOR = Color3.fromRGB(88, 70, 50)
local GOLD = Color3.fromRGB(255, 215, 90)
local WHITE = Color3.new(1, 1, 1)
local SECONDARY = Color3.fromRGB(215, 205, 190)
local BUCKETS = { "Near", "Mid", "Far" }
-- Cada cuánto se mira si el jugador sigue dentro del recinto.
local WATCH_SECONDS = 0.5
local INSIDE_SLACK = 2
local SIDE_MARGIN = 12
local MAX_SOURCE_LENGTH = 64

-- Medidas según el dispositivo: teléfono (táctil sin teclado) más compacto.
local compact = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
-- En PC el panel mide 500 px (dos tercios de los 749 de antes): 120 de nombre y 3 columnas de 118.
local NAME_WIDTH = if compact then 112 else 120
local CELL_WIDTH = if compact then 112 else 118
-- Margen de arriba: en PC libra la barra superior y los avisos de arriba a la derecha; en teléfono, el de antes.
local TOP_MARGIN = if compact then 46 else 100
-- Cada celda son tres líneas de tres columnas (tiros · acierto · vuelo / distancia · desvío · dispersión / ayuda),
-- con el texto pegado a la izquierda, al centro y a la derecha de su columna: así llena el ancho de la celda.
local CELL_LINE_HEIGHT = if compact then 13 else 14
local ROW_HEIGHT = CELL_LINE_HEIGHT * 3 + 6
local TEXT_SIZE = if compact then 10 else 13
local CELL_TEXT_SIZE = if compact then 10 else 11
local MAX_ROWS = if compact then 3 else 6
local PADDING = if compact then 8 else 12
local CONTROL_HEIGHT = if compact then 32 else 30
local CONTROL_LABEL_WIDTH = if compact then 104 else 104
local CONTROL_GAP = 4
local PANEL_WIDTH = NAME_WIDTH + CELL_WIDTH * 3 + PADDING * 2
-- Los botones de los controles se reparten el ancho que deja la etiqueta, para que la fila llene el panel.
local CONTROLS_INNER = PANEL_WIDTH - PADDING * 2 - CONTROL_LABEL_WIDTH
local DISTANCE_BUTTON_WIDTH = math.floor((CONTROLS_INNER - CONTROL_GAP * #SETTINGS.Distances) / #SETTINGS.Distances)
local MOVING_BUTTON_WIDTH = math.floor((CONTROLS_INNER - CONTROL_GAP * 3) / 3)
local SLOTS_PER_LINE = 3
local SLOT_WIDTH = math.floor((CELL_WIDTH - 4) / SLOTS_PER_LINE)

-- "cells[cubo]" tiene 7 etiquetas: 3 de la línea 1, 3 de la línea 2 y 1 ancha de la línea 3 (la ayuda del táctil).
type Row = { frame: Frame, name: TextLabel, reference: TextLabel, cells: { { TextLabel } } }
type Entry = { data: { [string]: any }, order: number, seen: number, row: Row }

local RangeCalibrationController = {}

local panel: Frame
local rowsHolder: Frame
local emptyLabel: TextLabel
local titleLabel: TextLabel
local legendLabel: TextLabel
local exportButton: TextButton?
local headerLabels: { TextLabel } = {}
local entries: { [string]: Entry } = {}
local nextOrder = 0
local isOpen = false
local dummy: Instance? = nil
local distanceLabel: TextLabel
local movingLabel: TextLabel
local distanceButtons: { [number]: TextButton } = {}
local movingButtons: { [string]: TextButton } = {}
local clearButton: TextButton

-- Un número de "table" si es finito.
local function num(container: any, key: string): number?
	if typeof(container) ~= "table" then
		return nil
	end
	local value = container[key]
	if typeof(value) == "number" and value == value and math.abs(value) < 1e9 then
		return value
	end
	return nil
end

-- Los 7 textos de una celda (ver Row.cells): tiros, acierto, vuelo · distancia, desvío, dispersión · ayuda.
-- Son símbolos y números (× % s st Δ σ): no se traducen; la leyenda del panel los explica.
local function cellItems(bucket: any): { string }
	local count = num(bucket, "n") or 0
	if count <= 0 then
		return { "—", "", "", "", "", "", "" }
	end
	local hits = num(bucket, "hits") or 0
	-- Acierto sobre el muñeco: los tiros que acaban en una pantalla de ajuste no cuentan.
	local aimed = count - (num(bucket, "screenShots") or 0)
	local travel = num(bucket, "meanTravel")
	local meanDx, meanDy, spread = num(bucket, "meanDx"), num(bucket, "meanDy"), num(bucket, "spread")
	local assist = num(bucket, "meanAssist")
	return {
		`{count}×`,
		if aimed > 0 then `{math.round(hits / aimed * 100)} %` else "—",
		string.format("%.2f s", num(bucket, "meanFlight") or 0),
		if travel then `{math.round(travel)} st` else "",
		if meanDx and meanDy then string.format("Δ %.2f", math.sqrt(meanDx * meanDx + meanDy * meanDy)) else "",
		if spread then string.format("σ %.2f", spread) else "",
		if assist then T("ayuda {assist}°", { assist = string.format("%.1f", assist) }) else "",
	}
end

local function renderRow(source: string, entry: Entry)
	local row = entry.row
	local info = RangeSources.get(source)
	row.name.Text = T(info.name)
	row.name.TextColor3 = info.color
	local reference = entry.data.labSpread
	if typeof(reference) == "table" then
		row.reference.Text = T("Disp. config.: {still}/{moving}/{air}°", {
			still = num(reference, "still") or 0,
			moving = num(reference, "moving") or 0,
			air = num(reference, "air") or 0,
		})
	else
		row.reference.Text = ""
	end
	for index, name in BUCKETS do
		local items = cellItems(entry.data[name])
		for slot, label in row.cells[index] do
			label.Text = items[slot]
		end
	end
end

local function renderStatic()
	titleLabel.Text = T("Calibración del tiro")
	legendLabel.Text = T(
		"Celda: tiros × · acierto % · vuelo (s) / distancia recorrida (st = studs) · Δ desvío medio y σ dispersión en pantallas (studs) · ayuda del táctil (°). Acierto = sobre el muñeco de calibración"
	)
	headerLabels[1].Text = T("Arma o habilidad")
	headerLabels[2].Text = T("Cerca (≤{max})", { max = SETTINGS.NearMax })
	headerLabels[3].Text = T("Media ({min}–{max})", { min = SETTINGS.NearMax + 1, max = SETTINGS.FarMin - 1 })
	headerLabels[4].Text = T("Lejos (≥{min})", { min = SETTINGS.FarMin })
	emptyLabel.Text = T("Dispara para empezar a medir")
	distanceLabel.Text = T("Distancia del muñeco")
	movingLabel.Text = T("Movimiento")
	movingButtons.still.Text = T("Quieto")
	movingButtons.moving.Text = T("De lado a lado")
	clearButton.Text = T("Borrar datos")
	if exportButton then
		exportButton.Text = T("Exportar")
	end
	for source, entry in entries do
		renderRow(source, entry)
	end
end

local function textLabel(text: string, size: number, color: Color3, parent: Instance): TextLabel
	local label = Widgets.label(text, parent)
	label.TextScaled = false
	label.TextSize = size
	label.TextColor3 = color
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	return label
end

local function newRow(order: number): Row
	local frame = Instance.new("Frame")
	frame.Name = "Fila"
	frame.BackgroundColor3 = BUTTON_COLOR
	frame.BackgroundTransparency = 0.6
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	frame.LayoutOrder = order
	frame.Parent = rowsHolder
	-- El nombre cabe en dos líneas y debajo va la dispersión configurada del arma del Laboratorio.
	local nameLines = 2
	local nameLabel = textLabel("", CELL_TEXT_SIZE + 1, WHITE, frame)
	nameLabel.Font = Enum.Font.BuilderSansBold
	nameLabel.Size = UDim2.fromOffset(NAME_WIDTH - 4, (CELL_TEXT_SIZE + 3) * nameLines)
	nameLabel.Position = UDim2.fromOffset(2, 2)
	local reference = textLabel("", CELL_TEXT_SIZE - 1, SECONDARY, frame)
	reference.Size = UDim2.fromOffset(NAME_WIDTH - 4, CELL_LINE_HEIGHT)
	reference.Position = UDim2.fromOffset(2, 2 + (CELL_TEXT_SIZE + 3) * nameLines)
	local cells = {}
	local alignments = { Enum.TextXAlignment.Left, Enum.TextXAlignment.Center, Enum.TextXAlignment.Right }
	for index = 1, #BUCKETS do
		local left = NAME_WIDTH + CELL_WIDTH * (index - 1)
		local slots = {}
		-- Líneas 1 y 2: tres columnas iguales (izquierda, centro, derecha).
		for line = 1, 2 do
			for column = 1, SLOTS_PER_LINE do
				local slot = textLabel("", CELL_TEXT_SIZE, WHITE, frame)
				slot.TextXAlignment = alignments[column]
				slot.Size = UDim2.fromOffset(SLOT_WIDTH, CELL_LINE_HEIGHT)
				slot.Position = UDim2.fromOffset(left + (column - 1) * SLOT_WIDTH, 2 + (line - 1) * CELL_LINE_HEIGHT)
				slots[(line - 1) * SLOTS_PER_LINE + column] = slot
			end
		end
		-- Línea 3: la ayuda del táctil, a todo lo ancho de la celda.
		local assist = textLabel("", CELL_TEXT_SIZE, SECONDARY, frame)
		assist.Size = UDim2.fromOffset(SLOT_WIDTH * SLOTS_PER_LINE, CELL_LINE_HEIGHT)
		assist.Position = UDim2.fromOffset(left, 2 + 2 * CELL_LINE_HEIGHT)
		slots[SLOTS_PER_LINE * 2 + 1] = assist
		cells[index] = slots
	end
	return { frame = frame, name = nameLabel, reference = reference, cells = cells }
end

-- Quita la fila que hace más que no recibe tiros hasta que caben todas.
local function trimRows(keep: string)
	while true do
		local count, oldest, oldestSeen = 0, nil, math.huge
		for source, entry in entries do
			count += 1
			if source ~= keep and entry.seen < oldestSeen then
				oldest, oldestSeen = source, entry.seen
			end
		end
		if count <= MAX_ROWS or not oldest then
			return
		end
		entries[oldest].row.frame:Destroy()
		entries[oldest] = nil
	end
end

local function updateEmpty()
	emptyLabel.Visible = next(entries) == nil
end

local function onCalibration(kind: any, source: any, data: any)
	if kind == "Clear" then
		for _, entry in entries do
			entry.row.frame:Destroy()
		end
		table.clear(entries)
		updateEmpty()
		return
	end
	if kind ~= "Snapshot" or typeof(source) ~= "string" or #source > MAX_SOURCE_LENGTH or typeof(data) ~= "table" then
		return
	end
	local entry = entries[source]
	if not entry then
		nextOrder += 1
		entry = { data = data, order = nextOrder, seen = os.clock(), row = newRow(nextOrder) }
		entries[source] = entry
		trimRows(source)
	end
	entry.data = data
	entry.seen = os.clock()
	renderRow(source, entry)
	updateEmpty()
end

-- Abre o cierra el panel. En primera persona suelta el ratón mientras está abierto.
local function setOpen(open: boolean)
	if isOpen == open then
		return
	end
	isOpen = open
	panel.Visible = open
	if ViewMode.get() == "First" then
		FirstPersonController.freeCursor(CURSOR_REASON, open)
	end
end

local function insideRange(): boolean
	local range = Workspace:FindFirstChild("CampoDeTiro")
	local floor = range and range:FindFirstChild("Suelo")
	local slab = floor and floor:FindFirstChild("Losa")
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (slab and slab:IsA("BasePart") and root and root:IsA("BasePart")) then
		return false
	end
	local at = slab.CFrame:PointToObjectSpace(root.Position)
	return math.abs(at.X) <= slab.Size.X / 2 + INSIDE_SLACK and math.abs(at.Z) <= slab.Size.Z / 2 + INSIDE_SLACK
end

local function roundButton(text: string, width: number, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Text = text
	button.Font = Enum.Font.BuilderSansBold
	button.TextSize = TEXT_SIZE + 3
	button.TextColor3 = WHITE
	button.BackgroundColor3 = BUTTON_COLOR
	button.Size = UDim2.fromOffset(width, 28)
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

-- Resalta (dorado) el botón activo de cada grupo con el estado del muñeco.
local function refreshControls()
	local distance = if dummy then dummy:GetAttribute("CalibrationDistance") else nil
	if typeof(distance) ~= "number" then
		distance = SETTINGS.Distances[SETTINGS.DefaultIndex]
	end
	local isMoving = if dummy then dummy:GetAttribute("CalibrationMoving") == true else false
	local function paint(button: TextButton, active: boolean)
		button.BackgroundColor3 = if active then GOLD else BUTTON_COLOR
		button.TextColor3 = if active then CARD_COLOR else WHITE
	end
	for studs, button in distanceButtons do
		paint(button, studs == distance)
	end
	paint(movingButtons.still, not isMoving)
	paint(movingButtons.moving, isMoving)
end

local function controlButton(text: string, width: number, parent: Instance): TextButton
	local button = roundButton(text, width, parent)
	button.Size = UDim2.fromOffset(width, CONTROL_HEIGHT - 4)
	button.TextSize = TEXT_SIZE + 1
	return button
end

local function controlRow(order: number, parent: Instance): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, CONTROL_HEIGHT)
	row.LayoutOrder = order
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, CONTROL_GAP)
	layout.Parent = row
	return row
end

local function controlLabel(order: number, parent: Instance): TextLabel
	local label = textLabel("", TEXT_SIZE, GOLD, parent)
	label.Font = Enum.Font.BuilderSansBold
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Size = UDim2.fromOffset(CONTROL_LABEL_WIDTH, CONTROL_HEIGHT)
	label.LayoutOrder = order
	return label
end

local function build(playerGui: PlayerGui)
	local gui = Widgets.screen("RangeCalibration", playerGui)
	gui.DisplayOrder = 0

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	-- A la derecha: el centro y la izquierda del campo quedan libres para ver las dianas.
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -SIDE_MARGIN, 0, TOP_MARGIN)
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
	padding.PaddingTop = UDim.new(0, PADDING)
	padding.PaddingBottom = UDim.new(0, PADDING)
	padding.PaddingLeft = UDim.new(0, PADDING)
	padding.PaddingRight = UDim.new(0, PADDING)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = panel

	-- Cabecera: título, «Exportar» (solo Studio) y ✕.
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 28)
	header.LayoutOrder = 1
	header.Parent = panel
	titleLabel = textLabel("", TEXT_SIZE + 5, GOLD, header)
	titleLabel.Font = Enum.Font.BuilderSansBold
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.Size = UDim2.new(1, -120, 1, 0)
	local close = roundButton("✕", 28, header)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	if RunService:IsStudio() then
		local export = roundButton("", 80, header)
		export.AnchorPoint = Vector2.new(1, 0)
		export.Position = UDim2.new(1, -34, 0, 0)
		export.Activated:Connect(function()
			Remotes.RangeCalibrationExport:FireServer()
		end)
		exportButton = export
	end

	-- Controles del muñeco: distancia (cinco botones) y movimiento (dos), y «Borrar datos».
	local controls = Instance.new("Frame")
	controls.Name = "Controles"
	controls.BackgroundTransparency = 1
	controls.Size = UDim2.fromScale(1, 0)
	controls.AutomaticSize = Enum.AutomaticSize.Y
	controls.LayoutOrder = 2
	controls.Parent = panel
	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlsLayout.Padding = UDim.new(0, 2)
	controlsLayout.Parent = controls
	local distanceRow = controlRow(1, controls)
	distanceLabel = controlLabel(0, distanceRow)
	for index, studs in SETTINGS.Distances do
		local button = controlButton(tostring(studs), DISTANCE_BUTTON_WIDTH, distanceRow)
		button.LayoutOrder = index
		button.Activated:Connect(function()
			Remotes.RangeCalibrationControl:FireServer("Distance", studs)
		end)
		distanceButtons[studs] = button
	end
	local movingRow = controlRow(2, controls)
	movingLabel = controlLabel(0, movingRow)
	for index, key in { "still", "moving" } do
		local button = controlButton("", MOVING_BUTTON_WIDTH, movingRow)
		button.LayoutOrder = index
		button.Activated:Connect(function()
			Remotes.RangeCalibrationControl:FireServer("Moving", key == "moving")
		end)
		movingButtons[key] = button
	end
	clearButton = controlButton("", MOVING_BUTTON_WIDTH, movingRow)
	clearButton.LayoutOrder = 3
	clearButton.Activated:Connect(function()
		Remotes.RangeCalibrationControl:FireServer("Clear")
	end)

	-- Cabeceras de columna.
	local columns = Instance.new("Frame")
	columns.BackgroundTransparency = 1
	columns.Size = UDim2.new(1, 0, 0, TEXT_SIZE + 6)
	columns.LayoutOrder = 3
	columns.Parent = panel
	for index = 1, 4 do
		local label = textLabel("", TEXT_SIZE, GOLD, columns)
		label.Font = Enum.Font.BuilderSansBold
		label.Size = UDim2.new(0, (if index == 1 then NAME_WIDTH else CELL_WIDTH) - 4, 1, 0)
		label.Position = UDim2.fromOffset(if index == 1 then 2 else NAME_WIDTH + CELL_WIDTH * (index - 2), 0)
		headerLabels[index] = label
	end

	rowsHolder = Instance.new("Frame")
	rowsHolder.Name = "Filas"
	rowsHolder.BackgroundTransparency = 1
	rowsHolder.Size = UDim2.fromScale(1, 0)
	rowsHolder.AutomaticSize = Enum.AutomaticSize.Y
	rowsHolder.LayoutOrder = 4
	rowsHolder.Parent = panel
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.Padding = UDim.new(0, 3)
	rowsLayout.Parent = rowsHolder

	emptyLabel = textLabel("", TEXT_SIZE + 1, SECONDARY, panel)
	emptyLabel.Size = UDim2.new(1, 0, 0, TEXT_SIZE + 6)
	emptyLabel.LayoutOrder = 5

	legendLabel = textLabel("", TEXT_SIZE - 1, SECONDARY, panel)
	legendLabel.Size = UDim2.new(1, 0, 0, (TEXT_SIZE + 2) * (if compact then 5 else 3))
	legendLabel.LayoutOrder = 6
end

function RangeCalibrationController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	build(playerGui)
	renderStatic()
	updateEmpty()
	refreshControls()

	-- El estado del muñeco es del campo entero: se lee de sus atributos y se sigue.
	task.spawn(function()
		local range = Workspace:WaitForChild("CampoDeTiro")
		local dummies = range:WaitForChild("Munecos")
		local found = dummies:WaitForChild("MuniecoCalibracion", 30)
		if found then
			dummy = found
			found:GetAttributeChangedSignal("CalibrationDistance"):Connect(refreshControls)
			found:GetAttributeChangedSignal("CalibrationMoving"):Connect(refreshControls)
			refreshControls()
		end
	end)

	Remotes.RangeCalibration.OnClientEvent:Connect(onCalibration)
	Strings.onChanged(renderStatic)
	-- Ctrl en primera persona vuelve a bloquear el ratón: cierra el panel (y devuelve el cursor).
	FirstPersonController.onLockRequested(function()
		setOpen(false)
	end)
	-- Si la vista cambia con el panel abierto (se equipa o se deja un arma del Armero), el ratón sigue a la vista.
	ViewMode.changed:Connect(function(mode: string)
		if isOpen then
			FirstPersonController.freeCursor(CURSOR_REASON, mode == "First")
		end
	end)

	local range = Workspace:WaitForChild("CampoDeTiro")
	local function consider(instance: Instance)
		if instance:IsA("ProximityPrompt") and instance.Name == OPEN_PROMPT then
			instance.Triggered:Connect(function()
				setOpen(not isOpen)
			end)
		end
	end
	for _, instance in range:GetDescendants() do
		consider(instance)
	end
	range.DescendantAdded:Connect(consider)

	-- Se cierra al salir del recinto.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < WATCH_SECONDS or not isOpen then
			return
		end
		elapsed = 0
		if not insideRange() then
			setOpen(false)
		end
	end)
end

return RangeCalibrationController
