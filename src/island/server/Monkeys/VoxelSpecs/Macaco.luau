--!strict
-- Macaco en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el formato de las cajas está explicado
-- en VoxelSpecs/Gorila. Referencia: docs/img/Macaco.jfif.
-- Compacto y fuerte, de espalda recta, pardo anaranjado con la cabeza y dos placas del lomo (hombros y
-- grupa) ocres; cara plana rosada con mejillas llenas, una ceja marcada, el hocico corto y redondeado y
-- orejas rosadas a los lados; vientre más claro con rayas, manos y pies rosados y gruesos, y una cola
-- mediana en fila de bloques que se eleva un poco y cae.
-- Tonos: "fur" (bodyColor) es el pardo anaranjado y "skin" (faceColor) el rosado de la cara.
-- Los pivotes son los del modelo redondo de antes (macaque), para que valgan sus animaciones.

local Shapes = require(script.Parent.Shapes)

local GOLD = Color3.fromRGB(188, 126, 50)
local BELLY = Color3.fromRGB(170, 118, 78)
local STRIPE = Color3.fromRGB(140, 92, 58)
local PINK_DARK = Color3.fromRGB(190, 120, 110)
local HAND = Color3.fromRGB(215, 150, 135)
local EYE = Color3.fromRGB(40, 25, 22)
local NOSTRIL = Color3.fromRGB(130, 70, 65)
local MOUTH = Color3.fromRGB(140, 75, 70)

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
			pivot = { 0, 16.5, 2 },
			boxes = {
				{ 0, 16, 2, 10, 8, 19, "fur" },
				{ 0, 16.5, -4, 10.6, 8, 6, "fur", "Shoulders" },
				-- Placas ocres sobre los hombros y sobre la grupa, con el pardo entre ellas.
				{ 0, 20.9, -3.8, 9.6, 0.9, 6, GOLD, "Mantle" },
				{ 0, 19.6, 7.5, 10.4, 1.8, 7.4, GOLD, "Saddle" },
				{ 0, 20.7, 7.5, 9, 0.6, 6, GOLD, "Saddle" },
				-- Vientre claro con rayas (se ve desde abajo y al trepar).
				{ 0, 11.6, 2, 7, 1, 13, BELLY, "Belly" },
				{ 0, 11.05, -1.5, 6, 0.2, 0.8, STRIPE, "Stripe" },
				{ 0, 11.05, 1, 6, 0.2, 0.8, STRIPE, "Stripe" },
				{ 0, 11.05, 3.5, 6, 0.2, 0.8, STRIPE, "Stripe" },
				{ 0, 15, -7.3, 6, 5, 0.6, BELLY, "Bib" },
				{ 0, 16, 11.8, 8.6, 6.4, 0.6, "fur", "Rump" },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 18.5, -8.5 },
			boxes = {
				{ 0, 21.5, -12.5, 8.6, 8, 8, GOLD },
				-- Placa ancha en la coronilla, con otra más pequeña encima.
				{ 0, 25.9, -12.2, 9.4, 0.9, 8.4, GOLD, "Cap" },
				{ 0, 26.7, -11.6, 6.4, 0.8, 5.6, GOLD, "Cap" },
				-- Cara plana rosada, ceja marcada y mejillas llenas.
				{ 0, 21, -16.75, 6.6, 6.4, 0.5, "skin", "Face" },
				{ 0, 23.4, -17.2, 6.2, 0.9, 0.6, PINK_DARK, "Brow" },
				{ 1.5, 22.3, -17.1, 1, 0.7, 0.2, EYE, "Pupil", true },
				{ 2.9, 19.6, -17.2, 1.6, 2.6, 0.8, "skin", "Cheek", true },
				-- Hocico corto y redondeado: la punta más estrecha que la base.
				{ 0, 19.4, -17.6, 4, 2.8, 1.4, "skin", "Muzzle" },
				{ 0, 19.6, -18.5, 3, 2, 0.6, "skin", "Muzzle" },
				{ 0.5, 20.2, -18.85, 0.5, 0.4, 0.1, NOSTRIL, "Nostril", true },
				{ 0, 18.9, -18.85, 2, 0.3, 0.1, MOUTH, "Mouth" },
				{ 4.6, 21.8, -12, 0.8, 2.4, 2, "skin", "Ear", true },
				{ 4.85, 21.8, -12.2, 0.3, 1.4, 1, PINK_DARK, "EarInner", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 5, 15, -6 },
			boxes = join({
				{ 5.2, 10.8, -6, 3.2, 8, 3.4, "fur" },
				{ 5.2, 14.4, -6, 3.8, 3, 3.8, "fur", "Deltoid" },
				{ 5.2, 4.5, -6.3, 2.9, 6.4, 2.9, "fur", "Forearm" },
				{ 5.2, 0.6, -6.9, 3.4, 1.2, 3.4, HAND, "Hand" },
			}, Shapes.fingers(5.2, -8.6, 3, 0.8, 1.3, HAND)),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 4.8, 15.5, 9.5 },
			boxes = join({
				{ 4.9, 12, 9.4, 3.6, 7.5, 4.4, "fur" },
				{ 4.9, 5, 10.2, 2.9, 7, 2.9, "fur", "Shin" },
				{ 4.9, 0.6, 9, 3.4, 1.2, 4.6, HAND, "Foot" },
			}, Shapes.fingers(4.9, 6.7, 3, 0.8, 1.3, HAND)),
		},
		{
			name = "Tail",
			joint = "TailJoint",
			parent = "Torso",
			pivot = { 0, 18.5, 12 },
			-- Mediana: se eleva un poco desde la grupa y cae en escalones.
			boxes = Shapes.tail(
				{
					Vector3.new(0, 18.5, 12.2),
					Vector3.new(0, 21.5, 15),
					Vector3.new(0, 23.5, 18.5),
					Vector3.new(0, 22.5, 21.5),
					Vector3.new(0, 19, 23.5),
					Vector3.new(0, 15, 24),
				},
				1.6,
				0.7,
				1.6,
				function()
					return "fur"
				end
			),
		},
	},
}
