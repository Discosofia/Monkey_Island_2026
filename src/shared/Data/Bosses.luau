--!strict
-- Jefes de bioma (GDD §8.2 categoría 4, Fase 5). Versiones gigantes de las especies difíciles.
-- Aparecen en su guarida (MapBuilder: GuaridasJefes/Guarida_<bioma>) según Config.Match.BossRotation,
-- uno cada Config.Match.BossIntervalDays días, y se quedan hasta que los derrotan o llega el siguiente.
-- Cada uno suelta siempre una pieza de la baliza de rescate (para el servidor) y su botín especial
-- (Config.Bosses.LootPerPlayer para cada jugador que le hizo daño): la corona y el cristal piden las
-- mejoras de nivel 3 y 4 de la forja, una para el arma y otra para la armadura.
--
-- Ataques especiales ("specials"), que se desbloquean por fase (fase 2 al 66 % de vida, 3 al 33 %):
--   stomp      golpe en área que daña y aturde
--   summon     llama a una tropa de "species"
--   rockRain   lluvia de rocas (o lava) sobre los jugadores cercanos, con aviso en el suelo
--   charge     embestida hacia su objetivo
--   grab       agarra a su objetivo (inmoviliza)
--   extinguish rugido que apaga las antorchas de los jugadores cercanos

export type Special = {
	id: string,
	fromPhase: number,
	cooldownSeconds: number,
	species: string?, -- summon
	count: number?, -- summon / rockRain
	-- Desde esta fase lo lanza quieto, invocando con los brazos en alto (animación Invoke) durante
	-- channelSeconds, y solo cuando su objetivo no está a su alcance cuerpo a cuerpo.
	channelFromPhase: number?,
	channelSeconds: number?,
}

export type Boss = {
	name: string,
	description: string, -- lo que cuenta el diario de campo (UI/Journal)
	biome: string,
	baseSpecies: string, -- especie de Data/Monkeys de la que toma el modelo
	scale: number, -- 2,6–3,2: de 9 a 11 studs de alto (GDD §8.2 "Tamaño estándar")
	bodyColor: Color3,
	faceColor: Color3,
	maxHealth: number, -- con un jugador peleando; Config.Bosses la sube con cada jugador más
	walkSpeed: number,
	damage: number,
	attackRange: number,
	attackCooldownSeconds: number,
	aggroRange: number,
	leashRange: number,
	specials: { Special },
	lootItemId: string, -- botín especial para cada jugador que participó
	eruption: boolean?, -- en su última fase provoca una erupción del volcán (WeatherService)
	-- Nombres de las piezas de su modelo que son su punto débil (MonkeyModels les pone WeakPoint = true;
	-- Hitbox.zoneOf las da por zona Weak: daño × Config.Combat.Zones.Weak). Una a la vista, de frente.
	weakPoints: { string }?,
}

local Bosses: { [string]: Boss } = {
	OrangutanDelManglar = {
		name = "Orangután del Manglar",
		description = "El señor del manglar. Agarra a quien se acerca, pisa con fuerza y, cuando está herido, llama a las marimondas.",
		biome = "Rios",
		baseSpecies = "Orangutan",
		scale = 3,
		bodyColor = Color3.fromRGB(150, 60, 22),
		faceColor = Color3.fromRGB(90, 60, 45),
		-- 2100 hasta T7 (27-10-2026): con las definitivas de un solo objetivo y los talentos al máximo caía
		-- en 88 s con 4 jugadores (objetivo ≥ 90).
		maxHealth = 2205,
		walkSpeed = 13,
		damage = 24,
		attackRange = 11,
		attackCooldownSeconds = 1.8,
		aggroRange = 90,
		leashRange = 170,
		specials = {
			{ id = "grab", fromPhase = 1, cooldownSeconds = 9 },
			{ id = "stomp", fromPhase = 2, cooldownSeconds = 11 },
			{ id = "summon", fromPhase = 3, cooldownSeconds = 30, species = "Marimonda", count = 3 },
		},
		lootItemId = "RiverPearl",
		weakPoints = { "ThroatGem" }, -- la gema azul de la bolsa de la garganta
	},
	ChimpanceCaudillo = {
		name = "Chimpancé Caudillo",
		description = "Manda en las montañas: hace llover rocas, llama a su tropa de chimpancés y, furioso, embiste.",
		biome = "Montanas",
		baseSpecies = "Chimpance",
		scale = 2.8,
		bodyColor = Color3.fromRGB(20, 18, 16),
		faceColor = Color3.fromRGB(170, 128, 108),
		maxHealth = 3100,
		walkSpeed = 18,
		damage = 22,
		attackRange = 10,
		attackCooldownSeconds = 1.5,
		aggroRange = 100,
		leashRange = 180,
		specials = {
			{ id = "rockRain", fromPhase = 1, cooldownSeconds = 12, count = 5 },
			{ id = "summon", fromPhase = 2, cooldownSeconds = 28, species = "Chimpance", count = 3 },
			{ id = "charge", fromPhase = 3, cooldownSeconds = 9 },
		},
		lootItemId = "ChieftainCrown",
		weakPoints = { "Medallion" }, -- el medallón dorado del pecho
	},
	GorilaAlbino = {
		name = "Gorila Albino",
		description = "Vive en las cuevas. Su rugido apaga las antorchas; pisa, embiste y llama a los babuinos.",
		biome = "Cuevas",
		baseSpecies = "Gorila",
		scale = 2.9,
		bodyColor = Color3.fromRGB(228, 224, 220),
		faceColor = Color3.fromRGB(195, 135, 140),
		maxHealth = 4700,
		walkSpeed = 15,
		damage = 28,
		attackRange = 11,
		attackCooldownSeconds = 1.7,
		aggroRange = 80,
		leashRange = 150,
		specials = {
			{ id = "extinguish", fromPhase = 1, cooldownSeconds = 18 },
			{ id = "stomp", fromPhase = 1, cooldownSeconds = 10 },
			{ id = "charge", fromPhase = 2, cooldownSeconds = 10 },
			{ id = "summon", fromPhase = 3, cooldownSeconds = 30, species = "Babuino", count = 3 },
		},
		lootItemId = "CaveCrystal",
		weakPoints = { "CrystalCore" }, -- el cristal cian del pecho
	},
	GorilaDeCeniza = {
		name = "Gorila de Ceniza",
		description = "El guardián del volcán. Embiste, hace llover lava y en su furia despierta la erupción.",
		biome = "Volcan",
		baseSpecies = "Gorila",
		-- Un 25 % más grande que el Gorila Albino (2,9): el jefe más imponente de la isla.
		scale = 3.625,
		-- Casi negro: el moteado gris de ceniza de su modelo voxel destaca encima.
		bodyColor = Color3.fromRGB(42, 38, 38),
		faceColor = Color3.fromRGB(255, 110, 40),
		-- 7000 (antes 5600) desde que el nivel 4 de la forja llega el día 7 (G5): sigue durando ~3 min.
		maxHealth = 7000,
		walkSpeed = 16,
		damage = 32,
		attackRange = 14, -- más que los demás: con su tamaño, el hocico queda a ~10 studs de la raíz
		attackCooldownSeconds = 1.6,
		aggroRange = 100,
		leashRange = 180,
		specials = {
			{ id = "charge", fromPhase = 1, cooldownSeconds = 9 },
			{
				id = "rockRain",
				fromPhase = 2,
				cooldownSeconds = 10,
				count = 7,
				channelFromPhase = 3,
				channelSeconds = 2.4,
			},
			{ id = "stomp", fromPhase = 2, cooldownSeconds = 12 },
		},
		lootItemId = "MagmaCore",
		weakPoints = { "LavaCore" }, -- el núcleo blanco incandescente del pecho
		eruption = true,
	},
}

return Bosses
