--!strict
-- Configuración central del juego.
-- Para balancear o ajustar el juego, cambia los números aquí: la lógica los lee de este módulo.

-- Premio del calendario, de las misiones y del pase (Daily; Shared/Rewards los escribe para el
-- jugador). "xp": XP del pase de temporada (las misiones; ServerShared/SeasonPass).
export type Reward = {
	amber: number?,
	items: { [string]: number }?,
	eggSeconds: number?,
	egg: { [string]: number }?,
	xp: number?,
}

-- Marca una frase para traducirla después (Strings.later; Config no carga Strings): tools/strings.py la busca.
local function later(es: string): string
	return es
end

local Config = {
	GameName = "Primal Banana Islands",
	Subtitle = "Monkey Survival",

	-- IDs de los places de la experiencia. Cómo obtenerlos: docs/SETUP.md, paso 6.
	PlaceIds = {
		Lobby = 86360888108434, -- place "Primal Banana Islands" (lugar de inicio)
		Island = 84163809226177, -- place "🍌Isla de monos🐒(survival)": la partida de supervivencia
		Dunas = 122593636654552, -- place "🎖️Isla de dunas☠️(PvP)": la arena PvP (captura la bandera)
		Laboratorio = 106219409395860, -- place "🧪Laboratorio en ruinas🏴‍☠️(PvP)": el shooter por equipos (Fase 13)
	},
	-- Nombres de los places. "Island", "Dunas" y "Laboratorio" son los que tienen en el Creator Hub
	-- (cambiarlos allí también, docs/SETUP.md); los cortos van dentro de las frases del juego ("Ir a la
	-- Isla de monos").
	PlaceNames = {
		Island = "🍌Isla de monos🐒(survival)",
		Dunas = "🎖️Isla de dunas☠️(PvP)",
		Laboratorio = "🧪Laboratorio en ruinas🏴‍☠️(PvP)",
		IslandShort = "Isla de monos",
		DunasShort = "Isla de dunas",
		LaboratorioShort = "Laboratorio en ruinas",
	},

	Match = {
		-- Tamaño del servidor de la Isla de monos. Lo decide Roblox por place (docs/SETUP.md, paso 7:
		-- Lobby 20, Isla de monos 5, Isla de dunas 10); aquí solo se apunta. Una partida es para un
		-- grupo de amigos (desde el 20-10-2026; antes 20 jugadores).
		MaxPlayers = 5,
		DayLengthSeconds = 10 * 60,
		NightLengthSeconds = 7 * 60,
		-- Segundos antes de la noche en que se avisa a los jugadores para que vuelvan.
		DuskWarningSeconds = 60,
		-- Un jefe cada BossIntervalDays días, en este orden (GDD §8.2).
		BossIntervalDays = 2,
		BossRotation = { "OrangutanDelManglar", "ChimpanceCaudillo", "GorilaAlbino", "GorilaDeCeniza" },
		-- Cada vuelta de la rotación (días 10–16, 18–24…, Fase 12) los jefes ya derrotados salen con esto
		-- más de vida y de daño por vuelta, hasta Difficulty.MaxMultiplier, y sin pieza de baliza nueva.
		-- Uno que aún no han derrotado vuelve con su fuerza normal.
		BossRoundHealth = 0.3,
		BossRoundDamage = 0.15,
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
	-- jefe dura parecido con 1, 3 o 5 jugadores. Objetivo con 4 jugadores
	-- (octubre de 2026, medido con ServerStorage.Tools.Equilibrio): 2 min el primero y 3 min el último.
	Bosses = {
		-- Unidades de su botín especial (Data/Bosses "lootItemId") para cada jugador que le hizo daño:
		-- una para el arma y otra para la armadura de la forja (Data/Recipes).
		LootPerPlayer = 2,
		HealthBase = 1,
		HealthPerExtraPlayer = 0.75,
		MaxHealthMultiplier = 16,
		-- Fuera de la Isla (el administrador lo invoca en el Lobby, Dunas o el Laboratorio) no hay botín ni
		-- baliza: cada jugador que le hizo daño recibe esto una sola vez por jefe. Solo Ámbar (que compra
		-- mejoras de poder, nunca se vende) y XP de pase; nada de Robux. Medido el 29-10-2026: 50 Ámbar es el
		-- 12,5 % del tope diario de Dunas (igual que AmberPerBoss) y 50 XP el 4,2 % de DailyMatchXpCap (cuenta
		-- contra ese tope). Solo un administrador lo invoca; si el evento se abre al público, hace falta un
		-- tope diario.
		OutsideReward = { Amber = 50, PassXp = 50 },
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
		-- Fase 9 (G5): vetas de obsidiana que ResourceService pone al arrancar si el mapa no tiene
		-- ninguna, junto a las guaridas del volcán y de la cueva (Mapa/GuaridasJefes). "min"/"max": a
		-- cuántos studs de la guarida (en el volcán, fuera del cráter de lava). "inside": la guarida
		-- está bajo tierra y el rayo que busca el suelo sale de dentro de la sala, no del cielo.
		ObsidianVeins = {
			{ lair = "Guarida_Volcan", count = 10, min = 45, max = 130 },
			{ lair = "Guarida_Cuevas", count = 5, min = 10, max = 20, inside = true },
		},
		-- Tiempos y cantidades de cada tipo: ver Shared/Data/ResourceNodes.
	},

	-- Grupo de colisión de los rayos del combate (Combat/Hitbox, CombatClient/Aim): lo que su grupo no deja
	-- chocar con este (los muros invisibles del Laboratorio, Lab.WallGroup) no frena disparos ni línea de visión.
	ShotCollisionGroup = "Disparo",

	Combat = {
		-- Solo se puede dañar a lo que tenga esta etiqueta (CollectionService): monos y muñecos.
		EnemyTag = "Enemy",
		-- Coberturas que se rompen (Fase 10, C11; Combat/Destructibles): los modelos del mundo con esta
		-- etiqueta. Hoy solo las estelas y columnas de la arena de Dunas (Config.Arena.Covers).
		DestructibleTag = "Destructible",
		-- Herramientas con las que aparece todo jugador, detrás de las armas de su rol (Data/Roles).
		StarterTools = { "WoodenAxe", "WoodenPick" },
		-- Tras hacer o recibir daño no se abren las estaciones, los cofres ni la parcela (Shared/InteractLock).
		InteractLockSeconds = 4,
		DodgeCooldownSeconds = 1.2,
		DodgeSpeed = 55,
		DodgeDurationSeconds = 0.2,
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
		-- Puntería a corta distancia (CombatService.aimDeviation, el Rayo encadenado; y los proyectiles,
		-- CombatService.aimShot): la cámara mira por encima del hombro y, de cerca, un mono pequeño queda
		-- muy por debajo de la línea de tiro. A menos de CloseAimRange (en horizontal) y CloseAimHeight (en
		-- vertical) solo cuenta la dirección en horizontal (el Rayo, con un cono de al menos
		-- CloseAimDegrees).
		CloseAimRange = 18,
		CloseAimHeight = 8,
		CloseAimDegrees = 30,
		DummyRespawnSeconds = 3,
		-- Muñeco de sparring (Fase 10, C6; Combat/TrainingDummies), junto a los de práctica: devuelve los
		-- golpes para practicar el bloqueo y el parry. No hace daño: gasta guardia, la rompe y, con un
		-- parry, se queda tambaleado.
		SparringAttackSeconds = 1.8, -- uno cada esto…
		SparringRange = 6, -- …a quien esté a menos de esto (studs)
		SparringWindupSeconds = 0.5, -- como un mono de categoría 2
		SparringGuardDamage = 18,
		-- Al soltarte de un agarre o un aturdimiento (monos, jefes, PvP), segundos en los que no te
		-- pueden volver a dejar quieto (Combat/Status.holdPlayer). Con 2, un orangután te tiene
		-- quieto como mucho el 46 % del tiempo y te da ~3 s para apartarte.
		PlayerControlImmunitySeconds = 2,
		-- Studs sobre el suelo desde donde mira un área que cae en el suelo (Meteoro, Lluvia, Polvo,
		-- Cepo) para saber a quién alcanza sin pared en medio (Combat/Hitbox.visible).
		AreaSightLift = 3,
		-- Disparos a la cabeza (Fase 15, V7; CombatRules.headshots: Dunas y el Laboratorio). Solo armas a
		-- distancia contra jugadores; los proyectiles se prueban contra una esfera de cabeza y una cápsula
		-- de cuerpo (Combat/Hitbox.sweepPlayers) en la posición rebobinada de la víctima.
		Headshot = {
			-- Multiplicador del daño de un impacto directo a la cabeza. No se suma al crítico: cuenta el mayor.
			Multiplier = 1.5,
			-- La esfera de la cabeza es este factor × el radio visible de la pieza Head (la mitad de su lado
			-- mayor): algo mayor que la cabeza, para que el móvil no quede castigado.
			HeadRadiusScale = 1.15,
			-- Radio (studs) de la cápsula vertical del cuerpo, de los pies al cuello; incluye los brazos.
			BodyRadius = 1.2,
			-- Studs que puede separarse el origen que manda el cliente de la cabeza del servidor (rebobinada).
			OriginToleranceStuds = 5,
			-- Segundos máximos que el proyectil se adelanta al salir para compensar el retraso del tirador.
			ShotLeadMaxSeconds = 0.1,
			-- Solo visual: el proyectil propio sale del cañón del arma y en estos segundos se junta con su
			-- trayectoria real (AbilityFxController.projectile). No cambia dónde acierta.
			MuzzleBlendSeconds = 0.12,
		},
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

	-- Pantalla roja al recibir daño (DamageFxController): destello de bordes, pulso con poca vida y arco
	-- hacia el atacante en PvP. Todo en rojo; se apaga con el ajuste "damageFx".
	DamageFx = {
		BigHitFraction = 0.15, -- un golpe de esta parte de la vida máxima también dispara el destello
		LowHealthFraction = 0.25, -- por debajo de esta parte de la vida pulsa la viñeta
		FlashSeconds = 0.35, -- lo que tarda en apagarse el destello
		FlashAlpha = 0.45, -- opacidad del destello (crítico o golpe fuerte)
		HeadFlashAlpha = 0.7, -- opacidad del destello de un golpe a la cabeza
		PulseSeconds = 1.2, -- periodo del pulso con salud baja
		PulseMin = 0.12, -- opacidad mínima y máxima del pulso
		PulseMax = 0.30,
		PulseFadeSeconds = 0.4, -- se funde a 0 al curarte por encima del umbral
		ArcSeconds = 0.8, -- el arco que señala al atacante
	},

	-- Estallidos de cómic del combate ("BAM!", "POW!", "K.O.!", "OUCH!"): ComicFxController.
	ComicFx = {
		-- Lado en píxeles en una pantalla de 720 px de alto (se escala con el alto de la pantalla).
		Pixels = {
			Hit = 84,
			Crit = 150,
			KO = 190,
			Hurt = 120,
			Parry = 160,
			GuardBroken = 170,
			Counter = 160,
		} :: { [string]: number },
		MinScreenScale = 0.6, -- en un teléfono no bajan de esto (no se usa la escala de los números)
		SizeScale = { Small = 0.75, Normal = 1, Large = 1.3 } :: { [string]: number }, -- ajuste "comicSize"
		HitCooldownSeconds = 0.3, -- como mucho un estallido de golpe normal por enemigo en este tiempo
		CritCooldownSeconds = 0.12, -- y uno de crítico
		HurtCooldownSeconds = 0.25,
		HurtFraction = 0.1, -- lo que recibes sale si te quita al menos esto de tu vida máxima (o es crítico)
		MaxActive = 10, -- estallidos a la vez como mucho
		MaxDistance = 200, -- studs
		-- La guardia (C12): el parry y la rotura salen sobre ti y sobre los jugadores a menos de esto (en
		-- la arena, el rival con quien peleas)…
		GuardNearbyStuds = 24,
		-- …y tu primer golpe a un enemigo aturdido o a un rival tambaleado hasta esto tras tu parry es una
		-- "¡CONTRA!" (lo que dura el aturdido del parry a un mono, Config.Guard.ParryStaggerMonkey).
		CounterSeconds = 1,
	},

	-- Temblor de la cámara en combate (C12, CombatClient/CameraShake): cuánto tiembla con cada valor del
	-- ajuste "cameraShake" (Shared/Settings). Lo usan el remate de la cadena, las habilidades, el rebote
	-- contra muros y la guardia.
	CameraShake = {
		Scale = { On = 1, Soft = 0.45, Off = 0 } :: { [string]: number },
		ParryPower = 0.35, -- al hacer un parry: un golpe seco y corto…
		ParrySeconds = 0.15,
		BreakPower = 0.8, -- …y al romperte la guardia, más fuerte
		BreakSeconds = 0.35,
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

	-- Fase 10, "Combate v2" (docs/PLAN.md): números propuestos para las mecánicas nuevas, medidos con la
	-- calculadora ServerStorage.Tools.Equilibrio (secciones 7 a 10). Hasta que se haga el grupo de cada
	-- uno (C2–C11), solo los lee la calculadora.

	-- Lo que tarda una persona en reaccionar a un aviso que ve (s). Un hueco más corto entre dos golpes
	-- no deja responder: cuenta como combo sin escape.
	Reaction = {
		Seconds = 0.25,
	},

	-- Estados de combate de los jugadores (C2; Shared/CombatState, Combat/StateMachine). Un estado
	-- nuevo solo sustituye al que hay si su prioridad es igual o mayor (o el que hay ya terminó): un
	-- aturdimiento corta un ataque, pero un ataque no corta un aturdimiento. Qué impide cada estado
	-- está en Shared/CombatState.
	CombatStates = {
		Priority = {
			Idle = 0,
			Attacking = 1,
			Casting = 1,
			Blocking = 2,
			Dodging = 2,
			Parrying = 3,
			Staggered = 4,
			Stunned = 5,
			GuardBroken = 5,
			Evading = 6, -- el Evasivo saca de un aturdimiento
			Downed = 7,
		} :: { [string]: number },
	},

	-- Cadena de golpes de las armas cuerpo a cuerpo (C4; Shared/MeleeChain): 4 golpes y el 4.º remata.
	-- Cada paso hace "damage" × el daño del arma y dura "time" × su cooldownSeconds (las armas pesadas
	-- encadenan más despacio). Con la suma de "damage" igual a la de "time", el DPS es el mismo que con
	-- golpes sueltos. Las herramientas (hacha, pico, hoz: "tool" en Data/Weapons) siguen con el golpe
	-- suelto.
	Chain = {
		Steps = {
			{ damage = 0.9, time = 0.9 },
			{ damage = 0.9, time = 0.9 },
			{ damage = 1.0, time = 1.0 },
			{ damage = 1.4, time = 1.4 }, -- remate: empuja (o lanza hacia arriba si el atacante va en el aire)
		},
		WindupFraction = 0.35, -- parte de cada paso antes del golpe (preparación, el momento del amago)
		-- Desde que se puede dar el siguiente golpe, hasta cuándo sigue la cadena; después vuelve al primero.
		LinkWindowSeconds = 0.8,
		-- Una pulsación hasta este tiempo antes de que se pueda pegar se guarda y sale en cuanto se puede
		-- (el cliente; quien pulsa al ritmo no pierde golpes por el fotograma o el toque).
		BufferSeconds = 0.3,
		-- Tambaleo de cada golpe contra jugadores (no el remate, que empuja). Como mucho dura el hueco hasta
		-- el siguiente golpe menos Config.Reaction: la cadena siempre deja responder (bloquear, parry o
		-- esquivar entre dos golpes), también con las armas rápidas.
		PvPHitstunSeconds = 0.35,
		FinisherKnockback = 35, -- studs/s del empuje del remate…
		FinisherKnockbackSeconds = 0.2, -- …durante este tiempo (unos 7 studs)
		FinisherLaunch = 45, -- studs/s hacia arriba si el atacante va en el aire
		-- Si no hay suelo a esta distancia bajo la raíz del atacante, va en el aire (la raíz queda a ~3,2).
		AirborneGroundDistance = 4.5,
		FinisherStaggerTier = 2, -- monos hasta esta categoría se tambalean con el remate (no alfas ni jefes)
		FinisherStaggerSeconds = 0.6,
		-- Sensación (solo en el cliente que pega): el tajo se para un instante al dar ("parón de impacto")
		-- y el remate hace temblar un poco la cámara.
		HitStopSeconds = 0.05,
		FinisherHitStopSeconds = 0.1,
		FinisherShakeStuds = 0.25,
	},

	-- Disparo de remate de las armas a distancia (C9b; Shared/RangedChain): el Length.º disparo seguido al
	-- mismo ritmo es un remate, un proyectil distinto que se ve y se puede esquivar. Cada arma dice el
	-- suyo ("finisher" en Data/Weapons). Los normales hacen "shot" × el daño del arma y el remate
	-- "finisher" ×: con (Length − 1) × shot + finisher = Length, el DPS contra uno es el de antes. Lo que
	-- el remate hace además lo mide la calculadora (sección 7).
	RangedChain = {
		Length = 4,
		-- Desde que se puede disparar otra vez, hasta cuándo sigue la cuenta; después vuelve al primero.
		LinkWindowSeconds = 0.8,
		Finishers = {
			-- Arcos: la flecha atraviesa al primero y da también al siguiente (pierceTargets en total), a
			-- éste con othersDamage × su daño.
			Pierce = { shot = 0.9, finisher = 1.3, pierceTargets = 2, othersDamage = 0.35 },
			-- Bastones: la bola estalla donde se para; a los demás a menos de "radius" studs (con línea de
			-- visión), othersDamage × su daño.
			Burst = { shot = 0.9, finisher = 1.3, radius = 6, othersDamage = 0.35 },
			-- Cerbatanas: el dardo de savia cura healMultiplier × lo normal (healOnHit) a un aliado; al propio
			-- médico, lo normal (en un duelo no se sostiene más). Un veneno doble subía su DPS un 20 %: el
			-- remate llega antes de que se acabe y quedaba doble todo el rato.
			Sap = { shot = 0.9, finisher = 1.3, healMultiplier = 2 },
			-- Hondas: tambalea staggerSeconds a un mono hasta Config.Chain.FinisherStaggerTier (no alfas,
			-- jefes ni jugadores: sería control sin riesgo a distancia).
			Stagger = { shot = 0.9, finisher = 1.3, staggerSeconds = 0.6 },
		},
	},

	-- Guardia (C5; Combat/Guard, GuardController): pulsar F / L2 / "Guardia" abre el parry y mantenerla
	-- bloquea. Atributo "Guard" del Player (0–Max).
	Guard = {
		Max = 100,
		RegenPerSecond = 25,
		RegenDelaySeconds = 1, -- sin recibir golpes este tiempo, se recupera (también bloqueando)
		-- Daño que quita el bloqueo contra jugadores… (0,6 dejaba el duelo de guerreros con defensa en
		-- 12,2 s, fuera de 8–12)
		BlockReduction = 0.5,
		BlockReductionEnemies = 0.7, -- …y contra monos y jefes
		BlockAngle = 120, -- grados del cono de delante que cubren el bloqueo y el parry
		BlockWalkMultiplier = 0.6, -- velocidad mientras bloquea (y no corre)
		-- Guardia que gasta cada golpe bloqueado. Los de la cadena son los de un arma de
		-- ChainReferenceCooldown s y se escalan con su cooldownSeconds: así cualquier arma rompe la guardia
		-- en el mismo tiempo (las rápidas pegan más veces, pero gastan menos cada vez).
		ChainGuardDamage = 12,
		FinisherGuardDamage = 24,
		ChainReferenceCooldown = 0.9,
		ProjectileGuardDamage = 10,
		AbilityGuardDamage = 25, -- por defecto; una habilidad puede llevar el suyo (Data/Roles "guardDamage")
		MonkeyGuardDamage = { [1] = 12, [2] = 18, [3] = 22 } :: { [number]: number }, -- por categoría
		AlphaGuardMultiplier = 1.5,
		BossGuardDamage = 25,
		-- Guardia rota: aturdido (estado "GuardBroken"). Si la rompe otro jugador, × el control del place
		-- (CombatRules.pvpControlMultiplier).
		BreakStunSeconds = 1.2,
		-- Desde que se pulsa (aunque se suelte enseguida); igual para todos los dispositivos.
		ParryWindowSeconds = 0.3,
		ParryRearmSeconds = 0.8, -- no se puede volver a hacer parry hasta pasado esto (no se puede spamear)
		ParryStaggerPvP = 0.6, -- el atacante al que le paran el golpe queda tambaleado…
		ParryStaggerMonkey = 1, -- …un mono, aturdido (los jefes se resisten: ×BossControlMultiplier)…
		ParryStaggerRange = 12, -- …solo si pega desde aquí (studs): parar un disparo no tambalea al tirador
		ParryGuardRefund = 20, -- …y quien para recupera esto de guardia
	},

	-- Proyectiles reales (C9; Combat/Projectiles): los disparos de las armas a distancia y las habilidades
	-- que viajan (Disparo múltiple, Flecha perforante, Bola de fuego, Dardo curativo) los mueve el
	-- servidor paso a paso, y dan a quien encuentran por el camino. Se pueden esquivar, bloquear y parar.
	Projectiles = {
		WeaponRadius = 0.6, -- radio (studs) del disparo de un arma
		-- Ayuda de puntería (CombatService.aimShot): solo elige la dirección de salida, y solo si la línea de
		-- tiro ya pasa casi por el blanco: su centro a menos de MonkeyAimStuds de ella (de lejos, dentro de
		-- MonkeyAimMinDegrees). Así, apuntando entre dos monos el disparo pasa entre ellos (con un cono de
		-- 10–12°, y 30° de cerca, se iba al de al lado). Contra monos apunta adonde estará al llegar (como
		-- mucho LeadMaxSeconds por delante); contra jugadores, más estrecho (PlayerAim…) y adonde está: se
		-- pueden apartar. De cerca (Config.Combat.CloseAimRange) un mono pequeño queda por debajo de la
		-- línea de la cámara: ahí solo cuenta la distancia en horizontal. Igual para todos los dispositivos.
		MonkeyAimStuds = 2.5,
		MonkeyAimMinDegrees = 2,
		PlayerAimStuds = 1.5,
		PlayerAimMinDegrees = 1,
		LeadMaxSeconds = 0.8,
	},

	-- Compensación del lag (C2, C3, C5): margen a favor del defensor o del atacante, igual para todos y
	-- con tope. Nadie gana por tener más ping.
	Net = {
		MaxCompensationSeconds = 0.15, -- rebobinar posiciones al golpear
		-- Esperar el parry del defensor antes de aplicar un golpe de arma en PvP (su ping, hasta esto). La
		-- pulsación cuenta desde la hora que manda su cliente, como mucho esto antes de llegar.
		ParryGraceMaxSeconds = 0.12,
		-- Margen fijo al comprobar un ritmo que el cliente lleva con su reloj (la cadena de golpes): una
		-- pulsación puntual llega unos milisegundos antes o después según la red y el fotograma.
		JitterSeconds = 0.05,
		-- Posiciones guardadas de cada combatiente para rebobinar (Combat/PositionHistory).
		HistorySeconds = 1,
		HistoryRate = 20, -- muestras por segundo
	},

	-- Evasivo (C7; Combat/Evasive, DodgeController): la esquiva pulsada estando aturdido, con la guardia
	-- rota, inmovilizado o lanzado (Shared/CombatState.isTrapped). Quita el estado, da invulnerabilidad
	-- y aparta. No gasta estamina: atrapado puedes no tener. Sujeto y con el Evasivo en recarga, no se
	-- puede esquivar.
	Evasive = {
		CooldownSeconds = 25,
		InvulnerableSeconds = 0.5,
		Speed = 60, -- studs/s del salto que aparta…
		DurationSeconds = 0.2, -- …durante esto (12 studs y unos 2,4 más de inercia: fuera del alcance de un arma)
	},

	-- Escalado de un combo en PvP (C7; Combat/ComboScaling), por víctima: cuenta los golpes seguidos que
	-- recibe de otros jugadores y se reinicia tras ResetSeconds sin recibir, al bloquear o parar y con el
	-- Evasivo. Cada habilidad cuenta como un golpe aunque pegue varias veces; el veneno no cuenta. Desde
	-- el golpe FromHit, cada uno hace DamageStep menos (hasta MinDamage) y su tambaleo dura HitstunStep
	-- menos (hasta MinHitstun).
	ComboScaling = {
		FromHit = 4,
		DamageStep = 0.08,
		MinDamage = 0.5,
		HitstunStep = 0.15,
		MinHitstun = 0.4,
		ResetSeconds = 1,
	},

	-- Rendimientos decrecientes del control sobre monos y jefes (C6), por modelo: cada control seguido
	-- dura esta fracción; después, inmune hasta ResetSeconds sin recibir otro. Suaves a propósito: un
	-- rol solo casi no los nota (cazador sobre un mono 27 → 25 %); muerden cuando varios encadenan
	-- controles sobre el mismo (equipo de 4 sobre un jefe 25 → 12 %, con talentos al máximo 35 → 17 %).
	-- Con 1 → 0,5 → 0,25 y 10 s el control casi desaparecía (jefe 7 %, cazador 11 %).
	-- Desde C7 también los controles de un jugador a otro (además de PlayerControlImmunitySeconds).
	ControlDR = {
		Steps = { 1, 0.8, 0.6, 0.4 },
		ResetSeconds = 6,
	},

	-- Amagos (C8; Combat/Feint, CombatClient/Feint): pulsar la guardia durante la preparación cancela el
	-- golpe de la cadena o la habilidad, sale un humo corto y la guardia se pone como siempre (amagar y
	-- parar es una opción). Si el amago no se puede, la guardia espera a que acabe, como antes.
	Feint = {
		WeaponCooldownSeconds = 1, -- el del golpe es gratis, como mucho uno por esto
		AbilityStaminaCost = 15, -- el de una habilidad cuesta estamina…
		AbilityPenaltySeconds = 1.5, -- …y deja esta recarga en vez de la entera
	},

	-- Preparación de los ataques (C6, C8): lo que se ve venir antes del golpe (Combat/EnemyAttack: "!"
	-- y ojos que brillan; "‼" naranja si no se puede bloquear). Cabe dentro de la recarga de cada ataque,
	-- así que el daño por segundo de los monos no cambia: solo se puede esquivar, apartarse o parar.
	Windup = {
		MonkeyByTier = { 0.4, 0.5, 0.6 } :: { number }, -- mordisco (y piedra) de los monos por categoría (s)
		MonkeyStompSeconds = 0.8, -- pisotón del gorila (imbloqueable)
		BossSeconds = 0.7, -- golpe y agarre de los jefes
		BossChargeSeconds = 0.7, -- embestida de los jefes (imbloqueable)
		-- La animación de ataque empieza esto antes del final de la preparación: lo que tarda en llegar
		-- al golpe (medido en Studio: la cabeza del mandril baja a los ~0,22 s de sus 0,5 s).
		AttackLeadSeconds = 0.2,
		-- Caja del golpe al acabar la preparación, delante de quien pega: de largo su alcance + ReachMargin
		-- (studs), de ancho su alcance × HitWidthFactor y de alto lo mayor de HitHeight y su alcance.
		-- Quien se aparta de ella o se pone detrás de una pared en ese tiempo, no recibe nada.
		ReachMargin = 1.5,
		HitWidthFactor = 1.2,
		HitHeight = 8,
		-- Habilidades sin "castSeconds" propio (C8, Data/Roles). Cada una sale al acabar la suya; si en ese
		-- tiempo te aturden, no sale y no gasta la recarga.
		AbilityDefaultSeconds = 0.2,
	},

	-- Rebote contra muros (C10, Combat/Knockback): un empujón de un jugador (Embestida, Rompehuesos y el
	-- remate de la cadena) que estampa a un mono o a un rival contra una pared, una roca o el terreno le
	-- aturde y le quita un poco de vida. A un jugador, como el control de una habilidad (× el control PvP
	-- del place y sin alargar un aturdido que ya tenga). Los jefes no se empujan.
	WallBang = {
		StunSeconds = 0.5,
		ImmunitySeconds = 1.5, -- después, ningún otro rebote al mismo
		Damage = 5,
		-- Se busca la pared por la trayectoria del empujón (velocidad × segundos) más esto (studs): lo que
		-- separa la raíz de la pared al chocar (el cuerpo; Dash corta el empuje de un jugador a 2,5).
		BodyReach = 2.5,
		-- Al acabar el viaje, la raíz tiene que estar a menos de BodyReach + esto de la pared: si se ha
		-- apartado (Evasivo) o un mono no ha llegado (rozamiento), no rebota.
		ArriveSlack = 1.5,
		-- Desde que debería llegar, se mira durante esto (s) si ya está contra la pared: el servidor ve
		-- moverse a un jugador con retraso (en Studio, con ping ~0, lo ve llegar ~0,2 s tarde).
		ArriveWindowSeconds = 0.5,
		-- Es pared si su normal sube menos que esto (una ladera suave no estampa).
		MaxNormalY = 0.6,
	},

	-- Zonas de peligro (C10, Combat/Zones): lo que dejan unas habilidades en el suelo unos segundos. Solo
	-- afectan a los monos y a los rivales de quien las pone (a un rival, solo donde las habilidades le
	-- ralentizan: CombatRules.pvpStatus). Todos los clientes las ven igual (efecto "Zone").
	--   - Fuego: el Meteoro que cierra "Lluvia de estrellas" (Combo.MeteorBurnTicks y MeteorBurnDamage).
	--   - Hielo: la Nova de hielo deja su radio helado: ralentiza y resbala.
	--   - Nube: la nube del Polvo somnífero se queda: a quien entra le entra sueño (va lento), sin dormirle.
	Zones = {
		TickSeconds = 0.25, -- cada cuánto se mira quién está dentro (hielo y nube)
		LingerSeconds = 0.25, -- lo que dura la lentitud tras salir (además de un tick)
		Height = 5, -- studs por encima y por debajo del suelo que cuentan como "dentro"
		Ice = {
			Seconds = 3,
			SlowFactor = 0.6, -- velocidad que les queda
			-- Al resbalar, la velocidad de un jugador sigue a la que quiere con esta rapidez (1/s): con 3
			-- tarda ~0,3 s en frenar o girar (ZoneController).
			Traction = 3,
		},
		Cloud = {
			Seconds = 3, -- desde que cae; ralentiza con Abilities.PowderSlowFactor (no a los jefes)
		},
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

	-- Movimiento de los cuatro places (Fase 15, V1): lo escribe un único módulo, CombatClient/Movement.
	Movement = {
		-- Velocidad al andar (studs/s) antes de los modificadores (guardia, ralentizar, huevo, bandera…).
		WalkSpeed = 18,
		-- Velocidad al correr (studs/s); correr gasta estamina (Survival.SprintStaminaPerSecond).
		SprintSpeed = 26,
		-- Deslizamiento (Fase 15, V2): solo corriendo, en el suelo; no da invulnerabilidad.
		Slide = {
			-- Velocidad al empezar y al terminar (studs/s); baja en línea recta.
			StartSpeed = 36,
			EndSpeed = 18,
			-- Duración del deslizamiento (s).
			Seconds = 0.75,
			-- Espera hasta el siguiente, contada desde el inicio del anterior (s).
			CooldownSeconds = 1,
			-- Estamina que cuesta (el Lobby no la cobra: regla staminaFree).
			StaminaCost = 15,
			-- Velocidad horizontal real mínima para empezar (studs/s): hay que ir corriendo de verdad.
			MinSpeed = 22,
			-- Salto deslizado: fracción de la velocidad que se conserva en el aire hasta aterrizar.
			JumpKeep = 0.9,
			-- Tope del impulso del salto deslizado (s).
			JumpCarrySeconds = 0.6,
			-- Con hambre o sed bajas (Survival.isWeak), factor de la velocidad de salida y la final.
			WeakFactor = 0.85,
			-- Cuánto baja la cámara en primera persona, solo en el Laboratorio (studs).
			CameraDrop = 1.5,
			-- Lo que tarda la cámara en bajar y en subir (s).
			CameraSeconds = 0.1,
			-- Versión corta, andando (solo con la regla slideFromWalk, el Laboratorio): menos impulso y
			-- menos tiempo, y vale con ir andando (velocidad horizontal mínima MinSpeed, studs/s).
			Walking = {
				StartSpeed = 30,
				EndSpeed = 16,
				Seconds = 0.5,
				MinSpeed = 8,
			},
		},
		-- Líneas blancas de movimiento en pantalla (solo en el Laboratorio, primera persona): al esquivar,
		-- al deslizarse y al correr de verdad. Opacidad máxima de cada causa (0 a 1) y velocidad horizontal
		-- (studs/s) desde la que se corre "rápido".
		SpeedLines = {
			Count = 18,
			DodgeStrength = 1,
			SlideStrength = 0.8,
			SprintStrength = 0.35,
			SprintMinSpeed = 24,
			-- Cada cuántos segundos se recolocan las líneas, y lo que tarda la intensidad en subir y bajar.
			ShuffleSeconds = 0.07,
			FadeSeconds = 0.15,
		},
		-- Esquiva con efecto (Fase 15, V3): la esquiva y el Evasivo (Combat.DodgeSpeed, Evasive.Speed).
		Dodge = {
			-- Al terminar el empuje sigue un segundo empuje a esta fracción de la velocidad...
			CarryKeep = 0.4,
			-- ...que baja en línea recta hasta 0 en estos segundos.
			CarrySeconds = 0.2,
			-- Empujón del campo de visión al esquivar, también en la Embestida (grados).
			FovKick = 6,
			-- Lo que tarda el empujón en volver (s); sube en una cuarta parte de ese tiempo.
			FovKickSeconds = 0.25,
			-- Solo en el Laboratorio: inclinación de la cámara hacia el lado de la esquiva (grados)...
			LabTiltDegrees = 8,
			-- ...y lo que tarda en volver (s).
			LabTiltSeconds = 0.25,
			-- Solo en el Laboratorio: studs que el arma de la vista se aparta al esquivar.
			LabWeaponShift = 0.6,
		},
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
		-- Con un kit de reanimación (Data/Items "ReviveKit", del médico) se gasta uno: se mantiene esto
		-- (0 = al pulsar) y el reanimado vuelve con esta fracción de su vida.
		ReviveKitHoldSeconds = 0,
		ReviveKitHealthFraction = 0.7,
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
		-- Estamina (0 a StaminaMax): correr la gasta y esquivar cuesta DodgeStaminaCost. La lleva el
		-- servidor (Combat/StaminaServer, atributo "Stamina"); el cliente la predice con estos mismos números.
		StaminaMax = 100,
		SprintStaminaPerSecond = 18,
		StaminaRegenPerSecond = 20,
		StaminaRegenDelay = 0.8,
		WeakStaminaRegenFactor = 0.5, -- con hambre o sed por debajo de LowThreshold se recupera a este ritmo
		DodgeStaminaCost = 25,
		-- El cliente se corrige con la del servidor si se separan más de esto (el ritmo de cada uno
		-- difiere un poco: el servidor sabe que corres por el remoto Sprint y por la velocidad real).
		StaminaSyncTolerance = 15,
	},

	Building = {
		-- Cuadrícula (studs): las piezas se colocan en múltiplos de esto y giran de 90 en 90 grados.
		GridSize = 4,
		-- Distancia máxima del jugador al sitio donde construye o derriba.
		Reach = 30,
		-- Núcleo compartido: círculo alrededor del centro del Basecamp donde cualquiera construye.
		CoreRadius = 40,
		-- Parcelas personales (Fase 12): una por jugador (5), a qué distancia del centro y de qué tamaño
		-- (cuadradas, para que quepan las 7 estructuras de la parcela permanente, Config.Plot).
		PlotRingRadius = 62,
		PlotSize = 24,
		-- Ángulo de cada parcela (grados; los 4 portones están en 0, 90, 180 y 270). Tres cuadrantes
		-- tienen una en medio y el cuarto, dos: así ninguna pisa el camino de un portón.
		PlotAngles = { 45, 135, 225, 299, 331 },
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

	Plot = {
		-- Parcela permanente (Fase 12, Shared/Plot): sitio de cada estructura dentro de la parcela, en
		-- studs desde su centro (X a lo ancho; Z hacia la empalizada, así que -Z mira al centro del
		-- Basecamp y al cartel) y su giro en grados. La columna del medio queda libre para entrar.
		Layout = {
			Forge = { x = -8, z = 7.5, yaw = 180 },
			Nest = { x = 0, z = 7.5, yaw = 180 },
			Healer = { x = 8, z = 7.5, yaw = 180 },
			Garden = { x = -8, z = -1.5, yaw = 90 },
			Bed = { x = 8, z = -1.5, yaw = 0 },
			Chest = { x = -8, z = -8.5, yaw = 90 },
			Incubator = { x = 8, z = -8.5, yaw = 270 },
		},
		-- Niveles, costes y efectos de cada estructura: Data/PlotStructures (P3).
		-- Cama: su "restRegen" se suma a la vida que recuperas a menos de esto de ella (studs), sin daño
		-- reciente (Config.Survival.RegenDelayAfterDamage) y aunque tengas hambre o sed.
		RestRadius = 10,
		-- Reparar una estructura rota (cualquiera puede, con su aviso): lo que cuesta. Si no, vuelve sola al
		-- amanecer, con toda la vida.
		RepairCost = { { itemId = "Wood", amount = 10 }, { itemId = "Stone", amount = 6 } },
		RepairHoldSeconds = 2,
		-- Cofre (P4, ChestService): casillas en los niveles I, II y III y cuánto cabe de un objeto en cada
		-- una (100 maderas ocupan 2). Lo privado y lo compartido llenan las mismas casillas.
		ChestSlots = { 6, 12, 20 },
		ChestStack = 50,
		-- Cada cuánto se acepta otra orden del cofre de un jugador (clics rápidos).
		ChestCooldownSeconds = 0.15,
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
		-- Fase 9 (G8): en la Gran Tropa, esta parte de los monos de cada especie de la lista va a por la
		-- baliza (y rompe lo que le cierre el camino); los demás monos la rodean. Le quitan su daño × el
		-- "siegeDamageMultiplier" de la baliza (Data/Buildables). Jugando solo, el día 8, sin nadie que
		-- los pare (medido en Studio): 35–45 de daño por segundo en la 3.ª oleada (mandriles), 95–130
		-- en la 4.ª (+ orangutanes) y unos 200 en la 5.ª (+ gorilas): la baliza (16.000) cae al poco de
		-- llegar la 5.ª; matándolos, aguanta.
		BeaconRaid = {
			Species = { "Mandril", "Orangutan", "Gorila" },
			Share = 0.5,
			SearchRadius = 200,
		},
		-- Antorchas de pie (G8): los monos del asedio que temen al fuego (aulladores) huyen de ellas
		-- ScareSeconds; cada susto le quita ScareWear de vida a la antorcha (120: unos 30 sustos; tres
		-- en un portón frenan ~1 min a los aulladores de la Gran Tropa que entran por él).
		TorchScare = {
			Radius = 10,
			ScareSeconds = 4,
			ScareWear = 4,
		},
		-- Tótem guardián (G8, DefenseService): a Radius studs de él, las piezas reciben PieceReduction
		-- menos daño y de noche, si llevan QuietSeconds sin recibir golpes, recuperan RepairPerSecond de
		-- su vida máxima por segundo; los jugadores reciben PlayerReduction menos daño.
		Totem = {
			Radius = 25,
			PieceReduction = 0.35,
			PlayerReduction = 0.1,
			RepairPerSecond = 0.004,
			QuietSeconds = 6,
		},
	},

	Crafting = {
		-- Atributo que marca una estación colocada a mano en el mapa ("CraftingStation" = "Workbench",
		-- "Campfire"…; ver Data/Stations). Si falta la mesa, se crea una en el Basecamp, desplazada así
		-- respecto a su centro. Si falta la hoguera, se usa el modelo "Hoguera" del mapa o se crea una.
		StationAttribute = "CraftingStation",
		-- Una segunda estación en la misma pieza (la forja III de la parcela también es forja volcánica).
		ExtraStationAttribute = "CraftingStation2",
		DefaultWorkbenchOffset = Vector3.new(-35, 0, 0),
		DefaultCampfireOffset = Vector3.new(0, 0, 0),
		-- Distancia máxima (studs) a una estación para abrirla y fabricar.
		UseDistance = 10,
		CraftCooldownSeconds = 0.4,
		-- Espera entre dos curaciones (vendas, ungüentos, antídotos). Lo que cura cada una: Data/Items.
		BandageCooldownSeconds = 3,
		-- Cataplasma de grupo ("groupHeal" en Data/Items): a quién alcanza y desde cuánta vida perdida
		-- cuenta un aliado como herido (entonces Curar la usa antes que nada).
		PoulticeRadius = 20,
		PoulticeWoundedMissing = 10,
		-- Recetas: ver Shared/Data/Recipes.
	},

	-- Administradores (UserIds): ven el panel "👑 Admin" también en el juego publicado y pueden darle
	-- todo (cosméticos, emotes, mascotas y monturas) a un jugador de su servidor (ServerShared/Admin).
	-- El dueño del juego (chillyduo) lo es siempre, sin estar en la lista.
	Admins = {} :: { number },
	-- Panel de administradores v2 (T4): lo que viaja entre servidores (ServerShared/AdminNet, tema de
	-- MessagingService), el registro de acciones (ServerShared/AdminLog) y el anuncio a todos.
	AdminTools = {
		Topic = "Admin",
		-- Atributo de ReplicatedStorage (JSON) con las acciones de la Isla que están en marcha, para el tablero.
		IslandStateAttribute = "AdminIslandState",
		LogStoreName = "AdminLog_v1",
		-- Acciones que guarda el registro (las más viejas se borran) y cada cuánto se escriben las nuevas
		-- (juntas, para no gastar escrituras del DataStore).
		LogKeep = 200,
		LogFlushSeconds = 10,
		-- Lo que enseña el panel al pedirlo.
		LogShown = 40,
		AnnounceMaxLength = 140,
		AnnounceSeconds = 10,
		-- Moderación (T4c, ServerShared/Moderation): minutos de silencio y horas de baneo que se eligen.
		MuteMinutes = { 5, 15, 60 },
		BanHours = { 1, 24, 168, 720 },
		ReasonMaxLength = 120,
		-- Mantenimiento (T4d): minutos de aviso antes de cerrar, a elegir.
		MaintenanceMinutes = { 1, 5, 10 },
		-- Lista de servidores: cuánto se espera a que respondan.
		ServerListSeconds = 3,
	},
	-- El administrador convertido en jefe gigante en los 4 places (T4e y Fase 18 A3, combat/Services/
	-- GiantAdminService): su personaje crece, pelea con su rol (o su arma en el Laboratorio) y con tres golpes
	-- de jefe con aviso en el suelo, y los que le pegan se llevan el premio al derribarlo. Medido con Equilibrio
	-- (sección 3, jefes): con las armas del día 8 un jugador le quita unos 23 por segundo (las armas pegan entero
	-- a un jugador y las habilidades ×0,5), así que con 4 jugadores (vida ×3,25) cae en unos 2 minutos.
	GiantAdmin = {
		Scale = 2.5,
		BaseHealth = 3600,
		-- Vida × (1 + esto × (jugadores activos − 1)), como los jefes. Activos: vivos, fuera del Basecamp y a
		-- menos de ActiveRange studs del gigante (al menos 1); se recalcula cada RescaleSeconds sin cambiar el %.
		HealthPerExtraPlayer = 0.75,
		ActiveRange = 200,
		RescaleSeconds = 3,
		-- Los golpes (daño contra 100 de vida base; los avisos son imbloqueables y en el Basecamp no
		-- alcanzan). Algo por debajo del pisotón del Gorila de Ceniza (49 + 1,5 s cada 12 s), porque el
		-- gigante además usa su rol.
		Stomp = { radius = 16, damage = 35, stunSeconds = 1, warnSeconds = 1, cooldown = 7 },
		Wave = {
			impacts = 5,
			spacing = 8,
			radius = 6,
			damage = 25,
			warnSeconds = 0.8,
			stepSeconds = 0.12,
			cooldown = 9,
		},
		Roar = { radius = 28, damage = 10, stunSeconds = 1.5, warnSeconds = 1.2, cooldown = 15 },
		-- Premio para los que le han pegado (un intento de golpe en los CreditSeconds antes de perder vida).
		RewardTitle = "TitleGiantSlayer",
		RewardEgg = "Legendary",
		CreditSeconds = 1.5,
	},
	-- Eventos en vivo que lanza un administrador (T4b; catálogo en Data/LiveEvents, servidor en
	-- ServerShared/LiveEventsServer). Son gratis para todos: nada de esto se vende.
	LiveEvents = {
		-- Los de "todos los servidores" se guardan aquí para que un servidor que arranca los vea.
		StoreName = "LiveEvents_v1",
		-- Duraciones y retrasos (minutos) que se eligen en el panel.
		Durations = { 15, 30, 60 },
		Delays = { 0, 5, 15, 30, 60 },
		AmberMultiplier = 2,
		XpMultiplier = 2,
		-- El huevo del nido avanza esto veces más rápido (se le quita tiempo cada EggTickSeconds).
		EggSpeed = 2,
		EggTickSeconds = 60,
		-- Pesos de la rareza de los huevos que aparecen con "Suerte de huevo" (normal: Pets.RarityWeights).
		EggLuckWeights = { Common = 30, Uncommon = 30, Rare = 22, Epic = 13, Legendary = 5 },
		-- Lluvia de huevos del Lobby: huevos por jugador (mínimo EggRainMin) y cada jugador recoge uno.
		EggRainPerPlayer = 2,
		EggRainMin = 6,
		-- Radio de la plaza del Lobby donde caen los huevos y el confeti de la fiesta.
		PlazaRadius = 24,
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
		-- Avisos guardados para la próxima vez que entra (perfil "notices": la compensación de las
		-- mascotas repetidas, un regalo recibido sin estar): segundos tras cargar, para que el cliente
		-- ya escuche.
		NoticeDelaySeconds = 8,
		-- Regalos para quien no estaba en el servidor al llegar el pago (ServerShared/Gifts): se guardan
		-- aparte (clave "g_<userId>") y se entregan al entrar a cualquier place.
		GiftStoreName = "Gifts_v1",
		-- Copias de seguridad de los perfiles (panel de administración, T4d; también las de las pruebas
		-- en Studio): clave "u_<userId>_<etiqueta>_<os.time>".
		BackupStoreName = "PlayerData_v1_backups",
		BackupsShown = 12,
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

	Arena = {
		-- Isla de Dunas: arena PvP de captura la bandera, de 1v1 a 5v5 (docs/GDD.md, "La arena").
		-- Jugadores por equipo: llega del Lobby con el viaje ("format" en TeleportData). En Studio no
		-- hay viaje: se usa StudioFormat (el panel de pruebas lo cambia).
		MinFormat = 1,
		MaxFormat = 5,
		StudioFormat = 1,
		-- Antes de la partida: si todos pulsan "Listo", cuenta atrás; si no, a los WaitSeconds de
		-- llegar el primero arranca igual (si algún equipo está vacío, se cancela y vuelven al Lobby).
		WaitSeconds = 60,
		CountdownSeconds = 10,
		-- Partida: gana quien llegue a CapturesToWin; si se acaba el tiempo, quien tenga más (con
		-- empate, muerte súbita: la siguiente captura gana).
		MatchSeconds = 8 * 60,
		CapturesToWin = 3,
		ResultsSeconds = 20,
		-- Al caer se reaparece en la base tras estos segundos (más si llevaba la bandera).
		RespawnSeconds = 5,
		CarrierRespawnSeconds = 8,
		-- Espectador al caer (Fase 15, V10; CombatClient/SpectateCamera): segundos de killcam sobre quien lo
		-- derribó, distancia de la cámara al aliado que sigue y, sin aliados en pie, la vista fija desde
		-- arriba del centro de la arena (ArenaBuilder la centra en el origen; la zona jugable mide unos 412 × 206).
		KillcamSeconds = 1.5,
		SpectateDistance = 12,
		SpectateOverheadCenter = Vector3.new(0, 0, 0),
		SpectateOverheadHeight = 190,
		-- Banderas (FlagService). Quien lleva la rival anda a esta fracción de su velocidad y no puede
		-- usar Parpadeo ni Embestida. Una bandera en el suelo vuelve sola a su base tras
		-- FlagReturnSeconds (o al momento si la toca alguien de su equipo).
		CarrierSpeedMultiplier = 0.85,
		FlagReturnSeconds = 15,
		-- Distancia (studs) a la que se coge o se devuelve una bandera, y a la que hay que llevar la
		-- rival del pedestal propio para capturarla.
		FlagTouchRadius = 4.5,
		CaptureRadius = 7,
		-- Ámbar al terminar una partida (ArenaRewardService): por resultado, por captura y por baja
		-- (las bajas, con tope por partida), con un tope diario para que la arena no sea la forma más
		-- rápida de conseguir Ámbar. Quien se va antes de acabar no cobra.
		Amber = {
			Win = 60,
			Tie = 30,
			Loss = 20,
			PerCapture = 15,
			PerKill = 2,
			MaxFromKills = 20,
			DailyCap = 400,
		},
		-- La vida se recupera sola tras RegenDelaySeconds sin recibir daño.
		RegenDelaySeconds = 6,
		RegenPerSecond = 4,
		-- En 4v4 y 5v5 (desde SameRoleLimitFromFormat), como mucho MaxSameRole del mismo rol por equipo.
		SameRoleLimitFromFormat = 4,
		MaxSameRole = 2,
		-- Daño de las armas y de las habilidades y duración de los aturdimientos y ralentizaciones
		-- contra otros jugadores. Ajustados (20-10-2026) para que un duelo entre dos roles iguales dure
		-- 8–10 s al 60 % de actividad (calculadora ServerStorage.Tools.Equilibrio, sección "Arena"):
		-- Guerrero 9,4 s, Cazador 8,6 s, Mago 8,7 s (9,8 · 9,1 · 9,3 s desde que las definitivas llevan su
		-- UltimateDamageMultiplier, 22-10-2026). Con las armas ×1 duraban 4,5–6 s.
		WeaponDamageMultiplier = 0.55,
		-- Ajuste de algunas armas sobre WeaponDamageMultiplier (id de Data/Weapons → fracción). El arco
		-- casi todo lo hace con el arma y desde lejos: sin esto, el duelo de cazadores duraba 6 s (con 0,7).
		-- Desde C9 los disparos se pueden esquivar: la calculadora supone que contra jugadores acierta el
		-- arco el 84 %, la cerbatana el 81 %, la honda el 77 % y el bastón (lento) el 74 %, y esto lo
		-- compensa para que los duelos espejo sigan en 9,3 s (cazador) y 9,7 s (mago).
		WeaponMultipliers = { Bow = 0.85, MagicStaff = 1.35, Blowgun = 1.1, Honda = 1.2 } :: { [string]: number },
		AbilityDamageMultiplier = 0.45,
		-- Las definitivas (V), además, esto (22-10-2026): el Pisotón quitaba 84 de 100 de un golpe y el
		-- Rayo encadenado 68; ahora 38 y 30 (límite 40). Los duelos espejo pasan de 8,6–9,4 s a 9,1–9,8 s.
		UltimateDamageMultiplier = 0.45,
		AbilityControlMultiplier = 0.5,
		-- Las curaciones de los jugadores (el médico) en la arena. Con ×1 un médico se curaba 6,3 por
		-- segundo solo y un duelo de médicos duraba 55 s; con ×0,6, 30 s (se tumba en 11–16 s).
		HealingMultiplier = 0.6,
		-- Altar de la cima de la pirámide del centro (Fase 10, C11; AltarService). Se toma quedándose a
		-- menos de CaptureRadius (en horizontal, hasta CaptureHeight por encima de la cima) durante
		-- CaptureSeconds sin rivales: con los dos equipos, la barra se para; sin nadie, se vacía sola en
		-- DecaySeconds; si entra el otro equipo, primero la vacía. Da al equipo BuffSeconds en los que su
		-- definitiva (V) se recarga UltChargeRate veces más rápido: con 30 s y ×2, 30 s menos de espera de
		-- los 90 (una V más cada tres altares). Después se apaga y vuelve RespawnSeconds más tarde; el
		-- primero, FirstSeconds después de empezar la partida. La calculadora lo mide (sección 11).
		Altar = {
			CaptureSeconds = 6,
			CaptureRadius = 7,
			CaptureHeight = 8,
			DecaySeconds = 12,
			BuffSeconds = 30,
			UltChargeRate = 2,
			RespawnSeconds = 75,
			FirstSeconds = 30,
		},
		-- Coberturas que se rompen (Fase 10, C11; CoverService y Combat/Destructibles): las estelas y las
		-- columnas de pie. Tienen Health de piedra; cada golpe que alcanza una le quita lo de Damage según
		-- lo que sea: una habilidad de daño (cada uso, una vez por cobertura), una definitiva, el remate de
		-- la cadena o el disparo de remate. Los golpes normales no. Rota, no tapa ni choca, y vuelve
		-- RespawnSeconds después (si hay alguien dentro, en cuanto se aparta). Un jugador solo tarda
		-- 10–12 s en romper una (el médico, 23 s; sección 11 de la calculadora).
		Covers = {
			Health = 100,
			Damage = { Ability = 25, Ultimate = 100, Finisher = 20, ShotFinisher = 20 },
			RespawnSeconds = 45,
		},
		-- Cola del Lobby (ArenaQueueService, con MemoryStore): cada cuánto se intenta juntar equipos y
		-- se miran las partidas encontradas, cuánto vive un ticket sin renovarse, cuánto dura el candado
		-- del servidor que reparte y cuánto se guarda una partida encontrada hasta que viajan.
		Queue = {
			TickSeconds = 3,
			TicketSeconds = 600,
			LockSeconds = 8,
			MatchSeconds = 120,
		},
		-- Los dos equipos: nombre, icono y color (bases, marcador, nombres sobre la cabeza).
		Teams = {
			Jaguar = { name = "Jaguar", icon = "🐆", color = Color3.fromRGB(240, 150, 40) },
			Quetzal = { name = "Quetzal", icon = "🦜", color = Color3.fromRGB(40, 165, 230) },
		},
	},

	Lab = {
		-- Laboratorio en ruinas (Fase 13, docs/LABORATORIO.md): shooter por equipos sin roles, habilidades,
		-- talentos ni mejoras. Todos con la misma vida, que vuelve sola tras RegenDelaySeconds sin recibir
		-- daño, y una de las cuatro armas de Data/LabWeapons (sus números están allí; la calculadora los
		-- mide en la sección 12, "Laboratorio").
		Health = 100,
		-- Grupo de colisión de los muros invisibles (barreras, barrotes y techos): chocan con los personajes
		-- pero no con los rayos de ShotCollisionGroup.
		WallGroup = "LabMuro",
		RegenDelaySeconds = 4,
		RegenPerSecond = 20, -- de 0 a llena en 5 s: en un shooter rápido, retirarse tiene que valer
		-- Al caer se reaparece a los RespawnSeconds con SpawnProtectionSeconds sin recibir daño (se pierde
		-- al disparar).
		RespawnSeconds = 3,
		SpawnProtectionSeconds = 1.5,
		-- Lanzadardos: cada dardo que acierta ralentiza DartSlowStep más (hasta DartSlowMax) durante
		-- DartSlowSeconds desde el último.
		DartSlowStep = 0.04,
		DartSlowMax = 0.2,
		DartSlowSeconds = 1.5,
		-- Lanzarredes: el impacto enreda (anda a NetSpeedFactor de su velocidad) NetSeconds, y no puede
		-- volver a enredarse hasta NetImmuneSeconds después de empezar.
		NetSpeedFactor = 0.65,
		NetSeconds = 1,
		NetImmuneSeconds = 3,
		-- Cañón de suero: vuela en arco hasta donde apunta, a su "projectileSpeed" en horizontal, subiendo
		-- sobre la línea de tiro AcidArc × la distancia (a 15 studs, 4,5; a 36, 11: pasa por encima de una
		-- cobertura baja), y estalla en AcidRadius. El veneno es el "poison" del arma.
		AcidArc = 0.3,
		AcidRadius = 6,
		AcidPuddleSeconds = 3,
		-- Rifle: campo de visión (grados) mientras se mantiene apuntado.
		RifleZoomFieldOfView = 30,
		-- Cargador y dispersión (Fase 15, V8; Data/LabWeapons, Shared/LabSpread). Velocidad horizontal (studs/s)
		-- desde la que cuenta como "moviéndose" para la dispersión del arma.
		SpreadMovingSpeed = 3,
		-- El contador de balas se pone en rojo claro cuando queda esta fracción del cargador o menos.
		LowAmmoFraction = 0.25,
		-- El anillo de espera de la mira solo sale en armas con una cadencia de al menos estos segundos
		-- (en el lanzadardos, automático, no).
		-- Retroceso del arma en la vista propia, por arma (Fase 15, V9; FirstPersonController): kickBack = studs
		-- que va atrás (el doble con el rifle acercado), kickPitch = grados que levanta la boca, kickRoll =
		-- grados de giro, camKick = grados que sube la cámara (y vuelve), recover = por segundo que se recupera.
		View = {
			LabDartGun = { kickBack = 0.08, kickPitch = 1.5, kickRoll = 0.6, camKick = 0.25, recover = 14 },
			LabBananaRifle = { kickBack = 0.3, kickPitch = 7, kickRoll = 1.2, camKick = 1.6, recover = 7 },
			LabNetHarpoon = { kickBack = 0.35, kickPitch = 8, kickRoll = 2, camKick = 1.8, recover = 7 },
			LabAcidCannon = { kickBack = 0.45, kickPitch = 10, kickRoll = 3, camKick = 2.5, recover = 6 },
		},
		CooldownRingMinSeconds = 0.4,
		-- Muñecos del panel de pruebas (LabDebugService): delante del jugador, a las distancias de la
		-- calculadora (corta, media y larga).
		TestDummyDistances = { 15, 50, 120 },
		-- Los dos bandos (Shared/Arena.configure; el id es también la facción de las armas, "LabFaction"):
		-- nombre, icono y color (marcador, barreras de salida, resultados). Sin verde, morado ni rojo.
		Teams = {
			Pirates = { name = "Piratas", icon = "🏴‍☠️", color = Color3.fromRGB(234, 194, 80) },
			Guardians = { name = "Guardianes", icon = "🥼", color = Color3.fromRGB(40, 115, 215) },
		},
		TeamOrder = { "Pirates", "Guardians" }, -- en el marcador: los piratas (oeste) a la izquierda
		-- Duelo por equipos (L2, docs/LABORATORIO.md §3; LabMatchService). Jugadores por equipo: llega
		-- del Lobby con el viaje ("format" en TeleportData); en Studio, StudioFormat (el panel lo cambia).
		-- Gana el primero en llegar a KillsToWin[formato] bajas, o el que más tenga a los MatchSeconds;
		-- con empate, la siguiente baja gana. Antes, como en Dunas: si todos pulsan "Listo", cuenta
		-- atrás; si no, a los WaitSeconds de llegar el primero.
		StudioFormat = 1,
		-- Modos de la cola, en orden (la clave va en la lista de MemoryStore y en TeleportData "mode"). Los
		-- nombres se traducen al dibujarlos (T(name)): Config no carga Strings.
		Modes = { "TeamDeathmatch", "FreeForAll", "Rounds" },
		ModeNames = { TeamDeathmatch = "Duelo por equipos", FreeForAll = "Todos contra todos", Rounds = "Rondas" },
		-- Formatos que se pueden buscar en la cola de cada modo: jugadores por bando (1v1…5v5) o, en Todos
		-- contra todos, el total de la sala (Shared/LabModes.formatLabel los escribe).
		ModeFormats = { TeamDeathmatch = { 1, 2, 3, 4, 5 }, FreeForAll = { 10 }, Rounds = { 1, 2, 3, 4, 5 } },
		-- Modo de Studio (sin viaje desde el Lobby); el panel de pruebas lo cambia.
		StudioMode = "TeamDeathmatch",
		-- Todos contra todos (L4a, Modes/FreeForAll): jugadores de la sala, mínimo para que siga y bajas
		-- para ganar.
		FreeForAllPlayers = 10,
		FreeForAllMinPlayers = 2,
		FreeForAllKills = 15,
		-- Rondas (Modes/Rounds): rondas para ganar, duración de cada una, segundo de la alarma (todos se ven
		-- con contorno), pausa entre rondas y ronda tras la cual cambian las bases (cada uno sigue en su
		-- bando). MatchSeconds es también el tope de todo el partido.
		RoundsToWin = 4,
		RoundSeconds = 45,
		AlarmAtSeconds = 30,
		RoundIntermissionSeconds = 8,
		SideSwapAfterRound = 3,
		-- Distancia de la cámara del espectador al compañero que sigue (LabSpectateController).
		SpectateDistance = 12,
		-- Segundos de killcam sobre quien lo derribó antes de pasar a los compañeros (V10).
		KillcamSeconds = 1.5,
		KillsToWin = { 10, 15, 20, 25, 30 },
		MatchSeconds = 6 * 60,
		WaitSeconds = 60,
		CountdownSeconds = 10,
		ResultsSeconds = 20,
		-- Hasta qué formato se cierra el paso que cierra el derrumbe de cada mapa (el invernadero del
		-- Laboratorio central, el nivel bajo de la Azotea, el túnel sur de las Alcantarillas; LabWorldService).
		CollapseUpToFormat = 2,
		-- Mapas (L4b; World/LabBuilder construye uno por id, todos a la vez, en Workspace.LabMap.<id>). El
		-- nombre y el alcance se traducen al dibujarlos (T(name)). StudioMap: el de Studio y el del primer
		-- arranque. VoteSeconds: lo que dura la votación de mapa. FallCreditSeconds: una caída cuenta como
		-- baja del último que hirió a la víctima si fue hace tanto o menos. FallDepth: studs bajo el suelo
		-- del mapa a los que se cae al vacío (LabWorldService.fallY).
		Maps = { "Central", "Azotea", "Alcantarillas" },
		MapNames = {
			Central = later("Laboratorio central"),
			Azotea = later("Azotea de la torre"),
			Alcantarillas = later("Alcantarillas"),
		},
		MapRanges = {
			Central = later("Media distancia"),
			Azotea = later("Larga distancia"),
			Alcantarillas = later("Corta distancia"),
		},
		StudioMap = "Central",
		VoteSeconds = 10,
		FallCreditSeconds = 10,
		FallDepth = { Central = 30, Azotea = 25, Alcantarillas = 30 },
		-- Arma de quien aún no ha elegido (id de Data/LabWeapons).
		DefaultWeapon = "LabDartGun",
		-- Recompensas de la partida (LabRewardService). Places = Ámbar por puesto 1.º, 2.º y 3.º en Todos
		-- contra todos; Rest = el resto de puestos. Tope diario propio, aparte del de Dunas.
		Amber = {
			Win = 45,
			Tie = 25,
			Loss = 15,
			Places = { 45, 30, 30 },
			Rest = 15,
			PerKill = 1,
			MaxFromKills = 15,
			DailyCap = 300,
		},
		-- Títulos ganados con WinsForTitle victorias con ese bando (Data/Cosmetics).
		Titles = { Pirates = "TitleLabPirate", Guardians = "TitleLabGuardian" },
		WinsForTitle = 50,
		-- Skins de arma por bajas (L5b, Data/Cosmetics "LabKills"): bajas con esa arma para el grado I, II y
		-- III (índice = grado). Solo se ganan jugando (LabRewardService).
		SkinKills = { 50, 250, 1000 },
	},

	Supply = {
		-- Cajas de suministro (Fase 5): llegan a una playa cada IntervalSeconds de día si no hay otra.
		IntervalSeconds = 300,
		FirstDelaySeconds = 120,
		OpenHoldSeconds = 5,
		ItemsPerCrate = 3,
		-- Siempre todo esto…
		Always = {
			{ itemId = "ShipMetal", min = 2, max = 2 },
		},
		-- …y ItemsPerCrate tiradas de este botín: { itemId, mín, máx, peso }.
		Loot = {
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

		-- Huevos guardados (bucle de retención, octubre de 2026; Shared/EggIncubation, ServerShared/Eggs).
		-- Al defender el huevo, cada participante se lleva uno de su rareza a la mochila (BagSize; los que
		-- no caben quedan pendientes hasta decidir en el Lobby). Solo el del nido del Lobby avanza con
		-- las horas reales y tarda HatchHours según su rareza.
		HatchHours = { Common = 8, Uncommon = 11, Rare = 14, Epic = 18, Legendary = 24 },
		BagSize = 3,
		-- Ámbar por descartar un huevo, según su rareza.
		DiscardAmber = { Common = 15, Uncommon = 30, Rare = 60, Epic = 120, Legendary = 250 },
		-- Ámbar de una mascota que ya se tiene al abrir el huevo (se tiene una de cada; 26-10-2026): el
		-- doble del descarte, para que esperar las horas del nido compense. También compensa, una vez,
		-- las copias que había antes de la versión 9 del perfil (ServerShared/PlayerData). Mítico: el
		-- Quetzalcóatl repetido de la tirada de pioneros (Config.Pioneer).
		DuplicateAmber = { Common = 30, Uncommon = 60, Rare = 120, Epic = 240, Legendary = 500, Mythic = 1000 },
		-- Lo que se gana jugando (días sobrevividos, misiones, tirada del rescate) quita como mucho esta
		-- fracción del tiempo total del huevo. El tiempo del calendario y la eclosión inmediata no cuentan.
		PlayCapFraction = 0.5,
		SecondsPerDaySurvived = 60 * 60,
		-- Tirada al ganar una partida (rescate) con un huevo en el nido: horas que quita o eclosión inmediata.
		RescueRoll = {
			{ weight = 40, hours = 2, hatch = false },
			{ weight = 30, hours = 4, hatch = false },
			{ weight = 20, hours = 6, hatch = false },
			{ weight = 8, hours = 10, hatch = false },
			{ weight = 2, hours = 0, hatch = true },
		},
	},

	-- Luz del día y de la noche en la Isla (Fase 18, B1). La curva da, para cada hora del reloj de Roblox
	-- (0-24, circular), los valores base de la luz; LightingController interpola entre las filas. El clima, la
	-- erupción y (B3) la luna roja se suman encima con sus propios efectos, sin tocar esta curva. Los pesos de
	-- la luna (B2) se enganchan en LightingController.adjust.
	Lighting = {
		-- El reloj avanza a la misma velocidad de día y de noche (antes iba más lento de día: 12 h en 10 min
		-- y 12 h en 7 min). La mitad del día cae en DayCenterClock; el día dura 24 * Day / (Day + Night) horas.
		DayCenterClock = 12.2,
		-- Cada fila: h = hora del reloj. Ambient/OutdoorAmbient/ColorShift/AtmColor/AtmDecay/GradeTint son Color3
		-- (r, g, b de 0 a 255); el resto, números. Grade* es el ColorCorrection base; Exposure es ExposureCompensation.
		Keyframes = {
			-- Noche: azul legible, con la luna como luz.
			{
				h = 4.0,
				Ambient = { 55, 68, 105 },
				OutdoorAmbient = { 70, 90, 135 },
				Brightness = 1.2,
				ColorShift = { 0, 0, 0 },
				AtmColor = { 90, 110, 160 },
				AtmDecay = { 40, 50, 90 },
				AtmDensity = 0.3,
				AtmHaze = 0.5,
				GradeBrightness = 0.02,
				GradeContrast = 0.05,
				GradeSaturation = -0.05,
				GradeTint = { 215, 225, 255 },
				Exposure = 0.25,
			},
			-- Antes del amanecer.
			{
				h = 5.0,
				Ambient = { 70, 70, 105 },
				OutdoorAmbient = { 95, 90, 125 },
				Brightness = 1.4,
				ColorShift = { 120, 110, 170 },
				AtmColor = { 150, 140, 180 },
				AtmDecay = { 120, 100, 140 },
				AtmDensity = 0.32,
				AtmHaze = 1.2,
				GradeBrightness = 0.02,
				GradeContrast = 0.05,
				GradeSaturation = 0,
				GradeTint = { 235, 235, 255 },
				Exposure = 0.2,
			},
			-- Amanecer.
			{
				h = 5.9,
				Ambient = { 110, 85, 90 },
				OutdoorAmbient = { 170, 115, 100 },
				Brightness = 2.0,
				ColorShift = { 255, 170, 110 },
				AtmColor = { 240, 170, 140 },
				AtmDecay = { 230, 140, 100 },
				AtmDensity = 0.36,
				AtmHaze = 1.6,
				GradeBrightness = 0,
				GradeContrast = 0.05,
				GradeSaturation = 0.08,
				GradeTint = { 255, 235, 215 },
				Exposure = 0,
			},
			-- Mañana.
			{
				h = 7.2,
				Ambient = { 80, 78, 78 },
				OutdoorAmbient = { 125, 125, 130 },
				Brightness = 2.8,
				ColorShift = { 255, 235, 210 },
				AtmColor = { 200, 200, 205 },
				AtmDecay = { 106, 112, 125 },
				AtmDensity = 0.3,
				AtmHaze = 0.3,
				GradeBrightness = 0,
				GradeContrast = 0,
				GradeSaturation = 0,
				GradeTint = { 255, 255, 255 },
				Exposure = 0,
			},
			-- Mediodía: lo que había antes de la curva.
			{
				h = 12.0,
				Ambient = { 70, 70, 70 },
				OutdoorAmbient = { 70, 70, 70 },
				Brightness = 3.0,
				ColorShift = { 0, 0, 0 },
				AtmColor = { 199, 199, 199 },
				AtmDecay = { 106, 112, 125 },
				AtmDensity = 0.3,
				AtmHaze = 0,
				GradeBrightness = 0,
				GradeContrast = 0,
				GradeSaturation = 0,
				GradeTint = { 255, 255, 255 },
				Exposure = 0,
			},
			-- Tarde.
			{
				h = 16.4,
				Ambient = { 80, 76, 74 },
				OutdoorAmbient = { 120, 112, 105 },
				Brightness = 2.8,
				ColorShift = { 255, 235, 205 },
				AtmColor = { 205, 198, 190 },
				AtmDecay = { 120, 115, 120 },
				AtmDensity = 0.3,
				AtmHaze = 0.4,
				GradeBrightness = 0,
				GradeContrast = 0,
				GradeSaturation = 0.03,
				GradeTint = { 255, 248, 235 },
				Exposure = 0,
			},
			-- Atardecer.
			{
				h = 17.5,
				Ambient = { 110, 80, 85 },
				OutdoorAmbient = { 175, 110, 95 },
				Brightness = 2.0,
				ColorShift = { 255, 160, 100 },
				AtmColor = { 240, 160, 120 },
				AtmDecay = { 230, 120, 80 },
				AtmDensity = 0.36,
				AtmHaze = 1.8,
				GradeBrightness = 0,
				GradeContrast = 0.05,
				GradeSaturation = 0.1,
				GradeTint = { 255, 225, 200 },
				Exposure = 0,
			},
			-- Anochecer.
			{
				h = 18.5,
				Ambient = { 75, 65, 100 },
				OutdoorAmbient = { 105, 90, 135 },
				Brightness = 1.4,
				ColorShift = { 150, 110, 170 },
				AtmColor = { 150, 120, 170 },
				AtmDecay = { 120, 80, 130 },
				AtmDensity = 0.34,
				AtmHaze = 1.2,
				GradeBrightness = 0.01,
				GradeContrast = 0.05,
				GradeSaturation = 0,
				GradeTint = { 235, 230, 255 },
				Exposure = 0.15,
			},
			-- Noche cerrada.
			{
				h = 19.5,
				Ambient = { 55, 68, 105 },
				OutdoorAmbient = { 70, 90, 135 },
				Brightness = 1.2,
				ColorShift = { 0, 0, 0 },
				AtmColor = { 90, 110, 160 },
				AtmDecay = { 40, 50, 90 },
				AtmDensity = 0.3,
				AtmHaze = 0.5,
				GradeBrightness = 0.02,
				GradeContrast = 0.05,
				GradeSaturation = -0.05,
				GradeTint = { 215, 225, 255 },
				Exposure = 0.25,
			},
		},
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

	Daily = {
		-- Bucle de retención (octubre de 2026; Shared/Daily, ServerShared/Retention). El día cambia a las
		-- 00:00 UTC más este desfase (en segundos) para todos los servidores.
		ResetOffsetSeconds = 0,
		-- Calendario de 7 días: basta con entrar al Lobby para cobrar el de hoy. Faltar un día no lo
		-- reinicia: al volver se cobra el siguiente. Tras el 7 vuelve al 1. Cada premio puede llevar
		-- Ámbar ("amber"), provisiones para la próxima partida ("items", ServerShared/Supplies), tiempo
		-- que se quita al huevo del nido sin tope ("eggSeconds") y un huevo ("egg": pesos de rareza).
		Calendar = {
			{ amber = 100, items = { Banana = 5 } },
			{ items = { Torch = 1, Fiber = 10 } },
			{ items = { Bandage = 2 }, eggSeconds = 60 * 60 },
			{ amber = 100, items = { Antidote = 2 } },
			{ amber = 250 },
			{ items = { ReviveKit = 1, SuperBandage = 2 }, eggSeconds = 2 * 60 * 60 },
			{ amber = 500, egg = { Rare = 13, Epic = 6, Legendary = 1 } },
		} :: { Reward },
		-- Si al cobrar tiempo de huevo no hay ninguno en el nido, se da Ámbar por cada hora.
		AmberPerUnusedEggHour = 30,
		-- Misiones (Data/Missions, misiones v2 de la Fase 9): cada día una de cada dificultad, en este
		-- orden (la "Media" es la del rol elegido), y cada semana WeeklyMissions semanales (cambian el
		-- lunes a las 00:00 UTC más ResetOffsetSeconds). Cambios gratis: DailyRerolls al día (en las
		-- diarias) y WeeklyRerolls a la semana (en las semanales); el cambio da otra de la misma clase.
		Difficulties = { "Facil", "Media", "Dificil" },
		WeeklyMissions = 5,
		DailyRerolls = 1,
		WeeklyRerolls = 1,
		-- Premio de cada misión por su clase ("xp" es la del pase; el tiempo de huevo cuenta para el
		-- tope de lo ganado jugando) y el extra por cumplir todas las semanales.
		MissionRewards = {
			Facil = { amber = 40, eggSeconds = 15 * 60, xp = 200 },
			Media = { amber = 70, eggSeconds = 25 * 60, xp = 200 },
			Dificil = { amber = 120, eggSeconds = 40 * 60, xp = 300 },
			Semanal = { amber = 150, xp = 500 },
		} :: { [string]: Reward },
		WeeklyBonus = { amber = 250, eggSeconds = 60 * 60, xp = 500 } :: Reward,
		-- Cada cuánto se apunta en el perfil lo que avanzan las misiones en la Isla y en Dunas.
		MissionFlushSeconds = 3,
	},

	-- Contratos de expedición (Fase 9, G6; Data/Contracts, ContractService): uno por partida, del grupo
	-- entero. Cada paso se abre en su día y se pierde si llega el día del siguiente sin cumplirlo.
	Contracts = {
		-- Premio de cada paso por su orden (1–5) para todos los que están en la partida al cumplirlo:
		-- Ámbar y XP del pase (cuenta como de partida: con el tope del día y el extra de amigos). Lo de la
		-- partida (vendas, antorchas…) lo pone cada paso en Data/Contracts.
		StepRewards = {
			{ amber = 20, xp = 50 },
			{ amber = 20, xp = 50 },
			{ amber = 25, xp = 75 },
			{ amber = 25, xp = 75 },
			{ amber = 50, xp = 125 },
		} :: { Reward },
		-- Los objetivos con "scales" crecen con el grupo: ×(1 + TargetPerExtraPlayer × (jugadores − 1)).
		TargetPerExtraPlayer = 0.5,
		-- Pasos "Visit": llegar a menos de esto de la guarida del bioma (Mapa/GuaridasJefes).
		VisitRadius = 45,
		CheckSeconds = 1,
	},

	-- Eventos de mitad de partida (Fase 9, G7; Data/MidEvents, MidEventService).
	MidEvents = {
		-- Los de día empiezan esto después del amanecer.
		DayStartDelaySeconds = 25,
		ToxicRain = {
			DurationSeconds = 6 * 60,
			-- Fiebre por cada trago de agua del río (un trago quita 25 de sed).
			WaterFever = 10,
			-- Los mordiscos suben la fiebre esto de veces más (Config.Fever.PerHealthBar).
			BiteFeverMultiplier = 2,
			-- Antídotos para cada médico al empezar (los objetos no se pasan: al grupo lo cura su Ungüento).
			MedicAntidotes = 2,
			-- El Ungüento en área del médico baja la fiebre esto a cada uno que cura (sin remate).
			SalveFeverCure = 15,
		},
		Saboteurs = {
			-- Macacos saboteadores en cada oleada: esta parte del tamaño de la oleada (como poco 2). La
			-- noche 5 con 5 jugadores, 6 por oleada; jugando solo, 5.
			ShareOfWave = 0.35,
			MinPerWave = 2,
			Species = "Macaco",
			-- Buscan pieza a esta distancia (desde el portón cubre todo el Basecamp) y le pegan su daño
			-- por esto (no el ×3 de Config.Siege.StructureDamageMultiplier): la noche 5, ~15 por segundo
			-- cada uno, así uno solo tarda ~30 s en un muro de piedra y ~20 s en el taller del curandero.
			-- Las estacas las desarman como siempre (Config.Siege.SpikeDisarmPerHit).
			SearchRadius = 140,
			DamageMultiplier = 1.5,
			-- Piezas a las que van (Data/Buildables): trampas, muros y barricadas, y las estaciones del
			-- núcleo con el nido y el tótem (G8). La baliza y las camas, no.
			Targets = {
				"Spikes",
				"WoodWall",
				"StoneWall",
				"GateBarricade",
				"HealerTent",
				"StoneForge",
				"VolcanicForge",
				"Nest",
				"WarTotem",
			},
		},
		Eruption = {
			DurationSeconds = 150,
			-- Zonas altas: terreno por encima de esta altura (el 10 % más alto: volcán y montañas).
			HighGroundY = 55,
			PyroclastEverySeconds = 1,
			-- Como las bombas de lava de la erupción (Config.Weather.LavaBombDamage); el golpe de un mono
			-- del día 1 llega a 40.
			PyroclastDamage = 22,
			PyroclastRadius = 7,
			-- Parte de los piroclastos que va a por un jugador que esté en una zona alta: uno cada ~5 s,
			-- así se puede abrir una caja militar (8 s) en plena erupción esquivando o aguantando 1–2.
			AimAtPlayerChance = 0.2,
			Crates = 2,
		},
	},

	-- Cajas militares de la erupción preliminar (G7; SupplyService). Más tiempo para abrirlas y un PvP
	-- más largo que la caja de suministro; la guardan babuinos.
	MilitaryCrate = {
		OpenHoldSeconds = 8,
		PvPSeconds = 240,
		Guards = { species = "Babuino", count = 2 },
		-- Siempre todo esto…
		Loot = {
			{ itemId = "ShipMetal", min = 2, max = 2 },
			{ itemId = "Obsidian", min = 4, max = 6 },
			{ itemId = "SuperBandage", min = 2, max = 2 },
			{ itemId = "Antidote", min = 1, max = 1 },
			{ itemId = "CookedMeat", min = 3, max = 3 },
		},
		-- …y una esquirla de jefe al azar (el tesoro que pide el nivel 3 o el 4 del equipo).
		Shards = { "ChieftainCrown", "CaveCrystal" },
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
		-- Las de rastreo resaltan a su dueño los monos a menos de TrackRadius studs cada TrackSeconds
		-- (UI/PetFollowers; el panel de Ajustes enseña los mismos números).
		TrackSeconds = 5,
		TrackRadius = 60,
		-- Las que olfatean (el beagle), al mismo ritmo, señalan el huevo misterioso si está en el suelo
		-- a menos de EggSniffRadius studs: unas huellas hacia él y su distancia encima (UI/PetFollowers).
		EggSniffRadius = 300,
		-- Las que marcan (el pointer) marcan en cada tick al mono más cercano a su dueño (dentro de
		-- AttackRange) durante MarkSeconds: todo el que le pega hace MarkBonus más de daño (los jefes se
		-- resisten: × MarkBossMultiplier). No rebajan una marca mayor ("Marcar presas" del cazador).
		MarkBonus = 0.15,
		MarkSeconds = 3,
		MarkBossMultiplier = 0.5,
	},

	Mounts = {
		-- Monturas (Fase 11; Data/Mounts, ServerShared/MountServer, UI/MountRiders): viaje rápido en el
		-- Lobby y en la Isla. Montado se va a Speed × "speed" de la montura (correr a pie son 24) sin
		-- gastar estamina, y no se pelea (Shared/CombatState): recibir daño, cargar el huevo o caer te
		-- bajan.
		Speed = 30,
		-- Espera entre montar y volver a montar, y desde el último daño recibido para poder montar.
		RemountCooldown = 2,
		HurtCooldown = 4,
		-- Gesto montado (escupir, rugir; sin daño, Fase 11 M3): espera entre uno y el siguiente.
		GestureCooldown = 3,
		-- Al abrir un huevo de una rareza que tenga monturas que aún no tienes, probabilidad de que salga
		-- una de ellas en vez de una mascota (Shared/PetRoll.rollMount; medido con la calculadora Economia).
		-- Con 0,5 el habitual (5 días por semana, 1 h) la tiene al 50 % el día 17 y al 74 % el 30.
		EggChance = 0.5,
		-- Velocidad del jinete (studs/s) a la que la montura empieza a galopar y a la que galopa del todo.
		RunFrom = 6,
		RunFull = 14,
		-- Planeo de las monturas que planean (Data/Mounts "glide"; UI/MountRiders): al caer con el suelo a
		-- más de MinHeight studs bajo la montura, empieza a planear sola y baja a FallSpeed studs/s como
		-- mucho (desde 40 studs, unos 5 s y unos 170 studs de avance montado). Nunca sube. Deja de planear
		-- con el suelo (o el agua) a menos de Landing studs.
		Glide = { MinHeight = 8, FallSpeed = 8, Landing = 1.5 },
	},

	Pioneer = {
		-- Bienvenida de pioneros (T6, 27-10-2026; Shared/Pioneer, ServerShared/Retention). Es pionero
		-- quien entra antes de que acabe la primera temporada del pase (Data/Seasons): queda marcado para
		-- siempre. Al cobrar el día 7 del calendario (cada ciclo, se repite) tiene una tirada de montura
		-- con estos pesos (PetRoll.rollPioneer). No evita las que ya tiene: una repetida da
		-- Config.Egg.DuplicateAmber de su rareza. Medido con Economia (§5b): quien entra a diario tiene
		-- las 3 al 50 % hacia el día 84 (12 ciclos), el habitual hacia el 118 y el casual hacia el 196.
		Weights = { Llama = 75, Jaguar = 18, Quetzalcoatl = 7 },
		-- La ventana de bienvenida sale al entrar al Lobby si hay premio que cobrar o si hace al menos
		-- esto desde la última vez (volver de una partida corta no la vuelve a enseñar).
		WelcomeGapMinutes = 60,
	},

	Abilities = {
		-- Habilidades de los roles (Fase 3; nombres y tiempos de espera en Shared/Data/Roles).
		-- Los daños se multiplican por la ventaja de daño del rol (MeleeDamage, RangedDamage o
		-- SpellDamage) y los de cada talento (Data/Perks).
		-- Contra otros jugadores (PvP activo) hacen este daño y los aturdimientos duran esto.
		PvPDamageMultiplier = 0.5,
		PvPControlMultiplier = 0.5,
		-- Las definitivas (V), además, esto contra jugadores: ningún golpe de una habilidad pasa de 40 de
		-- 100 (el Pisotón quitaba 94 y el Rayo encadenado 75 de un golpe; ahora 37 y 30).
		PvPUltimateMultiplier = 0.4,
		-- La protección del Grito de guerra contra el daño de otros jugadores es esta fracción de la suya
		-- (−40 % → −15 %; contra monos, entera). Con toda, el duelo de guerreros de la arena duraba 10,4 s
		-- (12,6 s con defensa; C13).
		PvPWarCryMultiplier = 0.375,
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
		ChargeKnockback = 45, -- studs/s del empujón a lo que golpea…
		ChargeKnockbackSeconds = 0.2, -- …y lo que dura en un jugador (a los monos, un solo impulso)
		WarCryRadius = 40,
		WarCrySeconds = 4, -- provoca y protege (con 12 s de recarga, un tercio del tiempo)
		QuakeDamage = 150,
		QuakeRadius = 16,
		-- Salto del gorila (la otra definitiva, T7): daño a uno frente al área del Pisotón. Inmoviliza al que
		-- cae lo que diga la ventaja "QuakeStun" (el talento Réplica sirve para las dos).
		LeapDamage = 330, -- al enemigo sobre el que cae
		LeapSplashDamage = 60, -- a los demás del radio
		LeapSplashRadius = 10,
		LeapRange = 40, -- hasta dónde salta (studs)
		LeapFlightSeconds = 0.5, -- lo que dura el salto: su sombra en el suelo avisa dónde cae
		LeapAimDegrees = 30, -- cono en el que busca a quién caerle; si no hay nadie, cae donde apuntas
		SmashDamage = 24, -- Rompehuesos, a cada mono del cono de delante
		SmashRange = 9,
		SmashAngle = 100, -- grados del cono (enlazado como remate, golpea alrededor)
		SmashStun = 0.5, -- los tumba un momento (corto: el control del equipo sobre los jefes)
		SmashKnockback = 30, -- studs/s del empujón hacia fuera (C10: contra un muro, rebote)…
		SmashKnockbackSeconds = 0.15, -- …durante este tiempo (unos 4,5 studs; a los jefes, no)

		-- Cazador.
		MultiShotDamage = 7, -- por proyectil
		MultiShotSpreadDegrees = 40,
		MultiShotRange = 100,
		MultiShotSpeed = 200, -- studs/s
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
		-- Disparo certero (la otra definitiva, T7): un proyectil a uno; el talento Diluvio también lo sube.
		-- Con 320 y talentos al máximo el combo del cazador pasaba del +35 %.
		TrueShotDamage = 300,
		TrueShotSpeed = 300, -- studs/s
		TrueShotRange = 150,
		PierceDamage = 17, -- Flecha perforante, a cada mono que atraviesa (16 hasta C9: ahora se puede esquivar)
		PierceRange = 90,
		PierceWidth = 1.5, -- radio de la línea que atraviesa
		PierceSpeed = 220, -- studs/s

		-- Mago.
		FireballDamage = 29, -- al que recibe el impacto (27 hasta C9: ahora se puede esquivar)
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
		-- Haz volcánico (la otra definitiva, T7): canalizado sobre uno. Cada salto de más del talento
		-- Tormenta ("ChainJumps" por encima de 4) es un golpe más (BeamSeconds ÷ BeamTicks más largo).
		BeamDamage = 30, -- por golpe
		BeamTicks = 8,
		BeamSeconds = 2,
		BeamRange = 60, -- alcance hasta el enemigo al empezar…
		BeamLeash = 75, -- …y si se aleja más, se corta
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
		-- Resurgir (la otra definitiva, T7): de golpe lo que el tótem en 8 s, y quita estados.
		SurgeHeal = 50, -- a cada aliado del radio (y al médico)
		SurgeRadius = 18,
		PowderDamage = 8, -- Polvo somnífero, a cada mono de la nube
		PowderRadius = 9,
		PowderMaxDistance = 40, -- la nube cae donde apuntas, como mucho a esta distancia
		PowderDrowsySeconds = 1, -- primero les entra sueño (van lentos)…
		PowderSlowFactor = 0.5, -- …a esta velocidad, y luego se duermen (Data/Perks "PowderSleep")
	},

	Party = {
		-- Grupos del Lobby (Fase 3): tamaño máximo (el de una partida de la Isla, Match.MaxPlayers) y
		-- segundos que vale una invitación.
		MaxSize = 5,
		InviteSeconds = 60,
	},

	Performance = {
		-- Cada cuántos segundos escribe PerformanceService su resumen en la Salida.
		LogSeconds = 120,
		-- Cada cuántos segundos mide Performance (pestaña Rendimiento del panel de administradores).
		SampleSeconds = 5,
		-- Instancias que recorre por fotograma al contar piezas, para no dar tirones.
		CountChunk = 2000,
	},

	Cosmetics = {
		-- En Studio, los cosméticos de Robux aún sin id (0, "Próximamente") se pueden probar gratis.
		FreeInStudio = true,
		-- Huecos de la rueda de emotes (Shared/CosmeticSlots).
		EmoteSlots = 6,
		-- Lo que sale en la rueda (UI/EmoteWheel) si no tienes ningún emote puesto: los de serie.
		DefaultEmotes = { "EmoteWave", "EmotePoint", "EmoteCheer", "EmoteLaugh", "EmoteDance" },
		-- Segundos sin perder vida antes de poder hacer un emote (fuera de combate).
		EmoteCombatSeconds = 5,
	},

	-- Tiendas de cosméticos del Lobby (Fase 9, G10; Shared/CosmeticShop): en Ámbar, los que tienen
	-- "source.amber" (Data/Cosmetics), AmberSlots cada día; en Robux, los sueltos con "source.productId",
	-- RobuxSlots cada semana (el lunes); los Game Passes, siempre. Cada jugador ve los primeros de la
	-- rotación que aún no tiene. Los precios los mira la calculadora (fuera de estos rangos, alerta; los
	-- míticos de Robux van aparte).
	CosmeticShop = {
		AmberSlots = 4,
		RobuxSlots = 3,
		AmberPrices = { 400, 1500 },
		RobuxPrices = { 75, 250 },
	},

	-- Pase de temporada (Fase 9; plan en docs/PLAN.md). La premium es solo cosmética: el Ámbar, el
	-- tiempo de huevo y las provisiones salen de la pista gratis y solo por nivel ganado jugando.
	-- Los números los mide la calculadora (ServerStorage.Tools.Economia, skill economia-retencion).
	-- Temporadas y premios: Data/Seasons; lógica: Shared/SeasonPass y ServerShared/SeasonPass.
	Season = {
		-- Días que dura cada temporada (desde "startsAt" de Data/Seasons).
		Days = 30,
		Levels = 30,
		LevelXp = 1000,
		-- Después del último nivel: un nivel "en bucle" cada LoopXp ganada jugando, con estos premios
		-- por turnos (pista gratis; el tiempo de huevo cuenta para el tope de lo ganado jugando).
		LoopXp = 1500,
		LoopRewards = { { amber = 50 }, { eggSeconds = 15 * 60 } } :: { Reward },
		-- Multiplicador de XP los últimos LastWeekDays días de la temporada.
		LastWeekMultiplier = 2,
		LastWeekDays = 7,
		-- Días sin temporada entre una y la siguiente (no se gana XP).
		RestDays = 7,
		-- Tope de XP al día de las partidas (Isla, Dunas y Laboratorio); las misiones no cuentan en él.
		DailyMatchXpCap = 1200,
		-- Extra por jugar con amigos (fuera del tope): si en el servidor hay algún amigo de Roblox.
		FriendsBonus = 0.1,
		-- XP de una partida en la Isla (MatchService, al terminar) y en Dunas (ArenaRewardService; las
		-- de prueba no dan nada). Las misiones llevan la suya en su premio (Data/Missions, "xp").
		IslandXp = { PerDay = 60, PerBoss = 150, PerEgg = 50, Rescue = 300 },
		ArenaXp = { Win = 80, Tie = 40, Loss = 30, PerCapture = 15 },
		-- XP de una partida en el Laboratorio (LabRewardService; en Todos contra todos: 1.º Win, 2.º y 3.º Tie).
		LabXp = { Win = 60, Tie = 30, Loss = 20 },
	},

	-- Compras con Robux (Fase 9). Los Developer Products los entrega ServerShared/Purchases con su
	-- recibo apuntado en el perfil. "productId" a 0 = "Próximamente" (créalos en el Creator Hub y pon
	-- aquí su id; docs/LANZAMIENTO.md); "price" es solo lo que se enseña. "grants" dice qué dan
	-- (la calculadora comprueba que solo sea el pase o un cosmético).
	Shop = {
		-- Recibos que recuerda cada perfil para no entregar dos veces la misma compra.
		ReceiptHistory = 50,
		-- Mientras la ventana de compra de Roblox está abierta no se abre otra (ServerShared/Purchases);
		-- pasado este tiempo sin respuesta de Roblox, se da por cerrada.
		PromptTimeoutSeconds = 60,
		Products = {
			SeasonPremium = { productId = 3721002705, price = 399, grants = "Premium" },
			-- El pase y 10 niveles; solo si aún no se tiene la premium de la temporada.
			SeasonPack = { productId = 3721002880, price = 799, grants = "Premium", levels = 10 },
			-- Un nivel; no se vende en el último nivel ni en los días de descanso.
			SeasonLevel = { productId = 3721003016, price = 79, grants = "Levels", levels = 1 },
		},
		-- Regalos (T3, 26-10-2026; ServerShared/Gifts): un producto por precio de los cosméticos de Robux
		-- sueltos (Data/Cosmetics "source.price"). El servidor apunta qué cosmético y a quién antes de
		-- abrir la compra. Solo cosméticos.
		GiftProducts = {
			Gift99 = { productId = 3722761253, price = 99, grants = "Cosmetic" },
			Gift149 = { productId = 3722761421, price = 149, grants = "Cosmetic" },
			Gift199 = { productId = 3722761555, price = 199, grants = "Cosmetic" },
			Gift249 = { productId = 3722761715, price = 249, grants = "Cosmetic" },
			Gift449 = { productId = 3722761838, price = 449, grants = "Cosmetic" },
		},
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
		-- Cartel de las mascotas (lo dibuja PetBoardController en cada cliente: el huevo de su nido) y
		-- el de la Isla de dunas (ArenaBoardController: tu estado en la arena y la cola).
		PetsBoardTag = "TablaMascotas",
		ArenaBoardTag = "TablaArena",
		-- Cartel del Laboratorio en ruinas (LabBoardController: la cola por formato).
		LabBoardTag = "TablaLab",
		-- Cartel del pase de temporada (PassBoardController: la temporada, tu nivel y tus premios).
		PassBoardTag = "TablaPase",
		-- Nido de huevos (World/LobbyBuilder): cada cliente dibuja en él su huevo (NestController).
		NestTag = "NidoLobby",
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

	-- Presupuesto de piezas y rendimiento (Fase 16). Los mide la calculadora ServerStorage.Tools.Rendimiento.
	-- Se ajustan tras probar en un teléfono de gama baja (R7).
	Budgets = {
		-- Piezas reales por tipo de modelo, contadas DESPUÉS de fusionar (Shared/VoxelMerge).
		Models = {
			ForgeWeaponLevel4 = 90, -- arma de la forja, nivel 4
			WeaponSkinMythic = 165, -- skin mítica de arma, nivel 4
			ArmorRank = { 80, 115, 150, 210 }, -- armadura por rango I a IV
			OutfitMythicGrade4 = 570, -- traje mítico, grado 4
			PetTotal = 240, -- mascota entera
			PetAnimated = 110, -- piezas de la mascota que se mueven cada fotograma
			MountRare = 260,
			MountLegendary = 375,
			MountMythic = 410,
			Aura = 30, -- aura cosmética
			LabWeaponBase = 45, -- arma del Laboratorio sin skin
			LabWeaponSkin3 = 200, -- arma del Laboratorio con una skin de bajas (hoy el Arpón de red III llega a 99)
			Buildable = 25, -- construible de la Isla
			PlotStructure = { 60, 90, 120 }, -- estructura de la parcela, nivel I a III
			Monkey = 10, -- mono en juego (ya unido con UnionAsync)
			Boss = 30, -- jefe en juego (ya unido)
			MapNode = 25, -- nodo de recurso del mapa
			Viewport = 300, -- modelo de un ViewportFrame (RewardModels)
		},
		-- Excepciones aprobadas: el tope de un modelo concreto (por id) que sustituye al de su tipo.
		Exceptions = {
			MonoX7 = { PetTotal = 270, PetAnimated = 130 }, -- mascota de élite
			Nest = { Buildable = 50 }, -- construible único
			WarTotem = { Buildable = 120 }, -- construible único (incluye el anillo de 40 trazos)
			OrangutanDelManglar = { Boss = 35 }, -- el jefe más grande
		},
		-- Totales por escena en el cliente del móvil de referencia (gama baja, 3-4 GB, 30 FPS).
		Matches = {
			IslandSiegeParts = 45000, -- Isla en el asedio final
			IslandSiegeDrawCalls = 1200,
			DunasParts = 25000, -- Dunas 5v5
			LaboratorioParts = 20000, -- Laboratorio 5v5
			LobbyParts = 30000, -- Lobby con 20 jugadores
			LobbyPlayers = 20,
			MovedPartsPerFrame = 1500, -- piezas movidas por fotograma, en todas
			MemoryMB = 1300, -- memoria en todas
			ServerFps = 55, -- FPS mínimos del servidor
		},
		-- Pico de piezas de efectos por cliente según la calidad de efectos.
		Vfx = { Low = 40, Medium = 90, High = 160 },
		-- LOD de detalle de los cosméticos de otros jugadores.
		Lod = {
			DetailDistance = 60, -- studs a partir de los que se ocultan los detalles
			CheckSeconds = 0.5, -- cada cuánto se revisa un personaje
			DetailMaxSize = 0.35, -- lado mayor (studs) por debajo del que una pieza cuenta como detalle
		},
		-- Interruptor de la fusión greedy de VoxelMerge (false = no fusiona, para comparar).
		Merge = true,
	},

	-- Efectos de los jefes dibujados en el cliente (Fase 16, R6; combatClient/BossFx). "Pieces" son las piezas
	-- de UN efecto (marcador de peligro incluido) por calidad: un pisotón, UNA roca, UNA bomba de lava... El
	-- pico de cada efecto y el de una lluvia completa (count × piezas) tiene que quedar dentro de
	-- Budgets.Vfx de su calidad: la lluvia de rocas más larga es de 5 (Chimpancé) y la de lava, de 7 (Ceniza).
	-- La calculadora Rendimiento (sección 9) lo comprueba.
	BossFx = {
		MaxDistanceStuds = 250, -- más lejos que esto el cliente ignora el efecto
		Pieces = {
			stomp = { Low = 16, Medium = 50, High = 100 },
			rock = { Low = 8, Medium = 18, High = 32 },
			lavaBomb = { Low = 5, Medium = 12, High = 22 },
			charge = { Low = 8, Medium = 20, High = 36 },
			grab = { Low = 6, Medium = 14, High = 26 },
			roar = { Low = 10, Medium = 30, High = 60 },
		},
		ChargeLengthStuds = 54, -- recorrido de la embestida (90 studs/s durante 0,6 s)
		RoarRadiusStuds = 45,
		MarkerColor = Color3.fromRGB(255, 60, 40), -- rojo: daño recibido
		MarkerTransparency = 0.55,
		LavaPoolSeconds = 4, -- lo que dura el charco incandescente
	},
}

return Config
