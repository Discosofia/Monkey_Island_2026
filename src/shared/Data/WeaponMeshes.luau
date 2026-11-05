--!strict
-- Mallas con textura de las armas (Fase 20 Q7, igual que ArmorMeshes). Las genera `tools/arma.py` a partir del volcado de
-- `ServerStorage.Tools.Mallas.volcarArma` (la silueta en bloques gruesos y los detalles finos pintados en la textura), se
-- importan en Studio con Import 3D y aquí van sus ids. `WeaponTools.fill` sustituye por ellas los bloques de cada grupo con
-- entrada; un grupo sin entrada (o cuya malla aún no ha cargado) se queda en bloques. Mientras la tabla esté vacía, el
-- aspecto no cambia.
--   Weapon[weaponId]  (el arma tal como la construye `WeaponTools.BUILDERS`, sin aspecto)
-- Cada entrada es una malla por grupo `Handle_<Soft|Hard>`: Soft = Fabric y Leather, Hard = el resto de materiales lisos.
-- Neón, cristal, bolas, cilindros, cuñas y los bloques girados no entran: se quedan sueltos (`WeaponTools.meshableBox`).
--   offset:  centro de la caja envolvente de la malla respecto al `Handle` (studs).
--   size:    tamaño de esa caja (la malla se ajusta a él al colocarla).
-- El importador gira la malla 180° sobre Y; WeaponTools lo compensa. El arma no se escala: no hay `ref`.

export type GroupMesh = {
	mesh: string,
	texture: string,
	offset: Vector3,
	size: Vector3,
	triangles: number,
}
export type Entry = { groups: { [string]: GroupMesh } }
export type WeaponMeshes = {
	Weapon: { [string]: Entry },
}

-- Las entradas las escribe `tools/arma.py ids`: van entre las marcas `-- @entrada` y `-- @fin`.
local WeaponMeshes: WeaponMeshes = {
	Weapon = {
		-- @entrada Weapon BoneMace
		BoneMace = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://123431818701203",
					texture = "rbxassetid://124615250769172",
					offset = Vector3.new(0.0000, 0.9300, 0.0000),
					size = Vector3.new(2.8000, 5.3400, 2.8000),
					triangles = 1292,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://120830224351346",
					texture = "rbxassetid://133216528751067",
					offset = Vector3.new(0.0000, 0.2250, 0.0000),
					size = Vector3.new(0.8200, 2.7500, 0.8200),
					triangles = 92,
				},
			},
		},
		-- @fin
		-- @entrada Weapon Bow
		Bow = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://104032953199774",
					texture = "rbxassetid://113629862679150",
					offset = Vector3.new(0.0425, 0.0000, 0.2375),
					size = Vector3.new(0.4350, 6.7250, 0.8950),
					triangles = 708,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://75257329793336",
					texture = "rbxassetid://75483729696755",
					offset = Vector3.new(0.0300, 0.0000, 0.2575),
					size = Vector3.new(0.4600, 6.3050, 1.0150),
					triangles = 208,
				},
			},
		},
		-- @fin
		-- @entrada Weapon EmberBow
		EmberBow = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://124827659810769",
					texture = "rbxassetid://86341480490147",
					offset = Vector3.new(-0.0100, 0.0000, 0.2142),
					size = Vector3.new(0.5400, 8.0200, 1.4517),
					triangles = 1328,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://96286258871565",
					texture = "rbxassetid://124263047418651",
					offset = Vector3.new(0.0000, -0.0700, 0.0000),
					size = Vector3.new(0.5100, 1.4600, 0.4800),
					triangles = 112,
				},
			},
		},
		-- @fin
		-- @entrada Weapon GoldenStaff
		GoldenStaff = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://137619227693423",
					texture = "rbxassetid://94029895082127",
					offset = Vector3.new(0.0000, 0.2547, 0.0000),
					size = Vector3.new(1.0870, 6.1094, 1.0870),
					triangles = 898,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://90151674069265",
					texture = "rbxassetid://82360739079602",
					offset = Vector3.new(0.0000, 0.0750, 0.0000),
					size = Vector3.new(0.5200, 4.3500, 0.5000),
					triangles = 92,
				},
			},
		},
		-- @fin
		-- @entrada Weapon LavaStaff
		LavaStaff = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://107536171650839",
					texture = "rbxassetid://78722095264325",
					offset = Vector3.new(0.0000, 0.3600, 0.0000),
					size = Vector3.new(1.3000, 6.5200, 1.3000),
					triangles = 1056,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://81888654705397",
					texture = "rbxassetid://95067924698523",
					offset = Vector3.new(0.0000, 0.4100, 0.0000),
					size = Vector3.new(0.6800, 3.1800, 0.3800),
					triangles = 204,
				},
			},
		},
		-- @fin
		-- @entrada Weapon LianaBow
		LianaBow = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://136286099932019",
					texture = "rbxassetid://105824909460160",
					offset = Vector3.new(0.0250, 0.0000, 0.2600),
					size = Vector3.new(0.7900, 7.9000, 1.2600),
					triangles = 1036,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://116070644712822",
					texture = "rbxassetid://114554724282592",
					offset = Vector3.new(0.0000, 0.0000, 0.2150),
					size = Vector3.new(0.5200, 6.9500, 0.9500),
					triangles = 280,
				},
			},
		},
		-- @fin
		-- @entrada Weapon MagicStaff
		MagicStaff = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://72511258026335",
					texture = "rbxassetid://140204452927498",
					offset = Vector3.new(0.0174, 0.3771, 0.0000),
					size = Vector3.new(0.9253, 5.5541, 0.8906),
					triangles = 636,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://135680489219207",
					texture = "rbxassetid://137915581532493",
					offset = Vector3.new(0.0100, 0.4250, 0.0000),
					size = Vector3.new(0.4400, 3.4500, 0.4200),
					triangles = 72,
				},
			},
		},
		-- @fin
		-- @entrada Weapon ReinforcedBow
		ReinforcedBow = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://117061482327465",
					texture = "rbxassetid://101684173208774",
					offset = Vector3.new(0.0725, 0.0000, 0.1550),
					size = Vector3.new(0.4950, 7.2580, 1.1900),
					triangles = 918,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://126108505789676",
					texture = "rbxassetid://88735754950776",
					offset = Vector3.new(0.0400, 0.0000, 0.2000),
					size = Vector3.new(0.4400, 6.8380, 0.8600),
					triangles = 196,
				},
			},
		},
		-- @fin
		-- @entrada Weapon SilverStaff
		SilverStaff = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://100383145304924",
					texture = "rbxassetid://88034410313695",
					offset = Vector3.new(0.0000, 0.7700, 0.0000),
					size = Vector3.new(1.2236, 7.0000, 1.2236),
					triangles = 1218,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://72688536887805",
					texture = "rbxassetid://136357612135517",
					offset = Vector3.new(0.0000, 0.3000, 0.0000),
					size = Vector3.new(0.5200, 3.9000, 0.4800),
					triangles = 250,
				},
			},
		},
		-- @fin
		-- @entrada Weapon StoneClub
		StoneClub = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://113733681364388",
					texture = "rbxassetid://128560928796818",
					offset = Vector3.new(0.0000, 1.1250, -0.0250),
					size = Vector3.new(2.0000, 5.1100, 1.5400),
					triangles = 418,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://112993037746452",
					texture = "rbxassetid://83054356451078",
					offset = Vector3.new(0.0850, 0.9000, 0.0000),
					size = Vector3.new(0.6700, 4.1000, 1.5600),
					triangles = 104,
				},
			},
		},
		-- @fin
		-- @entrada Weapon SulfurBlowgun
		SulfurBlowgun = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://127771998167539",
					texture = "rbxassetid://133007942265864",
					offset = Vector3.new(0.0000, 0.9075, 0.0000),
					size = Vector3.new(0.9700, 4.7250, 0.8605),
					triangles = 1500,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://116501876920161",
					texture = "rbxassetid://101945095979442",
					offset = Vector3.new(0.0325, 0.8500, 0.0000),
					size = Vector3.new(0.5150, 4.1000, 0.3000),
					triangles = 96,
				},
			},
		},
		-- @fin
		-- @entrada Weapon ThickBoneMaul
		ThickBoneMaul = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://103467533122854",
					texture = "rbxassetid://75689299751309",
					offset = Vector3.new(0.0000, 1.3600, 0.0500),
					size = Vector3.new(3.9200, 6.1600, 1.4000),
					triangles = 1162,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://71355891583401",
					texture = "rbxassetid://131378886726922",
					offset = Vector3.new(0.0350, 0.7500, 0.0000),
					size = Vector3.new(1.0500, 3.3400, 0.8000),
					triangles = 236,
				},
			},
		},
		-- @fin
		-- @entrada Weapon VolcanicMaul
		VolcanicMaul = {
			groups = {
				["Handle_Hard"] = {
					mesh = "rbxassetid://121555279033061",
					texture = "rbxassetid://134797331562920",
					offset = Vector3.new(0.0000, 1.5700, 0.4250),
					size = Vector3.new(2.9400, 6.8600, 3.6900),
					triangles = 1312,
				},
				["Handle_Soft"] = {
					mesh = "rbxassetid://126876416478237",
					texture = "rbxassetid://100830668990851",
					offset = Vector3.new(0.0000, 0.6750, 0.0000),
					size = Vector3.new(0.8800, 2.9500, 0.8800),
					triangles = 220,
				},
			},
		},
		-- @fin
	},
}

return WeaponMeshes
