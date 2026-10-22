--!strict
-- Cosméticos (GDD §14, Fase 6; ampliado en la Fase 9): solo cambian el aspecto, nunca dan ventaja.
-- Cada uno dice de dónde sale en "source":
--   - gamePassId: Game Pass (se compra una vez y es para siempre). Crea el pase en el Creator Hub
--     (docs/LANZAMIENTO.md) y pon aquí su ID.
--   - productId: Developer Product de la tienda rotativa (lo entrega ServerShared/Purchases y se
--     guarda en el perfil). "price" es solo el número que se enseña; el de verdad está en el Creator Hub.
--   - amber: precio en Ámbar (tienda de Ámbar). season: premio del pase de esa temporada (Data/Seasons,
--     lo entrega ServerShared/SeasonPass).
--   - earned: se gana jugando ("Rescue": ganar una partida de verdad; "MasterVictory": ganarla con el
--     rol del cosmético llevando su arma de rol y la armadura del nivel 4, island/DataService). Ni en
--     Studio es gratis.
--   - free: lo tiene todo el mundo desde el principio (los emotes de serie).
-- Un id de Robux a 0 sale como "Próximamente" (en Studio se prueba gratis con
-- Config.Cosmetics.FreeInStudio). Lo que se tiene sin Game Pass se guarda en el perfil
-- ("ownedCosmetics", ServerShared/CosmeticsServer).
-- Tipos y su hueco de equipo (Shared/CosmeticSlots): Trail (estela), Title (título sobre la cabeza),
-- Aura y Frame (marco), uno de cada; Outfit (traje) y WeaponSkin (aspecto del arma), uno por rol
-- ("role"); PetSkin, uno por mascota ("petId") o, en las que comparten modelo, uno por familia
-- ("petFamily", Data/Pets: la misma skin vale para los tres felinos); Emote, hasta
-- Config.Cosmetics.EmoteSlots a la vez (la rueda; con la rueda vacía salen Config.Cosmetics.DefaultEmotes).
-- Los modelos: trajes en Shared/ArmorModels (OUTFITS), aspectos de arma en Shared/WeaponTools (SKINS),
-- skins de mascota en Shared/PetModels (SKINS) y marcos en Shared/UI/PlayerFrames (STYLES).
-- Tipos baratos para llenar la premium (G9d), uno de cada: NumberStyle (colores y letra de los números
-- de daño que haces, Shared/UI/CombatTextColumn STYLES; los aliados también lo ven), BurstStyle
-- (colores y palabras de tus estallidos de cómic, Shared/UI/ComicBurst STYLES) y NestDecor
-- (decoración de tu nido del Lobby, Shared/NestDecor). Su imagen del pase y del Armario está en
-- Shared/RewardModels.cosmetic.
-- Grados (I, II, III): el mismo cosmético más intenso en tres niveles del pase. Cada grado es un
-- cosmético propio con la misma "line" y su "grade"; se equipa la línea y se ve siempre el grado más
-- alto que tienes (Shared/CosmeticSlots.best), y el Armario enseña una sola tarjeta por línea.
--
-- Rareza y detalle (cuanto más raro, más trabajo en el diseño): Común y Poco común, color y una forma
-- sencilla; Raro, varios materiales y un motivo propio; Épico, piezas con relieve y algo que brilla;
-- Legendario, luces y partículas y una espalda llamativa; Mítico (por encima de Legendario), lo más
-- detallado del juego: el traje y el arma ganan piezas con el nivel de la armadura y del arma (del 0 al
-- 4 en la Isla; enteros en el Lobby y en Dunas), con luz, partículas y una pieza enorme a la espalda.
-- Hay un traje y un aspecto de arma míticos por rol, los "dioses de la selva": el traje se gana
-- (earned "MasterVictory") y el arma se vende suelta en la tienda de Robux.

export type Kind =
	"Trail"
	| "Title"
	| "Aura"
	| "Outfit"
	| "WeaponSkin"
	| "PetSkin"
	| "Emote"
	| "Frame"
	| "NumberStyle"
	| "BurstStyle"
	| "NestDecor"

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type Source = {
	gamePassId: number?,
	productId: number?,
	price: number?,
	amber: number?,
	season: string?,
	earned: ("Rescue" | "MasterVictory")?,
	free: boolean?,
}

export type Cosmetic = {
	name: string,
	icon: string,
	kind: Kind,
	description: string,
	order: number,
	rarity: Rarity,
	color: Color3,
	source: Source,
	title: string?, -- Title: el texto que se ve
	role: string?, -- Outfit y WeaponSkin: el rol al que va
	weapon: string?, -- WeaponSkin de un arma que no es de rol: su familia ("Machete", Shared/WeaponTools)
	petId: string?, -- PetSkin: la mascota (Data/Pets)
	petFamily: string?, -- PetSkin de familia: vale para todas las mascotas con ese "family" (Data/Pets)
	animationId: string?, -- Emote: la animación publicada (rbxassetid://…)
	line: string?, -- cosmético por grados: los grados de una misma línea comparten este id
	grade: number?, -- su grado en la línea (1, 2 o 3: I, II, III)
	colors: { Color3 }?, -- Trail: franjas de arriba abajo (una estela por color) en vez de "color"
	sparkle: Color3?, -- Trail: chispas de este color que caen de la estela
	look: ("Sand" | "Storm" | "Petals")?, -- Aura: otra forma en vez de las chispas (ServerShared/CosmeticsServer)
}

-- El fuego azul y el azufre de la temporada 1.
local BLUE_FIRE = Color3.fromRGB(45, 120, 255)
local SULFUR_YELLOW = Color3.fromRGB(235, 205, 55)

local Cosmetics: { [string]: Cosmetic } = {
	GoldenTrail = {
		name = "Estela dorada",
		icon = "✨",
		kind = "Trail",
		description = "Dejas un rastro dorado al moverte.",
		order = 1,
		rarity = "Epic",
		color = Color3.fromRGB(255, 205, 70),
		source = { gamePassId = 2040772314 },
	},
	JungleTrail = {
		name = "Estela de la selva",
		icon = "🌿",
		kind = "Trail",
		description = "Un rastro verde de hojas.",
		order = 2,
		rarity = "Rare",
		color = Color3.fromRGB(90, 210, 90),
		source = { gamePassId = 2038168760 },
	},
	TitleKing = {
		name = "Título: Rey de la selva",
		icon = "👑",
		kind = "Title",
		description = "Muestra «Rey de la selva» sobre tu cabeza.",
		order = 3,
		rarity = "Epic",
		color = Color3.fromRGB(255, 215, 90),
		source = { gamePassId = 2036836741 },
		title = "👑 Rey de la selva",
	},
	TitleSurvivor = {
		name = "Título: Superviviente de la Isla",
		icon = "🏝️",
		kind = "Title",
		description = "Solo para quien ha ganado una partida: rescatados con la baliza.",
		order = 5,
		rarity = "Legendary",
		color = Color3.fromRGB(255, 160, 70),
		source = { earned = "Rescue" },
		title = "🏝️ Superviviente de la Isla",
	},
	BananaAura = {
		name = "Aura de banana",
		icon = "🍌",
		kind = "Aura",
		description = "Brillitos amarillos a tu alrededor.",
		order = 4,
		rarity = "Rare",
		color = Color3.fromRGB(255, 235, 90),
		source = { gamePassId = 2037898785 },
	},

	-- Temporada 1, "El Despertar del Volcán" (Data/Seasons). Provisionales hasta el contenido de la
	-- temporada (grupo G11 del plan): solo de los tipos que ya se dibujan (título, estela y aura).
	-- Pista gratis:
	TitleCastaway = {
		name = "Título: Náufrago del Volcán",
		icon = "🌋",
		kind = "Title",
		description = "Pase de temporada 1, nivel 1 (gratis).",
		order = 6,
		rarity = "Common",
		color = Color3.fromRGB(235, 170, 110),
		source = { season = "T1" },
		title = "🌋 Náufrago del Volcán",
	},
	AshTrail = {
		name = "Estela de ceniza",
		icon = "🌫️",
		kind = "Trail",
		description = "Pase de temporada 1, nivel 15 (gratis): un rastro gris de ceniza.",
		order = 7,
		rarity = "Uncommon",
		color = Color3.fromRGB(150, 145, 140),
		source = { season = "T1" },
	},
	TitleVolcanoLord = {
		name = "Título: Señor del Volcán",
		icon = "🔥",
		kind = "Title",
		description = "Pase de temporada 1, nivel 30 (gratis).",
		order = 8,
		rarity = "Rare",
		color = Color3.fromRGB(255, 120, 60),
		source = { season = "T1" },
		title = "🔥 Señor del Volcán",
	},
	-- Pista premium:
	-- El aura que evoluciona: I en el nivel 1, II en el 15 y III en el 30.
	PrimalFlameAura = {
		name = "Aura: Llama primal I",
		icon = "🔥",
		kind = "Aura",
		description = "Pase de temporada 1, nivel 1 (premium): chispas de fuego a tu alrededor. Crece en los niveles 15 y 30.",
		order = 9,
		rarity = "Epic",
		color = Color3.fromRGB(255, 110, 30),
		source = { season = "T1" },
		line = "PrimalFlame",
		grade = 1,
	},
	PrimalFlameAuraII = {
		name = "Aura: Llama primal II",
		icon = "🔥",
		kind = "Aura",
		description = "Pase de temporada 1, nivel 15 (premium): llamas que te envuelven y más chispas.",
		order = 9.1,
		rarity = "Epic",
		color = Color3.fromRGB(255, 110, 30),
		source = { season = "T1" },
		line = "PrimalFlame",
		grade = 2,
	},
	PrimalFlameAuraIII = {
		name = "Aura: Llama primal III",
		icon = "🔥",
		kind = "Aura",
		description = "Pase de temporada 1, nivel 30 (premium): una hoguera viva con brasas, humo y su luz.",
		order = 9.2,
		rarity = "Legendary",
		color = Color3.fromRGB(255, 110, 30),
		source = { season = "T1" },
		line = "PrimalFlame",
		grade = 3,
	},
	MagmaStepTrail = {
		name = "Estela: Pisada de magma",
		icon = "🌋",
		kind = "Trail",
		description = "Pase de temporada 1, nivel 11 (premium): un rastro de lava.",
		order = 10,
		rarity = "Epic",
		color = Color3.fromRGB(255, 70, 20),
		source = { season = "T1" },
	},
	TitlePrimalKing = {
		name = "Título: Rey de la Isla Primal",
		icon = "👑",
		kind = "Title",
		description = "Pase de temporada 1, nivel 29 (premium).",
		order = 11,
		rarity = "Legendary",
		color = Color3.fromRGB(255, 90, 40),
		source = { season = "T1" },
		title = "👑 Rey de la Isla Primal",
	},

	-- Ejemplos de skin de mascota, marcos y emotes (G9c). La Tortuga de Lava y los marcos son premios de
	-- la temporada 1 (G11 los pone en su nivel); los emotes de serie usan las animaciones de Roblox.
	LavaTurtleSkin = {
		name = "Skin: Tortuga de Lava",
		icon = "🐢",
		kind = "PetSkin",
		description = "Tu tortuga con un caparazón de basalto, grietas de lava y un volcancito que humea.",
		order = 12,
		rarity = "Rare",
		color = Color3.fromRGB(255, 120, 40),
		source = { season = "T1" },
		petId = "Tortuga",
	},
	BronzeFrame = {
		name = "Marco de bronce",
		icon = "🥉",
		kind = "Frame",
		description = "Un borde de bronce con remaches para tu nombre en el ranking, el grupo y los resultados.",
		order = 13,
		rarity = "Uncommon",
		color = Color3.fromRGB(215, 140, 70),
		source = { season = "T1" },
	},
	MoltenObsidianFrame = {
		name = "Marco: Obsidiana fundida",
		icon = "🌋",
		kind = "Frame",
		description = "Obsidiana con lava que corre por el borde y brasas que suben de tu nombre.",
		order = 14,
		rarity = "Legendary",
		color = Color3.fromRGB(255, 110, 30),
		source = { season = "T1" },
	},

	-- Trajes y armas de la temporada 1 (G11a), un traje y un arma por rol y el machete gratis: fuego azul y azufre sobre piedra pómez
	-- (Shared/ArmorModels y Shared/WeaponTools), para no confundirse con la armadura y las armas
	-- volcánicas del nivel 4. Los trajes ganan piezas con el grado de la armadura de debajo, como los míticos.
	BlueFireGuardianOutfit = {
		name = "Traje: Guardián del Fuego Azul",
		icon = "🔥",
		kind = "Outfit",
		description = "Pase de temporada 1, nivel 5 (premium): coraza de pómez con un corazón de fuego azul y, a la espalda, un escudo de azufre en llamas.",
		order = 18,
		rarity = "Legendary",
		color = BLUE_FIRE,
		source = { season = "T1" },
		role = "Guerrero",
	},
	SulfurMace = {
		name = "Arma: Maza de Azufre",
		icon = "🔥",
		kind = "WeaponSkin",
		description = "Pase de temporada 1, nivel 3 (premium): cristales de azufre en una jaula de piedra para tu maza de guerrero. Arde en azul en el nivel 4.",
		order = 18.1,
		rarity = "Epic",
		color = BLUE_FIRE,
		source = { season = "T1" },
		role = "Guerrero",
	},
	BlueFireStalkerOutfit = {
		name = "Traje: Acechador del Fuego Azul",
		icon = "🔥",
		kind = "Outfit",
		description = "Pase de temporada 1, nivel 10 (premium): capa de pómez y un carcaj cuyas flechas arden en azul.",
		order = 18.2,
		rarity = "Legendary",
		color = BLUE_FIRE,
		source = { season = "T1" },
		role = "Cazador",
	},
	SulfurBow = {
		name = "Arma: Arco de Azufre",
		icon = "🔥",
		kind = "WeaponSkin",
		description = "Pase de temporada 1, nivel 7 (premium): palas de carbón con puntas de azufre para tu arco. Arde en azul en el nivel 4.",
		order = 18.3,
		rarity = "Epic",
		color = BLUE_FIRE,
		source = { season = "T1" },
		role = "Cazador",
	},
	BlueFireInvokerOutfit = {
		name = "Traje: Invocador del Fuego Azul",
		icon = "🔥",
		kind = "Outfit",
		description = "Pase de temporada 1, nivel 20 (premium): túnica de carbón y, a la espalda, un aro de piedra del que brota fuego azul.",
		order = 18.4,
		rarity = "Legendary",
		color = BLUE_FIRE,
		source = { season = "T1" },
		role = "Mago",
	},
	SulfurStaff = {
		name = "Arma: Bastón de Azufre",
		icon = "🔥",
		kind = "WeaponSkin",
		description = "Pase de temporada 1, nivel 13 (premium): un racimo de cristales de azufre en lo alto de tu bastón. Arde en azul en el nivel 4.",
		order = 18.5,
		rarity = "Epic",
		color = BLUE_FIRE,
		source = { season = "T1" },
		role = "Mago",
	},
	BlueFireHealerOutfit = {
		name = "Traje: Sanador del Fuego Azul",
		icon = "🔥",
		kind = "Outfit",
		description = "Pase de temporada 1, nivel 25 (premium): manto de pómez, frascos que curan y un incensario de fuego azul a la espalda.",
		order = 18.6,
		rarity = "Legendary",
		color = BLUE_FIRE,
		source = { season = "T1" },
		role = "Medico",
	},
	SulfurBlowgun = {
		name = "Arma: Cerbatana de Azufre",
		icon = "🔥",
		kind = "WeaponSkin",
		description = "Pase de temporada 1, nivel 18 (premium): caña de pómez con cristales de azufre en la boca. Arde en azul en el nivel 4.",
		order = 18.7,
		rarity = "Epic",
		color = BLUE_FIRE,
		source = { season = "T1" },
		role = "Medico",
	},
	-- Pista gratis: el aspecto del machete, para el cazador, el mago y el médico (el guerrero no lo lleva).
	SulfurMachete = {
		name = "Arma: Machete de Azufre",
		icon = "🔥",
		kind = "WeaponSkin",
		description = "Pase de temporada 1, nivel 8 (gratis): una hoja de cristal de azufre para tu machete. Con filo de fuego azul cuando lo afilas.",
		order = 18.8,
		rarity = "Rare",
		color = SULFUR_YELLOW,
		source = { season = "T1" },
		weapon = "Machete",
	},

	-- Tipos baratos (G9d), un ejemplo de cada; G11 los pone en su nivel del pase.
	MagmaNumbers = {
		name = "Números: Magma",
		icon = "🔢",
		kind = "NumberStyle",
		description = "Pase de temporada 1, nivel 6 (premium): tu daño en letras gruesas de lava que se enfría.",
		order = 15,
		rarity = "Rare",
		color = Color3.fromRGB(255, 140, 40),
		source = { season = "T1" },
	},
	VolcanicBurst = {
		name = "Estallido: Erupción",
		icon = "💥",
		kind = "BurstStyle",
		description = "Pase de temporada 1, nivel 8 (premium): tus golpes estallan en lava y ceniza, «KABOOM!».",
		order = 16,
		rarity = "Rare",
		color = Color3.fromRGB(255, 95, 30),
		source = { season = "T1" },
	},
	VolcanicNest = {
		name = "Nido: Volcánico",
		icon = "🥚",
		kind = "NestDecor",
		description = "Pase de temporada 1, nivel 12 (premium): tu nido rodeado de basalto, un foso de lava y obsidiana.",
		order = 17,
		rarity = "Rare",
		color = Color3.fromRGB(255, 120, 45),
		source = { season = "T1" },
	},

	-- Tiendas de cosméticos (G10, Shared/CosmeticShop): tienda en Ámbar (rotación diaria) y sueltos de
	-- Robux (rotación semanal, con las armas míticas). Tema "selva y mar", distinto del volcán de la
	-- temporada 1 para que la tienda no le quite el sitio al pase. Precios por rareza: en Ámbar, común
	-- 400, poco común 600, raro 900, épico 1.200 y legendario 1.500 (los 22 suman 19.000: el habitual
	-- gasta casi todo lo que gana y no acaba la tienda antes del día 30, calculadora Economia); en
	-- Robux, poco común 99, raro 149, épico 199 y legendario 249.
	TitleBananaHunter = {
		name = "Título: Cazaplátanos",
		icon = "🍌",
		kind = "Title",
		description = "Muestra «Cazaplátanos» sobre tu cabeza.",
		order = 40,
		rarity = "Common",
		color = Color3.fromRGB(255, 225, 90),
		source = { amber = 400 },
		title = "🍌 Cazaplátanos",
	},
	TitleCoconutBreaker = {
		name = "Título: Rompecocos",
		icon = "🥥",
		kind = "Title",
		description = "Muestra «Rompecocos» sobre tu cabeza.",
		order = 41,
		rarity = "Common",
		color = Color3.fromRGB(210, 165, 110),
		source = { amber = 400 },
		title = "🥥 Rompecocos",
	},
	TitleMonkeyTamer = {
		name = "Título: Domador de monos",
		icon = "🐒",
		kind = "Title",
		description = "Muestra «Domador de monos» sobre tu cabeza.",
		order = 42,
		rarity = "Uncommon",
		color = Color3.fromRGB(255, 170, 90),
		source = { amber = 600 },
		title = "🐒 Domador de monos",
	},
	TideTrail = {
		name = "Estela de marea",
		icon = "🌊",
		kind = "Trail",
		description = "Un rastro azul de agua de mar al moverte.",
		order = 43,
		rarity = "Rare",
		color = Color3.fromRGB(60, 160, 255),
		source = { amber = 900 },
	},
	CoralAura = {
		name = "Aura de coral",
		icon = "🪸",
		kind = "Aura",
		description = "Brillitos color coral a tu alrededor.",
		order = 44,
		rarity = "Rare",
		color = Color3.fromRGB(255, 135, 120),
		source = { amber = 900 },
	},
	FrostNumbers = {
		name = "Números: Escarcha",
		icon = "🔢",
		kind = "NumberStyle",
		description = "Tu daño en letras gruesas de hielo, blancas arriba y azules abajo.",
		order = 45,
		rarity = "Rare",
		color = Color3.fromRGB(120, 205, 255),
		source = { productId = 0, price = 149 },
	},
	-- G10b, tienda en Ámbar:
	TitlePalmClimber = {
		name = "Título: Trepapalmeras",
		icon = "🌴",
		kind = "Title",
		description = "Muestra «Trepapalmeras» sobre tu cabeza.",
		order = 46,
		rarity = "Common",
		color = Color3.fromRGB(255, 205, 120),
		source = { amber = 400 },
		title = "🌴 Trepapalmeras",
	},
	TitleChattyParrot = {
		name = "Título: Loro parlanchín",
		icon = "🦜",
		kind = "Title",
		description = "Muestra «Loro parlanchín» sobre tu cabeza.",
		order = 47,
		rarity = "Common",
		color = Color3.fromRGB(100, 185, 255),
		source = { amber = 400 },
		title = "🦜 Loro parlanchín",
	},
	TitleAlphaHunter = {
		name = "Título: Cazador de alfas",
		icon = "🦍",
		kind = "Title",
		description = "Muestra «Cazador de alfas» sobre tu cabeza.",
		order = 48,
		rarity = "Uncommon",
		color = Color3.fromRGB(225, 230, 240),
		source = { amber = 600 },
		title = "🦍 Cazador de alfas",
	},
	TitleJungleExplorer = {
		name = "Título: Explorador de la selva",
		icon = "🗺️",
		kind = "Title",
		description = "Muestra «Explorador de la selva» sobre tu cabeza.",
		order = 49,
		rarity = "Uncommon",
		color = Color3.fromRGB(240, 215, 155),
		source = { amber = 600 },
		title = "🗺️ Explorador de la selva",
	},
	MacawTrail = {
		name = "Estela de guacamaya",
		icon = "🦜",
		kind = "Trail",
		description = "Un rastro de plumas en tres franjas: escarlata, amarillo y azul.",
		order = 50,
		rarity = "Rare",
		color = Color3.fromRGB(235, 60, 40),
		source = { amber = 900 },
		colors = { Color3.fromRGB(235, 60, 40), Color3.fromRGB(255, 200, 40), Color3.fromRGB(40, 110, 230) },
	},
	AuroraTrail = {
		name = "Estela de aurora",
		icon = "🌌",
		kind = "Trail",
		description = "Un rastro largo que brilla: turquesa, azul cielo y rosa.",
		order = 51,
		rarity = "Epic",
		color = Color3.fromRGB(60, 230, 220),
		source = { amber = 1200 },
		colors = { Color3.fromRGB(60, 230, 220), Color3.fromRGB(90, 150, 255), Color3.fromRGB(255, 120, 200) },
	},
	SandAura = {
		name = "Aura: Remolino de arena",
		icon = "🏜️",
		kind = "Aura",
		description = "Un remolino de arena de playa gira a tus pies, con granos que brillan.",
		order = 52,
		rarity = "Rare",
		color = Color3.fromRGB(235, 205, 145),
		source = { amber = 900 },
		look = "Sand",
	},
	StormAura = {
		name = "Aura: Tormenta",
		icon = "⛈️",
		kind = "Aura",
		description = "Una nube negra sobre tu cabeza, chispas eléctricas y su luz azul.",
		order = 53,
		rarity = "Epic",
		color = Color3.fromRGB(150, 210, 255),
		source = { amber = 1200 },
		look = "Storm",
	},
	BambooFrame = {
		name = "Marco de bambú",
		icon = "🎋",
		kind = "Frame",
		description = "Cañas de bambú con sus nudos y las esquinas atadas.",
		order = 54,
		rarity = "Uncommon",
		color = Color3.fromRGB(215, 190, 110),
		source = { amber = 600 },
	},
	CoralFrame = {
		name = "Marco de coral",
		icon = "🪸",
		kind = "Frame",
		description = "Coral rosa y blanco con una perla en cada esquina.",
		order = 55,
		rarity = "Rare",
		color = Color3.fromRGB(255, 135, 125),
		source = { amber = 900 },
	},
	TempleGoldFrame = {
		name = "Marco: Oro del templo",
		icon = "🏛️",
		kind = "Frame",
		description = "Oro del templo perdido que brilla al correr por el borde, con turquesas en las esquinas.",
		order = 56,
		rarity = "Epic",
		color = Color3.fromRGB(255, 200, 60),
		source = { amber = 1200 },
	},
	CoralNumbers = {
		name = "Números: Coral",
		icon = "🔢",
		kind = "NumberStyle",
		description = "Tu daño en letras de coral, rosa claro arriba y rosa hondo abajo, con borde de mar.",
		order = 57,
		rarity = "Rare",
		color = Color3.fromRGB(255, 140, 130),
		source = { amber = 900 },
	},
	SunsetNumbers = {
		name = "Números: Atardecer",
		icon = "🔢",
		kind = "NumberStyle",
		description = "Tu daño con los colores del atardecer en la playa: sol amarillo, rosa y azul de noche.",
		order = 58,
		rarity = "Epic",
		color = Color3.fromRGB(255, 160, 100),
		source = { amber = 1200 },
	},
	SplashBurst = {
		name = "Estallido: Chapuzón",
		icon = "💦",
		kind = "BurstStyle",
		description = "Tus golpes salpican agua de mar y espuma, «SPLASH!».",
		order = 59,
		rarity = "Rare",
		color = Color3.fromRGB(90, 190, 255),
		source = { amber = 900 },
	},
	LightningBurst = {
		name = "Estallido: Rayo",
		icon = "⚡",
		kind = "BurstStyle",
		description = "Tus golpes caen como rayos en una nube de tormenta, «KRAKK!».",
		order = 60,
		rarity = "Epic",
		color = Color3.fromRGB(255, 230, 60),
		source = { amber = 1200 },
	},
	CoralBeachNest = {
		name = "Nido: Playa de coral",
		icon = "🐚",
		kind = "NestDecor",
		description = "Tu nido en una playa de arena con conchas, estrellas de mar, coral y una palmera.",
		order = 61,
		rarity = "Epic",
		color = Color3.fromRGB(255, 175, 140),
		source = { amber = 1200 },
	},
	PirateDogSkin = {
		name = "Skin: Perro pirata",
		icon = "☠️",
		kind = "PetSkin",
		description = "Para tus tres perros: pañuelo rojo, parche, aro de oro, camiseta de marinero y la bandera pirata a la espalda.",
		order = 62,
		rarity = "Legendary",
		color = Color3.fromRGB(240, 200, 80),
		source = { amber = 1500 },
		petFamily = "Perro",
	},
	-- G10b, sueltos de Robux:
	TitlePirateCaptain = {
		name = "Título: Capitán pirata",
		icon = "☠️",
		kind = "Title",
		description = "Muestra «Capitán pirata» sobre tu cabeza.",
		order = 63,
		rarity = "Uncommon",
		color = Color3.fromRGB(245, 240, 225),
		source = { productId = 0, price = 99 },
		title = "☠️ Capitán pirata",
	},
	NeonBurst = {
		name = "Estallido: Neón",
		icon = "🕹️",
		kind = "BurstStyle",
		description = "Tus golpes como en una máquina recreativa: negro, rosa y celeste de neón, «BLIP!».",
		order = 64,
		rarity = "Rare",
		color = Color3.fromRGB(255, 80, 160),
		source = { productId = 0, price = 149 },
	},
	PetalAura = {
		name = "Aura: Lluvia de pétalos",
		icon = "🌸",
		kind = "Aura",
		description = "Pétalos rosas y blancos que caen despacio a tu alrededor.",
		order = 65,
		rarity = "Epic",
		color = Color3.fromRGB(255, 165, 205),
		source = { productId = 0, price = 199 },
		look = "Petals",
	},
	DiamondFrame = {
		name = "Marco de diamante",
		icon = "💎",
		kind = "Frame",
		description = "Un borde de diamante que destella, con gemas en las esquinas y chispas que suben.",
		order = 66,
		rarity = "Epic",
		color = Color3.fromRGB(170, 235, 255),
		source = { productId = 0, price = 199 },
	},
	StardustTrail = {
		name = "Estela: Polvo de estrellas",
		icon = "🌠",
		kind = "Trail",
		description = "Un rastro azul de noche que deja caer estrellitas doradas.",
		order = 67,
		rarity = "Legendary",
		color = Color3.fromRGB(45, 70, 175),
		source = { productId = 0, price = 249 },
		sparkle = Color3.fromRGB(255, 215, 90),
	},
	GoldenTempleNest = {
		name = "Nido: Templo dorado",
		icon = "🛕",
		kind = "NestDecor",
		description = "Tu nido en lo alto de un templo de piedra, con ídolos de oro y antorchas encendidas.",
		order = 68,
		rarity = "Legendary",
		color = Color3.fromRGB(255, 200, 60),
		source = { productId = 0, price = 249 },
	},

	EmoteWave = {
		name = "Emote: Saludar",
		icon = "👋",
		kind = "Emote",
		description = "Saluda con la mano.",
		order = 30,
		rarity = "Common",
		color = Color3.fromRGB(255, 225, 150),
		source = { free = true },
		animationId = "rbxassetid://507770239",
	},
	EmotePoint = {
		name = "Emote: Señalar",
		icon = "👉",
		kind = "Emote",
		description = "Señala hacia delante: ¡por allí!",
		order = 31,
		rarity = "Common",
		color = Color3.fromRGB(255, 225, 150),
		source = { free = true },
		animationId = "rbxassetid://507770453",
	},
	EmoteCheer = {
		name = "Emote: ¡Ánimo!",
		icon = "🙌",
		kind = "Emote",
		description = "Levanta los brazos para animar al grupo.",
		order = 32,
		rarity = "Common",
		color = Color3.fromRGB(255, 225, 150),
		source = { free = true },
		animationId = "rbxassetid://507770677",
	},
	EmoteLaugh = {
		name = "Emote: Reír",
		icon = "😂",
		kind = "Emote",
		description = "Una buena carcajada.",
		order = 33,
		rarity = "Common",
		color = Color3.fromRGB(255, 225, 150),
		source = { free = true },
		animationId = "rbxassetid://507770818",
	},
	EmoteDance = {
		name = "Emote: Bailar",
		icon = "💃",
		kind = "Emote",
		description = "Baila hasta que te muevas.",
		order = 34,
		rarity = "Common",
		color = Color3.fromRGB(255, 225, 150),
		source = { free = true },
		animationId = "rbxassetid://507771019",
	},

	-- Míticos, los dioses de la selva (uno de cada por rol; G9a: el guerrero; G9b: el cazador, el mago y
	-- el médico).
	TitanKingOutfit = {
		name = "Traje: Rey Gorila Titán",
		icon = "🦍",
		kind = "Outfit",
		description = "Gana una partida de guerrero con la Maza y la Armadura volcánicas. Crece con tu armadura.",
		order = 20,
		rarity = "Mythic",
		color = Color3.fromRGB(70, 225, 150),
		source = { earned = "MasterVictory" },
		role = "Guerrero",
	},
	TitanKingMace = {
		name = "Arma: Maza del Rey Gorila",
		icon = "🦍",
		kind = "WeaponSkin",
		description = "El puño de piedra del Rey Gorila para tu maza de guerrero. Crece con tu arma.",
		order = 21,
		rarity = "Mythic",
		color = Color3.fromRGB(70, 225, 150),
		source = { productId = 0, price = 449 },
		role = "Guerrero",
	},
	SpectralJaguarOutfit = {
		name = "Traje: Jaguar Espectral",
		icon = "🐆",
		kind = "Outfit",
		description = "Gana una partida de cazador con el Arco y el Manto de brasa. Crece con tu armadura.",
		order = 22,
		rarity = "Mythic",
		color = Color3.fromRGB(190, 240, 255),
		source = { earned = "MasterVictory" },
		role = "Cazador",
	},
	SpectralJaguarBow = {
		name = "Arma: Arco del Jaguar Espectral",
		icon = "🐆",
		kind = "WeaponSkin",
		description = "Garras de oro y el espíritu del jaguar para tu arco de cazador. Crece con tu arma.",
		order = 23,
		rarity = "Mythic",
		color = Color3.fromRGB(190, 240, 255),
		source = { productId = 0, price = 449 },
		role = "Cazador",
	},
	FeatheredSerpentOutfit = {
		name = "Traje: Serpiente Emplumada",
		icon = "🐍",
		kind = "Outfit",
		description = "Gana una partida de mago con el Bastón y la Túnica de lava. Crece con tu armadura.",
		order = 24,
		rarity = "Mythic",
		color = Color3.fromRGB(95, 215, 255),
		source = { earned = "MasterVictory" },
		role = "Mago",
	},
	FeatheredSerpentStaff = {
		name = "Arma: Báculo de la Serpiente Emplumada",
		icon = "🐍",
		kind = "WeaponSkin",
		description = "La serpiente de plumas sostiene el cristal de tu bastón de mago. Crece con tu arma.",
		order = 25,
		rarity = "Mythic",
		color = Color3.fromRGB(95, 215, 255),
		source = { productId = 0, price = 449 },
		role = "Mago",
	},
	CeibaOfLifeOutfit = {
		name = "Traje: Ceiba de la Vida",
		icon = "🌳",
		kind = "Outfit",
		description = "Gana una partida de médico con la Cerbatana y el Manto de azufre. Crece con tu armadura.",
		order = 26,
		rarity = "Mythic",
		color = Color3.fromRGB(120, 255, 150),
		source = { earned = "MasterVictory" },
		role = "Medico",
	},
	CeibaBlowgun = {
		name = "Arma: Cerbatana de la Ceiba",
		icon = "🌳",
		kind = "WeaponSkin",
		description = "Una rama de la ceiba sagrada, con espinas y savia que cura, para tu cerbatana. Crece con tu arma.",
		order = 27,
		rarity = "Mythic",
		color = Color3.fromRGB(120, 255, 150),
		source = { productId = 0, price = 449 },
		role = "Medico",
	},
}

return Cosmetics
