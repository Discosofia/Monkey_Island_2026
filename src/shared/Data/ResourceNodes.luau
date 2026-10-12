--!strict
-- Tipos de puntos de recolección. El nombre de cada entrada (Tree, Rock, Bush) es el valor
-- que hay que poner en el atributo "ResourceNode" de un modelo del mapa (ver docs/MAPA.md).

export type NodeDefinition = {
	name: string, -- lo que ve el jugador sobre el aviso
	actionText: string, -- verbo del aviso
	itemId: string, -- ítem que da (ver Data/Items)
	amount: number, -- cantidad por recolección
	holdSeconds: number, -- tiempo que hay que mantener pulsado
	uses: number, -- recolecciones antes de agotarse
	respawnSeconds: number, -- tiempo hasta que reaparece tras agotarse
}

local ResourceNodes: { [string]: NodeDefinition } = {
	Tree = {
		name = "Árbol",
		actionText = "Talar",
		itemId = "Wood",
		amount = 3,
		holdSeconds = 1,
		uses = 3,
		respawnSeconds = 120,
	},
	Rock = {
		name = "Roca",
		actionText = "Picar",
		itemId = "Stone",
		amount = 2,
		holdSeconds = 1.5,
		uses = 3,
		respawnSeconds = 150,
	},
	Bush = {
		name = "Arbusto",
		actionText = "Recolectar",
		itemId = "Fiber",
		amount = 2,
		holdSeconds = 0.8,
		uses = 2,
		respawnSeconds = 90,
	},
}

return ResourceNodes
