--!strict
-- Mallas con textura de los huesos de las monturas (Fase 21, igual que BossMeshes). Las genera `tools/mallas.py` a
-- partir del volcado de `ServerStorage.Tools.Mallas.volcarMontura` (la silueta en bloques gruesos y los detalles finos
-- pintados en la textura), se importan en Studio con Import 3D y aquí van sus ids. `MountModels.build` sustituye por
-- ellas las cajas de ese hueso; si falta el id (o la malla no carga), el hueso se queda con sus cajas.
--   scale:  `size` de la montura (Data/Mounts) con el que se volcaron los bloques.
--   offset: centro de la caja envolvente de la malla respecto al hueso (su pieza invisible), en studs a esa escala.
-- El importador gira la malla 180° sobre Y; MountModels lo compensa.

export type PartMesh = { mesh: string, texture: string, triangles: number, offset: Vector3 }
export type MountMesh = { scale: number, parts: { [string]: PartMesh } }

local MountMeshes: { [string]: MountMesh } = {
	Llama = {
		scale = 1,
		parts = {
			["Body"] = {
				mesh = "rbxassetid://107685012699738",
				texture = "rbxassetid://138461275947809",
				triangles = 500,
				offset = Vector3.new(0.0, -0.07, 0.14),
			},
			["EarL"] = {
				mesh = "rbxassetid://117481163547242",
				texture = "rbxassetid://122983669570005",
				triangles = 60,
				offset = Vector3.new(0.045, 0.54, -0.02),
			},
			["EarR"] = {
				mesh = "rbxassetid://100476230182633",
				texture = "rbxassetid://100221682725598",
				triangles = 60,
				offset = Vector3.new(-0.045, 0.54, -0.02),
			},
			["Head"] = {
				mesh = "rbxassetid://113425429231191",
				texture = "rbxassetid://118824112135169",
				triangles = 278,
				offset = Vector3.new(0.0, 0.44, -0.44),
			},
			["Jaw"] = {
				mesh = "rbxassetid://80848137089961",
				texture = "rbxassetid://72842792904670",
				triangles = 96,
				offset = Vector3.new(0.0, 0.07, -0.28),
			},
			["LegBL"] = {
				mesh = "rbxassetid://96329937420961",
				texture = "rbxassetid://76013000817734",
				triangles = 12,
				offset = Vector3.new(0.0, -0.48, 0.0),
			},
			["LegBR"] = {
				mesh = "rbxassetid://96329937420961",
				texture = "rbxassetid://106568835186299",
				triangles = 12,
				offset = Vector3.new(0.0, -0.48, 0.0),
			},
			["LegFL"] = {
				mesh = "rbxassetid://118307142376380",
				texture = "rbxassetid://71767217248799",
				triangles = 12,
				offset = Vector3.new(0.0, -0.48, 0.0),
			},
			["LegFR"] = {
				mesh = "rbxassetid://118307142376380",
				texture = "rbxassetid://97980634103962",
				triangles = 12,
				offset = Vector3.new(0.0, -0.48, 0.0),
			},
			["Neck"] = {
				mesh = "rbxassetid://91587507165296",
				texture = "rbxassetid://108785104850705",
				triangles = 376,
				offset = Vector3.new(0.0, 0.7425, -0.0525),
			},
			["ShinBL"] = {
				mesh = "rbxassetid://139916469539801",
				texture = "rbxassetid://131847716287235",
				triangles = 74,
				offset = Vector3.new(0.0, -0.65, -0.035),
			},
			["ShinBR"] = {
				mesh = "rbxassetid://115955342848969",
				texture = "rbxassetid://133275734618049",
				triangles = 74,
				offset = Vector3.new(0.0, -0.65, -0.035),
			},
			["ShinFL"] = {
				mesh = "rbxassetid://139916469539801",
				texture = "rbxassetid://131847716287235",
				triangles = 74,
				offset = Vector3.new(0.0, -0.65, -0.035),
			},
			["ShinFR"] = {
				mesh = "rbxassetid://115955342848969",
				texture = "rbxassetid://133275734618049",
				triangles = 74,
				offset = Vector3.new(0.0, -0.65, -0.035),
			},
			["Tail"] = {
				mesh = "rbxassetid://103467289370334",
				texture = "rbxassetid://105968462656507",
				triangles = 60,
				offset = Vector3.new(0.0, 0.22, 0.14),
			},
		},
	},
	Jaguar = {
		scale = 1.1,
		parts = {
			["Body"] = {
				mesh = "rbxassetid://125451170457758",
				texture = "rbxassetid://106636468672649",
				triangles = 850,
				offset = Vector3.new(0.0000, -0.0990, -0.2475),
			},
			["EarL"] = {
				mesh = "rbxassetid://83004076565492",
				texture = "rbxassetid://75029978410519",
				triangles = 36,
				offset = Vector3.new(0.0000, 0.2695, 0.0000),
			},
			["EarR"] = {
				mesh = "rbxassetid://137319375650693",
				texture = "rbxassetid://116297795548724",
				triangles = 36,
				offset = Vector3.new(0.0000, 0.2695, 0.0000),
			},
			["Head"] = {
				mesh = "rbxassetid://91871561014175",
				texture = "rbxassetid://80945704298653",
				triangles = 1132,
				offset = Vector3.new(0.0000, -0.2035, -0.7425),
			},
			["Jaw"] = {
				mesh = "rbxassetid://79224341398908",
				texture = "rbxassetid://115583132950783",
				triangles = 104,
				offset = Vector3.new(0.0000, -0.1430, -0.3960),
			},
			["LegBL"] = {
				mesh = "rbxassetid://132693781152986",
				texture = "rbxassetid://110551336187334",
				triangles = 132,
				offset = Vector3.new(0.0000, -0.6600, -0.0440),
			},
			["LegBR"] = {
				mesh = "rbxassetid://95797457657049",
				texture = "rbxassetid://124373241126121",
				triangles = 132,
				offset = Vector3.new(0.0000, -0.6600, -0.0440),
			},
			["LegFL"] = {
				mesh = "rbxassetid://94352836408399",
				texture = "rbxassetid://98804631365882",
				triangles = 104,
				offset = Vector3.new(-0.0385, -0.6160, 0.0660),
			},
			["LegFR"] = {
				mesh = "rbxassetid://94525411903022",
				texture = "rbxassetid://137092608016507",
				triangles = 104,
				offset = Vector3.new(0.0385, -0.6160, 0.0660),
			},
			["Neck"] = {
				mesh = "rbxassetid://101582834546782",
				texture = "rbxassetid://116775172127158",
				triangles = 570,
				offset = Vector3.new(0.0000, -0.2970, -0.2310),
			},
			["ShinBL"] = {
				mesh = "rbxassetid://114648706051156",
				texture = "rbxassetid://86501539141868",
				triangles = 124,
				offset = Vector3.new(0.0000, -0.7590, -0.0165),
			},
			["ShinBR"] = {
				mesh = "rbxassetid://76859130723950",
				texture = "rbxassetid://137643768987026",
				triangles = 124,
				offset = Vector3.new(0.0000, -0.7590, -0.0165),
			},
			["ShinFL"] = {
				mesh = "rbxassetid://73588088723551",
				texture = "rbxassetid://112817884065366",
				triangles = 166,
				offset = Vector3.new(0.0000, -0.7370, -0.1375),
			},
			["ShinFR"] = {
				mesh = "rbxassetid://77609488627352",
				texture = "rbxassetid://78851702767896",
				triangles = 166,
				offset = Vector3.new(0.0000, -0.7370, -0.1375),
			},
			["Tail"] = {
				mesh = "rbxassetid://134246455275202",
				texture = "rbxassetid://110072818954728",
				triangles = 116,
				offset = Vector3.new(0.0000, -0.1815, 0.6050),
			},
			["Tail2"] = {
				mesh = "rbxassetid://112559243727289",
				texture = "rbxassetid://136364985072532",
				triangles = 140,
				offset = Vector3.new(0.0000, -0.1705, 0.4840),
			},
			["Tail3"] = {
				mesh = "rbxassetid://87192976047910",
				texture = "rbxassetid://101818595656001",
				triangles = 132,
				offset = Vector3.new(0.0000, 0.2970, 0.1485),
			},
		},
	},
	Quetzalcoatl = {
		scale = 0.9,
		parts = {
			["Body"] = {
				mesh = "rbxassetid://94805314311406",
				texture = "rbxassetid://88573331031598",
				triangles = 556,
				offset = Vector3.new(0.0000, 0.1844, 0.0180),
			},
			["Head"] = {
				mesh = "rbxassetid://73609206752254",
				texture = "rbxassetid://125957501306755",
				triangles = 1148,
				offset = Vector3.new(0.0000, 0.7839, -1.6906),
			},
			["Jaw"] = {
				mesh = "rbxassetid://76084750047500",
				texture = "rbxassetid://133055591329218",
				triangles = 334,
				offset = Vector3.new(0.0000, -0.2515, -0.8190),
			},
			["Neck"] = {
				mesh = "rbxassetid://85531143293346",
				texture = "rbxassetid://110999353832947",
				triangles = 228,
				offset = Vector3.new(0.0000, 0.4630, -0.8100),
			},
			["Seg1"] = {
				mesh = "rbxassetid://76153923522877",
				texture = "rbxassetid://95759193109753",
				triangles = 348,
				offset = Vector3.new(0.0000, 0.0220, 1.2420),
			},
			["Seg2"] = {
				mesh = "rbxassetid://103409133188488",
				texture = "rbxassetid://136749424835415",
				triangles = 348,
				offset = Vector3.new(0.0000, 0.0501, 1.2420),
			},
			["Seg3"] = {
				mesh = "rbxassetid://87075220867598",
				texture = "rbxassetid://101835220928046",
				triangles = 252,
				offset = Vector3.new(0.0000, 0.0810, 1.1520),
			},
			["Seg4"] = {
				mesh = "rbxassetid://72269979550701",
				texture = "rbxassetid://91253535705837",
				triangles = 400,
				offset = Vector3.new(0.0000, 0.1298, 1.0620),
			},
			["Seg5"] = {
				mesh = "rbxassetid://125016025754876",
				texture = "rbxassetid://98775186054839",
				triangles = 188,
				offset = Vector3.new(0.0000, 0.1025, 0.7200),
			},
			["TailFan"] = {
				mesh = "rbxassetid://98388733335990",
				texture = "rbxassetid://102228566997528",
				triangles = 28,
				offset = Vector3.new(0.0000, 0.0000, 0.7344),
			},
			["Tongue"] = {
				mesh = "rbxassetid://84933010573896",
				texture = "rbxassetid://82972361583276",
				triangles = 12,
				offset = Vector3.new(0.0000, 0.0000, -0.7020),
			},
		},
	},
}

return MountMeshes
