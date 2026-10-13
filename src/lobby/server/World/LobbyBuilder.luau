--!strict
-- Escenario del Lobby: el naufragio de la «Esperanza» (GDD §13, lore). Los jugadores son náufragos:
-- el barco ha encallado en un banco de arena y, al norte, se ve la isla con su volcán humeante.
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
-- Crea: mar y banco de arena (terreno), el barco encallado con boquete y bodega, rampa de subida,
-- mástil caído, campamento con hoguera y tienda hecha con la vela, cajas de la carga, el diario del
-- capitán, el bote para zarpar (aviso "ZarparPrompt"), palmeras, la isla con el volcán en el
-- horizonte, muros invisibles, el punto de aparición y la luz de atardecer.
--
-- ⚠️ Borra la carpeta Workspace.Naufragio, la Baseplate, los SpawnLocation sueltos y el terreno de la
-- zona antes de construir.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

export type Options = { force: boolean? }

local FOLDER_NAME = "Naufragio"
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

-- Barco: eslora a lo largo de X local, de -38 (popa) a 38 (proa).
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

local WOOD_TONES = {
	Color3.fromRGB(96, 62, 34),
	Color3.fromRGB(110, 72, 40),
	Color3.fromRGB(84, 54, 30),
	Color3.fromRGB(122, 82, 48),
}
local DARK_WOOD = Color3.fromRGB(62, 40, 24)
local DECK_WOOD = Color3.fromRGB(150, 110, 68)
local SAIL = Color3.fromRGB(226, 212, 178)
local IRON = Color3.fromRGB(55, 55, 60)
local ROPE = Color3.fromRGB(170, 140, 90)
local FIRE_LIGHT = Color3.fromRGB(255, 170, 90)
local LANTERN_LIGHT = Color3.fromRGB(255, 200, 120)
local LEAF = Color3.fromRGB(70, 150, 60)

local LOG_TEXT = "DIARIO DEL CAPITÁN\n\n"
	.. "La tormenta lanzó a la «Esperanza» contra el arrecife. No volverá a navegar.\n\n"
	.. "Al norte se ve una isla con un volcán que humea día y noche. De allí llegan aullidos.\n\n"
	.. "Entre la carga hay cajas con un sello que nadie supo explicar: PROYECTO PRIMAL.\n\n"
	.. "Quien quiera salir de aquí, que tome el bote y reme hacia la isla. "
	.. "Dicen que en el viejo laboratorio aún queda una radio."

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

local function woodTone(): Color3
	return WOOD_TONES[rng:NextInteger(1, #WOOD_TONES)]
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
-- Barco

local function sheer(x: number): number
	return 1.8 * (x / SHIP_HALF_LENGTH) ^ 2
end

local function halfBeam(x: number, row: number): number
	local t = x / SHIP_HALF_LENGTH
	local shape = if t > 0 then 1 - t ^ 2.4 else 1 - 0.32 * (-t) ^ 3
	local depth = 0.5 + 0.5 * (row / HULL_ROWS) ^ 0.6
	return math.max(0.5, SHIP_BEAM / 2 * shape * depth)
end

local function hullPoint(x: number, row: number, side: number): Vector3
	return Vector3.new(x, row * ROW_HEIGHT + sheer(x) * row / HULL_ROWS, side * halfBeam(x, row))
end

local function deckHeight(x: number): number
	return HULL_ROWS * ROW_HEIGHT + sheer(x)
end

-- Una tabla del casco entre dos filas y dos cortes de la eslora (en coordenadas del barco).
local function plank(model: Model, side: number, row: number, x0: number, x1: number, color: Color3)
	local a0, a1 = hullPoint(x0, row, side), hullPoint(x0, row + 1, side)
	local b0, b1 = hullPoint(x1, row, side), hullPoint(x1, row + 1, side)
	local center = (a0 + a1 + b0 + b1) / 4
	local along = ((b0 + b1) / 2 - (a0 + a1) / 2)
	local up = ((a1 + b1) / 2 - (a0 + b0) / 2)
	local zAxis = along.Unit
	local yAxis = (up - zAxis * up:Dot(zAxis)).Unit
	local xAxis = yAxis:Cross(zAxis)
	newPart(
		"Tabla",
		Vector3.new(0.8, up.Magnitude + 0.25, along.Magnitude + 0.3),
		CFrame.fromMatrix(center, xAxis, yAxis, zAxis),
		color,
		Enum.Material.WoodPlanks,
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
					plank(model, side, row, x0, x1, woodTone())
				end
			end
		end
		-- Fondo de la bodega.
		local mid = (x0 + x1) / 2
		newPart(
			"Bodega",
			Vector3.new(step + 0.2, 0.8, 2 * halfBeam(mid, 0.6)),
			CFrame.new(mid, 0.6, 0),
			DARK_WOOD,
			Enum.Material.WoodPlanks,
			model
		)
	end
	-- Astillas en el borde del boquete.
	for _, stub in
		{
			{ x = -9.5, row = 3.5, length = 3, tilt = 0.5 },
			{ x = -4.75, row = 4.2, length = 2.4, tilt = -0.4 },
			{ x = -14, row = 2.4, length = 2.2, tilt = 0.8 },
			{ x = 0.5, row = 1.2, length = 2.6, tilt = -0.7 },
			{ x = 5, row = 2.6, length = 2, tilt = 0.4 },
		}
	do
		local point = hullPoint(stub.x, stub.row, 1)
		newPart(
			"Astilla",
			Vector3.new(0.6, 1.8, stub.length),
			CFrame.new(point) * CFrame.Angles(stub.tilt, 0.3, 0),
			woodTone(),
			Enum.Material.WoodPlanks,
			model
		)
	end
	-- Quilla, roda en la proa y espejo de popa con el nombre.
	newPart(
		"Quilla",
		Vector3.new(2 * SHIP_HALF_LENGTH, 1.2, 1.4),
		CFrame.new(0, -0.3, 0),
		DARK_WOOD,
		Enum.Material.Wood,
		model
	)
	local stemTop = Vector3.new(SHIP_HALF_LENGTH + 0.6, deckHeight(SHIP_HALF_LENGTH) + 1, 0)
	cylinder("Roda", 1.4, Vector3.new(SHIP_HALF_LENGTH - 1, 0, 0), stemTop, DARK_WOOD, Enum.Material.Wood, model)
	for row = 0, HULL_ROWS - 1 do
		local width = 2 * halfBeam(-SHIP_HALF_LENGTH, row + 0.5)
		newPart(
			"Espejo",
			Vector3.new(0.8, ROW_HEIGHT + 0.2, width),
			CFrame.new(-SHIP_HALF_LENGTH - 0.2, (row + 0.5) * ROW_HEIGHT + sheer(-SHIP_HALF_LENGTH) * 0.5, 0),
			woodTone(),
			Enum.Material.WoodPlanks,
			model
		)
	end
	local nameBoard = newPart(
		"Nombre",
		Vector3.new(0.3, 2, 11),
		CFrame.new(-SHIP_HALF_LENGTH - 0.8, deckHeight(-SHIP_HALF_LENGTH) - 2.2, 0),
		DARK_WOOD,
		Enum.Material.Wood,
		model
	)
	sign(nameBoard, Enum.NormalId.Left, "ESPERANZA", Color3.fromRGB(235, 200, 120), Enum.Font.Fantasy)
	-- El nombre también en la proa, del lado de la playa.
	local bowPoint = hullPoint(26, 4.6, 1)
	local bowNormal = Vector3.new(0, 0, 1)
	local bowBoard = newPart(
		"NombreProa",
		Vector3.new(9, 1.8, 0.3),
		CFrame.lookAt(bowPoint + bowNormal * 0.5, bowPoint + bowNormal * 2) * CFrame.Angles(0, 0, 0),
		DARK_WOOD,
		Enum.Material.Wood,
		model
	)
	sign(bowBoard, Enum.NormalId.Front, "ESPERANZA", Color3.fromRGB(235, 200, 120), Enum.Font.Fantasy)
end

local function buildDeck(model: Model)
	local step = 2 * SHIP_HALF_LENGTH / HULL_SEGMENTS
	for segment = 0, HULL_SEGMENTS - 1 do
		local x0 = -SHIP_HALF_LENGTH + segment * step
		local mid = x0 + step / 2
		local width = 2 * halfBeam(mid, HULL_ROWS) - 0.6
		local y = deckHeight(mid) - 0.4
		if segment == 7 then
			-- Cubierta hundida sobre el boquete: tablas sueltas y torcidas.
			for i = -1, 1 do
				newPart(
					"TablaRota",
					Vector3.new(step * 0.9, 0.5, 2.2),
					CFrame.new(mid + i * 0.6, y - 1.5 - i * 0.6, -3 + i * 4) * CFrame.Angles(0.25 * i, 0.2 * i, 0.3),
					DECK_WOOD,
					Enum.Material.WoodPlanks,
					model
				)
			end
		else
			newPart(
				"Cubierta",
				Vector3.new(step + 0.2, 0.6, width),
				CFrame.new(mid, y, 0),
				DECK_WOOD,
				Enum.Material.WoodPlanks,
				model
			)
		end
		-- Borda: postes y pasamanos, con un hueco en el costado de la rampa.
		for _, side in { -1, 1 } do
			local gap = side == 1 and segment == 3
			if not gap and segment > 2 then
				local a = hullPoint(x0, HULL_ROWS, side) + Vector3.new(0, 1.6, 0)
				local b = hullPoint(x0 + step, HULL_ROWS, side) + Vector3.new(0, 1.6, 0)
				cylinder("Pasamanos", 0.5, a, b, DARK_WOOD, Enum.Material.Wood, model)
				newPart(
					"Poste",
					Vector3.new(0.5, 2, 0.5),
					CFrame.new(a - Vector3.new(0, 0.8, 0)),
					DARK_WOOD,
					Enum.Material.Wood,
					model
				)
			end
		end
	end
end

-- Alcázar de popa: camarote del capitán con puerta y ventanas encendidas, timón y farol.
local function buildStern(model: Model)
	local front = -SHIP_HALF_LENGTH + 12
	local floor = deckHeight(-SHIP_HALF_LENGTH + 6)
	local width = 2 * halfBeam(-SHIP_HALF_LENGTH + 6, HULL_ROWS) - 0.4
	local height = 5.5
	for _, wall in
		{
			{ size = Vector3.new(0.8, height, width), at = Vector3.new(front, floor + height / 2, 0) },
			{
				size = Vector3.new(12, height, 0.8),
				at = Vector3.new(front - 6, floor + height / 2, width / 2 - 0.4),
			},
			{
				size = Vector3.new(12, height, 0.8),
				at = Vector3.new(front - 6, floor + height / 2, -width / 2 + 0.4),
			},
		}
	do
		newPart("Camarote", wall.size, CFrame.new(wall.at), woodTone(), Enum.Material.WoodPlanks, model)
	end
	newPart(
		"Alcazar",
		Vector3.new(13, 0.6, width + 0.6),
		CFrame.new(front - 6, floor + height + 0.3, 0),
		DECK_WOOD,
		Enum.Material.WoodPlanks,
		model
	)
	newPart(
		"Puerta",
		Vector3.new(0.3, 3.8, 2.4),
		CFrame.new(front + 0.5, floor + 1.9, 0),
		DARK_WOOD,
		Enum.Material.Wood,
		model
	)
	for _, z in { -4.5, 4.5 } do
		local window = newPart(
			"Ventana",
			Vector3.new(0.3, 1.4, 1.6),
			CFrame.new(front + 0.5, floor + 3, z),
			Color3.fromRGB(255, 200, 110),
			Enum.Material.Neon,
			model
		)
		decor(window)
	end
	-- Escalera al alcázar.
	for i = 0, 4 do
		newPart(
			"Escalon",
			Vector3.new(1.2, 0.5, 3),
			CFrame.new(front + 1 + (4 - i) * 1.1, floor + 0.6 + i * 1.1, -width / 2 + 2.5),
			DECK_WOOD,
			Enum.Material.WoodPlanks,
			model
		)
	end
	-- Timón: rueda con radios sobre un pedestal.
	local wheelCenter = Vector3.new(front - 3, floor + height + 3.2, 0)
	newPart(
		"Pedestal",
		Vector3.new(1, 2.6, 1),
		CFrame.new(wheelCenter - Vector3.new(0.8, 1.6, 0)),
		DARK_WOOD,
		Enum.Material.Wood,
		model
	)
	local rim =
		newPart("Timon", Vector3.new(0.4, 4.4, 4.4), CFrame.new(wheelCenter), DARK_WOOD, Enum.Material.Wood, model)
	rim.Shape = Enum.PartType.Cylinder
	local hub = newPart(
		"TimonCentro",
		Vector3.new(0.6, 3.4, 3.4),
		CFrame.new(wheelCenter),
		DECK_WOOD,
		Enum.Material.Wood,
		model
	)
	hub.Shape = Enum.PartType.Cylinder
	for i = 0, 3 do
		newPart(
			"Radio",
			Vector3.new(0.3, 5.6, 0.3),
			CFrame.new(wheelCenter) * CFrame.Angles(i * math.pi / 4, 0, 0),
			DARK_WOOD,
			Enum.Material.Wood,
			model
		)
	end
	-- Farol de popa.
	local post = Vector3.new(-SHIP_HALF_LENGTH + 0.8, floor + height + 0.6, 0)
	newPart(
		"PosteFarol",
		Vector3.new(0.4, 3, 0.4),
		CFrame.new(post + Vector3.new(0, 1.5, 0)),
		IRON,
		Enum.Material.Metal,
		model
	)
	local lantern = newPart(
		"Farol",
		Vector3.new(1.2, 1.6, 1.2),
		CFrame.new(post + Vector3.new(0, 3.6, 0)),
		LANTERN_LIGHT,
		Enum.Material.Neon,
		model
	)
	decor(lantern)
	light(lantern, LANTERN_LIGHT, 22, 2)
end

local function sailStrips(model: Model, top: CFrame, width: number, length: number, ragged: boolean)
	local strips = 6
	for i = 0, strips - 1 do
		local stripLength = if ragged then length * rng:NextNumber(0.45, 1) else length
		local offset = (i + 0.5) / strips * width - width / 2
		local strip = newPart(
			"Vela",
			Vector3.new(width / strips + 0.1, stripLength, 0.2),
			top * CFrame.new(offset, -stripLength / 2, 0) * CFrame.Angles(rng:NextNumber(-0.08, 0.12), 0, 0),
			SAIL,
			Enum.Material.Fabric,
			model
		)
		decor(strip)
	end
end

local function buildMasts(model: Model)
	-- Trinquete en pie, con verga y vela rasgada, cofa y obenques.
	local foreX = 16
	local foreBase = Vector3.new(foreX, deckHeight(foreX), 0)
	local foreTop = foreBase + Vector3.new(0, 30, 0)
	cylinder("Trinquete", 1.6, foreBase - Vector3.new(0, 6, 0), foreTop, DARK_WOOD, Enum.Material.Wood, model)
	local yardHeight = foreBase + Vector3.new(0, 22, 0)
	cylinder(
		"Verga",
		0.8,
		yardHeight - Vector3.new(0, 0, 9),
		yardHeight + Vector3.new(0, 0, 9),
		DARK_WOOD,
		Enum.Material.Wood,
		model
	)
	sailStrips(model, CFrame.new(yardHeight + Vector3.new(0.6, 0, 0)) * CFrame.Angles(0, math.pi / 2, 0), 16, 12, true)
	local nest = newPart(
		"Cofa",
		Vector3.new(1, 4, 4),
		CFrame.new(foreBase + Vector3.new(0, 26, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		DARK_WOOD,
		Enum.Material.Wood,
		model
	)
	nest.Shape = Enum.PartType.Cylinder
	for _, side in { -1, 1 } do
		for _, dx in { -3, 3 } do
			local anchor = hullPoint(foreX + dx, HULL_ROWS, side) + Vector3.new(0, 1.5, 0)
			decor(cylinder("Obenque", 0.15, anchor, foreTop - Vector3.new(0, 2, 0), ROPE, Enum.Material.Fabric, model))
		end
	end
	-- Bauprés.
	local bow = Vector3.new(SHIP_HALF_LENGTH, deckHeight(SHIP_HALF_LENGTH) + 0.8, 0)
	cylinder(
		"Baupres",
		1,
		bow - Vector3.new(4, 0, 0),
		bow + Vector3.new(12, 5, 0),
		DARK_WOOD,
		Enum.Material.Wood,
		model
	)
	decor(cylinder("Estay", 0.15, bow + Vector3.new(11, 4.6, 0), foreTop, ROPE, Enum.Material.Fabric, model))

	-- Palo mayor partido: queda un tocón astillado.
	local mainX = -6
	local mainBase = Vector3.new(mainX, deckHeight(mainX), 0)
	cylinder(
		"PaloMayor",
		2,
		mainBase - Vector3.new(0, 6, 0),
		mainBase + Vector3.new(0, 9, 0),
		DARK_WOOD,
		Enum.Material.Wood,
		model
	)
	for i = 0, 4 do
		local angle = i * 2 * math.pi / 5
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Astilla"
		wedge.Size = Vector3.new(0.6, rng:NextNumber(1.2, 2.6), 0.8)
		wedge.CFrame = CFrame.new(mainBase + Vector3.new(math.cos(angle) * 0.6, 9.6, math.sin(angle) * 0.6))
			* CFrame.Angles(0, -angle, 0)
		wedge.Color = DARK_WOOD
		wedge.Material = Enum.Material.Wood
		wedge.Anchored = true
		wedge.Parent = model
	end
end

-- Carga: cajas y barriles; algunas con el sello del Proyecto PRIMAL.
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

local function barrel(parent: Instance, position: Vector3, lying: boolean)
	local cframe = if lying
		then CFrame.new(position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		else CFrame.new(position + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local body =
		newPart("Barril", Vector3.new(3.2, 2.4, 2.4), cframe, Color3.fromRGB(120, 80, 45), Enum.Material.Wood, parent)
	body.Shape = Enum.PartType.Cylinder
	for _, offset in { -1, 1 } do
		local hoop = newPart(
			"Aro",
			Vector3.new(0.25, 2.5, 2.5),
			cframe * CFrame.new(offset, 0, 0),
			IRON,
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
	barrel(model, Vector3.new(-3, 0.9, 2), false)
	barrel(model, Vector3.new(-1, 0.9, -1.5), true)
	-- Racimos de bananas de la carga.
	for i = 0, 5 do
		local position = Vector3.new(-5 + (i % 3) * 0.9, 1.5, 4 + math.floor(i / 3) * 0.8)
		local banana = newPart(
			"Banana",
			Vector3.new(1.4, 0.4, 0.4),
			CFrame.new(position) * CFrame.Angles(0, i, 0.4),
			Color3.fromRGB(240, 210, 60),
			Enum.Material.SmoothPlastic,
			model
		)
		decor(banana)
	end
	local lantern = newPart(
		"FarolBodega",
		Vector3.new(0.9, 1.2, 0.9),
		CFrame.new(-6, 7, 0),
		LANTERN_LIGHT,
		Enum.Material.Neon,
		model
	)
	decor(lantern)
	light(lantern, LANTERN_LIGHT, 16, 1.6)
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
	buildStern(model)
	buildMasts(model)
	buildHold(model)
	local origin = newPart("Pivote", Vector3.one, CFrame.new(), DARK_WOOD, Enum.Material.Wood, model)
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
	-- Hoguera.
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
	-- Troncos para sentarse alrededor.
	for i = 0, 2 do
		local angle = i * 2 * math.pi / 3 + 0.5
		local center = fireAt + Vector3.new(math.cos(angle) * 7, 0.8, math.sin(angle) * 7)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local seat = cylinder(
			"Banco",
			1.6,
			center - tangent * 2.5,
			center + tangent * 2.5,
			Color3.fromRGB(110, 75, 45),
			Enum.Material.Wood,
			camp
		)
		seat.CanCollide = true
	end

	-- Tienda hecha con una vela del barco, sobre dos postes y una cumbrera.
	local tentAt = groundAt(-14, 16)
	local tentFrame = CFrame.new(tentAt) * CFrame.Angles(0, math.rad(20), 0)
	for _, dx in { -5, 5 } do
		newPart(
			"PosteTienda",
			Vector3.new(0.6, 7, 0.6),
			tentFrame * CFrame.new(dx, 3.5, 0),
			DARK_WOOD,
			Enum.Material.Wood,
			camp
		)
	end
	newPart(
		"Cumbrera",
		Vector3.new(11, 0.6, 0.6),
		tentFrame * CFrame.new(0, 6.8, 0),
		DARK_WOOD,
		Enum.Material.Wood,
		camp
	)
	for _, side in { -1, 1 } do
		decor(
			newPart(
				"VelaTienda",
				Vector3.new(11.5, 0.25, 8.4),
				tentFrame * CFrame.new(0, 3.6, side * 3.3) * CFrame.Angles(side * math.rad(-50), 0, 0),
				SAIL,
				Enum.Material.Fabric,
				camp
			)
		)
	end
	crate(camp, tentFrame * CFrame.new(-2, 1.3, 0), 2.6, false)
	barrel(camp, (tentFrame * CFrame.new(2.5, 0, 0.5)).Position, false)

	-- Carga desperdigada por la playa.
	crate(camp, CFrame.new(groundAt(-26, 6) + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0.5, 0.08), 3.2, true)
	crate(camp, CFrame.new(groundAt(-30, 2) + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0.1, -0.3, 0), 2.8, false)
	crate(camp, CFrame.new(groundAt(20, -18) + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0.9, 0.15), 2.4, false)
	barrel(camp, groundAt(16, 4), true)
	barrel(camp, groundAt(-20, -2), false)
	barrel(camp, groundAt(30, -30), true)

	-- Palo mayor caído en la arena, con su verga y la vela tendida.
	local fallFrom = groundAt(-40, 4) + Vector3.new(0, 1, 0)
	local fallTo = groundAt(-12, -6) + Vector3.new(0, 1, 0)
	cylinder("PaloCaido", 2, fallFrom, fallTo, DARK_WOOD, Enum.Material.Wood, camp)
	local yardMid = fallFrom:Lerp(fallTo, 0.6)
	cylinder(
		"VergaCaida",
		0.8,
		yardMid + Vector3.new(-3, 0.2, 8),
		yardMid + Vector3.new(3, 0.2, -8),
		DARK_WOOD,
		Enum.Material.Wood,
		camp
	)
	for i = 0, 3 do
		decor(
			newPart(
				"VelaCaida",
				Vector3.new(6, 0.2, 4.2),
				CFrame.new(groundAt(-22 + i * 2.5, 4 + i * 2) + Vector3.new(0, 0.3, 0))
					* CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0.4 + i * 0.2, rng:NextNumber(-0.12, 0.12)),
				SAIL,
				Enum.Material.Fabric,
				camp
			)
		)
	end

	-- Ancla clavada en la arena junto a la proa.
	local anchorAt = groundAt(14, -40)
	local anchorFrame = CFrame.new(anchorAt) * CFrame.Angles(0, 0.6, 0.35)
	newPart("Ancla", Vector3.new(0.9, 9, 0.9), anchorFrame * CFrame.new(0, 3.5, 0), IRON, Enum.Material.Metal, camp)
	newPart("Cepo", Vector3.new(0.7, 0.7, 6), anchorFrame * CFrame.new(0, 7.3, 0), IRON, Enum.Material.Metal, camp)
	for _, side in { -1, 1 } do
		newPart(
			"Brazo",
			Vector3.new(0.9, 0.9, 4),
			anchorFrame * CFrame.new(0, 0.4, side * 1.4) * CFrame.Angles(side * math.rad(-40), 0, 0),
			IRON,
			Enum.Material.Metal,
			camp
		)
	end
	local ring = newPart(
		"Argolla",
		Vector3.new(0.4, 2.2, 2.2),
		anchorFrame * CFrame.new(0, 8.6, 0),
		IRON,
		Enum.Material.Metal,
		camp
	)
	ring.Shape = Enum.PartType.Cylinder

	-- Diario del capitán en un tablón clavado en la arena.
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
		"DiarioDelCapitan",
		Vector3.new(7.5, 5, 0.4),
		boardFrame,
		Color3.fromRGB(205, 175, 125),
		Enum.Material.WoodPlanks,
		camp
	)
	sign(board, Enum.NormalId.Front, LOG_TEXT, Color3.fromRGB(45, 30, 15), Enum.Font.Antique)
	local lamp = newPart(
		"FarolTablon",
		Vector3.new(0.8, 1, 0.8),
		boardFrame * CFrame.new(3.4, 3, -0.6),
		LANTERN_LIGHT,
		Enum.Material.Neon,
		camp
	)
	decor(lamp)
	light(lamp, LANTERN_LIGHT, 14, 1.5)

	camp.Parent = parent
end

-- Bote salvavidas en la orilla, apuntando a la isla: con su aviso se viaja a la partida.
local function buildLifeboat(parent: Instance)
	local boat = Instance.new("Model")
	boat.Name = "Bote"
	local toIsland = (ISLAND_CENTER - Vector3.new(24, 0, -50)) * Vector3.new(1, 0, 1)
	local at = Vector3.new(24, SEA_LEVEL + 0.4, -50)
	local frame = CFrame.lookAt(at, at + toIsland.Unit) * CFrame.Angles(math.rad(-4), 0, math.rad(3))
	local length, beam = 12, 5
	newPart(
		"Fondo",
		Vector3.new(beam - 1.4, 0.5, length - 2),
		frame * CFrame.new(0, 0.3, 0),
		DARK_WOOD,
		Enum.Material.WoodPlanks,
		boat
	)
	for _, side in { -1, 1 } do
		newPart(
			"Costado",
			Vector3.new(0.5, 1.8, length - 1.5),
			frame * CFrame.new(side * (beam / 2 - 0.4), 1.2, 0.3) * CFrame.Angles(0, 0, side * -0.2),
			Color3.fromRGB(180, 70, 50),
			Enum.Material.WoodPlanks,
			boat
		)
		newPart(
			"Proa",
			Vector3.new(0.5, 1.8, 3.2),
			frame * CFrame.new(side * 1.05, 1.2, -length / 2 + 0.6) * CFrame.Angles(0, side * -0.55, side * -0.2),
			Color3.fromRGB(180, 70, 50),
			Enum.Material.WoodPlanks,
			boat
		)
		-- Remos apoyados en las bordas.
		decor(
			cylinder(
				"Remo",
				0.35,
				(frame * CFrame.new(side * 1.2, 1.9, 1.5)).Position,
				(frame * CFrame.new(side * 4.8, 0.6, 3.5)).Position,
				Color3.fromRGB(190, 150, 95),
				Enum.Material.Wood,
				boat
			)
		)
	end
	newPart(
		"Popa",
		Vector3.new(beam - 0.6, 1.8, 0.5),
		frame * CFrame.new(0, 1.2, length / 2 - 0.5),
		Color3.fromRGB(180, 70, 50),
		Enum.Material.WoodPlanks,
		boat
	)
	for _, z in { -1.5, 2 } do
		newPart(
			"Banco",
			Vector3.new(beam - 1, 0.4, 1.2),
			frame * CFrame.new(0, 1.4, z),
			DECK_WOOD,
			Enum.Material.WoodPlanks,
			boat
		)
	end
	local lanternPost = newPart(
		"PosteFarol",
		Vector3.new(0.3, 3, 0.3),
		frame * CFrame.new(0, 2.6, -length / 2 + 1.6),
		IRON,
		Enum.Material.Metal,
		boat
	)
	local lantern = newPart(
		"Farol",
		Vector3.new(0.9, 1.1, 0.9),
		lanternPost.CFrame * CFrame.new(0, 2, 0),
		LANTERN_LIGHT,
		Enum.Material.Neon,
		boat
	)
	decor(lantern)
	light(lantern, LANTERN_LIGHT, 18, 2)

	-- Aviso para zarpar (el Lobby lo trata como el botón "Ir a la Isla").
	local promptAnchor =
		newPart("Amarre", Vector3.new(2, 2, 2), frame * CFrame.new(0, 2, 2), DARK_WOOD, Enum.Material.Wood, boat)
	promptAnchor.Transparency = 1
	decor(promptAnchor)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZarparPrompt"
	prompt.ActionText = "Zarpar hacia la isla"
	prompt.ObjectText = "Bote salvavidas"
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
	sign(board, Enum.NormalId.Front, "⛵ A LA ISLA →", Color3.fromRGB(45, 30, 15), Enum.Font.Antique)
	boat.Parent = parent
end

-- Rampa de tablas de la arena a la cubierta (por el hueco de la borda).
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
		"Rampa",
		Vector3.new(4, 0.6, length + 1),
		CFrame.lookAt((top + foot) / 2, top),
		DECK_WOOD,
		Enum.Material.WoodPlanks,
		parent
	)
	for i = 1, math.floor(length / 2) do
		decor(
			newPart(
				"Listón",
				Vector3.new(4, 0.25, 0.3),
				ramp.CFrame * CFrame.new(0, 0.4, length / 2 - i * 2),
				DARK_WOOD,
				Enum.Material.Wood,
				parent
			)
		)
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

function LobbyBuilder.isBuilt(): boolean
	return Workspace:FindFirstChild(FOLDER_NAME) ~= nil
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
