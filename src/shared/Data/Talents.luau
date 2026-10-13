--!strict
-- Talentos por rol (GDD §6.3, Fase 3). Se aprenden en el Lobby con puntos de talento, que se ganan
-- con la XP de ese rol (Shared/Progression). Cada rango suma "perRank" a la ventaja "perk".

export type Talent = {
	name: string,
	description: string,
	order: number,
	perk: string, -- ver Data/Perks
	perRank: number,
	maxRank: number,
}

local Talents: { [string]: { [string]: Talent } } = {
	Medico = {
		QuickHands = {
			name = "Manos rápidas",
			description = "Reanimas aún más rápido.",
			order = 1,
			perk = "ReviveSpeed",
			perRank = -0.1,
			maxRank = 3,
		},
		StrongSalve = {
			name = "Ungüento potente",
			description = "+25 % de curación por rango.",
			order = 2,
			perk = "HealPower",
			perRank = 0.25,
			maxRank = 3,
		},
		SecondWind = {
			name = "Segundo aliento",
			description = "Quien reanimas se levanta con +10 % de vida por rango.",
			order = 3,
			perk = "ReviveHealth",
			perRank = 0.1,
			maxRank = 3,
		},
	},
	Cazador = {
		SharpEye = {
			name = "Ojo certero",
			description = "+10 % de daño a distancia por rango.",
			order = 1,
			perk = "RangedDamage",
			perRank = 0.1,
			maxRank = 3,
		},
		Tracker = {
			name = "Rastreador",
			description = "Las marcas duran 4 s más por rango.",
			order = 2,
			perk = "MarkSeconds",
			perRank = 4,
			maxRank = 3,
		},
		CoupDeGrace = {
			name = "Golpe de gracia",
			description = "Los monos marcados reciben +10 % de daño por rango.",
			order = 3,
			perk = "MarkedBonus",
			perRank = 0.1,
			maxRank = 3,
		},
	},
	Recolector = {
		StrongArms = {
			name = "Brazos fuertes",
			description = "El hacha y el pico avanzan más con cada golpe.",
			order = 1,
			perk = "ToolPower",
			perRank = 0.34,
			maxRank = 3,
		},
		KeenEye = {
			name = "Ojo para el botín",
			description = "+1 material por recolección por rango.",
			order = 2,
			perk = "HarvestBonus",
			perRank = 1,
			maxRank = 2,
		},
		Endurance = {
			name = "Resistencia",
			description = "Correr gasta un 15 % menos de estamina por rango.",
			order = 3,
			perk = "SprintCost",
			perRank = -0.15,
			maxRank = 3,
		},
	},
}

return Talents
