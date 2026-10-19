--!strict
-- Construye las armas y herramientas como Tools de Roblox: aparecen en la mochila nativa, que ya
-- funciona como barra rápida en PC (teclas 1-9), móvil (casillas táctiles) y mando.
--
-- Cada arma y cada mejora tiene su modelo, hecho con piezas sencillas (cañas, bolas, cuñas) en el
-- estilo de la isla: madera, piedra, fibra, cuero, hueso y colmillos; las mejoras se ven más grandes
-- y llevan los materiales con que se fabrican (Data/Recipes).
-- Ejes (respecto a la pieza "Handle"): +Y va de la mano hacia la punta del arma y -Z es hacia donde
-- golpea (el filo del hacha, el del machete). "tool.Grip" marca dónde va la mano. En la mayoría el
-- "Handle" es invisible y solo sostiene las piezas. En Studio, el panel de pruebas tiene un
-- expositor con todas (DebugService). Está en Shared porque el panel de Ajustes (UI/SettingsPanel)
-- también dibuja el arma en la mano del personaje de la vista previa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local WOOD = Color3.fromRGB(110, 72, 40)
local DARK_BARK = Color3.fromRGB(75, 48, 28)
local LIGHT_WOOD = Color3.fromRGB(175, 130, 80)
local SANDED_WOOD = Color3.fromRGB(205, 165, 105)
local LEATHER = Color3.fromRGB(60, 40, 25)
local FIBER = Color3.fromRGB(150, 135, 85)
local FUR = Color3.fromRGB(150, 70, 45)
local GOLDEN_FUR = Color3.fromRGB(235, 190, 80)
local STEEL = Color3.fromRGB(140, 146, 152)
local STEEL_BRIGHT = Color3.fromRGB(185, 192, 200)
local STEEL_DARK = Color3.fromRGB(85, 90, 96)
local STEEL_EDGE = Color3.fromRGB(215, 220, 226)
local STONE = Color3.fromRGB(120, 120, 125)
local STONE_DARK = Color3.fromRGB(85, 85, 90)
local STONE_LIGHT = Color3.fromRGB(160, 160, 165)
local BONE = Color3.fromRGB(230, 220, 195)
local BONE_DARK = Color3.fromRGB(190, 175, 145)
local FANG = Color3.fromRGB(235, 225, 195)
local BIG_FANG = Color3.fromRGB(245, 205, 140)
local MANDRILL_FANG = Color3.fromRGB(240, 215, 200)
local GOLD = Color3.fromRGB(215, 170, 60)
local SILVER = Color3.fromRGB(200, 205, 215)
local LIANA_GREEN = Color3.fromRGB(70, 120, 50)
local LEAF_GREEN = Color3.fromRGB(95, 160, 65)
local WHISKER = Color3.fromRGB(55, 50, 50)
local RED_PAINT = Color3.fromRGB(175, 55, 40)
local OCHRE_PAINT = Color3.fromRGB(215, 150, 55)
local TEAL_PAINT = Color3.fromRGB(50, 150, 155)
local FEATHER_WHITE = Color3.fromRGB(240, 238, 230)
local FEATHER_BLACK = Color3.fromRGB(50, 50, 58)
local FEATHER_YELLOW = Color3.fromRGB(245, 200, 70)
local BAMBOO = Color3.fromRGB(190, 175, 95)
local BAMBOO_NODE = Color3.fromRGB(150, 135, 70)
local SHELL = Color3.fromRGB(240, 205, 190)

local WOOD_MATERIAL = Enum.Material.Wood
local STONE_MATERIAL = Enum.Material.Slate
local SMOOTH = Enum.Material.SmoothPlastic
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal

-- Los cilindros de Roblox van a lo largo de su X: así quedan a lo largo de la Y de "at".
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
-- Gira la Y de una pieza hacia +Z (cañas a lo largo de Z, puntas hacia atrás).
local TO_Z = CFrame.Angles(math.rad(90), 0, 0)

local WeaponTools = {}

-- ===================================== Piezas =====================================

local function newPiece(
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	className: string?
): BasePart
	local piece = Instance.new(className or "Part") :: BasePart
	piece.Name = name
	piece.Size = size
	piece.Color = color
	piece.Material = material
	piece.CanCollide = false
	piece.Massless = true
	return piece
end

-- Suelda una pieza decorativa al "Handle", colocada respecto a él.
local function attach(handle: BasePart, piece: BasePart, offset: CFrame)
	piece.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = handle.Parent
end

-- "Handle" invisible: solo marca dónde va la mano y sostiene las piezas. "tool" es la Tool (o el
-- Model de la antorcha, que no es una herramienta) donde se meten.
local function hiddenHandle(tool: Instance, size: Vector3): BasePart
	local handle = newPiece("Handle", size, WOOD, SMOOTH)
	handle.Transparency = 1
	handle.Parent = tool
	return handle
end

local function block(
	handle: BasePart,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	at: CFrame
): BasePart
	local piece = newPiece(name, size, color, material)
	attach(handle, piece, at)
	return piece
end

-- Caña (cilindro) a lo largo de la Y de "at".
local function rod(
	handle: BasePart,
	name: string,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	at: CFrame
): BasePart
	local piece = newPiece(name, Vector3.new(length, diameter, diameter), color, material) :: Part
	piece.Shape = Enum.PartType.Cylinder
	attach(handle, piece, at * UPRIGHT)
	return piece
end

local function ball(
	handle: BasePart,
	name: string,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	at: CFrame
): BasePart
	local piece = newPiece(name, Vector3.one * diameter, color, material) :: Part
	piece.Shape = Enum.PartType.Ball
	attach(handle, piece, at)
	return piece
end

-- Punta (colmillo, púa, punta de lanza): dos medias cuñas espalda con espalda que forman un prisma
-- triangular apuntando hacia la +Y de "at". "width" es su grosor (X) y "depth" su base (Z).
local function tooth(
	handle: BasePart,
	name: string,
	length: number,
	width: number,
	depth: number,
	color: Color3,
	material: Enum.Material,
	at: CFrame
)
	for side = -1, 1, 2 do
		local half = newPiece(name, Vector3.new(width, length, depth / 2), color, material, "WedgePart")
		local flip = if side > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
		attach(handle, half, at * CFrame.new(0, 0, side * depth / 4) * flip)
	end
end

-- Filo: dos medias cuñas espalda con espalda que se afilan hacia la -Z de "at" (hachas).
local function edge(
	handle: BasePart,
	name: string,
	height: number,
	thickness: number,
	depth: number,
	color: Color3,
	material: Enum.Material,
	at: CFrame
)
	for side = -1, 1, 2 do
		local half = newPiece(name, Vector3.new(height, thickness / 2, depth), color, material, "WedgePart")
		attach(handle, half, at * CFrame.new(side * thickness / 4, 0, 0) * CFrame.Angles(0, 0, -side * math.rad(90)))
	end
end

-- Pieza recta de "from" a "to" (puntos respecto al Handle): palas del arco, gomas de la honda,
-- garras de los bastones. "height" va hacia "up" y "width" de lado.
local function strut(
	handle: BasePart,
	name: string,
	from: Vector3,
	to: Vector3,
	width: number,
	height: number,
	color: Color3,
	material: Enum.Material,
	up: Vector3?
): BasePart
	local piece = newPiece(name, Vector3.new(width, height, (to - from).Magnitude), color, material)
	attach(handle, piece, CFrame.lookAt((from + to) / 2, to, up or Vector3.yAxis))
	return piece
end

-- Vueltas de liana o de cuerda alrededor de un tramo recto, algo inclinadas como una espiral.
local function wraps(
	handle: BasePart,
	from: Vector3,
	to: Vector3,
	count: number,
	diameter: number,
	color: Color3,
	up: Vector3
)
	for index = 1, count do
		local point = from:Lerp(to, index / (count + 1))
		local along = CFrame.lookAt(point, to, up) * CFrame.Angles(math.rad(90), 0, 0)
		rod(handle, "Wrap", 0.1, diameter, color, FABRIC, along * CFrame.Angles(math.rad(20), 0, 0))
	end
end

-- Hoja de hierba o de árbol pequeña.
local function leaf(handle: BasePart, size: number, at: CFrame)
	block(handle, "Leaf", Vector3.new(0.28, 0.04, 0.5) * size, LEAF_GREEN, SMOOTH, at)
end

-- Luz y chispas de un cristal mágico (solo se ven con el arma en la mano).
local function glow(part: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 1.5
	light.Parent = part
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(color)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new(0.2, 1)
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Rate = 5
	sparkles.Speed = NumberRange.new(0.4, 1.2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = part
end

-- ===================================== Machetes =====================================

type MacheteStyle = {
	length: number,
	width: number,
	steel: Color3,
	reflectance: number,
	grip: Color3,
	gripMaterial: Enum.Material,
	guard: Color3,
	serrated: boolean,
}

-- La hoja es el "Handle": fina en X y ancha en Z, con el filo en -Z y el lomo en +Z.
local function buildMachete(tool: Tool, style: MacheteStyle): BasePart
	local length, width = style.length, style.width
	local blade = newPiece("Handle", Vector3.new(0.12, length, width), style.steel, METAL)
	blade.Reflectance = style.reflectance
	blade.Parent = tool

	-- Punta en ángulo: la cuña conserva el lomo y sube el filo hasta él.
	local tip = newPiece("Tip", Vector3.new(0.12, 0.8, width), style.steel, METAL, "WedgePart")
	tip.Reflectance = style.reflectance
	attach(blade, tip, CFrame.new(0, length / 2 + 0.4, 0))
	-- Filo brillante, lomo oscuro y acanaladura.
	local shine = newPiece("Edge", Vector3.new(0.13, length, 0.1), STEEL_EDGE, SMOOTH)
	shine.Reflectance = style.reflectance + 0.2
	attach(blade, shine, CFrame.new(0, 0, -(width / 2 - 0.045)))
	block(blade, "Spine", Vector3.new(0.16, length, 0.09), STEEL_DARK, METAL, CFrame.new(0, 0, width / 2 - 0.045))
	block(
		blade,
		"Fuller",
		Vector3.new(0.14, length * 0.73, 0.07),
		STEEL_DARK,
		METAL,
		CFrame.new(0, -length * 0.1, width * 0.19)
	)
	if style.serrated then
		-- Dientes de sierra en el lomo, hechos al afilarlo con piedra.
		for index = 0, 4 do
			tooth(
				blade,
				"Serration",
				0.18,
				0.1,
				0.16,
				style.steel,
				METAL,
				CFrame.new(0, -length / 2 + 0.45 + index * 0.28, width / 2 + 0.02) * TO_Z
			)
		end
	end

	-- Guarda, empuñadura con dos vueltas de cuero, remaches y pomo.
	local gripY = -length / 2 - 0.75
	local boneGrip = style.gripMaterial == SMOOTH
	block(
		blade,
		"Guard",
		Vector3.new(0.3, 0.15, width + 0.15),
		style.guard,
		if boneGrip then SMOOTH else METAL,
		CFrame.new(0, -length / 2 - 0.08, 0)
	)
	block(blade, "Grip", Vector3.new(0.34, 1.2, 0.42), style.grip, style.gripMaterial, CFrame.new(0, gripY, 0))
	for _, offset in { 0.4, -0.4 } do
		block(blade, "Wrap", Vector3.new(0.38, 0.12, 0.46), LEATHER, FABRIC, CFrame.new(0, gripY + offset, 0))
	end
	for _, offset in { 0.15, -0.15 } do
		local rivet = newPiece("Rivet", Vector3.new(0.4, 0.12, 0.12), STEEL_EDGE, METAL) :: Part
		rivet.Shape = Enum.PartType.Cylinder
		attach(blade, rivet, CFrame.new(0, gripY + offset, 0))
	end
	if boneGrip then
		ball(blade, "Pommel", 0.46, style.guard, SMOOTH, CFrame.new(0, gripY - 0.7, 0))
	else
		block(blade, "Pommel", Vector3.new(0.38, 0.2, 0.48), STEEL_DARK, METAL, CFrame.new(0, gripY - 0.7, 0))
	end

	tool.Grip = CFrame.new(0, gripY, 0)
	return blade
end

-- ===================================== Hondas =====================================

type SlingStyle = { size: number, wood: Color3, band: Color3, bandWidth: number, liana: boolean }

-- Tirachinas: horquilla de rama con dos gomas que llevan a una bolsa de cuero con una piedra.
local function buildSling(tool: Tool, style: SlingStyle): BasePart
	local size = style.size
	local handle = hiddenHandle(tool, Vector3.new(0.4, 1.4, 0.4) * size)
	local forkY = 0.8 * size
	rod(handle, "Stem", 1.7 * size, 0.36 * size, style.wood, WOOD_MATERIAL, CFrame.new(0, -0.05 * size, 0))
	ball(handle, "Fork", 0.48 * size, style.wood, WOOD_MATERIAL, CFrame.new(0, forkY, 0))

	local angle = math.rad(24)
	local prongLength = 1.3 * size
	local base = Vector3.new(0, forkY, 0)
	local tips = {}
	for side = -1, 1, 2 do
		local direction = Vector3.new(side * math.sin(angle), math.cos(angle), 0)
		local rotation = CFrame.Angles(0, 0, -side * angle)
		local tip = base + direction * prongLength
		rod(
			handle,
			"Prong",
			prongLength,
			0.28 * size,
			style.wood,
			WOOD_MATERIAL,
			CFrame.new(base + direction * prongLength / 2) * rotation
		)
		ball(handle, "Knob", 0.32 * size, style.wood, WOOD_MATERIAL, CFrame.new(tip))
		if style.liana then
			wraps(handle, base, tip, 3, 0.34 * size, LIANA_GREEN, Vector3.zAxis)
		end
		table.insert(tips, tip)
	end

	-- Las gomas se estiran hacia el jugador (+Z) hasta la bolsa.
	local pouch = Vector3.new(0, forkY + prongLength * math.cos(angle) * 0.85, 0.5 * size)
	for _, tip in tips do
		strut(handle, "Band", tip, pouch, style.bandWidth, style.bandWidth, style.band, FABRIC)
	end
	block(handle, "Pouch", Vector3.new(0.42, 0.3, 0.14) * size, LEATHER, FABRIC, CFrame.new(pouch))
	ball(handle, "Pebble", 0.22 * size, STONE, STONE_MATERIAL, CFrame.new(pouch + Vector3.new(0, 0, 0.07 * size)))

	rod(
		handle,
		"Wrap",
		0.8 * size,
		0.42 * size,
		if style.liana then LEATHER else FIBER,
		FABRIC,
		CFrame.new(0, -0.25 * size, 0)
	)
	if style.liana then
		leaf(handle, size, CFrame.new(0.22 * size, forkY - 0.1 * size, -0.12 * size) * CFrame.Angles(0.5, 0.3, 0.7))
		leaf(
			handle,
			size * 0.8,
			CFrame.new(-0.2 * size, forkY - 0.25 * size, 0.1 * size) * CFrame.Angles(-0.4, -0.5, -0.6)
		)
	end
	tool.Grip = CFrame.new(0, -0.25 * size, 0)
	return handle
end

-- ===================================== Antorcha y lanza =====================================

-- Antorcha: no es una herramienta. Una vez fabricada se lleva siempre en la mano izquierda
-- (TorchService), así que se monta en un Model con su "Handle" como PrimaryPart. La mano la agarra
-- por TORCH_GRIP; el fuego y la luz los enciende y apaga TorchService (empiezan apagados).
WeaponTools.TORCH_GRIP = CFrame.new(0, -0.6, 0)

function WeaponTools.buildTorch(): Model
	local model = Instance.new("Model")
	model.Name = "Antorcha"
	local handle = hiddenHandle(model, Vector3.new(0.35, 2.6, 0.35))
	model.PrimaryPart = handle
	rod(handle, "Stick", 2.6, 0.3, WOOD, WOOD_MATERIAL, CFrame.new())
	rod(handle, "Wrap", 0.6, 0.36, LEATHER, FABRIC, CFrame.new(0, -0.6, 0))
	-- Cabeza de trapo empapado, atada con cuerda y quemada por arriba.
	local head = rod(handle, "Head", 0.8, 0.55, Color3.fromRGB(80, 60, 40), FABRIC, CFrame.new(0, 1.5, 0))
	for _, y in { 1.15, 1.85 } do
		rod(handle, "Rope", 0.12, 0.6, FIBER, FABRIC, CFrame.new(0, y, 0))
	end
	ball(handle, "Charred", 0.5, Color3.fromRGB(40, 30, 25), FABRIC, CFrame.new(0, 1.92, 0))
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Enabled = false
	fire.Parent = head
	local light = Instance.new("PointLight")
	light.Range = 28
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Shadows = true
	light.Enabled = false
	light.Parent = head
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
	return model
end

-- Lanza: asta larga con un colmillo atado en la punta, un mechón de pelaje y contera de piedra.
local function buildSpear(tool: Tool): BasePart
	local handle = hiddenHandle(tool, Vector3.new(0.25, 6, 0.25))
	rod(handle, "Shaft", 6, 0.22, WOOD, WOOD_MATERIAL, CFrame.new())
	tooth(handle, "Tip", 1, 0.14, 0.42, FANG, SMOOTH, CFrame.new(0, 3.45, 0))
	rod(handle, "Lashing", 0.4, 0.3, FIBER, FABRIC, CFrame.new(0, 2.95, 0))
	ball(handle, "Fur", 0.42, FUR, FABRIC, CFrame.new(0, 2.6, 0))
	for side = -1, 1, 2 do
		-- Dos colmillos pequeños colgando del mechón.
		tooth(
			handle,
			"Charm",
			0.3,
			0.08,
			0.14,
			FANG,
			SMOOTH,
			CFrame.new(side * 0.16, 2.25, 0) * CFrame.Angles(0, 0, math.pi + side * 0.2)
		)
	end
	rod(handle, "Wrap", 0.9, 0.28, LEATHER, FABRIC, CFrame.new(0, -1.2, 0))
	ball(handle, "Butt", 0.3, STONE, STONE_MATERIAL, CFrame.new(0, -3, 0))
	tool.Grip = CFrame.new(0, -1.2, 0)
	return handle
end

-- ===================================== Hachas y picos =====================================

-- Mango común de hachas y picos: la mano va abajo, la cabeza arriba (y = 1.35-1.4).
local function toolShaft(tool: Tool, wood: Color3, wrap: Color3): BasePart
	local handle = hiddenHandle(tool, Vector3.new(0.35, 3.2, 0.35))
	rod(handle, "Shaft", 3.2, 0.32, wood, WOOD_MATERIAL, CFrame.new(0, 0.2, 0))
	rod(handle, "Wrap", 0.9, 0.38, wrap, FABRIC, CFrame.new(0, -0.9, 0))
	rod(handle, "Butt", 0.18, 0.4, DARK_BARK, WOOD_MATERIAL, CFrame.new(0, -1.35, 0))
	tool.Grip = CFrame.new(0, -0.9, 0)
	return handle
end

local AXE_Y = 1.35

-- Hacha de madera: una cuña de madera dura atada al mango.
local function buildWoodenAxe(tool: Tool): BasePart
	local handle = toolShaft(tool, WOOD, FIBER)
	block(handle, "Head", Vector3.new(0.36, 0.8, 0.75), LIGHT_WOOD, WOOD_MATERIAL, CFrame.new(0, AXE_Y, -0.42))
	edge(handle, "Edge", 0.95, 0.36, 0.4, SANDED_WOOD, WOOD_MATERIAL, CFrame.new(0, AXE_Y, -0.99))
	for _, offset in { -0.32, 0.32 } do
		block(handle, "Lashing", Vector3.new(0.44, 0.12, 0.95), FIBER, FABRIC, CFrame.new(0, AXE_Y + offset, -0.3))
	end
	ball(handle, "Knot", 0.36, WOOD, WOOD_MATERIAL, CFrame.new(0, 1.8, 0))
	return handle
end

-- Hacha de piedra: piedra tallada con el filo más claro, atada en cruz.
local function buildStoneAxe(tool: Tool): BasePart
	local handle = toolShaft(tool, WOOD, LEATHER)
	block(
		handle,
		"Head",
		Vector3.new(0.42, 0.85, 0.6),
		STONE,
		STONE_MATERIAL,
		CFrame.new(0, AXE_Y, -0.4) * CFrame.Angles(0, 0, math.rad(4))
	)
	block(handle, "Back", Vector3.new(0.38, 0.5, 0.35), STONE_DARK, STONE_MATERIAL, CFrame.new(0, AXE_Y, 0.28))
	edge(handle, "Edge", 1.1, 0.42, 0.5, STONE_LIGHT, STONE_MATERIAL, CFrame.new(0, AXE_Y, -0.95))
	for _, tilt in { 0.55, -0.55 } do
		block(
			handle,
			"Lashing",
			Vector3.new(0.48, 0.1, 1.25),
			FIBER,
			FABRIC,
			CFrame.new(0, AXE_Y, -0.1) * CFrame.Angles(tilt, 0, 0)
		)
	end
	return handle
end

-- Hacha de hueso: hoja ancha de hueso en media luna, con cuernos arriba y abajo y una rótula detrás.
local function buildBoneAxe(tool: Tool): BasePart
	local handle = toolShaft(tool, DARK_BARK, LEATHER)
	block(handle, "Head", Vector3.new(0.3, 1, 0.55), BONE, SMOOTH, CFrame.new(0, AXE_Y, -0.5))
	edge(handle, "Edge", 1.6, 0.3, 0.45, BONE, SMOOTH, CFrame.new(0, AXE_Y, -0.98))
	tooth(handle, "Horn", 0.5, 0.3, 0.35, BONE, SMOOTH, CFrame.new(0, AXE_Y + 0.95, -1.02) * CFrame.Angles(-0.3, 0, 0))
	tooth(
		handle,
		"Horn",
		0.5,
		0.3,
		0.35,
		BONE,
		SMOOTH,
		CFrame.new(0, AXE_Y - 0.95, -1.02) * CFrame.Angles(math.pi + 0.3, 0, 0)
	)
	ball(handle, "Joint", 0.55, BONE_DARK, SMOOTH, CFrame.new(0, AXE_Y, 0.25))
	block(
		handle,
		"Crack",
		Vector3.new(0.32, 0.5, 0.04),
		BONE_DARK,
		SMOOTH,
		CFrame.new(0, AXE_Y + 0.1, -0.62) * CFrame.Angles(0, 0, 0.4)
	)
	for _, offset in { -0.4, 0.4 } do
		rod(handle, "Lashing", 0.14, 0.42, LEATHER, FABRIC, CFrame.new(0, AXE_Y + offset, 0))
	end
	block(handle, "Strap", Vector3.new(0.34, 0.12, 0.7), LEATHER, FABRIC, CFrame.new(0, AXE_Y, -0.25))
	return handle
end

local PICK_Y = 1.4
-- Las puntas del pico miran hacia delante (-Z) y hacia atrás (+Z), algo caídas.
local PICK_FRONT = CFrame.Angles(-math.rad(100), 0, 0)
local PICK_BACK = CFrame.Angles(math.rad(100), 0, 0)

-- Pico de madera: travesaño de madera dura con las dos puntas afiladas.
local function buildWoodenPick(tool: Tool): BasePart
	local handle = toolShaft(tool, WOOD, FIBER)
	rod(handle, "Head", 1.3, 0.36, LIGHT_WOOD, WOOD_MATERIAL, CFrame.new(0, PICK_Y, 0) * TO_Z)
	tooth(
		handle,
		"Point",
		0.65,
		0.3,
		0.34,
		SANDED_WOOD,
		WOOD_MATERIAL,
		CFrame.new(0, PICK_Y - 0.03, -0.95) * PICK_FRONT
	)
	tooth(handle, "Point", 0.65, 0.3, 0.34, SANDED_WOOD, WOOD_MATERIAL, CFrame.new(0, PICK_Y - 0.03, 0.95) * PICK_BACK)
	block(handle, "Lashing", Vector3.new(0.44, 0.5, 0.44), FIBER, FABRIC, CFrame.new(0, PICK_Y, 0))
	return handle
end

-- Pico de piedra: cabeza de piedra con puntas largas y más claras, atada en cruz.
local function buildStonePick(tool: Tool): BasePart
	local handle = toolShaft(tool, WOOD, LEATHER)
	block(handle, "Head", Vector3.new(0.36, 0.42, 1.2), STONE, STONE_MATERIAL, CFrame.new(0, PICK_Y, 0))
	tooth(handle, "Point", 0.8, 0.34, 0.4, STONE_LIGHT, STONE_MATERIAL, CFrame.new(0, PICK_Y - 0.04, -1) * PICK_FRONT)
	tooth(handle, "Point", 0.8, 0.34, 0.4, STONE_LIGHT, STONE_MATERIAL, CFrame.new(0, PICK_Y - 0.04, 1) * PICK_BACK)
	for _, tilt in { 0.6, -0.6 } do
		block(
			handle,
			"Lashing",
			Vector3.new(0.44, 0.1, 0.75),
			FIBER,
			FABRIC,
			CFrame.new(0, PICK_Y - 0.1, 0) * CFrame.Angles(tilt, 0, 0)
		)
	end
	return handle
end

-- Pico de hueso: un hueso grueso atravesado, con una gran púa delante y un nudo de martillo detrás.
local function buildBonePick(tool: Tool): BasePart
	local handle = toolShaft(tool, DARK_BARK, LEATHER)
	rod(handle, "Head", 1.2, 0.4, BONE, SMOOTH, CFrame.new(0, PICK_Y, 0) * TO_Z)
	tooth(handle, "Point", 1.1, 0.32, 0.44, BONE, SMOOTH, CFrame.new(0, PICK_Y - 0.08, -1.15) * PICK_FRONT)
	ball(handle, "Hammer", 0.6, BONE_DARK, SMOOTH, CFrame.new(0, PICK_Y, 0.65))
	block(handle, "Lashing", Vector3.new(0.48, 0.55, 0.48), LEATHER, FABRIC, CFrame.new(0, PICK_Y, 0))
	return handle
end

-- ===================================== Hoz =====================================

-- Hoja de la hoz: un arco en el plano YZ del mango. Sale de la punta del mango, sube un poco, va
-- hacia delante (-Z) y baja hasta acabar mirando otra vez hacia la mano. El ángulo se mide desde
-- arriba girando hacia delante; el lomo (lado de fuera) va a SICKLE_RADIUS del centro y el filo
-- es el lado de dentro.
local SICKLE_CENTER = Vector3.new(0, 0.78, -1.03)
local SICKLE_RADIUS = 1.1
local SICKLE_FROM = math.rad(-70)
local SICKLE_TO = math.rad(115)
local SICKLE_SEGMENTS = 12

-- Punto del arco de la hoz a "angle" y a "radius" del centro.
local function sickleArc(angle: number, radius: number): Vector3
	return SICKLE_CENTER + Vector3.new(0, math.cos(angle), -math.sin(angle)) * radius
end

-- Hoz: mango corto de madera con empuñadura de cuero y hoja de pedernal en media luna, atada con
-- fibra a la punta. Ancha junto al mango y fina hacia la punta, con el filo de dentro más claro.
local function buildSickle(tool: Tool): BasePart
	local handle = hiddenHandle(tool, Vector3.new(0.35, 2.4, 0.35))
	rod(handle, "Shaft", 2.4, 0.3, WOOD, WOOD_MATERIAL, CFrame.new())
	rod(handle, "Wrap", 0.8, 0.36, LEATHER, FABRIC, CFrame.new(0, -0.55, 0))
	rod(handle, "Butt", 0.16, 0.38, DARK_BARK, WOOD_MATERIAL, CFrame.new(0, -1.15, 0))
	tool.Grip = CFrame.new(0, -0.55, 0)

	local step = (SICKLE_TO - SICKLE_FROM) / SICKLE_SEGMENTS
	local length = step * SICKLE_RADIUS + 0.06 -- un poco de solape entre tramos
	local tipWidth = 0.14
	for index = 1, SICKLE_SEGMENTS do
		local angle = SICKLE_FROM + step * (index - 0.5)
		local width = 0.44 - (0.44 - tipWidth) * (index - 1) / (SICKLE_SEGMENTS - 1)
		-- La Y de cada tramo sigue el arco y su Z apunta hacia fuera.
		local tangent = Vector3.new(0, -math.sin(angle), -math.cos(angle))
		local blade = CFrame.fromMatrix(sickleArc(angle, SICKLE_RADIUS - width / 2), Vector3.xAxis, tangent)
		block(handle, "Blade", Vector3.new(0.12, length, width), STONE, STONE_MATERIAL, blade)
		local edgeAt = CFrame.fromMatrix(sickleArc(angle, SICKLE_RADIUS - width - 0.01), Vector3.xAxis, tangent)
		block(handle, "Edge", Vector3.new(0.07, length, 0.09), STONE_LIGHT, STONE_MATERIAL, edgeAt)
	end
	local tipTangent = Vector3.new(0, -math.sin(SICKLE_TO), -math.cos(SICKLE_TO))
	local tipBase = sickleArc(SICKLE_TO, SICKLE_RADIUS - tipWidth / 2)
	tooth(
		handle,
		"Tip",
		0.36,
		0.12,
		tipWidth,
		STONE_LIGHT,
		STONE_MATERIAL,
		CFrame.fromMatrix(tipBase + tipTangent * 0.16, Vector3.xAxis, tipTangent)
	)

	-- Atadura en cruz donde la hoja se une al mango, y el nudo de arriba.
	for _, tilt in { 0.5, -0.5 } do
		block(
			handle,
			"Lashing",
			Vector3.new(0.4, 0.1, 0.62),
			FIBER,
			FABRIC,
			CFrame.new(0, 1.02, -0.12) * CFrame.Angles(tilt, 0, 0)
		)
	end
	ball(handle, "Knot", 0.34, WOOD, WOOD_MATERIAL, CFrame.new(0, 1.22, 0))
	return handle
end

-- ===================================== Garrotes y mazas =====================================

type FangClubStyle = {
	size: number,
	wood: Color3,
	cap: Color3,
	fang: Color3,
	fangLength: number,
	-- Anillos de colmillos: altura y radio del garrote ahí (antes de "size").
	rings: { { number } },
	perRing: number,
	topFang: boolean, -- un colmillo de mandril en la punta
	wrap: Color3,
}

-- Garrote con colmillos: se ensancha del mango a la punta y lleva colmillos clavados en anillos.
local function buildFangClub(tool: Tool, style: FangClubStyle): BasePart
	local size = style.size
	local handle = hiddenHandle(tool, Vector3.new(0.35, 2, 0.35))
	rod(handle, "Grip", 1.6, 0.32, style.wood, WOOD_MATERIAL, CFrame.new(0, -0.4, 0))
	rod(handle, "Wrap", 0.9, 0.38, style.wrap, FABRIC, CFrame.new(0, -0.6, 0))
	ball(handle, "Pommel", 0.42, style.cap, WOOD_MATERIAL, CFrame.new(0, -1.2, 0))
	rod(handle, "Body", 1 * size, 0.5 * size, style.wood, WOOD_MATERIAL, CFrame.new(0, 0.85 * size, 0))
	rod(handle, "Body", 1 * size, 0.7 * size, style.wood, WOOD_MATERIAL, CFrame.new(0, 1.75 * size, 0))
	rod(handle, "Body", 0.9 * size, 0.85 * size, style.wood, WOOD_MATERIAL, CFrame.new(0, 2.6 * size, 0))
	ball(handle, "Top", 0.86 * size, style.cap, WOOD_MATERIAL, CFrame.new(0, 3.05 * size, 0))
	rod(handle, "Band", 0.2, 0.62, style.cap, WOOD_MATERIAL, CFrame.new(0, 0.4, 0))

	local fangLength = style.fangLength * size
	for ringIndex, ring in style.rings do
		local y, radius = ring[1] * size, ring[2] * size
		for index = 0, style.perRing - 1 do
			local angle = (index + ringIndex * 0.5) * math.pi * 2 / style.perRing
			tooth(
				handle,
				"Fang",
				fangLength,
				0.16 * size,
				0.3 * size,
				style.fang,
				SMOOTH,
				CFrame.new(0, y, 0)
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(0, 0, -(radius + fangLength / 2 - 0.05))
					* CFrame.Angles(-math.rad(90), 0, 0)
			)
		end
	end
	if style.topFang then
		tooth(
			handle,
			"MandrillFang",
			1 * size,
			0.28 * size,
			0.5 * size,
			MANDRILL_FANG,
			SMOOTH,
			CFrame.new(0, 3.85 * size, 0)
		)
	end
	tool.Grip = CFrame.new(0, -0.6, 0)
	return handle
end

-- Garrote de piedra (guerrero): mango de madera con una roca de varias caras atada en la punta.
local function buildStoneClub(tool: Tool): BasePart
	local handle = hiddenHandle(tool, Vector3.new(0.35, 2.6, 0.35))
	rod(handle, "Shaft", 3.1, 0.36, WOOD, WOOD_MATERIAL, CFrame.new(0, 0.25, 0))
	rod(handle, "Wrap", 0.9, 0.42, LEATHER, FABRIC, CFrame.new(0, -0.7, 0))
	rod(handle, "Butt", 0.18, 0.44, DARK_BARK, WOOD_MATERIAL, CFrame.new(0, -1.25, 0))
	-- Roca grande de varias caras: tres bloques girados que se solapan.
	local rockY = 2.3
	for _, rock in
		{
			{ Vector3.new(1.5, 1.7, 1.4), STONE, CFrame.new(0, rockY, 0) * CFrame.Angles(0.35, 0.6, 0.2) },
			{
				Vector3.new(1.2, 1.15, 1.25),
				STONE_DARK,
				CFrame.new(0.18, rockY + 0.45, -0.1) * CFrame.Angles(-0.4, 0.2, 0.5),
			},
			{
				Vector3.new(0.9, 0.8, 0.9),
				STONE_LIGHT,
				CFrame.new(-0.3, rockY - 0.4, 0.22) * CFrame.Angles(0.7, 0.9, 0.1),
			},
		} :: { { any } }
	do
		block(handle, "Rock", rock[1], rock[2], STONE_MATERIAL, rock[3])
	end
	-- Correas de fibra por encima de la roca y atadura en el mango.
	block(
		handle,
		"Strap",
		Vector3.new(0.16, 2.1, 1.65),
		FIBER,
		FABRIC,
		CFrame.new(0, rockY, 0) * CFrame.Angles(0, 0.3, 0)
	)
	rod(handle, "Lashing", 0.35, 0.48, FIBER, FABRIC, CFrame.new(0, 1.35, 0))
	tool.Grip = CFrame.new(0, -0.7, 0)
	return handle
end

-- Maza de hueso: mango de hueso con nudos, collar de pelaje rojo y una gran bola de piedra con púas
-- de hueso.
local function buildBoneMace(tool: Tool): BasePart
	local handle = hiddenHandle(tool, Vector3.new(0.4, 2.6, 0.4))
	rod(handle, "Shaft", 3, 0.38, BONE, SMOOTH, CFrame.new(0, 0.2, 0))
	for side = -1, 1, 2 do
		ball(handle, "Knob", 0.48, BONE, SMOOTH, CFrame.new(side * 0.15, -1.35, 0))
	end
	rod(handle, "Wrap", 0.9, 0.46, LEATHER, FABRIC, CFrame.new(0, -0.7, 0))
	rod(handle, "Fur", 0.4, 0.75, FUR, FABRIC, CFrame.new(0, 1.4, 0))
	local headY, radius = 2.25, 0.8
	ball(handle, "Head", radius * 2, STONE, STONE_MATERIAL, CFrame.new(0, headY, 0))
	-- Dos anillos de 5 púas, cada uno girado respecto al otro, y una arriba.
	for ring, height in { -0.25, 0.3 } do
		for index = 0, 4 do
			local angle = (index + ring * 0.5) * math.pi * 2 / 5
			tooth(
				handle,
				"Spike",
				0.6,
				0.22,
				0.38,
				BONE,
				SMOOTH,
				CFrame.new(0, headY + height, 0)
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(0, 0, -(radius * 0.9 + 0.25))
					* CFrame.Angles(-math.rad(90), 0, 0)
			)
		end
	end
	tooth(handle, "Spike", 0.7, 0.24, 0.4, BONE, SMOOTH, CFrame.new(0, headY + radius + 0.28, 0))
	tool.Grip = CFrame.new(0, -0.7, 0)
	return handle
end

-- Mazo de hueso grueso: un fémur enorme. Caña gruesa que se ensancha hacia los extremos; el de golpe
-- (+Y) con dos cóndilos grandes y una cabeza redonda, y el del mango con dos nudos más pequeños.
local function buildThickBoneMaul(tool: Tool): BasePart
	local handle = hiddenHandle(tool, Vector3.new(0.6, 1.7, 0.6))
	rod(handle, "Shaft", 4, 0.62, BONE, SMOOTH, CFrame.new(0, 1, 0))
	rod(handle, "Neck", 0.8, 0.86, BONE, SMOOTH, CFrame.new(0, 2.75, 0))
	rod(handle, "BaseNeck", 0.45, 0.76, BONE, SMOOTH, CFrame.new(0, -0.95, 0))
	for side = -1, 1, 2 do
		ball(handle, "Condyle", 1.4, BONE, SMOOTH, CFrame.new(side * 0.45, 3.35, 0))
	end
	ball(handle, "Knob", 1.1, BONE, SMOOTH, CFrame.new(0, 3.65, 0.2))
	ball(handle, "Trochanter", 0.7, BONE_DARK, SMOOTH, CFrame.new(0.55, 2.9, -0.15))
	for side = -1, 1, 2 do
		ball(handle, "Pommel", 0.8, BONE, SMOOTH, CFrame.new(side * 0.28, -1.25, 0))
	end
	-- Grietas y manchas de hueso viejo.
	for _, crack in
		{
			{ CFrame.new(-0.45, 3.35, -0.69) * CFrame.Angles(0, 0, math.rad(25)), 0.55 },
			{ CFrame.new(0.5, 3.45, -0.67) * CFrame.Angles(0, 0, math.rad(-35)), 0.4 },
			{ CFrame.new(0, 1.9, -0.3) * CFrame.Angles(0, 0, math.rad(10)), 0.7 },
		} :: { { any } }
	do
		block(handle, "Crack", Vector3.new(0.05, crack[2], 0.05), BONE_DARK, SMOOTH, crack[1])
	end
	rod(handle, "Stain", 0.35, 0.64, BONE_DARK, SMOOTH, CFrame.new(0, 2.25, 0))
	-- Empuñadura de cuero con ataduras de fibra.
	rod(handle, "Wrap", 1.7, 0.74, LEATHER, FABRIC, CFrame.new())
	for _, y in { -0.85, 0.85, 2.35 } do
		rod(handle, "Lashing", 0.14, 0.8, FIBER, FABRIC, CFrame.new(0, y, 0))
	end
	tool.Grip = CFrame.new(0, -0.2, 0)
	return handle
end

-- ===================================== Arcos =====================================

type BowStyle = {
	size: number,
	limb: Color3,
	riser: Color3,
	riserMaterial: Enum.Material,
	grip: Color3,
	string: Color3,
	tips: Color3,
	paint: { Color3 }, -- bandas pintadas en las palas, de la empuñadura hacia fuera
	feathers: { Color3 }, -- plumas que cuelgan de la empuñadura
	plates: boolean, -- placas de hueso en la espalda de las palas (arco reforzado)
	liana: boolean, -- palas envueltas en liana y hojas en las puntas (arco de liana)
	fang: boolean, -- un colmillo colgado junto a las plumas
}

-- Arco recurvo: las palas van a lo largo de Y y se curvan hacia el arquero (+Z), donde va la cuerda;
-- las puntas se doblan hacia fuera (-Z).
local function buildBow(tool: Tool, style: BowStyle): BasePart
	local size = style.size
	local handle = hiddenHandle(tool, Vector3.new(0.3, 0.9, 0.35))
	block(handle, "Riser", Vector3.new(0.32, 1.1, 0.42), style.riser, style.riserMaterial, CFrame.new())
	block(handle, "Grip", Vector3.new(0.36, 0.6, 0.46), style.grip, FABRIC, CFrame.new())
	block(handle, "ArrowRest", Vector3.new(0.12, 0.1, 0.22), style.tips, SMOOTH, CFrame.new(0.2, 0.36, 0.04))

	-- Banda alrededor de la pala en "point" (pintura, atadura).
	local function band(point: Vector3, direction: Vector3, length: number, color: Color3, material: Enum.Material)
		local half = direction.Unit * length / 2
		strut(handle, "Band", point - half, point + half, 0.35, 0.28, color, material, Vector3.xAxis)
	end

	local tipY, tipZ = 0, 0
	for side = -1, 1, 2 do
		local start = Vector3.new(0, side * 0.5, 0)
		local middle = Vector3.new(0, side * 1.35 * size, 0.12 * size)
		local tip = Vector3.new(0, side * 2.05 * size, 0.5 * size)
		local curl = tip + Vector3.new(0, side * 0.3 * size, -0.12 * size)
		strut(handle, "Limb", start, middle, 0.3, 0.24, style.limb, WOOD_MATERIAL, Vector3.xAxis)
		strut(handle, "Limb", middle, tip, 0.25, 0.21, style.limb, WOOD_MATERIAL, Vector3.xAxis)
		strut(handle, "Limb", tip, curl, 0.2, 0.18, style.limb, WOOD_MATERIAL, Vector3.xAxis)
		ball(handle, "Nock", 0.22, style.tips, SMOOTH, CFrame.new(curl))
		-- Ataduras de cuero donde la pala sale de la empuñadura.
		band(start, middle - start, 0.16, LEATHER, FABRIC)
		for index, color in style.paint do
			band(start:Lerp(middle, index / (#style.paint + 1)), middle - start, 0.14, color, SMOOTH)
		end
		if style.plates then
			local back = Vector3.new(0, 0, -0.14)
			strut(handle, "Plate", start + back, middle + back, 0.1, 0.27, BONE, SMOOTH, Vector3.xAxis)
			for _, point in { start:Lerp(middle, 0.5), middle } do
				band(point, middle - start, 0.1, FIBER, FABRIC)
			end
		end
		if style.liana then
			wraps(handle, start, middle, 3, 0.33, LIANA_GREEN, Vector3.xAxis)
			wraps(handle, middle, tip, 2, 0.29, LIANA_GREEN, Vector3.xAxis)
			leaf(handle, 0.9, CFrame.new(tip) * CFrame.Angles(side * 0.6, 0.4, 0.3))
			leaf(handle, 0.7, CFrame.new(tip) * CFrame.Angles(-side * 0.5, -0.5, -0.4))
		end
		tipY, tipZ = tip.Y, tip.Z
	end
	block(handle, "String", Vector3.new(0.05, tipY * 2, 0.05), style.string, FABRIC, CFrame.new(0, 0, tipZ))

	-- Cordón con plumas (y a veces un colmillo) colgando a un lado de la empuñadura.
	local charmX = 0.22
	block(handle, "Cord", Vector3.new(0.03, 0.5, 0.03), FIBER, FABRIC, CFrame.new(charmX, -0.55, 0))
	for index, color in style.feathers do
		local offset = index - (#style.feathers + 1) / 2
		block(
			handle,
			"Feather",
			Vector3.new(0.04, 0.5, 0.14),
			color,
			SMOOTH,
			CFrame.new(charmX, -0.98, offset * 0.09) * CFrame.Angles(offset * 0.3, 0, 0)
		)
	end
	if style.fang then
		tooth(
			handle,
			"Charm",
			0.3,
			0.08,
			0.14,
			FANG,
			SMOOTH,
			CFrame.new(charmX + 0.04, -0.9, 0) * CFrame.Angles(math.pi, 0, 0)
		)
	end
	tool.Grip = CFrame.new()
	return handle
end

-- ===================================== Cerbatanas =====================================

type BlowgunStyle = {
	length: number,
	tube: Color3,
	tubeMaterial: Enum.Material,
	nodes: Color3, -- anillos a lo largo de la caña (nudos del bambú, bandas de hueso)
	nodeMaterial: Enum.Material,
	mouth: Color3, -- boquilla
	muzzle: Color3, -- remate de la punta
	tipMaterial: Enum.Material,
	grip: Color3,
	fur: boolean, -- mechón de pelaje rojo en la punta
	liana: boolean, -- caña envuelta en liana
	shells: boolean, -- conchas colgando junto a la empuñadura
	feathers: { Color3 }, -- plumas que cuelgan de la punta
	sap: boolean, -- anillo de savia que brilla en la punta
}

-- Cerbatana (médico): caña larga a lo largo de Y con la boquilla abajo, junto a la mano, y una bolsita
-- con dardos de savia atada a un lado.
local function buildBlowgun(tool: Tool, style: BlowgunStyle): BasePart
	local length = style.length
	local bottom = -1.4
	local top = bottom + length
	local handle = hiddenHandle(tool, Vector3.new(0.3, 1.4, 0.3))
	rod(handle, "Tube", length, 0.22, style.tube, style.tubeMaterial, CFrame.new(0, (bottom + top) / 2, 0))
	-- Nudos o bandas cada poco, sin tapar la empuñadura.
	local y = bottom + 0.9
	while y < top - 0.3 do
		if math.abs(y + 0.8) > 0.5 then
			rod(handle, "Node", 0.08, 0.27, style.nodes, style.nodeMaterial, CFrame.new(0, y, 0))
		end
		y += 0.6
	end
	rod(handle, "Mouthpiece", 0.3, 0.3, style.mouth, style.tipMaterial, CFrame.new(0, bottom + 0.1, 0))
	rod(handle, "Muzzle", 0.22, 0.3, style.muzzle, style.tipMaterial, CFrame.new(0, top - 0.08, 0))
	rod(handle, "Grip", 0.8, 0.28, style.grip, FABRIC, CFrame.new(0, -0.8, 0))

	-- Bolsita de cuero con tres dardos asomando.
	block(handle, "Pouch", Vector3.new(0.18, 0.42, 0.3), LEATHER, FABRIC, CFrame.new(0.2, -0.1, 0))
	for index = -1, 1 do
		local dart = CFrame.new(0.2, 0.2, index * 0.08) * CFrame.Angles(index * 0.15, 0, 0)
		rod(handle, "Dart", 0.4, 0.04, BONE, SMOOTH, dart)
		ball(handle, "Fluff", 0.11, LEAF_GREEN, FABRIC, dart * CFrame.new(0, 0.22, 0))
	end

	if style.liana then
		wraps(handle, Vector3.new(0, -0.2, 0), Vector3.new(0, top - 0.3, 0), 6, 0.28, LIANA_GREEN, Vector3.zAxis)
	end
	if style.fur then
		rod(handle, "Fur", 0.3, 0.36, FUR, FABRIC, CFrame.new(0, top - 0.4, 0))
	end
	if style.shells then
		for side = -1, 1, 2 do
			block(handle, "Cord", Vector3.new(0.03, 0.35, 0.03), FIBER, FABRIC, CFrame.new(-0.16, -0.3, side * 0.08))
			ball(handle, "Shell", 0.18, SHELL, SMOOTH, CFrame.new(-0.16, -0.5, side * 0.08))
		end
	end
	for index, color in style.feathers do
		local offset = index - (#style.feathers + 1) / 2
		block(handle, "Cord", Vector3.new(0.03, 0.3, 0.03), FIBER, FABRIC, CFrame.new(0.16, top - 0.35, offset * 0.08))
		block(
			handle,
			"Feather",
			Vector3.new(0.04, 0.42, 0.12),
			color,
			SMOOTH,
			CFrame.new(0.17, top - 0.68, offset * 0.09) * CFrame.Angles(offset * 0.3, 0, 0)
		)
	end
	if style.sap then
		local sap = rod(
			handle,
			"Sap",
			0.1,
			0.33,
			Color3.fromRGB(150, 225, 120),
			Enum.Material.Neon,
			CFrame.new(0, top - 0.25, 0)
		)
		glow(sap, Color3.fromRGB(150, 225, 120), 8)
	end
	tool.Grip = CFrame.new(0, -0.8, 0)
	return handle
end

-- ===================================== Bastones =====================================

type StaffStyle = {
	shaft: Color3,
	shaftMaterial: Enum.Material,
	claws: Color3,
	clawMaterial: Enum.Material,
	crystal: Color3,
	crystalSize: number,
	wrap: Color3,
	-- Adornos propios de cada bastón; "top" es la altura de la punta del asta.
	decorate: (handle: BasePart, top: number) -> (),
}

local STAFF_LENGTH = 4.6

-- Bastón: asta larga con cuatro garras que sujetan un cristal tallado que brilla.
local function buildStaff(tool: Tool, style: StaffStyle): BasePart
	local top = STAFF_LENGTH / 2
	local handle = hiddenHandle(tool, Vector3.new(0.3, STAFF_LENGTH, 0.3))
	local shaft = rod(handle, "Shaft", STAFF_LENGTH, 0.3, style.shaft, style.shaftMaterial, CFrame.new())
	if style.shaftMaterial == METAL then
		shaft.Reflectance = 0.15
	end
	rod(handle, "Collar", 0.25, 0.42, style.claws, style.clawMaterial, CFrame.new(0, top, 0))
	ball(handle, "Butt", 0.34, style.claws, style.clawMaterial, CFrame.new(0, -top, 0))
	rod(handle, "Wrap", 0.8, 0.36, style.wrap, FABRIC, CFrame.new(0, -0.6, 0))

	local crystalY = top + 0.6
	local crystal = block(
		handle,
		"Crystal",
		Vector3.one * style.crystalSize,
		style.crystal,
		Enum.Material.Neon,
		CFrame.new(0, crystalY, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	)
	crystal.Transparency = 0.1
	glow(crystal, style.crystal, 10)
	-- Garras: salen del collar, se abren alrededor del cristal y se cierran por encima.
	local reach = style.crystalSize * 0.75
	for index = 0, 3 do
		local angle = index * math.pi / 2 + math.pi / 4
		local outward = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local base = Vector3.new(0, top, 0) + outward * 0.12
		local bulge = Vector3.new(0, crystalY - 0.1, 0) + outward * reach
		local tip = Vector3.new(0, crystalY + style.crystalSize * 0.6, 0) + outward * reach * 0.35
		strut(handle, "Claw", base, bulge, 0.12, 0.12, style.claws, style.clawMaterial, outward)
		strut(handle, "Claw", bulge, tip, 0.1, 0.1, style.claws, style.clawMaterial, outward)
	end
	style.decorate(handle, top)
	tool.Grip = CFrame.new(0, -0.6, 0)
	return handle
end

-- ===================================== Lista =====================================

local BUILDERS: { [string]: (tool: Tool) -> BasePart } = {
	Machete = function(tool)
		return buildMachete(tool, {
			length = 2.6,
			width = 0.75,
			steel = STEEL,
			reflectance = 0.15,
			grip = WOOD,
			gripMaterial = WOOD_MATERIAL,
			guard = STEEL_DARK,
			serrated = false,
		})
	end,
	-- Afilado con piedra y con mango de hueso: más largo, más ancho, más brillante y con sierra.
	SharpMachete = function(tool)
		return buildMachete(tool, {
			length = 2.9,
			width = 0.85,
			steel = STEEL_BRIGHT,
			reflectance = 0.3,
			grip = BONE,
			gripMaterial = SMOOTH,
			guard = BONE_DARK,
			serrated = true,
		})
	end,
	Honda = function(tool)
		return buildSling(
			tool,
			{ size = 1, wood = WOOD, band = Color3.fromRGB(45, 35, 30), bandWidth = 0.07, liana = false }
		)
	end,
	-- Más grande, de madera oscura, con gomas de liana y la horquilla envuelta en liana.
	LianaSling = function(tool)
		return buildSling(tool, { size = 1.15, wood = DARK_BARK, band = LIANA_GREEN, bandWidth = 0.1, liana = true })
	end,
	Spear = buildSpear,
	WoodenAxe = buildWoodenAxe,
	StoneAxe = buildStoneAxe,
	BoneAxe = buildBoneAxe,
	WoodenPick = buildWoodenPick,
	StonePick = buildStonePick,
	BonePick = buildBonePick,
	Sickle = buildSickle,
	Club = function(tool)
		return buildFangClub(tool, {
			size = 1,
			wood = WOOD,
			cap = DARK_BARK,
			fang = FANG,
			fangLength = 0.5,
			rings = { { 1.6, 0.33 }, { 2.45, 0.42 } },
			perRing = 6,
			topFang = false,
			wrap = FUR,
		})
	end,
	-- Madera oscura, colmillos grandes y uno de mandril en la punta.
	BigFangClub = function(tool)
		return buildFangClub(tool, {
			size = 1.2,
			wood = DARK_BARK,
			cap = WOOD,
			fang = BIG_FANG,
			fangLength = 0.7,
			rings = { { 1.75, 0.33 }, { 2.6, 0.42 } },
			perRing = 4,
			topFang = true,
			wrap = LEATHER,
		})
	end,
	StoneClub = buildStoneClub,
	BoneMace = buildBoneMace,
	ThickBoneMaul = buildThickBoneMaul,
	-- Madera clara con bandas rojas y ocres pintadas y plumas blancas y rojas.
	Bow = function(tool)
		return buildBow(tool, {
			size = 1.25,
			limb = LIGHT_WOOD,
			riser = WOOD,
			riserMaterial = WOOD_MATERIAL,
			grip = LEATHER,
			string = Color3.fromRGB(235, 230, 215),
			tips = DARK_BARK,
			paint = { RED_PAINT, OCHRE_PAINT },
			feathers = { FEATHER_WHITE, RED_PAINT },
			plates = false,
			liana = false,
			fang = false,
		})
	end,
	-- Más largo: madera con placas de hueso atadas, empuñadura de pelaje rojo, puntas de hueso y un
	-- colmillo con plumas negras y blancas.
	ReinforcedBow = function(tool)
		return buildBow(tool, {
			size = 1.38,
			limb = WOOD,
			riser = DARK_BARK,
			riserMaterial = WOOD_MATERIAL,
			grip = FUR,
			string = Color3.fromRGB(235, 230, 215),
			tips = BONE,
			paint = { OCHRE_PAINT },
			feathers = { FEATHER_BLACK, FEATHER_WHITE, FEATHER_BLACK },
			plates = true,
			liana = false,
			fang = true,
		})
	end,
	-- El más largo: palas oscuras envueltas en liana con hojas, empuñadura de hueso grueso, cuerda de
	-- liana y plumas de colores de la selva.
	LianaBow = function(tool)
		return buildBow(tool, {
			size = 1.5,
			limb = DARK_BARK,
			riser = BONE,
			riserMaterial = SMOOTH,
			grip = LEATHER,
			string = Color3.fromRGB(120, 160, 80),
			tips = BONE,
			paint = {},
			feathers = { TEAL_PAINT, FEATHER_YELLOW, LEAF_GREEN, TEAL_PAINT },
			plates = false,
			liana = true,
			fang = false,
		})
	end,
	-- Caña de bambú con sus nudos, boquilla de madera y una bolsita de dardos.
	Blowgun = function(tool)
		return buildBlowgun(tool, {
			length = 3.6,
			tube = BAMBOO,
			tubeMaterial = WOOD_MATERIAL,
			nodes = BAMBOO_NODE,
			nodeMaterial = WOOD_MATERIAL,
			mouth = DARK_BARK,
			muzzle = BAMBOO_NODE,
			tipMaterial = WOOD_MATERIAL,
			grip = FIBER,
			fur = false,
			liana = false,
			shells = false,
			feathers = {},
			sap = false,
		})
	end,
	-- Más larga: madera con bandas, boquilla y punta de hueso, mechón de pelaje rojo y plumas.
	BoneBlowgun = function(tool)
		return buildBlowgun(tool, {
			length = 3.9,
			tube = WOOD,
			tubeMaterial = WOOD_MATERIAL,
			nodes = BONE,
			nodeMaterial = SMOOTH,
			mouth = BONE,
			muzzle = BONE,
			tipMaterial = SMOOTH,
			grip = LEATHER,
			fur = true,
			liana = false,
			shells = false,
			feathers = { FEATHER_WHITE, RED_PAINT },
			sap = false,
		})
	end,
	-- La más larga: madera oscura envuelta en liana, boquilla de hueso grueso, conchas, plumas de
	-- colores y un anillo de savia que brilla en la punta.
	ShamanBlowgun = function(tool)
		return buildBlowgun(tool, {
			length = 4.2,
			tube = DARK_BARK,
			tubeMaterial = WOOD_MATERIAL,
			nodes = BONE_DARK,
			nodeMaterial = SMOOTH,
			mouth = BONE,
			muzzle = BONE,
			tipMaterial = SMOOTH,
			grip = LEATHER,
			fur = false,
			liana = true,
			shells = true,
			feathers = { TEAL_PAINT, FEATHER_YELLOW, RED_PAINT },
			sap = true,
		})
	end,
	-- Rama retorcida con nudos y hojas que sujeta un cristal violeta.
	MagicStaff = function(tool)
		return buildStaff(tool, {
			shaft = DARK_BARK,
			shaftMaterial = WOOD_MATERIAL,
			claws = DARK_BARK,
			clawMaterial = WOOD_MATERIAL,
			crystal = Color3.fromRGB(170, 110, 255),
			crystalSize = 0.55,
			wrap = FIBER,
			decorate = function(handle, top)
				for _, knot in
					{ Vector3.new(0.08, -1.4, 0.04), Vector3.new(-0.07, 0.4, 0.05), Vector3.new(0.06, 1.3, -0.06) }
				do
					ball(handle, "Knot", 0.32, DARK_BARK, WOOD_MATERIAL, CFrame.new(knot))
				end
				leaf(handle, 1, CFrame.new(0.22, top - 0.2, 0) * CFrame.Angles(0.3, 0.2, -0.8))
				leaf(handle, 0.8, CFrame.new(-0.2, top - 0.35, 0.1) * CFrame.Angles(-0.2, -0.6, 0.9))
			end,
		})
	end,
	-- Bandas de oro, cuentas de hueso y un mechón de pelaje dorado bajo un cristal de sol.
	GoldenStaff = function(tool)
		return buildStaff(tool, {
			shaft = LIGHT_WOOD,
			shaftMaterial = WOOD_MATERIAL,
			claws = GOLD,
			clawMaterial = METAL,
			crystal = Color3.fromRGB(255, 210, 90),
			crystalSize = 0.65,
			wrap = LEATHER,
			decorate = function(handle, top)
				for _, y in { -1.2, 0.3, 1.5 } do
					rod(handle, "Band", 0.14, 0.36, GOLD, METAL, CFrame.new(0, y, 0))
				end
				for _, y in { 0.75, 0.95 } do
					rod(handle, "Bead", 0.16, 0.36, BONE, SMOOTH, CFrame.new(0, y, 0))
				end
				ball(handle, "GoldenFur", 0.5, GOLDEN_FUR, FABRIC, CFrame.new(0, top - 0.3, 0))
			end,
		})
	end,
	-- Asta de plata envuelta en liana, bigotes de marteja colgando y un colmillo de mandril en la punta.
	SilverStaff = function(tool)
		return buildStaff(tool, {
			shaft = SILVER,
			shaftMaterial = METAL,
			claws = SILVER,
			clawMaterial = METAL,
			crystal = Color3.fromRGB(120, 220, 255),
			crystalSize = 0.75,
			wrap = LEATHER,
			decorate = function(handle, top)
				wraps(
					handle,
					Vector3.new(0, -1.6, 0),
					Vector3.new(0, top - 0.3, 0),
					7,
					0.36,
					LIANA_GREEN,
					Vector3.zAxis
				)
				for index = 0, 3 do
					local angle = index * math.pi / 2
					local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * 0.2
					block(
						handle,
						"Whisker",
						Vector3.new(0.04, 0.9, 0.04),
						WHISKER,
						FABRIC,
						CFrame.new(Vector3.new(0, top - 0.5, 0) + offset)
							* CFrame.Angles(offset.Z * 0.6, 0, -offset.X * 0.6)
					)
				end
				tooth(handle, "MandrillFang", 0.7, 0.2, 0.34, MANDRILL_FANG, SMOOTH, CFrame.new(0, top + 1.45, 0))
			end,
		})
	end,
}

function WeaponTools.build(weaponId: string): Tool
	local weapon = Weapons[weaponId]
	local builder = BUILDERS[weaponId]
	assert(weapon and builder, `Arma desconocida: {weaponId}`)

	local tool = Instance.new("Tool")
	tool.Name = weapon.name
	local damage = math.round(weapon.damage * Config.Combat.PlayerDamageMultiplier)
	tool.ToolTip = `{weapon.name}: {damage} de daño`
	if weapon.tool then
		local kind = weapon.tool.kind
		tool.ToolTip ..= if kind == "Axe"
			then " · golpea árboles"
			elseif kind == "Sickle" then " · corta helechos y arbustos"
			else " · golpea rocas"
	end
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", weaponId)

	builder(tool)
	return tool
end

-- Sonido de uso, audible para todos. La animación del tajo la reproduce el cliente
-- (WeaponController) para que responda al instante.
function WeaponTools.playUse(tool: Tool)
	local handle = tool:FindFirstChild("Handle")
	local weaponId = tool:GetAttribute("WeaponId")
	local weapon = if typeof(weaponId) == "string" then Weapons[weaponId] else nil
	if handle and weapon then
		Sfx.play(weapon.sound or (if weapon.kind == "Melee" then "Swing" else "Shoot"), handle)
	end
end

return WeaponTools
