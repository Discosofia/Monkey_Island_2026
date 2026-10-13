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
-- Crea: mar y banco de arena (terreno); el carguero encallado con boquete y bodega, castillo con
-- puente de mando, chimenea y radar, contenedores en cubierta y grúa; la pasarela de subida; el
-- campamento con hoguera y tienda de lona, contenedores varados, cajas de la carga, ancla con cadena,
-- salvavidas y la bitácora del capitán; la lancha de rescate para zarpar (aviso "ZarparPrompt");
-- palmeras; la isla con el volcán en el horizonte; muros invisibles, el punto de aparición y la luz
-- de atardecer.
--
-- ⚠️ Borra la carpeta Workspace.Naufragio, la Baseplate, los SpawnLocation sueltos y el terreno de la
-- zona antes de construir.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

export type Options = { force: boolean? }

local FOLDER_NAME = "Naufragio"
-- Sube este número al cambiar el escenario: los Lobbies con una versión anterior guardada se
-- reconstruyen solos al arrancar (LobbyWorldService).
local VERSION = 2
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

-- Barco: carguero moderno, eslora a lo largo de X local, de -38 (popa) a 38 (proa); +Z es estribor.
local SHIP_HALF_LENGTH = 38
local SHIP_BEAM = 22
local HULL_ROWS = 6
local ROW_HEIGHT = 2.2
local HULL_SEGMENTS = 16
-- Encallado: la quilla un par de studs bajo la arena, escorado hacia la playa (+Z) y con la proa
-- algo levantada.
local SHIP_FRAME = CFrame.new(-36, 2.2, -24)
	* CFrame.Angles(0, math.rad(-6), 0)
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

local LOG_TEXT = "BITÁCORA DEL CAPITÁN\n\n"
	.. "La tormenta empujó al carguero «Esperanza» contra el arrecife. El casco está abierto y los "
	.. "motores, muertos.\n\n"
	.. "Al norte se ve una isla con un volcán que humea día y noche. De allí llegan aullidos.\n\n"
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
	-- Mar: de la orilla hasta más allá de la isla del horizonte, por bloques.
	local seaMin = Vector2.new(-700, -1100)
	local seaMax = Vector2.new(1100, 500)
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
			Vector3.new(-82, 0, -38),
			Vector3.new(-70, -1, -52),
			Vector3.new(-52, -2, -60),
			Vector3.new(4, -1, -58),
			Vector3.new(-90, -1, -15),
		}
	do
		terrain:FillBall(spot, rng:NextNumber(5, 8), Enum.Material.Basalt)
	end
	terrain:FillBall(Vector3.new(36, 1, 18), 5, Enum.Material.Rock)
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
	-- Chorretones de óxido bajo la borda.
	for _, x in { -30, -21, -13, 9, 17, 24 } do
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
	-- En la proa sigue la curva del casco.
	local bowFrom, bowTo = hullPoint(19, 4.7, 1), hullPoint(27, 4.7, 1)
	local outward = (bowTo - bowFrom):Cross(Vector3.yAxis).Unit
	local bowMid = (bowFrom + bowTo) / 2 + outward * 0.45
	local bowName = newPart(
		"NombreProa",
		Vector3.new((bowTo - bowFrom).Magnitude, 2, 0.2),
		CFrame.lookAt(bowMid, bowMid + outward),
		HULL_NAVY,
		Enum.Material.Metal,
		model
	)
	sign(bowName, Enum.NormalId.Front, "ESPERANZA", WHITE_PAINT, Enum.Font.GothamBlack)
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
	end
	local topLight =
		ball("LuzTope", 0.5, Vector3.new(mastX, roof + 7.2, 0), Color3.new(1, 1, 1), Enum.Material.Neon, model)
	decor(topLight)
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
	decor(mastLight)
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
	decor(lamp)
	light(lamp, Color3.fromRGB(255, 150, 80), 16, 1.6)
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

-- Salvavidas naranja y blanco (aro de tramos de cilindro) colgado de un poste.
local function lifeRing(parent: Instance, center: CFrame)
	local segments = 12
	local radius = 1.6
	for i = 0, segments - 1 do
		local a0 = i * 2 * math.pi / segments
		local a1 = (i + 1) * 2 * math.pi / segments
		local p0 = (center * CFrame.new(math.cos(a0) * radius, math.sin(a0) * radius, 0)).Position
		local p1 = (center * CFrame.new(math.cos(a1) * radius, math.sin(a1) * radius, 0)).Position
		decor(
			cylinder(
				"Salvavidas",
				0.7,
				p0,
				p1,
				if math.floor(i / 3) % 2 == 0 then RESCUE_ORANGE else WHITE_PAINT,
				Enum.Material.SmoothPlastic,
				parent
			)
		)
	end
end

local function buildCamp(parent: Instance)
	local camp = Instance.new("Model")
	camp.Name = "Campamento"
	-- Hoguera con leña de deriva.
	local fireAt = groundAt(6, 10)
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

	-- Tienda de lona azul sobre dos postes de aluminio.
	local tentAt = groundAt(-14, 16)
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
	local tipped = groundAt(-20, -1)
	container(
		camp,
		CFrame.new(tipped + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0.45, 0) * CFrame.Angles(math.rad(82), 0, 0),
		CONTAINER_COLORS[2],
		"PRIMAL",
		Enum.NormalId.Front
	)
	local openAt = groundAt(-36, 12)
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

	-- Más carga por la playa.
	crate(camp, CFrame.new(groundAt(20, -18) + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0.9, 0.15), 2.4, false)
	drum(camp, groundAt(16, 4), true)
	drum(camp, groundAt(30, -30), true)

	-- Ancla moderna (sin cepo) en la arena, unida a la proa por la cadena.
	local anchorAt = groundAt(14, -40)
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

	-- Bitácora del capitán en un tablero clavado en la arena, con su lámpara de emergencia.
	local boardAt = groundAt(-6, 30)
	local boardFrame = CFrame.lookAt(boardAt + Vector3.new(0, 4.2, 0), boardAt + Vector3.new(4, 4.2, 14))
	for _, dx in { -3, 3 } do
		newPart(
			"PosteTablon",
			Vector3.new(0.6, 6.5, 0.6),
			boardFrame * CFrame.new(dx, -1, 0.2),
			DARK_WOOD,
			Enum.Material.Wood,
			camp
		)
	end
	local board = newPart(
		"BitacoraDelCapitan",
		Vector3.new(7.5, 5, 0.4),
		boardFrame,
		Color3.fromRGB(205, 175, 125),
		Enum.Material.WoodPlanks,
		camp
	)
	sign(board, Enum.NormalId.Front, LOG_TEXT, Color3.fromRGB(45, 30, 15), Enum.Font.Antique)
	local lamp = newPart(
		"LamparaTablon",
		Vector3.new(0.9, 0.5, 0.5),
		boardFrame * CFrame.new(3.4, 2.8, -0.5),
		LANTERN_LIGHT,
		Enum.Material.Neon,
		camp
	)
	decor(lamp)
	light(lamp, LANTERN_LIGHT, 14, 1.5)
	-- Salvavidas del barco colgado de un poste junto a la llegada.
	local ringPost = groundAt(10, 32)
	newPart(
		"PosteSalvavidas",
		Vector3.new(0.5, 6, 0.5),
		CFrame.new(ringPost + Vector3.new(0, 3, 0)),
		DARK_WOOD,
		Enum.Material.Wood,
		camp
	)
	lifeRing(camp, CFrame.lookAt(ringPost + Vector3.new(0, 4.2, 0.6), ringPost + Vector3.new(0, 4.2, 10)))

	camp.Parent = parent
end

-- Lancha neumática de rescate en la orilla, apuntando a la isla: con su aviso se viaja a la partida.
local function buildLifeboat(parent: Instance)
	local boat = Instance.new("Model")
	boat.Name = "Lancha"
	local at = Vector3.new(24, SEA_LEVEL + 0.2, -50)
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
	prompt.ActionText = "Zarpar hacia la isla"
	prompt.ObjectText = "Lancha de rescate"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAnchor

	-- Cartel a su lado.
	local signAt = groundAt(16, -40)
	local signFrame = CFrame.lookAt(signAt + Vector3.new(0, 4, 0), signAt + Vector3.new(-6, 4, 16))
	newPart(
		"PosteCartel",
		Vector3.new(0.5, 5, 0.5),
		signFrame * CFrame.new(0, -1.6, 0.3),
		DARK_WOOD,
		Enum.Material.Wood,
		boat
	)
	local board = newPart(
		"Cartel",
		Vector3.new(6, 2, 0.3),
		signFrame,
		Color3.fromRGB(205, 175, 125),
		Enum.Material.WoodPlanks,
		boat
	)
	sign(board, Enum.NormalId.Front, "🚤 A LA ISLA →", Color3.fromRGB(45, 30, 15), Enum.Font.Antique)
	boat.Parent = parent
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
	local at = groundAt(4, 34)
	local toward = Vector3.new(24, at.Y, -50)
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
	carveHull()
	local ship = buildShip(folder)
	buildRamp(folder, ship)
	buildCamp(folder)
	buildLifeboat(folder)
	for _, palm in
		{
			{ x = 40, z = 22, lean = 0.12, yaw = 0.4 },
			{ x = 46, z = 6, lean = 0.18, yaw = 1.9 },
			{ x = -58, z = 26, lean = 0.1, yaw = 3.4 },
			{ x = -70, z = 10, lean = 0.2, yaw = 2.2 },
			{ x = 28, z = 32, lean = 0.08, yaw = 5.1 },
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
