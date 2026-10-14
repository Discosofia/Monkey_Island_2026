--!strict
-- Generador de la isla provisional (greybox, GDD §7). Se ejecuta UNA vez en Studio, en modo
-- edición (sin pulsar Play), desde la barra de comandos:
--
--   require(game.ServerStorage.Tools.MapBuilder).build()
--
-- Opciones: build({ seed = 7 }) cambia el reparto aleatorio; build({ islandRadius = 950 })
-- hace la isla más grande (vegetación, recursos y cueva escalan con el tamaño).
--
-- Por seguridad solo se ejecuta en el place de la Isla (Config.PlaceIds.Island). Para generar en
-- otro place (por ejemplo una copia de pruebas), usa build({ force = true }).
--
-- Crea el terreno (océano, playas, selva con colinas, Basecamp, río con manglar, montañas con
-- cueva y volcán) y las piezas: BasecampZone, puntos de aparición, empalizada con portones,
-- antorchas, hoguera, volcán activo, vegetación (cinco variedades de árbol, palmeras y helechos),
-- puntos de recolección, cultivos de banano y plátano, marcadores de las
-- guaridas de los jefes y límites invisibles. Todo lo que no es terreno queda en Workspace.Mapa.
--
-- ⚠️ Borra TODO el terreno, la carpeta Workspace.Mapa, la Baseplate y los SpawnLocation sueltos
-- antes de generar. Si ya retocaste el terreno a mano, esos cambios se pierden.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local NodeModels = require(ServerScriptService.ServerShared.NodeModels)

export type Options = {
	seed: number?,
	islandRadius: number?,
	force: boolean?, -- generar aunque el place abierto no sea la Isla de Config.PlaceIds
}

type Layout = {
	seed: number,
	radius: number,
	noiseOffset: Vector2,
	mountain: { center: Vector2, radius: number, peak: number },
	volcano: { center: Vector2, radius: number, peak: number, craterRadius: number, craterDepth: number },
	river: { Vector2 },
	cave: { entrance: Vector2, inward: Vector2, tunnelLength: number },
}

type Surface = {
	height: number,
	material: Enum.Material,
	inland: number, -- distancia hacia dentro desde la costa (negativa en el mar)
	riverDistance: number,
	caveDistance: number, -- distancia al eje de la cueva y su camino de entrada
	relief: number, -- altura que añaden montañas o volcán
}

local VOXEL = 4
local CHUNK = 128 -- studs por bloque de escritura (32 vóxeles)
local MIN_Y = -48
local MAX_Y = 208

local SEA_LEVEL = 2
local SEA_FLOOR = -24
local GROUND_LEVEL = 10
local BEACH_WIDTH = 90
local BASECAMP_RADIUS = 85
local RIVER_HALF_WIDTH = 12
local RIVER_BANK = 16
local RIVER_CARVE = RIVER_HALF_WIDTH + RIVER_BANK
local RIVER_BED = -4
local OCEAN_MARGIN = 200 -- mar que se genera más allá de la costa
local WALL_MARGIN = 100 -- distancia del muro invisible más allá de la costa más lejana

-- Cantidades para una isla de radio DEFAULT_RADIUS. Con otro radio se escalan: por área en la
-- selva (misma densidad) y por perímetro en la playa.
local DEFAULT_RADIUS = 650
local RESOURCE_COUNTS: { [string]: number } = { Tree = 140, Bush = 90, Rock = 60 }
local JUNGLE_TREE_COUNT = 380
local PALM_COUNT = 70
local FERN_COUNT = 380
-- Cultivos abandonados del santuario (GDD §13): grupos de matas en hileras.
local PLANTATIONS: { { nodeType: string, count: number } } = {
	{ nodeType = "BananaPlant", count = 12 },
	{ nodeType = "PlantainPlant", count = 9 },
}
local PLANT_SPACING = 6.5

local WOOD = Color3.fromRGB(110, 72, 40)
local DARK_WOOD = Color3.fromRGB(85, 55, 30)
local FIRE_LIGHT = Color3.fromRGB(255, 170, 90)
local LEAF_COLORS = { Color3.fromRGB(45, 120, 55), Color3.fromRGB(60, 140, 60), Color3.fromRGB(35, 100, 45) }

local MapBuilder = {}

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function distanceToSegment(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function makeLayout(seed: number, radius: number): Layout
	local rng = Random.new(seed)
	local mountainCenter = Vector2.new(-0.45, -0.4) * radius
	local mountainRadius = 0.38 * radius
	local caveInward = mountainCenter.Unit
	return {
		seed = seed,
		radius = radius,
		noiseOffset = Vector2.new(rng:NextNumber(-500, 500), rng:NextNumber(-500, 500)),
		-- Montañas y volcán al norte (Z negativa); río y manglar al sur.
		mountain = { center = mountainCenter, radius = mountainRadius, peak = 140 },
		volcano = {
			center = Vector2.new(0.42, -0.42) * radius,
			radius = 0.34 * radius,
			peak = 170,
			craterRadius = 28,
			craterDepth = 35,
		},
		-- Nace al pie de las montañas, rodea el Basecamp por el sur y desemboca al sureste.
		river = {
			Vector2.new(-0.36, -0.12) * radius,
			Vector2.new(-0.3, 0.14) * radius,
			Vector2.new(-0.1, 0.32) * radius,
			Vector2.new(0.18, 0.4) * radius,
			Vector2.new(0.45, 0.52) * radius,
			Vector2.new(0.68, 0.7) * radius,
			Vector2.new(0.9, 0.92) * radius,
		},
		-- La cueva entra en la falda de las montañas que mira al Basecamp.
		cave = {
			entrance = mountainCenter - caveInward * mountainRadius * 0.75,
			inward = caveInward,
			-- Más larga en islas grandes, para que la sala quede siempre bajo la montaña.
			tunnelLength = 140 * radius / DEFAULT_RADIUS,
		},
	}
end

local function surfaceAt(layout: Layout, x: number, z: number): Surface
	local p = Vector2.new(x, z)
	local r = p.Magnitude
	local o = layout.noiseOffset

	local riverDistance = math.huge
	for i = 1, #layout.river - 1 do
		riverDistance = math.min(riverDistance, distanceToSegment(p, layout.river[i], layout.river[i + 1]))
	end
	local cave = layout.cave
	local caveDistance =
		distanceToSegment(p, cave.entrance - cave.inward * 80, cave.entrance + cave.inward * (cave.tunnelLength + 20))

	-- Costa irregular: el radio varía ±10 % según el ángulo.
	local angle = math.atan2(z, x)
	local coast = layout.radius * (1 + 0.1 * math.noise(math.cos(angle) * 1.5 + o.X, math.sin(angle) * 1.5 + o.Y, 0.5))
	local inland = coast - r
	if inland < 0 then
		return {
			height = lerp(SEA_LEVEL - 2, SEA_FLOOR, smoothstep(0, 120, -inland)),
			material = Enum.Material.Sand,
			inland = inland,
			riverDistance = riverDistance,
			caveDistance = caveDistance,
			relief = 0,
		}
	end

	local mountain = layout.mountain
	local mountainFactor = 1 - smoothstep(0, mountain.radius, (p - mountain.center).Magnitude)
	local volcano = layout.volcano
	local volcanoDistance = (p - volcano.center).Magnitude

	-- Playa que sube hasta la selva. En la selva se alternan manchas de hierba y hojarasca.
	local height = lerp(SEA_LEVEL - 1, GROUND_LEVEL, smoothstep(0, BEACH_WIDTH, inland))
	local material = Enum.Material.Sand
	if inland >= BEACH_WIDTH * 0.7 then
		material = if math.noise(x / 90 + o.X, z / 90 + o.Y, 8.5) > 0.15
			then Enum.Material.Grass
			else Enum.Material.LeafyGrass
	end

	-- Colinas en tres escalas. Se suavizan cerca de la playa, el río, el Basecamp, la entrada de
	-- la cueva y bajo las montañas y el volcán (que ya tienen su propio relieve).
	local hillMask = smoothstep(BEACH_WIDTH * 0.5, BEACH_WIDTH * 2, inland)
		* smoothstep(RIVER_CARVE, RIVER_CARVE + 70, riverDistance)
		* smoothstep(BASECAMP_RADIUS + 20, BASECAMP_RADIUS + 90, r)
		* (1 - mountainFactor)
		* smoothstep(volcano.radius * 0.5, volcano.radius * 1.1, volcanoDistance)
		* smoothstep(20, 70, caveDistance)
	if hillMask > 0 then
		local rolling = 28 * smoothstep(-0.25, 0.45, math.noise(x / 260 + o.X, z / 260 + o.Y, 1.5))
		local medium = 9 * math.noise(x / 110 + o.X, z / 110 + o.Y, 3.5)
		local small = 3 * math.noise(x / 45 + o.X, z / 45 + o.Y, 4.5)
		-- Nunca por debajo de GROUND_LEVEL - 5: así no se forman charcos de agua tierra adentro.
		height += math.max(rolling + medium + small, -5) * hillMask
	end

	local relief = 0
	if mountainFactor > 0 then
		local ridges = (math.noise(x / 70 + o.X, z / 70 + o.Y, 2.5) + 1) / 2
		local lift = mountain.peak * mountainFactor ^ 1.6 * (0.7 + 0.6 * ridges)
		height += lift
		relief = lift
		if lift > 30 then
			material = Enum.Material.Rock
		elseif lift > 12 then
			material = Enum.Material.Ground
		end
	end

	if volcanoDistance < volcano.radius then
		local function cone(d: number): number
			return volcano.peak * (1 - d / volcano.radius) ^ 1.2
		end
		local lift
		if volcanoDistance < volcano.craterRadius then
			lift = cone(volcano.craterRadius) - volcano.craterDepth * (1 - (volcanoDistance / volcano.craterRadius) ^ 2)
			material = Enum.Material.CrackedLava
		else
			lift = cone(volcanoDistance)
			if lift > 15 then
				material = Enum.Material.Basalt
			end
		end
		height += lift
		relief = math.max(relief, lift)
	end

	-- Meseta plana del Basecamp.
	height = lerp(GROUND_LEVEL, height, smoothstep(BASECAMP_RADIUS, BASECAMP_RADIUS + 40, r))
	if r < BASECAMP_RADIUS + 6 then
		material = Enum.Material.Ground
	end

	-- Cauce del río (bajo el nivel del mar, así se llena de agua) y manglar cerca de la costa.
	local nearCoast = inland < layout.radius * 0.35
	if riverDistance < RIVER_CARVE then
		height = lerp(RIVER_BED, height, smoothstep(RIVER_HALF_WIDTH, RIVER_CARVE, riverDistance))
		material = if nearCoast then Enum.Material.Mud else Enum.Material.Ground
	elseif nearCoast and riverDistance < 60 and inland > BEACH_WIDTH * 0.7 then
		material = Enum.Material.Mud
	end

	return {
		height = height,
		material = material,
		inland = inland,
		riverDistance = riverDistance,
		caveDistance = caveDistance,
		relief = relief,
	}
end

local function writeTerrain(layout: Layout)
	local terrain = Workspace.Terrain
	local extent = math.ceil((layout.radius * 1.1 + OCEAN_MARGIN) / CHUNK) * CHUNK
	local columns = CHUNK // VOXEL
	local layers = (MAX_Y - MIN_Y) // VOXEL
	local total = (2 * extent // CHUNK) ^ 2
	local done = 0

	for chunkX = -extent, extent - CHUNK, CHUNK do
		for chunkZ = -extent, extent - CHUNK, CHUNK do
			local materials: { { { Enum.Material } } } = {}
			local occupancies: { { { number } } } = {}
			for ix = 1, columns do
				local materialsX: { { Enum.Material } } = {}
				local occupanciesX: { { number } } = {}
				for iy = 1, layers do
					materialsX[iy] = {}
					occupanciesX[iy] = {}
				end
				materials[ix] = materialsX
				occupancies[ix] = occupanciesX

				local x = chunkX + (ix - 0.5) * VOXEL
				for iz = 1, columns do
					local surface = surfaceAt(layout, x, chunkZ + (iz - 0.5) * VOXEL)
					for iy = 1, layers do
						local bottom = MIN_Y + (iy - 1) * VOXEL
						local solid = math.clamp((surface.height - bottom) / VOXEL, 0, 1)
						if solid > 0 then
							-- Bajo la superficie, roca.
							materialsX[iy][iz] = if surface.height - bottom > 12
								then Enum.Material.Rock
								else surface.material
							occupanciesX[iy][iz] = solid
						else
							local water = math.clamp((SEA_LEVEL - bottom) / VOXEL, 0, 1)
							materialsX[iy][iz] = if water > 0 then Enum.Material.Water else Enum.Material.Air
							occupanciesX[iy][iz] = water
						end
					end
				end
			end

			local region =
				Region3.new(Vector3.new(chunkX, MIN_Y, chunkZ), Vector3.new(chunkX + CHUNK, MAX_Y, chunkZ + CHUNK))
			terrain:WriteVoxels(region, VOXEL, materials, occupancies)
			done += 1
			if done % 25 == 0 then
				print(`[MapBuilder] Terreno: {math.floor(done / total * 100)} %`)
			end
			task.wait()
		end
	end

	-- Hierba animada sobre el material Grass (Roblox la desactiva sola en móviles de gama baja).
	pcall(function()
		terrain.Decoration = true
	end)
end

-- Devuelve el centro del suelo de la sala del fondo (guarida del Gorila Albino).
local function carveCave(layout: Layout): Vector3
	local terrain = Workspace.Terrain
	local cave = layout.cave
	local floorY = GROUND_LEVEL + 2

	for distance = 0, cave.tunnelLength, 6 do
		local point = cave.entrance + cave.inward * distance
		terrain:FillBall(Vector3.new(point.X, floorY + 7, point.Y), 9, Enum.Material.Air)
	end
	local chamber = cave.entrance + cave.inward * (cave.tunnelLength + 20)
	terrain:FillBall(Vector3.new(chamber.X, floorY + 22, chamber.Y), 28, Enum.Material.Air)
	return Vector3.new(chamber.X, floorY, chamber.Y)
end

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

-- Hojas y adornos: no chocan ni bloquean rayos, así no molestan al moverse ni a los sistemas.
local function decorative(part: Part): Part
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

-- Pieza invisible que solo sirve de referencia para el código.
local function newMarker(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = decorative(newPart(name, size, CFrame.new(position), Color3.new(1, 1, 1), parent))
	part.Transparency = 1
	return part
end

local function addLight(part: BasePart, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = FIRE_LIGHT
	light.Range = range
	light.Brightness = brightness
	light.Parent = part
end

local function addFire(part: BasePart, size: number, heat: number)
	local fire = Instance.new("Fire")
	fire.Size = size
	fire.Heat = heat
	fire.Parent = part
end

local function buildTorch(ground: Vector3, parent: Instance)
	local torch = Instance.new("Model")
	torch.Name = "Antorcha"
	torch.Parent = parent
	newPart("Pole", Vector3.new(0.8, 7, 0.8), CFrame.new(ground + Vector3.new(0, 3.5, 0)), DARK_WOOD, torch)
	local head = newPart(
		"Head",
		Vector3.new(1.4, 1.2, 1.4),
		CFrame.new(ground + Vector3.new(0, 7.4, 0)),
		Color3.fromRGB(60, 40, 25),
		torch
	)
	addFire(head, 3, 6)
	addLight(head, 24, 1.6)
end

-- Estaca de la empalizada: tronco cuadrado con punta. "tangent" es la dirección del muro.
local function buildStake(ground: Vector3, tangent: Vector3, height: number, color: Color3, parent: Instance)
	local frame = CFrame.fromMatrix(ground, tangent, Vector3.yAxis)
	newPart("Stake", Vector3.new(2.2, height, 2.2), frame * CFrame.new(0, height / 2 - 1, 0), color, parent)
	newPart(
		"Tip",
		Vector3.new(2.2, 1.56, 1.56),
		frame * CFrame.new(0, height - 1, 0) * CFrame.Angles(math.rad(45), 0, 0),
		color,
		parent
	)
end

local function isNearGate(angle: number, halfAngle: number): boolean
	for gate = 0, 3 do
		local diff = math.abs((angle - gate * math.pi / 2 + math.pi) % (2 * math.pi) - math.pi)
		if diff < halfAngle then
			return true
		end
	end
	return false
end

local function buildCampfire(parent: Instance)
	local campfire = Instance.new("Model")
	campfire.Name = "Hoguera"
	campfire.Parent = parent

	local center = Vector3.new(0, GROUND_LEVEL, 0)
	local firstLog: Part? = nil
	for i = 0, 3 do
		local log = newPart(
			"Log",
			Vector3.new(7, 1.3, 1.3),
			CFrame.new(center + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, i * math.pi / 4, 0),
			DARK_WOOD,
			campfire
		)
		firstLog = firstLog or log
	end
	-- Piedras del círculo, cada una con su tamaño y giro para que no parezcan cubos alineados.
	local stoneRng = Random.new(7)
	for i = 0, 9 do
		local angle = i * 2 * math.pi / 10
		local stone = newPart(
			"Stone",
			Vector3.new(stoneRng:NextNumber(1.4, 2), stoneRng:NextNumber(0.9, 1.3), stoneRng:NextNumber(1.3, 1.8)),
			CFrame.new(center + Vector3.new(math.cos(angle) * 5, 0.4, math.sin(angle) * 5))
				* CFrame.Angles(
					stoneRng:NextNumber(-0.3, 0.3),
					stoneRng:NextNumber(0, 2 * math.pi),
					stoneRng:NextNumber(-0.3, 0.3)
				),
			Color3.fromRGB(110, 110, 115):Lerp(Color3.new(0, 0, 0), stoneRng:NextNumber(0, 0.15)),
			campfire
		)
		stone.Material = Enum.Material.Rock
	end
	-- Bancos de tronco alrededor.
	for i = 0, 3 do
		local angle = i * math.pi / 2
		local position = center + Vector3.new(math.cos(angle) * 11, 0.8, math.sin(angle) * 11)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		newPart("Bench", Vector3.new(8, 1.6, 1.6), CFrame.fromMatrix(position, tangent, Vector3.yAxis), WOOD, campfire)
	end

	local mainLog = firstLog :: Part
	addFire(mainLog, 8, 10)
	addLight(mainLog, 50, 2.5)
	campfire.PrimaryPart = mainLog
	-- Estación de cocina (Data/Stations): CraftingService le pone el aviso "Cocinar".
	campfire:SetAttribute("CraftingStation", "Campfire")
end

local function buildBasecamp(layout: Layout, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Basecamp"
	folder.Parent = parent

	local zoneSize = BASECAMP_RADIUS * 2 + 8
	newMarker("BasecampZone", Vector3.new(zoneSize, 80, zoneSize), Vector3.new(0, GROUND_LEVEL + 30, 0), folder)

	-- Puntos de aparición entre los bancos de la hoguera.
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = Vector3.new(math.cos(angle) * 22, GROUND_LEVEL + 0.5, math.sin(angle) * 22)
		spawn.Parent = folder
	end

	buildCampfire(folder)

	-- Empalizada de estacas con 4 portones (norte, sur, este y oeste).
	local palisade = Instance.new("Model")
	palisade.Name = "Empalizada"
	palisade.Parent = folder
	local torches = Instance.new("Folder")
	torches.Name = "Antorchas"
	torches.Parent = folder

	local rng = Random.new(layout.seed + 1)
	local radius = BASECAMP_RADIUS - 4
	local gateHalfWidth = 10
	local stakeCount = math.floor(2 * math.pi * radius / 2.4)
	for i = 0, stakeCount - 1 do
		local angle = i * 2 * math.pi / stakeCount
		if not isNearGate(angle, gateHalfWidth / radius) then
			local ground = Vector3.new(math.cos(angle) * radius, GROUND_LEVEL, math.sin(angle) * radius)
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			buildStake(ground, tangent, rng:NextNumber(11, 14), if i % 3 == 0 then DARK_WOOD else WOOD, palisade)
		end
	end

	for gate = 0, 3 do
		local angle = gate * math.pi / 2
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local gateCenter = outward * radius + Vector3.new(0, GROUND_LEVEL, 0)
		for side = -1, 1, 2 do
			local post = gateCenter + tangent * side * (gateHalfWidth + 1)
			newPart(
				"GatePost",
				Vector3.new(3, 18, 3),
				CFrame.fromMatrix(post + Vector3.new(0, 8, 0), tangent, Vector3.yAxis),
				DARK_WOOD,
				palisade
			)
			buildTorch(post - outward * 4, torches)
		end
		newPart(
			"Lintel",
			Vector3.new(gateHalfWidth * 2 + 6, 2.5, 3),
			CFrame.fromMatrix(gateCenter + Vector3.new(0, 17, 0), tangent, Vector3.yAxis),
			DARK_WOOD,
			palisade
		)
	end
end

-- Muro invisible en el mar: nadie sale de la isla (GDD §7).
local function buildLimits(layout: Layout, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Limites"
	folder.Parent = parent

	local radius = layout.radius * 1.1 + WALL_MARGIN
	local segments = 72
	local segmentLength = 2 * math.pi * radius / segments + 2
	for i = 0, segments - 1 do
		local angle = i * 2 * math.pi / segments
		local position = Vector3.new(math.cos(angle) * radius, 150, math.sin(angle) * radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local wall = newPart(
			"Limite",
			Vector3.new(4, 400, segmentLength),
			CFrame.lookAt(position, position + tangent),
			Color3.new(1, 1, 1),
			folder
		)
		wall.Transparency = 1
		wall.CanTouch = false
		wall.CanQuery = false
	end
end

local function groundY(x: number, z: number, fallback: number, ignore: Instance): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	params.IgnoreWater = true
	local result = Workspace:Raycast(Vector3.new(x, MAX_Y + 20, z), Vector3.new(0, -(MAX_Y - MIN_Y + 40), 0), params)
	return if result then result.Position.Y else fallback
end

-- Coloca hasta "count" objetos en puntos al azar de la isla que cumplan "fits".
-- Con "clustered", se agrupan en bosques y dejan claros entre medias.
local function scatter(
	layout: Layout,
	map: Instance,
	rng: Random,
	count: number,
	clustered: boolean,
	fits: (Surface, number) -> boolean,
	place: (Vector3) -> ()
): number
	local o = layout.noiseOffset
	local placed = 0
	local attempts = 0
	while placed < count and attempts < count * 40 do
		attempts += 1
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = math.sqrt(rng:NextNumber()) * layout.radius * 1.1
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		local surface = surfaceAt(layout, x, z)
		local density = if clustered then smoothstep(-0.25, 0.25, math.noise(x / 160 + o.X, z / 160 + o.Y, 7.5)) else 1
		if fits(surface, distance) and rng:NextNumber() < 0.2 + 0.8 * density then
			place(Vector3.new(x, groundY(x, z, surface.height, map), z))
			placed += 1
		end
	end
	return placed
end

-- Selva: suelo firme, lejos de la playa, el río, la entrada de la cueva y las laderas empinadas.
local function isJungleSpot(surface: Surface, distanceFromCenter: number, clearance: number): boolean
	return distanceFromCenter > BASECAMP_RADIUS + clearance
		and surface.inland > BEACH_WIDTH * 0.8
		and surface.riverDistance > RIVER_CARVE + 4
		and surface.caveDistance > 25
		and surface.relief < 25
		and surface.material ~= Enum.Material.CrackedLava
end

local function byArea(count: number, layout: Layout): number
	return math.round(count * (layout.radius / DEFAULT_RADIUS) ^ 2)
end

local function placeResources(layout: Layout, map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Recursos"
	folder.Parent = map

	local rng = Random.new(layout.seed)
	for nodeType, count in RESOURCE_COUNTS do
		local placed = scatter(layout, map, rng, byArea(count, layout), false, function(surface, distance)
			if nodeType == "Rock" then
				-- Las rocas valen también en las laderas de montañas y volcán.
				return distance > BASECAMP_RADIUS + 45
					and surface.inland > BEACH_WIDTH * 0.8
					and surface.riverDistance > RIVER_CARVE + 6
					and surface.caveDistance > 25
					and surface.material ~= Enum.Material.CrackedLava
			end
			-- Fuera también de las esquinas de la BasecampZone (es cuadrada).
			return isJungleSpot(surface, distance, 45)
		end, function(ground)
			NodeModels.build(nodeType, ground, rng).Parent = folder
		end)
		print(`[MapBuilder] {placed} × {nodeType} (recolectables)`)
	end
end

local function buildFern(ground: Vector3, rng: Random, parent: Instance)
	local fern = Instance.new("Model")
	fern.Name = "Helecho"
	local scale = rng:NextNumber(0.7, 1.4)
	local base = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	for i = 0, 2 do
		local blade = decorative(
			newPart(
				"Blade",
				Vector3.new(0.2, 2.5, 3.5) * scale,
				base * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(0, 1.1 * scale, 0),
				color,
				fern
			)
		)
		fern.PrimaryPart = fern.PrimaryPart or blade
	end
	-- Da fibra (ver Data/ResourceNodes, tipo Fern).
	fern:SetAttribute(NodeModels.ATTRIBUTE, "Fern")
	fern.Parent = parent
end

local function placeVegetation(layout: Layout, map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Vegetacion"
	folder.Parent = map

	local rng = Random.new(layout.seed + 2)
	local trees = scatter(layout, map, rng, byArea(JUNGLE_TREE_COUNT, layout), true, function(surface, distance)
		return isJungleSpot(surface, distance, 15)
	end, function(ground)
		NodeModels.buildTree(ground, rng, rng:NextNumber(0.9, 1.6)).Parent = folder
	end)
	local palms = scatter(
		layout,
		map,
		rng,
		math.round(PALM_COUNT * layout.radius / DEFAULT_RADIUS),
		false,
		function(surface)
			return surface.inland > BEACH_WIDTH * 0.15
				and surface.inland < BEACH_WIDTH * 0.8
				and surface.riverDistance > RIVER_CARVE + 4
				and surface.relief < 15
		end,
		function(ground)
			NodeModels.buildPalm(ground, rng).Parent = folder
		end
	)
	local ferns = scatter(layout, map, rng, byArea(FERN_COUNT, layout), true, function(surface, distance)
		return isJungleSpot(surface, distance, 8)
	end, function(ground)
		buildFern(ground, rng, folder)
	end)
	print(`[MapBuilder] Vegetación: {trees} árboles, {palms} palmeras, {ferns} helechos`)
end

-- Cultivos de banano y plátano: cada uno es una cuadrícula de matas (2 hileras de 2 o 3) con
-- huecos al azar, como un cultivo abandonado. Se cosechan con el aviso (Data/ResourceNodes).
local function placePlantations(layout: Layout, map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Cultivos"
	folder.Parent = map

	local rng = Random.new(layout.seed + 3)
	local function fits(surface: Surface, distance: number): boolean
		return isJungleSpot(surface, distance, 30)
	end
	for _, plantation in PLANTATIONS do
		local plants = 0
		local groves = scatter(layout, map, rng, byArea(plantation.count, layout), false, fits, function(center)
			local frame = CFrame.new(center) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
			local columns = rng:NextInteger(2, 3)
			for row = 0, 1 do
				for column = 0, columns - 1 do
					local spot = frame
						* Vector3.new(
							(column - (columns - 1) / 2) * PLANT_SPACING + rng:NextNumber(-1.2, 1.2),
							0,
							(row - 0.5) * PLANT_SPACING + rng:NextNumber(-1.2, 1.2)
						)
					local surface = surfaceAt(layout, spot.X, spot.Z)
					local distance = Vector2.new(spot.X, spot.Z).Magnitude
					if rng:NextNumber() < 0.85 and fits(surface, distance) then
						local ground = Vector3.new(spot.X, groundY(spot.X, spot.Z, surface.height, map), spot.Z)
						NodeModels.buildMusa(plantation.nodeType, ground, rng).Parent = folder
						plants += 1
					end
				end
			end
		end)
		print(`[MapBuilder] {groves} cultivos de {plantation.nodeType} ({plants} matas)`)
	end
end

-- Volcán activo: lago de lava brillante, llamas, luz, humo y chispas.
-- Fase 5: la lava hará daño y habrá erupciones (GDD §7).
local function buildVolcano(layout: Layout, map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Volcan"
	folder.Parent = map

	local center = layout.volcano.center
	local floorY = groundY(center.X, center.Y, surfaceAt(layout, center.X, center.Y).height, map)
	-- Disco de lava unos studs por encima del fondo del cráter: solo asoma el centro del cuenco.
	local lava = decorative(
		newPart(
			"Lava",
			Vector3.new(1, 44, 44),
			CFrame.new(center.X, floorY + 8, center.Y) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(255, 95, 20),
			folder
		)
	)
	lava.Shape = Enum.PartType.Cylinder
	lava.Material = Enum.Material.Neon

	local vent = newMarker("Respiradero", Vector3.new(12, 1, 12), Vector3.new(center.X, floorY + 9, center.Y), folder)
	addFire(vent, 25, 20)
	addLight(vent, 60, 5)

	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(80, 80, 80)
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 12
	smoke.Size = 60
	smoke.Parent = vent

	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 180, 60), Color3.fromRGB(255, 60, 20))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.8, 0)
	embers.Lifetime = NumberRange.new(2, 4)
	embers.Rate = 25
	embers.Speed = NumberRange.new(20, 40)
	embers.SpreadAngle = Vector2.new(30, 30)
	embers.Acceleration = Vector3.new(0, -20, 0)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Parent = vent
end

-- Puntos de referencia para las guaridas de los jefes (Fase 5, GDD §8.2).
local function placeBossMarkers(layout: Layout, caveFloor: Vector3, map: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "GuaridasJefes"
	folder.Parent = map

	local function onGround(point: Vector2): Vector3
		local surface = surfaceAt(layout, point.X, point.Y)
		return Vector3.new(point.X, groundY(point.X, point.Y, surface.height, map) + 3, point.Y)
	end

	local river = layout.river
	local riverDirection = (river[6] - river[4]).Unit
	local riverBank = river[5] + Vector2.new(-riverDirection.Y, riverDirection.X) * 45

	local lairs = {
		{ biome = "Rios", boss = "OrangutanDelManglar", position = onGround(riverBank) },
		{ biome = "Montanas", boss = "ChimpanceCaudillo", position = onGround(layout.mountain.center) },
		{ biome = "Cuevas", boss = "GorilaAlbino", position = caveFloor + Vector3.new(0, 3, 0) },
		{ biome = "Volcan", boss = "GorilaDeCeniza", position = onGround(layout.volcano.center) },
	}
	for _, lair in lairs do
		local marker = newMarker(`Guarida_{lair.biome}`, Vector3.new(6, 6, 6), lair.position, folder)
		marker:SetAttribute("Bioma", lair.biome)
		marker:SetAttribute("Jefe", lair.boss)
	end
end

local function clearPrevious()
	Workspace.Terrain:Clear()
	local previous = Workspace:FindFirstChild("Mapa")
	if previous then
		previous:Destroy()
	end
	-- Restos de la plantilla Baseplate de Studio.
	for _, child in Workspace:GetChildren() do
		if (child.Name == "Baseplate" and child:IsA("BasePart")) or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

function MapBuilder.build(options: Options?)
	if game.PlaceId ~= Config.PlaceIds.Island and not (options and options.force) then
		warn(
			`[MapBuilder] No se generó nada: el place abierto ({game.PlaceId}) no es la Isla del juego `
				.. `({Config.PlaceIds.Island}). Abre la Isla desde el Gestor de recursos de la experiencia `
				.. "Primal Banana Island (ver docs/MAPA.md). Si de verdad quieres generar aquí, usa build({ force = true })."
		)
		return
	end

	local seed = if options and options.seed then options.seed else 2026
	local radius = if options and options.islandRadius then options.islandRadius else DEFAULT_RADIUS
	local layout = makeLayout(seed, radius)
	local startedAt = os.clock()
	print(`[MapBuilder] Generando la isla (semilla {seed}, radio {radius})...`)

	clearPrevious()
	writeTerrain(layout)
	local caveFloor = carveCave(layout)

	local map = Instance.new("Folder")
	map.Name = "Mapa"
	map.Parent = Workspace
	buildBasecamp(layout, map)
	buildLimits(layout, map)
	buildVolcano(layout, map)
	placeResources(layout, map)
	placePlantations(layout, map)
	placeVegetation(layout, map)
	placeBossMarkers(layout, caveFloor, map)

	print(
		`[MapBuilder] ¡Isla lista en {math.floor(os.clock() - startedAt)} s! Pulsa Play para probarla y luego publica el place.`
	)
end

return MapBuilder
