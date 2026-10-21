--!strict
-- Tipos de puntos de recolección. El nombre de cada entrada (Tree, Rock, Bush, Fern…) es el valor
-- que hay que poner en el atributo "ResourceNode" de un modelo del mapa (ver docs/MAPA.md).
-- Dos formas de recolectar:
--   - Con herramienta ("tool"): árboles y rocas. Se golpean con el hacha o el pico equipados;
--     cada golpe suma la potencia de la herramienta y al llegar a "toughness" da el material.
--   - Con aviso ("holdSeconds"): arbustos, helechos y matas de banano y plátano. Se mantiene
--     pulsado E (o se toca en móvil). Los que llevan "sickle" (helechos y arbustos) también se
--     cortan de un tajo con la hoz equipada, sin mantener E.

export type NodeDefinition = {
	name: string, -- lo que ve el jugador sobre el aviso
	actionText: string, -- verbo del aviso
	itemId: string, -- ítem que da (ver Data/Items)
	amount: number, -- cantidad por recolección
	tool: string?, -- tipo de herramienta necesaria ("Axe", "Pick"); ver Data/Weapons
	toughness: number?, -- potencia de golpes necesaria por recolección (con herramienta)
	holdSeconds: number?, -- tiempo que hay que mantener pulsado (sin herramienta)
	sickle: boolean?, -- la hoz lo corta de un tajo (además del aviso con E)
	uses: number, -- recolecciones antes de agotarse
	respawnSeconds: number, -- tiempo hasta que reaparece tras agotarse
	falls: boolean?, -- al agotarse cae hacia el lado contrario al jugador (árboles)
	extra: ExtraDrop?, -- ítem adicional con cierta probabilidad en cada recolección
}

export type ExtraDrop = {
	itemId: string,
	chance: number, -- 0 a 1
	amount: number,
}

local ResourceNodes: { [string]: NodeDefinition } = {
	Tree = {
		name = "Árbol",
		actionText = "Talar",
		itemId = "Wood",
		-- Un árbol se tala de una vez: todos los golpes llenan una barra y cae.
		amount = 6,
		tool = "Axe",
		toughness = 8,
		uses = 1,
		respawnSeconds = 120,
		falls = true,
	},
	-- Palmeras de la playa: algo menos de madera, pero siempre dan cocos (quitan sed).
	Palm = {
		name = "Palmera",
		actionText = "Talar",
		itemId = "Wood",
		amount = 4,
		tool = "Axe",
		toughness = 6,
		uses = 1,
		respawnSeconds = 150,
		falls = true,
		extra = { itemId = "Coconut", chance = 1, amount = 2 },
	},
	Rock = {
		name = "Roca",
		actionText = "Picar",
		itemId = "Stone",
		amount = 2,
		tool = "Pick",
		toughness = 5,
		uses = 3,
		respawnSeconds = 150,
	},
	-- Fase 9 (G5): vetas de obsidiana en las laderas del volcán y en la sala de la cueva
	-- (ResourceService las pone al arrancar si el mapa no las tiene). Duras: 4 golpes con el pico de
	-- hueso (que da +2 en cada una: 9 por veta), 12 con el de madera.
	Obsidian = {
		name = "Obsidiana",
		actionText = "Picar",
		itemId = "Obsidian",
		amount = 1,
		tool = "Pick",
		toughness = 12,
		uses = 3,
		respawnSeconds = 240,
	},
	-- Helechos de la selva: menos fibra que un arbusto, pero hay muchos.
	Fern = {
		name = "Helecho",
		actionText = "Recolectar",
		itemId = "Fiber",
		amount = 1,
		holdSeconds = 1.8,
		sickle = true,
		uses = 1,
		respawnSeconds = 90,
	},
	Bush = {
		name = "Arbusto",
		actionText = "Recolectar",
		itemId = "Fiber",
		amount = 2,
		holdSeconds = 1.8,
		sickle = true,
		uses = 2,
		respawnSeconds = 90,
		extra = { itemId = "Banana", chance = 0.35, amount = 1 },
	},
	-- Matas de los cultivos abandonados (GDD §13). Al cosechar se llevan el racimo: la mata se queda
	-- en pie y vuelve a dar pasado un tiempo. Las hojas dan algo de fibra.
	BananaPlant = {
		name = "Mata de banano",
		actionText = "Cosechar",
		itemId = "Banana",
		amount = 3,
		holdSeconds = 2,
		uses = 1,
		respawnSeconds = 180,
		extra = { itemId = "Fiber", chance = 0.5, amount = 1 },
	},
	-- El plátano crudo alimenta poco: rinde de verdad asado en la hoguera (Data/Recipes).
	PlantainPlant = {
		name = "Mata de plátano",
		actionText = "Cosechar",
		itemId = "Plantain",
		amount = 3,
		holdSeconds = 2,
		uses = 1,
		respawnSeconds = 180,
		extra = { itemId = "Fiber", chance = 0.5, amount = 1 },
	},
}

return ResourceNodes
