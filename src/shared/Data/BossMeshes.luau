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

export type PartMesh = { mesh: string, texture: string, triangles: number, offset: Vector3 }
export type BossMesh = { scale: number, parts: { [string]: PartMesh } }

local BossMeshes: { [string]: BossMesh } = {
	GorilaAlbino = {
		scale = 2.9,
		parts = {
			["Torso"] = {
				mesh = "rbxassetid://132216618931629",
				texture = "rbxassetid://76867166260715",
				triangles = 468,
				offset = Vector3.new(0.0, 1.1093, 1.6313),
			},
			["Head"] = {
				mesh = "rbxassetid://120996717551613",
				texture = "rbxassetid://79999482827925",
				triangles = 224,
				offset = Vector3.new(0.0, 0.6785, -0.3915),
			},
			["Right Arm"] = {
				mesh = "rbxassetid://135753898735981",
				texture = "rbxassetid://127244852042385",
				triangles = 884,
				offset = Vector3.new(0.3915, -0.7437, -0.287),
			},
			["Right Leg"] = {
				mesh = "rbxassetid://116246171315932",
				texture = "rbxassetid://126238197384102",
				triangles = 136,
				offset = Vector3.new(0.1565, -0.783, -0.2348),
			},
			["Left Arm"] = {
				mesh = "rbxassetid://106309051138211",
				texture = "rbxassetid://104511100174667",
				triangles = 884,
				offset = Vector3.new(-0.3915, -0.7437, -0.287),
			},
			["Left Leg"] = {
				mesh = "rbxassetid://74422811922463",
				texture = "rbxassetid://97885973098086",
				triangles = 136,
				offset = Vector3.new(-0.1565, -0.783, -0.2348),
			},
		},
	},
	GorilaDeCeniza = {
		scale = 3.625,
		parts = {
			["Torso"] = {
				mesh = "rbxassetid://115797129194582",
				texture = "rbxassetid://104062080269799",
				triangles = 460,
				offset = Vector3.new(0.0, 2.1367, 2.0395),
			},
			["Head"] = {
				mesh = "rbxassetid://88473151897415",
				texture = "rbxassetid://85663231709494",
				triangles = 368,
				offset = Vector3.new(0.0, 1.175, -0.4892),
			},
			["Right Arm"] = {
				mesh = "rbxassetid://127265271717347",
				texture = "rbxassetid://137887862042651",
				triangles = 416,
				offset = Vector3.new(0.2123, -1.6313, -0.5223),
			},
			["Right Leg"] = {
				mesh = "rbxassetid://119100144453149",
				texture = "rbxassetid://128765754198628",
				triangles = 136,
				offset = Vector3.new(0.196, -0.9788, -0.2935),
			},
			["Left Arm"] = {
				mesh = "rbxassetid://113088815510097",
				texture = "rbxassetid://70628587353341",
				triangles = 416,
				offset = Vector3.new(-0.2123, -1.6313, -0.5223),
			},
			["Left Leg"] = {
				mesh = "rbxassetid://73691879578824",
				texture = "rbxassetid://79741343744265",
				triangles = 136,
				offset = Vector3.new(-0.196, -0.9788, -0.2935),
			},
		},
	},
	ChimpanceCaudillo = {
		scale = 2.8,
		parts = {
			["Torso"] = {
				mesh = "rbxassetid://87299500070720",
				texture = "rbxassetid://85598719896890",
				triangles = 1106,
				offset = Vector3.new(-0.168, 0.098, 1.722),
			},
			["Head"] = {
				mesh = "rbxassetid://104934226076275",
				texture = "rbxassetid://94094949044913",
				triangles = 192,
				offset = Vector3.new(0.0, -0.098, -0.21),
			},
			["Right Arm"] = {
				mesh = "rbxassetid://111455069402190",
				texture = "rbxassetid://88330347842591",
				triangles = 420,
				offset = Vector3.new(0.273, -0.385, -0.112),
			},
			["Right Leg"] = {
				mesh = "rbxassetid://112563491084950",
				texture = "rbxassetid://129648413837671",
				triangles = 170,
				offset = Vector3.new(0.0, -0.91, -0.273),
			},
			["Left Arm"] = {
				mesh = "rbxassetid://75481364710106",
				texture = "rbxassetid://113825824441419",
				triangles = 420,
				offset = Vector3.new(-0.273, -0.385, -0.112),
			},
			["Left Leg"] = {
				mesh = "rbxassetid://128537696135085",
				texture = "rbxassetid://83351926105757",
				triangles = 170,
				offset = Vector3.new(0.0, -0.91, -0.273),
			},
		},
	},
	OrangutanDelManglar = {
		scale = 3,
		parts = {
			["Torso"] = {
				mesh = "rbxassetid://139636871876586",
				texture = "rbxassetid://117294235145911",
				triangles = 1006,
				offset = Vector3.new(0.0, 0.25, 1.365),
			},
			["Head"] = {
				mesh = "rbxassetid://114983613574935",
				texture = "rbxassetid://105069151736041",
				triangles = 378,
				offset = Vector3.new(0.0, -0.825, -0.45),
			},
			["Right Arm"] = {
				mesh = "rbxassetid://126945837773753",
				texture = "rbxassetid://130901727763319",
				triangles = 350,
				offset = Vector3.new(0.0735, -1.02, -0.15),
			},
			["Right Leg"] = {
				mesh = "rbxassetid://140191498769992",
				texture = "rbxassetid://88982213907354",
				triangles = 86,
				offset = Vector3.new(0.0, -0.9, -0.42),
			},
			["Left Arm"] = {
				mesh = "rbxassetid://131452607534584",
				texture = "rbxassetid://101335588857289",
				triangles = 350,
				offset = Vector3.new(-0.0735, -1.02, -0.15),
			},
			["Left Leg"] = {
				mesh = "rbxassetid://127279603998015",
				texture = "rbxassetid://81838129831357",
				triangles = 86,
				offset = Vector3.new(0.0, -0.9, -0.42),
			},
		},
	},
}

return BossMeshes
