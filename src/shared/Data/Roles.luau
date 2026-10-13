--!strict
-- Roles (GDD §6.3, Fase 3). Se eligen en el Lobby y son fijos durante la partida.
-- "perks": ventajas pasivas (se suman a Data/Perks). "ability": habilidad activa (G, R1 o el botón
-- "Habilidad"), que gestiona AbilityService en la Isla.

export type Role = {
	name: string,
	icon: string,
	order: number,
	passive: string, -- texto para el jugador
	perks: { [string]: number },
	ability: {
		id: string,
		name: string,
		description: string,
		cooldownSeconds: number,
	},
}

local Roles: { [string]: Role } = {
	Medico = {
		name = "Médico",
		icon = "⛑️",
		order = 1,
		passive = "Reanima el doble de rápido y ve la vida de sus aliados.",
		perks = { ReviveSpeed = -0.5, SeeHealth = 1 },
		ability = {
			id = "AreaHeal",
			name = "Ungüento en área",
			description = "Cura 30 de vida a los aliados cercanos (y a ti).",
			cooldownSeconds = 60,
		},
	},
	Cazador = {
		name = "Cazador",
		icon = "🏹",
		order = 2,
		passive = "+25 % de daño a distancia.",
		perks = { RangedDamage = 0.25 },
		ability = {
			id = "MarkPrey",
			name = "Marcar presas",
			description = "Señala a todos los monos cercanos: el equipo los ve y les hace más daño.",
			cooldownSeconds = 35,
		},
	},
	Recolector = {
		name = "Recolector",
		icon = "🧺",
		order = 3,
		passive = "Recoge un 30 % más rápido y saca +1 material de cada recurso.",
		perks = { HarvestSpeed = -0.3, HarvestBonus = 1 },
		ability = {
			id = "Frenzy",
			name = "Recolección frenética",
			description = "Durante 20 s, el hacha y el pico golpean el doble de fuerte.",
			cooldownSeconds = 70,
		},
	},
}

return Roles
