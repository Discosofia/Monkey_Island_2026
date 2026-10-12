--!strict
-- Puntos de recolección de la isla: árboles, rocas y arbustos (GDD §7, Fase 1.2).
-- Cualquier Model o Part del mapa con el atributo "ResourceNode" = "Tree" | "Rock" | "Bush"
-- se convierte en un punto de recolección (ver docs/MAPA.md). Se recolecta manteniendo pulsado
-- (E en PC, tocar en móvil). Tras varios usos se agota y reaparece pasado un tiempo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local ResourceNodes = require(ReplicatedStorage.Shared.Data.ResourceNodes)
local InventoryService = require(script.Parent.InventoryService)

local NODE_ATTRIBUTE = "ResourceNode"
-- Margen extra (studs) sobre la distancia del aviso, por el retraso de la red.
local DISTANCE_TOLERANCE = 4
-- Nodos de prueba alrededor del Basecamp si el mapa no tiene ninguno.
local TEST_NODE_TYPES =
	{ "Tree", "Rock", "Bush", "Tree", "Bush", "Tree", "Rock", "Bush", "Tree", "Rock", "Bush", "Tree" }

type NodeState = {
	instance: Instance,
	definition: ResourceNodes.NodeDefinition,
	prompt: ProximityPrompt,
	usesLeft: number,
}

local ResourceService = {}

local lastHarvestAt: { [Player]: number } = {}

local function partsOf(instance: Instance): { BasePart }
	local parts = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function anchorPartOf(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end
	if instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart
	end
	return instance:FindFirstChildWhichIsA("BasePart", true)
end

-- Oculta o muestra un nodo agotado. La primera vez guarda cómo era cada pieza para restaurarla.
local function setVisible(instance: Instance, visible: boolean)
	for _, part in partsOf(instance) do
		if part:GetAttribute("OriginalTransparency") == nil then
			part:SetAttribute("OriginalTransparency", part.Transparency)
			part:SetAttribute("OriginalCanCollide", part.CanCollide)
		end
		if visible then
			part.Transparency = part:GetAttribute("OriginalTransparency") :: number
			part.CanCollide = part:GetAttribute("OriginalCanCollide") :: boolean
		else
			part.Transparency = 1
			part.CanCollide = false
		end
	end
end

local function canHarvest(state: NodeState, player: Player): boolean
	if state.usesLeft <= 0 then
		return false
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local anchor = state.prompt.Parent
	if not (root and root:IsA("BasePart") and anchor and anchor:IsA("BasePart")) then
		return false
	end
	local distance = (root.Position - anchor.Position).Magnitude
	if distance > state.prompt.MaxActivationDistance + DISTANCE_TOLERANCE then
		return false
	end

	-- Evita recolectar más rápido de lo que permite mantener pulsado (clientes modificados).
	local now = os.clock()
	local last = lastHarvestAt[player]
	if last and now - last < state.definition.holdSeconds * 0.8 then
		return false
	end
	lastHarvestAt[player] = now
	return true
end

local function harvest(state: NodeState, player: Player)
	if not canHarvest(state, player) then
		return
	end

	InventoryService.add(player, state.definition.itemId, state.definition.amount)
	state.usesLeft -= 1
	if state.usesLeft > 0 then
		return
	end

	state.prompt.Enabled = false
	setVisible(state.instance, false)
	task.delay(state.definition.respawnSeconds, function()
		state.usesLeft = state.definition.uses
		setVisible(state.instance, true)
		state.prompt.Enabled = true
	end)
end

local function register(instance: Instance): boolean
	local typeId = instance:GetAttribute(NODE_ATTRIBUTE)
	local definition = if typeof(typeId) == "string" then ResourceNodes[typeId] else nil
	if not definition then
		warn(`[ResourceService] {instance:GetFullName()}: ResourceNode = "{typeId}" no es un tipo válido.`)
		return false
	end
	local anchor = anchorPartOf(instance)
	if not anchor then
		warn(`[ResourceService] {instance:GetFullName()} no tiene ninguna pieza (Part) para el aviso.`)
		return false
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HarvestPrompt"
	prompt.ActionText = definition.actionText
	prompt.ObjectText = definition.name
	prompt.HoldDuration = definition.holdSeconds
	prompt.MaxActivationDistance = Config.Resources.HarvestDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	local state: NodeState = {
		instance = instance,
		definition = definition,
		prompt = prompt,
		usesLeft = definition.uses,
	}
	prompt.Triggered:Connect(function(player: Player)
		harvest(state, player)
	end)
	return true
end

local function newPart(name: string, size: Vector3, color: Color3, shape: Enum.PartType, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = cframe
	return part
end

-- Modelos provisionales (greybox) para probar sin mapa.
local function buildTestNode(nodeType: string, ground: Vector3): Model
	local model = Instance.new("Model")
	model.Name = `Test{nodeType}`
	local main: Part
	if nodeType == "Tree" then
		main = newPart(
			"Trunk",
			Vector3.new(2, 12, 2),
			Color3.fromRGB(110, 75, 45),
			Enum.PartType.Block,
			CFrame.new(ground + Vector3.new(0, 6, 0))
		)
		local leaves = newPart(
			"Leaves",
			Vector3.new(9, 9, 9),
			Color3.fromRGB(60, 150, 70),
			Enum.PartType.Ball,
			CFrame.new(ground + Vector3.new(0, 13, 0))
		)
		leaves.Parent = model
	elseif nodeType == "Rock" then
		main = newPart(
			"Rock",
			Vector3.new(6, 4, 5),
			Color3.fromRGB(130, 130, 135),
			Enum.PartType.Block,
			CFrame.new(ground + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(25), 0)
		)
	else
		main = newPart(
			"Bush",
			Vector3.new(5, 5, 5),
			Color3.fromRGB(80, 170, 60),
			Enum.PartType.Ball,
			CFrame.new(ground + Vector3.new(0, 2, 0))
		)
	end
	main.Parent = model
	model.PrimaryPart = main
	model:SetAttribute(NODE_ATTRIBUTE, nodeType)
	return model
end

local function groundAt(x: number, z: number): Vector3
	local result = Workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -1000, 0))
	return Vector3.new(x, if result then result.Position.Y else 0, z)
end

local function spawnTestNodes(): { Instance }
	warn("[ResourceService] El mapa no tiene puntos de recolección: se crean unos de prueba alrededor del Basecamp.")
	local folder = Instance.new("Folder")
	folder.Name = "TestResourceNodes"
	folder.Parent = Workspace

	local center = Config.Basecamp.DefaultZoneCenter
	local nodes: { Instance } = {}
	for index, nodeType in TEST_NODE_TYPES do
		local angle = (index / #TEST_NODE_TYPES) * math.pi * 2
		-- Alterna dos distancias para que no queden todos en una línea perfecta.
		local radius = Config.Resources.TestNodeRingRadius + (if index % 2 == 0 then 15 else 0)
		local ground = groundAt(center.X + math.cos(angle) * radius, center.Z + math.sin(angle) * radius)
		local node = buildTestNode(nodeType, ground)
		node.Parent = folder
		table.insert(nodes, node)
	end
	return nodes
end

function ResourceService:Start()
	Players.PlayerRemoving:Connect(function(player)
		lastHarvestAt[player] = nil
	end)

	local found = {}
	for _, instance in Workspace:GetDescendants() do
		if instance:GetAttribute(NODE_ATTRIBUTE) ~= nil then
			table.insert(found, instance)
		end
	end
	if #found == 0 and Config.Resources.SpawnTestNodesIfNone then
		found = spawnTestNodes()
	end

	local count = 0
	for _, instance in found do
		if register(instance) then
			count += 1
		end
	end
	print(`[ResourceService] {count} puntos de recolección listos.`)
end

return ResourceService
