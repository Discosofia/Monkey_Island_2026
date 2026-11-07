--!strict
-- Escenas de las cinemáticas (Fase 25; Shared/Cinematics/Sequencer las reproduce). Cada una:
--   - duration: segundos. audience: quién la ve ("Self" solo quien la dispara, "All" todos los de la partida).
--   - freeze: true congela a los enemigos y protege a los jugadores mientras dura (jefes y rescate).
--   - anchor (opcional): dónde se ancla la escena ("boss" = el jefe); sin él, el que le dé quien la lanza.
--   - actors: { nombre = { kind = "dummy" | "localPlayer" | "boss" | "prop", … } } (ver Cinematics/Actors).
--   - camera: puntos { t, pos, look, fov? } con la posición y la mirada relativas al anchor (Cinematics/CameraPath).
--   - events: { t, kind, … } con letterbox, title, caption, fade (Presentation), anim, move (Actors), panel,
--     bubble, sfx (Comic, escenas «cómic») y los que registre cada place. Los textos se marcan con Strings.later y se traducen al dibujarlos.
--   - hour (número 0-24): hora del día propia de la escena. SceneLight la pone en Lighting.CinematicClockTime al empezar
--     (como un evento clock a t = 0) y LightingController de la Isla dibuja esa hora con un fundido de 0,4 s; la quita
--     al acabar o saltar (0,8 s de vuelta). El ciclo real sigue por debajo y el clima se ve despejado mientras dura.
--     REGLA: toda escena nueva lleva hour (las luces se calibran a una hora fija, nunca al ciclo de la Isla). Solo se
--     omite en un place sin ciclo de día (el Lobby: EggHatch), donde no habría quien la leyera.
--
-- Horas por escena (18,8 = anochecer ya oscuro, la hora con la que se calibraron: cielo morado con estrellas y sin sol):
--   Arrival, ArrivalShort ................ 18,8  (luz de relleno propia, calibrada de noche)
--   Voyage ............................... 5,6   (amanecer real; ver sus valores de luz)
--   Rescue ............................... 6,1   (amanecer: la escena es «Rescate al amanecer»)
--   EggHatch ............................. sin hora (Lobby: tiene su hora fija y ningún controlador de ciclo)
--   Shipwreck ............................ 18,8  (noche cerrada con luna roja baja y grande; Lobby sin ciclo de día: ShipwreckSet
--                                                 pone y devuelve la hora y la luz del Lobby él mismo, evento night; la última
--                                                 toma de G6c, justo antes de amanecer, irá a ~5,3)
--   Prueba ............................... 14,0  (tarde clara; no lleva luces propias)
--   Boss_OrangutanDelManglar, Boss_ChimpanceCaudillo, Boss_GorilaAlbino y sus _Comic ... 18,8 (luz de relleno de SceneLight)
--   Boss_GorilaDeCeniza y su _Comic ...... 17,5  (atardecer: sin luz de relleno, la lava y el sol bajo lo iluminan)
--   Battle_Pack, Battle_Pack_Comic, Battle_Pack_Reel ... 18,8
--   Battle_Boss_<jefe>, _Comic y _Reel (Orangután y Caudillo) ... 18,8

local Bosses = require(script.Parent.Bosses)
local CameraPath = require(script.Parent.Parent.Cinematics.CameraPath)
local Config = require(script.Parent.Parent.Config)
local ShipwreckSet = require(script.Parent.Parent.Cinematics.ShipwreckSet)
local HelicopterModel = require(script.Parent.Parent.HelicopterModel)
local LifeboatModel = require(script.Parent.Parent.LifeboatModel)
local Strings = require(script.Parent.Parent.Strings)

export type Scene = {
	duration: number,
	audience: string,
	freeze: boolean,
	waitTerrain: { Vector3 }?, -- puntos (relativos al anchor) cuyo terreno debe estar cargado antes de empezar (streaming)
	skippable: boolean?, -- se puede saltar aunque no se haya visto entera (sin él, solo si ya está vista)
	noSkip: boolean?, -- nunca se puede saltar, ni siquiera vista (el Naufragio)
	prepare: (() -> { { t: number, pos: Vector3, look: Vector3, fov: number? } })?, -- calcula la cámara justo antes de empezar (el Naufragio)
	anchor: string?,
	hour: number?, -- hora del día de la escena (0-24); ver la cabecera
	actors: { [string]: { [string]: any } },
	camera: { { t: number, pos: Vector3, look: Vector3, fov: number? } },
	events: { { t: number, kind: string, [string]: any } },
}

-- Ajustes de cámara de la aparición de un jefe; todo se mide en alturas del jefe (h).
type BossShot = {
	side: number?, -- 1 rodea por su derecha, -1 por la izquierda
	radius: number?, -- multiplica el radio del giro (1 por defecto)
	frontZ: number?, -- distancia de la cámara de frente, en alturas del jefe (2,1); menos en espacios cerrados
	frontT: number?, -- segundo en que llega al contrapicado de frente (2,0)
	startY: number?, -- altura del plano abierto (1,2)
	lowY: number?, -- altura del contrapicado (0,35)
	lit: (boolean | number)?, -- luz de relleno (jefes de noche o al amanecer): true = 1, o un número que multiplica su fuerza (0,35 para el Albino, que es casi blanco)
	skill: string?, -- habilidad que enseña (evento bossSkill): "stomp" | "rockRain" | "extinguish" | "eruption"
	skillAt: number?, -- segundo en que la lanza (por defecto, 0,6 s después de frontT)
	hour: number?, -- hora del día de la toma (por defecto, DUSK_HOUR)
}

-- Anochecer ya oscuro (cielo morado con estrellas, sin sol): la hora con la que se calibraron las luces de las escenas.
local DUSK_HOUR = 18.8

-- Cámara de la aparición de un jefe (G2): plano abierto desde atrás y giro hasta un contrapicado de frente. El
-- anchor es el pie del jefe y mira hacia -Z; la cámara de frente está en z negativo. Devuelve los puntos y frontT.
local function bossCamera(
	bossId: string,
	shot: BossShot?
): ({ { t: number, pos: Vector3, look: Vector3, fov: number? } }, number)
	local s: BossShot = shot or {}
	local h = Bosses[bossId].scale * 3
	local side = s.side or 1
	local radius = s.radius or 1
	local frontT = s.frontT or 2.0
	local startY = s.startY or 1.2
	local lowY = s.lowY or 0.35
	local function orbit(degrees: number, r: number, y: number): Vector3
		local a = math.rad(degrees)
		return Vector3.new(side * math.sin(a) * r * h * radius, y * h, math.cos(a) * r * h * radius)
	end
	-- El modelo mide unos 1,33 h de alto (h = escala × 3): la cara queda hacia 1,0 h, y la cámara se separa lo
	-- justo para que la cabeza no choque con la franja de arriba.
	local face = Vector3.new(0, 1.0 * h, 0)
	local frontZ = -(s.frontZ or 2.1)
	local camera = {
		{
			t = 0,
			pos = Vector3.new(0, startY * h, 2.2 * h * radius),
			look = Vector3.new(0, 0.7 * h, -0.5 * h),
			fov = 65,
		},
		{
			t = frontT * 0.45,
			pos = orbit(60, 2.1, (startY + lowY) / 2 + 0.1),
			look = Vector3.new(0, 0.7 * h, 0),
			fov = 60,
		},
		{ t = frontT * 0.8, pos = orbit(125, 1.8, lowY + 0.15), look = Vector3.new(0, 0.75 * h, 0), fov = 52 },
		{ t = frontT, pos = Vector3.new(0, lowY * h, frontZ * h), look = face, fov = 45 },
		{
			t = 4.6,
			pos = Vector3.new(side * 0.4 * h, (lowY + 0.05) * h, (frontZ + 0.1) * h),
			look = face,
			fov = 45,
		},
		{
			t = 6,
			pos = Vector3.new(side * 0.7 * h, (lowY + 0.1) * h, (frontZ + 0.25) * h),
			look = Vector3.new(0, 0.95 * h, 0),
			fov = 45,
		},
	}
	return camera, frontT
end

-- Luz de relleno de la aparición de un jefe (eventos exposure y light de Cinematics/SceneLight).
local function bossLights(bossId: string, shot: BossShot?): { { t: number, kind: string, [string]: any } }
	if not (shot and shot.lit) then
		return {}
	end
	local h = Bosses[bossId].scale * 3
	local strength: number = if shot.lit == true then 1 else shot.lit :: number
	-- Una luz que acompaña a la cámara, un poco por encima: a distancia casi constante del jefe, así la exposición
	-- es pareja de principio a fin (las luces fijas quemaban el plano final y dejaban a oscuras el de apertura).
	return {
		{ t = 0, kind = "exposure", value = 0.5 * strength },
		{
			t = 0,
			kind = "light",
			follow = true,
			offset = Vector3.new(0, 0.4 * h, 0),
			color = Color3.fromRGB(255, 236, 210),
			brightness = 2 * strength,
			range = 5 * h,
		},
	}
end

-- Evento de servidor bossSkill: enseña una habilidad real del jefe en la toma, solo visual (IslandBossHooks).
local function addBossSkill(scene: Scene, shot: BossShot?, frontT: number)
	if not (shot and shot.skill) then
		return
	end
	table.insert(scene.events :: { any }, {
		t = shot.skillAt or frontT + 0.6,
		kind = "bossSkill",
		server = true,
		essential = true,
		skill = shot.skill,
	})
end

-- Aparición de un jefe (G2): la cámara de bossCamera con el rugido, el cartel con su nombre y el fundido.
local function bossScene(bossId: string, subtitle: string, shot: BossShot?): Scene
	local camera, frontT = bossCamera(bossId, shot)
	local scene: Scene = {
		duration = 7.5,
		audience = "All",
		freeze = true,
		anchor = "boss",
		hour = (shot and shot.hour) or DUSK_HOUR,
		actors = {},
		camera = camera,
		events = {
			{ t = 0, kind = "letterbox" },
			{ t = 1.0, kind = "bossRoar", server = true, essential = true },
			-- El cartel sale cuando la cámara llega de frente al jefe, en el tercio de abajo (ver Presentation).
			{
				t = frontT - 0.1,
				kind = "title",
				text = Strings.later(Bosses[bossId].name),
				sub = subtitle,
				seconds = 7.0 - (frontT - 0.1),
			},
			{ t = 7.1, kind = "fade", seconds = 0.4, toBlack = true },
		},
	}
	for _, light in bossLights(bossId, shot) do
		table.insert(scene.events :: { any }, light)
	end
	addBossSkill(scene, shot, frontT)
	return scene
end

-- Variante cómic de la aparición de un jefe (G2b; se graba con el Plató cómic, sin franjas negras): la misma
-- cámara, con viñetas (Cinematics/Comic), una narración, la onomatopeya del rugido y la frase del jefe.
-- "subtitle" va bajo el nombre en la caja de título; "colors" = { color del jefe, color crema }.
local function bossComicScene(
	bossId: string,
	subtitle: string,
	quote: string,
	narration: string,
	colors: { Color3 },
	shot: BossShot?
): Scene
	local camera, frontT = bossCamera(bossId, shot)
	local base, cream = colors[1], colors[2]
	local speakAt = frontT + 0.3
	local scene: Scene = {
		duration = 7.5,
		audience = "All",
		freeze = true,
		anchor = "boss",
		hour = (shot and shot.hour) or DUSK_HOUR,
		actors = {},
		camera = camera,
		events = {
			{ t = 0, kind = "panel", shape = "diagLeft", bg = { style = "halftone", colors = { base, cream } } },
			{ t = 0.2, kind = "bubble", balloon = "narration", corner = "TL", text = narration, seconds = 2.4 },
			{ t = 1.0, kind = "bossRoar", server = true, essential = true },
			{
				t = 1.0,
				kind = "panel",
				shape = "diagRight",
				bg = { style = "speed", colors = { cream, base } },
				seconds = 0.2,
			},
			{
				t = 1.0,
				kind = "sfx",
				text = Strings.later("¡ROAAAR!"),
				pos = { 0.22, 0.2 },
				rot = -8,
				size = 0.2,
				color = Color3.new(1, 1, 1),
				seconds = 1.5,
			},
			{
				t = frontT - 0.3,
				kind = "panel",
				shape = "tallSlant",
				bg = { style = "flat", colors = { base, cream } },
				seconds = 0.3,
			},
			-- La caja de título es de Comic (el cartel de Presentation tapaba el pecho del jefe).
			{
				t = frontT - 0.1,
				kind = "bubble",
				balloon = "title",
				corner = "BL",
				text = Strings.later(Bosses[bossId].name),
				sub = subtitle,
				seconds = 7.0 - (frontT - 0.1),
			},
			{
				t = speakAt,
				kind = "bubble",
				balloon = "speech",
				actor = "boss",
				text = quote,
				seconds = 6.9 - speakAt,
			},
			{ t = 7.1, kind = "fade", seconds = 0.4, toBlack = true },
		},
	}
	for _, light in bossLights(bossId, shot) do
		table.insert(scene.events :: { any }, light)
	end
	addBossSkill(scene, shot, frontT)
	return scene
end

-- Rescate (G3b), en el marco del anchor: la base de la baliza, con +Z hacia el Basecamp (lo calcula BeaconService).
-- El helicóptero llega desde el horizonte (por detrás del Basecamp), sobrevuela la cámara y se queda flotando sobre
-- la baliza. Los giros (yaw) hacen que mire por donde vuela y, al llegar, hacia la baliza.
local HELI_START = Vector3.new(-90, 55, 130)
local HELI_START_YAW = -38
local HELI_HOVER = Vector3.new(10, 18, 4)
local HELI_HOVER_YAW = 68
local HELI_LOW = Vector3.new(10, 14, 4)

-- Salida con la tripulación a bordo (segunda parte, de 9,6 a 19 s). Con la pantalla en negro el helicóptero salta a
-- HELI_LOW con el yaw de salida; de 10 a 18 s sube y se aleja hasta HELI_OUT (Sine InOut, igual que el evento move).
-- Con yaw -23 la nariz (-Z local) apunta a (0,39, 0, -0,92) en (x, z): lejos del Basecamp (+Z) y hacia el recorrido
-- (16, 16, -38). Los ejes locales en el marco del anchor son: derecha (puerta) = (0,92, 0, 0,39), atrás = (-0,39, 0, 0,92).
local HELI_EXIT_YAW = -23
local HELI_OUT = Vector3.new(26, 30, -34)
local EXIT_FROM, EXIT_TO = 10, 18

-- Posición del helicóptero en el segundo t de la salida (anchor): HELI_LOW + (HELI_OUT - HELI_LOW) * s(t), con
-- s = (1 - cos(pi * alfa)) / 2 y alfa = (t - 10) / 8. Ejemplos: t 11 -> s 0,038; 12 -> 0,146; 13 -> 0,309; 14 -> 0,5;
-- 15 -> 0,691; 16 -> 0,854; 17 -> 0,962; 18 -> 1.
local function exitPosition(t: number): Vector3
	local alpha = math.clamp((t - EXIT_FROM) / (EXIT_TO - EXIT_FROM), 0, 1)
	return HELI_LOW:Lerp(HELI_OUT, (1 - math.cos(math.pi * alpha)) / 2)
end

-- Punto fijo en el marco del helicóptero (x derecha/puerta, y arriba, z atrás; el piloto está en (1, -0,7, -2,1) y la
-- fila de pasajeros de la puerta en z de -0,9 a 1,9) llevado al marco del anchor en el segundo t. Así la cámara de la
-- tripulación va pegada al helicóptero aunque este se mueva.
local function heliPoint(t: number, localPos: Vector3): Vector3
	return exitPosition(t) + CFrame.Angles(0, math.rad(HELI_EXIT_YAW), 0) * localPos
end

local function crewShot(t: number, camLocal: Vector3, lookLocal: Vector3, fov: number)
	return { t = t, pos = heliPoint(t, camLocal), look = heliPoint(t, lookLocal), fov = fov }
end

-- Llegada a la isla (G4), en el marco del anchor: la playa de arena de la Isla, con -Z hacia tierra adentro y +Z
-- hacia el mar. El suelo baja 0,08 studs por stud hacia +Z: beach da el punto a ras de suelo y ground() suma esa
-- altura a una cámara o una mirada dada en altura sobre el suelo.
local BEACH_SLOPE = 0.08

local function beach(x: number, z: number): Vector3
	return Vector3.new(x, -BEACH_SLOPE * z, z)
end

local function ground(x: number, height: number, z: number): Vector3
	return Vector3.new(x, height - BEACH_SLOPE * z, z)
end

-- La tripulación de la llegada: el mejor equipo de cada rol (como Portada), de izquierda a derecha.
local CREW = {
	{
		name = "guerrero",
		x = -8,
		startZ = 3,
		endZ = -4,
		yaw = 30,
		role = "Guerrero",
		outfit = "TitanKingOutfit",
		skin = "TitanKingMace",
	},
	{ name = "cazador", x = -3, startZ = 5, endZ = -9, yaw = 8, role = "Cazador", armor = "VolcanicArmor" },
	{
		name = "mago",
		x = 3.5,
		startZ = 4,
		endZ = -7,
		yaw = -8,
		role = "Mago",
		outfit = "BlueFireInvokerOutfit",
		skin = "SulfurStaff",
	},
	{
		name = "medico",
		x = 9,
		startZ = 5.5,
		endZ = -3.5,
		yaw = -32,
		role = "Medico",
		outfit = "CeibaOfLifeOutfit",
		skin = "CeibaBlowgun",
	},
}

-- Los cuatro maniquíes de la tripulación: en su sitio de salida (en el mar, a la orilla) o ya en tierra (atEnd).
local function crewActors(atEnd: boolean): { [string]: { [string]: any } }
	local actors: { [string]: { [string]: any } } = {}
	for _, member in CREW do
		actors[member.name] = {
			kind = "dummy",
			role = member.role,
			armor = member.armor,
			outfit = member.outfit,
			skin = member.skin,
			pos = beach(member.x, if atEnd then member.endZ else member.startZ),
			yaw = if atEnd then member.yaw else 0,
		}
	end
	return actors
end

-- Travesía en la lancha (G4b), en el marco del anchor de la playa (+Z es el mar). El nivel del mar de la Isla es 2
-- (MapBuilder.SEA_LEVEL) y el anchor está a 3, así que la superficie queda en y = -1; la lancha flota 0,2 por encima,
-- como la del Lobby. Sale a 150 studs de la orilla (el mar generado llega unos 200 más allá de la costa) y avanza
-- hacia tierra a velocidad constante con la proa en -Z. La cámara va en el marco de la lancha (boatShot).
local VOYAGE_SECONDS = 12
-- Amanecer real (entre «Antes del amanecer» 5,0 y «Amanecer» 5,9 de Config.Lighting.Keyframes): sol aún bajo el horizonte
-- y cielo rosado. Las luces de la travesía se calibraron de noche; con esta hora el mundo es algo más claro (ver Voyage).
local VOYAGE_HOUR = 5.95
local BOAT_START = Vector3.new(0, -0.8, 150)
local BOAT_SPEED = 3.5 -- studs por segundo
-- Oleaje: tres ondas senoidales muestreadas cada WAVE_STEP s. La subida y el cabeceo comparten periodo, con el
-- cabeceo desfasado 90° (la proa baja cuando la lancha pasa por la mitad de la subida); el balanceo va a otro ritmo.
local WAVE_STEP = 0.25 -- segundos entre dos muestras (cada tramo es lineal, así el avance sigue a velocidad constante)
local WAVE_BOB, WAVE_PITCH, WAVE_ROLL = 0.35, 3, 4 -- studs, grados y grados de amplitud
local WAVE_PERIOD, WAVE_ROLL_PERIOD = 2.6, 3.0 -- segundos por ciclo
local WAVE_ROLL_PHASE = 1.0 -- radianes
local WAVE_RAMP = 1 -- segundos hasta la amplitud completa (la lancha parte en reposo)

local function boatAt(t: number): Vector3
	return BOAT_START + Vector3.new(0, 0, -BOAT_SPEED * t)
end

-- Altura, cabeceo (grados; positivo = proa arriba) y balanceo (grados) de la lancha en el segundo t.
local function waveAt(t: number): (number, number, number)
	local ramp = math.min(1, t / WAVE_RAMP)
	local w = 2 * math.pi * t / WAVE_PERIOD
	local wRoll = 2 * math.pi * t / WAVE_ROLL_PERIOD + WAVE_ROLL_PHASE
	return ramp * WAVE_BOB * math.sin(w),
		ramp * WAVE_PITCH * math.sin(w + math.pi / 2),
		ramp * WAVE_ROLL * math.sin(wRoll)
end

-- Segundos en que la proa baja de una ola (el cabeceo cruza el cero hacia abajo): salen las ráfagas de espuma.
local function bowDipTimes(): { number }
	local times = {}
	local t = WAVE_PERIOD / 4
	while t < VOYAGE_SECONDS - 0.5 do
		table.insert(times, t)
		t += WAVE_PERIOD
	end
	return times
end

-- Punto de cámara en el segundo t, con la posición y la mirada dadas en el marco de la lancha (sin su balanceo).
local function boatShot(t: number, camLocal: Vector3, lookLocal: Vector3, fov: number)
	return { t = t, pos = boatAt(t) + camLocal, look = boatAt(t) + lookLocal, fov = fov }
end

-- La tripulación sentada en la lancha: los cuatro maniquíes con el mismo equipo que en la llegada. RescueCrew los
-- reduce y los sienta en LifeboatModel.SEATS al empezar (evento voyageBoard).
local function voyageActors(): { [string]: { [string]: any } }
	local actors: { [string]: { [string]: any } } = {}
	for _, member in CREW do
		actors[member.name] = {
			kind = "dummy",
			role = member.role,
			armor = member.armor,
			outfit = member.outfit,
			skin = member.skin,
			pos = boatAt(0),
			yaw = 0,
		}
	end
	actors.boat = {
		kind = "prop",
		build = function(anchor: CFrame)
			-- Con espuma: salpicaduras a los lados de la proa y estela tras el motor; ráfaga cuando la proa baja.
			local model = LifeboatModel.build({ spray = true, burstTimes = bowDipTimes() })
			model:PivotTo(anchor * CFrame.new(BOAT_START))
			-- El fondo (raíz) anclado: el resto va soldado a él y se mueve con el PivotTo del evento move.
			if model.PrimaryPart then
				model.PrimaryPart.Anchored = true
			end
			return model
		end,
	}
	return actors
end

-- Batalla montada «Tripulación contra la manada» (G5a), en el marco del anchor de la playa (ArrivalService.ANCHOR):
-- la tripulación en arco mira tierra adentro (-Z) y cuatro monos bajan de la selva y frenan a unos 14 studs. Es solo
-- para grabar (se lanza con «Batalla» y «Batalla cómic» del panel de pruebas). Las habilidades son solo visuales: sus
-- efectos son los del juego (Cinematics/AbilityShow, que llama a AbilityFxController), sin daño, sin recargas y sin
-- pasar por CombatService. Los monos son del servidor (CinematicMonkeyService, evento «monkey»).
--
-- Reparto del tiempo (14 s; los tiempos del servidor y del cliente son los mismos):
--    0,0 a  2,4  plano general; los monos bajan corriendo desde z ≈ -48 hasta su sitio
--    2,4 a  3,6  rugido del mandril (plano cerrado)
--    3,6 a  4,8  el guerrero responde con el Grito de guerra
--    4,8 a  6,6  el cazador (Disparo múltiple) y el mago (Bola de fuego)
--    6,6 a  8,6  el guerrero carga y gira (Embestida, Torbellino) y el mago congela al aullador (Nova de hielo)
--    8,6 a 10,4  el médico cura en área y el cazador llama a la Lluvia de flechas
--   10,4 a 12,2  remate del guerrero (Rompehuesos): el mandril se va con su «¡puf!»
--   12,2 a 14,0  el Meteoro del mago se lleva al babuino, los otros dos huyen y la tripulación celebra
-- Efectos grandes (los que cuentan para AbilityShow.MAX_HEAVY, no más de 2 a la vez y 0,4 s entre inicios): Torbellino
-- 7,3, Nova 7,8, Curación en área 9,2, Lluvia 9,85, Rompehuesos 10,65 y Meteoro 12,1. Con las duraciones de
-- AbilityShow.SPECS, nunca hay más de 2 vivos a la vez. En calidad baja el Meteoro y la Lluvia se sustituyen por un
-- Rayo y un Disparo múltiple.
local BATTLE_SECONDS = 14
-- Segundos extra del reel tras la acción: el cartel de cierre con el nombre del juego se lee un segundo más.
local REEL_TAIL_SECONDS = 1

-- Dónde está cada uno de la tripulación: z positivo es hacia el mar, el giro (yaw) lo pone mirando algo al centro.
local BATTLE_SPOTS: { [string]: { x: number, z: number, yaw: number } } = {
	guerrero = { x = -5, z = 1, yaw = -8 },
	cazador = { x = -12, z = 5, yaw = -22 },
	mago = { x = 3, z = 6, yaw = 6 },
	medico = { x = 9, z = 4, yaw = 20 },
}
-- La manada: (x, z) donde frenan y (startX, startZ) de donde salen. Tamaños muy distintos (escala 0,63 a 1,15).
local BATTLE_MONKEYS = {
	{ name = "mandril", species = "Mandril", x = -7, z = -12, startX = -9, startZ = -48 },
	{ name = "babuino", species = "Babuino", x = 0, z = -13, startX = 1, startZ = -52 },
	{ name = "macaco", species = "Macaco", x = -14, z = -9, startX = -17, startZ = -44 },
	{ name = "aullador", species = "AulladorRojo", x = 8, z = -10, startX = 10, startZ = -46 },
}
local BATTLE_FLEE = { macaco = Vector3.new(-17, 0, -52), aullador = Vector3.new(10, 0, -52) }

type CameraKey = { pos: Vector3, look: Vector3, fov: number }
type CameraShot = { t0: number, t1: number, a: CameraKey, b: CameraKey }
type EventList = { { t: number, kind: string, [string]: any } }

local function cameraKey(pos: Vector3, look: Vector3, fov: number): CameraKey
	return { pos = pos, look = look, fov = fov }
end

-- Puntos de cámara de una lista de planos seguidos: cada plano va de "a" a "b" y entre uno y otro hay un corte. Se
-- repite el primer y el último punto de cada plano (con 0,01 s de diferencia) para que la spline Catmull-Rom del
-- plano no se curve hacia el siguiente (ver el corte del Rescate).
local function cutShots(shots: { CameraShot }): { { t: number, pos: Vector3, look: Vector3, fov: number? } }
	local points: { { t: number, pos: Vector3, look: Vector3, fov: number? } } = {}
	local function add(t: number, point: CameraKey)
		table.insert(points, { t = t, pos = point.pos, look = point.look, fov = point.fov })
	end
	for index, shot in shots do
		local last = index == #shots
		add(shot.t0, shot.a)
		add(shot.t0 + 0.01, shot.a)
		add(if last then shot.t1 else shot.t1 - 0.03, shot.b)
		if not last then
			add(shot.t1 - 0.01, shot.b)
		end
	end
	return points
end

local function battleShots(): { CameraShot }
	-- Reglas: ninguna cámara a menos de 9 studs de un maniquí o mono; el eje de la acción (tripulación en z = 1 a 6,
	-- monos en z = -9 a -13) se ve de lado (x = ±21 a ±23) o desde detrás de los monos (z = -21 a -22); cada habilidad
	-- tiene su plano. ground() resta la pendiente de la playa (0,08 por stud).
	return {
		-- 0 a 2,4: plano general desde el costado izquierdo; la manada baja de la selva.
		{
			t0 = 0,
			t1 = 2.4,
			a = cameraKey(ground(-22, 5.5, 2), ground(-2, 3, -18), 62),
			b = cameraKey(ground(-22, 5, 0), ground(-3, 3, -12), 56),
		},
		-- 2,4 a 3,6: rugido del mandril, de tres cuartos desde el costado derecho.
		{
			t0 = 2.4,
			t1 = 3.6,
			a = cameraKey(ground(16, 4.5, -3), ground(-7, 3.7, -12), 46),
			b = cameraKey(ground(15, 4.5, -2), ground(-7, 3.7, -12), 44),
		},
		-- 3,6 a 4,8: Grito de guerra (3,7), el guerrero y el mandril en cuadro, de lado y a 16 studs.
		{
			t0 = 3.6,
			t1 = 4.8,
			a = cameraKey(ground(-21, 4.5, 2), ground(-6, 3.5, -3), 52),
			b = cameraKey(ground(-19, 4.5, 1), ground(-6, 3.5, -3), 52),
		},
		-- 4,8 a 6,6: contraplano desde detrás de los monos: Disparo múltiple (5,46) y Bola de fuego (6,12) llegan.
		{
			t0 = 4.8,
			t1 = 6.6,
			a = cameraKey(ground(-4, 5, -22), ground(-4, 3.5, 2), 58),
			b = cameraKey(ground(2, 5.5, -21), ground(-4, 3.5, 2), 58),
		},
		-- 6,6 a 7,7: Embestida (6,75) y Torbellino (7,3), desde el costado izquierdo.
		{
			t0 = 6.6,
			t1 = 7.7,
			a = cameraKey(ground(-22, 5, 0), ground(-4, 3, -9), 58),
			b = cameraKey(ground(-21, 5, 0), ground(-4, 3, -9), 58),
		},
		-- 7,7 a 8,6: Nova de hielo sobre el aullador (7,8), desde el costado derecho.
		{
			t0 = 7.7,
			t1 = 8.6,
			a = cameraKey(ground(21, 5.5, -3), ground(-1, 3, -9), 58),
			b = cameraKey(ground(22, 5.5, -4), ground(-1, 3, -9), 58),
		},
		-- 8,6 a 9,6: Curación en área del médico (9,2), en alto desde la derecha.
		{
			t0 = 8.6,
			t1 = 9.6,
			a = cameraKey(ground(21, 6.5, -4), ground(2, 2.5, -2), 60),
			b = cameraKey(ground(22, 7, -3), ground(2, 2.5, -2), 60),
		},
		-- 9,6 a 10,4: Lluvia de flechas (9,85) sobre los monos, desde la izquierda.
		{
			t0 = 9.6,
			t1 = 10.4,
			a = cameraKey(ground(-23, 6, -2), ground(-4, 4, -8), 58),
			b = cameraKey(ground(-22, 6.5, -3), ground(-4, 4, -8), 58),
		},
		-- 10,4 a 12,2: Rompehuesos (10,65), plano bajo de tres cuartos desde detrás del mandril.
		{
			t0 = 10.4,
			t1 = 12.2,
			a = cameraKey(ground(-12, 3.4, -22), ground(-5, 3.2, -8), 52),
			b = cameraKey(ground(-9, 3.6, -21), ground(-5, 3.2, -8), 52),
		},
		-- 12,2 a 14: Meteoro (12,1) sobre el babuino y plano de grupo con la tripulación celebrando.
		{
			t0 = 12.2,
			t1 = BATTLE_SECONDS,
			a = cameraKey(ground(21, 6, -8), ground(-3, 5, -5), 60),
			b = cameraKey(ground(22, 7.5, -2), ground(-3, 5, -4), 60),
		},
	}
end

-- Montaje REEL de la batalla (solo para grabar en Studio con OBS y recortar a 9:16; no sale en el juego).
-- Se graba a 1920×1080 a 60 fps y se recorta la banda central: la banda mide (9/16)·alto de ancho, o sea 607,5 px,
-- desde x = 656,25. En OBS (filtro «Recortar/Rellenar»): izquierda 656, derecha 656 (queda 608 × 1080, de x = 656 a
-- 1264) y en CapCut se escala a 1080 × 1920. A 1280×720 la banda mide 405 px desde x = 437,5 (recorte de 406 × 720
-- desde x = 437). El motor la calcula con el tamaño real de la pantalla (Comic.reelBand), así que vale en otras
-- proporciones; el relleno liso fuera de la banda y una línea fina justo fuera de su borde enseñan el encuadre en
-- Studio. Los bocadillos y las onomatopeyas quedan dentro de la banda y de la zona segura de TikTok e Instagram
-- (12 % de arriba y 22 % de abajo libres).
local REEL_ASPECT = 9 / 16
-- Alto de pantalla (0 arriba) donde cae el centro de cada ventana; el plano pone ahí lo que enseña.
local REEL_CENTER_Y: { [string]: number } = { reelTop = 0.31, reelBottom = 0.69 }

type ReelCut = {
	t0: number,
	t1: number,
	shape: string, -- preset de ventana de Comic.PRESETS
	bg: string, -- "flat" | "halftone" | "speed"
	pos: Vector3, -- cámara
	posB: Vector3?, -- cámara al final (por defecto, un empuje del 6 % hacia el sujeto)
	subject: Vector3, -- centro de masas de la ACCIÓN (lanzador y objetivo), a la altura del pecho
	subjectB: Vector3?, -- adónde mira al final del plano (por defecto, el mismo)
	h: number?, -- alto en studs que ocupa la acción
	fill: number?, -- fracción del alto de la ventana que debe ocupar (0,45 grupo, 0,6 un personaje)
	width: number?, -- ancho en studs que caben en la banda; sin él sale de h y fill
	f: number?, -- alto de pantalla donde cae el sujeto (por defecto el centro de la ventana)
}

-- Fracción del alto de la pantalla que abarca cada ventana (para repartir el alto visible entre la acción y el aire).
local REEL_WINDOW_HEIGHT: { [string]: number } = {
	reelTall = 0.94,
	reelTop = 0.58,
	reelBottom = 0.58,
	reelSlant = 0.96,
	reelDiagL = 0.9,
	reelDiagR = 0.9,
}

-- Ancho en studs que debe caber en la banda para que una acción de `h` studs de alto ocupe `fill` del alto de la
-- ventana. El alto visible es ancho / (9/16); la ventana enseña `REEL_WINDOW_HEIGHT` de él.
local function reelWidth(cut: ReelCut): number
	if cut.width then
		return cut.width
	end
	return REEL_ASPECT * (cut.h or 7) / ((cut.fill or 0.45) * (REEL_WINDOW_HEIGHT[cut.shape] or 0.9))
end

-- Punto de cámara de un plano vertical. En vertical el FOV de Roblox es el del ALTO, así que se saca del ancho que
-- se quiere enseñar en la banda (aspecto 9:16): tan(fov/2) = (ancho / 2 / distancia) / (9/16). La cámara apunta un
-- poco por debajo (o por encima) del sujeto para que caiga a la altura `f` de la pantalla, en el centro de la ventana
-- alta en vez de en el de la pantalla.
local function reelKey(pos: Vector3, subject: Vector3, width: number, f: number): CameraKey
	local offset = subject - pos
	local distance = math.max(offset.Magnitude, 1)
	local fov = math.clamp(math.deg(2 * math.atan(width / 2 / distance / REEL_ASPECT)), 12, 100)
	local dir = offset.Unit
	local right = dir:Cross(Vector3.yAxis)
	if right.Magnitude < 1e-3 then
		return cameraKey(pos, subject, fov)
	end
	local lift = math.atan((0.5 - f) * 2 * math.tan(math.rad(fov / 2))) -- ángulo del sujeto sobre el eje de la cámara
	local aimed = CFrame.fromAxisAngle(right.Unit, -lift):VectorToWorldSpace(dir)
	return cameraKey(pos, pos + aimed * distance, fov)
end

-- Los cortes del reel: la cámara de cada plano y su ventana salen del mismo dato, así que no se desfasan. Las
-- posiciones de cámara son las de los planos de battleShots (laterales a x = ±21 a ±23 y desde detrás de los monos),
-- todas a más de 9 studs de cualquier maniquí o mono; lo que cierra el encuadre es el FOV, no la distancia: cada
-- plano apunta al centro de la acción y su ancho sale de h y fill (grupo 0,45, un personaje 0,6 del alto de la
-- ventana). Las ventanas de 60 % (reelTop y reelBottom) llevan fondo de puntos para no dejar el resto vacío.
local function battleReelCuts(): { ReelCut }
	local g = ground
	return {
		-- Gancho: contrapicado ligero; la cámara corre delante del mandril y lo deja de 12 a 9,5 studs. La manada baja
		-- de z = -48 a -31 (15 studs por segundo) y la cámara de z = -36 a -22,5.
		{
			t0 = 0,
			t1 = 1.4,
			shape = "reelTall",
			bg = "speed",
			pos = g(-5, 2, -36),
			posB = g(-5, 2, -22.5),
			subject = g(-9, 3.5, -48),
			subjectB = g(-8, 3.5, -31.5),
			width = 10,
		},
		-- La manada llega: mandril y macaco, los dos de la izquierda.
		{
			t0 = 1.4,
			t1 = 2.4,
			shape = "reelDiagR",
			bg = "flat",
			pos = g(-22, 5.5, 2),
			subject = g(-11, 3.5, -28),
			subjectB = g(-11, 3.5, -17),
			h = 7,
			fill = 0.45,
		},
		-- Rugido del mandril (2,6): primer plano en la ventana alta de arriba.
		{
			t0 = 2.4,
			t1 = 3.5,
			shape = "reelTop",
			bg = "halftone",
			pos = g(16, 4.5, -3),
			subject = g(-7, 4, -12),
			h = 6.5,
			fill = 0.6,
		},
		-- Grito de guerra (3,7).
		{
			t0 = 3.5,
			t1 = 4.5,
			shape = "reelSlant",
			bg = "flat",
			pos = g(-21, 4.5, 2),
			subject = g(-5, 3.5, 1),
			h = 6.5,
			fill = 0.6,
		},
		-- Apunta y dispara el cazador (flecha a 5,3; Disparo múltiple a 5,46).
		{
			t0 = 4.5,
			t1 = 5.45,
			shape = "reelDiagL",
			bg = "halftone",
			pos = g(-23, 5, -2),
			subject = g(-12, 3.5, 5),
			h = 6,
			fill = 0.6,
		},
		-- Bola de fuego del mago (6,12): empieza en él y sigue la bola hacia los monos.
		{
			t0 = 5.45,
			t1 = 6.5,
			shape = "reelTall",
			bg = "flat",
			pos = g(23, 5, -3),
			subject = g(2, 3.5, 3),
			subjectB = g(0, 3.5, -8),
			h = 6.5,
			fill = 0.45,
		},
		-- Embestida (6,75): el guerrero cruza de z = 1 a -6,5.
		{
			t0 = 6.5,
			t1 = 7.25,
			shape = "reelSlant",
			bg = "speed",
			pos = g(-22, 5, 0),
			subject = g(-5, 3.5, 0),
			subjectB = g(-4, 3.5, -6),
			h = 7,
			fill = 0.6,
		},
		-- Torbellino (7,3).
		{
			t0 = 7.25,
			t1 = 7.75,
			shape = "reelDiagR",
			bg = "halftone",
			pos = g(-21, 5, 0),
			subject = g(-5, 3.5, -8),
			h = 7,
			fill = 0.5,
		},
		-- Nova de hielo sobre el aullador (7,8).
		{
			t0 = 7.75,
			t1 = 8.6,
			shape = "reelBottom",
			bg = "halftone",
			pos = g(21, 5.5, -3),
			subject = g(8, 2.5, -10),
			h = 4.5,
			fill = 0.6,
		},
		-- Curación en área del médico (9,2).
		{
			t0 = 8.6,
			t1 = 9.5,
			shape = "reelTop",
			bg = "halftone",
			pos = g(21, 6.5, -4),
			subject = g(9, 3.5, 3),
			h = 6.5,
			fill = 0.6,
		},
		-- Lluvia de flechas (9,85) sobre mandril y babuino.
		{
			t0 = 9.5,
			t1 = 10.4,
			shape = "reelDiagL",
			bg = "halftone",
			pos = g(-23, 6, -2),
			subject = g(-3.5, 3.5, -12.5),
			h = 7,
			fill = 0.45,
		},
		-- Rompehuesos (10,65) y el mandril se va (10,95), desde detrás: guerrero y mandril.
		{
			t0 = 10.4,
			t1 = 11.3,
			shape = "reelDiagR",
			bg = "flat",
			pos = g(-12, 3.4, -22),
			subject = g(-5.5, 3.5, -9.5),
			h = 7,
			fill = 0.45,
		},
		-- El mago prepara el Meteoro (11,9).
		{
			t0 = 11.3,
			t1 = 12.2,
			shape = "reelBottom",
			bg = "halftone",
			pos = g(23, 5, 2),
			subject = g(3, 3.5, 6),
			h = 6.5,
			fill = 0.6,
		},
		-- El Meteoro (12,1) cae sobre el babuino: la ventana alta enseña también el cielo por donde baja.
		{
			t0 = 12.2,
			t1 = 13.2,
			shape = "reelTall",
			bg = "speed",
			pos = g(22, 7, -8),
			subject = g(0, 6, -13),
			h = 12,
			fill = 0.5,
			f = 0.55,
		},
		-- La tripulación celebra (cazador, mago y médico, apilados en profundidad) y el cartel de cierre.
		{
			t0 = 13.2,
			t1 = BATTLE_SECONDS + REEL_TAIL_SECONDS,
			shape = "reelSlant",
			bg = "flat",
			pos = g(22, 7.5, -2),
			subject = g(-1, 3.5, 4),
			h = 7,
			fill = 0.5,
		},
	}
end

local function battleReelShots(cuts: { ReelCut }): { CameraShot }
	local shots: { CameraShot } = {}
	for _, cut in cuts do
		local f = cut.f or REEL_CENTER_Y[cut.shape] or 0.5
		-- Empuje lento hacia el sujeto (6 %) y un poco más cerrado al final, para que ningún plano quede muerto.
		local subjectB = cut.subjectB or cut.subject
		local posB = cut.posB or cut.pos:Lerp(subjectB, 0.06)
		local width = reelWidth(cut)
		table.insert(shots, {
			t0 = cut.t0,
			t1 = cut.t1,
			a = reelKey(cut.pos, cut.subject, width, f),
			b = reelKey(posB, subjectB, width * 0.9, f),
		})
	end
	return shots
end

-- La capa cómic del reel: el modo reel, una ventana por corte y las frases. Las coordenadas de `pos` y `at` son
-- relativas a la banda (x) y al alto de la pantalla (y); los textos que no caben en la banda se parten en líneas.
-- El modo reel y una ventana por corte (compartido por las batallas de G5a y G5b).
local function addReelPanels(events: EventList, cuts: { ReelCut }, base: Color3, cream: Color3)
	table.insert(events, { t = 0, kind = "reel", on = true })
	for index, cut in cuts do
		table.insert(events, {
			t = cut.t0,
			kind = "panel",
			shape = cut.shape,
			bg = { style = cut.bg, colors = { base, cream } },
			seconds = if index == 1 then nil else 0.12,
		})
	end
end

-- Escritores de bocadillos y onomatopeyas de la banda del reel. `side` (left, right, up o down) elige de qué lado de
-- la cabeza sale el bocadillo: sin él, arriba, y en una ventana alta y de borde inclinado el bocadillo se corre hacia
-- abajo y tapa la cara. `band` es el ancho máximo de la onomatopeya como fracción del ancho de la banda (sfx.bandMax
-- de Comic).
local function reelWriters(events: EventList)
	local function bubble(t: number, actor: string, text: string, seconds: number, side: string?)
		table.insert(events, {
			t = t,
			kind = "bubble",
			balloon = "speech",
			actor = actor,
			text = text,
			seconds = seconds,
			side = side,
		})
	end
	local function sfx(t: number, text: string, x: number, y: number, rot: number, band: number, seconds: number)
		table.insert(events, {
			t = t,
			kind = "sfx",
			text = text,
			pos = { x, y },
			rot = rot,
			size = 0.4,
			bandMax = band,
			color = Color3.new(1, 1, 1),
			seconds = seconds,
		})
	end
	return bubble, sfx
end

-- Cartel de cierre del reel: el nombre del juego (nombre propio, no se traduce), en grande y bajo en la zona segura.
local function addReelTitle(events: EventList, t: number, y: number?)
	table.insert(events, {
		t = t,
		kind = "bubble",
		balloon = "title",
		verbatim = true,
		text = Config.GameName,
		at = { 0.5, y or 0.66 },
		seconds = 0.7 + REEL_TAIL_SECONDS,
	})
end

local function addReelComic(events: EventList, cuts: { ReelCut })
	addReelPanels(events, cuts, Color3.fromRGB(190, 122, 44), Color3.fromRGB(246, 232, 196))
	local bubble, sfx = reelWriters(events)
	-- Reglas: ninguna onomatopeya coincide con otra (≥ 0,7 s entre inicios y ≤ 0,5 s de vida salvo el gancho), van en
	-- las esquinas libres de la ventana (arriba o abajo) con un giro de 12 a 15° y nunca en la zona de un bocadillo.
	-- Gancho (primer 1,5 s): ¡ROAAAR! arriba sobre la manada que carga; la narración, abajo a la izquierda.
	sfx(0.15, Strings.later("¡ROAAAR!"), 0.5, 0.22, -12, 0.6, 1.0)
	table.insert(events, {
		t = 0.15,
		kind = "bubble",
		balloon = "narration",
		corner = "BL",
		text = Strings.later("Una manada baja de la selva…"),
		seconds = 1.9,
	})
	bubble(3.75, "guerrero", Strings.later("¡Que vengan!"), 0.8, "left") -- al lado de la cabeza, no sobre la cara
	bubble(5.8, "mago", Strings.later("¡Fuego!"), 0.7) -- sobre la cabeza del mago
	sfx(6.15, Strings.later("¡FUM!"), 0.7, 0.7, 15, 0.3, 0.4) -- abajo a la derecha
	sfx(6.95, Strings.later("¡WHOOSH!"), 0.3, 0.22, -15, 0.3, 0.4) -- arriba a la izquierda
	bubble(9.3, "medico", Strings.later("¡Aguanten!"), 0.9)
	sfx(10.7, Strings.later("¡CRASH!"), 0.3, 0.7, -15, 0.4, 0.5) -- abajo a la izquierda
	sfx(12.85, Strings.later("¡BUM!"), 0.7, 0.7, 12, 0.4, 0.5) -- abajo a la derecha
	bubble(13.0, "cazador", Strings.later("¡Lo logramos!"), 0.8)
	addReelTitle(events, 13.1)
end

local function battleActors(): { [string]: { [string]: any } }
	local actors: { [string]: { [string]: any } } = {}
	for _, member in CREW do
		local spot = BATTLE_SPOTS[member.name]
		actors[member.name] = {
			kind = "dummy",
			role = member.role,
			armor = member.armor,
			outfit = member.outfit,
			skin = member.skin,
			pos = beach(spot.x, spot.z),
			yaw = spot.yaw,
		}
	end
	return actors
end

-- Los eventos de la batalla que son iguales en la versión normal y en la cómic: monos, gestos y efectos.
-- Escritores de los eventos de acción de una batalla: add(evento), anim(t, actor, acción, segundos?) y
-- skill(t, efecto, de, a, args?) (evento abilityFx; el campo es «fx», no «kind»).
local function actionWriters(events: EventList)
	local function add(event: { t: number, kind: string, [string]: any })
		table.insert(events, event)
	end
	local function anim(t: number, actor: string, action: string, seconds: number?)
		add({ t = t, kind = "anim", actor = actor, action = action, seconds = seconds })
	end
	local function skill(t: number, name: string, from: string, to: any, args: { [string]: any }?)
		add({ t = t, kind = "abilityFx", fx = name, from = from, to = to, args = args })
	end
	return add, anim, skill
end

local function battleAction(): EventList
	local events: EventList = {}
	local add, anim, skill = actionWriters(events)
	local function monkey(t: number, name: string, fields: { [string]: any })
		local event: { [string]: any } = { t = t, kind = "monkey", server = true, name = name }
		for field, value in fields do
			event[field] = value
		end
		add(event :: any)
	end

	-- La manada baja de la selva corriendo y frena en su sitio (la velocidad decide si anda o corre).
	for _, member in BATTLE_MONKEYS do
		monkey(0, member.name, {
			species = member.species,
			at = Vector3.new(member.startX, 0, member.startZ),
			yaw = 180,
			action = "Idle",
		})
		monkey(0.3, member.name, { move = { pos = Vector3.new(member.x, 0, member.z), seconds = 2.4, yaw = 180 } })
	end
	-- Rugido del mandril y respuesta del guerrero.
	monkey(2.6, "mandril", { action = "Roar" })
	anim(3.65, "guerrero", "WarCry", 1.4)
	skill(3.7, "WarCry", "guerrero", nil, { seconds = 1.4 })
	-- Cazador: apunta con el arco, dispara (la flecha sale a los 0,16 s del gesto) y el mago lanza la bola de fuego.
	anim(4.75, "cazador", "AimBow", 1.8)
	anim(5.3, "cazador", "Arrow", 0.7)
	skill(5.46, "MultiShot", "cazador", "mandril", nil)
	monkey(5.62, "mandril", { action = "Hurt" })
	anim(5.7, "mago", "AimSpell", 1.4)
	anim(6.0, "mago", "Spell", 0.6)
	skill(6.12, "Fireball", "mago", "babuino", nil)
	monkey(6.35, "babuino", { action = "Hurt" })
	-- Guerrero: embestida entre el mandril y el babuino, y torbellino al llegar.
	anim(6.7, "guerrero", "Charge", 0.7)
	add({
		t = 6.75,
		kind = "move",
		actor = "guerrero",
		pos = beach(-4, -6.5),
		yaw = 0,
		seconds = 0.55,
		easing = Enum.EasingStyle.Quad,
	})
	skill(6.75, "Charge", "guerrero", nil, { seconds = 0.7 })
	anim(7.3, "guerrero", "Whirlwind", 1.2)
	skill(7.3, "Whirlwind", "guerrero", nil, { seconds = 1.2 })
	monkey(7.55, "mandril", { action = "Hurt" })
	monkey(7.6, "macaco", { action = "Hurt" })
	monkey(7.7, "babuino", { action = "Hurt" })
	-- Mago: nova de hielo sobre el aullador, que queda congelado.
	anim(7.6, "mago", "CastArea", 1.0)
	skill(7.8, "FrostNova", "mago", "aullador", { radius = 10 })
	skill(7.95, "Frozen", "mago", "aullador", { seconds = 1.5 })
	-- Médico: curación en área; cazador: Lluvia de flechas sobre la hilera de monos.
	anim(9.1, "medico", "CastArea", 1.1)
	skill(9.2, "AreaHeal", "medico", nil, nil)
	anim(9.25, "cazador", "AimBow", 1.3)
	anim(9.7, "cazador", "Arrow", 0.7)
	skill(9.85, "ArrowRain", "cazador", Vector3.new(-3, 0, -12.5), { radius = 11, seconds = 1.6 })
	monkey(10.05, "mandril", { action = "Hurt" })
	monkey(10.25, "babuino", { action = "Hurt" })
	-- Remate: Rompehuesos del guerrero (el golpe cae a los 0,25 s del gesto) y el mandril se va con su «¡puf!».
	anim(10.4, "guerrero", "Smash", 0.8)
	skill(10.65, "Smash", "guerrero", "mandril", nil)
	monkey(10.95, "mandril", { action = "Die" })
	-- Meteoro del mago sobre el babuino (cae en 0,8 s); el macaco y el aullador huyen hacia la selva.
	anim(11.9, "mago", "CastArea", 1.0)
	skill(12.1, "Meteor", "mago", "babuino", nil)
	monkey(12.0, "macaco", { move = { pos = BATTLE_FLEE.macaco, seconds = 1.6, yaw = 0 } })
	monkey(12.0, "aullador", { move = { pos = BATTLE_FLEE.aullador, seconds = 1.6, yaw = 0 } })
	monkey(13.0, "babuino", { action = "Die" })
	for _, member in CREW do
		anim(12.5, member.name, "Cheer", 1.6)
	end
	return events
end

-- La luz de las dos versiones: la de la llegada (exposición y una luz que sigue a la cámara) y las luces de los trajes
-- de los maniquíes bajas, que a 5 o 10 studs de la cámara queman el plano con el Bloom (lección de la travesía).
local function battleLight(): EventList
	return {
		{ t = 0, kind = "exposure", value = 0.28 },
		{
			t = 0,
			kind = "light",
			follow = true,
			offset = Vector3.new(0, 3, 0),
			color = Color3.fromRGB(255, 236, 210),
			brightness = 1,
			range = 60,
		},
		{ t = 0, kind = "dimLights", lights = 0.3, neon = false },
	}
end

-- Escritores de la capa cómic de la variante «comic» (sin banda): panel(t, forma, fondo, segundos?),
-- bubble(t, actor, texto, segundos) y sfx(t, texto, x, y, giro, tamaño).
local function comicWriters(events: EventList, base: Color3, cream: Color3)
	local function panel(t: number, shape: string, style: string, seconds: number?)
		table.insert(events, {
			t = t,
			kind = "panel",
			shape = shape,
			bg = { style = style, colors = { base, cream } },
			seconds = seconds,
		})
	end
	local function bubble(t: number, actor: string, text: string, seconds: number)
		table.insert(
			events,
			{ t = t, kind = "bubble", balloon = "speech", actor = actor, text = text, seconds = seconds }
		)
	end
	local function sfx(t: number, text: string, x: number, y: number, rot: number, size: number)
		table.insert(events, {
			t = t,
			kind = "sfx",
			text = text,
			pos = { x, y },
			rot = rot,
			size = size,
			color = Color3.new(1, 1, 1),
			seconds = 1.1,
		})
	end
	return panel, bubble, sfx
end

-- Fundido a negro del final. El reel dura un segundo más que la batalla y acaba en negro (0,3 s) para que el cartel de
-- cierre se lea hasta casi el final.
local function addBattleFade(events: EventList, reel: boolean, total: number)
	table.insert(events, {
		t = if reel then total - 0.3 else total - 0.6,
		kind = "fade",
		seconds = if reel then 0.3 else 0.5,
		toBlack = true,
	})
end

-- La batalla. "comic" es la variante para vídeo: sin franjas negras, con viñetas, fondos de puntos y de líneas,
-- onomatopeyas y bocadillos cortos de la tripulación (Cinematics/Comic). "reel" es la misma acción (mismos monos,
-- habilidades y tiempos) con otro montaje: cámaras y capa cómic pensadas para la banda vertical 9:16.
local function battleScene(variant: string): Scene
	local comic = variant == "comic"
	local reel = variant == "reel"
	local events: EventList = battleLight()
	for _, event in battleAction() do
		table.insert(events, event)
	end
	local camera = cutShots(battleShots())
	if reel then
		local cuts = battleReelCuts()
		camera = cutShots(battleReelShots(cuts))
		addReelComic(events, cuts)
	elseif comic then
		local panel, bubble, sfx = comicWriters(events, Color3.fromRGB(190, 122, 44), Color3.fromRGB(246, 232, 196))
		panel(0, "diagLeft", "halftone")
		table.insert(events, {
			t = 0.2,
			kind = "bubble",
			balloon = "narration",
			corner = "TL",
			text = Strings.later("Una manada baja de la selva…"),
			seconds = 2.0,
		})
		panel(2.4, "diagRight", "speed", 0.2)
		sfx(2.6, Strings.later("¡ROAAAR!"), 0.22, 0.22, -8, 0.2)
		panel(3.6, "tallSlant", "flat", 0.25)
		bubble(3.9, "guerrero", Strings.later("¡Que vengan!"), 0.9)
		panel(4.8, "wide", "halftone", 0.25)
		bubble(6.1, "mago", Strings.later("¡Fuego!"), 0.9)
		sfx(6.3, Strings.later("¡FUM!"), 0.72, 0.3, 10, 0.17)
		panel(6.6, "diagLeft", "speed", 0.2)
		panel(7.7, "diagRight", "halftone", 0.2)
		sfx(6.85, Strings.later("¡WHOOSH!"), 0.28, 0.3, -12, 0.18)
		panel(8.6, "wide", "flat", 0.25)
		panel(9.6, "diagLeft", "halftone", 0.2)
		bubble(9.3, "medico", Strings.later("¡Aguanten!"), 1.0)
		panel(10.4, "tallSlant", "speed", 0.2)
		sfx(10.7, Strings.later("¡CRASH!"), 0.3, 0.25, -6, 0.22)
		panel(12.2, "wide", "flat", 0.25)
		bubble(12.7, "cazador", Strings.later("¡Lo logramos!"), 1.0)
	else
		table.insert(events, { t = 0, kind = "letterbox" })
	end
	local total = if reel then BATTLE_SECONDS + REEL_TAIL_SECONDS else BATTLE_SECONDS
	addBattleFade(events, reel, total)
	return {
		duration = total,
		audience = "Self",
		freeze = false,
		skippable = true,
		hour = DUSK_HOUR,
		waitTerrain = { beach(-5, 1), beach(9, 4), ground(0, 0, -18) },
		actors = battleActors(),
		camera = camera,
		events = events,
	}
end

-- Batallas contra un jefe (G5b): la tripulación de G5a contra un jefe quieto (Orangután o Caudillo), solo para grabar.
-- El anchor es el pie del jefe, que mira a -Z (ArrivalService.play con «stage»: el jefe lo monta StageBoss y llega
-- como actor boss). Los maniquís se paran a distancia con el arma lista y no se acercan, salvo el guerrero para su
-- remate. Los dos terrenos no son llanos: terrainY(jefe, x, z) lee una rejilla medida en Studio (altura respecto al pie
-- del jefe) y los maniquís, además, se pegan al suelo con un rayo (snap, en Actors).
--
-- Línea de tiempo (14 s; las habilidades son las de AbilityShow con los gestos del animador):
--    2,5  rugido del jefe (evento bossRoar; no esencial)
--    3,0  Grito de guerra del guerrero (3,05)
--    4,0  el cazador apunta; flecha 4,55; Disparo múltiple 4,7; el jefe se queja (Hurt) 4,95
--    5,3  el mago apunta; Bola de fuego 5,72; Hurt 6,0
--    6,4  habilidad del jefe (bossSkill: pisotón o lluvia de rocas; el impacto llega 0,9 s o 1,1 a 1,9 s después)
--    7,6  el mago lanza la Nova de hielo (7,8) y el jefe queda congelado (7,95)
--    8,9  el médico cura en área (9,0)
--    9,1  el cazador apunta; Lluvia de flechas 9,7 (1,2 s); Hurt 9,95
--   10,4  Embestida del guerrero hasta el jefe (0,55 s); Rompehuesos 11,45; Hurt 11,6
--   12,0  el guerrero vuelve a su sitio; el mago prepara el Meteoro (12,2); Cheer 12,6; muerte del jefe 13,05
-- Efectos grandes de AbilityShow (no más de 2 vivos a la vez ni dos inicios a menos de 0,4 s): con las duraciones de
-- AbilityShow.SPECS (Config.Abilities.MeteorDelay = 0,8 s):
--   Nova 7,8 → 9,6 (1,8 s) · Curación en área 9,0 → 10,4 (1,4 s) · Lluvia 9,7 → 11,9 (1,2 + 1 s)
--   Rompehuesos 11,45 → 12,85 (1,4 s) · Meteoro 12,2 → 14,2 (0,8 + 1,2 s)
-- Máximo 2 vivos a la vez (Nova y Curación de 9,0 a 9,6; Curación y Lluvia de 9,7 a 10,4; Lluvia y Rompehuesos de
-- 11,45 a 11,9; Rompehuesos y Meteoro de 12,2 a 12,85). Los inicios están a 1,2, 0,7, 1,75 y 0,75 s unos de otros.
-- Piezas vivas como mucho: 38 + 14 (Hielo) + 40 = 92 a los 9,0 s y 60 + 40 + 14 + 14 = 128 a los 9,7 s, bajo el tope
-- de High (160). La habilidad del jefe (6,4) cae entre la Bola de fuego (acaba hacia 7,3) y la Nova (7,8): el pisotón
-- (impacto 7,3) no solapa con efectos grandes; la lluvia de rocas (7,5 a 8,3) roza el inicio de la Nova.
local BOSS_CREW_OFFSETS: { [string]: { number } } = {
	guerrero = { 4, 3 },
	cazador = { -8, -1 },
	mago = { 0, 0 },
	medico = { 7, -2 },
}

-- Rejillas medidas en Studio: altura del suelo respecto al pie del jefe. Columnas x = -36 a 36 y filas z = -48 a 12,
-- las dos de 6 en 6 (filas de z creciente).
local TERRAIN_X0 = -36
local TERRAIN_Z0 = -48
local TERRAIN_STEP = 6
local TERRAIN_GRIDS: { [string]: { { number } } } = {
	-- Plataforma llana de x = -36 a 6; barranco hacia +X, de suelo plano a -10,8.
	OrangutanDelManglar = {
		{ -0.4, -0.4, -0.5, -0.6, -0.7, -1.6, -5.7, -10.8, -10.8, -10.8, -10.8, -10.8, -10.8 },
		{ -0.2, -0.3, -0.4, -0.6, -0.7, -1, -3, -8.5, -10.8, -10.8, -10.8, -10.8, -10.8 },
		{ -0.1, -0.3, -0.4, -0.5, -0.6, -0.7, -1.4, -4.9, -10.8, -10.8, -10.8, -10.8, -10.8 },
		{ 0, -0.1, -0.2, -0.4, -0.5, -0.6, -0.8, -2.2, -7.6, -10.8, -10.8, -10.8, -10.8 },
		{ 0.2, 0, -0.1, -0.2, -0.3, -0.5, -0.7, -1.3, -4.3, -10.5, -10.8, -10.8, -10.8 },
		{ 0.3, 0.2, 0.2, 0.1, -0.1, -0.4, -0.6, -0.8, -2, -6.8, -10.8, -10.8, -10.8 },
		{ 0.4, 0.5, 0.5, 0.4, 0.2, -0.1, -0.4, -0.7, -1, -3.8, -9.7, -10.8, -10.8 },
		{ 0.6, 0.7, 0.8, 0.7, 0.5, 0.1, -0.2, -0.5, -0.7, -2, -7.3, -10.8, -10.8 },
		{ 0.8, 1, 1.1, 1, 0.8, 0.4, 0, -0.4, -0.7, -1.4, -5.5, -10.8, -10.8 },
		{ 1.1, 1.4, 1.5, 1.2, 1, 0.6, 0.1, -0.3, -0.6, -1.1, -4, -10.5, -10.8 },
		{ 1.4, 1.8, 1.8, 1.6, 1.1, 0.7, 0.2, -0.2, -0.6, -0.8, -2.6, -8.6, -10.8 },
	},
	-- Cima con ladera irregular que baja hacia delante del jefe (rocas pegadas al anchor en (-3,0,0) y (0,1,0)).
	ChimpanceCaudillo = {
		{ -5.9, -7.8, -9.3, -13.2, -15.3, -17.7, -18.1, -17.6, -15.3, -12.6, -11.4, -9.7, -10.1 },
		{ -4.5, -6.9, -8.7, -12.7, -15.4, -17.1, -18.2, -16.7, -15.2, -14, -12.7, -11.4, -11.6 },
		{ -3.1, -6.2, -8.2, -10.8, -14.1, -15.2, -15.9, -15.9, -14.8, -14.5, -12.7, -12.7, -14.5 },
		{ -4.2, -5.4, -8.1, -9.4, -11.3, -13.5, -13, -14, -11.7, -13.3, -13.4, -14.7, -16.2 },
		{ -5.6, -4.6, -6.5, -8.8, -8.5, -9.2, -11.6, -10.1, -10.8, -11.1, -12.7, -14.9, -18 },
		{ -5.9, -4.8, -5.3, -5.5, -5.6, -6.9, -7.1, -6.9, -8.4, -9.7, -11.6, -15.6, -19.7 },
		{ -6.8, -5.5, -4.1, -3, -2, -3, -3.8, -4.6, -6.5, -7.7, -13.2, -18, -21.4 },
		{ -8.7, -5.6, -2.8, -1.7, -0.3, 0.2, -1.5, -2.9, -5.3, -8.5, -13.1, -18.4, -23.1 },
		{ -10.7, -6.5, -2.9, -0.3, 0.3, 1, 0, -2.7, -7.7, -10.8, -15.4, -21.4, -27.8 },
		{ -12.6, -7.8, -4.6, -0.9, -0.5, 0.4, -1.5, -5.2, -7.9, -12.8, -17.5, -23.7, -30 },
		{ -14.4, -9.4, -6.9, -3.9, -2.5, -3.9, -3.9, -5.4, -11.5, -16.4, -20.9, -27.5, -33.4 },
	},
}

-- Altura del suelo (relativa al pie del jefe) en (x, z), con interpolación bilineal; fuera de la rejilla, la del borde.
local function terrainY(bossId: string, x: number, z: number): number
	local grid = TERRAIN_GRIDS[bossId]
	local columns = #grid[1]
	local fx = math.clamp((x - TERRAIN_X0) / TERRAIN_STEP, 0, columns - 1)
	local fz = math.clamp((z - TERRAIN_Z0) / TERRAIN_STEP, 0, #grid - 1)
	local ix = math.min(math.floor(fx), columns - 2)
	local iz = math.min(math.floor(fz), #grid - 2)
	local tx, tz = fx - ix, fz - iz
	local near = grid[iz + 1][ix + 1] + (grid[iz + 1][ix + 2] - grid[iz + 1][ix + 1]) * tx
	local far = grid[iz + 2][ix + 1] + (grid[iz + 2][ix + 2] - grid[iz + 2][ix + 1]) * tx
	return near + (far - near) * tz
end

-- Cámara: { desplazamiento x, altura sobre el suelo de ese punto, desplazamiento z } respecto al centro C de la
-- tripulación. Mirada: { "abs", x, altura, z } (marco del jefe), { "crew", nombre, altura } (sobre un maniquí) o
-- { "mid", nombre | "C", altura } (a medio camino entre ese maniquí, o C, y el pie del jefe).
type Cam = { number }
type Look = { any }
type PlanShot = {
	t0: number,
	t1: number,
	cam: Cam,
	camB: Cam?, -- cámara al final del plano (por defecto, un empuje del 4 % hacia la mirada)
	look: Look,
	lookB: Look?, -- mirada al final (por defecto, la misma)
	fov: number,
}
-- Un corte del reel: lo mismo, con su ventana (ver ReelCut) y el tamaño de la acción.
type ReelPlan = {
	t0: number,
	t1: number,
	shape: string,
	bg: string,
	cam: Cam,
	camB: Cam?,
	subject: Look,
	subjectB: Look?,
	h: number?,
	fill: number?,
	width: number?,
	f: number?,
}
type BossBattle = {
	centre: { number }, -- C = (x, z) en el marco del jefe: el mago está ahí y los demás, en BOSS_CREW_OFFSETS
	colors: { Color3 }, -- { color del jefe, crema } para los paneles del cómic
	narration: string,
	quote: string, -- la frase del jefe
	skill: string, -- habilidad que enseña el jefe (bossSkill)
	wait: { Vector3 }, -- puntos del suelo que deben estar cargados antes de empezar (waitTerrain)
	plan: { PlanShot },
	reel: { ReelPlan },
}

-- Los planos de cámara (tiempo, cámara de a b, mirada y FOV). Ninguna cámara a menos de 12 studs de un maniquí.
local function bossPlan(): { PlanShot }
	return {
		-- 1 general desde el costado izquierdo.
		{
			t0 = 0,
			t1 = 2.6,
			cam = { 26, 7, 8 },
			camB = { 26, 6, 2 },
			look = { "mid", "C", 5 },
			lookB = { "mid", "C", 5 },
			fov = 56,
		},
		-- 2 rugido del jefe, a su cara.
		{ t0 = 2.6, t1 = 3.8, cam = { 18, 10, -10 }, camB = { 17, 10, -9 }, look = { "abs", 0, 9, 0 }, fov = 46 },
		-- 3 Grito de guerra del guerrero.
		{ t0 = 3.8, t1 = 4.8, cam = { -14, 6, 14 }, look = { "crew", "guerrero", 3.5 }, fov = 52 },
		-- 4 flecha y Bola de fuego hacia el jefe, desde el costado derecho.
		{ t0 = 4.8, t1 = 6.6, cam = { 26, 6, 6 }, look = { "mid", "C", 4 }, fov = 52 },
		-- 5 habilidad del jefe, desde detrás de la tripulación.
		{ t0 = 6.6, t1 = 8.0, cam = { 22, 8, -12 }, camB = { 20, 9, -12 }, look = { "abs", 0, 6, 0 }, fov = 46 },
		-- 6 Nova de hielo.
		{ t0 = 8.0, t1 = 9.0, cam = { -20, 5, 2 }, look = { "abs", -2, 4, -6 }, fov = 58 },
		-- 7 Curación en área y Lluvia de flechas.
		{ t0 = 9.0, t1 = 10.4, cam = { 22, 9, 0 }, look = { "mid", "C", 3 }, fov = 58 },
		-- 8 Embestida y Rompehuesos.
		{ t0 = 10.4, t1 = 12.0, cam = { -20, 3.4, -6 }, look = { "mid", "guerrero", 3.5 }, fov = 52 },
		-- 9 Meteoro, muerte del jefe y celebración.
		{
			t0 = 12.0,
			t1 = BATTLE_SECONDS,
			cam = { 22, 8, -10 },
			camB = { 22, 10, -10 },
			look = { "abs", 0, 7, 0 },
			lookB = { "abs", 0, 7, -6 },
			fov = 55,
		},
	}
end

-- Los cortes del reel (uno por plano normal, o más finos): cámara de los planos de arriba y sujeto en el centro de la
-- acción, con la ventana y el tamaño de cada uno (h y fill como en battleReelCuts; `width` si se quiere una anchura fija).
local function bossReelPlan(): { ReelPlan }
	return {
		-- Gancho: el jefe, grande, desde el costado.
		{
			t0 = 0,
			t1 = 1.4,
			shape = "reelTall",
			bg = "speed",
			cam = { 26, 7, 8 },
			subject = { "abs", 0, 6, 0 },
			width = 14,
		},
		-- La tripulación y el jefe al fondo.
		{
			t0 = 1.4,
			t1 = 2.6,
			shape = "reelDiagR",
			bg = "flat",
			cam = { 26, 6, 6 },
			subject = { "mid", "C", 3.5 },
			width = 28,
		},
		-- Rugido del jefe.
		{
			t0 = 2.6,
			t1 = 3.7,
			shape = "reelTop",
			bg = "halftone",
			cam = { 18, 10, -10 },
			subject = { "abs", 0, 9, 0 },
			h = 7,
			fill = 0.6,
		},
		-- Grito de guerra del guerrero.
		{
			t0 = 3.7,
			t1 = 4.7,
			shape = "reelSlant",
			bg = "flat",
			cam = { -14, 6, 14 },
			subject = { "crew", "guerrero", 3.5 },
			width = 11,
		},
		-- El cazador apunta y dispara.
		{
			t0 = 4.7,
			t1 = 5.6,
			shape = "reelDiagL",
			bg = "halftone",
			cam = { -22, 5, 5 },
			subject = { "crew", "cazador", 3.5 },
			width = 12,
		},
		-- Bola de fuego del mago hacia el jefe.
		{
			t0 = 5.6,
			t1 = 6.6,
			shape = "reelTall",
			bg = "flat",
			cam = { 26, 6, 6 },
			subject = { "crew", "mago", 3.5 },
			width = 22,
		},
		-- Habilidad del jefe.
		{
			t0 = 6.6,
			t1 = 8.0,
			shape = "reelSlant",
			bg = "speed",
			cam = { 22, 8, -12 },
			camB = { 20, 9, -12 },
			subject = { "abs", 0, 5, 0 },
			h = 12,
			fill = 0.55,
		},
		-- Nova de hielo.
		{
			t0 = 8.0,
			t1 = 9.0,
			shape = "reelBottom",
			bg = "halftone",
			cam = { -20, 5, 2 },
			subject = { "abs", -2, 3, -6 },
			width = 16,
		},
		-- Curación en área y Lluvia de flechas.
		{
			t0 = 9.0,
			t1 = 10.4,
			shape = "reelTop",
			bg = "halftone",
			cam = { 22, 9, 0 },
			subject = { "mid", "C", 3 },
			width = 26,
		},
		-- Embestida y Rompehuesos.
		{
			t0 = 10.4,
			t1 = 12.0,
			shape = "reelDiagR",
			bg = "speed",
			cam = { -20, 3.4, -6 },
			subject = { "mid", "guerrero", 3.5 },
			width = 24,
		},
		-- Meteoro y muerte del jefe: la ventana alta enseña también el cielo por donde baja.
		{
			t0 = 12.0,
			t1 = 13.2,
			shape = "reelTall",
			bg = "speed",
			cam = { 22, 8, -10 },
			subject = { "abs", 0, 6, 0 },
			h = 14,
			fill = 0.5,
			f = 0.55,
		},
		-- La tripulación celebra y el cartel de cierre.
		{
			t0 = 13.2,
			t1 = BATTLE_SECONDS + REEL_TAIL_SECONDS,
			shape = "reelTop",
			bg = "halftone",
			cam = { 22, 7, -2 },
			subject = { "crew", "mago", 3.5 },
			width = 22,
			f = 0.2,
		},
	}
end

-- Cámaras propias del Orangután: en el manglar los troncos y las copas tapaban dos planos. Posiciones medidas en
-- Studio (rayos contra todo lo que no es Terrain; desplazamientos respecto a C = (-9, -24)): para el guerrero, desde
-- (12, 4, -22) en el marco del jefe (21, 4, 2 desde C; el (8, 6, -10) también estaba despejado en el rayo, pero un tronco cercano se veía delante), y para el punto medio, desde (12, 4, -14) (21, 4, 10 desde C).
local function orangutanPlan(): { PlanShot }
	local plan = bossPlan()
	plan[3].cam = { 21, 4, 2 }
	return plan
end

local function orangutanReel(): { ReelPlan }
	local reel = bossReelPlan()
	reel[2].cam = { 21, 4, 10 }
	reel[4].cam = { 21, 4, 2 }
	return reel
end

local BOSS_BATTLES: { [string]: BossBattle } = {
	OrangutanDelManglar = {
		centre = { -9, -24 },
		colors = { Color3.fromRGB(26, 112, 108), Color3.fromRGB(246, 232, 196) },
		narration = Strings.later("En el corazón del manglar…"),
		quote = Strings.later("¡Fuera de mi manglar!"),
		skill = "stomp",
		wait = { Vector3.new(0, 0, 0), Vector3.new(-12, -0.3, -24) },
		plan = orangutanPlan(),
		reel = orangutanReel(),
	},
	ChimpanceCaudillo = {
		centre = { 0, -18 },
		colors = { Color3.fromRGB(140, 44, 36), Color3.fromRGB(244, 226, 190) },
		narration = Strings.later("En lo alto de la montaña…"),
		quote = Strings.later("¡Esta montaña es mía!"),
		skill = "rockRain",
		wait = { Vector3.new(0, 0, 0), Vector3.new(0, -7.1, -18) },
		plan = bossPlan(),
		reel = bossReelPlan(),
	},
}

-- Dónde está cada uno de la tripulación (x, z) en el marco del jefe.
local function crewSpot(battle: BossBattle, name: string): (number, number)
	local offset = BOSS_CREW_OFFSETS[name]
	return battle.centre[1] + offset[1], battle.centre[2] + offset[2]
end

-- Giro (grados) de quien está en (x, z) para mirar al jefe, que está en (0, 0): yaw 0 mira a -Z y 180 a +Z.
local function yawToBoss(x: number, z: number): number
	return math.deg(math.atan2(x, z))
end

-- Un punto sobre el suelo del jefe (x, z) a "height" studs.
local function bossGround(bossId: string, x: number, height: number, z: number): Vector3
	return Vector3.new(x, terrainY(bossId, x, z) + height, z)
end

local function bossCamPoint(bossId: string, battle: BossBattle, cam: Cam): Vector3
	return bossGround(bossId, battle.centre[1] + cam[1], cam[2], battle.centre[2] + cam[3])
end

local function bossLookPoint(bossId: string, battle: BossBattle, look: Look): Vector3
	local kind = look[1]
	if kind == "abs" then
		return bossGround(bossId, look[2], look[3], look[4])
	end
	local x, z = battle.centre[1], battle.centre[2]
	if look[2] ~= "C" then
		x, z = crewSpot(battle, look[2])
	end
	if kind == "mid" then
		x, z = x / 2, z / 2
	end
	return bossGround(bossId, x, look[3], z)
end

-- Un empuje del 4 % hacia la mirada, para que ningún plano quede muerto.
local function pushed(pos: Vector3, look: Vector3): Vector3
	return pos:Lerp(look, 0.04)
end

local function bossShots(bossId: string, battle: BossBattle): { CameraShot }
	local shots: { CameraShot } = {}
	for _, plan in battle.plan do
		local posA = bossCamPoint(bossId, battle, plan.cam)
		local lookA = bossLookPoint(bossId, battle, plan.look)
		local posB = if plan.camB then bossCamPoint(bossId, battle, plan.camB) else pushed(posA, lookA)
		local lookB = if plan.lookB then bossLookPoint(bossId, battle, plan.lookB) else lookA
		table.insert(shots, {
			t0 = plan.t0,
			t1 = plan.t1,
			a = cameraKey(posA, lookA, plan.fov),
			b = cameraKey(posB, lookB, plan.fov),
		})
	end
	return shots
end

local function bossReelCuts(bossId: string, battle: BossBattle): { ReelCut }
	local cuts: { ReelCut } = {}
	for _, plan in battle.reel do
		table.insert(cuts, {
			t0 = plan.t0,
			t1 = plan.t1,
			shape = plan.shape,
			bg = plan.bg,
			pos = bossCamPoint(bossId, battle, plan.cam),
			posB = if plan.camB then bossCamPoint(bossId, battle, plan.camB) else nil,
			subject = bossLookPoint(bossId, battle, plan.subject),
			subjectB = if plan.subjectB then bossLookPoint(bossId, battle, plan.subjectB) else nil,
			h = plan.h,
			fill = plan.fill,
			width = plan.width,
			f = plan.f,
		})
	end
	return cuts
end

local function bossBattleActors(bossId: string, battle: BossBattle): { [string]: { [string]: any } }
	local actors: { [string]: { [string]: any } } = { boss = { kind = "boss", id = bossId } }
	for _, member in CREW do
		local x, z = crewSpot(battle, member.name)
		actors[member.name] = {
			kind = "dummy",
			role = member.role,
			armor = member.armor,
			outfit = member.outfit,
			skin = member.skin,
			pos = Vector3.new(x, terrainY(bossId, x, z), z),
			yaw = yawToBoss(x, z),
			snap = true,
		}
	end
	return actors
end

-- Los eventos de la batalla contra el jefe, iguales en las tres versiones (ver la línea de tiempo más arriba).
local function bossBattleAction(battle: BossBattle): EventList
	local events: EventList = {}
	local add, anim, skill = actionWriters(events)
	local function bossAct(t: number, action: string)
		add({ t = t, kind = "bossAct", server = true, action = action })
	end
	local function crewMove(t: number, name: string, x: number, z: number, seconds: number, easing: Enum.EasingStyle?)
		add({
			t = t,
			kind = "move",
			actor = name,
			pos = Vector3.new(x, 0, z), -- la Y sale del suelo (snap)
			yaw = yawToBoss(x, z),
			seconds = seconds,
			easing = easing,
		})
	end

	add({ t = 2.5, kind = "bossRoar", server = true })
	-- Grito de guerra del guerrero.
	anim(3.0, "guerrero", "WarCry", 1.4)
	skill(3.05, "WarCry", "guerrero", nil, { seconds = 1.4 })
	-- El cazador dispara (la flecha sale 0,16 s después del gesto) y el mago lanza la Bola de fuego.
	anim(4.0, "cazador", "AimBow", 1.8)
	anim(4.55, "cazador", "Arrow", 0.7)
	skill(4.7, "MultiShot", "cazador", "boss", nil)
	bossAct(4.95, "Hurt")
	anim(5.3, "mago", "AimSpell", 1.4)
	anim(5.6, "mago", "Spell", 0.6)
	skill(5.72, "Fireball", "mago", "boss", nil)
	bossAct(6.0, "Hurt")
	-- Habilidad del jefe (pisotón o lluvia de rocas): solo visual.
	add({ t = 6.4, kind = "bossSkill", server = true, skill = battle.skill })
	-- El mago congela al jefe con la Nova de hielo.
	anim(7.6, "mago", "CastArea", 1.0)
	skill(7.8, "FrostNova", "mago", "boss", { radius = 12 })
	skill(7.95, "Frozen", "mago", "boss", { seconds = 1.5 })
	-- El médico cura en área; el cazador, Lluvia de flechas sobre el jefe (1,2 s: no hay tres efectos grandes a la vez).
	anim(8.9, "medico", "CastArea", 1.1)
	skill(9.0, "AreaHeal", "medico", nil, nil)
	anim(9.1, "cazador", "AimBow", 1.3)
	anim(9.55, "cazador", "Arrow", 0.7)
	skill(9.7, "ArrowRain", "cazador", Vector3.new(0, 0, -2), { radius = 10, seconds = 1.2 })
	bossAct(9.95, "Hurt")
	-- Remate: Embestida del guerrero hasta el jefe y Rompehuesos (el golpe cae 0,25 s después del gesto).
	anim(10.4, "guerrero", "Charge", 0.7)
	crewMove(10.45, "guerrero", 0, -11, 0.55, Enum.EasingStyle.Quad)
	skill(10.45, "Charge", "guerrero", nil, { seconds = 0.7 })
	anim(11.2, "guerrero", "Smash", 0.8)
	skill(11.45, "Smash", "guerrero", "boss", nil)
	bossAct(11.6, "Hurt")
	-- El guerrero vuelve a su sitio, el mago prepara el Meteoro (cae en MeteorDelay) y el jefe se va con su «¡puf!».
	local homeX, homeZ = crewSpot(battle, "guerrero")
	crewMove(12.0, "guerrero", homeX, homeZ, 0.5)
	anim(12.0, "mago", "CastArea", 1.0)
	skill(12.2, "Meteor", "mago", "boss", { radius = 8 })
	for _, member in CREW do
		anim(12.6, member.name, "Cheer", 1.4)
	end
	bossAct(13.05, "Die")
	return events
end

-- Capa cómic de la variante «comic» (sin banda): un panel por plano, narración, frases, onomatopeyas.
local function addBossComic(events: EventList, battle: BossBattle)
	local base, cream = battle.colors[1], battle.colors[2]
	local panel, bubble, sfx = comicWriters(events, base, cream)
	panel(0, "diagLeft", "halftone")
	table.insert(events, {
		t = 0.2,
		kind = "bubble",
		balloon = "narration",
		corner = "TL",
		text = battle.narration,
		seconds = 2.2,
	})
	panel(2.6, "diagRight", "speed", 0.2)
	sfx(2.65, Strings.later("¡ROAAAR!"), 0.22, 0.22, -8, 0.2)
	bubble(2.9, "boss", battle.quote, 0.9)
	panel(3.8, "wide", "flat", 0.25) -- el guerrero entero (en tallSlant quedaba en el borde)
	bubble(4.0, "guerrero", Strings.later("¡Que vengan!"), 0.8)
	panel(4.8, "diagLeft", "halftone", 0.25)
	bubble(5.9, "mago", Strings.later("¡Fuego!"), 0.7)
	sfx(6.15, Strings.later("¡FUM!"), 0.72, 0.3, 10, 0.17) -- la bola de fuego da en el jefe
	panel(6.6, "diagLeft", "speed", 0.2)
	panel(8.0, "diagRight", "halftone", 0.2)
	panel(9.0, "wide", "flat", 0.25)
	bubble(9.2, "medico", Strings.later("¡Aguanten!"), 1.0)
	panel(10.4, "diagLeft", "speed", 0.2)
	sfx(10.5, Strings.later("¡WHOOSH!"), 0.28, 0.3, -12, 0.18)
	sfx(11.5, Strings.later("¡CRASH!"), 0.3, 0.25, -6, 0.22)
	panel(12.0, "diagRight", "speed", 0.2)
	sfx(12.95, Strings.later("¡BUM!"), 0.7, 0.3, 10, 0.2)
	bubble(13.2, "cazador", Strings.later("¡Lo logramos!"), 0.9)
end

-- Capa cómic del reel: el modo reel, una ventana por corte y las frases dentro de la banda.
local function addBossReelComic(events: EventList, cuts: { ReelCut }, battle: BossBattle)
	addReelPanels(events, cuts, battle.colors[1], battle.colors[2])
	local bubble, sfx = reelWriters(events)
	table.insert(events, {
		t = 0.15,
		kind = "bubble",
		balloon = "narration",
		corner = "BL",
		text = battle.narration,
		seconds = 2.0,
	})
	sfx(2.65, Strings.later("¡ROAAAR!"), 0.5, 0.78, -12, 0.6, 0.9) -- abajo, sobre los puntos: arriba va la frase del jefe
	bubble(2.95, "boss", battle.quote, 0.7, "right")
	bubble(3.85, "guerrero", Strings.later("¡Que vengan!"), 0.8, "left")
	bubble(5.8, "mago", Strings.later("¡Fuego!"), 0.7)
	sfx(7.3, Strings.later("¡FUM!"), 0.7, 0.7, 15, 0.3, 0.4)
	bubble(9.2, "medico", Strings.later("¡Aguanten!"), 0.9)
	sfx(10.5, Strings.later("¡WHOOSH!"), 0.3, 0.22, -15, 0.3, 0.4)
	sfx(11.5, Strings.later("¡CRASH!"), 0.3, 0.7, -15, 0.4, 0.5)
	sfx(12.95, Strings.later("¡BUM!"), 0.7, 0.7, 12, 0.4, 0.5)
	bubble(13.5, "cazador", Strings.later("¡Lo logramos!"), 0.8)
	addReelTitle(events, 13.4, 0.76) -- sobre los puntos de la ventana de arriba, no sobre la tripulación
end

-- La batalla contra "bossId" en su versión normal, "comic" o "reel" (mismas acciones y tiempos; cámaras y capa cómic
-- cambian). Audiencia Self, sin congelar, saltable y con la hora del anochecer, como las de G5a.
local function bossBattleScene(bossId: string, variant: string): Scene
	local battle = BOSS_BATTLES[bossId]
	local reel = variant == "reel"
	local events: EventList = battleLight()
	-- El jefe está más lejos de la cámara que los monos de la playa y su pelaje es oscuro: más exposición y más luz.
	for _, event in events do
		if event.kind == "exposure" then
			event.value = 0.42
		elseif event.kind == "light" then
			event.brightness = 1.8
		end
	end
	for _, event in bossBattleAction(battle) do
		table.insert(events, event)
	end
	local camera: { { t: number, pos: Vector3, look: Vector3, fov: number? } }
	if reel then
		local cuts = bossReelCuts(bossId, battle)
		camera = cutShots(battleReelShots(cuts))
		addBossReelComic(events, cuts, battle)
	else
		camera = cutShots(bossShots(bossId, battle))
		if variant == "comic" then
			addBossComic(events, battle)
		else
			table.insert(events, { t = 0, kind = "letterbox" })
		end
	end
	local total = if reel then BATTLE_SECONDS + REEL_TAIL_SECONDS else BATTLE_SECONDS
	addBattleFade(events, reel, total)
	return {
		duration = total,
		audience = "Self",
		freeze = false,
		skippable = true,
		hour = DUSK_HOUR,
		waitTerrain = battle.wait,
		actors = bossBattleActors(bossId, battle),
		camera = camera,
		events = events,
	}
end

-- Naufragio (G6a), en el Lobby y de noche, en coordenadas absolutas del mundo (sin anchor). El barco (ShipwreckSet) navega
-- 21 s con la proa hacia la luna roja, al este del Lobby (rumbo y emplazamiento: ShipwreckSet.ROUTE); la cámara va en su
-- marco (x a proa, y arriba, z a estribor, origen en el pivote) y se muestrea cada SHIPWRECK_STEP s con el movimiento del
-- barco, así viaja pegada a él. Un solo vuelo continuo POR BABOR (z negativo del marco; con el barco rumbo al este, babor es
-- el sur): apertura desde detrás mirando a proa y la luna, giro hacia el norte, pasada de proa a popa por fuera de la borda
-- (z = -20 a -14, a 6 de los contenedores y a 3 del costado del puente) mirando al puente, entrada por el cristal del costado
-- de babor y, dentro, detrás del avatar (2,4 studs atrás, 0,35 a su derecha, a la altura de sus ojos,
-- ShipwreckSet.AVATAR_EYE) mirando a proa por el cristal con la luna.
-- REGLA: la cámara NUNCA mira hacia el oeste (azimut 222° a 318° con elevación < 25°: enseñaría el barco encallado del Lobby
-- a 400-500 studs) ni al sur (azimut 120° a 240° con elevación < 12°); ShipwreckSet.checkLook lo comprueba en preview() y
-- también que la cámara no salga de x 270 a 590 y z -170 a 170.
-- Medidas del barco: puente a popa (x de -32 a -26, z de -12 a 12, suelo en y 19,98, techo subido 1,2 con ShipwreckSet:
-- 24,7), cristal de delante en x = -25,95 y los de los costados en z = ±11,85 (y de 21,2 a 23,7); contenedores en x de -20 a
-- -8 y de 3 a 15 hasta y = 23,5; grúa en x de 21 a 33; castillo a popa de x = -36,5. Ningún punto muestreado cada 0,25 s
-- queda a menos de 0,6 de un sólido (comprobado con cajas; ShipwreckSet.checkCamera lo repite con GetPartBoundsInRadius en
-- preview()).
-- Azimut/elevación de la mirada en el mundo y posición de la cámara (x, z), con la luna a 93,6°, rumbo +11,6° y la ruta
-- centrada en (430, 40) (la recta se corre a x 333 a 580): t = 0: 64°/-18° en (272, 18); 2: 55°/-18° en (298, -2); 4: 44°/-17°
-- en (331, -22); 6: 20°/-17° en (384, -30); 8: 351°/-13° en (434, -30); 10: 336°/-8° en (454, -18); 11: 333°/-6° en
-- (460, -12); 12: 335°/-5° en (461, -1); 13: 342°/-5° en (467, 5); 14: 347°/-3° en (476, 7); 15: 356°/-1° en (482, 9);
-- 16: 9°/0° en (490, 9); 17: 29°/2° en (502, 15); 18: 103°/1° en (515, 20); 19: 104°/1° en (526, 18); 21: 102°/1° en (550, 13).
-- Los dos últimos puntos miran a proa con la inclinación que deja la luna en el tercio de arriba del cuadro (elevación - 8°,
-- entre 0 y 6°; calculada en shipwreckCamera); los ángulos entre el eje de la cámara y la luna (t = 0, 8, 14 y 19) salen de
-- ShipwreckSet.cameraMoonAngles(scene.prepare(), { 0, 8, 14, 19 }). Los números son de arranque: se tocan aquí.
-- Dura 40 s: el viaje y la tormenta acaban en negro a los 31 (el barco que navega se destruye en el evento dawn; su recorrido,
-- ShipwreckSet.SAIL_SECONDS, sigue siendo de 31 s) y de 31,2 a 40 es el amanecer sobre el Lobby real (SHIPWRECK_DAWN_SHOTS).
local SHIPWRECK_SECONDS = 40
local SHIPWRECK_STEP = 0.25
local SHIPWRECK_HOUR = ShipwreckSet.HOUR -- 18,8: noche con estrellas y la luna baja (G6c, justo antes de amanecer: ~5,3)

local SHIPWRECK_CAMERA: { { t: number, pos: Vector3, look: Vector3, fov: number? } } = {
	{ t = 0, pos = Vector3.new(-52, 41, -50), look = Vector3.new(14, 2, 0), fov = 55 },
	{ t = 4, pos = Vector3.new(-34, 41, -78), look = Vector3.new(15, -2, 0), fov = 54 },
	{ t = 8, pos = Vector3.new(20, 30, -65), look = Vector3.new(-5, 6, 0), fov = 52 },
	-- Las miradas de 11 y 12,5 se giran unos 8° a proa: con las de antes la Isla Calavera (oeste) asomaba por el borde izquierdo.
	{ t = 11, pos = Vector3.new(6, 27, -42), look = Vector3.new(-17, 21, 0), fov = 42 },
	{ t = 12.5, pos = Vector3.new(-12, 24.5, -27), look = Vector3.new(-23, 21.5, 0), fov = 44 },
	{ t = 14, pos = Vector3.new(-18, 23.2, -20), look = Vector3.new(-27, 22, 0), fov = 44 },
	{ t = 15.2, pos = Vector3.new(-26, 22.9, -16.5), look = Vector3.new(-29, 22.8, -4), fov = 44 },
	-- Pasa el cristal del costado de babor del puente (z = -11,85, banda de y 21,2 a 23,7) entre este punto y el siguiente.
	{ t = 16.2, pos = Vector3.new(-29, 22.9, -14.5), look = Vector3.new(-29, 22.9, -6), fov = 45 },
	{ t = 16.9, pos = Vector3.new(-29.8, 23, -8), look = Vector3.new(-28.5, 23.2, -1), fov = 48 },
}

-- PLANOS CERRADOS, de 17,4 s al final (corte seco entre cada uno, sin curva): una lista de planos con cámara casi ESTÁTICA en
-- el marco del barco (x a proa, y arriba, z a estribor; el barco no balancea en ese marco, así que el cabeceo y el balanceo de
-- la tormenta se notan contra la cámara). Cada plano: t0 y t1 (segundos), from = pose de arranque y to = pose final (sin to
-- la cámara no se mueve; con to avanza lento de una a otra), hold = segundos finales quietos (llega a to en t1 - hold y se
-- queda). Pose: pos (marco del barco), yaw (grados a estribor desde la proa), pitch (grados arriba) y fov. El primero es el
-- final de G6a: detrás y encima del puente, mirando a proa por encima de su techo (desde dentro el techo tapaba la luna);
-- los demás son de la tormenta. Medidas del barco: eslora de x -38 a 38, ancho de z -12 a 12, mar en y local 4,4, cubierta en
-- 12,9, puente de x -32 a -26 (techo en 24,7), contenedores en x de -20 a -8 y de 3 a 15 hasta y 23,5, grúa de x 21 a 33.
-- Mirar a popa es mirar al oeste (el Lobby): en el plano del puente lo tapa el propio puente. Números de arranque: se tocan aquí.
type Pose = { pos: Vector3, yaw: number, pitch: number, fov: number }
-- rocked = true: la cámara va en el marco del barco CON balanceo (el barco no se mueve en el cuadro y el horizonte se inclina). Hace
-- falta cuando la cámara está pegada al casco o dentro del puente: en el marco sin balanceo el casco la atravesaba al rolar.
type Shot = { t0: number, t1: number, from: Pose, to: Pose?, hold: number?, rocked: boolean? }
local function pose(x: number, y: number, z: number, yaw: number, pitch: number, fov: number): Pose
	return { pos = Vector3.new(x, y, z), yaw = yaw, pitch = pitch, fov = fov }
end
local SHIPWRECK_CUT = 17.4
local EYE = ShipwreckSet.AVATAR_EYE -- los ojos del avatar, en el marco del barco
local SHIPWRECK_SHOTS: { Shot } = {
	-- La luna roja, hasta que llega la tormenta (avance lento).
	{ t0 = SHIPWRECK_CUT, t1 = 19, from = pose(-47, 26.2, -13, 4, 5, 58), to = pose(-45.2, 26.4, -12.6, 4, 5, 56.2) },
	-- Casco desde fuera, a ras del mar por estribor, mirando a proa: el agua sube por el cuadro y las olas se ven grandes.
	{ t0 = 19, t1 = 21.5, from = pose(14, 7.5, 15.5, -12, 3, 62), to = pose(22, 7.5, 15.5, -12, 3, 62), hold = 1 },
	-- El avatar en el puente, visto de perfil por el cristal de babor: detrás se ve el mar por el de estribor (de frente, la pared
	-- blanca del fondo lo dejaba plano y gris).
	{
		t0 = 21.5,
		t1 = 24,
		from = pose(-27, 23.3, -16, 90, 2, 40),
		to = pose(-28.5, 23.3, -16, 90, 2, 40),
		hold = 1,
		rocked = true,
	},
	-- Cubierta baja en estribor, mirando al mar por la borda (con yaw -8 la cabina de la grúa, sin luz, tapaba el 40 % del cuadro).
	{ t0 = 24, t1 = 26.5, from = pose(6, 14.8, 10.4, 22, 4, 60), to = pose(11, 14.8, 10.4, 22, 4, 60), hold = 1 },
	-- Desde popa, viendo cabecear el barco (estático).
	{ t0 = 26.5, t1 = 29, from = pose(-46, 27.2, 5, -4, -4, 60) },
	-- Dentro del puente, detrás del avatar, agarrado.
	{
		t0 = 29,
		t1 = 31,
		from = pose(EYE.X - 2.6, EYE.Y + 0.25, EYE.Z + 1.3, 8, 0, 78),
		to = pose(EYE.X - 2.9, EYE.Y + 0.25, EYE.Z + 1.3, 8, 0, 78),
		hold = 1,
		rocked = true,
	},
}

-- EL AMANECER (G6c), de 31,2 s al final, en coordenadas del MUNDO (el Lobby real, sin marco del barco). Mismos planos que
-- SHIPWRECK_SHOTS (from / to / hold, cortes secos), pero la pose sale de lookPose: posición de la cámara, punto al que mira y
-- fov. El primero arranca a los 31,2 s (a la vez que el evento dawn, con la pantalla en negro; la imagen vuelve a los 31,5).
-- Mundo medido: el carguero encallado (Workspace.Naufragio.Esperanza) tiene el centro en (-44, 18, -36) y mide 78 x 35 x 25, con la
-- proa hacia (-0,29, 0,19, -0,94); la plaza está en (10, -3), el nido en (-10, 8, -24) y el campamento en (-10, 9, -11). A las
-- 5,3 h la luna roja sale al oeste (azimut ~266°, 10° de elevación; azimut = atan2(x, z), 0 = +Z). Desde la plaza el barco
-- queda a ~239° y la luna a ~266°: caben en el mismo plano. Al oeste del Lobby hay decorado cerrado (ruinas, calavera): es lo esperado.
-- Números de arranque, a afinar con capturas.
local function lookPose(x: number, y: number, z: number, tx: number, ty: number, tz: number, fov: number): Pose
	local d = Vector3.new(tx - x, ty - y, tz - z)
	local flat = math.sqrt(d.X * d.X + d.Z * d.Z)
	return pose(x, y, z, math.deg(math.atan2(d.Z, d.X)), math.deg(math.atan2(d.Y, flat)), fov)
end
local SHIPWRECK_DAWN_FROM = 31.2
local SHIPWRECK_DAWN_SHOTS: { Shot } = {
	-- A) Plano abierto desde el mar, al oeste, mirando a la popa del carguero encallado («ESPERANZA PANAMÁ») con la plaza al
	-- fondo. Desde la plaza no sirve: los carteles tapan el barco. Alto (y 13): a ras del mar los basaltos del arrecife (y 6) llenaban
	-- de negro el primer plano. Avanza muy despacio.
	{
		t0 = SHIPWRECK_DAWN_FROM,
		t1 = 35.5,
		from = lookPose(-100, 13, 2, -46, 15, -30, 60),
		to = lookPose(-95, 13.2, -1, -46, 15, -30, 58),
	},
	-- B) Más cerca y bajo, desde la orilla de poniente: la superestructura iluminada, los contenedores «PRIMAL» y la pasarela.
	{
		t0 = 35.5,
		t1 = 40,
		from = lookPose(-84, 6.5, 2, -52, 17, -28, 55),
		to = lookPose(-80, 6.8, 0, -52, 17, -28, 53),
	},
}

-- Pose de un plano en el segundo t: de from a to y quieta el último hold.
local function shotLook(shot: Shot, t: number): (Vector3, Vector3, number)
	local a = shot.from
	local b = shot.to or a
	local span = math.max(shot.t1 - shot.t0 - (shot.hold or 0), 0.01)
	local u = math.clamp((t - shot.t0) / span, 0, 1)
	local pos = a.pos:Lerp(b.pos, u)
	local yaw = math.rad(a.yaw + (b.yaw - a.yaw) * u)
	local pitch = math.rad(a.pitch + (b.pitch - a.pitch) * u)
	local look = pos
		+ Vector3.new(10 * math.cos(pitch) * math.cos(yaw), 10 * math.sin(pitch), 10 * math.cos(pitch) * math.sin(yaw))
	return pos, look, a.fov + (b.fov - a.fov) * u
end

-- La cámara en el mundo. Fija antes el rumbo del barco hacia la luna (ShipwreckSet.setCourse), porque el marco del barco
-- depende de él. El vuelo hasta el puente (SHIPWRECK_CAMERA) y cada plano de SHIPWRECK_SHOTS son tramos separados: en cada
-- corte se repiten el primer y el último punto del tramo con una milésima de diferencia, así la curva de la cámara
-- (Catmull-Rom del Sequencer) no se tuerce hacia el plano de al lado y el corte es seco.
local function shipwreckCamera(): { { t: number, pos: Vector3, look: Vector3, fov: number? } }
	ShipwreckSet.setCourse(SHIPWRECK_HOUR)
	local points: { { t: number, pos: Vector3, look: Vector3, fov: number? } } = {}
	local function addSegment(
		t0: number,
		t1: number,
		sample: (t: number) -> (Vector3, Vector3, number),
		rocked: boolean?,
		world: boolean?
	)
		local function add(t: number)
			local pos, look, fov = sample(t)
			-- world = true: coordenadas del mundo (el amanecer en el Lobby), sin marco del barco.
			local frame = if world
				then CFrame.identity
				elseif rocked then ShipwreckSet.poseAt(t)
				else ShipwreckSet.frameAt(t)
			table.insert(
				points,
				{ t = t, pos = frame:PointToWorldSpace(pos), look = frame:PointToWorldSpace(look), fov = fov }
			)
		end
		add(t0)
		add(t0 + 0.001)
		local t = math.ceil((t0 + 0.01) / SHIPWRECK_STEP) * SHIPWRECK_STEP
		while t < t1 - 0.01 do
			add(t)
			t += SHIPWRECK_STEP
		end
		add(t1 - 0.002)
		add(t1 - 0.001)
	end
	addSegment(0, SHIPWRECK_CUT, function(t: number)
		return CameraPath.sampleTimed(SHIPWRECK_CAMERA, t)
	end)
	for _, shot in SHIPWRECK_SHOTS do
		addSegment(shot.t0, shot.t1, function(t: number)
			return shotLook(shot, t)
		end, shot.rocked)
	end
	for _, shot in SHIPWRECK_DAWN_SHOTS do
		addSegment(shot.t0, shot.t1, function(t: number)
			return shotLook(shot, t)
		end, nil, true)
	end
	return points
end

local Cinematics: { [string]: Scene } = {
	-- Batallas contra un jefe (G5b): solo para grabar; las lanza el panel de pruebas con ArrivalService.play y un stage.
	Battle_Boss_OrangutanDelManglar = bossBattleScene("OrangutanDelManglar", "normal"),
	Battle_Boss_OrangutanDelManglar_Comic = bossBattleScene("OrangutanDelManglar", "comic"),
	Battle_Boss_OrangutanDelManglar_Reel = bossBattleScene("OrangutanDelManglar", "reel"),
	Battle_Boss_ChimpanceCaudillo = bossBattleScene("ChimpanceCaudillo", "normal"),
	Battle_Boss_ChimpanceCaudillo_Comic = bossBattleScene("ChimpanceCaudillo", "comic"),
	Battle_Boss_ChimpanceCaudillo_Reel = bossBattleScene("ChimpanceCaudillo", "reel"),

	-- Batallas montadas (G5a): solo para grabar, las lanza el panel de pruebas con ArrivalService.play.
	Battle_Pack = battleScene("normal"),
	Battle_Pack_Comic = battleScene("comic"),
	-- Montaje reel vertical (9:16) para grabar y recortar; ver el comentario de battleReelCuts.
	Battle_Pack_Reel = battleScene("reel"),

	Boss_OrangutanDelManglar = bossScene(
		"OrangutanDelManglar",
		Strings.later("Señor del manglar"),
		{ lowY = 0.2, side = 1, lit = true, skill = "stomp" }
	),
	-- Variante cómic (G2b): solo se lanza desde el Plató cómic, para grabar.
	Boss_OrangutanDelManglar_Comic = bossComicScene(
		"OrangutanDelManglar",
		Strings.later("Señor del manglar"),
		Strings.later("¡Fuera de mi manglar!"),
		Strings.later("En el corazón del manglar…"),
		{ Color3.fromRGB(26, 112, 108), Color3.fromRGB(246, 232, 196) },
		{ lowY = 0.2, side = 1, lit = true, skill = "stomp" }
	),
	Boss_ChimpanceCaudillo = bossScene(
		"ChimpanceCaudillo",
		Strings.later("Amo de las montañas"),
		{ side = -1, radius = 1.1, skill = "rockRain", lit = true }
	),
	Boss_ChimpanceCaudillo_Comic = bossComicScene(
		"ChimpanceCaudillo",
		Strings.later("Amo de las montañas"),
		Strings.later("¡Esta montaña es mía!"),
		Strings.later("En lo alto de la montaña…"),
		{ Color3.fromRGB(140, 44, 36), Color3.fromRGB(244, 226, 190) },
		{ side = -1, radius = 1.1, skill = "rockRain", lit = true }
	),
	Boss_GorilaAlbino = bossScene(
		"GorilaAlbino",
		Strings.later("Espectro de las cuevas"),
		{ startY = 1.6, lowY = 0.3, skill = "extinguish", lit = 0.35 }
	),
	Boss_GorilaAlbino_Comic = bossComicScene(
		"GorilaAlbino",
		Strings.later("Espectro de las cuevas"),
		Strings.later("Nadie sale de mi cueva…"),
		Strings.later("En la oscuridad de la cueva…"),
		{ Color3.fromRGB(62, 106, 160), Color3.fromRGB(232, 240, 248) },
		{ startY = 1.6, lowY = 0.3, skill = "extinguish", lit = 0.35 }
	),
	Boss_GorilaDeCeniza = bossScene(
		"GorilaDeCeniza",
		Strings.later("Furia del volcán"),
		{ side = -1, radius = 1.35, frontT = 2.4, skill = "eruption", hour = 17.5 }
	),
	Boss_GorilaDeCeniza_Comic = bossComicScene(
		"GorilaDeCeniza",
		Strings.later("Furia del volcán"),
		Strings.later("¡Todo arderá!"),
		Strings.later("Del fondo del volcán…"),
		{ Color3.fromRGB(196, 66, 18), Color3.fromRGB(255, 228, 176) },
		{ side = -1, radius = 1.35, frontT = 2.4, skill = "eruption", hour = 17.5 }
	),

	-- Eclosión del huevo del Lobby (G3a): escena local, solo la ve quien abre el huevo. El anchor es el reposo del
	-- huevo (su centro) y la cámara está hacia +Z, por donde llega el jugador al nido. Los eventos eggShake, eggBurst,
	-- petReveal y eggAnnounce los registra NestController. No lleva fundido de salida: el HUD vuelve solo.
	EggHatch = {
		duration = 7,
		audience = "Self",
		freeze = false,
		skippable = true,
		actors = {},
		camera = {
			{ t = 0, pos = Vector3.new(0, 1.4, 10), look = Vector3.new(0, 0.3, 0), fov = 55 },
			{ t = 2.1, pos = Vector3.new(0, 0.9, 6.6), look = Vector3.new(0, 0.2, 0), fov = 50 },
			-- Golpe de cámara al estallar.
			{ t = 2.25, pos = Vector3.new(0.3, 0.5, 5.4), look = Vector3.new(0, 0.4, 0), fov = 64 },
			-- La mascota sube solo hasta ~1,5 sobre el centro del huevo: la cámara se queda cerca y mira bajo.
			{ t = 2.9, pos = Vector3.new(1.0, 0.4, 8.0), look = Vector3.new(0, 1.5, 0), fov = 56 },
			{ t = 4.8, pos = Vector3.new(-1.2, 0.6, 8.5), look = Vector3.new(0, 1.8, 0), fov = 54 },
			{ t = 6.6, pos = Vector3.new(0.4, 0.9, 9), look = Vector3.new(0, 1.9, 0), fov = 52 },
			{ t = 7, pos = Vector3.new(0.4, 0.9, 9), look = Vector3.new(0, 1.9, 0), fov = 52 },
		},
		events = {
			{ t = 0, kind = "letterbox" },
			{ t = 0, kind = "eggShake", seconds = 2.2 },
			{ t = 2.2, kind = "eggBurst" },
			{ t = 2.2, kind = "petReveal" },
			{ t = 2.6, kind = "eggAnnounce" },
		},
	},

	-- Rescate al amanecer (G3b): lo lanza BeaconService con el anchor en la baliza; la ven todos los de la partida.
	-- Primera parte (0 a 9,2 s): plano abierto desde el Basecamp hacia donde aparece, contrapicado que lo sigue por
	-- encima de la cabeza y el cartel «¡Rescate!»; los puntos de seguimiento (3 a 6,5 s) siguen la trayectoria del
	-- evento move (Sine InOut de 0,5 a 6,5 s). Corte a negro a 9,2 s: a 9,6 s sube la tripulación (RescueCrew: el
	-- piloto y una copia de cada jugador, que se oculta de su sitio) y la segunda parte (9,7 a 19 s) es la cabina por
	-- la puerta, el piloto de tres cuartos y el helicóptero alejándose, con «¡Todos a salvo!».
	Rescue = {
		duration = 19,
		audience = "All",
		freeze = true,
		hour = 6.1,
		actors = {
			heli = {
				kind = "prop",
				build = function(anchor: CFrame)
					local model = HelicopterModel.build()
					model:PivotTo(anchor * CFrame.new(HELI_START) * CFrame.Angles(0, math.rad(HELI_START_YAW), 0))
					HelicopterModel.animate(model)
					return model
				end,
			},
		},
		camera = {
			{ t = 0, pos = Vector3.new(6, 3, 38), look = Vector3.new(-70, 48, 125), fov = 60 },
			{ t = 1.5, pos = Vector3.new(6, 3, 38), look = Vector3.new(-83, 52, 122), fov = 58 },
			{ t = 3, pos = Vector3.new(5, 2.8, 36), look = Vector3.new(-53, 41, 83), fov = 55 },
			{ t = 4, pos = Vector3.new(4, 2.6, 34), look = Vector3.new(-27, 32, 51), fov = 52 },
			{ t = 4.7, pos = Vector3.new(4, 2.5, 33), look = Vector3.new(-10, 27, 29), fov = 50 },
			{ t = 5.5, pos = Vector3.new(3, 2.5, 30), look = Vector3.new(3, 21, 12), fov = 50 },
			{ t = 6.5, pos = Vector3.new(2, 3, 26), look = Vector3.new(10, 18, 4), fov = 50 },
			{ t = 8, pos = Vector3.new(22, 7, 22), look = Vector3.new(8, 16, 3), fov = 50 },
			{ t = 9.5, pos = Vector3.new(31, 10, 4), look = Vector3.new(8, 15, 3), fov = 52 },
			-- Se repite el punto (pantalla ya en negro) para que el salto al plano siguiente no curve la cámara.
			{ t = 9.55, pos = Vector3.new(31, 10, 4), look = Vector3.new(8, 15, 3), fov = 52 },

			-- Segunda parte (los puntos van en el marco del helicóptero: x derecha/puerta, y arriba, z atrás).
			-- Plano 1 (9,6 a 13 s): fuera de la puerta, a unos 7 a 8 studs de ella (x = 2,2 + 7,5), a la altura de
			-- los ojos de los pasajeros (y ~ 0,4), un poco por detrás para ver al piloto (z = -2,1) y a los que
			-- saludan; mira al hueco entre el piloto y la primera fila. Se acerca hasta 3,6 studs de la puerta.
			crewShot(9.6, Vector3.new(9.7, 0.4, 2.0), Vector3.new(0.2, 0.1, -0.8), 50),
			crewShot(9.65, Vector3.new(9.7, 0.4, 2.0), Vector3.new(0.2, 0.1, -0.8), 50),
			crewShot(10, Vector3.new(9.24, 0.41, 1.88), Vector3.new(0.22, 0.106, -0.82), 50),
			crewShot(11, Vector3.new(8.1, 0.44, 1.59), Vector3.new(0.28, 0.12, -0.88), 49),
			crewShot(12, Vector3.new(6.95, 0.47, 1.29), Vector3.new(0.34, 0.135, -0.94), 48),
			crewShot(13, Vector3.new(5.8, 0.5, 1.0), Vector3.new(0.4, 0.15, -1.0), 47),
			-- Plano 2 (13 a 16 s): rodea hacia el morro hasta ver al piloto de tres cuartos a través del cristal.
			crewShot(14, Vector3.new(6.2, 0.7, -2.0), Vector3.new(0.7, 0.1, -2.0), 50),
			crewShot(15, Vector3.new(5.6, 0.9, -4.6), Vector3.new(0.8, 0.1, -2.4), 52),
			crewShot(16, Vector3.new(4.2, 1.0, -6.8), Vector3.new(0.7, 0.15, -2.6), 54),
			-- Plano 3 (16 a 19 s): grúa hacia atrás y arriba; el helicóptero sigue rumbo al horizonte (la cámara
			-- pasa por fuera del disco del rotor, de 6,5 de radio a 3,75 sobre la cabina).
			crewShot(17, Vector3.new(10, 5, 4), Vector3.new(0, 0.3, -1), 56),
			crewShot(18, Vector3.new(7, 7, 11), Vector3.new(0, 0.3, -1), 56),
			crewShot(19, Vector3.new(2, 10, 19), Vector3.new(0, 0.3, -1), 52),
		},
		events = {
			{ t = 0, kind = "letterbox" },
			-- Coloca al helicóptero en su sitio de partida (también al volver atrás con seek).
			{ t = 0, kind = "move", actor = "heli", pos = HELI_START, yaw = HELI_START_YAW },
			{ t = 0.5, kind = "move", actor = "heli", pos = HELI_HOVER, yaw = HELI_HOVER_YAW, seconds = 6 },
			-- Baja hasta HELI_LOW en 2,7 s (acaba a los 9,2 s: antes de la pantalla en negro, para que el
			-- movimiento no pise el salto instantáneo de 9,6).
			{ t = 6.5, kind = "move", actor = "heli", pos = HELI_LOW, yaw = HELI_HOVER_YAW, seconds = 2.7 },
			{
				t = 6.5,
				kind = "title",
				text = Strings.later("¡Rescate!"),
				sub = Strings.later("Lo lograron"),
				seconds = 4,
			},
			-- Negro, salto del helicóptero a su posición de salida, la tripulación sube y vuelve la imagen.
			{ t = 9.2, kind = "fade", seconds = 0.35, toBlack = true },
			{ t = 9.6, kind = "move", actor = "heli", pos = HELI_LOW, yaw = HELI_EXIT_YAW },
			{ t = 9.6, kind = "crewBoard" },
			{ t = 9.7, kind = "fade", seconds = 0.5, toBlack = false },
			{
				t = EXIT_FROM,
				kind = "move",
				actor = "heli",
				pos = HELI_OUT,
				yaw = HELI_EXIT_YAW,
				seconds = EXIT_TO - EXIT_FROM,
			},
			{ t = 11, kind = "caption", text = Strings.later("¡Todos a salvo!"), seconds = 4 },
			{ t = 18.4, kind = "fade", seconds = 0.6, toBlack = true },
		},
	},

	-- Llegada a la isla (G4): escena local, la lanza ArrivalService con el anchor en la playa. La tripulación sale
	-- del mar caminando, mira a su alrededor, señala el humo y celebra. Hasta verla entera no se puede saltar.
	Arrival = (function(): Scene
		local events: { { t: number, kind: string, [string]: any } } = {
			{ t = 0, kind = "letterbox" },
			{ t = 0, kind = "exposure", value = 0.28 },
			{
				t = 0,
				kind = "light",
				follow = true,
				offset = Vector3.new(0, 3, 0),
				color = Color3.fromRGB(255, 236, 210),
				brightness = 1,
				range = 60,
			},
		}
		for index, member in CREW do
			local startT = 0.6 + (index - 1) * 0.15
			table.insert(events, {
				t = startT,
				kind = "move",
				actor = member.name,
				pos = beach(member.x, member.endZ),
				yaw = member.yaw,
				seconds = 3.8,
			})
			table.insert(events, { t = startT, kind = "anim", actor = member.name, action = "Walk", seconds = 3.9 })
		end
		for _, event in
			{
				{ t = 4.7, kind = "anim", actor = "cazador", action = "LookAround", seconds = 3.1 },
				{ t = 6.4, kind = "anim", actor = "guerrero", action = "Point", seconds = 2.1 },
				{ t = 8.4, kind = "anim", actor = "mago", action = "Cheer", seconds = 2.4 },
				{ t = 8.4, kind = "anim", actor = "medico", action = "Cheer", seconds = 2.4 },
				-- Cada texto está en pantalla fundido de entrada (0,5 s) + seconds + fundido de salida (0,6 s): los tres van
				-- uno tras otro sin solaparse (termina el anterior antes de que empiece el siguiente).
				{ t = 4.8, kind = "caption", text = Strings.later("¿Dónde estamos…?"), seconds = 1.5 },
				{
					t = 7.5,
					kind = "caption",
					text = Strings.later("¡Allí! Hay humo entre los árboles."),
					seconds = 1.3,
				},
				{
					t = 10.2,
					kind = "title",
					text = Strings.later("¡Tierra firme!"),
					sub = Strings.later("La isla de los monos los espera"),
					seconds = 1.6,
				},
				{ t = 12.3, kind = "fade", seconds = 0.7, toBlack = true },
			}
		do
			table.insert(events, event)
		end
		return {
			duration = 13,
			audience = "Self",
			freeze = false,
			skippable = false,
			hour = DUSK_HOUR,
			waitTerrain = { beach(-8, 3), beach(0, -6), beach(9, -3.5), ground(0, 0, -18) },
			actors = crewActors(false),
			camera = {
				{ t = 0, pos = ground(-22, 3.2, 8), look = ground(0, 3.2, 2), fov = 55 },
				{ t = 2.5, pos = ground(-22, 3.6, -6), look = ground(0, 3.2, -5), fov = 52 },
				{ t = 4.5, pos = ground(-6, 4, -23), look = ground(0, 3.4, -6), fov = 52 },
				-- Barrido lento (2 s) por delante de la tripulación hasta su costado derecho, fuera de ella.
				{ t = 6.5, pos = ground(15, 4, -21), look = ground(0, 3.4, -6), fov = 52 },
				{ t = 7.8, pos = ground(27, 4, -6), look = ground(0, 3.4, -6), fov = 52 },
				-- Por encima del hombro de la tripulación, mirando tierra adentro.
				{ t = 9.2, pos = ground(8, 4.5, 9), look = ground(0, 3.6, -6), fov = 54 },
				-- Grúa lenta hacia arriba durante los últimos segundos.
				{ t = 10.8, pos = ground(5, 6, 10), look = ground(0, 5, -20), fov = 55 },
				{ t = 13, pos = ground(1, 10, 18), look = ground(0, 7, -40), fov = 58 },
			},
			events = events,
		}
	end)(),

	-- Versión corta para quien ya vio la llegada entera: la tripulación ya en tierra, celebrando.
	ArrivalShort = {
		duration = 3,
		audience = "Self",
		freeze = false,
		skippable = true,
		hour = DUSK_HOUR,
		waitTerrain = { beach(-8, -4), beach(0, -8), beach(9, -3.5) },
		actors = crewActors(true),
		camera = {
			{ t = 0, pos = ground(5, 3.2, 14), look = ground(0, 3.5, -14), fov = 55 },
			{ t = 3, pos = ground(3, 3.8, 11), look = ground(0, 3.5, -14), fov = 52 },
		},
		events = {
			{ t = 0, kind = "letterbox" },
			{ t = 0, kind = "exposure", value = 0.28 },
			{
				t = 0,
				kind = "light",
				follow = true,
				offset = Vector3.new(0, 3, 0),
				color = Color3.fromRGB(255, 236, 210),
				brightness = 1,
				range = 60,
			},
			{ t = 0.1, kind = "anim", actor = "mago", action = "Cheer", seconds = 2.4 },
			{ t = 0.1, kind = "anim", actor = "medico", action = "Cheer", seconds = 2.4 },
			{ t = 0.2, kind = "anim", actor = "guerrero", action = "Point", seconds = 2.1 },
			{ t = 0.3, kind = "caption", text = Strings.later("¡Tierra firme!"), seconds = 1.8 },
			{ t = 2.4, kind = "fade", seconds = 0.6, toBlack = true },
		},
	},

	-- Travesía (G4b): la tripulación y el avatar del jugador cruzan el mar en la lancha del Lobby, justo antes de
	-- «Arrival» la primera vez (la lanza ArrivalService con el anchor en la playa). Cámara: plano alto desde atrás sobre
	-- el mar, travelling por el costado izquierdo de proa a popa y plano bajo de popa con la isla al fondo. Hasta verla
	-- entera no se puede saltar.
	Voyage = (function(): Scene
		local events: { { t: number, kind: string, [string]: any } } = {
			{ t = 0, kind = "letterbox" },
			-- Amanecer: imagen más clara con un tinte cálido suave y dos luces que siguen a la cámara (sol bajo
			-- anaranjado desde un lado y relleno cálido encima) para que la lancha lea naranja y el mar tenga color.
			-- Dos tramos: planos lejanos (0 a 3,4 s, cámara a 17-30 studs) con más luz, y planos cercanos (desde 3 s,
			-- cámara a 9-13 studs de la lancha), donde la misma luz la quemaba. Las lejanas se apagan con fundido.
			-- Con la hora fija de amanecer (VOYAGE_HOUR) el mundo ya trae más luz y brillo que de noche: exposición,
			-- luces y brillo van rebajados un 25-35 % respecto a los valores calibrados de noche.
			{ t = 0, kind = "exposure", value = 0.8, tint = Color3.fromRGB(255, 236, 214) },
			{
				t = 0,
				kind = "light",
				follow = true,
				offset = Vector3.new(-8, 10, -6),
				color = Color3.fromRGB(255, 176, 96),
				brightness = 2,
				range = 90,
				seconds = 3.4,
			},
			{
				t = 0,
				kind = "light",
				follow = true,
				offset = Vector3.new(6, 4, 4),
				color = Color3.fromRGB(255, 214, 170),
				brightness = 0.7,
				range = 60,
				seconds = 3.4,
			},
			-- Cerca no hay luz puntual (a 9-13 studs satura los materiales de la lancha): solo exposición y tinte, y
			-- un sol y un relleno casi nulos.
			{ t = 3, kind = "bloom", intensity = 0.35, threshold = 3 },
			{ t = 3, kind = "brightness", scale = 0.6 },
			{ t = 3, kind = "exposure", value = 0.2, tint = Color3.fromRGB(240, 247, 255) },
			{
				t = 3,
				kind = "light",
				follow = true,
				offset = Vector3.new(-8, 10, -6),
				color = Color3.fromRGB(255, 170, 90),
				brightness = 0.2,
				range = 90,
			},
			{
				t = 3,
				kind = "light",
				follow = true,
				offset = Vector3.new(6, 4, 4),
				color = Color3.fromRGB(255, 214, 170),
				brightness = 0.1,
				range = 60,
			},
			{ t = 0, kind = "voyageBoard" },
			-- Los rigs pasan de AnimationConstraint a Motor6D al sentarse: se vuelve a pedir la pose del arma.
			{ t = 0.3, kind = "anim", actor = "guerrero", action = "WeaponPose" },
			{ t = 0.3, kind = "anim", actor = "cazador", action = "WeaponPose" },
			{ t = 0.3, kind = "anim", actor = "mago", action = "WeaponPose" },
			{ t = 0.3, kind = "anim", actor = "medico", action = "WeaponPose" },
			-- Cada texto está en pantalla fundido de entrada (0,5 s) + seconds + fundido de salida (0,6 s): el cartel
			-- (0,8 a 4,9 s) y el subtítulo (6,0 a 9,7 s) no se solapan.
			{
				t = 0.8,
				kind = "title",
				text = Strings.later("Rumbo a la Isla de monos"),
				sub = Strings.later("Al amanecer, con el mar en calma"),
				seconds = 3,
				oneLine = true,
			},
			{ t = 6, kind = "caption", text = Strings.later("Ya se ve la isla a lo lejos…"), seconds = 2.6 },
			{ t = 11.3, kind = "fade", seconds = 0.7, toBlack = true },
		}
		-- Avance a velocidad constante y oleaje (waveAt) en tramos lineales de WAVE_STEP s; cada tramo acaba un instante
		-- antes de que empiece el siguiente para que no se pisen.
		local segments = math.floor(VOYAGE_SECONDS / WAVE_STEP)
		for index = 1, segments do
			local bob, pitch, roll = waveAt(index * WAVE_STEP)
			table.insert(events, {
				t = (index - 1) * WAVE_STEP,
				kind = "move",
				actor = "boat",
				pos = boatAt(index * WAVE_STEP) + Vector3.new(0, bob, 0),
				yaw = 0,
				pitch = pitch,
				roll = roll,
				seconds = WAVE_STEP - 0.02,
				easing = Enum.EasingStyle.Linear,
			})
		end
		return {
			duration = VOYAGE_SECONDS,
			audience = "Self",
			freeze = false,
			skippable = false,
			hour = VOYAGE_HOUR,
			actors = voyageActors(),
			camera = {
				-- Plano inicial más cerca (la lancha ocupa ~1/3 del ancho) con el horizonte y la isla al fondo.
				boatShot(0, Vector3.new(-9, 7.5, 19), Vector3.new(0, 1.5, -18), 55),
				boatShot(2.5, Vector3.new(-9, 5, 15), Vector3.new(0, 1.5, -8), 52),
				-- Travelling por el costado: a 12 studs de la lancha, de popa a proa y de vuelta a popa.
				boatShot(4.5, Vector3.new(-12, 3.4, 12), Vector3.new(0, 2, 2), 48),
				boatShot(6.5, Vector3.new(-12, 3.2, 1), Vector3.new(0, 2, 0), 48),
				boatShot(8, Vector3.new(-12, 3, -6), Vector3.new(0, 2, -1), 48),
				boatShot(9.5, Vector3.new(-7, 2.6, 13), Vector3.new(0, 3, -12), 52),
				-- Plano bajo de popa, a la izquierda del motor, con la isla al fondo.
				boatShot(12, Vector3.new(-2.4, 2.1, 9), Vector3.new(0, 3.5, -45), 55),
			},
			events = events,
		}
	end)(),

	-- Naufragio (G6a): la bienvenida del Lobby, solo la primera vez que alguien entra al juego (la lanza el cliente,
	-- ShipwreckController, y no se puede saltar nunca). De noche: el barco navega con gaviotas y la cámara vuela hasta el
	-- puente de mando, donde está el avatar del jugador; a los 19 s llega la tormenta (G6b: planos cerrados con niebla, lluvia, viento,
	-- olas y rayos, de noche) y acaba en negro a los 31 s; de 31,2 a 40 s, el amanecer sobre el barco encallado del Lobby con
	-- el título del juego (G6c).
	Shipwreck = {
		duration = SHIPWRECK_SECONDS,
		audience = "Self",
		freeze = false,
		skippable = false,
		noSkip = true,
		hour = SHIPWRECK_HOUR,
		actors = {
			ship = {
				kind = "prop",
				build = function()
					local ship = ShipwreckSet.buildShip()
					ship:PivotTo(ShipwreckSet.poseAt(0))
					return ship
				end,
			},
		},
		-- La cámara depende de la luna (rumbo del barco): CinematicClient la pide a prepare justo antes de empezar.
		camera = {},
		prepare = shipwreckCamera,
		events = {
			{ t = 0, kind = "letterbox" },
			-- La luz del mundo baja cada cuadro: luna clara al principio, noche cerrada a los 19 s y, despacio, hasta el fondo
			-- a los 31 s (la tormenta conserva visibilidad para leer los planos entre rayos: STORM.look en ShipwreckSet).
			{ t = 0, kind = "night", midAt = 19, deepAt = 31, hour = SHIPWRECK_HOUR },
			-- Sin luz pegada a la cámara y con muy poca exposición: quemaban el casco blanco. La luna es el ambiente y una luz
			-- muy suave en el palo del barco (ShipwreckSet).
			{ t = 0, kind = "exposure", value = 0.3, tint = Color3.fromRGB(225, 235, 255) },
			{ t = 0, kind = "shipSail" },
			{ t = 0, kind = "shipAvatar" },
			{ t = 0, kind = "birds", seconds = 15 },
			-- Tormenta (19 a 31 s): niebla, mar y viento en 3 s; lluvia desde 19,5; rayos con trueno y un destello grande al
			-- final (sin tronco). Planos y números: SHIPWRECK_SHOTS y STORM (ShipwreckSet).
			{ t = 19, kind = "storm", seconds = 3 },
			{ t = 19.5, kind = "rain", seconds = 2 },
			{ t = 19, kind = "lightning", side = 0.3, thunderDelay = 0.5 },
			{ t = 22, kind = "lightning", side = -0.6, thunderDelay = 0.6 },
			{ t = 25.5, kind = "lightning", side = 0.7, thunderDelay = 0.7 },
			{ t = 28.5, kind = "lightning", side = -0.2, thunderDelay = 0.5 },
			{ t = 30.3, kind = "lightning", strength = 1.6, bolt = false, thunderDelay = 0.2 },
			-- A negro a los 29,5 s (en negro a los 31).
			{ t = 29.5, kind = "fade", seconds = 1.5, toBlack = true },
			-- El amanecer (G6c): con la pantalla en negro el Lobby cambia de golpe a la luz de antes del alba (DAWN en
			-- ShipwreckSet; night y storm dejan de aplicarse y el barco que navegaba desaparece). La imagen vuelve a los 31,5 s
			-- en el barco encallado real (SHIPWRECK_DAWN_SHOTS), con el tinte de la escena sin el azul de la noche.
			{ t = SHIPWRECK_DAWN_FROM, kind = "dawn", hour = 5.3 },
			{ t = SHIPWRECK_DAWN_FROM, kind = "exposure", value = 0.3 },
			{ t = 31.5, kind = "fade", seconds = 0.6, toBlack = false },
			{ t = 32, kind = "caption", text = Strings.later("Al amanecer solo quedaba la arena."), seconds = 2.4 },
			{
				t = 36.5,
				kind = "title",
				text = Strings.later("Primal Banana Islands"),
				sub = Strings.later("Monkey Survival"),
				seconds = 2.6,
			},
			-- A negro al final: el hook finish devuelve la imagen con fundido y el jugador queda en el Lobby.
			{ t = 39, kind = "fade", seconds = 1, toBlack = true },
			-- Diario de a bordo: cada texto dura 0,5 s de entrada + seconds + 0,6 s de salida y acaba antes de que empiece el siguiente.
			{
				t = 1.5,
				kind = "caption",
				text = Strings.later("Diario de a bordo. Noche 11. Mar en calma."),
				seconds = 2.2,
			},
			{
				t = 6,
				kind = "caption",
				text = Strings.later("La luna sale roja. Los marineros dicen que es mala señal."),
				seconds = 2.2,
			},
			{ t = 11.5, kind = "caption", text = Strings.later("Llevamos semanas sin ver tierra…"), seconds = 2.2 },
			{ t = 17.5, kind = "caption", text = Strings.later("El barómetro cae en picado."), seconds = 0.8 },
			{ t = 19.5, kind = "caption", text = Strings.later("¡Tormenta! ¡Todos a cubierta!"), seconds = 1.0 },
			{ t = 22, kind = "caption", text = Strings.later("Aguanta, Esperanza…"), seconds = 1.3 },
			{ t = 27, kind = "caption", text = Strings.later("Esto no va a resistir."), seconds = 1.3 },
		},
	},

	-- Escena de prueba del motor: un maniquí guerrero camina hacia la cámara delante del jugador.
	Prueba = {
		duration = 6,
		audience = "Self",
		freeze = false,
		hour = 14,
		actors = {
			hero = { kind = "dummy", role = "Guerrero", armor = "VolcanicArmor", pos = Vector3.new(0, 0, 0), yaw = 0 },
			player = { kind = "localPlayer" },
		},
		camera = {
			{ t = 0, pos = Vector3.new(-9, 4, 14), look = Vector3.new(0, 3, 0), fov = 60 },
			{ t = 2, pos = Vector3.new(-3, 3, 11), look = Vector3.new(0, 3, 2), fov = 55 },
			{ t = 4, pos = Vector3.new(5, 3.5, 9), look = Vector3.new(0, 3, 4) },
			{ t = 6, pos = Vector3.new(9, 6, 15), look = Vector3.new(0, 3, 5), fov = 65 },
		},
		events = {
			{ t = 0, kind = "letterbox" },
			{ t = 0.5, kind = "move", actor = "hero", pos = Vector3.new(0, 0, 8), yaw = 0, seconds = 4 },
			{
				t = 0.8,
				kind = "title",
				text = Strings.later("Escena de prueba"),
				sub = Strings.later("El motor de cinemáticas funciona"),
				seconds = 2,
			},
			{ t = 3.4, kind = "caption", text = Strings.later("Un guerrero avanza por la playa"), seconds = 1.8 },
			{ t = 5, kind = "fade", seconds = 1, toBlack = true },
		},
	},
}

return Cinematics
