--!strict
-- Capuchino ladrón (capuchino de cara blanca) en estilo voxel. Lo construye MonkeyModels.voxelMonkey;
-- el formato de las cajas está explicado en VoxelSpecs/Gorila. Referencia: docs/img/Capuchino Ladron.jfif.
-- Marrón chocolate con una capa crema en los hombros, el pecho y los lados de la cara; cara rosada con
-- ceja, nariz y hocico; orejas, manos y pies rosados; patas largas y cola con el final enroscado.
-- Tonos: "fur" (bodyColor) es el marrón y "skin" (faceColor) el crema de la capa.
-- Los pivotes son los del modelo redondo de antes (capuchin, ya borrado), para que valgan sus animaciones.

local Shapes = require(script.Parent.Shapes)

local PINK = Color3.fromRGB(205, 135, 115)
local PINK_DARK = Color3.fromRGB(170, 100, 88)
local MOUTH = Color3.fromRGB(95, 45, 40)
local EYE = Color3.fromRGB(25, 20, 18)
local BELLY = Color3.fromRGB(105, 65, 50)

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
				{ 0, 16.5, 1.5, 7.6, 7, 15, "fur" },
				-- Capa crema sobre hombros y pecho, con el borde de atrás en escalones.
				{ 0, 16.8, -4, 8.6, 7.6, 4.6, "skin", "Mantle" },
				{ 0, 20.1, -1, 6, 0.8, 2, "skin", "Mantle" },
				{ 3.9, 17.5, -1.2, 0.6, 3, 1.6, "skin", "Mantle", true },
				{ 0, 14.5, -6.6, 5, 3, 0.6, "skin", "Bib" },
				{ 0, 16.5, 9.6, 7, 6, 1.2, "fur", "Rump" },
				{ 0, 12.8, 2.5, 6, 1, 10, BELLY, "Belly" },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 17.5, -7.5 },
			boxes = {
				{ 0, 21.5, -11, 7.6, 7.6, 7.6, "fur" },
				{ 0, 25.7, -10.8, 6.8, 0.8, 6.8, "fur", "Cap" },
				{ 0, 20.6, -15.1, 5.8, 5.4, 0.6, PINK, "Face" },
				{ 0, 22.8, -15.6, 5.4, 0.7, 0.4, PINK_DARK, "Brow" },
				{ 1.4, 21.7, -15.5, 1, 0.7, 0.2, EYE, "Pupil", true },
				{ 0, 20.5, -15.8, 1.4, 1.8, 0.8, PINK, "Nose" },
				{ 0, 19, -15.9, 4, 2, 1, PINK, "Muzzle" },
				{ 0, 18.7, -16.45, 2.4, 0.3, 0.1, MOUTH, "Mouth" },
				-- Crema bajo la cara y por los lados, que enlaza con la capa.
				{ 0, 17.8, -13, 7, 1.6, 4, "skin", "Throat" },
				{ 3.6, 19, -12.5, 0.6, 3, 3.6, "skin", "Cheek", true },
				{ 4.1, 21.5, -11, 0.6, 2, 1.6, PINK, "Ear", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 3.8, 14, -5 },
			boxes = join({
				{ 3.8, 10.3, -5, 2.4, 7.4, 2.6, "fur" },
				{ 3.8, 13.6, -5, 3, 2.6, 3, "skin", "Deltoid" },
				{ 3.8, 4.2, -5.3, 2.2, 6, 2.2, "fur", "Forearm" },
				{ 3.8, 0.6, -5.9, 2.8, 1.2, 2.8, PINK, "Hand" },
			}, Shapes.fingers(3.8, -7.3, 3, 0.6, 1.3, PINK)),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 3.8, 14.5, 8 },
			boxes = join({
				{ 3.9, 11.3, 7.8, 2.8, 6.6, 3.6, "fur" },
				{ 3.9, 4.8, 8.6, 2.2, 6.6, 2.2, "fur", "Shin" },
				{ 3.9, 0.6, 7.4, 2.8, 1.2, 4.4, PINK, "Foot" },
			}, Shapes.fingers(3.9, 5.2, 3, 0.6, 1.3, PINK)),
		},
		{
			name = "Tail",
			joint = "TailJoint",
			parent = "Torso",
			pivot = { 0, 17.5, 10 },
			-- Baja hacia atrás y el final se enrosca hacia arriba y hacia dentro.
			boxes = Shapes.tail(
				{
					Vector3.new(0, 17.5, 10.5),
					Vector3.new(0, 15.5, 15),
					Vector3.new(0, 11, 19),
					Vector3.new(0, 7, 21),
					Vector3.new(0, 4, 24),
					Vector3.new(0, 4, 28),
					Vector3.new(0, 7.5, 30),
					Vector3.new(0, 10.5, 28.5),
					Vector3.new(0, 10.5, 26),
					Vector3.new(0, 8, 25.5),
				},
				1.3,
				0.85,
				1.5,
				function()
					return "fur"
				end
			),
		},
	},
}
