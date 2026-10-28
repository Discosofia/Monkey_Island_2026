--!strict
-- Lo que comparten el escenario del Laboratorio (servidor, World/LabBuilder) y las maquetas voxel de los
-- mapas (la ventana de votación, bloque D de L4b): la paleta, única fuente de los colores del mapa
-- (hormigón gris, metal oxidado, cristal azulado, cables negros y amarillos y la selva apagada; nunca verde
-- brillante, que es el color de la curación).

local LabMapModels = {}

LabMapModels.PALETTE = {
	CONCRETE = Color3.fromRGB(150, 150, 146),
	CONCRETE_LIGHT = Color3.fromRGB(176, 176, 172),
	CONCRETE_DARK = Color3.fromRGB(104, 104, 102),
	RUST = Color3.fromRGB(140, 82, 50),
	RUST_DARK = Color3.fromRGB(96, 58, 38),
	STEEL = Color3.fromRGB(92, 98, 106),
	STEEL_DARK = Color3.fromRGB(58, 62, 68),
	GLASS = Color3.fromRGB(150, 196, 220), -- cristal azulado
	SERUM = Color3.fromRGB(80, 170, 235), -- el brillo azul del reactor y los tanques
	CABLE = Color3.fromRGB(28, 28, 30),
	HAZARD = Color3.fromRGB(236, 190, 40), -- franjas amarillas y negras
	VINE = Color3.fromRGB(58, 84, 48), -- selva oscura y apagada
	VINE_DARK = Color3.fromRGB(42, 62, 38),
	LEAF = Color3.fromRGB(70, 98, 54),
	BANANA = Color3.fromRGB(214, 180, 60),
	SOIL = Color3.fromRGB(78, 56, 40),
	WOOD = Color3.fromRGB(116, 80, 48),
	WOOD_DARK = Color3.fromRGB(78, 52, 32),
	PIRATE_BLACK = Color3.fromRGB(34, 31, 30),
	LAB_WHITE = Color3.fromRGB(226, 230, 234),
	WATER = Color3.fromRGB(46, 84, 104),
	JUNGLE_GROUND = Color3.fromRGB(56, 66, 44),
}

local PALETTE = LabMapModels.PALETTE

-- Colores propios de las maquetas (los de bando, como los fosos y las bocas de salida).
local GUARD_BLUE = Color3.fromRGB(58, 104, 196)
local PIRATE_YELLOW = Color3.fromRGB(236, 190, 40)
local SKY = Color3.fromRGB(138, 192, 232)
local CENTRAL_FLOOR = Color3.fromRGB(92, 104, 116)
local CENTRAL_WALL = Color3.fromRGB(122, 134, 148)
local SEWER_FLOOR = Color3.fromRGB(52, 48, 46)
local SEWER_BRICK = Color3.fromRGB(96, 86, 76)
local SEWER_BRICK_DARK = Color3.fromRGB(68, 62, 58)

-- Cada maqueta usa 1 stud por bloque (escala 1:8 del mapa) y se centra en el origen. Se ven desde el
-- este y el sur (-Z), a tres cuartos (RewardModels.frame).
type Put = (
	cx: number,
	cy: number,
	cz: number,
	sx: number,
	sy: number,
	sz: number,
	color: Color3,
	alpha: number?
) -> Part

local function maker(model: Model): Put
	return function(cx, cy, cz, sx, sy, sz, color, alpha)
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Material = Enum.Material.SmoothPlastic
		part.Size = Vector3.new(sx, sy, sz)
		part.Position = Vector3.new(cx, cy, cz)
		part.Color = color
		part.Transparency = alpha or 0
		part.Parent = model
		return part
	end
end

-- Cilindro de pie (la única pieza no cúbica: la bomba).
local function upright(
	model: Model,
	cx: number,
	cy: number,
	cz: number,
	height: number,
	diameter: number,
	color: Color3
)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = CFrame.new(cx, cy, cz) * CFrame.Angles(0, 0, math.pi / 2)
	part.Color = color
	part.Parent = model
end

-- Laboratorio central: losa de 20x15 bloques, fosos de salida (azul al este, amarillo al oeste), muros de los
-- tres carriles, el reactor con su pasarela alta, las jaulas al norte (+Z) y el invernadero al sur (-Z).
local function central(model: Model)
	local put = maker(model)
	local top = 0.5
	put(0, 0, 0, 20, 1, 15, CENTRAL_FLOOR)
	for _, z in { -5, 0, 5 } do
		put(0, top + 0.05, z, 14, 0.1, if z == 0 then 3.6 else 2, PALETTE.CONCRETE_LIGHT)
	end
	-- Fosos de salida, con su franja de aviso.
	for _, side in { 1, -1 } do
		put(8.5 * side, top + 0.05, 0, 3, 0.1, 7, if side == 1 then GUARD_BLUE else PIRATE_YELLOW)
		for step = 0, 3 do
			local color = if step % 2 == 0 then PALETTE.HAZARD else PALETTE.CABLE
			put(6.8 * side, top + 0.1, -2.25 + step * 1.5, 0.4, 0.2, 1.5, color)
		end
	end
	-- Muros de los carriles.
	for _, side in { 1, -1 } do
		for _, z in { -2.5, 2.5 } do
			put(3.5 * side, top + 0.75, z, 5, 1.5, 0.6, CENTRAL_WALL)
			put(3.5 * side, top + 1.6, z, 5.2, 0.2, 0.8, PALETTE.CONCRETE_LIGHT)
		end
	end
	-- Reactor azul y su pasarela alta.
	put(0, top + 0.5, 0, 4, 1, 4, PALETTE.STEEL_DARK)
	put(0, top + 2.5, 0, 2, 3, 2, PALETTE.SERUM)
	put(0, top + 4.25, 0, 3, 0.5, 3, PALETTE.STEEL)
	for _, x in { -1.6, 1.6 } do
		for _, z in { -1.6, 1.6 } do
			put(x, top + 1.25, z, 0.6, 0.5, 0.6, PALETTE.SERUM)
		end
	end
	put(0, top + 5.1, 0, 14, 0.3, 1.4, PALETTE.STEEL)
	for _, z in { -0.65, 0.65 } do
		put(0, top + 5.55, z, 14, 0.3, 0.1, PALETTE.HAZARD)
	end
	for _, x in { -6.5, -3.5, 3.5, 6.5 } do
		put(x, top + 2.5, 0, 0.6, 5, 0.6, PALETTE.STEEL_DARK)
	end
	-- Jaulas al norte.
	for _, x in { -6, -2, 2, 6 } do
		put(x, top + 0.75, 6.2, 2, 1.5, 1.8, PALETTE.STEEL_DARK)
		put(x, top + 0.75, 5.25, 1.4, 1, 0.15, PALETTE.GLASS)
		put(x, top + 1.6, 6.2, 2.2, 0.2, 2, PALETTE.STEEL)
	end
	-- Invernadero al sur: cristal y matas oscuras.
	for _, x in { -3.9, 3.9 } do
		for _, z in { -4.6, -7 } do
			put(x, top + 0.8, z, 0.3, 1.6, 0.3, PALETTE.STEEL)
		end
	end
	put(0, top + 1.7, -5.8, 8.2, 0.15, 2.6, PALETTE.GLASS, 0.45)
	put(0, top + 0.8, -7, 8, 1.4, 0.1, PALETTE.GLASS, 0.55)
	for index, x in { -3, -1.8, -0.6, 0.6, 1.8, 3 } do
		local color = if index % 2 == 0 then PALETTE.VINE else PALETTE.VINE_DARK
		put(x, top + 0.45, -5.6 + (index % 2) * 0.6, 1, 0.9, 1, color)
	end
	-- Tubería oxidada del borde norte.
	put(0, top + 2.2, 7.3, 18, 0.5, 0.5, PALETTE.RUST)
	for _, x in { -6, -2, 2, 6 } do
		put(x, top + 2.2, 7.3, 0.3, 0.8, 0.8, PALETTE.RUST_DARK)
	end
	for _, x in { -9, 9 } do
		put(x, top + 1.2, 7, 0.5, 2.4, 0.5, PALETTE.RUST)
	end
end

-- Azotea de la torre: el fuste de hormigón con sus ventanas, la azotea con el helipuerto y la caseta, la
-- terraza baja con la grúa amarilla, los dos huecos y las copas oscuras abajo, sobre un cielo claro.
local function rooftop(model: Model)
	local put = maker(model)
	put(0, -10, 0, 30, 0.4, 26, SKY, 0.2)
	local clouds = { { -12, -5, -4 }, { -11, 2, 5 }, { 14, -8, 6 }, { 15, -3, -7 }, { -13, -9, 8 }, { 4, -9, -11 } }
	for _, cloud in clouds do
		put(cloud[1], cloud[2], cloud[3], 4, 0.8, 2, PALETTE.LAB_WHITE)
	end
	local trees = {
		{ -6, -6 },
		{ -2.5, -8 },
		{ 3, -7 },
		{ 7, -5 },
		{ -8, -1 },
		{ 7.5, 3 },
		{ -6, 5 },
		{ 0, 7 },
		{ -9, -8 },
		{ 9, -1 },
		{ -3, 9 },
		{ 5, 8 },
	}
	for index, tree in trees do
		put(tree[1], -8.9, tree[2], 3.5, 1.8, 3.5, if index % 3 == 0 then PALETTE.VINE else PALETTE.VINE_DARK)
	end
	-- Fuste con bandas de ventanas en las dos caras que se ven.
	put(0, -1, 0, 6, 14, 6, PALETTE.CONCRETE)
	for y = -6, 4, 2 do
		put(0, y, -3.05, 5, 1, 0.12, PALETTE.GLASS)
		put(3.05, y, 0, 0.12, 1, 5, PALETTE.GLASS)
	end
	-- Azotea.
	put(0, 6.5, 0, 14, 1, 14, PALETTE.CONCRETE_LIGHT)
	for _, side in { 1, -1 } do
		put(0, 7.3, 6.75 * side, 14, 0.6, 0.5, SKY)
		put(6.75 * side, 7.3, 0, 0.5, 0.6, 13, SKY)
	end
	-- Helipuerto: la H blanca sobre un cuadrado oscuro.
	put(-1, 7.08, 1, 6, 0.16, 6, PALETTE.CONCRETE_DARK)
	put(-2, 7.2, 1, 0.6, 0.16, 3.4, PALETTE.LAB_WHITE)
	put(0, 7.2, 1, 0.6, 0.16, 3.4, PALETTE.LAB_WHITE)
	put(-1, 7.2, 1, 2, 0.16, 0.6, PALETTE.LAB_WHITE)
	for _, x in { -3.7, 1.7 } do
		for _, z in { -0.7, 2.7 } do
			put(x, 7.2, z, 0.5, 0.16, 0.5, PALETTE.HAZARD)
		end
	end
	-- Caseta de los ascensores, huecos y ventilaciones.
	put(4.2, 8.2, 4, 3, 2.4, 3, PALETTE.STEEL)
	put(4.2, 9.5, 4, 3.4, 0.2, 3.4, PALETTE.STEEL_DARK)
	put(4.2, 7.9, 2.45, 1.2, 1.6, 0.1, PALETTE.CABLE)
	put(4, 7.08, -3.8, 2, 0.12, 2, PALETTE.CABLE)
	put(-4.5, 7.08, -4.5, 2, 0.12, 2, PALETTE.CABLE)
	put(-5, 7.4, 4, 0.8, 0.8, 0.8, PALETTE.STEEL)
	put(-5, 7.4, 5.5, 0.8, 0.8, 0.8, PALETTE.STEEL)
	-- Terraza baja con la grúa amarilla al borde.
	put(8, 3.5, 0, 10, 0.8, 10, PALETTE.CONCRETE)
	for _, z in { -4, 4 } do
		put(12, 0.05, z, 0.8, 6.1, 0.8, PALETTE.CONCRETE_DARK)
	end
	put(12, 7.5, 0, 1, 7, 1, PALETTE.HAZARD)
	put(8.5, 11.4, 0, 8, 0.8, 0.8, PALETTE.HAZARD)
	put(13.2, 11, 0, 1.6, 1.2, 1.2, PALETTE.STEEL_DARK)
	put(9, 9.5, 0, 0.1, 3, 0.1, PALETTE.CABLE)
	put(9, 7.9, 0, 0.6, 0.5, 0.6, PALETTE.HAZARD)
end

-- Alcantarillas: un corte sin techo; túneles de hormigón en cruz (el principal, de este a oeste, y dos
-- colectores), la sala de bombas del centro con la bomba oxidada, el agua, las tuberías y las dos bocas de
-- color de bando (azul al este, amarilla al oeste).
local function sewers(model: Model)
	local put = maker(model)
	local top = 0.5
	put(0, 0, 0, 20, 1, 15, SEWER_FLOOR)
	-- Agua de los túneles.
	for _, side in { 1, -1 } do
		put(6.25 * side, top + 0.05, 0, 7.5, 0.1, 2.4, PALETTE.WATER)
		put(7 * side, top + 0.06, 0, 2.4, 0.1, 14.5, PALETTE.WATER)
	end
	-- Muros del túnel principal (con la abertura de cada colector) y de los colectores.
	for _, side in { 1, -1 } do
		for _, z in { -1.75, 1.75 } do
			put(9 * side, top + 1, z, 1, 2, 0.6, SEWER_BRICK)
			put(4.5 * side, top + 1, z, 2, 2, 0.6, SEWER_BRICK)
		end
		for _, x in { 5.25, 8.75 } do
			for _, z in { -1, 1 } do
				put(x * side, top + 1, 4.4 * z, 0.6, 2, 6.2, SEWER_BRICK_DARK)
			end
		end
	end
	-- Sala de bombas: suelo, pilares, muros norte y sur y las jambas de las entradas.
	put(0, top + 0.15, 0, 6, 0.3, 6, PALETTE.STEEL_DARK)
	for _, x in { -3, 3 } do
		for _, z in { -3, 3 } do
			put(x, top + 1, z, 1, 2, 1, PALETTE.CONCRETE)
		end
	end
	for _, z in { -3, 3 } do
		put(0, top + 1, z, 4.6, 2, 0.6, PALETTE.CONCRETE_DARK)
	end
	for _, x in { -3, 3 } do
		for _, z in { -2.1, 2.1 } do
			put(x, top + 1, z, 0.6, 2, 1.2, PALETTE.CONCRETE_DARK)
		end
	end
	-- La bomba: cuerpo cilíndrico oxidado, base y tubo hasta el colector.
	put(0, top + 0.6, 0, 2.6, 0.6, 2.6, PALETTE.RUST_DARK)
	upright(model, 0, top + 2, 0, 2.2, 1.8, PALETTE.RUST)
	put(0, top + 3.3, 0, 1.2, 0.4, 1.2, PALETTE.STEEL_DARK)
	put(0, top + 3.5, 1.8, 0.5, 0.5, 3.6, PALETTE.RUST)
	-- Tuberías oxidadas del borde norte y dos verticales.
	put(0, top + 1.5, 7.2, 18, 0.6, 0.6, PALETTE.RUST)
	for _, x in { -6, -2, 2, 6 } do
		put(x, top + 1.5, 7.2, 0.3, 0.9, 0.9, PALETTE.RUST_DARK)
	end
	for _, x in { -9.3, 9.3 } do
		put(x, top + 1.5, 6.4, 0.6, 3, 0.6, PALETTE.RUST_DARK)
	end
	-- Bocas de color de bando al final del túnel principal.
	for _, side in { 1, -1 } do
		local color = if side == 1 then GUARD_BLUE else PIRATE_YELLOW
		for _, z in { -1.75, 1.75 } do
			put(9.7 * side, top + 1.25, z, 0.6, 2.5, 0.6, color)
		end
		put(9.7 * side, top + 2.7, 0, 0.6, 0.4, 4.1, color)
		put(9.7 * side, top + 0.05, 0, 0.5, 0.1, 2.9, PALETTE.CABLE)
	end
	-- Rejillas, cajas y farolas de aviso.
	for _, x in { -4.5, 4.5 } do
		put(x, top + 0.1, 0, 1.6, 0.1, 2, PALETTE.CABLE)
	end
	put(7, top + 0.1, 4.5, 2, 0.1, 1.6, PALETTE.CABLE)
	for _, crate in { { -7.5, -4.5 }, { -6.5, -5.5 }, { 7, -5 }, { 6, -6 } } do
		put(crate[1], top + 0.45, crate[2], 0.9, 0.9, 0.9, PALETTE.RUST_DARK)
	end
	for _, x in { -4.5, 4.5 } do
		for _, z in { -2.2, 2.2 } do
			put(x, top + 2.2, z, 0.4, 0.4, 0.4, PALETTE.HAZARD)
		end
	end
end

local BUILDERS: { [string]: (Model) -> () } = {
	Central = central,
	Azotea = rooftop,
	Alcantarillas = sewers,
}

-- La maqueta voxel del mapa "mapId" (Config.Lab.Maps), centrada en el origen para RewardModels.frame.
function LabMapModels.build(mapId: string): Model
	local model = Instance.new("Model")
	model.Name = mapId
	local builder = BUILDERS[mapId]
	if builder then
		builder(model)
	end
	model:PivotTo(CFrame.new(0, 0, 0))
	return model
end

return LabMapModels
