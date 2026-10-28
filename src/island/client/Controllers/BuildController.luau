--!strict
-- Modo construcción (Fase 2.2): se activa al equipar el martillo.
--   - Ventana compacta a la derecha con las piezas y su coste (en un teléfono, una ficha con la pieza
--     elegida y ◀ ▶); la elegida se ve como vista previa transparente (verde si se puede poner, roja
--     si no).
--   - PC: el ratón apunta, clic coloca, R gira, T cambia de pieza y X derriba una pieza tuya.
--   - Móvil y mando: la vista previa va al centro de la pantalla; tocar (o R2) coloca y hay botones
--     "Girar", "Pieza" y "Quitar" (cruceta derecha, L1 y cruceta abajo en mando).
-- El servidor (BuildingService) vuelve a comprobarlo todo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BuildModels = require(ReplicatedStorage.Shared.BuildModels)
local Buildables = require(ReplicatedStorage.Shared.Data.Buildables)
local Building = require(ReplicatedStorage.Shared.Building)
local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local ActionButtons = require(ReplicatedStorage.CombatClient.ActionButtons)
local BodyAnimations = require(ReplicatedStorage.CombatClient.BodyAnimations)

local T = Strings.t

local ROTATE_ACTION = "BuildRotate"
local NEXT_ACTION = "BuildNext"
local DEMOLISH_ACTION = "BuildDemolish"
local AIM_DISTANCE = 80
local VALID_COLOR = Color3.fromRGB(90, 230, 110)
local INVALID_COLOR = Color3.fromRGB(240, 70, 60)
local SELECTED_COLOR = Color3.fromRGB(242, 178, 36)
local IDLE_COLOR = Color3.fromRGB(45, 38, 30)
local WINDOW_COLOR = Color3.fromRGB(25, 20, 15)
-- Cuadrícula del panel en PC: 12 piezas en 3 columnas x 4 filas (unos 380 x 320 px).
local PANEL_COLUMNS = 3
local TILE_SIZE = Vector2.new(118, 62)

local BuildController = {}

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

local function textCap(object: GuiObject, max: number)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = max
	limit.Parent = object
end

local function sortedIds(): { string }
	local ids = {}
	for id in Buildables do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Buildables[a].order < Buildables[b].order
	end)
	return ids
end

local function costText(player: Player, definition: Buildables.Buildable): string
	local parts = {}
	for _, entry in definition.cost do
		local enough = Inventory.count(player, entry.itemId) >= entry.amount
		local color = if enough then "#a0f08c" else "#ff8c78"
		table.insert(parts, `<font color="{color}">{Items[entry.itemId].icon} {entry.amount}</font>`)
	end
	return table.concat(parts, "  ")
end

local function canAfford(player: Player, definition: Buildables.Buildable): boolean
	for _, entry in definition.cost do
		if Inventory.count(player, entry.itemId) < entry.amount then
			return false
		end
	end
	return true
end

function BuildController:Start()
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()
	local ids = sortedIds()
	local selected = 1
	local rotation = 0
	local active: Tool? = nil
	local ghost: Model? = nil
	local highlight: Highlight? = nil
	local placement: CFrame? = nil
	local placementValid = false
	local aimedStructure: Model? = nil

	-- Panel de piezas: una ventana opaca y compacta a la derecha, en una cuadrícula de 3 columnas. Antes
	-- era una columna transparente de 600 px que llegaba hasta "Volver al Lobby": un clic entre dos
	-- piezas caía en ese botón. El fondo es Active para que ningún clic lo atraviese.
	local gui = Widgets.screen("BuildHUD", player:WaitForChild("PlayerGui"))
	gui.Enabled = false
	local panel = Instance.new("Frame")
	panel.Name = "Pieces"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	panel.Size = UDim2.fromOffset(PANEL_COLUMNS * TILE_SIZE.X + (PANEL_COLUMNS - 1) * 6 + 16, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = WINDOW_COLOR
	panel.BackgroundTransparency = 0.05
	panel.Active = true
	panel.Parent = gui
	corner(panel, 12)
	local panelPadding = Instance.new("UIPadding")
	panelPadding.PaddingTop = UDim.new(0, 6)
	panelPadding.PaddingBottom = UDim.new(0, 8)
	panelPadding.PaddingLeft = UDim.new(0, 8)
	panelPadding.PaddingRight = UDim.new(0, 8)
	panelPadding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel
	local heading = Widgets.label(T("🔨 Construir"), panel)
	heading.LayoutOrder = 1
	heading.Size = UDim2.new(1, 0, 0, 26)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	textCap(heading, 20)
	local refreshPanel: () -> ()
	local grid = Instance.new("Frame")
	grid.LayoutOrder = 2
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Parent = panel
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(TILE_SIZE.X, TILE_SIZE.Y)
	gridLayout.CellPadding = UDim2.fromOffset(6, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	type Tile = { button: TextButton, name: TextLabel, cost: TextLabel }
	local tiles: { Tile } = {}
	for index, id in ids do
		local button = Instance.new("TextButton")
		button.Name = id
		button.LayoutOrder = index
		button.Text = ""
		button.BackgroundColor3 = IDLE_COLOR
		button.Parent = grid
		corner(button, 8)
		local name = Widgets.label("", button)
		name.Position = UDim2.fromOffset(5, 4)
		name.Size = UDim2.new(1, -10, 0, 32)
		name.TextWrapped = true
		textCap(name, 14)
		local cost = Widgets.label("", button)
		cost.AnchorPoint = Vector2.new(0, 1)
		cost.Position = UDim2.new(0, 5, 1, -4)
		cost.Size = UDim2.new(1, -10, 0, 18)
		cost.RichText = true
		textCap(cost, 14)
		button.MouseButton1Click:Connect(function()
			selected = index
			refreshPanel()
		end)
		tiles[index] = { button = button, name = name, cost = cost }
	end

	-- En un teléfono la cuadrícula no cabe: una ficha con la pieza elegida y ◀ ▶ para cambiarla, arriba
	-- en el centro, justo bajo la barra de Roblox (a la derecha están Girar, Pieza y Quitar; a la izquierda,
	-- las barras y las habilidades). De noche tapa la vida del campamento mientras llevas el martillo.
	local card = Instance.new("Frame")
	card.Name = "PieceCard"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 4)
	card.Size = UDim2.fromOffset(300, 52)
	card.BackgroundColor3 = WINDOW_COLOR
	card.BackgroundTransparency = 0.05
	card.Active = true
	card.Parent = gui
	corner(card, 12)
	local function arrow(text: string, anchorX: number): TextButton
		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(anchorX, 0.5)
		button.Position = UDim2.new(anchorX, if anchorX == 0 then 4 else -4, 0.5, 0)
		button.Size = UDim2.fromOffset(44, 44)
		button.BackgroundColor3 = IDLE_COLOR
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.BuilderSansExtraBold
		button.TextScaled = true
		button.Text = text
		button.Parent = card
		corner(button, 8)
		return button
	end
	local previous = arrow("◀", 0)
	local nextButton = arrow("▶", 1)
	local cardName = Widgets.label("", card)
	cardName.Position = UDim2.fromOffset(52, 4)
	cardName.Size = UDim2.new(1, -104, 0, 24)
	textCap(cardName, 16)
	local cardCost = Widgets.label("", card)
	cardCost.Position = UDim2.fromOffset(52, 28)
	cardCost.Size = UDim2.new(1, -104, 0, 20)
	cardCost.RichText = true
	textCap(cardCost, 15)
	previous.Activated:Connect(function()
		selected = (selected - 2) % #ids + 1
		refreshPanel()
	end)
	nextButton.Activated:Connect(function()
		selected = selected % #ids + 1
		refreshPanel()
	end)
	local hint = Widgets.label("", gui)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -100)
	hint.Size = UDim2.fromScale(0.6, 0.04)

	function refreshPanel()
		local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		panel.Visible = not touch
		card.Visible = touch
		for index, id in ids do
			local definition = Buildables[id]
			local tile = tiles[index]
			local chosen = index == selected
			tile.button.BackgroundColor3 = if chosen then SELECTED_COLOR else IDLE_COLOR
			tile.name.Text = `{definition.icon} {T(definition.name)}`
			tile.name.TextColor3 = if chosen then Color3.fromRGB(40, 25, 5) else Color3.new(1, 1, 1)
			tile.name.TextStrokeTransparency = if chosen then 1 else 0.5
			tile.cost.Text = costText(player, definition)
		end
		local definition = Buildables[ids[selected]]
		cardName.Text = `{definition.icon} {T(definition.name)}`
		cardCost.Text = costText(player, definition)
		hint.Text = if touch
			then T("Toca para colocar · Girar · Pieza · Quitar")
			else T("Clic: colocar · R: girar · T: cambiar pieza · F: quitar una pieza tuya")
	end

	local function clearGhost()
		if ghost then
			ghost:Destroy()
		end
		ghost = nil
		highlight = nil
	end

	local function ensureGhost()
		local id = ids[selected]
		if ghost and ghost:GetAttribute("BuildableId") == id then
			return
		end
		clearGhost()
		local model = BuildModels.build(id)
		BuildModels.makeGhost(model)
		model:SetAttribute("BuildableId", id)
		local newHighlight = Instance.new("Highlight")
		newHighlight.FillTransparency = 0.6
		newHighlight.OutlineTransparency = 0.2
		newHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
		newHighlight.Parent = model
		model.Parent = Workspace
		ghost = model
		highlight = newHighlight
	end

	-- Rayo de apuntado: ratón en PC, centro de la pantalla en móvil y mando.
	local function aimRay(): Ray
		local camera = Workspace.CurrentCamera
		if UserInputService.MouseEnabled then
			return mouse.UnitRay
		end
		local viewport = camera.ViewportSize
		return camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	end

	local function update()
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local center = Building.center()
		if not (active and character and root and root:IsA("BasePart") and center) then
			return
		end
		ensureGhost()
		local model = ghost :: Model
		local id = ids[selected]
		local definition = Buildables[id]

		local ray = aimRay()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, model }
		params.IgnoreWater = true
		local hit = Workspace:Raycast(ray.Origin, ray.Direction.Unit * AIM_DISTANCE, params)

		-- Pieza propia apuntada (para derribar).
		aimedStructure = nil
		local folder = Workspace:FindFirstChild(Building.STRUCTURES_FOLDER)
		if hit and folder and hit.Instance:IsDescendantOf(folder) then
			local structure = hit.Instance:FindFirstAncestorOfClass("Model")
			while structure and structure.Parent ~= folder do
				structure = structure:FindFirstAncestorOfClass("Model")
			end
			aimedStructure = structure
		end

		if not hit then
			model.Parent = nil
			placement = nil
			return
		end
		local ignore: { Instance } = { model }
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(ignore, other.Character)
			end
		end
		if folder then
			table.insert(ignore, folder)
		end
		local groundY = Building.groundAt(hit.Position.X, hit.Position.Z, root.Position.Y, ignore)
		if not groundY then
			model.Parent = nil
			placement = nil
			return
		end
		local cframe = Building.placement(hit.Position, groundY, rotation, definition.size)
		model:PivotTo(cframe)
		model.Parent = Workspace
		placement = cframe

		local plotIndex = player:GetAttribute(Building.PLOT_ATTRIBUTE)
		local zone =
			Building.zoneFor(cframe, definition.size, if typeof(plotIndex) == "number" then plotIndex else nil, center)
		local inReach = (cframe.Position - root.Position).Magnitude <= Config.Building.Reach
		placementValid = zone ~= nil
			and definition.zones[zone] == true
			and inReach
			and canAfford(player, definition)
			and not Building.isBlocked(cframe, definition.size, { model })
		if highlight then
			highlight.FillColor = if placementValid then VALID_COLOR else INVALID_COLOR
			highlight.OutlineColor = highlight.FillColor
		end
	end

	local function bindControls(enabled: boolean)
		if not enabled then
			ActionButtons.unbind(ROTATE_ACTION)
			ActionButtons.unbind(NEXT_ACTION)
			ActionButtons.unbind(DEMOLISH_ACTION)
			return
		end
		local function bind(action: string, title: string, handler: () -> (), ...: Enum.KeyCode)
			ActionButtons.bind(action, title, function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					handler()
				end
				return Enum.ContextActionResult.Sink
			end, ...)
		end
		bind(ROTATE_ACTION, T("Girar"), function()
			rotation = (rotation + 1) % 4
		end, Enum.KeyCode.R, Enum.KeyCode.DPadRight)
		bind(NEXT_ACTION, T("Pieza"), function()
			selected = selected % #ids + 1
			refreshPanel()
		end, Enum.KeyCode.T, Enum.KeyCode.ButtonL1)
		bind(DEMOLISH_ACTION, T("Quitar"), function()
			if aimedStructure then
				BodyAnimations.play("Hammer")
				Remotes.Demolish:FireServer(aimedStructure)
			end
		end, Enum.KeyCode.F, Enum.KeyCode.DPadDown)
	end

	local renderConnection: RBXScriptConnection? = nil
	local activatedConnection: RBXScriptConnection? = nil

	local function exitBuildMode()
		active = nil
		gui.Enabled = false
		clearGhost()
		bindControls(false)
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		if activatedConnection then
			activatedConnection:Disconnect()
			activatedConnection = nil
		end
	end

	local function enterBuildMode(tool: Tool)
		if active or not LifeState.isAlive(player) then
			return
		end
		active = tool
		gui.Enabled = true
		refreshPanel()
		bindControls(true)
		renderConnection = RunService.RenderStepped:Connect(update)
		activatedConnection = tool.Activated:Connect(function()
			if placement and placementValid then
				BodyAnimations.play("Hammer")
				Remotes.Build:FireServer(ids[selected], placement.Position, rotation)
			end
		end)
	end

	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("BuildTool") == true then
				enterBuildMode(child)
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child == active then
				exitBuildMode()
			end
		end)
	end
	player.CharacterAdded:Connect(function(character)
		exitBuildMode()
		watchCharacter(character)
	end)
	if player.Character then
		watchCharacter(player.Character)
	end

	player.AttributeChanged:Connect(function()
		if active then
			refreshPanel()
		end
	end)
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(function()
		if not LifeState.isAlive(player) then
			exitBuildMode()
		end
	end)
end

return BuildController
