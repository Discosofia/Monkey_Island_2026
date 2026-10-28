--!strict
-- Proyectiles reales (Fase 10, C9): los disparos de las armas a distancia y las habilidades que viajan
-- (Disparo múltiple, Flecha perforante, Bola de fuego, Dardo curativo). El servidor los mueve en línea
-- recta en un solo bucle de Heartbeat y en cada paso mira de la posición anterior a la nueva
-- (Combat/Hitbox): el mundo con un rayo (solo lo que choca y el terreno) y los combatientes con una
-- esfera, así que ni los rápidos atraviesan sin tocar. Da a quien encuentra por el camino: si alguien se
-- aparta, falla. Quien llama decide qué pasa al tocar a cada uno ("onHit": si no le vale, como un aliado,
-- el proyectil lo atraviesa) y al acabar ("onEnd").
-- Lo que se ve lo dibuja cada cliente (AbilityFxController, efectos "Projectile" y "ProjectileEnd") con
-- la hora de salida del servidor: todos lo ven en el mismo sitio, aunque cada uno con su ping.
-- Telemetría: cada uno que puede dar a alguien cuenta "ShotsHit" o "ShotsMissed" (Combat/CombatRules).
-- Coberturas (C11, Combat/Destructibles): con "breaks", el que se para en una la alcanza.
-- En arco (Fase 13, el cañón de suero del Laboratorio): con "gravity" cae mientras vuela; cada paso es un
-- tramo recto entre dos puntos de la parábola, así que se mira igual. "speed" es la de salida.
-- Cabeza y lag (Fase 15, V7): con "rewind", los jugadores se prueban donde estaban hace esos segundos,
-- con la cabeza aparte (onHit recibe "isHead"); con "lead", el proyectil sale ya adelantado.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AbilityFx = require(script.Parent.AbilityFx)
local CombatRules = require(script.Parent.CombatRules)
local Destructibles = require(script.Parent.Destructibles)
local Hitbox = require(script.Parent.Hitbox)

-- Sale desde esto antes del origen: la esfera no ve lo que ya toca al salir, y así da al mono pegado.
local START_BACK = 1.5

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
	-- "isHead": dio a la cabeza de un jugador (solo con "rewind").
	onHit: (model: Model, position: Vector3, isHead: boolean?) -> boolean,
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
	-- Segundos de lag del tirador (Fase 15, V7): los jugadores se prueban donde estaban hace esto, con
	-- cabeza y cuerpo (Hitbox.sweepPlayers); el resto, como siempre.
	rewind: number?,
	-- Segundos que el proyectil avanza de golpe al salir, para compensar el retraso del tirador.
	lead: number?,
}

type Flight = {
	shot: Shot,
	id: number,
	position: Vector3,
	travelled: number,
	elapsed: number,
	skip: { [Model]: boolean },
	hitAny: boolean,
	hits: number,
}

local Projectiles = {}

local flights: { Flight } = {}
local nextId = 0
local started = false

local function finish(flight: Flight, position: Vector3, model: Model?)
	local shot = flight.shot
	AbilityFx.all("ProjectileEnd", flight.id, position)
	if shot.counts ~= false and shot.owner.Parent then
		CombatRules.get().telemetry.mechanic(shot.owner, if flight.hitAny then "ShotsHit" else "ShotsMissed")
	end
	if shot.onEnd then
		task.spawn(shot.onEnd, position, model, flight.hitAny)
	end
end

-- Barre un tramo de "flight" entre los combatientes: el primero que toca, lo que avanza hasta él, el
-- contacto y si es la cabeza de un jugador. Con "rewind", los jugadores se prueban aparte
-- (Hitbox.sweepPlayers) y el barrido normal los ignora; se toma el más cercano de los dos.
local function sweepFlight(flight: Flight, from: Vector3, displacement: Vector3): (Model?, number, Vector3?, boolean)
	local shot = flight.shot
	local rewind = shot.rewind
	if not rewind then
		local model, along, contact = Hitbox.sweepCombatants(from, shot.radius, displacement, flight.skip)
		return model, along, contact, false
	end
	local skip = table.clone(flight.skip)
	for _, player in Players:GetPlayers() do
		if player.Character then
			skip[player.Character] = true
		end
	end
	local model, along, contact = Hitbox.sweepCombatants(from, shot.radius, displacement, skip)
	local playerModel, playerAlong, playerContact, isHead = Hitbox.sweepPlayers(from, displacement, rewind, flight.skip)
	if playerModel and (not model or playerAlong <= along) then
		return playerModel, playerAlong, playerContact, isHead
	end
	return model, along, contact, false
end

-- Lo que se mueve "flight" en "deltaTime" (sin pasar de su alcance).
local function displacementOf(flight: Flight, deltaTime: number): Vector3
	local shot = flight.shot
	local left = shot.range - flight.travelled
	if not shot.gravity then
		return shot.direction * math.min(shot.speed * deltaTime, left)
	end
	flight.elapsed += deltaTime
	local t = flight.elapsed
	local target = shot.origin + shot.direction * shot.speed * t - Vector3.yAxis * (shot.gravity * t * t / 2)
	local displacement = target - flight.position
	return if displacement.Magnitude > left then displacement.Unit * left else displacement
end

-- Avanza "flight" lo que toca en "deltaTime". Devuelve true si ha acabado.
local function advance(flight: Flight, deltaTime: number): boolean
	local shot = flight.shot
	local displacement = displacementOf(flight, deltaTime)
	local remaining = displacement.Magnitude
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
		local model, along, _, isHead = sweepFlight(flight, from, direction * (open - swept))
		if not model then
			break
		end
		swept += along
		from = flight.position + direction * swept
		flight.skip[model] = true
		if shot.onHit(model, from, isHead) then
			flight.hitAny = true
			flight.hits += 1
			if not shot.pierce or (shot.maxHits and flight.hits >= shot.maxHits) then
				flight.position = from
				finish(flight, from, model)
				return true
			end
		end
	end
	flight.position += direction * open
	flight.travelled += open
	if wall then
		if shot.breaks then
			Destructibles.hitPart(wall.Instance, shot.breaks, shot.owner, wall.Position, shot.breakOnce)
		end
		finish(flight, wall.Position, nil)
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

-- Lanza un proyectil. Devuelve su id (el de los efectos).
function Projectiles.fire(shot: Shot): number
	nextId += 1
	local character = shot.owner.Character
	local flight: Flight = {
		shot = shot,
		id = nextId,
		position = shot.origin,
		travelled = 0,
		elapsed = 0,
		skip = if character then { [character] = true } else {},
		hitAny = false,
		hits = 0,
	}
	local lead = shot.lead or 0
	-- Con adelanto, lo dibujado sale ya "lead" segundos por delante, como el servidor.
	AbilityFx.all(
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
		shot.gravity
	)
	-- Lo que ya toca al salir (un mono pegado al tirador): una esfera desde un poco antes del origen.
	local behind = shot.origin - shot.direction * START_BACK
	local model, _, contact, isHead = sweepFlight(flight, behind, shot.direction * START_BACK)
	if model then
		flight.skip[model] = true
		if shot.onHit(model, contact or shot.origin, isHead) then
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
