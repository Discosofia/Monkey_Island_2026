--!strict
-- Mallas con textura de los huesos de las monturas (Fase 21, igual que BossMeshes). Las genera `tools/mallas.py` a
-- partir del volcado de `ServerStorage.Tools.Mallas.volcarMontura` (la silueta en bloques gruesos y los detalles finos
-- pintados en la textura), se importan en Studio con Import 3D y aquí van sus ids. `MountModels.build` sustituye por
-- ellas las cajas de ese hueso; si falta el id (o la malla no carga), el hueso se queda con sus cajas.
--   scale:  `size` de la montura (Data/Mounts) con el que se volcaron los bloques.
--   offset: centro de la caja envolvente de la malla respecto al hueso (su pieza invisible), en studs a esa escala.
-- El importador gira la malla 180° sobre Y; MountModels lo compensa.

export type PartMesh = { mesh: string, texture: string, offset: Vector3 }
export type MountMesh = { scale: number, parts: { [string]: PartMesh } }

local MountMeshes: { [string]: MountMesh } = {
	Llama = {
		scale = 1,
		parts = {
			["Body"] = {
				mesh = "rbxassetid://107685012699738",
				texture = "rbxassetid://138461275947809",
				offset = Vector3.new(0.0, -0.07, 0.14),
			},
			["EarL"] = {
				mesh = "rbxassetid://117481163547242",
				texture = "rbxassetid://122983669570005",
				offset = Vector3.new(0.045, 0.54, -0.02),
			},
			["EarR"] = {
				mesh = "rbxassetid://100476230182633",
				texture = "rbxassetid://100221682725598",
				offset = Vector3.new(-0.045, 0.54, -0.02),
			},
			["Head"] = {
				mesh = "rbxassetid://113425429231191",
				texture = "rbxassetid://118824112135169",
				offset = Vector3.new(0.0, 0.44, -0.44),
			},
			["Jaw"] = {
				mesh = "rbxassetid://80848137089961",
				texture = "rbxassetid://72842792904670",
				offset = Vector3.new(0.0, 0.07, -0.28),
			},
			["LegBL"] = {
				mesh = "rbxassetid://96329937420961",
				texture = "rbxassetid://76013000817734",
				offset = Vector3.new(0.0, -0.48, 0.0),
			},
			["LegBR"] = {
				mesh = "rbxassetid://96329937420961",
				texture = "rbxassetid://106568835186299",
				offset = Vector3.new(0.0, -0.48, 0.0),
			},
			["LegFL"] = {
				mesh = "rbxassetid://118307142376380",
				texture = "rbxassetid://71767217248799",
				offset = Vector3.new(0.0, -0.48, 0.0),
			},
			["LegFR"] = {
				mesh = "rbxassetid://118307142376380",
				texture = "rbxassetid://97980634103962",
				offset = Vector3.new(0.0, -0.48, 0.0),
			},
			["Neck"] = {
				mesh = "rbxassetid://91587507165296",
				texture = "rbxassetid://108785104850705",
				offset = Vector3.new(0.0, 0.7425, -0.0525),
			},
			["ShinBL"] = {
				mesh = "rbxassetid://139916469539801",
				texture = "rbxassetid://131847716287235",
				offset = Vector3.new(0.0, -0.65, -0.035),
			},
			["ShinBR"] = {
				mesh = "rbxassetid://115955342848969",
				texture = "rbxassetid://133275734618049",
				offset = Vector3.new(0.0, -0.65, -0.035),
			},
			["ShinFL"] = {
				mesh = "rbxassetid://139916469539801",
				texture = "rbxassetid://131847716287235",
				offset = Vector3.new(0.0, -0.65, -0.035),
			},
			["ShinFR"] = {
				mesh = "rbxassetid://115955342848969",
				texture = "rbxassetid://133275734618049",
				offset = Vector3.new(0.0, -0.65, -0.035),
			},
			["Tail"] = {
				mesh = "rbxassetid://103467289370334",
				texture = "rbxassetid://105968462656507",
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
				offset = Vector3.new(0.0000, -0.0990, -0.2475),
			},
			["EarL"] = {
				mesh = "rbxassetid://83004076565492",
				texture = "rbxassetid://75029978410519",
				offset = Vector3.new(0.0000, 0.2695, 0.0000),
			},
			["EarR"] = {
				mesh = "rbxassetid://137319375650693",
				texture = "rbxassetid://116297795548724",
				offset = Vector3.new(0.0000, 0.2695, 0.0000),
			},
			["Head"] = {
				mesh = "rbxassetid://91871561014175",
				texture = "rbxassetid://80945704298653",
				offset = Vector3.new(0.0000, -0.2035, -0.7425),
			},
			["Jaw"] = {
				mesh = "rbxassetid://79224341398908",
				texture = "rbxassetid://115583132950783",
				offset = Vector3.new(0.0000, 0.0220, -0.1760),
			},
			["LegBL"] = {
				mesh = "rbxassetid://132693781152986",
				texture = "rbxassetid://110551336187334",
				offset = Vector3.new(0.0000, -0.6600, -0.0440),
			},
			["LegBR"] = {
				mesh = "rbxassetid://95797457657049",
				texture = "rbxassetid://124373241126121",
				offset = Vector3.new(0.0000, -0.6600, -0.0440),
			},
			["LegFL"] = {
				mesh = "rbxassetid://94352836408399",
				texture = "rbxassetid://98804631365882",
				offset = Vector3.new(-0.0385, -0.6160, 0.0660),
			},
			["LegFR"] = {
				mesh = "rbxassetid://94525411903022",
				texture = "rbxassetid://137092608016507",
				offset = Vector3.new(0.0385, -0.6160, 0.0660),
			},
			["Neck"] = {
				mesh = "rbxassetid://101582834546782",
				texture = "rbxassetid://116775172127158",
				offset = Vector3.new(0.0000, -0.0220, 0.1650),
			},
			["ShinBL"] = {
				mesh = "rbxassetid://114648706051156",
				texture = "rbxassetid://86501539141868",
				offset = Vector3.new(0.0000, -0.7590, -0.0165),
			},
			["ShinBR"] = {
				mesh = "rbxassetid://76859130723950",
				texture = "rbxassetid://137643768987026",
				offset = Vector3.new(0.0000, -0.7590, -0.0165),
			},
			["ShinFL"] = {
				mesh = "rbxassetid://73588088723551",
				texture = "rbxassetid://112817884065366",
				offset = Vector3.new(0.0000, -0.7370, -0.1375),
			},
			["ShinFR"] = {
				mesh = "rbxassetid://77609488627352",
				texture = "rbxassetid://78851702767896",
				offset = Vector3.new(0.0000, -0.7370, -0.1375),
			},
			["Tail"] = {
				mesh = "rbxassetid://134246455275202",
				texture = "rbxassetid://110072818954728",
				offset = Vector3.new(0.0000, -0.0935, 0.3410),
			},
			["Tail2"] = {
				mesh = "rbxassetid://112559243727289",
				texture = "rbxassetid://136364985072532",
				offset = Vector3.new(0.0000, -0.1705, 0.4840),
			},
			["Tail3"] = {
				mesh = "rbxassetid://87192976047910",
				texture = "rbxassetid://101818595656001",
				offset = Vector3.new(0.0000, 0.2970, 0.1485),
			},
		},
	},
}

return MountMeshes
