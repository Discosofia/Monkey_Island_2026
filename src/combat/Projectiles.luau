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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AbilityFx = require(script.Parent.AbilityFx)
local CombatRules = require(script.Parent.CombatRules)
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
	pierce: boolean?, -- atraviesa a todos los que toca (cada uno una vez); solo lo para el mundo
	-- Al tocar un combatiente: true si le vale (le da y, sin "pierce", se para); false para atravesarlo.
	onHit: (model: Model, position: Vector3) -> boolean,
	-- Al acabar: dónde, a quién dio el último (o nil) y si ha dado a alguien.
	onEnd: ((position: Vector3, model: Model?, hitAny: boolean) -> ())?,
	-- Datos que el cliente usa al llegar (el radio de la explosión de la Bola de fuego).
	extra: { any }?,
	-- false: no cuenta en la telemetría de aciertos (lo que no apunta a nadie, como un dardo al aire).
	counts: boolean?,
}

type Flight = {
	shot: Shot,
	id: number,
	position: Vector3,
	travelled: number,
	skip: { [Model]: boolean },
	hitAny: boolean,
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

-- Avanza "flight" "distance" studs. Devuelve true si ha acabado.
local function advance(flight: Flight, distance: number): boolean
	local shot = flight.shot
	local remaining = math.min(distance, shot.range - flight.travelled)
	local displacement = shot.direction * remaining
	local wall = Hitbox.ray(flight.position, displacement)
	local open = if wall then (wall.Position - flight.position).Magnitude else remaining
	local from = flight.position
	local swept = 0
	while swept < open do
		local model, along = Hitbox.sweepCombatants(from, shot.radius, shot.direction * (open - swept), flight.skip)
		if not model then
			break
		end
		swept += along
		from = flight.position + shot.direction * swept
		flight.skip[model] = true
		if shot.onHit(model, from) then
			flight.hitAny = true
			if not shot.pierce then
				flight.position = from
				finish(flight, from, model)
				return true
			end
		end
	end
	flight.position += shot.direction * open
	flight.travelled += open
	if wall then
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
		local ok, done = pcall(advance, flight, flight.shot.speed * deltaTime)
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
		skip = if character then { [character] = true } else {},
		hitAny = false,
	}
	AbilityFx.all(
		"Projectile",
		flight.id,
		shot.look,
		character,
		shot.origin,
		shot.direction,
		shot.speed,
		shot.range,
		Workspace:GetServerTimeNow(),
		shot.pierce == true,
		shot.extra
	)
	-- Lo que ya toca al salir (un mono pegado al tirador): una esfera desde un poco antes del origen.
	local behind = shot.origin - shot.direction * START_BACK
	local model, _, contact = Hitbox.sweepCombatants(behind, shot.radius, shot.direction * START_BACK, flight.skip)
	if model then
		flight.skip[model] = true
		if shot.onHit(model, contact or shot.origin) then
			flight.hitAny = true
			if not shot.pierce then
				finish(flight, contact or shot.origin, model)
				return flight.id
			end
		end
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
