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
	},
}

return WeaponMeshes
