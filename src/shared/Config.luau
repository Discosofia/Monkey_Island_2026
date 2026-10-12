--!strict
-- Configuración central del juego.
-- Para balancear o ajustar el juego, cambia los números aquí: la lógica los lee de este módulo.

local Config = {
	GameName = "Primal Banana Island",
	Subtitle = "Monkey Survival",

	-- IDs de los places de la experiencia. Cómo obtenerlos: docs/SETUP.md, paso 6.
	PlaceIds = {
		Lobby = 86360888108434, -- place "Primal Banana Island" (lugar de inicio)
		Island = 84163809226177, -- place creado después ("chillyDuo's Place", renombrar a "Isla")
	},

	Match = {
		-- El tamaño real del servidor se configura en Roblox (docs/SETUP.md, paso 7).
		MaxPlayers = 20,
		DayLengthSeconds = 10 * 60,
		NightLengthSeconds = 7 * 60,
		-- Segundos antes de la noche en que se avisa a los jugadores para que vuelvan.
		DuskWarningSeconds = 60,
		-- Un jefe cada BossIntervalDays días, en este orden (GDD §8.2).
		BossIntervalDays = 2,
		BossRotation = { "OrangutanDelManglar", "ChimpanceCaudillo", "GorilaAlbino", "GorilaDeCeniza" },
		-- Primer día en que se puede encender la baliza de rescate (GDD §5.3).
		BeaconUnlockDay = 8,
	},

	Basecamp = {
		-- Pieza de Workspace que marca el área del Basecamp (puede estar dentro de carpetas).
		-- Si no existe, se crea una zona con el tamaño y centro de abajo.
		ZonePartName = "BasecampZone",
		DefaultZoneSize = Vector3.new(120, 60, 120),
		DefaultZoneCenter = Vector3.new(0, 30, 0),
		-- Cada cuánto se comprueba quién está dentro.
		CheckIntervalSeconds = 0.5,
	},

	Resources = {
		-- Distancia máxima (studs) para recolectar de un árbol, roca o arbusto.
		HarvestDistance = 10,
		-- Si el mapa no tiene puntos de recolección, se crean unos de prueba alrededor del Basecamp.
		SpawnTestNodesIfNone = true,
		TestNodeRingRadius = 100,
		-- Tiempos y cantidades de cada tipo: ver Shared/Data/ResourceNodes.
	},

	Combat = {
		-- Solo se puede dañar a lo que tenga esta etiqueta (CollectionService): monos y muñecos.
		EnemyTag = "Enemy",
		-- Armas con las que aparece cada jugador (ver Shared/Data/Weapons).
		StarterWeapons = { "Machete", "Honda" },
		DodgeCooldownSeconds = 1.2,
		DodgeSpeed = 55,
		DodgeDurationSeconds = 0.15,
		-- Tiempo de invulnerabilidad al esquivar.
		DodgeInvulnerableSeconds = 0.35,
		DummyHealth = 100,
		DummyRespawnSeconds = 3,
	},

	Teleport = {
		-- Segundos mínimos entre dos peticiones de viaje del mismo jugador.
		CooldownSeconds = 5,
		MaxAttempts = 3,
		RetryDelaySeconds = 2,
	},
}

return Config
