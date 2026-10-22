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
-- y el Armario (UI/WardrobePanel) también dibujan el arma en la mano del personaje de la vista previa.
--
-- Aspectos de arma (cosméticos "WeaponSkin" de Data/Cosmetics, Fase 9): cambian el modelo del arma
-- de un rol (la inicial y sus mejoras, del nivel 1 al 4) por otro con la misma empuñadura ("Grip") y
-- un tamaño parecido; el nivel se nota en el aspecto (los míticos ganan piezas con cada uno). El
-- aspecto equipado del rol lo publica CosmeticsServer en el atributo "WeaponSkin" del jugador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
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
-- Nivel 4, forja volcánica (Fase 9, G5).
local OBSIDIAN = Color3.fromRGB(30, 24, 38)
local OBSIDIAN_SHEEN = Color3.fromRGB(80, 60, 110)
local BASALT = Color3.fromRGB(62, 58, 60)
local MAGMA = Color3.fromRGB(255, 110, 30)
local EMBER = Color3.fromRGB(255, 180, 60)
local SULFUR = Color3.fromRGB(235, 205, 55)
local SULFUR_GLOW = Color3.fromRGB(255, 235, 110)

local WOOD_MATERIAL = Enum.Material.Wood
local STONE_MATERIAL = Enum.Material.Slate
local SMOOTH = Enum.Material.SmoothPlastic
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal
local GLASS = Enum.Material.Glass
local NEON = Enum.Material.Neon
local BASALT_MATERIAL = Enum.Material.Basalt

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
): { BasePart }
	local halves = {}
	for side = -1, 1, 2 do
		local half = newPiece(name, Vector3.new(width, length, depth / 2), color, material, "WedgePart")
		local flip = if side > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
		attach(handle, half, at * CFrame.new(0, 0, side * depth / 4) * flip)
		table.insert(halves, half)
	end
	return halves
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

-- Esquirla de obsidiana: un colmillo de vidrio negro con algo de reflejo (armas de la forja volcánica).
local function shard(handle: BasePart, length: number, width: number, at: CFrame)
	tooth(handle, "Obsidian", length, width, width * 1.4, OBSIDIAN, SMOOTH, at)
end

-- Chispas de lava que suben del arma (solo se ven con ella en la mano).
local function embers(part: BasePart, rate: number)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(EMBER, MAGMA)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new(0.1, 1)
	sparks.Lifetime = NumberRange.new(0.6, 1.1)
	sparks.Rate = rate
	sparks.Speed = NumberRange.new(1, 2.5)
	sparks.SpreadAngle = Vector2.new(30, 30)
	sparks.Acceleration = Vector3.new(0, 2, 0)
	sparks.Parent = part
end

-- Esquirla de obsidiana bañada en lava: sale de un cono de lava en su base ("at" es su centro, como en
-- "tooth").
local function lavaShard(handle: BasePart, length: number, width: number, at: CFrame)
	shard(handle, length, width, at)
	tooth(handle, "Lava", length * 0.4, width * 1.35, width * 1.9, MAGMA, NEON, at * CFrame.new(0, -length * 0.3, 0))
end

-- Gota de lava de "length" que cuelga hacia abajo desde "at".
local function lavaDrip(handle: BasePart, length: number, at: CFrame)
	local width = length * 0.4
	tooth(
		handle,
		"Drip",
		length,
		width,
		width,
		MAGMA,
		NEON,
		at * CFrame.new(0, -length / 2, 0) * CFrame.Angles(math.pi, 0, 0)
	)
end

-- Humo (o vapor, con "color") que sube del arma.
local function smoke(part: BasePart, rate: number, color: Color3?)
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puff.Color = ColorSequence.new(color or Color3.fromRGB(70, 66, 64), Color3.fromRGB(150, 145, 140))
	puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	puff.Lifetime = NumberRange.new(1, 1.8)
	puff.Rate = rate
	puff.Speed = NumberRange.new(0.5, 1.2)
	puff.SpreadAngle = Vector2.new(25, 25)
	puff.Acceleration = Vector3.new(0, 1.2, 0)
	puff.Rotation = NumberRange.new(0, 360)
	puff.RotSpeed = NumberRange.new(-30, 30)
	puff.Parent = part
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

-- Mazo volcánico: martillo de dos caras con la cabeza de basalto y aristas de obsidiana, cruzada por
-- una franja y grietas de lava que brillan y echan humo y chispas; la cara de golpe (-Z) es una losa de
-- obsidiana, detrás sale una púa y por arriba tres esquirlas, todas bañadas en lava, y por debajo
-- cuelgan gotas de lava. Mango de madera oscura con anillos de obsidiana, collar con cuatro púas y pomo
-- con una púa.
local function buildVolcanicMaul(tool: Tool): BasePart
	local handle = hiddenHandle(tool, Vector3.new(0.5, 1.7, 0.5))
	rod(handle, "Shaft", 3.9, 0.46, DARK_BARK, WOOD_MATERIAL, CFrame.new(0, 0.95, 0))
	rod(handle, "Wrap", 1.6, 0.56, LEATHER, FABRIC, CFrame.new())
	for _, y in { -0.8, 0.8 } do
		rod(handle, "Lashing", 0.12, 0.62, MAGMA, NEON, CFrame.new(0, y, 0))
	end
	block(handle, "Pommel", Vector3.new(0.62, 0.42, 0.62), OBSIDIAN, SMOOTH, CFrame.new(0, -1.05, 0)).Reflectance = 0.05
	rod(handle, "Collar", 0.3, 0.72, OBSIDIAN, SMOOTH, CFrame.new(0, 2.35, 0)).Reflectance = 0.05

	local headY = 3.25
	block(handle, "Head", Vector3.new(1.4, 1.35, 2.3), BASALT, BASALT_MATERIAL, CFrame.new(0, headY, 0))
	local face = block(handle, "Face", Vector3.new(1.55, 1.5, 0.32), OBSIDIAN, SMOOTH, CFrame.new(0, headY, -1.2))
	face.Reflectance = 0.05
	block(handle, "Sheen", Vector3.new(0.3, 1, 0.05), OBSIDIAN_SHEEN, SMOOTH, CFrame.new(-0.4, headY + 0.1, -1.37))
	block(handle, "Rim", Vector3.new(1.5, 1.45, 0.16), OBSIDIAN, SMOOTH, CFrame.new(0, headY, 1.1)).Reflectance = 0.05
	local band = block(handle, "Band", Vector3.new(1.46, 0.14, 2.36), MAGMA, NEON, CFrame.new(0, headY, 0))
	glow(band, MAGMA, 9)
	embers(band, 6)
	-- Grietas en zigzag por los dos lados de la cabeza.
	for side = -1, 1, 2 do
		for _, crack in
			{
				{ Vector3.new(0, 0.32, -0.55), 0.55, 0.7 },
				{ Vector3.new(0, -0.3, 0.4), 0.5, -0.6 },
				{ Vector3.new(0, 0.38, 0.55), 0.35, -0.9 },
			} :: { { any } }
		do
			local at: Vector3 = crack[1]
			block(
				handle,
				"Crack",
				Vector3.new(0.05, crack[2], 0.09),
				MAGMA,
				NEON,
				CFrame.new(side * 0.71, headY + at.Y, at.Z) * CFrame.Angles(crack[3], 0, 0)
			)
		end
	end
	-- Aristas de obsidiana a lo largo de la cabeza: más pesada y de bloques.
	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			block(
				handle,
				"Edge",
				Vector3.new(0.26, 0.26, 1.95),
				OBSIDIAN,
				SMOOTH,
				CFrame.new(sx * 0.66, headY + sy * 0.62, 0)
			)
		end
	end
	-- Púa de obsidiana hacia atrás y tres esquirlas arriba, bañadas en lava; gotas de lava colgando.
	lavaShard(handle, 0.9, 0.42, CFrame.new(0, headY, 1.6) * CFrame.Angles(math.rad(90), 0, 0))
	for index, z in { -0.6, 0, 0.6 } do
		lavaShard(
			handle,
			if index == 2 then 0.85 else 0.55,
			0.3,
			CFrame.new(0, headY + 0.67 + (if index == 2 then 0.42 else 0.27), z) * CFrame.Angles(z * 0.6, 0, 0)
		)
	end
	for index, z in { -0.75, -0.2, 0.35, 0.8 } do
		lavaDrip(
			handle,
			if index % 2 == 0 then 0.42 else 0.28,
			CFrame.new(if index % 2 == 0 then 0.2 else -0.2, headY - 0.66, z)
		)
	end
	smoke(band, 3)
	-- Collar con cuatro púas hacia fuera y abajo, anillos de obsidiana con lava entre ellos y un pomo
	-- con una púa.
	for index = 0, 3 do
		shard(
			handle,
			0.42,
			0.18,
			CFrame.new(0, 2.3, 0)
				* CFrame.Angles(0, index * math.pi / 2 + math.pi / 4, 0)
				* CFrame.new(0, 0, -0.55)
				* CFrame.Angles(-math.rad(110), 0, 0)
		)
	end
	for _, y in { 1.5, 2.0 } do
		rod(handle, "Ring", 0.14, 0.56, OBSIDIAN, SMOOTH, CFrame.new(0, y, 0))
	end
	rod(handle, "Seam", 0.1, 0.52, MAGMA, NEON, CFrame.new(0, 1.75, 0))
	shard(handle, 0.45, 0.22, CFrame.new(0, -1.48, 0) * CFrame.Angles(math.pi, 0, 0))
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
	-- Arco de brasa: grietas de lava en las palas, esquirlas bañadas en lava en su lomo, puntas de
	-- obsidiana con brasas que echan chispas, cuerda que brilla, aletas de obsidiana y runas de lava en
	-- la empuñadura y una gota de lava que echa chispas.
	lava: boolean?,
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
		if style.lava then
			-- Grieta por la cara de fuera de cada tramo y esquirla que sigue a la punta.
			local out = Vector3.new(0, 0, -0.13)
			strut(handle, "Crack", start:Lerp(middle, 0.15) + out, middle + out, 0.08, 0.05, MAGMA, NEON, Vector3.xAxis)
			strut(handle, "Crack", middle + out, tip:Lerp(middle, 0.2) + out, 0.07, 0.05, MAGMA, NEON, Vector3.xAxis)
			local reach = (curl - tip).Unit
			shard(handle, 0.5, 0.16, CFrame.lookAt(curl, curl + reach) * CFrame.Angles(-math.rad(90), 0, 0))
			embers(ball(handle, "Ember", 0.26, EMBER, NEON, CFrame.new(curl)), 2)
			-- Esquirlas bañadas en lava en el lomo de cada pala, hacia delante.
			for _, spot in { start:Lerp(middle, 0.55), middle:Lerp(tip, 0.45) } do
				lavaShard(
					handle,
					0.42,
					0.16,
					CFrame.new(spot + Vector3.new(0, 0, -0.32)) * CFrame.Angles(-math.rad(90) + side * 0.3, 0, 0)
				)
			end
		end
		tipY, tipZ = tip.Y, tip.Z
	end
	local bowString =
		block(handle, "String", Vector3.new(0.05, tipY * 2, 0.05), style.string, FABRIC, CFrame.new(0, 0, tipZ))
	if style.lava then
		bowString.Material = NEON
		local drop = ball(handle, "Ember", 0.22, MAGMA, NEON, CFrame.new(0, 0, -0.24))
		glow(drop, MAGMA, 7)
		embers(drop, 4)
		-- Aletas de obsidiana arriba y abajo de la empuñadura y dos runas de lava en ella.
		for side = -1, 1, 2 do
			shard(
				handle,
				0.5,
				0.16,
				CFrame.new(0, side * 0.72, -0.2) * CFrame.Angles(if side > 0 then -0.5 else math.pi + 0.5, 0, 0)
			)
			block(handle, "Rune", Vector3.new(0.38, 0.05, 0.05), MAGMA, NEON, CFrame.new(0, side * 0.18, -0.24))
		end
	end

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
	sapColor: Color3?, -- su color (verde savia si no se dice)
	-- Cerbatana de azufre: racimos de cristales de azufre que brillan bajo la boca y a media caña, anillos
	-- de azufre que brillan, aletas de obsidiana y vapor amarillo que sale de la boca.
	sulfur: boolean?,
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
		local sapColor = style.sapColor or Color3.fromRGB(150, 225, 120)
		local sap = rod(handle, "Sap", 0.1, 0.33, sapColor, Enum.Material.Neon, CFrame.new(0, top - 0.25, 0))
		glow(sap, sapColor, 8)
	end
	if style.sulfur then
		-- Cristal de azufre de "size" abierto hacia fuera desde la caña: funda amarilla y núcleo que brilla.
		local function sulfurCrystal(level: number, angle: number, size: number, tilt: number)
			local at = CFrame.new(0, level, 0)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, 0, -0.14)
				* CFrame.Angles(-tilt, 0, 0)
			local case = newPiece("Sulfur", Vector3.new(0.16, 0.5, 0.16) * size, SULFUR, GLASS, "CornerWedgePart")
			case.Transparency = 0.2
			attach(handle, case, at * CFrame.new(0, 0.25 * size, 0))
			local core =
				newPiece("SulfurCore", Vector3.new(0.08, 0.36, 0.08) * size, SULFUR_GLOW, NEON, "CornerWedgePart")
			attach(handle, core, at * CFrame.new(0.03 * size, 0.2 * size, -0.03 * size))
		end
		-- Racimo grande bajo la boca y otro pequeño a media caña.
		for index = 0, 4 do
			sulfurCrystal(top - 0.8, index * math.pi * 2 / 5 + 0.4, if index % 2 == 0 then 1.25 else 0.85, 0.5)
		end
		for index = 0, 2 do
			sulfurCrystal(0.55, index * math.pi * 2 / 3, 0.7, 0.6)
		end
		-- Anillos de azufre que brillan, aletas de obsidiana en la boquilla y vapor amarillo en la boca.
		for _, ringY in { top - 1.3, top - 1.55, 0.25 } do
			rod(handle, "Glow", 0.06, 0.28, SULFUR_GLOW, NEON, CFrame.new(0, ringY, 0))
		end
		for side = -1, 1, 2 do
			shard(
				handle,
				0.3,
				0.1,
				CFrame.new(side * 0.17, bottom + 0.15, 0) * CFrame.Angles(0, 0, side * -math.rad(110))
			)
			shard(handle, 0.36, 0.1, CFrame.new(0, top - 0.45, side * 0.2) * CFrame.Angles(side * math.rad(70), 0, 0))
		end
		local sap = handle.Parent and handle.Parent:FindFirstChild("Sap")
		if sap and sap:IsA("BasePart") then
			smoke(sap, 3, Color3.fromRGB(215, 200, 110))
		end
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

-- ===================================== Míticos: dioses de la selva =====================================
-- Aspectos de arma míticos (Data/Cosmetics "WeaponSkin", rareza "Mythic"): sustituyen al arma de su
-- rol en cada nivel con la misma empuñadura y el mismo largo que el arma de ese nivel, y ganan piezas
-- con él. Piedra tallada, oro y jade; lo que brilla es oro de sol (el verde que brilla es de las
-- curaciones).

local TITAN_STONE = Color3.fromRGB(132, 138, 122)
local TITAN_STONE_DARK = Color3.fromRGB(92, 98, 88)
local TITAN_GOLD = Color3.fromRGB(232, 182, 64)
local SUN_GLOW = Color3.fromRGB(255, 214, 110)
local JADE = Color3.fromRGB(44, 158, 126)
local JADE_LIGHT = Color3.fromRGB(110, 214, 176)

-- Cristal de jade de "length" desde "at" (su base) hacia su +Y: funda translúcida y núcleo de jade.
local function jadeCrystal(handle: BasePart, length: number, width: number, at: CFrame)
	tooth(handle, "Jade", length, width, width, JADE_LIGHT, GLASS, at * CFrame.new(0, length / 2, 0))
	tooth(
		handle,
		"JadeCore",
		length * 0.7,
		width * 0.5,
		width * 0.5,
		JADE,
		SMOOTH,
		at * CFrame.new(0, length * 0.35, 0)
	)
end

-- Maza del Rey Gorila (guerrero): mango de piedra con anillos de oro y, de cabeza, un puño de gorila de
-- piedra con los nudillos hacia donde golpea (-Z), el pulgar cruzado y un puño de oro en la muñeca.
-- Nivel 1 (como el garrote de piedra): un anillo de oro. Nivel 2 (maza de hueso): dos anillos, bandas
-- de oro en el mango y un pomo de jade. Nivel 3 (mazo de hueso grueso, más largo y cogido por el centro):
-- más grande, con nudilleras de oro en punta, un óvalo de jade en el dorso y borlas de pelaje de gorila
-- en la muñeca. Nivel 4 (mazo volcánico): un aro de sol alrededor de la muñeca con rayos que brillan,
-- vetas de oro encendidas en los dedos, cristales de jade saliendo del dorso, luz y motas de sol.
local function buildTitanKingMace(tool: Tool, level: number): BasePart
	local long = level >= 3
	-- Mismo agarre y alto de la cabeza que el arma del nivel (garrote y maza; mazos de nivel 3 y 4).
	local handle = hiddenHandle(tool, if long then Vector3.new(0.5, 1.7, 0.5) else Vector3.new(0.4, 2.6, 0.4))
	local scale = ({ 1.05, 1.18, 1.4, 1.55 })[level] or 1
	local headY = if long then 3.25 else 2.35
	local shaftTop = headY - 0.5 * scale
	local shaftBottom = if long then -1 else -1.3
	rod(
		handle,
		"Shaft",
		shaftTop - shaftBottom,
		if long then 0.44 else 0.36,
		TITAN_STONE_DARK,
		STONE_MATERIAL,
		CFrame.new(0, (shaftTop + shaftBottom) / 2, 0)
	)
	rod(
		handle,
		"Wrap",
		if long then 1.5 else 0.9,
		if long then 0.52 else 0.42,
		Color3.fromRGB(120, 34, 34),
		FABRIC,
		CFrame.new(0, if long then 0 else -0.7, 0)
	)
	if level >= 2 then
		for _, y in { shaftTop - 0.35, if long then 0.9 else -0.15 } do
			rod(handle, "Band", 0.1, if long then 0.54 else 0.46, TITAN_GOLD, SMOOTH, CFrame.new(0, y, 0))
		end
		ball(handle, "Pommel", if long then 0.62 else 0.5, JADE, SMOOTH, CFrame.new(0, shaftBottom - 0.12, 0))
		rod(
			handle,
			"PommelCup",
			0.1,
			if long then 0.56 else 0.46,
			TITAN_GOLD,
			SMOOTH,
			CFrame.new(0, shaftBottom + 0.05, 0)
		)
	else
		rod(handle, "Butt", 0.2, 0.44, TITAN_STONE, STONE_MATERIAL, CFrame.new(0, shaftBottom, 0))
	end

	-- El puño: palma, cuatro dedos doblados con sus nudillos delante y el pulgar cruzado por debajo.
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * scale, headY + y * scale, z * scale)
	end
	block(handle, "Palm", Vector3.new(1, 0.95, 0.8) * scale, TITAN_STONE, STONE_MATERIAL, at(0, 0, 0.05))
	block(handle, "Wrist", Vector3.new(0.8, 0.3, 0.7) * scale, TITAN_STONE_DARK, STONE_MATERIAL, at(0, -0.55, 0.05))
	rod(handle, "Cuff", 0.26 * scale, 0.98 * scale, TITAN_GOLD, SMOOTH, at(0, -0.5, 0.05))
	for finger = 1, 4 do
		local x = -0.375 + (finger - 1) * 0.25
		block(handle, "Finger", Vector3.new(0.23, 0.32, 0.44) * scale, TITAN_STONE, STONE_MATERIAL, at(x, 0.28, -0.42))
		block(
			handle,
			"Finger",
			Vector3.new(0.23, 0.52, 0.26) * scale,
			TITAN_STONE_DARK,
			STONE_MATERIAL,
			at(x, -0.06, -0.58)
		)
		ball(handle, "Knuckle", 0.27 * scale, TITAN_STONE, STONE_MATERIAL, at(x, 0.27, -0.62))
		if finger == 2 or (level >= 2 and finger == 3) then
			rod(handle, "Ring", 0.12 * scale, 0.3 * scale, TITAN_GOLD, SMOOTH, at(x, 0.28, -0.4) * TO_Z)
		end
		if level >= 3 then
			tooth(
				handle,
				"Spike",
				0.3 * scale,
				0.14 * scale,
				0.14 * scale,
				TITAN_GOLD,
				SMOOTH,
				at(x, 0.27, -0.8) * CFrame.Angles(-math.pi / 2, 0, 0)
			)
		end
		if level >= 4 then
			local vein =
				block(handle, "Vein", Vector3.new(0.035, 0.36, 0.04) * scale, SUN_GLOW, NEON, at(x, -0.06, -0.72))
			if finger == 1 then
				glow(vein, SUN_GLOW, 8)
			end
		end
	end
	block(
		handle,
		"Thumb",
		Vector3.new(0.3, 0.28, 0.62) * scale,
		TITAN_STONE,
		STONE_MATERIAL,
		at(-0.56, -0.2, -0.28) * CFrame.Angles(0, 0.25, 0)
	)
	ball(handle, "ThumbTip", 0.28 * scale, TITAN_STONE_DARK, STONE_MATERIAL, at(-0.4, -0.22, -0.58))

	if level >= 3 then
		block(handle, "InlayRim", Vector3.new(0.58, 0.5, 0.1) * scale, TITAN_GOLD, SMOOTH, at(0, 0.05, 0.47))
		block(handle, "Inlay", Vector3.new(0.46, 0.38, 0.12) * scale, JADE, SMOOTH, at(0, 0.05, 0.49))
		-- Cuentas de jade engastadas alrededor del puño de oro de la muñeca.
		for index = 0, 5 do
			local angle = index * math.pi / 3
			ball(
				handle,
				"Bead",
				0.17 * scale,
				JADE,
				SMOOTH,
				at(0, -0.5, 0.05) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -0.5)
			)
		end
	end

	if level >= 4 then
		-- Aro de sol de pie detrás del puño (como el halo del traje): diez tramos de oro con rayos de oro
		-- y rayos de sol que brillan, alternos.
		local center = at(0, 0, 0.56)
		local radius = 0.82 * scale
		for index = 0, 9 do
			local angle = index * math.pi / 5
			block(
				handle,
				"SunRing",
				Vector3.new(2 * radius * math.sin(math.pi / 10) + 0.04, 0.1, 0.1),
				TITAN_GOLD,
				SMOOTH,
				center * CFrame.Angles(0, 0, angle + math.pi / 10) * CFrame.new(0, radius * math.cos(math.pi / 10), 0)
			)
			local ray = center * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius + 0.2, 0)
			if index % 2 == 0 then
				tooth(handle, "SunRay", 0.4, 0.14, 0.08, TITAN_GOLD, SMOOTH, ray)
			else
				tooth(handle, "SunRay", 0.32, 0.1, 0.06, SUN_GLOW, NEON, ray)
			end
		end
		-- Cristales de jade que salen del dorso del puño, hacia atrás y arriba.
		for index, x in { -0.28, 0, 0.28 } do
			jadeCrystal(
				handle,
				if index == 2 then 0.7 else 0.5,
				0.2,
				at(x, 0.3, 0.3) * CFrame.Angles(math.rad(35), 0, -x)
			)
		end
		local crown = block(handle, "Crown", Vector3.new(0.6, 0.08, 0.5) * scale, TITAN_GOLD, SMOOTH, at(0, 0.5, 0.05))
		local motes = Instance.new("ParticleEmitter")
		motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		motes.Color = ColorSequence.new(SUN_GLOW, TITAN_GOLD)
		motes.LightEmission = 1
		motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
		motes.Transparency = NumberSequence.new(0.15, 1)
		motes.Lifetime = NumberRange.new(0.8, 1.4)
		motes.Rate = 6
		motes.Speed = NumberRange.new(0.4, 1)
		motes.SpreadAngle = Vector2.new(60, 60)
		motes.Parent = crown
	end

	tool.Grip = CFrame.new(0, if long then -0.2 else -0.7, 0)
	return handle
end

-- Cazador, Jaguar Espectral: pelaje de jaguar con rosetas, piedra de noche, oro y jade; lo que brilla es
-- la luz del espíritu del jaguar, blanca azulada.
local JAGUAR = Color3.fromRGB(214, 150, 62)
local JAGUAR_CREAM = Color3.fromRGB(242, 222, 178)
local JAGUAR_MOUTH = Color3.fromRGB(96, 30, 32)
local ROSETTE = Color3.fromRGB(36, 28, 24)
local NIGHT_STONE = Color3.fromRGB(46, 48, 62)
local SPECTRAL = Color3.fromRGB(190, 240, 255)
local SPECTRAL_BODY = Color3.fromRGB(140, 200, 250)

-- Óvalo (bola estirada) de "size".
local function oval(
	handle: BasePart,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	at: CFrame
): BasePart
	local piece = newPiece(name, size, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = piece
	attach(handle, piece, at)
	return piece
end

-- Cabeza de jaguar rugiendo de "size" de ancho, mirando a la -Z de "at": cráneo ancho con manchas,
-- mejillas, orejas en punta, ojos almendrados de "eye" con cejas de furia, hocico claro, nariz y boca
-- abierta con colmillos de oro. Devuelve un ojo.
local function jaguarMask(handle: BasePart, at: CFrame, size: number, eye: Color3, eyeMaterial: Enum.Material): BasePart
	local function on(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x * size, y * size, z * size)
	end
	oval(handle, "Mask", Vector3.new(1, 0.7, 0.6) * size, JAGUAR, FABRIC, on(0, 0.05, 0.1))
	oval(handle, "Mask", Vector3.new(0.36, 0.16, 0.16) * size, JAGUAR_MOUTH, SMOOTH, on(0, -0.33, -0.2))
	oval(handle, "Mask", Vector3.new(0.2, 0.11, 0.1) * size, ROSETTE, SMOOTH, on(0, -0.1, -0.34))
	ball(handle, "Spot", 0.08 * size, ROSETTE, SMOOTH, on(0, 0.34, -0.1))
	local eyePiece: BasePart
	for side = -1, 1, 2 do
		oval(handle, "Mask", Vector3.new(0.5, 0.42, 0.44) * size, JAGUAR, FABRIC, on(side * 0.28, -0.14, -0.02))
		oval(handle, "Mask", Vector3.new(0.26, 0.22, 0.24) * size, JAGUAR_CREAM, FABRIC, on(side * 0.11, -0.2, -0.22))
		tooth(
			handle,
			"Ear",
			0.26 * size,
			0.06 * size,
			0.22 * size,
			JAGUAR,
			FABRIC,
			on(side * 0.36, 0.42, 0.08) * CFrame.Angles(0, 0, -side * 0.35) * CFrame.Angles(0, math.pi / 2, 0)
		)
		eyePiece = oval(
			handle,
			"Eye",
			Vector3.new(0.22, 0.1, 0.08) * size,
			eye,
			eyeMaterial,
			on(side * 0.2, 0.05, -0.26) * CFrame.Angles(0, 0, side * 0.35)
		)
		block(
			handle,
			"Brow",
			Vector3.new(0.26, 0.04, 0.04) * size,
			ROSETTE,
			SMOOTH,
			on(side * 0.2, 0.15, -0.28) * CFrame.Angles(0, 0, side * 0.45)
		)
		tooth(
			handle,
			"Fang",
			0.2 * size,
			0.06 * size,
			0.07 * size,
			TITAN_GOLD,
			SMOOTH,
			on(side * 0.13, -0.32, -0.26) * CFrame.Angles(math.pi, 0, 0)
		)
		ball(handle, "Spot", 0.07 * size, ROSETTE, SMOOTH, on(side * 0.17, 0.3, -0.12))
		ball(handle, "Spot", 0.07 * size, ROSETTE, SMOOTH, on(side * 0.38, -0.08, -0.16))
	end
	return eyePiece
end

-- Arco del Jaguar Espectral (cazador): el arco recurvo de cada nivel, del mismo tamaño, con las palas de
-- madera dorada con manchas de jaguar, la empuñadura de pelaje sobre un cuerpo de piedra de noche con
-- bandas de oro, puntas de garra de oro y la cuerda clara. Nivel 1: un disco de jade en el cuerpo y plumas
-- negras y doradas. Nivel 2: anillos de oro y cuentas de jade en las palas, un colmillo con las plumas.
-- Nivel 3: la cabeza de un jaguar rugiendo encima de la mano, con ojos de jade, y placas de piedra de
-- noche remachadas de oro en las palas. Nivel 4: el espíritu del jaguar: la cuerda, las manchas y los
-- ojos brillan en luz blanca azulada, zarpazos de luz en las palas, garras fantasma en las puntas, una
-- luna creciente detrás de la cabeza y chispas de luz.
local function buildSpectralJaguarBow(tool: Tool, level: number): BasePart
	local size = ({ 1.25, 1.38, 1.5, 1.6 })[level] or 1.25
	local lit = level >= 4
	local handle = hiddenHandle(tool, Vector3.new(0.3, 0.9, 0.35))
	block(handle, "Riser", Vector3.new(0.34, 1.2, 0.44), NIGHT_STONE, STONE_MATERIAL, CFrame.new())
	block(handle, "Grip", Vector3.new(0.38, 0.6, 0.48), JAGUAR, FABRIC, CFrame.new())
	for _, y in { 0.33, -0.33 } do
		rod(handle, "Band", 0.07, 0.52, TITAN_GOLD, SMOOTH, CFrame.new(0, y, 0))
	end
	for _, spot in { Vector3.new(0.2, 0.12, -0.1), Vector3.new(-0.2, -0.1, 0.08), Vector3.new(0.05, -0.15, -0.25) } do
		ball(handle, "Spot", 0.12, ROSETTE, SMOOTH, CFrame.new(spot))
	end
	block(handle, "ArrowRest", Vector3.new(0.12, 0.1, 0.22), TITAN_GOLD, SMOOTH, CFrame.new(0.2, 0.36, 0.04))

	-- Banda alrededor de la pala en "point".
	local function band(point: Vector3, direction: Vector3, length: number, color: Color3, material: Enum.Material)
		local half = direction.Unit * length / 2
		strut(handle, "Band", point - half, point + half, 0.36, 0.29, color, material, Vector3.xAxis)
	end

	local tipY, tipZ = 0, 0
	local out = Vector3.new(0, 0, -0.14)
	for side = -1, 1, 2 do
		local start = Vector3.new(0, side * 0.6, 0)
		local middle = Vector3.new(0, side * 1.35 * size, 0.12 * size)
		local tip = Vector3.new(0, side * 2.05 * size, 0.5 * size)
		local curl = tip + Vector3.new(0, side * 0.3 * size, -0.12 * size)
		strut(handle, "Limb", start, middle, 0.3, 0.24, JAGUAR, WOOD_MATERIAL, Vector3.xAxis)
		strut(handle, "Limb", middle, tip, 0.25, 0.21, JAGUAR, WOOD_MATERIAL, Vector3.xAxis)
		strut(handle, "Limb", tip, curl, 0.2, 0.18, NIGHT_STONE, STONE_MATERIAL, Vector3.xAxis)
		band(start, middle - start, 0.12, TITAN_GOLD, SMOOTH)
		-- Manchas en la cara de fuera y en los costados de las palas (brillan en el nivel 4).
		for index, point in { start:Lerp(middle, 0.3), start:Lerp(middle, 0.72), middle:Lerp(tip, 0.45) } do
			for _, offset in
				{ out * 0.8, Vector3.new(0.13, 0, (index % 2) * 0.06), Vector3.new(-0.13, 0, -(index % 2) * 0.06) }
			do
				ball(
					handle,
					"Spot",
					if offset.X == 0 then 0.13 else 0.1,
					if lit then SPECTRAL else ROSETTE,
					if lit then NEON else SMOOTH,
					CFrame.new(point + offset)
				)
			end
		end
		-- Punta: garra de oro que sigue la curva.
		local reach = (curl - tip).Unit
		ball(handle, "Nock", 0.22, TITAN_GOLD, SMOOTH, CFrame.new(curl))
		tooth(
			handle,
			"Claw",
			0.42,
			0.14,
			0.2,
			TITAN_GOLD,
			SMOOTH,
			CFrame.lookAt(curl, curl + reach) * CFrame.Angles(-math.rad(90), 0, 0) * CFrame.new(0, 0.2, 0)
		)
		if level >= 2 then
			band(middle, middle - start, 0.1, TITAN_GOLD, SMOOTH)
			ball(handle, "Jade", 0.16, JADE, SMOOTH, CFrame.new(middle + out * 1.1))
		end
		if level >= 3 then
			local plateFrom, plateTo = start:Lerp(middle, 0.12) + out, start:Lerp(middle, 0.88) + out
			strut(handle, "Plate", plateFrom, plateTo, 0.1, 0.27, NIGHT_STONE, STONE_MATERIAL, Vector3.xAxis)
			for _, t in { 0.25, 0.75 } do
				ball(
					handle,
					"Rivet",
					0.09,
					TITAN_GOLD,
					SMOOTH,
					CFrame.new(plateFrom:Lerp(plateTo, t) + Vector3.new(0, 0, -0.06))
				)
			end
		end
		if lit then
			-- Zarpazos de luz por la cara de fuera y una garra fantasma más larga en la punta.
			for _, x in { -0.06, 0.06 } do
				strut(
					handle,
					"Scratch",
					middle:Lerp(tip, 0.15) + out + Vector3.new(x, 0, -0.01),
					middle:Lerp(tip, 0.75) + out + Vector3.new(x, 0, -0.01),
					0.04,
					0.03,
					SPECTRAL,
					NEON,
					Vector3.xAxis
				)
			end
			local ghost = newPiece("Ghost", Vector3.new(0.2, 0.75, 0.15), SPECTRAL_BODY, GLASS, "WedgePart")
			ghost.Transparency = 0.4
			attach(
				handle,
				ghost,
				CFrame.lookAt(curl, curl + reach) * CFrame.Angles(-math.rad(90), 0, 0) * CFrame.new(0, 0.45, 0)
			)
		end
		tipY, tipZ = tip.Y, tip.Z
	end
	local bowString = block(
		handle,
		"String",
		Vector3.new(0.05, tipY * 2, 0.05),
		if lit then SPECTRAL else JAGUAR_CREAM,
		if lit then NEON else FABRIC,
		CFrame.new(0, 0, tipZ)
	)

	-- Delante, por encima de la mano: el disco de jade (niveles 1 y 2) o la cabeza del jaguar (3 y 4).
	local face = CFrame.new(0, 0.5, -0.26)
	if level >= 3 then
		local eye = jaguarMask(
			handle,
			face * CFrame.new(0, 0.06, -0.04),
			0.5,
			if lit then SPECTRAL else JADE,
			if lit then NEON else SMOOTH
		)
		if lit then
			glow(eye, SPECTRAL, 8)
			-- Luna creciente de plata detrás de la cabeza, con el filo de dentro de luz.
			local count = 10
			local step = math.rad(220) / count
			local radius = 0.62
			for index = 0, count - 1 do
				local angle = math.rad(-110) + (index + 0.5) * step
				local piece = face * CFrame.new(0, 0.06, 0.06) * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius, 0)
				local length = 2 * radius * math.sin(step / 2) + 0.03
				local thick = 0.12 - math.abs(index - (count - 1) / 2) * 0.02
				block(
					handle,
					"Moon",
					Vector3.new(length, thick, 0.06),
					SILVER,
					SMOOTH,
					piece * CFrame.new(0, thick / 2, 0)
				)
				block(handle, "Moon", Vector3.new(length, 0.03, 0.07), SPECTRAL, NEON, piece)
			end
			glow(bowString, SPECTRAL, 6)
		end
	else
		rod(handle, "Medallion", 0.06, 0.34, TITAN_GOLD, SMOOTH, face * TO_Z)
		rod(handle, "Medallion", 0.06, 0.26, JADE, SMOOTH, face * CFrame.new(0, 0, -0.03) * TO_Z)
	end

	-- Cordón con plumas negras y doradas (y un colmillo desde el nivel 2) a un lado de la empuñadura.
	local charmX = 0.22
	block(handle, "Cord", Vector3.new(0.03, 0.5, 0.03), FIBER, FABRIC, CFrame.new(charmX, -0.55, 0))
	local feathers = { ROSETTE, TITAN_GOLD, ROSETTE }
	for index, color in feathers do
		local offset = index - (#feathers + 1) / 2
		block(
			handle,
			"Feather",
			Vector3.new(0.04, 0.5, 0.14),
			color,
			SMOOTH,
			CFrame.new(charmX, -0.98, offset * 0.09) * CFrame.Angles(offset * 0.3, 0, 0)
		)
	end
	if level >= 2 then
		tooth(
			handle,
			"Charm",
			0.3,
			0.08,
			0.14,
			JAGUAR_CREAM,
			SMOOTH,
			CFrame.new(charmX + 0.04, -0.9, 0) * CFrame.Angles(math.pi, 0, 0)
		)
	end
	tool.Grip = CFrame.new()
	return handle
end

-- Mago, Serpiente Emplumada: escamas turquesa con anillos de oro, plumas de quetzal verdes con la punta
-- turquesa, rojo de quetzal, oro y jade; lo que brilla es el azul de las runas del mago.
local SCALE = Color3.fromRGB(48, 178, 168)
local SCALE_DARK = Color3.fromRGB(28, 116, 118)
local QUETZAL = Color3.fromRGB(40, 160, 74)
local QUETZAL_RED = Color3.fromRGB(196, 38, 48)
local SERPENT_MOUTH = Color3.fromRGB(110, 26, 40)
local SERPENT_EYE = Color3.fromRGB(16, 26, 34)
local RUNE = Color3.fromRGB(95, 215, 255)

-- Pluma de quetzal de "length" en el plano XY de "at" con la punta hacia su +Y: verde, con la punta
-- turquesa (de runa que brilla con "lit") y el cañón de oro.
local function quetzalFeather(handle: BasePart, length: number, at: CFrame, lit: boolean)
	oval(handle, "Feather", Vector3.new(length * 0.36, length, 0.04), QUETZAL, SMOOTH, at)
	oval(
		handle,
		"FeatherTip",
		Vector3.new(length * 0.26, length * 0.3, 0.06),
		if lit then RUNE else SCALE,
		if lit then NEON else SMOOTH,
		at * CFrame.new(0, length * 0.36, 0)
	)
	block(
		handle,
		"Quill",
		Vector3.new(0.02, length * 0.7, 0.06),
		TITAN_GOLD,
		SMOOTH,
		at * CFrame.new(0, -length * 0.1, 0)
	)
end

-- Báculo de la Serpiente Emplumada (mago): asta de madera oscura con la empuñadura roja y, arriba, la
-- cabeza de la serpiente mirando al cielo con las fauces abiertas y el cristal entre ellas (la pieza
-- "Crystal", la que destella al lanzar), con su cresta de plumas de quetzal. Nivel 1: dos plumas de
-- cresta y dos colgando. Nivel 2: el cuerpo de la serpiente sube enroscado por la mitad de arriba del
-- asta, bandas de oro, cuentas de jade y pomo de oro. Nivel 3: el cuerpo empieza sobre la mano, cresta
-- de cinco plumas, collar de oro con jade y plumas rojas de quetzal colgando. Nivel 4: cresta de siete
-- plumas con las puntas de runa, ojos de runa, alas de plumas abiertas bajo la cabeza, un anillo de runas
-- que flota alrededor del cristal y chispas.
local function buildFeatheredSerpentStaff(tool: Tool, level: number): BasePart
	local top = STAFF_LENGTH / 2
	local lit = level >= 4
	local handle = hiddenHandle(tool, Vector3.new(0.3, STAFF_LENGTH, 0.3))
	rod(handle, "Shaft", STAFF_LENGTH, 0.3, DARK_BARK, WOOD_MATERIAL, CFrame.new())
	rod(handle, "Wrap", 0.8, 0.36, QUETZAL_RED, FABRIC, CFrame.new(0, -0.6, 0))
	rod(handle, "Collar", 0.22, 0.4, TITAN_GOLD, SMOOTH, CFrame.new(0, top, 0))
	ball(
		handle,
		"Butt",
		0.36,
		if level >= 2 then TITAN_GOLD else DARK_BARK,
		if level >= 2 then SMOOTH else WOOD_MATERIAL,
		CFrame.new(0, -top, 0)
	)
	if level >= 2 then
		for _, y in { -1.4, -0.15, -1.05 } do
			rod(handle, "Band", 0.08, 0.36, TITAN_GOLD, SMOOTH, CFrame.new(0, y, 0))
		end
		for _, y in { -1.25, -1.55 } do
			rod(handle, "Bead", 0.12, 0.38, JADE, SMOOTH, CFrame.new(0, y, 0))
		end
	end

	-- El cuerpo enroscado al asta, de la cola (abajo) al cuello: tramos de escamas con anillos de oro.
	if level >= 2 then
		local from = if level >= 3 then 0 else 0.9
		local count = if level >= 3 then 12 else 7
		local previous: Vector3? = nil
		for index = 0, count do
			local angle = index * 1.05
			local point = Vector3.new(math.cos(angle) * 0.2, from + (top - from) * index / count, math.sin(angle) * 0.2)
			if previous then
				local thick = 0.16 + 0.08 * index / count
				local length = (point - previous).Magnitude
				local segment = CFrame.lookAt((point + previous) / 2, point)
				oval(handle, "Coil", Vector3.new(thick, thick, length + thick * 0.6), SCALE, SMOOTH, segment)
				if index % 2 == 0 then
					oval(
						handle,
						"Belly",
						Vector3.new(thick * 1.1, thick * 1.1, thick * 0.3),
						TITAN_GOLD,
						SMOOTH,
						segment * CFrame.new(0, 0, length / 2)
					)
				end
			end
			previous = point
		end
	end

	-- La cabeza mirando arriba y adelante, con las fauces abiertas alrededor del cristal.
	local size = ({ 1.1, 1.2, 1.3, 1.4 })[level] or 1.1
	local head = CFrame.new(0, top + 0.42, 0.08) * CFrame.Angles(1, 0, 0)
	local function on(x: number, y: number, z: number): CFrame
		return head * CFrame.new(x * size, y * size, z * size)
	end
	local neckFrom, neckTo = Vector3.new(0, top + 0.05, 0), (head * CFrame.new(0, 0, 0.2 * size)).Position
	oval(
		handle,
		"Neck",
		Vector3.new(0.3, 0.3, (neckTo - neckFrom).Magnitude + 0.2),
		SCALE,
		SMOOTH,
		CFrame.lookAt((neckFrom + neckTo) / 2, neckTo)
	)
	oval(handle, "Head", Vector3.new(0.5, 0.36, 0.62) * size, SCALE, SMOOTH, on(0, 0.04, 0.04))
	oval(
		handle,
		"Jaw",
		Vector3.new(0.42, 0.14, 0.46) * size,
		SCALE,
		SMOOTH,
		on(0, 0.08, -0.3) * CFrame.Angles(0.45, 0, 0)
	)
	oval(
		handle,
		"Jaw",
		Vector3.new(0.36, 0.12, 0.44) * size,
		SCALE_DARK,
		SMOOTH,
		on(0, -0.18, -0.24) * CFrame.Angles(-0.55, 0, 0)
	)
	oval(handle, "Mouth", Vector3.new(0.32, 0.14, 0.36) * size, SERPENT_MOUTH, SMOOTH, on(0, -0.06, -0.28))
	block(handle, "Band", Vector3.new(0.36, 0.04, 0.06) * size, TITAN_GOLD, SMOOTH, on(0, 0.22, 0.14))
	for side = -1, 1, 2 do
		-- Ojo oscuro con la pupila rasgada (de runa en el nivel 4).
		ball(handle, "Eye", 0.11 * size, SERPENT_EYE, SMOOTH, on(side * 0.21, 0.12, -0.08))
		local eye = block(
			handle,
			"Pupil",
			Vector3.new(0.025, 0.09, 0.035) * size,
			if lit then RUNE else JADE,
			if lit then NEON else SMOOTH,
			on(side * 0.265, 0.12, -0.09)
		)
		if lit and side == 1 then
			glow(eye, RUNE, 6)
		end
		oval(
			handle,
			"Brow",
			Vector3.new(0.16, 0.06, 0.22) * size,
			TITAN_GOLD,
			SMOOTH,
			on(side * 0.18, 0.2, -0.08) * CFrame.Angles(0, 0, side * 0.3)
		)
		tooth(
			handle,
			"Fang",
			0.16 * size,
			0.04 * size,
			0.05 * size,
			TITAN_GOLD,
			SMOOTH,
			on(side * 0.12, -0.04, -0.46) * CFrame.Angles(math.pi, 0, 0)
		)
	end
	-- Cresta de plumas que se abre hacia atrás desde la nuca.
	local crest = ({ 2, 3, 5, 7 })[level] or 2
	for index = 1, crest do
		local spread = (index - 1) / math.max(crest - 1, 1) * 1.3 - 0.65
		quetzalFeather(
			handle,
			(if math.abs(spread) < 0.25 then 0.75 else 0.6) * size,
			on(0, 0.18, 0.28) * CFrame.Angles(-0.6, 0, spread) * CFrame.new(0, 0.3 * size, 0),
			lit
		)
	end

	-- El cristal, entre las fauces.
	local crystalSize = ({ 0.55, 0.65, 0.75, 0.85 })[level] or 0.55
	local crystalAt = head * CFrame.new(0, -0.03 * size, -0.42 * size - crystalSize * 0.3)
	local crystal = block(
		handle,
		"Crystal",
		Vector3.one * crystalSize,
		RUNE,
		NEON,
		crystalAt * CFrame.Angles(math.rad(45), 0, math.rad(45))
	)
	crystal.Transparency = 0.1
	glow(crystal, RUNE, 10)

	-- Plumas que cuelgan del collar (rojas de quetzal desde el nivel 3, con un collar de oro y jade).
	local hanging = if level >= 3 then { QUETZAL, QUETZAL_RED, QUETZAL, QUETZAL_RED } else { QUETZAL, QUETZAL }
	for index, color in hanging do
		local angle = (index - 0.5) / #hanging * math.pi * 2
		local at = CFrame.new(0, top - 0.35, 0)
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(0, 0, -0.24)
			* CFrame.Angles(-0.15, 0, math.pi)
		oval(handle, "Feather", Vector3.new(0.14, 0.5, 0.03), color, SMOOTH, at)
	end
	if level >= 3 then
		rod(handle, "Collar", 0.12, 0.46, TITAN_GOLD, SMOOTH, CFrame.new(0, top - 0.12, 0))
		for index = 0, 3 do
			ball(
				handle,
				"Bead",
				0.12,
				JADE,
				SMOOTH,
				CFrame.new(0, top - 0.12, 0) * CFrame.Angles(0, index * math.pi / 2, 0) * CFrame.new(0, 0, -0.24)
			)
		end
	end

	if lit then
		-- Alas de plumas abiertas a los lados del cuello.
		for side = -1, 1, 2 do
			for index = 0, 2 do
				quetzalFeather(
					handle,
					0.8 - index * 0.12,
					CFrame.new(side * 0.2, top + 0.05, 0.05)
						* CFrame.Angles(0, 0, -side * (0.7 + index * 0.35))
						* CFrame.new(0, 0.4 - index * 0.06, 0),
					true
				)
			end
		end
		-- Anillo de runas que flota inclinado alrededor del cristal.
		local center = crystalAt
		local ringCount = 10
		for index = 0, ringCount - 1 do
			block(
				handle,
				"RuneRing",
				Vector3.new(0.34, 0.05, 0.05),
				RUNE,
				NEON,
				center
					* CFrame.Angles(0.4, 0, 0.3)
					* CFrame.Angles(0, index * math.pi * 2 / ringCount, 0)
					* CFrame.new(0, 0, -0.62)
			)
		end
	end
	tool.Grip = CFrame.new(0, -0.6, 0)
	return handle
end

-- Médico, Ceiba de la Vida: corteza gris verdosa de ceiba con espinas cónicas, hojas, flores rosas, el
-- algodón de sus frutos, oro y jade; lo que brilla es el verde de las curaciones.
local CEIBA_BARK = Color3.fromRGB(140, 150, 122)
local CEIBA_BARK_DARK = Color3.fromRGB(100, 108, 88)
local CEIBA_THORN = Color3.fromRGB(204, 190, 150)
local KAPOK = Color3.fromRGB(246, 244, 236)
local KAPOK_POD = Color3.fromRGB(112, 120, 70)
local CEIBA_BLOSSOM = Color3.fromRGB(238, 140, 176)
local HEAL_GLOW = Color3.fromRGB(120, 255, 150)

-- Cerbatana de la Ceiba (médico): la caña de cada nivel, del mismo largo, es una rama de ceiba con nudos
-- y espinas cónicas, la empuñadura envuelta en liana y, en la boca, un aro de hojas; los dardos llevan
-- algodón de ceiba y salen de un fruto atado a un lado. Nivel 1: tres espinas. Nivel 2: cinco espinas,
-- una ramita con hojas que brota de la caña, anillos de oro, cuentas de jade y una flor en la boca.
-- Nivel 3: siete espinas, dos ramitas, la boquilla es una raíz de contrafuerte, más hojas y un fruto
-- abierto colgando (nivel 4: tres ramitas). Nivel 4: nueve espinas, vetas de savia verde
-- que brillan por la caña, un anillo de savia en la boca, el algodón que brilla y chispas de curación.
local function buildCeibaBlowgun(tool: Tool, level: number): BasePart
	local length = ({ 3.6, 3.9, 4.2, 4.5 })[level] or 3.6
	local lit = level >= 4
	local bottom = -1.4
	local top = bottom + length
	local handle = hiddenHandle(tool, Vector3.new(0.3, 1.4, 0.3))
	rod(handle, "Tube", length, 0.28, CEIBA_BARK, WOOD_MATERIAL, CFrame.new(0, (bottom + top) / 2, 0))
	rod(handle, "Grip", 0.8, 0.33, LEATHER, FABRIC, CFrame.new(0, -0.8, 0))
	wraps(handle, Vector3.new(0, -1.2, 0), Vector3.new(0, -0.4, 0), 3, 0.36, LIANA_GREEN, Vector3.zAxis)

	-- Nudos de la rama (bultos de corteza a un lado y a otro: en anillo parecía bambú) y espinas cónicas
	-- en espiral, sin tocar la empuñadura.
	local y = bottom + 0.9
	local knot = 0
	while y < top - 0.3 do
		if math.abs(y + 0.8) > 0.5 then
			knot += 1
			oval(
				handle,
				"Knot",
				Vector3.new(0.2, 0.34, 0.2),
				CEIBA_BARK_DARK,
				WOOD_MATERIAL,
				CFrame.new(0, y, 0) * CFrame.Angles(0, knot * 2.5, 0) * CFrame.new(0, 0, -0.1)
			)
		end
		y += 0.7
	end
	local thorns = 1 + level * 2
	for index = 1, thorns do
		local thornY = -0.2 + (top - 0.6 - -0.2) * (index - 0.5) / thorns
		tooth(
			handle,
			"Thorn",
			0.32,
			0.13,
			0.18,
			CEIBA_THORN,
			SMOOTH,
			CFrame.new(0, thornY, 0)
				* CFrame.Angles(0, index * 2.4, 0)
				* CFrame.new(0, 0, -0.2)
				* CFrame.Angles(-math.pi / 2, 0, 0)
		)
	end

	-- Ramitas con tres hojas que brotan de la caña (una por nivel desde el 2), hacia arriba y afuera.
	for index = 1, level - 1 do
		local twig = CFrame.new(0, 0.3 + index * (top - 1) / level, 0)
			* CFrame.Angles(0, index * 2.1 + 0.5, 0)
			* CFrame.new(0, 0, -0.14)
			* CFrame.Angles(-0.7, 0, 0)
		rod(handle, "Twig", 0.5, 0.08, CEIBA_BARK_DARK, WOOD_MATERIAL, twig * CFrame.new(0, 0.25, 0))
		for leafIndex = -1, 1 do
			oval(
				handle,
				"Leaf",
				Vector3.new(0.16, 0.38, 0.03),
				if leafIndex == 0 then LEAF_GREEN else LIANA_GREEN,
				SMOOTH,
				twig * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, leafIndex * 0.7) * CFrame.new(0, 0.17, 0)
			)
		end
	end

	-- Boquilla: de madera oscura o, desde el nivel 3, una raíz de contrafuerte abierta en cuatro.
	rod(handle, "Mouthpiece", 0.3, 0.3, CEIBA_BARK_DARK, WOOD_MATERIAL, CFrame.new(0, bottom + 0.1, 0))
	if level >= 3 then
		for index = 0, 3 do
			tooth(
				handle,
				"Root",
				0.36,
				0.08,
				0.2,
				CEIBA_BARK_DARK,
				WOOD_MATERIAL,
				CFrame.new(0, bottom + 0.28, 0)
					* CFrame.Angles(0, index * math.pi / 2, 0)
					* CFrame.new(0, 0, -0.14)
					* CFrame.Angles(math.pi - 0.35, 0, 0)
			)
		end
	end

	-- Boca: aro de hojas (y una flor desde el nivel 2).
	local mouth = CFrame.new(0, top - 0.1, 0)
	rod(handle, "Muzzle", 0.2, 0.3, CEIBA_BARK_DARK, WOOD_MATERIAL, mouth)
	local leaves = if level >= 3 then 6 else 4
	for index = 0, leaves - 1 do
		oval(
			handle,
			"Leaf",
			Vector3.new(0.2, 0.5, 0.03),
			if index % 2 == 0 then LEAF_GREEN else LIANA_GREEN,
			SMOOTH,
			mouth
				* CFrame.Angles(0, index * math.pi * 2 / leaves, 0)
				* CFrame.new(0, -0.1, -0.18)
				* CFrame.Angles(-0.5, 0, 0)
		)
	end
	if level >= 2 then
		for _, ringY in { top - 0.35, -0.3, bottom + 0.3 } do
			rod(handle, "Band", 0.07, 0.29, TITAN_GOLD, SMOOTH, CFrame.new(0, ringY, 0))
		end
		ball(handle, "Jade", 0.16, JADE, SMOOTH, CFrame.new(0, top - 0.35, -0.15))
		ball(handle, "Jade", 0.16, JADE, SMOOTH, CFrame.new(0, -0.3, -0.15))
		local blossom = CFrame.new(0.16, top - 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0)
		for petal = 0, 4 do
			oval(
				handle,
				"Petal",
				Vector3.new(0.12, 0.2, 0.03),
				CEIBA_BLOSSOM,
				SMOOTH,
				blossom * CFrame.Angles(0, 0, petal * math.pi * 2 / 5) * CFrame.new(0, 0.1, 0)
			)
		end
		ball(handle, "Blossom", 0.08, TITAN_GOLD, SMOOTH, blossom * CFrame.new(0, 0, -0.02))
	end

	-- Fruto de ceiba atado a un lado con tres dardos de algodón asomando (y otro abierto colgando de la
	-- boca desde el nivel 3).
	oval(handle, "Pouch", Vector3.new(0.22, 0.46, 0.22), KAPOK_POD, SMOOTH, CFrame.new(0.21, -0.1, 0))
	for index = -1, 1 do
		local dart = CFrame.new(0.21, 0.2, index * 0.06) * CFrame.Angles(index * 0.15, 0, 0)
		rod(handle, "Dart", 0.4, 0.04, BONE, SMOOTH, dart)
		ball(handle, "Fluff", 0.12, KAPOK, if lit then NEON else FABRIC, dart * CFrame.new(0, 0.22, 0))
	end
	if level >= 3 then
		block(handle, "Cord", Vector3.new(0.03, 0.3, 0.03), FIBER, FABRIC, CFrame.new(-0.17, top - 0.5, 0))
		oval(handle, "Pod", Vector3.new(0.16, 0.34, 0.16), KAPOK_POD, SMOOTH, CFrame.new(-0.17, top - 0.8, 0))
		local fluff =
			ball(handle, "Fluff", 0.2, KAPOK, if lit then NEON else FABRIC, CFrame.new(-0.2, top - 0.86, -0.08))
		if lit then
			glow(fluff, KAPOK, 4)
		end
	end

	if lit then
		-- Vetas de savia verde que suben por la caña y un anillo de savia en la boca.
		for _, side in { -1, 1 } do
			local points = {
				Vector3.new(side * 0.13, -0.3, -0.06),
				Vector3.new(side * 0.15, 0.6, 0.03),
				Vector3.new(side * 0.13, 1.5, -0.05),
				Vector3.new(side * 0.15, top - 0.4, 0.03),
			}
			for index = 1, #points - 1 do
				strut(handle, "Sap", points[index], points[index + 1], 0.05, 0.05, HEAL_GLOW, NEON, Vector3.xAxis)
			end
		end
		local sap = rod(handle, "Sap", 0.1, 0.33, HEAL_GLOW, NEON, CFrame.new(0, top - 0.25, 0))
		glow(sap, HEAL_GLOW, 8)
	end
	tool.Grip = CFrame.new(0, -0.8, 0)
	return handle
end

-- ===================================== Temporada 1: fuego azul y azufre =====================================
-- Aspectos de arma de la Temporada 1, "El Despertar del Volcán" (Data/Seasons): piedra pómez clara,
-- carbón, cristales de azufre y fuego azul, para que no se confundan con las armas de la forja volcánica
-- (obsidiana negra y lava naranja). Mismo agarre y largo que el arma de cada nivel; ganan cristales con él
-- y en el nivel 4 arden en azul.

local PUMICE = Color3.fromRGB(196, 190, 178)
local PUMICE_DARK = Color3.fromRGB(148, 142, 134)
local CHARCOAL = Color3.fromRGB(52, 50, 56)
local BLUE_FIRE = Color3.fromRGB(45, 120, 255)
local BLUE_FIRE_MID = Color3.fromRGB(90, 185, 255)
local BLUE_FIRE_PALE = Color3.fromRGB(190, 235, 255)

-- Llama en píxeles (como las de los trajes de la temporada, Shared/ArmorModels), de arriba abajo: X el
-- fuego azul de fuera, C el celeste y W el corazón casi blanco, que sobresalen más.
local FLAME_ROWS = {
	"..X..",
	".XX.X",
	".XCXX",
	"XCWCX",
	"XCWCX",
	".XXX.",
}
local FLAME_COLORS: { [string]: Color3 } = { X = BLUE_FIRE, C = BLUE_FIRE_MID, W = BLUE_FIRE_PALE }
local FLAME_RELIEF: { [string]: number } = { X = 0.5, C = 0.75, W = 1 }

-- La llama en píxeles con el pie en "at", celdas de "cell" en su plano XY y relieve hacia su -Z. Cada tramo
-- seguido de un color es una pieza. Devuelve una del pie, para echar llamas de ahí.
local function pixelFlame(handle: BasePart, at: CFrame, cell: number): BasePart
	local columns = #FLAME_ROWS[1]
	local foot: BasePart? = nil
	for row, line in FLAME_ROWS do
		local y = (#FLAME_ROWS - row + 0.5) * cell
		local start = 1
		while start <= columns do
			local char = string.sub(line, start, start)
			local stop = start
			while stop < columns and string.sub(line, stop + 1, stop + 1) == char do
				stop += 1
			end
			local color = FLAME_COLORS[char]
			if color then
				local relief = FLAME_RELIEF[char] * cell
				local piece = block(
					handle,
					"Flame",
					Vector3.new((stop - start + 1) * cell, cell, relief),
					color,
					NEON,
					at * CFrame.new(((start + stop) / 2 - (columns + 1) / 2) * cell, y, -relief / 2)
				)
				if row == #FLAME_ROWS and not foot then
					foot = piece
				end
			end
			start = stop + 1
		end
	end
	return foot :: BasePart
end

-- Cristal de azufre de "length" desde "at" (su base) hacia su +Y: funda amarilla translúcida y núcleo
-- que brilla.
local function sulfurCrystal(handle: BasePart, length: number, width: number, at: CFrame)
	for _, half in tooth(handle, "Sulfur", length, width, width, SULFUR, GLASS, at * CFrame.new(0, length / 2, 0)) do
		half.Transparency = 0.25
	end
	tooth(
		handle,
		"SulfurCore",
		length * 0.7,
		width * 0.5,
		width * 0.5,
		SULFUR_GLOW,
		NEON,
		at * CFrame.new(0, length * 0.35, 0)
	)
end

-- "at" que lleva la +Y de "base" hacia "direction" (no vertical del todo).
local function toward(base: CFrame, direction: Vector3): CFrame
	return CFrame.lookAt(base.Position, base.Position + base:VectorToWorldSpace(direction))
		* CFrame.Angles(-math.pi / 2, 0, 0)
end

-- Fuego azul que sale de "part": llamas que suben, con su luz.
local function blueFire(part: BasePart, rate: number, size: number)
	local flames = Instance.new("ParticleEmitter")
	flames.Texture = "rbxasset://textures/particles/fire_main.dds"
	flames.Color = ColorSequence.new(BLUE_FIRE_PALE, BLUE_FIRE)
	flames.LightEmission = 1
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, 0) })
	flames.Transparency = NumberSequence.new(0.3, 1)
	flames.Lifetime = NumberRange.new(0.4, 0.8)
	flames.Rate = rate
	flames.Speed = NumberRange.new(size, size * 2)
	flames.SpreadAngle = Vector2.new(12, 12)
	flames.Rotation = NumberRange.new(0, 360)
	flames.RotSpeed = NumberRange.new(-60, 60)
	flames.Parent = part
	glow(part, BLUE_FIRE, 8)
end

-- Maza de Azufre (guerrero): mango de piedra pómez con venda de carbón y, de cabeza, un mazo de piedra
-- alargado hacia donde golpea (-Z) del que salen cristales de azufre, el más largo por delante. Nivel 1
-- (como el garrote de piedra): tres cristales y una banda de carbón. Nivel 2 (maza de hueso): una jaula de
-- cuatro barras de carbón, cristales a los lados y un pomo de azufre. Nivel 3 (mazo de hueso grueso, más
-- largo y cogido por el centro): más grande, con tapas de carbón por delante y por detrás y siete
-- cristales. Nivel 4 (mazo volcánico): costuras de fuego azul en las barras y, en vez del cristal de
-- arriba, una llamarada azul en píxeles (dos cruzadas, para que se vea de frente y de lado), con su luz.
local function buildSulfurMace(tool: Tool, level: number): BasePart
	local long = level >= 3
	-- Mismo agarre y alto de la cabeza que el arma del nivel (garrote y maza; mazos de nivel 3 y 4).
	local handle = hiddenHandle(tool, if long then Vector3.new(0.5, 1.7, 0.5) else Vector3.new(0.4, 2.6, 0.4))
	local scale = ({ 1, 1.12, 1.32, 1.45 })[level] or 1
	local headY = if long then 3.25 else 2.35
	local shaftTop = headY - 0.4 * scale
	local shaftBottom = if long then -1 else -1.3
	rod(
		handle,
		"Shaft",
		shaftTop - shaftBottom,
		if long then 0.42 else 0.34,
		PUMICE_DARK,
		STONE_MATERIAL,
		CFrame.new(0, (shaftTop + shaftBottom) / 2, 0)
	)
	rod(
		handle,
		"Wrap",
		if long then 1.5 else 0.9,
		if long then 0.5 else 0.4,
		CHARCOAL,
		FABRIC,
		CFrame.new(0, if long then 0 else -0.7, 0)
	)
	if level >= 2 then
		ball(handle, "Pommel", if long then 0.5 else 0.42, SULFUR, SMOOTH, CFrame.new(0, shaftBottom - 0.1, 0))
		rod(
			handle,
			"PommelCup",
			0.1,
			if long then 0.5 else 0.42,
			CHARCOAL,
			SMOOTH,
			CFrame.new(0, shaftBottom + 0.05, 0)
		)
	else
		rod(handle, "Butt", 0.2, 0.42, PUMICE, STONE_MATERIAL, CFrame.new(0, shaftBottom, 0))
	end

	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * scale, headY + y * scale, z * scale)
	end
	-- Medio largo del mazo hacia delante y hacia atrás.
	local reach = 0.6
	block(handle, "Head", Vector3.new(0.8, 0.8, reach * 2) * scale, PUMICE, STONE_MATERIAL, at(0, 0, 0))
	if level >= 2 then
		for x = -1, 1, 2 do
			for z = -1, 1, 2 do
				block(
					handle,
					"Bar",
					Vector3.new(0.14, 0.9, 0.14) * scale,
					CHARCOAL,
					STONE_MATERIAL,
					at(x * 0.41, 0, z * (reach + 0.01))
				)
				if level >= 4 then
					-- Costura de fuego azul por la arista de fuera de cada barra.
					block(
						handle,
						"Seam",
						Vector3.new(0.05, 0.7, 0.05) * scale,
						BLUE_FIRE,
						NEON,
						at(x * 0.47, 0, z * (reach + 0.07))
					)
				end
			end
		end
	else
		block(
			handle,
			"Band",
			Vector3.new(0.86, 0.14, reach * 2 + 0.06) * scale,
			CHARCOAL,
			STONE_MATERIAL,
			at(0, -0.2, 0)
		)
	end
	if level >= 3 then
		for z = -1, 1, 2 do
			block(handle, "Cap", Vector3.new(0.96, 0.96, 0.12) * scale, CHARCOAL, STONE_MATERIAL, at(0, 0, z * reach))
		end
	end

	-- Cristales: base en una cara de la cabeza y dirección (respecto a la cabeza), largo y nivel en que sale
	-- ("upTo": hasta qué nivel; el de arriba deja su sitio a la llamarada).
	local crystals: { { base: Vector3, direction: Vector3, length: number, level: number, upTo: number? } } = {
		{ base = Vector3.new(0, 0, -reach - 0.06), direction = Vector3.new(0, 0.05, -1), length = 0.85, level = 1 },
		{
			base = Vector3.new(0.05, 0.4, -0.1),
			direction = Vector3.new(0.15, 1, -0.25),
			length = 0.62,
			level = 1,
			upTo = 3,
		},
		{ base = Vector3.new(0, 0.05, reach + 0.06), direction = Vector3.new(0, 0.3, 1), length = 0.55, level = 1 },
		{ base = Vector3.new(-0.4, 0.05, -0.2), direction = Vector3.new(-1, 0.35, -0.3), length = 0.5, level = 2 },
		{ base = Vector3.new(0.4, 0.05, -0.2), direction = Vector3.new(1, 0.35, -0.3), length = 0.5, level = 2 },
		{
			base = Vector3.new(-0.22, 0.25, -reach - 0.06),
			direction = Vector3.new(-0.5, 0.6, -1),
			length = 0.5,
			level = 3,
		},
		{
			base = Vector3.new(0.22, 0.25, -reach - 0.06),
			direction = Vector3.new(0.5, 0.6, -1),
			length = 0.5,
			level = 3,
		},
	}
	for _, crystal in crystals do
		if level >= crystal.level and level <= (crystal.upTo or level) then
			sulfurCrystal(
				handle,
				crystal.length * scale,
				0.26 * scale,
				toward(at(crystal.base.X, crystal.base.Y, crystal.base.Z), crystal.direction)
			)
		end
	end

	if level >= 4 then
		local foot = pixelFlame(handle, at(0, 0.4, 0), 0.18 * scale)
		pixelFlame(handle, at(0, 0.4, 0) * CFrame.Angles(0, math.pi / 2, 0), 0.18 * scale)
		blueFire(foot, 14, 0.9 * scale)
	end

	tool.Grip = CFrame.new(0, if long then -0.2 else -0.7, 0)
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
	VolcanicMaul = buildVolcanicMaul,
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
	-- El más largo: palas de obsidiana con grietas de lava, empuñadura de basalto, puntas de esquirla,
	-- cuerda de fuego y plumas de fuego y negras.
	EmberBow = function(tool)
		return buildBow(tool, {
			size = 1.6,
			limb = OBSIDIAN,
			riser = BASALT,
			riserMaterial = BASALT_MATERIAL,
			grip = LEATHER,
			string = EMBER,
			tips = OBSIDIAN,
			paint = {},
			feathers = { MAGMA, FEATHER_BLACK, EMBER, FEATHER_BLACK },
			plates = false,
			liana = false,
			fang = false,
			lava = true,
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
	-- La más larga: caña de basalto con anillos de azufre, boquilla de obsidiana con dos esquirlas,
	-- cristales de azufre bajo la boca y un anillo amarillo que brilla en la punta.
	SulfurBlowgun = function(tool)
		return buildBlowgun(tool, {
			length = 4.5,
			tube = BASALT,
			tubeMaterial = BASALT_MATERIAL,
			nodes = SULFUR,
			nodeMaterial = SMOOTH,
			mouth = OBSIDIAN,
			muzzle = OBSIDIAN,
			tipMaterial = SMOOTH,
			grip = LEATHER,
			fur = false,
			liana = false,
			shells = false,
			feathers = { SULFUR, FEATHER_BLACK, MAGMA },
			sap = true,
			sapColor = SULFUR_GLOW,
			sulfur = true,
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
	-- Asta de basalto con una grieta de lava que sube en zigzag, bandas de lava y púas de obsidiana,
	-- garras de obsidiana de las que gotea lava, una corona de esquirlas y un corazón de magma que echa
	-- chispas y humo dentro de un anillo de fuego que flota inclinado.
	LavaStaff = function(tool)
		return buildStaff(tool, {
			shaft = BASALT,
			shaftMaterial = BASALT_MATERIAL,
			claws = OBSIDIAN,
			clawMaterial = SMOOTH,
			crystal = MAGMA,
			crystalSize = 0.85,
			wrap = LEATHER,
			decorate = function(handle, top)
				local points = {
					Vector3.new(0.13, -1.7, 0.04),
					Vector3.new(0.15, -0.9, -0.06),
					Vector3.new(0.13, 0.1, 0.06),
					Vector3.new(0.15, 1.1, -0.05),
					Vector3.new(0.13, top - 0.15, 0.03),
				}
				for index = 1, #points - 1 do
					strut(handle, "Crack", points[index], points[index + 1], 0.05, 0.06, MAGMA, NEON, Vector3.xAxis)
				end
				for index = 0, 4 do
					local angle = index * math.pi * 2 / 5
					shard(
						handle,
						0.55,
						0.16,
						CFrame.new(0, top + 0.1, 0)
							* CFrame.Angles(0, angle, 0)
							* CFrame.new(0, 0, -0.22)
							* CFrame.Angles(-0.55, 0, 0)
					)
				end
				-- Anillo de fuego que flota inclinado alrededor del corazón de magma.
				local ringCount = 10
				for index = 0, ringCount - 1 do
					block(
						handle,
						"FireRing",
						Vector3.new(0.5, 0.06, 0.06),
						MAGMA,
						NEON,
						CFrame.new(0, top + 0.6, 0)
							* CFrame.Angles(0.35, 0, 0.2)
							* CFrame.Angles(0, index * math.pi * 2 / ringCount, 0)
							* CFrame.new(0, 0, -0.8)
					)
				end
				-- Gotas de lava que cuelgan de las garras, púas de obsidiana a media asta y bandas de lava.
				for index = 0, 3 do
					local angle = index * math.pi / 2 + math.pi / 4
					local outward = Vector3.new(math.sin(angle), 0, math.cos(angle))
					lavaDrip(handle, 0.24, CFrame.new(Vector3.new(0, top + 0.42, 0) + outward * 0.62))
				end
				for index = 0, 2 do
					shard(
						handle,
						0.36,
						0.12,
						CFrame.new(0, 0.55, 0)
							* CFrame.Angles(0, index * math.pi * 2 / 3, 0)
							* CFrame.new(0, 0, -0.3)
							* CFrame.Angles(-math.rad(105), 0, 0)
					)
				end
				for _, bandY in { -0.25, 1.55 } do
					rod(handle, "Band", 0.06, 0.36, MAGMA, NEON, CFrame.new(0, bandY, 0))
				end
				local crystal = handle.Parent and handle.Parent:FindFirstChild("Crystal")
				if crystal and crystal:IsA("BasePart") then
					embers(crystal, 6)
					smoke(crystal, 2)
				end
			end,
		})
	end,
}

-- Aspectos de arma (Data/Cosmetics "WeaponSkin"), por id del cosmético: reciben el nivel del arma de
-- rol que sustituyen (1 la inicial, MAX_LEVEL la de la forja volcánica).
local SKINS: { [string]: (tool: Tool, level: number) -> BasePart } = {
	TitanKingMace = buildTitanKingMace,
	SpectralJaguarBow = buildSpectralJaguarBow,
	FeatheredSerpentStaff = buildFeatheredSerpentStaff,
	CeibaBlowgun = buildCeibaBlowgun,
	SulfurMace = buildSulfurMace,
}
WeaponTools.MAX_LEVEL = 4

-- Rol y nivel de cada arma de rol: la inicial (Data/Roles, la primera de "weapons") es la 1 y cada
-- receta del rol que la mejora ("upgrades") suma uno.
local roleLevels: { [string]: { role: string, level: number } } = {}
for roleId, role in Roles do
	local weaponId: string? = role.weapons[1]
	local level = 1
	while weaponId and not roleLevels[weaponId] do
		roleLevels[weaponId] = { role = roleId, level = level }
		local nextId: string? = nil
		for _, recipe in Recipes do
			if recipe.role == roleId and recipe.upgrades == weaponId and recipe.weaponId then
				nextId = recipe.weaponId
			end
		end
		weaponId = nextId
		level += 1
	end
end

-- Rol y nivel (1 a MAX_LEVEL) de un arma de rol; nil si no es de ningún rol.
function WeaponTools.roleLevel(weaponId: string): (string?, number)
	local entry = roleLevels[weaponId]
	return if entry then entry.role else nil, if entry then entry.level else 0
end

-- Arma inicial de un rol con el nivel "level" (para la vista previa del Armario).
function WeaponTools.roleWeapon(roleId: string, level: number): string?
	for weaponId, entry in roleLevels do
		if entry.role == roleId and entry.level == level then
			return weaponId
		end
	end
	return nil
end

function WeaponTools.hasSkin(skinId: string): boolean
	return SKINS[skinId] ~= nil
end

-- El constructor del aspecto "skinId" si es del rol del arma "weaponId", y el nivel del arma.
local function skinFor(weaponId: string, skinId: any): ((tool: Tool, level: number) -> BasePart)?
	local roleId = WeaponTools.roleLevel(weaponId)
	local cosmetic = if typeof(skinId) == "string" then Cosmetics[skinId] else nil
	return if roleId and cosmetic and cosmetic.role == roleId then SKINS[skinId] else nil
end

-- Pone en "tool" las piezas del arma "weaponId", con el aspecto "skinId" si es de su rol.
local function fill(tool: Tool, weaponId: string, skinId: string?)
	local _, level = WeaponTools.roleLevel(weaponId)
	local skin = skinFor(weaponId, skinId)
	tool:SetAttribute("Skin", if skin then skinId else nil)
	if skin then
		skin(tool, level)
	else
		BUILDERS[weaponId](tool)
	end
end

-- Construye el arma "weaponId" como Tool. Con "skinId" (un aspecto de su rol), con ese aspecto.
function WeaponTools.build(weaponId: string, skinId: string?): Tool
	local weapon = Weapons[weaponId]
	assert(weapon and BUILDERS[weaponId], `Arma desconocida: {weaponId}`)

	local tool = Instance.new("Tool")
	tool.Name = weapon.name
	local damage = math.round(weapon.damage * Config.Combat.PlayerDamageMultiplier)
	tool.ToolTip = `{weapon.name}: {damage} de daño`
	if weapon.poison then
		tool.ToolTip ..= ` · veneno {math.round(weapon.poison.dps * Config.Combat.PlayerDamageMultiplier)}/s`
	end
	if weapon.tool then
		local kind = weapon.tool.kind
		tool.ToolTip ..= if kind == "Axe"
			then " · golpea árboles"
			elseif kind == "Sickle" then " · corta helechos y arbustos"
			else " · golpea rocas"
	end
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponId", weaponId)

	fill(tool, weaponId, skinId)
	return tool
end

-- Cambia el aspecto de las armas de rol de "player" (mochila, mano y StarterGear) al de su atributo
-- "WeaponSkin" (o al de siempre si no lleva). Se cambian las piezas dentro de la misma Tool, así no
-- se mueve de su casilla; la que tenía en la mano se suelta y se vuelve a coger.
function WeaponTools.reskin(player: Player)
	local skinId = player:GetAttribute("WeaponSkin")
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local containers: { Instance? } =
		{ player:FindFirstChild("StarterGear"), player:FindFirstChildOfClass("Backpack"), character }
	for _, container in containers do
		for _, tool in if container then container:GetChildren() else {} do
			local weaponId = tool:GetAttribute("WeaponId")
			if
				tool:IsA("Tool")
				and typeof(weaponId) == "string"
				and tool:GetAttribute("Skin") ~= (if skinFor(weaponId, skinId) then skinId else nil)
			then
				local inHand = container == character and humanoid ~= nil
				if inHand and humanoid then
					humanoid:UnequipTools()
				end
				for _, child in tool:GetChildren() do
					if child:IsA("BasePart") then
						child:Destroy()
					end
				end
				fill(tool, weaponId, if typeof(skinId) == "string" then skinId else nil)
				if inHand and humanoid then
					humanoid:EquipTool(tool)
				end
			end
		end
	end
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

-- El arma del rol "roleId" en su nivel más alto con el aspecto "skinId", suelta y anclada, para verla
-- en una imagen (Armario, tiendas de cosméticos). Su PrimaryPart es el mango.
function WeaponTools.preview(roleId: string, skinId: string?): Model?
	local weaponId = WeaponTools.roleWeapon(roleId, WeaponTools.MAX_LEVEL)
	if not weaponId then
		return nil
	end
	local tool = WeaponTools.build(weaponId, skinId)
	local model = Instance.new("Model")
	model.Name = "Weapon"
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.Parent = model
		end
	end
	tool:Destroy()
	local handle = model:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		model.PrimaryPart = handle
	end
	return model
end

return WeaponTools
