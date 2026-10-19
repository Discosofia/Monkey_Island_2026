--!strict
-- Piezas que se pueden construir en el Basecamp con el martillo (GDD §10, Fase 2.2).
-- "zones": dónde se pueden poner. Core = núcleo compartido (cualquiera); Plot = tu parcela;
-- Perimeter = el resto del Basecamp hasta la empalizada y los portones (defensas, Fase 2.5).
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
	zones: { Core: boolean?, Plot: boolean?, Perimeter: boolean? },
	maxPerPlayer: number?, -- límite de esta pieza por jugador (nil = sin límite propio)
	station: string?, -- si es una estación de crafteo (Data/Stations), su id
	maxPerServer: number?, -- límite para todo el servidor (nido, baliza)
	-- Sonido cuando la golpean (clave de Data/Sounds.Effects); por defecto StructureHit (madera).
	hitSound: string?,
	-- No cierra el paso: los monos del asedio la cruzan en vez de pararse a romperla (las estacas).
	walkable: boolean?,
	-- Se va hundiendo en el suelo al perder vida: se ve cuánto le queda (las estacas).
	sinkOnWear: boolean?,
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
		zones = { Core = true, Plot = true, Perimeter = true },
	},
	StoneWall = {
		name = "Muro de piedra",
		icon = "🧱",
		description = "Más del doble de resistente que el de madera.",
		order = 2,
		size = Vector3.new(8, 8, 1.4),
		cost = { { itemId = "Stone", amount = 6 }, { itemId = "Wood", amount = 2 } },
		health = 450,
		zones = { Core = true, Plot = true, Perimeter = true },
		hitSound = "StructureHitStone",
	},
	StandingTorch = {
		name = "Antorcha de pie",
		icon = "🔥",
		description = "Ilumina el Basecamp de noche.",
		order = 3,
		size = Vector3.new(1.2, 6, 1.2),
		cost = { { itemId = "Wood", amount = 2 }, { itemId = "Fiber", amount = 1 } },
		health = 60,
		zones = { Core = true, Plot = true, Perimeter = true },
	},
	Bed = {
		name = "Cama",
		icon = "🛏️",
		description = "Solo en tu parcela. Si caes y no te reaniman, reapareces aquí.",
		order = 4,
		size = Vector3.new(4, 1.6, 7),
		cost = { { itemId = "Wood", amount = 6 }, { itemId = "Fiber", amount = 4 } },
		health = 100,
		zones = { Plot = true },
		maxPerPlayer = 1,
	},
	-- Barricada del ancho exacto de un portón de la empalizada (19 studs entre postes): lo cierra de
	-- una vez. Solo en el perímetro.
	GateBarricade = {
		name = "Barricada de portón",
		icon = "🚧",
		description = "Cierra un portón entero. Colócala centrada en el hueco (R para girarla).",
		order = 2.5,
		size = Vector3.new(18.4, 9, 1.6),
		cost = {
			{ itemId = "Wood", amount = 14 },
			{ itemId = "Stone", amount = 8 },
		},
		health = 900,
		zones = { Perimeter = true },
	},
	-- Trampa (Fase 2.5): hiere a los monos que pasan por encima y se desgasta con cada golpe.
	Spikes = {
		name = "Estacas",
		icon = "🔺",
		description = "Trampa de 4×4 con puntas hacia todos los lados: da igual por dónde lleguen los monos. "
			.. "Encajan en la cuadrícula: ponlas en fila para cubrir un portón.",
		order = 4.5,
		size = Vector3.new(4, 2, 4),
		cost = { { itemId = "Wood", amount = 4 }, { itemId = "Stone", amount = 1 } },
		health = 100,
		zones = { Perimeter = true },
		walkable = true,
		sinkOnWear = true,
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
	-- Fase 5: el nido donde se incuban los huevos rescatados.
	Nest = {
		name = "Nido",
		icon = "🥚",
		description = "Lleva aquí el huevo misterioso y defiéndelo mientras se incuba.",
		order = 7,
		size = Vector3.new(7, 3, 7),
		cost = {
			{ itemId = "Wood", amount = 12 },
			{ itemId = "Fiber", amount = 10 },
			{ itemId = "GoldenFur", amount = 2 },
		},
		health = 600,
		zones = { Core = true },
		maxPerServer = 1,
	},
	-- Fase 6: la baliza de rescate (la antigua radio del laboratorio). Con las 4 piezas de los jefes y
	-- desde el día Config.Match.BeaconUnlockDay se enciende: esa noche llega La Gran Tropa.
	Beacon = {
		name = "Baliza de rescate",
		icon = "📡",
		description = "Constrúyela en el núcleo. Con las 4 piezas de los jefes, enciéndela para pedir rescate.",
		order = 8,
		size = Vector3.new(6, 12, 6),
		cost = {
			{ itemId = "Wood", amount = 20 },
			{ itemId = "Stone", amount = 20 },
			{ itemId = "ShipMetal", amount = 6 },
		},
		health = 2500,
		zones = { Core = true },
		maxPerServer = 1,
		hitSound = "StructureHitStone",
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
		hitSound = "StructureHitStone",
	},
}

return Buildables
