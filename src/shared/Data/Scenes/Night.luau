--!strict
-- Escena Night de las cinemáticas (ver la cabecera de Data/Cinematics). Archivo propio por el límite de locales del módulo grande.

local Kit = require(script.Parent.Parent.CinematicKit)
local BossChoreo = require(script.Parent.Parent.BossChoreo)
local Strings = require(script.Parent.Parent.Parent.Strings)

type Scene = Kit.Scene
type EventList = Kit.EventList
local cameraKey = Kit.cameraKey
local cutShots = Kit.cutShots
local actionWriters = Kit.actionWriters
local yawBetween = Kit.yawBetween

-- ============================================================================ Noche y Luna roja (Fase 25, G14c)
-- «Night» (29 s, solo la versión normal): cae la noche en la Isla, el fuego mantiene a raya a las Martejas y sale la Luna roja con
-- una horda más grande. La lanza «🎬 Noche y Luna roja» del panel de la Isla con ArrivalService.play y un stage cuyo anchor es el
-- suelo bajo el centro del Basecamp (la hoguera, en (0, 0)). Se rueda ante la PUERTA ESTE: hueco de 22 studs centrado en
-- (81, 0) que mira hacia fuera por +X; el terreno hacia fuera es llano 30 studs y luego sube suave (+2,7 a los 70). La selva
-- empieza a unos 70-100 studs. Las posiciones se escriben con gt(f, s): f hacia fuera de la puerta, s lateral (Z).
-- La luna a ClockTime 19,5 está a 20,5° de elevación y a ~25° del lado -Z de la dirección +X (medido): la escena acaba en 19,5 y
-- la cámara mira hacia +X y un poco a -Z. La hora no pasa de 19,5 (si no, la luna sube y sale de cuadro).
--    0 a  5    grúa que baja sobre la puerta; los tres encienden su antorcha (2,5, 3 y 3,5); «Cae la noche»
--    5 a 11    dos Martejas salen de la selva; el avatar avanza con la antorcha y ellas rugen y se retiran
--   11 a 16    plano bajo detrás de los tres que sube hacia la luna; sale roja (redMoon + tinte); aúllan las Martejas
--   16 a 22    la horda (3 Macacos, 3 Babuinos y 1 Gorila) sale de la selva corriendo; cámara detrás de ella y contraplano
--   22 a 26    choque: Grito de guerra, Disparo múltiple sobre un Macaco y Bola de fuego sobre un Babuino
--   26 a 29    el Gorila salta sobre el avatar; título «Luna roja», logo y fundido a negro (final en suspense)
-- Efectos pesados separados al menos 0,4 s (22,25 / 23,16 / 23,72). Los monos son de servidor (evento monkey, solo la
-- variante normal, sin alfas) y el stage pide clearRadius = 200 porque salen a unos 170 studs del centro.
local nightScenes: { [string]: Scene? } = (function(): { [string]: Scene? }
	local out: { [string]: Scene? } = {}
	local function build(): Scene
		local NIGHT_SECONDS = 29
		local GATE_X = 81 -- la puerta este, en el marco del anchor
		local function gt(f: number, s: number): Vector3
			return Vector3.new(GATE_X + f, 0, s)
		end
		-- Igual, con la altura (y) en medio, para la cámara.
		local function gc(f: number, y: number, s: number): Vector3
			return Vector3.new(GATE_X + f, y, s)
		end
		-- Giro de quien mira hacia fuera de la puerta (+X) y de quien mira hacia dentro (-X).
		local OUT = -90
		local IN = 90
		-- Dónde están los tres: al principio por dentro de la puerta; desde 11 s, ya fuera de la empalizada (más cerca de la horda).
		local AVATAR_START = gt(-6, 0)
		local HUNTER_START = gt(-9, 5)
		local MAGE_START = gt(-9, -5)
		local AVATAR_FIRE = gt(15, 0) -- hasta dónde avanza con la antorcha
		local AVATAR_NOW = gt(2, 0)
		local HUNTER_NOW = gt(-1, 7)
		local MAGE_NOW = gt(-1, -7)
		-- Horda: (f, s) donde frena, y de dónde sale (72 studs más lejos: a 17 studs/s en 4,3 s, la velocidad pasa de Run).
		local HORDE = {
			{ name = "macaco1", species = "Macaco", f = 22, s = -12, near = gt(11, -9) },
			{ name = "macaco2", species = "Macaco", f = 22, s = -3, near = gt(11, -2) },
			{ name = "macaco3", species = "Macaco", f = 23, s = 9, near = gt(11, 6) },
			{ name = "babuino1", species = "Babuino", f = 27, s = -8, near = gt(14, -5) },
			{ name = "babuino2", species = "Babuino", f = 28, s = 4, near = gt(14, 3) },
			{ name = "babuino3", species = "Babuino", f = 26, s = 13, near = gt(14, 10) },
			{ name = "gorila", species = "Gorila", f = 34, s = 0, near = gt(5, 0) },
		}
		local HORDE_BACK = 72
		local HORDE_GO = 17.0 -- cuando echan a correr (están quietos en la linde desde 16)
		local HORDE_RUN_SECONDS = 4.3
		-- Rumbo de la luna a ClockTime 19,5 (medido): elevación 20,5° y 25° del lado -Z de +X.
		local function aim(cam: Vector3, bearing: number, pitch: number): Vector3
			local b, p = math.rad(bearing), math.rad(pitch)
			return cam + Vector3.new(math.cos(p) * math.cos(b), math.sin(p), -math.cos(p) * math.sin(b)) * 60
		end

		local events: EventList = {}
		local add, anim, skill = actionWriters(events)
		local function put(t: number, actor: string, pos: Vector3, yaw: number)
			add({ t = t, kind = "move", actor = actor, pos = pos, yaw = yaw, seconds = 0 })
		end
		-- Camina o corre de un punto a otro con el giro de la marcha; la velocidad de la animación sale de lo que recorre.
		local function go(t: number, actor: string, action: string, from: Vector3, to: Vector3, seconds: number)
			local reference = if action == "Run" then 16 else 6
			add({
				t = t,
				kind = "anim",
				actor = actor,
				action = action,
				seconds = seconds + 0.1,
				speed = math.clamp((to - from).Magnitude / seconds / reference, 0.4, 1.2),
			})
			add({
				t = t,
				kind = "move",
				actor = actor,
				pos = to,
				yaw = yawBetween(from, to),
				seconds = seconds,
				easing = Enum.EasingStyle.Linear,
			})
		end
		-- Evento de un mono de servidor (CinematicMonkeyService).
		local function monkey(t: number, name: string, fields: { [string]: any })
			local event: { [string]: any } = { t = t, kind = "monkey", server = true, name = name }
			for field, value in fields do
				event[field] = value
			end
			add(event :: any)
		end

		-- ===== Apertura (0 a 5): cae la noche, las antorchas se encienden una a una
		add({ t = 0, kind = "letterbox" })
		-- Luz fría y tenue que sigue a la cámara: de noche cerrada, sin ella los tres salen negros fuera del círculo de las antorchas.
		add({
			t = 0,
			kind = "light",
			follow = true,
			offset = Vector3.new(0, 3, 0),
			color = Color3.fromRGB(150, 170, 230),
			brightness = 0.6,
			range = 50,
		})
		add({ t = 0.4, kind = "caption", text = Strings.later("Cae la noche"), seconds = 2.8 })
		add({ t = 0, kind = "clock", hour = 18.6, seconds = 4 })
		add({ t = 5, kind = "clock", hour = 19, seconds = 5 })
		add({ t = 11, kind = "clock", hour = 19.5, seconds = 4 })
		for _, name in { "avatar", "hunter", "mage" } do
			table.insert(events, BossChoreo.torch(0, name, false))
		end
		table.insert(events, BossChoreo.torch(2.5, "avatar", true, 3))
		table.insert(events, BossChoreo.torch(3, "hunter", true, 3))
		table.insert(events, BossChoreo.torch(3.5, "mage", true, 3))

		-- ===== Miedo al fuego (5 a 11): las Martejas se acercan, el avatar avanza con la antorcha y ellas se retiran
		add({ t = 5.3, kind = "caption", text = Strings.later("El fuego los mantiene a raya"), seconds = 3.2 })
		local marteja1_start, marteja1_near = gt(66, 7), gt(31, 4)
		local marteja2_start, marteja2_near = gt(70, -8), gt(33, -5)
		monkey(4.6, "marteja1", { species = "Marteja", at = marteja1_start, yaw = IN, action = "Idle" })
		monkey(4.6, "marteja2", { species = "Marteja", at = marteja2_start, yaw = IN, action = "Idle" })
		monkey(5.0, "marteja1", { move = { pos = marteja1_near, seconds = 3.0, yaw = IN } })
		monkey(5.0, "marteja2", { move = { pos = marteja2_near, seconds = 3.2, yaw = IN } })
		go(6.0, "avatar", "Walk", AVATAR_START, AVATAR_FIRE, 2.6)
		go(6.6, "hunter", "Walk", HUNTER_START, gt(-2, 5), 2.0)
		go(6.6, "mage", "Walk", MAGE_START, gt(-2, -5), 2.0)
		monkey(8.4, "marteja1", { action = "Roar" })
		monkey(8.6, "marteja2", { action = "Roar" })
		monkey(9.2, "marteja1", { move = { pos = gt(70, 8), seconds = 2.4 } })
		monkey(9.3, "marteja2", { move = { pos = gt(74, -9), seconds = 2.4 } })
		-- Aullido de las Martejas ya lejos, mientras sale la luna.
		monkey(12.8, "marteja1", { action = "Howl" })
		monkey(13.4, "marteja2", { action = "Howl" })

		-- ===== La luna sale roja (11 a 16): los tres ya fuera de la puerta; plano bajo que sube hacia la luna
		put(11.0, "avatar", AVATAR_NOW, OUT)
		put(11.0, "hunter", HUNTER_NOW, OUT)
		put(11.0, "mage", MAGE_NOW, OUT)
		add({ t = 11.4, kind = "caption", text = Strings.later("La luna sale roja"), seconds = 3.0 })
		add({ t = 11.5, kind = "redMoon", amount = 1, seconds = 3, size = 18 })
		add({ t = 12.0, kind = "exposure", value = -0.35, tint = Color3.fromRGB(255, 170, 160) })
		add({ t = 12.0, kind = "shake", amp = 0.1, seconds = 1.6 })

		-- ===== La horda (16 a 22): sale de la selva; quieta en la linde de 16 a 17 y echa a correr
		for _, member in HORDE do
			local start = gt(member.f + HORDE_BACK, member.s)
			local stop = gt(member.f, member.s)
			monkey(15.9, member.name, { species = member.species, at = start, yaw = IN, action = "Idle" })
			monkey(HORDE_GO, member.name, { move = { pos = stop, seconds = HORDE_RUN_SECONDS, yaw = IN } })
		end
		add({
			t = 16.3,
			kind = "caption",
			text = Strings.later("Hordas más grandes. Monos más fuertes."),
			seconds = 3.4,
		})
		monkey(HORDE_GO + HORDE_RUN_SECONDS + 0.1, "gorila", { action = "Roar" })

		-- ===== El choque (22 a 26): grito, flechas y bola de fuego
		anim(22.2, "avatar", "WarCry", 1.4)
		skill(22.25, "WarCry", "avatar", nil, { seconds = 1.4 })
		anim(22.5, "hunter", "AimBow", 1.3)
		anim(23.0, "hunter", "Arrow", 0.7)
		skill(23.16, "MultiShot", "hunter", "macaco2", nil)
		monkey(23.32, "macaco2", { action = "Hurt" })
		anim(23.05, "mage", "AimSpell", 1.0)
		anim(23.4, "mage", "Spell", 0.6)
		skill(23.72, "Fireball", "mage", "babuino2", nil)
		monkey(23.95, "babuino2", { action = "Hurt" })
		monkey(24.3, "macaco2", { action = "Die" })
		monkey(24.9, "babuino2", { action = "Die" })

		-- ===== Final en suspense (26 a 29): el resto carga y el Gorila salta sobre el avatar
		for _, member in HORDE do
			if member.name ~= "gorila" and member.name ~= "macaco2" and member.name ~= "babuino2" then
				monkey(25.9, member.name, { move = { pos = member.near, seconds = 1.3, yaw = IN } })
			end
		end
		monkey(26.0, "gorila", { action = "Pounce", move = { pos = gt(5, 0), seconds = 1.1, yaw = IN } })
		anim(26.9, "avatar", "Slash1", 0.7)
		add({ t = 26.3, kind = "title", text = Strings.later("Luna roja"), seconds = 1.4 })
		add({
			t = 27.85,
			kind = "logo",
			text = Strings.later("Primal Banana Islands"),
			sub = Strings.later("Monkey Survival"),
			seconds = 0.5,
		})
		add({ t = 28.3, kind = "fade", seconds = 0.5, toBlack = true })

		-- ===== Cámara. Ninguna a menos de 12 studs de un actor; las alturas son sobre el suelo del anchor.
		local shots: { CameraShot } = {
			-- Grúa sobre la puerta que baja, mirando hacia fuera por encima de los tres.
			{
				t0 = 0,
				t1 = 5,
				a = cameraKey(gc(-30, 18, 6), gc(8, 3, 0), 58),
				b = cameraKey(gc(-21, 5.5, 7), gc(8, 3, 0), 55),
			},
			-- Lateral del fuego: el avatar con la antorcha en medio y las Martejas a la derecha, de lado.
			{
				t0 = 5,
				t1 = 11,
				a = cameraKey(gc(10, 4, -24), gc(20, 3, 0), 55),
				b = cameraKey(gc(24, 4, -24), gc(22, 3, 0), 55),
			},
			-- Plano bajo detrás de los tres que sube hacia la luna (20,5° de elevación, 25° a -Z).
			{
				t0 = 11,
				t1 = 16,
				a = cameraKey(gc(-16, 1.3, 0), aim(gc(-16, 1.3, 0), 6, 4), 60),
				b = cameraKey(gc(-16, 1.3, 0), aim(gc(-16, 1.3, 0), 14, 13), 60),
			},
			-- Detrás de la horda, por encima de la linde de la selva: la ven quieta y echar a correr.
			{
				t0 = 16,
				t1 = 19,
				a = cameraKey(gc(114, 9, -18), gc(70, 3, 0), 58),
				b = cameraKey(gc(98, 7, -14), gc(52, 3, 0), 58),
			},
			-- Contraplano: la horda llega de frente, por encima del hombro de los tres.
			{
				t0 = 19,
				t1 = 22,
				a = cameraKey(gc(-16, 2.5, 0), gc(40, 3, 0), 58),
				b = cameraKey(gc(-12, 2.5, 0), gc(34, 4, 0), 52),
			},
			-- Choque de lado: la tripulación a la izquierda y la horda a la derecha.
			{
				t0 = 22,
				t1 = 26,
				a = cameraKey(gc(12, 4.5, -30), gc(14, 3, 0), 60),
				b = cameraKey(gc(16, 4, -29), gc(17, 3.5, 0), 56),
			},
			-- Cierre: bajo, detrás del avatar; el Gorila salta hacia la cámara.
			{
				t0 = 26,
				t1 = NIGHT_SECONDS,
				a = cameraKey(gc(-15, 2.2, -3), gc(12, 6, 0), 48),
				b = cameraKey(gc(-13, 2.2, -3), gc(8, 6, 0), 44),
			},
		}

		-- ===== Actores. Los tres con snap (el suelo de fuera de la puerta no es llano). Empiezan con la antorcha apagada.
		local actors: { [string]: { [string]: any } } = {
			avatar = {
				kind = "localPlayer",
				copy = true,
				role = "Guerrero",
				weapon = "StoneAxe",
				torch = true,
				snap = true,
				pos = AVATAR_START,
				yaw = OUT,
			},
			hunter = {
				kind = "dummy",
				role = "Cazador",
				armor = "VolcanicArmor",
				torch = true,
				snap = true,
				pos = HUNTER_START,
				yaw = OUT,
			},
			mage = {
				kind = "dummy",
				role = "Mago",
				outfit = "BlueFireInvokerOutfit",
				skin = "SulfurStaff",
				torch = true,
				snap = true,
				pos = MAGE_START,
				yaw = OUT,
			},
		}

		return {
			duration = NIGHT_SECONDS + 0.6, -- el negro final se sostiene hasta que acaba la escena
			audience = "Self",
			freeze = false,
			skippable = true,
			hour = 18.3,
			redMoonOff = true,
			-- El suelo cargado donde se pisa y se filma: dentro de la puerta, el claro, la subida y la linde de la selva.
			waitTerrain = {
				gt(-9, 0),
				gt(0, 0),
				gt(30, 0),
				gt(30, -24),
				gt(60, 10),
				gt(60, -10),
				gt(100, 0),
				gt(100, -16),
				gt(120, -18),
			},
			actors = actors,
			camera = cutShots(shots),
			events = events,
		}
	end

	local ok, built = pcall(build)
	if ok then
		out.Night = built :: Scene
	else
		warn(`Cinematics: no se pudo construir la escena Night: {built}`)
	end
	return out
end)()

return { Night = nightScenes.Night }
