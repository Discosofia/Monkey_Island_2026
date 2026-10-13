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
	-- Recolección extra mientras la llevas (equipada o en la mochila): { Tree = 1 } = +1 madera por tala.
	harvestBonus: { [string]: number }?,
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
		harvestBonus = { Tree = 1 },
	},
	StonePick = {
		name = "Pico de piedra",
		kind = "Melee",
		damage = 14,
		cooldownSeconds = 0.7,
		range = 8,
		swingAnimationSpeed = 2,
		harvestBonus = { Rock = 1 },
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
