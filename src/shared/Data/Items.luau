--!strict
-- Ítems del juego. Fase 1.2: materiales básicos.
-- "order" decide el orden en el HUD del inventario.

export type ItemDefinition = {
	name: string,
	icon: string,
	order: number,
}

local Items: { [string]: ItemDefinition } = {
	Wood = { name = "Madera", icon = "🪵", order = 1 },
	Stone = { name = "Piedra", icon = "🪨", order = 2 },
	Fiber = { name = "Fibra", icon = "🌿", order = 3 },
}

return Items
