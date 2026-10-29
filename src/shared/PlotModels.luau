--!strict
-- Modelos voxel de las estructuras de la parcela permanente (Fase 12, P3; Data/PlotStructures), uno por
-- nivel. Los usa BuildingService para levantar la parcela del perfil.
-- Como en BuildModels, cada modelo tiene una pieza invisible "Bounds" del tamaño de la estructura: es su
-- PrimaryPart y su centro, así que basta con PivotTo(cframe). El frente mira a -Z.
-- Cada nivel se distingue de lejos y desde cualquier lado:
--   - I: madera y paja, sin zócalo ni estandarte.
--   - II: zócalo de piedra, tejas de barro y un banderín de bronce en un mástil detrás.
--   - III: zócalo de basalto con canto de oro, tejado oscuro con cumbrera de oro y un estandarte dorado
--     con una gema de ámbar que brilla encima del mástil.

local PlotStructures = require(script.Parent.Data.PlotStructures)
local VoxelMerge = require(script.Parent.VoxelMerge)

local WOOD = Color3.fromRGB(125, 85, 50)
local DARK_WOOD = Color3.fromRGB(85, 55, 32)
local STRAW = Color3.fromRGB(220, 192, 125)
local STRAW_DARK = Color3.fromRGB(170, 135, 80)
local FABRIC = Color3.fromRGB(205, 190, 150)
local STONE = Color3.fromRGB(125, 125, 130)
local STONE_DARK = Color3.fromRGB(90, 90, 95)
local CLAY = Color3.fromRGB(176, 92, 56)
local BRONZE = Color3.fromRGB(196, 124, 58)
local BASALT = Color3.fromRGB(62, 58, 60)
local OBSIDIAN = Color3.fromRGB(30, 24, 38)
local GOLD = Color3.fromRGB(240, 190, 60)
local AMBER = Color3.fromRGB(255, 170, 40)
local MAGMA = Color3.fromRGB(255, 110, 30)
local SOIL = Color3.fromRGB(78, 52, 34)
local LEAF = Color3.fromRGB(80, 150, 60)
local LEAF_DARK = Color3.fromRGB(52, 110, 44)
local BANANA = Color3.fromRGB(245, 205, 60)
local GREY_FUR = Color3.fromRGB(150, 146, 140)
local ORANGE_FUR = Color3.fromRGB(215, 120, 40)
local IRON = Color3.fromRGB(70, 70, 76)
local FEATHER_BLUE = Color3.fromRGB(40, 120, 190)
local FEATHER_TEAL = Color3.fromRGB(30, 160, 160)

local ROMAN = { "I", "II", "III" }

local PlotModels = {}

type Kit = {
	model: Model,
	size: Vector3,
	level: number,
	bottom: number,
}

local function block(
	kit: Kit,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = kit.model
	return part
end

-- Pieza de adorno: no choca ni bloquea rayos.
local function decor(part: Part): Part
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = part.Size.Magnitude > 2
	return part
end

local function glow(part: Part, color: Color3, range: number)
	part.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 1.2
	light.Parent = part
end

-- Zócalo del nivel II (piedra) y III (basalto con canto de oro), un poco más ancho que la estructura.
-- Devuelve la altura a la que empieza la estructura.
local function plinth(kit: Kit, width: number, depth: number): number
	if kit.level < 2 then
		return kit.bottom
	end
	local height = 0.5
	local color = if kit.level == 3 then BASALT else STONE
	block(
		kit,
		"Plinth",
		Vector3.new(width + 0.6, height, depth + 0.6),
		CFrame.new(0, kit.bottom + height / 2, 0),
		color,
		Enum.Material.Slate
	)
	if kit.level == 3 then
		-- Canto de oro alrededor, apenas por encima del basalto.
		for side = -1, 1, 2 do
			decor(
				block(
					kit,
					"GoldTrim",
					Vector3.new(width + 0.7, 0.15, 0.15),
					CFrame.new(0, kit.bottom + height, side * (depth + 0.6) / 2),
					GOLD,
					Enum.Material.Metal
				)
			)
			decor(
				block(
					kit,
					"GoldTrim",
					Vector3.new(0.15, 0.15, depth + 0.7),
					CFrame.new(side * (width + 0.6) / 2, kit.bottom + height, 0),
					GOLD,
					Enum.Material.Metal
				)
			)
		end
	end
	return kit.bottom + height
end

-- Mástil con el distintivo del nivel, en un punto de la parte de atrás (+Z) para que se vea por
-- encima de la estructura desde delante y desde detrás. Nivel II: banderín de bronce; III: estandarte
-- dorado más alto con una gema de ámbar que brilla.
local function banner(kit: Kit, at: Vector3, height: number)
	if kit.level < 2 then
		return
	end
	local poleHeight = if kit.level == 3 then height + 1.5 else height
	decor(
		block(
			kit,
			"BannerPole",
			Vector3.new(0.25, poleHeight, 0.25),
			CFrame.new(at + Vector3.new(0, poleHeight / 2, 0)),
			if kit.level == 3 then OBSIDIAN else DARK_WOOD,
			Enum.Material.Wood
		)
	)
	local top = at + Vector3.new(0, poleHeight, 0)
	local cloth = if kit.level == 3 then GOLD else BRONZE
	local clothHeight = if kit.level == 3 then 1.6 else 1.1
	-- Tela en escalones (voxel): un rectángulo y una punta más corta debajo; se ve igual por los dos lados.
	decor(
		block(
			kit,
			"Banner",
			Vector3.new(1.4, clothHeight, 0.12),
			CFrame.new(top + Vector3.new(0.82, -0.2 - clothHeight / 2, 0)),
			cloth,
			Enum.Material.Fabric
		)
	)
	decor(
		block(
			kit,
			"BannerTip",
			Vector3.new(0.7, 0.4, 0.12),
			CFrame.new(top + Vector3.new(0.82, -0.4 - clothHeight, 0)),
			cloth,
			Enum.Material.Fabric
		)
	)
	-- Marcas del nivel en la tela: una franja (II) o dos (III), en oscuro.
	for stripe = 1, kit.level - 1 do
		decor(
			block(
				kit,
				"BannerStripe",
				Vector3.new(1.42, 0.16, 0.16),
				CFrame.new(top + Vector3.new(0.82, -0.2 - stripe * clothHeight / kit.level, 0)),
				if kit.level == 3 then OBSIDIAN else DARK_WOOD,
				Enum.Material.Fabric
			)
		)
	end
	if kit.level == 3 then
		local gem = decor(
			block(
				kit,
				"AmberGem",
				Vector3.new(0.55, 0.55, 0.55),
				CFrame.new(top + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(45), math.rad(45)),
				AMBER
			)
		)
		glow(gem, AMBER, 10)
	else
		decor(
			block(
				kit,
				"PoleCap",
				Vector3.new(0.4, 0.3, 0.4),
				CFrame.new(top + Vector3.new(0, 0.15, 0)),
				BRONZE,
				Enum.Material.Metal
			)
		)
	end
end

-- Tejado a dos aguas de bloques escalonados (voxel) a lo largo de Z, de "width" de ancho, desde "y".
-- Paja (I), tejas de barro (II) o basalto con cumbrera de oro (III).
local function roof(kit: Kit, width: number, depth: number, y: number, steps: number)
	local color = if kit.level == 1 then STRAW elseif kit.level == 2 then CLAY else BASALT
	local material = if kit.level == 1 then Enum.Material.Grass else Enum.Material.Slate
	local stepHeight = 0.45
	for step = 0, steps - 1 do
		local stepWidth = width - step * (width / steps)
		block(
			kit,
			"Roof",
			Vector3.new(stepWidth, stepHeight, depth),
			CFrame.new(0, y + stepHeight * (step + 0.5), 0),
			if step % 2 == 1 and kit.level == 1 then STRAW_DARK else color,
			material
		)
	end
	local ridgeY = y + stepHeight * steps + 0.1
	decor(
		block(
			kit,
			"Ridge",
			Vector3.new(0.4, 0.25, depth + 0.3),
			CFrame.new(0, ridgeY, 0),
			if kit.level == 3 then GOLD elseif kit.level == 2 then DARK_WOOD else STRAW_DARK,
			if kit.level == 3 then Enum.Material.Metal else Enum.Material.Wood
		)
	)
end

local BUILDERS: { [string]: (kit: Kit) -> () } = {
	-- Horno de bloques con la boca encendida delante, chimenea detrás y un yunque al lado.
	Forge = function(kit)
		local base = plinth(kit, 5, 5)
		local level = kit.level
		local wall = if level == 1 then STONE elseif level == 2 then STONE_DARK else BASALT
		local furnaceHeight = 2.6 + (level - 1) * 0.3
		block(
			kit,
			"Furnace",
			Vector3.new(3.6, furnaceHeight, 3.4),
			CFrame.new(-0.6, base + furnaceHeight / 2, 0.4),
			wall,
			Enum.Material.Slate
		)
		-- Boca encendida (la luz de la forja).
		local mouth =
			decor(block(kit, "Mouth", Vector3.new(1.6, 1.1, 0.2), CFrame.new(-0.6, base + 0.9, 0.4 - 1.71), MAGMA))
		glow(mouth, MAGMA, 8)
		-- Ladrillos de otro tono (II) o grietas de lava (III) en los lados y detrás.
		if level >= 2 then
			for row = 0, 2 do
				for side = -1, 1, 2 do
					decor(
						block(
							kit,
							if level == 3 then "LavaCrack" else "Brick",
							Vector3.new(0.22, 0.4, if level == 3 then 0.9 else 1.2),
							CFrame.new(-0.6 + side * 1.81, base + 0.6 + row * 0.8, 0.4 + (row - 1) * 0.6),
							if level == 3 then MAGMA else STONE,
							if level == 3 then Enum.Material.Neon else Enum.Material.Slate
						)
					)
				end
			end
		end
		-- Chimenea detrás: más alta y con boca de oro en el III.
		local chimneyHeight = 1.8 + level * 0.6
		block(
			kit,
			"Chimney",
			Vector3.new(1.2, chimneyHeight, 1.2),
			CFrame.new(-1.2, base + furnaceHeight + chimneyHeight / 2, 1.4),
			if level == 3 then OBSIDIAN else wall,
			Enum.Material.Slate
		)
		if level == 3 then
			decor(
				block(
					kit,
					"ChimneyCap",
					Vector3.new(1.5, 0.3, 1.5),
					CFrame.new(-1.2, base + furnaceHeight + chimneyHeight + 0.15, 1.4),
					GOLD,
					Enum.Material.Metal
				)
			)
		end
		-- Yunque sobre un tocón, delante a la derecha.
		block(kit, "Stump", Vector3.new(1, 1, 1), CFrame.new(1.9, base + 0.5, -1.4), DARK_WOOD, Enum.Material.Wood)
		block(
			kit,
			"Anvil",
			Vector3.new(1.4, 0.5, 0.7),
			CFrame.new(1.9, base + 1.25, -1.4),
			if level == 3 then GOLD else IRON,
			Enum.Material.Metal
		)
		-- Fuelle de cuero (II y III), al otro lado.
		if level >= 2 then
			block(
				kit,
				"Bellows",
				Vector3.new(0.9, 0.7, 1.4),
				CFrame.new(1.9, base + 0.35, 1.2),
				DARK_WOOD,
				Enum.Material.Fabric
			)
		end
		banner(kit, Vector3.new(2.2, base, 2.2), 4.5)
	end,

	-- Tienda a dos aguas de tela sobre postes, con un estante de hierbas y vasijas.
	Healer = function(kit)
		local base = plinth(kit, 6.4, 5.4)
		local level = kit.level
		local width, depth = 6, 5
		-- Postes de las esquinas.
		for sideX = -1, 1, 2 do
			for sideZ = -1, 1, 2 do
				block(
					kit,
					"Post",
					Vector3.new(0.35, 2.4, 0.35),
					CFrame.new(sideX * (width / 2 - 0.2), base + 1.2, sideZ * (depth / 2 - 0.2)),
					DARK_WOOD,
					Enum.Material.Wood
				)
			end
		end
		-- Paredes de tela detrás y a los lados (delante queda abierto). Franjas de color por nivel.
		local cloth = FABRIC
		block(
			kit,
			"BackCloth",
			Vector3.new(width - 0.4, 2.2, 0.15),
			CFrame.new(0, base + 1.1, depth / 2 - 0.2),
			cloth,
			Enum.Material.Fabric
		)
		for side = -1, 1, 2 do
			block(
				kit,
				"SideCloth",
				Vector3.new(0.15, 2.2, depth - 0.4),
				CFrame.new(side * (width / 2 - 0.2), base + 1.1, 0),
				cloth,
				Enum.Material.Fabric
			)
		end
		if level >= 2 then
			-- Franja de color alrededor (bronce en el II, oro en el III), también detrás.
			local stripe = if level == 3 then GOLD else BRONZE
			decor(
				block(
					kit,
					"ClothStripe",
					Vector3.new(width - 0.3, 0.35, 0.2),
					CFrame.new(0, base + 1.6, depth / 2 - 0.2),
					stripe,
					Enum.Material.Fabric
				)
			)
			for side = -1, 1, 2 do
				decor(
					block(
						kit,
						"ClothStripe",
						Vector3.new(0.2, 0.35, depth - 0.3),
						CFrame.new(side * (width / 2 - 0.2), base + 1.6, 0),
						stripe,
						Enum.Material.Fabric
					)
				)
			end
		end
		roof(kit, width + 0.6, depth + 0.6, base + 2.4, 4)
		-- Hoja del curandero (el verde es de la curación) en el frontón de delante y en el de detrás.
		for side = -1, 1, 2 do
			decor(
				block(
					kit,
					"LeafEmblem",
					Vector3.new(0.8, 0.8, 0.12),
					CFrame.new(0, base + 3.1, side * (depth / 2 + 0.36)) * CFrame.Angles(0, 0, math.rad(45)),
					LEAF,
					if level == 3 then Enum.Material.Neon else Enum.Material.SmoothPlastic
				)
			)
		end
		-- Estante de hierbas y vasijas dentro, contra el fondo.
		block(
			kit,
			"Shelf",
			Vector3.new(3.6, 0.25, 0.8),
			CFrame.new(0, base + 1, depth / 2 - 0.8),
			WOOD,
			Enum.Material.Wood
		)
		local jars = 1 + level
		for jar = 1, jars do
			local x = (jar - (jars + 1) / 2) * 0.85
			decor(
				block(
					kit,
					"Jar",
					Vector3.new(0.5, 0.6, 0.5),
					CFrame.new(x, base + 1.43, depth / 2 - 0.8),
					if jar % 2 == 0 then CLAY else STRAW_DARK,
					Enum.Material.Slate
				)
			)
		end
		for herb = -1, 1 do
			decor(
				block(
					kit,
					"Herbs",
					Vector3.new(0.35, 0.7, 0.35),
					CFrame.new(herb * 1.2, base + 2.0, depth / 2 - 0.5),
					if herb == 0 then LEAF_DARK else LEAF,
					Enum.Material.Grass
				)
			)
		end
		if level == 3 then
			local lantern = decor(
				block(kit, "Lantern", Vector3.new(0.45, 0.6, 0.45), CFrame.new(0, base + 2.0, -depth / 2 + 0.3), AMBER)
			)
			glow(lantern, AMBER, 9)
		end
		banner(kit, Vector3.new(width / 2 - 0.2, base, depth / 2 - 0.2), 5)
	end,

	-- Bancal con surcos de tierra y matas de plátano: más filas y más altas por nivel.
	Garden = function(kit)
		local base = plinth(kit, 5.6, 6.6)
		local level = kit.level
		local width, depth = 5.4, 6.4
		local frame = if level == 1 then WOOD elseif level == 2 then STONE else BASALT
		local frameMaterial = if level == 1 then Enum.Material.Wood else Enum.Material.Slate
		block(
			kit,
			"Soil",
			Vector3.new(width - 0.6, 0.5, depth - 0.6),
			CFrame.new(0, base + 0.25, 0),
			SOIL,
			Enum.Material.Ground
		)
		for side = -1, 1, 2 do
			block(
				kit,
				"Frame",
				Vector3.new(width, 0.7, 0.3),
				CFrame.new(0, base + 0.35, side * (depth / 2 - 0.15)),
				frame,
				frameMaterial
			)
			block(
				kit,
				"Frame",
				Vector3.new(0.3, 0.7, depth),
				CFrame.new(side * (width / 2 - 0.15), base + 0.35, 0),
				frame,
				frameMaterial
			)
		end
		if level == 3 then
			for side = -1, 1, 2 do
				decor(
					block(
						kit,
						"GoldTrim",
						Vector3.new(width + 0.05, 0.12, 0.35),
						CFrame.new(0, base + 0.75, side * (depth / 2 - 0.15)),
						GOLD,
						Enum.Material.Metal
					)
				)
			end
		end
		-- Surcos a lo largo de Z y en cada uno matas de plátano: brote (I), mata con racimo (II), mata alta
		-- con hojas abiertas y racimo grande (III).
		local rows = level + 1
		local plantsPerRow = 3
		for row = 1, rows do
			local x = (row - (rows + 1) / 2) * ((width - 1.4) / math.max(rows - 1, 1))
			decor(
				block(
					kit,
					"Furrow",
					Vector3.new(0.6, 0.2, depth - 1),
					CFrame.new(x, base + 0.55, 0),
					SOIL,
					Enum.Material.Ground
				)
			)
			for plant = 1, plantsPerRow do
				local z = (plant - 2) * 1.8
				local stem = 0.5 + level * 0.45
				decor(
					block(
						kit,
						"Stem",
						Vector3.new(0.25, stem, 0.25),
						CFrame.new(x, base + 0.6 + stem / 2, z),
						LEAF_DARK,
						Enum.Material.Grass
					)
				)
				local top = base + 0.6 + stem
				decor(
					block(
						kit,
						"Leaves",
						Vector3.new(0.4 + level * 0.3, 0.25, 0.4 + level * 0.3),
						CFrame.new(x, top, z) * CFrame.Angles(0, math.rad(45), 0),
						LEAF,
						Enum.Material.Grass
					)
				)
				if level >= 2 then
					decor(
						block(
							kit,
							"Bunch",
							Vector3.new(0.35, 0.25 + (level - 1) * 0.2, 0.35),
							CFrame.new(x + 0.25, top - 0.4, z),
							BANANA
						)
					)
				end
			end
		end
		-- Cubo de agua (II) y espantapájaros con sombrero de paja (III), detrás.
		if level >= 2 then
			block(
				kit,
				"Bucket",
				Vector3.new(0.7, 0.7, 0.7),
				CFrame.new(-width / 2 - 0.15, base + 0.35, depth / 2 + 0.05),
				WOOD,
				Enum.Material.Wood
			)
		end
		banner(kit, Vector3.new(width / 2 - 0.15, base, depth / 2 - 0.15), 3.5)
	end,

	-- Cama de madera con colchón de paja; piel gris (II) o naranja con dosel de postes y oro (III).
	Bed = function(kit)
		local base = plinth(kit, 3.6, 6.6)
		local level = kit.level
		local width, depth = 3.4, 6.4
		local legs = 0.3 + (level - 1) * 0.15
		block(
			kit,
			"Frame",
			Vector3.new(width, 0.4, depth),
			CFrame.new(0, base + legs + 0.2, 0),
			if level == 3 then DARK_WOOD else WOOD,
			Enum.Material.Wood
		)
		for sideX = -1, 1, 2 do
			for sideZ = -1, 1, 2 do
				block(
					kit,
					"Leg",
					Vector3.new(0.4, legs, 0.4),
					CFrame.new(sideX * (width / 2 - 0.2), base + legs / 2, sideZ * (depth / 2 - 0.2)),
					DARK_WOOD,
					Enum.Material.Wood
				)
			end
		end
		local mattressTop = base + legs + 0.4 + 0.4
		block(
			kit,
			"Mattress",
			Vector3.new(width - 0.3, 0.4, depth - 0.4),
			CFrame.new(0, mattressTop - 0.2, 0),
			STRAW,
			Enum.Material.Fabric
		)
		-- Almohada al fondo (+Z) y manta por delante.
		decor(
			block(
				kit,
				"Pillow",
				Vector3.new(width - 0.9, 0.35, 1),
				CFrame.new(0, mattressTop + 0.17, depth / 2 - 1),
				FABRIC,
				Enum.Material.Fabric
			)
		)
		if level >= 2 then
			local fur = if level == 3 then ORANGE_FUR else GREY_FUR
			decor(
				block(
					kit,
					"Blanket",
					Vector3.new(width - 0.1, 0.2, depth * 0.55),
					CFrame.new(0, mattressTop + 0.1, -depth * 0.18),
					fur,
					Enum.Material.Fabric
				)
			)
			-- Rayas oscuras de la piel.
			for stripe = -1, 1 do
				decor(
					block(
						kit,
						"FurStripe",
						Vector3.new(width, 0.22, 0.25),
						CFrame.new(0, mattressTop + 0.11, -depth * 0.18 + stripe * 0.9),
						if level == 3 then DARK_WOOD else STONE_DARK,
						Enum.Material.Fabric
					)
				)
			end
		end
		-- Cabecero (detrás): liso (I), alto con remate (II), tallado con oro y gema de ámbar (III).
		local headHeight = 1.2 + level * 0.5
		block(
			kit,
			"Headboard",
			Vector3.new(width, headHeight, 0.35),
			CFrame.new(0, base + headHeight / 2, depth / 2 + 0.05),
			if level == 3 then DARK_WOOD else WOOD,
			Enum.Material.Wood
		)
		if level >= 2 then
			decor(
				block(
					kit,
					"HeadCap",
					Vector3.new(width + 0.3, 0.3, 0.5),
					CFrame.new(0, base + headHeight + 0.15, depth / 2 + 0.05),
					if level == 3 then GOLD else DARK_WOOD,
					if level == 3 then Enum.Material.Metal else Enum.Material.Wood
				)
			)
		end
		if level == 3 then
			local gem = decor(
				block(
					kit,
					"AmberGem",
					Vector3.new(0.6, 0.6, 0.2),
					CFrame.new(0, base + headHeight - 0.5, depth / 2 + 0.25) * CFrame.Angles(0, 0, math.rad(45)),
					AMBER
				)
			)
			glow(gem, AMBER, 8)
			-- Gema también en la cara de delante del cabecero (la que da a la almohada).
			decor(
				block(
					kit,
					"AmberGem",
					Vector3.new(0.6, 0.6, 0.2),
					CFrame.new(0, base + headHeight - 0.5, depth / 2 - 0.15) * CFrame.Angles(0, 0, math.rad(45)),
					AMBER,
					Enum.Material.Neon
				)
			)
			-- Postes del dosel con remate de oro en las esquinas de los pies.
			for side = -1, 1, 2 do
				block(
					kit,
					"CanopyPost",
					Vector3.new(0.3, 3, 0.3),
					CFrame.new(side * (width / 2 - 0.15), base + 1.5, -depth / 2 + 0.15),
					DARK_WOOD,
					Enum.Material.Wood
				)
				decor(
					block(
						kit,
						"Finial",
						Vector3.new(0.45, 0.45, 0.45),
						CFrame.new(side * (width / 2 - 0.15), base + 3.2, -depth / 2 + 0.15),
						GOLD,
						Enum.Material.Metal
					)
				)
			end
		end
		banner(kit, Vector3.new(width / 2 + 0.1, base, depth / 2 + 0.05), 3.5)
	end,

	-- Baúl: tablas (I), con flejes y esquinas de hierro (II), madera oscura con oro y cerradura de ámbar (III).
	Chest = function(kit)
		local base = plinth(kit, 3.6, 2.6)
		local level = kit.level
		local width, depth = 3.4, 2.4
		local height = 1.6 + (level - 1) * 0.2
		local wood = if level == 3 then DARK_WOOD else WOOD
		local metal = if level == 3 then GOLD else IRON
		block(
			kit,
			"Body",
			Vector3.new(width, height, depth),
			CFrame.new(0, base + height / 2, 0),
			wood,
			Enum.Material.WoodPlanks
		)
		-- Tapa en dos escalones (voxel).
		block(
			kit,
			"Lid",
			Vector3.new(width + 0.1, 0.4, depth + 0.1),
			CFrame.new(0, base + height + 0.2, 0),
			wood,
			Enum.Material.WoodPlanks
		)
		block(
			kit,
			"LidTop",
			Vector3.new(width, 0.35, depth * 0.6),
			CFrame.new(0, base + height + 0.57, 0),
			wood,
			Enum.Material.WoodPlanks
		)
		-- Flejes que dan la vuelta (se ven también por detrás).
		local bands = if level == 1 then 0 else 2
		for band = 1, bands do
			local x = (band - 1.5) * (width * 0.55)
			decor(
				block(
					kit,
					"Band",
					Vector3.new(0.25, height + 0.85, depth + 0.16),
					CFrame.new(x, base + (height + 0.75) / 2, 0),
					metal,
					Enum.Material.Metal
				)
			)
		end
		if level == 1 then
			-- Cuerda en lugar de flejes.
			decor(
				block(
					kit,
					"Rope",
					Vector3.new(width + 0.12, 0.18, depth + 0.12),
					CFrame.new(0, base + height * 0.6, 0),
					STRAW_DARK,
					Enum.Material.Fabric
				)
			)
		end
		if level >= 2 then
			for sideX = -1, 1, 2 do
				for sideZ = -1, 1, 2 do
					decor(
						block(
							kit,
							"Corner",
							Vector3.new(0.35, 0.35, 0.35),
							CFrame.new(sideX * width / 2, base + 0.17, sideZ * depth / 2),
							metal,
							Enum.Material.Metal
						)
					)
				end
			end
		end
		local lock = decor(
			block(
				kit,
				"Lock",
				Vector3.new(0.55, 0.6, 0.2),
				CFrame.new(0, base + height - 0.1, -depth / 2 - 0.1),
				if level == 3 then AMBER else metal,
				Enum.Material.Metal
			)
		)
		if level == 3 then
			glow(lock, AMBER, 7)
		end
		banner(kit, Vector3.new(width / 2 + 0.2, base, depth / 2 + 0.2), 3)
	end,

	-- Incubadora: lecho de paja con brasas (I), horno de piedra con ventana (II), basalto con cúpula de
	-- cristal y el resplandor de ámbar dentro (III).
	Incubator = function(kit)
		local base = plinth(kit, 3.6, 3.6)
		local level = kit.level
		local stone = if level == 3 then BASALT else STONE
		block(kit, "Base", Vector3.new(3.4, 0.8, 3.4), CFrame.new(0, base + 0.4, 0), stone, Enum.Material.Slate)
		local coals = decor(block(kit, "Coals", Vector3.new(1.6, 0.2, 1.6), CFrame.new(0, base + 0.85, 0), MAGMA))
		glow(coals, MAGMA, 6)
		block(kit, "Straw", Vector3.new(2.4, 0.4, 2.4), CFrame.new(0, base + 1.1, 0), STRAW, Enum.Material.Grass)
		-- Huevos de bloques en el lecho, uno por hueco del nido del Lobby (dos en el III): PlotService los
		-- pinta del color de la rareza del huevo que incuba el dueño y esconde los de un hueco vacío.
		for slot = 1, if level == 3 then 2 else 1 do
			local x = if level == 3 then (slot - 1.5) * 1.1 else 0
			local suffix = if slot == 1 then "" else tostring(slot)
			decor(block(kit, `Egg{suffix}`, Vector3.new(0.8, 1, 0.8), CFrame.new(x, base + 1.75, 0), FABRIC))
			decor(block(kit, `Egg{suffix}Top`, Vector3.new(0.5, 0.3, 0.5), CFrame.new(x, base + 2.4, 0), FABRIC))
		end
		if level == 1 then
			-- Tejadillo de paja sobre cuatro palos.
			for sideX = -1, 1, 2 do
				for sideZ = -1, 1, 2 do
					block(
						kit,
						"Stick",
						Vector3.new(0.25, 2.6, 0.25),
						CFrame.new(sideX * 1.5, base + 2.1, sideZ * 1.5),
						DARK_WOOD,
						Enum.Material.Wood
					)
				end
			end
			roof(kit, 3.6, 3.6, base + 3.3, 3)
		elseif level == 2 then
			-- Horno de piedra en escalones con ventana delante y chimenea detrás.
			for step = 0, 2 do
				local inset = step * 0.5
				local ring = 3.2 - inset * 2
				for side = -1, 1, 2 do
					block(
						kit,
						"Dome",
						Vector3.new(ring, 0.6, 0.35),
						CFrame.new(0, base + 1.1 + step * 0.6, side * (ring / 2 - 0.17)),
						STONE_DARK,
						Enum.Material.Slate
					)
					block(
						kit,
						"Dome",
						Vector3.new(0.35, 0.6, ring),
						CFrame.new(side * (ring / 2 - 0.17), base + 1.1 + step * 0.6, 0),
						STONE_DARK,
						Enum.Material.Slate
					)
				end
			end
			block(
				kit,
				"DomeTop",
				Vector3.new(1.4, 0.4, 1.4),
				CFrame.new(0, base + 2.9, 0),
				STONE_DARK,
				Enum.Material.Slate
			)
			decor(
				block(
					kit,
					"Pipe",
					Vector3.new(0.5, 1.4, 0.5),
					CFrame.new(0.9, base + 3.3, 1.1),
					IRON,
					Enum.Material.Metal
				)
			)
		else
			-- Cúpula de cristal con aros de oro y el ámbar que calienta encima.
			local dome = block(
				kit,
				"GlassDome",
				Vector3.new(2.8, 2, 2.8),
				CFrame.new(0, base + 2, 0),
				Color3.fromRGB(255, 220, 160),
				Enum.Material.Glass
			)
			dome.Transparency = 0.55
			for ring = 0, 1 do
				for side = -1, 1, 2 do
					decor(
						block(
							kit,
							"GoldRing",
							Vector3.new(2.9, 0.15, 0.15),
							CFrame.new(0, base + 1.2 + ring * 1.6, side * 1.43),
							GOLD,
							Enum.Material.Metal
						)
					)
					decor(
						block(
							kit,
							"GoldRing",
							Vector3.new(0.15, 0.15, 2.9),
							CFrame.new(side * 1.43, base + 1.2 + ring * 1.6, 0),
							GOLD,
							Enum.Material.Metal
						)
					)
				end
			end
			local heart = decor(
				block(
					kit,
					"AmberHeart",
					Vector3.new(0.6, 0.6, 0.6),
					CFrame.new(0, base + 3.3, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
					AMBER
				)
			)
			glow(heart, AMBER, 10)
			-- Vetas de lava en la base, por los cuatro lados.
			for side = -1, 1, 2 do
				decor(
					block(
						kit,
						"LavaVein",
						Vector3.new(1.8, 0.15, 0.1),
						CFrame.new(0, base + 0.4, side * 1.72),
						MAGMA,
						Enum.Material.Neon
					)
				)
				decor(
					block(
						kit,
						"LavaVein",
						Vector3.new(0.1, 0.15, 1.8),
						CFrame.new(side * 1.72, base + 0.4, 0),
						MAGMA,
						Enum.Material.Neon
					)
				)
			end
		end
		banner(kit, Vector3.new(1.75, base, 1.75), 3.5)
	end,

	-- Nido: anillo de palos (I), de troncos en dos capas con plumas (II), de piedra con oro, plumas de
	-- quetzal y gemas de ámbar (III).
	Nest = function(kit)
		local base = plinth(kit, 5.6, 5.6)
		local level = kit.level
		local radius = 2.5
		local segments = 8
		local layers = if level == 1 then 1 else 2
		local ringColor = if level == 3 then STONE else WOOD
		local ringMaterial = if level == 3 then Enum.Material.Slate else Enum.Material.Wood
		block(kit, "Floor", Vector3.new(4.4, 0.4, 4.4), CFrame.new(0, base + 0.2, 0), STRAW, Enum.Material.Grass)
		for layer = 1, layers do
			for segment = 1, segments do
				local angle = (segment + layer * 0.5) / segments * 2 * math.pi
				local length = 2 * radius * math.tan(math.pi / segments) + 0.3
				block(
					kit,
					"Ring",
					Vector3.new(length, 0.6, 0.6),
					CFrame.new(math.cos(angle) * radius, base + 0.1 + layer * 0.55, math.sin(angle) * radius)
						* CFrame.Angles(0, -angle + math.pi / 2, 0),
					if layer == 2 and level == 2 then DARK_WOOD else ringColor,
					ringMaterial
				)
			end
		end
		-- Huevos de bloques en el centro: uno (I), dos (II), tres (III).
		for egg = 1, level do
			local angle = egg / level * 2 * math.pi
			local offset = if level == 1
				then Vector3.zero
				else Vector3.new(math.cos(angle) * 0.7, 0, math.sin(angle) * 0.7)
			decor(
				block(
					kit,
					"Egg",
					Vector3.new(0.7, 0.9, 0.7),
					CFrame.new(offset + Vector3.new(0, base + 0.85, 0)),
					FABRIC
				)
			)
		end
		if level >= 2 then
			-- Plumas levantadas alrededor: pardas (II), azules y turquesa de quetzal (III).
			local feathers = if level == 3 then 8 else 4
			for feather = 1, feathers do
				local angle = (feather + 0.25) / feathers * 2 * math.pi
				local color = if level == 2 then STRAW_DARK elseif feather % 2 == 0 then FEATHER_BLUE else FEATHER_TEAL
				decor(
					block(
						kit,
						"Feather",
						Vector3.new(0.35, 1.3 + (level - 2) * 0.5, 0.12),
						CFrame.new(
							math.cos(angle) * (radius + 0.2),
							base + 1.6 + (level - 2) * 0.25,
							math.sin(angle) * (radius + 0.2)
						)
							* CFrame.Angles(0, -angle + math.pi / 2, 0)
							* CFrame.Angles(math.rad(15), 0, 0),
						color,
						Enum.Material.Fabric
					)
				)
			end
		end
		if level == 3 then
			for gem = 1, 4 do
				local angle = gem / 4 * 2 * math.pi + math.pi / 4
				local stone = decor(
					block(
						kit,
						"AmberGem",
						Vector3.new(0.45, 0.45, 0.45),
						CFrame.new(math.cos(angle) * radius, base + 1.4, math.sin(angle) * radius)
							* CFrame.Angles(0, angle, math.rad(45)),
						AMBER
					)
				)
				stone.Material = Enum.Material.Neon
			end
		end
		banner(kit, Vector3.new(2.6, base, 2.6), 3.5)
	end,
}

-- Crea la estructura "structureId" en su nivel (1–3) con su centro en el origen. Hay que moverla con
-- PivotTo.
function PlotModels.build(structureId: string, level: number): Model
	local definition = PlotStructures[structureId]
	local builder = BUILDERS[structureId]
	assert(definition and builder, `Estructura de parcela desconocida: {structureId}`)
	level = math.clamp(level, 1, #ROMAN)

	local model = Instance.new("Model")
	model.Name = `{definition.name} {ROMAN[level]}`
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
	builder({ model = model, size = definition.size, level = level, bottom = -definition.size.Y / 2 })
	VoxelMerge.mergeStatic(model)
	return model
end

return PlotModels
