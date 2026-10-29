--!strict
-- Gibón en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el formato de las cajas está explicado
-- en VoxelSpecs/Gorila. Referencia: docs/img/Gibon.jfif.
-- Simio pequeño y sin cola que en el suelo anda erguido, con las piernas cortas algo dobladas. Casi
-- negro, con el pecho y una mancha del lomo pardos; torso corto y hombros anchos; cabeza pequeña con
-- la cara negra rodeada por completo de un anillo blanco. Los brazos, largísimos (el doble que el
-- cuerpo) y con una banda parda en el codo, cuelgan hasta casi el suelo y acaban en manos de gancho.
-- Atrás, la espalda termina cuadrada y limpia.
-- Tonos: "fur" (bodyColor) es el casi negro y "skin" (faceColor) el blanco del anillo de la cara.
-- Los pivotes son los del modelo redondo de antes (gibbon), que tenía los brazos en alto: con los
-- brazos colgando, sus animaciones giran los brazos con el signo de X al revés (ver
-- MonkeyAnimationSpecs/MonosMedianosYGrandes).

local Shapes = require(script.Parent.Shapes)

local CHEST = Color3.fromRGB(78, 56, 46)
local BAND = Color3.fromRGB(70, 52, 44)
local FACE = Color3.fromRGB(45, 42, 42)
local BROW = Color3.fromRGB(28, 25, 25)
local EYE = Color3.fromRGB(10, 8, 8)
local MOUTH = Color3.fromRGB(50, 30, 28)
local HAND = Color3.fromRGB(26, 21, 19)

local function join(...: { any }): { any }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

return {
	-- 0,1 studs por celda a escala 1; con su scale mide ~2,4 studs (GDD §8.2).
	unit = 0.1,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			pivot = { 0, 18.5, 0 },
			boxes = {
				-- Pecho ancho que se estrecha hacia la cintura: entre el brazo y el cuerpo queda hueco.
				{ 0, 21, 0.3, 8.4, 9, 7, "fur" },
				{ 0, 15, 0.5, 6.4, 6, 6.4, "fur", "Waist" },
				{ 0, 23.5, 0.3, 10.6, 4, 7.4, "fur", "Shoulders" },
				{ 0, 26, 0.6, 7, 1.4, 5.6, "fur", "Trap" },
				{ 0, 12, 0.6, 6.8, 3, 6, "fur", "Pelvis" },
				-- Pecho pardo, más ancho arriba, y una mancha parda en el lomo.
				{ 0, 19.8, -3.3, 6, 6.6, 0.6, CHEST, "Bib" },
				{ 0, 15.8, -2.95, 3.6, 1.6, 0.6, CHEST, "Bib" },
				{ 0, 21.5, 4.05, 3, 4, 0.3, CHEST, "Back" },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 26, 0 },
			boxes = {
				{ 0, 29.6, -0.6, 7, 7, 6.6, "fur" },
				{ 0, 33.5, -0.3, 5.6, 0.8, 5, "fur", "Cap" },
				-- Cara negra rodeada por completo del anillo blanco.
				{ 0, 29.2, -4.05, 4.4, 4.8, 0.4, FACE, "Face" },
				{ 0, 32, -4.1, 6, 0.8, 0.5, "skin", "Ring" },
				{ 0, 26.4, -4.1, 6, 0.8, 0.5, "skin", "Ring" },
				{ 2.6, 29.2, -4.1, 0.8, 6.4, 0.5, "skin", "Ring", true },
				{ 0, 30.6, -4.35, 4.4, 0.7, 0.3, BROW, "Brow" },
				{ 1.1, 29.8, -4.3, 0.9, 0.6, 0.1, EYE, "Pupil", true },
				{ 0, 28.2, -4.5, 2, 1.4, 0.6, FACE, "Muzzle" },
				{ 0, 27.3, -4.3, 2.4, 0.3, 0.1, MOUTH, "Mouth" },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 5, 24, 0 },
			-- Larguísimo y separado del cuerpo: cuelga hasta casi el suelo, pardo del codo para abajo, y la
			-- mano se dobla hacia delante y arriba, en gancho.
			boxes = {
				{ 8, 18.5, 0.2, 2.2, 11, 2.2, "fur" },
				{ 7, 23.6, 0.2, 3.6, 3.2, 3.4, "fur", "Deltoid" },
				{ 8, 8.2, 0, 2, 9.6, 2, BAND, "Forearm" },
				{ 8, 2.3, -0.2, 2, 2.4, 2, HAND, "Hand" },
				{ 8, 1, -1.5, 1.8, 0.8, 3, HAND, "Hook" },
				{ 8, 1.9, -2.7, 1.8, 1.4, 0.8, HAND, "Hook" },
			},
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 3, 13, 0.5 },
			-- Corta y algo doblada: la rodilla adelantada en un escalón.
			boxes = join({
				{ 2.6, 10.5, 0, 2.8, 4, 3.4, "fur" },
				{ 2.6, 7.2, -0.9, 2.6, 3, 3, "fur", "Knee" },
				{ 2.6, 3.6, 0.1, 2.2, 5, 2.2, "fur", "Shin" },
				{ 2.6, 0.6, -0.8, 2.6, 1.2, 4.4, HAND, "Foot" },
			}, Shapes.fingers(2.6, -3, 3, 0.6, 1.2, HAND)),
		},
	},
}
