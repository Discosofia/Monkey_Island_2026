--!strict
-- Jefes «de plató» de las escenas (Fase 25, A5): para cada escena con un jefe quieto, qué jefe sale, en qué carpeta de
-- Workspace, dónde y si empieza enterrado hasta el evento stageShow. Lo monta StageBoss.mount (Combat/Monkeys) y lo
-- sube o baja IslandBossHooks (stageShow / stageHide). Al arrancar, IslandBossHooks avisa si la tabla y las escenas no
-- cuadran. Solo se registran escenas que existen en Data/Cinematics.

export type Entry = {
	boss: string,
	folder: string, -- carpeta de Workspace que lo contiene (quien lo monta la destruye al acabar)
	place: "map" | "basecamp", -- "map": su sitio de Data/BossStages; "basecamp": el suelo bajo el centro del Basecamp + offset
	offset: Vector3?, -- solo "basecamp": desplazamiento desde el centro, en el marco del mundo
	facing: Vector3?, -- solo "basecamp": hacia dónde mira
	hidden: boolean, -- empieza enterrado (HIDE_DEPTH) y la escena lo sube con stageShow
}

local StageBosses = {}

-- Studs bajo tierra a los que se esconde el jefe (stageHide y los que empiezan enterrados).
StageBosses.HIDE_DEPTH = 400

local entries: { [string]: Entry } = {
	Endless = {
		boss = "ChimpanceCaudillo",
		folder = "ParcelaJefe",
		place = "basecamp",
		offset = Vector3.new(0, 0, 100),
		facing = Vector3.new(0, 0, -1),
		hidden = true,
	},
}

local BOSSES = { "OrangutanDelManglar", "ChimpanceCaudillo", "GorilaDeCeniza", "GorilaAlbino" }
-- Batallas con versión cómic y reel (no todas los tienen).
local BATTLE_VARIANTS: { [string]: { string } } = {
	OrangutanDelManglar = { "", "_Comic", "_Reel" },
	ChimpanceCaudillo = { "", "_Comic", "_Reel" },
	GorilaDeCeniza = { "" },
	GorilaAlbino = { "" },
}

for _, bossId in BOSSES do
	for _, suffix in { "", "_Comic" } do
		entries[`Boss_{bossId}{suffix}`] = { boss = bossId, folder = "Plato", place = "map", hidden = false }
	end
	for _, suffix in BATTLE_VARIANTS[bossId] do
		entries[`Battle_Boss_{bossId}{suffix}`] =
			{ boss = bossId, folder = "BatallaJefe", place = "map", hidden = false }
	end
end

-- La entrada de una escena, o nil si no monta jefe de plató.
function StageBosses.get(sceneId: string): Entry?
	return entries[sceneId]
end

-- El id del jefe de una escena, o nil.
function StageBosses.bossFor(sceneId: string): string?
	local entry = entries[sceneId]
	return if entry then entry.boss else nil
end

-- Todas las entradas (para la validación al arrancar).
function StageBosses.all(): { [string]: Entry }
	return entries
end

return StageBosses
