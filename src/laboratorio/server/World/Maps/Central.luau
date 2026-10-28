--!strict
-- Mapa "Laboratorio central" del Laboratorio en ruinas (Fase 13, L2; docs/LABORATORIO.md §4): el
-- laboratorio del Proyecto PRIMAL, en ruinas entre los rascacielos comidos por la selva de la Ciudad
-- Perdida. Voxel: bloques en rejilla con pocos tonos planos (hormigón gris, metal oxidado, cristal
-- azulado, cables negros y amarillos y la selva entrando por las grietas; nunca verde brillante, que es
-- el color de la curación). Lo construye World/LabBuilder dentro de Workspace.LabMap.Central.
--
-- Forma: 160 (X, de oeste a este) × 120 (Z) studs, con el suelo en y = 0, simétrico de oeste a este
-- (x → -x) para que los dos bandos jueguen el mismo mapa:
--   - Al oeste, el muelle pirata (zona de salida de los Piratas): tablones sobre el agua y la proa de su
--     velero. Al este, la puerta de seguridad (la de los Guardianes): una esclusa blanca con franjas
--     azules y la compuerta blindada.
--   - Delante de cada zona, una explanada (|x| 52–64) que da a los tres carriles:
--       norte (z 30–56): el pasillo de las jaulas, quebrado en zigzag por muros y la sala de control;
--       centro (|z| < 22): la sala del reactor, abierta, con el núcleo (tapa la línea larga), cuatro
--         tanques de suero rotos como cobertura y una pasarela alta sobre el núcleo con dos escaleras;
--       sur (z -56…-30): el invernadero de bananas primales, con bancales bajos (paran los disparos) y
--         plátanos y helechos que tapan la vista pero no paran nada.
--   - Muros entre carriles con dos huecos por lado (|x| 10–18 y 32–40).
--
-- Piezas con nombre que lee el código, en <mapa>/Bases/<bando> ("Pirates" al oeste, "Guardians" al este):
--   "Spawn"    baldosa donde aparecen los del bando
--   "Zone"     volumen invisible de la zona de salida (ahí nadie hace ni recibe daño)
--   "Barrier"  las dos barreras de la boca de la zona: solo chocan con el bando rival (grupos de
--              colisión, LabParts.registerGroups), así que los de dentro salen y entran y el rival nunca entra
--   "Gate"     las dos compuertas de la boca: cerradas para todos antes de la partida (LabWorldService)
-- y en el mapa: "Derrumbes" (los cascotes que cierran el invernadero en 1v1 y 2v2; cada pieza se ve y
-- choca solo entonces) y "SpawnsLibres" (marcadores invisibles donde aparece cada uno en Todos contra todos,
-- fuera de las bases y de los derrumbes; LabParts.buildFreeSpawns los hace y los comprueba).
--
-- Coberturas que no se rompen (nada lleva la etiqueta de las destructibles). Lo decorativo va con
-- CanCollide, CanQuery y CanTouch en false. Las rejas de las jaulas chocan pero los disparos las cruzan
-- (grupo de colisión Config.Lab.WallGroup, que no choca con los rayos del combate). Ningún muro deja subirse: los muros miden WALL_HEIGHT y desde lo alto de la pasarela
-- no se llega. Barreras invisibles en los bordes y un techo invisible a CEILING_HEIGHT.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LabMapModels = require(ReplicatedStorage.Shared.LabMapModels)
local LabParts = require(script.Parent.Parent.LabParts)

local PALETTE = LabMapModels.PALETTE
local CONCRETE = PALETTE.CONCRETE
local CONCRETE_LIGHT = PALETTE.CONCRETE_LIGHT
local CONCRETE_DARK = PALETTE.CONCRETE_DARK
local RUST = PALETTE.RUST
local RUST_DARK = PALETTE.RUST_DARK
local STEEL = PALETTE.STEEL
local STEEL_DARK = PALETTE.STEEL_DARK
local GLASS = PALETTE.GLASS
local SERUM = PALETTE.SERUM
local HAZARD = PALETTE.HAZARD
local VINE = PALETTE.VINE
local SOIL = PALETTE.SOIL
local WOOD = PALETTE.WOOD
local WOOD_DARK = PALETTE.WOOD_DARK
local PIRATE_BLACK = PALETTE.PIRATE_BLACK
local LAB_WHITE = PALETTE.LAB_WHITE
local WATER = PALETTE.WATER
local JUNGLE_GROUND = PALETTE.JUNGLE_GROUND

-- Medidas de las zonas de salida y los muros (LabParts.buildZone). El suelo está en y = 0.
local GEOMETRY: LabParts.Geometry = {
	halfX = 64, -- la boca de las zonas de salida
	outerX = 80, -- el fondo de las zonas de salida
	halfZ = 16,
	mouthFrom = 6, -- cada boca de la zona va de |z| 6 a 14
	mouthTo = 14,
	wallHeight = 20,
	ceiling = 28,
	gateHeight = 12,
}

-- Mediodía nublado en la ciudad en ruinas: luz fría, sombras suaves y bruma azulada entre las torres.
local LIGHTING: LabParts.LightingPreset = {
	clockTime = 13.5,
	latitude = 10,
	brightness = 2,
	ambient = Color3.fromRGB(84, 90, 100),
	outdoorAmbient = Color3.fromRGB(128, 136, 148),
	atmosphere = {
		density = 0.36,
		offset = 0.1,
		color = Color3.fromRGB(176, 190, 204),
		decay = Color3.fromRGB(96, 110, 124),
		glare = 0,
		haze = 2,
	},
	colorCorrection = { contrast = 0.08, saturation = -0.06, tint = Color3.fromRGB(236, 242, 250) },
}

-- Semilla del decorado al azar (tonos, cables, lianas): el mismo mapa en cada construcción.
local SEED = 1313
-- Altura de la vista cenital del espectador (LabSpectateController) sobre el centro del mapa.
local OVERHEAD_HEIGHT = 150

local ZONE_OUTER_X = GEOMETRY.outerX
local ZONE_HALF_Z = GEOMETRY.halfZ
local HALF_X = GEOMETRY.halfX
local WALL_HEIGHT = GEOMETRY.wallHeight
local CEILING_HEIGHT = GEOMETRY.ceiling
local HALF_Z = 56 -- la cara de dentro de los muros norte y sur
local STAGING_X = 52 -- desde aquí hasta la boca de la zona, la explanada
local LANE_WALL_IN, LANE_WALL_OUT = 22, 30 -- muros entre carriles (|z|)
local LANE_GAPS = { { 10, 18 }, { 32, 40 } } -- huecos de esos muros (|x|)
local WALL_THICKNESS = 2
local BRIDGE_TOP = 10 -- suelo de la pasarela
local BRIDGE_HALF_X = 3
local BRIDGE_HALF_Z = 9 -- la pasarela va de z -9 a 9; de ahí bajan las escaleras
local STEP_DEPTH = 1.2
local CORE_HALF = 5
local CORE_HEIGHT = 8
-- Puntos de aparición libres (Todos contra todos), simétricos de oeste a este. Cada uno tiene a su
-- alrededor (±2 de reparto y el cuerpo) suelo despejado: ni muros, ni coberturas, ni la base ni los derrumbes.
--   (±30, ±4)   sala del reactor: entre el núcleo, los tanques (x 19–25) y las cajas (x 32+ y 38+)
--   (±47, ±14)  explanada: delante de la zona (x 64), a 8 del muro de carriles (z 22)
--   (±32, 36)   pasillo de las jaulas: entre el muro (x 22–24) y las jaulas (z 47+), a 6 del muro (z 30)
--   (±34, -44)  invernadero: entre bancales (x 24,5–27,5 y 40,5–43,5), lejos de los derrumbes (|x| 50+)
local FREE_SPAWNS: { LabParts.FreeSpawnPoint } = {
	{ x = -30, z = 4 },
	{ x = 30, z = 4 },
	{ x = -30, z = -4 },
	{ x = 30, z = -4 },
	{ x = -47, z = 14 },
	{ x = 47, z = 14 },
	{ x = -47, z = -14 },
	{ x = 47, z = -14 },
	{ x = -32, z = 36 },
	{ x = 32, z = 36 },
	{ x = -34, z = -44 },
	{ x = 34, z = -44 },
}

local block = LabParts.block
local between = LabParts.between
local decor = LabParts.decor
local solid = LabParts.solid
local barrier = LabParts.barrier
local tone = LabParts.tone
local hazardStripe = LabParts.hazardStripe
local cable = LabParts.cable
local vine = LabParts.vine
local crate = LabParts.crate
local serumTank = LabParts.serumTank
local cage = LabParts.cage
local bananaPlant = LabParts.bananaPlant

-- Muro de la altura de los del mapa (WALL_HEIGHT), salvo que se diga otra.
local function wall(parent: Instance, x1: number, z1: number, x2: number, z2: number, height: number?)
	return LabParts.wall(parent, x1, z1, x2, z2, height or WALL_HEIGHT)
end

-- Cascotes de la altura de los muros del mapa.
local function rubble(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	LabParts.rubble(parent, x1, z1, x2, z2, WALL_HEIGHT)
end

local function buildGround(folder: Instance)
	-- La selva alrededor (se ve por las grietas y desde lo alto de la pasarela).
	local outside =
		block("Selva", Vector3.new(1400, 2, 1400), CFrame.new(0, -1.2, 0), JUNGLE_GROUND, Enum.Material.Grass, folder)
	outside.Locked = true
	-- El suelo del laboratorio: baldosas de 8 × 8 en dos tonos, con alguna rota.
	local floor = Instance.new("Folder")
	floor.Name = "Suelo"
	floor.Parent = folder
	for x = -HALF_X, HALF_X - 8, 8 do
		for z = -HALF_Z, HALF_Z - 8, 8 do
			local even = ((x + z) / 8) % 2 == 0
			local color = if even then CONCRETE_LIGHT else CONCRETE
			local tile = between("Baldosa", x, z, x + 8, z + 8, -1, 1, tone(color, 0.05), Enum.Material.Concrete, floor)
			tile.Locked = true
			-- Grietas con hierba que asoma.
			if LabParts.rng:NextNumber() < 0.12 then
				decor(
					block(
						"Grieta",
						Vector3.new(LabParts.rng:NextNumber(2, 5), 0.12, 0.6),
						CFrame.new(x + 4, 0.05, z + 4) * CFrame.Angles(0, LabParts.rng:NextNumber(0, math.pi), 0),
						VINE,
						Enum.Material.Grass,
						floor
					)
				)
			end
		end
	end
end

-- Muros de fuera: norte y sur a lo largo de todo, y los tramos de |x| = HALF_X fuera de las zonas.
local function buildBoundary(folder: Instance)
	local walls = Instance.new("Folder")
	walls.Name = "Muros"
	walls.Parent = folder
	for _, sideZ in { -1, 1 } do
		local inner = sideZ * HALF_Z
		wall(walls, -HALF_X - WALL_THICKNESS, inner, HALF_X + WALL_THICKNESS, inner + sideZ * WALL_THICKNESS)
	end
	for _, sideX in { -1, 1 } do
		local inner = sideX * HALF_X
		for _, sideZ in { -1, 1 } do
			wall(walls, inner, sideZ * (ZONE_HALF_Z + WALL_THICKNESS), inner + sideX * WALL_THICKNESS, sideZ * HALF_Z)
		end
	end
	-- Barreras invisibles por encima de los muros y techo.
	barrier(-ZONE_OUTER_X - 4, HALF_Z, ZONE_OUTER_X + 4, HALF_Z + 4, WALL_HEIGHT, CEILING_HEIGHT - WALL_HEIGHT, walls)
	barrier(-ZONE_OUTER_X - 4, -HALF_Z - 4, ZONE_OUTER_X + 4, -HALF_Z, WALL_HEIGHT, CEILING_HEIGHT - WALL_HEIGHT, walls)
	barrier(-ZONE_OUTER_X - 4, -HALF_Z - 4, ZONE_OUTER_X + 4, HALF_Z + 4, CEILING_HEIGHT, 2, walls)
	for _, sideX in { -1, 1 } do
		local inner = sideX * HALF_X
		for _, sideZ in { -1, 1 } do
			barrier(
				inner,
				sideZ * (ZONE_HALF_Z + WALL_THICKNESS),
				inner + sideX * WALL_THICKNESS,
				sideZ * HALF_Z,
				WALL_HEIGHT,
				CEILING_HEIGHT - WALL_HEIGHT,
				walls
			)
		end
	end
	-- Cables de un muro a otro sobre la sala del reactor.
	for _, x in { -40, -20, 20, 40 } do
		cable(
			walls,
			Vector3.new(x, WALL_HEIGHT - 1, LANE_WALL_IN),
			Vector3.new(x + 6, WALL_HEIGHT - 1, -LANE_WALL_IN),
			5
		)
	end
end

-- Muros entre carriles (|z| de LANE_WALL_IN a LANE_WALL_OUT), con sus huecos.
local function buildLaneWalls(folder: Instance)
	local walls = Instance.new("Folder")
	walls.Name = "MurosCarriles"
	walls.Parent = folder
	-- Tramos entre huecos, de oeste a este.
	local cuts = { -STAGING_X }
	for index = #LANE_GAPS, 1, -1 do
		table.insert(cuts, -LANE_GAPS[index][2])
		table.insert(cuts, -LANE_GAPS[index][1])
	end
	for _, gap in LANE_GAPS do
		table.insert(cuts, gap[1])
		table.insert(cuts, gap[2])
	end
	table.insert(cuts, STAGING_X)
	for _, sideZ in { -1, 1 } do
		for index = 1, #cuts, 2 do
			wall(walls, cuts[index], sideZ * LANE_WALL_IN, cuts[index + 1], sideZ * LANE_WALL_OUT)
		end
		-- Franjas de peligro en el suelo de cada hueco.
		for _, gap in LANE_GAPS do
			for _, sideX in { -1, 1 } do
				hazardStripe(
					walls,
					Vector3.new(sideX * (gap[1] + gap[2]) / 2, 0.05, sideZ * (LANE_WALL_IN + LANE_WALL_OUT) / 2),
					gap[2] - gap[1],
					false
				)
			end
		end
	end
end

-- El velero pirata amarrado junto al muelle (decorado, fuera del mapa) y el agua.
local function buildDockOutside(folder: Instance)
	local outside = Instance.new("Folder")
	outside.Name = "Muelle"
	outside.Parent = folder
	decor(
		between("Agua", -260, -200, -ZONE_OUTER_X - WALL_THICKNESS, 200, -0.9, 1, WATER, Enum.Material.Glass, outside)
	).Transparency =
		0.15
	-- Casco: bloques escalonados que se estrechan hacia la proa (hacia el norte), madera oscura con una
	-- franja dorada y la cubierta clara; a popa, el castillo con sus ventanas doradas.
	local hullX = -ZONE_OUTER_X - 16
	for index, width in { 16, 15, 14, 12, 9, 6 } do
		local z = -26 + index * 7
		decor(
			block(
				"Casco",
				Vector3.new(width, 8, 7),
				CFrame.new(hullX, 3, z),
				WOOD_DARK,
				Enum.Material.WoodPlanks,
				outside
			)
		)
		decor(
			block(
				"FranjaCasco",
				Vector3.new(width + 0.2, 0.6, 7.02),
				CFrame.new(hullX, 5.2, z),
				Config.Lab.Teams.Pirates.color,
				Enum.Material.Metal,
				outside
			)
		)
		decor(
			block(
				"Cubierta",
				Vector3.new(width - 1, 0.4, 7),
				CFrame.new(hullX, 7.2, z),
				WOOD,
				Enum.Material.WoodPlanks,
				outside
			)
		)
	end
	decor(
		block(
			"Castillo",
			Vector3.new(14, 5, 7),
			CFrame.new(hullX, 9.5, -19),
			PIRATE_BLACK,
			Enum.Material.WoodPlanks,
			outside
		)
	)
	for _, offset in { -4, 0, 4 } do
		local window = decor(
			block(
				"Ventana",
				Vector3.new(14.1, 1.4, 1.4),
				CFrame.new(hullX, 9.8, -19 + offset * 0.75),
				Config.Lab.Teams.Pirates.color,
				Enum.Material.Neon,
				outside
			)
		)
		window.CastShadow = false
	end
	-- Mástil, vela negra y bandera.
	decor(block("Mastil", Vector3.new(1.5, 34, 1.5), CFrame.new(hullX, 22, 0), WOOD, Enum.Material.Wood, outside))
	decor(
		block(
			"Vela",
			Vector3.new(0.6, 16, 18),
			CFrame.new(hullX + 1.2, 24, 0),
			PIRATE_BLACK,
			Enum.Material.Fabric,
			outside
		)
	)
	decor(block("Calavera", Vector3.new(0.7, 4, 4), CFrame.new(hullX + 1.6, 25, 0), LAB_WHITE, nil, outside))
	decor(
		block(
			"Bandera",
			Vector3.new(0.3, 3, 5),
			CFrame.new(hullX, 40, 2.5),
			PIRATE_BLACK,
			Enum.Material.Fabric,
			outside
		)
	)
end

-- Núcleo del reactor (tapa la línea larga del centro): basa de metal, cuerpo de hormigón con rendijas
-- por las que se ve el brillo azul, y tuberías.
local function buildCore(parent: Instance)
	local core = Instance.new("Model")
	core.Name = "Reactor"
	core.Parent = parent
	between(
		"Basa",
		-CORE_HALF - 1,
		-CORE_HALF - 1,
		CORE_HALF + 1,
		CORE_HALF + 1,
		0,
		1,
		STEEL_DARK,
		Enum.Material.DiamondPlate,
		core
	)
	between(
		"Nucleo",
		-CORE_HALF,
		-CORE_HALF,
		CORE_HALF,
		CORE_HALF,
		1,
		CORE_HEIGHT - 1,
		CONCRETE_DARK,
		Enum.Material.Concrete,
		core
	)
	-- Rendijas brillantes en las cuatro caras.
	for _, face in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		for _, offset in { -2.5, 0, 2.5 } do
			local along = Vector3.new(face.Z, 0, face.X) * offset
			local glow = block(
				"Rendija",
				Vector3.new(1, 4, 1) - Vector3.new(math.abs(face.X), 0, math.abs(face.Z)) * 0.8,
				CFrame.new(face * (CORE_HALF + 0.05) + along + Vector3.new(0, 4, 0)),
				SERUM,
				Enum.Material.Neon,
				core
			)
			decor(glow)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = SERUM
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = core:FindFirstChild("Nucleo")
	-- Tuberías del núcleo a los muros (decorado, por el suelo).
	for _, sideX in { -1, 1 } do
		solid(
			between(
				"Tuberia",
				sideX * CORE_HALF,
				-0.6,
				sideX * 18,
				0.6,
				0,
				1.2,
				RUST,
				Enum.Material.CorrodedMetal,
				core
			)
		)
	end
end

-- Pasarela alta sobre el núcleo (de z -9 a 9) con barandillas, pilares y una escalera en cada punta.
local function buildBridge(parent: Instance)
	local bridge = Instance.new("Model")
	bridge.Name = "Pasarela"
	bridge.Parent = parent
	between(
		"Suelo",
		-BRIDGE_HALF_X,
		-BRIDGE_HALF_Z,
		BRIDGE_HALF_X,
		BRIDGE_HALF_Z,
		BRIDGE_TOP - 1,
		1,
		STEEL,
		Enum.Material.DiamondPlate,
		bridge
	)
	for _, sideX in { -1, 1 } do
		-- Barandillas (chocan: no se cae por los lados) con su pasamanos amarillo.
		between(
			"Barandilla",
			sideX * BRIDGE_HALF_X,
			-BRIDGE_HALF_Z,
			sideX * (BRIDGE_HALF_X - 0.4),
			BRIDGE_HALF_Z,
			BRIDGE_TOP,
			2.5,
			STEEL_DARK,
			Enum.Material.DiamondPlate,
			bridge
		)
		decor(
			between(
				"Pasamanos",
				sideX * (BRIDGE_HALF_X + 0.05),
				-BRIDGE_HALF_Z,
				sideX * (BRIDGE_HALF_X - 0.45),
				BRIDGE_HALF_Z,
				BRIDGE_TOP + 2.5,
				0.4,
				HAZARD,
				nil,
				bridge
			)
		)
		for _, sideZ in { -1, 1 } do
			block(
				"Pilar",
				Vector3.new(1, BRIDGE_TOP - 1, 1),
				CFrame.new(sideX * (BRIDGE_HALF_X - 0.5), (BRIDGE_TOP - 1) / 2, sideZ * (BRIDGE_HALF_Z - 0.5)),
				STEEL_DARK,
				nil,
				bridge
			)
		end
	end
	-- Escaleras: un peldaño por cada stud de alto, macizos hasta el suelo.
	for _, sideZ in { -1, 1 } do
		for step = 1, BRIDGE_TOP do
			local top = BRIDGE_TOP - step
			local z1 = sideZ * (BRIDGE_HALF_Z + (step - 1) * STEP_DEPTH)
			local z2 = sideZ * (BRIDGE_HALF_Z + step * STEP_DEPTH)
			if top > 0 then
				between(
					"Peldaño",
					-BRIDGE_HALF_X,
					z1,
					BRIDGE_HALF_X,
					z2,
					0,
					top,
					if step % 2 == 0 then STEEL else STEEL_DARK,
					Enum.Material.DiamondPlate,
					bridge
				)
			end
		end
	end
end

local function buildReactor(folder: Instance)
	local hall = Instance.new("Folder")
	hall.Name = "SalaReactor"
	hall.Parent = folder
	buildCore(hall)
	buildBridge(hall)
	for _, sideX in { -1, 1 } do
		for _, sideZ in { -1, 1 } do
			serumTank(hall, Vector3.new(sideX * 22, 0, sideZ * 11))
		end
		-- Cajas en la explanada y a la entrada de la sala.
		crate(hall, Vector3.new(sideX * 40, 0, 0), 4, RUST)
		crate(hall, Vector3.new(sideX * 34, 0, 15), 3, STEEL)
		crate(hall, Vector3.new(sideX * 34, 0, -15), 3, STEEL)
		crate(hall, Vector3.new(sideX * 58, 0, 34), 4, RUST_DARK)
		crate(hall, Vector3.new(sideX * 58, 0, -34), 4, RUST_DARK)
		crate(hall, Vector3.new(sideX * 57, 0, 0), 3, STEEL)
	end
	-- Suelo del reactor: un círculo de franjas alrededor del núcleo.
	hazardStripe(hall, Vector3.new(0, 0.05, CORE_HALF + 3), 12, false)
	hazardStripe(hall, Vector3.new(0, 0.05, -CORE_HALF - 3), 12, false)
end

local function buildCages(folder: Instance)
	local lane = Instance.new("Folder")
	lane.Name = "PasilloJaulas"
	lane.Parent = folder
	-- Sala de control en el centro (maciza: el pasillo la rodea por arriba y por abajo).
	wall(lane, -8, 42, 8, 50)
	decor(between("Ventanal", -6, 41.9, 6, 42, 9, 4, GLASS, Enum.Material.Glass, lane)).Transparency = 0.3
	for _, sideX in { -1, 1 } do
		-- Zigzag: un muro corta la mitad sur y el siguiente la mitad norte.
		wall(lane, sideX * 22, LANE_WALL_OUT, sideX * (22 + WALL_THICKNESS), 44)
		wall(lane, sideX * 42, 42, sideX * (42 + WALL_THICKNESS), HALF_Z)
		cage(lane, Vector3.new(sideX * 32, 0, 50), 6, false)
		cage(lane, Vector3.new(sideX * 15, 0, 38), 4, sideX == 1)
		cage(lane, Vector3.new(sideX * 48, 0, 36), 5, false)
	end
	-- Una jaula reventada en medio, delante de la sala de control.
	cage(lane, Vector3.new(0, 0, 36), 6, true)
	for _, x in { -30, 0, 30 } do
		cable(lane, Vector3.new(x - 6, WALL_HEIGHT - 1, HALF_Z), Vector3.new(x + 6, WALL_HEIGHT - 1, LANE_WALL_OUT), 6)
	end
end

local function buildGreenhouse(folder: Instance)
	local lane = Instance.new("Folder")
	lane.Name = "Invernadero"
	lane.Parent = folder
	-- Bancales bajos (paran los disparos), con tierra y plataneras.
	for _, x in { -42, -26, -10, 10, 26, 42 } do
		between("Bancal", x - 1.5, -50, x + 1.5, -36, 0, 3, WOOD_DARK, Enum.Material.WoodPlanks, lane)
		decor(between("Tierra", x - 1.3, -49.8, x + 1.3, -36.2, 3, 0.2, SOIL, Enum.Material.Ground, lane))
		for _, z in { -47, -43, -39 } do
			bananaPlant(lane, Vector3.new(x + LabParts.rng:NextNumber(-0.4, 0.4), 3, z), LabParts.rng:NextNumber(5, 7))
		end
	end
	-- Helechos entre bancales (tapan la vista a la altura de la cara).
	for _, x in { -34, -18, 0, 18, 34 } do
		for _, z in { -52, -44, -34 } do
			bananaPlant(lane, Vector3.new(x + LabParts.rng:NextNumber(-1, 1), 0, z), LabParts.rng:NextNumber(4.5, 5.5))
		end
	end
	-- Armazón del techo de cristal, roto: vigas y algunos paneles.
	for x = -48, 48, 12 do
		decor(between("Viga", x - 0.4, -HALF_Z, x + 0.4, -LANE_WALL_OUT, 16, 0.8, STEEL_DARK, nil, lane))
	end
	for _ = 1, 10 do
		local x = LabParts.rng:NextInteger(-4, 3) * 12
		local z = LabParts.rng:NextNumber(-52, -34)
		local pane = decor(
			block("PanelCristal", Vector3.new(11, 0.2, 6), CFrame.new(x + 6, 16.2, z), GLASS, Enum.Material.Glass, lane)
		)
		pane.Transparency = 0.4
	end
	-- Lianas por las vigas.
	for x = -48, 48, 24 do
		vine(lane, Vector3.new(x, 16, -44), Vector3.zAxis, LabParts.rng:NextNumber(4, 8))
	end
end

local function buildCollapse(folder: Instance)
	local collapse = Instance.new("Folder")
	collapse.Name = "Derrumbes"
	collapse.Parent = folder
	for _, sideX in { -1, 1 } do
		rubble(collapse, sideX * (STAGING_X - 2), -HALF_Z, sideX * (STAGING_X + 2), -LANE_WALL_OUT)
		for _, gap in LANE_GAPS do
			rubble(collapse, sideX * gap[1], -LANE_WALL_OUT, sideX * gap[2], -LANE_WALL_IN)
		end
	end
end

-- Construye el mapa en coordenadas locales dentro de "model" (LabBuilder lo coloca después). El orden de las
-- llamadas fija la serie del Random: no lo cambies.
local function build(model: Model)
	buildGround(model)
	buildBoundary(model)
	buildLaneWalls(model)
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	LabParts.buildZone(bases, "Pirates", -1, GEOMETRY)
	LabParts.buildZone(bases, "Guardians", 1, GEOMETRY)
	bases.Parent = model
	buildDockOutside(model)
	buildReactor(model)
	buildCages(model)
	buildGreenhouse(model)
	buildCollapse(model)
	LabParts.buildFreeSpawns(model, FREE_SPAWNS)
	LabParts.buildSkyline(model)
end

return {
	GEOMETRY = GEOMETRY,
	LIGHTING = LIGHTING,
	SEED = SEED,
	OVERHEAD_HEIGHT = OVERHEAD_HEIGHT,
	build = build,
}
