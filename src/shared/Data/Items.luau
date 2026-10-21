--!strict
-- Ítems del juego. Fase 1.2: materiales básicos. Fase 1.4: botín de los monos. Fase 1.6: vendas.
-- Fase 2.1: comida.
-- "order" decide el orden en el HUD del inventario; "alwaysShow" lo muestra aunque tengas 0.
-- "food" hace que se pueda comer (G, cruceta izquierda o el botón "Comer"): cuánto recupera.
-- "heal" hace que se pueda usar para curarse (H, cruceta arriba o el botón "Curar"): vida que da.
-- "groupHeal": lo mismo, pero cura a la vez al que lo usa y a los aliados cercanos
-- (Config.Crafting.PoulticeRadius); con aliados heridos cerca, Curar lo usa antes que nada.
-- "poisonMultiplier": munición opcional de las cerbatanas ("boostItemId" en Data/Weapons): mientras
-- quede, cada disparo gasta una y su veneno se multiplica por esto.
-- "rarity" (Data/Rarities) da color al nombre en el inventario y el diario; sin ella, Común.
-- "group" pone el objeto en otra sección de la Bolsa ("Materials", "Food", "Healing", "Loot",
-- "Treasure", "Gear"); sin él, la decide lo que hace (comida, curación, siempre visible o botín).
-- "keep": no se pierde nunca (ni lo roban los monos ni se queda en la mochila al caer): el equipo y
-- los tesoros de jefe, que piden las mejoras de la forja y no se pueden volver a conseguir.
-- "note": para qué sirve, en el detalle de la Bolsa.
-- Iconos: usa emojis anteriores a 2020; los más nuevos (🪵, 🪨…) Roblox los muestra como un cuadro vacío.

export type ItemDefinition = {
	name: string,
	icon: string,
	order: number,
	alwaysShow: boolean?,
	food: FoodDefinition?,
	heal: number?,
	groupHeal: number?,
	poisonMultiplier: number?,
	rarity: string?,
	group: string?,
	keep: boolean?,
	note: string?,
}

export type FoodDefinition = {
	hunger: number,
	thirst: number,
	raw: boolean?, -- cruda: sube la fiebre (Config.Fever.RawMeat) y "Comer" la deja para el final
}

local Items: { [string]: ItemDefinition } = {
	Wood = { name = "Madera", icon = "🌲", order = 1, alwaysShow = true },
	Stone = { name = "Piedra", icon = "⛰️", order = 2, alwaysShow = true },
	Fiber = { name = "Fibra", icon = "🌿", order = 3, alwaysShow = true },
	Meat = { name = "Carne cruda", icon = "🥩", order = 4, food = { hunger = 8, thirst = 0, raw = true } },
	RedFur = { name = "Pelaje rojo", icon = "🐾", order = 5 },
	GoldenFur = { name = "Pelaje dorado", icon = "✨", order = 6, rarity = "Uncommon" },
	SmallFang = { name = "Colmillo", icon = "🔺", order = 7, rarity = "Uncommon" },
	Bandage = { name = "Venda", icon = "➕", order = 8, heal = 30 },
	CookedMeat = { name = "Carne asada", icon = "🍖", order = 9, food = { hunger = 35, thirst = 0 } },
	Banana = { name = "Banano", icon = "🍌", order = 10, food = { hunger = 15, thirst = 5 } },
	Skewer = { name = "Brocheta", icon = "🍢", order = 11, food = { hunger = 60, thirst = 5 } },
	Coconut = { name = "Coco", icon = "🥥", order = 12, food = { hunger = 5, thirst = 25 } },
	-- Fase 9 (G7): se hierve en la hoguera; con lluvia tóxica es la que no da fiebre (como el coco).
	BoiledWater = { name = "Agua hervida", icon = "🍵", order = 12.5, food = { hunger = 0, thirst = 30 } },
	-- Fase 2.3: botín de hueso y productos del taller del curandero.
	Bone = { name = "Hueso", icon = "🦴", order = 13 },
	Ointment = { name = "Ungüento", icon = "🧴", order = 14, heal = 70 },
	Antidote = { name = "Antídoto", icon = "💉", order = 15, group = "Healing" },
	-- Matas de plátano de los cultivos: crudo alimenta poco, asado en la hoguera mucho más.
	Plantain = { name = "Plátano", icon = "🥒", order = 16, food = { hunger = 6, thirst = 0 } },
	RoastedPlantain = { name = "Plátano asado", icon = "🍠", order = 17, food = { hunger = 28, thirst = 0 } },
	-- Munición del arco del cazador (Data/Weapons).
	Arrow = { name = "Flecha", icon = "🏹", order = 18, group = "Materials" },
	-- Taller del curandero: cura entre la venda y el ungüento.
	SuperBandage = { name = "Super venda", icon = "🩹", order = 19, heal = 50 },
	-- Taller del curandero, solo para el médico (Data/Recipes "role").
	ReviveKit = {
		name = "Kit de reanimación",
		icon = "🧰",
		order = 33,
		group = "Healing",
		note = "Al reanimar a un aliado se gasta: lo levantas al momento y con más vida",
	},
	GroupPoultice = { name = "Cataplasma de grupo", icon = "🥣", order = 34, group = "Healing", groupHeal = 35 },
	VenomDart = {
		name = "Dardo venenoso",
		icon = "🐸",
		order = 35,
		group = "Materials",
		poisonMultiplier = 1.6,
		note = "La cerbatana los dispara solos mientras queden: su veneno pega más",
	},
	-- Equipo: la antorcha fabricada (receta "Torch"). De día se guarda aquí; de noche va encendida
	-- en la mano izquierda (TorchService).
	Torch = {
		name = "Antorcha",
		icon = "🔥",
		order = 45,
		group = "Gear",
		keep = true,
		note = "De noche se enciende sola en tu mano izquierda",
	},
	-- Fase 4: botín de las nuevas especies.
	BlackFur = { name = "Pelaje negro", icon = "🖤", order = 20 },
	Liana = { name = "Liana resistente", icon = "🌱", order = 21, rarity = "Uncommon" },
	TinyTooth = { name = "Diente diminuto", icon = "▫️", order = 22 },
	Whisker = { name = "Bigotes de marteja", icon = "〰️", order = 23, rarity = "Rare" },
	MandrillFang = { name = "Colmillo de mandril", icon = "🔻", order = 24, rarity = "Rare" },
	GreyFur = { name = "Pelaje gris", icon = "☁️", order = 25 },
	LabCard = { name = "Tarjeta de laboratorio", icon = "💳", order = 26, rarity = "Epic" },
	Leather = { name = "Cuero", icon = "👢", order = 27 },
	BigFang = { name = "Colmillo grande", icon = "🔶", order = 28, rarity = "Uncommon" },
	Shell = { name = "Concha", icon = "🐚", order = 29 },
	ThickBone = { name = "Hueso grueso", icon = "🦴", order = 30, rarity = "Rare" },
	OrangeFur = { name = "Pelaje naranja", icon = "🍊", order = 31, rarity = "Rare" },
	SilverFur = { name = "Pelaje plateado", icon = "⚪", order = 32, rarity = "Epic" },
	-- Fase 5: botín especial de los jefes (Config.Bosses.LootPerPlayer para cada uno que le hizo daño).
	-- Fase 9 (G5): la corona y el cristal piden las mejoras de nivel 3 y 4 de la forja (Data/Recipes).
	RiverPearl = {
		name = "Perla del río",
		icon = "🔮",
		order = 40,
		rarity = "Legendary",
		group = "Treasure",
		keep = true,
		note = "El tótem guardián del Basecamp la pide (martillo)",
	},
	ChieftainCrown = {
		name = "Corona del caudillo",
		icon = "👑",
		order = 41,
		rarity = "Legendary",
		group = "Treasure",
		keep = true,
		note = "La forja de piedra la pide para el nivel 3 de tu arma y la armadura de plata",
	},
	CaveCrystal = {
		name = "Cristal de cueva",
		icon = "💎",
		order = 42,
		rarity = "Legendary",
		group = "Treasure",
		keep = true,
		note = "La forja volcánica lo pide, con obsidiana, para el nivel 4 de tu arma y tu armadura",
	},
	MagmaCore = {
		name = "Núcleo de magma",
		icon = "🌋",
		order = 43,
		rarity = "Legendary",
		group = "Treasure",
		keep = true,
	},
	ShipMetal = { name = "Metal de naufragio", icon = "⚙️", order = 44, rarity = "Uncommon", group = "Treasure" },
	-- Fase 9 (G5): roca negra de las laderas del volcán y la sala de la cueva (Data/ResourceNodes).
	Obsidian = {
		name = "Obsidiana",
		icon = "⬛",
		order = 36,
		rarity = "Rare",
		note = "Vetas negras con grietas de lava en las laderas del volcán y en la sala de la cueva: se pican",
	},
}

return Items
