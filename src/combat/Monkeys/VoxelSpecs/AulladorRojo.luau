--!strict
-- Mono aullador rojo en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el formato de las cajas
-- está explicado en VoxelSpecs/Gorila. Referencia: docs/img/Mono aullador rojo.jfif.
-- Cuerpo pesado, rojo anaranjado, con una joroba alta en los hombros (escalones, cresta y una crin en
-- punta por los costados) y la grupa más baja; cabeza adelantada y baja, por debajo de la joroba, con
-- la frente inclinada; cara casi negra con la mandíbula adelantada y dos expresiones (faces): la normal,
-- con la ceja recta y la boca cerrada, y la del grito al llamar a la tropa y al atacar, con las cejas en V
-- sobre unos ojos rojos entornados, la boca abierta y cuatro colmillos (sin fila de dientes: parecía
-- una sonrisa). Bajo la cara, la caja de resonancia: una barba en bolsa que abulta hacia delante y abajo, con
-- puntas que cuelgan, enmarcada por patillas granates. Antebrazos, espinillas, manos y pies
-- granates; orejas y mechón de la coronilla pardos, y una cola gruesa que cae y se enrosca en gancho.
-- Tonos: "fur" (bodyColor) es el rojo y "skin" (faceColor) el pardo oscuro de la cara.
-- Los pivotes son los del modelo redondo de antes (howler, ya borrado), para que valgan sus animaciones.

local Shapes = require(script.Parent.Shapes)

local MAROON = Color3.fromRGB(150, 50, 25)
local LIGHT = Color3.fromRGB(205, 95, 45)
local BEARD = Color3.fromRGB(38, 26, 24)
local BROWN = Color3.fromRGB(85, 45, 35)
local CREST = Color3.fromRGB(222, 118, 58)
local BROW = Color3.fromRGB(70, 25, 18)
local EYE = Color3.fromRGB(160, 70, 50)
local EYE_ANGRY = Color3.fromRGB(205, 55, 35)
local LIPS = Color3.fromRGB(20, 14, 12)
local MOUTH = Color3.fromRGB(115, 28, 26) -- rojo oscuro: negro sobre la cara negra no se leía
local FANG = Color3.fromRGB(235, 225, 200)

local function join(...: { any }): { any }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

return {
	-- 0,1 studs por celda a escala 1; con su scale mide ~1,75 studs (GDD §8.2).
	unit = 0.1,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			pivot = { 0, 17, 2.5 },
			boxes = {
				{ 0, 16.5, 3, 11, 9, 20, "fur" },
				-- Joroba de los hombros: tres escalones y una cresta, muy por encima de la cabeza.
				{ 0, 18.5, -2.5, 13, 10, 9, "fur", "Shoulders" },
				{ 0, 24.3, -3, 11.8, 1.8, 8, LIGHT, "Hump" },
				{ 0, 25.9, -3, 9.4, 1.6, 6.2, LIGHT, "Hump" },
				{ 0, 27.2, -2.8, 6, 1.2, 4, CREST, "Crest" },
				-- La joroba baja hacia la grupa en escalones igual de anchos (con anchos distintos, desde atrás
				-- parecían cajones).
				{ 0, 22.6, 3.5, 10, 1.6, 6, LIGHT, "Back" },
				{ 0, 21.4, 7.5, 10, 1.2, 4, LIGHT, "Back" },
				{ 0, 21, 10.5, 10, 0.8, 3, "fur", "Back" },
				-- Crin en punta que cuelga de la joroba por los costados.
				{ 6.7, 21.5, -2.5, 0.8, 4, 8, LIGHT, "Mane", true },
				{ 6.8, 18.8, -5.2, 0.6, 1.6, 1.8, LIGHT, "Mane", true },
				{ 6.8, 18.6, -2.4, 0.6, 2, 1.8, LIGHT, "Mane", true },
				{ 6.8, 18.9, 0.4, 0.6, 1.4, 1.8, LIGHT, "Mane", true },
				-- Pelo del pecho que asoma por delante de los hombros, bajo la barba.
				{ 0, 17, -7.3, 9, 5, 0.8, MAROON, "Ruff" },
				{ 0, 16.5, 13.4, 10, 7.5, 1, "fur", "Rump" },
				{ 0, 11.6, 3, 8, 1, 14, MAROON, "Belly" },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 17, -8.5 },
			boxes = {
				{ 0, 18, -13, 9, 8, 8, "fur" },
				{ 0, 22.4, -12, 7.6, 0.8, 6, "fur", "Cap" },
				{ 0, 23, -10.5, 3, 0.8, 2.6, BROWN, "Crown" },
				-- Frente inclinada; cejas, ojos y boca van en las expresiones (faces, abajo).
				{ 0, 21.8, -17.1, 8, 0.8, 0.6, MAROON, "Forehead" },
				{ 0, 19.2, -17.2, 6.4, 4.4, 0.6, "skin", "Face" },
				{ 0, 19.5, -18, 2.2, 1.1, 1.2, "skin", "Nose" },
				{ 0, 17.4, -18, 6, 2.6, 2, "skin", "Jaw" },
				-- Caja de resonancia: barba en bolsa que abulta hacia delante y abajo.
				{ 0, 14, -15.8, 7.6, 5, 5.4, BEARD, "Beard" },
				{ 0, 12.6, -17.3, 6.2, 3.6, 3.4, BEARD, "Beard" },
				{ 0, 10.4, -16, 5, 1.6, 4, BEARD, "Beard" },
				{ 0, 9.2, -16.6, 2.4, 1, 2.2, BEARD, "Beard" },
				-- Puntas que cuelgan del borde (mechones pegados delante parecían botones).
				{ 2.4, 10.2, -17.9, 1.2, 1.6, 1.4, BEARD, "Beard", true },
				{ 0.8, 9.6, -18.1, 1.2, 2.4, 1.4, BEARD, "Beard", true },
				-- Patillas granates que enmarcan la cara y la bolsa.
				{ 3.9, 18.5, -16, 1.4, 6, 2.6, MAROON, "Cheek", true },
				{ 4.3, 14, -15, 1.2, 5.4, 4, MAROON, "Cheek", true },
				{ 0, 15, -11.2, 8.6, 4, 4, "fur", "Throat" },
				{ 4.8, 19.6, -12, 0.8, 2.2, 1.8, BROWN, "Ear", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 5.2, 15, -6 },
			boxes = join({
				{ 5.4, 11, -6, 3, 8, 3, "fur" },
				{ 5.4, 14.6, -6, 3.6, 3, 3.6, LIGHT, "Deltoid" },
				{ 5.4, 4.5, -6.3, 2.6, 6, 2.6, MAROON, "Forearm" },
				{ 5.4, 0.6, -6.9, 3.2, 1.2, 3.2, MAROON, "Hand" },
			}, Shapes.fingers(5.4, -8.5, 3, 0.7, 1.4, MAROON)),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 4.8, 15.5, 9.5 },
			boxes = join({
				{ 4.9, 12, 9.3, 3.4, 7.5, 4.2, "fur" },
				{ 4.9, 5, 10.2, 2.6, 7, 2.6, MAROON, "Shin" },
				{ 4.9, 0.6, 9, 3.2, 1.2, 4.6, MAROON, "Foot" },
			}, Shapes.fingers(4.9, 6.7, 3, 0.7, 1.4, MAROON)),
		},
		{
			name = "Tail",
			joint = "TailJoint",
			parent = "Torso",
			pivot = { 0, 19, 12.5 },
			-- Gruesa: sale hacia atrás, cae y el final se enrosca en gancho hacia el cuerpo.
			boxes = Shapes.tail(
				{
					Vector3.new(0, 19, 13),
					Vector3.new(0, 20, 17),
					Vector3.new(0, 18.5, 21),
					Vector3.new(0, 14, 23.5),
					Vector3.new(0, 9, 24.5),
					Vector3.new(0, 5.5, 24),
					Vector3.new(0, 4, 21.5),
					Vector3.new(0, 5.5, 19.5),
					Vector3.new(0, 7.5, 20),
				},
				1.9,
				0.65,
				1.6,
				function(index: number, count: number)
					return if index > count - 5 then MAROON else "fur"
				end
			),
		},
	},
	-- Expresiones de la cara, soldadas a la cabeza (MonkeyModels.showFace). La normal es la de siempre;
	-- el grito se ve mientras llama a la tropa (Howl) y mientras ataca (Attack).
	faces = {
		{
			name = "Normal",
			boxes = {
				{ 0, 21.2, -17.5, 6.6, 0.8, 0.8, BROW, "Brow" },
				{ 1.6, 20.2, -17.55, 1.2, 0.7, 0.2, EYE, "Pupil", true },
				{ 0, 17.6, -19.05, 3, 0.3, 0.1, LIPS, "Mouth" },
			},
		},
		{
			name = "Grito",
			actions = { "Howl", "Attack" },
			boxes = {
				-- Ceño: cejas oscuras en V, más bajas en el centro, sobre ojos entornados.
				{ 2.7, 21.3, -17.5, 2.6, 0.9, 1, BROW, "Brow", true },
				{ 1.1, 20.9, -17.6, 1.4, 0.9, 1.2, BROW, "Brow", true },
				{ 1.7, 20.2, -17.55, 1.3, 0.5, 0.2, EYE_ANGRY, "Pupil", true },
				{ 0, 20.2, -17.75, 1.2, 0.3, 0.4, BROW, "Wrinkle" },
				-- Boca abierta de aullido, casi toda la mandíbula (con la cabeza levantada en el aullido
				-- la cara queda de escorzo y una boca más pequeña no se leía): dos colmillos arriba y dos abajo.
				{ 0, 17.4, -19.05, 3.6, 2.2, 0.1, MOUTH, "Mouth" },
				{ 1.35, 18.05, -19.15, 0.6, 0.9, 0.2, FANG, "Fang", true },
				{ 1.25, 16.75, -19.15, 0.5, 0.6, 0.2, FANG, "Fang", true },
			},
		},
	},
}
