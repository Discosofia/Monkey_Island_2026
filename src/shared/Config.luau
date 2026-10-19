--!strict
-- Configuración central del juego.
-- Para balancear o ajustar el juego, cambia los números aquí: la lógica los lee de este módulo.

local Config = {
	GameName = "Primal Banana Islands",
	Subtitle = "Monkey Survival",

	-- IDs de los places de la experiencia. Cómo obtenerlos: docs/SETUP.md, paso 6.
	PlaceIds = {
		Lobby = 86360888108434, -- place "Primal Banana Islands" (lugar de inicio)
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
		-- Derrota (Fase 2.7): de noche, si todos los jugadores están caídos a la vez durante
		-- estos segundos seguidos. Después se ven los resultados y todos vuelven al Lobby.
		DefeatGraceSeconds = 10,
		ResultsSeconds = 30,
		-- Ámbar (moneda, GDD §13) que gana cada jugador al terminar la partida.
		AmberPerDay = 10,
		AmberPerKill = 2,
		AmberPerRevive = 5,
		AmberPerBoss = 50, -- por cada jefe en el que participaste (Fase 5)
		AmberPerBounty = 15, -- por cada recompensa PvP cobrada (Fase 5)
		AmberPerEgg = 25, -- por cada huevo rescatado (Fase 5)
		AmberForRescue = 200, -- victoria: rescatados (Fase 6)
	},

	-- Jefes (Data/Bosses, BossService). Su vida ("maxHealth" en Data/Bosses, la de un jugador solo) se
	-- multiplica según los jugadores que pelean con él: vivos, fuera del Basecamp y a menos de su
	-- "leashRange" de la guarida. Con uno ×HealthBase y cada uno más +HealthPerExtraPlayer, así un
	-- jefe dura parecido con 1, 4 o 20 jugadores (con más, algo menos). Objetivo con 4 jugadores
	-- (octubre de 2026, medido con ServerStorage.Tools.Equilibrio): 2 min el primero y 3 min el último.
	Bosses = {
		HealthBase = 1,
		HealthPerExtraPlayer = 0.75,
		MaxHealthMultiplier = 16,
	},

	Basecamp = {
		-- Pieza de Workspace que marca el área del Basecamp (puede estar dentro de carpetas).
		-- Si no existe, se crea una zona con el tamaño y centro de abajo.
		ZonePartName = "BasecampZone",
		DefaultZoneSize = Vector3.new(120, 60, 120),
		DefaultZoneCenter = Vector3.new(0, 30, 0),
		-- Cada cuánto se comprueba quién está dentro.
		CheckIntervalSeconds = 0.5,
		-- Vida del campamento (BasecampService, Shared/Basecamp). Los monos del asedio que llegan a su
		-- hueco junto a la hoguera le quitan MonkeyDamageMultiplier × su daño en cada golpe. A 0 cae:
		-- deja de ser zona segura y las estaciones no funcionan. De día se regenera RegenPerSecond y
		-- vuelve a estar en pie al pasar de RecoverFraction de su vida.
		MaxHealth = 2000,
		MonkeyDamageMultiplier = 0.25,
		RegenPerSecond = 4,
		RecoverFraction = 0.5,
	},

	Resources = {
		-- Distancia máxima (studs) para recolectar de un arbusto o helecho (con el aviso E).
		HarvestDistance = 10,
		-- Alcance del hacha y el pico: distancia desde la superficie del árbol o la roca.
		ToolReach = 5.5,
		-- Hoz: corta los helechos y arbustos a menos de SickleReach studs que tienes delante (coseno del
		-- ángulo máximo con la mirada: 0.3 ≈ 70° a cada lado).
		SickleReach = 7,
		SickleArcDot = 0.3,
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
		-- Herramientas con las que aparece todo jugador, detrás de las armas de su rol (Data/Roles).
		StarterTools = { "WoodenAxe", "WoodenPick" },
		DodgeCooldownSeconds = 1.2,
		DodgeSpeed = 55,
		DodgeDurationSeconds = 0.15,
		-- Tiempo de invulnerabilidad al esquivar.
		DodgeInvulnerableSeconds = 0.35,
		DummyHealth = 100,
		-- Daño que haces mientras te intimida un mandril (Fase 4).
		IntimidatedDamageMultiplier = 0.7,
		-- Daño de los jugadores (armas y habilidades) a monos, jefes y muñecos. No toca el PvP ni las
		-- mascotas. Lo que enseñan la forja, las armas y los Ajustes ya lo lleva aplicado.
		PlayerDamageMultiplier = 0.7,
		-- Cerbatanas del médico ("healOnHit" en Data/Weapons): a qué distancia busca al aliado herido.
		WeaponHealRadius = 40,
		-- Puntería a corta distancia (CombatService.aimDeviation): la cámara mira por encima del hombro
		-- y, de cerca, un mono pequeño queda muy por debajo de la línea de tiro. A menos de
		-- CloseAimRange (en horizontal) y CloseAimHeight (en vertical) solo cuenta la dirección en
		-- horizontal, con un cono de al menos CloseAimDegrees.
		CloseAimRange = 18,
		CloseAimHeight = 8,
		CloseAimDegrees = 30,
		DummyRespawnSeconds = 3,
		-- Al soltarte de un agarre o un aturdimiento (monos, jefes, PvP), segundos en los que no te
		-- pueden volver a dejar quieto (Combat/Status.holdPlayer). Con 2, un orangután te tiene
		-- quieto como mucho el 46 % del tiempo y te da ~3 s para apartarte.
		PlayerControlImmunitySeconds = 2,
	},

	-- Golpes críticos (Shared/Crit): hacen más daño o curan más y su número sale más grande.
	Crit = {
		Multiplier = 1.35, -- daño o curación de un crítico (+35 %)
		-- Probabilidad de los monos según su categoría (Data/Monkeys, "tier"); la 1 nunca.
		MonkeyTierChance = { [2] = 0.15, [3] = 0.20 } :: { [number]: number },
		-- Probabilidad de los jefes en cada fase (la 3 es la furia).
		BossPhaseChance = { 0.25, 0.25, 0.28 },
		-- Las armas tienen la suya ("critChance" en Data/Weapons); sin ella, esta.
		DefaultWeaponChance = 0.05,
		PetChance = 0.10, -- golpes y curaciones de las mascotas
		-- Curación crítica del médico: base + la del arma y, si el aliado tiene menos de
		-- SaveThreshold de vida (fracción), una "salvada" con SaveBonusChance más.
		HealBaseChance = 0.10,
		SaveThreshold = 0.35,
		SaveBonusChance = 0.30,
	},

	-- Números flotantes de combate (CombatTextController).
	CombatText = {
		CritTextScale = 1.25, -- tamaño del número de un crítico
		PetTextScale = 0.7, -- tamaño de los de la mascota (los del jugador predominan)
		AllyTextScale = 0.7, -- daño que hacen los aliados (tenue)
		AllyMaxDistance = 60, -- studs: el daño de aliados más lejanos no se dibuja
		Slots = 4, -- números por columna
		LifetimeSeconds = 2.8,
		MergeSeconds = 0.1, -- golpes al mismo objetivo en este tiempo se suman en un número
		-- Lo que recoges ("+2 🌲 Madera"), en su propia columna a la derecha del personaje.
		LootSlots = 4,
		LootLifetimeSeconds = 4.5,
		LootMergeSeconds = 3, -- lo mismo recogido en este tiempo suma en la misma línea (< Lifetime)
	},

	-- Estallidos de cómic del combate ("BAM!", "POW!", "K.O.!", "OUCH!"): ComicFxController.
	ComicFx = {
		-- Lado en píxeles en una pantalla de 720 px de alto (se escala con el alto de la pantalla).
		Pixels = { Hit = 84, Crit = 150, KO = 190, Hurt = 120 } :: { [string]: number },
		MinScreenScale = 0.6, -- en un teléfono no bajan de esto (no se usa la escala de los números)
		SizeScale = { Small = 0.75, Normal = 1, Large = 1.3 } :: { [string]: number }, -- ajuste "comicSize"
		HitCooldownSeconds = 0.3, -- como mucho un estallido de golpe normal por enemigo en este tiempo
		CritCooldownSeconds = 0.12, -- y uno de crítico
		HurtCooldownSeconds = 0.25,
		HurtFraction = 0.1, -- lo que recibes sale si te quita al menos esto de tu vida máxima (o es crítico)
		MaxActive = 10, -- estallidos a la vez como mucho
		MaxDistance = 200, -- studs
	},

	-- Dos combos de 3 habilidades por rol, que se conectan (Data/Combos, ComboService).
	Combo = {
		-- Tiempo máximo entre un paso y el siguiente. Si el siguiente aún se está recargando, cuenta
		-- desde que esté listo: el combo no se pierde por haber usado antes una de sus habilidades.
		StepWindowSeconds = 6,
		-- Tras enlazar un paso, sus golpes contra los marcados son críticos durante este tiempo
		-- (cubre el Torbellino, el cepo que salta y lo que tarda en llegar un proyectil).
		PayoffSeconds = 6,
		UltRefundSeconds = 10, -- cada paso enlazado acerca la definitiva (V) esto…
		UltRefundMaxSeconds = 20, -- …y como mucho esto por cada recarga de la definitiva
		MaxStreak = 5,
		-- Por cada nivel de racha por encima de x1, recargas más rápidas. Era 0.08 con un combo por
		-- rol; con dos y las conexiones la racha se queda en x5 casi siempre y enlazar valía +50 %.
		StreakCooldownBonus = 0.04,
		StreakSeconds = 8, -- la racha se pierde tras este tiempo sin hacer daño ni curar
		-- Un combo cerrado tras una conexión (empezado por el remate del otro) sube la racha esto más.
		ConnectStreakBonus = 1,
		ShieldBonus = 0.5, -- Escudo de hojas al aliado revitalizado: absorbe esto más
		SalveFeverCure = 9, -- el Ungüento que cierra "Cura de urgencia" baja la fiebre esto…
		SalvePoisonDps = 6, -- …y envenena a los monos de su radio con este daño por segundo…
		SalvePoisonSeconds = 5, -- …durante esto
		FireballSplashBonus = 0.25, -- la Bola de fuego que rompe el hielo salpica más lejos
		WarCryStun = 1, -- el Grito enlazado del guerrero aturde a los desequilibrados (s)
		WhirlwindExtraSeconds = 1, -- el Torbellino que cierra el combo del guerrero gira más
		MarkPreyRoot = 1.5, -- Marcar presas enlazado vuelve a sujetar a los atrapados (s)
		MultiShotExtraArrows = 2, -- el Disparo múltiple que cierra el combo del cazador
		-- Segundos combos (remate con la habilidad nueva de cada rol).
		PierceExtraArrows = 2, -- la Flecha perforante que cierra "Tiro de gracia" dispara estas más…
		PierceSpreadDegrees = 10, -- …en un abanico así de ancho
		MeteorBurnTicks = 3, -- el Meteoro que cierra "Lluvia de estrellas" deja el suelo ardiendo (1 golpe/s)
		MeteorBurnDamage = 6, -- por golpe, en el radio del Meteoro
		PowderExtraSleep = 1, -- el Polvo somnífero que cierra "Nana de la selva" duerme esto más (s)…
		PowderHeal = 10, -- …cura esto a los aliados que estén en la nube…
		PowderExposed = 0.3, -- …y los dormidos reciben esto más de daño (fracción) hasta despertar
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
		-- Las tropas solo existen cerca de los jugadores: lejos se guardan como un número (los monos que
		-- tiene) y aparecen cuando alguien se acerca a su zona a menos de WakeDistance; se vuelven a
		-- guardar sin nadie a menos de DormantDistance y si ninguno está peleando. Así hay monos por
		-- toda la isla sin que existan todos a la vez (medido en Studio, 18-10-2026: un mono guardado
		-- no cuesta nada; uno despierto, ~14 µs de física en reposo y ~45 µs persiguiendo; el cliente
		-- baja de 60 FPS con más de ~75 monos alrededor). Con la densidad de ahora, cada jugador
		-- tiene ~50-70 monos a menos de 350 studs.
		WakeDistance = 350,
		DormantDistance = 450,
		PopulationCheckSeconds = 1,
		-- Los grupos aparecen en la selva entre estas distancias del centro del Basecamp (la isla mide
		-- 950: con 800, la franja de selva de fuera, ~1/5 de toda, se quedaba sin monos), y los de
		-- playa entre las de Beach.
		SpawnMinDistance = 140,
		SpawnMaxDistance = 920,
		BeachMinDistance = 480,
		BeachMaxDistance = 1120,
		-- Cada tropa nueva prueba tantos sitios al azar y se queda con el más alejado de las que ya
		-- hay (de su mismo turno, día o noche): así se reparten sin dejar claros vacíos. Simulado en
		-- el mapa (19-10-2026): el punto de selva más lejos de una tropa de día pasa de ~380 a ~210
		-- studs, y el 90 % queda a menos de ~130 (antes ~200).
		HomeCandidates = 10,
		-- Aullido: alcance del aviso, espera hasta los refuerzos y cuáles llegan.
		HowlRadius = 100,
		HowlReinforcementSeconds = 6,
		HowlReinforcementSpecies = "MonoArdilla",
		HowlReinforcementCount = 2,
		-- Fase 4: radio alrededor de la guarida de su bioma donde aparecen las especies de bioma,
		-- límite de monos a la vez en el servidor (rendimiento) y alfas de las tropas.
		-- El límite solo cuenta los monos que existen (cerca de algún jugador); si se llega, aparecen
		-- primero las tropas más cercanas a un jugador. Con 200 persiguiendo a la vez, la física del
		-- servidor llegó a 9 ms por fotograma (con picos de 35 ms).
		BiomeRadius = 220,
		MaxActive = 200,
		AlphaHealthMultiplier = 2.5,
		AlphaDamageMultiplier = 1.5,
		AlphaScale = 1.15, -- el alfa es un 15 % más grande que los de su especie (y de colores más marcados)
		PounceCooldownSeconds = 6,
		RoarCooldownSeconds = 15,
		-- Miedo al fuego: distancia a una antorcha u hoguera a la que las especies miedosas se apartan.
		-- La antorcha del jugador (TorchService) solo cuenta encendida: de noche, y no durante
		-- TorchRoarOutSeconds tras el rugido de un jefe que la apaga.
		FireFearRadius = 10,
		TorchRoarOutSeconds = 8,
		-- Los grupos con bajas recuperan un mono cada GroupRegrowSeconds mientras su especie esté
		-- activa, siempre que no haya jugadores a menos de RegrowMinPlayerDistance de su zona.
		GroupRegrowSeconds = 25,
		RegrowMinPlayerDistance = 120,
		-- Tropas más grandes (sobre groupMin/groupMax de cada especie): más monos juntos con los que
		-- enlazar combos.
		GroupSizeMultiplier = 1.5,
		-- Probabilidad de cada botín de Data/Monkeys ("chance") multiplicada por esto.
		LootChanceMultiplier = 0.5,
		-- Botín compartido: al morir un mono, cada unidad de su botín va al azar a uno de los que
		-- pelearon contra él: quienes le golpearon en los últimos LootShareSeconds y los médicos que
		-- curaron a alguno de ellos en ese tiempo.
		LootShareSeconds = 30,
		-- Especies (vida, daño, botín…): ver Shared/Data/Monkeys.
	},

	Life = {
		-- Segundos caído antes de reaparecer (en tu cama o en el Basecamp) si nadie te reanima.
		DownedSeconds = 60,
		-- "Rendirse": el caído mantiene pulsado el botón SurrenderHoldSeconds para reaparecer ya. No
		-- vale nada más caer: hace falta llevar al menos SurrenderAfterSeconds caído.
		SurrenderHoldSeconds = 1.5,
		SurrenderAfterSeconds = 3,
		CrawlSpeed = 4,
		ReviveHoldSeconds = 4,
		ReviveDistance = 8,
		-- Vida con la que vuelves al ser reanimado (fracción de la máxima).
		ReviveHealthFraction = 0.35,
		-- Parte de cada material que se queda en la mochila al reaparecer sin que te reanimen.
		DropFraction = 0.5,
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
		-- Al reaparecer sin que te reanimen, hambre y sed suben al menos a esto.
		RespawnMinStat = 50,
		-- Beber del río: sed que recupera cada trago y distancia al agua.
		DrinkThirst = 25,
		DrinkReach = 6,
		EatCooldownSeconds = 0.8,
		DrinkCooldownSeconds = 0.8,
		-- Curar (H): por debajo de esta fracción de vida, una venda o un ungüento van antes que el
		-- antídoto aunque tengas fiebre (CraftingService).
		HealFirstBelow = 0.6,
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
		-- Solo los mordiscos (no piedras, pisotones, jefes ni peligros) y según el daño que entra tras
		-- la armadura: perder una barra de vida entera a mordiscos suma esto. Un mono básico, +1.
		PerHealthBar = 20,
		RawMeat = 12,
		-- Baja sola (más rápido descansando en el Basecamp); el antídoto (taller del curandero) la
		-- quita de golpe.
		DecayPerMinute = 4,
		BasecampDecayPerMinute = 15,
		-- Desde aquí llegan oleadas de vista borrosa (cortas y espaciadas; más seguidas y fuertes
		-- cuanto más fiebre) y un tinte morado suave; a 100 además quita vida.
		SymptomsAt = 60,
		WaveEverySeconds = { atSymptoms = 16, atMax = 7 },
		WaveSeconds = 2.5,
		WaveBlur = { atSymptoms = 3, atMax = 8 },
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
		-- La Gran Tropa (noche final tras encender la baliza, Fase 6): una oleada por especie de la lista.
		-- La 1.ª trae solo la primera especie (tamaño normal del día × FinalNightSizeMultiplier); cada
		-- oleada repite la anterior y suma FinalNightGrowth (20 %) más monos de la especie siguiente.
		FinalNightSpecies = { "AulladorRojo", "Macaco", "Mandril", "Orangutan", "Gorila" },
		FinalNightSizeMultiplier = 1.5,
		FinalNightGrowth = 0.2,
		-- Reparto en el tiempo: la 1.ª llega pronto, la última con FinalNightLastWaveSeconds de noche aún
		-- por delante y el resto, a intervalos iguales entre ambas (nunca menos de FinalNightMinInterval).
		FinalNightFirstWaveDelaySeconds = 15,
		FinalNightLastWaveSeconds = 75,
		FinalNightMinIntervalSeconds = 20,
		-- Hasta dónde busca estacas un macaco del asedio. Va a por ellas antes que a por los jugadores,
		-- salvo que tenga uno al alcance de su golpe. Cada golpe le quita SpikeDisarmPerHit de vida a la
		-- estaca (de 100): unos 5 golpes, y se la ve hundirse (Buildables "sinkOnWear").
		TrapSearchRadius = 30,
		SpikeDisarmPerHit = 20,
		-- Cada mono del asedio hace su propio recorrido (MonkeyService): entra por su portón, se abre
		-- hacia un lado (hasta SpreadWidth studs, SpreadDepth studs más adentro) y acaba en su hueco
		-- alrededor de la hoguera (entre CampRingMin y CampRingMax studs del centro, girado hasta
		-- CampRingSpreadDegrees hacia el lado por el que se abrió). Así cruzan las estacas por sitios
		-- distintos y no se amontonan. Cada punto cuenta como alcanzado a WaypointReach studs.
		SpreadDepth = 15,
		SpreadWidth = 30,
		CampRingMin = 14,
		CampRingMax = 24,
		CampRingSpreadDegrees = 60,
		WaypointReach = 6,
		-- Si un mono del asedio lleva DetourAfterSeconds sin avanzar 3 studs (algo le tapa el paso,
		-- como el tótem), rodea hacia un lado DetourDistance studs durante DetourSeconds.
		DetourAfterSeconds = 2,
		DetourDistance = 10,
		DetourSeconds = 1.5,
		-- Distancia más allá del perímetro a la que aparecen, frente a los portones.
		SpawnDistance = 45,
		-- A qué distancia busca jugadores un mono del asedio y a qué distancia ataca una pieza.
		PlayerAggroRange = 30,
		StructureReach = 7,
		-- Daño a las piezas: multiplicador sobre el daño de la especie.
		StructureDamageMultiplier = 3,
		-- Estacas (SiegeService): los monos las cruzan (no se paran a romperlas). Al pisarlas reciben
		-- un pinchazo que desgasta la trampa (como mucho uno cada SpikeHitCooldownSeconds por mono,
		-- aunque pise varias); mientras siguen encima, daño por segundo y van a SpikeSlowFactor de su
		-- velocidad. La zona que pincha es la pieza más SpikeReachMargin studs por cada lado.
		-- Una fila: un aullador (60 de vida) pierde ~30 al cruzarla.
		SpikeHitDamage = 15,
		SpikeHitCooldownSeconds = 1,
		SpikeDamagePerSecond = 16,
		SpikeSlowFactor = 0.5,
		SpikeSlowSeconds = 1,
		SpikeReachMargin = 1,
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
		-- Clasificaciones (Fase 6): prefijo de los OrderedDataStore y cada cuánto refresca el Lobby.
		LeaderboardPrefix = "Ranking_v1_",
		LeaderboardRefreshSeconds = 300,
		-- XP de rol al terminar una partida: por día sobrevivido y por mono derrotado.
		RoleXpPerDay = 20,
		RoleXpPerKill = 2,
	},

	PvP = {
		-- PvP opt-in (GDD §12, Fase 5): espera para desactivarlo tras pedirlo en el tótem, y cuánto
		-- dura el PvP obligatorio al abrir una caja de suministro o cargar el huevo.
		DisableDelaySeconds = 180,
		ForcedSeconds = 180,
		-- Posición del tótem respecto al centro del Basecamp (si el mapa no tiene uno con el atributo
		-- "PvPTotem").
		TotemOffset = Vector3.new(0, 0, -32),
	},

	Supply = {
		-- Cajas de suministro (Fase 5): llegan a una playa cada IntervalSeconds de día si no hay otra.
		IntervalSeconds = 300,
		FirstDelaySeconds = 120,
		OpenHoldSeconds = 5,
		ItemsPerCrate = 3,
		-- Botín posible: { itemId, mín, máx, peso }.
		Loot = {
			{ itemId = "ShipMetal", min = 2, max = 4, weight = 5 },
			{ itemId = "Bandage", min = 2, max = 3, weight = 4 },
			{ itemId = "Ointment", min = 1, max = 2, weight = 2 },
			{ itemId = "CookedMeat", min = 2, max = 4, weight = 4 },
			{ itemId = "Stone", min = 10, max = 20, weight = 3 },
			{ itemId = "Liana", min = 1, max = 3, weight = 2 },
			{ itemId = "Leather", min = 1, max = 3, weight = 2 },
			{ itemId = "Antidote", min = 1, max = 1, weight = 2 },
			{ itemId = "LabCard", min = 1, max = 1, weight = 1 },
		},
	},

	Egg = {
		-- Huevo misterioso (GDD §11, Fase 5). De día, cada CheckSeconds hay Chance de que aparezca uno
		-- (si no hay otro), entre MinDistance y MaxDistance del Basecamp.
		CheckSeconds = 180,
		Chance = 0.4,
		MinDistance = 250,
		MaxDistance = 700,
		-- El portador va más lento (el guerrero, menos) y atrae a los monos cercanos.
		CarrySpeedMultiplier = 0.75,
		WarriorCarrySpeedMultiplier = 0.9,
		AttractRadius = 80,
		-- Quien esté a menos de esto del huevo mientras viaja cuenta como participante.
		ParticipantRadius = 60,
		-- Incubación en el nido: duración y oleadas que llegan a por él.
		IncubationSeconds = 150,
		DefenseWaves = 2,
	},

	Weather = {
		-- Clima (Fase 5): al empezar cada fase se sortea uno (pesos) que dura entre MinSeconds y MaxSeconds.
		Weights = { Clear = 60, Rain = 30, Storm = 10 },
		MinSeconds = 120,
		MaxSeconds = 240,
		-- La lluvia quita sed a quien está fuera del Basecamp (por segundo; la tormenta, el doble).
		RainThirstPerSecond = 0.3,
		-- Tormenta: un rayo cada tantos segundos cerca de un jugador al azar (con aviso en el suelo).
		LightningEverySeconds = 20,
		LightningDamage = 15,
		-- Erupción del volcán: probabilidad en cada fase, duración, ritmo de bombas de lava y alcance.
		EruptionChance = 0.08,
		EruptionSeconds = 60,
		LavaBombEverySeconds = 0.7,
		LavaBombDamage = 20,
		EruptionRadius = 230,
	},

	Pets = {
		-- Probabilidad (peso) de cada rareza al eclosionar un huevo (Fase 5).
		RarityWeights = { Common = 55, Uncommon = 25, Rare = 13, Epic = 6, Legendary = 1 },
		-- Cada cuánto actúan las mascotas de combate y curación, y su alcance de ataque.
		TickSeconds = 2,
		AttackRange = 25,
		-- Segundos desde que la mascota sale hacia el mono hasta que le golpea (el daño llega entonces,
		-- a la vez que el golpe que dibujan los clientes en UI/PetFollowers).
		StrikeDelaySeconds = 0.35,
	},

	Abilities = {
		-- Habilidades de los roles (Fase 3; nombres y tiempos de espera en Shared/Data/Roles).
		-- Los daños se multiplican por la ventaja de daño del rol (MeleeDamage, RangedDamage o
		-- SpellDamage) y los de cada talento (Data/Perks).
		-- Contra otros jugadores (PvP activo) hacen este daño y los aturdimientos duran esto.
		PvPDamageMultiplier = 0.5,
		PvPControlMultiplier = 0.5,
		-- Los jefes se resisten: aturdir, congelar o inmovilizar les dura esta fracción.
		BossControlMultiplier = 0.5,
		-- Veneno (Combat/Status.poison: cerbatanas y remate de "Cura de urgencia"): un golpe cada tanto.
		PoisonTickSeconds = 1,

		-- Octubre de 2026: las activas (Z, X, C) se recargan un 40 % antes (Data/Roles) y sus daños,
		-- curaciones, escudos y duraciones bajan un 40 %; se usan más a menudo con el mismo daño por
		-- segundo y los combos (Data/Combos) ponen el extra. Las definitivas (V) no cambian.

		-- Guerrero.
		WhirlwindDamage = 7, -- por golpe
		WhirlwindInterval = 0.5, -- segundos entre golpes
		WhirlwindRadius = 10,
		ChargeDistance = 20,
		ChargeSeconds = 0.35, -- lo que dura la carga
		ChargeDamage = 21,
		ChargeWidth = 6,
		ChargeKnockback = 45,
		WarCryRadius = 40,
		WarCrySeconds = 4, -- provoca y protege (con 12 s de recarga, un tercio del tiempo)
		QuakeDamage = 150,
		QuakeRadius = 16,
		SmashDamage = 24, -- Rompehuesos, a cada mono del cono de delante
		SmashRange = 9,
		SmashAngle = 100, -- grados del cono (enlazado como remate, golpea alrededor)
		SmashStun = 0.5, -- los tumba un momento (corto: el control del equipo sobre los jefes)

		-- Cazador.
		MultiShotDamage = 7, -- por proyectil
		MultiShotSpreadDegrees = 40,
		MultiShotRange = 100,
		MarkRadius = 70,
		TrapDamage = 12,
		TrapRadius = 3.5, -- salta cuando un mono lo pisa (a esta distancia)
		TrapCatchRadius = 8, -- y atrapa a todos los que estén a esta distancia (en horizontal)
		TrapHeight = 7, -- cuánto más arriba o más abajo pueden estar (laderas, monos grandes)
		TrapLifetime = 30,
		TrapMaxActive = 2,
		RainDamage = 20, -- por golpe
		RainTicks = 8,
		RainSeconds = 4,
		RainRadius = 12,
		RainMaxDistance = 60,
		PierceDamage = 16, -- Flecha perforante, a cada mono que atraviesa
		PierceRange = 90,
		PierceWidth = 1.5, -- radio de la línea que atraviesa
		PierceSpeed = 220, -- studs/s

		-- Mago.
		FireballDamage = 27, -- al que recibe el impacto
		FireballSplashDamage = 18, -- a los demás del radio
		FireballSplashRadius = 8,
		FireballSpeed = 90,
		FireballRange = 100,
		NovaDamage = 12,
		NovaRadius = 14,
		NovaSlowSeconds = 1.8, -- tras el congelado
		NovaSlowFactor = 0.5, -- velocidad que les queda
		ChainDamage = 120,
		ChainFalloff = 0.75, -- cada salto hace esto del anterior
		ChainRange = 60, -- alcance hasta el primer mono
		ChainJumpRange = 20,
		MeteorDamage = 24, -- Meteoro, a cada mono del radio
		MeteorRadius = 9,
		MeteorDelay = 0.8, -- segundos entre el aviso en el suelo y el impacto (da tiempo a verlo caer)
		MeteorMaxDistance = 60, -- cae donde apuntas, como mucho a esta distancia

		-- Médico.
		AreaHealAmount = 11, -- a cada aliado del radio (cada 15 s)
		AreaHealRadius = 18,
		DartHeal = 21,
		DartDamage = 9,
		DartRange = 80,
		DartSpeed = 160,
		ShieldSeconds = 6,
		ShieldRange = 30, -- busca al aliado más cercano hasta esta distancia
		-- "Savia protectora" (pasiva del médico, Data/Perks "SapShield"): al curar a un aliado gana un
		-- escudo que dura esto, como mucho uno cada SapShieldCooldown segundos.
		SapShieldSeconds = 5,
		SapShieldCooldown = 8,
		TotemSeconds = 10,
		TotemHealPerSecond = 6,
		TotemRadius = 16,
		TotemMaxDistance = 40, -- se planta donde apuntas, como mucho a esta distancia
		PowderDamage = 8, -- Polvo somnífero, a cada mono de la nube
		PowderRadius = 9,
		PowderMaxDistance = 40, -- la nube cae donde apuntas, como mucho a esta distancia
		PowderDrowsySeconds = 1, -- primero les entra sueño (van lentos)…
		PowderSlowFactor = 0.5, -- …a esta velocidad, y luego se duermen (Data/Perks "PowderSleep")
	},

	Party = {
		-- Grupos del Lobby (Fase 3): tamaño máximo y segundos que vale una invitación.
		MaxSize = 6,
		InviteSeconds = 60,
	},

	Performance = {
		-- Cada cuántos segundos escribe PerformanceService su resumen en la Salida.
		LogSeconds = 120,
	},

	Cosmetics = {
		-- En Studio, los cosméticos sin Game Pass (ID 0) se pueden probar gratis.
		FreeInStudio = true,
	},

	Teleport = {
		-- Segundos mínimos entre dos peticiones de viaje del mismo jugador.
		CooldownSeconds = 5,
		MaxAttempts = 3,
		RetryDelaySeconds = 2,
	},

	Lobby = {
		-- Etiqueta (CollectionService) de las luces del barco que parpadean como averiadas
		-- (las pone World/LobbyBuilder; las hace parpadear ShipLightsController en cada cliente).
		BrokenLightTag = "LuzAveriada",
		-- Tablones colgados del casco (los pone World/LobbyBuilder): el del ranking lo rellena
		-- LeaderboardService con los RankingBoardSize primeros de cada clasificación, y el de los
		-- roles lo dibuja RoleBoardController en cada cliente (tu nivel y tu rol elegido).
		RankingBoardTag = "TablaRanking",
		RankingBoardSize = 5,
		RoleBoardTag = "TablaRoles",
	},

	Social = {
		-- Invitar amigos, favoritos y notificaciones (para que llegue más gente; docs/LANZAMIENTO.md §9).
		InviteMessage = "¡Ven a sobrevivir conmigo en la isla de los monos!",
		-- Al llegar al Lobby con estas partidas jugadas se pide marcar el juego como favorito (si no
		-- lo es ya). Solo se pide una cosa por visita al Lobby y unos segundos después de llegar.
		FavoritePromptMatches = { 1, 3, 6, 10 },
		-- Desde esta partida se ofrece activar las notificaciones (Roblox solo lo muestra una vez cada
		-- 30 días, a mayores de 13 años y si aún no las tiene activadas).
		NotificationPromptMinMatches = 2,
		PromptDelaySeconds = 6,
		-- Aviso a tus amigos cuando entras al Lobby. Es el "Asset ID" de la cadena de notificación
		-- (Creator Hub → tu experiencia → Interacción → Notificaciones). Texto sugerido:
		-- "{userId-friend} está jugando {experienceName}. ¡Únete a su tropa!". "" = desactivado.
		FriendJoinedMessageId = "f6089cdc-feb4-484f-9bcc-29c06b14d736",
		FriendNotifyMax = 25, -- amigos avisados como mucho cada vez
		FriendNotifyCooldownSeconds = 6 * 3600, -- por jugador: no avisa otra vez al volver de la Isla
	},
}

return Config
