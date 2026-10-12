--!strict
-- Especies de monos (GDD §8.2). Fase 1.4: las dos primeras de la categoría 1.
-- Para balancear, cambia los números aquí. Las distancias están en studs.

export type LootEntry = {
	itemId: string, -- ver Data/Items
	chance: number, -- 0 a 1
	min: number,
	max: number,
}

export type MonkeyDefinition = {
	name: string,
	tier: number,
	activeAt: "Day" | "Night" | "Both", -- cuándo aparece en la isla
	groups: number, -- grupos repartidos por la isla
	groupMin: number,
	groupMax: number,
	maxHealth: number,
	walkSpeed: number,
	damage: number,
	attackCooldownSeconds: number,
	attackRange: number,
	aggroRange: number, -- a qué distancia te detecta
	leashRange: number, -- cuánto se aleja de su zona antes de rendirse y volver
	fleeHealthFraction: number?, -- huye cuando le queda menos de esta fracción de vida
	howl: boolean?, -- aúlla al detectarte: avisa a los monos cercanos y llama refuerzos
	scale: number,
	bodyColor: Color3,
	faceColor: Color3,
	loot: { LootEntry },
}

local Monkeys: { [string]: MonkeyDefinition } = {
	MonoArdilla = {
		name = "Mono ardilla",
		tier = 1,
		activeAt = "Day",
		groups = 14,
		groupMin = 3,
		groupMax = 6,
		maxHealth = 30,
		walkSpeed = 20,
		damage = 5,
		attackCooldownSeconds = 1,
		attackRange = 4.5,
		aggroRange = 45,
		leashRange = 120,
		fleeHealthFraction = 0.3,
		scale = 0.7,
		bodyColor = Color3.fromRGB(205, 160, 70),
		faceColor = Color3.fromRGB(245, 220, 180),
		loot = {
			{ itemId = "GoldenFur", chance = 0.6, min = 1, max = 1 },
			{ itemId = "Meat", chance = 0.5, min = 1, max = 1 },
		},
	},
	AulladorRojo = {
		name = "Mono aullador rojo",
		tier = 1,
		activeAt = "Both",
		groups = 10,
		groupMin = 1,
		groupMax = 3,
		maxHealth = 60,
		walkSpeed = 15,
		damage = 8,
		attackCooldownSeconds = 1.4,
		attackRange = 5,
		aggroRange = 55,
		leashRange = 140,
		howl = true,
		scale = 1,
		bodyColor = Color3.fromRGB(150, 55, 30),
		faceColor = Color3.fromRGB(60, 35, 25),
		loot = {
			{ itemId = "RedFur", chance = 0.7, min = 1, max = 1 },
			{ itemId = "SmallFang", chance = 0.3, min = 1, max = 1 },
			{ itemId = "Meat", chance = 0.6, min = 1, max = 2 },
		},
	},
}

return Monkeys
