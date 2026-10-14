--!strict
-- Ítems del juego. Fase 1.2: materiales básicos. Fase 1.4: botín de los monos. Fase 1.6: vendas.
-- Fase 2.1: comida.
-- "order" decide el orden en el HUD del inventario; "alwaysShow" lo muestra aunque tengas 0.
-- "food" hace que se pueda comer (G, cruceta izquierda o el botón "Comer"): cuánto recupera.
-- "heal" hace que se pueda usar para curarse (H, cruceta arriba o el botón "Curar"): vida que da.
-- "rarity" (Data/Rarities) da color al nombre en el inventario y el diario; sin ella, Común.
-- Iconos: usa emojis anteriores a 2020; los más nuevos (🪵, 🪨…) Roblox los muestra como un cuadro vacío.

export type ItemDefinition = {
	name: string,
	icon: string,
	order: number,
	alwaysShow: boolean?,
	food: FoodDefinition?,
	heal: number?,
	rarity: string?,
}

export type FoodDefinition = {
	hunger: number,
	thirst: number,
}

local Items: { [string]: ItemDefinition } = {
	Wood = { name = "Madera", icon = "🌲", order = 1, alwaysShow = true },
	Stone = { name = "Piedra", icon = "⛰️", order = 2, alwaysShow = true },
	Fiber = { name = "Fibra", icon = "🌿", order = 3, alwaysShow = true },
	Meat = { name = "Carne cruda", icon = "🥩", order = 4, food = { hunger = 8, thirst = 0 } },
	RedFur = { name = "Pelaje rojo", icon = "🐾", order = 5 },
	GoldenFur = { name = "Pelaje dorado", icon = "✨", order = 6, rarity = "Uncommon" },
	SmallFang = { name = "Colmillo", icon = "🔺", order = 7, rarity = "Uncommon" },
	Bandage = { name = "Venda", icon = "➕", order = 8, heal = 30 },
	CookedMeat = { name = "Carne asada", icon = "🍖", order = 9, food = { hunger = 35, thirst = 0 } },
	Banana = { name = "Banano", icon = "🍌", order = 10, food = { hunger = 15, thirst = 5 } },
	Skewer = { name = "Brocheta", icon = "🍢", order = 11, food = { hunger = 60, thirst = 5 } },
	Coconut = { name = "Coco", icon = "🥥", order = 12, food = { hunger = 5, thirst = 25 } },
	-- Fase 2.3: botín de hueso y productos del taller del curandero.
	Bone = { name = "Hueso", icon = "🦴", order = 13 },
	Ointment = { name = "Ungüento", icon = "🧴", order = 14, heal = 70 },
	Antidote = { name = "Antídoto", icon = "💉", order = 15 },
	-- Matas de plátano de los cultivos: crudo alimenta poco, asado en la hoguera mucho más.
	Plantain = { name = "Plátano", icon = "🥒", order = 16, food = { hunger = 6, thirst = 0 } },
	RoastedPlantain = { name = "Plátano asado", icon = "🍠", order = 17, food = { hunger = 28, thirst = 0 } },
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
	-- Fase 5: botín especial de los jefes.
	RiverPearl = { name = "Perla del río", icon = "🔮", order = 40, rarity = "Legendary" },
	ChieftainCrown = { name = "Corona del caudillo", icon = "👑", order = 41, rarity = "Legendary" },
	CaveCrystal = { name = "Cristal de cueva", icon = "💎", order = 42, rarity = "Legendary" },
	MagmaCore = { name = "Núcleo de magma", icon = "🌋", order = 43, rarity = "Legendary" },
	ShipMetal = { name = "Metal de naufragio", icon = "⚙️", order = 44, rarity = "Uncommon" },
}

return Items
