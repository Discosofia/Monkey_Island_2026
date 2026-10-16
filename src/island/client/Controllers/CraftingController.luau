--!strict
-- Pantalla de las estaciones de crafteo (Fases 1.6 y 2.1). Se abre con el aviso de la mesa de trabajo
-- ("Usar") o de la hoguera ("Cocinar") y muestra solo las recetas de esa estación.
-- Muestra cada receta con lo que cuesta (en verde lo que tienes, en rojo lo que falta) y un botón
-- para fabricarla. Las armas (no el hacha ni el pico) terminan la descripción con su probabilidad de
-- crítico (Shared/Crit); las mejoras, de cuánto a cuánto sube: "🎯 Crítico 10 → 15 %". Se cierra con el botón ✕, con B en mando o al alejarte de la mesa.
-- El servidor (CraftingService) decide si la fabricación vale.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local Crit = require(ReplicatedStorage.Shared.Crit)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stations = require(ReplicatedStorage.Shared.Data.Stations)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local BodyAnimations = require(script.Parent.Parent.BodyAnimations)

local PROMPT_NAME = "StationPrompt"
local CLOSE_ACTION = "CloseWorkbench"
-- Distancia extra sobre la de uso antes de cerrar la pantalla al alejarte.
local CLOSE_MARGIN = 6
local ROW_HEIGHT = 86
local HAVE_COLOR = "#a0f08c"
local MISSING_COLOR = "#ff8c78"
local CRIT_COLOR = "#ffdc5a"
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local BLOCKED_COLOR = Color3.fromRGB(90, 90, 90)

type Row = { recipeId: string, recipe: Recipes.Recipe, frame: Frame, cost: TextLabel, button: TextButton }

local CraftingController = {}

local function sortedRecipeIds(): { string }
	local ids = {}
	for id in Recipes do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Recipes[a].order < Recipes[b].order
	end)
	return ids
end

local function costText(player: Player, recipe: Recipes.Recipe): string
	local parts = {}
	for _, cost in recipe.cost do
		local have = Inventory.count(player, cost.itemId)
		local color = if have >= cost.amount then HAVE_COLOR else MISSING_COLOR
		table.insert(parts, `<font color="{color}">{Items[cost.itemId].icon} {cost.amount} ({have})</font>`)
	end
	return table.concat(parts, "   ")
end

-- " · 🎯 Crítico 15 %" (o "10 → 15 %" si mejora otra arma) para las armas; "" para lo demás.
local function critText(recipe: Recipes.Recipe): string
	local weapon = if recipe.weaponId then Weapons[recipe.weaponId] else nil
	if not weapon or weapon.tool then
		return ""
	end
	local chance = math.round(Crit.weaponChance(recipe.weaponId) * 100)
	local previous = if recipe.upgrades and Weapons[recipe.upgrades]
		then math.round(Crit.weaponChance(recipe.upgrades) * 100)
		else nil
	local value = if previous and previous ~= chance then `{previous} → {chance} %` else `{chance} %`
	return ` · <font color="{CRIT_COLOR}">🎯 Crítico {value}</font>`
end

-- La descripción con "{damage}" cambiado por el daño del arma que da la receta.
local function descriptionOf(recipe: Recipes.Recipe): string
	local weapon = if recipe.weaponId then Weapons[recipe.weaponId] else nil
	if not weapon then
		return recipe.description
	end
	local damage = math.round(weapon.damage * Config.Combat.PlayerDamageMultiplier)
	return (string.gsub(recipe.description, "{damage}", tostring(damage)))
end

local function newRow(recipeId: string, recipe: Recipes.Recipe, parent: Instance): Row
	local frame = Instance.new("Frame")
	frame.Name = recipeId
	frame.LayoutOrder = recipe.order
	frame.Size = UDim2.new(1, -10, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = Color3.fromRGB(45, 38, 30)
	frame.BackgroundTransparency = 0.2
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Widgets.label(`{recipe.icon} {recipe.name}`, frame)
	title.Position = UDim2.fromOffset(10, 6)
	title.Size = UDim2.new(0.66, -10, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local description = Widgets.label(`{descriptionOf(recipe)}{critText(recipe)}`, frame)
	description.RichText = true
	description.Position = UDim2.fromOffset(10, 34)
	description.Size = UDim2.new(0.66, -10, 0, 20)
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextColor3 = Color3.fromRGB(210, 200, 185)
	description.Font = Enum.Font.BuilderSans

	local cost = Widgets.label("", frame)
	cost.Position = UDim2.fromOffset(10, 56)
	cost.Size = UDim2.new(0.66, -10, 0, 24)
	cost.TextXAlignment = Enum.TextXAlignment.Left
	cost.RichText = true

	local button = Widgets.button("Fabricar", frame)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.new(0.32, -10, 0, 56)
	-- En esta lista el botón se adapta a la fila, sin el tamaño mínimo general.
	local sizeLimit = button:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit:Destroy()
	end
	button.MouseButton1Click:Connect(function()
		-- Activo solo si se puede fabricar (refreshRow): entonces se pone a trabajar con las manos.
		if button.Active then
			BodyAnimations.play("Craft")
		end
		Remotes.Craft:FireServer(recipeId)
	end)

	return { recipeId = recipeId, recipe = recipe, frame = frame, cost = cost, button = button }
end

local function refreshRow(player: Player, row: Row)
	row.cost.Text = costText(player, row.recipe)
	local owned = Crafting.isUnique(row.recipe) and Crafting.isOwned(player, row.recipeId)
	local ready = not owned and Crafting.canAfford(player, row.recipe)
	local action = if row.recipe.upgrades then "Mejorar" else "Fabricar"
	row.button.Text = if owned then "Ya la tienes" elseif ready then action else "Faltan"
	row.button.BackgroundColor3 = if ready then READY_COLOR else BLOCKED_COLOR
	row.button.TextColor3 = if ready then Color3.fromRGB(40, 25, 5) else Color3.fromRGB(200, 200, 200)
	row.button.Active = ready
	row.button.AutoButtonColor = ready
end

function CraftingController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("CraftingHUD", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 5

	local panel = Instance.new("Frame")
	panel.Name = "Workbench"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromScale(0.62, 0.78)
	panel.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(320, 240)
	sizeLimit.MaxSize = Vector2.new(640, 600)
	sizeLimit.Parent = panel

	local title = Widgets.label("", panel)
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -80, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = Widgets.button("✕", panel)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -8, 0, 6)
	closeButton.Size = UDim2.fromOffset(48, 40)
	local closeLimit = closeButton:FindFirstChildOfClass("UISizeConstraint")
	if closeLimit then
		closeLimit:Destroy()
	end

	local list = Instance.new("ScrollingFrame")
	list.Name = "Recipes"
	list.Position = UDim2.fromOffset(8, 52)
	list.Size = UDim2.new(1, -16, 1, -60)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	local rows: { Row } = {}
	for _, recipeId in sortedRecipeIds() do
		table.insert(rows, newRow(recipeId, Recipes[recipeId], list))
	end

	local station: BasePart? = nil

	local function refresh()
		if panel.Visible then
			for _, row in rows do
				refreshRow(player, row)
			end
		end
	end

	local function close()
		if not panel.Visible then
			return
		end
		panel.Visible = false
		station = nil
		ContextActionService:UnbindAction(CLOSE_ACTION)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then
			GuiService.SelectedObject = nil
		end
	end

	local function open(anchor: BasePart, id: string)
		local definition = Stations[id]
		if not definition then
			return
		end
		station = anchor
		title.Text = `{definition.icon} {definition.name}`
		local first: Row? = nil
		for _, row in rows do
			row.frame.Visible = row.recipe.station == id and Crafting.isForRole(player, row.recipe)
			if row.frame.Visible and not first then
				first = row
			end
		end
		panel.Visible = true
		refresh()
		-- B en mando cierra la pantalla (por encima de la esquiva mientras está abierta).
		ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
		if UserInputService.GamepadEnabled and first then
			GuiService.SelectedObject = first.button
		end
	end

	closeButton.MouseButton1Click:Connect(close)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local anchor = prompt.Parent
		local id = prompt:GetAttribute("StationId")
		local valid = prompt.Name == PROMPT_NAME and typeof(id) == "string"
		if valid and anchor and anchor:IsA("BasePart") and LifeState.isAlive(player) then
			open(anchor, id :: string)
		end
	end)

	-- Inventario, recetas fabricadas o estado de vida: cualquier atributo del jugador refresca.
	player.AttributeChanged:Connect(function(attribute: string)
		if attribute == LifeState.ATTRIBUTE and not LifeState.isAlive(player) then
			close()
		else
			refresh()
		end
	end)

	-- Cerrar al alejarse de la mesa.
	task.spawn(function()
		while gui.Parent do
			local anchor = station
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if anchor and panel.Visible then
				local far = not (root and root:IsA("BasePart"))
					or (anchor.Position - (root :: BasePart).Position).Magnitude
						> Config.Crafting.UseDistance + CLOSE_MARGIN
				if far then
					close()
				end
			end
			task.wait(0.3)
		end
	end)
end

return CraftingController
