--!strict
-- Armas (GDD §6, Fase 1.3). Para balancear, cambia los números aquí.

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
}

return Weapons
