--!strict
-- Modelos de las armaduras (Data/Armor) que lleva puestas el personaje, y de los trajes (cosméticos
-- "Outfit" de Data/Cosmetics, Fase 9), que se ponen en su lugar. Los viste "dress" con los atributos
-- del jugador ("Armor", "Role" y "Outfit", que publica ServerShared/CosmeticsServer): CraftingService
-- al fabricarlas y al reaparecer y CosmeticsServer al cambiar de traje. Está en Shared porque el
-- Armario (UI/WardrobePanel) viste también el avatar de la vista previa. En el Lobby y en Dunas, donde
-- no se fabrican, se luce la mejor fabricada en la Isla con ese rol (atributo "ArmorLook", de
-- CosmeticsServer): solo el modelo, porque el daño lo reduce "Armor" (CombatService).
-- Cada pieza va soldada a la parte del cuerpo que cubre (torso,
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
--     hombreras de losa cuadrada de pelaje rojo con canto dorado y dos colmillos, cordones de fibra,
--     collar de colmillos, cinturón de cuerda con zurrón y un plátano de amuleto, faldones de pelaje
--     en los muslos, brazaletes de pelaje dorado y muñecas vendadas con fibra. Detrás, un panel de
--     pelaje rojo con la huella de una mano de mono grande en pelaje dorado (en bloques) y flecos.
--   - Armadura de hueso: peto de cuero con cinco pares de costillas en V y esternón de hueso, hombreras
--     de losa de cuero con un cráneo de mono sobre un mechón de pelaje rojo, brazales de cuero con tres
--     tablillas de hueso, hebilla de calavera con tachones y faldones de cuero y hueso en los muslos.
--     Detrás, columna con vértebras y tres pares de costillas grandes, y un cráneo de trofeo sobre
--     dos huesos cruzados con borlas de pelaje rojo y flecos.
--   - Armadura de plata (lomo plateado): manto y gorguera de siete bloques de pelaje plateado de
--     gorila, peto de hueso grueso (pectorales y abdominales con raya de cuero) con remaches,
--     medallón de plata con cuatro remaches y un plátano dorado que destella, hombreras de tres
--     láminas de hueso con tres cráneos de mono en abanico, brazales con aro de plata y puño de
--     pelaje, faldones de pelaje con tres placas de hueso y cinturón con un cráneo de mono. Detrás,
--     capa oscura de gorila con ribete plateado y flecos y la cabeza de un gorila plateado furioso
--     (melena con cresta, patillas, ceja de furia, ojos rojos que brillan y colmillos), todo de bloques.
-- Cazador (ligeras, de cuero con camuflaje de hojas; detrás, la capucha bajada y el carcaj con las
-- flechas asomando por encima del hombro derecho, el de la mano que tira):
--   - Capa de rastreador: jubón de cuero claro, capa corta de pelaje pardo con hojas cosidas, una
--     hombrera de losa de pelaje (izquierda) y otra en estrella de hojas (derecha), correa del carcaj
--     cruzada, brazal en el antebrazo del arco y cinturón de fibra con zurrón y cuchillo. Detrás, un
--     abanico de hojas de bloque (tres verdes) en semicírculo tras la capucha bajada y el carcaj de
--     corteza con cuatro flechas de plumas blancas sobre el hombro derecho.
--   - Armadura de cazador: jubón de cuero oscuro con botones de hueso, hombrera de losa de láminas de
--     hueso con garras en el hombro izquierdo y estrella de hojas en el derecho, correa con colmillos
--     de trofeo, brazal con tablillas de hueso y hojas colgando de los muslos. Detrás, un manto de hojas
--     de tres verdes en tres capas y el carcaj de cuero con aros de hueso, un colmillo colgando y cinco
--     flechas de plumas rojas y blancas.
--   - Manto de cazador plateado: capa de pelaje plateado con flecos y ribete de plata, hojas oscuras de
--     camuflaje, capucha de pelaje con orejas, broche de plata en forma de hoja, correas cruzadas con
--     remaches y colmillos de trofeo, hombros de losa de pelaje con garras de hueso y una hoja encima,
--     brazales con aro de plata y puño de pelaje y faldones plateados. Detrás, el carcaj de cuero
--     oscuro con tres aros de plata y siete flechas de plumas plateadas y negras sobre un manto de
--     hojas oscuras en dos abanicos de bloques.
-- Mago (de chamán: tela y amuletos que pasan a runas y cristales que brillan en azul; el morado es
-- del veneno y el verde, de las curaciones):
--   - Manto de amuletos: túnica teñida de morado bajo un poncho de fibra con franjas y flecos, collar
--     de cuentas con un amuleto de piedra, hombreras de disco plano de fibra tejida con una cuenta
--     turquesa, faja con una calabaza y pulseras de cuentas. Detrás, un atrapasueños grande (aro de
--     diez tramos, red de hilos cruzados) con cuatro plumas y cuentas colgando.
--   - Túnica de runas: túnica añil con ribetes dorados, una runa que brilla en el pecho, cráneos de
--     mono de ojos brillantes sobre hombreras de disco, faja con piedras rúnicas y brazales con runas.
--     Detrás, un sello grande de neón (círculo de runas con un triángulo dentro) y dos talismanes
--     colgando.
--   - Manto de cristal: túnica añil oscura con cintas de plata bajo una capa de pelaje plateado con
--     cuello alto en escalones y flecos de cristal, broche y cadena de plata con cristales, hombros
--     de losa de pelaje con cristales y puños plateados. Detrás, una corona de trece cristales que
--     sale de un disco de plata con núcleo que brilla, rodeado de un círculo de runas, y asoma por
--     encima de los hombros.
-- Médico (de curandero: lino, hierbas y frascos; lo que brilla, en verde, el color de las curaciones):
--   - Bandolera de curandero: túnica de lino con una bandolera de cuero cruzada, por delante y por
--     detrás, con bolsitas de las que asoman hojas; hombreras de disco plano de lino con una hoja,
--     mortero en la cadera, vendas en los antebrazos y hojas atadas a los brazos. Detrás, un manojo
--     grande de hierbas en abanico (tres verdes) con una flor roja, atado a la bandolera, y frasquitos.
--   - Peto de curandero: peto de hueso blanco con una cruz de hojas y una flor en el centro, hombreras
--     de disco de hueso con hojas, cinturón con rollos de venda y bolsas en los muslos. Detrás, una
--     mochila de cuero en un bastidor de madera con frascos de poción encima y a los lados, un rollo
--     de manta y hierbas asomando.
--   - Manto de sanador: manto y capa de pelaje plateado, bandolera con frascos que brillan y una
--     bolsita de hierbas, broche con una gema verde entre dos hojas y hojas en los hombros. Detrás,
--     un tótem sanador pequeño (como el de la definitiva) con su gema verde brillando por encima de
--     los hombros, sobre un abanico de hojas, atado a los hombros y entre frascos que brillan.
-- Nivel 4, armadura volcánica (forja volcánica): basalto y obsidiana con grietas de lava que brillan,
-- la más rica: las mismas siluetas y motivos que los rangos anteriores (cráneo de mono, garras, hojas,
-- cristales, frascos) hechos de basalto, ceniza y obsidiana. Todas con hombreras de losa (franja de
-- lava bajo el canto, escalón de obsidiana, grietas y gotas de lava) con cristales de obsidiana hundidos
-- en lava y una llama de lava en píxeles que echa humo. Detrás, el guerrero un volcán en escalones con
-- ríos de lava, cráter con fuente, bombas y humo bajo una corona de siete cristales; el cazador (Manto
-- de brasa) una capa de ceniza con zarpazos de lava, abanicos de hojas quemadas y el carcaj de obsidiana
-- con flechas que arden; el mago (Túnica de lava) un sol negro en anillos de fuego con llamas, rayos y
-- una corona de siete cristales de lava; y el médico (Manto de azufre) una mochila con un racimo de
-- siete cristales de azufre, chimeneas de humo y frascos que brillan en verde (la curación).

local Armor = require(game:GetService("ReplicatedStorage").Shared.Data.Armor)
local VoxelMerge = require(game:GetService("ReplicatedStorage").Shared.VoxelMerge)

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

-- Hombrera de losa cuadrada: un canto fino más grande debajo y la losa encima, corridas un poco hacia
-- fuera. "arm" es el brazo de arriba y "side" su lado (-1 izquierda, 1 derecha).
local function slabPauldron(arm: Builder, side: number, color: Color3, material: Enum.Material, trim: Color3)
	local as = arm.size
	local top = as.Y / 2
	local slab = Vector3.new(as.X + 0.38, 0.2, as.Z + 0.38)
	arm.block(Vector3.new(slab.X + 0.12, 0.08, slab.Z + 0.12), trim, FABRIC, CFrame.new(side * 0.1, top + 0.05, 0))
	arm.block(slab, color, material, CFrame.new(side * 0.1, top + 0.14, 0))
end

-- Hombrera de disco plano (un cilindro tumbado) con un aro debajo de otro color. Devuelve el marco del
-- centro de la cara de arriba, para poner encima una cuenta o una hoja.
local function discPauldron(arm: Builder, side: number, color: Color3, rim: Color3, material: Enum.Material): CFrame
	local as = arm.size
	local top = as.Y / 2
	arm.rod(0.1, as.X + 0.62, rim, material, CFrame.new(side * 0.1, top + 0.05, 0) * UPRIGHT)
	arm.rod(0.12, as.X + 0.46, color, material, CFrame.new(side * 0.1, top + 0.12, 0) * UPRIGHT)
	return CFrame.new(side * 0.1, top + 0.18, 0)
end

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
		-- Tapa del hombro de delante a atrás, dejando libre el cuello.
		local shoulderWidth = outer + skin / 2 - neck
		make.block(
			Vector3.new(shoulderWidth, skin, depth + 2 * (gap + skin)),
			FUR,
			FABRIC,
			CFrame.new(side * (neck + shoulderWidth / 2), height / 2 + gap + skin / 2, 0)
		)
		-- Cuello de pelaje dorado a cada lado.
		make.rod(
			depth * 0.9,
			0.24,
			GOLDEN_FUR,
			FABRIC,
			CFrame.new(side * neck, height / 2 + 0.1, 0) * CFrame.Angles(0, math.rad(90), 0)
		)
		-- Hombrera de losa cuadrada de pelaje rojo con canto dorado y dos colmillos hacia fuera.
		local arm = body.upperArm[side]
		slabPauldron(arm, side, FUR, FABRIC, GOLDEN_FUR)
		for tusk = -1, 1, 2 do
			arm.fang(
				0.34,
				0.12,
				BONE,
				SMOOTH,
				CFrame.new(side * (arm.size.X / 2 + 0.3), arm.size.Y / 2 + 0.2, tusk * arm.size.Z * 0.28)
					* CFrame.Angles(0, 0, -side * 0.7)
			)
		end
		-- Faldón de pelaje en el muslo con el borde dorado y un colmillo.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flapZ = -(ls.Z / 2 + 0.05)
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.34, 0.08), FUR, FABRIC, CFrame.new(0, ls.Y * 0.33, flapZ))
		leg.block(Vector3.new(ls.X * 0.9, 0.07, 0.11), GOLDEN_FUR, FABRIC, CFrame.new(0, ls.Y * 0.16, flapZ))
		leg.fang(0.22, 0.1, BONE, SMOOTH, CFrame.new(0, ls.Y * 0.16, flapZ - 0.05) * CFrame.Angles(0, 0, math.pi))
	end
	-- Espalda (lo que el jugador ve siempre): un panel de pelaje rojo con la huella de una mano de mono
	-- en pelaje dorado (palma, cuatro dedos y el pulgar, todo en bloques) y flecos de pelo en punta.
	local printZ = back + skin / 2 + 0.07
	make.block(
		Vector3.new(width * 0.86, height * 0.8, 0.04),
		FUR,
		FABRIC,
		CFrame.new(0, -height * 0.04, back + skin / 2 + 0.02)
	)
	local palmWidth, palmHeight = width * 0.42, height * 0.28
	local palmY = -height * 0.14
	make.block(Vector3.new(palmWidth, palmHeight, 0.06), GOLDEN_FUR, FABRIC, CFrame.new(0, palmY, printZ))
	local fingerLengths = { height * 0.17, height * 0.23, height * 0.2, height * 0.14 }
	for index, length in fingerLengths do
		make.block(
			Vector3.new(width * 0.085, length, 0.06),
			GOLDEN_FUR,
			FABRIC,
			CFrame.new((index - 2.5) * width * 0.105, palmY + palmHeight / 2 + length / 2 - 0.02, printZ)
		)
	end
	make.block(
		Vector3.new(width * 0.1, height * 0.18, 0.06),
		GOLDEN_FUR,
		FABRIC,
		CFrame.new(-palmWidth / 2 - 0.1, palmY + palmHeight * 0.2, printZ) * CFrame.Angles(0, 0, math.rad(55))
	)
	local fringe = 7
	for index = 0, fringe - 1 do
		local x = -width * 0.42 + index * width * 0.84 / (fringe - 1)
		make.fang(
			if index % 2 == 0 then 0.34 else 0.26,
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
	-- Flecos de pelo en el bajo del chaleco, delante.
	for index = 0, 3 do
		make.fang(
			0.24,
			0.18,
			if index % 2 == 0 then FUR_DARK else FUR,
			FABRIC,
			CFrame.new(-width * 0.33 + index * width * 0.22, -height / 2 + 0.02, front - 0.03)
				* CFrame.Angles(0, 0, math.pi)
		)
	end
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
	-- Peto de cuero con las costuras oscuras a los lados; cuello de pelaje rojo con ribete dorado.
	make.block(
		Vector3.new(width + 0.1, height * 0.9, depth + 0.16),
		LEATHER,
		LEATHER_MATERIAL,
		CFrame.new(0, -height * 0.03, 0)
	)
	make.block(Vector3.new(width * 0.75, 0.25, depth + 0.25), FUR, FABRIC, CFrame.new(0, height / 2 - 0.05, 0))
	make.block(
		Vector3.new(width * 0.75 + 0.04, 0.07, depth + 0.29),
		GOLDEN_FUR,
		FABRIC,
		CFrame.new(0, height / 2 - 0.2, 0)
	)
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.06, height * 0.8, depth + 0.2),
			LEATHER_DARK,
			LEATHER_MATERIAL,
			CFrame.new(side * (width / 2 + 0.06), -height * 0.04, 0)
		)
	end
	-- Cinco pares de costillas en V que bajan desde el esternón, cada vez más cortas, y el esternón
	-- atado con fibra y rematado en una punta (el apéndice xifoides).
	local tilt = 0.22
	for index, ribY in { 0.3, 0.16, 0.02, -0.12, -0.26 } do
		local length = width * (0.38 - index * 0.025)
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
	make.fang(0.3, 0.14, BONE, SMOOTH, CFrame.new(0.07, -height * 0.39, front - 0.05) * CFrame.Angles(0, 0, math.pi))
	for _, tieY in { 0.2, -0.16 } do
		make.block(Vector3.new(0.3, 0.1, 0.08), FIBER, FABRIC, CFrame.new(0, height * tieY, front - 0.12))
	end
	-- Espalda (lo que el jugador ve siempre): columna con vértebras y tres pares de costillas grandes
	-- sobre un fondo de cuero oscuro y, arriba, un cráneo de trofeo sobre dos huesos cruzados con una
	-- borla de pelaje rojo colgando de cada hueso y flecos de pelo abajo.
	make.block(
		Vector3.new(width * 0.84, height * 0.88, 0.06),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, -height * 0.02, back)
	)
	make.block(Vector3.new(0.14, height * 0.84, 0.1), BONE_DARK, SMOOTH, CFrame.new(0, -height * 0.02, back + 0.07))
	for _, knobY in { 0.42, -0.08, -0.22, -0.36 } do
		make.block(Vector3.new(0.28, 0.12, 0.12), BONE, SMOOTH, CFrame.new(0, height * knobY, back + 0.1))
	end
	for index, ribY in { -0.08, -0.22, -0.36 } do
		local length = width * (0.44 - index * 0.05)
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(length, 0.13, 0.09),
				BONE,
				SMOOTH,
				CFrame.new(
					side * (0.1 + length / 2 * math.cos(tilt)),
					height * ribY - length / 2 * math.sin(tilt),
					back + 0.08
				) * CFrame.Angles(0, 0, side * tilt)
			)
		end
	end
	local trophy = CFrame.new(0, height * 0.17, back + 0.16)
	for _, cross in { 0.65, -0.65 } do
		cartoonBone(make, width * 0.66, 0.13, BONE, trophy * CFrame.Angles(0, 0, cross))
	end
	monkeySkull(make, trophy * CFrame.new(0, 0.04, 0.3) * CFrame.Angles(math.rad(-10), math.pi, 0), 1.15)
	for side = -1, 1, 2 do
		local tassel = trophy * CFrame.new(side * width * 0.3, -0.3, 0.1)
		make.block(Vector3.new(0.04, 0.3, 0.04), FIBER, FABRIC, tassel)
		make.block(Vector3.new(0.18, 0.2, 0.1), FUR, FABRIC, tassel * CFrame.new(0, -0.22, 0.02))
		make.fang(0.3, 0.16, FUR_DARK, FABRIC, tassel * CFrame.new(0.08, -0.32, 0.02) * CFrame.Angles(0, 0, math.pi))
	end
	for index = 0, 3 do
		make.fang(
			if index % 2 == 0 then 0.34 else 0.26,
			0.2,
			if index % 2 == 0 then FUR else FUR_DARK,
			FABRIC,
			CFrame.new(-width * 0.33 + index * width * 0.22 + 0.1, -height / 2 + 0.02, back + 0.1)
				* CFrame.Angles(0, 0, math.pi)
		)
	end

	-- Cinturón con hebilla de calavera, tachones de hueso y dos tiras de cuero colgando.
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
		waist.ball(0.1, BONE_DARK, SMOOTH, CFrame.new(eye * hipWidth * 0.32, 0.08, beltFront - 0.06))
		waist.block(
			Vector3.new(0.18, 0.34, 0.05),
			LEATHER,
			LEATHER_MATERIAL,
			CFrame.new(eye * hipWidth * 0.2, -0.14, beltFront - 0.05)
		)
	end
	waist.block(Vector3.new(0.08, 0.08, 0.04), SKULL_HOLE, SMOOTH, CFrame.new(0, 0.02, beltFront - 0.21))

	for side = -1, 1, 2 do
		-- Hombrera de losa de cuero con canto de hueso, un mechón de pelaje rojo y, encima, un cráneo de mono.
		local arm = body.upperArm[side]
		local top = arm.size.Y / 2
		slabPauldron(arm, side, LEATHER, LEATHER_MATERIAL, BONE_DARK)
		arm.block(
			Vector3.new(arm.size.X * 0.7, 0.12, arm.size.Z * 0.7),
			FUR,
			FABRIC,
			CFrame.new(side * 0.1, top + 0.3, 0)
		)
		for z = -1, 1, 2 do
			arm.fang(
				0.3,
				0.14,
				FUR_DARK,
				FABRIC,
				CFrame.new(side * arm.size.X * 0.1, top + 0.3, z * (arm.size.Z * 0.35 + 0.05))
					* CFrame.Angles(z * 1.0, 0, 0)
			)
		end
		monkeySkull(
			arm,
			CFrame.new(side * arm.size.X * 0.2, top + 0.5, 0) * CFrame.Angles(0, -side * math.rad(30), 0),
			0.8
		)
		band(arm, -arm.size.Y * 0.12, 0.2, 0.1, FUR, FABRIC)
		-- Brazal de cuero con tres tablillas de hueso por fuera, atado con fibra por arriba y por abajo.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, -0.02, fs.Y * 0.6, 0.08, LEATHER, LEATHER_MATERIAL)
		band(forearm, fs.Y * 0.22, 0.08, 0.12, FIBER, FABRIC)
		band(forearm, -fs.Y * 0.26, 0.08, 0.12, FIBER, FABRIC)
		for _, z in { -0.3, 0, 0.3 } do
			forearm.block(
				Vector3.new(0.08, fs.Y * 0.5, 0.14),
				BONE,
				SMOOTH,
				CFrame.new(side * (fs.X / 2 + 0.07), -0.02, z * fs.Z)
			)
		end
		-- Faldón de cuero en el muslo con tres tablillas de hueso y un colmillo colgando.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.17, -(ls.Z / 2 + 0.05)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.85, ls.Y * 0.36, 0.08), LEATHER, LEATHER_MATERIAL, flap)
		for _, x in { -0.28, 0, 0.28 } do
			leg.block(Vector3.new(0.1, ls.Y * 0.3, 0.06), BONE, SMOOTH, flap * CFrame.new(x * ls.X, -0.02, -0.06))
		end
		leg.fang(
			0.26,
			0.12,
			BONE,
			SMOOTH,
			CFrame.new(side * 0.04 + 0.06, ls.Y * 0.15, -(ls.Z / 2 + 0.1)) * CFrame.Angles(0, 0, math.pi)
		)
	end
end

-- Cabeza de gorila plateado para la espalda, mirando a la -Z de "at", de "size" studs de ancho, toda
-- de bloques: melena plateada con cresta, orejas y patillas, cara oscura con ceja gruesa inclinada,
-- ojos rojos que brillan, nariz ancha y boca con colmillos.
local function gorillaFace(make: Builder, at: CFrame, size: number)
	local function on(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x * size, y * size, z * size)
	end
	make.block(Vector3.new(1, 1.05, 0.14) * size, SILVER_FUR, FABRIC, on(0, 0, 0))
	make.block(Vector3.new(0.56, 0.2, 0.18) * size, SILVER_FUR_DARK, FABRIC, on(0, 0.6, -0.02))
	make.block(Vector3.new(0.72, 0.62, 0.1) * size, GORILLA_FACE, SMOOTH, on(0, -0.1, -0.1))
	make.block(Vector3.new(0.44, 0.17, 0.08) * size, GORILLA_NOSE, SMOOTH, on(0, -0.14, -0.18))
	make.block(Vector3.new(0.4, 0.06, 0.06) * size, SKULL_HOLE, SMOOTH, on(0, -0.3, -0.18))
	for side = -1, 1, 2 do
		make.block(Vector3.new(0.12, 0.26, 0.1) * size, SILVER_FUR_DARK, FABRIC, on(side * 0.56, 0.04, 0))
		make.block(Vector3.new(0.14, 0.4, 0.16) * size, SILVER_FUR, FABRIC, on(side * 0.43, -0.12, -0.04))
		make.ball(0.15 * size, GORILLA_EYE, NEON, on(side * 0.17, 0.08, -0.17))
		make.ball(0.07 * size, SKULL_HOLE, SMOOTH, on(side * 0.1, -0.15, -0.23))
		-- Ceja de furia: inclinada, más baja por dentro.
		make.block(
			Vector3.new(0.4, 0.11, 0.12) * size,
			GORILLA_FACE,
			SMOOTH,
			on(side * 0.18, 0.18, -0.16) * CFrame.Angles(0, 0, side * 0.35)
		)
		-- Colmillos por fuera de la boca (no atraviesan la cara).
		make.fang(
			0.13 * size,
			0.07 * size,
			THICK_BONE,
			SMOOTH,
			on(side * 0.13 + 0.035, -0.31, -0.21) * CFrame.Angles(0, 0, math.pi)
		)
	end
end

-- Manto de pelaje plateado de los hombros y la espalda del rango III (cazador, mago y médico): dos
-- escalones sobre los hombros, capa con los lados de pelaje más oscuro, ribete de plata abajo y flecos
-- en punta. Devuelve la Y del borde de abajo de la capa.
local function silverCape(make: Builder, tufts: number): number
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local back = depth / 2
	make.block(
		Vector3.new(width + 0.4, 0.34, depth + 0.4),
		SILVER_FUR_DARK,
		FABRIC,
		CFrame.new(0, height / 2 - 0.06, 0.04)
	)
	make.block(Vector3.new(width + 0.12, 0.2, depth + 0.14), SILVER_FUR, FABRIC, CFrame.new(0, height / 2 + 0.14, 0.06))
	local capeHeight = height * 1.08
	local capeY = height / 2 - capeHeight / 2 - 0.02
	local capeBottom = capeY - capeHeight / 2
	make.block(Vector3.new(width * 1.02, capeHeight, 0.12), SILVER_FUR, FABRIC, CFrame.new(0, capeY, back + 0.16))
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.12, capeHeight, 0.16),
			SILVER_FUR_DARK,
			FABRIC,
			CFrame.new(side * width * 0.51, capeY, back + 0.16)
		)
	end
	local hem = make.block(
		Vector3.new(width * 1.02 + 0.2, 0.08, 0.16),
		SILVER,
		METAL,
		CFrame.new(0, capeBottom + 0.04, back + 0.16)
	)
	hem.Reflectance = 0.25
	for index = 0, tufts - 1 do
		local x = -width * 0.4 + index * width * 0.8 / (tufts - 1)
		make.fang(
			if index % 2 == 0 then 0.36 else 0.26,
			0.3,
			if index % 2 == 0 then SILVER_FUR else SILVER_FUR_DARK,
			FABRIC,
			CFrame.new(x + 0.15, capeBottom + 0.04, back + 0.36) * CFrame.Angles(0, 0, math.pi)
		)
	end
	return capeBottom
end

-- Hombrera de losa del rango III en pelaje plateado: canto de plata, losa de pelaje y un escalón
-- encima, con un puño de pelaje en el brazo. Devuelve el marco del centro de la cara de arriba.
local function furSlabPauldron(arm: Builder, side: number): CFrame
	local as = arm.size
	local top = as.Y / 2
	local rim =
		arm.block(Vector3.new(as.X + 0.5, 0.08, as.Z + 0.5), SILVER, METAL, CFrame.new(side * 0.1, top + 0.05, 0))
	rim.Reflectance = 0.25
	arm.block(
		Vector3.new(as.X + 0.42, 0.22, as.Z + 0.42),
		SILVER_FUR_DARK,
		FABRIC,
		CFrame.new(side * 0.1, top + 0.2, 0)
	)
	arm.block(Vector3.new(as.X + 0.1, 0.16, as.Z + 0.1), SILVER_FUR, FABRIC, CFrame.new(side * 0.1, top + 0.38, 0))
	band(arm, -as.Y * 0.12, 0.2, 0.1, SILVER_FUR, FABRIC)
	return CFrame.new(side * 0.1, top + 0.46, 0)
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
	-- Abdominales: tres filas de placas, más estrechas hacia abajo, con la raya central de cuero.
	make.block(
		Vector3.new(0.1, height * 0.5, 0.08),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, -height * 0.22, front)
	)
	for row = 0, 2 do
		for side = -1, 1, 2 do
			local plateWidth = width * (0.21 - row * 0.015)
			make.block(
				Vector3.new(plateWidth, height * 0.14, 0.1),
				if row == 1 then BONE else THICK_BONE,
				SMOOTH,
				CFrame.new(side * (plateWidth / 2 + 0.05), -height * (0.05 + row * 0.17), front - 0.03)
			)
		end
	end
	-- Medallón de plata con un plátano dorado, entre los pectorales, con cuatro remaches y un destello.
	local medal = CFrame.new(0, height * 0.22, front - 0.24)
	local rim = make.rod(0.08, 0.62, SILVER, METAL, medal * FACING)
	rim.Reflectance = 0.35
	make.rod(0.04, 0.48, GORILLA_FUR, METAL, medal * CFrame.new(0, 0, -0.04) * FACING)
	banana(make, 0.36, medal * CFrame.new(0, -0.08, -0.08))
	for index = 0, 3 do
		local angle = index * math.pi / 2
		local stud =
			make.ball(0.1, SILVER, METAL, medal * CFrame.new(math.sin(angle) * 0.31, math.cos(angle) * 0.31, -0.02))
		stud.Reflectance = 0.25
	end
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

	-- Manto de pelaje plateado sobre los hombros (por delante no baja, para no tapar el peto), collar
	-- por delante y gorguera de siete bloques por detrás del cuello, con tres púas de pelo encima.
	make.block(
		Vector3.new(width + 0.4, height * 0.28, depth * 0.7 + 0.2),
		SILVER_FUR_DARK,
		FABRIC,
		CFrame.new(0, height / 2 - 0.08, depth * 0.15 + 0.1)
	)
	make.block(
		Vector3.new(width + 0.1, 0.2, depth * 0.7 + 0.1),
		SILVER_FUR,
		FABRIC,
		CFrame.new(0, height / 2 + 0.12, depth * 0.15 + 0.1)
	)
	make.block(
		Vector3.new(width + 0.2, 0.26, 0.34),
		SILVER_FUR,
		FABRIC,
		CFrame.new(0, height / 2 - 0.04, -depth / 2 + 0.02)
	)
	local ruff = 7
	for index = 0, ruff - 1 do
		local angle = math.rad(-90 + index * 180 / (ruff - 1))
		make.block(
			Vector3.new(0.6, 0.55, 0.45),
			if index % 2 == 0 then SILVER_FUR else SILVER_FUR_DARK,
			FABRIC,
			CFrame.new(math.sin(angle) * 0.8, height / 2 + 0.22, math.cos(angle) * 0.62) * CFrame.Angles(0, angle, 0)
		)
		if index % 2 == 1 then
			make.fang(
				0.3,
				0.2,
				SILVER_FUR,
				FABRIC,
				CFrame.new(math.sin(angle) * 0.8 - 0.1, height / 2 + 0.4, math.cos(angle) * 0.62)
			)
		end
	end
	-- Capa de pelaje oscuro de gorila con ribete plateado a los lados y abajo, flecos en punta y, encima,
	-- la cabeza de un gorila plateado de ojos rojos que brillan: es lo que el jugador ve siempre.
	local capeHeight = height * 1.0
	local capeY = -height * 0.12
	make.block(Vector3.new(width * 0.96, capeHeight, 0.12), GORILLA_FUR, FABRIC, CFrame.new(0, capeY, back + 0.17))
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.12, capeHeight, 0.14),
			SILVER_FUR,
			FABRIC,
			CFrame.new(side * (width * 0.48 + 0.02), capeY, back + 0.17)
		)
	end
	make.block(
		Vector3.new(width * 0.96 + 0.2, 0.1, 0.14),
		SILVER_FUR_DARK,
		FABRIC,
		CFrame.new(0, capeY - capeHeight / 2 + 0.05, back + 0.17)
	)
	gorillaFace(make, CFrame.new(0, 0, back + 0.25) * CFrame.Angles(0, math.pi, 0), width * 0.74)
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

	-- Cinturón ancho con hebilla de plata, un cráneo de mono, dos remaches y dos borlas de pelaje.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	waist.block(
		Vector3.new(hipWidth + 0.16, 0.28, hipDepth + 0.18),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, 0.06, 0)
	)
	local buckle = waist.block(Vector3.new(0.5, 0.38, 0.08), SILVER, METAL, CFrame.new(0, 0.06, beltFront - 0.04))
	buckle.Reflectance = 0.35
	monkeySkull(waist, CFrame.new(0, 0.06, beltFront - 0.16), 0.5, true)
	for side = -1, 1, 2 do
		local stud = waist.ball(0.12, SILVER, METAL, CFrame.new(side * hipWidth * 0.34, 0.06, beltFront - 0.04))
		stud.Reflectance = 0.25
		waist.block(
			Vector3.new(0.16, 0.34, 0.06),
			SILVER_FUR,
			FABRIC,
			CFrame.new(side * hipWidth * 0.2, -0.2, beltFront - 0.03)
		)
	end

	for side = -1, 1, 2 do
		-- Hombrera: base de pelaje plateado y tres láminas de hueso grueso que bajan hacia fuera, con un
		-- remache y tres cráneos de mono en abanico encima (sin colmillos ni garras que los atraviesen).
		local arm = body.upperArm[side]
		local as = arm.size
		local top = as.Y / 2
		arm.block(Vector3.new(as.X + 0.5, 0.12, as.Z + 0.5), SILVER_FUR, FABRIC, CFrame.new(side * 0.12, top + 0.04, 0))
		local lames: { CFrame } = {}
		for index = 0, 2 do
			local lame = CFrame.new(side * (0.1 + index * 0.1), top + 0.2 - index * 0.21, 0)
				* CFrame.Angles(0, 0, -side * (0.22 + index * 0.18))
			lames[index + 1] = lame
			arm.block(
				Vector3.new(as.X * 0.95 - index * 0.06, 0.16, as.Z + 0.3 - index * 0.08),
				if index == 1 then BONE else THICK_BONE,
				SMOOTH,
				lame
			)
		end
		local stud = arm.ball(0.14, SILVER, METAL, lames[2] * CFrame.new(side * (as.X * 0.5 - 0.12), 0.12, 0))
		stud.Reflectance = 0.25
		-- Hacia fuera y delante, hacia fuera y hacia fuera y atrás: se les ve la cara también desde detrás.
		for index, z in { -0.42, 0, 0.42 } do
			local turn = math.rad(55 + (index - 1) * 35)
			local scale = if index == 2 then 0.7 else 0.58
			monkeySkull(
				arm,
				lames[1] * CFrame.new(0, 0.1 + 0.3 * scale, z * as.Z) * CFrame.Angles(0, -side * turn, 0),
				scale,
				true
			)
		end
		band(arm, -as.Y * 0.12, 0.2, 0.1, SILVER_FUR, FABRIC)
		band(arm, -as.Y * 0.3, 0.1, 0.08, LEATHER_DARK, LEATHER_MATERIAL)
		-- Brazal de cuero con placa de hueso por fuera, dos remaches, un aro de plata y un puño de pelaje.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, 0.05, fs.Y * 0.55, 0.08, LEATHER_DARK, LEATHER_MATERIAL)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, SILVER_FUR, FABRIC)
		local ring = band(forearm, fs.Y * 0.3, 0.06, 0.14, SILVER, METAL)
		ring.Reflectance = 0.25
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
		-- Faldón de pelaje plateado en el muslo con tres placas de hueso, un remache y dos flecos.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.19, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), SILVER_FUR, FABRIC, flap)
		leg.block(Vector3.new(ls.X * 0.4, ls.Y * 0.3, 0.08), THICK_BONE, SMOOTH, flap * CFrame.new(0, 0.02, -0.07))
		for plate = -1, 1, 2 do
			leg.block(
				Vector3.new(ls.X * 0.14, ls.Y * 0.26, 0.06),
				BONE,
				SMOOTH,
				flap * CFrame.new(plate * ls.X * 0.34, 0.02, -0.07)
			)
			leg.fang(
				0.22,
				0.18,
				if plate == 1 then SILVER_FUR_DARK else SILVER_FUR,
				FABRIC,
				flap * CFrame.new(plate * ls.X * 0.22 + 0.09, -ls.Y * 0.2 + 0.03, -0.02) * CFrame.Angles(0, 0, math.pi)
			)
		end
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

-- Abanico de "count" hojas de bloque que salen de la nuca y caen por la espalda en semicírculo, de
-- "length" de largo y abiertas "spread" radianes a cada lado de la vertical. Los colores de "colors"
-- se alternan y "out" es lo que se separan de la espalda.
local function blockLeafFan(
	make: Builder,
	count: number,
	length: number,
	spread: number,
	colors: { Color3 },
	out: number
)
	local height, depth = make.size.Y, make.size.Z
	local neck = Vector3.new(0, height / 2 - 0.3, depth / 2 + out)
	for index = 0, count - 1 do
		local angle = -spread + index * 2 * spread / (count - 1)
		local size = length * (1 - 0.12 * math.abs(angle) / spread)
		local direction = Vector3.new(math.sin(angle), -math.cos(angle), 0)
		-- Una de cada dos un poco por fuera, para que no compartan plano.
		local center = neck + direction * (size / 2 + 0.05) + Vector3.new(0, 0, (index % 2) * 0.05)
		make.block(
			Vector3.new(0.3, size, 0.06),
			colors[index % #colors + 1],
			SMOOTH,
			CFrame.new(center) * CFrame.Angles(0, 0, math.pi + angle)
		)
	end
end

-- Estrella de hojas tumbada sobre el hombro (la del lado del carcaj): seis hojas de bloque en rueda
-- sobre un disco de cuero, con una cuenta clara en el centro.
local function leafStar(arm: Builder, side: number)
	local as = arm.size
	local top = as.Y / 2
	local center = Vector3.new(side * 0.1, top + 0.1, 0)
	arm.rod(0.08, as.X + 0.2, HUNTER_LEATHER_DARK, LEATHER_MATERIAL, CFrame.new(center.X, top + 0.04, 0) * UPRIGHT)
	for index = 0, 5 do
		local angle = index / 6 * math.pi * 2
		arm.block(
			Vector3.new(0.24, 0.06, 0.66),
			if index % 2 == 0 then LEAF else LEAF_DARK,
			SMOOTH,
			CFrame.new(center + Vector3.new(0, (index % 2) * 0.03, 0))
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, 0, -0.34)
		)
	end
	arm.block(Vector3.new(0.2, 0.1, 0.2), LEAF_LIGHT, SMOOTH, CFrame.new(center + Vector3.new(0, 0.05, 0)))
end

-- Capucha bajada a la espalda, de bloques: el pliegue, su forro oscuro arriba y la punta colgando (de
-- cuero, o del "material" que se pida: el rango III la hace de pelaje). Devuelve el marco del pliegue.
local function blockHood(make: Builder, color: Color3, lining: Color3, material: Enum.Material?): CFrame
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local hoodMaterial = material or LEATHER_MATERIAL
	local fold = CFrame.new(0, height / 2 - 0.2, depth / 2 + 0.2)
	make.block(Vector3.new(width * 0.46, 0.64, 0.36), color, hoodMaterial, fold)
	make.block(Vector3.new(width * 0.34, 0.12, 0.24), lining, hoodMaterial, fold * CFrame.new(0, 0.33, -0.04))
	make.fang(0.4, 0.3, color, hoodMaterial, fold * CFrame.new(0.14, -0.32, 0.15) * CFrame.Angles(0, 0, math.pi))
	return fold
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
	-- Capa corta de pelaje pardo sobre los hombros, con flecos por detrás.
	make.block(Vector3.new(width + 0.24, 0.32, depth + 0.3), FUR_BROWN, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.02))
	for index = 0, 4 do
		make.fang(
			if index % 2 == 0 then 0.26 else 0.2,
			0.18,
			FUR_BROWN,
			FABRIC,
			CFrame.new(-width * 0.36 + index * width * 0.18, height / 2 - 0.2, depth / 2 + 0.2)
				* CFrame.Angles(0, 0, math.pi)
		)
	end
	-- Hombreras: la izquierda, una losa de pelaje con canto de cuero; la derecha (la del carcaj), una
	-- estrella de hojas. Ninguna estorba al arco, que va en el brazo derecho por debajo.
	slabPauldron(body.upperArm[-1], -1, FUR_BROWN, FABRIC, HUNTER_LEATHER_DARK)
	leafStar(body.upperArm[1], 1)
	-- Hojas cosidas por delante, a los lados del cuello.
	for side = -1, 1, 2 do
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
		-- Hoja cosida en el muslo.
		local leg = body.upperLeg[side]
		leaf(
			leg,
			0.5,
			if side == 1 then LEAF_DARK else LEAF,
			CFrame.new(side * 0.1, leg.size.Y * 0.3, -(leg.size.Z / 2 + 0.05)) * CFrame.Angles(0, math.pi, math.pi)
		)
	end
	-- Detrás (lo que el jugador ve siempre): un abanico de hojas de tres verdes en semicírculo tras la
	-- capucha bajada, y el carcaj de corteza con cuatro flechas de plumas blancas sobre el hombro derecho.
	blockLeafFan(make, 6, 0.85, 1.2, { LEAF_LIGHT }, 0.07)
	blockLeafFan(make, 9, 1.4, 1.35, { LEAF, LEAF_DARK }, 0.16)
	blockHood(make, HUNTER_LEATHER, HUNTER_LEATHER_DARK)
	backQuiver(make, {
		length = 1.6,
		radius = 0.22,
		color = BARK,
		material = WOOD,
		rim = FIBER,
		rimMaterial = FABRIC,
		arrows = 4,
		feathers = { FEATHER_WHITE },
	}, 0.3)
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

local function hunterLeather(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	-- Jubón de cuero oscuro con la tira central, dos pespuntes y cuatro botones de hueso (palitos atravesados).
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
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.05, height * 0.8, 0.04),
			HUNTER_LEATHER,
			LEATHER_MATERIAL,
			CFrame.new(side * 0.26, -height * 0.04, front)
		)
	end
	for _, y in { 0.28, 0.1, -0.08, -0.26 } do
		make.rod(0.32, 0.08, BONE, SMOOTH, CFrame.new(0, height * y, front - 0.04))
	end
	-- Cuello de cuero claro.
	make.block(
		Vector3.new(width * 0.7, 0.2, depth + 0.24),
		HUNTER_LEATHER,
		LEATHER_MATERIAL,
		CFrame.new(0, height / 2 - 0.04, 0)
	)
	-- Hojas cosidas a los lados del cuello, como en la capa de rastreador.
	for side = -1, 1, 2 do
		leaf(
			make,
			0.42,
			LEAF,
			CFrame.new(side * width * 0.32, height / 2 - 0.14, front - 0.1) * CFrame.Angles(0, 0, side * 0.5)
		)
		leaf(
			make,
			0.36,
			LEAF_DARK,
			CFrame.new(side * width * 0.44, height / 2 - 0.2, front - 0.09) * CFrame.Angles(0, 0, side * 1.1)
		)
	end
	-- Correa del carcaj con tres colmillos de trofeo colgando.
	quiverStrap(make, front - 0.06, 0.14, LEATHER, LEATHER_MATERIAL)
	for index = 1, 3 do
		local t = 0.25 + index * 0.13
		local x = width * 0.3 + (-width * 0.7) * t
		local y = (height / 2 - 0.02) + (-height + 0.14) * t
		make.fang(0.26, 0.1, BONE, SMOOTH, CFrame.new(x + 0.05, y - 0.04, front - 0.09) * CFrame.Angles(0, 0, math.pi))
	end
	-- Detrás (lo que el jugador ve siempre): un manto de hojas de tres verdes en tres capas, más denso
	-- que el de la capa de rastreador, la capucha bajada y el carcaj de cuero con aros de hueso.
	blockLeafFan(make, 7, 1.55, 1.4, { LEAF_DARK }, 0.06)
	blockLeafFan(make, 9, 1.25, 1.25, { LEAF }, 0.14)
	blockLeafFan(make, 6, 0.9, 1.0, { LEAF_LIGHT }, 0.22)
	blockHood(make, HUNTER_LEATHER, LEATHER_DARK)
	local quiverAt = backQuiver(make, {
		length = 1.8,
		radius = 0.26,
		color = HUNTER_LEATHER,
		material = LEATHER_MATERIAL,
		rim = BONE,
		rimMaterial = SMOOTH,
		arrows = 5,
		feathers = { FEATHER_RED, FEATHER_WHITE },
	}, 0.3)
	-- Un tercer aro de hueso a media altura y un colmillo grande atado al costado del carcaj.
	make.rod(0.1, 0.57, BONE, SMOOTH, quiverAt * CFrame.new(0, -0.2, 0) * UPRIGHT)
	make.block(Vector3.new(0.04, 0.3, 0.04), FIBER, FABRIC, quiverAt * CFrame.new(-0.3, 0.3, 0.05))
	make.fang(0.38, 0.14, BONE, SMOOTH, quiverAt * CFrame.new(-0.23, 0.17, 0.14) * CFrame.Angles(0, 0, math.pi))

	-- Cinturón de cuero con hebilla de hueso, tachones, zurrón, cuchillo y un colmillo de trofeo.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.08)
	waist.block(Vector3.new(hipWidth + 0.14, 0.2, hipDepth + 0.14), LEATHER, LEATHER_MATERIAL, CFrame.new(0, 0.06, 0))
	waist.block(Vector3.new(0.3, 0.24, 0.08), BONE, SMOOTH, CFrame.new(0, 0.06, beltFront - 0.02))
	waist.fang(0.3, 0.12, BONE, SMOOTH, CFrame.new(0.06, -0.06, beltFront - 0.06) * CFrame.Angles(0, 0, math.pi))
	for _, x in { 0.16, -0.16 } do
		waist.ball(0.09, BONE_DARK, SMOOTH, CFrame.new(x * hipWidth, 0.06, beltFront - 0.04))
	end
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

	-- Hombrera de láminas de hueso (losa con tres tablillas y dos garras) en el hombro izquierdo; en el
	-- derecho, la estrella de hojas del arco (la del lado del carcaj, como en la capa de rastreador).
	local left = body.upperArm[-1]
	local leftTop = left.size.Y / 2
	slabPauldron(left, -1, BONE, SMOOTH, BONE_DARK)
	for _, z in { -0.34, 0, 0.34 } do
		left.block(
			Vector3.new(left.size.X + 0.3, 0.06, 0.16),
			BONE_DARK,
			SMOOTH,
			CFrame.new(-0.1, leftTop + 0.27, z * left.size.Z)
		)
	end
	for _, z in { -0.26, 0.26 } do
		left.fang(
			0.34,
			0.12,
			BONE,
			SMOOTH,
			CFrame.new(-(left.size.X / 2 + 0.3), leftTop + 0.2, z * left.size.Z) * CFrame.Angles(0, 0, 0.7)
		)
	end
	band(left, leftTop - 0.45, 0.14, 0.08, HUNTER_LEATHER_DARK, LEATHER_MATERIAL)
	local right = body.upperArm[1]
	leafStar(right, 1)
	band(right, right.size.Y / 2 - 0.45, 0.14, 0.08, HUNTER_LEATHER_DARK, LEATHER_MATERIAL)
	-- Brazal de cuero con tres tablillas de hueso en el antebrazo del arco; guante en el otro.
	local bowArm = body.lowerArm[1]
	local fs = bowArm.size
	band(bowArm, -fs.Y * 0.06, fs.Y * 0.55, 0.08, LEATHER, LEATHER_MATERIAL)
	band(bowArm, fs.Y * 0.26, 0.06, 0.12, FIBER, FABRIC)
	for _, z in { -0.3, 0, 0.3 } do
		bowArm.block(
			Vector3.new(0.08, fs.Y * 0.5, 0.14),
			BONE,
			SMOOTH,
			CFrame.new(fs.X / 2 + 0.07, -fs.Y * 0.06, z * fs.Z)
		)
	end
	band(body.lowerArm[-1], -fs.Y * 0.38, 0.2, 0.08, HUNTER_LEATHER_DARK, LEATHER_MATERIAL)
	band(body.lowerArm[-1], -fs.Y * 0.16, 0.06, 0.12, FIBER, FABRIC)
	-- Hojas colgando por delante de los muslos (en el muslo: en la cintura, la pierna las atraviesa),
	-- sujetas con una correa y un botón de hueso.
	for side = -1, 1, 2 do
		local leg = body.upperLeg[side]
		local ls = leg.size
		band(leg, ls.Y / 2 - 0.14, 0.1, 0.06, HUNTER_LEATHER_DARK, LEATHER_MATERIAL)
		leg.ball(0.1, BONE, SMOOTH, CFrame.new(side * 0.06, ls.Y / 2 - 0.14, -(ls.Z / 2 + 0.07)))
		for index, x in { -0.18, 0.18 } do
			leaf(
				leg,
				0.62,
				if index == 1 then LEAF else LEAF_DARK,
				CFrame.new(side * 0.06 + x * ls.X, ls.Y / 2 - 0.4, -(ls.Z / 2 + 0.05 + index * 0.02))
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
	-- Jubón de cuero oscuro con la tira central cosida y dos correas cruzadas con remaches de plata.
	make.block(
		Vector3.new(width + 0.12, height * 0.92, depth + 0.14),
		LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(0, -height * 0.02, 0)
	)
	make.block(Vector3.new(0.06, height * 0.8, 0.04), LEATHER, LEATHER_MATERIAL, CFrame.new(0, -height * 0.04, front))
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
			Vector3.new(0, height * 0.09, 0),
			Vector3.new(width * 0.3, height / 2 - 0.06, 0),
			Vector3.new(-width * 0.3, height / 2 - 0.06, 0),
			Vector3.new(-width * 0.4, -height / 2 + 0.16, 0),
			Vector3.new(width * 0.4, -height / 2 + 0.16, 0),
		}
	do
		local rivet = make.ball(0.13, SILVER, METAL, CFrame.new(at.X, at.Y, front - 0.12))
		rivet.Reflectance = 0.25
	end
	-- Tres colmillos de trofeo colgando de la correa.
	for _, t in { 0.3, 0.45, 0.6 } do
		local x = width * 0.3 - width * 0.7 * t
		local y = (height / 2 - 0.02) + (-height + 0.14) * t
		make.fang(
			0.26,
			0.1,
			THICK_BONE,
			SMOOTH,
			CFrame.new(x + 0.05, y - 0.08, front - 0.16) * CFrame.Angles(0, 0, math.pi)
		)
	end
	-- Manto de pelaje plateado con la capa y los flecos (silverCape) y hojas oscuras de camuflaje cosidas
	-- a los lados del cuello.
	silverCape(make, 5)
	make.block(Vector3.new(width * 0.5, 0.24, 0.3), SILVER_FUR, FABRIC, CFrame.new(0, height / 2 - 0.06, front + 0.02))
	for side = -1, 1, 2 do
		leaf(
			make,
			0.42,
			LEAF_SHADOW,
			CFrame.new(side * width * 0.3, height / 2 - 0.16, front - 0.1) * CFrame.Angles(0, 0, side * 0.5)
		)
		leaf(
			make,
			0.36,
			LEAF_DARK,
			CFrame.new(side * width * 0.43, height / 2 - 0.2, front - 0.09) * CFrame.Angles(0, 0, side * 1.1)
		)
	end
	-- Broche de plata en forma de hoja cerrando el manto bajo el cuello.
	local brooch = CFrame.new(0, height / 2 - 0.22, front - 0.14)
	local disc = make.rod(0.06, 0.26, SILVER, METAL, brooch * FACING)
	disc.Reflectance = 0.35
	leaf(make, 0.52, SILVER, brooch * CFrame.new(0, -0.02, -0.05) * CFrame.Angles(0, math.pi, 0.6))
	-- Detrás (lo que el jugador ve siempre): un manto de hojas oscuras en dos abanicos de bloques sobre
	-- la capa, hojas sueltas en las esquinas, la capucha de pelaje con orejas y el carcaj con siete flechas.
	blockLeafFan(make, 9, 1.5, 1.3, { LEAF_SHADOW, LEAF_DARK }, 0.3)
	blockLeafFan(make, 7, 1.05, 1.1, { LEAF_DARK, LEAF }, 0.36)
	for index, spot in
		{
			Vector3.new(-0.8, -0.45, 0.5),
			Vector3.new(-0.62, -0.85, -0.4),
			Vector3.new(0.8, -0.5, -0.5),
			Vector3.new(0.62, -0.88, 0.4),
		}
	do
		leaf(
			make,
			0.5,
			if index % 2 == 0 then LEAF_SHADOW else LEAF_DARK,
			CFrame.new(spot.X, spot.Y, back + 0.42) * CFrame.Angles(0, 0, spot.Z)
		)
	end
	local hood = blockHood(make, SILVER_FUR_DARK, GORILLA_FUR, FABRIC)
	for side = -1, 1, 2 do
		make.fang(
			0.34,
			0.22,
			GORILLA_FUR,
			FABRIC,
			hood * CFrame.new(side * 0.42 - 0.11, 0.3, -0.05) * CFrame.Angles(0, 0, -side * 0.3)
		)
	end
	local quiverAt = backQuiver(make, {
		length = 1.8,
		radius = 0.26,
		color = LEATHER_DARK,
		material = LEATHER_MATERIAL,
		rim = SILVER,
		rimMaterial = METAL,
		arrows = 7,
		feathers = { SILVER_FUR, GORILLA_FACE },
	}, 0.4)
	for _, y in { 0, -0.5 } do
		local ring = make.rod(0.1, 0.58, SILVER, METAL, quiverAt * CFrame.new(0, y, 0) * UPRIGHT)
		ring.Reflectance = 0.25
	end
	-- Borla de pelaje plateado colgando del costado del carcaj.
	make.block(Vector3.new(0.04, 0.3, 0.04), FIBER, FABRIC, quiverAt * CFrame.new(-0.3, 0.2, 0.05))
	make.block(Vector3.new(0.14, 0.22, 0.1), SILVER_FUR, FABRIC, quiverAt * CFrame.new(-0.3, 0.0, 0.05))

	-- Cinturón ancho con hebilla de plata, remaches, zurrón y cuchillo de hueso.
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
	for _, x in { 0.16, -0.16 } do
		local stud = waist.ball(0.1, SILVER, METAL, CFrame.new(x * hipWidth, 0.06, beltFront - 0.04))
		stud.Reflectance = 0.25
	end
	local pouch = CFrame.new(hipWidth * 0.3, -0.12, beltFront - 0.06)
	waist.block(Vector3.new(0.38, 0.34, 0.14), LEATHER_DARK, LEATHER_MATERIAL, pouch)
	waist.block(Vector3.new(0.42, 0.14, 0.18), SILVER_FUR, FABRIC, pouch * CFrame.new(0, 0.13, -0.01))
	local sheath = CFrame.new(-hipWidth * 0.36, -0.14, beltFront - 0.03) * CFrame.Angles(0, 0, -0.25)
	waist.block(Vector3.new(0.14, 0.44, 0.08), LEATHER_DARK, LEATHER_MATERIAL, sheath)
	waist.block(Vector3.new(0.1, 0.22, 0.1), THICK_BONE, SMOOTH, sheath * CFrame.new(0, 0.32, 0))

	for side = -1, 1, 2 do
		-- Hombro: losa de pelaje plateado con tres garras de hueso hacia fuera (salen del pelaje) y una
		-- hoja oscura de camuflaje tumbada encima.
		local arm = body.upperArm[side]
		local as = arm.size
		local top = as.Y / 2
		local center = furSlabPauldron(arm, side)
		for _, z in { -0.3, 0, 0.3 } do
			arm.fang(
				0.42,
				0.16,
				THICK_BONE,
				SMOOTH,
				CFrame.new(side * (as.X * 0.55) - 0.08, top + 0.2, z * as.Z + 0.08) * CFrame.Angles(0, 0, -side * 0.7)
			)
		end
		leaf(arm, 0.5, LEAF_SHADOW, center * CFrame.Angles(-math.pi / 2, 0, side * 0.6))
		band(arm, -as.Y * 0.3, 0.1, 0.08, LEATHER_DARK, LEATHER_MATERIAL)
		-- Brazal de cuero con puño de pelaje plateado y aro de plata; el del arco, con placa de hueso y
		-- dos remaches.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, 0.04, fs.Y * 0.55, 0.08, LEATHER_DARK, LEATHER_MATERIAL)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, SILVER_FUR, FABRIC)
		local ring = band(forearm, fs.Y * 0.3, 0.06, 0.14, SILVER, METAL)
		ring.Reflectance = 0.25
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
		-- Faldón de pelaje plateado en el muslo con una hoja oscura encima y dos flecos.
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
		for plate = -1, 1, 2 do
			leg.fang(
				0.22,
				0.18,
				if plate == 1 then SILVER_FUR_DARK else SILVER_FUR,
				FABRIC,
				flap * CFrame.new(plate * ls.X * 0.22 + 0.09, -ls.Y * 0.2 + 0.03, -0.02) * CFrame.Angles(0, 0, math.pi)
			)
		end
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

-- Atrapasueños grande de la espalda, en el plano XY de "at" (mirando a su +Z, hacia atrás): aro de
-- madera de diez tramos, red de tres cuerdas cruzadas y un aro interior, una cuenta turquesa en el
-- centro y cuatro cordones con cuenta y pluma colgando.
local function bigDreamcatcher(make: Builder, at: CFrame, radius: number)
	hoop(make, at, radius, 10, 0.12, BARK, WOOD)
	for index = 0, 2 do
		make.block(
			Vector3.new(radius * 2, 0.04, 0.04),
			FIBER,
			FABRIC,
			at * CFrame.new(0, 0, 0.02) * CFrame.Angles(0, 0, index * math.pi / 3)
		)
	end
	hoop(make, at * CFrame.new(0, 0, 0.03), radius * 0.5, 6, 0.04, WOVEN_FIBER, FABRIC)
	make.ball(0.2, BEAD_TEAL, SMOOTH, at * CFrame.new(0, 0, 0.06))
	local feathers = { FEATHER_WHITE, FEATHER_RED, FEATHER_WHITE, FEATHER_GREY }
	for index = 1, 4 do
		local x = (index - 2.5) * radius * 0.4
		local bottom = -math.sqrt(radius * radius - x * x)
		make.block(Vector3.new(0.03, 0.26, 0.03), FIBER, FABRIC, at * CFrame.new(x, bottom - 0.12, 0))
		make.ball(0.13, if index % 2 == 0 then BEAD_RED else BEAD_TEAL, SMOOTH, at * CFrame.new(x, bottom - 0.3, 0))
		make.block(
			Vector3.new(0.16, 0.5, 0.04),
			feathers[index],
			SMOOTH,
			at * CFrame.new(x, bottom - 0.62, 0) * CFrame.Angles(0, 0, (index - 2.5) * 0.12)
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
	-- Rombos de colores en fila por el centro del poncho.
	for index, color in { DYE_PURPLE, BEAD_TEAL, BEAD_RED } do
		make.block(
			Vector3.new(0.17, 0.17, 0.04),
			color,
			SMOOTH,
			CFrame.new(0, 0.1 - (index - 1) * 0.18, front - 0.03) * CFrame.Angles(0, 0, math.rad(45))
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
	-- Hombreras de disco plano de fibra tejida con una cuenta turquesa encima.
	for side = -1, 1, 2 do
		local center = discPauldron(body.upperArm[side], side, WOVEN_FIBER, DYE_PURPLE, FABRIC)
		body.upperArm[side].ball(0.2, BEAD_TEAL, SMOOTH, center * CFrame.new(0, 0.04, 0))
	end
	-- Detrás (lo que el jugador ve siempre): un atrapasueños grande.
	bigDreamcatcher(make, CFrame.new(0, height * 0.16, back + 0.08), 0.72)

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
	-- Túnica añil con cuello, tira central, cintas laterales y bajo dorados, y tres tachones de oro.
	make.block(
		Vector3.new(width + 0.12, height * 0.94, depth + 0.16),
		MAGE_INDIGO,
		FABRIC,
		CFrame.new(0, -height * 0.02, 0)
	)
	make.block(Vector3.new(width * 0.7, 0.18, depth + 0.24), GOLD_TRIM, FABRIC, CFrame.new(0, height / 2 - 0.04, 0))
	make.block(Vector3.new(0.14, height * 0.8, 0.04), GOLD_TRIM, FABRIC, CFrame.new(0, -height * 0.08, front))
	make.block(
		Vector3.new(width + 0.16, 0.1, depth + 0.2),
		GOLD_TRIM,
		FABRIC,
		CFrame.new(0, -height * 0.02 - height * 0.47 + 0.05, 0)
	)
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.07, height * 0.84, 0.04),
			GOLD_TRIM,
			FABRIC,
			CFrame.new(side * width * 0.43, -height * 0.04, front)
		)
	end
	for _, studY in { 0.3, 0.05, -0.2 } do
		make.ball(0.1, GOLD_TRIM, SMOOTH, CFrame.new(0, height * studY, front - 0.04))
	end
	-- Runa del pecho: círculo de neón con un triángulo y un punto dentro, a un lado de la tira; al otro,
	-- una piedra rúnica.
	local chest = CFrame.new(width * 0.26, height * 0.14, front - 0.02)
	hoop(make, chest, 0.3, 8, 0.05, RUNE, NEON)
	for index = 0, 2 do
		make.block(
			Vector3.new(0.3, 0.05, 0.04),
			RUNE,
			NEON,
			chest * CFrame.Angles(0, 0, index * 2 * math.pi / 3) * CFrame.new(0, -0.08, 0)
		)
	end
	make.ball(0.08, RUNE, NEON, chest)
	local chestStone = CFrame.new(-width * 0.26, height * 0.14, front - 0.04)
	make.block(Vector3.new(0.34, 0.4, 0.08), STONE, SLATE, chestStone)
	make.block(Vector3.new(0.07, 0.24, 0.03), RUNE, NEON, chestStone * CFrame.new(0, 0, -0.05))
	-- Detrás (lo que el jugador ve siempre): un sello grande sobre un fondo añil oscuro, con un círculo de
	-- doce tramos de neón, cuatro marcas en cruz por fuera, un triángulo con un rombo y tres puntos en
	-- los vértices; es más grande y detallado que el atrapasueños del manto de amuletos.
	make.block(
		Vector3.new(width * 0.9, height * 0.92, 0.05),
		MAGE_INDIGO_DARK,
		FABRIC,
		CFrame.new(0, -height * 0.02, back - 0.01)
	)
	local seal = CFrame.new(0, height * 0.02, back + 0.05)
	hoop(make, seal, 0.7, 12, 0.08, RUNE, NEON)
	for index = 0, 3 do
		make.block(
			Vector3.new(0.07, 0.2, 0.05),
			RUNE,
			NEON,
			seal * CFrame.Angles(0, 0, index * math.pi / 2) * CFrame.new(0, 0.88, 0)
		)
	end
	for index = 0, 2 do
		make.block(
			Vector3.new(0.9, 0.06, 0.05),
			RUNE,
			NEON,
			seal * CFrame.Angles(0, 0, index * 2 * math.pi / 3) * CFrame.new(0, -0.25, 0)
		)
		make.ball(0.12, RUNE, NEON, seal * CFrame.Angles(0, 0, index * 2 * math.pi / 3) * CFrame.new(0, 0.5, 0))
	end
	make.block(Vector3.new(0.18, 0.18, 0.05), RUNE, NEON, seal * CFrame.Angles(0, 0, math.pi / 4))
	-- Dos talismanes de piedra rúnica con una cuenta de oro colgando de los hombros por detrás.
	for side = -1, 1, 2 do
		local cord = CFrame.new(side * width * 0.46, height / 2 - 0.3, back + 0.12)
		make.block(Vector3.new(0.04, 0.5, 0.04), FIBER, FABRIC, cord)
		make.block(Vector3.new(0.22, 0.28, 0.08), STONE, SLATE, cord * CFrame.new(0, -0.38, 0.02))
		make.block(Vector3.new(0.05, 0.18, 0.03), RUNE, NEON, cord * CFrame.new(0, -0.38, 0.07))
		make.ball(0.12, GOLD_TRIM, SMOOTH, cord * CFrame.new(0, -0.58, 0.02))
	end

	-- Faja dorada con tres piedras rúnicas y dos borlas añil colgando.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.08)
	waist.block(Vector3.new(hipWidth + 0.14, 0.2, hipDepth + 0.14), GOLD_TRIM, FABRIC, CFrame.new(0, 0.06, 0))
	waist.ball(0.2, GOLD_TRIM, SMOOTH, CFrame.new(0, 0.06, beltFront - 0.04))
	for _, x in { -0.3, 0, 0.3 } do
		local stone = CFrame.new(x * hipWidth, -0.2, beltFront - 0.04)
		waist.block(Vector3.new(0.2, 0.24, 0.08), STONE, SLATE, stone)
		waist.block(Vector3.new(0.05, 0.14, 0.03), RUNE, NEON, stone * CFrame.new(0, 0, -0.05))
	end
	for side = -1, 1, 2 do
		waist.fang(
			0.3,
			0.14,
			MAGE_INDIGO,
			FABRIC,
			CFrame.new(side * hipWidth * 0.44 + 0.07, 0.0, beltFront - 0.04) * CFrame.Angles(0, 0, math.pi)
		)
	end

	for side = -1, 1, 2 do
		-- Hombrera: disco plano añil con aro dorado y, encima, un cráneo de mono de ojos encendidos.
		local arm = body.upperArm[side]
		local center = discPauldron(arm, side, MAGE_INDIGO_DARK, GOLD_TRIM, FABRIC)
		runeSkull(
			arm,
			center * CFrame.new(side * arm.size.X * 0.1, 0.3, 0) * CFrame.Angles(0, -side * math.rad(30), 0),
			0.9
		)
		band(arm, -arm.size.Y * 0.14, 0.12, 0.08, GOLD_TRIM, FABRIC)
		-- Brazal añil con runas que brillan y bandas doradas.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, -fs.Y * 0.05, fs.Y * 0.5, 0.08, MAGE_INDIGO_DARK, FABRIC)
		band(forearm, -fs.Y * 0.05, 0.06, 0.12, RUNE, NEON)
		band(forearm, -fs.Y * 0.38, 0.1, 0.1, GOLD_TRIM, FABRIC)
		for _, z in { -0.22, 0.22 } do
			forearm.block(
				Vector3.new(0.05, 0.16, 0.05),
				RUNE,
				NEON,
				CFrame.new(side * (fs.X / 2 + 0.08), fs.Y * 0.12, z * fs.Z)
			)
		end
		-- Faldón añil con ribete dorado, una runa y una borla dorada en el muslo.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.05)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.86, ls.Y * 0.42, 0.08), MAGE_INDIGO, FABRIC, flap)
		leg.block(Vector3.new(ls.X * 0.86 + 0.04, 0.08, 0.1), GOLD_TRIM, FABRIC, flap * CFrame.new(0, -ls.Y * 0.21, 0))
		leg.block(Vector3.new(0.06, 0.2, 0.03), RUNE, NEON, flap * CFrame.new(0, 0.02, -0.06))
		leg.fang(
			0.24,
			0.12,
			GOLD_TRIM,
			FABRIC,
			flap * CFrame.new(0.06, -ls.Y * 0.21, -0.02) * CFrame.Angles(0, 0, math.pi)
		)
	end
end

local function crystalMantle(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	local back = depth / 2
	-- Túnica añil oscura con una tira de plata, dos cintas laterales y el bajo de plata.
	make.block(
		Vector3.new(width + 0.12, height * 0.94, depth + 0.16),
		MAGE_INDIGO_DARK,
		FABRIC,
		CFrame.new(0, -height * 0.02, 0)
	)
	local trim = make.block(Vector3.new(0.14, height * 0.8, 0.04), SILVER, METAL, CFrame.new(0, -height * 0.08, front))
	trim.Reflectance = 0.25
	for side = -1, 1, 2 do
		local ribbon = make.block(
			Vector3.new(0.07, height * 0.84, 0.04),
			SILVER,
			METAL,
			CFrame.new(side * width * 0.43, -height * 0.04, front)
		)
		ribbon.Reflectance = 0.25
	end
	local hemBand = make.block(
		Vector3.new(width + 0.16, 0.1, depth + 0.2),
		SILVER,
		METAL,
		CFrame.new(0, -height * 0.02 - height * 0.47 + 0.05, 0)
	)
	hemBand.Reflectance = 0.25
	-- Manto de pelaje plateado sobre los hombros, cuello alto en tres escalones por detrás y capa con
	-- flecos de pelaje y de cristal.
	local capeBottom = silverCape(make, 5)
	for index = 0, 2 do
		make.block(
			Vector3.new(width * (0.84 - index * 0.2), 0.3, 0.3),
			if index % 2 == 0 then SILVER_FUR_DARK else SILVER_FUR,
			FABRIC,
			CFrame.new(0, height / 2 + 0.28 + index * 0.26, depth / 2 + 0.12 - index * 0.02)
		)
	end
	for _, x in { -0.4, -0.2, 0, 0.2, 0.4 } do
		crystal(make, Vector3.new(x * width, capeBottom + 0.06, back + 0.42), Vector3.new(0, -1, 0), 0.46, 0.16)
	end
	-- Detrás (lo que el jugador ve siempre): disco de plata con un núcleo que brilla, rodeado de runas, del
	-- que sale una corona de cristales hacia arriba, que asoma por encima de los hombros.
	-- (Alto en la espalda y con cristales largos: si no, se queda en una estrella en mitad de la capa.)
	local seal = CFrame.new(0, height * 0.22, back + 0.28)
	local disc = make.rod(0.08, 0.62, SILVER, METAL, seal * FACING)
	disc.Reflectance = 0.35
	make.rod(0.06, 0.42, MAGE_INDIGO_DARK, FABRIC, seal * CFrame.new(0, 0, 0.04) * FACING)
	make.ball(0.2, RUNE, NEON, seal * CFrame.new(0, 0, 0.08))
	hoop(make, seal * CFrame.new(0, 0, 0.02), 0.56, 12, 0.06, RUNE, NEON)
	-- Marcas de runa por debajo del círculo (por arriba las tapan los cristales) y una a cada lado.
	for index = -2, 2 do
		make.block(
			Vector3.new(0.06, 0.18, 0.05),
			RUNE,
			NEON,
			seal * CFrame.Angles(0, 0, math.pi + index * 0.42) * CFrame.new(0, 0.74, 0.02)
		)
	end
	for side = -1, 1, 2 do
		make.block(Vector3.new(0.18, 0.06, 0.05), RUNE, NEON, seal * CFrame.new(side * 0.74, 0, 0.02))
	end
	-- Nueve cristales grandes en abanico y, entre ellos y más cortos, cuatro más.
	local crystals = 9
	for index = 0, crystals - 1 do
		local angle = math.rad(-80 + index * 160 / (crystals - 1))
		local direction = Vector3.new(math.sin(angle), math.cos(angle), 0.12)
		local length = 1.55 - math.abs(angle) * 0.6
		crystal(make, seal.Position + direction * 0.14 + Vector3.new(0, 0, 0.1), direction, length, 0.34)
	end
	for _, degrees in { -62, -22, 22, 62 } do
		local angle = math.rad(degrees)
		local direction = Vector3.new(math.sin(angle), math.cos(angle), 0.3)
		crystal(make, seal.Position + direction * 0.14 + Vector3.new(0, 0, 0.2), direction, 0.8, 0.24)
	end
	-- Cadena de plata cruzada con tres cristales colgando y, arriba, el broche de cristal.
	strap(
		make,
		Vector3.new(-width * 0.38, height / 2 - 0.1, front - 0.05),
		Vector3.new(width * 0.38, -height * 0.18, front - 0.05),
		0.07,
		SILVER,
		METAL
	)
	for _, t in { 0.25, 0.5, 0.75 } do
		local x = -width * 0.38 + width * 0.76 * t
		local y = (height / 2 - 0.1) + (-height * 0.18 - (height / 2 - 0.1)) * t
		crystal(make, Vector3.new(x, y - 0.03, front - 0.09), Vector3.new(0, -1, -0.1), 0.26, 0.12)
	end
	local brooch = CFrame.new(0, height / 2 - 0.2, front - 0.1)
	local rim = make.rod(0.06, 0.34, SILVER, METAL, brooch * FACING)
	rim.Reflectance = 0.35
	local clasp = make.rod(0.06, 0.46, SILVER_FUR_DARK, METAL, brooch * CFrame.new(0, 0, 0.02) * FACING)
	clasp.Reflectance = 0.15
	crystal(make, brooch.Position + Vector3.new(0, -0.08, -0.06), Vector3.new(0, 1, -0.3), 0.32, 0.16)

	-- Faja oscura con hebilla de plata, dos remaches, dos borlas y un cristal colgando.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	waist.block(Vector3.new(hipWidth + 0.16, 0.22, hipDepth + 0.18), MAGE_INDIGO, FABRIC, CFrame.new(0, 0.06, 0))
	local buckle = waist.block(Vector3.new(0.34, 0.28, 0.08), SILVER, METAL, CFrame.new(0, 0.06, beltFront - 0.02))
	buckle.Reflectance = 0.35
	crystal(waist, Vector3.new(0, -0.08, beltFront - 0.06), Vector3.new(0, -1, 0), 0.34, 0.16)
	for side = -1, 1, 2 do
		local stud = waist.ball(0.1, SILVER, METAL, CFrame.new(side * hipWidth * 0.34, 0.06, beltFront - 0.04))
		stud.Reflectance = 0.25
		waist.fang(
			0.28,
			0.14,
			MAGE_INDIGO,
			FABRIC,
			CFrame.new(side * hipWidth * 0.44 + 0.07, -0.02, beltFront - 0.04) * CFrame.Angles(0, 0, math.pi)
		)
	end

	for side = -1, 1, 2 do
		-- Hombros de pelaje plateado (losa con canto de plata) con tres cristales hacia fuera que salen
		-- de la losa.
		local arm = body.upperArm[side]
		local as = arm.size
		local top = as.Y / 2
		furSlabPauldron(arm, side)
		for index, z in { -0.28, 0, 0.28 } do
			crystal(
				arm,
				Vector3.new(side * as.X * 0.45, top + 0.34, z * as.Z),
				Vector3.new(side * 0.6, 1, z * 1.5),
				if index == 2 then 0.62 else 0.46,
				0.2
			)
		end
		-- Brazal añil con puño plateado de plata y de pelaje, dos tiras de runa y un cristal por fuera.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, 0.04, fs.Y * 0.5, 0.08, MAGE_INDIGO, FABRIC)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, SILVER_FUR, FABRIC)
		local cuff = band(forearm, -fs.Y / 2 + 0.26, 0.08, 0.14, SILVER, METAL)
		cuff.Reflectance = 0.3
		for _, z in { -0.22, 0.22 } do
			forearm.block(
				Vector3.new(0.05, 0.16, 0.05),
				RUNE,
				NEON,
				CFrame.new(side * (fs.X / 2 + 0.06), fs.Y * 0.12, z * fs.Z)
			)
		end
		crystal(forearm, Vector3.new(side * (fs.X / 2 + 0.04), 0.06, 0), Vector3.new(side, 0.6, 0), 0.32, 0.16)
		-- Faldón de pelaje plateado en el muslo con una runa, el bajo de plata y un cristal colgando.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), SILVER_FUR, FABRIC, flap)
		leg.block(Vector3.new(0.06, ls.Y * 0.26, 0.04), RUNE, NEON, flap * CFrame.new(0, 0, -0.07))
		local flapHem =
			leg.block(Vector3.new(ls.X * 0.9 + 0.04, 0.07, 0.12), SILVER, METAL, flap * CFrame.new(0, -ls.Y * 0.2, 0))
		flapHem.Reflectance = 0.25
		crystal(leg, (flap * CFrame.new(0, -ls.Y * 0.2 - 0.03, -0.06)).Position, Vector3.new(0, -1, -0.1), 0.26, 0.12)
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
	local pouchAt = from:Lerp(to, 0.8)
	herbPouch(make, CFrame.new(pouchAt.X, pouchAt.Y - 0.1, back + 0.1) * CFrame.Angles(0, math.pi, 0), LEAF_DARK)
	-- Hombreras de disco plano de lino con una hoja encima.
	for side = -1, 1, 2 do
		local arm = body.upperArm[side]
		local center = discPauldron(arm, side, LINEN, LEATHER, FABRIC)
		leaf(arm, 0.44, if side == 1 then LEAF else LEAF_DARK, center * CFrame.Angles(-math.pi / 2, 0, side * 0.6))
	end
	-- Detrás (lo que el jugador ve siempre): un manojo grande de hierbas atado a la bandolera, abierto en
	-- abanico hacia arriba (tres verdes) con una flor roja arriba, y dos frasquitos colgados abajo.
	local knot = from:Lerp(to, 0.5)
	local tie = CFrame.new(knot.X, knot.Y, back + 0.12)
	local herbs = 9
	local greens = { LEAF, LEAF_LIGHT, LEAF_DARK }
	for index = 0, herbs - 1 do
		local angle = -1.05 + index * 2.1 / (herbs - 1)
		local length = 1.2 - math.abs(angle) * 0.3
		make.block(
			Vector3.new(0.28, length, 0.05),
			greens[index % 3 + 1],
			SMOOTH,
			tie * CFrame.Angles(0, 0, -angle) * CFrame.new(0, length / 2 + 0.05, 0.02 * (index % 2))
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
	-- Flor roja de cuatro pétalos con el centro dorado.
	local flower = tie * CFrame.new(0, 1.0, 0.1)
	for petal = 0, 3 do
		local angle = petal * math.pi / 2
		make.block(
			Vector3.new(0.16, 0.16, 0.05),
			FLOWER,
			SMOOTH,
			flower * CFrame.new(math.sin(angle) * 0.15, math.cos(angle) * 0.15, 0)
		)
	end
	make.ball(0.14, GOLD_TRIM, SMOOTH, flower * CFrame.new(0, 0, 0.03))
	for index, x in { -width * 0.28, width * 0.1 } do
		local base = CFrame.new(x, -height / 2 + 0.16, back + 0.12)
		make.block(Vector3.new(0.05, 0.16, 0.04), LEATHER, LEATHER_MATERIAL, base * CFrame.new(0, 0.3, -0.01))
		flask(make, base, 0.26, index == 2)
	end

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
		-- Faldón de lino en el muslo con el borde de cuero.
		local leg = body.upperLeg[side]
		local ls = leg.size
		leg.block(
			Vector3.new(ls.X * 0.9, ls.Y * 0.3, 0.07),
			LINEN,
			FABRIC,
			CFrame.new(0, ls.Y * 0.34, -(ls.Z / 2 + 0.05))
		)
		leg.block(
			Vector3.new(ls.X * 0.9, 0.06, 0.1),
			LEATHER,
			LEATHER_MATERIAL,
			CFrame.new(0, ls.Y * 0.19, -(ls.Z / 2 + 0.05))
		)
	end
end

local function healerPlastron(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.06)
	local back = depth / 2 + 0.06
	make.block(Vector3.new(width + 0.1, height * 0.94, depth + 0.12), LINEN, FABRIC, CFrame.new(0, -height * 0.02, 0))
	-- Peto de hueso blanco sobre un borde más oscuro, con remaches, sujeto con correas por encima de los hombros.
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
		for rivetY = -1, 1, 2 do
			make.ball(0.1, BONE_DARK, SMOOTH, plate * CFrame.new(side * width * 0.37, rivetY * height * 0.3, -0.1))
		end
	end
	-- Cruz de hojas con una flor roja de cuatro pétalos y el centro dorado.
	local cross = plate * CFrame.new(0, height * 0.04, -0.1)
	for index = 0, 3 do
		leaf(
			make,
			0.52,
			if index % 2 == 0 then LEAF else LEAF_DARK,
			cross * CFrame.Angles(0, 0, index * math.pi / 2) * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, math.pi, 0)
		)
	end
	for petal = 0, 3 do
		local angle = petal * math.pi / 2
		make.block(
			Vector3.new(0.14, 0.14, 0.05),
			FLOWER,
			SMOOTH,
			cross * CFrame.new(math.sin(angle) * 0.13, math.cos(angle) * 0.13, -0.06)
		)
	end
	make.ball(0.14, GOLD_TRIM, SMOOTH, cross * CFrame.new(0, 0, -0.09))
	-- Detrás (lo que el jugador ve siempre): mochila de cuero con correas en un bastidor de madera, con
	-- frascos de poción encima y a los lados, un rollo de manta abajo y hierbas asomando por detrás.
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
		-- Bolsa lateral de cuero bajo el frasco.
		make.block(
			Vector3.new(0.2, 0.3, 0.3),
			LEATHER,
			LEATHER_MATERIAL,
			pack * CFrame.new(side * (width * 0.31 + 0.12), -height * 0.34, 0.04)
		)
	end
	for _, y in { height * 0.4, -height * 0.32 } do
		make.rod(width * 0.76, 0.07, BARK, WOOD, pack * CFrame.new(0, y, -0.12))
	end
	make.rod(width * 0.7, 0.3, LINEN, FABRIC, pack * CFrame.new(0, -height * 0.4, 0.04))
	for _, x in { -0.26, 0.26 } do
		make.block(
			Vector3.new(0.08, 0.38, 0.38),
			LEATHER_DARK,
			LEATHER_MATERIAL,
			pack * CFrame.new(x * width, -height * 0.4, 0.04)
		)
	end
	local top = pack * CFrame.new(0, height * 0.32, 0)
	for index = -2, 2 do
		leaf(
			make,
			0.5 - math.abs(index) * 0.04,
			if index == 0 then LEAF_LIGHT elseif index % 2 == 0 then LEAF_DARK else LEAF,
			top * CFrame.new(index * 0.17, 0.22, -0.12) * CFrame.Angles(0, 0, -index * 0.35)
		)
	end
	for index, x in { -0.32, 0, 0.32 } do
		flask(make, top * CFrame.new(x * width * 0.5, 0, 0.04), if index == 2 then 0.36 else 0.3, false)
	end
	for side = -1, 1, 2 do
		flask(make, pack * CFrame.new(side * (width * 0.31 + 0.13), -height * 0.2, 0.06), 0.28, false)
	end

	-- Cinturón de cuero con dos rollos de venda, la hebilla de hueso y las puntas de venda colgando.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.08)
	waist.block(Vector3.new(hipWidth + 0.14, 0.2, hipDepth + 0.14), LEATHER, LEATHER_MATERIAL, CFrame.new(0, 0.06, 0))
	waist.block(Vector3.new(0.22, 0.22, 0.06), BONE, SMOOTH, CFrame.new(0, 0.06, beltFront - 0.02))
	for _, x in { -0.32, 0.32 } do
		waist.rod(0.24, 0.22, PAINT_WHITE, FABRIC, CFrame.new(x * hipWidth, -0.06, beltFront - 0.1) * UPRIGHT)
		waist.block(
			Vector3.new(0.1, 0.3, 0.04),
			PAINT_WHITE,
			FABRIC,
			CFrame.new(x * hipWidth * 0.62, -0.16, beltFront - 0.04)
		)
	end

	for side = -1, 1, 2 do
		-- Hombrera de disco de hueso con tres hojas en abanico y un remache en el centro.
		local arm = body.upperArm[side]
		local center = discPauldron(arm, side, THICK_BONE, BONE_DARK, SMOOTH)
		for index, yaw in { -0.7, 0, 0.7 } do
			leaf(
				arm,
				0.5,
				if index == 2 then LEAF_LIGHT elseif index == 1 then LEAF else LEAF_DARK,
				center
					* CFrame.Angles(0, -side * math.pi / 2 + yaw, 0)
					* CFrame.Angles(-math.pi / 2, 0, 0)
					* CFrame.new(0, 0.24, 0)
			)
		end
		arm.ball(0.18, BONE, SMOOTH, center * CFrame.new(0, 0.06, 0))
		band(arm, -arm.size.Y * 0.14, 0.1, 0.08, LEATHER, LEATHER_MATERIAL)
		-- Vendas en el antebrazo.
		local forearm = body.lowerArm[side]
		band(forearm, -forearm.size.Y * 0.1, 0.12, 0.06, PAINT_WHITE, FABRIC, 0.12)
		band(forearm, -forearm.size.Y * 0.28, 0.12, 0.06, PAINT_WHITE, FABRIC, -0.12)
		band(forearm, -forearm.size.Y * 0.44, 0.1, 0.06, PAINT_WHITE, FABRIC, 0.12)
		-- Bolsa de cuero atada al muslo, con una hoja asomando y un botón de hueso.
		local leg = body.upperLeg[side]
		local ls = leg.size
		band(leg, ls.Y * 0.2, 0.1, 0.06, LEATHER_DARK, LEATHER_MATERIAL)
		local bag = CFrame.new(side * (ls.X / 2 + 0.06), ls.Y * 0.08, 0)
		leg.block(Vector3.new(0.14, 0.34, 0.42), HUNTER_LEATHER, LEATHER_MATERIAL, bag)
		leg.block(Vector3.new(0.18, 0.12, 0.46), LEATHER_DARK, LEATHER_MATERIAL, bag * CFrame.new(0, 0.14, 0))
		leg.ball(0.1, BONE, SMOOTH, bag * CFrame.new(side * 0.09, 0.1, 0))
		leaf(
			leg,
			0.4,
			LEAF,
			bag
				* CFrame.new(side * 0.02, 0.32, 0)
				* CFrame.Angles(0, side * math.rad(90), 0)
				* CFrame.Angles(0, 0, side * 0.3)
		)
	end
end

local function silverHealer(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	local back = depth / 2
	-- Túnica de lino con el bajo y una tira central de plata.
	make.block(Vector3.new(width + 0.12, height * 0.94, depth + 0.16), LINEN, FABRIC, CFrame.new(0, -height * 0.02, 0))
	local tunicHem = make.block(
		Vector3.new(width + 0.16, 0.1, depth + 0.2),
		SILVER,
		METAL,
		CFrame.new(0, -height * 0.02 - height * 0.47 + 0.05, 0)
	)
	tunicHem.Reflectance = 0.25
	local tunicTrim =
		make.block(Vector3.new(0.1, height * 0.8, 0.04), SILVER, METAL, CFrame.new(0, -height * 0.08, front))
	tunicTrim.Reflectance = 0.25
	-- Manto y capa de pelaje plateado con flecos (silverCape) y dos solapas de pelaje por delante.
	silverCape(make, 5)
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(width * 0.3, 0.24, 0.3),
			SILVER_FUR,
			FABRIC,
			CFrame.new(side * width * 0.32, height / 2 - 0.06, front + 0.02)
		)
	end
	-- Detrás (lo que el jugador ve siempre): tótem sanador pequeño atado a la capa, con su gema verde
	-- brillando por encima de los hombros, un abanico de hojas en la base, correas a los hombros y frascos
	-- brillantes colgando a los lados y en el suelo del tótem.
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
	for index, angle in { -1.3, -0.8, -0.3, 0.3, 0.8, 1.3 } do
		leaf(
			make,
			0.7,
			if index % 3 == 0 then LEAF_LIGHT elseif index % 2 == 0 then LEAF_DARK else LEAF,
			totemBase * CFrame.new(0, 0.12, -0.1) * CFrame.Angles(0, 0, -angle) * CFrame.new(0, 0.36, 0)
		)
	end
	for side = -1, 1, 2 do
		strap(
			make,
			Vector3.new(side * 0.3, -height * 0.3 + 0.9, back + 0.3),
			Vector3.new(side * width * 0.4, height / 2 - 0.1, back + 0.3),
			0.1,
			LEATHER_DARK,
			LEATHER_MATERIAL
		)
		local cord = CFrame.new(side * width * 0.36, height * 0.22, back + 0.26)
		make.block(Vector3.new(0.04, 0.2, 0.04), FIBER, FABRIC, cord)
		local knot = make.ball(0.1, SILVER, METAL, cord * CFrame.new(0, 0.1, 0))
		knot.Reflectance = 0.25
		flask(make, cord * CFrame.new(0, -0.45, 0.02), 0.26, true)
		flask(make, CFrame.new(side * 0.9, -height * 0.3 - 0.02, back + 0.4), 0.24, true)
	end
	-- Bandolera del hombro derecho a la cadera izquierda con tres frascos que brillan y una bolsita de hierbas.
	local from = Vector3.new(width * 0.3, height / 2 - 0.02, front - 0.03)
	local to = Vector3.new(-width * 0.4, -height / 2 + 0.12, front - 0.03)
	strap(make, from, to, 0.16, LEATHER_DARK, LEATHER_MATERIAL)
	for _, t in { 0.3, 0.52, 0.74 } do
		local at = from:Lerp(to, t)
		flask(make, CFrame.new(at.X, at.Y - 0.32, at.Z - 0.1), 0.22, true)
	end
	for _, t in { 0, 1 } do
		local at = from:Lerp(to, t)
		local buckle = make.ball(0.14, SILVER, METAL, CFrame.new(at.X, at.Y, at.Z - 0.1))
		buckle.Reflectance = 0.25
	end
	local pouchAt = from:Lerp(to, 0.9)
	herbPouch(make, CFrame.new(pouchAt.X, pouchAt.Y - 0.12, front - 0.14), LEAF)
	-- Broche de plata con una gema verde que cierra el manto, entre dos hojas.
	local brooch = CFrame.new(-width * 0.22, height / 2 - 0.16, front - 0.1)
	local rim = make.rod(0.06, 0.32, SILVER, METAL, brooch * FACING)
	rim.Reflectance = 0.35
	make.ball(0.18, HEAL_GLOW, NEON, brooch * CFrame.new(0, 0, -0.05))
	for side = -1, 1, 2 do
		leaf(
			make,
			0.4,
			if side == 1 then LEAF else LEAF_DARK,
			brooch * CFrame.new(side * 0.22, -0.04, -0.02) * CFrame.Angles(0, math.pi, side * 1.1)
		)
	end

	-- Cinturón oscuro con hebilla de plata, un rollo de venda, un frasco que brilla y una bolsita de hierbas.
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
	waist.block(Vector3.new(0.1, 0.3, 0.04), PAINT_WHITE, FABRIC, CFrame.new(hipWidth * 0.2, -0.18, beltFront - 0.04))
	flask(waist, CFrame.new(-hipWidth * 0.34, -0.3, beltFront - 0.12), 0.22, true)
	herbPouch(waist, CFrame.new(-hipWidth * 0.16, -0.14, beltFront - 0.1), LEAF_DARK)

	for side = -1, 1, 2 do
		-- Hombro: losa de pelaje plateado con tres hojas tumbadas encima (se abren hacia fuera).
		local arm = body.upperArm[side]
		local center = furSlabPauldron(arm, side)
		for index, yaw in { -0.7, 0, 0.7 } do
			leaf(
				arm,
				0.5,
				if index == 2 then LEAF_LIGHT elseif index == 1 then LEAF else LEAF_DARK,
				center
					* CFrame.Angles(0, -side * math.pi / 2 + yaw, 0)
					* CFrame.Angles(-math.pi / 2, 0, 0)
					* CFrame.new(0, 0.24, 0)
			)
		end
		-- Dos vendas y un puño de pelaje plateado en el antebrazo.
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, fs.Y * 0.05, 0.12, 0.06, PAINT_WHITE, FABRIC, 0.12)
		band(forearm, -fs.Y * 0.14, 0.12, 0.06, PAINT_WHITE, FABRIC, -0.12)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, SILVER_FUR, FABRIC)
		-- Faldón de pelaje plateado en el muslo con el bajo de plata y una hoja.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), SILVER_FUR, FABRIC, flap)
		local flapHem =
			leg.block(Vector3.new(ls.X * 0.9 + 0.04, 0.07, 0.12), SILVER, METAL, flap * CFrame.new(0, -ls.Y * 0.2, 0))
		flapHem.Reflectance = 0.25
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

-- Gota de lava (o de "color", el azufre) que cuelga de "at" (su base), de "length" de largo.
local function lavaDrip(make: Builder, at: CFrame, length: number, color: Color3?)
	local width = length * 0.45
	make.fang(
		length,
		width,
		color or MAGMA,
		NEON,
		at * CFrame.new(width / 2, 0, width / 2) * CFrame.Angles(0, 0, math.pi)
	)
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

-- Llamas en píxeles (las de un videojuego: con puntas en pico se leían como hielo), de arriba abajo: X el
-- fuego de fuera, C el de en medio y W el corazón más claro, que sobresalen más. Los colores los pone la
-- paleta de cada uno (LAVA_FLAME aquí; el fuego azul, los trajes de la temporada 1).
local BIG_FLAME = {
	"....X.....",
	"...XX...X.",
	"..XXX..XX.",
	"..XCXX.XX.",
	".XXCCXXXX.",
	".XCCCCXCX.",
	"XXCWWCCCXX",
	"XCCWWWCCCX",
	"XCWWWWWCCX",
	".XCWWWWCX.",
	"..XXCCXX..",
}
local SMALL_FLAME = {
	"..X..",
	".XX.X",
	".XCXX",
	"XCWCX",
	"XCWCX",
	".XXX.",
}
local FLAME_RELIEF: { [string]: number } = { X = 0.5, C = 0.75, W = 1 }
local LAVA_FLAME: { [string]: Color3 } = { X = MAGMA, C = EMBER, W = Color3.fromRGB(255, 240, 170) }

-- Llama en píxeles de "rows" con los colores de "palette" y el pie (el centro de la fila de abajo) en
-- "at", celdas de "cell" studs en el plano XY de "at" y relieve hacia su +Z (el lado que más se mira); con
-- "mirror", de lado contrario. Cada tramo seguido de un color es una sola pieza. Devuelve una del pie, para
-- echar llamas o humo de ahí.
local function pixelFlame(
	make: Builder,
	rows: { string },
	palette: { [string]: Color3 },
	at: CFrame,
	cell: number,
	mirror: boolean
): BasePart
	local columns = #rows[1]
	local foot: BasePart? = nil
	for row, line in rows do
		local y = (#rows - row + 0.5) * cell
		local start = 1
		while start <= columns do
			local char = string.sub(line, start, start)
			local stop = start
			while stop < columns and string.sub(line, stop + 1, stop + 1) == char do
				stop += 1
			end
			local color = palette[char]
			if color then
				local x = ((start + stop) / 2 - (columns + 1) / 2) * cell * (if mirror then -1 else 1)
				local relief = FLAME_RELIEF[char] * cell
				local piece = make.block(
					Vector3.new((stop - start + 1) * cell, cell, relief),
					color,
					NEON,
					at * CFrame.new(x, y, relief / 2)
				)
				if row == #rows and not foot then
					foot = piece
				end
			end
			start = stop + 1
		end
	end
	return foot :: BasePart
end

-- Cráneo de mono de obsidiana con la cara hacia la -Z de "at", "scale" veces su tamaño: cráneo, ceja de
-- basalto, ojos de lava, hocico y dos colmillos de brasa (la calavera del rango II, hecha de obsidiana).
local function obsidianSkull(make: Builder, at: CFrame, scale: number)
	local function on(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x * scale, y * scale, z * scale)
	end
	make.block(Vector3.new(0.8, 0.7, 0.86) * scale, OBSIDIAN, SMOOTH, on(0, 0.06, 0.06))
	make.block(Vector3.new(0.84, 0.12, 0.2) * scale, BASALT, BASALT_MATERIAL, on(0, 0.17, -0.36))
	for eye = -1, 1, 2 do
		make.ball(0.2 * scale, MAGMA, NEON, on(eye * 0.15, -0.03, -0.36))
	end
	make.block(Vector3.new(0.4, 0.24, 0.3) * scale, BASALT_DARK, BASALT_MATERIAL, on(0, -0.2, -0.4))
	for tooth = -1, 1, 2 do
		make.fang(
			0.18 * scale,
			0.07 * scale,
			EMBER,
			NEON,
			on(tooth * 0.12 + 0.035, -0.31, -0.47) * CFrame.Angles(0, 0, math.pi)
		)
	end
end

-- Hombrera de losa del rango IV (la forma de las del rango III, con la lava de la temporada 1): franja de
-- lava bajo el canto de obsidiana, losa de "pad", un escalón de obsidiana encima con la llama de lava en
-- píxeles que echa humo y chispas, grietas de lava en la losa, tres gotas colgando y, según "spikes",
-- cristales de obsidiana hundidos en lava ("shard"), garras de obsidiana ("claw"), cristales de lava
-- ("crystal") o de azufre ("sulfur"). Las puntas van lejos de la llama, que ocupa el centro.
local function lavaPauldron(arm: Builder, side: number, pad: Color3, padMaterial: Enum.Material, spikes: string)
	local as = arm.size
	local top = as.Y / 2
	local cx = side * 0.1
	arm.block(Vector3.new(as.X + 0.64, 0.08, as.Z + 0.64), MAGMA, NEON, CFrame.new(cx, top + 0.01, 0))
	arm.block(Vector3.new(as.X + 0.5, 0.08, as.Z + 0.5), OBSIDIAN, SMOOTH, CFrame.new(cx, top + 0.05, 0))
	arm.block(Vector3.new(as.X + 0.42, 0.22, as.Z + 0.42), pad, padMaterial, CFrame.new(cx, top + 0.2, 0))
	arm.block(Vector3.new(as.X + 0.1, 0.16, as.Z + 0.1), OBSIDIAN, SMOOTH, CFrame.new(cx, top + 0.38, 0))
	local stepTop = top + 0.46
	-- Grietas de lava en el borde de la losa que asoma alrededor del escalón.
	for _, z in { -1, 1 } do
		arm.block(
			Vector3.new(0.34, 0.03, 0.06),
			MAGMA,
			NEON,
			CFrame.new(cx + side * 0.04, top + 0.315, z * (as.Z / 2 + 0.13))
		)
	end
	arm.block(Vector3.new(0.06, 0.03, 0.4), MAGMA, NEON, CFrame.new(cx + side * (as.X / 2 + 0.13), top + 0.315, 0.04))
	for index, z in { -0.3, 0, 0.3 } do
		lavaDrip(arm, CFrame.new(cx + side * (as.X / 2 + 0.2), top - 0.03, z * as.Z), if index == 2 then 0.42 else 0.28)
	end
	local far = as.Z * 0.42
	local spots = {
		{ x = 0.1, z = far, length = 0.8, width = 0.3 },
		{ x = 0.1, z = -far, length = 0.64, width = 0.26 },
		{ x = 0.44, z = 0, length = 0.55, width = 0.24 },
	}
	for index, spot in spots do
		local base = Vector3.new(side * spot.x, stepTop - 0.02, spot.z)
		local direction = Vector3.new(side * (0.25 + spot.x), 1, spot.z * 0.9)
		if spikes == "crystal" then
			fireCrystal(arm, base, direction, spot.length, spot.width, LAVA_ROBE, MAGMA)
		elseif index < 3 or spikes == "shard" then
			lavaShard(arm, base, direction, spot.length, spot.width)
		elseif spikes == "sulfur" then
			for _, z in { -0.2, 0.2 } do
				fireCrystal(
					arm,
					base + Vector3.new(0, 0, z * as.Z),
					Vector3.new(direction.X, 1, z * 1.5),
					spot.length * 0.9,
					0.2,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end
	end
	if spikes == "claw" then
		for _, z in { -0.3, 0, 0.3 } do
			arm.fang(
				0.46,
				0.16,
				OBSIDIAN,
				SMOOTH,
				CFrame.new(side * (as.X * 0.55) - 0.08, top + 0.2, z * as.Z + 0.08) * CFrame.Angles(0, 0, -side * 0.7)
			)
		end
	end
	local foot = pixelFlame(arm, SMALL_FLAME, LAVA_FLAME, CFrame.new(side * 0.04, stepTop, 0), 0.12, side < 0)
	smoke(foot, 4)
	embers(foot, EMBER, 2)
end

-- Faldón del muslo de "color" con el bajo de "hem" (lava o azufre). Devuelve su marco.
local function lavaFlap(
	leg: Builder,
	side: number,
	color: Color3,
	material: Enum.Material,
	hem: Color3,
	hemMaterial: Enum.Material
): CFrame
	local ls = leg.size
	local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
	leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.44, 0.1), color, material, flap)
	leg.block(Vector3.new(ls.X * 0.9 + 0.04, 0.07, 0.12), hem, hemMaterial, flap * CFrame.new(0, -ls.Y * 0.22, -0.01))
	return flap
end

-- Placa de obsidiana de "size" con un contorno de lava que asoma por detrás (en "at", mirando a -Z).
local function lavaPlate(make: Builder, size: Vector3, at: CFrame)
	make.block(size + Vector3.new(0.08, 0.08, -0.04), MAGMA, NEON, at * CFrame.new(0, 0, 0.03))
	return make.block(size, OBSIDIAN, SMOOTH, at)
end

-- Guerrero. Delante: coraza de basalto con gorguera de esquirlas, pectorales de obsidiana con el
-- contorno de lava y una raya de lava arriba, corazón de magma sujeto por cuatro garras de obsidiana,
-- vientre de placas con costuras de lava, una grieta del cuello al vientre y una hebilla con un cráneo
-- de mono de obsidiana de ojos de lava y dos cuernos. Detrás: placa de ceniza con marco de obsidiana
-- y lava corriendo por los lados y un volcán en cinco escalones que sobresalen cada vez más, con rocas
-- en las laderas, ríos de lava en cada escalón, un lago de lava al pie, cráter con una fuente de lava,
-- bombas de lava, humo y chispas, bajo una corona de siete cristales de obsidiana bañados en lava que
-- asoma por encima de los hombros. Hombreras de basalto con cristales de obsidiana y llama de lava.
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
		-- Raya de lava sobre el pectoral.
		make.block(
			Vector3.new(width * 0.32, 0.05, 0.05),
			MAGMA,
			NEON,
			CFrame.new(side * width * 0.24, height * 0.4, front - 0.05)
		)
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
	-- de obsidiana y lava corriendo por él.
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
		make.block(
			Vector3.new(0.04, height * 0.5, 0.04),
			MAGMA,
			NEON,
			CFrame.new(side * width * 0.5, -height * 0.1, plateZ + 0.14)
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
		-- Dos rocas de basalto en el borde del escalón, una mayor que la otra según el lado.
		if tier < tiers then
			for side = -1, 1, 2 do
				local big = (tier % 2 == 0) == (side == 1)
				make.block(
					Vector3.new(if big then 0.22 else 0.14, if big then 0.14 else 0.1, 0.12),
					ASH_DARK,
					BASALT_MATERIAL,
					CFrame.new(side * (tierWidth / 2 - 0.12), baseY + tier * tierHeight + 0.02, tierFront(tier) - 0.04)
						* CFrame.Angles(0.2, 0.3, side * 0.25)
				)
			end
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
	-- Corona de siete cristales, más altos en el centro y abiertos hacia los lados.
	for index, angle in { -1, -0.66, -0.33, 0, 0.33, 0.66, 1 } do
		lavaShard(
			make,
			Vector3.new(math.sin(angle) * width * 0.4, height * 0.47, plateZ + 0.04),
			Vector3.new(math.sin(angle) * 0.9, 1, 0.45),
			1.25 - math.abs(angle) * 0.5,
			if index == 4 then 0.4 else 0.34,
			0.5
		)
	end

	-- Cinturón de basalto con una hebilla de obsidiana: cráneo de mono de ojos de lava y dos cuernos.
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
	waist.block(Vector3.new(0.56, 0.4, 0.1), OBSIDIAN, SMOOTH, mask)
	obsidianSkull(waist, mask * CFrame.new(0, 0, -0.08), 0.55)
	for side = -1, 1, 2 do
		obsidianShard(waist, (mask * CFrame.new(side * 0.24, 0.16, 0)).Position, Vector3.new(side, 1, -0.2), 0.26, 0.1)
		waist.ball(0.1, MAGMA, NEON, CFrame.new(side * hipWidth * 0.34, 0.06, beltFront - 0.05))
	end

	for side = -1, 1, 2 do
		local arm = body.upperArm[side]
		lavaPauldron(arm, side, BASALT, BASALT_MATERIAL, "shard")
		band(arm, -arm.size.Y * 0.12, 0.16, 0.1, BASALT_DARK, BASALT_MATERIAL)
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
		for _, z in { -0.3, 0.3 } do
			obsidianShard(
				forearm,
				Vector3.new(side * (fs.X / 2 + 0.04), -fs.Y * 0.3, z * fs.Z),
				Vector3.new(side, 0.3, z * 1.5),
				0.3,
				0.12
			)
		end
		-- Faldón de basalto con una placa de obsidiana bordeada de lava, dos placas de lado y una gota.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = lavaFlap(leg, side, BASALT, BASALT_MATERIAL, MAGMA, NEON)
		lavaPlate(leg, Vector3.new(ls.X * 0.5, ls.Y * 0.26, 0.08), flap * CFrame.new(0, 0.02, -0.08))
		for plate = -1, 1, 2 do
			leg.block(
				Vector3.new(ls.X * 0.14, ls.Y * 0.3, 0.06),
				BASALT_DARK,
				BASALT_MATERIAL,
				flap * CFrame.new(plate * ls.X * 0.34, 0.02, -0.07)
			)
		end
		lavaDrip(leg, flap * CFrame.new(0, -ls.Y * 0.22 - 0.03, -0.06), 0.22)
	end
end

-- Cazador. Delante: jubón de cuero oscuro con correas cruzadas tachonadas de obsidiana, una grieta de
-- lava, collar de tres puntas de flecha de obsidiana bañadas en lava, manto de ceniza en dos escalones
-- con ribete de brasa, broche con una gota de lava, hojas quemadas junto al cuello, cinturón con zurrón
-- y un cuchillo de obsidiana. Detrás: capa de ceniza con dos zarpazos de lava de tres rayas en los
-- lados, el bajo de brasas que echa chispas, dos abanicos de hojas quemadas de bloque, capucha de ceniza
-- forrada de brasa con orejas y el carcaj de obsidiana con aros de lava, dos cristales bañados en lava
-- y siete flechas de plumas de fuego que arden. Hombreras de ceniza con garras de obsidiana y llama.
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
	-- Manto de ceniza sobre los hombros en dos escalones, con un ribete de brasa delante, y dos solapas.
	make.block(Vector3.new(width + 0.4, 0.34, depth + 0.4), ASH, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.04))
	make.block(Vector3.new(width + 0.12, 0.2, depth + 0.14), ASH_DARK, FABRIC, CFrame.new(0, height / 2 + 0.14, 0.06))
	make.block(Vector3.new(width + 0.42, 0.06, 0.08), MAGMA, NEON, CFrame.new(0, height / 2 - 0.21, -depth / 2 - 0.17))
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(width * 0.3, 0.24, 0.3),
			ASH,
			FABRIC,
			CFrame.new(side * width * 0.32, height / 2 - 0.06, front + 0.02)
		)
		-- Hojas quemadas cosidas a los lados del cuello.
		leaf(
			make,
			0.42,
			CHARRED_LEAF,
			CFrame.new(side * width * 0.3, height / 2 - 0.2, front - 0.1) * CFrame.Angles(0, 0, side * 0.5)
		)
	end
	local brooch = CFrame.new(0, height / 2 - 0.18, front - 0.14)
	local disc = make.rod(0.06, 0.34, OBSIDIAN, SMOOTH, brooch * FACING)
	disc.Reflectance = 0.05
	make.ball(0.16, MAGMA, NEON, brooch * CFrame.new(0, 0, -0.05))

	-- Espalda: capa de ceniza con el bajo de brasas y dos zarpazos de lava; encima, dos abanicos de hojas
	-- quemadas, la capucha y el carcaj.
	local capeHeight = height * 1.08
	local capeY = height / 2 - capeHeight / 2 - 0.02
	local capeZ = back + 0.16
	make.block(Vector3.new(width * 1.02, capeHeight, 0.12), ASH_DARK, FABRIC, CFrame.new(0, capeY, capeZ))
	local capeBottom = capeY - capeHeight / 2
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.12, capeHeight, 0.16),
			BASALT_DARK,
			FABRIC,
			CFrame.new(side * width * 0.51, capeY, capeZ)
		)
	end
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
	-- Zarpazos: tres rayas en diagonal a cada lado, bajo los abanicos y lejos del carcaj.
	for side = -1, 1, 2 do
		for stroke = 0, 2 do
			local x = side * (width * 0.36 + stroke * 0.1)
			strap(
				make,
				Vector3.new(x + side * 0.1, -height * 0.03, capeZ + 0.07),
				Vector3.new(x - side * 0.1, -height * 0.53, capeZ + 0.07),
				0.07,
				MAGMA,
				NEON
			)
		end
	end
	blockLeafFan(make, 9, 0.95, 1.3, { CHARRED_LEAF, BASALT_DARK }, 0.3)
	blockLeafFan(make, 7, 0.65, 1.1, { LAVA_ROBE, CHARRED_LEAF }, 0.36)
	local hood = blockHood(make, ASH, EMBER, FABRIC)
	for side = -1, 1, 2 do
		make.fang(
			0.34,
			0.22,
			BASALT_DARK,
			FABRIC,
			hood * CFrame.new(side * 0.42 - 0.11, 0.3, -0.05) * CFrame.Angles(0, 0, -side * 0.3)
		)
	end
	local quiverAt = backQuiver(make, {
		length = 1.9,
		radius = 0.27,
		color = OBSIDIAN,
		material = SMOOTH,
		rim = MAGMA,
		rimMaterial = NEON,
		arrows = 7,
		feathers = { MAGMA, EMBER },
	}, 0.4)
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

	-- Cinturón de basalto con hebilla de obsidiana, zurrón de ceniza, un cuchillo de obsidiana y dos
	-- borlas de brasa.
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
		waist.fang(
			0.26,
			0.14,
			MAGMA,
			NEON,
			CFrame.new(side * hipWidth * 0.1 + 0.07, -0.08, beltFront - 0.06) * CFrame.Angles(0, 0, math.pi)
		)
	end

	for side = -1, 1, 2 do
		local arm = body.upperArm[side]
		lavaPauldron(arm, side, ASH, FABRIC, "claw")
		band(arm, -arm.size.Y * 0.12, 0.16, 0.1, LEATHER_DARK, LEATHER_MATERIAL)
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, 0.04, fs.Y * 0.55, 0.08, LEATHER_DARK, LEATHER_MATERIAL)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, ASH, FABRIC)
		band(forearm, -fs.Y / 2 + 0.26, 0.05, 0.18, MAGMA, NEON)
		for _, z in { -0.3, 0.3 } do
			obsidianShard(
				forearm,
				Vector3.new(side * (fs.X / 2 + 0.04), fs.Y * 0.1, z * fs.Z),
				Vector3.new(side, 0.3, z * 1.5),
				0.3,
				0.12
			)
		end
		if side == 1 then
			forearm.block(
				Vector3.new(0.12, fs.Y * 0.55, fs.Z * 0.7),
				OBSIDIAN,
				SMOOTH,
				CFrame.new(fs.X / 2 + 0.08, 0.04, 0)
			)
			forearm.block(Vector3.new(0.06, fs.Y * 0.4, 0.06), MAGMA, NEON, CFrame.new(fs.X / 2 + 0.15, 0.04, 0))
		end
		-- Faldón de ceniza con una hoja quemada y dos placas de lado.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = lavaFlap(leg, side, ASH_DARK, FABRIC, MAGMA, NEON)
		leaf(
			leg,
			0.48,
			CHARRED_LEAF,
			flap * CFrame.new(side * 0.1, -0.05, -0.07) * CFrame.Angles(0, math.pi, math.pi + side * 0.3)
		)
		for plate = -1, 1, 2 do
			leg.block(
				Vector3.new(ls.X * 0.12, ls.Y * 0.3, 0.06),
				OBSIDIAN,
				SMOOTH,
				flap * CFrame.new(plate * ls.X * 0.36, 0.02, -0.07)
			)
		end
	end
end

-- Mago. Delante: túnica rojo lava con una pechera oscura ribeteada de lava, una runa de lava (triángulo
-- dentro de un círculo) con una brasa en el centro, cuello alto de esquirlas, dos amuletos de obsidiana
-- con un cristal de lava colgando, una raya de lava en el cuello y faja de basalto con tres cristales de
-- lava. Detrás: un sol negro, un disco de obsidiana con una runa dentro de dos anillos de fuego con
-- llamas, cinco rayos de obsidiana bañados en lava, dos talismanes colgando y una corona de siete
-- cristales de lava que asoma por encima de los hombros. Hombreras de tela con cristales de lava y llama.
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
	hoop(make, runeAt, width * 0.17, 8, 0.05, MAGMA, NEON)
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
	-- Cuello alto de esquirlas, en arco por delante de la nuca (detrás lo ocupa la corona).
	for index = 0, 4 do
		local angle = math.rad(-80 + index * 40)
		obsidianShard(
			make,
			Vector3.new(math.sin(angle) * width * 0.4, height / 2 - 0.05, -math.cos(angle) * depth * 0.42),
			Vector3.new(math.sin(angle) * 0.4, 1, -math.cos(angle) * 0.3),
			0.4,
			0.24
		)
	end
	-- Raya de lava en el cuello y dos amuletos de obsidiana con un cristal de lava colgando de cordones.
	make.block(Vector3.new(width * 0.5, 0.05, 0.05), MAGMA, NEON, CFrame.new(0, height / 2 - 0.2, front - 0.06))
	for side = -1, 1, 2 do
		local from = Vector3.new(side * width * 0.36, height / 2 - 0.06, front - 0.06)
		local to = Vector3.new(side * width * 0.38, height * 0.02, front - 0.1)
		strap(make, from, to, 0.03, FIBER, FABRIC)
		make.block(Vector3.new(0.14, 0.2, 0.06), OBSIDIAN, SMOOTH, CFrame.new(to.X, to.Y - 0.1, to.Z))
		fireCrystal(make, Vector3.new(to.X, to.Y - 0.2, to.Z), Vector3.new(0, -1, -0.1), 0.3, 0.14, LAVA_ROBE, MAGMA)
	end

	-- Espalda: sol negro con dos anillos de fuego y una runa en el disco, cinco rayos, dos talismanes y,
	-- por encima, la corona de cristales de lava.
	local ringAt = CFrame.new(0, -height * 0.04, back + 0.2)
	make.block(
		Vector3.new(width * 0.96, height * 1.02, 0.12),
		LAVA_ROBE_DARK,
		FABRIC,
		CFrame.new(0, -height * 0.06, back + 0.12)
	)
	hoop(make, ringAt, width * 0.34, 14, 0.12, MAGMA, NEON)
	hoop(make, ringAt * CFrame.new(0, 0, 0.02), width * 0.24, 10, 0.07, EMBER, NEON)
	local disc = make.rod(0.06, width * 0.42, OBSIDIAN, SMOOTH, ringAt * CFrame.new(0, 0, -0.02) * FACING)
	disc.Reflectance = 0.05
	hoop(make, ringAt * CFrame.new(0, 0, 0.05), width * 0.16, 8, 0.05, EMBER, NEON)
	local heart = make.ball(0.24, EMBER, NEON, ringAt * CFrame.new(0, 0, 0.06))
	local flames = Instance.new("Fire")
	flames.Color = MAGMA
	flames.SecondaryColor = EMBER
	flames.Size = 1.6
	flames.Heat = 4
	flames.Parent = heart
	embers(heart, EMBER, 5)
	fireLight(heart, MAGMA)
	-- Los rayos de arriba los tapa la corona: solo los cinco de abajo y de los lados.
	for _, degrees in { 90, 135, 180, 225, 270 } do
		local angle = math.rad(degrees)
		local out = Vector3.new(math.sin(angle), math.cos(angle), 0.12)
		lavaShard(make, (ringAt * CFrame.new(out.X * width * 0.4, out.Y * width * 0.4, 0)).Position, out, 0.46, 0.2)
	end
	-- Talismanes: dos placas de obsidiana con una runa de lava que cuelgan bajo el sol.
	for side = -1, 1, 2 do
		local from = (ringAt * CFrame.new(side * width * 0.2, -width * 0.36, 0.04)).Position
		local to = from + Vector3.new(side * 0.04, -height * 0.18, 0.02)
		strap(make, from, to, 0.03, FIBER, FABRIC)
		make.block(Vector3.new(0.16, 0.24, 0.05), OBSIDIAN, SMOOTH, CFrame.new(to.X, to.Y - 0.12, to.Z))
		make.block(Vector3.new(0.04, 0.14, 0.03), MAGMA, NEON, CFrame.new(to.X, to.Y - 0.12, to.Z + 0.03))
	end
	for index, step in { -3, -2, -1, 0, 1, 2, 3 } do
		fireCrystal(
			make,
			Vector3.new(step * 0.14 * width, height * 0.44, back + 0.22),
			Vector3.new(step * 0.15, 1, 0.35),
			if index == 4 then 1.2 else 1.05 - math.abs(step) * 0.13,
			if index == 4 then 0.34 else 0.28,
			LAVA_ROBE,
			MAGMA
		)
	end

	-- Faja de basalto con una raya de lava, tres cristales de lava y dos borlas.
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
		fireCrystal(
			waist,
			Vector3.new(side * hipWidth * 0.3, -0.08, beltFront - 0.05),
			Vector3.new(side * 0.1, -1, -0.1),
			0.3,
			0.14,
			LAVA_ROBE,
			MAGMA
		)
		waist.fang(
			0.28,
			0.14,
			LAVA_ROBE,
			FABRIC,
			CFrame.new(side * hipWidth * 0.44 + 0.07, -0.02, beltFront - 0.04) * CFrame.Angles(0, 0, math.pi)
		)
	end

	for side = -1, 1, 2 do
		local arm = body.upperArm[side]
		lavaPauldron(arm, side, LAVA_ROBE_DARK, FABRIC, "crystal")
		band(arm, -arm.size.Y * 0.12, 0.16, 0.1, LAVA_ROBE, FABRIC)
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, 0.02, fs.Y * 0.5, 0.08, LAVA_ROBE_DARK, FABRIC)
		band(forearm, -fs.Y / 2 + 0.1, 0.08, 0.12, MAGMA, NEON)
		band(forearm, fs.Y * 0.26, 0.05, 0.12, MAGMA, NEON)
		for _, z in { -0.22, 0.22 } do
			forearm.block(
				Vector3.new(0.05, 0.16, 0.05),
				EMBER,
				NEON,
				CFrame.new(side * (fs.X / 2 + 0.06), -fs.Y * 0.06, z * fs.Z)
			)
		end
		fireCrystal(
			forearm,
			Vector3.new(side * (fs.X / 2 + 0.04), fs.Y * 0.06, 0),
			Vector3.new(side, 0.6, 0),
			0.32,
			0.16,
			LAVA_ROBE,
			MAGMA
		)
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = lavaFlap(leg, side, LAVA_ROBE, FABRIC, MAGMA, NEON)
		lavaVein(leg, {
			Vector3.new(-ls.X * 0.25, ls.Y * 0.12, -(ls.Z / 2 + 0.13)),
			Vector3.new(ls.X * 0.05, -ls.Y * 0.05, -(ls.Z / 2 + 0.13)),
			Vector3.new(-ls.X * 0.1, -ls.Y * 0.3, -(ls.Z / 2 + 0.13)),
		}, 0.05)
		fireCrystal(
			leg,
			(flap * CFrame.new(0, -ls.Y * 0.22 - 0.03, -0.06)).Position,
			Vector3.new(0, -1, -0.1),
			0.26,
			0.12,
			LAVA_ROBE,
			MAGMA
		)
	end
end

-- Médico. Delante: túnica de lino bajo un manto de ceniza en dos escalones con ribete de azufre, peto de
-- basalto con una cruz verde que brilla (el color de las curaciones) y dos cristales de azufre, bandolera
-- con tres frascos que brillan, broche con un cristal de azufre, bolsita de hierbas y, en el cinturón,
-- un frasco, un rollo de venda y dos bolsas de las que asoman cristales de azufre. Detrás: bastidor de
-- madera con una mochila de basalto cubierta de costras de azufre, dos bolsillos y gotas de azufre,
-- un racimo de siete cristales de azufre que brillan, dos chimeneas que echan humo amarillo, dos
-- frascos a los lados y dos cristales en las esquinas. Hombreras de ceniza con cristales de obsidiana,
-- de azufre y llama de lava.
local function sulfurMantle(body: Body)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	local back = depth / 2
	make.block(Vector3.new(width + 0.12, height * 0.94, depth + 0.16), LINEN, FABRIC, CFrame.new(0, -height * 0.02, 0))
	make.block(Vector3.new(width + 0.4, 0.34, depth + 0.4), ASH, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.04))
	make.block(Vector3.new(width + 0.12, 0.2, depth + 0.14), ASH_DARK, FABRIC, CFrame.new(0, height / 2 + 0.14, 0.06))
	make.block(Vector3.new(width + 0.42, 0.08, depth + 0.42), SULFUR, SMOOTH, CFrame.new(0, height / 2 - 0.24, 0.04))
	-- Peto de basalto con una cruz verde que brilla entre dos ribetes de azufre, arriba a la izquierda:
	-- fuera del camino de la bandolera. Dos cristales de azufre en sus esquinas de arriba.
	local plastron = CFrame.new(-width * 0.27, height * 0.14, front - 0.04)
	make.block(Vector3.new(width * 0.34, height * 0.36, 0.08), BASALT, BASALT_MATERIAL, plastron)
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.05, height * 0.36, 0.06),
			SULFUR,
			SMOOTH,
			plastron * CFrame.new(side * width * 0.17, 0, -0.02)
		)
		fireCrystal(
			make,
			(plastron * CFrame.new(side * width * 0.12, height * 0.18 - 0.02, -0.08)).Position,
			Vector3.new(side * 0.3, 1, -0.5),
			0.34,
			0.14,
			SULFUR,
			SULFUR_GLOW
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
	for _, t in { 0, 1 } do
		local at = from:Lerp(to, t)
		make.ball(0.14, SULFUR, SMOOTH, CFrame.new(at.X, at.Y, at.Z - 0.1))
	end
	local pouchAt = from:Lerp(to, 0.88)
	herbPouch(make, CFrame.new(pouchAt.X, pouchAt.Y - 0.12, front - 0.14), LEAF)
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
	-- Costras de azufre en la mochila, dos bolsillos debajo y tres gotas de azufre bajo ella.
	for _, crust in { Vector3.new(-0.3, 0.22, 0.23), Vector3.new(0.34, 0.3, 0.23), Vector3.new(0.05, 0.05, 0.23) } do
		make.block(
			Vector3.new(0.18, 0.12, 0.05),
			SULFUR,
			SMOOTH,
			pack * CFrame.new(crust) * CFrame.Angles(0, 0, crust.X * 2)
		)
	end
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.34, 0.2, 0.1),
			BASALT_DARK,
			BASALT_MATERIAL,
			pack * CFrame.new(side * 0.45, -0.26, 0.26)
		)
		make.block(Vector3.new(0.38, 0.05, 0.12), SULFUR, SMOOTH, pack * CFrame.new(side * 0.45, -0.17, 0.26))
	end
	for _, x in { -0.4, 0, 0.4 } do
		lavaDrip(make, pack * CFrame.new(x, -height * 0.28, 0.1), 0.3, SULFUR_GLOW)
	end
	-- Racimo de siete cristales de azufre que sale de la mochila.
	local clusterBase = pack * CFrame.new(0, height * 0.27, 0)
	for index, tilt in { -0.3, -0.2, -0.1, 0, 0.1, 0.2, 0.3 } do
		fireCrystal(
			make,
			(clusterBase * CFrame.new(tilt * width * 0.3, 0, (index % 2) * 0.14 - 0.07)).Position,
			Vector3.new(tilt * 2.2, 1, 0.25),
			if index == 4
				then 1.2
				elseif index == 3 or index == 5 then 1.0
				elseif index == 2 or index == 6 then 0.8
				else 0.6,
			0.3,
			SULFUR,
			SULFUR_GLOW
		)
	end
	local glow = make.ball(0.22, SULFUR_GLOW, NEON, clusterBase * CFrame.new(0, 0.05, 0))
	fireLight(glow, SULFUR_GLOW)
	embers(glow, SULFUR_GLOW, 4)
	-- Dos chimeneas de obsidiana a los lados del racimo, con su aro de azufre, que echan humo amarillo.
	for side = -1, 1, 2 do
		local chimney = clusterBase * CFrame.new(side * width * 0.27, 0.12, -0.12)
		make.rod(0.36, 0.14, OBSIDIAN, SMOOTH, chimney * UPRIGHT)
		make.rod(0.06, 0.18, SULFUR, SMOOTH, chimney * CFrame.new(0, 0.1, 0) * UPRIGHT)
		local mouth = make.rod(0.05, 0.16, SULFUR_GLOW, NEON, chimney * CFrame.new(0, 0.19, 0) * UPRIGHT)
		smoke(mouth, 3, Color3.fromRGB(200, 190, 110), 0.8)
	end
	for side = -1, 1, 2 do
		flask(make, pack * CFrame.new(side * (width * 0.38 + 0.12), -height * 0.14, 0), 0.3, true)
		-- Cristal de azufre en la esquina de abajo de la mochila.
		fireCrystal(
			make,
			(pack * CFrame.new(side * width * 0.28, -height * 0.26, 0.2)).Position,
			Vector3.new(side * 0.5, -0.5, 0.6),
			0.4,
			0.2,
			SULFUR,
			SULFUR_GLOW
		)
	end
	-- Correas de la mochila a los hombros.
	for side = -1, 1, 2 do
		strap(
			make,
			Vector3.new(side * width * 0.28, -height * 0.3, back + 0.6),
			Vector3.new(side * width * 0.4, height / 2 - 0.1, back + 0.3),
			0.1,
			LEATHER_DARK,
			LEATHER_MATERIAL
		)
	end

	-- Cinturón con hebilla de azufre, una venda, un frasco y dos bolsas con cristales de azufre.
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
	flask(waist, CFrame.new(-hipWidth * 0.2, -0.38, beltFront - 0.12), 0.22, true)
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
		local arm = body.upperArm[side]
		lavaPauldron(arm, side, ASH, FABRIC, "sulfur")
		band(arm, -arm.size.Y * 0.12, 0.16, 0.1, SULFUR, SMOOTH)
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, fs.Y * 0.05, 0.12, 0.06, PAINT_WHITE, FABRIC, 0.12)
		band(forearm, -fs.Y / 2 + 0.12, 0.22, 0.16, ASH, FABRIC)
		band(forearm, -fs.Y / 2 + 0.26, 0.06, 0.18, SULFUR, SMOOTH)
		band(forearm, -fs.Y * 0.14, 0.12, 0.06, PAINT_WHITE, FABRIC, -0.12)
		fireCrystal(
			forearm,
			Vector3.new(side * (fs.X / 2 + 0.04), fs.Y * 0.1, 0),
			Vector3.new(side, 0.6, 0),
			0.3,
			0.16,
			SULFUR,
			SULFUR_GLOW
		)
		local leg = body.upperLeg[side]
		local flap = lavaFlap(leg, side, ASH_DARK, FABRIC, SULFUR, SMOOTH)
		herbPouch(leg, flap * CFrame.new(side * 0.05, 0, -0.12), LEAF)
	end
end

-- Trajes (Data/Cosmetics, tipo "Outfit"), por id del cosmético; cada sección pone los suyos. Reciben el
-- grado de la armadura que se lleva debajo (0 a MAX_GRADE) y ganan piezas con él: muchas los míticos y
-- cinco escalones los de temporada. Cada traje (salvo el primero, cuyos colores y cristales
-- de jade usan los demás) va en su bloque "do": Luau no deja más de 200 variables locales a la vez en
-- el módulo, y las del bloque se sueltan al cerrarlo.
local OUTFITS: { [string]: (body: Body, grade: number) -> () } = {}

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
		-- Ojos de jade engastados en oro viejo (como el jade de la hebilla y de la gorguera) bajo una ceja
		-- de furia en V (más baja por dentro), con pupilas de plata. Sin neón: el verde que brilla es de las
		-- curaciones.
		disc(side * 0.21, -0.03, 0.27, 0.25, 3, TITAN_GOLD_DARK)
		disc(side * 0.21, -0.04, 0.18, 0.16, 3.5, JADE)
		disc(side * 0.21, -0.04, 0.07, 0.07, 3.8, SILVER)
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

-- Abanico de "count" colmillos o plumas en punta, repartidos entre los ángulos "range" (X a Y, en radianes;
-- 0 es hacia arriba y crece hacia la -X) sobre una elipse de radios "radius" en el plano XY de "at", cada uno
-- con la punta hacia fuera. Devuelve las piezas.
local function fangRing(
	make: Builder,
	at: CFrame,
	count: number,
	range: Vector2,
	radius: Vector2,
	length: number,
	width: number,
	color: Color3,
	material: Enum.Material
): { BasePart }
	local parts = {}
	for index = 0, count - 1 do
		local angle = range.X + (range.Y - range.X) * (if count > 1 then index / (count - 1) else 0)
		table.insert(
			parts,
			make.fang(
				length,
				width,
				color,
				material,
				at
					* CFrame.new(-math.sin(angle) * radius.X, math.cos(angle) * radius.Y, 0)
					* CFrame.Angles(0, 0, angle)
					* CFrame.new(-width / 2, 0, width / 2)
			)
		)
	end
	return parts
end

-- Runa o gema plana (un óvalo fino de "size" de ancho) en el plano XY de "at", mirando a su -Z.
local function rune(make: Builder, at: CFrame, color: Color3, material: Enum.Material, size: number?): BasePart
	local wide = size or 0.12
	return make.oval(Vector3.new(wide, wide * 1.3, 0.04), color, material, at)
end

-- Hombrera del Rey Gorila (grado 1+): losa cuadrada de piedra con el canto de oro, tachones en las esquinas
-- y gemas de jade, dos láminas escalonadas con el canto de oro y, hundida en ellas, una cabeza de gorila de
-- piedra que mira hacia fuera (con los ojos de sol encendidos desde el grado 3, más un penacho de oro y
-- tachones de sol). Grado 4: cinco cristales de jade que salen por detrás de la cabeza.
local function titanPauldron(arm: Builder, side: number, grade: number)
	local as = arm.size
	local top = as.Y / 2
	local slab = CFrame.new(side * 0.12, top + 0.1, 0)
	arm.block(Vector3.new(as.X * 1.3, 0.22, as.Z * 1.3), TITAN_STONE_DARK, SLATE, slab)
	arm.block(Vector3.new(as.X * 1.3 + 0.1, 0.07, as.Z * 1.3 + 0.1), TITAN_GOLD, SMOOTH, slab * CFrame.new(0, -0.13, 0))
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			arm.ball(0.1, TITAN_GOLD, SMOOTH, slab * CFrame.new(sx * as.X * 0.55, 0.12, sz * as.Z * 0.55))
		end
	end
	for sz = -1, 1, 2 do
		arm.ball(0.12, JADE, SMOOTH, CFrame.new(side * (0.12 + as.X * 0.68), top + 0.1, sz * as.Z * 0.3))
	end
	if grade >= 3 then
		for sz = -1, 1, 2 do
			arm.fang(0.4, 0.14, TITAN_GOLD, SMOOTH, slab * CFrame.new(-side * as.X * 0.3, 0.1, sz * as.Z * 0.3))
		end
		for _, z in { -0.15, 0, 0.15 } do
			arm.ball(0.1, SUN_GLOW, NEON, CFrame.new(side * (0.12 + as.X * 0.66), top + 0.2, z * as.Z))
		end
	end
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
		for _, z in { -0.42, -0.26, 0, 0.26, 0.42 } do
			jadeCrystal(
				arm,
				Vector3.new(-side * 0.04, top + 0.24, z * as.Z),
				Vector3.new(-side * 0.35, 1, z * 1.4),
				if z == 0 then 0.66 elseif math.abs(z) > 0.3 then 0.4 else 0.48,
				if math.abs(z) > 0.3 then 0.18 else 0.22
			)
		end
	end
end

-- Riqueza extra del Rey Gorila (T2 de la Fase 18): cada grado suma detalle sobre el anterior para que se
-- vea claramente más rico que un legendario. Grado 1: runas y tachones en el peto, el vientre, el cinturón,
-- los brazos y los muslos, y en la espalda el sol con doce rayos y gemas. Grado 2: runas y flecos en la
-- capa, un halo de rayos de oro y jade alrededor de la calavera, cadenas con colgantes y flecos en los
-- faldones. Grado 3: melena plateada y collar del ídolo, tachones en su corona, filas de mechones, púas en
-- las muñecas, rodilleras de oro y colgantes. Grado 4: tachones en el aro solar y en los muslos. Las runas
-- brillan con el sol desde el grado 3.
local function titanRichness(body: Body, grade: number)
	if grade < 1 then
		return
	end
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.08)
	local back = depth / 2
	local lit = grade >= 3
	local glow = if lit then SUN_GLOW else TITAN_GOLD_DARK
	local glowMaterial = if lit then NEON else SMOOTH
	local fur = if lit then SILVER_FUR_DARK else GORILLA_FUR
	local capeHeight = height * 1.2
	local capeTop = height / 2 - 0.05
	local capeBottom = capeTop - capeHeight
	local capeZ = back + 0.22
	local idolSize = 1.4
	local idolY = height * 0.05

	-- Peto, esternón y vientre. Los pectorales giran un poco, así que la z de lo que va encima los sigue.
	for side = -1, 1, 2 do
		for index, x in { 0.13, 0.26, 0.39, 0.19, 0.33 } do
			rune(
				make,
				CFrame.new(
					side * width * x,
					height * (if index <= 3 then 0.26 else 0.14),
					front - 0.11 + 0.14 * (x - 0.25) * width
				),
				glow,
				glowMaterial
			)
		end
		for _, x in { 0.1, 0.2, 0.3, 0.4 } do
			make.ball(
				0.09,
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * width * x, height * 0.04, front - 0.12 + 0.14 * (x - 0.25) * width)
			)
		end
		for sy = -1, 1, 2 do
			make.ball(0.12, JADE, SMOOTH, CFrame.new(side * width * 0.19, height * (0.1 + sy * 0.22), front - 0.17))
		end
		for row = 0, 1 do
			local y = -height * 0.21 - row * height * 0.15
			rune(make, CFrame.new(side * width * 0.08, y, front - 0.07), glow, glowMaterial, 0.1)
			rune(make, CFrame.new(side * width * 0.32, y, front - 0.07), glow, glowMaterial, 0.1)
		end
	end
	make.rod(0.05, 0.24, TITAN_GOLD, SMOOTH, CFrame.new(0, -height * 0.28, front - 0.07) * FACING)
	make.ball(0.12, JADE, SMOOTH, CFrame.new(0, -height * 0.28, front - 0.1))

	-- Cinturón: runas delante y un fleco de colmillos de oro en el bajo del taparrabos, delante y detrás.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.09)
	for side = -1, 1, 2 do
		for _, x in { 0.2, 0.32, 0.44 } do
			rune(waist, CFrame.new(side * hipWidth * x, 0.04, beltFront - 0.02), glow, glowMaterial, 0.1)
		end
	end
	for index = 0, 4 do
		for _, z in { beltFront + 0.02, -beltFront - 0.02 } do
			waist.fang(
				0.22,
				0.12,
				TITAN_GOLD_DARK,
				SMOOTH,
				CFrame.new((index - 2) * hipWidth * 0.1, -0.69, z) * CFrame.Angles(math.pi, 0, 0)
			)
		end
	end

	-- Brazos y muslos: manguito de pelaje en el brazo, brazal de piedra con runas y púas, y en el muslo
	-- bandas, una placa de piedra con runas y gemas de jade.
	for side = -1, 1, 2 do
		local upper = body.upperArm[side]
		local us = upper.size
		for index = 0, 5 do
			local angle = index * math.pi / 3
			upper.fang(
				0.3,
				0.14,
				fur,
				FABRIC,
				CFrame.new(math.cos(angle) * (us.X / 2 + 0.04), -us.Y * 0.2 - 0.04, math.sin(angle) * (us.Z / 2 + 0.04))
					* CFrame.Angles(math.pi, 0, 0)
			)
		end
		local forearm = body.lowerArm[side]
		local fs = forearm.size
		band(forearm, fs.Y * 0.12, fs.Y * 0.34, 0.12, TITAN_STONE_DARK, SLATE)
		for _, y in { fs.Y * 0.3, -fs.Y * 0.05 } do
			band(forearm, y, 0.05, 0.16, TITAN_GOLD, SMOOTH)
		end
		for _, y in { 0.2, 0.1, 0 } do
			rune(
				forearm,
				CFrame.new(side * (fs.X / 2 + 0.075), fs.Y * y, 0) * CFrame.Angles(0, math.pi / 2, 0),
				glow,
				glowMaterial
			)
		end
		for _, z in { -0.28, 0.28 } do
			forearm.fang(
				0.26,
				0.12,
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * (fs.X / 2 + 0.06), -fs.Y / 2 + 0.2, z) * CFrame.Angles(0, 0, -side * math.pi / 2)
			)
		end
		forearm.ball(0.14, JADE, SMOOTH, CFrame.new(side * (fs.X / 2 + 0.07), fs.Y * 0.44, 0))

		local leg = body.upperLeg[side]
		local ls = leg.size
		band(leg, -ls.Y * 0.34, 0.1, 0.12, TITAN_GOLD, SMOOTH)
		band(leg, -ls.Y * 0.12, 0.14, 0.08, TITAN_STONE_DARK, SLATE)
		leg.block(
			Vector3.new(0.1, ls.Y * 0.36, ls.Z * 0.6),
			TITAN_STONE,
			SLATE,
			CFrame.new(side * (ls.X / 2 + 0.07), ls.Y * 0.14, 0)
		)
		for _, y in { 0.23, 0.14, 0.05 } do
			rune(
				leg,
				CFrame.new(side * (ls.X / 2 + 0.135), ls.Y * y, 0) * CFrame.Angles(0, math.pi / 2, 0),
				glow,
				glowMaterial,
				0.08
			)
		end
		for _, z in { -0.22, 0.22 } do
			leg.ball(0.12, JADE, SMOOTH, CFrame.new(side * (ls.X / 2 + 0.13), ls.Y * 0.14, z * ls.Z))
		end
	end

	-- Grado 1: el sol de la espalda con doce rayos de oro, gemas y runas en el borde de la placa (con la capa
	-- del grado 2 queda tapado).
	if grade == 1 then
		local sun = CFrame.new(0, -height * 0.1, back + 0.15)
		for index = 0, 11 do
			make.fang(
				if index % 2 == 0 then 0.36 else 0.26,
				0.1,
				TITAN_GOLD,
				SMOOTH,
				sun * CFrame.Angles(0, 0, index * math.pi / 6) * CFrame.new(-0.05, 0.6, 0.05)
			)
		end
		for side = -1, 1, 2 do
			for _, y in { 0.3, 0.1, -0.1, -0.3 } do
				rune(make, CFrame.new(side * width * 0.37, height * y, back + 0.16), glow, glowMaterial)
			end
			for sy = -1, 1, 2 do
				make.ball(0.14, JADE, SMOOTH, CFrame.new(side * width * 0.37, sy * height * 0.38, back + 0.17))
			end
		end
		for index = 0, 3 do
			make.ball(
				0.12,
				JADE,
				SMOOTH,
				sun * CFrame.Angles(0, 0, math.pi / 4 + index * math.pi / 2) * CFrame.new(0, 0.32, 0.03)
			)
		end
	end

	if grade >= 2 then
		-- Runas en los cantos de la capa, una banda de oro con gotas de jade en el bajo y mechones por los lados.
		for side = -1, 1, 2 do
			for index = 0, 6 do
				rune(
					make,
					CFrame.new(side * width * 0.44, capeTop - capeHeight * (0.1 + index * 0.11), capeZ + 0.08),
					glow,
					glowMaterial,
					0.1
				)
			end
			for index = 0, 7 do
				make.fang(
					if index % 2 == 0 then 0.3 else 0.22,
					0.12,
					fur,
					FABRIC,
					CFrame.new(side * (width * 0.5 + 0.06), capeTop - capeHeight * (0.08 + index * 0.115), capeZ + 0.01)
						* CFrame.Angles(0, 0, -side * (math.pi / 2 + 0.5))
						* CFrame.new(-0.06, 0, 0.06)
				)
			end
		end
		make.block(Vector3.new(width * 1.04, 0.08, 0.14), TITAN_GOLD, SMOOTH, CFrame.new(0, capeBottom + 0.12, capeZ))
		for index = 0, 5 do
			make.ball(
				0.1,
				JADE,
				SMOOTH,
				CFrame.new(((index + 0.5) / 6 - 0.5) * width * 0.92, capeBottom + 0.12, capeZ + 0.09)
			)
		end

		-- Grado 2: rayos de oro y gemas de jade alrededor de la calavera (menos por arriba, junto a los hombros).
		if grade == 2 then
			local skull = CFrame.new(0, capeTop - capeHeight * 0.36, capeZ + 0.1)
			local size = width * 0.7
			local from, to = 0.7, 2 * math.pi - 0.7
			fangRing(
				make,
				skull,
				12,
				Vector2.new(from, to),
				Vector2.new(size * 0.68, size * 0.66),
				0.34,
				0.12,
				TITAN_GOLD,
				SMOOTH
			)
			local step = (to - from) / 11
			for index = 2, 9 do
				local angle = from + (index + 0.5) * step
				make.ball(
					0.1,
					JADE,
					SMOOTH,
					skull * CFrame.new(-math.sin(angle) * size * 0.56, math.cos(angle) * size * 0.54, 0.02)
				)
			end
		end

		-- Cadenas con colgantes de jade que cuelgan de los broches, y flecos y runas en los faldones.
		for side = -1, 1, 2 do
			local drop = Vector3.new(side * width * 0.36, height / 2 - 1, front - 0.12)
			strap(
				make,
				Vector3.new(side * width * 0.36, height / 2 - 0.2, front - 0.12),
				drop,
				0.04,
				TITAN_GOLD,
				SMOOTH
			)
			make.ball(0.16, JADE, SMOOTH, CFrame.new(drop))
			make.fang(
				0.2,
				0.1,
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(drop + Vector3.new(0.05, -0.08, 0.05)) * CFrame.Angles(math.pi, 0, 0)
			)
			local outer = Vector3.new(side * width * 0.46, height / 2 - 0.8, front - 0.1)
			strap(
				make,
				Vector3.new(side * width * 0.46, height / 2 - 0.3, front - 0.1),
				outer,
				0.04,
				TITAN_GOLD,
				SMOOTH
			)
			make.ball(0.12, TITAN_GOLD, SMOOTH, CFrame.new(outer))

			local leg = body.upperLeg[side]
			local ls = leg.size
			local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
			for index = 0, 3 do
				leg.fang(
					0.2,
					0.1,
					TITAN_GOLD,
					SMOOTH,
					flap * CFrame.new((index - 1.5) * ls.X * 0.2, -ls.Y * 0.23, -0.04) * CFrame.Angles(math.pi, 0, 0)
				)
			end
			for _, x in { -0.25, 0.25 } do
				rune(leg, flap * CFrame.new(x * ls.X, 0.02, -0.06), glow, glowMaterial, 0.1)
			end
		end
	end

	if grade >= 3 then
		-- Melena plateada a los lados del ídolo, collar de jade con colmillos y hombreras de oro en su busto,
		-- tachones y alas de oro en la corona, y colgantes de cadena bajo el busto.
		local bustY = idolY - idolSize * 0.5 - 0.06
		for side = -1, 1, 2 do
			fangRing(
				make,
				CFrame.new(0, idolY, back + 0.5),
				5,
				Vector2.new(side * math.rad(40), side * math.rad(125)),
				Vector2.new(1, 0.95),
				0.36,
				0.14,
				SILVER_FUR,
				FABRIC
			)
			make.oval(
				Vector3.new(0.26, 0.14, 0.4),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * 0.8, bustY + 0.02, back + 0.44)
			)
		end
		for index = 0, 6 do
			make.ball(0.13, JADE, SMOOTH, CFrame.new((index - 3) * 0.2, bustY + 0.02, back + 0.72))
			if index < 6 then
				make.fang(
					0.2,
					0.09,
					TITAN_GOLD,
					SMOOTH,
					CFrame.new((index - 2.5) * 0.2 + 0.04, bustY - 0.03, back + 0.72) * CFrame.Angles(math.pi, 0, 0)
				)
			end
		end
		local crown = CFrame.new(0, idolY, back + 0.6)
			* CFrame.Angles(0, math.pi, 0)
			* CFrame.new(0, idolSize * 0.5, idolSize * 0.08)
		for index = 0, 5 do
			make.ball(
				0.09,
				TITAN_GOLD,
				SMOOTH,
				crown * CFrame.new((index - 2.5) * idolSize * 0.115, 0, -idolSize * 0.26)
			)
		end
		for side = -1, 1, 2 do
			make.fang(
				0.4,
				0.14,
				TITAN_GOLD,
				SMOOTH,
				crown * CFrame.new(side * idolSize * 0.33, 0, 0) * CFrame.Angles(0, 0, -side * 1.1)
			)
		end
		for index = -2, 2 do
			local from = Vector3.new(index * 0.28, bustY - 0.2, back + 0.5)
			local to = from + Vector3.new(0, -(0.5 + (2 - math.abs(index)) * 0.12), 0)
			strap(make, from, to, 0.04, TITAN_GOLD, SMOOTH)
			make.ball(0.1, JADE, SMOOTH, CFrame.new(to))
			make.fang(
				0.16,
				0.08,
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(to + Vector3.new(0.04, -0.04, 0.04)) * CFrame.Angles(math.pi, 0, 0)
			)
		end

		-- Dos filas más de mechones plateados en la capa, bajo la silla del lomo plateado.
		for row = 1, 2 do
			for index = 0, 6 do
				make.fang(
					if index % 2 == 0 then 0.24 else 0.18,
					0.16,
					SILVER_FUR_DARK,
					FABRIC,
					CFrame.new(
						(index / 6 - 0.5) * width * 0.9 + (row - 1.5) * 0.1,
						capeTop - capeHeight * (0.54 + row * 0.1),
						capeZ + 0.07
					) * CFrame.Angles(math.pi, 0, 0)
				)
			end
		end

		-- Púas de oro en las muñecas (solo por fuera, nunca hacia el cuerpo) y rodilleras de oro.
		for side = -1, 1, 2 do
			local forearm = body.lowerArm[side]
			local fs = forearm.size
			for _, degrees in { -75, -45, -15, 15, 45, 75 } do
				local angle = math.rad(degrees)
				local dir = Vector3.new(math.cos(angle) * side, 0, math.sin(angle))
				local pos = Vector3.new(dir.X * (fs.X / 2 + 0.07), fs.Y * 0.12, dir.Z * (fs.Z / 2 + 0.07))
				forearm.fang(
					0.22,
					0.1,
					TITAN_GOLD,
					SMOOTH,
					CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
				)
			end
			local leg = body.upperLeg[side]
			local ls = leg.size
			local knee = CFrame.new(side * 0.04, -ls.Y * 0.3, -(ls.Z / 2 + 0.1))
			leg.oval(Vector3.new(ls.X * 0.5, 0.3, 0.1), TITAN_GOLD, SMOOTH, knee)
			leg.ball(0.12, JADE, SMOOTH, knee * CFrame.new(0, 0, -0.07))
			for _, x in { -0.16, 0.16 } do
				local pos = (knee * CFrame.new(x, 0, -0.04)).Position
				leg.fang(
					0.2,
					0.1,
					TITAN_GOLD,
					SMOOTH,
					CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)) * CFrame.Angles(-math.pi / 2, 0, 0)
				)
				leg.ball(0.08, SUN_GLOW, NEON, knee * CFrame.new(x * 0.5, x * 0.7, -0.06))
			end
		end
	end

	if grade >= 4 then
		-- Un tachón de oro en la base de cada rayo del aro solar y tres tachones de sol en cada muslo.
		local disc = CFrame.new(0, idolY + 0.3, back + 0.36)
		for index = 0, 11 do
			make.ball(
				0.1,
				TITAN_GOLD,
				SMOOTH,
				disc * CFrame.Angles(0, 0, index * math.pi / 6) * CFrame.new(0, idolSize * 0.86 - 0.02, 0.08)
			)
		end
		for side = -1, 1, 2 do
			local ls = body.upperLeg[side].size
			for _, z in { -0.3, 0, 0.3 } do
				body.upperLeg[side].ball(
					0.1,
					SUN_GLOW,
					NEON,
					CFrame.new(side * (ls.X / 2 + 0.1), -ls.Y * 0.34, z * ls.Z)
				)
			end
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
				-- Dos orquídeas por liana y dos hojas más en el tramo de abajo.
				for _, flower in
					{
						CFrame.new(points[2] + Vector3.new(side * 0.04, 0, 0.06)),
						CFrame.new(points[4] + Vector3.new(-side * 0.04, 0.1, 0.06)),
					}
				do
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
				for _, index in { 2, 3 } do
					leaf(
						make,
						0.26,
						LEAF,
						CFrame.new(points[index] + Vector3.new(-side * 0.1, -0.12, 0.04))
							* CFrame.Angles(0, 0, -side * 0.7)
					)
				end
			end
		end
	end
	titanRichness(body, grade)
end

OUTFITS.TitanKingOutfit = titanKing

-- Cazador, Jaguar Espectral: pelaje de jaguar con rosetas, piedra de noche, oro y jade (los del Rey
-- Gorila); lo que brilla es la luz del espíritu del jaguar, blanca azulada (ni verde ni morado).
do
	local JAGUAR = Color3.fromRGB(214, 150, 62)
	local JAGUAR_CREAM = Color3.fromRGB(242, 222, 178)
	local ROSETTE = Color3.fromRGB(36, 28, 24)
	local ROSETTE_CORE = Color3.fromRGB(170, 104, 40)
	local JAGUAR_MOUTH = Color3.fromRGB(96, 30, 32)
	local NIGHT_STONE = Color3.fromRGB(46, 48, 62)
	local SPECTRAL = Color3.fromRGB(190, 240, 255)
	local SPECTRAL_BODY = Color3.fromRGB(140, 200, 250)
	local SPECTRAL_SPOT = Color3.fromRGB(70, 120, 185)

	-- Roseta de jaguar de "size" en el plano XY de "at" (mirando a su -Z): mancha negra con el centro más
	-- oscuro que el pelaje.
	local function rosette(make: Builder, size: number, at: CFrame)
		make.oval(Vector3.new(size, size * 0.85, 0.04), ROSETTE, SMOOTH, at)
		make.oval(Vector3.new(size * 0.56, size * 0.46, 0.04), ROSETTE_CORE, SMOOTH, at * CFrame.new(0, 0, -0.012))
	end

	-- Huella de jaguar de "size" en el plano XY de "at" (mirando a su -Z): almohadilla y cuatro dedos.
	local function pawPrint(make: Builder, size: number, color: Color3, material: Enum.Material, at: CFrame)
		make.oval(Vector3.new(size * 0.56, size * 0.46, 0.05), color, material, at * CFrame.new(0, -size * 0.16, 0))
		for index = 0, 3 do
			local angle = math.rad(-48 + index * 32)
			make.oval(
				Vector3.new(size * 0.2, size * 0.26, 0.05),
				color,
				material,
				at
					* CFrame.new(math.sin(angle) * size * 0.4, -size * 0.12 + math.cos(angle) * size * 0.4, 0)
					* CFrame.Angles(0, 0, -angle)
			)
		end
	end

	-- Cabeza de jaguar rugiendo, mirando a la -Z de "at", "size" studs de ancho y "depth" veces su fondo:
	-- cráneo ancho y bajo con manchas, mejillas anchas, orejas pequeñas en punta con el dentro negro, ojos
	-- almendrados de "eye" bajo unas cejas de furia, la lágrima negra bajo cada ojo, hocico corto y claro
	-- con la nariz oscura y la boca abierta con colmillos de oro (ancha y con orejas grandes y redondas
	-- parecía un oso). "pelt", "cream" y "material" son su pelaje (el del espíritu es translúcido).
	-- Devuelve sus piezas y los ojos.
	local function jaguarHead(
		make: Builder,
		at: CFrame,
		size: number,
		depth: number,
		eye: Color3,
		eyeMaterial: Enum.Material,
		pelt: Color3,
		cream: Color3,
		material: Enum.Material
	): ({ BasePart }, { BasePart })
		local parts, eyes = {}, {}
		local spot = if material == FABRIC then ROSETTE else SPECTRAL_SPOT
		local function on(x: number, y: number, z: number): CFrame
			return at * CFrame.new(x * size, y * size, z * size * depth)
		end
		local function scaled(x: number, y: number, z: number): Vector3
			return Vector3.new(x * size, y * size, z * size * depth)
		end
		local function add(piece: BasePart): BasePart
			table.insert(parts, piece)
			return piece
		end
		local mouth = if material == FABRIC then JAGUAR_MOUTH else SPECTRAL_SPOT
		add(make.oval(scaled(1, 0.7, 0.8), pelt, material, on(0, 0.08, 0.1)))
		add(make.oval(scaled(0.26, 0.12, 0.24), cream, material, on(0, -0.43, -0.28)))
		add(make.oval(scaled(0.38, 0.17, 0.22), mouth, SMOOTH, on(0, -0.33, -0.33)))
		add(make.block(scaled(0.16, 0.28, 0.14), pelt, material, on(0, 0, -0.4) * CFrame.Angles(-0.3, 0, 0)))
		add(make.oval(scaled(0.2, 0.11, 0.1), spot, SMOOTH, on(0, -0.11, -0.52)))
		add(make.ball(0.08 * size, spot, SMOOTH, on(0, 0.36, -0.16)))
		for side = -1, 1, 2 do
			add(make.oval(scaled(0.5, 0.42, 0.56), pelt, material, on(side * 0.28, -0.14, -0.08)))
			add(make.oval(scaled(0.26, 0.22, 0.3), cream, material, on(side * 0.11, -0.2, -0.36)))
			-- Oreja en punta, un poco abierta hacia fuera, con el dentro negro.
			local earWidth = 0.22 * size
			local ear = on(side * 0.36, 0.34, 0.12) * CFrame.Angles(0, 0, -side * 0.35)
			add(make.fang(0.26 * size, earWidth, pelt, material, ear * CFrame.new(-earWidth / 2, 0, earWidth / 2)))
			add(
				make.fang(
					0.17 * size,
					earWidth * 0.6,
					spot,
					SMOOTH,
					ear * CFrame.new(-earWidth * 0.3, 0.02, earWidth * 0.3 - 0.06 * size)
				)
			)
			table.insert(
				eyes,
				add(
					make.oval(
						scaled(0.22, 0.1, 0.08),
						eye,
						eyeMaterial,
						on(side * 0.2, 0.05, -0.36) * CFrame.Angles(0, 0, side * 0.35)
					)
				)
			)
			add(
				make.oval(
					scaled(0.32, 0.1, 0.14),
					pelt,
					material,
					on(side * 0.2, 0.15, -0.34) * CFrame.Angles(0, 0, side * 0.45)
				)
			)
			add(
				make.block(
					scaled(0.26, 0.04, 0.04),
					spot,
					SMOOTH,
					on(side * 0.2, 0.13, -0.41) * CFrame.Angles(0, 0, side * 0.45)
				)
			)
			add(
				make.block(
					scaled(0.04, 0.16, 0.04),
					spot,
					SMOOTH,
					on(side * 0.15, -0.07, -0.44) * CFrame.Angles(0, 0, -side * 0.2)
				)
			)
			add(make.ball(0.07 * size, spot, SMOOTH, on(side * 0.38, -0.06, -0.26)))
			add(make.ball(0.06 * size, spot, SMOOTH, on(side * 0.42, -0.24, -0.2)))
			add(make.ball(0.07 * size, spot, SMOOTH, on(side * 0.17, 0.32, -0.2)))
			local fangWidth = 0.07 * size
			add(
				make.fang(
					0.19 * size,
					fangWidth,
					TITAN_GOLD,
					SMOOTH,
					on(side * 0.13, -0.27, -0.42)
						* CFrame.new(fangWidth / 2, 0, -fangWidth / 2)
						* CFrame.Angles(0, 0, math.pi)
				)
			)
			add(
				make.fang(
					0.1 * size,
					fangWidth * 0.8,
					TITAN_GOLD,
					SMOOTH,
					on(side * 0.11, -0.41, -0.4) * CFrame.new(-fangWidth * 0.4, 0, fangWidth * 0.4)
				)
			)
		end
		return parts, eyes
	end

	-- Niebla del espíritu: velos blancos azulados que suben despacio.
	local function spectralMist(part: BasePart, rate: number)
		local mist = Instance.new("ParticleEmitter")
		mist.Texture = SMOKE_TEXTURE
		mist.Color = ColorSequence.new(SPECTRAL)
		mist.LightEmission = 0.6
		mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.1) })
		mist.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		mist.Lifetime = NumberRange.new(1.2, 2)
		mist.Rate = rate
		mist.Speed = NumberRange.new(0.3, 0.8)
		mist.SpreadAngle = Vector2.new(40, 40)
		mist.Acceleration = Vector3.new(0, 0.6, 0)
		mist.Rotation = NumberRange.new(0, 360)
		mist.RotSpeed = NumberRange.new(-20, 20)
		mist.Parent = part
	end

	-- Hombrera del Jaguar (grado 1+). La del brazo izquierdo: almohadilla de piedra de noche, dos láminas de
	-- pelaje con el canto de oro y una cabeza de jaguar que mira hacia fuera (con los ojos encendidos desde
	-- el grado 3; grado 4: tres cristales de jade detrás). La del arco (derecho), pequeña para no tensar la
	-- cuerda contra ella: un casquete de pelaje con tres garras de oro.
	local function jaguarPauldron(arm: Builder, side: number, grade: number)
		local as = arm.size
		local top = as.Y / 2
		local lit = grade >= 3
		if side > 0 then
			-- Casquete plano (un óvalo fino, nunca una almohada) con el aro de oro debajo.
			local cap = CFrame.new(side * 0.1, top + 0.06, 0)
			arm.oval(Vector3.new(as.X * 1.24, 0.16, as.Z * 1.26), JAGUAR, FABRIC, cap)
			arm.oval(Vector3.new(as.X * 1.3, 0.08, as.Z * 1.3), TITAN_GOLD, SMOOTH, cap * CFrame.new(0, -0.1, 0))
			for _, z in { -0.24, 0, 0.24 } do
				arm.ball(0.12, ROSETTE, SMOOTH, cap * CFrame.new(side * 0.16, 0.06, z * as.Z * 1.2))
				arm.fang(
					if z == 0 then 0.42 else 0.32,
					0.12,
					if lit then SPECTRAL else TITAN_GOLD,
					if lit then NEON else SMOOTH,
					CFrame.new(side * (as.X * 0.62), top - 0.12, z * as.Z) * CFrame.Angles(0, 0, -side * 2.4)
				)
			end
			if lit then
				-- Tres tachones de luz del espíritu en el canto del casquete.
				for _, z in { -0.15, 0, 0.15 } do
					arm.ball(0.1, SPECTRAL, NEON, cap * CFrame.new(side * as.X * 0.58, 0.04, z * as.Z * 1.2))
				end
			end
			return
		end
		-- Casquete plano de pelaje con un aro de oro debajo y cuatro tachones de oro (no una almohada).
		local cap = CFrame.new(side * 0.1, top + 0.06, 0)
		arm.oval(Vector3.new(as.X * 1.3, 0.18, as.Z * 1.3), JAGUAR, FABRIC, cap)
		arm.oval(Vector3.new(as.X * 1.36, 0.07, as.Z * 1.36), TITAN_GOLD, SMOOTH, cap * CFrame.new(0, -0.1, 0))
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				arm.ball(0.1, TITAN_GOLD, SMOOTH, cap * CFrame.new(sx * as.X * 0.5, 0.1, sz * as.Z * 0.5))
			end
		end
		for _, z in { -0.32, 0.32 } do
			arm.ball(0.13, ROSETTE, SMOOTH, cap * CFrame.new(side * 0.24, 0.08, z * as.Z))
		end
		if lit then
			for _, z in { -0.15, 0, 0.15 } do
				arm.ball(0.1, SPECTRAL, NEON, cap * CFrame.new(side * as.X * 0.62, 0.02, z * as.Z))
			end
		end
		for index = 0, 1 do
			local lame = CFrame.new(side * (0.2 + index * 0.12), top - 0.08 - index * 0.2, 0)
				* CFrame.Angles(0, 0, -side * (0.35 + index * 0.22))
			arm.oval(
				Vector3.new(as.X * 1.12 + 0.12, 0.1, as.Z * 1.36 - index * 0.1 + 0.06),
				TITAN_GOLD,
				SMOOTH,
				lame * CFrame.new(0, -0.07, 0)
			)
			arm.oval(Vector3.new(as.X * 1.12, 0.22, as.Z * 1.36 - index * 0.1), NIGHT_STONE, SLATE, lame)
		end
		jaguarHead(
			arm,
			CFrame.new(side * as.X * 0.36, top + 0.3, 0) * CFrame.Angles(0, -side * math.pi / 2, 0),
			0.82,
			0.75,
			if lit then SPECTRAL else JADE,
			if lit then NEON else SMOOTH,
			JAGUAR,
			JAGUAR_CREAM,
			FABRIC
		)
		if grade >= 4 then
			for _, z in { -0.42, -0.26, 0, 0.26, 0.42 } do
				jadeCrystal(
					arm,
					Vector3.new(-side * 0.04, top + 0.24, z * as.Z),
					Vector3.new(-side * 0.35, 1, z * 1.4),
					if z == 0 then 0.62 elseif math.abs(z) > 0.3 then 0.38 else 0.44,
					if math.abs(z) > 0.3 then 0.16 else 0.2
				)
			end
		end
	end

	-- Las ocho rosetas de la capa (x en anchos del torso, y en alturas de la capa): las usa la capa y las
	-- luces del espíritu que se encienden en su centro.
	local CAPE_SPOTS = {
		{ -0.34, 0.22 },
		{ 0.32, 0.12 },
		{ -0.12, -0.12 },
		{ 0.36, -0.32 },
		{ -0.36, -0.4 },
		{ 0.06, -0.62 },
		{ -0.2, -0.82 },
		{ 0.3, -0.78 },
	}

	-- Riqueza extra del Jaguar (T2 de la Fase 18). Grado 1: más rosetas en el jubón, manguitos de pelaje
	-- crema, bandas y rosetas en los muslos, tachones y flecos en el cinturón. Grado 2: mechones por los
	-- lados de la capa, gotas de jade en el bajo, flecos y cadenas con colgantes. Grado 3: luces del
	-- espíritu en el centro de las rosetas de la capa y zarpazos de luz en los faldones. Grado 4: el mapa de
	-- estrellas del espíritu sobre la capa.
	local function jaguarRichness(body: Body, grade: number)
		if grade < 1 then
			return
		end
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local capeHeight = height * 1.16
		local capeTop = height / 2 - 0.05
		local capeBottom = capeTop - capeHeight
		local capeZ = back + 0.2

		for _, spot in { { -0.4, -0.12 }, { 0.16, -0.16 }, { 0.4, -0.14 }, { -0.14, -0.24 }, { 0.12, -0.34 } } do
			rosette(make, 0.24, CFrame.new(spot[1] * width, spot[2] * height, front + 0.005))
		end

		local waist = body.waist
		local hipWidth, hipDepth = waist.size.X, waist.size.Z
		local beltFront = -(hipDepth / 2 + 0.09)
		for side = -1, 1, 2 do
			for _, x in { 0.22, 0.4 } do
				waist.ball(0.09, TITAN_GOLD, SMOOTH, CFrame.new(side * hipWidth * x, 0.05, beltFront - 0.02))
			end
		end
		for index = 0, 2 do
			for _, z in { beltFront + 0.02, -beltFront - 0.02 } do
				waist.fang(
					0.2,
					0.1,
					JAGUAR_CREAM,
					FABRIC,
					CFrame.new((index - 1) * hipWidth * 0.12, -0.69, z) * CFrame.Angles(math.pi, 0, 0)
				)
			end
		end

		for side = -1, 1, 2 do
			local upper = body.upperArm[side]
			local us = upper.size
			for index = 0, 4 do
				local angle = index * math.pi * 2 / 5
				upper.fang(
					0.28,
					0.13,
					JAGUAR_CREAM,
					FABRIC,
					CFrame.new(
						math.cos(angle) * (us.X / 2 + 0.04),
						-us.Y * 0.2 - 0.04,
						math.sin(angle) * (us.Z / 2 + 0.04)
					) * CFrame.Angles(math.pi, 0, 0)
				)
			end
			local leg = body.upperLeg[side]
			local ls = leg.size
			band(leg, -ls.Y * 0.34, 0.1, 0.12, TITAN_GOLD, SMOOTH)
			band(leg, -ls.Y * 0.12, 0.16, 0.08, JAGUAR, FABRIC)
			leg.ball(0.12, JADE, SMOOTH, CFrame.new(side * (ls.X / 2 + 0.1), -ls.Y * 0.34, 0))
			rosette(
				leg,
				0.2,
				CFrame.new(side * (ls.X / 2 + 0.06), -ls.Y * 0.12, 0) * CFrame.Angles(0, -side * math.pi / 2, 0)
			)
		end

		if grade >= 2 then
			-- Mechones de crema por los lados de la capa y gotas de jade entre los garras del bajo.
			for side = -1, 1, 2 do
				for index = 0, 5 do
					make.fang(
						if index % 2 == 0 then 0.28 else 0.2,
						0.12,
						JAGUAR_CREAM,
						FABRIC,
						CFrame.new(
							side * (width * 0.5 + 0.06),
							capeTop - capeHeight * (0.1 + index * 0.15),
							capeZ + 0.01
						)
							* CFrame.Angles(0, 0, -side * (math.pi / 2 + 0.5))
							* CFrame.new(-0.06, 0, 0.06)
					)
				end
				-- Cadena con colgante de jade que cuelga de cada broche.
				local top = Vector3.new(side * width * 0.36, height / 2 - 0.2, front - 0.12)
				local drop = top + Vector3.new(0, -0.8, 0)
				strap(make, top, drop, 0.04, TITAN_GOLD, SMOOTH)
				make.ball(0.15, JADE, SMOOTH, CFrame.new(drop))
				make.fang(
					0.18,
					0.09,
					JAGUAR_CREAM,
					SMOOTH,
					CFrame.new(drop + Vector3.new(0.04, -0.07, 0.04)) * CFrame.Angles(math.pi, 0, 0)
				)
				local leg = body.upperLeg[side]
				local ls = leg.size
				local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.06))
					* CFrame.Angles(0.1, 0, 0)
				for index = 0, 2 do
					leg.fang(
						0.2,
						0.1,
						JAGUAR_CREAM,
						FABRIC,
						flap * CFrame.new((index - 1) * ls.X * 0.25, -ls.Y * 0.23, -0.04) * CFrame.Angles(math.pi, 0, 0)
					)
				end
			end
			for index = 0, 5 do
				make.ball(
					0.1,
					JADE,
					SMOOTH,
					CFrame.new(((index + 0.5) / 6 - 0.5) * width * 0.92, capeBottom + 0.14, capeZ + 0.08)
				)
			end
		end

		if grade >= 3 then
			-- Una luz del espíritu en el centro de cada roseta de la capa y tres zarpazos de luz en cada faldón.
			for _, spot in CAPE_SPOTS do
				make.ball(
					0.07,
					SPECTRAL,
					NEON,
					CFrame.new(spot[1] * width, capeTop + spot[2] * capeHeight * 0.8 - 0.1, capeZ + 0.1)
				)
			end
			for side = -1, 1, 2 do
				local leg = body.upperLeg[side]
				local ls = leg.size
				local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.06))
					* CFrame.Angles(0.1, 0, 0)
				for index = -1, 1 do
					strap(
						make,
						(flap * CFrame.new(index * ls.X * 0.28 + ls.X * 0.1, ls.Y * 0.15, -0.08)).Position,
						(flap * CFrame.new(index * ls.X * 0.28 - ls.X * 0.1, -ls.Y * 0.15, -0.08)).Position,
						0.04,
						SPECTRAL,
						NEON
					)
				end
				leg.ball(0.07, SPECTRAL, NEON, flap * CFrame.new(0, -ls.Y * 0.17, -0.08))
			end
		end

		if grade >= 4 then
			-- El mapa de estrellas del espíritu: ocho estrellas unidas por líneas finas de luz sobre la capa.
			local stars = {
				{ -0.3, 0.3 },
				{ -0.12, 0.45 },
				{ 0.12, 0.38 },
				{ 0.3, 0.52 },
				{ 0.1, 0.66 },
				{ -0.2, 0.72 },
				{ -0.34, 0.88 },
				{ 0.2, 0.9 },
			}
			local previous: Vector3? = nil
			for _, star in stars do
				local at = Vector3.new(star[1] * width, capeTop - star[2] * capeHeight, capeZ + 0.1)
				make.ball(0.08, SPECTRAL, NEON, CFrame.new(at))
				if previous then
					strap(make, previous, at, 0.025, SPECTRAL, NEON)
				end
				previous = at
			end
		end
	end

	-- Traje mítico del cazador, Jaguar Espectral. Grado 0: jubón de pelaje de jaguar con rosetas, placa de
	-- piedra de noche en el pecho con una cabeza de jaguar en relieve, tres zarpazos en el otro pectoral,
	-- gorguera de oro con cuentas de jade y colmillos colgando, correa del carcaj con tachones de oro y un
	-- medallón de jade con la huella de oro, cinturón de piedra con hebilla de jade, taparrabos de pelaje,
	-- la cola del jaguar colgando detrás, brazal de piedra en el brazo del arco y garras de oro en el otro.
	-- Detrás, una gran huella de jaguar de oro y el carcaj de piedra de noche con aros de oro y flechas de
	-- plumas negras y doradas. Grado 1: hombrera con cabeza de jaguar (y casquete con garras en el brazo del
	-- arco). Grado 2: manto y capa de pelaje con rosetas y un fleco de garras de oro, broches con cadena,
	-- faldones en los muslos y, de motivo en la espalda, la capucha con la cabeza del jaguar. Grado 3: el
	-- espíritu del jaguar sale de la capucha (queda vacía) y asoma translúcido por encima del hombro
	-- izquierdo, con una pata sobre él; se encienden los ojos de todas las cabezas, los zarpazos y las
	-- garras. Grado 4: una luna creciente con estrellas detrás del espíritu, niebla espectral, las flechas
	-- que arden en luz y cristales de jade en la hombrera.
	local function spectralJaguar(body: Body, grade: number)
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local lit = grade >= 3
		local eye = if lit then SPECTRAL else JADE
		local eyeMaterial = if lit then NEON else SMOOTH
		make.block(
			Vector3.new(width + 0.1, height * 0.92, depth + 0.14),
			JAGUAR,
			FABRIC,
			CFrame.new(0, -height * 0.03, 0)
		)
		local BEHIND = CFrame.Angles(0, math.pi, 0)
		for _, spot in { { -0.38, -0.3 }, { 0.36, -0.38 }, { -0.12, -0.42 }, { 0.42, 0.04 } } do
			rosette(make, 0.26, CFrame.new(spot[1] * width, spot[2] * height, front + 0.005))
		end
		for _, spot in
			{ { -0.36, 0.3 }, { 0.3, 0.32 }, { -0.1, -0.06 }, { 0.38, -0.2 }, { -0.36, -0.36 }, { 0.08, -0.4 } }
		do
			rosette(make, 0.28, CFrame.new(spot[1] * width, spot[2] * height, back + 0.075) * BEHIND)
		end

		-- Pecho: placa de piedra de noche con el canto de oro y una cabeza de jaguar en relieve (izquierda) y
		-- tres zarpazos (derecha), que brillan desde el grado 3.
		local plate = CFrame.new(-width * 0.24, height * 0.18, front - 0.03) * CFrame.Angles(0.08, 0.12, 0)
		make.block(Vector3.new(width * 0.46, height * 0.4, 0.12), TITAN_GOLD, SMOOTH, plate * CFrame.new(0, 0, 0.02))
		make.block(Vector3.new(width * 0.4, height * 0.34, 0.12), NIGHT_STONE, SLATE, plate * CFrame.new(0, 0, -0.01))
		jaguarHead(make, plate * CFrame.new(0, -0.02, -0.07), 0.6, 0.35, eye, eyeMaterial, JAGUAR, JAGUAR_CREAM, FABRIC)
		for index = -1, 1 do
			local x = width * 0.26 + index * 0.13
			strap(
				make,
				Vector3.new(x + 0.1, height * 0.36, front - 0.02),
				Vector3.new(x - 0.1, height * 0.04, front - 0.02),
				0.07,
				if lit then SPECTRAL else ROSETTE,
				if lit then NEON else SMOOTH
			)
		end

		-- Gorguera de oro con cuentas de jade y colmillos colgando.
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
				local bead = CFrame.new(math.sin(mid) * width * 0.31, height / 2 - 0.05, -math.cos(mid) * depth * 0.5)
				make.ball(0.15, JADE, SMOOTH, bead)
				if math.cos(mid) > 0.3 then
					make.fang(
						0.24,
						0.1,
						JAGUAR_CREAM,
						SMOOTH,
						bead * CFrame.new(0.05, -0.08, -0.02) * CFrame.Angles(0, 0, math.pi)
					)
				end
			end
		end

		-- Correa del carcaj con tachones de oro y un medallón de jade con la huella de oro.
		quiverStrap(make, front - 0.05, 0.16, NIGHT_STONE, LEATHER_MATERIAL)
		local strapFrom = Vector3.new(width * 0.3, height / 2 - 0.02, front - 0.09)
		local strapTo = Vector3.new(-width * 0.4, -height / 2 + 0.12, front - 0.09)
		for _, t in { 0.18, 0.72, 0.88 } do
			make.ball(0.1, TITAN_GOLD, SMOOTH, CFrame.new(strapFrom:Lerp(strapTo, t)))
		end
		local medallion = CFrame.new(strapFrom:Lerp(strapTo, 0.45) + Vector3.new(0, 0, -0.02))
		make.rod(0.06, 0.48, TITAN_GOLD, SMOOTH, medallion * FACING)
		make.rod(0.06, 0.38, JADE, SMOOTH, medallion * CFrame.new(0, 0, -0.03) * FACING)
		pawPrint(make, 0.3, TITAN_GOLD, SMOOTH, medallion * CFrame.new(0, 0.02, -0.06))

		-- Espalda: la gran huella de oro (bajo la capa desde el grado 2).
		if grade < 2 then
			pawPrint(make, 0.8, TITAN_GOLD, SMOOTH, CFrame.new(-width * 0.2, height * 0.12, back + 0.1) * BEHIND)
		end

		-- Cinturón de piedra con banda de oro y hebilla de jade, taparrabos de pelaje y la cola.
		local waist = body.waist
		local hipWidth, hipDepth = waist.size.X, waist.size.Z
		local beltFront = -(hipDepth / 2 + 0.09)
		waist.block(Vector3.new(hipWidth + 0.16, 0.24, hipDepth + 0.18), NIGHT_STONE, SLATE, CFrame.new(0, 0.05, 0))
		waist.block(Vector3.new(hipWidth + 0.18, 0.05, hipDepth + 0.2), TITAN_GOLD, SMOOTH, CFrame.new(0, 0.15, 0))
		local buckle = CFrame.new(0, 0.05, beltFront - 0.03)
		waist.rod(0.06, 0.42, TITAN_GOLD, SMOOTH, buckle * FACING)
		waist.oval(Vector3.new(0.3, 0.28, 0.1), JADE, SMOOTH, buckle * CFrame.new(0, 0, -0.04))
		for _, z in { beltFront + 0.02, -beltFront - 0.02 } do
			local out = if z < 0 then -0.035 else 0.035
			waist.block(Vector3.new(hipWidth * 0.4, 0.6, 0.06), JAGUAR, FABRIC, CFrame.new(0, -0.38, z))
			waist.block(Vector3.new(hipWidth * 0.42, 0.06, 0.08), TITAN_GOLD, SMOOTH, CFrame.new(0, -0.66, z))
			waist.ball(0.16, ROSETTE, SMOOTH, CFrame.new(0.04, -0.34, z + out))
		end
		local tail = {
			Vector3.new(hipWidth * 0.12, -0.05, hipDepth / 2 + 0.12),
			Vector3.new(hipWidth * 0.26, -0.55, hipDepth / 2 + 0.4),
			Vector3.new(hipWidth * 0.3, -1.1, hipDepth / 2 + 0.5),
			Vector3.new(hipWidth * 0.14, -1.55, hipDepth / 2 + 0.62),
			Vector3.new(hipWidth * 0.22, -1.8, hipDepth / 2 + 0.88),
		}
		-- Tramos de pelaje que se solapan (lisos, sin juntas), un anillo negro en cada uno y la punta negra.
		for index = 1, #tail - 1 do
			local from, to = tail[index], tail[index + 1]
			local thick = 0.24 - index * 0.025
			local segment = CFrame.lookAt((from + to) / 2, to)
			waist.oval(Vector3.new(thick, thick, (to - from).Magnitude + thick), JAGUAR, FABRIC, segment)
			waist.oval(Vector3.new(thick + 0.03, thick + 0.03, 0.1), ROSETTE, SMOOTH, segment * CFrame.new(0, 0, 0.08))
		end
		waist.oval(
			Vector3.new(0.18, 0.18, 0.3),
			ROSETTE,
			FABRIC,
			CFrame.lookAt(tail[#tail], tail[#tail] + (tail[#tail] - tail[#tail - 1]))
		)

		-- Brazos: brazaletes de oro con jade; brazal de piedra de noche en el del arco (derecho) y, en el
		-- otro, un puño de pelaje con tres garras de oro.
		for side = -1, 1, 2 do
			local upper = body.upperArm[side]
			local us = upper.size
			band(upper, -us.Y * 0.2, 0.12, 0.08, TITAN_GOLD, SMOOTH)
			upper.ball(0.15, JADE, SMOOTH, CFrame.new(side * (us.X / 2 + 0.06), -us.Y * 0.2, 0))
			local forearm = body.lowerArm[side]
			local fs = forearm.size
			if side > 0 then
				band(forearm, 0.02, fs.Y * 0.6, 0.1, NIGHT_STONE, SLATE)
				for _, y in { fs.Y * 0.3, -fs.Y * 0.26 } do
					band(forearm, y, 0.06, 0.14, TITAN_GOLD, SMOOTH)
				end
				forearm.oval(Vector3.new(0.06, 0.24, 0.2), JADE, SMOOTH, CFrame.new(fs.X / 2 + 0.08, 0.02, 0))
			else
				band(forearm, -fs.Y / 2 + 0.16, 0.26, 0.14, JAGUAR, FABRIC)
				band(forearm, -fs.Y / 2 + 0.3, 0.06, 0.16, TITAN_GOLD, SMOOTH)
				for _, z in { -0.18, 0, 0.18 } do
					forearm.fang(
						0.3,
						0.09,
						if lit then SPECTRAL else TITAN_GOLD,
						if lit then NEON else SMOOTH,
						CFrame.new(-(fs.X / 2 + 0.06), -fs.Y / 2 + 0.06, z) * CFrame.Angles(0, 0, math.pi - 0.3)
					)
				end
			end
			if grade >= 1 then
				jaguarPauldron(upper, side, grade)
			end
		end

		-- Grado 2: manto y capa de pelaje con rosetas, fleco de garras de oro, broches y faldones.
		local quiverOut = 0.06
		if grade >= 2 then
			quiverOut = 0.32
			make.block(
				Vector3.new(width + 0.36, 0.32, depth * 0.62),
				JAGUAR,
				FABRIC,
				CFrame.new(0, height / 2 - 0.06, depth * 0.24)
			)
			local capeHeight = height * 1.16
			local capeTop = height / 2 - 0.05
			local capeZ = back + 0.2
			make.block(
				Vector3.new(width * 1.02, capeHeight, 0.12),
				JAGUAR,
				FABRIC,
				CFrame.new(0, capeTop - capeHeight / 2, capeZ)
			)
			for _, spot in CAPE_SPOTS do
				rosette(
					make,
					0.3,
					CFrame.new(spot[1] * width, capeTop + spot[2] * capeHeight * 0.8 - 0.1, capeZ + 0.075) * BEHIND
				)
			end
			local capeBottom = capeTop - capeHeight
			make.block(
				Vector3.new(width * 1.04, 0.08, 0.14),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(0, capeBottom + 0.04, capeZ)
			)
			for side = -1, 1, 2 do
				make.block(
					Vector3.new(0.08, capeHeight, 0.14),
					TITAN_GOLD,
					SMOOTH,
					CFrame.new(side * width * 0.5, capeTop - capeHeight / 2, capeZ + 0.01)
				)
			end
			for index = 0, 6 do
				local x = (index / 6 - 0.5) * width * 0.92
				make.fang(
					if index % 2 == 0 then 0.32 else 0.22,
					0.13,
					if index % 2 == 0 then TITAN_GOLD else JAGUAR_CREAM,
					SMOOTH,
					CFrame.new(x, capeBottom + 0.02, capeZ) * CFrame.Angles(math.pi, 0, 0)
				)
			end
			-- Broches de oro con jade y cadena.
			local clasps = {}
			for side = -1, 1, 2 do
				local clasp = CFrame.new(side * width * 0.36, height / 2 - 0.12, front - 0.06)
				make.rod(0.08, 0.3, TITAN_GOLD, SMOOTH, clasp * FACING)
				make.ball(0.14, JADE, SMOOTH, clasp * CFrame.new(0, 0, -0.06))
				clasps[side] = clasp.Position
			end
			local sag = Vector3.new(0, height / 2 - 0.3, front - 0.1)
			strap(make, clasps[-1], sag, 0.05, TITAN_GOLD, SMOOTH)
			strap(make, sag, clasps[1], 0.05, TITAN_GOLD, SMOOTH)
			for side = -1, 1, 2 do
				local leg = body.upperLeg[side]
				local ls = leg.size
				local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.06))
					* CFrame.Angles(0.1, 0, 0)
				leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.42, 0.1), JAGUAR, FABRIC, flap)
				leg.block(
					Vector3.new(ls.X * 0.92, 0.06, 0.12),
					TITAN_GOLD,
					SMOOTH,
					flap * CFrame.new(0, -ls.Y * 0.2, 0)
				)
				leg.ball(0.14, ROSETTE, SMOOTH, flap * CFrame.new(-side * 0.12, 0.04, -0.05))
				leg.ball(0.12, JADE, SMOOTH, flap * CFrame.new(side * 0.1, -0.06, -0.06))
			end
			-- La capucha: la cabeza del jaguar a la espalda (grado 2) o, desde el grado 3, vacía, porque el
			-- espíritu ha salido de ella.
			if grade == 2 then
				jaguarHead(
					make,
					CFrame.new(0, height / 2 - 0.36, capeZ + 0.3) * BEHIND * CFrame.Angles(-0.25, 0, 0),
					1.1,
					0.6,
					JADE,
					SMOOTH,
					JAGUAR,
					JAGUAR_CREAM,
					FABRIC
				)
			else
				loweredHood(make, JAGUAR, ROSETTE, FABRIC)
			end
		end

		-- El carcaj de piedra de noche con aros de oro, un aro de pelaje con jade y flechas de plumas negras
		-- y doradas (grado 4: arden en luz).
		local quiverAt = backQuiver(make, {
			length = 1.85,
			radius = 0.26,
			color = NIGHT_STONE,
			material = SLATE,
			rim = TITAN_GOLD,
			rimMaterial = SMOOTH,
			arrows = if grade >= 3 then 9 elseif grade >= 2 then 7 else 5,
			feathers = { ROSETTE, TITAN_GOLD },
		}, quiverOut)
		make.rod(0.22, 0.58, JAGUAR, FABRIC, quiverAt * UPRIGHT)
		make.ball(0.16, JADE, SMOOTH, quiverAt * CFrame.new(0, 0, 0.27))
		for _, y in { 0.42, -0.42 } do
			make.rod(0.05, 0.56, TITAN_GOLD, SMOOTH, quiverAt * CFrame.new(0, y, 0) * UPRIGHT)
		end

		-- Grado 3: el espíritu del jaguar, translúcido, asoma por encima del hombro izquierdo mirando atrás:
		-- la cabeza rugiendo, que se deshace por debajo en jirones de niebla que bajan hasta la capucha, y una
		-- pata sobre el hombro.
		if grade >= 3 then
			local ghost: { BasePart } = {}
			local function keep(piece: BasePart)
				table.insert(ghost, piece)
			end
			local headAt = CFrame.new(-width * 0.4, height / 2 + 0.2, back + 0.85)
				* BEHIND
				* CFrame.Angles(0.1, -0.35, 0.12)
			local headParts, spiritEyes =
				jaguarHead(make, headAt, 1.25, 1, SPECTRAL, NEON, SPECTRAL_BODY, SPECTRAL, GLASS)
			for _, piece in headParts do
				if not table.find(spiritEyes, piece) then
					keep(piece)
				end
			end
			fireLight(spiritEyes[1], SPECTRAL)
			-- Aura: un abanico de colmillos de cristal detrás de la cabeza (menos por abajo, en el cuello) y doce
			-- estrellitas de luz que flotan alrededor.
			for _, piece in
				fangRing(
					make,
					headAt * CFrame.new(0, 0.02, 0.38),
					14,
					Vector2.new(-2.5, 2.5),
					Vector2.new(0.85, 0.8),
					0.36,
					0.14,
					SPECTRAL_BODY,
					GLASS
				)
			do
				keep(piece)
			end
			for index = 0, 11 do
				make.ball(
					0.06,
					SPECTRAL,
					NEON,
					headAt
						* CFrame.new(
							math.sin(index * 2.4) * (1.05 + index % 3 * 0.1),
							math.cos(index * 2.4) * 0.95,
							0.3
						)
				)
			end
			local neck = headAt.Position + Vector3.new(0.1, -0.5, -0.12)
			keep(make.oval(Vector3.new(0.9, 0.6, 0.7), SPECTRAL_BODY, GLASS, CFrame.new(neck)))
			-- Manchas oscuras del espíritu sobre el cuello (la z sigue la curva del óvalo).
			for _, spot in { { -0.2, 0.08 }, { 0.18, 0.1 }, { 0, -0.1 }, { -0.3, -0.1 }, { 0.28, -0.08 } } do
				local depthAt = 0.35 * math.sqrt(math.max(0, 1 - (spot[1] / 0.45) ^ 2 - (spot[2] / 0.3) ^ 2))
				keep(
					make.oval(
						Vector3.new(0.14, 0.11, 0.04),
						SPECTRAL_SPOT,
						SMOOTH,
						CFrame.new(neck + Vector3.new(spot[1], spot[2], depthAt + 0.02))
					)
				)
			end
			for index, wisp in
				{
					{ -0.3, 1.3, 0.38 },
					{ 0.05, 1.6, 0.34 },
					{ 0.4, 1.15, 0.28 },
					{ -0.55, 1.0, 0.26 },
					{ 0.65, 0.9, 0.24 },
					{ -0.15, 1.9, 0.3 },
					{ 0.25, 1.4, 0.26 },
					{ -0.45, 1.6, 0.22 },
				}
			do
				local tilt, length, wide = wisp[1], wisp[2], wisp[3]
				local at = CFrame.new(neck + Vector3.new(tilt * 0.6, 0, 0.05 * index))
					* CFrame.Angles(0, 0, math.pi + tilt)
				keep(make.fang(length, wide, SPECTRAL_BODY, GLASS, at * CFrame.new(-wide / 2, 0, wide / 2)))
				make.block(
					Vector3.new(0.04, length * 0.6, 0.04),
					SPECTRAL,
					NEON,
					at * CFrame.new(0, length * 0.3, wide * 0.6)
				)
			end
			local paw = {
				Vector3.new(-width * 0.36, height * 0.3, back + 0.6),
				Vector3.new(-width * 0.34, height / 2 + 0.16, back * 0.2),
				Vector3.new(-width * 0.44, height * 0.38, front - 0.12),
			}
			for index = 1, #paw - 1 do
				keep(
					make.oval(
						Vector3.new(0.32, 0.32, (paw[index + 1] - paw[index]).Magnitude + 0.2),
						SPECTRAL_BODY,
						GLASS,
						CFrame.lookAt((paw[index] + paw[index + 1]) / 2, paw[index + 1])
					)
				)
			end
			keep(make.oval(Vector3.new(0.4, 0.3, 0.36), SPECTRAL_BODY, GLASS, CFrame.new(paw[3])))
			for index = -1, 1 do
				make.fang(
					0.2,
					0.07,
					SPECTRAL,
					NEON,
					CFrame.new(paw[3] + Vector3.new(index * 0.11, -0.1, -0.12)) * CFrame.Angles(math.pi - 0.4, 0, 0)
				)
				keep(
					make.oval(
						Vector3.new(0.14, 0.1, 0.14),
						SPECTRAL_BODY,
						GLASS,
						CFrame.new(paw[3] + Vector3.new(index * 0.11, -0.05, -0.02))
					)
				)
			end
			for _, x in { -0.19, 0.19 } do
				make.fang(
					0.16,
					0.06,
					SPECTRAL,
					NEON,
					CFrame.new(paw[3] + Vector3.new(x, -0.08, -0.1)) * CFrame.Angles(math.pi - 0.4, 0, 0)
				)
			end
			-- Rastro del espíritu: seis esferas de cristal que se afinan hacia atrás desde la punta de la cola.
			for index = 1, 6 do
				keep(
					waist.ball(
						0.36 - index * 0.04,
						SPECTRAL_BODY,
						GLASS,
						CFrame.new(tail[#tail] + Vector3.new(0, index * 0.05, index * 0.25))
					)
				)
			end
			for _, piece in ghost do
				piece.Transparency = 0.35
			end

			-- Grado 4: luna creciente con estrellas detrás de la cabeza del espíritu, niebla y las flechas
			-- que arden en luz.
			if grade >= 4 then
				-- La luna: un arco de plata que engorda hacia el centro, con el filo de dentro de luz.
				local moon = CFrame.new(headAt.Position + Vector3.new(0, 0.05, -0.25))
				local radius = 1.05
				local count = 12
				local step = math.rad(240) / count
				for index = 0, count - 1 do
					local angle = math.rad(-120) + (index + 0.5) * step
					local thick = 0.3 - math.abs(index - (count - 1) / 2) * 0.04
					local piece = moon * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius, 0)
					local length = 2 * radius * math.sin(step / 2) + 0.05
					make.block(Vector3.new(length, thick, 0.1), SILVER, SMOOTH, piece * CFrame.new(0, thick / 2, 0))
					make.block(Vector3.new(length, 0.06, 0.12), SPECTRAL, NEON, piece)
				end
				for _, star in { Vector3.new(0.75, 0.95, 0), Vector3.new(1.15, 0.35, 0), Vector3.new(0.35, 1.35, 0) } do
					local twinkle = moon * CFrame.new(star) * CFrame.Angles(0, 0, math.pi / 4)
					make.block(Vector3.new(0.14, 0.14, 0.06), SPECTRAL, NEON, twinkle)
					make.block(Vector3.new(0.05, 0.3, 0.05), SPECTRAL, NEON, twinkle * CFrame.Angles(0, 0, math.pi / 4))
				end
				-- Un halo fino de luz fuera de la luna, seis estrellas más, una llama de luz en la frente del
				-- espíritu y una estela de diez bolas de niebla que cae desde el cuello.
				for index = 0, count - 1 do
					local angle = math.rad(-120) + (index + 0.5) * step
					make.block(
						Vector3.new(2 * (radius + 0.42) * math.sin(step / 2) + 0.05, 0.04, 0.06),
						SPECTRAL,
						NEON,
						moon * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius + 0.42, 0)
					)
				end
				for _, star in
					{
						Vector3.new(-0.9, 0.9, 0),
						Vector3.new(-1.2, 0.3, 0),
						Vector3.new(0, 1.55, 0),
						Vector3.new(1.45, 0.85, 0),
						Vector3.new(-0.5, 1.35, 0),
						Vector3.new(0.95, 1.5, 0),
					}
				do
					local twinkle = moon * CFrame.new(star) * CFrame.Angles(0, 0, math.pi / 4)
					make.block(Vector3.new(0.12, 0.12, 0.06), SPECTRAL, NEON, twinkle)
					make.block(
						Vector3.new(0.04, 0.26, 0.05),
						SPECTRAL,
						NEON,
						twinkle * CFrame.Angles(0, 0, math.pi / 4)
					)
				end
				for index = 0, 5 do
					make.fang(
						0.3,
						0.1,
						SPECTRAL,
						NEON,
						headAt
							* CFrame.new((index - 2.5) * 0.11, 0.54, 0.05)
							* CFrame.Angles(0, 0, (index - 2.5) * 0.15)
					)
				end
				for index = 0, 9 do
					local mist = make.ball(
						0.5 - index * 0.03,
						SPECTRAL_BODY,
						GLASS,
						CFrame.new(
							neck
								+ Vector3.new(
									math.sin(index * 1.7) * 0.35,
									-0.4 - index * 0.17,
									0.1 + math.cos(index * 1.3) * 0.15
								)
						)
					)
					mist.Transparency = 0.5
				end
				for index = 0, 3 do
					make.ball(
						0.06,
						SPECTRAL,
						NEON,
						quiverAt
							* CFrame.new(
								math.cos(index * math.pi / 2) * 0.14,
								1.12 + index * 0.04,
								math.sin(index * math.pi / 2) * 0.14
							)
					)
				end
				spectralMist(spiritEyes[2], 3)
				-- Las flechas arden en luz: chispas blancas azuladas que suben de la boca del carcaj.
				local mouthLight = make.ball(0.2, SPECTRAL, NEON, quiverAt * CFrame.new(0, 1.05, 0))
				fireLight(mouthLight, SPECTRAL)
				local sparks = Instance.new("ParticleEmitter")
				sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				sparks.Color = ColorSequence.new(SPECTRAL, SPECTRAL_BODY)
				sparks.LightEmission = 1
				sparks.Size =
					NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
				sparks.Transparency = NumberSequence.new(0.1, 1)
				sparks.Lifetime = NumberRange.new(0.6, 1.1)
				sparks.Rate = 8
				sparks.Speed = NumberRange.new(1, 2)
				sparks.SpreadAngle = Vector2.new(25, 25)
				sparks.Acceleration = Vector3.new(0, 1.5, 0)
				sparks.Parent = mouthLight
			end
		end
		jaguarRichness(body, grade)
	end

	OUTFITS.SpectralJaguarOutfit = spectralJaguar
end

-- Mago, Serpiente Emplumada: túnica añil (la del mago), escamas turquesa con el vientre de oro, plumas de
-- quetzal verdes con la punta turquesa, rojo de quetzal, oro y jade; lo que brilla es el azul de las
-- runas del mago (el verde de las plumas no brilla nunca: el que brilla es de las curaciones).
do
	local QUETZAL = Color3.fromRGB(40, 160, 74)
	local QUETZAL_RED = Color3.fromRGB(196, 38, 48)
	local SCALE = TURQUOISE
	local SCALE_DARK = Color3.fromRGB(28, 116, 118)
	local SERPENT_MOUTH = Color3.fromRGB(110, 26, 40)
	local SERPENT_EYE = Color3.fromRGB(16, 26, 34)

	-- Pluma de quetzal de "length" en el plano XY de "at", con la punta hacia su +Y: verde, con la punta
	-- turquesa (azul de runa que brilla con "lit") y el cañón de oro. La punta va al final y del ancho de la
	-- pluma: un óvalo en medio parecía el ojo de una pluma de pavo real. "wide" es su ancho respecto al
	-- largo (0,36 si no se dice).
	local function quetzalFeather(make: Builder, length: number, at: CFrame, lit: boolean, wide: number?)
		local ratio = wide or 0.36
		make.oval(Vector3.new(length * ratio, length, 0.05), QUETZAL, SMOOTH, at)
		make.oval(
			Vector3.new(length * ratio * 0.72, length * 0.3, 0.07),
			if lit then RUNE else SCALE,
			if lit then NEON else SMOOTH,
			at * CFrame.new(0, length * 0.36, 0)
		)
		make.block(Vector3.new(0.02, length * 0.7, 0.07), TITAN_GOLD, SMOOTH, at * CFrame.new(0, -length * 0.1, 0))
	end

	-- Cuerpo de la serpiente por los puntos de "points": tramos de escamas turquesa que se solapan, con un
	-- anillo de oro (el vientre) en cada junta.
	local function serpentBody(make: Builder, points: { Vector3 }, thickness: number)
		for index = 1, #points - 1 do
			local from, to = points[index], points[index + 1]
			local length = (to - from).Magnitude
			local segment = CFrame.lookAt((from + to) / 2, to)
			make.oval(Vector3.new(thickness, thickness, length + thickness * 0.6), SCALE, SMOOTH, segment)
			make.oval(
				Vector3.new(thickness * 1.08, thickness * 1.08, thickness * 0.24),
				TITAN_GOLD,
				SMOOTH,
				segment * CFrame.new(0, 0, length / 2)
			)
		end
	end

	-- Cabeza de la serpiente emplumada de "size" mirando a la -Z de "at": cráneo de escamas con una banda
	-- de oro, cejas de oro, fauces abiertas (hocico alzado, mandíbula caída y la boca roja), colmillos de
	-- oro, lengua bífida y, detrás, una cresta de "crest" plumas de quetzal abiertas hacia atrás. Devuelve
	-- los ojos.
	local function serpentHead(
		make: Builder,
		at: CFrame,
		size: number,
		eye: Color3,
		eyeMaterial: Enum.Material,
		crest: number,
		lit: boolean
	): { BasePart }
		local function on(x: number, y: number, z: number): CFrame
			return at * CFrame.new(x * size, y * size, z * size)
		end
		local function scaled(x: number, y: number, z: number): Vector3
			return Vector3.new(x * size, y * size, z * size)
		end
		make.oval(scaled(0.72, 0.46, 0.9), SCALE, SMOOTH, on(0, 0.06, 0.05))
		make.oval(scaled(0.58, 0.2, 0.62), SCALE, SMOOTH, on(0, 0.04, -0.42) * CFrame.Angles(0.42, 0, 0))
		make.oval(scaled(0.5, 0.16, 0.6), SCALE_DARK, SMOOTH, on(0, -0.28, -0.34) * CFrame.Angles(-0.5, 0, 0))
		make.oval(scaled(0.44, 0.2, 0.5), SERPENT_MOUTH, SMOOTH, on(0, -0.12, -0.38))
		make.block(scaled(0.5, 0.05, 0.08), TITAN_GOLD, SMOOTH, on(0, 0.29, 0.18))
		make.block(scaled(0.04, 0.04, 0.3), QUETZAL_RED, SMOOTH, on(0, -0.14, -0.66))
		local eyes = {}
		for side = -1, 1, 2 do
			make.block(
				scaled(0.03, 0.03, 0.2),
				QUETZAL_RED,
				SMOOTH,
				on(side * 0.04, -0.14, -0.88) * CFrame.Angles(0, side * 0.35, 0)
			)
			local fangWidth = 0.06 * size
			make.fang(
				0.2 * size,
				fangWidth,
				TITAN_GOLD,
				SMOOTH,
				on(side * 0.17, -0.06, -0.6)
					* CFrame.new(fangWidth / 2, 0, -fangWidth / 2)
					* CFrame.Angles(0, 0, math.pi)
			)
			-- Ojo oscuro (claro se perdía contra las escamas) con la pupila rasgada de "eye".
			make.ball(0.16 * size, SERPENT_EYE, SMOOTH, on(side * 0.3, 0.14, -0.14))
			table.insert(eyes, make.block(scaled(0.03, 0.12, 0.05), eye, eyeMaterial, on(side * 0.375, 0.14, -0.15)))
			make.oval(
				scaled(0.24, 0.08, 0.32),
				TITAN_GOLD,
				SMOOTH,
				on(side * 0.26, 0.27, -0.12) * CFrame.Angles(0, 0, side * 0.3)
			)
			make.ball(0.05 * size, SERPENT_MOUTH, SMOOTH, on(side * 0.1, 0.12, -0.72))
		end
		for index = 1, crest do
			local spread = if crest == 1 then 0 else (index - 1) / (crest - 1) * 1.4 - 0.7
			quetzalFeather(
				make,
				(if math.abs(spread) < 0.2 then 0.9 else 0.72) * size,
				on(0, 0.22, 0.32) * CFrame.Angles(0.9, 0, spread) * CFrame.new(0, 0.32 * size, 0),
				lit
			)
		end
		return eyes
	end

	-- Hombrera de la Serpiente (grado 1+): almohadilla de escamas turquesa, dos láminas añil con el canto de
	-- oro y una cabeza de serpiente con cresta que mira hacia fuera (ojos de runa desde el grado 3; grado
	-- 4: tres cristales de runa detrás).
	local function serpentPauldron(arm: Builder, side: number, grade: number)
		local as = arm.size
		local top = as.Y / 2
		local lit = grade >= 3
		-- Disco plano de escamas (un óvalo fino, nunca una almohada) con un aro de oro debajo y cuatro tachones.
		local disc = CFrame.new(side * 0.1, top + 0.06, 0)
		arm.oval(Vector3.new(as.X * 1.3, 0.18, as.Z * 1.3), SCALE, SMOOTH, disc)
		arm.oval(Vector3.new(as.X * 1.36, 0.07, as.Z * 1.36), TITAN_GOLD, SMOOTH, disc * CFrame.new(0, -0.1, 0))
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				arm.ball(0.1, TITAN_GOLD, SMOOTH, disc * CFrame.new(sx * as.X * 0.5, 0.1, sz * as.Z * 0.5))
			end
		end
		for _, z in { -0.3, 0, 0.3 } do
			arm.ball(0.12, SCALE_DARK, SMOOTH, CFrame.new(side * 0.36, top + 0.12, z * as.Z))
		end
		if lit then
			-- Dos plumas de quetzal largas barridas hacia atrás sobre la hombrera.
			for _, x in { -0.2, 0.2 } do
				quetzalFeather(
					arm,
					0.7,
					CFrame.new(side * 0.1 + x, top + 0.12, as.Z * 0.2)
						* CFrame.Angles(1.05, 0, x * 1.2)
						* CFrame.new(0, 0.3, 0),
					true
				)
			end
		end
		for index = 0, 1 do
			local lame = CFrame.new(side * (0.2 + index * 0.12), top - 0.08 - index * 0.2, 0)
				* CFrame.Angles(0, 0, -side * (0.35 + index * 0.22))
			arm.oval(
				Vector3.new(as.X * 1.12 + 0.12, 0.1, as.Z * 1.36 - index * 0.1 + 0.06),
				TITAN_GOLD,
				SMOOTH,
				lame * CFrame.new(0, -0.07, 0)
			)
			arm.oval(Vector3.new(as.X * 1.12, 0.22, as.Z * 1.36 - index * 0.1), MAGE_INDIGO, FABRIC, lame)
		end
		serpentHead(
			arm,
			CFrame.new(side * as.X * 0.4, top + 0.32, 0) * CFrame.Angles(0, -side * math.pi / 2, 0),
			0.7,
			if lit then RUNE else JADE,
			if lit then NEON else SMOOTH,
			3,
			lit
		)
		if grade >= 4 then
			for _, z in { -0.42, -0.26, 0, 0.26, 0.42 } do
				crystal(
					arm,
					Vector3.new(-side * 0.04, top + 0.24, z * as.Z),
					Vector3.new(-side * 0.35, 1, z * 1.4),
					if z == 0 then 0.62 elseif math.abs(z) > 0.3 then 0.38 else 0.44,
					if math.abs(z) > 0.3 then 0.16 else 0.2
				)
			end
		end
	end

	-- Riqueza extra de la Serpiente (T2 de la Fase 18). Grado 1: rombos de escamas en la espalda del cinturón,
	-- tachones de jade y bandas de oro y escamas en los muslos (más los tachones de las hombreras). Grado 3: una
	-- fila de plumas de quetzal por cada lado de la capa, runas de luz en sus cantos, cadenas con colgantes
	-- y plumas en el bajo de los faldones (la serpiente que se alza y su cresta están en el traje).
	local function serpentRichness(body: Body, grade: number)
		if grade < 1 then
			return
		end
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local waist = body.waist
		local hipWidth, hipDepth = waist.size.X, waist.size.Z
		for index = -3, 3 do
			if index ~= 0 then
				waist.block(
					Vector3.new(0.1, 0.1, 0.04),
					SCALE_DARK,
					SMOOTH,
					CFrame.new(index * hipWidth * 0.13, 0.05, hipDepth / 2 + 0.11) * CFrame.Angles(0, 0, math.pi / 4)
				)
			end
		end
		for side = -1, 1, 2 do
			for _, z in { -0.3, 0.3 } do
				waist.ball(0.1, JADE, SMOOTH, CFrame.new(side * (hipWidth / 2 + 0.1), 0.05, z * hipDepth))
			end
			local leg = body.upperLeg[side]
			local ls = leg.size
			band(leg, -ls.Y * 0.34, 0.1, 0.12, TITAN_GOLD, SMOOTH)
			band(leg, -ls.Y * 0.14, 0.18, 0.08, SCALE, SMOOTH)
		end
		if grade < 3 then
			return
		end
		local capeHeight = height * 1.16
		local capeTop = height / 2 - 0.05
		local capeZ = back + 0.2
		for side = -1, 1, 2 do
			for index = 0, 3 do
				quetzalFeather(
					make,
					0.45,
					CFrame.new(side * (width * 0.5 + 0.12), capeTop - capeHeight * (0.15 + index * 0.2), capeZ + 0.02)
						* CFrame.Angles(0, 0, -side * (math.pi / 2 + 0.5))
						* CFrame.new(0, 0.2, 0),
					true
				)
			end
			for index = 0, 5 do
				rune(
					make,
					CFrame.new(side * width * 0.43, capeTop - capeHeight * (0.1 + index * 0.14), capeZ + 0.13),
					RUNE,
					NEON,
					0.1
				)
			end
			local top = Vector3.new(side * width * 0.36, height / 2 - 0.2, front - 0.12)
			local drop = top + Vector3.new(0, -0.9, 0)
			strap(make, top, drop, 0.04, TITAN_GOLD, SMOOTH)
			make.ball(0.15, JADE, SMOOTH, CFrame.new(drop))
			make.fang(
				0.18,
				0.09,
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(drop + Vector3.new(0.04, -0.07, 0.04)) * CFrame.Angles(math.pi, 0, 0)
			)
			local leg = body.upperLeg[side]
			local ls = leg.size
			local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.06)) * CFrame.Angles(0.1, 0, 0)
			for index = 0, 1 do
				quetzalFeather(
					leg,
					0.4,
					flap
						* CFrame.new((index - 0.5) * ls.X * 0.4, -ls.Y * 0.2 - 0.2, -0.06)
						* CFrame.Angles(0, 0, math.pi),
					true
				)
			end
		end
	end

	-- Traje mítico del mago, Serpiente Emplumada. Grado 0: túnica añil con ribetes de oro, pectoral de
	-- mosaico turquesa en un aro de oro con la cabeza de la serpiente en el centro, gorguera de oro con
	-- cuentas de jade, el cinturón es la propia serpiente (escamas turquesa con anillos de oro y la cabeza
	-- de hebilla), taparrabos rojo de quetzal con plumas, brazaletes de oro y puños de plumas. Detrás, un
	-- disco de mosaico turquesa con un abanico de plumas de quetzal. Grado 1: hombreras de escamas con
	-- cabezas de serpiente con cresta. Grado 2: capa de plumas de quetzal en tres filas, cuello de plumas,
	-- broches con cadena, faldones rojos y, de motivo en la espalda, la serpiente enroscada en espiral con
	-- la cabeza en el centro. Grado 3: la serpiente se alza: el cuerpo sube en S por la capa y la cabeza
	-- grande, con las fauces abiertas y una cresta de siete plumas, queda entre los omoplatos (la cabeza
	-- del jugador se ve por encima); se encienden los ojos de todas las cabezas, las puntas de las plumas y
	-- un aro de runas en el pectoral. Grado 4: un penacho de diez plumas largas abierto como alas alrededor
	-- de la cabeza, con rayos de oro, chispas de runa y cristales de runa en las hombreras.
	local function featheredSerpent(body: Body, grade: number)
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local lit = grade >= 3
		local eye = if lit then RUNE else JADE
		local eyeMaterial = if lit then NEON else SMOOTH
		local BEHIND = CFrame.Angles(0, math.pi, 0)
		make.block(
			Vector3.new(width + 0.1, height * 0.92, depth + 0.14),
			MAGE_INDIGO,
			FABRIC,
			CFrame.new(0, -height * 0.03, 0)
		)
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.08, height * 0.9, 0.08),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * width * 0.3, -height * 0.04, front + 0.01)
			)
		end

		-- Pectoral: aro de oro con el mosaico turquesa (teselas de dos tonos y jade) y la cabeza de la
		-- serpiente en el centro; desde el grado 3, un aro de runas que brilla alrededor.
		local pectoral = CFrame.new(0, height * 0.12, front - 0.04)
		make.rod(0.06, width * 0.52, TITAN_GOLD, SMOOTH, pectoral * FACING)
		make.rod(0.06, width * 0.44, SCALE_DARK, SMOOTH, pectoral * CFrame.new(0, 0, -0.02) * FACING)
		for index = 0, 9 do
			local angle = index * math.pi / 5
			make.block(
				Vector3.new(0.14, 0.14, 0.05),
				if index % 3 == 0 then JADE elseif index % 3 == 1 then SCALE else TITAN_GOLD,
				SMOOTH,
				pectoral
					* CFrame.Angles(0, 0, angle)
					* CFrame.new(0, width * 0.17, -0.05)
					* CFrame.Angles(0, 0, math.pi / 4)
			)
		end
		if lit then
			hoop(make, pectoral * CFrame.new(0, 0, -0.06), width * 0.25, 12, 0.05, RUNE, NEON)
		end
		-- Las cabezas van de perfil a tres cuartos (de frente, una serpiente parece una rana).
		local PROFILE = CFrame.Angles(0, -math.pi / 2 + 0.45, 0)
		serpentHead(make, pectoral * CFrame.new(-0.08, 0.02, -0.16) * PROFILE, 0.68, eye, eyeMaterial, 0, lit)

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

		-- Espalda (grados 0 y 1): disco de mosaico turquesa con un abanico de plumas de quetzal.
		if grade < 2 then
			local disc = CFrame.new(0, height * 0.08, back + 0.1) * BEHIND
			for index = -2, 2 do
				quetzalFeather(
					make,
					1,
					disc * CFrame.new(0, 0, 0.04) * CFrame.Angles(0, 0, index * 0.38) * CFrame.new(0, 0.5, 0),
					false
				)
			end
			make.rod(0.06, 0.62, TITAN_GOLD, SMOOTH, disc * CFrame.new(0, 0, -0.02) * FACING)
			make.rod(0.06, 0.48, SCALE, SMOOTH, disc * CFrame.new(0, 0, -0.05) * FACING)
			make.ball(0.18, JADE, SMOOTH, disc * CFrame.new(0, 0, -0.08))
		end

		-- Cinturón: la serpiente rodea la cintura (escamas con anillos de oro) con la cabeza de hebilla y la
		-- cola colgando a un lado; taparrabos rojo de quetzal con el bajo de oro y tres plumas.
		local waist = body.waist
		local hipWidth, hipDepth = waist.size.X, waist.size.Z
		local beltFront = -(hipDepth / 2 + 0.09)
		waist.block(Vector3.new(hipWidth + 0.16, 0.24, hipDepth + 0.18), SCALE, SMOOTH, CFrame.new(0, 0.05, 0))
		for _, y in { 0.17, -0.07 } do
			waist.block(Vector3.new(hipWidth + 0.18, 0.04, hipDepth + 0.2), TITAN_GOLD, SMOOTH, CFrame.new(0, y, 0))
		end
		for index = -3, 3 do
			if index ~= 0 then
				waist.block(
					Vector3.new(0.1, 0.1, 0.04),
					SCALE_DARK,
					SMOOTH,
					CFrame.new(index * hipWidth * 0.13, 0.05, beltFront + 0.01) * CFrame.Angles(0, 0, math.pi / 4)
				)
			end
		end
		serpentHead(waist, CFrame.new(-0.05, 0.06, beltFront - 0.12) * PROFILE, 0.42, eye, eyeMaterial, 0, lit)
		serpentBody(waist, {
			Vector3.new(hipWidth * 0.5, 0.0, -hipDepth * 0.2),
			Vector3.new(hipWidth * 0.58, -0.3, -hipDepth * 0.1),
			Vector3.new(hipWidth * 0.56, -0.62, -hipDepth * 0.28),
		}, 0.14)
		for _, z in { beltFront + 0.02, -beltFront - 0.02 } do
			waist.block(Vector3.new(hipWidth * 0.4, 0.6, 0.06), QUETZAL_RED, FABRIC, CFrame.new(0, -0.4, z))
			waist.block(Vector3.new(hipWidth * 0.42, 0.06, 0.08), TITAN_GOLD, SMOOTH, CFrame.new(0, -0.68, z))
		end
		for index = -1, 1 do
			quetzalFeather(
				waist,
				0.42,
				CFrame.new(index * 0.13, -0.86, beltFront - 0.01) * CFrame.Angles(0, 0, math.pi + index * 0.25),
				lit
			)
		end

		-- Brazos: brazaletes de oro con jade y puños de plumas de quetzal en las muñecas.
		for side = -1, 1, 2 do
			local upper = body.upperArm[side]
			local us = upper.size
			band(upper, -us.Y * 0.2, 0.12, 0.08, TITAN_GOLD, SMOOTH)
			upper.ball(0.15, JADE, SMOOTH, CFrame.new(side * (us.X / 2 + 0.06), -us.Y * 0.2, 0))
			local forearm = body.lowerArm[side]
			local fs = forearm.size
			band(forearm, -fs.Y / 2 + 0.3, 0.08, 0.12, TITAN_GOLD, SMOOTH)
			band(forearm, -fs.Y / 2 + 0.16, 0.2, 0.1, SCALE, SMOOTH)
			for _, z in { -0.22, 0.22 } do
				quetzalFeather(
					forearm,
					0.36,
					CFrame.new(side * (fs.X / 2 + 0.06), -fs.Y / 2 + 0.14, z) * CFrame.Angles(0, math.pi / 2, math.pi),
					lit
				)
			end
			if grade >= 1 then
				serpentPauldron(upper, side, grade)
			end
		end

		-- Grado 2: capa y cuello de plumas de quetzal, broches con cadena y faldones.
		if grade >= 2 then
			make.block(
				Vector3.new(width + 0.36, 0.3, depth * 0.62),
				MAGE_INDIGO_DARK,
				FABRIC,
				CFrame.new(0, height / 2 - 0.06, depth * 0.24)
			)
			for index = 0, 6 do
				local x = (index / 6 - 0.5) * (width + 0.2)
				quetzalFeather(
					make,
					0.5,
					CFrame.new(x, height / 2 - 0.3, front - 0.02) * CFrame.Angles(0, 0, math.pi),
					lit
				)
			end
			local capeHeight = height * 1.16
			local capeTop = height / 2 - 0.05
			local capeZ = back + 0.2
			make.block(
				Vector3.new(width * 1.02, capeHeight, 0.12),
				MAGE_INDIGO_DARK,
				FABRIC,
				CFrame.new(0, capeTop - capeHeight / 2, capeZ)
			)
			for side = -1, 1, 2 do
				make.block(
					Vector3.new(0.08, capeHeight, 0.14),
					TITAN_GOLD,
					SMOOTH,
					CFrame.new(side * width * 0.5, capeTop - capeHeight / 2, capeZ + 0.01)
				)
			end
			-- Tres filas de plumas que caen solapadas, la de abajo por fuera.
			for row = 0, 2 do
				local count = 5
				for index = 0, count - 1 do
					local x = (index / (count - 1) - 0.5) * width * 0.82 + (row % 2) * 0.16 - 0.08
					quetzalFeather(
						make,
						0.85,
						CFrame.new(x, capeTop - capeHeight * (0.4 + row * 0.25), capeZ + 0.07 + row * 0.03)
							* BEHIND
							* CFrame.Angles(0, 0, math.pi + (index - 2) * 0.08),
						lit,
						0.5
					)
				end
			end
			local clasps = {}
			for side = -1, 1, 2 do
				local clasp = CFrame.new(side * width * 0.36, height / 2 - 0.12, front - 0.06)
				make.rod(0.08, 0.3, TITAN_GOLD, SMOOTH, clasp * FACING)
				make.ball(0.14, JADE, SMOOTH, clasp * CFrame.new(0, 0, -0.06))
				clasps[side] = clasp.Position
			end
			local sag = Vector3.new(0, height / 2 - 0.3, front - 0.1)
			strap(make, clasps[-1], sag, 0.05, TITAN_GOLD, SMOOTH)
			strap(make, sag, clasps[1], 0.05, TITAN_GOLD, SMOOTH)
			for side = -1, 1, 2 do
				local leg = body.upperLeg[side]
				local ls = leg.size
				local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.06))
					* CFrame.Angles(0.1, 0, 0)
				leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.42, 0.1), QUETZAL_RED, FABRIC, flap)
				leg.block(
					Vector3.new(ls.X * 0.92, 0.06, 0.12),
					TITAN_GOLD,
					SMOOTH,
					flap * CFrame.new(0, -ls.Y * 0.2, 0)
				)
				leg.ball(0.12, JADE, SMOOTH, flap * CFrame.new(0, 0.02, -0.06))
			end

			-- El motivo de la espalda: la serpiente enroscada en espiral (grado 2) o alzándose (3 y 4).
			local coilZ = capeZ + 0.24
			if grade == 2 then
				local points = {}
				for index = 0, 14 do
					local angle = index * 0.62
					local radius = 0.78 - index * 0.042
					table.insert(
						points,
						Vector3.new(
							math.cos(angle) * radius,
							capeTop - capeHeight * 0.45 + math.sin(angle) * radius,
							coilZ
						)
					)
				end
				serpentBody(make, points, 0.26)
				serpentHead(
					make,
					CFrame.new(0, capeTop - capeHeight * 0.45, coilZ + 0.2) * CFrame.Angles(0, -math.pi / 2 - 0.45, 0),
					0.62,
					eye,
					eyeMaterial,
					3,
					lit
				)
			else
				local rise = {
					Vector3.new(width * 0.34, capeTop - capeHeight * 0.92, coilZ),
					Vector3.new(-width * 0.2, capeTop - capeHeight * 0.78, coilZ + 0.04),
					Vector3.new(-width * 0.3, capeTop - capeHeight * 0.6, coilZ + 0.08),
					Vector3.new(width * 0.18, capeTop - capeHeight * 0.48, coilZ + 0.14),
					Vector3.new(width * 0.16, capeTop - capeHeight * 0.34, coilZ + 0.22),
					Vector3.new(0, height * 0.02, back + 0.62),
				}
				serpentBody(make, rise, 0.28)
				-- De perfil a tres cuartos, en pose de ataque hacia la derecha: de frente una serpiente parece
				-- una rana.
				local headAt = CFrame.new(-width * 0.06, height * 0.12, back + 0.78)
					* CFrame.Angles(0, -math.pi / 2 - 0.45, 0)
					* CFrame.Angles(0.25, 0, 0)
				local eyes = serpentHead(make, headAt, 1.15, RUNE, NEON, 7, true)
				fireLight(eyes[1], RUNE)

				-- Rombos de escamas oscuras a lo largo del cuerpo, tres plumas de quetzal abiertas en su recodo
				-- y la lengua bífida con dos colmillos de oro en la mandíbula.
				for index = 1, #rise - 1 do
					for _, t in { 0.3, 0.7 } do
						make.block(
							Vector3.new(0.12, 0.12, 0.04),
							SCALE_DARK,
							SMOOTH,
							CFrame.new(rise[index]:Lerp(rise[index + 1], t) + Vector3.new(0, 0, 0.15))
								* CFrame.Angles(0, 0, math.pi / 4)
						)
					end
				end
				for _, index in { 2, 3, 4 } do
					local sign = if index == 3 then -1 else 1
					quetzalFeather(
						make,
						0.6,
						CFrame.new(rise[index] + Vector3.new(-sign * 0.22, 0, 0.1))
							* CFrame.Angles(0, 0, sign * 1.2)
							* CFrame.new(0, 0.3, 0),
						lit
					)
				end
				local tongue = {
					(headAt * CFrame.new(0, -0.2, -0.85)).Position,
					(headAt * CFrame.new(0, -0.2, -1.3)).Position,
					(headAt * CFrame.new(0.12, -0.2, -1.55)).Position,
					(headAt * CFrame.new(-0.12, -0.2, -1.55)).Position,
				}
				strap(make, tongue[1], tongue[2], 0.04, QUETZAL_RED, SMOOTH)
				strap(make, tongue[2], tongue[3], 0.04, QUETZAL_RED, SMOOTH)
				strap(make, tongue[2], tongue[4], 0.04, QUETZAL_RED, SMOOTH)
				for side = -1, 1, 2 do
					make.fang(0.25, 0.09, TITAN_GOLD, SMOOTH, headAt * CFrame.new(side * 0.2, -0.3, -0.7))
				end

				-- Grado 4: penacho de plumas largas abierto como alas alrededor de la cabeza, con rayos de oro y
				-- chispas de runa.
				if grade >= 4 then
					local crown = CFrame.new(0, height * 0.22, back + 0.5) * BEHIND
					for _, degrees in { 36, 54, 72, 90, 108 } do
						for side = -1, 1, 2 do
							local angle = math.rad(degrees) * side
							local length = 1.7 - math.abs(degrees - 54) * 0.01
							quetzalFeather(
								make,
								length,
								crown
									* CFrame.Angles(0, 0, angle)
									* CFrame.new(0, 0.55 + length / 2, (degrees % 40) * 0.002),
								true,
								0.22
							)
							if degrees < 108 then
								make.fang(
									0.5,
									0.12,
									TITAN_GOLD,
									SMOOTH,
									crown
										* CFrame.Angles(0, 0, angle + side * math.rad(10))
										* CFrame.new(-0.06, 0.6, -0.03)
								)
							end
						end
					end
					-- Una fila interior de plumas cortas, un halo de runas detrás del penacho, puntos de luz en el
					-- cuerpo y tres plumas abiertas en la cola.
					for _, degrees in { 8, 18, 27 } do
						for side = -1, 1, 2 do
							quetzalFeather(
								make,
								1.25,
								crown * CFrame.Angles(0, 0, math.rad(degrees) * side) * CFrame.new(0, 1.175, 0.06),
								true,
								0.2
							)
						end
					end
					hoop(make, crown * CFrame.new(0, 0.5, -0.04), 1.25, 12, 0.05, RUNE, NEON)
					for index = 1, 4 do
						for _, t in { 0.25, 0.75 } do
							make.ball(
								0.09,
								RUNE,
								NEON,
								CFrame.new(rise[index]:Lerp(rise[index + 1], t) + Vector3.new(0, 0, 0.2))
							)
						end
					end
					for index = 0, 2 do
						quetzalFeather(
							make,
							0.7,
							CFrame.new(rise[1] + Vector3.new(0, 0, 0.05))
								* CFrame.Angles(0, 0, math.pi + (index - 1) * 0.5)
								* CFrame.new(0, 0.35, 0),
							true
						)
					end
					local sparks = Instance.new("ParticleEmitter")
					sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
					sparks.Color = ColorSequence.new(RUNE, CRYSTAL)
					sparks.LightEmission = 1
					sparks.Size =
						NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
					sparks.Transparency = NumberSequence.new(0.15, 1)
					sparks.Lifetime = NumberRange.new(1.2, 2)
					sparks.Rate = 6
					sparks.Speed = NumberRange.new(0.4, 1)
					sparks.SpreadAngle = Vector2.new(60, 60)
					sparks.Acceleration = Vector3.new(0, 0.8, 0)
					sparks.Parent = eyes[2]
				end
			end
		end
		serpentRichness(body, grade)
	end

	OUTFITS.FeatheredSerpentOutfit = featheredSerpent
end

-- Médico, Ceiba de la Vida (el árbol del mundo): lino del médico, corteza gris verdosa de ceiba con sus
-- espinas cónicas, hojas, flores rosas, frutos de algodón, oro y jade; lo que brilla es el verde de las
-- curaciones (solo este mítico lo lleva) y el algodón blanco de los frutos.
do
	local CEIBA_BARK = Color3.fromRGB(140, 150, 122)
	local CEIBA_BARK_DARK = Color3.fromRGB(100, 108, 88)
	local CEIBA_THORN = Color3.fromRGB(204, 190, 150)
	local KAPOK = Color3.fromRGB(246, 244, 236)
	local KAPOK_POD = Color3.fromRGB(112, 120, 70)
	local CEIBA_BLOSSOM = Color3.fromRGB(238, 140, 176)
	local HUMMINGBIRD = Color3.fromRGB(30, 150, 120)
	local HUMMINGBIRD_THROAT = Color3.fromRGB(200, 30, 60)

	-- Espina cónica de ceiba de "length" que sale de "base" hacia "direction".
	local function ceibaThorn(make: Builder, base: Vector3, direction: Vector3, length: number, width: number)
		make.fang(
			length,
			width,
			CEIBA_THORN,
			SMOOTH,
			CFrame.lookAt(base, base + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
		)
	end

	-- Rama de ceiba por los puntos de "points": tramos de corteza que se solapan y, con "thorns", una espina
	-- en cada uno, alternando el lado, hacia atrás (+Z).
	local function ceibaBranch(make: Builder, points: { Vector3 }, thickness: number, thorns: boolean)
		for index = 1, #points - 1 do
			local from, to = points[index], points[index + 1]
			local length = (to - from).Magnitude
			local segment = CFrame.lookAt((from + to) / 2, to)
			make.oval(Vector3.new(thickness, thickness, length + thickness * 0.6), CEIBA_BARK, WOOD, segment)
			if thorns then
				local side = if index % 2 == 0 then 1 else -1
				ceibaThorn(
					make,
					(segment * CFrame.new(side * thickness * 0.4, 0, 0)).Position,
					segment.RightVector * side + Vector3.new(0, 0, 0.8),
					thickness * 0.7,
					thickness * 0.35
				)
			end
		end
	end

	-- Roseta de "count" hojas en el plano XY de "at" (mirando a su -Z), de "length" cada una.
	local function leafCluster(make: Builder, at: CFrame, count: number, length: number)
		for index = 0, count - 1 do
			leaf(
				make,
				length,
				if index % 2 == 0 then LEAF else LEAF_DARK,
				at * CFrame.Angles(0, 0, index / count * math.pi * 2) * CFrame.new(0, length * 0.45, index * 0.008)
			)
		end
	end

	-- Flor de ceiba en "at" (mirando a su -Z): cinco pétalos rosas y el centro de oro.
	local function ceibaBlossom(make: Builder, at: CFrame, size: number)
		for petal = 0, 4 do
			make.oval(
				Vector3.new(size * 0.4, size * 0.6, 0.04),
				CEIBA_BLOSSOM,
				SMOOTH,
				at * CFrame.Angles(0, 0, petal * math.pi * 2 / 5) * CFrame.new(0, size * 0.3, 0)
			)
		end
		make.ball(size * 0.3, TITAN_GOLD, SMOOTH, at * CFrame.new(0, 0, -0.03))
	end

	-- Fruto de ceiba de "size" colgando de "at" (su rabito): vaina verde parda; abierto ("open"), el
	-- algodón blanco que revienta por la raja (que brilla con "lit"). Devuelve el algodón (o la vaina).
	local function kapokPod(make: Builder, at: CFrame, size: number, open: boolean, lit: boolean): BasePart
		local pod =
			make.oval(Vector3.new(size * 0.45, size, size * 0.45), KAPOK_POD, SMOOTH, at * CFrame.new(0, -size / 2, 0))
		if not open then
			return pod
		end
		local fluff = pod
		for index = -1, 1 do
			fluff = make.ball(
				size * (if index == 0 then 0.42 else 0.32),
				KAPOK,
				if lit then NEON else FABRIC,
				at * CFrame.new(index * size * 0.14, -size * (0.5 + index * 0.1), size * 0.2)
			)
		end
		return fluff
	end

	-- Colibrí de "size" en "at" mirando a su -Z: cuerpo verde, garganta roja, pico largo y dos alas abiertas.
	local function hummingbird(make: Builder, at: CFrame, size: number)
		make.oval(Vector3.new(0.12, 0.12, 0.28) * size, HUMMINGBIRD, SMOOTH, at)
		make.ball(0.12 * size, HUMMINGBIRD, SMOOTH, at * CFrame.new(0, 0.04 * size, -0.14 * size))
		make.oval(
			Vector3.new(0.09, 0.06, 0.1) * size,
			HUMMINGBIRD_THROAT,
			SMOOTH,
			at * CFrame.new(0, -0.01 * size, -0.16 * size)
		)
		make.block(
			Vector3.new(0.02, 0.02, 0.18) * size,
			PAINT_BLACK,
			SMOOTH,
			at * CFrame.new(0, 0.04 * size, -0.28 * size)
		)
		make.fang(
			0.16 * size,
			0.08 * size,
			HUMMINGBIRD,
			SMOOTH,
			at * CFrame.new(0, 0, 0.14 * size) * CFrame.Angles(math.pi / 2, 0, 0)
		)
		for side = -1, 1, 2 do
			make.oval(
				Vector3.new(0.26, 0.03, 0.1) * size,
				HUMMINGBIRD,
				SMOOTH,
				at * CFrame.new(side * 0.13 * size, 0.06 * size, 0) * CFrame.Angles(0, 0, side * 0.6)
			)
		end
	end

	-- Motas verdes de curación que suben despacio (las de la copa) o el algodón que cae ("fluff").
	local function lifeMotes(part: BasePart, rate: number, fluff: boolean)
		local motes = Instance.new("ParticleEmitter")
		motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		motes.Color = if fluff then ColorSequence.new(KAPOK) else ColorSequence.new(HEAL_GLOW, POTION)
		motes.LightEmission = if fluff then 0.4 else 1
		motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
		motes.Transparency = NumberSequence.new(0.15, 1)
		motes.Lifetime = NumberRange.new(1.4, 2.2)
		motes.Rate = rate
		motes.Speed = NumberRange.new(0.3, 0.8)
		motes.SpreadAngle = Vector2.new(70, 70)
		motes.Acceleration = if fluff then Vector3.new(0.3, -0.5, 0) else Vector3.new(0, 0.8, 0)
		motes.Parent = part
	end

	-- Hombrera de la Ceiba (grado 1+): almohadilla de corteza, dos láminas de lino con el canto de oro,
	-- tres espinas cónicas hacia fuera, una roseta de hojas y un fruto colgando (abierto desde el grado 3;
	-- grado 4: tres cristales de jade que brillan en verde).
	local function ceibaPauldron(arm: Builder, side: number, grade: number)
		local as = arm.size
		local top = as.Y / 2
		local lit = grade >= 3
		-- Disco plano de corteza (un óvalo fino, nunca una almohada) con un aro de oro debajo y cuatro tachones.
		local disc = CFrame.new(side * 0.1, top + 0.06, 0)
		arm.oval(Vector3.new(as.X * 1.34, 0.18, as.Z * 1.34), CEIBA_BARK, WOOD, disc)
		arm.oval(Vector3.new(as.X * 1.4, 0.07, as.Z * 1.4), TITAN_GOLD, SMOOTH, disc * CFrame.new(0, -0.1, 0))
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				arm.ball(0.1, TITAN_GOLD, SMOOTH, disc * CFrame.new(sx * as.X * 0.5, 0.1, sz * as.Z * 0.5))
			end
		end
		for index = 0, 1 do
			local lame = CFrame.new(side * (0.2 + index * 0.12), top - 0.08 - index * 0.2, 0)
				* CFrame.Angles(0, 0, -side * (0.35 + index * 0.22))
			arm.oval(
				Vector3.new(as.X * 1.12 + 0.12, 0.1, as.Z * 1.36 - index * 0.1 + 0.06),
				TITAN_GOLD,
				SMOOTH,
				lame * CFrame.new(0, -0.07, 0)
			)
			arm.oval(Vector3.new(as.X * 1.12, 0.22, as.Z * 1.36 - index * 0.1), LINEN, FABRIC, lame)
		end
		for _, z in { -0.3, 0, 0.3 } do
			ceibaThorn(
				arm,
				Vector3.new(side * as.X * 0.5, top + 0.12, z * as.Z),
				Vector3.new(side, 0.5, z * 0.6),
				if z == 0 then 0.36 else 0.26,
				0.14
			)
		end
		leafCluster(arm, CFrame.new(side * 0.1, top + 0.3, as.Z * 0.2) * CFrame.Angles(-1.2, 0, 0), 5, 0.36)
		arm.ball(0.14, JADE, SMOOTH, CFrame.new(side * 0.1, top + 0.32, as.Z * 0.2))
		kapokPod(arm, CFrame.new(side * (as.X * 0.66), top - 0.1, as.Z * 0.3), 0.3, lit, lit)
		if grade >= 4 then
			for _, z in { -0.26, 0, 0.26 } do
				fireCrystal(
					arm,
					Vector3.new(-side * 0.04, top + 0.24, z * as.Z - 0.1),
					Vector3.new(-side * 0.35, 1, z * 1.4),
					if z == 0 then 0.6 else 0.42,
					0.2,
					JADE_LIGHT,
					HEAL_GLOW
				)
			end
		end
	end

	-- Riqueza extra de la Ceiba (T2 de la Fase 18). Grado 1: espinas, musgo y una liana con flor en el peto,
	-- hojas colgando de la gorguera, del taparrabos, de los brazos y de los muslos, enredaderas y espinas en
	-- los brazos y bandas de corteza en los muslos; en la espalda, espinas, raíces y hojas alrededor de la
	-- placa. Grado 2: enredaderas, musgo y cuatro flores en la capa. (El grado 3 añade ramitas, frutos y
	-- luciérnagas en el árbol de la espalda.)
	local function ceibaRichness(body: Body, grade: number)
		if grade < 1 then
			return
		end
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local BEHIND = CFrame.Angles(0, math.pi, 0)

		-- Peto: espinas en los bordes, musgo y una liana por el costado derecho con hojas y una flor.
		local plate = CFrame.new(0, height * 0.14, front - 0.03)
		for side = -1, 1, 2 do
			ceibaThorn(
				make,
				(plate * CFrame.new(side * width * 0.28, -height * 0.2, -0.06)).Position,
				Vector3.new(side, -0.6, -0.5),
				0.24,
				0.11
			)
			for _, y in { 0, height * 0.1 } do
				ceibaThorn(
					make,
					(plate * CFrame.new(side * width * 0.31, y, -0.04)).Position,
					Vector3.new(side, 0.1, -0.4),
					0.22,
					0.1
				)
			end
			for index = 0, 3 do
				make.oval(
					Vector3.new(0.16, 0.1, 0.03),
					LEAF_DARK,
					SMOOTH,
					plate * CFrame.new(side * width * 0.22, (-0.15 + index * 0.1) * height, -0.075)
				)
			end
		end
		local vine = {
			Vector3.new(width * 0.36, height / 2 - 0.1, front - 0.2),
			Vector3.new(width * 0.46, height * 0.15, front - 0.2),
			Vector3.new(width * 0.42, -height * 0.05, front - 0.2),
			Vector3.new(width * 0.44, -height * 0.2, front - 0.2),
			Vector3.new(width * 0.4, -height * 0.32, front - 0.2),
		}
		for index = 1, #vine - 1 do
			strap(make, vine[index], vine[index + 1], 0.06, LIANA, FABRIC)
			leaf(
				make,
				0.3,
				if index % 2 == 0 then LEAF else LEAF_DARK,
				CFrame.new(vine[index + 1] + Vector3.new(-0.06, 0, 0)) * CFrame.Angles(0, 0, (index % 2 - 0.5) * 1.6)
			)
		end
		ceibaBlossom(make, CFrame.new(vine[3] + Vector3.new(0, 0.1, -0.04)), 0.26)

		-- Hojas que cuelgan de la gorguera (delante).
		for _, degrees in { -75, -25, 25, 75 } do
			local mid = math.rad(degrees)
			leaf(
				make,
				0.3,
				if degrees < 0 then LEAF else LEAF_DARK,
				CFrame.new(math.sin(mid) * width * 0.31, height / 2 - 0.2, -math.cos(mid) * depth * 0.5 - 0.04)
					* CFrame.Angles(0, -mid, 0)
					* CFrame.Angles(0, 0, math.pi)
			)
		end

		-- Hojas en el bajo del taparrabos, delante y detrás.
		local waist = body.waist
		local hipWidth, hipDepth = waist.size.X, waist.size.Z
		local beltFront = -(hipDepth / 2 + 0.09)
		for index = 0, 2 do
			for _, z in { beltFront + 0.02, -beltFront - 0.02 } do
				leaf(
					waist,
					0.3,
					if index == 1 then LEAF_DARK else LEAF,
					CFrame.new((index - 1) * hipWidth * 0.13, -0.84, z) * CFrame.Angles(0, 0, math.pi)
				)
			end
		end

		-- Brazos y muslos.
		for side = -1, 1, 2 do
			local upper = body.upperArm[side]
			local us = upper.size
			band(upper, -us.Y * 0.02, 0.07, 0.12, LIANA, FABRIC, 0.35)
			band(upper, us.Y * 0.2, 0.07, 0.12, LIANA, FABRIC, -0.35)
			for _, y in { us.Y * 0.1, -us.Y * 0.08 } do
				ceibaThorn(upper, Vector3.new(side * (us.X / 2 + 0.04), y, 0), Vector3.new(side, 0.3, 0), 0.22, 0.1)
			end
			local forearm = body.lowerArm[side]
			local fs = forearm.size
			for index, z in { -0.22, 0, 0.22 } do
				leaf(
					forearm,
					0.34,
					if index == 2 then LEAF_DARK else LEAF,
					CFrame.new(side * (fs.X / 2 + 0.1), fs.Y * 0.3, z)
						* CFrame.Angles(0, 0, -side * 1.0)
						* CFrame.Angles(0, math.pi / 2, 0)
						* CFrame.new(0, 0.15, 0)
				)
			end
			local leg = body.upperLeg[side]
			local ls = leg.size
			band(leg, -ls.Y * 0.12, 0.16, 0.08, CEIBA_BARK, WOOD)
			band(leg, -ls.Y * 0.3, 0.06, 0.12, LIANA, FABRIC, 0.3)
			for _, z in { -0.2, 0.2 } do
				ceibaThorn(
					leg,
					Vector3.new(side * (ls.X / 2 + 0.06), -ls.Y * 0.12, z * ls.Z),
					Vector3.new(side, 0.2, z),
					0.22,
					0.1
				)
			end
			leaf(
				leg,
				0.34,
				LEAF,
				CFrame.new(side * (ls.X / 2 + 0.1), -ls.Y * 0.3, 0)
					* CFrame.Angles(0, 0, -side * 0.9)
					* CFrame.Angles(0, math.pi / 2, 0)
					* CFrame.new(0, 0.15, 0)
			)
			leg.ball(0.12, JADE, SMOOTH, CFrame.new(side * (ls.X / 2 + 0.1), -ls.Y * 0.12, 0))
		end

		-- Grado 1: la placa de corteza de la espalda (queda bajo la capa desde el grado 2) con espinas, tres
		-- raíces colgando y hojas.
		if grade == 1 then
			local plaqueY = height * 0.06
			for side = -1, 1, 2 do
				for _, y in { 0.22, 0, -0.22 } do
					ceibaThorn(
						make,
						Vector3.new(side * width * 0.26, plaqueY + height * y, back + 0.14),
						Vector3.new(side, y * 1.5, 0.5),
						0.24,
						0.11
					)
				end
			end
			for index = 0, 2 do
				make.fang(
					0.35,
					0.2,
					CEIBA_BARK,
					WOOD,
					CFrame.new((index - 1) * width * 0.14, plaqueY - height * 0.28, back + 0.14)
						* CFrame.Angles(math.pi, 0, 0)
				)
			end
			for _, spot in { { -0.3, 0.28, 0.5 }, { 0.3, 0.3, -0.5 }, { 0, -0.36, 0 } } do
				leaf(
					make,
					0.34,
					LEAF,
					CFrame.new(spot[1] * width, plaqueY + spot[2] * height, back + 0.14)
						* BEHIND
						* CFrame.Angles(0, 0, spot[3])
				)
			end
		end

		-- Grado 2: la capa, con enredaderas, musgo y cuatro flores.
		if grade >= 2 then
			local capeHeight = height * 1.16
			local capeTop = height / 2 - 0.05
			local capeZ = back + 0.2
			for side = -1, 1, 2 do
				for index = 0, 2 do
					local x = side * width * (0.34 + index * 0.06)
					local bottom =
						Vector3.new(x + side * 0.05, capeTop - capeHeight * (0.4 + index * 0.13), capeZ + 0.09)
					strap(make, Vector3.new(x, capeTop - capeHeight * 0.04, capeZ + 0.09), bottom, 0.05, LIANA, FABRIC)
					leaf(make, 0.3, LEAF, CFrame.new(bottom) * BEHIND * CFrame.Angles(0, 0, math.pi + side * 0.4))
				end
			end
			for index = 0, 9 do
				make.oval(
					Vector3.new(0.22 + (index % 3) * 0.06, 0.12, 0.03),
					LEAF_DARK,
					SMOOTH,
					CFrame.new(
						((index * 0.37) % 1 - 0.5) * width * 0.8,
						capeTop - capeHeight * (0.12 + (index * 0.173) % 0.7),
						capeZ + 0.07
					)
				)
			end
			for _, spot in { { -0.4, 0.2 }, { 0.4, 0.35 }, { -0.4, 0.55 }, { 0.4, 0.7 } } do
				ceibaBlossom(
					make,
					CFrame.new(spot[1] * width, capeTop - capeHeight * spot[2], capeZ + 0.1) * BEHIND,
					0.26
				)
			end
		end
	end

	-- Traje mítico del médico, Ceiba de la Vida. Grado 0: túnica de lino, peto de corteza con el canto de
	-- oro y espinas en las esquinas y, en un disco de jade, el glifo de oro del árbol del mundo (una cruz de
	-- ramas con brotes), gorguera de oro con jade, bandolera con tres frascos de savia, cinturón de raíces
	-- trenzadas con hebilla de jade, taparrabos de lino con una bolsa de hierbas, brazaletes de oro y
	-- brazales de corteza con espinas. Detrás, una placa de corteza con el glifo y un brote de tres hojas.
	-- Grado 1: hombreras de corteza con espinas, hojas y un fruto. Grado 2: capa de tela de corteza con
	-- cantos de oro y un fleco de hojas, cuello de hojas, broches, faldones y, de motivo, la base del tronco
	-- de la ceiba con sus raíces de contrafuerte y un brote con flor. Grado 3: el tronco sube por la espalda
	-- y se abre en dos ramas por encima de los hombros (la cabeza queda libre entre ellas), con espinas,
	-- flores rosas, lianas y vetas de savia verde que brillan; brillan el glifo, los frascos y el algodón de
	-- los frutos. Grado 4: la copa, rosetas de hojas grandes en arco por encima de los hombros con cuatro
	-- ramas más, frutos abiertos con algodón que cae, motas de curación, dos colibríes y cristales verdes en
	-- las hombreras.
	local function ceibaOfLife(body: Body, grade: number)
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local lit = grade >= 3
		local BEHIND = CFrame.Angles(0, math.pi, 0)
		make.block(
			Vector3.new(width + 0.1, height * 0.92, depth + 0.14),
			LINEN,
			FABRIC,
			CFrame.new(0, -height * 0.03, 0)
		)

		-- El glifo del árbol del mundo en "at" (mirando a su -Z): disco de jade en un aro de oro y un árbol de
		-- oro en Y (tronco con dos raíces y dos ramas abiertas) con un brote en cada punta (verde que brilla
		-- desde el grado 3). En cruz se leía como una cruz cristiana.
		local function worldTree(at: CFrame, size: number)
			make.rod(0.06, size, TITAN_GOLD, SMOOTH, at * FACING)
			make.rod(0.06, size * 0.84, JADE, SMOOTH, at * CFrame.new(0, 0, -0.02) * FACING)
			local glyph = at * CFrame.new(0, 0, -0.05)
			make.block(Vector3.new(0.08, size * 0.42, 0.04), TITAN_GOLD, SMOOTH, glyph * CFrame.new(0, -size * 0.08, 0))
			local tips = { glyph * CFrame.new(0, size * 0.2, 0) }
			for side = -1, 1, 2 do
				local branch = glyph * CFrame.new(side * size * 0.1, size * 0.1, 0) * CFrame.Angles(0, 0, -side * 0.7)
				make.block(Vector3.new(0.07, size * 0.26, 0.04), TITAN_GOLD, SMOOTH, branch)
				table.insert(tips, branch * CFrame.new(0, size * 0.14, 0))
				make.block(
					Vector3.new(0.06, size * 0.14, 0.04),
					TITAN_GOLD,
					SMOOTH,
					glyph * CFrame.new(side * size * 0.06, -size * 0.3, 0) * CFrame.Angles(0, 0, side * 0.8)
				)
			end
			for _, tip in tips do
				make.ball(
					size * 0.15,
					if lit then HEAL_GLOW else LEAF,
					if lit then NEON else SMOOTH,
					tip * CFrame.new(0, 0, -0.02)
				)
			end
		end

		-- Peto de corteza con el canto de oro, espinas en las esquinas de arriba y el glifo.
		local plate = CFrame.new(0, height * 0.14, front - 0.03)
		make.block(Vector3.new(width * 0.62, height * 0.5, 0.12), TITAN_GOLD, SMOOTH, plate * CFrame.new(0, 0, 0.02))
		make.block(Vector3.new(width * 0.56, height * 0.44, 0.12), CEIBA_BARK, WOOD, plate * CFrame.new(0, 0, -0.01))
		for side = -1, 1, 2 do
			ceibaThorn(
				make,
				(plate * CFrame.new(side * width * 0.28, height * 0.2, -0.06)).Position,
				Vector3.new(side, 0.6, -0.5),
				0.26,
				0.12
			)
		end
		worldTree(plate * CFrame.new(0, 0, -0.08), width * 0.34)

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

		-- Bandolera del hombro izquierdo a la cadera derecha con tres frascos de savia.
		local strapFrom = Vector3.new(-width * 0.34, height / 2 - 0.02, front - 0.1)
		local strapTo = Vector3.new(width * 0.4, -height / 2 + 0.12, front - 0.1)
		strap(make, strapFrom, strapTo, 0.14, LEATHER, LEATHER_MATERIAL)
		for _, t in { 0.62, 0.76, 0.9 } do
			flask(make, CFrame.new(strapFrom:Lerp(strapTo, t) + Vector3.new(0, -0.06, -0.1)), 0.2, lit)
		end

		-- Espalda (grados 0 y 1): placa de corteza con el glifo y un brote de tres hojas.
		if grade < 2 then
			local plaque = CFrame.new(0, height * 0.06, back + 0.08) * BEHIND
			make.block(
				Vector3.new(width * 0.5, height * 0.56, 0.1),
				TITAN_GOLD,
				SMOOTH,
				plaque * CFrame.new(0, 0, 0.02)
			)
			make.block(Vector3.new(width * 0.44, height * 0.5, 0.1), CEIBA_BARK, WOOD, plaque)
			worldTree(plaque * CFrame.new(0, -0.04, -0.06), width * 0.3)
			for index = -1, 1 do
				leaf(
					make,
					0.4,
					LEAF,
					plaque
						* CFrame.new(index * 0.12, height * 0.3, -0.04)
						* CFrame.Angles(0, 0, -index * 0.5)
						* CFrame.new(0, 0.18, 0)
				)
			end
		end

		-- Cinturón de raíces trenzadas con hebilla de jade, taparrabos de lino y una bolsa de hierbas.
		local waist = body.waist
		local hipWidth, hipDepth = waist.size.X, waist.size.Z
		local beltFront = -(hipDepth / 2 + 0.09)
		waist.block(Vector3.new(hipWidth + 0.16, 0.24, hipDepth + 0.18), CEIBA_BARK_DARK, WOOD, CFrame.new(0, 0.05, 0))
		for index = -1, 1, 2 do
			waist.block(
				Vector3.new(hipWidth + 0.18, 0.05, hipDepth + 0.2),
				CEIBA_BARK,
				WOOD,
				CFrame.new(0, 0.05 + index * 0.07, 0) * CFrame.Angles(0, 0, index * 0.04)
			)
		end
		local buckle = CFrame.new(0, 0.05, beltFront - 0.03)
		waist.rod(0.06, 0.42, TITAN_GOLD, SMOOTH, buckle * FACING)
		waist.oval(Vector3.new(0.3, 0.28, 0.1), JADE, SMOOTH, buckle * CFrame.new(0, 0, -0.04))
		for _, z in { beltFront + 0.02, -beltFront - 0.02 } do
			waist.block(Vector3.new(hipWidth * 0.4, 0.6, 0.06), LINEN, FABRIC, CFrame.new(0, -0.38, z))
			waist.block(Vector3.new(hipWidth * 0.42, 0.06, 0.08), TITAN_GOLD, SMOOTH, CFrame.new(0, -0.66, z))
		end
		herbPouch(waist, CFrame.new(-hipWidth * 0.32, -0.14, beltFront - 0.06), LEAF)

		-- Brazos: brazaletes de oro con jade y brazales de corteza con dos espinas y una liana.
		for side = -1, 1, 2 do
			local upper = body.upperArm[side]
			local us = upper.size
			band(upper, -us.Y * 0.2, 0.12, 0.08, TITAN_GOLD, SMOOTH)
			upper.ball(0.15, JADE, SMOOTH, CFrame.new(side * (us.X / 2 + 0.06), -us.Y * 0.2, 0))
			local forearm = body.lowerArm[side]
			local fs = forearm.size
			band(forearm, -fs.Y * 0.05, fs.Y * 0.55, 0.1, CEIBA_BARK, WOOD)
			band(forearm, -fs.Y * 0.05, 0.06, 0.14, LIANA, FABRIC, 0.3)
			for _, y in { fs.Y * 0.1, -fs.Y * 0.22 } do
				ceibaThorn(forearm, Vector3.new(side * (fs.X / 2 + 0.05), y, 0), Vector3.new(side, 0.3, 0), 0.22, 0.1)
			end
			if grade >= 1 then
				ceibaPauldron(upper, side, grade)
			end
		end

		-- Grado 2: capa de hojas, cuello de hojas, broches y faldones; el tronco y sus raíces.
		if grade >= 2 then
			make.block(
				Vector3.new(width + 0.36, 0.3, depth * 0.62),
				CEIBA_BARK_DARK,
				FABRIC,
				CFrame.new(0, height / 2 - 0.06, depth * 0.24)
			)
			for index = 0, 6 do
				local x = (index / 6 - 0.5) * (width + 0.2)
				leaf(
					make,
					0.42,
					if index % 2 == 0 then LEAF else LEAF_DARK,
					CFrame.new(x, height / 2 - 0.3, front - 0.02) * CFrame.Angles(0, math.pi, math.pi)
				)
			end
			local capeHeight = height * 1.16
			local capeTop = height / 2 - 0.05
			local capeZ = back + 0.2
			make.block(
				Vector3.new(width * 1.02, capeHeight, 0.12),
				CEIBA_BARK_DARK,
				FABRIC,
				CFrame.new(0, capeTop - capeHeight / 2, capeZ)
			)
			for side = -1, 1, 2 do
				make.block(
					Vector3.new(0.08, capeHeight, 0.14),
					TITAN_GOLD,
					SMOOTH,
					CFrame.new(side * width * 0.5, capeTop - capeHeight / 2, capeZ + 0.01)
				)
			end
			-- Solo un fleco de hojas en el bajo: filas de hojas por toda la capa tapaban el tronco.
			for index = 0, 6 do
				local x = (index / 6 - 0.5) * width * 0.92
				leaf(
					make,
					0.5,
					if index % 2 == 0 then LEAF else LEAF_DARK,
					CFrame.new(x, capeTop - capeHeight - 0.12, capeZ + 0.07) * BEHIND * CFrame.Angles(0, 0, math.pi)
				)
			end
			local clasps = {}
			for side = -1, 1, 2 do
				local clasp = CFrame.new(side * width * 0.36, height / 2 - 0.12, front - 0.06)
				make.rod(0.08, 0.3, TITAN_GOLD, SMOOTH, clasp * FACING)
				make.ball(0.14, JADE, SMOOTH, clasp * CFrame.new(0, 0, -0.06))
				clasps[side] = clasp.Position
			end
			local sag = Vector3.new(0, height / 2 - 0.3, front - 0.12)
			strap(make, clasps[-1], sag, 0.05, TITAN_GOLD, SMOOTH)
			strap(make, sag, clasps[1], 0.05, TITAN_GOLD, SMOOTH)
			for side = -1, 1, 2 do
				local leg = body.upperLeg[side]
				local ls = leg.size
				local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.06))
					* CFrame.Angles(0.1, 0, 0)
				leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.42, 0.1), LINEN, FABRIC, flap)
				leg.block(
					Vector3.new(ls.X * 0.92, 0.06, 0.12),
					TITAN_GOLD,
					SMOOTH,
					flap * CFrame.new(0, -ls.Y * 0.2, 0)
				)
				leaf(
					leg,
					0.36,
					LEAF,
					flap * CFrame.new(side * 0.1, -0.04, -0.07) * CFrame.Angles(0, math.pi, math.pi + side * 0.3)
				)
			end

			-- La base del tronco, de corteza clara sobre la capa oscura, con cinco raíces de contrafuerte
			-- abiertas, espinas, un aro de oro con jade y, en el grado 2, un brote con una flor en lo alto.
			local trunkZ = capeZ + 0.3
			local baseY = capeTop - capeHeight * 0.8
			make.oval(Vector3.new(0.9, 1.2, 0.5), CEIBA_BARK, WOOD, CFrame.new(0, baseY + 0.45, trunkZ))
			for index = -2, 2 do
				local root = CFrame.new(0, baseY + 0.1, trunkZ - 0.04) * CFrame.Angles(0, 0, math.pi + index * 0.5)
				make.fang(0.95 - math.abs(index) * 0.08, 0.36, CEIBA_BARK, WOOD, root * CFrame.new(-0.18, 0, 0.18))
			end
			make.rod(0.1, 0.86, TITAN_GOLD, SMOOTH, CFrame.new(0, baseY + 0.8, trunkZ) * UPRIGHT)
			make.ball(0.22, JADE, SMOOTH, CFrame.new(0, baseY + 0.8, trunkZ + 0.4))
			for _, y in { 0.2, 0.5 } do
				for side = -1, 1, 2 do
					ceibaThorn(
						make,
						Vector3.new(side * 0.3, baseY + y + (side + 1) * 0.06, trunkZ + 0.12),
						Vector3.new(side * 0.6, 0.2, 1),
						0.3,
						0.13
					)
				end
			end
			if grade == 2 then
				leafCluster(make, CFrame.new(0, baseY + 1.2, trunkZ + 0.08) * BEHIND, 6, 0.5)
				ceibaBlossom(make, CFrame.new(0, baseY + 1.2, trunkZ + 0.16) * BEHIND, 0.34)
			else
				-- Grado 3: el tronco sube y se abre en dos ramas por encima de los hombros (la cabeza queda libre
				-- entre ellas), con espinas, vetas de savia que brillan, flores y una liana colgando de cada una.
				local fork = Vector3.new(0, height * 0.3, trunkZ - 0.04)
				ceibaBranch(
					make,
					{ Vector3.new(0, baseY + 0.9, trunkZ), Vector3.new(0.05, height * 0.02, trunkZ - 0.02), fork },
					0.5,
					true
				)
				for _, offset in { -0.12, 0.12 } do
					lavaVein(make, {
						Vector3.new(offset, baseY + 0.3, trunkZ + 0.25),
						Vector3.new(offset * 1.6, baseY + 0.9, trunkZ + 0.25),
						Vector3.new(offset, height * 0.1, trunkZ + 0.22),
						Vector3.new(offset * 1.4, height * 0.28, trunkZ + 0.2),
					}, 0.05, HEAL_GLOW)
				end
				local tips, elbows = {}, {}
				for side = -1, 1, 2 do
					local elbow = Vector3.new(side * width * 0.42, height * 0.62, trunkZ - 0.1)
					local tip = Vector3.new(side * width * 0.82, height * 0.86, trunkZ - 0.2)
					ceibaBranch(make, { fork, elbow, tip }, 0.34, true)
					tips[side], elbows[side] = tip, elbow
					ceibaBlossom(make, CFrame.new(elbow + Vector3.new(0, 0.18, 0.2)) * BEHIND, 0.42)
					leafCluster(
						make,
						CFrame.new(tip) * BEHIND,
						if grade >= 4 then 8 else 7,
						if grade >= 4 then 0.7 else 0.58
					)
					local hang = elbow + Vector3.new(side * 0.12, -0.9, 0.16)
					strap(make, elbow + Vector3.new(0, -0.1, 0.12), hang, 0.05, LIANA, FABRIC)
					leaf(make, 0.3, LEAF, CFrame.new(hang) * BEHIND * CFrame.Angles(0, 0, math.pi + side * 0.4))
				end
				local sap = make.ball(0.24, HEAL_GLOW, NEON, CFrame.new(fork + Vector3.new(0, 0, 0.26)))
				fireLight(sap, HEAL_GLOW)

				-- Ramitas con hojas, un fruto abierto y una veta de savia más por rama, cinco brotes rosas en el
				-- tronco y diez luciérnagas de curación alrededor del árbol.
				for side = -1, 1, 2 do
					local elbow, tip = elbows[side], tips[side]
					for _, twig in { { fork, elbow, 0.25 }, { fork, elbow, 0.7 }, { elbow, tip, 0.5 } } do
						local start = twig[1]:Lerp(twig[2], twig[3])
						local finish = start + Vector3.new(side * 0.25, 0.35, 0.05)
						ceibaBranch(make, { start, finish }, 0.12, false)
						leaf(make, 0.3, LEAF, CFrame.new(finish) * BEHIND * CFrame.Angles(0, 0, side * 0.6))
					end
					kapokPod(make, CFrame.new(elbow + Vector3.new(side * 0.1, -0.25, 0.2)), 0.36, true, true)
					lavaVein(make, {
						fork + Vector3.new(0, 0, 0.18),
						elbow + Vector3.new(0, 0, 0.18),
						tip + Vector3.new(0, 0, 0.12),
					}, 0.05, HEAL_GLOW)
				end
				for index = 0, 4 do
					make.ball(
						0.1,
						CEIBA_BLOSSOM,
						SMOOTH,
						CFrame.new((index % 2 * 2 - 1) * 0.22, baseY + 0.9 + index * 0.25, trunkZ + 0.28)
					)
				end
				for index = 0, 9 do
					make.ball(
						0.08,
						HEAL_GLOW,
						NEON,
						CFrame.new(
							math.sin(index * 2.1) * width * 0.8,
							height * (0.3 + (index * 0.137) % 0.5),
							trunkZ + 0.1 + math.cos(index * 1.7) * 0.2
						)
					)
				end

				-- Grado 4: la copa: dos ramas más hacia arriba y rosetas grandes en arco por encima de los
				-- hombros (sin tapar la cabeza), frutos abiertos con algodón que cae, motas de curación y dos
				-- colibríes junto a las flores.
				if grade >= 4 then
					for side = -1, 1, 2 do
						local tip = Vector3.new(side * width * 0.5, height * 1.08, trunkZ - 0.16)
						ceibaBranch(make, { elbows[side]:Lerp(fork, 0.4), tip }, 0.22, false)
						leafCluster(make, CFrame.new(tip) * BEHIND, 7, 0.6)
						ceibaBlossom(make, CFrame.new(tip + Vector3.new(0, 0, 0.14)) * BEHIND, 0.34)
						local outer = Vector3.new(side * width * 1.02, height * 0.58, trunkZ - 0.24)
						ceibaBranch(make, { elbows[side], outer }, 0.2, false)
						leafCluster(make, CFrame.new(outer) * BEHIND, 6, 0.5)
						local fluff = kapokPod(
							make,
							CFrame.new(tips[side] + Vector3.new(-side * 0.16, -0.3, 0.16)),
							0.42,
							true,
							true
						)
						lifeMotes(fluff, 2, true)
						hummingbird(
							make,
							CFrame.new(tip + Vector3.new(side * 0.42, -0.3, 0.34)) * CFrame.Angles(0, side * 2.2, 0),
							1.5
						)
					end
					lifeMotes(sap, 5, false)
					for index = 0, 3 do
						make.ball(
							0.08,
							HEAL_GLOW,
							NEON,
							CFrame.new(
								math.sin(index * 1.3 + 0.5) * width * 0.9,
								height * (0.9 + index * 0.08),
								trunkZ - 0.1
							)
						)
					end
				end
			end
		end
		ceibaRichness(body, grade)
	end

	OUTFITS.CeibaOfLifeOutfit = ceibaOfLife
end

-- ===================================== Temporada 1: fuego azul y azufre =====================================
-- Trajes de la Temporada 1, "El Despertar del Volcán" (Data/Seasons, rareza Legendaria): piedra pómez
-- clara, carbón, cristales de azufre y fuego azul (el del azufre que arde), para que nunca se confundan con
-- la armadura volcánica del nivel 4 (obsidiana negra y lava naranja). Como los míticos, ganan piezas con el
-- grado de la armadura que se lleva debajo (0 a 4, enteros en el Lobby y en Dunas), pero menos: 0, la
-- coraza; 1, las hombreras; 2, el motivo del pecho y los cristales; 3, un cráter con una llama pequeña a la
-- espalda; 4, la gran llamarada con llamas de partículas y su luz.

do
	-- Pómez algo tostada: más clara y fría, con la luz de Studio salía lila y, junto al azul, parecía hielo.
	local PUMICE = Color3.fromRGB(184, 172, 152)
	local PUMICE_DARK = Color3.fromRGB(138, 128, 112)
	local CHARCOAL = Color3.fromRGB(52, 50, 56)
	local BLUE_FIRE = Color3.fromRGB(45, 120, 255)
	local BLUE_FIRE_MID = Color3.fromRGB(90, 185, 255)
	local BLUE_FIRE_PALE = Color3.fromRGB(190, 235, 255)

	-- Fuego azul que sale de "part" (llamas de "size" que suben), con su luz.
	local function blueFire(part: BasePart, rate: number, size: number)
		local flames = Instance.new("ParticleEmitter")
		flames.Texture = "rbxasset://textures/particles/fire_main.dds"
		flames.Color = ColorSequence.new(BLUE_FIRE_PALE, BLUE_FIRE)
		flames.LightEmission = 1
		flames.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, 0) })
		flames.Transparency = NumberSequence.new(0.1, 1)
		flames.Lifetime = NumberRange.new(0.5, 0.9)
		flames.Rate = rate
		flames.Speed = NumberRange.new(size, size * 2)
		flames.SpreadAngle = Vector2.new(12, 12)
		flames.Rotation = NumberRange.new(0, 360)
		flames.RotSpeed = NumberRange.new(-60, 60)
		flames.Parent = part
		fireLight(part, BLUE_FIRE)
	end

	-- Paleta de la llama en píxeles (pixelFlame): fuego azul por fuera, celeste y el corazón casi blanco.
	local BLUE_FLAME: { [string]: Color3 } = { X = BLUE_FIRE, C = BLUE_FIRE_MID, W = BLUE_FIRE_PALE }

	-- Hombrera del fuego azul: losa de pómez inclinada hacia fuera con una piedra encima, canto de carbón y
	-- una raya de fuego azul debajo; tres cristales de azufre grandes alrededor de una llama en píxeles que,
	-- con "lit", echa fuego.
	local function blueFirePauldron(arm: Builder, side: number, grade: number)
		local lit = grade >= 4
		local as = arm.size
		local top = as.Y / 2
		local pad = CFrame.new(side * 0.14, top + 0.08, 0) * CFrame.Angles(0, 0, -side * 0.22)
		arm.block(Vector3.new(as.X * 1.5, 0.42, as.Z * 1.5), PUMICE, SLATE, pad)
		arm.block(Vector3.new(as.X * 1.58, 0.1, as.Z * 1.58), CHARCOAL, SLATE, pad * CFrame.new(0, -0.25, 0))
		arm.block(
			Vector3.new(as.X * 1.58 + 0.04, 0.05, as.Z * 1.58 + 0.04),
			BLUE_FIRE,
			NEON,
			pad * CFrame.new(0, -0.32, 0)
		)
		arm.block(Vector3.new(as.X * 0.8, 0.18, as.Z * 1.1), PUMICE_DARK, SLATE, pad * CFrame.new(side * 0.16, 0.3, 0))
		for index, spec in
			{
				{ x = 0.22, z = -0.34, length = 0.62 },
				{ x = 0.36, z = 0.05, length = 0.5 },
				{ x = 0.2, z = 0.36, length = 0.74 },
			}
		do
			fireCrystal(
				arm,
				Vector3.new(side * spec.x, top + 0.34, spec.z),
				Vector3.new(side * (0.3 + spec.x), 1, spec.z * 0.9),
				spec.length,
				if index == 3 then 0.32 else 0.28,
				SULFUR,
				SULFUR_GLOW
			)
		end
		local foot = pixelFlame(arm, SMALL_FLAME, BLUE_FLAME, CFrame.new(side * 0.02, top + 0.36, 0), 0.12, side < 0)
		if lit then
			blueFire(foot, 5, 0.5)
			smoke(foot, 1.5, Color3.fromRGB(150, 160, 190), 0.5)
		end
		-- Grado 1: remaches de azufre en las cuatro esquinas de la losa y dos grabados de carbón en sus bordes.
		for sz = -1, 1, 2 do
			for sx = -1, 1, 2 do
				arm.ball(0.12, SULFUR, SMOOTH, pad * CFrame.new(sx * as.X * 0.72, 0.24, sz * as.Z * 0.72))
			end
			arm.block(Vector3.new(as.X * 1.3, 0.04, 0.1), CHARCOAL, SLATE, pad * CFrame.new(0, 0.23, sz * as.Z * 0.66))
		end
		-- Grado 2: tres gotas de fuego azul que cuelgan del canto de fuera y un cristal que sale hacia fuera.
		if grade >= 2 then
			for _, z in { -0.5, 0, 0.5 } do
				lavaDrip(
					arm,
					pad * CFrame.new(side * as.X * 0.76, -0.34, z * as.Z),
					0.3 - math.abs(z) * 0.1,
					BLUE_FIRE_MID
				)
			end
			fireCrystal(
				arm,
				(pad * CFrame.new(side * as.X * 0.7, 0.2, 0)).Position,
				pad:VectorToWorldSpace(Vector3.new(side, 0.7, 0)),
				0.5,
				0.2,
				SULFUR,
				SULFUR_GLOW
			)
		end
		-- Grado 3: aleta de carbón en el borde de fuera con una raya de fuego azul y tres remaches.
		if grade >= 3 then
			local fin = pad * CFrame.new(side * as.X * 0.8, 0.3, 0) * CFrame.Angles(0, 0, -side * 0.2)
			arm.block(Vector3.new(0.1, 0.45, as.Z * 1.2), CHARCOAL, SLATE, fin)
			arm.block(Vector3.new(0.04, 0.3, as.Z * 0.9), BLUE_FIRE, NEON, fin * CFrame.new(side * 0.06, -0.05, 0))
			for _, z in { -1, 0, 1 } do
				arm.ball(0.1, SULFUR, SMOOTH, fin * CFrame.new(side * 0.08, 0.14, z * as.Z * 0.5))
			end
		end
		-- Grado 4: dos cristales altos en las esquinas de dentro y una chispa que sube sobre la llama.
		if lit then
			for sz = -1, 1, 2 do
				fireCrystal(
					arm,
					(pad * CFrame.new(side * as.X * 0.5, 0.2, sz * as.Z * 0.62)).Position,
					pad:VectorToWorldSpace(Vector3.new(side * 0.4, 1, sz * 0.5)),
					0.9,
					0.26,
					SULFUR,
					SULFUR_GLOW
				)
			end
			arm.ball(0.1, BLUE_FIRE_PALE, NEON, CFrame.new(side * 0.02, top + 1.3, 0))
		end
	end

	-- Brasas: bolitas de neón pálido (la mitad, más pequeñas) en los puntos de "points".
	local function motes(make: Builder, points: { Vector3 }, size: number)
		for index, at in points do
			make.ball(if index % 2 == 0 then size else size * 0.7, BLUE_FIRE_PALE, NEON, CFrame.new(at))
		end
	end

	-- Hilera de gotas de fuego azul que cuelgan de "at" (su borde de arriba) en las X de "xs", alternando largo.
	local function drips(make: Builder, at: CFrame, xs: { number }, length: number)
		for index, x in xs do
			lavaDrip(make, at * CFrame.new(x, 0, 0), if index % 2 == 0 then length * 0.7 else length, BLUE_FIRE_MID)
		end
	end

	-- Marco de la espalda (Guardián e Invocador): de ancho "width" y alto "height", centrado en "y" a la
	-- profundidad "z" de la placa. Dos pilares de pómez con remaches y una raya azul por dentro (con
	-- "pillars"), una viga de carbón arriba con la raya de fuego azul, cuatro escuadras en las esquinas, una
	-- hilera de "dripCount" gotas azules abajo y "crown" cristales de azufre que salen de la viga.
	local function backFrame(
		make: Builder,
		width: number,
		height: number,
		y: number,
		z: number,
		pillars: boolean,
		dripCount: number,
		crown: number
	)
		local halfW, halfH = width / 2, height / 2
		if pillars then
			for side = -1, 1, 2 do
				make.block(
					Vector3.new(0.14, height, 0.1),
					PUMICE,
					SLATE,
					CFrame.new(side * (halfW - 0.07), y, z + 0.04)
				)
				make.block(
					Vector3.new(0.04, height * 0.86, 0.1),
					BLUE_FIRE,
					NEON,
					CFrame.new(side * (halfW - 0.18), y, z + 0.05)
				)
				for _, up in { 0.3, 0, -0.3 } do
					make.ball(0.13, SULFUR, SMOOTH, CFrame.new(side * (halfW - 0.07), y + height * up, z + 0.1))
				end
			end
		end
		local beamY = y + halfH - 0.04
		make.block(Vector3.new(width, 0.14, 0.14), CHARCOAL, SLATE, CFrame.new(0, beamY, z + 0.05))
		make.block(Vector3.new(width, 0.04, 0.1), BLUE_FIRE, NEON, CFrame.new(0, beamY + 0.09, z + 0.05))
		for side = -1, 1, 2 do
			for up = -1, 1, 2 do
				make.block(
					Vector3.new(0.26, 0.26, 0.14),
					PUMICE_DARK,
					SLATE,
					CFrame.new(side * (halfW - 0.13), y + up * (halfH - 0.13), z + 0.04)
				)
			end
		end
		local xs = {}
		for index = 1, dripCount do
			xs[index] = (index - (dripCount + 1) / 2) / dripCount * width * 0.9
		end
		drips(make, CFrame.new(0, y - halfH, z + 0.02), xs, 0.3)
		for index = 1, crown do
			local x = (index - (crown + 1) / 2) / crown * width * 0.8
			fireCrystal(
				make,
				Vector3.new(x, beamY + 0.1, z + 0.05),
				Vector3.new(x * 1.2, 1, 0.5),
				if index % 2 == 0 then 0.42 else 0.58,
				0.2,
				SULFUR,
				SULFUR_GLOW
			)
		end
	end

	-- Cinturón de carbón con la hebilla de pómez: un tachón de azufre y, desde el grado 2, dos cristales.
	-- Desde el grado 1 lleva remaches y dos muescas de fuego azul; desde el 2, dos gotas azules; desde el 3,
	-- otras dos con sus remaches; en el 4, una chispa en la hebilla y una gota central.
	-- Devuelve el frente del cinturón (su Z), para colgar más cosas.
	local function seasonBelt(body: Body, grade: number): number
		local waist = body.waist
		local hipWidth, hipDepth = waist.size.X, waist.size.Z
		local beltFront = -(hipDepth / 2 + 0.09)
		waist.block(Vector3.new(hipWidth + 0.16, 0.28, hipDepth + 0.18), CHARCOAL, SLATE, CFrame.new(0, 0.06, 0))
		local buckle = CFrame.new(0, 0.06, beltFront - 0.05)
		waist.block(Vector3.new(0.46, 0.36, 0.1), PUMICE, SLATE, buckle)
		waist.block(Vector3.new(0.3, 0.22, 0.06), CHARCOAL, SLATE, buckle * CFrame.new(0, 0, -0.05))
		waist.ball(0.18, SULFUR, SMOOTH, buckle * CFrame.new(0, 0, -0.08))
		if grade >= 1 then
			for side = -1, 1, 2 do
				for _, x in { 0.2, 0.34 } do
					waist.ball(0.12, SULFUR, SMOOTH, CFrame.new(side * hipWidth * x, 0.06, beltFront - 0.03))
				end
				waist.block(
					Vector3.new(0.04, 0.2, 0.03),
					BLUE_FIRE,
					NEON,
					CFrame.new(side * hipWidth * 0.27, 0.06, beltFront - 0.02)
				)
			end
		end
		if grade >= 2 then
			for side = -1, 1, 2 do
				fireCrystal(
					waist,
					(buckle * CFrame.new(side * 0.2, 0.12, 0)).Position,
					Vector3.new(side, 1, -0.3),
					0.26,
					0.12,
					SULFUR,
					SULFUR_GLOW
				)
			end
			drips(waist, CFrame.new(0, -0.09, beltFront - 0.02), { -hipWidth * 0.27, hipWidth * 0.27 }, 0.26)
		end
		if grade >= 3 then
			drips(waist, CFrame.new(0, -0.09, beltFront - 0.02), { -hipWidth * 0.4, hipWidth * 0.4 }, 0.2)
			for side = -1, 1, 2 do
				waist.ball(0.1, SULFUR, SMOOTH, CFrame.new(side * hipWidth * 0.4, 0.06, beltFront - 0.03))
			end
		end
		if grade >= 4 then
			waist.ball(0.1, BLUE_FIRE_PALE, NEON, buckle * CFrame.new(0, 0, -0.17))
			drips(waist, CFrame.new(0, -0.09, beltFront - 0.02), { 0 }, 0.3)
		end
		return beltFront
	end

	-- Brazos y muslos de los trajes de la temporada: hombreras desde el grado 1, brazales de pómez con una
	-- raya de fuego azul y un cristal de azufre desde el grado 2, y faldones de "flap" con una placa de
	-- carbón, la raya azul y un tachón (más largos con "long", los de las túnicas).
	local function seasonLimbs(body: Body, grade: number, flap: Color3, flapMaterial: Enum.Material, long: boolean?)
		for side = -1, 1, 2 do
			if grade >= 1 then
				blueFirePauldron(body.upperArm[side], side, grade)
			end
			local forearm = body.lowerArm[side]
			local fs = forearm.size
			band(forearm, 0.05, fs.Y * 0.6, 0.1, PUMICE, SLATE)
			band(forearm, fs.Y * 0.32, 0.06, 0.14, BLUE_FIRE, NEON)
			band(forearm, -fs.Y / 2 + 0.12, 0.12, 0.14, CHARCOAL, SLATE)
			-- Grado 1: dos anillos de pómez oscura; 2: dos remaches; 3 y 4: espolones de azufre hacia atrás.
			if grade >= 1 then
				band(forearm, fs.Y * 0.18, 0.05, 0.18, PUMICE_DARK, SLATE)
				band(forearm, -fs.Y * 0.12, 0.05, 0.18, PUMICE_DARK, SLATE)
			end
			if grade >= 2 then
				for _, up in { 0.22, -0.22 } do
					forearm.ball(0.1, SULFUR, SMOOTH, CFrame.new(side * (fs.X / 2 + 0.06), fs.Y * up, -0.12))
				end
			end
			if grade >= 3 then
				fireCrystal(
					forearm,
					Vector3.new(side * fs.X * 0.3, fs.Y / 2 - 0.12, fs.Z / 2 + 0.04),
					Vector3.new(side * 0.4, 0.3, 1),
					0.45,
					0.18,
					SULFUR,
					SULFUR_GLOW
				)
			end
			if grade >= 4 then
				fireCrystal(
					forearm,
					Vector3.new(side * fs.X * 0.3, 0.1, fs.Z / 2 + 0.04),
					Vector3.new(side * 0.5, 0, 1),
					0.35,
					0.16,
					SULFUR,
					SULFUR_GLOW
				)
			end
			if grade >= 2 then
				fireCrystal(
					forearm,
					Vector3.new(side * (fs.X / 2), 0.05, 0.1),
					Vector3.new(side, 0.4, 0.5),
					0.4,
					0.18,
					SULFUR,
					SULFUR_GLOW
				)
			end
			local leg = body.upperLeg[side]
			local ls = leg.size
			local tall = if long then 0.6 else 0.44
			local at = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * (if long then 0.3 else 0.2), -(ls.Z / 2 + 0.06))
				* CFrame.Angles(0.1, 0, 0)
			leg.block(Vector3.new(ls.X * 0.9, ls.Y * tall, 0.1), flap, flapMaterial, at)
			leg.block(Vector3.new(ls.X * 0.62, ls.Y * 0.28, 0.06), CHARCOAL, SLATE, at * CFrame.new(0, 0.02, -0.07))
			leg.block(
				Vector3.new(ls.X * 0.9, 0.06, 0.12),
				BLUE_FIRE,
				NEON,
				at * CFrame.new(0, -ls.Y * (tall / 2 - 0.01), -0.01)
			)
			leg.ball(0.12, SULFUR, SMOOTH, at * CFrame.new(0, 0.02, -0.11))
			-- Grado 1: tres gotas de fuego azul bajo el faldón; 2: remaches en sus esquinas de arriba; 3 y 4:
			-- cristales de azufre en el costado del muslo.
			if grade >= 1 then
				drips(leg, at * CFrame.new(0, -ls.Y * tall / 2 - 0.02, -0.02), { -ls.X * 0.28, 0, ls.X * 0.28 }, 0.22)
			end
			if grade >= 2 then
				for _, x in { -0.34, 0.34 } do
					leg.ball(0.1, SULFUR, SMOOTH, at * CFrame.new(x * ls.X, ls.Y * tall * 0.36, -0.1))
				end
			end
			if grade >= 3 then
				fireCrystal(
					leg,
					Vector3.new(side * ls.X / 2, ls.Y * 0.18, 0),
					Vector3.new(side, 0.2, -0.3),
					0.4,
					0.16,
					SULFUR,
					SULFUR_GLOW
				)
			end
			if grade >= 4 then
				fireCrystal(
					leg,
					Vector3.new(side * ls.X / 2, -ls.Y * 0.08, 0),
					Vector3.new(side, 0.1, 0.3),
					0.32,
					0.14,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end
	end

	-- Traje de temporada del guerrero, Guardián del Fuego Azul. Delante: coraza de pómez cruzada por dos
	-- correas de carbón con el canto de fuego azul y tachones de azufre; donde se cruzan, una llama en píxeles
	-- sobre un disco de carbón sujeto por cuatro cristales de azufre; gorguera de carbón con cristales de
	-- azufre alrededor del cuello; cinturón de carbón con la hebilla de pómez. Detrás: una
	-- llamarada azul en píxeles más alta que la cabeza que sale de un cráter de azufre (como el fuego azul de
	-- los volcanes de azufre), sobre una placa de carbón con el borde de fuego azul. Hombreras de losa con
	-- cristales de azufre y su llama, brazales de pómez con un cristal y faldones de pómez con una placa de
	-- carbón. Por grados: 0, la coraza con las correas, el cinturón, los brazales, los faldones y la placa de
	-- la espalda; 1, las hombreras; 2, la llama del pecho, los cristales de la gorguera, de la hebilla y de los
	-- brazales; 3, el cráter de la espalda con una llama pequeña; 4, la llamarada grande y el fuego que sale
	-- de las llamas, con su luz.
	-- Cada grado suma además detalle común (hombreras, brazales, faldones y cinturón con remaches, gotas de
	-- fuego azul y cristales; marco de la espalda con pilares, viga y corona desde el 1; cristales en los
	-- pilares y gotas bajo el disco desde el 2; cristales a los lados del cráter, remaches y brasas desde el 3).
	local function blueFireGuardian(body: Body, grade: number)
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.1)
		local back = depth / 2
		local FACING_FRONT = CFrame.Angles(0, math.pi, 0)
		local lit = grade >= 4
		make.block(
			Vector3.new(width + 0.14, height * 0.94, depth + 0.2),
			PUMICE,
			SLATE,
			CFrame.new(0, -height * 0.02, 0)
		)
		-- Gorguera de carbón y cristales de azufre alrededor del cuello, más largos a los lados.
		make.block(Vector3.new(width * 0.66, 0.16, depth + 0.28), CHARCOAL, SLATE, CFrame.new(0, height * 0.44, 0))
		if grade >= 2 then
			for index = 0, 4 do
				local angle = math.rad(-100 + index * 50)
				fireCrystal(
					make,
					Vector3.new(math.sin(angle) * width * 0.3, height * 0.47, -math.cos(angle) * depth * 0.45),
					Vector3.new(math.sin(angle) * 0.6, 1, -math.cos(angle) * 0.4),
					if index == 2 then 0.24 else 0.34,
					0.16,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end
		-- Correas cruzadas del hombro a la cadera contraria, con tachones de azufre.
		for side = -1, 1, 2 do
			local from = Vector3.new(side * width * 0.42, height * 0.45, front)
			local to = Vector3.new(-side * width * 0.4, -height * 0.44, front)
			strap(make, from + Vector3.new(0, 0, 0.04), to + Vector3.new(0, 0, 0.04), 0.3, BLUE_FIRE, NEON)
			strap(make, from, to, 0.22, CHARCOAL, SLATE)
			for _, t in { 0.12, 0.3, 0.7, 0.88 } do
				make.ball(0.12, SULFUR, SMOOTH, CFrame.new(from:Lerp(to, t) + Vector3.new(0, 0, -0.1)))
			end
		end
		-- Donde se cruzan las correas, un tachón de azufre o, desde el grado 2, una llama en píxeles sobre un
		-- disco de carbón con cuatro cristales.
		local core = CFrame.new(0, 0, front - 0.14)
		if grade < 2 then
			make.ball(0.26, SULFUR, SMOOTH, core * CFrame.new(0, 0, 0.04))
		end
		if grade >= 2 then
			make.rod(0.12, 0.8, CHARCOAL, SLATE, core * FACING)
			local heart = pixelFlame(
				make,
				SMALL_FLAME,
				BLUE_FLAME,
				core * CFrame.new(0, -0.33, -0.06) * FACING_FRONT,
				0.11,
				false
			)
			if lit then
				blueFire(heart, 4, 0.4)
			end
			for index = 0, 3 do
				local angle = index * math.pi / 2 + math.pi / 4
				local out = Vector3.new(math.sin(angle), math.cos(angle), 0)
				fireCrystal(
					make,
					core.Position + out * 0.36,
					out + Vector3.new(0, 0, -0.6),
					0.32,
					0.15,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end

		-- Espalda: placa de carbón con el borde de fuego azul y la llamarada sobre su cráter de azufre.
		local plateZ = back + 0.12
		make.block(
			Vector3.new(width * 0.9 + 0.08, height * 0.9 + 0.08, 0.06),
			BLUE_FIRE,
			NEON,
			CFrame.new(0, -height * 0.02, plateZ - 0.03)
		)
		make.block(Vector3.new(width * 0.9, height * 0.9, 0.1), CHARCOAL, SLATE, CFrame.new(0, -height * 0.02, plateZ))
		-- Grado 1: marco de pómez alrededor de la placa (pilares, viga con corona de cristales, escuadras y gotas
		-- azules), tres costillas, el cuello trasero y, delante, remaches en la gorguera y tres placas de abdomen.
		backFrame(make, width * 0.9, height * 0.9, -height * 0.02, plateZ, true, 7, 5)
		for _, y in { 0.12, 0, -0.12 } do
			make.block(
				Vector3.new(width * 0.7, 0.08, 0.06),
				PUMICE_DARK,
				SLATE,
				CFrame.new(0, height * y, plateZ + 0.06)
			)
		end
		make.block(Vector3.new(width * 0.5, 0.3, 0.12), CHARCOAL, SLATE, CFrame.new(0, height * 0.44, back + 0.1))
		make.block(
			Vector3.new(width * 0.54, 0.06, 0.16),
			PUMICE,
			SLATE,
			CFrame.new(0, height * 0.44 + 0.17, back + 0.1)
		)
		for index = 1, 7 do
			make.ball(0.1, SULFUR, SMOOTH, CFrame.new((index - 4) * width * 0.09, height * 0.44 - 0.04, front - 0.03))
		end
		for _, y in { -0.34, -0.41, -0.48 } do
			make.block(Vector3.new(width * 0.22, 0.1, 0.06), PUMICE, SLATE, CFrame.new(0, height * y, front - 0.03))
		end
		-- Grado 2: un cristal de azufre en cada lado alto de la placa, hacia atrás y arriba (lo del pecho no se
		-- ve desde detrás; más hacia fuera, las hombreras los tapaban).
		if grade >= 2 then
			for side = -1, 1, 2 do
				fireCrystal(
					make,
					Vector3.new(side * width * 0.28, height * 0.28, plateZ + 0.06),
					Vector3.new(side * 0.5, 0.8, 0.8),
					0.85,
					0.34,
					SULFUR,
					SULFUR_GLOW
				)
				-- Y uno más grande en la cabeza de cada pilar.
				fireCrystal(
					make,
					Vector3.new(side * width * 0.38, height * 0.43, plateZ + 0.1),
					Vector3.new(side * 0.5, 1, 0.5),
					0.6,
					0.22,
					SULFUR,
					SULFUR_GLOW
				)
			end
			-- Tres gotas de fuego azul bajo el disco del pecho.
			drips(make, core * CFrame.new(0, -0.4, -0.04), { -0.18, 0, 0.18 }, 0.2)
		end
		local footY = -height * 0.3
		if grade >= 3 then
			-- En el grado 4, más ancha que el torso y más alta que la cabeza: es lo que se ve de lejos.
			local flameAt = CFrame.new(0, footY, plateZ + 0.05)
			if lit then
				local big = pixelFlame(make, BIG_FLAME, BLUE_FLAME, flameAt, width * 0.12, false)
				blueFire(big, 12, 0.9)
				smoke(big, 2, Color3.fromRGB(150, 160, 190), 0.9)
			else
				pixelFlame(make, SMALL_FLAME, BLUE_FLAME, flameAt, width * 0.13, false)
			end
			-- Grado 3: cuatro cristales altos a los lados del cráter, remaches en su labio y siete brasas que
			-- suben por delante de la llama (en el 4, tres más, más altas).
			for index, x in { -0.44, -0.34, 0.34, 0.44 } do
				fireCrystal(
					make,
					Vector3.new(x * width, footY + height * 0.06, plateZ + 0.34),
					Vector3.new(x * 2.4, 1, 0.5),
					if index == 1 or index == 4 then 0.9 else 0.7,
					0.24,
					SULFUR,
					SULFUR_GLOW
				)
			end
			for index = 1, 7 do
				make.ball(
					0.12,
					SULFUR,
					SMOOTH,
					CFrame.new((index - 4) * width * 0.11, footY - height * 0.04, plateZ + 0.37)
				)
			end
			local sparks = {}
			for index = 1, 7 do
				sparks[index] = Vector3.new(
					(index - 4) * width * 0.16,
					footY + height * (0.7 + 0.12 * ((index * 3) % 5)),
					plateZ + 0.6
				)
			end
			motes(make, sparks, 0.1)
			if lit then
				local high = {}
				for index = 1, 3 do
					high[index] =
						Vector3.new((index - 2) * width * 0.3, footY + height * (1.35 + 0.1 * index), plateZ + 0.6)
				end
				motes(make, high, 0.1)
			end
			-- Cráter: labio de carbón y pómez y cinco cristales de azufre delante del pie de la llama.
			make.block(
				Vector3.new(width * 0.86, height * 0.16, 0.3),
				PUMICE_DARK,
				SLATE,
				CFrame.new(0, footY - height * 0.04, plateZ + 0.2)
			)
			make.block(
				Vector3.new(width * 0.9, 0.08, 0.34),
				CHARCOAL,
				SLATE,
				CFrame.new(0, footY + height * 0.04, plateZ + 0.2)
			)
			for index, x in { -0.36, -0.18, 0, 0.18, 0.36 } do
				fireCrystal(
					make,
					Vector3.new(x * width, footY + height * 0.06, plateZ + 0.34),
					Vector3.new(x * 1.6, 1, 0.5),
					if index == 3 then 0.66 else 0.56 - math.abs(x) * 0.3,
					0.28,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end

		seasonBelt(body, grade)
		seasonLimbs(body, grade, PUMICE, SLATE)
	end

	OUTFITS.BlueFireGuardianOutfit = blueFireGuardian

	-- Traje de temporada del cazador, Acechador del Fuego Azul. Delante: jubón de cuero de carbón, la
	-- correa del carcaj de pómez con tachones de azufre, esclavina de pómez con la raya de fuego azul,
	-- cinturón con zurrón y un cuchillo de azufre. Detrás: capa de pómez oscura con el bajo de carbón y el
	-- carcaj de pómez con aros de carbón y flechas de plumas celestes. Por grados: 0, todo eso; 1, las
	-- hombreras; 2, collar de tres puntas de flecha de azufre con un broche de fuego azul, la capucha
	-- bajada forrada de celeste y dos cristales de azufre en el carcaj; 3, tres zarpazos de fuego azul en la
	-- capa, aros de fuego azul en el carcaj y una llama pequeña entre las flechas (arden); 4, la llama de las
	-- flechas más grande, el bajo de la capa en llamas y el fuego de partículas, con su luz. Además: flecos de
	-- carbón y remaches en la capa desde el 1; flecos de pómez en la esclavina y puntas en el carcaj desde el 2;
	-- el bajo de la capa arde ya en el 3.
	local function blueFireStalker(body: Body, grade: number)
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local lit = grade >= 4
		local FACING_FRONT = CFrame.Angles(0, math.pi, 0)
		make.block(
			Vector3.new(width + 0.12, height * 0.92, depth + 0.14),
			CHARCOAL,
			LEATHER_MATERIAL,
			CFrame.new(0, -height * 0.02, 0)
		)
		quiverStrap(make, front - 0.04, 0.16, PUMICE_DARK, LEATHER_MATERIAL)
		local strapFrom = Vector3.new(width * 0.3, height / 2 - 0.02, front - 0.04)
		local strapTo = Vector3.new(-width * 0.4, -height / 2 + 0.12, front - 0.04)
		for _, t in { 0.25, 0.5, 0.75 } do
			make.ball(0.12, SULFUR, SMOOTH, CFrame.new(strapFrom:Lerp(strapTo, t) + Vector3.new(0, 0, -0.08)))
		end
		-- Esclavina de pómez sobre los hombros con la raya de fuego azul delante.
		make.block(Vector3.new(width + 0.36, 0.3, depth + 0.36), PUMICE, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.04))
		make.block(
			Vector3.new(width + 0.38, 0.05, 0.08),
			BLUE_FIRE,
			NEON,
			CFrame.new(0, height / 2 - 0.2, -depth / 2 - 0.15)
		)
		if grade >= 2 then
			-- Collar: cordón en V con tres puntas de flecha de azufre y un broche con una llama azul.
			local neckLeft = Vector3.new(-width * 0.2, height / 2 - 0.12, front - 0.06)
			local neckRight = Vector3.new(width * 0.2, height / 2 - 0.12, front - 0.06)
			local bottom = Vector3.new(0, height * 0.14, front - 0.1)
			strap(make, neckLeft, bottom, 0.04, CHARCOAL, FABRIC)
			strap(make, bottom, neckRight, 0.04, CHARCOAL, FABRIC)
			for index, spot in { neckLeft:Lerp(bottom, 0.7), bottom, neckRight:Lerp(bottom, 0.7) } do
				fireCrystal(
					make,
					spot + Vector3.new(0, -0.02, -0.02),
					Vector3.new((index - 2) * 0.2, -1, -0.15),
					0.28,
					0.13,
					SULFUR,
					SULFUR_GLOW
				)
			end
			local brooch = CFrame.new(-width * 0.3, height / 2 - 0.2, front - 0.14)
			make.rod(0.06, 0.4, CHARCOAL, SLATE, brooch * FACING)
			pixelFlame(make, SMALL_FLAME, BLUE_FLAME, brooch * CFrame.new(0, -0.17, -0.04) * FACING_FRONT, 0.06, false)
		end

		-- Espalda: capa de pómez oscura con el bajo de carbón y la raya azul.
		local capeHeight = height * 1.08
		local capeY = height / 2 - capeHeight / 2 - 0.02
		local capeZ = back + 0.16
		make.block(Vector3.new(width * 1.02, capeHeight, 0.12), PUMICE_DARK, FABRIC, CFrame.new(0, capeY, capeZ))
		local capeBottom = capeY - capeHeight / 2
		make.block(
			Vector3.new(width * 1.04, 0.16, 0.14),
			CHARCOAL,
			FABRIC,
			CFrame.new(0, capeBottom + 0.08, capeZ + 0.01)
		)
		make.block(
			Vector3.new(width * 1.04, 0.05, 0.16),
			BLUE_FIRE,
			NEON,
			CFrame.new(0, capeBottom + 0.18, capeZ + 0.01)
		)
		if grade >= 3 then
			-- Tres zarpazos de fuego azul en diagonal, en la mitad de la capa que no tapa el carcaj.
			for index = -1, 1 do
				local x = -width * 0.24 + index * 0.15
				strap(
					make,
					Vector3.new(x - 0.14, height * 0.06, capeZ + 0.07),
					Vector3.new(x + 0.18, -height * 0.46, capeZ + 0.07),
					0.11,
					BLUE_FIRE_MID,
					NEON
				)
			end
		end
		-- Grado 1: nueve flecos de carbón que cuelgan del bajo de la capa y tres remaches en su cuello.
		for index = 0, 8 do
			make.fang(
				if index % 2 == 0 then 0.34 else 0.26,
				0.18,
				CHARCOAL,
				FABRIC,
				CFrame.new(-width * 0.46 + index * width * 0.115 + 0.09, capeBottom + 0.02, capeZ + 0.02)
					* CFrame.Angles(0, 0, math.pi)
			)
		end
		for _, x in { -0.32, -0.4, -0.47 } do
			make.ball(0.12, SULFUR, SMOOTH, CFrame.new(x * width, capeY + capeHeight / 2 - 0.1, capeZ + 0.09))
		end
		if grade >= 3 then
			-- El bajo de la capa arde: cuatro llamas pequeñas (con fuego de verdad en el grado 4).
			for index = 0, 3 do
				local x = -width * 0.39 + index * width * 0.26
				local hem = pixelFlame(
					make,
					SMALL_FLAME,
					BLUE_FLAME,
					CFrame.new(x, capeBottom + 0.12, capeZ + 0.08),
					0.1,
					index % 2 == 1
				)
				if lit and index == 1 then
					blueFire(hem, 4, 0.4)
				end
			end
		end
		if grade >= 2 then
			loweredHood(make, CHARCOAL, BLUE_FIRE_MID, FABRIC)
		end
		local quiverLength = 1.9
		local quiverAt = backQuiver(make, {
			length = quiverLength,
			radius = 0.27,
			color = PUMICE,
			material = SLATE,
			rim = CHARCOAL,
			rimMaterial = SLATE,
			arrows = 7,
			feathers = { BLUE_FIRE_MID, PUMICE },
		}, 0.32)
		make.rod(0.1, 0.6, CHARCOAL, SLATE, quiverAt * UPRIGHT)
		if grade >= 2 then
			-- Grado 2: flecos de pómez bajo la esclavina y una punta de azufre en cada lado del fondo del carcaj.
			for _, x in { -0.45, -0.3, -0.15, 0, 0.45 } do
				make.fang(
					0.22,
					0.14,
					PUMICE,
					FABRIC,
					CFrame.new(x * width + 0.07, height / 2 - 0.21, -(depth / 2 + 0.12)) * CFrame.Angles(0, 0, math.pi)
				)
			end
			for side = -1, 1, 2 do
				fireCrystal(
					make,
					(quiverAt * CFrame.new(side * 0.12, -quiverLength / 2 + 0.02, 0.05)).Position,
					quiverAt:VectorToWorldSpace(Vector3.new(side * 0.5, -1, 0.2)),
					0.32,
					0.14,
					SULFUR,
					SULFUR_GLOW
				)
			end
			make.ball(0.14, SULFUR, SMOOTH, quiverAt * CFrame.new(0, -quiverLength / 2 - 0.02, 0.0))
			for side = -1, 1, 2 do
				fireCrystal(
					make,
					(quiverAt * CFrame.new(side * 0.22, -0.25, 0.12)).Position,
					quiverAt:VectorToWorldSpace(Vector3.new(side * 0.8, -0.6, 0.4)),
					0.38,
					0.17,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end
		if grade >= 3 then
			for _, y in { 0.45, -0.45 } do
				make.rod(0.05, 0.6, BLUE_FIRE, NEON, quiverAt * CFrame.new(0, y, 0) * UPRIGHT)
			end
			-- Las flechas arden: una llama entre las plumas y, en el grado 4, la llamarada grande que sale del
			-- carcaj por encima del hombro.
			local mouth = quiverAt * CFrame.new(0, quiverLength / 2 + 0.1, 0.05)
			if lit then
				blueFire(pixelFlame(make, BIG_FLAME, BLUE_FLAME, mouth, 0.14, false), 10, 0.8)
			else
				pixelFlame(make, SMALL_FLAME, BLUE_FLAME, mouth, 0.13, false)
			end
		end

		-- Cinturón con zurrón de pómez y un cuchillo de azufre.
		local beltFront = seasonBelt(body, grade)
		local waist = body.waist
		local hipWidth = waist.size.X
		local pouch = CFrame.new(hipWidth * 0.32, -0.12, beltFront - 0.06)
		waist.block(Vector3.new(0.36, 0.32, 0.14), CHARCOAL, LEATHER_MATERIAL, pouch)
		waist.block(Vector3.new(0.4, 0.13, 0.18), PUMICE, FABRIC, pouch * CFrame.new(0, 0.12, -0.01))
		local knife = CFrame.new(-hipWidth * 0.36, -0.05, beltFront - 0.04) * CFrame.Angles(0, 0, 0.25)
		waist.block(Vector3.new(0.1, 0.24, 0.1), CHARCOAL, LEATHER_MATERIAL, knife)
		fireCrystal(
			waist,
			(knife * CFrame.new(0, -0.12, 0)).Position,
			knife:VectorToWorldSpace(Vector3.new(0, -1, -0.05)),
			0.4,
			0.12,
			SULFUR,
			SULFUR_GLOW
		)
		seasonLimbs(body, grade, PUMICE_DARK, FABRIC)
	end

	-- Traje de temporada del mago, Invocador del Fuego Azul. Delante: túnica de carbón con una pechera de
	-- pómez ribeteada de fuego azul y faja de carbón. Detrás: un panel de pómez oscura con un disco de piedra
	-- dentro de un aro de carbón. Por grados: 0, todo eso; 1, las hombreras; 2, una runa de fuego azul en el
	-- pecho (aro con una llama dentro), un cuello alto de cristales de azufre que se ve también por detrás y
	-- dos talismanes de pómez colgando bajo el disco; 3, un aro de fuego azul alrededor del disco con seis
	-- rayos de azufre y una llama en el centro; 4, en vez de esa llama, la llamarada grande que asoma por
	-- encima de los hombros, una corona de cinco cristales de azufre y el fuego de partículas con su luz.
	local function blueFireInvoker(body: Body, grade: number)
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.09)
		local back = depth / 2
		local lit = grade >= 4
		local FACING_FRONT = CFrame.Angles(0, math.pi, 0)
		make.block(
			Vector3.new(width + 0.12, height * 0.96, depth + 0.16),
			CHARCOAL,
			FABRIC,
			CFrame.new(0, -height * 0.02, 0)
		)
		make.block(
			Vector3.new(width * 0.5, height * 0.86, 0.08),
			PUMICE,
			FABRIC,
			CFrame.new(0, -height * 0.04, front - 0.02)
		)
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.05, height * 0.86, 0.05),
				BLUE_FIRE,
				NEON,
				CFrame.new(side * width * 0.26, -height * 0.04, front - 0.05)
			)
		end
		if grade >= 2 then
			-- Runa: aro de fuego azul con una llama dentro.
			local runeAt = CFrame.new(0, height * 0.12, front - 0.08)
			hoop(make, runeAt, width * 0.17, 10, 0.05, BLUE_FIRE, NEON)
			pixelFlame(make, SMALL_FLAME, BLUE_FLAME, runeAt * CFrame.new(0, -0.2, -0.02) * FACING_FRONT, 0.07, false)
			-- Cuello alto de cristales de azufre, de un hombro a otro por detrás de la nuca.
			for index = 0, 4 do
				local angle = math.rad(-80 + index * 40)
				fireCrystal(
					make,
					Vector3.new(math.sin(angle) * width * 0.4, height / 2 - 0.05, math.cos(angle) * depth * 0.45 + 0.05),
					Vector3.new(math.sin(angle) * 0.4, 1, math.cos(angle) * 0.4 + 0.1),
					if index == 2 then 0.75 else 0.6,
					0.28,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end

		-- Espalda: panel de pómez oscura con un disco de piedra en un aro de carbón.
		local ringAt = CFrame.new(0, height * 0.12, back + 0.2)
		make.block(
			Vector3.new(width * 0.96, height * 1.02, 0.12),
			PUMICE_DARK,
			FABRIC,
			CFrame.new(0, -height * 0.06, back + 0.12)
		)
		make.rod(0.08, width * 0.62, PUMICE, SLATE, ringAt * CFrame.new(0, 0, -0.02) * FACING)
		hoop(make, ringAt * CFrame.new(0, 0, 0.02), width * 0.3, 12, 0.1, CHARCOAL, SLATE)
		-- Grado 1: viga y escuadras de pómez en el panel con cinco gotas azules, borlas, ocho brasas que giran
		-- dentro del aro y, delante, gotas en el bajo de la pechera, seis botones y diez muescas de fuego azul.
		backFrame(make, width * 0.96, height * 1.02, -height * 0.06, back + 0.12, false, 5, 0)
		for side = -1, 1, 2 do
			local tassel = Vector3.new(side * width * 0.44, height * 0.45 - 0.1, back + 0.2)
			strap(make, tassel, tassel - Vector3.new(0, 0.7, 0), 0.04, CHARCOAL, FABRIC)
			make.ball(0.12, SULFUR, SMOOTH, CFrame.new(tassel - Vector3.new(0, 0.74, 0)))
			for step = 0, 4 do
				make.block(
					Vector3.new(0.1, 0.04, 0.04),
					BLUE_FIRE,
					NEON,
					CFrame.new(side * (width * 0.26 + 0.1), height * (0.3 - 0.15 * step), front - 0.01)
				)
			end
		end
		local orbit = {}
		for index = 0, 7 do
			local angle = index / 8 * math.pi * 2
			orbit[index + 1] = (ringAt * CFrame.new(
				math.sin(angle) * width * 0.27,
				math.cos(angle) * width * 0.27,
				0.06
			)).Position
		end
		motes(make, orbit, 0.09)
		drips(
			make,
			CFrame.new(0, -height * 0.47, front - 0.02),
			{ -0.2 * width, -0.1 * width, 0, 0.1 * width, 0.2 * width },
			0.28
		)
		for index = 0, 5 do
			make.ball(0.09, SULFUR, SMOOTH, CFrame.new(0, -height * (0.1 + 0.05 * index), front - 0.08))
		end
		if grade >= 2 then
			-- Tres remaches de azufre en el aro de la runa del pecho.
			for index = 0, 2 do
				local angle = index / 3 * math.pi * 2
				make.ball(
					0.1,
					SULFUR,
					SMOOTH,
					CFrame.new(
						math.sin(angle) * width * 0.17,
						height * 0.12 + math.cos(angle) * width * 0.17,
						front - 0.11
					)
				)
			end
		end
		if grade >= 3 then
			-- Cuatro cristales más en las esquinas de arriba del panel, dos a cada lado.
			for side = -1, 1, 2 do
				fireCrystal(
					make,
					Vector3.new(side * width * 0.46, height * 0.44, back + 0.17),
					Vector3.new(side, 0.6, 0.5),
					0.7,
					0.22,
					SULFUR,
					SULFUR_GLOW
				)
				fireCrystal(
					make,
					Vector3.new(side * width * 0.46, height * 0.4, back + 0.3),
					Vector3.new(side * 0.5, 1, 0.8),
					0.55,
					0.2,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end
		if grade >= 2 then
			-- Talismanes: dos placas de pómez con una runa azul que cuelgan bajo el disco.
			for side = -1, 1, 2 do
				local from = (ringAt * CFrame.new(side * width * 0.2, -width * 0.34, 0.04)).Position
				local to = from + Vector3.new(side * 0.04, -height * 0.18, 0.02)
				strap(make, from, to, 0.03, CHARCOAL, FABRIC)
				make.block(Vector3.new(0.24, 0.36, 0.06), PUMICE, SLATE, CFrame.new(to.X, to.Y - 0.18, to.Z))
				make.block(Vector3.new(0.06, 0.22, 0.03), BLUE_FIRE, NEON, CFrame.new(to.X, to.Y - 0.18, to.Z + 0.04))
			end
		end
		if grade >= 3 then
			hoop(make, ringAt * CFrame.new(0, 0, 0.04), width * 0.38, 14, 0.1, BLUE_FIRE, NEON)
			for index = 0, 5 do
				local angle = index * math.pi / 3 + math.pi / 6
				local out = Vector3.new(math.sin(angle), math.cos(angle), 0.12)
				fireCrystal(
					make,
					(ringAt * CFrame.new(out.X * width * 0.42, out.Y * width * 0.42, 0)).Position,
					out,
					0.42,
					0.2,
					SULFUR,
					SULFUR_GLOW
				)
			end
			local flameAt = ringAt * CFrame.new(0, -width * 0.24, 0.06)
			if lit then
				blueFire(pixelFlame(make, BIG_FLAME, BLUE_FLAME, flameAt, width * 0.1, false), 10, 0.8)
			else
				pixelFlame(make, SMALL_FLAME, BLUE_FLAME, flameAt, width * 0.09, false)
			end
		end
		if lit then
			-- Corona de cristales de azufre que asoma por encima de los hombros.
			for index, x in { -0.4, -0.2, 0, 0.2, 0.4 } do
				fireCrystal(
					make,
					Vector3.new(x * width, height * 0.44, back + 0.24),
					Vector3.new(x * 1.1, 1, 0.35),
					if index == 3 then 1.05 elseif index % 2 == 0 then 0.8 else 0.6,
					if index == 3 then 0.32 else 0.26,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end

		seasonBelt(body, grade)
		seasonLimbs(body, grade, CHARCOAL, FABRIC, true)
	end

	-- Traje de temporada del médico, Sanador del Fuego Azul. Delante: túnica de lino bajo un manto de pómez
	-- con la raya de fuego azul, un peto de pómez y la bandolera de carbón con tres frascos. Detrás: capa de
	-- pómez oscura, bastidor de madera y una mochila de pómez con una correa de carbón. Por grados: 0, todo
	-- eso; 1, las hombreras; 2, la cruz verde que brilla en el peto (el verde de las curaciones), los frascos
	-- que brillan y dos frascos más a los lados de la mochila; 3, encima de la mochila un incensario de
	-- carbón con borde de pómez y cadenas, con una llama azul y humo; 4, la llamarada grande que sale del
	-- incensario y el fuego de partículas con su luz.
	local function blueFireHealer(body: Body, grade: number)
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local lit = grade >= 4
		local healing = grade >= 2
		make.block(
			Vector3.new(width + 0.12, height * 0.94, depth + 0.16),
			LINEN,
			FABRIC,
			CFrame.new(0, -height * 0.02, 0)
		)
		make.block(Vector3.new(width + 0.4, 0.34, depth + 0.4), PUMICE, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.04))
		make.block(
			Vector3.new(width + 0.42, 0.06, depth + 0.42),
			BLUE_FIRE,
			NEON,
			CFrame.new(0, height / 2 - 0.24, 0.04)
		)
		-- Peto de pómez arriba a la izquierda, fuera del camino de la bandolera.
		local plastron = CFrame.new(-width * 0.27, height * 0.12, front - 0.04)
		make.block(Vector3.new(width * 0.34, height * 0.36, 0.08), PUMICE, SLATE, plastron)
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.05, height * 0.36, 0.06),
				CHARCOAL,
				SLATE,
				plastron * CFrame.new(side * width * 0.17, 0, -0.02)
			)
		end
		if healing then
			local cross = make.block(
				Vector3.new(width * 0.07, height * 0.26, 0.05),
				HEAL_GLOW,
				NEON,
				plastron * CFrame.new(0, 0, -0.06)
			)
			make.block(
				Vector3.new(width * 0.22, height * 0.08, 0.05),
				HEAL_GLOW,
				NEON,
				plastron * CFrame.new(0, 0.04, -0.06)
			)
			fireLight(cross, HEAL_GLOW)
		end
		local from = Vector3.new(width * 0.3, height / 2 - 0.02, front - 0.08)
		local to = Vector3.new(-width * 0.4, -height / 2 + 0.12, front - 0.08)
		strap(make, from, to, 0.16, CHARCOAL, LEATHER_MATERIAL)
		for _, t in { 0.22, 0.42, 0.62 } do
			local at = from:Lerp(to, t)
			flask(make, CFrame.new(at.X, at.Y - 0.32, at.Z - 0.1), 0.22, healing)
		end
		-- Grado 1: flecos de pómez bajo el manto (menos donde cruza la bandolera) y tres remaches de azufre.
		for _, x in { -0.45, -0.3, -0.15, 0, 0.45 } do
			make.fang(
				0.2,
				0.14,
				PUMICE,
				FABRIC,
				CFrame.new(x * width + 0.07, height / 2 - 0.27, -(depth / 2 + 0.14)) * CFrame.Angles(0, 0, math.pi)
			)
		end
		for _, x in { -0.42, -0.21, 0 } do
			make.ball(0.1, SULFUR, SMOOTH, CFrame.new(x * width, height / 2 - 0.06, -(depth / 2 + 0.19)))
		end
		if healing then
			-- Grado 2: cuatro remaches en las esquinas del peto, cuatro motas de curación a su alrededor y tres
			-- cristales de azufre que asoman por detrás del manto.
			for sy = -1, 1, 2 do
				for sx = -1, 1, 2 do
					make.ball(0.09, SULFUR, SMOOTH, plastron * CFrame.new(sx * width * 0.15, sy * height * 0.16, -0.06))
					make.ball(0.07, HEAL_GLOW, NEON, plastron * CFrame.new(sx * width * 0.23, sy * height * 0.1, -0.1))
				end
			end
			for _, x in { -0.2, 0, 0.2 } do
				fireCrystal(
					make,
					Vector3.new(x * width, height / 2 + 0.08, depth / 2 + 0.1),
					Vector3.new(x * 1.5, 1, 0.4),
					0.5,
					0.2,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end

		-- Espalda: capa de pómez oscura, bastidor de madera y la mochila de pómez.
		local capeHeight = height * 1.06
		local capeY = height / 2 - capeHeight / 2 - 0.02
		make.block(Vector3.new(width * 1.02, capeHeight, 0.12), PUMICE_DARK, FABRIC, CFrame.new(0, capeY, back + 0.16))
		make.block(
			Vector3.new(width * 1.03, 0.06, 0.14),
			BLUE_FIRE,
			NEON,
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
		make.block(Vector3.new(width * 0.72, height * 0.62, 0.46), PUMICE, SLATE, pack)
		make.block(Vector3.new(width * 0.74, 0.12, 0.48), CHARCOAL, SLATE, pack * CFrame.new(0, height * 0.1, 0))
		for _, x in { -0.2, 0, 0.2 } do
			make.ball(0.16, SULFUR, SMOOTH, pack * CFrame.new(x * width, height * 0.1, 0.25))
		end
		-- Grado 1: flecos de carbón en el bajo de la capa, dos correas con hebilla en la mochila, remates y
		-- remaches en el bastidor, dos rayas de fuego azul en los bordes de la capa y un manojo de hierbas.
		local capeBottom = capeY - capeHeight / 2
		for index = 1, 7 do
			make.fang(
				if index % 2 == 0 then 0.24 else 0.32,
				0.16,
				CHARCOAL,
				FABRIC,
				CFrame.new((index - 4) * width * 0.15 + 0.08, capeBottom + 0.01, back + 0.16)
					* CFrame.Angles(0, 0, math.pi)
			)
		end
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.12, height * 0.62, 0.04),
				CHARCOAL,
				LEATHER_MATERIAL,
				pack * CFrame.new(side * width * 0.3, 0, 0.25)
			)
			make.ball(0.12, SULFUR, SMOOTH, pack * CFrame.new(side * width * 0.3, -height * 0.15, 0.28))
			make.ball(0.18, SULFUR, SMOOTH, CFrame.new(side * width * 0.38, height * 0.59 + 0.07, back + 0.3))
			for _, up in { 0.29, -0.21 } do
				make.ball(0.12, SULFUR, SMOOTH, CFrame.new(side * width * 0.38, height * up, back + 0.37))
			end
			make.block(
				Vector3.new(0.04, height * 0.9, 0.03),
				BLUE_FIRE,
				NEON,
				CFrame.new(side * width * 0.46, capeY, back + 0.225)
			)
		end
		for _, x in { -0.31, -0.24, -0.17, 0.27, 0.31 } do
			make.fang(
				0.3,
				0.12,
				LEAF,
				FABRIC,
				CFrame.new(x * width, height * 0.44 - 0.05, back + 0.3) * CFrame.Angles(0, 0, math.pi)
			)
		end
		if healing then
			for side = -1, 1, 2 do
				flask(make, pack * CFrame.new(side * (width * 0.36 + 0.24), -height * 0.2, 0.04), 0.42, true)
			end
			-- Grado 2: tres frascos más que cuelgan con un cordón del travesaño de abajo del bastidor y un
			-- remache en cada extremo de ese travesaño.
			for _, x in { -0.25, 0, 0.25 } do
				strap(
					make,
					Vector3.new(x * width, -height * 0.4 - 0.05, back + 0.3),
					Vector3.new(x * width, -height * 0.4 - 0.2, back + 0.3),
					0.03,
					CHARCOAL,
					LEATHER_MATERIAL
				)
				flask(make, CFrame.new(x * width, -height * 0.4 - 0.5, back + 0.3), 0.22, true)
			end
			for side = -1, 1, 2 do
				make.ball(0.1, SULFUR, SMOOTH, CFrame.new(side * width * 0.43, -height * 0.4, back + 0.3))
			end
		end
		if grade >= 3 then
			-- Incensario: cuenco de carbón con borde de pómez sobre la mochila, colgado de tres cadenas.
			local censer = pack * CFrame.new(0, height * 0.31 + 0.18, 0.02)
			make.block(Vector3.new(width * 0.56, 0.32, 0.42), CHARCOAL, SLATE, censer)
			make.block(Vector3.new(width * 0.62, 0.08, 0.48), PUMICE, SLATE, censer * CFrame.new(0, 0.18, 0))
			for _, x in { -0.2, 0, 0.2 } do
				make.ball(0.1, SULFUR, SMOOTH, censer * CFrame.new(x * width, 0, 0.19))
			end
			for side = -1, 1, 2 do
				strap(
					make,
					(censer * CFrame.new(side * width * 0.2, 0.15, 0)).Position,
					(censer * CFrame.new(side * width * 0.06, 0.9, 0)).Position,
					0.04,
					CHARCOAL,
					SLATE
				)
			end
			local flameAt = censer * CFrame.new(0, 0.2, 0.04)
			local flame = if lit
				then pixelFlame(make, BIG_FLAME, BLUE_FLAME, flameAt, width * 0.1, false)
				else pixelFlame(make, SMALL_FLAME, BLUE_FLAME, flameAt, 0.16, false)
			smoke(flame, 2, Color3.fromRGB(150, 160, 190), 0.7)
			if lit then
				blueFire(flame, 10, 0.7)
			end
			-- Pedestal con cuatro patas y dos asas, una cadena central con su anillo, cuatro brasas en la boca,
			-- tres cristales de azufre en el borde y cuatro chispas que suben (cinco más en el grado 4).
			make.block(Vector3.new(width * 0.4, 0.12, 0.36), PUMICE_DARK, SLATE, censer * CFrame.new(0, -0.2, 0))
			for sz = -1, 1, 2 do
				for sx = -1, 1, 2 do
					make.ball(0.12, SULFUR, SMOOTH, censer * CFrame.new(sx * width * 0.22, -0.15, sz * 0.15))
				end
				make.block(
					Vector3.new(0.1, 0.18, 0.1),
					CHARCOAL,
					SLATE,
					censer * CFrame.new(sz * (width * 0.28 + 0.05), 0, 0)
				)
			end
			local top = censer * CFrame.new(0, 0.95, 0)
			strap(
				make,
				(censer * CFrame.new(0, 0.15, 0)).Position,
				(censer * CFrame.new(0, 0.9, 0)).Position,
				0.04,
				CHARCOAL,
				SLATE
			)
			hoop(make, top, 0.12, 6, 0.04, CHARCOAL, SLATE)
			for _, x in { -0.15, -0.05, 0.05, 0.15 } do
				make.ball(0.1, BLUE_FIRE_PALE, NEON, censer * CFrame.new(x * width, 0.2, -0.08))
			end
			for _, x in { -0.22, 0, 0.22 } do
				fireCrystal(
					make,
					(censer * CFrame.new(x * width, 0.2, 0.15)).Position,
					censer:VectorToWorldSpace(Vector3.new(x * 3, 1, 0.6)),
					0.4,
					0.16,
					SULFUR,
					SULFUR_GLOW
				)
			end
			local sparks = {}
			for index, x in { -0.18, -0.07, 0.07, 0.18 } do
				sparks[index] = (censer * CFrame.new(x * width, 1.2 + 0.1 * (index % 2), 0.1)).Position
			end
			motes(make, sparks, 0.08)
			if lit then
				local high = {}
				for index = 1, 5 do
					high[index] = (censer * CFrame.new((index - 3) * width * 0.1, 1.7 + 0.12 * (index % 3), 0.12)).Position
				end
				motes(make, high, 0.08)
			end
		end

		-- Cinturón, una venda enrollada y dos bolsitas de hierbas.
		local beltFront = seasonBelt(body, grade)
		local waist = body.waist
		local hipWidth = waist.size.X
		waist.rod(0.24, 0.22, PAINT_WHITE, FABRIC, CFrame.new(hipWidth * 0.32, -0.06, beltFront - 0.1) * UPRIGHT)
		herbPouch(waist, CFrame.new(-hipWidth * 0.34, -0.12, beltFront - 0.08), LEAF)
		seasonLimbs(body, grade, PUMICE_DARK, FABRIC)
	end

	OUTFITS.BlueFireStalkerOutfit = blueFireStalker
	OUTFITS.BlueFireInvokerOutfit = blueFireInvoker
	OUTFITS.BlueFireHealerOutfit = blueFireHealer
end

-- Constructores por armadura y rol (el que falta usa el de DEFAULT_ROLE).
local BUILDERS: { [string]: { [string]: (body: Body) -> () } } = {
	FurVest = { Guerrero = furVest, Cazador = trackerCape, Mago = amuletMantle, Medico = healerBandolier },
	BoneArmor = { Guerrero = boneArmor, Cazador = hunterLeather, Mago = runeTunic, Medico = healerPlastron },
	SilverArmor = { Guerrero = silverArmor, Cazador = silverHunter, Mago = crystalMantle, Medico = silverHealer },
	VolcanicArmor = { Guerrero = volcanicArmor, Cazador = emberCloak, Mago = lavaRobe, Medico = sulfurMantle },
}

-- Las armaduras por grado (sin ninguna, 0): los trajes míticos ganan piezas con él.
ArmorModels.BY_GRADE = { "FurVest", "BoneArmor", "SilverArmor", "VolcanicArmor" }
ArmorModels.MAX_GRADE = #ArmorModels.BY_GRADE
local ARMOR_GRADE: { [string]: number } = {}
for grade, armorId in ArmorModels.BY_GRADE do
	ARMOR_GRADE[armorId] = grade
end

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
	-- Por miembro (Part0 de las soldaduras), antes de ponerlo en el personaje.
	VoxelMerge.mergeWelded(model)
	model.Parent = character
	return model
end

-- Viste al personaje de "player" con lo suyo: el traje equipado de su rol ("Outfit") o su armadura
-- ("Armor", la fabricada, o "ArmorLook", la que luce en el Lobby y en Dunas).
function ArmorModels.dress(player: Player, character: Model?): Model?
	character = character or player.Character
	if not character then
		return nil
	end
	local armorId = player:GetAttribute("Armor") or player:GetAttribute("ArmorLook")
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
