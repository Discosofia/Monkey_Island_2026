--!strict
-- Modelo provisional (greybox) de un mono: cuerpo, cabeza con cara y ojos, orejas, brazos,
-- piernas y cola, soldados a un HumanoidRootPart. El Humanoid lo mueve como a un personaje.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)

local MonkeyModels = {}

local EYE_COLOR = Color3.fromRGB(20, 15, 10)

local function newPart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.Massless = true
	part.Parent = parent
	return part
end

-- Coloca una pieza respecto a la raíz y la suelda a ella.
local function attach(root: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function ball(name: string, diameter: number, color: Color3, parent: Instance): Part
	local part = newPart(name, Vector3.one, color, parent)
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * diameter
	return part
end

-- Altura de la raíz sobre el suelo para que las patas lo toquen (ver HipHeight).
function MonkeyModels.rootHeight(scale: number): number
	return 1.9 * scale
end

-- "ground" es el punto del suelo donde aparece.
function MonkeyModels.build(speciesId: string, definition: Monkeys.MonkeyDefinition, ground: Vector3): Model
	local s = definition.scale
	local bodyColor = definition.bodyColor
	local faceColor = definition.faceColor
	local model = Instance.new("Model")
	model.Name = definition.name
	model:SetAttribute("MonkeyType", speciesId)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * s
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = CFrame.new(ground + Vector3.new(0, MonkeyModels.rootHeight(s), 0))
	root.Parent = model
	model.PrimaryPart = root

	-- Cuerpo encorvado, cabeza adelantada (la cara mira hacia -Z, la dirección en la que anda).
	attach(root, newPart("Body", Vector3.new(1.8, 1.8, 1.4) * s, bodyColor, model), CFrame.new(0, 0, 0))
	local head = ball("Head", 1.4 * s, bodyColor, model)
	attach(root, head, CFrame.new(0, 1.1 * s, -0.7 * s))
	attach(root, newPart("Face", Vector3.new(0.9, 0.8, 0.25) * s, faceColor, model), CFrame.new(0, 1.05 * s, -1.3 * s))
	for side = -1, 1, 2 do
		attach(root, ball("Eye", 0.22 * s, EYE_COLOR, model), CFrame.new(side * 0.22 * s, 1.2 * s, -1.45 * s))
		attach(root, ball("Ear", 0.5 * s, faceColor, model), CFrame.new(side * 0.75 * s, 1.25 * s, -0.6 * s))
		attach(
			root,
			newPart("Arm", Vector3.new(0.45, 1.6, 0.45) * s, bodyColor, model),
			CFrame.new(side * 1.05 * s, -0.4 * s, -0.3 * s) * CFrame.Angles(math.rad(15), 0, 0)
		)
		attach(
			root,
			newPart("Leg", Vector3.new(0.55, 1, 0.55) * s, bodyColor, model),
			CFrame.new(side * 0.5 * s, -1.4 * s, 0.2 * s)
		)
	end
	attach(
		root,
		newPart("Tail", Vector3.new(0.3, 0.3, 2.4) * s, bodyColor, model),
		CFrame.new(0, 0.3 * s, 1.6 * s) * CFrame.Angles(math.rad(35), 0, 0)
	)

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = definition.name
	humanoid.MaxHealth = definition.maxHealth
	humanoid.Health = definition.maxHealth
	humanoid.WalkSpeed = definition.walkSpeed
	humanoid.HipHeight = 0.9 * s
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	return model
end

return MonkeyModels
