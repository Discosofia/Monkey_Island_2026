--!strict
-- Escenas de las cinemáticas (Fase 25; Shared/Cinematics/Sequencer las reproduce). Cada una:
--   - duration: segundos. audience: quién la ve ("Self" solo quien la dispara, "All" todos los de la partida).
--   - freeze: true congela a los enemigos y protege a los jugadores mientras dura (jefes y rescate).
--   - anchor (opcional): dónde se ancla la escena ("boss" = el jefe); sin él, el que le dé quien la lanza.
--   - actors: { nombre = { kind = "dummy" | "localPlayer" | "boss" | "prop", … } } (ver Cinematics/Actors).
--   - camera: puntos { t, pos, look, fov? } con la posición y la mirada relativas al anchor (Cinematics/CameraPath).
--   - events: { t, kind, … } con letterbox, title, caption, fade (Presentation), anim, move (Actors), panel,
--     bubble, sfx (Comic, escenas «cómic») y los que registre cada place. Los textos se marcan con Strings.later y se traducen al dibujarlos.

local Bosses = require(script.Parent.Bosses)
local HelicopterModel = require(script.Parent.Parent.HelicopterModel)
local Strings = require(script.Parent.Parent.Strings)

export type Scene = {
	duration: number,
	audience: string,
	freeze: boolean,
	waitTerrain: { Vector3 }?, -- puntos (relativos al anchor) cuyo terreno debe estar cargado antes de empezar (streaming)
	skippable: boolean?, -- se puede saltar aunque no se haya visto entera (sin él, solo si ya está vista)
	anchor: string?,
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
}

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

local Cinematics: { [string]: Scene } = {
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
		{ side = -1, radius = 1.35, frontT = 2.4, skill = "eruption" }
	),
	Boss_GorilaDeCeniza_Comic = bossComicScene(
		"GorilaDeCeniza",
		Strings.later("Furia del volcán"),
		Strings.later("¡Todo arderá!"),
		Strings.later("Del fondo del volcán…"),
		{ Color3.fromRGB(196, 66, 18), Color3.fromRGB(255, 228, 176) },
		{ side = -1, radius = 1.35, frontT = 2.4, skill = "eruption" }
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

	-- Escena de prueba del motor: un maniquí guerrero camina hacia la cámara delante del jugador.
	Prueba = {
		duration = 6,
		audience = "Self",
		freeze = false,
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
