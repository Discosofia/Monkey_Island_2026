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

export type Effect = {
	id: string,
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

local Effects: { [string]: Effect } = {
	-- Armas
	Swing = { id = JUMP, volume = 0.35, pitch = 1.6, jitter = 0.1 }, -- Provisional: "sword swing whoosh"
	Shoot = { id = SWIM, volume = 0.5, pitch = 1.8, jitter = 0.1 }, -- Provisional: "slingshot"
	Hit = { id = LAND, volume = 0.7, pitch = 1.3, jitter = 0.15 }, -- golpe que acierta
	PlayerHurt = { id = OUCH, volume = 0.6, pitch = 1, jitter = 0.08 },
	PlayerDown = { id = OOF, volume = 0.7, pitch = 0.9 },
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
	StructureBreak = { id = BOOM, volume = 0.4, pitch = 0.7 },
	Craft = { id = GET_UP, volume = 0.6, pitch = 1.3 },

	-- Animales (las voces de los monos están en MonkeyVoices, más abajo)
	MonkeySteal = { id = OUCH, volume = 0.5, pitch = 2.4 }, -- Provisional: "monkey chatter" (el ladrón se ríe)
	PetAttack = { id = OUCH, volume = 0.35, pitch = 2.6, jitter = 0.1 },

	-- Clima, volcán y eventos
	Thunder = { id = BOOM, volume = 1, pitch = 0.5, jitter = 0.1, range = 400 },
	LavaLaunch = { id = BOOM, volume = 0.35, pitch = 1.4, range = 200 },
	LavaImpact = { id = BOOM, volume = 0.8, pitch = 0.8, jitter = 0.1, range = 160 },
	RockImpact = { id = LAND, volume = 1, pitch = 0.5, jitter = 0.1, range = 120 },
	EggHatch = { id = GET_UP, volume = 0.9, pitch = 1.8, range = 120 },
}

-- Voces de los monos por tamaño (cada especie elige su grupo con "voice" en Data/Monkeys). Cada grupo
-- tiene cuatro: Attack (muerde o salta), Call (aúlla o ruge para llamar a la tropa), Hurt (recibe un
-- golpe) y Death (muere). Todas son provisionales: pega el ID de tu sonido y pon pitch = 1.
local MonkeyVoices: { [string]: { [string]: Effect } } = {
	-- Tití, capuchino, mono ardilla y marteja: chillidos agudos y trinos.
	Small = {
		Attack = { id = OUCH, volume = 0.45, pitch = 2.6, jitter = 0.15 },
		Call = { id = OUCH, volume = 0.6, pitch = 3, jitter = 0.1, range = 120 },
		Hurt = { id = OUCH, volume = 0.5, pitch = 2.4, jitter = 0.12 },
		Death = { id = OOF, volume = 0.6, pitch = 2.2, jitter = 0.1 },
	},
	-- Cola larga, marimonda, gibón, aullador, macaco y babuino: gritos, ladridos y parloteo.
	Medium = {
		Attack = { id = OUCH, volume = 0.5, pitch = 2, jitter = 0.15 },
		Call = { id = OOF, volume = 0.8, pitch = 0.75, range = 160 }, -- el aullador avisa a la tropa
		Hurt = { id = OUCH, volume = 0.6, pitch = 1.8, jitter = 0.12 },
		Death = { id = OOF, volume = 0.7, pitch = 1.5, jitter = 0.1 },
	},
	-- Chimpancé, mandril, orangután y gorila: ululatos, gruñidos graves y rugidos.
	Large = {
		Attack = { id = OOF, volume = 0.6, pitch = 0.8, jitter = 0.1 },
		Call = { id = BOOM, volume = 0.5, pitch = 0.45, range = 140 }, -- rugido del mandril y golpe del gorila
		Hurt = { id = OOF, volume = 0.7, pitch = 0.9, jitter = 0.1 },
		Death = { id = OOF, volume = 0.8, pitch = 0.65, range = 120 },
	},
}

for voice, effects in MonkeyVoices do
	for action, effect in effects do
		Effects[`Monkey{voice}{action}`] = effect
	end
end

-- Los jefes usan las voces de los grandes: más graves, más fuertes y desde más lejos.
local BOSS_PITCH = 0.65

local function bossVoice(effect: Effect, range: number): Effect
	return { id = effect.id, volume = 0.9, pitch = effect.pitch * BOSS_PITCH, jitter = effect.jitter, range = range }
end

Effects.BossAttack = bossVoice(MonkeyVoices.Large.Attack, 120)
Effects.BossRoar = bossVoice(MonkeyVoices.Large.Call, 260)
Effects.BossHurt = bossVoice(MonkeyVoices.Large.Hurt, 160)
Effects.BossDeath = bossVoice(MonkeyVoices.Large.Death, 260)

local Sounds = {
	-- Música de fondo por situación (la Isla elige sola cuál toca). Basta con Lobby y Day: las
	-- situaciones de la Isla que queden en "" usan la pista de Day.
	Music = {
		Lobby = "rbxassetid://127164046914411",
		Day = "rbxassetid://111965007272199", -- pista principal de la Isla
		Night = "",
		Siege = "", -- cuando los monos atacan el Basecamp
		Boss = "", -- cerca de un jefe
		FinalNight = "", -- La Gran Tropa
	},
	MusicVolume = 0.35, -- Lobby
	IslandMusicVolume = 0.12,
	-- Aviso de cada mensaje en pantalla.
	Notify = CLICK,
	NotifyVolume = 0.4,
	Effects = Effects,
}

return Sounds
