--!strict
-- Talentos por rol (GDD §6.3, Fase 3). Se aprenden en el Lobby con puntos de talento, que se ganan
-- con la XP de ese rol (Shared/Progression). Cada rango suma "perRank" a la ventaja "perk".
-- Cada talento mejora una de las 4 habilidades del rol (el del médico, además, su pasiva).
-- Si se quita un talento, los puntos que tuviera gastados vuelven a quedar libres solos.

export type Talent = {
	name: string,
	description: string,
	order: number,
	perk: string, -- ver Data/Perks
	perRank: number,
	maxRank: number,
}

local Talents: { [string]: { [string]: Talent } } = {
	Guerrero = {
		LongSpin = {
			name = "Remolino",
			description = "El Torbellino dura 0,5 s más por rango.",
			order = 1,
			perk = "WhirlwindSeconds",
			perRank = 0.5,
			maxRank = 3,
		},
		Battering = {
			name = "Ariete",
			description = "+20 % de daño de la Embestida por rango.",
			order = 2,
			perk = "ChargeDamage",
			perRank = 0.2,
			maxRank = 3,
		},
		ThickSkin = {
			name = "Piel curtida",
			description = "Durante el Grito de guerra recibes un 10 % menos de daño por rango.",
			order = 3,
			perk = "WarCryReduction",
			perRank = 0.1,
			maxRank = 3,
		},
		Aftershock = {
			name = "Réplica",
			description = "El Golpe sísmico aturde 0,5 s más por rango.",
			order = 4,
			perk = "QuakeStun",
			perRank = 0.5,
			maxRank = 3,
		},
	},
	Cazador = {
		Volley = {
			name = "Andanada",
			description = "+1 proyectil en el Disparo múltiple por rango.",
			order = 1,
			perk = "MultiShotCount",
			perRank = 1,
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
		StrongVines = {
			name = "Muelles fuertes",
			description = "El cepo sujeta 1 s más por rango.",
			order = 3,
			perk = "TrapRoot",
			perRank = 1,
			maxRank = 2,
		},
		Downpour = {
			name = "Diluvio",
			description = "+20 % de daño de la Lluvia de proyectiles por rango.",
			order = 4,
			perk = "RainDamage",
			perRank = 0.2,
			maxRank = 3,
		},
	},
	Mago = {
		Wildfire = {
			name = "Llama viva",
			description = "+20 % de daño de la Bola de fuego por rango.",
			order = 1,
			perk = "FireballDamage",
			perRank = 0.2,
			maxRank = 3,
		},
		DeepFrost = {
			name = "Escarcha",
			description = "La Nova de hielo congela 0,5 s más por rango.",
			order = 2,
			perk = "NovaFreeze",
			perRank = 0.5,
			maxRank = 3,
		},
		LongStep = {
			name = "Paso largo",
			description = "El Parpadeo avanza 5 studs más por rango.",
			order = 3,
			perk = "BlinkDistance",
			perRank = 5,
			maxRank = 2,
		},
		Storm = {
			name = "Tormenta",
			description = "El Rayo encadenado salta a 1 mono más por rango.",
			order = 4,
			perk = "ChainJumps",
			perRank = 1,
			maxRank = 3,
		},
	},
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
			description = "+25 % de curación por rango (vendas, ungüentos, dardo y tótem).",
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
		ThickLeaves = {
			name = "Hojas gruesas",
			description = "El Escudo de hojas absorbe 10 de daño más por rango.",
			order = 4,
			perk = "ShieldAmount",
			perRank = 10,
			maxRank = 3,
		},
	},
}

return Talents
