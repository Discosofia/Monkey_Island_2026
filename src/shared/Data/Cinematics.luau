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
local Strings = require(script.Parent.Parent.Strings)

export type Scene = {
	duration: number,
	audience: string,
	freeze: boolean,
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
