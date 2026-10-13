--!strict
-- Ítems del juego. Fase 1.2: materiales básicos. Fase 1.4: botín de los monos. Fase 1.6: vendas.
-- Fase 2.1: comida.
-- "order" decide el orden en el HUD del inventario; "alwaysShow" lo muestra aunque tengas 0.
-- "food" hace que se pueda comer (C, cruceta izquierda o el botón "Comer"): cuánto recupera.
-- Iconos: usa emojis anteriores a 2020; los más nuevos (🪵, 🪨…) Roblox los muestra como un cuadro vacío.

export type ItemDefinition = {
	name: string,
	icon: string,
	order: number,
	alwaysShow: boolean?,
	food: FoodDefinition?,
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
	GoldenFur = { name = "Pelaje dorado", icon = "✨", order = 6 },
	SmallFang = { name = "Colmillo", icon = "🔺", order = 7 },
	Bandage = { name = "Venda", icon = "➕", order = 8 },
	CookedMeat = { name = "Carne asada", icon = "🍖", order = 9, food = { hunger = 35, thirst = 0 } },
	Banana = { name = "Plátano", icon = "🍌", order = 10, food = { hunger = 15, thirst = 5 } },
	Skewer = { name = "Brocheta", icon = "🍢", order = 11, food = { hunger = 60, thirst = 5 } },
	Coconut = { name = "Coco", icon = "🥥", order = 12, food = { hunger = 5, thirst = 25 } },
}

return Items
