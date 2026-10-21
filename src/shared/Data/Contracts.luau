--!strict
-- Contratos de expedición (Fase 9, G6; ContractService, Config.Contracts). Al empezar cada partida
-- toca uno al azar y es de todo el grupo: lo que hace cualquiera cuenta para todos. Sus 5 pasos siguen
-- la partida: preparar el campamento (días 1–2), explorar (3–4), fortificar o cazar (5–6), asegurar
-- (7) y encender la baliza (8). Cada paso se abre en su "day" y se pierde si llega el día del siguiente
-- sin cumplirlo; al cumplirlo, todos los que están en la partida se llevan el premio de su orden
-- (Config.Contracts.StepRewards) y los objetos de "items" para esta partida.
-- "event" es como en Data/Missions (lo avisan los mismos servicios con ServerShared/Retention), más:
--   "Visit": llegar a la guarida de un bioma ("key": Rios, Montanas, Cuevas, Volcan).
--   "Supply": abrir una caja de suministro (SupplyService); con "key" = "Military", una caja militar de
--     la erupción preliminar del día 7 (Data/MidEvents).
--   "Beacon": encender la baliza de rescate (BeaconService).
-- "key": solo cuenta eso (el jefe, el recurso, el bioma); "keys": solo una de esas (piezas
-- defensivas); "distinct": cosas distintas (especies); "scales": el objetivo crece con el grupo.
-- "{target}" en el texto se cambia por el objetivo (ya con el grupo).

export type ContractEvent =
	"Kill"
	| "Gather"
	| "Craft"
	| "Build"
	| "Boss"
	| "Alpha"
	| "Species"
	| "Visit"
	| "Supply"
	| "Beacon"

export type Step = {
	day: number,
	icon: string,
	title: string, -- corto, para el HUD ("Fortificar")
	text: string,
	event: ContractEvent,
	target: number,
	key: string?,
	keys: { string }?,
	distinct: boolean?,
	scales: boolean?,
	items: { [string]: number }?,
}

export type Contract = {
	name: string,
	icon: string,
	description: string,
	steps: { Step },
}

-- Último paso de todos: la baliza (pide las 4 piezas de los jefes y el día 8).
local function beacon(): Step
	return {
		day = 8,
		icon = "📡",
		title = "Rescate",
		text = "Encended la baliza de rescate",
		event = "Beacon",
		target = 1,
		items = { ReviveKit = 1 },
	}
end

-- Piezas que cuentan como defensa del Basecamp (Data/Buildables). Las antorchas de pie, no: son
-- demasiado baratas.
local DEFENSES = { "WoodWall", "StoneWall", "GateBarricade", "Spikes", "WarTotem" }

local Contracts: { [string]: Contract } = {
	Camp = {
		name = "Campamento del náufrago",
		icon = "🏕️",
		description = "Levantad un campamento que aguante hasta el rescate",
		steps = {
			{
				day = 1,
				icon = "🧱",
				title = "Preparar el campamento",
				text = "Construid {target} piezas",
				event = "Build",
				target = 3,
				scales = true,
				items = { Bandage = 2 },
			},
			{
				day = 3,
				icon = "🕯️",
				title = "Explorar",
				text = "Llegad a la cueva del Gorila Albino",
				event = "Visit",
				target = 1,
				key = "Cuevas",
				items = { Torch = 1 },
			},
			{
				day = 5,
				icon = "🛡️",
				title = "Fortificar",
				text = "Levantad {target} muros, estacas, barricadas o el tótem",
				event = "Build",
				target = 4,
				keys = DEFENSES,
				scales = true,
				items = { Ointment = 1 },
			},
			{
				day = 7,
				icon = "📦",
				title = "Asegurar",
				text = "Abrid {target} caja militar de la erupción",
				event = "Supply",
				target = 1,
				key = "Military",
				items = { SuperBandage = 2 },
			},
			beacon(),
		},
	},
	Naturalist = {
		name = "Diario del naturalista",
		icon = "📖",
		description = "Estudiad la fauna de la isla antes de pedir el rescate",
		steps = {
			{
				day = 1,
				icon = "🪓",
				title = "Preparar el campamento",
				text = "Recolectad {target} recursos",
				event = "Gather",
				target = 80,
				scales = true,
				items = { CookedMeat = 3 },
			},
			{
				day = 3,
				icon = "📖",
				title = "Bestiario",
				text = "Derrotad monos de {target} especies distintas",
				event = "Species",
				target = 8,
				distinct = true,
				items = { Antidote = 1 },
			},
			{
				day = 5,
				icon = "🦍",
				title = "Cazar",
				text = "Derrotad {target} mono alfa",
				event = "Alpha",
				target = 1,
				items = { Ointment = 1 },
			},
			{
				day = 7,
				icon = "🐒",
				title = "Despejar",
				text = "Derrotad {target} monos",
				event = "Kill",
				target = 12,
				scales = true,
				items = { SuperBandage = 2 },
			},
			beacon(),
		},
	},
	Volcano = {
		name = "Ruta del volcán",
		icon = "🌋",
		description = "Abrid camino hasta el corazón del volcán",
		steps = {
			{
				day = 1,
				icon = "🛠️",
				title = "Preparar el campamento",
				text = "Fabricad {target} objetos",
				event = "Craft",
				target = 3,
				scales = true,
				items = { Bandage = 2 },
			},
			{
				day = 3,
				icon = "👑",
				title = "Explorar",
				text = "Derrotad al Chimpancé Caudillo",
				event = "Boss",
				target = 1,
				key = "ChimpanceCaudillo",
				items = { Torch = 1 },
			},
			{
				day = 5,
				icon = "🪨",
				title = "Obsidiana",
				text = "Picad {target} de obsidiana",
				event = "Gather",
				target = 6,
				key = "Obsidian",
				scales = true,
				items = { Ointment = 1 },
			},
			{
				day = 7,
				icon = "📦",
				title = "Asegurar",
				text = "Abrid {target} caja militar de la erupción",
				event = "Supply",
				target = 1,
				key = "Military",
				items = { SuperBandage = 2 },
			},
			beacon(),
		},
	},
}

return Contracts
