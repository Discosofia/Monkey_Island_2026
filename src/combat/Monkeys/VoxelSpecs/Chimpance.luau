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
				Torso = {
					{ 0, 29.4, -3.5, 9, 0.6, 4.5, "fur", "Trapezius" },
					{ 2.6, 22.3, -8.85, 4.4, 3, 0.4, GREY, "Pectoral", true },
					{ 0, 25.05, 5, 12, 0.1, 6, "silver", "Saddle" },
					{ 0, 21.05, 11, 10, 0.1, 5, "silver", "Saddle" },
				},
				Arm = {
					{ 11.2, 13.5, -7.5, 0.6, 4, 3, "fur", "Biceps" },
					{ 9.2, 13.5, -9.6, 3, 4, 0.6, "fur", "Biceps" },
					{ 11.05, 6.5, -7.8, 0.5, 3, 3, "shag", "Forearm" },
					{ 9.2, 2.25, -10.5, 3.4, 0.5, 0.8, "paws", "Knuckle" },
				},
				Head = {
					{ 0, 21.1, -18.2, 3.6, 1.8, 2, BEARD, "Beard" },
				},
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
				}
			),
		},
	},
}
