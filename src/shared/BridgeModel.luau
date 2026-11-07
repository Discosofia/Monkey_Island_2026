--!strict
-- Interior del puente de mando del carguero «Esperanza» para la escena «Shipwreck» (Fase 25, G6a): una cáscara fina
-- (suelo, paredes y cristales) que sustituye a la caja maciza del puente en el clon del barco, y dentro la consola con tres
-- pantallas, el timón de rueda, la silla del capitán, la mesa con la carta y dos faroles.
--   BridgeModel.build(options?)  el modelo. Marco propio: origen en el centro de la cara de arriba del suelo del puente, +X
--                        hacia la proa (donde están los cristales de delante), +Y arriba y +Z a estribor. PrimaryPart =
--                        "Suelo". Todo va soldado al suelo, sin anclar y sin colisión: quien lo use ancla el suelo y lo
--                        coloca con PivotTo. options = { length, width, height } con las medidas de la caja del puente
--                        (por defecto las de LobbyBuilder: 6 x 24 x 3,6); la cáscara se ajusta a ellas.
--   BridgeModel.AVATAR   dónde se para el avatar (pies, marco del puente), mirando a +X, detrás del timón.
--   BridgeModel.GLASS    franja de altura del cristal de delante (la pieza «Cristalera» del barco): de y GLASS.low a GLASS.high.
-- Los cristales de los costados son paneles transparentes; el de delante lo hace transparente quien usa el modelo.
-- Recuento (Config.Budgets.Models.Bridge): cáscara 12 (suelo, pared de delante bajo y sobre el cristal, dos postes, pared
-- de atrás, costados bajo, sobre y cristal ×2), consola 1, pantallas 6 (marco y pantalla ×3), luces de instrumentos 4, timón
-- 14 (pedestal, cubo, 4 radios, 8 empuñaduras), silla 3, mesa con carta 7 y dos faroles 6 = 53.

local WHITE = Color3.fromRGB(232, 232, 226) -- WHITE_PAINT de LobbyBuilder: el blanco del castillo
local GLASS_BLUE = Color3.fromRGB(120, 150, 175)
local STEEL = Color3.fromRGB(62, 66, 72)
local DARK = Color3.fromRGB(28, 30, 34)
local SCREEN = Color3.fromRGB(35, 85, 130)
local LEATHER = Color3.fromRGB(110, 50, 40)
local WOOD = Color3.fromRGB(150, 108, 66)
local WOOD_DARK = Color3.fromRGB(110, 78, 46)
local CREAM = Color3.fromRGB(232, 222, 196)
local BRASS = Color3.fromRGB(190, 150, 70)
local WARM = Color3.fromRGB(255, 190, 110)
local PALE_BLUE = Color3.fromRGB(150, 185, 255)
local GREEN = Color3.fromRGB(60, 255, 120)
local RED = Color3.fromRGB(255, 60, 50)

local DEFAULT_LENGTH, DEFAULT_WIDTH, DEFAULT_HEIGHT = 6, 24, 3.6
local FLOOR_THICKNESS = 0.3
local WALL = 0.3
local GLASS_LOW, GLASS_HIGH = 1.27, 2.97 -- altura del cristal de delante sobre el suelo del interior, que queda 0,08 sobre el techo del Castillo (LobbyBuilder: 21,25 a 22,95)
local SIDE_GLASS_LOW, SIDE_GLASS_HIGH = 1.2, 2.5

local BridgeModel = {}

BridgeModel.AVATAR = Vector3.new(0.45, 0, 0)
BridgeModel.GLASS = { low = GLASS_LOW, high = GLASS_HIGH }

function BridgeModel.build(options: { length: number?, width: number?, height: number?, raise: number? }?): Model
	local length = if options and options.length then options.length else DEFAULT_LENGTH
	local width = if options and options.width then options.width else DEFAULT_WIDTH
	local height = if options and options.height then options.height else DEFAULT_HEIGHT
	local front = length / 2
	-- raise: cuánto más alto es el puente que el original (el techo sube); los cristales crecen hacia arriba lo mismo.
	local raise = if options and options.raise then options.raise else 0
	local glassHigh = GLASS_HIGH + raise
	local sideHigh = SIDE_GLASS_HIGH + raise

	local model = Instance.new("Model")
	model.Name = "InteriorPuente"

	local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = cframe
		part.Color = color
		part.Material = material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Parent = model
		return part
	end

	-- Suelo: raíz del modelo, un panel de acero bajo el piso; el origen del modelo queda en su cara de arriba.
	local floorCenter = Vector3.new(0, -FLOOR_THICKNESS / 2, 0)
	local base = newPart(
		"Suelo",
		Vector3.new(length - 0.1, FLOOR_THICKNESS, width - 0.1),
		CFrame.new(floorCenter),
		STEEL,
		Enum.Material.DiamondPlate
	)
	base.PivotOffset = CFrame.new(-floorCenter)
	base.Massless = false
	model.PrimaryPart = base

	local function weld(part: Part)
		local joint = Instance.new("Weld")
		joint.Part0 = base
		joint.Part1 = part
		joint.C0 = base.CFrame:ToObjectSpace(part.CFrame)
		joint.Parent = part
	end

	local function box(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
		local part = newPart(name, size, CFrame.new(position), color, material)
		weld(part)
		return part
	end

	-- Igual, con una rotación (pantallas inclinadas, radios del timón).
	local function turned(
		name: string,
		size: Vector3,
		position: Vector3,
		rotation: CFrame,
		color: Color3,
		material: Enum.Material
	): Part
		local part = newPart(name, size, CFrame.new(position) * rotation, color, material)
		weld(part)
		return part
	end

	-- Cáscara (12). El cristal de delante lo pone el barco en su sitio (Cristalera); aquí, lo que lo rodea.
	local wallX = front - WALL / 2
	box(
		"ParedDelanteBaja",
		Vector3.new(WALL, GLASS_LOW, width),
		Vector3.new(wallX, GLASS_LOW / 2, 0),
		WHITE,
		Enum.Material.SmoothPlastic
	)
	box(
		"ParedDelanteAlta",
		Vector3.new(WALL, height - glassHigh, width),
		Vector3.new(wallX, (glassHigh + height) / 2, 0),
		WHITE,
		Enum.Material.SmoothPlastic
	)
	for _, side in { -1, 1 } do
		box(
			"PostePuente",
			Vector3.new(WALL, glassHigh - GLASS_LOW, 0.5),
			Vector3.new(wallX, (GLASS_LOW + glassHigh) / 2, side * (width / 2 - 0.25)),
			WHITE,
			Enum.Material.SmoothPlastic
		)
	end
	box(
		"ParedAtras",
		Vector3.new(WALL, height, width),
		Vector3.new(-front + WALL / 2, height / 2, 0),
		WHITE,
		Enum.Material.SmoothPlastic
	)
	for _, side in { -1, 1 } do
		local z = side * (width / 2 - WALL / 2)
		box(
			"CostadoBajo",
			Vector3.new(length - WALL, SIDE_GLASS_LOW, WALL),
			Vector3.new(0, SIDE_GLASS_LOW / 2, z),
			WHITE,
			Enum.Material.SmoothPlastic
		)
		box(
			"CostadoAlto",
			Vector3.new(length - WALL, height - sideHigh, WALL),
			Vector3.new(0, (sideHigh + height) / 2, z),
			WHITE,
			Enum.Material.SmoothPlastic
		)
		local pane = box(
			"CristalCostado",
			Vector3.new(length - WALL, sideHigh - SIDE_GLASS_LOW, 0.15),
			Vector3.new(0, (SIDE_GLASS_LOW + sideHigh) / 2, z),
			GLASS_BLUE,
			Enum.Material.Glass
		)
		pane.Transparency = 0.55
	end

	-- Consola de mandos pegada al cristal de delante, con tres pantallas apagadas o tenues (un marco oscuro y la
	-- pantalla con un Neon azul muy bajo), inclinadas hacia quien está al timón, y cuatro luces de instrumentos
	-- (verde y rojo, Neon sin PointLight).
	local consoleX = front - WALL - 0.45
	box("Consola", Vector3.new(0.9, 0.9, 9), Vector3.new(consoleX, 0.45, 0), STEEL, Enum.Material.Metal)
	local tilt = CFrame.Angles(0, 0, math.rad(12))
	for _, z in { -3.2, 0, 3.2 } do
		local at = Vector3.new(consoleX - 0.15, 1.2, z)
		turned("MarcoPantalla", Vector3.new(0.1, 0.55, 0.95), at, tilt, DARK, Enum.Material.SmoothPlastic)
		local screen = turned(
			"Pantalla",
			Vector3.new(0.06, 0.42, 0.8),
			at + Vector3.new(-0.06, 0, 0),
			tilt,
			SCREEN,
			Enum.Material.Neon
		)
		if z == 0 then
			-- Luz suave azul pálido de la pantalla del centro: da luz a la silueta del avatar y al timón.
			local glow = Instance.new("PointLight")
			glow.Color = PALE_BLUE
			glow.Range = 10 -- con más brillo las paredes blancas se queman (G6a: probado 0,4 y 0,2)
			glow.Brightness = 0.2
			glow.Shadows = false
			glow.Parent = screen
		end
	end
	for index, color in { GREEN, RED, GREEN, RED } do
		local z = if index <= 2 then -4.15 + (index - 1) * 0.3 else 3.85 + (index - 3) * 0.3
		box(
			"LuzInstrumento",
			Vector3.new(0.08, 0.08, 0.08),
			Vector3.new(consoleX - 0.3, 0.93, z),
			color,
			Enum.Material.Neon
		)
	end

	-- Timón de rueda voxel (14): pedestal, cubo, cuatro radios (0°, 45°, 90° y 135°) y ocho empuñaduras en sus puntas.
	local wheelX = consoleX - 1.0
	local wheelY = 1.45
	box("PedestalTimon", Vector3.new(0.25, 1.3, 0.25), Vector3.new(wheelX, 0.65, 0), WOOD_DARK, Enum.Material.Wood)
	box("CuboTimon", Vector3.new(0.3, 0.3, 0.3), Vector3.new(wheelX, wheelY, 0), BRASS, Enum.Material.Metal)
	for index = 0, 3 do
		turned(
			"RadioTimon",
			Vector3.new(0.08, 1.24, 0.08),
			Vector3.new(wheelX, wheelY, 0),
			CFrame.Angles(math.rad(index * 45), 0, 0),
			WOOD,
			Enum.Material.Wood
		)
	end
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		box(
			"EmpunaduraTimon",
			Vector3.new(0.14, 0.14, 0.14),
			Vector3.new(wheelX, wheelY + math.cos(angle) * 0.68, math.sin(angle) * 0.68),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end

	-- Silla del capitán (3), de cara a proa, junto a la pared de atrás.
	local chairX = -front + WALL + 1.2
	box("PieSilla", Vector3.new(0.2, 0.6, 0.2), Vector3.new(chairX, 0.3, -3.6), STEEL, Enum.Material.Metal)
	box("AsientoSilla", Vector3.new(0.8, 0.12, 0.8), Vector3.new(chairX, 0.66, -3.6), LEATHER, Enum.Material.Fabric)
	box(
		"RespaldoSilla",
		Vector3.new(0.12, 0.9, 0.8),
		Vector3.new(chairX - 0.4, 1.17, -3.6),
		LEATHER,
		Enum.Material.Fabric
	)

	-- Mesa con la carta (7): tablero, cuatro patas, el papel y la ruta marcada en rojo; con un farol encima.
	local tableX = -front + WALL + 0.9
	box("MesaCarta", Vector3.new(1.2, 0.1, 1.8), Vector3.new(tableX, 0.85, 3.8), WOOD, Enum.Material.Wood)
	for _, dx in { -0.5, 0.5 } do
		for _, dz in { -0.75, 0.75 } do
			box(
				"PataMesa",
				Vector3.new(0.12, 0.85, 0.12),
				Vector3.new(tableX + dx, 0.425, 3.8 + dz),
				WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	box("Carta", Vector3.new(1, 0.02, 1.4), Vector3.new(tableX, 0.91, 3.8), CREAM, Enum.Material.Fabric)
	turned(
		"RutaCarta",
		Vector3.new(0.05, 0.025, 1),
		Vector3.new(tableX, 0.925, 3.8),
		CFrame.Angles(0, math.rad(25), 0),
		RED,
		Enum.Material.SmoothPlastic
	)

	-- Dos faroles de luz cálida y baja (3 piezas cada uno): uno en la mesa y otro en el extremo de la consola.
	local function lantern(x: number, y: number, z: number)
		box("BaseFarol", Vector3.new(0.4, 0.08, 0.4), Vector3.new(x, y + 0.04, z), DARK, Enum.Material.Metal)
		local body =
			box("CuerpoFarol", Vector3.new(0.3, 0.45, 0.3), Vector3.new(x, y + 0.305, z), WARM, Enum.Material.Neon)
		box("TapaFarol", Vector3.new(0.36, 0.07, 0.36), Vector3.new(x, y + 0.565, z), DARK, Enum.Material.Metal)
		local point = Instance.new("PointLight")
		point.Color = WARM
		point.Range = 16
		point.Brightness = 0.4
		point.Shadows = false
		point.Parent = body
	end
	lantern(tableX + 0.1, 0.9, 4.3)
	lantern(consoleX, 0.9, -4.35)

	return model
end

return BridgeModel
