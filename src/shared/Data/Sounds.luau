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

	-- Animales (Provisional todos: busca "monkey scream", "monkey chatter", "gorilla roar"…)
	MonkeyHurt = { id = OUCH, volume = 0.6, pitch = 1.9, jitter = 0.12 },
	MonkeyDeath = { id = OOF, volume = 0.7, pitch = 1.7, jitter = 0.1 },
	MonkeyAttack = { id = OUCH, volume = 0.5, pitch = 2.2, jitter = 0.15 },
	MonkeyHowl = { id = OOF, volume = 0.8, pitch = 0.75, range = 160 }, -- el aullador avisa a la tropa
	MonkeyRoar = { id = BOOM, volume = 0.5, pitch = 0.45, range = 140 }, -- rugido del alfa / gorila
	MonkeySteal = { id = OUCH, volume = 0.5, pitch = 2.4 }, -- el ladrón se ríe y huye
	BossRoar = { id = BOOM, volume = 0.9, pitch = 0.3, range = 260 },
	BossHurt = { id = OOF, volume = 0.8, pitch = 0.6, jitter = 0.1, range = 160 },
	PetAttack = { id = OUCH, volume = 0.35, pitch = 2.6, jitter = 0.1 },

	-- Clima, volcán y eventos
	Thunder = { id = BOOM, volume = 1, pitch = 0.5, jitter = 0.1, range = 400 },
	LavaLaunch = { id = BOOM, volume = 0.35, pitch = 1.4, range = 200 },
	LavaImpact = { id = BOOM, volume = 0.8, pitch = 0.8, jitter = 0.1, range = 160 },
	RockImpact = { id = LAND, volume = 1, pitch = 0.5, jitter = 0.1, range = 120 },
	EggHatch = { id = GET_UP, volume = 0.9, pitch = 1.8, range = 120 },
}

local Sounds = {
	-- Música de fondo por situación (la Isla elige sola cuál toca).
	Music = {
		Lobby = "",
		Day = "",
		Night = "",
		Siege = "", -- cuando los monos atacan el Basecamp
		Boss = "", -- cerca de un jefe
		FinalNight = "", -- La Gran Tropa
	},
	MusicVolume = 0.35,
	-- Aviso de cada mensaje en pantalla.
	Notify = CLICK,
	NotifyVolume = 0.4,
	Effects = Effects,
}

return Sounds
