--!strict
-- Recetas de la mesa de trabajo (GDD §9.3, Fase 1.6). Para balancear, cambia los números aquí.
-- Cada receta da UNA de estas cosas:
--   weaponId → una herramienta o arma (ver Data/Weapons). Solo se fabrica una vez y no se pierde.
--   itemId   → un ítem que se acumula en el inventario (ver Data/Items), "amount" unidades.
--   armorId  → una armadura que se lleva puesta (ver Data/Armor). Solo se fabrica una vez.
-- "cost" es una lista para que el orden de los materiales en pantalla no cambie.

export type Cost = { itemId: string, amount: number }

export type Recipe = {
	name: string,
	icon: string, -- emoji anterior a 2020 (los nuevos salen como un cuadro vacío)
	description: string,
	order: number,
	cost: { Cost },
	weaponId: string?,
	itemId: string?,
	amount: number?,
	armorId: string?,
}

local Recipes: { [string]: Recipe } = {
	Torch = {
		name = "Antorcha",
		icon = "🔥",
		description = "Ilumina la selva de noche. Golpea flojo.",
		order = 1,
		cost = { { itemId = "Wood", amount = 2 }, { itemId = "Fiber", amount = 1 } },
		weaponId = "Torch",
	},
	Bandage = {
		name = "Venda",
		icon = "➕",
		description = "Cura 30 de vida. Úsala con H o el botón Curar.",
		order = 2,
		cost = { { itemId = "Fiber", amount = 3 } },
		itemId = "Bandage",
		amount = 1,
	},
	StoneAxe = {
		name = "Hacha de piedra",
		icon = "⚒️",
		description = "Llevándola, cada tala da +1 madera. También sirve de arma.",
		order = 3,
		cost = { { itemId = "Wood", amount = 4 }, { itemId = "Stone", amount = 3 }, { itemId = "Fiber", amount = 2 } },
		weaponId = "StoneAxe",
	},
	StonePick = {
		name = "Pico de piedra",
		icon = "⛏️",
		description = "Llevándolo, cada roca da +1 piedra. También sirve de arma.",
		order = 4,
		cost = { { itemId = "Wood", amount = 4 }, { itemId = "Stone", amount = 4 }, { itemId = "Fiber", amount = 2 } },
		weaponId = "StonePick",
	},
	Spear = {
		name = "Lanza de colmillo",
		icon = "🔱",
		description = "Mucho alcance: golpea antes de que el mono te alcance.",
		order = 5,
		cost = {
			{ itemId = "Wood", amount = 5 },
			{ itemId = "Fiber", amount = 3 },
			{ itemId = "SmallFang", amount = 2 },
		},
		weaponId = "Spear",
	},
	Club = {
		name = "Garrote con colmillos",
		icon = "🏏",
		description = "Lento pero muy fuerte.",
		order = 6,
		cost = {
			{ itemId = "Wood", amount = 6 },
			{ itemId = "SmallFang", amount = 3 },
			{ itemId = "RedFur", amount = 2 },
		},
		weaponId = "Club",
	},
	FurVest = {
		name = "Chaleco de pelaje",
		icon = "🛡️",
		description = "Los monos te hacen un 25 % menos de daño.",
		order = 7,
		cost = {
			{ itemId = "Fiber", amount = 4 },
			{ itemId = "RedFur", amount = 3 },
			{ itemId = "GoldenFur", amount = 3 },
		},
		armorId = "FurVest",
	},
}

return Recipes
