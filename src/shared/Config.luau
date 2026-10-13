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
		-- Derrota (Fase 2.7): de noche, si todos los jugadores están caídos o son Espíritus durante
		-- estos segundos seguidos. Después se ven los resultados y todos vuelven al Lobby.
		DefeatGraceSeconds = 10,
		ResultsSeconds = 30,
		-- Ámbar (moneda, GDD §13) que gana cada jugador al terminar la partida.
		AmberPerDay = 10,
		AmberPerKill = 2,
		AmberPerRevive = 5,
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
		-- Distancia máxima (studs) para recolectar de un arbusto o helecho (con el aviso E).
		HarvestDistance = 10,
		-- Alcance del hacha y el pico: distancia desde la superficie del árbol o la roca.
		ToolReach = 5.5,
		-- Segundos que se ve la barra de progreso tras el último golpe.
		ProgressBarSeconds = 3,
		-- Si el mapa no tiene puntos de recolección, se crean unos de prueba alrededor del Basecamp.
		SpawnTestNodesIfNone = true,
		TestNodeRingRadius = 100,
		-- Tiempos y cantidades de cada tipo: ver Shared/Data/ResourceNodes.
	},

	Combat = {
		-- Solo se puede dañar a lo que tenga esta etiqueta (CollectionService): monos y muñecos.
		EnemyTag = "Enemy",
		-- Armas con las que aparece cada jugador (ver Shared/Data/Weapons).
		StarterWeapons = { "Machete", "Honda", "WoodenAxe", "WoodenPick" },
		DodgeCooldownSeconds = 1.2,
		DodgeSpeed = 55,
		DodgeDurationSeconds = 0.15,
		-- Tiempo de invulnerabilidad al esquivar.
		DodgeInvulnerableSeconds = 0.35,
		DummyHealth = 100,
		-- Daño que haces mientras te intimida un mandril (Fase 4).
		IntimidatedDamageMultiplier = 0.7,
		DummyRespawnSeconds = 3,
	},

	-- Dificultad por día (Fase 2.7): cada día los monos tienen más vida y pegan más fuerte.
	Difficulty = {
		HealthPerDay = 0.12, -- +12 % de vida por cada día pasado
		DamagePerDay = 0.08, -- +8 % de daño por cada día pasado
		MaxMultiplier = 2.5,
	},

	Monkeys = {
		-- Cada cuánto "piensa" la IA de los monos.
		ThinkIntervalSeconds = 0.25,
		-- Sin jugadores a esta distancia, un mono no piensa (ahorra rendimiento).
		SleepDistance = 300,
		-- Los grupos aparecen en la selva entre estas distancias del centro del Basecamp.
		SpawnMinDistance = 140,
		SpawnMaxDistance = 800,
		-- Aullido: alcance del aviso, espera hasta los refuerzos y cuáles llegan.
		HowlRadius = 100,
		HowlReinforcementSeconds = 6,
		HowlReinforcementSpecies = "MonoArdilla",
		HowlReinforcementCount = 2,
		-- Segundos que tarda en desvanecerse un mono derrotado.
		CorpseSeconds = 1.5,
		-- Fase 4: radio alrededor de la guarida de su bioma donde aparecen las especies de bioma,
		-- límite de monos a la vez en el servidor (rendimiento) y alfas de las tropas.
		BiomeRadius = 220,
		MaxActive = 160,
		AlphaHealthMultiplier = 2.5,
		AlphaDamageMultiplier = 1.5,
		PounceCooldownSeconds = 6,
		RoarCooldownSeconds = 15,
		-- Miedo al fuego: distancia a una antorcha u hoguera a la que las especies miedosas se apartan.
		FireFearRadius = 10,
		-- Los grupos con bajas recuperan un mono cada GroupRegrowSeconds mientras su especie esté
		-- activa, siempre que no haya jugadores a menos de RegrowMinPlayerDistance de su zona.
		GroupRegrowSeconds = 45,
		RegrowMinPlayerDistance = 120,
		-- Especies (vida, daño, botín…): ver Shared/Data/Monkeys.
	},

	Life = {
		-- Segundos caído antes de pasar a Espíritu si nadie te reanima.
		DownedSeconds = 30,
		-- Tiempo como Espíritu antes de reaparecer en el Basecamp. Cada caída del mismo día suma
		-- SpiritExtraSecondsPerDeath, hasta SpiritMaxSeconds. Al amanecer reaparecen todos.
		SpiritSeconds = 45,
		SpiritExtraSecondsPerDeath = 30,
		SpiritMaxSeconds = 180,
		CrawlSpeed = 4,
		ReviveHoldSeconds = 4,
		ReviveDistance = 8,
		-- Vida con la que vuelves al ser reanimado (fracción de la máxima).
		ReviveHealthFraction = 0.35,
		-- Parte de cada material que se queda en la mochila al pasar a Espíritu.
		DropFraction = 0.5,
		-- Marcas de los Espíritus: duración, espera entre marcas y alcance.
		SpiritMarkSeconds = 8,
		SpiritMarkCooldownSeconds = 2,
		SpiritMarkRange = 250,
	},

	Survival = {
		-- Hambre y sed van de 100 (lleno) a 0. Cuánto bajan por minuto mientras estás vivo.
		HungerPerMinute = 5, -- unos 20 min de lleno a vacío
		ThirstPerMinute = 7, -- unos 14 min
		-- Por debajo de esto sale un aviso y la estamina se recupera a la mitad.
		LowThreshold = 25,
		-- A 0 de hambre o de sed pierdes vida (por cada una que esté a 0). Puede dejarte caído.
		StarvationDamagePerSecond = 1,
		-- La vida solo se regenera con hambre y sed por encima de RegenMinStat y sin daño reciente.
		RegenPerSecond = 1,
		RegenMinStat = 50,
		RegenDelayAfterDamage = 6,
		-- Al reaparecer como Espíritu, hambre y sed suben al menos a esto.
		RespawnMinStat = 50,
		-- Beber del río: sed que recupera cada trago y distancia al agua.
		DrinkThirst = 25,
		DrinkReach = 6,
		EatCooldownSeconds = 0.8,
		DrinkCooldownSeconds = 0.8,
		-- Estamina (0 a 100): correr la gasta y esquivar cuesta DodgeStaminaCost.
		WalkSpeed = 16,
		SprintSpeed = 24,
		SprintStaminaPerSecond = 18,
		StaminaRegenPerSecond = 20,
		StaminaRegenDelay = 0.8,
		DodgeStaminaCost = 25,
	},

	Building = {
		-- Cuadrícula (studs): las piezas se colocan en múltiplos de esto y giran de 90 en 90 grados.
		GridSize = 4,
		-- Distancia máxima del jugador al sitio donde construye o derriba.
		Reach = 30,
		-- Núcleo compartido: círculo alrededor del centro del Basecamp donde cualquiera construye.
		CoreRadius = 40,
		-- Parcelas personales: cuántas, a qué distancia del centro y de qué tamaño (cuadradas).
		PlotCount = 20,
		PlotRingRadius = 62,
		PlotSize = 13,
		-- Grados libres a cada lado de los 4 portones, para que las parcelas no tapen los caminos.
		GateGapDegrees = 18,
		-- Perímetro: hasta dónde se pueden poner defensas (la empalizada de MapBuilder está a 81).
		PerimeterRadius = 92,
		-- Piezas como máximo por jugador, y parte del coste que se devuelve al derribar.
		MaxStructuresPerPlayer = 60,
		RefundFraction = 0.5,
		-- Margen al comprobar si algo estorba: permite juntar muros en las esquinas.
		OverlapShrink = 0.6,
		BuildCooldownSeconds = 0.25,
		-- Piezas: ver Shared/Data/Buildables.
	},

	Fever = {
		-- Fiebre del mono (GDD §6.1, Fase 2.6), de 0 a 100. La suben los mordiscos y la carne cruda.
		PerBite = 6,
		RawMeat = 12,
		-- Baja sola muy despacio; el antídoto (taller del curandero) la quita de golpe.
		DecayPerMinute = 2,
		-- Desde aquí se nubla la vista; a 100 además quita vida.
		SymptomsAt = 50,
		DamagePerSecondAtMax = 0.5,
	},

	Siege = {
		-- Asedio nocturno (GDD §10, Fase 2.5): oleadas de monos hacia el Basecamp cada noche.
		FirstWaveDelaySeconds = 30,
		WaveIntervalSeconds = 110,
		WavesPerNight = 3,
		-- Monos por oleada: base + por cada día pasado + por cada jugador, con un máximo.
		BaseWaveSize = 4,
		ExtraPerDay = 2,
		ExtraPerPlayer = 1,
		MaxWaveSize = 30,
		-- Especies de las oleadas por día de partida (ver Shared/Data/Monkeys): cada grupo elige al azar
		-- entre las ya desbloqueadas.
		SpeciesByDay = {
			{ day = 1, species = "AulladorRojo" },
			{ day = 3, species = "Macaco" },
			{ day = 5, species = "Babuino" },
			{ day = 7, species = "Gorila" },
		},
		-- Hasta dónde busca estacas un macaco del asedio.
		TrapSearchRadius = 30,
		-- Distancia más allá del perímetro a la que aparecen, frente a los portones.
		SpawnDistance = 45,
		-- A qué distancia busca jugadores un mono del asedio y a qué distancia ataca una pieza.
		PlayerAggroRange = 30,
		StructureReach = 7,
		-- Daño a las piezas: multiplicador sobre el daño de la especie.
		StructureDamageMultiplier = 3,
		-- Estacas: daño por segundo a los monos encima y desgaste de la trampa por golpe.
		SpikeDamagePerSecond = 16,
		SpikeWearPerHit = 6,
	},

	Crafting = {
		-- Atributo que marca una estación colocada a mano en el mapa ("CraftingStation" = "Workbench",
		-- "Campfire"…; ver Data/Stations). Si falta la mesa, se crea una en el Basecamp, desplazada así
		-- respecto a su centro. Si falta la hoguera, se usa el modelo "Hoguera" del mapa o se crea una.
		StationAttribute = "CraftingStation",
		DefaultWorkbenchOffset = Vector3.new(-35, 0, 0),
		DefaultCampfireOffset = Vector3.new(0, 0, 0),
		-- Distancia máxima (studs) a una estación para abrirla y fabricar.
		UseDistance = 10,
		CraftCooldownSeconds = 0.4,
		-- Espera entre dos curaciones (vendas, ungüentos, antídotos). Lo que cura cada una: Data/Items.
		BandageCooldownSeconds = 3,
		-- Recetas: ver Shared/Data/Recipes.
	},

	Data = {
		-- Guardado de datos (Fase 2.8). Cambiar StoreName empieza de cero (útil para pruebas).
		StoreName = "PlayerData_v1",
		AutosaveSeconds = 120,
		-- Si otro servidor tiene los datos (p. ej. viajando entre places), reintentos y espera.
		LoadAttempts = 6,
		RetrySeconds = 2,
		-- Un bloqueo más viejo que esto es de un servidor caído: se ignora.
		LockTimeoutSeconds = 600,
		-- XP de rol al terminar una partida: por día sobrevivido y por mono derrotado.
		RoleXpPerDay = 20,
		RoleXpPerKill = 2,
	},

	Abilities = {
		-- Habilidades de los roles (Fase 3; tiempos de espera en Shared/Data/Roles).
		AreaHealAmount = 30,
		AreaHealRadius = 18,
		MarkRadius = 70,
		FrenzySeconds = 20,
	},

	Party = {
		-- Grupos del Lobby (Fase 3): tamaño máximo y segundos que vale una invitación.
		MaxSize = 6,
		InviteSeconds = 60,
	},

	Teleport = {
		-- Segundos mínimos entre dos peticiones de viaje del mismo jugador.
		CooldownSeconds = 5,
		MaxAttempts = 3,
		RetryDelaySeconds = 2,
	},
}

return Config
