--!strict
-- Mallas con textura de las partes del cuerpo de los jefes (Fase 21). Las genera `tools/mallas.py` a partir de
-- los bloques de su spec voxel (la silueta en bloques gruesos y los mechones pintados en la textura), se importan
-- en Studio con Import 3D y aquí van sus ids. `MonkeyModels` las usa en lugar de la unión de bloques de esa parte;
-- si falta el id (o la malla no carga), la parte se construye con bloques como siempre.
--   scale:  escala del jefe con la que se volcaron los bloques (Bosses.scale).
--   offset: centro de la caja envolvente de la malla respecto al centro de la parte, en studs a esa escala.
-- El importador gira la malla 180° sobre Y; MonkeyModels lo compensa.
-- Para rehacer un jefe: `ServerStorage.Tools.Mallas.volcar(bossId)`, `python tools/mallas.py` (ver su cabecera) e
-- importar los .obj de build/mallas/<jefe>.

export type PartMesh = { mesh: string, texture: string, offset: Vector3 }
export type BossMesh = { scale: number, parts: { [string]: PartMesh } }

local BossMeshes: { [string]: BossMesh } = {
	GorilaAlbino = {
		scale = 2.9,
		parts = {
			["Torso"] = {
				mesh = "rbxassetid://127295755080221",
				texture = "rbxassetid://82104211036822",
				offset = Vector3.new(0.0, 1.1093, 1.6313),
			},
			["Head"] = {
				mesh = "rbxassetid://75413982563235",
				texture = "rbxassetid://84081373742351",
				offset = Vector3.new(0.0, 0.6785, -0.3915),
			},
			["Right Arm"] = {
				mesh = "rbxassetid://85769272103974",
				texture = "rbxassetid://119670673055224",
				offset = Vector3.new(0.3915, -0.7437, -0.287),
			},
			["Right Leg"] = {
				mesh = "rbxassetid://102453728106639",
				texture = "rbxassetid://118210888340930",
				offset = Vector3.new(0.1565, -0.783, -0.2348),
			},
			["Left Arm"] = {
				mesh = "rbxassetid://126183656056144",
				texture = "rbxassetid://89064369088899",
				offset = Vector3.new(-0.3915, -0.7437, -0.287),
			},
			["Left Leg"] = {
				mesh = "rbxassetid://85492389869771",
				texture = "rbxassetid://107517519136136",
				offset = Vector3.new(-0.1565, -0.783, -0.2348),
			},
		},
	},
}

return BossMeshes
