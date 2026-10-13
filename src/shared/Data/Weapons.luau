--!strict
-- Armas y herramientas (GDD §6, Fases 1.3 y 1.6). Para balancear, cambia los números aquí.
-- Las iniciales están en Config.Combat.StarterWeapons; el resto se fabrica (Data/Recipes).

export type WeaponDefinition = {
	name: string,
	kind: "Melee" | "Ranged",
	damage: number,
	cooldownSeconds: number,
	range: number, -- studs
	ammoItemId: string?, -- ítem que gasta cada disparo (ver Data/Items)
	projectileSpeed: number?, -- studs por segundo
	aimAssistDegrees: number?, -- ayuda de puntería: ángulo máximo para "enganchar" un enemigo
	swingAnimationSpeed: number?, -- velocidad del tajo (1 = la animación normal de Roblox)
	-- Herramienta de recolección (hacha, pico): golpeando un árbol o una roca con ella equipada.
	tool: ToolDefinition?,
}

export type ToolDefinition = {
	kind: string, -- "Axe" o "Pick": qué recursos trabaja (ver Data/ResourceNodes)
	power: number, -- progreso por golpe; más potencia = menos golpes por recolección
	bonus: number, -- material extra en cada recolección
}

local Weapons: { [string]: WeaponDefinition } = {
	Machete = {
		name = "Machete",
		kind = "Melee",
		damage = 20,
		cooldownSeconds = 0.6,
		range = 8,
		swingAnimationSpeed = 2,
	},
	-- Fase 2.3: mejora del machete en la forja de piedra.
	SharpMachete = {
		name = "Machete afilado",
		kind = "Melee",
		damage = 28,
		cooldownSeconds = 0.55,
		range = 8.5,
		swingAnimationSpeed = 2,
	},
	Honda = {
		name = "Honda",
		kind = "Ranged",
		damage = 12,
		cooldownSeconds = 0.9,
		range = 90,
		ammoItemId = "Stone",
		projectileSpeed = 140,
		aimAssistDegrees = 12,
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
		damage = 20,
		cooldownSeconds = 0.8,
		range = 110,
		ammoItemId = "Stone",
		projectileSpeed = 170,
		aimAssistDegrees = 12,
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
		damage = 46,
		cooldownSeconds = 1.1,
		range = 10,
		swingAnimationSpeed = 1.5,
	},
	Torch = {
		name = "Antorcha",
		kind = "Melee",
		damage = 8,
		cooldownSeconds = 0.6,
		range = 7,
		swingAnimationSpeed = 2,
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
		damage = 24,
		cooldownSeconds = 0.8,
		range = 12,
		swingAnimationSpeed = 1.8,
	},
	Club = {
		name = "Garrote con colmillos",
		kind = "Melee",
		damage = 34,
		cooldownSeconds = 1.1,
		range = 10,
		swingAnimationSpeed = 1.5,
	},
}

return Weapons
