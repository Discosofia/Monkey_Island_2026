--!strict
-- Ítems del juego. Fase 1.2: materiales básicos.
-- "order" decide el orden en el HUD del inventario.
-- Iconos: usa emojis anteriores a 2020; los más nuevos (🪵, 🪨…) Roblox los muestra como un cuadro vacío.

export type ItemDefinition = {
	name: string,
	icon: string,
	order: number,
}

local Items: { [string]: ItemDefinition } = {
	Wood = { name = "Madera", icon = "🌲", order = 1 },
	Stone = { name = "Piedra", icon = "⛰️", order = 2 },
	Fiber = { name = "Fibra", icon = "🌿", order = 3 },
}

return Items
