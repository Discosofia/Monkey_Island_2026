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
-- "pose": la animación de disparo de Data/WeaponAnimations que usa (cada una la suya, Fase 15, V9; el
-- lanzadardos "LabDart" desde la Fase 19, W2). "sound": el efecto de Data/Sounds de su disparo.
-- Cargador (Fase 15, V8): "magazine" balas y "reloadSeconds" para recargarlo (sola al vaciarse, o con la
-- acción Recargar). "automatic": mantener el gatillo repite el disparo a su cadencia.
-- "spread": dispersión en grados (cono de un disco uniforme) según la situación; sin "spread", exacta.
--   still / moving / air   quieto en el suelo / moviéndose (Config.Lab.SpreadMovingSpeed) / en el aire
--   perShot, maxShots      lo que suma cada disparo seguido, hasta maxShots disparos acumulados
--   recover                grados por segundo que se recupera el acumulado al dejar de disparar
--   zoomExact              con el zoom y en el suelo, dispersión 0 (el rifle)
-- El primer tiro quieto, sin acumulado, es exacto aunque "still" valga más. Lo calcula Shared/LabSpread.
export type SpreadFields = {
	still: number,
	moving: number,
	air: number,
	perShot: number,
	maxShots: number?,
	recover: number?,
	zoomExact: boolean?,
}

export type LabFields = {
	effect: ("SlowStack" | "Entangle" | "AcidBurst")?,
	zoom: boolean?,
	pose: "Stone" | "Arrow" | "Spell" | "Dart" | "LabDart" | "LabRifle" | "LabHarpoon" | "LabCannon",
	magazine: number,
	reloadSeconds: number,
	automatic: boolean?,
	spread: SpreadFields?,
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
		sound = "LabDartShot",
		damage = 10,
		critChance = 0,
		cooldownSeconds = 0.15,
		range = 80,
		projectileSpeed = 260,
		projectile = "LabDart",
		lab = {
			effect = "SlowStack",
			pose = "LabDart",
			magazine = 24,
			reloadSeconds = 1.6,
			automatic = true,
			spread = { still = 0.6, moving = 1.8, air = 3.1, perShot = 0.35, maxShots = 3, recover = 6 },
		},
	},
	LabBananaRifle = {
		name = "Rifle de bananas primales",
		description = "Precisión a larga distancia. Mantén apuntado para acercar la vista.",
		kind = "Ranged",
		sound = "LabRifleShot",
		damage = 45,
		critChance = 0,
		cooldownSeconds = 0.95,
		range = 200,
		projectileSpeed = 450,
		projectile = "LabBanana",
		lab = {
			zoom = true,
			pose = "LabRifle",
			magazine = 5,
			reloadSeconds = 2.2,
			spread = { still = 0, moving = 2.5, air = 5, perShot = 0, zoomExact = true },
		},
	},
	LabNetHarpoon = {
		name = "Lanzarredes de arpón",
		description = "Corta distancia. El impacto enreda y frena al que se acerca.",
		kind = "Ranged",
		sound = "LabHarpoonShot",
		damage = 35,
		critChance = 0,
		cooldownSeconds = 0.65,
		range = 35,
		projectileSpeed = 180,
		projectile = "LabNet",
		lab = {
			effect = "Entangle",
			pose = "LabHarpoon",
			magazine = 3,
			reloadSeconds = 1.8,
			spread = { still = 0, moving = 1.5, air = 3, perShot = 0 },
		},
	},
	LabAcidCannon = {
		name = "Cañón de suero ácido",
		description = "Dispara en arco por encima de las coberturas. Estalla y envenena en un área.",
		kind = "Ranged",
		sound = "LabCannonShot",
		damage = 30,
		critChance = 0,
		cooldownSeconds = 0.8,
		range = 70,
		projectileSpeed = 110,
		projectile = "LabAcid",
		poison = { dps = 6, seconds = 3 },
		-- Sin dispersión: cae donde se apunta.
		lab = { effect = "AcidBurst", pose = "LabCannon", magazine = 4, reloadSeconds = 2.0 },
	},
}

return {
	ORDER = ORDER,
	weapons = LabWeapons,
}
