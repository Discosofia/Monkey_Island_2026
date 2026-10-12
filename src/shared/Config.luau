--!strict
-- Configuración central del juego.
-- Para balancear o ajustar el juego, cambia los números aquí: la lógica los lee de este módulo.

local Config = {
	GameName = "Primal Banana Island",
	Subtitle = "Monkey Survival",

	-- IDs de los places de la experiencia. Cómo obtenerlos: docs/SETUP.md, paso 6.
	PlaceIds = {
		Lobby = 0,
		Island = 0,
	},

	Match = {
		-- El tamaño real del servidor se configura en Roblox (docs/SETUP.md, paso 7).
		MaxPlayers = 20,
		DayLengthSeconds = 10 * 60,
		NightLengthSeconds = 7 * 60,
		-- Un jefe cada BossIntervalDays días, en este orden (GDD §8.2).
		BossIntervalDays = 2,
		BossRotation = { "OrangutanDelManglar", "ChimpanceCaudillo", "GorilaAlbino", "GorilaDeCeniza" },
		-- Primer día en que se puede encender la baliza de rescate (GDD §5.3).
		BeaconUnlockDay = 8,
	},

	Teleport = {
		-- Segundos mínimos entre dos peticiones de viaje del mismo jugador.
		CooldownSeconds = 5,
		MaxAttempts = 3,
		RetryDelaySeconds = 2,
	},
}

return Config
