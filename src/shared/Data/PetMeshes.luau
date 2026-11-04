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
			["Static"] = {
				mesh = "rbxassetid://99116424445872",
				texture = "rbxassetid://92351443102937",
				offset = Vector3.new(0.0000, -0.2550, 0.1000),
			},
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
		},
	},
	Tucan = {
		scale = 1,
		parts = {
			["Static"] = {
				mesh = "rbxassetid://84218343613262",
				texture = "rbxassetid://76033448460316",
				offset = Vector3.new(0.0000, -0.2500, 0.0437),
			},
			["Head"] = {
				mesh = "rbxassetid://76131305655361",
				texture = "rbxassetid://115425192348396",
				offset = Vector3.new(0.0000, 0.3475, -0.6375),
			},
			["Tail"] = {
				mesh = "rbxassetid://72663062426892",
				texture = "rbxassetid://136481049080016",
				offset = Vector3.new(0.0000, -0.2325, 0.2200),
			},
			["WingL"] = {
				mesh = "rbxassetid://100259608612120",
				texture = "rbxassetid://124276299099613",
				offset = Vector3.new(-0.6650, 0.0200, 0.1550),
			},
			["WingR"] = {
				mesh = "rbxassetid://135833314955919",
				texture = "rbxassetid://70470263520411",
				offset = Vector3.new(0.6650, 0.0200, 0.1550),
			},
		},
	},
	Colibri = {
		scale = 1,
		parts = {
			["Static"] = {
				mesh = "rbxassetid://140341211268224",
				texture = "rbxassetid://84995592741074",
				offset = Vector3.new(0.0000, -0.2650, -0.0100),
			},
			["Head"] = {
				mesh = "rbxassetid://129217797369533",
				texture = "rbxassetid://99912227694821",
				offset = Vector3.new(0.0000, 0.1550, -0.3925),
			},
			["Tail"] = {
				mesh = "rbxassetid://89369307558480",
				texture = "rbxassetid://100939801753303",
				offset = Vector3.new(0.0000, -0.3137, 0.2941),
			},
			["WingL"] = {
				mesh = "rbxassetid://86915386166344",
				texture = "rbxassetid://123465679567613",
				offset = Vector3.new(-0.5750, 0.0200, 0.1000),
			},
			["WingR"] = {
				mesh = "rbxassetid://123220262133492",
				texture = "rbxassetid://101453029587526",
				offset = Vector3.new(0.5750, 0.0200, 0.1000),
			},
		},
	},
	Guacamaya = {
		scale = 1,
		parts = {
			["Static"] = {
				mesh = "rbxassetid://121299303988009",
				texture = "rbxassetid://80907640539852",
				offset = Vector3.new(0.0000, -0.1650, 0.0575),
			},
			["Head"] = {
				mesh = "rbxassetid://109082098201460",
				texture = "rbxassetid://79629197387032",
				offset = Vector3.new(0.0000, 0.2840, -0.1825),
			},
			["Tail"] = {
				mesh = "rbxassetid://123598930540920",
				texture = "rbxassetid://123332361710102",
				offset = Vector3.new(0.0000, -0.2575, 0.8601),
			},
			["WingL"] = {
				mesh = "rbxassetid://118523715130776",
				texture = "rbxassetid://96290480952302",
				offset = Vector3.new(-0.9825, 0.0100, 0.1950),
			},
			["WingR"] = {
				mesh = "rbxassetid://87784175255024",
				texture = "rbxassetid://134908936606989",
				offset = Vector3.new(0.9825, 0.0100, 0.1950),
			},
		},
	},
	Quetzal = {
		scale = 1,
		parts = {
			["Static"] = {
				mesh = "rbxassetid://113728992051230",
				texture = "rbxassetid://128298858331372",
				offset = Vector3.new(0.0000, -0.3350, 0.0625),
			},
			["Head"] = {
				mesh = "rbxassetid://119656885700794",
				texture = "rbxassetid://75724585969841",
				offset = Vector3.new(0.0000, 0.3375, -0.0475),
			},
			["Tail"] = {
				mesh = "rbxassetid://126114458225286",
				texture = "rbxassetid://130506569345592",
				offset = Vector3.new(0.0000, -0.2350, 1.5300),
			},
			["WingL"] = {
				mesh = "rbxassetid://123436697153410",
				texture = "rbxassetid://140196152603915",
				offset = Vector3.new(-1.0100, 0.0025, 0.2725),
			},
			["WingR"] = {
				mesh = "rbxassetid://118900349989071",
				texture = "rbxassetid://138118011895286",
				offset = Vector3.new(1.0100, 0.0025, 0.2725),
			},
		},
	},
	Rana = {
		scale = 1,
		parts = {
			["Static"] = {
				mesh = "rbxassetid://91935588803549",
				texture = "rbxassetid://134029865095137",
				offset = Vector3.new(0.0000, 0.1250, -0.0850),
			},
			["BL"] = {
				mesh = "rbxassetid://102475806270923",
				texture = "rbxassetid://120269440618035",
				offset = Vector3.new(-0.3255, -0.1450, 0.0100),
			},
			["BR"] = {
				mesh = "rbxassetid://125092827457611",
				texture = "rbxassetid://113614711158731",
				offset = Vector3.new(0.3255, -0.1450, 0.0100),
			},
			["FL"] = {
				mesh = "rbxassetid://108958852313846",
				texture = "rbxassetid://82148326884073",
				offset = Vector3.new(-0.1648, -0.1750, -0.1560),
			},
			["FR"] = {
				mesh = "rbxassetid://80266988954196",
				texture = "rbxassetid://89511352608853",
				offset = Vector3.new(0.1648, -0.1750, -0.1560),
			},
		},
	},
	Tortuga = {
		scale = 1,
		parts = {
			["Static"] = {
				mesh = "rbxassetid://105440745384337",
				texture = "rbxassetid://136148240079364",
				offset = Vector3.new(0.0000, 0.0525, 0.1400),
			},
			["BL"] = {
				mesh = "rbxassetid://72892688518602",
				texture = "rbxassetid://139556717269724",
				offset = Vector3.new(-0.1550, -0.0600, 0.2100),
			},
			["BR"] = {
				mesh = "rbxassetid://92043140235140",
				texture = "rbxassetid://78848930382546",
				offset = Vector3.new(0.1550, -0.0600, 0.2100),
			},
			["FL"] = {
				mesh = "rbxassetid://118770408483834",
				texture = "rbxassetid://72468479185313",
				offset = Vector3.new(-0.5650, -0.0950, 0.0850),
			},
			["FR"] = {
				mesh = "rbxassetid://117886977048710",
				texture = "rbxassetid://101971849745166",
				offset = Vector3.new(0.5650, -0.0950, 0.0850),
			},
			["Head"] = {
				mesh = "rbxassetid://131696539074577",
				texture = "rbxassetid://111855786006004",
				offset = Vector3.new(0.0000, 0.0450, -0.3450),
			},
		},
	},
	Perezoso = {
		scale = 1,
		parts = {
			["Static"] = {
				mesh = "rbxassetid://129051009976149",
				texture = "rbxassetid://129054740651181",
				offset = Vector3.new(0.0000, 0.5725, 0.1400),
			},
			["BL"] = {
				mesh = "rbxassetid://114861222806336",
				texture = "rbxassetid://137285197435097",
				offset = Vector3.new(-0.0800, -0.4650, -0.0950),
			},
			["BR"] = {
				mesh = "rbxassetid://134095420263744",
				texture = "rbxassetid://97471076072442",
				offset = Vector3.new(0.0800, -0.4650, -0.0950),
			},
			["FL"] = {
				mesh = "rbxassetid://70456368594577",
				texture = "rbxassetid://81874019612939",
				offset = Vector3.new(-0.0500, -0.6600, -0.5800),
			},
			["FR"] = {
				mesh = "rbxassetid://102820490881901",
				texture = "rbxassetid://112170061298068",
				offset = Vector3.new(0.0500, -0.6600, -0.5800),
			},
			["Head"] = {
				mesh = "rbxassetid://83223279620081",
				texture = "rbxassetid://96024515587816",
				offset = Vector3.new(0.0000, 0.0250, -0.2250),
			},
		},
	},
}

return PetMeshes
