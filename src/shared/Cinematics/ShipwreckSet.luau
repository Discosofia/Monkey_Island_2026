--!strict
-- Decorado de la escena «Shipwreck» (Fase 25, G6a): el carguero «Esperanza» del Lobby navegando de noche con gaviotas, y
-- el puente de mando donde está el avatar del jugador y adonde llega la cámara. Solo cliente (lo usa ShipwreckController
-- del Lobby) y el modo edición (preview). Sin Remotes, Settings ni CombatClient.
--
--   buildShip()        clona Workspace.Naufragio.Esperanza y lo deja limpio e intacto: sin humo, sin luces averiadas (ni su
--                      etiqueta), sin el boquete (planchas reventadas y cubierta hundida; el hueco del casco se tapa con
--                      copias espejo de las planchas de babor) y con las luces de noche encendidas y tenues. La caja maciza
--                      del puente se sustituye por una cáscara fina con su interior (BridgeModel), y los cristales del puente
--                      son paneles transparentes. Todo anclado: se mueve con PivotTo.
--   buildGull()        una gaviota (GullModel.build, con brillo de noche).
--   buildAvatar()      copia del personaje del jugador local de pie en el puente, mirando a proa, con la animación de reposo.
--   positionAt(t), frameAt(t), poseAt(t)  dónde está el barco en el segundo t: posición del pivote en el mar, marco sin
--                      balanceo (el de la cámara: x a proa, y arriba, z a estribor, origen en el pivote) y marco con
--                      balanceo (el del modelo). El barco navega hacia -X con la proa por delante.
--   install(Sequencer) registra los eventos:
--     shipSail         pone el barco en poseAt(t) cada cuadro (ctx.actors.ship, el actor prop de la escena).
--     shipAvatar       pone al avatar en el puente del barco (ctx.actors.ship).
--     birds { seconds }  las gaviotas giran alrededor del barco hasta "seconds".
--     night { midAt?, deepAt? }  luz de noche del Lobby, que baja cada cuadro de la luna clara del principio (NIGHT.start) a
--                      la noche cerrada en midAt (19 s, NIGHT.mid) y a casi oscuridad en deepAt (NIGHT.deep); se
--                      devuelve al acabar la escena.
--     storm { seconds }  tormenta (G6b): en "seconds" s lleva la niebla, la luz, la luna, el oleaje del agua y el viento
--                      (Workspace.GlobalWind) a STORM.look; lo aplica night en cada cuadro y restoreNight lo devuelve. El
--                      balanceo y el avance del barco (poseAt, positionAt) dependen de stormAmount(t), no del evento.
--     rain { seconds }  lluvia de dos capas sobre piezas invisibles que siguen a la cámara.
--     lightning { side?, thunderDelay?, strength?, bolt? }  destello doble, tronco de Neon al este y trueno (Sfx).
--   applyNight / restoreNight  la hora, la luz de noche y la luna roja del cielo del Lobby, guardando y devolviendo los
--                      valores de antes (ClockTime, Lighting, Atmosphere, ColorCorrection, Bloom y Sky: MoonTextureId,
--                      MoonAngularSize y CelestialBodiesShown).
--   moonInfo(hour)     { direction, elevation, azimuth } de la luna a esa hora, midiendo Lighting:GetMoonDirection() con
--                      ese ClockTime un instante (y devolviéndolo). Sirve para G6b y G6c (en G6c la hora será ~5,3).
--   setCourse(hour?, offsetDeg?)  rumbo del barco: la proa (+X local) apunta al azimut horizontal de la luna de esa hora,
--                      yaw = atan2(-h.Z, h.X) + offset (h = (dir.X, dir.Z)); con offset 8° la luna queda a estribor del
--                      eje. La recta de 21 s (12 studs/s) pasa por (400, 0, 40) a los 7 s y se desplaza si no cabe en
--                      el mar abierto (x 300 a 550, z -150 a 150). Las escenas la llaman en su campo prepare, antes de
--                      construir el barco y la cámara; positionAt, frameAt y poseAt dependen de ella.
--   cameraMoonAngles(puntos, tiempos)  ángulo entre el eje de la cámara y la luna, para calibrar planos.
--   findCoplanar(modelo, soloNuevas?)  pares de piezas con caras coplanares (parpadeo); checkCamera(barco, puntos, desde)  puntos de
--                      cámara dentro de sólidos o a menos de 1,2 del avatar. preview() los ejecuta y avisa con warn.
--   preview(parent?, { t?, night?, nightT?, storm? }) lo coloca todo en el mundo en modo edición (sin escena) para capturarlo; clearPreview lo quita.
--
-- El mar del Lobby está en y = 0 y el barco flota con su línea de flotación (la franja negra del casco, a y local 4,4)
-- a esa altura. Todos los números de arranque están arriba, para tocarlos con capturas.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BridgeModel = require(script.Parent.Parent.BridgeModel)
local Config = require(script.Parent.Parent.Config)
local GullModel = require(script.Parent.Parent.GullModel)
local Sfx = require(script.Parent.Parent.Sfx)
local RescueCrew = require(script.Parent.RescueCrew)
local Sequencer = require(script.Parent.Sequencer)

local ShipwreckSet = {}

-- Navegación: el barco avanza SAIL_SPEED studs por segundo en línea recta con la proa hacia la luna (ver setCourse); en la
-- tormenta frena (STORM.slow). WATERLINE: y local de la línea de flotación (2 filas de casco de 2,2 de LobbyBuilder). El
-- balanceo es suave: altura, cabeceo y balanceo en grados, con sus periodos en segundos (en la tormenta crece: STORM).
local SAIL_SPEED = 12 -- studs por segundo
local SAIL_SECONDS = 31 -- duración de la escena: el recorrido entero que debe caber en el mar
-- RUTA DEL VIAJE (los números que se tocan para cambiar de sitio): center = punto del mar por donde pasa el barco a los
-- centerSeconds s (el tramo de 14 s va de 0 a 14); bowOffsetDeg = grados a estribor de la proa a los que queda la luna; zone =
-- rectángulo de mar abierto donde debe caber la recta entera de la línea central (la recta se desplaza lo mínimo si se sale;
-- las gaviotas vuelan hasta 40 studs a su alrededor, así que la zona deja ese margen respecto al borde del agua). Mar de
-- este emplazamiento (al este del Lobby): x de 250 a 600 y z de -200 a 200, con una sola isla lejana a la vista.
local ROUTE = {
	center = Vector3.new(430, 0, 40),
	centerSeconds = 7,
	bowOffsetDeg = 8,
	zone = { x0 = 280, x1 = 580, z0 = -150, z1 = 150 },
	-- Hasta dónde pueden llegar las cámaras (checkLook avisa si una sale).
	bounds = { x0 = 270, x1 = 590, z0 = -170, z1 = 170 },
}
-- Hora fija de la escena (noche cerrada con estrellas; la luna baja sobre el horizonte, ~9° de elevación a las 18,8) y la luna
-- roja del evento de luna roja de la Isla.
local SCENE_HOUR = 18.8
local MOON_SIZE = 22 -- MoonAngularSize: grande y legible cerca del horizonte
local WATERLINE = 4.4
local HEAVE, PITCH, ROLL = 0.4, 1.5, 2.5
local PERIOD_HEAVE, PERIOD_ROLL = 5.2, 6.3

-- LA TORMENTA (G6b). Todos los números, para tocarlos con capturas. Entra a los 19 s: el mar y el barco crecen entre seaFrom y
-- seaTo (poseAt), y el evento storm lleva el cielo, la niebla y el viento a "look" en los segundos que diga el evento.
type StormLook = { target: string, property: string, value: any }
local STORM_WIND = Vector3.new(30, 0, 22) -- studs/s, hacia donde sopla (mundo)
local STORM = {
	seaFrom = 19, -- el mar empieza a crecer
	seaTo = 23, -- y llega a su máximo
	-- Amplitudes del barco con el mar al máximo (heave en studs, pitch y roll en grados): sustituyen a HEAVE, PITCH y ROLL.
	heave = 1.6,
	pitch = 4.5,
	roll = 11,
	-- Segundo armónico del balanceo (para que no sea un seno puro): fracción de la amplitud, su periodo (fracción del
	-- principal) y su fase.
	harmonic = 0.35,
	harmonicPeriod = 0.47,
	harmonicPhase = 1.3,
	-- Velocidad del barco al luchar contra el mar (fracción de SAIL_SPEED); se alcanza en seaTo (ver sailDistance).
	slow = 0.02, -- casi parado: con 0,4 el recorrido de 31 s (300 studs) no cabía en la zona de mar (280 a 580) y la cámara de salida quedaba a 45 studs fuera
	-- Lo que cambia el evento storm (valor final); lo demás de la luz lo sigue llevando "night".
	look = {
		{ target = "atmosphere", property = "Density", value = 0.62 },
		{ target = "atmosphere", property = "Haze", value = 6 },
		{ target = "atmosphere", property = "Color", value = Color3.new(0.30, 0.34, 0.42) },
		{ target = "atmosphere", property = "Decay", value = Color3.new(0.14, 0.16, 0.20) },
		{ target = "atmosphere", property = "Glare", value = 0 },
		-- Menos luz, pero la justa para leer los planos entre rayos.
		{ target = "lighting", property = "Brightness", value = 0.5 },
		{ target = "lighting", property = "Ambient", value = Color3.new(0.17, 0.21, 0.32) },
		{ target = "lighting", property = "OutdoorAmbient", value = Color3.new(0.22, 0.27, 0.40) },
		-- La luna roja se tapa al acabar la rampa (la niebla ya la ha borrado casi del todo).
		{ target = "sky", property = "CelestialBodiesShown", value = false },
		{ target = "terrain", property = "WaterWaveSize", value = 1 },
		{ target = "terrain", property = "WaterWaveSpeed", value = 45 },
		-- Viento fuerte: mueve palmeras y hierba del fondo y inclina la lluvia.
		{ target = "workspace", property = "GlobalWind", value = STORM_WIND },
	} :: { StormLook },
	wind = STORM_WIND,
	-- Lluvia: dos capas sobre una pieza que sigue a la cámara. height = altura sobre la cámara, side = lado de la pieza,
	-- rate = gotas por segundo con la lluvia entera, speed = velocidad de caída, drift = fracción del viento que las inclina,
	-- squash negativo = la gota se alarga en raya.
	rain = {
		{
			height = 26,
			side = 90,
			rate = 2200,
			speed = 70,
			size = 0.22,
			lifetime = 1.2,
			transparency = 0.3,
			squash = -2,
		},
		{
			height = 14,
			side = 34,
			rate = 1100,
			speed = 95,
			size = 0.34,
			lifetime = 0.55,
			transparency = 0.2,
			squash = -2.5,
		},
	},
	rainDrift = 0.8,
	-- Rayo. flash: cuánto suben Lighting.Brightness y ExposureCompensation en el destello (por la fuerza del evento);
	-- bolt: tronco en zigzag de Neon (steps piezas, tope 12) al horizonte, a minDist-maxDist studs, con spread grados de abanico
	-- (side del evento, de -1 a 1) y wobble studs de quiebro; dur = pulso del destello doble (encendido, apagado,
	-- encendido) y fade = lo que tarda en apagarse.
	flash = { brightness = 3.2, exposure = 1.2 },
	bolt = {
		minDist = 250,
		maxDist = 400,
		top = 340,
		steps = 12,
		thickness = 5,
		wobble = 16,
		spread = 28,
		color = Color3.fromRGB(215, 230, 255),
	},
	pulse = { on1 = 0.07, off = 0.08, on2 = 0.12, fade = 0.25 },
	thunderVolume = 0.8,
}

-- Avatar en el puente: tamaño (el puente tiene 3,6 de alto) y animación de reposo.
local AVATAR_SCALE = 0.75
-- Medidas del puente real (LobbyBuilder.buildSuperstructure): centro en x, suelo (techo del Castillo, 19,9) y cuánto sube el
-- techo para que quepa el avatar. El suelo del interior queda FLOOR_LIFT por encima del techo del Castillo (si no, las dos
-- caras coplanares parpadean). Los ojos del avatar están a EYE_RATIO veces su escala sobre el suelo.
local BRIDGE_CENTER_X = -29
local BRIDGE_FLOOR_Y = 19.98
local BRIDGE_RAISE = 1.2
local BRIDGE_FLOOR_LIFT = 0.08
local EYE_RATIO = 4.6
-- Piezas sobre el techo del puente que suben con él.
local ROOF_PARTS = {
	TechoPuente = true,
	MastilRadar = true,
	Cruceta = true,
	Radar = true,
	Domo = true,
	LuzNavegacion = true,
	LuzTope = true,
}
local AVATAR_LIGHT = 0.35 -- brillo de la luz tenue sobre su torso
local AVATAR_LIGHT_OFF = 29.5 -- segundo en que empieza a apagarse (con el fundido a negro)
local AVATAR_LIGHT_FADE = 1.5 -- lo que tarda en apagarse
local IDLE_FALLBACK = "rbxassetid://507766388" -- reposo R15 de Roblox, si el personaje no trae el suyo

-- Boquete del casco (LobbyBuilder.isHole: estribor, tramos 6 a 8): de x = -9,5 a 4,75 y por debajo de y = 11. Se tapa con
-- copias espejo de las planchas de babor. Y la cubierta del tramo 7, que el barco encallado tiene hundida.
local BREACH_X0, BREACH_X1, BREACH_TOP = -9.5, 4.75, 11
-- Un poco más alta (0,07) y sin las puntas de 0,1 de las vecinas, para no quedar coplanar con ellas.
local DECK_PATCH_X, DECK_PATCH_Y = -2.375, 12.87
local DECK_PATCH_SIZE = Vector3.new(4.75, 0.6, 21.4)

-- Cristales del puente: transparentes para ver al avatar desde fuera.
local BRIDGE_GLASS = Color3.fromRGB(120, 150, 175)
local BRIDGE_GLASS_TRANSPARENCY = 0.55
-- Los cristales pequeños de los costados del puente (nivel 3 de LobbyBuilder, y 21,9 de alto) los sustituyen los paneles
-- del interior: se quitan estos.
local BRIDGE_SIDE_WINDOW_Y0, BRIDGE_SIDE_WINDOW_Y1 = 21.5, 22.4

-- Luces de la noche en el barco, tenues: ventanas encendidas (una de cada cuatro sigue apagada), tres con PointLight, y
-- el mástil. Con las dos del puente no pasan de 8.
local WINDOW_LIT = Color3.fromRGB(200, 150, 80)
local WINDOW_LIGHTS = 3
local WINDOW_LIGHT_BRIGHTNESS, WINDOW_LIGHT_RANGE = 0.5, 12
local MAST_LIGHT = Color3.fromRGB(190, 210, 255) -- la luz de luna: muy suave, azul pálido, en lo alto del palo
local WARM_LIGHT = Color3.fromRGB(255, 196, 110)

-- Gaviotas: radio y altura (sobre el mar) del círculo, vuelta en radianes por segundo (el signo es el sentido), fase y
-- aleteo (Hz, amplitud en radianes).
local GULLS = {
	{ radius = 22, height = 26, turn = 0.55, phase = 0, flapHz = 2.8, flapAmp = 0.55 },
	{ radius = 28, height = 34, turn = -0.42, phase = 1.1, flapHz = 2.3, flapAmp = 0.5 },
	{ radius = 34, height = 40, turn = 0.36, phase = 2.4, flapHz = 3.1, flapAmp = 0.6 },
	{ radius = 40, height = 46, turn = -0.3, phase = 3.7, flapHz = 2.5, flapAmp = 0.45 },
	{ radius = 25, height = 44, turn = 0.48, phase = 4.6, flapHz = 3.4, flapAmp = 0.55 },
	{ radius = 37, height = 29, turn = -0.5, phase = 5.5, flapHz = 2.1, flapAmp = 0.5 },
}
local GULL_BANK = 0.3 -- radianes que se inclina cada gaviota al girar

-- Luz de la noche (Lighting del Lobby; LobbyBuilder fija 17,6, un atardecer). Cada propiedad tiene tres valores: el del
-- principio (luna clara), el de MID_AT segundos (la noche de siempre) y el de DEEP_AT (casi oscuridad); entre uno y otro, lineal.
-- target: "lighting", "atmosphere", "grade" (NaufragioColor) o "bloom" (NaufragioBrillo). El umbral del Bloom sube para que las
-- ventanas no lo saturen.
local NIGHT_MID_AT, NIGHT_DEEP_AT = 19, 21
local NIGHT_DEEP_AT_STORM = 31 -- con tormenta, la luz tarda hasta aquí en llegar al fondo (no se oscurece antes de tiempo)
type NightKey = { target: string, property: string, start: any?, mid: any?, deep: any? }
local NIGHT: { NightKey } = {
	-- ClockTime: lo pone applyNight con la hora de la escena (SCENE_HOUR o la del evento night).
	{ target = "lighting", property = "ClockTime", start = 0, mid = 0, deep = 0 },
	-- Luna roja llena (la textura del evento de luna roja de la Isla) grande en el cielo del Lobby.
	{
		target = "sky",
		property = "MoonTextureId",
		start = Config.Moon.RedMoonTexture,
		mid = Config.Moon.RedMoonTexture,
		deep = Config.Moon.RedMoonTexture,
	},
	{ target = "sky", property = "MoonAngularSize", start = MOON_SIZE, mid = MOON_SIZE, deep = MOON_SIZE },
	{ target = "sky", property = "CelestialBodiesShown", start = true, mid = true, deep = true },
	{ target = "lighting", property = "Brightness", start = 1.3, mid = 0.6, deep = 0.35 },
	{
		target = "lighting",
		property = "Ambient",
		start = Color3.new(0.18, 0.22, 0.34),
		mid = Color3.new(0.10, 0.13, 0.22),
		deep = Color3.new(0.06, 0.08, 0.14),
	},
	{
		target = "lighting",
		property = "OutdoorAmbient",
		start = Color3.new(0.26, 0.32, 0.50),
		mid = Color3.new(0.14, 0.18, 0.30),
		deep = Color3.new(0.09, 0.11, 0.20),
	},
	{ target = "lighting", property = "ExposureCompensation", start = 0.35, mid = 0.2, deep = 0.1 },
	{
		target = "atmosphere",
		property = "Color",
		start = Color3.new(0.47, 0.50, 0.78),
		mid = Color3.new(0.36, 0.42, 0.68),
		deep = Color3.new(0.27, 0.31, 0.54),
	},
	{
		target = "atmosphere",
		property = "Decay",
		start = Color3.new(0.10, 0.14, 0.28),
		mid = Color3.new(0.10, 0.14, 0.28),
		deep = Color3.new(0.10, 0.14, 0.28),
	},
	{ target = "atmosphere", property = "Density", start = 0.48, mid = 0.5, deep = 0.52 },
	{ target = "atmosphere", property = "Glare", start = 0.1, mid = 0.1, deep = 0.1 },
	{ target = "atmosphere", property = "Haze", start = 1, mid = 1, deep = 1 },
	{
		target = "grade",
		property = "TintColor",
		start = Color3.new(0.88, 0.94, 1),
		mid = Color3.new(0.85, 0.92, 1),
		deep = Color3.new(0.80, 0.88, 1),
	},
	{ target = "bloom", property = "Threshold", start = 2.6, mid = 2.6, deep = 2.6 },
	-- Solo de la tormenta (STORM.look): sin valor de noche, parten del que tenía el mundo y se guardan para devolverlos.
	{ target = "terrain", property = "WaterWaveSize" },
	{ target = "terrain", property = "WaterWaveSpeed" },
	{ target = "workspace", property = "GlobalWind" },
}

local NEW_ATTRIBUTE = "ShipwreckNew" -- marca las piezas que añade este módulo (findCoplanar)
local PREVIEW_NAME = "ShipwreckPreview"
local PREVIEW_CAMERA_FROM = 11 -- desde este segundo la cámara está a menos de 40 studs del barco
local PREVIEW_SECONDS = 14 -- segundo de la escena donde se coloca la vista previa (252 studs de la salida)

----------------------------------------------------------------------------------------------------------------------
-- Dónde está el barco

-- Fuerza del mar en el segundo t: 0 hasta STORM.seaFrom, 1 desde STORM.seaTo, con smoothstep entre medias.
local function stormAmount(t: number): number
	local u = math.clamp((t - STORM.seaFrom) / (STORM.seaTo - STORM.seaFrom), 0, 1)
	return u * u * (3 - 2 * u)
end

-- Studs recorridos por el barco en el segundo t. Hasta STORM.seaFrom va a SAIL_SPEED; después frena con la misma curva
-- smoothstep hasta SAIL_SPEED * STORM.slow (integral cerrada de la rampa: D * (u^3 - u^4 / 2) + lo que pasa del final).
local function sailDistance(t: number): number
	local tau = math.max(t - STORM.seaFrom, 0)
	local span = STORM.seaTo - STORM.seaFrom
	local u = math.min(tau / span, 1)
	local lost = span * (u ^ 3 - u ^ 4 / 2) + math.max(tau - span, 0) * 1
	return SAIL_SPEED * (t - (1 - STORM.slow) * lost)
end

-- Rumbo del viaje (setCourse): giro del barco alrededor de Y (la proa es +X local), dirección de avance y punto de salida.
type MoonInfo = { direction: Vector3, elevation: number, azimuth: number }
local course = {
	yaw = math.pi, -- por defecto, hacia -X
	forward = Vector3.new(-1, 0, 0),
	start = ROUTE.center + Vector3.new(SAIL_SPEED * ROUTE.centerSeconds, 0, 0),
	info = nil :: MoonInfo?,
}

ShipwreckSet.HOUR = SCENE_HOUR
ShipwreckSet.ROUTE = ROUTE -- centro, desvío de la luna y zona de mar de la ruta (se pueden cambiar antes de setCourse)
-- Los ojos del avatar (marco del barco): la cámara final se pone detrás de ellos.
ShipwreckSet.AVATAR_EYE =
	Vector3.new(BRIDGE_CENTER_X + BridgeModel.AVATAR.X, BRIDGE_FLOOR_Y + EYE_RATIO * AVATAR_SCALE, 0)

-- La luna en la hora "hour" (0-24): pone Lighting.ClockTime un instante, lee Lighting:GetMoonDirection() y lo devuelve. La
-- luna está fija en el mundo mientras la hora esté fija. direction = vector unitario hacia la luna; elevation = asin(y) en
-- radianes sobre el horizonte; azimuth = atan2(x, z) en radianes. Si GetMoonDirection falla, una luna baja hacia -Z.
function ShipwreckSet.moonInfo(hour: number): MoonInfo
	local previous = Lighting.ClockTime
	Lighting.ClockTime = hour
	local ok, direction = pcall(function()
		return Lighting:GetMoonDirection()
	end)
	Lighting.ClockTime = previous
	local dir: Vector3 = if ok
			and typeof(direction) == "Vector3"
			and direction.Magnitude > 0.01
		then (direction :: Vector3).Unit
		else Vector3.new(0, 0.16, -1).Unit
	return { direction = dir, elevation = math.asin(dir.Y), azimuth = math.atan2(dir.X, dir.Z) }
end

-- Fija el rumbo del barco hacia la luna de la hora "hour" (SCENE_HOUR por defecto): la proa apunta al azimut horizontal de
-- la luna girada "offsetDeg" grados (ROUTE.bowOffsetDeg por defecto; positivo = la luna queda a estribor del eje). El recorrido
-- es una recta de SAIL_SPEED studs/s que pasa por ROUTE.center a los ROUTE.centerSeconds s y se desplaza, si hace falta, para
-- que los SAIL_SECONDS s enteros caigan dentro de la zona de mar abierto. Hay que llamarla antes de construir el barco
-- y la cámara (la escena lo hace en su campo prepare). Devuelve la luna.
--   yaw del rumbo = atan2(-h.Z, h.X) + offset, con h el rumbo horizontal (x, z) de GetMoonDirection: la proa +X local
--   gira a (cos yaw, 0, -sin yaw) en el mundo.
function ShipwreckSet.setCourse(hour: number?, offsetDeg: number?): MoonInfo
	local info = ShipwreckSet.moonInfo(hour or SCENE_HOUR)
	local heading = Vector3.new(info.direction.X, 0, info.direction.Z)
	local yaw = math.pi
	if heading.Magnitude > 0.01 then
		yaw = math.atan2(-heading.Z, heading.X) + math.rad(if offsetDeg == nil then ROUTE.bowOffsetDeg else offsetDeg)
	end
	local forward = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	local start = ROUTE.center - forward * sailDistance(ROUTE.centerSeconds)
	local finish = start + forward * sailDistance(SAIL_SECONDS)
	-- Desplazamiento de la recta entera para que quepa en el rectángulo (si es más larga que él, centrada).
	local function shift(low: number, high: number, zoneLow: number, zoneHigh: number): number
		local a, b = math.min(low, high), math.max(low, high)
		if b - a > zoneHigh - zoneLow then
			return (zoneLow + zoneHigh) / 2 - (a + b) / 2
		elseif a < zoneLow then
			return zoneLow - a
		elseif b > zoneHigh then
			return zoneHigh - b
		end
		return 0
	end
	local zone = ROUTE.zone
	start += Vector3.new(shift(start.X, finish.X, zone.x0, zone.x1), 0, shift(start.Z, finish.Z, zone.z0, zone.z1))
	course = { yaw = yaw, forward = forward, start = start, info = info }
	return info
end

-- La luna del último setCourse (nil si aún no se llamó).
function ShipwreckSet.course(): MoonInfo?
	return course.info
end

-- Ángulo en grados entre el eje de la cámara y la dirección de la luna del último setCourse, en cada segundo de "times" (con
-- el punto de la lista de cámara más cercano). Para calibrar los planos.
function ShipwreckSet.cameraMoonAngles(
	points: { { t: number, pos: Vector3, look: Vector3 } },
	times: { number }
): { number }
	local info = course.info
	local result: { number } = {}
	if not info then
		return result
	end
	for _, time in times do
		local nearest = points[1]
		for _, point in points do
			if math.abs(point.t - time) < math.abs(nearest.t - time) then
				nearest = point
			end
		end
		local axis = (nearest.look - nearest.pos).Unit
		table.insert(result, math.deg(math.acos(math.clamp(axis:Dot(info.direction), -1, 1))))
	end
	return result
end

function ShipwreckSet.positionAt(t: number): Vector3
	return course.start + course.forward * sailDistance(t)
end

ShipwreckSet.stormAmount = stormAmount

-- Marco del barco sin balanceo: la proa (+X local) mira al rumbo y el origen del marco (el pivote del modelo) queda
-- WATERLINE por debajo del mar, así que el punto de la línea de flotación está en y = 0.
function ShipwreckSet.frameAt(t: number): CFrame
	return CFrame.new(ShipwreckSet.positionAt(t)) * CFrame.Angles(0, course.yaw, 0) * CFrame.new(0, -WATERLINE, 0)
end

-- Con balanceo: sube y baja, cabecea y se balancea girando alrededor del punto de la línea de flotación.
-- En la tormenta (stormAmount) las amplitudes crecen de las de calma a las de STORM y entra un segundo armónico; con s = 0
-- sale el mismo movimiento de antes (sin saltos a los 19 s).
function ShipwreckSet.poseAt(t: number): CFrame
	local s = stormAmount(t)
	local tau = 2 * math.pi * t
	local second = STORM.harmonic * s
	local heaveAmp = HEAVE + (STORM.heave - HEAVE) * s
	local pitchAmp = PITCH + (STORM.pitch - PITCH) * s
	local rollAmp = ROLL + (STORM.roll - ROLL) * s
	local heave = heaveAmp
		* (
			math.sin(tau / PERIOD_HEAVE)
			+ second * math.sin(tau / (PERIOD_HEAVE * STORM.harmonicPeriod) + STORM.harmonicPhase)
		)
	local pitch = math.rad(pitchAmp)
		* (
			math.sin(tau / PERIOD_HEAVE + math.pi / 2)
			+ second * math.sin(tau / (PERIOD_HEAVE * STORM.harmonicPeriod) + STORM.harmonicPhase + 2)
		)
	local roll = math.rad(rollAmp)
		* (
			math.sin(tau / PERIOD_ROLL)
			+ second * math.sin(tau / (PERIOD_ROLL * STORM.harmonicPeriod * 0.9) + STORM.harmonicPhase + 4)
		)
	return CFrame.new(ShipwreckSet.positionAt(t) + Vector3.new(0, heave, 0))
		* CFrame.Angles(0, course.yaw, 0)
		* CFrame.Angles(roll, 0, pitch)
		* CFrame.new(0, -WATERLINE, 0)
end

----------------------------------------------------------------------------------------------------------------------
-- El barco

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local point = Instance.new("PointLight")
	point.Color = color
	point.Range = range
	point.Brightness = brightness
	point.Shadows = false
	point.Parent = parent
end

function ShipwreckSet.buildGull(): (Model, GullModel.Joints)
	return GullModel.build({ glow = true })
end

-- Tapa el boquete del casco con copias espejo (z -> -z) de las planchas de babor que caen en su hueco (las de estribor
-- que aún existen, arriba y abajo del boquete, no se duplican).
local function closeBreach(ship: Model, frame: CFrame)
	local inverse = frame:Inverse()
	local starboard: { Vector3 } = {}
	local port: { BasePart } = {}
	for _, child in ship:GetChildren() do
		if child:IsA("BasePart") and child.Name == "Chapa" then
			local position = (inverse * child.CFrame).Position
			if position.Z > 0 then
				table.insert(starboard, position)
			else
				table.insert(port, child)
			end
		end
	end
	for _, plate in port do
		local rel = inverse * plate.CFrame
		local p = rel.Position
		if p.X > BREACH_X0 and p.X < BREACH_X1 and p.Y < BREACH_TOP then
			local exists = false
			for _, other in starboard do
				if math.abs(other.X - p.X) < 0.4 and math.abs(other.Y - p.Y) < 0.4 then
					exists = true
					break
				end
			end
			if not exists then
				local x, y, z = rel.XVector, rel.YVector, rel.ZVector
				local mirrored = CFrame.fromMatrix(
					Vector3.new(p.X, p.Y, -p.Z),
					Vector3.new(x.X, x.Y, -x.Z),
					Vector3.new(y.X, y.Y, -y.Z),
					Vector3.new(-z.X, -z.Y, z.Z)
				)
				-- Un poco más pequeña (sin la mitad de las puntas de 0,1 de las planchas) y 0,05 hacia dentro: las caras
				-- no quedan coplanares con las vecinas.
				local copy = plate:Clone()
				copy.Size = plate.Size - Vector3.new(0, 0.1, 0.1)
				local outward = mirrored.XVector
				if outward.Z < 0 then
					outward = -outward
				end
				copy.CFrame = frame * (mirrored - outward * 0.05)
				copy:SetAttribute(NEW_ATTRIBUTE, true)
				copy.Parent = ship
			end
		end
	end
end

-- El carguero limpio, con el interior del puente. Si el mundo aún no lo tiene devuelve un modelo vacío (con aviso).
function ShipwreckSet.buildShip(): Model
	local folder = Workspace:FindFirstChild("Naufragio")
	local source = if folder then folder:FindFirstChild("Esperanza") else nil
	if not (source and source:IsA("Model") and source.PrimaryPart) then
		warn("ShipwreckSet: no está Workspace.Naufragio.Esperanza")
		local empty = Instance.new("Model")
		empty.Name = "Esperanza"
		return empty
	end
	local wasArchivable = source.Archivable
	source.Archivable = true
	local ship = source:Clone()
	source.Archivable = wasArchivable
	local root = ship.PrimaryPart :: BasePart
	root.PivotOffset = CFrame.identity
	local frame = root.CFrame -- el marco del barco: x a proa, y arriba, z a estribor
	local inverse = frame:Inverse()

	-- Limpieza: humo y fuego, luces averiadas (se quitan sus luces y la etiqueta), avisos, scripts, y el boquete (las
	-- planchas reventadas y la cubierta hundida; el humo del boquete y de la cubierta ya cae en lo primero).
	local doomed: { Instance } = {}
	local windows: { BasePart } = {}
	for _, descendant in ship:GetDescendants() do
		if
			descendant:IsA("ParticleEmitter")
			or descendant:IsA("Fire")
			or descendant:IsA("Smoke")
			or descendant:IsA("Sparkles")
			or descendant:IsA("ProximityPrompt")
			or descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Light")
		then
			table.insert(doomed, descendant)
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			CollectionService:RemoveTag(descendant, Config.Lobby.BrokenLightTag)
			if
				descendant.Name == "HumoBoquete"
				or descendant.Name == "HumoCubierta"
				or descendant.Name == "ChapaRota"
				or descendant.Name == "PlanchaDoblada"
			then
				table.insert(doomed, descendant)
			elseif descendant.Name == "Ventana" then
				table.insert(windows, descendant)
			end
		end
	end

	-- Puente: la caja maciza se sustituye por la cáscara con su interior, que cabe justo en su volumen. Los cristales
	-- pequeños de sus costados sobran (los paneles del interior ocupan su sitio).
	local bridgeBox = ship:FindFirstChild("Puente")
	local bridge: Model? = nil
	local bridgeSize = Vector3.new(6, 3.6, 24)
	local bridgeCenter = Vector3.zero
	if bridgeBox and bridgeBox:IsA("BasePart") then
		bridgeSize = bridgeBox.Size
		bridgeCenter = (inverse * bridgeBox.CFrame).Position
		table.insert(doomed, bridgeBox)
		local interior = BridgeModel.build({
			length = bridgeSize.X,
			width = bridgeSize.Z,
			height = bridgeSize.Y + BRIDGE_RAISE,
			raise = BRIDGE_RAISE,
		})
		for _, part in interior:GetDescendants() do
			if part:IsA("BasePart") then
				part:SetAttribute(NEW_ATTRIBUTE, true)
			end
		end
		local floorRoot = interior.PrimaryPart :: BasePart
		floorRoot.Anchored = true
		interior:PivotTo(frame * CFrame.new(bridgeCenter - Vector3.new(0, bridgeSize.Y / 2 - BRIDGE_FLOOR_LIFT, 0)))
		bridge = interior
		for index = #windows, 1, -1 do
			local position = (inverse * windows[index].CFrame).Position
			if
				math.abs(position.X - bridgeCenter.X) < bridgeSize.X / 2 + 0.3
				and position.Y > BRIDGE_SIDE_WINDOW_Y0
				and position.Y < BRIDGE_SIDE_WINDOW_Y1
			then
				table.insert(doomed, windows[index])
				table.remove(windows, index)
			end
		end
	else
		warn("ShipwreckSet: el clon no tiene la pieza «Puente»")
	end
	for _, instance in doomed do
		instance:Destroy()
	end
	if bridge then
		bridge.Parent = ship
	end
	local glass = ship:FindFirstChild("Cristalera")
	if glass and glass:IsA("BasePart") then
		glass.Color = BRIDGE_GLASS
		glass.Material = Enum.Material.Glass
		glass.Transparency = BRIDGE_GLASS_TRANSPARENCY
		-- El techo sube BRIDGE_RAISE: el cristal de delante crece hacia arriba lo mismo (el borde de abajo se queda).
		glass.Size += Vector3.new(0, BRIDGE_RAISE, 0)
		glass.CFrame += frame.UpVector * (BRIDGE_RAISE / 2)
	end
	if bridge then
		for _, child in ship:GetChildren() do
			if child:IsA("BasePart") and ROOF_PARTS[child.Name] then
				child.CFrame += frame.UpVector * BRIDGE_RAISE
			end
		end
	end

	-- Casco cerrado: el boquete se tapa con planchas espejo, y la cubierta hundida con una plancha entera (copia de una
	-- vecina, para conservar su color y material).
	closeBreach(ship, frame)
	local template = ship:FindFirstChild("Cubierta")
	if template and template:IsA("BasePart") then
		local patch = template:Clone()
		patch.Name = "Cubierta"
		patch.Size = DECK_PATCH_SIZE
		patch.CFrame = frame * CFrame.new(DECK_PATCH_X, DECK_PATCH_Y, 0)
		patch:SetAttribute(NEW_ATTRIBUTE, true)
		patch.Parent = ship
	end

	-- Noche: ventanas encendidas, tenues (un Neon oscuro que el Bloom no sature), y pocas luces con PointLight.
	table.sort(windows, function(a, b)
		return a.Position.X < b.Position.X
	end)
	for index, window in windows do
		if index % 4 ~= 0 then
			window.Material = Enum.Material.Neon
			window.Color = WINDOW_LIT
			window.Reflectance = 0
		end
	end
	local step = math.max(1, math.floor(#windows / WINDOW_LIGHTS))
	for index = 1, WINDOW_LIGHTS do
		local window = windows[1 + (index - 1) * step]
		if window and window.Parent then
			light(window, WARM_LIGHT, WINDOW_LIGHT_RANGE, WINDOW_LIGHT_BRIGHTNESS)
		end
	end
	local masthead = ship:FindFirstChild("LuzTope")
	if masthead and masthead:IsA("BasePart") then
		light(masthead, MAST_LIGHT, 30, 0.25)
	end

	return ship
end

----------------------------------------------------------------------------------------------------------------------
-- Diagnóstico

type Box = { part: BasePart, min: Vector3, max: Vector3 }

local function boxOf(part: BasePart): Box
	local cf, size = part.CFrame, part.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local extent = Vector3.new(
		math.abs(r.X) * size.X + math.abs(u.X) * size.Y + math.abs(l.X) * size.Z,
		math.abs(r.Y) * size.X + math.abs(u.Y) * size.Y + math.abs(l.Y) * size.Z,
		math.abs(r.Z) * size.X + math.abs(u.Z) * size.Y + math.abs(l.Z) * size.Z
	)
	return { part = part, min = cf.Position - extent, max = cf.Position + extent }
end

export type Coplanar = { a: BasePart, b: BasePart, area: number }

-- Pares de piezas de "model" cuyas cajas (AABB) se solapan más de 0,2 en los tres ejes y comparten la cota de arriba o la de
-- abajo con menos de 0,06 de diferencia, con un área solapada de más de 1 stud²: son los que parpadean (z-fighting). Con
-- onlyNew = true solo cuenta los pares con alguna pieza que añade este módulo (atributo ShipwreckNew); los del modelo original
-- no se ven. Devuelve la lista (vacía = limpio).
function ShipwreckSet.findCoplanar(model: Instance, onlyNew: boolean?): { Coplanar }
	local fresh: { Box } = {}
	local all: { Box } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local box = boxOf(descendant)
			table.insert(all, box)
			if descendant:GetAttribute(NEW_ATTRIBUTE) == true then
				table.insert(fresh, box)
			end
		end
	end
	local result: { Coplanar } = {}
	local function test(x: Box, y: Box)
		local overlap = Vector3.new(
			math.min(x.max.X, y.max.X) - math.max(x.min.X, y.min.X),
			math.min(x.max.Y, y.max.Y) - math.max(x.min.Y, y.min.Y),
			math.min(x.max.Z, y.max.Z) - math.max(x.min.Z, y.min.Z)
		)
		if overlap.X > 0.2 and overlap.Y > 0.2 and overlap.Z > 0.2 then
			if math.abs(x.max.Y - y.max.Y) < 0.06 or math.abs(x.min.Y - y.min.Y) < 0.06 then
				local area = overlap.X * overlap.Z
				if area > 1 then
					table.insert(result, { a = x.part, b = y.part, area = area })
				end
			end
		end
	end
	if onlyNew then
		for index, x in fresh do
			for _, y in all do
				-- Cada par una vez: contra las piezas viejas, y entre las nuevas solo con las de después.
				if y.part:GetAttribute(NEW_ATTRIBUTE) ~= true or table.find(fresh, y, index + 1) then
					if x.part ~= y.part then
						test(x, y)
					end
				end
			end
		end
	else
		for i = 1, #all do
			for j = i + 1, #all do
				test(all[i], all[j])
			end
		end
	end
	return result
end

-- Comprueba la cámara del Naufragio contra "ship" colocado en el mundo: cada punto de "points" (mundo, en la escena) con
-- t >= fromT se pasa al marco actual del barco y, si hay una pieza sólida (Transparency < 0,5, sin el cristal ni el avatar)
-- a menos de 0,6, o el avatar a menos de 1,2, sale en la lista. Devuelve los avisos (vacía = limpio).
function ShipwreckSet.checkCamera(ship: Model, points: { { t: number, pos: Vector3 } }, fromT: number): { string }
	local problems: { string } = {}
	local root = ship.PrimaryPart
	if not root then
		return problems
	end
	local interior = ship:FindFirstChild("InteriorPuente")
	local avatar = if interior then interior:FindFirstChild("NaufragoAvatar") else nil
	-- Las consultas espaciales ignoran lo que tiene CanQuery apagado (el barco lo tiene): se enciende un momento.
	local changed: { BasePart } = {}
	for _, descendant in ship:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.CanQuery then
			descendant.CanQuery = true
			table.insert(changed, descendant)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if avatar then { avatar } else {}
	local avatarParts: { BasePart } = {}
	if avatar then
		for _, descendant in avatar:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(avatarParts, descendant)
			end
		end
	end
	for _, point in points do
		if point.t >= fromT then
			local world = root.CFrame:ToWorldSpace(ShipwreckSet.frameAt(point.t):ToObjectSpace(CFrame.new(point.pos)))
			for _, part in Workspace:GetPartBoundsInRadius(world.Position, 0.6, params) do
				if part:IsDescendantOf(ship) and part.Transparency < 0.5 then
					table.insert(problems, `t = {point.t}: dentro de «{part.Name}»`)
					break
				end
			end
			for _, part in avatarParts do
				if (part.Position - world.Position).Magnitude - part.Size.Magnitude / 2 < 1.2 then
					table.insert(problems, `t = {point.t}: a menos de 1,2 del avatar («{part.Name}»)`)
					break
				end
			end
		end
	end
	for _, part in changed do
		part.CanQuery = false
	end
	return problems
end

local function angularDistance(a: number, b: number): number
	local d = math.abs(a - b) % 360
	return math.min(d, 360 - d)
end

-- Comprueba la dirección de mirada de cada cámara de "points" (mundo) y su posición: avisa si el azimut (grados de 0 a 360
-- desde +Z hacia +X) cae a menos de 48° de 270 (el oeste, donde está el barco encallado del Lobby: 250 a 290 más 28° de margen
-- por el campo de visión) con elevación < 25°, o a menos de 60° de 180 (el sur, tierra lejana) con elevación < 12°, o si la
-- cámara sale de ROUTE.bounds. Devuelve los avisos (vacía = limpio).
function ShipwreckSet.checkLook(points: { { t: number, pos: Vector3, look: Vector3 } }): { string }
	local problems: { string } = {}
	local bounds = ROUTE.bounds
	for _, point in points do
		local d = point.look - point.pos
		local flat = math.sqrt(d.X * d.X + d.Z * d.Z)
		if flat > 0.01 then
			local azimuth = math.deg(math.atan2(d.X, d.Z)) % 360
			local elevation = math.deg(math.atan2(d.Y, flat))
			if angularDistance(azimuth, 270) < 48 and elevation < 25 then
				table.insert(
					problems,
					`t = {point.t}: mira al oeste (azimut {math.round(azimuth)}°, elevación {math.round(elevation)}°)`
				)
			elseif angularDistance(azimuth, 180) < 60 and elevation < 12 then
				table.insert(
					problems,
					`t = {point.t}: mira al sur (azimut {math.round(azimuth)}°, elevación {math.round(elevation)}°)`
				)
			end
		end
		local p = point.pos
		if p.X < bounds.x0 or p.X > bounds.x1 or p.Z < bounds.z0 or p.Z > bounds.z1 then
			table.insert(problems, `t = {point.t}: la cámara sale de la zona ({math.round(p.X)}, {math.round(p.Z)})`)
		end
	end
	return problems
end

----------------------------------------------------------------------------------------------------------------------
-- El avatar

-- Copia del personaje del jugador local (o, sin personaje, un R15 de prueba) de pie en el puente de "ship", mirando a proa,
-- soldada al suelo del puente, con la animación de reposo si el juego corre. Devuelve nil si no se puede.
function ShipwreckSet.buildAvatar(ship: Model, character: Model?): Model?
	local interior = ship:FindFirstChild("InteriorPuente")
	local base = if interior and interior:IsA("Model") then interior.PrimaryPart else nil
	if not (interior and base) then
		return nil
	end
	local rig: Model? = nil
	local idleId = IDLE_FALLBACK
	if character then
		-- El script Animate trae la animación de reposo del personaje (antes de quitarle los scripts).
		pcall(function()
			local animateScript = character:FindFirstChild("Animate")
			local idle = if animateScript then animateScript:FindFirstChild("idle") else nil
			local first = if idle then idle:FindFirstChildWhichIsA("Animation") else nil
			if first and first.AnimationId ~= "" then
				idleId = first.AnimationId
			end
		end)
		pcall(function()
			local wasArchivable = character.Archivable
			character.Archivable = true
			rig = character:Clone()
			character.Archivable = wasArchivable
		end)
	else
		pcall(function()
			rig = Players:CreateHumanoidModelFromDescription(
				Instance.new("HumanoidDescription"),
				Enum.HumanoidRigType.R15
			)
		end)
	end
	local avatar = rig
	if not avatar then
		return nil
	end
	avatar.Name = "NaufragoAvatar"
	for _, descendant in avatar:GetDescendants() do
		-- Los BillboardGui (título y nombre sobre la cabeza) flotaban sobre el techo del puente.
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Tool")
			or descendant:IsA("ForceField")
			or descendant:IsA("BillboardGui")
		then
			descendant:Destroy()
		end
	end
	local avatarHumanoid = avatar:FindFirstChildOfClass("Humanoid")
	if avatarHumanoid then
		avatarHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	RescueCrew.toMotors(avatar)
	if not pcall(avatar.ScaleTo, avatar, AVATAR_SCALE) then
		avatar:Destroy()
		return nil
	end
	RescueCrew.freeze(avatar)
	local root = avatar:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		avatar:Destroy()
		return nil
	end
	avatar.PrimaryPart = root
	-- Mira a +X del puente (la proa), con los pies en el suelo.
	local floorFrame = base.CFrame * base.PivotOffset -- origen del puente: centro de la cara de arriba del suelo
	local spot = floorFrame * CFrame.new(BridgeModel.AVATAR) * CFrame.Angles(0, -math.pi / 2, 0)
	avatar:PivotTo(spot * CFrame.new(0, 3, 0))
	local boxCFrame, boxSize = avatar:GetBoundingBox()
	local lift = floorFrame.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	avatar:PivotTo(avatar:GetPivot() + Vector3.new(0, lift, 0))
	local weld = Instance.new("Weld")
	weld.Name = "BridgeWeld"
	weld.Part0 = base
	weld.Part1 = root
	weld.C0 = base.CFrame:ToObjectSpace(root.CFrame)
	weld.Parent = root
	avatar.Parent = interior
	-- Las armaduras llevan luces propias que a un metro de la cámara queman el plano: se bajan.
	RescueCrew.dimLights(avatar, { lights = 0.25, particles = 0.4 })
	-- Una luz tenue sobre su torso para que se lea la silueta (la escena la apaga antes del fundido: evento shipAvatar). El
	-- atributo hace que dimLights no la baje.
	local torso = avatar:FindFirstChild("UpperTorso")
	local glow = Instance.new("PointLight")
	glow.Name = "AvatarLight"
	glow.Color = Color3.fromRGB(255, 225, 190)
	glow.Brightness = AVATAR_LIGHT
	glow.Range = 8
	glow.Shadows = false
	glow:SetAttribute("VoyageDimmed", true)
	glow.Parent = if torso and torso:IsA("BasePart") then torso else root

	if RunService:IsRunning() then
		pcall(function()
			local humanoid = avatar:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				return
			end
			local animator: Animator? = humanoid:FindFirstChildOfClass("Animator")
			if not animator then
				local created = Instance.new("Animator")
				created.Parent = humanoid
				animator = created
			end
			if not animator then
				return
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = idleId
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track:Play()
		end)
	end
	return avatar
end

----------------------------------------------------------------------------------------------------------------------
-- Las gaviotas

type Gull = { model: Model, joints: GullModel.Joints, spec: typeof(GULLS[1]) }

local function makeGulls(parent: Instance): { Gull }
	local gulls: { Gull } = {}
	for _, spec in GULLS do
		local model, joints = ShipwreckSet.buildGull()
		if model.PrimaryPart then
			model.PrimaryPart.Anchored = true
		end
		model.Parent = parent
		table.insert(gulls, { model = model, joints = joints, spec = spec })
	end
	return gulls
end

-- Pone cada gaviota en su círculo alrededor del barco en el segundo t, mirando hacia donde vuela, y la hace aletear.
local function updateGulls(gulls: { Gull }, t: number)
	local center = ShipwreckSet.positionAt(t)
	for _, gull in gulls do
		local spec = gull.spec
		local angle = spec.phase + spec.turn * t
		local offset = Vector3.new(
			math.cos(angle) * spec.radius,
			spec.height + math.sin(t * 0.9 + spec.phase) * 1.2,
			math.sin(angle) * spec.radius
		)
		local sense = if spec.turn >= 0 then 1 else -1
		local tangent = Vector3.new(-math.sin(angle) * sense, 0, math.cos(angle) * sense)
		local position = center + offset
		gull.model:PivotTo(CFrame.lookAt(position, position + tangent) * CFrame.Angles(0, 0, -sense * GULL_BANK))
		GullModel.pose(gull.joints, math.sin(t * spec.flapHz * 2 * math.pi + spec.phase) * spec.flapAmp)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- La noche

type Saved = { instance: Instance, property: string, value: any }
type Resolved = { instance: Instance, key: NightKey, id: string, original: any }

-- Lo que se tocó y sus valores de antes, para devolverlo; y las propiedades de la noche con su instancia.
local saved: { Saved } = {}
local resolved: { Resolved } = {}
local restoreTweens: { Tween } = {}
-- La tormenta en marcha (evento storm o preview): desde "start" y con "seconds" de rampa. nil = sin tormenta. Y su valor
-- final por "objetivo.propiedad" (STORM.look).
local stormState: { start: number, seconds: number }? = nil
local stormLook: { [string]: any } = {}
for _, look in STORM.look do
	stormLook[`{look.target}.{look.property}`] = look.value
end

local function targetOf(name: string): Instance?
	if name == "lighting" then
		return Lighting
	elseif name == "atmosphere" then
		return Lighting:FindFirstChild("NaufragioAtmosfera") or Lighting:FindFirstChildOfClass("Atmosphere")
	elseif name == "grade" then
		return Lighting:FindFirstChild("NaufragioColor") or Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	elseif name == "sky" then
		return Lighting:FindFirstChildOfClass("Sky")
	elseif name == "bloom" then
		return Lighting:FindFirstChild("NaufragioBrillo") or Lighting:FindFirstChildOfClass("BloomEffect")
	elseif name == "terrain" then
		return Workspace.Terrain
	elseif name == "workspace" then
		return Workspace
	end
	return nil
end

local function mix(a: any, b: any, fraction: number): any
	if typeof(a) == "Color3" then
		return (a :: Color3):Lerp(b :: Color3, fraction)
	elseif typeof(a) == "Vector3" then
		return (a :: Vector3):Lerp(b :: Vector3, fraction)
	elseif typeof(a) == "boolean" then
		return if fraction >= 1 then b else a -- un booleano cambia al acabar la rampa
	elseif typeof(a) ~= "number" then
		return a -- texto: no se interpola
	end
	return (a :: number) + ((b :: number) - (a :: number)) * fraction
end

-- Valor de una propiedad en el segundo t: lineal de start a mid hasta midAt y de mid a deep hasta deepAt.
local function nightValue(key: NightKey, t: number, midAt: number, deepAt: number): any
	if t <= midAt then
		return mix(key.start, key.mid, math.clamp(t / midAt, 0, 1))
	end
	return mix(key.mid, key.deep, math.clamp((t - midAt) / math.max(deepAt - midAt, 0.01), 0, 1))
end

-- Pone la luz de la noche como estaría en el segundo t de la escena (0 por defecto). Guarda los valores de antes solo la
-- primera vez.
function ShipwreckSet.applyNight(t: number?, midAt: number?, deepAt: number?, hour: number?)
	if #resolved == 0 then
		for _, key in NIGHT do
			local instance = targetOf(key.target)
			if instance then
				-- Una propiedad que este cliente no pueda leer (p. ej. GlobalWind) se salta sin romper lo demás.
				local ok, original = pcall(function()
					return (instance :: any)[key.property]
				end)
				if ok then
					table.insert(
						resolved,
						{ instance = instance, key = key, id = `{key.target}.{key.property}`, original = original }
					)
					table.insert(saved, { instance = instance, property = key.property, value = original })
				end
			end
		end
		for _, tween in restoreTweens do
			tween:Cancel()
		end
		table.clear(restoreTweens)
	end
	local now = t or 0
	for _, entry in resolved do
		if entry.key.property == "ClockTime" then
			(entry.instance :: any).ClockTime = hour or SCENE_HOUR
		else
			local value = nightValue(entry.key, now, midAt or NIGHT_MID_AT, deepAt or NIGHT_DEEP_AT)
			if value == nil then
				value = entry.original -- solo de la tormenta: parte del valor que había
			end
			local storm = stormState
			local target = stormLook[entry.id]
			if storm and target ~= nil then
				value = mix(value, target, math.clamp((now - storm.start) / math.max(storm.seconds, 0.01), 0, 1))
			end
			(entry.instance :: any)[entry.key.property] = value
		end
	end
end

-- Pone la tormenta como si empezara en el segundo "start" y durara "seconds" de rampa (el evento storm y preview). La
-- aplica applyNight en cada llamada.
function ShipwreckSet.setStorm(start: number, seconds: number)
	stormState = { start = start, seconds = seconds }
end

-- Devuelve la luz de antes (con un fundido de "seconds"; por defecto 0,5 s). No hace nada si no se puso la noche.
function ShipwreckSet.restoreNight(seconds: number?)
	stormState = nil
	if #saved == 0 then
		return
	end
	local fade = if seconds == nil then 0.5 else seconds
	local byInstance: { [Instance]: { [string]: any } } = {}
	for _, entry in saved do
		local values = byInstance[entry.instance]
		if not values then
			values = {}
			byInstance[entry.instance] = values
		end
		values[entry.property] = entry.value
	end
	table.clear(saved)
	table.clear(resolved)
	for instance, values in byInstance do
		-- Texto y booleanos no se pueden animar: van directos; el resto, con el fundido.
		local smooth: { [string]: any } = {}
		local hasSmooth = false
		for property, value in values do
			if fade > 0 and (typeof(value) == "number" or typeof(value) == "Color3") then
				smooth[property] = value
				hasSmooth = true
			else
				(instance :: any)[property] = value
			end
		end
		if hasSmooth then
			local tween = TweenService:Create(instance, TweenInfo.new(fade), smooth)
			table.insert(restoreTweens, tween)
			tween:Play()
		end
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Eventos de la escena

-- Destellos en curso: segundo de la escena en que empezaron y su fuerza.
type Flash = { start: number, strength: number }
type Shared = { gulls: Folder?, night: boolean, fx: Folder?, alive: boolean, flashes: { Flash }, flashHook: boolean }

local rng = Random.new()

local function stateOf(ctx: Sequencer.Context): Shared
	local state: Shared? = ctx._shipwreck
	if not state then
		state = { gulls = nil, night = false, fx = nil, alive = true, flashes = {}, flashHook = false }
		ctx._shipwreck = state
	end
	return state :: Shared
end

-- Carpeta de los efectos de la tormenta (lluvia y rayos): se destruye entera al acabar.
local function stormFolder(state: Shared): Folder
	local folder = state.fx
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ShipwreckStorm"
		folder.Parent = Workspace
		state.fx = folder
	end
	return folder :: Folder
end

-- Brillo del destello doble (0 a 1) a "age" segundos de empezar: encendido, apagado, encendido y se apaga.
local function pulseAt(age: number): number
	local pulse = STORM.pulse
	local second = pulse.on1 + pulse.off
	if age < 0 then
		return 0
	elseif age < pulse.on1 then
		return 1
	elseif age < second then
		return 0
	elseif age < second + pulse.on2 then
		return 0.8
	end
	return 0.8 * math.clamp(1 - (age - second - pulse.on2) / pulse.fade, 0, 1)
end

-- Tronco del rayo: zigzag de Neon desde el cielo hasta el mar en "ground", con el destello doble.
local function spawnBolt(folder: Folder, ground: Vector3)
	local bolt = STORM.bolt
	local top = ground + Vector3.new(rng:NextNumber(-20, 20), bolt.top, rng:NextNumber(-20, 20))
	local points = { top }
	for i = 1, bolt.steps - 1 do
		local wobble = bolt.wobble * (1 - i / bolt.steps) + 2
		table.insert(
			points,
			top:Lerp(ground, i / bolt.steps)
				+ Vector3.new(rng:NextNumber(-wobble, wobble), 0, rng:NextNumber(-wobble, wobble))
		)
	end
	table.insert(points, ground)
	local parts: { BasePart } = {}
	for i = 1, #points - 1 do
		local from, to = points[i], points[i + 1]
		local part = Instance.new("Part")
		part.Name = "Rayo"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = bolt.color
		part.Size = Vector3.new(bolt.thickness, bolt.thickness, (to - from).Magnitude)
		part.CFrame = CFrame.lookAt((from + to) / 2, to)
		part.Parent = folder
		table.insert(parts, part)
	end
	-- Mismo pulso que el destello: encendido, apagado, encendido y fuera.
	task.spawn(function()
		local pulse = STORM.pulse
		local function setVisible(visible: boolean)
			for _, part in parts do
				part.Transparency = if visible then 0 else 1
			end
		end
		task.wait(pulse.on1)
		setVisible(false)
		task.wait(pulse.off)
		setVisible(true)
		task.wait(pulse.on2)
		for _, part in parts do
			part:Destroy()
		end
	end)
end

local function addFrameHook(ctx: Sequencer.Context, fn: (t: number) -> ())
	local list = ctx.frameHooks
	if not list then
		list = {}
		ctx.frameHooks = list
	end
	table.insert(list, fn)
end

function ShipwreckSet.install(sequencer: typeof(Sequencer))
	-- shipSail: el barco sigue a poseAt(t) cada cuadro, justo tras la cámara (Sequencer.frameHooks) para no desfasarse.
	sequencer.registerHandler("shipSail", function(_, ctx)
		local actors = ctx.actors
		local ship = if actors then actors.ship else nil
		if not (ship and ship:IsA("Model")) then
			warn("ShipwreckSet: no hay barco (ctx.actors.ship)")
			return
		end
		addFrameHook(ctx, function(t: number)
			if ship.Parent then
				ship:PivotTo(ShipwreckSet.poseAt(t))
			end
		end)
	end)

	sequencer.registerHandler("shipAvatar", function(_, ctx)
		local actors = ctx.actors
		local ship = if actors then actors.ship else nil
		if not (ship and ship:IsA("Model")) then
			warn("ShipwreckSet: no hay barco (ctx.actors.ship)")
			return
		end
		local player = Players.LocalPlayer
		local character = if player then player.Character else nil
		local avatar = ShipwreckSet.buildAvatar(ship, character)
		if not avatar then
			warn("ShipwreckSet: no se pudo poner al avatar en el puente")
			return
		end
		local glow = avatar:FindFirstChild("AvatarLight", true)
		if glow and glow:IsA("PointLight") then
			local full = glow.Brightness
			addFrameHook(ctx, function(t: number)
				if glow.Parent then
					glow.Brightness = full * math.clamp(1 - (t - AVATAR_LIGHT_OFF) / AVATAR_LIGHT_FADE, 0, 1)
				end
			end)
		end
	end)

	sequencer.registerHandler("birds", function(event, ctx)
		local state = stateOf(ctx)
		if state.gulls then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "ShipwreckGulls"
		folder.Parent = Workspace
		state.gulls = folder
		local gulls = makeGulls(folder)
		local untilT: number = event.seconds or 15
		addFrameHook(ctx, function(t: number)
			if not folder.Parent then
				return
			end
			if t >= untilT then
				folder:Destroy()
				return
			end
			updateGulls(gulls, t)
		end)
	end)

	-- night: la luz del mundo baja cada cuadro (frameHooks) de la luna clara a la noche cerrada y a casi oscuridad.
	sequencer.registerHandler("night", function(event, ctx)
		stateOf(ctx).night = true
		local midAt: number = event.midAt or NIGHT_MID_AT
		local deepAt: number = event.deepAt or NIGHT_DEEP_AT
		local hour: number? = event.hour
		ShipwreckSet.applyNight(0, midAt, deepAt, hour)
		addFrameHook(ctx, function(t: number)
			ShipwreckSet.applyNight(t, midAt, deepAt, hour)
		end)
	end)

	-- storm { seconds }: en "seconds" s la niebla se espesa, el mar y el viento suben y la luna se tapa (STORM.look). Lo aplica
	-- el evento night en cada cuadro, así que necesita que esté en la escena; restoreNight lo devuelve todo.
	sequencer.registerHandler("storm", function(event, ctx)
		stateOf(ctx)
		ShipwreckSet.setStorm(event.t, event.seconds or 3)
	end)

	-- rain { seconds }: dos capas de gotas (STORM.rain) sobre piezas invisibles que siguen a la cámara; entran en "seconds" s.
	sequencer.registerHandler("rain", function(event, ctx)
		local state = stateOf(ctx)
		local folder = stormFolder(state)
		local wind = STORM.wind * STORM.rainDrift
		local fadeIn: number = event.seconds or 2
		local startT: number = event.t
		local layers: { { part: BasePart, emitter: ParticleEmitter, spec: typeof(STORM.rain[1]) } } = {}
		for _, spec in STORM.rain do
			local part = Instance.new("Part")
			part.Name = "Lluvia"
			part.Size = Vector3.new(spec.side, 1, spec.side)
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Parent = folder
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			emitter.Color = ColorSequence.new(Color3.fromRGB(180, 200, 230))
			emitter.Size = NumberSequence.new(spec.size)
			emitter.Transparency = NumberSequence.new(spec.transparency)
			emitter.Squash = NumberSequence.new(spec.squash)
			emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
			emitter.Lifetime = NumberRange.new(spec.lifetime * 0.8, spec.lifetime)
			emitter.Speed = NumberRange.new(spec.speed * 0.9, spec.speed)
			emitter.Acceleration = Vector3.new(wind.X, 0, wind.Z)
			emitter.EmissionDirection = Enum.NormalId.Bottom
			emitter.SpreadAngle = Vector2.new(3, 3)
			emitter.LightEmission = 0.3
			emitter.Rate = 0
			emitter.Parent = part
			table.insert(layers, { part = part, emitter = emitter, spec = spec })
		end
		addFrameHook(ctx, function(t: number)
			local camera = Workspace.CurrentCamera
			if not (camera and folder.Parent) then
				return
			end
			local amount = math.clamp((t - startT) / math.max(fadeIn, 0.01), 0, 1)
			for _, layer in layers do
				-- Un poco a barlovento de la cámara, para que las gotas inclinadas lleguen a ella.
				layer.part.Position = camera.CFrame.Position
					+ Vector3.new(-wind.X * 0.5, layer.spec.height, -wind.Z * 0.5)
				layer.emitter.Rate = layer.spec.rate * amount
			end
		end)
	end)

	-- lightning { side?, thunderDelay?, strength?, bolt? }: destello doble que sube Brightness y ExposureCompensation, tronco
	-- en zigzag al horizonte por delante de la cámara (nunca al oeste ni al sur: si la cámara mira ahí, hacia la luna) y
	-- trueno. "side" (-1 a 1) abre el rayo a un lado, "strength" (1) escala el destello y bolt = false lo deja sin tronco.
	sequencer.registerHandler("lightning", function(event, ctx)
		local state = stateOf(ctx)
		table.insert(state.flashes, { start = event.t, strength = event.strength or 1 })
		if not state.flashHook then
			state.flashHook = true
			-- Va después de night (se registró antes): suma el destello a la luz de ese cuadro.
			addFrameHook(ctx, function(t: number)
				local level = 0
				for _, flash in state.flashes do
					level = math.max(level, pulseAt(t - flash.start) * flash.strength)
				end
				if level > 0 then
					Lighting.Brightness += STORM.flash.brightness * level
					Lighting.ExposureCompensation += STORM.flash.exposure * level
				end
			end)
		end
		local camera = Workspace.CurrentCamera
		local distance = rng:NextNumber(STORM.bolt.minDist, STORM.bolt.maxDist)
		if camera and event.bolt ~= false then
			local origin = camera.CFrame.Position
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			local azimuth = math.deg(math.atan2(look.X, look.Z)) % 360
			-- Oeste (el Lobby) y sur (tierra lejana): se sustituye por la dirección de la luna, al este.
			if flat.Magnitude < 0.1 or (azimuth > 130 and azimuth < 310) then
				local info = ShipwreckSet.course()
				flat = if info then Vector3.new(info.direction.X, 0, info.direction.Z) else Vector3.new(1, 0, 0)
			end
			local side: number = event.side or rng:NextNumber(-1, 1)
			local direction = (CFrame.Angles(0, -math.rad(side * STORM.bolt.spread), 0) * flat.Unit)
			spawnBolt(stormFolder(state), Vector3.new(origin.X, 0, origin.Z) + direction * distance)
		end
		local delay: number = event.thunderDelay or (0.4 + (distance - STORM.bolt.minDist) / 150 * 0.8)
		task.delay(delay, function()
			if state.alive then
				Sfx.playLocal("Thunder", STORM.thunderVolume)
			end
		end)
	end)

	sequencer.addHooks({
		finish = function(_, ctx)
			local state: Shared? = ctx._shipwreck
			if not state then
				return
			end
			ctx._shipwreck = nil
			ctx.frameHooks = nil
			state.alive = false
			if state.gulls then
				state.gulls:Destroy()
			end
			if state.fx then
				state.fx:Destroy()
			end
			-- Siempre (salte, aborte o acabe): devuelve la luz, la niebla, el mar y el viento.
			ShipwreckSet.restoreNight()
		end,
	})
end

----------------------------------------------------------------------------------------------------------------------
-- Vista previa en modo edición

function ShipwreckSet.clearPreview()
	local old = Workspace:FindFirstChild(PREVIEW_NAME)
	if old then
		old:Destroy()
	end
	ShipwreckSet.restoreNight(0)
end

-- Coloca el barco con el puente, las gaviotas y un avatar de prueba (un R15 sin ropa) en el segundo options.t de la escena
-- (14 por defecto: 252 studs de la salida), sin escena ni cámara. Con options.night = true pone también la luz de la
-- noche tal como estaría en options.nightT segundos (0 por defecto; 21 es casi oscuro). Con options.storm = true pone la
-- tormenta (niebla, luz, mar y viento) como en options.t (o nightT). OJO: en modo edición la luz se
-- queda en el place; clearPreview() la devuelve. Devuelve la carpeta.
function ShipwreckSet.preview(
	parent: Instance?,
	options: { t: number?, night: boolean?, nightT: number?, storm: boolean? }?
): Folder
	ShipwreckSet.clearPreview()
	ShipwreckSet.setCourse()
	local t = if options and options.t then options.t else PREVIEW_SECONDS
	local folder = Instance.new("Folder")
	folder.Name = PREVIEW_NAME
	folder.Parent = parent or Workspace

	local ship = ShipwreckSet.buildShip()
	ship:PivotTo(ShipwreckSet.poseAt(t))
	ship.Parent = folder
	ShipwreckSet.buildAvatar(ship, nil)

	local gulls = makeGulls(folder)
	updateGulls(gulls, t)

	-- storm = true: la luz, la niebla, el mar y el viento de la tormenta como estarían en options.t (con la rampa de 3 s a los
	-- STORM.seaFrom s); implica la noche. clearPreview() lo devuelve.
	if options and options.storm then
		ShipwreckSet.setStorm(STORM.seaFrom, 3)
		ShipwreckSet.applyNight(options.nightT or t, nil, NIGHT_DEEP_AT_STORM)
	elseif options and options.night then
		ShipwreckSet.applyNight(options.nightT or 0)
	end

	-- Comprobaciones: caras coplanares entre piezas nuevas (objetivo: 0) y la cámara del último tramo contra los sólidos.
	local pairsFound = ShipwreckSet.findCoplanar(ship, true)
	warn(`ShipwreckSet.preview: {#pairsFound} pares coplanares nuevos`)
	for index, pair in pairsFound do
		if index <= 10 then
			warn(`  {pair.a.Name} / {pair.b.Name} ({math.round(pair.area * 10) / 10} studs²)`)
		end
	end
	local ok, cinematics = pcall(function()
		return require(script.Parent.Parent.Data.Cinematics) :: any
	end)
	if ok and cinematics.Shipwreck and cinematics.Shipwreck.prepare then
		local points = cinematics.Shipwreck.prepare()
		local looks = ShipwreckSet.checkLook(points)
		warn(`ShipwreckSet.preview: mirada y zona de la cámara: {#looks} avisos`)
		for index, problem in looks do
			if index <= 10 then
				warn("  " .. problem)
			end
		end
		local problems = ShipwreckSet.checkCamera(ship, points, PREVIEW_CAMERA_FROM)
		warn(`ShipwreckSet.preview: cámara desde t = {PREVIEW_CAMERA_FROM}: {#problems} problemas`)
		for index, problem in problems do
			if index <= 10 then
				warn("  " .. problem)
			end
		end
	end
	return folder
end

return ShipwreckSet
