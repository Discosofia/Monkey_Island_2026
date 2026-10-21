--!strict
-- Modelos de las armaduras (Data/Armor) que lleva puestas el personaje, y de los trajes (cosméticos
-- "Outfit" de Data/Cosmetics, Fase 9), que se ponen en su lugar. Los viste "dress" con los atributos
-- del jugador ("Armor", "Role" y "Outfit", que publica ServerShared/CosmeticsServer): CraftingService
-- al fabricarlas y al reaparecer y CosmeticsServer al cambiar de traje. Está en Shared porque el
-- Armario (UI/WardrobePanel) viste también el avatar de la vista previa. Cada pieza va soldada a la parte del cuerpo que cubre (torso,
-- cintura, brazos y muslos), así se mueve con ella y no la atraviesa al andar o al golpear; las
-- medidas salen del tamaño de esa parte, así quedan bien en cualquier avatar. En R6, que no tiene
-- antebrazos ni cintura, se usa el trozo correspondiente del brazo, la pierna o el torso.
-- Respecto a cada parte: -Z es el frente, +Z la espalda, +Y arriba.
-- Cada rol tiene las suyas (mismos números y recetas; nombres por rol en Data/Armor "roleNames"); un
-- rol nuevo sin las propias llevaría las del guerrero. Cada rango es más vistoso y detallado que
-- el anterior. La espalda es lo que el jugador ve todo el rato (la cámara va detrás), así que cada una
-- lleva ahí su motivo más llamativo.
-- Guerrero:
--   - Chaleco de pelaje: chaleco rojo de mono aullador con ribete y cuello de pelaje dorado,
--     cordones de fibra, collar de colmillos, cinturón de cuerda con zurrón y un plátano de amuleto,
--     brazaletes de pelaje dorado y muñecas vendadas con fibra. Detrás, la huella de una mano de
--     mono en pelaje dorado y flecos de pelo.
--   - Armadura de hueso: peto de cuero con costillas en V y esternón de hueso, cráneos de mono de
--     hombreras sobre un mechón de pelaje rojo, brazales de cuero con tablillas de hueso, hebilla
--     de calavera y faldones de cuero y hueso en los muslos. Detrás, columna y costillas con un
--     cráneo de trofeo sobre dos huesos cruzados y borlas de pelaje rojo.
--   - Armadura de plata (lomo plateado): manto y gorguera de pelaje plateado de gorila, peto de
--     hueso grueso (pectorales y abdominales) con remaches, medallón de plata con un plátano dorado
--     que destella, hombreras de láminas de hueso con tres cráneos de mono en abanico, brazales con
--     puño de pelaje y faldones de pelaje y hueso. Detrás, capa oscura de gorila con flecos y la
--     cabeza de un gorila plateado furioso de ojos rojos que brillan.
-- Cazador (ligeras, de cuero con camuflaje de hojas; detrás, la capucha bajada y el carcaj con las
-- flechas asomando por encima del hombro derecho, el de la mano que tira):
--   - Capa de rastreador: jubón de cuero claro, esclavina de pelaje pardo con hojas cosidas, correa
--     del carcaj cruzada, brazal en el antebrazo del arco y cinturón de fibra con zurrón y cuchillo.
--     Detrás, un abanico de hojas bajo la capucha y el carcaj de corteza con tres flechas de plumas
--     blancas.
--   - Armadura de cazador: jubón de cuero oscuro con botones de hueso, hombrera de láminas de hueso
--     en el hombro izquierdo y un manojo de hojas en el derecho, correa con colmillos de trofeo,
--     brazal con tablillas de hueso y hojas colgando de los muslos. Detrás, un manto de hojas de tres
--     verdes y el carcaj de cuero con aros de hueso, un colmillo colgando y cinco flechas de plumas
--     rojas y blancas.
--   - Manto de cazador plateado: capa de pelaje plateado con hojas oscuras de camuflaje y flecos,
--     capucha de pelaje con orejas, broche de plata en forma de hoja, correas cruzadas con remaches,
--     hombros de pelaje con garras de hueso, brazales con puño de pelaje y faldones plateados. Detrás,
--     el carcaj de cuero oscuro con aros de plata y siete flechas de plumas plateadas y negras.
-- Mago (de chamán: tela y amuletos que pasan a runas y cristales que brillan en azul; el morado es
-- del veneno y el verde, de las curaciones):
--   - Manto de amuletos: túnica teñida de morado bajo un poncho de fibra con franjas y flecos, collar
--     de cuentas con un amuleto de piedra, faja con una calabaza y pulseras de cuentas. Detrás, un
--     atrapasueños con tres plumas.
--   - Túnica de runas: túnica añil con ribetes dorados, una runa que brilla en el pecho, cráneos de
--     mono de ojos brillantes en las hombreras, faja con piedras rúnicas y brazales con runas.
--     Detrás, un círculo de runas de neón con un triángulo dentro y dos talismanes colgando.
--   - Manto de cristal: túnica añil oscura bajo una capa de pelaje plateado con cuello alto y flecos
--     de cristal, broche y cadena de plata con cristales, hombros de pelaje con cristales y puños
--     plateados. Detrás, una corona de cristales que sale de un disco de plata rodeado de runas y
--     asoma por encima de los hombros.
-- Médico (de curandero: lino, hierbas y frascos; lo que brilla, en verde, el color de las curaciones):
--   - Bandolera de curandero: túnica de lino con una bandolera de cuero cruzada, por delante y por
--     detrás, con bolsitas de las que asoman hojas; mortero en la cadera, vendas en los antebrazos y
--     hojas atadas a los brazos. Detrás, un manojo de hierbas atado a la bandolera.
--   - Peto de curandero: peto de hueso blanco con una cruz de hojas y una flor en el centro, hombreras
--     de hueso con hojas, cinturón con rollos de venda y bolsas en los muslos. Detrás, una mochila de
--     cuero en un bastidor de madera con frascos de poción encima y a los lados y hierbas asomando.
--   - Manto de sanador: manto y capa de pelaje plateado, bandolera con frascos que brillan, broche
--     con una gema verde y hojas en los hombros. Detrás, un tótem sanador pequeño (como el de la
--     definitiva) con su gema verde brillando por encima de los hombros, entre hojas y frascos.
-- Nivel 4, armadura volcánica (forja volcánica): basalto y obsidiana con grietas de lava que brillan,
-- la más detallada (113–137 piezas). Todas con hombreras de cristales de obsidiana hundidos en lava,
-- gotas de lava y humo que sale de los hombros. Detrás, el guerrero un volcán en escalones con ríos
-- de lava, cráter con fuente, bombas y humo bajo una corona de cristales; el cazador (Manto de brasa)
-- una capa de ceniza con zarpazos de lava y el carcaj de obsidiana con flechas que arden; el mago
-- (Túnica de lava) un sol negro en anillos de fuego con llamas y una corona de cristales de lava, y el
-- médico (Manto de azufre) una mochila con un racimo de cristales de azufre y chimeneas de humo.

local Armor = require(game:GetService("ReplicatedStorage").Shared.Data.Armor)

local FUR = Color3.fromRGB(150, 70, 45)
local FUR_DARK = Color3.fromRGB(122, 55, 36)
local GOLDEN_FUR = Color3.fromRGB(235, 190, 80)
local FIBER = Color3.fromRGB(150, 135, 85)
local LEATHER = Color3.fromRGB(70, 47, 30)
local LEATHER_DARK = Color3.fromRGB(48, 32, 20)
local BONE = Color3.fromRGB(230, 220, 195)
local BONE_DARK = Color3.fromRGB(190, 175, 145)
local THICK_BONE = Color3.fromRGB(242, 236, 218)
local SKULL_HOLE = Color3.fromRGB(45, 32, 24)
local SILVER_FUR = Color3.fromRGB(215, 220, 228)
local SILVER_FUR_DARK = Color3.fromRGB(170, 175, 185)
local GORILLA_FUR = Color3.fromRGB(72, 72, 80)
local GORILLA_FACE = Color3.fromRGB(40, 40, 46)
local GORILLA_NOSE = Color3.fromRGB(58, 58, 66)
local GORILLA_EYE = Color3.fromRGB(235, 45, 30)
local SILVER = Color3.fromRGB(200, 205, 215)
local BANANA = Color3.fromRGB(240, 200, 60)
local BANANA_TIP = Color3.fromRGB(85, 60, 30)
local HUNTER_LEATHER = Color3.fromRGB(128, 90, 56)
local HUNTER_LEATHER_DARK = Color3.fromRGB(90, 62, 40)
local FUR_BROWN = Color3.fromRGB(112, 80, 52)
local LEAF = Color3.fromRGB(62, 132, 56)
local LEAF_DARK = Color3.fromRGB(40, 100, 46)
local BARK = Color3.fromRGB(96, 66, 40)
local ARROW_SHAFT = Color3.fromRGB(165, 125, 80)
local FEATHER_WHITE = Color3.fromRGB(236, 232, 222)
local FEATHER_GREY = Color3.fromRGB(150, 150, 150)
local FEATHER_RED = Color3.fromRGB(185, 55, 40)
local LEAF_LIGHT = Color3.fromRGB(110, 160, 70)
local LEAF_SHADOW = Color3.fromRGB(32, 72, 52)
local DYE_PURPLE = Color3.fromRGB(118, 72, 148)
-- Fibra tejida del poncho, más clara que la de los cordones (FIBER): en grande salía verde oliva.
local WOVEN_FIBER = Color3.fromRGB(196, 165, 108)
local MAGE_INDIGO = Color3.fromRGB(64, 54, 112)
local MAGE_INDIGO_DARK = Color3.fromRGB(42, 36, 80)
local GOLD_TRIM = Color3.fromRGB(215, 175, 75)
local BEAD_RED = Color3.fromRGB(185, 60, 45)
local BEAD_TEAL = Color3.fromRGB(55, 160, 165)
local GOURD = Color3.fromRGB(195, 150, 70)
local STONE = Color3.fromRGB(120, 120, 125)
local RUNE = Color3.fromRGB(95, 215, 255)
local CRYSTAL = Color3.fromRGB(150, 225, 255)
-- Lino algo tostado: más claro, con la luz de Studio salía azulado.
local LINEN = Color3.fromRGB(196, 170, 125)
local FLASK_GLASS = Color3.fromRGB(205, 235, 228)
local POTION = Color3.fromRGB(85, 185, 95)
local HEAL_GLOW = Color3.fromRGB(120, 255, 150)
local CORK = Color3.fromRGB(150, 110, 70)
local FLOWER = Color3.fromRGB(215, 70, 60)
-- Los del Tótem sanador de la definitiva (AbilityFxController).
local TOTEM_WOOD = Color3.fromRGB(128, 84, 46)
local TOTEM_WOOD_LIGHT = Color3.fromRGB(156, 108, 62)
local TURQUOISE = Color3.fromRGB(48, 178, 168)
local PAINT_RED = Color3.fromRGB(178, 48, 38)
local PAINT_BLACK = Color3.fromRGB(25, 22, 20)
local PAINT_WHITE = Color3.fromRGB(240, 232, 214)
-- Armadura volcánica (forja volcánica).
local BASALT = Color3.fromRGB(62, 58, 60)
local BASALT_DARK = Color3.fromRGB(40, 37, 40)
local OBSIDIAN = Color3.fromRGB(30, 24, 38)
local OBSIDIAN_SHEEN = Color3.fromRGB(80, 60, 110)
local MAGMA = Color3.fromRGB(255, 110, 30)
local EMBER = Color3.fromRGB(255, 180, 60)
local ASH = Color3.fromRGB(118, 110, 106)
local ASH_DARK = Color3.fromRGB(72, 66, 64)
local CHARRED_LEAF = Color3.fromRGB(52, 46, 40)
local LAVA_ROBE = Color3.fromRGB(96, 30, 26)
local LAVA_ROBE_DARK = Color3.fromRGB(58, 20, 20)
local SULFUR = Color3.fromRGB(235, 205, 55)
local SULFUR_GLOW = Color3.fromRGB(255, 235, 110)

local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic
local LEATHER_MATERIAL = Enum.Material.Leather
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local SLATE = Enum.Material.Slate
local BASALT_MATERIAL = Enum.Material.Basalt

-- Y así a lo largo de Z (discos que miran al frente).
local FACING = CFrame.Angles(0, math.rad(90), 0)
-- Y así a lo largo de Y (los cilindros tienen el eje en X): tubos de pie.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
-- Rol que pone su armadura a quien aún no tiene la suya.
local DEFAULT_ROLE = "Guerrero"

local ArmorModels = {}

type Builder = {
	size: Vector3, -- tamaño de la parte del cuerpo a la que se suelda
	block: (size: Vector3, color: Color3, material: Enum.Material, at: CFrame) -> BasePart,
	rod: (length: number, diameter: number, color: Color3, material: Enum.Material, at: CFrame) -> BasePart,
	ball: (diameter: number, color: Color3, material: Enum.Material, at: CFrame) -> BasePart,
	oval: (size: Vector3, color: Color3, material: Enum.Material, at: CFrame) -> BasePart,
	fang: (length: number, width: number, color: Color3, material: Enum.Material, at: CFrame) -> BasePart,
}

-- Las partes del cuerpo que cubre una armadura; los brazos y los muslos por lado (-1 izquierda, 1
-- derecha, que es también el signo de su X respecto al torso).
type Body = {
	torso: Builder,
	waist: Builder,
	upperArm: { [number]: Builder },
	lowerArm: { [number]: Builder },
	upperLeg: { [number]: Builder },
}

-- Piezas soldadas a "anchor" dentro de "model"; "at" es respecto a la parte del cuerpo, que en R6
-- es el trozo "offset" de "anchor". Sin "anchor" (un avatar sin esa parte) las piezas no se ponen.
local function builder(model: Model, anchor: BasePart?, offset: CFrame, size: Vector3): Builder
	local function place(piece: BasePart, at: CFrame): BasePart
		piece.Name = "Armor"
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true
		piece.CastShadow = false
		if anchor then
			piece.CFrame = anchor.CFrame * offset * at
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchor
			weld.Part1 = piece
			weld.Parent = piece
			piece.Parent = model
		end
		return piece
	end
	local function part(partSize: Vector3, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local piece = Instance.new("Part")
		piece.Size = partSize
		piece.Color = color
		piece.Material = material
		if shape then
			piece.Shape = shape
		end
		return piece
	end
	return {
		size = size,
		block = function(blockSize, color, material, at)
			return place(part(blockSize, color, material), at)
		end,
		rod = function(length, diameter, color, material, at)
			return place(part(Vector3.new(length, diameter, diameter), color, material, Enum.PartType.Cylinder), at)
		end,
		ball = function(diameter, color, material, at)
			return place(part(Vector3.one * diameter, color, material, Enum.PartType.Ball), at)
		end,
		oval = function(ovalSize, color, material, at)
			local piece = part(ovalSize, color, material)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = piece
			return place(piece, at)
		end,
		-- Colmillo, garra o mechón en punta: pirámide (CornerWedgePart) con la base en "at" y la punta
		-- "length" studs hacia su +Y. La punta queda sobre una esquina de la base, así se curva un poco.
		fang = function(length, width, color, material, at)
			local piece = Instance.new("CornerWedgePart")
			piece.Size = Vector3.new(width, length, width)
			piece.Color = color
			piece.Material = material
			return place(piece, at * CFrame.new(width / 2, length / 2, -width / 2))
		end,
	}
end

-- La parte "r15" del personaje o, en R6, el trozo "r6Offset" (de tamaño "r6Size") de la parte "r6".
local function limb(
	model: Model,
	character: Model,
	r15: string,
	r6: string,
	r6Offset: CFrame,
	r6Size: Vector3?
): Builder
	local part = character:FindFirstChild(r15)
	if part and part:IsA("BasePart") then
		return builder(model, part, CFrame.identity, part.Size)
	end
	local fallback = character:FindFirstChild(r6)
	if fallback and fallback:IsA("BasePart") then
		return builder(model, fallback, r6Offset, r6Size or fallback.Size)
	end
	return builder(model, nil, CFrame.identity, Vector3.one)
end

-- Cordón, correa o tira recta de "from" a "to".
local function strap(
	make: Builder,
	from: Vector3,
	to: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material
)
	make.block(
		Vector3.new(thickness, thickness, (to - from).Magnitude),
		color,
		material,
		CFrame.lookAt((from + to) / 2, to)
	)
end

-- Plátano pequeño (amuleto y emblema): tres tramos en arco en el plano XY de "at", con la parte
-- de abajo del arco en "at" y el rabito oscuro en un extremo. "length" es lo que mide de punta a punta.
local function banana(make: Builder, length: number, at: CFrame)
	local radius = length * 0.75
	local function onArc(angle: number): CFrame
		return at * CFrame.new(math.sin(angle) * radius, radius * (1 - math.cos(angle)), 0) * CFrame.Angles(0, 0, angle)
	end
	for index = -1, 1 do
		make.rod(length * 0.38, length * 0.22, BANANA, SMOOTH, onArc(index * 0.45))
	end
	make.rod(length * 0.14, length * 0.1, BANANA_TIP, SMOOTH, onArc(0.78))
end

-- Banda que rodea un brazo o una pierna a la altura "y" (con "tilt" parece una venda enrollada).
local function band(
	make: Builder,
	y: number,
	height: number,
	grow: number,
	color: Color3,
	material: Enum.Material,
	tilt: number?
)
	local size = make.size
	return make.block(
		Vector3.new(size.X + grow, height, size.Z + grow),
		color,
		material,
		CFrame.new(0, y, 0) * CFrame.Angles(tilt or 0, 0, 0)
	)
end

-- ===================================== Chaleco de pelaje =====================================

local function furVest(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local skin = 0.1 -- grosor del pelaje
	local gap = 0.03 -- separación del torso
	local front = -(depth / 2 + gap + skin / 2)
	local back = depth / 2 + gap + skin / 2
	local outer = width / 2 + gap + skin / 2
	-- Los paneles suben hasta el borde de arriba de las hombreras: se solapan con ellas y no queda
	-- ninguna rendija entre el chaleco y los hombros.
	local panelHeight = height + gap + skin
	local panelY = (gap + skin) / 2
	-- Espalda y costados, ceñidos al torso.
	make.block(Vector3.new(width + 2 * (gap + skin), panelHeight, skin), FUR_DARK, FABRIC, CFrame.new(0, panelY, back))
	local neck = width * 0.2
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(skin, panelHeight, depth + 2 * gap),
			FUR_DARK,
			FABRIC,
			CFrame.new(side * outer, panelY, 0)
		)
		-- Panel delantero: deja una abertura estrecha en el centro.
		local inner = 0.16
		local panelWidth = width / 2 + gap + skin - inner
		make.block(
			Vector3.new(panelWidth, panelHeight, skin),
			FUR,
			FABRIC,
			CFrame.new(side * (inner + panelWidth / 2), panelY, front)
		)
		-- Ribete dorado en el borde de la abertura.
		make.block(
			Vector3.new(0.1, panelHeight, skin + 0.04),
			GOLDEN_FUR,
			FABRIC,
			CFrame.new(side * (inner + 0.05), panelY, front)
		)
		-- Hombrera: tapa el hombro de delante a atrás y deja libre el cuello.
		local shoulderWidth = outer + skin / 2 - neck
		make.block(
			Vector3.new(shoulderWidth, skin, depth + 2 * (gap + skin)),
			FUR,
			FABRIC,
			CFrame.new(side * (neck + shoulderWidth / 2), height / 2 + gap + skin / 2, 0)
		)
		-- Mechón de pelaje redondeando el borde del hombro.
		make.ball(0.42, FUR, FABRIC, CFrame.new(side * (outer - 0.04), height / 2 + 0.04, 0))
		-- Cuello de pelaje dorado a cada lado.
		make.rod(
			depth * 0.9,
			0.24,
			GOLDEN_FUR,
			FABRIC,
			CFrame.new(side * neck, height / 2 + 0.1, 0) * CFrame.Angles(0, math.rad(90), 0)
		)
	end
	-- Espalda (lo que el jugador ve siempre): huella de una mano de mono en pelaje dorado y flecos
	-- de pelo en punta bajo el ribete.
	local paw = CFrame.new(0, -height * 0.06, back + skin / 2 + 0.02)
	make.oval(Vector3.new(0.5, 0.46, 0.06), GOLDEN_FUR, FABRIC, paw)
	for finger = 0, 3 do
		local angle = math.rad(-33 + finger * 22)
		make.oval(
			Vector3.new(0.13, 0.3, 0.06),
			GOLDEN_FUR,
			FABRIC,
			paw * CFrame.new(math.sin(angle) * 0.38, math.cos(angle) * 0.38, 0) * CFrame.Angles(0, 0, -angle)
		)
	end
	make.oval(
		Vector3.new(0.13, 0.26, 0.06),
		GOLDEN_FUR,
		FABRIC,
		paw * CFrame.new(-0.3, -0.06, 0) * CFrame.Angles(0, 0, math.rad(55))
	)
	local fringe = 5
	for index = 0, fringe - 1 do
		local x = -width * 0.4 + index * width * 0.8 / (fringe - 1)
		make.fang(
			if index % 2 == 0 then 0.3 else 0.22,
			0.2,
			if index % 2 == 0 then FUR else FUR_DARK,
			FABRIC,
			CFrame.new(x + 0.1, -height / 2 + 0.02, back + 0.12) * CFrame.Angles(0, 0, math.pi)
		)
	end
	-- Cuello por detrás y ribete dorado fino abajo.
	make.rod(width * 0.4 + 0.24, 0.24, GOLDEN_FUR, FABRIC, CFrame.new(0, height / 2 + 0.1, depth / 2 - 0.02))
	make.block(
		Vector3.new(width + 2 * (gap + skin) + 0.04, 0.14, depth + 2 * (gap + skin) + 0.04),
		GOLDEN_FUR,
		FABRIC,
		CFrame.new(0, -height / 2 + 0.05, 0)
	)
	-- Cordones de fibra en cruz que cierran la abertura, por debajo del collar.
	for _, laceY in { -height * 0.06, -height * 0.28 } do
		for _, tilt in { 0.5, -0.5 } do
			make.block(
				Vector3.new(0.36, 0.05, 0.04),
				FIBER,
				FABRIC,
				CFrame.new(0, laceY, front - 0.07) * CFrame.Angles(0, 0, tilt)
			)
		end
	end
	-- Collar de colmillos: cordón en V desde el cuello y tres colmillos colgando, el del centro mayor.
	local necklaceZ = front - 0.09
	local knot = Vector3.new(0, height * 0.17, necklaceZ)
	for side = -1, 1, 2 do
		local from = Vector3.new(side * neck * 1.1, height / 2 - 0.02, necklaceZ)
		strap(make, from, knot, 0.05, FIBER, FABRIC)
		local hook = knot:Lerp(from, 0.35)
		make.fang(
			0.26,
			0.11,
			BONE,
			SMOOTH,
			CFrame.new(hook.X + side * 0.04, hook.Y + 0.02, necklaceZ - 0.02) * CFrame.Angles(0, 0, math.pi)
		)
	end
	make.fang(
		0.38,
		0.14,
		BONE,
		SMOOTH,
		CFrame.new(0.06, knot.Y + 0.03, necklaceZ - 0.02) * CFrame.Angles(0, 0, math.pi)
	)

	-- Cinturón de cuerda con el nudo y los cabos delante, un zurrón y un plátano de amuleto.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltY = waist.size.Y * 0.1
	local beltFront = -(hipDepth / 2 + 0.07)
	waist.block(Vector3.new(hipWidth + 0.12, 0.14, hipDepth + 0.12), FIBER, FABRIC, CFrame.new(0, beltY, 0))
	waist.ball(0.2, FIBER, FABRIC, CFrame.new(-0.28, beltY, beltFront - 0.02))
	for _, tilt in { 0.18, -0.12 } do
		waist.block(
			Vector3.new(0.06, 0.3, 0.06),
			FIBER,
			FABRIC,
			CFrame.new(-0.28 + tilt * 0.4, beltY - 0.18, beltFront - 0.03) * CFrame.Angles(0, 0, tilt)
		)
	end
	local pouch = CFrame.new(hipWidth * 0.3, beltY - 0.18, beltFront - 0.06)
	waist.block(Vector3.new(0.38, 0.36, 0.14), LEATHER, LEATHER_MATERIAL, pouch)
	waist.block(Vector3.new(0.42, 0.14, 0.18), LEATHER_DARK, LEATHER_MATERIAL, pouch * CFrame.new(0, 0.13, -0.01))
	waist.ball(0.11, BONE, SMOOTH, pouch * CFrame.new(0, 0.06, -0.1))
	banana(waist, 0.6, CFrame.new(-hipWidth * 0.3, beltY - 0.12, beltFront - 0.06) * CFrame.Angles(0, 0, 1.25))

	-- Brazaletes de pelaje dorado y muñecas vendadas con fibra.
	for side = -1, 1, 2 do
		band(body.upperArm[side], -body.upperArm[side].size.Y * 0.12, 0.2, 0.1, GOLDEN_FUR, FABRIC)
		local forearm = body.lowerArm[side]
		band(forearm, -forearm.size.Y * 0.3, 0.1, 0.06, FIBER, FABRIC, 0.12)
		band(forearm, -forearm.size.Y * 0.44, 0.1, 0.06, FIBER, FABRIC, -0.12)
	end
end

-- ===================================== Armadura de hueso =====================================

-- Cráneo de mono con la cara hacia la -Z de "at", "scale" veces el tamaño de las hombreras de la
-- armadura de hueso. Los pequeños ("simple") van sin ceja, nariz ni colmillos: no se verían.
local function monkeySkull(make: Builder, at: CFrame, scale: number, simple: boolean?)
	local function on(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x * scale, y * scale, z * scale)
	end
	make.oval(Vector3.new(0.8, 0.7, 0.86) * scale, BONE, SMOOTH, on(0, 0.06, 0.06))
	-- Cuencas oscuras bajo la ceja saliente.
	for eye = -1, 1, 2 do
		make.ball(0.2 * scale, SKULL_HOLE, SMOOTH, on(eye * 0.15, -0.03, -0.32))
	end
	-- Hocico con el hueco de la nariz y dos colmillos.
	make.block(Vector3.new(0.4, 0.24, 0.3) * scale, BONE, SMOOTH, on(0, -0.2, -0.38))
	if simple then
		return
	end
	make.oval(Vector3.new(0.64, 0.15, 0.16) * scale, BONE, SMOOTH, on(0, 0.1, -0.32))
	make.block(Vector3.new(0.12, 0.08, 0.04) * scale, SKULL_HOLE, SMOOTH, on(0, -0.13, -0.54))
	for tooth = -1, 1, 2 do
		make.fang(
			0.18 * scale,
			0.07 * scale,
			BONE,
			SMOOTH,
			on(tooth * 0.12 + 0.035, -0.31, -0.47) * CFrame.Angles(0, 0, math.pi)
		)
	end
end

-- Hueso de dibujo (caña con un bulto en cada punta) de "length" a lo largo de la X de "at".
local function cartoonBone(make: Builder, length: number, thickness: number, color: Color3, at: CFrame)
	make.rod(length, thickness, color, SMOOTH, at)
	for tip = -1, 1, 2 do
		make.ball(thickness * 1.8, color, SMOOTH, at * CFrame.new(tip * length / 2, 0, 0))
	end
end

local function boneArmor(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.1)
	local back = depth / 2 + 0.1
	-- Peto de cuero y cuello de pelaje rojo.
	make.block(
		Vector3.new(width + 0.1, height * 0.9, depth + 0.16),
		LEATHER,
		LEATHER_MATERIAL,
		CFrame.new(0, -height * 0.03, 0)
	)
	make.block(Vector3.new(width * 0.75, 0.25, depth + 0.25), FUR, FABRIC, CFrame.new(0, height / 2 - 0.05, 0))
	-- Costillas en V que bajan desde el esternón, cada vez más cortas, y el esternón atado con fibra.
	local tilt = 0.22
	for index, ribY in { 0.27, 0.1, -0.07, -0.24 } do
		local length = width * (0.36 - index * 0.02)
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(length, 0.12, 0.1),
				BONE,
				SMOOTH,
				CFrame.new(
					side * (0.1 + length / 2 * math.cos(tilt)),
					height * ribY - length / 2 * math.sin(tilt),
					front - 0.02
				) * CFrame.Angles(0, 0, -side * tilt)
			)
		end
	end
	make.block(Vector3.new(0.2, height * 0.74, 0.14), BONE, SMOOTH, CFrame.new(0, -height * 0.02, front - 0.05))
	for _, tieY in { 0.18, -0.16 } do
		make.block(Vector3.new(0.3, 0.1, 0.08), FIBER, FABRIC, CFrame.new(0, height * tieY, front - 0.12))
	end
	-- Espalda (lo que el jugador ve siempre): columna sobre tres costillas oscuras y, encima, un
	-- cráneo de trofeo sobre dos huesos cruzados, con dos borlas de pelaje rojo colgando.
	for _, ribY in { 0.2, 0, -0.2 } do
		make.block(Vector3.new(width * 0.78, 0.13, 0.08), BONE_DARK, SMOOTH, CFrame.new(0, height * ribY, back))
	end
	make.block(Vector3.new(0.14, height * 0.8, 0.1), BONE_DARK, SMOOTH, CFrame.new(0, 0, back + 0.04))
	for index = 0, 1 do
		make.block(
			Vector3.new(0.26, 0.11, 0.1),
			BONE,
			SMOOTH,
			CFrame.new(0, -height * (0.18 + index * 0.18), back + 0.1)
		)
	end
	local trophy = CFrame.new(0, height * 0.16, back + 0.12)
	for _, cross in { 0.65, -0.65 } do
		cartoonBone(make, width * 0.62, 0.12, BONE, trophy * CFrame.new(0, 0, 0.04) * CFrame.Angles(0, 0, cross))
	end
	monkeySkull(make, trophy * CFrame.new(0, 0, 0.28) * CFrame.Angles(math.rad(-10), math.pi, 0), 0.85)
	for side = -1, 1, 2 do
		make.block(Vector3.new(0.04, 0.3, 0.04), FIBER, FABRIC, trophy * CFrame.new(side * 0.3, -0.3, 0.12))
		make.fang(
			0.3,
			0.16,
			FUR,
			FABRIC,
			trophy * CFrame.new(side * 0.3 + 0.08, -0.42, 0.2) * CFrame.Angles(0, 0, math.pi)
		)
	end

	-- Cinturón con hebilla de calavera.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.07)
	waist.block(
		Vector3.new(hipWidth + 0.14, 0.22, hipDepth + 0.14),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, 0.08, 0)
	)
	waist.ball(0.32, BONE, SMOOTH, CFrame.new(0, 0.08, beltFront - 0.06))
	for eye = -1, 1, 2 do
		waist.ball(0.09, SKULL_HOLE, SMOOTH, CFrame.new(eye * 0.06, 0.1, beltFront - 0.2))
	end

	for side = -1, 1, 2 do
		-- Hombrera: cráneo de mono sobre un mechón de pelaje rojo, sujeto con una correa al brazo.
		local arm = body.upperArm[side]
		local top = arm.size.Y / 2
		arm.oval(Vector3.new(arm.size.X * 0.95, 0.36, arm.size.Z * 0.95), FUR, FABRIC, CFrame.new(side * 0.06, top, 0))
		band(arm, top - 0.42, 0.16, 0.08, LEATHER, LEATHER_MATERIAL)
		monkeySkull(
			arm,
			CFrame.new(side * arm.size.X * 0.2, top + 0.2, 0) * CFrame.Angles(0, -side * math.rad(30), 0),
			1
		)
		-- Brazal de cuero con dos tablillas de hueso por fuera, atado con fibra.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, -0.02, fs.Y * 0.55, 0.08, LEATHER, LEATHER_MATERIAL)
		band(forearm, fs.Y * 0.2, 0.08, 0.12, FIBER, FABRIC)
		for _, z in { -0.2, 0.2 } do
			forearm.block(
				Vector3.new(0.08, fs.Y * 0.6, 0.16),
				BONE,
				SMOOTH,
				CFrame.new(side * (fs.X / 2 + 0.07), -0.02, z * fs.Z)
			)
		end
		-- Faldón de cuero en el muslo con dos tablillas de hueso.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.17, -(ls.Z / 2 + 0.05)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.85, ls.Y * 0.36, 0.08), LEATHER, LEATHER_MATERIAL, flap)
		for _, x in { -0.2, 0.2 } do
			leg.block(Vector3.new(0.12, ls.Y * 0.3, 0.06), BONE, SMOOTH, flap * CFrame.new(x * ls.X, -0.02, -0.06))
		end
	end
end

-- Cabeza de gorila plateado para la espalda, mirando a la -Z de "at", de "size" studs de ancho:
-- pelaje plateado con orejas, cara oscura, ceja gruesa, ojos rojos que brillan, nariz ancha y
-- boca con colmillos.
local function gorillaFace(make: Builder, at: CFrame, size: number)
	local function on(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x * size, y * size, z * size)
	end
	make.oval(Vector3.new(1, 1.05, 0.14) * size, SILVER_FUR, FABRIC, on(0, 0, 0))
	make.oval(Vector3.new(0.72, 0.7, 0.2) * size, GORILLA_FACE, SMOOTH, on(0, -0.08, -0.06))
	make.oval(Vector3.new(0.44, 0.17, 0.14) * size, GORILLA_NOSE, SMOOTH, on(0, -0.12, -0.13))
	make.block(Vector3.new(0.4, 0.06, 0.04) * size, SKULL_HOLE, SMOOTH, on(0, -0.32, -0.13))
	for side = -1, 1, 2 do
		make.oval(Vector3.new(0.22, 0.28, 0.12) * size, SILVER_FUR_DARK, FABRIC, on(side * 0.52, 0.04, 0.02))
		make.ball(0.15 * size, GORILLA_EYE, Enum.Material.Neon, on(side * 0.17, 0.08, -0.14))
		make.ball(0.07 * size, SKULL_HOLE, SMOOTH, on(side * 0.1, -0.15, -0.19))
		-- Ceja de furia: inclinada, más baja por dentro.
		make.oval(
			Vector3.new(0.4, 0.11, 0.2) * size,
			GORILLA_FACE,
			SMOOTH,
			on(side * 0.18, 0.18, -0.13) * CFrame.Angles(0, 0, side * 0.35)
		)
		make.fang(
			0.13 * size,
			0.07 * size,
			THICK_BONE,
			SMOOTH,
			on(side * 0.13 + 0.035, -0.33, -0.15) * CFrame.Angles(0, 0, math.pi)
		)
	end
end

-- ===================================== Armadura de plata =====================================

local function silverArmor(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.09)
	local back = depth / 2
	-- Peto de cuero oscuro bajo las placas de hueso grueso.
	make.block(
		Vector3.new(width + 0.12, height * 0.92, depth + 0.18),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, -height * 0.03, 0)
	)
	-- Pectorales: placa clara sobre otra más oscura que hace de borde, con dos remaches de plata.
	for side = -1, 1, 2 do
		local pec = CFrame.new(side * (width * 0.22 + 0.03), height * 0.2, front - 0.06)
			* CFrame.Angles(0.12, -side * 0.12, 0)
		make.block(Vector3.new(width * 0.44, height * 0.3, 0.12), BONE_DARK, SMOOTH, pec)
		make.block(Vector3.new(width * 0.4, height * 0.26, 0.1), THICK_BONE, SMOOTH, pec * CFrame.new(0, 0.01, -0.04))
		for _, y in { 0.12, -0.12 } do
			local rivet = make.ball(0.1, SILVER, METAL, pec * CFrame.new(side * width * 0.15, y, -0.1))
			rivet.Reflectance = 0.25
		end
	end
	-- Abdominales: tres filas de placas, más estrechas hacia abajo.
	for row = 0, 2 do
		for side = -1, 1, 2 do
			local plateWidth = width * (0.21 - row * 0.015)
			make.block(
				Vector3.new(plateWidth, height * 0.14, 0.1),
				if row == 1 then BONE else THICK_BONE,
				SMOOTH,
				CFrame.new(side * (plateWidth / 2 + 0.03), -height * (0.05 + row * 0.17), front - 0.03)
			)
		end
	end
	-- Medallón de plata con un plátano dorado, entre los pectorales, que destella de vez en cuando.
	local medal = CFrame.new(0, height * 0.22, front - 0.24)
	local rim = make.rod(0.08, 0.62, SILVER, METAL, medal * FACING)
	rim.Reflectance = 0.35
	make.rod(0.04, 0.48, GORILLA_FUR, METAL, medal * CFrame.new(0, 0, -0.04) * FACING)
	banana(make, 0.36, medal * CFrame.new(0, -0.08, -0.08))
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 3
	sparkle.Lifetime = NumberRange.new(0.5, 0.9)
	sparkle.Speed = NumberRange.new(0.3, 0.8)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.LightEmission = 0.6
	sparkle.ZOffset = 1
	sparkle.Parent = rim

	-- Manto de pelaje plateado sobre los hombros (por delante no baja, para no tapar el peto) y
	-- gorguera alta por detrás del cuello.
	make.block(
		Vector3.new(width + 0.4, height * 0.28, depth * 0.7 + 0.2),
		SILVER_FUR,
		FABRIC,
		CFrame.new(0, height / 2 - 0.08, depth * 0.15 + 0.1)
	)
	make.oval(
		Vector3.new(width + 0.3, 0.3, 0.36),
		SILVER_FUR,
		FABRIC,
		CFrame.new(0, height / 2 - 0.06, -depth / 2 + 0.02)
	)
	local ruff = 5
	for index = 0, ruff - 1 do
		local angle = math.rad(-90 + index * 180 / (ruff - 1))
		make.oval(
			Vector3.new(0.6, 0.55, 0.45),
			if index % 2 == 0 then SILVER_FUR else SILVER_FUR_DARK,
			FABRIC,
			CFrame.new(math.sin(angle) * 0.8, height / 2 + 0.22, math.cos(angle) * 0.62) * CFrame.Angles(0, angle, 0)
		)
	end
	-- Capa de pelaje oscuro de gorila con flecos en punta abajo y, encima, la cabeza de un gorila
	-- plateado de ojos rojos que brillan: es lo que el jugador ve siempre, desde detrás.
	local capeHeight = height * 1.0
	local capeY = -height * 0.12
	make.block(Vector3.new(width * 0.96, capeHeight, 0.12), GORILLA_FUR, FABRIC, CFrame.new(0, capeY, back + 0.17))
	gorillaFace(make, CFrame.new(0, height * 0.06, back + 0.23) * CFrame.Angles(0, math.pi, 0), width * 0.7)
	local tufts = 5
	for index = 0, tufts - 1 do
		local x = -width * 0.38 + index * width * 0.76 / (tufts - 1)
		make.fang(
			if index % 2 == 0 then 0.42 else 0.3,
			0.34,
			if index % 2 == 0 then GORILLA_FUR else SILVER_FUR,
			FABRIC,
			CFrame.new(x + 0.17, capeY - capeHeight / 2 + 0.05, back + 0.36) * CFrame.Angles(0, 0, math.pi)
		)
	end

	-- Cinturón ancho con hebilla de plata y un hueso en el centro.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	waist.block(
		Vector3.new(hipWidth + 0.16, 0.28, hipDepth + 0.18),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, 0.06, 0)
	)
	local buckle = waist.block(Vector3.new(0.46, 0.36, 0.08), SILVER, METAL, CFrame.new(0, 0.06, beltFront - 0.04))
	buckle.Reflectance = 0.35
	waist.ball(0.16, THICK_BONE, SMOOTH, CFrame.new(0, 0.06, beltFront - 0.1))

	for side = -1, 1, 2 do
		-- Hombrera: tres láminas de hueso grueso que bajan hacia fuera sobre un mechón de pelaje
		-- plateado, con un remache y tres cráneos de mono encima.
		local arm = body.upperArm[side]
		local as = arm.size
		local top = as.Y / 2
		arm.oval(Vector3.new(as.X * 1.3, 0.6, as.Z * 1.3), SILVER_FUR, FABRIC, CFrame.new(side * 0.12, top + 0.05, 0))
		local lames: { CFrame } = {}
		for index = 0, 2 do
			local lame = CFrame.new(side * (0.1 + index * 0.1), top + 0.2 - index * 0.21, 0)
				* CFrame.Angles(0, 0, -side * (0.22 + index * 0.18))
			lames[index + 1] = lame
			arm.oval(
				Vector3.new(as.X * 1.05 - index * 0.08, 0.28, as.Z * 1.3 - index * 0.08),
				if index == 1 then BONE else THICK_BONE,
				SMOOTH,
				lame
			)
		end
		local stud = arm.ball(0.14, SILVER, METAL, lames[2] * CFrame.new(side * (as.X * 0.5 - 0.12), 0.08, 0))
		stud.Reflectance = 0.25
		-- Tres cráneos de mono en fila sobre la lámina de arriba, el del centro mayor, en abanico: hacia
		-- fuera y delante, hacia fuera y hacia fuera y atrás, para que se les vea la cara desde detrás.
		for index, z in { -0.32, 0, 0.32 } do
			local turn = math.rad(55 + (index - 1) * 35)
			local scale = if index == 2 then 0.72 else 0.6
			monkeySkull(
				arm,
				lames[1] * CFrame.new(0, 0.1 + 0.3 * scale, z * as.Z) * CFrame.Angles(0, -side * turn, 0),
				scale,
				true
			)
		end
		-- Brazal de cuero con placa de hueso por fuera, dos remaches y un puño de pelaje en la muñeca.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, 0.05, fs.Y * 0.55, 0.08, LEATHER_DARK, LEATHER_MATERIAL)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, SILVER_FUR, FABRIC)
		forearm.block(
			Vector3.new(0.12, fs.Y * 0.6, fs.Z * 0.75),
			THICK_BONE,
			SMOOTH,
			CFrame.new(side * (fs.X / 2 + 0.08), 0.05, 0)
		)
		for _, y in { 0.18, -0.18 } do
			local rivet = forearm.ball(0.12, SILVER, METAL, CFrame.new(side * (fs.X / 2 + 0.15), 0.05 + y * fs.Y, 0))
			rivet.Reflectance = 0.25
		end
		-- Faldón de pelaje plateado en el muslo con una placa de hueso y un remache.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.19, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), SILVER_FUR, FABRIC, flap)
		leg.block(Vector3.new(ls.X * 0.65, ls.Y * 0.3, 0.08), THICK_BONE, SMOOTH, flap * CFrame.new(0, 0.02, -0.07))
		local rivet = leg.ball(0.12, SILVER, METAL, flap * CFrame.new(0, ls.Y * 0.09, -0.12))
		rivet.Reflectance = 0.25
	end
end

-- ===================================== Cazador =====================================

-- Hoja de camuflaje: óvalo estrecho de "length" de largo en el plano XY de "at", con la punta hacia su
-- +Y y el nervio central más oscuro por fuera (+Z de "at"); sin nervio parece un lunar.
local function leaf(make: Builder, length: number, color: Color3, at: CFrame)
	make.oval(Vector3.new(length * 0.42, length, 0.05), color, SMOOTH, at)
	make.block(
		Vector3.new(0.03, length * 0.8, 0.03),
		color:Lerp(Color3.new(0, 0, 0), 0.35),
		SMOOTH,
		at * CFrame.new(0, 0, 0.03)
	)
end

type QuiverStyle = {
	length: number,
	radius: number,
	color: Color3,
	material: Enum.Material,
	rim: Color3,
	rimMaterial: Enum.Material,
	arrows: number,
	feathers: { Color3 },
}

-- Carcaj con el eje a lo largo de la +Y de "at" (el centro del tubo): tubo, aro en la boca y en el
-- fondo, y las flechas asomando por la boca con sus plumas, un poco abiertas en abanico. Devuelve el
-- marco de la boca.
local function quiver(make: Builder, at: CFrame, style: QuiverStyle): CFrame
	local length, radius = style.length, style.radius
	make.rod(length, radius * 2, style.color, style.material, at * UPRIGHT)
	local mouth = at * CFrame.new(0, length / 2, 0)
	make.rod(0.12, radius * 2 + 0.06, style.rim, style.rimMaterial, mouth * CFrame.new(0, -0.05, 0) * UPRIGHT)
	make.rod(0.1, radius * 2 + 0.04, style.rim, style.rimMaterial, at * CFrame.new(0, -length / 2 + 0.06, 0) * UPRIGHT)
	local count = style.arrows
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2
		local spot = if count == 1
			then Vector3.zero
			else Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.55
		local stick = 0.4 + (index % 2) * 0.12
		local arrowAt = mouth * CFrame.new(spot) * CFrame.Angles(spot.Z * 0.8, 0, -spot.X * 0.8)
		make.rod(stick + 0.2, 0.06, ARROW_SHAFT, WOOD, arrowAt * CFrame.new(0, (stick - 0.2) / 2, 0) * UPRIGHT)
		local feather = style.feathers[(index - 1) % #style.feathers + 1]
		for vane = 0, 1 do
			make.block(
				Vector3.new(0.03, 0.3, 0.17),
				feather,
				SMOOTH,
				arrowAt * CFrame.new(0, stick - 0.13, 0) * CFrame.Angles(0, vane * math.pi / 2, 0)
			)
		end
	end
	return mouth
end

-- Abanico de "count" hojas solapadas que salen de la nuca y caen por la espalda, de "length" de largo,
-- abiertas "spread" radianes a cada lado de la vertical, con los colores de "colors" alternados y a
-- "out" studs por detrás de la espalda (más si van sobre una capa).
local function leafFan(make: Builder, count: number, length: number, spread: number, colors: { Color3 }, out: number)
	local height, depth = make.size.Y, make.size.Z
	-- Salen de debajo de la capucha (loweredHood), que tapa su arranque.
	local neck = Vector3.new(0, height / 2 - 0.3, depth / 2 + out)
	for index = 0, count - 1 do
		local angle = -spread + index * 2 * spread / (count - 1)
		-- Las del centro, más largas; una de cada dos un poco por fuera (sin caras en el mismo plano).
		local size = length * (1 - 0.18 * math.abs(angle) / spread)
		local direction = Vector3.new(math.sin(angle), -math.cos(angle), 0)
		local center = neck + direction * (size / 2 + 0.05) + Vector3.new(0, 0, 0.02 + (index % 2) * 0.03)
		leaf(make, size, colors[index % #colors + 1], CFrame.new(center) * CFrame.Angles(0, 0, math.pi + angle))
	end
end

-- Capucha bajada a la espalda, bajo la nuca: el pliegue, su abertura oscura y la punta colgando.
-- Devuelve el marco del pliegue.
local function loweredHood(make: Builder, color: Color3, lining: Color3, material: Enum.Material): CFrame
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	-- Más alto que ancho, con la abertura arriba: ancho y plano parece el ala de un sombrero.
	local fold = CFrame.new(0, height / 2 - 0.2, depth / 2 + 0.2)
	make.oval(Vector3.new(width * 0.52, 0.72, 0.44), color, material, fold)
	make.oval(Vector3.new(width * 0.38, 0.14, 0.26), lining, material, fold * CFrame.new(0, 0.31, -0.05))
	make.fang(0.4, 0.28, color, material, fold * CFrame.new(0.14, -0.3, 0.2) * CFrame.Angles(0, 0, math.pi))
	return fold
end

-- El carcaj va en diagonal por la espalda, con la boca junto al hombro derecho (+X), a "out" studs
-- de la espalda (más si va sobre una capa). Devuelve el marco de su centro.
local function backQuiver(make: Builder, style: QuiverStyle, out: number): CFrame
	local depth = make.size.Z
	local at = CFrame.new(0.16, -0.04, depth / 2 + style.radius + out) * CFrame.Angles(0, 0, -0.42)
	quiver(make, at, style)
	return at
end

-- Correa del carcaj por delante: del hombro derecho a la cadera izquierda.
local function quiverStrap(make: Builder, front: number, thickness: number, color: Color3, material: Enum.Material)
	local width, height = make.size.X, make.size.Y
	strap(
		make,
		Vector3.new(width * 0.3, height / 2 - 0.02, front),
		Vector3.new(-width * 0.4, -height / 2 + 0.12, front),
		thickness,
		color,
		material
	)
end

local function trackerCape(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.07)
	-- Jubón de cuero claro, ceñido.
	make.block(
		Vector3.new(width + 0.1, height * 0.92, depth + 0.12),
		HUNTER_LEATHER,
		LEATHER_MATERIAL,
		CFrame.new(0, -height * 0.02, 0)
	)
	-- Esclavina corta de pelaje pardo sobre los hombros.
	make.block(Vector3.new(width + 0.24, 0.32, depth + 0.3), FUR_BROWN, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.02))
	for side = -1, 1, 2 do
		make.ball(0.5, FUR_BROWN, FABRIC, CFrame.new(side * (width / 2 + 0.02), height / 2 - 0.08, 0))
		-- Hojas cosidas por delante, a los lados del cuello.
		leaf(
			make,
			0.42,
			LEAF,
			CFrame.new(side * width * 0.3, height / 2 - 0.16, front - 0.1) * CFrame.Angles(0, 0, side * 0.5)
		)
		leaf(
			make,
			0.36,
			LEAF_DARK,
			CFrame.new(side * width * 0.43, height / 2 - 0.2, front - 0.09) * CFrame.Angles(0, 0, side * 1.1)
		)
	end
	-- Detrás, un abanico de hojas que cae de la nuca por la espalda, bajo la capucha.
	leafFan(make, 9, 1.15, 1.3, { LEAF, LEAF_DARK }, 0.1)
	loweredHood(make, HUNTER_LEATHER, HUNTER_LEATHER_DARK, LEATHER_MATERIAL)
	backQuiver(make, {
		length = 1.6,
		radius = 0.22,
		color = BARK,
		material = WOOD,
		rim = FIBER,
		rimMaterial = FABRIC,
		arrows = 3,
		feathers = { FEATHER_WHITE, FEATHER_GREY },
	}, 0.2)
	quiverStrap(make, front - 0.04, 0.12, FIBER, FABRIC)
	-- Cordones de fibra cerrando el jubón.
	for _, laceY in { -height * 0.12, -height * 0.32 } do
		make.block(Vector3.new(0.3, 0.05, 0.04), FIBER, FABRIC, CFrame.new(0, laceY, front - 0.02))
	end

	-- Cinturón de fibra con zurrón a la derecha y cuchillo de hueso en su funda a la izquierda.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltY = waist.size.Y * 0.1
	local beltFront = -(hipDepth / 2 + 0.07)
	waist.block(Vector3.new(hipWidth + 0.12, 0.14, hipDepth + 0.12), FIBER, FABRIC, CFrame.new(0, beltY, 0))
	local pouch = CFrame.new(hipWidth * 0.3, beltY - 0.16, beltFront - 0.06)
	waist.block(Vector3.new(0.36, 0.32, 0.14), HUNTER_LEATHER_DARK, LEATHER_MATERIAL, pouch)
	waist.block(Vector3.new(0.4, 0.12, 0.18), HUNTER_LEATHER, LEATHER_MATERIAL, pouch * CFrame.new(0, 0.12, -0.01))
	local sheath = CFrame.new(-hipWidth * 0.36, beltY - 0.2, beltFront - 0.03) * CFrame.Angles(0, 0, -0.25)
	waist.block(Vector3.new(0.14, 0.42, 0.08), HUNTER_LEATHER_DARK, LEATHER_MATERIAL, sheath)
	waist.block(Vector3.new(0.1, 0.2, 0.1), BONE, SMOOTH, sheath * CFrame.new(0, 0.3, 0))

	-- Brazal de cuero en el antebrazo del arco (el derecho) y muñeca vendada en el otro.
	local bowArm = body.lowerArm[1]
	band(bowArm, -bowArm.size.Y * 0.08, bowArm.size.Y * 0.5, 0.08, HUNTER_LEATHER_DARK, LEATHER_MATERIAL)
	band(bowArm, bowArm.size.Y * 0.1, 0.06, 0.12, FIBER, FABRIC)
	local drawArm = body.lowerArm[-1]
	band(drawArm, -drawArm.size.Y * 0.36, 0.12, 0.06, FIBER, FABRIC, 0.12)
end

-- Hombrera de láminas de hueso (la del arco no la lleva: tensaría la cuerda contra ella).
local function bonePauldron(arm: Builder, side: number)
	local as = arm.size
	local top = as.Y / 2
	for index = 0, 2 do
		arm.oval(
			Vector3.new(as.X * 1.05 - index * 0.1, 0.24, as.Z * 1.15 - index * 0.1),
			if index == 1 then BONE_DARK else BONE,
			SMOOTH,
			CFrame.new(side * (0.06 + index * 0.09), top + 0.08 - index * 0.2, 0)
				* CFrame.Angles(0, 0, -side * (0.2 + index * 0.2))
		)
	end
	band(arm, top - 0.5, 0.12, 0.08, HUNTER_LEATHER_DARK, LEATHER_MATERIAL)
end

local function hunterLeather(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	-- Jubón de cuero oscuro con tres botones de hueso (palitos atravesados) en el centro.
	make.block(
		Vector3.new(width + 0.12, height * 0.92, depth + 0.14),
		HUNTER_LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, -height * 0.02, 0)
	)
	make.block(
		Vector3.new(0.06, height * 0.8, 0.04),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, -height * 0.04, front)
	)
	for _, y in { 0.22, 0, -0.22 } do
		make.rod(0.32, 0.08, BONE, SMOOTH, CFrame.new(0, height * y, front - 0.04))
	end
	-- Cuello de cuero claro.
	make.block(
		Vector3.new(width * 0.7, 0.2, depth + 0.24),
		HUNTER_LEATHER,
		LEATHER_MATERIAL,
		CFrame.new(0, height / 2 - 0.04, 0)
	)
	-- Correa del carcaj con tres colmillos de trofeo colgando.
	quiverStrap(make, front - 0.06, 0.14, LEATHER, LEATHER_MATERIAL)
	for index = 1, 3 do
		local t = 0.25 + index * 0.13
		local x = width * 0.3 + (-width * 0.7) * t
		local y = (height / 2 - 0.02) + (-height + 0.14) * t
		make.fang(0.26, 0.1, BONE, SMOOTH, CFrame.new(x + 0.05, y - 0.04, front - 0.09) * CFrame.Angles(0, 0, math.pi))
	end
	-- Detrás, un manto de hojas de tres verdes, la capucha y el carcaj de cuero con aros de hueso.
	leafFan(make, 11, 1.3, 1.4, { LEAF, LEAF_DARK, LEAF_LIGHT }, 0.1)
	loweredHood(make, HUNTER_LEATHER, LEATHER_DARK, LEATHER_MATERIAL)
	local quiverAt = backQuiver(make, {
		length = 1.7,
		radius = 0.24,
		-- Claro, de hueso: de lejos es lo que lo distingue de la capa de rastreador.
		color = BONE_DARK,
		material = SMOOTH,
		rim = LEATHER_DARK,
		rimMaterial = LEATHER_MATERIAL,
		arrows = 5,
		feathers = { FEATHER_RED, FEATHER_WHITE },
	}, 0.22)
	-- Un colmillo grande atado al carcaj, colgando de su costado.
	make.block(Vector3.new(0.04, 0.3, 0.04), FIBER, FABRIC, quiverAt * CFrame.new(-0.28, 0.25, 0.05))
	make.fang(0.36, 0.14, BONE, SMOOTH, quiverAt * CFrame.new(-0.21, 0.12, 0.14) * CFrame.Angles(0, 0, math.pi))

	-- Cinturón de cuero con hebilla de hueso, zurrón y cuchillo.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.08)
	waist.block(Vector3.new(hipWidth + 0.14, 0.2, hipDepth + 0.14), LEATHER, LEATHER_MATERIAL, CFrame.new(0, 0.06, 0))
	waist.block(Vector3.new(0.3, 0.24, 0.08), BONE, SMOOTH, CFrame.new(0, 0.06, beltFront - 0.02))
	local pouch = CFrame.new(hipWidth * 0.3, -0.12, beltFront - 0.06)
	waist.block(Vector3.new(0.38, 0.34, 0.14), LEATHER, LEATHER_MATERIAL, pouch)
	waist.block(
		Vector3.new(0.42, 0.12, 0.18),
		HUNTER_LEATHER_DARK,
		LEATHER_MATERIAL,
		pouch * CFrame.new(0, 0.13, -0.01)
	)
	local sheath = CFrame.new(-hipWidth * 0.36, -0.14, beltFront - 0.03) * CFrame.Angles(0, 0, -0.25)
	waist.block(Vector3.new(0.14, 0.44, 0.08), LEATHER, LEATHER_MATERIAL, sheath)
	waist.block(Vector3.new(0.1, 0.22, 0.1), BONE, SMOOTH, sheath * CFrame.new(0, 0.32, 0))

	-- Hombrera de hueso en el hombro izquierdo; en el derecho, un manojo de hojas.
	bonePauldron(body.upperArm[-1], -1)
	local right = body.upperArm[1]
	for index, tilt in { -0.5, 0, 0.5 } do
		leaf(
			right,
			0.5,
			if index == 2 then LEAF_DARK else LEAF,
			CFrame.new(right.size.X * 0.3, right.size.Y / 2 - 0.05, tilt * 0.6)
				* CFrame.Angles(0, math.rad(90), 0)
				* CFrame.Angles(0, 0, math.pi * 0.9 + tilt)
		)
	end
	-- Brazal de cuero con dos tablillas de hueso en el antebrazo del arco; guante en el otro.
	local bowArm = body.lowerArm[1]
	local fs = bowArm.size
	band(bowArm, -fs.Y * 0.06, fs.Y * 0.55, 0.08, LEATHER, LEATHER_MATERIAL)
	for _, z in { -0.2, 0.2 } do
		bowArm.block(
			Vector3.new(0.08, fs.Y * 0.5, 0.16),
			BONE,
			SMOOTH,
			CFrame.new(fs.X / 2 + 0.07, -fs.Y * 0.06, z * fs.Z)
		)
	end
	band(body.lowerArm[-1], -fs.Y * 0.38, 0.2, 0.08, HUNTER_LEATHER_DARK, LEATHER_MATERIAL)
	-- Hojas colgando por delante de los muslos (en el muslo: en la cintura, la pierna las atraviesa).
	for side = -1, 1, 2 do
		local leg = body.upperLeg[side]
		local ls = leg.size
		for index, x in { -0.18, 0.18 } do
			leaf(
				leg,
				0.6,
				if index == 1 then LEAF else LEAF_DARK,
				CFrame.new(side * 0.06 + x * ls.X, ls.Y / 2 - 0.36, -(ls.Z / 2 + 0.05 + index * 0.02))
					* CFrame.Angles(0, 0, math.pi + x)
			)
		end
	end
end

local function silverHunter(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	local back = depth / 2
	-- Jubón de cuero oscuro con dos correas cruzadas y remaches de plata.
	make.block(
		Vector3.new(width + 0.12, height * 0.92, depth + 0.14),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, -height * 0.02, 0)
	)
	quiverStrap(make, front - 0.04, 0.14, HUNTER_LEATHER_DARK, LEATHER_MATERIAL)
	strap(
		make,
		Vector3.new(-width * 0.3, height / 2 - 0.02, front - 0.02),
		Vector3.new(width * 0.4, -height / 2 + 0.12, front - 0.02),
		0.14,
		HUNTER_LEATHER_DARK,
		LEATHER_MATERIAL
	)
	for _, at in
		{
			Vector3.new(0.03, -height * 0.02, 0),
			Vector3.new(-width * 0.33, -height * 0.36, 0),
			Vector3.new(width * 0.33, -height * 0.36, 0),
		}
	do
		local rivet = make.ball(0.13, SILVER, METAL, CFrame.new(at.X, at.Y, front - 0.1))
		rivet.Reflectance = 0.25
	end
	-- Manto de pelaje plateado sobre los hombros y capa que baja por la espalda hasta la cintura, con
	-- flecos en punta y hojas oscuras de camuflaje encima.
	make.block(Vector3.new(width + 0.4, 0.34, depth + 0.4), SILVER_FUR, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.04))
	for side = -1, 1, 2 do
		make.ball(0.6, SILVER_FUR, FABRIC, CFrame.new(side * (width / 2 + 0.06), height / 2 - 0.1, 0))
	end
	local capeHeight = height * 1.08
	local capeY = height / 2 - capeHeight / 2 - 0.02
	make.block(Vector3.new(width * 1.02, capeHeight, 0.12), SILVER_FUR, FABRIC, CFrame.new(0, capeY, back + 0.16))
	local tufts = 5
	for index = 0, tufts - 1 do
		local x = -width * 0.4 + index * width * 0.8 / (tufts - 1)
		make.fang(
			if index % 2 == 0 then 0.36 else 0.26,
			0.3,
			if index % 2 == 0 then SILVER_FUR else SILVER_FUR_DARK,
			FABRIC,
			CFrame.new(x + 0.15, capeY - capeHeight / 2 + 0.04, back + 0.36) * CFrame.Angles(0, 0, math.pi)
		)
	end
	leafFan(make, 9, 1.25, 1.3, { LEAF_SHADOW, LEAF_DARK }, 0.25)
	-- Capucha de pelaje plateado con dos orejas, como la piel de un animal.
	-- (Más oscura que la capa: del mismo plateado no se distingue.)
	local hood = loweredHood(make, SILVER_FUR_DARK, GORILLA_FUR, FABRIC)
	for side = -1, 1, 2 do
		make.fang(
			0.34,
			0.22,
			GORILLA_FUR,
			FABRIC,
			hood * CFrame.new(side * 0.26 - 0.11, 0.24, 0.2) * CFrame.Angles(0, 0, -side * 0.3)
		)
	end
	-- Broche de plata en forma de hoja cerrando el manto bajo el cuello.
	local brooch = CFrame.new(0, height / 2 - 0.18, front - 0.12)
	local disc = make.rod(0.06, 0.34, SILVER, METAL, brooch * FACING)
	disc.Reflectance = 0.35
	local leafPin = make.oval(
		Vector3.new(0.14, 0.32, 0.05),
		SILVER,
		METAL,
		brooch * CFrame.new(0, 0, -0.05) * CFrame.Angles(0, 0, 0.6)
	)
	leafPin.Reflectance = 0.35
	-- Carcaj de cuero oscuro con aros de plata y siete flechas de plumas plateadas y negras.
	local quiverAt = backQuiver(make, {
		length = 1.8,
		radius = 0.26,
		color = LEATHER_DARK,
		material = LEATHER_MATERIAL,
		rim = SILVER,
		rimMaterial = METAL,
		arrows = 7,
		feathers = { SILVER_FUR, GORILLA_FACE },
	}, 0.32)
	local midBand = make.rod(0.1, 0.58, SILVER, METAL, quiverAt * UPRIGHT)
	midBand.Reflectance = 0.25
	for side = -1, 1, 2 do
		make.fang(
			0.3,
			0.12,
			THICK_BONE,
			SMOOTH,
			quiverAt * CFrame.new(side * 0.2 - 0.06, -0.1, 0.2) * CFrame.Angles(0, 0, math.pi)
		)
	end

	-- Cinturón ancho con hebilla de plata y zurrón.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	waist.block(
		Vector3.new(hipWidth + 0.16, 0.24, hipDepth + 0.18),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, 0.06, 0)
	)
	local buckle = waist.block(Vector3.new(0.36, 0.28, 0.08), SILVER, METAL, CFrame.new(0, 0.06, beltFront - 0.02))
	buckle.Reflectance = 0.35
	local pouch = CFrame.new(hipWidth * 0.3, -0.12, beltFront - 0.06)
	waist.block(Vector3.new(0.38, 0.34, 0.14), LEATHER_DARK, LEATHER_MATERIAL, pouch)
	waist.block(Vector3.new(0.42, 0.14, 0.18), SILVER_FUR, FABRIC, pouch * CFrame.new(0, 0.13, -0.01))

	for side = -1, 1, 2 do
		-- Hombros de pelaje plateado con dos garras de hueso hacia fuera.
		local arm = body.upperArm[side]
		local as = arm.size
		local top = as.Y / 2
		arm.oval(Vector3.new(as.X * 1.3, 0.55, as.Z * 1.3), SILVER_FUR, FABRIC, CFrame.new(side * 0.1, top + 0.02, 0))
		-- Desde lo alto del pelaje: más adentro quedan enterradas en él.
		for _, z in { -0.2, 0.2 } do
			arm.fang(
				0.42,
				0.16,
				THICK_BONE,
				SMOOTH,
				CFrame.new(side * (as.X * 0.55) - 0.08, top + 0.22, z * as.Z + 0.08) * CFrame.Angles(0, 0, -side * 0.7)
			)
		end
		-- Brazal de cuero con puño de pelaje plateado; el del arco, con placa de hueso y dos remaches.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, 0.04, fs.Y * 0.55, 0.08, LEATHER_DARK, LEATHER_MATERIAL)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, SILVER_FUR, FABRIC)
		if side == 1 then
			forearm.block(
				Vector3.new(0.12, fs.Y * 0.55, fs.Z * 0.7),
				THICK_BONE,
				SMOOTH,
				CFrame.new(fs.X / 2 + 0.08, 0.04, 0)
			)
			for _, y in { 0.16, -0.16 } do
				local rivet = forearm.ball(0.12, SILVER, METAL, CFrame.new(fs.X / 2 + 0.15, 0.04 + y * fs.Y, 0))
				rivet.Reflectance = 0.25
			end
		end
		-- Faldón de pelaje plateado en el muslo con una hoja oscura encima.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), SILVER_FUR, FABRIC, flap)
		leaf(
			leg,
			0.48,
			LEAF_SHADOW,
			flap * CFrame.new(side * 0.1, -0.05, -0.07) * CFrame.Angles(0, math.pi, math.pi + side * 0.3)
		)
	end
end

-- ===================================== Mago =====================================

-- Aro de "count" tramos de radio "radius" en el plano XY de "at" (mirando a su Z): el del atrapasueños
-- y los círculos de runas.
local function hoop(
	make: Builder,
	at: CFrame,
	radius: number,
	count: number,
	thickness: number,
	color: Color3,
	material: Enum.Material
)
	local length = 2 * math.pi * radius / count * 1.08
	for index = 0, count - 1 do
		make.block(
			Vector3.new(length, thickness, thickness),
			color,
			material,
			at * CFrame.Angles(0, 0, index / count * 2 * math.pi) * CFrame.new(0, radius, 0)
		)
	end
end

-- Cristal de "length" que sale de "base" hacia "direction" (respecto a la parte del cuerpo): funda de
-- cristal translúcido con un núcleo de neón que brilla dentro.
local function crystal(make: Builder, base: Vector3, direction: Vector3, length: number, width: number)
	local at = CFrame.lookAt(base, base + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	local shell = make.fang(length, width, CRYSTAL, GLASS, at)
	shell.Transparency = 0.3
	make.fang(length * 0.72, width * 0.5, RUNE, NEON, at * CFrame.new(width * 0.25, 0, -width * 0.25))
end

-- Atrapasueños de "radius" en el plano XY de "at" (mirando a su +Z, hacia atrás): aro de madera, tela
-- de fibra en estrella con una cuenta en el centro y tres plumas colgando de unos cordones con cuentas.
local function dreamcatcher(make: Builder, at: CFrame, radius: number)
	hoop(make, at, radius, 10, 0.09, BARK, WOOD)
	for index = 0, 2 do
		make.block(Vector3.new(radius * 2, 0.03, 0.03), FIBER, FABRIC, at * CFrame.Angles(0, 0, index * math.pi / 3))
	end
	make.ball(0.15, BEAD_TEAL, SMOOTH, at * CFrame.new(0, 0, 0.03))
	for index = -1, 1 do
		local x = index * radius * 0.6
		local bottom = -math.sqrt(radius * radius - x * x)
		make.block(Vector3.new(0.03, 0.28, 0.03), FIBER, FABRIC, at * CFrame.new(x, bottom - 0.14, 0))
		make.ball(0.11, if index == 0 then BEAD_RED else BEAD_TEAL, SMOOTH, at * CFrame.new(x, bottom - 0.3, 0))
		make.oval(
			Vector3.new(0.14, 0.46, 0.04),
			FEATHER_WHITE,
			SMOOTH,
			at * CFrame.new(x, bottom - 0.58, 0) * CFrame.Angles(0, 0, index * 0.15)
		)
	end
end

local function amuletMantle(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	-- Túnica teñida de morado y, encima, el manto de fibra tejida que cae de los hombros como un poncho.
	make.block(
		Vector3.new(width + 0.08, height * 0.95, depth + 0.1),
		DYE_PURPLE,
		FABRIC,
		CFrame.new(0, -height * 0.02, 0)
	)
	local ponchoHeight = height * 0.82
	local ponchoY = height / 2 + 0.05 - ponchoHeight / 2
	local ponchoBottom = ponchoY - ponchoHeight / 2
	local front = -(depth + 0.26) / 2
	local back = (depth + 0.26) / 2
	make.block(Vector3.new(width + 0.26, ponchoHeight, depth + 0.26), WOVEN_FIBER, FABRIC, CFrame.new(0, ponchoY, 0))
	-- Dos franjas teñidas cerca del borde.
	for index, y in { 0.1, 0.26 } do
		make.block(
			Vector3.new(width + 0.3, 0.09, depth + 0.3),
			if index == 1 then DYE_PURPLE else BEAD_RED,
			FABRIC,
			CFrame.new(0, ponchoBottom + y, 0)
		)
	end
	-- Flecos de fibra en el borde, delante y detrás.
	local tassels = 5
	for index = 0, tassels - 1 do
		local x = -width * 0.42 + index * width * 0.84 / (tassels - 1)
		for _, z in { front + 0.12, back + 0.02 } do
			make.fang(
				0.24,
				0.12,
				FIBER,
				FABRIC,
				CFrame.new(x + 0.06, ponchoBottom + 0.02, z) * CFrame.Angles(0, 0, math.pi)
			)
		end
	end
	-- Collar de cuentas en U con un amuleto de piedra teñido en el centro.
	local beads = 7
	for index = 0, beads - 1 do
		local t = index / (beads - 1)
		make.ball(
			0.13,
			if index % 2 == 0 then BEAD_RED else BEAD_TEAL,
			SMOOTH,
			CFrame.new((t - 0.5) * width * 0.48, height / 2 - 0.08 - math.sin(math.pi * t) * 0.34, front - 0.06)
		)
	end
	local amulet = CFrame.new(0, height / 2 - 0.56, front - 0.08)
	make.rod(0.07, 0.36, STONE, SLATE, amulet * FACING)
	make.rod(0.05, 0.2, DYE_PURPLE, SMOOTH, amulet * CFrame.new(0, 0, -0.04) * FACING)
	-- Detrás (lo que el jugador ve siempre): un atrapasueños grande.
	dreamcatcher(make, CFrame.new(0, height * 0.12, back + 0.04), 0.5)

	-- Faja morada con el nudo a un lado y una calabaza de pociones colgando.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.08)
	waist.block(Vector3.new(hipWidth + 0.14, 0.2, hipDepth + 0.14), DYE_PURPLE, FABRIC, CFrame.new(0, 0.08, 0))
	waist.ball(0.22, DYE_PURPLE, FABRIC, CFrame.new(-hipWidth * 0.32, 0.08, beltFront - 0.03))
	waist.block(
		Vector3.new(0.12, 0.34, 0.06),
		DYE_PURPLE,
		FABRIC,
		CFrame.new(-hipWidth * 0.32, -0.16, beltFront - 0.04) * CFrame.Angles(0, 0, 0.15)
	)
	local gourd = CFrame.new(hipWidth * 0.32, -0.2, beltFront - 0.12)
	waist.ball(0.34, GOURD, SMOOTH, gourd)
	waist.rod(0.18, 0.12, GOURD, SMOOTH, gourd * CFrame.new(0, 0.22, 0) * UPRIGHT)
	waist.block(Vector3.new(0.04, 0.2, 0.04), FIBER, FABRIC, gourd * CFrame.new(0, 0.36, 0))

	-- Pulseras de cuentas.
	for side = -1, 1, 2 do
		local forearm = body.lowerArm[side]
		band(forearm, -forearm.size.Y * 0.3, 0.12, 0.08, if side == 1 then BEAD_TEAL else BEAD_RED, SMOOTH)
		band(forearm, -forearm.size.Y * 0.42, 0.08, 0.06, FIBER, FABRIC)
	end
end

-- Cráneo de mono con los ojos encendidos (las hombreras de la túnica de runas).
local function runeSkull(make: Builder, at: CFrame, scale: number)
	monkeySkull(make, at, scale)
	for eye = -1, 1, 2 do
		make.ball(0.12 * scale, RUNE, NEON, at * CFrame.new(eye * 0.15 * scale, -0.03 * scale, -0.37 * scale))
	end
end

local function runeTunic(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	local back = depth / 2 + 0.08
	-- Túnica añil con cuello y tira dorados.
	make.block(
		Vector3.new(width + 0.12, height * 0.94, depth + 0.16),
		MAGE_INDIGO,
		FABRIC,
		CFrame.new(0, -height * 0.02, 0)
	)
	make.block(Vector3.new(width * 0.7, 0.18, depth + 0.24), GOLD_TRIM, FABRIC, CFrame.new(0, height / 2 - 0.04, 0))
	make.block(Vector3.new(0.14, height * 0.8, 0.04), GOLD_TRIM, FABRIC, CFrame.new(0, -height * 0.08, front))
	-- Runa del pecho: triángulo de neón con un punto dentro, a los dos lados de la tira.
	local chest = CFrame.new(width * 0.26, height * 0.16, front - 0.02)
	for index = 0, 2 do
		local angle = index * 2 * math.pi / 3
		make.block(
			Vector3.new(0.34, 0.05, 0.04),
			RUNE,
			NEON,
			chest * CFrame.Angles(0, 0, angle) * CFrame.new(0, -0.1, 0)
		)
	end
	make.ball(0.08, RUNE, NEON, chest)
	-- Detrás (lo que el jugador ve siempre): círculo de runas de neón con marcas en cruz y un
	-- triángulo con un rombo en el centro.
	local seal = CFrame.new(0, height * 0.08, back + 0.02)
	hoop(make, seal, 0.52, 12, 0.07, RUNE, NEON)
	for index = 0, 3 do
		make.block(
			Vector3.new(0.06, 0.18, 0.05),
			RUNE,
			NEON,
			seal * CFrame.Angles(0, 0, index * math.pi / 2) * CFrame.new(0, 0.68, 0)
		)
	end
	for index = 0, 2 do
		make.block(
			Vector3.new(0.72, 0.06, 0.05),
			RUNE,
			NEON,
			seal * CFrame.Angles(0, 0, index * 2 * math.pi / 3) * CFrame.new(0, -0.2, 0)
		)
	end
	make.block(Vector3.new(0.16, 0.16, 0.05), RUNE, NEON, seal * CFrame.Angles(0, 0, math.pi / 4))
	-- Dos talismanes de piedra rúnica colgando de los hombros por detrás y el ribete dorado del bajo.
	for side = -1, 1, 2 do
		local cord = CFrame.new(side * width * 0.4, height / 2 - 0.3, back + 0.03)
		make.block(Vector3.new(0.04, 0.5, 0.04), FIBER, FABRIC, cord)
		make.block(Vector3.new(0.2, 0.26, 0.08), STONE, SLATE, cord * CFrame.new(0, -0.36, 0.02))
		make.block(Vector3.new(0.05, 0.16, 0.03), RUNE, NEON, cord * CFrame.new(0, -0.36, 0.07))
	end
	make.block(
		Vector3.new(width + 0.16, 0.1, depth + 0.2),
		GOLD_TRIM,
		FABRIC,
		CFrame.new(0, -height * 0.02 - height * 0.47 + 0.05, 0)
	)

	-- Faja dorada con tres piedras rúnicas colgando.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.08)
	waist.block(Vector3.new(hipWidth + 0.14, 0.2, hipDepth + 0.14), GOLD_TRIM, FABRIC, CFrame.new(0, 0.06, 0))
	for _, x in { -0.3, 0, 0.3 } do
		local stone = CFrame.new(x * hipWidth, -0.16, beltFront - 0.04)
		waist.block(Vector3.new(0.2, 0.24, 0.08), STONE, SLATE, stone)
		waist.block(Vector3.new(0.05, 0.14, 0.03), RUNE, NEON, stone * CFrame.new(0, 0, -0.05))
	end

	for side = -1, 1, 2 do
		-- Hombrera: cráneo de mono de ojos encendidos sobre un paño añil.
		local arm = body.upperArm[side]
		local top = arm.size.Y / 2
		arm.oval(
			Vector3.new(arm.size.X * 1.05, 0.34, arm.size.Z * 1.05),
			MAGE_INDIGO_DARK,
			FABRIC,
			CFrame.new(side * 0.06, top, 0)
		)
		runeSkull(arm, CFrame.new(side * arm.size.X * 0.2, top + 0.2, 0) * CFrame.Angles(0, -side * math.rad(30), 0), 1)
		-- Brazal añil con una runa que brilla.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, -fs.Y * 0.05, fs.Y * 0.5, 0.08, MAGE_INDIGO_DARK, FABRIC)
		band(forearm, -fs.Y * 0.05, 0.06, 0.12, RUNE, NEON)
		band(forearm, -fs.Y * 0.38, 0.1, 0.1, GOLD_TRIM, FABRIC)
		-- Faldón añil con ribete dorado en el muslo.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.05)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.86, ls.Y * 0.42, 0.08), MAGE_INDIGO, FABRIC, flap)
		leg.block(Vector3.new(ls.X * 0.86 + 0.04, 0.08, 0.1), GOLD_TRIM, FABRIC, flap * CFrame.new(0, -ls.Y * 0.21, 0))
	end
end

local function crystalMantle(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	local back = depth / 2
	-- Túnica añil oscura con una tira de plata.
	make.block(
		Vector3.new(width + 0.12, height * 0.94, depth + 0.16),
		MAGE_INDIGO_DARK,
		FABRIC,
		CFrame.new(0, -height * 0.02, 0)
	)
	local trim = make.block(Vector3.new(0.14, height * 0.8, 0.04), SILVER, METAL, CFrame.new(0, -height * 0.08, front))
	trim.Reflectance = 0.25
	-- Manto de pelaje plateado sobre los hombros, cuello alto por detrás y capa hasta la cintura.
	make.block(Vector3.new(width + 0.4, 0.34, depth + 0.4), SILVER_FUR, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.04))
	for side = -1, 1, 2 do
		make.ball(0.6, SILVER_FUR, FABRIC, CFrame.new(side * (width / 2 + 0.06), height / 2 - 0.1, 0))
	end
	make.oval(
		Vector3.new(width * 0.72, 0.62, 0.34),
		SILVER_FUR,
		FABRIC,
		CFrame.new(0, height / 2 + 0.16, depth / 2 + 0.1)
	)
	local capeHeight = height * 1.08
	local capeY = height / 2 - capeHeight / 2 - 0.02
	make.block(Vector3.new(width * 1.02, capeHeight, 0.12), SILVER_FUR, FABRIC, CFrame.new(0, capeY, back + 0.16))
	-- Flecos de pelaje en el borde de la capa, con tres cristales pequeños colgando entre ellos.
	local capeBottom = capeY - capeHeight / 2
	local tufts = 5
	for index = 0, tufts - 1 do
		local x = -width * 0.4 + index * width * 0.8 / (tufts - 1)
		make.fang(
			if index % 2 == 0 then 0.34 else 0.26,
			0.28,
			if index % 2 == 0 then SILVER_FUR else SILVER_FUR_DARK,
			FABRIC,
			CFrame.new(x + 0.14, capeBottom + 0.04, back + 0.34) * CFrame.Angles(0, 0, math.pi)
		)
	end
	for _, x in { -0.38, -0.19, 0, 0.19, 0.38 } do
		crystal(make, Vector3.new(x * width, capeBottom + 0.06, back + 0.3), Vector3.new(0, -1, 0), 0.4, 0.16)
	end
	-- Detrás (lo que el jugador ve siempre): disco de plata rodeado de runas del que sale una corona de
	-- cristales hacia arriba, que asoma por encima de los hombros por detrás de la cabeza.
	-- (Alto en la espalda y con cristales largos: si no, se queda en una estrella en mitad de la capa.)
	local seal = CFrame.new(0, height * 0.26, back + 0.24)
	local disc = make.rod(0.08, 0.5, SILVER, METAL, seal * FACING)
	disc.Reflectance = 0.35
	hoop(make, seal * CFrame.new(0, 0, -0.02), 0.5, 12, 0.06, RUNE, NEON)
	-- Marcas de runa por debajo del círculo (por arriba las tapan los cristales).
	for index = -2, 2 do
		make.block(
			Vector3.new(0.06, 0.18, 0.05),
			RUNE,
			NEON,
			seal * CFrame.Angles(0, 0, math.pi + index * 0.42) * CFrame.new(0, 0.66, -0.02)
		)
	end
	local crystals = 7
	for index = 0, crystals - 1 do
		local angle = math.rad(-70 + index * 140 / (crystals - 1))
		local direction = Vector3.new(math.sin(angle), math.cos(angle), 0.12)
		local length = 1.5 - math.abs(angle) * 0.55
		crystal(make, seal.Position + direction * 0.14 + Vector3.new(0, 0, 0.06), direction, length, 0.34)
	end
	-- Cadena de plata cruzada con dos cristales colgando y, arriba, el broche de cristal.
	strap(
		make,
		Vector3.new(-width * 0.38, height / 2 - 0.1, front - 0.05),
		Vector3.new(width * 0.38, -height * 0.18, front - 0.05),
		0.07,
		SILVER,
		METAL
	)
	for _, t in { 0.35, 0.7 } do
		local x = -width * 0.38 + width * 0.76 * t
		local y = (height / 2 - 0.1) + (-height * 0.18 - (height / 2 - 0.1)) * t
		crystal(make, Vector3.new(x, y - 0.03, front - 0.09), Vector3.new(0, -1, -0.1), 0.26, 0.12)
	end
	local brooch = CFrame.new(0, height / 2 - 0.2, front - 0.1)
	local rim = make.rod(0.06, 0.34, SILVER, METAL, brooch * FACING)
	rim.Reflectance = 0.35
	crystal(make, brooch.Position + Vector3.new(0, -0.08, -0.06), Vector3.new(0, 1, -0.3), 0.32, 0.16)

	-- Faja oscura con hebilla de plata y un cristal colgando.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	waist.block(Vector3.new(hipWidth + 0.16, 0.22, hipDepth + 0.18), MAGE_INDIGO, FABRIC, CFrame.new(0, 0.06, 0))
	local buckle = waist.block(Vector3.new(0.34, 0.28, 0.08), SILVER, METAL, CFrame.new(0, 0.06, beltFront - 0.02))
	buckle.Reflectance = 0.35
	crystal(waist, Vector3.new(0, -0.08, beltFront - 0.06), Vector3.new(0, -1, 0), 0.34, 0.16)

	for side = -1, 1, 2 do
		-- Hombros de pelaje plateado con dos cristales hacia fuera.
		local arm = body.upperArm[side]
		local as = arm.size
		local top = as.Y / 2
		arm.oval(Vector3.new(as.X * 1.3, 0.55, as.Z * 1.3), SILVER_FUR, FABRIC, CFrame.new(side * 0.1, top + 0.02, 0))
		for _, z in { -0.2, 0.2 } do
			crystal(arm, Vector3.new(side * as.X * 0.5, top + 0.18, z * as.Z), Vector3.new(side * 0.7, 1, z), 0.5, 0.2)
		end
		-- Brazal añil con puño de pelaje plateado y un cristal por fuera.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, 0.04, fs.Y * 0.5, 0.08, MAGE_INDIGO, FABRIC)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, SILVER_FUR, FABRIC)
		crystal(forearm, Vector3.new(side * (fs.X / 2 + 0.04), 0.06, 0), Vector3.new(side, 0.6, 0), 0.32, 0.16)
		-- Faldón de pelaje plateado en el muslo con una runa.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), SILVER_FUR, FABRIC, flap)
		leg.block(Vector3.new(0.06, ls.Y * 0.26, 0.04), RUNE, NEON, flap * CFrame.new(0, 0, -0.07))
	end
end

-- ===================================== Médico =====================================

-- Frasco de pociones de "size" con la base en "at": panza de cristal con el líquido dentro, cuello y
-- tapón de corcho. "glow": el líquido brilla.
local function flask(make: Builder, at: CFrame, size: number, glow: boolean)
	-- Cristal muy transparente: si no, la poción no se ve y el frasco sale blanco.
	local belly = make.ball(size, FLASK_GLASS, GLASS, at * CFrame.new(0, size / 2, 0))
	belly.Transparency = 0.65
	make.ball(
		size * 0.78,
		if glow then HEAL_GLOW else POTION,
		if glow then NEON else SMOOTH,
		at * CFrame.new(0, size * 0.46, 0)
	)
	local neck = make.rod(size * 0.4, size * 0.34, FLASK_GLASS, GLASS, at * CFrame.new(0, size * 1.05, 0) * UPRIGHT)
	neck.Transparency = 0.65
	make.rod(size * 0.2, size * 0.38, CORK, WOOD, at * CFrame.new(0, size * 1.3, 0) * UPRIGHT)
end

-- Bolsita de cuero con su solapa y una hoja asomando, en "at" (mirando a su -Z).
local function herbPouch(make: Builder, at: CFrame, herb: Color3)
	make.block(Vector3.new(0.28, 0.26, 0.14), HUNTER_LEATHER, LEATHER_MATERIAL, at)
	make.block(Vector3.new(0.32, 0.1, 0.18), LEATHER_DARK, LEATHER_MATERIAL, at * CFrame.new(0, 0.12, 0))
	leaf(make, 0.34, herb, at * CFrame.new(0.06, 0.26, 0.02) * CFrame.Angles(0, math.pi, -0.3))
end

-- Tótem sanador pequeño para la espalda, como el de la definitiva del médico: dos caras talladas
-- mirando hacia atrás (+Z de "at", que es su base), alas del pájaro del trueno y una gema verde que
-- brilla arriba. A escala 1 mide 1,5 studs de alto.
local function backTotem(make: Builder, at: CFrame, scale: number)
	local function block(
		size: Vector3,
		color: Color3,
		material: Enum.Material,
		x: number,
		y: number,
		z: number,
		tilt: number?
	)
		make.block(
			size * scale,
			color,
			material,
			at * CFrame.new(x * scale, y * scale, z * scale) * CFrame.Angles(0, 0, tilt or 0)
		)
	end
	block(Vector3.new(0.46, 0.56, 0.38), TOTEM_WOOD, WOOD, 0, 0.28, 0)
	block(Vector3.new(0.5, 0.08, 0.42), TURQUOISE, SMOOTH, 0, 0.04, 0)
	block(Vector3.new(0.5, 0.08, 0.42), PAINT_RED, SMOOTH, 0, 0.6, 0)
	-- Primera cara: ojos grandes y boca roja.
	for side = -1, 1, 2 do
		block(Vector3.new(0.13, 0.09, 0.03), PAINT_WHITE, SMOOTH, side * 0.11, 0.38, 0.2)
		block(Vector3.new(0.06, 0.06, 0.03), PAINT_BLACK, SMOOTH, side * 0.11, 0.38, 0.215)
	end
	block(Vector3.new(0.26, 0.07, 0.03), PAINT_RED, SMOOTH, 0, 0.2, 0.2)
	-- Segunda cara, más clara: ojos en rombo; arriba, las alas abiertas con la punta pintada.
	block(Vector3.new(0.42, 0.5, 0.36), TOTEM_WOOD_LIGHT, WOOD, 0, 0.89, 0)
	for side = -1, 1, 2 do
		block(Vector3.new(0.12, 0.12, 0.03), PAINT_WHITE, SMOOTH, side * 0.1, 0.96, 0.19, math.rad(45))
		block(Vector3.new(0.06, 0.06, 0.03), PAINT_BLACK, SMOOTH, side * 0.1, 0.96, 0.205, math.rad(45))
		block(Vector3.new(0.36, 0.12, 0.08), TURQUOISE, SMOOTH, side * 0.36, 1.1, 0, side * math.rad(20))
		block(Vector3.new(0.12, 0.13, 0.09), PAINT_RED, SMOOTH, side * 0.51, 1.155, 0, side * math.rad(20))
	end
	-- La gema en su copa.
	block(Vector3.new(0.26, 0.1, 0.26), TOTEM_WOOD, WOOD, 0, 1.19, 0)
	make.ball(0.28 * scale, HEAL_GLOW, NEON, at * CFrame.new(0, 1.36 * scale, 0))
end

local function healerBandolier(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.06)
	local back = depth / 2 + 0.06
	-- Túnica de lino claro.
	make.block(Vector3.new(width + 0.1, height * 0.94, depth + 0.12), LINEN, FABRIC, CFrame.new(0, -height * 0.02, 0))
	-- Bandolera de cuero del hombro izquierdo a la cadera derecha, por delante y por detrás, con
	-- bolsitas de las que asoman hojas.
	local from = Vector3.new(-width * 0.3, height / 2 - 0.02, 0)
	local to = Vector3.new(width * 0.4, -height / 2 + 0.12, 0)
	for _, z in { front - 0.03, back + 0.03 } do
		strap(make, Vector3.new(from.X, from.Y, z), Vector3.new(to.X, to.Y, z), 0.16, LEATHER, LEATHER_MATERIAL)
	end
	for index, t in { 0.25, 0.5, 0.75 } do
		local at = from:Lerp(to, t)
		herbPouch(make, CFrame.new(at.X, at.Y - 0.1, front - 0.1), if index == 2 then LEAF_DARK else LEAF)
	end
	for _, t in { 0.22, 0.78 } do
		local at = from:Lerp(to, t)
		herbPouch(make, CFrame.new(at.X, at.Y - 0.1, back + 0.1) * CFrame.Angles(0, math.pi, 0), LEAF_DARK)
	end
	-- Detrás (lo que el jugador ve siempre): un manojo de hierbas abierto en abanico hacia arriba,
	-- atado a la bandolera en mitad de la espalda.
	local knot = from:Lerp(to, 0.5)
	local tie = CFrame.new(knot.X, knot.Y, back + 0.12)
	local herbs = 7
	for index = 0, herbs - 1 do
		local angle = -0.95 + index * 1.9 / (herbs - 1)
		local length = 1.05 - math.abs(angle) * 0.3
		leaf(
			make,
			length,
			if index % 2 == 0 then LEAF else LEAF_LIGHT,
			tie * CFrame.Angles(0, 0, -angle) * CFrame.new(0, length / 2 + 0.05, 0.01 * (index % 2))
		)
	end
	for index = -1, 1 do
		make.block(
			Vector3.new(0.04, 0.42, 0.04),
			LEAF_DARK,
			SMOOTH,
			tie * CFrame.Angles(0, 0, index * 0.25) * CFrame.new(0, -0.2, 0.03)
		)
	end
	make.ball(0.22, FIBER, FABRIC, tie * CFrame.new(0, 0, 0.04))

	-- Cinturón de fibra con un mortero de piedra y su mano de hueso en la cadera derecha.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.07)
	waist.block(Vector3.new(hipWidth + 0.12, 0.14, hipDepth + 0.12), FIBER, FABRIC, CFrame.new(0, 0.08, 0))
	local mortar = CFrame.new(-hipWidth * 0.32, -0.16, beltFront - 0.14)
	waist.rod(0.24, 0.36, STONE, SLATE, mortar * UPRIGHT)
	waist.rod(0.04, 0.27, SKULL_HOLE, SMOOTH, mortar * CFrame.new(0, 0.11, 0) * UPRIGHT)
	waist.rod(0.38, 0.08, BONE, SMOOTH, mortar * CFrame.new(0.06, 0.22, 0) * CFrame.Angles(0, 0, math.rad(70)))

	for side = -1, 1, 2 do
		-- Vendas de lino en los antebrazos y una hoja atada en cada brazo.
		local forearm = body.lowerArm[side]
		band(forearm, -forearm.size.Y * 0.18, 0.12, 0.06, PAINT_WHITE, FABRIC, 0.12)
		band(forearm, -forearm.size.Y * 0.36, 0.12, 0.06, PAINT_WHITE, FABRIC, -0.12)
		local arm = body.upperArm[side]
		band(arm, -arm.size.Y * 0.1, 0.1, 0.08, FIBER, FABRIC)
		leaf(
			arm,
			0.42,
			LEAF,
			CFrame.new(side * (arm.size.X / 2 + 0.05), -arm.size.Y * 0.1, 0)
				* CFrame.Angles(0, side * math.rad(90), 0)
				* CFrame.Angles(0, 0, math.pi + side * 0.4)
		)
	end
end

local function healerPlastron(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.06)
	local back = depth / 2 + 0.06
	make.block(Vector3.new(width + 0.1, height * 0.94, depth + 0.12), LINEN, FABRIC, CFrame.new(0, -height * 0.02, 0))
	-- Peto de hueso blanco sobre un borde más oscuro, sujeto con correas por encima de los hombros.
	local plate = CFrame.new(0, height * 0.06, front - 0.06)
	make.block(Vector3.new(width * 0.9, height * 0.78, 0.1), BONE_DARK, SMOOTH, plate)
	make.block(Vector3.new(width * 0.84, height * 0.72, 0.1), THICK_BONE, SMOOTH, plate * CFrame.new(0, 0.01, -0.04))
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.18, 0.08, depth + 0.24),
			LEATHER,
			LEATHER_MATERIAL,
			CFrame.new(side * width * 0.3, height / 2 + 0.02, 0)
		)
	end
	-- Cruz de hojas con una flor roja en el centro.
	local cross = plate * CFrame.new(0, height * 0.04, -0.1)
	for index = 0, 3 do
		leaf(
			make,
			0.42,
			if index % 2 == 0 then LEAF else LEAF_DARK,
			cross * CFrame.Angles(0, 0, index * math.pi / 2) * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, math.pi, 0)
		)
	end
	make.ball(0.18, FLOWER, SMOOTH, cross * CFrame.new(0, 0, -0.04))
	-- Detrás (lo que el jugador ve siempre): mochila de cuero en un bastidor de madera, con frascos de
	-- poción encima y a los lados y hierbas asomando por detrás de los frascos.
	local pack = CFrame.new(0, -height * 0.04, back + 0.26)
	make.block(Vector3.new(width * 0.62, height * 0.62, 0.42), HUNTER_LEATHER, LEATHER_MATERIAL, pack)
	make.block(
		Vector3.new(width * 0.64, height * 0.2, 0.46),
		HUNTER_LEATHER_DARK,
		LEATHER_MATERIAL,
		pack * CFrame.new(0, height * 0.22, 0.01)
	)
	make.block(Vector3.new(0.16, 0.14, 0.06), BONE, SMOOTH, pack * CFrame.new(0, height * 0.12, 0.24))
	for side = -1, 1, 2 do
		make.rod(
			height * 0.86,
			0.08,
			BARK,
			WOOD,
			pack * CFrame.new(side * width * 0.34, height * 0.04, -0.12) * UPRIGHT
		)
	end
	for _, y in { height * 0.4, -height * 0.32 } do
		make.rod(width * 0.76, 0.07, BARK, WOOD, pack * CFrame.new(0, y, -0.12))
	end
	local top = pack * CFrame.new(0, height * 0.32, 0)
	for index = -1, 1 do
		leaf(
			make,
			0.5,
			if index == 0 then LEAF_LIGHT else LEAF,
			top * CFrame.new(index * 0.2, 0.22, -0.12) * CFrame.Angles(0, 0, -index * 0.4)
		)
	end
	for index, x in { -0.32, 0, 0.32 } do
		flask(make, top * CFrame.new(x * width * 0.5, 0, 0.04), if index == 2 then 0.36 else 0.3, false)
	end
	for side = -1, 1, 2 do
		flask(make, pack * CFrame.new(side * (width * 0.31 + 0.13), -height * 0.16, 0.06), 0.28, false)
	end

	-- Cinturón de cuero con dos rollos de venda.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.08)
	waist.block(Vector3.new(hipWidth + 0.14, 0.2, hipDepth + 0.14), LEATHER, LEATHER_MATERIAL, CFrame.new(0, 0.06, 0))
	for _, x in { -0.32, 0.32 } do
		waist.rod(0.24, 0.22, PAINT_WHITE, FABRIC, CFrame.new(x * hipWidth, -0.06, beltFront - 0.1) * UPRIGHT)
	end

	for side = -1, 1, 2 do
		-- Hombrera de hueso con dos hojas por debajo.
		local arm = body.upperArm[side]
		local as = arm.size
		local top2 = as.Y / 2
		for index, tilt in { -0.35, 0.35 } do
			leaf(
				arm,
				0.46,
				if index == 1 then LEAF else LEAF_DARK,
				CFrame.new(side * (as.X / 2 + 0.03), top2 - 0.22, tilt * 0.6)
					* CFrame.Angles(0, side * math.rad(90), 0)
					* CFrame.Angles(0, 0, math.pi + tilt)
			)
		end
		arm.oval(
			Vector3.new(as.X * 1.08, 0.3, as.Z * 1.12),
			THICK_BONE,
			SMOOTH,
			CFrame.new(side * 0.06, top2 + 0.02, 0)
		)
		arm.oval(
			Vector3.new(as.X * 0.9, 0.24, as.Z * 0.96),
			BONE_DARK,
			SMOOTH,
			CFrame.new(side * 0.16, top2 - 0.14, 0) * CFrame.Angles(0, 0, -side * 0.35)
		)
		-- Vendas en el antebrazo.
		local forearm = body.lowerArm[side]
		band(forearm, -forearm.size.Y * 0.18, 0.12, 0.06, PAINT_WHITE, FABRIC, 0.12)
		band(forearm, -forearm.size.Y * 0.36, 0.12, 0.06, PAINT_WHITE, FABRIC, -0.12)
		-- Bolsa de cuero atada al muslo.
		local leg = body.upperLeg[side]
		local ls = leg.size
		band(leg, ls.Y * 0.2, 0.1, 0.06, LEATHER_DARK, LEATHER_MATERIAL)
		local bag = CFrame.new(side * (ls.X / 2 + 0.06), ls.Y * 0.08, 0)
		leg.block(Vector3.new(0.14, 0.34, 0.42), HUNTER_LEATHER, LEATHER_MATERIAL, bag)
		leg.block(Vector3.new(0.18, 0.12, 0.46), LEATHER_DARK, LEATHER_MATERIAL, bag * CFrame.new(0, 0.14, 0))
	end
end

local function silverHealer(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	local back = depth / 2
	make.block(Vector3.new(width + 0.12, height * 0.94, depth + 0.16), LINEN, FABRIC, CFrame.new(0, -height * 0.02, 0))
	-- Manto de pelaje plateado sobre los hombros y capa por la espalda con flecos.
	make.block(Vector3.new(width + 0.4, 0.34, depth + 0.4), SILVER_FUR, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.04))
	for side = -1, 1, 2 do
		make.ball(0.6, SILVER_FUR, FABRIC, CFrame.new(side * (width / 2 + 0.06), height / 2 - 0.1, 0))
	end
	local capeHeight = height * 1.08
	local capeY = height / 2 - capeHeight / 2 - 0.02
	make.block(Vector3.new(width * 1.02, capeHeight, 0.12), SILVER_FUR, FABRIC, CFrame.new(0, capeY, back + 0.16))
	local capeBottom = capeY - capeHeight / 2
	local tufts = 5
	for index = 0, tufts - 1 do
		local x = -width * 0.4 + index * width * 0.8 / (tufts - 1)
		make.fang(
			if index % 2 == 0 then 0.34 else 0.26,
			0.28,
			if index % 2 == 0 then SILVER_FUR else SILVER_FUR_DARK,
			FABRIC,
			CFrame.new(x + 0.14, capeBottom + 0.04, back + 0.34) * CFrame.Angles(0, 0, math.pi)
		)
	end
	-- Detrás (lo que el jugador ve siempre): tótem sanador pequeño atado a la capa, con su gema verde
	-- brillando por encima de los hombros, hojas en la base y un frasco brillante a cada lado.
	local totemBase = CFrame.new(0, -height * 0.3, back + 0.42)
	-- (A escala 1 se quedaba bajo los hombros.)
	local totemScale = 1.25
	backTotem(make, totemBase, totemScale)
	make.block(
		Vector3.new(0.56, 0.1, 0.46) * totemScale,
		LEATHER_DARK,
		LEATHER_MATERIAL,
		totemBase * CFrame.new(0, 0.7 * totemScale, 0)
	)
	for index, angle in { -1.1, -0.45, 0.45, 1.1 } do
		leaf(
			make,
			0.6,
			if index % 2 == 0 then LEAF_DARK else LEAF,
			totemBase * CFrame.new(0, 0.12, -0.1) * CFrame.Angles(0, 0, -angle) * CFrame.new(0, 0.32, 0)
		)
	end
	for side = -1, 1, 2 do
		local cord = CFrame.new(side * width * 0.36, height * 0.22, back + 0.26)
		make.block(Vector3.new(0.04, 0.3, 0.04), FIBER, FABRIC, cord)
		flask(make, cord * CFrame.new(0, -0.62, 0.02), 0.26, true)
	end
	-- Bandolera del hombro derecho a la cadera izquierda con tres frascos que brillan colgando.
	local from = Vector3.new(width * 0.3, height / 2 - 0.02, front - 0.03)
	local to = Vector3.new(-width * 0.4, -height / 2 + 0.12, front - 0.03)
	strap(make, from, to, 0.16, LEATHER_DARK, LEATHER_MATERIAL)
	for _, t in { 0.3, 0.52, 0.74 } do
		local at = from:Lerp(to, t)
		flask(make, CFrame.new(at.X, at.Y - 0.32, at.Z - 0.1), 0.22, true)
	end
	-- Broche de plata con una gema verde que cierra el manto.
	local brooch = CFrame.new(-width * 0.22, height / 2 - 0.16, front - 0.1)
	local rim = make.rod(0.06, 0.32, SILVER, METAL, brooch * FACING)
	rim.Reflectance = 0.35
	make.ball(0.18, HEAL_GLOW, NEON, brooch * CFrame.new(0, 0, -0.05))

	-- Cinturón oscuro con hebilla de plata y un rollo de venda.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	waist.block(
		Vector3.new(hipWidth + 0.16, 0.22, hipDepth + 0.18),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, 0.06, 0)
	)
	local buckle = waist.block(Vector3.new(0.34, 0.26, 0.08), SILVER, METAL, CFrame.new(0, 0.06, beltFront - 0.02))
	buckle.Reflectance = 0.35
	waist.rod(0.24, 0.22, PAINT_WHITE, FABRIC, CFrame.new(hipWidth * 0.32, -0.06, beltFront - 0.1) * UPRIGHT)

	for side = -1, 1, 2 do
		-- Hombros de pelaje plateado con dos hojas por debajo.
		local arm = body.upperArm[side]
		local as = arm.size
		local top = as.Y / 2
		for index, tilt in { -0.35, 0.35 } do
			leaf(
				arm,
				0.5,
				if index == 1 then LEAF else LEAF_DARK,
				CFrame.new(side * (as.X / 2 + 0.04), top - 0.3, tilt * 0.6)
					* CFrame.Angles(0, side * math.rad(90), 0)
					* CFrame.Angles(0, 0, math.pi + tilt)
			)
		end
		arm.oval(Vector3.new(as.X * 1.3, 0.55, as.Z * 1.3), SILVER_FUR, FABRIC, CFrame.new(side * 0.1, top + 0.02, 0))
		-- Venda y puño de pelaje plateado en el antebrazo.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, fs.Y * 0.05, 0.12, 0.06, PAINT_WHITE, FABRIC, 0.12)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, SILVER_FUR, FABRIC)
		-- Faldón de pelaje plateado en el muslo con una hoja.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), SILVER_FUR, FABRIC, flap)
		leaf(
			leg,
			0.46,
			LEAF,
			flap * CFrame.new(side * 0.1, -0.05, -0.07) * CFrame.Angles(0, math.pi, math.pi + side * 0.3)
		)
	end
end

-- ===================================== Armadura volcánica =====================================
-- Forja volcánica (Fase 9, G5): basalto y obsidiana con grietas de lava que brillan. Es el nivel más
-- alto, así que lleva más detalle que ninguna: hombreras con cristales de obsidiana hundidos en lava,
-- gotas de lava colgando y humo que sale de un respiradero entre los cristales; frentes con placas
-- bordeadas de lava, y detrás un motivo de fuego que se reconoce de lejos. Cada rol guarda su silueta
-- (coraza, capa con carcaj, túnica, manto con mochila). La obsidiana es SmoothPlastic casi sin reflejo:
-- con Glass o con reflejo coge el azul del cielo y se ve lila.

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SMOKE = Color3.fromRGB(70, 66, 64)

-- Esquirla de obsidiana de "length" que sale de "base" hacia "direction" (nunca vertical del todo:
-- CFrame.lookAt no sabe girar alrededor de Y).
local function obsidianShard(make: Builder, base: Vector3, direction: Vector3, length: number, width: number)
	local at = CFrame.lookAt(base, base + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	local shard = make.fang(length, width, OBSIDIAN, SMOOTH, at)
	shard.Reflectance = 0.05
	return at
end

-- Cristal de obsidiana bañado en lava: la esquirla negra sale de un cono de lava (con "dip" 1, se ve
-- hasta un cuarto de su alto; menos, más bajo). Sin brillo de neón encima: aunque sea translúcido,
-- tiñe de cobre toda la obsidiana.
local function lavaShard(make: Builder, base: Vector3, direction: Vector3, length: number, width: number, dip: number?)
	local at = obsidianShard(make, base, direction, length, width)
	-- Centradas en la misma base: la pirámide de "width" ocupa de 0 a width en X y de -width a 0 en Z.
	local amount = dip or 1
	local scale = 1 + 0.4 * amount
	local grow = width * (scale - 1) / 2
	make.fang(length * 0.55 * amount, width * scale, MAGMA, NEON, at * CFrame.new(-grow, 0, grow))
end

-- Cristal de lava o de azufre: funda translúcida con un núcleo de neón que brilla.
local function fireCrystal(
	make: Builder,
	base: Vector3,
	direction: Vector3,
	length: number,
	width: number,
	shell: Color3,
	core: Color3
)
	local at = CFrame.lookAt(base, base + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	local case = make.fang(length, width, shell, GLASS, at)
	case.Transparency = 0.25
	make.fang(length * 0.75, width * 0.5, core, NEON, at * CFrame.new(width * 0.25, 0, -width * 0.25))
end

-- Grieta de lava en zigzag por los puntos de "points" (nunca dos seguidos uno encima del otro).
local function lavaVein(make: Builder, points: { Vector3 }, thickness: number, color: Color3?)
	for index = 1, #points - 1 do
		strap(make, points[index], points[index + 1], thickness, color or MAGMA, NEON)
	end
end

-- Gota de lava que cuelga de "at" (su base), de "length" de largo.
local function lavaDrip(make: Builder, at: CFrame, length: number)
	local width = length * 0.45
	make.fang(length, width, MAGMA, NEON, at * CFrame.new(width / 2, 0, width / 2) * CFrame.Angles(0, 0, math.pi))
end

-- Luz suave del color de la lava o del azufre, para que la armadura se vea de noche.
local function fireLight(part: BasePart, color: Color3)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 7
	light.Brightness = 1.2
	light.Parent = part
end

-- Chispas que suben despacio (del cráter de la espalda, del bajo de la capa…).
local function embers(part: BasePart, color: Color3, rate: number)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(color, MAGMA)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new(0.1, 1)
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Rate = rate
	sparks.Speed = NumberRange.new(1, 2.5)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(0, 1.5, 0)
	sparks.Parent = part
end

-- Humo que sube de "part" y se abre al subir (los respiraderos de los hombros, el cráter…).
local function smoke(part: BasePart, rate: number, color: Color3?, size: number?)
	local scale = size or 1
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = SMOKE_TEXTURE
	puff.Color = ColorSequence.new(color or SMOKE, Color3.fromRGB(150, 145, 140))
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3 * scale),
		NumberSequenceKeypoint.new(1, 1.4 * scale),
	})
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	puff.Lifetime = NumberRange.new(1.4, 2.2)
	puff.Rate = rate
	puff.Speed = NumberRange.new(0.6, 1.4)
	puff.SpreadAngle = Vector2.new(20, 20)
	puff.Acceleration = Vector3.new(0, 1.2, 0)
	puff.Rotation = NumberRange.new(0, 360)
	puff.RotSpeed = NumberRange.new(-30, 30)
	puff.Parent = part
end

-- Hombrera volcánica: base de "pad", dos láminas de obsidiana con el borde de lava, un racimo de
-- "shards" cristales de obsidiana hundidos en lava (el del centro de "length"), tres gotas de lava
-- colgando del borde de fuera y un respiradero que echa humo y chispas entre los cristales.
local function volcanicPauldron(
	arm: Builder,
	side: number,
	pad: Color3,
	padMaterial: Enum.Material,
	shards: number,
	length: number
)
	local as = arm.size
	local top = as.Y / 2
	arm.oval(Vector3.new(as.X * 1.4, 0.62, as.Z * 1.4), pad, padMaterial, CFrame.new(side * 0.12, top + 0.04, 0))
	for index = 0, 1 do
		local lame = CFrame.new(side * (0.18 + index * 0.12), top - 0.1 - index * 0.2, 0)
			* CFrame.Angles(0, 0, -side * (0.35 + index * 0.22))
		arm.oval(
			Vector3.new(as.X * 1.12 + 0.14, 0.12, as.Z * 1.38 - index * 0.1 + 0.06),
			MAGMA,
			NEON,
			lame * CFrame.new(0, -0.06, 0)
		)
		arm.oval(Vector3.new(as.X * 1.12, 0.24, as.Z * 1.38 - index * 0.1), OBSIDIAN, SMOOTH, lame)
	end
	for index = 1, shards do
		local z = if shards == 1 then 0 else (index - 1) / (shards - 1) * 0.6 - 0.3
		local center = math.abs(z) < 0.01
		lavaShard(
			arm,
			Vector3.new(side * as.X * 0.3, top + 0.22, z * as.Z),
			Vector3.new(side * (if center then 0.5 else 0.8), 1, z * 0.9),
			if center then length else length * 0.72,
			if center then 0.3 else 0.24
		)
	end
	for _, z in { -0.3, 0, 0.3 } do
		lavaDrip(arm, CFrame.new(side * (as.X * 0.72 + 0.08), top - 0.22, z * as.Z), 0.2 + math.abs(z) * 0.2)
	end
	local vent = arm.ball(0.2, EMBER, NEON, CFrame.new(side * as.X * 0.12, top + 0.3, 0))
	smoke(vent, 4)
	embers(vent, EMBER, 2)
	fireLight(vent, MAGMA)
end

-- Faldón del muslo de "color" con una placa de obsidiana bordeada de lava y una gota colgando.
local function volcanicFlap(leg: Builder, side: number, color: Color3, material: Enum.Material)
	local ls = leg.size
	local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
	leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.44, 0.1), color, material, flap)
	leg.block(Vector3.new(ls.X * 0.66, ls.Y * 0.3, 0.06), MAGMA, NEON, flap * CFrame.new(0, 0.02, -0.06))
	leg.block(Vector3.new(ls.X * 0.58, ls.Y * 0.24, 0.08), OBSIDIAN, SMOOTH, flap * CFrame.new(0, 0.02, -0.09))
	lavaDrip(leg, flap * CFrame.new(0, -ls.Y * 0.22, -0.06), 0.2)
end

-- Placa de obsidiana de "size" con un contorno de lava que asoma por detrás (en "at", mirando a -Z).
local function lavaPlate(make: Builder, size: Vector3, at: CFrame)
	make.block(size + Vector3.new(0.08, 0.08, -0.04), MAGMA, NEON, at * CFrame.new(0, 0, 0.03))
	return make.block(size, OBSIDIAN, SMOOTH, at)
end

-- Guerrero. Delante: coraza de basalto con gorguera de esquirlas, pectorales de obsidiana con el
-- contorno de lava, corazón de magma sujeto por cuatro garras de obsidiana, vientre de placas con
-- costuras de lava, una grieta del cuello al vientre y una hebilla en forma de máscara de ojos de
-- lava con dos cuernos. Detrás: placa de ceniza con marco de obsidiana y un volcán en cinco escalones
-- que sobresalen cada vez más, con rocas en las laderas, ríos de lava en cada escalón, un lago de lava
-- al pie, cráter con una fuente de lava, bombas de lava, humo y chispas, bajo una corona de cinco
-- cristales de obsidiana bañados en lava que asoma por encima de los hombros.
local function volcanicArmor(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.09)
	local back = depth / 2
	make.block(
		Vector3.new(width + 0.14, height * 0.94, depth + 0.2),
		BASALT,
		BASALT_MATERIAL,
		CFrame.new(0, -height * 0.02, 0)
	)
	-- Gorguera: esquirlas de obsidiana alrededor del cuello, más altas por detrás.
	for index = 0, 6 do
		local angle = math.rad(-150 + index * 50)
		obsidianShard(
			make,
			Vector3.new(math.sin(angle) * width * 0.3, height / 2 - 0.04, -math.cos(angle) * depth * 0.42),
			Vector3.new(math.sin(angle) * 0.35, 1, -math.cos(angle) * 0.35),
			if index == 3 then 0.3 else 0.38,
			0.2
		)
	end
	for side = -1, 1, 2 do
		local pec = CFrame.new(side * (width * 0.23 + 0.02), height * 0.2, front - 0.07)
			* CFrame.Angles(0.1, -side * 0.1, 0)
		lavaPlate(make, Vector3.new(width * 0.4, height * 0.28, 0.1), pec)
		make.block(
			Vector3.new(width * 0.1, height * 0.18, 0.04),
			OBSIDIAN_SHEEN,
			SMOOTH,
			pec * CFrame.new(-side * width * 0.1, 0.02, -0.06)
		)
		make.ball(0.1, BASALT, BASALT_MATERIAL, pec * CFrame.new(side * width * 0.14, -height * 0.09, -0.06))
		-- Vientre: tres placas de basalto oscuro por lado, con costuras de lava entre ellas.
		for row = 0, 2 do
			local plateWidth = width * (0.2 - row * 0.015)
			local plate = CFrame.new(side * (plateWidth / 2 + 0.04), -height * (0.06 + row * 0.15), front - 0.04)
			make.block(
				Vector3.new(plateWidth + 0.04, height * 0.13 + 0.04, 0.06),
				MAGMA,
				NEON,
				plate * CFrame.new(0, 0, 0.03)
			)
			make.block(Vector3.new(plateWidth, height * 0.13, 0.1), BASALT_DARK, BASALT_MATERIAL, plate)
		end
	end
	lavaVein(make, {
		Vector3.new(-0.03, height * 0.42, front - 0.06),
		Vector3.new(0.05, height * 0.33, front - 0.06),
		Vector3.new(-0.04, height * 0.06, front - 0.06),
	}, 0.08)
	-- Corazón de magma en un aro de obsidiana, sujeto por cuatro garras.
	local core = CFrame.new(0, height * 0.2, front - 0.22)
	local rim = make.rod(0.1, 0.62, OBSIDIAN, SMOOTH, core * FACING)
	rim.Reflectance = 0.05
	local heart = make.ball(0.4, MAGMA, NEON, core * CFrame.new(0, 0, -0.07))
	fireLight(heart, MAGMA)
	embers(heart, EMBER, 2)
	for index = 0, 3 do
		local angle = index * math.pi / 2 + math.pi / 4
		local out = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local base = (core * CFrame.new(out * 0.36)).Position
		obsidianShard(make, base, Vector3.new(-out.X * 0.6, -out.Y * 0.6, -1), 0.28, 0.14)
	end

	-- Espalda: placa de ceniza clara (sobre basalto oscuro el volcán negro no se distinguía) con marco
	-- de obsidiana.
	local plateZ = back + 0.17
	make.block(
		Vector3.new(width * 0.98, height * 0.98, 0.14),
		ASH,
		BASALT_MATERIAL,
		CFrame.new(0, -height * 0.02, plateZ)
	)
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.12, height * 0.98, 0.2),
			OBSIDIAN,
			SMOOTH,
			CFrame.new(side * width * 0.49, -height * 0.02, plateZ + 0.03)
		)
	end
	make.block(
		Vector3.new(width * 0.98 + 0.12, 0.12, 0.2),
		OBSIDIAN,
		SMOOTH,
		CFrame.new(0, -height * 0.51, plateZ + 0.03)
	)
	-- Volcán: cinco escalones que se estrechan y sobresalen más cuanto más altos (relieve).
	local tiers = 5
	local tierHeight = height * 0.16
	local baseY = -height * 0.48
	local function tierFront(tier: number): number
		return plateZ + 0.1 + tier * 0.02 + (0.14 + tier * 0.03) / 2
	end
	for tier = 1, tiers do
		local tierWidth = width * (0.94 - (tier - 1) * 0.16)
		make.block(
			Vector3.new(tierWidth, tierHeight, 0.14 + tier * 0.03),
			if tier % 2 == 0 then BASALT_DARK else OBSIDIAN,
			SMOOTH,
			CFrame.new(0, baseY + (tier - 0.5) * tierHeight, plateZ + 0.1 + tier * 0.02)
		)
		-- Una roca de basalto en el borde del escalón, a un lado y al otro según el escalón.
		if tier < tiers then
			local side = if tier % 2 == 0 then 1 else -1
			make.block(
				Vector3.new(0.2, 0.13, 0.12),
				ASH_DARK,
				BASALT_MATERIAL,
				CFrame.new(side * (tierWidth / 2 - 0.12), baseY + tier * tierHeight + 0.02, tierFront(tier) - 0.04)
					* CFrame.Angles(0.2, 0.3, side * 0.25)
			)
		end
		-- Ríos de lava: uno central en cada escalón y dos a los lados en los tres de abajo.
		local z = tierFront(tier) + 0.02
		local function rowY(t: number): number
			return baseY + (tier - 1 + t) * tierHeight
		end
		local sway = if tier % 2 == 0 then 1 else -1
		strap(make, Vector3.new(sway * 0.05, rowY(0.97), z), Vector3.new(-sway * 0.05, rowY(0.03), z), 0.1, MAGMA, NEON)
		if tier <= 3 then
			for side = -1, 1, 2 do
				local x = side * width * (0.14 + (3 - tier) * 0.08)
				strap(
					make,
					Vector3.new(x - side * 0.04, rowY(0.95), z),
					Vector3.new(x + side * 0.05, rowY(0.05), z),
					0.08,
					MAGMA,
					NEON
				)
			end
		end
	end
	-- Lago de lava al pie del volcán.
	make.block(Vector3.new(width * 0.86, 0.07, 0.06), MAGMA, NEON, CFrame.new(0, baseY + 0.04, tierFront(1) + 0.02))
	-- Cráter: lago de lava entre dos labios de obsidiana, una fuente de lava, bombas en el aire, humo y
	-- chispas.
	local craterY = baseY + tiers * tierHeight
	local craterZ = plateZ + 0.1 + tiers * 0.02
	local crater = make.block(Vector3.new(width * 0.22, 0.08, 0.2), MAGMA, NEON, CFrame.new(0, craterY, craterZ))
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.09, 0.16, 0.24),
			OBSIDIAN,
			SMOOTH,
			CFrame.new(side * width * 0.135, craterY + 0.05, craterZ)
		)
	end
	make.fang(0.34, 0.14, EMBER, NEON, CFrame.new(0.07, craterY + 0.02, craterZ - 0.07))
	for index, bomb in { Vector3.new(-0.16, 0.42, 0), Vector3.new(0.12, 0.55, 0.04), Vector3.new(0.24, 0.3, -0.02) } do
		make.ball(if index == 2 then 0.1 else 0.08, MAGMA, NEON, CFrame.new(bomb.X, craterY + bomb.Y, craterZ + bomb.Z))
	end
	smoke(crater, 6, nil, 1.3)
	embers(crater, EMBER, 8)
	fireLight(crater, MAGMA)
	for index, angle in { -0.75, -0.38, 0, 0.38, 0.75 } do
		lavaShard(
			make,
			Vector3.new(math.sin(angle) * width * 0.4, height * 0.47, plateZ + 0.04),
			Vector3.new(math.sin(angle) * 0.9, 1, 0.45),
			if index == 3 then 1.2 else 0.95 - math.abs(angle) * 0.35,
			0.4,
			0.5
		)
	end

	-- Cinturón de basalto con una hebilla de máscara de obsidiana: ojos de lava y dos cuernos.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	waist.block(
		Vector3.new(hipWidth + 0.16, 0.28, hipDepth + 0.18),
		BASALT_DARK,
		BASALT_MATERIAL,
		CFrame.new(0, 0.06, 0)
	)
	local mask = CFrame.new(0, 0.06, beltFront - 0.05)
	waist.block(Vector3.new(0.5, 0.38, 0.1), OBSIDIAN, SMOOTH, mask)
	for side = -1, 1, 2 do
		waist.block(
			Vector3.new(0.13, 0.05, 0.04),
			MAGMA,
			NEON,
			mask * CFrame.new(side * 0.11, 0.05, -0.06) * CFrame.Angles(0, 0, side * 0.3)
		)
		obsidianShard(waist, (mask * CFrame.new(side * 0.2, 0.15, 0)).Position, Vector3.new(side, 1, -0.2), 0.24, 0.1)
	end
	waist.block(Vector3.new(0.2, 0.04, 0.04), MAGMA, NEON, mask * CFrame.new(0, -0.1, -0.06))

	for side = -1, 1, 2 do
		volcanicPauldron(body.upperArm[side], side, BASALT, BASALT_MATERIAL, 3, 0.8)
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, 0.05, fs.Y * 0.6, 0.1, BASALT, BASALT_MATERIAL)
		band(forearm, fs.Y * 0.32, 0.06, 0.14, MAGMA, NEON)
		band(forearm, -fs.Y / 2 + 0.12, 0.12, 0.14, OBSIDIAN, SMOOTH)
		lavaVein(forearm, {
			Vector3.new(side * (fs.X / 2 + 0.06), fs.Y * 0.22, -fs.Z * 0.25),
			Vector3.new(side * (fs.X / 2 + 0.06), 0, fs.Z * 0.1),
			Vector3.new(side * (fs.X / 2 + 0.06), -fs.Y * 0.2, -fs.Z * 0.15),
		}, 0.06)
		lavaShard(forearm, Vector3.new(side * (fs.X / 2), 0.05, 0.1), Vector3.new(side, 0.4, 0.5), 0.42, 0.2)
		volcanicFlap(body.upperLeg[side], side, BASALT, BASALT_MATERIAL)
	end
end

-- Cazador. Delante: jubón de cuero oscuro con correas cruzadas tachonadas de obsidiana, una grieta de
-- lava, collar de tres puntas de flecha de obsidiana bañadas en lava, broche con una gota de lava,
-- cinturón con zurrón y un cuchillo de obsidiana. Detrás: capa de ceniza con tres zarpazos de lava, el
-- bajo de brasas que echa chispas, abanico de hojas quemadas, capucha forrada de brasa y el carcaj de
-- obsidiana con aros de lava, dos cristales bañados en lava y flechas de plumas de fuego que arden.
local function emberCloak(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	local back = depth / 2
	make.block(
		Vector3.new(width + 0.12, height * 0.92, depth + 0.14),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, -height * 0.02, 0)
	)
	quiverStrap(make, front - 0.04, 0.14, BASALT_DARK, LEATHER_MATERIAL)
	local crossFrom = Vector3.new(-width * 0.3, height / 2 - 0.02, front - 0.02)
	local crossTo = Vector3.new(width * 0.4, -height / 2 + 0.12, front - 0.02)
	strap(make, crossFrom, crossTo, 0.14, BASALT_DARK, LEATHER_MATERIAL)
	for _, t in { 0.25, 0.5, 0.75 } do
		local stud = crossFrom:Lerp(crossTo, t)
		make.ball(0.12, OBSIDIAN, SMOOTH, CFrame.new(stud.X, stud.Y, stud.Z - 0.08))
	end
	lavaVein(make, {
		Vector3.new(-width * 0.34, height * 0.1, front - 0.02),
		Vector3.new(-width * 0.18, -height * 0.08, front - 0.02),
		Vector3.new(-width * 0.26, -height * 0.32, front - 0.02),
	}, 0.07)
	-- Collar: cordón en V con tres puntas de flecha de obsidiana bañadas en lava.
	local neckLeft = Vector3.new(-width * 0.2, height / 2 - 0.08, front - 0.06)
	local neckRight = Vector3.new(width * 0.2, height / 2 - 0.08, front - 0.06)
	local bottom = Vector3.new(0, height * 0.18, front - 0.1)
	strap(make, neckLeft, bottom, 0.04, FIBER, FABRIC)
	strap(make, bottom, neckRight, 0.04, FIBER, FABRIC)
	for index, spot in { neckLeft:Lerp(bottom, 0.7), bottom, neckRight:Lerp(bottom, 0.7) } do
		lavaShard(make, spot + Vector3.new(0, -0.02, -0.02), Vector3.new((index - 2) * 0.2, -1, -0.15), 0.26, 0.12)
	end
	-- Manto de ceniza sobre los hombros con un ribete de brasa delante.
	make.block(Vector3.new(width + 0.4, 0.34, depth + 0.4), ASH, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.04))
	make.block(Vector3.new(width + 0.42, 0.06, 0.08), MAGMA, NEON, CFrame.new(0, height / 2 - 0.21, -depth / 2 - 0.17))
	local brooch = CFrame.new(0, height / 2 - 0.18, front - 0.14)
	local disc = make.rod(0.06, 0.34, OBSIDIAN, SMOOTH, brooch * FACING)
	disc.Reflectance = 0.05
	make.ball(0.16, MAGMA, NEON, brooch * CFrame.new(0, 0, -0.05))

	-- Espalda: capa de ceniza con el bajo de brasas, tres zarpazos de lava y el abanico de hojas quemadas.
	local capeHeight = height * 1.08
	local capeY = height / 2 - capeHeight / 2 - 0.02
	local capeZ = back + 0.16
	make.block(Vector3.new(width * 1.02, capeHeight, 0.12), ASH_DARK, FABRIC, CFrame.new(0, capeY, capeZ))
	local capeBottom = capeY - capeHeight / 2
	local hem =
		make.block(Vector3.new(width * 1.02, 0.1, 0.14), MAGMA, NEON, CFrame.new(0, capeBottom + 0.05, capeZ + 0.01))
	embers(hem, EMBER, 4)
	local tufts = 5
	for index = 0, tufts - 1 do
		local x = -width * 0.4 + index * width * 0.8 / (tufts - 1)
		make.fang(
			if index % 2 == 0 then 0.36 else 0.26,
			0.3,
			if index % 2 == 0 then MAGMA else EMBER,
			NEON,
			CFrame.new(x + 0.15, capeBottom + 0.02, capeZ + 0.2) * CFrame.Angles(0, 0, math.pi)
		)
	end
	for index = -1, 1 do
		local x = -width * 0.22 + index * 0.14
		strap(
			make,
			Vector3.new(x - 0.12, -height * 0.02, capeZ + 0.07),
			Vector3.new(x + 0.16, -height * 0.42, capeZ + 0.07),
			0.07,
			MAGMA,
			NEON
		)
	end
	leafFan(make, 9, 1.25, 1.3, { CHARRED_LEAF, BASALT_DARK }, 0.25)
	loweredHood(make, ASH, EMBER, FABRIC)
	local quiverAt = backQuiver(make, {
		length = 1.9,
		radius = 0.27,
		color = OBSIDIAN,
		material = SMOOTH,
		rim = MAGMA,
		rimMaterial = NEON,
		arrows = 7,
		feathers = { MAGMA, EMBER },
	}, 0.32)
	local midBand = make.rod(0.1, 0.6, MAGMA, NEON, quiverAt * UPRIGHT)
	fireLight(midBand, MAGMA)
	for _, y in { 0.45, -0.45 } do
		make.rod(0.05, 0.58, MAGMA, NEON, quiverAt * CFrame.new(0, y, 0) * UPRIGHT)
	end
	for side = -1, 1, 2 do
		lavaShard(
			make,
			(quiverAt * CFrame.new(side * 0.22, -0.25, 0.12)).Position,
			quiverAt:VectorToWorldSpace(Vector3.new(side * 0.8, -0.6, 0.4)),
			0.34,
			0.15
		)
	end
	-- Las flechas arden: llamitas y chispas en la boca del carcaj.
	local mouthFire = make.ball(0.16, EMBER, NEON, quiverAt * CFrame.new(0, 1.05, 0))
	local flames = Instance.new("Fire")
	flames.Color = MAGMA
	flames.SecondaryColor = EMBER
	flames.Size = 1.2
	flames.Heat = 3
	flames.Parent = mouthFire
	embers(mouthFire, EMBER, 4)

	-- Cinturón de basalto con hebilla de obsidiana, zurrón de ceniza y un cuchillo de obsidiana.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	waist.block(
		Vector3.new(hipWidth + 0.16, 0.24, hipDepth + 0.18),
		BASALT_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, 0.06, 0)
	)
	waist.block(Vector3.new(0.36, 0.28, 0.08), OBSIDIAN, SMOOTH, CFrame.new(0, 0.06, beltFront - 0.02))
	waist.block(Vector3.new(0.22, 0.05, 0.04), MAGMA, NEON, CFrame.new(0, 0.06, beltFront - 0.07))
	local pouch = CFrame.new(hipWidth * 0.3, -0.12, beltFront - 0.06)
	waist.block(Vector3.new(0.38, 0.34, 0.14), LEATHER_DARK, LEATHER_MATERIAL, pouch)
	waist.block(Vector3.new(0.42, 0.14, 0.18), ASH, FABRIC, pouch * CFrame.new(0, 0.13, -0.01))
	local knife = CFrame.new(-hipWidth * 0.34, -0.05, beltFront - 0.04) * CFrame.Angles(0, 0, 0.25)
	waist.block(Vector3.new(0.1, 0.24, 0.1), LEATHER, LEATHER_MATERIAL, knife)
	obsidianShard(
		waist,
		(knife * CFrame.new(0, -0.12, 0)).Position,
		knife:VectorToWorldSpace(Vector3.new(0, -1, -0.05)),
		0.4,
		0.12
	)

	for side = -1, 1, 2 do
		volcanicPauldron(body.upperArm[side], side, ASH, FABRIC, 2, 0.6)
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, 0.04, fs.Y * 0.55, 0.08, LEATHER_DARK, LEATHER_MATERIAL)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, ASH, FABRIC)
		band(forearm, -fs.Y / 2 + 0.26, 0.05, 0.18, MAGMA, NEON)
		if side == 1 then
			forearm.block(
				Vector3.new(0.12, fs.Y * 0.55, fs.Z * 0.7),
				OBSIDIAN,
				SMOOTH,
				CFrame.new(fs.X / 2 + 0.08, 0.04, 0)
			)
			forearm.block(Vector3.new(0.06, fs.Y * 0.4, 0.06), MAGMA, NEON, CFrame.new(fs.X / 2 + 0.15, 0.04, 0))
		end
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), ASH_DARK, FABRIC, flap)
		leg.block(Vector3.new(ls.X * 0.9, 0.06, 0.12), MAGMA, NEON, flap * CFrame.new(0, -ls.Y * 0.19, -0.01))
		leaf(
			leg,
			0.48,
			CHARRED_LEAF,
			flap * CFrame.new(side * 0.1, -0.05, -0.07) * CFrame.Angles(0, math.pi, math.pi + side * 0.3)
		)
	end
end

-- Mago. Delante: túnica rojo lava con una pechera oscura ribeteada de lava, una runa de lava (triángulo
-- dentro de un círculo) con una brasa en el centro, cuello alto de esquirlas, dos amuletos de
-- obsidiana colgando y faja de basalto con un cristal de lava. Detrás: un sol negro, un disco de
-- obsidiana dentro de dos anillos de fuego con llamas, seis rayos de obsidiana bañados en lava, dos
-- talismanes colgando y una corona de cinco cristales de lava que asoma por encima de los hombros.
local function lavaRobe(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.09)
	local back = depth / 2
	make.block(
		Vector3.new(width + 0.12, height * 0.96, depth + 0.16),
		LAVA_ROBE,
		FABRIC,
		CFrame.new(0, -height * 0.02, 0)
	)
	make.block(
		Vector3.new(width * 0.5, height * 0.86, 0.08),
		LAVA_ROBE_DARK,
		FABRIC,
		CFrame.new(0, -height * 0.04, front - 0.02)
	)
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.05, height * 0.86, 0.05),
			MAGMA,
			NEON,
			CFrame.new(side * width * 0.26, -height * 0.04, front - 0.05)
		)
	end
	local runeAt = CFrame.new(0, height * 0.12, front - 0.08)
	hoop(make, runeAt, width * 0.17, 10, 0.05, MAGMA, NEON)
	local rune = {
		Vector3.new(-width * 0.13, -height * 0.07),
		Vector3.new(0.01, height * 0.13),
		Vector3.new(width * 0.13, -height * 0.07),
	}
	for index = 1, 3 do
		local a, b = rune[index], rune[index % 3 + 1]
		strap(make, (runeAt * CFrame.new(a)).Position, (runeAt * CFrame.new(b)).Position, 0.05, EMBER, NEON)
	end
	local runeHeart = make.ball(0.12, EMBER, NEON, runeAt * CFrame.new(0, 0, -0.02))
	fireLight(runeHeart, MAGMA)
	-- Cuello alto de esquirlas, de un hombro a otro por detrás de la nuca.
	for index = 0, 4 do
		local angle = math.rad(-80 + index * 40)
		obsidianShard(
			make,
			Vector3.new(math.sin(angle) * width * 0.4, height / 2 - 0.05, math.cos(angle) * depth * 0.45 + 0.05),
			Vector3.new(math.sin(angle) * 0.4, 1, math.cos(angle) * 0.4 + 0.1),
			0.45,
			0.24
		)
	end
	-- Dos amuletos de obsidiana con una gota de lava, colgando de cordones.
	for side = -1, 1, 2 do
		local from = Vector3.new(side * width * 0.36, height / 2 - 0.06, front - 0.06)
		local to = Vector3.new(side * width * 0.38, height * 0.02, front - 0.1)
		strap(make, from, to, 0.03, FIBER, FABRIC)
		make.block(Vector3.new(0.14, 0.2, 0.06), OBSIDIAN, SMOOTH, CFrame.new(to.X, to.Y - 0.1, to.Z))
		make.ball(0.07, MAGMA, NEON, CFrame.new(to.X, to.Y - 0.1, to.Z - 0.04))
	end

	-- Espalda: sol negro con anillos de fuego.
	local ringAt = CFrame.new(0, height * 0.12, back + 0.2)
	make.block(
		Vector3.new(width * 0.96, height * 1.02, 0.12),
		LAVA_ROBE_DARK,
		FABRIC,
		CFrame.new(0, -height * 0.06, back + 0.12)
	)
	hoop(make, ringAt, width * 0.38, 14, 0.12, MAGMA, NEON)
	hoop(make, ringAt * CFrame.new(0, 0, 0.02), width * 0.26, 10, 0.07, EMBER, NEON)
	local disc = make.rod(0.06, width * 0.42, OBSIDIAN, SMOOTH, ringAt * CFrame.new(0, 0, -0.02) * FACING)
	disc.Reflectance = 0.05
	local heart = make.ball(0.24, EMBER, NEON, ringAt * CFrame.new(0, 0, 0.06))
	local flames = Instance.new("Fire")
	flames.Color = MAGMA
	flames.SecondaryColor = EMBER
	flames.Size = 1.6
	flames.Heat = 4
	flames.Parent = heart
	embers(heart, EMBER, 5)
	fireLight(heart, MAGMA)
	for index = 0, 5 do
		local angle = index * math.pi / 3 + math.pi / 6
		local out = Vector3.new(math.sin(angle), math.cos(angle), 0.12)
		lavaShard(make, (ringAt * CFrame.new(out.X * width * 0.42, out.Y * width * 0.42, 0)).Position, out, 0.42, 0.2)
	end
	-- Talismanes: dos placas de obsidiana con una runa de lava que cuelgan bajo el sol.
	for side = -1, 1, 2 do
		local from = (ringAt * CFrame.new(side * width * 0.2, -width * 0.36, 0.04)).Position
		local to = from + Vector3.new(side * 0.04, -height * 0.18, 0.02)
		strap(make, from, to, 0.03, FIBER, FABRIC)
		make.block(Vector3.new(0.16, 0.24, 0.05), OBSIDIAN, SMOOTH, CFrame.new(to.X, to.Y - 0.12, to.Z))
		make.block(Vector3.new(0.04, 0.14, 0.03), MAGMA, NEON, CFrame.new(to.X, to.Y - 0.12, to.Z + 0.03))
	end
	for index, x in { -0.4, -0.2, 0, 0.2, 0.4 } do
		fireCrystal(
			make,
			Vector3.new(x * width, height * 0.44, back + 0.22),
			Vector3.new(x * 1.1, 1, 0.35),
			if index == 3 then 1.15 elseif index % 2 == 0 then 0.85 else 0.6,
			if index == 3 then 0.34 else 0.28,
			LAVA_ROBE,
			MAGMA
		)
	end

	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	waist.block(
		Vector3.new(hipWidth + 0.16, 0.26, hipDepth + 0.18),
		BASALT_DARK,
		BASALT_MATERIAL,
		CFrame.new(0, 0.06, 0)
	)
	waist.block(Vector3.new(hipWidth + 0.18, 0.05, hipDepth + 0.2), MAGMA, NEON, CFrame.new(0, -0.06, 0))
	fireCrystal(waist, Vector3.new(0, -0.02, beltFront - 0.05), Vector3.new(0, 1, -0.3), 0.32, 0.18, LAVA_ROBE, MAGMA)

	for side = -1, 1, 2 do
		volcanicPauldron(body.upperArm[side], side, LAVA_ROBE_DARK, FABRIC, 3, 0.7)
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, 0.02, fs.Y * 0.5, 0.08, LAVA_ROBE_DARK, FABRIC)
		band(forearm, -fs.Y / 2 + 0.1, 0.08, 0.12, MAGMA, NEON)
		band(forearm, fs.Y * 0.26, 0.05, 0.12, MAGMA, NEON)
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.25, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.08, 0, 0)
		leg.block(Vector3.new(ls.X * 0.95, ls.Y * 0.55, 0.1), LAVA_ROBE, FABRIC, flap)
		lavaVein(leg, {
			Vector3.new(-ls.X * 0.25, ls.Y * 0.12, -(ls.Z / 2 + 0.13)),
			Vector3.new(ls.X * 0.05, -ls.Y * 0.05, -(ls.Z / 2 + 0.13)),
			Vector3.new(-ls.X * 0.1, -ls.Y * 0.3, -(ls.Z / 2 + 0.13)),
		}, 0.05)
	end
end

-- Médico. Delante: túnica de lino bajo un manto de ceniza con ribete de azufre, peto de basalto con una
-- cruz verde que brilla (el color de las curaciones), bandolera con tres frascos que brillan, broche
-- con un cristal de azufre y dos bolsas en el cinturón de las que asoman cristales de azufre. Detrás:
-- bastidor de madera con una mochila de basalto cubierta de costras de azufre, un racimo de seis
-- cristales de azufre que brillan, dos chimeneas que echan humo amarillo y dos frascos a los lados.
local function sulfurMantle(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	local back = depth / 2
	make.block(Vector3.new(width + 0.12, height * 0.94, depth + 0.16), LINEN, FABRIC, CFrame.new(0, -height * 0.02, 0))
	make.block(Vector3.new(width + 0.4, 0.34, depth + 0.4), ASH, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.04))
	make.block(Vector3.new(width + 0.42, 0.08, depth + 0.42), SULFUR, SMOOTH, CFrame.new(0, height / 2 - 0.24, 0.04))
	-- Peto de basalto con una cruz verde que brilla entre dos ribetes de azufre, arriba a la izquierda:
	-- fuera del camino de la bandolera.
	local plastron = CFrame.new(-width * 0.27, height * 0.14, front - 0.04)
	make.block(Vector3.new(width * 0.34, height * 0.36, 0.08), BASALT, BASALT_MATERIAL, plastron)
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.05, height * 0.36, 0.06),
			SULFUR,
			SMOOTH,
			plastron * CFrame.new(side * width * 0.17, 0, -0.02)
		)
	end
	local cross =
		make.block(Vector3.new(width * 0.07, height * 0.26, 0.05), HEAL_GLOW, NEON, plastron * CFrame.new(0, 0, -0.06))
	make.block(Vector3.new(width * 0.22, height * 0.08, 0.05), HEAL_GLOW, NEON, plastron * CFrame.new(0, 0.04, -0.06))
	fireLight(cross, HEAL_GLOW)
	local from = Vector3.new(width * 0.3, height / 2 - 0.02, front - 0.08)
	local to = Vector3.new(-width * 0.4, -height / 2 + 0.12, front - 0.08)
	strap(make, from, to, 0.16, BASALT_DARK, LEATHER_MATERIAL)
	for _, t in { 0.22, 0.42, 0.62 } do
		local at = from:Lerp(to, t)
		flask(make, CFrame.new(at.X, at.Y - 0.32, at.Z - 0.1), 0.22, true)
	end
	local brooch = CFrame.new(width * 0.3, height / 2 - 0.16, front - 0.12)
	local rim = make.rod(0.06, 0.32, OBSIDIAN, SMOOTH, brooch * FACING)
	rim.Reflectance = 0.05
	fireCrystal(
		make,
		(brooch * CFrame.new(0, -0.08, -0.04)).Position,
		Vector3.new(0.1, 1, -0.3),
		0.26,
		0.14,
		SULFUR,
		SULFUR_GLOW
	)

	-- Espalda: capa de ceniza, bastidor de madera y la mochila de azufre.
	local capeHeight = height * 1.06
	local capeY = height / 2 - capeHeight / 2 - 0.02
	make.block(Vector3.new(width * 1.02, capeHeight, 0.12), ASH_DARK, FABRIC, CFrame.new(0, capeY, back + 0.16))
	make.block(
		Vector3.new(width * 1.03, 0.08, 0.14),
		SULFUR,
		SMOOTH,
		CFrame.new(0, capeY - capeHeight / 2 + 0.04, back + 0.17)
	)
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.1, height * 1.1, 0.1),
			TOTEM_WOOD,
			WOOD,
			CFrame.new(side * width * 0.38, height * 0.04, back + 0.3)
		)
	end
	for _, y in { height * 0.44, -height * 0.4 } do
		make.block(Vector3.new(width * 0.86, 0.1, 0.1), TOTEM_WOOD, WOOD, CFrame.new(0, y, back + 0.3))
	end
	local pack = CFrame.new(0, -height * 0.08, back + 0.44)
	make.block(Vector3.new(width * 0.64, height * 0.56, 0.44), BASALT, BASALT_MATERIAL, pack)
	make.block(Vector3.new(width * 0.66, 0.08, 0.46), SULFUR, SMOOTH, pack * CFrame.new(0, height * 0.12, 0))
	-- Costras de azufre en la mochila.
	for _, crust in { Vector3.new(-0.18, -0.12, 0.23), Vector3.new(0.2, -0.04, 0.23), Vector3.new(0.05, -0.22, 0.23) } do
		make.block(
			Vector3.new(0.18, 0.12, 0.05),
			SULFUR,
			SMOOTH,
			pack * CFrame.new(crust.X * width, crust.Y * height, crust.Z) * CFrame.Angles(0, 0, crust.X * 2)
		)
	end
	local clusterBase = pack * CFrame.new(0, height * 0.27, 0)
	for index, tilt in { -0.6, -0.36, -0.12, 0.12, 0.36, 0.6 } do
		fireCrystal(
			make,
			(clusterBase * CFrame.new(tilt * width * 0.42, 0, (index % 2) * 0.14 - 0.07)).Position,
			Vector3.new(tilt, 1, 0.25),
			if index == 3 or index == 4 then 1.1 elseif index == 2 or index == 5 then 0.8 else 0.6,
			0.32,
			SULFUR,
			SULFUR_GLOW
		)
	end
	local glow = make.ball(0.22, SULFUR_GLOW, NEON, clusterBase * CFrame.new(0, 0.05, 0))
	fireLight(glow, SULFUR_GLOW)
	embers(glow, SULFUR_GLOW, 4)
	-- Dos chimeneas de obsidiana a los lados del racimo que echan humo amarillo.
	for side = -1, 1, 2 do
		local chimney = clusterBase * CFrame.new(side * width * 0.27, 0.12, -0.12)
		make.rod(0.36, 0.14, OBSIDIAN, SMOOTH, chimney * UPRIGHT)
		local mouth = make.rod(0.05, 0.16, SULFUR_GLOW, NEON, chimney * CFrame.new(0, 0.19, 0) * UPRIGHT)
		smoke(mouth, 3, Color3.fromRGB(200, 190, 110), 0.8)
	end
	for side = -1, 1, 2 do
		flask(make, pack * CFrame.new(side * (width * 0.38 + 0.12), -height * 0.14, 0), 0.3, true)
	end

	-- Cinturón con hebilla de azufre, una venda y dos bolsas con cristales de azufre.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	waist.block(
		Vector3.new(hipWidth + 0.16, 0.22, hipDepth + 0.18),
		BASALT_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, 0.06, 0)
	)
	waist.block(Vector3.new(0.34, 0.26, 0.08), SULFUR, SMOOTH, CFrame.new(0, 0.06, beltFront - 0.02))
	waist.rod(0.24, 0.22, PAINT_WHITE, FABRIC, CFrame.new(hipWidth * 0.32, -0.06, beltFront - 0.1) * UPRIGHT)
	for _, x in { -0.34, 0.12 } do
		local bag = CFrame.new(x * hipWidth, -0.1, beltFront - 0.08)
		waist.block(Vector3.new(0.24, 0.22, 0.12), LEATHER_DARK, LEATHER_MATERIAL, bag)
		fireCrystal(
			waist,
			(bag * CFrame.new(0, 0.1, 0)).Position,
			Vector3.new(0.2, 1, -0.2),
			0.22,
			0.12,
			SULFUR,
			SULFUR_GLOW
		)
	end

	for side = -1, 1, 2 do
		volcanicPauldron(body.upperArm[side], side, ASH, FABRIC, 2, 0.6)
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, fs.Y * 0.05, 0.12, 0.06, PAINT_WHITE, FABRIC, 0.12)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, ASH, FABRIC)
		band(forearm, -fs.Y / 2 + 0.26, 0.06, 0.18, SULFUR, SMOOTH)
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), ASH_DARK, FABRIC, flap)
		leg.block(Vector3.new(ls.X * 0.9, 0.06, 0.12), SULFUR, SMOOTH, flap * CFrame.new(0, -ls.Y * 0.19, -0.01))
		herbPouch(leg, flap * CFrame.new(side * 0.05, 0, -0.12), LEAF)
	end
end

-- ===================================== Míticos: dioses de la selva =====================================
-- Trajes míticos (Data/Cosmetics, rareza "Mythic"): lo más detallado del juego. Ganan piezas con el
-- grado de la armadura que se lleva debajo (0 sin armadura, 4 con la volcánica; enteros en el Lobby y
-- en Dunas). Piedra tallada, oro y jade; lo que brilla es oro de sol (el verde que brilla es solo de
-- las curaciones, así que el jade va sin neón).

local TITAN_STONE = Color3.fromRGB(132, 138, 122)
local TITAN_STONE_DARK = Color3.fromRGB(92, 98, 88)
local TITAN_CARVING = Color3.fromRGB(46, 44, 40)
local TITAN_GOLD = Color3.fromRGB(232, 182, 64)
local TITAN_GOLD_DARK = Color3.fromRGB(176, 128, 40)
local SUN_GLOW = Color3.fromRGB(255, 214, 110)
local JADE = Color3.fromRGB(44, 158, 126)
local JADE_LIGHT = Color3.fromRGB(110, 214, 176)
local ROYAL_RED = Color3.fromRGB(138, 34, 34)
local LIANA = Color3.fromRGB(58, 104, 46)
local ORCHID = Color3.fromRGB(236, 96, 150)

-- Motas de sol que suben despacio (el ídolo, el disco solar).
local function sunMotes(part: BasePart, rate: number)
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Color = ColorSequence.new(SUN_GLOW, TITAN_GOLD)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new(0.15, 1)
	motes.Lifetime = NumberRange.new(1.2, 2)
	motes.Rate = rate
	motes.Speed = NumberRange.new(0.4, 1)
	motes.SpreadAngle = Vector2.new(60, 60)
	motes.Acceleration = Vector3.new(0, 0.8, 0)
	motes.Parent = part
end

-- Cabeza de gorila tallada en piedra mirando a la -Z de "at", "size" studs de ancho y "depth" veces su
-- fondo (en relieve sobre el peto, plana; el ídolo, entera): cráneo con cresta, orejas, cara hundida,
-- cejas de furia, nariz ancha, boca y colmillos de oro. Devuelve los ojos (de "eye" y "eyeMaterial").
local function stoneGorilla(
	make: Builder,
	at: CFrame,
	size: number,
	depth: number,
	eye: Color3,
	eyeMaterial: Enum.Material
): { BasePart }
	local function on(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x * size, y * size, z * size * depth)
	end
	local function scaled(x: number, y: number, z: number): Vector3
		return Vector3.new(x * size, y * size, z * size * depth)
	end
	make.oval(scaled(1, 1, 0.6), TITAN_STONE, SLATE, on(0, 0, 0.1))
	make.oval(scaled(0.46, 0.34, 0.4), TITAN_STONE, SLATE, on(0, 0.46, 0.16))
	make.oval(scaled(0.74, 0.6, 0.26), TITAN_STONE_DARK, SLATE, on(0, -0.12, -0.14))
	make.oval(scaled(0.46, 0.16, 0.12), TITAN_STONE, SLATE, on(0, -0.1, -0.28))
	make.block(scaled(0.42, 0.06, 0.04), TITAN_CARVING, SMOOTH, on(0, -0.32, -0.27))
	local eyes = {}
	for side = -1, 1, 2 do
		make.oval(scaled(0.18, 0.26, 0.14), TITAN_STONE_DARK, SLATE, on(side * 0.5, 0.02, 0.06))
		make.oval(
			scaled(0.42, 0.12, 0.2),
			TITAN_STONE,
			SLATE,
			on(side * 0.18, 0.17, -0.2) * CFrame.Angles(0, 0, side * 0.3)
		)
		table.insert(eyes, make.ball(0.13 * size, eye, eyeMaterial, on(side * 0.17, 0.05, -0.24)))
		make.ball(0.04 * size, TITAN_CARVING, SMOOTH, on(side * 0.09, -0.15, -0.32))
		make.fang(
			0.13 * size,
			0.07 * size,
			TITAN_GOLD,
			SMOOTH,
			on(side * 0.13 + 0.035, -0.3, -0.28) * CFrame.Angles(0, 0, math.pi)
		)
	end
	return eyes
end

-- Calavera de gorila dorada de "size" de ancho, plana, mirando a la +Z de "at" (la espalda): óvalos de
-- oro que se cruzan (cráneo con cresta, pómulos y hocico) sobre un contorno oscuro, con la ceja de oro
-- viejo, las cuencas, la nariz y la boca hundidas y dos colmillos. Sin más detalle: es el motivo del
-- grado 2 y no debe competir con el ídolo del 3.
local function goldenGorillaSkull(make: Builder, at: CFrame, size: number)
	local function on(x: number, y: number, layer: number): CFrame
		return at * CFrame.new(x * size, y * size, layer * 0.02)
	end
	local function disc(x: number, y: number, w: number, h: number, layer: number, color: Color3, tilt: number?)
		make.oval(
			Vector3.new(w * size, h * size, 0.04),
			color,
			SMOOTH,
			on(x, y, layer) * CFrame.Angles(0, 0, tilt or 0)
		)
	end
	-- Contorno oscuro del cráneo y del hocico, un poco más grande que el oro.
	disc(0, 0.2, 0.98, 0.8, 0, TITAN_CARVING)
	disc(0, -0.3, 0.88, 0.62, 0, TITAN_CARVING)
	disc(0, 0.56, 0.34, 0.3, 0.5, TITAN_GOLD)
	disc(0, 0.2, 0.9, 0.72, 1, TITAN_GOLD)
	for side = -1, 1, 2 do
		disc(side * 0.4, -0.06, 0.3, 0.3, 1.5, TITAN_GOLD)
	end
	disc(0, -0.3, 0.78, 0.52, 2, TITAN_GOLD)
	for side = -1, 1, 2 do
		-- Cuencas grandes y hundidas bajo una ceja de furia en V (más baja por dentro).
		disc(side * 0.21, -0.03, 0.27, 0.25, 3, TITAN_CARVING)
		disc(side * 0.22, 0.13, 0.46, 0.13, 4, TITAN_GOLD_DARK, side * 0.35)
		disc(side * 0.07, -0.22, 0.09, 0.07, 3, TITAN_CARVING)
		make.fang(
			0.2 * size,
			0.08 * size,
			TITAN_GOLD,
			SMOOTH,
			on(side * 0.15 + 0.04, -0.4, 3) * CFrame.new(0, 0, 0.1 * size) * CFrame.Angles(0, 0, math.pi)
		)
	end
	make.block(Vector3.new(0.5 * size, 0.05 * size, 0.04), TITAN_CARVING, SMOOTH, on(0, -0.42, 3))
end

-- Cristal de jade (sin neón: el verde que brilla es de las curaciones): funda translúcida de jade
-- claro con un núcleo de jade, de "length" desde "base" hacia "direction".
local function jadeCrystal(make: Builder, base: Vector3, direction: Vector3, length: number, width: number)
	local at = CFrame.lookAt(base, base + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	local case = make.fang(length, width, JADE_LIGHT, GLASS, at)
	case.Transparency = 0.2
	make.fang(length * 0.75, width * 0.5, JADE, SMOOTH, at * CFrame.new(width * 0.25, 0, -width * 0.25))
end

-- Hombrera del Rey Gorila (grado 1+): almohadilla de piedra y dos láminas escalonadas con el canto de
-- oro y, hundida en ellas, una cabeza de gorila de piedra que mira hacia fuera (con los ojos de sol
-- encendidos desde el grado 3). Grado 4: tres cristales de jade que salen por detrás de la cabeza.
local function titanPauldron(arm: Builder, side: number, grade: number)
	local as = arm.size
	local top = as.Y / 2
	arm.oval(
		Vector3.new(as.X * 1.4, 0.56, as.Z * 1.36),
		TITAN_STONE_DARK,
		SLATE,
		CFrame.new(side * 0.12, top + 0.04, 0)
	)
	for index = 0, 1 do
		local lame = CFrame.new(side * (0.2 + index * 0.12), top - 0.08 - index * 0.2, 0)
			* CFrame.Angles(0, 0, -side * (0.35 + index * 0.22))
		arm.oval(
			Vector3.new(as.X * 1.12 + 0.12, 0.1, as.Z * 1.36 - index * 0.1 + 0.06),
			TITAN_GOLD,
			SMOOTH,
			lame * CFrame.new(0, -0.07, 0)
		)
		arm.oval(Vector3.new(as.X * 1.12, 0.22, as.Z * 1.36 - index * 0.1), TITAN_STONE, SLATE, lame)
	end
	local lit = grade >= 3
	stoneGorilla(
		arm,
		CFrame.new(side * as.X * 0.36, top + 0.3, 0) * CFrame.Angles(0, -side * math.pi / 2, 0),
		0.86,
		0.7,
		if lit then SUN_GLOW else JADE,
		if lit then NEON else SMOOTH
	)
	if grade >= 4 then
		for _, z in { -0.26, 0, 0.26 } do
			jadeCrystal(
				arm,
				Vector3.new(-side * 0.04, top + 0.24, z * as.Z),
				Vector3.new(-side * 0.35, 1, z * 1.4),
				if z == 0 then 0.66 else 0.48,
				0.22
			)
		end
	end
end

-- Traje mítico del guerrero, Rey Gorila Titán. Grado 0: túnica roja, peto de piedra con ribete de oro y
-- la cara de un gorila en relieve, gorguera de oro con cuentas de jade, vientre de placas con tachones,
-- placa de la espalda con un sol de oro y centro de jade, cinturón de piedra con hebilla de jade y
-- taparrabos rojo con ribete de oro, brazaletes y muñequeras de oro con jade. Grado 1: hombreras con
-- cabezas de gorila de piedra que miran hacia fuera. Grado 2: manto y capa de pelaje negro de gorila
-- con flecos y una calavera de gorila dorada en la espalda, broches de oro con cadena y faldones de
-- piedra en los muslos (cada grado tiene su motivo en la espalda). Grado 3: el lomo plateado sale
-- alrededor del ídolo, un busto de gorila de piedra enorme entre los omoplatos con ojos de sol que
-- brillan y corona de oro con jade; se encienden los ojos de todas las cabezas y unas vetas de oro en
-- el peto.
-- Grado 4: disco solar de oro con doce rayos y cuatro cristales de jade detrás del ídolo (queda como
-- un halo detrás de la cabeza), lianas con orquídeas colgando de él, cristales de jade en las
-- hombreras y motas de sol que suben.
local function titanKing(body: Body, grade: number)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	local back = depth / 2
	local lit = grade >= 3
	make.block(
		Vector3.new(width + 0.1, height * 0.92, depth + 0.14),
		ROYAL_RED,
		FABRIC,
		CFrame.new(0, -height * 0.03, 0)
	)

	-- Peto: dos pectorales de piedra en ángulo con el borde de abajo de oro y, entre ellos, el esternón
	-- de piedra oscura con la cara del gorila en relieve entre dos franjas de oro.
	for side = -1, 1, 2 do
		local pec = CFrame.new(side * width * 0.25, height * 0.2, front - 0.03) * CFrame.Angles(0.1, -side * 0.14, 0)
		make.block(Vector3.new(width * 0.44, height * 0.32, 0.1), TITAN_STONE, SLATE, pec)
		make.block(
			Vector3.new(width * 0.44, 0.07, 0.12),
			TITAN_GOLD,
			SMOOTH,
			pec * CFrame.new(0, -height * 0.16, -0.01)
		)
	end
	local plate = CFrame.new(0, height * 0.1, front - 0.08)
	make.block(Vector3.new(width * 0.42, height * 0.52, 0.14), TITAN_STONE_DARK, SLATE, plate)
	for _, y in { height * 0.26, -height * 0.26 } do
		make.block(Vector3.new(width * 0.46, 0.08, 0.16), TITAN_GOLD, SMOOTH, plate * CFrame.new(0, y, -0.01))
	end
	stoneGorilla(
		make,
		plate * CFrame.new(0, -0.02, -0.07),
		0.74,
		0.35,
		if lit then SUN_GLOW else JADE,
		if lit then NEON else SMOOTH
	)
	if lit then
		-- Vetas de oro encendidas por los pectorales y el vientre.
		for side = -1, 1, 2 do
			lavaVein(make, {
				Vector3.new(side * width * 0.23, height * 0.34, front - 0.1),
				Vector3.new(side * width * 0.3, height * 0.2, front - 0.1),
				Vector3.new(side * width * 0.4, height * 0.28, front - 0.1),
			}, 0.06, SUN_GLOW)
			lavaVein(make, {
				Vector3.new(side * width * 0.24, height * 0.12, front - 0.1),
				Vector3.new(side * width * 0.36, height * 0.1, front - 0.1),
			}, 0.06, SUN_GLOW)
		end
	end

	-- Gorguera de oro con cuentas de jade.
	for index = 0, 6 do
		local angle = math.rad(-150 + index * 50)
		make.block(
			Vector3.new(0.28, 0.14, 0.16),
			TITAN_GOLD,
			SMOOTH,
			CFrame.new(math.sin(angle) * width * 0.3, height / 2 - 0.02, -math.cos(angle) * depth * 0.46)
				* CFrame.Angles(0, -angle, 0)
		)
		if index < 6 then
			local mid = angle + math.rad(25)
			make.ball(
				0.15,
				JADE,
				SMOOTH,
				CFrame.new(math.sin(mid) * width * 0.31, height / 2 - 0.05, -math.cos(mid) * depth * 0.5)
			)
		end
	end

	-- Vientre de placas de piedra con tachones de oro.
	for row = 0, 1 do
		for side = -1, 1, 2 do
			local at = CFrame.new(side * width * 0.2, -height * 0.21 - row * height * 0.15, front - 0.01)
			make.block(Vector3.new(width * 0.36, height * 0.12, 0.1), TITAN_STONE_DARK, SLATE, at)
			make.ball(0.08, TITAN_GOLD, SMOOTH, at * CFrame.new(0, 0, -0.05))
		end
	end

	-- Espalda: placa de piedra con cantos de oro y un sol de oro con el centro de jade.
	make.block(
		Vector3.new(width * 0.88, height * 0.86, 0.12),
		TITAN_STONE,
		SLATE,
		CFrame.new(0, -height * 0.02, back + 0.08)
	)
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.08, height * 0.86, 0.14),
			TITAN_GOLD,
			SMOOTH,
			CFrame.new(side * width * 0.44, -height * 0.02, back + 0.09)
		)
	end
	local sun = CFrame.new(0, -height * 0.1, back + 0.15)
	make.rod(0.06, 0.5, TITAN_GOLD, SMOOTH, sun * FACING)
	make.ball(0.2, JADE, SMOOTH, sun * CFrame.new(0, 0, 0.05))
	for index = 0, 3 do
		make.block(
			Vector3.new(0.08, 0.26, 0.05),
			TITAN_GOLD,
			SMOOTH,
			sun * CFrame.Angles(0, 0, index * math.pi / 2) * CFrame.new(0, 0.38, 0)
		)
	end

	-- Cinturón de piedra con banda de oro, hebilla de jade y taparrabos rojo delante y detrás.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	waist.block(Vector3.new(hipWidth + 0.16, 0.26, hipDepth + 0.18), TITAN_STONE_DARK, SLATE, CFrame.new(0, 0.04, 0))
	waist.block(Vector3.new(hipWidth + 0.18, 0.06, hipDepth + 0.2), TITAN_GOLD, SMOOTH, CFrame.new(0, 0.15, 0))
	local buckle = CFrame.new(0, 0.04, beltFront - 0.03)
	waist.rod(0.06, 0.44, TITAN_GOLD, SMOOTH, buckle * FACING)
	waist.oval(Vector3.new(0.32, 0.3, 0.12), JADE, SMOOTH, buckle * CFrame.new(0, 0, -0.04))
	for _, z in { beltFront + 0.02, -beltFront - 0.02 } do
		waist.block(Vector3.new(hipWidth * 0.4, 0.6, 0.06), ROYAL_RED, FABRIC, CFrame.new(0, -0.38, z))
		waist.block(Vector3.new(hipWidth * 0.42, 0.06, 0.08), TITAN_GOLD, SMOOTH, CFrame.new(0, -0.66, z))
	end

	-- Brazaletes y muñequeras de oro con jade.
	for side = -1, 1, 2 do
		local upper = body.upperArm[side]
		local us = upper.size
		band(upper, -us.Y * 0.2, 0.12, 0.08, TITAN_GOLD, SMOOTH)
		upper.ball(0.15, JADE, SMOOTH, CFrame.new(side * (us.X / 2 + 0.06), -us.Y * 0.2, 0))
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, -fs.Y / 2 + 0.2, 0.3, 0.1, TITAN_GOLD, SMOOTH)
		forearm.block(
			Vector3.new(0.05, 0.16, 0.22),
			JADE,
			SMOOTH,
			CFrame.new(side * (fs.X / 2 + 0.07), -fs.Y / 2 + 0.2, 0)
		)
		if grade >= 1 then
			titanPauldron(upper, side, grade)
		end
	end

	-- Grado 2: manto y capa de pelaje de gorila con el lomo plateado, broches y faldones de piedra.
	if grade >= 2 then
		make.block(
			Vector3.new(width + 0.36, 0.34, depth * 0.62),
			GORILLA_FUR,
			FABRIC,
			CFrame.new(0, height / 2 - 0.06, depth * 0.24)
		)
		local capeHeight = height * 1.2
		local capeTop = height / 2 - 0.05
		local capeZ = back + 0.22
		make.block(
			Vector3.new(width * 1.02, capeHeight, 0.12),
			GORILLA_FUR,
			FABRIC,
			CFrame.new(0, capeTop - capeHeight / 2, capeZ)
		)
		if grade == 2 then
			-- Calavera de gorila dorada, el motivo de la espalda de este grado: más que el sol del grado 1
			-- y menos que el ídolo del 3, que la tapa.
			goldenGorillaSkull(make, CFrame.new(0, capeTop - capeHeight * 0.36, capeZ + 0.06), width * 0.7)
		else
			-- Lomo plateado alrededor del ídolo: una silla de pelaje plateado con mechones en punta abajo.
			make.oval(
				Vector3.new(width * 0.84, capeHeight * 0.56, 0.05),
				SILVER_FUR,
				FABRIC,
				CFrame.new(0, capeTop - capeHeight * 0.3, capeZ + 0.06)
			)
			for index = -1, 1 do
				make.fang(
					if index == 0 then 0.3 else 0.22,
					0.18,
					SILVER_FUR_DARK,
					FABRIC,
					CFrame.new(index * width * 0.2, capeTop - capeHeight * 0.52, capeZ + 0.07)
						* CFrame.Angles(math.pi, 0, 0)
				)
			end
		end
		for index = 0, 6 do
			local x = (index / 6 - 0.5) * width * 0.92
			make.fang(
				if index % 2 == 0 then 0.34 else 0.26,
				0.16,
				GORILLA_FUR,
				FABRIC,
				CFrame.new(x, capeTop - capeHeight + 0.02, capeZ) * CFrame.Angles(math.pi, 0, 0)
			)
		end
		-- Broches de oro con jade, unidos por una cadena que cuelga.
		local clasps = {}
		for side = -1, 1, 2 do
			local clasp = CFrame.new(side * width * 0.36, height / 2 - 0.12, front - 0.04)
			make.rod(0.08, 0.3, TITAN_GOLD, SMOOTH, clasp * FACING)
			make.ball(0.14, JADE, SMOOTH, clasp * CFrame.new(0, 0, -0.06))
			clasps[side] = clasp.Position
		end
		local sag = Vector3.new(0, height / 2 - 0.3, front - 0.06)
		strap(make, clasps[-1], sag, 0.05, TITAN_GOLD, SMOOTH)
		strap(make, sag, clasps[1], 0.05, TITAN_GOLD, SMOOTH)
		for side = -1, 1, 2 do
			local leg = body.upperLeg[side]
			local ls = leg.size
			local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
			leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.42, 0.1), TITAN_STONE, SLATE, flap)
			leg.block(Vector3.new(ls.X * 0.92, 0.06, 0.12), TITAN_GOLD, SMOOTH, flap * CFrame.new(0, -ls.Y * 0.2, 0))
			leg.ball(0.12, JADE, SMOOTH, flap * CFrame.new(0, 0.02, -0.06))
		end
	end

	-- Grado 3: el ídolo de la espalda, un busto de piedra con corona de oro, entre los omoplatos: la
	-- corona llega a la nuca y la cabeza del jugador se sigue viendo por encima.
	if grade >= 3 then
		local idolSize = 1.4
		local idolY = height * 0.05
		local idol = CFrame.new(0, idolY, back + 0.6) * CFrame.Angles(0, math.pi, 0)
		local bust = CFrame.new(0, idolY - idolSize * 0.5 - 0.06, back + 0.44)
		make.block(Vector3.new(width * 0.78, 0.34, 0.5), TITAN_STONE_DARK, SLATE, bust)
		make.block(Vector3.new(width * 0.8, 0.07, 0.52), TITAN_GOLD, SMOOTH, bust * CFrame.new(0, 0.1, 0))
		local eyes = stoneGorilla(make, idol, idolSize, 1, SUN_GLOW, NEON)
		fireLight(eyes[1], SUN_GLOW)
		-- Corona: banda de oro y cinco puntas con una cuenta de jade.
		local crown = idol * CFrame.new(0, idolSize * 0.5, idolSize * 0.08)
		make.block(Vector3.new(idolSize * 0.66, 0.16, idolSize * 0.5), TITAN_GOLD, SMOOTH, crown)
		for index = -2, 2 do
			local spike = crown
				* CFrame.new(index * idolSize * 0.13, 0.08, -idolSize * 0.22)
				* CFrame.Angles(-0.15, 0, -index * 0.12)
			local length = if index == 0 then 0.5 else 0.38 - math.abs(index) * 0.04
			make.fang(length, 0.16, TITAN_GOLD, SMOOTH, spike)
			make.ball(0.12, JADE, SMOOTH, spike * CFrame.new(0.08, 0.04, -0.1))
		end
		-- Grado 4: disco solar con rayos y cristales de jade, lianas con orquídeas y motas de sol.
		if grade >= 4 then
			local disc = CFrame.new(0, idolY + 0.3, back + 0.36)
			-- Aro abierto (no un disco: por detrás taparía la cabeza) de doce tramos de oro, con rayos de
			-- oro largos y rayos de sol que brillan, alternos.
			local radius = idolSize * 0.86
			local segment = 2 * radius * math.sin(math.pi / 12) + 0.04
			for index = 0, 11 do
				local angle = index * math.pi / 6
				make.block(
					Vector3.new(segment, 0.14, 0.1),
					TITAN_GOLD_DARK,
					SMOOTH,
					disc
						* CFrame.Angles(0, 0, angle + math.pi / 12)
						* CFrame.new(0, radius * math.cos(math.pi / 12) - 0.04, 0)
				)
				local ray = disc * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius, 0.02)
				if index % 2 == 0 then
					make.fang(0.6, 0.2, TITAN_GOLD, SMOOTH, ray)
				else
					local beam = make.fang(0.42, 0.14, SUN_GLOW, NEON, ray)
					if index == 3 then
						fireLight(beam, SUN_GLOW)
						sunMotes(beam, 6)
					end
				end
			end
			-- Cuatro cristales de jade en las diagonales.
			for _, angle in { math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4 } do
				local base = disc * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius - 0.05, 0.05)
				jadeCrystal(make, base.Position, base.UpVector + Vector3.new(0, 0, 0.15), 0.55, 0.24)
			end
			-- Lianas con hojas y una orquídea que caen de los lados del ídolo por la capa.
			for side = -1, 1, 2 do
				local points = {
					Vector3.new(side * width * 0.34, idolY + 0.3, back + 0.5),
					Vector3.new(side * width * 0.42, height * 0.04, back + 0.4),
					Vector3.new(side * width * 0.36, -height * 0.2, back + 0.36),
					Vector3.new(side * width * 0.42, -height * 0.48, back + 0.34),
				}
				for index = 1, #points - 1 do
					strap(make, points[index], points[index + 1], 0.06, LIANA, FABRIC)
					leaf(
						make,
						0.3,
						if index % 2 == 0 then LEAF else LEAF_DARK,
						CFrame.new(points[index + 1]) * CFrame.Angles(0, 0, side * 0.9)
					)
				end
				local flower = CFrame.new(points[2] + Vector3.new(side * 0.04, 0, 0.06))
				for petal = 0, 2 do
					make.oval(
						Vector3.new(0.12, 0.2, 0.05),
						ORCHID,
						SMOOTH,
						flower * CFrame.Angles(0, 0, petal * 2.1) * CFrame.new(0, 0.08, 0)
					)
				end
				make.ball(0.07, SUN_GLOW, NEON, flower * CFrame.new(0, 0, 0.03))
			end
		end
	end
end

-- Constructores por armadura y rol (el que falta usa el de DEFAULT_ROLE).
local BUILDERS: { [string]: { [string]: (body: Body) -> () } } = {
	FurVest = { Guerrero = furVest, Cazador = trackerCape, Mago = amuletMantle, Medico = healerBandolier },
	BoneArmor = { Guerrero = boneArmor, Cazador = hunterLeather, Mago = runeTunic, Medico = healerPlastron },
	SilverArmor = { Guerrero = silverArmor, Cazador = silverHunter, Mago = crystalMantle, Medico = silverHealer },
	VolcanicArmor = { Guerrero = volcanicArmor, Cazador = emberCloak, Mago = lavaRobe, Medico = sulfurMantle },
}

-- Grado de cada armadura (sin ninguna, 0): los trajes míticos ganan piezas con él.
local ARMOR_GRADE: { [string]: number } = { FurVest = 1, BoneArmor = 2, SilverArmor = 3, VolcanicArmor = 4 }
ArmorModels.MAX_GRADE = 4

-- Trajes (Data/Cosmetics, tipo "Outfit"), por id del cosmético. Reciben el grado de la armadura que
-- se lleva debajo (0 a MAX_GRADE): los míticos ganan piezas con cada grado; los demás lo enseñarán con
-- un acento de color.
local OUTFITS: { [string]: (body: Body, grade: number) -> () } = {
	TitanKingOutfit = titanKing,
}

-- Si los trajes crecen con la armadura (la Isla, donde se fabrica: lo pone CraftingService). En el
-- Lobby y en Dunas, donde no hay armaduras que fabricar, se ven enteros (MAX_GRADE).
ArmorModels.growWithArmor = false

function ArmorModels.hasOutfit(outfitId: string): boolean
	return OUTFITS[outfitId] ~= nil
end

function ArmorModels.grade(armorId: string?): number
	return if armorId then ARMOR_GRADE[armorId] or 0 else 0
end

-- Viste a "character" con el traje "outfitId" (si lo hay; con el grado "grade" o el de la armadura)
-- o, si no, con la armadura "armorId" en la versión de su rol "roleId". Sustituye a lo que llevara; sin
-- traje ni armadura lo quita. Devuelve el modelo, o nil si no hay nada que poner o no hay torso.
function ArmorModels.wear(
	character: Model,
	armorId: string?,
	roleId: string?,
	outfitId: string?,
	grade: number?
): Model?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		return nil
	end
	local previous = character:FindFirstChild("ArmorPiece")
	if previous then
		previous:Destroy()
	end
	local outfit = if outfitId then OUTFITS[outfitId] else nil
	local byRole = if armorId and Armor[armorId] then BUILDERS[armorId] else nil
	local armor = if byRole then byRole[roleId or DEFAULT_ROLE] or byRole[DEFAULT_ROLE] else nil
	if not (outfit or armor) then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "ArmorPiece"
	local function arms(r15: string, r6Offset: CFrame, r6Size: Vector3): { [number]: Builder }
		return {
			[-1] = limb(model, character, "Left" .. r15, "Left Arm", r6Offset, r6Size),
			[1] = limb(model, character, "Right" .. r15, "Right Arm", r6Offset, r6Size),
		}
	end
	local body: Body = {
		torso = limb(model, character, "UpperTorso", "Torso", CFrame.identity),
		waist = limb(model, character, "LowerTorso", "Torso", CFrame.new(0, -0.8, 0), Vector3.new(2, 0.4, 1)),
		upperArm = arms("UpperArm", CFrame.new(0, 0.4, 0), Vector3.new(1, 1.2, 1)),
		lowerArm = arms("LowerArm", CFrame.new(0, -0.6, 0), Vector3.new(1, 0.8, 1)),
		upperLeg = {
			[-1] = limb(model, character, "LeftUpperLeg", "Left Leg", CFrame.new(0, 0.35, 0), Vector3.new(1, 1.3, 1)),
			[1] = limb(model, character, "RightUpperLeg", "Right Leg", CFrame.new(0, 0.35, 0), Vector3.new(1, 1.3, 1)),
		},
	}
	if outfit then
		outfit(body, math.clamp(grade or ArmorModels.grade(armorId), 0, ArmorModels.MAX_GRADE))
	elseif armor then
		armor(body)
	end
	model.Parent = character
	return model
end

-- Viste al personaje de "player" con lo suyo: el traje equipado de su rol ("Outfit") o su armadura.
function ArmorModels.dress(player: Player, character: Model?): Model?
	character = character or player.Character
	if not character then
		return nil
	end
	local armorId = player:GetAttribute("Armor")
	local roleId = player:GetAttribute("Role")
	local outfitId = player:GetAttribute("Outfit")
	local validArmor = if typeof(armorId) == "string" then armorId else nil
	return ArmorModels.wear(
		character,
		validArmor,
		if typeof(roleId) == "string" then roleId else nil,
		if typeof(outfitId) == "string" then outfitId else nil,
		if ArmorModels.growWithArmor then ArmorModels.grade(validArmor) else ArmorModels.MAX_GRADE
	)
end

return ArmorModels
