--!strict
-- Ítems del juego. Fase 1.2: materiales básicos. Fase 1.4: botín de los monos. Fase 1.6: vendas.
-- "order" decide el orden en el HUD del inventario; "alwaysShow" lo muestra aunque tengas 0.
-- Iconos: usa emojis anteriores a 2020; los más nuevos (🪵, 🪨…) Roblox los muestra como un cuadro vacío.

export type ItemDefinition = {
	name: string,
	icon: string,
	order: number,
	alwaysShow: boolean?,
}

local Items: { [string]: ItemDefinition } = {
	Wood = { name = "Madera", icon = "🌲", order = 1, alwaysShow = true },
	Stone = { name = "Piedra", icon = "⛰️", order = 2, alwaysShow = true },
	Fiber = { name = "Fibra", icon = "🌿", order = 3, alwaysShow = true },
	Meat = { name = "Carne", icon = "🍖", order = 4 },
	RedFur = { name = "Pelaje rojo", icon = "🐾", order = 5 },
	GoldenFur = { name = "Pelaje dorado", icon = "✨", order = 6 },
	SmallFang = { name = "Colmillo", icon = "🔺", order = 7 },
	Bandage = { name = "Venda", icon = "➕", order = 8 },
}

return Items
