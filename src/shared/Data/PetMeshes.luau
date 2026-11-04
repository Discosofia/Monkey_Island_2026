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
	Beagle = {
		scale = 1,
		parts = {
			["Static"] = {
				mesh = "rbxassetid://95922908610820",
				texture = "rbxassetid://113487744918203",
				offset = Vector3.new(0.0000, -0.0220, -0.3960),
			},
			["BL"] = {
				mesh = "rbxassetid://134317041836718",
				texture = "rbxassetid://96804631888448",
				offset = Vector3.new(-0.0028, -0.1733, 0.0220),
			},
			["BL2"] = {
				mesh = "rbxassetid://82426733002597",
				texture = "rbxassetid://79138878435448",
				offset = Vector3.new(0.0000, -0.1347, 0.0413),
			},
			["BR"] = {
				mesh = "rbxassetid://120157083375296",
				texture = "rbxassetid://118380129017177",
				offset = Vector3.new(0.0028, -0.1733, 0.0220),
			},
			["BR2"] = {
				mesh = "rbxassetid://105943879948109",
				texture = "rbxassetid://76906067800729",
				offset = Vector3.new(0.0000, -0.1347, 0.0413),
			},
			["FL"] = {
				mesh = "rbxassetid://124152676872264",
				texture = "rbxassetid://118298026929235",
				offset = Vector3.new(-0.0110, -0.2338, -0.0220),
			},
			["FL2"] = {
				mesh = "rbxassetid://115421853683589",
				texture = "rbxassetid://120665282180816",
				offset = Vector3.new(0.0000, -0.1347, -0.0633),
			},
			["FR"] = {
				mesh = "rbxassetid://105595932693934",
				texture = "rbxassetid://123851691439945",
				offset = Vector3.new(0.0110, -0.2338, -0.0220),
			},
			["FR2"] = {
				mesh = "rbxassetid://115549473813816",
				texture = "rbxassetid://91799830223469",
				offset = Vector3.new(0.0000, -0.1347, -0.0633),
			},
			["Head"] = {
				mesh = "rbxassetid://88721121000170",
				texture = "rbxassetid://83460939051016",
				offset = Vector3.new(0.0000, 0.3795, -0.3190),
			},
			["Hip"] = {
				mesh = "rbxassetid://138795116524176",
				texture = "rbxassetid://86684470703063",
				offset = Vector3.new(0.0000, 0.0473, 0.3025),
			},
			["J1"] = {
				mesh = "rbxassetid://128775103954251",
				texture = "rbxassetid://70626539191929",
				offset = Vector3.new(0.0000, 0.0825, 0.3245),
			},
		},
	},
	Labrador = {
		scale = 1,
		parts = {
			["Static"] = {
				mesh = "rbxassetid://105753227125177",
				texture = "rbxassetid://72202445609499",
				offset = Vector3.new(0.0000, -0.0220, -0.4510),
			},
			["BL"] = {
				mesh = "rbxassetid://99486870390493",
				texture = "rbxassetid://106131736763818",
				offset = Vector3.new(0.0000, -0.2008, 0.0110),
			},
			["BL2"] = {
				mesh = "rbxassetid://124528152935464",
				texture = "rbxassetid://111175915890666",
				offset = Vector3.new(0.0000, -0.1622, 0.0550),
			},
			["BR"] = {
				mesh = "rbxassetid://122687908772911",
				texture = "rbxassetid://83614660261536",
				offset = Vector3.new(0.0000, -0.2008, 0.0110),
			},
			["BR2"] = {
				mesh = "rbxassetid://116203318765183",
				texture = "rbxassetid://120770670772316",
				offset = Vector3.new(0.0000, -0.1622, 0.0550),
			},
			["FL"] = {
				mesh = "rbxassetid://101826178570096",
				texture = "rbxassetid://96410029302392",
				offset = Vector3.new(0.0000, -0.2750, -0.0220),
			},
			["FL2"] = {
				mesh = "rbxassetid://95052060301770",
				texture = "rbxassetid://117712025336090",
				offset = Vector3.new(0.0000, -0.1622, -0.0495),
			},
			["FR"] = {
				mesh = "rbxassetid://139203892377635",
				texture = "rbxassetid://72320300311310",
				offset = Vector3.new(0.0000, -0.2750, -0.0220),
			},
			["FR2"] = {
				mesh = "rbxassetid://84651527256185",
				texture = "rbxassetid://121401323320560",
				offset = Vector3.new(0.0000, -0.1622, -0.0495),
			},
			["Head"] = {
				mesh = "rbxassetid://133269533416799",
				texture = "rbxassetid://139050274449186",
				offset = Vector3.new(0.0000, 0.4290, -0.3520),
			},
			["Hip"] = {
				mesh = "rbxassetid://138578040225651",
				texture = "rbxassetid://135939021611894",
				offset = Vector3.new(0.0000, -0.2695, 0.2035),
			},
			["J1"] = {
				mesh = "rbxassetid://122197695887199",
				texture = "rbxassetid://81808308804158",
				offset = Vector3.new(0.0000, 0.0715, 0.3795),
			},
		},
	},
	Pointer = {
		scale = 1,
		parts = {
			["Static"] = {
				mesh = "rbxassetid://84026755151541",
				texture = "rbxassetid://76530782507511",
				offset = Vector3.new(0.0000, -0.0220, -0.4510),
			},
			["BL"] = {
				mesh = "rbxassetid://94999228727814",
				texture = "rbxassetid://113593663948758",
				offset = Vector3.new(-0.0110, -0.2420, 0.0220),
			},
			["BL2"] = {
				mesh = "rbxassetid://96290267067711",
				texture = "rbxassetid://136444730880585",
				offset = Vector3.new(0.0000, -0.2035, 0.0330),
			},
			["BR"] = {
				mesh = "rbxassetid://74399458632909",
				texture = "rbxassetid://131993351549906",
				offset = Vector3.new(0.0110, -0.2420, 0.0220),
			},
			["BR2"] = {
				mesh = "rbxassetid://131578170751606",
				texture = "rbxassetid://100698169946056",
				offset = Vector3.new(0.0000, -0.2035, 0.0330),
			},
			["FL"] = {
				mesh = "rbxassetid://87678720809889",
				texture = "rbxassetid://125503324338195",
				offset = Vector3.new(-0.0192, -0.2970, -0.0220),
			},
			["FL2"] = {
				mesh = "rbxassetid://132638530333624",
				texture = "rbxassetid://93015558134365",
				offset = Vector3.new(0.0000, -0.2035, -0.0660),
			},
			["FR"] = {
				mesh = "rbxassetid://100569683015186",
				texture = "rbxassetid://80534832121542",
				offset = Vector3.new(0.0192, -0.2970, -0.0220),
			},
			["FR2"] = {
				mesh = "rbxassetid://94764139295698",
				texture = "rbxassetid://81768842051938",
				offset = Vector3.new(0.0000, -0.2035, -0.0660),
			},
			["Head"] = {
				mesh = "rbxassetid://117286277748534",
				texture = "rbxassetid://93115117067900",
				offset = Vector3.new(0.0000, 0.4221, -0.3520),
			},
			["Hip"] = {
				mesh = "rbxassetid://117232131605954",
				texture = "rbxassetid://113117530296084",
				offset = Vector3.new(0.0000, 0.0798, 0.3850),
			},
			["J1"] = {
				mesh = "rbxassetid://79502460889824",
				texture = "rbxassetid://120340710853549",
				offset = Vector3.new(0.0000, 0.1155, 0.3795),
			},
		},
	},
}

return PetMeshes
