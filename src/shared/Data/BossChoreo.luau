--!strict
-- Coreografía de las batallas contra jefes (Fase 25, G14a): lo que hace la tripulación (correr, saltar, esquivar, caer,
-- forcejear), lo que le hace el jefe y lo que se ve (golpes, barra de vida, efectos del jefe), más los planos de cámara que
-- siguen cada guion. Módulo PURO: no requiere Cinematics.luau; devuelve listas de eventos `{ t, kind, … }` que el
-- Sequencer reproduce (anim, move, abilityFx, hit, bossBar, bossFx, shake y los de servidor bossAct y bossRoar).
--
-- Marco de coordenadas: el del jefe (el anchor es su pie). El jefe está en (0, 0) y mira a -Z; la tripulación está hacia -Z
-- (crewSpot) y «hacia el jefe» es +Z. Las posiciones de los maniquíes llevan Y = 0: la Y sale de un rayo al Terrain (snap) y
-- los saltos y las caídas suman altura con `rise` en el evento move (Actors).
-- Los campos de los eventos propios (BattleActor) no pueden llamarse «kind»: `hit` lleva `hitKind` y `bossFx` lleva `fx`.
--
-- Constructores: BossChoreo.orangutan, caudillo, albino y ceniza (ctx) devuelven { events, plan, ownLight? }. `plan` son
-- PlanShot (el formato de Data/Cinematics: cámara y mirada relativas a C, el centro de la tripulación). Si `ownLight` es
-- true, el guion trae su propia luz (eventos light y exposure) y Data/Cinematics quita la luz común de battleLight().
-- BossChoreo.build(nombre, ctx) elige el constructor por el campo `choreo` de la batalla.

local BossChoreo = {}

export type Event = { t: number, kind: string, [string]: any }
export type EventList = { Event }
export type PlanShot = {
	t0: number,
	t1: number,
	cam: { number },
	camB: { number }?,
	look: { any },
	lookB: { any }?,
	fov: number,
}
export type Context = {
	bossId: string,
	bossName: string, -- Bosses[id].name, sin traducir (el cliente lo traduce en la barra)
	crewSpot: (name: string) -> (number, number), -- (x, z) de un maniquí en el marco del jefe
	total: number, -- duración de la batalla
	torches: { string }?, -- maniquíes que llevan antorcha (BossBattle.torches)
}
export type Choreo = { events: EventList, plan: { PlanShot }, ownLight: boolean? }

local CREW = { "guerrero", "cazador", "mago", "medico" }
local RUN_ANIM_STUDS = 16 -- studs/s a los que la pista Run va a su velocidad
local FALL_DISTANCE = 1.5 -- cuánto se desplaza un caído de espaldas
local FALL_RISE = -1.7 -- el cuerpo queda a ras de suelo
local FALL_PITCH = 80
local STEP = 0.12 -- el forcejeo: un movimiento lateral cada 0,12 s
local STEP_SIDE = 0.3 -- studs de cada movimiento (la cámara está a 12, no más)
local QUAD = Enum.EasingStyle.Quad
local SINE = Enum.EasingStyle.Sine
local LINEAR = Enum.EasingStyle.Linear

-- ===================================== Utilidades =====================================

local function flat(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

-- Giro (grados) de quien mira hacia `dir`: yaw 0 mira a -Z y 180 a +Z.
local function yawOf(dir: Vector3): number
	return math.deg(math.atan2(-dir.X, -dir.Z))
end

-- Giro de quien está en `from` para mirar al jefe, que está en (0, 0).
local function yawToBoss(from: Vector3): number
	return yawOf(-from)
end

local function moveEvent(
	t: number,
	name: string,
	pos: Vector3,
	yaw: number,
	seconds: number,
	easing: Enum.EasingStyle?,
	extra: { pitch: number?, roll: number?, rise: number? }?
): Event
	return {
		t = t,
		kind = "move",
		actor = name,
		pos = pos,
		yaw = yaw,
		seconds = seconds,
		easing = easing or SINE,
		pitch = if extra then extra.pitch else nil,
		roll = if extra then extra.roll else nil,
		rise = if extra then extra.rise else nil,
	}
end

-- ===================================== Movimientos =====================================
-- Cada uno devuelve una lista de eventos. `from`, `to` y `pos` son del marco del jefe (Y = 0).

-- Corre de `from` a `to` entre t0 y t1 (la pista Run al ritmo de lo que avanza). Pone al actor en `from` al empezar.
-- `finalYaw` lo gira al llegar (por ejemplo hacia el jefe).
function BossChoreo.run(name: string, t0: number, t1: number, from: Vector3, to: Vector3, finalYaw: number?): EventList
	local seconds = math.max(t1 - t0, 0.05)
	local distance = (to - from).Magnitude
	local yaw = if distance > 0.01 then yawOf(to - from) else finalYaw or 0
	local events: EventList = {
		{
			t = t0,
			kind = "anim",
			actor = name,
			action = "Run",
			seconds = seconds,
			speed = distance / seconds / RUN_ANIM_STUDS,
		},
		moveEvent(t0, name, from, yaw, 0),
		moveEvent(t0, name, to, yaw, seconds, LINEAR),
	}
	if finalYaw then
		table.insert(events, moveEvent(t1, name, to, finalYaw, 0.15))
	end
	return events
end

-- Un salto con arco (la pista DodgeRoll lo convierte en voltereta): sube `height` studs hasta la mitad inclinándose hacia
-- delante (pitch) y baja.
function BossChoreo.leap(
	name: string,
	t: number,
	from: Vector3,
	to: Vector3,
	height: number,
	seconds: number,
	yaw: number
): EventList
	return {
		{ t = t, kind = "anim", actor = name, action = "DodgeRoll", seconds = seconds },
		moveEvent(t, name, from:Lerp(to, 0.5), yaw, seconds / 2, QUAD, { rise = height, pitch = -12 }),
		moveEvent(t + seconds / 2, name, to, yaw, seconds / 2, QUAD, { rise = 0, pitch = 0 }),
	}
end

-- Una esquiva: voltereta baja de `dist` studs hacia `dir` (completa en `seconds`, 0,45 por defecto).
function BossChoreo.dodge(
	name: string,
	t: number,
	from: Vector3,
	dir: Vector3,
	dist: number,
	yaw: number,
	seconds: number?
): EventList
	return BossChoreo.leap(name, t, from, from + dir.Unit * dist, 0.9, seconds or 0.45, yaw)
end

-- Un salto hacia atrás (DodgeBack): sube con un impulso y cae en `to`.
function BossChoreo.hop(name: string, t: number, from: Vector3, to: Vector3, yaw: number): EventList
	return {
		{ t = t, kind = "anim", actor = name, action = "DodgeBack", seconds = 0.8 },
		moveEvent(t, name, from:Lerp(to, 0.5), yaw, 0.25, QUAD, { rise = 1.8 }),
		moveEvent(t + 0.25, name, to, yaw, 0.3, QUAD, { rise = 0 }),
	}
end

-- Un tropiezo: un salto corto hacia atrás, `dist` studs (2,5) en la dirección `dir`.
function BossChoreo.stagger(name: string, t: number, from: Vector3, dir: Vector3, yaw: number, dist: number?): EventList
	return BossChoreo.hop(name, t, from, from + dir.Unit * (dist or 2.5), yaw)
end

-- Dónde queda un caído de espaldas (para encadenar con getUp).
function BossChoreo.fallenPos(pos: Vector3, away: Vector3): Vector3
	return pos + away.Unit * FALL_DISTANCE
end

-- Cae de espaldas hacia `away`: el cuerpo se tumba (pitch) y queda a ras de suelo.
function BossChoreo.knockDown(
	name: string,
	t: number,
	pos: Vector3,
	away: Vector3,
	yaw: number,
	seconds: number?
): EventList
	return {
		moveEvent(
			t,
			name,
			BossChoreo.fallenPos(pos, away),
			yaw,
			seconds or 0.9,
			QUAD,
			{ pitch = FALL_PITCH, rise = FALL_RISE }
		),
	}
end

-- Se levanta en `pos` (el sitio donde estaba de pie).
function BossChoreo.getUp(name: string, t: number, pos: Vector3, yaw: number, seconds: number?): EventList
	return { moveEvent(t, name, pos, yaw, seconds or 0.6, QUAD, { pitch = 0, rise = 0 }) }
end

-- Forcejea en `pos` entre t0 y t1: movimientos laterales pequeños, uno cada 0,12 s, y vuelve a su sitio.
function BossChoreo.jitter(name: string, t0: number, t1: number, pos: Vector3, yaw: number): EventList
	local events: EventList = {}
	local steps = math.max(math.floor((t1 - t0) / STEP) - 1, 1)
	for index = 0, steps - 1 do
		local side = if index % 2 == 0 then 1 else -1
		table.insert(
			events,
			moveEvent(
				t0 + index * STEP,
				name,
				pos + Vector3.new(side * STEP_SIDE, 0, 0),
				yaw,
				STEP,
				SINE,
				{ roll = side * 5 }
			)
		)
	end
	table.insert(events, moveEvent(t0 + steps * STEP, name, pos, yaw, STEP, SINE, { roll = 0 }))
	return events
end

-- ===================================== Escritores =====================================

function BossChoreo.anim(t: number, name: string, action: string, seconds: number?): Event
	return { t = t, kind = "anim", actor = name, action = action, seconds = seconds }
end

-- Una habilidad de AbilityShow (evento abilityFx; el campo es «fx»).
function BossChoreo.skill(t: number, fx: string, from: string, to: any, args: { [string]: any }?): Event
	return { t = t, kind = "abilityFx", fx = fx, from = from, to = to, args = args }
end

-- Un golpe (BattleActor): hitKind = "Dealt" | "Taken" | "Heal"; opts = { crit?, ko?, pow? }.
function BossChoreo.hit(
	t: number,
	actor: string,
	amount: number,
	hitKind: string,
	opts: { crit: boolean?, ko: boolean?, pow: boolean? }?
): Event
	return {
		t = t,
		kind = "hit",
		actor = actor,
		amount = amount,
		hitKind = hitKind,
		crit = if opts then opts.crit else nil,
		ko = if opts then opts.ko else nil,
		pow = if opts then opts.pow else nil,
	}
end

-- La barra de vida del jefe (BattleActor): de la fracción `from` a `to` en `seconds`.
function BossChoreo.bar(t: number, name: string, from: number, to: number, seconds: number?, color: Color3?): Event
	return { t = t, kind = "bossBar", name = name, from = from, to = to, seconds = seconds, color = color }
end

-- Un efecto real del jefe (BattleActor): opts = { actor?, pos?, warn?, flight?, radius?, direction?, origin? }.
function BossChoreo.bossFx(t: number, fx: string, style: string, opts: { [string]: any }?): Event
	local event: Event = { t = t, kind = "bossFx", fx = fx, style = style }
	for field, value in opts or {} do
		event[field] = value
	end
	return event
end

-- Gesto del jefe (lo lanza el servidor: IslandBossHooks) y su rugido.
function BossChoreo.bossAct(t: number, action: string): Event
	return { t = t, kind = "bossAct", server = true, action = action }
end

function BossChoreo.bossRoar(t: number): Event
	return { t = t, kind = "bossRoar", server = true }
end

function BossChoreo.shake(t: number, amp: number, seconds: number): Event
	return { t = t, kind = "shake", amp = amp, seconds = seconds }
end

-- Enciende o apaga la antorcha de un actor (BattleActor: evento torch). `brightness` solo al encender (2 por defecto).
function BossChoreo.torch(t: number, actor: string, lit: boolean, brightness: number?): Event
	return { t = t, kind = "torch", actor = actor, lit = lit, brightness = brightness }
end

-- Segundos que tarda el anillo del rugido (bossFx roar, que BossFx abre de 3 a 45 studs en 1,1 s con Quad Out) en llegar a
-- `dist` studs del pie del jefe: de d = 3 + 42·(1 - (1 - t/1,1)²) sale t = 1,1·(1 - √(1 - (d - 3)/42)).
function BossChoreo.roarReach(dist: number): number
	if dist <= 3 then
		return 0
	elseif dist >= 45 then
		return 1.1
	end
	return 1.1 * (1 - math.sqrt(1 - (dist - 3) / 42))
end

-- Luz que sigue a la cámara (SceneLight: evento light con follow): `seconds` la apaga sola con un fundido de 0,4 s.
local function followLight(t: number, color: Color3, brightness: number, range: number, seconds: number?): Event
	return {
		t = t,
		kind = "light",
		follow = true,
		offset = Vector3.new(0, 3, 0),
		color = color,
		brightness = brightness,
		range = range,
		seconds = seconds,
	}
end

local function exposure(t: number, value: number): Event
	return { t = t, kind = "exposure", value = value }
end

local function shot(
	t0: number,
	t1: number,
	cam: { number },
	look: { any },
	fov: number,
	camB: { number }?,
	lookB: { any }?
): PlanShot
	return { t0 = t0, t1 = t1, cam = cam, camB = camB, look = look, lookB = lookB, fov = fov }
end

-- ===================================== Guion =====================================

-- Lo que se repite en cada guion: la lista de eventos con sus escritores, el sitio de cada maniquí y la entrada.
type Writer = {
	events: EventList,
	spots: { [string]: Vector3 },
	add: (event: Event) -> (),
	addAll: (list: EventList) -> (),
	bar: (t: number, from: number, to: number, seconds: number?) -> (),
	enter: () -> (),
	bow: (t: number, aimSeconds: number) -> (),
	shoot: (tFx: number, to: any) -> (),
	fireball: (tAim: number, tFx: number) -> (),
	cheer: (t: number) -> (),
}

local function newWriter(ctx: Context): Writer
	local events: EventList = {}
	local spots: { [string]: Vector3 } = {}
	for _, name in CREW do
		local x, z = ctx.crewSpot(name)
		spots[name] = flat(x, z)
	end
	local function add(event: Event)
		table.insert(events, event)
	end
	local function addAll(list: EventList)
		for _, event in list do
			table.insert(events, event)
		end
	end
	-- La barra de vida con el nombre del jefe ya puesto.
	local function bar(t: number, from: number, to: number, seconds: number?)
		add(BossChoreo.bar(t, ctx.bossName, from, to, seconds))
	end
	return {
		events = events,
		spots = spots,
		add = add,
		addAll = addAll,
		bar = bar,
		-- 0 a 2,4: los cuatro corren desde 9 studs detrás de su sitio; 0,8: sale la barra; 2,5: rugido y temblor.
		enter = function()
			for _, name in CREW do
				local spot = spots[name]
				addAll(BossChoreo.run(name, 0, 2.4, spot + Vector3.new(0, 0, -9), spot, yawToBoss(spot)))
			end
			bar(0.8, 1, 1)
			add(BossChoreo.bossRoar(2.5))
			add(BossChoreo.shake(2.5, 0.3, 0.7))
		end,
		-- El cazador apunta (AimBow) y suelta la flecha 0,16 s antes de la habilidad MultiShot.
		bow = function(t: number, aimSeconds: number)
			add(BossChoreo.anim(t, "cazador", "AimBow", aimSeconds))
		end,
		shoot = function(tFx: number, to: any)
			add(BossChoreo.anim(tFx - 0.16, "cazador", "Arrow", 0.7))
			add(BossChoreo.skill(tFx, "MultiShot", "cazador", to))
		end,
		-- El mago apunta, hace el gesto 0,12 s antes de la Bola de fuego y la lanza.
		fireball = function(tAim: number, tFx: number)
			add(BossChoreo.anim(tAim, "mago", "AimSpell", 1.0))
			add(BossChoreo.anim(tFx - 0.12, "mago", "Spell", 0.6))
			add(BossChoreo.skill(tFx, "Fireball", "mago", "boss"))
		end,
		-- Celebran los cuatro.
		cheer = function(t: number)
			for _, name in CREW do
				add(BossChoreo.anim(t, name, "Cheer", 1.4))
			end
		end,
	}
end

-- Los planos que comparten los dos guiones (los de bossPlan() de Data/Cinematics).
local function openingShots(roarEnd: number): { PlanShot }
	return {
		-- Plano general desde el costado.
		shot(0, 2.5, { 26, 7, 8 }, { "mid", "C", 5 }, 56, { 26, 6, 2 }, { "mid", "C", 5 }),
		-- Rugido del jefe, a su cara.
		shot(2.5, roarEnd, { 18, 10, -10 }, { "abs", 0, 9, 0 }, 46, { 17, 10, -9 }),
	}
end

-- Meteoro, muerte del jefe y celebración.
local function closingShot(total: number): PlanShot
	return shot(12.0, total, { 22, 8, -10 }, { "abs", 0, 7, 0 }, 55, { 22, 10, -10 }, { "abs", 0, 7, -6 })
end

-- Orangután del Manglar: dispara el cazador y el mago, el jefe ataca al guerrero (que esquiva), las lianas atrapan al
-- cazador, el guerrero salta y las rompe, el médico lo cura y el contraataque remata al jefe.
-- Efectos grandes de AbilityShow (no más de 2 vivos ni 2 inicios a menos de 0,4 s): Rompehuesos 7,5 a 8,9 · Curación 7,95
-- a 9,35 · Nova 9,0 a 10,8 · Lluvia 9,7 a 11,9 · Rompehuesos 11,45 a 12,85 · Meteoro 12,2 a 14,2.
function BossChoreo.orangutan(ctx: Context): Choreo
	local s = newWriter(ctx)
	local gSpot, cSpot = s.spots.guerrero, s.spots.cazador
	local yawG, yawC = yawToBoss(gSpot), yawToBoss(cSpot)

	s.enter()

	-- Disparan desde lejos; el jefe se queja con cada golpe.
	s.bow(2.6, 1.8)
	s.shoot(2.95, "boss")
	s.add(BossChoreo.hit(3.1, "boss", 180, "Dealt"))
	s.bar(3.1, 1, 0.88)
	s.fireball(3.3, 3.6)
	s.add(BossChoreo.hit(3.95, "boss", 410, "Dealt", { crit = true }))
	s.bar(3.95, 0.88, 0.70)
	s.add(BossChoreo.bossAct(4.0, "Hurt"))

	-- El jefe golpea al guerrero y este esquiva (la esquiva empieza 0,5 s antes del golpe).
	s.add(BossChoreo.bossAct(4.4, "Attack"))
	s.addAll(BossChoreo.dodge("guerrero", 4.55, gSpot, Vector3.xAxis, 5, yawG, 0.45))
	local gAfterDodge = gSpot + Vector3.new(5, 0, 0)

	-- El poder: las lianas atrapan al cazador, que forcejea.
	s.add(BossChoreo.bossAct(5.2, "Attack"))
	s.add(BossChoreo.bossFx(5.5, "grab", ctx.bossId, { actor = "cazador" }))
	s.add(BossChoreo.hit(5.9, "cazador", 45, "Taken"))
	s.addAll(BossChoreo.jitter("cazador", 5.9, 7.2, cSpot, yawC))

	-- El guerrero corre hacia el cazador (7,5 studs), salta por encima y rompe las lianas con Rompehuesos.
	local toCazador = (cSpot - gAfterDodge).Unit
	local gRun = gAfterDodge + toCazador * 7.5
	local landing = cSpot + (gRun - cSpot).Unit * 1.8
	s.addAll(BossChoreo.run("guerrero", 6.2, 6.9, gAfterDodge, gRun))
	s.addAll(BossChoreo.leap("guerrero", 6.9, gRun, landing, 2.2, 0.45, yawOf(landing - gRun)))
	s.add(BossChoreo.anim(7.35, "guerrero", "Smash", 0.8))
	s.add(BossChoreo.skill(7.5, "Smash", "guerrero", "cazador"))
	-- El cazador cae (suave, hacia atrás: lejos de la cámara) y se levanta; el médico lo cura en área.
	local fallDir = Vector3.new(0.2, 0, -0.98)
	s.addAll(BossChoreo.knockDown("cazador", 7.55, cSpot, fallDir, yawC, 0.9))
	s.addAll(BossChoreo.getUp("cazador", 8.45, cSpot, yawC, 0.6))
	s.add(BossChoreo.anim(7.75, "medico", "CastArea", 1.1))
	s.add(BossChoreo.skill(7.95, "AreaHeal", "cazador", nil))
	s.add(BossChoreo.hit(8.1, "cazador", 120, "Heal"))
	-- El guerrero vuelve a su sitio.
	s.addAll(BossChoreo.run("guerrero", 8.6, 9.5, landing, gSpot, yawG))

	-- Contraataque: Nova de hielo del mago y Lluvia de flechas del cazador.
	s.add(BossChoreo.anim(8.85, "mago", "CastArea", 1.0))
	s.add(BossChoreo.skill(9.0, "FrostNova", "mago", "boss", { radius = 12 }))
	s.add(BossChoreo.skill(9.15, "Frozen", "mago", "boss", { seconds = 1.5 }))
	s.add(BossChoreo.hit(9.2, "boss", 260, "Dealt"))
	s.bar(9.2, 0.70, 0.52)
	s.bow(9.5, 1.3)
	s.add(BossChoreo.anim(9.54, "cazador", "Arrow", 0.7))
	s.add(BossChoreo.skill(9.7, "ArrowRain", "cazador", Vector3.new(0, 0, -2), { radius = 10, seconds = 1.2 }))
	s.add(BossChoreo.hit(10.0, "boss", 150, "Dealt"))
	s.bar(10.0, 0.52, 0.44)
	s.add(BossChoreo.hit(10.15, "boss", 150, "Dealt"))
	s.bar(10.15, 0.44, 0.36)
	s.add(BossChoreo.hit(10.3, "boss", 210, "Dealt"))
	s.bar(10.3, 0.36, 0.28)

	-- Remate: Embestida del guerrero hasta el jefe (llega a z -6 a 11,05) y Rompehuesos.
	local hitSpot = flat(0, -6)
	s.add(BossChoreo.anim(10.5, "guerrero", "Charge", 0.7))
	s.add(BossChoreo.skill(10.5, "Charge", "guerrero", nil, { seconds = 0.7 }))
	s.add(moveEvent(10.5, "guerrero", hitSpot, yawToBoss(hitSpot), 0.55, QUAD))
	s.add(BossChoreo.anim(11.25, "guerrero", "Smash", 0.8))
	s.add(BossChoreo.skill(11.45, "Smash", "guerrero", "boss"))
	s.add(BossChoreo.hit(11.45, "boss", 620, "Dealt", { crit = true }))
	s.bar(11.45, 0.28, 0.06)
	s.add(BossChoreo.bossAct(11.5, "Hurt"))
	s.add(BossChoreo.shake(11.45, 0.35, 0.5))

	-- El guerrero se aparta del meteoro; el mago lo invoca; el jefe cae.
	s.addAll(BossChoreo.run("guerrero", 12.0, 12.7, hitSpot, gSpot, yawG))
	s.add(BossChoreo.anim(12.0, "mago", "CastArea", 1.0))
	s.add(BossChoreo.skill(12.2, "Meteor", "mago", "boss", { radius = 8 }))
	s.cheer(12.6)
	s.add(BossChoreo.hit(13.0, "boss", 700, "Dealt", { ko = true }))
	s.bar(13.0, 0.06, 0, 0.25)
	s.add(BossChoreo.bossAct(13.05, "Die"))

	-- Planos. El tercero (el guerrero) conserva el ajuste del Orangután: en el manglar los troncos tapaban el otro.
	local plan = openingShots(3.9)
	table.insert(plan, shot(3.9, 5.2, { 22.5, 4, 2 }, { "mid", "guerrero", 3.5 }, 52))
	table.insert(plan, shot(5.2, 7.9, { -20, 5, 2 }, { "crew", "cazador", 3 }, 52))
	table.insert(plan, shot(7.9, 9.4, { 22, 9, 0 }, { "mid", "C", 3 }, 58))
	table.insert(plan, shot(9.4, 10.4, { 22, 8, -12 }, { "abs", 0, 6, 0 }, 46, { 20, 9, -12 }))
	table.insert(plan, shot(10.4, 12.0, { -23, 3.4, -7 }, { "mid", "guerrero", 3.5 }, 52))
	table.insert(plan, closingShot(ctx.total))
	return { events = s.events, plan = plan }
end

-- Posición en el segundo `t` de un recorrido de varios tramos (puntos y segundos de llegada a cada uno).
local function pathAt(points: { Vector3 }, times: { number }, t: number): Vector3
	if t <= times[1] then
		return points[1]
	end
	for index = 2, #points do
		if t <= times[index] then
			local u = (t - times[index - 1]) / (times[index] - times[index - 1])
			return points[index - 1]:Lerp(points[index], u)
		end
	end
	return points[#points]
end

-- Chimpancé Caudillo: el poder es una lluvia de rocas en tres oleadas con aviso. Cada una la esquiva alguien (el guerrero
-- salta, el cazador rueda, el mago retrocede); al médico, que reacciona tarde, le da una; el guerrero sube corriendo en
-- zigzag entre las últimas y remata al jefe.
-- Efectos grandes de AbilityShow: Nova 6,9 a 8,7 · Curación 8,3 a 9,7 · Rompehuesos 10,2 a 11,6 · Meteoro 12,2 a 14,2.
function BossChoreo.caudillo(ctx: Context): Choreo
	local s = newWriter(ctx)
	local gSpot, cSpot, mSpot, dSpot = s.spots.guerrero, s.spots.cazador, s.spots.mago, s.spots.medico
	local yawG, yawC, yawM, yawD = yawToBoss(gSpot), yawToBoss(cSpot), yawToBoss(mSpot), yawToBoss(dSpot)
	local style = "ChimpanceCaudillo"
	local function rock(t: number, pos: Vector3, warn: number)
		s.add(BossChoreo.bossFx(t, "rock", style, { pos = pos, warn = warn, flight = 0.4, radius = 6 }))
	end

	s.enter()

	-- OLA 1 (T = 3,2): rocas sobre el guerrero y el cazador, donde estaban. Impacto a T + 1,6; salen del radio a tiempo.
	s.add(BossChoreo.bossAct(2.6, "Throw"))
	rock(3.2, gSpot, 1.2)
	rock(3.2, cSpot, 1.2)
	local gWave = gSpot + Vector3.new(8, 0, 0)
	s.addAll(BossChoreo.leap("guerrero", 3.8, gSpot, gWave, 2.2, 0.5, yawG))
	s.addAll(BossChoreo.dodge("cazador", 3.8, cSpot, -Vector3.xAxis, 8, yawC, 0.45))
	local cWave = cSpot - Vector3.new(8, 0, 0)

	-- Mientras tanto disparan el mago y el cazador.
	s.fireball(3.3, 3.6)
	s.add(BossChoreo.hit(4.0, "boss", 300, "Dealt", { crit = true }))
	s.bar(4.0, 1, 0.86)
	s.bow(4.5, 1.3)
	s.shoot(4.85, "boss")
	s.add(BossChoreo.hit(5.0, "boss", 120, "Dealt"))
	s.bar(5.0, 0.86, 0.80)

	-- OLA 2 (T = 5,2): rocas sobre el mago (retrocede de un salto) y el médico (reacciona tarde y recibe la roca).
	s.add(BossChoreo.bossAct(4.9, "Throw"))
	rock(5.2, mSpot, 1.2)
	rock(5.2, dSpot, 1.2)
	s.addAll(BossChoreo.hop("mago", 5.8, mSpot, mSpot + Vector3.new(0, 0, -8), yawM))
	local dStep = dSpot - Vector3.new(2.5, 0, 0)
	s.addAll(BossChoreo.run("medico", 6.45, 6.8, dSpot, dStep, yawD))
	s.add(BossChoreo.hit(6.8, "medico", 60, "Taken"))
	s.addAll(BossChoreo.knockDown("medico", 6.8, dStep, Vector3.new(0, 0, -1), yawD, 0.9))
	s.addAll(BossChoreo.getUp("medico", 7.9, dStep, yawD, 0.6))

	-- Nova de hielo del mago; después el médico se cura a sí mismo.
	s.add(BossChoreo.anim(6.7, "mago", "CastArea", 1.0))
	s.add(BossChoreo.skill(6.9, "FrostNova", "mago", "boss", { radius = 12 }))
	s.add(BossChoreo.skill(7.05, "Frozen", "mago", "boss", { seconds = 1.5 }))
	s.add(BossChoreo.hit(7.1, "boss", 240, "Dealt"))
	s.bar(7.1, 0.80, 0.60)
	s.add(BossChoreo.anim(8.1, "medico", "CastArea", 1.1))
	s.add(BossChoreo.skill(8.3, "AreaHeal", "medico", nil))
	s.add(BossChoreo.hit(8.4, "medico", 60, "Heal"))

	-- OLA 3 (T = 7,3): el guerrero sube corriendo en zigzag (3 tramos de 9,5 studs de lado) y las rocas caen detrás de él;
	-- otra cae sobre el cazador, que rueda a T + 1,4.
	local points = { gWave, flat(2.5, -13), flat(12, -10), flat(2.5, -7) }
	local times = { 7.3, 8.0, 8.7, 9.4 }
	s.add(BossChoreo.bossAct(7.0, "Throw"))
	for index = 1, 3 do
		s.addAll(BossChoreo.run("guerrero", times[index], times[index + 1], points[index], points[index + 1]))
	end
	local hitSpot = points[4]
	s.add(moveEvent(9.4, "guerrero", hitSpot, yawToBoss(hitSpot), 0.15, SINE))
	-- Cada roca cae donde estaba el guerrero un rato antes: a más de radio + 2,5 de donde está en el impacto.
	for _, warn in { 1.2, 1.4 } do
		local impact = 7.3 + warn + 0.4
		local now = pathAt(points, times, impact)
		local center, far = points[1], -1
		for lag = 0.5, 1.6, 0.1 do
			local candidate = pathAt(points, times, impact - lag)
			local away = (candidate - now).Magnitude
			if away > far then
				center, far = candidate, away
			end
			if away >= 8.5 then
				center = candidate
				break
			end
		end
		rock(7.3, center, warn)
	end
	rock(7.3, cWave, 1.6)
	s.addAll(BossChoreo.dodge("cazador", 8.7, cWave, Vector3.xAxis, 8, yawC, 0.45))

	-- El guerrero llega junto al jefe (z -7): Embestida, Rompehuesos y golpe crítico.
	s.add(BossChoreo.skill(9.2, "Charge", "guerrero", nil, { seconds = 0.6 }))
	s.add(BossChoreo.anim(10.0, "guerrero", "Smash", 0.8))
	s.add(BossChoreo.skill(10.2, "Smash", "guerrero", "boss"))
	s.add(BossChoreo.hit(10.3, "boss", 560, "Dealt", { crit = true }))
	s.bar(10.3, 0.60, 0.30)
	s.add(BossChoreo.bossAct(10.3, "Hurt"))
	s.add(BossChoreo.shake(10.3, 0.35, 0.5))

	-- Cazador y mago rematan desde lejos.
	s.bow(10.2, 1.3)
	s.shoot(10.6, "boss")
	s.add(BossChoreo.hit(10.75, "boss", 160, "Dealt"))
	s.bar(10.75, 0.30, 0.24)
	s.add(BossChoreo.hit(10.9, "boss", 160, "Dealt"))
	s.bar(10.9, 0.24, 0.18)
	s.fireball(10.9, 11.2)
	s.add(BossChoreo.hit(11.55, "boss", 300, "Dealt"))
	s.bar(11.55, 0.18, 0.02)

	-- El guerrero se aparta del meteoro; el mago lo invoca; el jefe cae.
	s.addAll(BossChoreo.run("guerrero", 11.5, 12.2, hitSpot, gSpot, yawG))
	s.add(BossChoreo.anim(12.0, "mago", "CastArea", 1.0))
	s.add(BossChoreo.skill(12.2, "Meteor", "mago", "boss", { radius = 8 }))
	s.cheer(12.6)
	s.add(BossChoreo.hit(13.0, "boss", 700, "Dealt", { ko = true }))
	s.bar(13.0, 0.02, 0, 0.25)
	s.add(BossChoreo.bossAct(13.05, "Die"))

	-- Planos (los de bossPlan() con los tiempos de este guion).
	local plan = openingShots(3.5)
	table.insert(plan, shot(3.5, 5.2, { 22, 8, -12 }, { "mid", "C", 4 }, 50, { 20, 9, -12 }))
	table.insert(plan, shot(5.2, 7.3, { 26, 6, 6 }, { "mid", "C", 4 }, 52))
	table.insert(plan, shot(7.3, 9.4, { 22, 8, -12 }, { "abs", 3, 3, -10 }, 48, { 20, 9, -12 }))
	table.insert(plan, shot(9.4, 10.5, { -20, 3.4, -6 }, { "mid", "guerrero", 3.5 }, 52))
	table.insert(plan, shot(10.5, 12.0, { 22, 9, 0 }, { "mid", "C", 3 }, 58))
	table.insert(plan, closingShot(ctx.total))
	return { events = s.events, plan = plan }
end

-- Gorila Albino: la cueva está a oscuras y la única luz es la del guion. Entran con antorchas (guerrero, mago y médico); el
-- guerrero esquiva un zarpazo y pega; el resoplido del jefe apaga las antorchas cuando el anillo llega a cada uno (roarReach)
-- y los tira hacia atrás; en la penumbra una púa de cristal, un tropiezo y otro zarpazo; el mago reenciende las antorchas
-- y la tripulación contraataca.
-- Efectos grandes de AbilityShow: Rompehuesos 5,05 a 6,45 · Nova 9,0 a 10,8 · Lluvia 9,7 a 11,9 · Rompehuesos 11,45 a 12,85
-- · Meteoro 12,2 a 14,2.
function BossChoreo.albino(ctx: Context): Choreo
	local s = newWriter(ctx)
	local gSpot, cSpot, mSpot, dSpot = s.spots.guerrero, s.spots.cazador, s.spots.mago, s.spots.medico
	local yawG, yawC, yawM, yawD = yawToBoss(gSpot), yawToBoss(cSpot), yawToBoss(mSpot), yawToBoss(dSpot)
	local style = "GorilaAlbino"
	local back = Vector3.new(0, 0, -1) -- «hacia atrás» respecto al jefe
	local carries: { [string]: boolean } = {}
	for _, name in ctx.torches or {} do
		carries[name] = true
	end
	local function torch(t: number, name: string, lit: boolean)
		if carries[name] then
			s.add(BossChoreo.torch(t, name, lit))
		end
	end
	local function reach(pos: Vector3): number
		return BossChoreo.roarReach(math.sqrt(pos.X * pos.X + pos.Z * pos.Z))
	end

	s.enter()
	-- Las antorchas entran encendidas; el evento dimLights de t = 0 les baja la luz y este se la devuelve.
	for _, name in CREW do
		torch(0.05, name, true)
	end

	-- A la luz de las antorchas: disparan el cazador y el mago.
	s.bow(2.6, 1.8)
	s.shoot(2.95, "boss")
	s.add(BossChoreo.hit(3.1, "boss", 180, "Dealt"))
	s.bar(3.1, 1, 0.90)
	s.fireball(3.3, 3.6)
	s.add(BossChoreo.hit(3.95, "boss", 400, "Dealt", { crit = true }))
	s.bar(3.95, 0.90, 0.70)

	-- El guerrero corre hasta el jefe, esquiva su zarpazo hacia un lado y le pega con Rompehuesos.
	local gNear = flat(3, -8)
	s.addAll(BossChoreo.run("guerrero", 3.4, 4.2, gSpot, gNear, yawToBoss(gNear)))
	s.add(BossChoreo.bossAct(4.3, "Attack"))
	local gDodged = gNear + Vector3.new(4, 0, 0)
	local yawG2 = yawToBoss(gDodged)
	s.addAll(BossChoreo.dodge("guerrero", 4.4, gNear, Vector3.xAxis, 4, yawG2, 0.45))
	s.add(BossChoreo.anim(4.9, "guerrero", "Smash", 0.8))
	s.add(BossChoreo.skill(5.05, "Smash", "guerrero", "boss"))
	s.add(BossChoreo.hit(5.05, "boss", 300, "Dealt"))
	s.bar(5.05, 0.70, 0.55)

	-- El resoplido: el anillo llega a cada uno según su distancia, le apaga la antorcha y lo echa hacia atrás.
	local roarT = 5.6
	s.add(BossChoreo.bossAct(5.4, "Roar"))
	s.add(BossChoreo.bossFx(roarT, "roar", style, { pos = flat(0, 0), radius = 45 }))
	s.add(BossChoreo.shake(roarT, 0.4, 0.8))
	-- El guerrero, pegado al jefe, cae de espaldas y se levanta a 6,9.
	local tG = roarT + reach(gDodged)
	torch(tG, "guerrero", false)
	s.add(BossChoreo.hit(tG, "guerrero", 90, "Taken"))
	s.addAll(BossChoreo.knockDown("guerrero", tG, gDodged, back, yawG2, 0.9))
	s.addAll(BossChoreo.getUp("guerrero", 6.9, gDodged, yawG2, 0.6))
	-- El mago retrocede solo 1,5 studs.
	local tM = roarT + reach(mSpot)
	torch(tM, "mago", false)
	s.addAll(BossChoreo.stagger("mago", tM, mSpot, mSpot, yawM, 1.5))
	-- El médico retrocede.
	local tD = roarT + reach(dSpot)
	torch(tD, "medico", false)
	s.addAll(BossChoreo.stagger("medico", tD, dSpot, dSpot, yawD))
	local dPushed = dSpot + dSpot.Unit * 2.5
	-- El cazador retrocede (sin antorcha) y, ya en la penumbra, tropieza hacia +X.
	local tC = roarT + reach(cSpot)
	s.addAll(BossChoreo.stagger("cazador", tC, cSpot, cSpot, yawC))
	local cPushed = cSpot + cSpot.Unit * 2.5
	s.addAll(BossChoreo.stagger("cazador", 6.4, cPushed, Vector3.xAxis, yawC, 1.5))

	-- En la penumbra: una púa de cristal sobre el médico, que rueda hacia -X y vuelve corriendo a su sitio.
	s.add(BossChoreo.bossFx(6.8, "stomp", style, { pos = dPushed, warn = 0.9, radius = 5 }))
	s.addAll(BossChoreo.dodge("medico", 7.3, dPushed, -Vector3.xAxis, 6.5, yawD, 0.45))
	s.addAll(BossChoreo.run("medico", 7.8, 8.4, dPushed - Vector3.new(6.5, 0, 0), dSpot, yawD))
	-- Otro zarpazo al guerrero levantado, que salta hacia atrás 4 studs.
	s.add(BossChoreo.bossAct(7.6, "Attack"))
	s.addAll(BossChoreo.hop("guerrero", 7.7, gDodged, gDodged + back * 4, yawG2))

	-- El mago reenciende las antorchas, una detrás de otra.
	s.add(BossChoreo.anim(8.45, "mago", "CastArea", 1.0))
	torch(8.7, "mago", true)
	torch(8.8, "medico", true)
	torch(8.9, "guerrero", true)

	-- Contraataque: Nova de hielo del mago y Lluvia de flechas del cazador.
	s.add(BossChoreo.anim(8.85, "mago", "CastArea", 1.0))
	s.add(BossChoreo.skill(9.0, "FrostNova", "mago", "boss", { radius = 12 }))
	s.add(BossChoreo.skill(9.15, "Frozen", "mago", "boss", { seconds = 1.5 }))
	s.add(BossChoreo.hit(9.2, "boss", 260, "Dealt"))
	s.bar(9.2, 0.55, 0.40)
	s.bow(9.5, 1.3)
	s.add(BossChoreo.anim(9.54, "cazador", "Arrow", 0.7))
	s.add(BossChoreo.skill(9.7, "ArrowRain", "cazador", Vector3.new(0, 0, -2), { radius = 10, seconds = 1.2 }))
	s.add(BossChoreo.hit(10.0, "boss", 150, "Dealt"))
	s.bar(10.0, 0.40, 0.33)
	s.add(BossChoreo.hit(10.15, "boss", 150, "Dealt"))
	s.bar(10.15, 0.33, 0.26)
	s.add(BossChoreo.hit(10.3, "boss", 210, "Dealt"))
	s.bar(10.3, 0.26, 0.16)

	-- Remate: Embestida del guerrero hasta el jefe y Rompehuesos crítico.
	local hitSpot = flat(0, -6)
	s.add(BossChoreo.anim(10.5, "guerrero", "Charge", 0.7))
	s.add(BossChoreo.skill(10.5, "Charge", "guerrero", nil, { seconds = 0.7 }))
	s.add(moveEvent(10.5, "guerrero", hitSpot, yawToBoss(hitSpot), 0.55, QUAD))
	s.add(BossChoreo.anim(11.25, "guerrero", "Smash", 0.8))
	s.add(BossChoreo.skill(11.45, "Smash", "guerrero", "boss"))
	s.add(BossChoreo.hit(11.45, "boss", 620, "Dealt", { crit = true }))
	s.bar(11.45, 0.16, 0.04)
	s.add(BossChoreo.shake(11.45, 0.35, 0.5))

	-- El guerrero se aparta del meteoro; el mago lo invoca; el jefe cae.
	s.addAll(BossChoreo.run("guerrero", 12.0, 12.7, hitSpot, gSpot, yawG))
	s.add(BossChoreo.anim(12.0, "mago", "CastArea", 1.0))
	s.add(BossChoreo.skill(12.2, "Meteor", "mago", "boss", { radius = 8 }))
	s.cheer(12.6)
	s.add(BossChoreo.hit(13.0, "boss", 700, "Dealt", { ko = true }))
	s.bar(13.0, 0.04, 0, 0.25)
	s.add(BossChoreo.bossAct(13.05, "Die"))

	-- Luz propia: cálida hasta el resoplido (se funde de 5,6 a 6,0 a la vez que las antorchas), fría y baja en la penumbra,
	-- cálida otra vez cuando el mago reenciende. La exposición de t = 0 (0,3) la pone la entrada de la batalla.
	local warm, cold = Color3.fromRGB(255, 236, 210), Color3.fromRGB(150, 170, 215)
	s.add(followLight(0, warm, 1.2, 60, 6.0))
	s.add(exposure(5.9, 0.08))
	s.add(followLight(5.9, cold, 0.35, 40, 2.9))
	s.add(exposure(8.75, 0.3))
	s.add(followLight(8.75, warm, 1.2, 60, nil))

	-- Planos (medidos en el Studio de la Isla, ninguno a menos de 12 studs de un maniquí).
	local plan = openingShots(3.6)
	table.insert(plan, shot(3.6, 5.4, { -23, 3.4, -7 }, { "mid", "guerrero", 3.5 }, 52))
	table.insert(plan, shot(5.4, 6.4, { 0, 8, -16 }, { "abs", 0, 6, 0 }, 56))
	table.insert(plan, shot(6.4, 8.6, { 20, 5, -6 }, { "mid", "C", 3 }, 54))
	table.insert(plan, shot(8.6, 9.4, { 4, 3, -14 }, { "crew", "mago", 3 }, 50))
	table.insert(plan, shot(9.4, 10.4, { 22, 8, -12 }, { "abs", 0, 6, 0 }, 46, { 20, 9, -12 }))
	table.insert(plan, shot(10.4, 12.0, { -23, 3.4, -7 }, { "mid", "guerrero", 3.5 }, 52))
	table.insert(plan, closingShot(ctx.total))
	return { events = s.events, plan = plan, ownLight = true }
end

-- Gorila de Ceniza: canaliza el aullido con grietas de lava y lanza tres oleadas de bombas desde el cráter (detrás del jefe),
-- con aviso. Cada una la esquiva alguien; al cazador, que reacciona tarde, le llega la onda y el médico lo cura; el guerrero
-- sube en zigzag entre las últimas y remata al jefe. Los charcos arden 4 s (Config.BossFx.LavaPoolSeconds): nadie pisa uno.
-- Efectos grandes de AbilityShow: Nova 7,0 a 8,8 · Curación 7,6 a 9,0 · Rompehuesos 10,4 a 11,8 · Meteoro 12,2 a 14,2.
function BossChoreo.ceniza(ctx: Context): Choreo
	local s = newWriter(ctx)
	local gSpot, cSpot, mSpot, dSpot = s.spots.guerrero, s.spots.cazador, s.spots.mago, s.spots.medico
	local yawG, yawC, yawM = yawToBoss(gSpot), yawToBoss(cSpot), yawToBoss(mSpot)
	local style = "GorilaDeCeniza"
	local crater = Vector3.new(0, 35, 14) -- de donde salen las bombas, en el marco del jefe
	local function bomb(t: number, pos: Vector3, warn: number)
		s.add(
			BossChoreo.bossFx(
				t,
				"lavaBomb",
				style,
				{ pos = pos, warn = warn, flight = 1.1, radius = 5, origin = crater }
			)
		)
	end

	s.enter()

	-- Canaliza el aullido: grietas de lava alrededor del jefe. Mientras, disparan el cazador y el mago.
	s.add(BossChoreo.bossAct(2.6, "Howl"))
	s.add(BossChoreo.bossFx(3.0, "stomp", style, { pos = flat(0, 0), warn = 0.6, radius = 10 }))
	s.add(BossChoreo.shake(3.6, 0.3, 0.8))
	s.bow(2.6, 1.8)
	s.shoot(2.95, "boss")
	s.add(BossChoreo.hit(3.1, "boss", 180, "Dealt"))
	s.bar(3.1, 1, 0.90)
	s.fireball(3.3, 3.6)
	s.add(BossChoreo.hit(3.95, "boss", 400, "Dealt", { crit = true }))
	s.bar(3.95, 0.90, 0.72)

	-- OLA 1 (aviso a 4,0, impacto a 5,4): bombas sobre el guerrero y el médico, donde están. El guerrero salta de lado y el
	-- médico corre en diagonal.
	s.add(BossChoreo.bossAct(3.8, "Stomp"))
	bomb(4.0, gSpot, 1.4)
	bomb(4.0, dSpot, 1.4)
	local gWave = flat(12, -15)
	local dWave = flat(11, -17)
	s.addAll(BossChoreo.leap("guerrero", 4.8, gSpot, gWave, 2.2, 0.5, yawG))
	s.addAll(BossChoreo.run("medico", 4.7, 5.2, dSpot, dWave, yawToBoss(dWave)))

	-- OLA 2 (aviso a 5,4, impacto a 6,8): bombas sobre el mago (retrocede de un salto) y a 4 studs del cazador, que reacciona
	-- tarde: la onda lo tira hacia +X, fuera del charco.
	s.add(BossChoreo.bossAct(5.2, "Stomp"))
	bomb(5.4, mSpot, 1.4)
	bomb(5.4, flat(-12, -19), 1.4)
	s.addAll(BossChoreo.hop("mago", 6.1, mSpot, flat(0, -26), yawM))
	s.add(BossChoreo.hit(6.8, "cazador", 70, "Taken"))
	s.addAll(BossChoreo.knockDown("cazador", 6.8, flat(-6.5, -19), Vector3.xAxis, yawC, 0.9))
	local cDown = flat(-5, -19)
	s.addAll(BossChoreo.getUp("cazador", 7.8, cDown, yawC, 0.2))

	-- El médico va a curarlo por el norte (rodea los charcos vivos: el camino recto cruza el del mago) y lo cura en área.
	local dNorth, dHeal = flat(8.5, -9), flat(-4, -10.5)
	s.addAll(BossChoreo.run("medico", 6.05, 6.6, dWave, dNorth))
	s.addAll(BossChoreo.run("medico", 6.6, 7.35, dNorth, dHeal, yawOf(cDown - dHeal)))
	s.add(BossChoreo.anim(7.4, "medico", "CastArea", 1.1))
	s.add(BossChoreo.skill(7.6, "AreaHeal", "cazador", nil))
	s.add(BossChoreo.hit(7.75, "cazador", 120, "Heal"))

	-- En el hueco: Nova de hielo sobre el jefe.
	s.add(BossChoreo.anim(6.8, "mago", "CastArea", 1.0))
	s.add(BossChoreo.skill(7.0, "FrostNova", "mago", "boss", { radius = 12 }))
	s.add(BossChoreo.skill(7.15, "Frozen", "mago", "boss", { seconds = 1.5 }))
	s.add(BossChoreo.hit(7.2, "boss", 240, "Dealt"))
	s.bar(7.2, 0.72, 0.56)

	-- OLA 3 (aviso a 7,2, impactos a 8,6 y 8,8): el guerrero sube en zigzag (tres tramos, el primero desde donde aterrizó) y
	-- dos bombas caen detrás de él; otra cae sobre el cazador ya levantado, que rueda.
	local points = { gWave, flat(13, -9), flat(4, -9), flat(2.5, -6.5) }
	local times = { 7.3, 7.9, 8.6, 9.0 }
	s.add(BossChoreo.bossAct(7.0, "Stomp"))
	for index = 1, 3 do
		s.addAll(BossChoreo.run("guerrero", times[index], times[index + 1], points[index], points[index + 1]))
	end
	local hitSpot = points[4]
	s.add(moveEvent(9.0, "guerrero", hitSpot, yawToBoss(hitSpot), 0.15, SINE))
	-- Cada bomba cae donde estaba el guerrero un rato antes: a más de radio + 2,5 de donde está en el impacto.
	local minLags = { 0.5, 1.4 }
	for index, warn in { 1.4, 1.6 } do
		local impact = 7.2 + warn
		local now = pathAt(points, times, impact)
		local center, far = points[1], -1
		for lag = minLags[index], 1.8, 0.1 do
			local candidate = pathAt(points, times, impact - lag)
			local away = (candidate - now).Magnitude
			if away > far then
				center, far = candidate, away
			end
			if away >= 7.5 then
				center = candidate
				break
			end
		end
		bomb(7.2, center, warn)
	end
	bomb(7.2, cDown, 1.4)
	s.addAll(BossChoreo.dodge("cazador", 8.0, cDown, -Vector3.zAxis, 7, yawC, 0.45))

	-- El guerrero llega junto al jefe: Embestida, Rompehuesos crítico y temblor.
	s.add(BossChoreo.skill(9.6, "Charge", "guerrero", nil, { seconds = 0.6 }))
	s.add(BossChoreo.anim(10.2, "guerrero", "Smash", 0.8))
	s.add(BossChoreo.skill(10.4, "Smash", "guerrero", "boss"))
	s.add(BossChoreo.hit(10.4, "boss", 560, "Dealt", { crit = true }))
	s.bar(10.4, 0.56, 0.30)
	s.add(BossChoreo.bossAct(10.45, "Hurt"))
	s.add(BossChoreo.shake(10.4, 0.35, 0.5))

	-- Cazador y mago rematan desde lejos.
	s.bow(10.3, 1.3)
	s.shoot(10.7, "boss")
	s.add(BossChoreo.hit(10.85, "boss", 160, "Dealt"))
	s.bar(10.85, 0.30, 0.24)
	s.add(BossChoreo.hit(11.0, "boss", 160, "Dealt"))
	s.bar(11.0, 0.24, 0.18)
	s.fireball(10.9, 11.2)
	s.add(BossChoreo.hit(11.55, "boss", 300, "Dealt"))
	s.bar(11.55, 0.18, 0.04)

	-- El guerrero se aparta del meteoro; el mago lo invoca; el jefe cae con un estallido de lava.
	s.addAll(BossChoreo.run("guerrero", 11.5, 12.2, hitSpot, gSpot, yawG))
	s.add(BossChoreo.anim(12.0, "mago", "CastArea", 1.0))
	s.add(BossChoreo.skill(12.2, "Meteor", "mago", "boss", { radius = 8 }))
	s.cheer(12.6)
	s.add(BossChoreo.hit(13.0, "boss", 700, "Dealt", { ko = true }))
	s.add(BossChoreo.bossFx(13.0, "stomp", style, { pos = flat(0, 0), warn = 0.1, radius = 12 }))
	s.bar(13.0, 0.04, 0, 0.25)
	s.add(BossChoreo.bossAct(13.05, "Die"))

	-- Planos (medidos en el Studio de la Isla, ninguno a menos de 12 studs de un maniquí).
	local plan = openingShots(3.8)
	table.insert(plan, shot(3.8, 5.6, { 0, 5, -14 }, { "abs", 0, 8, 4 }, 58))
	table.insert(plan, shot(5.6, 7.4, { -14, 5, -12 }, { "crew", "cazador", 3 }, 52))
	table.insert(plan, shot(7.4, 9.6, { 22, 8, -12 }, { "abs", 3, 3, -10 }, 48, { 20, 9, -12 }))
	table.insert(plan, shot(9.6, 10.6, { -20, 3.4, -6 }, { "mid", "guerrero", 3.5 }, 52))
	table.insert(plan, shot(10.6, 12.0, { 22, 9, 0 }, { "mid", "C", 3 }, 58))
	table.insert(plan, closingShot(ctx.total))
	return { events = s.events, plan = plan }
end

-- Elige el constructor por el campo `choreo` de la batalla ("orangutan" | "caudillo" | "albino" | "ceniza"). nil si no existe.
function BossChoreo.build(choreo: string, ctx: Context): Choreo?
	if choreo == "orangutan" then
		return BossChoreo.orangutan(ctx)
	elseif choreo == "caudillo" then
		return BossChoreo.caudillo(ctx)
	elseif choreo == "albino" then
		return BossChoreo.albino(ctx)
	elseif choreo == "ceniza" then
		return BossChoreo.ceniza(ctx)
	end
	return nil
end

return BossChoreo
