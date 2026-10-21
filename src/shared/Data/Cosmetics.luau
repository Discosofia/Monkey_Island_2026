--!strict
-- Cosméticos (GDD §14, Fase 6; ampliado en la Fase 9): solo cambian el aspecto, nunca dan ventaja.
-- Cada uno dice de dónde sale en "source":
--   - gamePassId: Game Pass (se compra una vez y es para siempre). Crea el pase en el Creator Hub
--     (docs/LANZAMIENTO.md) y pon aquí su ID.
--   - productId: Developer Product de la tienda rotativa (lo entrega ServerShared/Purchases y se
--     guarda en el perfil). "price" es solo el número que se enseña; el de verdad está en el Creator Hub.
--   - amber: precio en Ámbar (tienda de Ámbar). season: premio del pase de esa temporada (Data/Seasons,
--     lo entrega ServerShared/SeasonPass).
--   - earned: se gana jugando ("Rescue": ganar una partida de verdad). Ni en Studio es gratis.
-- Un id de Robux a 0 sale como "Próximamente" (en Studio se prueba gratis con
-- Config.Cosmetics.FreeInStudio). Lo que se tiene sin Game Pass se guarda en el perfil
-- ("ownedCosmetics", ServerShared/CosmeticsServer).
-- Tipos y su hueco de equipo (Shared/CosmeticSlots): Trail (estela), Title (título sobre la cabeza),
-- Aura y Frame (marco), uno de cada; Outfit (traje) y WeaponSkin (aspecto del arma), uno por rol
-- ("role"); PetSkin, uno por mascota ("petId"); Emote, hasta Config.Cosmetics.EmoteSlots a la vez.

export type Kind = "Trail" | "Title" | "Aura" | "Outfit" | "WeaponSkin" | "PetSkin" | "Emote" | "Frame"

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type Source = {
	gamePassId: number?,
	productId: number?,
	price: number?,
	amber: number?,
	season: string?,
	earned: "Rescue"?,
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
	petId: string?, -- PetSkin: la mascota (Data/Pets)
	animationId: string?, -- Emote: la animación publicada (rbxassetid://…)
}

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
	PrimalFlameAura = {
		name = "Aura: Llama primal",
		icon = "🔥",
		kind = "Aura",
		description = "Pase de temporada 1, nivel 1 (premium): chispas de fuego a tu alrededor.",
		order = 9,
		rarity = "Epic",
		color = Color3.fromRGB(255, 110, 30),
		source = { season = "T1" },
	},
	MagmaStepTrail = {
		name = "Estela: Pisada de magma",
		icon = "🌋",
		kind = "Trail",
		description = "Pase de temporada 1, nivel 10 (premium): un rastro de lava.",
		order = 10,
		rarity = "Epic",
		color = Color3.fromRGB(255, 70, 20),
		source = { season = "T1" },
	},
	TitlePrimalKing = {
		name = "Título: Rey de la Isla Primal",
		icon = "👑",
		kind = "Title",
		description = "Pase de temporada 1, nivel 30 (premium).",
		order = 11,
		rarity = "Legendary",
		color = Color3.fromRGB(255, 90, 40),
		source = { season = "T1" },
		title = "👑 Rey de la Isla Primal",
	},
}

return Cosmetics
