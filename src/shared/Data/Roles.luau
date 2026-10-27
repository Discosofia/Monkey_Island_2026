--!strict
-- Roles (GDD §6.3, Fase 3). Se eligen en el Lobby y son fijos durante la partida.
--   - "perks": ventajas pasivas (se suman a Data/Perks).
--   - "weapons": armas con las que aparece (además del hacha y el pico, Config.Combat.StarterTools).
--   - "items": ítems con los que empieza la partida (las flechas del cazador).
--   - "refill": un ítem que se rellena solo (el carcaj del cazador): +1 cada "seconds" mientras tenga
--     menos de "cap". Lo fabricado puede pasar del tope. Lo hace RoleService.
--   - "abilities": 4 activas y la definitiva, en el orden de sus huecos: Z, X, C, la definitiva V y la
--     cuarta activa R (con mando, R1 + A, B, X, Y y L1). La R va al final para que los huecos 1-4 sigan
--     siendo los de siempre. Las gestiona AbilityService y sus números están en Config.Abilities.
--   - "altUltimates": otras definitivas que el jugador puede elegir en el Lobby (ventana de Talentos) en
--     lugar de la del hueco 4 (T7). La elegida va en su perfil, una por rol; Shared/RoleAbilities da las
--     5 habilidades de un jugador con la que haya elegido.

export type Ability = {
	id: string,
	name: string,
	short: string, -- texto del botón táctil
	description: string,
	cooldownSeconds: number,
	ultimate: boolean?,
	-- Preparación (Fase 10, C8; AbilityService): segundos desde que se pulsa hasta que sale, con el gesto
	-- ya en marcha. En ese tiempo se puede amagar (pulsar la guardia) y un aturdimiento la corta. 0 =
	-- sale al momento (las de defensa y huida: Grito, Parpadeo, Escudo). Sin él,
	-- Config.Windup.AbilityDefaultSeconds.
	castSeconds: number?,
	-- Guardia (Fase 10, C5 y C8; Combat/Guard): la que gasta si un jugador la bloquea, una vez por uso
	-- aunque pegue varias veces (sin él, Config.Guard.AbilityGuardDamage), y si es imbloqueable (rompe
	-- la guardia y entra entera). Las fuertes 25, las medias 20, las de control 15 y el dardo 10.
	guardDamage: number?,
	unblockable: boolean?,
	-- Solo las definitivas: contra jugadores, esto además de CombatRules.pvpUltimateMultiplier. Lo llevan
	-- las de un solo objetivo, que meten todo su daño en un golpe: así ninguno pasa de 40 de 100 (T7).
	pvpMultiplier: number?,
}

export type Refill = { itemId: string, seconds: number, cap: number }

export type Role = {
	name: string,
	icon: string,
	order: number,
	passive: string, -- texto para el jugador
	-- Su ventaja en combate en dos líneas cortas, bajo su nombre al elegir rol en la arena.
	edge: string,
	perks: { [string]: number },
	weapons: { string },
	items: { [string]: number }?,
	refill: Refill?,
	abilities: { Ability },
	altUltimates: { Ability }?,
}

local Roles: { [string]: Role } = {
	Guerrero = {
		name = "Guerrero",
		icon = "⚔️",
		order = 1,
		passive = "+25 % de daño cuerpo a cuerpo y +20 de vida máxima.",
		edge = "+25 % melé\n+20 de vida",
		perks = { MeleeDamage = 0.25, MaxHealth = 20 },
		weapons = { "StoneClub", "Honda" },
		abilities = {
			{
				id = "Whirlwind",
				name = "Torbellino",
				short = "Torbellino",
				description = "Gira con el arma y golpea a todo lo que tienes alrededor.",
				cooldownSeconds = 7,
				castSeconds = 0.2,
				guardDamage = 25,
			},
			{
				id = "Charge",
				name = "Embestida",
				short = "Embestida",
				description = "Cargas hacia delante, dañas y empujas a lo que atraviesas. Si lo estampas contra un muro, lo aturdes.",
				cooldownSeconds = 6,
				castSeconds = 0.2,
				guardDamage = 20,
			},
			{
				id = "WarCry",
				name = "Grito de guerra",
				short = "Grito",
				description = "Los monos cercanos van a por ti y recibes un 40 % menos de daño (de otros jugadores, un 15 %).",
				cooldownSeconds = 12,
				castSeconds = 0,
			},
			{
				id = "Quake",
				name = "Pisotón",
				short = "Pisotón",
				description = "Pisas el suelo con fuerza: daño fuerte alrededor y aturde a los monos.",
				cooldownSeconds = 90,
				castSeconds = 0.35,
				ultimate = true,
				unblockable = true,
			},
			{
				id = "Smash",
				name = "Rompehuesos",
				short = "Rompe",
				description = "Un golpe brutal hacia delante que daña, tumba un momento y aparta a los monos. Contra un muro, rebotan.",
				cooldownSeconds = 8,
				castSeconds = 0.3,
				unblockable = true,
			},
		},
		altUltimates = {
			{
				id = "Leap",
				name = "Salto del gorila",
				short = "Salto",
				description = "Saltas sobre un enemigo: daño enorme a ese y lo inmovilizas.",
				cooldownSeconds = 90,
				castSeconds = 0.35,
				ultimate = true,
				unblockable = true,
				pvpMultiplier = 0.45,
			},
		},
	},
	Cazador = {
		name = "Cazador",
		icon = "🏹",
		order = 2,
		passive = "+25 % de daño a distancia. Su carcaj recupera 1 flecha cada 3 s (hasta 30).",
		edge = "+25 % daño\na distancia",
		perks = { RangedDamage = 0.25 },
		weapons = { "Bow", "Machete" },
		items = { Arrow = 40 },
		refill = { itemId = "Arrow", seconds = 3, cap = 30 },
		abilities = {
			{
				id = "MultiShot",
				name = "Disparo múltiple",
				short = "Múltiple",
				description = "Lanzas un abanico de proyectiles hacia donde apuntas.",
				cooldownSeconds = 5,
				castSeconds = 0.2,
				guardDamage = 20,
			},
			{
				id = "MarkPrey",
				name = "Marcar presas",
				short = "Marcar",
				description = "Señala a los monos cercanos: el equipo los ve y les hace más daño.",
				cooldownSeconds = 15,
				castSeconds = 0.15,
			},
			{
				id = "Trap",
				name = "Cepo",
				short = "Cepo",
				description = "Deja un cepo a tus pies; cuando un mono lo pisa, atrapa a todos los que tiene alrededor.",
				cooldownSeconds = 9,
				castSeconds = 0.15,
				guardDamage = 15,
			},
			{
				id = "ArrowRain",
				name = "Lluvia de proyectiles",
				short = "Lluvia",
				description = "Una zona donde apuntas recibe daño continuo durante unos segundos.",
				cooldownSeconds = 90,
				castSeconds = 0.3,
				guardDamage = 20,
				ultimate = true,
			},
			{
				id = "PiercingShot",
				name = "Flecha perforante",
				short = "Perforante",
				description = "Una flecha recta que atraviesa a todos los monos que encuentra en línea.",
				cooldownSeconds = 8,
				castSeconds = 0.3,
				guardDamage = 25,
			},
		},
		altUltimates = {
			{
				id = "TrueShot",
				name = "Disparo certero",
				short = "Certero",
				description = "Tiro cargado con línea de aviso: daño enorme a un solo enemigo.",
				cooldownSeconds = 90,
				castSeconds = 0.35,
				guardDamage = 25,
				ultimate = true,
				pvpMultiplier = 0.5,
			},
		},
	},
	Mago = {
		name = "Mago",
		icon = "🔮",
		order = 3,
		passive = "+25 % de daño de hechizos y habilidades un 15 % más rápidas.",
		edge = "+25 % hechizos\n−15 % recargas",
		perks = { SpellDamage = 0.25, CooldownRate = -0.15 },
		weapons = { "MagicStaff", "Machete" },
		abilities = {
			{
				id = "Fireball",
				name = "Bola de fuego",
				short = "Fuego",
				description = "Proyectil que explota al impactar y daña alrededor.",
				cooldownSeconds = 6,
				castSeconds = 0.2,
				guardDamage = 25,
			},
			{
				id = "FrostNova",
				name = "Nova de hielo",
				short = "Hielo",
				description = "Congela a los monos a tu alrededor y después los ralentiza. El suelo se queda helado unos segundos.",
				cooldownSeconds = 11,
				castSeconds = 0.25,
				guardDamage = 15,
			},
			{
				id = "Blink",
				name = "Parpadeo",
				short = "Parpadeo",
				description = "Te teletransportas hacia donde miras.",
				cooldownSeconds = 7,
				castSeconds = 0,
			},
			{
				id = "ChainLightning",
				name = "Rayo encadenado",
				short = "Rayo",
				description = "Un rayo que salta entre varios monos, algo más débil en cada salto.",
				cooldownSeconds = 90,
				castSeconds = 0.3,
				guardDamage = 25,
				ultimate = true,
			},
			{
				id = "Meteor",
				name = "Meteoro",
				short = "Meteoro",
				description = "Una roca ardiente cae del cielo donde apuntas y daña a todos los de alrededor.",
				cooldownSeconds = 10,
				castSeconds = 0.2,
				unblockable = true,
			},
		},
		altUltimates = {
			{
				id = "LavaBeam",
				name = "Haz volcánico",
				short = "Haz",
				description = "Rayo de lava fijo en un enemigo 2 s: mucho daño a ese.",
				cooldownSeconds = 90,
				castSeconds = 0.3,
				guardDamage = 25,
				ultimate = true,
			},
		},
	},
	Medico = {
		name = "Médico",
		icon = "⛑️",
		order = 4,
		passive = "+15 de vida máxima, reanima el doble de rápido y ve la vida de sus aliados. Al curarlos gana un escudo de savia.",
		edge = "+15 de vida\nescudo al curar",
		-- "SapShield": escudo de la Savia protectora (Config.Abilities.SapShieldSeconds y SapShieldCooldown).
		perks = { ReviveSpeed = -0.5, SeeHealth = 1, MaxHealth = 15, SapShield = 10 },
		weapons = { "Blowgun", "Machete" },
		abilities = {
			{
				id = "AreaHeal",
				name = "Ungüento en área",
				short = "Ungüento",
				description = "Cura a los aliados cercanos (y a ti).",
				cooldownSeconds = 15,
				castSeconds = 0.2,
			},
			{
				id = "HealingDart",
				name = "Dardo curativo",
				short = "Dardo",
				description = "Dardo que cura al aliado que alcanza (o pica un poco a un mono).",
				cooldownSeconds = 6,
				castSeconds = 0.15,
				guardDamage = 10,
			},
			{
				id = "LeafShield",
				name = "Escudo de hojas",
				short = "Escudo",
				description = "El aliado más cercano (o tú) recibe un escudo que absorbe daño.",
				cooldownSeconds = 12,
				castSeconds = 0,
			},
			{
				id = "HealingTotem",
				name = "Tótem sanador",
				short = "Tótem",
				description = "Plantas un tótem donde apuntas que cura poco a poco a quien esté cerca.",
				cooldownSeconds = 90,
				castSeconds = 0.3,
				ultimate = true,
			},
			{
				id = "SleepPowder",
				name = "Polvo somnífero",
				short = "Somnífero",
				description = "Lanzas una nube donde apuntas: a los monos les entra sueño y se duermen un momento (los jefes, no). La nube se queda unos segundos.",
				cooldownSeconds = 12,
				castSeconds = 0.25,
				guardDamage = 15,
			},
		},
		altUltimates = {
			{
				id = "Resurgence",
				name = "Resurgir",
				short = "Resurgir",
				description = "Curas de golpe a los cercanos y les quitas veneno y aturdidos (en la arena, solo el veneno).",
				cooldownSeconds = 90,
				castSeconds = 0.2,
				ultimate = true,
			},
		},
	},
}

return Roles
