--!strict
-- Babuino en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el formato de las cajas está explicado
-- en VoxelSpecs/Gorila. Referencia: docs/img/Babuino.jfif.
-- Gris oliva, pesado y con el lomo muy inclinado: hombros altos y la grupa baja. Melena parda en capas
-- sobre el cuello y los hombros, que cae por los costados con el borde en puntas; mejillas peludas, ceja
-- fuerte, hocico negro muy largo y cuadrado, como de perro, que baja en escalones hasta la nariz;
-- orejas pequeñas oscuras, patas largas con manos y pies negros y anchos, y la cola parda "rota": sube,
-- se dobla hacia atrás y cae. Musculatura en bloques: bíceps y antebrazos más claros, nudillos, y
-- muslos, ancas y gemelos más oscuros; callosidades rosadas en el trasero.
-- Dos expresiones (faces): la normal, con la ceja recta y la boca cerrada, y la de amenaza al atacar,
-- con las cejas en V, los párpados claros a la vista (los babuinos los enseñan para amenazar), arrugas
-- en el hocico y la boca abierta con los colmillos largos.
-- Tonos: "fur" (bodyColor) es el gris oliva y "skin" (faceColor) el negro del hocico.
-- Los pivotes son los del modelo redondo de antes (baboon), para que valgan sus animaciones.

local Shapes = require(script.Parent.Shapes)

local MANE = Color3.fromRGB(112, 88, 62)
local MANE_MID = Color3.fromRGB(100, 78, 56)
local MANE_DARK = Color3.fromRGB(88, 68, 50)
local BELLY = Color3.fromRGB(98, 100, 84)
local BROW = Color3.fromRGB(100, 102, 86)
local BROW_DARK = Color3.fromRGB(55, 56, 46)
local FUR_LIGHT = Color3.fromRGB(98, 100, 83)
local FUR_DARK = Color3.fromRGB(80, 82, 68)
local CALLUS = Color3.fromRGB(150, 95, 90)
local KNUCKLE = Color3.fromRGB(28, 28, 30)
local JAW = Color3.fromRGB(30, 30, 32)
local LID = Color3.fromRGB(225, 220, 210)
local MOUTH = Color3.fromRGB(120, 35, 40)
local FANG = Color3.fromRGB(240, 232, 205)
local NOSTRIL = Color3.fromRGB(18, 18, 20)
local NOSE = Color3.fromRGB(58, 58, 62)
local EYE = Color3.fromRGB(150, 95, 40)
local EAR = Color3.fromRGB(45, 45, 48)
local HAND = Color3.fromRGB(42, 42, 44)
local TAIL = Color3.fromRGB(110, 85, 66)

local function join(...: { any }): { any }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

return {
	-- 0,1 studs por celda a escala 1; con su scale mide ~2,2 studs (GDD §8.2).
	unit = 0.1,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			pivot = { 0, 19, 2.5 },
			boxes = {
				{ 0, 19, 3.5, 11, 9, 21, "fur" },
				{ 0, 21, -3, 12, 10, 9, "fur", "Shoulders" },
				-- El lomo baja de la melena hacia la grupa.
				{ 0, 24.1, 4.5, 10.4, 1.2, 6, "fur", "Back" },
				-- Joroba gris en escalón sobre los hombros; la melena parda la rodea por los lados y por
				-- delante, en capas que se abren hacia abajo (una melena que cubría también el lomo
				-- parecía una mochila).
				{ 0, 26.6, -3, 8.6, 1.2, 8, "fur", "Hump" },
				-- Cada capa más ancha y más corta por detrás que la de encima: de lado, el borde de atrás baja
				-- en escalones, como una capa que cae (con capas iguales parecían correas).
				{ 0, 25.2, -3.6, 12.6, 2.4, 9.6, MANE, "Mane" },
				{ 0, 22.8, -4.2, 13.6, 2.4, 8.8, MANE_MID, "Mane" },
				{ 0, 20.6, -4.8, 14.6, 2, 8, MANE, "Mane" },
				{ 0, 21, -8.2, 11.6, 8, 1, MANE, "Mane" },
				{ 0, 18.2, -9.2, 7, 3, 2, MANE, "Mane" },
				-- Borde en puntas, más oscuro, por los costados y bajo la barbilla.
				{ 7.3, 19.1, -7.6, 0.6, 1.4, 1.8, MANE_DARK, "Mane", true },
				{ 7.3, 18.8, -4.8, 0.6, 2, 1.8, MANE_DARK, "Mane", true },
				{ 7.3, 19.2, -2, 0.6, 1.2, 1.6, MANE_DARK, "Mane", true },
				{ 1.6, 16.4, -9.4, 1.6, 1.2, 1.4, MANE_DARK, "Mane", true },
				{ 0, 14, 3.5, 8, 1, 15, BELLY, "Belly" },
				-- Ancas más oscuras que abultan por los lados hasta el final de la grupa (más cortas, parecían
				-- ventanas).
				{ 5.75, 17.2, 11.7, 0.5, 5.4, 6.2, FUR_DARK, "Haunch", true },
				{ 0, 19, 14.4, 9.4, 7, 0.8, "fur", "Rump" },
				{ 1.3, 16.4, 14.95, 2, 2.4, 0.4, CALLUS, "Callus", true },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 21, -9 },
			boxes = {
				{ 0, 24, -12.5, 9, 8.5, 8, "fur" },
				{ 0, 28.9, -11.6, 7.4, 1.4, 6, "fur", "Crown" },
				{ 4.7, 25.6, -11.2, 0.6, 1.4, 1.2, EAR, "Ear", true },
				-- Mejillas de pelo más claro a los lados del hocico.
				{ 3.6, 22.2, -16.9, 1.8, 3, 1, FUR_LIGHT, "Cheek", true },
				-- Hocico negro, largo y cuadrado: baja en escalones desde la ceja hasta la nariz, con un
				-- bulto más claro encima de la punta y surcos a los lados. La ceja, los ojos y la mandíbula
				-- van en las expresiones (faces, abajo).
				{ 0, 23, -18.5, 4, 4, 4, "skin", "Muzzle" },
				{ 0, 22.4, -21.5, 3.8, 3.4, 2.2, "skin", "Muzzle" },
				{ 0, 22, -23.4, 3.8, 3, 1.6, "skin", "Muzzle" },
				{ 0, 23.6, -23.5, 3.2, 0.6, 1.6, NOSE, "Nose" },
				{ 0.7, 22.8, -24.25, 0.7, 0.5, 0.1, NOSTRIL, "Nostril", true },
				{ 2.05, 22.6, -18.5, 0.1, 0.3, 3.6, NOSE, "Groove", true },
				{ 2.05, 23.7, -18.5, 0.1, 0.3, 3.6, NOSE, "Groove", true },
				{ 1.95, 22.6, -21.5, 0.1, 0.3, 2, NOSE, "Groove", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 5.8, 18, -7.5 },
			boxes = join({
				{ 6.2, 13, -7.5, 3.4, 10, 3.4, "fur" },
				{ 6.2, 17.5, -7.5, 4, 3.4, 4, MANE, "Deltoid" },
				{ 8.25, 15.2, -8.4, 0.5, 1.4, 1.4, MANE_DARK, "Mane" },
				{ 8.25, 14.9, -6.6, 0.5, 2, 1.4, MANE_DARK, "Mane" },
				-- Bíceps delante y por fuera, y antebrazo que abulta arriba.
				{ 6.2, 13.6, -9.45, 2.6, 3.6, 0.5, FUR_LIGHT, "Biceps" },
				{ 8.1, 13, -7.6, 0.5, 3.4, 2.6, FUR_LIGHT, "Biceps" },
				{ 6.2, 5, -7.8, 3, 8, 3, "fur", "Forearm" },
				{ 6.2, 6.6, -9.45, 2.4, 2.6, 0.5, FUR_LIGHT, "Forearm" },
				{ 7.9, 6.2, -7.8, 0.5, 3, 2.6, FUR_LIGHT, "Forearm" },
				{ 6.2, 0.6, -8.4, 3.6, 1.2, 3.6, HAND, "Hand" },
				{ 6.2, 1.45, -9.4, 3.2, 0.5, 1.2, KNUCKLE, "Knuckle" },
			}, Shapes.fingers(6.2, -10.2, 3, 0.8, 1.4, HAND)),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 5, 17, 10 },
			boxes = join({
				{ 5.2, 13, 10, 3.8, 9, 4.6, "fur" },
				-- Muslo por fuera y anca por detrás más oscuros; gemelo bajo la corva.
				{ 7.35, 13, 9.8, 0.5, 5, 3.6, FUR_DARK, "Thigh" },
				{ 5.2, 14.5, 12.55, 3.4, 4, 0.5, FUR_DARK, "Glute" },
				{ 5.2, 5, 11, 3, 8, 3, "fur", "Shin" },
				{ 5.2, 6.6, 12.75, 2.6, 2.8, 0.5, FUR_LIGHT, "Calf" },
				{ 5.2, 0.6, 9.6, 3.6, 1.2, 5, HAND, "Foot" },
			}, Shapes.fingers(5.2, 7.1, 3, 0.8, 1.4, HAND)),
		},
		{
			name = "Tail",
			joint = "TailJoint",
			parent = "Torso",
			pivot = { 0, 20.5, 13 },
			-- "Rota": sube desde la grupa, se dobla hacia atrás y cae.
			boxes = Shapes.tail(
				{
					Vector3.new(0, 21, 14.2),
					Vector3.new(0, 25, 16),
					Vector3.new(0, 28, 18.5),
					Vector3.new(0, 27.5, 21.5),
					Vector3.new(0, 24, 23),
					Vector3.new(0, 18, 23.5),
					Vector3.new(0, 13, 23),
				},
				1.3,
				0.8,
				1.6,
				function()
					return TAIL
				end
			),
		},
	},
	-- Expresiones de la cara, soldadas a la cabeza (MonkeyModels.showFace). La normal es la de siempre;
	-- la de amenaza se ve mientras ataca (Attack) y si ruge (Roar).
	faces = {
		{
			name = "Normal",
			boxes = {
				-- Ceja fuerte que sobresale sobre unos ojos hundidos, y la mandíbula cerrada.
				{ 0, 26.3, -17, 9.4, 1.4, 1.2, BROW, "Brow" },
				{ 2.9, 24.9, -16.6, 1.2, 0.7, 0.2, EYE, "Pupil", true },
				{ 0, 20.3, -20, 3.4, 1.2, 6, JAW, "Jaw" },
			},
		},
		{
			name = "Amenaza",
			actions = { "Attack", "Roar" },
			boxes = {
				-- Cejas oscuras en V sobre los párpados claros a la vista, y arrugas en el hocico.
				{ 3.3, 26.6, -17.05, 3.2, 1.1, 1.3, BROW_DARK, "Brow", true },
				{ 1, 26, -17.2, 1.6, 1.3, 1.6, BROW_DARK, "Brow", true },
				{ 2.9, 25.2, -16.65, 1.3, 0.5, 0.2, LID, "Lid", true },
				{ 2.9, 24.75, -16.6, 1.2, 0.4, 0.2, EYE, "Pupil", true },
				{ 0, 25.1, -17.6, 3.4, 0.2, 0.4, NOSE, "Wrinkle" },
				{ 0, 25.1, -19, 3.4, 0.2, 0.4, NOSE, "Wrinkle" },
				-- Boca abierta bajo el hocico, con la mandíbula caída, dos colmillos largos arriba y dos
				-- cortos abajo (una fila de dientes parecía una sonrisa).
				{ 0, 19.6, -20.3, 3.4, 1.8, 6, MOUTH, "Mouth" },
				{ 0, 18.2, -20.2, 3.4, 1, 6, JAW, "Jaw" },
				{ 1.3, 19.6, -23.1, 0.6, 2, 0.6, FANG, "Fang", true },
				{ 1.1, 19.1, -22.3, 0.5, 0.8, 0.5, FANG, "Fang", true },
			},
		},
	},
	-- El alfa: capa plateada como la de los machos de babuino sagrado (la melena parda pasa a gris
	-- plata, más larga por los costados y bajo la barbilla), callosidades rojas más grandes, y la cara
	-- normal algo más agresiva: cejas oscuras un poco en V, ojos entornados y las puntas de los
	-- colmillos asomando con la boca cerrada.
	alpha = {
		recolor = {
			-- Studio aclara los grises: con (172, 170, 162) la capa salía blanca.
			{ MANE, Color3.fromRGB(145, 143, 136) },
			{ MANE_MID, Color3.fromRGB(126, 124, 118) },
			{ MANE_DARK, Color3.fromRGB(100, 98, 93) },
			{ CALLUS, Color3.fromRGB(215, 65, 80) },
		},
		add = {
			Torso = {
				{ 7.3, 17.6, -6.2, 0.6, 2, 1.8, MANE_DARK, "Mane", true },
				{ 7.3, 17.9, -3.4, 0.6, 1.6, 1.6, MANE_DARK, "Mane", true },
				{ 0, 16.2, -9.4, 4.4, 2.4, 1.6, MANE, "Mane" },
				{ 1.3, 16.3, 15.05, 2.4, 3.2, 0.4, CALLUS, "Callus", true },
			},
			Arm = {
				{ 8.25, 13.6, -7.5, 0.5, 1.8, 1.4, MANE_DARK, "Mane" },
			},
		},
		faces = {
			Normal = {
				{ 3.3, 26.45, -17.05, 3.2, 1.2, 1.3, BROW_DARK, "Brow", true },
				{ 1, 26.1, -17.2, 1.6, 1.3, 1.5, BROW_DARK, "Brow", true },
				{ 2.9, 24.85, -16.6, 1.2, 0.5, 0.2, EYE, "Pupil", true },
				{ 0, 20.3, -20, 3.4, 1.2, 6, JAW, "Jaw" },
				{ 1.3, 20.2, -23.1, 0.5, 1, 0.5, FANG, "Fang", true },
			},
		},
	},
}
