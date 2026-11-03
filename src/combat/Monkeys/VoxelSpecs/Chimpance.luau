--!strict
-- Chimpancé en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el formato de las cajas está
-- explicado en VoxelSpecs/Gorila. Referencia: docs/img/Chimpance.jfif.
-- Casi negro, apoyado en los nudillos: hombros altos con joroba y el lomo que baja hacia la grupa;
-- pecho y vientre gris oscuro; cabeza con la cara rosada, la ceja en saliente, el hocico salido con el
-- labio de abajo grueso y las orejas grandes y despegadas. Brazos largos y piernas cortas, con las
-- manos y los pies rosados.
-- Dos expresiones (faces): la normal y la de ataque, con las cejas en V y la boca abierta con los
-- colmillos. El Chimpancé Caudillo (bosses) pone músculo, lomo y barba canosos de viejo jefe, el
-- tocado de plumas y el collar de cuentas con la nuez, y cambia en cada fase del combate: pintura de
-- guerra en la 2 y, en la 3, el pelo erizado y el tocado roto (ver su entrada abajo).
-- Tonos: "fur" (bodyColor) es el negro y "skin" (faceColor) el rosado de la cara.
-- Los pivotes son los del modelo redondo de antes (chimpanzee), para que valgan sus animaciones.

local Shapes = require(script.Parent.Shapes)

local GREY = Color3.fromRGB(58, 56, 55)
local GREY_DARK = Color3.fromRGB(44, 42, 41)
local EYE = Color3.fromRGB(15, 10, 8)
local MOUTH_OPEN = Color3.fromRGB(120, 35, 40)
local LIP = Color3.fromRGB(150, 100, 90)
local BROW = Color3.fromRGB(135, 98, 82)
local ALPHA_BROW = Color3.fromRGB(38, 26, 22)

local function join(...: { any }): { any }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

-- Pluma en escalera: bloques de 1,7 celdas que salen de "from" con el ángulo "angle" (radianes, 0 hacia
-- arriba, + hacia +X) e inclinados hacia atrás; los dos últimos, más claros.
local function feather(from: Vector3, angle: number, length: number, color: Color3): { { any } }
	local tip = color:Lerp(Color3.new(1, 1, 1), 0.35)
	local direction = Vector3.new(math.sin(angle), math.cos(angle), 0.3).Unit
	local count = math.max(3, math.floor(length / 1.1))
	local boxes = {}
	for k = 0, count - 1 do
		local at = from + direction * (1 + k * 1.1)
		local x, y, z = math.round(at.X * 2) / 2, math.round(at.Y * 2) / 2, math.round(at.Z * 2) / 2
		table.insert(boxes, { x, y, z, 1.7, 1.7, 0.7, if k >= count - 2 then tip else color })
	end
	return boxes
end

-- Las tres caras del Caudillo, una por fase del combate: seria; furiosa (cejas en V, gruñido con los
-- colmillos y arrugas en el hocico); y rabiosa (ceño hundido, rugido y ojos encendidos). "more" añade
-- rasgos a la cara de cada fase (la pintura de guerra): { [fase] = { cajas } }.
local function phaseFaces(glow: Color3, more: { [number]: { any } }): { any }
	local faces = {
		{
			brow = { { 0, 28.7, -17.75, 7, 1.2, 1.2, BROW } },
			mouth = { { 0, 22.8, -19.95, 3, 0.3, 0.1, "mouth" } },
			eyes = { { 1.5, 27.5, -17.6, 1, 0.7, 0.2, nil, nil, true } },
		},
		{
			brow = {
				{ 0.9, 28.2, -17.85, 1.8, 1.1, 1.5, "dark", nil, true },
				{ 2.6, 28.8, -17.75, 1.8, 1.1, 1.3, "dark", nil, true },
			},
			mouth = {
				{ 0, 22.8, -19.95, 3, 0.45, 0.1, "mouth" },
				{ 0.9, 22.45, -20, 0.35, 0.5, 0.1, "teeth", nil, true },
				{ 0, 25.2, -19.95, 2.4, 0.2, 0.1, "dark" },
			},
			eyes = { { 1.5, 27.4, -17.6, 1.1, 0.45, 0.2, nil, nil, true } },
		},
		{
			brow = {
				{ 0.8, 28.1, -17.9, 1.6, 1.1, 1.6, "dark", nil, true },
				{ 2.2, 28.5, -17.8, 1.4, 1.1, 1.4, "dark", nil, true },
				{ 3.3, 29, -17.7, 0.8, 1.1, 1.2, "dark", nil, true },
			},
			mouth = {
				{ 0, 22.6, -19.95, 3.4, 1.6, 0.1, MOUTH_OPEN },
				{ 1.1, 23.1, -20, 0.45, 0.6, 0.1, "teeth", nil, true },
				{ 0.8, 22.05, -20, 0.4, 0.45, 0.1, "teeth", nil, true },
				{ 0, 25.2, -19.95, 2.6, 0.2, 0.1, "dark" },
				{ 0, 24.8, -19.95, 1.8, 0.2, 0.1, "dark" },
			},
			eyes = { { 1.5, 27.4, -17.6, 1.1, 0.5, 0.2, nil, nil, true } },
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

local FEATHERS = {
	Color3.fromRGB(35, 85, 190),
	Color3.fromRGB(230, 175, 45),
	Color3.fromRGB(200, 40, 35),
	Color3.fromRGB(230, 115, 35),
	Color3.fromRGB(60, 140, 210),
}
local BEADS = { Color3.fromRGB(235, 225, 200), Color3.fromRGB(60, 120, 200), Color3.fromRGB(200, 50, 40) }
local WOOD = Color3.fromRGB(150, 92, 50)
local WOOD_DARK = Color3.fromRGB(110, 68, 38)
local NUT = Color3.fromRGB(125, 80, 45)
local BEARD = Color3.fromRGB(190, 186, 178)

-- Tocado: abanico de plumas que sale de la banda y se abre hacia arriba y a los lados, "spread" grados
-- a cada lado. "broken" (fase 3, tras la embestida): faltan dos plumas, otras dos están partidas y la
-- del centro, doblada.
local function headdress(spread: number, broken: boolean?): { { any } }
	local boxes = {}
	local count = 9
	for index = 1, count do
		local angle = math.rad(-spread + (index - 1) * 2 * spread / (count - 1))
		local length = 13.5 - math.abs(angle) * 3.5
		local color = FEATHERS[(index - 1) % #FEATHERS + 1]
		if broken then
			if index == 3 or index == 8 then
				continue
			elseif index == 2 or index == 6 then
				length *= 0.45
			elseif index == 5 then
				angle += math.rad(100)
				length *= 0.7
			end
		end
		boxes = join(boxes, feather(Vector3.new(0, 30.5, -12), angle, length, color))
	end
	return boxes
end

-- Cuentas de colores en el frente de la banda.
local function beads(): { { any } }
	local boxes = {}
	for index = -2, 2 do
		table.insert(boxes, { index * 1.6, 30.1, -17.85, 1, 1, 0.6, BEADS[math.abs(index) % 3 + 1] })
	end
	return boxes
end

-- Pintura de guerra (fases 2 y 3, cuando llama a su tropa): banda roja sobre los ojos y rayas blancas
-- en las mejillas; en el cuerpo, una V blanca en el pecho y dos rayas rojas en cada brazo.
local WAR_RED = Color3.fromRGB(185, 35, 30)
local WAR_WHITE = Color3.fromRGB(235, 230, 220)
local FACE_PAINT = {
	{ 0, 27.45, -17.55, 6.4, 1.3, 0.1, WAR_RED },
	{ 2.55, 24.6, -17.55, 0.3, 2, 0.1, WAR_WHITE, nil, true },
	{ 3, 24.8, -17.55, 0.3, 1.6, 0.1, WAR_WHITE, nil, true },
}

local function warPaint(phase: number): { any }
	return {
		{
			anchor = "Torso",
			name = "WarPaint",
			phase = phase,
			color = WAR_WHITE,
			boxes = {
				{ 0, 16.2, -8.75, 1.2, 1, 0.1 },
				{ 1.1, 17, -8.75, 1.2, 1, 0.1, nil, nil, true },
				{ 2.2, 17.8, -8.75, 1.2, 1, 0.1, nil, nil, true },
				{ 3.3, 18.6, -8.75, 1.2, 1, 0.1, nil, nil, true },
			},
		},
		{
			anchor = "Arm",
			mirror = true,
			name = "WarPaint",
			phase = phase,
			color = WAR_RED,
			boxes = {
				{ 9.2, 16.3, -9.45, 3.6, 0.6, 0.1 },
				{ 9.2, 10.5, -9.45, 3.6, 0.6, 0.1 },
				{ 11.05, 16.3, -7.5, 0.1, 0.6, 3.8 },
				{ 11.05, 10.5, -7.5, 0.1, 0.6, 3.8 },
			},
		},
	}
end

-- Pelo erizado (fase 3, furioso: los chimpancés se erizan para parecer más grandes): mechones de tres
-- bloques gruesos que suben en escalón hacia atrás, negros, por la joroba, el lomo y la grupa. Púas
-- finas con la punta canosa parecían clavijas.
local function bristle(): { { any } }
	local boxes = {}
	local rows = {
		{ y = 29.7, z = -5, xs = { -3.2, 0, 3.2 } },
		{ y = 29.2, z = -1.5, xs = { -4.5, -1.5, 1.5, 4.5 } },
		{ y = 28.5, z = -5.5, xs = { -7, 7 } },
		{ y = 25.1, z = 3.5, xs = { -4, 0, 4 } },
		{ y = 25.1, z = 6.5, xs = { -2, 2 } },
		{ y = 21.1, z = 10.5, xs = { -3, 0, 3 } },
	}
	for _, row in rows do
		for _, x in row.xs do
			table.insert(boxes, { x, row.y + 0.9, row.z, 2.2, 1.8, 2.4, "fur" })
			table.insert(boxes, { x, row.y + 2.4, row.z + 0.8, 1.5, 1.6, 1.6, "fur" })
			table.insert(boxes, { x, row.y + 3.8, row.z + 1.5, 0.8, 1.4, 0.9, "shag" })
		end
	end
	-- Sobre los hombros, hacia fuera.
	for _, side in { -1, 1 } do
		table.insert(boxes, { side * 9.6, 27, -4.5, 1.4, 1.4, 1.4, "fur" })
		table.insert(boxes, { side * 10.6, 27.6, -4.2, 1, 0.7, 0.7, "fur" })
	end
	return boxes
end

-- Collar en U por delante del pecho, con cuentas de dos maderas y la nuez colgando del centro.
local function necklace(): { { any } }
	local boxes = {}
	local count = 7
	for index = 1, count do
		local t = (index - 1) / (count - 1) * 2 - 1
		local sag = 1 - t * t
		table.insert(boxes, {
			math.round(t * 10) / 2,
			math.round((24 - sag * 4) * 2) / 2,
			-9.1 - sag * 0.3,
			1.2,
			1.2,
			1.2,
			if index % 2 == 0 then WOOD_DARK else WOOD,
		})
	end
	table.insert(boxes, { 0, 18.1, -9.5, 1.8, 2.4, 1.4, NUT })
	table.insert(boxes, { 0, 19.7, -9.4, 0.6, 1, 0.6, WOOD_DARK })
	return boxes
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

-- Jefe tribal (Fase 20 Q3b): manto de leopardo sobre el hombro izquierdo, hombreras y brazaletes de hueso,
-- cinturón con trofeos, melena y lomo canosos, y un abanico de plumas grande en la espalda. Con malla, lo
-- fino (matas de pelo, rosetas del manto) se pinta en la textura.
local PELT = Color3.fromRGB(205, 150, 70)
local PELT_DARK = Color3.fromRGB(150, 100, 48)
local SPOT = Color3.fromRGB(48, 28, 18)
local LEATHER = Color3.fromRGB(104, 62, 36)
local LEATHER_DARK = Color3.fromRGB(70, 42, 28)
local BONE = Color3.fromRGB(232, 224, 200)
local BONE_DARK = Color3.fromRGB(176, 164, 136)
local BLOOD = Color3.fromRGB(150, 24, 24)
local FUR_TUFTS = { Color3.fromRGB(50, 46, 44), Color3.fromRGB(34, 31, 29), Color3.fromRGB(10, 9, 8) }

local TORSO_FACES = {
	{ "z", -8, -1, { -7, 14 }, { 7, 23 } },
	{ "x", 7.5, 1, { 14, -7.5 }, { 27, 1 } },
	{ "x", -7.5, -1, { 14, -7.5 }, { 27, 1 } },
	{ "z", 14, 1, { -5.5, 11 }, { 5.5, 20 } },
	{ "x", 6, 1, { 11, 8.5 }, { 20, 13.5 } },
	{ "x", -6, -1, { 11, 8.5 }, { 20, 13.5 } },
	{ "y", 25, 1, { 0, 2 }, { 6.5, 8 } },
}
local ARM_FACES = {
	{ "x", 11, 1, { 10, -9 }, { 17, -6 } },
	{ "z", -9.4, -1, { 8, 10 }, { 10.4, 17 } },
	{ "z", -9.5, -1, { 8, 3 }, { 10.4, 8 } },
}
local LEG_FACES = {
	{ "x", 8.1, 1, { 7.5, 8.5 }, { 11, 12.5 } },
	{ "z", 8, -1, { 4.5, 7.5 }, { 7.5, 11 } },
}
local HEAD_FACES = {
	{ "y", 31, 1, { -4, -16.5 }, { 4, -9.5 } },
	{ "x", 4.5, 1, { 23.5, -16 }, { 29.5, -10 } },
	{ "x", -4.5, -1, { 23.5, -16 }, { 29.5, -10 } },
	{ "z", -9, 1, { -4, 23.5 }, { 4, 29.5 } },
}
local FUR_BOSS = {
	Torso = mottle(61, 70, FUR_TUFTS, TORSO_FACES, 0.3),
	Arm = mottle(63, 40, FUR_TUFTS, ARM_FACES, 0.3),
	Leg = mottle(67, 16, FUR_TUFTS, LEG_FACES, 0.3),
	Head = mottle(71, 20, FUR_TUFTS, HEAD_FACES, 0.25),
}

-- Manto de leopardo: cubre el hombro izquierdo, cuelga por delante, baja por la espalda y la grupa y
-- termina en una cola con anillos. Las rosetas son manchas oscuras de 0,2 de grueso.
local PELT_MID = Color3.fromRGB(176, 116, 38)
local CREAM = Color3.fromRGB(242, 218, 168)

-- Rosetas de leopardo: anillo oscuro de cuatro barras con el centro ocre, repartidas al azar por las caras
-- de "mottle". Con relieve de 0,3 (lo fino de la malla, pintado en la textura).
local function rosettes(seed: number, count: number, faces: { { any } }): { any }
	local rng = Random.new(seed)
	local total, areas = 0, {}
	for index, face in faces do
		total += (face[5][1] - face[4][1]) * (face[5][2] - face[4][2])
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
		local function put(da: number, db: number, sa: number, sb: number, thick: number, color: Color3)
			local depth = plane + out * thick / 2
			local pa, pb = a + da, b + db
			if axis == "x" then
				table.insert(boxes, { depth, pa, pb, thick, sa, sb, color })
			elseif axis == "y" then
				table.insert(boxes, { pa, depth, pb, sa, thick, sb, color })
			else
				table.insert(boxes, { pa, pb, depth, sa, sb, thick, color })
			end
		end
		put(0, 0, 0.9, 0.7, 0.2, PELT_MID)
		put(0, 0.6, 1.7, 0.35, 0.3, SPOT)
		put(0, -0.6, 1.7, 0.35, 0.3, SPOT)
		put(-0.7, 0, 0.35, 1.2, 0.3, SPOT)
		put(0.7, 0, 0.35, 1.2, 0.3, SPOT)
	end
	return boxes
end

local function pelt(): { { any } }
	local boxes = {
		-- Hombro izquierdo, costado y solapa delantera con el borde crema y las garras.
		{ -7.5, 28.6, -4.5, 4, 1.2, 8.5, PELT, "Pelt" },
		{ -3.5, 29.9, -3.5, 5, 1.2, 6.5, PELT, "Pelt" },
		{ -9.6, 25.5, -4.5, 1.2, 5.5, 8.5, PELT, "Pelt" },
		{ -7.2, 25.5, -8.9, 3, 5, 0.9, PELT, "Pelt" },
		{ -7.2, 22.9, -8.9, 3, 0.8, 1, CREAM, "Hem" },
		{ -8.2, 22.3, -9.5, 0.6, 1.2, 0.5, BONE, "Claw" },
		{ -6.2, 22.3, -9.5, 0.6, 1.2, 0.5, BONE, "Claw" },
		-- Cuelga por el costado izquierdo.
		{ -8.2, 19, -1.5, 1.2, 8, 7, PELT, "Pelt" },
		{ -8.2, 15.2, -1.5, 1.3, 0.8, 7.2, CREAM, "Hem" },
		-- Espalda, grupa y la caída por detrás.
		{ -3, 25.6, 4.5, 9, 1.2, 8, PELT, "Pelt" },
		{ -3, 22.5, 9, 9, 5.5, 1, PELT, "Pelt" },
		{ -3.5, 21.5, 11.3, 6, 1, 6.8, PELT, "Pelt" },
		{ -3.5, 16, 14.4, 6, 12, 0.8, PELT, "Pelt" },
		{ -3.5, 10.3, 14.4, 6.2, 0.7, 1, CREAM, "Hem" },
		-- Cola con anillos.
		{ -3.5, 15, 15.4, 1.8, 11, 1.2, PELT_MID, "Tail" },
		{ -3.5, 18.8, 15.4, 1.9, 0.9, 1.3, SPOT, "Tail" },
		{ -3.5, 16.6, 15.4, 1.9, 0.9, 1.3, SPOT, "Tail" },
		{ -3.5, 14.4, 15.4, 1.9, 0.9, 1.3, SPOT, "Tail" },
		{ -3.5, 12.2, 15.4, 1.9, 0.9, 1.3, SPOT, "Tail" },
		{ -3.5, 9.9, 15.4, 1.9, 1.4, 1.3, SPOT, "Tail" },
	}
	return join(
		boxes,
		rosettes(81, 70, {
			{ "y", 29.2, 1, { -9, -6 }, { -6, -1.5 } },
			{ "y", 30.5, 1, { -5, -5.5 }, { -2, -1 } },
			{ "x", -10.2, -1, { 24, -8 }, { 27, -1.5 } },
			{ "z", -9.35, -1, { -8, 23.8 }, { -6.4, 27.2 } },
			{ "x", -8.85, -1, { 16.5, -4 }, { 21.5, 1 } },
			{ "y", 26.2, 1, { -6.5, 1 }, { 0.5, 8 } },
			{ "z", 9.5, 1, { -6.5, 20.5 }, { 0.5, 24.5 } },
			{ "y", 22, 1, { -6, 8.5 }, { -1, 13.5 } },
			{ "z", 14.8, 1, { -6, 11 }, { -1, 21 } },
		})
	)
end

-- Bandolera de cuero en diagonal desde el hombro izquierdo hasta la cadera derecha.
local function strap(): { { any } }
	local boxes = {}
	for index = 0, 6 do
		local y = 27 - index * 2.1
		table.insert(
			boxes,
			{ -7 + index * 2.1, y, if y >= 23 then -8.8 else -8.3, 1.8, 1.8, 0.6, LEATHER_DARK, "Strap" }
		)
	end
	table.insert(boxes, { -4.8, 24.4, -9.15, 1.1, 1.1, 0.3, BONE, "Toggle" })
	return boxes
end

-- Cinturón con trofeos: cráneo, colmillos, cuentas y plumas colgando a cada lado (simétricos).
local function belt(): { { any } }
	return {
		{ 0, 13.7, -8.4, 15.4, 1.4, 0.8, LEATHER, "Belt" },
		{ 7.9, 13.7, -3, 0.8, 1.4, 10.4, LEATHER, "Belt", true },
		{ 7.4, 13.7, 5.2, 0.8, 1.4, 7.4, LEATHER, "Belt", true },
		{ 0, 13.7, -8.9, 3, 1.8, 0.4, BONE, "Buckle" },
		{ 0, 13.7, -9.15, 1.2, 0.8, 0.2, SPOT, "Buckle" },
		-- Cráneo (con las cuencas vacías) y mandíbula.
		{ 8.1, 12.6, -3, 0.3, 1, 0.3, LEATHER_DARK, "Cord", true },
		{ 8.3, 11.4, -3, 1.2, 2.4, 2.4, BONE, "Skull", true },
		{ 8.95, 11.7, -3.7, 0.15, 0.7, 0.7, SPOT, "Socket", true },
		{ 8.95, 11.7, -2.3, 0.15, 0.7, 0.7, SPOT, "Socket", true },
		{ 8.3, 10, -3, 1, 0.8, 1.8, BONE_DARK, "Jaw", true },
		-- Colmillos.
		{ 8.1, 11.7, 0, 0.8, 2.2, 0.8, BONE, "Fang", true },
		{ 8.1, 10.3, 0, 0.5, 0.8, 0.5, BONE_DARK, "Fang", true },
		-- Cuentas.
		{ 8.1, 12, 3, 0.9, 0.9, 0.9, BEADS[1], "Bead", true },
		{ 8.1, 10.9, 3, 0.9, 0.9, 0.9, BEADS[2], "Bead", true },
		{ 8.1, 9.8, 3, 0.9, 0.9, 0.9, BEADS[3], "Bead", true },
		-- Manojo de plumas.
		{ 8.1, 11.2, 6, 0.5, 3.4, 1, FEATHERS[3], "Plume", true },
		{ 8.1, 10.9, 6.9, 0.5, 2.8, 1, FEATHERS[1], "Plume", true },
	}
end

-- Melena y lomo canosos: mechones en escalón por el cuello, el lomo y los costados de la grupa.
local function mane(): { { any } }
	return {
		{ 0, 29.9, -3.5, 10, 1.2, 5.5, "silver", "Mane" },
		{ 0, 31, -2.8, 7, 1, 4, "silver", "Mane" },
		{ 3.7, 25.7, 5, 6.6, 0.9, 7.2, "silver", "Mane" },
		{ 3.8, 26.5, 5, 4, 0.8, 5, "silver", "Mane" },
		{ 7.3, 21.5, 5, 0.8, 7, 5, "silver", "Mane" },
		{ 6.3, 16, 11, 0.6, 8, 5, "silver", "Mane" },
		{ -6.4, 16, 11, 0.6, 8, 5, "silver", "Mane" },
		{ 0, 22.4, 14.3, 7, 0.6, 0.1, "silver", "Mane" },
	}
end

-- Hombreras de cuero con púas de hueso (lado derecho; salen en los dos brazos) y brazaletes.
local function armTribal(): { { any } }
	return {
		{ 9.2, 21.8, -7, 5.4, 1.6, 5.6, LEATHER, "Pad" },
		{ 11.6, 20.2, -7, 1.2, 3.4, 5.4, LEATHER_DARK, "Pad" },
		{ 12.3, 20.8, -8.5, 0.3, 0.7, 0.7, BONE, "Rivet" },
		{ 12.3, 20.8, -5.5, 0.3, 0.7, 0.7, BONE, "Rivet" },
		{ 12.3, 19.2, -7, 0.3, 0.7, 0.7, BONE, "Rivet" },
		{ 12.4, 22.2, -7, 1.4, 1, 1, BONE, "Spike" },
		{ 13.4, 22.9, -7, 0.9, 0.7, 0.7, BONE, "Spike" },
		{ 9.2, 8.2, -7.8, 4, 1, 4, BONE, "Bracelet" },
		{ 9.2, 6.7, -7.8, 3.9, 0.8, 3.9, BONE_DARK, "Bracelet" },
		{ 11.4, 7.5, -7.8, 0.8, 0.8, 0.8, BONE, "Stud" },
		{ 9.2, 1.9, -8.4, 3.9, 0.9, 4.2, LEATHER_DARK, "Wrap" },
	}
end

-- Abanico de plumas de la espalda, sobre una placa de cuero: abierto en las fases 1 y 2, roto en la 3.
local function backFan(spread: number, broken: boolean?): { { any } }
	local boxes = {
		{ 0, 23.5, 9.3, 6.5, 5, 1.8, LEATHER },
		{ 0, 23.5, 10.3, 3, 3, 0.4, BONE },
		{ 0, 23.5, 10.55, 1.2, 1.2, 0.2, SPOT },
	}
	local count = 11
	for index = 1, count do
		local angle = math.rad(-spread + (index - 1) * 2 * spread / (count - 1))
		local length = 15 - math.abs(angle) * 3
		local color = FEATHERS[(index - 1) % #FEATHERS + 1]
		if broken then
			if index == 3 or index == 9 then
				continue
			elseif index == 2 or index == 7 or index == 10 then
				length *= 0.4
			elseif index == 6 then
				angle += math.rad(80)
				length *= 0.7
			end
		end
		boxes = join(boxes, feather(Vector3.new(0, 23.5, 10.4), angle, length, color))
	end
	return boxes
end

-- Fase 3: cicatrices abiertas en el pecho y el manto hecho jirones.
local function wounds(): { { any } }
	local boxes = {}
	for slash = 0, 2 do
		for index = 0, 3 do
			table.insert(boxes, { 3 + slash * 1.5 + index * 0.9, 24.8 - index * 1.4, -8.45, 0.9, 1.1, 0.2, BLOOD })
		end
	end
	return boxes
end

local function rags(): { { any } }
	local HOLE = Color3.fromRGB(22, 14, 10)
	return {
		-- Jirones que cuelgan del borde de la grupa y del costado, más largos y de otro tono que el manto.
		{ -6, 8, 14.4, 1.1, 4.4, 0.9, PELT_DARK },
		{ -4.8, 6.8, 14.4, 1.2, 6.8, 0.9, PELT_DARK },
		{ -3.4, 8.2, 14.6, 1, 4, 0.9, PELT_DARK },
		{ -2.1, 6.4, 14.4, 1.1, 7.6, 0.9, PELT_DARK },
		{ -0.9, 8.4, 14.4, 1, 3.6, 0.9, PELT_DARK },
		{ -8.2, 12.6, -4.5, 1.3, 3.8, 1.1, PELT_DARK },
		{ -8.2, 11.4, -2, 1.3, 6.2, 1.1, PELT_DARK },
		{ -8.2, 12.8, 0.5, 1.3, 3.4, 1.1, PELT_DARK },
		-- Desgarrones: agujeros oscuros con la sangre al borde.
		{ -5.2, 18.4, 14.85, 2, 2.4, 0.2, HOLE },
		{ -2, 13.6, 14.85, 2.2, 1.8, 0.2, HOLE },
		{ -5, 12.2, 14.85, 1.6, 1.4, 0.2, HOLE },
		{ -5.2, 16.9, 14.9, 2.2, 0.35, 0.15, BLOOD },
		{ -2, 12.6, 14.9, 2.4, 0.35, 0.15, BLOOD },
		{ -7.6, 24.2, -9.4, 1.6, 2.2, 0.2, HOLE },
		{ -7.6, 22.8, -9.45, 1.8, 0.35, 0.15, BLOOD },
	}
end

return {
	-- 0,1 studs por celda a escala 1; con su scale mide ~2,7 studs (GDD §8.2).
	unit = 0.1,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			pivot = { 0, 18.5, 3.5 },
			boxes = {
				-- Pecho alto delante: con el tronco horizontal, de lado parecía una mesa.
				{ 0, 20, -3, 15, 14, 10, "fur" },
				-- Hombros altos con joroba, y el lomo que baja en escalones hasta la grupa.
				{ 0, 25.5, -4.5, 18, 5, 8, "fur", "Shoulders" },
				{ 0, 28.6, -3.5, 12, 1.2, 6, "fur", "Hump" },
				{ 0, 18.5, 5, 14, 13, 7, "fur", "Back" },
				{ 0, 15.5, 11, 12, 11, 6, "fur", "Rump" },
				{ 0, 13.5, 2, 11, 3, 10, "fur", "Belly" },
				-- Pecho gris en dos escalones, más ancho arriba, y vientre gris.
				{ 0, 22, -8.35, 10, 7, 0.7, GREY, "Bib" },
				{ 0, 16.5, -8.35, 7, 3, 0.7, GREY, "Bib" },
				{ 0, 12.05, 1, 7, 0.1, 8, GREY_DARK, "Bib" },
				-- Paletillas algo más claras, que asoman sobre los hombros (el gris de la referencia).
				{ 4.2, 28.05, -4.5, 5, 0.1, 6, GREY_DARK, "Blade", true },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 23, -8.5 },
			boxes = {
				{ 0, 26.5, -13, 9, 9, 8, "fur" },
				{ 0, 31.5, -12.5, 7, 1.2, 6, "fur", "Cap" },
				-- Cara rosada; la ceja, los ojos y la boca van en las expresiones (faces, abajo).
				{ 0, 26, -17.2, 6.4, 6, 0.6, "skin", "Face" },
				-- Hocico salido y el labio de abajo, grueso y algo más oscuro.
				{ 0, 23.8, -18.6, 4.6, 3.4, 2.6, "skin", "Muzzle" },
				{ 0, 22.1, -18.8, 4, 1.2, 2, LIP, "Lip" },
				{ 0.6, 24.9, -19.95, 0.6, 0.5, 0.1, "dark", "Nostril", true },
				-- Orejas grandes y despegadas.
				{ 4.9, 27, -12.5, 1, 3.2, 2.8, "skin", "Ear", true },
				{ 5.45, 27, -12.5, 0.1, 2, 1.6, "dark", "Ear", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 9.2, 17.4, -7.5 },
			-- Largo, apoyado en los nudillos.
			boxes = join({
				{ 9.2, 13, -7.5, 3.6, 9, 3.8, "fur" },
				{ 9.2, 19, -7, 4.4, 4, 4.6, "fur", "Deltoid" },
				{ 9.2, 5.5, -7.8, 3.4, 8, 3.4, "fur", "Forearm" },
				{ 9.2, 1, -8.4, 3.6, 2, 4, "paws", "Hand" },
			}, Shapes.fingers(9.2, -10.4, 3, 0.8, 1.2, "paws")),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 6, 11, 11 },
			boxes = join({
				{ 6, 9, 10.5, 4.2, 5, 5, "fur" },
				-- Rodilla adelantada en un escalón: recta, la pata parecía un zanco.
				{ 6, 6.5, 9.2, 3.8, 2.6, 4, "fur", "Knee" },
				{ 6, 3.5, 10.3, 3.4, 5, 3.4, "fur", "Shin" },
				{ 6, 0.75, 10, 3.6, 1.5, 5.5, "paws", "Foot" },
			}, Shapes.fingers(6, 7.25, 3, 0.8, 1.2, "paws")),
		},
	},
	-- Expresiones de la cara, soldadas a la cabeza (MonkeyModels.showFace). La de ataque se ve mientras
	-- ataca (Attack) y si ruge (Roar).
	faces = {
		{
			name = "Normal",
			boxes = {
				{ 0, 28.7, -17.75, 7, 1.2, 1.2, BROW, "Brow" },
				{ 1.5, 27.5, -17.6, 1, 0.7, 0.2, EYE, "Pupil", true },
				{ 0, 22.8, -19.95, 3, 0.3, 0.1, "mouth", "Mouth" },
			},
		},
		{
			name = "Ataque",
			actions = { "Attack", "Roar" },
			boxes = {
				{ 0.9, 28.2, -17.85, 1.8, 1.1, 1.5, "dark", "Brow", true },
				{ 2.6, 28.8, -17.75, 1.8, 1.1, 1.3, "dark", "Brow", true },
				{ 1.5, 27.4, -17.6, 1.1, 0.5, 0.2, EYE, "Pupil", true },
				{ 0, 22.6, -19.95, 3.4, 1.6, 0.1, MOUTH_OPEN, "Mouth" },
				{ 1.1, 23.1, -20, 0.45, 0.6, 0.1, "teeth", "Fang", true },
				{ 0.8, 22.05, -20, 0.4, 0.45, 0.1, "teeth", "Fang", true },
				{ 0, 25.2, -19.95, 2.4, 0.2, 0.1, "dark", "Wrinkle" },
			},
		},
	},
	-- El alfa: macho dominante maduro, negro intenso con el lomo canoso (encima, no en la cara de atrás
	-- de la grupa: ahí parecía una ventana), barba canosa, cara más oscura y más músculo; la
	-- cara normal, algo más agresiva: cejas en V y ojos entornados.
	alpha = {
		tones = {
			fur = Color3.fromRGB(20, 19, 18),
			silver = Color3.fromRGB(112, 110, 107), -- canoso; más claro, desde atrás parecían tapas blancas
			skin = Color3.fromRGB(105, 72, 60), -- con (130, 92, 76) no se veía más oscura que la normal
		},
		add = {
			Torso = {
				{ 0, 29.4, -3.5, 9, 0.6, 4.5, "fur", "Trapezius" },
				{ 2.6, 22.3, -8.85, 4.4, 3, 0.4, GREY, "Pectoral", true },
				-- Lomo y grupa canosos de lado a lado, con el escalón entre ellos: desde atrás se lee como
				-- una sola zona canosa (unas tiras finas encima parecían tapas).
				{ 0, 25.2, 5, 14.2, 0.4, 7.2, "silver", "Saddle" },
				{ 0, 23, 8.6, 14.2, 4.4, 0.4, "silver", "Saddle" },
				{ 0, 21.2, 11, 12.2, 0.4, 6.2, "silver", "Saddle" },
			},
			Arm = {
				{ 11.2, 13.5, -7.5, 0.6, 4, 3, "fur", "Biceps" },
				{ 9.2, 13.5, -9.6, 3, 4, 0.6, "fur", "Biceps" },
			},
			-- Mechón canoso en la barbilla (más grande y claro parecía una servilleta).
			Head = {
				{ 0, 21.2, -18.4, 3, 1.2, 1.6, "silver", "Beard" },
			},
		},
		-- Las cejas en V de la de ataque, con la boca cerrada (las puntas de los colmillos, en el
		-- chimpancé, parecían dientes de conejo).
		faces = {
			Normal = {
				-- Casi negras: en el tono "dark" de la cara salían pardo claro y el ceño no se leía.
				{ 0.9, 28.2, -17.85, 1.8, 1.1, 1.5, ALPHA_BROW, "Brow", true },
				{ 2.6, 28.8, -17.75, 1.8, 1.1, 1.3, ALPHA_BROW, "Brow", true },
				{ 1.5, 27.4, -17.6, 1.1, 0.5, 0.2, EYE, "Pupil", true },
				{ 0, 22.8, -19.95, 3.2, 0.3, 0.1, "mouth", "Mouth" },
			},
		},
	},
	bosses = {
		-- Chimpancé Caudillo: viejo jefe con el lomo y la barba canosos, más músculo, el tocado de plumas
		-- sobre una banda de madera con cuentas y el collar con la nuez. Cada fase cambia la cara y algo
		-- del cuerpo: 1, sereno; 2, pintura de guerra y el abanico abierto al llamar a su tropa; 3, furioso,
		-- con el pelo erizado, el tocado roto, rugido y ojos encendidos.
		ChimpanceCaudillo = {
			add = {
				Torso = join({
					{ 0, 29.4, -3.5, 9, 0.6, 4.5, "fur", "Trapezius" },
					{ 2.6, 22.3, -8.85, 4.4, 3, 0.4, GREY, "Pectoral", true },
					{ 0, 25.05, 5, 12, 0.1, 6, "silver", "Saddle" },
					{ 0, 21.05, 11, 10, 0.1, 5, "silver", "Saddle" },
				}, FUR_BOSS.Torso, mane(), pelt(), strap(), belt()),
				Arm = join({
					{ 11.2, 13.5, -7.5, 0.6, 4, 3, "fur", "Biceps" },
					{ 9.2, 13.5, -9.6, 3, 4, 0.6, "fur", "Biceps" },
					{ 11.05, 6.5, -7.8, 0.5, 3, 3, "shag", "Forearm" },
					{ 9.2, 2.25, -10.5, 3.4, 0.5, 0.8, "paws", "Knuckle" },
				}, FUR_BOSS.Arm, armTribal()),
				Leg = join(FUR_BOSS.Leg, {
					{ 6, 6, 9.2, 4.2, 0.8, 4.4, LEATHER, "Strap" },
					{ 6, 6, 6.9, 0.8, 0.8, 0.4, BONE, "Stud" },
				}),
				Head = join({
					{ 0, 21.1, -18.2, 3.6, 1.8, 2, BEARD, "Beard" },
					{ 4.8, 23.8, -14.4, 0.8, 3.6, 3.4, "silver", "Sideburn", true },
					{ 0, 25.5, -8.3, 8.6, 6, 1.4, "silver", "Ruff" },
				}, FUR_BOSS.Head),
			},
			groups = join(
				phaseFaces(Color3.fromRGB(255, 120, 40), {
					[2] = FACE_PAINT,
					[3] = FACE_PAINT,
				}),
				warPaint(2),
				warPaint(3),
				{
					{
						anchor = "Head",
						name = "Headband",
						material = "Wood",
						color = WOOD,
						boxes = {
							{ 0, 30.1, -17.3, 9.4, 1.4, 0.6 },
							{ 0, 30.1, -8.7, 9.4, 1.4, 0.6 },
							{ 4.8, 30.1, -13, 0.6, 1.4, 9.2, nil, nil, true },
						},
					},
					{ anchor = "Head", name = "Beads", boxes = beads() },
					-- Fase 1: el abanico en calma; fase 2, al llamar a la tropa, más abierto; fase 3, roto.
					{ anchor = "Head", name = "Feather", phase = 1, boxes = headdress(75) },
					{ anchor = "Head", name = "Feather", phase = 2, boxes = headdress(88) },
					{ anchor = "Head", name = "Feather", phase = 3, boxes = headdress(88, true) },
					{ anchor = "Torso", name = "Necklace", material = "Wood", color = WOOD, boxes = necklace() },
					{
						-- Punto débil (MonkeyModels, Bosses.weakPoints): medallón dorado sobre el collar.
						anchor = "Torso",
						name = "Medallion",
						color = Color3.fromRGB(255, 200, 40),
						material = "Neon",
						boxes = {
							{ 0, 22.8, -9.4, 2.4, 2.4, 0.8 },
							{ 0, 22.8, -9.85, 1.2, 1.2, 0.2, Color3.fromRGB(255, 240, 170) },
						},
					},
					{ anchor = "Torso", name = "Bristle", phase = 3, boxes = bristle() },
					-- Abanico de la espalda: en calma, abierto al llamar a la tropa y roto.
					{ anchor = "Torso", name = "BackFan", phase = 1, boxes = backFan(70) },
					{ anchor = "Torso", name = "BackFan", phase = 2, boxes = backFan(85) },
					{ anchor = "Torso", name = "BackFan", phase = 3, boxes = backFan(85, true) },
					{ anchor = "Torso", name = "Wounds", phase = 3, boxes = wounds() },
					{ anchor = "Torso", name = "Rags", phase = 3, boxes = rags() },
				}
			),
		},
	},
}
