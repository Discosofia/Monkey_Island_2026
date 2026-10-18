--!strict
-- Mandril en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el formato de las cajas está
-- explicado en VoxelSpecs/Gorila. Referencia: docs/img/Mandril.jfif.
-- Robusto, alto de hombros y con la grupa más baja. Lomo y costados oliváceos en escalones, con vetas
-- más oscuras; cabeza, hombros, pecho y vientre gris oscuro, y patas pardas. Musculatura en bloques:
-- pectorales, omóplatos más claros que asoman sobre el lomo, bíceps, antebrazos y nudillos, muslos,
-- gemelos y unas ancas más oscuras que abultan por detrás. Cabeza con la coronilla en escalones;
-- hocico largo y anguloso con las crestas azules surcadas a los lados, la raya roja por encima que
-- acaba en una nariz roja de bloques, una banda blanca debajo y la barba amarilla. Orejas pequeñas
-- tapadas por el pelo, el trasero azul y rojo alrededor de una cola cortísima, un muñón de dos bloques.
-- Dos expresiones (faces): la normal, con la ceja recta y la boca cerrada, y la de furia al atacar y
-- al rugir, con las cejas en V sobre unos ojos ámbar entornados y la boca abierta enseñando los
-- colmillos largos, como hacen los mandriles para amenazar.
-- Tonos: "fur" (bodyColor) es el pardo de los costados y "skin" (faceColor) el rojo de la nariz.
-- Los pivotes son los del modelo redondo de antes (mandrill), para que valgan sus animaciones.

local Shapes = require(script.Parent.Shapes)

local OLIVE = Color3.fromRGB(132, 122, 42)
local OLIVE_LIGHT = Color3.fromRGB(150, 140, 52)
local OLIVE_DARK = Color3.fromRGB(108, 100, 36)
local GREY = Color3.fromRGB(78, 78, 82)
local GREY_LIGHT = Color3.fromRGB(100, 100, 104)
local GREY_DARK = Color3.fromRGB(52, 52, 56)
local MUSCLE = Color3.fromRGB(90, 90, 95)
local LIMB = Color3.fromRGB(98, 84, 78)
local LIMB_LIGHT = Color3.fromRGB(112, 97, 90)
local HAUNCH = Color3.fromRGB(88, 78, 64)
local KNUCKLE = Color3.fromRGB(70, 60, 56)
local BLUE = Color3.fromRGB(45, 150, 225)
local BLUE_DARK = Color3.fromRGB(30, 105, 170)
local RUMP_BLUE = Color3.fromRGB(85, 110, 200)
local RUMP_RED = Color3.fromRGB(200, 70, 90)
local WHITE = Color3.fromRGB(235, 235, 230)
local YELLOW = Color3.fromRGB(225, 185, 40)
local EYE = Color3.fromRGB(30, 22, 18)
local EYE_ANGRY = Color3.fromRGB(235, 150, 35)
local NOSTRIL = Color3.fromRGB(110, 25, 25)
local MOUTH = Color3.fromRGB(110, 22, 28)
local FANG = Color3.fromRGB(240, 232, 205)
local EAR = Color3.fromRGB(120, 92, 82)

local function join(...: { any }): { any }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

return {
	-- 0,1 studs por celda a escala 1; con su scale mide ~2 studs (GDD §8.2).
	unit = 0.1,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			pivot = { 0, 18, 2.5 },
			boxes = {
				{ 0, 17.5, 3.5, 12, 9, 22, "fur" },
				{ 0, 19.5, -3.5, 13.4, 9, 9, GREY, "Shoulders" },
				-- Lomo oliváceo: de los hombros baja en escalones igual de anchos hacia la grupa, y cubre
				-- la mitad de arriba de los costados.
				{ 0, 24.6, -3, 12.6, 1.4, 8.6, OLIVE, "Mantle" },
				{ 0, 22.8, 4, 12.6, 1.8, 7, OLIVE, "Back" },
				{ 0, 22.2, 10.5, 12.6, 1, 6, OLIVE, "Back" },
				{ 0, 20, 4, 12.6, 4, 21, OLIVE, "Flank" },
				{ 0, 21.6, -3.5, 13.8, 4.6, 9.2, OLIVE, "Flank" },
				-- Omóplatos algo más claros que asoman sobre el lomo, a los lados de la columna.
				{ 3.4, 25.6, -3.6, 3.8, 0.8, 5, OLIVE_LIGHT, "Scapula", true },
				-- El oliva acaba por los costados en puntas sobre el pardo (manchas sueltas en el costado
				-- parecían ventanas), y por encima lleva vetas largas más oscuras, como capas de pelo.
				{ 6.3, 17.4, -0.5, 0.4, 1.4, 2.4, OLIVE, "Fringe", true },
				{ 6.3, 17.1, 3.5, 0.4, 2, 2.4, OLIVE, "Fringe", true },
				{ 6.3, 17.5, 7.5, 0.4, 1.2, 2.4, OLIVE, "Fringe", true },
				{ 6.3, 17.2, 11.5, 0.4, 1.8, 2.4, OLIVE, "Fringe", true },
				{ 2.2, 23.75, 5, 1.6, 0.2, 7, OLIVE_DARK, "Streak" },
				{ -2.8, 23.75, 4, 1.6, 0.2, 5, OLIVE_DARK, "Streak" },
				{ -0.6, 22.75, 11, 1.6, 0.2, 5, OLIVE_DARK, "Streak" },
				{ 0, 25.35, -1, 1.4, 0.2, 5, OLIVE_DARK, "Streak" },
				-- Pecho gris con los pectorales marcados, y vientre gris.
				{ 0, 17, -8.3, 9, 6, 0.8, GREY, "Bib" },
				{ 2.2, 16.6, -8.85, 3.8, 3.2, 0.5, MUSCLE, "Pectoral", true },
				{ 0, 12.6, 3, 9, 1, 15, GREY, "Belly" },
				-- Ancas más oscuras que abultan por los lados hasta el final de la grupa (más cortas, parecían
				-- ventanas).
				{ 6.25, 15.5, 12, 0.5, 5, 6.4, HAUNCH, "Haunch", true },
				{ 0, 17.5, 14.8, 10, 7, 0.8, "fur", "Rump" },
				-- Trasero de colores bajo la cola: una mancha azul de esquinas en escalón con el rojo arriba,
				-- junto a la cola (un cuadrado dentro de otro parecía una diana, y en franjas, una bandera).
				{ 0, 16.2, 15.3, 5, 3.2, 0.4, RUMP_BLUE, "Rump" },
				{ 0, 16.2, 15.3, 3.4, 4.4, 0.4, RUMP_BLUE, "Rump" },
				{ 0, 17.7, 15.5, 2.4, 1.2, 0.4, RUMP_RED, "Rump" },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 21, -9 },
			boxes = {
				{ 0, 23, -13.5, 10, 9, 8, GREY },
				-- Coronilla en tres escalones que se estrechan hacia atrás.
				{ 0, 28.2, -12.8, 8.6, 1.4, 6.6, GREY, "Crown" },
				{ 0, 29.5, -12, 6.4, 1.2, 4.8, GREY_LIGHT, "Crown" },
				{ 0, 30.5, -11.4, 3.6, 0.8, 3, GREY_LIGHT, "Crown" },
				-- Orejas pequeñas, casi tapadas por el pelo, y mejillas grises que abultan tras las crestas.
				{ 5.2, 24.6, -10.8, 0.6, 1.6, 1.6, EAR, "Ear", true },
				{ 4.3, 21.2, -17.4, 1.6, 3.6, 1.2, GREY_LIGHT, "Cheek", true },
				-- Hocico: crestas azules a los lados, más bajas hacia la punta y surcadas a lo largo, y la
				-- raya roja encima. Cejas, ojos y boca van en las expresiones (faces, abajo).
				{ 1.6, 22, -19.5, 1.9, 4.4, 4, BLUE, "Ridge", true },
				{ 1.5, 21.6, -22.4, 1.7, 3.4, 2, BLUE, "Ridge", true },
				{ 2.6, 21, -19.5, 0.1, 0.3, 3.6, BLUE_DARK, "Groove", true },
				{ 2.6, 22.2, -19.5, 0.1, 0.3, 3.6, BLUE_DARK, "Groove", true },
				{ 2.6, 23.3, -19.5, 0.1, 0.3, 3.6, BLUE_DARK, "Groove", true },
				{ 2.4, 20.8, -22.4, 0.1, 0.3, 1.8, BLUE_DARK, "Groove", true },
				{ 2.4, 22, -22.4, 0.1, 0.3, 1.8, BLUE_DARK, "Groove", true },
				{ 0, 21.6, -20.8, 1.4, 3.6, 6.4, "skin", "Snout" },
				{ 0, 24.2, -20, 1.8, 1.4, 5, "skin", "NoseRidge" },
				{ 0, 23.4, -22.8, 1.8, 1, 1.4, "skin", "NoseRidge" },
				-- Nariz roja de bloques en la punta, con los orificios por delante.
				{ 0, 21.6, -24.1, 3.6, 2.4, 1.4, "skin", "Nose" },
				{ 0.7, 22, -24.85, 0.7, 0.6, 0.1, NOSTRIL, "Nostril", true },
				-- Barba amarilla en dos escalones, con puntas que cuelgan.
				{ 0, 18.1, -19.6, 5.4, 2.4, 5.4, YELLOW, "Beard" },
				{ 0, 16.6, -20.2, 3.6, 1.2, 3.4, YELLOW, "Beard" },
				{ 1.2, 15.6, -20.8, 1, 1, 1.2, YELLOW, "Beard", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 6.8, 16.5, -7.5 },
			boxes = join({
				{ 6.8, 11.5, -7.5, 3.6, 9, 3.6, GREY },
				{ 6.8, 16, -7.5, 4.2, 3.6, 4.2, GREY, "Deltoid" },
				{ 6.8, 18, -7.5, 3.4, 0.6, 3.4, GREY_LIGHT, "Deltoid" },
				-- Bíceps delante y por fuera, y un mechón en el codo.
				{ 6.8, 12.6, -9.55, 2.8, 3.6, 0.5, MUSCLE, "Biceps" },
				{ 8.85, 12.4, -7.6, 0.5, 3.4, 2.8, MUSCLE, "Biceps" },
				{ 6.8, 8.6, -5.5, 2.8, 2, 0.6, GREY, "Elbow" },
				{ 6.8, 4.5, -7.8, 3, 7, 3, LIMB, "Forearm" },
				{ 6.8, 6.4, -9.5, 2.6, 2.6, 0.5, LIMB_LIGHT, "Forearm" },
				{ 8.5, 6.2, -7.8, 0.4, 2.6, 2.6, LIMB_LIGHT, "Forearm" },
				{ 6.8, 0.6, -8.4, 3.6, 1.2, 3.6, LIMB, "Hand" },
				{ 6.8, 1.45, -9.4, 3.2, 0.5, 1.2, KNUCKLE, "Knuckle" },
			}, Shapes.fingers(6.8, -10.2, 3, 0.8, 1.4, LIMB)),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 5.5, 16.5, 10.5 },
			boxes = join({
				{ 5.6, 12.5, 10.5, 3.8, 8, 4.6, "fur" },
				-- Muslo por fuera y anca más oscura por detrás; gemelo bajo la corva.
				{ 7.65, 12.4, 10.2, 0.5, 5, 3.6, HAUNCH, "Thigh" },
				{ 5.6, 13.6, 13.05, 3.4, 4, 0.5, HAUNCH, "Glute" },
				{ 5.6, 5, 11.4, 3, 7.5, 3, LIMB, "Shin" },
				{ 5.6, 6.6, 13.15, 2.6, 2.8, 0.5, LIMB_LIGHT, "Calf" },
				{ 5.6, 0.6, 10, 3.6, 1.2, 5, LIMB, "Foot" },
			}, Shapes.fingers(5.6, 7.5, 3, 0.8, 1.4, LIMB)),
		},
		{
			name = "Tail",
			joint = "TailJoint",
			parent = "Torso",
			pivot = { 0, 19, 14 },
			-- Muñón cortísimo que asoma hacia arriba al final del lomo.
			boxes = {
				{ 0, 22, 15.2, 1.6, 2.4, 1.6, "fur" },
				{ 0, 23.6, 15.6, 1.2, 1, 1.2, "fur" },
			},
		},
	},
	-- Expresiones de la cara, soldadas a la cabeza (MonkeyModels.showFace). La normal es la de siempre;
	-- la de furia se ve mientras ataca (Attack) y mientras ruge para intimidar (Roar).
	faces = {
		{
			name = "Normal",
			boxes = {
				{ 0, 25.6, -17.9, 9.4, 1.4, 1, GREY_DARK, "Brow" },
				{ 3, 24.2, -17.6, 1.2, 0.7, 0.2, EYE, "Pupil", true },
				-- Boca cerrada: la banda blanca bajo la nariz.
				{ 0, 19.8, -21.8, 4.4, 1.2, 5, WHITE, "Lip" },
			},
		},
		{
			name = "Furia",
			actions = { "Attack", "Roar" },
			boxes = {
				-- Cejas en V, más bajas junto a la raya roja, sobre ojos ámbar entornados.
				{ 3.3, 25.9, -17.95, 3.4, 1, 1.1, GREY_DARK, "Brow", true },
				{ 1.1, 25.3, -18.05, 1.6, 1.2, 1.3, GREY_DARK, "Brow", true },
				{ 3, 24.1, -17.6, 1.3, 0.5, 0.2, EYE_ANGRY, "Pupil", true },
				-- Boca abierta bajo la nariz, con el labio blanco arriba: colmillos largos arriba y dos
				-- cortos abajo.
				{ 0, 20.35, -22, 4.4, 0.3, 4.8, WHITE, "Lip" },
				{ 0, 18.9, -22.2, 4.2, 2.6, 4.4, MOUTH, "Mouth" },
				{ 1.4, 19, -24.5, 0.6, 2.2, 0.4, FANG, "Fang", true },
				{ 0.6, 18, -24.5, 0.5, 0.8, 0.4, FANG, "Fang", true },
			},
		},
	},
}
