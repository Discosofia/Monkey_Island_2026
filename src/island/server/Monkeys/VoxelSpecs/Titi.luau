--!strict
-- Tití del Chocó (tamarino de Geoffroy) en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el
-- formato de las cajas está explicado en VoxelSpecs/Gorila. Referencia: docs/img/Titi del choco.jfif.
-- Cuerpo pardo oscuro con el lomo, las ancas y las patas grises; cara negra con un bigote blanco y una
-- cresta blanca en escalones de la frente a la nuca; orejitas pardas y cola fina anillada, más larga
-- que el cuerpo. Tonos: "fur" (bodyColor) es el pardo y "skin" (faceColor) el blanco de la cresta.
-- Los pivotes son los del modelo redondo de antes (tamarin, ya borrado), para que valgan sus animaciones.

local Shapes = require(script.Parent.Shapes)

local GREY = Color3.fromRGB(118, 108, 104)
local LIMB = Color3.fromRGB(88, 78, 75)
local BLACK = Color3.fromRGB(28, 25, 25)
local EYE = Color3.fromRGB(150, 95, 70)
local RING = Color3.fromRGB(58, 40, 32)

local function join(...: { any }): { any }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

return {
	-- 0,1 studs por celda a escala 1; con su scale mide ~1,4 studs con la cresta (GDD §8.2).
	unit = 0.1,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			pivot = { 0, 15.5, 1.5 },
			boxes = {
				{ 0, 14.5, 1, 8, 9, 14, "fur" },
				{ 0, 15.5, -3.5, 8.6, 8, 5, "fur", "Shoulders" },
				-- Lomo y ancas grises: una placa encima y los costados algo más anchos, que asoman.
				{ 0, 19.4, 3.5, 7.4, 0.8, 7, GREY, "Saddle" },
				{ 0, 15, 4.5, 8.2, 8.2, 6, GREY, "Flank" },
				{ 0, 14.5, 8.6, 7.2, 8, 1.4, LIMB, "Rump" },
				{ 0, 10, 2, 6, 1, 10, GREY, "Belly" },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 17, -6 },
			boxes = {
				{ 0, 21, -9.5, 8, 7, 7, "skin" },
				-- Cresta blanca baja, peinada hacia atrás, y la melena que baja por la nuca.
				{ 0, 24.7, -8.5, 6.4, 0.8, 7.5, "skin", "Crest" },
				{ 0, 25.2, -7, 4, 0.6, 6, "skin", "Crest" },
				{ 0, 22, -4.9, 6, 4.4, 2.2, "skin", "Mane" },
				{ 0, 20.4, -13.15, 6.8, 6, 0.5, BLACK, "Face" },
				{ 0, 18.6, -14.2, 4, 2.4, 1.2, BLACK, "Muzzle" },
				{ 0, 18.9, -14.9, 3, 0.6, 0.2, "skin", "Moustache" },
				{ 1.5, 21.2, -13.5, 1, 0.8, 0.2, EYE, "Pupil", true },
				{ 4.3, 21, -9, 0.6, 1.4, 1.2, "fur", "Ear", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 3.6, 14, -4.5 },
			boxes = join({
				{ 3.6, 10.5, -4.5, 2.4, 7, 2.4, "fur" },
				{ 3.6, 4.5, -4.8, 2, 6, 2, LIMB, "Forearm" },
				{ 3.6, 0.6, -5.4, 2.4, 1.2, 2.6, LIMB, "Hand" },
			}, Shapes.fingers(3.6, -6.7, 3, 0.6, 1.2, LIMB)),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 3.6, 14.5, 7 },
			boxes = join({
				{ 3.8, 11.5, 6.5, 2.8, 6, 3.6, GREY },
				{ 3.8, 5.5, 7.5, 2, 6, 2, LIMB, "Shin" },
				{ 3.8, 1.8, 8, 2, 2.4, 2, LIMB, "Heel" },
				{ 3.8, 0.6, 6.6, 2.4, 1.2, 4, LIMB, "Foot" },
			}, Shapes.fingers(3.8, 4.6, 3, 0.6, 1.2, LIMB)),
		},
		{
			name = "Tail",
			joint = "TailJoint",
			parent = "Torso",
			pivot = { 0, 16.5, 8.5 },
			-- Cuelga hacia atrás, con anillos más oscuros cada dos bloques.
			boxes = Shapes.tail(
				{
					Vector3.new(0, 16, 9.2),
					Vector3.new(0, 13, 16),
					Vector3.new(0, 8, 21),
					Vector3.new(0, 5, 26),
					Vector3.new(0, 4, 29),
				},
				1.3,
				0.75,
				1.6,
				function(index: number)
					return if index % 4 >= 2 then RING else "fur"
				end
			),
		},
	},
}
