--!strict
-- Modelos provisionales (greybox) de las piezas construibles (Data/Buildables).
-- Los usa el servidor para la pieza real y el cliente para la vista previa transparente.
-- Cada modelo tiene una pieza invisible "Bounds" del tamaño de la pieza: es su PrimaryPart y su
-- centro, así que basta con PivotTo(cframe) para colocarlo.

local Buildables = require(script.Parent.Data.Buildables)
local Config = require(script.Parent.Config)

local WOOD = Color3.fromRGB(125, 85, 50)
local DARK_WOOD = Color3.fromRGB(85, 55, 32)
local STONE = Color3.fromRGB(125, 125, 130)
local STONE_DARK = Color3.fromRGB(90, 90, 95)
local FABRIC = Color3.fromRGB(205, 190, 150)
local STRAW = Color3.fromRGB(220, 192, 125)
local STRAW_DARK = Color3.fromRGB(170, 135, 80)
-- Forja volcánica (Fase 9, G5).
local BASALT = Color3.fromRGB(62, 58, 60)
local BASALT_DARK = Color3.fromRGB(44, 41, 44)
local OBSIDIAN = Color3.fromRGB(30, 24, 38)
local MAGMA = Color3.fromRGB(255, 110, 30)
-- Tótem guardián (Fase 9, G8): madera tallada con pintura de ocre y ojos de perla del río.
local TOTEM_LIGHT = Color3.fromRGB(156, 108, 62)
local OCHRE = Color3.fromRGB(170, 62, 40)
local PEARL = Color3.fromRGB(205, 225, 255)

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
	-- Fase 9 (G5): un volcán pequeño de basalto en tres escalones con un lago de lava arriba, rodeado de
	-- esquirlas de obsidiana, una boca de horno que brilla por delante (-Z), humo y chispas, y un yunque
	-- de obsidiana al lado.
	VolcanicForge = function(model, size)
		local bottom = -size.Y / 2
		local furnaceWidth = size.X - 2.4
		local tierHeight = (size.Y - 1.2) / 3
		for tier = 0, 2 do
			local shrink = tier * 1.1
			newPart(
				model,
				"Furnace",
				Vector3.new(furnaceWidth - shrink, tierHeight, furnaceWidth - shrink),
				CFrame.new(-0.6, bottom + tierHeight * (tier + 0.5), 0.4),
				if tier == 1 then BASALT_DARK else BASALT,
				Enum.Material.Basalt
			)
		end
		local topY = bottom + tierHeight * 3
		local lava = newPart(
			model,
			"Lava",
			Vector3.new(furnaceWidth - 2.9, 0.3, furnaceWidth - 2.9),
			CFrame.new(-0.6, topY + 0.05, 0.4),
			MAGMA,
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Color = MAGMA
		light.Range = 18
		light.Brightness = 2
		light.Parent = lava
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(70, 66, 66)
		smoke.Opacity = 0.15
		smoke.RiseVelocity = 4
		smoke.Size = 3
		smoke.Parent = lava
		local sparks = Instance.new("Fire")
		sparks.Color = MAGMA
		sparks.SecondaryColor = Color3.fromRGB(255, 200, 80)
		sparks.Heat = 6
		sparks.Size = 3
		sparks.Parent = lava
		-- Esquirlas de obsidiana en el borde del cráter, inclinadas hacia fuera.
		for index = 0, 5 do
			local angle = index * math.pi / 3 + 0.3
			local reach = (furnaceWidth - 2.2) / 2
			local shard = decor(
				newPart(
					model,
					"Obsidian",
					Vector3.new(0.5, 1.2 + (index % 2) * 0.5, 0.5),
					CFrame.new(-0.6 + math.cos(angle) * reach, topY + 0.5, 0.4 + math.sin(angle) * reach)
						* CFrame.Angles(math.sin(angle) * 0.65, 0, -math.cos(angle) * 0.65),
					OBSIDIAN,
					Enum.Material.SmoothPlastic
				)
			)
			shard.Reflectance = 0.05
		end
		-- Boca del horno por delante: un hueco oscuro con brasas dentro.
		local mouthZ = 0.4 - furnaceWidth / 2
		newPart(
			model,
			"Mouth",
			Vector3.new(1.8, 1.3, 0.2),
			CFrame.new(-0.6, bottom + 0.9, mouthZ - 0.05),
			OBSIDIAN,
			Enum.Material.SmoothPlastic
		)
		decor(
			newPart(
				model,
				"Embers",
				Vector3.new(1.4, 0.9, 0.12),
				CFrame.new(-0.6, bottom + 0.8, mouthZ - 0.12),
				MAGMA,
				Enum.Material.Neon
			)
		)
		-- Grietas de lava que bajan por la ladera del horno.
		for side = -1, 1, 2 do
			decor(
				newPart(
					model,
					"Crack",
					Vector3.new(0.18, tierHeight * 2.2, 0.12),
					CFrame.new(-0.6 + side * 1.1, bottom + tierHeight * 1.6, mouthZ + 0.5)
						* CFrame.Angles(0, 0, side * 0.35),
					MAGMA,
					Enum.Material.Neon
				)
			)
		end
		-- Yunque de obsidiana sobre un tocón de basalto.
		local anvilX, anvilZ = size.X / 2 - 0.9, -size.Z / 2 + 1.2
		newPart(
			model,
			"Stump",
			Vector3.new(1, 1.2, 1),
			CFrame.new(anvilX, bottom + 0.6, anvilZ),
			BASALT,
			Enum.Material.Basalt
		)
		local anvil = newPart(
			model,
			"Anvil",
			Vector3.new(0.9, 0.5, 1.6),
			CFrame.new(anvilX, bottom + 1.45, anvilZ),
			OBSIDIAN,
			Enum.Material.SmoothPlastic
		)
		anvil.Reflectance = 0.05
	end,
	-- Fase 9 (G8): tótem de tres caras de mono apiladas (gorila ceñudo, aullador con la boca abierta y
	-- uno de orejas grandes con penacho de obsidiana y la perla del río), talladas delante (-Z) y
	-- detrás, con alas a los lados, sobre una base de piedra. Un anillo de trazos en el suelo marca
	-- hasta dónde llega su aura (Config.Siege.Totem.Radius).
	WarTotem = function(model, size)
		local bottom = -size.Y / 2
		newPart(
			model,
			"Base",
			Vector3.new(size.X, 0.8, size.Z),
			CFrame.new(0, bottom + 0.4, 0),
			STONE_DARK,
			Enum.Material.Slate
		)
		newPart(
			model,
			"Step",
			Vector3.new(size.X - 0.8, 0.6, size.Z - 0.8),
			CFrame.new(0, bottom + 1.1, 0),
			STONE,
			Enum.Material.Slate
		)
		-- De abajo arriba: el gorila (ancho y oscuro), el aullador y el de las orejas (más estrecho).
		local headHeight = 2
		local headWidths = { 3, 2.6, 2.3 }
		local headColors = { DARK_WOOD, TOTEM_LIGHT, WOOD }
		local firstY = bottom + 1.4 + headHeight / 2
		-- Cara tallada en el lado "side" (-1 delante, 1 detrás) de la cabeza "index" (1 abajo).
		local function face(index: number, centerY: number, side: number)
			local width = headWidths[index]
			local z = side * (width / 2 + 0.1)
			newPart(
				model,
				"Brow",
				Vector3.new(width - 0.2, if index == 1 then 0.5 else 0.35, 0.3),
				CFrame.new(0, centerY + 0.55, z),
				if index == 1 then Color3.fromRGB(50, 32, 20) else DARK_WOOD,
				Enum.Material.Wood
			)
			for eye = -1, 1, 2 do
				local socket = newPart(
					model,
					"Eye",
					Vector3.new(0.55, 0.45, 0.2),
					CFrame.new(eye * 0.6, centerY + 0.15, z),
					OBSIDIAN,
					Enum.Material.SmoothPlastic
				)
				socket.Reflectance = 0.05
				decor(
					newPart(
						model,
						"Pupil",
						Vector3.new(0.24, 0.24, 0.1),
						CFrame.new(eye * 0.6, centerY + 0.15, z + side * 0.1),
						PEARL,
						Enum.Material.Neon
					)
				)
			end
			-- Rayas de pintura de ocre en las mejillas.
			for cheek = -1, 1, 2 do
				decor(
					newPart(
						model,
						"Paint",
						Vector3.new(0.18, 0.7, 0.1),
						CFrame.new(cheek * (width / 2 - 0.25), centerY - 0.15, z),
						OCHRE,
						Enum.Material.SmoothPlastic
					)
				)
			end
			local muzzleY = centerY - 0.55
			newPart(
				model,
				"Muzzle",
				Vector3.new(1.5, 0.75, 0.4),
				CFrame.new(0, muzzleY, z + side * 0.1),
				TOTEM_LIGHT,
				Enum.Material.Wood
			)
			if index == 2 then
				-- El aullador: boca abierta con colmillos.
				newPart(
					model,
					"Mouth",
					Vector3.new(0.9, 0.45, 0.1),
					CFrame.new(0, muzzleY - 0.05, z + side * 0.32),
					DARK_WOOD,
					Enum.Material.SmoothPlastic
				)
				for fang = -1, 1, 2 do
					decor(
						newPart(
							model,
							"Fang",
							Vector3.new(0.14, 0.22, 0.08),
							CFrame.new(fang * 0.3, muzzleY + 0.06, z + side * 0.37),
							Color3.fromRGB(230, 220, 195),
							Enum.Material.SmoothPlastic
						)
					)
				end
			else
				newPart(
					model,
					"Nose",
					Vector3.new(if index == 1 then 0.8 else 0.45, 0.3, 0.2),
					CFrame.new(0, muzzleY + 0.2, z + side * 0.35),
					DARK_WOOD,
					Enum.Material.Wood
				)
			end
		end
		for index = 1, 3 do
			local centerY = firstY + (index - 1) * headHeight
			local width = headWidths[index]
			newPart(
				model,
				"Head",
				Vector3.new(width, headHeight, width),
				CFrame.new(0, centerY, 0),
				headColors[index],
				Enum.Material.Wood
			)
			face(index, centerY, -1)
			face(index, centerY, 1)
		end
		-- Alas talladas a los lados de la cabeza del medio, levantadas.
		local wingY = firstY + headHeight
		local wingX = headWidths[2] / 2
		for side = -1, 1, 2 do
			newPart(
				model,
				"Wing",
				Vector3.new(1.5, 0.9, 0.5),
				CFrame.new(side * (wingX + 0.6), wingY + 0.3, 0) * CFrame.Angles(0, 0, side * math.rad(25)),
				DARK_WOOD,
				Enum.Material.Wood
			)
			decor(
				newPart(
					model,
					"WingPaint",
					Vector3.new(1.1, 0.2, 0.55),
					CFrame.new(side * (wingX + 0.7), wingY + 0.38, 0) * CFrame.Angles(0, 0, side * math.rad(25)),
					OCHRE,
					Enum.Material.SmoothPlastic
				)
			)
		end
		-- Arriba: orejas grandes y la perla del río que brilla en una corona de esquirlas de obsidiana
		-- (una a cada lado: se ve de frente y de espaldas).
		local topY = firstY + 2.5 * headHeight
		for side = -1, 1, 2 do
			newPart(
				model,
				"Ear",
				Vector3.new(0.45, 1, 0.9),
				CFrame.new(side * (headWidths[3] / 2 + 0.2), topY - 0.9, 0),
				TOTEM_LIGHT,
				Enum.Material.Wood
			)
		end
		for spike = 0, 3 do
			local angle = spike * math.pi / 2
			local shard = newPart(
				model,
				"Shard",
				Vector3.new(0.45, 1.1, 0.45),
				CFrame.Angles(0, angle, 0) * CFrame.new(0, topY + 0.45, -0.75) * CFrame.Angles(math.rad(-25), 0, 0),
				OBSIDIAN,
				Enum.Material.SmoothPlastic
			)
			shard.Reflectance = 0.05
		end
		local pearl = newPart(
			model,
			"Pearl",
			Vector3.new(1.1, 1.1, 1.1),
			CFrame.new(0, topY + 1.05, 0),
			PEARL,
			Enum.Material.Neon
		)
		pearl.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Color = PEARL
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = pearl
		-- Anillo de trazos en el suelo con el radio del aura.
		local radius = Config.Siege.Totem.Radius
		local dashes = 40
		local dashLength = 2 * math.pi * radius / dashes * 0.55
		for dash = 1, dashes do
			local angle = (dash - 0.5) / dashes * 2 * math.pi
			local ring = decor(
				newPart(
					model,
					"AuraRing",
					Vector3.new(0.35, 0.1, dashLength),
					CFrame.new(math.cos(angle) * radius, bottom + 0.05, math.sin(angle) * radius)
						* CFrame.Angles(0, -angle, 0),
					PEARL,
					Enum.Material.Neon
				)
			)
			ring.Transparency = 0.4
			ring.CastShadow = false
		end
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
