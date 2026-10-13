--!strict
-- Modelos provisionales (greybox) de los puntos de recolección: árbol, roca y arbusto.
-- Los usan ResourceService (nodos de prueba) y MapBuilder (isla generada).
-- Cuando tengas modelos definitivos, basta con ponerles el mismo atributo (ver docs/MAPA.md).

local NodeModels = {}

-- Atributo que convierte un Model o Part en punto de recolección.
NodeModels.ATTRIBUTE = "ResourceNode"

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

-- Convierte un modelo decorativo (por ejemplo, una palmera) en punto de recolección del tipo dado.
-- Pone un punto invisible a la altura del jugador sobre "base" (el pie del tronco): ahí se miden
-- el alcance del hacha y la barra de progreso.
function NodeModels.makeHarvestable(model: Model, nodeType: string, base: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "PromptAnchor"
	anchor.Size = Vector3.one
	anchor.Position = base + Vector3.new(0, 3, 0)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Parent = model
	model.PrimaryPart = anchor
	model:SetAttribute(NodeModels.ATTRIBUTE, nodeType)
end

-- Crea un modelo apoyado en "ground". Con rng, cada uno sale con tamaño y giro distintos.
function NodeModels.build(nodeType: string, ground: Vector3, rng: Random?): Model
	local scale = if rng then rng:NextNumber(0.85, 1.25) else 1
	local base = CFrame.new(ground) * CFrame.Angles(0, if rng then rng:NextNumber(0, math.pi * 2) else 0, 0)

	local model = Instance.new("Model")
	model.Name = nodeType
	local main: Part
	if nodeType == "Tree" then
		main = newPart(
			"Trunk",
			Vector3.new(2, 12, 2) * scale,
			Color3.fromRGB(110, 75, 45),
			Enum.PartType.Block,
			base * CFrame.new(0, 6 * scale, 0)
		)
		local leaves = newPart(
			"Leaves",
			Vector3.new(9, 9, 9) * scale,
			Color3.fromRGB(60, 150, 70),
			Enum.PartType.Ball,
			base * CFrame.new(0, 13 * scale, 0)
		)
		leaves.Parent = model
	elseif nodeType == "Rock" then
		main = newPart(
			"Rock",
			Vector3.new(6, 4, 5) * scale,
			Color3.fromRGB(130, 130, 135),
			Enum.PartType.Block,
			base * CFrame.new(0, 1.5 * scale, 0)
		)
	else
		main = newPart(
			"Bush",
			Vector3.new(5, 5, 5) * scale,
			Color3.fromRGB(80, 170, 60),
			Enum.PartType.Ball,
			base * CFrame.new(0, 2 * scale, 0)
		)
	end
	main.Parent = model
	model.PrimaryPart = main
	model:SetAttribute(NodeModels.ATTRIBUTE, nodeType)
	return model
end

return NodeModels
