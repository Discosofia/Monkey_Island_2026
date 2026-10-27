--!strict
-- Modelos de las monturas (Data/Mounts): animales voxel que el jugador monta. Cajas alineadas en
-- celdas de CELL studs, con el suelo en y = 0 y el frente hacia -Z, alrededor de una pieza invisible
-- "Root" en el suelo, bajo el centro del cuerpo (el pivote).
-- Articulado para las animaciones (KeyframeSequence, con un AnimationController): cada hueso es una
-- pieza invisible con su nombre ("Body", "Neck", "Head", "Jaw", "EarL", "Tail", "LegFL" y debajo
-- "ShinFL"…) colgada de su padre con un Motor6D en la articulación, y cada caja va soldada a su
-- hueso (atributo "Bone"). Las animaciones se enlazan por esos nombres.
-- El attachment "Seat" del hueso "Body" marca dónde se sienta el jinete (encima de la manta o la silla), y se
-- mueve con el lomo.

local TweenService = game:GetService("TweenService")

local Mounts = require(script.Parent.Data.Mounts)

local CELL = 0.2

type Kit = {
	-- Caja de la parte "bone" con su centro y su tamaño en celdas.
	box: (bone: string, name: string, center: Vector3, size: Vector3, color: Color3) -> BasePart,
	-- Posición en el modelo (studs, ya escalada) de una celda.
	at: (cell: Vector3) -> Vector3,
}

-- Lo que devuelve cada constructor: la celda del asiento y los huesos, cada uno después de su padre,
-- con la celda de su articulación.
type Built = {
	seat: Vector3,
	joints: { { bone: string, parent: string, pivot: Vector3 } },
	-- Celda de la boca, de donde sale el escupitajo (si la montura escupe).
	mouth: Vector3?,
	-- Celda de la boca de la que sale la onda del rugido (si la montura ruge).
	roar: Vector3?,
	aura: Aura?,
}

-- Aura que gira alrededor del cuerpo como un barril (sobre el eje cabeza-cola, Z): bandas de luz
-- (Beam) en arco a lo largo del cuerpo y cubitos de neón, en un hueso "Aura" que gira la propia
-- montura (MountModels.animateAura). Medidas en celdas.
type Aura = {
	center: Vector3, -- eje del cilindro
	radius: number,
	length: number, -- largo del cilindro (en Z)
	bands: { number }, -- Z de cada banda
	colors: { Color3 },
	cubes: number,
}

local MountModels = {}

-- Giro del aura (radianes por segundo): parada, al galope y lo que suma el rugido (se apaga en un
-- segundo).
local AURA_SPIN_IDLE, AURA_SPIN_RUN, AURA_SPIN_ROAR = 0.9, 3, 7

-- Estado del aura de cada montura construida que la tiene (para girarla y avivarla al rugir).
type AuraState = {
	motor: Motor6D,
	rest: CFrame,
	angle: number,
	boost: number,
	beams: { Beam },
	colors: { Color3 },
}
local auras: { [Model]: AuraState } = setmetatable({}, { __mode = "k" }) :: any

-- Colores de la manta y las borlas andinas (docs/img/LlamaVoxel.jfif). Studio aclara los tonos
-- saturados: van algo más oscuros que en la referencia.
local MAGENTA = Color3.fromRGB(215, 20, 125)
local RED = Color3.fromRGB(215, 25, 30)
local YELLOW = Color3.fromRGB(245, 200, 15)
local GREEN = Color3.fromRGB(25, 165, 55)

local builders: { [string]: (kit: Kit) -> Built } = {
	-- Llama Andina (docs/img/LlamaVoxel.jfif y las fotos de llamas de docs/img): lana blanca con la
	-- grupa, los muslos, la panza y las orejas negras, cuello largo, orejas altas que se curvan hacia
	-- dentro como un plátano, gafas de sol más anchas que la cabeza, collar de borlas y la manta
	-- tejida en marcos (rojo, amarillo, verde, rojo y magenta en el centro) con flecos rojos.
	Llama = function(k)
		local box = k.box
		local wool = Color3.fromRGB(228, 226, 220)
		local speck = Color3.fromRGB(198, 196, 192)
		local black = Color3.fromRGB(30, 28, 32)
		local hoof = Color3.fromRGB(48, 44, 48)
		local muzzle = Color3.fromRGB(208, 204, 200)
		local nose = Color3.fromRGB(95, 88, 90)
		local fluff = Color3.fromRGB(238, 236, 230)
		local cheek = Color3.fromRGB(196, 190, 186) -- sombra de la cara: cachetes, nariz y barbilla
		-- Bozal de cuerda turquesa, como el de las fotos (no verde: el verde es solo para curar).
		local halter = Color3.fromRGB(30, 150, 165)
		local frame = Color3.fromRGB(72, 60, 88)
		local lens = Color3.fromRGB(36, 30, 46)

		-- Cuerpo: tronco, pecho que baja delante, grupa negra y panza negra.
		box("Body", "Torso", Vector3.new(0, 15.5, 2), Vector3.new(7, 7, 18), wool)
		box("Body", "Chest", Vector3.new(0, 15.25, -7.5), Vector3.new(6.6, 7.5, 3), wool)
		box("Body", "Rump", Vector3.new(0, 15.3, 11.8), Vector3.new(6.6, 6.2, 2), black)
		box("Body", "Belly", Vector3.new(0, 11.5, 2), Vector3.new(5.4, 1.2, 15), black)
		-- Lo negro de atrás sube por los costados y el lomo detrás de la manta, con una mancha blanca.
		box("Body", "Haunch", Vector3.new(0, 15.6, 10), Vector3.new(7.24, 7.2, 2.2), black)
		box("Body", "Spot", Vector3.new(1.2, 19.25, 10.4), Vector3.new(2, 0.1, 1.2), wool)
		-- Por detrás (lo que ve el jugador), manchas blancas irregulares sobre la grupa negra: sin ellas
		-- la espalda era una losa negra.
		box("Body", "Spot", Vector3.new(-0.6, 14.3, 12.85), Vector3.new(2.6, 1.8, 0.1), wool)
		box("Body", "Spot", Vector3.new(0.7, 15.5, 12.85), Vector3.new(1.8, 1.2, 0.1), wool)
		box("Body", "Spot", Vector3.new(-2.2, 17.6, 12.85), Vector3.new(1.2, 0.9, 0.1), wool)
		for side = -1, 1, 2 do
			-- Mancha negra del codo, delante y abajo.
			box("Body", "Elbow", Vector3.new(side * 3.35, 12.9, -7.4), Vector3.new(0.12, 2.6, 3), black)
		end

		-- Patas blancas con la pezuña partida en dos dedos; las de atrás, con el muslo negro de la grupa.
		for _, leg in { { "F", -6.5, 2.6, 2.8 }, { "B", 9.6, 3, 3.6 } } do
			local key, z, upperW, upperD = leg[1] :: string, leg[2] :: number, leg[3] :: number, leg[4] :: number
			for side = -1, 1, 2 do
				local bone = `Leg{key}{if side < 0 then "L" else "R"}`
				local shin = `Shin{key}{if side < 0 then "L" else "R"}`
				local x = side * 2.3
				local back = if key == "B" then 0.4 else 0
				box(
					bone,
					"Thigh",
					Vector3.new(x, 9.6, z + back),
					Vector3.new(upperW, 5.6, upperD),
					if key == "B" then black else wool
				)
				box(shin, "Shin", Vector3.new(x, 4, z + back), Vector3.new(2.2, 6, 2.2), wool)
				-- Rodilla (corvejón en las de atrás): un bloque algo más ancho entre los dos tramos.
				box(shin, "Knee", Vector3.new(x, 7, z + back), Vector3.new(2.5, 1, 2.5), wool)
				if key == "B" then
					box(
						bone,
						"Spot",
						Vector3.new(x + side * 0.5, 8.2, z + back + 1.85),
						Vector3.new(1.4, 1.6, 0.1),
						wool
					)
				end
				for toe = -1, 1, 2 do
					box(shin, "Toe", Vector3.new(x + toe * 0.58, 0.55, z + back - 0.3), Vector3.new(1, 1.1, 2.6), hoof)
				end
			end
		end

		-- Cuello largo que se adelanta un poco al subir.
		box("Neck", "NeckBase", Vector3.new(0, 20, -7), Vector3.new(3.8, 7, 4.2), wool)
		box("Neck", "NeckTop", Vector3.new(0, 25.5, -7.8), Vector3.new(3.4, 5, 3.6), wool)
		-- Collar magenta con borlas que cuelgan delante del pecho: cinco columnas de tres pompones
		-- (rojo o magenta arriba, amarillo y verde), separadas para que no parezcan un solo bloque.
		box("Neck", "Collar", Vector3.new(0, 19.9, -7), Vector3.new(4.4, 1.4, 4.8), MAGENTA)
		for i = 1, 5 do
			local x = (i - 3) * 1.05
			-- Las de los lados y el centro, un pompón más largas: escalonadas, como flecos.
			local stripes = if i % 2 == 1 then { RED, YELLOW, GREEN, MAGENTA } else { MAGENTA, YELLOW, GREEN }
			for row, color in stripes do
				box("Neck", "Tassel", Vector3.new(x, 19.65 - row * 0.95, -9.5), Vector3.new(0.85, 0.85, 0.85), color)
			end
		end

		-- Cabeza, hocico gris claro con la nariz y la boca, mechón de lana entre las orejas.
		box("Head", "Skull", Vector3.new(0, 29.5, -8.6), Vector3.new(4.4, 4.2, 5.2), wool)
		box("Head", "Muzzle", Vector3.new(0, 28.2, -12.6), Vector3.new(3.2, 2.8, 2.8), muzzle)
		-- Almohadilla de la nariz algo más oscura arriba del hocico, con las fosas nasales en ranura
		-- (dos bloques en diagonal que bajan hacia el centro, como las de la llama) y un brillo encima.
		box("Head", "NosePad", Vector3.new(0, 28.95, -14.05), Vector3.new(2.6, 1.2, 0.12), cheek)
		for side = -1, 1, 2 do
			box("Head", "Nostril", Vector3.new(side * 0.85, 29.15, -14.13), Vector3.new(0.35, 0.45, 0.1), nose)
			box("Head", "Nostril", Vector3.new(side * 0.55, 28.75, -14.13), Vector3.new(0.35, 0.45, 0.1), nose)
			box("Head", "NoseShine", Vector3.new(side * 0.85, 29.5, -14.13), Vector3.new(0.5, 0.15, 0.1), fluff)
			-- Labio de arriba partido: dos almohadillas a los lados de la raya del centro.
			box("Jaw", "Lip", Vector3.new(side * 0.75, 27.65, -14.15), Vector3.new(1.2, 0.8, 0.3), muzzle)
			-- Cachetes marcados: abultan a los lados bajo las gafas, con el borde de arriba más claro.
			box("Head", "Cheek", Vector3.new(side * 2.42, 28.75, -9.9), Vector3.new(0.45, 1.5, 2.6), cheek)
			box("Head", "Cheek", Vector3.new(side * 2.45, 29.65, -10), Vector3.new(0.45, 0.35, 2.1), fluff)
		end
		-- Interior de la boca: lo tapan los labios y solo se ve cuando la mandíbula se abre (al escupir).
		box("Head", "MouthInside", Vector3.new(0, 27.4, -13.98), Vector3.new(2.4, 1, 0.1), Color3.fromRGB(80, 38, 48))
		box("Jaw", "Mouth", Vector3.new(0, 27.9, -14.12), Vector3.new(0.25, 1, 0.12), nose)
		box("Jaw", "Mouth", Vector3.new(0, 27.15, -14.12), Vector3.new(2.2, 0.2, 0.12), nose)
		-- Barbilla: un escalón bajo el hocico.
		box("Jaw", "Chin", Vector3.new(0, 26.55, -12.5), Vector3.new(2.6, 0.5, 2.4), cheek)
		box("Head", "Tuft", Vector3.new(0, 32, -8.4), Vector3.new(2, 0.8, 2), wool)
		-- Bozal: muserola alrededor del hocico, carrillera por el lado de la cabeza (bajo el cachete)
		-- hasta detrás de las orejas y la tira de la nuca por encima.
		box("Head", "Halter", Vector3.new(0, 29.75, -12), Vector3.new(3.4, 0.3, 0.6), halter)
		box("Head", "Halter", Vector3.new(0, 26.15, -12), Vector3.new(3.4, 0.3, 0.6), halter)
		box("Head", "Halter", Vector3.new(0, 31.65, -6.4), Vector3.new(4.6, 0.12, 0.5), halter)
		for side = -1, 1, 2 do
			box("Head", "Halter", Vector3.new(side * 1.65, 27.95, -12), Vector3.new(0.15, 3.9, 0.6), halter)
			box("Head", "Halter", Vector3.new(side * 2.25, 27.65, -8.8), Vector3.new(0.12, 0.4, 4.8), halter)
			box("Head", "Halter", Vector3.new(side * 2.25, 29.6, -6.4), Vector3.new(0.12, 4, 0.5), halter)
		end
		-- Gafas de sol: dos cristales oscuros, puente, barra de arriba y patillas hasta las orejas.
		for side = -1, 1, 2 do
			box("Head", "Lens", Vector3.new(side * 1.2, 30.4, -11.45), Vector3.new(1.9, 1.2, 0.5), lens)
			box("Head", "Shine", Vector3.new(side * 1.2 - 0.45, 30.7, -11.72), Vector3.new(0.4, 0.3, 0.06), muzzle)
			box("Head", "Temple", Vector3.new(side * 2.35, 31, -9.45), Vector3.new(0.3, 0.35, 3.5), frame)
		end
		box("Head", "Brow", Vector3.new(0, 31.15, -11.5), Vector3.new(4.8, 0.4, 0.6), frame)
		box("Head", "Bridge", Vector3.new(0, 30.6, -11.45), Vector3.new(0.6, 0.35, 0.5), frame)
		-- Orejas negras en tres tramos que se cierran hacia arriba (forma de plátano), claras por dentro.
		for side = -1, 1, 2 do
			local ear = if side < 0 then "EarL" else "EarR"
			box(ear, "Ear", Vector3.new(side * 1.55, 33, -7.2), Vector3.new(1.2, 2.8, 1), black)
			box(ear, "Ear", Vector3.new(side * 1.25, 35.3, -7.4), Vector3.new(1.1, 2.2, 0.9), black)
			box(ear, "Ear", Vector3.new(side * 0.95, 36.6, -7.5), Vector3.new(0.9, 0.8, 0.8), black)
			box(ear, "EarInner", Vector3.new(side * 1.5, 33.4, -7.75), Vector3.new(0.6, 2.6, 0.1), muzzle)
			-- Pompones colgando de la base de la oreja, por fuera.
			box("Head", "Pompom", Vector3.new(side * 2.35, 32.2, -7), Vector3.new(0.8, 0.8, 0.8), MAGENTA)
			box("Head", "Pompom", Vector3.new(side * 2.35, 31.45, -7), Vector3.new(0.7, 0.7, 0.7), YELLOW)
		end

		-- Cola negra corta enroscada hacia arriba.
		box("Tail", "TailTuft", Vector3.new(0, 18, 13), Vector3.new(2, 2, 2), black)
		box("Tail", "TailTuft", Vector3.new(0, 19.8, 13.6), Vector3.new(1.8, 2, 1.6), black)
		box("Tail", "TailTuft", Vector3.new(0, 20.6, 12.7), Vector3.new(1.6, 1.2, 1.4), black)

		-- Manta: placa de base roja sobre el lomo y los costados, y encima marcos cada vez más
		-- pequeños, uno sobre otro (0,1 celdas cada uno). Por los lados, abiertos arriba, siguen en el lomo.
		local front, back, bottom, top, half = -4, 8.5, 13.4, 19.4, 3.9
		local z = (front + back) / 2
		box("Body", "Blanket", Vector3.new(0, top - 0.2, z), Vector3.new(half * 2, 0.4, back - front), RED)
		for side = -1, 1, 2 do
			box(
				"Body",
				"Blanket",
				Vector3.new(side * (half - 0.2), (bottom + top) / 2, z),
				Vector3.new(0.4, top - bottom, back - front),
				RED
			)
		end
		local frames = { { YELLOW, 0.8 }, { GREEN, 1.4 }, { RED, 2 }, { MAGENTA, 2.4 } }
		for i, layer in frames do
			local color, inset = layer[1] :: Color3, layer[2] :: number
			local face = top + 0.1 * (i - 1) -- donde se apoya este marco (arriba y a los lados)
			local side = half + 0.1 * (i - 1)
			local length = back - front - inset * 2
			box("Body", "Blanket", Vector3.new(0, face + 0.05, z), Vector3.new((side + 0.1) * 2, 0.1, length), color)
			for sign = -1, 1, 2 do
				local low = bottom + inset
				local high = face + 0.1
				box(
					"Body",
					"Blanket",
					Vector3.new(sign * (side + 0.05), (low + high) / 2, z),
					Vector3.new(0.1, high - low, length),
					color
				)
			end
		end
		-- Rombos andinos tejidos en el centro magenta de cada costado: rombo amarillo pequeño en escalones
		-- (una caja cuadrada y dos barras en cruz). En el lomo no van: los tapa el jinete.
		local surface = half + 0.45 -- sobre la cara de fuera del marco magenta
		for side = -1, 1, 2 do
			for _, rz in { -0.25, 2.25, 4.75 } do
				local center = Vector3.new(side * surface, 17.8, rz)
				box("Body", "Rhombus", center, Vector3.new(0.1, 1.1, 1.1), YELLOW)
				box("Body", "Rhombus", center, Vector3.new(0.1, 0.4, 1.8), YELLOW)
				box("Body", "Rhombus", center, Vector3.new(0.1, 1.8, 0.4), YELLOW)
			end
		end
		-- Flecos rojos en el borde de abajo.
		for side = -1, 1, 2 do
			for fz = front + 0.6, back - 0.5, 1.1 do
				box("Body", "Fringe", Vector3.new(side * 3.7, 12.95, fz), Vector3.new(0.45, 0.9, 0.6), RED)
			end
		end

		-- Motas grises de la lana en el cuello (semilla fija: todas las llamas iguales).
		local rng = Random.new(7)
		for _ = 1, 6 do
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local y = rng:NextNumber(17.5, 27)
			local width = if y > 23 then 1.7 else 1.9
			box(
				"Neck",
				"Speck",
				Vector3.new(side * (width + 0.05), y, rng:NextNumber(-9, -6)),
				Vector3.new(0.1, 0.8, 1.4),
				speck
			)
		end
		-- Pecho lanudo: dos mechones más claros que se escalonan bajo las borlas.
		box("Body", "Fluff", Vector3.new(0, 13, -9.2), Vector3.new(5, 1.6, 0.4), fluff)
		box("Body", "Fluff", Vector3.new(0, 11.9, -9.1), Vector3.new(3.6, 1, 0.4), fluff)

		-- Articulaciones: lomo en su centro, cuello en la base, cabeza en lo alto del cuello, mandíbula
		-- detrás del hocico (mastica de lado), orejas en su base, cola en la grupa, y cada pata en el
		-- hombro o la cadera con la caña en la rodilla.
		local joints = {
			{ bone = "Body", parent = "Root", pivot = Vector3.new(0, 15.5, 1) },
			{ bone = "Neck", parent = "Body", pivot = Vector3.new(0, 18, -7) },
			{ bone = "Head", parent = "Neck", pivot = Vector3.new(0, 27.5, -7.8) },
			{ bone = "Jaw", parent = "Head", pivot = Vector3.new(0, 27, -11.4) },
			{ bone = "EarL", parent = "Head", pivot = Vector3.new(-1.55, 31.6, -7.2) },
			{ bone = "EarR", parent = "Head", pivot = Vector3.new(1.55, 31.6, -7.2) },
			{ bone = "Tail", parent = "Body", pivot = Vector3.new(0, 18, 12.5) },
		}
		for _, leg in { { "F", -6.5 }, { "B", 10 } } do
			for side = -1, 1, 2 do
				local name = `{leg[1]}{if side < 0 then "L" else "R"}`
				local x, lz = side * 2.3, leg[2] :: number
				table.insert(joints, { bone = `Leg{name}`, parent = "Body", pivot = Vector3.new(x, 12, lz) })
				table.insert(joints, { bone = `Shin{name}`, parent = `Leg{name}`, pivot = Vector3.new(x, 7, lz) })
			end
		end
		return { seat = Vector3.new(0, top + 0.4, 2), joints = joints, mouth = Vector3.new(0, 27.4, -14.4) }
	end,

	-- Jaguar Albino Esmeralda (docs/img/Jaguar_con_aura.jpg, solo de forma; detalles de la entrevista del
	-- 27-10-2026): pelaje blanco con marfil en el vientre, el hocico y el pecho, nariz, almohadillas y
	-- orejas rosas por dentro, ojos esmeralda que brillan, rosetas huecas de jade (anillos con el centro
	-- blanco, también en la grupa: es lo que se ve por detrás), cola con anillos de jade que se curva
	-- hacia arriba, silla azul marino con oro y collar con una esmeralda. El aura pastel la pone
	-- MountModels.build con "aura".
	Jaguar = function(k)
		local box = k.box
		local fur = Color3.fromRGB(232, 230, 224)
		local light = Color3.fromRGB(240, 239, 234) -- omóplatos: apenas más claros que el lomo
		local shade = Color3.fromRGB(214, 211, 204) -- muslos y anca: escalón de tono del músculo
		local ivory = Color3.fromRGB(232, 214, 178)
		local slit = Color3.fromRGB(190, 186, 178) -- rendijas de los dedos
		local pink = Color3.fromRGB(238, 150, 165)
		local innerEar = Color3.fromRGB(242, 178, 188)
		local mouthDark = Color3.fromRGB(140, 50, 70)
		local mouthLine = Color3.fromRGB(150, 112, 116)
		local lid = Color3.fromRGB(205, 178, 182) -- párpados: gris rosado (albino)
		local crease = Color3.fromRGB(214, 188, 170) -- pliegue del hocico: marfil algo más oscuro
		local nostril = Color3.fromRGB(175, 110, 125)
		local noseShine = Color3.fromRGB(252, 205, 215)
		local whisker = Color3.fromRGB(250, 250, 248)
		local fang = Color3.fromRGB(250, 248, 240)
		local jade = Color3.fromRGB(40, 150, 120)
		local jadeDark = Color3.fromRGB(22, 105, 85)
		local emerald = Color3.fromRGB(30, 220, 120)
		local pupil = Color3.fromRGB(10, 70, 45)
		local gold = Color3.fromRGB(240, 190, 60)
		-- Silla y collar azul marino: contrastan con el blanco y no compiten con el jade de las manchas.
		local navy = Color3.fromRGB(30, 50, 110)
		local navyDark = Color3.fromRGB(20, 32, 75)
		local gem = Color3.fromRGB(20, 175, 95)

		local function metal(part: BasePart)
			part.Material = Enum.Material.Metal
			part.Reflectance = 0.1
		end
		-- Placa fina pegada a una cara cuya normal es el eje "axis" ("x", "y" o "z"): "u" y "v" son su
		-- ancho y su alto sobre la cara (x: u = Z, v = Y; y: u = X, v = Z; z: u = X, v = Y).
		local function plate(
			bone: string,
			name: string,
			center: Vector3,
			axis: string,
			u: number,
			v: number,
			color: Color3
		)
			local size = if axis == "x"
				then Vector3.new(0.25, v, u)
				elseif axis == "y" then Vector3.new(u, -1.55, v)
				else Vector3.new(u, v, 0.25)
			return box(bone, name, center, size, color)
		end
		local function along(axis: string, du: number, dv: number): Vector3
			return if axis == "x"
				then Vector3.new(0, dv, du)
				elseif axis == "y" then Vector3.new(du, -1.8, dv)
				else Vector3.new(du, dv, 0)
		end
		-- Roseta hueca: un anillo de cuatro manchas en las diagonales, de tamaños algo distintos (semilla
		-- fija), con el pelaje blanco en medio. Con cuatro barras rectas se leían como letras ("O", "U").
		-- "gap" quita una de las cuatro, como en los anillos rotos de un jaguar de verdad.
		local spots = Random.new(23)
		local function rosette(bone: string, center: Vector3, axis: string, w: number, h: number, gap: number?)
			local i = 0
			for _, su in { -1, 1 } do
				for _, sv in { 1, -1 } do
					i += 1
					if i ~= gap then
						local u, v = spots:NextNumber(0.8, 1.2), spots:NextNumber(0.6, 0.9)
						local du = su * (w / 2 - u / 2) + spots:NextNumber(-0.15, 0.15)
						local dv = sv * (h / 2 - v / 2) + spots:NextNumber(-0.15, 0.15)
						plate(bone, "Rosette", center + along(axis, du, dv), axis, u, v, jade)
					end
				end
			end
		end

		-- Proporciones de un jaguar de verdad (1,1–1,85 m de cabeza y cuerpo, 45–75 cm de cola y 65–80 cm
		-- a la cruz): la cruz a la mitad del largo y la cola un 41 % del cuerpo. Con el lomo a un tercio del
		-- largo y la cola en un 27 % se veía chaparro.
		-- Tronco en tres tramos (pecho hondo, cintura recogida y grupa), cada uno con los cantos de arriba y
		-- de abajo achaflanados: de una sola caja parecía una mesa.
		local top = 16.4 -- lomo de la grupa
		local function segment(name: string, z0: number, z1: number, low: number, high: number, width: number)
			local z, length = (z0 + z1) / 2, z1 - z0
			box("Body", name, Vector3.new(0, (low + high) / 2, z), Vector3.new(width, high - low - 1.6, length), fur)
			box("Body", name, Vector3.new(0, high - 0.4, z), Vector3.new(width - 1.4, 0.8, length), fur)
			box("Body", name, Vector3.new(0, low + 0.4, z), Vector3.new(width - 1.4, 0.8, length), fur)
		end
		segment("Chest", -13.4, -5, 8.2, 16.4, 6.6)
		segment("Waist", -5, 3.4, 9.4, 16, 5.8)
		segment("Rump", 3.4, 10.6, 9.6, 16.4, 6.4)
		-- Grupa redondeada por detrás (un escalón más estrecho y más bajo) y lomo que baja hacia la cola.
		box("Body", "RumpEnd", Vector3.new(0, 13.3, 11.1), Vector3.new(5.2, 4.6, 1), fur)
		-- Músculos: hombro (un poco más claro, abulta por los lados) con los omóplatos que asoman sobre la
		-- cruz, y anca más oscura que abulta sobre la grupa.
		box("Body", "Shoulder", Vector3.new(0, 13.4, -9.6), Vector3.new(7, 4.4, 4.2), light)
		for side = -1, 1, 2 do
			box("Body", "ShoulderBlade", Vector3.new(side * 1.8, 16.8, -9.8), Vector3.new(1.6, 0.9, 3.4), light)
		end
		box("Body", "Haunch", Vector3.new(0, 13.4, 7.2), Vector3.new(6.9, 4.6, 5.4), shade)
		-- Marfil: quilla del pecho, vientre recogido y pecho.
		box("Body", "Keel", Vector3.new(0, 8.1, -9.2), Vector3.new(5, 0.5, 7.6), ivory)
		box("Body", "Belly", Vector3.new(0, 9.3, -0.8), Vector3.new(4.2, 0.5, 8.4), ivory)
		plate("Body", "ChestFur", Vector3.new(0, 11.4, -13.45), "z", 4.6, 5, ivory)

		-- Cuello corto que baja hacia delante (la cabeza va más baja que el lomo, como en la referencia), con
		-- el collar azul marino.
		box("Neck", "Neck", Vector3.new(0, 13.75, -14.6), Vector3.new(4.8, 4.3, 4.4), fur)
		-- Cresta del cuello en dos escalones que suben de la nuca a los omóplatos (de un solo bloque más alto
		-- que la cabeza, el cuello cambiaba de golpe al llegar a ella), y el músculo de cada lado, que baja
		-- hacia el pecho.
		box("Neck", "NeckCrest", Vector3.new(0, 16.2, -14.4), Vector3.new(3.8, 0.6, 2.8), light)
		box("Neck", "NeckCrest", Vector3.new(0, 16.7, -12.9), Vector3.new(3.6, 0.6, 1.6), light)
		for side = -1, 1, 2 do
			box("Neck", "NeckMuscle", Vector3.new(side * 2.6, 12.4, -14.8), Vector3.new(0.6, 2.4, 3.6), light)
		end
		-- Garganta marfil que llena el hueco entre la barbilla y el pecho (sin ella se veía una caja abierta).
		box("Neck", "Throat", Vector3.new(0, 11.6, -14.4), Vector3.new(4.2, 3.4, 2.4), ivory)
		box("Neck", "Collar", Vector3.new(0, 14, -14.6), Vector3.new(5.2, 1, 4.8), navy)
		-- La esmeralda, engastada en oro, va en el pecho bajo la garganta y cuelga del tronco: así no se
		-- despega del pecho cuando el cuello se mueve.
		metal(box("Body", "CollarSetting", Vector3.new(0, 9.2, -13.7), Vector3.new(1.3, 1.3, 0.5), gold))
		local pendant = plate("Body", "CollarGem", Vector3.new(0, 9.2, -14.05), "z", 0.8, 0.8, gem)
		pendant.Reflectance = 0.2

		-- Cabeza: cráneo con la frente abombada y la nuca, carrillos que se abren hacia atrás, cejas y ojos
		-- hundidos bajo ellas, y el hocico bien marcado delante de la cara (docs/img/JaguarVoxel.jfif):
		-- puente de la nariz, las dos almohadillas de los bigotes con sus puntos, la nariz rosa en
		-- triángulo encima y la barbilla debajo. La boca es la raya bajo las almohadillas (una nariz encima
		-- de una raya vertical parecía un buzón).
		-- Perfil como el de la referencia: de la nariz a la coronilla la cara sube en escalones (puente,
		-- cara con los ojos, frente más atrás y bóveda), en vez de una pared con un hocico pegado delante.
		box("Head", "Skull", Vector3.new(0, 13, -18.6), Vector3.new(5.6, 3.8, 5), fur)
		box("Head", "Forehead", Vector3.new(0, 15.3, -18.2), Vector3.new(5, 0.8, 4.2), fur)
		box("Head", "Dome", Vector3.new(0, 16.05, -18.1), Vector3.new(4.4, 0.7, 3), fur)
		-- La nuca entra en el cuello: acabando justo donde empezaba, quedaba una rendija entre los dos.
		box("Head", "Nape", Vector3.new(0, 13.8, -15.6), Vector3.new(4.6, 4.2, 1.6), fur)
		box("Head", "Bridge", Vector3.new(0, 13.3, -22.3), Vector3.new(2.4, 1.2, 2.4), fur)
		box("Head", "Bridge", Vector3.new(0, 14.2, -21.7), Vector3.new(2, 0.6, 1.6), fur)
		-- Pliegue que separa los cachetes: una raya suave que baja de la nariz a la boca.
		plate("Head", "Philtrum", Vector3.new(0, 11.6, -23.95), "z", 0.3, 1.2, crease)
		box("Head", "Nose", Vector3.new(0, 13, -23.5), Vector3.new(2, 0.7, 1), pink)
		box("Head", "Nose", Vector3.new(0, 12.45, -23.85), Vector3.new(1, 0.5, 0.6), pink)
		plate("Head", "NoseShine", Vector3.new(-0.4, 13.4, -23.3), "y", 0.5, 0.4, noseShine)
		-- Ceño: un pliegue corto entre las cejas.
		plate("Head", "Frown", Vector3.new(0, 14.7, -21.15), "z", 0.3, 0.4, crease)
		plate("Head", "Mouth", Vector3.new(0, 11, -23.95), "z", 3.6, 0.25, mouthLine)
		for side = -1, 1, 2 do
			box("Head", "WhiskerPad", Vector3.new(side * 0.95, 11.85, -22.5), Vector3.new(1.9, 1.7, 2.8), ivory)
			for _, dot in { { 0.6, 12.05 }, { 1.25, 12.25 }, { 1.05, 11.55 } } do
				plate("Head", "Whisker", Vector3.new(side * dot[1], dot[2], -23.95), "z", 0.3, 0.3, mouthLine)
			end
			box("Head", "Cheek", Vector3.new(side * 3.2, 12.4, -18.2), Vector3.new(1, 3, 3.2), fur)
			-- Carrillo delantero: abraza el hocico por los lados y lo hace más ancho en la base.
			box("Head", "Cheek", Vector3.new(side * 2.4, 12, -21.5), Vector3.new(1.2, 1.8, 1.6), fur)
			box("Head", "Jowl", Vector3.new(side * 3, 10.7, -17.8), Vector3.new(0.8, 1.6, 2.2), fur)
			-- Ojos esmeralda de neón, hondos (con poco fondo salían de otro color), pupila en ranura y la
			-- ceja encima.
			local eye = box("Head", "Eye", Vector3.new(side * 1.8, 13.75, -21.1), Vector3.new(1, 0.6, 0.7), emerald)
			eye.Material = Enum.Material.Neon
			plate("Head", "Pupil", Vector3.new(side * 1.8, 13.75, -21.55), "z", 0.3, 0.55, pupil)
			plate("Head", "Glint", Vector3.new(side * 1.8 - 0.3, 13.9, -21.68), "z", 0.25, 0.25, whisker)
			-- Ceja en dos tramos, el de dentro más bajo (mirada seria), y un párpado gris rosado alrededor
			-- del ojo que lo enmarca sobre el pelaje blanco.
			box("Head", "Brow", Vector3.new(side * 2.15, 14.65, -21.25), Vector3.new(1.2, 0.5, 0.6), fur)
			box("Head", "Brow", Vector3.new(side * 1.2, 14.4, -21.25), Vector3.new(0.8, 0.5, 0.6), fur)
			plate("Head", "Lid", Vector3.new(side * 1.8, 13.75, -21.15), "z", 1.4, 0.9, lid)
			-- Lagrimal: raya suave que baja de la esquina de dentro del ojo por el carrillo, junto al hocico.
			plate("Head", "TearLine", Vector3.new(side * 1.95, 12.45, -22.35), "z", 0.3, 0.9, crease)
			-- Orificios de la nariz, pequeños y en las esquinas de abajo (grandes y en medio, era un
			-- hocico de cerdo).
			plate("Head", "Nostril", Vector3.new(side * 0.75, 12.75, -24.05), "z", 0.35, 0.25, nostril)
			-- Bigotes: dos a cada lado, blancos, que salen de las almohadillas.
			box("Head", "Whisker", Vector3.new(side * 3, 11.95, -23), Vector3.new(2.2, 0.25, 0.25), whisker)
			box("Head", "Whisker", Vector3.new(side * 2.9, 11.5, -22.6), Vector3.new(2, 0.25, 0.25), whisker)
			-- Gorguera: mechones en escalón bajo los carrillos, que dibujan la mandíbula.
			box("Head", "Ruff", Vector3.new(side * 3.3, 10.6, -17), Vector3.new(0.8, 0.8, 1), fur)
			box("Head", "Ruff", Vector3.new(side * 2.8, 9.9, -18.2), Vector3.new(0.8, 0.8, 1.2), fur)
			-- Manchas de jade sueltas en la frente, la coronilla y los carrillos.
			plate("Head", "Spot", Vector3.new(side * 0.9, 15.2, -20.35), "z", 0.6, 0.6, jade)
			plate("Head", "Spot", Vector3.new(side * 1, 16.45, -18.2), "y", 0.7, 0.7, jade)
			plate("Head", "Spot", Vector3.new(side * 3.75, 12.8, -18.8), "x", 0.7, 0.7, jade)
			plate("Head", "Spot", Vector3.new(side * 3.75, 11.8, -17.6), "x", 0.6, 0.6, jade)
		end
		plate("Head", "Spot", Vector3.new(0, 15.3, -20.35), "z", 0.6, 0.6, jade)
		plate("Head", "Spot", Vector3.new(-0.45, 15.5, -20.35), "z", 0.4, 0.4, jade)
		plate("Head", "Spot", Vector3.new(0.5, 15.5, -20.35), "z", 0.4, 0.4, jade)
		-- Dentro de la boca: lo tapan las almohadillas y la barbilla; se ve al rugir (paladar, colmillos y
		-- lengua).
		box("Head", "MouthInside", Vector3.new(0, 11.15, -22), Vector3.new(2.2, 0.5, 2.6), mouthDark)
		for side = -1, 1, 2 do
			box("Head", "Fang", Vector3.new(side * 1, 10.7, -23.4), Vector3.new(0.45, 1, 0.45), fang)
			box("Jaw", "Fang", Vector3.new(side * 0.6, 11.25, -23.5), Vector3.new(0.4, 0.7, 0.4), fang)
		end
		box("Jaw", "Jaw", Vector3.new(0, 10.5, -20.4), Vector3.new(3.2, 1, 3.2), ivory)
		box("Jaw", "Chin", Vector3.new(0, 10.6, -22.6), Vector3.new(2.4, 0.8, 2.2), ivory)
		box("Jaw", "ChinTuft", Vector3.new(0, 10, -22.6), Vector3.new(1.2, 0.5, 0.8), ivory)
		box("Jaw", "Tongue", Vector3.new(0, 11.05, -21.8), Vector3.new(1.6, 0.3, 2), pink)

		-- Orejas redondeadas a los lados de la coronilla, rosas por dentro y con una mancha de jade por
		-- detrás (se ven a la espalda).
		for side = -1, 1, 2 do
			local ear = if side < 0 then "EarL" else "EarR"
			box(ear, "Ear", Vector3.new(side * 2.3, 16.5, -17), Vector3.new(2, 1.8, 0.9), fur)
			box(ear, "Ear", Vector3.new(side * 2.3, 17.65, -17), Vector3.new(1.3, 0.5, 0.9), fur)
			plate(ear, "EarInner", Vector3.new(side * 2.3, 16.5, -17.5), "z", 1.2, 1.1, innerEar)
			plate(ear, "EarTuft", Vector3.new(side * 2, 16.3, -17.65), "z", 0.5, 0.6, whisker)
			plate(ear, "EarSpot", Vector3.new(side * 2.3, 16.6, -16.5), "z", 1, 0.9, jade)
		end

		-- Patas largas y musculosas. Delante: brazo grueso con la punta del codo detrás, antebrazo con su
		-- músculo arriba y el pie ancho. Detrás: muslo grande y oscuro, pantorrilla, corvejón retrasado con
		-- el talón y el pie. Pies con dos rendijas (dedos) y almohadillas rosas debajo y detrás (lo que se
		-- ve al galopar desde la espalda).
		for _, leg in { { "F", -9.6, 2.5 }, { "B", 8.4, 2.4 } } do
			local key, z = leg[1] :: string, leg[2] :: number
			local isFront = key == "F"
			for side = -1, 1, 2 do
				local bone = `Leg{key}{if side < 0 then "L" else "R"}`
				local shin = `Shin{key}{if side < 0 then "L" else "R"}`
				local x = side * (leg[3] :: number)
				local pawZ, lowZ
				if isFront then
					box(bone, "UpperArm", Vector3.new(x, 10.7, z), Vector3.new(3.2, 7, 3.6), fur)
					box(bone, "Elbow", Vector3.new(x, 8.2, z + 1.6), Vector3.new(2.6, 1.4, 1.2), fur)
					-- Deltoides delante (más claro) y tríceps detrás (más oscuro): el brazo deja de ser un pilar.
					box(bone, "Deltoid", Vector3.new(x, 12.6, z - 2.1), Vector3.new(2.6, 2.4, 0.8), light)
					box(bone, "Triceps", Vector3.new(x, 11.4, z + 2.1), Vector3.new(2.6, 3, 0.8), shade)
					rosette(bone, Vector3.new(side * 4.15, 11.6, z), "x", 2.4, 2.6, if side < 0 then 2 else 1)
					lowZ, pawZ = z + 0.1, z - 0.7
					box(shin, "Forearm", Vector3.new(x, 4.4, lowZ), Vector3.new(2.5, 6.4, 2.7), fur)
					box(shin, "ForearmMuscle", Vector3.new(x, 6.4, lowZ), Vector3.new(2.9, 2.2, 3), fur)
					plate(shin, "Spot", Vector3.new(side * 3.8, 4, z + 0.2), "x", 0.7, 0.7, jade)
					plate(shin, "Spot", Vector3.new(side * 3.8, 2.8, z - 0.4), "x", 0.6, 0.6, jade)
				else
					box(bone, "Thigh", Vector3.new(x, 11.7, z), Vector3.new(3.6, 6.6, 5), shade)
					box(bone, "Gaskin", Vector3.new(x, 8.2, z + 1.2), Vector3.new(2.8, 3.2, 3.4), shade)
					-- Cuádriceps delante (más claro) y la corva detrás, que abultan sobre el muslo.
					box(bone, "Quadriceps", Vector3.new(x, 11.2, z - 2.8), Vector3.new(2.8, 3, 0.8), fur)
					box(bone, "Hamstring", Vector3.new(x, 11, z + 2.8), Vector3.new(2.8, 4, 0.8), shade)
					rosette(bone, Vector3.new(side * 4.25, 11.6, z - 0.2), "x", 3, 2.8, if side < 0 then 3 else 4)
					lowZ, pawZ = z + 2.4, z + 1.6
					box(shin, "Hock", Vector3.new(x, 4, lowZ), Vector3.new(2.3, 5.8, 2.4), fur)
					box(shin, "Heel", Vector3.new(x, 6.6, z + 3.4), Vector3.new(2.4, 1.2, 1), fur)
				end
				box(shin, "Paw", Vector3.new(x, 0.7, pawZ), Vector3.new(3.3, 1.4, 3.9), fur)
				for toe = -1, 1, 2 do
					box(shin, "Toe", Vector3.new(x + toe * 0.55, 0.75, pawZ - 1.75), Vector3.new(0.25, 1, 0.6), slit)
				end
				plate(shin, "Pad", Vector3.new(x, 0.05, pawZ), "y", 2.2, 2.4, pink)
				plate(shin, "Pad", Vector3.new(x, 0.7, pawZ + 2), "z", 1.8, 0.8, pink)
			end
		end

		-- Rosetas del cuerpo (y una mancha en cada lado del cuello): dos en el pecho detrás del brazo, una baja en la
		-- cintura (bajo la silla), dos encima de la grupa y dos en la grupa por detrás.
		for side = -1, 1, 2 do
			local gap = if side < 0 then 1 else 2
			rosette("Body", Vector3.new(side * 3.35, 12.6, -6.2), "x", 2.4, 2.4, nil)
			rosette("Body", Vector3.new(side * 3.35, 9.7, -6.2), "x", 2.2, 1.8, gap)
			rosette("Body", Vector3.new(side * 2.95, 10.4, -2.2), "x", 2.6, 1.8, nil)
			rosette("Body", Vector3.new(side * 1.3, top + 0.05, 7.4), "y", 2.2, 3, if side < 0 then 3 else nil)
			rosette("Body", Vector3.new(side * 1.35, 12.8, 11.65), "z", 2.2, 2.2, nil)
			plate("Neck", "Spot", Vector3.new(side * 2.45, 15.1, -14.2), "x", 0.8, 0.7, jade)
		end

		-- Cola larga (un 41 % del cuerpo, como la de verdad) que sale hacia atrás, baja y se curva hacia
		-- arriba en la punta, cada vez más fina, con anillos de jade y la punta de jade oscuro (se ve por
		-- detrás, entre las ancas).
		box("Tail", "Tail", Vector3.new(0, 14.8, 12.8), Vector3.new(1.8, 1.8, 2.6), fur)
		box("Tail", "Tail", Vector3.new(0, 14, 15), Vector3.new(1.7, 1.7, 2.4), fur)
		box("Tail", "TailRing", Vector3.new(0, 14, 15.4), Vector3.new(1.9, 1.9, 0.6), jade)
		box("Tail2", "Tail", Vector3.new(0, 12.9, 17.2), Vector3.new(1.6, 1.6, 2.4), fur)
		box("Tail2", "Tail", Vector3.new(0, 12.2, 19.2), Vector3.new(1.5, 1.5, 2.4), fur)
		box("Tail2", "TailRing", Vector3.new(0, 12.9, 17.6), Vector3.new(1.8, 1.8, 0.5), jade)
		box("Tail2", "TailRing", Vector3.new(0, 12.2, 19.6), Vector3.new(1.7, 1.7, 0.5), jade)
		box("Tail3", "Tail", Vector3.new(0, 12, 21), Vector3.new(1.4, 1.4, 1.8), fur)
		box("Tail3", "Tail", Vector3.new(0, 13.2, 21.8), Vector3.new(1.3, 2.6, 1.3), fur)
		box("Tail3", "TailRing", Vector3.new(0, 13.6, 21.8), Vector3.new(1.5, 0.5, 1.5), jade)
		box("Tail3", "TailTip", Vector3.new(0, 15.1, 21.8), Vector3.new(1.2, 1.4, 1.2), jadeDark)

		-- Silla azul marino con oro: asiento entre dos arzones, faldones a los lados con el marco y una
		-- esmeralda engastada (a juego con los ojos), y la cincha bajo el vientre. De jade, como las
		-- manchas, se comía al jaguar; con un panel oscuro más, los cuadrados uno dentro de otro parecían
		-- una diana.
		box("Body", "Saddle", Vector3.new(0, 16.3, -0.5), Vector3.new(5, 0.6, 8), navy)
		for _, sz in { -4.6, 3.6 } do
			metal(box("Body", "SaddleCantle", Vector3.new(0, 16.9, sz), Vector3.new(5.2, 1.4, 0.7), gold))
		end
		for side = -1, 1, 2 do
			metal(box("Body", "SaddleRail", Vector3.new(side * 2.6, 16.7, -0.5), Vector3.new(0.4, 0.4, 8), gold))
			box("Body", "SaddleFlap", Vector3.new(side * 3.05, 13.8, -0.5), Vector3.new(0.3, 4.4, 6), navy)
			metal(box("Body", "SaddleTrim", Vector3.new(side * 3.1, 11.6, -0.5), Vector3.new(0.4, 0.5, 6.4), gold))
			for _, ez in { -3.5, 2.5 } do
				metal(box("Body", "SaddleTrim", Vector3.new(side * 3.1, 13.8, ez), Vector3.new(0.4, 4.4, 0.4), gold))
			end
			metal(plate("Body", "SaddleSetting", Vector3.new(side * 3.25, 13.9, -0.5), "x", 1.6, 1.6, gold))
			local stone = plate("Body", "SaddleGem", Vector3.new(side * 3.4, 13.9, -0.5), "x", 1.1, 1.1, gem)
			stone.Reflectance = 0.2
			box("Body", "Girth", Vector3.new(side * 3, 10.5, 1.2), Vector3.new(0.3, 2.2, 1), navyDark)
		end
		box("Body", "Girth", Vector3.new(0, 9.2, 1.2), Vector3.new(5.2, 0.5, 1), navyDark)

		-- Articulaciones: lomo en su centro, cuello en la cruz, cabeza sobre el cuello, mandíbula detrás del
		-- hocico (se abre al rugir), orejas en su base, cola en tres tramos (ondula en S) y cada pata en el
		-- hombro o la cadera con el tramo de abajo en el codo o la rodilla.
		local joints = {
			{ bone = "Body", parent = "Root", pivot = Vector3.new(0, 13, 0) },
			{ bone = "Neck", parent = "Body", pivot = Vector3.new(0, 15, -12.8) },
			{ bone = "Head", parent = "Neck", pivot = Vector3.new(0, 14, -16.1) },
			{ bone = "Jaw", parent = "Head", pivot = Vector3.new(0, 11.1, -19.4) },
			{ bone = "EarL", parent = "Head", pivot = Vector3.new(-2.3, 15.8, -17) },
			{ bone = "EarR", parent = "Head", pivot = Vector3.new(2.3, 15.8, -17) },
			{ bone = "Tail", parent = "Body", pivot = Vector3.new(0, 15.2, 11.6) },
			{ bone = "Tail2", parent = "Tail", pivot = Vector3.new(0, 13.6, 16.2) },
			{ bone = "Tail3", parent = "Tail2", pivot = Vector3.new(0, 12.2, 20.4) },
		}
		for _, leg in { { "F", -9.6, 2.5, 13.5, 7.6, 0 }, { "B", 8.4, 2.4, 13.8, 7.4, 1.6 } } do
			for side = -1, 1, 2 do
				local name = `{leg[1]}{if side < 0 then "L" else "R"}`
				local x, lz = side * (leg[3] :: number), leg[2] :: number
				table.insert(
					joints,
					{ bone = `Leg{name}`, parent = "Body", pivot = Vector3.new(x, leg[4] :: number, lz) }
				)
				table.insert(joints, {
					bone = `Shin{name}`,
					parent = `Leg{name}`,
					pivot = Vector3.new(x, leg[5] :: number, lz + (leg[6] :: number)),
				})
			end
		end
		return {
			seat = Vector3.new(0, 16.9, -0.5),
			joints = joints,
			roar = Vector3.new(0, 11, -24.2),
			aura = {
				center = Vector3.new(0, 12.6, -0.5),
				radius = 8,
				length = 40,
				bands = { -13, -1, 11 },
				-- Celeste, rosa, melocotón y aguamarina (nada de menta ni lila: el verde es la curación y el
				-- morado, el veneno). Más saturados que un pastel: el neón y la luz los aclaran hasta pastel
				-- (con 165, 215, 255 y parecidos salían blancos).
				colors = {
					Color3.fromRGB(95, 175, 255),
					Color3.fromRGB(255, 125, 185),
					Color3.fromRGB(255, 165, 95),
					Color3.fromRGB(60, 215, 205),
				},
				cubes = 12,
			},
		}
	end,
}

-- Construye la montura "mountId": Root anclada y el resto colgando de ella por las articulaciones,
-- sin colisión (quien la use decide cómo moverla: desanclar Root y soldarla, o moverla con PivotTo).
function MountModels.build(mountId: string): Model?
	local mount = Mounts[mountId]
	local builder = builders[mountId]
	if not (mount and builder) then
		return nil
	end
	local scale = CELL * mount.size
	local model = Instance.new("Model")
	model.Name = `Montura_{mountId}`
	local function at(cell: Vector3): Vector3
		return cell * scale
	end
	local function place(name: string, size: Vector3, position: Vector3, color: Color3): BasePart
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = CFrame.new(position)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.Parent = model
		return part
	end
	local root = place("Root", Vector3.one * 0.2, Vector3.zero, Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CastShadow = false
	model.PrimaryPart = root
	local boxes: { BasePart } = {}
	local kit: Kit = {
		at = at,
		box = function(bone, name, center, size, color)
			local part = place(name, size * scale, at(center), color)
			part:SetAttribute("Bone", bone)
			table.insert(boxes, part)
			return part
		end,
	}
	local built = builder(kit)
	local aura = built.aura
	if aura then
		-- Cubitos de neón repartidos por el cilindro del aura (semilla fija: todas iguales).
		local rng = Random.new(11)
		for i = 1, aura.cubes do
			local angle = rng:NextNumber(0, math.pi * 2)
			local radius = aura.radius + rng:NextNumber(-0.8, 1.2)
			local offset = Vector3.new(
				radius * math.cos(angle),
				radius * math.sin(angle),
				rng:NextNumber(-aura.length / 2, aura.length / 2)
			)
			local cube = kit.box(
				"Aura",
				"AuraCube",
				aura.center + offset,
				Vector3.one * rng:NextNumber(0.6, 1),
				aura.colors[(i - 1) % #aura.colors + 1]
			)
			cube.Material = Enum.Material.Neon
			cube.Transparency = 0.2
			cube.CastShadow = false
		end
		table.insert(built.joints, { bone = "Aura", parent = "Body", pivot = aura.center })
	end
	-- Huesos: pieza invisible en la articulación, con un Motor6D desde la de su padre.
	local bones: { [string]: BasePart } = { Root = root }
	for _, item in built.joints do
		local bone = place(item.bone, Vector3.one * 0.2, at(item.pivot), Color3.new(1, 1, 1))
		bone.Transparency = 1
		bone.CastShadow = false
		bone.Anchored = false
		local parent = bones[item.parent]
		local motor = Instance.new("Motor6D")
		motor.Name = `{item.bone}Joint`
		motor.Part0 = parent
		motor.Part1 = bone
		motor.C0 = parent.CFrame:ToObjectSpace(bone.CFrame)
		motor.Parent = parent
		bones[item.bone] = bone
	end
	for _, part in boxes do
		local bone = bones[part:GetAttribute("Bone") :: string]
		part.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = bone
		weld.Part1 = part
		weld.Parent = part
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Seat"
	attachment.CFrame = bones.Body.CFrame:ToObjectSpace(CFrame.new(at(built.seat)))
	attachment.Parent = bones.Body
	if built.mouth then
		-- Escupitajo: un chorro de gotas que sale hacia delante de la cabeza y cae con la gravedad.
		-- Blanco azulado, como la saliva (ni verde, que es la curación, ni morado, que es el veneno).
		-- Velocidades muy distintas para que las gotas se estiren en un chorro: con todas parecidas
		-- salía una bola de nube delante de la boca.
		local mouth = Instance.new("Attachment")
		mouth.Name = "SpitPoint"
		mouth.CFrame = bones.Head.CFrame:ToObjectSpace(CFrame.new(at(built.mouth)))
		mouth.Parent = bones.Head
		local spit = Instance.new("ParticleEmitter")
		spit.Name = "Spit"
		spit.Enabled = false
		spit.Rate = 0
		spit.EmissionDirection = Enum.NormalId.Front
		spit.SpreadAngle = Vector2.new(6, 6)
		spit.Speed = NumberRange.new(5 * mount.size, 28 * mount.size)
		spit.Acceleration = Vector3.new(0, -30, 0)
		spit.Drag = 1.5
		spit.Lifetime = NumberRange.new(0.35, 0.6)
		spit.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2 * mount.size),
			NumberSequenceKeypoint.new(1, 0.08 * mount.size),
		})
		spit.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		spit.Color = ColorSequence.new(Color3.fromRGB(235, 245, 250), Color3.fromRGB(190, 215, 230))
		spit.LightEmission = 0.2
		spit.LightInfluence = 0.6
		spit.Parent = mouth
	end
	if built.roar then
		-- Rugido: chispas que salen de la boca en todas direcciones (el anillo de cubitos lo lanza
		-- MountModels.gesture) y luz esmeralda de los ojos, que se aviva al rugir.
		local mouth = Instance.new("Attachment")
		mouth.Name = "RoarPoint"
		mouth.CFrame = bones.Head.CFrame:ToObjectSpace(CFrame.new(at(built.roar)))
		mouth.Parent = bones.Head
		local burst = Instance.new("ParticleEmitter")
		burst.Name = "Roar"
		burst.Enabled = false
		burst.Rate = 0
		burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		burst.EmissionDirection = Enum.NormalId.Front
		burst.SpreadAngle = Vector2.new(70, 70)
		burst.Speed = NumberRange.new(6 * mount.size, 14 * mount.size)
		burst.Drag = 3
		burst.Lifetime = NumberRange.new(0.4, 0.8)
		burst.Size = NumberSequence.new(0.5 * mount.size, 0)
		burst.LightEmission = 0.4
		burst.LightInfluence = 0
		burst.Brightness = 2
		burst.Parent = mouth
		local eye = model:FindFirstChild("Eye")
		if eye then
			local glow = Instance.new("PointLight")
			glow.Name = "EyeGlow"
			glow.Color = (eye :: BasePart).Color
			glow.Range = 4 * mount.size
			glow.Brightness = 0.6
			glow.Parent = eye
		end
	end
	if aura then
		-- Bandas de luz: en cada Z, un arco de 150° en dos tramos de Beam curvados como un círculo,
		-- que se apaga hacia la cola (parece que corre alrededor del cuerpo al girar). Miran a la cámara:
		-- se ven igual desde cualquier lado. Finas: con 0,75 studs de ancho parecían velas.
		local bone = bones.Aura
		local radius = aura.radius * scale
		local step = math.rad(75)
		-- Largo de los puntos de control de una curva de Bézier que sigue un arco de "step" radianes.
		local control = 4 / 3 * math.tan(step / 4) * radius
		local beams: { Beam } = {}
		for index, bandZ in aura.bands do
			local color = aura.colors[(index - 1) % #aura.colors + 1]
			local start = index * 2.4
			local points: { Attachment } = {}
			for i = 0, 2 do
				local angle = start + i * step
				local point = Instance.new("Attachment")
				point.Name = "AuraPoint"
				point.CFrame = CFrame.fromMatrix(
					Vector3.new(radius * math.cos(angle), radius * math.sin(angle), (bandZ - aura.center.Z) * scale),
					Vector3.new(-math.sin(angle), math.cos(angle), 0),
					Vector3.zAxis
				)
				point.Parent = bone
				points[i] = point
			end
			for i = 0, 1 do
				local beam = Instance.new("Beam")
				beam.Name = "AuraBand"
				beam.Attachment0 = points[i]
				beam.Attachment1 = points[i + 1]
				beam.CurveSize0 = control
				beam.CurveSize1 = -control
				beam.Segments = 12
				beam.FaceCamera = true
				beam.Width0 = (0.06 + i * 0.12) * mount.size
				beam.Width1 = (0.18 + i * 0.12) * mount.size
				beam.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.3 * i))
				beam.Transparency = if i == 0 then NumberSequence.new(0.95, 0.55) else NumberSequence.new(0.55, 0.2)
				beam.LightEmission = 0.3
				beam.LightInfluence = 0
				beam.Brightness = 1
				beam.Parent = bone
				table.insert(beams, beam)
			end
		end
		-- Chispas sueltas por la superficie del cilindro, que giran con él.
		bone.Size = Vector3.new(radius * 2, radius * 2, aura.length * scale)
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "AuraSparkles"
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Shape = Enum.ParticleEmitterShape.Box
		sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		sparkles.Rate = 8
		sparkles.Speed = NumberRange.new(0.2, 0.6)
		sparkles.Lifetime = NumberRange.new(0.8, 1.6)
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.3 * mount.size),
			NumberSequenceKeypoint.new(1, 0),
		})
		local keys = {}
		for i, color in aura.colors do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#aura.colors - 1), color))
		end
		sparkles.Color = ColorSequence.new(keys)
		sparkles.LightEmission = 0.4
		sparkles.LightInfluence = 0
		sparkles.Brightness = 2
		sparkles.Parent = bone
		local motor = bones.Body:FindFirstChild("AuraJoint") :: Motor6D
		auras[model] = {
			motor = motor,
			rest = motor.C0,
			angle = 0,
			boost = 0,
			beams = beams,
			colors = aura.colors,
		}
	end
	local controller = Instance.new("AnimationController")
	Instance.new("Animator").Parent = controller
	controller.Parent = model
	return model
end

-- Escupitajo de la llama.
local function spit(model: Model)
	local emitter = model:FindFirstChild("Spit", true)
	if emitter and emitter:IsA("ParticleEmitter") then
		emitter:Emit(28)
	end
end

-- Rugido del jaguar: chispas desde la boca, un anillo de cubitos de los colores del aura que se abre
-- alrededor de la cabeza, los ojos que se encienden y el aura que gira deprisa un momento.
local function roar(model: Model)
	local point = model:FindFirstChild("RoarPoint", true)
	if not (point and point:IsA("Attachment")) then
		return
	end
	local burst = point:FindFirstChild("Roar")
	if burst and burst:IsA("ParticleEmitter") then
		burst:Emit(30)
	end
	local state = auras[model]
	local colors = if state then state.colors else { Color3.new(1, 1, 1) }
	if state then
		state.boost = 1
	end
	local origin = point.WorldCFrame
	local count = 16
	local reach = 6 * (model:GetExtentsSize().Y / 4)
	for i = 1, count do
		local angle = (i - 1) / count * math.pi * 2
		local direction = origin.RightVector * math.cos(angle) + origin.UpVector * math.sin(angle)
		local cube = Instance.new("Part")
		cube.Name = "RoarCube"
		cube.Size = Vector3.one * 0.35
		cube.CFrame = CFrame.new(origin.Position + direction * 0.4 + origin.LookVector * 0.3)
		cube.Color = colors[(i - 1) % #colors + 1]
		cube.Material = Enum.Material.Neon
		cube.Anchored = true
		cube.CanCollide = false
		cube.CanQuery = false
		cube.CanTouch = false
		cube.CastShadow = false
		cube.Parent = model
		local tween = TweenService:Create(cube, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(origin.Position + direction * reach + origin.LookVector * 1.5),
			Size = Vector3.one * 0.12,
			Transparency = 1,
		})
		tween.Completed:Once(function()
			cube:Destroy()
		end)
		tween:Play()
	end
	local glow = model:FindFirstChild("EyeGlow", true)
	if glow and glow:IsA("PointLight") then
		glow.Brightness = 5
		TweenService:Create(glow, TweenInfo.new(0.9), { Brightness = 0.6 }):Play()
	end
end

-- Efecto del gesto de la montura (Data/Mounts "gesture.effect"), en el marcador de su animación.
function MountModels.gesture(model: Model, effect: string)
	if effect == "Spit" then
		spit(model)
	elseif effect == "Roar" then
		roar(model)
	end
end

-- Gira el aura de la montura (si la tiene) "deltaTime" segundos: despacio parada, deprisa al galopar
-- ("run", de 0 a 1) y más aún justo después de rugir, con las bandas más brillantes.
function MountModels.animateAura(model: Model, deltaTime: number, run: number)
	local state = auras[model]
	if not state then
		return
	end
	state.angle = (
		state.angle
		+ deltaTime * (AURA_SPIN_IDLE + (AURA_SPIN_RUN - AURA_SPIN_IDLE) * run + AURA_SPIN_ROAR * state.boost)
	) % (math.pi * 2)
	state.boost = math.max(0, state.boost - deltaTime)
	state.motor.C0 = state.rest * CFrame.Angles(0, 0, state.angle)
	local brightness = 1 + run * 0.6 + state.boost * 1.5
	if math.abs(state.beams[1].Brightness - brightness) > 0.05 then
		for _, beam in state.beams do
			beam.Brightness = brightness
		end
	end
end

return MountModels
