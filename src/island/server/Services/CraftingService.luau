--!strict
-- Estaciones de crafteo y recetas (GDD §9.3; Fases 1.6 y 2.1): mesa de trabajo y hoguera.
--   - Busca en el mapa las estaciones marcadas con el atributo "CraftingStation" (ver Data/Stations).
--     Si falta la mesa, crea una en el Basecamp (Config.Crafting.DefaultWorkbenchOffset). Si falta la
--     hoguera, usa el modelo "Hoguera" que genera MapBuilder o crea una sencilla.
--   - El aviso de cada estación abre su pantalla de recetas en el cliente (CraftingController).
--   - El servidor valida cada fabricación: vivo, cerca de su estación, materiales y que no la tenga ya.
--   - Las herramientas fabricadas van a StarterGear: no se pierden al reaparecer.
--   - Una mejora (receta con "upgrades") sustituye a la herramienta vieja, también si está en la mano.
--     No se saltan niveles: hace falta tener la anterior (Crafting.missingPrerequisite).
--   - Las estaciones construidas con el martillo (taller del curandero, forja) se activan al momento.
--   - También gestiona la armadura y el uso de curaciones (vendas, ungüentos, antídotos y la
--     cataplasma de grupo del médico).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Armor = require(ReplicatedStorage.Shared.Data.Armor)
local Basecamp = require(ReplicatedStorage.Shared.Basecamp)
local Building = require(ReplicatedStorage.Shared.Building)
local Config = require(ReplicatedStorage.Shared.Config)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Stations = require(ReplicatedStorage.Shared.Data.Stations)
local Survival = require(ReplicatedStorage.Shared.Survival)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local Retention = require(ServerScriptService.ServerShared.Retention)
local BasecampService = require(script.Parent.BasecampService)
local CombatService = require(script.Parent.CombatService)
local InventoryService = require(script.Parent.InventoryService)
local AbilityFx = require(script.Parent.Parent.Combat.AbilityFx)
local ArmorModels = require(script.Parent.Parent.Combat.ArmorModels)
local CombatText = require(script.Parent.Parent.Combat.CombatText)

local PROMPT_NAME = "StationPrompt"
-- Nombre del modelo de hoguera que crea MapBuilder en mapas generados antes de la Fase 2.1.
local MAP_CAMPFIRE_NAME = "Hoguera"
-- Margen extra (studs) sobre la distancia de uso, por el retraso de la red.
local DISTANCE_TOLERANCE = 4
local WOOD = Color3.fromRGB(125, 85, 50)
local DARK_WOOD = Color3.fromRGB(85, 55, 32)

local CraftingService = {}

type Station = { stationId: string, anchor: BasePart }

local stations: { Station } = {}
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

-- Suelo del Basecamp desplazado "offset" respecto a su centro.
local function groundNearCenter(offset: Vector3): Vector3
	local center = BasecampService.getCenter()
	local spot = center + offset
	local hit = Workspace:Raycast(Vector3.new(spot.X, center.Y + 60, spot.Z), Vector3.new(0, -300, 0))
	return if hit then hit.Position else Vector3.new(spot.X, 0, spot.Z)
end

-- Cartel flotante con el nombre de la estación.
local function addSign(stationId: string, part: BasePart)
	local station = Stations[stationId]
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromOffset(200, 40)
	sign.StudsOffset = Vector3.new(0, 4, 0)
	sign.MaxDistance = 80
	sign.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = `{station.icon} {station.name}`
	label.TextColor3 = Color3.fromRGB(255, 220, 140)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Parent = sign
end

-- Mesa de troncos con herramientas encima y un cartel flotante. Mira hacia el centro del Basecamp.
local function buildWorkbench(): Model
	local center = BasecampService.getCenter()
	local ground = groundNearCenter(Config.Crafting.DefaultWorkbenchOffset)
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
	model:SetAttribute(Config.Crafting.StationAttribute, "Workbench")
	addSign("Workbench", top)
	model.Parent = Workspace
	return model
end

-- Hoguera sencilla (troncos, piedras, fuego y luz) para mapas que no tengan una.
local function buildCampfire(): Model
	local ground = groundNearCenter(Config.Crafting.DefaultCampfireOffset)
	local model = Instance.new("Model")
	model.Name = MAP_CAMPFIRE_NAME
	local first: Part? = nil
	for i = 0, 3 do
		local log = newPart(
			"Log",
			Vector3.new(6, 1.2, 1.2),
			CFrame.new(ground + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, i * math.pi / 4, 0),
			DARK_WOOD,
			model
		)
		first = first or log
	end
	for i = 0, 7 do
		local angle = i * math.pi / 4
		local stone = newPart(
			"Stone",
			Vector3.new(1.4, 1, 1.4),
			CFrame.new(ground + Vector3.new(math.cos(angle) * 4, 0.5, math.sin(angle) * 4)),
			Color3.fromRGB(110, 110, 115),
			model
		)
		stone.Material = Enum.Material.Slate
	end
	local main = first :: Part
	local fire = Instance.new("Fire")
	fire.Size = 7
	fire.Heat = 9
	fire.Parent = main
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 40
	light.Brightness = 2
	light.Parent = main
	model.PrimaryPart = main
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

-- El aviso lleva el atributo "StationId": el cliente sabe qué recetas mostrar.
local function addStation(stationId: string, instance: Instance)
	local anchor = anchorOf(instance)
	local station = Stations[stationId]
	if not (anchor and station) then
		warn(`[CraftingService] {instance:GetFullName()}: estación "{stationId}" no válida o sin piezas.`)
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = station.actionText
	prompt.ObjectText = station.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Crafting.UseDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("StationId", stationId)
	prompt.Parent = anchor
	table.insert(stations, { stationId = stationId, anchor = anchor })
end

-- Quita las estaciones de una pieza derribada o rota.
local function removeStationsIn(instance: Instance)
	for index = #stations, 1, -1 do
		if stations[index].anchor:IsDescendantOf(instance) then
			table.remove(stations, index)
		end
	end
end

local function hasStation(stationId: string): boolean
	for _, station in stations do
		if station.stationId == stationId then
			return true
		end
	end
	return false
end

local function isNearStation(player: Player, stationId: string): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return false
	end
	for _, station in stations do
		local distance = (station.anchor.Position - root.Position).Magnitude
		if station.stationId == stationId and distance <= Config.Crafting.UseDistance + DISTANCE_TOLERANCE then
			return true
		end
	end
	return false
end

-- Piezas soldadas al torso, la cintura, los brazos y los muslos (R15 o R6). Se vuelve a poner en
-- cada reaparición.
-- Viste la armadura del jugador (Combat/ArmorModels); una nueva sustituye a la anterior.
local function wearArmor(player: Player, character: Model)
	local armorId = player:GetAttribute("Armor")
	if typeof(armorId) ~= "string" or not Armor[armorId] then
		return
	end
	-- Espera al torso (R15 o R6) antes de vestir.
	if not (character:WaitForChild("UpperTorso", 5) or character:FindFirstChild("Torso")) then
		return
	end
	ArmorModels.wear(character, armorId, player:GetAttribute("Role"))
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

local recipeOfGear = Crafting.recipeOfGear

-- Todo lo que sustituye una mejora: lo de "upgrades" y lo anterior de la cadena (hacha de hueso →
-- de piedra → de madera; armadura de plata → de hueso → chaleco).
local function replacedBy(recipe: Recipes.Recipe): { string }
	local replaced = {}
	local gearId = recipe.upgrades
	while gearId and not table.find(replaced, gearId) do
		table.insert(replaced, gearId)
		local previous = recipeOfGear[gearId]
		gearId = if previous then Recipes[previous].upgrades else nil
	end
	return replaced
end

-- Las recetas de las versiones viejas quedan como hechas: no tiene sentido volver atrás (ni ponerse
-- el chaleco encima de la armadura de plata).
local function markReplacedOwned(player: Player, recipe: Recipes.Recipe)
	for _, gearId in replacedBy(recipe) do
		local previous = recipeOfGear[gearId]
		if previous then
			player:SetAttribute(Crafting.ownedAttribute(previous), true)
		end
	end
end

local function grant(player: Player, recipeId: string, recipe: Recipes.Recipe)
	if recipe.weaponId then
		local wasEquipped = false
		for _, weaponId in replacedBy(recipe) do
			wasEquipped = removeWeapon(player, weaponId) or wasEquipped
		end
		markReplacedOwned(player, recipe)
		local tool = WeaponTools.build(recipe.weaponId)
		-- La mejora de un arma de rol sigue siendo del rol: si cambia (panel de pruebas), se va con él.
		if recipe.role then
			tool:SetAttribute("RoleWeapon", true)
		end
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
		markReplacedOwned(player, recipe)
		player:SetAttribute("Armor", recipe.armorId)
		if player.Character then
			task.spawn(wearArmor, player, player.Character)
		end
	elseif recipe.offhand then
		-- La antorcha va a la Bolsa; de noche TorchService la pone en la mano izquierda.
		InventoryService.add(player, recipe.offhand, 1)
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
	if not LifeState.isAlive(player) or not isNearStation(player, recipe.station) then
		return
	end
	if not Crafting.isForRole(player, recipe) then
		return
	end
	-- Con el campamento caído las estaciones no funcionan hasta que se recupere de día.
	if Basecamp.isFallen() then
		Remotes.Notify:FireClient(
			player,
			"🔥 El campamento ha caído: las estaciones no funcionan hasta que se recupere"
		)
		return
	end
	if Crafting.isUnique(recipe) and Crafting.isOwned(player, recipeId) then
		Remotes.Notify:FireClient(player, `Ya tienes: {recipe.name}`)
		return
	end
	-- Las mejoras no se saltan: hace falta la anterior de la cadena.
	local missing = Crafting.missingPrerequisite(player, recipe)
	if missing then
		Remotes.Notify:FireClient(player, `🔒 Primero fabrica: {missing}`)
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
	local character = player.Character
	if character then
		Sfx.play("Craft", character:GetPivot().Position)
	end
	local verb = if recipe.upgrades then "mejorado" else "fabricado"
	Remotes.Notify:FireClient(player, `Has {verb}: {recipe.icon} {Crafting.recipeName(player, recipe)}`)
	Retention.progress(player, "Craft")
end

-- La curación que mejor encaja: la más pequeña que cubre la vida que falta, o si ninguna llega,
-- la más grande. Así no se gasta un ungüento para 5 puntos de vida.
local function bestHealItem(player: Player, missing: number): string?
	local bestId: string? = nil
	local bestHeal = 0
	for itemId, item in Items do
		local heal = item.heal
		if heal and Inventory.count(player, itemId) > 0 then
			local covers = heal >= missing
			local bestCovers = bestHeal >= missing
			local better = if covers and bestCovers then heal < bestHeal else heal > bestHeal
			if bestId == nil or better then
				bestId = itemId
				bestHeal = heal
			end
		end
	end
	return bestId
end

local function useAntidote(player: Player)
	if InventoryService.remove(player, "Antidote", 1) then
		player:SetAttribute(Survival.FEVER, 0)
		Remotes.Notify:FireClient(player, "💉 La fiebre ha bajado")
	end
end

local function useHealItem(player: Player, humanoid: Humanoid, itemId: string)
	local heal = Items[itemId].heal
	if not heal or not InventoryService.remove(player, itemId, 1) then
		return
	end
	-- Vendas y ungüentos nunca son críticos.
	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, before + heal * Progression.perk(player, "HealPower"))
	CombatText.heal(player, humanoid.Health - before, false, player)
	Sfx.play("Heal", humanoid.Parent or player)
end

-- Una curación de grupo ("groupHeal", la cataplasma del médico) que lleve "player", o nil.
local function groupHealItem(player: Player): string?
	for itemId, item in Items do
		if item.groupHeal and Inventory.count(player, itemId) > 0 then
			return itemId
		end
	end
	return nil
end

-- Aliados vivos (sin contar a "player") a menos de Config.Crafting.PoulticeRadius de "center".
local function alliesAround(player: Player, center: Vector3): { Player }
	local found = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if
			other ~= player
			and LifeState.isAlive(other)
			and root
			and root:IsA("BasePart")
			and (root.Position - center).Magnitude <= Config.Crafting.PoulticeRadius
		then
			table.insert(found, other)
		end
	end
	return found
end

local function isWounded(player: Player): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil
		and humanoid.Health > 0
		and humanoid.MaxHealth - humanoid.Health >= Config.Crafting.PoulticeWoundedMissing
end

-- Cataplasma de grupo: cura a "player" y a los aliados de alrededor. Cuenta como curación del médico
-- (botín compartido, Savia protectora), pero, como las vendas, nunca es crítica.
local function usePoultice(player: Player, root: BasePart, itemId: string)
	local heal = Items[itemId].groupHeal
	if not heal or not InventoryService.remove(player, itemId, 1) then
		return
	end
	local amount = heal * Progression.perk(player, "HealPower")
	CombatService.heal(player, amount, player)
	local healed = 0
	for _, ally in alliesAround(player, root.Position) do
		if CombatService.heal(ally, amount, player) > 0 then
			healed += 1
		end
	end
	AbilityFx.all("AreaHeal", root.Position, Config.Crafting.PoulticeRadius)
	Sfx.play("Heal", root)
	Remotes.Notify:FireClient(
		player,
		`{Items[itemId].icon} Cataplasma: te has curado y has curado a {healed} aliado(s)`
	)
end

-- Curar (H) elige qué usar. Con aliados heridos cerca, la cataplasma de grupo va antes que nada. Luego
-- la vida: por debajo de Config.Survival.HealFirstBelow se usa una venda o un ungüento aunque haya
-- fiebre, para no caer por quitarse la fiebre. Con la vida bien, la fiebre con síntomas
-- (Config.Fever.SymptomsAt) se quita con el antídoto; si no, se cura la vida que falte y, con la vida
-- llena, el antídoto quita la fiebre que quede. Sin otra cosa para la vida, la cataplasma cura solo
-- a quien la usa.
local function onUseHeal(player: Player)
	if not LifeState.isAlive(player) or not canBandage(player) then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local poulticeId = groupHealItem(player)
	if poulticeId and root and root:IsA("BasePart") then
		for _, ally in alliesAround(player, root.Position) do
			if isWounded(ally) then
				usePoultice(player, root, poulticeId)
				return
			end
		end
	end
	local missing = humanoid.MaxHealth - humanoid.Health
	local healId = if missing > 0 then bestHealItem(player, missing) else nil
	local fever = Survival.fever(player)
	local hasAntidote = fever > 0 and Inventory.count(player, "Antidote") > 0
	local lowHealth = humanoid.Health < humanoid.MaxHealth * Config.Survival.HealFirstBelow
	local feverFirst = hasAntidote and fever >= Config.Fever.SymptomsAt
	if healId and (lowHealth or not feverFirst) then
		useHealItem(player, humanoid, healId)
	elseif hasAntidote then
		useAntidote(player)
	elseif missing > 0 and poulticeId and root and root:IsA("BasePart") then
		usePoultice(player, root, poulticeId)
	elseif missing > 0 then
		Remotes.Notify:FireClient(player, "No tienes con qué curarte: vendas o ungüentos")
	end
end

function CraftingService:Start()
	Remotes.Craft.OnServerEvent:Connect(onCraft)
	Remotes.UseBandage.OnServerEvent:Connect(onUseHeal)

	for _, instance in Workspace:GetDescendants() do
		local stationId = instance:GetAttribute(Config.Crafting.StationAttribute)
		if typeof(stationId) == "string" then
			addStation(stationId, instance)
		end
	end
	if not hasStation("Workbench") then
		addStation("Workbench", buildWorkbench())
	end
	if not hasStation("Campfire") then
		local mapCampfire = Workspace:FindFirstChild(MAP_CAMPFIRE_NAME, true)
		addStation("Campfire", if mapCampfire then mapCampfire else buildCampfire())
	end
	print(`[CraftingService] {#stations} estaciones de crafteo listas.`)

	-- Estaciones construidas durante la partida (BuildingService).
	task.spawn(function()
		local folder = Workspace:WaitForChild(Building.STRUCTURES_FOLDER)
		folder.ChildAdded:Connect(function(child)
			local stationId = child:GetAttribute(Config.Crafting.StationAttribute)
			if typeof(stationId) == "string" then
				addStation(stationId, child)
			end
		end)
		folder.ChildRemoved:Connect(removeStationsIn)
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			wearArmor(player, character)
		end)
		-- Si cambia el rol (panel de pruebas), sus armas vuelven a las de base: las mejoras de rol
		-- dejan de contar como fabricadas. La armadura pasa a la del aspecto del rol nuevo.
		player:GetAttributeChangedSignal("Role"):Connect(function()
			for recipeId, recipe in Recipes do
				if recipe.role then
					player:SetAttribute(Crafting.ownedAttribute(recipeId), nil)
				end
			end
			if player.Character then
				task.spawn(wearArmor, player, player.Character)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CraftingService
