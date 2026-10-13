--!strict
-- Modelos provisionales (greybox) de las piezas construibles (Data/Buildables).
-- Los usa el servidor para la pieza real y el cliente para la vista previa transparente.
-- Cada modelo tiene una pieza invisible "Bounds" del tamaño de la pieza: es su PrimaryPart y su
-- centro, así que basta con PivotTo(cframe) para colocarlo.

local Buildables = require(script.Parent.Data.Buildables)

local WOOD = Color3.fromRGB(125, 85, 50)
local DARK_WOOD = Color3.fromRGB(85, 55, 32)
local STONE = Color3.fromRGB(125, 125, 130)
local STONE_DARK = Color3.fromRGB(90, 90, 95)
local FABRIC = Color3.fromRGB(205, 190, 150)

local BuildModels = {}

local function newPart(
	model: Model,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = offset
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Las piezas se describen respecto al centro de la caja; "bottom" es la altura del suelo.
local BUILDERS: { [string]: (model: Model, size: Vector3) -> () } = {
	WoodWall = function(model, size)
		newPart(model, "Panel", size, CFrame.new(), WOOD, Enum.Material.WoodPlanks)
		for side = -1, 1, 2 do
			newPart(
				model,
				"Post",
				Vector3.new(0.9, size.Y + 0.4, size.Z + 0.3),
				CFrame.new(side * (size.X / 2 - 0.45), 0.2, 0),
				DARK_WOOD,
				Enum.Material.Wood
			)
		end
		newPart(
			model,
			"Beam",
			Vector3.new(size.X, 0.6, size.Z + 0.2),
			CFrame.new(0, size.Y / 2 - 1.2, 0),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end,
	StoneWall = function(model, size)
		newPart(model, "Panel", size, CFrame.new(), STONE, Enum.Material.Cobblestone)
		newPart(
			model,
			"Cap",
			Vector3.new(size.X + 0.2, 0.6, size.Z + 0.4),
			CFrame.new(0, size.Y / 2 + 0.3, 0),
			STONE_DARK,
			Enum.Material.Slate
		)
	end,
	StandingTorch = function(model, size)
		local bottom = -size.Y / 2
		newPart(
			model,
			"Post",
			Vector3.new(0.5, size.Y - 1, 0.5),
			CFrame.new(0, bottom + (size.Y - 1) / 2, 0),
			DARK_WOOD,
			Enum.Material.Wood
		)
		local head = newPart(
			model,
			"Head",
			Vector3.new(0.9, 1, 0.9),
			CFrame.new(0, bottom + size.Y - 0.5, 0),
			Color3.fromRGB(60, 40, 25),
			Enum.Material.Fabric
		)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Parent = head
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 90)
		light.Range = 26
		light.Brightness = 2
		light.Parent = head
	end,
	Bed = function(model, size)
		local bottom = -size.Y / 2
		newPart(
			model,
			"Frame",
			Vector3.new(size.X, 0.8, size.Z),
			CFrame.new(0, bottom + 0.4, 0),
			WOOD,
			Enum.Material.Wood
		)
		newPart(
			model,
			"Mattress",
			Vector3.new(size.X - 0.5, 0.6, size.Z - 1.4),
			CFrame.new(0, bottom + 1.1, 0.5),
			FABRIC,
			Enum.Material.Fabric
		)
		newPart(
			model,
			"Pillow",
			Vector3.new(size.X - 1, 0.5, 1),
			CFrame.new(0, bottom + 1.1, -size.Z / 2 + 0.8),
			Color3.fromRGB(235, 230, 215),
			Enum.Material.Fabric
		)
	end,
	-- Base de tierra con estacas inclinadas hacia fuera. No bloquea el paso: los monos la cruzan.
	Spikes = function(model, size)
		local bottom = -size.Y / 2
		local base = newPart(
			model,
			"Base",
			Vector3.new(size.X, 0.3, size.Z),
			CFrame.new(0, bottom + 0.15, 0),
			Color3.fromRGB(95, 70, 45),
			Enum.Material.Ground
		)
		base.CanCollide = false
		for i = 0, 4 do
			for _, z in { -0.7, 0.7 } do
				local stake = newPart(
					model,
					"Stake",
					Vector3.new(0.35, size.Y + 0.6, 0.35),
					CFrame.new(-size.X / 2 + 0.8 + i * (size.X - 1.6) / 4, 0.2, z)
						* CFrame.Angles(math.rad(if z > 0 then 25 else -25), 0, 0),
					DARK_WOOD,
					Enum.Material.Wood
				)
				stake.CanCollide = false
			end
		end
	end,
	-- Tienda de lona sobre postes, con una mesa baja y hierbas colgando.
	HealerTent = function(model, size)
		local bottom = -size.Y / 2
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				newPart(
					model,
					"Pole",
					Vector3.new(0.4, size.Y - 0.5, 0.4),
					CFrame.new(x * (size.X / 2 - 0.3), bottom + (size.Y - 0.5) / 2, z * (size.Z / 2 - 0.3)),
					DARK_WOOD,
					Enum.Material.Wood
				)
			end
		end
		for _, side in { -1, 1 } do
			newPart(
				model,
				"Canvas",
				Vector3.new(size.X + 0.4, 0.2, size.Z / 2 + 1),
				CFrame.new(0, size.Y / 2 - 0.9, side * size.Z / 4) * CFrame.Angles(side * math.rad(-25), 0, 0),
				Color3.fromRGB(215, 205, 175),
				Enum.Material.Fabric
			)
		end
		newPart(
			model,
			"Table",
			Vector3.new(size.X - 2, 0.4, 2),
			CFrame.new(0, bottom + 2.2, 0),
			WOOD,
			Enum.Material.Wood
		)
		for i = -1, 1 do
			newPart(
				model,
				"Herbs",
				Vector3.new(0.6, 1, 0.6),
				CFrame.new(i * 2, size.Y / 2 - 2, 0),
				Color3.fromRGB(80, 160, 70),
				Enum.Material.Grass
			)
		end
	end,
	-- Horno de piedra con brasas y un yunque de roca al lado.
	StoneForge = function(model, size)
		local bottom = -size.Y / 2
		newPart(
			model,
			"Furnace",
			Vector3.new(size.X - 2, size.Y - 1, size.Z - 1.5),
			CFrame.new(-1, bottom + (size.Y - 1) / 2, 0),
			STONE_DARK,
			Enum.Material.Cobblestone
		)
		local embers = newPart(
			model,
			"Embers",
			Vector3.new(1.5, 1, size.Z - 2.5),
			CFrame.new(size.X / 2 - 2.6, bottom + 1.2, 0),
			Color3.fromRGB(255, 120, 40),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 60)
		light.Range = 16
		light.Brightness = 2
		light.Parent = embers
		newPart(
			model,
			"Chimney",
			Vector3.new(1.4, 2, 1.4),
			CFrame.new(-1.5, size.Y / 2 - 0.5, 0),
			STONE,
			Enum.Material.Slate
		)
		newPart(
			model,
			"Anvil",
			Vector3.new(1.2, 1.6, 2),
			CFrame.new(size.X / 2 - 0.6, bottom + 0.8, size.Z / 2 - 1.2),
			STONE,
			Enum.Material.Slate
		)
	end,
}

-- Crea la pieza con su centro en el origen. Hay que moverla con PivotTo.
function BuildModels.build(buildableId: string): Model
	local definition = Buildables[buildableId]
	local builder = BUILDERS[buildableId]
	assert(definition and builder, `Pieza desconocida: {buildableId}`)

	local model = Instance.new("Model")
	model.Name = definition.name
	local bounds = Instance.new("Part")
	bounds.Name = "Bounds"
	bounds.Size = definition.size
	bounds.Transparency = 1
	bounds.Anchored = true
	bounds.CanCollide = false
	bounds.CanQuery = false
	bounds.CanTouch = false
	bounds.Parent = model
	model.PrimaryPart = bounds
	builder(model, definition.size)
	return model
end

-- Convierte un modelo en vista previa: transparente, sin colisiones y sin fuego ni luz.
function BuildModels.makeGhost(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			if descendant.Transparency < 1 then
				descendant.Transparency = 0.45
			end
		elseif descendant:IsA("Fire") or descendant:IsA("Light") then
			descendant:Destroy()
		end
	end
end

return BuildModels
