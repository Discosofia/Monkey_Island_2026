--!strict
-- Mallas con textura de las armaduras y los trajes (Fase 20 Q6, igual que PetMeshes). Las genera `tools/armadura.py` a
-- partir del volcado de `ServerStorage.Tools.Mallas.volcarArmadura` (la silueta en bloques gruesos y los detalles finos
-- pintados en la textura), se importan en Studio con Import 3D y aquí van sus ids. `ArmorModels.wear` sustituye por ellas
-- los bloques de cada grupo con entrada; un grupo sin entrada (o cuya malla aún no ha cargado) se queda en bloques.
-- Mientras las dos tablas estén vacías, el aspecto no cambia.
--   Armor[armorId][roleId]  y  Outfit[outfitId][grado]  (grado 0..4, el de la armadura con la que crece el traje).
-- Cada entrada es una malla por grupo `<Anclaje>_<Soft|Hard>`:
--   Anclaje: la parte R15 a la que van soldados los bloques (UpperTorso, LowerTorso, Left/RightUpperArm,
--            Left/RightLowerArm, Left/RightUpperLeg). La izquierda y la derecha NO se espejan.
--   Soft:    Fabric y Leather. Hard: el resto de materiales lisos. Neón, cristal, bolas, cilindros, óvalos, cuñas y los
--            bloques inclinados no entran: se quedan sueltos (`ArmorModels.meshableBox`).
--   ref:     tamaño de cada ancla en el rig de referencia del volcado; `wear` escala la malla eje a eje por
--            `ancla.Size / ref`, así queda bien en cualquier avatar.
--   offset:  centro de la caja envolvente de la malla respecto al origen del ancla (studs del rig de referencia).
--   size:    tamaño de esa caja (la malla se ajusta a él al colocarla).
-- El importador gira la malla 180° sobre Y; ArmorModels lo compensa.

export type GroupMesh = {
	mesh: string,
	texture: string,
	offset: Vector3,
	size: Vector3,
	triangles: number,
}
export type Entry = { ref: { [string]: Vector3 }, groups: { [string]: GroupMesh } }
export type ArmorMeshes = {
	Armor: { [string]: { [string]: Entry } },
	Outfit: { [string]: { [number]: Entry } },
}

-- Las entradas las escribe `tools/armadura.py ids`: van entre las marcas `-- @entrada` y `-- @fin`.
local ArmorMeshes: ArmorMeshes = {
	Armor = {
		FurVest = {
			-- @entrada Armor FurVest Guerrero
			Guerrero = {
				ref = {
					LeftLowerArm = Vector3.new(1.0011, 1.1175, 1.0019),
					LeftUpperArm = Vector3.new(1.0011, 1.2416, 1.0019),
					LeftUpperLeg = Vector3.new(0.9928, 1.3629, 0.9727),
					LowerTorso = Vector3.new(1.9914, 0.4007, 1.0040),
					RightLowerArm = Vector3.new(1.0011, 1.1175, 1.0019),
					RightUpperArm = Vector3.new(1.0011, 1.2416, 1.0019),
					RightUpperLeg = Vector3.new(0.9928, 1.3629, 0.9727),
					UpperTorso = Vector3.new(1.9432, 1.6980, 1.0040),
				},
				groups = {
					["LeftLowerArm_Soft"] = {
						mesh = "rbxassetid://114055427505297",
						texture = "rbxassetid://96423657664940",
						offset = Vector3.new(0.0000, -0.4135, 0.0000),
						size = Vector3.new(1.0611, 0.2565, 1.0619),
						triangles = 24,
					},
					["LeftUpperArm_Soft"] = {
						mesh = "rbxassetid://132522750754238",
						texture = "rbxassetid://117858981494819",
						offset = Vector3.new(-0.1000, 0.3660, 0.0000),
						size = Vector3.new(1.5011, 1.2298, 1.5019),
						triangles = 56,
					},
					["LeftUpperLeg_Soft"] = {
						mesh = "rbxassetid://116829134079810",
						texture = "rbxassetid://106779680380924",
						offset = Vector3.new(0.0000, 0.3297, -0.5364),
						size = Vector3.new(0.8936, 0.7033, 0.1100),
						triangles = 108,
					},
					["LowerTorso_Soft"] = {
						mesh = "rbxassetid://91176456766621",
						texture = "rbxassetid://129604692503656",
						offset = Vector3.new(0.0000, -0.0899, -0.0850),
						size = Vector3.new(2.1114, 0.4599, 1.2941),
						triangles = 84,
					},
					["RightLowerArm_Soft"] = {
						mesh = "rbxassetid://83340324145304",
						texture = "rbxassetid://105543271050447",
						offset = Vector3.new(0.0000, -0.4135, 0.0000),
						size = Vector3.new(1.0611, 0.2565, 1.0619),
						triangles = 24,
					},
					["RightUpperArm_Soft"] = {
						mesh = "rbxassetid://102747369812802",
						texture = "rbxassetid://117035528090300",
						offset = Vector3.new(0.1000, 0.3660, 0.0000),
						size = Vector3.new(1.5011, 1.2298, 1.5019),
						triangles = 56,
					},
					["RightUpperLeg_Soft"] = {
						mesh = "rbxassetid://122503528859893",
						texture = "rbxassetid://126446121809965",
						offset = Vector3.new(0.0000, 0.3297, -0.5364),
						size = Vector3.new(0.8936, 0.7033, 0.1100),
						triangles = 108,
					},
					["UpperTorso_Soft"] = {
						mesh = "rbxassetid://100426642402525",
						texture = "rbxassetid://98215364392127",
						offset = Vector3.new(0.0000, -0.0099, 0.0649),
						size = Vector3.new(2.2432, 2.3181, 1.4540),
						triangles = 778,
					},
				},
			},
			-- @fin
		},
	},
	Outfit = {},
}

return ArmorMeshes
