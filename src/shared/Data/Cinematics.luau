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
--   Flyover y Flyover_Comic .............. 17,5  (atardecer con el sol bajo; a 18,8 el sobrevuelo queda a oscuras)
--   Prueba ............................... 14,0  (tarde clara; no lleva luces propias)
--   Boss_OrangutanDelManglar, Boss_ChimpanceCaudillo, Boss_GorilaAlbino y sus _Comic ... 18,8 (luz de relleno de SceneLight)
--   Boss_GorilaDeCeniza y su _Comic ...... 17,5  (atardecer: sin luz de relleno, la lava y el sol bajo lo iluminan)
--   Battle_Pack, Battle_Pack_Comic, Battle_Pack_Reel ... 18,8
--   Battle_Boss_<jefe>, _Comic y _Reel (Orangután y Caudillo) ... 18,8
--   Pets, Pets_Reel y Pets_Comic ......... 17,5  (atardecer dorado; sin luces propias: las mascotas se ven con el sol bajo)
--   Mounts, Mounts_Reel y Mounts_Comic ... 17,5  (atardecer dorado, como Pets)
--   Ballgame ............................. 17,5  (Dunas no tiene ciclo de día: DunasCineController pone Lighting.ClockTime)
--   Flag y Flag_Comic .................... 16,5  (idem)

local BallHit = require(script.Parent.Parent.BallHit)
local BallSim = require(script.Parent.Parent.BallSim)
local BallgameData = require(script.Parent.Ballgame)
local BossChoreo = require(script.Parent.BossChoreo)
local Bosses = require(script.Parent.Bosses)
local CameraPath = require(script.Parent.Parent.Cinematics.CameraPath)
local ComicPages = require(script.Parent.ComicPages)
local Config = require(script.Parent.Parent.Config)
local CourtGeometry = require(script.Parent.Parent.CourtGeometry)
local ShipwreckSet = require(script.Parent.Parent.Cinematics.ShipwreckSet)
local HelicopterModel = require(script.Parent.Parent.HelicopterModel)
local LifeboatModel = require(script.Parent.Parent.LifeboatModel)
local MountedRider = require(script.Parent.Parent.Cinematics.MountedRider)
local Mounts = require(script.Parent.Mounts)
local PetActor = require(script.Parent.Parent.Cinematics.PetActor)
local Strings = require(script.Parent.Parent.Strings)

export type Scene = {
	duration: number,
	audience: string,
	freeze: boolean,
	streamFollowsCamera: boolean?, -- el servidor carga el terreno donde estará la cámara (escenas que cruzan la isla)
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

-- Punto de cámara de un plano de cómic de página (G7c). El 3D se ve a pantalla completa y solo asoma el rectángulo de
-- la viñeta viva, así que el sujeto tiene que caer en su centro (cx, cy, en 0–1 de la pantalla) y `width` studs tienen
-- que llenar el ANCHO de la viñeta (cellW, fracción del ancho de la pantalla): con la pantalla 16:9,
-- tan(fov/2) = (width / 2 / distancia) / (cellW · 16/9). El alto de la viñeta no entra en la cuenta (se cancela con
-- su aspecto), pero se pide para que quien llama pase el rectángulo entero de ComicPages.cellCenter.
-- La cámara se gira en horizontal y en vertical hasta que el sujeto caiga en (cx, cy): se corrige la dirección hacia
-- el sujeto con el error que queda en cada eje (converge en 2 o 3 vueltas con los FOV de aquí).
local SCREEN_ASPECT = 16 / 9
local function pageKey(
	pos: Vector3,
	subject: Vector3,
	width: number,
	cx: number,
	cy: number,
	cellW: number,
	_cellH: number
): CameraKey
	local offset = subject - pos
	local distance = math.max(offset.Magnitude, 1)
	local fov = math.clamp(math.deg(2 * math.atan(width / 2 / distance / (cellW * SCREEN_ASPECT))), 8, 100)
	local tanHalf = math.tan(math.rad(fov / 2))
	local wantX = (cx * 2 - 1) * tanHalf * SCREEN_ASPECT -- dónde debe caer el sujeto en el plano de la cámara
	local wantY = (1 - cy * 2) * tanHalf
	local forward = offset.Unit
	for _ = 1, 6 do
		local side = forward:Cross(Vector3.yAxis)
		if side.Magnitude < 1e-3 then
			return cameraKey(pos, subject, fov)
		end
		local right = side.Unit
		local up = right:Cross(forward)
		local depth = offset:Dot(forward)
		local errorX = offset:Dot(right) / depth - wantX
		local errorY = offset:Dot(up) / depth - wantY
		forward = (forward + right * errorX + up * errorY).Unit
	end
	return cameraKey(pos, pos + forward * distance, fov)
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

local BATTLE_CAPTIONS = {
	{ t = 0.3, seconds = 2.2, text = Strings.later("Una manada baja de la selva…") },
	{ t = 2.7, seconds = 1.9, text = Strings.later("El mandril ruge y el guerrero responde.") },
	{ t = 4.8, seconds = 1.9, text = Strings.later("Flechas y bolas de fuego abren el combate.") },
	{ t = 7.0, seconds = 2.0, text = Strings.later("El torbellino y el hielo rompen sus filas.") },
	{ t = 9.2, seconds = 2.0, text = Strings.later("El médico cura al equipo mientras llueven flechas.") },
	{ t = 11.4, seconds = 1.6, text = Strings.later("¡La manada huye!") },
}

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
		-- Subtítulos narrativos que acompañan la acción (misma línea de tiempo que `battleAction`).
		for _, line in BATTLE_CAPTIONS do
			table.insert(events, { t = line.t, kind = "caption", text = line.text, seconds = line.seconds })
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
	-- Ladera del cráter que baja hacia delante del jefe.
	GorilaDeCeniza = {
		{ -33.2, -31.7, -30.6, -30, -28.9, -28.6, -28.8, -28.6, -29.5, -30, -30.9, -31.9, -33.8 },
		{ -30.4, -28.9, -27.7, -26.3, -26, -25.3, -25.4, -25.1, -25.6, -26.8, -27.5, -28.9, -31 },
		{ -26.9, -24.9, -23.7, -22.8, -22, -22, -21.8, -21.5, -22, -23.4, -24.2, -25.6, -27.6 },
		{ -23.6, -21.8, -20.8, -19.8, -17.7, -17.2, -17.9, -17.8, -18, -19.3, -20.3, -22.1, -23.6 },
		{ -20.2, -18.4, -16.6, -16.7, -15.5, -14.8, -14.6, -14.6, -15.4, -16.1, -17.4, -18.5, -21.2 },
		{ -18.1, -16.4, -13.6, -12.4, -11.2, -10.7, -11.5, -10.2, -11.5, -12.7, -14, -15.7, -17.6 },
		{ -14.1, -13.2, -11, -8.4, -8.4, -7.6, -7.4, -6.6, -8, -9.3, -10.7, -12.7, -14.8 },
		{ -12.4, -8.9, -7.7, -4.7, -4.6, -3.7, -2.9, -3.6, -4.2, -5.7, -7.7, -10.5, -12.2 },
		{ -9.1, -7.1, -3.6, -2.8, -1.5, 0.4, 0, -0.6, -0.6, -2.3, -4.3, -7.9, -10.2 },
		{ -7.1, -4, -0.9, 1.1, 0.6, 0.8, -0.8, 0.6, 0.5, 0.4, -0.8, -3.8, -7.6 },
		{ -4.7, -2.2, 1.4, -2.5, -6.6, -12.1, -13.5, -11.2, -5, 0.3, 0.5, -2.5, -5.8 },
	},
	-- Sala llana. Donde la medición no dio suelo (pared o boca del túnel, nadie pisa ahí) se rellenó con 0,5.
	GorilaAlbino = {
		{ 0.5, 0.5, 0.5, 0.5, 0.5, 0.8, -0.2, 1.1, 0.5, 0.5, 0.5, 0.5, 0.5 },
		{ 0.5, 0.5, 0.5, 0.5, 0.5, 0.7, -0.2, 1.1, 0.5, 0.5, 0.5, 0.5, 0.5 },
		{ 0.5, 0.5, 0.5, 6.2, 1.8, 0.8, 0.3, 0.2, 0.7, 4.5, 0.5, 0.5, 0.5 },
		{ 0.5, 7.1, 0.5, -0.2, -0.2, 0.7, 0.2, 0.7, 0.8, 0.6, 1.8, 10, 0.5 },
		{ 0.5, 0.9, 0.6, 0.9, 0.7, 0.7, 0.2, 0.5, -0.1, 0.6, 0.8, 2.8, 0.5 },
		{ 4, 0.9, 0.8, 0.9, 0.9, 0.9, 0.5, 0.9, 0.3, 0.9, 0.4, 0.9, 3.3 },
		{ 0.7, -0.1, 0.9, 0.9, 0.3, 0.4, 0.6, 0.8, 0.8, 0.5, 0.1, 0.2, 1.2 },
		{ 0.3, -0.1, 0.9, 0.9, 0.5, 0.4, 0.6, 0.8, 0.1, 0.8, 0.8, 0, 0.6 },
		{ 0.6, 0.4, 0.6, 0.7, 0.4, 0.6, 0, 0.6, 0.9, 0.9, 0.7, 0.2, 0.7 },
		{ 0.6, 0.7, 0.9, 0.8, 0.8, 0.8, 0.5, 0.7, 0.7, 0.3, 0.9, 0.9, 0.3 },
		{ 1.1, 0.4, 0.6, 0.3, 0.7, 0.7, 0.9, 0.2, 0.7, 0.6, 0.3, 0.6, 2.2 },
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
	choreo: string?, -- "orangutan" | "caudillo": la coreografía propia de la versión normal (BossChoreo); sin ella, la común
	reel: { ReelPlan }?, -- cortes del reel; sin ellos el jefe solo tiene la versión normal
	hour: number?, -- hora del día de la escena (por defecto, DUSK_HOUR)
	exposure: number?, -- exposición de la cámara (por defecto, 0,42)
	brightness: number?, -- brillo de la luz de la escena (por defecto, 1,8)
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
		choreo = "orangutan",
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
		choreo = "caudillo",
		reel = bossReelPlan(),
	},
	GorilaDeCeniza = {
		centre = { 0, -18 },
		colors = { Color3.fromRGB(196, 66, 18), Color3.fromRGB(255, 228, 176) },
		narration = Strings.later("Del fondo del volcán…"),
		quote = Strings.later("¡Todo arderá!"),
		skill = "eruption",
		hour = 17.5,
		exposure = 0.42,
		brightness = 1.8,
		wait = { Vector3.new(0, 0, 0), Vector3.new(0, -11.5, -18) },
		plan = bossPlan(),
	},
	GorilaAlbino = {
		centre = { 0, -18 },
		colors = { Color3.fromRGB(62, 106, 160), Color3.fromRGB(232, 240, 248) },
		narration = Strings.later("En la oscuridad de la cueva…"),
		quote = Strings.later("Nadie sale de mi cueva…"),
		skill = "extinguish",
		exposure = 0.3,
		brightness = 1.2,
		wait = { Vector3.new(0, 0, 0), Vector3.new(0, 0.5, -18) },
		plan = bossPlan(),
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

local function bossShots(bossId: string, battle: BossBattle, planShots: { PlanShot }): { CameraShot }
	local shots: { CameraShot } = {}
	for _, plan in planShots do
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
	assert(battle.reel, `El jefe {bossId} no tiene reel`)
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
			event.value = battle.exposure or 0.42
		elseif event.kind == "light" then
			event.brightness = battle.brightness or 1.8
		end
	end
	-- La versión normal con coreografía propia (G14a) saca de BossChoreo los eventos y los planos; las demás, la común.
	local choreo: BossChoreo.Choreo? = nil
	if variant == "normal" and battle.choreo then
		choreo = BossChoreo.build(battle.choreo, {
			bossId = bossId,
			bossName = Bosses[bossId].name,
			crewSpot = function(name: string): (number, number)
				return crewSpot(battle, name)
			end,
			total = BATTLE_SECONDS,
		})
	end
	local actionEvents = if choreo then choreo.events else bossBattleAction(battle)
	for _, event in actionEvents do
		table.insert(events, event)
	end
	local camera: { { t: number, pos: Vector3, look: Vector3, fov: number? } }
	if reel then
		local cuts = bossReelCuts(bossId, battle)
		camera = cutShots(battleReelShots(cuts))
		addBossReelComic(events, cuts, battle)
	else
		camera = cutShots(bossShots(bossId, battle, if choreo then choreo.plan else battle.plan))
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
		hour = battle.hour or DUSK_HOUR,
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

-- Sobrevuelo (Fase 25, S2; 42 s): tráiler de la Isla, solo para grabar (orden «🎬 Sobrevuelo»). Va en coordenadas del MUNDO
-- (anchor = CFrame.identity, lo pone DebugService) y recorre toda la isla, así que CinematicService carga el terreno
-- siguiendo a la cámara (campo streamFollowsCamera). Ocho clips panorámicos de ~1,3 s con corte seco (costa, montaña,
-- volcán, cráter y acercamiento al Basecamp), el avatar del jugador planeando en el Quetzalcóatl desde el borde del
-- cráter hasta el Basecamp (siete planos de ~1,5 s alrededor de ella), tres manadas con su alfa en posición de ataque
-- (volcán: gorilas; falda de la montaña: babuino y gibones; sur del Basecamp: chimpancés) y el cartel con el reto.
-- Medidas en el Studio de la Isla (radio 950): borde del cráter y 160, fondo 130, cima de la montaña 135 a 148, Basecamp 12.
local FLYOVER_SECONDS = 42
local FLYOVER_HOUR = 17.5 -- atardecer con el sol bajo (como Gorila de Ceniza); a 18,8 la isla se ve a oscuras desde el aire
local GLIDE_FROM = Vector3.new(350, 180, -350) -- sobre el borde del cráter
local GLIDE_TO = Vector3.new(45, 55, -40) -- ya sobre el Basecamp
local GLIDE_START = 11
local GLIDE_END = 22
local GLIDE_FLAT = Vector3.new(GLIDE_TO.X - GLIDE_FROM.X, 0, GLIDE_TO.Z - GLIDE_FROM.Z)
local GLIDE_DIR = GLIDE_FLAT.Unit
local GLIDE_RIGHT = GLIDE_DIR:Cross(Vector3.yAxis)
local GLIDE_YAW = math.deg(math.atan2(-GLIDE_DIR.X, -GLIDE_DIR.Z)) -- la montura mira a -Z con yaw 0
local GLIDE_PITCH = -math.deg(math.atan((GLIDE_FROM.Y - GLIDE_TO.Y) / GLIDE_FLAT.Magnitude)) -- nariz abajo
local FLYOVER_CUT_GAP = 0.05 -- segundos entre el final de un plano y el principio del siguiente (corte seco)

type CameraPoint = { t: number, pos: Vector3, look: Vector3, fov: number? }

-- Posición de la montura en el instante t de la escena (el movimiento es lineal).
local function glideAt(t: number): Vector3
	return GLIDE_FROM:Lerp(GLIDE_TO, math.clamp((t - GLIDE_START) / (GLIDE_END - GLIDE_START), 0, 1))
end

-- Un plano: dos extremos con el punto repetido 1 ms después, para que la spline no curve el plano con los vecinos del corte.
local pushShot = CameraPath.pushShot -- la cuenta vive en CameraPath, que también encadena tomas (montage)

local function shot(pos: Vector3, look: Vector3, fov: number): CameraPoint
	return { t = 0, pos = pos, look = look, fov = fov }
end

-- Plano que acompaña a la montura: la cámara a offsetA..offsetB (derecha, arriba, delante, en el marco de su rumbo) y
-- mirando un poco por encima de ella. Se muestrea cada 0,5 s.
local function pushFollow(
	camera: { CameraPoint },
	t0: number,
	t1: number,
	offsetA: Vector3,
	offsetB: Vector3,
	lookUp: number,
	fov: number
)
	local steps = math.max(2, math.ceil((t1 - t0) / 0.5))
	for i = 0, steps do
		local f = i / steps
		local t = t0 + (t1 - t0) * f
		local o = offsetA:Lerp(offsetB, f)
		local mount = glideAt(t)
		local point: CameraPoint = {
			t = t,
			pos = mount + GLIDE_RIGHT * o.X + Vector3.yAxis * o.Y + GLIDE_DIR * o.Z,
			look = mount + Vector3.new(0, lookUp, 0),
			fov = fov,
		}
		if i == 0 then
			table.insert(camera, { t = t0 - 0.001, pos = point.pos, look = point.look, fov = fov })
		end
		table.insert(camera, point)
		if i == steps then
			table.insert(camera, { t = t1 + 0.001, pos = point.pos, look = point.look, fov = fov })
		end
	end
end

local function flyoverCamera(): { CameraPoint }
	local camera: { CameraPoint } = {}
	local gap = FLYOVER_CUT_GAP
	-- Un plano cada ~1,3 s: la panorámica del principio es una ráfaga de cortes (v = vista de lejos o de cerca).
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z)
	end
	local mountain, volcano, crater, camp = v(-428, 150, -380), v(399, 150, -399), v(399, 135, -399), v(0, 18, 0)
	-- Panorámica: costa, montaña (lejos y cerca), volcán (flanco y desde el este), cráter (dos planos), Basecamp.
	pushShot(camera, 0, 1.3, shot(v(120, 75, 1010), v(0, 110, -250), 70), shot(v(90, 95, 940), v(0, 125, -250), 70))
	pushShot(camera, 1.35, 2.65, shot(v(-260, 105, -60), mountain, 65), shot(v(-300, 115, -120), mountain, 65))
	pushShot(camera, 2.7, 4.0, shot(v(-330, 125, -190), mountain, 60), shot(v(-370, 130, -250), mountain, 58))
	pushShot(camera, 4.05, 5.35, shot(v(150, 120, -150), volcano, 65), shot(v(230, 130, -250), volcano, 65))
	pushShot(camera, 5.4, 6.7, shot(v(600, 120, -300), volcano, 62), shot(v(560, 140, -330), volcano, 60))
	pushShot(camera, 6.75, 8.05, shot(v(320, 175, -300), volcano, 62), shot(v(370, 215, -345), crater, 58))
	pushShot(camera, 8.1, 9.4, shot(v(399, 215, -345), crater, 60), shot(v(399, 200, -368), crater, 55))
	pushShot(camera, 9.45, GLIDE_START - gap, shot(v(230, 100, -190), camp, 60), shot(v(60, 30, -50), camp, 48))
	-- Planeo (la montura mide unos 16 studs de largo): siete planos de ~1,5 s alrededor de ella.
	-- Offsets (derecha, arriba, delante) en el marco de su rumbo.
	local function follow(t0: number, t1: number, a: Vector3, b: Vector3, lookUp: number, fov: number)
		pushFollow(camera, t0, t1, a, b, lookUp, fov)
	end
	follow(GLIDE_START, 12.8, v(0, 7, -30), v(-6, 9, -22), 1, 62)
	follow(12.8 + gap, 14.4, v(11, 5, 2), v(9, 5, -3), 4, 45)
	follow(14.4 + gap, 16, v(6, -2, 24), v(-3, 2, 18), 3, 52)
	follow(16 + gap, 17.6, v(-14, 6, -2), v(-12, 6, 4), 4, 48)
	follow(17.6 + gap, 19.2, v(0, 18, -14), v(2, 14, -8), 0, 58)
	follow(19.2 + gap, 20.6, v(10, 6, 40), v(0, 10, 30), 2, 55)
	follow(20.6 + gap, GLIDE_END, v(30, 3, -4), v(24, 5, 6), 1, 58)
	-- Manadas: tres planos de ~1,35 s cada una (de frente y abierto, bajo y cerca del alfa, y de costado).
	local function pack(t0: number, plans: { { CameraPoint } })
		for index, plan in plans do
			local from = t0 + (index - 1) * 1.4
			pushShot(camera, from, from + 1.35, plan[1], plan[2])
		end
	end
	pack(22.05, {
		{ shot(v(372, 22, -76), v(402, 22, -94), 55), shot(v(370, 21, -88), v(402, 22, -94), 55) },
		{ shot(v(384, 22, -90), v(399, 22, -92), 45), shot(v(381, 23, -95), v(399, 22, -92), 45) },
		{ shot(v(400, 26, -60), v(405, 20, -90), 55), shot(v(412, 24, -64), v(405, 20, -90), 55) },
	})
	pack(26.3, {
		{ shot(v(-414, 27, -84), v(-421, 27, -103), 55), shot(v(-420, 26, -86), v(-421, 27, -103), 55) },
		{ shot(v(-422, 27, -88), v(-420, 26, -100), 45), shot(v(-420, 27, -90), v(-420, 26, -100), 45) },
		{ shot(v(-404, 26, -100), v(-422, 25, -106), 55), shot(v(-405, 26, -108), v(-422, 25, -106), 55) },
	})
	pack(30.55, {
		{ shot(v(-8, 24, 250), v(-25, 19, 276), 55), shot(v(-14, 23, 252), v(-25, 19, 276), 55) },
		{ shot(v(-25, 20, 258), v(-25, 19, 272), 45), shot(v(-22, 20, 260), v(-25, 19, 272), 45) },
		{ shot(v(-4, 22, 268), v(-27, 18, 276), 55), shot(v(-5, 22, 275), v(-27, 18, 276), 55) },
	})
	-- Cartel: la cámara sube despacio sobre el Basecamp con el reto encima.
	pushShot(
		camera,
		34.8,
		FLYOVER_SECONDS,
		shot(v(70, 40, 60), v(0, 30, -20), 60),
		shot(v(40, 80, 90), v(0, 45, -20), 65)
	)
	return camera
end

-- Una manada: el alfa en el centro y sus compañeros detrás, todos mirando en la misma dirección (yaw del marco del mundo).
local function flyoverPack(
	events: { { [string]: any } },
	prefix: string,
	species: string,
	spawnAt: number,
	yaw: number,
	alphaAt: Vector3,
	others: { Vector3 },
	roarAt: number,
	attackAt: number
)
	local function add(event: { [string]: any })
		event.kind = "monkey"
		event.server = true
		event.essential = true
		table.insert(events, event)
	end
	add({ t = spawnAt, name = `{prefix}Alfa`, species = species, alpha = true, at = alphaAt, yaw = yaw })
	add({ t = roarAt, name = `{prefix}Alfa`, action = "Roar" })
	add({ t = roarAt + 1.3, name = `{prefix}Alfa`, action = "Attack" })
	for index, position in others do
		local name = `{prefix}{index}`
		add({ t = spawnAt, name = name, species = species, at = position, yaw = yaw })
		add({ t = attackAt + (index % 3) * 0.35, name = name, action = "Attack" })
		add({ t = attackAt + 1.2 + (index % 2) * 0.4, name = name, action = "Roar" })
	end
end

-- Versión cómic del sobrevuelo (Flyover_Comic): el mismo recorrido con viñetas, fondos de semitono y de líneas de
-- velocidad y onomatopeyas en 11 de los 25 planos (el 44 %); en los demás, la ventana a pantalla completa (sin borde).
-- Cada fila es el plano que empieza en t: forma de la ventana (Comic.PRESETS), estilo de fondo, colores y, si lleva,
-- una onomatopeya { texto, x, y, rotación }. Los paneles cambian de golpe, a la vez que el corte de cámara.
local COMIC_RED = { Color3.fromRGB(206, 62, 32), Color3.fromRGB(255, 238, 200) }
local COMIC_BLUE = { Color3.fromRGB(64, 98, 168), Color3.fromRGB(255, 238, 200) }
local COMIC_GOLD = { Color3.fromRGB(240, 170, 30), Color3.fromRGB(70, 36, 20) }
local COMIC_DARK = { Color3.fromRGB(150, 28, 40), Color3.fromRGB(255, 226, 170) }
local FLYOVER_COMIC_PANELS: { { t: number, shape: string, style: string?, colors: { Color3 }?, sfx: { any }? } } = {
	{ t = 0, shape = "full" },
	{ t = 1.35, shape = "diagLeft", style = "halftone", colors = COMIC_BLUE },
	{ t = 2.7, shape = "full" },
	{ t = 4.05, shape = "diagRight", style = "speed", colors = COMIC_RED },
	{ t = 5.4, shape = "full" },
	{
		t = 6.75,
		shape = "tri",
		style = "halftone",
		colors = COMIC_RED,
		sfx = { Strings.later("¡BUM!"), 0.68, 0.25, 8 },
	},
	{ t = 8.1, shape = "full" },
	{ t = 9.45, shape = "diagLeft", style = "speed", colors = COMIC_GOLD },
	{ t = GLIDE_START, shape = "full" },
	{
		t = 12.85,
		shape = "tallSlant",
		style = "halftone",
		colors = COMIC_GOLD,
		sfx = { Strings.later("¡WHOOSH!"), 0.14, 0.24, -10 },
	},
	{ t = 14.45, shape = "full" },
	{
		t = 16.05,
		shape = "diagRight",
		style = "speed",
		colors = COMIC_GOLD,
		sfx = { Strings.later("¡WHOOSH!"), 0.68, 0.22, 7 },
	},
	{ t = 17.65, shape = "full" },
	{ t = 19.25, shape = "diagLeft", style = "halftone", colors = COMIC_BLUE },
	{ t = 20.65, shape = "full" },
	{ t = 22.05, shape = "full" },
	{
		t = 23.45,
		shape = "diagRight",
		style = "speed",
		colors = COMIC_DARK,
		sfx = { Strings.later("¡ROAAAR!"), 0.2, 0.22, -8 },
	},
	{ t = 24.85, shape = "full" },
	{ t = 26.3, shape = "full" },
	{
		t = 27.7,
		shape = "tallSlant",
		style = "halftone",
		colors = COMIC_DARK,
		sfx = { Strings.later("¡FUM!"), 0.7, 0.3, 9 },
	},
	{ t = 29.1, shape = "full" },
	{
		t = 30.55,
		shape = "diagLeft",
		style = "halftone",
		colors = COMIC_RED,
		sfx = { Strings.later("¡ROAAAR!"), 0.2, 0.24, -7 },
	},
	{ t = 31.95, shape = "full" },
	{
		t = 33.35,
		shape = "wide",
		style = "speed",
		colors = COMIC_DARK,
		sfx = { Strings.later("¡CRASH!"), 0.68, 0.26, 6 },
	},
	{ t = 34.8, shape = "full" },
}

local function flyoverScene(comic: boolean): Scene
	local events: { { [string]: any } } = {
		-- Planeo: un solo movimiento lineal, nariz abajo. Al llegar, la montura se aparta del mundo (ya no sale en pantalla).
		{
			t = GLIDE_START,
			kind = "move",
			actor = "mount",
			pos = GLIDE_TO,
			yaw = GLIDE_YAW,
			pitch = GLIDE_PITCH,
			seconds = GLIDE_END - GLIDE_START,
			easing = Enum.EasingStyle.Linear,
		},
		-- Las manadas salen a contraluz y oscuras: una luz que sigue a la cámara y algo de exposición, hasta el cartel.
		{ t = GLIDE_END - 0.1, kind = "exposure", value = 0.6 },
		{
			t = GLIDE_END - 0.1,
			kind = "light",
			follow = true,
			offset = Vector3.new(0, 5, 0),
			color = Color3.fromRGB(255, 236, 210),
			brightness = 2,
			range = 40,
			seconds = 12.8,
		},
		{ t = 34.7, kind = "exposure", value = 0 },
		{ t = GLIDE_END + 0.5, kind = "move", actor = "mount", pos = Vector3.new(0, -400, 0), yaw = GLIDE_YAW },
	}
	-- Las escenas cómic no llevan franjas negras: la ventana de las viñetas (Comic) hace de marco.
	if not comic then
		table.insert(events, 1, { t = 0, kind = "letterbox" })
	end
	-- Volcán: gorilas (grandes) mirando hacia el Basecamp (-X).
	flyoverPack(
		events,
		"VolcanGorila",
		"Gorila",
		19.5,
		90,
		Vector3.new(399, 0, -92),
		{ Vector3.new(410, 0, -76), Vector3.new(410, 0, -108), Vector3.new(420, 0, -84), Vector3.new(420, 0, -100) },
		22.6,
		23.0
	)
	-- Falda de la montaña: babuino alfa (mediano) con gibones detrás, mirando al sur (+Z).
	flyoverPack(events, "MontanaBabuino", "Babuino", 23.8, 180, Vector3.new(-420, 0, -100), {
		Vector3.new(-432, 0, -108),
		Vector3.new(-408, 0, -108),
		Vector3.new(-442, 0, -114),
		Vector3.new(-398, 0, -114),
	}, 26.9, 27.3)
	-- Sur del Basecamp (claro sin árboles ni bambú, a 270 studs): chimpancés (grandes) mirando al norte, hacia el Basecamp.
	flyoverPack(
		events,
		"SurChimpance",
		"Chimpance",
		28,
		0,
		Vector3.new(-25, 0, 272),
		{ Vector3.new(-13, 0, 284), Vector3.new(-37, 0, 284), Vector3.new(-3, 0, 294), Vector3.new(-47, 0, 294) },
		31.2,
		31.6
	)
	-- Cartel con el reto, título del juego y fundido a negro.
	table.insert(events, {
		t = 35,
		kind = "title",
		text = Strings.later("¿Cuántos días puedes sobrevivir en la isla?"),
		seconds = 2.7,
	})
	table.insert(events, {
		t = 38.8,
		kind = "logo", -- el logo de la portada; sin imagen, el texto
		text = Strings.later("Primal Banana Islands"),
		sub = Strings.later("Monkey Survival"),
		seconds = 1.5,
	})
	table.insert(events, { t = 41, kind = "fade", seconds = 1, toBlack = true })
	if comic then
		for _, row in FLYOVER_COMIC_PANELS do
			table.insert(events, {
				t = row.t,
				kind = "panel",
				shape = row.shape,
				bg = { style = row.style or "flat", colors = row.colors or COMIC_RED },
			})
			local sfx = row.sfx
			if sfx then
				table.insert(events, {
					t = row.t + 0.1,
					kind = "sfx",
					text = sfx[1],
					pos = { sfx[2], sfx[3] },
					rot = sfx[4],
					size = 0.3,
					color = Color3.new(1, 1, 1),
					seconds = 1.3,
				})
			end
		end
	end
	return {
		duration = FLYOVER_SECONDS,
		audience = "Self",
		freeze = false,
		skippable = true,
		hour = FLYOVER_HOUR,
		streamFollowsCamera = true,
		actors = {
			mount = {
				kind = "prop",
				build = function()
					local Players = game:GetService("Players")
					local model = MountedRider.build("Quetzalcoatl", Players.LocalPlayer.Character, { pose = "Glide" })
					assert(model, "Sobrevuelo: no se pudo construir la montura")
					model:PivotTo(
						CFrame.new(GLIDE_FROM)
							* CFrame.Angles(0, math.rad(GLIDE_YAW), 0)
							* CFrame.Angles(math.rad(GLIDE_PITCH), 0, 0)
					)
					return model
				end,
			},
		},
		camera = flyoverCamera(),
		events = events,
	}
end

-- Mascotas (Fase 25, G7b; 40 s) y Mascotas reel (15 s, 9:16): vídeo de las siete mascotas con el avatar del jugador en tres
-- sitios de la Isla, solo para grabar (órdenes «🐾 Mascotas» y «🐾 Mascotas reel»). Van en coordenadas del MUNDO (anchor =
-- CFrame.identity, lo pone DebugService) y la cámara cruza la isla (streamFollowsCamera). Los sitios están medidos con
-- rayos en el Studio de la Isla (radio 950): JUNGLA, claro llano al sur del Basecamp (Y 12 a 13, árboles fuera de ±30
-- del centro); MANGLAR, orilla del Orangután (llano al oeste y al sur, el río al NE); MONTAÑA, banco llano de la falda
-- (Y ~21) con la pared al norte. Todas las alturas de cámara se cuentan sobre el suelo MÁS ALTO de su claro
-- (surface), con 2 studs de colchón como mínimo. Lo marcado «a medir» no se pudo comprobar sin Studio.
--
-- Línea de tiempo de Pets (las coordenadas de cada acción están en petsFullEvents):
--    0 a 4     Montaje de 6 cortes en la jungla (cara del Labrador, cenital del Beagle, gatos a ras, el avatar visto por
--              detrás, salto del Jaguar de Cristal de perfil, plano general)
--    4 a 14    JUNGLA: el avatar se agacha y da la mano al Labrador (GivePaw), el Beagle echado, los gatos se rozan en sus
--              piernas (IdleRub) y dan la vuelta, salto del Jaguar de Cristal con sacudida al aterrizar
--   14 a 27    MANGLAR: la capibara y el ajolote saltan junto al agua, llega la manada (5 monos, el Mandril alfa), pelea y
--              los monos se van con su «¡puf!»
--   27 a 37    MONTAÑA: el avatar sube la falda, el Ocelote salta entre rocas, el Quetzal despega y planea sobre la cámara
--   37 a 40    cartel «Tus mascotas, tu manada», logo y fundido a negro
-- Pets_Reel es lo mismo recortado: montaje de 3 s, dar la pata, mordisco y planeo del Quetzal (cortes de ventana alta,
-- como Battle_Pack_Reel).
local PETS_SECONDS = 40
local PETS_REEL_SECONDS = 15
local PETS_HOUR = 17.5 -- atardecer dorado, como el Sobrevuelo
local PET_JUMP_SECONDS = 0.95 -- clip Jump (Cat, Dog, Capibara y Quetzal duran de 0,9 a 0,95 s)
local PET_ATTACK_HIT = 0.35 -- segundos del inicio de Attack al zarpazo (el Ocelote y el Jaguar de Cristal)
local PET_BITE_HIT = 0.45 -- segundos del inicio de Bite al mordisco (a medir en Studio)
local PET_LUNGE_SECONDS = 0.35 -- lo que tarda una mascota en lanzarse hacia un mono
local PET_WALK_MOVING = 0.4 -- «moving» (0 a 1) de un paseo: mezcla Walk y Run como PetFollowers
local PET_RUN_MOVING = 1
local PET_CAPTIONS = {
	jungle = Strings.later("Los amigos más fieles de la isla"),
	mangrove = Strings.later("Y no se rinden ante la manada"),
	mountain = Strings.later("Siempre a tu lado, hasta la cima"),
	title = Strings.later("Tus mascotas, tu manada"),
}

-- Altura (x, alto sobre el suelo más alto del claro, z) en el mundo. El colchón de las cámaras sale de aquí.
local function surface(top: number): (number, number, number) -> Vector3
	return function(x: number, height: number, z: number): Vector3
		return Vector3.new(x, top + height, z)
	end
end
local jungle = surface(13) -- el llano sube a 13 como mucho
local mangrove = surface(14) -- 12 a 14
local mountain = surface(22) -- el banco ronda los 21 (a medir)

-- Giro (grados, como el yaw de los actores: 0 mira a -Z) para ir de un punto a otro.
local function yawBetween(from: Vector3, to: Vector3): number
	return math.deg(math.atan2(-(to.X - from.X), -(to.Z - from.Z)))
end

local JUNGLE_AVATAR = Vector3.new(-25, 12.5, 272)
local JUNGLE_RING = 2.4 -- radio de la vuelta de los gatos alrededor del avatar

-- Punto de la vuelta de los gatos alrededor del avatar (grados desde +X hacia +Z).
local function ringPoint(degrees: number): Vector3
	local a = math.rad(degrees)
	return Vector3.new(
		JUNGLE_AVATAR.X + math.cos(a) * JUNGLE_RING,
		JUNGLE_AVATAR.Y,
		JUNGLE_AVATAR.Z + math.sin(a) * JUNGLE_RING
	)
end

-- Quetzal (montaña): sale del banco, despega y planea hasta pasar a ~6 studs sobre la cámara (PET_OVERHEAD_CAM).
local Q_FROM = Vector3.new(-414, 21.1, -96) -- en el suelo (sin snap: vuela; a medir)
local Q_MID = Vector3.new(-409, 24, -94.3) -- donde acaba el despegue
local Q_TO = Vector3.new(-376, 38, -83)
local Q_TAKEOFF_SECONDS = 0.9
local Q_BODY_LIFT = 1.2 -- de sus pies al centro del cuerpo (adonde mira la cámara)
local Q_YAW = yawBetween(Q_MID, Q_TO)
local Q_GLIDE_PITCH =
	math.deg(math.atan((Q_TO.Y - Q_MID.Y) / Vector3.new(Q_TO.X - Q_MID.X, 0, Q_TO.Z - Q_MID.Z).Magnitude))
local PET_OVERHEAD_CAM = mountain(-396, 4, -92.3) -- a 2,5 studs al lado del camino del Quetzal (nunca mira en vertical); a 4 studs, sobre la hierba

-- Dónde está el Quetzal (sus pies) en el segundo t, con el despegue en jumpAt y un planeo de glideSeconds.
local function quetzalAt(t: number, jumpAt: number, glideSeconds: number): Vector3
	local takeoffEnd = jumpAt + Q_TAKEOFF_SECONDS
	if t <= jumpAt then
		return Q_FROM
	elseif t < takeoffEnd then
		return Q_FROM:Lerp(Q_MID, (t - jumpAt) / Q_TAKEOFF_SECONDS)
	end
	return Q_MID:Lerp(Q_TO, math.clamp((t - takeoffEnd) / glideSeconds, 0, 1))
end

type Spot = { pos: Vector3, yaw: number }

local function spot(x: number, y: number, z: number, yaw: number): Spot
	return { pos = Vector3.new(x, y, z), yaw = yaw }
end

-- Jungla: el avatar mira al este, hacia el Labrador; los gatos, en su vuelta; el Beagle, echado al noroeste.
local PET_JUNGLE: { [string]: Spot } = {
	avatar = { pos = JUNGLE_AVATAR, yaw = -90 },
	labrador = spot(-22.2, 12.5, 272, 90),
	beagle = spot(-31, 12.5, 264, 170),
	ocelote = { pos = ringPoint(140), yaw = yawBetween(ringPoint(140), JUNGLE_AVATAR) },
	jaguar = { pos = ringPoint(250), yaw = yawBetween(ringPoint(250), JUNGLE_AVATAR) },
}
-- Orilla del manglar donde juegan la capibara y el ajolote (a medir: el río está a x ≥ 410, z ≤ 520).
local PET_WATER: { [string]: Spot } = {
	capibara = spot(400, 13, 531, 180),
	ajolote = spot(404.5, 13, 527.5, 200),
}
-- Manglar: la fila de combate de cara a los monos, que llegan del oeste.
local PET_LINE: { [string]: Spot } = {
	avatar = spot(392, 13, 542.5, 90),
	labrador = spot(382.5, 13, 546, 90),
	jaguar = spot(381, 13, 543.5, 90),
	ocelote = spot(381, 13, 541, 90),
	beagle = spot(382.5, 13, 538.5, 90),
	capibara = spot(386, 13, 548, 90),
	ajolote = spot(386, 13, 536, 90),
}
-- Hasta dónde se lanza cada una contra los monos (a ~4,5 studs de ellos).
local PET_LUNGE: { [string]: Vector3 } = {
	labrador = Vector3.new(377.8, 13, 547.4),
	beagle = Vector3.new(377.8, 13, 537.6),
	jaguar = Vector3.new(377.3, 13, 542.8),
	ocelote = Vector3.new(377.3, 13, 540.8),
	capibara = Vector3.new(376, 13, 544.2),
}
-- Montaña, al llegar (el banco llano de x -420 a -395 y z -112 a -88) y al terminar la subida, de cara a la pared.
local PET_CLIMB_START: { [string]: Spot } = {
	avatar = spot(-404, 21, -96, 35),
	labrador = spot(-402.5, 21, -98.5, 35),
	beagle = spot(-406, 21, -94.5, 35),
	jaguar = spot(-400, 21, -96.5, 35),
	ocelote = spot(-408, 21, -98, 35),
	capibara = spot(-399.5, 21, -100, 35),
	ajolote = spot(-407, 21, -91.5, 35),
}
local PET_SUMMIT: { [string]: Spot } = {
	avatar = spot(-411, 21, -106, 20),
	labrador = spot(-408.5, 21, -103.5, 20),
	beagle = spot(-413.5, 21, -103.8, 20),
	jaguar = spot(-407, 21, -107.5, 20),
	ocelote = spot(-409.5, 21, -101.5, 20),
	capibara = spot(-405, 21, -104, 20),
	ajolote = spot(-415, 21, -107, 20),
}
local PET_SPECIES = {
	labrador = "Labrador",
	beagle = "Beagle",
	jaguar = "JaguarCristal",
	ocelote = "Ocelote",
	capibara = "Capibara",
	ajolote = "Ajolote",
	quetzal = "Quetzal",
}
-- La manada del manglar: el Mandril alfa y cuatro más, en fila a ~5 studs de las mascotas (x, z donde frenan).
local PET_MONKEY_START_X = 350
local PET_MONKEYS = {
	{ name = "alfa", species = "Mandril", alpha = true, x = 372.5, z = 541.8 },
	{ name = "macaco1", species = "Macaco", alpha = false, x = 373.5, z = 545.8 },
	{ name = "babuino", species = "Babuino", alpha = false, x = 373.2, z = 538.2 },
	{ name = "aullador", species = "AulladorRojo", alpha = false, x = 374, z = 549 },
	{ name = "macaco2", species = "Macaco", alpha = false, x = 374, z = 535.6 },
}

local function petsActors(): { [string]: { [string]: any } }
	-- Dónde empieza cada una al comenzar la escena (el resto de sitios se ponen con eventos move a t = 0 s).
	local starts: { [string]: Spot } = table.clone(PET_JUNGLE)
	for name, start in PET_WATER do
		starts[name] = start
	end
	starts.quetzal = { pos = Q_FROM, yaw = Q_YAW }
	local actors: { [string]: { [string]: any } } = {
		avatar = { kind = "localPlayer", pos = JUNGLE_AVATAR, yaw = PET_JUNGLE.avatar.yaw, snap = true },
	}
	for name, species in PET_SPECIES do
		local start = starts[name]
		actors[name] = {
			kind = "prop",
			build = PetActor.propBuilder(species, nil, start.pos, start.yaw, name == "quetzal"),
		}
	end
	return actors
end

-- Escritor de los eventos de la escena: petClip y move de las mascotas, anim y move del avatar, monkey del servidor.
-- Recuerda dónde está cada actor (para el giro de un paseo). Los nombres de actor son los de PET_SPECIES y «avatar».
type PetWriter = {
	add: (event: { t: number, kind: string, [string]: any }) -> (),
	clip: (t: number, actor: string, name: string | boolean, loop: boolean?, moving: number?) -> (),
	walk: (t: number, actor: string, pos: Vector3, seconds: number, moving: number?, yaw: number?) -> (),
	put: (t: number, actor: string, pos: Vector3, yaw: number) -> (),
	jump: (t: number, actor: string, to: Vector3?, yaw: number?) -> (),
	strike: (t: number, actor: string, name: string, lunge: Vector3?) -> (),
	monkey: (t: number, name: string, fields: { [string]: any }) -> (),
	anim: (t: number, action: string, seconds: number) -> (),
	avatarWalk: (t: number, pos: Vector3, seconds: number, yaw: number) -> (),
}

local function petWriter(events: EventList): PetWriter
	local where: { [string]: Vector3 } = { quetzal = Q_FROM }
	for name, start in PET_JUNGLE do
		where[name] = start.pos
	end
	for name, start in PET_WATER do
		where[name] = start.pos
	end
	local function add(event: { t: number, kind: string, [string]: any })
		table.insert(events, event)
	end
	-- name = clip a poner (loop: en bucle) o false para quitarlo; moving = cuánto anda (0 a 1) hasta el próximo cambio.
	local function clip(t: number, actor: string, name: string | boolean, loop: boolean?, moving: number?)
		add({ t = t, kind = "petClip", actor = actor, clip = name, loop = loop, moving = moving })
	end
	-- Paseo en línea recta: anda (Walk o Run según moving) y se para al llegar. yaw = el giro con que llega.
	local function walk(t: number, actor: string, pos: Vector3, seconds: number, moving: number?, yaw: number?)
		clip(t, actor, false, nil, moving or PET_WALK_MOVING)
		add({
			t = t,
			kind = "move",
			actor = actor,
			pos = pos,
			yaw = yaw or yawBetween(where[actor] or pos, pos),
			seconds = seconds,
			easing = Enum.EasingStyle.Linear,
		})
		clip(t + seconds, actor, false, nil, 0)
		where[actor] = pos
	end
	-- Cambio de sitio de golpe (entre un claro y el siguiente, justo antes del corte de cámara).
	local function put(t: number, actor: string, pos: Vector3, yaw: number)
		if actor ~= "avatar" then
			clip(t, actor, false, nil, 0)
		end
		add({ t = t, kind = "move", actor = actor, pos = pos, yaw = yaw, seconds = 0 })
		where[actor] = pos
	end
	-- Salto: el clip Jump y, si lleva destino, el desplazamiento de lo que dura (el clip mueve el cuerpo, no el sitio).
	local function jump(t: number, actor: string, to: Vector3?, yaw: number?)
		clip(t, actor, "Jump")
		if to then
			add({
				t = t,
				kind = "move",
				actor = actor,
				pos = to,
				yaw = yaw or yawBetween(where[actor] or to, to),
				seconds = PET_JUMP_SECONDS,
				easing = Enum.EasingStyle.Linear,
			})
			where[actor] = to
		end
	end
	-- Ataque (Bite, Attack): el clip y, si lleva destino, un salto corto hacia el mono.
	local function strike(t: number, actor: string, name: string, lunge: Vector3?)
		clip(t, actor, name)
		if lunge then
			add({
				t = t,
				kind = "move",
				actor = actor,
				pos = lunge,
				yaw = yawBetween(where[actor] or lunge, lunge),
				seconds = PET_LUNGE_SECONDS,
			})
			where[actor] = lunge
		end
	end
	local function monkey(t: number, name: string, fields: { [string]: any })
		local event: { [string]: any } = { t = t, kind = "monkey", server = true, name = name }
		for field, value in fields do
			event[field] = value
		end
		add(event :: any)
	end
	-- Gesto del avatar (PlayerAnimations: Place, Point, Cheer…).
	local function anim(t: number, action: string, seconds: number)
		add({ t = t, kind = "anim", actor = "avatar", action = action, seconds = seconds })
	end
	local function avatarWalk(t: number, pos: Vector3, seconds: number, yaw: number)
		anim(t, "Walk", seconds)
		add({
			t = t,
			kind = "move",
			actor = "avatar",
			pos = pos,
			yaw = yaw,
			seconds = seconds,
			easing = Enum.EasingStyle.Linear,
		})
		where.avatar = pos
	end
	return {
		add = add,
		clip = clip,
		walk = walk,
		put = put,
		jump = jump,
		strike = strike,
		monkey = monkey,
		anim = anim,
		avatarWalk = avatarWalk,
	}
end

-- Pone a todos los de `names` en sus sitios de `spots` (un claro nuevo).
local function putGroup(w: PetWriter, t: number, spots: { [string]: Spot }, names: { string })
	for _, name in names do
		w.put(t, name, spots[name].pos, spots[name].yaw)
	end
end

-- Montaje de la jungla (los primeros segundos de las dos versiones): cada una en su postura de reposo y el Jaguar de
-- Cristal salta en jumpAt hacia el oeste y vuelve a su sitio.
local function petMontage(w: PetWriter, jumpAt: number)
	w.clip(0, "labrador", "IdleSit", true)
	w.clip(0, "beagle", "LieDown", true)
	w.clip(0, "ocelote", "IdleRub", true)
	w.clip(0, "jaguar", "IdleRub", true)
	local home = PET_JUNGLE.jaguar
	w.jump(jumpAt, "jaguar", Vector3.new(-29.5, 12.5, 268.8))
	w.walk(jumpAt + PET_JUMP_SECONDS + 0.1, "jaguar", home.pos, 1, PET_WALK_MOVING, home.yaw)
	w.clip(jumpAt + PET_JUMP_SECONDS + 1.2, "jaguar", "IdleRub", true)
end

-- Despegue y planeo del Quetzal: Jump con el despegue hasta Q_MID, Glide en bucle y una línea recta nariz arriba hasta
-- Q_TO (pasa sobre PET_OVERHEAD_CAM a un 40 % del planeo).
local function petQuetzal(w: PetWriter, jumpAt: number, glideSeconds: number)
	local takeoffEnd = jumpAt + Q_TAKEOFF_SECONDS
	w.clip(jumpAt, "quetzal", "Jump")
	w.add({
		t = jumpAt,
		kind = "move",
		actor = "quetzal",
		pos = Q_MID,
		yaw = Q_YAW,
		pitch = 25,
		seconds = Q_TAKEOFF_SECONDS,
		easing = Enum.EasingStyle.Linear,
	})
	w.clip(takeoffEnd, "quetzal", "Glide", true)
	w.add({
		t = takeoffEnd,
		kind = "move",
		actor = "quetzal",
		pos = Q_TO,
		yaw = Q_YAW,
		pitch = Q_GLIDE_PITCH,
		seconds = glideSeconds,
		easing = Enum.EasingStyle.Linear,
	})
end

-- La manada llega del oeste corriendo (aparece en arrivalAt - runSeconds - 0,2 y frena en arrivalAt) y las mascotas
-- pelean. Tiempos relativos a `a` = el momento en que frena. Los golpes caen PET_BITE_HIT o PET_ATTACK_HIT tras empezar
-- el clip (el mono se queja entonces); el alfa cae el último. withTail = false deja fuera la vuelta a la fila y el
-- Cheer (en el reel el corte a la montaña llega justo después).
local function petFight(w: PetWriter, a: number, runSeconds: number, withTail: boolean)
	for _, member in PET_MONKEYS do
		local at = Vector3.new(PET_MONKEY_START_X, 0, member.z)
		w.monkey(
			a - runSeconds - 0.2,
			member.name,
			{ species = member.species, alpha = member.alpha, at = at, yaw = -90, action = "Idle" }
		)
		w.monkey(
			a - runSeconds,
			member.name,
			{ move = { pos = Vector3.new(member.x, 0, member.z), seconds = runSeconds, yaw = -90 } }
		)
	end
	w.anim(a - 0.9, "Point", 1.5)
	w.monkey(a + 0.1, "alfa", { action = "Roar" })
	-- Primera ronda: los perros muerden, los gatos arañan y el alfa se defiende.
	w.strike(a + 0.4, "labrador", "Bite", PET_LUNGE.labrador)
	w.monkey(a + 0.4 + PET_BITE_HIT, "aullador", { action = "Hurt" })
	w.monkey(a + 1.4, "aullador", { action = "Die" })
	w.strike(a + 0.6, "beagle", "Bite", PET_LUNGE.beagle)
	w.monkey(a + 0.6 + PET_BITE_HIT, "babuino", { action = "Hurt" })
	w.monkey(a + 1.6, "babuino", { action = "Die" })
	w.monkey(a + 0.9, "alfa", { action = "Attack" })
	w.strike(a + 0.8, "jaguar", "Attack", PET_LUNGE.jaguar)
	w.monkey(a + 0.8 + PET_ATTACK_HIT, "alfa", { action = "Hurt" })
	w.strike(a + 1.0, "ocelote", "Attack", PET_LUNGE.ocelote)
	w.monkey(a + 1.0 + PET_ATTACK_HIT, "alfa", { action = "Hurt" })
	w.monkey(a + 1.2, "macaco1", { action = "Attack" })
	-- La capibara embiste y el ajolote salta (sacudida suave al chocar).
	w.walk(a + 1.5, "capibara", PET_LUNGE.capibara, 0.7, PET_RUN_MOVING, 90)
	w.add({ t = a + 2.1, kind = "shake", amp = 0.15, seconds = 0.4 })
	w.monkey(a + 2.15, "alfa", { action = "Hurt" })
	w.jump(a + 1.55, "ajolote", Vector3.new(381.5, 13, 537.8), 90)
	w.jump(a + 2.6, "ajolote", PET_LINE.ajolote.pos, 90)
	-- Segunda ronda: los perros repiten desde donde están y los gatos remachan al alfa.
	w.strike(a + 1.5, "labrador", "Bite")
	w.monkey(a + 1.5 + PET_BITE_HIT, "macaco1", { action = "Hurt" })
	w.monkey(a + 2.4, "macaco1", { action = "Die" })
	w.strike(a + 1.7, "beagle", "Bite")
	w.monkey(a + 1.7 + PET_BITE_HIT, "macaco2", { action = "Hurt" })
	w.monkey(a + 2.65, "macaco2", { action = "Die" })
	w.strike(a + 1.9, "jaguar", "Attack")
	w.monkey(a + 1.9 + PET_ATTACK_HIT, "alfa", { action = "Hurt" })
	w.strike(a + 2.1, "ocelote", "Attack")
	w.monkey(a + 2.1 + PET_ATTACK_HIT, "alfa", { action = "Hurt" })
	w.monkey(a + 3.0, "alfa", { action = "Die" })
	if withTail then
		for _, name in { "labrador", "beagle", "jaguar", "ocelote", "capibara" } do
			w.walk(a + 3.3, name, PET_LINE[name].pos, 0.8, PET_WALK_MOVING, 90)
		end
		w.anim(a + 3.3, "Cheer", 1.6)
	end
end

local PET_ALL = { "avatar", "labrador", "beagle", "jaguar", "ocelote", "capibara", "ajolote" }

-- Los eventos de Pets (40 s). Cortes de cámara en petsCamera (mismos segundos).
local function petsFullEvents(w: PetWriter)
	petMontage(w, 2.85)
	-- JUNGLA (4 a 14): el avatar se agacha (Place) con la mano tendida, el Labrador da la pata (GivePaw dura 6,4 s).
	w.anim(5.4, "Place", 3.4)
	w.clip(5.9, "labrador", "GivePaw")
	-- Los gatos dan la vuelta pegados a sus piernas; el Ocelote vuelve a rozarse y el Jaguar de Cristal se va a saltar.
	w.walk(8.0, "ocelote", ringPoint(200), 1.3)
	w.walk(9.3, "ocelote", ringPoint(260), 1.3)
	w.clip(10.6, "ocelote", "IdleRub", true)
	w.walk(8.0, "jaguar", ringPoint(310), 1.2)
	w.walk(9.3, "jaguar", Vector3.new(-31.5, 12.5, 269.5), 1.4)
	w.jump(11.5, "jaguar", Vector3.new(-28, 12.5, 269.5), -90)
	w.add({ t = 11.5 + PET_JUMP_SECONDS - 0.1, kind = "shake", amp = 0.18, seconds = 0.45 }) -- al aterrizar
	-- MANGLAR (14 a 27): todos a la fila; la capibara y el ajolote juegan junto al agua y luego se unen a ella.
	putGroup(w, 13.96, PET_LINE, { "avatar", "labrador", "beagle", "jaguar", "ocelote" })
	w.jump(14.3, "capibara", Vector3.new(398, 13, 531.2))
	w.jump(14.8, "ajolote", Vector3.new(402.4, 13, 528.6))
	w.walk(15.5, "capibara", Vector3.new(403.5, 13, 534), 1, PET_RUN_MOVING)
	w.jump(16.0, "ajolote", Vector3.new(399.2, 13, 530.4))
	w.walk(17.2, "capibara", PET_LINE.capibara.pos, 2.2, PET_RUN_MOVING, 90)
	w.walk(17.2, "ajolote", PET_LINE.ajolote.pos, 2.2, 0.8, 90)
	petFight(w, 19.6, 2.4, true)
	-- MONTAÑA (27 a 37): sube la falda el avatar con las mascotas, el Ocelote salta, el Quetzal despega y planea.
	putGroup(w, 26.96, PET_CLIMB_START, PET_ALL)
	w.put(26.96, "quetzal", Q_FROM, Q_YAW)
	w.avatarWalk(27.4, PET_SUMMIT.avatar.pos, 5, 35)
	for _, name in { "labrador", "beagle", "jaguar", "capibara", "ajolote" } do
		w.walk(27.8, name, PET_SUMMIT[name].pos, 4.6, PET_WALK_MOVING, 30)
	end
	w.jump(28.5, "ocelote", Vector3.new(-410.5, 21, -101))
	w.jump(29.8, "ocelote", Vector3.new(-412.5, 21, -103.8))
	petQuetzal(w, 30.5, 3)
	w.jump(33.7, "ocelote", PET_SUMMIT.ocelote.pos, 25)
	w.anim(35.3, "Point", 1.7)
end

-- Los eventos de Pets_Reel (15 s). Cortes en petsReelCuts.
local function petsReelEvents(w: PetWriter)
	petMontage(w, 2.45)
	-- Dar la pata (3 a 5,4).
	w.anim(2.6, "Place", 3)
	w.clip(2.9, "labrador", "GivePaw")
	-- Mordisco (5,4 a 9,9): todos a la fila de golpe, la manada llega a 6,7 y cae el alfa a 9,7.
	putGroup(w, 5.26, PET_LINE, PET_ALL)
	petFight(w, 6.7, 1.6, false)
	-- Planeo del Quetzal (9,9 a 15): el grupo ya está en lo alto, de cara a la pared.
	putGroup(w, 9.86, PET_SUMMIT, PET_ALL)
	w.put(9.86, "quetzal", Q_FROM, Q_YAW)
	petQuetzal(w, 10.1, 2.1)
	w.anim(13.4, "Point", 1.5)
end

local function still(pos: Vector3, look: Vector3, seconds: number, fov: number, posB: Vector3?, lookB: Vector3?)
	return {
		{ t = 0, pos = pos, look = look, fov = fov },
		{ t = seconds, pos = posB or pos, look = lookB or look, fov = fov },
	}
end

-- Plano con la cámara fija y la mirada siguiendo al Quetzal de t0 a t1 (pasa por encima): se muestrea cada 0,3 s.
local function pushOverhead(
	camera: { CameraPoint },
	t0: number,
	t1: number,
	jumpAt: number,
	glideSeconds: number,
	fov: number
)
	local steps = math.ceil((t1 - t0) / 0.3)
	for i = 0, steps do
		local t = t0 + (t1 - t0) * i / steps
		local look = quetzalAt(t, jumpAt, glideSeconds) + Vector3.new(0, Q_BODY_LIFT, 0)
		if i == 0 then
			table.insert(camera, { t = t0 - 0.001, pos = PET_OVERHEAD_CAM, look = look, fov = fov })
		end
		table.insert(camera, { t = t, pos = PET_OVERHEAD_CAM, look = look, fov = fov })
		if i == steps then
			table.insert(camera, { t = t1 + 0.001, pos = PET_OVERHEAD_CAM, look = look, fov = fov })
		end
	end
end

-- La cámara de Pets: montaje de 6 cortes de 0,5 a 0,8 s (0 a 4) y después 4 o 6 tomas por claro. Las posiciones son de
-- diseño: a medir en Studio con rayos (colchón de 2 studs sobre el suelo y ningún tronco delante).
local function petsCamera(): { CameraPoint }
	local camera = (
		CameraPath.montage({
			-- 1. Primer plano de la cara del Labrador (IdleSit, mira al avatar), de perfil a ~4,5 studs. Coordenadas absolutas
			-- medidas en Studio con las mascotas colocadas: la versión anterior (a 2,5 studs, mirando al lomo) solo enseñaba
			-- el hombro. El avatar queda al borde del cuadro: el perro le mira.
			still(Vector3.new(-24.6, 15, 267.4), Vector3.new(-23.5, 14.9, 272), 0.6, 38, Vector3.new(-24.2, 15, 268.4)),
			-- 2. Picado fuerte de tres cuartos del Beagle echado (con cara y orejas; el cenital puro solo enseñaba el lomo).
			still(
				Vector3.new(-33, 16.8, 268.6),
				Vector3.new(-31, 13.8, 264.9),
				0.55,
				50,
				Vector3.new(-32.4, 16.2, 267.7)
			),
			-- 3. Los dos gatos rozándose en las piernas del avatar, desde atrás a la izquierda y baja (el Jaguar de Cristal a
			-- la izquierda, el Ocelote junto a las piernas y el Labrador al fondo). Antes, las piernas llenaban el cuadro.
			still(
				Vector3.new(-31.8, 14.4, 277.4),
				Vector3.new(-26.4, 13.9, 272.4),
				0.65,
				48,
				Vector3.new(-30.2, 14.3, 276.2)
			),
			-- 4. El avatar «como lo ve el jugador», con las mascotas alrededor.
			CameraPath.behind(Vector3.new(-25, 15.8, 272), PET_JUNGLE.avatar.yaw, 7, 2.2, 0, 0.8, 58),
			-- 5. El Jaguar de Cristal salta de perfil.
			still(jungle(-27.5, 2.4, 279), jungle(-27.7, 1.8, 269.3), 0.65, 42, jungle(-26.5, 2.4, 279)),
			-- 6. Plano general (el mismo con que empieza la toma de la jungla).
			still(jungle(-6, 3.2, 288), jungle(-26, 1.2, 272), 0.5, 62, jungle(-8, 3.2, 286.5)),
		}) :: any
	) :: { CameraPoint }
	-- JUNGLA. General lenta; primer plano de la mano y la pata; a ras del roce; salto de perfil.
	local groupLook = jungle(-26.5, 1.2, 270.5)
	pushShot(camera, 4.05, 6.55, shot(jungle(-8, 3.2, 286.5), groupLook, 62), shot(jungle(-12, 3, 283), groupLook, 52))
	pushShot(
		camera,
		6.6,
		8.55,
		shot(jungle(-22.4, 2.2, 277), jungle(-23.2, 1.3, 272), 42),
		shot(jungle(-22.8, 2.2, 276.2), jungle(-23.2, 1.3, 272), 36)
	)
	pushShot(
		camera,
		8.6,
		11,
		shot(jungle(-19.5, 2.2, 276), jungle(-25.5, 1.2, 272.4), 48),
		shot(jungle(-20.5, 2.2, 275), jungle(-25.8, 1.2, 271.6), 46)
	)
	pushShot(
		camera,
		11.05,
		13.95,
		shot(jungle(-34, 2.4, 281), jungle(-31.2, 1.8, 269.6), 44),
		shot(jungle(-26, 2.4, 281), jungle(-28.4, 1.8, 269.6), 44)
	)
	-- MANGLAR. El juego junto al agua (desde el oeste, con el río a la izquierda); la fila y la manada que llega (desde
	-- el sur); lateral del mordisco; contrapicado del salto del ajolote; cenital de la melé; el avatar por detrás.
	pushShot(
		camera,
		14,
		17.35,
		shot(mangrove(381, 3.5, 524), mangrove(402, 1.2, 529.5), 52),
		shot(mangrove(384, 3.2, 525), mangrove(403, 1.2, 529.5), 48)
	)
	pushShot(
		camera,
		17.4,
		19.75,
		shot(mangrove(394, 3.5, 565), mangrove(378, 1, 543), 60),
		-- x = 395: en 390 hay un tronco de mangle (Mapa.Vegetacion.Mangle.Trunk), medido en el Studio de la Isla.
		shot(mangrove(395, 3.5, 563), mangrove(377, 1, 543), 58)
	)
	pushShot(
		camera,
		19.8,
		21.05,
		shot(mangrove(388, 2.2, 556), mangrove(380, 1, 543), 44),
		shot(mangrove(386.5, 2.2, 555), mangrove(379.5, 1, 543), 40)
	)
	pushShot(
		camera,
		21.1,
		22.25,
		shot(mangrove(391, 1.9, 530), mangrove(386, 3, 536), 52),
		shot(mangrove(390, 1.9, 531), mangrove(386, 3.4, 536), 52)
	)
	local melee = CameraPath.zenith(Vector3.new(378, 14.5, 541.5), 24, 22.3, 24.15, 55)
	pushShot(camera, 22.3, 24.15, melee[1], melee[2])
	-- El avatar (en x = 392) visto desde 3 studs por detrás de él, mirando a la fila y a donde llegaron los monos.
	local watching = CameraPath.behind(Vector3.new(386, 15.2, 542.5), PET_LINE.avatar.yaw, 9, 2.4, 24.2, 27, 54)
	pushShot(camera, 24.2, 27, watching[1], watching[2])
	-- MONTAÑA. General baja con la pared al fondo; la cámara en el banco y la mirada tras el Quetzal que pasa sobre ella;
	-- primer plano del Ocelote; plano final abierto, que sube despacio.
	pushShot(
		camera,
		27.05,
		30.45,
		shot(mountain(-401.5, 6.5, -94), mountain(-406.5, 0.8, -100.5), 62),
		shot(mountain(-402, 6.5, -94.5), mountain(-409, 1, -103), 58)
	)
	pushOverhead(camera, 30.5, 33.55, 30.5, 3, 60)
	pushShot(
		camera,
		33.6,
		35.15,
		shot(mountain(-404, 5.2, -98.5), mountain(-410, 1.2, -103), 44),
		shot(mountain(-405, 5.2, -99.5), mountain(-410.5, 1.4, -103), 40)
	)
	pushShot(
		camera,
		35.2,
		PETS_SECONDS,
		shot(mountain(-402, 8, -95.5), mountain(-409.5, 1.5, -104.5), 55),
		shot(mountain(-400, 11.5, -92), mountain(-410, 3.5, -107), 58)
	)
	return camera
end

-- Los cortes de Pets_Reel (9:16): cada plano y su ventana salen del mismo dato (como battleReelCuts). `width` = studs
-- que caben en la banda a la distancia del sujeto. Posiciones de diseño: a medir en Studio.
local function petsReelCuts(): { ReelCut }
	local lift = Vector3.new(0, Q_BODY_LIFT, 0)
	return {
		-- Montaje de 3 s en la jungla.
		{
			t0 = 0,
			t1 = 0.55,
			shape = "reelTall",
			bg = "speed",
			-- Los tres primeros, con los encuadres medidos en Studio (los mismos que el montaje de Pets).
			pos = Vector3.new(-24.6, 15, 267.4),
			subject = Vector3.new(-23.5, 14.9, 272),
			width = 4,
		},
		{
			t0 = 0.6,
			t1 = 1.15,
			shape = "reelTop",
			bg = "halftone",
			pos = Vector3.new(-33, 16.8, 268.6),
			subject = Vector3.new(-31, 13.8, 264.9),
			width = 5,
		},
		{
			t0 = 1.2,
			t1 = 1.75,
			shape = "reelDiagR",
			bg = "flat",
			pos = Vector3.new(-31.8, 14.4, 277.4),
			subject = Vector3.new(-26.4, 13.9, 272.4),
			width = 6.5,
		},
		{
			t0 = 1.8,
			t1 = 2.35,
			shape = "reelSlant",
			bg = "speed",
			pos = Vector3.new(-32, 17.7, 272),
			subject = Vector3.new(-24, 15.2, 272),
			width = 9,
		},
		{
			t0 = 2.4,
			t1 = 3,
			shape = "reelTall",
			bg = "halftone",
			pos = jungle(-27.5, 2.4, 279),
			subject = Vector3.new(-27.7, 14.8, 269.2),
			width = 7,
		},
		-- Dar la pata (el Labrador, GivePaw desde 2,9) y el grupo.
		{
			t0 = 3.05,
			t1 = 4.5,
			shape = "reelTop",
			bg = "flat",
			pos = jungle(-22.4, 2.2, 277),
			subject = jungle(-23.6, 1.3, 272),
			width = 4.5,
		},
		{
			t0 = 4.55,
			t1 = 5.35,
			shape = "reelDiagL",
			bg = "halftone",
			pos = jungle(-8, 3.2, 286.5),
			subject = jungle(-26.5, 1.2, 270.5),
			width = 16,
		},
		-- Manglar: la manada llega (6,7), mordiscos y zarpazos, el alfa cae (9,7).
		{
			t0 = 5.4,
			t1 = 6.75,
			shape = "reelTall",
			bg = "speed",
			pos = mangrove(394, 3.5, 565),
			subject = mangrove(378, 1, 543),
			width = 30,
		},
		{
			t0 = 6.8,
			t1 = 8.15,
			shape = "reelDiagR",
			bg = "flat",
			pos = mangrove(388, 2.2, 556),
			subject = mangrove(379.5, 1, 543),
			width = 12,
		},
		{
			t0 = 8.2,
			t1 = 9.9,
			shape = "reelTop",
			bg = "halftone",
			pos = Vector3.new(381, 24, 553),
			subject = Vector3.new(376, 14.6, 542),
			width = 14,
		},
		-- Montaña: despega el Quetzal (10,1), planea sobre la cámara y el grupo mira la pared.
		{
			t0 = 9.95,
			t1 = 11.35,
			shape = "reelTall",
			bg = "speed",
			pos = mountain(-403, 6, -89.5),
			subject = Q_FROM + lift,
			subjectB = quetzalAt(11.3, 10.1, 2.1) + lift,
			width = 10,
		},
		{
			t0 = 11.4,
			t1 = 13,
			shape = "reelSlant",
			bg = "flat",
			pos = PET_OVERHEAD_CAM,
			subject = quetzalAt(11.4, 10.1, 2.1) + lift,
			subjectB = quetzalAt(13, 10.1, 2.1) + lift,
			width = 12,
		},
		{
			t0 = 13.05,
			t1 = PETS_REEL_SECONDS,
			shape = "reelDiagL",
			bg = "halftone",
			pos = mountain(-402, 8, -95.5),
			subject = mountain(-409.5, 1.5, -104.5),
			width = 14,
		},
	}
end

-- Narración y cartel final del reel: tres frases en la esquina de abajo a la izquierda y la última arriba, con el
-- nombre del juego bajo en la zona segura.
local function addPetsReelText(events: EventList)
	local function narration(t: number, text: string, corner: string, seconds: number)
		table.insert(
			events,
			{ t = t, kind = "bubble", balloon = "narration", corner = corner, text = text, seconds = seconds }
		)
	end
	narration(3.1, PET_CAPTIONS.jungle, "BL", 2.1)
	narration(5.6, PET_CAPTIONS.mangrove, "BL", 3)
	narration(10, PET_CAPTIONS.mountain, "BL", 2.8)
	narration(13.1, PET_CAPTIONS.title, "TL", 1.8)
	addReelTitle(events, 13.3)
end

-- Pets_Comic (G7c): los 15 s de Pets_Reel (mismos eventos) montados como páginas de cómic con viñetas (Comic, modo
-- página). Cada corte da a la vez la cámara, la página (si abre una) y la viñeta que se activa, sin desfase:
--    0 a 2,45    P1 montaje 3×2 (grid6), seis viñetas de ~0,4 s en la jungla, en amarillo cómic
--    2,5 a 5,35  P2 jungla (four_a), 4 viñetas de ~0,7 s: salto del Jaguar de Cristal, la pata, el avatar, el grupo
--    5,4 a 9,9   P3 manglar (four_b), 4 viñetas de ~1,1 s: llega la manada, mordiscos, cenital, el alfa cae
--    9,9 a 13,1  P4 montaña (four_c), 4 viñetas de ~0,8 s: el Quetzal despega y planea sobre la cámara
--   13,15 a 15   P5 cartel (single): el grupo en lo alto, «Tus mascotas, tu manada», logo y fundido
-- Paleta cálida SIN verde (el verde es la curación): amarillo, ocre y mostaza, turquesa y crema, terracota y lila.
-- Las posiciones salen de petsReelCuts y de petsCamera, con el ancho cambiado al de la viñeta; son de diseño.
local COMIC_COLORS = {
	montage = { Color3.fromRGB(255, 222, 89), Color3.fromRGB(240, 178, 40) }, -- amarillo cómic
	jungle = { Color3.fromRGB(232, 184, 64), Color3.fromRGB(190, 120, 40) }, -- mostaza y ocre
	mangrove = { Color3.fromRGB(64, 190, 196), Color3.fromRGB(246, 232, 196) }, -- turquesa y crema
	mountain = { Color3.fromRGB(205, 104, 70), Color3.fromRGB(176, 140, 200) }, -- terracota y lila
}

type ComicCell = {
	t0: number,
	t1: number,
	pos: Vector3,
	subject: Vector3,
	width: number, -- studs que llenan el ancho de la viñeta
	bg: string, -- "flat" | "dots" (el fondo de la viñeta cuando se congela)
	posB: Vector3?,
	subjectB: Vector3?,
	widthB: number?, -- ancho al final del plano (por defecto, el 90 % del inicial)
}

type ComicCut = {
	t0: number,
	t1: number,
	layout: string, -- id de Comic.PAGES (ComicPages)
	page: { layout: string, colors: { Color3 }, wipe: string? }?, -- solo en la primera viñeta de cada página
	cell: number, -- índice de la viñeta en la plantilla
	pos: Vector3,
	posB: Vector3?,
	subject: Vector3,
	subjectB: Vector3?,
	width: number,
	widthB: number?,
	bg: string,
}

local function comicCell(
	t0: number,
	t1: number,
	pos: Vector3,
	subject: Vector3,
	width: number,
	bg: string,
	subjectB: Vector3?
): ComicCell
	return { t0 = t0, t1 = t1, pos = pos, subject = subject, width = width, bg = bg, subjectB = subjectB }
end

-- El cartel final del cómic ve al grupo de frente: justo antes de la última página (la cámara mira hacia otro sitio)
-- todos se dan la vuelta hacia el sur. En Pets_Reel y Pets siguen de espaldas a la cámara, mirando la pared.
local function petsComicTurn(w: PetWriter)
	for _, name in PET_ALL do
		local at = PET_SUMMIT[name]
		w.put(13.12, name, at.pos, at.yaw + 180)
	end
end

local function petsComicCuts(): { ComicCut }
	local lift = Vector3.new(0, Q_BODY_LIFT, 0)
	local cuts: { ComicCut } = {}
	-- `order`: qué viñeta de la plantilla enseña cada plano, en orden de tiempo. Las páginas de cuatro empiezan por la
	-- grande (la 4): así no queda medio cuadro vacío mientras pasan las pequeñas.
	local BIG_FIRST = { 4, 1, 2, 3 }
	local function addPage(layout: string, colors: { Color3 }, wipe: string?, cells: { ComicCell }, order: { number }?)
		for index, c in cells do
			table.insert(cuts, {
				t0 = c.t0,
				t1 = c.t1,
				layout = layout,
				page = if index == 1 then { layout = layout, colors = colors, wipe = wipe } else nil,
				cell = if order then order[index] else index,
				pos = c.pos,
				posB = c.posB,
				subject = c.subject,
				subjectB = c.subjectB,
				width = c.width,
				bg = c.bg,
			})
		end
	end
	-- P1: montaje de la jungla (los cuatro primeros encuadres medidos de Pets, el salto y el plano general).
	addPage("grid6", COMIC_COLORS.montage, nil, {
		comicCell(0, 0.41, Vector3.new(-24.6, 15, 267.4), Vector3.new(-23.5, 14.9, 272), 4, "flat"),
		comicCell(0.41, 0.82, Vector3.new(-33, 16.8, 268.6), Vector3.new(-31, 13.8, 264.9), 5, "dots"),
		comicCell(0.82, 1.22, Vector3.new(-31.8, 14.4, 277.4), Vector3.new(-26.4, 13.9, 272.4), 6.5, "flat"),
		comicCell(1.22, 1.63, Vector3.new(-32, 17.7, 272), Vector3.new(-24, 15.2, 272), 9, "dots"),
		comicCell(1.63, 2.04, jungle(-27.5, 2.4, 279), Vector3.new(-27.7, 14.8, 269.2), 7, "flat"),
		comicCell(2.04, 2.45, jungle(-8, 3.2, 286.5), jungle(-26.5, 1.2, 270.5), 16, "dots"),
	})
	-- P2: jungla. El Jaguar de Cristal salta (2,45), el Labrador da la pata (2,9), el avatar se agacha, el grupo.
	addPage("four_a", COMIC_COLORS.jungle, "left", {
		comicCell(2.5, 3.2, jungle(-21, 2.4, 279), Vector3.new(-29, 13.9, 268.8), 15, "flat"),
		comicCell(3.2, 3.9, jungle(-22.4, 2.2, 277), jungle(-23.6, 1.3, 272), 4.5, "dots"),
		comicCell(3.9, 4.6, jungle(-14, 2.6, 278), jungle(-24, 1.4, 272), 9, "flat"),
		comicCell(4.6, 5.35, jungle(-12, 3, 283), jungle(-26.5, 1.2, 270.5), 13, "dots"),
	}, BIG_FIRST)
	-- P3: manglar. La manada llega (6,7), mordiscos y zarpazos (7,1 a 8,6), la capibara embiste y el alfa cae (9,7).
	addPage("four_b", COMIC_COLORS.mangrove, "left", {
		-- Plano general desde más alto y más lejos (396, 21, 561): el de (394, 17.5, 565) caía entre raíces rojas.
		comicCell(5.4, 6.5, Vector3.new(396, 21, 561), mangrove(378, 1, 543), 30, "flat"),
		comicCell(6.5, 7.5, mangrove(388, 2.2, 556), mangrove(379.5, 1, 543), 12, "dots"),
		comicCell(7.5, 8.6, Vector3.new(381, 24, 553), Vector3.new(376, 14.6, 542), 14, "flat"),
		comicCell(8.6, 9.9, mangrove(391, 1.9, 530), mangrove(382, 2, 542), 14, "dots"),
	}, BIG_FIRST)
	-- P4: montaña. El Quetzal despega (10,1), planea y pasa sobre la cámara (11,4 a 13).
	addPage("four_c", COMIC_COLORS.mountain, "down", {
		comicCell(9.9, 10.7, mountain(-403, 6, -89.5), Q_FROM + lift, 10, "flat", quetzalAt(10.7, 10.1, 2.1) + lift),
		comicCell(
			10.7,
			11.5,
			mountain(-403, 6, -89.5),
			quetzalAt(10.7, 10.1, 2.1) + lift,
			7,
			"dots",
			quetzalAt(11.5, 10.1, 2.1) + lift
		),
		comicCell(
			11.5,
			12.3,
			PET_OVERHEAD_CAM,
			quetzalAt(11.5, 10.1, 2.1) + lift,
			12,
			"flat",
			quetzalAt(12.3, 10.1, 2.1) + lift
		),
		comicCell(
			12.3,
			13.1,
			PET_OVERHEAD_CAM,
			quetzalAt(12.3, 10.1, 2.1) + lift,
			12,
			"dots",
			quetzalAt(13, 10.1, 2.1) + lift
		),
	}, BIG_FIRST)
	-- P5: cartel. El grupo en lo alto, de cara a la pared (el avatar señala a 13,4).
	addPage("single", COMIC_COLORS.mountain, "left", {
		-- De frente (el grupo se da la vuelta a 13,12, ver petsComicTurn) y a su altura, con la pared de roca detrás: la
		-- cámara (-405,2, 25, -91,3) mide 15 studs hasta el grupo sin nada en medio y el suelo a 21.
		comicCell(
			13.15,
			PETS_REEL_SECONDS,
			Vector3.new(-405.2, 25, -91.3),
			Vector3.new(-410, 23.2, -104.5),
			11,
			"flat"
		),
	})
	return cuts
end

-- Los planos de la cámara de los cortes de cómic: empuje lento hacia el sujeto (6 %) y un poco más cerrado al final.
local function comicShots(cuts: { ComicCut }): { CameraShot }
	local shots: { CameraShot } = {}
	for _, cut in cuts do
		local cx, cy, cellW, cellH = ComicPages.cellCenter(cut.layout, cut.cell)
		local subjectB = cut.subjectB or cut.subject
		local posB = cut.posB or cut.pos:Lerp(subjectB, 0.06)
		table.insert(shots, {
			t0 = cut.t0,
			t1 = cut.t1,
			a = pageKey(cut.pos, cut.subject, cut.width, cx, cy, cellW, cellH),
			b = pageKey(posB, subjectB, cut.widthB or cut.width * 0.9, cx, cy, cellW, cellH),
		})
	end
	return shots
end

-- La capa cómic de página: el evento `page` en la primera viñeta de cada página y el `cell` de cada corte.
local function addComicPages(events: EventList, cuts: { ComicCut })
	for _, cut in cuts do
		local page = cut.page
		if page then
			table.insert(
				events,
				{ t = cut.t0, kind = "page", layout = page.layout, colors = page.colors, wipe = page.wipe }
			)
		end
		table.insert(events, { t = cut.t0, kind = "cell", index = cut.cell, bg = cut.bg })
	end
end

-- Narración, bocadillos del avatar y onomatopeyas de Pets_Comic, con los tiempos de petsReelEvents. Las mascotas no
-- hablan; el avatar sí, con frases cortas. Las onomatopeyas van dentro de la viñeta viva (ComicPages.cellPoint).
local function addPetsComicText(events: EventList)
	-- Narración pegada a una esquina de la página: en la viñeta grande de abajo, que aún está vacía mientras pasan las
	-- otras tres.
	local function narration(t: number, text: string, corner: string, seconds: number)
		table.insert(events, {
			t = t,
			kind = "bubble",
			balloon = "narration",
			corner = corner,
			onPage = true,
			text = text,
			seconds = seconds,
		})
	end
	local function speech(t: number, text: string, seconds: number)
		table.insert(
			events,
			{ t = t, kind = "bubble", balloon = "speech", actor = "avatar", text = text, seconds = seconds }
		)
	end
	local function sfx(t: number, text: string, layout: string, cell: number, fx: number, fy: number, rot: number)
		table.insert(events, {
			t = t,
			kind = "sfx",
			text = text,
			pos = ComicPages.cellPoint(layout, cell, fx, fy),
			rot = rot,
			size = 0.3,
			color = Color3.new(1, 1, 1),
			seconds = 0.6,
		})
	end
	narration(2.8, PET_CAPTIONS.jungle, "BL", 2.4)
	narration(5.65, PET_CAPTIONS.mangrove, "BL", 2.8)
	narration(10.2, PET_CAPTIONS.mountain, "BL", 2.7)
	speech(3.95, Strings.later("¡Buen chico!"), 0.65)
	speech(6, Strings.later("¡A por ellos!"), 0.9)
	speech(13.25, Strings.later("¡Mira!"), 0.8)
	sfx(3.3, Strings.later("¡GUAU!"), "four_a", 1, 0.62, 0.28, -12) -- el Labrador da la pata (GivePaw desde 2,9)
	sfx(7.6, Strings.later("¡ÑAM!"), "four_b", 2, 0.25, 0.3, -14) -- mordiscos (caen a 7,55 y 7,75)
	sfx(8.95, Strings.later("¡ZAS!"), "four_b", 3, 0.75, 0.25, 12) -- zarpazos del Jaguar de Cristal y el Ocelote (8,95 y 9,15)
	sfx(9.7, Strings.later("¡PUF!"), "four_b", 3, 0.3, 0.7, -10) -- el alfa cae (9,7)
	sfx(10.35, Strings.later("¡FIUU!"), "four_c", 4, 0.35, 0.3, 14) -- el Quetzal despega (10,1)
	-- Cartel final en la viñeta única: título, logo del juego y fundido a negro.
	table.insert(events, { t = 13.7, kind = "title", text = PET_CAPTIONS.title, seconds = 0.8 })
	table.insert(events, {
		t = 14.5,
		kind = "logo",
		text = Strings.later("Primal Banana Islands"),
		sub = Strings.later("Monkey Survival"),
		seconds = 0.5,
	})
	table.insert(events, { t = 14.6, kind = "fade", seconds = 0.4, toBlack = true })
end

-- `variant`: "normal" (40 s, con bandas), "reel" (15 s, ventana alta 9:16) o "comic" (15 s, páginas con viñetas).
local function petsScene(variant: string): Scene
	local reel = variant == "reel"
	local comic = variant == "comic"
	local events: EventList = {}
	local w = petWriter(events)
	local camera: { CameraPoint }
	if comic then
		petsReelEvents(w)
		petsComicTurn(w)
		local cuts = petsComicCuts()
		camera = cutShots(comicShots(cuts))
		addComicPages(events, cuts)
		addPetsComicText(events)
	elseif reel then
		petsReelEvents(w)
		local cuts = petsReelCuts()
		camera = cutShots(battleReelShots(cuts))
		addReelPanels(events, cuts, Color3.fromRGB(190, 122, 44), Color3.fromRGB(246, 232, 196))
		addPetsReelText(events)
		addBattleFade(events, true, PETS_REEL_SECONDS)
	else
		petsFullEvents(w)
		camera = petsCamera()
		table.insert(events, { t = 0, kind = "letterbox" })
		table.insert(events, { t = 4.3, kind = "caption", text = PET_CAPTIONS.jungle, seconds = 3.2 })
		table.insert(events, { t = 14.4, kind = "caption", text = PET_CAPTIONS.mangrove, seconds = 3.6 })
		table.insert(events, { t = 27.4, kind = "caption", text = PET_CAPTIONS.mountain, seconds = 3.6 })
		-- Cartel final, logo del juego y fundido a negro.
		table.insert(events, { t = 37, kind = "title", text = PET_CAPTIONS.title, seconds = 1.6 })
		table.insert(events, {
			t = 38.6,
			kind = "logo",
			text = Strings.later("Primal Banana Islands"),
			sub = Strings.later("Monkey Survival"),
			seconds = 1,
		})
		table.insert(events, { t = 39.2, kind = "fade", seconds = 0.8, toBlack = true })
	end
	local petIds: { string } = {}
	for _, species in PET_SPECIES do
		table.insert(petIds, species)
	end
	-- Los monos reales de la isla (ardillas y capuchinos a 70-100 studs del claro de la jungla) se esconden en los tres
	-- sitios mientras dura la escena; por eso lleva freeze: sin él, atacarían al avatar sin verse.
	table.insert(events, {
		t = 0,
		kind = "hideEnemies",
		server = true,
		centers = { JUNGLE_AVATAR, PET_LINE.avatar.pos, PET_CLIMB_START.avatar.pos },
		radius = 200,
	})
	return {
		duration = if reel or comic then PETS_REEL_SECONDS else PETS_SECONDS,
		audience = "Self",
		freeze = true,
		skippable = true,
		hour = PETS_HOUR,
		streamFollowsCamera = true,
		-- El claro de la jungla (donde empieza la escena) con su terreno cargado antes de poner a nadie.
		waitTerrain = { JUNGLE_AVATAR, PET_JUNGLE.beagle.pos, PET_JUNGLE.labrador.pos },
		-- Las mallas de las siete mascotas, cargadas antes de construirlas (PetActor.build espera si no).
		prepare = function()
			PetActor.preloadAll(petIds)
			return camera
		end,
		actors = petsActors(),
		camera = camera,
		events = events,
	}
end

-- Monturas (Fase 25, G8a; 20 s): la Llama Andina, el Jaguar Albino Esmeralda y el Quetzalcóatl, cada uno con el avatar del
-- jugador montado, en tres sitios de la isla (coordenadas del MUNDO, anchor = CFrame.identity). Solo para grabar (orden
-- «🐎 Monturas»). Los sitios están medidos con rayos en el Studio de la Isla: PLAYA, la arena baja hacia el mar (+Z); JUNGLA,
-- el claro llano de PET_JUNGLE; MONTAÑA, el banco (-410, 21, -100) con la falda que baja hacia el este y el vacío desde x = -350.
-- Lo marcado «a medir» no se pudo comprobar sin Studio: las tomas de cámara de MOUNT_SHOTS son un primer borrador.
--
-- Línea de tiempo (segundos):
--    0 a 3,5   Montaje de 6 cortes en la jungla (cabeza de la Llama, ojos del Jaguar, penacho del Quetzalcóatl, la silla
--              por detrás, cenital y plano general). Las tres monturas esperan en fila, en Idle, a 6 studs entre sí: es lo
--              más simple (un solo sitio, sin teletransportes entre cortes); al acabar, cada una salta a su sitio con `move`.
--  3,5 a 8    PLAYA: la Llama galopa paralela a la orilla, salta y se para a escupir a la cámara
--    8 a 12,5 JUNGLA: el Jaguar corre y salta; a los 9,65 corte a una cámara fija al final de su recorrido, a la que llega
--              de frente y para a ~6,6 studs: primer plano de la cara y el pecho, y rugido con sacudida
-- 12,5 a 17,5 MONTAÑA: el Quetzalcóatl baja corriendo de frente hacia la cámara (sobre la roca de la ladera, x -414), salta,
--              pasa por encima y se aleja planeando por el valle con la cámara siguiéndolo
-- 17,5 a 20   cartel «Elige tu montura», logo y fundido a negro
-- Las monturas que no salen en pantalla se aparcan en y = -400 (como el final del Sobrevuelo).
local MOUNTS_SECONDS = 20
local MOUNTS_HOUR = 17.5 -- atardecer dorado, como el Sobrevuelo y las mascotas
local MOUNT_PARK = Vector3.new(0, -400, 0)
local MOUNT_ROW_YAW = -90 -- el montaje las deja mirando al este
local MOUNT_ROW = {
	Llama = Vector3.new(-25, 12.7, 266),
	Jaguar = Vector3.new(-25, 12.7, 272),
	Quetzalcoatl = Vector3.new(-25, 12.7, 278),
}
-- PLAYA: la Llama galopa por x -70 a 0 (mirando +X) a z = 925; la cámara va por el lado del mar (+Z).
local BEACH_FROM = Vector3.new(-70, 4.8, 925)
local BEACH_TO = Vector3.new(0, 4.8, 925)
-- JUNGLA: el Jaguar corre por el claro de PET_JUNGLE (sin árboles entre x -55 y 5) mirando +X.
local JUNGLE_RUN_FROM = Vector3.new(5, 12.7, 272)
local JUNGLE_RUN_TO = Vector3.new(-39, 12.7, 272) -- el Jaguar corre hacia -X y se para a ~6,6 studs de la cámara fija (en x -49)
-- MONTAÑA (rehecha tras el vídeo del 07-11-2026: el sitio anterior era la zanja de un río y la cámara quedaba debajo): la
-- ladera de la montaña, mirando al norte. Línea libre de árboles en x ≈ -414 (medida con rayos): el suelo va de y 51 en
-- z -194 a y 31 en z -148 (unos 25°) y sigue hasta y 22 en z -98. La cámara está sobre la roca desnuda (x -409,5, z -128, y 29):
-- la hierba (~3 studs) solo crece donde el suelo es césped (más al sur) y, a menos de ~8 studs de altura, tapaba al
-- Quetzalcóatl. Baja corriendo de frente hacia ella, salta y pasa por encima; después la cámara lo sigue por la espalda
-- mientras planea hacia el sur sobre el valle y la isla (el sol está al oeste, a ~7°, a la derecha de esa vista).
-- Puntos de la bajada: { z, y del suelo, t }.
local MOUNTAIN_X = -414
local MOUNTAIN_RUN = {
	{ z = -194, y = 51, t = 12.5 },
	{ z = -182, y = 46.4, t = 12.95 },
	{ z = -170, y = 40.8, t = 13.45 },
	{ z = -158, y = 35.6, t = 13.95 },
	{ z = -148, y = 31.2, t = 14.4 },
}
local MOUNTAIN_RUN_START = 12.5
local MOUNTAIN_LEAP_AT = 14.4 -- salta
local MOUNTAIN_GLIDE_AT = 15.3 -- planea
local MOUNTAIN_GLIDE_END = 17 -- el Quetzalcóatl se queda flotando (Idle) y siseando en MOUNTAIN_GLIDE_TO
local MOUNTAIN_LEAP_TO = Vector3.new(MOUNTAIN_X, 41, -126)
local MOUNTAIN_GLIDE_TO = Vector3.new(MOUNTAIN_X, 37, -82) -- por encima de las copas de la colina (~32)
-- Cámara del plano final: más al sur y al este del punto donde flota, de modo que lo ve de TRES CUARTOS por delante (él mira al
-- sur; la cámara queda a ~31° de su frente) con el cielo detrás, a la altura de las copas para que no las tenga delante.
local MOUNTAIN_FINAL_CAMERA = Vector3.new(-401.5, 33, -61)
local MOUNTAIN_CUT = 16.35 -- corte de la cámara de la roca a la del plano final
local MOUNTAIN_FINAL_LIFT = 3 -- hacia dónde apunta la cámara final sobre el cuerpo (más que MOUNT_BODY_LIFT: lo baja en el cuadro)
local MOUNTAIN_CAMERA = Vector3.new(-409.5, 29, -128)
local MOUNTAIN_CENTER = Vector3.new(MOUNTAIN_X, 30, -150) -- para hideEnemies y waitTerrain
local MOUNT_BODY_LIFT = 1.5 -- de los pies al centro del cuerpo, adonde mira la cámara en el planeo
local MOUNT_CAPTION_SECONDS = 2.6

-- Fotogramas clave del Quetzalcóatl en la montaña: { t, pos (pies), pitch }. De ellos salen los `move` y la mirada de la cámara.
-- En la bajada el cuerpo sigue la pendiente (pitch negativo: morro abajo).
local function mountainKeys(): { { t: number, pos: Vector3, pitch: number } }
	local function pitchOf(from: Vector3, to: Vector3): number
		return math.deg(math.atan((to.Y - from.Y) / Vector3.new(to.X - from.X, 0, to.Z - from.Z).Magnitude))
	end
	local keys = {}
	for _, point in MOUNTAIN_RUN do
		table.insert(keys, { t = point.t, pos = Vector3.new(MOUNTAIN_X, point.y, point.z), pitch = 0 })
	end
	for i = 2, #keys do
		keys[i].pitch = pitchOf(keys[i - 1].pos, keys[i].pos)
	end
	keys[1].pitch = keys[2].pitch
	local runEnd = keys[#keys].pos
	table.insert(keys, { t = MOUNTAIN_GLIDE_AT, pos = MOUNTAIN_LEAP_TO, pitch = pitchOf(runEnd, MOUNTAIN_LEAP_TO) })
	table.insert(
		keys,
		{ t = MOUNTAIN_GLIDE_END, pos = MOUNTAIN_GLIDE_TO, pitch = pitchOf(MOUNTAIN_LEAP_TO, MOUNTAIN_GLIDE_TO) }
	)
	return keys
end

-- Dónde están los pies del Quetzalcóatl en el segundo t (lineal entre fotogramas clave).
local function mountainQuetzalAt(keys: { { t: number, pos: Vector3, pitch: number } }, t: number): Vector3
	if t <= keys[1].t then
		return keys[1].pos
	end
	for i = 2, #keys do
		if t <= keys[i].t then
			local a, b = keys[i - 1], keys[i]
			return a.pos:Lerp(b.pos, (t - a.t) / (b.t - a.t))
		end
	end
	return keys[#keys].pos
end

-- Tomas de cámara con nombre (pos, look y fov a mano, para afinarlas en Studio). Las del montaje (jungla, con las monturas
-- en MOUNT_ROW) son `still` de una duración fija; el resto son un par { a, b } para pushShot (de dónde a dónde).
-- Los primeros planos van a ~4,5 studs y la cámara de la montaña a >= 5 studs sobre el suelo.
local MOUNT_SHOTS = {
	-- MONTAJE (3,45 s): cada corte con su seguimiento mínimo.
	llamaHead = still(
		Vector3.new(-19.4, 18.7, 262.6),
		Vector3.new(-23.2, 18.3, 266),
		0.5,
		40,
		Vector3.new(-20, 18.7, 263.1)
	),
	jaguarEyes = still(
		Vector3.new(-14.5, 16.7, 276),
		Vector3.new(-21.3, 16.1, 272),
		0.5,
		36,
		Vector3.new(-15.2, 16.7, 275.5)
	),
	quetzalCrest = still(
		Vector3.new(-11.5, 18, 281.8),
		Vector3.new(-19, 17.1, 278),
		0.55,
		42,
		Vector3.new(-12.2, 18, 281.4)
	),
	saddleBehind = CameraPath.behind(Vector3.new(-25, 17.5, 266), MOUNT_ROW_YAW, 7.5, 2.6, 0, 0.6, 52),
	topDown = CameraPath.zenith(Vector3.new(-25, 12.7, 272), 14, 0, 0.55, 60),
	wide = still(jungle(-6, 3.2, 290), jungle(-25, 1.5, 272), 0.5, 62, jungle(-8, 3.2, 288.5)),
	-- PLAYA: la cámara por el lado de tierra (z 903), mirando al mar con la Llama delante; la mirada sigue a la Llama
	-- (corre de x -70 a 0 en 3,2 s) y el mar queda al fondo. Luego, de frente a la Llama que escupe.
	beachGallop = {
		a = shot(Vector3.new(-64, 9.4, 909), Vector3.new(-69, 6.9, 925), 48),
		b = shot(Vector3.new(-6, 9.4, 909), Vector3.new(-3, 6.9, 925), 46),
	},
	beachSpit = {
		a = shot(Vector3.new(1.5, 8.6, 918.5), Vector3.new(0, 8.2, 925), 44),
		b = shot(Vector3.new(1, 8.5, 919.2), Vector3.new(0, 8.2, 925), 42),
	},
	-- JUNGLA: lateral desde el sur siguiendo la carrera (el Jaguar va de x 5 a -39, hacia -X); luego una cámara FIJA al
	-- final del recorrido (x -49, a la altura de su cara, mirando a +X): el Jaguar llega corriendo de frente hasta
	-- ~6,6 studs (su cabeza queda en x ≈ -42,4) y ruge, para enseñar la cara, el pecho y las patas delanteras.
	jungleRun = {
		a = shot(jungle(3, 2.4, 286), jungle(5, 2.4, 272), 50),
		b = shot(jungle(-21, 2.4, 286), jungle(-23, 2.4, 272), 48),
	},
	jungleFront = {
		a = shot(jungle(-49, 2.6, 272), jungle(-42.4, 2.9, 272), 40),
		b = shot(jungle(-49, 2.6, 272), jungle(-42.4, 2.9, 272), 40),
	},
	-- MONTAÑA: la cámara de la roca (MOUNTAIN_CAMERA) sigue al Quetzalcóatl (ver mountsCamera): baja corriendo de frente,
	-- salta, pasa por encima y se aleja planeando. A MOUNTAIN_CUT corte a la cámara del plano final (MOUNTAIN_FINAL_CAMERA),
	-- que lo ve llegar y quedarse flotando de tres cuartos por delante; el plano final lo mantiene ahí, con un leve acercamiento.
	finale = {
		a = shot(MOUNTAIN_FINAL_CAMERA, MOUNTAIN_GLIDE_TO + Vector3.new(0, MOUNTAIN_FINAL_LIFT, 0), 52),
		b = shot(Vector3.new(-404, 32.5, -65), MOUNTAIN_GLIDE_TO + Vector3.new(0, MOUNTAIN_FINAL_LIFT, 0), 46),
	},
}

local function mountsCamera(keys: { { t: number, pos: Vector3, pitch: number } }): { CameraPoint }
	local shots = MOUNT_SHOTS
	local camera = (
		CameraPath.montage({
			shots.llamaHead,
			shots.jaguarEyes,
			shots.quetzalCrest,
			shots.saddleBehind,
			shots.topDown,
			shots.wide,
		}) :: any
	) :: { CameraPoint }
	pushShot(camera, 3.5, 6.65, shots.beachGallop.a, shots.beachGallop.b)
	pushShot(camera, 6.7, 7.95, shots.beachSpit.a, shots.beachSpit.b)
	pushShot(camera, 8, 9.6, shots.jungleRun.a, shots.jungleRun.b)
	pushShot(camera, 9.65, 12.35, shots.jungleFront.a, shots.jungleFront.b)
	-- Montaña: cámara fija en el pie de la ladera y mirada siguiendo al Quetzalcóatl (se muestrea cada 0,3 s, como el
	-- planeo de las mascotas). El fov se abre de 46 a 60 entre 13,5 y 15,5 s: de la bajada de frente al paso por encima.
	local function mountainPoint(t: number, pos: Vector3, fov: number, lift: number): CameraPoint
		local look = mountainQuetzalAt(keys, t) + Vector3.new(0, lift, 0)
		return { t = t, pos = pos, look = look, fov = fov }
	end
	-- Cámara de la roca hasta MOUNTAIN_CUT - 0,05; después la del plano final, siguiendo al Quetzalcóatl hasta que se para.
	local function follow(from: number, to: number, pos: Vector3, lift: number, fovAt: (number) -> number)
		local steps = math.max(1, math.ceil((to - from) / 0.3))
		table.insert(camera, mountainPoint(from - 0.001, pos, fovAt(from), lift))
		for i = 0, steps do
			local t = from + (to - from) * i / steps
			table.insert(camera, mountainPoint(t, pos, fovAt(t), lift))
		end
		table.insert(camera, mountainPoint(to + 0.001, pos, fovAt(to), lift))
	end
	follow(12.4, MOUNTAIN_CUT - 0.05, MOUNTAIN_CAMERA, MOUNT_BODY_LIFT, function(t)
		return 46 + 14 * math.clamp((t - 13.5) / 2, 0, 1)
	end)
	follow(MOUNTAIN_CUT, MOUNTAIN_GLIDE_END, MOUNTAIN_FINAL_CAMERA, MOUNTAIN_FINAL_LIFT, function()
		return 52
	end)
	pushShot(camera, MOUNTAIN_GLIDE_END + 0.05, MOUNTS_SECONDS, shots.finale.a, shots.finale.b)
	return camera
end

-- Altura de la raíz de la montura sobre su pieza más baja (sin el jinete): el actor `prop` no tiene snap al suelo, así que
-- se guarda como CinematicLift y el evento `move` la suma a la Y del suelo que le damos. Se mide al construir, con la pose
-- de reposo (a medir en Studio: en carrera las patas pueden bajar o subir algo).
local function mountLift(model: Model): number
	local root = model.PrimaryPart
	if not root then
		return 0
	end
	local rider = model:FindFirstChild("Jinete")
	local lowest = math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and not (rider and part:IsDescendantOf(rider)) then
			local cf, size = part.CFrame, part.Size
			local half = (
				math.abs(cf.RightVector.Y) * size.X
				+ math.abs(cf.UpVector.Y) * size.Y
				+ math.abs(cf.LookVector.Y) * size.Z
			) / 2
			lowest = math.min(lowest, cf.Position.Y - half)
		end
	end
	if lowest == math.huge then
		return 0
	end
	return math.clamp(root.Position.Y - lowest, 0, 10)
end

-- Actor `prop` de una montura con el avatar del jugador montado, en Idle y en su sitio del montaje.
local function mountActor(mountId: string): { [string]: any }
	return {
		kind = "prop",
		build = function()
			local Players = game:GetService("Players")
			local model = MountedRider.build(mountId, Players.LocalPlayer.Character, { pose = "Idle" })
			assert(model, `Monturas: no se pudo construir la montura {mountId}`)
			local lift = mountLift(model)
			model:SetAttribute("CinematicLift", lift)
			model:PivotTo(
				CFrame.new(MOUNT_ROW[mountId] + Vector3.new(0, lift, 0)) * CFrame.Angles(0, math.rad(MOUNT_ROW_YAW), 0)
			)
			return model
		end,
	}
end

local MOUNTS_REEL_SECONDS = 15
local MOUNTS_TITLE = Strings.later("Elige tu montura")

-- Los cortes de Mounts_Reel (9:16): los de la escena completa con los tiempos × 0,75 (MOUNTS_REEL_SECONDS / MOUNTS_SECONDS).
-- Posiciones de diseño: a medir en Studio. En la montaña la mirada sigue al Quetzalcóatl (mountainQuetzalAt con el tiempo
-- de la escena completa, t / K).
local function mountsReelCuts(keys: { { t: number, pos: Vector3, pitch: number } }): { ReelCut }
	local k = MOUNTS_REEL_SECONDS / MOUNTS_SECONDS
	local bodyLift = Vector3.new(0, MOUNT_BODY_LIFT, 0)
	local finalLift = Vector3.new(0, MOUNTAIN_FINAL_LIFT, 0)
	local function quetzal(t: number, lift: Vector3): Vector3
		return mountainQuetzalAt(keys, t / k) + lift
	end
	return {
		-- Montaje: las tres monturas en fila (seis cortes de ~0,43 s).
		{
			t0 = 0,
			t1 = 0.43,
			shape = "reelTall",
			bg = "speed",
			pos = Vector3.new(-19.4, 18.7, 262.6),
			subject = Vector3.new(-23.2, 18.3, 266),
			width = 4.5,
		},
		{
			t0 = 0.43,
			t1 = 0.86,
			shape = "reelDiagR",
			bg = "halftone",
			pos = Vector3.new(-14.5, 16.7, 276),
			subject = Vector3.new(-21.3, 16.1, 272),
			width = 5,
		},
		{
			t0 = 0.86,
			t1 = 1.29,
			shape = "reelSlant",
			bg = "flat",
			pos = Vector3.new(-11.5, 18, 281.8),
			subject = Vector3.new(-19, 17.1, 278),
			width = 7.5,
		},
		{
			t0 = 1.29,
			t1 = 1.72,
			shape = "reelDiagL",
			bg = "speed",
			pos = Vector3.new(-32.5, 20.1, 266), -- la silla por detrás
			subject = Vector3.new(-25, 17.5, 266),
			width = 7,
		},
		{
			t0 = 1.72,
			t1 = 2.15,
			shape = "reelTop", -- cenital
			bg = "halftone",
			pos = Vector3.new(-25, 26.7, 272),
			subject = Vector3.new(-25, 12.7, 272),
			width = 12,
		},
		{
			t0 = 2.15,
			t1 = 2.59,
			shape = "reelTall",
			bg = "flat",
			pos = jungle(-6, 3.2, 290),
			subject = jungle(-25, 1.5, 272),
			width = 18,
		},
		-- Playa: la Llama galopa por la orilla y escupe a la cámara.
		{
			t0 = 2.62,
			t1 = 4.95,
			shape = "reelSlant",
			bg = "speed",
			pos = Vector3.new(-35, 9.4, 909),
			subject = Vector3.new(-69, 6.9, 925),
			subjectB = Vector3.new(-3, 6.9, 925),
			width = 14,
		},
		{
			t0 = 4.95,
			t1 = 5.96,
			shape = "reelTall",
			bg = "halftone",
			pos = Vector3.new(1.5, 8.6, 918.5),
			subject = Vector3.new(0, 8.2, 925),
			width = 5,
		},
		-- Selva: el Jaguar corre y, al final, llega de frente a la cámara fija.
		{
			t0 = 5.97,
			t1 = 7.4,
			shape = "reelDiagL",
			bg = "flat",
			pos = Vector3.new(-18, 15.4, 286),
			subject = Vector3.new(5, 15.4, 272),
			subjectB = Vector3.new(-22, 15.4, 272),
			width = 14,
		},
		{
			t0 = 7.45,
			t1 = 9.26,
			shape = "reelDiagR",
			bg = "speed",
			pos = Vector3.new(-49, 15.6, 272),
			subject = Vector3.new(-42.4, 15.9, 272),
			width = 5.5,
		},
		-- Montaña: el Quetzalcóatl baja de frente, salta y planea hasta quedarse flotando.
		{
			t0 = 9.3,
			t1 = 10.8,
			shape = "reelTall",
			bg = "halftone",
			pos = MOUNTAIN_CAMERA,
			subject = quetzal(9.3, bodyLift),
			subjectB = quetzal(10.8, bodyLift),
			width = 16,
		},
		{
			t0 = 10.85,
			t1 = 11.75,
			shape = "reelDiagR",
			bg = "speed",
			pos = MOUNTAIN_CAMERA,
			subject = quetzal(10.85, bodyLift),
			subjectB = quetzal(11.75, bodyLift),
			width = 14,
		},
		{
			t0 = 11.8,
			t1 = 12.75,
			shape = "reelSlant",
			bg = "flat",
			pos = MOUNTAIN_FINAL_CAMERA,
			subject = quetzal(11.8, finalLift),
			subjectB = quetzal(12.75, finalLift),
			width = 18,
		},
		{
			t0 = 12.8,
			t1 = MOUNTS_REEL_SECONDS,
			shape = "reelDiagL",
			bg = "halftone",
			pos = MOUNTAIN_FINAL_CAMERA,
			subject = MOUNTAIN_GLIDE_TO + finalLift,
			width = 16,
		},
	}
end

-- Narración y cartel final del reel: el nombre de cada montura abajo a la izquierda al empezar su tramo, el título
-- arriba y el nombre del juego bajo en la zona segura.
local function addMountsReelText(events: EventList)
	local function narration(t: number, text: string, corner: string, seconds: number)
		table.insert(
			events,
			{ t = t, kind = "bubble", balloon = "narration", corner = corner, text = text, seconds = seconds }
		)
	end
	narration(2.62, Mounts.Llama.name, "BL", 2.4)
	narration(5.97, Mounts.Jaguar.name, "BL", 2.4)
	narration(9.3, Mounts.Quetzalcoatl.name, "BL", 2.4)
	narration(13.1, MOUNTS_TITLE, "TL", 1.8)
	addReelTitle(events, 13.3)
end

-- Los cortes de Mounts_Comic (G8b): la misma escena en páginas con viñetas (tiempos × 0,75, como Mounts_Reel).
--    0 a 2,59      P1 montaje 3×2 (grid6), seis viñetas de ~0,43 s con las tres monturas, en amarillo cómic
--  2,62 a 5,96     P2 playa (four_a): la Llama galopa, salta y escupe
--  5,97 a 9,26     P3 selva (four_b): el Jaguar corre, llega de frente y ruge
--  9,27 a 12,75    P4 montaña (four_c): el Quetzalcóatl baja, salta y planea
--  12,8 a 15       P5 cartel (single): flotando de tres cuartos, título, logo y fundido
local function mountsComicCuts(keys: { { t: number, pos: Vector3, pitch: number } }): { ComicCut }
	local k = MOUNTS_REEL_SECONDS / MOUNTS_SECONDS
	local bodyLift = Vector3.new(0, MOUNT_BODY_LIFT, 0)
	local finalLift = Vector3.new(0, MOUNTAIN_FINAL_LIFT, 0)
	local function quetzal(t: number, lift: Vector3): Vector3
		return mountainQuetzalAt(keys, t / k) + lift
	end
	local cuts: { ComicCut } = {}
	-- `order`: qué viñeta de la plantilla enseña cada plano. Las páginas de cuatro abren por la grande (la 4).
	local BIG_FIRST = { 4, 1, 2, 3 }
	local function addPage(layout: string, colors: { Color3 }, wipe: string?, cells: { ComicCell }, order: { number }?)
		for index, c in cells do
			table.insert(cuts, {
				t0 = c.t0,
				t1 = c.t1,
				layout = layout,
				page = if index == 1 then { layout = layout, colors = colors, wipe = wipe } else nil,
				cell = if order then order[index] else index,
				pos = c.pos,
				posB = c.posB,
				subject = c.subject,
				subjectB = c.subjectB,
				width = c.width,
				bg = c.bg,
			})
		end
	end
	-- P1: los seis encuadres del montaje.
	addPage("grid6", COMIC_COLORS.montage, nil, {
		comicCell(0, 0.43, Vector3.new(-19.4, 18.7, 262.6), Vector3.new(-23.2, 18.3, 266), 4.5, "flat"),
		comicCell(0.43, 0.86, Vector3.new(-14.5, 16.7, 276), Vector3.new(-21.3, 16.1, 272), 5, "dots"),
		comicCell(0.86, 1.29, Vector3.new(-11.5, 18, 281.8), Vector3.new(-19, 17.1, 278), 7.5, "flat"),
		comicCell(1.29, 1.72, Vector3.new(-32.5, 20.1, 266), Vector3.new(-25, 17.5, 266), 7, "dots"),
		comicCell(1.72, 2.15, Vector3.new(-25, 26.7, 272), Vector3.new(-25, 12.7, 272), 12, "flat"),
		comicCell(2.15, 2.59, jungle(-6, 3.2, 290), jungle(-25, 1.5, 272), 18, "dots"),
	})
	-- P2: playa. La Llama cruza en tres viñetas y escupe a la cámara en la última.
	addPage("four_a", COMIC_COLORS.jungle, "left", {
		comicCell(
			2.62,
			3.45,
			Vector3.new(-50, 9.4, 906),
			Vector3.new(-70, 6.9, 925),
			12,
			"flat",
			Vector3.new(-47, 6.9, 925)
		),
		comicCell(
			3.45,
			4.3,
			Vector3.new(-30, 9.4, 906),
			Vector3.new(-47, 6.9, 925),
			12,
			"dots",
			Vector3.new(-22, 6.9, 925)
		),
		comicCell(4.3, 5, Vector3.new(-10, 9.4, 906), Vector3.new(-22, 6.9, 925), 12, "flat", Vector3.new(0, 6.9, 925)),
		comicCell(5, 5.96, Vector3.new(1.5, 8.6, 918.5), Vector3.new(0, 8.2, 925), 5, "dots"),
	}, BIG_FIRST)
	-- P3: selva. El Jaguar corre y llega de frente a la cámara fija.
	addPage("four_b", COMIC_COLORS.mangrove, "left", {
		comicCell(
			5.97,
			6.9,
			Vector3.new(-8, 15.4, 286),
			Vector3.new(5, 15.4, 272),
			14,
			"flat",
			Vector3.new(-15, 15.4, 272)
		),
		comicCell(
			6.9,
			7.7,
			Vector3.new(-30, 15.4, 286),
			Vector3.new(-15, 15.4, 272),
			13,
			"dots",
			Vector3.new(-35, 15.4, 272)
		),
		comicCell(7.7, 8.5, Vector3.new(-49, 15.6, 272), Vector3.new(-42.4, 15.9, 272), 5.5, "flat"),
		comicCell(8.5, 9.26, Vector3.new(-47, 15.6, 272), Vector3.new(-42.4, 15.9, 272), 4.5, "dots"),
	}, BIG_FIRST)
	-- P4: montaña. Baja de frente, salta y pasa por encima; la última viñeta ya con la cámara del plano final.
	addPage("four_c", COMIC_COLORS.mountain, "down", {
		comicCell(9.27, 10.2, MOUNTAIN_CAMERA, quetzal(9.27, bodyLift), 16, "flat", quetzal(10.2, bodyLift)),
		comicCell(10.2, 11, MOUNTAIN_CAMERA, quetzal(10.2, bodyLift), 14, "dots", quetzal(11, bodyLift)),
		comicCell(11, 11.8, MOUNTAIN_CAMERA, quetzal(11, bodyLift), 12, "flat", quetzal(11.8, bodyLift)),
		comicCell(11.8, 12.75, MOUNTAIN_FINAL_CAMERA, quetzal(11.8, finalLift), 18, "dots", quetzal(12.75, finalLift)),
	}, BIG_FIRST)
	-- P5: el Quetzalcóatl flotando de tres cuartos (cartel final).
	addPage("single", COMIC_COLORS.mountain, "left", {
		comicCell(12.8, MOUNTS_REEL_SECONDS, MOUNTAIN_FINAL_CAMERA, MOUNTAIN_GLIDE_TO + finalLift, 16, "flat"),
	})
	return cuts
end

-- Narración y onomatopeyas de Mounts_Comic. Con BIG_FIRST la viñeta k de la lista muestra la celda order[k] de la
-- plantilla ({4, 1, 2, 3}): las onomatopeyas llevan el índice de la celda de la plantilla.
local function addMountsComicText(events: EventList)
	local function narration(t: number, text: string, seconds: number)
		table.insert(events, {
			t = t,
			kind = "bubble",
			balloon = "narration",
			corner = "BL",
			onPage = true,
			text = text,
			seconds = seconds,
		})
	end
	local function sfx(t: number, text: string, layout: string, cell: number, fx: number, fy: number, rot: number)
		table.insert(events, {
			t = t,
			kind = "sfx",
			text = text,
			pos = ComicPages.cellPoint(layout, cell, fx, fy),
			rot = rot,
			size = 0.3,
			color = Color3.new(1, 1, 1),
			seconds = 0.6,
		})
	end
	narration(2.8, Mounts.Llama.name, 2.4)
	narration(6.1, Mounts.Jaguar.name, 2.4)
	narration(9.4, Mounts.Quetzalcoatl.name, 2.4)
	sfx(5.25, Strings.later("¡PTUI!"), "four_a", 3, 0.6, 0.3, -12) -- la Llama escupe
	sfx(8.2, Strings.later("¡GRRR!"), "four_b", 2, 0.5, 0.3, 12) -- el Jaguar ruge
	sfx(10.9, Strings.later("¡FIUU!"), "four_c", 2, 0.35, 0.3, 14) -- el Quetzalcóatl salta
	sfx(13.1, Strings.later("¡FSSS!"), "single", 1, 0.65, 0.3, -10) -- el Quetzalcóatl sisea
	-- Cartel final en la viñeta única: título, logo del juego y fundido a negro.
	table.insert(events, { t = 13.3, kind = "title", text = MOUNTS_TITLE, seconds = 1 })
	table.insert(events, {
		t = 14.3,
		kind = "logo",
		text = Strings.later("Primal Banana Islands"),
		sub = Strings.later("Monkey Survival"),
		seconds = 0.5,
	})
	table.insert(events, { t = 14.5, kind = "fade", seconds = 0.4, toBlack = true })
end

-- `variant`: "full" (20 s, con bandas), "reel" (15 s, ventana alta 9:16) o "comic" (15 s, páginas con viñetas). Reel y cómic
-- usan los mismos eventos de movimiento con el tiempo × 0,75 (también la duración de los `move`).
local function mountsScene(variant: string): Scene
	local full = variant == "full"
	local comic = variant == "comic"
	local scale = if full then 1 else MOUNTS_REEL_SECONDS / MOUNTS_SECONDS
	local events: EventList = {}
	local function add(event: { t: number, kind: string, [string]: any })
		event.t *= scale
		if event.kind == "move" then
			event.seconds *= scale
		end
		table.insert(events, event)
	end
	-- Atajos de los eventos de montura y de movimiento (los `move` llevan la Y del suelo; el actor suma su altura).
	local function setPose(t: number, actor: string, name: string)
		add({ t = t, kind = "mountPose", actor = actor, pose = name })
	end
	local function gesture(t: number, actor: string)
		add({ t = t, kind = "mountGesture", actor = actor })
	end
	local function put(t: number, actor: string, pos: Vector3, yaw: number)
		add({ t = t, kind = "move", actor = actor, pos = pos, yaw = yaw, seconds = 0 })
	end
	local function run(t: number, actor: string, pos: Vector3, yaw: number, seconds: number)
		add({
			t = t,
			kind = "move",
			actor = actor,
			pos = pos,
			yaw = yaw,
			seconds = seconds,
			easing = Enum.EasingStyle.Linear,
		})
	end
	local function caption(t: number, mountId: string)
		-- Solo en la completa (reel y cómic ponen su propia narración). El nombre de la montura de Data/Mounts (se traduce
		-- al dibujarlo, ya está en Data/Strings/Content). Sin la rareza: el rótulo es de una sola línea y no hay plantilla
		-- «{nombre} · {rareza}» en las frases.
		if full then
			add({ t = t, kind = "caption", text = Mounts[mountId].name, seconds = MOUNT_CAPTION_SECONDS })
		end
	end

	if full then
		add({ t = 0, kind = "letterbox" })
	end
	-- Los monos reales de la isla se esconden en los tres sitios mientras dura la escena; por eso lleva freeze.
	add({
		t = 0,
		kind = "hideEnemies",
		server = true,
		centers = { MOUNT_ROW.Jaguar, BEACH_TO, MOUNTAIN_CENTER },
		radius = 200,
	})

	-- Cada montura sale del montaje (3,45) directa a su sitio o al aparcamiento.
	local beachYaw = yawBetween(BEACH_FROM, BEACH_TO)
	put(3.45, "Quetzalcoatl", MOUNT_PARK, MOUNT_ROW_YAW)
	put(3.45, "Llama", BEACH_FROM, beachYaw)

	-- PLAYA (3,5 a 8): galope, salto a los 2 s y, al llegar, se gira hacia la cámara y escupe.
	local beachCamera = MOUNT_SHOTS.beachSpit.a.pos
	caption(3.6, "Llama")
	setPose(3.5, "Llama", "Run")
	run(3.5, "Llama", BEACH_TO, beachYaw, 3.2)
	setPose(5.5, "Llama", "Jump")
	put(6.7, "Llama", BEACH_TO, yawBetween(BEACH_TO, beachCamera))
	setPose(6.7, "Llama", "Idle")
	gesture(6.95, "Llama")
	put(7.95, "Llama", MOUNT_PARK, beachYaw)
	put(7.95, "Jaguar", JUNGLE_RUN_FROM, yawBetween(JUNGLE_RUN_FROM, JUNGLE_RUN_TO))

	-- JUNGLA (8 a 12,5): carrera lateral y salto; a los 9,65 corte a la cámara fija del final, a la que el Jaguar llega
	-- corriendo de frente (para en 10,6 a ~6,6 studs) y ruge con sacudida.
	local jungleYaw = yawBetween(JUNGLE_RUN_FROM, JUNGLE_RUN_TO)
	caption(8.1, "Jaguar")
	setPose(8, "Jaguar", "Run")
	run(8, "Jaguar", JUNGLE_RUN_TO, jungleYaw, 2.6)
	setPose(8.9, "Jaguar", "Jump")
	setPose(10.6, "Jaguar", "Idle")
	gesture(10.8, "Jaguar")
	add({ t = 11.1, kind = "shake", amp = 0.2, seconds = 0.6 })
	put(12.35, "Jaguar", MOUNT_PARK, jungleYaw)

	-- MONTAÑA (12,5 a 17,5): corre por la falda y sisea, salta y planea por encima de la cámara.
	local keys = mountainKeys()
	put(12.35, "Quetzalcoatl", keys[1].pos, yawBetween(keys[1].pos, keys[2].pos))
	caption(12.6, "Quetzalcoatl")
	setPose(MOUNTAIN_RUN_START, "Quetzalcoatl", "Run")
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		add({
			t = a.t,
			kind = "move",
			actor = "Quetzalcoatl",
			pos = b.pos,
			yaw = yawBetween(a.pos, b.pos),
			pitch = b.pitch,
			seconds = b.t - a.t,
			easing = Enum.EasingStyle.Linear,
		})
	end
	gesture(13.1, "Quetzalcoatl")
	setPose(MOUNTAIN_LEAP_AT, "Quetzalcoatl", "Jump")
	setPose(MOUNTAIN_GLIDE_AT, "Quetzalcoatl", "Glide")
	-- Al llegar flota quieto (Idle) con el cuerpo nivelado, de cara al sur, y sisea para la cámara de tres cuartos.
	setPose(MOUNTAIN_GLIDE_END, "Quetzalcoatl", "Idle")
	add({
		t = MOUNTAIN_GLIDE_END,
		kind = "move",
		actor = "Quetzalcoatl",
		pos = MOUNTAIN_GLIDE_TO,
		yaw = yawBetween(MOUNTAIN_LEAP_TO, MOUNTAIN_GLIDE_TO),
		pitch = 0,
		seconds = 0.5,
		easing = Enum.EasingStyle.Quad,
	})
	gesture(MOUNTAIN_GLIDE_END + 0.3, "Quetzalcoatl")
	put(MOUNTS_SECONDS - 0.05, "Quetzalcoatl", MOUNT_PARK, -90)

	local camera: { CameraPoint }
	if comic then
		local cuts = mountsComicCuts(keys)
		camera = cutShots(comicShots(cuts))
		addComicPages(events, cuts)
		addMountsComicText(events)
	elseif not full then
		local cuts = mountsReelCuts(keys)
		camera = cutShots(battleReelShots(cuts))
		addReelPanels(events, cuts, Color3.fromRGB(190, 122, 44), Color3.fromRGB(246, 232, 196))
		addMountsReelText(events)
		addBattleFade(events, true, MOUNTS_REEL_SECONDS)
	else
		-- Cartel final, logo del juego y fundido a negro (los mismos tiempos relativos que Pets).
		add({ t = 17.5, kind = "title", text = MOUNTS_TITLE, seconds = 1.4 })
		add({
			t = 18.9,
			kind = "logo",
			text = Strings.later("Primal Banana Islands"),
			sub = Strings.later("Monkey Survival"),
			seconds = 0.9,
		})
		add({ t = 19.3, kind = "fade", seconds = 0.7, toBlack = true })
		camera = mountsCamera(keys)
	end
	return {
		duration = if full then MOUNTS_SECONDS else MOUNTS_REEL_SECONDS,
		audience = "Self",
		freeze = true,
		skippable = true,
		hour = MOUNTS_HOUR,
		streamFollowsCamera = true,
		-- Los tres sitios con su terreno cargado antes de poner a nadie (el montaje empieza en la jungla).
		waitTerrain = { MOUNT_ROW.Jaguar, BEACH_TO, MOUNTAIN_CENTER },
		-- Las mallas y texturas de las tres monturas se bajan antes de arrancar (las tres a la vez): el montaje enseña las
		-- tres en los primeros cortes y, sin esto, salían a bloques o sin textura hasta que cargaban.
		prepare = function()
			MountedRider.preloadAll({ "Llama", "Jaguar", "Quetzalcoatl" })
			return camera
		end,
		actors = {
			Llama = mountActor("Llama"),
			Jaguar = mountActor("Jaguar"),
			Quetzalcoatl = mountActor("Quetzalcoatl"),
		},
		camera = camera,
		events = events,
	}
end

-- ============================================================================ Juego de pelota (Fase 25, G9a)
-- «Ballgame»: el 3 contra 3 de la Isla de dunas (cancha de formato 3, hora 17,5, solo para grabar; la lanza la orden
-- «🎬 Juego de pelota» del panel de Dunas con el cliente DunasCineController, anclada al centro de la cancha: todas las
-- posiciones son LOCALES de la cancha, el origen es el centro del pasillo a nivel del suelo y los Jaguar defienden X < 0).
--   0 a 4        montaje de 5 cortes: el yugo de un Jaguar, el aro desde arriba, la rodillera, el tocado de plumas de un
--                Quetzal y el avatar visto por detrás
--   4 a ~11      un saque que bota una vez y cuatro pases de Jaguar (cadera, rodilla, codo y cadera) entre dos maniquíes y
--                el avatar, mientras los tres Quetzal corren a cortar; planos laterales que siguen la pelota
--   ~11 a 17     el avatar tira de cadera al aro y la escena pasa a cámara lenta ×0,3: la pelota da en el borde del aro y
--                sale (ringRim, nunca ringPass)
--   17 a 20      plano medio del avatar mirando a los lados (LookAround), un Quetzal recoge la pelota, cartel, logo y fundido
-- Nada de la pelota se improvisa: las trayectorias salen de la misma simulación del juego (BallSim) y de las mismas
-- velocidades de golpe (BallHit.velocity), así que lo que se ve es lo que haría la pelota de verdad. Cada pase empieza
-- donde acabó el anterior, y los pies de quien lo recibe se ponen donde cae la pelota a la altura de su zona de golpe
-- (Data/Ballgame.Hit). El tiro final se busca con una bisección (como ArenaDebugService.shootAtRing) para que el centro
-- cruce el plano del aro BALLGAME_RIM studs sobre su centro: roza la piedra. Los tiempos de los cortes y de los golpes
-- salen de esas trayectorias (el tiro sale cuando acaba el último pase): son de diseño, a ajustar en Studio.
-- La cámara lenta no es del Sequencer: las muestras del tiro se reparten en más segundos de escena (evento ballPath con
-- times) y un evento animSpeed baja la velocidad de las pistas de los maniquíes (Cinematics/BallActor).
-- Tiempos por variante (G9b). La física es la misma; solo cambian cuándo sale el saque, hasta cuándo dura la cámara lenta
-- y cuándo acaba la escena: `full` (la normal, 20 s) y `short` (reel y cómic, 15 s).
type BallTiming = {
	seconds: number, -- duración de la escena
	serveAt: number, -- el saque sale al acabar el montaje
	slowEnd: number, -- cuándo vuelve la velocidad normal tras la cámara lenta
	pickupMax: number, -- el Quetzal llega a la pelota como tarde a este segundo
}
local BALLGAME_TIMING: { [string]: BallTiming } = {
	full = { seconds = 20, serveAt = 4, slowEnd = 17, pickupMax = 19 },
	short = { seconds = 15, serveAt = 2.6, slowEnd = 13, pickupMax = 14.2 },
}
local BALLGAME_HOUR = 17.5 -- atardecer dorado, como Pets y Mounts
local BALLGAME_FORMAT = 3 -- la cancha de 3 contra 3
local BALLGAME_LAYOUT = CourtGeometry.forFormat(BALLGAME_FORMAT)
local BALLGAME_SLOW = 0.3 -- velocidad de la cámara lenta del tiro
local BALLGAME_AFTER_SIM = 2 -- segundos de simulación tras la cámara lenta (la pelota sigue rodando hasta pararse)
local BALLGAME_RING_SIDE = -1 -- el tiro va al aro del lado de z negativo
local BALLGAME_RIM = 3.4 -- studs sobre el centro del aro por donde cruza la pelota (el hueco mide 3,2: roza la piedra)
local BALLGAME_BOOST_RANGE = { 0.2, 1.3 } -- límites de la bisección del multiplicador de rapidez del tiro
local BALLGAME_BEHIND = 1.4 -- studs de la pelota a la raíz de quien la golpea, contra su dirección de salida
local BALLGAME_RUN_SPEED = 20 -- studs/s al correr a un contacto
local BALLGAME_HIT_LEAD = 0.15 -- la animación de golpe sale este tiempo antes de que salga la pelota
-- Altura del centro de la pelota al contacto (raíz del maniquí a ~3 studs del suelo + la mitad de cada zona de Hit.Zone*).
local BALLGAME_RECEIVE_Y: { [string]: number } = { Hip = 3.4, Knee = 1.6, Elbow = 4.7 }
local BALLGAME_HIT_ANIMATION: { [string]: string } = { Hip = "BallHip", Knee = "BallKnee", Elbow = "BallElbow" }
-- Saque: parte del centro, a la altura del saque (Ballgame.Serve) y cae al Jaguar A tras un bote.
local BALLGAME_SERVE_FROM = Vector3.new(0, 10, 0)
local BALLGAME_SERVE_VELOCITY = Vector3.new(-13.3, 16, 2.2)
-- Los cuatro pases: quién golpea, con qué zona y calidad, hacia dónde (grados desde +X hacia +Z), cuántos botes de suelo
-- da antes de llegar y a qué altura lo recibe el siguiente. El quinto golpe es el tiro del avatar.
local BALLGAME_LEGS = {
	{ hitter = "jaguarA", zone = "Hip", quality = "Weak", heading = 0, bounces = 0, receive = "Elbow" },
	{ hitter = "jaguarB", zone = "Elbow", quality = "Weak", heading = 200, bounces = 1, receive = "Knee" },
	{ hitter = "avatar", zone = "Knee", quality = "Good", heading = 50, bounces = 0, receive = "Hip" },
	{ hitter = "jaguarA", zone = "Hip", quality = "Weak", heading = 280, bounces = 0, receive = "Hip" },
}
-- Dónde está cada uno al empezar (el montaje los enseña quietos): pies sobre el suelo (y = 0) y yaw (-90 mira a +X).
local BALLGAME_START = {
	jaguarA = Vector3.new(-33, 0, 9),
	jaguarB = Vector3.new(-15, 0, 11),
	avatar = Vector3.new(-22, 0, -1),
	quetzalA = Vector3.new(12, 0, 8),
	quetzalB = Vector3.new(18, 0, -2),
	quetzalC = Vector3.new(11, 0, -10),
}
local BALLGAME_QUETZAL_X = { quetzalA = 6.5, quetzalB = 11, quetzalC = 15.5 } -- por dónde cortan
local BALLGAME_QUETZAL_Z = { quetzalA = 0, quetzalB = 8, quetzalC = -8 } -- su desvío lateral respecto a la pelota
local BALLGAME_TITLE = Strings.later("Juego de pelota")

type BallHitPlan = { hitter: string, zone: string, t: number, ball: Vector3, dir: Vector3 }
type BallPath = { samples: { Vector3 }, times: { number }, team: string }
type BallPlan = {
	hits: { BallHitPlan }, -- cinco: los cuatro pases y el tiro (el último)
	paths: { BallPath },
	keyTimes: { number }, -- la pelota en cada instante, para las cámaras (ballgameBallAt)
	keyPositions: { Vector3 },
	shotAt: number, -- segundo del tiro (= fin del último pase)
	rimAt: number?, -- segundo en que la pelota toca el aro
	endAt: number, -- segundo en que la pelota se para (o acaba la simulación)
	endPos: Vector3,
}
type BallFlight = { samples: { Vector3 }, events: { { t: number, kind: string, surface: string? } }, reached: boolean }

-- Vuela la pelota con BallSim desde start hasta que stop devuelva true (o se pare, salga o pase maxSeconds). stop recibe
-- el estado, los segundos de vuelo, la altura de antes del paso y los botes en el suelo.
local function ballgameFly(
	start: Vector3,
	velocity: Vector3,
	maxSeconds: number,
	stop: ((state: BallSim.State, elapsed: number, previousY: number, bounces: number) -> boolean)?
): BallFlight
	local state = BallSim.new(start, velocity)
	local samples = { start }
	local events = {}
	local bounces = 0
	local reached = false
	for index = 1, math.floor(maxSeconds / BallSim.STEP) do
		local previousY = state.pos.Y
		local elapsed = index * BallSim.STEP
		for _, event in BallSim.step(state, BALLGAME_LAYOUT, BallSim.STEP) do
			table.insert(events, { t = elapsed, kind = event.kind, surface = event.surface })
			if event.kind == "bounce" and event.surface == "Floor" then
				bounces += 1
			end
		end
		table.insert(samples, state.pos)
		if stop and stop(state, elapsed, previousY, bounces) then
			reached = true
			break
		end
		if state.dead or state.resting then
			break
		end
	end
	return { samples = samples, events = events, reached = reached }
end

-- La pelota llega a la altura de contacto de una zona (bajando, tras `bounces` botes en el suelo).
local function ballgameReceive(zone: string, bounces: number)
	local height = BALLGAME_RECEIVE_Y[zone]
	return function(state: BallSim.State, elapsed: number, previousY: number, floorBounces: number): boolean
		return floorBounces >= bounces
			and state.vel.Y < 0
			and previousY > height
			and state.pos.Y <= height
			and elapsed > 0.3
	end
end

-- Altura del centro de la pelota al recorrer `distance` studs en horizontal con la velocidad dada (gravedad y arrastre de
-- BallSim, sin choques): sirve para la bisección del tiro.
local function ballgameHeightAfter(start: Vector3, velocity: Vector3, distance: number): number
	local step = 1 / 240
	local damp = 1 - BallgameData.AirDrag * step
	local travelled, y, horizontal, vertical = 0, start.Y, Vector2.new(velocity.X, velocity.Z).Magnitude, velocity.Y
	for _ = 1, 2400 do
		vertical = (vertical - BallgameData.Gravity * step) * damp
		horizontal *= damp
		travelled += horizontal * step
		y += vertical * step
		if travelled >= distance then
			return y
		end
	end
	return -math.huge
end

-- Todo lo que sale de la simulación: golpes, trayectorias con su tiempo de escena y qué pasa con el aro.
local function ballgamePlan(timing: BallTiming): BallPlan
	local ring = CourtGeometry.ring
	local ringPos = Vector3.new(ring.centerX, ring.centerY, BALLGAME_RING_SIDE * ring.centerZ)
	local hits: { BallHitPlan } = {}
	local paths: { BallPath } = {}
	local keyTimes: { number } = {}
	local keyPositions: { Vector3 } = {}

	-- Anota una trayectoria que empieza en t0 con el tiempo de escena de cada muestra (timeOf); devuelve el del final.
	local function addPath(samples: { Vector3 }, t0: number, timeOf: (index: number) -> number): number
		local times = {}
		for index = 1, #samples do
			local t = t0 + timeOf(index)
			times[index] = t
			table.insert(keyTimes, t)
			table.insert(keyPositions, samples[index])
		end
		table.insert(paths, { samples = samples, times = times, team = "Jaguar" })
		return times[#times]
	end
	local function realTime(index: number): number
		return (index - 1) * BallSim.STEP
	end

	-- Saque: baja al Jaguar A tras un bote; el primer golpe es al llegar.
	local serve = ballgameFly(BALLGAME_SERVE_FROM, BALLGAME_SERVE_VELOCITY, 8, ballgameReceive("Hip", 1))
	if not serve.reached then
		warn("Ballgame: el saque no llega a la altura de cadera")
	end
	local t = addPath(serve.samples, timing.serveAt, realTime)
	local contact = serve.samples[#serve.samples]

	for _, leg in BALLGAME_LEGS do
		local radians = math.rad(leg.heading)
		local dir = Vector3.new(math.cos(radians), 0, math.sin(radians))
		table.insert(hits, { hitter = leg.hitter, zone = leg.zone, t = t, ball = contact, dir = dir })
		local flight = ballgameFly(
			contact,
			BallHit.velocity(leg.zone, leg.quality, dir, 1),
			8,
			ballgameReceive(leg.receive, leg.bounces)
		)
		if not flight.reached then
			warn(`Ballgame: el pase de {leg.hitter} no llega a la altura de {leg.receive}`)
		end
		t = addPath(flight.samples, t, realTime)
		contact = flight.samples[#flight.samples]
	end

	-- El tiro del avatar: de cadera, hacia el centro del aro, con la rapidez que da (bisección) la altura pedida.
	local shotAt = t
	assert(shotAt < timing.slowEnd - 2.5, `Ballgame: el tiro sale demasiado tarde ({shotAt}); acorta los pases`)
	local toRing = Vector3.new(ringPos.X - contact.X, 0, ringPos.Z - contact.Z)
	local dir = toRing.Unit
	table.insert(hits, { hitter = "avatar", zone = "Hip", t = shotAt, ball = contact, dir = dir })
	local aimY = ring.centerY + BALLGAME_RIM
	local function shotVelocity(boost: number): Vector3
		return BallHit.velocity("Hip", "Perfect", dir, 1, boost)
	end
	local low, high = BALLGAME_BOOST_RANGE[1], BALLGAME_BOOST_RANGE[2]
	if ballgameHeightAfter(contact, shotVelocity(high), toRing.Magnitude) < aimY then
		warn("Ballgame: el tiro no llega a la altura del aro ni con la rapidez máxima")
	end
	for _ = 1, 40 do
		local mid = (low + high) / 2
		if ballgameHeightAfter(contact, shotVelocity(mid), toRing.Magnitude) < aimY then
			low = mid
		else
			high = mid
		end
	end
	local slowSim = (timing.slowEnd - shotAt) * BALLGAME_SLOW -- segundos de simulación que caben en la cámara lenta
	local shotFlight = ballgameFly(contact, shotVelocity((low + high) / 2), slowSim + BALLGAME_AFTER_SIM, nil)
	local function shotTime(simSeconds: number): number
		if simSeconds <= slowSim then
			return shotAt + simSeconds / BALLGAME_SLOW
		end
		return timing.slowEnd + (simSeconds - slowSim)
	end
	local endAt = addPath(shotFlight.samples, 0, function(index)
		return shotTime((index - 1) * BallSim.STEP)
	end)
	-- Comprobación: debe haber roce con el aro y ningún pase por él.
	local rimAt: number? = nil
	for _, event in shotFlight.events do
		if event.kind == "ringPass" then
			warn("Ballgame: el tiro final PASA por el aro (ringPass); cambia BALLGAME_RIM")
		elseif event.kind == "ringRim" and rimAt == nil then
			rimAt = shotTime(event.t)
		end
	end
	if rimAt == nil then
		warn("Ballgame: el tiro final no toca el aro (sin ringRim); cambia BALLGAME_RIM")
	end
	return {
		hits = hits,
		paths = paths,
		keyTimes = keyTimes,
		keyPositions = keyPositions,
		shotAt = shotAt,
		rimAt = rimAt,
		endAt = endAt,
		endPos = shotFlight.samples[#shotFlight.samples],
	}
end

-- Dónde está la pelota en el segundo t (lineal entre muestras; fuera del rango, la primera o la última).
local function ballgameBallAt(plan: BallPlan, t: number): Vector3
	local times, positions = plan.keyTimes, plan.keyPositions
	local count = #times
	if t <= times[1] then
		return positions[1]
	end
	if t >= times[count] then
		return positions[count]
	end
	local lo, hi = 1, count
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if times[mid] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	local span = times[hi] - times[lo]
	return positions[lo]:Lerp(positions[hi], if span > 0 then (t - times[lo]) / span else 1)
end

-- Un plano que se muestrea cada 0,3 s: `at(t)` da la posición, la mirada y el fov de la cámara en ese segundo. Se repiten el
-- primer y el último punto 1 ms después para que la spline no curve el plano con los vecinos del corte.
local function ballgameFollow(
	camera: { CameraPoint },
	t0: number,
	t1: number,
	at: (t: number) -> (Vector3, Vector3, number)
)
	local steps = math.max(1, math.ceil((t1 - t0) / 0.3))
	for index = 0, steps do
		local t = t0 + (t1 - t0) * index / steps
		local pos, look, fov = at(t)
		table.insert(camera, { t = t, pos = pos, look = look, fov = fov })
		if index == 0 or index == steps then
			table.insert(camera, { t = t + 0.001, pos = pos, look = look, fov = fov })
		end
	end
end

-- Mirada que sigue a la pelota sin dar saltos con cada bote: la altura se queda a medio camino de una fija.
local function ballgameLook(ball: Vector3): Vector3
	return Vector3.new(ball.X, 3 + (ball.Y - 3) * 0.45, ball.Z)
end

-- Los tres planos laterales fijos de los pases (por el lado de +Z, el de -Z y otra vez +Z): por encima del banco y del
-- talud (a 8 studs la pared roja del lado opuesto cortaba la imagen). Los comparten la cámara normal, el reel y el cómic.
local BALLGAME_LATERAL: { { pos: Vector3, fov: number } } = {
	{ pos = Vector3.new(-21, 11, 20), fov = 54 },
	{ pos = Vector3.new(-21, 11, -20), fov = 54 },
	{ pos = Vector3.new(-24, 11, 20), fov = 52 },
}

-- Los cinco tramos de vuelo entre golpes (saque, cuatro pases) con el plano lateral que sigue a la pelota en cada uno.
local function ballgameSegments(plan: BallPlan, timing: BallTiming): { { t0: number, t1: number, lateral: number } }
	local hits = plan.hits
	return {
		{ t0 = timing.serveAt, t1 = hits[1].t, lateral = 1 },
		{ t0 = hits[1].t, t1 = hits[2].t, lateral = 1 },
		{ t0 = hits[2].t, t1 = hits[3].t, lateral = 2 },
		{ t0 = hits[3].t, t1 = hits[4].t, lateral = 2 },
		{ t0 = hits[4].t, t1 = hits[5].t, lateral = 3 },
	}
end

-- El tiro del avatar: dónde pisa, hacia dónde sale la pelota (face), su costado (side), cuándo acaba su plano cercano
-- (un segundo antes del toque del aro, para que el aro se vea al llegar la pelota) y los dos puntos de la cámara de lado.
local function ballgameShooterView(plan: BallPlan): {
	feet: Vector3,
	side: Vector3,
	face: Vector3,
	closeEnd: number,
	a: CameraPoint,
	b: CameraPoint,
}
	local shooter = plan.hits[5]
	local feet = Vector3.new(
		shooter.ball.X - shooter.dir.X * BALLGAME_BEHIND,
		0,
		shooter.ball.Z - shooter.dir.Z * BALLGAME_BEHIND
	)
	local side = Vector3.new(-shooter.dir.Z, 0, shooter.dir.X)
	return {
		feet = feet,
		side = side,
		face = shooter.dir,
		closeEnd = math.max(plan.shotAt + 0.8, (plan.rimAt or plan.shotAt + 3.2) - 1),
		a = shot(
			feet + side * 11 + shooter.dir * 0.5 + Vector3.new(0, 3.6, 0),
			feet + shooter.dir * 0.8 + Vector3.new(0, 3, 0),
			46
		),
		b = shot(
			feet + side * 10 + shooter.dir * 2.5 + Vector3.new(0, 3.6, 0),
			feet + shooter.dir * 3.5 + Vector3.new(0, 3.4, 0),
			40
		),
	}
end

-- Plano lateral al aro (el de BallReplayController): mira entre el aro y la pelota y se acerca. Devuelve la posición, la
-- mirada y el fov en el segundo t de un plano que va de ringStart a ringEnd.
local function ballgameRingView(
	plan: BallPlan,
	ringStart: number,
	ringEnd: number,
	t: number
): (Vector3, Vector3, number)
	local ring = CourtGeometry.ring
	local ringPos = Vector3.new(ring.centerX, ring.centerY, BALLGAME_RING_SIDE * ring.centerZ)
	local ball = ballgameBallAt(plan, t)
	local progress = math.clamp((t - ringStart) / (ringEnd - ringStart), 0, 1)
	local far = math.clamp(math.abs(ball.X - ringPos.X) / 50, 0, 1)
	local focus = ringPos:Lerp(ball, 0.5 * far)
	local lateralDistance = 24 + 16 * far - 8 * progress
	return focus + Vector3.new(-8, -3, -BALLGAME_RING_SIDE * lateralDistance), focus, 55 - 15 * progress
end

-- La cámara: montaje de 5 cortes, tres planos laterales de los pases, el tiro (el avatar y después el aro) y el plano medio
-- final. Posiciones de diseño: a encuadrar en Studio.
local function ballgameCamera(plan: BallPlan, timing: BallTiming): { CameraPoint }
	local ring = CourtGeometry.ring
	local ringPos = Vector3.new(ring.centerX, ring.centerY, BALLGAME_RING_SIDE * ring.centerZ)
	local start = BALLGAME_START
	local yoke = start.jaguarA
	local knee = start.jaguarB
	local crest = start.quetzalA
	local camera = (
		CameraPath.montage({
			-- 1. El yugo de piedra del Jaguar A, de frente (mira a +X) y un poco de lado.
			still(
				yoke + Vector3.new(6.2, 3.6, 2.8),
				yoke + Vector3.new(0, 2.8, 0),
				0.7,
				42,
				yoke + Vector3.new(5.6, 3.5, 2.5)
			),
			-- 2. El aro del lado del tiro desde arriba.
			CameraPath.zenith(ringPos, 12, 0, 0.8, 60),
			-- 3. La rodillera del Jaguar B.
			still(
				knee + Vector3.new(5, 2.8, 2.4),
				knee + Vector3.new(0, 1.6, 0),
				0.7,
				40,
				knee + Vector3.new(4.5, 2.7, 2.1)
			),
			-- 4. El tocado de plumas del Quetzal A (mira a -X), de frente.
			still(
				crest + Vector3.new(-3.2, 5.9, 0.9),
				crest + Vector3.new(0, 5.6, 0),
				0.75,
				38,
				crest + Vector3.new(-2.8, 5.8, 0.7)
			),
			-- 5. El avatar visto por detrás, como lo ve el jugador.
			CameraPath.behind(start.avatar + Vector3.new(0, 3, 0), -90, 7.5, 2.6, 0, 0.8, 52),
		}) :: any
	) :: { CameraPoint }

	-- Los pases: los planos laterales fijos que siguen la pelota (el saque y el pase 1 con el primero, los pases 2 y 3 con el
	-- segundo y el 4 con el tercero).
	local segments = ballgameSegments(plan, timing)
	for _, lateralIndex in { 1, 2, 3 } do
		local first, last = math.huge, 0
		for _, segment in segments do
			if segment.lateral == lateralIndex then
				first = math.min(first, segment.t0)
				last = math.max(last, segment.t1)
			end
		end
		local lateral = BALLGAME_LATERAL[lateralIndex]
		ballgameFollow(camera, first, if lateralIndex == 3 then plan.shotAt - 0.05 else last - 0.05, function(t)
			return lateral.pos, ballgameLook(ballgameBallAt(plan, t)), lateral.fov
		end)
	end

	-- El tiro. Primero el avatar de lado, a la altura de la cadera, con la pelota saliendo hacia el aro.
	local view = ballgameShooterView(plan)
	local feet, side, face = view.feet, view.side, view.face
	pushShot(camera, plan.shotAt, view.closeEnd, view.a, view.b)
	-- Después, lateral al aro: mira entre el aro y la pelota y se acerca; fov 55 a 40.
	local ringStart = view.closeEnd + 0.05
	local ringEnd = timing.slowEnd - 0.03
	ballgameFollow(camera, ringStart, ringEnd, function(t)
		return ballgameRingView(plan, ringStart, ringEnd, t)
	end)

	-- Final: plano medio del avatar, de frente, con un leve acercamiento.
	pushShot(
		camera,
		timing.slowEnd + 0.05,
		timing.seconds,
		-- El avatar queda a un lado del cuadro: el cartel «Juego de pelota» sale en el centro y no debe taparlo.
		shot(feet + face * 14 + Vector3.new(0, 4.6, 0), feet + side * 4.6 + Vector3.new(0, 3.3, 0), 38),
		shot(feet + face * 12 + Vector3.new(0, 4.4, 0), feet + side * 4 + Vector3.new(0, 3.3, 0), 34)
	)
	return camera
end

-- Un maniquí del partido: sin arma y con el equipo de su bando.
local function ballgameDummy(team: string, pos: Vector3, yaw: number, skin: Color3): { [string]: any }
	return { kind = "dummy", weapon = false, ballGear = team, pos = pos, yaw = yaw, skinColor = skin }
end

-- Las posiciones del montaje de 5 (el yugo de un Jaguar, el aro desde arriba, la rodillera, el tocado del Quetzal y el
-- avatar por detrás), las mismas que ballgameCamera, para el reel (`reelWidth`) y el cómic (`comicWidth`).
local function ballgameMontage(): { { pos: Vector3, subject: Vector3, reelWidth: number, comicWidth: number } }
	local ring = CourtGeometry.ring
	local ringPos = Vector3.new(ring.centerX, ring.centerY, BALLGAME_RING_SIDE * ring.centerZ)
	local start = BALLGAME_START
	local yoke, knee, crest, avatar = start.jaguarA, start.jaguarB, start.quetzalA, start.avatar
	return {
		{
			pos = yoke + Vector3.new(6.2, 3.6, 2.8),
			subject = yoke + Vector3.new(0, 2.8, 0),
			reelWidth = 4,
			comicWidth = 4.5,
		},
		{ pos = ringPos + Vector3.new(0, 12, 0), subject = ringPos, reelWidth = 9, comicWidth = 10 },
		{
			pos = knee + Vector3.new(5, 2.8, 2.4),
			subject = knee + Vector3.new(0, 1.6, 0),
			reelWidth = 3.5,
			comicWidth = 4,
		},
		{
			pos = crest + Vector3.new(-3.2, 5.9, 0.9),
			subject = crest + Vector3.new(0, 5.6, 0),
			reelWidth = 3,
			comicWidth = 3.5,
		},
		-- El avatar visto por detrás, como lo ve el jugador (mira a +X: detrás es -X).
		{
			pos = avatar + Vector3.new(-7.5, 5.6, 0),
			subject = avatar + Vector3.new(0, 3, 0),
			reelWidth = 4.5,
			comicWidth = 5,
		},
	}
end

-- Los Quetzal en fila vistos de frente (miran a -X), sexta viñeta del montaje del cómic.
local BALLGAME_QUETZAL_ROW = {
	pos = Vector3.new(-4, 7, 0),
	subject = Vector3.new(14.5, 3.5, -1),
	comicWidth = 24,
}

-- Los cortes de Ballgame_Reel (G9b): ventanas de la banda 9:16. Montaje de 5 (~0,5 s cada uno) hasta el saque, un corte por
-- tramo de vuelo (saque y cuatro pases) con la cámara lateral de la normal y la mirada de la pelota al empezar y al
-- acabar, el tiro del avatar de lado, el aro en cámara lenta y el final con el avatar. Posiciones de diseño.
local function ballgameReelCuts(plan: BallPlan, timing: BallTiming): { ReelCut }
	local cuts: { ReelCut } = {}
	local montage = ballgameMontage()
	local shapes = { "reelTall", "reelTop", "reelDiagR", "reelSlant", "reelDiagL" }
	local backgrounds = { "speed", "halftone", "flat", "speed", "halftone" }
	local step = timing.serveAt / #montage
	for index, m in montage do
		table.insert(cuts, {
			t0 = (index - 1) * step,
			t1 = index * step,
			shape = shapes[index],
			bg = backgrounds[index],
			pos = m.pos,
			subject = m.subject,
			width = m.reelWidth,
		})
	end
	-- Un corte por tramo: la cámara lateral fija y el sujeto que va de la pelota de t0 a la de t1.
	local passShapes = { "reelDiagR", "reelSlant", "reelDiagL", "reelSlant", "reelDiagR" }
	local passBackgrounds = { "flat", "speed", "halftone", "flat", "speed" }
	for index, segment in ballgameSegments(plan, timing) do
		table.insert(cuts, {
			t0 = segment.t0,
			t1 = segment.t1,
			shape = passShapes[index],
			bg = passBackgrounds[index],
			pos = BALLGAME_LATERAL[segment.lateral].pos,
			subject = ballgameLook(ballgameBallAt(plan, segment.t0)),
			subjectB = ballgameLook(ballgameBallAt(plan, segment.t1)),
			width = 14,
		})
	end
	-- El tiro: el avatar de lado con la pelota saliendo (las mismas cámaras que la normal).
	local view = ballgameShooterView(plan)
	table.insert(cuts, {
		t0 = plan.shotAt,
		t1 = view.closeEnd,
		shape = "reelTall",
		bg = "speed",
		pos = view.a.pos,
		posB = view.b.pos,
		subject = view.a.look,
		subjectB = view.b.look,
		width = 5,
	})
	-- El aro en cámara lenta: la pelota da en el borde.
	local ringPosA, ringFocusA = ballgameRingView(plan, view.closeEnd, timing.slowEnd, view.closeEnd)
	local ringPosB, ringFocusB = ballgameRingView(plan, view.closeEnd, timing.slowEnd, timing.slowEnd)
	table.insert(cuts, {
		t0 = view.closeEnd,
		t1 = timing.slowEnd,
		shape = "reelSlant",
		bg = "halftone",
		pos = ringPosA,
		posB = ringPosB,
		subject = ringFocusA,
		subjectB = ringFocusB,
		width = 20,
	})
	-- Final: el avatar mirando a los lados.
	cuts[#cuts + 1] = {
		t0 = timing.slowEnd,
		t1 = timing.seconds,
		shape = "reelDiagL",
		bg = "flat",
		pos = view.feet + view.face * 12 + Vector3.new(0, 4.4, 0),
		subject = view.feet + Vector3.new(0, 3.3, 0),
		width = 6,
	}
	return cuts
end

-- Narración y cartel final del reel: las dos frases de la normal abajo a la izquierda, el título arriba y el nombre del
-- juego bajo en la zona segura.
local function addBallgameReelText(events: EventList, plan: BallPlan, timing: BallTiming)
	local function narration(t: number, text: string, corner: string, seconds: number)
		table.insert(
			events,
			{ t = t, kind = "bubble", balloon = "narration", corner = corner, text = text, seconds = seconds }
		)
	end
	narration(timing.serveAt + 0.2, Strings.later("Sin manos. Solo cadera, rodilla y codo."), "BL", 2.4)
	narration(plan.shotAt - 1.8, Strings.later("Un aro. Un tiro."), "BL", 1.5)
	narration(13.1, BALLGAME_TITLE, "TL", 1.8)
	addReelTitle(events, 13.3)
end

-- Los cortes de Ballgame_Comic (G9b): la misma escena en páginas con viñetas.
--    0 a serveAt   P1 montaje 3×2 (grid6): los 5 del montaje y los tres Quetzal en fila, en amarillo cómic
--    saque a pase 3  P2 (four_a): el saque, el pase 1, el pase 2 y el pase 3 del avatar
--    pase 4 al aro   P3 (four_b): el pase 4, el avatar recibe, el tiro sale y la pelota vuela al aro
--    el aro y el final P4 (single): la cámara lenta del aro y el avatar mirando a los lados, ¡TOC!, título, logo y fundido
local function ballgameComicCuts(plan: BallPlan, timing: BallTiming): { ComicCut }
	local cuts: { ComicCut } = {}
	-- Las páginas de cuatro empiezan por la viñeta grande (la 4): así no queda medio cuadro vacío mientras pasan las pequeñas.
	local BIG_FIRST = { 4, 1, 2, 3 }
	local function addPage(layout: string, colors: { Color3 }, wipe: string?, cells: { ComicCell }, order: { number }?)
		for index, c in cells do
			table.insert(cuts, {
				t0 = c.t0,
				t1 = c.t1,
				layout = layout,
				page = if index == 1 then { layout = layout, colors = colors, wipe = wipe } else nil,
				cell = if order then order[index] else index,
				pos = c.pos,
				posB = c.posB,
				subject = c.subject,
				subjectB = c.subjectB,
				width = c.width,
				bg = c.bg,
			})
		end
	end
	local function lookAt(t: number): Vector3
		return ballgameLook(ballgameBallAt(plan, t))
	end
	-- Una viñeta que sigue a la pelota de t0 a t1 desde la cámara lateral `lateral`.
	local function flight(t0: number, t1: number, lateral: number, bg: string, width: number?): ComicCell
		return comicCell(t0, t1, BALLGAME_LATERAL[lateral].pos, lookAt(t0), width or 14, bg, lookAt(t1))
	end

	-- P1: el montaje (seis viñetas del mismo largo).
	local montage = ballgameMontage()
	local step = timing.serveAt / (#montage + 1)
	local cells: { ComicCell } = {}
	for index, m in montage do
		table.insert(
			cells,
			comicCell(
				(index - 1) * step,
				index * step,
				m.pos,
				m.subject,
				m.comicWidth,
				if index % 2 == 1 then "flat" else "dots"
			)
		)
	end
	table.insert(
		cells,
		comicCell(
			#montage * step,
			timing.serveAt,
			BALLGAME_QUETZAL_ROW.pos,
			BALLGAME_QUETZAL_ROW.subject,
			BALLGAME_QUETZAL_ROW.comicWidth,
			"flat"
		)
	)
	addPage("grid6", COMIC_COLORS.montage, nil, cells)

	-- P2: el saque y los pases 1, 2 y 3 (el del avatar).
	local segments = ballgameSegments(plan, timing)
	addPage("four_a", COMIC_COLORS.jungle, "left", {
		flight(segments[1].t0, segments[1].t1, segments[1].lateral, "flat"),
		flight(segments[2].t0, segments[2].t1, segments[2].lateral, "dots"),
		flight(segments[3].t0, segments[3].t1, segments[3].lateral, "flat"),
		flight(segments[4].t0, segments[4].t1, segments[4].lateral, "dots"),
	}, BIG_FIRST)

	-- P3: el pase 4, el avatar recibe (por detrás), el tiro sale (de lado) y la pelota vuela al aro.
	local view = ballgameShooterView(plan)
	local receiveAt = math.max(segments[5].t0 + 0.4, plan.shotAt - 0.6)
	local pageEnd = math.max(view.closeEnd + 0.4, (plan.rimAt or view.closeEnd + 1.5) - 0.3)
	local ringStart, ringEnd = view.closeEnd, timing.slowEnd
	local ringPosA, ringFocusA = ballgameRingView(plan, ringStart, ringEnd, ringStart)
	local ringPosB, ringFocusB = ballgameRingView(plan, ringStart, ringEnd, pageEnd)
	addPage("four_b", COMIC_COLORS.mountain, "left", {
		-- Más cerrada que las otras: es la viñeta grande y, congelada, se quedaba con un avatar diminuto sobre fondo vacío.
		flight(segments[5].t0, receiveAt, segments[5].lateral, "flat", 9),
		comicCell(
			receiveAt,
			plan.shotAt,
			view.feet - view.face * 8 + Vector3.new(0, 4.5, 0) + view.side * 1.5,
			view.feet + Vector3.new(0, 3, 0),
			5,
			"dots"
		),
		comicCell(plan.shotAt, view.closeEnd, view.a.pos, view.a.look, 6, "flat", view.b.look),
		comicCell(ringStart, pageEnd, ringPosA, ringFocusA, 22, "dots", ringFocusB),
	}, BIG_FIRST)
	cuts[#cuts].posB = ringPosB

	-- P4: el aro en cámara lenta hasta que acaba y el final con el avatar. Una sola viñeta: los dos planos la comparten (el
	-- evento `cell` con el mismo índice no hace nada).
	local ringPosC, ringFocusC = ballgameRingView(plan, ringStart, ringEnd, pageEnd)
	local ringPosD, ringFocusD = ballgameRingView(plan, ringStart, ringEnd, ringEnd)
	addPage("single", COMIC_COLORS.mangrove, "left", {
		comicCell(pageEnd, ringEnd, ringPosC, ringFocusC, 22, "flat", ringFocusD),
		comicCell(
			ringEnd,
			timing.seconds,
			view.feet + view.face * 12 + Vector3.new(0, 4.4, 0),
			-- El avatar a un lado de la viñeta: el cartel «Juego de pelota» sale en el centro y no debe taparlo.
			view.feet
				+ view.side * 3.8
				+ Vector3.new(0, 3.3, 0),
			12,
			"flat"
		),
	}, { 1, 1 })
	cuts[#cuts - 1].posB = ringPosD
	return cuts
end

-- Narración y onomatopeyas de Ballgame_Comic. Con BIG_FIRST la viñeta k de la lista muestra la celda order[k] de la
-- plantilla ({4, 1, 2, 3}): las onomatopeyas llevan el índice de la celda de la plantilla.
local function addBallgameComicText(events: EventList, plan: BallPlan, timing: BallTiming)
	local function narration(t: number, text: string, seconds: number)
		table.insert(events, {
			t = t,
			kind = "bubble",
			balloon = "narration",
			corner = "BL",
			onPage = true,
			text = text,
			seconds = seconds,
		})
	end
	local lastSfx = -math.huge
	local function sfx(t: number, text: string, layout: string, cell: number, fx: number, fy: number, rot: number)
		if t - lastSfx < 0.7 then
			return -- ninguna onomatopeya pisa a la anterior
		end
		lastSfx = t
		table.insert(events, {
			t = t,
			kind = "sfx",
			text = text,
			pos = ComicPages.cellPoint(layout, cell, fx, fy),
			rot = rot,
			size = 0.3,
			color = Color3.new(1, 1, 1),
			seconds = 0.6,
		})
	end
	local hits = plan.hits
	narration(timing.serveAt + 0.2, Strings.later("Sin manos. Solo cadera, rodilla y codo."), 2.4)
	narration(math.max(hits[4].t + 0.1, plan.shotAt - 1.7), Strings.later("Un aro. Un tiro."), 1.5)
	-- Cada golpe, en la viñeta donde empieza su vuelo: pase 1 (celda 1 de P2), 2 (celda 2), 3 (celda 3), 4 (celda 4 de P3)
	-- y el tiro (celda 2 de P3).
	local pam = Strings.later("¡PAM!")
	sfx(hits[1].t + 0.05, pam, "four_a", 1, 0.6, 0.3, -12)
	sfx(hits[2].t + 0.05, pam, "four_a", 2, 0.4, 0.3, 14)
	sfx(hits[3].t + 0.05, pam, "four_a", 3, 0.6, 0.3, -13)
	sfx(hits[4].t + 0.05, pam, "four_b", 4, 0.55, 0.3, 12)
	sfx(plan.shotAt + 0.05, pam, "four_b", 2, 0.4, 0.3, -14)
	if plan.rimAt then
		sfx(plan.rimAt, Strings.later("¡TOC!"), "single", 1, 0.65, 0.3, -12)
	end
	-- Cartel final en la viñeta única: título, logo del juego y fundido a negro.
	table.insert(events, { t = 13.3, kind = "title", text = BALLGAME_TITLE, seconds = 1 })
	table.insert(events, {
		t = 14.3,
		kind = "logo",
		text = Strings.later("Primal Banana Islands"),
		sub = Strings.later("Monkey Survival"),
		seconds = 0.5,
	})
	table.insert(events, { t = 14.5, kind = "fade", seconds = 0.4, toBlack = true })
end

-- `variant`: "full" (20 s, con bandas), "reel" (15 s, ventana alta 9:16) o "comic" (15 s, páginas con viñetas). Los eventos
-- de los actores y de la pelota son los mismos; cada variante pone su cámara y sus textos.
local function ballgameScene(variant: string): Scene
	assert(variant == "full" or variant == "reel" or variant == "comic", `Ballgame: la variante {variant} no existe`)
	local full = variant == "full"
	local timing = if full then BALLGAME_TIMING.full else BALLGAME_TIMING.short
	local plan = ballgamePlan(timing)
	local events: EventList = {}
	local function add(event: { t: number, kind: string, [string]: any })
		table.insert(events, event)
	end

	if full then
		add({ t = 0, kind = "letterbox" })
	end
	-- La pelota: una trayectoria por pase (la última, el tiro con la cámara lenta) y la velocidad de las animaciones.
	for _, path in plan.paths do
		add({ t = path.times[1], kind = "ballPath", samples = path.samples, times = path.times, team = path.team })
	end
	add({ t = plan.shotAt, kind = "animSpeed", speed = BALLGAME_SLOW })
	add({ t = timing.slowEnd, kind = "animSpeed", speed = 1 })
	if plan.rimAt then
		add({ t = plan.rimAt, kind = "shake", amp = 0.15, seconds = 0.5 })
	end

	-- Los tres Jaguar: cada uno corre al contacto de cada uno de sus golpes, se gira hacia donde sale la pelota y golpea
	-- con la animación de su zona. Quien golpea tiene la pelota delante: su raíz queda BALLGAME_BEHIND detrás de ella.
	local byActor: { [string]: { BallHitPlan } } = {}
	for _, hit in plan.hits do
		byActor[hit.hitter] = byActor[hit.hitter] or {}
		table.insert(byActor[hit.hitter], hit)
	end
	local function runTo(t: number, actor: string, from: Vector3, to: Vector3, seconds: number)
		add({ t = t, kind = "anim", actor = actor, action = "Run", seconds = seconds })
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
	for actor, list in byActor do
		local pos = BALLGAME_START[actor]
		local freeAt = timing.serveAt - 0.1 -- el montaje los enseña quietos
		for _, hit in list do
			local feet =
				Vector3.new(hit.ball.X - hit.dir.X * BALLGAME_BEHIND, 0, hit.ball.Z - hit.dir.Z * BALLGAME_BEHIND)
			local arrive = hit.t - BALLGAME_HIT_LEAD
			local seconds = math.min((feet - pos).Magnitude / BALLGAME_RUN_SPEED, arrive - freeAt)
			if seconds >= 0.15 then
				runTo(arrive - seconds, actor, pos, feet, seconds)
			else
				add({ t = freeAt, kind = "move", actor = actor, pos = feet, seconds = 0 })
			end
			-- Se gira hacia la salida de la pelota y golpea (el tiro, a cámara lenta, dura más).
			add({
				t = arrive,
				kind = "move",
				actor = actor,
				pos = feet,
				yaw = yawBetween(feet, feet + hit.dir),
				seconds = 0.1,
			})
			add({
				t = arrive,
				kind = "anim",
				actor = actor,
				action = BALLGAME_HIT_ANIMATION[hit.zone],
				seconds = if hit == plan.hits[5] then 3.5 else 1,
			})
			pos = feet
			freeAt = hit.t + 0.4
		end
	end

	-- Los tres Quetzal cortan: tras cada golpe corren a ponerse entre la pelota y su aro (x fija, z según la pelota).
	local lastQuetzal: { [string]: Vector3 } = {}
	for actor, x in BALLGAME_QUETZAL_X do
		local pos = BALLGAME_START[actor]
		for index, hit in plan.hits do
			local ws = if index == 1 then timing.serveAt + 0.1 else plan.hits[index - 1].t + 0.1
			local we = hit.t - BALLGAME_HIT_LEAD
			local target = Vector3.new(x, 0, math.clamp(hit.ball.Z + BALLGAME_QUETZAL_Z[actor], -12, 12))
			local seconds = math.min(1.2, (we - ws) * 0.9)
			if seconds >= 0.15 and (target - pos).Magnitude > 0.5 then
				runTo(ws, actor, pos, target, seconds)
				pos = target
			end
		end
		lastQuetzal[actor] = pos
	end

	-- Al final el Quetzal B recoge la pelota donde se queda: corre, se agacha y se la lleva a la mano.
	local endPos = plan.endPos
	local restZ = math.clamp(endPos.Z, -CourtGeometry.TALUD_OUTER_Z + 2, CourtGeometry.TALUD_OUTER_Z - 2)
	local pickup = Vector3.new(endPos.X, CourtGeometry.surfaceY(restZ) or 0, restZ)
	local from = lastQuetzal.quetzalB
	local runAt = timing.slowEnd + 0.05
	local arrive =
		math.clamp(math.max(runAt + (pickup - from).Magnitude / 25, plan.endAt), runAt + 0.3, timing.pickupMax)
	runTo(runAt, "quetzalB", from, pickup, arrive - runAt)
	add({ t = arrive, kind = "anim", actor = "quetzalB", action = "Place", seconds = 1.2 })
	add({
		t = arrive + 0.3,
		kind = "ballPath",
		samples = { endPos, pickup + Vector3.new(0, 2.4, 0) },
		times = { arrive + 0.3, arrive + 0.7 },
		team = "Quetzal",
	})

	-- El avatar se queda mirando a los lados.
	add({ t = timing.slowEnd + 0.1, kind = "anim", actor = "avatar", action = "LookAround", seconds = 2.6 })

	-- Cámara y textos de cada variante.
	local camera: { CameraPoint }
	if full then
		-- Subtítulos, cartel final, logo y fundido (los mismos tiempos relativos que Pets y Mounts).
		camera = ballgameCamera(plan, timing)
		add({
			t = timing.serveAt + 0.6,
			kind = "caption",
			text = Strings.later("Sin manos. Solo cadera, rodilla y codo."),
			seconds = 2.4,
		})
		add({ t = plan.shotAt - 2.5, kind = "caption", text = Strings.later("Un aro. Un tiro."), seconds = 1.6 })
		add({
			t = 17.5,
			kind = "title",
			text = BALLGAME_TITLE,
			sub = Strings.later("3 contra 3 en la Isla de dunas"),
			seconds = 1.4,
		})
		add({
			t = 18.9,
			kind = "logo",
			text = Strings.later("Primal Banana Islands"),
			sub = Strings.later("Monkey Survival"),
			seconds = 0.9,
		})
		add({ t = 19.3, kind = "fade", seconds = 0.7, toBlack = true })
	elseif variant == "reel" then
		local cuts = ballgameReelCuts(plan, timing)
		camera = cutShots(battleReelShots(cuts)) :: any
		-- Colores de la cancha: rojo de la pared y crema de la arena.
		addReelPanels(events, cuts, Color3.fromRGB(190, 60, 44), Color3.fromRGB(246, 232, 196))
		addBallgameReelText(events, plan, timing)
		addBattleFade(events, true, timing.seconds)
	else
		local cuts = ballgameComicCuts(plan, timing)
		camera = cutShots(comicShots(cuts)) :: any
		addComicPages(events, cuts)
		addBallgameComicText(events, plan, timing)
	end

	local start = BALLGAME_START
	return {
		duration = timing.seconds,
		audience = "Self",
		freeze = true,
		skippable = true,
		hour = BALLGAME_HOUR,
		actors = {
			jaguarA = ballgameDummy("Jaguar", start.jaguarA, -90, Color3.fromRGB(255, 204, 153)),
			jaguarB = ballgameDummy("Jaguar", start.jaguarB, -90, Color3.fromRGB(198, 134, 92)),
			avatar = { kind = "localPlayer", copy = true, ballGear = "Jaguar", pos = start.avatar, yaw = -90 },
			quetzalA = ballgameDummy("Quetzal", start.quetzalA, 90, Color3.fromRGB(141, 85, 58)),
			quetzalB = ballgameDummy("Quetzal", start.quetzalB, 90, Color3.fromRGB(233, 183, 140)),
			quetzalC = ballgameDummy("Quetzal", start.quetzalC, 90, Color3.fromRGB(198, 134, 92)),
		},
		camera = camera,
		events = events,
	}
end

-- Si la simulación falla no se pierde el resto de cinemáticas: la escena queda sin registrar y se avisa. Cada variante va
-- en su pcall, para que una que falle no tumbe a las otras.
local ballgameOk, ballgameBuilt = pcall(ballgameScene, "full")
if not ballgameOk then
	warn(`Cinematics: no se pudo construir la escena Ballgame: {ballgameBuilt}`)
end
local ballgameReelOk, ballgameReelBuilt = pcall(ballgameScene, "reel")
if not ballgameReelOk then
	warn(`Cinematics: no se pudo construir la escena Ballgame_Reel: {ballgameReelBuilt}`)
end
local ballgameComicOk, ballgameComicBuilt = pcall(ballgameScene, "comic")
if not ballgameComicOk then
	warn(`Cinematics: no se pudo construir la escena Ballgame_Comic: {ballgameComicBuilt}`)
end

-- ============================================================================ Captura la bandera (Fase 25, G10)
-- «Flag» y «Flag_Comic»: el 5 contra 5 de Captura la bandera en la Isla de dunas (hora 16,5, solo para grabar; las lanzan
-- «🎬 Captura la bandera» y «… cómic» del panel de Dunas con DunasCineController). Anclada al origen del mundo: todas las
-- posiciones son las de la arena (suelo en y = 0; los patios de las bases, en y = 2; los Jaguar defienden x < 0 y atacan
-- hacia +x; los Quetzal, al revés; el pedestal de cada bandera, en x = ±175 con su cara de arriba en y = 3,5; las puertas, en
-- x = ±150; la pirámide del centro, de 36 de lado y 16 de alto, y su escalinata llega hasta |x| o |z| = 24 por los ejes).
-- Lo que se ve (30 s):
--    0 a  5   montaje: grúa sobre la bandera Jaguar, grúa sobre la Quetzal y los cinco Jaguar en línea ante su puerta
--    5 a 12.4 carga de los cuatro Jaguar por el carril central contra los cinco Quetzal, que rodean la pirámide por los
--             carriles de los lados; choque al oeste de la pirámide con ocho habilidades escalonadas (nunca más de 2
--             grandes a la vez, 0,4 s entre inicios). El avatar rodea la pirámide por el carril del norte
--   12.4 a 17.9 el avatar entra por la puerta Quetzal hasta el pedestal (x = 175), agacha la mano y, a cámara lenta ×0,35
--             (animSpeed), se lleva la bandera (flagGrab)
--   17.9 a 26.3 persecución de vuelta a x = -175 en tres planos con corte (la distancia, 350 studs, no cabe en 8 s a paso de
--             carrera): dos Quetzal le siguen; en el último un Jaguar los frena (shake) y llega al pedestal propio:
--             flagCapture
--   26.3 a 30 captura, cartel «Captura la bandera», logo del juego y fundido a negro
-- La variante cómic (15 s) usa las mismas acciones a la mitad de tiempo (escala FLAG_COMIC_SCALE; sin Rompehuesos, que a
-- esa velocidad rebasaría el tope de efectos grandes) en seis viñetas: bases, carga, choque, robo, persecución y captura.
-- Los cinco Jaguar son cuatro maniquíes y el avatar (copia, con el equipo de Jaguar); los cinco Quetzal, maniquíes. Van sin
-- arma y con el equipo del Juego de pelota de su bando (ballGear): sin armadura de rol, `role` no cambiaría nada. Los
-- tiempos, las posiciones y los encuadres son de diseño, a ajustar en Studio.
-- Todo el bloque va dentro de una función: el ámbito principal del módulo está en el límite de 200 locales de Luau.
local function buildFlagScenes(): { [string]: Scene? }
	local FLAG_HOUR = 16.5 -- tarde baja, entre el atardecer dorado de Pets y la hora azul
	local FLAG_SECONDS = 30
	local FLAG_COMIC_SECONDS = 15
	local FLAG_COMIC_SCALE = 0.5 -- el cómic corre la acción a la mitad de tiempo
	local FLAG_TITLE = Strings.later("Captura la bandera")
	local FLAG_STANDS = { Jaguar = Vector3.new(-175, 3.55, 0), Quetzal = Vector3.new(175, 3.55, 0) } -- techo del FlagStand
	local FLAG_ANIM_STUDS = 16 -- studs/s a los que la pista de correr va a velocidad 1
	local FLAG_RUN_SPEED = 22 -- studs/s del avatar al cruzar y de los Jaguar
	local FLAG_QUETZAL_SPEED = 24 -- los Quetzal salen más tarde y rodean la pirámide
	local FLAG_CHASE_SPEED = 21 -- la persecución
	local FLAG_CHARGE_AT = 5 -- sale la carga de los Jaguar
	local FLAG_QUETZAL_AT = 5.3 -- salen los Quetzal
	local FLAG_GATE_AT = 12.4 -- el avatar entra por la puerta Quetzal
	local FLAG_CHASE_AT = 17.9 -- empieza el primer plano de la persecución
	local FLAG_LANE_Z = 27 -- carriles por los que se rodea la pirámide (la escalinata llega a |z| = 24 en x = 0)
	local FLAG_GRAB_SLOW = 0.35 -- velocidad de la cámara lenta del robo
	local FLAG_GRAB_WAIT = 0.75 -- segundos entre llegar al pedestal y soltar la bandera del pedestal (la mano baja a cámara lenta)
	local FLAG_SLOW_SECONDS = 1.95 -- segundos de cámara lenta tras llegar al pedestal

	-- Las Y son las del suelo medido en el Studio de Dunas (Sacbe 0,25; Plaza 0,2; rampa de 12° de x = ±140,5 a ±150,3; calzada
	-- 2,10; altar 2,50): no hay Terrain donde apoyar a los actores, así que se colocan con la Y que se les da.
	local FLAG_START: { [string]: Vector3 } = {
		jaguarA = Vector3.new(-141, 0.25, -16),
		jaguarB = Vector3.new(-139, 0.25, -8),
		avatar = Vector3.new(-140, 0.25, 0),
		jaguarC = Vector3.new(-139, 0.25, 8),
		jaguarD = Vector3.new(-141, 0.25, 16),
		quetzalA = Vector3.new(60, 0.2, -24),
		quetzalB = Vector3.new(58, 0.2, -12),
		quetzalC = Vector3.new(60, 0.2, 0),
		quetzalD = Vector3.new(58, 0.2, 12),
		quetzalE = Vector3.new(60, 0.2, 24),
		quetzalG = Vector3.new(164, 2.1, -5.5), -- la guardia, junto al pedestal Quetzal: ve entrar al avatar y se gira a verlo robar
	}
	-- Dónde chocan (al oeste de la pirámide) y por qué carril rodea cada Quetzal (signo de z).
	local FLAG_CLASH: { [string]: Vector3 } = {
		jaguarA = Vector3.new(-37, 0.15, -12),
		jaguarB = Vector3.new(-38, 0.15, -4),
		jaguarC = Vector3.new(-38, 0.15, 5),
		jaguarD = Vector3.new(-37, 0.15, 13),
		quetzalA = Vector3.new(-30, 0.15, -12),
		quetzalB = Vector3.new(-31, 0.15, -4),
		quetzalC = Vector3.new(-30, 0.15, 5),
		quetzalD = Vector3.new(-31, 0.15, 13),
		quetzalE = Vector3.new(-29, 0.15, 21),
	}
	-- La embestida del Guerrero Jaguar: corre hasta FLAG_A_WINDUP, espera a que lleguen todos y embiste hasta FLAG_A_CHARGE_END.
	local FLAG_A_WINDUP = Vector3.new(-53, 0.15, -12)
	local FLAG_A_CHARGE_END = Vector3.new(-32.5, 0.15, -12)
	local FLAG_A_WHIRL_END = Vector3.new(-28.5, 0.15, -12)
	local FLAG_A_CHARGE_SECONDS = 0.6
	local FLAG_A_WHIRL_SECONDS = 1.2
	local FLAG_LANE: { [string]: number } = { quetzalA = -1, quetzalB = -1, quetzalC = 1, quetzalD = 1, quetzalE = 1 }
	-- Los recorridos del avatar (los dos Quetzal que le siguen van desplazados de él, ver flagShift). Waypoints medidos con rayos
	-- (sin obstáculos, a más de 3 studs de pilares y muros).
	local FLAG_ROUTES: { [string]: { Vector3 } } = {
		-- Rodea la pirámide por el carril del norte mientras los demás chocan.
		charge = {
			FLAG_START.avatar,
			Vector3.new(-112, 0.1, 2),
			Vector3.new(-80, 0, 18),
			Vector3.new(-60, 0, 24),
			Vector3.new(-30, 0.1, 24),
			Vector3.new(-14, 0.2, FLAG_LANE_Z + 2),
			Vector3.new(14, 0.2, FLAG_LANE_Z + 2),
		},
		-- Por la puerta Quetzal, la rampa y la calzada hasta el pedestal (el altar está a y = 2,5).
		gate = {
			Vector3.new(100, 0, 6),
			Vector3.new(122, 0, 0),
			Vector3.new(141, 0.47, 0),
			Vector3.new(150, 2.39, 0),
			Vector3.new(152, 2.1, 0),
			Vector3.new(169.5, 2.1, 0),
			Vector3.new(171.5, 2.5, 0),
		},
		chase1 = {
			Vector3.new(171.5, 2.5, 0),
			Vector3.new(169.5, 2.1, 0),
			Vector3.new(152, 2.1, 0),
			Vector3.new(150, 2.39, 0),
			Vector3.new(141, 0.47, 0),
			Vector3.new(139, 0.25, 0),
			Vector3.new(122, 0.25, 0),
		},
		chase2 = { Vector3.new(48, 0.2, 26), Vector3.new(-8, 0.2, 26) },
		chase3 = {
			Vector3.new(-104, 0.25, 4),
			Vector3.new(-139, 0.25, 0),
			Vector3.new(-141, 0.47, 0),
			Vector3.new(-150, 2.39, 0),
			Vector3.new(-152, 2.1, 0),
			Vector3.new(-169.5, 2.1, 0),
			Vector3.new(-171.5, 2.5, 0),
		},
	}

	local function flagRouteLength(points: { Vector3 }): number
		local total = 0
		for index = 2, #points do
			total += (points[index] - points[index - 1]).Magnitude
		end
		return total
	end

	-- Dónde está quien recorre `points` a velocidad constante desde t0, en el segundo t.
	local function flagRouteAt(points: { Vector3 }, t0: number, speed: number, t: number): Vector3
		local distance = math.clamp((t - t0) * speed, 0, flagRouteLength(points))
		for index = 2, #points do
			local leg = (points[index] - points[index - 1]).Magnitude
			if distance <= leg then
				return points[index - 1]:Lerp(points[index], if leg > 0 then distance / leg else 1)
			end
			distance -= leg
		end
		return points[#points]
	end

	local function flagShift(points: { Vector3 }, dx: number, dz: number): { Vector3 }
		local shifted = {}
		for _, point in points do
			table.insert(shifted, point + Vector3.new(dx, 0, dz))
		end
		return shifted
	end

	-- El recorrido de un Quetzal hasta el choque: rodea la pirámide por su carril.
	local function flagLaneRoute(name: string): { Vector3 }
		local z = FLAG_LANE[name] * FLAG_LANE_Z
		return { FLAG_START[name], Vector3.new(38, 0.2, z), Vector3.new(-26, 0.15, z), FLAG_CLASH[name] }
	end

	-- El segundo en que el último llega al choque.
	local function flagContact(): number
		local contact = 0
		for _, name in { "jaguarA", "jaguarB", "jaguarC", "jaguarD" } do
			local length = flagRouteLength({ FLAG_START[name], FLAG_CLASH[name] })
			contact = math.max(contact, FLAG_CHARGE_AT + length / FLAG_RUN_SPEED)
		end
		for name in FLAG_LANE do
			contact = math.max(contact, FLAG_QUETZAL_AT + flagRouteLength(flagLaneRoute(name)) / FLAG_QUETZAL_SPEED)
		end
		return contact
	end

	type FlagTiming = {
		contact: number, -- llegan al choque
		gateEnd: number, -- el avatar llega al pedestal Quetzal
		grabAt: number, -- suelta la bandera del pedestal (flagGrab)
		slowEnd: number, -- vuelve la velocidad normal
		c1Start: number,
		c2Start: number,
		c3Start: number,
		captureAt: number, -- flagCapture
	}

	local function flagTiming(): FlagTiming
		local gateEnd = FLAG_GATE_AT + flagRouteLength(FLAG_ROUTES.gate) / FLAG_RUN_SPEED
		local c1Start = FLAG_CHASE_AT
		local c2Start = c1Start + flagRouteLength(FLAG_ROUTES.chase1) / FLAG_CHASE_SPEED
		local c3Start = c2Start + flagRouteLength(FLAG_ROUTES.chase2) / FLAG_CHASE_SPEED
		local c3End = c3Start + flagRouteLength(FLAG_ROUTES.chase3) / FLAG_CHASE_SPEED
		assert(
			gateEnd + FLAG_SLOW_SECONDS < c1Start,
			`Flag: la cámara lenta ({gateEnd}) no cabe antes de la persecución`
		)
		return {
			contact = flagContact(),
			gateEnd = gateEnd,
			grabAt = gateEnd + FLAG_GRAB_WAIT,
			slowEnd = gateEnd + FLAG_SLOW_SECONDS,
			c1Start = c1Start,
			c2Start = c2Start,
			c3Start = c3Start,
			captureAt = c3End + 0.15,
		}
	end

	-- Dónde está `name` en el segundo t de la acción (sin escalar: el cómic lo divide entre FLAG_COMIC_SCALE), siguiendo los
	-- mismos recorridos que flagScene. Sirve para encuadrar a los personajes en un instante, sin puntos fijos. Aproxima los
	-- gestos sueltos (el empujón de la carga del Jaguar, la esquiva de los Quetzal).
	local function flagActorAt(timing: FlagTiming, name: string, t: number): Vector3
		if name == "avatar" then
			if t < FLAG_GATE_AT then
				return flagRouteAt(FLAG_ROUTES.charge, FLAG_CHARGE_AT, FLAG_RUN_SPEED, t)
			elseif t < timing.c1Start then
				return flagRouteAt(FLAG_ROUTES.gate, FLAG_GATE_AT, FLAG_RUN_SPEED, t)
			elseif t < timing.c2Start then
				return flagRouteAt(FLAG_ROUTES.chase1, timing.c1Start, FLAG_CHASE_SPEED, t)
			elseif t < timing.c3Start then
				return flagRouteAt(FLAG_ROUTES.chase2, timing.c2Start, FLAG_CHASE_SPEED, t)
			end
			return flagRouteAt(FLAG_ROUTES.chase3, timing.c3Start, FLAG_CHASE_SPEED, t)
		end
		if name == "quetzalG" then
			return FLAG_START.quetzalG
		end
		if FLAG_LANE[name] == nil then -- un Jaguar
			if name == "jaguarA" then
				if t >= timing.c3Start then
					local k = math.clamp((t - timing.c3Start - 0.35) / 0.35, 0, 1)
					return Vector3.new(-92, 0.1, 1):Lerp(Vector3.new(-88, 0.1, 0), k)
				end
				local chargeAt = timing.contact - 0.35
				if t >= chargeAt then
					local k = math.clamp((t - chargeAt) / FLAG_A_CHARGE_SECONDS, 0, 1)
					local whirl = math.clamp((t - timing.contact - 0.3) / FLAG_A_WHIRL_SECONDS, 0, 1)
					return FLAG_A_WINDUP:Lerp(FLAG_A_CHARGE_END, k):Lerp(FLAG_A_WHIRL_END, whirl)
				end
				return flagRouteAt({ FLAG_START[name], FLAG_A_WINDUP }, FLAG_CHARGE_AT, FLAG_RUN_SPEED, t)
			end
			return flagRouteAt({ FLAG_START[name], FLAG_CLASH[name] }, FLAG_CHARGE_AT, FLAG_RUN_SPEED, t)
		end
		if (name == "quetzalD" or name == "quetzalE") and t >= timing.c1Start then
			local isD = name == "quetzalD"
			if t >= timing.c3Start then
				local z = if isD then 4 else -4
				local k = math.clamp((t - timing.c3Start - 0.7) / 0.4, 0, 1)
				return Vector3.new(-82, 0.1, z):Lerp(Vector3.new(-72, 0.1, z * 1.25), k)
			end
			local dx, dz = if isD then 14 else 17, if isD then -2.5 else 2.5
			if t >= timing.c2Start then
				return flagRouteAt(flagShift(FLAG_ROUTES.chase2, dx, dz), timing.c2Start, FLAG_CHASE_SPEED, t)
			end
			return flagRouteAt(flagShift(FLAG_ROUTES.chase1, dx, dz), timing.c1Start, FLAG_CHASE_SPEED, t)
		end
		if name == "quetzalA" and t >= timing.contact + 0.75 then
			return Vector3.new(-25.5, 0.15, -13.5) -- ya lanzada por la embestida
		end
		return flagRouteAt(flagLaneRoute(name), FLAG_QUETZAL_AT, FLAG_QUETZAL_SPEED, t)
	end

	-- La cámara de la persecución: detrás y a un lado de quien corre hacia -x, mirando un poco por delante.
	local function flagChaseView(at: Vector3): (Vector3, Vector3, number)
		return at + Vector3.new(8, 4.5, -5.5), at + Vector3.new(-6, 2.7, 0), 58
	end

	-- Los planos de la versión normal. Posiciones de diseño, dentro de la arena (sin pasar de los muros de los carriles, z = ±35,
	-- ni de los muros de las bases).
	local function flagCamera(timing: FlagTiming): { CameraPoint }
		local camera: { CameraPoint } = {}
		-- Corte seco: cada plano empieza 0,05 s después de acabar el anterior (los puntos repetidos evitan que la spline se curve).
		local function put(t0: number, t1: number, a: CameraPoint, b: CameraPoint)
			pushShot(camera, if t0 == 0 then 0 else t0 + 0.05, t1, a, b)
		end
		local function follow(t0: number, t1: number, at: (t: number) -> (Vector3, Vector3, number))
			ballgameFollow(camera, t0 + 0.05, t1, at)
		end
		local jaguarFlag, quetzalFlag = FLAG_STANDS.Jaguar, FLAG_STANDS.Quetzal

		-- Montaje: grúa sobre cada bandera (el patio de la base) y los Jaguar en línea ante su puerta.
		put(
			0,
			1.9,
			shot(jaguarFlag + Vector3.new(7, 1, -12), jaguarFlag + Vector3.new(0, 2.5, 0), 55),
			shot(jaguarFlag + Vector3.new(9, 9.5, -14), jaguarFlag + Vector3.new(0, 3.5, 0), 50)
		)
		put(
			1.9,
			3.8,
			shot(quetzalFlag + Vector3.new(-7, 1, -12), quetzalFlag + Vector3.new(0, 2.5, 0), 55),
			shot(quetzalFlag + Vector3.new(-9, 9.5, -14), quetzalFlag + Vector3.new(0, 3.5, 0), 50)
		)
		put(
			3.8,
			FLAG_CHARGE_AT,
			shot(Vector3.new(-120, 3.5, 0), Vector3.new(-140, 4, 0), 62),
			shot(Vector3.new(-122, 3.6, 0), Vector3.new(-140, 4.2, 0), 58)
		)
		-- La carga, vista de lado desde el carril (los Jaguar corren hacia la cámara y la cruzan).
		put(
			FLAG_CHARGE_AT,
			8,
			shot(Vector3.new(-118, 6.5, -28), Vector3.new(-135, 3, -2), 58),
			shot(Vector3.new(-100, 6.5, -28), Vector3.new(-95, 3.5, 0), 54)
		)
		-- El choque: general desde el hueco del centro y primer plano de lado.
		put(
			8,
			10.9,
			shot(Vector3.new(-22, 11, -30), Vector3.new(-42, 3, 0), 55),
			shot(Vector3.new(-24, 10, -26), Vector3.new(-42, 3, 0), 50)
		)
		put(
			10.9,
			FLAG_GATE_AT,
			shot(Vector3.new(-24, 5, 10), Vector3.new(-42, 4, -2), 50),
			shot(Vector3.new(-26, 5, 8), Vector3.new(-43, 4, -2), 46)
		)
		-- El avatar entra por la puerta Quetzal, pasa el umbral y llega al pedestal.
		put(
			FLAG_GATE_AT,
			14.2,
			shot(Vector3.new(118, 5, 22), Vector3.new(95, 3, 12), 56),
			shot(Vector3.new(130, 5, 20), Vector3.new(144, 3, 2), 52)
		)
		put(
			14.2,
			timing.gateEnd + 0.15,
			shot(Vector3.new(158, 5.5, -13), Vector3.new(150, 3.5, 0), 55),
			shot(Vector3.new(160, 5.5, -12), Vector3.new(168, 4, 0), 50)
		)
		-- El robo, a cámara lenta: de lado, con la mano del avatar y el mástil.
		put(
			timing.gateEnd + 0.15,
			timing.c1Start,
			shot(Vector3.new(167, 5, -8), Vector3.new(173, 4.2, 0), 44),
			shot(Vector3.new(168.5, 5, -6.5), Vector3.new(174, 4.6, 0), 36)
		)
		-- La persecución: tres planos con corte, siempre detrás del avatar. El último empieza con el bloqueo del Jaguar.
		follow(timing.c1Start, timing.c2Start, function(t)
			return flagChaseView(flagRouteAt(FLAG_ROUTES.chase1, timing.c1Start, FLAG_CHASE_SPEED, t))
		end)
		follow(timing.c2Start, timing.c3Start, function(t)
			return flagChaseView(flagRouteAt(FLAG_ROUTES.chase2, timing.c2Start, FLAG_CHASE_SPEED, t))
		end)
		put(
			timing.c3Start,
			timing.c3Start + 1.3,
			shot(Vector3.new(-108, 5, -11), Vector3.new(-92, 3, 0), 58),
			shot(Vector3.new(-106, 5, -11), Vector3.new(-96, 3, 0), 56)
		)
		follow(timing.c3Start + 1.3, timing.captureAt, function(t)
			return flagChaseView(flagRouteAt(FLAG_ROUTES.chase3, timing.c3Start, FLAG_CHASE_SPEED, t))
		end)
		-- La captura en el pedestal propio.
		put(
			timing.captureAt,
			FLAG_SECONDS,
			shot(jaguarFlag + Vector3.new(15, 2.5, -10), jaguarFlag + Vector3.new(-1, 2, 0), 50),
			shot(jaguarFlag + Vector3.new(20, 4, -12), jaguarFlag + Vector3.new(-1, 3, 0), 42)
		)
		return camera
	end

	-- Los cortes de Flag_Comic, en tres páginas y con los tiempos de la acción a la mitad (FLAG_COMIC_SCALE). Cada encuadre sale
	-- de dónde están los personajes en ese instante (flagActorAt) y abarca solo a 2 o 3 armados, para que llenen la viñeta: una
	-- viñeta congelada guarda solo a los personajes (y las banderas) sobre fondo liso.
	--    P1 four_a  0 a ~ 6,2   Jaguar (grande), Quetzal y médico y mago Jaguar en 0,5 s cada uno; la carga y el choque
	--    P2 two     ~ 6,2 a 11,45 la entrada por la puerta; el robo y la persecución
	--    P3 single  11,45 a 15  el bloqueo del Jaguar, el último tramo y la captura, con el cartel, el logo y el fundido
	local function flagComicCuts(timing: FlagTiming): { ComicCut }
		local cuts: { ComicCut } = {}
		local scale = FLAG_COMIC_SCALE
		local CHASERS = { "avatar", "quetzalD", "quetzalE" }
		local function addPage(
			layout: string,
			colors: { Color3 },
			wipe: string?,
			cells: { ComicCell },
			order: { number }
		)
			for index, c in cells do
				table.insert(cuts, {
					t0 = c.t0,
					t1 = c.t1,
					layout = layout,
					page = if index == 1 then { layout = layout, colors = colors, wipe = wipe } else nil,
					cell = order[index],
					pos = c.pos,
					posB = c.posB,
					subject = c.subject,
					subjectB = c.subjectB,
					width = c.width,
					widthB = c.widthB,
					bg = c.bg,
				})
			end
		end

		-- Centro y radio (en el suelo) de los personajes `names` en el segundo `t` de la acción.
		local function groupAt(names: { string }, t: number): (Vector3, number)
			local sum = Vector3.zero
			local points = {}
			for _, name in names do
				local at = flagActorAt(timing, name, t)
				table.insert(points, at)
				sum += at
			end
			local center = sum / #points
			local radius = 0
			for _, at in points do
				radius = math.max(radius, (at - center).Magnitude)
			end
			return center, radius
		end
		-- El plano que tiene a `names` en el segundo de cómic `c`: la cámara a `offset` del centro (a la altura del pecho) y un ancho
		-- que los abarca con poco margen (nunca menos de `minWidth`).
		local function framed(
			names: { string },
			c: number,
			offset: Vector3,
			minWidth: number
		): (Vector3, Vector3, number)
			local center, radius = groupAt(names, c / scale)
			local subject = center + Vector3.new(0, 2.8, 0)
			return subject + offset, subject, math.max(minWidth, radius * 2 + 3)
		end
		-- Una viñeta de c0 a c1 (segundos de cómic) que va del encuadre del principio al del final.
		local function cellOf(
			c0: number,
			c1: number,
			names: { string },
			offset: Vector3,
			minWidth: number,
			bg: string
		): ComicCell
			local posA, subjectA, widthA = framed(names, c0, offset, minWidth)
			local posB, subjectB, widthB = framed(names, c1, offset, minWidth)
			local cell = comicCell(c0, c1, posA, subjectA, widthA, bg, subjectB)
			cell.posB = posB
			cell.widthB = widthB
			return cell
		end
		-- Lo mismo en tramos de ~`step` s, para que la cámara siga a quien se mueve (la posición de un tramo a otro es continua).
		local function followCells(
			c0: number,
			c1: number,
			step: number,
			names: { string },
			offset: Vector3,
			minWidth: number,
			bg: string
		): { ComicCell }
			local out: { ComicCell } = {}
			local count = math.max(1, math.round((c1 - c0) / step))
			for index = 1, count do
				local a = c0 + (c1 - c0) * (index - 1) / count
				local b = c0 + (c1 - c0) * index / count
				table.insert(out, cellOf(a, b, names, offset, minWidth, bg))
			end
			return out
		end
		local function append(list: { ComicCell }, order: { number }, index: number, items: { ComicCell })
			for _, item in items do
				table.insert(list, item)
				table.insert(order, index)
			end
		end

		local gateAt = FLAG_GATE_AT * scale
		local gateEnd = timing.gateEnd * scale + 0.1
		local chaseAt = timing.c1Start * scale
		local chase2At = timing.c2Start * scale
		local chase3At = timing.c3Start * scale
		local captureAt = timing.captureAt * scale
		local contactAt = timing.contact * scale

		-- P1: tres retratos de 0,5 s (los Jaguar en su base, los Quetzal en la suya y el mago y el médico Jaguar) llenan los
		-- recuadros al empezar; la cuarta viñeta sigue la carga del Guerrero y el Cazador Jaguar y luego el choque. Las páginas de
		-- cuatro empiezan por la viñeta grande (la 4): de ahí el orden {4, 1, 2, 3}.
		local cells1: { ComicCell } = {}
		local order1: { number } = {}
		append(cells1, order1, 4, {
			cellOf(0, 0.55, { "jaguarB", "avatar", "jaguarC" }, Vector3.new(22, 2, -3), 24, "flat"),
		})
		append(cells1, order1, 1, {
			cellOf(0.55, 1.1, { "quetzalB", "quetzalC", "quetzalD" }, Vector3.new(-15, 2.5, -9), 22, "dots"),
		})
		append(cells1, order1, 2, {
			cellOf(1.1, 1.65, { "jaguarC", "jaguarD" }, Vector3.new(18, 2, -4), 14, "flat"),
		})
		local runEnd = contactAt - 0.3
		append(
			cells1,
			order1,
			3,
			followCells(1.65, runEnd, 0.45, { "jaguarA", "jaguarB" }, Vector3.new(20, 2.5, -6), 14, "dots")
		)
		append(
			cells1,
			order1,
			3,
			followCells(runEnd, gateAt, 0.6, { "jaguarA", "quetzalA", "quetzalB" }, Vector3.new(8, 6, -20), 16, "dots")
		)
		addPage("four_a", COMIC_COLORS.montage, nil, cells1, order1)

		-- P2: la entrada del avatar hasta junto a la guardia (viñeta 1); luego, en la 2, el robo, la persecución de frente por la
		-- calzada y por el carril del norte. Los Quetzal que le siguen van detrás del avatar: la cámara, de frente, los tiene a
		-- todos en línea.
		local cells2: { ComicCell } = {}
		local order2: { number } = {}
		local entryEnd = gateAt + 1.2
		append(
			cells2,
			order2,
			1,
			followCells(gateAt, entryEnd, 0.4, { "avatar", "quetzalG" }, Vector3.new(-9, 2, -9), 12, "dots")
		)
		append(
			cells2,
			order2,
			2,
			followCells(entryEnd, gateEnd, 0.4, { "avatar", "quetzalG" }, Vector3.new(-6, 1.8, -9), 11, "flat")
		)
		append(
			cells2,
			order2,
			2,
			{ cellOf(gateEnd, chaseAt, { "avatar", "quetzalG" }, Vector3.new(-4, 1.5, -9), 10, "flat") }
		)
		append(cells2, order2, 2, followCells(chaseAt, chase2At, 0.4, CHASERS, Vector3.new(-12, 2.2, -3), 11, "flat"))
		append(cells2, order2, 2, followCells(chase2At, chase3At, 0.4, CHASERS, Vector3.new(-12, 2.2, 2), 11, "flat"))
		addPage("two", COMIC_COLORS.mountain, "left", cells2, order2)

		-- P3: el Guerrero Jaguar frena a los dos Quetzal, el último tramo hasta el pedestal propio y la captura. Una sola viñeta.
		local cells3: { ComicCell } = {}
		local order3: { number } = {}
		local blockEnd = chase3At + 0.9
		append(cells3, order3, 1, {
			cellOf(chase3At, blockEnd, { "jaguarA", "quetzalD", "quetzalE" }, Vector3.new(-12, 4, -17), 18, "flat"),
		})
		append(
			cells3,
			order3,
			1,
			followCells(blockEnd, captureAt, 0.4, { "avatar" }, Vector3.new(9, 2, -6.5), 11, "flat")
		)
		append(
			cells3,
			order3,
			1,
			{ cellOf(captureAt, FLAG_COMIC_SECONDS, { "avatar" }, Vector3.new(11, 0.5, -9), 13, "flat") }
		)
		addPage("single", COMIC_COLORS.mangrove, "left", cells3, order3)
		return cuts
	end

	-- Narración, bocadillos y onomatopeyas de Flag_Comic. Con el orden {4, 1, 2, 3} la viñeta k de la lista muestra la celda order[k] de
	-- la plantilla: las onomatopeyas llevan el índice de la celda de la plantilla (P1: 3 la carga y el choque; P2 "two": 1 la entrada,
	-- 2 el robo y la persecución; P3: 1). Un texto cada ~1,5 s, para que ninguna página se quede muda.
	local function addFlagComicText(events: EventList, timing: FlagTiming)
		local scale = FLAG_COMIC_SCALE
		local function narration(t: number, text: string, seconds: number)
			table.insert(events, {
				t = t,
				kind = "bubble",
				balloon = "narration",
				corner = "BL",
				onPage = true,
				text = text,
				seconds = seconds,
			})
		end
		local function speech(t: number, actor: string, text: string, seconds: number)
			table.insert(
				events,
				{ t = t, kind = "bubble", balloon = "speech", actor = actor, text = text, seconds = seconds }
			)
		end
		local lastSfx = -math.huge
		local function sfx(t: number, text: string, layout: string, cell: number, fx: number, fy: number, rot: number)
			if t - lastSfx < 0.7 then
				return -- ninguna onomatopeya pisa a la anterior
			end
			lastSfx = t
			table.insert(events, {
				t = t,
				kind = "sfx",
				text = text,
				pos = ComicPages.cellPoint(layout, cell, fx, fy),
				rot = rot,
				size = 0.3,
				color = Color3.new(1, 1, 1),
				seconds = 0.6,
			})
		end
		local contact = timing.contact * scale
		local grab = timing.grabAt * scale
		local chase = timing.c1Start * scale
		local block = timing.c3Start * scale
		narration(0.2, Strings.later("Dos bases. Una bandera cada una."), 1.4)
		sfx(FLAG_CHARGE_AT * scale + 0.1, Strings.later("¡ZUM!"), "four_a", 3, 0.5, 0.3, -10)
		sfx(contact + 0.05, Strings.later("¡PAM!"), "four_a", 3, 0.5, 0.3, -12)
		sfx(contact + 0.8, Strings.later("¡ZAS!"), "four_a", 3, 0.3, 0.7, 12)
		narration(FLAG_GATE_AT * scale + 0.1, Strings.later("Roba la bandera rival."), 1.8)
		speech(grab - 0.1, "avatar", Strings.later("¡Mía!"), 0.7)
		sfx(grab + 0.05, Strings.later("¡ÑAP!"), "two", 2, 0.55, 0.25, -10)
		sfx(chase + 0.7, Strings.later("¡FIUU!"), "two", 2, 0.6, 0.25, 12)
		narration(block + 0.15, Strings.later("Y llévala a tu base."), 1.9)
		speech(block + 0.1, "jaguarA", Strings.later("¡Alto ahí!"), 0.7)
		sfx(block + 0.35, Strings.later("¡PAM!"), "single", 1, 0.3, 0.3, -12)
		sfx(timing.captureAt * scale, Strings.later("¡BUM!"), "single", 1, 0.6, 0.3, -12)
		-- Cartel final en la viñeta única: título, logo del juego y fundido a negro.
		table.insert(events, { t = 13.7, kind = "title", text = FLAG_TITLE, seconds = 1 })
		table.insert(events, {
			t = 14.4,
			kind = "logo",
			text = Strings.later("Primal Banana Islands"),
			sub = Strings.later("Monkey Survival"),
			seconds = 0.5,
		})
		table.insert(events, { t = 14.55, kind = "fade", seconds = 0.4, toBlack = true })
	end

	-- Un maniquí armado de su bando: la armadura y el arma de su rol (WeaponTools.roleWeapon al nivel máximo) y la marca del equipo.
	local function flagDummy(
		team: string,
		role: string,
		armor: string,
		pos: Vector3,
		yaw: number,
		skin: Color3
	): { [string]: any }
		return { kind = "dummy", role = role, armor = armor, team = team, pos = pos, yaw = yaw, skinColor = skin }
	end

	-- `variant`: "full" (30 s, con bandas) o "comic" (15 s, páginas con viñetas). Las acciones son las mismas; el cómic las corre a la
	-- mitad de tiempo y pone su cámara y sus textos.
	local function flagScene(variant: string): Scene
		assert(variant == "full" or variant == "comic", `Flag: la variante {variant} no existe`)
		local comic = variant == "comic"
		local scale = if comic then FLAG_COMIC_SCALE else 1
		local timing = flagTiming()
		local events: EventList = {}
		-- Un evento de la acción, con el tiempo y las duraciones a la escala de la variante.
		local function add(event: { t: number, kind: string, [string]: any })
			if scale ~= 1 then
				event = table.clone(event)
				event.t *= scale
				if event.seconds then
					event.seconds *= scale
				end
				if event.args and event.args.seconds then
					event.args = table.clone(event.args)
					event.args.seconds *= scale
				end
			end
			table.insert(events, event)
		end
		-- `speed` (solo Run y Walk): velocidad de la pista (1 = ~16 studs/s); no se escala con la variante, la calcula quien llama.
		local function anim(t: number, actor: string, action: string, seconds: number?, speed: number?)
			add({ t = t, kind = "anim", actor = actor, action = action, seconds = seconds, speed = speed })
		end
		local function fx(t: number, name: string, from: string, to: any, args: { [string]: any }?)
			add({ t = t, kind = "abilityFx", fx = name, from = from, to = to, args = args })
		end
		local function place(t: number, actor: string, pos: Vector3, yaw: number)
			add({ t = t, kind = "move", actor = actor, pos = pos, yaw = yaw, seconds = 0 })
		end
		-- Un recorrido a velocidad constante: en cada tramo se pone al actor mirando hacia donde va y se le mueve. Devuelve el segundo
		-- en que llega.
		local function route(actor: string, t0: number, points: { Vector3 }, speed: number): number
			-- La pista corre al paso de lo que se mueve: studs/s reales (en el cómic, el doble) entre los ~16 de la animación.
			anim(t0, actor, "Run", flagRouteLength(points) / speed, speed / scale / FLAG_ANIM_STUDS)
			local t = t0
			for index = 2, #points do
				local seconds = (points[index] - points[index - 1]).Magnitude / speed
				if seconds > 0.01 then
					local yaw = yawBetween(points[index - 1], points[index])
					place(t, actor, points[index - 1], yaw)
					add({
						t = t,
						kind = "move",
						actor = actor,
						pos = points[index],
						yaw = yaw,
						seconds = seconds,
						easing = Enum.EasingStyle.Linear,
					})
					t += seconds
				end
			end
			return t
		end

		if not comic then
			add({ t = 0, kind = "letterbox" })
		end
		add({ t = 0, kind = "flagProp", stands = FLAG_STANDS })

		-- La carga: los cuatro Jaguar van derechos al choque; los Quetzal rodean la pirámide por su carril y llegan al choque.
		local contact = 0 -- el segundo en que el último llega al choque
		for _, name in { "jaguarB", "jaguarC", "jaguarD" } do
			contact =
				math.max(contact, route(name, FLAG_CHARGE_AT, { FLAG_START[name], FLAG_CLASH[name] }, FLAG_RUN_SPEED))
		end
		-- El Guerrero Jaguar corre hasta el arranque de su embestida (más abajo) y espera a que lleguen los demás.
		route("jaguarA", FLAG_CHARGE_AT, { FLAG_START.jaguarA, FLAG_A_WINDUP }, FLAG_RUN_SPEED)
		contact = math.max(
			contact,
			FLAG_CHARGE_AT + flagRouteLength({ FLAG_START.jaguarA, FLAG_CLASH.jaguarA }) / FLAG_RUN_SPEED
		)
		for name in FLAG_LANE do
			contact = math.max(contact, route(name, FLAG_QUETZAL_AT, flagLaneRoute(name), FLAG_QUETZAL_SPEED))
		end
		-- El avatar se cuela por el carril del norte y, ya fuera de plano, aparece junto a la puerta Quetzal.
		local sneakEnd = route("avatar", FLAG_CHARGE_AT, FLAG_ROUTES.charge, FLAG_RUN_SPEED)
		if sneakEnd > FLAG_GATE_AT then
			warn(`Flag: el avatar tarda {sneakEnd} s en rodear la pirámide y la puerta se abre a {FLAG_GATE_AT}`)
		end

		-- El choque, con las habilidades de cada rol saliendo del actor que corre (todos los tiempos, relativos a `contact`, son de
		-- la versión larga: el cómic los corre a la mitad). Una habilidad por actor, el rival reacciona con anim y move, y nunca
		-- más de 2 efectos grandes (AbilityShow.SPECS) a la vez ni a menos de 0,4 s: Torbellino (+0,3 a +2,0), Nova o Rayo
		-- (+0,75), Curación en área (+2,05). La Nova (grande) solo en la larga: en el cómic la hace un Rayo.
		local c = contact
		-- Una víctima salta hacia atrás: sube con un impulso y cae un poco más allá (el suelo es y0 de `from`).
		local function hop(t: number, actor: string, from: Vector3, to: Vector3, yaw: number)
			anim(t, actor, "DodgeBack", 0.8)
			add({
				t = t,
				kind = "move",
				actor = actor,
				pos = from:Lerp(to, 0.5) + Vector3.new(0, 1.8, 0),
				yaw = yaw,
				seconds = 0.25,
				easing = Enum.EasingStyle.Quad,
			})
			add({
				t = t + 0.25,
				kind = "move",
				actor = actor,
				pos = to,
				yaw = yaw,
				seconds = 0.3,
				easing = Enum.EasingStyle.Quad,
			})
		end
		-- De lejos: el Guerrero Jaguar grita; el Mago Jaguar lanza una bola de fuego al Cazador Quetzal, el Cazador Jaguar dispara
		-- una andanada al Médico Quetzal y el Cazador Quetzal le contesta. Las víctimas lo notan (con anim: aún corren).
		anim(c - 3.4, "jaguarA", "WarCry", 0.9)
		fx(c - 3.3, "WarCry", "jaguarA", nil, { seconds = 0.9 })
		anim(c - 2.2, "jaguarC", "Spell", 0.6)
		fx(c - 2.08, "Fireball", "jaguarC", "quetzalC")
		anim(c - 1.2, "quetzalC", "DodgeBack", 0.7)
		anim(c - 1.7, "jaguarB", "Arrow", 0.7)
		fx(c - 1.54, "MultiShot", "jaguarB", "quetzalB")
		anim(c - 0.9, "quetzalB", "DodgeBack", 0.7)
		anim(c - 1.1, "quetzalC", "Arrow", 0.7)
		fx(c - 0.94, "MultiShot", "quetzalC", "jaguarB")
		anim(c - 0.3, "jaguarB", "DodgeBack", 0.7)
		-- Embestida del Guerrero Jaguar contra el Guerrero Quetzal: llega a su sitio, el Quetzal sale despedido por los aires y el
		-- Torbellino sigue avanzando entre ellos.
		local charge = c - 0.35
		anim(charge, "jaguarA", "Charge", 0.7)
		fx(charge + 0.05, "Charge", "jaguarA", nil, { seconds = 0.7 })
		add({
			t = charge,
			kind = "move",
			actor = "jaguarA",
			pos = FLAG_A_CHARGE_END,
			yaw = -90,
			seconds = FLAG_A_CHARGE_SECONDS,
			easing = Enum.EasingStyle.Quad,
		})
		add({ t = c + 0.1, kind = "shake", amp = 0.2, seconds = 0.4 })
		hop(c + 0.1, "quetzalA", FLAG_CLASH.quetzalA, Vector3.new(-25.5, 0.15, -13.5), 90)
		anim(c + 0.3, "jaguarA", "Whirlwind", FLAG_A_WHIRL_SECONDS) -- grande (hasta c + 2,0)
		fx(c + 0.3, "Whirlwind", "jaguarA", nil, { seconds = FLAG_A_WHIRL_SECONDS })
		add({
			t = c + 0.3,
			kind = "move",
			actor = "jaguarA",
			pos = FLAG_A_WHIRL_END,
			yaw = -90,
			seconds = FLAG_A_WHIRL_SECONDS,
			easing = Enum.EasingStyle.Linear,
		})
		-- El Mago Quetzal (que sigue el choque desde el sur) lanza su hechizo sobre el Mago Jaguar: Nova de hielo en la larga, Rayo
		-- en el cómic. El Mago Jaguar sale despedido.
		if comic then
			anim(c + 0.65, "quetzalE", "CastForward", 0.6)
			fx(c + 0.75, "Lightning", "quetzalE", "jaguarC")
		else
			anim(c + 0.65, "quetzalE", "CastArea", 1)
			fx(c + 0.75, "FrostNova", "quetzalE", "jaguarC", { radius = 7 }) -- grande (hasta c + 2,55)
		end
		hop(c + 0.95, "jaguarC", FLAG_CLASH.jaguarC, Vector3.new(-42, 0.15, 6), -90)
		-- El Guerrero Quetzal D tajea al Médico Jaguar, que sale despedido; el Médico Quetzal se venda.
		anim(c + 1.0, "quetzalD", "Slash1")
		hop(c + 1.2, "jaguarD", FLAG_CLASH.jaguarD, Vector3.new(-41.5, 0.15, 14), -90)
		anim(c + 1.2, "quetzalB", "Bandage", 1.2)
		-- El Médico Jaguar se levanta y cura al equipo (verde solo aquí: es la curación).
		anim(c + 1.95, "jaguarD", "CastArea", 1.1)
		fx(c + 2.05, "AreaHeal", "jaguarD", nil) -- grande (hasta c + 3,45)

		-- El robo: el avatar sale por la puerta Quetzal, llega al pedestal y baja la mano a cámara lenta.
		route("avatar", FLAG_GATE_AT, FLAG_ROUTES.gate, FLAG_RUN_SPEED)
		anim(timing.gateEnd + 0.05, "avatar", "Place", 1.6)
		add({ t = timing.gateEnd + 0.15, kind = "animSpeed", speed = FLAG_GRAB_SLOW })
		add({ t = timing.grabAt, kind = "flagGrab", team = "Quetzal", actor = "avatar" })
		add({ t = timing.slowEnd, kind = "animSpeed", speed = 1 })
		place(timing.slowEnd + 0.02, "avatar", FLAG_ROUTES.gate[#FLAG_ROUTES.gate], 90)
		-- La guardia Quetzal se vuelve hacia el avatar cuando este llega al pedestal.
		place(
			timing.gateEnd,
			"quetzalG",
			FLAG_START.quetzalG,
			yawBetween(FLAG_START.quetzalG, FLAG_ROUTES.gate[#FLAG_ROUTES.gate])
		)

		-- La guardia Quetzal (Cazador) apunta con el arco al ver al avatar en el altar y le dispara cuando echa a correr.
		anim(timing.gateEnd + 0.3, "quetzalG", "AimBow", timing.c1Start - timing.gateEnd - 0.5)
		anim(timing.c1Start - 0.15, "quetzalG", "Arrow", 0.7)
		fx(timing.c1Start, "MultiShot", "quetzalG", "avatar")
		-- La persecución: tres planos con corte. Dos Quetzal le siguen a 14 studs; en el último, un Jaguar los frena.
		local function chase(t0: number, points: { Vector3 })
			route("avatar", t0, points, FLAG_CHASE_SPEED)
			route("quetzalD", t0, flagShift(points, 14, -2.5), FLAG_CHASE_SPEED)
			route("quetzalE", t0, flagShift(points, 17, 2.5), FLAG_CHASE_SPEED)
		end
		chase(timing.c1Start, FLAG_ROUTES.chase1)
		chase(timing.c2Start, FLAG_ROUTES.chase2)
		-- El Mago Quetzal, que corre tras él, le tira un Rayo.
		anim(timing.c2Start + 0.4, "quetzalE", "CastForward", 0.6)
		fx(timing.c2Start + 0.5, "Lightning", "quetzalE", "avatar")
		-- Último tramo: el avatar sigue solo; los Quetzal salen más atrás y se topan con el Jaguar B.
		local blockAt = timing.c3Start
		route("avatar", blockAt, FLAG_ROUTES.chase3, FLAG_CHASE_SPEED)
		place(blockAt, "jaguarA", Vector3.new(-92, 0.1, 1), -90)
		place(blockAt, "quetzalD", Vector3.new(-76, 0.1, 4), 90)
		place(blockAt, "quetzalE", Vector3.new(-76, 0.1, -4), 90)
		route("quetzalD", blockAt + 0.05, { Vector3.new(-76, 0.1, 4), Vector3.new(-85, 0.1, 4) }, FLAG_CHASE_SPEED)
		route("quetzalE", blockAt + 0.05, { Vector3.new(-76, 0.1, -4), Vector3.new(-85, 0.1, -4) }, FLAG_CHASE_SPEED)
		anim(blockAt + 0.3, "jaguarA", "Charge", 0.6)
		fx(blockAt + 0.35, "Charge", "jaguarA", nil, { seconds = 0.6 })
		add({
			t = blockAt + 0.35,
			kind = "move",
			actor = "jaguarA",
			pos = Vector3.new(-88, 0.1, 0),
			yaw = -90,
			seconds = 0.35,
			easing = Enum.EasingStyle.Quad,
		})
		add({ t = blockAt + 0.7, kind = "shake", amp = 0.3, seconds = 0.45 })
		for _, name in { "quetzalD", "quetzalE" } do
			local z = if name == "quetzalD" then 5 else -5
			hop(blockAt + 0.7, name, Vector3.new(-85, 0.1, z * 0.8), Vector3.new(-71, 0.1, z), 90)
		end

		-- La captura en el pedestal propio: la bandera vuelve al suyo con un destello y el avatar celebra.
		add({ t = timing.captureAt, kind = "flagCapture", team = "Quetzal", pos = FLAG_STANDS.Jaguar })
		add({ t = timing.captureAt, kind = "shake", amp = 0.15, seconds = 0.5 })
		anim(timing.captureAt + 0.2, "avatar", "Cheer", 1.6)

		-- Cámara y textos de cada variante.
		local camera: { CameraPoint }
		if comic then
			local cuts = flagComicCuts(timing)
			camera = cutShots(comicShots(cuts)) :: any
			addComicPages(events, cuts)
			addFlagComicText(events, timing)
		else
			camera = flagCamera(timing)
			table.insert(events, {
				t = 0.4,
				kind = "caption",
				text = Strings.later("Dos bases. Una bandera cada una."),
				seconds = 2.6,
			})
			table.insert(events, {
				t = FLAG_GATE_AT + 0.6,
				kind = "caption",
				text = Strings.later("Roba la bandera rival."),
				seconds = 2.2,
			})
			table.insert(events, {
				t = timing.c1Start + 0.3,
				kind = "caption",
				text = Strings.later("Y llévala a tu base."),
				seconds = 2.2,
			})
			table.insert(events, {
				t = timing.captureAt + 0.1,
				kind = "caption",
				text = Strings.later("¡Bandera capturada!"),
				seconds = 1,
			})
			-- Cartel final, logo del juego y fundido (los mismos tiempos relativos que Pets, Mounts y Ballgame).
			table.insert(events, {
				t = 27.2,
				kind = "title",
				text = FLAG_TITLE,
				sub = Strings.later("5 contra 5 en la Isla de dunas"),
				seconds = 1.3,
			})
			table.insert(events, {
				t = 28.5,
				kind = "logo",
				text = Strings.later("Primal Banana Islands"),
				sub = Strings.later("Monkey Survival"),
				seconds = 0.9,
			})
			table.insert(events, { t = 29.3, kind = "fade", seconds = 0.7, toBlack = true })
		end

		local start = FLAG_START
		return {
			duration = if comic then FLAG_COMIC_SECONDS else FLAG_SECONDS,
			audience = "Self",
			freeze = true,
			skippable = true,
			hour = FLAG_HOUR,
			noBlur = true, -- sin DepthOfField ni Blur del place mientras suena (SceneLight)
			actors = {
				-- Cinco por bando, con la armadura y el arma de su rol (nivel máximo, sin trajes) y la marca del bando. Los
				-- repetidos (Guerrero del avatar Jaguar, Guerrero y Cazador extra Quetzal) llevan la armadura de plata: menos piezas.
				jaguarA = flagDummy(
					"Jaguar",
					"Guerrero",
					"VolcanicArmor",
					start.jaguarA,
					-90,
					Color3.fromRGB(255, 204, 153)
				),
				jaguarB = flagDummy(
					"Jaguar",
					"Cazador",
					"VolcanicArmor",
					start.jaguarB,
					-90,
					Color3.fromRGB(198, 134, 92)
				),
				jaguarC = flagDummy("Jaguar", "Mago", "VolcanicArmor", start.jaguarC, -90, Color3.fromRGB(141, 85, 58)),
				jaguarD = flagDummy(
					"Jaguar",
					"Medico",
					"VolcanicArmor",
					start.jaguarD,
					-90,
					Color3.fromRGB(233, 183, 140)
				),
				avatar = {
					kind = "localPlayer",
					copy = true,
					role = "Guerrero",
					armor = "VolcanicArmor",
					team = "Jaguar",
					pos = start.avatar,
					yaw = -90,
				},
				quetzalA = flagDummy(
					"Quetzal",
					"Guerrero",
					"VolcanicArmor",
					start.quetzalA,
					90,
					Color3.fromRGB(141, 85, 58)
				),
				quetzalB = flagDummy(
					"Quetzal",
					"Medico",
					"VolcanicArmor",
					start.quetzalB,
					90,
					Color3.fromRGB(233, 183, 140)
				),
				quetzalC = flagDummy(
					"Quetzal",
					"Cazador",
					"VolcanicArmor",
					start.quetzalC,
					90,
					Color3.fromRGB(198, 134, 92)
				),
				quetzalD = flagDummy(
					"Quetzal",
					"Guerrero",
					"SilverArmor",
					start.quetzalD,
					90,
					Color3.fromRGB(255, 204, 153)
				),
				quetzalE = flagDummy(
					"Quetzal",
					"Mago",
					"VolcanicArmor",
					start.quetzalE,
					90,
					Color3.fromRGB(176, 112, 76)
				),
				quetzalG = flagDummy(
					"Quetzal",
					"Cazador",
					"SilverArmor",
					start.quetzalG,
					yawBetween(start.quetzalG, FLAG_ROUTES.gate[1]),
					Color3.fromRGB(233, 183, 140)
				),
			},
			camera = camera,
			events = events,
		}
	end

	-- Cada variante va en su pcall, para que una que falle no tumbe a las otras ni al resto de cinemáticas.
	local flagScenes: { [string]: Scene? } = {}
	for name, variant in { Flag = "full", Flag_Comic = "comic" } do
		local ok, built = pcall(flagScene, variant)
		if ok then
			flagScenes[name] = built :: Scene
		else
			warn(`Cinematics: no se pudo construir la escena {name}: {built}`)
		end
	end
	return flagScenes
end
local flagScenes = buildFlagScenes()

-- ============================================================================ Motor en el Laboratorio (Fase 25, G12)
-- «LabEngine» (16 s): escena de PRUEBA del motor en el Laboratorio en ruinas, no la final (la escena «Lab» de tres actos es
-- G13, más abajo en este bloque). La lanza «🎬 Motor del Laboratorio» del panel del Laboratorio con LabCineController, anclada a la explanada este del
-- mapa Central (x 47: despejada, entre las cajas de x 40 y x 57; el suelo en y = 0). Cuatro maniquíes se enfrentan en dos
-- líneas, de espaldas a z = ±9: los Guardianes (z -9, de cara a +z) con el rifle y el arpón y los Piratas (z 9, de cara a -z)
-- con el lanzadardos y el cañón. Lo que enseña:
--    0 a  9   labLight Central, un labShot de cada arma (proyectil real, fogonazo y sonido), recargas y un Pirata que avanza
--    9.5      labLight Azotea (el cambio de luz)
--   10 a 15.2 fpView del rifle Guardián: la cámara en su cabeza, con los brazos; Fire, Aim, Reload y dos disparos
-- Sin textos (nada que traducir). Va dentro de una función por el límite de 200 locales del módulo.
local labScenes: { [string]: Scene? } = (function(): { [string]: Scene? }
	local out: { [string]: Scene? } = {}
	local function build(): Scene
		local events: { { t: number, kind: string, [string]: any } } = {}
		local function add(event: { t: number, kind: string, [string]: any })
			table.insert(events, event)
		end
		local function fire(t: number, actor: string, target: string)
			add({ t = t, kind = "labShot", actor = actor, target = target })
		end
		local function anim(t: number, actor: string, action: string, seconds: number)
			add({ t = t, kind = "anim", actor = actor, action = action, seconds = seconds })
		end
		local function fighter(weapon: string, faction: string, x: number, z: number, yaw: number): { [string]: any }
			return {
				kind = "dummy",
				labWeapon = weapon,
				faction = faction,
				pos = Vector3.new(x, 0, z),
				yaw = yaw,
			}
		end

		add({ t = 0, kind = "labLight", map = "Central" })
		-- Los tres dardos del lanzadardos (automático) sobre el rifle Guardián.
		fire(1.0, "pA", "gA")
		fire(1.15, "pA", "gA")
		fire(1.3, "pA", "gA")
		fire(2.2, "gA", "pA")
		fire(3.4, "gB", "pA")
		fire(4.6, "pB", "gB")
		anim(5.6, "gA", "ReloadRifle", 2.2)
		anim(5.8, "pB", "ReloadCannon", 2)
		-- El lanzadardos avanza hacia los Guardianes corriendo con su pista de arma bajada.
		add({ t = 6, kind = "move", actor = "pA", pos = Vector3.new(-3, 0, 3), yaw = 0, seconds = 2 })
		anim(6, "pA", "RunDartGun", 2)
		-- Primera persona del rifle Guardián (el cambio de luz justo antes).
		add({ t = 9.5, kind = "labLight", map = "Azotea" })
		add({ t = 10, kind = "fpView", on = true, actor = "gA", target = "pA", fov = 70 })
		add({ t = 10.2, kind = "fpAnim", key = "Equip" })
		fire(11, "gA", "pA")
		add({ t = 11, kind = "fpAnim", key = "Fire" })
		add({ t = 12.2, kind = "fpAnim", key = "Aim", weight = 1 })
		fire(13, "gA", "pA")
		add({ t = 13, kind = "fpAnim", key = "Fire" })
		add({ t = 13.6, kind = "fpAnim", key = "Aim", weight = 0 })
		add({ t = 14, kind = "fpAnim", key = "Reload", seconds = 1.4 })
		add({ t = 15.2, kind = "fpView", on = false })

		return {
			duration = 16,
			audience = "Self",
			freeze = true,
			skippable = true,
			actors = {
				gA = fighter("LabBananaRifle", "Guardians", -3, -9, 180),
				gB = fighter("LabNetHarpoon", "Guardians", 3, -9, 180),
				pA = fighter("LabDartGun", "Pirates", -3, 9, 0),
				pB = fighter("LabAcidCannon", "Pirates", 3, 9, 0),
			},
			camera = {
				{ t = 0, pos = Vector3.new(-6, 2, -18), look = Vector3.new(0, 1.8, 0), fov = 55 },
				{ t = 4, pos = Vector3.new(-3, 2, -14), look = Vector3.new(0, 1.8, 3), fov = 55 },
				{ t = 8, pos = Vector3.new(9, 2.4, -5), look = Vector3.new(0, 1.8, 4), fov = 55 },
				{ t = 16, pos = Vector3.new(9, 2.4, -5), look = Vector3.new(0, 1.8, 4), fov = 55 },
			},
			events = events,
		}
	end

	local ok, built = pcall(build)
	if ok then
		out.LabEngine = built :: Scene
	else
		warn(`Cinematics: no se pudo construir la escena LabEngine: {built}`)
	end

	-- ======================================================================== «Lab» y «Lab_Comic» (Fase 25, G13)
	-- Las dos escenas del tráiler del Laboratorio en ruinas, en tres actos que se ruedan en los tres mapas a la vez
	-- (Workspace.LabMap los tiene todos, cada uno en su Config.Lab.MapOffsets). El ancla es el origen del Central, así que
	-- cada punto es una coordenada del mundo: `at(mapa, x, y, z)` suma el offset del mapa. Las lanza «🎬 Laboratorio en
	-- ruinas» (y «… cómic») del panel del Laboratorio con LabCineController, que lleva el personaje cerca de cada acto
	-- (evento labPark: por si el place carga el mapa por streaming) y pone la luz (labLight).
	--    Acto 1 (0 a 15,5)     Central: duelo 1v1. Travelling, primera persona (falla), intercambio, remate a cámara lenta
	--    Acto 2 (15,5 a 30)    Alcantarillas: 3v3 en los túneles con la red, el ácido y los deslizamientos
	--    Acto 3 (30 a 45)      Azotea: largo alcance; el disparo final con el visor del rifle (fpView con scope)
	-- Los Guardianes llevan el rifle (el avatar, toda la escena), el arpón (gNet) y el lanzadardos (gDart); los Piratas, el
	-- lanzadardos (pDart, el rival del acto 1), el arpón (pNet) y el cañón (pCannon). Los golpes llevan `hit` (labShot): la
	-- respuesta del combate (número, crítico, cómic, hitmarker, red y charco) la pone Cinematics/LabHitFx.
	-- La variante cómic corre las mismas acciones a LAB_COMIC_SCALE y sin primera persona; las páginas son una por acto.
	-- Los tiempos, las posiciones y los encuadres son de diseño, a ajustar en Studio (raycasts de cada tiro y cada cámara).
	local function buildLabScenes(scenes: { [string]: Scene? })
		local LAB_SECONDS = 45
		local LAB_COMIC_SECONDS = 25
		local LAB_COMIC_SCALE = 0.55 -- el cómic corre la acción a este ritmo
		local LAB_TITLE = Strings.later("Laboratorio en ruinas")
		local RIFLE_DELAY = 0.1 -- fxDelay de la pose LabRifle (Data/WeaponAnimations): del disparo a la salida del proyectil
		local RIFLE_SPEED = 450 -- velocidad del proyectil del rifle (Data/LabWeapons)
		local RUN_ACTIONS: { [string]: string } = {
			avatar = "RunRifle",
			gNet = "RunHarpoon",
			gDart = "RunDartGun",
			pDart = "RunDartGun",
			pNet = "RunHarpoon",
			pCannon = "RunCannon",
		}
		local OFFSETS: { [string]: Vector3 } = Config.Lab.MapOffsets
		local LIFT = Vector3.new(0, 2.6, 0) -- del suelo al pecho de un personaje

		-- Una coordenada de un mapa, en el mundo.
		local function at(map: string, x: number, y: number, z: number): Vector3
			return OFFSETS[map] + Vector3.new(x, y, z)
		end
		local function central(x: number, y: number, z: number): Vector3
			return at("Central", x, y, z)
		end
		local function sewer(x: number, y: number, z: number): Vector3
			return at("Alcantarillas", x, y, z)
		end
		local function roof(x: number, y: number, z: number): Vector3
			return at("Azotea", x, y, z)
		end

		-- Acto 1 (Central): el avatar al este, de cara al rival, que avanza andando, rueda y salta atrás.
		local A1_AVATAR = central(52, 0, 5)
		local A1_AVATAR_0 = central(52, 0, 2.2) -- de dónde llega: la escena empieza con él ya en movimiento
		local A1_RIVAL_FROM = central(14, 0, 5)
		local A1_RIVAL_SPEED = 3 -- studs/s: avanza al trote lento (las pistas de correr van a speed / 16)
		local A1_RIVAL = central(26, 0, 5)
		local A1_RIVAL_2 = central(29, 0, 5.2) -- adónde llega mientras el avatar le apunta (4 a 5,6 s)
		local A1_AVATAR_2 = central(49.6, 0, 6.4) -- el avatar se desplaza de lado mientras apunta
		local A1_PUSH = central(37, 0, 5.4) -- el rival, tras rodar, avanza a tiros
		local A1_STRAFE = central(44.5, 0, 4.8) -- el avatar, tras deslizarse, sigue moviéndose
		-- La caja de x 40 (z ±2) queda al sur: el intercambio ocurre en la banda z 3…7, al norte de ella, para que ningún tiro la cruce.
		local A1_ROLL = central(34, 0, 7)
		local A1_SLIDE = central(46, 0, 3)
		local A1_HOP = central(31, 0, 6)
		-- Acto 2 (sala de bombas, claro oeste): duelo 1v1 del avatar con el Pirata del arpón. El claro (x -15,5…-5, z -5,8…5,8)
		-- queda entre la boca del túnel (x -16), las bombas pequeñas (4x6x4, en (-8, ±8)) y la cara de la bomba grande (x -4,3).
		-- Los otros cuatro actores esperan lejos, bajo el mapa, hasta el acto 3 (pDart, pCannon) o no vuelven a salir.
		local A2_PIRATE = sewer(-6.2, 0, 0.2)
		local A2_AWAY = sewer(0, -500, 0)
		-- Acto 3 (Azotea): el avatar en el helipuerto y los Piratas por el flanco oeste.
		-- En x 6 del helipuerto: desde ahí la línea al Pirata pasa a 17° del Depósito (x -19…-13, z 11…17), fuera del visor de 30°.
		local A3_AVATAR = roof(6, 4, 40)
		-- Los Piratas cruzan al norte del Aparato de x -34 (z -13) y acaban en x -8…-12 (z -8…-4). A 5,5 studs/s, en el disparo
		-- del visor (39,7 s) pDart está en x -12, z -8,6: la línea desde (6, 40) pasa a 19° del Depósito (x -19…-13, z 11…17),
		-- fuera del visor de 30°, y entre él y la Caseta (x ±6, z ±6, 8 de alto).
		local A3_PDART_PATH = { roof(-40, 0, -6), roof(-27, 0, -4), roof(-14, 0, -8) }
		local A3_PCANNON_PATH = { roof(-38, 0, -2), roof(-27, 0, -1), roof(-18, 0, -4), roof(-12, 0, -2) }
		-- Los Piratas ya vienen corriendo cuando empieza el acto: de estos puntos a la ruta de arriba.
		local A3_PDART_LEAD = roof(-56, 0, 8)
		local A3_PCANNON_LEAD = roof(-54, 0, 10)
		local A3_RUN_SPEED = 6.5 -- studs/s: unos 8 s de carrera desde que empieza el acto, y se paran hacia 37,4
		-- El avatar llega corriendo al helipuerto y su compañero Guardián (gDart) lo acompaña, moviéndose de lado.
		local A3_AVATAR_FROM = roof(-3, 4, 40)
		local A3_ALLY_FROM = roof(-8, 4, 40)
		local A3_ALLY = { roof(0.5, 4, 40.5), roof(-2, 4, 39), roof(2, 4, 40.5), roof(-1, 4, 39.5), roof(1, 4, 40.5) }

		local function labDummy(weapon: string, faction: string, pos: Vector3, yaw: number): { [string]: any }
			return { kind = "dummy", labWeapon = weapon, faction = faction, pos = pos, yaw = yaw }
		end

		-- `variant`: "full" (45 s, con bandas) o "comic" (25 s, páginas con viñetas).
		local function labScene(variant: string): Scene
			assert(variant == "full" or variant == "comic", `Lab: la variante {variant} no existe`)
			local comic = variant == "comic"
			local scale = if comic then LAB_COMIC_SCALE else 1
			local act = { two = if comic then 15.3 else 14.5, three = if comic then 29.8 else 29.5 }
			local events: EventList = {}
			-- Dónde está cada actor en cada segundo (de la acción, sin escalar): llaves { t, pos } que se interpolan en línea
			-- recta. Sirven para encuadrar (cámara de seguimiento y viñetas) y para saber cuándo llega un proyectil.
			local tracks: { [string]: { { t: number, pos: Vector3 } } } = {}
			local function key(actor: string, t: number, pos: Vector3)
				local list = tracks[actor]
				if not list then
					list = {}
					tracks[actor] = list
				end
				table.insert(list, { t = t, pos = pos })
			end
			local function posAt(actor: string, t: number): Vector3
				local list = tracks[actor]
				local prev = list[1]
				if t <= prev.t then
					return prev.pos
				end
				for index = 2, #list do
					local nextKey = list[index]
					if t < nextKey.t then
						local span = nextKey.t - prev.t
						return prev.pos:Lerp(nextKey.pos, if span > 0 then (t - prev.t) / span else 1)
					end
					prev = nextKey
				end
				return prev.pos
			end
			-- Hacia dónde mira quien se mueve (en horizontal), mirando medio segundo alrededor de t.
			local function heading(actor: string, t: number): Vector3
				local d = posAt(actor, t + 0.25) - posAt(actor, t - 0.25)
				d = Vector3.new(d.X, 0, d.Z)
				return if d.Magnitude > 0.01 then d.Unit else Vector3.new(1, 0, 0)
			end

			-- Un evento de la acción, con el tiempo y las duraciones a la escala de la variante.
			local function add(event: { t: number, kind: string, [string]: any })
				if scale ~= 1 then
					event = table.clone(event)
					event.t *= scale
					if event.seconds then
						event.seconds *= scale
					end
				end
				table.insert(events, event)
			end
			local function anim(t: number, actor: string, action: string, seconds: number?, speed: number?)
				add({ t = t, kind = "anim", actor = actor, action = action, seconds = seconds, speed = speed })
			end
			-- Las líneas de velocidad del juego (SpeedLinesController): una de más o menos fuerza (`value`, de 0 a 1) mientras alguien
			-- corre, salta, se desliza o esquiva. Se juntan al final (emitLines) en una sola curva con el máximo de las que se
			-- solapan. El cómic no las lleva.
			local lineSpans: { { t0: number, t1: number, value: number } } = {}
			local function lines(t: number, value: number, seconds: number)
				table.insert(lineSpans, { t0 = t, t1 = t + seconds, value = value })
			end
			local function emitLines()
				if comic then
					return
				end
				local bounds: { number } = {}
				for _, span in lineSpans do
					table.insert(bounds, span.t0)
					table.insert(bounds, span.t1)
				end
				table.sort(bounds)
				local last = 0
				for _, t in bounds do
					local value = 0
					for _, span in lineSpans do
						if t >= span.t0 and t < span.t1 then
							value = math.max(value, span.value)
						end
					end
					if value ~= last then
						last = value
						table.insert(events, { t = t, kind = "speedLines", value = value })
					end
				end
			end
			-- Pone a un actor en un sitio de golpe.
			local function place(t: number, actor: string, pos: Vector3, yaw: number)
				local list = tracks[actor]
				local last = list[#list]
				if last.pos ~= pos then
					key(actor, t - 0.001, last.pos)
				end
				key(actor, t, pos)
				add({ t = t, kind = "move", actor = actor, pos = pos, yaw = yaw, seconds = 0 })
			end
			-- Lo mueve hasta `pos` en `seconds`; `tilt` ({ pitch?, roll? }) lo inclina (la caída).
			local function glide(
				t: number,
				actor: string,
				pos: Vector3,
				yaw: number,
				seconds: number,
				easing: Enum.EasingStyle?,
				tilt: { pitch: number?, roll: number? }?
			)
				local list = tracks[actor]
				local last = list[#list]
				if last.t < t then
					key(actor, t, last.pos)
				end
				key(actor, t + seconds, pos)
				add({
					t = t,
					kind = "move",
					actor = actor,
					pos = pos,
					yaw = yaw,
					seconds = seconds,
					easing = easing or Enum.EasingStyle.Sine,
					pitch = if tilt then tilt.pitch else nil,
					roll = if tilt then tilt.roll else nil,
				})
			end
			-- Un recorrido a velocidad constante con la pista de correr de su arma. Devuelve el segundo en que llega.
			local function route(
				actor: string,
				t0: number,
				points: { Vector3 },
				speed: number,
				animSpeed: number?
			): number
				local total = 0
				for index = 2, #points do
					total += (points[index] - points[index - 1]).Magnitude
				end
				anim(t0, actor, RUN_ACTIONS[actor], total / speed, animSpeed or speed / 16)
				if speed >= 6 then
					lines(t0, math.min(1, speed / 11), total / speed)
				end
				local t = t0
				for index = 2, #points do
					local seconds = (points[index] - points[index - 1]).Magnitude / speed
					if seconds > 0.01 then
						local yaw = yawBetween(points[index - 1], points[index])
						place(t, actor, points[index - 1], yaw)
						glide(t, actor, points[index], yaw, seconds, Enum.EasingStyle.Linear)
						t += seconds
					end
				end
				return t
			end
			-- Una víctima salta hacia atrás (el suelo es el y de `from`).
			local function hop(t: number, actor: string, from: Vector3, to: Vector3, yaw: number)
				anim(t, actor, "DodgeBack", 0.8)
				lines(t, 0.5, 0.6)
				glide(t, actor, from:Lerp(to, 0.5) + Vector3.new(0, 1.8, 0), yaw, 0.25, Enum.EasingStyle.Quad)
				glide(t + 0.25, actor, to, yaw, 0.3, Enum.EasingStyle.Quad)
			end
			-- Cae de espaldas, 1,5 studs más allá (`away` es la dirección del tiro): el cuerpo queda a ras de suelo.
			local function knockDown(t: number, actor: string, from: Vector3, away: Vector3, yaw: number)
				glide(
					t,
					actor,
					from + away * 1.5 + Vector3.new(0, -1.7, 0),
					yaw,
					1.6,
					Enum.EasingStyle.Quad,
					{ pitch = 80 }
				)
			end
			-- Un disparo del arma del actor. `speed` (studs/s) se acelera en el cómic para que el vuelo dure lo mismo que la
			-- acción; `range` recorta el alcance; `hit` pone la respuesta del combate en el blanco (LabHitFx).
			local function lshot(
				t: number,
				actor: string,
				target: any,
				opts: { speed: number?, range: number?, hit: any? }?
			)
				local o = opts or {}
				add({
					t = t,
					kind = "labShot",
					actor = actor,
					target = target,
					speed = if o.speed then o.speed / scale else nil,
					range = o.range,
					hit = o.hit,
				})
			end
			-- El segundo en que el proyectil de un disparo de `shooter` llega a `victim`.
			local function impactAt(t: number, shooter: string, victim: string, speed: number): number
				return t + RIFLE_DELAY + (posAt(shooter, t) - posAt(victim, t)).Magnitude / speed
			end
			-- Un salto con arco (la pista DodgeRoll lo convierte en voltereta): sube `height` studs hasta la mitad y baja.
			local function leap(t: number, actor: string, to: Vector3, yaw: number, seconds: number, height: number)
				local from = posAt(actor, t)
				anim(t, actor, "DodgeRoll", seconds)
				lines(t, 0.85, seconds)
				glide(t, actor, from:Lerp(to, 0.5) + Vector3.new(0, height, 0), yaw, seconds / 2, Enum.EasingStyle.Quad)
				glide(t + seconds / 2, actor, to, yaw, seconds / 2, Enum.EasingStyle.Quad)
			end

			-- Dardos que pasan por encima del avatar: apuntan 5,6 studs sobre el suelo de su sitio.
			local function over(pos: Vector3): Vector3
				return pos + Vector3.new(0, 5.6, 0)
			end

			-- Los actores, con su sitio de partida (para las llaves de posición, antes del primer evento).
			local actors: { [string]: { [string]: any } } = {
				avatar = {
					kind = "localPlayer",
					copy = true,
					labWeapon = "LabBananaRifle",
					faction = "Guardians",
					pos = A1_AVATAR_0,
					yaw = yawBetween(A1_AVATAR, A1_RIVAL),
				},
				pDart = labDummy("LabDartGun", "Pirates", A1_RIVAL_FROM, yawBetween(A1_RIVAL_FROM, A1_AVATAR)),
				gNet = labDummy("LabNetHarpoon", "Guardians", A2_AWAY, 0),
				gDart = labDummy("LabDartGun", "Guardians", A2_AWAY, 0),
				pNet = labDummy("LabNetHarpoon", "Pirates", A2_PIRATE, 180),
				pCannon = labDummy("LabAcidCannon", "Pirates", A2_AWAY, 180),
			}
			for name, def in actors do
				key(name, -1, def.pos)
			end

			-- ------------------------------------------------------------------------------------------ Acto 1: Central
			if not comic then
				add({ t = 0, kind = "letterbox" })
			end
			add({ t = 0, kind = "labLight", map = "Central" })
			-- El halo del Bloom del place sobre las franjas Neon y los focos quemaba los planos cercanos de las Alcantarillas
			-- (se vio en la grabación): se rebaja mientras dura la escena (SceneLight lo devuelve al acabar).
			add({ t = 0, kind = "bloom", intensity = 0.25, threshold = 3 })
			add({ t = 0, kind = "labPark", map = "Central", pos = Vector3.new(-30, 3, 4) })
			-- 1.1 El avatar apunta con el rifle (1.1a) y el rival avanza al trote hacia él, visto de lado (1.1b) y por sus ojos
			-- (1.1c). Todo el que se mueve lleva la pista de correr de su arma a la velocidad real (speed / 16).
			anim(0, "avatar", "RunRifle", 1.6, 0.17)
			glide(0, "avatar", A1_AVATAR, yawBetween(A1_AVATAR, A1_RIVAL), 1.6, Enum.EasingStyle.Linear)
			anim(1.7, "avatar", "AimRifle", 2.3)
			anim(0, "pDart", "RunDartGun", 4, A1_RIVAL_SPEED / 16)
			glide(0, "pDart", A1_RIVAL, yawBetween(A1_RIVAL_FROM, A1_AVATAR), 4, Enum.EasingStyle.Linear)
			-- 1.1c Primera persona del Pirata: ve avanzar el pasillo con su lanzadardos y al avatar al fondo.
			if not comic then
				add({
					t = 2.8,
					kind = "fpView",
					on = true,
					actor = "pDart",
					faction = "Pirates",
					target = "avatar",
					fov = 70,
				})
				add({ t = 2.9, kind = "fpAnim", key = "Equip" })
				add({ t = 3.98, kind = "fpView", on = false })
			end
			-- Sigue avanzando mientras el avatar le apunta (1.2).
			anim(4, "pDart", "RunDartGun", 1.6, A1_RIVAL_SPEED / 16)
			glide(4, "pDart", A1_RIVAL_2, yawBetween(A1_RIVAL, A1_AVATAR), 1.6, Enum.EasingStyle.Linear)
			-- 1.2 Primera persona del avatar: el disparo falla (apunta donde estaba el rival), el rival rueda, y el avatar se
			-- desplaza de lado mientras apunta.
			if not comic then
				-- Con la mira del visor, como la ve el jugador al apuntar con el rifle.
				add({ t = 4, kind = "fpView", on = true, actor = "avatar", target = "pDart", fov = 70, scope = true })
				add({ t = 4.1, kind = "fpAnim", key = "Equip" })
				add({ t = 4.7, kind = "fpAnim", key = "Aim", weight = 1, fov = 30, seconds = 0.4 })
				add({ t = 5.6, kind = "fpAnim", key = "Fire" })
				add({ t = 7, kind = "fpView", on = false })
			end
			lines(4.5, 0.3, 2)
			glide(4.4, "avatar", A1_AVATAR_2, yawBetween(A1_AVATAR_2, A1_RIVAL_2), 2.4, Enum.EasingStyle.Sine)
			-- Pasa rozando su hombro: la mira apunta 2,4 studs al lado del rival.
			lshot(5.6, "avatar", posAt("pDart", 5.6) + Vector3.new(0, 1.6, 2.4))
			anim(5.65, "pDart", "DodgeRoll", 0.7)
			lines(5.65, 0.6, 0.6)
			glide(5.65, "pDart", A1_ROLL, yawBetween(A1_ROLL, A1_SLIDE), 0.5)
			-- 1.3 Intercambio: el rival avanza a tiros (ráfaga de dardos por encima) y el avatar se desliza y le contesta; su
			-- rifle da en el blanco, y los dos siguen moviéndose.
			anim(7, "pDart", "RunDartGun", 1.8, 0.3)
			glide(7, "pDart", A1_PUSH, yawBetween(A1_ROLL, A1_SLIDE), 1.8, Enum.EasingStyle.Sine)
			for _, t in { 7.3, 7.45, 7.6 } do
				lshot(t, "pDart", over(A1_AVATAR_2))
			end
			anim(7.6, "avatar", "Slide", 0.7)
			lines(7.6, 0.9, 0.9)
			glide(7.6, "avatar", A1_SLIDE, yawBetween(A1_SLIDE, A1_PUSH), 0.6)
			anim(8.3, "avatar", "RunRifle", 2.1, 0.2)
			glide(8.3, "avatar", A1_STRAFE, yawBetween(A1_STRAFE, A1_HOP), 2.1, Enum.EasingStyle.Sine)
			lshot(8.8, "avatar", "pDart", { hit = { damage = 48 } })
			do
				local struck = impactAt(8.8, "avatar", "pDart", RIFLE_SPEED)
				hop(struck, "pDart", posAt("pDart", struck), A1_HOP, yawBetween(A1_HOP, A1_SLIDE))
			end
			lshot(9.4, "pDart", "avatar", { hit = { damage = 10 } })
			lshot(9.55, "pDart", "avatar", { hit = { damage = 10 } })
			-- 1.4 Remate a cámara lenta: la banana se ve volar y el rival cae de espaldas.
			add({ t = 10.3, kind = "animSpeed", speed = 0.25 })
			lshot(10.6, "avatar", "pDart", { speed = 25, hit = { damage = 96, head = true, ko = true } })
			local finishAt = impactAt(10.6, "avatar", "pDart", 25)
			add({ t = finishAt, kind = "shake", amp = 0.2, seconds = 0.4 })
			local awayDir = (A1_HOP - A1_SLIDE) * Vector3.new(1, 0, 1)
			knockDown(finishAt + 0.02, "pDart", A1_HOP, awayDir.Unit, yawBetween(A1_HOP, A1_SLIDE))
			add({ t = 13.2, kind = "animSpeed", speed = 1 })
			-- 1.5 Cierre en picado y fundido.
			anim(14, "avatar", "ReloadRifle", 1.4)

			-- ------------------------------------------------------------------------------------ Acto 2: Sala de bombas
			-- Combate cercano 1v1 en el claro oeste, sin remate y sin red que atrape a nadie (en el juego la red no funciona así):
			-- los dos se mueven siempre mirándose, esquivan, se deslizan, saltan y se disparan a 4-6 studs; el Pirata falla sus
			-- redes y el avatar le acierta de vez en cuando (a veces apuntando). Entra y sale con corte seco, en pleno movimiento.
			-- Los tiempos están en segundos de diseño (14,5 a 29,5); `A` los ajusta al cómic, que entra más tarde.
			add({ t = act.two - 0.1, kind = "labPark", map = "Alcantarillas", pos = Vector3.new(50, 3, 25) })
			add({ t = act.two, kind = "labLight", map = "Alcantarillas" })
			do
				local function A(t: number): number
					return act.two + (t - 14.5) * (act.three - act.two) / 15
				end
				-- Posiciones del avatar (P) y del Pirata (Q); el claro mide x -15…-5,5 y |z| < 4,5 entre las bombas pequeñas.
				local P = {
					sewer(-14.5, 0, -3.8),
					sewer(-13.3, 0, -1.6),
					sewer(-14.2, 0, -3.9),
					sewer(-12.6, 0, -2.4),
					sewer(-12.2, 0, -0.4),
					sewer(-13.2, 0, 1.6),
					sewer(-12.5, 0, 2.8),
					sewer(-13.8, 0, 0.8),
					sewer(-12.3, 0, -1),
					sewer(-13.8, 0, -3.2),
					sewer(-12.8, 0, -1.4),
					sewer(-13.8, 0, 1.2),
					sewer(-12.4, 0, 2.4),
					sewer(-12.5, 0, 0.6),
				}
				local Q = {
					sewer(-7, 0, 3.4),
					sewer(-6.2, 0, 1),
					sewer(-5.8, 0, 2.6),
					sewer(-6.2, 0, -1.8),
					sewer(-5.8, 0, 0.2),
					sewer(-6.2, 0, 2.4),
					sewer(-5.8, 0, 1),
					sewer(-6.6, 0, -1.2),
					sewer(-6, 0, 2.4),
					sewer(-5.8, 0, 0.6),
					sewer(-6.4, 0, -1.4),
					sewer(-5.8, 0, -0.2),
					sewer(-6.6, 0, 2.2),
					sewer(-6, 0, 0.2),
					sewer(-6.4, 0, -1.6),
				}
				-- Hacia dónde mira quien llega a `to` en `t`: hacia el otro duelista en ese momento.
				local function facing(to: Vector3, other: string, t: number): number
					return yawBetween(to, posAt(other, t))
				end
				-- Corre (de lado, mirando al otro) hasta `to`: la pista de correr de su arma a un ritmo que se vea.
				local function dash(t: number, actor: string, to: Vector3, seconds: number, other: string)
					local speed = (to - posAt(actor, t)).Magnitude / seconds
					anim(t, actor, RUN_ACTIONS[actor], seconds, math.max(speed / 16, 0.5))
					if speed >= 6 then
						lines(t, math.min(1, speed / 11), seconds)
					end
					glide(t, actor, to, facing(to, other, t + seconds), seconds, Enum.EasingStyle.Linear)
				end
				local function dodge(t: number, actor: string, to: Vector3, seconds: number, other: string)
					leap(t, actor, to, facing(to, other, t + seconds), seconds, 2.2)
				end
				local function slide(t: number, actor: string, to: Vector3, other: string)
					anim(t, actor, "Slide", 0.7)
					lines(t, 0.9, 0.9)
					glide(t, actor, to, facing(to, other, t + 0.7), 0.7)
				end
				local function stagger(t: number, actor: string, to: Vector3, other: string)
					hop(t, actor, posAt(actor, t), to, facing(to, other, t + 0.55))
				end

				place(A(14.5), "avatar", P[1], yawBetween(P[1], Q[1]))
				place(A(14.5), "pNet", Q[1], yawBetween(Q[1], P[1]))
				place(A(14.5), "pDart", A2_AWAY, 180) -- el caído del acto 1 se aparta
				dash(A(14.5), "avatar", P[2], 1.9, "pNet")
				dash(A(14.5), "pNet", Q[2], 1.2, "avatar")
				lshot(A(15.6), "avatar", "pNet", { hit = { damage = 36 } })
				stagger(A(15.75), "pNet", Q[3], "avatar")
				dodge(A(16.4), "avatar", P[3], 0.8, "pNet")
				dash(A(16.4), "pNet", Q[4], 1.55, "avatar")
				lshot(A(16.6), "pNet", "avatar")
				lshot(A(17.1), "pNet", "avatar")
				dash(A(17.2), "avatar", P[4], 1.2, "pNet")
				lshot(A(17.9), "avatar", "pNet", { hit = { damage = 24 } })
				stagger(A(18.05), "pNet", Q[5], "avatar")
				dash(A(18.5), "avatar", P[5], 1.1, "pNet")
				dash(A(18.9), "pNet", Q[6], 0.7, "avatar")
				lshot(A(19.2), "pNet", "avatar")
				lshot(A(19.6), "avatar", "pNet", { hit = { damage = 48 } }) -- apuntando
				stagger(A(19.75), "pNet", Q[7], "avatar")
				slide(A(19.8), "avatar", P[6], "pNet")
				dash(A(20.6), "avatar", P[7], 1, "pNet")
				dodge(A(20.9), "pNet", Q[8], 0.9, "avatar")
				lshot(A(21.2), "avatar", "pNet")
				dodge(A(21.8), "avatar", P[8], 0.8, "pNet")
				dash(A(21.9), "pNet", Q[9], 1.5, "avatar")
				lshot(A(22.1), "pNet", "avatar")
				lshot(A(22.6), "pNet", "avatar")
				dash(A(22.7), "avatar", P[9], 1.1, "pNet")
				lshot(A(23.3), "avatar", "pNet", { hit = { damage = 36 } })
				stagger(A(23.45), "pNet", Q[10], "avatar")
				slide(A(24), "avatar", P[10], "pNet")
				dash(A(24.3), "pNet", Q[11], 1, "avatar")
				lshot(A(24.5), "pNet", "avatar")
				dash(A(24.8), "avatar", P[11], 1.1, "pNet")
				lshot(A(25.4), "avatar", "pNet", { hit = { damage = 48 } }) -- apuntando
				stagger(A(25.55), "pNet", Q[12], "avatar")
				dodge(A(26.2), "avatar", P[12], 0.8, "pNet")
				dodge(A(26.4), "pNet", Q[13], 0.9, "avatar")
				dash(A(27.1), "avatar", P[13], 1.2, "pNet")
				lshot(A(27.6), "avatar", "pNet")
				dash(A(27.4), "pNet", Q[14], 1, "avatar")
				lshot(A(27.9), "pNet", "avatar")
				dash(A(28.4), "avatar", P[14], 1.1, "pNet")
				dash(A(28.5), "pNet", Q[15], 1, "avatar")
				lshot(A(28.9), "pNet", "avatar")
				lshot(A(29.1), "avatar", "pNet")

				-- Primera persona, alternando las cabezas de los dos y cortando en los tiros y las esquivas (sin cómic).
				if not comic then
					local function fp(
						from: number,
						to: number,
						who: string,
						fireAt: { number },
						fov: number,
						aimAt: number?
					)
						local pirate = who == "pNet"
						add({
							t = from,
							kind = "fpView",
							on = true,
							actor = who,
							faction = if pirate then "Pirates" else nil,
							target = if pirate then "avatar" else "pNet",
							fov = fov,
						})
						if aimAt then
							add({ t = aimAt, kind = "fpAnim", key = "Aim", weight = 1, fov = fov - 22, seconds = 0.35 })
						end
						for _, ft in fireAt do
							add({ t = ft, kind = "fpAnim", key = "Fire" })
						end
						add({ t = to, kind = "fpView", on = false })
					end
					fp(14.5, 16.3, "avatar", { 15.6 }, 74)
					fp(16.35, 17.8, "pNet", { 16.6, 17.1 }, 70)
					fp(17.85, 19.95, "avatar", { 17.9, 19.6 }, 72, 19.1)
					fp(20, 21.55, "pNet", {}, 70)
					fp(21.6, 23.95, "avatar", { 21.2, 23.3 }, 74)
					fp(24, 24.95, "pNet", { 24.5 }, 70)
					fp(25, 26.9, "avatar", { 25.4 }, 72, 24.95)
					fp(26.95, 28.4, "pNet", { 27.9 }, 70)
					fp(28.45, 29.45, "avatar", { 29.1 }, 74)
				end
			end

			-- --------------------------------------------------------------------------------------------- Acto 3: Azotea
			-- 2 contra 2: el avatar y un Guardián del lanzadardos (gDart) en el helipuerto, y dos Piratas que cruzan corriendo desde
			-- el principio. Todos entran en movimiento; al final los Piratas se paran y se vuelven hacia quien los apunta.
			local a3Face = yawBetween(A3_AVATAR, A3_PDART_PATH[1])
			add({ t = act.three - 0.1, kind = "labPark", map = "Azotea", pos = Vector3.new(-50, 3, -20) })
			add({ t = act.three, kind = "labLight", map = "Azotea" })
			place(act.three, "avatar", A3_AVATAR_FROM, a3Face)
			anim(act.three, "avatar", "RunRifle", 1.4, 0.3)
			glide(act.three, "avatar", A3_AVATAR, a3Face, 1.4, Enum.EasingStyle.Linear)
			-- 3.1 Se descubre el avatar en el helipuerto, apuntando, con su compañero a un lado.
			anim(act.three + 1.5, "avatar", "AimRifle", 5)
			place(act.three, "gDart", A3_ALLY_FROM, a3Face)
			anim(act.three, "gDart", "RunDartGun", 1.4, 0.5)
			glide(act.three, "gDart", A3_ALLY[1], a3Face, 1.4, Enum.EasingStyle.Linear)
			for index = 2, 5 do
				local t = act.three + 1.4 + (index - 2) * 1.6
				anim(t, "gDart", "RunDartGun", 1.6, 0.5)
				glide(t, "gDart", A3_ALLY[index], a3Face, 1.6, Enum.EasingStyle.Sine)
			end
			for _, t in { 34.1, 34.8, 35.5 } do
				lshot(t, "gDart", posAt("pDart", t) + Vector3.new(0, 9, 0), { range = 45 })
			end
			-- 3.2 Los Piratas cruzan la azotea por el flanco oeste, corriendo desde el principio (llegan a 37,4 y se paran); sus
			-- dardos se quedan cortos (alcance de 80, a 45).
			route(
				"pDart",
				act.three,
				{ A3_PDART_LEAD, roof(-44, 0, 5), table.unpack(A3_PDART_PATH) },
				A3_RUN_SPEED,
				0.6
			)
			route(
				"pCannon",
				act.three,
				{ A3_PCANNON_LEAD, roof(-44, 0, 7.5), table.unpack(A3_PCANNON_PATH) },
				A3_RUN_SPEED,
				0.6
			)
			for _, t in { 36, 36.15, 36.3 } do
				lshot(t, "pDart", A3_AVATAR + Vector3.new(0, 1.6, 0), { range = 45 })
			end
			-- 3.3 Primera persona con el visor: entra a 37,3 (fov 30 en 0,4 s) y el disparo sale a 39,6. El Pirata apuntado se
			-- vuelve hacia quien lo apunta a 37,6 y su acompañante, un segundo después.
			glide(37.6, "pDart", posAt("pDart", 37.6), yawBetween(posAt("pDart", 37.6), A3_AVATAR), 0.35)
			glide(38.6, "pCannon", posAt("pCannon", 38.6), yawBetween(posAt("pCannon", 38.6), A3_AVATAR), 0.35)
			if not comic then
				add({ t = 37, kind = "fpView", on = true, actor = "avatar", target = "pDart", fov = 70, scope = true })
				add({ t = 37.3, kind = "fpAnim", key = "Aim", weight = 1, fov = 30, seconds = 0.4 })
				add({ t = 39.6, kind = "fpAnim", key = "Fire" })
				add({ t = 40, kind = "fpView", on = false })
			end
			lshot(39.6, "avatar", "pDart", { speed = 90, hit = { damage = 96, head = true, ko = true } })
			add({ t = 39.9, kind = "shake", amp = 0.15, seconds = 0.3 })
			-- 3.4 El impacto a cámara lenta, en primera persona del Pirata del cañón: su compañero cae a su lado y él se agacha.
			add({ t = 40, kind = "animSpeed", speed = 0.3 })
			local sniperAt = impactAt(39.6, "avatar", "pDart", 90)
			local pDartAtHit = posAt("pDart", sniperAt)
			local sniperAway = (pDartAtHit - A3_AVATAR) * Vector3.new(1, 0, 1)
			knockDown(sniperAt + 0.02, "pDart", pDartAtHit, sniperAway.Unit, yawBetween(pDartAtHit, A3_AVATAR))
			local cannonAtHit = posAt("pCannon", sniperAt)
			hop(
				sniperAt + 0.05,
				"pCannon",
				cannonAtHit,
				cannonAtHit + sniperAway.Unit * 2.5,
				yawBetween(cannonAtHit, A3_AVATAR)
			)
			if not comic then
				add({
					t = 40.05,
					kind = "fpView",
					on = true,
					actor = "pCannon",
					faction = "Pirates",
					target = "pDart",
					fov = 70,
				})
				add({ t = 41.5, kind = "fpView", on = false })
			end
			add({ t = 41.8, kind = "animSpeed", speed = 1 })
			-- 3.5 Cierre: recarga, título, logo y fundido.
			anim(42, "avatar", "ReloadRifle", 1.8)

			emitLines()

			-- ------------------------------------------------------------------------------------------ Cámara y textos
			local camera: { CameraPoint } = {}
			local function lookAtPawn(actor: string, t: number): Vector3
				return posAt(actor, t) + LIFT
			end
			if comic then
				-- Las viñetas del cómic (Lab_Comic): tres páginas, una por acto, con los tiempos de la acción a LAB_COMIC_SCALE.
				local cuts: { ComicCut } = {}
				local function addPage(
					layout: string,
					colors: { Color3 },
					wipe: string?,
					cells: { ComicCell },
					order: { number }
				)
					for index, c in cells do
						table.insert(cuts, {
							t0 = c.t0,
							t1 = c.t1,
							layout = layout,
							page = if index == 1 then { layout = layout, colors = colors, wipe = wipe } else nil,
							cell = order[index],
							pos = c.pos,
							posB = c.posB,
							subject = c.subject,
							subjectB = c.subjectB,
							width = c.width,
							widthB = c.widthB,
							bg = c.bg,
						})
					end
				end
				-- Centro y radio (en el suelo) de los personajes `names` en el segundo `c` de cómic.
				-- Hasta qué segundo de la acción se miden los personajes: cada página se encuadra solo con lo que pasa en su mapa (más
				-- allá, los actores ya se han ido al siguiente y la cámara miraría a 2000 studs).
				local sampleCap = math.huge
				local function groupAt(names: { string }, c: number): (Vector3, number)
					local sum = Vector3.zero
					local points = {}
					for _, name in names do
						local p = posAt(name, math.min(c / scale, sampleCap))
						table.insert(points, p)
						sum += p
					end
					local center = sum / #points
					local radius = 0
					for _, p in points do
						radius = math.max(radius, (p - center).Magnitude)
					end
					return center, radius
				end
				local function framed(
					names: { string },
					c: number,
					offset: Vector3,
					minWidth: number
				): (Vector3, Vector3, number)
					local center, radius = groupAt(names, c)
					local subject = center + LIFT
					return subject + offset, subject, math.max(minWidth, radius * 2 + 3)
				end
				-- Una viñeta de c0 a c1: la cámara a `offA` del grupo al principio y a `offB` al final.
				local function cellBetween(
					c0: number,
					c1: number,
					names: { string },
					offA: Vector3,
					offB: Vector3,
					minWidth: number,
					bg: string
				): ComicCell
					local posA, subjectA, widthA = framed(names, c0, offA, minWidth)
					local posB, subjectB, widthB = framed(names, c1, offB, minWidth)
					local cell = comicCell(c0, c1, posA, subjectA, widthA, bg, subjectB)
					cell.posB = posB
					cell.widthB = widthB
					return cell
				end
				-- La cámara en un sitio fijo del mapa, mirando al grupo.
				local function cellFixed(
					c0: number,
					c1: number,
					pos: Vector3,
					names: { string },
					minWidth: number,
					bg: string
				): ComicCell
					local _, subjectA, widthA = framed(names, c0, Vector3.zero, minWidth)
					local _, subjectB, widthB = framed(names, c1, Vector3.zero, minWidth)
					local cell = comicCell(c0, c1, pos, subjectA, widthA, bg, subjectB)
					cell.posB = pos
					cell.widthB = widthB
					return cell
				end
				local function followCells(
					c0: number,
					c1: number,
					step: number,
					names: { string },
					offset: Vector3,
					minWidth: number,
					bg: string
				): { ComicCell }
					local list: { ComicCell } = {}
					local count = math.max(1, math.round((c1 - c0) / step))
					for index = 1, count do
						local a = c0 + (c1 - c0) * (index - 1) / count
						local b = c0 + (c1 - c0) * index / count
						table.insert(list, cellBetween(a, b, names, offset, offset, minWidth, bg))
					end
					return list
				end
				local s = scale
				-- P1 Central (four_a): presentación del avatar, el rival rodando, el deslizamiento y el remate (la grande).
				sampleCap = 15.2 -- el salto a las Alcantarillas es a 15,3
				local cells1: { ComicCell } = {
					cellBetween(
						0,
						3.45 * s,
						{ "avatar" },
						Vector3.new(-6, 1.2, -7),
						Vector3.new(-5, 1.2, -6),
						7,
						"flat"
					),
					cellBetween(
						3.45 * s,
						6.2 * s,
						{ "pDart" },
						Vector3.new(8, 1.4, 5),
						Vector3.new(8, 1.4, 5),
						9,
						"dots"
					),
					cellBetween(
						6.2 * s,
						8.9 * s,
						{ "avatar" },
						Vector3.new(-5, 1, -9),
						Vector3.new(-5, 1, -9),
						9,
						"flat"
					),
				}
				local order1 = { 1, 2, 3 }
				for _, extra in
					followCells(8.9 * s, 15.45 * s, 1, { "avatar", "pDart" }, Vector3.new(4, 3, 12), 14, "dots")
				do
					table.insert(cells1, extra)
					table.insert(order1, 4)
				end
				addPage("four_a", COMIC_COLORS.jungle, nil, cells1, order1)
				-- P2 Alcantarillas (grid6): la carrera en fila, la red, el ácido, la contra-red, el deslizamiento y la salida.
				sampleCap = 29.7 -- el salto a la Azotea es a 29,8
				local duel = { "avatar", "pNet" }
				local cells2: { ComicCell } = {
					cellFixed(15.45 * s, 18 * s, sewer(-14.8, 3.6, 5.5), duel, 12, "flat"),
					cellFixed(18 * s, 20.5 * s, sewer(-14.8, 2.8, -5.4), duel, 12, "dots"),
					cellFixed(20.5 * s, 22.4 * s, sewer(-4.9, 6.2, 5.6), duel, 12, "flat"),
					cellFixed(22.4 * s, 24 * s, sewer(-5, 13, -5.5), duel, 14, "dots"),
					cellFixed(24 * s, 26.5 * s, sewer(-14.8, 2.8, -5.4), duel, 12, "flat"),
					cellFixed(26.5 * s, 30 * s, sewer(-4.9, 2.4, -5.4), duel, 12, "dots"),
				}
				addPage("grid6", COMIC_COLORS.mangrove, "down", cells2, { 1, 2, 3, 4, 5, 6 })
				-- P3 Azotea (four_b): el avatar en el helipuerto, los Piratas, el visor (muy cerrada) y el impacto (la grande).
				sampleCap = math.huge
				local cells3: { ComicCell } = {
					cellBetween(
						30 * s,
						34.5 * s,
						{ "avatar" },
						Vector3.new(-4, 1.2, -8),
						Vector3.new(-3, 1.2, -6),
						8,
						"flat"
					),
					cellBetween(
						34.5 * s,
						37 * s,
						{ "pDart", "pCannon" },
						Vector3.new(-6, 2.6, -5),
						Vector3.new(-6, 2.6, -5),
						12,
						"dots"
					),
					cellBetween(
						37 * s,
						39.8 * s,
						{ "avatar" },
						Vector3.new(-3, 0.4, -3.5),
						Vector3.new(-2.5, 0.4, -3),
						3.2,
						"flat"
					),
					cellBetween(
						39.8 * s,
						LAB_COMIC_SECONDS,
						{ "pDart" },
						Vector3.new(5.5, 0.6, 4),
						Vector3.new(5.5, 0.6, 4),
						9,
						"dots"
					),
				}
				addPage("four_b", COMIC_COLORS.mountain, "left", cells3, { 1, 2, 3, 4 })
				camera = cutShots(comicShots(cuts)) :: any
				addComicPages(events, cuts)

				local function narration(t: number, text: string, seconds: number)
					table.insert(events, {
						t = t,
						kind = "bubble",
						balloon = "narration",
						corner = "BL",
						onPage = true,
						text = text,
						seconds = seconds,
					})
				end
				local lastSfx = -math.huge
				local function sfx(
					t: number,
					text: string,
					layout: string,
					cell: number,
					fx: number,
					fy: number,
					rot: number
				)
					if t - lastSfx < 0.7 then
						return -- ninguna onomatopeya pisa a la anterior
					end
					lastSfx = t
					table.insert(events, {
						t = t,
						kind = "sfx",
						text = text,
						pos = ComicPages.cellPoint(layout, cell, fx, fy),
						rot = rot,
						size = 0.3,
						color = Color3.new(1, 1, 1),
						seconds = 0.6,
					})
				end
				narration(0.2, Strings.later("Un duelo en el Central."), 1.8)
				narration(15.5 * s + 0.1, Strings.later("Un duelo a corta distancia."), 2)
				narration(30 * s + 0.1, Strings.later("Y desde la azotea, un solo disparo."), 2.2)
				-- Solo la red y el ácido llevan onomatopeya de página: el golpe ya sale con el PEW! y el K.O.! del juego.
				sfx(18.55 * s, Strings.later("¡FLUP!"), "grid6", 2, 0.55, 0.3, -10)
				sfx(21.5 * s, Strings.later("¡SPLASH!"), "grid6", 3, 0.5, 0.3, 12)
				sfx(24.3 * s, Strings.later("¡ZAS!"), "grid6", 5, 0.5, 0.3, -12)
				sfx(39.7 * s, Strings.later("¡BLAM!"), "four_b", 3, 0.55, 0.3, -10)
				-- Cartel final en la viñeta grande: título, logo del juego y fundido a negro.
				table.insert(events, { t = 23.1, kind = "title", text = LAB_TITLE, seconds = 0.9 })
				table.insert(events, {
					t = 23.9,
					kind = "logo",
					text = Strings.later("Primal Banana Islands"),
					sub = Strings.later("Monkey Survival"),
					seconds = 0.5,
				})
				table.insert(events, { t = 24.1, kind = "fade", seconds = 0.5, toBlack = true })
			else
				-- Cámara de la versión larga. Corte seco: cada plano empieza 0,05 s después de acabar el anterior.
				local function put(t0: number, t1: number, a: CameraPoint, b: CameraPoint)
					pushShot(camera, if t0 == 0 then 0 else t0 + 0.05, t1, a, b)
				end
				local function follow(t0: number, t1: number, fn: (t: number) -> (Vector3, Vector3, number))
					ballgameFollow(camera, t0 + 0.05, t1, fn)
				end
				-- Una grúa o travelling con aceleración suave (smoothstep) entre dos encuadres.
				local function sweep(t0: number, t1: number, a: CameraPoint, b: CameraPoint)
					local start = t0 + 0.05
					follow(t0, t1, function(t)
						local u = math.clamp((t - start) / (t1 - start), 0, 1)
						local k = u * u * (3 - 2 * u)
						local fovA, fovB = a.fov or 55, b.fov or 55
						return a.pos:Lerp(b.pos, k), a.look:Lerp(b.look, k), fovA + (fovB - fovA) * k
					end)
				end
				-- Acto 1
				local avatarEye = A1_AVATAR + Vector3.new(0, 4.6, 0)
				-- 1.1 Presentación en dos planos cerrados (antes, un travelling por un pasillo vacío): el avatar con el rifle de
				-- bananas, de tres cuartos y de frente, y el rival que avanza hacia él con el lanzadardos.
				-- 1.1a La cámara empieza arriba y lejos (cabeza y rifle enteros) y baja acercándose al avatar, que apunta.
				put(
					0,
					1.6,
					shot(central(45.5, 1.4, 11.5), A1_AVATAR + Vector3.new(0, 2.4, 0), 50),
					shot(central(48.6, 4.5, 6.8), A1_AVATAR + Vector3.new(0, 4.4, 0), 36)
				)
				-- 1.1b Plano del Pirata que avanza hacia el avatar: la cámara va con él, de frente y de lado.
				follow(1.6, 2.8, function(t)
					local p = posAt("pDart", t)
					local k = (t - 1.6) / 1.2
					return p + Vector3.new(8 - 3 * k, 2.4, -7), p + Vector3.new(0, 2.6, 0), 44
				end)
				-- 1.1c El mismo Pirata en primera persona (la cámara la pone fpView en su cabeza).
				put(
					2.8,
					4,
					shot(central(26, 4.5, 5), A1_AVATAR + Vector3.new(0, 3, 0), 70),
					shot(central(27, 4.5, 5), A1_AVATAR + Vector3.new(0, 3, 0), 70)
				)
				put(4, 7, shot(avatarEye, lookAtPawn("pDart", 5.5), 70), shot(avatarEye, lookAtPawn("pDart", 6.5), 70))
				-- 1.3 La cámara recorre la línea de fuego de lado, de un duelista al otro, mientras los dos se mueven.
				put(
					7,
					10,
					shot(central(47, 3.4, 18), central(41.5, 1.8, 5.2), 66),
					shot(central(38, 3.4, 19), central(39, 1.8, 5.2), 74)
				)
				do
					-- Desde el norte, como el plano 1.3 pero más abajo y empujando: caben el tirador, la banana en vuelo y el rival.
					-- Detrás del hombro el avatar tapaba la pantalla y, a 9 studs, la Caja de x 34 (z 15) quedaba a 2 studs de la
					-- cámara (se vio en la grabación).
					local aim = central(38.5, 1.8, 4.8)
					put(
						10,
						14,
						shot(central(44, 2.6, 18), aim, 62),
						shot(central(39.5, 2, 12.5), aim:Lerp(central(35, 1.8, 5.4), 0.7), 50)
					)
				end
				do
					local fallen = posAt("pDart", 14.2) + Vector3.new(0, 14, 0)
					local center = posAt("pDart", 14.2)
					put(
						14,
						14.5,
						shot(fallen, center + Vector3.new(0, 0, -0.3), 60),
						shot(fallen, center + Vector3.new(0, 0, -0.3), 58)
					)
				end
				-- Acto 2: el duelo va en primera persona (fpView, alternando los dos duelistas). Esta cámara de esquina solo se ve en
				-- los huecos de 0,05 s entre vistas: queda en la esquina noroeste del claro, mirando al centro.
				put(
					14.5,
					29.5,
					shot(sewer(-14.8, 3.6, 5.5), sewer(-8.5, 1.8, 0.4), 60),
					shot(sewer(-13.2, 3.9, 5.4), sewer(-8.5, 1.8, 0.4), 58)
				)
				-- Acto 3
				-- 3.1 Grúa que sube desde justo bajo el borde, más rápida (3,5 s en vez de 4,5): el acto empieza en pleno movimiento.
				sweep(
					act.three,
					33,
					shot(roof(0, -4, 82), roof(0, 4, 40), 55),
					shot(roof(0, 22, 75), roof(0, 5, 35), 50)
				)
				-- 3.2 Travelling lateral por el sur, con los dos Piratas centrados (la cámara miraba a 4 studs por delante del primero
				-- y el segundo salía cortado): a 12 studs, un poco más alta, apuntando al punto medio entre los dos.
				follow(33, 37, function(t)
					local mid = (posAt("pDart", t) + posAt("pCannon", t)) / 2
					local h = heading("pDart", t)
					local side = Vector3.new(-h.Z, 0, h.X)
					return mid + side * 12 + Vector3.new(0, 3.2, 0), mid + Vector3.new(0, 2.2, 0), 64
				end)
				do
					local eye = A3_AVATAR + Vector3.new(0, 4.6, 0)
					put(37, 40, shot(eye, lookAtPawn("pDart", 38.5), 70), shot(eye, lookAtPawn("pDart", 40), 30))
				end
				do
					-- El impacto, de lado: perpendicular a la línea del tiro.
					local body = posAt("pDart", sniperAt)
					local line = ((body - A3_AVATAR) * Vector3.new(1, 0, 1)).Unit
					local side = Vector3.new(-line.Z, 0, line.X)
					local look = body + Vector3.new(0, 1.2, 0) + line * 0.8
					put(
						40,
						42,
						shot(body - side * 12 + Vector3.new(0, 2.6, 0), look, 45),
						shot(body - side * 10 + Vector3.new(0, 2.4, 0), look, 40)
					)
				end
				do
					-- Cierre en dronie: la cámara arranca junto a la cara del avatar, por delante, y se aleja subiendo mientras lo
					-- mantiene en el centro, hasta enseñar el helipuerto y la ciudad.
					local forward = ((A3_PDART_PATH[3] - A3_AVATAR) * Vector3.new(1, 0, 1)).Unit
					local face = A3_AVATAR + Vector3.new(0, 4.4, 0)
					sweep(
						42,
						LAB_SECONDS,
						shot(face + forward * 4.5 + Vector3.new(0, 0.4, 0), face, 42),
						shot(face + forward * 26 + Vector3.new(0, 20, 0), face, 58)
					)
				end

				table.insert(events, {
					t = 0.6,
					kind = "caption",
					text = Strings.later("Un duelo en el Central."),
					seconds = 2.6,
				})
				table.insert(events, {
					t = 15.9,
					kind = "caption",
					text = Strings.later("Un duelo a corta distancia."),
					seconds = 2.4,
				})
				table.insert(events, {
					t = 30.6,
					kind = "caption",
					text = Strings.later("Y desde la azotea, un solo disparo."),
					seconds = 2.6,
				})
				-- Cartel final, logo del juego y fundido (los mismos tiempos relativos que Pets, Mounts, Ballgame y Flag).
				table.insert(events, {
					t = 42.2,
					kind = "title",
					text = LAB_TITLE,
					sub = Strings.later("Shooter por equipos en primera persona"),
					seconds = 1.3,
				})
				table.insert(events, {
					t = 43.6,
					kind = "logo",
					text = Strings.later("Primal Banana Islands"),
					sub = Strings.later("Monkey Survival"),
					seconds = 0.9,
				})
				table.insert(events, { t = 44.4, kind = "fade", seconds = 0.6, toBlack = true })
			end

			return {
				duration = if comic then LAB_COMIC_SECONDS else LAB_SECONDS,
				audience = "Self",
				freeze = true,
				skippable = true,
				noBlur = true, -- sin DepthOfField ni Blur del place mientras suena (SceneLight)
				actors = actors,
				camera = camera,
				events = events,
			}
		end

		-- Cada variante va en su pcall, para que una que falle no tumbe a la otra ni al resto de cinemáticas.
		for name, variant in { Lab = "full", Lab_Comic = "comic" } do
			local labOk, labBuilt = pcall(labScene, variant)
			if labOk then
				scenes[name] = labBuilt :: Scene
			else
				warn(`Cinematics: no se pudo construir la escena {name}: {labBuilt}`)
			end
		end
	end
	buildLabScenes(out)
	return out
end)()

local Cinematics: { [string]: Scene } = {
	-- Motor en el Laboratorio (G12): escena de prueba; la lanza «🎬 Motor del Laboratorio» del panel del Laboratorio
	-- (LabCineController).
	LabEngine = labScenes.LabEngine,

	-- Laboratorio en ruinas (G13): las escenas de tres actos del tráiler y su variante cómic; las lanzan «🎬 Laboratorio en
	-- ruinas» y «… cómic» del panel del Laboratorio (LabCineController).
	Lab = labScenes.Lab,
	Lab_Comic = labScenes.Lab_Comic,

	-- Captura la bandera (G10): solo para grabar; las lanzan «🎬 Captura la bandera» y «… cómic» del panel de Dunas
	-- (DunasCineController).
	Flag = flagScenes.Flag,
	Flag_Comic = flagScenes.Flag_Comic,

	-- Juego de pelota (G9a y G9b): solo para grabar; las lanzan «🎬 Juego de pelota», «… reel» y «… cómic» del panel de
	-- Dunas (DunasCineController).
	Ballgame = if ballgameOk then ballgameBuilt :: Scene else nil,
	Ballgame_Reel = if ballgameReelOk then ballgameReelBuilt :: Scene else nil,
	Ballgame_Comic = if ballgameComicOk then ballgameComicBuilt :: Scene else nil,

	-- Monturas (G8a): solo para grabar; las lanzan «🐎 Monturas», «… reel» y «… cómic» del panel de pruebas.
	Mounts = mountsScene("full"),
	Mounts_Reel = mountsScene("reel"),
	Mounts_Comic = mountsScene("comic"),

	-- Mascotas (G7b y G7c): solo para grabar; las lanzan las órdenes «🐾 Mascotas», «… reel» y «… cómic» del panel de pruebas.
	Pets = petsScene("normal"),
	Pets_Reel = petsScene("reel"),
	Pets_Comic = petsScene("comic"),

	-- Batallas contra un jefe (G5b): solo para grabar; las lanza el panel de pruebas con ArrivalService.play y un stage.
	Battle_Boss_OrangutanDelManglar = bossBattleScene("OrangutanDelManglar", "normal"),
	Battle_Boss_OrangutanDelManglar_Comic = bossBattleScene("OrangutanDelManglar", "comic"),
	Battle_Boss_OrangutanDelManglar_Reel = bossBattleScene("OrangutanDelManglar", "reel"),
	Battle_Boss_ChimpanceCaudillo = bossBattleScene("ChimpanceCaudillo", "normal"),
	Battle_Boss_ChimpanceCaudillo_Comic = bossBattleScene("ChimpanceCaudillo", "comic"),
	Battle_Boss_ChimpanceCaudillo_Reel = bossBattleScene("ChimpanceCaudillo", "reel"),
	Battle_Boss_GorilaDeCeniza = bossBattleScene("GorilaDeCeniza", "normal"),
	Battle_Boss_GorilaAlbino = bossBattleScene("GorilaAlbino", "normal"),

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

	-- Sobrevuelo (S2): ver flyoverScene.
	Flyover = flyoverScene(false),
	Flyover_Comic = flyoverScene(true),

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
