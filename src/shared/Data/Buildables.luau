--!strict
-- Piezas que se pueden construir en el Basecamp con el martillo (GDD §10, Fase 2.2).
-- "zones": dónde se pueden poner. Core = núcleo compartido (cualquiera); Plot = tu parcela.
-- "health" es la vida de la pieza: la usará el asedio nocturno (entrega 2.5) para romper defensas.
-- Para balancear, cambia los números aquí.

export type Cost = { itemId: string, amount: number }

export type Buildable = {
	name: string,
	icon: string, -- emoji anterior a 2020
	description: string,
	order: number,
	size: Vector3, -- caja que ocupa (ancho, alto, fondo) en studs
	cost: { Cost },
	health: number,
	zones: { Core: boolean?, Plot: boolean? },
	maxPerPlayer: number?, -- límite de esta pieza por jugador (nil = sin límite propio)
	station: string?, -- si es una estación de crafteo (Data/Stations), su id
}

local Buildables: { [string]: Buildable } = {
	WoodWall = {
		name = "Muro de madera",
		icon = "🌲",
		description = "Barato y rápido de poner.",
		order = 1,
		size = Vector3.new(8, 8, 1),
		cost = { { itemId = "Wood", amount = 6 } },
		health = 200,
		zones = { Core = true, Plot = true },
	},
	StoneWall = {
		name = "Muro de piedra",
		icon = "🧱",
		description = "Más del doble de resistente que el de madera.",
		order = 2,
		size = Vector3.new(8, 8, 1.4),
		cost = { { itemId = "Stone", amount = 6 }, { itemId = "Wood", amount = 2 } },
		health = 450,
		zones = { Core = true, Plot = true },
	},
	StandingTorch = {
		name = "Antorcha de pie",
		icon = "🔥",
		description = "Ilumina el Basecamp de noche.",
		order = 3,
		size = Vector3.new(1.2, 6, 1.2),
		cost = { { itemId = "Wood", amount = 2 }, { itemId = "Fiber", amount = 1 } },
		health = 60,
		zones = { Core = true, Plot = true },
	},
	Bed = {
		name = "Cama",
		icon = "🛏️",
		description = "Solo en tu parcela. Al volver de Espíritu reapareces aquí.",
		order = 4,
		size = Vector3.new(4, 1.6, 7),
		cost = { { itemId = "Wood", amount = 6 }, { itemId = "Fiber", amount = 4 } },
		health = 100,
		zones = { Plot = true },
		maxPerPlayer = 1,
	},
	-- Estaciones (Fase 2.3): se construyen en el núcleo y las usa todo el equipo.
	HealerTent = {
		name = "Taller del curandero",
		icon = "🌿",
		description = "Estación: ungüentos, vendas y antídotos.",
		order = 5,
		size = Vector3.new(8, 6, 6),
		cost = {
			{ itemId = "Wood", amount = 10 },
			{ itemId = "Fiber", amount = 8 },
			{ itemId = "RedFur", amount = 2 },
		},
		health = 300,
		zones = { Core = true },
		station = "Healer",
	},
	StoneForge = {
		name = "Forja de piedra",
		icon = "⚒️",
		description = "Estación: equipo de hueso y colmillo.",
		order = 6,
		size = Vector3.new(6, 5, 6),
		cost = { { itemId = "Stone", amount = 20 }, { itemId = "Wood", amount = 6 } },
		health = 500,
		zones = { Core = true },
		station = "Forge",
	},
}

return Buildables
