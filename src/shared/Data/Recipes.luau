--!strict
-- Recetas de las estaciones de crafteo (GDD §9.3; Fases 1.6 y 2.1). Para balancear, cambia los números.
-- "station" es dónde se fabrica (ver Data/Stations): la mesa de trabajo o la hoguera.
-- Cada receta da UNA de estas cosas:
--   weaponId → una herramienta o arma (ver Data/Weapons). Solo se fabrica una vez y no se pierde.
--   itemId   → un ítem que se acumula en el inventario (ver Data/Items), "amount" unidades.
--   armorId  → una armadura que se lleva puesta (ver Data/Armor). Solo se fabrica una vez.
-- "upgrades" (opcional) es el arma que la receta sustituye: al fabricarla, la vieja desaparece.
-- "cost" es una lista para que el orden de los materiales en pantalla no cambie.

export type Cost = { itemId: string, amount: number }

export type Recipe = {
	station: string,
	name: string,
	icon: string, -- emoji anterior a 2020 (los nuevos salen como un cuadro vacío)
	description: string,
	order: number,
	cost: { Cost },
	weaponId: string?,
	itemId: string?,
	amount: number?,
	armorId: string?,
	upgrades: string?,
}

local Recipes: { [string]: Recipe } = {
	Torch = {
		station = "Workbench",
		name = "Antorcha",
		icon = "🔥",
		description = "Ilumina la selva de noche. Golpea flojo.",
		order = 1,
		cost = { { itemId = "Wood", amount = 2 }, { itemId = "Fiber", amount = 1 } },
		weaponId = "Torch",
	},
	Bandage = {
		station = "Workbench",
		name = "Venda",
		icon = "➕",
		description = "Cura 30 de vida. Úsala con H o el botón Curar.",
		order = 2,
		cost = { { itemId = "Fiber", amount = 3 } },
		itemId = "Bandage",
		amount = 1,
	},
	StoneAxe = {
		station = "Workbench",
		name = "Hacha de piedra",
		icon = "⚒️",
		description = "Mejora el hacha de madera: tala el doble de rápido y da +2 madera por árbol.",
		order = 3,
		cost = { { itemId = "Wood", amount = 4 }, { itemId = "Stone", amount = 3 }, { itemId = "Fiber", amount = 2 } },
		weaponId = "StoneAxe",
		upgrades = "WoodenAxe",
	},
	StonePick = {
		station = "Workbench",
		name = "Pico de piedra",
		icon = "⛏️",
		description = "Mejora el pico de madera: pica casi el doble de rápido y da +1 piedra.",
		order = 4,
		cost = { { itemId = "Wood", amount = 4 }, { itemId = "Stone", amount = 4 }, { itemId = "Fiber", amount = 2 } },
		weaponId = "StonePick",
		upgrades = "WoodenPick",
	},
	Spear = {
		station = "Forge",
		name = "Lanza de colmillo",
		icon = "🔱",
		description = "Mucho alcance: golpea antes de que el mono te alcance.",
		order = 41,
		cost = {
			{ itemId = "Wood", amount = 5 },
			{ itemId = "Fiber", amount = 3 },
			{ itemId = "SmallFang", amount = 2 },
		},
		weaponId = "Spear",
	},
	Club = {
		station = "Forge",
		name = "Garrote con colmillos",
		icon = "🏏",
		description = "Lento pero muy fuerte.",
		order = 42,
		cost = {
			{ itemId = "Wood", amount = 6 },
			{ itemId = "SmallFang", amount = 3 },
			{ itemId = "RedFur", amount = 2 },
		},
		weaponId = "Club",
	},
	FurVest = {
		station = "Workbench",
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
	-- Hoguera (Fase 2.1).
	CookedMeat = {
		station = "Campfire",
		name = "Carne asada",
		icon = "🍖",
		description = "Mucho mejor que cruda: quita bastante hambre.",
		order = 20,
		cost = { { itemId = "Meat", amount = 1 } },
		itemId = "CookedMeat",
		amount = 1,
	},
	Skewer = {
		station = "Campfire",
		name = "Brocheta",
		icon = "🍢",
		description = "Carne y banano: casi llena el hambre.",
		order = 21,
		cost = { { itemId = "Meat", amount = 1 }, { itemId = "Banana", amount = 2 } },
		itemId = "Skewer",
		amount = 1,
	},
	RoastedPlantain = {
		station = "Campfire",
		name = "Plátano asado",
		icon = "🍠",
		description = "Dos plátanos de los cultivos, asados: quitan bastante hambre.",
		order = 22,
		cost = { { itemId = "Plantain", amount = 2 } },
		itemId = "RoastedPlantain",
		amount = 2,
	},
	-- Taller del curandero (Fase 2.3).
	Ointment = {
		station = "Healer",
		name = "Ungüento",
		icon = "🧴",
		description = "Cura 70 de vida. Se usa con Curar (H).",
		order = 30,
		cost = {
			{ itemId = "Fiber", amount = 2 },
			{ itemId = "GoldenFur", amount = 1 },
			{ itemId = "Banana", amount = 1 },
		},
		itemId = "Ointment",
		amount = 1,
	},
	HealerBandages = {
		station = "Healer",
		name = "Vendas (×3)",
		icon = "➕",
		description = "Tres vendas por menos fibra que en la mesa.",
		order = 31,
		cost = { { itemId = "Fiber", amount = 6 } },
		itemId = "Bandage",
		amount = 3,
	},
	Antidote = {
		station = "Healer",
		name = "Antídoto",
		icon = "💉",
		description = "Cura la fiebre del mono. Se usa con Curar (H) cuando tienes fiebre.",
		order = 32,
		cost = {
			{ itemId = "Fiber", amount = 2 },
			{ itemId = "RedFur", amount = 1 },
			{ itemId = "Coconut", amount = 1 },
		},
		itemId = "Antidote",
		amount = 1,
	},
	-- Forja de piedra (Fase 2.3): equipo de hueso y colmillo.
	SharpMachete = {
		station = "Forge",
		name = "Machete afilado",
		icon = "🗡️",
		description = "Mejora el machete: 28 de daño y algo más rápido.",
		order = 40,
		cost = {
			{ itemId = "Stone", amount = 6 },
			{ itemId = "Bone", amount = 2 },
			{ itemId = "Wood", amount = 2 },
		},
		weaponId = "SharpMachete",
		upgrades = "Machete",
	},
	BoneArmor = {
		station = "Forge",
		name = "Armadura de hueso",
		icon = "🦴",
		description = "Los monos te hacen un 40 % menos de daño. Sustituye al chaleco.",
		order = 43,
		cost = {
			{ itemId = "Bone", amount = 6 },
			{ itemId = "RedFur", amount = 4 },
			{ itemId = "Fiber", amount = 4 },
		},
		armorId = "BoneArmor",
	},
	-- Forja de piedra, nivel 3 (Fase 4): botín de las especies de categoría 2 y 3.
	LianaSling = {
		station = "Forge",
		name = "Honda de liana",
		icon = "🌱",
		description = "Mejora la honda: 20 de daño y más alcance.",
		order = 50,
		cost = {
			{ itemId = "Liana", amount = 3 },
			{ itemId = "Leather", amount = 2 },
			{ itemId = "Wood", amount = 4 },
		},
		weaponId = "LianaSling",
		upgrades = "Honda",
	},
	BoneAxe = {
		station = "Forge",
		name = "Hacha de hueso",
		icon = "🦴",
		description = "Mejora el hacha de piedra: tala aún más rápido y da +3 madera.",
		order = 51,
		cost = {
			{ itemId = "ThickBone", amount = 2 },
			{ itemId = "Leather", amount = 1 },
			{ itemId = "Wood", amount = 4 },
		},
		weaponId = "BoneAxe",
		upgrades = "StoneAxe",
	},
	BonePick = {
		station = "Forge",
		name = "Pico de hueso",
		icon = "⛏️",
		description = "Mejora el pico de piedra: pica más rápido y da +2 piedra.",
		order = 52,
		cost = {
			{ itemId = "ThickBone", amount = 2 },
			{ itemId = "Leather", amount = 1 },
			{ itemId = "Stone", amount = 6 },
		},
		weaponId = "BonePick",
		upgrades = "StonePick",
	},
	BigFangClub = {
		station = "Forge",
		name = "Garrote de colmillo grande",
		icon = "🔶",
		description = "Mejora el garrote: 46 de daño.",
		order = 53,
		cost = {
			{ itemId = "BigFang", amount = 2 },
			{ itemId = "MandrillFang", amount = 1 },
			{ itemId = "Wood", amount = 6 },
		},
		weaponId = "BigFangClub",
		upgrades = "Club",
	},
	SilverArmor = {
		station = "Forge",
		name = "Armadura de plata",
		icon = "⚪",
		description = "Los monos te hacen un 55 % menos de daño. Sustituye a la anterior.",
		order = 54,
		cost = {
			{ itemId = "SilverFur", amount = 2 },
			{ itemId = "Leather", amount = 4 },
			{ itemId = "ThickBone", amount = 2 },
		},
		armorId = "SilverArmor",
	},
}

return Recipes
