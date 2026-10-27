--!strict
-- Eventos en vivo que lanza un administrador desde el panel (T4b). Los que duran lo que elige el
-- admin (15, 30 o 60 min, Config.LiveEvents.Durations) no llevan "seconds"; los de un momento sí.
-- Los números de cada uno están en Config.LiveEvents.

export type Kind = "DoubleAmber" | "DoubleXp" | "FastEgg" | "EggLuck" | "Party" | "EggRain" | "Maintenance"

export type Info = {
	icon: string,
	name: string,
	-- Lo que cambia, para el panel y el aviso al empezar.
	detail: string,
	order: number,
	-- Duración fija (s); sin ella dura lo que elige el admin.
	seconds: number?,
	-- Solo pasa algo en ese place (el resto lo ve en la franja, pero no le afecta).
	place: string?,
	-- No sale entre los eventos del panel (lo lanza otra cosa: el mantenimiento, en la pestaña Servidor).
	hidden: boolean?,
}

local LiveEvents: { [string]: Info } = {
	DoubleAmber = {
		icon = "💰",
		name = "Doble Ámbar",
		detail = "Las partidas de la Isla y de Dunas dan el doble de Ámbar",
		order = 1,
	},
	DoubleXp = {
		icon = "⭐",
		name = "Doble XP del pase",
		detail = "Todo lo que da XP del pase da el doble",
		order = 2,
	},
	FastEgg = {
		icon = "⏩",
		name = "Huevo acelerado",
		detail = "El huevo del nido incuba el doble de rápido",
		order = 3,
	},
	EggLuck = {
		icon = "🍀",
		name = "Suerte de huevo",
		detail = "Los huevos que aparecen salen más raros",
		order = 4,
	},
	Party = {
		icon = "🎉",
		name = "Fiesta",
		detail = "Confeti y fuegos artificiales en la plaza del Lobby, y todos celebran a la vez",
		order = 5,
		seconds = 120,
		place = "Lobby",
	},
	EggRain = {
		icon = "🥚",
		name = "Lluvia de huevos",
		detail = "Caen huevos en la plaza del Lobby: cada jugador puede recoger uno",
		order = 6,
		seconds = 90,
		place = "Lobby",
	},
	-- Mantenimiento (T4d, ServerShared/ServerOps): al empezar se guarda todo y se expulsa a los
	-- jugadores; mientras dura ("seconds") no se puede entrar. Lo programa la pestaña 🖥️ Servidor.
	Maintenance = {
		icon = "🛠️",
		name = "Mantenimiento",
		detail = "El juego se cierra para actualizarse: termina lo que estés haciendo y vuelve en unos minutos",
		order = 99,
		seconds = 600,
		hidden = true,
	},
}

return LiveEvents
