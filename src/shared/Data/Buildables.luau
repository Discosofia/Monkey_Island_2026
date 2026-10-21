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
	-- Multiplicador del daño de los monos del asedio a esta pieza (por defecto
	-- Config.Siege.StructureDamageMultiplier). La baliza lo baja: la Gran Tropa tarda en romperla.
	siegeDamageMultiplier: number?,
	-- A 0 de vida no desaparece: queda derribada ("Broken") hasta que se repara (la baliza, G8).
	breaksInPlace: boolean?,
	-- Solo la rompen los monos que van a por ella (Config.Siege.BeaconRaid); los demás la rodean, así
	-- que lo que aguanta no depende de si está en el camino de la hoguera (la baliza, G8).
	raidOnly: boolean?,
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
		description = "Ilumina el Basecamp de noche y espanta a los aulladores del asedio (se consume).",
		order = 3,
		size = Vector3.new(1.2, 6, 1.2),
		cost = { { itemId = "Wood", amount = 2 }, { itemId = "Fiber", amount = 1 } },
		health = 120,
		zones = { Core = true, Plot = true, Perimeter = true },
	},
	-- Fase 9 (G8): aura defensiva para preparar la Gran Tropa (DefenseService, Config.Siege.Totem).
	WarTotem = {
		name = "Tótem guardián",
		icon = "🗿",
		description = "Uno por campamento. Cerca de él las piezas reciben menos daño y se reparan de noche, "
			.. "y los jugadores reciben menos daño.",
		order = 7.5,
		size = Vector3.new(4, 9, 4),
		cost = {
			{ itemId = "Wood", amount = 20 },
			{ itemId = "Stone", amount = 15 },
			{ itemId = "Obsidian", amount = 5 },
			{ itemId = "RiverPearl", amount = 1 },
		},
		-- En la Gran Tropa sin defender, con 800 caía en la 2.ª oleada.
		health = 1500,
		zones = { Core = true },
		maxPerServer = 1,
		hitSound = "StructureHitStone",
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
		description = "Constrúyela en el núcleo. Con las 4 piezas de los jefes, enciéndela y defiéndela esa noche: "
			.. "si cae, no hay rescate.",
		order = 8,
		size = Vector3.new(6, 12, 6),
		cost = {
			{ itemId = "Wood", amount = 20 },
			{ itemId = "Stone", amount = 20 },
			{ itemId = "ShipMetal", amount = 6 },
		},
		health = 16000,
		zones = { Core = true },
		maxPerServer = 1,
		hitSound = "StructureHitStone",
		-- La Gran Tropa va a por ella (Config.Siege.BeaconRaid): cada golpe le quita la mitad del daño del
		-- mono (no ×3 como a un muro). Medido en Studio (día 8, solo, sin defenderla, dos noches): 35–45
		-- de daño por segundo en la 3.ª oleada y 95–130 en la 4.ª (según por qué portón entran); con
		-- 12.000 caía al final de la 4.ª. Con 16.000 cae entre 10 y 30 s después de llegar la 5.ª (a
		-- ~6 min de los 7 de noche); matando a la mitad de los que van a por ella llega justa al
		-- amanecer. Si cae, no hay rescate esa noche (BeaconService).
		siegeDamageMultiplier = 0.5,
		breaksInPlace = true,
		raidOnly = true,
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
	-- Fase 9 (G5): horno de obsidiana con lava. Pide la obsidiana del volcán o de la cueva.
	VolcanicForge = {
		name = "Forja volcánica",
		icon = "🌋",
		description = "Estación: el nivel 4 de tu arma y tu armadura (obsidiana y cristal de cueva).",
		order = 6.5,
		size = Vector3.new(7, 6, 7),
		cost = {
			{ itemId = "Stone", amount = 25 },
			{ itemId = "Obsidian", amount = 8 },
			{ itemId = "ThickBone", amount = 2 },
		},
		health = 700,
		zones = { Core = true },
		station = "VolcanicForge",
		hitSound = "StructureHitStone",
	},
}

return Buildables
