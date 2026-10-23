--!strict
-- Escenario de la arena de Dunas (captura la bandera): ruinas mayas en un cañón del desierto.
--
-- Lo construye solo el servidor de Dunas al arrancar si no existe Workspace.Arena o es de otra
-- versión (ArenaWorldService). Para dejarlo fijo en el place, ejecútalo en Studio, en modo edición,
-- desde la barra de comandos:
--
--   require(game.ServerScriptService.Server.World.ArenaBuilder).build()
--
-- Forma (de oeste a este, el eje X): la base Jaguar (x < 0), el carril central con la pirámide en
-- el centro y la base Quetzal (x > 0). A los dos lados del carril, separados por muros de ruinas,
-- dos pasillos laterales; en 1v1 y 2v2 se cierran (carpeta "SideWalls", ArenaWorldService).
-- - Cada base es el patio de un templo: fachada con arco maya (falsa bóveda) y la máscara del
--   equipo encima de la puerta y, al fondo, una pirámide escalonada sobre un basamento más alto que
--   un salto (es decorado: cierra la arena por ese lado).
-- - Junto a la pirámide del centro, los muros del carril son los de un juego de pelota (talud y
--   aro); de ahí a cada base, muros en ruinas. Una calzada blanca (sacbé) une la plaza con las
--   puertas.
-- - Fuera, paredes de cañón a franjas, y dunas y mesetas en el horizonte.
--
-- Piezas con nombre que lee el código, en Arena/Bases/<equipo>:
--   "Spawn"      baldosa donde reaparecen los del equipo
--   "Gate"       puerta de la base: cerrada antes de la partida
--   "FlagStand"  pedestal de la bandera
--   "Zone"       volumen invisible de la base
-- y en Arena: "SideWalls" (muros que cierran los pasillos; cada hijo es una pieza), un
-- SpawnLocation "EsperaSpawn" en lo alto de la pirámide, donde aparecen los que aún no han elegido
-- equipo, y el modelo "Altar" (Fase 10, C11; AltarService): el altar de la cima, con "Captura" (el
-- centro de la zona que se toma), los "Pilar" con su "Gema", el "Glifo" del suelo y el "Haz" de luz,
-- que colorea cada cliente (AltarController).
-- Coberturas que se rompen (C11; CoverService): las estelas y las columnas de pie son modelos con la
-- etiqueta Config.Combat.DestructibleTag; su zócalo o su basa se quedan fuera del modelo (no se rompen).
--
-- Lo decorativo va con CanCollide, CanQuery y CanTouch en false: el Parpadeo lanza rayos y no debe
-- tropezar con un estandarte. Nada que choque deja subirse a un muro: un salto llega a ~7 studs.
-- Barreras invisibles ("Barrera": chocan, sin rayos) delante de la cara del basamento de cada templo
-- (sus relieves hacían de peldaño) y por los bordes de fuera de su terraza: detrás del templo no hay
-- cañón, y quien llegaba arriba se salía de la arena.
--
-- ⚠️ Borra la carpeta Workspace.Arena, la Baseplate y los SpawnLocation sueltos antes de construir.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

export type Options = { force: boolean? }

local FOLDER_NAME = "Arena"
-- Sube este número al cambiar el escenario: los places con una versión anterior guardada se
-- reconstruyen solos al arrancar (ArenaWorldService).
local VERSION = 5
-- Semilla del decorado al azar (contrafuertes, cactus, dunas): el mismo mapa en cada construcción.
local SEED = 2026

-- Medidas (studs). El suelo está en y = 0.
local HALF_LENGTH = 200 -- de la pared oeste a la este
local HALF_WIDTH = 100 -- de la pared sur a la norte
local BOUNDARY_HEIGHT = 40
local BOUNDARY_THICKNESS = 6
local BASE_INNER_X = 150 -- la pared de la base que mira al centro
local BASE_HALF_WIDTH = 40
local BASE_FLOOR = 2 -- la base está un poco elevada
local BASE_WALL_HEIGHT = 26
local BASE_WALL_THICKNESS = 4
local GATE_HALF_WIDTH = 8
local LANE_WALL_Z = 35 -- muros entre el carril central y los pasillos
local LANE_WALL_HEIGHT = 12
local LANE_WALL_GAP = 30 -- hueco del centro (|x| < esto) que conecta carril y pasillos
local LANE_WALL_END = 130 -- desde aquí hasta la base, otro hueco
local COURT_END = 80 -- el juego de pelota va del hueco del centro hasta aquí
local COURT_WALL_HEIGHT = 14 -- más alto que el resto: desde lo alto del talud no se llega arriba
local PYRAMID_STEP = 4
local PYRAMID_SIZES = { 36, 28, 20, 12 }
local PYRAMID_STAIR_REACH = 24 -- hasta dónde sale la escalinata de la pirámide del centro
-- Templo del fondo de cada base: basamento (no se llega arriba de un salto) y cuatro cuerpos
-- escalonados. Las mitades de los cuerpos quedan detrás de la línea de la escalinata.
local TEMPLE_PLATFORM_HEIGHT = 12
local TEMPLE_DEPTH = 80
local TEMPLE_HALF_SIZES = { 32, 25.5, 18, 12.5 }
local TEMPLE_TIER_HEIGHT = 7
-- Alto de las barreras invisibles (studs, desde su suelo).
local BARRIER_HEIGHT = 80

local SAND = Color3.fromRGB(222, 186, 128)
local LIMESTONE = Color3.fromRGB(196, 178, 140)
local LIMESTONE_LIGHT = Color3.fromRGB(214, 200, 168)
local LIMESTONE_DARK = Color3.fromRGB(132, 114, 90)
local PAVING = Color3.fromRGB(178, 160, 128)
local CANYON = Color3.fromRGB(200, 132, 80)
local CANYON_DARK = Color3.fromRGB(150, 92, 58)
local STUCCO_RED = Color3.fromRGB(160, 58, 42) -- estuco pintado de los santuarios
local SHADOW = Color3.fromRGB(30, 22, 18) -- huecos: puertas, ojos, aros
local BONE = Color3.fromRGB(230, 220, 195)
local CREAM = Color3.fromRGB(240, 220, 175)
local WOOD = Color3.fromRGB(110, 72, 40)
local CACTUS = Color3.fromRGB(70, 120, 60)
local DRY_BUSH = Color3.fromRGB(140, 110, 70)
local FIRE = Color3.fromRGB(255, 140, 40)
local JAGUAR_EYE = Color3.fromRGB(220, 230, 80)
local QUETZAL_GREEN = Color3.fromRGB(40, 160, 90)
local QUETZAL_RED = Color3.fromRGB(200, 45, 45)
local BEAK = Color3.fromRGB(245, 190, 50)

-- Cilindros de pie (el eje de los cilindros de Roblox es X).
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
-- Cilindros mirando a lo largo de Z (discos en una pared que mira a ±Z).
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)

local ArenaBuilder = {}

local rng = Random.new(SEED)

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
	part.Material = material or Enum.Material.Limestone
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Pieza que no se ve ni choca ni la encuentran los rayos (marcas para el código).
local function marker(part: BasePart)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- Barrera invisible: choca con los personajes, pero no la encuentran los rayos (ni la cámara, ni los
-- disparos, ni el Parpadeo).
local function barrier(size: Vector3, cframe: CFrame, parent: Instance)
	local part = block("Barrera", size, cframe, LIMESTONE, nil, parent)
	part.Transparency = 1
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- Cobertura que se rompe (C11): un modelo con la etiqueta de las destructibles (CoverService). Atómico:
-- con StreamingEnabled llega entero a los clientes (CoverController dibuja sus grietas y sus trozos).
local function coverModel(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollectionService:AddTag(model, Config.Combat.DestructibleTag)
	model.Parent = parent
	return model
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

-- Variación de tono para que la piedra repetida no parezca de plástico.
local function tone(color: Color3, amount: number?): Color3
	return color:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, amount or 0.12))
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
	parent: Instance
): Part
	local size = Vector3.new(math.abs(x2 - x1), height, math.abs(z2 - z1))
	local center = Vector3.new((x1 + x2) / 2, bottom + height / 2, (z1 + z2) / 2)
	return block(name, size, CFrame.new(center), color, nil, parent)
end

local function wedge(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

-- Marco que mira de "from" a "to" (su -Z apunta a "to"), también si la línea es vertical.
local function along(from: Vector3, to: Vector3): CFrame
	local direction = (to - from).Unit
	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt((from + to) / 2, to, up)
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
	local part = block(
		name,
		Vector3.new((to - from).Magnitude, diameter, diameter),
		along(from, to) * ALONG_Z,
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
	local part = block(name, Vector3.one * diameter, CFrame.new(position), color, material, parent)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Fuego de un brasero, con una luz corta para que no tiña todo el patio.
local function flame(part: BasePart, color: Color3)
	local fire = Instance.new("Fire")
	fire.Color = color
	fire.SecondaryColor = color:Lerp(Color3.new(1, 1, 1), 0.4)
	fire.Size = 4
	fire.Heat = 8
	fire.Parent = part
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 9
	light.Brightness = 0.8
	light.Parent = part
end

-- Brasero de piedra sobre el suelo "ground". "solid": el pedestal choca (en el suelo de juego).
local function brazier(parent: Instance, ground: Vector3, color: Color3, solid: boolean)
	local pedestal = block(
		"Pebetero",
		Vector3.new(2.2, 3, 2.2),
		CFrame.new(ground + Vector3.new(0, 1.5, 0)),
		LIMESTONE_DARK,
		nil,
		parent
	)
	if not solid then
		decor(pedestal)
	end
	local bowl = block(
		"Cuenco",
		Vector3.new(1, 3.4, 3.4),
		CFrame.new(ground + Vector3.new(0, 3.4, 0)) * UPRIGHT,
		LIMESTONE_DARK:Lerp(SHADOW, 0.3),
		nil,
		parent
	)
	bowl.Shape = Enum.PartType.Cylinder
	decor(bowl)
	flame(bowl, color)
end

-- Estandarte de tela colgado de una vara, con flecos oscuros y un rombo claro. "frame": el centro de
-- la vara, con -Z hacia fuera del muro.
local function banner(parent: Instance, frame: CFrame, width: number, height: number, color: Color3)
	decor(
		block(
			"Vara",
			Vector3.new(width + 1.2, 0.5, 0.5),
			frame * CFrame.new(0, 0, -0.5),
			WOOD,
			Enum.Material.Wood,
			parent
		)
	)
	decor(
		block(
			"Estandarte",
			Vector3.new(width, height, 0.3),
			frame * CFrame.new(0, -height / 2, -0.3),
			color,
			Enum.Material.Fabric,
			parent
		)
	)
	decor(
		block(
			"Flecos",
			Vector3.new(width, 1.4, 0.34),
			frame * CFrame.new(0, -height + 0.7, -0.3),
			color:Lerp(SHADOW, 0.45),
			Enum.Material.Fabric,
			parent
		)
	)
	decor(
		block(
			"Rombo",
			Vector3.new(2.6, 2.6, 0.2),
			frame * CFrame.new(0, -height * 0.42, -0.5) * CFrame.Angles(0, 0, math.rad(45)),
			BONE,
			Enum.Material.Fabric,
			parent
		)
	)
end

-- Escalinata recta que sube hacia "inward": "count" peldaños de "rise" de alto. El primero sale a
-- "reach" del centro "base" (a la altura de su suelo) y cada uno entra "run" más; todos llegan hasta
-- el centro, así que no quedan huecos debajo. A los lados, las alfardas: cuñas macizas desde el
-- suelo hasta la línea de las narices de los peldaños (sobresalen "run" por delante del primero).
local function stairs(
	parent: Instance,
	base: Vector3,
	inward: Vector3,
	reach: number,
	run: number,
	rise: number,
	count: number,
	width: number
)
	local across = Vector3.new(-inward.Z, 0, inward.X)
	for step = 1, count do
		local front = reach - (step - 1) * run
		local center = base - inward * (front / 2) + Vector3.new(0, (step - 0.5) * rise, 0)
		block(
			"Peldano",
			Vector3.new(width, rise, front),
			CFrame.lookAt(center, center + inward),
			tone(LIMESTONE_LIGHT, 0.06),
			nil,
			parent
		)
	end
	local lastFront = reach - (count - 1) * run
	local railDepth = reach + run - lastFront
	local railHeight = count * rise
	for _, sideSign in { -1, 1 } do
		local center = base
			- inward * (lastFront + railDepth / 2)
			+ across * sideSign * (width / 2 + 0.7)
			+ Vector3.new(0, railHeight / 2, 0)
		-- El frente de la cuña (-Z, la parte baja) mira hacia fuera.
		wedge(
			"Alfarda",
			Vector3.new(1.4, railHeight, railDepth),
			CFrame.lookAt(center, center - inward),
			LIMESTONE_DARK,
			Enum.Material.Limestone,
			parent
		)
	end
end

-- Estela maya: losa tallada sobre un zócalo, con tocado y una cara en relieve en las dos caras
-- anchas. "frame": el punto del suelo (puede ir inclinado); las caras anchas miran a ±Z local. Es una
-- cobertura que se rompe (modelo "Estela"); el zócalo se queda.
local function stela(parent: Instance, frame: CFrame, height: number)
	local width, depth = 4.2, 2.4
	block(
		"Zocalo",
		Vector3.new(width + 1.4, 1, depth + 1.6),
		frame * CFrame.new(0, 0.5, 0),
		LIMESTONE_DARK,
		nil,
		parent
	)
	local cover = coverModel("Estela", parent)
	local slab = block(
		"Losa",
		Vector3.new(width, height, depth),
		frame * CFrame.new(0, 1 + height / 2, 0),
		tone(LIMESTONE),
		nil,
		cover
	)
	cover.PrimaryPart = slab
	parent = cover
	block(
		"Tocado",
		Vector3.new(width + 0.8, 1.6, depth + 0.4),
		frame * CFrame.new(0, 1 + height + 0.3, 0),
		LIMESTONE_DARK,
		nil,
		parent
	)
	for _, face in { -1, 1 } do
		local z = face * (depth / 2 + 0.1)
		local out = face * (depth / 2 + 0.3)
		local eyes = 1 + height * 0.62
		decor(
			block(
				"Relieve",
				Vector3.new(width - 0.8, height * 0.55, 0.3),
				frame * CFrame.new(0, 1 + height * 0.45, z),
				LIMESTONE_DARK,
				nil,
				parent
			)
		)
		for _, eyeSide in { -1, 1 } do
			decor(
				block(
					"Ojo",
					Vector3.new(0.8, 0.5, 0.2),
					frame * CFrame.new(eyeSide * 0.75, eyes, out),
					SHADOW,
					Enum.Material.SmoothPlastic,
					parent
				)
			)
		end
		decor(
			block(
				"Boca",
				Vector3.new(1.6, 0.4, 0.2),
				frame * CFrame.new(0, eyes - 1.4, out),
				SHADOW,
				Enum.Material.SmoothPlastic,
				parent
			)
		)
	end
end

-- Columna rota: basa cuadrada y tres tambores de pie, cada uno un poco descolocado. Es una cobertura
-- que se rompe (modelo "Columna"); la basa se queda.
local function brokenColumn(parent: Instance, ground: Vector3, height: number)
	block("Basa", Vector3.new(6.4, 1.2, 6.4), CFrame.new(ground + Vector3.new(0, 0.6, 0)), LIMESTONE_DARK, nil, parent)
	parent = coverModel("Columna", parent)
	local bottom = 1.2
	for index, share in { 0.42, 0.34, 0.24 } do
		local drumHeight = (height - 1.2) * share
		local offset = Vector3.new(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))
		local drum = cylinder(
			"Tambor",
			5 - index * 0.2,
			ground + offset + Vector3.new(0, bottom, 0),
			ground + offset + Vector3.new(0, bottom + drumHeight, 0),
			tone(LIMESTONE),
			Enum.Material.Limestone,
			parent
		)
		if index == 1 then
			(parent :: Model).PrimaryPart = drum
		end
		bottom += drumHeight
	end
end

-- Columna caída: tres tambores tumbados en fila y el capitel al final.
local function fallenColumn(parent: Instance, ground: Vector3, yaw: number)
	local direction = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local drum = 4.4
	for index = 0, 2 do
		local start = ground + direction * (index * 4.6 - 6.9) + Vector3.new(0, drum / 2 - 0.2, 0)
		cylinder("Tambor", drum, start, start + direction * 4.2, tone(LIMESTONE), Enum.Material.Limestone, parent)
	end
	block(
		"Capitel",
		Vector3.new(6, 1.6, 6),
		CFrame.new(ground + direction * 9.2 + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, -yaw, 0.25),
		LIMESTONE_DARK,
		nil,
		parent
	)
end

-- Cactus como los del Lobby (buildDunesIsland), con menos piezas: tronco y dos brazos.
local function cactus(parent: Instance, ground: Vector3, height: number)
	local width = height / 6
	local top = ground + Vector3.new(0, height, 0)
	decor(cylinder("Cactus", width, ground - Vector3.new(0, 1, 0), top, CACTUS, Enum.Material.Grass, parent))
	decor(ball("Punta", width, top, CACTUS, Enum.Material.Grass, parent))
	local yaw = rng:NextNumber(0, 2 * math.pi)
	for _, armSide in { -1, 1 } do
		local out = Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * armSide
		local start = ground + Vector3.new(0, height * rng:NextNumber(0.35, 0.55), 0)
		local elbow = start + out * height * 0.22
		local tip = elbow + Vector3.new(0, height * rng:NextNumber(0.2, 0.35), 0)
		decor(cylinder("Brazo", width * 0.7, start, elbow + out * width * 0.35, CACTUS, Enum.Material.Grass, parent))
		decor(
			cylinder(
				"Brazo",
				width * 0.7,
				elbow - Vector3.new(0, width * 0.35, 0),
				tip,
				CACTUS,
				Enum.Material.Grass,
				parent
			)
		)
		decor(ball("Punta", width * 0.7, tip, CACTUS, Enum.Material.Grass, parent))
	end
end

-- Mata seca: dos bolas pardas aplastadas.
local function dryBush(parent: Instance, ground: Vector3)
	for index = 1, 2 do
		local size = rng:NextNumber(2.4, 3.6)
		local offset = Vector3.new(rng:NextNumber(-1.2, 1.2), size * 0.3, rng:NextNumber(-1.2, 1.2))
		local part = block(
			"Mata",
			Vector3.new(size, size * 0.7, size),
			CFrame.new(ground + offset),
			tone(DRY_BUSH, 0.2),
			Enum.Material.Grass,
			parent
		)
		part.Shape = if index == 1 then Enum.PartType.Ball else Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		decor(part)
	end
end

-- Pieza de una máscara: "frame" es el centro de la máscara en la cara del muro (-Z hacia fuera).
local function maskPiece(
	parent: Instance,
	frame: CFrame,
	name: string,
	size: Vector3,
	x: number,
	y: number,
	z: number,
	color: Color3,
	rotation: CFrame?,
	material: Enum.Material?
)
	decor(
		block(
			name,
			size,
			frame * CFrame.new(x, y, z) * (rotation or CFrame.identity),
			color,
			material or Enum.Material.SmoothPlastic,
			parent
		)
	)
end

-- Máscara del jaguar encima de la puerta de su base: cara naranja con rosetas, orejas, ojos verdes
-- que brillan, hocico claro y colmillos.
local function jaguarMask(parent: Instance, frame: CFrame, fur: Color3)
	local function piece(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, roll: number?)
		maskPiece(parent, frame, name, size, x, y, z, color, CFrame.Angles(0, 0, roll or 0))
	end
	piece("Cara", Vector3.new(12, 9, 1.6), 0, 0, -0.8, fur)
	for _, s in { -1, 1 } do
		piece("Oreja", Vector3.new(3, 3, 1.4), s * 4.6, 5.4, -0.7, fur)
		piece("Oreja", Vector3.new(1.6, 1.6, 0.3), s * 4.6, 5.3, -1.5, SHADOW)
		-- Ceño: cejas más bajas por dentro.
		piece("Ceja", Vector3.new(3.6, 0.8, 0.5), s * 2.6, 2.5, -1.75, SHADOW, s * 0.35)
		maskPiece(
			parent,
			frame,
			"Ojo",
			Vector3.new(2.6, 1.2, 0.4),
			s * 2.6,
			1.2,
			-1.75,
			JAGUAR_EYE,
			CFrame.Angles(0, 0, s * 0.25),
			Enum.Material.Neon
		)
		piece("Pupila", Vector3.new(0.45, 1.1, 0.2), s * 2.6, 1.2, -2.0, SHADOW)
		piece("Colmillo", Vector3.new(0.7, 1.2, 0.5), s * 1.6, -3.5, -2.85, BONE)
		piece("Colmillo", Vector3.new(0.6, 0.9, 0.5), s * 1.0, -4.05, -2.85, BONE)
	end
	piece("Hocico", Vector3.new(6, 3.8, 1.2), 0, -2.3, -2.0, CREAM)
	piece("Nariz", Vector3.new(2.4, 1.2, 0.6), 0, -0.9, -2.8, Color3.fromRGB(60, 35, 30))
	piece("Boca", Vector3.new(5, 1.4, 0.4), 0, -3.7, -2.65, SHADOW)
	for _, spot in
		{
			Vector2.new(0, 3.5),
			Vector2.new(-1.8, 3.7),
			Vector2.new(1.8, 3.7),
			Vector2.new(-5, -0.6),
			Vector2.new(5, -0.6),
			Vector2.new(-4.6, -3.2),
			Vector2.new(4.6, -3.2),
		}
	do
		piece("Roseta", Vector3.new(0.9, 0.9, 0.2), spot.X, spot.Y, -1.65, SHADOW)
	end
end

-- Máscara del quetzal, como un emblema: cabeza azul con penacho verde, ojos en rombo, pico amarillo,
-- pecho rojo, alas abiertas en abanico de plumas y la cola larga colgando por el centro (por encima
-- de las cabezas). Las alas sueltas de una pieza parecían brazos.
local function quetzalMask(parent: Instance, frame: CFrame, head: Color3)
	local function piece(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, roll: number?)
		maskPiece(parent, frame, name, size, x, y, z, color, CFrame.Angles(0, 0, roll or 0))
	end
	local tipColor = QUETZAL_GREEN:Lerp(SHADOW, 0.35)
	-- Pluma que sale de "pivot" hacia "angle" (0 = arriba, positivo hacia -X), con la punta oscura.
	local function feather(name: string, pivot: Vector2, angle: number, length: number, width: number, z: number)
		local direction = Vector2.new(-math.sin(angle), math.cos(angle))
		local mid = pivot + direction * (length / 2)
		local tip = pivot + direction * (length - 0.7)
		piece(name, Vector3.new(width, length, 0.8), mid.X, mid.Y, z, QUETZAL_GREEN, angle)
		piece(name, Vector3.new(width + 0.1, 1.4, 0.85), tip.X, tip.Y, z, tipColor, angle)
	end
	piece("Cabeza", Vector3.new(8, 7, 1.6), 0, 1, -0.8, head)
	for index = -2, 2 do
		feather("Penacho", Vector2.new(0, 3), index * 0.34, 6.5, 1.6, -0.5)
	end
	for _, s in { -1, 1 } do
		piece("Ojo", Vector3.new(2.2, 2.2, 0.3), s * 2.1, 1.8, -1.7, BONE, math.rad(45))
		piece("Pupila", Vector3.new(1.1, 1.1, 0.3), s * 2.1, 1.8, -1.9, SHADOW, math.rad(45))
		for _, degrees in { 45, 68, 91 } do
			feather("Ala", Vector2.new(s * 3, -3), -s * math.rad(degrees), 7.5, 2, -0.6)
		end
		feather("Cola", Vector2.new(0, -5.5), math.pi + s * 0.2, 10, 1.8, -0.4)
	end
	feather("Cola", Vector2.new(0, -5.5), math.pi, 12, 2, -0.5)
	piece("Pecho", Vector3.new(6, 4, 1.4), 0, -4, -1.0, QUETZAL_RED)
	piece("Pico", Vector3.new(3, 2.2, 2.4), 0, 0, -2.6, BEAK)
	maskPiece(parent, frame, "Pico", Vector3.new(1.8, 1.8, 1.8), 0, -1.1, -3.6, BEAK, CFrame.Angles(math.rad(45), 0, 0))
end

local function applyLighting()
	-- Tarde del desierto: sol bajo y cálido, sombras largas y bruma de arena en el horizonte.
	Lighting.ClockTime = 15.6
	Lighting.GeographicLatitude = 23
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(95, 80, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 125, 100)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(230, 195, 145)
	atmosphere.Decay = Color3.fromRGB(180, 110, 65)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting
	local grade = (Lighting:FindFirstChild("ColorDesierto") :: ColorCorrectionEffect?)
		or Instance.new("ColorCorrectionEffect")
	grade.Name = "ColorDesierto"
	grade.Parent = Lighting
	grade.TintColor = Color3.fromRGB(255, 244, 228)
	grade.Saturation = 0.08
	grade.Contrast = 0.06
end

local function buildGround(folder: Folder)
	local ground = block("Suelo", Vector3.new(1800, 4, 1800), CFrame.new(0, -2, 0), SAND, Enum.Material.Sand, folder)
	ground.Locked = true
	-- Plaza enlosada alrededor de la pirámide y calzada blanca (sacbé) hasta cada puerta.
	block("Plaza", Vector3.new(64, 0.2, 66), CFrame.new(0, 0.1, 0), PAVING, Enum.Material.Pavement, folder)
	for _, side in { -1, 1 } do
		local from, to = 32, BASE_INNER_X - 9
		block(
			"Sacbe",
			Vector3.new(to - from, 0.25, 14),
			CFrame.new(side * (from + to) / 2, 0.125, 0),
			LIMESTONE_LIGHT,
			nil,
			folder
		)
	end
end

-- Pared del cañón entre dos puntos de su cara de dentro (a ras de suelo): el muro que cierra la
-- arena (choca), con dos franjas oscuras, contrafuertes de roca de alturas distintas que rompen la
-- línea de arriba y cantos caídos al pie.
local function canyonWall(walls: Folder, name: string, from: Vector3, to: Vector3, inward: Vector3)
	local length = (to - from).Magnitude
	local direction = (to - from).Unit
	local center = (from + to) / 2 - inward * (BOUNDARY_THICKNESS / 2)
	local frame = CFrame.lookAt(center, center + inward)
	block(
		name,
		Vector3.new(length, BOUNDARY_HEIGHT, BOUNDARY_THICKNESS),
		frame * CFrame.new(0, BOUNDARY_HEIGHT / 2, 0),
		CANYON,
		Enum.Material.Sandstone,
		walls
	)
	for _, height in { 13, 29 } do
		decor(
			block(
				"Franja",
				Vector3.new(length, 1.8, BOUNDARY_THICKNESS + 1.2),
				frame * CFrame.new(0, height, 0),
				CANYON_DARK,
				Enum.Material.Sandstone,
				walls
			)
		)
	end
	local distance = rng:NextNumber(0, 8)
	while distance < length do
		local width = rng:NextNumber(12, 22)
		local depth = rng:NextNumber(3, 8)
		local height = rng:NextNumber(20, 50)
		local at = from + direction * math.clamp(distance + width / 2, width / 2, length - width / 2)
		local base = CFrame.lookAt(at, at + inward) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0)
		local inset = -(depth / 2 - 1.5)
		block(
			"Roca",
			Vector3.new(width, height, depth),
			base * CFrame.new(0, height / 2, inset),
			tone(CANYON, 0.15),
			Enum.Material.Sandstone,
			walls
		)
		decor(
			block(
				"Franja",
				Vector3.new(width + 0.6, rng:NextNumber(1.2, 2.4), depth + 0.6),
				base * CFrame.new(0, height * rng:NextNumber(0.3, 0.7), inset),
				tone(CANYON_DARK, 0.1),
				Enum.Material.Sandstone,
				walls
			)
		)
		if rng:NextNumber() < 0.5 then
			local size = rng:NextNumber(3, 5.5)
			ball(
				"Canto",
				size,
				(base * CFrame.new(rng:NextNumber(-width / 2, width / 2), size * 0.3, -(depth + size * 0.3))).Position,
				tone(CANYON_DARK, 0.1),
				Enum.Material.Sandstone,
				walls
			)
		end
		distance += width * rng:NextNumber(0.75, 1.1)
	end
end

local function buildBoundary(folder: Folder)
	local walls = Instance.new("Folder")
	walls.Name = "Limites"
	local reach = HALF_LENGTH + BOUNDARY_THICKNESS
	canyonWall(walls, "Norte", Vector3.new(-reach, 0, HALF_WIDTH), Vector3.new(reach, 0, HALF_WIDTH), -Vector3.zAxis)
	canyonWall(walls, "Sur", Vector3.new(-reach, 0, -HALF_WIDTH), Vector3.new(reach, 0, -HALF_WIDTH), Vector3.zAxis)
	-- Al oeste y al este, a los lados de cada base (detrás del patio está el templo).
	local baseEdge = BASE_HALF_WIDTH + BASE_WALL_THICKNESS
	for _, side in { -1, 1 } do
		local x = side * HALF_LENGTH
		local inward = Vector3.new(-side, 0, 0)
		local name = if side < 0 then "Oeste" else "Este"
		canyonWall(walls, name, Vector3.new(x, 0, baseEdge), Vector3.new(x, 0, HALF_WIDTH), inward)
		canyonWall(walls, name, Vector3.new(x, 0, -HALF_WIDTH), Vector3.new(x, 0, -baseEdge), inward)
	end
	walls.Parent = folder
end

-- Pirámide escalonada al fondo de una base, sobre un basamento más alto que un salto, con la
-- escalinata hacia el patio y un santuario rojo en lo alto con braseros del color del equipo.
local function buildTemple(parent: Instance, teamColor: Color3, side: number)
	local temple = Instance.new("Model")
	temple.Name = "Templo"
	local outer = side * HALF_LENGTH
	local centerX = side * (HALF_LENGTH + TEMPLE_DEPTH / 2)
	local halfWidth = BASE_HALF_WIDTH + BASE_WALL_THICKNESS
	between(
		"Basamento",
		outer,
		-halfWidth,
		outer + side * TEMPLE_DEPTH,
		halfWidth,
		0,
		TEMPLE_PLATFORM_HEIGHT,
		LIMESTONE,
		temple
	)
	-- Cara del basamento que da al patio: moldura, pilastras y el glifo del equipo encima de la
	-- baldosa de aparición. Todo choca: la cámara, al aparecer, queda justo delante de esta pared y
	-- solo se aparta de las piezas sólidas (con el glifo como decorado se metía dentro y la pantalla
	-- salía toda naranja).
	local face = outer - side * 0.4
	block(
		"Moldura",
		Vector3.new(1.2, 1.4, halfWidth * 2),
		CFrame.new(face, TEMPLE_PLATFORM_HEIGHT - 0.5, 0),
		LIMESTONE_DARK,
		nil,
		temple
	)
	for _, z in { -32, -18, 18, 32 } do
		block(
			"Pilastra",
			Vector3.new(1, TEMPLE_PLATFORM_HEIGHT - BASE_FLOOR, 2.4),
			CFrame.new(face, (TEMPLE_PLATFORM_HEIGHT + BASE_FLOOR) / 2, z),
			LIMESTONE_DARK,
			nil,
			temple
		)
	end
	local diamond = CFrame.Angles(math.rad(45), 0, 0)
	block(
		"Glifo",
		Vector3.new(0.6, 6, 6),
		CFrame.new(face, 7, 0) * diamond,
		teamColor,
		Enum.Material.SmoothPlastic,
		temple
	)
	block(
		"Glifo",
		Vector3.new(0.8, 2.6, 2.6),
		CFrame.new(face, 7, 0) * diamond,
		SHADOW,
		Enum.Material.SmoothPlastic,
		temple
	)

	for index, half in TEMPLE_HALF_SIZES do
		local bottom = TEMPLE_PLATFORM_HEIGHT + (index - 1) * TEMPLE_TIER_HEIGHT
		block(
			"Cuerpo",
			Vector3.new(half * 2, TEMPLE_TIER_HEIGHT, half * 2),
			CFrame.new(centerX, bottom + TEMPLE_TIER_HEIGHT / 2, 0),
			if index % 2 == 0 then LIMESTONE else LIMESTONE:Lerp(LIMESTONE_DARK, 0.2),
			nil,
			temple
		)
		decor(
			block(
				"Cornisa",
				Vector3.new(half * 2 + 0.8, 1.2, half * 2 + 0.8),
				CFrame.new(centerX, bottom + TEMPLE_TIER_HEIGHT - 1.6, 0),
				LIMESTONE_DARK,
				nil,
				temple
			)
		)
	end
	local tiers = #TEMPLE_HALF_SIZES
	local summit = TEMPLE_PLATFORM_HEIGHT + tiers * TEMPLE_TIER_HEIGHT
	local topHalf = TEMPLE_HALF_SIZES[tiers]
	local steps = 14
	-- El primer peldaño, un poco detrás del borde del basamento: delante de él va el pie de las alfardas.
	local stairReach = TEMPLE_DEPTH / 2 - 2
	stairs(
		temple,
		Vector3.new(centerX, TEMPLE_PLATFORM_HEIGHT, 0),
		Vector3.new(side, 0, 0),
		stairReach,
		(stairReach - topHalf) / (steps - 1),
		(summit - TEMPLE_PLATFORM_HEIGHT) / steps,
		steps,
		14
	)

	-- Santuario: cuerpo de estuco rojo, puerta oscura, friso del color del equipo, cornisa y
	-- crestería calada encima.
	local shrineX = centerX + side * 2.5
	local frontX = shrineX - side * 6.5
	block(
		"Santuario",
		Vector3.new(13, 10, 18),
		CFrame.new(shrineX, summit + 5, 0),
		STUCCO_RED,
		Enum.Material.Plaster,
		temple
	)
	decor(
		block(
			"Puerta",
			Vector3.new(0.6, 6.5, 4.4),
			CFrame.new(frontX - side * 0.2, summit + 3.25, 0),
			SHADOW,
			Enum.Material.SmoothPlastic,
			temple
		)
	)
	decor(
		block(
			"Dintel",
			Vector3.new(0.8, 1, 6),
			CFrame.new(frontX - side * 0.3, summit + 7, 0),
			LIMESTONE_LIGHT,
			nil,
			temple
		)
	)
	decor(
		block(
			"Friso",
			Vector3.new(13.4, 1.8, 18.4),
			CFrame.new(shrineX, summit + 8.2, 0),
			teamColor,
			Enum.Material.SmoothPlastic,
			temple
		)
	)
	block("Cornisa", Vector3.new(14, 1.2, 19), CFrame.new(shrineX, summit + 9.7, 0), LIMESTONE_DARK, nil, temple)
	local combX = shrineX + side * 2
	block(
		"Cresteria",
		Vector3.new(2.4, 9, 12),
		CFrame.new(combX, summit + 14.8, 0),
		STUCCO_RED,
		Enum.Material.Plaster,
		temple
	)
	for _, z in { -3, 3 } do
		decor(
			block(
				"Calado",
				Vector3.new(0.3, 3, 2.2),
				CFrame.new(combX - side * 1.25, summit + 15, z),
				SHADOW,
				Enum.Material.SmoothPlastic,
				temple
			)
		)
	end
	block("Remate", Vector3.new(3, 1, 13), CFrame.new(combX, summit + 19.8, 0), LIMESTONE_DARK, nil, temple)
	for _, zSign in { -1, 1 } do
		brazier(temple, Vector3.new(centerX - side * (topHalf - 3.5), summit, zSign * 9.5), teamColor, false)
	end

	-- Barreras: delante de la cara del basamento, más allá de lo que sobresale (molduras, pilastras y el
	-- glifo, cuyos bordes a 45° hacían de peldaño hasta arriba), y por los otros tres bordes de la terraza.
	barrier(
		Vector3.new(0.5, BARRIER_HEIGHT, halfWidth * 2),
		CFrame.new(outer - side * 1.45, BASE_FLOOR + BARRIER_HEIGHT / 2, 0),
		temple
	)
	local terraceY = TEMPLE_PLATFORM_HEIGHT + BARRIER_HEIGHT / 2
	barrier(
		Vector3.new(1, BARRIER_HEIGHT, halfWidth * 2),
		CFrame.new(outer + side * (TEMPLE_DEPTH - 0.5), terraceY, 0),
		temple
	)
	for _, zSign in { -1, 1 } do
		barrier(
			Vector3.new(TEMPLE_DEPTH, BARRIER_HEIGHT, 1),
			CFrame.new(centerX, terraceY, zSign * (halfWidth - 0.5)),
			temple
		)
	end
	temple.Parent = parent
end

-- Fachada de la base (el muro que mira al centro, ya construido): talud al pie, falsa bóveda en la
-- puerta, friso con grecas, crestería con la máscara del equipo, almenas, estandartes y braseros.
local function buildFacade(parent: Instance, teamId: string, teamColor: Color3, side: number)
	local facade = Instance.new("Model")
	facade.Name = "Fachada"
	local inner = side * BASE_INNER_X
	local top = BASE_FLOOR + BASE_WALL_HEIGHT
	local outFace = inner - side * BASE_WALL_THICKNESS / 2
	local wallX2 = inner + side * BASE_WALL_THICKNESS / 2
	local toCenter = Vector3.new(-side, 0, 0)

	for _, zSign in { -1, 1 } do
		-- Talud: el pie del muro en pendiente, como los edificios mayas. Se queda antes de la línea de
		-- los muros del carril: desde lo alto del talud se llegaría de un salto al cierre del pasillo.
		-- Con 4 de alto, un salto desde arriba llega a 11,2 (el cierre mide 12).
		local taludEnd = LANE_WALL_Z - 6
		local taludHeight = 4
		local taludCenter =
			Vector3.new(outFace - side * 1.75, taludHeight / 2, zSign * (GATE_HALF_WIDTH + taludEnd) / 2)
		wedge(
			"Talud",
			Vector3.new(taludEnd - GATE_HALF_WIDTH, taludHeight, 3.5),
			CFrame.lookAt(taludCenter, taludCenter + toCenter),
			tone(LIMESTONE, 0.06),
			Enum.Material.Limestone,
			facade
		)
		-- Falsa bóveda: la puerta se cierra hacia arriba en escalones (por encima de las cabezas).
		for step = 1, 4 do
			local bottom = 14 + (step - 1) * 2.5
			between(
				"Boveda",
				outFace,
				zSign * (GATE_HALF_WIDTH - 1.5 * step),
				wallX2,
				zSign * GATE_HALF_WIDTH,
				bottom,
				top - 4 - bottom,
				LIMESTONE,
				facade
			)
		end
		-- Almenas escalonadas a lo largo del muro.
		for _, z in { 16, 24, 32, 38.5 } do
			block(
				"Almena",
				Vector3.new(BASE_WALL_THICKNESS + 0.4, 2.4, 3),
				CFrame.new(inner, top + 1.2, zSign * z),
				LIMESTONE_DARK,
				nil,
				facade
			)
			block(
				"Almena",
				Vector3.new(BASE_WALL_THICKNESS + 0.4, 1.4, 1.4),
				CFrame.new(inner, top + 3.1, zSign * z),
				LIMESTONE_DARK,
				nil,
				facade
			)
		end
		banner(
			facade,
			CFrame.lookAt(Vector3.new(outFace, 25, zSign * 24), Vector3.new(outFace, 25, zSign * 24) + toCenter),
			7,
			16,
			teamColor
		)
		brazier(facade, Vector3.new(outFace - side * 5, 0, zSign * 11.5), teamColor, true)
	end
	-- Grecas oscuras en la franja del color del equipo.
	for z = -37.5, 37.5, 5 do
		decor(
			block(
				"Greca",
				Vector3.new(0.2, 1.2, 1.2),
				CFrame.new(outFace - side * 0.25, top - 7 + 1.25, z),
				SHADOW,
				Enum.Material.SmoothPlastic,
				facade
			)
		)
	end
	-- Crestería encima de la puerta: marco de estuco rojo, piedra y la máscara del equipo.
	local crestCenter = top + 3
	block(
		"Cresta",
		Vector3.new(BASE_WALL_THICKNESS - 0.6, 15.6, 24),
		CFrame.new(inner, crestCenter + 0.3, 0),
		STUCCO_RED,
		Enum.Material.Plaster,
		facade
	)
	block("Cresta", Vector3.new(BASE_WALL_THICKNESS, 14, 22), CFrame.new(inner, crestCenter, 0), LIMESTONE, nil, facade)
	block("Remate", Vector3.new(4.4, 1.2, 16), CFrame.new(inner, crestCenter + 8.7, 0), LIMESTONE_DARK, nil, facade)
	block("Remate", Vector3.new(4.4, 1.2, 8), CFrame.new(inner, crestCenter + 9.9, 0), LIMESTONE_DARK, nil, facade)
	local maskAt = Vector3.new(outFace, crestCenter, 0)
	local maskFrame = CFrame.lookAt(maskAt, maskAt + toCenter)
	local mask = Instance.new("Model")
	mask.Name = "Mascara"
	if teamId == "Jaguar" then
		jaguarMask(mask, maskFrame, teamColor)
	else
		quetzalMask(mask, maskFrame, teamColor)
	end
	mask.Parent = facade
	facade.Parent = parent
end

-- Base de un equipo: patio de un templo con muros, puerta hacia el centro, baldosa de aparición y
-- pedestal de la bandera. "side": -1 al oeste (Jaguar), 1 al este (Quetzal).
local function buildBase(bases: Folder, teamId: string, side: number)
	local team = Config.Arena.Teams[teamId]
	local model = Instance.new("Model")
	model.Name = teamId
	model:SetAttribute("Team", teamId)
	local inner = side * BASE_INNER_X
	local outer = side * HALF_LENGTH
	local depth = HALF_LENGTH - BASE_INNER_X
	local centerX = (inner + outer) / 2

	-- Suelo enlosado y elevado, con rampa hacia el carril y una calzada clara de la puerta al templo.
	local patio = between("Patio", inner, -BASE_HALF_WIDTH, outer, BASE_HALF_WIDTH, 0, BASE_FLOOR, PAVING, model)
	patio.Material = Enum.Material.Pavement
	block(
		"Rampa",
		Vector3.new(10, 1, GATE_HALF_WIDTH * 2),
		CFrame.new(inner - side * 4.6, BASE_FLOOR / 2 - 0.1, 0) * CFrame.Angles(0, 0, side * math.rad(12)),
		LIMESTONE_LIGHT,
		nil,
		model
	)
	block(
		"Calzada",
		Vector3.new(depth, 0.1, 10),
		CFrame.new(centerX, BASE_FLOOR + 0.05, 0),
		LIMESTONE_LIGHT,
		nil,
		model
	)

	-- Muros: el que mira al centro (con el hueco de la puerta) y los de los lados.
	local top = BASE_FLOOR + BASE_WALL_HEIGHT
	local wallX1 = inner - side * BASE_WALL_THICKNESS / 2
	local wallX2 = inner + side * BASE_WALL_THICKNESS / 2
	between("MuroNorte", wallX1, GATE_HALF_WIDTH, wallX2, BASE_HALF_WIDTH, 0, top, LIMESTONE, model)
	between("MuroSur", wallX1, -BASE_HALF_WIDTH, wallX2, -GATE_HALF_WIDTH, 0, top, LIMESTONE, model)
	between("Dintel", wallX1, -GATE_HALF_WIDTH, wallX2, GATE_HALF_WIDTH, top - 4, 4, LIMESTONE, model)
	local sideEdge = BASE_HALF_WIDTH + BASE_WALL_THICKNESS
	between("LadoNorte", inner, BASE_HALF_WIDTH, outer, sideEdge, 0, top, LIMESTONE, model)
	between("LadoSur", inner, -sideEdge, outer, -BASE_HALF_WIDTH, 0, top, LIMESTONE, model)
	for _, zSign in { -1, 1 } do
		-- Zócalo oscuro por fuera y almenas encima de los muros de los lados.
		decor(
			block(
				"Zocalo",
				Vector3.new(depth, 3, 0.6),
				CFrame.new(centerX, 1.5, zSign * (sideEdge + 0.3)),
				LIMESTONE_DARK,
				nil,
				model
			)
		)
		for _, offset in { 6, 16, 26, 36, 46 } do
			block(
				"Almena",
				Vector3.new(3, 2.4, BASE_WALL_THICKNESS + 0.4),
				CFrame.new(inner + side * offset, top + 1.2, zSign * (BASE_HALF_WIDTH + BASE_WALL_THICKNESS / 2)),
				LIMESTONE_DARK,
				nil,
				model
			)
		end
	end
	-- Franja del color del equipo en lo alto del muro de la puerta, para saber de quién es la base.
	local stripe = between(
		"Franja",
		wallX1 - side * 0.2,
		-BASE_HALF_WIDTH,
		wallX2 + side * 0.2,
		BASE_HALF_WIDTH,
		top - 7,
		2.5,
		team.color,
		model
	)
	stripe.Material = Enum.Material.SmoothPlastic

	-- Puerta: cerrada (se ve y choca) hasta que empieza la partida (ArenaWorldService.setGates).
	local gate = between(
		"Gate",
		inner - side * 1,
		-GATE_HALF_WIDTH,
		inner + side * 1,
		GATE_HALF_WIDTH,
		BASE_FLOOR,
		top - 4 - BASE_FLOOR,
		team.color,
		model
	)
	gate.Material = Enum.Material.ForceField

	-- Baldosa de aparición, al fondo del patio, al pie del templo, con un marco de piedra y dos
	-- braseros.
	-- A 14 del templo: con la cámara a ~12,5 detrás del personaje, cabe sin tocar la pared.
	local spawnX = outer - side * 14
	local spawn = block(
		"Spawn",
		Vector3.new(10, 0.2, 10),
		CFrame.new(spawnX, BASE_FLOOR + 0.1, 0),
		team.color,
		Enum.Material.SmoothPlastic,
		model
	)
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	for _, sign in { -1, 1 } do
		decor(
			block(
				"Marco",
				Vector3.new(11.6, 0.3, 0.8),
				CFrame.new(spawnX, BASE_FLOOR + 0.15, sign * 5.4),
				LIMESTONE_DARK,
				nil,
				model
			)
		)
		decor(
			block(
				"Marco",
				Vector3.new(0.8, 0.3, 10),
				CFrame.new(spawnX + sign * 5.4, BASE_FLOOR + 0.15, 0),
				LIMESTONE_DARK,
				nil,
				model
			)
		)
		-- Sin chocar: subido a un pebetero se llegaría de un salto al basamento del templo (y desde
		-- allí, fuera de la arena).
		brazier(model, Vector3.new(outer - side * 2.5, BASE_FLOOR, sign * 10), team.color, false)
	end

	-- Pedestal de la bandera, en medio del patio, sobre un altar bajo con cuatro postes que brillan
	-- del color del equipo.
	block("Altar", Vector3.new(9, 0.5, 9), CFrame.new(centerX, BASE_FLOOR + 0.25, 0), LIMESTONE_DARK, nil, model)
	local stand = block(
		"FlagStand",
		Vector3.new(5, 1.5, 5),
		CFrame.new(centerX, BASE_FLOOR + 0.75, 0),
		LIMESTONE_DARK:Lerp(SHADOW, 0.2),
		nil,
		model
	)
	stand:SetAttribute("Team", teamId)
	for _, xSign in { -1, 1 } do
		for _, zSign in { -1, 1 } do
			local at = Vector3.new(centerX + xSign * 5.2, BASE_FLOOR, zSign * 5.2)
			decor(
				block(
					"Poste",
					Vector3.new(1.2, 3.5, 1.2),
					CFrame.new(at + Vector3.new(0, 1.75, 0)),
					LIMESTONE,
					nil,
					model
				)
			)
			decor(block(
				"Luz",
				Vector3.new(1.5, 0.5, 1.5),
				CFrame.new(at + Vector3.new(0, 3.75, 0)),
				-- El neón aclara el color: oscurecido, el naranja no sale amarillo.
				team.color:Lerp(SHADOW, 0.3),
				Enum.Material.Neon,
				model
			))
		end
	end

	-- Volumen de la base (para saber quién está dentro).
	local zone = block(
		"Zone",
		Vector3.new(depth, 30, BASE_HALF_WIDTH * 2),
		CFrame.new(centerX, BASE_FLOOR + 15, 0),
		team.color,
		nil,
		model
	)
	marker(zone)

	buildFacade(model, teamId, team.color, side)
	buildTemple(model, team.color, side)
	model.PrimaryPart = spawn
	model.Parent = bases
end

-- Pirámide escalonada del centro, con escalinatas en las cuatro caras y braseros en las esquinas
-- del tercer cuerpo; en lo alto, el punto de aparición neutro.
local function buildPyramid(folder: Folder)
	local pyramid = Instance.new("Model")
	pyramid.Name = "Piramide"
	for index, size in PYRAMID_SIZES do
		local bottom = (index - 1) * PYRAMID_STEP
		block(
			`Escalon{index}`,
			Vector3.new(size, PYRAMID_STEP, size),
			CFrame.new(0, bottom + PYRAMID_STEP / 2, 0),
			if index % 2 == 0 then LIMESTONE else LIMESTONE:Lerp(LIMESTONE_DARK, 0.2),
			nil,
			pyramid
		)
		decor(
			block(
				"Cornisa",
				Vector3.new(size + 0.4, 0.8, size + 0.4),
				CFrame.new(0, bottom + PYRAMID_STEP - 1.2, 0),
				LIMESTONE_DARK,
				nil,
				pyramid
			)
		)
	end
	local height = #PYRAMID_SIZES * PYRAMID_STEP
	local topHalf = PYRAMID_SIZES[#PYRAMID_SIZES] / 2
	for _, inward in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		stairs(
			pyramid,
			Vector3.zero,
			inward,
			PYRAMID_STAIR_REACH,
			(PYRAMID_STAIR_REACH - topHalf) / (height - 1),
			1,
			height,
			6
		)
	end
	local corner = (PYRAMID_SIZES[#PYRAMID_SIZES - 1] / 2 + topHalf) / 2 + 0.2
	for _, xSign in { -1, 1 } do
		for _, zSign in { -1, 1 } do
			brazier(pyramid, Vector3.new(xSign * corner, height - PYRAMID_STEP, zSign * corner), FIRE, false)
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "EsperaSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, height + 0.5, 0)
	spawn.Color = LIMESTONE_LIGHT
	spawn.Material = Enum.Material.Limestone
	spawn.TopSurface = Enum.SurfaceType.Smooth
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = pyramid
	pyramid.Parent = folder
end

-- Altar de la cima (C11, AltarService): cuatro pilares bajos con una gema en las esquinas del punto de
-- aparición, un glifo redondo en el suelo y un haz de luz que se ve desde toda la arena. Las gemas, el
-- glifo y el haz los colorea cada cliente según el estado (AltarController); aquí salen apagados.
local function buildAltar(folder: Folder)
	local altar = Instance.new("Model")
	altar.Name = "Altar"
	-- Entero y siempre en todos los clientes (su haz se ve desde toda la arena).
	altar.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local top = #PYRAMID_SIZES * PYRAMID_STEP + 1 -- encima de la baldosa de aparición
	local capture = block("Captura", Vector3.one, CFrame.new(0, top, 0), LIMESTONE, nil, altar)
	marker(capture)
	altar.PrimaryPart = capture
	local corner = 4.6
	for _, xSign in { -1, 1 } do
		for _, zSign in { -1, 1 } do
			local at = Vector3.new(xSign * corner, top, zSign * corner)
			block(
				"Pilar",
				Vector3.new(1.6, 3.2, 1.6),
				CFrame.new(at + Vector3.new(0, 1.6, 0)),
				LIMESTONE_DARK,
				nil,
				altar
			)
			decor(
				block("Remate", Vector3.new(2, 0.5, 2), CFrame.new(at + Vector3.new(0, 3.45, 0)), LIMESTONE, nil, altar)
			)
			decor(
				block(
					"Gema",
					Vector3.new(1, 1, 1),
					CFrame.new(at + Vector3.new(0, 4.2, 0)) * CFrame.Angles(0, math.rad(45), math.rad(45)),
					LIMESTONE_LIGHT,
					Enum.Material.Neon,
					altar
				)
			)
		end
	end
	local glyph = block(
		"Glifo",
		Vector3.new(0.12, 8, 8),
		CFrame.new(0, top + 0.06, 0) * UPRIGHT,
		LIMESTONE_DARK,
		Enum.Material.Neon,
		altar
	)
	glyph.Shape = Enum.PartType.Cylinder
	decor(glyph)
	local beamHeight = 140
	local beam = block(
		"Haz",
		Vector3.new(beamHeight, 3, 3),
		CFrame.new(0, top + beamHeight / 2, 0) * UPRIGHT,
		CREAM,
		Enum.Material.Neon,
		altar
	)
	beam.Shape = Enum.PartType.Cylinder
	beam.Transparency = 1
	beam.CastShadow = false
	decor(beam)
	altar.Parent = folder
end

-- Muro del juego de pelota (junto a la pirámide): más alto, con talud hacia el carril, moldura
-- oscura y un aro de piedra en lo alto. "laneSide": hacia dónde queda el carril (±1 en Z).
local function buildCourtWall(ruins: Folder, side: number, z: number, laneSide: number)
	between(
		"MuroCarril",
		side * LANE_WALL_GAP,
		z - 2,
		side * COURT_END,
		z + 2,
		0,
		COURT_WALL_HEIGHT,
		tone(LIMESTONE, 0.06),
		ruins
	)
	local length = COURT_END - LANE_WALL_GAP
	local middleX = side * (LANE_WALL_GAP + COURT_END) / 2
	local laneFace = z + laneSide * 2
	local slope = Vector3.new(middleX, 1.75, laneFace + laneSide * 2.5)
	wedge(
		"Talud",
		Vector3.new(length, 3.5, 5),
		CFrame.lookAt(slope, slope + Vector3.new(0, 0, laneSide)),
		LIMESTONE_LIGHT,
		Enum.Material.Limestone,
		ruins
	)
	decor(
		block(
			"Moldura",
			Vector3.new(length, 1.2, 0.6),
			CFrame.new(middleX, COURT_WALL_HEIGHT - 0.8, laneFace + laneSide * 0.25),
			LIMESTONE_DARK,
			nil,
			ruins
		)
	)
	local ringAt = Vector3.new(middleX, 10, laneFace + laneSide * 0.4)
	local ring = block("Aro", Vector3.new(0.9, 5.5, 5.5), CFrame.new(ringAt) * ALONG_Z, LIMESTONE_LIGHT, nil, ruins)
	ring.Shape = Enum.PartType.Cylinder
	decor(ring)
	local hole = block(
		"Aro",
		Vector3.new(1.1, 2.6, 2.6),
		CFrame.new(ringAt) * ALONG_Z,
		SHADOW,
		Enum.Material.SmoothPlastic,
		ruins
	)
	hole.Shape = Enum.PartType.Cylinder
	decor(hole)
end

-- Muro en ruinas entre el juego de pelota y la base: tres tramos de alturas distintas (ninguno al
-- alcance de un salto), remate oscuro, glifos tallados en las dos caras y cascotes al pie.
local function buildRuinWall(ruins: Folder, side: number, z: number, laneSide: number)
	local cuts = { COURT_END, 97, 113, LANE_WALL_END }
	local heights = { LANE_WALL_HEIGHT, 11, 12.5 }
	for index, height in heights do
		local x1, x2 = side * cuts[index], side * cuts[index + 1]
		between("MuroCarril", x1, z - 2, x2, z + 2, 0, height, tone(LIMESTONE, 0.1), ruins)
		decor(
			block(
				"Remate",
				Vector3.new(math.abs(x2 - x1) + 0.2, 0.6, 4.6),
				CFrame.new((x1 + x2) / 2, height + 0.1, z),
				LIMESTONE_DARK,
				nil,
				ruins
			)
		)
	end
	local glyphX = side * (cuts[2] + cuts[3]) / 2
	for _, faceSign in { -1, 1 } do
		local faceZ = z + faceSign * 2
		decor(
			block(
				"Glifo",
				Vector3.new(4.5, 4.5, 0.4),
				CFrame.new(glyphX, 6, faceZ + faceSign * 0.1),
				LIMESTONE_DARK,
				nil,
				ruins
			)
		)
		decor(
			block(
				"Glifo",
				Vector3.new(3, 3, 0.2),
				CFrame.new(glyphX, 6, faceZ + faceSign * 0.35),
				LIMESTONE_LIGHT,
				nil,
				ruins
			)
		)
		decor(
			block(
				"Glifo",
				Vector3.new(1, 1, 0.2),
				CFrame.new(glyphX + 0.5, 6.4, faceZ + faceSign * 0.5),
				SHADOW,
				Enum.Material.SmoothPlastic,
				ruins
			)
		)
	end
	for _, spot in { 88, 122 } do
		block(
			"Cascote",
			Vector3.new(2.6, 1.5, 2),
			CFrame.new(side * spot, 0.6, z + laneSide * 3.5) * CFrame.Angles(0.1, rng:NextNumber(0, math.pi), 0.15),
			tone(LIMESTONE, 0.15),
			nil,
			ruins
		)
	end
end

-- Muros de ruinas entre el carril y los pasillos, coberturas y los muros que cierran los pasillos en
-- 1v1 y 2v2.
local function buildLanes(folder: Folder)
	local ruins = Instance.new("Folder")
	ruins.Name = "Ruinas"
	local closers = Instance.new("Folder")
	closers.Name = "SideWalls"
	-- Estelas de frente a las bases (sus caras anchas miran a ±X).
	local facingX = CFrame.Angles(0, math.rad(90), 0)
	for _, z in { -LANE_WALL_Z, LANE_WALL_Z } do
		local laneSide = if z > 0 then -1 else 1
		for _, side in { -1, 1 } do
			buildCourtWall(ruins, side, z, laneSide)
			buildRuinWall(ruins, side, z, laneSide)
			-- Cierres: el hueco de la base y la mitad del hueco del centro, como tres hiladas de
			-- sillares (cada una es una pieza de SideWalls).
			for _, span in { { "CierreBase", LANE_WALL_END, BASE_INNER_X }, { "CierreCentro", 0, LANE_WALL_GAP } } do
				local name, from, to = span[1] :: string, span[2] :: number, span[3] :: number
				for course = 1, 3 do
					local height = LANE_WALL_HEIGHT / 3
					local stones = block(
						name,
						Vector3.new(to - from + 0.4, height, 4),
						CFrame.new(side * (from + to) / 2, (course - 0.5) * height, z)
							* CFrame.Angles(0, math.rad(if course % 2 == 0 then 0.6 else -0.6), 0),
						tone(LIMESTONE_DARK, 0.15),
						nil,
						closers
					)
					stones.Material = Enum.Material.Cobblestone
				end
			end
		end
	end
	-- Juego de pelota: marcador de piedra en el suelo y la pelota de hule olvidada.
	for _, side in { -1, 1 } do
		local courtMarker = block(
			"Marcador",
			Vector3.new(0.12, 5, 5),
			CFrame.new(side * (LANE_WALL_GAP + COURT_END) / 2, 0.3, 0) * UPRIGHT,
			LIMESTONE_DARK,
			nil,
			ruins
		)
		courtMarker.Shape = Enum.PartType.Cylinder
		decor(courtMarker)
	end
	-- La pelota choca (es lo bastante baja para que subirse a ella no lleve a ningún sitio).
	ball("Pelota", 2.6, Vector3.new(42, 1.3, 12), Color3.fromRGB(45, 32, 26), Enum.Material.Rubber, ruins)

	for _, side in { -1, 1 } do
		-- Coberturas del carril central: altar bajo (no se rompe) y estelas, simétricos.
		block("AltarBajo", Vector3.new(4, 3.4, 20), CFrame.new(side * 80, 1.7, 0), LIMESTONE, nil, ruins)
		block("AltarBajo", Vector3.new(5, 0.8, 21), CFrame.new(side * 80, 3.8, 0), LIMESTONE_DARK, nil, ruins)
		for _, zSign in { -1, 1 } do
			block(
				"AltarBajo",
				Vector3.new(5, 5, 3),
				CFrame.new(side * 80, 2.5, zSign * 10.5),
				LIMESTONE_DARK,
				nil,
				ruins
			)
		end
		for _, spot in { Vector2.new(58, 18), Vector2.new(58, -18), Vector2.new(108, 14), Vector2.new(108, -14) } do
			stela(ruins, CFrame.new(side * spot.X, 0, spot.Y) * facingX, 12)
		end
		-- Pasillos laterales: estela, columna rota, estela inclinada, columna caída, cactus y matas.
		for _, z in { -1, 1 } do
			stela(ruins, CFrame.new(side * 40, 0, z * 70) * facingX, 15)
			brokenColumn(ruins, Vector3.new(side * 95, 0, z * 60), 16)
			stela(
				ruins,
				CFrame.new(side * 120, -0.6, z * 82) * facingX * CFrame.Angles(math.rad(7) * z, 0, math.rad(5) * side),
				14
			)
			fallenColumn(ruins, Vector3.new(side * 66, 0, z * 78), math.rad(25 * side * z))
			for _, spot in { Vector2.new(22, 86), Vector2.new(75, 44), Vector2.new(138, 66) } do
				cactus(ruins, Vector3.new(side * spot.X, 0, z * spot.Y), rng:NextNumber(9, 14))
			end
			for _, spot in { Vector2.new(52, 88), Vector2.new(108, 46), Vector2.new(165, 86) } do
				dryBush(ruins, Vector3.new(side * spot.X, 0, z * spot.Y))
			end
		end
	end
	ruins.Parent = folder
	closers.Parent = folder
end

-- Horizonte: dunas medio enterradas y mesetas a franjas fuera del cañón, y arena que vuela.
local function buildBackdrop(folder: Folder)
	local backdrop = Instance.new("Folder")
	backdrop.Name = "Horizonte"
	local duneCount = 14
	for index = 1, duneCount do
		local angle = index / duneCount * 2 * math.pi + rng:NextNumber(-0.15, 0.15)
		local radius = rng:NextNumber(300, 460)
		local at = Vector3.new(math.cos(angle) * radius * 1.3, 0, math.sin(angle) * radius)
		local dune = block(
			"Duna",
			Vector3.new(rng:NextNumber(160, 260), rng:NextNumber(40, 80), rng:NextNumber(90, 140)),
			CFrame.new(at) * CFrame.Angles(0, -angle + math.pi / 2 + rng:NextNumber(-0.4, 0.4), 0),
			tone(SAND, 0.08),
			Enum.Material.Sand,
			backdrop
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = dune
		decor(dune)
	end
	local mesaCount = 7
	for index = 1, mesaCount do
		local angle = (index + 0.5) / mesaCount * 2 * math.pi + rng:NextNumber(-0.2, 0.2)
		local radius = rng:NextNumber(540, 660)
		local at = Vector3.new(math.cos(angle) * radius * 1.2, 0, math.sin(angle) * radius)
		local size = Vector3.new(rng:NextNumber(70, 140), rng:NextNumber(60, 130), rng:NextNumber(60, 110))
		local frame = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		decor(
			block(
				"Talud",
				Vector3.new(size.X * 1.25, size.Y * 0.35, size.Z * 1.25),
				frame * CFrame.new(0, size.Y * 0.175, 0),
				tone(CANYON, 0.1),
				Enum.Material.Sandstone,
				backdrop
			)
		)
		decor(
			block(
				"Meseta",
				size,
				frame * CFrame.new(0, size.Y / 2, 0),
				tone(CANYON, 0.1),
				Enum.Material.Sandstone,
				backdrop
			)
		)
		decor(
			block(
				"Franja",
				Vector3.new(size.X + 1, size.Y * 0.08, size.Z + 1),
				frame * CFrame.new(0, size.Y * 0.62, 0),
				CANYON_DARK,
				Enum.Material.Sandstone,
				backdrop
			)
		)
	end
	-- Arena que vuela por encima de la arena (como en la isla de las Dunas del Lobby), muy suave para
	-- no tapar a nadie.
	local dustArea = block(
		"Polvareda",
		Vector3.new(HALF_LENGTH * 2 + 40, 30, HALF_WIDTH * 2 + 40),
		CFrame.new(0, 50, 0),
		SAND,
		Enum.Material.SmoothPlastic,
		backdrop
	)
	dustArea.Transparency = 1
	decor(dustArea)
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Arena"
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.Color = ColorSequence.new(Color3.fromRGB(230, 185, 130))
	dust.Size = NumberSequence.new(30, 60)
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(10, 14)
	dust.Rate = 2
	dust.Speed = NumberRange.new(0)
	dust.Acceleration = Vector3.new(0, 0, 2)
	dust.RotSpeed = NumberRange.new(-8, 8)
	dust.Parent = dustArea
	backdrop.Parent = folder
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
end

-- true si el place ya tiene el escenario de esta versión.
function ArenaBuilder.isBuilt(): boolean
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	return folder ~= nil and folder:GetAttribute("Version") == VERSION
end

function ArenaBuilder.build(options: Options?)
	local force = options and options.force
	if not force and game.PlaceId ~= Config.PlaceIds.Dunas then
		warn(
			`[ArenaBuilder] Este place ({game.PlaceId}) no es Dunas ({Config.PlaceIds.Dunas}). `
				.. "Abre Dunas o usa build({ force = true })."
		)
		return
	end
	clearOld()
	rng = Random.new(SEED)
	applyLighting()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("Version", VERSION)
	buildGround(folder)
	buildBoundary(folder)
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	buildBase(bases, "Jaguar", -1)
	buildBase(bases, "Quetzal", 1)
	bases.Parent = folder
	buildPyramid(folder)
	buildAltar(folder)
	buildLanes(folder)
	buildBackdrop(folder)
	folder.Parent = Workspace
	print("[ArenaBuilder] ¡Arena lista!")
end

return ArenaBuilder
