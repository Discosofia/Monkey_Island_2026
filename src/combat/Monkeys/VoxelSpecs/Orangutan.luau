--!strict
-- Orangután en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el formato de las cajas está
-- explicado en VoxelSpecs/Gorila. Referencia: docs/img/Orangutan.jfif.
-- Naranja rojizo, corpulento y casi erguido: hombros muy anchos con el pelo en capas que bajan por el
-- lomo, barriga más oscura y vetas de pelo a lo largo del cuerpo. La cabeza lleva las almohadillas de
-- las mejillas (un disco pardo oscuro, más ancho que la cabeza) alrededor de la cara, el hocico salido
-- y el saco de la garganta. Brazos larguísimos con las manos en gancho y piernas cortas.
-- Dos expresiones (faces): la normal y la de ataque, con las cejas en V y la boca abierta con los
-- colmillos. El Orangután del Manglar (bosses) pone la cara con más detalle, más músculo, musgo en el
-- lomo, la cabeza y los brazos y una liana con hojas cruzada en el pecho, y cambia en cada fase del
-- combate: barro en la 2 y, en la 3, el saco de la garganta hinchado, raíces del manglar en el lomo y
-- hongos luminosos (ver su entrada abajo).
-- Tonos: "fur" (bodyColor) es el naranja, "skin" (faceColor) el pardo de la cara, "shade" el naranja
-- oscuro de las vetas y "deep" el pardo oscuro de las almohadillas.
-- Los pivotes son los del modelo redondo de antes (orangutan), para que valgan sus animaciones.

local Shapes = require(script.Parent.Shapes)

local EYE = Color3.fromRGB(15, 10, 8)
local MOUTH_OPEN = Color3.fromRGB(110, 35, 35)
local ALPHA_BROW = Color3.fromRGB(58, 38, 30) -- el ceño del alfa; en "dark" no se leía sobre la cara

local function join(...: { any }): { any }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

-- Las tres caras del Orangután del Manglar, una por fase del combate: seria; furiosa (cejas en V y
-- gruñido con los colmillos); y rabiosa (ceño hundido, rugido y ojos encendidos). "more" añade rasgos a
-- la cara de cada fase (el saco de la garganta que se hincha): { [fase] = { cajas } }.
local function phaseFaces(glow: Color3, more: { [number]: { any } }): { any }
	local faces = {
		{
			brow = { { 0, 31.4, -14.95, 5.6, 0.8, 0.4, "deep" } },
			mouth = { { 0, 25.1, -16.65, 3.6, 0.3, 0.1, "mouth" } },
			eyes = { { 1.6, 30.1, -14.9, 1, 0.8, 0.2, nil, nil, true } },
		},
		{
			brow = {
				{ 0.8, 30.8, -15.1, 1.6, 1, 0.6, "dark", nil, true },
				{ 2.3, 31.4, -15, 1.6, 1, 0.5, "dark", nil, true },
			},
			mouth = {
				{ 0, 25.1, -16.65, 3.6, 0.45, 0.1, "mouth" },
				{ 1, 24.75, -16.7, 0.4, 0.5, 0.1, "teeth", nil, true },
			},
			eyes = { { 1.6, 30, -14.9, 1.1, 0.5, 0.2, nil, nil, true } },
		},
		{
			brow = {
				{ 0.7, 30.7, -15.15, 1.4, 1, 0.7, "dark", nil, true },
				{ 2, 31.1, -15.05, 1.2, 1, 0.6, "dark", nil, true },
				{ 3, 31.6, -15, 0.8, 1, 0.5, "dark", nil, true },
			},
			mouth = {
				{ 0, 24.8, -16.65, 3.8, 1.8, 0.1, MOUTH_OPEN },
				{ 1.2, 25.4, -16.7, 0.5, 0.7, 0.1, "teeth", nil, true },
				{ 0.9, 24.15, -16.7, 0.45, 0.5, 0.1, "teeth", nil, true },
			},
			eyes = { { 1.6, 30, -14.9, 1.1, 0.55, 0.2, nil, nil, true } },
			glow = true,
		},
	}
	local groups = {}
	for phase, face in faces do
		table.insert(groups, {
			anchor = "Head",
			name = "Expression",
			phase = phase,
			boxes = join(face.brow, face.mouth, more[phase] or {}),
		})
		table.insert(groups, {
			anchor = "Head",
			name = "Eye",
			phase = phase,
			color = if face.glow then glow else EYE,
			material = if face.glow then "Neon" else nil,
			boxes = face.eyes,
		})
	end
	return groups
end

local LIP = Color3.fromRGB(118, 90, 76)
local SAC = Color3.fromRGB(108, 80, 64) -- el saco de la garganta, algo más claro que la cara
local MOSS = Color3.fromRGB(85, 120, 50)
local MOSS_DARK = Color3.fromRGB(62, 95, 38)
local VINE = Color3.fromRGB(70, 110, 40)
local LEAF = Color3.fromRGB(60, 140, 60)

-- Liana en escalera del hombro derecho a la cadera izquierda, por delante del pecho, con hojas.
local function vine(): { { any } }
	local boxes = {}
	local from, to = Vector3.new(8, 27, -7.9), Vector3.new(-7, 14.5, -7.9)
	local count = 14
	for k = 0, count - 1 do
		local at = from:Lerp(to, k / (count - 1))
		table.insert(boxes, { math.round(at.X * 2) / 2, math.round(at.Y * 2) / 2, at.Z, 1.4, 1.4, 0.8, VINE })
	end
	for _, leaf in { { 4.5, 24.5, -1 }, { 0, 21, 1 }, { -4, 17.5, -1 } } do
		table.insert(boxes, { leaf[1] + leaf[3] * 1.2, leaf[2] + 0.6, -8.5, 2.2, 1.2, 0.3, LEAF })
	end
	return boxes
end

-- Cara del jefe con más detalle (va dentro de la unión de la cabeza): almohadillas con volumen y
-- pliegues, cuencas de los ojos hundidas, puente de la nariz, labio y barbilla claros, barba rojiza
-- bajo el saco de la garganta y pelo largo en la coronilla y la nuca.
local MANGLAR_HEAD = {
	{ 6.3, 29, -14.5, 2.4, 6.5, 0.6, "deep", "Pad", true },
	{ 0, 34.6, -14.5, 5, 1.2, 0.6, "deep", "Pad" },
	{ 6.3, 31.2, -14.85, 1.8, 0.2, 0.1, "dark", "Fold", true },
	{ 6.5, 27.4, -14.85, 1.6, 0.2, 0.1, "dark", "Fold", true },
	{ 1.6, 30.1, -14.85, 1.9, 1.5, 0.1, "deep", "Socket", true },
	{ 0, 28.6, -15, 1.6, 1.8, 0.4, "skin", "Nose" },
	{ 0, 26, -16.65, 4.6, 0.6, 0.1, LIP, "Lip" },
	{ 0, 23.7, -15.6, 4.4, 1.4, 2, LIP, "Chin" },
	{ 0, 21.4, -14, 5, 3, 1.6, "shade", "Beard" },
	{ 0, 19.4, -13.7, 3.6, 1.6, 1.4, "shade", "Beard" },
	{ 0, 18.2, -13.5, 2, 1.2, 1.2, "shade", "Beard" },
	{ 0, 35.1, -11, 7, 1.6, 3.5, "shag", "Hair" },
	{ 0, 31.5, -4.7, 7, 5, 0.6, "shade", "Hair" },
}

-- El saco de la garganta: medio hinchado en la fase 2 y del todo en la 3 (la llamada larga de los
-- orangutanes machos), tapando la barba.
local MANGLAR_FACE = {
	[2] = {
		{ 0, 22.2, -12.4, 8, 4.6, 6.6, SAC },
		{ 0, 28.8, -15.25, 1.4, 0.2, 0.1, "dark" },
		{ 0, 28.2, -15.25, 1.2, 0.2, 0.1, "dark" },
	},
	[3] = {
		-- Redondo en escalones y sin rayas: un solo bloque ancho parecía un cajón delante del pecho, y
		-- una raya oscura encima, una segunda boca.
		{ 0, 21.6, -12.6, 8, 5.6, 7, SAC },
		{ 0, 21.6, -12.6, 6.4, 7, 6.8, SAC },
		{ 0, 21.6, -12.6, 4.4, 7.8, 6.4, SAC },
		{ 0, 28.8, -15.25, 1.4, 0.2, 0.1, "dark" },
		{ 0, 28.2, -15.25, 1.2, 0.2, 0.1, "dark" },
	},
}

-- Barro del manglar (fases 2 y 3, cuando pisotea): costras en los antebrazos y las manos, las patas
-- y la barriga, con salpicaduras más oscuras encima.
local MUD = Color3.fromRGB(105, 80, 55)
local MUD_WET = Color3.fromRGB(80, 60, 42)

local function mud(phase: number): { any }
	return {
		{
			anchor = "Arm",
			mirror = true,
			name = "Mud",
			material = "Mud",
			color = MUD,
			phase = phase,
			boxes = {
				{ 10.5, 4, -7.2, 4.2, 3.4, 4.2 },
				{ 9.6, 6.3, -9.35, 0.9, 1.2, 0.3, MUD_WET },
				{ 11.4, 6, -9.35, 0.8, 0.8, 0.3 },
				{ 13, 6.2, -6.2, 0.3, 1, 1, MUD_WET },
			},
		},
		{
			anchor = "Leg",
			mirror = true,
			name = "Mud",
			material = "Mud",
			color = MUD,
			phase = phase,
			boxes = {
				{ 6.2, 3, 10, 4, 3, 4.2 },
				{ 6.2, 1.6, 8, 4.2, 0.3, 4.4 },
				{ 6.6, 5, 7.95, 1, 0.9, 0.3, MUD_WET },
			},
		},
		{
			anchor = "Torso",
			name = "Mud",
			material = "Mud",
			color = MUD,
			phase = phase,
			boxes = {
				{ -2, 15, -7.9, 3, 1.6, 0.3 },
				{ 2.5, 14.3, -7.9, 2, 1, 0.3, MUD_WET },
				{ -2.6, 13.9, -7.9, 0.8, 1.2, 0.3 },
			},
		},
	}
end

-- Hongos luminosos (fase 3) sobre el musgo: pie y sombrero de tamaño "s" sobre la superficie "y".
local FUNGUS_STEM = Color3.fromRGB(120, 210, 95)
local FUNGUS_CAP = Color3.fromRGB(185, 255, 130)

local function mushrooms(list: { { number } }): { { any } }
	local boxes = {}
	for _, m in list do
		local x, y, z, size = m[1], m[2], m[3], m[4]
		table.insert(boxes, { x, y + size * 0.5, z, 0.4 * size, size, 0.4 * size, FUNGUS_STEM })
		table.insert(boxes, { x, y + size * 1.2, z, 1.4 * size, 0.4 * size, 1.4 * size, FUNGUS_CAP })
	end
	return boxes
end

-- Raíces del manglar (fase 3) que le brotan del lomo y se arquean hacia la grupa.
local ROOT = Color3.fromRGB(125, 90, 60)
local function root(points: { Vector3 }, width: number): { { any } }
	return Shapes.tail(points, width, 0.6, 1.2, function()
		return ROOT
	end)
end

-- Moteado: copia del de Gorila (ver su explicación). Cada cara es { eje, plano, hacia fuera, desde, hasta };
-- con eje "x" las coordenadas son y, z; con "y", x, z; y con "z", x, y.
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

-- Señor del pantano (Fase 20 Q3c): cortina de pelo largo por la espalda y los brazos, musgo y lianas con flores,
-- conchas y cangrejos en los hombros y el lomo, y el manglar que crece con las fases (raíces cada vez más
-- grandes y, en la 3, flores abiertas). Con malla, lo fino (matas de pelo, musgo, hojas) va a la textura.
local FUR_TUFTS = { Color3.fromRGB(188, 86, 34), Color3.fromRGB(132, 50, 18), Color3.fromRGB(92, 34, 12) }
local MOSS_LIGHT = Color3.fromRGB(122, 165, 72)
local SHELL = Color3.fromRGB(238, 214, 190)
local SHELL_DARK = Color3.fromRGB(200, 150, 140)
local CRAB = Color3.fromRGB(86, 108, 128)
local CRAB_CLAW = Color3.fromRGB(226, 168, 120)
local PINK = Color3.fromRGB(236, 120, 150)
local PETAL = Color3.fromRGB(250, 232, 240)
local POLLEN = Color3.fromRGB(250, 205, 60)

local TORSO_FACES = {
	{ "y", 29.5, 1, { -10, -6.5 }, { 10, 2 } },
	{ "z", -7.5, -1, { -10, 24 }, { 10, 28.5 } },
	{ "x", 11, 1, { 24, -6.5 }, { 29, 2 } },
	{ "x", -11, -1, { 24, -6.5 }, { 29, 2 } },
	{ "y", 28.7, 1, { -7.5, 2.2 }, { 7.5, 5.8 } },
	{ "y", 25.8, 1, { -7, 5.2 }, { 7, 8.8 } },
}
local ARM_FACES = {
	{ "x", 12.4, 1, { 11, -8.5 }, { 20, -5.5 } },
	{ "z", -9, -1, { 9, 11 }, { 12, 20 } },
	{ "z", -9, -1, { 9.2, 3 }, { 11.8, 10 } },
}
local LEG_FACES = {
	{ "x", 8.4, 1, { 7, 8 }, { 12.5, 12 } },
	{ "z", 7.5, -1, { 4.6, 7 }, { 7.8, 12.5 } },
}
local HEAD_FACES = {
	{ "y", 33.5, 1, { -3.5, -11.5 }, { 3.5, -6.5 } },
	{ "x", 4.5, 1, { 26, -12 }, { 33, -6 } },
	{ "x", -4.5, -1, { 26, -12 }, { 33, -6 } },
	{ "z", -5, 1, { -4, 26 }, { 4, 33 } },
}
local SWAMP_FUR = {
	Torso = mottle(101, 70, FUR_TUFTS, TORSO_FACES, 0.3),
	Arm = mottle(103, 40, FUR_TUFTS, ARM_FACES, 0.3),
	Leg = mottle(107, 16, FUR_TUFTS, LEG_FACES, 0.3),
	Head = mottle(109, 20, FUR_TUFTS, HEAD_FACES, 0.25),
}
-- Musgo pintado sobre el lomo y los hombros (lo grueso, con material, sigue en los grupos "Moss").
local SWAMP_MOSS = mottle(113, 60, { MOSS, MOSS_DARK, MOSS_LIGHT }, {
	{ "y", 29.5, 1, { -9, -6 }, { 9, 1.5 } },
	{ "y", 28.7, 1, { -7, 2.5 }, { 7, 5.5 } },
	{ "y", 25.8, 1, { -6.5, 5.5 }, { 6.5, 8.5 } },
	{ "x", 11, 1, { 25, -6 }, { 29, 1.5 } },
	{ "x", -11, -1, { 25, -6 }, { 29, 1.5 } },
}, 0.3)

-- Cortina de pelo largo y desigual: dos tramos de mechones por detrás de la espalda y la grupa, con lianas finas
-- y flores en rosa pegadas al tramo de arriba.
local function curtain(): { { any } }
	local tones = { FUR_TUFTS[1], FUR_TUFTS[2], FUR_TUFTS[3] }
	local rng = Random.new(7)
	local boxes = {}
	for index = -3, 3 do
		local length = rng:NextNumber(4, 11)
		table.insert(boxes, {
			index * 2.3,
			25.5 - length / 2,
			10.7 + (index % 2) * 0.5,
			2.4,
			length,
			1.2,
			tones[(index + 3) % 3 + 1],
			"Strand",
		})
	end
	for index = -2, 2 do
		local length = rng:NextNumber(4, 9.5)
		table.insert(boxes, {
			index * 2.4,
			19.5 - length / 2,
			12.7 + (index % 2) * 0.6,
			2.5,
			length,
			1.2,
			tones[(index + 3) % 3 + 1],
			"Strand",
		})
	end
	for _, x in { -5.5, -1.5, 3, 6.5 } do
		table.insert(boxes, { x, 22.8, 11.45, 0.7, 5, 0.3, VINE, "Liana" })
		table.insert(boxes, { x + 1, 23.6, 11.5, 1.8, 1.2, 0.3, LEAF, "Leaf" })
		table.insert(boxes, { x - 1, 21.4, 11.5, 1.8, 1.2, 0.3, LEAF, "Leaf" })
		table.insert(boxes, { x, 20.6, 11.7, 0.9, 0.9, 0.5, PINK, "Bud" })
	end
	return boxes
end

-- Concha de caracola (tres bloques que se estrechan) y cangrejo con las pinzas abiertas.
local function shell(x: number, y: number, z: number, size: number): { { any } }
	return {
		{ x, y + size * 0.4, z, size * 1.6, size * 0.8, size * 1.6, SHELL, "Shell" },
		{ x, y + size * 1.1, z, size * 1.1, size * 0.6, size * 1.1, SHELL_DARK, "Shell" },
		{ x, y + size * 1.6, z, size * 0.6, size * 0.5, size * 0.6, SHELL, "Shell" },
	}
end

local function crab(x: number, y: number, z: number): { { any } }
	return {
		{ x, y + 0.7, z, 2.8, 1.4, 2.2, CRAB, "Crab" },
		{ x - 1.9, y + 0.9, z - 1.4, 1.1, 0.9, 1.1, CRAB_CLAW, "Crab" },
		{ x + 1.9, y + 0.9, z - 1.4, 1.1, 0.9, 1.1, CRAB_CLAW, "Crab" },
		{ x - 0.8, y + 1.6, z - 0.8, 0.5, 0.6, 0.5, EYE, "Crab" },
		{ x + 0.8, y + 1.6, z - 0.8, 0.5, 0.6, 0.5, EYE, "Crab" },
	}
end

local SWAMP_DECOR = join(
	shell(7, 29.5, -3.5, 2),
	shell(-8.5, 29.5, -1, 1.7),
	shell(5, 25.8, 7.5, 1.6),
	crab(-4.5, 28.7, 4),
	crab(5.5, 25.8, 7),
	crab(-6, 29.5, -4.5)
)
local SWAMP_ARM_DECOR = join({
	{ 12.9, 14, -4.4, 0.8, 9, 1.6, "shag", "Hair" },
	{ 12.9, 8.5, -5.8, 0.8, 7, 1.4, "shade", "Hair" },
	{ 12.9, 17.5, -5.2, 0.8, 6, 1.4, "shag", "Hair" },
}, shell(12.4, 18, -7.4, 1.3), crab(10.5, 20.5, -6.5))

-- Raíces del manglar que le brotan del lomo: unas pocas y cortas en la fase 1, más y más altas en la 2 y las
-- grandes de siempre más dos sobre los hombros en la 3.
local function rootGroups(): { any }
	local function group(phase: number, roots: { any }): any
		local boxes = {}
		for _, spec in roots do
			boxes = join(boxes, root(spec[1], spec[2]))
		end
		return { anchor = "Torso", name = "Root", material = "Wood", color = ROOT, phase = phase, boxes = boxes }
	end
	local function V(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z)
	end
	local small = {
		{ { V(3, 30.5, -1), V(3.5, 33, 0), V(4, 35, 2.5), V(4.5, 34, 5) }, 1.2 },
		{ { V(-3, 30, 0), V(-3.5, 32.5, 1.5), V(-4, 34, 4), V(-4.5, 33, 6.5) }, 1.2 },
	}
	local medium = join(small, {
		{ { V(7, 29.8, -2), V(8, 33.5, -1), V(8.5, 36, 2), V(8.5, 35, 5) }, 1.6 },
		{ { V(-7, 29.8, -1), V(-8, 33, 0), V(-8.5, 35.5, 3), V(-8.5, 34, 6) }, 1.6 },
		{ { V(0, 30.5, -3), V(0, 34.5, -2), V(0.5, 36, 1) }, 1.4 },
	})
	local large = join({
		{ { V(4, 30.5, -2), V(4.5, 35.5, 0), V(5, 38, 3.5), V(5.5, 36, 7), V(6, 26, 9) }, 2.2 },
		{ { V(-3.5, 29.5, 1.5), V(-4, 34, 3), V(-4.5, 36, 6), V(-5, 33, 8.5), V(-5.5, 25, 9.5) }, 2 },
		{ { V(0, 30.5, -3.5), V(0, 34, -2), V(0.5, 35.5, 1), V(1, 33, 3.5), V(1, 28.5, 4.5) }, 1.6 },
		{ { V(10, 29.5, -1), V(11, 34, 0), V(11, 38, 3), V(10.5, 36, 7) }, 2 },
		{ { V(-10, 29.5, 0), V(-11, 34, 1), V(-11, 37.5, 4), V(-10.5, 35, 8) }, 2 },
	}, {})
	return { group(1, small), group(2, medium), group(3, large) }
end

-- Flores abiertas (fase 3): cuatro pétalos blancos y el centro dorado, sobre los hombros y la joroba.
local function flowers(): { { any } }
	local boxes = {}
	for _, at in { { 7.5, 30.9, -4.5 }, { -7.5, 30.9, -3.5 }, { 0, 31.8, -3.5 }, { 3.5, 29.9, 4 }, { -3, 28.4, 6 } } do
		local x, y, z = at[1], at[2], at[3]
		table.insert(boxes, { x - 1.2, y, z, 1.4, 0.5, 1, PETAL })
		table.insert(boxes, { x + 1.2, y, z, 1.4, 0.5, 1, PETAL })
		table.insert(boxes, { x, y, z - 1.2, 1, 0.5, 1.4, PETAL })
		table.insert(boxes, { x, y, z + 1.2, 1, 0.5, 1.4, PETAL })
		table.insert(boxes, { x, y + 0.1, z, 1, 0.7, 1, POLLEN })
	end
	return boxes
end

return {
	-- 0,1 studs por celda a escala 1; con su scale mide ~3 studs (GDD §8.2).
	unit = 0.1,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			pivot = { 0, 19.5, 3 },
			boxes = {
				-- Pecho alto y corto de fondo: casi erguido, como en la referencia.
				{ 0, 21, -1.5, 17, 15, 11, "fur" },
				-- Hombros muy anchos y el pelo del lomo en capas que bajan hacia la grupa.
				{ 0, 26.5, -2.5, 22, 6, 10, "fur", "Shoulders" },
				{ 0, 30.1, -1.5, 15, 1.2, 7, "shag", "Hump" },
				{ 0, 27.5, 4, 16, 2.4, 4, "shag", "Layer" },
				{ 0, 24.5, 7, 15.4, 2.6, 4, "fur", "Layer" },
				{ 0, 18.5, 7, 15, 11, 6, "fur", "Back" },
				{ 0, 15.5, 10.5, 13, 7, 3, "fur", "Rump" },
				-- Pecho del naranja del cuerpo y barriga más oscura.
				{ 0, 17.5, -7.4, 11, 8, 0.8, "shade", "Belly" },
				{ 0, 14, -6.2, 9, 1, 3, "shade", "Belly" },
				-- Vetas de pelo oscuro a lo largo de los costados y del lomo.
				{ 8.55, 20, -3, 0.1, 9, 1.2, "shade", "Streak", true },
				{ 8.55, 19, 1.5, 0.1, 7, 1, "shade", "Streak", true },
				{ 7.55, 17, 7, 0.1, 7, 1.2, "shade", "Streak", true },
				{ 3, 25.85, 7, 1.2, 0.1, 3, "shade", "Streak", true },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 24, -7 },
			boxes = {
				{ 0, 29.5, -9, 9, 8, 8, "fur" },
				{ 0, 34.1, -8.5, 6, 1.2, 6, "fur", "Crown" },
				{ 0, 35.1, -8.5, 3, 0.8, 3, "shag", "Tuft" },
				-- Almohadillas de las mejillas: un disco de esquinas en escalón, más ancho que la cabeza.
				{ 0, 29, -13.6, 15, 8, 1.4, "deep", "Flange" },
				{ 0, 29, -13.6, 12, 11, 1.4, "deep", "Flange" },
				{ 0, 29, -13.6, 9, 12.4, 1.4, "deep", "Flange" },
				-- Cara parda, hocico salido y el saco de la garganta bajo la barbilla. La ceja, los ojos y
				-- la boca van en las expresiones (faces, abajo).
				{ 0, 29, -14.5, 7, 7, 0.6, "skin", "Face" },
				{ 0, 26.1, -15.6, 5, 3.4, 2, "skin", "Muzzle" },
				{ 0.7, 27.5, -16.65, 0.6, 0.5, 0.1, "dark", "Nostril", true },
				{ 0, 22.9, -12.2, 8, 3.6, 5, "deep", "ThroatSac" },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 10, 21.6, -7 },
			-- Larguísimo, con flecos de pelo por fuera y la mano en gancho, apoyada en los nudillos.
			boxes = join({
				{ 10.5, 15.5, -7, 3.8, 10, 4, "fur" },
				{ 10.5, 22, -6.5, 4.6, 4.4, 5, "fur", "Deltoid" },
				{ 10.5, 6.5, -7.2, 3.6, 9, 3.6, "fur", "Forearm" },
				{ 12.5, 14, -6.6, 0.6, 9, 2.6, "shade", "Fringe" },
				{ 12.4, 6.5, -6.8, 0.6, 6, 2.4, "shade", "Fringe" },
				{ 10.5, 1.5, -7.8, 3.6, 3, 4, "paws", "Hand" },
				{ 10.5, 1.6, -10.2, 3.4, 1.2, 1, "paws", "Knuckle" },
			}, Shapes.fingers(10.5, -10.2, 3, 0.9, 1.2, "paws")),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 6.2, 10.9, 10 },
			-- Corta.
			boxes = join({
				{ 6.2, 9.5, 10, 4.4, 7, 5, "fur" },
				{ 6.2, 4, 10, 3.6, 5, 3.8, "fur", "Shin" },
				{ 6.2, 0.75, 9, 4, 1.5, 6, "paws", "Foot" },
			}, Shapes.fingers(6.2, 6, 3, 0.9, 1.3, "paws")),
		},
	},
	-- Expresiones de la cara, soldadas a la cabeza (MonkeyModels.showFace). La de ataque se ve mientras
	-- ataca (Attack) y si ruge (Roar).
	faces = {
		{
			name = "Normal",
			boxes = {
				{ 0, 31.4, -14.95, 5.6, 0.8, 0.4, "deep", "Brow" },
				{ 1.6, 30.1, -14.9, 1, 0.8, 0.2, EYE, "Pupil", true },
				{ 0, 25.1, -16.65, 3.6, 0.3, 0.1, "mouth", "Mouth" },
			},
		},
		{
			name = "Ataque",
			actions = { "Attack", "Roar" },
			boxes = {
				{ 0.8, 30.8, -15.1, 1.6, 1, 0.6, "dark", "Brow", true },
				{ 2.3, 31.4, -15, 1.6, 1, 0.5, "dark", "Brow", true },
				{ 1.6, 30, -14.9, 1.1, 0.5, 0.2, EYE, "Pupil", true },
				{ 0, 24.8, -16.65, 3.8, 1.8, 0.1, MOUTH_OPEN, "Mouth" },
				{ 1.2, 25.4, -16.7, 0.5, 0.7, 0.1, "teeth", "Fang", true },
				{ 0.9, 24.15, -16.7, 0.45, 0.5, 0.1, "teeth", "Fang", true },
			},
		},
	},
	-- El alfa: macho de mejillas anchas, con el pelo largo castaño granate (en vez de naranja), las
	-- almohadillas más anchas, barba bajo el saco de la garganta y melenas largas colgando de los
	-- brazos; la cara normal, algo más agresiva: las cejas en V de la de ataque, casi negras, y los
	-- ojos entornados, con la boca cerrada (las puntas de los colmillos parecían dientes de conejo).
	alpha = {
		tones = {
			fur = Color3.fromRGB(120, 42, 22),
			shag = Color3.fromRGB(140, 52, 26),
			shade = Color3.fromRGB(88, 28, 15),
		},
		add = {
			Head = {
				{ 0, 29, -13.6, 17.4, 6.4, 1.4, "deep", "Flange" },
				-- Del color del pelo: más clara, parecía un babero.
				{ 0, 20.4, -13, 5, 1.6, 3, "fur", "Beard" },
				{ 0, 19.1, -13.4, 2.6, 1.2, 2, "fur", "Beard" },
			},
			Arm = {
				{ 12.9, 11.5, -6.6, 0.6, 13, 2.8, "shag", "Hair" },
				{ 10.5, 12.5, -4.9, 2.6, 10, 0.6, "shag", "Hair" },
			},
		},
		faces = {
			Normal = {
				-- Finas: con el alto de las de ataque parecían unas gafas de sol.
				{ 0.8, 30.85, -15.1, 1.6, 0.65, 0.6, ALPHA_BROW, "Brow", true },
				{ 2.3, 31.35, -15, 1.6, 0.65, 0.5, ALPHA_BROW, "Brow", true },
				{ 1.6, 30, -14.9, 1.1, 0.5, 0.2, EYE, "Pupil", true },
				{ 0, 25.1, -16.65, 3.8, 0.3, 0.1, "mouth", "Mouth" },
			},
		},
	},
	bosses = {
		-- Orangután del Manglar: más músculo, la cara con más detalle, musgo en el lomo, la cabeza y
		-- colgando de los brazos (como el de las ramas del manglar) y una liana con hojas cruzada en el
		-- pecho. Cada fase cambia la cara y algo del cuerpo: 1, sereno; 2, al pisotear, barro y el saco de
		-- la garganta medio hinchado; 3, la llamada larga con el saco hinchado del todo, ojos encendidos,
		-- raíces del manglar arqueadas en el lomo y hongos luminosos en el musgo.
		OrangutanDelManglar = {
			add = {
				Torso = join({
					{ 2.8, 24, -7.5, 5, 3.5, 0.6, "fur", "Pectoral", true },
				}, SWAMP_FUR.Torso, SWAMP_MOSS, curtain(), SWAMP_DECOR),
				Arm = join({
					{ 12.6, 7.5, -7.2, 0.6, 4, 3, "fur", "Forearm" },
					{ 10.5, 7.5, -9.2, 3, 4, 0.6, "fur", "Forearm" },
					{ 10.5, 16, -9.2, 3, 4, 0.6, "fur", "Biceps" },
				}, SWAMP_FUR.Arm, SWAMP_ARM_DECOR),
				Leg = SWAMP_FUR.Leg,
				Head = join(MANGLAR_HEAD, SWAMP_FUR.Head),
			},
			groups = join(phaseFaces(Color3.fromRGB(150, 230, 90), MANGLAR_FACE), mud(2), mud(3), rootGroups(), {
				{ anchor = "Torso", name = "Flower", phase = 3, boxes = flowers() },
				{
					anchor = "Torso",
					name = "Moss",
					material = "Grass",
					color = MOSS,
					boxes = {
						{ 4, 30.6, -2, 6, 1, 5 },
						{ 5.5, 31.2, -2.5, 3, 0.6, 3, MOSS_DARK },
						{ -3.5, 29.1, 3.5, 5, 1, 4 },
						{ -2, 26.1, 7, 4, 0.8, 3, MOSS_DARK },
					},
				},
				{
					anchor = "Head",
					name = "Moss",
					material = "Grass",
					color = MOSS,
					boxes = {
						{ -1.5, 35.5, -8, 3.5, 0.8, 3.5 },
						{ 1.5, 36.1, -11, 2.4, 0.5, 2.4, MOSS_DARK },
					},
				},
				{
					anchor = "Arm",
					mirror = true,
					name = "Moss",
					material = "Grass",
					color = MOSS,
					boxes = {
						{ 11, 24.7, -6, 4, 0.8, 4 },
						{ 12.9, 15, -8, 0.6, 6, 1.4, MOSS_DARK },
						{ 12.9, 11.5, -8, 0.6, 2, 1.4 },
					},
				},
				{ anchor = "Torso", name = "Vine", boxes = vine() },
				{
					-- Punto débil (MonkeyModels, Bosses.weakPoints): gema azul incrustada en la bolsa de la
					-- garganta. Sobresale de la bolsa en las tres fases (la de la fase 3 llega a z = -16,1).
					anchor = "Head",
					name = "ThroatGem",
					color = Color3.fromRGB(70, 150, 255),
					material = "Neon",
					boxes = {
						{ 0, 21.6, -15.5, 2.6, 2.6, 2.6 },
						{ 0, 21.6, -16.85, 1.4, 1.4, 0.3, Color3.fromRGB(190, 225, 255) },
					},
				},
				{
					anchor = "Torso",
					name = "Leaf",
					color = LEAF,
					phase = 3,
					boxes = {
						{ 5, 39.4, 3.5, 2.6, 0.5, 2 },
						{ -4.5, 37.3, 6, 2.2, 0.5, 1.8 },
						{ 0.5, 36.6, 1, 1.8, 0.5, 1.4 },
					},
				},
				{
					anchor = "Torso",
					name = "Fungus",
					material = "Neon",
					phase = 3,
					boxes = mushrooms({
						{ 2.5, 31.1, -1, 2 },
						{ 6, 31.5, -3, 1.6 },
						{ 1.5, 31.1, -4, 1.3 },
						{ -5, 29.6, 3, 2 },
						{ -2.5, 29.6, 4.5, 1.3 },
						{ -2, 26.5, 7.5, 1.6 },
					}),
				},
				{
					anchor = "Head",
					name = "Fungus",
					material = "Neon",
					phase = 3,
					boxes = mushrooms({ { -1.5, 35.9, -8, 1.6 }, { 1.8, 36.35, -11, 1.2 } }),
				},
				{
					anchor = "Arm",
					mirror = true,
					name = "Fungus",
					material = "Neon",
					phase = 3,
					boxes = mushrooms({ { 11.5, 25.1, -5.5, 1.5 } }),
				},
			}),
		},
	},
}
