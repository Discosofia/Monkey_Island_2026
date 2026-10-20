--!strict
-- Misiones diarias (bucle de retención, octubre de 2026; ServerShared/Retention). Cada día tocan
-- Config.Daily.GeneralMissions generales (sin "role") y una del rol elegido (cambia si cambias de rol).
-- "event" es lo que las hace avanzar (lo cuentan los servicios de la Isla); "{target}" en el texto se
-- cambia por el objetivo. El tiempo de huevo del premio cuenta para el tope de lo ganado jugando.
-- Solo cosas que se pueden hacer jugando solo y en un día: nada de reanimar ni curar a aliados.

local Config = require(script.Parent.Parent.Config)

export type Mission = {
	icon: string,
	text: string,
	event: "Kill" | "Night" | "Gather" | "Egg" | "Craft" | "Build" | "Combo" | "Ability" | "Damage",
	target: number,
	role: string?,
	reward: Config.Reward,
}

local GENERAL_REWARD: Config.Reward = { amber = 60, eggSeconds = 20 * 60 }
local ROLE_REWARD: Config.Reward = { amber = 100, eggSeconds = 30 * 60 }

local Missions: { [string]: Mission } = {
	Kills = { icon = "🐒", text = "Derrota {target} monos", event = "Kill", target = 15, reward = GENERAL_REWARD },
	Night = {
		icon = "🌙",
		text = "Supera {target} noche en la " .. Config.PlaceNames.IslandShort,
		event = "Night",
		target = 1,
		reward = GENERAL_REWARD,
	},
	Gather = {
		icon = "🪓",
		text = "Recolecta {target} recursos",
		event = "Gather",
		target = 40,
		reward = GENERAL_REWARD,
	},
	Egg = { icon = "🥚", text = "Ayuda a salvar {target} huevo", event = "Egg", target = 1, reward = GENERAL_REWARD },
	Craft = {
		icon = "🛠️",
		text = "Fabrica {target} objetos",
		event = "Craft",
		target = 3,
		reward = GENERAL_REWARD,
	},
	Build = { icon = "🧱", text = "Construye {target} piezas", event = "Build", target = 3, reward = GENERAL_REWARD },

	WarriorCombos = {
		icon = "⚔️",
		text = "Cierra {target} combos de guerrero",
		event = "Combo",
		target = 4,
		role = "Guerrero",
		reward = ROLE_REWARD,
	},
	WarriorDamage = {
		icon = "💥",
		text = "Haz {target} de daño como guerrero",
		event = "Damage",
		target = 1500,
		role = "Guerrero",
		reward = ROLE_REWARD,
	},
	HunterAbilities = {
		icon = "🏹",
		text = "Usa {target} habilidades de cazador",
		event = "Ability",
		target = 15,
		role = "Cazador",
		reward = ROLE_REWARD,
	},
	HunterDamage = {
		icon = "🎯",
		text = "Haz {target} de daño como cazador",
		event = "Damage",
		target = 1200,
		role = "Cazador",
		reward = ROLE_REWARD,
	},
	MageDamage = {
		icon = "🔮",
		text = "Haz {target} de daño como mago",
		event = "Damage",
		target = 1200,
		role = "Mago",
		reward = ROLE_REWARD,
	},
	MageCombos = {
		icon = "✨",
		text = "Cierra {target} combos de mago",
		event = "Combo",
		target = 4,
		role = "Mago",
		reward = ROLE_REWARD,
	},
	MedicAbilities = {
		icon = "⛑️",
		text = "Usa {target} habilidades de médico",
		event = "Ability",
		target = 15,
		role = "Medico",
		reward = ROLE_REWARD,
	},
	MedicCombos = {
		icon = "💚",
		text = "Cierra {target} combos de médico",
		event = "Combo",
		target = 3,
		role = "Medico",
		reward = ROLE_REWARD,
	},
}

return Missions
