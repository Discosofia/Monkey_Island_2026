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

local function join(...: { { number } }): { { number } }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

local RUBY = Color3.fromRGB(205, 25, 45)
local LAVA = Color3.fromRGB(255, 110, 30)

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
	-- Cada grupo: bloques de un mismo material pegados a "anchor" (con "mirror", a los dos lados) y
	-- unidos en una pieza. Caja: { x, y, z, ancho, alto, fondo, simétrica? }.
	bosses = {
		-- Gorila Albino: racimos de cristales de rubí en los hombros (el derecho más grande), el lomo
		-- y los brazos, y el corazón de neón en el pecho rodeado de cristales.
		GorilaAlbino = {
			{
				anchor = "Torso",
				name = "Crystal",
				color = RUBY,
				material = "Glass",
				transparency = 0.3,
				boxes = join(
					crystal(3, 16.5, -5, 1.3),
					crystal(4.2, 16.5, -2.5, 1),
					crystal(1.8, 16.5, -3, 0.8),
					crystal(-3, 16.5, -4.5, 1.1),
					crystal(-1.6, 16.5, -2, 0.8),
					crystal(1.5, 15.5, 2, 0.9),
					crystal(-2, 14.5, 5.5, 0.7),
					crystal(-2.8, 11.8, -9, 0.7, true),
					crystal(0, 8.6, -9, 0.6, true)
				),
			},
			{
				anchor = "Arm",
				mirror = true,
				name = "Crystal",
				color = RUBY,
				material = "Glass",
				transparency = 0.3,
				boxes = crystal(8.5, 16.5, -5, 0.9),
			},
			{
				anchor = "Torso",
				name = "CrystalCore",
				color = Color3.fromRGB(255, 70, 70),
				material = "Neon",
				boxes = { { -1.5, 10, -9.6, 2, 2, 0.8 } },
			},
		},
		-- Gorila de Ceniza: grietas de lava (filas de celdas de neón al ras) en los hombros, el lomo,
		-- los costados, el pecho y los brazos.
		GorilaDeCeniza = {
			{
				anchor = "Torso",
				name = "LavaCrack",
				color = LAVA,
				material = "Neon",
				boxes = {
					{ 2, 17.05, -6, 4, 0.2, 0.6 },
					{ 3.7, 17.05, -4.2, 0.6, 0.2, 3 },
					{ -3, 17.05, -3, 3, 0.2, 0.6 },
					{ -1.8, 17.05, -4.8, 0.6, 0.2, 3 },
					{ 1, 16.05, 1.5, 0.6, 0.2, 4 },
					{ -0.5, 16.05, 2.8, 3, 0.2, 0.6 },
					{ 8.05, 14, -5, 0.2, 4, 0.6, true },
					{ 8.05, 12.3, -4, 0.2, 0.6, 2.5, true },
					{ 1.5, 10.5, -9.35, 0.6, 4, 0.2 },
					{ 0.5, 9, -9.35, 2.5, 0.6, 0.2 },
				},
			},
			{
				anchor = "Arm",
				mirror = true,
				name = "LavaCrack",
				color = LAVA,
				material = "Neon",
				boxes = {
					{ 9.8, 11, -6, 0.2, 5, 0.6 },
					{ 9.8, 9, -5.2, 0.2, 0.6, 2 },
					{ 10.05, 4.5, -6.5, 0.2, 3, 0.6 },
				},
			},
		},
	},
}
