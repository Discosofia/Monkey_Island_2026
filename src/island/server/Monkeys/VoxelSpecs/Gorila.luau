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

local RUBY = Color3.fromRGB(205, 25, 45)
local LAVA = Color3.fromRGB(255, 110, 30)

-- Losa de roca en escalón: una placa y otra más pequeña encima.
local function rock(x: number, y: number, z: number, width: number, depth: number): { { any } }
	return {
		{ x, y, z, width, 0.8, depth },
		{ x + width * 0.1, y + 0.6, z - depth * 0.1, width * 0.6, 0.6, depth * 0.6 },
	}
end

local BASALT = Color3.fromRGB(40, 36, 36)

-- Los jefes quitan la cara normal: la suya cambia con la fase del combate (phaseFaces).
local BOSS_FACE = { "Brow", "Eye", "Mouth" }

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
local function phaseFaces(glow: Color3, more: { [number]: { any } }?): { any }
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
		local boxes = join(face.brow, face.mouth, if more then more[phase] or {} else {})
		table.insert(groups, { anchor = "Head", name = "Expression", phase = phase, boxes = boxes })
		table.insert(groups, {
			anchor = "Head",
			name = "Eye",
			phase = phase,
			tone = "eye",
			material = if face.glow then "Neon" else nil,
			color = if face.glow then glow else nil,
			boxes = face.eyes,
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
-- celdas: las grietas de lava (0,15) y las rocas quedan por encima.
local function mottle(seed: number, count: number, colors: { Color3 }, faces: { { any } }): { any }
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
		local depth = plane + out * 0.05
		local color = colors[rng:NextInteger(1, #colors)]
		if axis == "x" then
			table.insert(boxes, { depth, a, b, 0.1, sizeA, sizeB, color })
		elseif axis == "y" then
			table.insert(boxes, { a, depth, b, sizeA, 0.1, sizeB, color })
		else
			table.insert(boxes, { a, b, depth, sizeA, sizeB, 0.1, color })
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

local CENIZA_ASH = {
	Torso = mottle(11, 55, ASH, {
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
	}),
	Arm = mottle(23, 26, ASH, {
		-- Por delante (bíceps, antebrazo y hombro): es lo que se ve cuando viene de frente.
		{ "z", -8.95, -1, { 6, 9.75 }, { 9, 13.25 } },
		{ "z", -9.3, -1, { 6, 3.95 }, { 9, 6.45 } },
		{ "z", -9.1, -1, { 5.5, 14.5 }, { 9.5, 16.5 } },
		{ "x", 9.75, 1, { 7, -8.25 }, { 14, -3.75 } },
		{ "z", -3.75, 1, { 5.25, 7 }, { 9.75, 14 } },
		{ "y", 17, 1, { 4.75, -8.5 }, { 10.25, -2.5 } },
		{ "x", 10, 1, { 2, -8.8 }, { 7, -3.8 } },
		{ "z", -3.8, 1, { 5, 2 }, { 10, 7 } },
	}),
	Leg = mottle(37, 10, ASH, {
		{ "x", 7.25, 1, { 3, 4 }, { 9, 9 } },
		{ "z", 9, 1, { 2.75, 3 }, { 7.25, 9 } },
	}),
	Head = mottle(41, 16, ASH, {
		{ "x", 3.5, 1, { 10, -14 }, { 16, -8 } },
		{ "x", -3.5, -1, { 10, -14 }, { 16, -8 } },
		{ "x", 3, 1, { 16, -12.5 }, { 18, -7.5 } },
		{ "x", -3, -1, { 16, -12.5 }, { 18, -7.5 } },
		{ "y", 18, 1, { -3, -12.5 }, { 3, -7.5 } },
	}),
}

-- Rasgos de más en la cara de cada fase: arrugas en la frente, ojeras, aletas de la nariz abiertas,
-- tensión en las mejillas y más colmillos al rugir.
local CENIZA_FACE = {
	{
		{ 0, 15.5, -14.05, 3, 0.2, 0.1, "dark" },
		{ 1.3, 12.9, -14.85, 1.2, 0.2, 0.1, "dark", nil, true },
	},
	{
		{ 0, 15.4, -14.05, 3.4, 0.2, 0.1, "dark" },
		{ 0, 15.8, -14.05, 2.2, 0.2, 0.1, "dark" },
		{ 0.7, 11.6, -16.1, 0.9, 0.8, 0.15, "dark", nil, true },
		{ 2.2, 11.5, -14.85, 0.2, 1.2, 0.1, "dark", nil, true },
	},
	{
		{ 0, 15.3, -14.05, 3.6, 0.2, 0.1, "dark" },
		{ 0, 15.6, -14.05, 2.8, 0.2, 0.1, "dark" },
		{ 0, 15.9, -14.05, 1.8, 0.2, 0.1, "dark" },
		{ 0.75, 11.6, -16.1, 1, 0.9, 0.15, "dark", nil, true },
		{ 2.2, 11.8, -14.85, 0.2, 1.2, 0.1, "dark", nil, true },
		{ 2.3, 10.6, -14.85, 0.2, 0.9, 0.1, "dark", nil, true },
		{ 0.4, 10.8, -16.15, 0.3, 0.35, 0.1, "teeth", nil, true },
	},
}

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
	-- Lo que cada jefe cambia del cuerpo del gorila (ver VoxelBoss en MonkeyModels): quita la cara
	-- normal (va por fases), añade músculos a las partes y pone sus adornos en grupos de un material.
	bosses = {
		-- Gorila Albino: racimos de cristales de rubí en los hombros, el lomo, los brazos y la cresta,
		-- el corazón de neón en el pecho, y en la fase 3 venas de rubí encendidas.
		GorilaAlbino = {
			remove = BOSS_FACE,
			add = BOSS_MUSCLES,
			groups = join(phaseFaces(Color3.fromRGB(255, 60, 70)), {
				{
					anchor = "Torso",
					name = "Crystal",
					color = RUBY,
					material = "Glass",
					transparency = 0.3,
					boxes = join(
						crystal(3, 18, -5, 1.3),
						crystal(4.2, 17.5, -2.5, 1),
						crystal(1.8, 18, -3, 0.8),
						crystal(-3, 18, -4.5, 1.1),
						crystal(-1.6, 18, -2.5, 0.8),
						crystal(1.5, 16.5, 2, 0.9),
						crystal(-2, 14.5, 5.5, 0.7),
						crystal(2.5, 14.5, 6, 0.6),
						crystal(-0.5, 13.5, 8.5, 0.5),
						crystal(-2.6, 12, -10, 0.6, true),
						crystal(1.2, 8.4, -10, 0.5, true)
					),
				},
				{
					anchor = "Arm",
					mirror = true,
					name = "Crystal",
					color = RUBY,
					material = "Glass",
					transparency = 0.3,
					boxes = join(crystal(8.5, 16.5, -5, 0.9), crystal(6, 16.5, -3.2, 0.6)),
				},
				{
					anchor = "Head",
					name = "Crystal",
					color = RUBY,
					material = "Glass",
					transparency = 0.3,
					boxes = join(crystal(1.2, 19.5, -8.5, 0.5), crystal(-1, 19.5, -9.5, 0.4)),
				},
				{
					anchor = "Torso",
					name = "CrystalCore",
					color = Color3.fromRGB(255, 70, 70),
					material = "Neon",
					boxes = { { 0, 9, -10.2, 1.8, 1.8, 0.8 } },
				},
				{
					anchor = "Torso",
					name = "CrystalVein",
					color = Color3.fromRGB(255, 60, 70),
					material = "Neon",
					phase = 3,
					boxes = {
						{ 5.8, 14.5, -9.05, 0.3, 3, 0.2, nil, nil, true },
						{ 6.6, 13.1, -9.05, 1.6, 0.3, 0.2, nil, nil, true },
						{ 4.9, 16, -9.05, 1.8, 0.3, 0.2, nil, nil, true },
					},
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
			tones = { silver = ASH_SADDLE },
			remove = BOSS_FACE,
			add = combine(BOSS_MUSCLES, CENIZA_MUSCLES, CENIZA_ASH),
			groups = join(phaseFaces(LAVA, CENIZA_FACE), {
				{
					anchor = "Torso",
					name = "Basalt",
					color = BASALT,
					material = "Slate",
					-- Placas anchas, como una coraza de lava enfriada: de 2,5 celdas parecían botones.
					boxes = join(
						rock(-2, 17.4, 1.5, 4, 3.5),
						rock(2.5, 15.4, 5.5, 4, 2.5),
						rock(-1.5, 14.4, 8.5, 4, 2.2)
					),
				},
				{
					anchor = "Arm",
					mirror = true,
					name = "Basalt",
					color = BASALT,
					material = "Slate",
					boxes = rock(7.5, 17.4, -5.5, 3.5, 3.5),
				},
				{
					anchor = "Torso",
					name = "LavaCrack",
					color = LAVA,
					material = "Neon",
					boxes = {
						-- Sobre la joroba y el trapecio, en el lomo, en los costados del lomo y en los
						-- pectorales.
						{ 1, 19.05, -4.5, 2, 0.2, 0.5 },
						{ 1.8, 19.05, -3.5, 0.5, 0.2, 1.6 },
						{ -3.6, 18.05, -4.6, 0.6, 0.2, 2.6 },
						{ 3.8, 18.05, -5, 0.6, 0.2, 2.6 },
						{ 1.5, 17.05, 1.5, 0.6, 0.2, 3 },
						{ 6.05, 13, 1.5, 0.2, 4, 0.6, nil, nil, true },
						{ 6.05, 11.5, 2.5, 0.2, 0.6, 2, nil, nil, true },
						{ 2.6, 11.3, -10.15, 0.5, 2.2, 0.1 },
						{ -1.8, 10.6, -10.15, 1.6, 0.4, 0.1 },
					},
				},
				{
					anchor = "Arm",
					mirror = true,
					name = "LavaCrack",
					color = LAVA,
					material = "Neon",
					boxes = {
						{ 10.5, 11.5, -6, 0.2, 3, 0.5 },
						{ 10.5, 10.3, -5.2, 0.2, 0.5, 1.6 },
						{ 10.65, 5, -6.3, 0.2, 2, 0.5 },
					},
				},
				{
					anchor = "Leg",
					mirror = true,
					name = "LavaCrack",
					color = LAVA,
					material = "Neon",
					boxes = {
						{ 7.9, 6, 5.5, 0.2, 2.5, 0.5 },
						{ 5, 6.5, 9.65, 0.5, 2, 0.2 },
					},
				},
				{
					anchor = "Head",
					name = "LavaCrack",
					color = LAVA,
					material = "Neon",
					boxes = {
						{ 3.05, 17, -10, 0.2, 1.5, 0.4, nil, nil, true },
						{ 3.55, 13, -9, 0.2, 2, 0.4, nil, nil, true },
					},
				},
				{
					anchor = "Torso",
					name = "LavaCrack",
					color = LAVA,
					material = "Neon",
					phase = 3,
					boxes = {
						{ 6.05, 12, 5.5, 0.2, 3, 0.6, nil, nil, true },
						{ 1.5, 10.5, 10.05, 0.6, 4, 0.2 },
						{ -1, 11.5, 10.05, 2.5, 0.6, 0.2 },
					},
				},
				{
					anchor = "Arm",
					mirror = true,
					name = "LavaCrack",
					color = LAVA,
					material = "Neon",
					phase = 3,
					boxes = { { 8, 4.5, -9.35, 0.3, 2, 0.1 } },
				},
				{
					-- En la fase 3: grieta en la cresta y lava cayéndole por las comisuras al rugir.
					anchor = "Head",
					name = "LavaCrack",
					color = LAVA,
					material = "Neon",
					phase = 3,
					boxes = {
						{ 1.5, 19.05, -9.5, 0.6, 0.2, 2 },
						{ 1.2, 9.3, -16.1, 0.3, 0.9, 0.2, nil, nil, true },
						{ 1.2, 8.7, -16.1, 0.5, 0.3, 0.2, nil, nil, true },
					},
				},
			}),
		},
	},
}
