--!strict
-- Modo construcción (Fase 2.2): se activa al equipar el martillo.
--   - Panel a la derecha con las piezas y su coste; la elegida se ve como vista previa transparente
--     (verde si se puede poner, roja si no).
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
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local ActionButtons = require(script.Parent.Parent.ActionButtons)
local BodyAnimations = require(script.Parent.Parent.BodyAnimations)

local ROTATE_ACTION = "BuildRotate"
local NEXT_ACTION = "BuildNext"
local DEMOLISH_ACTION = "BuildDemolish"
local AIM_DISTANCE = 80
local VALID_COLOR = Color3.fromRGB(90, 230, 110)
local INVALID_COLOR = Color3.fromRGB(240, 70, 60)
local SELECTED_COLOR = Color3.fromRGB(242, 178, 36)
local IDLE_COLOR = Color3.fromRGB(45, 38, 30)

local BuildController = {}

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

	-- Panel de piezas.
	local gui = Widgets.screen("BuildHUD", player:WaitForChild("PlayerGui"))
	gui.Enabled = false
	local panel = Instance.new("Frame")
	panel.Name = "Pieces"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	panel.Size = UDim2.fromOffset(230, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundTransparency = 1
	panel.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	local buttons: { TextButton } = {}
	for index, id in ids do
		local button = Instance.new("TextButton")
		button.Name = id
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(230, 54)
		button.BackgroundColor3 = IDLE_COLOR
		button.BackgroundTransparency = 0.15
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.BuilderSansBold
		button.TextScaled = true
		button.RichText = true
		button.Parent = panel
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = button
		button.MouseButton1Click:Connect(function()
			selected = index
		end)
		buttons[index] = button
	end

	local hint = Widgets.label("", gui)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -100)
	hint.Size = UDim2.fromScale(0.6, 0.04)

	local function refreshPanel()
		for index, id in ids do
			local definition = Buildables[id]
			buttons[index].Text = `{definition.icon} {definition.name}\n{costText(player, definition)}`
			buttons[index].BackgroundColor3 = if index == selected then SELECTED_COLOR else IDLE_COLOR
		end
		local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		hint.Text = if touch
			then "Toca para colocar · Girar · Pieza · Quitar"
			else "Clic: colocar · R: girar · T: cambiar pieza · F: quitar una pieza tuya"
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
		bind(ROTATE_ACTION, "Girar", function()
			rotation = (rotation + 1) % 4
		end, Enum.KeyCode.R, Enum.KeyCode.DPadRight)
		bind(NEXT_ACTION, "Pieza", function()
			selected = selected % #ids + 1
			refreshPanel()
		end, Enum.KeyCode.T, Enum.KeyCode.ButtonL1)
		bind(DEMOLISH_ACTION, "Quitar", function()
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
