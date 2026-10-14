--!strict
-- Mejoras permanentes de la tienda del Lobby (Fase 3), pagadas con Ámbar.
-- "costs[n]" es lo que cuesta el rango n. Cada rango suma "perRank" a la ventaja "perk" (Data/Perks).

export type Upgrade = {
	name: string,
	icon: string,
	description: string,
	order: number,
	perk: string,
	perRank: number,
	costs: { number },
}

local Upgrades: { [string]: Upgrade } = {
	StrongHeart = {
		name = "Corazón fuerte",
		icon = "❤️",
		description = "+10 de vida máxima por rango.",
		order = 1,
		perk = "MaxHealth",
		perRank = 10,
		costs = { 50, 100, 200 },
	},
	IronStomach = {
		name = "Estómago de hierro",
		icon = "🍖",
		description = "El hambre y la sed bajan un 8 % más despacio por rango.",
		order = 2,
		perk = "HungerRate",
		perRank = -0.08,
		costs = { 40, 80, 160 },
	},
	CastawayKit = {
		name = "Kit de náufrago",
		icon = "🎒",
		description = "Empiezas cada partida con 5 de madera, piedra y fibra por rango.",
		order = 3,
		perk = "StartKit",
		perRank = 1,
		costs = { 30, 60, 120 },
	},
	RunnerLungs = {
		name = "Pulmones de corredor",
		icon = "⚡",
		description = "Correr gasta un 10 % menos de estamina por rango.",
		order = 4,
		perk = "SprintCost",
		perRank = -0.1,
		costs = { 60, 120 },
	},
	-- Antes eran ventajas del recolector; ahora cualquier rol puede comprarlas.
	QuickGather = {
		name = "Manos ágiles",
		icon = "🖐️",
		description = "Recoges un 10 % más rápido por rango.",
		order = 5,
		perk = "HarvestSpeed",
		perRank = -0.1,
		costs = { 40, 80, 160 },
	},
	KeenEye = {
		name = "Ojo para el botín",
		icon = "👀",
		description = "+1 material en cada recolección por rango.",
		order = 6,
		perk = "HarvestBonus",
		perRank = 1,
		costs = { 80, 200 },
	},
	StrongArms = {
		name = "Brazos fuertes",
		icon = "💪",
		description = "El hacha y el pico avanzan más con cada golpe.",
		order = 7,
		perk = "ToolPower",
		perRank = 0.34,
		costs = { 50, 100, 200 },
	},
}

return Upgrades
