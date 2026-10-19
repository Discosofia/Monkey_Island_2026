--!strict
-- Construcción en el Basecamp (GDD §10, Fase 2.2).
--   - Cada jugador lleva un martillo. Con él coloca piezas (Data/Buildables) en la cuadrícula.
--   - Núcleo compartido: cualquiera construye; parcela personal: solo su dueño.
--   - Cada jugador recibe una parcela libre al entrar; al salir se libera y se derriba lo que tenía.
--   - Derribar: solo tus piezas; se devuelve parte del coste (Config.Building.RefundFraction).
--   - La cama marca dónde reapareces al volver de Espíritu (atributo "RespawnCFrame").
-- El servidor valida todo: zona, distancia, materiales, límites y que nada estorbe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local BuildModels = require(ReplicatedStorage.Shared.BuildModels)
local Buildables = require(ReplicatedStorage.Shared.Data.Buildables)
local Building = require(ReplicatedStorage.Shared.Building)
local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local BasecampService = require(script.Parent.BasecampService)
local InventoryService = require(script.Parent.InventoryService)

local SIGN_FREE = "Parcela libre"
local BORDER_COLOR = Color3.fromRGB(205, 175, 115)
-- Margen extra sobre el alcance, por el retraso de la red.
local REACH_TOLERANCE = 6

local BuildingService = {}

local center = Vector3.zero
local plots: { CFrame } = {}
local plotOwners: { [number]: Player } = {}
local plotSigns: { [number]: TextLabel } = {}
local structures: Folder? = nil
local hammerTemplate: Tool? = nil
local canBuild = RequestCooldown.new(Config.Building.BuildCooldownSeconds)

local function structureFolder(): Folder
	return structures :: Folder
end

-- Personajes de todos los jugadores: no cuentan como suelo.
local function characters(): { Instance }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function decorPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Wood
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

-- Borde en el suelo y un cartel con el nombre del dueño.
local function buildPlotMarker(index: number, plot: CFrame, parent: Instance)
	local groundY = Building.groundAt(plot.Position.X, plot.Position.Z, center.Y, characters()) or center.Y
	local base = plot - plot.Position + Vector3.new(plot.Position.X, groundY, plot.Position.Z)
	local half = Config.Building.PlotSize / 2
	local model = Instance.new("Model")
	model.Name = `Parcela{index}`
	for _, side in { -1, 1 } do
		decorPart(
			"Border",
			Vector3.new(Config.Building.PlotSize, 0.2, 0.3),
			base * CFrame.new(0, 0.1, side * half),
			BORDER_COLOR,
			model
		)
		decorPart(
			"Border",
			Vector3.new(0.3, 0.2, Config.Building.PlotSize),
			base * CFrame.new(side * half, 0.1, 0),
			BORDER_COLOR,
			model
		)
	end
	-- Cartel en el lado que mira al centro (la parcela mira hacia -Z).
	local post = decorPart("SignPost", Vector3.new(0.4, 3, 0.4), base * CFrame.new(0, 1.5, -half), BORDER_COLOR, model)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(180, 32)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance = 70
	billboard.Parent = post
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = SIGN_FREE
	label.TextColor3 = Color3.fromRGB(255, 235, 190)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Parent = billboard
	plotSigns[index] = label
	model.Parent = parent
end

local function buildHammer(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Martillo"
	tool.ToolTip = "Construir en el Basecamp"
	tool.CanBeDropped = false
	tool:SetAttribute("BuildTool", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 2.4, 0.3)
	handle.Color = Color3.fromRGB(110, 72, 40)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(0.5, 0.6, 1.3)
	head.Color = Color3.fromRGB(120, 120, 125)
	head.Material = Enum.Material.Slate
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 1.3, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = head
	head.Parent = tool
	tool.Grip = CFrame.new(0, -0.6, 0)
	return tool
end

local function giveHammer(player: Player)
	local starterGear = player:WaitForChild("StarterGear")
	local template = hammerTemplate :: Tool
	template:Clone().Parent = starterGear
	local backpack = player:FindFirstChildOfClass("Backpack")
	if player.Character and backpack then
		template:Clone().Parent = backpack
	end
end

local function ownedBy(player: Player, buildableId: string?): number
	local count = 0
	for _, model in structureFolder():GetChildren() do
		local mine = model:GetAttribute("OwnerUserId") == player.UserId
		if mine and (buildableId == nil or model:GetAttribute("BuildableId") == buildableId) then
			count += 1
		end
	end
	return count
end

local function plotIndexOf(player: Player): number?
	local value = player:GetAttribute(Building.PLOT_ATTRIBUTE)
	return if typeof(value) == "number" then value else nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function canAfford(player: Player, cost: { Buildables.Cost }): boolean
	for _, entry in cost do
		if Inventory.count(player, entry.itemId) < entry.amount then
			return false
		end
	end
	return true
end

local function onBuild(player: Player, buildableId: any, point: any, rotation: any)
	local definition = if typeof(buildableId) == "string" then Buildables[buildableId] else nil
	local validRotation = typeof(rotation) == "number" and rotation % 1 == 0 and rotation >= 0 and rotation <= 3
	if not definition or typeof(point) ~= "Vector3" or not validRotation or not canBuild(player) then
		return
	end
	local root = rootOf(player)
	if not root or not LifeState.isAlive(player) then
		return
	end
	if (root.Position - point).Magnitude > Config.Building.Reach + REACH_TOLERANCE then
		return
	end

	local ignore = characters()
	table.insert(ignore, structureFolder())
	local groundY = Building.groundAt(point.X, point.Z, root.Position.Y, ignore)
	if not groundY then
		return
	end
	local cframe = Building.placement(point, groundY, rotation, definition.size)
	local zone = Building.zoneFor(cframe, definition.size, plotIndexOf(player), center)
	if not zone or not definition.zones[zone] then
		local places = {}
		if definition.zones.Core then
			table.insert(places, "el núcleo")
		end
		if definition.zones.Plot then
			table.insert(places, "tu parcela")
		end
		if definition.zones.Perimeter then
			table.insert(places, "el perímetro y los portones")
		end
		Remotes.Notify:FireClient(player, `{definition.name}: solo en {table.concat(places, ", ")}`)
		return
	end
	if Building.isBlocked(cframe, definition.size, {}) then
		Remotes.Notify:FireClient(player, "Algo estorba en ese sitio")
		return
	end
	if ownedBy(player, nil) >= Config.Building.MaxStructuresPerPlayer then
		Remotes.Notify:FireClient(player, `Has llegado al límite de {Config.Building.MaxStructuresPerPlayer} piezas`)
		return
	end
	if definition.maxPerServer then
		local count = 0
		for _, model in structureFolder():GetChildren() do
			if model:GetAttribute("BuildableId") == buildableId then
				count += 1
			end
		end
		if count >= definition.maxPerServer then
			Remotes.Notify:FireClient(player, `Ya hay {definition.name} en el Basecamp`)
			return
		end
	end
	if definition.maxPerPlayer and ownedBy(player, buildableId) >= definition.maxPerPlayer then
		Remotes.Notify:FireClient(player, `Solo puedes tener {definition.maxPerPlayer}: {definition.name}`)
		return
	end
	if not canAfford(player, definition.cost) then
		Remotes.Notify:FireClient(player, `Te faltan materiales para: {definition.name}`)
		return
	end
	for _, entry in definition.cost do
		InventoryService.remove(player, entry.itemId, entry.amount)
	end

	local model = BuildModels.build(buildableId)
	model:PivotTo(cframe)
	model:SetAttribute("BuildableId", buildableId)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	model:SetAttribute("Zone", zone)
	model:SetAttribute("Health", definition.health)
	model:SetAttribute("MaxHealth", definition.health)
	if definition.station then
		-- CraftingService ve la pieza nueva en la carpeta y le pone su aviso.
		model:SetAttribute(Config.Crafting.StationAttribute, definition.station)
	end
	model.Parent = structureFolder()
	Sfx.play("Build", cframe.Position)

	if buildableId == "Bed" then
		player:SetAttribute("RespawnCFrame", cframe * CFrame.new(0, 3, 0))
		Remotes.Notify:FireClient(player, "🛏️ Al volver de Espíritu reaparecerás en tu cama")
	end
end

local function removeStructure(model: Instance)
	if model:GetAttribute("BuildableId") == "Bed" then
		local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerUserId") :: number)
		if owner then
			owner:SetAttribute("RespawnCFrame", nil)
		end
	end
	model:Destroy()
end

local function onDemolish(player: Player, model: any)
	if typeof(model) ~= "Instance" or model.Parent ~= structureFolder() or not model:IsA("Model") then
		return
	end
	if model:GetAttribute("OwnerUserId") ~= player.UserId then
		Remotes.Notify:FireClient(player, `Esta pieza es de {model:GetAttribute("OwnerName") or "otro jugador"}`)
		return
	end
	local root = rootOf(player)
	if not root or not LifeState.isAlive(player) then
		return
	end
	if (root.Position - model:GetPivot().Position).Magnitude > Config.Building.Reach + REACH_TOLERANCE then
		return
	end
	local buildableId = model:GetAttribute("BuildableId")
	local definition = if typeof(buildableId) == "string" then Buildables[buildableId] else nil
	if definition then
		for _, entry in definition.cost do
			local refund = math.floor(entry.amount * Config.Building.RefundFraction)
			if refund > 0 and Items[entry.itemId] then
				InventoryService.add(player, entry.itemId, refund)
			end
		end
	end
	removeStructure(model)
end

local function assignPlot(player: Player)
	for index = 1, #plots do
		if not plotOwners[index] then
			plotOwners[index] = player
			player:SetAttribute(Building.PLOT_ATTRIBUTE, index)
			plotSigns[index].Text = `🏕️ {player.DisplayName}`
			return
		end
	end
end

local function releasePlayer(player: Player)
	for index, owner in plotOwners do
		if owner == player then
			plotOwners[index] = nil
			plotSigns[index].Text = SIGN_FREE
		end
	end
	-- Lo que tenía en su parcela se derriba; lo del núcleo se queda para el equipo.
	for _, model in structureFolder():GetChildren() do
		if model:GetAttribute("OwnerUserId") == player.UserId and model:GetAttribute("Zone") == "Plot" then
			model:Destroy()
		end
	end
end

-- Para el asedio (entrega 2.5) y otros sistemas: carpeta con todas las piezas construidas.
function BuildingService.getStructures(): Folder
	return structureFolder()
end

-- Sonido del golpe a una pieza, como mucho uno cada HIT_SOUND_INTERVAL por pieza: en el asedio
-- varios monos (y las estacas) la golpean a la vez y saturarían el audio.
local HIT_SOUND_INTERVAL = 0.3
local lastHitSound: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function playHitSound(model: Model)
	local now = os.clock()
	if now - (lastHitSound[model] or -math.huge) < HIT_SOUND_INTERVAL then
		return
	end
	lastHitSound[model] = now
	local buildableId = model:GetAttribute("BuildableId")
	local definition = if typeof(buildableId) == "string" then Buildables[buildableId] else nil
	local key = if definition and definition.hitSound then definition.hitSound else "StructureHit"
	Sfx.play(key, model:GetPivot().Position)
end

-- Daña una pieza; a 0 de vida se rompe. Devuelve true si se rompió.
function BuildingService.damageStructure(model: Model, amount: number): boolean
	local health = model:GetAttribute("Health")
	if typeof(health) ~= "number" or model.Parent ~= structures then
		return false
	end
	local remaining = health - amount
	if remaining <= 0 then
		Sfx.play("StructureBreak", model:GetPivot().Position)
		removeStructure(model)
		return true
	end
	model:SetAttribute("Health", remaining)
	playHitSound(model)
	-- Las que se desgastan a la vista (estacas) se van hundiendo: se ve cuánto les queda.
	local buildableId = model:GetAttribute("BuildableId")
	local definition = if typeof(buildableId) == "string" then Buildables[buildableId] else nil
	if definition and definition.sinkOnWear then
		local basePivot = model:GetAttribute("BasePivot")
		if typeof(basePivot) ~= "CFrame" then
			basePivot = model:GetPivot()
			model:SetAttribute("BasePivot", basePivot)
		end
		local maxHealth = model:GetAttribute("MaxHealth")
		local worn = 1 - remaining / (if typeof(maxHealth) == "number" then maxHealth else definition.health)
		model:PivotTo((basePivot :: CFrame) * CFrame.new(0, -worn * definition.size.Y * 0.7, 0))
	end
	return false
end

function BuildingService:Start()
	local zoneCenter = BasecampService.getCenter()
	local groundY = Building.groundAt(zoneCenter.X, zoneCenter.Z, zoneCenter.Y, {}) or zoneCenter.Y
	center = Vector3.new(zoneCenter.X, groundY, zoneCenter.Z)
	ReplicatedStorage:SetAttribute(Building.CENTER_ATTRIBUTE, center)

	local folder = Instance.new("Folder")
	folder.Name = Building.STRUCTURES_FOLDER
	folder.Parent = Workspace
	structures = folder

	local markers = Instance.new("Folder")
	markers.Name = "Parcelas"
	markers.Parent = Workspace
	plots = Building.plots(center)
	for index, plot in plots do
		buildPlotMarker(index, plot, markers)
	end

	hammerTemplate = buildHammer()
	Remotes.Build.OnServerEvent:Connect(onBuild)
	Remotes.Demolish.OnServerEvent:Connect(onDemolish)

	local function onPlayer(player: Player)
		assignPlot(player)
		giveHammer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(releasePlayer)
	print(`[BuildingService] {#plots} parcelas listas.`)
end

return BuildingService
