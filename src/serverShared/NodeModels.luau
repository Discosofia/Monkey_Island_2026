--!strict
-- Modelos de los puntos de recolección: árboles (cinco variedades y el mangle), palmeras, rocas irregulares,
-- matas de banano y plátano y arbustos. Los usan ResourceService (nodos de prueba) y MapBuilder
-- (isla generada). Cuando tengas modelos definitivos, basta con ponerles el mismo atributo
-- (ver docs/MAPA.md).
--
-- Rendimiento: cada modelo usa entre 10 y 25 piezas. Troncos y rocas chocan; hojas, ramas y
-- frutos no (ni bloquean rayos), así no molestan al moverse ni a los sistemas.

local NodeModels = {}

-- Atributo que convierte un Model o Part en punto de recolección.
NodeModels.ATTRIBUTE = "ResourceNode"
-- Nombre de las palmeras: ResourceService también lo usa para hacer talables las de mapas antiguos.
NodeModels.PALM_NAME = "Palmera"
-- Si un punto de recolección tiene una carpeta con este nombre, al agotarse solo desaparece ella
-- (el racimo de una mata de banano) y el resto del modelo sigue en su sitio.
NodeModels.HARVEST_FOLDER = "Cosecha"

local TAU = 2 * math.pi
-- Las piezas Cylinder tienen el eje en X: este giro lo pone a lo largo del eje Y del marco.
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)

local BARK = Color3.fromRGB(110, 75, 45)
local LEAF_COLORS = { Color3.fromRGB(45, 120, 55), Color3.fromRGB(60, 140, 60), Color3.fromRGB(35, 100, 45) }
local ROCK_COLORS = {
	Color3.fromRGB(125, 125, 128),
	Color3.fromRGB(110, 104, 98),
	Color3.fromRGB(138, 132, 120),
	Color3.fromRGB(96, 98, 104),
}
local MOSS = Color3.fromRGB(80, 115, 55)

-- Variedades de árbol y su peso en el sorteo (todas dan madera: tipo Tree).
local TREE_VARIETIES: { { name: string, weight: number } } = {
	{ name = "Frondoso", weight = 34 },
	{ name = "Mango", weight = 20 },
	{ name = "Yarumo", weight = 16 },
	{ name = "Guadua", weight = 16 },
	{ name = "Ceiba", weight = 14 },
}

type MusaKind = {
	modelName: string,
	height: number,
	stem: Color3,
	leaf: Color3,
	fruit: Color3,
	finger: Vector3, -- tamaño de cada fruto
	tiers: number, -- manos del racimo
	perTier: number, -- frutos por mano
}

-- Matas de banano y plátano: el plátano es más alto, de tallo más oscuro y fruto verde y largo.
local MUSA_KINDS: { [string]: MusaKind } = {
	BananaPlant = {
		modelName = "MataBanano",
		height = 7.5,
		stem = Color3.fromRGB(125, 150, 70),
		leaf = Color3.fromRGB(85, 165, 60),
		fruit = Color3.fromRGB(235, 205, 60),
		finger = Vector3.new(0.45, 1.3, 0.45),
		tiers = 3,
		perTier = 3,
	},
	PlantainPlant = {
		modelName = "MataPlatano",
		height = 8.5,
		stem = Color3.fromRGB(105, 112, 58),
		leaf = Color3.fromRGB(65, 140, 55),
		fruit = Color3.fromRGB(115, 160, 55),
		finger = Vector3.new(0.55, 1.9, 0.55),
		tiers = 2,
		perTier = 4,
	},
}

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function decorative(part: Part): Part
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

local function newBall(name: string, diameter: number, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = newPart(name, Vector3.one, cframe, color, parent)
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * diameter
	return decorative(part)
end

-- Elipsoide (una bola estirada): copas, racimos y frutos. Las Ball de Roblox solo pueden ser esferas.
local function newEllipsoid(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = decorative(newPart(name, size, cframe, color, parent))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Cilindro que sale de "from" a lo largo de su eje Y. Devuelve el marco del otro extremo, para
-- encadenar tramos (tronco, ramas). Con "solid" choca (troncos); si no, es decorativo (ramas).
local function limb(
	name: string,
	from: CFrame,
	length: number,
	diameter: number,
	color: Color3,
	parent: Instance,
	solid: boolean?
): CFrame
	local part = newPart(
		name,
		Vector3.new(length, diameter, diameter),
		from * CFrame.new(0, length / 2, 0) * ALONG_Y,
		color,
		parent
	)
	part.Shape = Enum.PartType.Cylinder
	if not solid then
		decorative(part)
	end
	return from * CFrame.new(0, length, 0)
end

-- Cuña: la cara alta queda hacia +Z del marco y la pendiente baja hacia -Z (LookVector).
local function newWedge(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Anchored = true
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Color = color
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.Parent = parent
	return wedge
end

-- Variación de un color: un poco más claro o más oscuro.
local function shade(color: Color3, rng: Random, amount: number): Color3
	local target = if rng:NextNumber() < 0.5 then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
	return color:Lerp(target, rng:NextNumber(0, amount))
end

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

-- Giro al azar: cualquier rumbo y una inclinación de hasta "tilt" radianes.
local function randomTilt(rng: Random, tilt: number): CFrame
	return CFrame.Angles(rng:NextNumber(-tilt, tilt), rng:NextNumber(0, TAU), rng:NextNumber(-tilt, tilt))
end

local function jitter(rng: Random, amount: number): Vector3
	return Vector3.new(
		rng:NextNumber(1 - amount, 1 + amount),
		rng:NextNumber(1 - amount, 1 + amount),
		rng:NextNumber(1 - amount, 1 + amount)
	)
end

local function leafy(part: Part): Part
	part.Material = Enum.Material.LeafyGrass
	return decorative(part)
end

-- Mata de hojas de una copa: dos bloques con textura de hojas, girados al azar y cruzados, como
-- las rocas. El contorno sale irregular y con facetas, no una bola perfecta. "size" es el tamaño
-- aproximado de la mata; "tilt" cuánto se inclinan (poco en copas planas como la de la ceiba).
local function foliage(parent: Instance, position: Vector3, size: Vector3, color: Color3, rng: Random, tilt: number)
	leafy(
		newPart(
			"Leaves",
			size * Vector3.new(0.8, 0.85, 0.8) * jitter(rng, 0.1),
			CFrame.new(position) * randomTilt(rng, tilt),
			color,
			parent
		)
	)
	local offset = Vector3.new(
		rng:NextNumber(-0.2, 0.2) * size.X,
		rng:NextNumber(0, 0.15) * size.Y,
		rng:NextNumber(-0.2, 0.2) * size.Z
	)
	leafy(
		newPart(
			"Leaves",
			size * Vector3.new(0.7, 0.7, 0.7) * jitter(rng, 0.12),
			CFrame.new(position + offset) * randomTilt(rng, tilt * 1.3),
			shade(color, rng, 0.12),
			parent
		)
	)
end

-- Convierte un modelo decorativo (por ejemplo, una palmera) en punto de recolección del tipo dado.
-- Pone un punto invisible a la altura del jugador sobre "base" (el pie del tronco): ahí se miden
-- el alcance del hacha y la barra de progreso. "footprint" (opcional) es el ancho de ese punto:
-- en árboles con raíces anchas o rocas grandes, así se alcanzan desde el borde y no solo del centro.
function NodeModels.makeHarvestable(model: Model, nodeType: string, base: Vector3, footprint: number?)
	local width = footprint or 1
	local anchor = Instance.new("Part")
	anchor.Name = "PromptAnchor"
	anchor.Size = Vector3.new(width, 1, width)
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

-- ÁRBOLES ---------------------------------------------------------------------------------------
-- Cada constructor recibe el modelo, el marco del pie (ya girado), el rng y la escala, y devuelve
-- el ancho de la base (para el punto de tala).

-- Árbol frondoso de la selva: tronco en dos tramos, raíces, tres ramas y copa en racimos.
local function buildBroadleaf(tree: Model, base: CFrame, rng: Random, s: number): number
	local bark = shade(BARK, rng, 0.15)
	local leaf = pick(LEAF_COLORS, rng)
	local height = 15 * s

	for i = 0, 2 do
		local yaw = i * TAU / 3 + rng:NextNumber(-0.4, 0.4)
		-- Inclinado 115°: sale del tronco hacia fuera y se hunde en el suelo.
		limb(
			"Root",
			base * CFrame.new(0, 1.2 * s, 0) * CFrame.Angles(0, yaw, math.rad(115)),
			3.5 * s,
			0.9 * s,
			bark,
			tree
		)
	end

	local lowerLength = height * 0.6
	local upperStart = limb("Trunk", base * CFrame.new(0, -1, 0), lowerLength, 2.3 * s, bark, tree, true)
		* CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
	local upperLength = height * 0.45
	local top = limb("Trunk", upperStart, upperLength, 1.7 * s, bark, tree, true)

	for i = 0, 2 do
		local yaw = i * TAU / 3 + rng:NextNumber(-0.5, 0.5)
		local from = upperStart
			* CFrame.new(0, rng:NextNumber(0.2, 0.6) * upperLength, 0)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(math.rad(rng:NextNumber(40, 60)), 0, 0)
		local tip = limb("Branch", from, 5.5 * s, 0.9 * s, bark, tree)
		foliage(
			tree,
			tip.Position + Vector3.new(0, s, 0),
			Vector3.new(rng:NextNumber(7, 9), rng:NextNumber(4.5, 5.5), rng:NextNumber(7, 9)) * s,
			shade(leaf, rng, 0.12),
			rng,
			0.55
		)
	end
	foliage(tree, (top * CFrame.new(0, 1.5 * s, 0)).Position, Vector3.new(10, 6, 10) * s, leaf, rng, 0.45)
	return 3 * s
end

-- Ceiba: árbol gigante con raíces tabulares (aletas), copa ancha y plana y lianas colgando.
local function buildCeiba(tree: Model, base: CFrame, rng: Random, s: number): number
	local bark = shade(Color3.fromRGB(150, 140, 120), rng, 0.1)
	local leaf = shade(LEAF_COLORS[2], rng, 0.1)
	local lowerDiameter = 3.4 * s

	local buttressLength = 4.5 * s
	for i = 0, 4 do
		local frame = base * CFrame.Angles(0, i * TAU / 5 + rng:NextNumber(-0.3, 0.3), 0)
		local size = Vector3.new(0.8 * s, rng:NextNumber(5.5, 7) * s, buttressLength)
		newWedge(
			"Buttress",
			size,
			frame * CFrame.new(0, size.Y / 2 - 0.5, -(lowerDiameter / 2 + buttressLength / 2 - 0.6 * s)),
			bark,
			tree
		)
	end

	local upperStart = limb("Trunk", base * CFrame.new(0, -1, 0), 14 * s, lowerDiameter, bark, tree, true)
	local top = limb("Trunk", upperStart, 9 * s, 2.6 * s, bark, tree, true)

	local liana = Color3.fromRGB(50, 90, 40)
	for i = 0, 4 do
		local yaw = i * TAU / 5 + rng:NextNumber(-0.3, 0.3)
		local from = top
			* CFrame.new(0, -rng:NextNumber(0, 3) * s, 0)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(math.rad(rng:NextNumber(62, 75)), 0, 0)
		local tip = limb("Branch", from, 8 * s, 1.1 * s, bark, tree)
		foliage(
			tree,
			tip.Position + Vector3.new(0, 1.2 * s, 0),
			Vector3.new(rng:NextNumber(10, 12), rng:NextNumber(3, 4), rng:NextNumber(10, 12)) * s,
			shade(leaf, rng, 0.1),
			rng,
			0.15
		)
		if i < 2 then
			local length = rng:NextNumber(7, 11) * s
			decorative(
				newPart(
					"Liana",
					Vector3.new(0.25, length, 0.25),
					CFrame.new(tip.Position - Vector3.new(0, length / 2, 0)),
					liana,
					tree
				)
			)
		end
	end
	foliage(tree, (top * CFrame.new(0, 2 * s, 0)).Position, Vector3.new(13, 4, 13) * s, leaf, rng, 0.12)
	return lowerDiameter + buttressLength
end

-- Mango: tronco corto que se abre en tres ramas, copa densa y redonda y mangos colgando.
local function buildMango(tree: Model, base: CFrame, rng: Random, s: number): number
	local bark = shade(Color3.fromRGB(95, 70, 50), rng, 0.12)
	local leaf = shade(Color3.fromRGB(35, 95, 40), rng, 0.1)
	local fork = limb("Trunk", base * CFrame.new(0, -1, 0), 7 * s, 2 * s, bark, tree, true)

	for i = 0, 2 do
		local yaw = i * TAU / 3 + rng:NextNumber(-0.4, 0.4)
		local tip = limb(
			"Branch",
			fork * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(rng:NextNumber(28, 40)), 0, 0),
			5 * s,
			1.1 * s,
			bark,
			tree
		)
		foliage(
			tree,
			tip.Position + Vector3.new(0, s, 0),
			Vector3.new(7.5, 6, 7.5) * s,
			shade(leaf, rng, 0.1),
			rng,
			0.6
		)
	end
	local crown = fork * CFrame.new(0, 5 * s, 0)
	foliage(tree, crown.Position, Vector3.new(12, 8, 12) * s, leaf, rng, 0.4)

	local mangoColors = { Color3.fromRGB(240, 170, 40), Color3.fromRGB(230, 110, 40), Color3.fromRGB(200, 190, 50) }
	for i = 0, 5 do
		local angle = i * TAU / 6 + rng:NextNumber(-0.3, 0.3)
		local radius = rng:NextNumber(3.5, 5) * s
		local position = crown.Position + Vector3.new(math.cos(angle) * radius, -3.6 * s, math.sin(angle) * radius)
		newBall("Mango", 0.8, CFrame.new(position), pick(mangoColors, rng), tree)
	end
	return 2.5 * s
end

-- Yarumo: tronco fino y claro con anillos y hojas palmeadas plateadas en sombrilla.
local function buildYarumo(tree: Model, base: CFrame, rng: Random, s: number): number
	local bark = shade(Color3.fromRGB(180, 175, 160), rng, 0.08)
	local leaf = shade(Color3.fromRGB(130, 160, 120), rng, 0.08)
	local underside = Color3.fromRGB(185, 195, 170)
	local height = 17 * s
	local top = limb("Trunk", base * CFrame.new(0, -1, 0), height, 1.1 * s, bark, tree, true)

	for i = 1, 2 do
		local ring = newPart(
			"Ring",
			Vector3.new(0.25, 1.35 * s, 1.35 * s),
			base * CFrame.new(0, height * i / 3, 0) * ALONG_Y,
			bark:Lerp(Color3.new(1, 1, 1), 0.2),
			tree
		)
		ring.Shape = Enum.PartType.Cylinder
		decorative(ring)
	end

	for i = 0, 2 do
		local yaw = i * TAU / 3 + rng:NextNumber(-0.4, 0.4)
		local tip = limb(
			"Branch",
			top * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(rng:NextNumber(30, 45)), 0, 0),
			3.5 * s,
			0.5 * s,
			bark,
			tree
		)
		-- Media vuelta: así el -Z del marco apunta hacia fuera, como la rama.
		local umbrella = CFrame.new(tip.Position) * CFrame.Angles(0, yaw + math.pi, 0)
		for k = 0, 2 do
			leafy(
				newPart(
					"Leaf",
					Vector3.new(1.5 * s, 0.2, rng:NextNumber(5.5, 6.8) * s),
					umbrella * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, 0),
					shade(leaf, rng, 0.08),
					tree
				)
			)
		end
		-- Una hoja vieja que cuelga del borde, enseñando el envés plateado.
		decorative(
			newPart(
				"Leaf",
				Vector3.new(1.4 * s, 0.15, 3.5 * s),
				umbrella * CFrame.new(0, 0, -2.8 * s) * CFrame.Angles(math.rad(-55), 0, 0) * CFrame.new(0, 0, -1.75 * s),
				underside,
				tree
			)
		)
	end
	return 1.5 * s
end

-- Guadua: mata de bambú con varias cañas que se abren un poco hacia fuera.
local function buildGuadua(tree: Model, base: CFrame, rng: Random, s: number): number
	local cane = Color3.fromRGB(130, 150, 60)
	local leaf = Color3.fromRGB(90, 150, 60)
	for _ = 1, rng:NextInteger(6, 9) do
		local height = rng:NextNumber(16, 24) * s
		-- Angles(-x) inclina el eje Y hacia -Z, es decir, hacia fuera de la mata.
		local from = base
			* CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
			* CFrame.new(0, -0.5, -rng:NextNumber(0, 1.6) * s)
			* CFrame.Angles(-math.rad(rng:NextNumber(4, 14)), 0, 0)
		local top =
			limb("Trunk", from, height, rng:NextNumber(0.7, 0.95) * math.sqrt(s), shade(cane, rng, 0.15), tree, true)
		-- Ramilletes de hojas: dos láminas cruzadas a lo largo de la punta de la caña.
		local spray = top * CFrame.new(0, -1.5 * s, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		for k = 0, 1 do
			leafy(
				newPart(
					"Leaves",
					Vector3.new(3, 6.5, 1.1) * s * jitter(rng, 0.15),
					spray * CFrame.Angles(0, k * math.pi / 2, rng:NextNumber(-0.2, 0.2)),
					shade(leaf, rng, 0.12),
					tree
				)
			)
		end
	end
	return 4 * s
end

local TREE_BUILDERS: { [string]: (Model, CFrame, Random, number) -> number } = {
	Frondoso = buildBroadleaf,
	Ceiba = buildCeiba,
	Mango = buildMango,
	Yarumo = buildYarumo,
	Guadua = buildGuadua,
}

local function pickVariety(rng: Random): string
	local total = 0
	for _, variety in TREE_VARIETIES do
		total += variety.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, variety in TREE_VARIETIES do
		roll -= variety.weight
		if roll <= 0 then
			return variety.name
		end
	end
	return TREE_VARIETIES[1].name
end

-- Cilindro de adorno entre dos puntos, un poco más largo para que las uniones no dejen huecos.
local function rod(name: string, from: Vector3, to: Vector3, diameter: number, color: Color3, parent: Instance)
	local length = (to - from).Magnitude + diameter * 0.5
	local part = decorative(
		newPart(
			name,
			Vector3.new(length, diameter, diameter),
			CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0),
			color,
			parent
		)
	)
	part.Shape = Enum.PartType.Cylinder
end

-- Mangle (solo en el manglar, ver MapBuilder): el tronco nace en alto, sobre raíces zanco que
-- salen en arco y se clavan en el barro; copa densa y ancha, y raíces aéreas que cuelgan de las
-- ramas. Se tala como cualquier árbol (tipo Tree). Las raíces no chocan, para poder cruzarlo.
function NodeModels.buildMangrove(ground: Vector3, rng: Random, scale: number): Model
	local tree = Instance.new("Model")
	tree.Name = "Mangle"
	local s = scale
	local bark = shade(Color3.fromRGB(115, 70, 55), rng, 0.12)
	local rootColor = bark:Lerp(Color3.fromRGB(60, 45, 40), 0.3)
	local leaf = shade(Color3.fromRGB(70, 140, 50), rng, 0.1)
	local base = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local rootTop = rng:NextNumber(3, 4) * s

	-- Raíces zanco: del tronco salen hacia fuera subiendo un poco (rodilla) y bajan al barro.
	local reach = 0
	local count = rng:NextInteger(6, 8)
	for i = 0, count - 1 do
		local angle = i * TAU / count + rng:NextNumber(-0.3, 0.3)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local start = ground + Vector3.new(0, rootTop - rng:NextNumber(0, 1.2) * s, 0) + out * 0.35 * s
		local knee = start + out * rng:NextNumber(1, 1.6) * s + Vector3.new(0, rng:NextNumber(0.1, 0.5) * s, 0)
		local footDistance = rng:NextNumber(2.6, 3.8) * s
		local foot = ground + out * footDistance - Vector3.new(0, 0.4, 0)
		rod("Root", start, knee, 0.32 * s, rootColor, tree)
		rod("Root", knee, foot, 0.3 * s, rootColor, tree)
		reach = math.max(reach, footDistance)
	end

	local trunkStart = base
		* CFrame.new(0, rootTop - 0.5 * s, 0)
		* CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08))
	local trunkLength = rng:NextNumber(5.5, 7) * s
	local top = limb("Trunk", trunkStart, trunkLength, 1 * s, bark, tree, true)

	-- Ramas abiertas con matas de hojas; de dos de ellas cuelga una raíz aérea hasta el barro.
	for i = 0, 3 do
		local yaw = i * TAU / 4 + rng:NextNumber(-0.4, 0.4)
		local from = trunkStart
			* CFrame.new(0, rng:NextNumber(0.55, 0.9) * trunkLength, 0)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(math.rad(rng:NextNumber(40, 60)), 0, 0)
		local tip = limb("Branch", from, 3.2 * s, 0.4 * s, bark, tree)
		foliage(
			tree,
			tip.Position + Vector3.new(0, 0.6 * s, 0),
			Vector3.new(6, 3.5, 6) * s,
			shade(leaf, rng, 0.1),
			rng,
			0.4
		)
		if i < 2 then
			local hang = tip.Position - Vector3.new(0, 0.5 * s, 0)
			rod("AerialRoot", hang, Vector3.new(hang.X, ground.Y - 0.3, hang.Z), 0.12 * s, rootColor, tree)
		end
	end
	foliage(tree, top.Position + Vector3.new(0, 1.2 * s, 0), Vector3.new(7, 4, 7) * s, leaf, rng, 0.35)

	-- Punto de tala que cubre la mitad interior de las raíces: el hacha alcanza desde su borde.
	NodeModels.makeHarvestable(tree, "Tree", ground, reach)
	return tree
end

-- Árbol talable (tipo Tree) de una variedad al azar, o la indicada en "variety".
function NodeModels.buildTree(ground: Vector3, rng: Random, scale: number, variety: string?): Model
	local name = variety or pickVariety(rng)
	local tree = Instance.new("Model")
	tree.Name = name
	local base = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local footprint = TREE_BUILDERS[name](tree, base, rng, scale)
	NodeModels.makeHarvestable(tree, "Tree", ground, footprint)
	return tree
end

-- Palmera de la playa: tronco en tramos que se curva, penachos de hojas caídas y cocos.
-- Se tala con el hacha y da madera y cocos (Data/ResourceNodes, tipo Palm).
function NodeModels.buildPalm(ground: Vector3, rng: Random): Model
	local palm = Instance.new("Model")
	palm.Name = NodeModels.PALM_NAME
	local s = rng:NextNumber(0.9, 1.3)
	local lean = math.rad(rng:NextNumber(3, 7))
	local trunk = Color3.fromRGB(150, 115, 70)

	-- Tronco en 5 tramos, cada uno más fino y algo más inclinado: se notan los anillos.
	local frame = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.new(0, -0.5, 0)
	for i = 1, 5 do
		frame = limb(
			"Trunk",
			frame * CFrame.Angles(lean, 0, 0),
			3.8 * s,
			(1.75 - i * 0.12) * s,
			if i % 2 == 0 then trunk else trunk:Lerp(Color3.new(0, 0, 0), 0.12),
			palm,
			true
		)
	end
	-- Corona horizontal sobre la punta (el tronco termina inclinado).
	local top = CFrame.new(frame.Position)
	newEllipsoid("Crown", Vector3.new(1.8, 1.3, 1.8) * s, top, Color3.fromRGB(110, 120, 55), palm)

	-- 8 hojas: un tramo que sube y otro que cae. Una de ellas, seca y más caída.
	local dry = rng:NextInteger(0, 7)
	for i = 0, 7 do
		local isDry = i == dry
		local color = if isDry then Color3.fromRGB(150, 120, 60) else shade(Color3.fromRGB(70, 150, 60), rng, 0.12)
		local rise = math.rad(if isDry then -40 else rng:NextNumber(8, 20))
		local inner = top * CFrame.Angles(0, i * TAU / 8 + rng:NextNumber(-0.15, 0.15), 0) * CFrame.Angles(rise, 0, 0)
		decorative(
			newPart("Frond", Vector3.new(1.6 * s, 0.25, 4.5 * s), inner * CFrame.new(0, 0, -2.25 * s), color, palm)
		)
		local outer = inner * CFrame.new(0, 0, -4.4 * s) * CFrame.Angles(math.rad(-rng:NextNumber(35, 50)), 0, 0)
		decorative(newPart("Frond", Vector3.new(1.2 * s, 0.2, 4 * s), outer * CFrame.new(0, 0, -2 * s), color, palm))
	end
	for i = 0, 2 do
		local angle = i * TAU / 3 + rng:NextNumber(-0.3, 0.3)
		newBall(
			"Coconut",
			1.2,
			top * CFrame.new(math.cos(angle) * 0.8, -0.9, math.sin(angle) * 0.8),
			Color3.fromRGB(90, 60, 30),
			palm
		)
	end
	NodeModels.makeHarvestable(palm, "Palm", ground)
	return palm
end

-- ROCAS ----------------------------------------------------------------------------------------
-- Varios bloques y cuñas girados al azar que se cruzan entre sí: el contorno sale irregular y con
-- facetas, como una roca de verdad, y el choque sigue siendo exacto.

local function rockPiece(rock: Model, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = newPart("Rock", size, cframe, color, rock)
	part.Material = material
	return part
end

-- Cuñas apoyadas en el pie de la roca, con la pendiente hacia fuera, y guijarros alrededor.
local function rockSkirt(
	rock: Model,
	base: CFrame,
	rng: Random,
	s: number,
	color: Color3,
	wedges: number,
	reach: number
)
	for _ = 1, wedges do
		local wedge = newWedge(
			"Rock",
			Vector3.new(rng:NextNumber(2, 3), rng:NextNumber(1.4, 2.2), rng:NextNumber(2, 3)) * s,
			base
				* CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
				* CFrame.new(0, 0.4 * s, -reach * s)
				* CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.15, 0.15)),
			shade(color, rng, 0.08),
			rock
		)
		wedge.Material = Enum.Material.Rock
	end
	for _ = 1, rng:NextInteger(2, 3) do
		local angle = rng:NextNumber(0, TAU)
		local distance = rng:NextNumber(reach + 1, reach + 2.5) * s
		decorative(
			rockPiece(
				rock,
				Vector3.new(rng:NextNumber(0.6, 1.4), rng:NextNumber(0.4, 0.9), rng:NextNumber(0.6, 1.3)),
				base * CFrame.new(math.cos(angle) * distance, 0.15, math.sin(angle) * distance) * randomTilt(rng, 0.4),
				shade(color, rng, 0.1),
				Enum.Material.Rock
			)
		)
	end
end

-- Musgo pegado a la cara de arriba de una pieza.
local function addMoss(rock: Model, piece: Part, rng: Random)
	decorative(
		rockPiece(
			rock,
			Vector3.new(piece.Size.X * 0.75, 0.3, piece.Size.Z * 0.7),
			piece.CFrame * CFrame.new(rng:NextNumber(-0.3, 0.3), piece.Size.Y / 2, rng:NextNumber(-0.3, 0.3)),
			shade(MOSS, rng, 0.1),
			Enum.Material.Grass
		)
	)
end

-- Canto rodado: tres bloques girados unos sobre otros.
local function buildBoulder(rock: Model, base: CFrame, rng: Random, s: number, color: Color3): number
	local center = base * CFrame.new(0, 1.1 * s, 0)
	rockPiece(
		rock,
		Vector3.new(5, 3.6, 4.4) * s * jitter(rng, 0.12),
		center * randomTilt(rng, 0.3),
		color,
		Enum.Material.Rock
	)
	rockPiece(
		rock,
		Vector3.new(4.4, 3.2, 4.6) * s * jitter(rng, 0.12),
		center
			* CFrame.new(rng:NextNumber(-0.4, 0.4) * s, 0.2 * s, rng:NextNumber(-0.4, 0.4) * s)
			* randomTilt(rng, 0.5),
		shade(color, rng, 0.06),
		Enum.Material.Rock
	)
	local cap = rockPiece(
		rock,
		Vector3.new(3, 2, 2.8) * s * jitter(rng, 0.15),
		center
			* CFrame.new(rng:NextNumber(-0.6, 0.6) * s, 1.4 * s, rng:NextNumber(-0.6, 0.6) * s)
			* randomTilt(rng, 0.35),
		shade(color, rng, 0.08),
		Enum.Material.Rock
	)
	if rng:NextNumber() < 0.35 then
		addMoss(rock, cap, rng)
	end
	rockSkirt(rock, base, rng, s, color, 2, 2.4)
	return 5 * s
end

-- Laja: capas planas apiladas, cada una algo más pequeña y desplazada.
local function buildSlab(rock: Model, base: CFrame, rng: Random, s: number, color: Color3): number
	local sizes = { Vector3.new(6.5, 1.5, 5.5), Vector3.new(5, 1.3, 4.2), Vector3.new(3.4, 1.1, 3) }
	local heights = { 0.5, 1.7, 2.8 }
	local top: Part? = nil
	for i, size in sizes do
		top = rockPiece(
			rock,
			size * s * jitter(rng, 0.12),
			base
				* CFrame.new(rng:NextNumber(-0.6, 0.6) * s, heights[i] * s, rng:NextNumber(-0.6, 0.6) * s)
				* CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.08, 0.08)),
			shade(color, rng, 0.07),
			Enum.Material.Slate
		)
	end
	if top and rng:NextNumber() < 0.4 then
		addMoss(rock, top, rng)
	end
	rockSkirt(rock, base, rng, s, color, 1, 3)
	return 6 * s
end

-- Peñasco: tres o cuatro bloques altos que se abren hacia fuera desde el centro.
local function buildCrag(rock: Model, base: CFrame, rng: Random, s: number, color: Color3): number
	local sizes =
		{ Vector3.new(2.4, 5, 2.2), Vector3.new(2, 4, 2.4), Vector3.new(2.2, 3, 2), Vector3.new(1.8, 2.4, 1.8) }
	local start = rng:NextNumber(0, TAU)
	for i = 1, rng:NextInteger(3, 4) do
		local size = sizes[i] * s * jitter(rng, 0.12)
		rockPiece(
			rock,
			size,
			base
				* CFrame.Angles(0, start + i * TAU / 4 + rng:NextNumber(-0.4, 0.4), 0)
				* CFrame.new(0, size.Y / 2 - 0.8 * s, -(if i == 1 then 0 else 1.1 * s))
				* CFrame.Angles(-rng:NextNumber(0.1, 0.3), rng:NextNumber(0, TAU), rng:NextNumber(-0.1, 0.1)),
			shade(color, rng, 0.07),
			Enum.Material.Rock
		)
	end
	rockSkirt(rock, base, rng, s, color, 2, 2)
	return 4.5 * s
end

local ROCK_STYLES = { buildBoulder, buildBoulder, buildSlab, buildCrag }

-- Roca picable (tipo Rock) de forma irregular: canto rodado, laja o peñasco.
function NodeModels.buildRock(ground: Vector3, rng: Random, scale: number): Model
	local rock = Instance.new("Model")
	rock.Name = "Roca"
	-- Algo hundida: en las laderas no queda flotando por el lado de abajo.
	local base = CFrame.new(ground - Vector3.new(0, 0.3 * scale, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local footprint = pick(ROCK_STYLES, rng)(rock, base, rng, scale, pick(ROCK_COLORS, rng))
	NodeModels.makeHarvestable(rock, "Rock", ground, footprint)
	return rock
end

-- MATAS DE BANANO Y PLÁTANO --------------------------------------------------------------------

-- Una hoja grande en dos tramos: el primero sube desde el tallo y el segundo se dobla hacia abajo.
local function musaLeaf(plant: Model, from: CFrame, rng: Random, s: number, color: Color3)
	local rise = math.rad(rng:NextNumber(25, 45))
	local inner = from * CFrame.Angles(rise, 0, 0)
	decorative(newPart("Leaf", Vector3.new(2.4 * s, 0.15, 4 * s), inner * CFrame.new(0, 0, -2 * s), color, plant))
	local outer = inner * CFrame.new(0, 0, -4 * s) * CFrame.Angles(-rise - math.rad(rng:NextNumber(25, 40)), 0, 0)
	decorative(newPart("Leaf", Vector3.new(2.1 * s, 0.15, 3.6 * s), outer * CFrame.new(0, 0, -1.8 * s), color, plant))
end

-- Mata de banano o de plátano ("BananaPlant" o "PlantainPlant"): tallo, hojas grandes, una hoja
-- seca, a veces un hijuelo y el racimo con su bellota. Al cosechar solo desaparece el racimo.
function NodeModels.buildMusa(nodeType: string, ground: Vector3, rng: Random): Model
	local kind = MUSA_KINDS[nodeType]
	local plant = Instance.new("Model")
	plant.Name = kind.modelName
	local s = rng:NextNumber(0.85, 1.15)
	local base = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local height = kind.height * s
	local lean = CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))

	local middle = limb("Stem", base * CFrame.new(0, -0.5, 0) * lean, height * 0.55, 1.5 * s, kind.stem, plant, true)
	local top = limb("Stem", middle * lean, height * 0.45, 1.15 * s, shade(kind.stem, rng, 0.1), plant, true)

	local leafCount = 5
	local start = rng:NextNumber(0, TAU)
	for i = 0, leafCount - 1 do
		local yaw = start + i * TAU / leafCount + rng:NextNumber(-0.3, 0.3)
		musaLeaf(plant, top * CFrame.Angles(0, yaw, 0) * CFrame.new(0, -0.3 * s, 0), rng, s, shade(kind.leaf, rng, 0.1))
	end
	-- Hoja seca que cuelga pegada al tallo.
	decorative(
		newPart(
			"DryLeaf",
			Vector3.new(1.6 * s, 0.12, 3.5 * s),
			top
				* CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
				* CFrame.new(0, -0.6 * s, -0.8 * s)
				* CFrame.Angles(math.rad(-80), 0, 0)
				* CFrame.new(0, 0, -1.75 * s),
			Color3.fromRGB(140, 110, 60),
			plant
		)
	)
	-- Hijuelo: una mata pequeña que brota al pie.
	if rng:NextNumber() < 0.5 then
		local sucker = limb(
			"Stem",
			base * CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.new(0, -0.3, -1.4 * s),
			2.2 * s,
			0.6 * s,
			kind.stem,
			plant
		)
		for i = 0, 1 do
			musaLeaf(plant, sucker * CFrame.Angles(0, i * math.pi, 0), rng, s * 0.45, kind.leaf)
		end
	end

	-- Racimo: sale del tallo hacia fuera y cuelga, con manos de frutos que apuntan hacia arriba.
	local harvest = Instance.new("Folder")
	harvest.Name = NodeModels.HARVEST_FOLDER
	harvest.Parent = plant
	local stalkColor = Color3.fromRGB(110, 120, 60)
	local hang = limb(
		"Stalk",
		top * CFrame.Angles(0, rng:NextNumber(0, TAU), 0) * CFrame.Angles(math.rad(-120), 0, 0),
		2 * s,
		0.3 * s,
		stalkColor,
		harvest
	)
	local bunchTop = hang.Position
	local tierGap = kind.finger.Y * 0.8 * s
	local bunchLength = tierGap * (kind.tiers + 0.5)
	local rachis = CFrame.new(bunchTop) * CFrame.Angles(math.pi, 0, 0)
	limb("Stalk", rachis, bunchLength, 0.35 * s, stalkColor, harvest)
	for tier = 0, kind.tiers - 1 do
		for i = 0, kind.perTier - 1 do
			local around = CFrame.Angles(0, (i + tier * 0.5) * TAU / kind.perTier, 0)
			local position = bunchTop
				- Vector3.new(0, (tier + 0.6) * tierGap, 0)
				+ around:VectorToWorldSpace(Vector3.new(0, 0, -0.45 * s))
			newEllipsoid(
				"Fruit",
				kind.finger * s,
				CFrame.new(position) * around * CFrame.Angles(math.rad(-35), 0, 0),
				shade(kind.fruit, rng, 0.06),
				harvest
			)
		end
	end
	-- Bellota: la flor morada al final del racimo.
	newEllipsoid(
		"Bud",
		Vector3.new(0.7, 1.3, 0.7) * s,
		CFrame.new(bunchTop - Vector3.new(0, bunchLength + 0.5 * s, 0)),
		Color3.fromRGB(110, 30, 45),
		harvest
	)

	NodeModels.makeHarvestable(plant, nodeType, ground)
	return plant
end

-- Helecho de la selva: roseta de 4 a 6 frondas que suben y se arquean hacia abajo, cada una en
-- dos tramos (el de fuera más estrecho, como una hoja que se afina), y un cogollo enrollado en el
-- centro. Da fibra (Data/ResourceNodes, tipo Fern).
function NodeModels.buildFern(ground: Vector3, rng: Random): Model
	local fern = Instance.new("Model")
	fern.Name = "Helecho"
	local s = rng:NextNumber(0.7, 1.3)
	local color = shade(Color3.fromRGB(70, 150, 60), rng, 0.15)
	local base = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
	local count = rng:NextInteger(4, 6)
	for i = 0, count - 1 do
		local rise = math.rad(rng:NextNumber(45, 65))
		local length = rng:NextNumber(1.6, 2.2) * s
		-- Angles(+x) levanta el -Z del marco: la fronda sale hacia fuera y hacia arriba.
		local inner = base
			* CFrame.new(0, 0.1, 0)
			* CFrame.Angles(0, i * TAU / count + rng:NextNumber(-0.25, 0.25), 0)
			* CFrame.Angles(rise, 0, 0)
		leafy(newPart("Frond", Vector3.new(0.9 * s, 0.08, length), inner * CFrame.new(0, 0, -length / 2), color, fern))
		local outer = inner * CFrame.new(0, 0, -length) * CFrame.Angles(-rise - math.rad(rng:NextNumber(30, 50)), 0, 0)
		leafy(
			newPart(
				"Frond",
				Vector3.new(0.6 * s, 0.07, length * 0.9),
				outer * CFrame.new(0, 0, -length * 0.45),
				shade(color, rng, 0.08),
				fern
			)
		)
	end
	newBall(
		"Fiddlehead",
		0.35 * s,
		base * CFrame.new(0, 0.45 * s, 0),
		color:Lerp(Color3.fromRGB(160, 190, 80), 0.4),
		fern
	)
	NodeModels.makeHarvestable(fern, "Fern", ground)
	return fern
end

-- Arbusto: montículo de una mata grande y tres más pequeñas alrededor, con bayas rojas asomando
-- entre las hojas. La mata grande choca y lleva el aviso; el resto es de adorno.
local function buildBush(ground: Vector3, rng: Random, scale: number): Model
	local bush = Instance.new("Model")
	bush.Name = "Bush"
	local color = shade(Color3.fromRGB(70, 150, 55), rng, 0.1)
	local center = ground + Vector3.new(0, 1.4 * scale, 0)
	local main = newPart(
		"Bush",
		Vector3.new(3.6, 3, 3.6) * scale * jitter(rng, 0.1),
		CFrame.new(center) * randomTilt(rng, 0.45),
		color,
		bush
	)
	main.Material = Enum.Material.LeafyGrass
	local start = rng:NextNumber(0, TAU)
	for i = 1, 3 do
		local angle = start + i * TAU / 3 + rng:NextNumber(-0.4, 0.4)
		local offset = Vector3.new(math.cos(angle) * 1.5, rng:NextNumber(-0.4, 0.3), math.sin(angle) * 1.5) * scale
		leafy(
			newPart(
				"Leaves",
				Vector3.new(2.4, 2.1, 2.4) * scale * jitter(rng, 0.15),
				CFrame.new(center + offset) * randomTilt(rng, 0.6),
				shade(color, rng, 0.12),
				bush
			)
		)
	end
	local berry = Color3.fromRGB(200, 40, 50)
	for _ = 1, 5 do
		local angle = rng:NextNumber(0, TAU)
		local direction = Vector3.new(math.cos(angle), rng:NextNumber(0.1, 0.8), math.sin(angle)).Unit
		newBall("Berry", 0.35, CFrame.new(center + direction * 1.6 * scale), shade(berry, rng, 0.15), bush)
	end
	bush.PrimaryPart = main
	bush:SetAttribute(NodeModels.ATTRIBUTE, "Bush")
	return bush
end

-- Crea un punto de recolección del tipo dado ("Tree", "Rock", "Bush", "BananaPlant",
-- "PlantainPlant") apoyado en "ground". Con rng, cada uno sale con tamaño, giro y variedad distintos.
function NodeModels.build(nodeType: string, ground: Vector3, rng: Random?): Model
	local random = rng or Random.new()
	local scale = random:NextNumber(0.85, 1.25)
	if nodeType == "Tree" then
		return NodeModels.buildTree(ground, random, scale)
	elseif nodeType == "Rock" then
		return NodeModels.buildRock(ground, random, scale)
	elseif MUSA_KINDS[nodeType] then
		return NodeModels.buildMusa(nodeType, ground, random)
	end
	return buildBush(ground, random, scale)
end

return NodeModels
