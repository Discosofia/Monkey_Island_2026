--!strict
-- Campo de tiro del Lobby (Fase 23): un recinto cerrado de 90 × 182 studs para probar la puntería de
-- las armas a distancia. Forma, medidas y colores salen de la maqueta aprobada
-- (tools/maquetas/campo-de-tiro.html); las coordenadas de abajo son las de la maqueta, locales al
-- recinto: suelo en y = 0, x de -45 a 45, z de -70 (pared del fondo) a 112 (pared trasera), línea de
-- tiro en z = 66 y el tirador mirando hacia -z. Todo pasa por ORIGIN, así que el recinto queda lejos
-- del Lobby, en el aire y fuera de vista.
--
-- Lo construye el servidor del Lobby al arrancar si falta Workspace.CampoDeTiro o es de otra versión
-- (LobbyWorldService). Para dejarlo fijo en el place, en modo edición:
--
--   require(game.ServerScriptService.Server.World.RangeBuilder).build()
--
-- Crea: suelo con rejilla, números de distancia y línea de tiro; muros con remate de ruinas voxel y
-- bambú en las esquinas; la pared trasera con el arco de salida («Volver al Lobby»); dos pantallas de
-- ajuste (RangeScreen = "Near" / "Far", con un Frame "Grid", un Frame "Marks" vacío para las marcas
-- y un TextLabel "Readout"); diez dianas (Model con RangeTarget = true en CampoDeTiro/Dianas);
-- tres muñecos (fijo, de lado a lado y de atrás adelante, en CampoDeTiro/Munecos); obstáculos, plataforma con rampa y cañón, foso de rebotes, paneles de materiales y un
-- péndulo; la zona de preparación con bancos y cajas; dos consolas (BorrarMarcasPrompt y RondaPrompt); y el
-- Armero (Fase 24b, v8; v9: armas en horizontal con su nombre y más separadas): una pared de la zona de
-- preparación con las cuatro armas del Laboratorio colgadas, un aviso por arma (atributo "ArmeroWeapon") y
-- «Dejar arma» (ArmeroDejarPrompt), que atiende RangeShooterService.
-- Aquí todo está quieto: mueve las dianas RangeTargetService, y las marcas y la lectura de las pantallas
-- las dibuja RangeScreenController.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)
local LabWeapons = require(ReplicatedStorage.Shared.Data.LabWeapons)
local LabWeaponModels = require(ReplicatedStorage.Shared.LabWeaponModels)

local later = Strings.later

export type Options = { force: boolean? }

local FOLDER_NAME = "CampoDeTiro"
-- Sube este número al cambiar el recinto: el Lobby con una versión anterior lo reconstruye al arrancar.
local VERSION = 9
local SEED = 1717

-- Dónde está el recinto en el mundo (lejos del Lobby, que llega a unos 170 studs, y en el aire).
local ORIGIN = CFrame.new(850, 1.5, -1150) -- sobre el mar, detrás de la isla del volcán (centro (520, -700))

-- Medidas del recinto (studs, locales).
local HALF_WIDTH = 45
local BACK_Z = -70 -- cara interior de la pared del fondo
local REAR_Z = 112 -- cara interior de la pared trasera
local FIRE_Z = 66 -- línea de tiro
local LENGTH = REAR_Z - BACK_Z
local MID_Z = (REAR_Z + BACK_Z) / 2
-- Todos los muros suben igual para que desde dentro no se vea dónde está el recinto.
local SIDE_HEIGHT = 64
local FAR_HEIGHT = 64
local REAR_HEIGHT = 64
local FOOTING = 24 -- lo que se entierran muros y losa bajo el suelo: llegan al fondo del mar
local GRID_STEP = 2
local GRID_THICK_EVERY = 5 -- una línea gruesa cada 10 studs
local DISTANCE_MARKS = { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130 }
-- Dónde aparece el jugador: en la zona de preparación, unos 5 studs detrás de la línea.
local ENTRY_Z = FIRE_Z + 5
local ENTRY_HEIGHT = 3.5
local ENTRY_SPREAD = 3 -- separación entre jugadores que llegan seguidos

-- Pantalla de ajuste: 1920 × 1080 píxeles, 16 × 9 celdas de 120 píxeles.
local SCREEN_W = 1920
local SCREEN_H = 1080
local CELL = 120
local READOUT_H = 60

local STONE = { 0x565d66, 0x5e656f, 0x4b525b, 0x666d77 }
local RING_COLORS = { 0xd9392b, 0xf2f2ee, 0xd9392b, 0xff8a1f }
local RING_FRACTIONS = { 1, 0.75, 0.5, 0.25 }
local RING_STEP = 0.1 -- cada anillo interior sobresale un poco, para que no parpadee con el de fuera

type TargetSpec = {
	x: number,
	z: number,
	center: number, -- altura del centro
	radius: number,
	kind: string,
	tower: boolean?,
	post: boolean?,
	-- Colgada de la cara interior del muro izquierdo: sin poste, girada hacia el centro de la línea de tiro.
	wall: boolean?,
	index: number?,
}

-- Las diez dianas de la maqueta.
local TARGETS: { TargetSpec } = {
	{ x = 9, z = 51, center = 3, radius = 3, kind = "fixed" }, -- 15 studs, a ras de suelo
	{ x = -34, z = 16, center = 8, radius = 3.5, kind = "fixed", wall = true }, -- 50 studs, 8 de altura
	{ x = -38, z = -4, center = 16, radius = 4, kind = "fixed", wall = true }, -- 16 de altura
	{ x = -30, z = -20, center = 28, radius = 4.5, kind = "fixed", wall = true }, -- 28 de altura
	{ x = 29, z = 44, center = 6, radius = 3, kind = "rail" }, -- móvil en raíl
	{ x = -38, z = 4, center = 9, radius = 3.5, kind = "spin" }, -- giratoria (z = 4: deja sitio a la diana de la pared)
	{ x = 24, z = -10, center = 3, radius = 3, kind = "popup", post = false, index = 0 },
	{ x = 31, z = -10, center = 3, radius = 3, kind = "popup", post = false, index = 1 },
	{ x = 38, z = -10, center = 3, radius = 3, kind = "popup", post = false, index = 2 },
	{ x = -38, z = -54, center = 36, radius = 6, kind = "far", wall = true }, -- a 120 studs de la línea
}

local RangeBuilder = {}

local function hex(value: number): Color3
	return Color3.fromRGB(bit32.rshift(value, 16), bit32.band(bit32.rshift(value, 8), 255), bit32.band(value, 255))
end

-- Posición del recinto en el mundo.
local function place(x: number, y: number, z: number): CFrame
	return ORIGIN * CFrame.new(x, y, z)
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

-- Caja con la base en y0 y el centro en (x, z), como la «B» de la maqueta.
local function box(
	parent: Instance,
	name: string,
	x: number,
	y0: number,
	z: number,
	width: number,
	height: number,
	depth: number,
	color: number,
	material: Enum.Material,
	yaw: number?
): Part
	return newPart(
		name,
		Vector3.new(width, height, depth),
		place(x, y0 + height / 2, z) * CFrame.Angles(0, yaw or 0, 0),
		hex(color),
		material,
		parent
	)
end

-- Cilindro entre dos puntos locales del recinto.
local function cylinder(
	parent: Instance,
	name: string,
	diameter: number,
	from: Vector3,
	to: Vector3,
	color: number,
	material: Enum.Material
): Part
	local a = ORIGIN:PointToWorldSpace(from)
	local b = ORIGIN:PointToWorldSpace(to)
	local direction = b - a
	-- Con un tramo vertical, lookAt necesita otro vector "arriba".
	local up = if math.abs(direction.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local part = newPart(
		name,
		Vector3.new(direction.Magnitude, diameter, diameter),
		CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0),
		hex(color),
		material,
		parent
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local point = Instance.new("PointLight")
	point.Color = color
	point.Range = range
	point.Brightness = brightness
	point.Parent = parent
end

local function folder(parent: Instance, name: string): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- SurfaceGui con la escala de píxeles por stud dada, siempre legible (sin la luz del mundo).
local function surface(part: BasePart, face: Enum.NormalId, pixelsPerStud: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0
	gui.Parent = part
	return gui
end

local function textLabel(parent: Instance, text: string, color: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = text
	label.TextColor3 = hex(color)
	label.Font = font
	label.Parent = parent
	return label
end

-- Rótulo de pared: tablilla oscura con texto. "face" es la cara que se lee (Back mira a +z, Front a -z,
-- Left a -x, Right a +x); "at" es el centro, local al recinto.
local function sign(
	parent: Instance,
	text: string,
	width: number,
	height: number,
	at: Vector3,
	face: Enum.NormalId,
	color: number?
)
	local alongX = face == Enum.NormalId.Front or face == Enum.NormalId.Back
	local size = if alongX then Vector3.new(width, height, 0.1) else Vector3.new(0.1, height, width)
	local part =
		decor(newPart("Rotulo", size, place(at.X, at.Y, at.Z), hex(0x0a0e12), Enum.Material.SmoothPlastic, parent))
	part.Transparency = 0.18
	local label = textLabel(surface(part, face, 40), text, color or 0xffd9b8, Enum.Font.GothamBold)
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.Parent = label
end

---------------------------------------------------------------------------------------------------
-- Suelo

local FLOOR_PPS = 20

-- Plano invisible sobre el suelo para dibujar texto en él. La cara Top de Roblox gira los ejes del
-- SurfaceGui, así que la pieza se tumba para que su cara Front mire hacia arriba, con la derecha del
-- texto hacia +x y su parte de arriba hacia -z: se lee derecho desde la línea de tiro mirando a -z.
local function floorGui(parent: Instance, name: string, x: number, z: number, width: number, depth: number): SurfaceGui
	local at = place(x, 0.2, z).Position
	local part = decor(
		newPart(
			name,
			Vector3.new(width, depth, 0.02),
			CFrame.fromMatrix(at, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0)),
			hex(0x2a3137),
			Enum.Material.SmoothPlastic,
			parent
		)
	)
	part.Transparency = 1
	return surface(part, Enum.NormalId.Front, FLOOR_PPS)
end

local function buildFloor(root: Instance)
	local floor = folder(root, "Suelo")
	local width = HALF_WIDTH * 2
	-- Losa sólida: no se puede caer.
	box(floor, "Losa", 0, -FOOTING, MID_Z, width, FOOTING, LENGTH, 0x343c43, Enum.Material.SmoothPlastic)

	-- Rejilla: líneas finas cada 2 studs y gruesas cada 10.
	for index = 0, width / GRID_STEP do
		local thick = index % GRID_THICK_EVERY == 0
		local x = -HALF_WIDTH + index * GRID_STEP
		local line = box(
			floor,
			"LineaX",
			x,
			0,
			MID_Z,
			if thick then 0.33 else 0.17,
			if thick then 0.06 else 0.04,
			LENGTH,
			if thick then 0x5a6975 else 0x3a444c,
			Enum.Material.SmoothPlastic
		)
		decor(line)
	end
	for index = 0, LENGTH / GRID_STEP do
		local thick = index % GRID_THICK_EVERY == 0
		local z = BACK_Z + index * GRID_STEP
		local line = box(
			floor,
			"LineaZ",
			0,
			0,
			z,
			width,
			if thick then 0.06 else 0.04,
			if thick then 0.33 else 0.17,
			if thick then 0x5a6975 else 0x3a444c,
			Enum.Material.SmoothPlastic
		)
		decor(line)
	end

	-- Zona de preparación (detrás de la línea): un velo oscuro sobre el suelo y la rejilla.
	local prepDepth = REAR_Z - FIRE_Z
	local veil = decor(
		box(
			floor,
			"ZonaDePreparacion",
			0,
			0.08,
			FIRE_Z + prepDepth / 2,
			width,
			0.02,
			prepDepth,
			0x0a0d10,
			Enum.Material.SmoothPlastic
		)
	)
	veil.Transparency = 0.62

	-- Franja naranja de la línea de tiro.
	decor(box(floor, "LineaDeTiro", 0, 0, FIRE_Z, width, 0.14, 0.83, 0xff7a1a, Enum.Material.SmoothPlastic))

	-- Números de distancia desde la línea, a los dos lados, y una marca corta en el centro.
	for _, distance in DISTANCE_MARKS do
		local lineZ = FIRE_Z - distance
		local gui = floorGui(floor, `Distancia{distance}`, 0, lineZ - 1, width, 3)
		local top = lineZ - 2.5 -- borde de arriba de la tablilla (hacia -z)
		local tick = Instance.new("Frame")
		tick.Name = "Marca"
		tick.BorderSizePixel = 0
		tick.BackgroundColor3 = hex(0x6f808c)
		tick.Position = UDim2.fromOffset(width * FLOOR_PPS / 2 - 60, (lineZ - top) * FLOOR_PPS - 3)
		tick.Size = UDim2.fromOffset(120, 6)
		tick.Parent = gui
		for _, side in { -1, 1 } do
			local label = textLabel(gui, tostring(distance), 0x9fb0bb, Enum.Font.RobotoMono)
			label.Size = UDim2.fromOffset(200, 50)
			label.TextSize = 50
			label.Position = if side < 0
				then UDim2.fromOffset(86, 5)
				else UDim2.fromOffset(width * FLOOR_PPS - 86 - 200, 5)
			label.TextXAlignment = if side < 0 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		end
	end

	-- Rótulos del suelo.
	local fireGui = floorGui(floor, "RotuloLinea", 0, FIRE_Z + 4, 60, 6)
	local fireLabel = textLabel(fireGui, later("LÍNEA DE TIRO"), 0xffcfa8, Enum.Font.GothamBold)
	fireLabel.Size = UDim2.fromScale(1, 1)
	fireLabel.TextScaled = false
	fireLabel.TextSize = 100
	fireLabel.TextWrapped = false
	local prepGui = floorGui(floor, "RotuloPreparacion", 0, FIRE_Z + 28, 80, 6)
	local prepLabel = textLabel(prepGui, later("ZONA DE PREPARACIÓN"), 0x6f808c, Enum.Font.GothamBold)
	prepLabel.Size = UDim2.fromScale(1, 1)
	prepLabel.TextScaled = false
	prepLabel.TextSize = 100
	prepLabel.TextWrapped = false
end

---------------------------------------------------------------------------------------------------
-- Muros, ruinas y bambú

-- Remate de ruinas: bloques de 2 con alturas de 1 a 3 y huecos, sobre la línea de (x0, z0) a (x1, z1).
local function crown(parent: Instance, rng: Random, from: Vector2, to: Vector2, base: number)
	local count = math.round((to - from).Magnitude / 2)
	for index = 0, count - 1 do
		if rng:NextNumber() < 0.35 then
			continue
		end
		local at = from:Lerp(to, index / count)
		local height = 1 + math.floor(rng:NextNumber() * 3)
		local color = STONE[rng:NextInteger(1, #STONE)]
		decor(box(parent, "Ruina", at.X, base, at.Y, 2, height, 2, color, Enum.Material.SmoothPlastic))
	end
end

local function buildWalls(root: Instance)
	local walls = folder(root, "Muros")
	local stone = 0x565d66
	local slate = Enum.Material.SmoothPlastic -- sin textura
	local wood = Enum.Material.Wood
	local sideLength = LENGTH + 2
	-- Laterales, fondo y pared trasera (baja, con la entrada abierta en el centro).
	box(walls, "MuroIzquierdo", -HALF_WIDTH - 1, -FOOTING, MID_Z, 2, SIDE_HEIGHT + FOOTING, sideLength, stone, slate)
	box(walls, "MuroDerecho", HALF_WIDTH + 1, -FOOTING, MID_Z, 2, SIDE_HEIGHT + FOOTING, sideLength, stone, slate)
	box(walls, "MuroFondo", 0, -FOOTING, BACK_Z - 1, HALF_WIDTH * 2 + 4, FAR_HEIGHT + FOOTING, 2, stone, slate)
	box(walls, "MuroTrasero", 0, -FOOTING, REAR_Z + 1, HALF_WIDTH * 2 + 4, REAR_HEIGHT + FOOTING, 2, stone, slate)

	-- Arco de salida al Lobby, en el centro de la pared trasera.
	local arch = folder(walls, "ArcoDeSalida")
	box(arch, "PosteIzquierdo", -6.5, 0, REAR_Z + 1, 2, 14, 2.4, 0x6a5a45, wood)
	box(arch, "PosteDerecho", 6.5, 0, REAR_Z + 1, 2, 14, 2.4, 0x6a5a45, wood)
	box(arch, "Dintel", 0, 12.6, REAR_Z + 1, 15, 2.4, 2.4, 0x6a5a45, wood)
	-- La pared trasera está cerrada: el arco es una puerta de madera y se sale con su aviso.
	box(arch, "Puerta", 0, 0, REAR_Z - 0.3, 11, 10.5, 0.6, 0x4a3a28, wood)
	sign(arch, later("Entrada del Lobby"), 10, 2, Vector3.new(0, 11.4, REAR_Z - 0.5), Enum.NormalId.Front)
	-- Zona de activación de «Volver al Lobby» (la atiende RangeService).
	local exit = decor(
		newPart(
			"Salida",
			Vector3.new(11, 10, 1),
			place(0, 5, REAR_Z + 1),
			hex(0x6a5a45),
			Enum.Material.SmoothPlastic,
			arch
		)
	)
	exit.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CampoSalidaPrompt"
	prompt.ActionText = later("Volver al Lobby")
	prompt.ObjectText = later("Campo de tiro")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.Parent = exit

	-- Remate de ruinas voxel (semilla fija) y bambú en las cuatro esquinas.
	local ruins = folder(root, "Ruinas")
	local rng = Random.new(SEED)
	local edge = HALF_WIDTH + 1
	crown(ruins, rng, Vector2.new(-edge, REAR_Z + 1), Vector2.new(edge, REAR_Z + 1), REAR_HEIGHT)
	crown(ruins, rng, Vector2.new(-edge, BACK_Z - 1), Vector2.new(edge, BACK_Z - 1), FAR_HEIGHT)
	crown(ruins, rng, Vector2.new(-edge, BACK_Z), Vector2.new(-edge, REAR_Z), SIDE_HEIGHT)
	crown(ruins, rng, Vector2.new(edge, BACK_Z), Vector2.new(edge, REAR_Z), SIDE_HEIGHT)

	local bamboo = folder(root, "Bambu")
	for _, corner in
		{
			Vector2.new(-edge, BACK_Z - 1),
			Vector2.new(edge, BACK_Z - 1),
			Vector2.new(-edge, REAR_Z + 1),
			Vector2.new(edge, REAR_Z + 1),
		}
	do
		local signX = if corner.X >= 0 then 1 else -1
		local signZ = if corner.Y >= 0 then 1 else -1
		for k = 0, 2 do
			local x = corner.X + (k - 1) * 1.3 * signX
			local z = corner.Y + (k % 2) * 1.1 * signZ
			local top = REAR_HEIGHT + 4 + k * 2.8
			decor(
				cylinder(bamboo, "Cana", 1, Vector3.new(x, 0, z), Vector3.new(x, top, z), 0xd8c97a, Enum.Material.Wood)
			)
			for ring = 3, REAR_HEIGHT + 4, 6 do
				decor(
					cylinder(
						bamboo,
						"Nudo",
						1.24,
						Vector3.new(x, ring + k * 1.4 - 1, z),
						Vector3.new(x, ring + k * 1.4 - 0.65, z),
						0xa89a4c,
						Enum.Material.Wood
					)
				)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Pantallas de ajuste

-- Color CSS hsl(hue°, sat, light) como Color3.
local function hsl(hue: number, saturation: number, lightness: number): Color3
	local value = lightness + saturation * math.min(lightness, 1 - lightness)
	local sat = if value == 0 then 0 else 2 * (1 - lightness / value)
	return Color3.fromHSV(hue / 360, sat, value)
end

local function rect(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	width: number,
	height: number,
	color: Color3
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(width, height)
	frame.Parent = parent
	return frame
end

-- La malla de la pantalla: celdas de tono por columna, líneas blancas, círculos y cruz de la mira.
local function buildGrid(gui: SurfaceGui)
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BorderSizePixel = 0
	grid.BackgroundColor3 = Color3.new(0, 0, 0)
	grid.Size = UDim2.fromOffset(SCREEN_W, SCREEN_H)
	grid.ClipsDescendants = true
	grid.Parent = gui

	local columns = SCREEN_W // CELL
	local rows = SCREEN_H // CELL
	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			local dark = (column + row) % 2 == 0
			local cell = textLabel(
				grid,
				` {string.char(65 + column)}{row + 1}`,
				if dark then 0xffffff else 0x101010,
				Enum.Font.RobotoMono
			)
			cell.Name = "Celda"
			cell.BackgroundTransparency = 0
			cell.BackgroundColor3 = hsl(column * 22.5, if dark then 0.85 else 0.7, if dark then 0.36 else 0.66)
			cell.Position = UDim2.fromOffset(column * CELL, row * CELL)
			cell.Size = UDim2.fromOffset(CELL, CELL)
			cell.TextSize = 22
			cell.TextXAlignment = Enum.TextXAlignment.Left
			cell.TextYAlignment = Enum.TextYAlignment.Top
		end
	end

	local white = Color3.new(1, 1, 1)
	for index = 0, columns do
		rect(grid, "LineaV", index * CELL - 1, 0, 2, SCREEN_H, white)
	end
	for index = 0, rows do
		rect(grid, "LineaH", 0, index * CELL - 1, SCREEN_W, 2, white)
	end

	-- Cuatro círculos concéntricos con borde negro y blanco (el negro, de 6 px, y el blanco, de 2, centrados
	-- en el mismo radio: el trazo de UIStroke va por fuera del Frame).
	local strokes = {
		{ inset = 3, thickness = 6, color = Color3.new(0, 0, 0) },
		{ inset = 1, thickness = 2, color = white },
	}
	for _, radius in { 120, 240, 360, 480 } do
		for _, ring in strokes do
			local circle = Instance.new("Frame")
			circle.Name = "Circulo"
			circle.BackgroundTransparency = 1
			circle.BorderSizePixel = 0
			circle.AnchorPoint = Vector2.new(0.5, 0.5)
			circle.Position = UDim2.fromOffset(SCREEN_W / 2, SCREEN_H / 2)
			circle.Size = UDim2.fromOffset((radius - ring.inset) * 2, (radius - ring.inset) * 2)
			circle.Parent = grid
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = circle
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Thickness = ring.thickness
			stroke.Color = ring.color
			stroke.Parent = circle
		end
	end

	-- Cruz central negra con borde blanco y punto naranja.
	local black = Color3.new(0, 0, 0)
	rect(grid, "CruzH", 0, SCREEN_H / 2 - 4, SCREEN_W, 8, black)
	rect(grid, "CruzV", SCREEN_W / 2 - 4, 0, 8, SCREEN_H, black)
	rect(grid, "CruzHBlanca", 0, SCREEN_H / 2 - 1.5, SCREEN_W, 3, white)
	rect(grid, "CruzVBlanca", SCREEN_W / 2 - 1.5, 0, 3, SCREEN_H, white)
	rect(grid, "PuntoBorde", SCREEN_W / 2 - 10, SCREEN_H / 2 - 10, 20, 20, black)
	rect(grid, "Punto", SCREEN_W / 2 - 6, SCREEN_H / 2 - 6, 12, 12, hex(0xff7a1a))
end

type ScreenSpec = {
	id: string, -- "Near" / "Far"
	name: string,
	tag: string,
	width: number,
	height: number,
	base: number, -- altura de la base
	-- Centro del cuerpo de la pantalla en x y z, y la cara que se lee.
	x: number,
	z: number,
	face: Enum.NormalId,
}

local function buildScreen(parent: Instance, spec: ScreenSpec)
	local alongX = spec.face == Enum.NormalId.Back
	local centerY = spec.base + spec.height / 2
	-- La normal de la pantalla (Right = +x, Back = +z) para colocar el bastidor y el rótulo.
	local normal = if alongX then Vector3.zAxis else Vector3.xAxis
	local center = Vector3.new(spec.x, centerY, spec.z)
	local function oriented(width: number, height: number, thickness: number): Vector3
		return if alongX then Vector3.new(width, height, thickness) else Vector3.new(thickness, height, width)
	end

	-- Bastidor oscuro, un poco más grande y detrás.
	newPart(
		spec.name .. "Bastidor",
		oriented(spec.width + 2, spec.height + 1.2, 0.6),
		place(center.X - normal.X * 0.1, center.Y, center.Z - normal.Z * 0.1),
		hex(0x20262c),
		Enum.Material.Metal,
		parent
	)
	local screen = newPart(
		spec.name,
		oriented(spec.width, spec.height, 1),
		place(center.X, center.Y, center.Z),
		hex(0x15191d),
		Enum.Material.SmoothPlastic,
		parent
	)
	screen:SetAttribute("RangeScreen", spec.id)
	screen:SetAttribute("ScreenWidth", spec.width)
	screen:SetAttribute("ScreenHeight", spec.height)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Pantalla"
	gui.Face = spec.face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(SCREEN_W, SCREEN_H)
	gui.LightInfluence = 0
	gui.Parent = screen
	buildGrid(gui)

	-- Capa vacía para las marcas de los disparos (23c).
	local marks = Instance.new("Frame")
	marks.Name = "Marks"
	marks.BackgroundTransparency = 1
	marks.BorderSizePixel = 0
	marks.Size = UDim2.fromOffset(SCREEN_W, SCREEN_H)
	marks.ZIndex = 2
	marks.Parent = gui

	-- Franja de lectura abajo.
	local readout =
		textLabel(gui, later("Dispara a la cruz central para medir el desvío"), 0xffffff, Enum.Font.RobotoMono)
	readout.Name = "Readout"
	readout.BackgroundTransparency = 0.16
	readout.BackgroundColor3 = hex(0x080a0c)
	readout.Position = UDim2.fromOffset(0, SCREEN_H - READOUT_H)
	readout.Size = UDim2.fromOffset(SCREEN_W, READOUT_H)
	readout.TextSize = 30
	readout.TextXAlignment = Enum.TextXAlignment.Left
	readout.ZIndex = 3
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 24)
	padding.Parent = readout

	-- Rótulo bajo la pantalla.
	local tagAt = Vector3.new(spec.x + normal.X * 0.6, 1.6, spec.z + normal.Z * 0.6)
	sign(parent, spec.tag, 12, 2.4, tagAt, spec.face, 0xffcfa8)
end

local function buildScreens(root: Instance)
	local screens = folder(root, "Pantallas")
	-- Corta: pegada a la pared izquierda, mirando a +x, con el centro a la altura de la línea de tiro.
	buildScreen(screens, {
		id = "Near",
		name = "PantallaCorta",
		tag = later("PANTALLA CORTA"),
		width = 32,
		height = 18,
		base = 4,
		x = -HALF_WIDTH + 0.5,
		z = FIRE_Z,
		face = Enum.NormalId.Right,
	})
	-- Larga: en la pared del fondo, mirando a +z.
	buildScreen(screens, {
		id = "Far",
		name = "PantallaLarga",
		tag = later("PANTALLA LARGA"),
		width = 64,
		height = 36,
		base = 4,
		x = 0,
		z = BACK_Z + 0.5,
		face = Enum.NormalId.Back,
	})
end

---------------------------------------------------------------------------------------------------
-- Dianas

-- Sitio de una diana de pared: guiñada hacia el centro de la línea de tiro y x tal que su canto más
-- cercano queda a un palmo del muro izquierdo (el disco es plano, gira sobre el eje vertical).
local WALL_GAP = 0.8
local function wallFrame(spec: TargetSpec): (CFrame, number)
	local yaw = math.atan2(0 - spec.x, FIRE_Z - spec.z)
	local x = -HALF_WIDTH + spec.radius * math.abs(math.cos(yaw)) + WALL_GAP
	return place(x, spec.center, spec.z) * CFrame.Angles(0, yaw, 0), x
end

local function buildTarget(parent: Instance, spec: TargetSpec, number: number)
	local model = Instance.new("Model")
	model.Name = `Diana{number}`
	model:SetAttribute("RangeTarget", true)
	model:SetAttribute("Kind", spec.kind)
	model:SetAttribute("Radius", spec.radius)
	model:SetAttribute("CenterHeight", spec.center)
	if spec.kind == "rail" then
		-- Recorrido de la maqueta: ±9 studs en x a 0,8 rad/s (el movimiento llega en 23c).
		model:SetAttribute("RailAmplitude", 9)
		model:SetAttribute("RailSpeed", 0.8)
	elseif spec.kind == "spin" then
		model:SetAttribute("SpinSpeed", 1.4)
	elseif spec.kind == "popup" then
		model:SetAttribute("PopupIndex", spec.index or 0)
	end

	local frame = place(spec.x, spec.center, spec.z)
	if spec.wall then
		local wallX
		frame, wallX = wallFrame(spec)
		-- Brazo corto de metal del muro al reverso del disco; no hay poste en el suelo.
		local reach = wallX + HALF_WIDTH
		box(
			model,
			"Soporte",
			-HALF_WIDTH + reach / 2,
			spec.center - 0.25,
			spec.z,
			reach,
			0.5,
			0.5,
			0x50565d,
			Enum.Material.Metal
		)
	elseif spec.post ~= false then
		local tower = spec.tower == true
		box(
			model,
			"Poste",
			spec.x,
			0,
			spec.z - 0.5,
			if tower then 3.2 else 0.7,
			math.max(0.5, spec.center),
			0.7,
			if tower then 0x6a5a45 else 0x50565d,
			if tower then Enum.Material.Wood else Enum.Material.Metal
		)
	end
	-- Anillos: cilindros finos de radio R, 0,75 R, 0,5 R y 0,25 R (el último es el centro).
	for index, fraction in RING_FRACTIONS do
		local diameter = spec.radius * fraction * 2
		local ring = newPart(
			if index == #RING_FRACTIONS then "Bullseye" else `Anillo{index}`,
			Vector3.new(0.5, diameter, diameter),
			frame * CFrame.new(0, 0, RING_STEP * (index - 1)) * CFrame.Angles(0, math.pi / 2, 0),
			hex(RING_COLORS[index]),
			Enum.Material.SmoothPlastic,
			model
		)
		ring.Shape = Enum.PartType.Cylinder
		ring.CanCollide = false
		if index == #RING_FRACTIONS then
			model.PrimaryPart = ring
		end
	end
	model.Parent = parent
end

local function buildTargets(root: Instance)
	local targets = folder(root, "Dianas")
	for number, spec in TARGETS do
		buildTarget(targets, spec, number)
	end

	-- Carril de la diana móvil.
	box(root, "Carril", 29, 0, 44.6, 22, 0.4, 0.8, 0x50565d, Enum.Material.Metal)

	-- Carteles de altura.
	local labels = folder(root, "CartelesDeAltura")
	sign(labels, "0", 2.2, 1.6, Vector3.new(9, 7, 51.4), Enum.NormalId.Back, 0xffffff)
	-- Los de la pared izquierda cuelgan del muro, justo sobre su diana, girados hacia la línea de tiro.
	for number, text in
		{ [2] = later("8 studs"), [3] = later("16 studs"), [4] = later("28 studs"), [10] = later("120 studs") }
	do
		local spec = TARGETS[number]
		local frame = wallFrame(spec)
		local above = frame * CFrame.new(0, spec.radius + 1.2, 0.4)
		local part = decor(
			newPart(
				"Rotulo",
				Vector3.new(if number == 10 then 9 else 6, if number == 10 then 2 else 1.6, 0.1),
				above,
				hex(0x0a0e12),
				Enum.Material.SmoothPlastic,
				labels
			)
		)
		part.Transparency = 0.18
		local label = textLabel(surface(part, Enum.NormalId.Back, 40), text, 0xffffff, Enum.Font.GothamBold)
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
	end
end

---------------------------------------------------------------------------------------------------
-- Muñecos de práctica (fijo, de lado a lado y de atrás adelante)

type DummySpec = {
	name: string,
	x: number,
	z: number,
	kind: string, -- "fixed", "rail" (en x) o "depth" (en z)
	amplitude: number?,
	speed: number?,
}

-- Mismo cuerpo que Combat/TrainingDummies (poste, torso, cabeza redonda y brazos separados, para que las
-- zonas Head/Torso/Limb salgan por el nombre de la pieza), sobre una base baja. Las piezas no chocan: el
-- muñeco se mueve con PivotTo y no debe empujar a nadie. «RangeTarget» hace que la ayuda de puntería no lo
-- elija (como las dianas); RangeTargetService le da vida infinita y el movimiento.
local DUMMIES: { DummySpec } = {
	{ name = "MuniecoFijo", x = 14, z = 30, kind = "fixed" }, -- a 36 studs de la línea de tiro
	{ name = "MuniecoLateral", x = 0, z = 0, kind = "rail", amplitude = 14, speed = 0.8 }, -- a 66 studs
	{ name = "MuniecoProfundo", x = -6, z = 30, kind = "depth", amplitude = 20, speed = 0.6 }, -- de 16 a 56 studs
}

local function buildDummy(parent: Instance, spec: DummySpec)
	local model = Instance.new("Model")
	model.Name = spec.name
	model:SetAttribute("RangeTarget", true)
	model:SetAttribute("RangeDummy", true)
	model:SetAttribute("Kind", spec.kind)
	if spec.kind == "rail" then
		model:SetAttribute("RailAmplitude", spec.amplitude)
		model:SetAttribute("RailSpeed", spec.speed)
	elseif spec.kind == "depth" then
		model:SetAttribute("DepthAmplitude", spec.amplitude)
		model:SetAttribute("DepthSpeed", spec.speed)
	end
	local smooth = Enum.Material.SmoothPlastic
	local function piece(
		name: string,
		width: number,
		y0: number,
		height: number,
		depth: number,
		x: number,
		color: number
	)
		local part = box(model, name, spec.x + x, y0, spec.z, width, height, depth, color, smooth)
		part.CanCollide = false
		return part
	end
	piece("Base", 3.4, 0, 0.4, 3.4, 0, 0x4b525b)
	piece("Post", 0.6, 0.4, 2.6, 0.6, 0, 0x6e4828)
	piece("Torso", 2, 3, 2, 1, 0, 0xbea06e)
	local head = piece("Head", 1.6, 5, 1.6, 1.6, 0, 0xcdaf7d)
	head.Shape = Enum.PartType.Ball
	piece("LeftUpperArm", 0.8, 3.5, 1.6, 0.8, -1.9, 0xd2b684)
	piece("RightUpperArm", 0.8, 3.5, 1.6, 0.8, 1.9, 0xd2b684)
	local rootPart = piece("HumanoidRootPart", 2, 3, 2, 1, 0, 0x000000)
	rootPart.Transparency = 1
	model.PrimaryPart = rootPart
	model.Parent = parent
end

local function buildDummies(root: Instance)
	local group = folder(root, "Munecos")
	for _, spec in DUMMIES do
		buildDummy(group, spec)
		-- Raíl en el suelo para los que se mueven: lo que recorren más el ancho de la base.
		if spec.kind ~= "fixed" then
			local reach = (spec.amplitude or 0) * 2 + 3.4
			local alongX = spec.kind == "rail"
			decor(
				box(
					group,
					"Carril",
					spec.x,
					0,
					spec.z,
					if alongX then reach else 0.5,
					0.1,
					if alongX then 0.5 else reach,
					0x50565d,
					Enum.Material.Metal
				)
			)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Obstáculos, plataforma, foso, paneles y péndulo

local function buildObstacles(root: Instance)
	local cover = folder(root, "Obstaculos")
	local concrete = Enum.Material.Concrete
	local wood = Enum.Material.WoodPlanks
	local metal = Enum.Material.Metal
	-- nombre, x, y0, z, ancho, alto, fondo, color, material, giro
	local function add(
		name: string,
		x: number,
		y0: number,
		z: number,
		width: number,
		height: number,
		depth: number,
		color: number,
		material: Enum.Material,
		yaw: number?
	)
		box(cover, name, x, y0, z, width, height, depth, color, material, yaw)
	end
	add("Cobertura", 8, 0, 58, 5, 2.5, 1.6, 0x5c6168, concrete) -- delante de la diana de 0
	add("Caja", -8, 0, 56, 3, 3, 3, 0x8a6a3c, wood)
	add("Caja", -8, 3, 56, 3, 3, 3, 0x9b7a48, wood, 0.3)
	add("Caja", -2, 0, 56, 3, 3, 3, 0x8a6a3c, wood)
	add("Pilar", 22, 0, 48, 2, 7, 6, 0x5c6168, concrete) -- tapa parte del raíl
	add("MuroAlto", -28, 0, 26, 2, 12, 8, 0x4a4f56, concrete) -- delante de la diana de 8
	add("CoberturaMedia", -20, 0, -12, 10, 3, 1.6, 0x5c6168, concrete)
	add("CoberturaLejana", 38, 0, -40, 14, 5, 1.6, 0x5c6168, concrete)
	-- Plataforma con rampa.
	add("Plataforma", 32, 0, 58, 16, 8, 12, 0x6a5a45, concrete)
	add("PlataformaSuelo", 32, 8, 58, 16, 0.5, 12, 0x7b6a52, wood)
	-- Foso de rebotes con paredes en ángulo.
	add("FosoLateral", 22, 0, 20, 1.2, 3, 36, 0x5c6168, concrete)
	add("FosoPared", 30, 0, 20, 14, 6, 1.6, 0x9aa4ad, metal, math.rad(35))
	add("FosoPared", 39, 0, 10, 12, 6, 1.6, 0x9aa4ad, metal, math.rad(-35))
	add("FosoTope", 38, 0, 30, 8, 3, 1.6, 0x8a6a3c, wood, math.rad(15))

	-- Rampa de la plataforma: sube hacia ella (la maqueta la dibuja inclinada al revés).
	newPart(
		"Rampa",
		Vector3.new(13, 0.8, 4),
		place(18.5, 3.9, 58) * CFrame.Angles(0, 0, math.atan(8 / 11.5)),
		hex(0x7b6a52),
		wood,
		cover
	)

	-- Cañón de pelotas (RangeBallService): base y tubo apuntando a -z, elevado 25 grados. «Boca» es una
	-- pieza invisible en la punta del tubo: de ella salen las pelotas, en la dirección de su cara frontal.
	local cannon = folder(root, "Canon")
	local base = box(cannon, "Base", 34, 8.5, 56, 3, 1.4, 3, 0x30363c, metal)
	local muzzle = Vector3.new(0, math.sin(math.rad(25)), -math.cos(math.rad(25)))
	local middle = Vector3.new(34, 10.6, 54.2)
	decor(cylinder(cannon, "Tubo", 2, middle - muzzle * 2.25, middle + muzzle * 2.25, 0x8e98a2, metal))
	local mouthAt = middle + muzzle * 2.6
	local mouth = decor(
		newPart(
			"Boca",
			Vector3.one * 0.4,
			CFrame.lookAt(place(mouthAt.X, mouthAt.Y, mouthAt.Z).Position, ORIGIN:PointToWorldSpace(mouthAt + muzzle)),
			hex(0x30363c),
			metal,
			cannon
		)
	)
	mouth.Transparency = 1
	sign(cannon, later("Cañón de pelotas"), 9, 1.8, Vector3.new(34, 14, 56.8), Enum.NormalId.Back)
	local ballPrompt = Instance.new("ProximityPrompt")
	ballPrompt.Name = "PelotasPrompt"
	ballPrompt.ActionText = later("Ajustar el cañón")
	ballPrompt.ObjectText = later("Cañón de pelotas")
	ballPrompt.HoldDuration = 0
	ballPrompt.MaxActivationDistance = Config.Range.Balls.PanelReach
	ballPrompt.RequiresLineOfSight = false
	ballPrompt.Parent = base

	-- Paneles de materiales en el muro de la derecha: Madera, Piedra, Metal y Arena.
	local panels = folder(root, "PanelesDeMateriales")
	local materials = {
		{ later("Madera"), 0x8a5a2e, Enum.Material.Wood },
		{ later("Piedra"), 0x7d838a, Enum.Material.Slate },
		{ later("Metal"), 0x6d8aa3, Enum.Material.Metal },
		{ later("Arena"), 0xd2bd86, Enum.Material.Sand },
	}
	for index, entry in materials do
		local z = -4 - (index - 1) * 10
		local panel = box(panels, "Panel", 44.7, 1, z, 0.6, 8, 8, entry[2] :: number, entry[3] :: Enum.Material)
		panel:SetAttribute("PanelMaterial", (entry[3] :: Enum.Material).Name)
		sign(panels, entry[1] :: string, 6, 1.4, Vector3.new(44.3, 10.2, z), Enum.NormalId.Left)
	end

	-- Péndulo, quieto (se mueve en 23c): poste, travesaño, varilla y bola roja colgando del pivote.
	local pendulum = Instance.new("Model")
	pendulum.Name = "Pendulo"
	box(pendulum, "Poste", -14, 0, 52, 0.8, 18, 0.8, 0x50565d, metal)
	box(pendulum, "Travesano", -14, 17.6, 52, 3, 0.8, 0.8, 0x50565d, metal)
	box(pendulum, "Varilla", -14, 5.6, 52, 0.3, 11.5, 0.3, 0xb7bec6, metal)
	box(pendulum, "Bola", -14, 3.6, 52, 3, 3, 3, 0xd9392b, Enum.Material.SmoothPlastic)
	local pivot = decor(newPart("Pivote", Vector3.one * 0.3, place(-14, 17.6, 52), hex(0x50565d), metal, pendulum))
	pivot.Transparency = 1
	pendulum.PrimaryPart = pivot
	pendulum.Parent = root
end

---------------------------------------------------------------------------------------------------
-- Zona de preparación y luces

local function buildPreparation(root: Instance)
	local prep = folder(root, "Preparacion")
	for _, x in { -30, -18, 18, 30 } do
		box(prep, "Banco", x, 0, 100, 7, 1.4, 1.8, 0x8a5a2e, Enum.Material.WoodPlanks)
		box(prep, "PataBanco", x - 3, 0, 100, 0.8, 2.6, 1.8, 0x50565d, Enum.Material.Metal)
		box(prep, "PataBanco", x + 3, 0, 100, 0.8, 2.6, 1.8, 0x50565d, Enum.Material.Metal)
	end
	box(prep, "Caja", -36, 0, 84, 4, 4, 4, 0x8a6a3c, Enum.Material.WoodPlanks)
	box(prep, "Caja", -36, 4, 84, 4, 3, 4, 0x9b7a48, Enum.Material.WoodPlanks, 0.25)
	box(prep, "Caja", 36, 0, 88, 4, 4, 4, 0x8a6a3c, Enum.Material.WoodPlanks)

	-- Luz propia del recinto (el cielo del Lobby es de atardecer y desde fuera se ve a oscuras): focos
	-- altos pegados a los muros laterales, cada 40 studs.
	local lights = folder(root, "Luces")
	for _, side in { -1, 1 } do
		for _, z in { 100, 60, 20, -20, -55 } do
			local x = side * (HALF_WIDTH - 2)
			box(lights, "PosteFoco", x, 0, z, 0.8, 19, 0.8, 0x50565d, Enum.Material.Metal)
			local lamp = decor(box(lights, "Foco", x, 19, z, 2.2, 1, 2.2, 0xfff1dc, Enum.Material.Neon))
			light(lamp, Color3.fromRGB(255, 241, 220), 45, 0.5)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Consolas de la línea de tiro

-- Dos pedestales voxel detrás de la línea de tiro, a los lados del centro, cada uno con un aviso:
-- «Borrar marcas» (BorrarMarcasPrompt: cada cliente vacía las marcas de sus pantallas) y «Ronda de tiro»
-- (RondaPrompt: la atiende RangeRoundService).
local CONSOLE_Z = FIRE_Z + 8
local CONSOLE_X = 14
local CONSOLE_COLOR = 0xff7a1a

local function buildConsole(parent: Instance, x: number, label: string, promptName: string)
	local console = folder(parent, "Consola")
	box(console, "Base", x, 0, CONSOLE_Z, 3.4, 1, 3.4, 0x4b525b, Enum.Material.SmoothPlastic)
	box(console, "Columna", x, 1, CONSOLE_Z, 2.2, 2, 2.2, 0x565d66, Enum.Material.SmoothPlastic)
	local top = decor(box(console, "Panel", x, 3, CONSOLE_Z, 2.8, 0.5, 2.8, CONSOLE_COLOR, Enum.Material.Neon))
	-- Poste fino y rótulo que se lee desde la línea de tiro (mira hacia +z).
	box(console, "Poste", x, 3.5, CONSOLE_Z, 0.4, 1.4, 0.4, 0x50565d, Enum.Material.Metal)
	sign(console, label, 6.4, 1.5, Vector3.new(x, 5.6, CONSOLE_Z), Enum.NormalId.Front, 0xffcfa8)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = promptName
	prompt.ActionText = label
	prompt.ObjectText = later("Campo de tiro")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Range.ConsoleReach
	prompt.RequiresLineOfSight = false
	prompt.Parent = top
end

local function buildConsoles(root: Instance)
	local consoles = folder(root, "Consolas")
	buildConsole(consoles, -CONSOLE_X, later("Borrar marcas"), "BorrarMarcasPrompt")
	buildConsole(consoles, CONSOLE_X, later("Ronda de tiro"), "RondaPrompt")
end

---------------------------------------------------------------------------------------------------
-- Armero (Fase 24b)

-- Pared derecha de la zona de preparación (cara interior en x = HALF_WIDTH), entre la línea de tiro y la pared
-- trasera. Las cuatro armas del Laboratorio cuelgan en horizontal, con la boca hacia las dianas (-z), cada una
-- con su nombre debajo, y al final va «Dejar arma». Cada aviso es de una sola arma: ArmeroWeapon = su id. Van a
-- ARMORY_COLUMN studs unas de otras y con un alcance corto, para que el aviso sea el del arma que se tiene delante.
local ARMORY_X = HALF_WIDTH - 1.4
local ARMORY_Z = 86 -- centro de la fila de armas
local ARMORY_COLUMN = 8 -- separación entre armas
local ARMORY_DROP_Z = ARMORY_Z + 20
local ARMORY_BOARD_Z = ARMORY_Z + 4 -- centro del tablero: cubre las armas y «Dejar arma»
local ARMORY_BOARD_DEPTH = 40
local ARMORY_CENTER_Y = 6.8
local ARMORY_WEAPON_LENGTH = 6.4 -- lado mayor de cada arma, en studs
local ARMORY_LABEL_Y = 3.9
local ARMORY_REACH = 6
local ARMORY_COLOR = 0xffcfa8

-- Una copia decorativa y anclada de la herramienta del arma, con su centro en "target".
local function buildDisplayWeapon(parent: Instance, weaponId: string, target: CFrame)
	local tool = Instance.new("Tool")
	local handle = LabWeaponModels.build(tool, weaponId, "Guardians", nil)
	local model = Instance.new("Model")
	model.Name = weaponId
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end
	for _, child in tool:GetChildren() do
		child.Parent = model
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			decor(descendant)
		end
	end
	model.PrimaryPart = handle
	model.Parent = parent
	-- Todas del mismo largo y con el centro de sus piezas en el punto de la pared.
	local _, size = model:GetBoundingBox()
	model:ScaleTo(ARMORY_WEAPON_LENGTH / math.max(size.X, size.Y, size.Z))
	local boxCFrame = model:GetBoundingBox()
	model:PivotTo(target * handle.CFrame:ToObjectSpace(boxCFrame):Inverse())
	tool:Destroy()
end

local function buildArmory(root: Instance)
	local armory = folder(root, "Armero")
	local boardZ = ARMORY_BOARD_Z
	local boardDepth = ARMORY_BOARD_DEPTH
	local wood = Enum.Material.WoodPlanks
	box(armory, "Tablero", HALF_WIDTH - 0.5, 2, boardZ, 1, 12.4, boardDepth, 0x3a2a1c, wood)
	for _, y0 in { 1.6, 11.2 } do
		box(armory, "Riel", HALF_WIDTH - 1.1, y0, boardZ, 0.5, 0.5, boardDepth + 0.6, 0x50565d, Enum.Material.Metal)
	end
	decor(
		box(
			armory,
			"Franja",
			HALF_WIDTH - 1.05,
			10.6,
			boardZ,
			0.2,
			0.3,
			boardDepth - 1,
			CONSOLE_COLOR,
			Enum.Material.Neon
		)
	)
	sign(armory, later("Armero"), 12, 1.6, Vector3.new(ARMORY_X + 0.3, 13.2, boardZ), Enum.NormalId.Left, ARMORY_COLOR)

	for index, weaponId in LabWeapons.ORDER do
		local z = ARMORY_Z - 10 + (index - 1) * ARMORY_COLUMN
		-- Tumbada (+90° sobre el eje de la pared, que es x): la boca apunta a -z, hacia las dianas, y el cargador
		-- queda abajo.
		buildDisplayWeapon(armory, weaponId, place(ARMORY_X, ARMORY_CENTER_Y, z) * CFrame.Angles(math.rad(90), 0, 0))
		for _, dz in { -2.2, 2.2 } do
			box(
				armory,
				"Soporte",
				HALF_WIDTH - 1.3,
				ARMORY_CENTER_Y - 1.9,
				z + dz,
				0.6,
				0.4,
				0.8,
				0x50565d,
				Enum.Material.Metal
			)
		end
		sign(
			armory,
			LabWeapons.weapons[weaponId].name,
			ARMORY_WEAPON_LENGTH + 0.6,
			1.1,
			Vector3.new(ARMORY_X + 0.3, ARMORY_LABEL_Y, z),
			Enum.NormalId.Left,
			ARMORY_COLOR
		)
		local anchor = decor(
			box(armory, "Aviso", ARMORY_X - 0.6, ARMORY_CENTER_Y - 0.5, z, 0.5, 0.5, 0.5, 0x50565d, Enum.Material.Metal)
		)
		anchor.Transparency = 1
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ArmeroPrompt"
		prompt.ActionText = later("Equipar")
		prompt.ObjectText = LabWeapons.weapons[weaponId].name
		prompt:SetAttribute("ArmeroWeapon", weaponId)
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = ARMORY_REACH
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
	end

	-- «Dejar arma»: una chapa al final del tablero.
	sign(
		armory,
		later("Dejar arma"),
		4.4,
		1.4,
		Vector3.new(ARMORY_X + 0.3, ARMORY_CENTER_Y, ARMORY_DROP_Z),
		Enum.NormalId.Left,
		ARMORY_COLOR
	)
	local dropAnchor = decor(
		box(
			armory,
			"Aviso",
			ARMORY_X - 0.6,
			ARMORY_CENTER_Y - 0.7,
			ARMORY_DROP_Z,
			0.5,
			0.5,
			0.5,
			0x50565d,
			Enum.Material.Metal
		)
	)
	dropAnchor.Transparency = 1
	local drop = Instance.new("ProximityPrompt")
	drop.Name = "ArmeroDejarPrompt"
	drop.ActionText = later("Dejar arma")
	drop.ObjectText = later("Armero")
	drop.HoldDuration = 0
	drop.MaxActivationDistance = ARMORY_REACH
	drop.RequiresLineOfSight = false
	drop.Parent = dropAnchor
end

---------------------------------------------------------------------------------------------------
-- API

-- Dónde aparece un jugador al entrar: en la zona de preparación, mirando a -z. "slot" reparte a los
-- que llegan seguidos a lo ancho (-3 … 3 casillas de ENTRY_SPREAD studs).
function RangeBuilder.entrySpawn(slot: number?): CFrame
	local offset = ((slot or 0) % 7 - 3) * ENTRY_SPREAD
	return place(offset, ENTRY_HEIGHT, ENTRY_Z)
end

function RangeBuilder.isBuilt(): boolean
	local built = Workspace:FindFirstChild(FOLDER_NAME)
	return built ~= nil and built:GetAttribute("Version") == VERSION
end

function RangeBuilder.build(options: Options?)
	local force = options and options.force
	if not force and game.PlaceId ~= Config.PlaceIds.Lobby then
		warn(
			`[RangeBuilder] Este place ({game.PlaceId}) no es el Lobby ({Config.PlaceIds.Lobby}). `
				.. "Abre el Lobby o usa build({ force = true })."
		)
		return
	end
	local old = Workspace:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = FOLDER_NAME
	root:SetAttribute("Version", VERSION)
	buildFloor(root)
	buildWalls(root)
	buildScreens(root)
	buildTargets(root)
	buildDummies(root)
	buildObstacles(root)
	buildPreparation(root)
	buildConsoles(root)
	buildArmory(root)

	local parts = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
		end
	end
	if parts > Config.Budgets.Matches.RangeParts then
		warn(`[RangeBuilder] El campo de tiro tiene {parts} piezas y el tope es {Config.Budgets.Matches.RangeParts}`)
	end
	root.Parent = Workspace
	print(`[RangeBuilder] ¡Campo de tiro listo! ({parts} piezas)`)
end

return RangeBuilder
