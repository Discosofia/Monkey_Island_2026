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
