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
		BoneArmor = {
			-- @entrada Armor BoneArmor Guerrero
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
					["LeftLowerArm_Hard"] = {
						mesh = "rbxassetid://97344471145607",
						texture = "rbxassetid://103637689168350",
						offset = Vector3.new(-0.5705, -0.0200, 0.0000),
						size = Vector3.new(0.0800, 0.5588, 0.7410),
						triangles = 36,
					},
					["LeftLowerArm_Soft"] = {
						mesh = "rbxassetid://99371337319823",
						texture = "rbxassetid://81822476428994",
						offset = Vector3.new(0.0000, -0.0200, 0.0000),
						size = Vector3.new(1.1211, 0.6705, 1.1219),
						triangles = 76,
					},
					["LeftUpperArm_Hard"] = {
						mesh = "rbxassetid://88474076976202",
						texture = "rbxassetid://137311725829175",
						offset = Vector3.new(-0.2002, 1.1608, -0.0160),
						size = Vector3.new(0.6400, 0.5922, 0.8161),
						triangles = 150,
					},
					["LeftUpperArm_Soft"] = {
						mesh = "rbxassetid://90069811831053",
						texture = "rbxassetid://77002081485854",
						offset = Vector3.new(-0.1000, 0.3660, 0.0000),
						size = Vector3.new(1.5011, 1.2298, 1.5019),
						triangles = 56,
					},
					["LeftUpperLeg_Hard"] = {
						mesh = "rbxassetid://127519051418412",
						texture = "rbxassetid://107516909608486",
						offset = Vector3.new(-0.0400, 0.3327, -0.5864),
						size = Vector3.new(0.6560, 0.6030, 0.1000),
						triangles = 60,
					},
					["LeftUpperLeg_Soft"] = {
						mesh = "rbxassetid://125456563302096",
						texture = "rbxassetid://113637752677818",
						offset = Vector3.new(-0.0400, 0.4497, -0.5364),
						size = Vector3.new(0.8439, 0.4907, 0.0800),
						triangles = 12,
					},
					["LowerTorso_Hard"] = {
						mesh = "rbxassetid://109438389639791",
						texture = "rbxassetid://89097868636341",
						offset = Vector3.new(0.0000, 0.0801, -0.6721),
						size = Vector3.new(1.3746, 0.3000, 0.2599),
						triangles = 48,
					},
					["LowerTorso_Soft"] = {
						mesh = "rbxassetid://100748981604432",
						texture = "rbxassetid://71970520035992",
						offset = Vector3.new(0.0000, -0.0599, -0.0376),
						size = Vector3.new(2.1314, 0.5000, 1.2191),
						triangles = 36,
					},
					["RightLowerArm_Hard"] = {
						mesh = "rbxassetid://124982661810137",
						texture = "rbxassetid://125920144497596",
						offset = Vector3.new(0.5705, -0.0200, 0.0000),
						size = Vector3.new(0.0800, 0.5588, 0.7410),
						triangles = 36,
					},
					["RightLowerArm_Soft"] = {
						mesh = "rbxassetid://127565397093657",
						texture = "rbxassetid://105403828786547",
						offset = Vector3.new(0.0000, -0.0200, 0.0000),
						size = Vector3.new(1.1211, 0.6705, 1.1219),
						triangles = 76,
					},
					["RightUpperArm_Hard"] = {
						mesh = "rbxassetid://82109483397963",
						texture = "rbxassetid://99312324118386",
						offset = Vector3.new(0.2002, 1.1608, -0.0160),
						size = Vector3.new(0.6400, 0.5922, 0.8161),
						triangles = 150,
					},
					["RightUpperArm_Soft"] = {
						mesh = "rbxassetid://112706664990800",
						texture = "rbxassetid://106722594544574",
						offset = Vector3.new(0.1000, 0.3660, 0.0000),
						size = Vector3.new(1.5011, 1.2298, 1.5019),
						triangles = 56,
					},
					["RightUpperLeg_Hard"] = {
						mesh = "rbxassetid://74557319789699",
						texture = "rbxassetid://106582851588704",
						offset = Vector3.new(0.0400, 0.3327, -0.5864),
						size = Vector3.new(0.6560, 0.6030, 0.1000),
						triangles = 60,
					},
					["RightUpperLeg_Soft"] = {
						mesh = "rbxassetid://107277598910736",
						texture = "rbxassetid://128037550369429",
						offset = Vector3.new(0.0400, 0.4497, -0.5364),
						size = Vector3.new(0.8439, 0.4907, 0.0800),
						triangles = 12,
					},
					["UpperTorso_Hard"] = {
						mesh = "rbxassetid://135731115264505",
						texture = "rbxassetid://116975475936534",
						offset = Vector3.new(0.0485, -0.0253, 0.4776),
						size = Vector3.new(2.0209, 1.6740, 2.3994),
						triangles = 1818,
					},
					["UpperTorso_Soft"] = {
						mesh = "rbxassetid://111093402516927",
						texture = "rbxassetid://132443269412358",
						offset = Vector3.new(0.0000, -0.1224, 0.0851),
						size = Vector3.new(2.0432, 2.0931, 1.6940),
						triangles = 316,
					},
				},
			},
			-- @fin
		},
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
		SilverArmor = {
			-- @entrada Armor SilverArmor Guerrero
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
					["LeftLowerArm_Hard"] = {
						mesh = "rbxassetid://130287002466716",
						texture = "rbxassetid://96588643397370",
						offset = Vector3.new(-0.5805, 0.0500, 0.0000),
						size = Vector3.new(0.1200, 0.6705, 0.7514),
						triangles = 12,
					},
					["LeftLowerArm_Soft"] = {
						mesh = "rbxassetid://74478631036841",
						texture = "rbxassetid://111370425566200",
						offset = Vector3.new(0.0000, -0.0957, 0.0000),
						size = Vector3.new(1.1611, 0.9060, 1.1619),
						triangles = 24,
					},
					["LeftUpperArm_Hard"] = {
						mesh = "rbxassetid://75684597189703",
						texture = "rbxassetid://137668973489689",
						offset = Vector3.new(-0.2300, 0.8728, 0.0000),
						size = Vector3.new(1.2110, 1.1038, 1.4562),
						triangles = 574,
					},
					["LeftUpperArm_Soft"] = {
						mesh = "rbxassetid://121615220739375",
						texture = "rbxassetid://111468884719660",
						offset = Vector3.new(-0.1200, 0.1492, 0.0000),
						size = Vector3.new(1.5011, 1.1435, 1.5019),
						triangles = 36,
					},
					["LeftUpperLeg_Hard"] = {
						mesh = "rbxassetid://84839500265630",
						texture = "rbxassetid://122675352640429",
						offset = Vector3.new(-0.0400, 0.4426, -0.6165),
						size = Vector3.new(0.8142, 0.4089, 0.0800),
						triangles = 36,
					},
					["LeftUpperLeg_Soft"] = {
						mesh = "rbxassetid://84930460835346",
						texture = "rbxassetid://78699491186091",
						offset = Vector3.new(-0.0400, 0.3276, -0.5564),
						size = Vector3.new(0.8936, 0.7353, 0.1200),
						triangles = 106,
					},
					["LowerTorso_Hard"] = {
						mesh = "rbxassetid://121724545916967",
						texture = "rbxassetid://106046986315916",
						offset = Vector3.new(0.0000, 0.0851, -0.7619),
						size = Vector3.new(0.4000, 0.3701, 0.5100),
						triangles = 150,
					},
					["LowerTorso_Soft"] = {
						mesh = "rbxassetid://85325648812097",
						texture = "rbxassetid://133831569549626",
						offset = Vector3.new(0.0000, 0.0601, 0.0000),
						size = Vector3.new(2.1514, 0.2800, 1.1840),
						triangles = 12,
					},
					["RightLowerArm_Hard"] = {
						mesh = "rbxassetid://85819286538007",
						texture = "rbxassetid://94832349194208",
						offset = Vector3.new(0.5805, 0.0500, 0.0000),
						size = Vector3.new(0.1200, 0.6705, 0.7514),
						triangles = 12,
					},
					["RightLowerArm_Soft"] = {
						mesh = "rbxassetid://76874956343686",
						texture = "rbxassetid://130246670197259",
						offset = Vector3.new(0.0000, -0.0957, 0.0000),
						size = Vector3.new(1.1611, 0.9060, 1.1619),
						triangles = 24,
					},
					["RightUpperArm_Hard"] = {
						mesh = "rbxassetid://116837191654873",
						texture = "rbxassetid://130805073122641",
						offset = Vector3.new(0.2300, 0.8728, 0.0000),
						size = Vector3.new(1.2110, 1.1038, 1.4562),
						triangles = 574,
					},
					["RightUpperArm_Soft"] = {
						mesh = "rbxassetid://139536466859588",
						texture = "rbxassetid://100117260623941",
						offset = Vector3.new(0.1200, 0.1492, 0.0000),
						size = Vector3.new(1.5011, 1.1435, 1.5019),
						triangles = 36,
					},
					["RightUpperLeg_Hard"] = {
						mesh = "rbxassetid://73818808634311",
						texture = "rbxassetid://97814171050664",
						offset = Vector3.new(0.0400, 0.4426, -0.6165),
						size = Vector3.new(0.8142, 0.4089, 0.0800),
						triangles = 36,
					},
					["RightUpperLeg_Soft"] = {
						mesh = "rbxassetid://75519412366526",
						texture = "rbxassetid://101255846199794",
						offset = Vector3.new(0.0400, 0.3276, -0.5564),
						size = Vector3.new(0.8936, 0.7353, 0.1200),
						triangles = 106,
					},
					["UpperTorso_Hard"] = {
						mesh = "rbxassetid://109077943140091",
						texture = "rbxassetid://80041392232936",
						offset = Vector3.new(0.0000, -0.0935, 0.1956),
						size = Vector3.new(1.7700, 1.3756, 1.8750),
						triangles = 362,
					},
					["UpperTorso_Soft"] = {
						mesh = "rbxassetid://136999968860864",
						texture = "rbxassetid://87013939468669",
						offset = Vector3.new(0.0000, 0.1331, 0.1364),
						size = Vector3.new(2.3432, 3.1118, 1.5766),
						triangles = 774,
					},
				},
			},
			-- @fin
		},
		VolcanicArmor = {
			-- @entrada Armor VolcanicArmor Guerrero
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
					["LeftLowerArm_Hard"] = {
						mesh = "rbxassetid://78099135247470",
						texture = "rbxassetid://71543455600900",
						offset = Vector3.new(0.0000, -0.0567, 0.0000),
						size = Vector3.new(1.1411, 0.8840, 1.1419),
						triangles = 24,
					},
					["LeftUpperArm_Hard"] = {
						mesh = "rbxassetid://97317645146060",
						texture = "rbxassetid://75250376812882",
						offset = Vector3.new(-0.1000, 0.4860, 0.0000),
						size = Vector3.new(1.5011, 1.4298, 1.5019),
						triangles = 506,
					},
					["LeftUpperLeg_Hard"] = {
						mesh = "rbxassetid://70796782896750",
						texture = "rbxassetid://98175169985954",
						offset = Vector3.new(-0.0400, 0.4089, -0.5815),
						size = Vector3.new(0.8936, 0.5997, 0.1701),
						triangles = 28,
					},
					["LowerTorso_Hard"] = {
						mesh = "rbxassetid://110674864580390",
						texture = "rbxassetid://72336384994766",
						offset = Vector3.new(0.0000, 0.0728, -0.2162),
						size = Vector3.new(2.1514, 0.4254, 1.6164),
						triangles = 100,
					},
					["RightLowerArm_Hard"] = {
						mesh = "rbxassetid://107864970469283",
						texture = "rbxassetid://75111196693664",
						offset = Vector3.new(0.0000, -0.0567, 0.0000),
						size = Vector3.new(1.1411, 0.8840, 1.1419),
						triangles = 24,
					},
					["RightUpperArm_Hard"] = {
						mesh = "rbxassetid://101546021676759",
						texture = "rbxassetid://104825351342918",
						offset = Vector3.new(0.1000, 0.4860, 0.0000),
						size = Vector3.new(1.5011, 1.4298, 1.5019),
						triangles = 506,
					},
					["RightUpperLeg_Hard"] = {
						mesh = "rbxassetid://72509780898781",
						texture = "rbxassetid://140059629372746",
						offset = Vector3.new(0.0400, 0.4089, -0.5815),
						size = Vector3.new(0.8936, 0.5997, 0.1701),
						triangles = 28,
					},
					["UpperTorso_Hard"] = {
						mesh = "rbxassetid://105473956351169",
						texture = "rbxassetid://87889927719768",
						offset = Vector3.new(0.0000, 0.1315, 0.0475),
						size = Vector3.new(2.0832, 2.1151, 1.9392),
						triangles = 1366,
					},
				},
			},
			-- @fin
		},
	},
	Outfit = {},
}

return ArmorMeshes
