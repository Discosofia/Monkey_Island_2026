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

-- Relativos a este módulo (no al Shared real) para que el volcado de mallas pueda usar un clon con su propia Config.
local Armor = require(script.Parent.Data.Armor)
local VoxelMerge = require(script.Parent.VoxelMerge)
local ArmorMeshes = require(script.Parent.Data.ArmorMeshes)

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
-- Los ayudantes compartidos (leaf, quiver, quiverStrap, blockLeafFan, leafStar, blockHood, silverCape) tienen dos versiones: la
-- de siempre (óvalos, cilindros y bloques girados, pocas piezas) y la de escalones sin giro, que entra en la malla pero cuesta
-- más piezas. "wear" pone `on` a true solo si lo que viste tiene malla en Data/ArmorMeshes o si se está diseñando (boxesOnly).
local STEPS = { on = false }

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
-- Con "scale" (lo que se viste lleva malla), "size" es el de referencia del volcado y cada pieza se escala por eje como la
-- malla (posición y tamaño por los ejes del ancla): así las piezas sueltas (neón, cristal) acompañan a la malla en un
-- avatar de otras proporciones, en vez de quedarse con las medidas del diseño.
local function builder(model: Model, anchor: BasePart?, offset: CFrame, size: Vector3, scale: Vector3?): Builder
	local function place(piece: BasePart, at: CFrame): BasePart
		piece.Name = "Armor"
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true
		piece.CastShadow = false
		if anchor and scale then
			local rotation = at - at.Position
			local right, up, back = rotation.RightVector, rotation.UpVector, -rotation.LookVector
			local fx, fy, fz = (scale * right).Magnitude, (scale * up).Magnitude, (scale * back).Magnitude
			local current = piece.Size
			if piece:IsA("Part") and (piece :: Part).Shape == Enum.PartType.Ball then
				piece.Size = current * (fx * fy * fz) ^ (1 / 3)
			else
				piece.Size = Vector3.new(current.X * fx, current.Y * fy, current.Z * fz)
			end
			at = CFrame.new(at.Position * scale) * rotation
		end
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
	-- Con STEPS.on (la armadura tiene malla), lo que no es de neón ni de cristal y va alineado con los ejes del ancla se
	-- hace de bloques: la bola, el cilindro y el óvalo, en un bloque; el colmillo, en tres escalones. Así entra en la malla.
	local function aligned(at: CFrame): boolean
		if not STEPS.on then
			return false
		end
		local _, _, _, r11, r12, r13, r21, r22, r23, r31, r32, r33 = at:GetComponents()
		for _, value in { r11, r12, r13, r21, r22, r23, r31, r32, r33 } do
			local abs = math.abs(value)
			if abs > 0.01 and abs < 0.9999 then
				return false
			end
		end
		return true
	end
	local function plain(material: Enum.Material): boolean
		return material ~= Enum.Material.Neon and material ~= Enum.Material.Glass
	end
	return {
		size = size,
		block = function(blockSize, color, material, at)
			return place(part(blockSize, color, material), at)
		end,
		rod = function(length, diameter, color, material, at)
			if plain(material) and aligned(at) then
				return place(part(Vector3.new(length, diameter, diameter), color, material), at)
			end
			return place(part(Vector3.new(length, diameter, diameter), color, material, Enum.PartType.Cylinder), at)
		end,
		ball = function(diameter, color, material, at)
			if plain(material) and aligned(at) then
				return place(part(Vector3.one * diameter, color, material), at)
			end
			return place(part(Vector3.one * diameter, color, material, Enum.PartType.Ball), at)
		end,
		oval = function(ovalSize, color, material, at)
			if plain(material) and aligned(at) then
				return place(part(ovalSize, color, material), at)
			end
			local piece = part(ovalSize, color, material)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = piece
			return place(piece, at)
		end,
		-- Colmillo, garra o mechón en punta: pirámide (CornerWedgePart) con la base en "at" y la punta
		-- "length" studs hacia su +Y. La punta queda sobre una esquina de la base, así se curva un poco.
		fang = function(length, width, color, material, at)
			if plain(material) and aligned(at) then
				local first
				for step = 0, 2 do
					local w = width * (1 - 0.3 * step)
					local block = place(
						part(Vector3.new(w, length / 3, w), color, material),
						at * CFrame.new(width / 2, length / 3 * (step + 0.5), -width / 2)
					)
					first = first or block
				end
				return first
			end
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
	r6Size: Vector3?,
	refs: { [string]: Vector3 }?
): Builder
	local part = character:FindFirstChild(r15)
	if part and part:IsA("BasePart") then
		-- Con malla, se diseña contra el tamaño de referencia del volcado y se escala al de este avatar.
		local ref = if refs then refs[r15] else nil
		if ref and ref.X > 0 and ref.Y > 0 and ref.Z > 0 then
			return builder(model, part, CFrame.identity, ref, part.Size / ref)
		end
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
	if STEPS.on and material ~= NEON and material ~= GLASS then
		-- Sin giro: en escalones (en XY y, si cambia la Z, también en profundidad), así entra en la malla.
		local steps = math.max(3, math.round((to - from).Magnitude / 0.12))
		local dx, dy, dz =
			math.abs(to.X - from.X) / steps, math.abs(to.Y - from.Y) / steps, math.abs(to.Z - from.Z) / steps
		for index = 0, steps - 1 do
			local centre = from:Lerp(to, (index + 0.5) / steps)
			make.block(
				Vector3.new(dx + thickness * 0.5, dy + thickness * 0.5, math.max(thickness, dz + thickness * 0.5)),
				color,
				material,
				CFrame.new(centre)
			)
		end
		return
	end
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
		CFrame.new(0, y, 0) * CFrame.Angles(if STEPS.on then 0 else tilt or 0, 0, 0)
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

-- Línea en escalones de "from" a "to", sin ninguna pieza girada: así entra en la malla (Fase 20 Q6). Va en el plano XY
-- (mismo Z, con "depth" de fondo) o, si los dos puntos tienen la misma Y, en el plano horizontal XZ (con "depth" de
-- alto). "thickness" es el grosor de la línea y "steps" los escalones.
local function stairs(
	make: Builder,
	from: Vector3,
	to: Vector3,
	thickness: number,
	depth: number,
	color: Color3,
	material: Enum.Material,
	steps: number
)
	local flat = math.abs(to.Y - from.Y) < 0.0001 and math.abs(to.Z - from.Z) > 0.0001
	local dx, dy, dz = math.abs(to.X - from.X) / steps, math.abs(to.Y - from.Y) / steps, math.abs(to.Z - from.Z) / steps
	for index = 0, steps - 1 do
		local centre = from:Lerp(to, (index + 0.5) / steps)
		if flat then
			make.block(
				Vector3.new(dx + thickness * 0.5, depth, dz + thickness * 0.5),
				color,
				material,
				CFrame.new(centre.X, from.Y, centre.Z)
			)
		else
			make.block(
				Vector3.new(dx + thickness * 0.5, dy + thickness * 0.5, depth),
				color,
				material,
				CFrame.new(centre.X, centre.Y, from.Z)
			)
		end
	end
end

-- Mechón en tres escalones que se estrechan hacia abajo desde "topY" (sustituye al colmillo girado de los flecos).
local function tuft(
	make: Builder,
	x: number,
	topY: number,
	z: number,
	width: number,
	height: number,
	depth: number,
	color: Color3,
	material: Enum.Material
)
	for index = 0, 2 do
		make.block(
			Vector3.new(width * (1 - 0.3 * index), height / 3, depth),
			color,
			material,
			CFrame.new(x, topY - height / 3 * (index + 0.5), z)
		)
	end
end

-- Púa en tres escalones que se estrecha hacia arriba desde "baseY"; "lean" la inclina en X sin girar nada.
local function spire(
	make: Builder,
	x: number,
	baseY: number,
	z: number,
	width: number,
	height: number,
	depth: number,
	color: Color3,
	material: Enum.Material,
	lean: number?
)
	for index = 0, 2 do
		make.block(
			Vector3.new(width * (1 - 0.3 * index), height / 3, depth * (1 - 0.3 * index)),
			color,
			material,
			CFrame.new(x + (lean or 0) * index / 2, baseY + height / 3 * (index + 0.5), z)
		)
	end
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
		make.block(
			Vector3.new(0.26, 0.2, depth * 0.9),
			GOLDEN_FUR,
			FABRIC,
			CFrame.new(side * neck, height / 2 + 0.1, 0)
		)
		make.block(
			Vector3.new(0.16, 0.1, depth * 0.78),
			GOLDEN_FUR,
			FABRIC,
			CFrame.new(side * neck, height / 2 + 0.25, 0)
		)
		-- Hombrera de losa cuadrada de pelaje rojo con canto dorado y dos colmillos hacia fuera.
		local arm = body.upperArm[side]
		slabPauldron(arm, side, FUR, FABRIC, GOLDEN_FUR)
		-- Segundo escalón y mechones pintados en su cara (más volumen y relieve, sin piezas giradas).
		local padTop = arm.size.Y / 2
		arm.block(
			Vector3.new(arm.size.X + 0.16, 0.12, arm.size.Z + 0.16),
			FUR_DARK,
			FABRIC,
			CFrame.new(side * 0.1, padTop + 0.3, 0)
		)
		for strip = -2, 2 do
			arm.block(
				Vector3.new(arm.size.X + 0.1, 0.04, 0.07),
				if strip % 2 == 0 then GOLDEN_FUR else FUR,
				FABRIC,
				CFrame.new(side * 0.1, padTop + 0.35, strip * (arm.size.Z + 0.16) * 0.19)
			)
		end
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
		for hem = -1, 1, 2 do
			tuft(leg, hem * ls.X * 0.3, ls.Y * 0.16, flapZ, ls.X * 0.24, 0.24, 0.09, FUR, FABRIC)
		end
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
	-- El pulgar, en tres escalones hacia arriba y fuera de la palma.
	for index = 0, 2 do
		make.block(
			Vector3.new(width * 0.1, height * 0.07, 0.06),
			GOLDEN_FUR,
			FABRIC,
			CFrame.new(-palmWidth / 2 - 0.04 - index * 0.07, palmY + palmHeight * 0.05 + index * height * 0.06, printZ)
		)
	end
	-- Costura de fibra a los lados del panel (rayas cortas pintadas).
	for dash = 0, 4 do
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.035, height * 0.09, 0.03),
				FIBER,
				FABRIC,
				CFrame.new(side * width * 0.4, -height * 0.34 + dash * height * 0.12, back + skin / 2 + 0.045)
			)
		end
	end
	-- Manto de pelaje sobre los hombros, por detrás: una losa gruesa con mechones pintados y el bajo en mechones de
	-- tres escalones.
	local mantleY = height * 0.41
	local mantleZ = back + skin / 2 + 0.1
	make.block(Vector3.new(width * 0.96, height * 0.17, 0.12), FUR, FABRIC, CFrame.new(0, mantleY, mantleZ))
	for strand = 0, 7 do
		make.block(
			Vector3.new(0.07, height * 0.12, 0.03),
			if strand % 2 == 0 then FUR_DARK else GOLDEN_FUR,
			FABRIC,
			CFrame.new((strand - 3.5) * width * 0.115, mantleY, mantleZ + 0.075)
		)
	end
	for tip = 0, 4 do
		tuft(
			make,
			(tip - 2) * width * 0.2,
			mantleY - height * 0.085,
			mantleZ,
			0.28,
			0.14,
			0.12,
			if tip % 2 == 0 then FUR_DARK else FUR,
			FABRIC
		)
	end
	local fringe = 7
	for index = 0, fringe - 1 do
		local x = -width * 0.42 + index * width * 0.84 / (fringe - 1)
		tuft(
			make,
			x + 0.1,
			-height / 2 + 0.02,
			back + 0.12,
			0.2,
			if index % 2 == 0 then 0.34 else 0.26,
			0.12,
			if index % 2 == 0 then FUR else FUR_DARK,
			FABRIC
		)
	end
	-- Cuello por detrás y ribete dorado fino abajo.
	make.block(
		Vector3.new(width * 0.4 + 0.24, 0.24, 0.24),
		GOLDEN_FUR,
		FABRIC,
		CFrame.new(0, height / 2 + 0.1, depth / 2 - 0.02)
	)
	make.block(
		Vector3.new(width + 2 * (gap + skin) + 0.04, 0.14, depth + 2 * (gap + skin) + 0.04),
		GOLDEN_FUR,
		FABRIC,
		CFrame.new(0, -height / 2 + 0.05, 0)
	)
	-- Flecos de pelo en el bajo del chaleco, delante.
	for index = 0, 3 do
		tuft(
			make,
			-width * 0.33 + index * width * 0.22,
			-height / 2 + 0.02,
			front - 0.03,
			0.18,
			0.24,
			0.1,
			if index % 2 == 0 then FUR_DARK else FUR,
			FABRIC
		)
	end
	-- Cordones de fibra en cruz que cierran la abertura, por debajo del collar (en escalones).
	for _, laceY in { -height * 0.06, -height * 0.28 } do
		stairs(
			make,
			Vector3.new(-0.18, laceY + 0.1, front - 0.07),
			Vector3.new(0.18, laceY - 0.1, front - 0.07),
			0.05,
			0.04,
			FIBER,
			FABRIC,
			4
		)
		stairs(
			make,
			Vector3.new(-0.18, laceY - 0.1, front - 0.07),
			Vector3.new(0.18, laceY + 0.1, front - 0.07),
			0.05,
			0.04,
			FIBER,
			FABRIC,
			4
		)
	end
	-- Collar de colmillos: cordón en V desde el cuello y tres colmillos colgando, el del centro mayor.
	local necklaceZ = front - 0.09
	local knot = Vector3.new(0, height * 0.17, necklaceZ)
	for side = -1, 1, 2 do
		local from = Vector3.new(side * neck * 1.1, height / 2 - 0.02, necklaceZ)
		stairs(make, from, knot, 0.05, 0.05, FIBER, FABRIC, 4)
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
	waist.block(Vector3.new(0.2, 0.2, 0.14), FIBER, FABRIC, CFrame.new(-0.28, beltY, beltFront - 0.02))
	for _, offset in { 0.07, -0.05 } do
		waist.block(
			Vector3.new(0.06, 0.3, 0.06),
			FIBER,
			FABRIC,
			CFrame.new(-0.28 + offset, beltY - 0.18, beltFront - 0.03)
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
		band(forearm, -forearm.size.Y * 0.3, 0.1, 0.06, FIBER, FABRIC)
		band(forearm, -forearm.size.Y * 0.44, 0.1, 0.06, FIBER, FABRIC)
	end
end

-- ===================================== Armadura de hueso =====================================

-- Cráneo de mono con la cara hacia la -Z de "at", "scale" veces el tamaño de las hombreras de la
-- armadura de hueso. Todos llevan ceja, fosas nasales y dientes, también los pequeños (el cuarto parámetro ya no quita nada).
local function monkeySkull(make: Builder, at: CFrame, scale: number, _simple: boolean?)
	local function on(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x * scale, y * scale, z * scale)
	end
	-- Cráneo en tres capas de bloques (como un óvalo en píxeles): entra en la malla si "at" va alineado con el ancla.
	make.block(Vector3.new(0.8, 0.42, 0.86) * scale, BONE, SMOOTH, on(0, 0.06, 0.06))
	make.block(Vector3.new(0.64, 0.14, 0.74) * scale, BONE, SMOOTH, on(0, 0.35, 0.06))
	make.block(Vector3.new(0.64, 0.14, 0.74) * scale, BONE, SMOOTH, on(0, -0.23, 0.06))
	-- Cuencas oscuras bajo la ceja saliente.
	for eye = -1, 1, 2 do
		make.block(Vector3.one * 0.2 * scale, SKULL_HOLE, SMOOTH, on(eye * 0.15, -0.03, -0.32))
	end
	-- Hocico con el hueco de la nariz y dos colmillos.
	make.block(Vector3.new(0.4, 0.24, 0.3) * scale, BONE, SMOOTH, on(0, -0.2, -0.38))
	make.block(Vector3.new(0.64, 0.15, 0.16) * scale, BONE, SMOOTH, on(0, 0.1, -0.32))
	-- Dos fosas nasales hondas, una a cada lado del tabique, y cuatro dientes en la boca (los de los lados, más largos).
	for nostril = -1, 1, 2 do
		make.block(Vector3.new(0.1, 0.13, 0.05) * scale, SKULL_HOLE, SMOOTH, on(nostril * 0.08, -0.16, -0.545))
	end
	for index, x in { -0.15, -0.05, 0.05, 0.15 } do
		make.block(
			Vector3.new(0.08, if index == 1 or index == 4 then 0.19 else 0.13, 0.07) * scale,
			BONE,
			SMOOTH,
			on(x, if index == 1 or index == 4 then -0.405 else -0.375, -0.5)
		)
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
			-- Costilla en escalones (sin giro): del esternón hacia fuera y abajo.
			stairs(
				make,
				Vector3.new(side * 0.1, height * ribY, front - 0.02),
				Vector3.new(
					side * (0.1 + length * math.cos(tilt)),
					height * ribY - length * math.sin(tilt),
					front - 0.02
				),
				0.12,
				0.1,
				BONE,
				SMOOTH,
				3
			)
		end
	end
	make.block(Vector3.new(0.2, height * 0.74, 0.14), BONE, SMOOTH, CFrame.new(0, -height * 0.02, front - 0.05))
	tuft(make, 0, -height * 0.39, front - 0.05, 0.16, 0.3, 0.14, BONE, SMOOTH)
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
			-- Costilla de la espalda en escalones: del espinazo hacia fuera y arriba.
			stairs(
				make,
				Vector3.new(side * 0.1, height * ribY - length * math.sin(tilt), back + 0.08),
				Vector3.new(side * (0.1 + length * math.cos(tilt)), height * ribY, back + 0.08),
				0.13,
				0.09,
				BONE,
				SMOOTH,
				3
			)
		end
	end
	-- Escamas de hueso sobre los hombros, por detrás (tres filas escalonadas) y costura de fibra en el borde del cuero.
	for row = 0, 2 do
		for column = -2, 2 do
			if column ~= 0 then
				make.block(
					Vector3.new(width * 0.19, 0.11, 0.07),
					if (row + column) % 2 == 0 then BONE else BONE_DARK,
					SMOOTH,
					CFrame.new((column + (row % 2) * 0.25) * width * 0.2, height * (0.43 - row * 0.075), back + 0.065)
				)
			end
		end
	end
	for dash = 0, 4 do
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.035, height * 0.09, 0.03),
				FIBER,
				FABRIC,
				CFrame.new(side * width * 0.4, -height * 0.34 + dash * height * 0.12, back + 0.035)
			)
		end
	end
	local trophy = CFrame.new(0, height * 0.17, back + 0.16)
	-- Huesos cruzados en escalones, con un bulto cuadrado en cada punta (sin ninguna pieza girada).
	for _, cross in { 0.65, -0.65 } do
		local from = (trophy * CFrame.Angles(0, 0, cross) * CFrame.new(-width * 0.33, 0, 0)).Position
		local to = (trophy * CFrame.Angles(0, 0, cross) * CFrame.new(width * 0.33, 0, 0)).Position
		stairs(make, from, to, 0.13, 0.13, BONE, SMOOTH, 6)
		for _, tip in { from, to } do
			make.block(Vector3.new(0.24, 0.24, 0.16), BONE, SMOOTH, CFrame.new(tip))
		end
	end
	monkeySkull(make, trophy * CFrame.new(0, 0.04, 0.3) * CFrame.Angles(0, math.pi, 0), 1.15)
	for side = -1, 1, 2 do
		local tassel = trophy * CFrame.new(side * width * 0.3, -0.3, 0.1)
		make.block(Vector3.new(0.04, 0.3, 0.04), FIBER, FABRIC, tassel)
		make.block(Vector3.new(0.18, 0.2, 0.1), FUR, FABRIC, tassel * CFrame.new(0, -0.22, 0.02))
		local tasselAt = (tassel * CFrame.new(0, -0.32, 0.02)).Position
		tuft(make, tasselAt.X, tasselAt.Y, tasselAt.Z, 0.18, 0.3, 0.1, FUR_DARK, FABRIC)
	end
	for index = 0, 3 do
		tuft(
			make,
			-width * 0.33 + index * width * 0.22 + 0.1,
			-height / 2 + 0.02,
			back + 0.1,
			0.2,
			if index % 2 == 0 then 0.34 else 0.26,
			0.1,
			if index % 2 == 0 then FUR else FUR_DARK,
			FABRIC
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
	waist.block(Vector3.new(0.32, 0.3, 0.18), BONE, SMOOTH, CFrame.new(0, 0.08, beltFront - 0.06))
	for eye = -1, 1, 2 do
		waist.block(Vector3.new(0.09, 0.09, 0.05), SKULL_HOLE, SMOOTH, CFrame.new(eye * 0.06, 0.1, beltFront - 0.16))
		waist.block(
			Vector3.new(0.1, 0.1, 0.08),
			BONE_DARK,
			SMOOTH,
			CFrame.new(eye * hipWidth * 0.32, 0.08, beltFront - 0.06)
		)
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
		for strip = -2, 2 do
			arm.block(
				Vector3.new(arm.size.X + 0.2, 0.04, 0.07),
				if strip % 2 == 0 then BONE_DARK else BONE,
				LEATHER_MATERIAL,
				CFrame.new(side * 0.1, top + 0.255, strip * (arm.size.Z + 0.1) * 0.19)
			)
		end
		monkeySkull(arm, CFrame.new(side * arm.size.X * 0.2, top + 0.5, 0), 0.8)
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
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.17, -(ls.Z / 2 + 0.05))
		leg.block(Vector3.new(ls.X * 0.85, ls.Y * 0.36, 0.08), LEATHER, LEATHER_MATERIAL, flap)
		for _, x in { -0.28, 0, 0.28 } do
			leg.block(Vector3.new(0.1, ls.Y * 0.3, 0.06), BONE, SMOOTH, flap * CFrame.new(x * ls.X, -0.02, -0.06))
		end
		tuft(leg, side * 0.04, ls.Y * 0.15, -(ls.Z / 2 + 0.1), 0.12, 0.26, 0.1, BONE, SMOOTH)
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
		make.block(Vector3.one * 0.07 * size, SKULL_HOLE, SMOOTH, on(side * 0.1, -0.15, -0.23))
		-- Ceja de furia: inclinada, más baja por dentro.
		stairs(
			make,
			on(side * 0.4, 0.27, -0.16).Position,
			on(side * 0.03, 0.12, -0.16).Position,
			0.13 * size,
			0.12 * size,
			GORILLA_FACE,
			SMOOTH,
			4
		)
		-- Comisuras de la boca hacia abajo: gruñido.
		make.block(Vector3.new(0.07, 0.12, 0.06) * size, SKULL_HOLE, SMOOTH, on(side * 0.22, -0.34, -0.18))
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
		if STEPS.on then
			tuft(
				make,
				x + 0.15,
				capeBottom + 0.04,
				back + 0.24,
				0.3,
				if index % 2 == 0 then 0.36 else 0.26,
				0.14,
				if index % 2 == 0 then SILVER_FUR else SILVER_FUR_DARK,
				FABRIC
			)
		else
			make.fang(
				if index % 2 == 0 then 0.36 else 0.26,
				0.3,
				if index % 2 == 0 then SILVER_FUR else SILVER_FUR_DARK,
				FABRIC,
				CFrame.new(x + 0.15, capeBottom + 0.04, back + 0.36) * CFrame.Angles(0, 0, math.pi)
			)
		end
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
		make.block(Vector3.new(width * 0.44, height * 0.3, 0.12), BONE_DARK, SMOOTH, pec)
		make.block(Vector3.new(width * 0.4, height * 0.26, 0.1), THICK_BONE, SMOOTH, pec * CFrame.new(0, 0.01, -0.04))
		for _, y in { 0.12, -0.12 } do
			local rivet = make.block(Vector3.one * 0.1, SILVER, METAL, pec * CFrame.new(side * width * 0.15, y, -0.1))
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
		local stud = make.block(
			Vector3.one * 0.1,
			SILVER,
			METAL,
			medal * CFrame.new(math.sin(angle) * 0.31, math.cos(angle) * 0.31, -0.02)
		)
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
		-- Sin giro: cada bloque de la gorguera va en su sitio del semicírculo, y las púas son escalones.
		make.block(
			Vector3.new(0.5, 0.55, 0.4),
			if index % 2 == 0 then SILVER_FUR else SILVER_FUR_DARK,
			FABRIC,
			CFrame.new(math.sin(angle) * 0.8, height / 2 + 0.22, math.cos(angle) * 0.62)
		)
		if index % 2 == 1 then
			spire(
				make,
				math.sin(angle) * 0.8,
				height / 2 + 0.5,
				math.cos(angle) * 0.62,
				0.22,
				0.34,
				0.2,
				SILVER_FUR,
				FABRIC
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
		tuft(
			make,
			x + 0.17,
			capeY - capeHeight / 2 + 0.05,
			back + 0.2,
			0.34,
			if index % 2 == 0 then 0.42 else 0.3,
			0.14,
			if index % 2 == 0 then GORILLA_FUR else SILVER_FUR,
			FABRIC
		)
	end
	-- Mechones pintados en la capa, a los lados de la cara (relieve de pelo, casi gratis en la malla).
	for side = -1, 1, 2 do
		for strand = 0, 2 do
			make.block(
				Vector3.new(0.06, capeHeight * (0.62 - strand * 0.08), 0.03),
				if strand % 2 == 0 then SILVER_FUR_DARK else SILVER_FUR,
				FABRIC,
				CFrame.new(side * (width * 0.36 + strand * 0.11), capeY + capeHeight * 0.08, back + 0.245)
			)
		end
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
		local stud =
			waist.block(Vector3.one * 0.12, SILVER, METAL, CFrame.new(side * hipWidth * 0.34, 0.06, beltFront - 0.04))
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
			-- Tres láminas en cascada (cada una más afuera y más abajo), sin giro: así entran en la malla.
			local lame = CFrame.new(side * (0.1 + index * 0.16), top + 0.2 - index * 0.21, 0)
			lames[index + 1] = lame
			arm.block(
				Vector3.new(as.X * 0.95 - index * 0.06, 0.16, as.Z + 0.3 - index * 0.08),
				if index == 1 then BONE else THICK_BONE,
				SMOOTH,
				lame
			)
		end
		local stud =
			arm.block(Vector3.one * 0.14, SILVER, METAL, lames[2] * CFrame.new(side * (as.X * 0.5 - 0.12), 0.12, 0))
		stud.Reflectance = 0.25
		-- Hacia fuera y delante, hacia fuera y hacia fuera y atrás: se les ve la cara también desde detrás.
		for index, z in { -0.42, 0, 0.42 } do
			-- Cara al frente, hacia fuera y atrás (giros de 90°: se les ve la cara también desde detrás).
			local yaw = if index == 1 then 0 elseif index == 2 then -side * math.rad(90) else math.pi
			local scale = if index == 2 then 0.7 else 0.58
			monkeySkull(
				arm,
				lames[1] * CFrame.new(0, 0.1 + 0.3 * scale, z * as.Z) * CFrame.Angles(0, yaw, 0),
				scale,
				true
			)
		end
		for strip = -2, 2 do
			arm.block(
				Vector3.new(as.X + 0.4, 0.04, 0.07),
				if strip % 2 == 0 then SILVER else SILVER_FUR_DARK,
				FABRIC,
				CFrame.new(side * 0.12, top + 0.095, strip * (as.Z + 0.5) * 0.19)
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
			local rivet = forearm.block(
				Vector3.one * 0.12,
				SILVER,
				METAL,
				CFrame.new(side * (fs.X / 2 + 0.15), 0.05 + y * fs.Y, 0)
			)
			rivet.Reflectance = 0.25
		end
		-- Faldón de pelaje plateado en el muslo con tres placas de hueso, un remache y dos flecos.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.19, -(ls.Z / 2 + 0.06))
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), SILVER_FUR, FABRIC, flap)
		leg.block(Vector3.new(ls.X * 0.4, ls.Y * 0.3, 0.08), THICK_BONE, SMOOTH, flap * CFrame.new(0, 0.02, -0.07))
		for plate = -1, 1, 2 do
			leg.block(
				Vector3.new(ls.X * 0.14, ls.Y * 0.26, 0.06),
				BONE,
				SMOOTH,
				flap * CFrame.new(plate * ls.X * 0.34, 0.02, -0.07)
			)
			local hemAt = (flap * CFrame.new(plate * ls.X * 0.22, -ls.Y * 0.2 + 0.03, -0.02)).Position
			tuft(
				leg,
				hemAt.X,
				hemAt.Y,
				hemAt.Z,
				0.18,
				0.22,
				0.1,
				if plate == 1 then SILVER_FUR_DARK else SILVER_FUR,
				FABRIC
			)
		end
		local rivet = leg.block(Vector3.one * 0.12, SILVER, METAL, flap * CFrame.new(0, ls.Y * 0.09, -0.12))
		rivet.Reflectance = 0.25
	end
end

-- ===================================== Cazador =====================================

-- Hoja de camuflaje de "length" de largo a lo largo del eje +Y de "at" (la punta hacia allí), en escalones sin giro: una
-- franja diagonal con el nervio más oscuro por fuera (+Z de "at"); sin nervio parece un lunar. Vale para una hoja en un
-- plano vertical o, tumbada (como sobre un hombro), en el horizontal.
local function leaf(make: Builder, length: number, color: Color3, at: CFrame)
	if not STEPS.on then
		make.oval(Vector3.new(length * 0.42, length, 0.05), color, SMOOTH, at)
		make.block(
			Vector3.new(0.03, length * 0.8, 0.03),
			color:Lerp(Color3.new(0, 0, 0), 0.35),
			SMOOTH,
			at * CFrame.new(0, 0, 0.03)
		)
		return
	end
	local axis = at:VectorToWorldSpace(Vector3.yAxis)
	local lift = at:VectorToWorldSpace(Vector3.zAxis) * 0.03
	local from = at.Position - axis * (length / 2)
	local to = at.Position + axis * (length / 2)
	local steps = math.max(3, math.round(length / 0.1))
	stairs(make, from, to, length * 0.3, 0.05, color, SMOOTH, steps)
	stairs(make, from + lift, to + lift, 0.04, 0.03, color:Lerp(Color3.new(0, 0, 0), 0.35), SMOOTH, steps)
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

-- Carcaj con el eje a lo largo de la +Y de "at" (el centro del tubo), en escalones sin giro: el tubo grueso, un aro en la
-- boca y otro en el fondo, y las flechas asomando por la boca (un palo fino en escalones con dos plumas cruzadas), un
-- poco abiertas en abanico. "at" solo gira alrededor de Z (en la espalda va en diagonal). Devuelve el marco de la boca.
local function quiver(make: Builder, at: CFrame, style: QuiverStyle): CFrame
	if not STEPS.on then
		local length, radius = style.length, style.radius
		make.rod(length, radius * 2, style.color, style.material, at * UPRIGHT)
		local mouth = at * CFrame.new(0, length / 2, 0)
		make.rod(0.12, radius * 2 + 0.06, style.rim, style.rimMaterial, mouth * CFrame.new(0, -0.05, 0) * UPRIGHT)
		make.rod(
			0.1,
			radius * 2 + 0.04,
			style.rim,
			style.rimMaterial,
			at * CFrame.new(0, -length / 2 + 0.06, 0) * UPRIGHT
		)
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
	local length, radius = style.length, style.radius
	local axis = at:VectorToWorldSpace(Vector3.yAxis)
	local across = at:VectorToWorldSpace(Vector3.xAxis)
	local bottom = at.Position - axis * (length / 2)
	local mouth = at.Position + axis * (length / 2)
	-- Tubo: un bloque por escalón, tan ancho como el carcaj más lo que avanza en X, con el alto del escalón.
	local steps = math.max(5, math.round(length / 0.2))
	local stepX, stepY = math.abs(mouth.X - bottom.X) / steps, math.abs(mouth.Y - bottom.Y) / steps
	for index = 0, steps - 1 do
		make.block(
			Vector3.new(radius * 2 + stepX, stepY + 0.04, radius * 2),
			style.color,
			style.material,
			CFrame.new(bottom:Lerp(mouth, (index + 0.5) / steps))
		)
	end
	-- Aros de la boca y del fondo: dos losas planas que sobresalen un poco del tubo.
	make.block(
		Vector3.new(radius * 2 + 0.1 + stepX, 0.12, radius * 2 + 0.08),
		style.rim,
		style.rimMaterial,
		CFrame.new(mouth - axis * 0.05)
	)
	make.block(
		Vector3.new(radius * 2 + 0.08 + stepX, 0.1, radius * 2 + 0.06),
		style.rim,
		style.rimMaterial,
		CFrame.new(bottom + axis * 0.05)
	)
	local count = style.arrows
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2
		local spot = if count == 1
			then Vector3.zero
			else Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.55
		local stick = 0.4 + (index % 2) * 0.12
		local start = mouth + across * spot.X + Vector3.new(0, 0, spot.Z)
		local direction = (axis + across * spot.X * 1.4).Unit
		stairs(make, start - direction * 0.2, start + direction * stick, 0.06, 0.06, ARROW_SHAFT, WOOD, 4)
		local feather = style.feathers[(index - 1) % #style.feathers + 1]
		local plume = start + direction * (stick - 0.13)
		make.block(Vector3.new(0.03, 0.3, 0.17), feather, SMOOTH, CFrame.new(plume))
		make.block(Vector3.new(0.17, 0.3, 0.03), feather, SMOOTH, CFrame.new(plume))
	end
	return CFrame.new(mouth) * (at - at.Position)
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
	if not STEPS.on then
		strap(
			make,
			Vector3.new(width * 0.3, height / 2 - 0.02, front),
			Vector3.new(-width * 0.4, -height / 2 + 0.12, front),
			thickness,
			color,
			material
		)
		return
	end
	stairs(
		make,
		Vector3.new(width * 0.3, height / 2 - 0.02, front),
		Vector3.new(-width * 0.4, -height / 2 + 0.12, front),
		thickness,
		thickness,
		color,
		material,
		10
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
		-- Una de cada dos un poco por fuera, para que no compartan plano. Cada hoja es una franja en escalones.
		local root = neck + Vector3.new(0, 0, (index % 2) * 0.05)
		if not STEPS.on then
			make.block(
				Vector3.new(0.3, size, 0.06),
				colors[index % #colors + 1],
				SMOOTH,
				CFrame.new(root + direction * (size / 2 + 0.05)) * CFrame.Angles(0, 0, math.pi + angle)
			)
			continue
		end
		stairs(
			make,
			root + direction * 0.05,
			root + direction * (size + 0.05),
			0.6,
			0.06,
			colors[index % #colors + 1],
			SMOOTH,
			math.max(4, math.round(size / 0.18))
		)
	end
end

-- Estrella de hojas tumbada sobre el hombro (la del lado del carcaj): ocho hojas de bloque en rueda sobre un disco de
-- cuero (cuatro largas en los ejes y cuatro cortas en escalones en las diagonales), con una cuenta clara en el centro.
local function leafStar(arm: Builder, side: number)
	local as = arm.size
	local top = as.Y / 2
	local center = Vector3.new(side * 0.1, top + 0.1, 0)
	if not STEPS.on then
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
		return
	end
	arm.block(
		Vector3.new(as.X + 0.2, 0.08, as.Z + 0.2),
		HUNTER_LEATHER_DARK,
		LEATHER_MATERIAL,
		CFrame.new(center.X, top + 0.04, 0)
	)
	for index = 0, 7 do
		local angle = index / 8 * math.pi * 2
		local dx, dz = math.round(math.cos(angle) * 100) / 100, math.round(math.sin(angle) * 100) / 100
		local color = if index % 2 == 0 then LEAF else LEAF_DARK
		if index % 2 == 0 then
			local alongX = math.abs(dx) > 0.5
			arm.block(
				if alongX then Vector3.new(0.66, 0.06, 0.24) else Vector3.new(0.24, 0.06, 0.66),
				color,
				SMOOTH,
				CFrame.new(center + Vector3.new(dx * 0.34, 0, dz * 0.34))
			)
		else
			local sx, sz = if dx > 0 then 1 else -1, if dz > 0 then 1 else -1
			arm.block(
				Vector3.new(0.2, 0.06, 0.2),
				color,
				SMOOTH,
				CFrame.new(center + Vector3.new(sx * 0.2, 0.03, sz * 0.2))
			)
			arm.block(
				Vector3.new(0.16, 0.06, 0.16),
				color,
				SMOOTH,
				CFrame.new(center + Vector3.new(sx * 0.36, 0.03, sz * 0.36))
			)
		end
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
	if STEPS.on then
		local tip = (fold * CFrame.new(0, -0.32, 0.15)).Position
		tuft(make, tip.X, tip.Y, tip.Z, 0.3, 0.4, 0.24, color, hoodMaterial)
	else
		make.fang(0.4, 0.3, color, hoodMaterial, fold * CFrame.new(0.14, -0.32, 0.15) * CFrame.Angles(0, 0, math.pi))
	end
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
		tuft(
			make,
			-width * 0.36 + index * width * 0.18 + 0.09,
			height / 2 - 0.2,
			depth / 2 + 0.2,
			0.18,
			if index % 2 == 0 then 0.26 else 0.2,
			0.1,
			FUR_BROWN,
			FABRIC
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

	-- Pespuntes de fibra a los lados del jubón y mechones pintados sobre la capa de pelaje (relieve casi gratis en la malla).
	for dash = 0, 4 do
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.035, height * 0.09, 0.03),
				FIBER,
				FABRIC,
				CFrame.new(side * width * 0.4, -height * 0.34 + dash * height * 0.12, front + 0.01)
			)
		end
	end
	for strip = -2, 2 do
		make.block(
			Vector3.new(width + 0.14, 0.04, 0.07),
			if strip % 2 == 0 then BARK else HUNTER_LEATHER_DARK,
			FABRIC,
			CFrame.new(0, height / 2 + 0.095, 0.02 + strip * (depth + 0.3) * 0.19)
		)
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
	local sheath = CFrame.new(-hipWidth * 0.36, beltY - 0.2, beltFront - 0.03)
	waist.block(Vector3.new(0.14, 0.42, 0.08), HUNTER_LEATHER_DARK, LEATHER_MATERIAL, sheath)
	waist.block(Vector3.new(0.1, 0.2, 0.1), BONE, SMOOTH, sheath * CFrame.new(0, 0.3, 0))

	-- Brazal de cuero en el antebrazo del arco (el derecho) y muñeca vendada en el otro.
	local bowArm = body.lowerArm[1]
	band(bowArm, -bowArm.size.Y * 0.08, bowArm.size.Y * 0.5, 0.08, HUNTER_LEATHER_DARK, LEATHER_MATERIAL)
	band(bowArm, bowArm.size.Y * 0.1, 0.06, 0.12, FIBER, FABRIC)
	local drawArm = body.lowerArm[-1]
	band(drawArm, -drawArm.size.Y * 0.36, 0.12, 0.06, FIBER, FABRIC)
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
		make.block(Vector3.new(0.32, 0.08, 0.08), BONE, SMOOTH, CFrame.new(0, height * y, front - 0.04))
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
		tuft(make, x, y - 0.04, front - 0.09, 0.1, 0.26, 0.08, BONE, SMOOTH)
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
	local ringAt = (quiverAt * CFrame.new(0, -0.2, 0)).Position
	make.block(Vector3.new(0.6, 0.1, 0.57), BONE, SMOOTH, CFrame.new(ringAt))
	make.block(
		Vector3.new(0.04, 0.3, 0.04),
		FIBER,
		FABRIC,
		CFrame.new((quiverAt * CFrame.new(-0.3, 0.3, 0.05)).Position)
	)
	local fangAt = (quiverAt * CFrame.new(-0.23, 0.17, 0.14)).Position
	tuft(make, fangAt.X, fangAt.Y, fangAt.Z, 0.14, 0.38, 0.12, BONE, SMOOTH)

	-- Pespuntes claros a los lados del jubón y rayas de cuero pintadas en el cuello (relieve casi gratis en la malla).
	for dash = 0, 4 do
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.035, height * 0.09, 0.03),
				HUNTER_LEATHER,
				LEATHER_MATERIAL,
				CFrame.new(side * width * 0.4, -height * 0.34 + dash * height * 0.12, front + 0.01)
			)
		end
	end
	for strip = -2, 2 do
		make.block(
			Vector3.new(width * 0.7 + 0.1, 0.04, 0.07),
			if strip % 2 == 0 then HUNTER_LEATHER_DARK else BONE_DARK,
			LEATHER_MATERIAL,
			CFrame.new(0, height / 2 + 0.055, strip * (depth + 0.24) * 0.19)
		)
	end

	-- Cinturón de cuero con hebilla de hueso, tachones, zurrón, cuchillo y un colmillo de trofeo.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.08)
	waist.block(Vector3.new(hipWidth + 0.14, 0.2, hipDepth + 0.14), LEATHER, LEATHER_MATERIAL, CFrame.new(0, 0.06, 0))
	waist.block(Vector3.new(0.3, 0.24, 0.08), BONE, SMOOTH, CFrame.new(0, 0.06, beltFront - 0.02))
	tuft(waist, 0, -0.06, beltFront - 0.06, 0.12, 0.3, 0.1, BONE, SMOOTH)
	for _, x in { 0.16, -0.16 } do
		waist.block(Vector3.one * 0.09, BONE_DARK, SMOOTH, CFrame.new(x * hipWidth, 0.06, beltFront - 0.04))
	end
	local pouch = CFrame.new(hipWidth * 0.3, -0.12, beltFront - 0.06)
	waist.block(Vector3.new(0.38, 0.34, 0.14), LEATHER, LEATHER_MATERIAL, pouch)
	waist.block(
		Vector3.new(0.42, 0.12, 0.18),
		HUNTER_LEATHER_DARK,
		LEATHER_MATERIAL,
		pouch * CFrame.new(0, 0.13, -0.01)
	)
	local sheath = CFrame.new(-hipWidth * 0.36, -0.14, beltFront - 0.03)
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
		-- Garra en tres escalones hacia fuera y arriba (sin giro).
		for step = 0, 2 do
			left.block(
				Vector3.one * (0.14 - step * 0.035),
				BONE,
				SMOOTH,
				CFrame.new(-(left.size.X / 2 + 0.25 + step * 0.1), leftTop + 0.2 + step * 0.1, z * left.size.Z)
			)
		end
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
		leg.block(Vector3.one * 0.1, BONE, SMOOTH, CFrame.new(side * 0.06, ls.Y / 2 - 0.14, -(ls.Z / 2 + 0.07)))
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
	stairs(
		make,
		Vector3.new(-width * 0.3, height / 2 - 0.02, front - 0.02),
		Vector3.new(width * 0.4, -height / 2 + 0.12, front - 0.02),
		0.14,
		0.14,
		HUNTER_LEATHER_DARK,
		LEATHER_MATERIAL,
		10
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
		local rivet = make.block(Vector3.one * 0.13, SILVER, METAL, CFrame.new(at.X, at.Y, front - 0.12))
		rivet.Reflectance = 0.25
	end
	-- Tres colmillos de trofeo colgando de la correa.
	for _, t in { 0.3, 0.45, 0.6 } do
		local x = width * 0.3 - width * 0.7 * t
		local y = (height / 2 - 0.02) + (-height + 0.14) * t
		tuft(make, x, y - 0.08, front - 0.16, 0.1, 0.26, 0.08, THICK_BONE, SMOOTH)
	end
	-- Pespuntes de plata a los lados del jubón (rayas cortas pintadas).
	for dash = 0, 4 do
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.035, height * 0.09, 0.03),
				SILVER,
				LEATHER_MATERIAL,
				CFrame.new(side * width * 0.4, -height * 0.34 + dash * height * 0.12, front + 0.01)
			)
		end
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
		-- Orejas de la capucha en tres escalones, algo abiertas hacia fuera.
		local ear = (hood * CFrame.new(side * 0.42, 0.3, -0.05)).Position
		spire(make, ear.X, ear.Y, ear.Z, 0.22, 0.34, 0.18, GORILLA_FUR, FABRIC, side * 0.06)
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
	make.block(
		Vector3.new(0.04, 0.3, 0.04),
		FIBER,
		FABRIC,
		CFrame.new((quiverAt * CFrame.new(-0.3, 0.2, 0.05)).Position)
	)
	make.block(
		Vector3.new(0.14, 0.22, 0.1),
		SILVER_FUR,
		FABRIC,
		CFrame.new((quiverAt * CFrame.new(-0.3, 0.0, 0.05)).Position)
	)

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
		local stud = waist.block(Vector3.one * 0.1, SILVER, METAL, CFrame.new(x * hipWidth, 0.06, beltFront - 0.04))
		stud.Reflectance = 0.25
	end
	local pouch = CFrame.new(hipWidth * 0.3, -0.12, beltFront - 0.06)
	waist.block(Vector3.new(0.38, 0.34, 0.14), LEATHER_DARK, LEATHER_MATERIAL, pouch)
	waist.block(Vector3.new(0.42, 0.14, 0.18), SILVER_FUR, FABRIC, pouch * CFrame.new(0, 0.13, -0.01))
	local sheath = CFrame.new(-hipWidth * 0.36, -0.14, beltFront - 0.03)
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
			-- Garra en tres escalones hacia fuera y arriba (sin giro).
			for step = 0, 2 do
				arm.block(
					Vector3.one * (0.18 - step * 0.045),
					THICK_BONE,
					SMOOTH,
					CFrame.new(side * (as.X * 0.55 + step * 0.13), top + 0.2 + step * 0.13, z * as.Z)
				)
			end
		end
		for strip = -2, 2 do
			arm.block(
				Vector3.new(as.X + 0.06, 0.04, 0.07),
				if strip % 2 == 0 then SILVER else SILVER_FUR_DARK,
				FABRIC,
				CFrame.new(side * 0.1, top + 0.455, strip * (as.Z + 0.1) * 0.19)
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
				local rivet =
					forearm.block(Vector3.one * 0.12, SILVER, METAL, CFrame.new(fs.X / 2 + 0.15, 0.04 + y * fs.Y, 0))
				rivet.Reflectance = 0.25
			end
		end
		-- Faldón de pelaje plateado en el muslo con una hoja oscura encima y dos flecos.
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06))
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), SILVER_FUR, FABRIC, flap)
		leaf(
			leg,
			0.48,
			LEAF_SHADOW,
			flap * CFrame.new(side * 0.1, -0.05, -0.07) * CFrame.Angles(0, math.pi, math.pi + side * 0.3)
		)
		for plate = -1, 1, 2 do
			local hemAt = (flap * CFrame.new(plate * ls.X * 0.22, -ls.Y * 0.2 + 0.03, -0.02)).Position
			tuft(
				leg,
				hemAt.X,
				hemAt.Y,
				hemAt.Z,
				0.18,
				0.22,
				0.1,
				if plate == 1 then SILVER_FUR_DARK else SILVER_FUR,
				FABRIC
			)
		end
	end
end

-- ===================================== Mago =====================================

-- Detalle extra del Mago con malla (Fase 20 Q6d): todo en bloques alineados y de material liso, así entra en la malla y
-- casi no cuesta triángulos. Costuras en el pecho, bandas en la espalda, hombreras con rayas, remaches y flecos,
-- anillos en los antebrazos y rayas y flecos en los faldones. "p" trae los colores del rango y las medidas de su hombrera.
type MageDetail = {
	main: Color3,
	dark: Color3,
	accent: Color3,
	material: Enum.Material,
	frontZ: number, -- lo que el frente de la túnica sobresale de depth / 2
	backZ: number, -- y la espalda
	padY: number?, -- altura de la cara de arriba de la hombrera sobre su base (nil: la lleva la propia armadura)
	padWide: number,
	padStud: number,
	fringeZ: number,
	fringeY: number,
}
local function mageDetail(body: Body, p: MageDetail)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local mat = p.material
	-- Costuras a los lados del pecho.
	for dash = 0, 4 do
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.035, height * 0.09, 0.03),
				p.accent,
				mat,
				CFrame.new(side * width * 0.37, -height * 0.34 + dash * height * 0.12, -(depth / 2 + p.frontZ))
			)
		end
	end
	-- Bandas pintadas en la espalda baja y flecos en el bajo.
	for index = 0, 2 do
		make.block(
			Vector3.new(width * 0.8, 0.04, 0.04),
			if index == 1 then p.dark else p.accent,
			mat,
			CFrame.new(0, -height * (0.3 + 0.07 * index), depth / 2 + p.backZ)
		)
	end
	for index = 0, 6 do
		tuft(
			make,
			(index - 3) * width * 0.13,
			-height / 2 + 0.06,
			depth / 2 + p.backZ - 0.02,
			0.2,
			if index % 2 == 0 then 0.3 else 0.22,
			0.08,
			if index % 2 == 0 then p.main else p.dark,
			mat
		)
	end
	for side = -1, 1, 2 do
		local arm = body.upperArm[side]
		local as = arm.size
		local top = as.Y / 2
		local cx = side * 0.1
		if p.padY then
			for strip = -2, 2 do
				arm.block(
					Vector3.new(as.X + p.padWide, 0.03, 0.06),
					if strip % 2 == 0 then p.accent else p.dark,
					mat,
					CFrame.new(cx, top + p.padY + 0.015, strip * (as.Z + p.padWide) * 0.2)
				)
			end
			for _, corner in
				{ Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) }
			do
				arm.block(
					Vector3.one * 0.1,
					p.accent,
					mat,
					CFrame.new(
						cx + corner.X * (as.X / 2 + p.padStud),
						top + p.padY - 0.02,
						corner.Z * (as.Z / 2 + p.padStud)
					)
				)
			end
			for _, face in { -1, 1 } do
				for k = -1, 1 do
					tuft(
						arm,
						cx + k * as.X * 0.3,
						top + p.fringeY,
						face * (as.Z / 2 + p.fringeZ),
						0.26,
						0.22,
						0.06,
						if k == 0 then p.accent else p.main,
						mat
					)
				end
			end
		end
		local forearm = body.lowerArm[side]
		for _, y in { 0.34, 0.18 } do
			band(forearm, forearm.size.Y * (y - 0.5) + 0.05, 0.035, 0.14, p.accent, mat)
		end
		local leg = body.upperLeg[side]
		local ls = leg.size
		local flapY = ls.Y / 2 - ls.Y * 0.2
		local flapZ = -(ls.Z / 2 + 0.11)
		for k = -1, 1 do
			leg.block(
				Vector3.new(0.04, ls.Y * 0.18, 0.03),
				p.accent,
				mat,
				CFrame.new(side * 0.04 + k * ls.X * 0.25, flapY + 0.02, flapZ)
			)
			tuft(
				leg,
				side * 0.04 + k * ls.X * 0.25,
				flapY - ls.Y * 0.2,
				flapZ + 0.02,
				0.2,
				0.22,
				0.06,
				if k == 0 then p.accent else p.main,
				mat
			)
		end
	end
end

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
	if STEPS.on and material ~= NEON and material ~= GLASS then
		-- Aro en píxeles (celdas de "thickness"): sin ningún bloque girado, así entra en la malla.
		local seen: { [string]: boolean } = {}
		local samples = math.max(count * 4, 24)
		for index = 0, samples - 1 do
			local angle = index / samples * 2 * math.pi
			local cx = math.round(math.cos(angle) * radius / thickness)
			local cy = math.round(math.sin(angle) * radius / thickness)
			local key = `{cx},{cy}`
			if not seen[key] then
				seen[key] = true
				make.block(Vector3.one * thickness, color, material, at * CFrame.new(cx * thickness, cy * thickness, 0))
			end
		end
		return
	end
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
			CFrame.new(0, 0.1 - (index - 1) * 0.18, front - 0.03)
				* CFrame.Angles(0, 0, if STEPS.on then 0 else math.rad(45))
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
		CFrame.new(-hipWidth * 0.32, -0.16, beltFront - 0.04) * CFrame.Angles(0, 0, if STEPS.on then 0 else 0.15)
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
	if STEPS.on then
		mageDetail(body, {
			main = WOVEN_FIBER,
			dark = DYE_PURPLE,
			accent = BEAD_TEAL,
			material = FABRIC,
			frontZ = 0.17,
			backZ = 0.15,
			padY = 0.18,
			padWide = 0.4,
			padStud = 0.28,
			fringeZ = 0.36,
			fringeY = 0.02,
		})
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
			center
				* CFrame.new(side * arm.size.X * 0.1, 0.3, 0)
				* CFrame.Angles(0, if STEPS.on then math.pi else -side * math.rad(30), 0),
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
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.05))
			* CFrame.Angles(if STEPS.on then 0 else 0.1, 0, 0)
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
	if STEPS.on then
		mageDetail(body, {
			main = MAGE_INDIGO,
			dark = MAGE_INDIGO_DARK,
			accent = GOLD_TRIM,
			material = FABRIC,
			frontZ = 0.12,
			backZ = 0.12,
			padY = 0.18,
			padWide = 0.4,
			padStud = 0.28,
			fringeZ = 0.36,
			fringeY = 0.02,
		})
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
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06))
			* CFrame.Angles(if STEPS.on then 0 else 0.1, 0, 0)
		leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.4, 0.1), SILVER_FUR, FABRIC, flap)
		leg.block(Vector3.new(0.06, ls.Y * 0.26, 0.04), RUNE, NEON, flap * CFrame.new(0, 0, -0.07))
		local flapHem =
			leg.block(Vector3.new(ls.X * 0.9 + 0.04, 0.07, 0.12), SILVER, METAL, flap * CFrame.new(0, -ls.Y * 0.2, 0))
		flapHem.Reflectance = 0.25
		crystal(leg, (flap * CFrame.new(0, -ls.Y * 0.2 - 0.03, -0.06)).Position, Vector3.new(0, -1, -0.1), 0.26, 0.12)
	end
	if STEPS.on then
		mageDetail(body, {
			main = SILVER_FUR,
			dark = SILVER_FUR_DARK,
			accent = CRYSTAL,
			material = FABRIC,
			frontZ = 0.12,
			backZ = 0.235,
			padY = 0.46,
			padWide = 0.1,
			padStud = 0.17,
			fringeZ = 0.25,
			fringeY = 0.09,
		})
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
			at * CFrame.new(x * scale, y * scale, z * scale) * CFrame.Angles(0, 0, if STEPS.on then 0 else tilt or 0)
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
		if STEPS.on then
			local zz = 0.02 * (index % 2)
			stairs(
				make,
				(tie * CFrame.new(0, 0.05, zz)).Position,
				(tie * CFrame.new(math.sin(angle) * (length + 0.05), math.cos(angle) * (length + 0.05), zz)).Position,
				0.56,
				0.05,
				greens[index % 3 + 1],
				SMOOTH,
				math.max(4, math.round(length / 0.18))
			)
			continue
		end
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
			tie * CFrame.Angles(0, 0, if STEPS.on then 0 else index * 0.25) * CFrame.new(0, -0.2, 0.03)
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
	waist.rod(
		0.38,
		0.08,
		BONE,
		SMOOTH,
		mortar * CFrame.new(0.06, 0.22, 0) * CFrame.Angles(0, 0, math.rad(if STEPS.on then 90 else 70))
	)

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
	if STEPS.on then
		mageDetail(body, {
			main = LINEN,
			dark = LEATHER,
			accent = PAINT_WHITE,
			material = FABRIC,
			frontZ = 0.1,
			backZ = 0.1,
			padY = 0.18,
			padWide = 0.4,
			padStud = 0.28,
			fringeZ = 0.36,
			fringeY = 0.02,
		})
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
	if STEPS.on then
		mageDetail(body, {
			main = BONE,
			dark = BONE_DARK,
			accent = LEATHER,
			material = SMOOTH,
			frontZ = 0.12,
			backZ = 0.14,
			padY = 0.18,
			padWide = 0.4,
			padStud = 0.28,
			fringeZ = 0.36,
			fringeY = 0.02,
		})
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
		local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06))
			* CFrame.Angles(if STEPS.on then 0 else 0.1, 0, 0)
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
	if STEPS.on then
		mageDetail(body, {
			main = SILVER_FUR,
			dark = SILVER_FUR_DARK,
			accent = PAINT_WHITE,
			material = FABRIC,
			frontZ = 0.13,
			backZ = 0.23,
			padY = 0.46,
			padWide = 0.1,
			padStud = 0.17,
			fringeZ = 0.25,
			fringeY = 0.09,
		})
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
local function lavaPauldron(
	arm: Builder,
	side: number,
	pad: Color3,
	padMaterial: Enum.Material,
	spikes: string,
	rich: boolean?
)
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
			-- Garra en tres escalones hacia fuera y arriba (sin giro).
			for step = 0, 2 do
				arm.block(
					Vector3.one * (0.16 - step * 0.04),
					OBSIDIAN,
					SMOOTH,
					CFrame.new(side * (as.X * 0.55 + step * 0.13), top + 0.2 + step * 0.13, z * as.Z)
				)
			end
		end
	end
	if rich then
		-- Más detalle (el guerrero): remaches de basalto en las cuatro esquinas de la losa, brillo de obsidiana y vetas de
		-- ceniza pintados en el escalón, vetas de lava pintadas en los costados de la losa y una fila de púas de obsidiana
		-- (en escalones, sin giro) por el borde de fuera.
		for _, corner in { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1) } do
			arm.block(
				Vector3.one * 0.1,
				BASALT_DARK,
				BASALT_MATERIAL,
				CFrame.new(cx + corner.X * (as.X / 2 + 0.13), top + 0.36, corner.Z * (as.Z / 2 + 0.13))
			)
		end
		for strip = -2, 2 do
			arm.block(
				Vector3.new(as.X + 0.06, 0.03, 0.06),
				if strip % 2 == 0 then OBSIDIAN_SHEEN else ASH_DARK,
				SMOOTH,
				CFrame.new(cx, top + 0.455, strip * (as.Z + 0.1) * 0.2)
			)
		end
		for _, face in { -1, 1 } do
			for vein = -1, 1 do
				arm.block(
					Vector3.new(0.05, 0.14, 0.03),
					MAGMA,
					SMOOTH,
					CFrame.new(cx + vein * (as.X + 0.42) * 0.3, top + 0.2, face * (as.Z / 2 + 0.21))
				)
			end
		end
		for _, z in { -0.42, -0.22, 0.22, 0.42 } do
			spire(
				arm,
				cx + side * (as.X / 2 + 0.1),
				top + 0.3,
				z * as.Z,
				0.12,
				0.3,
				0.12,
				OBSIDIAN,
				SMOOTH,
				side * 0.12
			)
		end
		-- Brasero: cuatro muros bajos de basalto oscuro alrededor del pie de la llama, con el borde de arriba de lava
		-- pintada en los dos de los lados.
		local hearth = 0.36
		for _, wall in { -1, 1 } do
			arm.block(
				Vector3.new(hearth * 2 + 0.1, 0.12, 0.1),
				BASALT_DARK,
				BASALT_MATERIAL,
				CFrame.new(side * 0.04, stepTop + 0.06, wall * hearth)
			)
			arm.block(
				Vector3.new(0.1, 0.12, hearth * 2 - 0.1),
				BASALT_DARK,
				BASALT_MATERIAL,
				CFrame.new(side * 0.04 + wall * hearth, stepTop + 0.06, 0)
			)
			arm.block(
				Vector3.new(0.04, 0.03, hearth * 2 - 0.1),
				MAGMA,
				SMOOTH,
				CFrame.new(side * 0.04 + wall * hearth, stepTop + 0.115, 0)
			)
		end
		-- Faldones de basalto que cuelgan por delante y por detrás de la losa, con el borde de lava pintado, una veta de
		-- ceniza y el bajo en mechones de obsidiana; y tres púas sobre cada uno de esos bordes de la losa.
		for _, face in { -1, 1 } do
			local fz = face * (as.Z / 2 + 0.2)
			for k = -1, 1 do
				local fx = cx + k * 0.36
				arm.block(Vector3.new(0.3, 0.22, 0.08), BASALT, BASALT_MATERIAL, CFrame.new(fx, top - 0.14, fz))
				arm.block(Vector3.new(0.3, 0.03, 0.09), MAGMA, SMOOTH, CFrame.new(fx, top - 0.26, fz))
				arm.block(Vector3.new(0.04, 0.12, 0.03), ASH_DARK, SMOOTH, CFrame.new(fx, top - 0.14, fz + face * 0.04))
				tuft(arm, fx, top - 0.27, fz, 0.26, 0.16, 0.08, OBSIDIAN, SMOOTH)
				spire(arm, fx, top + 0.31, face * (as.Z / 2 + 0.13), 0.14, 0.22, 0.1, OBSIDIAN, SMOOTH)
			end
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
	local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.2, -(ls.Z / 2 + 0.06))
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
		-- Púa de obsidiana en escalones (sin giro), inclinada hacia fuera con el desplazamiento de cada escalón.
		spire(
			make,
			math.sin(angle) * width * 0.3,
			height / 2 - 0.04,
			-math.cos(angle) * depth * 0.42,
			0.22,
			if index == 3 then 0.3 else 0.38,
			0.22,
			OBSIDIAN,
			SMOOTH,
			math.sin(angle) * 0.1
		)
	end
	for side = -1, 1, 2 do
		local pec = CFrame.new(side * (width * 0.23 + 0.02), height * 0.2, front - 0.07)
		lavaPlate(make, Vector3.new(width * 0.4, height * 0.28, 0.1), pec)
		make.block(
			Vector3.new(width * 0.1, height * 0.18, 0.04),
			OBSIDIAN_SHEEN,
			SMOOTH,
			pec * CFrame.new(-side * width * 0.1, 0.02, -0.06)
		)
		make.block(
			Vector3.one * 0.1,
			BASALT,
			BASALT_MATERIAL,
			pec * CFrame.new(side * width * 0.14, -height * 0.09, -0.06)
		)
		-- Más detalle: una placa interior de basalto oscuro con tres surcos de lava pintados, y cuatro remaches en las
		-- esquinas del pectoral.
		make.block(
			Vector3.new(width * 0.32, height * 0.2, 0.05),
			BASALT_DARK,
			BASALT_MATERIAL,
			pec * CFrame.new(0, 0.01, -0.08)
		)
		for _, groove in { -0.06, 0, 0.06 } do
			make.block(
				Vector3.new(width * 0.26, 0.03, 0.03),
				MAGMA,
				SMOOTH,
				pec * CFrame.new(0, groove * height, -0.105)
			)
		end
		for _, corner in { Vector3.new(1, 1, 0), Vector3.new(1, -1, 0), Vector3.new(-1, 1, 0), Vector3.new(-1, -1, 0) } do
			make.block(
				Vector3.one * 0.08,
				OBSIDIAN_SHEEN,
				SMOOTH,
				pec * CFrame.new(corner.X * width * 0.185, corner.Y * height * 0.115, -0.08)
			)
		end
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
			-- Veta de ceniza y remache pintados en cada placa del vientre.
			make.block(
				Vector3.new(0.03, height * 0.09, 0.03),
				ASH_DARK,
				SMOOTH,
				plate * CFrame.new(side * plateWidth * 0.18, 0, -0.05)
			)
			make.block(Vector3.one * 0.06, MAGMA, SMOOTH, plate * CFrame.new(-side * plateWidth * 0.3, 0, -0.05))
		end
	end
	-- Clavícula de obsidiana sobre el pecho, con cinco púas pequeñas en escalones.
	make.block(Vector3.new(width * 0.86, 0.1, 0.1), OBSIDIAN, SMOOTH, CFrame.new(0, height * 0.455, front - 0.04))
	for index = -2, 2 do
		spire(make, index * width * 0.18, height * 0.455 + 0.05, front - 0.04, 0.12, 0.2, 0.08, OBSIDIAN, SMOOTH)
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
	-- Cuatro garras iguales en las diagonales: un taco pegado al pecho y una punta que muerde el aro por delante.
	for _, diagonal in { Vector3.new(1, 1, 0), Vector3.new(-1, 1, 0), Vector3.new(1, -1, 0), Vector3.new(-1, -1, 0) } do
		make.block(
			Vector3.new(0.16, 0.16, 0.16),
			OBSIDIAN,
			SMOOTH,
			core * CFrame.new(diagonal * 0.27 + Vector3.new(0, 0, 0.08))
		)
		make.block(
			Vector3.new(0.12, 0.12, 0.1),
			OBSIDIAN,
			SMOOTH,
			core * CFrame.new(diagonal * 0.2 + Vector3.new(0, 0, -0.06))
		)
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
		-- Laderas: la roca que rellena a cada lado del volcán hasta el marco (más ancha cuanto más alto el escalón), con
		-- una veta de lava y una veta de ceniza pintadas.
		if tier >= 2 then
			local gap = width * 0.49 - tierWidth / 2
			for side = -1, 1, 2 do
				local cliffX = side * (tierWidth / 2 + gap / 2)
				local cliffY = baseY + (tier - 0.5) * tierHeight
				make.block(
					Vector3.new(gap - 0.03, tierHeight, 0.06),
					if tier % 2 == 0 then ASH_DARK else BASALT,
					BASALT_MATERIAL,
					CFrame.new(cliffX, cliffY, plateZ + 0.1)
				)
				make.block(
					Vector3.new(0.04, tierHeight * 0.8, 0.03),
					MAGMA,
					SMOOTH,
					CFrame.new(cliffX - side * gap * 0.12, cliffY, plateZ + 0.13)
				)
				make.block(
					Vector3.new(0.03, tierHeight * 0.5, 0.03),
					ASH_DARK,
					SMOOTH,
					CFrame.new(cliffX + side * gap * 0.2, cliffY + tierHeight * 0.1, plateZ + 0.13)
				)
			end
		end
		-- Dos rocas de basalto en el borde del escalón, una mayor que la otra según el lado.
		if tier < tiers then
			for side = -1, 1, 2 do
				local big = (tier % 2 == 0) == (side == 1)
				make.block(
					Vector3.new(if big then 0.22 else 0.14, if big then 0.14 else 0.1, 0.12),
					ASH_DARK,
					BASALT_MATERIAL,
					CFrame.new(side * (tierWidth / 2 - 0.12), baseY + tier * tierHeight + 0.02, tierFront(tier) - 0.04)
				)
			end
		end
		-- Brillo de obsidiana y vetas de ceniza pintados en la cara del escalón (relieve casi gratis en la malla).
		for _, at in { 0.2, 0.72 } do
			make.block(
				Vector3.new(tierWidth * (0.7 - at * 0.2), 0.035, 0.03),
				if tier % 2 == 0 then ASH_DARK else OBSIDIAN_SHEEN,
				SMOOTH,
				CFrame.new(
					(if tier % 2 == 0 then 0.06 else -0.06) * at,
					baseY + (tier - 1 + at) * tierHeight,
					tierFront(tier)
				)
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
	-- Rocas al pie del volcán, en el borde del lago de lava, y brasas sueltas que suben del cráter.
	for rock = -3, 3 do
		make.block(
			Vector3.new(0.2 + 0.06 * (rock % 2), 0.1 + 0.04 * (rock % 3), 0.1),
			if rock % 2 == 0 then ASH_DARK else BASALT,
			BASALT_MATERIAL,
			CFrame.new(rock * width * 0.13, baseY + 0.06, tierFront(1) + 0.07)
		)
	end
	for index, ember in
		{
			Vector3.new(-0.3, 0.62, 0.05),
			Vector3.new(-0.08, 0.78, 0.1),
			Vector3.new(0.2, 0.7, 0.02),
			Vector3.new(0.34, 0.5, 0.08),
		}
	do
		make.block(
			Vector3.one * (0.05 + 0.01 * (index % 2)),
			EMBER,
			NEON,
			CFrame.new(ember.X, craterY + ember.Y, craterZ + ember.Z)
		)
	end
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

	-- Manto de ceniza sobre los hombros, por detrás: una losa de basalto con vetas de obsidiana y lava pintadas, y el bajo
	-- en mechones de tres escalones (las puntas de los cristales de la corona salen de él).
	local mantleY = height * 0.43
	local mantleZ = plateZ + 0.06
	make.block(
		Vector3.new(width * 0.96, height * 0.17, 0.12),
		ASH_DARK,
		BASALT_MATERIAL,
		CFrame.new(0, mantleY, mantleZ)
	)
	for strand = 0, 7 do
		make.block(
			Vector3.new(0.07, height * 0.12, 0.03),
			if strand % 2 == 0 then OBSIDIAN else OBSIDIAN_SHEEN,
			SMOOTH,
			CFrame.new((strand - 3.5) * width * 0.115, mantleY, mantleZ + 0.075)
		)
	end
	for tip = 0, 4 do
		tuft(
			make,
			(tip - 2) * width * 0.2,
			mantleY - height * 0.085,
			mantleZ,
			0.28,
			0.14,
			0.12,
			if tip % 2 == 0 then OBSIDIAN else BASALT_DARK,
			BASALT_MATERIAL
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
		lavaPauldron(arm, side, BASALT, BASALT_MATERIAL, "shard", true)
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
	stairs(make, crossFrom, crossTo, 0.14, 0.14, BASALT_DARK, LEATHER_MATERIAL, 10)
	for _, t in { 0.25, 0.5, 0.75 } do
		local stud = crossFrom:Lerp(crossTo, t)
		make.block(Vector3.one * 0.12, OBSIDIAN, SMOOTH, CFrame.new(stud.X, stud.Y, stud.Z - 0.08))
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
	stairs(make, neckLeft, bottom, 0.04, 0.04, FIBER, FABRIC, 4)
	stairs(make, bottom, neckRight, 0.04, 0.04, FIBER, FABRIC, 4)
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

	-- Brillo de obsidiana y vetas de ceniza pintados en el manto de los hombros, y pespuntes a los lados del jubón.
	for strip = -2, 2 do
		make.block(
			Vector3.new(width + 0.06, 0.035, 0.07),
			if strip % 2 == 0 then OBSIDIAN_SHEEN else ASH_DARK,
			SMOOTH,
			CFrame.new(0, height / 2 + 0.235, 0.06 + strip * (depth + 0.14) * 0.19)
		)
	end
	for dash = 0, 4 do
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.035, height * 0.09, 0.03),
				ASH_DARK,
				LEATHER_MATERIAL,
				CFrame.new(side * width * 0.4, -height * 0.34 + dash * height * 0.12, front + 0.01)
			)
		end
	end

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
		local ear = (hood * CFrame.new(side * 0.42, 0.3, -0.05)).Position
		spire(make, ear.X, ear.Y, ear.Z, 0.22, 0.34, 0.18, BASALT_DARK, FABRIC, side * 0.06)
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
	local knife = CFrame.new(-hipWidth * 0.34, -0.05, beltFront - 0.04)
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
		lavaPauldron(arm, side, ASH, FABRIC, "claw", true)
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
		lavaPauldron(arm, side, LAVA_ROBE_DARK, FABRIC, "crystal", STEPS.on)
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
	if STEPS.on then
		mageDetail(body, {
			main = LAVA_ROBE,
			dark = LAVA_ROBE_DARK,
			accent = MAGMA,
			material = SMOOTH,
			frontZ = 0.125,
			backZ = 0.19,
			padY = nil,
			padWide = 0.4,
			padStud = 0.28,
			fringeZ = 0.36,
			fringeY = 0.02,
		})
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
		lavaPauldron(arm, side, ASH, FABRIC, "sulfur", STEPS.on)
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
	if STEPS.on then
		mageDetail(body, {
			main = ASH,
			dark = BASALT_DARK,
			accent = SULFUR,
			material = SMOOTH,
			frontZ = 0.13,
			backZ = 0.35,
			padY = nil,
			padWide = 0.4,
			padStud = 0.28,
			fringeZ = 0.36,
			fringeY = 0.02,
		})
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

-- Runa o gema plana (un óvalo fino de "size" de ancho) en el plano XY de "at", mirando a su -Z.
local function rune(make: Builder, at: CFrame, color: Color3, material: Enum.Material, size: number?): BasePart
	local wide = size or 0.12
	return make.oval(Vector3.new(wide, wide * 1.3, 0.04), color, material, at)
end

-- Cabeza de gorila de piedra hecha solo de bloques alineados con los ejes (sin óvalos ni giros, así entra en la malla),
-- mirando a la -Z de "at": "size" studs de ancho y "depth" veces su fondo (en relieve sobre el peto, plana; el ídolo,
-- entera). Cráneo con cresta, orejas, cejas de furia en dos escalones, cara hundida, hocico, boca y colmillos de oro.
-- Con "simple" (las hombreras) sin cresta, orejas ni fosas. Devuelve los ojos (de "eye" y "eyeMaterial").
local function titanFace(
	make: Builder,
	at: CFrame,
	size: number,
	depth: number,
	eye: Color3,
	eyeMaterial: Enum.Material,
	simple: boolean
): { BasePart }
	local function put(
		w: number,
		h: number,
		d: number,
		x: number,
		y: number,
		z: number,
		color: Color3,
		material: Enum.Material
	)
		make.block(
			Vector3.new(w * size, h * size, d * size * depth),
			color,
			material,
			at * CFrame.new(x * size, y * size, z * size * depth)
		)
	end
	put(0.96, 0.9, 0.5, 0, 0, 0.1, TITAN_STONE, SLATE)
	put(0.8, 0.52, 0.24, 0, -0.12, -0.14, TITAN_STONE_DARK, SLATE)
	put(0.46, 0.2, 0.14, 0, -0.1, -0.28, TITAN_STONE, SLATE)
	put(0.44, 0.05, 0.04, 0, -0.32, -0.27, TITAN_CARVING, SMOOTH)
	if not simple then
		put(0.5, 0.3, 0.4, 0, 0.55, 0.14, TITAN_STONE, SLATE)
	end
	local eyes = {}
	for side = -1, 1, 2 do
		-- Cejas en dos escalones: la de fuera más alta y la de dentro más baja (la furia).
		put(0.34, 0.12, 0.2, side * 0.27, 0.2, -0.2, TITAN_STONE, SLATE)
		put(0.2, 0.12, 0.2, side * 0.1, 0.13, -0.2, TITAN_STONE, SLATE)
		table.insert(
			eyes,
			make.ball(
				0.15 * size,
				eye,
				eyeMaterial,
				at * CFrame.new(side * 0.17 * size, 0.05 * size, -0.34 * size * depth - 0.05)
			)
		)
		put(0.07, 0.14, 0.06, side * 0.13, -0.37, -0.28, TITAN_GOLD, SMOOTH)
		if not simple then
			put(0.14, 0.3, 0.18, side * 0.55, 0.02, 0.06, TITAN_STONE_DARK, SLATE)
			put(0.06, 0.05, 0.04, side * 0.09, -0.15, -0.34, TITAN_CARVING, SMOOTH)
		end
	end
	return eyes
end

-- Hombrera del Rey Gorila (grado 1+): tres láminas de piedra escalonadas (más anchas y más bajas hacia fuera) con el
-- canto de oro, una cresta de piedra en dos mitades con la cabeza de gorila entre ellas mirando hacia fuera y tachones
-- de oro y gemas de jade. Todo en bloques alineados, sin giros. Por grados: 1, lo anterior; 2, flecos de oro bajo la
-- lámina de abajo y dos cristales de jade sobre la cresta; 3, ojos de sol encendidos, colmillo de oro hacia fuera y una
-- aleta de piedra detrás con raya de oro y tres gemas (lo que se ve de espaldas); 4, tres cristales de jade que salen
-- por detrás de la cabeza y una chispa de sol.
local function titanPauldron(arm: Builder, side: number, grade: number)
	local as = arm.size
	local top = as.Y / 2
	local W, D = as.X, as.Z
	local lit = grade >= 3
	local lames = {
		{ w = 1.3, depth = 1.4, y = 0.3, out = 0.04, color = TITAN_STONE },
		{ w = 1.55, depth = 1.5, y = 0.1, out = 0.14, color = TITAN_STONE_DARK },
		{ w = 1.8, depth = 1.6, y = -0.1, out = 0.26, color = TITAN_STONE },
	}
	for _, lame in lames do
		local at = CFrame.new(side * lame.out, top + lame.y, 0)
		local size = Vector3.new(W * lame.w, 0.2, D * lame.depth)
		arm.block(size, lame.color, SLATE, at)
		arm.block(Vector3.new(size.X + 0.06, 0.06, size.Z + 0.06), TITAN_GOLD, SMOOTH, at * CFrame.new(0, -0.12, 0))
	end
	-- Cresta: dos mitades de piedra con el borde de oro, una a cada lado de la cabeza.
	local crest = CFrame.new(side * 0.1, top + 0.58, 0)
	for sz = -1, 1, 2 do
		arm.block(Vector3.new(0.24, 0.3, D * 0.5), TITAN_STONE_DARK, SLATE, crest * CFrame.new(0, 0, sz * D * 0.7))
		arm.block(Vector3.new(0.14, 0.08, D * 0.4), TITAN_GOLD, SMOOTH, crest * CFrame.new(0, 0.18, sz * D * 0.7))
	end
	-- La cabeza mira hacia fuera, hundida entre las dos mitades de la cresta.
	titanFace(
		arm,
		CFrame.new(side * W * 0.3, top + 0.62, 0) * CFrame.Angles(0, -side * math.pi / 2, 0),
		0.8,
		0.7,
		if lit then SUN_GLOW else JADE,
		if lit then NEON else SMOOTH,
		true
	)
	-- Tachones de oro en las esquinas de la lámina de arriba y dos gemas de jade en el canto de fuera.
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			arm.ball(0.1, TITAN_GOLD, SMOOTH, CFrame.new(side * 0.04 + sx * W * 0.62, top + 0.44, sz * D * 0.66))
		end
	end
	for sz = -1, 1, 2 do
		arm.ball(0.12, JADE, SMOOTH, CFrame.new(side * (0.26 + W * 0.9 + 0.02), top - 0.1, sz * D * 0.3))
	end
	-- Grado 2: flecos de oro bajo la lámina de abajo y dos cristales de jade sobre la cresta.
	if grade >= 2 then
		for index = -2, 2 do
			arm.block(
				Vector3.new(0.14, 0.34 - math.abs(index) * 0.06, 0.1),
				TITAN_GOLD_DARK,
				SMOOTH,
				CFrame.new(side * (0.26 + W * 0.78), top - 0.2 - (0.34 - math.abs(index) * 0.06) / 2, index * D * 0.34)
			)
		end
		for sz = -1, 1, 2 do
			spire(arm, side * 0.1, top + 0.76, sz * D * 0.7, 0.22, 0.6, 0.22, JADE, SMOOTH, 0)
		end
	end
	-- Grado 3: colmillo de oro en tres escalones hacia fuera y aleta de piedra detrás, con raya de oro y tres gemas.
	if grade >= 3 then
		for index = 0, 2 do
			arm.block(
				Vector3.new(0.22, 0.32 - index * 0.09, 0.32 - index * 0.09),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * (0.26 + W * 0.9 + 0.1 + index * 0.17), top + 0.02 + index * 0.06, 0)
			)
		end
		local fin = CFrame.new(side * 0.2, top + 0.18, D * 0.95)
		arm.block(Vector3.new(W * 1.3, 0.6, 0.1), TITAN_STONE_DARK, SLATE, fin)
		arm.block(Vector3.new(W * 1.1, 0.06, 0.12), TITAN_GOLD, SMOOTH, fin * CFrame.new(0, 0.12, 0.01))
		for _, x in { -0.4, 0, 0.4 } do
			arm.ball(0.1, JADE, SMOOTH, fin * CFrame.new(x * W, -0.12, 0.08))
		end
	end
	-- Grado 4: tres cristales de jade detrás de la cabeza (de dentro, para que se vean desde atrás) y una chispa de sol.
	if grade >= 4 then
		for _, z in { -0.4, 0, 0.4 } do
			local tall = if z == 0 then 1 else 0.72
			spire(arm, -side * W * 0.12, top + 0.4, z * D, 0.2, tall, 0.2, JADE, SMOOTH, 0)
		end
		arm.ball(0.1, SUN_GLOW, NEON, CFrame.new(-side * W * 0.12, top + 1.5, 0))
	end
end

-- Traje mítico del guerrero, Rey Gorila Titán. Todo en bloques alineados con los ejes (sin giros) para que el grado 4
-- pueda llevar malla; los grados 0 a 3 usan el mismo diseño y ganan piezas. Grado 0: túnica roja, peto de piedra con
-- ribete de oro y la cara de un gorila en relieve entre costillas de oro, gorguera de oro con cuentas de jade, vientre
-- de placas con tachones, estela de piedra en la espalda con un sol de oro y centro de jade, cinturón con hebilla de
-- jade y taparrabos rojo con ribete de oro y lengüeta de jade delante y detrás, brazaletes y muñequeras de oro y piedra.
-- Grado 1: hombreras con la cabeza de gorila entre dos láminas de cresta, runas y gemas en el peto, el cinturón y los
-- antebrazos, manguitos de pelaje, grebas de piedra en los muslos y, en la espalda, el sol con doce rayos (cada grado
-- tiene su motivo en la espalda). Grado 2: manto y capa de pelaje negro con flecos, runas en los cantos, una calavera de
-- gorila dorada con un halo de rayos de oro y jade, broches con cadenas y faldones de piedra en los muslos. Grado 3: el
-- lomo plateado sale alrededor del ídolo, un busto de gorila de piedra enorme entre los omoplatos con ojos de sol que
-- brillan, corona de oro con jade, melena y collar; púas en las muñecas y rodilleras de oro.
-- Grado 4: aro solar de oro con rayos y cuatro cristales de jade detrás del ídolo (queda como un halo detrás de la
-- cabeza), lianas con orquídeas colgando de él, más cristales en las hombreras y motas de sol que suben.
-- Lo único que no entra en la malla es el neón (los ojos de las cabezas, las gemas del sol, la chispa) y lo que lleva luz
-- o partículas. Lo de delante va 0,1 más adelantado para que no quede enterrado con un avatar ancho y hondo.
local function titanKing(body: Body, grade: number)
	local make = body.torso
	local width, height, depth = make.size.X, make.size.Y, make.size.Z
	local front = -(depth / 2 + 0.18)
	local base = depth / 2
	local back = base + 0.08
	local lit = grade >= 3
	local runeColor = if lit then TITAN_GOLD else TITAN_GOLD_DARK
	local eye = if lit then SUN_GLOW else JADE
	local eyeMaterial = if lit then NEON else SMOOTH
	local fur = if lit then SILVER_FUR_DARK else GORILLA_FUR
	local capeHeight = height * 1.2
	local capeTop = height / 2 - 0.05
	local capeBottom = capeTop - capeHeight
	local capeZ = base + 0.22
	local idolSize = 1.4
	local idolY = height * 0.05

	make.block(
		Vector3.new(width + 0.1, height * 0.92, depth + 0.3),
		ROYAL_RED,
		FABRIC,
		CFrame.new(0, -height * 0.03, 0)
	)

	-- Peto: dos pectorales de piedra con el borde de abajo de oro y una placa oscura encima y, entre ellos, el esternón
	-- de piedra oscura con costillas de oro y la cara del gorila en relieve.
	for side = -1, 1, 2 do
		local pec = CFrame.new(side * width * 0.25, height * 0.2, front)
		make.block(Vector3.new(width * 0.44, height * 0.32, 0.1), TITAN_STONE, SLATE, pec)
		make.block(
			Vector3.new(width * 0.44, 0.07, 0.12),
			TITAN_GOLD,
			SMOOTH,
			pec * CFrame.new(0, -height * 0.16, -0.01)
		)
		make.block(
			Vector3.new(width * 0.34, height * 0.2, 0.05),
			TITAN_STONE_DARK,
			SLATE,
			pec * CFrame.new(0, 0.02, -0.07)
		)
	end
	local plate = CFrame.new(0, height * 0.1, front - 0.06)
	make.block(Vector3.new(width * 0.42, height * 0.52, 0.14), TITAN_STONE_DARK, SLATE, plate)
	for _, y in { height * 0.26, -height * 0.26 } do
		make.block(Vector3.new(width * 0.46, 0.08, 0.16), TITAN_GOLD, SMOOTH, plate * CFrame.new(0, y, -0.01))
	end
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.06, height * 0.44, 0.16),
			TITAN_GOLD,
			SMOOTH,
			plate * CFrame.new(side * width * 0.2, 0, -0.01)
		)
	end
	titanFace(make, plate * CFrame.new(0, -0.02, -0.07), 0.74, 0.35, eye, eyeMaterial, false)

	-- Gorguera de oro con cuentas de jade: siete placas en arco alrededor del cuello, sin giros (las de los lados más
	-- atrás).
	for k = -3, 3 do
		local z = -(depth / 2 + 0.12) + math.abs(k) * 0.08
		make.block(
			Vector3.new(0.28, 0.14, 0.16),
			TITAN_GOLD,
			SMOOTH,
			CFrame.new(k * width * 0.13, height / 2 - 0.02, z)
		)
		if k < 3 then
			make.ball(0.15, JADE, SMOOTH, CFrame.new((k + 0.5) * width * 0.13, height / 2 - 0.05, z + 0.04 - 0.07))
		end
	end

	-- Vientre de placas de piedra con tachones de oro y, entre ellas, el espinazo de oro con una gema de jade.
	for row = 0, 1 do
		for side = -1, 1, 2 do
			local at = CFrame.new(side * width * 0.2, -height * 0.21 - row * height * 0.15, front)
			make.block(Vector3.new(width * 0.36, height * 0.12, 0.1), TITAN_STONE_DARK, SLATE, at)
			make.ball(0.08, TITAN_GOLD, SMOOTH, at * CFrame.new(0, 0, -0.06))
		end
	end
	make.block(Vector3.new(0.1, 0.24, 0.08), TITAN_GOLD, SMOOTH, CFrame.new(0, -height * 0.28, front - 0.02))
	make.ball(0.12, JADE, SMOOTH, CFrame.new(0, -height * 0.28, front - 0.08))

	-- Espalda: estela de piedra con cantos de oro y un sol de oro con el centro de jade y cuatro rayos.
	make.block(Vector3.new(width * 0.88, height * 0.86, 0.12), TITAN_STONE, SLATE, CFrame.new(0, -height * 0.02, back))
	for side = -1, 1, 2 do
		make.block(
			Vector3.new(0.08, height * 0.86, 0.14),
			TITAN_GOLD,
			SMOOTH,
			CFrame.new(side * width * 0.44, -height * 0.02, back + 0.01)
		)
	end
	local sun = CFrame.new(0, -height * 0.1, back + 0.07)
	make.block(Vector3.new(0.4, 0.4, 0.06), TITAN_GOLD, SMOOTH, sun)
	make.ball(0.22, JADE, SMOOTH, sun * CFrame.new(0, 0, 0.05))
	for _, dir in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
		make.block(
			Vector3.new(0.1 + math.abs(dir[1]) * 0.18, 0.1 + math.abs(dir[2]) * 0.18, 0.05),
			TITAN_GOLD,
			SMOOTH,
			sun * CFrame.new(dir[1] * 0.38, dir[2] * 0.38, 0.02)
		)
	end

	-- Cinturón de piedra con banda de oro, hebilla de jade y taparrabos rojo con ribete de oro y lengüeta de jade.
	local waist = body.waist
	local hipWidth, hipDepth = waist.size.X, waist.size.Z
	local beltFront = -(hipDepth / 2 + 0.17)
	waist.block(Vector3.new(hipWidth + 0.16, 0.26, hipDepth + 0.34), TITAN_STONE_DARK, SLATE, CFrame.new(0, 0.04, 0))
	waist.block(Vector3.new(hipWidth + 0.18, 0.06, hipDepth + 0.36), TITAN_GOLD, SMOOTH, CFrame.new(0, 0.15, 0))
	waist.block(Vector3.new(0.44, 0.3, 0.08), TITAN_GOLD, SMOOTH, CFrame.new(0, 0.04, beltFront - 0.02))
	waist.block(Vector3.new(0.22, 0.18, 0.06), JADE, SMOOTH, CFrame.new(0, 0.04, beltFront - 0.08))
	for _, face in { { beltFront + 0.02, -1 }, { -beltFront - 0.02, 1 } } do
		waist.block(Vector3.new(hipWidth * 0.4, 0.6, 0.06), ROYAL_RED, FABRIC, CFrame.new(0, -0.38, face[1]))
		waist.block(Vector3.new(hipWidth * 0.42, 0.06, 0.08), TITAN_GOLD, SMOOTH, CFrame.new(0, -0.66, face[1]))
		waist.block(Vector3.new(0.16, 0.2, 0.05), JADE, SMOOTH, CFrame.new(0, -0.42, face[1] + face[2] * 0.05))
	end

	-- Brazaletes y muñequeras de oro con jade, y el brazal de piedra del antebrazo.
	for side = -1, 1, 2 do
		local upper = body.upperArm[side]
		local us = upper.size
		band(upper, -us.Y * 0.2, 0.12, 0.08, TITAN_GOLD, SMOOTH)
		band(upper, -us.Y * 0.38, 0.1, 0.12, TITAN_STONE_DARK, SLATE)
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
		band(forearm, fs.Y * 0.12, fs.Y * 0.34, 0.12, TITAN_STONE_DARK, SLATE)
		for _, y in { fs.Y * 0.3, -fs.Y * 0.05 } do
			band(forearm, y, 0.05, 0.16, TITAN_GOLD, SMOOTH)
		end
		if grade >= 1 then
			titanPauldron(upper, side, grade)
		end
	end

	-- Grado 1: runas y gemas por el peto, el vientre, el cinturón, los brazos y los muslos.
	if grade >= 1 then
		for side = -1, 1, 2 do
			for _, x in { 0.15, 0.25, 0.35 } do
				rune(make, CFrame.new(side * width * x, height * 0.24, front - 0.11), runeColor, SMOOTH)
			end
			for _, y in { 0.32, -0.12 } do
				make.ball(0.12, JADE, SMOOTH, CFrame.new(side * width * 0.34, height * (0.1 + y), front - 0.1))
			end
			for row = 0, 1 do
				rune(
					make,
					CFrame.new(side * width * 0.32, -height * 0.21 - row * height * 0.15, front - 0.07),
					runeColor,
					SMOOTH,
					0.1
				)
			end
			for _, x in { 0.2, 0.32, 0.44 } do
				rune(waist, CFrame.new(side * hipWidth * x, 0.04, beltFront - 0.03), runeColor, SMOOTH, 0.1)
			end

			-- Placa de piedra con banda de oro y dos tachones en cada cadera.
			waist.block(
				Vector3.new(0.12, 0.24, hipDepth * 0.6),
				TITAN_STONE_DARK,
				SLATE,
				CFrame.new(side * (hipWidth / 2 + 0.1), 0.04, 0)
			)
			waist.block(
				Vector3.new(0.14, 0.06, hipDepth * 0.62),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * (hipWidth / 2 + 0.1), -0.06, 0)
			)
			for _, z in { -0.18, 0.18 } do
				waist.ball(0.1, TITAN_GOLD, SMOOTH, CFrame.new(side * (hipWidth / 2 + 0.17), 0.06, z))
			end

			-- Manguito de pelaje en el brazo (cuatro bloques en anillo), runas en el brazal y grebas en el muslo.
			local upper = body.upperArm[side]
			local us = upper.size
			local cuffY = us.Y * 0.08
			for _, sz in { -1, 1 } do
				upper.block(
					Vector3.new(us.X + 0.1, 0.22, 0.12),
					fur,
					FABRIC,
					CFrame.new(0, cuffY, sz * (us.Z / 2 + 0.02))
				)
				upper.block(
					Vector3.new(0.12, 0.22, us.Z + 0.1),
					fur,
					FABRIC,
					CFrame.new(sz * (us.X / 2 + 0.02), cuffY, 0)
				)
			end
			local forearm = body.lowerArm[side]
			local fs = forearm.size
			for _, y in { 0.2, 0.1, 0 } do
				rune(
					forearm,
					CFrame.new(side * (fs.X / 2 + 0.075), fs.Y * y, 0) * CFrame.Angles(0, math.pi / 2, 0),
					runeColor,
					SMOOTH
				)
			end
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
					runeColor,
					SMOOTH,
					0.08
				)
			end
			for _, z in { -0.22, 0.22 } do
				leg.ball(0.12, JADE, SMOOTH, CFrame.new(side * (ls.X / 2 + 0.13), ls.Y * 0.14, z * ls.Z))
			end
		end
	end

	-- Grado 1 (con la capa del 2 queda tapado): el sol de la espalda con doce rayos de oro y jade, y runas y gemas en
	-- los cantos de la estela.
	if grade == 1 then
		for index = 0, 11 do
			local angle = index * math.pi / 6
			local x, y = math.sin(angle) * 0.66, math.cos(angle) * 0.66
			local long = math.abs(x) > math.abs(y)
			make.block(
				Vector3.new(if long then 0.22 else 0.1, if long then 0.1 else 0.22, 0.05),
				TITAN_GOLD,
				SMOOTH,
				sun * CFrame.new(x, y, 0.02)
			)
		end
		for index = 0, 3 do
			make.ball(
				0.12,
				JADE,
				SMOOTH,
				sun * CFrame.new((index % 2 * 2 - 1) * 0.36, (index // 2 * 2 - 1) * 0.36, 0.05)
			)
		end
		for side = -1, 1, 2 do
			for _, y in { 0.3, 0.1, -0.1, -0.3 } do
				rune(make, CFrame.new(side * width * 0.37, height * y, back + 0.07), runeColor, SMOOTH)
			end
			for sy = -1, 1, 2 do
				make.ball(0.14, JADE, SMOOTH, CFrame.new(side * width * 0.37, sy * height * 0.38, back + 0.08))
			end
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
		make.block(
			Vector3.new(width * 1.02, capeHeight, 0.12),
			GORILLA_FUR,
			FABRIC,
			CFrame.new(0, capeTop - capeHeight / 2, capeZ)
		)
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.08, capeHeight, 0.14),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * width * 0.51, capeTop - capeHeight / 2, capeZ + 0.01)
			)
			-- Runas en el canto y cuatro mechones por el lado de la capa.
			for index = 0, 6 do
				rune(
					make,
					CFrame.new(side * width * 0.44, capeTop - capeHeight * (0.1 + index * 0.11), capeZ + 0.08),
					runeColor,
					SMOOTH,
					0.1
				)
			end
			for index = 0, 3 do
				make.block(
					Vector3.new(0.22 - index % 2 * 0.06, 0.12, 0.1),
					fur,
					FABRIC,
					CFrame.new(side * (width * 0.5 + 0.12), capeTop - capeHeight * (0.12 + index * 0.2), capeZ)
				)
			end
		end
		-- Flecos del bajo (dos escalones), banda de oro y gotas de jade.
		for index = 0, 6 do
			local x = (index / 6 - 0.5) * width * 0.92
			local long = if index % 2 == 0 then 0.34 else 0.26
			make.block(
				Vector3.new(0.18, long * 0.6, 0.12),
				GORILLA_FUR,
				FABRIC,
				CFrame.new(x, capeBottom - long * 0.3 + 0.02, capeZ)
			)
			make.block(
				Vector3.new(0.1, long * 0.4, 0.12),
				GORILLA_FUR,
				FABRIC,
				CFrame.new(x, capeBottom - long * 0.8 + 0.02, capeZ)
			)
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

		-- Calavera de gorila dorada con un halo de rayos de oro y gemas de jade: el motivo de la espalda de este grado
		-- (el ídolo del 3 la tapa).
		if grade == 2 then
			local skull = CFrame.new(0, capeTop - capeHeight * 0.36, capeZ + 0.06)
			local size = width * 0.7
			local function disc(x: number, y: number, w: number, h: number, layer: number, color: Color3)
				make.block(
					Vector3.new(w * size, h * size, 0.04),
					color,
					SMOOTH,
					skull * CFrame.new(x * size, y * size, layer * 0.02)
				)
			end
			disc(0, 0.2, 0.98, 0.8, 0, TITAN_CARVING)
			disc(0, -0.3, 0.88, 0.62, 0, TITAN_CARVING)
			disc(0, 0.2, 0.9, 0.72, 1, TITAN_GOLD)
			disc(0, 0.56, 0.34, 0.3, 0.5, TITAN_GOLD)
			disc(0, -0.3, 0.78, 0.52, 2, TITAN_GOLD)
			disc(0, -0.42, 0.5, 0.05, 3, TITAN_CARVING)
			for side = -1, 1, 2 do
				disc(side * 0.4, -0.06, 0.3, 0.3, 1.5, TITAN_GOLD)
				disc(side * 0.21, -0.03, 0.27, 0.25, 3, TITAN_GOLD_DARK)
				disc(side * 0.21, -0.04, 0.18, 0.16, 3.5, JADE)
				disc(side * 0.22, 0.13, 0.46, 0.13, 4, TITAN_GOLD_DARK)
				disc(side * 0.07, -0.22, 0.09, 0.07, 3, TITAN_CARVING)
				make.block(
					Vector3.new(0.08 * size, 0.2 * size, 0.04),
					TITAN_GOLD,
					SMOOTH,
					skull * CFrame.new(side * 0.15 * size, -0.5 * size, 0.07)
				)
			end
			-- Halo: diez rayos de oro alrededor (sin los de arriba, junto a los hombros) y ocho gemas de jade entre ellos.
			for index = 0, 9 do
				local angle = 0.7 + index * (2 * math.pi - 1.4) / 9
				local x, y = -math.sin(angle) * size * 0.7, math.cos(angle) * size * 0.68
				local long = math.abs(x) > math.abs(y)
				make.block(
					Vector3.new(if long then 0.34 else 0.12, if long then 0.12 else 0.34, 0.08),
					TITAN_GOLD,
					SMOOTH,
					skull * CFrame.new(x, y, 0.1)
				)
				if index >= 1 and index <= 8 then
					local mid = angle - (2 * math.pi - 1.4) / 18
					make.ball(
						0.1,
						JADE,
						SMOOTH,
						skull * CFrame.new(-math.sin(mid) * size * 0.58, math.cos(mid) * size * 0.56, 0.1)
					)
				end
			end
		end

		-- Broches de oro con jade, unidos por una cadena que cuelga, y de cada uno un colgante de jade.
		local clasps = {}
		for side = -1, 1, 2 do
			local clasp = CFrame.new(side * width * 0.36, height / 2 - 0.12, front - 0.04)
			make.block(Vector3.new(0.3, 0.3, 0.08), TITAN_GOLD, SMOOTH, clasp)
			make.ball(0.14, JADE, SMOOTH, clasp * CFrame.new(0, 0, -0.06))
			clasps[side] = clasp.Position
			for link = 0, 3 do
				make.block(
					Vector3.new(0.06, 0.12, 0.06),
					TITAN_GOLD,
					SMOOTH,
					CFrame.new(side * width * 0.36, height / 2 - 0.34 - link * 0.14, front - 0.1)
				)
			end
			make.ball(0.16, JADE, SMOOTH, CFrame.new(side * width * 0.36, height / 2 - 0.96, front - 0.1))
			make.block(
				Vector3.new(0.1, 0.16, 0.08),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * width * 0.36, height / 2 - 1.12, front - 0.1)
			)
		end
		local sag = Vector3.new(0, height / 2 - 0.3, front - 0.06)
		strap(make, clasps[-1], sag, 0.05, TITAN_GOLD, SMOOTH)
		strap(make, sag, clasps[1], 0.05, TITAN_GOLD, SMOOTH)

		-- Faldones de piedra en los muslos con ribete de oro, gema de jade, flecos y dos runas.
		for side = -1, 1, 2 do
			local leg = body.upperLeg[side]
			local ls = leg.size
			local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.16))
			leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.42, 0.1), TITAN_STONE, SLATE, flap)
			leg.block(Vector3.new(ls.X * 0.92, 0.06, 0.12), TITAN_GOLD, SMOOTH, flap * CFrame.new(0, -ls.Y * 0.2, 0))
			leg.ball(0.12, JADE, SMOOTH, flap * CFrame.new(0, 0.02, -0.06))
			for index = 0, 3 do
				leg.block(
					Vector3.new(0.12, 0.2, 0.1),
					TITAN_GOLD_DARK,
					SMOOTH,
					flap * CFrame.new((index - 1.5) * ls.X * 0.2, -ls.Y * 0.23 - 0.1, -0.02)
				)
			end
			for _, x in { -0.25, 0.25 } do
				rune(leg, flap * CFrame.new(x * ls.X, 0.02, -0.07), runeColor, SMOOTH, 0.1)
			end
		end
	end

	-- Grado 3: el ídolo de la espalda, un busto de piedra con corona de oro, entre los omoplatos: la corona llega a la
	-- nuca y la cabeza del jugador se sigue viendo por encima. Alrededor, la silla de lomo plateado, la melena, el collar
	-- de jade, las cadenas y las filas de mechones; en las muñecas púas de oro y en las rodillas placas de oro.
	if grade >= 3 then
		local idol = CFrame.new(0, idolY, base + 0.6) * CFrame.Angles(0, math.pi, 0)
		local bustY = idolY - idolSize * 0.5 - 0.06
		local bust = CFrame.new(0, bustY, base + 0.44)
		-- Lomo plateado: una silla de pelaje plateado con mechones en punta abajo, y dos filas más de mechones.
		make.block(
			Vector3.new(width * 0.84, capeHeight * 0.56, 0.05),
			SILVER_FUR,
			FABRIC,
			CFrame.new(0, capeTop - capeHeight * 0.3, capeZ + 0.06)
		)
		for index = -1, 1 do
			local long = if index == 0 then 0.3 else 0.22
			make.block(
				Vector3.new(0.18, long * 0.6, 0.1),
				SILVER_FUR_DARK,
				FABRIC,
				CFrame.new(index * width * 0.2, capeTop - capeHeight * 0.58 - long * 0.3, capeZ + 0.07)
			)
			make.block(
				Vector3.new(0.1, long * 0.4, 0.1),
				SILVER_FUR_DARK,
				FABRIC,
				CFrame.new(index * width * 0.2, capeTop - capeHeight * 0.58 - long * 0.8, capeZ + 0.07)
			)
		end
		for row = 1, 2 do
			for index = 0, 6 do
				make.block(
					Vector3.new(0.16, if index % 2 == 0 then 0.24 else 0.18, 0.1),
					SILVER_FUR_DARK,
					FABRIC,
					CFrame.new(
						(index / 6 - 0.5) * width * 0.9 + (row - 1.5) * 0.1,
						capeTop - capeHeight * (0.66 + row * 0.1),
						capeZ + 0.07
					)
				)
			end
		end
		make.block(Vector3.new(width * 0.78, 0.34, 0.5), TITAN_STONE_DARK, SLATE, bust)
		make.block(Vector3.new(width * 0.8, 0.07, 0.52), TITAN_GOLD, SMOOTH, bust * CFrame.new(0, 0.1, 0))
		local eyes = titanFace(make, idol, idolSize, 1, SUN_GLOW, NEON, false)
		fireLight(eyes[1], SUN_GLOW)
		-- Corona: banda de oro, cinco puntas de dos escalones con una cuenta de jade y seis tachones.
		local crown = idol * CFrame.new(0, idolSize * 0.5, idolSize * 0.08)
		make.block(Vector3.new(idolSize * 0.66, 0.16, idolSize * 0.5), TITAN_GOLD, SMOOTH, crown)
		for index = -2, 2 do
			local length = if index == 0 then 0.5 else 0.38 - math.abs(index) * 0.04
			local x = index * idolSize * 0.13
			make.block(
				Vector3.new(0.16, length * 0.6, 0.12),
				TITAN_GOLD,
				SMOOTH,
				crown * CFrame.new(x, 0.08 + length * 0.3, -idolSize * 0.22)
			)
			make.block(
				Vector3.new(0.1, length * 0.4, 0.1),
				TITAN_GOLD,
				SMOOTH,
				crown * CFrame.new(x, 0.08 + length * 0.8, -idolSize * 0.22)
			)
			make.ball(0.12, JADE, SMOOTH, crown * CFrame.new(x, 0.12, -idolSize * 0.22 - 0.09))
		end
		for index = 0, 5 do
			make.ball(
				0.09,
				TITAN_GOLD,
				SMOOTH,
				crown * CFrame.new((index - 2.5) * idolSize * 0.115, 0, -idolSize * 0.26)
			)
		end
		-- Melena plateada a los lados del ídolo (cinco bloques por lado) y hombreras de oro en el busto.
		for side = -1, 1, 2 do
			for index = 0, 4 do
				make.block(
					Vector3.new(0.2, 0.28, 0.2),
					SILVER_FUR,
					FABRIC,
					CFrame.new(side * (0.78 + math.sin(index * 0.8) * 0.16), idolY + 0.5 - index * 0.28, base + 0.5)
				)
			end
			make.block(
				Vector3.new(0.26, 0.14, 0.4),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * 0.8, bustY + 0.02, base + 0.44)
			)
		end
		-- Collar de siete gemas de jade con seis colmillos de oro, y tres cadenas de dos eslabones con jade.
		for index = 0, 6 do
			make.ball(0.13, JADE, SMOOTH, CFrame.new((index - 3) * 0.2, bustY + 0.02, base + 0.72))
			if index < 6 then
				make.block(
					Vector3.new(0.09, 0.2, 0.09),
					TITAN_GOLD,
					SMOOTH,
					CFrame.new((index - 2.5) * 0.2, bustY - 0.1, base + 0.72)
				)
			end
		end
		for index = -1, 1 do
			for link = 0, 1 do
				make.block(
					Vector3.new(0.05, 0.12, 0.05),
					TITAN_GOLD,
					SMOOTH,
					CFrame.new(index * 0.28, bustY - 0.24 - link * 0.14, base + 0.5)
				)
			end
			make.ball(
				0.1,
				JADE,
				SMOOTH,
				CFrame.new(index * 0.28, bustY - 0.56 - (2 - math.abs(index)) * 0.06, base + 0.5)
			)
		end
		-- Púas de oro en las muñecas (tres por lado, solo hacia fuera) y rodilleras de oro con jade y dos puntas.
		for side = -1, 1, 2 do
			local forearm = body.lowerArm[side]
			local fs = forearm.size
			for _, z in { -0.28, 0, 0.28 } do
				forearm.block(
					Vector3.new(0.22, 0.1, 0.1),
					TITAN_GOLD,
					SMOOTH,
					CFrame.new(side * (fs.X / 2 + 0.11), fs.Y * 0.12, z)
				)
			end
			local leg = body.upperLeg[side]
			local ls = leg.size
			local knee = CFrame.new(side * 0.04, -ls.Y * 0.3, -(ls.Z / 2 + 0.1))
			leg.block(Vector3.new(ls.X * 0.5, 0.3, 0.1), TITAN_GOLD, SMOOTH, knee)
			leg.ball(0.12, JADE, SMOOTH, knee * CFrame.new(0, 0, -0.07))
			for _, x in { -0.16, 0.16 } do
				leg.block(Vector3.new(0.1, 0.1, 0.2), TITAN_GOLD, SMOOTH, knee * CFrame.new(x, 0, -0.1))
			end
		end

		-- Grado 4: aro solar con rayos y cristales de jade, lianas con orquídeas y motas de sol.
		if grade >= 4 then
			local disc = CFrame.new(0, idolY + 0.3, base + 0.36)
			local radius = idolSize * 0.86
			-- Aro abierto (no un disco: por detrás taparía la cabeza), octogonal y sin giros: cuatro barras y, en cada
			-- esquina, tres escalones.
			for _, bar in
				{
					{ 0, radius, 1.0, 0.14 },
					{ 0, -radius, 1.0, 0.14 },
					{ radius, 0, 0.14, 1.1 },
					{ -radius, 0, 0.14, 1.1 },
				}
			do
				make.block(
					Vector3.new(bar[3], bar[4], 0.1),
					TITAN_GOLD_DARK,
					SMOOTH,
					disc * CFrame.new(bar[1], bar[2], 0)
				)
			end
			for sx = -1, 1, 2 do
				for sy = -1, 1, 2 do
					for _, step in { { 0.62, 0.98 }, { 0.9, 0.78 }, { 1.12, 0.56 } } do
						make.block(
							Vector3.new(0.26, 0.2, 0.1),
							TITAN_GOLD_DARK,
							SMOOTH,
							disc * CFrame.new(sx * step[1], sy * step[2] * 1.2, 0)
						)
					end
				end
			end
			-- Un rayo largo de oro en cada punto cardinal (tres escalones) y un cristal de jade en cada esquina.
			for _, dir in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
				for index = 0, 2 do
					local span = 0.22 - index * 0.04
					make.block(
						Vector3.new(if dir[1] ~= 0 then 0.2 else span, if dir[2] ~= 0 then 0.2 else span, 0.1),
						TITAN_GOLD,
						SMOOTH,
						disc
							* CFrame.new(
								dir[1] * (radius + 0.1 + index * 0.18),
								dir[2] * (radius + 0.1 + index * 0.18),
								0.02
							)
					)
				end
			end
			for sx = -1, 1, 2 do
				for sy = -1, 1, 2 do
					spire(make, sx * 0.9, disc.Position.Y + sy * 0.94, base + 0.4, 0.24, 0.5, 0.24, JADE, SMOOTH, 0)
				end
			end
			-- Cuatro rayos de sol que brillan en el centro de las barras (el único neón del aro, con luz y motas en uno).
			for index, dir in { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } } do
				local beam = make.ball(0.16, SUN_GLOW, NEON, disc * CFrame.new(dir[1] * radius, dir[2] * radius, 0.08))
				if index == 1 then
					fireLight(beam, SUN_GLOW)
					sunMotes(beam, 6)
				end
			end
			-- Ocho tachones de oro en el aro y tres en cada muslo (de oro, sin neón).
			for index = 0, 7 do
				make.ball(
					0.1,
					TITAN_GOLD,
					SMOOTH,
					disc
						* CFrame.new(
							math.sin(index * math.pi / 4) * radius * 0.78,
							math.cos(index * math.pi / 4) * radius * 0.78,
							0.08
						)
				)
			end
			for side = -1, 1, 2 do
				local ls = body.upperLeg[side].size
				for _, z in { -0.3, 0, 0.3 } do
					body.upperLeg[side].ball(
						0.1,
						TITAN_GOLD,
						SMOOTH,
						CFrame.new(side * (ls.X / 2 + 0.1), -ls.Y * 0.34, z * ls.Z)
					)
				end
			end
			-- Lianas con hojas y orquídeas que caen de los lados del ídolo por la capa: cuatro puntos y tiras entre ellos.
			for side = -1, 1, 2 do
				local points = {
					Vector3.new(side * width * 0.34, idolY + 0.3, base + 0.5),
					Vector3.new(side * width * 0.42, height * 0.04, base + 0.4),
					Vector3.new(side * width * 0.36, -height * 0.2, base + 0.36),
					Vector3.new(side * width * 0.42, -height * 0.48, base + 0.34),
				}
				for index = 1, #points - 1 do
					strap(make, points[index], points[index + 1], 0.06, LIANA, FABRIC)
				end
				for index = 2, 3 do
					local at = points[index] + Vector3.new(-side * 0.1, -0.08, 0.04)
					make.block(
						Vector3.new(0.16, 0.26, 0.05),
						if index % 2 == 0 then LEAF else LEAF_DARK,
						FABRIC,
						CFrame.new(at)
					)
					make.block(Vector3.new(0.04, 0.2, 0.04), LIANA, FABRIC, CFrame.new(at + Vector3.new(0, 0, 0.03)))
				end
				for _, flower in { points[2] + Vector3.new(side * 0.04, 0, 0.06) } do
					for petal = 0, 2 do
						make.block(
							Vector3.new(0.12, 0.12, 0.05),
							ORCHID,
							SMOOTH,
							CFrame.new(flower + Vector3.new((petal - 1) * 0.1, math.abs(petal - 1) * -0.06 + 0.04, 0))
						)
					end
					make.block(
						Vector3.new(0.08, 0.08, 0.05),
						TITAN_GOLD,
						SMOOTH,
						CFrame.new(flower + Vector3.new(0, 0, 0.03))
					)
				end
			end
		end
	end
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
	-- El cuerpo del espíritu es azul espectral profundo (no casi blanco) para que se lea sobre fondos claros y sobre la capa;
	-- detrás lleva una sombra de piedra de noche. La luna es plata azulada sobre un disco de azul noche.
	local SPECTRAL_BODY = Color3.fromRGB(62, 96, 215)
	local SPECTRAL_PALE = Color3.fromRGB(120, 160, 245)
	local SPECTRAL_SPOT = Color3.fromRGB(28, 36, 105)
	local MOON_SILVER = Color3.fromRGB(168, 190, 232)
	local STAR_GOLD = Color3.fromRGB(255, 226, 150)

	-- Ayudantes del Jaguar (Fase 20 Q6g). Todo de bloques alineados con los ejes y sin giros (ni óvalos, ni bolas, ni
	-- colmillos girados): así entran en la malla del grado 4 y, en los grados bajos, cuestan lo mismo. Van en una tabla
	-- para no gastar locales del nivel superior.
	local jag = {}

	-- Roseta de jaguar de "size" en el plano XY de "at" (mirando a su -Z): mancha negra con el centro más claro. Dos bloques.
	function jag.rosette(make: Builder, size: number, at: CFrame)
		make.block(Vector3.new(size, size * 0.85, 0.04), ROSETTE, SMOOTH, at)
		make.block(Vector3.new(size * 0.5, size * 0.42, 0.04), ROSETTE_CORE, SMOOTH, at * CFrame.new(0, 0, -0.012))
	end

	-- Huella de jaguar de "size" en el plano XY de "at" (mirando a su -Z): almohadilla y cuatro dedos. Cinco bloques.
	function jag.paw(make: Builder, size: number, color: Color3, material: Enum.Material, at: CFrame)
		make.block(Vector3.new(size * 0.56, size * 0.4, 0.05), color, material, at * CFrame.new(0, -size * 0.18, 0))
		for index = 0, 3 do
			local outer = index == 0 or index == 3
			make.block(
				Vector3.new(size * 0.18, size * 0.24, 0.05),
				color,
				material,
				at * CFrame.new((index - 1.5) * size * 0.24, size * (if outer then 0.07 else 0.17), 0)
			)
		end
	end

	-- Garra, colmillo o mechón que cuelga (dos escalones, el segundo más fino): nace en "topY", en la X "x" y la Z "z".
	-- "tipColor" y "tipMaterial" pintan el escalón de la punta de otra cosa (la luz del espíritu).
	function jag.claw(
		make: Builder,
		x: number,
		topY: number,
		z: number,
		length: number,
		width: number,
		color: Color3,
		material: Enum.Material,
		tipColor: Color3?,
		tipMaterial: Enum.Material?
	)
		make.block(Vector3.new(width, length * 0.55, width), color, material, CFrame.new(x, topY - length * 0.275, z))
		make.block(
			Vector3.new(width * 0.6, length * 0.45, width * 0.6),
			tipColor or color,
			tipMaterial or material,
			CFrame.new(x, topY - length * 0.775, z)
		)
	end

	-- Cristal de jade de bloques: tres escalones que se estrechan hacia arriba y se corren "lean" studs (X, Z) por
	-- escalón. Sin neón (el verde que brilla es de las curaciones).
	function jag.crystal(make: Builder, base: Vector3, height: number, width: number, lean: Vector3)
		for index = 0, 2 do
			make.block(
				Vector3.new(width * (1 - 0.28 * index), height / 3, width * (1 - 0.28 * index)),
				if index == 2 then JADE_LIGHT else JADE,
				SMOOTH,
				CFrame.new(base + lean * (index + 0.5) + Vector3.new(0, height / 3 * (index + 0.5), 0))
			)
		end
	end

	-- Cabeza de jaguar rugiendo, de bloques, mirando a la -Z de "at": "size" studs de ancho y "depth" veces su fondo.
	-- Cráneo ancho y bajo, mejillas, orejas de dos escalones, ojos de "eye" bajo las cejas de furia (con "detail"), hocico
	-- crema con la nariz oscura y la boca abierta con colmillos de oro. "pelt", "cream" y "material" son su pelaje; con
	-- cualquier otro material que no sea FABRIC es el espíritu (todo translúcido, colmillos de luz). "detail" añade cejas,
	-- lágrimas, manchas, bigotes y el dentro de las orejas (38 bloques; sin él, 19). Devuelve sus piezas y los ojos.
	function jag.head(
		make: Builder,
		at: CFrame,
		size: number,
		depth: number,
		eye: Color3,
		eyeMaterial: Enum.Material,
		pelt: Color3,
		cream: Color3,
		material: Enum.Material,
		detail: boolean
	): ({ BasePart }, { BasePart })
		local parts, eyes = {}, {}
		local real = material == FABRIC
		local spot = if real then ROSETTE else SPECTRAL_SPOT
		local spotMaterial = if real then SMOOTH else material
		local mouth = if real then JAGUAR_MOUTH else SPECTRAL_SPOT
		local fang = if real then TITAN_GOLD else SPECTRAL
		local fangMaterial = if real then SMOOTH else material
		local function put(
			x: number,
			y: number,
			z: number,
			sx: number,
			sy: number,
			sz: number,
			color: Color3,
			blockMaterial: Enum.Material
		): BasePart
			local piece = make.block(
				Vector3.new(sx * size, sy * size, sz * size * depth),
				color,
				blockMaterial,
				at * CFrame.new(x * size, y * size, z * size * depth)
			)
			table.insert(parts, piece)
			return piece
		end
		put(0, 0.06, 0.12, 1, 0.62, 0.7, pelt, material)
		put(0, -0.14, -0.38, 0.42, 0.22, 0.3, cream, material)
		put(0, -0.05, -0.54, 0.16, 0.08, 0.06, spot, spotMaterial)
		put(0, -0.27, -0.45, 0.34, 0.08, 0.08, mouth, spotMaterial)
		put(0, -0.37, -0.38, 0.36, 0.1, 0.26, cream, material)
		for side = -1, 1, 2 do
			-- Mejilla ancha con el mechón crema delante.
			put(side * 0.43, -0.12, -0.02, 0.3, 0.3, 0.42, pelt, material)
			put(side * 0.36, -0.2, -0.25, 0.22, 0.2, 0.1, cream, material)
			-- Oreja de dos escalones.
			put(side * 0.36, 0.4, 0.12, 0.2, 0.18, 0.16, pelt, material)
			put(side * 0.36, 0.53, 0.12, 0.12, 0.12, 0.12, pelt, material)
			-- Ojos y colmillos de arriba.
			table.insert(eyes, put(side * 0.2, 0.08, -0.25, 0.22, 0.09, 0.06, eye, eyeMaterial))
			put(side * 0.12, -0.3, -0.5, 0.07, 0.1, 0.07, fang, fangMaterial)
			put(side * 0.12, -0.37, -0.5, 0.045, 0.07, 0.045, fang, fangMaterial)
			if detail then
				put(side * 0.36, 0.42, 0.03, 0.08, 0.12, 0.04, spot, spotMaterial)
				-- Cejas de furia: el escalón de fuera, alto, y el de dentro, más bajo y oscuro.
				put(side * 0.27, 0.18, -0.27, 0.18, 0.08, 0.1, pelt, material)
				put(side * 0.11, 0.145, -0.31, 0.14, 0.05, 0.04, spot, spotMaterial)
				-- Lágrima negra bajo el ojo, manchas de la mejilla y bigotes.
				put(side * 0.2, -0.07, -0.27, 0.05, 0.2, 0.04, spot, spotMaterial)
				put(side * 0.43, -0.06, -0.235, 0.06, 0.06, 0.03, spot, spotMaterial)
				put(side * 0.43, -0.18, -0.235, 0.06, 0.06, 0.03, spot, spotMaterial)
				put(side * 0.1, -0.12, -0.535, 0.05, 0.05, 0.03, spot, spotMaterial)
				put(side * 0.17, -0.17, -0.535, 0.05, 0.05, 0.03, spot, spotMaterial)
			end
		end
		if detail then
			put(0, 0.25, -0.235, 0.08, 0.07, 0.03, spot, spotMaterial)
			put(-0.15, 0.28, -0.235, 0.07, 0.07, 0.03, spot, spotMaterial)
			put(0.15, 0.28, -0.235, 0.07, 0.07, 0.03, spot, spotMaterial)
		end
		return parts, eyes
	end

	-- Niebla del espíritu: velos blancos azulados que suben despacio.
	local function spectralMist(part: BasePart, rate: number)
		local mist = Instance.new("ParticleEmitter")
		mist.Texture = SMOKE_TEXTURE
		mist.Color = ColorSequence.new(SPECTRAL_BODY)
		mist.LightEmission = 0.3
		mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.8) })
		mist.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.78),
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

	-- Hombrera del Jaguar (grado 1+), sin giros para la malla. La del brazo izquierdo: almohadilla de piedra de noche con
	-- el canto de oro, láminas de pelaje que bajan escalonadas hacia fuera (con rosetas y el canto de oro) y, encima, la
	-- cabeza de un jaguar que mira hacia fuera. La del arco (derecho), pequeña para no tensar la cuerda contra ella: un
	-- casquete de pelaje con tachones de oro, dos rosetas y tres garras de oro colgando por fuera.
	-- Por grados (izquierda): 1, almohadilla, dos láminas y la cabeza sin manchas; 2, la tercera lámina, la cabeza con
	-- todos sus detalles y cinco garras de oro colgando del borde; 3, ojos de luz, golpe de pelaje crema detrás de la cabeza,
	-- aleta de detrás con roseta (lo que se ve de espaldas) y dos gemas de jade; 4, cinco cristales de jade detrás de la
	-- cabeza. (Derecha): 1, el casquete; 2, la lámina de abajo; 3, puntas de las garras de luz y aleta con roseta detrás;
	-- 4, tres cristales de jade.
	local function jaguarPauldron(arm: Builder, side: number, grade: number)
		local as = arm.size
		local W, D = as.X, as.Z
		local top = as.Y / 2
		local lit = grade >= 3
		local behind = CFrame.Angles(0, math.pi, 0)
		local flat = CFrame.Angles(math.pi / 2, 0, 0) -- la roseta tumbada, mirando hacia arriba
		local eye = if lit then SPECTRAL else JADE
		local eyeMaterial = if lit then NEON else SMOOTH
		if side > 0 then
			local cap = CFrame.new(side * 0.1, top + 0.08, 0)
			arm.block(Vector3.new(W * 1.2, 0.18, D * 1.22), JAGUAR, FABRIC, cap)
			arm.block(Vector3.new(W * 1.28, 0.06, D * 1.3), TITAN_GOLD, SMOOTH, cap * CFrame.new(0, -0.11, 0))
			for sx = -1, 1, 2 do
				for sz = -1, 1, 2 do
					arm.block(
						Vector3.one * 0.1,
						TITAN_GOLD,
						SMOOTH,
						cap * CFrame.new(sx * W * 0.52, 0.12, sz * D * 0.52)
					)
				end
			end
			for _, z in { -0.28, 0.28 } do
				jag.rosette(arm, 0.2, cap * CFrame.new(side * 0.06, 0.095, z * D) * flat)
			end
			if grade >= 2 then
				-- Lámina de abajo, corrida hacia fuera, con el canto de oro.
				local lame = cap * CFrame.new(side * 0.12, -0.2, 0)
				arm.block(Vector3.new(W * 1.1, 0.14, D * 1.12), JAGUAR, FABRIC, lame)
				arm.block(Vector3.new(W * 1.14, 0.05, D * 1.16), TITAN_GOLD, SMOOTH, lame * CFrame.new(0, -0.09, 0))
			end
			for _, z in { -0.3, 0, 0.3 } do
				jag.claw(
					arm,
					side * 0.74,
					top - 0.02,
					z * D,
					if z == 0 then 0.46 else 0.34,
					0.13,
					TITAN_GOLD,
					SMOOTH,
					if lit then SPECTRAL else nil,
					if lit then NEON else nil
				)
			end
			if grade >= 3 then
				-- Aleta de pelaje detrás del casquete, con el canto de oro y una roseta.
				local fin = CFrame.new(side * 0.1, top + 0.22, D * 0.66)
				arm.block(Vector3.new(W * 1.1, 0.5, 0.1), JAGUAR, FABRIC, fin)
				arm.block(Vector3.new(W * 1.14, 0.05, 0.12), TITAN_GOLD, SMOOTH, fin * CFrame.new(0, -0.27, 0))
				jag.rosette(arm, 0.22, fin * CFrame.new(0, 0, 0.075) * behind)
			end
			if grade >= 4 then
				for _, z in { -0.3, 0, 0.3 } do
					jag.crystal(
						arm,
						Vector3.new(side * 0.12, top + 0.15, z * D),
						if z == 0 then 0.85 else 0.55,
						0.2,
						Vector3.new(side * 0.03, 0, z * 0.1)
					)
				end
			end
			return
		end

		-- Almohadilla de piedra con el canto de oro debajo y cuatro tachones en las esquinas.
		local pad = CFrame.new(side * 0.1, top + 0.1, 0)
		arm.block(Vector3.new(W * 1.32, 0.2, D * 1.34), NIGHT_STONE, SLATE, pad)
		arm.block(Vector3.new(W * 1.42, 0.07, D * 1.44), TITAN_GOLD, SMOOTH, pad * CFrame.new(0, -0.11, 0))
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				arm.block(Vector3.one * 0.1, TITAN_GOLD, SMOOTH, pad * CFrame.new(sx * W * 0.6, 0.14, sz * D * 0.62))
			end
		end
		-- Láminas de pelaje que bajan escalonadas hacia fuera; las de fuera llevan una roseta en la franja que asoma.
		local lames = {
			{ w = 1.15, d = 1.36, y = 0.1, out = 0.18 },
			{ w = 1.3, d = 1.3, y = 0.3, out = 0.33 },
			{ w = 1.45, d = 1.24, y = 0.5, out = 0.48 },
		}
		for index, lame in lames do
			if index == 3 and grade < 2 then
				break
			end
			local at = CFrame.new(side * lame.out, top - lame.y, 0)
			arm.block(Vector3.new(W * lame.w, 0.2, D * lame.d), JAGUAR, FABRIC, at)
			arm.block(
				Vector3.new(W * lame.w + 0.06, 0.05, D * lame.d + 0.06),
				TITAN_GOLD,
				SMOOTH,
				at * CFrame.new(0, -0.12, 0)
			)
			if index > 1 then
				jag.rosette(arm, 0.18, at * CFrame.new(side * (W * lame.w / 2 - 0.11), 0.12, 0) * flat)
			end
		end
		-- La cabeza de jaguar, hundida en la almohadilla y mirando hacia fuera.
		jag.head(
			arm,
			CFrame.new(side * 0.45, top + 0.52, 0) * CFrame.Angles(0, -side * math.pi / 2, 0),
			0.92,
			0.8,
			eye,
			eyeMaterial,
			JAGUAR,
			JAGUAR_CREAM,
			FABRIC,
			grade >= 2
		)
		if grade >= 2 then
			-- Garras de oro colgando del borde de la lámina de abajo.
			for index = -2, 2 do
				jag.claw(
					arm,
					side * 1.12,
					top - 0.63,
					index * 0.25 * D,
					if index % 2 == 0 then 0.42 else 0.3,
					0.12,
					TITAN_GOLD,
					SMOOTH
				)
			end
		end
		if grade >= 3 then
			-- Golpe de pelaje crema detrás de la cabeza, con cuatro manchas por su cara de atrás.
			arm.block(Vector3.new(0.5, 0.5, D * 0.9), JAGUAR_CREAM, FABRIC, CFrame.new(0, top + 0.45, 0))
			for _, x in { -0.15, 0.15 } do
				for _, y in { 0.35, 0.58 } do
					arm.block(Vector3.one * 0.08, ROSETTE, SMOOTH, CFrame.new(x, top + y, D * 0.45 + 0.02))
				end
			end
			-- Aleta de detrás, con el canto de oro y una roseta.
			local fin = CFrame.new(side * 0.15, top + 0.35, D * 0.7)
			arm.block(Vector3.new(W * 1.2, 0.6, 0.1), JAGUAR, FABRIC, fin)
			arm.block(Vector3.new(W * 1.24, 0.05, 0.12), TITAN_GOLD, SMOOTH, fin * CFrame.new(0, -0.32, 0))
			jag.rosette(arm, 0.24, fin * CFrame.new(0, 0, 0.075) * behind)
			for sz = -1, 1, 2 do
				arm.block(Vector3.one * 0.14, JADE, SMOOTH, pad * CFrame.new(0, 0.14, sz * D * 0.58))
			end
		end
		if grade >= 4 then
			for _, z in { -0.42, -0.26, 0, 0.26, 0.42 } do
				jag.crystal(
					arm,
					Vector3.new(-side * 0.05, top + 0.68, z * D),
					if z == 0 then 0.75 elseif math.abs(z) > 0.3 then 0.5 else 0.62,
					if math.abs(z) > 0.3 then 0.16 else 0.2,
					Vector3.new(-side * 0.07, 0, z * 0.12)
				)
			end
		end
	end

	-- Traje mítico del cazador, Jaguar Espectral (Fase 20 Q6g: todo de bloques alineados con los ejes, sin giros, para la
	-- malla del grado 4; solo quedan sueltos el neón, el cristal del espíritu y las piezas con luces o partículas).
	-- Grado 0: jubón de pelaje de jaguar con rosetas, placa de piedra de noche en el pecho con una cabeza de jaguar en
	-- relieve, tres zarpazos en el otro pectoral, gorguera de oro con cuentas de jade y colmillos, correa del carcaj
	-- con tachones de oro y un medallón de jade con la huella de oro, cinturón de piedra con hebilla de jade, taparrabos
	-- de pelaje, la cola del jaguar colgando detrás (anillos negros y punta negra), brazal de piedra en el brazo del
	-- arco y garras de oro en el otro. Detrás, una gran huella de jaguar de oro con rosetas y el carcaj de piedra de
	-- noche con aros de oro y flechas de plumas negras y doradas. Grado 1: hombreras (cabeza de jaguar a la izquierda,
	-- casquete con garras en el brazo del arco), más rosetas en el jubón, manguitos de pelaje crema, bandas y rosetas en
	-- los muslos, tachones en el cinturón. Grado 2: manto y capa de pelaje con rosetas y un fleco de garras, broches con
	-- cadena, faldones con dientes en los muslos, mechones por los lados de la capa, gotas de jade en el bajo, dientes en
	-- el taparrabos y en los manguitos y, de motivo en la espalda, la capucha con la cabeza del jaguar. Grado 3: el
	-- espíritu del jaguar sale de la capucha (queda vacía) y asoma translúcido por encima del hombro izquierdo, con una
	-- pata sobre él; se encienden los ojos de todas las cabezas, los zarpazos, las garras y las rosetas de la capa.
	-- Grado 4: una luna creciente con estrellas detrás del espíritu, niebla espectral, el mapa de estrellas sobre la
	-- capa, las flechas que arden en luz y cristales de jade en las hombreras.
	local function spectralJaguar(body: Body, grade: number)
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local lit = grade >= 3
		local eye = if lit then SPECTRAL else JADE
		local eyeMaterial = if lit then NEON else SMOOTH
		local BEHIND = CFrame.Angles(0, math.pi, 0)
		local capeHeight = height * 1.16
		local capeTop = height / 2 - 0.05
		local capeBottom = capeTop - capeHeight
		local capeZ = back + 0.2
		make.block(
			Vector3.new(width + 0.1, height * 0.92, depth + 0.14),
			JAGUAR,
			FABRIC,
			CFrame.new(0, -height * 0.03, 0)
		)
		-- Rosetas de delante: cuatro en el grado 0 y cinco más desde el grado 1.
		local frontSpots = { { -0.38, -0.3 }, { 0.36, -0.38 }, { -0.12, -0.42 }, { 0.42, 0.04 } }
		if grade >= 1 then
			for _, spot in { { -0.4, -0.12 }, { 0.16, -0.16 }, { -0.14, -0.24 }, { 0.12, -0.34 }, { 0.4, -0.14 } } do
				table.insert(frontSpots, spot)
			end
		end
		for _, spot in frontSpots do
			jag.rosette(make, 0.24, CFrame.new(spot[1] * width, spot[2] * height, front + 0.005))
		end

		-- Espalda (hasta el grado 1; la capa la tapa después): rosetas y la gran huella de oro.
		if grade < 2 then
			for _, spot in
				{ { -0.36, 0.3 }, { 0.3, 0.32 }, { -0.06, -0.26 }, { 0.38, -0.2 }, { -0.36, -0.36 }, { 0.08, -0.46 } }
			do
				jag.rosette(make, 0.28, CFrame.new(spot[1] * width, spot[2] * height, back + 0.075) * BEHIND)
			end
			jag.paw(make, 0.8, TITAN_GOLD, SMOOTH, CFrame.new(-width * 0.2, height * 0.12, back + 0.1) * BEHIND)
		end

		-- Pecho: placa de piedra de noche con el canto de oro, cuatro tachones y una cabeza de jaguar en relieve
		-- (izquierda); tres zarpazos (derecha), que brillan desde el grado 3 y entonces van adelantados.
		local plate = CFrame.new(-width * 0.24, height * 0.18, front - 0.03)
		make.block(Vector3.new(width * 0.46, height * 0.4, 0.12), TITAN_GOLD, SMOOTH, plate * CFrame.new(0, 0, 0.02))
		make.block(Vector3.new(width * 0.4, height * 0.34, 0.12), NIGHT_STONE, SLATE, plate * CFrame.new(0, 0, -0.01))
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				make.block(
					Vector3.one * 0.1,
					TITAN_GOLD,
					SMOOTH,
					plate * CFrame.new(sx * width * 0.2, sy * height * 0.16, -0.1)
				)
			end
		end
		jag.head(
			make,
			plate * CFrame.new(0, -0.02, -0.07),
			0.6,
			0.35,
			eye,
			eyeMaterial,
			JAGUAR,
			JAGUAR_CREAM,
			FABRIC,
			false
		)
		local slashZ = if lit then front - 0.1 else front - 0.02
		for index = -1, 1 do
			local x = width * 0.26 + index * 0.13
			strap(
				make,
				Vector3.new(x + 0.1, height * 0.36, slashZ),
				Vector3.new(x - 0.1, height * 0.04, slashZ),
				0.07,
				if lit then SPECTRAL else ROSETTE,
				if lit then NEON else SMOOTH
			)
		end

		-- Gorguera: aro de oro alrededor del cuello con cuatro cuentas de jade y tres colmillos crema delante.
		local neckY = height / 2 - 0.02
		local collarZ = depth / 2 + 0.1
		for _, z in { -collarZ, collarZ } do
			make.block(Vector3.new(width * 0.54, 0.14, 0.16), TITAN_GOLD, SMOOTH, CFrame.new(0, neckY, z))
		end
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.16, 0.14, collarZ * 2 - 0.16),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * width * 0.27, neckY, 0)
			)
			for _, z in { -collarZ, collarZ } do
				make.block(Vector3.one * 0.15, JADE, SMOOTH, CFrame.new(side * width * 0.27, neckY + 0.05, z))
			end
		end
		for index = -1, 1 do
			jag.claw(
				make,
				index * width * 0.16,
				neckY - 0.07,
				-collarZ - 0.02,
				if index == 0 then 0.34 else 0.26,
				0.1,
				JAGUAR_CREAM,
				SMOOTH
			)
		end

		-- Correa del carcaj con tachones de oro y un medallón de jade con la huella de oro.
		quiverStrap(make, front - 0.05, 0.16, NIGHT_STONE, LEATHER_MATERIAL)
		local strapFrom = Vector3.new(width * 0.3, height / 2 - 0.02, front - 0.09)
		local strapTo = Vector3.new(-width * 0.4, -height / 2 + 0.12, front - 0.09)
		for _, t in { 0.18, 0.72, 0.88 } do
			make.block(Vector3.one * 0.1, TITAN_GOLD, SMOOTH, CFrame.new(strapFrom:Lerp(strapTo, t)))
		end
		local medallion = CFrame.new(strapFrom:Lerp(strapTo, 0.45) + Vector3.new(0, 0, -0.02))
		make.block(Vector3.new(0.5, 0.5, 0.06), TITAN_GOLD, SMOOTH, medallion)
		make.block(Vector3.new(0.38, 0.38, 0.06), JADE, SMOOTH, medallion * CFrame.new(0, 0, -0.03))
		jag.paw(make, 0.3, TITAN_GOLD, SMOOTH, medallion * CFrame.new(0, 0.02, -0.06))

		-- Cinturón de piedra con banda de oro y hebilla de jade, taparrabos de pelaje con roseta (delante y detrás).
		local waist = body.waist
		local hipWidth, hipDepth = waist.size.X, waist.size.Z
		local beltFront = -(hipDepth / 2 + 0.09)
		waist.block(Vector3.new(hipWidth + 0.16, 0.24, hipDepth + 0.18), NIGHT_STONE, SLATE, CFrame.new(0, 0.05, 0))
		waist.block(Vector3.new(hipWidth + 0.18, 0.05, hipDepth + 0.2), TITAN_GOLD, SMOOTH, CFrame.new(0, 0.15, 0))
		local buckle = CFrame.new(0, 0.05, beltFront - 0.03)
		waist.block(Vector3.new(0.44, 0.34, 0.06), TITAN_GOLD, SMOOTH, buckle)
		waist.block(Vector3.new(0.3, 0.24, 0.06), JADE, SMOOTH, buckle * CFrame.new(0, 0, -0.04))
		for _, z in { beltFront + 0.02, -beltFront - 0.02 } do
			local isFront = z < 0
			waist.block(Vector3.new(hipWidth * 0.4, 0.6, 0.06), JAGUAR, FABRIC, CFrame.new(0, -0.38, z))
			waist.block(Vector3.new(hipWidth * 0.42, 0.06, 0.08), TITAN_GOLD, SMOOTH, CFrame.new(0, -0.66, z))
			jag.rosette(
				waist,
				0.2,
				CFrame.new(0.04, -0.34, z + (if isFront then -0.035 else 0.035))
					* (if isFront then CFrame.identity else BEHIND)
			)
			if grade >= 2 then
				for index = -1, 1 do
					jag.claw(waist, index * hipWidth * 0.12, -0.69, z, 0.2, 0.1, JAGUAR_CREAM, FABRIC)
				end
			end
		end
		if grade >= 1 then
			for side = -1, 1, 2 do
				for _, x in { 0.22, 0.4 } do
					waist.block(
						Vector3.one * 0.09,
						TITAN_GOLD,
						SMOOTH,
						CFrame.new(side * hipWidth * x, 0.05, beltFront - 0.02)
					)
				end
			end
		end

		-- La cola del jaguar: nueve bloques de pelaje que bajan y se curvan hacia atrás, con tres anillos negros y la
		-- punta negra. Cada uno: x en anchos del cinturón, y, z detrás de la cintura y grosor.
		local tail = {
			{ 0.1, -0.06, 0.16, 0.28 },
			{ 0.14, -0.32, 0.3, 0.27 },
			{ 0.18, -0.58, 0.42, 0.26 },
			{ 0.22, -0.84, 0.5, 0.25 },
			{ 0.25, -1.1, 0.54, 0.24 },
			{ 0.23, -1.36, 0.6, 0.22 },
			{ 0.19, -1.6, 0.7, 0.2 },
			{ 0.14, -1.78, 0.84, 0.18 },
			{ 0.1, -1.86, 1.0, 0.16 },
		}
		for index, piece in tail do
			local at = CFrame.new(hipWidth * piece[1], piece[2], hipDepth / 2 + piece[3])
			local thick = piece[4]
			waist.block(Vector3.new(thick, 0.3, thick), if index == #tail then ROSETTE else JAGUAR, FABRIC, at)
			if index == 3 or index == 5 or index == 7 then
				waist.block(
					Vector3.new(thick + 0.04, 0.07, thick + 0.04),
					ROSETTE,
					SMOOTH,
					at * CFrame.new(0, -0.03, 0)
				)
			end
		end

		-- Brazos: brazaletes de oro con jade; brazal de piedra de noche en el del arco (derecho) y, en el otro, un puño
		-- de pelaje con tres garras de oro (de luz en las puntas desde el grado 3). Grado 1: manguito crema.
		for side = -1, 1, 2 do
			local upper = body.upperArm[side]
			local us = upper.size
			band(upper, -us.Y * 0.2, 0.12, 0.08, TITAN_GOLD, SMOOTH)
			upper.block(Vector3.one * 0.15, JADE, SMOOTH, CFrame.new(side * (us.X / 2 + 0.06), -us.Y * 0.2, 0))
			if grade >= 1 then
				band(upper, -us.Y * 0.34, 0.18, 0.12, JAGUAR_CREAM, FABRIC)
			end
			if grade >= 2 then
				-- Tres dientes crema que cuelgan del manguito: delante, detrás y por fuera.
				for _, tooth in { { 0, -1 }, { 0, 1 }, { side, 0 } } do
					jag.claw(
						upper,
						tooth[1] * (us.X / 2 + 0.08),
						-us.Y * 0.34 - 0.09,
						tooth[2] * (us.Z / 2 + 0.08),
						0.26,
						0.12,
						JAGUAR_CREAM,
						FABRIC
					)
				end
			end
			local forearm = body.lowerArm[side]
			local fs = forearm.size
			if side > 0 then
				band(forearm, 0.02, fs.Y * 0.6, 0.1, NIGHT_STONE, SLATE)
				for _, y in { fs.Y * 0.3, -fs.Y * 0.26 } do
					band(forearm, y, 0.06, 0.14, TITAN_GOLD, SMOOTH)
				end
				forearm.block(Vector3.new(0.06, 0.24, 0.2), JADE, SMOOTH, CFrame.new(fs.X / 2 + 0.08, 0.02, 0))
			else
				band(forearm, -fs.Y / 2 + 0.16, 0.26, 0.14, JAGUAR, FABRIC)
				band(forearm, -fs.Y / 2 + 0.3, 0.06, 0.16, TITAN_GOLD, SMOOTH)
				for _, z in { -0.18, 0, 0.18 } do
					jag.claw(
						forearm,
						-(fs.X / 2 + 0.06),
						-fs.Y / 2 + 0.16,
						z,
						0.34,
						0.1,
						TITAN_GOLD,
						SMOOTH,
						if lit then SPECTRAL else nil,
						if lit then NEON else nil
					)
				end
			end
			if grade >= 1 then
				jaguarPauldron(upper, side, grade)
			end
			-- Muslos. Grado 1: banda de oro, banda de pelaje, cuenta de jade y roseta. Grado 2: faldón de pelaje con el
			-- canto de oro, roseta, jade y dos dientes crema. Grado 3: tres zarpazos de luz delante del faldón.
			local leg = body.upperLeg[side]
			local ls = leg.size
			if grade >= 1 then
				band(leg, -ls.Y * 0.34, 0.1, 0.12, TITAN_GOLD, SMOOTH)
				band(leg, -ls.Y * 0.12, 0.16, 0.08, JAGUAR, FABRIC)
				leg.block(Vector3.one * 0.12, JADE, SMOOTH, CFrame.new(side * (ls.X / 2 + 0.1), -ls.Y * 0.34, 0))
				jag.rosette(
					leg,
					0.2,
					CFrame.new(side * (ls.X / 2 + 0.06), -ls.Y * 0.12, 0) * CFrame.Angles(0, -side * math.pi / 2, 0)
				)
			end
			local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.06))
			if grade >= 2 then
				leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.42, 0.1), JAGUAR, FABRIC, flap)
				leg.block(
					Vector3.new(ls.X * 0.92, 0.06, 0.12),
					TITAN_GOLD,
					SMOOTH,
					flap * CFrame.new(0, -ls.Y * 0.2, 0)
				)
				leg.block(Vector3.one * 0.14, ROSETTE, SMOOTH, flap * CFrame.new(-side * 0.12, 0.04, -0.05))
				leg.block(Vector3.one * 0.12, JADE, SMOOTH, flap * CFrame.new(side * 0.1, -0.06, -0.06))
				for _, x in { -0.22, 0.22 } do
					jag.claw(
						leg,
						flap.X + x * ls.X,
						flap.Y - ls.Y * 0.23,
						flap.Z - 0.04,
						0.2,
						0.1,
						JAGUAR_CREAM,
						FABRIC
					)
				end
			end
			if grade >= 3 then
				local glow = Vector3.new(flap.X, flap.Y, flap.Z - 0.14)
				for index = -1, 1 do
					strap(
						leg,
						glow + Vector3.new(index * ls.X * 0.28 + ls.X * 0.1, ls.Y * 0.15, 0),
						glow + Vector3.new(index * ls.X * 0.28 - ls.X * 0.1, -ls.Y * 0.15, 0),
						0.04,
						SPECTRAL,
						NEON
					)
				end
				leg.block(Vector3.one * 0.07, SPECTRAL, NEON, CFrame.new(glow + Vector3.new(0, -ls.Y * 0.17, 0)))
			end
		end

		-- Grado 2: manto y capa de pelaje con rosetas, fleco de garras, broches con cadena, mechones por los lados y
		-- gotas de jade en el bajo.
		local quiverOut = 0.06
		local capeSpots = {
			{ -0.34, 0.22 },
			{ 0.32, 0.12 },
			{ -0.12, -0.12 },
			{ 0.36, -0.32 },
			{ -0.36, -0.4 },
			{ 0.06, -0.62 },
			{ -0.2, -0.82 },
			{ 0.3, -0.78 },
		}
		if grade >= 2 then
			quiverOut = 0.32
			make.block(
				Vector3.new(width + 0.36, 0.32, depth * 0.62),
				JAGUAR,
				FABRIC,
				CFrame.new(0, height / 2 - 0.06, depth * 0.24)
			)
			make.block(
				Vector3.new(width * 1.02, capeHeight, 0.12),
				JAGUAR,
				FABRIC,
				CFrame.new(0, capeTop - capeHeight / 2, capeZ)
			)
			for _, spot in capeSpots do
				jag.rosette(
					make,
					0.3,
					CFrame.new(spot[1] * width, capeTop + spot[2] * capeHeight * 0.8 - 0.1, capeZ + 0.075) * BEHIND
				)
			end
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
				-- Tres mechones crema que cuelgan por cada lado de la capa.
				for index = 0, 2 do
					jag.claw(
						make,
						side * (width * 0.5 + 0.08),
						capeTop - capeHeight * (0.2 + index * 0.27),
						capeZ + 0.01,
						if index % 2 == 0 then 0.28 else 0.2,
						0.12,
						JAGUAR_CREAM,
						FABRIC
					)
				end
			end
			-- Fleco de garras de oro y crema en el bajo, con gotas de jade entre ellas.
			for index = 0, 6 do
				jag.claw(
					make,
					(index / 6 - 0.5) * width * 0.92,
					capeBottom + 0.02,
					capeZ,
					if index % 2 == 0 then 0.32 else 0.22,
					0.13,
					if index % 2 == 0 then TITAN_GOLD else JAGUAR_CREAM,
					SMOOTH
				)
			end
			for index = 0, 5 do
				make.block(
					Vector3.one * 0.1,
					JADE,
					SMOOTH,
					CFrame.new(((index + 0.5) / 6 - 0.5) * width * 0.92, capeBottom + 0.14, capeZ + 0.08)
				)
			end
			-- Broches de oro con jade y la cadena entre ellos, por delante del pecho.
			local clasps = {}
			for side = -1, 1, 2 do
				local clasp = CFrame.new(side * width * 0.36, height / 2 - 0.12, front - 0.06)
				make.block(Vector3.new(0.26, 0.26, 0.08), TITAN_GOLD, SMOOTH, clasp)
				make.block(Vector3.one * 0.14, JADE, SMOOTH, clasp * CFrame.new(0, 0, -0.06))
				clasps[side] = Vector3.new(clasp.X, clasp.Y, front - 0.12)
			end
			local sag = Vector3.new(0, height / 2 - 0.3, front - 0.12)
			stairs(make, clasps[-1], sag, 0.05, 0.05, TITAN_GOLD, SMOOTH, 4)
			stairs(make, sag, clasps[1], 0.05, 0.05, TITAN_GOLD, SMOOTH, 4)
			-- La capucha: la cabeza del jaguar a la espalda (grado 2) o, desde el grado 3, vacía, porque el espíritu ha
			-- salido de ella.
			if grade == 2 then
				jag.head(
					make,
					CFrame.new(0, height / 2 - 0.36, capeZ + 0.42) * BEHIND,
					1.1,
					0.8,
					JADE,
					SMOOTH,
					JAGUAR,
					JAGUAR_CREAM,
					FABRIC,
					false
				)
			else
				blockHood(make, JAGUAR, ROSETTE, FABRIC)
			end
		end

		-- El carcaj de piedra de noche con aros de oro, un aro de pelaje con jade y flechas de plumas negras y doradas
		-- (grado 4: arden en luz).
		local quiverAt = backQuiver(make, {
			length = 1.85,
			radius = 0.26,
			color = NIGHT_STONE,
			material = SLATE,
			rim = TITAN_GOLD,
			rimMaterial = SMOOTH,
			arrows = if grade >= 4 then 8 elseif grade >= 3 then 7 elseif grade >= 2 then 6 else 5,
			feathers = { ROSETTE, TITAN_GOLD },
		}, quiverOut)
		local quiverAxis = quiverAt:VectorToWorldSpace(Vector3.yAxis)
		make.block(Vector3.new(0.78, 0.22, 0.6), JAGUAR, FABRIC, CFrame.new(quiverAt.Position))
		for _, along in { 0.42, -0.42 } do
			make.block(
				Vector3.new(0.76, 0.07, 0.58),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(quiverAt.Position + quiverAxis * along)
			)
		end
		make.block(Vector3.one * 0.16, JADE, SMOOTH, CFrame.new(quiverAt.Position + Vector3.new(0, 0, 0.3)))

		-- Grado 3: el espíritu del jaguar, translúcido, asoma por encima del hombro izquierdo mirando atrás: la cabeza
		-- rugiendo con su halo de espinas, el cuello que se deshace en jirones de niebla y una pata sobre el hombro.
		if grade >= 3 then
			local ghost: { BasePart } = {}
			local function keep(piece: BasePart)
				table.insert(ghost, piece)
			end
			local headAt = CFrame.new(-width * 0.4, height / 2 + 0.2, back + 0.85)
				* BEHIND
				* CFrame.Angles(0.1, -0.35, 0.12)
			local headParts, spiritEyes =
				jag.head(make, headAt, 1.5, 1, SPECTRAL, NEON, SPECTRAL_BODY, SPECTRAL_PALE, GLASS, false)
			for _, piece in headParts do
				if not table.find(spiritEyes, piece) then
					keep(piece)
				end
			end
			fireLight(spiritEyes[1], SPECTRAL)
			-- Sombra de piedra de noche (mate, entra en la malla) detrás de la cabeza, el cuello y la pata: el contorno
			-- oscuro con el que el espíritu se lee sobre un fondo claro.
			make.block(Vector3.new(1.75, 1.6, 0.1), NIGHT_STONE, SLATE, headAt * CFrame.new(0, 0.04, 0.8))
			-- Halo: nueve espinas de cristal detrás de la cabeza (menos por abajo, en el cuello) y cuatro estrellitas.
			for index = 0, 8 do
				local angle = math.rad(-120 + index * 30)
				keep(
					make.block(
						Vector3.new(0.24, 0.6, 0.12),
						SPECTRAL_PALE,
						GLASS,
						headAt
							* CFrame.new(-math.sin(angle) * 1.15, math.cos(angle) * 1.15 + 0.02, 0.5)
							* CFrame.Angles(0, 0, angle)
					)
				)
			end
			for index = 0, 3 do
				make.block(
					Vector3.one * 0.07,
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
			-- Cuello con manchas oscuras y cuatro jirones de niebla que cuelgan de él.
			local neck = headAt.Position + Vector3.new(0.1, -0.6, -0.12)
			make.block(Vector3.new(1.25, 0.9, 0.1), NIGHT_STONE, SLATE, CFrame.new(neck + Vector3.new(0, -0.05, -0.45)))
			keep(make.block(Vector3.new(1.05, 0.7, 0.8), SPECTRAL_BODY, GLASS, CFrame.new(neck)))
			for _, spot in { { -0.2, 0.08 }, { 0.18, 0.1 }, { 0, -0.1 } } do
				keep(
					make.block(
						Vector3.new(0.16, 0.12, 0.04),
						SPECTRAL_SPOT,
						GLASS,
						CFrame.new(neck + Vector3.new(spot[1], spot[2], 0.42))
					)
				)
			end
			for index, wisp in { { -0.3, 1.3, 0.3 }, { -0.05, 1.7, 0.3 }, { 0.2, 1.2, 0.26 }, { 0.4, 0.9, 0.22 } } do
				for _, piece in
					{
						make.block(
							Vector3.new(wisp[3], wisp[2] * 0.55, wisp[3]),
							SPECTRAL_BODY,
							GLASS,
							CFrame.new(neck.X + wisp[1], neck.Y - 0.35 - wisp[2] * 0.275, neck.Z + 0.05 * index)
						),
						make.block(
							Vector3.new(wisp[3] * 0.6, wisp[2] * 0.45, wisp[3] * 0.6),
							SPECTRAL_BODY,
							GLASS,
							CFrame.new(neck.X + wisp[1], neck.Y - 0.35 - wisp[2] * 0.775, neck.Z + 0.05 * index)
						),
					}
				do
					keep(piece)
				end
			end
			-- La pata sobre el hombro: un brazo largo que va de la espalda al pecho, el antebrazo que baja, la mano con
			-- tres dedos y tres garras de luz (adelantada del pecho).
			local handZ = front - 0.2
			local armLength = back + 0.65 - handZ
			make.block(
				Vector3.new(0.5, 0.5, armLength),
				NIGHT_STONE,
				SLATE,
				CFrame.new(-width * 0.5, height / 2 + 0.14, (back + 0.65 + handZ) / 2)
			)
			keep(
				make.block(
					Vector3.new(0.32, 0.32, armLength),
					SPECTRAL_BODY,
					GLASS,
					CFrame.new(-width * 0.5, height / 2 + 0.16, (back + 0.65 + handZ) / 2)
				)
			)
			keep(
				make.block(
					Vector3.new(0.32, 0.5, 0.32),
					SPECTRAL_BODY,
					GLASS,
					CFrame.new(-width * 0.5, height / 2 - 0.1, handZ)
				)
			)
			keep(
				make.block(
					Vector3.new(0.42, 0.3, 0.38),
					SPECTRAL_BODY,
					GLASS,
					CFrame.new(-width * 0.5, height / 2 - 0.5, handZ)
				)
			)
			for index = -1, 1 do
				keep(
					make.block(
						Vector3.new(0.12, 0.1, 0.14),
						SPECTRAL_BODY,
						GLASS,
						CFrame.new(-width * 0.5 + index * 0.13, height / 2 - 0.6, handZ - 0.2)
					)
				)
				make.block(
					Vector3.new(0.06, 0.18, 0.06),
					SPECTRAL,
					NEON,
					CFrame.new(-width * 0.5 + index * 0.13, height / 2 - 0.74, handZ - 0.22)
				)
			end
			-- Rastro del espíritu: cuatro cubos de cristal que se afinan hacia atrás desde la punta de la cola.
			local tip = tail[#tail]
			for index = 1, 4 do
				keep(
					waist.block(
						Vector3.one * (0.36 - index * 0.05),
						SPECTRAL_BODY,
						GLASS,
						CFrame.new(hipWidth * tip[1], tip[2] + index * 0.05, hipDepth / 2 + tip[3] + index * 0.25)
					)
				)
			end
			for _, piece in ghost do
				piece.Transparency = 0.3
			end
			-- Las rosetas de la capa que brillan: una luz del espíritu en el centro de cuatro de ellas.
			for _, index in { 1, 3, 5, 7 } do
				local spot = capeSpots[index]
				make.block(
					Vector3.one * 0.07,
					SPECTRAL,
					NEON,
					CFrame.new(spot[1] * width, capeTop + spot[2] * capeHeight * 0.8 - 0.1, capeZ + 0.12)
				)
			end

			-- Grado 4: luna creciente con estrellas detrás de la cabeza del espíritu, niebla, el mapa de estrellas de la
			-- capa y las flechas que arden en luz.
			if grade >= 4 then
				-- La luna: pixel art de plata (dos círculos de celdas, uno vaciado dentro del otro), una celda de luz por
				-- el filo de dentro y tres estrellas en cruz.
				local cell = 0.17
				local moon = Vector3.new(headAt.X - 0.5, headAt.Y + 0.95, headAt.Z - 0.35)
				for row = -6, 6 do
					local runFrom: number? = nil
					for col = -6, 7 do
						local inside = col <= 6
							and col * col + row * row <= 6.3 * 6.3
							and (col - 2.4) * (col - 2.4) + row * row > 5 * 5
						if inside and not runFrom then
							runFrom = col
						elseif not inside and runFrom then
							local count = col - runFrom
							make.block(
								Vector3.new(count * cell, cell, 0.1),
								MOON_SILVER,
								SMOOTH,
								CFrame.new(moon + Vector3.new((runFrom + col - 1) / 2 * cell, row * cell, 0))
							)
							-- Filo de luz: la celda de dentro de las filas centrales.
							if math.abs(row) <= 3 then
								make.block(
									Vector3.new(0.05, cell, 0.12),
									SPECTRAL,
									NEON,
									CFrame.new(moon + Vector3.new((col - 0.5) * cell + 0.025, row * cell, 0))
								)
							end
							runFrom = nil
						end
					end
				end
				for _, star in { Vector3.new(0.4, 0.55, 0), Vector3.new(0.85, 0.15, 0), Vector3.new(0.15, -0.1, 0) } do
					make.block(Vector3.new(0.2, 0.06, 0.05), STAR_GOLD, NEON, CFrame.new(moon + star))
					make.block(Vector3.new(0.06, 0.2, 0.05), STAR_GOLD, NEON, CFrame.new(moon + star))
				end
				-- Llama de luz en la frente del espíritu y niebla que cae del cuello.
				for index = 0, 3 do
					make.block(
						Vector3.new(0.1, 0.22 - math.abs(index - 1.5) * 0.05, 0.08),
						SPECTRAL,
						NEON,
						headAt * CFrame.new((index - 1.5) * 0.18, 0.78, 0.05)
					)
				end
				for index = 0, 2 do
					local mist = make.block(
						Vector3.one * (0.5 - index * 0.06),
						SPECTRAL_BODY,
						GLASS,
						CFrame.new(
							neck
								+ Vector3.new(
									math.sin(index * 1.7) * 0.35,
									-0.4 - index * 0.3,
									0.1 + math.cos(index * 1.3) * 0.15
								)
						)
					)
					mist.Transparency = 0.6
				end
				spectralMist(spiritEyes[2], 2)
				-- El mapa de estrellas del espíritu sobre la capa: seis estrellas unidas por líneas finas de luz.
				local stars =
					{ { -0.3, 0.3 }, { -0.1, 0.46 }, { 0.14, 0.4 }, { 0.3, 0.56 }, { 0.1, 0.7 }, { -0.22, 0.8 } }
				local previous: Vector3? = nil
				for _, star in stars do
					local at = Vector3.new(star[1] * width, capeTop - star[2] * capeHeight, capeZ + 0.12)
					make.block(Vector3.one * 0.08, SPECTRAL, NEON, CFrame.new(at))
					if previous then
						strap(make, previous, at, 0.025, SPECTRAL, NEON)
					end
					previous = at
				end
				-- Las flechas arden en luz: tres chispas y una luz en la boca del carcaj que echa chispas blancas azuladas.
				for index = 0, 2 do
					make.block(
						Vector3.one * 0.06,
						SPECTRAL,
						NEON,
						CFrame.new(
							quiverAt.Position
								+ quiverAxis * (1.12 + index * 0.04)
								+ Vector3.new(
									math.cos(index * math.pi * 2 / 3) * 0.14,
									0,
									math.sin(index * math.pi * 2 / 3) * 0.14
								)
						)
					)
				end
				local mouthLight = make.block(Vector3.one * 0.2, SPECTRAL, NEON, quiverAt * CFrame.new(0, 1.05, 0))
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

	-- Verde más oscuro del quetzal: las plumas de atrás y de las filas pares, para que se lean capas.
	local QUETZAL_DARK = Color3.fromRGB(26, 116, 58)

	-- Cuerpo de la serpiente de la espalda: verde quetzal claro, casi lima, para que destaque sobre la capa añil y
	-- sobre el penacho verde oscuro; el vientre es crema.
	local SERPENT_GREEN = Color3.fromRGB(44, 170, 104)
	local RAY_YELLOW = Color3.fromRGB(252, 212, 70)
	local RAY_ORANGE = Color3.fromRGB(246, 150, 50)
	local RAY_PALE = Color3.fromRGB(255, 240, 160)
	local RAY_GREEN = Color3.fromRGB(50, 168, 84)
	local RAY_TEAL = Color3.fromRGB(48, 190, 170)
	local JADE_GLOW = Color3.fromRGB(90, 235, 190)
	local SERPENT_GREEN_DARK = Color3.fromRGB(24, 120, 86)
	local SERPENT_CREAM = Color3.fromRGB(244, 232, 190)

	-- Cubo de "size" studs centrado en "at".
	local function cube(parent: Builder, at: Vector3, size: number, color: Color3, material: Enum.Material?): BasePart
		return parent.block(Vector3.one * size, color, material or SMOOTH, CFrame.new(at))
	end

	-- Pluma de quetzal en el plano XY, en bloques sin giro (entra en la malla): "base" es el centro de donde nace,
	-- "dir" 1 la saca hacia arriba y -1 hacia abajo, y "lean" desplaza la punta en X (la inclinación, a escalones).
	-- Tres piezas: la hoja verde (o "tone"), la punta turquesa (azul de runa que brilla con "lit") y el cañón de
	-- oro. El verde de las plumas no brilla nunca: lo único que se enciende es la punta.
	local function quetzalFeather(
		make: Builder,
		base: Vector3,
		length: number,
		dir: number,
		lean: number,
		lit: boolean,
		tone: Color3?
	)
		local width = length * 0.36
		make.block(
			Vector3.new(width, length * 0.58, 0.05),
			tone or QUETZAL,
			SMOOTH,
			CFrame.new(base + Vector3.new(lean * 0.2, dir * length * 0.29, 0))
		)
		make.block(
			Vector3.new(width * 0.74, length * 0.36, 0.065),
			if lit then RUNE else SCALE,
			if lit then NEON else SMOOTH,
			CFrame.new(base + Vector3.new(lean * 0.72, dir * length * 0.74, 0))
		)
		make.block(
			Vector3.new(0.025, length * 0.6, 0.08),
			TITAN_GOLD,
			SMOOTH,
			CFrame.new(base + Vector3.new(lean * 0.4, dir * length * 0.32, 0))
		)
	end

	-- Cuerpo de la serpiente por los puntos de "points" (tramos rectos o en diagonal de escalones, sin giros):
	-- trozos de escamas turquesa y oscuras con un anillo de oro cada cinco, y un codo en cada esquina.
	local function serpentRun(make: Builder, points: { Vector3 }, thickness: number)
		local count = 0
		for index = 1, #points - 1 do
			local from, to = points[index], points[index + 1]
			local delta = to - from
			local chunks = math.max(1, math.round(delta.Magnitude / 0.42))
			local function span(value: number): number
				if math.abs(value) < 0.001 then
					return thickness
				end
				return math.max(math.abs(value) / chunks + 0.03, thickness)
			end
			local size = Vector3.new(span(delta.X), span(delta.Y), span(delta.Z))
			for step = 0, chunks - 1 do
				local color = if count % 5 == 4 then TITAN_GOLD elseif count % 2 == 1 then SCALE_DARK else SCALE
				make.block(size, color, SMOOTH, CFrame.new(from:Lerp(to, (step + 0.5) / chunks)))
				count += 1
			end
			if index < #points - 1 then
				cube(make, to, thickness * 1.02, SCALE)
			end
		end
	end

	-- Cabeza de la serpiente emplumada, de perfil y en bloques sin giro, centrada en "at". Mira hacia +X o -X de
	-- "at" ("faceX", signo "s") o hacia -Z/+Z (con "faceX" en false, "s" -1 es hacia delante). "u" es su
	-- escala (el largo del cráneo al hocico mide unas 2 u). Cráneo con banda de oro, hocico, boca roja abierta,
	-- mandíbula caída, dos colmillos de oro, cuello, ojos oscuros con la pupila rasgada de "eye" (los únicos que
	-- brillan) y cejas de oro; con "tongue", la lengua bífida; detrás, una cresta de "crest" plumas de quetzal
	-- abiertas hacia atrás. Devuelve las dos pupilas.
	local function serpentHead(
		make: Builder,
		at: Vector3,
		faceX: boolean,
		s: number,
		u: number,
		eye: Color3,
		eyeMaterial: Enum.Material,
		crest: number,
		lit: boolean,
		tongue: boolean,
		skin: Color3?,
		skinDark: Color3?
	): { BasePart }
		local skull = skin or SCALE
		local skullDark = skinDark or SCALE_DARK
		-- f: hacia delante, y: arriba, w: a un lado; sf, sy, sw: el tamaño en esos tres ejes (en unidades de u).
		local function box(
			f: number,
			y: number,
			w: number,
			sf: number,
			sy: number,
			sw: number,
			color: Color3,
			material: Enum.Material
		): BasePart
			local offset = if faceX then Vector3.new(s * f, y, w) else Vector3.new(w, y, s * f)
			local size = if faceX then Vector3.new(sf, sy, sw) else Vector3.new(sw, sy, sf)
			return make.block(size * u, color, material, CFrame.new(at + offset * u))
		end
		box(-0.15, 0.1, 0, 0.95, 0.55, 0.6, skull, SMOOTH)
		box(-0.35, 0.39, 0, 0.12, 0.06, 0.64, TITAN_GOLD, SMOOTH)
		box(-0.85, 0, 0, 0.5, 0.45, 0.45, skull, SMOOTH)
		box(0.62, 0.15, 0, 0.7, 0.26, 0.46, skull, SMOOTH)
		box(1.05, 0.12, 0, 0.2, 0.18, 0.36, skullDark, SMOOTH)
		box(0.55, -0.1, 0, 0.75, 0.2, 0.38, SERPENT_MOUTH, SMOOTH)
		box(0.45, -0.3, 0, 0.85, 0.14, 0.44, skullDark, SMOOTH)
		if u >= 0.8 then
			-- Escamas en el cráneo, púas de oro en la nuca, escudos bajo la mandíbula y, a cada lado, la ventana de la
			-- nariz, tres dientes de crema y una placa de oro en la mejilla.
			for row = 0, 2 do
				box(-0.5 + row * 0.38, 0.4, 0, 0.28, 0.07, 0.44 - row * 0.06, SCALE, SMOOTH)
			end
			for spike = 0, 2 do
				box(-0.66 - spike * 0.17, 0.3 - spike * 0.08, 0, 0.1, 0.3 - spike * 0.06, 0.12, TITAN_GOLD, SMOOTH)
			end
			for scute = 0, 1 do
				box(0.25 + scute * 0.45, -0.39, 0, 0.3, 0.05, 0.34, SERPENT_CREAM, SMOOTH)
			end
			for side = -1, 1, 2 do
				box(1.0, 0.22, side * 0.21, 0.06, 0.07, 0.05, SERPENT_EYE, SMOOTH)
				for tooth = 0, 2 do
					box(0.4 + tooth * 0.22, 0.0, side * 0.19, 0.08, 0.1, 0.05, SERPENT_CREAM, SMOOTH)
				end
				box(-0.1, -0.1, side * 0.32, 0.3, 0.22, 0.04, TITAN_GOLD, SMOOTH)
			end
		end
		local eyes = {}
		for side = -1, 1, 2 do
			box(0.9, -0.12, side * 0.15, 0.07, 0.22, 0.07, TITAN_GOLD, SMOOTH)
			box(0.05, 0.22, side * 0.32, 0.2, 0.2, 0.08, SERPENT_EYE, SMOOTH)
			table.insert(eyes, box(0.05, 0.22, side * 0.375, 0.05, 0.14, 0.03, eye, eyeMaterial))
			box(0.05, 0.34, side * 0.34, 0.3, 0.05, 0.1, TITAN_GOLD, SMOOTH)
		end
		if tongue then
			box(1.35, -0.1, 0, 0.5, 0.04, 0.05, QUETZAL_RED, SMOOTH)
			for side = -1, 1, 2 do
				box(1.7, -0.1, side * 0.06, 0.22, 0.04, 0.04, QUETZAL_RED, SMOOTH)
			end
		end
		for index = 1, crest do
			local t = if crest == 1 then 0 else (index - 1) / (crest - 1)
			local length = (1 - t * 0.25) * u
			local base: Vector3
			local lean: number
			if faceX then
				base = at + Vector3.new(-s * 0.5 * u, 0.34 * u, (index - (crest + 1) / 2) * 0.08 * u)
				lean = -s * (0.25 + t * 0.45) * length
			else
				local spread = t * 2 - 1
				base = at + Vector3.new(spread * 0.2 * u, 0.34 * u, s * -0.5 * u + (index % 2) * 0.04)
				lean = spread * 0.55 * length
			end
			quetzalFeather(
				make,
				base,
				length,
				1,
				lean,
				lit and index == 1,
				if index % 2 == 0 then QUETZAL_DARK else nil
			)
		end
		return eyes
	end

	-- Disco de mosaico turquesa de 7 x 7 celdas de "cell" studs (sin las esquinas), en el plano XY de "centre", con
	-- el relieve hacia "out" (1: hacia +Z, la espalda; -1: hacia -Z, el pecho): fondo oscuro, aro de oro, ocho
	-- teselas (cuatro turquesa y cuatro jade). Dieciocho piezas; la cabeza va aparte, encima.
	local function serpentMosaic(make: Builder, centre: Vector3, cell: number, out: number)
		local function slab(column: number, row: number, columns: number, rows: number, lift: number, color: Color3)
			make.block(
				Vector3.new(cell * columns, cell * rows, 0.06),
				color,
				SMOOTH,
				CFrame.new(centre + Vector3.new(column * cell, row * cell, out * lift))
			)
		end
		slab(0, 0, 7, 3, 0, SCALE_DARK)
		slab(0, 0, 5, 5, 0, SCALE_DARK)
		for sign = -1, 1, 2 do
			slab(0, sign * 3, 3, 1, 0.04, TITAN_GOLD)
			slab(sign * 3, 0, 1, 3, 0.04, TITAN_GOLD)
			for sx = -1, 1, 2 do
				slab(sx * 2, sign * 2, 1, 1, 0.04, TITAN_GOLD)
				slab(sx * 2, sign * 1, 0.9, 0.9, 0.07, SCALE)
				slab(sx * 1, sign * 2, 0.9, 0.9, 0.07, JADE)
			end
		end
	end

	-- Hombrera de la Serpiente (grado 1+), en bloques sin giro. Tres láminas de escamas que bajan hacia fuera
	-- (la de abajo con el canto de oro) con tres lomos de escamas cruzados, tachones de jade y, detrás, un
	-- abanico de plumas de quetzal sobre un broche de oro: lo que se ve desde la espalda. Por grados: 1, las láminas,
	-- los tachones y un abanico de tres plumas; 2, el abanico de cinco y dos plumas rojas que cuelgan del canto de
	-- fuera; 3, la cabeza de la serpiente sobre las láminas, mirando al frente, con los ojos de runa; 4, otra
	-- fila de tres plumas largas detrás, la del centro con la punta encendida.
	local function serpentPauldron(arm: Builder, side: number, grade: number)
		local as = arm.size
		local top = as.Y / 2
		local W, D = as.X, as.Z
		local lit = grade >= 3
		local lames = {
			{ w = 1.3, depth = 1.35, y = 0.24, out = 0.06, color = SCALE },
			{ w = 1.55, depth = 1.45, y = 0.06, out = 0.16, color = SCALE_DARK },
			{ w = 1.8, depth = 1.55, y = -0.12, out = 0.27, color = SCALE },
		}
		for index, lame in lames do
			local at = Vector3.new(side * lame.out, top + lame.y, 0)
			local size = Vector3.new(W * lame.w, 0.2, D * lame.depth)
			arm.block(size, lame.color, SMOOTH, CFrame.new(at))
			local ridge = if lame.color == SCALE then SCALE_DARK else SCALE
			for _, x in { -0.3, 0, 0.3 } do
				arm.block(
					Vector3.new(0.12, 0.24, size.Z + 0.08),
					ridge,
					SMOOTH,
					CFrame.new(at + Vector3.new(x * size.X, 0, 0))
				)
			end
			if index == 3 then
				arm.block(
					Vector3.new(size.X + 0.06, 0.06, size.Z + 0.06),
					TITAN_GOLD,
					SMOOTH,
					CFrame.new(at + Vector3.new(0, -0.12, 0))
				)
			end
		end
		-- Dos tachones de jade en las esquinas de delante de la lámina de arriba.
		for sx = -1, 1, 2 do
			cube(arm, Vector3.new(side * 0.06 + sx * W * 0.55, top + 0.42, -D * 0.68), 0.13, JADE)
		end
		-- Broche de oro y abanico de plumas de quetzal detrás, abierto hacia fuera.
		arm.block(Vector3.new(W * 1.1, 0.12, 0.22), TITAN_GOLD, SMOOTH, CFrame.new(side * 0.08, top + 0.36, D * 0.42))
		local count = if grade >= 2 then 5 else 3
		for index = 1, count do
			local spread = (index - (count + 1) / 2) / ((count - 1) / 2)
			local length = 1.2 - math.abs(spread) * 0.3
			quetzalFeather(
				arm,
				Vector3.new(side * 0.1 + spread * 0.34, top + 0.4, D * 0.42 + (index % 2) * 0.05),
				length,
				1,
				(spread * 0.55 + side * 0.2) * length,
				false,
				if index % 2 == 0 then QUETZAL_DARK else nil
			)
		end
		if grade >= 2 then
			for _, z in { -0.35, 0.35 } do
				quetzalFeather(
					arm,
					Vector3.new(side * (0.27 + W * 0.7), top - 0.22, z * D),
					0.55,
					-1,
					side * 0.08,
					false,
					QUETZAL_RED
				)
			end
		end
		if grade >= 3 then
			serpentHead(
				arm,
				Vector3.new(side * 0.12, top + 0.64, -0.02),
				false,
				-1,
				0.62,
				if lit then RUNE else JADE,
				if lit then NEON else SMOOTH,
				0,
				lit,
				false
			)
		end
		if grade >= 4 then
			for index = 1, 3 do
				local spread = index - 2
				quetzalFeather(
					arm,
					Vector3.new(side * 0.1 + spread * 0.3, top + 0.44, D * 0.42 + 0.14),
					1.7 - math.abs(spread) * 0.3,
					1,
					(spread * 0.5 + side * 0.15) * 1.5,
					spread == 0,
					QUETZAL_DARK
				)
			end
		end
	end

	-- Riqueza extra de la Serpiente. Grado 1: rombos de escamas en la espalda del cinturón, tachones de jade y
	-- bandas de oro y escamas en los muslos. Grado 3: una fila de plumas de quetzal por cada lado de la capa, seis
	-- runas de luz en sus cantos, cadenas con colgantes que bajan de los broches y dos plumas en el bajo de cada
	-- faldón (la serpiente que se alza está en el traje). Todo en bloques sin giro.
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
					CFrame.new(index * hipWidth * 0.13, 0.05, hipDepth / 2 + 0.11)
				)
			end
		end
		for side = -1, 1, 2 do
			for _, z in { -0.3, 0.3 } do
				cube(waist, Vector3.new(side * (hipWidth / 2 + 0.1), 0.05, z * hipDepth), 0.1, JADE)
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
			for index = 0, 2 do
				quetzalFeather(
					make,
					Vector3.new(side * (width * 0.5 + 0.12), capeTop - capeHeight * (0.15 + index * 0.25), capeZ + 0.02),
					0.5,
					-1,
					side * 0.1,
					false,
					if index % 2 == 0 then nil else QUETZAL_DARK
				)
				cube(
					make,
					Vector3.new(side * width * 0.43, capeTop - capeHeight * (0.12 + index * 0.27), capeZ + 0.2),
					0.1,
					RUNE,
					NEON
				)
			end
			-- Cadena de oro que baja del broche con un colgante de jade y una punta de oro.
			local top = Vector3.new(side * width * 0.36, height / 2 - 0.2, front - 0.12)
			make.block(Vector3.new(0.04, 0.9, 0.04), TITAN_GOLD, SMOOTH, CFrame.new(top + Vector3.new(0, -0.45, 0)))
			cube(make, top + Vector3.new(0, -0.95, 0), 0.15, JADE)
			cube(make, top + Vector3.new(0, -1.08, 0), 0.1, TITAN_GOLD)
			local leg = body.upperLeg[side]
			local ls = leg.size
			local hem = ls.Y / 2 - ls.Y * 0.22 - ls.Y * 0.2
			for index = 0, 1 do
				quetzalFeather(
					leg,
					Vector3.new(side * 0.04 + (index - 0.5) * ls.X * 0.4, hem - 0.03, -(ls.Z / 2 + 0.1)),
					0.4,
					-1,
					0,
					false,
					nil
				)
			end
		end
	end

	-- Pluma del abanico de "length" que nace en "base" (su +Y es hacia donde apunta; el CFrame lleva el giro del abanico):
	-- tres tramos que se ensanchan y se afilan (hoja), de los colores de "colors" de la base a la punta. Como está
	-- girada no entra en la malla: queda suelta (3 piezas por pluma).
	local function featherRay(
		make: Builder,
		base: CFrame,
		length: number,
		width: number,
		colors: { Color3 },
		tipMaterial: Enum.Material?,
		rib: boolean?
	)
		local cuts = { { 0, 0.34, 0.6 }, { 0.34, 0.76, 1 }, { 0.76, 1, 0.42 } }
		for index, cut in cuts do
			make.block(
				Vector3.new(width * cut[3], (cut[2] - cut[1]) * length + 0.02, 0.07),
				colors[index],
				if index == #cuts and tipMaterial then tipMaterial else SMOOTH,
				base * CFrame.new(0, (cut[1] + cut[2]) / 2 * length, 0)
			)
		end
		if rib then
			-- Raquis de oro por el centro de la pluma, algo más grueso que la hoja para que se vea por los dos lados.
			make.block(
				Vector3.new(0.06, length * 0.78, 0.1),
				TITAN_GOLD,
				SMOOTH,
				base * CFrame.new(0, length * 0.39, 0)
			)
		end
	end

	-- Cuerpo grueso de la serpiente de la espalda por los puntos de "points" (tramos rectos en X o en Y): trozos de
	-- "thickness" de grosor en verde claro y oscuro alternos, una banda crema cada cuatro, una escama de oro
	-- cada dos, un codo en cada esquina y, bajo cada tramo horizontal, una tira crema (el vientre).
	local function serpentCoil(make: Builder, points: { Vector3 }, thickness: number)
		local count = 0
		for index = 1, #points - 1 do
			local from, to = points[index], points[index + 1]
			local delta = to - from
			local chunks = math.max(1, math.round(delta.Magnitude / thickness))
			local function span(value: number): number
				if math.abs(value) < 0.001 then
					return thickness
				end
				return math.abs(value) / chunks + 0.03
			end
			local size = Vector3.new(span(delta.X), span(delta.Y), thickness)
			for step = 0, chunks - 1 do
				local at = from:Lerp(to, (step + 0.5) / chunks)
				local color = if count % 4 == 3
					then SERPENT_CREAM
					elseif count % 2 == 1 then SERPENT_GREEN_DARK
					else SERPENT_GREEN
				make.block(size, color, SMOOTH, CFrame.new(at))
				-- Escamas: una placa turquesa en cada trozo y, cada tres, un rombo de oro más grande encima.
				if count % 4 ~= 3 then
					make.block(
						Vector3.new(size.X * 0.7 + 0.02, size.Y * 0.7 + 0.02, 0.06),
						SCALE,
						SMOOTH,
						CFrame.new(at + Vector3.new(0, 0, thickness / 2 + 0.03))
					)
				end
				if count % 3 == 0 then
					cube(make, at + Vector3.new(0, 0, thickness / 2 + 0.08), 0.18, TITAN_GOLD)
				end
				count += 1
			end
			if index < #points - 1 then
				cube(make, to, thickness * 1.02, SERPENT_GREEN)
			end
			if math.abs(delta.Y) < 0.001 then
				make.block(
					Vector3.new(math.abs(delta.X), 0.1, thickness + 0.02),
					SERPENT_CREAM,
					SMOOTH,
					CFrame.new((from + to) / 2 + Vector3.new(0, -thickness / 2 + 0.05, 0))
				)
			end
		end
	end

	-- Traje mítico del mago, Serpiente Emplumada, todo en bloques alineados con los ejes y sin giros (es lo que
	-- entra en la malla; el neón queda suelto y es lo mínimo). Grado 0: túnica añil con ribetes de oro, pectoral de
	-- mosaico turquesa en un aro de oro con la cabeza de la serpiente en el centro, gorguera de oro con cuentas
	-- de jade, el cinturón es la propia serpiente (escamas con anillos de oro, la cabeza de hebilla y la cola
	-- colgando), taparrabos rojo de quetzal con tres plumas, brazaletes de oro y puños de plumas. Detrás, un
	-- disco de mosaico con un abanico de cinco plumas de quetzal. Grado 1: hombreras de escamas con abanico de
	-- plumas, el abanico de la espalda crece a siete y rombos y bandas en el cinturón y los muslos. Grado 2: capa de
	-- plumas de quetzal en dos filas, cuello de plumas, plumas en el pecho y en los puños de detrás, broches,
	-- faldones rojos y, de motivo en la espalda, la serpiente enroscada en espiral con la cabeza en el centro.
	-- Grado 3: la serpiente se alza en S por la capa y su cabeza grande, con las fauces abiertas, la lengua y una
	-- cresta de cinco plumas, asoma por encima de un hombro; tercera fila de plumas en la capa, plumas en los
	-- recodos, cabezas en las hombreras, ojos y aro de runas que brillan, y la riqueza extra. Grado 4: un penacho
	-- de nueve plumas largas y seis cortas, en dos filas, abierto como alas detrás de todo, una cola de plumas, otra pluma en el
	-- pecho, tres plumas más en cada hombrera, runas en el penacho y chispas.
	local function featheredSerpent(body: Body, grade: number)
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local lit = grade >= 3
		local eye = if lit then RUNE else JADE
		local eyeMaterial = if lit then NEON else SMOOTH
		local capeHeight = height * 1.16
		local capeTop = height / 2 - 0.05
		local capeZ = back + 0.2
		local coilZ = capeZ + 0.26
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

		-- Pectoral: disco de mosaico con aro de oro (adelantado para que no lo tape un avatar hondo) y, encima,
		-- la cabeza de la serpiente de perfil; desde el grado 3, tres runas de luz fuera del aro.
		local cell = 0.17
		local disc = Vector3.new(0, -height * 0.06, front - 0.1)
		serpentMosaic(make, disc, cell, -1)
		serpentHead(make, disc + Vector3.new(0, 0, -0.1), true, 1, 0.45, eye, eyeMaterial, 0, lit, false)
		if lit then
			for _, spot in { Vector3.new(4, 0, 0), Vector3.new(-4, 0, 0), Vector3.new(0, -4, 0) } do
				cube(make, disc + spot * cell + Vector3.new(0, 0, -0.1), 0.12, RUNE, NEON)
			end
		end

		-- Gorguera de oro (cuatro tramos alrededor del cuello) con cinco cuentas de jade por delante.
		local collarY = height / 2 - 0.02
		make.block(Vector3.new(width * 0.64, 0.14, 0.16), TITAN_GOLD, SMOOTH, CFrame.new(0, collarY, front))
		make.block(Vector3.new(width * 0.64, 0.14, 0.16), TITAN_GOLD, SMOOTH, CFrame.new(0, collarY, back + 0.04))
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.16, 0.14, depth * 0.7),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * width * 0.33, collarY, 0)
			)
		end
		for index = -2, 2 do
			cube(make, Vector3.new(index * 0.28, collarY - 0.12, front - 0.1), 0.12, JADE)
		end

		-- Espalda (grados 0 y 1): disco de mosaico con un abanico de plumas de quetzal (cinco; siete desde el
		-- grado 1).
		if grade < 2 then
			local sun = Vector3.new(0, height * 0.05, back + 0.2)
			local fan = if grade >= 1 then 7 else 5
			for index = 1, fan do
				local spread = (index - (fan + 1) / 2) / ((fan - 1) / 2)
				quetzalFeather(
					make,
					sun + Vector3.new(spread * 0.5, 0.35 - math.abs(spread) * 0.1, -0.1),
					1.15,
					1,
					spread * 0.6 * 1.15,
					false,
					if index % 2 == 0 then QUETZAL_DARK else nil
				)
			end
			serpentMosaic(make, sun, 0.2, 1)
			cube(make, sun + Vector3.new(0, 0, 0.1), 0.2, JADE)
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
					CFrame.new(index * hipWidth * 0.13, 0.05, beltFront - 0.02)
				)
			end
		end
		serpentHead(waist, Vector3.new(0, 0.06, beltFront - 0.12), true, -1, 0.42, eye, eyeMaterial, 0, lit, false)
		serpentRun(waist, {
			Vector3.new(hipWidth * 0.52, 0.0, -hipDepth * 0.2),
			Vector3.new(hipWidth * 0.52, -0.64, -hipDepth * 0.2),
			Vector3.new(hipWidth * 0.52 + 0.22, -0.64, -hipDepth * 0.2),
		}, 0.14)
		for _, z in { beltFront - 0.03, -beltFront + 0.03 } do
			waist.block(Vector3.new(hipWidth * 0.4, 0.6, 0.06), QUETZAL_RED, FABRIC, CFrame.new(0, -0.4, z))
			waist.block(Vector3.new(hipWidth * 0.42, 0.06, 0.08), TITAN_GOLD, SMOOTH, CFrame.new(0, -0.68, z))
		end
		for index = -1, 1 do
			quetzalFeather(waist, Vector3.new(index * 0.15, -0.7, beltFront - 0.08), 0.42, -1, index * 0.06, false, nil)
		end

		-- Brazos: brazaletes de oro con jade y puños de plumas de quetzal en las muñecas (dos por delante; desde
		-- el grado 2, otras dos por detrás). Las hombreras van desde el grado 1.
		local cuffSides = if grade >= 2 then { -1, 1 } else { -1 }
		for side = -1, 1, 2 do
			local upper = body.upperArm[side]
			local us = upper.size
			band(upper, -us.Y * 0.2, 0.12, 0.08, TITAN_GOLD, SMOOTH)
			cube(upper, Vector3.new(side * (us.X / 2 + 0.06), -us.Y * 0.2, 0), 0.15, JADE)
			local forearm = body.lowerArm[side]
			local fs = forearm.size
			band(forearm, -fs.Y / 2 + 0.3, 0.08, 0.12, TITAN_GOLD, SMOOTH)
			band(forearm, -fs.Y / 2 + 0.16, 0.2, 0.1, SCALE, SMOOTH)
			for _, sz in cuffSides do
				for _, x in { -0.2, 0.2 } do
					quetzalFeather(
						forearm,
						Vector3.new(x, -fs.Y / 2 + 0.3, sz * (fs.Z / 2 + 0.07)),
						0.4,
						-1,
						x * 0.2,
						false,
						if sz == 1 then QUETZAL_DARK else nil
					)
				end
			end
			if grade >= 1 then
				serpentPauldron(upper, side, grade)
			end
		end

		-- Grado 2: cuello y plumas de pecho de quetzal, broches con barra y faldones.
		if grade >= 2 then
			make.block(
				Vector3.new(width + 0.36, 0.3, depth * 0.62),
				MAGE_INDIGO_DARK,
				FABRIC,
				CFrame.new(0, height / 2 - 0.06, depth * 0.24)
			)
			for index = -2, 2 do
				quetzalFeather(
					make,
					Vector3.new(index * 0.3, height / 2 - 0.06, front - 0.2),
					0.42 - math.abs(index) * 0.04,
					-1,
					index * 0.05,
					false,
					nil
				)
			end
			-- Plumas a los lados del pecho: dos por lado (tres en el grado 4).
			for side = -1, 1, 2 do
				for index = 0, (if grade >= 4 then 2 else 1) do
					quetzalFeather(
						make,
						Vector3.new(side * (0.8 + index * 0.13), height * 0.3, front - 0.12 - index * 0.02),
						0.7 - index * 0.06,
						-1,
						side * 0.1,
						false,
						if index == 1 then QUETZAL_DARK else nil
					)
				end
				local clasp = Vector3.new(side * width * 0.36, height / 2 - 0.12, front - 0.06)
				make.block(Vector3.new(0.08, 0.3, 0.08), TITAN_GOLD, SMOOTH, CFrame.new(clasp))
				cube(make, clasp + Vector3.new(0, 0, -0.07), 0.15, JADE)
				local leg = body.upperLeg[side]
				local ls = leg.size
				local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.06))
				leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.42, 0.1), QUETZAL_RED, FABRIC, flap)
				leg.block(
					Vector3.new(ls.X * 0.92, 0.06, 0.12),
					TITAN_GOLD,
					SMOOTH,
					flap * CFrame.new(0, -ls.Y * 0.2, 0)
				)
				cube(leg, (flap * CFrame.new(0, 0.02, -0.07)).Position, 0.12, JADE)
			end
			make.block(
				Vector3.new(width * 0.72, 0.05, 0.05),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(0, height / 2 - 0.25, front - 0.1)
			)

			-- Capa: el paño añil liso con el canto de oro.
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
			-- Pliegues más claros (cinco tiras finas) y el bajo de oro: la capa se lee lisa.
			local capeBottom = capeTop - capeHeight
			for index = -2, 2 do
				make.block(
					Vector3.new(0.05, capeHeight * 0.84, 0.04),
					MAGE_INDIGO,
					FABRIC,
					CFrame.new(index * width * 0.2, capeTop - capeHeight * 0.5, capeZ + 0.07)
				)
			end
			make.block(
				Vector3.new(width * 1.02, 0.07, 0.14),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(0, capeBottom + 0.03, capeZ + 0.01)
			)
			-- Fleco inferior: una sola fila de plumas colgando, separadas, verde claro y oscuro alternos.
			local fringe = if grade >= 3 then 9 else 7
			for index = 0, fringe - 1 do
				quetzalFeather(
					make,
					Vector3.new((index / (fringe - 1) - 0.5) * width * 0.94, capeBottom + 0.05, capeZ + 0.08),
					0.5,
					-1,
					0,
					false,
					if index % 2 == 1 then QUETZAL_DARK else nil
				)
			end

			-- El motivo de la espalda: la serpiente verde claro enroscada en tres vueltas sobre la capa, con la cola a
			-- la izquierda y el cuello subiendo a la derecha hasta la cabeza de perfil, y detrás un penacho de
			-- plumas largas y separadas que sale de encima de ella. Por grados: 2, cabeza pequeña y cinco plumas;
			-- 3, cuello sobre el hombro, cabeza con lengua y cresta y siete plumas; 4, cabeza mayor, nueve plumas
			-- con otra fila de ocho cortas turquesa en los huecos, runas de luz en las puntas y chispas.
			-- La serpiente a un 80 % de su tamaño y centrada en la espalda: se calcula lo que ocupa de lado a lado (la cola, las
			-- vueltas, el cuello y la cabeza con el hocico y la lengua) y se desplaza "shiftX" para que quede a mitad de la capa.
			local scale = 0.8
			local thickness = 0.4 * scale
			local coilW = width * 0.4 * scale
			local rawY0, rawY1, rawY2 = -height * 0.5, -height * 0.14, height * 0.22
			local headScale = (if grade >= 4 then 1.15 elseif grade == 3 then 1.0 else 0.85) * scale
			local rawNeckY = if grade >= 3 then height / 2 + 0.2 + (grade - 3) * 0.15 else rawY2 + 0.45
			local middleY = (rawY0 + rawNeckY) / 2
			local function scaleY(y: number): number
				return middleY + (y - middleY) * scale
			end
			local y0, y1, y2, neckY = scaleY(rawY0), scaleY(rawY1), scaleY(rawY2), scaleY(rawNeckY)
			local neckX = -0.85 * headScale
			local minX = math.min(-0.72 * scale - 0.05, -coilW - thickness / 2, neckX - thickness / 2, -1.1 * headScale)
			local maxX = (if grade >= 3 then 1.81 else 1.15) * headScale
			local shiftX = -(minX + maxX) / 2
			local function at2(x: number, y: number): Vector3
				return Vector3.new(x + shiftX, y, coilZ)
			end
			serpentCoil(make, {
				at2(-0.2 * scale, y0),
				at2(coilW, y0),
				at2(coilW, y1),
				at2(-coilW, y1),
				at2(-coilW, y2),
				at2(neckX, y2),
				at2(neckX, neckY),
			}, thickness)
			-- La cola se afina y acaba en una punta de oro.
			cube(make, at2(-0.4 * scale, y0), 0.3 * scale, SERPENT_GREEN_DARK)
			cube(make, at2(-0.6 * scale, y0), 0.18 * scale, SERPENT_GREEN)
			cube(make, at2(-0.72 * scale, y0), 0.1 * scale, TITAN_GOLD)
			-- De perfil, mirando hacia fuera sobre el hombro: de frente una serpiente parece una rana. Ojos de oro.
			local eyes = serpentHead(
				make,
				at2(neckX + 0.85 * headScale, neckY),
				true,
				1,
				headScale,
				TITAN_GOLD,
				SMOOTH,
				if grade >= 3 then 3 else 0,
				false,
				grade >= 3,
				SERPENT_GREEN,
				SERPENT_GREEN_DARK
			)

			-- Abanico alrededor de la cabeza, como el de siempre de esta armadura: una fila corta de plumas naranjas y
			-- amarillas arriba (desde el grado 3) y, en el grado 4, diez plumas largas abiertas como alas a los lados, amarillas
			-- en la base y verdes en la punta, con rayos de oro entre ellas y un aro de runas turquesa que brilla. Todo
			-- girado (ninguna a 0 ni a 90 grados): queda suelto y no entra en la malla.
			local crown = CFrame.new(0, rawNeckY - 1.15, capeZ + 0.1)
			if grade >= 3 then
				for _, degrees in { 8, 18, 27 } do
					for side = -1, 1, 2 do
						featherRay(
							make,
							crown
								* CFrame.new(0, 0, -0.03)
								* CFrame.Angles(0, 0, math.rad(degrees) * side)
								* CFrame.new(0, 0.6, 0),
							1.4,
							0.28,
							{ RAY_ORANGE, RAY_YELLOW, RAY_PALE }
						)
					end
				end
			end
			if grade >= 4 then
				for _, degrees in { 36, 45, 54, 63, 72, 80, 88, 108 } do
					for side = -1, 1, 2 do
						local angle = math.rad(degrees) * side
						featherRay(
							make,
							crown * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.6, 0),
							2.16 - math.abs(degrees - 54) * 0.0084,
							0.3,
							{ RAY_GREEN, RAY_TEAL, JADE_GLOW },
							NEON,
							true
						)
						if degrees == 36 or degrees == 54 or degrees == 72 or degrees == 88 then
							make.block(
								Vector3.new(0.05, 0.66, 0.05),
								TITAN_GOLD,
								SMOOTH,
								crown * CFrame.Angles(0, 0, angle + side * math.rad(10)) * CFrame.new(0, 0.96, 0.04)
							)
						end
					end
				end
				hoop(make, crown * CFrame.new(0, 0.6, 0.02), 1.68, 14, 0.05, RUNE, NEON)
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
	-- Corteza del tronco, las ramas y el peto: marrón grisáceo oscuro y cálido, con vetas más claras, para que
	-- destaque sobre el lino claro y sobre la capa; la capa del grado 2+ es de tela clara.
	local TRUNK_BARK = Color3.fromRGB(88, 66, 52)
	local TRUNK_BARK_DARK = Color3.fromRGB(56, 42, 34)
	local TRUNK_VEIN = Color3.fromRGB(138, 110, 86)
	local CAPE_CLOTH = Color3.fromRGB(208, 200, 172)
	local KAPOK = Color3.fromRGB(246, 244, 236)
	local KAPOK_POD = Color3.fromRGB(112, 120, 70)
	local CEIBA_BLOSSOM = Color3.fromRGB(238, 140, 176)
	local HUMMINGBIRD = Color3.fromRGB(30, 150, 120)
	local HUMMINGBIRD_THROAT = Color3.fromRGB(200, 30, 60)

	-- Espina de ceiba (sin giros): tres bloques que se estrechan, de "length" de largo, que sale de "base" hacia
	-- el eje de "direction" que más pesa (X, Y o Z, con su signo).
	local function ceibaThorn(make: Builder, base: Vector3, direction: Vector3, length: number, width: number)
		local ax, ay, az = math.abs(direction.X), math.abs(direction.Y), math.abs(direction.Z)
		local axis = if ax >= ay and ax >= az then Vector3.xAxis elseif ay >= az then Vector3.yAxis else Vector3.zAxis
		local sign = if direction:Dot(axis) < 0 then -1 else 1
		for step = 0, 2 do
			local w = width * (1 - 0.3 * step)
			make.block(
				Vector3.one * w + axis * (length / 3 - w),
				CEIBA_THORN,
				SMOOTH,
				CFrame.new(base + axis * (sign * length / 3 * (step + 0.5)))
			)
		end
	end

	-- Flor de ceiba en "at" (mirando a su -Z): cuatro pétalos rosas en cruz y el centro de oro, que sobresale.
	local function ceibaBlossom(make: Builder, at: CFrame, size: number)
		for axis = 0, 1 do
			for side = -1, 1, 2 do
				make.block(
					Vector3.new(size * 0.34, size * 0.34, 0.05),
					CEIBA_BLOSSOM,
					SMOOTH,
					at * CFrame.new(side * size * 0.32 * (1 - axis), side * size * 0.32 * axis, 0)
				)
			end
		end
		make.block(Vector3.new(size * 0.3, size * 0.3, 0.08), TITAN_GOLD, SMOOTH, at * CFrame.new(0, 0, -0.03))
	end

	-- Fruto de ceiba de "size" colgando de "at" (su rabito): vaina verde parda; abierto ("open"), el algodón blanco
	-- que revienta por la raja (tres bloques de tela). Devuelve el algodón (o la vaina).
	local function kapokPod(make: Builder, at: CFrame, size: number, open: boolean): BasePart
		local pod =
			make.block(Vector3.new(size * 0.45, size, size * 0.45), KAPOK_POD, SMOOTH, at * CFrame.new(0, -size / 2, 0))
		if not open then
			return pod
		end
		local fluff = pod
		for index = -1, 1 do
			fluff = make.block(
				Vector3.one * size * (if index == 0 then 0.42 else 0.32),
				KAPOK,
				FABRIC,
				at * CFrame.new(index * size * 0.14, -size * (0.5 + index * 0.1), size * 0.2)
			)
		end
		return fluff
	end

	-- Cristal de jade en pie: dos tramos de cristal que se estrechan hacia arriba y, con "core", el núcleo que brilla
	-- en verde (lo único suelto del hombro).
	local function jadeSpire(make: Builder, base: Vector3, length: number, width: number, core: boolean)
		local lower = make.block(
			Vector3.new(width, length * 0.55, width),
			JADE_LIGHT,
			GLASS,
			CFrame.new(base + Vector3.new(0, length * 0.275, 0))
		)
		lower.Transparency = 0.3
		local upper = make.block(
			Vector3.new(width * 0.6, length * 0.45, width * 0.6),
			JADE_LIGHT,
			GLASS,
			CFrame.new(base + Vector3.new(0, length * 0.775, 0))
		)
		upper.Transparency = 0.3
		if core then
			make.block(
				Vector3.new(width * 0.35, length * 0.9, width * 0.35),
				HEAL_GLOW,
				NEON,
				CFrame.new(base + Vector3.new(0, length * 0.45, 0))
			)
		end
	end

	-- Hombrera de la Ceiba (grado 1+), todo de bloques alineados con los ejes (sin giros, apta para malla): láminas de
	-- lino con el canto de oro que bajan hacia fuera, una cresta de corteza con contrafuertes escalonados (tres
	-- niveles), remaches de oro, una espina de corteza hacia fuera y un fruto colgando.
	-- Grado 2: la tercera lámina, tres espinas sobre la cresta y una liana que baja por delante con una flor y una hoja.
	-- Grado 3: el fruto se abre (algodón) y detrás sale una aleta de corteza con canto de oro. Grado 4: la espina de en
	-- medio da paso a tres cristales de jade (el núcleo del grande y de los pequeños brilla en verde).
	local function ceibaPauldron(arm: Builder, side: number, grade: number)
		local as = arm.size
		local top = as.Y / 2
		local W, D = as.X, as.Z
		local lames = {
			{ w = 1.3, d = 1.4, y = 0.2, out = 0.05 },
			{ w = 1.55, d = 1.5, y = 0, out = 0.16 },
			{ w = 1.8, d = 1.6, y = -0.2, out = 0.28 },
		}
		local count = if grade >= 2 then 3 else 2
		for index = 1, count do
			local lame = lames[index]
			local at = CFrame.new(side * lame.out, top + lame.y, 0)
			local size = Vector3.new(W * lame.w, 0.18, D * lame.d)
			arm.block(size, LINEN, FABRIC, at)
			arm.block(Vector3.new(size.X + 0.08, 0.06, size.Z + 0.08), TITAN_GOLD, SMOOTH, at * CFrame.new(0, -0.11, 0))
		end
		local last = lames[count]
		local reach = W * last.w / 2 + last.out
		local rimY = top + last.y

		-- Cresta: base con un escalón más bajo en cada punta (contrafuertes), tramo medio oscuro y lomo.
		local crest = CFrame.new(side * 0.08, top + 0.29, 0)
		arm.block(Vector3.new(0.5, 0.2, D * 1.1), CEIBA_BARK, WOOD, crest * CFrame.new(0, 0.1, 0))
		for sz = -1, 1, 2 do
			arm.block(
				Vector3.new(0.34, 0.14, D * 0.3),
				CEIBA_BARK_DARK,
				WOOD,
				crest * CFrame.new(0, 0.07, sz * D * 0.7)
			)
		end
		arm.block(Vector3.new(0.36, 0.22, D * 0.8), CEIBA_BARK_DARK, WOOD, crest * CFrame.new(0, 0.31, 0))
		arm.block(Vector3.new(0.2, 0.2, D * 0.5), CEIBA_BARK, WOOD, crest * CFrame.new(0, 0.52, 0))
		-- Remaches de oro en las cuatro esquinas de la lámina de arriba.
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				arm.ball(0.1, TITAN_GOLD, SMOOTH, CFrame.new(side * 0.05 + sx * W * 0.62, top + 0.31, sz * D * 0.64))
			end
		end
		-- Espina hacia fuera, en el canto de la lámina de abajo.
		ceibaThorn(arm, Vector3.new(side * (reach - 0.02), rimY, 0), Vector3.new(side, 0, 0), 0.45, 0.2)
		-- Fruto: cerrado hasta el grado 2; desde el 3, abierto, con el algodón.
		kapokPod(
			arm,
			CFrame.new(side * (reach - 0.1), rimY - 0.1, D * 0.3),
			if grade >= 3 then 0.32 else 0.3,
			grade >= 3
		)

		if grade >= 2 then
			-- Espinas: dos sobre el tramo medio y, en el lomo, la de en medio (en el grado 4 se cambia por los cristales).
			for _, z in { -0.34, 0.34 } do
				ceibaThorn(arm, Vector3.new(side * 0.08, top + 0.71, z * D), Vector3.yAxis, 0.34, 0.12)
			end
			if grade < 4 then
				ceibaThorn(arm, Vector3.new(side * 0.08, top + 0.91, 0), Vector3.yAxis, 0.46, 0.14)
			end
			-- Liana por delante: dos tramos en escalera, una flor (adelantada, para que no la tape el torso) y una hoja.
			local zf = -(D * last.d / 2) - 0.07
			local p1 = Vector3.new(side * 0.1, top + 0.4, zf)
			local p2 = Vector3.new(side * 0.45, top + 0.05, zf)
			local p3 = Vector3.new(side * 0.75, top - 0.3, zf)
			stairs(arm, p1, p2, 0.08, 0.08, LIANA, FABRIC, 2)
			stairs(arm, p2, p3, 0.08, 0.08, LIANA, FABRIC, 2)
			ceibaBlossom(arm, CFrame.new(p2.X, p2.Y + 0.02, zf - 0.08), 0.26)
			tuft(arm, p3.X, p3.Y, zf, 0.2, 0.34, 0.05, LEAF, SMOOTH)
		end

		if grade >= 3 then
			-- Aleta de corteza detrás (lo que se ve de espaldas): losa con canto de oro, veta oscura y una cuenta de jade.
			local fin = CFrame.new(side * 0.15, top + 0.35, D * last.d / 2 + 0.08)
			arm.block(Vector3.new(W * 1.1, 0.7, 0.14), CEIBA_BARK, WOOD, fin)
			arm.block(Vector3.new(W * 1.1 + 0.06, 0.06, 0.18), TITAN_GOLD, SMOOTH, fin * CFrame.new(0, 0.35, 0))
			arm.block(Vector3.new(0.1, 0.5, 0.18), CEIBA_BARK_DARK, WOOD, fin * CFrame.new(0, -0.02, 0.01))
			arm.ball(0.14, JADE, SMOOTH, fin * CFrame.new(0, 0.12, 0.1))
			arm.block(Vector3.new(W * 0.7, 0.08, 0.2), TITAN_GOLD, SMOOTH, fin * CFrame.new(0, -0.3, 0))
		end

		if grade >= 4 then
			local ridge = Vector3.new(side * 0.08, top + 0.91, 0)
			jadeSpire(arm, ridge, 0.8, 0.26, true)
			for _, z in { -0.22, 0.22 } do
				jadeSpire(arm, ridge + Vector3.new(0, 0, z * D), 0.5, 0.18, false)
			end
		end
	end

	-- Rama de ceiba por los puntos de "points", sin giros: cada tramo es una escalera de bloques de corteza (clara y
	-- oscura alternadas) y, con "thorns", lleva una espina hacia atrás (+Z) en el medio, alternando el lado.
	local function ceibaBranch(make: Builder, points: { Vector3 }, thickness: number, thorns: boolean)
		for index = 1, #points - 1 do
			local from, to = points[index], points[index + 1]
			local steps = math.max(2, math.round((to - from).Magnitude / (thickness * 2)))
			local dx, dy, dz =
				math.abs(to.X - from.X) / steps, math.abs(to.Y - from.Y) / steps, math.abs(to.Z - from.Z) / steps
			for step = 0, steps - 1 do
				local dark = (index + step) % 2 == 1
				-- Los oscuros son un poco más finos: así las caras no coinciden con las de los claros.
				local grow = if dark then thickness * 0.86 else thickness
				make.block(
					Vector3.new(dx + grow, dy + grow, math.max(grow, dz + grow)),
					if dark then TRUNK_BARK_DARK else TRUNK_BARK,
					WOOD,
					CFrame.new(from:Lerp(to, (step + 0.5) / steps))
				)
			end
			if thorns then
				local sideX = if index % 2 == 0 then 1 else -1
				ceibaThorn(
					make,
					from:Lerp(to, 0.5) + Vector3.new(sideX * thickness * 0.25, 0, thickness * 0.5),
					Vector3.zAxis,
					thickness * 0.9,
					thickness * 0.4
				)
			end
		end
	end

	-- Copa de hojas en bloques (5 piezas; con "rich", dos brotes rosas arriba): masa verde, tapa oscura, faldón oscuro
	-- y un lóbulo a cada lado. Se ve sobre todo desde atrás, por eso los brotes salen hacia +Z.
	local function canopy(make: Builder, centre: Vector3, size: number, rich: boolean)
		make.block(Vector3.new(size, size * 0.55, size * 0.5), LEAF, SMOOTH, CFrame.new(centre))
		make.block(
			Vector3.new(size * 0.62, size * 0.4, size * 0.44),
			LEAF_DARK,
			SMOOTH,
			CFrame.new(centre + Vector3.new(0, size * 0.42, size * 0.03))
		)
		make.block(
			Vector3.new(size * 0.5, size * 0.3, size * 0.4),
			LEAF_DARK,
			SMOOTH,
			CFrame.new(centre + Vector3.new(0, -size * 0.38, 0))
		)
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(size * 0.34, size * 0.34, size * 0.4),
				LEAF,
				SMOOTH,
				CFrame.new(centre + Vector3.new(side * size * 0.62, -size * 0.06, 0))
			)
			if rich then
				make.block(
					Vector3.one * (size * 0.14),
					CEIBA_BLOSSOM,
					SMOOTH,
					CFrame.new(centre + Vector3.new(side * size * 0.3, size * 0.66, size * 0.3))
				)
			end
		end
	end

	-- Hojita de dos bloques (para las ramitas).
	local function leafBlob(make: Builder, at: Vector3, size: number, color: Color3)
		make.block(Vector3.new(size, size * 0.7, size * 0.5), color, SMOOTH, CFrame.new(at))
		make.block(
			Vector3.new(size * 0.6, size * 0.5, size * 0.6),
			LEAF_DARK,
			SMOOTH,
			CFrame.new(at + Vector3.yAxis * (size * 0.45))
		)
	end

	-- Colibrí de "size" en "at", de lado hacia "dir" (-1 o 1 en X): cuerpo verde, cabeza, garganta roja (hacia atrás,
	-- que es por donde se ve), pico, cola y dos alas en V. Siete bloques sin giros.
	local function hummingbird(make: Builder, at: Vector3, size: number, dir: number)
		local function piece(extent: Vector3, color: Color3, x: number, y: number, z: number)
			make.block(extent * size, color, SMOOTH, CFrame.new(at + Vector3.new(dir * x, y, z) * size))
		end
		piece(Vector3.new(0.3, 0.12, 0.12), HUMMINGBIRD, 0, 0, 0)
		piece(Vector3.new(0.13, 0.13, 0.13), HUMMINGBIRD, 0.2, 0.03, 0)
		piece(Vector3.new(0.1, 0.06, 0.04), HUMMINGBIRD_THROAT, 0.2, -0.02, 0.08)
		piece(Vector3.new(0.18, 0.025, 0.025), PAINT_BLACK, 0.37, 0.03, 0)
		piece(Vector3.new(0.16, 0.06, 0.05), HUMMINGBIRD, -0.23, -0.02, 0)
		piece(Vector3.new(0.14, 0.2, 0.03), HUMMINGBIRD, -0.02, 0.15, 0.08)
		piece(Vector3.new(0.14, 0.2, 0.03), HUMMINGBIRD, -0.02, 0.15, -0.08)
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

	-- Hoja que cuelga por un costado de un brazo o una pierna (bloques que se estrechan hacia abajo, finos en X).
	local function sideLeaf(make: Builder, x: number, topY: number, z: number, color: Color3)
		for index = 0, 2 do
			make.block(
				Vector3.new(0.05, 0.12, 0.22 * (1 - 0.3 * index)),
				color,
				SMOOTH,
				CFrame.new(x, topY - 0.12 * (index + 0.5), z)
			)
		end
	end

	-- Riqueza extra de la Ceiba (T2 de la Fase 18), toda de bloques. Grado 1: espinas, musgo y una liana con flor en
	-- el peto, hojas colgando de la gorguera y del taparrabos, lianas y espinas en los brazos y bandas de corteza en
	-- los muslos; en la espalda, espinas y raíces alrededor de la placa. Grado 2: lianas con hojas, musgo y dos flores
	-- en la capa. (El grado 3 añade las ramitas, los frutos y las luciérnagas del árbol de la espalda.)
	local function ceibaRichness(body: Body, grade: number)
		if grade < 1 then
			return
		end
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local BEHIND = CFrame.Angles(0, math.pi, 0)

		-- Peto: dos espinas y dos manchas de musgo en cada borde y una liana por el costado derecho con hojas y una flor
		-- (la flor va 0,1 adelantada de la liana para que no la entierre un torso hondo).
		local plate = CFrame.new(0, height * 0.14, front - 0.03)
		for side = -1, 1, 2 do
			for _, y in { 0, -height * 0.2 } do
				ceibaThorn(
					make,
					(plate * CFrame.new(side * width * 0.31, y, -0.04)).Position,
					Vector3.new(side, 0, 0),
					0.24,
					0.11
				)
			end
			for index = 0, 1 do
				make.block(
					Vector3.new(0.16, 0.1, 0.03),
					LEAF_DARK,
					SMOOTH,
					plate * CFrame.new(side * width * 0.22, (-0.12 + index * 0.16) * height, -0.075)
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
			stairs(make, vine[index], vine[index + 1], 0.06, 0.06, LIANA, FABRIC, 1)
		end
		for _, index in { 2, 4 } do
			tuft(
				make,
				vine[index].X - 0.06,
				vine[index].Y,
				front - 0.2,
				0.2,
				0.32,
				0.05,
				if index == 2 then LEAF else LEAF_DARK,
				SMOOTH
			)
		end
		ceibaBlossom(make, CFrame.new(vine[3] + Vector3.new(0, 0.1, -0.1)), 0.26)

		-- Hojas que cuelgan de la gorguera (delante).
		for index, x in { -0.38, -0.2, 0.2, 0.38 } do
			tuft(
				make,
				x * width,
				height / 2 - 0.12,
				front - 0.07,
				0.18,
				0.3,
				0.05,
				if index % 2 == 1 then LEAF else LEAF_DARK,
				SMOOTH
			)
		end

		-- Hojas en el bajo del taparrabos, delante y detrás.
		local waist = body.waist
		local hipWidth, hipDepth = waist.size.X, waist.size.Z
		local beltFront = -(hipDepth / 2 + 0.09)
		for index, x in { -0.14, 0.14 } do
			for _, z in { beltFront - 0.03, -beltFront + 0.03 } do
				tuft(
					waist,
					x * hipWidth * 1.4,
					-0.56,
					z,
					0.2,
					0.3,
					0.05,
					if index == 1 then LEAF else LEAF_DARK,
					SMOOTH
				)
			end
		end

		-- Brazos y muslos.
		for side = -1, 1, 2 do
			local upper = body.upperArm[side]
			local us = upper.size
			band(upper, -us.Y * 0.02, 0.07, 0.12, LIANA, FABRIC)
			band(upper, us.Y * 0.2, 0.07, 0.12, LIANA, FABRIC)
			ceibaThorn(upper, Vector3.new(side * (us.X / 2 + 0.04), us.Y * 0.1, 0), Vector3.new(side, 0, 0), 0.22, 0.1)
			local forearm = body.lowerArm[side]
			local fs = forearm.size
			sideLeaf(forearm, side * (fs.X / 2 + 0.04), fs.Y * 0.4, 0, LEAF)
			local leg = body.upperLeg[side]
			local ls = leg.size
			band(leg, -ls.Y * 0.12, 0.16, 0.08, CEIBA_BARK, WOOD)
			band(leg, -ls.Y * 0.3, 0.06, 0.12, LIANA, FABRIC)
			ceibaThorn(leg, Vector3.new(side * (ls.X / 2 + 0.06), -ls.Y * 0.12, 0), Vector3.new(side, 0, 0), 0.22, 0.1)
			sideLeaf(leg, side * (ls.X / 2 + 0.04), -ls.Y * 0.3, 0, LEAF)
			leg.ball(0.12, JADE, SMOOTH, CFrame.new(side * (ls.X / 2 + 0.1), -ls.Y * 0.12, 0))
		end

		-- Grado 1: la placa de corteza de la espalda (queda bajo la capa desde el grado 2) con cuatro espinas y tres
		-- raíces colgando.
		if grade == 1 then
			local plaqueY = height * 0.06
			for side = -1, 1, 2 do
				for _, y in { 0.2, -0.2 } do
					ceibaThorn(
						make,
						Vector3.new(side * width * 0.26, plaqueY + height * y, back + 0.14),
						Vector3.zAxis,
						0.24,
						0.11
					)
				end
			end
			for index = 0, 2 do
				ceibaThorn(
					make,
					Vector3.new((index - 1) * width * 0.14, plaqueY - height * 0.28, back + 0.14),
					-Vector3.yAxis,
					0.4,
					0.2
				)
			end
		end

		-- Grado 2: la capa, con dos lianas con hoja por lado, musgo y dos flores.
		if grade >= 2 then
			local capeHeight = height * 1.16
			local capeTop = height / 2 - 0.05
			local capeZ = back + 0.2
			for side = -1, 1, 2 do
				for index = 0, 1 do
					local x = side * width * (0.3 + index * 0.14)
					local bottom = Vector3.new(x, capeTop - capeHeight * (0.45 + index * 0.15), capeZ + 0.09)
					stairs(
						make,
						Vector3.new(x, capeTop - capeHeight * 0.04, capeZ + 0.09),
						bottom,
						0.05,
						0.05,
						LIANA,
						FABRIC,
						2
					)
					tuft(make, bottom.X, bottom.Y, capeZ + 0.1, 0.22, 0.3, 0.04, LEAF, SMOOTH)
				end
				make.block(
					Vector3.new(0.26, 0.12, 0.03),
					LEAF_DARK,
					SMOOTH,
					CFrame.new(side * width * 0.18, capeTop - capeHeight * 0.3, capeZ + 0.07)
				)
			end
			for _, spot in { { -0.4, 0.2 }, { 0.4, 0.62 } } do
				ceibaBlossom(
					make,
					CFrame.new(spot[1] * width, capeTop - capeHeight * spot[2], capeZ + 0.1) * BEHIND,
					0.26
				)
			end
		end
	end

	-- Traje mítico del médico, Ceiba de la Vida, de bloques alineados con los ejes (apto para malla). Grado 0: túnica
	-- de lino, peto de corteza con el canto de oro y espinas en las esquinas y, sobre un disco de jade, el glifo de
	-- oro del árbol del mundo (un tronco en Y con un brote en cada punta), gorguera de oro con jade, bandolera con tres
	-- frascos de savia, cinturón de raíces trenzadas con hebilla de jade, taparrabos de lino con una bolsa de hierbas,
	-- brazaletes de oro y brazales de corteza con espinas. Detrás, una placa de corteza con el glifo y tres hojas.
	-- Grado 1: hombreras de corteza (láminas de lino, cresta con contrafuertes y espinas), espinas, lianas y raíces.
	-- Grado 2: capa de tela de corteza con cantos de oro y un fleco de hojas, broches con cadena, faldones y, de motivo,
	-- la base del tronco de la ceiba (tres tramos de corteza) con raíces de contrafuerte, espinas, un aro de oro con
	-- jade y un brote con flor. Grado 3: el tronco sube por la espalda y se abre en dos ramas por encima de los hombros
	-- (la cabeza queda libre entre ellas) con espinas, flores rosas, lianas, ramitas con hojas y vetas de savia verde
	-- que brillan; brillan el glifo, los frascos y las luciérnagas, y los frutos se abren. Grado 4: la copa, dos ramas
	-- más hacia arriba y dos hacia fuera con copas de hojas, frutos con algodón que cae, motas de curación, dos colibríes,
	-- raíces de contrafuerte hasta la cintura y cristales de jade en las hombreras.
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

		-- El glifo del árbol del mundo en "at" (mirando a su -Z): disco de jade en un aro de oro y un árbol de oro en Y
		-- (tronco con dos raíces y dos ramas en escalón) con un brote en cada punta (verde que brilla desde el grado 3).
		local function worldTree(at: CFrame, size: number)
			make.rod(0.06, size, TITAN_GOLD, SMOOTH, at * FACING)
			make.rod(0.06, size * 0.84, JADE, SMOOTH, at * CFrame.new(0, 0, -0.02) * FACING)
			local glyph = at * CFrame.new(0, 0, -0.05)
			make.block(Vector3.new(0.13, size * 0.42, 0.05), TITAN_GOLD, SMOOTH, glyph * CFrame.new(0, -size * 0.08, 0))
			for side = -1, 1, 2 do
				make.block(
					Vector3.new(0.11, size * 0.16, 0.05),
					TITAN_GOLD,
					SMOOTH,
					glyph * CFrame.new(side * size * 0.06, size * 0.1, 0)
				)
				make.block(
					Vector3.new(0.11, size * 0.16, 0.05),
					TITAN_GOLD,
					SMOOTH,
					glyph * CFrame.new(side * size * 0.13, size * 0.22, 0)
				)
				make.block(
					Vector3.new(0.1, size * 0.14, 0.05),
					TITAN_GOLD,
					SMOOTH,
					glyph * CFrame.new(side * size * 0.06, -size * 0.3, 0)
				)
			end
			for _, tip in
				{
					Vector3.new(0, size * 0.2, 0),
					Vector3.new(-size * 0.15, size * 0.34, 0),
					Vector3.new(size * 0.15, size * 0.34, 0),
				}
			do
				make.ball(size * 0.15, LEAF, SMOOTH, glyph * CFrame.new(tip + Vector3.new(0, 0, -0.04)))
			end
		end

		-- Peto de corteza con el canto de oro, dos vetas oscuras, espinas en las esquinas de arriba y el glifo.
		local plate = CFrame.new(0, height * 0.14, front - 0.03)
		make.block(Vector3.new(width * 0.68, height * 0.56, 0.12), TITAN_GOLD, SMOOTH, plate * CFrame.new(0, 0, 0.02))
		make.block(Vector3.new(width * 0.62, height * 0.5, 0.12), TRUNK_BARK, WOOD, plate * CFrame.new(0, 0, -0.01))
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.08, height * 0.44, 0.04),
				TRUNK_VEIN,
				WOOD,
				plate * CFrame.new(side * width * 0.27, 0, -0.07)
			)
			ceibaThorn(
				make,
				(plate * CFrame.new(side * width * 0.31, height * 0.24, -0.06)).Position,
				Vector3.new(side * 0.6, 1, 0),
				0.26,
				0.12
			)
		end
		-- El glifo va 0,1 adelantado del peto; tres raíces cuelgan del borde de abajo.
		worldTree(plate * CFrame.new(0, 0, -0.18), width * 0.42)
		for index = -1, 1 do
			ceibaThorn(
				make,
				Vector3.new(index * width * 0.2, plate.Y - height * 0.29, front - 0.12),
				-Vector3.yAxis,
				if index == 0 then 0.5 else 0.36,
				0.18
			)
		end

		-- Gorguera de oro en anillo (delante, a los lados y detrás) con cuentas de jade.
		local collarY = height / 2 - 0.02
		make.block(Vector3.new(width * 0.6, 0.14, 0.16), TITAN_GOLD, SMOOTH, CFrame.new(0, collarY, front + 0.04))
		make.block(Vector3.new(width * 0.6, 0.14, 0.16), TITAN_GOLD, SMOOTH, CFrame.new(0, collarY, back - 0.04))
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(0.16, 0.14, depth * 0.8),
				TITAN_GOLD,
				SMOOTH,
				CFrame.new(side * width * 0.3, collarY, 0)
			)
			make.ball(0.15, JADE, SMOOTH, CFrame.new(side * width * 0.3, collarY + 0.04, -depth * 0.3))
		end
		for _, x in { -0.15, 0, 0.15 } do
			make.ball(0.15, JADE, SMOOTH, CFrame.new(x * width * 1.6, collarY + 0.03, front - 0.04))
		end

		-- Bandolera del hombro izquierdo a la cadera derecha (seis escalones) con tres frascos de savia.
		local strapFrom = Vector3.new(-width * 0.34, height / 2 - 0.02, front - 0.1)
		local strapTo = Vector3.new(width * 0.4, -height / 2 + 0.12, front - 0.1)
		stairs(make, strapFrom, strapTo, 0.14, 0.1, LEATHER, LEATHER_MATERIAL, 6)
		for _, t in { 0.62, 0.76, 0.9 } do
			flask(make, CFrame.new(strapFrom:Lerp(strapTo, t) + Vector3.new(0, -0.06, -0.1)), 0.2, lit)
		end

		-- Espalda (grados 0 y 1): placa de corteza con el glifo y tres hojas colgando del borde de arriba.
		if grade < 2 then
			local plaque = CFrame.new(0, height * 0.06, back + 0.08) * BEHIND
			make.block(
				Vector3.new(width * 0.5, height * 0.56, 0.1),
				TITAN_GOLD,
				SMOOTH,
				plaque * CFrame.new(0, 0, 0.02)
			)
			make.block(Vector3.new(width * 0.44, height * 0.5, 0.1), TRUNK_BARK, WOOD, plaque)
			worldTree(plaque * CFrame.new(0, -0.04, -0.06), width * 0.3)
			for index = -1, 1 do
				tuft(
					make,
					index * 0.14 * width,
					height * 0.06 + height * 0.36,
					back + 0.2,
					0.22,
					0.4,
					0.05,
					if index == 0 then LEAF_DARK else LEAF,
					SMOOTH
				)
			end
		end

		-- Cinturón de raíces trenzadas con hebilla de jade, tachones, taparrabos de lino y una bolsa de hierbas.
		local waist = body.waist
		local hipWidth, hipDepth = waist.size.X, waist.size.Z
		local beltFront = -(hipDepth / 2 + 0.09)
		waist.block(Vector3.new(hipWidth + 0.16, 0.24, hipDepth + 0.18), CEIBA_BARK_DARK, WOOD, CFrame.new(0, 0.05, 0))
		for index = -1, 1, 2 do
			waist.block(
				Vector3.new(hipWidth + 0.18, 0.05, hipDepth + 0.2),
				CEIBA_BARK,
				WOOD,
				CFrame.new(0, 0.05 + index * 0.07, 0)
			)
		end
		local buckle = CFrame.new(0, 0.05, beltFront - 0.03)
		waist.rod(0.06, 0.42, TITAN_GOLD, SMOOTH, buckle * FACING)
		waist.oval(Vector3.new(0.3, 0.28, 0.1), JADE, SMOOTH, buckle * CFrame.new(0, 0, -0.04))
		for side = -1, 1, 2 do
			for _, x in { 0.2, 0.34 } do
				waist.ball(0.1, TITAN_GOLD, SMOOTH, CFrame.new(side * hipWidth * x, 0.05, beltFront - 0.04))
			end
		end
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
			band(forearm, -fs.Y * 0.05, 0.06, 0.14, LIANA, FABRIC)
			for _, y in { fs.Y * 0.1, -fs.Y * 0.22 } do
				ceibaThorn(forearm, Vector3.new(side * (fs.X / 2 + 0.05), y, 0), Vector3.new(side, 0, 0), 0.22, 0.1)
			end
			if grade >= 1 then
				ceibaPauldron(upper, side, grade)
			end
		end

		-- Grado 2: manto de corteza sobre los hombros, capa con cantos de oro y fleco de hojas, broches con cadena,
		-- faldones; y el tronco con sus raíces.
		if grade >= 2 then
			make.block(
				Vector3.new(width + 0.36, 0.3, depth * 0.62),
				CEIBA_BARK_DARK,
				FABRIC,
				CFrame.new(0, height / 2 - 0.06, depth * 0.24)
			)
			local capeHeight = height * 1.16
			local capeTop = height / 2 - 0.05
			local capeZ = back + 0.2
			make.block(
				Vector3.new(width * 1.02, capeHeight, 0.12),
				CAPE_CLOTH,
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
			for index = 0, 4 do
				tuft(
					make,
					(index / 4 - 0.5) * width * 0.92,
					capeTop - capeHeight + 0.04,
					capeZ + 0.07,
					0.3,
					0.5,
					0.05,
					if index % 2 == 0 then LEAF else LEAF_DARK,
					SMOOTH
				)
			end
			-- Broches de oro con jade (la bola va adelantada) unidos por una cadena que cuelga.
			local clasps: { [number]: Vector3 } = {}
			for side = -1, 1, 2 do
				local clasp = CFrame.new(side * width * 0.36, height / 2 - 0.12, front - 0.06)
				make.rod(0.08, 0.3, TITAN_GOLD, SMOOTH, clasp * FACING)
				make.ball(0.14, JADE, SMOOTH, clasp * CFrame.new(0, 0, -0.1))
				clasps[side] = clasp.Position
			end
			local sag = Vector3.new(0, height / 2 - 0.3, front - 0.12)
			stairs(make, clasps[-1], sag, 0.05, 0.05, TITAN_GOLD, SMOOTH, 3)
			stairs(make, sag, clasps[1], 0.05, 0.05, TITAN_GOLD, SMOOTH, 3)
			for side = -1, 1, 2 do
				local leg = body.upperLeg[side]
				local ls = leg.size
				local flap = CFrame.new(side * 0.04, ls.Y / 2 - ls.Y * 0.22, -(ls.Z / 2 + 0.06))
				leg.block(Vector3.new(ls.X * 0.9, ls.Y * 0.42, 0.1), LINEN, FABRIC, flap)
				leg.block(
					Vector3.new(ls.X * 0.92, 0.06, 0.12),
					TITAN_GOLD,
					SMOOTH,
					flap * CFrame.new(0, -ls.Y * 0.2, 0)
				)
			end

			-- La base del tronco, de corteza clara sobre la capa oscura: tres tramos que se estrechan, raíces de
			-- contrafuerte abiertas a los lados, dos espinas, un aro de oro con jade y, en el grado 2, un brote con flor.
			local trunkZ = capeZ + 0.3
			local baseY = capeTop - capeHeight * 0.8
			local trunkTop = baseY + 1.35
			make.block(Vector3.new(1.2, 0.5, 0.5), TRUNK_BARK, WOOD, CFrame.new(0, baseY + 0.2, trunkZ))
			make.block(Vector3.new(1, 0.5, 0.46), TRUNK_BARK_DARK, WOOD, CFrame.new(0, baseY + 0.65, trunkZ))
			make.block(Vector3.new(0.8, 0.5, 0.42), TRUNK_BARK, WOOD, CFrame.new(0, baseY + 1.1, trunkZ))
			-- Tres vetas claras que suben por el tronco.
			for _, x in { -0.3, 0, 0.3 } do
				make.block(Vector3.new(0.07, 1.3, 0.05), TRUNK_VEIN, WOOD, CFrame.new(x, baseY + 0.7, trunkZ + 0.24))
			end
			for side = -1, 1, 2 do
				ceibaThorn(make, Vector3.new(side * 0.46, baseY + 0.1, trunkZ), Vector3.new(side, 0, 0), 0.62, 0.34)
				ceibaThorn(make, Vector3.new(side * 0.36, baseY + 0.42, trunkZ), Vector3.new(side, 0, 0), 0.4, 0.22)
			end
			make.block(Vector3.new(0.86, 0.1, 0.62), TITAN_GOLD, SMOOTH, CFrame.new(0, baseY + 0.86, trunkZ))
			make.ball(0.22, JADE, SMOOTH, CFrame.new(0, baseY + 0.86, trunkZ + 0.4))
			for side = -1, 1, 2 do
				ceibaThorn(make, Vector3.new(side * 0.3, baseY + 0.5, trunkZ + 0.22), Vector3.zAxis, 0.3, 0.13)
			end
			if grade == 2 then
				canopy(make, Vector3.new(0, trunkTop + 0.45, trunkZ + 0.04), 0.9, false)
				ceibaBlossom(make, CFrame.new(0, trunkTop + 0.55, trunkZ + 0.4) * BEHIND, 0.34)
			else
				-- Grado 3: el tronco sube y se abre en dos ramas por encima de los hombros (la cabeza queda libre
				-- entre ellas), con espinas, vetas de savia que brillan, flores, una liana colgando y ramitas con hojas.
				local fork = Vector3.new(0, math.max(height * 0.3, trunkTop + 0.3), trunkZ - 0.04)
				local shaftFrom = Vector3.new(0, trunkTop - 0.2, trunkZ)
				ceibaBranch(make, { shaftFrom, fork }, 0.7, true)
				local veinFrom = baseY + 0.2
				for _, offset in { -0.14, 0.14 } do
					make.block(
						Vector3.new(0.05, fork.Y - veinFrom, 0.05),
						HEAL_GLOW,
						NEON,
						CFrame.new(offset, (fork.Y + veinFrom) / 2, trunkZ + 0.27)
					)
				end
				local tips, elbows = {}, {}
				for side = -1, 1, 2 do
					-- Ramas gruesas (0,42) que se abren en horquilla; las copas quedan a menos de 0,4 del ancho del
					-- torso del centro, dentro de las hombreras (cuyo borde interior ronda el 0,3).
					local elbow = Vector3.new(side * width * 0.24, fork.Y + height * 0.25, trunkZ - 0.1)
					local tip = Vector3.new(side * width * 0.36, fork.Y + height * 0.47, trunkZ - 0.2)
					ceibaBranch(make, { fork, elbow, tip }, 0.42, true)
					tips[side], elbows[side] = tip, elbow
					-- Vetas claras a lo largo de cada tramo, para leer la horquilla.
					stairs(
						make,
						fork + Vector3.new(side * 0.12, 0, 0.26),
						elbow + Vector3.new(side * 0.12, 0, 0.26),
						0.05,
						0.05,
						TRUNK_VEIN,
						WOOD,
						2
					)
					stairs(
						make,
						elbow + Vector3.new(side * 0.1, 0, 0.26),
						tip + Vector3.new(side * 0.1, 0, 0.26),
						0.05,
						0.05,
						TRUNK_VEIN,
						WOOD,
						2
					)
					stairs(
						make,
						fork + Vector3.new(0, 0, 0.2),
						elbow + Vector3.new(0, 0, 0.2),
						0.05,
						0.05,
						HEAL_GLOW,
						NEON,
						2
					)
					ceibaBlossom(make, CFrame.new(elbow + Vector3.new(0, 0.18, 0.2)) * BEHIND, 0.42)
					canopy(make, tip + Vector3.new(0, 0.1, 0), if grade >= 4 then 0.65 else 0.6, false)
					local hang = elbow + Vector3.new(side * 0.12, -0.9, 0.16)
					stairs(make, elbow + Vector3.new(0, -0.1, 0.12), hang, 0.05, 0.05, LIANA, FABRIC, 2)
					tuft(make, hang.X, hang.Y, hang.Z, 0.24, 0.32, 0.05, LEAF, SMOOTH)
				end
				local sap = make.ball(0.24, HEAL_GLOW, NEON, CFrame.new(fork + Vector3.new(0, 0, 0.26)))
				fireLight(sap, HEAL_GLOW)

				-- Dos ramitas con hojas y un fruto abierto por rama, cinco brotes rosas en el tronco y seis luciérnagas
				-- de curación alrededor del árbol.
				for side = -1, 1, 2 do
					local elbow, tip = elbows[side], tips[side]
					for _, twig in { { fork, elbow, 0.45 }, { elbow, tip, 0.5 } } do
						local start = twig[1]:Lerp(twig[2], twig[3])
						local finish = start + Vector3.new(side * 0.25, 0.35, 0.05)
						ceibaBranch(make, { start, finish }, 0.12, false)
						leafBlob(make, finish + Vector3.new(0, 0.1, 0), 0.22, LEAF)
					end
					kapokPod(make, CFrame.new(elbow + Vector3.new(side * 0.1, -0.25, 0.2)), 0.36, true)
				end
				for index = 0, 4 do
					make.ball(
						0.1,
						CEIBA_BLOSSOM,
						SMOOTH,
						CFrame.new((index % 2 * 2 - 1) * 0.22, baseY + 0.9 + index * 0.25, trunkZ + 0.28)
					)
				end
				for index = 0, 5 do
					make.ball(
						0.08,
						HEAL_GLOW,
						NEON,
						CFrame.new(
							math.sin(index * 2.1) * width * 0.5,
							height * (0.3 + (index * 0.137) % 0.5),
							trunkZ + 0.1 + math.cos(index * 1.7) * 0.2
						)
					)
				end

				-- Grado 4: la copa: dos ramas más hacia arriba y dos hacia fuera con copas de hojas (con brotes rosas
				-- las de arriba), frutos abiertos con algodón que cae, motas de curación, dos colibríes junto a las
				-- flores y raíces de contrafuerte en rampa hasta la cintura.
				if grade >= 4 then
					for side = -1, 1, 2 do
						-- Una segunda rama sube desde el codo hacia el centro, con otra copa pequeña (rosa); entre las dos
						-- copas de cada lado queda cielo.
						local tip = Vector3.new(side * width * 0.12, fork.Y + height * 0.78, trunkZ - 0.16)
						ceibaBranch(make, { elbows[side], tip }, 0.28, false)
						canopy(make, tip + Vector3.new(0, 0.1, 0), 0.55, true)
						ceibaBlossom(make, CFrame.new(tip + Vector3.new(0, -0.35, 0.3)) * BEHIND, 0.34)
						local fluff =
							kapokPod(make, CFrame.new(tips[side] + Vector3.new(-side * 0.16, -0.3, 0.16)), 0.42, true)
						lifeMotes(fluff, 2, true)
						hummingbird(make, tip + Vector3.new(side * 0.4, -0.2, 0.4), 1.5, side)
						-- Raíz en rampa del pie del tronco hacia fuera y abajo, con una espina en la punta.
						local rootFrom = Vector3.new(side * 0.5, baseY + 0.5, trunkZ)
						local rootTo = Vector3.new(side * 1.05, baseY - 0.05, trunkZ)
						stairs(make, rootFrom, rootTo, 0.22, 0.3, CEIBA_BARK_DARK, WOOD, 3)
						ceibaThorn(
							make,
							rootTo + Vector3.new(side * 0.08, -0.12, 0),
							Vector3.new(side, -1, 0),
							0.3,
							0.16
						)
					end
					lifeMotes(sap, 5, false)
					for index = 0, 3 do
						make.ball(
							0.08,
							HEAL_GLOW,
							NEON,
							CFrame.new(
								math.sin(index * 1.3 + 0.5) * width * 0.5,
								fork.Y + height * (0.6 + index * 0.08),
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

	-- Hombrera del fuego azul: tres láminas de pómez que bajan hacia fuera (la de abajo, con el canto de
	-- carbón y la raya de fuego azul), una cresta de carbón en dos mitades con la llama en píxeles en el hueco,
	-- y cristales de azufre. Con STEPS.on (malla) no hay giros: el bajar de las láminas lo hace el escalón.
	-- Por grados: 1, las láminas, la cresta, remaches; 2, gotas azules bajo la lámina de abajo y la
	-- corona de cristales; 3, el cuerno de azufre hacia fuera y la aleta de carbón de detrás (lo que se ve de
	-- espaldas); 4, la llama echa fuego y salen dos cristales altos y una chispa.
	local function blueFirePauldron(arm: Builder, side: number, grade: number)
		local lit = grade >= 4
		local as = arm.size
		local top = as.Y / 2
		local W, D = as.X, as.Z
		local droop = if STEPS.on then 0 else -side * 0.14
		local lames = {
			{ w = 1.35, depth = 1.45, y = 0.32, out = 0.04, color = PUMICE },
			{ w = 1.6, depth = 1.55, y = 0.12, out = 0.14, color = PUMICE_DARK },
			{ w = 1.85, depth = 1.65, y = -0.08, out = 0.25, color = PUMICE },
		}
		for index, lame in lames do
			local at = CFrame.new(side * lame.out, top + lame.y, 0) * CFrame.Angles(0, 0, droop)
			local size = Vector3.new(W * lame.w, 0.2, D * lame.depth)
			arm.block(size, lame.color, SLATE, at)
			arm.block(Vector3.new(size.X + 0.06, 0.06, size.Z + 0.06), CHARCOAL, SLATE, at * CFrame.new(0, -0.12, 0))
			if index == 3 then
				arm.block(Vector3.new(size.X + 0.1, 0.04, size.Z + 0.1), BLUE_FIRE, NEON, at * CFrame.new(0, -0.17, 0))
			end
		end
		local crest = CFrame.new(side * 0.1, top + 0.58, 0)
		for sz = -1, 1, 2 do
			arm.block(Vector3.new(0.24, 0.3, D * 0.5), CHARCOAL, SLATE, crest * CFrame.new(0, 0, sz * D * 0.62))
			arm.block(Vector3.new(0.14, 0.08, D * 0.4), PUMICE_DARK, SLATE, crest * CFrame.new(0, 0.18, sz * D * 0.62))
		end
		local foot = pixelFlame(arm, SMALL_FLAME, BLUE_FLAME, CFrame.new(side * 0.06, top + 0.44, 0), 0.12, side < 0)
		if lit then
			blueFire(foot, 5, 0.5)
			smoke(foot, 1.5, Color3.fromRGB(150, 160, 190), 0.5)
		end
		-- Grado 1: remaches de azufre en las dos esquinas de delante de la lámina de arriba.
		for sx = -1, 1, 2 do
			arm.ball(0.12, SULFUR, SMOOTH, CFrame.new(side * 0.04 + sx * W * 0.62, top + 0.46, -D * 0.64))
		end
		-- Grado 2: gotas de fuego azul bajo la lámina de abajo y dos cristales de azufre sobre la cresta.
		if grade >= 2 then
			for _, z in { -0.5, 0, 0.5 } do
				lavaDrip(
					arm,
					CFrame.new(side * (0.25 + W * 0.55), top - 0.2, z * D),
					0.32 - math.abs(z) * 0.2,
					BLUE_FIRE_MID
				)
			end
			for _, z in { -0.55, 0.55 } do
				fireCrystal(
					arm,
					Vector3.new(side * 0.1, top + 0.72, z * D),
					Vector3.new(side * 0.4, 1, z * 0.8),
					0.7,
					0.24,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end
		-- Grado 3: cuerno de azufre hacia fuera y aleta de carbón detrás con raya azul y tres remaches.
		if grade >= 3 then
			fireCrystal(
				arm,
				Vector3.new(side * (W * 0.95 + 0.25), top - 0.04, 0),
				Vector3.new(side, 0.55, 0),
				1,
				0.34,
				SULFUR,
				SULFUR_GLOW
			)
			local fin = CFrame.new(side * 0.2, top + 0.18, D * 0.9)
			arm.block(Vector3.new(W * 1.3, 0.6, 0.1), CHARCOAL, SLATE, fin)
			arm.block(Vector3.new(W * 1.0, 0.05, 0.04), BLUE_FIRE, NEON, fin * CFrame.new(0, 0.1, 0.07))
			for _, x in { -0.4, 0, 0.4 } do
				arm.ball(0.1, SULFUR, SMOOTH, fin * CFrame.new(x * W, -0.18, 0.08))
			end
		end
		-- Grado 4: dos cristales altos detrás de la cresta y una chispa sobre la llama.
		if lit then
			for sz = -1, 1, 2 do
				fireCrystal(
					arm,
					Vector3.new(side * 0.2, top + 0.6, sz * D * 0.86),
					Vector3.new(side * 0.5, 1, sz * 0.5),
					1.1,
					0.28,
					SULFUR,
					SULFUR_GLOW
				)
			end
			arm.ball(0.1, BLUE_FIRE_PALE, NEON, CFrame.new(side * 0.06, top + 1.4, 0))
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

	-- Traje de temporada del guerrero, Guardián del Fuego Azul. Delante: coraza de pómez en placas escalonadas
	-- (tres láminas de pecho y tres de abdomen, cada una con su costura de carbón) cruzada por dos correas de
	-- carbón con el canto de fuego azul y tachones de azufre; donde se cruzan, una llama en píxeles sobre un
	-- disco de carbón con marco de pómez sujeto por cuatro cristales de azufre; gorguera de carbón con
	-- cristales de azufre alrededor del cuello; grietas de carbón pintadas en las placas; cinturón de carbón con
	-- la hebilla de pómez. Detrás: una placa de carbón con el borde de fuego azul y su marco, un lomo de
	-- pómez (espina con vértebras y tres pares de costillas que abrazan la llama) y, sobre un cráter de
	-- escalones, una llamarada azul en píxeles más alta que la cabeza (como el fuego azul de los volcanes de
	-- azufre). Hombreras de láminas con cristales de azufre y su llama, brazales de pómez con un cristal y
	-- faldones de pómez con una placa de carbón. Por grados: 0, la coraza con las correas, el cinturón, los
	-- brazales, los faldones, la placa de la espalda y su marco; 1, las hombreras, las costuras y grietas de la
	-- coraza, la espina y el primer par de costillas; 2, la llama del pecho, los cristales de la gorguera, de la
	-- hebilla y de los brazales, y los otros dos pares de costillas; 3, el cráter de escalones de la espalda con
	-- una llama pequeña; 4, la llamarada grande y el fuego que sale de las llamas, con su luz.
	-- Con malla (STEPS.on) todo lo de pómez y carbón es de bloques alineados con los ejes; solo el neón y los
	-- cristales quedan sueltos.
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
			for index = 0, 4, 2 do
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
		-- Coraza en placas: tres láminas de pecho (cada una más ancha que la de arriba, de pómez clara y oscura
		-- alternas) con su costura de carbón debajo, y tres de abdomen que se estrechan.
		local lames = {
			{ y = 0.3, w = 0.84, color = PUMICE },
			{ y = 0.12, w = 0.92, color = PUMICE_DARK },
			{ y = -0.06, w = 1, color = PUMICE },
		}
		for _, lame in lames do
			local y = height * lame.y
			make.block(
				Vector3.new(width * lame.w, height * 0.15, 0.08),
				lame.color,
				SLATE,
				CFrame.new(0, y, front - 0.04)
			)
			make.block(
				Vector3.new(width * lame.w + 0.04, 0.05, 0.1),
				CHARCOAL,
				SLATE,
				CFrame.new(0, y - height * 0.075 - 0.025, front - 0.045)
			)
		end
		local belly = {
			{ y = -0.24, w = 0.7, color = PUMICE_DARK },
			{ y = -0.33, w = 0.56, color = PUMICE },
			{ y = -0.42, w = 0.42, color = PUMICE_DARK },
		}
		for index, plate in belly do
			local y = height * plate.y
			make.block(
				Vector3.new(width * plate.w, height * 0.07, 0.08),
				plate.color,
				SLATE,
				CFrame.new(0, y, front - 0.04)
			)
			-- Grado 1: costura de carbón bajo las dos placas de arriba.
			if grade >= 1 and index < 3 then
				make.block(
					Vector3.new(width * plate.w + 0.04, 0.04, 0.1),
					CHARCOAL,
					SLATE,
					CFrame.new(0, y - height * 0.035 - 0.02, front - 0.045)
				)
			end
		end
		-- Grado 1: grietas de carbón en zigzag (dos en el pecho, de lado a lado) y tres tachones en la gorguera.
		if grade >= 1 then
			local cracks = {
				{ -0.4, 0.3, 0.05, 0.3 },
				{ -0.37, 0.19, 0.14, 0.05 },
				{ 0.4, 0.14, 0.05, 0.3 },
				{ 0.37, 0.03, 0.14, 0.05 },
			}
			for _, crack in cracks do
				make.block(
					Vector3.new(crack[3], crack[4], 0.03),
					CHARCOAL,
					SLATE,
					CFrame.new(crack[1] * width, crack[2] * height, front - 0.09)
				)
			end
			for _, x in { -0.2, 0, 0.2 } do
				make.ball(0.1, SULFUR, SMOOTH, CFrame.new(x * width, height * 0.44, front - 0.1))
			end
		end
		-- Correas cruzadas del hombro a la cadera contraria, con tachones de azufre.
		for side = -1, 1, 2 do
			local from = Vector3.new(side * width * 0.42, height * 0.45, front)
			local to = Vector3.new(-side * width * 0.4, -height * 0.44, front)
			strap(make, from + Vector3.new(0, 0, 0.04), to + Vector3.new(0, 0, 0.04), 0.3, BLUE_FIRE, NEON)
			strap(make, from, to, 0.22, CHARCOAL, SLATE)
			for _, t in { 0.15, 0.85 } do
				make.ball(0.12, SULFUR, SMOOTH, CFrame.new(from:Lerp(to, t) + Vector3.new(0, 0, -0.1)))
			end
		end
		-- Donde se cruzan las correas, un tachón de azufre o, desde el grado 2, una llama en píxeles sobre un
		-- disco de carbón con marco de pómez y cuatro cristales.
		local core = CFrame.new(0, 0, front - 0.14)
		if grade < 2 then
			make.ball(0.26, SULFUR, SMOOTH, core * CFrame.new(0, 0, 0.04))
		end
		if grade >= 2 then
			make.block(Vector3.new(0.96, 0.96, 0.05), PUMICE_DARK, SLATE, core * CFrame.new(0, 0, 0.05))
			make.rod(0.12, 0.8, CHARCOAL, SLATE, core * FACING)
			local heart = pixelFlame(
				make,
				SMALL_FLAME,
				BLUE_FLAME,
				core * CFrame.new(0, -0.33, -0.14) * FACING_FRONT,
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

		-- Espalda: placa de carbón con el borde de fuego azul, su marco y, sobre ella, el lomo de pómez y la
		-- llamarada sobre su cráter.
		local plateZ = back + 0.12
		make.block(
			Vector3.new(width * 0.9 + 0.08, height * 0.9 + 0.08, 0.06),
			BLUE_FIRE,
			NEON,
			CFrame.new(0, -height * 0.02, plateZ - 0.03)
		)
		make.block(Vector3.new(width * 0.9, height * 0.9, 0.1), CHARCOAL, SLATE, CFrame.new(0, -height * 0.02, plateZ))
		backFrame(make, width * 0.9, height * 0.9, -height * 0.02, plateZ, true, 5, 3)
		make.block(Vector3.new(width * 0.5, 0.3, 0.12), CHARCOAL, SLATE, CFrame.new(0, height * 0.44, back + 0.1))
		make.block(
			Vector3.new(width * 0.54, 0.06, 0.16),
			PUMICE,
			SLATE,
			CFrame.new(0, height * 0.44 + 0.17, back + 0.1)
		)
		-- Grado 1: la espina de pómez con tres vértebras y el primer par de costillas (las de arriba): cada una,
		-- una barra que sale al lado, más delante que la llama, y un poste que la sujeta a la placa.
		-- Grado 2: los otros dos pares, más abajo.
		if grade >= 1 then
			make.block(Vector3.new(0.2, height * 0.84, 0.1), PUMICE, SLATE, CFrame.new(0, -height * 0.02, plateZ + 0.1))
			for _, y in { 0.26, 0.06, -0.14 } do
				make.block(
					Vector3.new(width * 0.24, 0.1, 0.16),
					PUMICE_DARK,
					SLATE,
					CFrame.new(0, height * y, plateZ + 0.12)
				)
			end
		end
		for level, y in { 0.28, 0.1, -0.08 } do
			if grade >= (if level == 1 then 1 else 2) then
				for side = -1, 1, 2 do
					make.block(
						Vector3.new(width * 0.26, 0.12, 0.14),
						if level == 2 then PUMICE_DARK else PUMICE,
						SLATE,
						CFrame.new(side * width * 0.41, height * y, plateZ + 0.22)
					)
					make.block(
						Vector3.new(0.12, 0.22, 0.26),
						PUMICE_DARK,
						SLATE,
						CFrame.new(side * width * 0.5, height * y - 0.08, plateZ + 0.22)
					)
				end
			end
		end
		-- Grado 2: un cristal de azufre alto a cada lado de la viga, hacia atrás y arriba.
		if grade >= 2 then
			for side = -1, 1, 2 do
				fireCrystal(
					make,
					Vector3.new(side * width * 0.3, height * 0.43, plateZ + 0.12),
					Vector3.new(side * 0.4, 1, 0.6),
					0.8,
					0.3,
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
				local big = pixelFlame(make, BIG_FLAME, BLUE_FLAME, flameAt, width * 0.1, false)
				blueFire(big, 12, 0.9)
				smoke(big, 2, Color3.fromRGB(150, 160, 190), 0.9)
			else
				pixelFlame(make, SMALL_FLAME, BLUE_FLAME, flameAt, width * 0.1, false)
			end
			-- Grado 3: dos cristales altos en las esquinas del cráter, tres remaches en su labio y cinco brasas
			-- que suben por delante de la llama (en el 4, dos más, más altas).
			for _, x in { -0.44, 0.44 } do
				fireCrystal(
					make,
					Vector3.new(x * width, footY + height * 0.06, plateZ + 0.34),
					Vector3.new(x * 2.4, 1, 0.5),
					0.9,
					0.24,
					SULFUR,
					SULFUR_GLOW
				)
			end
			for _, x in { -0.27, 0, 0.27 } do
				make.ball(0.12, SULFUR, SMOOTH, CFrame.new(x * width, footY - height * 0.07, plateZ + 0.37))
			end
			local sparks = {}
			for index = 1, 5 do
				sparks[index] = Vector3.new(
					(index - 3) * width * 0.2,
					footY + height * (0.7 + 0.12 * ((index * 3) % 5)),
					plateZ + 0.6
				)
			end
			motes(make, sparks, 0.1)
			if lit then
				local high = {}
				for index = 1, 2 do
					high[index] =
						Vector3.new((index - 1.5) * width * 0.5, footY + height * (1.35 + 0.1 * index), plateZ + 0.6)
				end
				motes(make, high, 0.1)
			end
			-- Cráter: labio de pómez oscura con borde de carbón, dos escalones de pómez a cada lado (el de dentro
			-- más bajo) y tres cristales de azufre delante del pie de la llama.
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
			for side = -1, 1, 2 do
				make.block(
					Vector3.new(width * 0.1, height * 0.1, 0.3),
					PUMICE,
					SLATE,
					CFrame.new(side * width * 0.4, footY + height * 0.1, plateZ + 0.2)
				)
				make.block(
					Vector3.new(width * 0.07, height * 0.2, 0.28),
					PUMICE,
					SLATE,
					CFrame.new(side * width * 0.455, footY + height * 0.15, plateZ + 0.2)
				)
			end
			for index, x in { -0.3, 0, 0.3 } do
				fireCrystal(
					make,
					Vector3.new(x * width, footY + height * 0.06, plateZ + 0.34),
					Vector3.new(x * 1.6, 1, 0.5),
					if index == 2 then 0.66 else 0.56 - math.abs(x) * 0.3,
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

	-- Traje de temporada del cazador, Acechador del Fuego Azul. Delante: jubón de cuero de carbón con costuras
	-- pintadas de pómez (cuatro tiras finas y dos travesaños), la correa del carcaj de pómez con tachones de
	-- azufre, esclavina de pómez en dos escalones con la raya de fuego azul, cinturón con zurrón y un cuchillo
	-- de azufre. Detrás: capa de pómez oscura con ribetes de carbón y el bajo en flecos de carbón, y el carcaj
	-- de pómez con aros de carbón y flechas de plumas celestes. Todo va alineado con los ejes (sin giros) para
	-- que entre en la malla; solo el neón, el cristal y las llamas quedan sueltos. Por grados: 0, todo eso;
	-- 1, las hombreras; 2, collar de tres puntas de flecha de azufre con un broche de fuego azul, flecos de
	-- pómez bajo la esclavina, la capucha bajada forrada de celeste y dos cristales de azufre en el carcaj;
	-- 3, tres zarpazos de fuego azul en la capa, aros de fuego azul en el carcaj y una llama pequeña entre las
	-- flechas (arden); 4, la llama de las flechas más grande, el bajo de la capa en llamas y el fuego de
	-- partículas, con su luz. Además: flecos de carbón, ribetes y remaches en la capa desde el 1.
	local function blueFireStalker(body: Body, grade: number)
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local lit = grade >= 4
		local FACING_FRONT = CFrame.Angles(0, math.pi, 0)
		-- Llama pequeña del bajo de la capa: tres filas (siete piezas), menos que la llama pequeña de siempre.
		local HEM_FLAME = { ".X.", "XCX", "XWX" }
		-- Punta que cuelga hacia abajo: "x" es el centro, "topY" donde nace y "z" su plano. Con STEPS son tres escalones.
		local function dropFang(
			length: number,
			wide: number,
			color: Color3,
			material: Enum.Material,
			x: number,
			topY: number,
			z: number
		)
			make.fang(
				length,
				wide,
				color,
				material,
				CFrame.new(x + wide / 2, topY, z + wide / 2) * CFrame.Angles(0, 0, math.pi)
			)
		end

		-- Jubón de cuero de carbón con las costuras pintadas: tres tiras verticales finas (centro y costados) y
		-- dos travesaños, fuera del paso de la correa.
		make.block(
			Vector3.new(width + 0.12, height * 0.92, depth + 0.14),
			CHARCOAL,
			LEATHER_MATERIAL,
			CFrame.new(0, -height * 0.02, 0)
		)
		for _, x in { -0.4, 0, 0.4 } do
			make.block(
				Vector3.new(0.04, height * (if x == 0 then 0.74 else 0.66), 0.03),
				PUMICE_DARK,
				LEATHER_MATERIAL,
				CFrame.new(x * width, -height * 0.04, front - 0.005)
			)
		end
		make.block(
			Vector3.new(width * 0.14, 0.04, 0.03),
			PUMICE_DARK,
			LEATHER_MATERIAL,
			CFrame.new(-width * 0.22, height * 0.2, front - 0.005)
		)
		make.block(
			Vector3.new(width * 0.14, 0.04, 0.03),
			PUMICE_DARK,
			LEATHER_MATERIAL,
			CFrame.new(width * 0.22, -height * 0.2, front - 0.005)
		)
		quiverStrap(make, front - 0.04, 0.16, PUMICE_DARK, LEATHER_MATERIAL)
		local strapFrom = Vector3.new(width * 0.3, height / 2 - 0.02, front - 0.04)
		local strapTo = Vector3.new(-width * 0.4, -height / 2 + 0.12, front - 0.04)
		for _, t in { 0.25, 0.5, 0.75 } do
			make.ball(0.12, SULFUR, SMOOTH, CFrame.new(strapFrom:Lerp(strapTo, t) + Vector3.new(0, 0, -0.08)))
		end
		-- Esclavina de pómez sobre los hombros en dos escalones (el de abajo, más oscuro) con la raya de fuego azul.
		make.block(Vector3.new(width + 0.36, 0.3, depth + 0.36), PUMICE, FABRIC, CFrame.new(0, height / 2 - 0.06, 0.04))
		make.block(
			Vector3.new(width + 0.14, 0.18, depth + 0.24),
			PUMICE_DARK,
			FABRIC,
			CFrame.new(0, height / 2 - 0.27, 0.04)
		)
		make.block(
			Vector3.new(width + 0.16, 0.05, 0.08),
			BLUE_FIRE,
			NEON,
			CFrame.new(0, height / 2 - 0.39, -depth / 2 - 0.13)
		)
		if grade >= 2 then
			-- Collar: un cordón de carbón con tres puntas de flecha de azufre colgando y un broche con una llama azul.
			make.block(
				Vector3.new(width * 0.5, 0.06, 0.05),
				CHARCOAL,
				FABRIC,
				CFrame.new(0, height / 2 - 0.46, front - 0.07)
			)
			for index = 1, 3 do
				dropFang(
					if index == 2 then 0.36 else 0.28,
					0.14,
					SULFUR,
					SLATE,
					(index - 2) * width * 0.18,
					height / 2 - 0.46,
					front - 0.1
				)
			end
			local brooch = CFrame.new(-width * 0.3, height / 2 - 0.2, front - 0.14)
			make.rod(0.06, 0.4, CHARCOAL, SLATE, brooch * FACING)
			pixelFlame(make, SMALL_FLAME, BLUE_FLAME, brooch * CFrame.new(0, -0.17, -0.04) * FACING_FRONT, 0.06, false)
			-- Flecos de pómez que cuelgan del escalón de abajo de la esclavina, largos y cortos.
			for index = -2, 2 do
				local length = if index % 2 == 0 then 0.24 else 0.16
				make.block(
					Vector3.new(0.11, length, 0.06),
					PUMICE,
					FABRIC,
					CFrame.new(index * width * 0.2, height / 2 - 0.42 - length / 2, -(depth / 2 + 0.11))
				)
			end
		end

		-- Espalda: capa de pómez oscura con ribetes de carbón en los lados, el bajo de carbón y la raya azul.
		local capeHeight = height * 1.08
		local capeY = height / 2 - capeHeight / 2 - 0.02
		local capeZ = back + 0.16
		make.block(Vector3.new(width * 1.02, capeHeight, 0.12), PUMICE_DARK, FABRIC, CFrame.new(0, capeY, capeZ))
		for side = -1, 1, 2 do
			make.block(
				Vector3.new(width * 0.08, capeHeight * 0.9, 0.16),
				CHARCOAL,
				FABRIC,
				CFrame.new(side * width * 0.47, capeY - capeHeight * 0.04, capeZ + 0.01)
			)
		end
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
		-- Grado 1: nueve flecos de carbón en escalones (largo y corto) que cuelgan del bajo de la capa y tres
		-- remaches de azufre en su cuello.
		for index = 0, 8 do
			local length = if index % 2 == 0 then 0.36 else 0.24
			make.block(
				Vector3.new(width * 0.085, length, 0.12),
				CHARCOAL,
				FABRIC,
				CFrame.new(-width * 0.46 + index * width * 0.115 + 0.09, capeBottom + 0.02 - length / 2, capeZ + 0.02)
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
					HEM_FLAME,
					BLUE_FLAME,
					CFrame.new(x, capeBottom + 0.12, capeZ + 0.08),
					0.12,
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
			feathers = { BLUE_FIRE_PALE, BLUE_FIRE_MID },
		}, 0.32)
		-- Banda de carbón a media altura del carcaj (con malla, un bloque recto: el cilindro girado no entraría).
		if STEPS.on then
			make.block(Vector3.new(0.8, 0.14, 0.62), CHARCOAL, SLATE, CFrame.new(quiverAt.Position))
		else
			make.rod(0.1, 0.6, CHARCOAL, SLATE, quiverAt * UPRIGHT)
		end
		if grade >= 2 then
			-- Grado 2: una punta de azufre en el fondo del carcaj (recta, sin giro) y dos cristales de azufre.
			make.ball(
				0.14,
				SULFUR,
				SMOOTH,
				CFrame.new((quiverAt * CFrame.new(0, -quiverLength / 2 - 0.02, 0)).Position)
			)
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

		-- Cinturón con zurrón de pómez (con su botón de azufre) y un cuchillo de azufre: mango y guarda rectos
		-- con malla, la hoja en tres escalones.
		local beltFront = seasonBelt(body, grade)
		local waist = body.waist
		local hipWidth = waist.size.X
		local pouch = CFrame.new(hipWidth * 0.32, -0.12, beltFront - 0.06)
		waist.block(Vector3.new(0.36, 0.32, 0.14), CHARCOAL, LEATHER_MATERIAL, pouch)
		waist.block(Vector3.new(0.4, 0.13, 0.18), PUMICE, FABRIC, pouch * CFrame.new(0, 0.12, -0.01))
		waist.ball(0.08, SULFUR, SMOOTH, pouch * CFrame.new(0, 0.1, -0.1))
		local knife = CFrame.new(-hipWidth * 0.36, -0.05, beltFront - 0.04)
			* CFrame.Angles(0, 0, if STEPS.on then 0 else 0.25)
		waist.block(Vector3.new(0.1, 0.24, 0.1), CHARCOAL, LEATHER_MATERIAL, knife)
		waist.block(Vector3.new(0.2, 0.04, 0.13), SULFUR, SLATE, knife * CFrame.new(0, -0.13, 0))
		waist.fang(0.4, 0.1, SULFUR, SLATE, knife * CFrame.new(0.05, -0.15, 0.05) * CFrame.Angles(0, 0, math.pi))
		seasonLimbs(body, grade, PUMICE_DARK, FABRIC)
	end

	-- Traje de temporada del mago, Invocador del Fuego Azul. Delante: túnica de carbón con una pechera de
	-- pómez ribeteada de fuego azul, un amuleto de disco de carbón en el pecho y el bajo en tres faldones
	-- escalonados que se ensanchan (pómez oscura, carbón, pómez). Detrás: el panel de pómez oscura con el
	-- marco del cráter (backFrame), un disco de pómez con aro de carbón y un sol de azufre, y los mismos
	-- faldones. Casi todo es pómez, carbón y detalle pintado (bloques lisos alineados, que entran en la malla);
	-- lo suelto es el neón, los cristales y las llamas. Por grados: 0, todo eso; 1, las hombreras, borlas,
	-- bandas de azufre en el bajo y en la espalda, gotas azules en el bajo, brasas que giran sobre el disco,
	-- botones y puntadas en la pechera; 2, la llama del amuleto con tres remaches, la gorguera en escalones
	-- sobre la nuca con tres cristales de azufre y dos talismanes de pómez bajo el disco; 3, un aro de fuego
	-- azul alrededor del disco con seis rayos de azufre, una llama en el centro y los pilares del marco;
	-- 4, en vez de esa llama, la llamarada grande que asoma por encima de los hombros, una corona de cuatro
	-- cristales de azufre y el fuego de partículas con su luz.
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

		-- Bajo de la túnica: tres faldones escalonados que se ensanchan hacia abajo, alrededor de todo el torso.
		local hemColors = { PUMICE_DARK, CHARCOAL, PUMICE }
		for tier = 0, 2 do
			make.block(
				Vector3.new(width + 0.16 + 0.06 * tier, 0.14, depth + 0.2 + 0.1 * tier),
				hemColors[tier + 1],
				FABRIC,
				CFrame.new(0, -height / 2 + 0.33 - 0.14 * tier, 0)
			)
		end

		-- Amuleto del pecho: disco de carbón sobre un cuello de pómez oscura.
		local medal = CFrame.new(0, height * 0.12, front - 0.08)
		make.rod(0.1, width * 0.46, PUMICE_DARK, SLATE, medal * FACING)
		make.rod(0.1, width * 0.34, CHARCOAL, SLATE, medal * CFrame.new(0, 0, -0.03) * FACING)
		if grade >= 2 then
			-- Grado 2: la llama de fuego azul dentro del disco y tres remaches de azufre en su borde.
			pixelFlame(make, SMALL_FLAME, BLUE_FLAME, medal * CFrame.new(0, -0.2, -0.2) * FACING_FRONT, 0.07, false)
			for index = 0, 2 do
				local angle = index / 3 * math.pi * 2
				make.ball(
					0.1,
					SULFUR,
					SMOOTH,
					medal * CFrame.new(math.sin(angle) * width * 0.2, math.cos(angle) * width * 0.2, -0.1)
				)
			end
		end

		-- Espalda: panel de pómez oscura con un disco de pómez dentro de un aro de carbón y un sol de azufre.
		local ringAt = CFrame.new(0, height * 0.12, back + 0.2)
		make.block(
			Vector3.new(width * 0.96, height * 1.02, 0.12),
			PUMICE_DARK,
			FABRIC,
			CFrame.new(0, -height * 0.06, back + 0.12)
		)
		make.rod(0.12, width * 0.66, CHARCOAL, SLATE, ringAt * FACING)
		make.rod(0.12, width * 0.54, PUMICE, SLATE, ringAt * CFrame.new(0, 0, 0.03) * FACING)
		make.rod(0.12, width * 0.12, SULFUR, SMOOTH, ringAt * CFrame.new(0, 0, 0.06) * FACING)
		-- Marco del cráter (viga, escuadras y gotas azules; con pilares desde el grado 3).
		backFrame(make, width * 0.96, height * 1.02, -height * 0.06, back + 0.12, grade >= 3, 5, 0)

		if grade >= 1 then
			-- Grado 1: borlas de azufre en las esquinas de arriba del panel.
			for side = -1, 1, 2 do
				local tassel = Vector3.new(side * width * 0.44, height * 0.45 - 0.1, back + 0.2)
				strap(make, tassel, tassel - Vector3.new(0, 0.7, 0), 0.04, CHARCOAL, FABRIC)
				make.ball(0.12, SULFUR, SMOOTH, CFrame.new(tassel - Vector3.new(0, 0.74, 0)))
				-- Dos puntadas de carbón en el borde de la pechera.
				for step = 0, 1 do
					make.block(
						Vector3.new(0.1, 0.05, 0.04),
						CHARCOAL,
						SLATE,
						CFrame.new(side * (width * 0.2), height * (0.28 - 0.18 * step), front - 0.07)
					)
				end
			end
			-- Cuatro botones de azufre bajo el amuleto.
			for index = 0, 3 do
				make.ball(0.09, SULFUR, SMOOTH, CFrame.new(0, -height * (0.14 + 0.07 * index), front - 0.08))
			end
			-- Banda de azufre en el faldón de carbón, por delante y por detrás, y tres bandas pintadas en la
			-- espalda baja (pómez, azufre, pómez).
			for _, sign in { -1, 1 } do
				make.block(
					Vector3.new(width * 0.7 + 0.2, 0.04, 0.03),
					SULFUR,
					SLATE,
					CFrame.new(0, -height / 2 + 0.19, sign * ((depth + 0.3) / 2 + 0.01))
				)
			end
			for index = 0, 2 do
				make.block(
					Vector3.new(width * 0.9, 0.05, 0.03),
					if index == 1 then SULFUR else PUMICE,
					SLATE,
					CFrame.new(0, -height * (0.3 + 0.06 * index), back + 0.2)
				)
			end
			-- Seis brasas que giran dentro del aro, y gotas azules en el bajo de delante.
			local orbit = {}
			for index = 0, 5 do
				local angle = index / 6 * math.pi * 2
				orbit[index + 1] = (ringAt * CFrame.new(
					math.sin(angle) * width * 0.3,
					math.cos(angle) * width * 0.3,
					0.14
				)).Position
			end
			motes(make, orbit, 0.09)
			drips(
				make,
				CFrame.new(0, -height / 2 + 0.1, -(depth / 2 + 0.25)),
				{ -0.2 * width, -0.1 * width, 0, 0.1 * width, 0.2 * width },
				0.28
			)
		end
		if grade >= 2 then
			-- Gorguera en escalones sobre la nuca (pómez oscura, carbón, pómez) con tres cristales de azufre.
			local yokeColors = { PUMICE_DARK, CHARCOAL, PUMICE }
			local yokeWidths = { 0.9, 0.64, 0.4 }
			for tier = 0, 2 do
				make.block(
					Vector3.new(width * yokeWidths[tier + 1], 0.14, 0.14),
					yokeColors[tier + 1],
					SLATE,
					CFrame.new(0, height * 0.45 + 0.06 + 0.14 * tier, back + 0.1)
				)
			end
			for _, x in { -0.14, 0, 0.14 } do
				fireCrystal(
					make,
					Vector3.new(x * width, height * 0.45 + 0.4, back + 0.1),
					Vector3.new(x * 2, 1, 0.3),
					if x == 0 then 0.75 else 0.55,
					0.24,
					SULFUR,
					SULFUR_GLOW
				)
			end
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
			-- Grado 3: aro de fuego azul alrededor del disco, seis rayos de azufre y una llama en el centro.
			hoop(make, ringAt * CFrame.new(0, 0, 0.06), width * 0.38, 14, 0.1, BLUE_FIRE, NEON)
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
			local flameAt = ringAt * CFrame.new(0, width * 0.3, 0.12)
			if lit then
				blueFire(pixelFlame(make, BIG_FLAME, BLUE_FLAME, flameAt, width * 0.07, false), 10, 0.8)
			else
				pixelFlame(make, SMALL_FLAME, BLUE_FLAME, flameAt, width * 0.07, false)
			end
		end
		if lit then
			-- Corona de cuatro cristales de azufre que asoma por encima de los hombros, a los lados de la gorguera.
			for index, x in { -0.44, -0.3, 0.3, 0.44 } do
				fireCrystal(
					make,
					Vector3.new(x * width, height * 0.44, back + 0.24),
					Vector3.new(x * 1.1, 1, 0.35),
					if index == 1 or index == 4 then 0.8 else 1.05,
					if index == 1 or index == 4 then 0.26 else 0.32,
					SULFUR,
					SULFUR_GLOW
				)
			end
		end

		seasonBelt(body, grade)
		seasonLimbs(body, grade, CHARCOAL, FABRIC, true)
	end

	-- Traje de temporada del médico, Sanador del Fuego Azul. Delante: túnica de pómez clara con vendas
	-- enrolladas, el manto de pómez oscura con la raya de fuego azul, un peto y la bandolera de carbón en
	-- escalones con tres frasquitos. Detrás: capa de pómez oscura, bastidor de madera y una mochila de pómez con
	-- correas. Sin giros con malla: la bandolera y el abanico van en escalones y los frascos, bolas y colmillos
	-- pasan a bloques. Por grados: 0, todo eso; 1, las hombreras, los flecos, los remaches y detrás el abanico
	-- de hierbas (franjas de pómez que se abren sobre la nuca, sin verde); 2, la cruz de fuego azul del peto (la
	-- llama es el símbolo de curar), el líquido azul de los frascos y tres frascos más colgados del bastidor;
	-- 3, el tótem sanador sobre la mochila (dos caras talladas, alas y una llama azul en la cima) y las
	-- nervaduras del abanico; 4, la llamarada grande del tótem y el fuego de partículas con su luz.
	local function blueFireHealer(body: Body, grade: number)
		local make = body.torso
		local width, height, depth = make.size.X, make.size.Y, make.size.Z
		local front = -(depth / 2 + 0.08)
		local back = depth / 2
		local lit = grade >= 4
		local healing = grade >= 2
		-- Frasquito de pómez oscura con tapón de carbón y, con "glow", el líquido de fuego azul (todo bloques).
		local function vial(at: CFrame, size: number, glow: boolean)
			make.block(Vector3.new(size, size * 1.2, size * 0.8), PUMICE_DARK, SLATE, at * CFrame.new(0, size * 0.6, 0))
			make.block(
				Vector3.new(size * 0.5, size * 0.4, size * 0.5),
				CHARCOAL,
				SLATE,
				at * CFrame.new(0, size * 1.4, 0)
			)
			if glow then
				make.block(
					Vector3.new(size * 0.6, size * 0.7, size * 0.2),
					BLUE_FIRE,
					NEON,
					at * CFrame.new(0, size * 0.6, -size * 0.45)
				)
			end
		end
		-- Túnica de pómez clara, el manto de pómez oscura con su raya de fuego azul y tres vendas enrolladas.
		make.block(
			Vector3.new(width + 0.12, height * 0.94, depth + 0.16),
			PUMICE,
			FABRIC,
			CFrame.new(0, -height * 0.02, 0)
		)
		make.block(
			Vector3.new(width + 0.4, 0.34, depth + 0.4),
			PUMICE_DARK,
			FABRIC,
			CFrame.new(0, height / 2 - 0.06, 0.04)
		)
		make.block(
			Vector3.new(width + 0.42, 0.06, depth + 0.42),
			BLUE_FIRE,
			NEON,
			CFrame.new(0, height / 2 - 0.24, 0.04)
		)
		for _, y in { -0.12, -0.24, -0.36 } do
			make.block(Vector3.new(width + 0.22, 0.1, depth + 0.24), PUMICE_DARK, FABRIC, CFrame.new(0, height * y, 0))
		end
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
				BLUE_FIRE,
				NEON,
				plastron * CFrame.new(0, 0, -0.14)
			)
			make.block(
				Vector3.new(width * 0.22, height * 0.08, 0.05),
				BLUE_FIRE,
				NEON,
				plastron * CFrame.new(0, 0.04, -0.14)
			)
			fireLight(cross, BLUE_FIRE)
		end
		-- Bandolera de carbón en seis escalones del hombro derecho a la cadera izquierda, con tres frascos.
		local from = Vector3.new(width * 0.3, height / 2 - 0.02, front - 0.08)
		local to = Vector3.new(-width * 0.4, -height / 2 + 0.12, front - 0.08)
		for index = 0, 5 do
			local centre = from:Lerp(to, (index + 0.5) / 6)
			make.block(
				Vector3.new(math.abs(to.X - from.X) / 6 + 0.16, math.abs(to.Y - from.Y) / 6 + 0.16, 0.14),
				CHARCOAL,
				LEATHER_MATERIAL,
				CFrame.new(centre)
			)
		end
		for _, t in { 0.22, 0.42, 0.62 } do
			local at = from:Lerp(to, t)
			vial(CFrame.new(at.X, at.Y - 0.36, at.Z - 0.1), 0.2, healing)
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
			-- Grado 2: cuatro remaches en las esquinas del peto y tres cristales de azufre que asoman por detrás
			-- del manto.
			for sy = -1, 1, 2 do
				for sx = -1, 1, 2 do
					make.ball(0.09, SULFUR, SMOOTH, plastron * CFrame.new(sx * width * 0.15, sy * height * 0.16, -0.12))
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
		-- remaches en el bastidor, dos rayas de fuego azul en los bordes de la capa y el abanico de hierbas.
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
		-- Abanico de hierbas: un tallo de carbón y cinco franjas de pómez que se abren hacia arriba tras la nuca.
		-- Va detrás del tótem, así que se ve de espaldas como un fondo.
		local fan = CFrame.new(0, height / 2 - 0.05, back + 0.34)
		make.block(Vector3.new(0.14, 0.5, 0.08), CHARCOAL, LEATHER_MATERIAL, fan * CFrame.new(0, 0.2, 0))
		local fanWidths = { 0.4, 0.6, 0.8, 0.95, 1.05 }
		for index, fanWidth in fanWidths do
			make.block(
				Vector3.new(width * fanWidth, 0.14, 0.06),
				if index == 5 then CHARCOAL elseif index % 2 == 0 then PUMICE_DARK else PUMICE,
				FABRIC,
				fan * CFrame.new(0, 0.1 + (index - 1) * 0.145, 0)
			)
		end
		if healing then
			-- Grado 2: dos frascos con líquido azul a los lados de la mochila y tres colgados con un cordón del
			-- travesaño de abajo del bastidor, con un remache en cada extremo de ese travesaño.
			for side = -1, 1, 2 do
				vial(pack * CFrame.new(side * (width * 0.36 + 0.24), -height * 0.2, 0.04), 0.42, true)
			end
			for _, x in { -0.25, 0, 0.25 } do
				make.block(
					Vector3.new(0.03, 0.2, 0.03),
					CHARCOAL,
					LEATHER_MATERIAL,
					CFrame.new(x * width, -height * 0.4 - 0.15, back + 0.3)
				)
				vial(CFrame.new(x * width, -height * 0.4 - 0.5, back + 0.3), 0.22, true)
			end
			for side = -1, 1, 2 do
				make.ball(0.1, SULFUR, SMOOTH, CFrame.new(side * width * 0.43, -height * 0.4, back + 0.3))
			end
		end
		if grade >= 3 then
			-- Tótem sanador sobre la mochila: peana de carbón, columna de pómez con la cara tallada, cabeza de
			-- pómez oscura con ojos de fuego azul, tres escalones de ala a cada lado, una corona de carbón con
			-- una bola de azufre y la llama azul encima. Todo en bloques sin giro.
			local totem = pack * CFrame.new(0, height * 0.31 + 0.04, 0)
			local K = 1.35 -- escala del tótem: pequeño se perdía en la espalda
			local function carve(size: Vector3, color: Color3, material: Enum.Material, x: number, y: number, z: number)
				make.block(size * K, color, material, totem * CFrame.new(x * K, y * K, z * K))
			end
			carve(Vector3.new(0.5, 0.12, 0.42), CHARCOAL, SLATE, 0, 0.06, 0)
			carve(Vector3.new(0.4, 0.5, 0.36), PUMICE, SLATE, 0, 0.37, 0)
			for _, y in { 0.18, 0.62 } do
				carve(Vector3.new(0.44, 0.07, 0.4), CHARCOAL, SLATE, 0, y, 0)
			end
			for side = -1, 1, 2 do
				carve(Vector3.new(0.1, 0.08, 0.03), CHARCOAL, SLATE, side * 0.1, 0.42, 0.19)
				carve(Vector3.new(0.09, 0.09, 0.03), BLUE_FIRE_PALE, NEON, side * 0.08, 0.95, 0.17)
				carve(Vector3.new(0.3, 0.12, 0.08), PUMICE, SLATE, side * 0.33, 0.82, 0)
				carve(Vector3.new(0.24, 0.12, 0.08), PUMICE_DARK, SLATE, side * 0.5, 0.94, 0)
				carve(Vector3.new(0.14, 0.12, 0.08), CHARCOAL, SLATE, side * 0.66, 1.06, 0)
			end
			carve(Vector3.new(0.2, 0.06, 0.03), CHARCOAL, SLATE, 0, 0.27, 0.19)
			carve(Vector3.new(0.36, 0.38, 0.32), PUMICE_DARK, SLATE, 0, 0.9, 0)
			carve(Vector3.new(0.14, 0.08, 0.04), CHARCOAL, SLATE, 0, 0.82, 0.17)
			carve(Vector3.new(0.3, 0.08, 0.28), CHARCOAL, SLATE, 0, 1.13, 0)
			make.ball(0.14 * K, SULFUR, SMOOTH, totem * CFrame.new(0, 1.24 * K, 0))
			-- Nervaduras de carbón sobre el abanico.
			for _, x in { -0.3, 0, 0.3 } do
				make.block(Vector3.new(0.04, 0.7, 0.04), CHARCOAL, SLATE, fan * CFrame.new(x * width, 0.4, 0.05))
			end
			local flameAt = totem * CFrame.new(0, 1.3 * K, 0.02)
			local flame = if lit
				then pixelFlame(make, BIG_FLAME, BLUE_FLAME, flameAt, width * 0.065, false)
				else pixelFlame(make, SMALL_FLAME, BLUE_FLAME, flameAt, 0.14, false)
			smoke(flame, 2, Color3.fromRGB(150, 160, 190), 0.7)
			if lit then
				blueFire(flame, 10, 0.7)
			end
			-- Dos cristales de azufre a los pies de la peana y cuatro chispas que suben (cinco más en el grado 4).
			for side = -1, 1, 2 do
				fireCrystal(
					make,
					(totem * CFrame.new(side * 0.36, 0.14, 0.14)).Position,
					totem:VectorToWorldSpace(Vector3.new(side * 2, 1, 0.6)),
					0.4,
					0.16,
					SULFUR,
					SULFUR_GLOW
				)
			end
			local sparks = {}
			for index, x in { -0.18, -0.07, 0.07, 0.18 } do
				sparks[index] = (totem * CFrame.new(x * width, 2.3 + 0.1 * (index % 2), 0.1)).Position
			end
			motes(make, sparks, 0.08)
			if lit then
				local high = {}
				for index = 1, 5 do
					high[index] = (totem * CFrame.new((index - 3) * width * 0.1, 2.8 + 0.12 * (index % 3), 0.12)).Position
				end
				motes(make, high, 0.08)
			end
		end

		-- Cinturón, una venda enrollada y dos bolsitas de hierbas (de pómez: sin verde).
		local beltFront = seasonBelt(body, grade)
		local waist = body.waist
		local hipWidth = waist.size.X
		waist.rod(0.24, 0.22, PUMICE, FABRIC, CFrame.new(hipWidth * 0.32, -0.06, beltFront - 0.1) * UPRIGHT)
		herbPouch(waist, CFrame.new(-hipWidth * 0.34, -0.12, beltFront - 0.08), PUMICE_DARK)
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

-- ============================== Mallas con textura (Fase 20 Q6) ==============================
-- Las piezas de un grupo `<Anclaje>_<Soft|Hard>` (Data/ArmorMeshes) pueden pasar a una `MeshPart` por grupo. Todo va en
-- la tabla "Meshing" para no gastar locales de este módulo. Sin entradas en Data/ArmorMeshes, "wear" no hace nada de esto.
local Meshing = {
	-- Las partes R15 a las que se sueldan las piezas (en R6 no hay: el trozo del torso o del brazo no entra).
	ANCHORS = {
		UpperTorso = true,
		LowerTorso = true,
		LeftUpperArm = true,
		RightUpperArm = true,
		LeftLowerArm = true,
		RightLowerArm = true,
		LeftUpperLeg = true,
		RightUpperLeg = true,
	} :: { [string]: boolean },
	cache = {} :: { [string]: MeshPart }, -- mallas ya cargadas, por id
	loading = {} :: { [string]: boolean },
	failed = {} :: { [string]: boolean }, -- las que no cargaron: no se reintentan en cada "wear"
	-- Personajes vestidos con bloques a la espera de que carguen las mallas de su entrada.
	pending = setmetatable({}, { __mode = "k" }) :: {
		[Model]: {
			entry: ArmorMeshes.Entry,
			armorId: string?,
			roleId: string?,
			outfitId: string?,
			grade: number?,
		},
	},
}

-- "Soft" (Fabric y Leather) o "Hard" (cualquier otro material liso): la clase de material de una malla.
function ArmorModels.meshClass(material: Enum.Material): string
	return if material == FABRIC or material == LEATHER_MATERIAL then "Soft" else "Hard"
end

-- La parte del cuerpo (Part0 de su WeldConstraint) a la que va soldada una pieza de armadura.
function ArmorModels.anchorOf(piece: BasePart): BasePart?
	for _, child in piece:GetChildren() do
		if child:IsA("WeldConstraint") then
			local anchor = (child :: WeldConstraint).Part0
			if anchor and anchor ~= piece then
				return anchor
			end
		end
	end
	return nil
end

-- Centro y tamaño (studs, en el espacio de "anchor") de una pieza que puede ir a la malla, y el nombre de su grupo
-- (`<Anclaje>_<Soft|Hard>`); o nil si tiene que seguir suelta: no es un bloque, lleva hijos (una forma, un adorno), es de
-- neón o cristal, es transparente, se llama como una pieza que no se funde, está girada fuera de los ejes del ancla
-- (múltiplos de 90°, tolerancia 0,01 rad) o el ancla no es una de las R15. Lo usan "wear" y el volcado
-- (ServerStorage.Tools.Mallas), para que vean las mismas piezas.
function ArmorModels.meshableBox(piece: BasePart, anchor: BasePart): (Vector3?, Vector3?, string?)
	if
		not Meshing.ANCHORS[anchor.Name]
		or piece.ClassName ~= "Part"
		or (piece :: Part).Shape ~= Enum.PartType.Block
	then
		return nil, nil, nil
	end
	local material = piece.Material
	if
		material == NEON
		or material == GLASS
		or piece.Transparency > 0
		or piece.Reflectance > 0
		or VoxelMerge.isKept(piece.Name)
	then
		return nil, nil, nil
	end
	for _, child in piece:GetChildren() do
		if not child:IsA("WeldConstraint") then
			return nil, nil, nil
		end
	end
	local cf = anchor.CFrame:ToObjectSpace(piece.CFrame)
	local _, _, _, r11, r12, r13, r21, r22, r23, r31, r32, r33 = cf:GetComponents()
	local rows = { { r11, r12, r13 }, { r21, r22, r23 }, { r31, r32, r33 } }
	local own = { piece.Size.X, piece.Size.Y, piece.Size.Z }
	local size = { 0, 0, 0 }
	for i, row in rows do
		for j, value in row do
			local abs = math.abs(value)
			if abs > 0.9999 then
				-- Girada 90°: el lado de la pieza que cae en este eje del ancla intercambia el tamaño.
				size[i] = own[j]
			elseif abs > 0.01 then
				return nil, nil, nil
			end
		end
		if size[i] == 0 then
			return nil, nil, nil
		end
	end
	return cf.Position, Vector3.new(size[1], size[2], size[3]), `{anchor.Name}_{ArmorModels.meshClass(material)}`
end

-- La entrada de Data/ArmorMeshes de lo que se viste (el traje con su grado, o la armadura con la versión de su rol).
function Meshing.find(armorId: string?, roleId: string?, outfitId: string?, grade: number?): ArmorMeshes.Entry?
	if outfitId and OUTFITS[outfitId] then
		local grades = ArmorMeshes.Outfit[outfitId]
		return if grades then grades[math.clamp(grade or ArmorModels.grade(armorId), 0, ArmorModels.MAX_GRADE)] else nil
	end
	local byRole = if armorId then BUILDERS[armorId] else nil
	local roles = if armorId then ArmorMeshes.Armor[armorId] else nil
	if byRole and roles then
		return roles[if roleId and byRole[roleId] then roleId else DEFAULT_ROLE]
	end
	return nil
end

-- Si ya están cargadas todas las mallas de la entrada (una sin id no cuenta: se queda en bloques para siempre).
function Meshing.isReady(entry: ArmorMeshes.Entry): boolean
	for _, group in entry.groups do
		if group.mesh == "" or group.texture == "" or not Meshing.cache[group.mesh] then
			return false
		end
	end
	return true
end

-- Los personajes vestidos con bloques cuyas mallas ya han llegado se vuelven a vestir, esta vez con ellas.
function Meshing.flush()
	local due: { Model } = {}
	for character, request in Meshing.pending do
		if Meshing.isReady(request.entry) then
			table.insert(due, character)
		end
	end
	for _, character in due do
		local request = Meshing.pending[character]
		Meshing.pending[character] = nil
		if request and character.Parent then
			ArmorModels.wear(character, request.armorId, request.roleId, request.outfitId, request.grade)
		end
	end
end

-- Pide a Roblox las mallas de la entrada, cada una en su hilo. Cada vez que llega una, reconstruye los personajes que
-- esperaban (el cliente y el servidor visten antes de que lleguen: la primera carga de la sesión tarda).
function Meshing.load(entry: ArmorMeshes.Entry)
	for _, group in entry.groups do
		local id = group.mesh
		if
			id ~= ""
			and group.texture ~= ""
			and not Meshing.cache[id]
			and not Meshing.loading[id]
			and not Meshing.failed[id]
		then
			Meshing.loading[id] = true
			task.spawn(function()
				local ok, mesh = pcall(function()
					return game:GetService("AssetService"):CreateMeshPartAsync(Content.fromUri(id))
				end)
				if ok then
					Meshing.cache[id] = mesh
				else
					Meshing.failed[id] = true
					warn(`[ArmorModels] No se pudo cargar la malla {id}: {mesh}`)
				end
				Meshing.loading[id] = nil
				Meshing.flush()
			end)
		end
	end
end

-- Sustituye las piezas de cada grupo con malla por su `MeshPart`, soldada al ancla con un Weld de desfase explícito (un
-- WeldConstraint lo calcula al activarse, y con el modelo ya movido quedaría lejos). Solo anclas R15 de "character".
function Meshing.apply(model: Model, character: Model, entry: ArmorMeshes.Entry)
	local byGroup: { [string]: { BasePart } } = {}
	local anchors: { [string]: BasePart } = {}
	for _, piece in model:GetChildren() do
		local anchor = if piece:IsA("BasePart") then ArmorModels.anchorOf(piece) else nil
		if anchor and anchor.Parent == character then
			local _, _, group = ArmorModels.meshableBox(piece :: BasePart, anchor)
			if group and entry.groups[group] then
				anchors[group] = anchor
				byGroup[group] = byGroup[group] or {}
				table.insert(byGroup[group], piece :: BasePart)
			end
		end
	end
	for group, pieces in byGroup do
		local data = entry.groups[group]
		local anchor = anchors[group]
		local cached = Meshing.cache[data.mesh]
		if not cached then
			continue
		end
		-- Escala eje a eje: el ancla de este avatar frente a la del rig de referencia del volcado.
		local ref = entry.ref[anchor.Name]
		local factor = Vector3.one
		if ref and ref.X > 0 and ref.Y > 0 and ref.Z > 0 then
			factor = Vector3.new(anchor.Size.X / ref.X, anchor.Size.Y / ref.Y, anchor.Size.Z / ref.Z)
		end
		local mesh = cached:Clone()
		mesh.Size = data.size * factor
		mesh.TextureID = data.texture
		mesh.Color = Color3.new(1, 1, 1)
		mesh.Material = if string.sub(group, -4) == "Soft" then FABRIC else SMOOTH
		mesh.Anchored = false
		mesh.CanCollide = false
		mesh.CanQuery = false
		mesh.CanTouch = false
		mesh.Massless = true
		mesh.CastShadow = false
		mesh.Name = "Armor"
		local relative = CFrame.new(data.offset * factor) * CFrame.Angles(0, math.pi, 0) * mesh.ExtentsCFrame:Inverse()
		mesh.CFrame = anchor.CFrame * relative
		mesh.Parent = model
		local weld = Instance.new("Weld")
		weld.Part0 = anchor
		weld.Part1 = mesh
		weld.C0 = relative
		weld.Parent = mesh
		for _, piece in pieces do
			piece:Destroy()
		end
	end
end

-- Pide las mallas de lo que se vistirá (si tiene entrada en Data/ArmorMeshes); "wear" también las pide solo.
function ArmorModels.preload(armorId: string?, roleId: string?, outfitId: string?, grade: number?)
	local entry = Meshing.find(armorId, roleId, outfitId, grade)
	if entry then
		Meshing.load(entry)
	end
end

function ArmorModels.hasOutfit(outfitId: string): boolean
	return OUTFITS[outfitId] ~= nil
end

function ArmorModels.grade(armorId: string?): number
	return if armorId then ARMOR_GRADE[armorId] or 0 else 0
end

-- Esferas de luz de la armadura de rango IV (la volcánica): bolitas de neón que flotan junto al cuello, los hombros,
-- la espalda y los brazos, cada rol con su color (el verde es el de la curación, del médico; ninguna es roja, que es el
-- daño recibido). Son puntos pequeños y sin halo; piezas sueltas (el neón no entra en la malla).
local ORB_COLORS: { [string]: Color3 } = {
	Guerrero = Color3.fromRGB(255, 140, 40),
	Cazador = Color3.fromRGB(40, 225, 210),
	Mago = Color3.fromRGB(150, 100, 255),
	Medico = Color3.fromRGB(80, 235, 110),
}
-- Posición (X, Y, Z en studs de la parte) y diámetro de cada esfera; en las partes de los dos lados, X se espeja.
local ORB_TORSO = {
	{ 1.7, 1.8, 0.3, 0.11 },
	{ 0.8, 1.7, 0.7, 0.08 },
	{ 2.2, 0.7, -0.5, 0.09 },
	{ 0, 2.2, 0.6, 0.11 },
}
local ORB_UPPER_ARM = { { 1.2, 0.2, 0.3, 0.08 } }
local ORB_LOWER_ARM = { { 0.95, 0, 0.1, 0.1 } }

-- Los trajes míticos llevan las suyas de un dorado pálido, en el grado 4.
local ORB_MYTHIC_OUTFITS: { [string]: boolean } =
	{ TitanKingOutfit = true, SpectralJaguarOutfit = true, FeatheredSerpentOutfit = true, CeibaOfLifeOutfit = true }
local ORB_MYTHIC_COLOR = Color3.fromRGB(255, 208, 110)

local function addOrbs(body: Body, roleId: string?, tint: Color3?)
	local color = tint or ORB_COLORS[roleId or DEFAULT_ROLE] or ORB_COLORS[DEFAULT_ROLE]
	local function orbs(make: Builder, spots: { { number } }, side: number)
		for _, spot in spots do
			if spot[1] == 0 and side == 1 then
				continue -- la del centro, una sola vez
			end
			local at = CFrame.new(spot[1] * side, spot[2], spot[3])
			make.ball(spot[4], color, Enum.Material.Neon, at)
		end
	end
	for _, side in { -1, 1 } do
		orbs(body.torso, ORB_TORSO, side)
		orbs(body.upperArm[side], ORB_UPPER_ARM, side)
		orbs(body.lowerArm[side], ORB_LOWER_ARM, side)
	end
end

-- Viste a "character" con el traje "outfitId" (si lo hay; con el grado "grade" o el de la armadura)
-- o, si no, con la armadura "armorId" en la versión de su rol "roleId". Sustituye a lo que llevara; sin
-- traje ni armadura lo quita. Devuelve el modelo, o nil si no hay nada que poner o no hay torso.
function ArmorModels.wear(
	character: Model,
	armorId: string?,
	roleId: string?,
	outfitId: string?,
	grade: number?,
	boxesOnly: boolean?
): Model?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not (torso and torso:IsA("BasePart")) then
		return nil
	end
	local previous = character:FindFirstChild("ArmorPiece")
	if previous then
		previous:Destroy()
	end
	if Meshing.pending[character] then
		Meshing.pending[character] = nil
	end
	local outfit = if outfitId then OUTFITS[outfitId] else nil
	local byRole = if armorId and Armor[armorId] then BUILDERS[armorId] else nil
	local armor = if byRole then byRole[roleId or DEFAULT_ROLE] or byRole[DEFAULT_ROLE] else nil
	if not (outfit or armor) then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "ArmorPiece"
	local meshEntry = if boxesOnly then nil else Meshing.find(armorId, roleId, outfitId, grade)
	local refs = if meshEntry then meshEntry.ref else nil
	local function arms(r15: string, r6Offset: CFrame, r6Size: Vector3): { [number]: Builder }
		return {
			[-1] = limb(model, character, "Left" .. r15, "Left Arm", r6Offset, r6Size, refs),
			[1] = limb(model, character, "Right" .. r15, "Right Arm", r6Offset, r6Size, refs),
		}
	end
	local body: Body = {
		torso = limb(model, character, "UpperTorso", "Torso", CFrame.identity, nil, refs),
		waist = limb(model, character, "LowerTorso", "Torso", CFrame.new(0, -0.8, 0), Vector3.new(2, 0.4, 1), refs),
		upperArm = arms("UpperArm", CFrame.new(0, 0.4, 0), Vector3.new(1, 1.2, 1)),
		lowerArm = arms("LowerArm", CFrame.new(0, -0.6, 0), Vector3.new(1, 0.8, 1)),
		upperLeg = {
			[-1] = limb(
				model,
				character,
				"LeftUpperLeg",
				"Left Leg",
				CFrame.new(0, 0.35, 0),
				Vector3.new(1, 1.3, 1),
				refs
			),
			[1] = limb(
				model,
				character,
				"RightUpperLeg",
				"Right Leg",
				CFrame.new(0, 0.35, 0),
				Vector3.new(1, 1.3, 1),
				refs
			),
		},
	}
	STEPS.on = boxesOnly == true or meshEntry ~= nil
	if outfit then
		local outfitGrade = math.clamp(grade or ArmorModels.grade(armorId), 0, ArmorModels.MAX_GRADE)
		outfit(body, outfitGrade)
		if outfitId and ORB_MYTHIC_OUTFITS[outfitId] and outfitGrade >= 4 then
			addOrbs(body, roleId, ORB_MYTHIC_COLOR)
		end
	elseif armor then
		armor(body)
		if armorId == "VolcanicArmor" then
			addOrbs(body, roleId)
		end
	end
	STEPS.on = false
	-- Fase 20 Q6: los grupos con malla (Data/ArmorMeshes) sustituyen a sus bloques antes de fusionar. Si las mallas aún no
	-- han cargado se viste con bloques y "Meshing.flush" vuelve a vestir al llegar. Con "boxesOnly" (el volcado) no se usan.
	local entry = meshEntry
	if entry then
		if Meshing.isReady(entry) then
			Meshing.apply(model, character, entry)
		else
			Meshing.pending[character] = {
				entry = entry,
				armorId = armorId,
				roleId = roleId,
				outfitId = outfitId,
				grade = grade,
			}
			Meshing.load(entry)
		end
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
