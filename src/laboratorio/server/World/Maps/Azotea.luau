--!strict
-- Mapa "Azotea de la torre" del Laboratorio en ruinas (Fase 13, L4b bloque B; docs/LABORATORIO.md §4): la
-- azotea de un rascacielos del Proyecto PRIMAL comido por la selva. Favorece la larga distancia: de boca a
-- boca hay unos 92 studs. Voxel: bloques en rejilla con pocos tonos planos (hormigón gris, metal oxidado,
-- cristal azulado roto, cables y la selva oscura; nunca verde brillante, que es el color de la curación).
-- Lo construye World/LabBuilder dentro de Workspace.LabMap.Azotea.
--
-- Forma: 120 × 120 studs, en coordenadas locales (el suelo de la azotea en y = 0, simétrico de oeste a este):
--   - Azotea (y 0, z -30…60): al oeste la zona de los Piratas (|x| 46–60, tablones y faroles) y al este la de
--     los Guardianes (esclusa blanca y focos). La caseta de los ascensores (x ±6, z ±6, alto 8) corta la línea
--     central: los rifles se enfrentan por los flancos (|z| 6–11), entre aparatos de aire, depósitos de agua,
--     claraboyas, cajas y una antena caída (z -21…-19, x ±[4, 18]).
--   - Helipuerto (y +4, x ±12, z 18–42) con una rampa a cada lado (z 26–34) y una H pintada.
--   - Terraza baja (y -12, z -60…-30). Se sube a la azotea por dos escaleras (x ±[30, 38]) y por la pluma
--     caída de la grúa (una rampa de 4 de ancho de (0, 0, -30) a (0, -12, -46)). El mástil de la grúa sube de
--     la terraza hasta el techo.
--   - Caídas: solo por cuatro huecos rotos con franjas amarillas y negras (dos al norte, x ±[14, 22], y dos al
--     sur de la terraza, x ±[20, 28]). El resto del borde lleva un pretil visible y una barrera invisible
--     que llega hasta el techo.
--   - Debajo: el fuste de la torre hasta la selva (a -161), las torres vecinas a la altura de los ojos y la
--     selva propia del mapa. Todo eso es decorado: sin choque ni rayos. Los suelos jugables son planos.
--
-- Piezas con nombre que lee el código (como en el Central): "Bases/<bando>" con "Spawn", "Zone", "Barrier" y
-- "Gate" (LabParts.buildZone), "Derrumbes" (tres tapones de cascotes arriba de cada escalera y de la rampa
-- que cierran la terraza en 1v1 y 2v2; sin barreras invisibles dentro: LabWorldService.setFormat los pone
-- visibles y con choque a todos) y "SpawnsLibres" (LabParts.buildFreeSpawns).
--
-- La barandilla de z = -30 (pretil visible de 1,5 de alto y una barrera invisible que los disparos cruzan) va
-- siempre, fuera de Derrumbes, con las aberturas justas para las escaleras y la rampa. Techo invisible a 30.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local CABLE = PALETTE.CABLE
local HAZARD = PALETTE.HAZARD
local VINE = PALETTE.VINE
local VINE_DARK = PALETTE.VINE_DARK
local LEAF = PALETTE.LEAF
local WOOD = PALETTE.WOOD
local WOOD_DARK = PALETTE.WOOD_DARK
local LAB_WHITE = PALETTE.LAB_WHITE
local JUNGLE_GROUND = PALETTE.JUNGLE_GROUND

-- Medidas de las zonas de salida y los muros (LabParts.buildZone). El suelo está en y = 0.
local GEOMETRY: LabParts.Geometry = {
	halfX = 46, -- la boca de las zonas de salida
	outerX = 60, -- el fondo de las zonas de salida
	halfZ = 12,
	mouthFrom = 3, -- cada boca de la zona va de |z| 3 a 9
	mouthTo = 9,
	wallHeight = 12,
	ceiling = 30,
	gateHeight = 10,
}

-- Última hora de la tarde sobre la ciudad en ruinas: luz cálida, sombras largas y poca bruma, para ver a 120
-- studs. Sin verdes en la corrección de color.
local LIGHTING: LabParts.LightingPreset = {
	clockTime = 16,
	latitude = 10,
	brightness = 2.2,
	ambient = Color3.fromRGB(92, 98, 112),
	outdoorAmbient = Color3.fromRGB(136, 142, 158),
	atmosphere = {
		density = 0.28,
		offset = 0.1,
		color = Color3.fromRGB(190, 198, 216),
		decay = Color3.fromRGB(120, 124, 142),
		glare = 0,
		haze = 1,
	},
	colorCorrection = { contrast = 0.08, saturation = -0.04, tint = Color3.fromRGB(250, 244, 236) },
	sunRays = { intensity = 0.05, spread = 0.6 },
}

-- Semilla del decorado al azar (tonos, lianas, cascotes): el mismo mapa en cada construcción.
local SEED = 2112
-- Altura de la vista cenital del espectador (LabSpectateController) sobre el centro del mapa.
local OVERHEAD_HEIGHT = 150

type Rect = { number } -- { x1, z1, x2, z2 }

local EDGE = 60 -- el borde de la azotea y de la terraza (|x| y |z|)
local LEDGE_Z = -30 -- el escalón entre la azotea y la terraza
local TERRACE_TOP = -12
local CEILING = GEOMETRY.ceiling
local WALL_HEIGHT = GEOMETRY.wallHeight
local STAIR_X1, STAIR_X2 = 30, 38 -- las escaleras (|x|)
local STAIR_Z1 = -44 -- donde empiezan, en la terraza
local STAIR_STEPS = 12
local RAMP_HALF = 2 -- la pluma de la grúa mide 4 de ancho
local RAMP_END_Z = -46
local MAST_Z = -50
local HELI_HALF_X = 12
local HELI_Z1, HELI_Z2 = 18, 42
local HELI_TOP = 4
local SHAFT_HALF = 44 -- el fuste de la torre
local GROUND_Y = -160.2 -- la selva de abajo (en el mundo, y ≈ -0,2)

-- Huecos rotos por los que se cae: { x1, z1, x2, z2 }.
local ROOF_HOLES: { Rect } = { { -22, 54, -14, 60 }, { 14, 54, 22, 60 } }
local TERRACE_HOLES: { Rect } = { { -28, -60, -20, -54 }, { 20, -60, 28, -54 } }
-- Tramos abiertos del borde oeste y este (z1, z2), detrás de las zonas de salida: 20 de largo cada uno, 1/3 del
-- borde entre los dos. Sin pretil ni barrera: se cae.
local SIDE_DROPS: { { number } } = { { 14, 34 }, { -34, -14 } }
-- Donde la azotea no lleva baldosas porque están las zonas de salida.
local ZONE_AREAS: { Rect } = { { -EDGE, -12, -46, 12 }, { 46, -12, EDGE, 12 } }

-- Puntos de aparición libres (Todos contra todos), simétricos de oeste a este y sin nada que choque a ±3:
--   (±24, 50)   norte, entre el hueco (x 14–22) y las cajas de x 30+
--   (±36, 24)   flanco, entre el helipuerto y los aparatos de x 41+
--   (±24, -8)   flanco sur, entre los depósitos (x 13–19) y los aparatos de x 31+
--   (±6, 30)    sobre el helipuerto (y 4)
--   (±24, -46)  terraza, entre las escaleras y los huecos
--   (±44, -40)  terraza, a la derecha de las escaleras (la del encargo, ±40, chocaba con ellas)
local FREE_SPAWNS: { LabParts.FreeSpawnPoint } = {
	{ x = -24, z = 50 },
	{ x = 24, z = 50 },
	{ x = -36, z = 24 },
	{ x = 36, z = 24 },
	{ x = -24, z = -8 },
	{ x = 24, z = -8 },
	{ x = -6, z = 30, y = HELI_TOP },
	{ x = 6, z = 30, y = HELI_TOP },
	{ x = -24, z = -46, y = TERRACE_TOP, closable = true },
	{ x = 24, z = -46, y = TERRACE_TOP, closable = true },
	{ x = -44, z = -40, y = TERRACE_TOP, closable = true },
	{ x = 44, z = -40, y = TERRACE_TOP, closable = true },
}

-- Torres vecinas { x, z, ancho, alto }: de 150 a 320 del centro, con las azoteas a la altura de los ojos (el
-- suelo de abajo está en -162 y la azotea en 0).
local SKYLINE_TOWERS: { { number } } = {
	{ 0, 200, 50, 168 },
	{ 170, 170, 44, 160 },
	{ -180, 160, 48, 172 },
	{ 240, -30, 40, 164 },
	{ 150, -200, 52, 170 },
	{ -50, -220, 46, 166 },
	{ -230, -150, 40, 160 },
	{ -250, 40, 42, 168 },
	{ 290, 120, 38, 162 },
	{ -140, -280, 44, 170 },
}

local block = LabParts.block
local between = LabParts.between
local decor = LabParts.decor
local barrier = LabParts.barrier
local tone = LabParts.tone
local hazardStripe = LabParts.hazardStripe
local cable = LabParts.cable
local vine = LabParts.vine
local crate = LabParts.crate
local bananaPlant = LabParts.bananaPlant

-- Pieza decorativa (sin choque ni rayos).
local function deco(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance
): BasePart
	return decor(block(name, size, cframe, color, material, parent))
end

local function folder(parent: Instance, name: string): Folder
	local result = Instance.new("Folder")
	result.Name = name
	result.Parent = parent
	return result
end

-- Cortes de un eje: cada "step" desde "from" hasta "to", más los de "extra" que caen dentro (los bordes de
-- los huecos, para que las baldosas encajen).
local function cuts(from: number, to: number, step: number, extra: { number }): { number }
	local list = { from, to }
	local at = from + step
	while at < to - 0.01 do
		table.insert(list, at)
		at += step
	end
	for _, value in extra do
		if value > from + 0.01 and value < to - 0.01 then
			table.insert(list, value)
		end
	end
	table.sort(list)
	local result = { list[1] }
	for index = 2, #list do
		if list[index] - result[#result] > 0.01 then
			table.insert(result, list[index])
		end
	end
	return result
end

-- Baldosas de 8 × 8 en dos tonos (con algún hueco para las zonas y las caídas) sobre un suelo plano de 1 de
-- grueso cuya cara de arriba está en "top".
local function floorArea(parent: Instance, x1: number, z1: number, x2: number, z2: number, top: number, skip: { Rect })
	local extraX, extraZ = {}, {}
	for _, rect in skip do
		table.insert(extraX, rect[1])
		table.insert(extraX, rect[3])
		table.insert(extraZ, rect[2])
		table.insert(extraZ, rect[4])
	end
	local xs, zs = cuts(x1, x2, 8, extraX), cuts(z1, z2, 8, extraZ)
	for ix = 1, #xs - 1 do
		for iz = 1, #zs - 1 do
			local cx, cz = (xs[ix] + xs[ix + 1]) / 2, (zs[iz] + zs[iz + 1]) / 2
			local blocked = false
			for _, rect in skip do
				if cx > rect[1] and cx < rect[3] and cz > rect[2] and cz < rect[4] then
					blocked = true
					break
				end
			end
			if not blocked then
				local color = if (ix + iz) % 2 == 0 then CONCRETE_LIGHT else CONCRETE
				local tile = between(
					"Baldosa",
					xs[ix],
					zs[iz],
					xs[ix + 1],
					zs[iz + 1],
					top - 1,
					1,
					tone(color, 0.05),
					Enum.Material.Concrete,
					parent
				)
				tile.Locked = true
				-- Grietas con hierba que asoma.
				if LabParts.rng:NextNumber() < 0.1 then
					deco(
						"Grieta",
						Vector3.new(LabParts.rng:NextNumber(2, 5), 0.12, 0.6),
						CFrame.new((xs[ix] + xs[ix + 1]) / 2, top + 0.05, (zs[iz] + zs[iz + 1]) / 2)
							* CFrame.Angles(0, LabParts.rng:NextNumber(0, math.pi), 0),
						VINE,
						Enum.Material.Grass,
						parent
					)
				end
			end
		end
	end
end

-- Borde de un hueco roto: franjas amarillas y negras por tres lados (el cuarto da al vacío), hierros
-- torcidos y una losa colgando. "openZ" es la z del lado por el que se llega al hueco.
local function holeEdge(parent: Instance, rect: Rect, top: number, openZ: number)
	local x1, z1, x2, z2 = rect[1], rect[2], rect[3], rect[4]
	local midX, midZ = (x1 + x2) / 2, (z1 + z2) / 2
	hazardStripe(parent, Vector3.new(midX, top + 0.05, openZ), x2 - x1, false)
	hazardStripe(parent, Vector3.new(x1 - 0.75, top + 0.05, midZ), z2 - z1, true)
	hazardStripe(parent, Vector3.new(x2 + 0.75, top + 0.05, midZ), z2 - z1, true)
	-- Los hierros salen del suelo del lado por el que se llega (sobre las franjas) y se inclinan hacia el
	-- hueco: nada flota sobre el vacío.
	local rng = LabParts.rng
	local rimZ = if openZ < midZ then z1 - 0.3 else z2 + 0.3
	local lean = if openZ < midZ then 1 else -1
	for index = 1, 5 do
		local x = x1 + (index - 0.5) * (x2 - x1) / 5
		block(
			"Hierro",
			Vector3.new(0.4, 3.5, 0.4),
			CFrame.new(x, top, rimZ)
				* CFrame.Angles(lean * rng:NextNumber(0.1, 0.4), 0, rng:NextNumber(-0.25, 0.25))
				* CFrame.new(0, 1.75, 0),
			RUST,
			Enum.Material.CorrodedMetal,
			parent
		)
	end
end

local function buildGround(model: Model)
	-- La selva de abajo (se ve desde los bordes y por los huecos).
	local outside = block(
		"Selva",
		Vector3.new(1400, 2, 1400),
		CFrame.new(0, GROUND_Y - 1, 0),
		JUNGLE_GROUND,
		Enum.Material.Grass,
		model
	)
	outside.Locked = true
	local floor = folder(model, "Suelo")
	-- Azotea y terraza (suelos planos).
	local roofSkip: { Rect } = {}
	for _, rect in ROOF_HOLES do
		table.insert(roofSkip, rect)
	end
	for _, rect in ZONE_AREAS do
		table.insert(roofSkip, rect)
	end
	floorArea(floor, -EDGE, LEDGE_Z, EDGE, EDGE, 0, roofSkip)
	floorArea(floor, -EDGE, -EDGE, EDGE, LEDGE_Z, TERRACE_TOP, TERRACE_HOLES)
	-- Los huecos rotos.
	local marks = folder(model, "Huecos")
	for _, rect in ROOF_HOLES do
		holeEdge(marks, rect, 0, rect[2] - 0.75)
	end
	for _, rect in TERRACE_HOLES do
		holeEdge(marks, rect, TERRACE_TOP, rect[4] + 0.75)
	end
	-- La fachada del escalón de la terraza, con las aberturas de las escaleras y de la rampa.
	local facade = folder(model, "Fachada")
	local spans = {
		{ -EDGE, -STAIR_X2 },
		{ -STAIR_X1, -RAMP_HALF },
		{ RAMP_HALF, STAIR_X1 },
		{ STAIR_X2, EDGE },
	}
	for _, span in spans do
		local wallPart = between(
			"Fachada",
			span[1],
			LEDGE_Z - 1,
			span[2],
			LEDGE_Z,
			TERRACE_TOP,
			-TERRACE_TOP,
			tone(CONCRETE_DARK, 0.08),
			Enum.Material.Concrete,
			facade
		)
		wallPart.Locked = true
		deco(
			"Cornisa",
			Vector3.new(span[2] - span[1], 1.5, 0.4),
			CFrame.new((span[1] + span[2]) / 2, -0.85, LEDGE_Z - 1.2),
			STEEL_DARK,
			Enum.Material.SmoothPlastic,
			facade
		)
		-- Ventanas rotas y lianas por la cara de la terraza.
		for x = span[1] + 5, span[2] - 5, 10 do
			if LabParts.rng:NextNumber() < 0.7 then
				deco(
					"Ventana",
					Vector3.new(4, 3, 0.3),
					CFrame.new(x, -6, LEDGE_Z - 1.1),
					if LabParts.rng:NextNumber() < 0.5 then GLASS else STEEL_DARK,
					Enum.Material.Glass,
					facade
				)
			end
			if LabParts.rng:NextNumber() < 0.5 then
				vine(facade, Vector3.new(x + 2, -1, LEDGE_Z - 1), -Vector3.zAxis, LabParts.rng:NextNumber(5, 10))
			end
		end
	end
end

-- Pretiles visibles (decorado, los disparos los cruzan) y barreras invisibles que llegan hasta el techo.
local function buildEdges(model: Model)
	local edges = folder(model, "Bordes")
	-- Decorado: lo que lo hace "macizo" es la barrera invisible, que empieza un stud antes (EDGE - 1) y para al
	-- jugador sin que se suba ni se meta dentro del pretil.
	local function rail(x1: number, z1: number, x2: number, z2: number, bottom: number)
		deco(
			"Pretil",
			Vector3.new(math.abs(x2 - x1), 1.5, math.abs(z2 - z1)),
			CFrame.new((x1 + x2) / 2, bottom + 0.75, (z1 + z2) / 2),
			tone(CONCRETE, 0.1),
			Enum.Material.Concrete,
			edges
		)
		deco(
			"Remate",
			Vector3.new(math.abs(x2 - x1) + 0.2, 0.3, math.abs(z2 - z1) + 0.2),
			CFrame.new((x1 + x2) / 2, bottom + 1.65, (z1 + z2) / 2),
			STEEL_DARK,
			nil,
			edges
		)
	end
	-- Norte: el pretil se corta en los huecos.
	rail(-EDGE, EDGE - 1, -22, EDGE, 0)
	rail(-14, EDGE - 1, 14, EDGE, 0)
	rail(22, EDGE - 1, EDGE, EDGE, 0)
	-- Sur (la terraza): lo mismo.
	rail(-EDGE, -EDGE, -28, -EDGE + 1, TERRACE_TOP)
	rail(-20, -EDGE, 20, -EDGE + 1, TERRACE_TOP)
	rail(28, -EDGE, EDGE, -EDGE + 1, TERRACE_TOP)
	-- Oeste y este: detrás de las zonas de salida se abren dos tramos de 20 (SIDE_DROPS) sin pretil ni
	-- barrera, marcados con franjas: quien se acerca de más cae. El segundo cruza el escalón (azotea y terraza).
	for _, sideX in { -1, 1 } do
		local x1, x2 = sideX * (EDGE - 1), sideX * EDGE
		rail(x1, SIDE_DROPS[1][2], x2, EDGE, 0)
		rail(x1, -EDGE, x2, SIDE_DROPS[2][1], TERRACE_TOP)
		hazardStripe(
			edges,
			Vector3.new(sideX * (EDGE - 0.75), 0.05, (SIDE_DROPS[1][1] + SIDE_DROPS[1][2]) / 2),
			20,
			true
		)
		hazardStripe(edges, Vector3.new(sideX * (EDGE - 0.75), 0.05, (LEDGE_Z + SIDE_DROPS[2][2]) / 2), 16, true)
		hazardStripe(
			edges,
			Vector3.new(sideX * (EDGE - 0.75), TERRACE_TOP + 0.05, (SIDE_DROPS[2][1] + LEDGE_Z) / 2),
			4,
			true
		)
	end
	-- La barandilla del escalón (z = -30): pretil sobre la fachada y una barrera invisible (del grupo
	-- Config.Lab.WallGroup: los disparos la cruzan), con aberturas para las escaleras y la rampa.
	for _, span in
		{
			{ -EDGE, -STAIR_X2 },
			{ -STAIR_X1, -RAMP_HALF },
			{ RAMP_HALF, STAIR_X1 },
			{ STAIR_X2, EDGE },
		}
	do
		rail(span[1], LEDGE_Z - 1, span[2], LEDGE_Z, 0)
		barrier(span[1], LEDGE_Z - 1, span[2], LEDGE_Z + 1, 0, CEILING, edges)
	end
	for _, x in { -STAIR_X2, -STAIR_X1, -RAMP_HALF, RAMP_HALF, STAIR_X1, STAIR_X2 } do
		block("Poste", Vector3.new(0.6, 3.2, 0.6), CFrame.new(x, 1.6, LEDGE_Z - 0.5), STEEL, Enum.Material.Metal, edges)
	end
	-- Barreras del perímetro (de la terraza al techo) y el techo invisible (todas del grupo WallGroup: los
	-- disparos las cruzan).
	-- Oeste y este, cortadas en los dos tramos abiertos de SIDE_DROPS.
	for _, span in
		{ { -EDGE - 2, SIDE_DROPS[2][1] }, { SIDE_DROPS[2][2], SIDE_DROPS[1][1] }, { SIDE_DROPS[1][2], EDGE + 2 } }
	do
		barrier(-EDGE - 2, span[1], -EDGE + 1, span[2], TERRACE_TOP, CEILING - TERRACE_TOP, edges)
		barrier(EDGE - 1, span[1], EDGE + 2, span[2], TERRACE_TOP, CEILING - TERRACE_TOP, edges)
	end
	-- Empiezan un stud antes del borde (sobre el pretil de 1 de ancho): el jugador se para ante él.
	barrier(-EDGE, EDGE - 1, EDGE, EDGE + 2, TERRACE_TOP, CEILING - TERRACE_TOP, edges)
	barrier(-EDGE, -EDGE - 2, EDGE, -EDGE + 1, TERRACE_TOP, CEILING - TERRACE_TOP, edges)
	barrier(-EDGE - 2, -EDGE - 2, EDGE + 2, EDGE + 2, CEILING, 2, edges)
end

local function buildStairs(model: Model)
	local stairs = folder(model, "Escaleras")
	local depth = (LEDGE_Z - STAIR_Z1) / STAIR_STEPS
	for _, sideX in { -1, 1 } do
		for step = 1, STAIR_STEPS do
			local z1 = STAIR_Z1 + (step - 1) * depth
			local part = between(
				"Escalon",
				sideX * STAIR_X1,
				z1,
				sideX * STAIR_X2,
				z1 + depth,
				TERRACE_TOP,
				step,
				tone(CONCRETE_LIGHT, 0.12),
				Enum.Material.Concrete,
				stairs
			)
			part.Locked = true
		end
		-- Pasamanos de hierro por los dos lados, con postes.
		for _, x in { sideX * (STAIR_X1 + 0.2), sideX * (STAIR_X2 - 0.2) } do
			local from = Vector3.new(x, TERRACE_TOP + 3.2, STAIR_Z1)
			local to = Vector3.new(x, 3.2, LEDGE_Z)
			block(
				"Pasamanos",
				Vector3.new(0.4, 0.4, (to - from).Magnitude),
				CFrame.lookAt((from + to) / 2, to),
				RUST,
				Enum.Material.CorrodedMetal,
				stairs
			)
			for _, z in { STAIR_Z1 + 2, STAIR_Z1 + 7, STAIR_Z1 + 12 } do
				local topY = TERRACE_TOP + math.ceil((z - STAIR_Z1) / depth)
				block(
					"Poste",
					Vector3.new(0.4, 3.2, 0.4),
					CFrame.new(x, topY + 1.6, z),
					RUST_DARK,
					Enum.Material.CorrodedMetal,
					stairs
				)
			end
		end
	end
end

-- La pluma caída de la grúa (rampa) y su mástil, que sube de la terraza hasta el techo.
local function buildCrane(model: Model)
	local crane = folder(model, "Grua")
	local from = Vector3.new(0, 0, LEDGE_Z)
	local to = Vector3.new(0, TERRACE_TOP, RAMP_END_Z)
	local length = (to - from).Magnitude
	local base = CFrame.lookAt(from, to)
	-- La cara de arriba de la rampa pasa justo por los dos extremos.
	local deck = block(
		"Pluma",
		Vector3.new(RAMP_HALF * 2, 1, length),
		base * CFrame.new(0, -0.5, -length / 2),
		STEEL_DARK,
		Enum.Material.CorrodedMetal,
		crane
	)
	deck.Locked = true
	for index = 1, math.floor(length / 2) do
		deco(
			"Franja",
			Vector3.new(RAMP_HALF * 2 - 0.4, 0.12, 1.4),
			base * CFrame.new(0, 0.06, -(index - 0.5) * 2),
			if index % 2 == 1 then HAZARD else RUST,
			Enum.Material.SmoothPlastic,
			crane
		)
	end
	for _, sideX in { -1, 1 } do
		block(
			"Celosia",
			Vector3.new(0.5, 1.2, length),
			base * CFrame.new(sideX * (RAMP_HALF + 0.25), 0.1, -length / 2),
			HAZARD,
			Enum.Material.Metal,
			crane
		)
	end
	for index = 1, 4 do
		deco(
			"Travesano",
			Vector3.new(RAMP_HALF * 2 + 1, 0.4, 0.4),
			base * CFrame.new(0, -1.3, -index * 4),
			RUST_DARK,
			Enum.Material.CorrodedMetal,
			crane
		)
	end
	-- El mástil: núcleo macizo (cobertura) con las esquinas amarillas y los aros oxidados, sobre una base.
	local mastTop = CEILING
	local mastHeight = mastTop - TERRACE_TOP
	between("BaseMastil", -3, MAST_Z - 3, 3, MAST_Z + 3, TERRACE_TOP, 1.5, CONCRETE_DARK, Enum.Material.Concrete, crane)
	between(
		"Mastil",
		-1.5,
		MAST_Z - 1.5,
		1.5,
		MAST_Z + 1.5,
		TERRACE_TOP,
		mastHeight,
		STEEL_DARK,
		Enum.Material.Metal,
		crane
	)
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			block(
				"Esquina",
				Vector3.new(0.9, mastHeight, 0.9),
				CFrame.new(cx * 1.2, TERRACE_TOP + mastHeight / 2, MAST_Z + cz * 1.2),
				HAZARD,
				Enum.Material.Metal,
				crane
			)
		end
	end
	for level = 1, 6 do
		block(
			"Aro",
			Vector3.new(3.5, 0.5, 3.5),
			CFrame.new(0, TERRACE_TOP + level * 6, MAST_Z),
			RUST_DARK,
			Enum.Material.CorrodedMetal,
			crane
		)
	end
	deco("Cabina", Vector3.new(4.4, 3, 4.4), CFrame.new(0, mastTop - 1.6, MAST_Z), STEEL, Enum.Material.Metal, crane)
	-- Los tirantes del mástil a la pluma.
	cable(crane, Vector3.new(0, mastTop - 2, MAST_Z + 2.2), Vector3.new(0, 1.2, LEDGE_Z - 0.6), 4)
	cable(crane, Vector3.new(0, mastTop - 3, MAST_Z + 2.2), Vector3.new(0, -5.8, -38), 2)
end

-- Cascotes que cierran el paso a la terraza baja en 1v1 y 2v2: uno arriba de cada escalera y otro arriba de
-- la rampa. Sin barreras invisibles dentro: setFormat hace visibles y con choque todas sus piezas.
local function buildCollapse(model: Model)
	local collapse = folder(model, "Derrumbes")
	for _, sideX in { -1, 1 } do
		-- Dos tramos que se solapan: LabParts.rubble deja un hueco de 2 en los anchos de 8.
		LabParts.rubble(collapse, sideX * STAIR_X1, LEDGE_Z - 4, sideX * (STAIR_X1 + 6), LEDGE_Z, WALL_HEIGHT)
		LabParts.rubble(collapse, sideX * (STAIR_X1 + 2), LEDGE_Z - 3.8, sideX * STAIR_X2, LEDGE_Z - 0.2, WALL_HEIGHT)
	end
	LabParts.rubble(collapse, -RAMP_HALF - 1, LEDGE_Z - 3, RAMP_HALF + 1, LEDGE_Z, WALL_HEIGHT)
end

-- Helipuerto: plataforma (y +4) con la H pintada, luces en el borde y una rampa de peldaños finos a cada lado.
local function buildHelipad(model: Model)
	local pad = folder(model, "Helipuerto")
	local centerZ = (HELI_Z1 + HELI_Z2) / 2
	local body = between(
		"Plataforma",
		-HELI_HALF_X,
		HELI_Z1,
		HELI_HALF_X,
		HELI_Z2,
		0,
		HELI_TOP,
		STEEL_DARK,
		Enum.Material.Concrete,
		pad
	)
	body.Locked = true
	local y = HELI_TOP + 0.06
	-- La H y el círculo (cuadrado de bloques).
	deco("HIzquierda", Vector3.new(1.4, 0.12, 10), CFrame.new(-3.5, y, centerZ), LAB_WHITE, nil, pad)
	deco("HDerecha", Vector3.new(1.4, 0.12, 10), CFrame.new(3.5, y, centerZ), LAB_WHITE, nil, pad)
	deco("HCentro", Vector3.new(6.6, 0.12, 1.4), CFrame.new(0, y + 0.01, centerZ), LAB_WHITE, nil, pad)
	for _, sideX in { -1, 1 } do
		deco("Aro", Vector3.new(0.8, 0.12, 19), CFrame.new(sideX * 9.5, y, centerZ), HAZARD, nil, pad)
	end
	for _, sideZ in { -1, 1 } do
		deco("Aro", Vector3.new(19, 0.12, 0.8), CFrame.new(0, y, centerZ + sideZ * 9.5), HAZARD, nil, pad)
	end
	-- Luces de borde, alguna apagada.
	for _, sideX in { -1, 1 } do
		for z = HELI_Z1 + 1, HELI_Z2 - 1, 5 do
			if LabParts.rng:NextNumber() < 0.8 then
				block(
					"Luz",
					Vector3.new(0.8, 0.6, 0.8),
					CFrame.new(sideX * (HELI_HALF_X - 0.6), HELI_TOP + 0.3, z),
					HAZARD,
					Enum.Material.Neon,
					pad
				)
			end
		end
	end
	-- Manga de viento rota en una esquina.
	block(
		"PosteManga",
		Vector3.new(0.4, 6, 0.4),
		CFrame.new(-HELI_HALF_X + 1, HELI_TOP + 3, HELI_Z2 - 1),
		STEEL,
		nil,
		pad
	)
	deco(
		"Manga",
		Vector3.new(0.6, 1.2, 3),
		CFrame.new(-HELI_HALF_X + 1, HELI_TOP + 5.6, HELI_Z2 - 2.6),
		RUST,
		Enum.Material.Fabric,
		pad
	)
	-- Las rampas laterales (z 26–34): ocho peldaños de medio stud, de |x| 20 a 12.
	for _, sideX in { -1, 1 } do
		for step = 1, 8 do
			local near = HELI_HALF_X + 8 - step
			local part = between(
				"Rampa",
				sideX * near,
				26,
				sideX * (near + 1),
				34,
				0,
				step * 0.5,
				tone(CONCRETE, 0.1),
				Enum.Material.Concrete,
				pad
			)
			part.Locked = true
		end
		deco(
			"FranjaRampa",
			Vector3.new(0.8, 0.12, 8),
			CFrame.new(sideX * (HELI_HALF_X + 7.5), 0.6, 30),
			HAZARD,
			nil,
			pad
		)
	end
end

-- Caseta de los ascensores: corta la línea central.
local function buildElevatorHouse(model: Model)
	local house = folder(model, "Caseta")
	between("Caseta", -6, -6, 6, 6, 0, 8, tone(CONCRETE_LIGHT, 0.05), Enum.Material.Concrete, house)
	between("Cornisa", -6.3, -6.3, 6.3, 6.3, 7.4, 0.8, CONCRETE_DARK, Enum.Material.Concrete, house)
	block("Zocalo", Vector3.new(12.4, 1.2, 12.4), CFrame.new(0, 0.6, 0), CONCRETE_DARK, Enum.Material.Concrete, house)
	-- Puertas de ascensor (norte y sur) con el marco, y ventilaciones en los lados.
	for _, sideZ in { -1, 1 } do
		block("Marco", Vector3.new(5, 5.6, 0.3), CFrame.new(0, 3.3, sideZ * 6.1), STEEL_DARK, nil, house)
		block("Puerta", Vector3.new(1.8, 4.6, 0.3), CFrame.new(-1, 3.1, sideZ * 6.2), STEEL, Enum.Material.Metal, house)
		block(
			"Puerta",
			Vector3.new(1.8, 4.6, 0.3),
			CFrame.new(1.4, 3.1, sideZ * 6.2),
			STEEL,
			Enum.Material.Metal,
			house
		)
		hazardStripe(house, Vector3.new(0, 0.05, sideZ * 7.5), 6, false)
	end
	for _, sideX in { -1, 1 } do
		for index = 0, 2 do
			block("Rejilla", Vector3.new(0.3, 0.5, 5), CFrame.new(sideX * 6.1, 3.5 + index, 0), CABLE, nil, house)
		end
	end
	-- Encima: ventilaciones, el motor y una antena.
	for _, sideX in { -1, 1 } do
		deco(
			"Ventilacion",
			Vector3.new(2.4, 1.6, 2.4),
			CFrame.new(sideX * 3, 9, sideX * -2),
			STEEL,
			Enum.Material.Metal,
			house
		)
	end
	deco("Antena", Vector3.new(0.5, 9, 0.5), CFrame.new(0, 12.7, 0), STEEL, Enum.Material.Metal, house)
	deco("Travesano", Vector3.new(4, 0.4, 0.4), CFrame.new(0, 16, 0), STEEL_DARK, nil, house)
	deco("Travesano", Vector3.new(2.6, 0.4, 0.4), CFrame.new(0, 14, 0), STEEL_DARK, nil, house)
end

-- Aparato de aire acondicionado de 6 × 3,5 × 4 (cobertura media). "turned": girado 90°. "floorY": el suelo
-- donde se apoya (la azotea, y 0, o la terraza baja).
local function airConditioner(parent: Instance, x: number, z: number, turned: boolean, floorY: number?)
	local pose = CFrame.new(x, floorY or 0, z) * CFrame.Angles(0, if turned then math.pi / 2 else 0, 0)
	block("Aparato", Vector3.new(6, 3.5, 4), pose * CFrame.new(0, 1.75, 0), tone(LAB_WHITE, 0.25), nil, parent)
	block("Tapa", Vector3.new(6.3, 0.4, 4.3), pose * CFrame.new(0, 3.7, 0), STEEL, nil, parent)
	deco("Ventilador", Vector3.new(2.6, 0.2, 2.6), pose * CFrame.new(-1.3, 3.95, 0), CABLE, nil, parent)
	deco("Ventilador", Vector3.new(2.6, 0.2, 2.6), pose * CFrame.new(1.5, 3.95, 0), CABLE, nil, parent)
	block("Rejilla", Vector3.new(4.4, 1.6, 0.2), pose * CFrame.new(0, 1.9, 2.05), STEEL_DARK, nil, parent)
	block("Oxido", Vector3.new(6.1, 0.8, 4.1), pose * CFrame.new(0, 0.4, 0), RUST, Enum.Material.CorrodedMetal, parent)
end

-- Depósito de agua de madera (cobertura alta): pedestal, barril con aros, tapa y tubo.
local function waterTank(parent: Instance, x: number, z: number)
	local pose = CFrame.new(x, 0, z)
	block("Pedestal", Vector3.new(5, 3, 5), pose * CFrame.new(0, 1.5, 0), CONCRETE_DARK, Enum.Material.Concrete, parent)
	block("Deposito", Vector3.new(6, 6, 6), pose * CFrame.new(0, 6, 0), WOOD, Enum.Material.WoodPlanks, parent)
	for _, y in { 4.4, 7.6 } do
		block(
			"Aro",
			Vector3.new(6.4, 0.5, 6.4),
			pose * CFrame.new(0, y, 0),
			RUST_DARK,
			Enum.Material.CorrodedMetal,
			parent
		)
	end
	block("Tapa", Vector3.new(6.8, 1, 6.8), pose * CFrame.new(0, 9.5, 0), WOOD_DARK, Enum.Material.Wood, parent)
	block("Remate", Vector3.new(3.4, 1, 3.4), pose * CFrame.new(0, 10.5, 0), WOOD_DARK, Enum.Material.Wood, parent)
	block("Tubo", Vector3.new(0.7, 4, 0.7), pose * CFrame.new(3.2, 1.5, 0), STEEL, Enum.Material.Metal, parent)
end

-- Claraboya rota (cobertura baja): marco macizo con el cristal agrietado y esquirlas.
local function skylight(parent: Instance, x: number, z: number)
	local pose = CFrame.new(x, 0, z)
	block("Marco", Vector3.new(6, 1, 6), pose * CFrame.new(0, 0.5, 0), CONCRETE_DARK, Enum.Material.Concrete, parent)
	local glass =
		block("Cristal", Vector3.new(4, 1, 4), pose * CFrame.new(0, 1.5, 0), GLASS, Enum.Material.Glass, parent)
	glass.Transparency = 0.35
	deco(
		"Esquirla",
		Vector3.new(1.5, 0.2, 1.5),
		pose * CFrame.new(1, 2.3, -0.6) * CFrame.Angles(0.5, 0.4, 0.3),
		GLASS,
		Enum.Material.Glass,
		parent
	)
	deco(
		"Esquirla",
		Vector3.new(1.2, 0.2, 1.2),
		pose * CFrame.new(-1.2, 2.2, 1) * CFrame.Angles(-0.4, 0.8, 0.2),
		GLASS,
		Enum.Material.Glass,
		parent
	)
end

-- Chimenea de ventilación: tubo macizo de hierro.
local function ventPipe(parent: Instance, x: number, z: number, height: number)
	block(
		"Chimenea",
		Vector3.new(2.4, height, 2.4),
		CFrame.new(x, height / 2, z),
		RUST,
		Enum.Material.CorrodedMetal,
		parent
	)
	block("Boca", Vector3.new(3, 0.6, 3), CFrame.new(x, height + 0.3, z), STEEL_DARK, nil, parent)
end

-- Antena en pie: base maciza y mástil decorativo con travesaños y una luz.
local function standingAntenna(parent: Instance, x: number, z: number, height: number): Vector3
	block("BaseAntena", Vector3.new(2.4, 2, 2.4), CFrame.new(x, 1, z), CONCRETE_DARK, Enum.Material.Concrete, parent)
	block("Antena", Vector3.new(0.7, height, 0.7), CFrame.new(x, 2 + height / 2, z), STEEL, Enum.Material.Metal, parent)
	for index, level in { 0.45, 0.65, 0.85 } do
		deco(
			"Travesano",
			Vector3.new(5 - index, 0.4, 0.4),
			CFrame.new(x, 2 + height * level, z),
			STEEL_DARK,
			nil,
			parent
		)
	end
	deco("Luz", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, 2 + height + 0.4, z), HAZARD, Enum.Material.Neon, parent)
	return Vector3.new(x, 2 + height, z)
end

-- Antena caída (cobertura baja): z -21…-19, x ±[4, 18]; el plato roto en la punta y cables a la caseta.
local function fallenAntenna(parent: Instance)
	for _, sideX in { -1, 1 } do
		between("AntenaCaida", sideX * 4, -21, sideX * 18, -19, 0, 2, STEEL, Enum.Material.Metal, parent)
		for x = 5, 17, 3 do
			block(
				"Travesano",
				Vector3.new(0.5, 0.5, 2.6),
				CFrame.new(sideX * x, 2.2, -20),
				RUST_DARK,
				Enum.Material.CorrodedMetal,
				parent
			)
		end
		block("Base", Vector3.new(2, 0.8, 2.4), CFrame.new(sideX * 4.5, 0.4, -20), CONCRETE_DARK, nil, parent)
		-- Macizo (cuenta como cobertura): inclinado, con la esquina baja apoyada en el suelo.
		block(
			"Plato",
			Vector3.new(4, 0.5, 4),
			CFrame.new(sideX * 18.5, 2.1, -20) * CFrame.Angles(0.5, 0, sideX * 0.6),
			LAB_WHITE,
			Enum.Material.Metal,
			parent
		)
		cable(parent, Vector3.new(sideX * 4, 2, -20), Vector3.new(sideX * 6, 7.6, -6), 2)
	end
end

local function buildRoofCovers(model: Model)
	local covers = folder(model, "Coberturas")
	airConditioner(covers, 0, -12, false)
	local antennaTops: { Vector3 } = {}
	for _, sideX in { -1, 1 } do
		-- Los flancos entre la caseta y las bocas. Los dos primeros quedan fuera de los carriles de las bocas
		-- (|z| 3 a 9) para que los rifles tengan línea de tiro libre de boca a boca.
		airConditioner(covers, sideX * 34, 13, false)
		airConditioner(covers, sideX * 34, -13, false)
		airConditioner(covers, sideX * 44, 30, false)
		airConditioner(covers, sideX * 44, -24, false)
		airConditioner(covers, sideX * 40, 48, false)
		waterTank(covers, sideX * 16, 14)
		waterTank(covers, sideX * 16, -14)
		waterTank(covers, sideX * 50, 36)
		skylight(covers, sideX * 28, 36)
		skylight(covers, sideX * 8, 46)
		skylight(covers, sideX * 30, -18)
		ventPipe(covers, sideX * 10, -26, 5)
		ventPipe(covers, sideX * 12, 52, 5)
		crate(covers, Vector3.new(sideX * 41, 0, 16), 3, RUST_DARK)
		crate(covers, Vector3.new(sideX * 44, 0, 19), 2, STEEL)
		crate(covers, Vector3.new(sideX * 41, 0, -18), 3, STEEL)
		crate(covers, Vector3.new(sideX * 31, 0, 53), 3, WOOD)
		crate(covers, Vector3.new(sideX * 16, 0, -26), 3, RUST_DARK)
		crate(covers, Vector3.new(sideX * 24, 0, 20), 3, WOOD_DARK)
		table.insert(antennaTops, standingAntenna(covers, sideX * 53, 44, 22))
		table.insert(antennaTops, standingAntenna(covers, sideX * 53, -20, 18))
		-- Cables de la caseta a las antenas.
		cable(covers, Vector3.new(sideX * 3, 10, 0), antennaTops[#antennaTops - 1], 4)
		cable(covers, Vector3.new(sideX * 3, 9, 0), antennaTops[#antennaTops], 4)
	end
	fallenAntenna(covers)
end

local function buildTerraceCovers(model: Model)
	local covers = folder(model, "CoberturasTerraza")
	for _, sideX in { -1, 1 } do
		airConditioner(covers, sideX * 14, -38, false, TERRACE_TOP)
		airConditioner(covers, sideX * 12, -55, false, TERRACE_TOP)
		crate(covers, Vector3.new(sideX * 51, TERRACE_TOP, -35), 3, STEEL)
		crate(covers, Vector3.new(sideX * 53, TERRACE_TOP, -52), 3, RUST_DARK)
		crate(covers, Vector3.new(sideX * 38, TERRACE_TOP, -56), 2, WOOD)
		-- Un pretil roto bajo, de cobertura.
		between(
			"MuroRoto",
			sideX * 34,
			-50.5,
			sideX * 44,
			-49.5,
			TERRACE_TOP,
			2.5,
			tone(CONCRETE, 0.15),
			Enum.Material.Concrete,
			covers
		)
		block(
			"Hierro",
			Vector3.new(0.4, 3, 0.4),
			CFrame.new(sideX * 40, TERRACE_TOP + 3.5, -50),
			RUST,
			Enum.Material.CorrodedMetal,
			covers
		)
	end
end

-- El fuste de la torre hasta la selva (decorado): hormigón con franjas de ventanas rotas, el revestimiento
-- algo inclinado y lianas.
local function buildTower(model: Model)
	local tower = folder(model, "Fuste")
	local rng = LabParts.rng
	local bottom = GROUND_Y - 0.8
	-- Faldón bajo el suelo de la azotea (sin cubrir los huecos) y bajo el de la terraza.
	deco("FaldonAzotea", Vector3.new(116, 4, 82), CFrame.new(0, -3, 11), CONCRETE_DARK, Enum.Material.Concrete, tower)
	for _, span in { { -58, -28 }, { -20, 20 }, { 28, 58 } } do
		deco(
			"FaldonTerraza",
			Vector3.new(span[2] - span[1], 3, 28),
			CFrame.new((span[1] + span[2]) / 2, -14.5, -45),
			CONCRETE_DARK,
			Enum.Material.Concrete,
			tower
		)
	end
	-- Los dos cuerpos del fuste: el de la azotea (sube hasta -1) y el de debajo de la terraza (hasta -13).
	local function shaft(name: string, z1: number, z2: number, top: number)
		deco(
			name,
			Vector3.new(SHAFT_HALF * 2, top - bottom, z2 - z1),
			CFrame.new(0, (top + bottom) / 2, (z1 + z2) / 2),
			tone(CONCRETE, 0.15),
			Enum.Material.Concrete,
			tower
		)
	end
	shaft("Fuste", LEDGE_Z, SHAFT_HALF, -1)
	shaft("FusteTerraza", -SHAFT_HALF, LEDGE_Z, -13)
	-- Revestimiento inclinado en tres caras (este, oeste y norte), de -50 a -5.
	local lean = math.atan(8 / 45)
	local slabLength = math.sqrt(8 ^ 2 + 45 ^ 2)
	local slabCenter = SHAFT_HALF + 4
	deco(
		"RevestimientoEste",
		Vector3.new(3, slabLength, 74),
		CFrame.new(slabCenter, -27.5, 7) * CFrame.Angles(0, 0, -lean),
		CONCRETE_DARK,
		Enum.Material.Concrete,
		tower
	)
	deco(
		"RevestimientoOeste",
		Vector3.new(3, slabLength, 74),
		CFrame.new(-slabCenter, -27.5, 7) * CFrame.Angles(0, 0, lean),
		CONCRETE_DARK,
		Enum.Material.Concrete,
		tower
	)
	deco(
		"RevestimientoNorte",
		Vector3.new(88, slabLength, 3),
		CFrame.new(0, -27.5, slabCenter) * CFrame.Angles(lean, 0, 0),
		CONCRETE_DARK,
		Enum.Material.Concrete,
		tower
	)
	-- Franjas de ventanas rotas en las cuatro caras: sin el revestimiento, desde -56 (la cara sur desde -24).
	local faces = {
		{ axis = "x", sign = 1, from = LEDGE_Z, to = SHAFT_HALF, top = -56 },
		{ axis = "x", sign = -1, from = LEDGE_Z, to = SHAFT_HALF, top = -56 },
		{ axis = "z", sign = 1, from = -SHAFT_HALF, to = SHAFT_HALF, top = -56 },
		{ axis = "z", sign = -1, from = -SHAFT_HALF, to = SHAFT_HALF, top = -24 },
	}
	for _, face in faces do
		local span = face.to - face.from
		local segments = math.ceil(span / 24)
		local segLength = span / segments
		for y = face.top, GROUND_Y + 8, -12 do
			for segment = 0, segments - 1 do
				if rng:NextNumber() < 0.8 then
					local along = face.from + (segment + 0.5) * segLength
					local color = if rng:NextNumber() < 0.3 then GLASS else STEEL_DARK
					local size = if face.axis == "x"
						then Vector3.new(0.6, 3.2, segLength - 2)
						else Vector3.new(segLength - 2, 3.2, 0.6)
					local position = if face.axis == "x"
						then Vector3.new(face.sign * (SHAFT_HALF + 0.2), y, along)
						else Vector3.new(along, y, face.sign * (SHAFT_HALF + 0.2))
					deco("Ventanas", size, CFrame.new(position), color, Enum.Material.Glass, tower)
				end
			end
		end
	end
	-- Lianas que cuelgan por las caras.
	for index = 1, 8 do
		local alongX = index % 2 == 0
		local sign = if index % 4 < 2 then 1 else -1
		local along = rng:NextNumber(-30, 30)
		local top = Vector3.new(
			if alongX then sign * SHAFT_HALF else along,
			rng:NextNumber(-60, -30),
			if alongX then math.max(along, LEDGE_Z + 4) else sign * SHAFT_HALF
		)
		vine(tower, top, if alongX then Vector3.new(sign, 0, 0) else Vector3.new(0, 0, sign), rng:NextNumber(14, 24))
	end
	-- Las raíces de la base.
	deco(
		"Cimientos",
		Vector3.new(104, 6, 104),
		CFrame.new(0, GROUND_Y + 2, 0),
		CONCRETE_DARK,
		Enum.Material.Concrete,
		tower
	)
end

-- Selva propia de abajo: árboles altos y plataneras alrededor del fuste, y las torres vecinas.
local function buildJungle(model: Model)
	local jungle = folder(model, "SelvaDeAbajo")
	local rng = LabParts.rng
	for _ = 1, 22 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(66, 150)
		local size = rng:NextNumber(30, 70)
		local ground = Vector3.new(math.cos(angle) * distance, GROUND_Y, math.sin(angle) * distance)
		deco(
			"Tronco",
			Vector3.new(3, size, 3),
			CFrame.new(ground + Vector3.new(0, size / 2, 0)),
			WOOD_DARK,
			Enum.Material.Wood,
			jungle
		)
		deco(
			"Copa",
			Vector3.new(size * 0.7, size * 0.35, size * 0.7),
			CFrame.new(ground + Vector3.new(0, size, 0)),
			if rng:NextNumber() < 0.5 then VINE else VINE_DARK,
			Enum.Material.Grass,
			jungle
		)
	end
	for index = 1, 10 do
		local angle = index * math.pi / 5 + rng:NextNumber(-0.2, 0.2)
		local distance = rng:NextNumber(58, 74)
		bananaPlant(jungle, Vector3.new(math.cos(angle) * distance, GROUND_Y, math.sin(angle) * distance), 9)
	end
	LabParts.buildSkyline(model, {
		towers = SKYLINE_TOWERS,
		baseY = GROUND_Y - 1.8,
		trees = 0,
	})
end

-- La selva que asoma por los bordes: hojas y lianas sobre los pretiles.
local function buildOvergrowth(model: Model)
	local growth = folder(model, "SelvaDeArriba")
	local rng = LabParts.rng
	local leaves = { VINE, LEAF, VINE_DARK }
	for _ = 1, 22 do
		local onZ = rng:NextNumber() < 0.5
		local sign = if rng:NextNumber() < 0.5 then 1 else -1
		local along = rng:NextNumber(-EDGE + 4, EDGE - 4)
		if onZ then
			-- Norte (la azotea) y sur (la terraza), lejos de los huecos.
			local z = if sign > 0 then EDGE + rng:NextNumber(0.2, 1.8) else -EDGE - rng:NextNumber(0.2, 1.8)
			local y = if sign > 0 then rng:NextNumber(-1.5, 0.5) else TERRACE_TOP + rng:NextNumber(-1.5, 0.5)
			if not (math.abs(along) > 13 and math.abs(along) < 29) then
				deco(
					"Hojas",
					Vector3.new(4, 1.5, 3),
					CFrame.new(along, y, z),
					leaves[rng:NextInteger(1, 3)],
					Enum.Material.Grass,
					growth
				)
			end
		else
			local x = sign * (EDGE + rng:NextNumber(0.2, 1.8))
			if math.abs(along) > 16 then
				local y = if along < LEDGE_Z then TERRACE_TOP + rng:NextNumber(-1.5, 0.5) else rng:NextNumber(-1.5, 0.5)
				deco(
					"Hojas",
					Vector3.new(3, 1.5, 4),
					CFrame.new(x, y, along),
					leaves[rng:NextInteger(1, 3)],
					Enum.Material.Grass,
					growth
				)
			end
		end
	end
	for _, x in { -50, -34, -6, 6, 34, 50 } do
		vine(growth, Vector3.new(x, 0, EDGE), Vector3.zAxis, rng:NextNumber(8, 16))
		vine(growth, Vector3.new(x, TERRACE_TOP, -EDGE), -Vector3.zAxis, rng:NextNumber(8, 14))
	end
	for _, sideX in { -1, 1 } do
		for _, z in { 20, 46, -22 } do
			vine(growth, Vector3.new(sideX * EDGE, 0, z), Vector3.new(sideX, 0, 0), rng:NextNumber(8, 16))
		end
		vine(growth, Vector3.new(sideX * EDGE, TERRACE_TOP, -44), Vector3.new(sideX, 0, 0), rng:NextNumber(6, 12))
	end
end

-- Construye el mapa en coordenadas locales dentro de "model" (LabBuilder lo coloca después).
local function build(model: Model)
	buildGround(model)
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	LabParts.buildZone(bases, "Pirates", -1, GEOMETRY)
	LabParts.buildZone(bases, "Guardians", 1, GEOMETRY)
	bases.Parent = model
	buildEdges(model)
	buildStairs(model)
	buildCrane(model)
	buildCollapse(model)
	buildHelipad(model)
	buildElevatorHouse(model)
	buildRoofCovers(model)
	buildTerraceCovers(model)
	buildTower(model)
	buildJungle(model)
	buildOvergrowth(model)
	LabParts.buildFreeSpawns(model, FREE_SPAWNS)
end

return {
	GEOMETRY = GEOMETRY,
	LIGHTING = LIGHTING,
	SEED = SEED,
	OVERHEAD_HEIGHT = OVERHEAD_HEIGHT,
	build = build,
}
