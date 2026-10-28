--!strict
-- Las cuatro armas del Laboratorio en ruinas (Fase 13, docs/LABORATORIO.md §2.1). Las dos facciones
-- llevan las mismas con los mismos números: solo cambia el aspecto (atributo "LabFaction" del jugador,
-- Shared/WeaponTools). Data/Weapons las mezcla con las demás, así que el combate las trata como
-- cualquier arma a distancia; lo propio de cada una está en "lab" y sus números en Config.Lab.
-- Sin crítico, sin remate de cadena y sin ventajas: en el Laboratorio solo cuentan el arma y la
-- puntería. La calculadora (ServerStorage.Tools.Equilibrio, sección 12) mide su tiempo para matar.

-- Qué hace cada una al acertar (CombatService.labHit):
--   "SlowStack": cada acierto ralentiza un poco más (Config.Lab.DartSlow…).
--   "Entangle": enreda, con inmunidad al soltarse (Config.Lab.Net…).
--   "AcidBurst": vuela en arco y estalla en un área que envenena (Config.Lab.Acid…; el veneno es "poison").
--   nil: solo el daño. "zoom": el cliente acerca la vista al mantener apuntado (Config.Lab.RifleZoom…).
-- "pose": la animación de disparo de Data/WeaponAnimations que usa (la del arma de la isla más parecida).
export type LabFields = {
	effect: ("SlowStack" | "Entangle" | "AcidBurst")?,
	zoom: boolean?,
	pose: "Stone" | "Arrow" | "Spell" | "Dart",
}

export type LabWeaponDefinition = {
	name: string,
	description: string,
	kind: "Ranged",
	sound: string,
	damage: number,
	critChance: number,
	cooldownSeconds: number,
	range: number,
	projectileSpeed: number,
	projectile: "LabDart" | "LabBanana" | "LabNet" | "LabAcid",
	poison: { dps: number, seconds: number }?,
	lab: LabFields,
}

-- El orden es el de la mochila (teclas 1–4) y el de la calculadora.
local ORDER = { "LabDartGun", "LabBananaRifle", "LabNetHarpoon", "LabAcidCannon" }

local LabWeapons: { [string]: LabWeaponDefinition } = {
	LabDartGun = {
		name = "Lanzadardos tranquilizante",
		description = "Automática de media distancia. Cada dardo ralentiza un poco más.",
		kind = "Ranged",
		sound = "ShootDart",
		damage = 10,
		critChance = 0,
		cooldownSeconds = 0.15,
		range = 80,
		projectileSpeed = 260,
		projectile = "LabDart",
		lab = { effect = "SlowStack", pose = "Dart" },
	},
	LabBananaRifle = {
		name = "Rifle de bananas primales",
		description = "Precisión a larga distancia. Mantén apuntado para acercar la vista.",
		kind = "Ranged",
		sound = "ShootArrow",
		damage = 45,
		critChance = 0,
		cooldownSeconds = 0.95,
		range = 200,
		projectileSpeed = 450,
		projectile = "LabBanana",
		lab = { zoom = true, pose = "Dart" },
	},
	LabNetHarpoon = {
		name = "Lanzarredes de arpón",
		description = "Corta distancia. El impacto enreda y frena al que se acerca.",
		kind = "Ranged",
		sound = "ShootStone",
		damage = 35,
		critChance = 0,
		cooldownSeconds = 0.65,
		range = 35,
		projectileSpeed = 180,
		projectile = "LabNet",
		lab = { effect = "Entangle", pose = "Spell" },
	},
	LabAcidCannon = {
		name = "Cañón de suero ácido",
		description = "Dispara en arco por encima de las coberturas. Estalla y envenena en un área.",
		kind = "Ranged",
		sound = "ShootSpell",
		damage = 30,
		critChance = 0,
		cooldownSeconds = 0.8,
		range = 70,
		projectileSpeed = 110,
		projectile = "LabAcid",
		poison = { dps = 6, seconds = 3 },
		lab = { effect = "AcidBurst", pose = "Spell" },
	},
}

return {
	ORDER = ORDER,
	weapons = LabWeapons,
}
