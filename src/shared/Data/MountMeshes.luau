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
}

return MountMeshes
