--!strict
-- Escenario del Lobby: el naufragio del carguero «Esperanza» (GDD §13, lore). Los jugadores son
-- náufragos: el barco ha encallado en un banco de arena y, al norte, se ve la isla con su volcán
-- humeante.
--
-- Lo construye solo el servidor del Lobby al arrancar si no existe Workspace.Naufragio
-- (LobbyWorldService). Para dejarlo fijo en el place y retocarlo a mano, ejecútalo una vez en Studio,
-- en modo edición (sin pulsar Play), desde la barra de comandos:
--
--   require(game.ServerScriptService.Server.World.LobbyBuilder).build()
--
-- Por seguridad, desde la barra de comandos solo se ejecuta en el place del Lobby
-- (Config.PlaceIds.Lobby). Para otro place usa build({ force = true }).
--
-- Todo se ordena alrededor de la plaza (PLAZA): un óvalo de arena libre donde se juntan los
-- jugadores y prueban sus habilidades contra los muñecos de práctica (LobbyDummyService, en
-- practiceSpots). Dentro quedan la hoguera, el nido y la llegada; los carteles le hacen de borde.
--
-- Crea: mar y banco de arena (terreno); el carguero encallado arriba a la izquierda, con boquete y
-- bodega, castillo con puente de mando, chimenea y radar, contenedores en cubierta y grúa; la
-- pasarela de subida; la hoguera de la plaza; el campamento abajo a la izquierda con tienda de lona,
-- contenedores varados y cajas de la carga; el ancla con cadena; cuatro carteles en el borde de la
-- plaza (de izquierda a derecha: el de las mascotas tapando el nombre de la proa, la bitácora del
-- capitán, los roles con el aviso "RolesPrompt", el ranking con "RankingPrompt" y el de la Isla de
-- dunas con "ArenaPrompt"); el nido de huevos delante del cartel de las mascotas (aviso "NidoPrompt",
-- etiqueta Config.Lobby.NestTag); las estaciones con interacción llevan los atributos "StationId" y
-- "StationIcon" (los marcadores de cada cliente); la lancha de rescate para zarpar a la Isla de monos (aviso "ZarparPrompt");
-- el embarcadero con el velero que lleva a la Isla de dunas (aviso "ZarparDunasPrompt");
-- humo saliendo del boquete del casco y luces averiadas (etiqueta Config.Lobby.BrokenLightTag, las
-- hace parpadear ShipLightsController en cada cliente);
-- palmeras; la isla con el volcán en el horizonte; las otras cuatro islas del archipiélago, aún
-- cerradas (Isla Calavera, Ciudad Perdida, Isla de las Dunas y Picos de la Niebla, GDD §7.1); muros
-- invisibles, el punto de aparición y la luz de atardecer.
--
-- ⚠️ Borra la carpeta Workspace.Naufragio, la Baseplate, los SpawnLocation sueltos y el terreno de la
-- zona antes de construir.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BuildModels = require(ReplicatedStorage.Shared.BuildModels)
local Config = require(ReplicatedStorage.Shared.Config)

export type Options = { force: boolean? }

local FOLDER_NAME = "Naufragio"
-- Sube este número al cambiar el escenario: los Lobbies con una versión anterior guardada se
-- reconstruyen solos al arrancar (LobbyWorldService).
local VERSION = 12
local SEED = 1717

-- Banco de arena: elipse con centro y semiejes; la orilla queda hacia el 70 % del radio.
local BAR_CENTER = Vector2.new(-10, -5)
local BAR_RADII = Vector2.new(110, 70)
local BAR_TOP = 4
local SEA_LEVEL = 0
local SEA_FLOOR = -20
local TERRAIN_STEP = 4
local BOUNDARY_RADIUS = 165

-- Isla del horizonte (la de la partida) y su volcán.
local ISLAND_CENTER = Vector3.new(520, 0, -700)
local VOLCANO_PEAK = 230

-- Las otras islas del archipiélago, aún cerradas: solo se ven desde el Lobby, cada una a una
-- distancia distinta (de la más cercana a la más lejana: Calavera, Ciudad Perdida, Dunas, Picos).
local SKULL_CENTER = Vector3.new(-330, 0, 400)
local RUINS_CENTER = Vector3.new(-430, 0, -420)
local DUNES_CENTER = Vector3.new(820, 0, 470)
local DUNES_RADIUS = 270
local PEAKS_CENTER = Vector3.new(-150, 0, -1300)

-- Plaza: el círculo de arena libre (centro; radio de unos 41 × 39) donde se juntan los jugadores.
-- Dentro solo quedan la hoguera, el nido, los muñecos de práctica y la llegada. Los carteles están
-- sobre su borde (de arriba a la izquierda a la derecha: mascotas, bitácora, roles, ranking y arena)
-- y miran a su centro; el barco, el campamento y los botes quedan fuera.
local PLAZA = Vector2.new(10, -3)
-- Cartel de las mascotas: a la izquierda de la bitácora, en la línea que va del centro de la plaza al
-- nombre de la proa ("ESPERANZA"), para taparlo desde la plaza.
local PETS_BOARD_AT = Vector2.new(-16.4, -30.4)
local PETS_BOARD_HEIGHT = 9.5
local LOG_BOARD_AT = Vector2.new(1.7, -41.2)
local ROLE_BOARD_AT = Vector2.new(39.5, -30.1)
local RANKING_BOARD_AT = Vector2.new(50.4, -9.4)
-- Cartel de la arena de Dunas: debajo del ranking, junto al embarcadero.
local ARENA_BOARD_AT = Vector2.new(48.6, 13.2)
-- Cartelito de la lancha: en la orilla, entre la bitácora y el cartel de roles.
local LIFEBOAT_SIGN_AT = Vector2.new(26, -43)
-- Embarcadero hacia la Isla de dunas: sale de la playa al pie del cartel de la arena, hacia el
-- sureste (donde se ve la Isla de las Dunas), con el velero amarrado al final.
local DUNES_PIER_FROM = Vector2.new(40, 27)
local DUNES_PIER_LENGTH = 18
local DUNES_PIER_DECK = 2.4
-- Nido de huevos: en la plaza, delante del cartel de las mascotas (que enseña su huevo). Es el Nido
-- de la Isla (BuildModels) en grande, sobre un montículo de arena.
local NEST_AT = Vector2.new(-10.1, -23.9)
local NEST_SCALE = 1.4
local NEST_MOUND_HEIGHT = 1.6
local SPAWN_AT = Vector2.new(4, 34)
local CAMPFIRE_AT = Vector2.new(6, 10)
-- Muñecos de práctica (LobbyDummyService): en el borde oeste de la plaza, mirando a su centro.
local PRACTICE_SPOTS = { Vector2.new(-27, -12), Vector2.new(-29, -2), Vector2.new(-27, 8) }

-- Barco: carguero moderno, eslora a lo largo de X local, de -38 (popa) a 38 (proa); +Z es estribor.
local SHIP_HALF_LENGTH = 38
local SHIP_BEAM = 22
local HULL_ROWS = 6
local ROW_HEIGHT = 2.2
local HULL_SEGMENTS = 16
-- Encallado arriba a la izquierda, fuera de la plaza, con la proa hacia el noreste: la quilla un par
-- de studs bajo la arena, escorado hacia la playa (+Z) y con la proa algo levantada.
local SHIP_FRAME = CFrame.new(-44, 2.2, -40)
	* CFrame.Angles(0, math.rad(17), 0)
	* CFrame.Angles(math.rad(11), 0, math.rad(4))

local HULL_NAVY = Color3.fromRGB(30, 50, 85)
local HULL_RED = Color3.fromRGB(150, 40, 32)
local BOOT_TOP = Color3.fromRGB(35, 35, 40)
local STEEL_DECK = Color3.fromRGB(95, 105, 98)
local WHITE_PAINT = Color3.fromRGB(232, 232, 226)
local RAIL = Color3.fromRGB(235, 235, 230)
local RUST = Color3.fromRGB(130, 70, 40)
local GLASS = Color3.fromRGB(45, 65, 85)
local CRANE_YELLOW = Color3.fromRGB(235, 175, 35)
local RESCUE_ORANGE = Color3.fromRGB(240, 110, 30)
local TARP = Color3.fromRGB(45, 95, 170)
local ALUMINIUM = Color3.fromRGB(170, 175, 180)
local CONTAINER_COLORS = {
	Color3.fromRGB(200, 80, 40),
	Color3.fromRGB(40, 90, 160),
	Color3.fromRGB(50, 120, 70),
	Color3.fromRGB(170, 40, 40),
	Color3.fromRGB(220, 150, 40),
}
local DARK_WOOD = Color3.fromRGB(62, 40, 24)
local IRON = Color3.fromRGB(55, 55, 60)
local FIRE_LIGHT = Color3.fromRGB(255, 170, 90)
local LANTERN_LIGHT = Color3.fromRGB(255, 200, 120)
local LEAF = Color3.fromRGB(70, 150, 60)
local PLANK = Color3.fromRGB(205, 175, 125)
local INK = Color3.fromRGB(45, 30, 15)
local BOARD_CARD = Color3.fromRGB(45, 38, 30)
-- Oro, plata y bronce para los tres primeros del ranking.
local RANK_COLORS = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(215, 220, 230), Color3.fromRGB(225, 150, 90) }

local LOG_TEXT = "La tormenta empujó al carguero «Esperanza» contra el arrecife. El casco está abierto y los "
	.. "motores, muertos.\n\n"
	.. "Al norte se ve una isla con un volcán que humea día y noche. De allí llegan aullidos.\n\n"
	.. "No es la única: alrededor hay más islas. Una ciudad en ruinas tragada por la selva, un "
	.. "desierto de dunas, una roca con forma de calavera y unos picos entre la niebla. Con esta "
	.. "lancha solo llegamos a la del volcán.\n\n"
	.. "En la bodega llevábamos contenedores con un sello que nadie supo explicar: PROYECTO PRIMAL.\n\n"
	.. "Nuestra radio no funciona. Quien quiera salir de aquí, que tome la lancha y vaya a la isla: "
	.. "dicen que en el viejo laboratorio aún queda una radio."

local LobbyBuilder = {}

local rng = Random.new(SEED)

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Altura de la arena en (x, z).
local function sandHeight(x: number, z: number): number
	local offset = (Vector2.new(x, z) - BAR_CENTER) / BAR_RADII
	local slope = smoothstep(0.55, 1.15, offset.Magnitude)
	local dunes = 1.2 * math.sin(x / 13) * math.cos(z / 11) * (1 - slope)
	return BAR_TOP - (BAR_TOP - SEA_FLOOR + 2) * slope + dunes
end

local function groundAt(x: number, z: number): Vector3
	return Vector3.new(x, math.max(sandHeight(x, z), SEA_LEVEL - 1), z)
end

local function newPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Pieza de adorno: no choca ni estorba a los rayos ni a las cámaras.
local function decor(part: BasePart): BasePart
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

local function cylinder(
	name: string,
	diameter: number,
	from: Vector3,
	to: Vector3,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local direction = to - from
	-- Con un tramo vertical, lookAt necesita otro vector "arriba".
	local up = if math.abs(direction.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local part = newPart(
		name,
		Vector3.new(direction.Magnitude, diameter, diameter),
		CFrame.lookAt((from + to) / 2, to, up) * CFrame.Angles(0, math.pi / 2, 0),
		color,
		material,
		parent
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function ball(
	name: string,
	diameter: number,
	position: Vector3,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local part = newPart(name, Vector3.one * diameter, CFrame.new(position), color, material, parent)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Luz del barco que parpadea como averiada (ShipLightsController).
local function broken(part: BasePart): BasePart
	CollectionService:AddTag(part, Config.Lobby.BrokenLightTag)
	return part
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local point = Instance.new("PointLight")
	point.Color = color
	point.Range = range
	point.Brightness = brightness
	point.Shadows = true
	point.Parent = parent
end

-- Variación leve de un color para que las chapas no se vean todas iguales.
local function tone(color: Color3): Color3
	return color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.12))
end

-- Texto en una cara de una pieza.
local function sign(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3, font: Enum.Font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = textColor
	label.Font = font
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.Parent = label
end

---------------------------------------------------------------------------------------------------
-- Terreno

local function buildTerrain()
	local terrain = Workspace.Terrain
	local bottom = SEA_FLOOR - 8
	-- Mar: de la orilla hasta más allá de las islas del horizonte, por bloques.
	local seaMin = Vector2.new(-1100, -1800)
	local seaMax = Vector2.new(1300, 1000)
	local chunk = 400
	for x = seaMin.X, seaMax.X - 1, chunk do
		for z = seaMin.Y, seaMax.Y - 1, chunk do
			local center = Vector3.new(x + chunk / 2, 0, z + chunk / 2)
			terrain:FillBlock(
				CFrame.new(center.X, (bottom + SEA_FLOOR) / 2, center.Z),
				Vector3.new(chunk, SEA_FLOOR - bottom, chunk),
				Enum.Material.Sand
			)
			terrain:FillBlock(
				CFrame.new(center.X, (SEA_FLOOR + SEA_LEVEL) / 2, center.Z),
				Vector3.new(chunk, SEA_LEVEL - SEA_FLOOR, chunk),
				Enum.Material.Water
			)
		end
	end
	-- Banco de arena por columnas.
	for x = -150, 130, TERRAIN_STEP do
		for z = -110, 100, TERRAIN_STEP do
			local top = sandHeight(x, z)
			if top > SEA_FLOOR then
				local height = top - SEA_FLOOR
				terrain:FillBlock(
					CFrame.new(x, SEA_FLOOR + height / 2, z),
					Vector3.new(TERRAIN_STEP, height, TERRAIN_STEP),
					Enum.Material.Sand
				)
			end
		end
	end
	-- Arrecife: rocas que asoman alrededor del barco.
	for _, spot in
		{
			Vector3.new(-94, 0, -28),
			Vector3.new(-72, -1, -60),
			Vector3.new(-50, -2, -68),
			Vector3.new(4, -1, -58),
			Vector3.new(-90, -1, -15),
		}
	do
		terrain:FillBall(spot, rng:NextNumber(5, 8), Enum.Material.Basalt)
	end
	-- Roca detrás del cartel de la arena, fuera de la plaza.
	terrain:FillBall(Vector3.new(60, 1, 14), 5, Enum.Material.Rock)
	terrain:FillBall(Vector3.new(-62, 2, 30), 4, Enum.Material.Rock)
end

-- La isla de la partida en el horizonte: selva y un volcán de capas con cráter.
local function buildIsland(parent: Instance)
	local terrain = Workspace.Terrain
	local layers = 34
	local layerHeight = (VOLCANO_PEAK - SEA_FLOOR) / layers
	for i = 0, layers - 1 do
		local t = i / layers
		local radius = 30 + 260 * (1 - t) ^ 1.5
		local material = if t < 0.08
			then Enum.Material.Sand
			elseif t < 0.4 then Enum.Material.LeafyGrass
			elseif t < 0.6 then Enum.Material.Ground
			else Enum.Material.Basalt
		local y = SEA_FLOOR + (i + 0.5) * layerHeight
		terrain:FillCylinder(CFrame.new(ISLAND_CENTER.X, y, ISLAND_CENTER.Z), layerHeight + 1, radius, material)
	end
	-- Montañas a los lados para que la silueta no sea un cono solo.
	for _, hill in
		{
			{ offset = Vector3.new(-220, 0, 60), radius = 120, height = 90 },
			{ offset = Vector3.new(200, 0, 80), radius = 100, height = 60 },
		}
	do
		local steps = 12
		for i = 0, steps - 1 do
			local t = i / steps
			local y = SEA_FLOOR + (i + 0.5) * (hill.height - SEA_FLOOR) / steps
			terrain:FillCylinder(
				CFrame.new(ISLAND_CENTER + hill.offset + Vector3.new(0, y, 0)),
				(hill.height - SEA_FLOOR) / steps + 1,
				hill.radius * (1 - t) ^ 1.2 + 10,
				if t < 0.1 then Enum.Material.Sand else Enum.Material.LeafyGrass
			)
		end
	end
	local crater = ISLAND_CENTER + Vector3.new(0, VOLCANO_PEAK, 0)
	terrain:FillBall(crater + Vector3.new(0, 6, 0), 34, Enum.Material.Air)

	-- Lava y humo del cráter: se ven desde el Lobby.
	local lava = newPart(
		"Lava",
		Vector3.new(3, 52, 52),
		CFrame.new(crater + Vector3.new(0, -16, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(255, 110, 30),
		Enum.Material.Neon,
		parent
	)
	lava.Shape = Enum.PartType.Cylinder
	decor(lava)
	light(lava, Color3.fromRGB(255, 120, 40), 60, 6)
	local fire = Instance.new("Fire")
	fire.Size = 30
	fire.Heat = 25
	fire.Color = Color3.fromRGB(255, 110, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
	fire.Parent = lava
	local plume = Instance.new("ParticleEmitter")
	plume.Name = "Humo"
	plume.Texture = "rbxasset://textures/particles/smoke_main.dds"
	plume.Color = ColorSequence.new(Color3.fromRGB(110, 95, 90), Color3.fromRGB(60, 55, 60))
	plume.Size = NumberSequence.new(40, 140)
	plume.Transparency = NumberSequence.new(0.2, 1)
	plume.Lifetime = NumberRange.new(14, 20)
	plume.Rate = 3
	plume.Speed = NumberRange.new(14, 22)
	plume.SpreadAngle = Vector2.new(12, 12)
	plume.Acceleration = Vector3.new(-3, 2, 0)
	plume.RotSpeed = NumberRange.new(-10, 10)
	plume.Parent = lava
	local glowEmitter = Instance.new("ParticleEmitter")
	glowEmitter.Name = "Resplandor"
	glowEmitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	glowEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 140, 60))
	glowEmitter.LightEmission = 1
	glowEmitter.Size = NumberSequence.new(30, 60)
	glowEmitter.Transparency = NumberSequence.new(0.4, 1)
	glowEmitter.Lifetime = NumberRange.new(3, 5)
	glowEmitter.Rate = 4
	glowEmitter.Speed = NumberRange.new(8, 12)
	glowEmitter.Parent = lava
	-- Ríos de lava por la ladera que mira al Lobby: tramos que siguen la superficie del cono.
	local toLobby = ((Vector3.zero - ISLAND_CENTER) * Vector3.new(1, 0, 1)).Unit
	local function surfaceY(radius: number): number
		local t = 1 - math.clamp((radius - 30) / 260, 0, 1) ^ (1 / 1.5)
		return SEA_FLOOR + t * (VOLCANO_PEAK - SEA_FLOOR)
	end
	for index, angle in { -0.35, 0.1, 0.45 } do
		local direction = (CFrame.Angles(0, angle, 0) * CFrame.new(toLobby)).Position
		local reach = 110 + index * 30
		local previous: Vector3? = nil
		for radius = 32, reach, 12 do
			local wobble = math.sin(radius / 9 + index) * 3
			local side = Vector3.new(-direction.Z, 0, direction.X)
			local point = ISLAND_CENTER
				+ direction * radius
				+ side * wobble
				+ Vector3.new(0, surfaceY(radius + 6) + 1.5, 0)
			if previous then
				decor(
					newPart(
						"RioDeLava",
						Vector3.new(6 - index, 3, (point - previous).Magnitude + 1),
						CFrame.lookAt((point + previous) / 2, point),
						Color3.fromRGB(255, 100, 25),
						Enum.Material.Neon,
						parent
					)
				)
			end
			previous = point
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Barco: el carguero «Esperanza»

-- Cubierta plana salvo en la proa, que se levanta.
local function sheer(x: number): number
	local t = x / SHIP_HALF_LENGTH
	return if t > 0.5 then 3 * ((t - 0.5) / 0.5) ^ 2 else 0
end

local function halfBeam(x: number, row: number): number
	local t = x / SHIP_HALF_LENGTH
	local shape = 1
	local depth = 0.7 + 0.3 * (row / HULL_ROWS) ^ 0.5 -- pantoque redondeado
	if t > 0.45 then
		-- Proa afilada, más estrecha cuanto más cerca de la quilla.
		shape = 1 - ((t - 0.45) / 0.55) ^ 1.8
		depth = 0.45 + 0.55 * (row / HULL_ROWS) ^ 0.7
	elseif t < -0.85 then
		shape = 1 - 0.25 * ((-t - 0.85) / 0.15) ^ 2
	end
	return math.max(0.5, SHIP_BEAM / 2 * shape * depth)
end

local function hullPoint(x: number, row: number, side: number): Vector3
	return Vector3.new(x, row * ROW_HEIGHT + sheer(x) * row / HULL_ROWS, side * halfBeam(x, row))
end

local function deckHeight(x: number): number
	return HULL_ROWS * ROW_HEIGHT + sheer(x)
end

-- Obra viva roja, franja negra en la flotación y obra muerta azul marino.
local function hullColor(row: number): Color3
	if row <= 1 then
		return HULL_RED
	elseif row == 2 then
		return BOOT_TOP
	end
	return HULL_NAVY
end

-- Una chapa del casco entre dos filas y dos cortes de la eslora (en coordenadas del barco).
local function plate(model: Model, side: number, row: number, x0: number, x1: number, color: Color3)
	local a0, a1 = hullPoint(x0, row, side), hullPoint(x0, row + 1, side)
	local b0, b1 = hullPoint(x1, row, side), hullPoint(x1, row + 1, side)
	local center = (a0 + a1 + b0 + b1) / 4
	local along = ((b0 + b1) / 2 - (a0 + a1) / 2)
	local up = ((a1 + b1) / 2 - (a0 + b0) / 2)
	local zAxis = along.Unit
	local yAxis = (up - zAxis * up:Dot(zAxis)).Unit
	local xAxis = yAxis:Cross(zAxis)
	newPart(
		"Chapa",
		Vector3.new(0.7, up.Magnitude + 0.2, along.Magnitude + 0.2),
		CFrame.fromMatrix(center, xAxis, yAxis, zAxis),
		color,
		Enum.Material.Metal,
		model
	)
end

-- Marco de una pieza plana pegada al costado de la playa (+Z) entre dos cortes de la eslora y dos
-- filas (en coordenadas del barco), y su tamaño. Sigue la cuerda del casco y se separa lo justo
-- para que ninguna chapa la atraviese. La cara Front mira hacia fuera.
local function hullBoard(
	xFrom: number,
	xTo: number,
	rowFrom: number,
	rowTo: number,
	thickness: number
): (CFrame, Vector2)
	-- Se mide sobre las chapas (planas y algo más grandes que su hueco), no sobre la curva: donde
	-- empieza la proa el ancho da un pequeño salto y la chapa no coincide con ella.
	local step = 2 * SHIP_HALF_LENGTH / HULL_SEGMENTS
	-- Punto del plano de la chapa del tramo de segmentX y la fila de rowBand.
	local function platePoint(x: number, row: number, segmentX: number, rowBand: number): Vector3
		local segment = math.clamp(math.floor((segmentX + SHIP_HALF_LENGTH) / step), 0, HULL_SEGMENTS - 1)
		local band = math.clamp(math.floor(rowBand), 0, HULL_ROWS - 1)
		local x0 = -SHIP_HALF_LENGTH + segment * step
		local u, v = (x - x0) / step, row - band
		local low = hullPoint(x0, band, 1):Lerp(hullPoint(x0 + step, band, 1), u)
		local high = hullPoint(x0, band + 1, 1):Lerp(hullPoint(x0 + step, band + 1, 1), u)
		return low:Lerp(high, v)
	end
	local inset = 0.01
	local a0 = platePoint(xFrom, rowFrom, xFrom + inset, rowFrom + inset)
	local a1 = platePoint(xFrom, rowTo, xFrom + inset, rowTo - inset)
	local b0 = platePoint(xTo, rowFrom, xTo - inset, rowFrom + inset)
	local b1 = platePoint(xTo, rowTo, xTo - inset, rowTo - inset)
	local center = (a0 + a1 + b0 + b1) / 4
	local along = ((b0 + b1) / 2 - (a0 + a1) / 2)
	local rise = ((a1 + b1) / 2 - (a0 + b0) / 2)
	local up = (rise - along.Unit * rise:Dot(along.Unit)).Unit
	local outward = along.Unit:Cross(up)
	local clearance = 0
	for i = 0, 10 do
		local x = xFrom + (xTo - xFrom) * i / 10
		for j = 0, 4 do
			local row = rowFrom + (rowTo - rowFrom) * j / 4
			for _, dx in { -0.15, 0.15 } do
				for _, dr in { -0.1, 0.1 } do
					clearance = math.max(clearance, (platePoint(x, row, x + dx, row + dr) - center):Dot(outward))
				end
			end
		end
	end
	local position = center + outward * (clearance + 0.4 + thickness / 2)
	return CFrame.lookAt(position, position + outward, up), Vector2.new(along.Magnitude, rise:Dot(up))
end

local function isHole(side: number, row: number, segment: number): boolean
	-- Boquete en el costado que mira a la playa (+Z): deja ver la bodega.
	if side ~= 1 then
		return false
	end
	if segment == 7 then
		return row <= 4
	end
	return (segment == 6 or segment == 8) and row >= 1 and row <= 3
end

local function buildHull(model: Model)
	local step = 2 * SHIP_HALF_LENGTH / HULL_SEGMENTS
	for segment = 0, HULL_SEGMENTS - 1 do
		local x0 = -SHIP_HALF_LENGTH + segment * step
		local x1 = x0 + step
		for _, side in { -1, 1 } do
			for row = 0, HULL_ROWS - 1 do
				if not isHole(side, row, segment) then
					plate(model, side, row, x0, x1, tone(hullColor(row)))
				end
			end
		end
		-- Fondo de la bodega.
		local mid = (x0 + x1) / 2
		newPart(
			"Bodega",
			Vector3.new(step + 0.2, 0.8, 2 * halfBeam(mid, 0.6)),
			CFrame.new(mid, 0.6, 0),
			Color3.fromRGB(60, 62, 66),
			Enum.Material.DiamondPlate,
			model
		)
	end
	-- Chapas reventadas hacia fuera en el borde del boquete.
	for _, shard in
		{
			{ x = -9.5, row = 3.6, length = 3.2, tilt = 0.5 },
			{ x = -4.75, row = 4.4, length = 2.6, tilt = -0.4 },
			{ x = -14, row = 2.4, length = 2.4, tilt = 0.8 },
			{ x = 0.5, row = 1.2, length = 2.8, tilt = -0.7 },
			{ x = 5, row = 2.6, length = 2.2, tilt = 0.4 },
			{ x = -2, row = 5, length = 2.4, tilt = 0.2 },
		}
	do
		local point = hullPoint(shard.x, shard.row, 1)
		newPart(
			"ChapaRota",
			Vector3.new(0.5, 2, shard.length),
			CFrame.new(point + Vector3.new(0, 0, 0.6)) * CFrame.Angles(shard.tilt, 0.5, 0),
			if shard.row > 2.5 then HULL_NAVY else HULL_RED,
			Enum.Material.CorrodedMetal,
			model
		)
	end
	-- Chorretones de óxido bajo la borda (hacia popa: delante están el nombre y los tablones).
	for _, x in { -30, -21, -13 } do
		local point = hullPoint(x, HULL_ROWS - 1.1, 1)
		decor(
			newPart(
				"Oxido",
				Vector3.new(0.6, rng:NextNumber(2.5, 4), 0.2),
				CFrame.new(point + Vector3.new(0, 0, 0.45)),
				RUST,
				Enum.Material.CorrodedMetal,
				model
			)
		)
	end
	-- Quilla, roda y espejo de popa.
	newPart(
		"Quilla",
		Vector3.new(2 * SHIP_HALF_LENGTH, 1.2, 1.4),
		CFrame.new(0, -0.3, 0),
		HULL_RED,
		Enum.Material.Metal,
		model
	)
	local stemTop = Vector3.new(SHIP_HALF_LENGTH + 0.4, deckHeight(SHIP_HALF_LENGTH) + 0.6, 0)
	cylinder("Roda", 1.2, Vector3.new(SHIP_HALF_LENGTH - 1.5, 0, 0), stemTop, HULL_NAVY, Enum.Material.Metal, model)
	for row = 0, HULL_ROWS - 1 do
		local width = 2 * halfBeam(-SHIP_HALF_LENGTH, row + 0.5)
		newPart(
			"Espejo",
			Vector3.new(0.7, ROW_HEIGHT + 0.2, width),
			CFrame.new(-SHIP_HALF_LENGTH - 0.2, (row + 0.5) * ROW_HEIGHT, 0),
			tone(hullColor(row)),
			Enum.Material.Metal,
			model
		)
	end
	-- Nombre pintado en la popa y en la proa (lado de la playa).
	local sternName = newPart(
		"Nombre",
		Vector3.new(0.2, 2.6, 14),
		CFrame.new(-SHIP_HALF_LENGTH - 0.65, deckHeight(-SHIP_HALF_LENGTH) - 2.6, 0),
		HULL_NAVY,
		Enum.Material.Metal,
		model
	)
	sign(sternName, Enum.NormalId.Left, "ESPERANZA\nPANAMÁ", WHITE_PAINT, Enum.Font.GothamBlack)
	-- En la proa, una letra por pieza: cada una sigue su tramo de la curva del casco (una placa
	-- recta entera quedaba atravesada por las chapas del centro y no se leía).
	local letters = "ESPERANZA"
	local spacing = 1.05
	for i = 1, #letters do
		local x0 = 16.6 + (i - 1) * spacing
		local frame, size = hullBoard(x0, x0 + spacing, 4.08, 4.92, 0.1)
		local letter =
			newPart("NombreProa", Vector3.new(size.X, size.Y, 0.1), frame, HULL_NAVY, Enum.Material.Metal, model)
		letter.Transparency = 1
		decor(letter)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 1
		gui.Parent = letter
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = string.sub(letters, i, i)
		label.TextColor3 = WHITE_PAINT
		label.Font = Enum.Font.GothamBlack
		-- Tamaño fijo (no TextScaled): con cajas iguales, cada letra saldría de un tamaño distinto.
		label.TextSize = 58
		label.Parent = gui
	end
end

-- Texto grande con borde (títulos de los carteles).
local function headline(part: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0 -- siempre legible, también de noche
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = label
end

-- Cartel grande sobre dos postes clavados en la arena en (x, z), de cara a la plaza o hacia "facing":
-- marco de madera oscura, cabecera con el título y un farol en lo alto de cada poste. "headerShare":
-- qué parte del ancho ocupa la cabecera (más para un título largo). Devuelve el tablón, donde va el
-- contenido.
local function standingBoard(
	parent: Instance,
	name: string,
	at: Vector2,
	width: number,
	height: number,
	title: string,
	facing: Vector2?,
	headerShare: number?
): Part
	local ground = groundAt(at.X, at.Y)
	local bottom = 4.5 -- del suelo al borde de abajo del tablón
	local center = ground + Vector3.new(0, bottom + height / 2, 0)
	local target = if facing
		then center + Vector3.new(facing.X, 0, facing.Y)
		else Vector3.new(PLAZA.X, center.Y, PLAZA.Y)
	local frame = CFrame.lookAt(center, target)

	local model = Instance.new("Model")
	model.Name = name
	local board = newPart(name, Vector3.new(width, height, 0.4), frame, PLANK, Enum.Material.WoodPlanks, model)
	-- Largueros arriba y abajo, un poco por delante del tablón.
	for _, side in { -1, 1 } do
		newPart(
			"Larguero",
			Vector3.new(width + 0.4, 0.5, 0.7),
			frame * CFrame.new(0, side * (height / 2 + 0.25), -0.1),
			DARK_WOOD,
			Enum.Material.Wood,
			model
		)
	end
	-- Postes de suelo (enterrados un estudio) hasta por encima de la cabecera, con su farol.
	local postTop = height / 2 + 3
	local postBottom = -(height / 2 + bottom + 1)
	for _, side in { -1, 1 } do
		local x = side * (width / 2 + 0.75)
		newPart(
			"PosteCartel",
			Vector3.new(1.1, postTop - postBottom, 1.1),
			frame * CFrame.new(x, (postTop + postBottom) / 2, 0.1),
			DARK_WOOD,
			Enum.Material.Wood,
			model
		)
		newPart(
			"Tapa",
			Vector3.new(1.5, 0.3, 1.5),
			frame * CFrame.new(x, postTop + 0.15, 0.1),
			IRON,
			Enum.Material.Metal,
			model
		)
		local lamp = newPart(
			"Farol",
			Vector3.new(0.8, 1, 0.8),
			frame * CFrame.new(x, postTop + 0.8, 0.1),
			LANTERN_LIGHT,
			Enum.Material.Neon,
			model
		)
		decor(lamp)
		-- Luz floja: con el atardecer, una más fuerte quema el cartel y no se lee.
		light(lamp, LANTERN_LIGHT, 8, 0.6)
	end
	-- Cabecera roja con el título, clavada entre los postes por encima del tablón.
	local header = newPart(
		"Cabecera",
		Vector3.new(width * (headerShare or 0.62), 2.2, 0.5),
		frame * CFrame.new(0, height / 2 + 1.6, -0.15),
		HULL_RED,
		Enum.Material.WoodPlanks,
		model
	)
	headline(header, title, Color3.fromRGB(255, 215, 90))
	model.Parent = parent
	return board
end

-- Cartelito que indica un bote, con el aspecto de los carteles grandes en pequeño: tablón rojo con
-- el texto dorado, largueros y dos postes de madera oscura con su farol, clavado en el suelo bajo
-- (x, z) y de cara a la plaza. En la bajada a la orilla los postes se alargan para que el tablón
-- quede a la altura de la plaza y no parezca hundido.
local function smallSign(parent: Instance, at: Vector2, text: string)
	local width, height = 6, 2
	local ground = groundAt(at.X, at.Y)
	-- Del suelo al borde de abajo del tablón.
	local bottom = 2.2 + math.max(0, BAR_TOP - ground.Y)
	local center = ground + Vector3.new(0, bottom + height / 2, 0)
	local frame = CFrame.lookAt(center, Vector3.new(PLAZA.X, center.Y, PLAZA.Y))
	local plank = newPart("Cartel", Vector3.new(width, height, 0.4), frame, HULL_RED, Enum.Material.WoodPlanks, parent)
	headline(plank, text, Color3.fromRGB(255, 215, 90))
	for _, side in { -1, 1 } do
		newPart(
			"Larguero",
			Vector3.new(width + 0.3, 0.35, 0.6),
			frame * CFrame.new(0, side * (height / 2 + 0.17), -0.05),
			DARK_WOOD,
			Enum.Material.Wood,
			parent
		)
	end
	local postTop = height / 2 + 1.2
	local postBottom = -(height / 2 + bottom + 1)
	for _, side in { -1, 1 } do
		local x = side * (width / 2 + 0.45)
		newPart(
			"PosteCartel",
			Vector3.new(0.7, postTop - postBottom, 0.7),
			frame * CFrame.new(x, (postTop + postBottom) / 2, 0.05),
			DARK_WOOD,
			Enum.Material.Wood,
			parent
		)
		newPart(
			"Tapa",
			Vector3.new(1, 0.25, 1),
			frame * CFrame.new(x, postTop + 0.12, 0.05),
			IRON,
			Enum.Material.Metal,
			parent
		)
		local lamp = newPart(
			"Farol",
			Vector3.new(0.55, 0.7, 0.55),
			frame * CFrame.new(x, postTop + 0.6, 0.05),
			LANTERN_LIGHT,
			Enum.Material.Neon,
			parent
		)
		decor(lamp)
		light(lamp, LANTERN_LIGHT, 6, 0.5)
	end
end

-- Columnas de un cartel de clasificación (las rellena LeaderboardService por el nombre de cada
-- columna, que es el de su clasificación): título y una línea por puesto. Van en bloques (un recuadro
-- con su título y sus columnas), repartidos a lo ancho del cartel.
type RankingBlock = { title: string, columns: { { stat: string, title: string } } }
local function rankingColumns(ranking: Part, blocks: { RankingBlock })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0 -- siempre legible, también de noche
	gui.Parent = ranking
	local function text(value: string, list: Instance, position: UDim2, size: UDim2): TextLabel
		local label = Instance.new("TextLabel")
		label.Position = position
		label.Size = size
		label.BackgroundTransparency = 1
		label.Text = value
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.BuilderSansBold
		label.TextScaled = true
		label.Parent = list
		-- Tope común: así los dos encabezados y todas las líneas salen del mismo tamaño aunque
		-- unos textos sean más largos que otros.
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 23
		limit.Parent = label
		return label
	end
	local blockWidth = 0.94 / #blocks
	for index, block in blocks do
		local card = Instance.new("Frame")
		card.Name = `Bloque{index}`
		card.BackgroundColor3 = BOARD_CARD
		card.BackgroundTransparency = 0.1
		card.Position = UDim2.fromScale(0.03 + (index - 1) * blockWidth, 0.05)
		card.Size = UDim2.fromScale(blockWidth - 0.02, 0.9)
		card.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.05, 0)
		corner.Parent = card
		local title = text(block.title, card, UDim2.fromScale(0.04, 0.02), UDim2.fromScale(0.92, 0.15))
		title.TextColor3 = Color3.fromRGB(255, 160, 90)
		local columnWidth = 1 / #block.columns
		for column, board in block.columns do
			local list = Instance.new("Frame")
			list.Name = board.stat
			list.BackgroundTransparency = 1
			list.Position = UDim2.fromScale((column - 1) * columnWidth, 0.17)
			list.Size = UDim2.fromScale(columnWidth, 0.83)
			list.Parent = card
			local header = text(board.title, list, UDim2.fromScale(0.06, 0), UDim2.fromScale(0.88, 0.15))
			header.TextColor3 = Color3.fromRGB(255, 215, 90)
			for position = 1, Config.Lobby.RankingBoardSize do
				local line = text(
					if position == 1 then "Aún no hay datos" else "",
					list,
					UDim2.fromScale(0.07, 0.02 + position * 0.165),
					UDim2.fromScale(0.88, 0.14)
				)
				line.Name = tostring(position)
				line.TextXAlignment = Enum.TextXAlignment.Left
				line.TextColor3 = RANK_COLORS[position] or line.TextColor3
			end
		end
	end
end

-- Aviso de una estación de la plaza (abre su ventana en LobbyUIController) y los atributos con los
-- que la señalan los marcadores de cada cliente (icono encima y brillo al acercarse).
local function station(part: BasePart, id: string, icon: string, promptName: string?, action: string?, object: string?)
	part:SetAttribute("StationId", id)
	part:SetAttribute("StationIcon", icon)
	if promptName then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = promptName
		prompt.ActionText = action or ""
		prompt.ObjectText = object or ""
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 13
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end
end

-- Carteles del borde de la plaza: la bitácora del capitán; las mascotas (lo dibuja PetBoardController
-- en cada cliente con su huevo; se interactúa con el nido, no con el cartel); los roles (lo dibuja
-- RoleBoardController; su aviso abre la ventana de roles); el ranking con las cuatro clasificaciones
-- (lo rellena LeaderboardService; su aviso abre la ventana del ranking) y el de la Isla de dunas (lo
-- dibuja ArenaBoardController con tu estado de la arena; su aviso abre la ventana de la arena).
local function buildBoards(parent: Instance)
	-- La bitácora cuenta la historia del naufragio en un panel oscuro, como el del ranking.
	local log = standingBoard(parent, "BitacoraDelCapitan", LOG_BOARD_AT, 14, 8.5, "📜 BITÁCORA DEL CAPITÁN")
	local logGui = Instance.new("SurfaceGui")
	logGui.Face = Enum.NormalId.Front
	logGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	logGui.PixelsPerStud = 40
	logGui.LightInfluence = 0 -- siempre legible, también de noche
	logGui.Parent = log
	local page = Instance.new("TextLabel")
	page.Position = UDim2.fromScale(0.03, 0.05)
	page.Size = UDim2.fromScale(0.94, 0.9)
	page.BackgroundColor3 = BOARD_CARD
	page.BackgroundTransparency = 0.1
	page.Text = LOG_TEXT
	page.TextColor3 = Color3.fromRGB(235, 225, 205)
	page.Font = Enum.Font.BuilderSansMedium
	page.TextScaled = true
	page.TextWrapped = true
	page.TextXAlignment = Enum.TextXAlignment.Left
	page.TextYAlignment = Enum.TextYAlignment.Top
	page.Parent = logGui
	local pageCorner = Instance.new("UICorner")
	pageCorner.CornerRadius = UDim.new(0.04, 0)
	pageCorner.Parent = page
	local pagePadding = Instance.new("UIPadding")
	pagePadding.PaddingLeft = UDim.new(0.03, 0)
	pagePadding.PaddingRight = UDim.new(0.03, 0)
	pagePadding.PaddingTop = UDim.new(0.04, 0)
	pagePadding.PaddingBottom = UDim.new(0.04, 0)
	pagePadding.Parent = page

	-- Mascotas: el huevo del nido de cada jugador (no lleva aviso: se interactúa con el nido). Más alto
	-- que los demás: el huevo del nido tapa su franja de abajo, y el contenido va encima
	-- (PetBoardController); subirlo entero dejaría ver el nombre de la proa por debajo.
	local pets = standingBoard(parent, "TablaMascotas", PETS_BOARD_AT, 14, PETS_BOARD_HEIGHT, "🐾 MASCOTAS")
	CollectionService:AddTag(pets, Config.Lobby.PetsBoardTag)

	-- Ranking: supervivencia (días y rescates) y arena (victorias y banderas, Leaderboards.ARENA_STATS).
	local ranking = standingBoard(parent, "TablaRanking", RANKING_BOARD_AT, 20, 7.5, "🏆 RANKING")
	CollectionService:AddTag(ranking, Config.Lobby.RankingBoardTag)
	rankingColumns(ranking, {
		{
			title = "🐒 SUPERVIVENCIA",
			columns = {
				{ stat = "BestDays", title = "📅 Más días" },
				{ stat = "Rescues", title = "🚁 Más rescates" },
			},
		},
		{
			title = "🎖️ ARENA",
			columns = {
				{ stat = "ArenaWins", title = "🏆 Más victorias" },
				{ stat = "ArenaCaptures", title = "🚩 Más banderas" },
			},
		},
	})
	station(ranking, "Ranking", "🏆", "RankingPrompt", "Ver ranking", "Ranking")

	-- Isla de dunas: tu estado en la arena (ArenaBoardController); su aviso abre la ventana de la arena.
	local arena = standingBoard(parent, "TablaArena", ARENA_BOARD_AT, 12, 7.5, Config.PlaceNames.Dunas, nil, 0.95)
	CollectionService:AddTag(arena, Config.Lobby.ArenaBoardTag)
	station(arena, "Arena", "🎖️", "ArenaPrompt", "Jugar en la arena", Config.PlaceNames.DunasShort)

	local roles = standingBoard(parent, "TablaRoles", ROLE_BOARD_AT, 16, 7.5, "ELIGE TU ROL")
	CollectionService:AddTag(roles, Config.Lobby.RoleBoardTag)
	station(roles, "Rol", "⚔️", "RolesPrompt", "Elegir rol", "Roles")
end

-- Nido de huevos del Lobby: cada cliente dibuja encima su propio huevo y su temporizador
-- (NestController, por la etiqueta Config.Lobby.NestTag y el punto "EggSeat"); con el aviso
-- "NidoPrompt" se abre el panel del nido. Antorchas tiki a los lados.
local function buildNest(parent: Instance)
	local ground = groundAt(NEST_AT.X, NEST_AT.Y)
	local model = Instance.new("Model")
	model.Name = "NidoDeHuevos"
	local mound = newPart(
		"Monticulo",
		Vector3.new(13, NEST_MOUND_HEIGHT * 2, 13),
		CFrame.new(ground),
		Color3.fromRGB(214, 190, 140),
		Enum.Material.Sand,
		model
	)
	local moundMesh = Instance.new("SpecialMesh")
	moundMesh.MeshType = Enum.MeshType.Sphere
	moundMesh.Parent = mound

	local nest = BuildModels.build("Nest")
	nest.Name = "Nido"
	nest:ScaleTo(NEST_SCALE)
	local _, nestSize = nest:GetBoundingBox()
	nest:PivotTo(CFrame.new(ground + Vector3.new(0, NEST_MOUND_HEIGHT * 0.8 + nestSize.Y / 2 - 0.3, 0)))
	nest.Parent = model
	local seat = nest:FindFirstChild("EggSeat", true)
	if seat and seat:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "NidoPrompt"
		prompt.ActionText = "Ver el nido"
		prompt.ObjectText = "Nido de huevos"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = seat
	end

	-- Antorchas tiki detrás, a los lados: enmarcan el huevo sin taparlo desde la llegada.
	for _, side in { -1, 1 } do
		local base = ground + Vector3.new(side * 6.5, 0, -3)
		local top = base + Vector3.new(0, 6.2, 0)
		cylinder("Antorcha", 0.45, base - Vector3.new(0, 1, 0), top, PLANK, Enum.Material.Wood, model)
		local head = cylinder(
			"Mecha",
			0.95,
			top - Vector3.new(0, 0.3, 0),
			top + Vector3.new(0, 1, 0),
			Color3.fromRGB(150, 135, 85),
			Enum.Material.Fabric,
			model
		)
		local flame = Instance.new("Fire")
		flame.Size = 3
		flame.Heat = 6
		flame.Parent = head
		light(head, FIRE_LIGHT, 16, 1.5)
	end

	CollectionService:AddTag(model, Config.Lobby.NestTag)
	-- Estación del nido: el aviso está en el asiento del huevo; el marcador va sobre el montículo.
	station(mound, "Mascotas", "🥚")
	model.Parent = parent
end

local function buildDeck(model: Model)
	local step = 2 * SHIP_HALF_LENGTH / HULL_SEGMENTS
	for segment = 0, HULL_SEGMENTS - 1 do
		local x0 = -SHIP_HALF_LENGTH + segment * step
		local mid = x0 + step / 2
		local width = 2 * halfBeam(mid, HULL_ROWS) - 0.6
		local y = deckHeight(mid) - 0.4
		if segment == 7 then
			-- Cubierta hundida sobre el boquete: planchas dobladas hacia la bodega.
			for i = -1, 1 do
				newPart(
					"PlanchaDoblada",
					Vector3.new(step * 0.9, 0.4, 3),
					CFrame.new(mid + i * 0.6, y - 1.5 - i * 0.6, -3 + i * 4) * CFrame.Angles(0.25 * i, 0.2 * i, 0.3),
					STEEL_DECK,
					Enum.Material.DiamondPlate,
					model
				)
			end
		else
			newPart(
				"Cubierta",
				Vector3.new(step + 0.2, 0.6, width),
				CFrame.new(mid, y, 0),
				STEEL_DECK,
				Enum.Material.DiamondPlate,
				model
			)
		end
		-- Barandilla de tubo con dos pasamanos; hueco en el costado de la pasarela.
		for _, side in { -1, 1 } do
			if not (side == 1 and segment == 3) then
				local a = hullPoint(x0, HULL_ROWS, side)
				local b = hullPoint(x0 + step, HULL_ROWS, side)
				for _, height in { 0.9, 1.8 } do
					cylinder(
						"Barandilla",
						0.22,
						a + Vector3.new(0, height, 0),
						b + Vector3.new(0, height, 0),
						RAIL,
						Enum.Material.Metal,
						model
					)
				end
				newPart(
					"Candelero",
					Vector3.new(0.25, 1.9, 0.25),
					CFrame.new(a + Vector3.new(0, 0.95, 0)),
					RAIL,
					Enum.Material.Metal,
					model
				)
			end
		end
	end
end

-- Ventanas en una cara: algunas encendidas, otras oscuras.
local function windows(model: Model, from: Vector3, along: Vector3, count: number, spacing: number, size: Vector3)
	for i = 0, count - 1 do
		local lit = rng:NextNumber() < 0.35
		local pane = newPart(
			"Ventana",
			size,
			CFrame.new(from + along * (i * spacing)),
			if lit then Color3.fromRGB(255, 205, 120) else GLASS,
			if lit then Enum.Material.Neon else Enum.Material.Glass,
			model
		)
		decor(pane)
		if lit then
			broken(pane)
		end
	end
end

-- Castillo de popa: tres pisos blancos con el puente de mando arriba, chimenea, mástil de radar,
-- luces de navegación, escalera exterior y el pescante vacío de la lancha.
local function buildSuperstructure(model: Model)
	local floor = deckHeight(-30) - 0.1
	local fullWidth = 2 * halfBeam(-30, HULL_ROWS)
	local levels = {
		{ x0 = -36.5, x1 = -24, width = fullWidth - 3, height = 3.4 },
		{ x0 = -36, x1 = -25.5, width = fullWidth - 5, height = 3.4 },
		{ x0 = -32, x1 = -26, width = fullWidth + 2, height = 3.6 },
	}
	local bottom = floor
	for index, level in levels do
		local length = level.x1 - level.x0
		local centerX = (level.x0 + level.x1) / 2
		newPart(
			if index == 3 then "Puente" else "Castillo",
			Vector3.new(length, level.height, level.width),
			CFrame.new(centerX, bottom + level.height / 2, 0),
			WHITE_PAINT,
			Enum.Material.SmoothPlastic,
			model
		)
		if index == 3 then
			-- Cristalera corrida del puente y techo con visera.
			decor(
				newPart(
					"Cristalera",
					Vector3.new(0.2, 1.7, level.width - 1),
					CFrame.new(level.x1 + 0.05, bottom + 2.2, 0),
					GLASS,
					Enum.Material.Glass,
					model
				)
			)
			newPart(
				"TechoPuente",
				Vector3.new(length + 1.2, 0.4, level.width + 0.4),
				CFrame.new(centerX + 0.4, bottom + level.height + 0.2, 0),
				WHITE_PAINT,
				Enum.Material.SmoothPlastic,
				model
			)
		else
			local count = math.floor(level.width / 3)
			windows(
				model,
				Vector3.new(level.x1 + 0.05, bottom + 2, -(count - 1) * 1.5),
				Vector3.zAxis,
				count,
				3,
				Vector3.new(0.2, 1.1, 1.4)
			)
		end
		-- Ventanas del costado que mira a la playa.
		local sideCount = math.floor(length / 2.6)
		windows(
			model,
			Vector3.new(level.x0 + 1.4, bottom + 2, level.width / 2 + 0.05),
			Vector3.xAxis,
			sideCount,
			2.6,
			Vector3.new(1.3, 1.1, 0.2)
		)
		bottom += level.height
	end
	newPart(
		"Puerta",
		Vector3.new(0.2, 2.6, 1.4),
		CFrame.new(-23.9, floor + 1.3, -4),
		Color3.fromRGB(90, 95, 100),
		Enum.Material.Metal,
		model
	)
	-- Escalera exterior hasta el techo del primer piso.
	for i = 0, 4 do
		newPart(
			"Escalon",
			Vector3.new(1.6, 0.4, 1.3),
			CFrame.new(-23.1, floor + 0.5 + i * 0.68, 2 + i * 1.3),
			ALUMINIUM,
			Enum.Material.DiamondPlate,
			model
		)
	end

	-- Chimenea detrás del puente: blanca, franja naranja y boca negra.
	local funnelBase = floor + levels[1].height + levels[2].height
	local funnelX = -34.6
	newPart(
		"Chimenea",
		Vector3.new(3, 6, 4),
		CFrame.new(funnelX, funnelBase + 3, 0),
		WHITE_PAINT,
		Enum.Material.SmoothPlastic,
		model
	)
	newPart(
		"FranjaChimenea",
		Vector3.new(3.1, 1.4, 4.1),
		CFrame.new(funnelX, funnelBase + 4, 0),
		RESCUE_ORANGE,
		Enum.Material.SmoothPlastic,
		model
	)
	newPart(
		"BocaChimenea",
		Vector3.new(3.1, 0.8, 4.1),
		CFrame.new(funnelX, funnelBase + 6.2, 0),
		IRON,
		Enum.Material.Metal,
		model
	)

	-- Mástil de radar sobre el puente, con la antena parada y luces de navegación.
	local roof = bottom + 0.4
	local mastX = -29
	newPart("MastilRadar", Vector3.new(0.6, 7, 0.6), CFrame.new(mastX, roof + 3.5, 0), RAIL, Enum.Material.Metal, model)
	newPart("Cruceta", Vector3.new(0.4, 0.4, 5), CFrame.new(mastX, roof + 5.5, 0), RAIL, Enum.Material.Metal, model)
	newPart(
		"Radar",
		Vector3.new(0.5, 0.35, 4.5),
		CFrame.new(mastX, roof + 7.3, 0) * CFrame.Angles(0, 0.6, 0),
		Color3.fromRGB(40, 40, 45),
		Enum.Material.Metal,
		model
	)
	ball("Domo", 1.2, Vector3.new(mastX, roof + 6.2, 2.4), WHITE_PAINT, Enum.Material.SmoothPlastic, model)
	for _, navigation in
		{
			{ z = -2.6, color = Color3.fromRGB(255, 40, 40) }, -- babor
			{ z = 2.6, color = Color3.fromRGB(40, 255, 90) }, -- estribor
		}
	do
		broken(
			decor(
				ball(
					"LuzNavegacion",
					0.5,
					Vector3.new(mastX, roof + 5.5, navigation.z),
					navigation.color,
					Enum.Material.Neon,
					model
				)
			)
		)
	end
	local topLight =
		ball("LuzTope", 0.5, Vector3.new(mastX, roof + 7.2, 0), Color3.new(1, 1, 1), Enum.Material.Neon, model)
	broken(decor(topLight))
	light(topLight, Color3.fromRGB(255, 240, 220), 18, 1.5)

	-- Pescante de la lancha, vacío: los cables cuelgan sueltos.
	local davitBase = floor + levels[1].height
	for _, x in { -33.5, -27.5 } do
		local post = Vector3.new(x, davitBase + 1.5, levels[1].width / 2 - 0.4)
		newPart("Pescante", Vector3.new(0.5, 3, 0.5), CFrame.new(post), RESCUE_ORANGE, Enum.Material.Metal, model)
		local arm = post + Vector3.new(0, 1.3, 1.6)
		newPart("BrazoPescante", Vector3.new(0.5, 0.5, 3.6), CFrame.new(arm), RESCUE_ORANGE, Enum.Material.Metal, model)
		decor(
			cylinder(
				"Cable",
				0.12,
				arm + Vector3.new(0, 0, 1.6),
				arm + Vector3.new(0, -5, 1.8),
				IRON,
				Enum.Material.Metal,
				model
			)
		)
	end
end

-- Contenedor de mercancías con nervios, puertas y, si se pide, un rótulo en el costado.
local function container(
	parent: Instance,
	cframe: CFrame,
	color: Color3,
	label: string?,
	labelFace: Enum.NormalId?,
	doorsOpen: boolean?
): Part
	local size = Vector3.new(12, 5.2, 4.8)
	local body = newPart("Contenedor", size, cframe, color, Enum.Material.Metal, parent)
	local rib = color:Lerp(Color3.new(0, 0, 0), 0.25)
	for _, side in { -1, 1 } do
		for _, x in { -4.5, -1.5, 1.5, 4.5 } do
			decor(
				newPart(
					"Nervio",
					Vector3.new(0.35, size.Y - 0.4, 0.15),
					cframe * CFrame.new(x, 0, side * (size.Z / 2 + 0.07)),
					rib,
					Enum.Material.Metal,
					parent
				)
			)
		end
		decor(
			newPart(
				"Larguero",
				Vector3.new(size.X, 0.3, 0.3),
				cframe * CFrame.new(0, size.Y / 2 - 0.1, side * (size.Z / 2 - 0.1)),
				rib,
				Enum.Material.Metal,
				parent
			)
		)
	end
	local doorEnd = cframe * CFrame.new(size.X / 2 + 0.08, 0, 0)
	if doorsOpen then
		decor(
			newPart(
				"Interior",
				Vector3.new(0.1, size.Y - 0.5, size.Z - 0.5),
				doorEnd,
				Color3.fromRGB(25, 25, 25),
				Enum.Material.Metal,
				parent
			)
		)
		for _, side in { -1, 1 } do
			newPart(
				"PuertaContenedor",
				Vector3.new(0.15, size.Y - 0.3, size.Z / 2),
				doorEnd * CFrame.new(size.Z / 4, 0, side * (size.Z / 2 + 0.05)) * CFrame.Angles(0, side * 1.4, 0),
				rib,
				Enum.Material.Metal,
				parent
			)
		end
	else
		decor(
			newPart("Puertas", Vector3.new(0.15, size.Y - 0.3, size.Z - 0.3), doorEnd, rib, Enum.Material.Metal, parent)
		)
		for _, z in { -0.8, 0.8 } do
			decor(
				newPart(
					"Cierre",
					Vector3.new(0.15, size.Y - 0.6, 0.12),
					doorEnd * CFrame.new(0.1, 0, z),
					ALUMINIUM,
					Enum.Material.Metal,
					parent
				)
			)
		end
	end
	if label and labelFace then
		sign(body, labelFace, label, WHITE_PAINT, Enum.Font.GothamBlack)
	end
	return body
end

local function containerColor(): Color3
	return CONTAINER_COLORS[rng:NextInteger(1, #CONTAINER_COLORS)]
end

-- Contenedores en cubierta (uno a punto de caer por la borda) y una grúa amarilla.
local function buildCargo(model: Model)
	local tier1 = deckHeight(0) - 0.1 + 2.6
	local tier2 = tier1 + 5.2
	for _, bay in { -14, 9 } do
		for _, z in { -6, 0, 6 } do
			local stamped = bay == -14 and z == 6
			container(
				model,
				CFrame.new(bay, tier1, z),
				containerColor(),
				if stamped then "PRIMAL" else nil,
				if stamped then Enum.NormalId.Back else nil
			)
		end
		container(model, CFrame.new(bay, tier2, -6), containerColor())
	end
	container(model, CFrame.new(-14, tier2, 0), containerColor())
	-- El de arriba a estribor se ha deslizado hacia la playa.
	container(
		model,
		CFrame.new(9, tier2 - 1, 7.8) * CFrame.Angles(0.3, 0.05, 0),
		containerColor(),
		"PRIMAL",
		Enum.NormalId.Back
	)

	-- Grúa de cubierta con la pluma levantada y el gancho colgando.
	local base = Vector3.new(21, deckHeight(21) - 0.1, -6)
	local pedestal = newPart(
		"PedestalGrua",
		Vector3.new(5, 3, 3),
		CFrame.new(base + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		CRANE_YELLOW,
		Enum.Material.Metal,
		model
	)
	pedestal.Shape = Enum.PartType.Cylinder
	local cab = base + Vector3.new(0, 6.5, 0)
	newPart("CabinaGrua", Vector3.new(4, 3, 3.5), CFrame.new(cab), CRANE_YELLOW, Enum.Material.Metal, model)
	decor(
		newPart(
			"CristalGrua",
			Vector3.new(0.2, 1.2, 2.4),
			CFrame.new(cab + Vector3.new(2.05, 0.5, 0)),
			GLASS,
			Enum.Material.Glass,
			model
		)
	)
	local boomFrom = cab + Vector3.new(1.5, 1, 0)
	local boomTo = Vector3.new(32, deckHeight(32) + 19, 4)
	newPart(
		"Pluma",
		Vector3.new(1.1, 1.1, (boomTo - boomFrom).Magnitude),
		CFrame.lookAt((boomFrom + boomTo) / 2, boomTo),
		CRANE_YELLOW,
		Enum.Material.Metal,
		model
	)
	decor(cylinder("CableGrua", 0.12, boomTo, boomTo - Vector3.new(0, 9, 0), IRON, Enum.Material.Metal, model))
	newPart(
		"Gancho",
		Vector3.new(0.8, 1.2, 0.8),
		CFrame.new(boomTo - Vector3.new(0, 9.6, 0)),
		IRON,
		Enum.Material.Metal,
		model
	)

	-- Proa: bolardos, molinete y mástil con luz.
	for _, z in { -3.5, 3.5 } do
		for _, dx in { 0, 1.4 } do
			local bitt = newPart(
				"Bolardo",
				Vector3.new(1.2, 1, 1),
				CFrame.new(29.5 + dx, deckHeight(29.5 + dx) + 0.2, z) * CFrame.Angles(0, 0, math.pi / 2),
				IRON,
				Enum.Material.Metal,
				model
			)
			bitt.Shape = Enum.PartType.Cylinder
		end
	end
	newPart(
		"Molinete",
		Vector3.new(2.4, 1.4, 4),
		CFrame.new(33, deckHeight(33) + 0.4, 0),
		IRON,
		Enum.Material.Metal,
		model
	)
	local foremast = Vector3.new(27, deckHeight(27), 0)
	newPart(
		"Trinquete",
		Vector3.new(0.7, 11, 0.7),
		CFrame.new(foremast + Vector3.new(0, 5.5, 0)),
		CRANE_YELLOW,
		Enum.Material.Metal,
		model
	)
	local mastLight =
		ball("LuzProa", 0.5, foremast + Vector3.new(0, 11.2, 0), Color3.new(1, 1, 1), Enum.Material.Neon, model)
	broken(decor(mastLight))
end

-- Caja de madera de la carga; algunas con el sello del Proyecto PRIMAL.
local function crate(parent: Instance, cframe: CFrame, size: number, stamped: boolean)
	local box =
		newPart("Caja", Vector3.one * size, cframe, Color3.fromRGB(160, 120, 70), Enum.Material.WoodPlanks, parent)
	for _, offset in { -0.42, 0.42 } do
		decor(
			newPart(
				"Fleje",
				Vector3.new(size + 0.1, size * 0.12, size + 0.1),
				cframe * CFrame.new(0, offset * size, 0),
				DARK_WOOD,
				Enum.Material.Wood,
				parent
			)
		)
	end
	if stamped then
		sign(
			box,
			Enum.NormalId.Front,
			"⚠ PROYECTO PRIMAL\nNO ABRIR",
			Color3.fromRGB(40, 25, 10),
			Enum.Font.SourceSansBold
		)
	end
	return box
end

-- Bidón metálico de 200 litros, de pie o tumbado.
local function drum(parent: Instance, position: Vector3, lying: boolean)
	local cframe = if lying
		then CFrame.new(position + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		else CFrame.new(position + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local color = if rng:NextNumber() < 0.5 then Color3.fromRGB(40, 80, 150) else Color3.fromRGB(170, 45, 35)
	local body = newPart("Bidon", Vector3.new(3.2, 2.2, 2.2), cframe, color, Enum.Material.Metal, parent)
	body.Shape = Enum.PartType.Cylinder
	for _, offset in { -0.6, 0.6 } do
		local hoop = newPart(
			"Aro",
			Vector3.new(0.2, 2.3, 2.3),
			cframe * CFrame.new(offset, 0, 0),
			color:Lerp(Color3.new(0, 0, 0), 0.3),
			Enum.Material.Metal,
			parent
		)
		hoop.Shape = Enum.PartType.Cylinder
		decor(hoop)
	end
end

local function buildHold(model: Model)
	crate(model, CFrame.new(-8, 2.4, 3) * CFrame.Angles(0, 0.3, 0), 3.4, true)
	crate(model, CFrame.new(-11, 2.4, 0.5) * CFrame.Angles(0, -0.2, 0), 3.4, false)
	crate(model, CFrame.new(-9.5, 5.6, 1.5) * CFrame.Angles(0, 0.6, 0.1), 3, false)
	drum(model, Vector3.new(-3, 0.9, 2), false)
	drum(model, Vector3.new(-1, 0.9, -1.5), true)
	-- Bananas de la carga.
	for i = 0, 5 do
		local position = Vector3.new(-5 + (i % 3) * 0.9, 1.5, 4 + math.floor(i / 3) * 0.8)
		decor(
			newPart(
				"Banana",
				Vector3.new(1.4, 0.4, 0.4),
				CFrame.new(position) * CFrame.Angles(0, i, 0.4),
				Color3.fromRGB(240, 210, 60),
				Enum.Material.SmoothPlastic,
				model
			)
		)
	end
	-- Luz de emergencia de la bodega.
	local lamp = newPart(
		"LuzEmergencia",
		Vector3.new(1.2, 0.6, 0.6),
		CFrame.new(-6, 9, 0),
		RESCUE_ORANGE,
		Enum.Material.Neon,
		model
	)
	broken(decor(lamp))
	light(lamp, Color3.fromRGB(255, 150, 80), 16, 1.6)
end

-- Humo que sale de la bodega por el boquete del costado y por la cubierta hundida. Sale hacia
-- donde mira "cframe" (su -Z); "size" es la boca por la que sale.
local function smoke(model: Model, name: string, cframe: CFrame, size: Vector3, rate: number, spread: number)
	local source = newPart(name, size, cframe, IRON, Enum.Material.Metal, model)
	source.Transparency = 1
	decor(source)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Humo"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(60, 56, 54), Color3.fromRGB(125, 118, 112))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.5),
		NumberSequenceKeypoint.new(1, 14),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(spread, spread)
	emitter.Acceleration = Vector3.new(1.2, 1.4, 0.6)
	emitter.RotSpeed = NumberRange.new(-15, 15)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Parent = source
end

local function buildSmoke(model: Model)
	-- Por el boquete: sale hacia la playa (+Z) y sube.
	local breach = hullPoint(-2.4, 2.5, 1)
	smoke(model, "HumoBoquete", CFrame.lookAt(breach, breach + Vector3.new(0, 1, 1.4)), Vector3.new(6, 3, 1), 5, 25)
	-- Por la cubierta hundida, más lento y en columna.
	local hatch = Vector3.new(-2.4, deckHeight(-2.4) - 1, -1)
	smoke(
		model,
		"HumoCubierta",
		CFrame.lookAt(hatch, hatch + Vector3.yAxis, Vector3.zAxis),
		Vector3.new(4, 6, 1),
		3,
		12
	)
end

-- Vacía de arena el interior del casco (el banco de arena se generó también por dentro).
local function carveHull()
	local step = 2 * SHIP_HALF_LENGTH / HULL_SEGMENTS
	for segment = 0, HULL_SEGMENTS - 1 do
		local mid = -SHIP_HALF_LENGTH + (segment + 0.5) * step
		for row = 0, HULL_ROWS + 2 do
			local width = 2 * halfBeam(mid, math.min(row + 0.5, HULL_ROWS)) - 1.6
			Workspace.Terrain:FillBlock(
				SHIP_FRAME * CFrame.new(mid, 1 + (row + 0.5) * ROW_HEIGHT, 0),
				Vector3.new(step + 0.5, ROW_HEIGHT + 0.2, math.max(1, width)),
				Enum.Material.Air
			)
		end
	end
end

local function buildShip(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Esperanza"
	buildHull(model)
	buildDeck(model)
	buildSuperstructure(model)
	buildCargo(model)
	buildHold(model)
	buildSmoke(model)
	local origin = newPart("Pivote", Vector3.one, CFrame.new(), IRON, Enum.Material.Metal, model)
	origin.Transparency = 1
	decor(origin)
	model.PrimaryPart = origin
	model:PivotTo(SHIP_FRAME)
	model.Parent = parent
	return model
end

---------------------------------------------------------------------------------------------------
-- Playa

local function buildPalm(parent: Instance, ground: Vector3, lean: number, yaw: number)
	local palm = Instance.new("Model")
	palm.Name = "Palmera"
	local frame = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	for _ = 1, 4 do
		frame *= CFrame.Angles(lean, 0, 0)
		newPart(
			"Tronco",
			Vector3.new(1.5, 5, 1.5),
			frame * CFrame.new(0, 2.5, 0),
			Color3.fromRGB(150, 115, 70),
			Enum.Material.Wood,
			palm
		)
		frame *= CFrame.new(0, 5, 0)
	end
	for i = 0, 6 do
		decor(
			newPart(
				"Hoja",
				Vector3.new(1.8, 0.3, 9),
				frame
					* CFrame.Angles(0, i * 2 * math.pi / 7, 0)
					* CFrame.Angles(math.rad(-22), 0, 0)
					* CFrame.new(0, 0, -4.4),
				LEAF,
				Enum.Material.Grass,
				palm
			)
		)
	end
	for i = 0, 2 do
		decor(
			ball(
				"Coco",
				1.2,
				(frame * CFrame.new((i - 1) * 0.9, -0.8, 0.5)).Position,
				Color3.fromRGB(90, 60, 30),
				Enum.Material.Wood,
				palm
			)
		)
	end
	palm.Parent = parent
end

local function buildCamp(parent: Instance)
	local camp = Instance.new("Model")
	camp.Name = "Campamento"
	-- Hoguera con leña de deriva.
	local fireAt = groundAt(CAMPFIRE_AT.X, CAMPFIRE_AT.Y)
	for i = 0, 7 do
		local angle = i * math.pi / 4
		ball(
			"Piedra",
			1.4,
			fireAt + Vector3.new(math.cos(angle) * 2.6, 0.4, math.sin(angle) * 2.6),
			Color3.fromRGB(110, 105, 100),
			Enum.Material.Slate,
			camp
		)
	end
	for i = 0, 2 do
		local angle = i * 2 * math.pi / 3
		local tip = fireAt + Vector3.new(0, 2.2, 0)
		local foot = fireAt + Vector3.new(math.cos(angle) * 1.8, 0.2, math.sin(angle) * 1.8)
		cylinder("Leña", 0.6, foot, tip, Color3.fromRGB(90, 60, 35), Enum.Material.Wood, camp)
	end
	local embers = newPart(
		"Brasas",
		Vector3.new(2.2, 0.4, 2.2),
		CFrame.new(fireAt + Vector3.new(0, 0.3, 0)),
		Color3.fromRGB(255, 120, 40),
		Enum.Material.Neon,
		camp
	)
	decor(embers)
	local flame = Instance.new("Fire")
	flame.Size = 6
	flame.Heat = 9
	flame.Parent = embers
	light(embers, FIRE_LIGHT, 30, 3)
	-- Troncos para sentarse y un bidón como mesa.
	for i = 0, 2 do
		local angle = i * 2 * math.pi / 3 + 0.5
		local center = fireAt + Vector3.new(math.cos(angle) * 7, 0.8, math.sin(angle) * 7)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		cylinder(
			"Banco",
			1.6,
			center - tangent * 2.5,
			center + tangent * 2.5,
			Color3.fromRGB(110, 75, 45),
			Enum.Material.Wood,
			camp
		)
	end
	drum(camp, fireAt + Vector3.new(-6.5, 0, 4), false)

	-- El resto del campamento, abajo a la izquierda, fuera de la plaza: tienda de lona azul sobre dos
	-- postes de aluminio.
	local tentAt = groundAt(-28, 28)
	local tentFrame = CFrame.new(tentAt) * CFrame.Angles(0, math.rad(20), 0)
	for _, dx in { -5, 5 } do
		newPart(
			"PosteTienda",
			Vector3.new(0.4, 7, 0.4),
			tentFrame * CFrame.new(dx, 3.5, 0),
			ALUMINIUM,
			Enum.Material.Metal,
			camp
		)
	end
	cylinder(
		"Cuerda",
		0.2,
		(tentFrame * CFrame.new(-5.2, 6.8, 0)).Position,
		(tentFrame * CFrame.new(5.2, 6.8, 0)).Position,
		Color3.fromRGB(200, 200, 190),
		Enum.Material.Fabric,
		camp
	)
	for _, side in { -1, 1 } do
		decor(
			newPart(
				"Lona",
				Vector3.new(11.5, 0.2, 8.4),
				tentFrame * CFrame.new(0, 3.6, side * 3.3) * CFrame.Angles(side * math.rad(-50), 0, 0),
				TARP,
				Enum.Material.Fabric,
				camp
			)
		)
	end
	crate(camp, tentFrame * CFrame.new(-2, 1.3, 0), 2.6, false)
	drum(camp, (tentFrame * CFrame.new(2.5, 0, 0.5)).Position, false)

	-- Contenedores varados en la arena: uno volcado y medio enterrado, otro abierto con la carga
	-- desparramada.
	local tipped = groundAt(-44, 24)
	container(
		camp,
		CFrame.new(tipped + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0.45, 0) * CFrame.Angles(math.rad(82), 0, 0),
		CONTAINER_COLORS[2],
		"PRIMAL",
		Enum.NormalId.Front
	)
	local openAt = groundAt(-58, 8)
	local openFrame = CFrame.new(openAt + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, math.rad(-35), math.rad(-3))
	container(camp, openFrame, CONTAINER_COLORS[1], nil, nil, true)
	local mouth = openFrame * CFrame.new(9, 0, 0)
	crate(camp, CFrame.new(groundAt(mouth.X, mouth.Z) + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, 0.5, 0.1), 2.8, true)
	crate(
		camp,
		CFrame.new(groundAt(mouth.X + 3, mouth.Z + 2.5) + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0.2, -0.4, 0),
		2.2,
		false
	)
	drum(camp, groundAt(mouth.X - 1, mouth.Z + 4), true)

	-- Más carga por la playa: junto al campamento y detrás del cartel de roles, cerca de la lancha.
	crate(camp, CFrame.new(groundAt(40, -36) + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0.9, 0.15), 2.4, false)
	drum(camp, groundAt(-34, 36), true)
	drum(camp, groundAt(46, -36), true)

	-- Ancla moderna (sin cepo) en la arena, detrás de la bitácora, unida a la proa por la cadena.
	local anchorAt = groundAt(2, -47)
	local anchorFrame = CFrame.new(anchorAt) * CFrame.Angles(0, 0.6, 0.3)
	newPart("Caña", Vector3.new(0.9, 7, 0.9), anchorFrame * CFrame.new(0, 3, 0), IRON, Enum.Material.Metal, camp)
	newPart("Corona", Vector3.new(1.6, 1, 3.2), anchorFrame * CFrame.new(0, 0, 0), IRON, Enum.Material.Metal, camp)
	for _, side in { -1, 1 } do
		newPart(
			"Una",
			Vector3.new(1.2, 3, 1),
			anchorFrame * CFrame.new(0, 1.2, side * 1.6) * CFrame.Angles(side * math.rad(-25), 0, 0),
			IRON,
			Enum.Material.Metal,
			camp
		)
	end
	local shackle = (anchorFrame * CFrame.new(0, 6.8, 0)).Position
	local hawse = SHIP_FRAME * (hullPoint(32, HULL_ROWS - 0.6, 1) + Vector3.new(0, 0, 0.6))
	local links = 22
	local function chainPoint(t: number): Vector3
		return hawse:Lerp(shackle, t) - Vector3.new(0, math.sin(t * math.pi) * 3, 0)
	end
	for i = 0, links - 1 do
		local link = cylinder(
			"Cadena",
			if i % 2 == 0 then 0.55 else 0.4,
			chainPoint(i / links),
			chainPoint((i + 1) / links),
			IRON,
			Enum.Material.Metal,
			camp
		)
		decor(link)
	end

	camp.Parent = parent
end

-- Lancha neumática de rescate en la orilla, apuntando a la isla: con su aviso se viaja a la partida.
local function buildLifeboat(parent: Instance)
	local boat = Instance.new("Model")
	boat.Name = "Lancha"
	local at = Vector3.new(34, SEA_LEVEL + 0.2, -48)
	local toIsland = (ISLAND_CENTER - at) * Vector3.new(1, 0, 1)
	-- La proa (-Z local) mira a la isla.
	local frame = CFrame.lookAt(at, at + toIsland.Unit) * CFrame.Angles(math.rad(3), 0, math.rad(2))
	local function point(x: number, y: number, z: number): Vector3
		return (frame * CFrame.new(x, y, z)).Position
	end
	-- Flotadores: rectos a los lados y cerrándose en la proa.
	for _, side in { -1, 1 } do
		cylinder(
			"Flotador",
			1.6,
			point(side * 2.2, 0.9, 5.2),
			point(side * 2.2, 0.9, -2.5),
			RESCUE_ORANGE,
			Enum.Material.Fabric,
			boat
		)
		cylinder(
			"Flotador",
			1.6,
			point(side * 2.2, 0.9, -2.5),
			point(0, 1.1, -6.2),
			RESCUE_ORANGE,
			Enum.Material.Fabric,
			boat
		)
		ball("Tapa", 1.6, point(side * 2.2, 0.9, 5.2), RESCUE_ORANGE, Enum.Material.Fabric, boat)
		-- Cabo de agarre a lo largo del flotador.
		decor(
			cylinder(
				"Cabo",
				0.15,
				point(side * 2.9, 1.4, 4),
				point(side * 2.9, 1.4, -2),
				WHITE_PAINT,
				Enum.Material.Fabric,
				boat
			)
		)
	end
	ball("ProaLancha", 1.8, point(0, 1.1, -6.2), RESCUE_ORANGE, Enum.Material.Fabric, boat)
	newPart(
		"FondoLancha",
		Vector3.new(3.6, 0.4, 10.5),
		frame * CFrame.new(0, 0.4, -0.3),
		Color3.fromRGB(70, 75, 80),
		Enum.Material.Metal,
		boat
	)
	newPart(
		"Espejo",
		Vector3.new(4.2, 1.6, 0.4),
		frame * CFrame.new(0, 1, 5.4),
		Color3.fromRGB(50, 50, 55),
		Enum.Material.Metal,
		boat
	)
	-- Consola con parabrisas y volante.
	newPart(
		"Consola",
		Vector3.new(1.4, 1.6, 1.1),
		frame * CFrame.new(0, 1.4, 0.5),
		WHITE_PAINT,
		Enum.Material.SmoothPlastic,
		boat
	)
	decor(
		newPart(
			"Parabrisas",
			Vector3.new(1.4, 0.8, 0.1),
			frame * CFrame.new(0, 2.6, 0.05) * CFrame.Angles(math.rad(-20), 0, 0),
			GLASS,
			Enum.Material.Glass,
			boat
		)
	)
	local wheel = newPart(
		"Volante",
		Vector3.new(0.15, 0.9, 0.9),
		frame * CFrame.new(0, 2.3, 1.1) * CFrame.Angles(0, math.pi / 2, math.rad(30)),
		Color3.fromRGB(30, 30, 30),
		Enum.Material.SmoothPlastic,
		boat
	)
	wheel.Shape = Enum.PartType.Cylinder
	newPart(
		"Asiento",
		Vector3.new(2.4, 0.9, 1.2),
		frame * CFrame.new(0, 1.05, 2.6),
		Color3.fromRGB(40, 40, 45),
		Enum.Material.Fabric,
		boat
	)
	-- Motor fueraborda.
	newPart(
		"Motor",
		Vector3.new(1.1, 1.6, 1.3),
		frame * CFrame.new(0, 2.2, 6),
		Color3.fromRGB(25, 25, 28),
		Enum.Material.SmoothPlastic,
		boat
	)
	newPart(
		"FranjaMotor",
		Vector3.new(1.15, 0.3, 1.35),
		frame * CFrame.new(0, 2.4, 6),
		RESCUE_ORANGE,
		Enum.Material.SmoothPlastic,
		boat
	)
	newPart(
		"Pie",
		Vector3.new(0.4, 2.2, 0.5),
		frame * CFrame.new(0, 0.5, 6.1),
		Color3.fromRGB(25, 25, 28),
		Enum.Material.Metal,
		boat
	)
	-- Luz de navegación en un mástil corto.
	newPart(
		"MastilLancha",
		Vector3.new(0.2, 2.4, 0.2),
		frame * CFrame.new(0, 3.2, 3.4),
		ALUMINIUM,
		Enum.Material.Metal,
		boat
	)
	local lamp = ball("LuzLancha", 0.5, point(0, 4.5, 3.4), Color3.new(1, 1, 1), Enum.Material.Neon, boat)
	decor(lamp)
	light(lamp, LANTERN_LIGHT, 18, 2)

	-- Aviso para zarpar (el Lobby lo trata como el botón "Ir a la Isla").
	local promptAnchor =
		newPart("Amarre", Vector3.new(2, 2, 2), frame * CFrame.new(0, 2, 1.5), DARK_WOOD, Enum.Material.Wood, boat)
	promptAnchor.Transparency = 1
	decor(promptAnchor)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZarparPrompt"
	prompt.ActionText = `Zarpar a la {Config.PlaceNames.IslandShort}`
	prompt.ObjectText = "Lancha de rescate"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAnchor

	-- Cartelito en la orilla, de cara a la plaza.
	smallSign(boat, LIFEBOAT_SIGN_AT, `🚤 {string.upper(Config.PlaceNames.IslandShort)} →`)
	boat.Parent = parent
end

-- Embarcadero de madera hacia la Isla de las Dunas con un velero del desierto amarrado al final: casco
-- de madera, vela latina color arena con un sol, banderines de los dos equipos (🐆 naranja y 🦜 azul)
-- y un farol. Con su aviso ("ZarparDunasPrompt") se abre la pestaña Arena del menú.
local function buildDunesDock(parent: Instance)
	local dock = Instance.new("Model")
	dock.Name = "EmbarcaderoDunas"
	local from = Vector3.new(DUNES_PIER_FROM.X, DUNES_PIER_DECK, DUNES_PIER_FROM.Y)
	local toDunes = ((DUNES_CENTER - from) * Vector3.new(1, 0, 1)).Unit
	local pier = CFrame.lookAt(from, from + toDunes)
	-- Tablones de la pasarela (a lo largo de -Z local) y pilotes clavados en el fondo.
	local planks = math.floor(DUNES_PIER_LENGTH / 1.2)
	for index = 0, planks - 1 do
		newPart(
			"Tablon",
			Vector3.new(4, 0.3, 1.1),
			pier * CFrame.new(0, 0, -(index + 0.5) * 1.2) * CFrame.Angles(0, math.rad(rng:NextNumber(-1.5, 1.5)), 0),
			tone(PLANK),
			Enum.Material.WoodPlanks,
			dock
		)
	end
	for along = 0, DUNES_PIER_LENGTH, 6 do
		for _, side in { -1, 1 } do
			local top = (pier * CFrame.new(side * 1.9, 0.6, -along)).Position
			cylinder("Pilote", 0.5, top, top - Vector3.new(0, 10, 0), DARK_WOOD, Enum.Material.Wood, dock)
		end
	end

	-- Velero, con la proa (-Z local) hacia las Dunas.
	local at = (pier * CFrame.new(3.6, -DUNES_PIER_DECK + SEA_LEVEL + 0.2, -DUNES_PIER_LENGTH + 2)).Position
	local frame = CFrame.lookAt(at, at + toDunes) * CFrame.Angles(math.rad(2), 0, math.rad(-3))
	local hullWood = Color3.fromRGB(120, 78, 44)
	newPart(
		"Casco",
		Vector3.new(3.6, 1.4, 9),
		frame * CFrame.new(0, 0.7, 0.5),
		hullWood,
		Enum.Material.WoodPlanks,
		dock
	)
	newPart(
		"Proa",
		Vector3.new(2.6, 1.4, 2.6),
		frame * CFrame.new(0, 0.7, -4) * CFrame.Angles(0, math.rad(45), 0),
		hullWood,
		Enum.Material.WoodPlanks,
		dock
	)
	for _, side in { -1, 1 } do
		newPart(
			"Borda",
			Vector3.new(0.3, 0.4, 9),
			frame * CFrame.new(side * 1.85, 1.6, 0.5),
			DARK_WOOD,
			Enum.Material.Wood,
			dock
		)
	end
	newPart("Bancada", Vector3.new(3.4, 0.3, 1), frame * CFrame.new(0, 1.4, 2.5), PLANK, Enum.Material.Wood, dock)
	local mastFoot = (frame * CFrame.new(0, 1.4, -1)).Position
	local mastTop = (frame * CFrame.new(0, 13.5, -1)).Position
	cylinder("Mastil", 0.35, mastFoot, mastTop, DARK_WOOD, Enum.Material.Wood, dock)
	-- Vela latina: una verga inclinada y la vela color arena colgando de ella, con un sol pintado.
	local yardLow = (frame * CFrame.new(0, 2.6, -4.6)).Position
	local yardHigh = (frame * CFrame.new(0, 12.5, 2.2)).Position
	cylinder("Verga", 0.25, yardLow, yardHigh, DARK_WOOD, Enum.Material.Wood, dock)
	local sailCenter = frame * CFrame.new(-0.15, 6.6, -0.6) * CFrame.Angles(math.rad(-34), 0, 0)
	local sail = newPart(
		"Vela",
		Vector3.new(0.12, 6.4, 6.2),
		sailCenter,
		Color3.fromRGB(236, 214, 168),
		Enum.Material.Fabric,
		dock
	)
	sail.CastShadow = false
	newPart(
		"FranjaVela",
		Vector3.new(0.14, 0.7, 6.2),
		sailCenter * CFrame.new(0, -2.4, 0),
		Color3.fromRGB(200, 120, 50),
		Enum.Material.Fabric,
		dock
	)
	sign(sail, Enum.NormalId.Right, "☀️", Color3.fromRGB(230, 150, 40), Enum.Font.BuilderSansBold)
	sign(sail, Enum.NormalId.Left, "☀️", Color3.fromRGB(230, 150, 40), Enum.Font.BuilderSansBold)
	-- Banderines de los dos equipos en lo alto del mástil, por encima de la vela.
	for index, color in { Color3.fromRGB(240, 150, 40), Color3.fromRGB(40, 165, 230) } do
		decor(
			newPart(
				"Banderin",
				Vector3.new(0.1, 0.8, 1.6),
				CFrame.new(mastTop) * frame.Rotation * CFrame.new(0, -0.6 - (index - 1) * 1, 0.9),
				color,
				Enum.Material.Fabric,
				dock
			)
		)
	end
	local lamp =
		ball("FarolVelero", 0.6, (frame * CFrame.new(0, 2.4, 4.6)).Position, LANTERN_LIGHT, Enum.Material.Neon, dock)
	decor(lamp)
	light(lamp, LANTERN_LIGHT, 16, 1.5)

	-- Aviso para zarpar: en el extremo de la pasarela, junto al velero.
	local promptAnchor = newPart(
		"AmarreDunas",
		Vector3.new(2, 2, 2),
		pier * CFrame.new(0, 1.5, -DUNES_PIER_LENGTH + 1.5),
		DARK_WOOD,
		Enum.Material.Wood,
		dock
	)
	promptAnchor.Transparency = 1
	decor(promptAnchor)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZarparDunasPrompt"
	prompt.ActionText = `Zarpar a la {Config.PlaceNames.DunasShort}`
	prompt.ObjectText = "Velero de la arena"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAnchor

	-- Cartelito a la entrada de la pasarela, en la arena y de cara a la plaza.
	local signAt = (pier * CFrame.new(-4.5, 0, -0.6)).Position
	smallSign(dock, Vector2.new(signAt.X, signAt.Z), `🎖️ {string.upper(Config.PlaceNames.DunasShort)} →`)
	dock.Parent = parent
end

-- Pasarela metálica de la arena a la cubierta (por el hueco de la barandilla).
local function buildRamp(parent: Instance, ship: Model)
	local shipFrame = ship:GetPivot()
	local step = 2 * SHIP_HALF_LENGTH / HULL_SEGMENTS
	local x = -SHIP_HALF_LENGTH + 3.5 * step
	local top = shipFrame * (hullPoint(x, HULL_ROWS, 1) + Vector3.new(0, 0.2, -1.2))
	local outward = (shipFrame.ZVector * Vector3.new(1, 0, 1)).Unit
	local footXZ = top + outward * 16
	local foot = groundAt(footXZ.X, footXZ.Z) + Vector3.new(0, 0.3, 0)
	local length = (top - foot).Magnitude
	local ramp = newPart(
		"Pasarela",
		Vector3.new(4, 0.5, length + 1),
		CFrame.lookAt((top + foot) / 2, top),
		ALUMINIUM,
		Enum.Material.DiamondPlate,
		parent
	)
	for i = 1, math.floor(length / 1.5) do
		decor(
			newPart(
				"Peldaño",
				Vector3.new(4, 0.2, 0.25),
				ramp.CFrame * CFrame.new(0, 0.35, length / 2 - i * 1.5),
				Color3.fromRGB(120, 125, 130),
				Enum.Material.Metal,
				parent
			)
		)
	end
	-- Pasamanos a los dos lados.
	for _, side in { -1, 1 } do
		local low = (ramp.CFrame * CFrame.new(side * 2, 1.6, length / 2)).Position
		local high = (ramp.CFrame * CFrame.new(side * 2, 1.6, -length / 2)).Position
		decor(cylinder("Pasamanos", 0.2, low, high, RAIL, Enum.Material.Metal, parent))
		for _, z in { length / 2, 0, -length / 2 } do
			decor(
				newPart(
					"PostePasarela",
					Vector3.new(0.2, 1.6, 0.2),
					ramp.CFrame * CFrame.new(side * 2, 0.8, z),
					RAIL,
					Enum.Material.Metal,
					parent
				)
			)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Archipiélago: las otras islas, cerradas por ahora. Nadie llega a ellas, así que todo es decorado
-- sin colisión y de piezas grandes, para que su silueta se lea desde el banco de arena.

local CONCRETE = Color3.fromRGB(150, 148, 140)
local CONCRETE_DARK = Color3.fromRGB(40, 44, 42)
local JUNGLE_LEAVES = {
	Color3.fromRGB(46, 105, 45),
	Color3.fromRGB(62, 128, 50),
	Color3.fromRGB(36, 86, 40),
}
local TRUNK = Color3.fromRGB(85, 62, 40)
local SANDSTONE = Color3.fromRGB(205, 140, 85)
local CACTUS = Color3.fromRGB(70, 120, 60)
local SKULL_STONE = Color3.fromRGB(178, 168, 150)
local LIMESTONE = Color3.fromRGB(125, 128, 116)
local SKULL_DARK = Color3.fromRGB(18, 14, 14)
local BONE = Color3.fromRGB(215, 205, 175)
local EYE_GLOW = Color3.fromRGB(255, 140, 40)
local WATERFALL = Color3.fromRGB(215, 235, 250)

local function leafColor(): Color3
	return JUNGLE_LEAVES[rng:NextInteger(1, #JUNGLE_LEAVES)]
end

-- Dirección horizontal de "from" hacia el Lobby (el origen).
local function towardLobby(from: Vector3): Vector3
	return ((Vector3.zero - from) * Vector3.new(1, 0, 1)).Unit
end

-- Desvío lateral de la capa "t" de un monte con "wobble" (para que no sea un cono perfecto).
local function mountDrift(center: Vector3, t: number, wobble: number): Vector3
	return Vector3.new(math.noise(t * 3, center.X / 97, 0.5), 0, math.noise(t * 3, center.Z / 97, 7.5)) * wobble
end

-- Monte de terreno por capas, del fondo del mar a la altura "top": el radio pasa de "baseRadius" a
-- "topRadius" con la curva "curve" (como el volcán). Devuelve el centro de la cima.
local function terrainMount(
	center: Vector3,
	baseRadius: number,
	topRadius: number,
	top: number,
	curve: number,
	materialAt: (t: number) -> Enum.Material,
	wobble: number?
): Vector3
	local steps = math.max(8, math.ceil((top - SEA_FLOOR) / 6))
	local layerHeight = (top - SEA_FLOOR) / steps
	for i = 0, steps - 1 do
		local t = i / steps
		local radius = topRadius + (baseRadius - topRadius) * (1 - t) ^ curve
		local drift = if wobble then mountDrift(center, t, wobble) else Vector3.zero
		Workspace.Terrain:FillCylinder(
			CFrame.new(center.X + drift.X, SEA_FLOOR + (i + 0.5) * layerHeight, center.Z + drift.Z),
			layerHeight + 1,
			radius,
			materialAt(t)
		)
	end
	local drift = if wobble then mountDrift(center, 1, wobble) else Vector3.zero
	return Vector3.new(center.X + drift.X, top, center.Z + drift.Z)
end

-- Altura de un terrainMount sin "wobble" a "r" studs de su centro.
local function mountHeight(r: number, baseRadius: number, topRadius: number, top: number, curve: number): number
	local k = math.clamp((r - topRadius) / (baseRadius - topRadius), 0, 1)
	return SEA_FLOOR + (1 - k ^ (1 / curve)) * (top - SEA_FLOOR)
end

-- Bloque estirado entre dos puntos: ancho en X y grueso en Y (con Y hacia "up").
local function beam(
	name: string,
	from: Vector3,
	to: Vector3,
	width: number,
	thickness: number,
	up: Vector3,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): BasePart
	return decor(
		newPart(
			name,
			Vector3.new(width, thickness, (to - from).Magnitude),
			CFrame.lookAt((from + to) / 2, to, up),
			color,
			material,
			parent
		)
	)
end

-- Árbol de selva visto de lejos: tronco y copa de tres bolas.
local function jungleTree(parent: Instance, ground: Vector3, height: number)
	local crown = ground + Vector3.new(0, height * 0.8, 0)
	decor(cylinder("Tronco", height / 9, ground - Vector3.new(0, 2, 0), crown, TRUNK, Enum.Material.Wood, parent))
	for _ = 1, 3 do
		local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 0.4), rng:NextNumber(-1, 1))
		decor(
			ball(
				"Copa",
				height * rng:NextNumber(0.45, 0.65),
				crown + offset * height * 0.22,
				leafColor(),
				Enum.Material.Grass,
				parent
			)
		)
	end
end

-- Lianas que cuelgan de un borde: "frame" en el borde, -Z hacia fuera y X a lo largo de él.
local function vines(parent: Instance, frame: CFrame, along: number, count: number, maxLength: number)
	for _ = 1, count do
		local length = rng:NextNumber(0.3, 1) * maxLength
		decor(
			newPart(
				"Liana",
				Vector3.new(rng:NextNumber(1.5, 3), length, 1),
				frame * CFrame.new(rng:NextNumber(-0.45, 0.45) * along, -length / 2, -0.6),
				leafColor(),
				Enum.Material.Grass,
				parent
			)
		)
	end
end

-- Edificio en ruinas tragado por la selva: bandas oscuras de ventanas (algunas ya cubiertas de
-- hojas), la cima rota con hierros asomando, lianas por las fachadas y matas en la azotea. "frame"
-- es el centro de la base y puede ir inclinado.
local function ruinedTower(parent: Instance, frame: CFrame, size: Vector3)
	local width, height, depth = size.X, size.Y, size.Z
	decor(
		newPart(
			"Bloque",
			size,
			frame * CFrame.new(0, height / 2 - 4, 0),
			tone(CONCRETE),
			Enum.Material.Concrete,
			parent
		)
	)
	local roof = height - 4
	local function face(index: number): (CFrame, number)
		local along = if index % 2 == 0 then width else depth
		local out = (if index % 2 == 0 then depth else width) / 2
		return frame * CFrame.Angles(0, index * math.pi / 2, 0) * CFrame.new(0, 0, -out), along
	end
	for y = 7, roof - 6, 7 do
		for index = 0, 3 do
			local faceFrame, along = face(index)
			local overgrown = rng:NextNumber() < 0.4
			decor(
				newPart(
					"Ventanas",
					Vector3.new(along - 3, 3, 0.8),
					faceFrame * CFrame.new(0, y - 4, 0),
					if overgrown then leafColor() else CONCRETE_DARK,
					if overgrown then Enum.Material.Grass else Enum.Material.Slate,
					parent
				)
			)
		end
	end
	-- Cima rota: trozos de muro de alturas distintas y varillas de hierro.
	for _ = 1, 4 do
		local w = rng:NextNumber(0.2, 0.45) * width
		local d = rng:NextNumber(0.2, 0.45) * depth
		local h = rng:NextNumber(3, 12)
		decor(
			newPart(
				"Escombro",
				Vector3.new(w, h, d),
				frame
					* CFrame.new(
						rng:NextNumber(-1, 1) * (width - w) / 2,
						roof + h / 2,
						rng:NextNumber(-1, 1) * (depth - d) / 2
					)
					* CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)),
				tone(CONCRETE),
				Enum.Material.Concrete,
				parent
			)
		)
	end
	for _ = 1, 3 do
		local x = rng:NextNumber(-0.45, 0.45) * width
		local z = rng:NextNumber(-0.45, 0.45) * depth
		decor(
			cylinder(
				"Hierro",
				1.4,
				(frame * CFrame.new(x, roof, z)).Position,
				(frame * CFrame.new(x + rng:NextNumber(-4, 4), roof + rng:NextNumber(8, 16), z + rng:NextNumber(-4, 4))).Position,
				RUST,
				Enum.Material.CorrodedMetal,
				parent
			)
		)
	end
	for _ = 1, 2 do
		decor(
			ball(
				"Mata",
				math.min(width, depth) * rng:NextNumber(0.35, 0.55),
				(frame * CFrame.new(rng:NextNumber(-0.3, 0.3) * width, roof, rng:NextNumber(-0.3, 0.3) * depth)).Position,
				leafColor(),
				Enum.Material.Grass,
				parent
			)
		)
	end
	-- Lianas y matas de musgo agarradas a las fachadas.
	for index = 0, 3 do
		local faceFrame, along = face(index)
		vines(parent, faceFrame * CFrame.new(0, roof, 0), along, rng:NextInteger(2, 4), height * 0.8)
		for _ = 1, 2 do
			decor(
				ball(
					"Musgo",
					math.min(width, depth) * rng:NextNumber(0.3, 0.5),
					(faceFrame * CFrame.new(rng:NextNumber(-0.4, 0.4) * along, rng:NextNumber(0.1, 0.9) * roof, 0)).Position,
					leafColor(),
					Enum.Material.Grass,
					parent
				)
			)
		end
	end
end

-- Isla de la Ciudad Perdida: rascacielos rotos, inclinados o tumbados, y un paso elevado partido,
-- todo comido por la selva.
local function buildRuinsIsland(parent: Instance)
	local island = Instance.new("Model")
	island.Name = "CiudadPerdida"
	local center = RUINS_CENTER
	local plateau = 12
	terrainMount(center, 230, 165, plateau, 2.2, function(t)
		return if t < 0.75 then Enum.Material.Sand else Enum.Material.LeafyGrass
	end)
	local hill = { center = center + Vector3.new(-95, 0, -70), base = 120, top = 25, height = 58, curve = 1.5 }
	terrainMount(hill.center, hill.base, hill.top, hill.height, hill.curve, function()
		return Enum.Material.LeafyGrass
	end)

	local front = towardLobby(center)
	local side = Vector3.new(-front.Z, 0, front.X)
	local ground = center + Vector3.new(0, plateau, 0)
	for _, tower in
		{
			{ x = 20, z = 10, size = Vector3.new(26, 92, 22), yaw = 0.3, tiltX = 0.02, tiltZ = 0.1 },
			{ x = -30, z = -20, size = Vector3.new(30, 118, 30), yaw = 0.1, tiltX = -0.05, tiltZ = 0 },
			{ x = 55, z = -35, size = Vector3.new(22, 74, 22), yaw = 0.8, tiltX = 0, tiltZ = -0.24 },
			{ x = -70, z = 40, size = Vector3.new(34, 56, 26), yaw = 0.5, tiltX = 0.04, tiltZ = 0.03 },
			{ x = 10, z = 70, size = Vector3.new(20, 46, 20), yaw = 1.2, tiltX = 0.08, tiltZ = 0 },
			{ x = -5, z = -75, size = Vector3.new(24, 80, 24), yaw = 0.6, tiltX = 0, tiltZ = 0.05 },
			-- Tumbado entre los árboles.
			{ x = 75, z = 45, size = Vector3.new(18, 64, 18), yaw = 2.3, tiltX = 1.4, tiltZ = 0 },
		}
	do
		local base = ground + Vector3.new(tower.x, if tower.tiltX > 1 then tower.size.Z / 2 - 2 else 0, tower.z)
		ruinedTower(
			island,
			CFrame.new(base) * CFrame.Angles(0, tower.yaw, 0) * CFrame.Angles(tower.tiltX, 0, tower.tiltZ),
			tower.size
		)
	end

	-- Paso elevado de autopista en la orilla, partido: un tramo vuela sobre el vacío y el otro se
	-- ha caído con un extremo en el suelo.
	local road = ground + front * 128
	local deckY = Vector3.new(0, 34, 0)
	for _, s in { -70, -30, 30 } do
		decor(
			newPart(
				"Pilar",
				Vector3.new(6, 36, 6),
				CFrame.new(road + side * s + Vector3.new(0, 16, 0)),
				tone(CONCRETE),
				Enum.Material.Concrete,
				island
			)
		)
	end
	beam(
		"Calzada",
		road + side * -84 + deckY,
		road + side * -10 + deckY,
		3,
		14,
		front,
		CONCRETE,
		Enum.Material.Concrete,
		island
	)
	beam(
		"CalzadaCaida",
		road + side * 6 + Vector3.new(0, 1, 0),
		road + side * 34 + deckY,
		3,
		14,
		front,
		CONCRETE,
		Enum.Material.Concrete,
		island
	)
	vines(island, CFrame.lookAt(road + side * -47 + deckY, road + side * -47 + deckY + front), 70, 5, 26)

	-- Selva espesa con algunos árboles gigantes que llegan a media altura de las torres.
	for i = 1, 75 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local r = 155 * math.sqrt(rng:NextNumber())
		local height = if i <= 6 then rng:NextNumber(48, 60) else rng:NextNumber(18, 34)
		jungleTree(island, ground + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), height)
	end
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local r = 160 * math.sqrt(rng:NextNumber())
		decor(
			ball(
				"Matorral",
				rng:NextNumber(8, 16),
				ground + Vector3.new(math.cos(angle) * r, 1, math.sin(angle) * r),
				leafColor(),
				Enum.Material.Grass,
				island
			)
		)
	end
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(0, 70)
		local y = mountHeight(r, hill.base, hill.top, hill.height, hill.curve)
		jungleTree(
			island,
			hill.center + Vector3.new(math.cos(angle) * r, y - 1, math.sin(angle) * r),
			rng:NextNumber(24, 38)
		)
	end
	island.Parent = parent
end

-- Altura de la arena de la Isla de las Dunas en (x, z): crestas de duna en diagonal que se apagan
-- hacia la orilla.
local function duneHeight(x: number, z: number): number
	local dx, dz = x - DUNES_CENTER.X, z - DUNES_CENTER.Z
	local r = math.sqrt(dx * dx + dz * dz) / DUNES_RADIUS
	local crest = 1 - math.abs(math.sin((dx * 0.8 + dz * 0.6) / 38 + math.sin(dz / 57) * 1.4))
	local land = 8 + 26 * crest ^ 2 + 6 * math.sin(dx / 83) * math.cos(dz / 67)
	return land + (SEA_FLOOR - 2 - land) * smoothstep(0.6, 1.05, r)
end

-- Saguaro con dos brazos.
local function cactus(parent: Instance, ground: Vector3, height: number)
	local width = height / 6
	local top = ground + Vector3.new(0, height, 0)
	decor(cylinder("Cactus", width, ground - Vector3.new(0, 2, 0), top, CACTUS, Enum.Material.Grass, parent))
	decor(ball("Punta", width, top, CACTUS, Enum.Material.Grass, parent))
	local yaw = rng:NextNumber(0, 2 * math.pi)
	for _, armSide in { -1, 1 } do
		local out = Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * armSide
		local start = ground + Vector3.new(0, height * rng:NextNumber(0.35, 0.55), 0)
		local elbow = start + out * height * 0.22
		local tip = elbow + Vector3.new(0, height * rng:NextNumber(0.25, 0.4), 0)
		decor(cylinder("Brazo", width * 0.75, start, elbow, CACTUS, Enum.Material.Grass, parent))
		decor(ball("Codo", width * 0.75, elbow, CACTUS, Enum.Material.Grass, parent))
		decor(cylinder("Brazo", width * 0.75, elbow, tip, CACTUS, Enum.Material.Grass, parent))
		decor(ball("Punta", width * 0.75, tip, CACTUS, Enum.Material.Grass, parent))
	end
end

-- Isla de las Dunas: desierto de dunas con mesetas de arenisca a franjas, un arco de roca,
-- obeliscos medio enterrados, cactus y arena que vuela.
local function buildDunesIsland(parent: Instance)
	local island = Instance.new("Model")
	island.Name = "Dunas"
	local center = DUNES_CENTER
	local terrain = Workspace.Terrain
	local step = 8
	local reach = DUNES_RADIUS * 1.05
	for x = center.X - reach, center.X + reach, step do
		for z = center.Z - reach, center.Z + reach, step do
			local top = duneHeight(x, z)
			if top > SEA_FLOOR then
				terrain:FillBlock(
					CFrame.new(x, (SEA_FLOOR + top) / 2, z),
					Vector3.new(step, top - SEA_FLOOR, step),
					Enum.Material.Sand
				)
			end
		end
	end

	local front = towardLobby(center)
	local side = Vector3.new(-front.Z, 0, front.X)
	-- Mesetas al fondo (lejos del Lobby), con franjas de roca más oscura.
	for _, mesa in
		{
			{ back = 110, across = -40, radius = 60, top = 96 },
			{ back = 160, across = 80, radius = 44, top = 70 },
			{ back = 40, across = -150, radius = 48, top = 120 },
		}
	do
		terrainMount(
			center - front * mesa.back + side * mesa.across,
			mesa.radius * 1.25,
			mesa.radius,
			mesa.top,
			1,
			function(t)
				return if (t * 7) % 1 < 0.2 then Enum.Material.Ground else Enum.Material.Sandstone
			end
		)
	end

	-- Arco de roca en la orilla, de cara al Lobby: bolas de arenisca a lo largo de medio óvalo,
	-- más gruesas en las patas que arriba.
	local archFoot = center + front * 150 + side * 70
	archFoot = Vector3.new(archFoot.X, math.max(duneHeight(archFoot.X, archFoot.Z), 0) - 6, archFoot.Z)
	local archFrame = CFrame.lookAt(archFoot, archFoot + front)
	local archRadius = 30
	local segments = 24
	for i = 0, segments do
		local angle = math.pi * i / segments
		local point = archFrame * CFrame.new(math.cos(angle) * archRadius, math.sin(angle) * archRadius * 1.5, 0)
		terrain:FillBall(
			point.Position,
			7 + 3 * math.abs(math.cos(angle)) + rng:NextNumber(0, 2),
			Enum.Material.Sandstone
		)
	end

	-- Obeliscos: uno de pie, torcido y medio enterrado, y otro caído y partido.
	local obelisk = center + front * 90 - side * 60
	obelisk = Vector3.new(obelisk.X, duneHeight(obelisk.X, obelisk.Z), obelisk.Z)
	decor(
		newPart(
			"Obelisco",
			Vector3.new(9, 64, 9),
			CFrame.new(obelisk) * CFrame.Angles(0.18, 0.5, -0.12) * CFrame.new(0, 20, 0),
			SANDSTONE,
			Enum.Material.Sandstone,
			island
		)
	)
	local fallen = center + front * 60 + side * 10
	fallen = Vector3.new(fallen.X, duneHeight(fallen.X, fallen.Z) + 2, fallen.Z)
	beam(
		"ObeliscoCaido",
		fallen,
		fallen + side * 34 + Vector3.new(0, 4, 0),
		8,
		8,
		Vector3.yAxis,
		SANDSTONE,
		Enum.Material.Sandstone,
		island
	)
	beam(
		"ObeliscoCaido",
		fallen + side * 38 + Vector3.new(0, 2, 6),
		fallen + side * 56 + Vector3.new(0, -2, 8),
		8,
		8,
		Vector3.yAxis,
		SANDSTONE,
		Enum.Material.Sandstone,
		island
	)

	for _, spot in { -120, -80, -20, 30, 110, 140 } do
		local at = center + front * rng:NextNumber(150, 190) + side * spot
		local ground = Vector3.new(at.X, duneHeight(at.X, at.Z), at.Z)
		if ground.Y > 1 then
			cactus(island, ground, rng:NextNumber(16, 26))
		end
	end

	-- Arena que vuela sobre la isla.
	local dustArea = newPart(
		"Polvareda",
		Vector3.new(DUNES_RADIUS * 1.8, 30, DUNES_RADIUS * 1.8),
		CFrame.new(center + Vector3.new(0, 40, 0)),
		SANDSTONE,
		Enum.Material.SmoothPlastic,
		island
	)
	dustArea.Transparency = 1
	decor(dustArea)
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Arena"
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.Color = ColorSequence.new(Color3.fromRGB(230, 185, 130))
	dust.Size = NumberSequence.new(40, 80)
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(10, 14)
	dust.Rate = 4
	dust.Speed = NumberRange.new(0)
	dust.Acceleration = side * 2
	dust.RotSpeed = NumberRange.new(-8, 8)
	dust.Parent = dustArea
	island.Parent = parent
end

-- Isla Calavera: una roca enorme con forma de cráneo de mono que mira al Lobby, con los ojos
-- encendidos, colmillos, una escalera hasta la boca y dos antorchas.
local function buildSkullIsland(parent: Instance)
	local island = Instance.new("Model")
	island.Name = "Calavera"
	local center = SKULL_CENTER
	local plateau = 18
	terrainMount(center, 170, 70, plateau, 1.6, function(t)
		return if t < 0.6 then Enum.Material.Sand elseif t < 0.85 then Enum.Material.Rock else Enum.Material.LeafyGrass
	end)
	local front = towardLobby(center)
	local side = Vector3.new(-front.Z, 0, front.X)
	local hills = {}
	for _, across in { -85, 85 } do
		local hill = { center = center + side * across - front * 25, base = 85, top = 20, height = 52, curve = 1.4 }
		terrainMount(hill.center, hill.base, hill.top, hill.height, hill.curve, function()
			return Enum.Material.LeafyGrass
		end)
		table.insert(hills, hill)
	end

	local base = center + Vector3.new(0, plateau, 0) - front * 10
	local skull = CFrame.lookAt(base, base + front)
	local function at(x: number, y: number, z: number): CFrame
		return skull * CFrame.new(x, y, z)
	end
	local function stone(name: string, size: Vector3, cframe: CFrame): Part
		local part = newPart(name, size, cframe, tone(SKULL_STONE), Enum.Material.Slate, island)
		decor(part)
		return part
	end
	local function rock(name: string, diameter: number, x: number, y: number, z: number): BasePart
		return decor(ball(name, diameter, at(x, y, z).Position, tone(SKULL_STONE), Enum.Material.Slate, island))
	end
	rock("Craneo", 96, 0, 80, 14)
	-- Hocico redondo que sobresale, barbilla y pómulos.
	rock("Hocico", 54, 0, 30, -30)
	rock("Barbilla", 36, 0, 8, -36)
	for _, x in { -36, 36 } do
		rock("Pomulo", 28, x, 44, -14)
	end
	for _, x in { -19, 19 } do
		-- Ceja: barra redondeada, más baja por dentro (ceño fruncido).
		local brow =
			stone("Ceja", Vector3.new(44, 16, 16), at(x, 66, -34) * CFrame.Angles(0, 0, math.rad(x > 0 and 12 or -12)))
		brow.Shape = Enum.PartType.Cylinder
		-- Cuenca hundida bajo la ceja, con el ojo encendido al fondo.
		local socket = newPart(
			"Cuenca",
			Vector3.new(4, 28, 28),
			at(x, 51, -22) * CFrame.Angles(0, math.pi / 2, 0),
			SKULL_DARK,
			Enum.Material.Slate,
			island
		)
		socket.Shape = Enum.PartType.Cylinder
		decor(socket)
		local eye = decor(ball("Ojo", 7, at(x, 51, -25).Position, EYE_GLOW, Enum.Material.Neon, island))
		light(eye, EYE_GLOW, 50, 4)
		decor(ball("Nariz", 6, at(x * 0.27, 46, -50).Position, SKULL_DARK, Enum.Material.Slate, island))
	end
	-- Boca abierta, dientes y colmillos.
	decor(newPart("Boca", Vector3.new(28, 11, 6), at(0, 19, -54), SKULL_DARK, Enum.Material.Slate, island))
	for x = -9, 9, 6 do
		decor(newPart("Diente", Vector3.new(4, 6, 3), at(x, 23, -57.5), BONE, Enum.Material.Limestone, island))
	end
	for _, x in { -12, 12 } do
		decor(
			newPart(
				"Colmillo",
				Vector3.new(5, 15, 4),
				at(x, 19, -57.5) * CFrame.Angles(0, 0, math.rad(x > 0 and 6 or -6)),
				BONE,
				Enum.Material.Limestone,
				island
			)
		)
	end
	-- Musgo y lianas por la cabeza.
	for _, spot in { Vector3.new(-14, 124, 18), Vector3.new(20, 120, 30), Vector3.new(32, 104, -4) } do
		decor(
			ball(
				"Musgo",
				rng:NextNumber(20, 30),
				at(spot.X, spot.Y, spot.Z).Position,
				leafColor(),
				Enum.Material.Grass,
				island
			)
		)
	end
	vines(island, at(0, 60, -42), 76, 7, 22)
	-- Escalera hasta la boca y antorchas.
	for i = 0, 6 do
		stone("Escalon", Vector3.new(22, 2, 5), at(0, 13 - i * 2, -60 - i * 4.5))
	end
	for _, x in { -16, 16 } do
		local post = stone("Antorcha", Vector3.new(2, 12, 2), at(x, 5, -80))
		local fire = Instance.new("Fire")
		fire.Size = 8
		fire.Heat = 10
		fire.Parent = post
		light(post, FIRE_LIGHT, 30, 3)
	end

	for _ = 1, 20 do
		local hill = hills[rng:NextInteger(1, #hills)]
		local angle = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(0, 55)
		local y = mountHeight(r, hill.base, hill.top, hill.height, hill.curve)
		jungleTree(
			island,
			hill.center + Vector3.new(math.cos(angle) * r, y - 1, math.sin(angle) * r),
			rng:NextNumber(20, 34)
		)
	end
	for _, spot in { -50, -38, 40, 55 } do
		buildPalm(island, base + front * 45 + side * spot - Vector3.new(0, 1, 0), 0.15, rng:NextNumber(0, 6))
	end
	island.Parent = parent
end

-- Picos de la Niebla: agujas de roca caliza con selva en lo alto, una cascada y bandas de niebla.
-- Es la isla más lejana: casi solo se ve su silueta.
local function buildPeaksIsland(parent: Instance)
	local island = Instance.new("Model")
	island.Name = "PicosDeLaNiebla"
	local center = PEAKS_CENTER
	-- Solo estas agujas usan caliza: gris de roca en vez del crema de serie.
	Workspace.Terrain:SetMaterialColor(Enum.Material.Limestone, LIMESTONE)
	terrainMount(center, 270, 200, 4, 2, function(t)
		return if t < 0.8 then Enum.Material.Sand else Enum.Material.LeafyGrass
	end)
	local front = towardLobby(center)
	local mainTop: Vector3? = nil
	local mainRadius = 0
	for index, peak in
		{
			{ x = 0, z = 0, radius = 52, top = 320 },
			{ x = -110, z = 40, radius = 40, top = 230 },
			{ x = 95, z = 55, radius = 38, top = 250 },
			{ x = -60, z = -90, radius = 45, top = 280 },
			{ x = 150, z = -40, radius = 30, top = 170 },
			{ x = -190, z = -30, radius = 32, top = 150 },
			{ x = 45, z = 140, radius = 28, top = 140 },
			{ x = 60, z = -120, radius = 36, top = 210 },
			{ x = -150, z = 120, radius = 26, top = 120 },
		}
	do
		local grassFrom = 1 - 10 / (peak.top - SEA_FLOOR)
		local top = terrainMount(
			center + Vector3.new(peak.x, 0, peak.z),
			peak.radius * 1.25,
			peak.radius * 0.75,
			peak.top,
			1,
			function(t)
				-- Repisas con plantas a distintas alturas de la pared.
				local ledge = t > 0.15 and math.noise(t * 9, peak.x / 50, peak.z / 50) > 0.3
				return if t > grassFrom or ledge then Enum.Material.LeafyGrass else Enum.Material.Limestone
			end,
			peak.radius * 0.6
		)
		Workspace.Terrain:FillBall(
			top - Vector3.new(0, peak.radius * 0.2, 0),
			peak.radius * 0.7,
			Enum.Material.LeafyGrass
		)
		for _ = 1, 3 do
			local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * peak.radius * 0.35
			jungleTree(island, top + offset + Vector3.new(0, peak.radius * 0.4, 0), rng:NextNumber(18, 28))
		end
		if index == 1 then
			mainTop = top
			mainRadius = peak.radius
		end
	end

	-- Cascada por la cara que mira al Lobby, con espuma abajo.
	if mainTop then
		local from = mainTop + front * mainRadius * 0.85 - Vector3.new(0, 30, 0)
		local to = Vector3.new(from.X, 0, from.Z) + front * mainRadius * 0.55
		local fall = beam("Cascada", from, to, 10, 1.5, front, WATERFALL, Enum.Material.SmoothPlastic, island)
		fall.Transparency = 0.2
		local foam = decor(ball("Espuma", 14, to, WATERFALL, Enum.Material.SmoothPlastic, island))
		foam.Transparency = 1
		local spray = Instance.new("ParticleEmitter")
		spray.Name = "Espuma"
		spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
		spray.Color = ColorSequence.new(Color3.new(1, 1, 1))
		spray.Size = NumberSequence.new(12, 30)
		spray.Transparency = NumberSequence.new(0.4, 1)
		spray.Lifetime = NumberRange.new(3, 5)
		spray.Rate = 6
		spray.Speed = NumberRange.new(4, 8)
		spray.SpreadAngle = Vector2.new(60, 60)
		spray.Parent = foam
	end

	-- Bandas de niebla entre las agujas.
	for _, height in { 70, 165 } do
		local band = newPart(
			"Niebla",
			Vector3.new(420, 20, 420),
			CFrame.new(center + Vector3.new(0, height, 0)),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic,
			island
		)
		band.Transparency = 1
		decor(band)
		local mist = Instance.new("ParticleEmitter")
		mist.Name = "Niebla"
		mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
		mist.Shape = Enum.ParticleEmitterShape.Box
		mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		mist.Color = ColorSequence.new(Color3.fromRGB(240, 235, 235))
		mist.Size = NumberSequence.new(60, 110)
		mist.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		mist.Lifetime = NumberRange.new(16, 22)
		mist.Rate = 3
		mist.Speed = NumberRange.new(0)
		mist.Acceleration = Vector3.new(1.5, 0, 0)
		mist.RotSpeed = NumberRange.new(-5, 5)
		mist.Parent = band
	end
	island.Parent = parent
end

local function buildBoundary(parent: Instance)
	local walls = Instance.new("Folder")
	walls.Name = "Limites"
	local count = 28
	for i = 0, count - 1 do
		local angle = i * 2 * math.pi / count
		local position = Vector3.new(BAR_CENTER.X, 30, BAR_CENTER.Y)
			+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * BOUNDARY_RADIUS
		local wall = newPart(
			"Muro",
			Vector3.new(2 * BOUNDARY_RADIUS * math.sin(math.pi / count) + 4, 120, 2),
			CFrame.lookAt(position, Vector3.new(BAR_CENTER.X, 30, BAR_CENTER.Y)),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic,
			walls
		)
		wall.Transparency = 1
		wall.CanQuery = false
	end
	walls.Parent = parent
end

local function buildSpawn(parent: Instance)
	local at = groundAt(SPAWN_AT.X, SPAWN_AT.Y)
	-- De cara a la plaza.
	local toward = Vector3.new(PLAZA.X, at.Y, PLAZA.Y)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Llegada"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.lookAt(at + Vector3.new(0, 0.2, 0), toward)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = parent
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
end

local function setLighting()
	Lighting.ClockTime = 17.6
	Lighting.GeographicLatitude = 20
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(90, 70, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 115, 110)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 190, 140)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	for _, name in { "NaufragioAtmosfera", "NaufragioBrillo", "NaufragioColor", "NaufragioRayos" } do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "NaufragioAtmosfera"
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(255, 190, 150)
	atmosphere.Decay = Color3.fromRGB(130, 85, 110)
	atmosphere.Glare = 0.5
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "NaufragioBrillo"
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "NaufragioColor"
	grade.Saturation = 0.12
	grade.Contrast = 0.06
	grade.TintColor = Color3.fromRGB(255, 240, 225)
	grade.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "NaufragioRayos"
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting
end

local function clearOld()
	local old = Workspace:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	Workspace.Terrain:Clear()
end

-- true si el place ya tiene el escenario de esta versión.
-- Dónde van los muñecos de práctica (en el suelo bajo cada punto) y hacia dónde miran: el centro de
-- la plaza (LobbyDummyService).
function LobbyBuilder.practiceSpots(): ({ Vector3 }, Vector3)
	local spots = {}
	for _, spot in PRACTICE_SPOTS do
		table.insert(spots, Vector3.new(spot.X, BAR_TOP, spot.Y))
	end
	return spots, Vector3.new(PLAZA.X, BAR_TOP, PLAZA.Y)
end

function LobbyBuilder.isBuilt(): boolean
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	return folder ~= nil and folder:GetAttribute("Version") == VERSION
end

function LobbyBuilder.build(options: Options?)
	local force = options and options.force
	if not force and game.PlaceId ~= Config.PlaceIds.Lobby then
		warn(
			`[LobbyBuilder] Este place ({game.PlaceId}) no es el Lobby ({Config.PlaceIds.Lobby}). `
				.. "Abre el Lobby o usa build({ force = true })."
		)
		return
	end
	rng = Random.new(SEED)
	clearOld()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("Version", VERSION)
	buildTerrain()
	local horizon = Instance.new("Folder")
	horizon.Name = "IslaLejana"
	buildIsland(horizon)
	horizon.Parent = folder
	local archipelago = Instance.new("Folder")
	archipelago.Name = "Archipielago"
	buildSkullIsland(archipelago)
	buildRuinsIsland(archipelago)
	buildDunesIsland(archipelago)
	buildPeaksIsland(archipelago)
	archipelago.Parent = folder
	carveHull()
	local ship = buildShip(folder)
	buildRamp(folder, ship)
	buildCamp(folder)
	buildBoards(folder)
	buildNest(folder)
	buildLifeboat(folder)
	buildDunesDock(folder)
	for _, palm in
		{
			{ x = 57, z = -21, lean = 0.12, yaw = 0.4 }, -- detrás del ranking
			{ x = 57, z = 0, lean = 0.18, yaw = 1.9 }, -- entre el ranking y el cartel de la arena
			{ x = -58, z = 26, lean = 0.1, yaw = 3.4 },
			{ x = -70, z = 10, lean = 0.2, yaw = 2.2 },
			{ x = 16, z = 38, lean = 0.08, yaw = 5.1 }, -- en la orilla, junto a la llegada
		}
	do
		buildPalm(folder, groundAt(palm.x, palm.z) - Vector3.new(0, 0.5, 0), palm.lean, palm.yaw)
	end
	buildBoundary(folder)
	buildSpawn(folder)
	folder.Parent = Workspace
	setLighting()
	print("[LobbyBuilder] ¡Naufragio listo!")
end

return LobbyBuilder
