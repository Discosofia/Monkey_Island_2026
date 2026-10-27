--!strict
-- Parcela permanente en la Isla (Fase 12, Shared/Plot):
--   - La ventana de bienvenida al desbloquearla, cuando se cierra la de resultados del rescate
--     (UI/PlotWelcome).
--   - La ventana "Tu parcela" (P3), que abre el aviso del cartel de tu hueco: las 7 estructuras con su
--     nivel, lo que da el siguiente y lo que cuesta (Ámbar del perfil y materiales de la Bolsa,
--     Data/PlotStructures). Construir o mejorar lo pide al servidor (Remotes.UpgradePlot).
--     Sin desplazamiento: en PC una columna de filas; en pantallas bajas (teléfono), dos columnas.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Building = require(ReplicatedStorage.Shared.Building)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Plot = require(ReplicatedStorage.Shared.Plot)
local PlotStructures = require(ReplicatedStorage.Shared.Data.PlotStructures)
local PlotWelcome = require(ReplicatedStorage.Shared.UI.PlotWelcome)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local CLOSE_ACTION = "ClosePlot"
local HAVE_COLOR = "#a0f08c"
local MISSING_COLOR = "#ff8c78"
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local BLOCKED_COLOR = Color3.fromRGB(90, 90, 90)
local DETAIL_COLOR = Color3.fromRGB(210, 200, 185)
local GOLD = Color3.fromRGB(255, 205, 70)
-- Por debajo de este alto de pantalla (px) la ventana la ocupa entera, con dos columnas (teléfono apaisado).
local TWO_COLUMNS_BELOW = 470
local PADDING = 6

type Row = {
	structureId: string,
	frame: Frame,
	title: TextLabel,
	effect: TextLabel,
	cost: TextLabel,
	button: TextButton,
}

local PlotController = {}

local function newRow(structureId: string, order: number, parent: Instance): Row
	local frame = Instance.new("Frame")
	frame.Name = structureId
	frame.LayoutOrder = order
	frame.BackgroundColor3 = Color3.fromRGB(45, 38, 30)
	frame.BackgroundTransparency = 0.2
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	-- Tres líneas a la izquierda (nombre y nivel, lo que da el siguiente, lo que cuesta) y el botón a la
	-- derecha; todo en escala del alto de la fila, que cambia con la pantalla.
	local title = Widgets.label("", frame)
	title.Position = UDim2.new(0, 10, 0.06, 0)
	title.Size = UDim2.new(0.68, -10, 0.34, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local effect = Widgets.label("", frame)
	effect.Position = UDim2.new(0, 10, 0.4, 0)
	effect.Size = UDim2.new(0.68, -10, 0.26, 0)
	effect.TextXAlignment = Enum.TextXAlignment.Left
	effect.TextColor3 = DETAIL_COLOR
	effect.Font = Enum.Font.BuilderSans

	local cost = Widgets.label("", frame)
	cost.Position = UDim2.new(0, 10, 0.68, 0)
	cost.Size = UDim2.new(0.68, -10, 0.26, 0)
	cost.TextXAlignment = Enum.TextXAlignment.Left
	cost.RichText = true

	local button = Widgets.button("", frame)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -8, 0.5, 0)
	-- 84 % del alto de la fila: en el teléfono (filas de ~58 px) queda por encima de los 44 px para tocar.
	button.Size = UDim2.new(0.3, -10, 0.84, 0)
	-- En esta lista el botón se adapta a la fila, sin el tamaño mínimo general.
	local sizeLimit = button:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit:Destroy()
	end
	button.MouseButton1Click:Connect(function()
		if button.Active then
			Remotes.UpgradePlot:FireServer(structureId)
		end
	end)

	return { structureId = structureId, frame = frame, title = title, effect = effect, cost = cost, button = button }
end

local function amberOf(player: Player): number
	local amber = player:GetAttribute("Amber")
	return if typeof(amber) == "number" then amber else 0
end

local function refreshRow(player: Player, state: Plot.State, row: Row)
	local definition = PlotStructures[row.structureId]
	local level = state.levels[row.structureId]
	local nextLevel = definition.levels[level + 1]
	local levelText = if level > 0 then ` {Plot.ROMAN[level]}` else ""
	row.title.Text = `{definition.icon} {definition.name}{levelText}`
	if not nextLevel then
		row.effect.Text = definition.levels[level].effect
		row.cost.Text = `<font color="{HAVE_COLOR}">⭐ Nivel máximo</font>`
		row.button.Text = "Al máximo"
		row.button.BackgroundColor3 = BLOCKED_COLOR
		row.button.TextColor3 = Color3.fromRGB(200, 200, 200)
		row.button.Active = false
		row.button.AutoButtonColor = false
		return
	end
	row.effect.Text = `{Plot.ROMAN[level + 1]}: {nextLevel.effect}`
	-- Lo que pide y, entre paréntesis, lo que tienes (en verde si llega, en rojo si no).
	local amber = amberOf(player)
	local ready = amber >= nextLevel.amber
	local parts = {
		`<font color="{if ready then HAVE_COLOR else MISSING_COLOR}">✨ {nextLevel.amber} ({amber})</font>`,
	}
	for _, entry in nextLevel.cost do
		local have = Inventory.count(player, entry.itemId)
		local enough = have >= entry.amount
		ready = ready and enough
		local color = if enough then HAVE_COLOR else MISSING_COLOR
		table.insert(parts, `<font color="{color}">{Items[entry.itemId].icon} {entry.amount} ({have})</font>`)
	end
	row.cost.Text = table.concat(parts, "  ")
	row.button.Text = if not ready then "Faltan" elseif level == 0 then "Construir" else "Mejorar"
	row.button.BackgroundColor3 = if ready then READY_COLOR else BLOCKED_COLOR
	row.button.TextColor3 = if ready then Color3.fromRGB(40, 25, 5) else Color3.fromRGB(200, 200, 200)
	row.button.Active = ready
	row.button.AutoButtonColor = ready
end

function PlotController:Start()
	PlotWelcome.watch({ "Results" })

	local player = Players.LocalPlayer
	local gui = Widgets.screen("PlotHUD", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 5

	local panel = Instance.new("Frame")
	panel.Name = "PlotWindow"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromScale(0.62, 0.86)
	panel.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(320, 240)
	sizeLimit.MaxSize = Vector2.new(680, 600)
	sizeLimit.Parent = panel

	local title = Widgets.label("🏡 Tu parcela", panel)
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -80, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = GOLD

	-- "X" y no "✕": BuilderSans no tiene ese signo y sale una caja vacía.
	local closeButton = Widgets.button("X", panel)
	closeButton.Font = Enum.Font.BuilderSansExtraBold
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -8, 0, 6)
	closeButton.Size = UDim2.fromOffset(48, 40)
	local closeLimit = closeButton:FindFirstChildOfClass("UISizeConstraint")
	if closeLimit then
		closeLimit:Destroy()
	end

	local list = Instance.new("Frame")
	list.Name = "Structures"
	list.Position = UDim2.fromOffset(8, 52)
	list.Size = UDim2.new(1, -16, 1, -60)
	list.BackgroundTransparency = 1
	list.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellPadding = UDim2.fromOffset(PADDING, PADDING)
	grid.Parent = list

	local rows: { Row } = {}
	for order, structureId in Plot.STRUCTURES do
		table.insert(rows, newRow(structureId, order, list))
	end

	-- PC: una columna, la ventana centrada a su tamaño. Pantalla baja (teléfono apaisado): la ventana
	-- ocupa todo el ancho y el alto libres, con las filas en dos columnas.
	local function layout()
		local compact = gui.AbsoluteSize.Y < TWO_COLUMNS_BELOW
		panel.Size = if compact then UDim2.fromScale(0.97, 0.94) else UDim2.fromScale(0.62, 0.86)
		panel.Position = if compact then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.52)
		sizeLimit.MaxSize = if compact then Vector2.new(1000, 480) else Vector2.new(680, 600)
		local size = list.AbsoluteSize
		local columns = if compact then 2 else 1
		local lines = math.ceil(#rows / columns)
		grid.CellSize =
			UDim2.fromOffset((size.X - PADDING * (columns - 1)) / columns, (size.Y - PADDING * (lines - 1)) / lines)
	end
	list:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	local function refresh()
		if not panel.Visible then
			return
		end
		local state = Plot.of(player)
		for _, row in rows do
			refreshRow(player, state, row)
		end
	end

	local function close()
		if not panel.Visible then
			return
		end
		panel.Visible = false
		ContextActionService:UnbindAction(CLOSE_ACTION)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
			GuiService.SelectedObject = nil
		end
	end

	local function open()
		panel.Visible = true
		layout()
		refresh()
		-- B en mando cierra la ventana (por encima de la esquiva mientras está abierta).
		ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
	end

	closeButton.MouseButton1Click:Connect(close)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == Plot.PROMPT_NAME and LifeState.isAlive(player) then
			open()
		end
	end)

	-- El aviso del cartel solo sale en tu hueco y con la parcela desbloqueada.
	local prompts: { ProximityPrompt } = {}
	local function updatePrompts()
		local mine = player:GetAttribute(Building.PLOT_ATTRIBUTE)
		local unlocked = Plot.of(player).unlocked
		for _, prompt in prompts do
			prompt.Enabled = unlocked and prompt:GetAttribute("PlotIndex") == mine
		end
	end
	local function track(instance: Instance)
		if instance:IsA("ProximityPrompt") and instance.Name == Plot.PROMPT_NAME then
			table.insert(prompts, instance)
			updatePrompts()
		end
	end
	Workspace.DescendantAdded:Connect(track)
	for _, instance in Workspace:GetDescendants() do
		track(instance)
	end

	-- Ámbar, parcela, Bolsa o estado de vida: cualquier atributo del jugador refresca.
	player.AttributeChanged:Connect(function(attribute: string)
		if attribute == "Plot" or attribute == Building.PLOT_ATTRIBUTE then
			updatePrompts()
		end
		if attribute == LifeState.ATTRIBUTE and not LifeState.isAlive(player) then
			close()
		else
			refresh()
		end
	end)
end

return PlotController
