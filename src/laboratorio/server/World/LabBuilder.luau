--!strict
-- Mapa "Laboratorio central" del Laboratorio en ruinas (Fase 13, L2; docs/LABORATORIO.md §4): el
-- laboratorio del Proyecto PRIMAL, en ruinas entre los rascacielos comidos por la selva de la Ciudad
-- Perdida. Voxel: bloques en rejilla con pocos tonos planos (hormigón gris, metal oxidado, cristal
-- azulado, cables negros y amarillos y la selva entrando por las grietas; nunca verde brillante, que es
-- el color de la curación).
--
-- Lo construye solo el servidor del Laboratorio al arrancar si no existe Workspace.LabMap o es de otra
-- versión (LabWorldService). Para dejarlo fijo en el place, ejecútalo en Studio, en modo edición, desde la
-- barra de comandos:
--
--   require(game.ServerScriptService.Server.World.LabBuilder).build()
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
-- Piezas con nombre que lee el código, en LabMap/Bases/<bando> ("Pirates" al oeste, "Guardians" al este):
--   "Spawn"    baldosa donde aparecen los del bando
--   "Zone"     volumen invisible de la zona de salida (ahí nadie hace ni recibe daño)
--   "Barrier"  las dos barreras de la boca de la zona: solo chocan con el bando rival (grupos de
--              colisión, registerGroups), así que los de dentro salen y entran y el rival nunca entra
--   "Gate"     las dos compuertas de la boca: cerradas para todos antes de la partida (LabWorldService)
-- y en LabMap: "Derrumbes" (los cascotes que cierran el invernadero en 1v1 y 2v2; cada pieza se ve y
-- choca solo entonces) y "SpawnsLibres" (marcadores invisibles donde aparece cada uno en Todos contra todos,
-- fuera de las bases y de los derrumbes; buildFreeSpawns los hace y los comprueba, y cada mapa los trae).
--
-- Coberturas que no se rompen (nada lleva la etiqueta de las destructibles). Lo decorativo va con
-- CanCollide, CanQuery y CanTouch en false. Las rejas de las jaulas chocan pero los disparos las cruzan
-- (CanQuery false). Ningún muro deja subirse: los muros miden WALL_HEIGHT y desde lo alto de la pasarela
-- no se llega. Barreras invisibles en los bordes y un techo invisible a CEILING_HEIGHT.
--
-- ⚠️ Borra la carpeta Workspace.LabMap, la sala de pruebas de la L1, la Baseplate y los SpawnLocation
-- sueltos antes de construir.

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

export type Options = { force: boolean? }

local FOLDER_NAME = "LabMap"
-- Sube este número al cambiar el mapa: los places con una versión anterior guardada se reconstruyen
-- solos al arrancar (LabWorldService).
local VERSION = 2
-- Semilla del decorado al azar (tonos, cables, lianas): el mismo mapa en cada construcción.
local SEED = 1313

-- Medidas (studs). El suelo está en y = 0.
local HALF_X = 64 -- la boca de las zonas de salida
local ZONE_OUTER_X = 80 -- el fondo de las zonas de salida
local HALF_Z = 56 -- la cara de dentro de los muros norte y sur
local STAGING_X = 52 -- desde aquí hasta la boca de la zona, la explanada
local ZONE_HALF_Z = 16
local MOUTH_FROM, MOUTH_TO = 6, 14 -- cada boca de la zona va de |z| 6 a 14
local LANE_WALL_IN, LANE_WALL_OUT = 22, 30 -- muros entre carriles (|z|)
local LANE_GAPS = { { 10, 18 }, { 32, 40 } } -- huecos de esos muros (|x|)
local WALL_HEIGHT = 20
local WALL_THICKNESS = 2
local CEILING_HEIGHT = 28
local BRIDGE_TOP = 10 -- suelo de la pasarela
local BRIDGE_HALF_X = 3
local BRIDGE_HALF_Z = 9 -- la pasarela va de z -9 a 9; de ahí bajan las escaleras
local STEP_DEPTH = 1.2
local CORE_HALF = 5
local CORE_HEIGHT = 8
-- Puntos de aparición libres (Todos contra todos), simétricos de oeste a este: x, z. Cada uno tiene a su
-- alrededor (±2 de reparto y el cuerpo) suelo despejado: ni muros, ni coberturas, ni la base ni los derrumbes.
--   (±30, ±4)   sala del reactor: entre el núcleo, los tanques (x 19–25) y las cajas (x 32+ y 38+)
--   (±47, ±14)  explanada: delante de la zona (x 64), a 8 del muro de carriles (z 22)
--   (±32, 36)   pasillo de las jaulas: entre el muro (x 22–24) y las jaulas (z 47+), a 6 del muro (z 30)
--   (±34, -44)  invernadero: entre bancales (x 24,5–27,5 y 40,5–43,5), lejos de los derrumbes (|x| 50+)
local FREE_SPAWNS = {
	{ -30, 4 },
	{ 30, 4 },
	{ -30, -4 },
	{ 30, -4 },
	{ -47, 14 },
	{ 47, 14 },
	{ -47, -14 },
	{ 47, -14 },
	{ -32, 36 },
	{ 32, 36 },
	{ -34, -44 },
	{ 34, -44 },
}

local CONCRETE = Color3.fromRGB(150, 150, 146)
local CONCRETE_LIGHT = Color3.fromRGB(176, 176, 172)
local CONCRETE_DARK = Color3.fromRGB(104, 104, 102)
local RUST = Color3.fromRGB(140, 82, 50)
local RUST_DARK = Color3.fromRGB(96, 58, 38)
local STEEL = Color3.fromRGB(92, 98, 106)
local STEEL_DARK = Color3.fromRGB(58, 62, 68)
local GLASS = Color3.fromRGB(150, 196, 220) -- cristal azulado
local SERUM = Color3.fromRGB(80, 170, 235) -- el brillo azul del reactor y los tanques
local CABLE = Color3.fromRGB(28, 28, 30)
local HAZARD = Color3.fromRGB(236, 190, 40) -- franjas amarillas y negras
local VINE = Color3.fromRGB(58, 84, 48) -- selva oscura y apagada
local VINE_DARK = Color3.fromRGB(42, 62, 38)
local LEAF = Color3.fromRGB(70, 98, 54)
local BANANA = Color3.fromRGB(214, 180, 60)
local SOIL = Color3.fromRGB(78, 56, 40)
local WOOD = Color3.fromRGB(116, 80, 48)
local WOOD_DARK = Color3.fromRGB(78, 52, 32)
local PIRATE_BLACK = Color3.fromRGB(34, 31, 30)
local LAB_WHITE = Color3.fromRGB(226, 230, 234)
local WATER = Color3.fromRGB(46, 84, 104)
local JUNGLE_GROUND = Color3.fromRGB(56, 66, 44)

local LabBuilder = {}

LabBuilder.NAME = FOLDER_NAME

local rng = Random.new(SEED)

-- Grupos de colisión: el del personaje de cada bando y el de las barreras de la zona de salida de cada
-- bando (que solo chocan con el personaje del otro).
function LabBuilder.characterGroup(teamId: string): string
	return `LabEquipo_{teamId}`
end

function LabBuilder.barrierGroup(teamId: string): string
	return `LabBarrera_{teamId}`
end

function LabBuilder.registerGroups()
	for _, teamId in Config.Lab.TeamOrder do
		for _, group in { LabBuilder.characterGroup(teamId), LabBuilder.barrierGroup(teamId) } do
			if not PhysicsService:IsCollisionGroupRegistered(group) then
				PhysicsService:RegisterCollisionGroup(group)
			end
		end
	end
	for _, owner in Config.Lab.TeamOrder do
		for _, teamId in Config.Lab.TeamOrder do
			PhysicsService:CollisionGroupSetCollidable(
				LabBuilder.barrierGroup(owner),
				LabBuilder.characterGroup(teamId),
				teamId ~= owner
			)
		end
	end
end

local function block(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Bloque entre dos esquinas (x1, z1) y (x2, z2), de "height" de alto desde "bottom".
local function between(
	name: string,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	bottom: number,
	height: number,
	color: Color3,
	material: Enum.Material?,
	parent: Instance
): Part
	local size = Vector3.new(math.abs(x2 - x1), height, math.abs(z2 - z1))
	local center = Vector3.new((x1 + x2) / 2, bottom + height / 2, (z1 + z2) / 2)
	return block(name, size, CFrame.new(center), color, material, parent)
end

-- Pieza que no se ve ni choca ni la encuentran los rayos (marcas para el código).
local function marker(part: BasePart)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- Decorado: se ve pero no choca ni lo encuentran los rayos. Las piezas pequeñas no dan sombra.
local function decor(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	if part.Size.Magnitude < 8 then
		part.CastShadow = false
	end
	return part
end

-- Barrera invisible: choca con los personajes, pero no la encuentran los rayos (ni la cámara ni los
-- disparos).
local function barrier(x1: number, z1: number, x2: number, z2: number, bottom: number, height: number, parent: Instance)
	local part = between("Barrera", x1, z1, x2, z2, bottom, height, CONCRETE, nil, parent)
	part.Transparency = 1
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- Variación de tono para que el hormigón repetido no parezca de plástico.
local function tone(color: Color3, amount: number?): Color3
	return color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, amount or 0.1))
end

local function applyLighting()
	-- Mediodía nublado en la ciudad en ruinas: luz fría, sombras suaves y bruma azulada entre las torres.
	Lighting.ClockTime = 13.5
	Lighting.GeographicLatitude = 10
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(84, 90, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 136, 148)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.36
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(176, 190, 204)
	atmosphere.Decay = Color3.fromRGB(96, 110, 124)
	atmosphere.Glare = 0
	atmosphere.Haze = 2
	atmosphere.Parent = Lighting
	local grade = (Lighting:FindFirstChild("ColorLaboratorio") :: ColorCorrectionEffect?)
		or Instance.new("ColorCorrectionEffect")
	grade.Name = "ColorLaboratorio"
	grade.Parent = Lighting
	grade.TintColor = Color3.fromRGB(236, 242, 250)
	grade.Saturation = -0.06
	grade.Contrast = 0.08
end

-- Franjas de peligro (amarillo y negro) a lo largo de X, de "length" studs, en el suelo.
local function hazardStripe(parent: Instance, center: Vector3, length: number, alongZ: boolean)
	local count = math.floor(length / 2)
	for index = 0, count - 1 do
		local offset = (index - (count - 1) / 2) * 2
		local position = center + (if alongZ then Vector3.new(0, 0, offset) else Vector3.new(offset, 0, 0))
		local size = if alongZ then Vector3.new(1.5, 0.1, 2) else Vector3.new(2, 0.1, 1.5)
		decor(
			block(
				"Franja",
				size,
				CFrame.new(position),
				if index % 2 == 0 then HAZARD else CABLE,
				Enum.Material.SmoothPlastic,
				parent
			)
		)
	end
end

-- Cable que cuelga de "from" a "to", combado: tres tramos rectos.
local function cable(parent: Instance, from: Vector3, to: Vector3, sag: number)
	local middle = (from + to) / 2 - Vector3.new(0, sag, 0)
	local points = {
		from,
		(from + middle) / 2 - Vector3.new(0, sag * 0.25, 0),
		middle,
		(middle + to) / 2 - Vector3.new(0, sag * 0.25, 0),
		to,
	}
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		decor(
			block(
				"Cable",
				Vector3.new(0.3, 0.3, (b - a).Magnitude),
				CFrame.lookAt((a + b) / 2, b),
				CABLE,
				Enum.Material.SmoothPlastic,
				parent
			)
		)
	end
end

-- Liana que baja por una pared desde "top" (en la cara del muro que mira a "facing"): bloques de hojas
-- oscuras escalonados.
local function vine(parent: Instance, top: Vector3, facing: Vector3, length: number)
	local position = top
	for index = 1, math.floor(length / 1.5) do
		local wobble = rng:NextInteger(-1, 1) * 0.5
		local side = if math.abs(facing.X) > 0.5 then Vector3.new(0, 0, wobble) else Vector3.new(wobble, 0, 0)
		position = position - Vector3.new(0, 1.5, 0) + side
		decor(
			block(
				"Liana",
				Vector3.new(1.2, 1.5, 1.2) - Vector3.new(math.abs(facing.X), 0, math.abs(facing.Z)) * 0.8,
				CFrame.new(position + facing * 0.25),
				if index % 3 == 0 then VINE_DARK else VINE,
				Enum.Material.Grass,
				parent
			)
		)
	end
end

-- Muro de hormigón entre dos esquinas, con un zócalo oscuro, una franja de cables arriba y alguna liana.
local function wall(parent: Instance, x1: number, z1: number, x2: number, z2: number, height: number?)
	local h = height or WALL_HEIGHT
	local part = between("Muro", x1, z1, x2, z2, 0, h, tone(CONCRETE), Enum.Material.Concrete, parent)
	local sizeX, sizeZ = math.abs(x2 - x1), math.abs(z2 - z1)
	-- Zócalo y remate, un poco salidos.
	decor(
		between(
			"Zocalo",
			math.min(x1, x2) - 0.1,
			math.min(z1, z2) - 0.1,
			math.max(x1, x2) + 0.1,
			math.max(z1, z2) + 0.1,
			0,
			1.5,
			CONCRETE_DARK,
			Enum.Material.Concrete,
			parent
		)
	)
	decor(
		between(
			"Remate",
			math.min(x1, x2) - 0.15,
			math.min(z1, z2) - 0.15,
			math.max(x1, x2) + 0.15,
			math.max(z1, z2) + 0.15,
			h - 1,
			1,
			STEEL_DARK,
			Enum.Material.SmoothPlastic,
			parent
		)
	)
	-- Una liana por cada tramo largo, por los dos lados.
	local long = math.max(sizeX, sizeZ)
	for _ = 1, math.floor(long / 14) do
		local t = rng:NextNumber(0.15, 0.85)
		local center = part.Position
		if sizeX >= sizeZ then
			local x = math.min(x1, x2) + sizeX * t
			for _, facing in { Vector3.zAxis, -Vector3.zAxis } do
				local face = center.Z + facing.Z * sizeZ / 2
				vine(parent, Vector3.new(x, h, face), facing, rng:NextNumber(5, 12))
			end
		else
			local z = math.min(z1, z2) + sizeZ * t
			for _, facing in { Vector3.xAxis, -Vector3.xAxis } do
				local face = center.X + facing.X * sizeX / 2
				vine(parent, Vector3.new(face, h, z), facing, rng:NextNumber(5, 12))
			end
		end
	end
	return part
end

-- Caja de suministros (cobertura baja que para los disparos): metal con franja.
local function crate(parent: Instance, position: Vector3, size: number, color: Color3)
	block("Caja", Vector3.one * size, CFrame.new(position + Vector3.new(0, size / 2, 0)), color, nil, parent)
	decor(
		block(
			"Franja",
			Vector3.new(size + 0.1, 0.5, size + 0.1),
			CFrame.new(position + Vector3.new(0, size * 0.7, 0)),
			HAZARD,
			nil,
			parent
		)
	)
end

local function buildGround(folder: Folder)
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
			if rng:NextNumber() < 0.12 then
				decor(
					block(
						"Grieta",
						Vector3.new(rng:NextNumber(2, 5), 0.12, 0.6),
						CFrame.new(x + 4, 0.05, z + 4) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
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
local function buildBoundary(folder: Folder)
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
local function buildLaneWalls(folder: Folder)
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

-- Zona de salida de "teamId" ("side" -1 oeste, 1 este): suelo, paredes, las dos bocas con su barrera y
-- su compuerta, la baldosa de aparición y el volumen de la zona.
local function buildZone(bases: Folder, teamId: string, side: number)
	local team = Config.Lab.Teams[teamId]
	local model = Instance.new("Model")
	model.Name = teamId
	model.Parent = bases
	local inner, outer = side * HALF_X, side * ZONE_OUTER_X
	local pirate = teamId == "Pirates"

	-- Suelo: tablones del muelle o el hormigón blanco de la esclusa.
	if pirate then
		for z = -ZONE_HALF_Z, ZONE_HALF_Z - 2, 2 do
			local plank = between(
				"Tablon",
				inner,
				z,
				outer,
				z + 2,
				-1,
				1,
				if (z / 2) % 2 == 0 then WOOD else tone(WOOD, 0.15),
				Enum.Material.WoodPlanks,
				model
			)
			plank.Locked = true
		end
	else
		between(
			"SueloEsclusa",
			inner,
			-ZONE_HALF_Z,
			outer,
			ZONE_HALF_Z,
			-1,
			1,
			LAB_WHITE,
			Enum.Material.Concrete,
			model
		)
		hazardStripe(model, Vector3.new((inner + outer) / 2, 0.05, ZONE_HALF_Z - 2), math.abs(outer - inner) - 2, false)
		hazardStripe(
			model,
			Vector3.new((inner + outer) / 2, 0.05, -ZONE_HALF_Z + 2),
			math.abs(outer - inner) - 2,
			false
		)
	end

	-- Paredes de los lados (norte y sur) y la de la boca, con dos huecos.
	local sideColor = if pirate then WOOD_DARK else LAB_WHITE
	for _, sideZ in { -1, 1 } do
		local part = between(
			"Pared",
			inner,
			sideZ * ZONE_HALF_Z,
			outer + side * WALL_THICKNESS,
			sideZ * (ZONE_HALF_Z + WALL_THICKNESS),
			0,
			WALL_HEIGHT,
			sideColor,
			if pirate then Enum.Material.WoodPlanks else Enum.Material.Concrete,
			model
		)
		part.Name = "Pared"
		-- Franja del bando a media altura.
		decor(
			between(
				"FranjaBando",
				inner,
				sideZ * (ZONE_HALF_Z - 0.1),
				outer,
				sideZ * ZONE_HALF_Z,
				6,
				1.5,
				team.color,
				nil,
				model
			)
		)
	end
	local mouthX1, mouthX2 = inner, inner + side * WALL_THICKNESS
	for _, range in { { -ZONE_HALF_Z, -MOUTH_TO }, { -MOUTH_FROM, MOUTH_FROM }, { MOUTH_TO, ZONE_HALF_Z } } do
		wall(model, mouthX1, range[1], mouthX2, range[2])
	end
	-- Dintel sobre cada boca (la barrera no llega hasta arriba).
	for _, sideZ in { -1, 1 } do
		between(
			"Dintel",
			mouthX1,
			sideZ * MOUTH_FROM,
			mouthX2,
			sideZ * MOUTH_TO,
			12,
			WALL_HEIGHT - 12,
			CONCRETE_DARK,
			Enum.Material.Concrete,
			model
		)
		-- La barrera del bando: solo choca con el rival (registerGroups). Un campo a franjas del color del
		-- bando que los disparos cruzan (y que en la zona no hacen daño, LabCombatRules).
		local field = between(
			"Barrier",
			(mouthX1 + mouthX2) / 2 - 0.3,
			sideZ * MOUTH_FROM,
			(mouthX1 + mouthX2) / 2 + 0.3,
			sideZ * MOUTH_TO,
			0,
			12,
			team.color,
			Enum.Material.ForceField,
			model
		)
		field.Transparency = 0.45
		field.CanQuery = false
		field.CanTouch = false
		field.CastShadow = false
		field.CollisionGroup = LabBuilder.barrierGroup(teamId)
		-- La compuerta de antes de la partida: una persiana de metal, del lado de dentro.
		local gate = between(
			"Gate",
			mouthX2 + side * 0.5,
			sideZ * MOUTH_FROM,
			mouthX2 + side * 1.5,
			sideZ * MOUTH_TO,
			0,
			12,
			STEEL,
			Enum.Material.DiamondPlate,
			model
		)
		gate.Transparency = 0.35
		gate.CanQuery = false
		gate.CanTouch = false
		hazardStripe(
			model,
			Vector3.new(inner + side * 3, 0.05, sideZ * (MOUTH_FROM + MOUTH_TO) / 2),
			MOUTH_TO - MOUTH_FROM,
			true
		)
	end

	-- Baldosa de aparición y volumen de la zona.
	local spawn = block(
		"Spawn",
		Vector3.new(8, 0.2, 8),
		CFrame.new((inner + outer) / 2, 0.1, 0),
		team.color,
		Enum.Material.SmoothPlastic, -- sin brillo: en primera persona se ve de cerca
		model
	)
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	local zone = between("Zone", inner, -ZONE_HALF_Z, outer, ZONE_HALF_Z, 0, 24, CONCRETE, nil, model)
	marker(zone)

	-- El fondo de la zona.
	if pirate then
		-- El muelle se acaba en el agua: barrera invisible y postes.
		barrier(outer + side * WALL_THICKNESS, -ZONE_HALF_Z, outer, ZONE_HALF_Z, 0, CEILING_HEIGHT, model)
		for z = -ZONE_HALF_Z + 2, ZONE_HALF_Z - 2, 6 do
			block(
				"Poste",
				Vector3.new(1, 4, 1),
				CFrame.new(outer - side * 0.5, 1, z),
				WOOD_DARK,
				Enum.Material.Wood,
				model
			)
			decor(
				block(
					"Cuerda",
					Vector3.new(0.3, 0.3, 6),
					CFrame.new(outer - side * 0.5, 2.6, z + 3),
					Color3.fromRGB(190, 160, 110),
					nil,
					model
				)
			)
		end
		-- Barriles y cajas dentro de la zona (cobertura para salir).
		for _, spot in { Vector3.new(outer - side * 3, 0, 12), Vector3.new(outer - side * 3, 0, -12) } do
			block(
				"Barril",
				Vector3.new(3, 3.5, 3),
				CFrame.new(spot + Vector3.new(0, 1.75, 0)),
				WOOD,
				Enum.Material.Wood,
				model
			)
			decor(
				block(
					"Aro",
					Vector3.new(3.2, 0.4, 3.2),
					CFrame.new(spot + Vector3.new(0, 2.6, 0)),
					team.color,
					Enum.Material.Metal,
					model
				)
			)
		end
		-- Farolillos dorados en las paredes.
		for _, sideZ in { -1, 1 } do
			for _, t in { 0.3, 0.7 } do
				local x = inner + (outer - inner) * t
				local lamp = block(
					"Farol",
					Vector3.new(1, 1.4, 1),
					CFrame.new(x, 8, sideZ * (ZONE_HALF_Z - 0.7)),
					team.color,
					Enum.Material.Neon,
					model
				)
				decor(lamp)
				local light = Instance.new("PointLight")
				light.Color = team.color
				light.Range = 14
				light.Brightness = 1.2
				light.Parent = lamp
			end
		end
	else
		-- La compuerta blindada al fondo, medio abierta (decorado: detrás hay hormigón).
		between(
			"Fondo",
			outer,
			-ZONE_HALF_Z - WALL_THICKNESS,
			outer + side * WALL_THICKNESS,
			ZONE_HALF_Z + WALL_THICKNESS,
			0,
			WALL_HEIGHT,
			LAB_WHITE,
			Enum.Material.Concrete,
			model
		)
		local doorX = outer - side * 0.3
		decor(
			block(
				"Compuerta",
				Vector3.new(0.6, 10, 12),
				CFrame.new(doorX, 7, 0),
				STEEL,
				Enum.Material.DiamondPlate,
				model
			)
		)
		decor(block("Rendija", Vector3.new(0.7, 2, 12), CFrame.new(doorX, 1, 0), CABLE, nil, model))
		decor(block("MarcoCompuerta", Vector3.new(0.8, 1, 14), CFrame.new(doorX, 12.5, 0), team.color, nil, model))
		for _, sideZ in { -1, 1 } do
			decor(
				block(
					"MarcoCompuerta",
					Vector3.new(0.8, 13, 1),
					CFrame.new(doorX, 6.5, sideZ * 6.5),
					team.color,
					nil,
					model
				)
			)
			-- Focos en lo alto.
			local spot = block(
				"Foco",
				Vector3.new(1.5, 1, 1.5),
				CFrame.new(outer - side * 1, 14, sideZ * 10),
				LAB_WHITE,
				Enum.Material.Neon,
				model
			)
			decor(spot)
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Bottom
			light.Range = 22
			light.Angle = 70
			light.Brightness = 2
			light.Color = Color3.fromRGB(220, 235, 255)
			light.Parent = spot
		end
		-- Taquillas de seguridad (cobertura para salir).
		for _, sideZ in { -1, 1 } do
			block(
				"Taquilla",
				Vector3.new(3, 5, 3),
				CFrame.new(outer - side * 3, 2.5, sideZ * 12),
				LAB_WHITE,
				nil,
				model
			)
			decor(
				block(
					"FranjaTaquilla",
					Vector3.new(3.1, 0.6, 3.1),
					CFrame.new(outer - side * 3, 3.8, sideZ * 12),
					team.color,
					nil,
					model
				)
			)
		end
	end
end

-- El velero pirata amarrado junto al muelle (decorado, fuera del mapa) y el agua.
local function buildDockOutside(folder: Folder)
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
		decor(
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

-- Tanque de suero roto (cobertura media): aro de metal, cristal azulado con huecos y el remate.
local function serumTank(parent: Instance, center: Vector3)
	local tank = Instance.new("Model")
	tank.Name = "Tanque"
	tank.Parent = parent
	block(
		"Basa",
		Vector3.new(6, 1, 6),
		CFrame.new(center + Vector3.new(0, 0.5, 0)),
		STEEL_DARK,
		Enum.Material.DiamondPlate,
		tank
	)
	-- El cristal en bloques de 1 × 1 por las cuatro caras, con algunos rotos (los de arriba, más).
	for level = 1, 3 do
		for _, face in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
			for offset = -1, 1 do -- las esquinas son de los montantes
				if rng:NextNumber() > 0.12 * level then
					local along = Vector3.new(face.Z, 0, face.X) * offset
					local pane = block(
						"Cristal",
						Vector3.new(1, 1, 1),
						CFrame.new(center + face * 2.5 + along + Vector3.new(0, level + 0.5, 0)),
						GLASS,
						Enum.Material.Glass,
						tank
					)
					pane.Transparency = 0.35
				end
			end
		end
	end
	-- Por dentro, un bloque macizo bajo (para que la cobertura pare de verdad) con el resto del suero.
	-- Más pequeño que el hueco de los cristales (±2): sin caras en el mismo plano, que parpadean.
	block("Dentro", Vector3.new(3.6, 3, 3.6), CFrame.new(center + Vector3.new(0, 2.5, 0)), CONCRETE_DARK, nil, tank)
	decor(
		block(
			"Suero",
			Vector3.new(3.4, 0.4, 3.4),
			CFrame.new(center + Vector3.new(0, 4.2, 0)),
			SERUM,
			Enum.Material.Neon,
			tank
		)
	)
	-- Montantes de las esquinas.
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			block(
				"Montante",
				Vector3.new(1.5, 4.5, 1.5),
				CFrame.new(center + Vector3.new(cx * 2.35, 3.25, cz * 2.35)),
				RUST,
				Enum.Material.CorrodedMetal,
				tank
			)
		end
	end
end

local function buildReactor(folder: Folder)
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

-- Jaula de barrotes de "size" × "size": chocan, pero los disparos pasan entre ellos (CanQuery false).
local function cage(parent: Instance, center: Vector3, size: number, broken: boolean)
	local model = Instance.new("Model")
	model.Name = if broken then "JaulaRota" else "Jaula"
	model.Parent = parent
	local height = 7
	local half = size / 2
	local function bar(position: Vector3, barHeight: number, tilt: number)
		local part = block(
			"Barrote",
			Vector3.new(0.4, barHeight, 0.4),
			CFrame.new(position + Vector3.new(0, barHeight / 2, 0)) * CFrame.Angles(tilt, 0, 0),
			STEEL,
			Enum.Material.Metal,
			model
		)
		part.CanQuery = false
	end
	for offset = -half, half, 1.5 do
		for _, sideZ in { -1, 1 } do
			local bent = broken and sideZ == 1 and math.abs(offset) < 2
			bar(center + Vector3.new(offset, 0, sideZ * half), if bent then 3 else height, if bent then 0.5 else 0)
		end
		for _, sideX in { -1, 1 } do
			bar(center + Vector3.new(sideX * half, 0, offset), height, 0)
		end
	end
	-- Techo y suelo de la jaula.
	local roof = block(
		"TechoJaula",
		Vector3.new(size + 0.6, 0.6, size + 0.6),
		CFrame.new(center + Vector3.new(0, height + 0.3, 0)),
		RUST_DARK,
		Enum.Material.CorrodedMetal,
		model
	)
	roof.CanQuery = false
	decor(
		block(
			"SueloJaula",
			Vector3.new(size, 0.15, size),
			CFrame.new(center + Vector3.new(0, 0.08, 0)),
			STEEL_DARK,
			Enum.Material.DiamondPlate,
			model
		)
	)
end

local function buildCages(folder: Folder)
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

-- Platanera primal (decorado: tapa la vista pero no para nada): tronco, hojas grandes y un racimo.
local function bananaPlant(parent: Instance, ground: Vector3, height: number)
	decor(
		block(
			"Tronco",
			Vector3.new(1, height, 1),
			CFrame.new(ground + Vector3.new(0, height / 2, 0)),
			Color3.fromRGB(96, 104, 62),
			Enum.Material.Grass,
			parent
		)
	)
	for index = 1, 4 do
		local angle = index * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		decor(
			block(
				"Hoja",
				Vector3.new(2.4, 0.3, 5),
				CFrame.lookAt(
					ground + Vector3.new(0, height - 0.4, 0) + out * 2.4,
					ground + Vector3.new(0, height - 1.6, 0) + out * 5
				),
				if index % 2 == 0 then LEAF else VINE,
				Enum.Material.Grass,
				parent
			)
		)
	end
	decor(
		block(
			"Racimo",
			Vector3.new(1.2, 1.6, 1.2),
			CFrame.new(ground + Vector3.new(0.7, height - 1.5, 0)),
			BANANA,
			nil,
			parent
		)
	)
end

local function buildGreenhouse(folder: Folder)
	local lane = Instance.new("Folder")
	lane.Name = "Invernadero"
	lane.Parent = folder
	-- Bancales bajos (paran los disparos), con tierra y plataneras.
	for _, x in { -42, -26, -10, 10, 26, 42 } do
		between("Bancal", x - 1.5, -50, x + 1.5, -36, 0, 3, WOOD_DARK, Enum.Material.WoodPlanks, lane)
		decor(between("Tierra", x - 1.3, -49.8, x + 1.3, -36.2, 3, 0.2, SOIL, Enum.Material.Ground, lane))
		for _, z in { -47, -43, -39 } do
			bananaPlant(lane, Vector3.new(x + rng:NextNumber(-0.4, 0.4), 3, z), rng:NextNumber(5, 7))
		end
	end
	-- Helechos entre bancales (tapan la vista a la altura de la cara).
	for _, x in { -34, -18, 0, 18, 34 } do
		for _, z in { -52, -44, -34 } do
			bananaPlant(lane, Vector3.new(x + rng:NextNumber(-1, 1), 0, z), rng:NextNumber(4.5, 5.5))
		end
	end
	-- Armazón del techo de cristal, roto: vigas y algunos paneles.
	for x = -48, 48, 12 do
		decor(between("Viga", x - 0.4, -HALF_Z, x + 0.4, -LANE_WALL_OUT, 16, 0.8, STEEL_DARK, nil, lane))
	end
	for _ = 1, 10 do
		local x = rng:NextInteger(-4, 3) * 12
		local z = rng:NextNumber(-52, -34)
		local pane = decor(
			block("PanelCristal", Vector3.new(11, 0.2, 6), CFrame.new(x + 6, 16.2, z), GLASS, Enum.Material.Glass, lane)
		)
		pane.Transparency = 0.4
	end
	-- Lianas por las vigas.
	for x = -48, 48, 24 do
		vine(lane, Vector3.new(x, 16, -44), Vector3.zAxis, rng:NextNumber(4, 8))
	end
end

-- Derrumbes que cierran el invernadero en 1v1 y 2v2 (LabWorldService.setFormat): cascotes en sus dos
-- bocas a la explanada y en los huecos del muro con el reactor. Se construyen cerrados; el servidor los
-- abre según el formato.
local function rubble(parent: Instance, x1: number, z1: number, x2: number, z2: number)
	local sizeX, sizeZ = math.abs(x2 - x1), math.abs(z2 - z1)
	local alongX = sizeX >= sizeZ
	local length = math.max(sizeX, sizeZ)
	local center = Vector3.new((x1 + x2) / 2, 0, (z1 + z2) / 2)
	for offset = -length / 2 + 1.5, length / 2 - 1.5, 3 do
		local height = rng:NextNumber(WALL_HEIGHT - 4, WALL_HEIGHT)
		local slab =
			Vector3.new(if alongX then 3 else math.min(sizeX, 4), height, if alongX then math.min(sizeZ, 4) else 3)
		local position = center + (if alongX then Vector3.new(offset, 0, 0) else Vector3.new(0, 0, offset))
		block(
			"Cascote",
			slab,
			CFrame.new(position + Vector3.new(0, height / 2, 0)),
			tone(CONCRETE_DARK, 0.2),
			Enum.Material.Concrete,
			parent
		)
	end
	-- Hierros torcidos encima.
	for _ = 1, 2 do
		local position = center
			+ Vector3.new(rng:NextNumber(-1, 1) * sizeX / 3, WALL_HEIGHT - 2, rng:NextNumber(-1, 1) * sizeZ / 3)
		block(
			"Hierro",
			Vector3.new(0.4, 5, 0.4),
			CFrame.new(position) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6)),
			RUST,
			Enum.Material.CorrodedMetal,
			parent
		)
	end
end

local function buildCollapse(folder: Folder)
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

-- Marcadores donde aparece cada uno en Todos contra todos (LabWorldService.freeSpawnCFrame): invisibles y
-- sin choque. "points" son pares { x, z }; sin ellos, los del Laboratorio central. Cada mapa trae los suyos.
function LabBuilder.buildFreeSpawns(folder: Folder, points: { { number } }?)
	local spawns = Instance.new("Folder")
	spawns.Name = "SpawnsLibres"
	spawns.Parent = folder
	for _, point in points or FREE_SPAWNS do
		local part = block("Libre", Vector3.new(4, 0.2, 4), CFrame.new(point[1], 0.1, point[2]), CONCRETE, nil, spawns)
		marker(part)
	end
end

-- Avisa si un marcador de SpawnsLibres tiene algo que choque donde estaría el personaje (se llama con el
-- mapa ya en Workspace; los rayos solo encuentran lo que tiene CanQuery, que es lo que importa: muros,
-- coberturas, bancales).
local function checkFreeSpawns(folder: Folder)
	local spawns = folder:FindFirstChild("SpawnsLibres")
	if not spawns then
		return
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { spawns }
	for _, part in spawns:GetChildren() do
		if part:IsA("BasePart") then
			-- Del pecho a la cabeza (el suelo queda por debajo) y con 2 studs de reparto a cada lado.
			local box = CFrame.new(part.Position.X, 3, part.Position.Z)
			for _, hit in Workspace:GetPartBoundsInBox(box, Vector3.new(6, 4, 6), params) do
				if hit.CanCollide then
					warn(`[LabBuilder] El punto libre {part.Position} choca con {hit:GetFullName()}`)
				end
			end
		end
	end
end

-- Rascacielos en ruinas comidos por la selva alrededor (decorado, lejos): torres de hormigón con
-- ventanas a franjas, algo inclinadas, con copas de árboles oscuras encima y lianas.
local function buildSkyline(folder: Folder)
	local skyline = Instance.new("Folder")
	skyline.Name = "CiudadPerdida"
	skyline.Parent = folder
	local towers = {
		{ 0, 190, 50, 170 },
		{ 150, 170, 44, 140 },
		{ -170, 150, 48, 190 },
		{ 210, -40, 40, 120 },
		{ 140, -180, 52, 200 },
		{ -40, -200, 46, 150 },
		{ -200, -150, 40, 130 },
		{ 260, 90, 38, 110 },
	}
	for index, tower in towers do
		local x, z, width, height = tower[1], tower[2], tower[3], tower[4]
		local lean = CFrame.Angles(rng:NextNumber(-0.05, 0.05), rng:NextNumber(0, math.pi), rng:NextNumber(-0.05, 0.05))
		local base = CFrame.new(x, -2, z) * lean
		decor(
			block(
				"Torre",
				Vector3.new(width, height, width),
				base * CFrame.new(0, height / 2, 0),
				tone(CONCRETE, 0.25),
				Enum.Material.Concrete,
				skyline
			)
		)
		-- Ventanas: una franja oscura cada 8 studs.
		for y = 10, height - 8, 8 do
			decor(
				block(
					"Ventanas",
					Vector3.new(width + 0.4, 3, width + 0.4),
					base * CFrame.new(0, y, 0),
					STEEL_DARK,
					Enum.Material.Glass,
					skyline
				)
			)
		end
		-- La selva por encima y bajando por una cara.
		for _ = 1, 3 do
			local offset = Vector3.new(
				rng:NextNumber(-0.3, 0.3) * width,
				height + rng:NextNumber(0, 6),
				rng:NextNumber(-0.3, 0.3) * width
			)
			decor(
				block(
					"Copa",
					Vector3.new(16, 8, 16),
					base * CFrame.new(offset),
					if index % 2 == 0 then VINE else VINE_DARK,
					Enum.Material.Grass,
					skyline
				)
			)
		end
		decor(
			block(
				"Enredadera",
				Vector3.new(width * 0.4, height * 0.6, 1),
				base * CFrame.new(0, height * 0.55, width / 2 + 0.5),
				VINE_DARK,
				Enum.Material.Grass,
				skyline
			)
		)
	end
	-- Copas de la selva entre las torres.
	for _ = 1, 36 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(120, 280)
		local size = rng:NextNumber(14, 26)
		local ground = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		-- Tronco hasta la copa, que es un bloque ancho y bajo.
		decor(
			block(
				"Tronco",
				Vector3.new(2, size, 2),
				CFrame.new(ground + Vector3.new(0, size / 2, 0)),
				WOOD_DARK,
				Enum.Material.Wood,
				skyline
			)
		)
		decor(
			block(
				"Arbol",
				Vector3.new(size, size * 0.5, size),
				CFrame.new(ground + Vector3.new(0, size, 0)),
				if rng:NextNumber() < 0.5 then VINE else VINE_DARK,
				Enum.Material.Grass,
				skyline
			)
		)
	end
end

local function clearOld()
	for _, name in { FOLDER_NAME, "LabSalaDePruebas", "MuñecosDePractica", "Baseplate" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

-- true si el place ya tiene el mapa de esta versión.
function LabBuilder.isBuilt(): boolean
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	return folder ~= nil and folder:GetAttribute("Version") == VERSION
end

function LabBuilder.build(options: Options?)
	local force = options and options.force
	if not force and game.PlaceId ~= Config.PlaceIds.Laboratorio then
		warn(
			`[LabBuilder] Este place ({game.PlaceId}) no es el Laboratorio ({Config.PlaceIds.Laboratorio}). `
				.. "Abre el Laboratorio o usa build({ force = true })."
		)
		return
	end
	clearOld()
	rng = Random.new(SEED)
	LabBuilder.registerGroups()
	applyLighting()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("Version", VERSION)
	buildGround(folder)
	buildBoundary(folder)
	buildLaneWalls(folder)
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	buildZone(bases, "Pirates", -1)
	buildZone(bases, "Guardians", 1)
	bases.Parent = folder
	buildDockOutside(folder)
	buildReactor(folder)
	buildCages(folder)
	buildGreenhouse(folder)
	buildCollapse(folder)
	LabBuilder.buildFreeSpawns(folder)
	buildSkyline(folder)
	folder.Parent = Workspace
	checkFreeSpawns(folder)
	print("[LabBuilder] ¡Laboratorio central listo!")
end

return LabBuilder
