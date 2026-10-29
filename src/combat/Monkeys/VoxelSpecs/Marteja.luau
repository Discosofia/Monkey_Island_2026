--!strict
-- Marteja (mono nocturno) en estilo voxel. Lo construye MonkeyModels.voxelMonkey; el formato de las
-- cajas está explicado en VoxelSpecs/Gorila. Referencia: docs/img/Marteja.jfif.
-- Pequeña, redonda y lanuda, gris con el lomo en escalones; pecho, vientre y hombros ocres; cara
-- blanca con dos manchas negras enormes alrededor de los ojos y tres rayas oscuras (una en medio y una
-- a cada lado); hocico y orejas pardos, manos y pies pardos y una cola gruesa y parda, levantada.
-- Los ojos (cajas "Eye", con glowEyes) son de neón: es la especie de la noche y se le ven los ojos.
-- Tonos: "fur" (bodyColor) es el gris y "skin" (faceColor) el blanco de la cara.
-- Los pivotes son los del modelo redondo de antes (nightMonkey, ya borrado), para que valgan sus
-- animaciones.

local Shapes = require(script.Parent.Shapes)

local OCHRE = Color3.fromRGB(190, 145, 60)
local BROWN = Color3.fromRGB(95, 78, 68)
local BLACK = Color3.fromRGB(22, 20, 20)
local STRIPE = Color3.fromRGB(60, 50, 44)
local AMBER = Color3.fromRGB(255, 140, 40)

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
	glowEyes = true,
	parts = {
		{
			name = "Torso",
			joint = "RootJoint",
			pivot = { 0, 16, 2 },
			boxes = {
				{ 0, 15.5, 2, 9, 8, 15, "fur" },
				-- Lomo lanudo en dos escalones.
				{ 0, 20, 2.5, 7.4, 1.2, 12, "shag", "Back" },
				{ 0, 21, 3, 5, 0.8, 8, "shag", "Back" },
				-- Ocre: banda sobre los hombros, pecho y vientre.
				{ 0, 15.8, -4, 9.6, 6.5, 4, OCHRE, "Mantle" },
				{ 0, 14.5, -6.2, 6, 5, 0.6, OCHRE, "Bib" },
				{ 0, 11.1, 2, 7, 1, 11, OCHRE, "Belly" },
				{ 0, 15.5, 9.9, 8, 7, 1, "fur", "Rump" },
			},
		},
		{
			name = "Head",
			joint = "Neck",
			parent = "Torso",
			pivot = { 0, 17.5, -7 },
			boxes = {
				{ 0, 21, -11, 9.5, 8.5, 8, "fur" },
				{ 0, 25.6, -10.5, 8, 0.8, 6.5, "fur", "Cap" },
				{ 0, 20.6, -15.2, 8.6, 6.8, 0.5, "skin", "Face" },
				-- Ojos enormes: mancha negra y ojo de neón, sin pupila. Con la escala del juego, una pupila de
				-- menos de una celda salía como un bloque verde translúcido, y un ojo de menos de dos celdas
				-- de fondo, verde.
				{ 2.2, 21, -15.6, 3.2, 3.2, 0.4, BLACK, "Socket", true },
				{ 2.2, 21, -15.2, 1.8, 1.8, 2, AMBER, "Eye", true },
				-- Marcas tripartitas: raya en medio de la frente y una a cada lado.
				{ 0, 23.8, -15.3, 1, 2.8, 0.8, STRIPE, "Stripe" },
				{ 3.4, 24.4, -15.2, 0.9, 1.6, 0.6, STRIPE, "Stripe", true },
				{ 0, 18.2, -15.9, 3.4, 2.4, 1.4, BROWN, "Muzzle" },
				{ 0, 19, -16.65, 1.4, 0.7, 0.2, BLACK, "Nose" },
				{ 4.9, 22, -9.5, 0.6, 2.2, 2, BROWN, "Ear", true },
			},
		},
		{
			name = "Arm",
			joint = "Shoulder",
			parent = "Torso",
			mirror = true,
			pivot = { 3.8, 14, -5 },
			boxes = join({
				{ 3.8, 10.5, -5, 2.4, 7, 2.4, "fur" },
				{ 3.8, 13.6, -5, 3, 2.6, 3, OCHRE, "Deltoid" },
				{ 3.8, 4.4, -5.3, 2, 6, 2, "fur", "Forearm" },
				{ 3.8, 0.6, -5.9, 2.6, 1.2, 2.6, BROWN, "Hand" },
			}, Shapes.fingers(3.8, -7.2, 3, 0.6, 1.2, BROWN)),
		},
		{
			name = "Leg",
			joint = "Hip",
			parent = "Torso",
			mirror = true,
			pivot = { 3.8, 14.5, 8 },
			boxes = join({
				{ 3.9, 11.5, 7.8, 3, 6.6, 3.8, "fur" },
				{ 3.9, 4.8, 8.6, 2.2, 6.6, 2.2, "fur", "Shin" },
				{ 3.9, 0.6, 7.4, 2.6, 1.2, 4.4, BROWN, "Foot" },
			}, Shapes.fingers(3.9, 5.2, 3, 0.6, 1.3, BROWN)),
		},
		{
			name = "Tail",
			joint = "TailJoint",
			parent = "Torso",
			pivot = { 0, 17.5, 10.5 },
			-- Gruesa y poblada, levantada hacia atrás para equilibrarse.
			boxes = Shapes.tail(
				{
					Vector3.new(0, 17.5, 11),
					Vector3.new(0, 20, 15),
					Vector3.new(0, 23, 19),
					Vector3.new(0, 25.5, 23),
					Vector3.new(0, 27, 26),
				},
				2.4,
				0.85,
				1.8,
				function()
					return BROWN
				end
			),
		},
	},
}
