--!strict
-- Mallas con textura de las mascotas (Fase 21, igual que MountMeshes). Las genera `tools/mallas.py` a partir del volcado de
-- `ServerStorage.Tools.Mallas.volcarMascota` (la silueta en bloques gruesos y los detalles finos pintados en la textura),
-- se importan en Studio con Import 3D y aquí van sus ids. Una malla por grupo de piezas que se mueven juntas (la cabeza,
-- cada pata…) y una para todo lo fijo ("Static"). `PetModels.build` sustituye por ellas los bloques de ese grupo; si falta
-- el id (o la malla aún no ha cargado), el grupo se queda con sus bloques. La mascota con skin no usa mallas.
--   scale:  1 (los bloques se volcaron sin escalar; la mascota se escala con `Data/Pets.size`).
--   offset: centro de la caja envolvente de la malla respecto al origen de su grupo (la bisagra, o el pivote en "Static").
-- El importador gira la malla 180° sobre Y; PetModels lo compensa.

export type PartMesh = { mesh: string, texture: string, offset: Vector3 }
export type PetMesh = { scale: number, parts: { [string]: PartMesh } }

local PetMeshes: { [string]: PetMesh } = {
	Capibara = {
		scale = 1,
		parts = {
			["BL"] = {
				mesh = "rbxassetid://103895063260982",
				texture = "rbxassetid://137385743350688",
				offset = Vector3.new(0.0000, -0.2200, -0.0400),
			},
			["BR"] = {
				mesh = "rbxassetid://71568587787420",
				texture = "rbxassetid://99726675635837",
				offset = Vector3.new(0.0000, -0.2200, -0.0400),
			},
			["FL"] = {
				mesh = "rbxassetid://85336612139371",
				texture = "rbxassetid://109621648905410",
				offset = Vector3.new(0.0000, -0.2600, -0.0650),
			},
			["FR"] = {
				mesh = "rbxassetid://104338952777716",
				texture = "rbxassetid://80518573873491",
				offset = Vector3.new(0.0000, -0.2600, -0.0650),
			},
			["Head"] = {
				mesh = "rbxassetid://122113995896532",
				texture = "rbxassetid://98734548845421",
				offset = Vector3.new(0.0000, 0.0450, -0.4075),
			},
			["Static"] = {
				mesh = "rbxassetid://99116424445872",
				texture = "rbxassetid://92351443102937",
				offset = Vector3.new(0.0000, -0.2550, 0.1000),
			},
		},
	},
}

return PetMeshes
