--!strict
-- Escena Endless de las cinemáticas (ver la cabecera de Data/Cinematics). Archivo propio por el límite de locales del módulo grande.

local Kit = require(script.Parent.Parent.CinematicKit)
local BossChoreo = require(script.Parent.Parent.BossChoreo)
local Bosses = require(script.Parent.Parent.Bosses)
local Config = require(script.Parent.Parent.Parent.Config)
local HelicopterModel = require(script.Parent.Parent.Parent.HelicopterModel)
local Strings = require(script.Parent.Parent.Parent.Strings)

type Scene = Kit.Scene
type EventList = Kit.EventList
type CameraShot = Kit.CameraShot
local cameraKey = Kit.cameraKey
local cutShots = Kit.cutShots
local actionWriters = Kit.actionWriters
local yawBetween = Kit.yawBetween

-- ============================================================================ Parcela y modo infinito (Fase 25, G14d)
-- «Endless» (32 s, solo la versión normal): el helicóptero del rescate se va sin ellos, la parcela permanente sube de grado
-- día a día y de noche vuelve el Caudillo. La lanza «🎬 Parcela y modo infinito» del panel de la Isla con ArrivalService.play y
-- un stage cuyo anchor es el suelo bajo el centro del Basecamp (la hoguera, en (0, 0)); el Caudillo es de servidor (StageBoss)
-- y está fuera de la puerta sur, a (0, 100). La parcela de la escena es el hueco 2 de Config.Building.PlotAngles (135°, radio 62):
-- con un solo jugador el hueco 1 es el suyo y este está libre. Todo lo de la parcela está escrito en su marco local con pl(x, y, z)
-- (x a lo ancho, z hacia la empalizada, -Z mira al centro; el mismo de Config.Plot.Layout) y PlotActor dibuja el borde y las
-- 7 estructuras (PlotModels) en este cliente, sin tocar el perfil real.
--    0 a  6    Día 7, amanecer: el helicóptero despega de la plaza y se aleja; los tres lo despiden; «Rescatados… ¿y si te quedas?»
--              y «♾️ Seguir sobreviviendo»; entra el reloj del HUD en grande (grúa que baja hacia ellos)
--    6 a  9    los tres corren a su parcela; borde dorado, cartel y las 7 estructuras en grado I
--    9 a 21    Días 8 a 11, unos 3 s por día (la hora vuelve al amanecer en cada corte): Forja II, Incubadora II, Forja III y
--              Nido II, y por último todo a III (plano general en grúa)
--   21 a 27,6  Día 12, de noche: el Caudillo ante la puerta sur con su barra, ruge y pisa; los tres lo miran desde dentro
--   27,6 a 31,4  título «Modo infinito» (2,6 s), logo y negro (el plano se aleja de la parcela)
-- Efectos pesados (cada mejora de PlotActor y el rugido) separados al menos 0,4 s. Las cámaras, a 12 studs o más de los actores.
-- Las alturas de cámara son sobre el suelo del anchor: PLOT_Y las corrige si el suelo de la parcela no está a su altura.
-- Va dentro de una función por el límite de 200 locales del módulo.
local endlessScenes: { [string]: Scene? } = (function(): { [string]: Scene? }
	local out: { [string]: Scene? } = {}
	local function build(): Scene
		local ENDLESS_SECONDS = 31.4
		local FIRE = Vector3.zero
		local PLOT_Y = 0 -- diferencia de altura entre el suelo de la parcela y el del anchor (a medir en el Basecamp)

		-- ===== La parcela: su marco (como Building.plots) y sus estructuras
		local plotAngle = math.rad(Config.Building.PlotAngles[2])
		local plotPos = Vector3.new(math.cos(plotAngle), 0, math.sin(plotAngle)) * Config.Building.PlotRingRadius
		local plotFrame = CFrame.lookAt(plotPos, Vector3.zero)
		local PLOT_YAW = yawBetween(plotPos, Vector3.zero) -- giro (como el de los actores) del marco de la parcela
		-- Un punto del marco local de la parcela, en el marco del anchor.
		local function pl(x: number, y: number, z: number): Vector3
			return plotFrame:PointToWorldSpace(Vector3.new(x, y + PLOT_Y, z))
		end
		local layout: { [string]: { x: number, z: number, yaw: number } } = Config.Plot.Layout :: any
		local ORDER = { "Forge", "Nest", "Healer", "Garden", "Bed", "Chest", "Incubator" }

		-- Dónde se pone cada uno (marco local de la parcela). Los dos amigos esperan en la entrada y el avatar trabaja junto a
		-- cada estructura, por la columna libre del medio.
		local HUNTER_AT = pl(-4, 0, -12)
		local MEDIC_AT = pl(4, 0, -12)
		local AVATAR_ARRIVE = pl(0, 0, -6)
		local STAND_FORGE = pl(-4, 0, 4)
		local STAND_INCUBATOR = pl(3.2, 0, -8.5)
		local STAND_NEST = pl(0, 0, 2)
		local STAND_CENTER = pl(0, 0, -2)
		local FORGE_AT = pl(layout.Forge.x, 0, layout.Forge.z)
		local INCUBATOR_AT = pl(layout.Incubator.x, 0, layout.Incubator.z)
		local NEST_AT = pl(layout.Nest.x, 0, layout.Nest.z)
		local PLOT_MID = pl(0, 0, 4)
		local DAY10_HUNTER = pl(-12, 0, -13) -- el Día 10 se apartan de la línea cámara-avatar
		local DAY10_MEDIC = pl(5, 0, -13)

		-- ===== La plaza: dónde despiden al helicóptero (a la derecha de la hoguera) y su recorrido
		local CREW_AVATAR = Vector3.new(3.5, 0, 9)
		local CREW_HUNTER = Vector3.new(-3, 0, 10)
		local CREW_MEDIC = Vector3.new(8, 0, 4)
		local HELI_START = Vector3.new(18, 4.5, 10)
		local HELI_HOVER = Vector3.new(18, 11, 10)
		local HELI_OUT = Vector3.new(70, 52, -120)
		local HELI_YAW = yawBetween(HELI_HOVER, HELI_OUT)

		-- ===== La puerta sur (la empalizada está en z = 81; el Caudillo, fuera, a (0, 100) y mirando al norte)
		local BOSS_AT = Vector3.new(0, 0, 100)
		local NIGHT_AVATAR = Vector3.new(0, 0, 62)
		local NIGHT_HUNTER = Vector3.new(-5, 0, 66)
		local NIGHT_MEDIC = Vector3.new(5, 0, 66)

		-- Los cuatro días de aceleración: cuándo empiezan en la escena y qué se mejora.
		local DAY_LENGTH = 3
		local DAY_START = { [8] = 9, [9] = 12, [10] = 15, [11] = 18 }

		local events: EventList = {}
		local add, anim = actionWriters(events)
		local function put(t: number, actor: string, pos: Vector3, yaw: number)
			add({ t = t, kind = "move", actor = actor, pos = pos, yaw = yaw, seconds = 0 })
		end
		-- Corre de un punto a otro con el giro de la marcha; la velocidad de la animación sale de lo que recorre.
		local function run(t: number, actor: string, from: Vector3, to: Vector3, seconds: number)
			add({
				t = t,
				kind = "anim",
				actor = actor,
				action = "Run",
				seconds = seconds + 0.1,
				speed = math.clamp((to - from).Magnitude / seconds / 16, 0.4, 1.2),
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
		local function face(t: number, actor: string, pos: Vector3, target: Vector3)
			put(t, actor, pos, yawBetween(pos, target))
		end
		-- La estructura `id` sube de grado (PlotActor): se escribe 0,5 s después del martillazo.
		local function upgrade(t: number, id: string, level: number)
			add({ t = t, kind = "plotUpgrade", key = id, level = level })
		end
		-- Lleva el reloj de la escena a `to` en `over` segundos. LightingController lee `seconds` como los segundos que tardaría en
		-- recorrer 12 h (no como la duración del cambio), así que se calcula con la distancia. `from` es la hora de la que parte
		-- (la fijó antes un clock con seconds = 0, o un ramp anterior).
		local function ramp(t: number, from: number, to: number, over: number)
			add({ t = t, kind = "clock", hour = to, seconds = 12 * over / math.abs(to - from) })
		end
		local function startDay(day: number, hour: number?)
			local t0 = DAY_START[day]
			local from = hour or 6.2
			add({ t = t0, kind = "dayClock", show = true, day = day })
			-- Vuelve al amanecer (salto) y avanza hasta la tarde: la escena salta hacia atrás por el camino corto del reloj.
			add({ t = t0, kind = "clock", hour = from, seconds = 0 })
			ramp(t0 + 0.1, from, 17.5, DAY_LENGTH - 0.3)
		end

		-- ===== Rescate (0 a 6): el helicóptero despega y se aleja sin ellos
		add({ t = 0, kind = "letterbox" })
		-- Esconde la parcela real (borde, cartel y estructuras) que haya en el hueco de la escena; se repite al llegar
		-- por si el terreno de allí no estaba aún cargado al empezar.
		add({ t = 0, kind = "plotHide", at = pl(0, 0, 0), radius = 30 })
		add({ t = 5.5, kind = "plotHide", at = pl(0, 0, 0), radius = 30 })
		add({ t = 0.4, kind = "dayClock", show = true, day = 7 })
		add({ t = 0, kind = "clock", hour = 6.1, seconds = 0 })
		ramp(0.05, 6.1, 7.0, 5.6)
		ramp(6, 7.0, 7.5, 3)
		add({ t = 0, kind = "move", actor = "heli", pos = HELI_START, yaw = HELI_YAW, seconds = 0 })
		add({ t = 0.2, kind = "move", actor = "heli", pos = HELI_HOVER, yaw = HELI_YAW, seconds = 1.3 })
		add({ t = 1.6, kind = "move", actor = "heli", pos = HELI_OUT, yaw = HELI_YAW, seconds = 4.6 })
		add({ t = 0.4, kind = "caption", text = Strings.later("Rescatados… ¿y si te quedas?"), seconds = 2.6 })
		add({ t = 3.2, kind = "caption", text = Strings.later("♾️ Seguir sobreviviendo"), seconds = 2.6 })
		face(0, "avatar", CREW_AVATAR, HELI_START)
		face(0, "hunter", CREW_HUNTER, HELI_START)
		face(0, "medic", CREW_MEDIC, HELI_START)
		anim(0.5, "avatar", "Cheer", 1.6)
		anim(0.6, "hunter", "Cheer", 1.6)
		anim(0.7, "medic", "Cheer", 1.6)
		-- Se dan la vuelta hacia la plaza cuando ya se ha ido.
		face(3.0, "avatar", CREW_AVATAR, FIRE)
		face(3.0, "hunter", CREW_HUNTER, FIRE)
		face(3.0, "medic", CREW_MEDIC, FIRE)

		-- ===== La parcela (6 a 9): los tres corren a ella y se dibuja entera, en grado I
		add({ t = 6.0, kind = "plotMarker", at = pl(0, 0, 0), yaw = PLOT_YAW })
		for _, id in ORDER do
			local spot = layout[id]
			add({
				t = 6.0,
				kind = "plotPiece",
				key = id,
				id = id,
				level = 1,
				at = pl(spot.x, 0, spot.z),
				yaw = PLOT_YAW + spot.yaw,
			})
		end
		add({ t = 6.2, kind = "caption", text = Strings.later("Tu parcela viaja contigo"), seconds = 2.6 })
		local avatarStart, hunterStart, medicStart = pl(1, 0, -24), pl(-4, 0, -27), pl(5, 0, -27)
		put(6.0, "avatar", avatarStart, yawBetween(avatarStart, AVATAR_ARRIVE))
		put(6.0, "hunter", hunterStart, yawBetween(hunterStart, HUNTER_AT))
		put(6.0, "medic", medicStart, yawBetween(medicStart, MEDIC_AT))
		run(6.1, "avatar", avatarStart, AVATAR_ARRIVE, 2.2)
		run(6.1, "hunter", hunterStart, HUNTER_AT, 2.3)
		run(6.1, "medic", medicStart, MEDIC_AT, 2.3)
		face(8.45, "avatar", AVATAR_ARRIVE, PLOT_MID)
		face(8.5, "hunter", HUNTER_AT, PLOT_MID)
		face(8.55, "medic", MEDIC_AT, PLOT_MID)

		-- ===== Los días (9 a 21): cada uno, un corte al amanecer, martillazos y una o varias estructuras que suben
		add({ t = 9.3, kind = "caption", text = Strings.later("Mejórala día a día"), seconds = 3.2 })
		-- Día 8: Forja I a II
		startDay(8, 6.2)
		put(9.0, "avatar", STAND_FORGE, yawBetween(STAND_FORGE, FORGE_AT))
		put(9.0, "hunter", HUNTER_AT, yawBetween(HUNTER_AT, PLOT_MID))
		put(9.0, "medic", MEDIC_AT, yawBetween(MEDIC_AT, PLOT_MID))
		anim(9.4, "avatar", "Hammer", 0.8)
		upgrade(9.9, "Forge", 2)
		-- Día 9: Incubadora I a II
		startDay(9)
		put(12.0, "avatar", STAND_INCUBATOR, yawBetween(STAND_INCUBATOR, INCUBATOR_AT))
		anim(12.4, "avatar", "Hammer", 0.8)
		upgrade(12.9, "Incubator", 2)
		-- Día 10: Forja II a III y Nido I a II
		startDay(10)
		-- Los dos amigos se apartan de la línea cámara-avatar (el Cazador tapaba al avatar) y vuelven a la entrada a 18,0.
		face(15.0, "hunter", DAY10_HUNTER, PLOT_MID)
		face(15.0, "medic", DAY10_MEDIC, PLOT_MID)
		face(18.0, "hunter", HUNTER_AT, PLOT_MID)
		face(18.0, "medic", MEDIC_AT, PLOT_MID)
		put(15.0, "avatar", STAND_FORGE, yawBetween(STAND_FORGE, FORGE_AT))
		anim(15.3, "avatar", "Hammer", 0.8)
		upgrade(15.8, "Forge", 3)
		run(16.2, "avatar", STAND_FORGE, STAND_NEST, 0.5)
		face(16.75, "avatar", STAND_NEST, NEST_AT)
		anim(16.9, "avatar", "Hammer", 0.8)
		upgrade(17.4, "Nest", 2)
		-- Día 11: todo a III
		startDay(11)
		put(18.0, "avatar", STAND_CENTER, yawBetween(STAND_CENTER, NEST_AT))
		anim(18.2, "avatar", "Hammer", 0.8)
		anim(19.2, "avatar", "Hammer", 0.8)
		upgrade(18.6, "Incubator", 3)
		upgrade(19.0, "Nest", 3)
		upgrade(19.4, "Healer", 3)
		upgrade(19.8, "Garden", 3)
		upgrade(20.2, "Bed", 3)
		upgrade(20.6, "Chest", 3)
		anim(20.1, "hunter", "Cheer", 0.9)
		anim(20.2, "medic", "Cheer", 0.9)

		-- ===== Noche, Día 12 (21 a 27,6): el Caudillo ante la puerta sur
		-- El Caudillo sube de su escondite antes de la noche (empieza 400 studs bajo tierra: de día no se ve).
		add({ t = 20.9, kind = "stageShow", server = true })
		-- El reloj baja bajo la barra del jefe (BattleActor: alto NAME_HEIGHT 22 + 4 + BAR_HEIGHT 16 = 42 px desde +14 = 56; +8 de aire).
		add({ t = 21.0, kind = "dayClock", show = true, day = 12, drop = 52 })
		add({ t = 21.0, kind = "clock", hour = 18.5, seconds = 0 })
		ramp(21.1, 18.5, 19.5, 6.4)
		-- Luz fría y tenue que sigue a la cámara (la de Night): de noche cerrada, sin ella los tres salen negros.
		add({
			t = 21.0,
			kind = "light",
			follow = true,
			offset = Vector3.new(0, 3, 0),
			color = Color3.fromRGB(150, 170, 230),
			brightness = 0.6,
			range = 50,
		})
		add({ t = 21.3, kind = "caption", text = Strings.later("Los jefes vuelven más fuertes"), seconds = 3.4 })
		put(21.0, "avatar", NIGHT_AVATAR, yawBetween(NIGHT_AVATAR, BOSS_AT))
		put(21.0, "hunter", NIGHT_HUNTER, yawBetween(NIGHT_HUNTER, BOSS_AT))
		put(21.0, "medic", NIGHT_MEDIC, yawBetween(NIGHT_MEDIC, BOSS_AT))
		table.insert(events, BossChoreo.bar(21.2, Bosses.ChimpanceCaudillo.name, 1, 1))
		-- El rugido cae en el contrapicado que se acerca (22,6 a 25,2) y el pisotón en el plano bajo lateral (desde 25,2).
		table.insert(events, BossChoreo.bossAct(23.0, "Roar"))
		table.insert(events, BossChoreo.bossRoar(23.0))
		table.insert(events, BossChoreo.shake(23.1, 0.12, 0.8))
		table.insert(events, BossChoreo.bossAct(25.5, "Stomp"))
		table.insert(events, BossChoreo.shake(25.8, 0.1, 0.5))

		-- ===== Final (27,6 a 31,4): de vuelta en la parcela, ya de noche; título, logo y negro
		add({ t = 27.4, kind = "plotSign", show = false }) -- el cartel de la parcela tapaba el título
		add({ t = 27.5, kind = "dayClock", show = false })
		local endAvatar, endHunter, endMedic = pl(0, 0, -10), pl(-4, 0, -12), pl(4, 0, -12) -- fuera del Cofre (-8, -8,5) y la Incubadora (8, -8,5)
		local endCamera = pl(0, 2.5, -24)
		put(27.6, "avatar", endAvatar, yawBetween(endAvatar, endCamera))
		put(27.6, "hunter", endHunter, yawBetween(endHunter, endCamera))
		put(27.6, "medic", endMedic, yawBetween(endMedic, endCamera))
		anim(27.8, "avatar", "Cheer", 1.4)
		anim(27.9, "hunter", "Cheer", 1.4)
		anim(28.0, "medic", "Cheer", 1.4)
		add({
			t = 27.6,
			kind = "title",
			text = Strings.later("Modo infinito"),
			sub = Strings.later("¿Cuántos días aguantas?"),
			seconds = 2.6, -- el subtítulo «¿Cuántos días aguantas?» con 1,4 s se iba demasiado pronto
		})
		add({
			t = 30.4,
			kind = "logo",
			text = Strings.later("Primal Banana Islands"),
			sub = Strings.later("Monkey Survival"),
			seconds = 0.5,
		})
		-- Negro hasta el final: tras acabar la escena, y antes de la pantalla de «Heading back», salía medio segundo de día.
		add({ t = 30.6, kind = "fade", seconds = 0.6, toBlack = true })

		-- ===== Cámara. Ninguna a menos de 12 studs de un actor; las alturas son sobre el suelo del anchor.
		local shots: { CameraShot } = {
			-- Contrapicado del helicóptero que despega, con los tres de espaldas en primer término.
			{
				t0 = 0,
				t1 = 3,
				a = cameraKey(Vector3.new(-13, 2.2, 27), Vector3.new(18, 7, 10), 58),
				b = cameraKey(Vector3.new(-12, 2.4, 26), Vector3.new(36, 22, -24), 50),
			},
			-- Grúa que baja hacia los tres, ya sin helicóptero.
			{
				t0 = 3,
				t1 = 6,
				a = cameraKey(Vector3.new(-6, 26, 30), Vector3.new(6, 2, 8), 58),
				b = cameraKey(Vector3.new(-10, 9, 25), Vector3.new(3, 3, 8), 52),
			},
			-- Plano abierto de la parcela desde fuera del borde.
			{
				t0 = 6,
				t1 = 9,
				a = cameraKey(pl(-30, 8, -20), pl(0, 2.5, 2), 55),
				b = cameraKey(pl(-26, 9, -24), pl(0, 2.5, 3), 52),
			},
			-- Día 8: la Forja, de lado.
			{
				t0 = 9,
				t1 = 12,
				a = cameraKey(pl(-30, 6, 6), pl(-8, 3, 7.5), 52),
				b = cameraKey(pl(-27, 6.5, 2), pl(-8, 3.5, 7.5), 46),
			},
			-- Día 9: la Incubadora, desde el otro lado.
			{
				t0 = 12,
				t1 = 15,
				a = cameraKey(pl(32, 6, -16), pl(8, 3, -8.5), 52),
				b = cameraKey(pl(29, 6.5, -12), pl(8, 3.2, -8.5), 46),
			},
			-- Día 10: la Forja y el Nido, de frente desde la entrada.
			{
				t0 = 15,
				t1 = 18,
				a = cameraKey(pl(-8, 7, -32), pl(-4, 4, 6), 48),
				b = cameraKey(pl(-2, 8, -30), pl(-2, 4, 6), 44),
			},
			-- Día 11: plano general en grúa, con las gemas encendidas.
			{
				t0 = 18,
				t1 = 21,
				a = cameraKey(pl(-22, 8, -22), pl(0, 3, 2), 55),
				b = cameraKey(pl(-16, 16, -28), pl(0, 3, 2), 58),
			},
			-- Contraplano desde detrás de los tres hacia el Caudillo, que espera fuera de la puerta.
			{
				t0 = 21,
				t1 = 22.6,
				a = cameraKey(Vector3.new(0, 3, 46), Vector3.new(0, 9, 100), 55),
				b = cameraKey(Vector3.new(1, 3.2, 49), Vector3.new(0, 9, 100), 50),
			},
			-- Contrapicado que se acerca al Caudillo girando (el rugido): fuera de la empalizada, a 15 studs o más.
			{
				t0 = 22.6,
				t1 = 25.2,
				a = cameraKey(Vector3.new(16, 4, 84), Vector3.new(0, 7.5, 100), 55),
				b = cameraKey(Vector3.new(8, 3, 86), Vector3.new(0, 7.5, 100), 58),
			},
			-- Plano bajo lateral con travelling (el pisotón).
			{
				t0 = 25.2,
				t1 = 27.6,
				-- A 4,5 de altura: con 1,5 la hierba tapaba al jefe (QA de Endless, ver docs/qa/Endless).
				a = cameraKey(Vector3.new(-14, 4.5, 92), Vector3.new(0, 9, 100), 52),
				b = cameraKey(Vector3.new(-10, 5, 90), Vector3.new(0, 9, 100), 52),
			},
			-- Cierre: el plano se aleja de la parcela de noche.
			{
				t0 = 27.6,
				t1 = ENDLESS_SECONDS,
				a = cameraKey(endCamera, pl(0, 7, 4), 52),
				b = cameraKey(pl(3, 20, -60), pl(0, 4, 3), 60),
			},
		}

		-- ===== Actores. Los tres con snap (el suelo del Basecamp no es llano). El helicóptero es un prop, como en el Rescate.
		local actors: { [string]: { [string]: any } } = {
			avatar = {
				kind = "localPlayer",
				copy = true,
				role = "Guerrero",
				weapon = "StoneAxe",
				snap = true,
				pos = CREW_AVATAR,
				yaw = 0,
			},
			hunter = {
				kind = "dummy",
				role = "Cazador",
				armor = "VolcanicArmor",
				weapon = "StonePick",
				snap = true,
				pos = CREW_HUNTER,
				yaw = 0,
			},
			medic = {
				kind = "dummy",
				role = "Medico",
				outfit = "CeibaOfLifeOutfit",
				weapon = false,
				snap = true,
				pos = CREW_MEDIC,
				yaw = 0,
			},
			heli = {
				kind = "prop",
				build = function(anchor: CFrame): Model
					local model = HelicopterModel.build()
					model:PivotTo(anchor * CFrame.new(HELI_START) * CFrame.Angles(0, math.rad(HELI_YAW), 0))
					HelicopterModel.animate(model)
					return model
				end,
			},
		}

		return {
			duration = ENDLESS_SECONDS + 0.6, -- el negro final se sostiene hasta que acaba la escena
			audience = "Self",
			freeze = false,
			skippable = true,
			hour = 6.1,
			redMoonOff = true,
			-- El suelo cargado donde se pisa y se filma: la plaza, la parcela (centro, entrada y cámaras) y la puerta sur.
			waitTerrain = {
				FIRE,
				Vector3.new(HELI_START.X, 0, HELI_START.Z), -- el suelo bajo el helicóptero (con su y = 4,5 la espera nunca se cumplía)
				pl(0, 0, 0),
				pl(-30, 0, 6),
				pl(32, 0, -16),
				pl(0, 0, -27),
				pl(-34, 0, -34),
				pl(0, 0, 14),
				Vector3.new(0, 0, 46),
				NIGHT_AVATAR,
				Vector3.new(0, 0, 81),
				BOSS_AT,
			},
			actors = actors,
			camera = cutShots(shots),
			events = events,
		}
	end

	local ok, built = pcall(build)
	if ok then
		out.Endless = built :: Scene
	else
		warn(`Cinematics: no se pudo construir la escena Endless: {built}`)
	end
	return out
end)()

return { Endless = endlessScenes.Endless }
