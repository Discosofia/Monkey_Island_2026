--!strict
-- Mono ardilla (Saimiri) en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el formato de las
-- cajas está explicado en VoxelSpecs/Gorila. Referencia: docs/img/Mono ardilla.jfif.
-- Gris verdoso con una montura ocre en el lomo; antebrazos, espinillas, manos y pies ocres; máscara
-- blanca alrededor de los ojos, hocico negro que sobresale, orejas crema y una cola larga con la
-- punta negra. Tonos: "fur" (bodyColor) es el ocre y "skin" (faceColor) el blanco de la máscara.
-- Los pivotes son los del modelo redondo de antes (squirrelMonkey, ya borrado), para que valgan sus animaciones.

local Shapes = require(script.Parent.Shapes)

local GREEN = Color3.fromRGB(122, 134, 110)
local CAP = Color3.fromRGB(104, 115, 94)
local PALE = Color3.fromRGB(200, 204, 172)
local CREAM = Color3.fromRGB(228, 212, 168)
local BLACK = Color3.fromRGB(28, 26, 24)
local EYE = Color3.fromRGB(25, 20, 18)

local function join(...: { any }): { any }
	local all = {}
	for _, list in { ... } do
		table.move(list, 1, #list, #all + 1, all)
	end
	return all
end

return {
	-- 0,1 studs por celda a escala 1; con su scale mide ~1,5 studs (GDD §8.2).
	unit = 0.1,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			pivot = { 0, 16, 2.5 },
			boxes = {
				{ 0, 16, 2, 7.6, 7, 16, GREEN },
				{ 0, 16.3, -4, 8.2, 6, 4.5, GREEN, "Shoulders" },
				-- Montura ocre: placa encima, costados que asoman y un escalón detrás.
				{ 0, 19.9, 4, 6.8, 0.8, 7, "fur", "Saddle" },
				{ 0, 18.3, 4, 8, 2.6, 6, "fur", "Saddle" },
				{ 0, 19.9, 8.5, 4.4, 0.8, 2, "fur", "Saddle" },
				{ 0, 16.5, 10.3, 7, 6, 1.4, GREEN, "Rump" },
				{ 0, 12.3, 2, 6, 1, 12, PALE, "Belly" },
				{ 0, 15, -6.55, 5.2, 4.5, 0.6, PALE, "Bib" },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 17, -7 },
			boxes = {
				{ 0, 20.5, -10, 7.6, 7.4, 7.4, GREEN },
				{ 0, 24.4, -9.5, 7, 0.6, 6.6, CAP, "Cap" },
				{ 0, 24.9, -9, 4.6, 0.5, 4.4, CAP, "Cap" },
				-- Máscara: un recuadro blanco por ojo y una franja debajo que los une.
				{ 1.8, 20.8, -13.95, 3, 3.6, 0.5, "skin", "Mask", true },
				{ 0, 18.4, -13.95, 6.4, 1.6, 0.5, "skin", "Mask" },
				{ 1.8, 21, -14.3, 1, 1, 0.2, EYE, "Pupil", true },
				{ 0, 18.6, -14.9, 3.4, 2.4, 1.8, BLACK, "Muzzle" },
				{ 4.1, 20.8, -9.5, 0.6, 2, 1.6, CREAM, "Ear", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 3.6, 14, -5 },
			boxes = join({
				{ 3.6, 10.5, -5, 2.4, 7, 2.4, GREEN },
				{ 3.6, 4.5, -5.3, 2.2, 6, 2.2, "fur", "Forearm" },
				{ 3.6, 0.6, -5.9, 2.6, 1.2, 2.6, "fur", "Hand" },
			}, Shapes.fingers(3.6, -7.2, 3, 0.6, 1.2, "fur")),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 3.8, 14.5, 9 },
			boxes = join({
				{ 3.9, 11.5, 8.8, 2.8, 6.4, 3.6, GREEN },
				{ 3.9, 5, 9.6, 2.2, 6.6, 2.2, "fur", "Shin" },
				{ 3.9, 0.6, 8.4, 2.6, 1.2, 4.2, "fur", "Foot" },
			}, Shapes.fingers(3.9, 6.3, 3, 0.6, 1.2, "fur")),
		},
		{
			name = "Tail",
			joint = "TailJoint",
			parent = "Torso",
			pivot = { 0, 17, 11 },
			-- Larga y hacia atrás; baja y levanta un poco la punta negra.
			boxes = Shapes.tail(
				{
					Vector3.new(0, 17, 11.5),
					Vector3.new(0, 15, 17),
					Vector3.new(0, 11, 22),
					Vector3.new(0, 9, 27),
					Vector3.new(0, 10, 32),
					Vector3.new(0, 12, 35),
				},
				1.3,
				0.8,
				1.6,
				function(index: number, count: number)
					return if index > count - 3 then BLACK else GREEN
				end
			),
		},
	},
}
