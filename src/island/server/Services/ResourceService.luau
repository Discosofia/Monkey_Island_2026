--!strict
-- Puntos de recolección de la isla: árboles, rocas, arbustos, helechos y matas de banano y
-- plátano (GDD §7). Cualquier Model o Part del mapa con el atributo "ResourceNode" (un tipo de
-- Data/ResourceNodes) se convierte en un punto de recolección (ver docs/MAPA.md). Dos formas:
--   - Árboles y rocas: se golpean con el hacha o el pico equipados (CombatService llama a strike).
--     Una barra muestra el progreso; la herramienta mejor necesita menos golpes y da más.
--   - Arbustos, helechos y matas: se mantiene pulsado el aviso (E en PC, tocar en móvil).
-- Tras varios usos el punto se agota y reaparece pasado un tiempo. Si el modelo tiene una carpeta
-- "Cosecha" (NodeModels.HARVEST_FOLDER), solo desaparece ella: la mata se queda sin su racimo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local ResourceNodes = require(ReplicatedStorage.Shared.Data.ResourceNodes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local NodeModels = require(ServerScriptService.ServerShared.NodeModels)
local InventoryService = require(script.Parent.InventoryService)

-- Margen extra (studs) sobre la distancia del aviso, por el retraso de la red.
local DISTANCE_TOLERANCE = 4
-- Nodos de prueba alrededor del Basecamp si el mapa no tiene ninguno.
local TEST_NODE_TYPES = {
	"Tree",
	"Rock",
	"Bush",
	"BananaPlant",
	"Tree",
	"Bush",
	"Tree",
	"Rock",
	"PlantainPlant",
	"Bush",
	"Tree",
	"Rock",
	"Bush",
	"Tree",
}

-- Caída de un árbol talado: duración y ángulo final.
local FALL_SECONDS = 1.2
local FALL_DEGREES = 85

-- Los golpes deben venir de delante del jugador (coseno del ángulo máximo, unos 70°).
local FACING_DOT = 0.35

type NodeState = {
	instance: Instance,
	definition: ResourceNodes.NodeDefinition,
	anchor: BasePart,
	prompt: ProximityPrompt?,
	usesLeft: number,
	progress: number,
	progressBar: BillboardGui?,
	lastStrikeAt: number,
}

local ResourceService = {}

local lastHarvestAt: { [Player]: number } = {}
local toolNodes: { NodeState } = {}

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

-- Guarda cómo era la pieza la primera vez, para poder restaurarla al reaparecer.
local function remember(part: BasePart)
	if part:GetAttribute("OriginalTransparency") == nil then
		part:SetAttribute("OriginalTransparency", part.Transparency)
		part:SetAttribute("OriginalCanCollide", part.CanCollide)
	end
end

-- Oculta o muestra un nodo agotado.
local function setVisible(instance: Instance, visible: boolean)
	for _, part in partsOf(instance) do
		remember(part)
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
	if state.usesLeft <= 0 or not LifeState.isAlive(player) then
		return false
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local distance = (root.Position - state.anchor.Position).Magnitude
	if distance > Config.Resources.HarvestDistance + DISTANCE_TOLERANCE then
		return false
	end

	-- Evita recolectar más rápido de lo que permite mantener pulsado (clientes modificados).
	local now = os.clock()
	local last = lastHarvestAt[player]
	-- Con la mejora "Manos ágiles" se mantiene menos tiempo (su cliente acorta el aviso): se respeta aquí.
	local holdSeconds = (state.definition.holdSeconds or 0) * Progression.perk(player, "HarvestSpeed")
	if last and now - last < holdSeconds * 0.8 then
		return false
	end
	lastHarvestAt[player] = now
	return true
end

-- El árbol cae girando sobre su base, hacia el lado contrario a "awayFrom", y luego desaparece.
-- Al terminar vuelve (invisible) a su sitio para reaparecer de pie.
local function fall(model: Model, awayFrom: Vector3, onDone: () -> ())
	local pivot = model:GetPivot()
	local boxCFrame, boxSize = model:GetBoundingBox()
	local ground = Vector3.new(pivot.Position.X, boxCFrame.Position.Y - boxSize.Y / 2, pivot.Position.Z)
	local direction = (pivot.Position - awayFrom) * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.1 then
		direction = Vector3.xAxis
	end
	-- Girar alrededor de (arriba × dirección) inclina la copa hacia "direction".
	local unit = direction.Unit
	local axis = Vector3.new(unit.Z, 0, -unit.X)

	for _, part in partsOf(model) do
		remember(part)
		part.CanCollide = false
	end
	local angle = Instance.new("NumberValue")
	angle.Changed:Connect(function(degrees: number)
		local rotation = CFrame.fromAxisAngle(axis, math.rad(degrees))
		model:PivotTo(CFrame.new(ground) * rotation * CFrame.new(-ground) * pivot)
	end)
	local tween = TweenService:Create(
		angle,
		TweenInfo.new(FALL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = FALL_DEGREES }
	)
	tween.Completed:Connect(function()
		task.wait(0.4)
		angle:Destroy()
		onDone()
		model:PivotTo(pivot)
	end)
	tween:Play()
end

local rng = Random.new()

-- Lo que desaparece al agotarse: la cosecha (el racimo de una mata) si el modelo la tiene; si no, todo.
local function depletedPartOf(instance: Instance): Instance
	return instance:FindFirstChild(NodeModels.HARVEST_FOLDER) or instance
end

-- Da el material (y a veces un extra, como bananos de los arbustos) y, si el punto se agota,
-- lo oculta hasta que reaparece.
local function collect(state: NodeState, player: Player, amount: number)
	-- Material extra de las mejoras de la tienda y de la mascota.
	amount += math.floor(Progression.perk(player, "HarvestBonus"))
	InventoryService.collect(player, state.definition.itemId, amount)
	Sfx.play("Pickup", state.anchor)
	local extra = state.definition.extra
	if extra and rng:NextNumber() < extra.chance then
		InventoryService.collect(player, extra.itemId, extra.amount)
	end
	state.usesLeft -= 1
	if state.usesLeft > 0 then
		return
	end

	state.progress = 0
	if state.prompt then
		state.prompt.Enabled = false
	end
	if state.progressBar then
		state.progressBar.Parent = nil
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	Sfx.play(if state.definition.falls then "TreeFall" else "RockBreak", state.anchor.Position)
	local hidden = depletedPartOf(state.instance)
	if state.definition.falls and state.instance:IsA("Model") and root and root:IsA("BasePart") then
		fall(state.instance, root.Position, function()
			setVisible(hidden, false)
		end)
	else
		setVisible(hidden, false)
	end
	task.delay(state.definition.respawnSeconds, function()
		state.usesLeft = state.definition.uses
		setVisible(hidden, true)
		if state.prompt then
			state.prompt.Enabled = true
		end
	end)
end

local function harvest(state: NodeState, player: Player)
	if canHarvest(state, player) then
		collect(state, player, state.definition.amount)
	end
end

-- Barra de progreso sobre el árbol o la roca. Se oculta sola tras unos segundos sin golpes.
local function newProgressBar(): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HarvestProgress"
	billboard.Size = UDim2.fromOffset(110, 12)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	back.BackgroundTransparency = 0.3
	back.Parent = billboard
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(242, 178, 36)
	fill.BorderSizePixel = 0
	fill.Parent = back
	return billboard
end

local function showProgress(state: NodeState)
	local billboard = state.progressBar or newProgressBar()
	state.progressBar = billboard
	local fill = (billboard :: any).Back.Fill :: Frame
	fill.Size = UDim2.fromScale(math.clamp(state.progress / (state.definition.toughness or 1), 0, 1), 1)
	billboard.Parent = state.anchor

	local strikeAt = state.lastStrikeAt
	task.delay(Config.Resources.ProgressBarSeconds, function()
		if state.lastStrikeAt == strikeAt then
			billboard.Parent = nil
		end
	end)
end

-- Distancia horizontal desde una posición hasta la superficie de la pieza (0 si está encima).
local function surfaceOffset(part: BasePart, position: Vector3): Vector3
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	local closest = Vector3.new(
		math.clamp(localPosition.X, -half.X, half.X),
		math.clamp(localPosition.Y, -half.Y, half.Y),
		math.clamp(localPosition.Z, -half.Z, half.Z)
	)
	local offset = part.CFrame:PointToWorldSpace(closest) - position
	return Vector3.new(offset.X, 0, offset.Z)
end

-- Golpe con una herramienta equipada (hacha, pico). Lo llama CombatService al usar el arma.
-- Trabaja el árbol o la roca más cercano que el jugador tenga delante y al alcance.
function ResourceService.strike(player: Player, root: BasePart, tool: Weapons.ToolDefinition)
	if not LifeState.isAlive(player) then
		return
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local best: NodeState? = nil
	local bestDistance = Config.Resources.ToolReach
	for _, state in toolNodes do
		if state.definition.tool == tool.kind and state.usesLeft > 0 then
			local offset = surfaceOffset(state.anchor, root.Position)
			local distance = offset.Magnitude
			local facing = distance < 1.5 or look:Dot(offset.Unit) >= FACING_DOT
			if distance <= bestDistance and facing then
				best = state
				bestDistance = distance
			end
		end
	end
	local state = best
	if not state then
		return
	end

	state.lastStrikeAt = os.clock()
	Sfx.play(if tool.kind == "Axe" then "Chop" else "Mine", state.anchor)
	-- Potencia extra por las mejoras de la tienda ("Brazos fuertes").
	local power = tool.power + Progression.perk(player, "ToolPower")
	state.progress += power
	local toughness = state.definition.toughness or 1
	if state.progress >= toughness then
		state.progress -= toughness
		collect(state, player, state.definition.amount + tool.bonus)
	end
	if state.usesLeft > 0 then
		showProgress(state)
	end
end

local function register(instance: Instance): boolean
	local typeId = instance:GetAttribute(NodeModels.ATTRIBUTE)
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

	local state: NodeState = {
		instance = instance,
		definition = definition,
		anchor = anchor,
		prompt = nil,
		usesLeft = definition.uses,
		progress = 0,
		progressBar = nil,
		lastStrikeAt = 0,
	}
	if definition.tool then
		-- Árboles y rocas: sin aviso, se golpean con la herramienta.
		table.insert(toolNodes, state)
		return true
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HarvestPrompt"
	prompt.ActionText = definition.actionText
	prompt.ObjectText = definition.name
	prompt.HoldDuration = definition.holdSeconds or 1
	prompt.MaxActivationDistance = Config.Resources.HarvestDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	state.prompt = prompt
	prompt.Triggered:Connect(function(player: Player)
		harvest(state, player)
	end)
	return true
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
		local node = NodeModels.build(nodeType, ground)
		node.Parent = folder
		table.insert(nodes, node)
	end
	return nodes
end

-- Las palmeras de islas generadas antes de que fueran talables: se les añade el atributo aquí.
local function upgradeOldPalms()
	for _, instance in Workspace:GetDescendants() do
		if
			instance:IsA("Model")
			and instance.Name == NodeModels.PALM_NAME
			and instance:GetAttribute(NodeModels.ATTRIBUTE) == nil
		then
			local trunk = instance:FindFirstChild("Trunk")
			if trunk and trunk:IsA("BasePart") then
				-- El primer tramo del tronco: su base está medio tramo por debajo de su centro.
				local base = (trunk.CFrame * CFrame.new(0, -trunk.Size.Y / 2, 0)).Position
				NodeModels.makeHarvestable(instance, "Palm", base)
			end
		end
	end
end

function ResourceService:Start()
	Players.PlayerRemoving:Connect(function(player)
		lastHarvestAt[player] = nil
	end)
	upgradeOldPalms()

	local found = {}
	for _, instance in Workspace:GetDescendants() do
		if instance:GetAttribute(NodeModels.ATTRIBUTE) ~= nil then
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
