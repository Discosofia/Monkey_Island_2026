--!strict
-- Armas y herramientas (GDD §6, Fases 1.3 y 1.6). Para balancear, cambia los números aquí.
-- Las iniciales dependen del rol (Data/Roles, más Config.Combat.StarterTools); el resto se fabrica
-- (Data/Recipes). Las del Laboratorio (Data/LabWeapons) se añaden al final.

local LabWeapons = require(script.Parent.LabWeapons)

export type WeaponDefinition = {
	name: string,
	kind: "Melee" | "Ranged",
	damage: number,
	-- Probabilidad de golpe crítico (Config.Crit). Sube con cada mejora de la forja; sin ella,
	-- Config.Crit.DefaultWeaponChance. Las habilidades usan la de tu mejor arma (Shared/Crit).
	critChance: number?,
	cooldownSeconds: number,
	range: number, -- studs
	ammoItemId: string?, -- ítem que gasta cada disparo (ver Data/Items)
	-- Studs por segundo. El disparo es un proyectil que mueve el servidor (C9, Combat/Projectiles): se
	-- puede esquivar, y cuanto más rápido, menos (la calculadora cuenta su acierto con esto). La ayuda de
	-- puntería es la misma para todas (Config.Projectiles).
	projectileSpeed: number?,
	-- Cómo se ve lo que dispara (piedra por defecto; los "Lab…", las armas del Laboratorio).
	projectile: ("Stone" | "Arrow" | "Spell" | "Dart" | "LabDart" | "LabBanana" | "LabNet" | "LabAcid")?,
	-- Disparo de remate (C9b, Shared/RangedChain): qué hace el 4.º disparo seguido (Config.RangedChain.
	-- Finishers): "Pierce" atraviesa, "Burst" estalla, "Sap" cura el doble, "Stagger" tambalea a un mono.
	finisher: ("Pierce" | "Burst" | "Sap" | "Stagger")?,
	spell: boolean?, -- hechizo: su daño sube con "SpellDamage" en vez de "RangedDamage"
	-- Armas del médico: cada disparo que acierta a un enemigo cura esto al aliado más herido cerca
	-- (o al propio médico), a menos de Config.Combat.WeaponHealRadius…
	healOnHit: number?,
	-- …y le envenena (Combat/Status.poison): "dps" de daño por segundo (con la misma ventaja de daño que
	-- el arma) durante "seconds". No se acumula: cada acierto lo renueva. "boostItemId": munición
	-- opcional (los dardos venenosos): mientras quede, cada disparo gasta una y el veneno se multiplica
	-- por su "poisonMultiplier" (Data/Items).
	poison: PoisonDefinition?,
	swingAnimationSpeed: number?, -- velocidad del tajo (1 = la animación normal de Roblox)
	-- Sonido al usarla (clave de Data/Sounds.Effects); sin él, Swing (cuerpo a cuerpo) o Shoot (distancia).
	sound: string?,
	-- Herramienta de recolección (hacha, pico, hoz): golpeando un árbol o una roca con ella equipada; la
	-- hoz corta de un golpe los helechos y arbustos que tienes delante (ResourceService).
	tool: ToolDefinition?,
	-- Solo las del Laboratorio (Data/LabWeapons): qué hace al acertar y si acerca la vista.
	lab: LabWeapons.LabFields?,
	description: string?,
}

export type PoisonDefinition = {
	dps: number,
	seconds: number,
	boostItemId: string?,
}

export type ToolDefinition = {
	kind: string, -- "Axe", "Pick" o "Sickle": qué recursos trabaja (ver Data/ResourceNodes)
	power: number, -- progreso por golpe; más potencia = menos golpes por recolección
	bonus: number, -- material extra en cada recolección
}

local Weapons: { [string]: WeaponDefinition } = {
	Machete = {
		name = "Machete",
		kind = "Melee",
		sound = "SwingLight",
		damage = 20,
		cooldownSeconds = 0.6,
		range = 8,
		swingAnimationSpeed = 2,
	},
	-- Fase 2.3: mejora del machete en la forja de piedra.
	SharpMachete = {
		name = "Machete afilado",
		kind = "Melee",
		sound = "SwingLight",
		damage = 28,
		critChance = 0.10,
		cooldownSeconds = 0.55,
		range = 8.5,
		swingAnimationSpeed = 2,
	},
	Honda = {
		name = "Honda",
		kind = "Ranged",
		sound = "ShootStone",
		damage = 13,
		cooldownSeconds = 0.9,
		range = 90,
		ammoItemId = "Stone",
		projectileSpeed = 140,
		finisher = "Stagger",
	},
	WoodenAxe = {
		name = "Hacha de madera",
		kind = "Melee",
		damage = 10,
		cooldownSeconds = 0.7,
		range = 8,
		swingAnimationSpeed = 2,
		tool = { kind = "Axe", power = 1, bonus = 0 },
	},
	WoodenPick = {
		name = "Pico de madera",
		kind = "Melee",
		damage = 9,
		cooldownSeconds = 0.7,
		range = 8,
		swingAnimationSpeed = 2,
		tool = { kind = "Pick", power = 1, bonus = 0 },
	},
	-- Fase 4: equipo de nivel 3 (forja de piedra, con botín de categoría 2 y 3).
	LianaSling = {
		name = "Honda de liana",
		kind = "Ranged",
		sound = "ShootStone",
		damage = 21,
		critChance = 0.15,
		cooldownSeconds = 0.8,
		range = 110,
		ammoItemId = "Stone",
		projectileSpeed = 170,
		finisher = "Stagger",
	},
	BoneAxe = {
		name = "Hacha de hueso",
		kind = "Melee",
		damage = 22,
		cooldownSeconds = 0.65,
		range = 8,
		swingAnimationSpeed = 2,
		tool = { kind = "Axe", power = 3, bonus = 3 },
	},
	BonePick = {
		name = "Pico de hueso",
		kind = "Melee",
		damage = 20,
		cooldownSeconds = 0.65,
		range = 8,
		swingAnimationSpeed = 2,
		tool = { kind = "Pick", power = 3, bonus = 2 },
	},
	BigFangClub = {
		name = "Garrote de colmillo grande",
		kind = "Melee",
		sound = "SwingHeavy",
		damage = 46,
		critChance = 0.15,
		cooldownSeconds = 1.1,
		range = 10,
		swingAnimationSpeed = 1.5,
	},
	-- Hoz (mesa de trabajo): cada tajo corta los helechos y arbustos de delante, sin mantener E.
	Sickle = {
		name = "Hoz",
		kind = "Melee",
		sound = "SwingLight",
		damage = 10,
		cooldownSeconds = 0.5,
		range = 7,
		swingAnimationSpeed = 2.2,
		tool = { kind = "Sickle", power = 1, bonus = 0 },
	},
	StoneAxe = {
		name = "Hacha de piedra",
		kind = "Melee",
		damage = 16,
		cooldownSeconds = 0.7,
		range = 8,
		swingAnimationSpeed = 2,
		tool = { kind = "Axe", power = 2, bonus = 2 },
	},
	StonePick = {
		name = "Pico de piedra",
		kind = "Melee",
		damage = 14,
		cooldownSeconds = 0.7,
		range = 8,
		swingAnimationSpeed = 2,
		tool = { kind = "Pick", power = 2, bonus = 1 },
	},
	Spear = {
		name = "Lanza de colmillo",
		kind = "Melee",
		sound = "SwingThrust",
		damage = 24,
		critChance = 0.10,
		cooldownSeconds = 0.8,
		range = 12,
		swingAnimationSpeed = 1.8,
	},
	-- Armas iniciales de los roles (Data/Roles).
	StoneClub = {
		name = "Garrote de piedra",
		kind = "Melee",
		sound = "SwingHeavy",
		damage = 30,
		cooldownSeconds = 0.9,
		range = 9,
		swingAnimationSpeed = 1.6,
	},
	Bow = {
		name = "Arco",
		kind = "Ranged",
		sound = "ShootArrow",
		damage = 19,
		cooldownSeconds = 0.8,
		range = 130,
		ammoItemId = "Arrow",
		projectileSpeed = 200,
		projectile = "Arrow",
		finisher = "Pierce",
	},
	MagicStaff = {
		name = "Bastón mágico",
		kind = "Ranged",
		sound = "ShootSpell",
		damage = 15,
		cooldownSeconds = 0.9,
		range = 100,
		projectileSpeed = 120,
		projectile = "Spell",
		spell = true,
		finisher = "Burst",
	},
	-- Médico: dispara dardos de savia, sin munición, que envenenan. Casi todo el daño del médico es el
	-- de su cerbatana (medido con la calculadora ServerStorage.Tools.Equilibrio: ~60 % del de un rol de
	-- daño contra un mono, también con las mejoras de la forja).
	Blowgun = {
		name = "Cerbatana",
		kind = "Ranged",
		sound = "ShootDart",
		damage = 15,
		cooldownSeconds = 0.7,
		range = 110,
		projectileSpeed = 170,
		projectile = "Dart",
		healOnHit = 2,
		poison = { dps = 5, seconds = 4, boostItemId = "VenomDart" },
		finisher = "Sap",
	},
	Club = {
		name = "Garrote con colmillos",
		kind = "Melee",
		sound = "SwingHeavy",
		damage = 34,
		critChance = 0.10,
		cooldownSeconds = 1.1,
		range = 10,
		swingAnimationSpeed = 1.5,
	},
	-- Mejoras de las armas de rol (Data/Recipes, solo para su rol): dos niveles por arma.
	BoneMace = {
		name = "Maza de hueso",
		kind = "Melee",
		sound = "SwingHeavy",
		damage = 40,
		critChance = 0.10,
		cooldownSeconds = 0.85,
		range = 9.5,
		swingAnimationSpeed = 1.6,
	},
	ThickBoneMaul = {
		name = "Mazo de hueso grueso",
		kind = "Melee",
		sound = "SwingHeavy",
		damage = 55,
		critChance = 0.15,
		cooldownSeconds = 0.95,
		range = 10,
		swingAnimationSpeed = 1.5,
	},
	ReinforcedBow = {
		name = "Arco reforzado",
		kind = "Ranged",
		sound = "ShootArrow",
		damage = 27,
		critChance = 0.10,
		cooldownSeconds = 0.75,
		range = 145,
		ammoItemId = "Arrow",
		projectileSpeed = 220,
		projectile = "Arrow",
		finisher = "Pierce",
	},
	LianaBow = {
		name = "Arco de liana",
		kind = "Ranged",
		sound = "ShootArrow",
		damage = 37,
		critChance = 0.15,
		cooldownSeconds = 0.7,
		range = 165,
		ammoItemId = "Arrow",
		projectileSpeed = 250,
		projectile = "Arrow",
		finisher = "Pierce",
	},
	BoneBlowgun = {
		name = "Cerbatana de hueso",
		kind = "Ranged",
		sound = "ShootDart",
		damage = 18,
		critChance = 0.10,
		cooldownSeconds = 0.65,
		range = 125,
		projectileSpeed = 190,
		projectile = "Dart",
		healOnHit = 3,
		poison = { dps = 7, seconds = 4, boostItemId = "VenomDart" },
		finisher = "Sap",
	},
	ShamanBlowgun = {
		name = "Cerbatana del chamán",
		kind = "Ranged",
		sound = "ShootDart",
		damage = 23,
		critChance = 0.15,
		cooldownSeconds = 0.6,
		range = 140,
		projectileSpeed = 210,
		projectile = "Dart",
		healOnHit = 5,
		poison = { dps = 9, seconds = 4, boostItemId = "VenomDart" },
		finisher = "Sap",
	},
	-- Fase 9 (G5): nivel 4 de las armas de rol, en la forja volcánica (obsidiana y cristal de cueva).
	-- ~+30 % de DPS sobre el nivel 3, como el salto anterior.
	VolcanicMaul = {
		name = "Mazo volcánico",
		kind = "Melee",
		sound = "SwingHeavy",
		damage = 68,
		critChance = 0.2,
		cooldownSeconds = 0.9,
		range = 10.5,
		swingAnimationSpeed = 1.5,
	},
	EmberBow = {
		name = "Arco de brasa",
		kind = "Ranged",
		sound = "ShootArrow",
		damage = 45,
		critChance = 0.2,
		cooldownSeconds = 0.65,
		range = 180,
		ammoItemId = "Arrow",
		projectileSpeed = 280,
		projectile = "Arrow",
		finisher = "Pierce",
	},
	SulfurBlowgun = {
		name = "Cerbatana de azufre",
		kind = "Ranged",
		sound = "ShootDart",
		damage = 27,
		critChance = 0.2,
		cooldownSeconds = 0.55,
		range = 150,
		projectileSpeed = 230,
		projectile = "Dart",
		healOnHit = 7,
		poison = { dps = 11, seconds = 4, boostItemId = "VenomDart" },
		finisher = "Sap",
	},
	LavaStaff = {
		name = "Bastón de lava",
		kind = "Ranged",
		sound = "ShootSpell",
		damage = 36,
		critChance = 0.2,
		cooldownSeconds = 0.75,
		range = 140,
		projectileSpeed = 165,
		projectile = "Spell",
		spell = true,
		finisher = "Burst",
	},
	GoldenStaff = {
		name = "Bastón dorado",
		kind = "Ranged",
		sound = "ShootSpell",
		damage = 21,
		critChance = 0.10,
		cooldownSeconds = 0.85,
		range = 110,
		projectileSpeed = 135,
		projectile = "Spell",
		spell = true,
		finisher = "Burst",
	},
	SilverStaff = {
		name = "Bastón de plata",
		kind = "Ranged",
		sound = "ShootSpell",
		damage = 29,
		critChance = 0.15,
		cooldownSeconds = 0.8,
		range = 125,
		projectileSpeed = 150,
		projectile = "Spell",
		spell = true,
		finisher = "Burst",
	},
}

for id, weapon in LabWeapons.weapons do
	Weapons[id] = weapon :: any
end

return Weapons
