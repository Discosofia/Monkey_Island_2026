--!strict
-- Gorila en estilo voxel (bloques grandes, como un juguete de bloques). Lo construye
-- MonkeyModels.voxelMonkey; el formato está explicado allí.
-- Cada caja: { x, y, z, ancho, alto, fondo, tono, nombre?, simétrica? } en celdas de "unit" studs.
-- x e z son el centro (frente a -Z), y es el centro medido desde el suelo. Los tonos salen de los
-- colores de Data, así que el mismo spec vale para el Gorila Albino y el de Ceniza.
-- Las partes con "mirror" se describen del lado derecho (+X) y el izquierdo sale reflejado.
-- "bosses": los adornos en bloques de cada jefe (ver MonkeyModels.voxelBossExtras).

-- Cristal en escalera: tres bloques que se estrechan hacia la punta, de tamaño "s" celdas. Crece
-- hacia arriba desde (x, y, z) o, con "forward", hacia delante (-Z).
local function crystal(x: number, y: number, z: number, s: number, forward: boolean?): { { number } }
	local steps = { { 2, 2 }, { 1.3, 2 }, { 0.7, 1.5 } } -- ancho y largo de cada bloque, en "s"
	local boxes = {}
	local along = 0
	for _, step in steps do
		local width, length = step[1] * s, step[2] * s
		local middle = along + length / 2
		if forward then
			table.insert(boxes, { x, y, z - middle, width, width, length })
		else
			table.insert(boxes, { x, y + middle, z, width, length, width })
		end
		along += length
	end
	return boxes
end

local function join(...: { any }): { any }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

-- Torre de escalones para picos, cuernos y el volcán: "steps" bloques de alto "h" que se estrechan hacia arriba.
-- (x, z) es el centro, "y" la base del primero y "tone" su tono (nil = el del grupo).
local function tower(
	x: number,
	y: number,
	z: number,
	width: number,
	depth: number,
	steps: number,
	h: number,
	shrink: number,
	tone: any
): { { any } }
	local boxes = {}
	for i = 0, steps - 1 do
		table.insert(boxes, { x, y + h * (i + 0.5), z, width - shrink * i, h, depth - shrink * i, tone })
	end
	return boxes
end

-- Vena de lava: un camino de tramos rectos sobre una superficie. "plane" es el eje de la normal ("x", "y" o
-- "z"), "fixed" el valor de ese eje (el centro de la vena) y (a, b) el inicio en los otros dos ejes, en orden
-- (con "z": x, y; con "x": y, z; con "y": x, z). Cada "moves" es { da, db } con uno de los dos a 0. "w" es el
-- ancho, "out" el grosor y "mirror" la pone también en el lado -X.
local function vein(
	plane: string,
	fixed: number,
	a: number,
	b: number,
	moves: { { number } },
	w: number,
	out: number,
	mirror: boolean?
): { { any } }
	local boxes = {}
	for _, move in moves do
		local da, db = move[1], move[2]
		local ca, cb = a + da / 2, b + db / 2
		local sa, sb = math.abs(da) + w, math.abs(db) + w
		if plane == "z" then
			table.insert(boxes, { ca, cb, fixed, sa, sb, out, nil, nil, mirror })
		elseif plane == "x" then
			table.insert(boxes, { fixed, ca, cb, out, sa, sb, nil, nil, mirror })
		else
			table.insert(boxes, { ca, fixed, cb, sa, out, sb, nil, nil, mirror })
		end
		a, b = a + da, b + db
	end
	return boxes
end

-- Marco de lava (cuatro tiras de ancho "edge" y alto "h") sobre el borde de una losa de "w" por "d" centrada en
-- (x, y, z): enciende el contorno sin tapar la cara de arriba.
local function frame(x: number, y: number, z: number, w: number, d: number, edge: number, h: number): { { any } }
	return {
		{ x, y, z - d / 2 + edge / 2, w, h, edge },
		{ x, y, z + d / 2 - edge / 2, w, h, edge },
		{ x - w / 2 + edge / 2, y, z, edge, h, d - 2 * edge },
		{ x + w / 2 - edge / 2, y, z, edge, h, d - 2 * edge },
	}
end

local LAVA = Color3.fromRGB(255, 110, 30)

-- Losa de roca en escalón: una placa y otra más pequeña encima.
-- Con "mirror" la losa sale también en el lado -X.
local function rock(x: number, y: number, z: number, width: number, depth: number, mirror: boolean?): { { any } }
	return {
		{ x, y, z, width, 0.8, depth, nil, nil, mirror },
		{ x + width * 0.1, y + 0.6, z - depth * 0.1, width * 0.6, 0.6, depth * 0.6, nil, nil, mirror },
	}
end

local BASALT = Color3.fromRGB(40, 36, 36)

-- Los jefes quitan la cara normal: la suya cambia con la fase del combate (phaseFaces).
local BOSS_FACE = { "Brow", "Eye", "Mouth" }
local NOSTRIL = Color3.fromRGB(22, 6, 5)

-- Músculos de los jefes: van dentro de la unión de cada parte, así que no añaden piezas (salvo los
-- pectorales, que el Gorila de Ceniza recolorea por nombre).
local BOSS_MUSCLES = {
	Torso = {
		{ 0, 17.5, -4.5, 9, 1, 5, "fur", "Trapezius" },
		{ 0, 16.5, 1.5, 8, 1, 4, "silver", "Lats" },
		{ 2.3, 11.2, -9.7, 4, 3, 0.8, "chest", "Pec", true },
	},
	Arm = {
		{ 10.1, 11.5, -6, 0.7, 3.5, 3, "fur", "Biceps" },
		{ 7.5, 11.5, -8.6, 3, 3.5, 0.7, "fur", "Biceps" },
		{ 10.3, 5, -6.3, 0.6, 2.6, 3.4, "shag", "Forearm" },
		{ 6, 2.2, -9, 1.2, 0.5, 1.1, "paws", "Knuckle" },
		{ 7.5, 2.2, -9, 1.2, 0.5, 1.1, "paws", "Knuckle" },
		{ 9, 2.2, -9, 1.2, 0.5, 1.1, "paws", "Knuckle" },
	},
	Leg = {
		{ 7.55, 6.5, 6.5, 0.6, 3, 3.4, "fur", "Thigh" },
		{ 5, 4, 9.3, 3, 2, 0.6, "fur", "Calf" },
	},
	Head = {
		{ 3, 11.5, -13.3, 1, 2, 1.5, "fur", "Jowl", true },
	},
}

-- Las tres caras de un jefe gorila, una por fase del combate: seria; furiosa (cejas en V, gruñido
-- enseñando los colmillos y ojos entornados); y rabiosa (ceño hundido, rugido, arrugas en el hocico y
-- ojos encendidos del color "glow"). Las cejas tapan la parte de arriba de los ojos para la furia, y
-- en las fases 2 y 3 son oscuras: del color del pelo no se leían en el Albino (blanco sobre blanco).
-- "more" añade rasgos a la cara de cada fase (arrugas, aletas de la nariz…): { [fase] = { cajas } }.
-- "eyeLook" (el Gorila de Ceniza) cambia los ojos de cada fase por { boxes = { [fase] = cajas }, colors = { [fase] =
-- color } }, siempre de neón; y "skin" da el color de la piel de la cara en cada fase (una capa fina sobre la
-- cara, el hocico y el mentón, que se cambia con la expresión sin añadir piezas).
local function phaseFaces(
	glow: Color3,
	more: { [number]: { any } }?,
	eyeLook: { boxes: { [number]: { any } }, colors: { [number]: Color3 }, darkBrows: boolean? }?,
	skin: { Color3 }?
): { any }
	local faces = {
		{
			brow = { { 0, 14.5, -14.5, 6, 1, 1.4, "fur" } },
			mouth = { { 0, 10.3, -16.05, 2.6, 0.3, 0.2, "mouth" } },
			eyes = { { 1.3, 13.4, -14.9, 1, 0.6, 0.2, "eye", nil, true } },
		},
		{
			-- Gruñido con la boca cerrada: con la boca abierta y los dientes en fila parecía sonreír.
			brow = {
				{ 0.8, 14, -14.6, 1.6, 1, 1.6, "dark", nil, true },
				{ 2.3, 14.6, -14.5, 1.6, 1, 1.4, "dark", nil, true },
			},
			mouth = {
				{ 0, 10.3, -16.05, 2.6, 0.45, 0.2, "mouth" },
				{ 0.8, 9.95, -16.15, 0.35, 0.5, 0.1, "teeth", nil, true },
				{ 0, 12.1, -16.05, 1.8, 0.2, 0.2, "dark" },
			},
			eyes = { { 1.3, 13.3, -14.9, 1.1, 0.45, 0.2, "eye", nil, true } },
		},
		{
			brow = {
				{ 0.7, 13.9, -14.65, 1.4, 1, 1.7, "dark", nil, true },
				{ 1.9, 14.3, -14.55, 1.2, 1, 1.5, "dark", nil, true },
				{ 2.8, 14.8, -14.5, 0.8, 1, 1.4, "dark", nil, true },
			},
			mouth = {
				{ 0, 10.35, -16.05, 3, 1.2, 0.2, "mouth" },
				{ 1, 10.75, -16.15, 0.45, 0.5, 0.1, "teeth", nil, true },
				{ 0.6, 9.95, -16.15, 0.4, 0.4, 0.1, "teeth", nil, true },
				{ 0, 12.1, -16.05, 2.2, 0.2, 0.2, "dark" },
			},
			eyes = { { 1.3, 13.3, -14.9, 1.1, 0.5, 0.2, nil, nil, true } },
			glow = true,
		},
	}
	local groups = {}
	for phase, face in faces do
		local layer = {}
		if skin then
			local color = skin[phase]
			layer = {
				{ 0, 12, -14.85, 5, 4, 0.1, color },
				{ 0, 11, -16.05, 4, 2.6, 0.1, color },
				{ 0, 9.2, -16.05, 3.6, 1.2, 0.1, color },
				-- Orificios de la nariz casi negros y por delante de todo el hocico, para que contrasten.
				{ 0.75, 11.55, -16.2, 0.6, 0.65, 0.1, NOSTRIL, nil, true },
			}
		end
		-- Con "eyeLook" (el Gorila de Ceniza) las cejas de todas las fases son del pelo, como la de la fase 1: el
		-- tono "dark" sale de la piel y aquí es rojizo. Con "darkBrows" (el Albino, de pelo blanco) se quedan oscuras.
		local brow = face.brow
		if eyeLook and not eyeLook.darkBrows then
			brow = {}
			for _, box in face.brow do
				local copy = table.clone(box)
				if copy[7] == "dark" then
					copy[7] = "fur"
				end
				table.insert(brow, copy)
			end
		end
		local boxes = join(layer, brow, face.mouth, if more then more[phase] or {} else {})
		table.insert(groups, { anchor = "Head", name = "Expression", phase = phase, boxes = boxes })
		table.insert(groups, {
			anchor = "Head",
			name = "Eye",
			phase = phase,
			tone = "eye",
			material = if face.glow or eyeLook then "Neon" else nil,
			color = if eyeLook then eyeLook.colors[phase] elseif face.glow then glow else nil,
			boxes = if eyeLook then eyeLook.boxes[phase] else face.eyes,
		})
	end
	return groups
end

-- Suma tablas de cajas por parte ({ Torso = {...}, Arm = {...} }) en una sola.
local function combine(...: { [string]: { any } }): { [string]: { any } }
	local all = {}
	for _, byPart in { ... } do
		for part, boxes in byPart do
			all[part] = join(all[part] or {}, boxes)
		end
	end
	return all
end

-- Moteado: "count" manchas planas de tonos de "colors" repartidas al azar (con semilla fija, así sale
-- siempre igual) por las caras visibles "faces" de una parte. Cada cara es
-- { eje, plano, hacia fuera (1 o -1), desde (dos coordenadas), hasta (dos coordenadas) }; con eje
-- "x" las dos coordenadas son y, z; con "y", x, z; y con "z", x, y. Las manchas sobresalen 0,1
-- celdas (o "thick", para las matas de pelo con relieve): las grietas de lava (0,15) y las rocas quedan por encima.
local function mottle(seed: number, count: number, colors: { Color3 }, faces: { { any } }, thick: number?): { any }
	local t = thick or 0.1
	local rng = Random.new(seed)
	local areas, total = {}, 0
	for index, face in faces do
		local from, to = face[4], face[5]
		total += (to[1] - from[1]) * (to[2] - from[2])
		areas[index] = total
	end
	local boxes = {}
	for _ = 1, count do
		local pick = rng:NextNumber(0, total)
		local face = faces[#faces]
		for index, area in areas do
			if pick <= area then
				face = faces[index]
				break
			end
		end
		local axis, plane, out, from, to = face[1], face[2], face[3], face[4], face[5]
		local a, b = rng:NextNumber(from[1], to[1]), rng:NextNumber(from[2], to[2])
		local sizeA, sizeB = rng:NextNumber(0.8, 1.8), rng:NextNumber(0.6, 1.4)
		local depth = plane + out * t / 2
		local color = colors[rng:NextInteger(1, #colors)]
		if axis == "x" then
			table.insert(boxes, { depth, a, b, t, sizeA, sizeB, color })
		elseif axis == "y" then
			table.insert(boxes, { a, depth, b, sizeA, t, sizeB, color })
		else
			table.insert(boxes, { a, b, depth, sizeA, sizeB, t, color })
		end
	end
	return boxes
end

-- Gorila de Ceniza, el jefe final: casi negro con un moteado gris de ceniza, más músculo y una cara
-- más trabajada en cada fase.
-- Manchas más oscuras y más claras que el lomo (ASH_SADDLE), para que se vean en él y en el pelo negro.
local ASH = { Color3.fromRGB(60, 58, 56), Color3.fromRGB(100, 97, 95), Color3.fromRGB(135, 132, 128) }
local ASH_SADDLE = Color3.fromRGB(82, 79, 77)
local CHARCOAL = Color3.fromRGB(45, 40, 40) -- el pecho (BOSS_EXTRAS lo pone de este color)

local CENIZA_MUSCLES = {
	Torso = {
		-- Joroba más alta sobre el trapecio, abdominales y costillas (serrato) detrás de los brazos.
		{ 0, 18.5, -4.5, 6, 1, 3.5, "fur", "Hump" },
		{ 1.1, 8.6, -9.5, 1.8, 1.1, 0.5, CHARCOAL, "Abs", true },
		{ 1.1, 7.4, -9.5, 1.8, 1.1, 0.5, CHARCOAL, "Abs", true },
		{ 6.2, 10.2, -2.4, 0.4, 0.6, 1.6, "shag", "Serratus", true },
		{ 6.2, 9.1, -2.4, 0.4, 0.6, 1.6, "shag", "Serratus", true },
		{ 6.2, 8, -2.4, 0.4, 0.6, 1.6, "shag", "Serratus", true },
	},
	Arm = {
		{ 7.5, 15.5, -8.8, 4, 2, 0.6, "fur", "Deltoid" },
		{ 10.45, 15.5, -5.5, 0.4, 2, 4, "fur", "Deltoid" },
		{ 7.5, 11, -3.4, 3, 3, 0.7, "fur", "Triceps" },
		{ 7.5, 5.2, -9.05, 3, 2.5, 0.5, "shag", "Forearm" },
	},
	Leg = {
		{ 5, 6.5, 9.3, 3.5, 3, 0.6, "fur", "Hamstring" },
	},
	Head = {
		{ 0, 20.5, -9, 1, 1, 2, "fur", "Crest" },
	},
}

-- Caras visibles de cada parte (para el moteado de ceniza y las matas de pelo).
local TORSO_FACES = {
	{ "y", 17, 1, { -8, -9 }, { 8, -1 } },
	{ "y", 18, 1, { -4.5, -7 }, { 4.5, -2 } },
	{ "x", 8, 1, { 11, -3.7 }, { 17, -1 } },
	{ "x", -8, -1, { 11, -3.7 }, { 17, -1 } },
	{ "z", -9, -1, { 4.5, 13 }, { 8, 17 } },
	{ "z", -9, -1, { -8, 13 }, { -4.5, 17 } },
	{ "y", 16, 1, { -6, -1 }, { 6, 4 } },
	{ "x", 6, 1, { 10, -1 }, { 16, 4 } },
	{ "x", -6, -1, { 10, -1 }, { 16, 4 } },
	{ "y", 15, 1, { -6, 4 }, { 6, 7 } },
	{ "x", 6, 1, { 9, 4 }, { 15, 7 } },
	{ "x", -6, -1, { 9, 4 }, { 15, 7 } },
	{ "y", 14, 1, { -6, 7 }, { 6, 10 } },
	{ "x", 6, 1, { 7, 7 }, { 14, 10 } },
	{ "x", -6, -1, { 7, 7 }, { 14, 10 } },
	{ "z", 10, 1, { -6, 7 }, { 6, 14 } },
}
local ARM_FACES = {
	-- Por delante (bíceps, antebrazo y hombro): es lo que se ve cuando viene de frente.
	{ "z", -8.95, -1, { 6, 9.75 }, { 9, 13.25 } },
	{ "z", -9.3, -1, { 6, 3.95 }, { 9, 6.45 } },
	{ "z", -9.1, -1, { 5.5, 14.5 }, { 9.5, 16.5 } },
	{ "x", 9.75, 1, { 7, -8.25 }, { 14, -3.75 } },
	{ "z", -3.75, 1, { 5.25, 7 }, { 9.75, 14 } },
	{ "y", 17, 1, { 4.75, -8.5 }, { 10.25, -2.5 } },
	{ "x", 10, 1, { 2, -8.8 }, { 7, -3.8 } },
	{ "z", -3.8, 1, { 5, 2 }, { 10, 7 } },
}
local LEG_FACES = {
	{ "x", 7.25, 1, { 3, 4 }, { 9, 9 } },
	{ "z", 9, 1, { 2.75, 3 }, { 7.25, 9 } },
}
local HEAD_FACES = {
	{ "x", 3.5, 1, { 10, -14 }, { 16, -8 } },
	{ "x", -3.5, -1, { 10, -14 }, { 16, -8 } },
	{ "x", 3, 1, { 16, -12.5 }, { 18, -7.5 } },
	{ "x", -3, -1, { 16, -12.5 }, { 18, -7.5 } },
	{ "y", 18, 1, { -3, -12.5 }, { 3, -7.5 } },
}

local CENIZA_ASH = {
	Torso = mottle(11, 55, ASH, TORSO_FACES),
	Arm = mottle(23, 26, ASH, ARM_FACES),
	Leg = mottle(37, 10, ASH, LEG_FACES),
	Head = mottle(41, 16, ASH, HEAD_FACES),
}

-- Sombreado pintado (Fase 20): matas de pelo con relieve en tres tonos (claro, medio y oscuro), para que cada
-- cara tenga luz y sombra aunque el pelo sea casi negro.
local FUR_TUFTS = { Color3.fromRGB(78, 73, 70), Color3.fromRGB(58, 54, 53), Color3.fromRGB(32, 29, 29) }
local CENIZA_FUR = {
	Torso = mottle(51, 70, FUR_TUFTS, TORSO_FACES, 0.3),
	Arm = mottle(53, 44, FUR_TUFTS, ARM_FACES, 0.3),
	Leg = mottle(57, 18, FUR_TUFTS, LEG_FACES, 0.3),
	Head = mottle(59, 22, FUR_TUFTS, HEAD_FACES, 0.25),
}

-- La lava del Gorila de Ceniza va de naranja a rojo con las fases del combate, y la piel de la cara a juego.
local LAVA_P = { Color3.fromRGB(255, 92, 15), Color3.fromRGB(255, 58, 15), Color3.fromRGB(235, 22, 22) }
local SKIN_P = { Color3.fromRGB(190, 80, 32), Color3.fromRGB(150, 40, 26), Color3.fromRGB(112, 18, 20) }
-- Los ojos, un tono más vivo que la piel para que se lean sobre ella.
local EYE_P = { Color3.fromRGB(255, 140, 30), Color3.fromRGB(255, 92, 22), Color3.fromRGB(255, 45, 35) }
local PUPIL = Color3.fromRGB(28, 8, 6)

-- Ojos de lava (nada de blanco), con la expresión de cada fase: 1, párpado a medias y pupila vertical (acecha);
-- 2, ceño inclinado (la esquina de dentro más baja) con pupila; 3, grandes y furiosos, con lágrimas de lava.
-- Se ven bajo las cejas de su fase (ver phaseFaces), así que van por debajo de ellas.
local CENIZA_EYES = {
	colors = EYE_P,
	boxes = {
		{
			{ 0.95, 12.7, -15, 0.65, 0.6, 0.2, nil, nil, true },
			{ 1.55, 12.85, -15, 0.65, 0.7, 0.2, nil, nil, true },
			{ 2.15, 13, -15, 0.65, 0.6, 0.2, nil, nil, true },
			{ 1.55, 12.85, -15.07, 0.3, 0.7, 0.1, PUPIL, nil, true },
			-- Párpado pesado e inclinado: la esquina de dentro más baja, como un ceño contenido.
			{ 0.95, 13.05, -15.06, 0.7, 0.35, 0.12, "dark", nil, true },
			{ 1.55, 13.25, -15.06, 0.7, 0.35, 0.12, "dark", nil, true },
			{ 2.15, 13.45, -15.06, 0.7, 0.35, 0.12, "dark", nil, true },
		},
		{
			{ 0.9, 12.35, -15, 0.75, 0.8, 0.2, nil, nil, true },
			{ 1.6, 12.7, -15, 0.75, 0.9, 0.2, nil, nil, true },
			{ 2.3, 13.05, -15, 0.75, 0.8, 0.2, nil, nil, true },
			{ 1.6, 12.7, -15.07, 0.3, 0.9, 0.1, PUPIL, nil, true },
			{ 2.3, 11.6, -14.95, 0.25, 0.8, 0.15, nil, nil, true },
		},
		{
			{ 0.75, 12.2, -15, 0.85, 0.9, 0.2, nil, nil, true },
			{ 1.5, 12.6, -15, 0.85, 1, 0.2, nil, nil, true },
			{ 2.25, 13, -15, 0.85, 0.9, 0.2, nil, nil, true },
			{ 1.5, 12.6, -15.07, 0.4, 1, 0.1, PUPIL, nil, true },
			{ 2.3, 11.4, -14.95, 0.25, 1.1, 0.15, nil, nil, true },
			{ 2.3, 10.5, -14.95, 0.3, 0.5, 0.15, nil, nil, true },
		},
	},
}

local OBSIDIAN = Color3.fromRGB(30, 27, 33)
local CLAW = Color3.fromRGB(20, 18, 20)
local EMBER = Color3.fromRGB(110, 44, 24)

-- Forma nueva del jefe (Fase 20): volcán y espinas en el lomo, brazales, guanteletes y garras, rodilleras y
-- cuernos de obsidiana, y la cara con cuencas, almohadilla de la nariz y mentón. Todo va dentro de la unión de
-- su parte, así que no añade piezas.
local CENIZA_FORM = {
	Torso = join(
		-- El volcán: tres escalones; el cráter y las coladas de lava van en el grupo LavaCrack.
		tower(0, 19, -4.2, 6.6, 5.2, 3, 0.9, 1.4, OBSIDIAN),
		-- Espinas del lomo, entre las losas de basalto.
		tower(0, 17, 1.5, 1.8, 1.8, 3, 0.8, 0.6, OBSIDIAN),
		tower(0, 15, 5.5, 1.8, 1.8, 3, 0.8, 0.6, OBSIDIAN),
		tower(0, 14, 8.5, 1.6, 1.6, 2, 0.8, 0.6, OBSIDIAN)
	),
	Arm = {
		-- Dos brazales, pincho en el codo, guantelete sobre los nudillos y garras.
		{ 7.5, 3.4, -6.3, 5.4, 0.7, 5.4, OBSIDIAN },
		{ 7.5, 5.9, -6.3, 5.4, 0.7, 5.4, OBSIDIAN },
		{ 10.2, 7.6, -4.2, 0.9, 1, 0.9, OBSIDIAN },
		{ 10.6, 8.6, -4.2, 0.6, 1, 0.6, OBSIDIAN },
		{ 7.5, 2.35, -8.3, 5.2, 0.9, 2.8, OBSIDIAN },
		{ 6, 0.4, -10.7, 0.9, 0.7, 0.8, CLAW },
		{ 7.5, 0.4, -10.7, 0.9, 0.7, 0.8, CLAW },
		{ 9, 0.4, -10.7, 0.9, 0.7, 0.8, CLAW },
	},
	Leg = {
		{ 5, 6.2, 3.75, 3.8, 2.6, 0.7, OBSIDIAN },
		{ 3.8, 0.4, 2.9, 0.9, 0.7, 0.8, CLAW },
		{ 5, 0.4, 2.9, 0.9, 0.7, 0.8, CLAW },
		{ 6.2, 0.4, 2.9, 0.9, 0.7, 0.8, CLAW },
	},
	Head = {
		-- Cuernos en escalones a los lados de la cresta, con la punta al rojo.
		{ 3.6, 16.6, -9.4, 1.4, 1.2, 1.4, OBSIDIAN, nil, true },
		{ 4.3, 17.6, -9.4, 1.1, 1.2, 1.1, OBSIDIAN, nil, true },
		{ 4.8, 18.7, -9.4, 0.8, 1.2, 0.8, OBSIDIAN, nil, true },
		{ 5.1, 19.8, -9.4, 0.5, 1.1, 0.5, EMBER, nil, true },
		-- Mentón (con su sombra) y ceniza clara en la frente; la piel de la cara va en una capa por fase.
		{ 0, 9.2, -14.9, 3.6, 1.2, 2.2, "skin" },
		{ 0, 8.56, -14.9, 3.6, 0.12, 2.2, "umber" },
		{ 0, 16.05, -11, 6, 0.12, 5, "lit" },
	},
}

-- Rasgos de más en la cara de cada fase: arrugas en la frente, ojeras, aletas de la nariz abiertas,
-- tensión en las mejillas y más colmillos al rugir.
local CENIZA_FACE = {
	{
		{ 0, 15.5, -14.05, 3, 0.2, 0.1, "dark" },
		{ 1.3, 12.9, -14.85, 1.2, 0.2, 0.1, "dark", nil, true },
		{ 1.5, 9.9, -15.95, 0.4, 1, 0.3, "teeth", nil, true },
	},
	{
		{ 0, 15.4, -14.05, 3.4, 0.2, 0.1, "dark" },
		{ 0, 15.8, -14.05, 2.2, 0.2, 0.1, "dark" },
		{ 0.7, 11.6, -16.1, 0.9, 0.8, 0.15, NOSTRIL, nil, true },
		{ 2.2, 11.5, -14.85, 0.2, 1.2, 0.1, "dark", nil, true },
		{ 1.5, 10.1, -15.95, 0.45, 1.4, 0.3, "teeth", nil, true },
	},
	{
		{ 0, 15.3, -14.05, 3.6, 0.2, 0.1, "dark" },
		{ 0, 15.6, -14.05, 2.8, 0.2, 0.1, "dark" },
		{ 0, 15.9, -14.05, 1.8, 0.2, 0.1, "dark" },
		{ 0.75, 11.6, -16.1, 1, 0.9, 0.15, NOSTRIL, nil, true },
		{ 2.2, 11.8, -14.85, 0.2, 1.2, 0.1, "dark", nil, true },
		{ 2.3, 10.6, -14.85, 0.2, 0.9, 0.1, "dark", nil, true },
		{ 0.4, 10.8, -16.15, 0.3, 0.35, 0.1, "teeth", nil, true },
		{ 1.6, 10.3, -15.95, 0.5, 1.8, 0.35, "teeth", nil, true },
	},
}

-- Gorila Albino (Fase 20 Q3a): pelaje blanco hueso con sombras azuladas, roca de cueva, cristales de rubí que crecen
-- y se encienden con las fases, y ojos lechosos con la pupila de rubí.
local IVORY = { Color3.fromRGB(246, 243, 238), Color3.fromRGB(206, 201, 200), Color3.fromRGB(158, 160, 176) }
local STONE = Color3.fromRGB(112, 120, 138)
local STONE_DARK = Color3.fromRGB(72, 78, 94)
local STONE_LIGHT = Color3.fromRGB(160, 168, 186)
local BONE = Color3.fromRGB(232, 226, 210)
local SHADE = Color3.fromRGB(176, 178, 192)

-- Torre colgante (estalactita): como "tower" pero cuelga desde "top" hacia abajo.
local function hang(
	x: number,
	top: number,
	z: number,
	width: number,
	depth: number,
	steps: number,
	h: number,
	shrink: number,
	tone: any
): { { any } }
	local boxes = {}
	for i = 0, steps - 1 do
		table.insert(boxes, { x, top - h * (i + 0.5), z, width - shrink * i, h, depth - shrink * i, tone })
	end
	return boxes
end

-- Marca todas las cajas como simétricas (aparecen también en el lado -X).
local function both(boxes: { { any } }): { { any } }
	for _, box in boxes do
		box[9] = true
	end
	return boxes
end

local ALBINO_MUSCLES = {
	Torso = {
		{ 0, 18.5, -4.5, 6, 1, 3.5, "fur", "Hump" },
		{ 1.1, 8.6, -9.5, 1.8, 1.1, 0.5, SHADE, "Abs", true },
		{ 1.1, 7.4, -9.5, 1.8, 1.1, 0.5, SHADE, "Abs", true },
		{ 6.2, 10.2, -2.4, 0.4, 0.6, 1.6, "shag", "Serratus", true },
		{ 6.2, 9.1, -2.4, 0.4, 0.6, 1.6, "shag", "Serratus", true },
		{ 6.2, 8, -2.4, 0.4, 0.6, 1.6, "shag", "Serratus", true },
	},
	Arm = CENIZA_MUSCLES.Arm,
	Leg = CENIZA_MUSCLES.Leg,
}

local ALBINO_FUR = {
	Torso = mottle(61, 110, IVORY, TORSO_FACES, 0.3),
	Arm = mottle(63, 70, IVORY, ARM_FACES, 0.3),
	Leg = mottle(67, 28, IVORY, LEG_FACES, 0.3),
	Head = mottle(69, 34, IVORY, HEAD_FACES, 0.25),
}

-- Forma nueva (dentro de la unión de cada parte, sin piezas): la cordillera de roca del lomo, la hombrera de
-- roca con estalactitas colgando, los puños con estalagmitas, garras de hueso y el mentón.
local ALBINO_FORM = {
	Torso = join(
		-- Pedestales de la cordillera, uno por cada racimo grande del lomo.
		tower(0, 18, -4.5, 4.4, 3.8, 2, 0.7, 1, STONE),
		tower(0, 16, 1.5, 3.4, 3, 2, 0.7, 0.8, STONE),
		tower(0, 15, 5.5, 3, 2.8, 2, 0.7, 0.8, STONE),
		tower(0, 14, 8.5, 2.8, 2.6, 2, 0.7, 0.8, STONE),
		both(tower(3.2, 17, -4, 2.2, 2.2, 2, 0.6, 0.6, STONE_DARK)),
		both(tower(2.6, 15.2, 1.5, 1.8, 1.8, 2, 0.6, 0.5, STONE_DARK)),
		-- Melena: una banda clara sobre los hombros.
		{ { 0, 17.2, -6.5, 12, 0.5, 2.5, IVORY[1] } }
	),
	Arm = join(
		-- Hombrera de roca en tres escalones y las estalactitas que cuelgan de su borde.
		{
			{ 8.2, 17.4, -5.5, 6.6, 0.8, 7, STONE },
			{ 8.2, 18.1, -5.5, 5, 0.7, 5.4, STONE_LIGHT },
			{ 8.2, 18.8, -5.5, 3.4, 0.7, 3.8, STONE },
		},
		hang(11, 17, -7.8, 1.3, 1.3, 4, 0.8, 0.3, STONE_DARK),
		hang(11, 17, -5.4, 1.5, 1.5, 5, 0.8, 0.3, STONE),
		hang(11, 17, -3.1, 1.2, 1.2, 4, 0.7, 0.3, STONE_DARK),
		hang(6.8, 17, -8.8, 1.2, 1.2, 3, 0.7, 0.3, STONE),
		hang(9.6, 17, -8.8, 1.3, 1.3, 4, 0.7, 0.3, STONE_DARK),
		-- El puño: guantelete de roca con tres estalagmitas y garras de hueso.
		{
			{ 7.5, 2.4, -8.4, 5.4, 1.1, 3, STONE_DARK },
			{ 7.5, 3.1, -8.2, 4.4, 0.5, 2.4, STONE },
		},
		tower(6, 3.3, -9.3, 1.1, 1.1, 3, 0.7, 0.3, STONE_LIGHT),
		tower(7.5, 3.3, -9.6, 1.3, 1.3, 4, 0.7, 0.3, STONE),
		tower(9, 3.3, -9.3, 1.1, 1.1, 3, 0.7, 0.3, STONE_LIGHT),
		{
			{ 6, 0.4, -10.7, 0.9, 0.7, 0.8, BONE },
			{ 7.5, 0.4, -10.7, 0.9, 0.7, 0.8, BONE },
			{ 9, 0.4, -10.7, 0.9, 0.7, 0.8, BONE },
		}
	),
	Leg = {
		{ 5, 6.2, 3.75, 3.8, 2.6, 0.7, STONE_DARK },
		{ 3.8, 0.4, 2.9, 0.9, 0.7, 0.8, BONE },
		{ 5, 0.4, 2.9, 0.9, 0.7, 0.8, BONE },
		{ 6.2, 0.4, 2.9, 0.9, 0.7, 0.8, BONE },
	},
	Head = {
		-- Mentón con su sombra y una frente clara; la piel de la cara va en una capa por fase.
		{ 0, 9.2, -14.9, 3.6, 1.2, 2.2, "skin" },
		{ 0, 8.56, -14.9, 3.6, 0.12, 2.2, "umber" },
		{ 0, 16.05, -11, 6, 0.12, 5, "lit" },
		-- Mechones de pelo en las mejillas.
		{ 3.8, 11.8, -12.2, 0.5, 1.6, 1.4, IVORY[2], nil, true },
		{ 3.8, 10.4, -12.6, 0.5, 1.2, 1.2, IVORY[3], nil, true },
	},
}

-- Cristales de rubí en racimos. Tres tamaños, uno por fase: los de siempre (los apagados), los que crecen en la
-- fase 2 y la corona de la fase 3. Cada fase pinta un grupo con las posiciones de la anterior más grandes y más racimos
-- (los de las fases 2 y 3 sustituyen al de la fase anterior, ver MonkeyModels.showPhase).
local RIDGE_BASE = join(
	crystal(0, 19.4, -4.5, 0.9),
	crystal(2.2, 18, -3.5, 0.6),
	crystal(-2.2, 18, -3.8, 0.6),
	crystal(0, 17.4, 1.5, 0.7),
	crystal(0, 16.4, 5.5, 0.6),
	crystal(0, 15.4, 8.5, 0.5),
	crystal(-2.6, 12, -10, 0.6, true),
	crystal(1.2, 8.4, -10, 0.5, true)
)
local RIDGE_GROW = join(
	crystal(0, 19.4, -4.5, 1.3),
	crystal(3.2, 18.6, -4, 0.9),
	crystal(-3.2, 18.6, -4, 0.9),
	crystal(0, 17.4, 1.5, 1),
	crystal(2.6, 16.2, 1.5, 0.6),
	crystal(-2.6, 16.2, 1.5, 0.6),
	crystal(0, 16.4, 5.5, 0.8),
	crystal(0, 15.4, 8.5, 0.7),
	crystal(-2.6, 12, -10, 0.7, true),
	crystal(1.2, 8.4, -10, 0.6, true)
)
local RIDGE_CROWN = join(
	crystal(0, 19.4, -4.5, 1.8),
	crystal(3.4, 18.6, -4, 1.2),
	crystal(-3.4, 18.6, -4, 1.2),
	crystal(0, 17.4, 1.5, 1.4),
	crystal(2.8, 16.2, 1.5, 0.9),
	crystal(-2.8, 16.2, 1.5, 0.9),
	crystal(0, 16.4, 5.5, 1.1),
	crystal(2, 15.2, 6, 0.7),
	crystal(-2, 15.2, 6, 0.7),
	crystal(0, 15.4, 8.5, 0.9),
	crystal(-2.6, 12, -10, 0.8, true),
	crystal(1.2, 8.4, -10, 0.7, true)
)
local SHOULDER_BASE = join(crystal(8.2, 19.15, -5.5, 0.7), crystal(10.4, 17.8, -7, 0.45))
local SHOULDER_GROW = join(
	crystal(8.2, 19.15, -5.5, 1.1),
	crystal(10.2, 17.8, -4, 0.7),
	crystal(6.2, 17.8, -3.5, 0.6),
	crystal(7.5, 5.7, -9.6, 0.4)
)
local SHOULDER_CROWN = join(
	crystal(8.2, 19.15, -5.5, 1.6),
	crystal(10.4, 17.8, -4, 1),
	crystal(6, 17.8, -7.5, 0.9),
	crystal(6.2, 17.8, -3.2, 0.8),
	crystal(10.6, 17.8, -7.5, 0.7),
	crystal(7.5, 5.7, -9.6, 0.55),
	crystal(6, 4.7, -9.3, 0.35),
	crystal(9, 4.7, -9.3, 0.35)
)
local RUBY_P = { Color3.fromRGB(150, 20, 36), Color3.fromRGB(205, 25, 45), Color3.fromRGB(240, 35, 55) }

-- Venas de rubí encendidas: el pecho desde el corazón, y en la fase 3 también los flancos y la espalda.
local VEINS_FRONT = join(
	vein("z", -10.1, 1.2, 9, { { 1.6, 0 }, { 0, 1.6 }, { 1.4, 0 } }, 0.3, 0.16, true),
	vein("z", -10.1, 1.2, 9, { { 0, -1.8 }, { 1.2, 0 } }, 0.3, 0.16, true)
)
local VEINS_ALL = join(
	VEINS_FRONT,
	vein("x", 6.2, 12.5, 6, { { 0, 1 }, { -1.2, 0 }, { 0, 0.8 } }, 0.4, 0.4, true),
	vein("z", 10.2, 3.5, 12.5, { { 0, -1.5 }, { 1.5, 0 }, { 0, -1.2 } }, 0.4, 0.4, true),
	vein("z", 10.2, 0, 13.4, { { 0, -2 }, { -1, 0 }, { 0, -2.5 }, { 1.2, 0 }, { 0, -1.4 } }, 0.45, 0.4)
)

-- Ojos lechosos (ciegos) con la pupila de rubí, que brilla más cada fase. Parten de los de lava del Ceniza
-- (la misma expresión por fase): su pupila se cambia por la de rubí, más ancha.
local ALBINO_EYE_COLORS =
	{ Color3.fromRGB(222, 218, 230), Color3.fromRGB(240, 205, 212), Color3.fromRGB(255, 175, 180) }
local ALBINO_PUPILS = { Color3.fromRGB(150, 15, 30), Color3.fromRGB(205, 25, 45), Color3.fromRGB(255, 35, 60) }
local ALBINO_SKIN = { Color3.fromRGB(200, 140, 146), Color3.fromRGB(205, 105, 115), Color3.fromRGB(170, 48, 62) }
local ALBINO_EYES = { colors = ALBINO_EYE_COLORS, darkBrows = true, boxes = {} :: { { any } } }
for phase, boxes in CENIZA_EYES.boxes do
	local copy = {}
	for _, box in boxes do
		local clone = table.clone(box)
		if clone[7] == PUPIL then
			clone[7] = ALBINO_PUPILS[phase]
			clone[4] *= 1.6
		end
		table.insert(copy, clone)
	end
	ALBINO_EYES.boxes[phase] = copy
end

return {
	-- Con 0,18 y su scale (1,45) tiene los hombros a ~4,4 studs: 1,5 m, como un gorila macho a cuatro
	-- patas al lado de un jugador de 1,75 m (1 m ≈ 3 studs). Sus jefes quedan como en el GDD §8.2.
	unit = 0.18,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			boxes = {
				{ 0, 11, -3, 12, 8, 10, "fur" },
				-- Hombros enormes, más altos que la cabeza.
				{ 0, 14, -5, 16, 6, 8, "fur", "Shoulders" },
				-- Lomo plateado en tres escalones que bajan hacia la grupa. Los tres igual de anchos y el
				-- último hasta las patas: desde atrás se ve un solo panel (con escalones distintos
				-- parecían los cajones de una cómoda).
				{ 0, 13, 1.5, 12, 6, 5, "silver", "Saddle" },
				{ 0, 12, 5.5, 12, 6, 3, "silver", "Saddle" },
				{ 0, 10.5, 8.5, 12, 7, 3, "silver", "Saddle" },
				{ 0, 8.5, 3, 10, 3, 10, "fur", "Belly" },
				{ 0, 10, -8.6, 9, 6, 1.4, "chest", "Chest" },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 13, -8 },
			boxes = {
				{ 0, 13, -11, 7, 6, 6, "fur" },
				-- La cresta, en escalones hacia arriba y atrás.
				{ 0, 17, -10, 6, 2, 5, "fur", "Crest" },
				{ 0, 18.5, -9.5, 4, 1, 4, "fur", "Crest" },
				{ 0, 19.5, -9, 2, 1, 3, "fur", "Crest" },
				{ 0, 12, -14.3, 5, 4, 1, "skin", "Face" },
				{ 0, 14.5, -14.5, 6, 1, 1.4, "fur", "Brow" },
				{ 1.3, 13.4, -14.9, 1, 0.6, 0.2, "eye", "Eye", true },
				{ 0, 11, -15.2, 4, 2.6, 1.6, "skin", "Muzzle" },
				{ 0.7, 11.6, -16.05, 0.6, 0.6, 0.2, "dark", "Nostril", true },
				{ 0, 10.3, -16.05, 2.6, 0.3, 0.2, "mouth", "Mouth" },
				{ 3.6, 13, -10.5, 0.6, 1.4, 1, "skin", "Ear", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 7.5, 14, -6 },
			boxes = {
				{ 7.5, 11, -6, 4.5, 8, 4.5, "fur" },
				-- Masa del hombro: sobresale de los hombros del torso y se mueve con el brazo.
				{ 7.5, 15.5, -5.5, 5.5, 3, 6, "fur", "Deltoid" },
				{ 7.5, 4.5, -6.3, 5, 5, 5, "shag", "Forearm" },
				{ 7.5, 1, -6.8, 5, 2, 5.6, "paws", "Hand" },
				{ 6, 0.5, -10, 1.2, 1, 1, "paws", "Finger" },
				{ 7.5, 0.5, -10, 1.2, 1, 1, "paws", "Finger" },
				{ 9, 0.5, -10, 1.2, 1, 1, "paws", "Finger" },
			},
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 5, 8, 6 },
			boxes = {
				{ 5, 6, 6.5, 4.5, 6, 5, "fur" },
				{ 5, 1.5, 6, 4, 3, 5.5, "paws", "Foot" },
			},
		},
	},
	-- El alfa: espalda plateada de verdad, con el cuerpo negro intenso y el plateado más claro (un
	-- parche plateado en el muslo parecía una pegatina), la cresta más alta y más músculo; la ceja recta pasa a un ceño
	-- un poco en V sobre los ojos (las puntas de los colmillos parecían dientes de conejo).
	alpha = {
		tones = {
			fur = Color3.fromRGB(26, 26, 30),
			shag = Color3.fromRGB(38, 38, 43),
			silver = Color3.fromRGB(175, 175, 183), -- más claro salía blanco
		},
		remove = { "Brow" },
		add = {
			Torso = {
				{ 0, 17.5, -4.5, 9, 1, 5, "fur", "Trapezius" },
				{ 0, 16.5, 1.5, 8, 1, 4, "silver", "Lats" },
			},
			Head = {
				{ 0, 20.4, -8.6, 1.4, 1, 2.4, "fur", "Crest" },
				-- No se llaman "Brow": "remove" las quitaría también. El lado de dentro baja sobre la cara
				-- y tapa la parte de arriba de los ojos; más arriba quedaba sobre el pelo negro y no se veía.
				{ 2, 14.4, -14.6, 2.2, 0.9, 1.5, "dark", "Scowl", true },
				{ 0.75, 14.05, -14.75, 1.5, 0.9, 1.6, "dark", "Scowl", true },
			},
		},
	},
	-- Lo que cada jefe cambia del cuerpo del gorila (ver VoxelBoss en MonkeyModels): quita la cara
	-- normal (va por fases), añade músculos a las partes y pone sus adornos en grupos de un material.
	bosses = {
		-- Gorila Albino (Fase 20 Q3a): pelaje blanco hueso con sombras azuladas, roca de cueva (cordillera en el lomo,
		-- hombreras con estalactitas, puños con estalagmitas) y cristales de rubí que crecen y se encienden con las
		-- fases; ojos lechosos con la pupila de rubí. El corazón cian del pecho es el único tono frío (punto débil).
		GorilaAlbino = {
			tones = {
				lit = Color3.fromRGB(248, 245, 240),
				umber = Color3.fromRGB(150, 152, 168),
			},
			remove = BOSS_FACE,
			add = combine(BOSS_MUSCLES, ALBINO_MUSCLES, ALBINO_FUR, ALBINO_FORM),
			groups = join(phaseFaces(Color3.fromRGB(255, 60, 70), CENIZA_FACE, ALBINO_EYES, ALBINO_SKIN), {
				-- Cristales de siempre (apagados en la fase 1, más vivos en la 2 y la 3 con phaseColors).
				{
					anchor = "Torso",
					name = "Crystal",
					color = RUBY_P[1],
					phaseColors = RUBY_P,
					material = "Glass",
					boxes = RIDGE_BASE,
				},
				{
					anchor = "Arm",
					mirror = true,
					name = "Crystal",
					color = RUBY_P[1],
					phaseColors = RUBY_P,
					material = "Glass",
					boxes = SHOULDER_BASE,
				},
				{
					anchor = "Head",
					name = "Crystal",
					color = RUBY_P[1],
					phaseColors = RUBY_P,
					material = "Glass",
					boxes = join(crystal(1.2, 20, -8.5, 0.5), crystal(-1, 20, -9.5, 0.4)),
				},
				-- Fase 2: los racimos crecen. Los de la fase 3 sustituyen a estos (showPhase) y son enormes.
				{
					anchor = "Torso",
					name = "CrystalGrow",
					color = RUBY_P[2],
					material = "Glass",
					phase = 2,
					boxes = RIDGE_GROW,
				},
				{
					anchor = "Arm",
					mirror = true,
					name = "CrystalGrow",
					color = RUBY_P[2],
					material = "Glass",
					phase = 2,
					boxes = SHOULDER_GROW,
				},
				{
					anchor = "Head",
					name = "CrystalGrow",
					color = RUBY_P[2],
					material = "Glass",
					phase = 2,
					boxes = join(crystal(1.2, 20, -8.5, 0.8), crystal(-1, 20, -9.5, 0.65), crystal(0, 20, -7.5, 0.5)),
				},
				{
					anchor = "Torso",
					name = "CrystalGrow",
					color = RUBY_P[3],
					material = "Glass",
					phase = 3,
					boxes = RIDGE_CROWN,
				},
				{
					anchor = "Arm",
					mirror = true,
					name = "CrystalGrow",
					color = RUBY_P[3],
					material = "Glass",
					phase = 3,
					boxes = SHOULDER_CROWN,
				},
				{
					anchor = "Head",
					name = "CrystalGrow",
					color = RUBY_P[3],
					material = "Glass",
					phase = 3,
					boxes = join(
						crystal(1.2, 20, -8.5, 1.1),
						crystal(-1, 20, -9.5, 0.9),
						crystal(0, 20, -7.5, 0.8),
						crystal(2.6, 19, -9.5, 0.5, false)
					),
				},
				{
					anchor = "Torso",
					name = "CrystalCore",
					-- Punto débil (MonkeyModels, Bosses.weakPoints): cian, el único tono frío del jefe, no rojo.
					color = Color3.fromRGB(90, 230, 255),
					material = "Neon",
					boxes = { { 0, 9, -10.2, 2.2, 2.2, 0.8 } },
				},
				-- Venas de rubí: en la fase 2 salen del corazón por el pecho; en la 3 también por los flancos y la espalda.
				{
					anchor = "Torso",
					name = "CrystalVein",
					color = Color3.fromRGB(205, 25, 45),
					material = "Neon",
					phase = 2,
					boxes = VEINS_FRONT,
				},
				{
					anchor = "Torso",
					name = "CrystalVein",
					color = Color3.fromRGB(255, 60, 70),
					material = "Neon",
					phase = 3,
					boxes = VEINS_ALL,
				},
				{
					anchor = "Arm",
					mirror = true,
					name = "CrystalVein",
					color = Color3.fromRGB(255, 60, 70),
					material = "Neon",
					phase = 3,
					boxes = {
						{ 6.8, 11.5, -9, 0.3, 3, 0.15 },
						{ 8, 5, -8.85, 0.3, 2.5, 0.15 },
					},
				},
			}),
		},
		-- Gorila de Ceniza, el jefe final: casi negro con moteado de ceniza, más músculo, placas de roca
		-- volcánica en el lomo y los hombros, grietas de lava (filas de celdas de neón al ras) por todo
		-- el cuerpo y, en la fase 3, más grietas encendidas y lava cayéndole de la boca.
		GorilaDeCeniza = {
			-- El lomo de ceniza, no plateado: con el tono de siempre salía casi blanco sobre el negro.
			-- "lit" y "umber": la luz y la sombra pintadas del pelo (ver CENIZA_FUR y CENIZA_FORM).
			tones = {
				silver = ASH_SADDLE,
				lit = Color3.fromRGB(78, 73, 70),
				umber = Color3.fromRGB(24, 21, 21),
				-- Piel de corteza de lava: la de base de orejas, manos y pies; la de la cara cambia con la fase.
				skin = Color3.fromRGB(176, 62, 34),
				paws = Color3.fromRGB(150, 50, 28),
			},
			remove = BOSS_FACE,
			add = combine(BOSS_MUSCLES, CENIZA_MUSCLES, CENIZA_ASH, CENIZA_FUR, CENIZA_FORM),
			groups = join(phaseFaces(LAVA, CENIZA_FACE, CENIZA_EYES, SKIN_P), {
				{
					-- Punto débil (MonkeyModels, Bosses.weakPoints): el núcleo del pecho, entre los
					-- pectorales, blanco incandescente con el centro más claro; las grietas son naranja.
					anchor = "Torso",
					name = "LavaCore",
					color = Color3.fromRGB(255, 235, 150),
					material = "Neon",
					boxes = {
						{ 0, 11.2, -10.3, 2.2, 2.2, 0.8 },
						{ 0, 11.2, -10.75, 1.1, 1.1, 0.2, Color3.fromRGB(255, 252, 225) },
					},
				},
				{
					anchor = "Torso",
					name = "Basalt",
					color = BASALT,
					material = "Slate",
					-- Placas anchas a los dos lados del lomo, como una coraza de lava enfriada (las espinas del
					-- centro son de obsidiana y van en la unión del torso).
					boxes = join(
						rock(3.2, 17.4, 1.5, 3.4, 3.2, true),
						rock(3.2, 15.4, 5.5, 3.4, 2.6, true),
						rock(3.2, 14.4, 8.5, 3.4, 2.2, true)
					),
				},
				{
					-- Hombrera en tres escalones con un pincho, y una placa en el costado del brazo.
					anchor = "Arm",
					mirror = true,
					name = "Basalt",
					color = BASALT,
					material = "Slate",
					boxes = join({
						{ 8.2, 17.35, -5.5, 6.4, 0.7, 6.6 },
						{ 8.2, 18.05, -5.5, 4.8, 0.7, 5 },
						{ 8.2, 18.75, -5.5, 3.2, 0.7, 3.4 },
						{ 10.8, 15.6, -5.5, 0.6, 2.4, 4.4 },
					}, tower(8.2, 19.1, -5.5, 1.4, 1.4, 3, 0.7, 0.4)),
				},
				{
					-- El cráter del volcán del lomo y sus coladas por detrás, y las venas del pecho, el vientre,
					-- los flancos y la espalda. Las de pelo con relieve (flancos y espalda) son gruesas (0,4) para
					-- asomar por encima de las matas.
					anchor = "Torso",
					name = "LavaCrack",
					color = LAVA_P[1],
					phaseColors = LAVA_P,
					material = "Neon",
					boxes = join(
						{
							{ 0, 21.85, -4.2, 2.2, 0.25, 1.6 },
							{ 0.5, 21.25, -2.95, 0.5, 0.9, 0.12 },
							{ 0.9, 20.35, -2.25, 0.5, 0.9, 0.12 },
							{ 0.4, 19.45, -1.55, 0.5, 0.9, 0.12 },
						},
						vein("z", -10.2, 1.2, 11.2, { { 1.9, 0 }, { 0, 1.2 }, { 1, 0 } }, 0.35, 0.16, true),
						vein("z", -10.2, 2.6, 11.2, { { 0, -1 }, { 1.2, 0 } }, 0.3, 0.16, true),
						vein("z", -9.55, -1.9, 8, { { 3.8, 0 } }, 0.25, 0.5),
						vein("z", -9.55, 0, 7, { { 0, 2.2 } }, 0.3, 0.5),
						vein(
							"x",
							6.2,
							14.2,
							1,
							{ { -1.5, 0 }, { 0, 2.2 }, { -1.5, 0 }, { 0, 1.8 }, { -1.5, 0 } },
							0.4,
							0.4,
							true
						),
						vein("z", 10.2, 1.5, 7.6, { { 0, 3 }, { 2.5, 0 }, { 0, 2 }, { -1.5, 0 } }, 0.4, 0.4, true),
						vein(
							"z",
							10.2,
							0,
							13.4,
							{ { 0, -2 }, { -1, 0 }, { 0, -2.5 }, { 1.2, 0 }, { 0, -1.4 } },
							0.45,
							0.4
						)
					),
				},
				{
					-- Costuras de la hombrera, el guantelete y las venas del brazo por delante.
					anchor = "Arm",
					mirror = true,
					name = "LavaCrack",
					color = LAVA_P[1],
					phaseColors = LAVA_P,
					material = "Neon",
					boxes = join(
						{
							{ 10.5, 11.5, -6, 0.2, 3, 0.5 },
							{ 10.5, 10.3, -5.2, 0.2, 0.5, 1.6 },
							{ 10.65, 5, -6.3, 0.2, 2, 0.5 },
							{ 7.5, 2.82, -8.3, 3.6, 0.15, 0.4 },
						},
						frame(8.2, 17.7, -5.5, 6.6, 6.8, 0.3, 0.12),
						frame(8.2, 18.4, -5.5, 5, 5.2, 0.3, 0.12),
						vein("z", -9.15, 7, 13, { { 0, -1.2 }, { 1.2, 0 }, { 0, -1.6 } }, 0.35, 0.4),
						vein("z", -9.5, 7.5, 6.2, { { 0, -1 }, { 1, 0 }, { 0, -1 } }, 0.3, 0.4)
					),
				},
				{
					anchor = "Leg",
					mirror = true,
					name = "LavaCrack",
					color = LAVA_P[1],
					phaseColors = LAVA_P,
					material = "Neon",
					boxes = join({
						{ 7.9, 6, 5.5, 0.2, 2.5, 0.5 },
						{ 5, 6.5, 9.65, 0.5, 2, 0.2 },
					}, vein("z", 3.3, 3.9, 7.2, { { 0, -1.6 }, { 1.6, 0 } }, 0.3, 0.12)),
				},
				{
					anchor = "Head",
					name = "LavaCrack",
					color = LAVA_P[1],
					phaseColors = LAVA_P,
					material = "Neon",
					boxes = {
						{ 3.6, 15, -10, 0.2, 1.4, 0.4, nil, nil, true },
						{ 3.55, 13, -9, 0.2, 2, 0.4, nil, nil, true },
					},
				},
				{
					-- Fase 3: el volcán echa llamas y se encienden más venas en los flancos y la espalda.
					anchor = "Torso",
					name = "LavaCrack",
					color = LAVA_P[3],
					material = "Neon",
					phase = 3,
					boxes = join(
						{
							-- Llamaradas del cráter y coladas de lava a todo el ancho por detrás del volcán.
							{ 0, 23, -4.2, 0.9, 2.2, 0.9 },
							{ 1.3, 22.7, -4, 0.6, 1.6, 0.6, nil, nil, true },
							{ 1.8, 22.4, -4.4, 0.5, 1.1, 0.5, nil, nil, true },
							{ 0, 21.25, -2.95, 3, 0.8, 0.12 },
							{ 0, 20.35, -2.25, 4.4, 0.8, 0.12 },
							{ 0, 19.45, -1.55, 5.6, 0.8, 0.12 },
							-- Las espinas del lomo, incandescentes de la mitad hacia arriba.
							{ 0, 19, 1.5, 0.7, 1.2, 0.7 },
							{ 0, 17, 5.5, 0.7, 1.2, 0.7 },
							{ 0, 15.2, 8.5, 0.7, 1.2, 0.7 },
						},
						-- La erupción: los tres escalones del volcán al rojo vivo.
						frame(0, 19.9, -4.2, 6.8, 5.4, 0.3, 0.12),
						frame(0, 20.8, -4.2, 5.4, 4, 0.3, 0.12),
						frame(0, 21.7, -4.2, 4, 2.6, 0.3, 0.12),
						vein("x", 6.2, 12.5, 6, { { 0, 1 }, { -1.2, 0 }, { 0, 0.8 } }, 0.4, 0.4, true),
						vein("z", 10.2, 3.5, 12.5, { { 0, -1.5 }, { 1.5, 0 }, { 0, -1.2 } }, 0.4, 0.4, true)
					),
				},
				{
					anchor = "Arm",
					mirror = true,
					name = "LavaCrack",
					color = LAVA_P[3],
					material = "Neon",
					phase = 3,
					boxes = {
						{ 8, 4.5, -9.35, 0.3, 2, 0.1 },
						-- La punta del pincho de la hombrera, incandescente.
						{ 8.2, 21.4, -5.5, 0.4, 0.5, 0.4 },
					},
				},
				{
					-- En la fase 3: grieta en la cresta y lava cayéndole por las comisuras al rugir.
					anchor = "Head",
					name = "LavaCrack",
					color = LAVA_P[3],
					material = "Neon",
					phase = 3,
					boxes = {
						{ 1.5, 19.05, -9.5, 0.6, 0.2, 2 },
						{ 5.1, 20.5, -9.4, 0.4, 0.5, 0.4, nil, nil, true },
						{ 1.2, 9.3, -16.1, 0.3, 0.9, 0.2, nil, nil, true },
						{ 1.2, 8.7, -16.1, 0.5, 0.3, 0.2, nil, nil, true },
					},
				},
			}),
		},
	},
}
