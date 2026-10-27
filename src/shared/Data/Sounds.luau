--!strict
-- Música y sonidos (Fase 6). Pon aquí los IDs de audio ("rbxassetid://123…") que elijas en la
-- Caja de herramientas → Audio del Creator Store (usa pistas con licencia de Roblox, p. ej. de APM
-- Music, que son gratis para usar en tus juegos). Con "" esa música o ese efecto no suena.
-- Ver docs/LANZAMIENTO.md, sección Sonido.
--
-- Roblox solo trae 11 sonidos de serie ("rbxasset://sounds/…": pasos, salto, aterrizaje, levantarse,
-- caída, nadar, agua, explosión, "oof", "ouch" y el clic del volumen). Los efectos de abajo los usan
-- con distintos tonos para que el juego suene desde ya; los marcados con «Provisional» quedan mejor con
-- un audio propio del Creator Store (busca el nombre que se sugiere y pega su ID en "id").
--
-- Variantes: en "id" puedes poner una lista de IDs y cada vez suena uno al azar (los "" se saltan):
--   Hit = { id = { "rbxassetid://111", "rbxassetid://222", "rbxassetid://333" }, volume = 0.7, pitch = 1 },
-- Con tus propias grabaciones pon pitch = 1 (el tono ya lo ajustaste al editarlas) y jitter ~0.05–0.1.

export type Effect = {
	id: string | { string }, -- un ID o una lista de variantes
	volume: number,
	pitch: number, -- velocidad/tono (1 = normal)
	jitter: number?, -- variación al azar del tono en cada golpe (0.1 = ±10 %)
	range: number?, -- distancia (studs) a la que deja de oírse; por defecto 90
}

local FOOTSTEP = "rbxasset://sounds/action_footsteps_plastic.mp3"
local JUMP = "rbxasset://sounds/action_jump.mp3"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
local GET_UP = "rbxasset://sounds/action_get_up.mp3"
local SWIM = "rbxasset://sounds/action_swim.mp3"
local WATER = "rbxasset://sounds/impact_water.mp3"
local BOOM = "rbxasset://sounds/impact_explosion_03.mp3"
local OOF = "rbxasset://sounds/oof.ogg"
local OUCH = "rbxasset://sounds/ouch.ogg"
local CLICK = "rbxasset://sounds/volume_slider.ogg"

-- Lista de variantes a partir de los números de los audios subidos a Roblox.
local function assets(...: number): { string }
	local ids = {}
	for _, assetId in { ... } do
		table.insert(ids, `rbxassetid://{assetId}`)
	end
	return ids
end

local Effects: { [string]: Effect } = {
	-- Armas. Cada arma elige su sonido de uso con "sound" en Data/Weapons; sin él, las de cuerpo a
	-- cuerpo usan Swing y las de distancia Shoot (también los usan las habilidades de los roles).
	Swing = { id = JUMP, volume = 0.35, pitch = 1.6, jitter = 0.1 }, -- Provisional: "sword swing whoosh"
	Shoot = { id = SWIM, volume = 0.5, pitch = 1.8, jitter = 0.1 }, -- Provisional: "slingshot"
	SwingLight = { id = JUMP, volume = 0.3, pitch = 1.9, jitter = 0.1 }, -- machete, antorcha. Provisional: "blade swish"
	SwingHeavy = { id = JUMP, volume = 0.5, pitch = 1.05, jitter = 0.08 }, -- garrotes y mazas. Provisional: "heavy swing whoosh"
	SwingThrust = { id = JUMP, volume = 0.35, pitch = 1.4, jitter = 0.08 }, -- lanza. Provisional: "spear thrust"
	ShootStone = { id = SWIM, volume = 0.5, pitch = 1.8, jitter = 0.1 }, -- hondas. Provisional: "slingshot"
	ShootArrow = { id = SWIM, volume = 0.45, pitch = 2.4, jitter = 0.08 }, -- arcos. Provisional: "bow release"
	ShootSpell = { id = GET_UP, volume = 0.5, pitch = 2, jitter = 0.1 }, -- bastones. Provisional: "magic cast"
	ShootDart = { id = SWIM, volume = 0.4, pitch = 2.9, jitter = 0.08 }, -- cerbatanas. Provisional: "blowgun puff"
	Hit = { id = LAND, volume = 0.7, pitch = 1.3, jitter = 0.15 }, -- golpe que acierta a un mono o jefe (carne)
	PlayerHurt = { id = OUCH, volume = 0.6, pitch = 1, jitter = 0.08 },
	PlayerDown = { id = OOF, volume = 0.7, pitch = 0.9 },
	-- Guardia (Fase 10, C5; Combat/Guard) y el resto del combate v2 (C12): audios de Pro Sound Effects y de
	-- Roblox del Creator Store, con licencia para usar en el juego. Madera contra piedra al bloquear, un
	-- tintineo claro al parar (se distingue a ciegas del bloqueo), madera que se astilla al romperse la
	-- guardia, un soplido al escapar o amagar y piedra que cae contra la pared en el rebote.
	Block = { id = assets(9118629282, 9118629121, 9118621947), volume = 0.9, pitch = 1, jitter = 0.08 },
	Parry = { id = assets(9113133597, 9125362690), volume = 0.8, pitch = 1.15, jitter = 0.04 },
	GuardBreak = { id = assets(9120826936, 9113582284), volume = 1, pitch = 0.9, jitter = 0.05 },
	Evasive = { id = "rbxassetid://12222200", volume = 0.8, pitch = 0.9, jitter = 0.05 }, -- Evasivo (C7)
	Feint = { id = "rbxassetid://12222200", volume = 0.45, pitch = 0.65, jitter = 0.05 }, -- amago (C8)
	-- Rebote contra muros (C10, CombatService).
	WallBang = { id = assets(9118588165, 9118587494), volume = 0.9, pitch = 0.9, jitter = 0.08, range = 120 },
	Revive = { id = GET_UP, volume = 0.7, pitch = 1.1 },
	Heal = { id = GET_UP, volume = 0.5, pitch = 1.5 },

	-- Herramientas y recursos
	Chop = { id = FOOTSTEP, volume = 0.9, pitch = 0.55, jitter = 0.08 }, -- hacha contra el árbol
	Mine = { id = FOOTSTEP, volume = 0.9, pitch = 1.5, jitter = 0.08 }, -- pico contra la roca
	TreeFall = { id = BOOM, volume = 0.45, pitch = 0.35, range = 120 },
	RockBreak = { id = LAND, volume = 0.9, pitch = 0.6 },
	Pickup = { id = CLICK, volume = 0.5, pitch = 1.3, jitter = 0.1 },
	Drink = { id = WATER, volume = 0.5, pitch = 1.6, jitter = 0.1 },
	Eat = { id = GET_UP, volume = 0.5, pitch = 1.6, jitter = 0.1 }, -- Provisional: "eating crunch"

	-- Construcción y estaciones
	Build = { id = LAND, volume = 0.9, pitch = 0.8, jitter = 0.08 },
	Repair = { id = FOOTSTEP, volume = 0.8, pitch = 0.9, jitter = 0.1 },
	-- Golpe a una pieza construida (un mono que la ataca, las estacas al pincharle). Cada pieza elige
	-- con "hitSound" en Data/Buildables; por defecto, madera.
	StructureHit = { id = FOOTSTEP, volume = 0.8, pitch = 0.7, jitter = 0.1 }, -- Provisional: "wood impact"
	StructureHitStone = { id = FOOTSTEP, volume = 0.8, pitch = 1.3, jitter = 0.1 }, -- Provisional: "stone impact"
	StructureBreak = { id = BOOM, volume = 0.4, pitch = 0.7 },
	Craft = { id = GET_UP, volume = 0.6, pitch = 1.3 },

	-- Animales (las voces de los monos están en MonkeyVoices, más abajo)
	-- El capuchino ladrón se ríe al robarte (mono steal 1-3).
	MonkeySteal = {
		id = assets(72053613594928, 72889728117222, 90077280374632),
		volume = 0.65,
		pitch = 1,
		jitter = 0.06,
	},
	-- Tu mascota ataca (pet attack 1-4).
	PetAttack = {
		id = assets(129448246875134, 105072784917714, 126577775232138, 84211282254857),
		volume = 0.5,
		pitch = 1,
		jitter = 0.08,
	},

	-- Clima, volcán y eventos
	Thunder = { id = BOOM, volume = 1, pitch = 0.5, jitter = 0.1, range = 400 },
	LavaLaunch = { id = BOOM, volume = 0.35, pitch = 1.4, range = 200 },
	LavaImpact = { id = BOOM, volume = 0.8, pitch = 0.8, jitter = 0.1, range = 160 },
	-- Fuegos artificiales de la fiesta del Lobby (evento en vivo, T4b). Provisional: «firework pop».
	Firework = { id = BOOM, volume = 0.3, pitch = 1.9, jitter = 0.15, range = 250 },
	RockImpact = { id = LAND, volume = 1, pitch = 0.5, jitter = 0.1, range = 120 },
	EggHatch = { id = GET_UP, volume = 0.9, pitch = 1.8, range = 120 },
	-- "¡Puf!" de humo al derrotar un mono, un jefe o un muñeco (Combat/Poof).
	Poof = { id = GET_UP, volume = 0.6, pitch = 2.2, jitter = 0.1, range = 120 }, -- Provisional: "cartoon poof"
}

-- Voces de los monos por tamaño (cada especie elige su grupo con "voice" en Data/Monkeys). Cada grupo
-- tiene cuatro: Attack (muerde o salta), Call (aúlla o ruge para llamar a la tropa), Hurt (recibe un
-- golpe) y Death (ya no suena: al derrotarlos suena Hurt y el "¡puf!", violencia de caricatura). Son
-- grabaciones propias (ya afinadas en Audacity, por eso pitch = 1) con varias tomas: cada vez suena una
-- al azar. El número de cada toma está en su comentario.
local MonkeyVoices: { [string]: { [string]: Effect } } = {
	-- Tití, capuchino, mono ardilla y marteja: chillidos agudos y trinos.
	Small = {
		Attack = {
			id = assets(120818784564690, 97162650609963, 100889891543035),
			volume = 0.6,
			pitch = 1,
			jitter = 0.08,
		}, -- 1-3
		Call = {
			id = assets(92840853267309, 132638077007976, 127804153022844),
			volume = 0.7,
			pitch = 1,
			jitter = 0.06,
			range = 120,
		}, -- 1-3
		Hurt = {
			id = assets(83206462911000, 94071359686291, 121789156418140, 119853628467210),
			volume = 0.6,
			pitch = 1,
			jitter = 0.08,
		}, -- damage 1-4
		Death = {
			id = assets(96263078454750, 107348634145517, 120413905689461, 127383166361393),
			volume = 0.7,
			pitch = 1,
			jitter = 0.06,
		}, -- 1-3 y la primera que subiste (sin número)
	},
	-- Cola larga, marimonda, gibón, aullador, macaco y babuino: gritos, ladridos y parloteo.
	Medium = {
		Attack = {
			id = assets(101566051140325, 78666182840062, 129343390376286),
			volume = 0.6,
			pitch = 1,
			jitter = 0.08,
		}, -- 1-3
		Call = {
			id = assets(84612324755022, 73113198461767, 112267620291035),
			volume = 0.8,
			pitch = 1,
			jitter = 0.05,
			range = 160,
		}, -- 1-3; el aullador avisa a la tropa
		Hurt = {
			id = assets(127218142406410, 126398772994173, 127695909714054),
			volume = 0.65,
			pitch = 1,
			jitter = 0.08,
		}, -- damage 1-3
		Death = {
			id = assets(132598995656891, 106334434884373, 78663149014123, 131254715857839),
			volume = 0.75,
			pitch = 1,
			jitter = 0.06,
		}, -- 1-4
	},
	-- Chimpancé, mandril, orangután y gorila: ululatos, gruñidos graves y rugidos.
	Large = {
		Attack = {
			id = assets(95144095220328, 121761682490390, 79838978185801),
			volume = 0.7,
			pitch = 1,
			jitter = 0.06,
		}, -- 1-3
		Call = { id = assets(117838908803383, 127164177577247), volume = 0.85, pitch = 1, jitter = 0.05, range = 140 }, -- 1-2
		Hurt = {
			id = assets(100911323277547, 83423545485614, 129547708669523),
			volume = 0.75,
			pitch = 1,
			jitter = 0.06,
		}, -- damage 1-3
		Death = {
			id = assets(139892111825679, 91154327046668, 103189610835600),
			volume = 0.85,
			pitch = 1,
			jitter = 0.05,
			range = 120,
		}, -- 1-3
	},
}

for voice, effects in MonkeyVoices do
	for action, effect in effects do
		Effects[`Monkey{voice}{action}`] = effect
	end
end

-- Los jefes usan las voces de los grandes: más graves, más fuertes y desde más lejos. Las grabaciones
-- de los grandes ya vienen graves, así que basta con bajarlas un poco (0.8 ≈ 4 semitonos).
local BOSS_PITCH = 0.8

local function bossVoice(effect: Effect, range: number): Effect
	return { id = effect.id, volume = 0.9, pitch = effect.pitch * BOSS_PITCH, jitter = effect.jitter, range = range }
end

Effects.BossAttack = bossVoice(MonkeyVoices.Large.Attack, 120)
Effects.BossRoar = bossVoice(MonkeyVoices.Large.Call, 260)
Effects.BossHurt = bossVoice(MonkeyVoices.Large.Hurt, 160)
-- Derrota del jefe: un quejido grave (no el grito de muerte) antes del "¡puf!".
Effects.BossDeath = bossVoice(MonkeyVoices.Large.Hurt, 260)

local Sounds = {
	-- Música de fondo por situación (la Isla elige sola cuál toca). Basta con Lobby y Day: la que
	-- quede en "" usa la más parecida (FinalNight → Siege → Night → Day).
	Music = {
		Lobby = "rbxassetid://127164046914411",
		Day = "rbxassetid://108537342283944", -- pista principal de la Isla
		Night = "rbxassetid://140472208029970", -- noche tranquila (sin monos atacando)
		Siege = "rbxassetid://107447708451092", -- cuando los monos atacan el Basecamp
		Boss = "", -- tema común de los jefes que no tengan uno propio en BossMusic
		FinalNight = "rbxassetid://128802469389447", -- La Gran Tropa
	},
	-- Tema propio de cada jefe (id de Data/Bosses). Suena cuando el jefe está peleando y estás cerca.
	-- Si queda en "", usa Music.Boss; si tampoco hay, sigue la música de la situación.
	BossMusic = {
		OrangutanDelManglar = "rbxassetid://102669914804895",
		ChimpanceCaudillo = "rbxassetid://96506704725423",
		GorilaAlbino = "rbxassetid://83706082419045",
		GorilaDeCeniza = "rbxassetid://115935631696800",
	} :: { [string]: string },
	MusicVolume = 0.35, -- Lobby
	IslandMusicVolume = 0.12,
	-- Aviso de cada mensaje en pantalla.
	Notify = CLICK,
	NotifyVolume = 0.4,
	Effects = Effects,
}

return Sounds
