--!strict
-- Generador de la isla provisional (greybox, GDD §7). Se ejecuta UNA vez en Studio, en modo
-- edición (sin pulsar Play), desde la barra de comandos:
--
--   require(game.ServerStorage.Tools.MapBuilder).build()
--
-- Opciones: build({ seed = 7 }) cambia el reparto aleatorio; build({ islandRadius = 800 })
-- hace la isla más grande.
--
-- Crea el terreno (océano, playas, selva, Basecamp, río con manglar, montañas con cueva y
-- volcán) y las piezas que usa el código: BasecampZone, puntos de aparición, empalizada,
-- hoguera, puntos de recolección, marcadores de las guaridas de los jefes y límites invisibles.
-- Todo lo que no es terreno queda en Workspace.Mapa.
--
-- ⚠️ Borra TODO el terreno, la carpeta Workspace.Mapa, la Baseplate y los SpawnLocation sueltos
-- antes de generar. Si ya retocaste el terreno a mano, esos cambios se pierden.

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local NodeModels = require(ServerScriptService.ServerShared.NodeModels)

export type Options = {
	seed: number?,
	islandRadius: number?,
}

type Layout = {
	seed: number,
	radius: number,
	noiseOffset: Vector2,
	mountain: { center: Vector2, radius: number, peak: number },
	volcano: { center: Vector2, radius: number, peak: number, craterRadius: number, craterDepth: number },
	river: { Vector2 },
}

type Surface = {
	height: number,
	material: Enum.Material,
	inland: number, -- distancia hacia dentro desde la costa (negativa en el mar)
	riverDistance: number,
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
local BASECAMP_RADIUS = 60
local RIVER_HALF_WIDTH = 12
local RIVER_BANK = 16
local RIVER_BED = -4
local OCEAN_MARGIN = 200 -- mar que se genera más allá de la costa
local WALL_MARGIN = 100 -- distancia del muro invisible más allá de la costa más lejana

local RESOURCE_COUNTS: { [string]: number } = { Tree = 140, Bush = 90, Rock = 60 }

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
	return {
		seed = seed,
		radius = radius,
		noiseOffset = Vector2.new(rng:NextNumber(-500, 500), rng:NextNumber(-500, 500)),
		-- Montañas y volcán al norte (Z negativa); río y manglar al sur.
		mountain = { center = Vector2.new(-0.45, -0.4) * radius, radius = 0.38 * radius, peak = 140 },
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
			Vector2.new(-0.22, 0.08) * radius,
			Vector2.new(-0.02, 0.24) * radius,
			Vector2.new(0.22, 0.36) * radius,
			Vector2.new(0.45, 0.52) * radius,
			Vector2.new(0.68, 0.7) * radius,
			Vector2.new(0.9, 0.92) * radius,
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
			relief = 0,
		}
	end

	-- Playa que sube hasta la selva, con colinas suaves tierra adentro.
	local height = lerp(SEA_LEVEL - 1, GROUND_LEVEL, smoothstep(0, BEACH_WIDTH, inland))
	height += 6 * math.noise(x / 120 + o.X, z / 120 + o.Y, 1.5) * smoothstep(
		BEACH_WIDTH * 0.5,
		BEACH_WIDTH * 1.5,
		inland
	)
	local material = if inland < BEACH_WIDTH * 0.7 then Enum.Material.Sand else Enum.Material.LeafyGrass
	local relief = 0

	local mountain = layout.mountain
	local mountainFactor = 1 - smoothstep(0, mountain.radius, (p - mountain.center).Magnitude)
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

	local volcano = layout.volcano
	local volcanoDistance = (p - volcano.center).Magnitude
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
	if riverDistance < RIVER_HALF_WIDTH + RIVER_BANK then
		height = lerp(RIVER_BED, height, smoothstep(RIVER_HALF_WIDTH, RIVER_HALF_WIDTH + RIVER_BANK, riverDistance))
		material = if nearCoast then Enum.Material.Mud else Enum.Material.Ground
	elseif nearCoast and riverDistance < 60 and inland > BEACH_WIDTH * 0.7 then
		material = Enum.Material.Mud
	end

	return {
		height = height,
		material = material,
		inland = inland,
		riverDistance = riverDistance,
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
end

-- Cueva excavada en la falda de las montañas que mira al Basecamp.
-- Devuelve el centro del suelo de la sala del fondo (guarida del Gorila Albino).
local function carveCave(layout: Layout): Vector3
	local terrain = Workspace.Terrain
	local mountain = layout.mountain
	local inward = mountain.center.Unit
	local entrance = mountain.center - inward * mountain.radius * 0.75
	local floorY = GROUND_LEVEL + 2
	local tunnelLength = 140

	for distance = 0, tunnelLength, 6 do
		local point = entrance + inward * distance
		terrain:FillBall(Vector3.new(point.X, floorY + 7, point.Y), 9, Enum.Material.Air)
	end
	local chamber = entrance + inward * (tunnelLength + 20)
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

-- Pieza invisible que solo sirve de referencia para el código.
local function newMarker(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = newPart(name, size, CFrame.new(position), Color3.new(1, 1, 1), parent)
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

local function buildBasecamp(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Basecamp"
	folder.Parent = parent

	local zoneSize = BASECAMP_RADIUS * 2 + 8
	newMarker("BasecampZone", Vector3.new(zoneSize, 80, zoneSize), Vector3.new(0, GROUND_LEVEL + 30, 0), folder)

	-- Puntos de aparición alrededor de la hoguera.
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = Vector3.new(math.cos(angle) * 16, GROUND_LEVEL + 0.5, math.sin(angle) * 16)
		spawn.Parent = folder
	end

	-- Hoguera central: troncos, piedras, fuego y luz para la noche.
	local fire = Instance.new("Model")
	fire.Name = "Hoguera"
	fire.Parent = folder
	local wood = Color3.fromRGB(100, 65, 35)
	local log1 = newPart("Log", Vector3.new(6, 1.2, 1.2), CFrame.new(0, GROUND_LEVEL + 0.6, 0), wood, fire)
	newPart(
		"Log",
		Vector3.new(6, 1.2, 1.2),
		CFrame.new(0, GROUND_LEVEL + 0.6, 0) * CFrame.Angles(0, math.pi / 2, 0),
		wood,
		fire
	)
	for i = 0, 7 do
		local angle = i * math.pi / 4
		newPart(
			"Stone",
			Vector3.new(1.4, 1, 1.4),
			CFrame.new(math.cos(angle) * 4, GROUND_LEVEL + 0.5, math.sin(angle) * 4),
			Color3.fromRGB(110, 110, 115),
			fire
		)
	end
	local flames = Instance.new("Fire")
	flames.Size = 6
	flames.Heat = 8
	flames.Parent = log1
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 45
	light.Brightness = 2
	light.Parent = log1
	fire.PrimaryPart = log1

	-- Empalizada con 4 entradas (norte, sur, este y oeste).
	local palisade = Instance.new("Model")
	palisade.Name = "Empalizada"
	palisade.Parent = folder
	local radius = BASECAMP_RADIUS - 4
	local segments = 56
	local segmentLength = 2 * math.pi * radius / segments + 0.4
	local gateHalfAngle = 10 / radius
	for i = 0, segments - 1 do
		local angle = (i + 0.5) * 2 * math.pi / segments
		local nearGate = false
		for gate = 0, 3 do
			local diff = math.abs((angle - gate * math.pi / 2 + math.pi) % (2 * math.pi) - math.pi)
			if diff < gateHalfAngle then
				nearGate = true
			end
		end
		if not nearGate then
			local position = Vector3.new(math.cos(angle) * radius, GROUND_LEVEL + 4, math.sin(angle) * radius)
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			newPart(
				"Wall",
				Vector3.new(1.6, 10, segmentLength),
				CFrame.lookAt(position, position + tangent),
				Color3.fromRGB(125, 85, 50),
				palisade
			)
		end
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

local function isGoodSpot(nodeType: string, surface: Surface, distanceFromCenter: number): boolean
	if distanceFromCenter < BASECAMP_RADIUS + 30 then
		return false -- dentro del Basecamp no hay recursos (GDD §10)
	end
	if surface.inland < BEACH_WIDTH * 0.8 then
		return false -- ni en la playa ni en el mar
	end
	if surface.riverDistance < RIVER_HALF_WIDTH + RIVER_BANK + 6 then
		return false
	end
	if surface.material == Enum.Material.CrackedLava then
		return false
	end
	-- Las rocas valen en cualquier sitio; árboles y arbustos no en laderas empinadas.
	return nodeType == "Rock" or surface.relief < 25
end

local function placeResources(layout: Layout, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Recursos"
	folder.Parent = parent

	local rng = Random.new(layout.seed)
	for nodeType, count in RESOURCE_COUNTS do
		local placed = 0
		local attempts = 0
		while placed < count and attempts < count * 40 do
			attempts += 1
			local angle = rng:NextNumber(0, 2 * math.pi)
			local distance = math.sqrt(rng:NextNumber()) * layout.radius
			local x = math.cos(angle) * distance
			local z = math.sin(angle) * distance
			local surface = surfaceAt(layout, x, z)
			if isGoodSpot(nodeType, surface, distance) then
				local ground = Vector3.new(x, groundY(x, z, surface.height, parent), z)
				NodeModels.build(nodeType, ground, rng).Parent = folder
				placed += 1
			end
		end
		print(`[MapBuilder] {placed} × {nodeType}`)
	end
end

-- Puntos de referencia para las guaridas de los jefes (Fase 5, GDD §8.2).
local function placeBossMarkers(layout: Layout, caveFloor: Vector3, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "GuaridasJefes"
	folder.Parent = parent

	local function onGround(point: Vector2): Vector3
		local surface = surfaceAt(layout, point.X, point.Y)
		return Vector3.new(point.X, groundY(point.X, point.Y, surface.height, parent) + 3, point.Y)
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
	local seed = if options and options.seed then options.seed else 2026
	local radius = if options and options.islandRadius then options.islandRadius else 650
	local layout = makeLayout(seed, radius)
	local startedAt = os.clock()
	print(`[MapBuilder] Generando la isla (semilla {seed}, radio {radius})... tarda alrededor de un minuto.`)

	clearPrevious()
	writeTerrain(layout)
	local caveFloor = carveCave(layout)

	local map = Instance.new("Folder")
	map.Name = "Mapa"
	map.Parent = Workspace
	buildBasecamp(map)
	buildLimits(layout, map)
	placeResources(layout, map)
	placeBossMarkers(layout, caveFloor, map)

	print(
		`[MapBuilder] ¡Isla lista en {math.floor(os.clock() - startedAt)} s! Pulsa Play para probarla y luego publica el place.`
	)
end

return MapBuilder
