--!strict
-- Misiones (bucle de retención, octubre de 2026; misiones v2 de la Fase 9; ServerShared/Retention).
-- Cada día toca una de cada dificultad de Config.Daily.Difficulties: una "Facil" y una "Dificil" de las
-- generales (sin "role") y una "Media" del rol elegido (cambia si cambias de rol). Cada semana tocan
-- Config.Daily.WeeklyMissions de las "weekly", sin dos de la misma "family" (así hay como mucho una de
-- Dunas). El premio sale de Config.Daily.MissionRewards por su clase.
-- "event" es lo que las hace avanzar (lo cuentan los servicios de la Isla y de Dunas); "{target}" en el
-- texto se cambia por el objetivo. Con "best", cuenta lo más alto de una vez (el día al que llegas en
-- una partida), no la suma; con "distinct", cuántas cosas distintas (especies de mono).
-- Solo cosas que se pueden hacer jugando solo: nada de reanimar ni curar a aliados. Las fáciles caben
-- en un rato (≤ 15 min), las medias piden una partida y las difíciles avanzar en ella (días 3–5); la
-- calculadora (tools/Economia) lo comprueba con sus ritmos.

local Config = require(script.Parent.Parent.Config)

export type Difficulty = "Facil" | "Media" | "Dificil"
export type MissionEvent =
	"Kill"
	| "Night"
	| "Gather"
	| "Egg"
	| "Craft"
	| "Build"
	| "Combo"
	| "Ability"
	| "Damage"
	| "ReachDay"
	| "Boss"
	| "Alpha"
	| "Species"
	| "Rescue"
	| "ArenaWin"
	| "ArenaCapture"

export type Mission = {
	icon: string,
	text: string,
	event: MissionEvent,
	target: number,
	difficulty: Difficulty?, -- las diarias
	weekly: boolean?,
	role: string?,
	family: string?, -- semanales: no salen dos de la misma
	best: boolean?,
	distinct: boolean?,
	reward: Config.Reward,
}

local REWARDS = Config.Daily.MissionRewards

local function daily(difficulty: Difficulty, mission: { [string]: any }): Mission
	mission.difficulty = difficulty
	mission.reward = REWARDS[difficulty]
	return mission :: any
end

local function role(roleId: string, mission: { [string]: any }): Mission
	mission.role = roleId
	return daily("Media", mission)
end

local function weekly(mission: { [string]: any }): Mission
	mission.weekly = true
	mission.reward = REWARDS.Semanal
	return mission :: any
end

local Missions: { [string]: Mission } = {
	-- Diarias fáciles.
	Kills = daily("Facil", { icon = "🐒", text = "Derrota {target} monos", event = "Kill", target = 10 }),
	Gather = daily("Facil", { icon = "🪓", text = "Recolecta {target} recursos", event = "Gather", target = 40 }),
	Craft = daily("Facil", { icon = "🛠️", text = "Fabrica {target} objetos", event = "Craft", target = 2 }),
	Build = daily("Facil", { icon = "🧱", text = "Construye {target} estructura", event = "Build", target = 1 }),

	-- Diarias medias: la del rol.
	WarriorCombos = role(
		"Guerrero",
		{ icon = "⚔️", text = "Cierra {target} combos de guerrero", event = "Combo", target = 7 }
	),
	WarriorDamage = role(
		"Guerrero",
		{ icon = "💥", text = "Haz {target} de daño como guerrero", event = "Damage", target = 6000 }
	),
	HunterAbilities = role(
		"Cazador",
		{ icon = "🏹", text = "Usa {target} habilidades de cazador", event = "Ability", target = 50 }
	),
	HunterDamage = role(
		"Cazador",
		{ icon = "🎯", text = "Haz {target} de daño como cazador", event = "Damage", target = 5000 }
	),
	MageDamage = role(
		"Mago",
		{ icon = "🔮", text = "Haz {target} de daño como mago", event = "Damage", target = 5000 }
	),
	MageCombos = role("Mago", { icon = "✨", text = "Cierra {target} combos de mago", event = "Combo", target = 7 }),
	MedicAbilities = role(
		"Medico",
		{ icon = "⛑️", text = "Usa {target} habilidades de médico", event = "Ability", target = 50 }
	),
	MedicCombos = role(
		"Medico",
		{ icon = "💚", text = "Cierra {target} combos de médico", event = "Combo", target = 6 }
	),

	-- Diarias difíciles: avanzar en la partida.
	ReachDay = daily("Dificil", {
		icon = "☀️",
		text = "Llega al día {target} en una partida",
		event = "ReachDay",
		target = 4,
		best = true,
	}),
	Bosses = daily("Dificil", { icon = "👑", text = "Ayuda a derrotar {target} jefes", event = "Boss", target = 2 }),
	Alphas = daily("Dificil", { icon = "🦍", text = "Derrota {target} monos alfa", event = "Alpha", target = 8 }),
	Night = daily(
		"Dificil",
		{ icon = "🌙", text = "Supera {target} noches en la Isla de monos", event = "Night", target = 3 }
	),
	Egg = daily("Dificil", { icon = "🥚", text = "Ayuda a salvar {target} huevos", event = "Egg", target = 2 }),

	-- Semanales.
	WeeklyBosses = weekly({ icon = "👑", text = "Ayuda a derrotar {target} jefes", event = "Boss", target = 6 }),
	WeeklyNights = weekly({
		icon = "🌙",
		text = "Supera {target} noches en la Isla de monos",
		event = "Night",
		target = 10,
	}),
	WeeklyAlphas = weekly({ icon = "🦍", text = "Derrota {target} monos alfa", event = "Alpha", target = 20 }),
	WeeklySpecies = weekly({
		icon = "📖",
		text = "Derrota monos de {target} especies distintas",
		event = "Species",
		target = 8,
		distinct = true,
	}),
	WeeklyEggs = weekly({ icon = "🥚", text = "Ayuda a salvar {target} huevos", event = "Egg", target = 4 }),
	WeeklyKills = weekly({ icon = "🐒", text = "Derrota {target} monos", event = "Kill", target = 150 }),
	WeeklyGather = weekly({ icon = "🪓", text = "Recolecta {target} recursos", event = "Gather", target = 600 }),
	WeeklyCraft = weekly({ icon = "🛠️", text = "Fabrica {target} objetos", event = "Craft", target = 20 }),
	WeeklyBuild = weekly({ icon = "🧱", text = "Construye {target} estructuras", event = "Build", target = 15 }),
	WeeklyRescue = weekly({
		icon = "🚁",
		text = "Gana {target} partida con el rescate",
		event = "Rescue",
		target = 1,
		family = "Far",
	}),
	WeeklyFarDay = weekly({
		icon = "☀️",
		text = "Llega al día {target} en una partida",
		event = "ReachDay",
		target = 6,
		best = true,
		family = "Far",
	}),
	WeeklyArenaWins = weekly({
		icon = "🏜️",
		text = "Gana {target} partidas en la Isla de dunas",
		event = "ArenaWin",
		target = 3,
		family = "Dunas",
	}),
	WeeklyArenaCaptures = weekly({
		icon = "🚩",
		text = "Captura {target} banderas en la Isla de dunas",
		event = "ArenaCapture",
		target = 5,
		family = "Dunas",
	}),
}

return Missions
