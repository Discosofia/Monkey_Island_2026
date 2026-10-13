--!strict
-- Mesa de trabajo y recetas (GDD §9.3, Fase 1.6).
--   - Busca en el mapa las mesas marcadas con el atributo "CraftingStation" = "Workbench".
--     Si no hay ninguna, crea una en el Basecamp (Config.Crafting.DefaultWorkbenchOffset).
--   - El aviso "Usar" abre la pantalla de recetas en el cliente (CraftingController).
--   - El servidor valida cada fabricación: vivo, cerca de una mesa, materiales y que no la tenga ya.
--   - Las herramientas fabricadas van a StarterGear: no se pierden al reaparecer.
--   - Una mejora (receta con "upgrades") sustituye a la herramienta vieja, también si está en la mano.
--   - También gestiona el chaleco (armadura) y el uso de las vendas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Armor = require(ReplicatedStorage.Shared.Data.Armor)
local Config = require(ReplicatedStorage.Shared.Config)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local BasecampService = require(script.Parent.BasecampService)
local InventoryService = require(script.Parent.InventoryService)
local WeaponTools = require(script.Parent.Parent.Combat.WeaponTools)

local WORKBENCH = "Workbench"
local PROMPT_NAME = "WorkbenchPrompt"
-- Margen extra (studs) sobre la distancia de uso, por el retraso de la red.
local DISTANCE_TOLERANCE = 4
local WOOD = Color3.fromRGB(125, 85, 50)
local DARK_WOOD = Color3.fromRGB(85, 55, 32)

local CraftingService = {}

local stations: { BasePart } = {}
local canCraft = RequestCooldown.new(Config.Crafting.CraftCooldownSeconds)
local canBandage = RequestCooldown.new(Config.Crafting.BandageCooldownSeconds)

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Wood
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Mesa de troncos con herramientas encima y un cartel flotante. Mira hacia el centro del Basecamp.
local function buildWorkbench(): Model
	local center = BasecampService.getCenter()
	local spot = center + Config.Crafting.DefaultWorkbenchOffset
	local hit = Workspace:Raycast(Vector3.new(spot.X, center.Y + 60, spot.Z), Vector3.new(0, -300, 0))
	local ground = if hit then hit.Position else Vector3.new(spot.X, 0, spot.Z)
	local base = CFrame.lookAt(ground, Vector3.new(center.X, ground.Y, center.Z))

	local model = Instance.new("Model")
	model.Name = "Mesa de trabajo"
	local top = newPart("Top", Vector3.new(9, 0.8, 4.5), base * CFrame.new(0, 3.4, 0), WOOD, model)
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			newPart("Leg", Vector3.new(0.8, 3, 0.8), base * CFrame.new(x * 3.8, 1.5, z * 1.7), DARK_WOOD, model)
		end
	end
	newPart("Shelf", Vector3.new(8, 0.4, 3.5), base * CFrame.new(0, 1, 0), DARK_WOOD, model)
	-- Objetos sobre la mesa: un tronco, una piedra y un manojo de fibra.
	newPart("Log", Vector3.new(3, 1, 1), base * CFrame.new(-2.5, 4.3, 0.6), DARK_WOOD, model)
	local stone = newPart("Stone", Vector3.new(1.4, 0.9, 1.2), base * CFrame.new(1.2, 4.25, 0.8), WOOD, model)
	stone.Color = Color3.fromRGB(120, 120, 125)
	stone.Material = Enum.Material.Slate
	local fiber = newPart("Fiber", Vector3.new(1.6, 0.4, 1), base * CFrame.new(3, 4, -0.8), WOOD, model)
	fiber.Color = Color3.fromRGB(150, 135, 85)
	fiber.Material = Enum.Material.Fabric
	model.PrimaryPart = top
	model:SetAttribute(Config.Crafting.StationAttribute, WORKBENCH)

	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(200, 40)
	sign.StudsOffset = Vector3.new(0, 4, 0)
	sign.MaxDistance = 80
	sign.Parent = top
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "🔨 Mesa de trabajo"
	label.TextColor3 = Color3.fromRGB(255, 220, 140)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Parent = sign

	model.Parent = Workspace
	return model
end

local function anchorOf(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function addPrompt(anchor: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "Usar"
	prompt.ObjectText = "Mesa de trabajo"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Crafting.UseDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	table.insert(stations, anchor)
end

local function isNearStation(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return false
	end
	for _, anchor in stations do
		if (anchor.Position - root.Position).Magnitude <= Config.Crafting.UseDistance + DISTANCE_TOLERANCE then
			return true
		end
	end
	return false
end

-- Chaleco: una pieza soldada al torso (R15 o R6). Se vuelve a poner en cada reaparición.
local function wearArmor(player: Player, character: Model)
	local armorId = player:GetAttribute("Armor")
	local armor = if typeof(armorId) == "string" then Armor[armorId] else nil
	if not armor then
		return
	end
	local torso = character:WaitForChild("UpperTorso", 5) or character:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) or character:FindFirstChild("ArmorPiece") then
		return
	end
	local piece = Instance.new("Part")
	piece.Name = "ArmorPiece"
	piece.Size = torso.Size + Vector3.new(0.2, -0.1, 0.25)
	piece.CFrame = torso.CFrame
	piece.Color = armor.color
	piece.Material = armor.material
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = character
end

-- Quita una herramienta de la mochila, la mano y StarterGear. Devuelve true si estaba equipada.
local function removeWeapon(player: Player, weaponId: string): boolean
	local wasEquipped = false
	local backpack = player:FindFirstChildOfClass("Backpack")
	local starterGear = player:FindFirstChild("StarterGear")
	for _, container in { player.Character :: Instance?, backpack, starterGear } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("WeaponId") == weaponId then
					wasEquipped = wasEquipped or container == player.Character
					child:Destroy()
				end
			end
		end
	end
	return wasEquipped
end

local function grant(player: Player, recipeId: string, recipe: Recipes.Recipe)
	if recipe.weaponId then
		local wasEquipped = if recipe.upgrades then removeWeapon(player, recipe.upgrades) else false
		local tool = WeaponTools.build(recipe.weaponId)
		local starterGear = player:FindFirstChild("StarterGear")
		if starterGear then
			tool:Clone().Parent = starterGear
		end
		tool.Parent = player:FindFirstChildOfClass("Backpack")
		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		if wasEquipped and humanoid then
			humanoid:EquipTool(tool)
		end
	elseif recipe.armorId then
		player:SetAttribute("Armor", recipe.armorId)
		if player.Character then
			task.spawn(wearArmor, player, player.Character)
		end
	elseif recipe.itemId then
		InventoryService.add(player, recipe.itemId, recipe.amount or 1)
	end
	if Crafting.isUnique(recipe) then
		player:SetAttribute(Crafting.ownedAttribute(recipeId), true)
	end
end

local function onCraft(player: Player, recipeId: any)
	local recipe = if typeof(recipeId) == "string" then Recipes[recipeId] else nil
	if not recipe or not canCraft(player) then
		return
	end
	if not LifeState.isAlive(player) or not isNearStation(player) then
		return
	end
	if Crafting.isUnique(recipe) and Crafting.isOwned(player, recipeId) then
		Remotes.Notify:FireClient(player, `Ya tienes: {recipe.name}`)
		return
	end
	if not Crafting.canAfford(player, recipe) then
		Remotes.Notify:FireClient(player, `Te faltan materiales para: {recipe.name}`)
		return
	end
	-- Ya se comprobó que alcanza para todo: se gasta y se entrega.
	for _, cost in recipe.cost do
		InventoryService.remove(player, cost.itemId, cost.amount)
	end
	grant(player, recipeId, recipe)
	local verb = if recipe.upgrades then "mejorado" else "fabricado"
	Remotes.Notify:FireClient(player, `Has {verb}: {recipe.icon} {recipe.name}`)
end

local function onUseBandage(player: Player)
	if not LifeState.isAlive(player) then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or humanoid.Health >= humanoid.MaxHealth then
		return
	end
	if not canBandage(player) then
		return
	end
	if not InventoryService.remove(player, "Bandage", 1) then
		Remotes.Notify:FireClient(player, `No tienes {Items.Bandage.name}s: fabrícalas en la mesa de trabajo`)
		return
	end
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.Crafting.BandageHeal)
end

function CraftingService:Start()
	Remotes.Craft.OnServerEvent:Connect(onCraft)
	Remotes.UseBandage.OnServerEvent:Connect(onUseBandage)

	for _, instance in Workspace:GetDescendants() do
		if instance:GetAttribute(Config.Crafting.StationAttribute) == WORKBENCH then
			local anchor = anchorOf(instance)
			if anchor then
				addPrompt(anchor)
			end
		end
	end
	if #stations == 0 then
		local anchor = anchorOf(buildWorkbench())
		if anchor then
			addPrompt(anchor)
		end
	end
	print(`[CraftingService] {#stations} mesa(s) de trabajo listas.`)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			wearArmor(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CraftingService
