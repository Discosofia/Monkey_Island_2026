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
local STRAW = Color3.fromRGB(220, 192, 125)
local STRAW_DARK = Color3.fromRGB(170, 135, 80)

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

-- Pieza de adorno: no choca ni bloquea rayos.
local function decor(part: Part): Part
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Convierte una pieza en un óvalo del tamaño de la pieza (las Ball solo pueden ser esferas).
local function oval(part: Part)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
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
	-- Barricada: tablones gruesos con tres refuerzos y travesaños.
	GateBarricade = function(model, size)
		newPart(model, "Planks", size, CFrame.new(), WOOD, Enum.Material.WoodPlanks)
		for _, x in { -1, 0, 1 } do
			newPart(
				model,
				"Brace",
				Vector3.new(1, size.Y + 0.4, size.Z + 0.4),
				CFrame.new(x * (size.X / 2 - 0.5), 0.2, 0),
				DARK_WOOD,
				Enum.Material.Wood
			)
		end
		for _, y in { -1, 1 } do
			newPart(
				model,
				"Rail",
				Vector3.new(size.X, 0.8, size.Z + 0.3),
				CFrame.new(0, y * size.Y / 4, 0),
				DARK_WOOD,
				Enum.Material.Wood
			)
		end
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
	-- Erizo de estacas: base de tierra y 3×3 estacas, la del centro recta y las demás inclinadas hacia
	-- fuera, así pincha igual venga el mono de donde venga. No bloquea el paso: los monos la cruzan.
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
		local spacing = size.X / 3
		for _, gx in { -1, 0, 1 } do
			for _, gz in { -1, 0, 1 } do
				local tilt = CFrame.new()
				if gx ~= 0 or gz ~= 0 then
					-- Girar sobre (arriba × dirección) inclina la punta hacia fuera del centro.
					local axis = Vector3.new(gz, 0, -gx).Unit
					tilt = CFrame.fromAxisAngle(axis, math.rad(28))
				end
				local stake = newPart(
					model,
					"Stake",
					Vector3.new(0.35, size.Y + 0.6, 0.35),
					CFrame.new(gx * spacing, 0.2, gz * spacing) * tilt,
					DARK_WOOD,
					Enum.Material.Wood
				)
				stake.CanCollide = false
			end
		end
	end,
	-- Nido: cuenco redondo de ramitas entrelazadas en dos vueltas, con forro de paja, plumas y
	-- ramitas sueltas. El huevo se apoya en el punto invisible "EggSeat" (EggService).
	Nest = function(model, size)
		local bottom = -size.Y / 2
		local radius = size.X / 2 - 0.95 -- eje del aro de ramitas
		local twigColors = { DARK_WOOD, WOOD, Color3.fromRGB(150, 115, 70) }

		local mound = decor(
			newPart(
				model,
				"Mound",
				Vector3.new(size.X - 0.4, 1.4, size.Z - 0.4),
				CFrame.new(0, bottom + 0.35, 0),
				STRAW_DARK,
				Enum.Material.SmoothPlastic
			)
		)
		oval(mound)

		-- Dos vueltas de ramitas tangentes al aro, inclinadas a un lado y a otro (como tejidas).
		for layer = 0, 1 do
			local count = 12
			local layerRadius = radius - layer * 0.15
			for i = 0, count - 1 do
				local angle = (i + layer * 0.5) * 2 * math.pi / count
				local position = Vector3.new(
					math.cos(angle) * layerRadius,
					bottom + 0.85 + layer * 0.5,
					math.sin(angle) * layerRadius
				)
				local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
				local twig = newPart(
					model,
					"Twig",
					Vector3.new(2 * math.pi * layerRadius / count * 1.4, 0.55, 0.55),
					CFrame.fromMatrix(position, tangent, Vector3.yAxis)
						* CFrame.Angles(0, 0, (if (i + layer) % 2 == 0 then 1 else -1) * 0.16),
					twigColors[(i + layer) % #twigColors + 1],
					Enum.Material.Wood
				)
				twig.Shape = Enum.PartType.Cylinder
			end
		end

		-- Paja asomando por el borde.
		for i = 0, 7 do
			local angle = (i + 0.25) * math.pi / 4
			local tuft = decor(
				newPart(
					model,
					"Tuft",
					Vector3.new(1.1, 0.45, 0.7),
					CFrame.new(math.cos(angle) * radius, bottom + 1.6, math.sin(angle) * radius)
						* CFrame.Angles(0, -angle, 0.15),
					STRAW,
					Enum.Material.SmoothPlastic
				)
			)
			oval(tuft)
		end

		-- Ramitas sueltas que salen del aro hacia fuera y hacia arriba.
		for i = 0, 7 do
			local angle = i * math.pi / 4 + 0.3
			local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local start = outward * (radius - 0.2) + Vector3.new(0, bottom + 1.1 + (i % 2) * 0.4, 0)
			local direction = (outward + Vector3.new(0, 0.35 + (i % 3) * 0.2, 0)).Unit
			local twig = decor(
				newPart(
					model,
					"LooseTwig",
					Vector3.new(1.6, 0.18, 0.18),
					CFrame.lookAt(start + direction * 0.8, start + direction * 2) * CFrame.Angles(0, math.pi / 2, 0),
					DARK_WOOD,
					Enum.Material.Wood
				)
			)
			twig.Shape = Enum.PartType.Cylinder
		end

		-- Forro: cuenco de paja clara dentro del aro, con unas plumas.
		local lining = decor(
			newPart(
				model,
				"Lining",
				Vector3.new(radius * 2 - 0.6, 0.9, radius * 2 - 0.6),
				CFrame.new(0, bottom + 0.75, 0),
				STRAW,
				Enum.Material.SmoothPlastic
			)
		)
		oval(lining)
		local liningTop = bottom + 0.75 + 0.45
		for i = 0, 2 do
			local angle = i * 2.1 + 0.6
			local feather = decor(
				newPart(
					model,
					"Feather",
					Vector3.new(0.3, 0.05, 0.8),
					CFrame.new(math.cos(angle) * 1.4, liningTop - 0.12, math.sin(angle) * 1.4)
						* CFrame.Angles(0.15, angle, 0),
					if i == 1 then Color3.fromRGB(150, 230, 240) else Color3.fromRGB(245, 245, 240),
					Enum.Material.SmoothPlastic
				)
			)
			oval(feather)
		end

		-- Donde se apoya la base del huevo: el centro del forro.
		local seat = decor(
			newPart(
				model,
				"EggSeat",
				Vector3.one * 0.5,
				CFrame.new(0, liningTop, 0),
				STRAW,
				Enum.Material.SmoothPlastic
			)
		)
		seat.Transparency = 1
	end,
	-- Baliza: torre de metal con antena y una luz roja arriba.
	Beacon = function(model, size)
		local bottom = -size.Y / 2
		newPart(
			model,
			"Base",
			Vector3.new(size.X, 1.5, size.Z),
			CFrame.new(0, bottom + 0.75, 0),
			STONE_DARK,
			Enum.Material.Concrete
		)
		newPart(
			model,
			"Tower",
			Vector3.new(2, size.Y - 3, 2),
			CFrame.new(0, bottom + 1.5 + (size.Y - 3) / 2, 0),
			Color3.fromRGB(150, 150, 160),
			Enum.Material.DiamondPlate
		)
		newPart(
			model,
			"Antenna",
			Vector3.new(0.3, 3, 0.3),
			CFrame.new(0, size.Y / 2 - 0.5, 0),
			Color3.fromRGB(200, 200, 210),
			Enum.Material.Metal
		)
		local lamp = newPart(
			model,
			"Lamp",
			Vector3.new(1.2, 1.2, 1.2),
			CFrame.new(0, size.Y / 2 - 2.2, 0),
			Color3.fromRGB(120, 30, 30),
			Enum.Material.Glass
		)
		lamp.Shape = Enum.PartType.Ball
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
