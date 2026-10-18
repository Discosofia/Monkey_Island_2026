--!strict
-- Marimonda del Chocó (mono araña) en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el formato
-- de las cajas está explicado en VoxelSpecs/Gorila. Referencia: docs/img/Mono araña.jfif.
-- Negra, esbelta y con el pecho más alto que la grupa; cabeza pequeña y redonda con la cara parda y el
-- hocico algo más claro; vientre pardo; brazos y piernas larguísimos y finos, manos en gancho sin
-- pulgar y una cola larguísima levantada en S con la punta doblada.
-- Tonos: "fur" (bodyColor) es el negro y "skin" (faceColor) el pardo de la cara y el vientre.
-- Los pivotes son los del modelo redondo de antes (spiderMonkey, ya borrado), para que valgan sus
-- animaciones.

local Shapes = require(script.Parent.Shapes)

local MUZZLE = Color3.fromRGB(95, 75, 62)
local EYE = Color3.fromRGB(190, 160, 130)
local MOUTH = Color3.fromRGB(25, 18, 15)

local function join(...: { any }): { any }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

return {
	-- 0,1 studs por celda a escala 1; con su scale mide ~1,65 studs sin la cola (GDD §8.2).
	unit = 0.1,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			pivot = { 0, 19, 1.5 },
			boxes = {
				-- Pecho alto y grupa más baja, en tres escalones.
				{ 0, 20, -2, 7, 7, 7, "fur" },
				{ 0, 18.5, 3.5, 6, 6, 6, "fur", "Waist" },
				{ 0, 17.2, 7.2, 6.6, 5.6, 3, "fur", "Hips" },
				{ 0, 16.6, 1.5, 4.6, 1, 8, "skin", "Belly" },
				{ 0, 19.5, -5.8, 4.6, 4.5, 0.6, "skin", "Bib" },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 21.5, -6 },
			boxes = {
				{ 0, 24.5, -9.5, 7, 7, 7, "fur" },
				{ 0, 28.3, -9.2, 5.6, 0.6, 5.4, "fur", "Cap" },
				{ 0, 24, -13.2, 5, 4.6, 0.5, "skin", "Face" },
				{ 1.2, 25, -13.55, 1, 0.8, 0.2, EYE, "Pupil", true },
				{ 0, 22.6, -13.9, 3, 1.8, 1, MUZZLE, "Muzzle" },
				{ 0, 22.3, -14.45, 1.8, 0.3, 0.1, MOUTH, "Mouth" },
				{ 3.7, 24.5, -9, 0.6, 1.6, 1.4, "skin", "Ear", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 3, 18.5, -3.5 },
			boxes = join({
				{ 3.4, 13.5, -3.8, 1.8, 10, 1.8, "fur" },
				{ 3.4, 17.6, -3.6, 2.4, 2.4, 2.4, "fur", "Deltoid" },
				{ 3.4, 4.8, -4.4, 1.6, 8.4, 1.6, "fur", "Forearm" },
				-- Mano en gancho: palma larga y dedos que se doblan hacia abajo, sin pulgar.
				{ 3.4, 0.9, -5.2, 2, 1, 2.6, "fur", "Hand" },
			}, Shapes.fingers(3.4, -6.5, 3, 0.5, 1.6, "fur")),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 3, 15.5, 6 },
			boxes = join({
				{ 3.3, 11.5, 6, 2.2, 8, 2.6, "fur" },
				{ 3.3, 4.4, 6.8, 1.8, 7, 1.8, "fur", "Shin" },
				{ 3.3, 0.6, 5.6, 2.2, 1.2, 3.6, "fur", "Foot" },
			}, Shapes.fingers(3.3, 3.8, 3, 0.5, 1.4, "fur")),
		},
		{
			name = "Tail",
			joint = "TailJoint",
			parent = "Torso",
			pivot = { 0, 19, 8.5 },
			-- Levantada en S, más alta que el mono, con la punta doblada hacia delante.
			boxes = Shapes.tail(
				{
					Vector3.new(0, 19, 9),
					Vector3.new(0, 24, 13),
					Vector3.new(0, 30, 15.5),
					Vector3.new(0, 36, 16),
					Vector3.new(0, 40, 14),
					Vector3.new(0, 41, 11),
					Vector3.new(0, 39, 9),
					Vector3.new(0, 37, 10),
				},
				1.2,
				0.75,
				1.5,
				function()
					return "fur"
				end
			),
		},
	},
}
