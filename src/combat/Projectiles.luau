--!strict
-- Proyectiles reales (Fase 10, C9): los disparos de las armas a distancia y las habilidades que viajan
-- (Disparo múltiple, Flecha perforante, Bola de fuego, Dardo curativo). El servidor los mueve en línea
-- recta en un solo bucle de Heartbeat y en cada paso mira de la posición anterior a la nueva
-- (Combat/Hitbox): el mundo con un rayo (solo lo que choca y el terreno) y los combatientes con una
-- esfera, así que ni los rápidos atraviesan sin tocar. Da a quien encuentra por el camino: si alguien se
-- aparta, falla. Quien llama decide qué pasa al tocar a cada uno ("onHit": si no le vale, como un aliado,
-- el proyectil lo atraviesa) y al acabar ("onEnd").
-- Lo que se ve lo dibuja cada cliente (AbilityFxController, efectos "Projectile" y "ProjectileEnd") con
-- la hora de salida del servidor: todos lo ven en el mismo sitio, aunque cada uno con su ping. El
-- disparo directo de un arma a distancia (Fase 19, W4, "ownerSeq") lo dibuja ya el cliente del tirador.
-- Telemetría: cada uno que puede dar a alguien cuenta "ShotsHit" o "ShotsMissed" (Combat/CombatRules).
-- Coberturas (C11, Combat/Destructibles): con "breaks", el que se para en una la alcanza.
-- En arco (Fase 13, el cañón de suero del Laboratorio): con "gravity" cae mientras vuela; cada paso es un
-- tramo recto entre dos puntos de la parábola, así que se mira igual. "speed" es la de salida.
-- Cabeza y lag (Fase 15, V7): con "rewind", los jugadores se prueban donde estaban hace esos segundos,
-- pieza a pieza (onHit recibe la zona: "Head", "Torso", "Limb" o "Weak"); con "lead", el proyectil sale ya
-- adelantado. Los monos, jefes y muñecos dan también su zona, sin rebobinar.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ballistics = require(ReplicatedStorage.Shared.Ballistics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AbilityFx = require(script.Parent.AbilityFx)
local CombatRules = require(script.Parent.CombatRules)
local Destructibles = require(script.Parent.Destructibles)
local Hitbox = require(script.Parent.Hitbox)

-- Sale desde esto antes del origen: la esfera no ve lo que ya toca al salir, y así da al mono pegado.
local START_BACK = 1.5
-- Un rebote que dejaría el proyectil por debajo de esta rapidez (studs/s) lo da por acabado.
local BOUNCE_MIN_SPEED = 4
-- Separación de la pared tras un rebote, para que el rayo siguiente no empiece dentro de ella.
local BOUNCE_OFFSET = 0.05

export type Shot = {
	owner: Player,
	look: string, -- cómo se ve (AbilityFxController: "Stone", "Arrow", "Spell", "Dart", "MultiShot"…)
	origin: Vector3,
	direction: Vector3, -- unitario
	speed: number, -- studs/s
	range: number, -- studs
	radius: number, -- studs: el grosor que alcanza
	pierce: boolean?, -- atraviesa a todos los que toca (cada uno una vez); solo lo para el mundo…
	maxHits: number?, -- …o, con esto, al dar a tantos (el remate del arco, C9b)
	-- Al tocar un combatiente: true si le vale (le da y, sin "pierce", se para); false para atravesarlo.
	-- "zone": la zona del cuerpo que ha tocado (Hitbox.zoneOf; la de un jugador, con "rewind", pieza a pieza).
	-- "contact": el punto de la superficie que toca (el centro de la esfera del proyectil queda a su radio de él).
	onHit: (model: Model, position: Vector3, zone: string?, contact: Vector3?) -> boolean,
	-- Al acabar: dónde, a quién dio el último (o nil) y si ha dado a alguien.
	onEnd: ((position: Vector3, model: Model?, hitAny: boolean) -> ())?,
	-- Datos que el cliente usa al llegar (el radio de la explosión de la Bola de fuego).
	extra: { any }?,
	-- false: no cuenta en la telemetría de aciertos (lo que no apunta a nadie, como un dardo al aire).
	counts: boolean?,
	-- Si se para en una cobertura, la alcanza con esto (C11; las habilidades y el disparo de remate), una
	-- vez por cobertura y tabla "breakOnce" (la de todas las flechas de un mismo abanico).
	breaks: Destructibles.Kind?,
	breakOnce: Destructibles.Once?,
	-- Studs/s² hacia abajo (en arco); "range" es entonces lo que recorre por la curva.
	gravity: number?,
	-- Frenado del aire (1/s; Shared/Ballistics): la rapidez baja como e^(-drag × t). Si el disparo no trae ni
	-- "gravity" ni "drag" ni rebotes, Projectiles.fire los toma de Data/Ballistics según "source" y "look".
	drag: number?,
	-- Segundos de lag del tirador (Fase 15, V7): los jugadores se prueban donde estaban hace esto, con
	-- piezas (Hitbox.sweepBodies); el resto, como siempre.
	rewind: number?,
	-- Segundos que el proyectil avanza de golpe al salir, para compensar el retraso del tirador.
	lead: number?,
	-- Número del disparo del tirador (UseWeapon, Fase 19 W4): su cliente ya dibuja la bala, así que
	-- "Projectile" va solo a los demás y a él le llega ProjectileAck con el id y la dirección real.
	ownerSeq: number?,
	-- Rebotes (Fase 23d): veces que, al chocar con el mundo, se refleja en la normal de la pieza en vez de
	-- acabar (el campo de tiro; ningún arma lo usa todavía). "bounciness" (0 a 1, por defecto 1) es la
	-- parte de la rapidez que conserva en cada rebote; si baja de BOUNCE_MIN_SPEED, acaba allí. Cada rebote
	-- es un tramo nuevo para el cliente (ProjectileEnd y un Projectile con otro id) y "range" cuenta todo
	-- lo recorrido.
	bounces: number?,
	bounciness: number?,
	-- Solo para depurar (campo de tiro, Fase 23e): la dirección que mandó el cliente antes de la ayuda de
	-- puntería y de la dispersión.
	aimDirection: Vector3?,
	-- Qué lo dispara (el id del arma de Data/Weapons|LabWeapons o de la habilidad): solo para medir en el campo de
	-- tiro (RangeCalibrationService); nada del combate lo mira.
	source: string?,
}

-- Lo que se cuenta de un proyectil al acabar (oyentes de onImpact): del disparo tal como salió la primera vez
-- (origen, dirección, puntería del cliente), no del último tramo tras un rebote.
export type ImpactInfo = {
	source: string?,
	look: string,
	elapsed: number, -- segundos de vuelo hasta el impacto
	travelled: number, -- studs recorridos
	hitAny: boolean,
	origin: Vector3,
	direction: Vector3,
	aimDirection: Vector3?,
}

type ImpactListener = (
	shooter: Player,
	position: Vector3,
	instance: Instance?,
	model: Model?,
	info: ImpactInfo
) -> ()

type Flight = {
	shot: Shot,
	id: number,
	position: Vector3,
	travelled: number,
	elapsed: number,
	age: number, -- segundos de vuelo desde que salió (el "elapsed" de arriba se reinicia en cada rebote)
	first: Shot, -- el disparo tal como salió
	skip: { [Model]: boolean },
	hitAny: boolean,
	hits: number,
	bouncesLeft: number,
}

local Projectiles = {}

local flights: { Flight } = {}
local nextId = 0
local started = false
-- Oyentes aditivos (el campo de tiro del Lobby): sin ninguno, no hacen nada.
local impactListeners: { ImpactListener } = {}
local shotListeners: { (shooter: Player, ownerSeq: number?, shot: Shot) -> () } = {}

-- Llama a "listener" cuando un proyectil acaba: contra el mundo (con la pieza que toca), contra un
-- combatiente (con su modelo) o al final de su alcance (sin ninguno de los dos). El último parámetro, "info",
-- dice cómo fue el vuelo (ImpactInfo); un oyente puede ignorarlo.
function Projectiles.onImpact(listener: ImpactListener)
	table.insert(impactListeners, listener)
end

-- Llama a "listener" cada vez que sale un proyectil. "ownerSeq" solo lo traen los disparos directos de un
-- arma a distancia (las habilidades no). "shot" es el disparo tal como sale.
function Projectiles.onShot(listener: (shooter: Player, ownerSeq: number?, shot: Shot) -> ())
	table.insert(shotListeners, listener)
end

-- "instance": la pieza del mundo contra la que acaba, si es el caso.
local function finish(flight: Flight, position: Vector3, model: Model?, instance: Instance?)
	local shot = flight.shot
	AbilityFx.all("ProjectileEnd", flight.id, position, model ~= nil)
	if shot.counts ~= false and shot.owner.Parent then
		CombatRules.get().telemetry.mechanic(shot.owner, if flight.hitAny then "ShotsHit" else "ShotsMissed")
	end
	if shot.owner.Parent and #impactListeners > 0 then
		local first = flight.first
		local info: ImpactInfo = {
			source = first.source,
			look = first.look,
			elapsed = flight.age,
			travelled = flight.travelled,
			hitAny = flight.hitAny,
			origin = first.origin,
			direction = first.direction,
			aimDirection = first.aimDirection,
		}
		for _, listener in impactListeners do
			task.spawn(listener, shot.owner, position, instance, model, info)
		end
	end
	if shot.onEnd then
		task.spawn(shot.onEnd, position, model, flight.hitAny)
	end
end

-- Barre un tramo de "flight" entre los combatientes: el primero que toca, lo que avanza hasta él, el
-- contacto y la zona que toca. Con "rewind", los jugadores se prueban aparte (Hitbox.sweepBodies) y el
-- barrido normal los ignora; se toma el más cercano de los dos.
local function sweepFlight(flight: Flight, from: Vector3, displacement: Vector3): (Model?, number, Vector3?, string?)
	local shot = flight.shot
	local rewind = shot.rewind
	if not rewind then
		return Hitbox.sweepCombatants(from, shot.radius, displacement, flight.skip)
	end
	local model, along, contact, zone = Hitbox.sweepCombatants(from, shot.radius, displacement, flight.skip, true)
	local playerModel, playerAlong, playerContact, playerZone =
		Hitbox.sweepBodies(from, displacement, rewind, flight.skip)
	if playerModel and (not model or playerAlong <= along) then
		return playerModel, playerAlong, playerContact, playerZone
	end
	return model, along, contact, zone
end

-- Rebota "flight" en la pared "wall": refleja su velocidad actual en la normal y sigue desde allí. Devuelve
-- false si ya no le quedan rebotes o se queda sin rapidez (entonces el llamador lo acaba).
local function bounce(flight: Flight, wall: RaycastResult): boolean
	local shot = flight.shot
	local left = flight.bouncesLeft
	if left <= 0 then
		return false
	end
	local velocity = shot.direction * shot.speed
	if shot.gravity then
		velocity -= Vector3.yAxis * (shot.gravity * flight.elapsed)
	end
	local normal = wall.Normal
	local reflected = (velocity - 2 * velocity:Dot(normal) * normal) * (shot.bounciness or 1)
	local speed = reflected.Magnitude
	if speed < BOUNCE_MIN_SPEED then
		return false
	end
	flight.bouncesLeft = left - 1
	AbilityFx.all("ProjectileEnd", flight.id, wall.Position, false)
	local nextShot = table.clone(shot)
	nextShot.origin = wall.Position + normal * BOUNCE_OFFSET
	nextShot.direction = reflected / speed
	nextShot.speed = speed
	nextShot.ownerSeq = nil
	nextId += 1
	flight.id = nextId
	flight.shot = nextShot
	flight.elapsed = 0
	flight.position = nextShot.origin
	AbilityFx.all(
		"Projectile",
		flight.id,
		nextShot.look,
		shot.owner.Character,
		nextShot.origin,
		nextShot.direction,
		speed,
		nextShot.range - flight.travelled,
		Workspace:GetServerTimeNow(),
		nextShot.pierce == true,
		nextShot.extra,
		nextShot.gravity,
		nextShot.drag
	)
	return true
end

-- Lo que se mueve "flight" en "deltaTime" (sin pasar de su alcance).
local function displacementOf(flight: Flight, deltaTime: number): Vector3
	local shot = flight.shot
	local left = shot.range - flight.travelled
	if not shot.gravity and not shot.drag then
		return shot.direction * math.min(shot.speed * deltaTime, left)
	end
	flight.elapsed += deltaTime
	local t = flight.elapsed
	local target = Ballistics.position(
		shot.origin,
		shot.direction,
		{ speed = shot.speed, gravity = shot.gravity or 0, drag = shot.drag or 0 },
		t
	)
	local displacement = target - flight.position
	return if displacement.Magnitude > left then displacement.Unit * left else displacement
end

-- Avanza "flight" lo que toca en "deltaTime". Devuelve true si ha acabado.
local function advance(flight: Flight, deltaTime: number): boolean
	local shot = flight.shot
	local displacement = displacementOf(flight, deltaTime)
	local remaining = displacement.Magnitude
	local startAge = flight.age
	flight.age += deltaTime
	if remaining < 1e-4 then
		if flight.travelled >= shot.range - 1e-3 then
			finish(flight, flight.position, nil)
			return true
		end
		return false
	end
	local direction = displacement / remaining
	local wall = Hitbox.ray(flight.position, displacement)
	local open = if wall then (wall.Position - flight.position).Magnitude else remaining
	local from = flight.position
	local swept = 0
	while swept < open do
		local model, along, contact, zone = sweepFlight(flight, from, direction * (open - swept))
		if not model then
			break
		end
		swept += along
		from = flight.position + direction * swept
		flight.skip[model] = true
		if shot.onHit(model, from, zone, contact) then
			flight.hitAny = true
			flight.hits += 1
			if not shot.pierce or (shot.maxHits and flight.hits >= shot.maxHits) then
				flight.position = from
				flight.travelled += swept
				flight.age = startAge + deltaTime * swept / remaining
				finish(flight, from, model)
				return true
			end
		end
	end
	flight.position += direction * open
	flight.travelled += open
	if wall then
		flight.age = startAge + deltaTime * open / remaining
		if shot.breaks then
			Destructibles.hitPart(wall.Instance, shot.breaks, shot.owner, wall.Position, shot.breakOnce)
		end
		if bounce(flight, wall) then
			return false
		end
		finish(flight, wall.Position, nil, wall.Instance)
		return true
	end
	if flight.travelled >= shot.range - 1e-3 then
		finish(flight, flight.position, nil)
		return true
	end
	return false
end

local function step(deltaTime: number)
	local index = 1
	while index <= #flights do
		local flight = flights[index]
		local ok, done = pcall(advance, flight, deltaTime)
		if not ok then
			warn("Projectiles:", done)
		end
		if not ok or done then
			flights[index] = flights[#flights]
			flights[#flights] = nil
		else
			index += 1
		end
	end
end

-- El aspecto base de un "look" ("StoneFinisher" es "Stone").
local function baseLook(look: string): string
	return (string.gsub(look, "Finisher$", ""))
end

-- La balística (gravedad y frenado) que le toca a un proyectil de "source" y "look" que sale a "speed" y llega a
-- "range": nil si vuela recto. Es la que usa Projectiles.fire, y la que CombatService necesita antes para apuntar.
function Projectiles.motionFor(source: string?, look: string, speed: number, range: number): Ballistics.Motion?
	return Ballistics.motion(Ballistics.profile(source, baseLook(look)), speed, range)
end

-- Lanza un proyectil. Devuelve su id (el de los efectos).
function Projectiles.fire(shot: Shot): number
	if shot.gravity == nil and shot.drag == nil and (shot.bounces or 0) == 0 then
		local motion = Projectiles.motionFor(shot.source, shot.look, shot.speed, shot.range)
		if motion then
			shot.gravity = if motion.gravity > 0 then motion.gravity else nil
			shot.drag = if motion.drag > 0 then motion.drag else nil
		end
	end
	nextId += 1
	local character = shot.owner.Character
	local flight: Flight = {
		shot = shot,
		id = nextId,
		position = shot.origin,
		travelled = 0,
		elapsed = 0,
		age = 0,
		first = shot,
		skip = if character then { [character] = true } else {},
		hitAny = false,
		hits = 0,
		bouncesLeft = shot.bounces or 0,
	}
	local lead = shot.lead or 0
	-- Con adelanto, lo dibujado sale ya "lead" segundos por delante, como el servidor.
	-- Con "ownerSeq", el tirador ya la dibuja: solo se le manda el ack con el id y la dirección real.
	local ownerSeq = shot.ownerSeq
	local owner = shot.owner
	for _, listener in shotListeners do
		task.spawn(listener, owner, ownerSeq, shot)
	end
	if ownerSeq then
		Remotes.ProjectileAck:FireClient(owner, ownerSeq, flight.id, shot.direction)
	end
	local send = if ownerSeq
		then function(...: any)
			AbilityFx.others(owner, ...)
		end
		else AbilityFx.all
	send(
		"Projectile",
		flight.id,
		shot.look,
		character,
		shot.origin,
		shot.direction,
		shot.speed,
		shot.range,
		Workspace:GetServerTimeNow() - lead,
		shot.pierce == true,
		shot.extra,
		shot.gravity,
		shot.drag
	)
	-- Lo que ya toca al salir (un mono pegado al tirador): una esfera desde un poco antes del origen.
	local behind = shot.origin - shot.direction * START_BACK
	local model, _, contact, zone = sweepFlight(flight, behind, shot.direction * START_BACK)
	if model then
		flight.skip[model] = true
		if shot.onHit(model, contact or shot.origin, zone, contact) then
			flight.hitAny = true
			flight.hits += 1
			if not shot.pierce or (shot.maxHits and flight.hits >= shot.maxHits) then
				finish(flight, contact or shot.origin, model)
				return flight.id
			end
		end
	end
	if lead > 0 and advance(flight, lead) then
		return flight.id
	end
	table.insert(flights, flight)
	return flight.id
end

function Projectiles.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(step)
	-- Quien se va deja de disparar: lo suyo en vuelo se acaba sin hacer nada más.
	Players.PlayerRemoving:Connect(function(player)
		for index = #flights, 1, -1 do
			if flights[index].shot.owner == player then
				AbilityFx.all("ProjectileEnd", flights[index].id, flights[index].position)
				table.remove(flights, index)
			end
		end
	end)
end

return Projectiles
