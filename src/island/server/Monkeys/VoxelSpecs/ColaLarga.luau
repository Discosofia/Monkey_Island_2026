--!strict
-- Mono de cola larga (macaco cangrejero) en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el
-- formato de las cajas está explicado en VoxelSpecs/Gorila. Referencia: docs/img/Mono de cola larga.jfif.
-- Delgado, gris pardo con los hombros, el lomo y la grupa ocres y el vientre claro; cara rosada con
-- cejas oscuras y marcadas, patillas claras a los lados, orejas rosadas y un copete en la coronilla;
-- antebrazos, espinillas, manos y pies más oscuros, con dedos largos, y una cola larguísima y fina que
-- cae hasta el suelo y se arrastra detrás.
-- Tonos: "fur" (bodyColor) es el gris pardo y "skin" (faceColor) el claro con el que se mezcla el vientre.
-- Los pivotes son los del modelo redondo de antes (longTailedMacaque, ya borrado), para que valgan sus
-- animaciones.

local Shapes = require(script.Parent.Shapes)

local GOLD = Color3.fromRGB(185, 140, 60)
local LIMB = Color3.fromRGB(110, 100, 94)
local PINK = Color3.fromRGB(215, 155, 145)
local PINK_DARK = Color3.fromRGB(170, 110, 105)
local BROW = Color3.fromRGB(95, 85, 80)
local EYE = Color3.fromRGB(30, 22, 18)
local MOUTH = Color3.fromRGB(110, 60, 58)
local TAIL = Color3.fromRGB(140, 132, 124)
local CREAM = Color3.fromRGB(222, 210, 178)

local function join(...: { any }): { any }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

return {
	-- 0,1 studs por celda a escala 1; con su scale mide ~1,6 studs (GDD §8.2).
	unit = 0.1,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			pivot = { 0, 16, 2 },
			boxes = {
				{ 0, 16, 2, 8.6, 8, 17, "fur" },
				{ 0, 16.5, -4, 9.4, 7, 5, "fur", "Shoulders" },
				-- Ocre sobre los hombros (y por los costados) y sobre la grupa.
				{ 0, 18.4, -3.5, 9.8, 3.4, 5.4, GOLD, "Mantle" },
				{ 0, 18.2, 8, 8.8, 3.8, 5.4, GOLD, "Saddle" },
				{ 0, 16.8, 10.7, 7, 4.6, 0.6, GOLD, "Rump" },
				{ 0, 11.6, 2, 6.4, 1, 13, "chest", "Belly" },
				{ 0, 15, -6.7, 5.4, 4.5, 0.6, "chest", "Bib" },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 18, -7.5 },
			boxes = {
				{ 0, 21.5, -11.5, 8, 7.6, 7.6, "fur" },
				{ 0, 25.6, -11, 7, 0.8, 6, "fur", "Cap" },
				{ 0, 26.4, -10.5, 2.4, 0.8, 3, "fur", "Crest" },
				{ 0, 21, -15.5, 6, 5.6, 0.5, PINK, "Face" },
				{ 0, 23.1, -15.95, 5.6, 0.8, 0.5, BROW, "Brow" },
				{ 1.4, 22.1, -15.85, 1, 0.6, 0.2, EYE, "Pupil", true },
				{ 0, 19.3, -16.3, 4, 2.6, 1.6, PINK, "Muzzle" },
				{ 0.6, 20, -17.15, 0.5, 0.4, 0.1, PINK_DARK, "Nostril", true },
				{ 0, 18.6, -17.15, 2.4, 0.3, 0.1, MOUTH, "Mouth" },
				-- Patillas claras a los lados de la cara, peinadas hacia atrás y abajo.
				{ 4.1, 19.2, -13.3, 0.8, 3.6, 4.2, CREAM, "Whiskers", true },
				{ 4.3, 22.2, -10.5, 0.6, 2, 1.6, PINK, "Ear", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 4.2, 14.5, -5.5 },
			boxes = join({
				{ 4.2, 10.8, -5.5, 2.4, 7.4, 2.6, "fur" },
				{ 4.2, 14, -5.5, 3, 2.6, 3, GOLD, "Deltoid" },
				{ 4.2, 4.5, -5.8, 2.2, 6.2, 2.2, LIMB, "Forearm" },
				{ 4.2, 0.6, -6.4, 2.8, 1.2, 2.8, LIMB, "Hand" },
			}, Shapes.fingers(4.2, -7.8, 3, 0.6, 1.5, LIMB)),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 4, 15, 9 },
			boxes = join({
				{ 4.1, 11.6, 8.8, 3, 7, 3.8, "fur" },
				{ 4.1, 5, 9.6, 2.2, 7, 2.2, LIMB, "Shin" },
				{ 4.1, 0.6, 8.4, 2.8, 1.2, 4.6, LIMB, "Foot" },
			}, Shapes.fingers(4.1, 6.1, 3, 0.6, 1.5, LIMB)),
		},
		{
			name = "Tail",
			joint = "TailJoint",
			parent = "Torso",
			pivot = { 0, 18, 11 },
			-- Larguísima y fina: cae desde la grupa y se arrastra por el suelo.
			boxes = Shapes.tail(
				{
					Vector3.new(0, 18, 11.5),
					Vector3.new(0, 17, 16),
					Vector3.new(0, 13, 20),
					Vector3.new(0, 8, 22.5),
					Vector3.new(0, 3, 24),
					Vector3.new(0, 1, 28),
					Vector3.new(0, 1, 33),
					Vector3.new(0, 2, 37),
				},
				1,
				0.75,
				1.6,
				function()
					return TAIL
				end
			),
		},
	},
}
