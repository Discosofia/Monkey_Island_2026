--!strict
-- Cuentas de la balística (Fase 24, 24e), iguales en el servidor y en el cliente: dónde está un proyectil a los t
-- segundos, cuánto cae, cuánto daño conserva y hacia dónde apuntar para compensar la caída. Los números están en
-- Data/Ballistics; cada proyectil se resume en "Motion" (gravedad y frenado ya calculados para su rapidez y alcance).
--
-- Recorrido sobre la línea de tiro: s(t) = v0 × (1 − e^(−k t)) / k  (k = frenado; sin él, v0 × t).
-- Caída: g × t² / 2, aparte de la línea (no la frena el aire). La gravedad de un perfil sale de pedir que, al
-- tiempo que tarda en llegar al alcance, haya caído "drop" studs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Profiles = require(ReplicatedStorage.Shared.Data.Ballistics)

export type Profile = Profiles.Profile

export type Motion = {
	speed: number,
	gravity: number, -- studs/s²
	drag: number, -- 1/s
}

local Ballistics = {}

-- El perfil de un proyectil: por "source" (habilidad o arma) y, si no, por su aspecto "style". nil si no tiene.
function Ballistics.profile(source: string?, style: string?): Profile?
	local byId = if source then Profiles[source] else nil
	if byId then
		return byId
	end
	return if style then Profiles[style] else nil
end

-- Studs recorridos sobre la línea de tiro a los "t" segundos de salir a "speed" con frenado "drag".
function Ballistics.distance(speed: number, drag: number, t: number): number
	if drag < 1e-6 then
		return speed * t
	end
	return speed * (1 - math.exp(-drag * t)) / drag
end

-- Segundos que tarda en recorrer "distance" sobre la línea. math.huge si el frenado lo para antes.
function Ballistics.timeTo(speed: number, drag: number, distance: number): number
	if drag < 1e-6 then
		return distance / speed
	end
	local fraction = drag * distance / speed
	if fraction >= 1 then
		return math.huge
	end
	return -math.log(1 - fraction) / drag
end

-- La gravedad y el frenado de un proyectil con "profile" que sale a "speed" y llega a "range". nil si vuela recto.
function Ballistics.motion(profile: Profile?, speed: number, range: number): Motion?
	if not profile or (profile.drop <= 0 and profile.drag <= 0) then
		return nil
	end
	-- Un frenado que pararía la bala antes de su alcance se recorta (el alcance es lo que manda).
	local drag = math.min(profile.drag, 0.9 * speed / range)
	local seconds = Ballistics.timeTo(speed, drag, range)
	local gravity = if profile.drop > 0 and seconds < math.huge then 2 * profile.drop / (seconds * seconds) else 0
	return { speed = speed, gravity = gravity, drag = drag }
end

-- Dónde está a los "t" segundos un proyectil que salió de "origin" hacia "direction" (unitario) con "motion".
function Ballistics.position(origin: Vector3, direction: Vector3, motion: Motion, t: number): Vector3
	local along = Ballistics.distance(motion.speed, motion.drag, t)
	return origin + direction * along - Vector3.yAxis * (motion.gravity * t * t / 2)
end

-- Cuánto de su daño conserva a "distance" studs del origen, con un alcance de "range": 1 sin falloff.
function Ballistics.damageScale(profile: Profile?, distance: number, range: number): number
	local falloff = if profile then profile.falloff else nil
	if not falloff or range <= 0 then
		return 1
	end
	local from = falloff.start * range
	if distance <= from then
		return 1
	end
	local fraction = math.clamp((distance - from) / math.max(range - from, 1e-3), 0, 1)
	return 1 - (1 - falloff.min) * fraction
end

-- La dirección que hay que dar desde "origin" para que el proyectil pase por "target" pese a la caída (aproximada:
-- sube la puntería lo que caerá en el tiempo que tarda en recorrer esa distancia). Sin caída, la recta.
function Ballistics.launchFor(origin: Vector3, target: Vector3, motion: Motion?): Vector3
	local offset = target - origin
	local distance = offset.Magnitude
	if distance < 1e-3 then
		return offset
	end
	if not motion or motion.gravity <= 0 then
		return offset.Unit
	end
	local seconds = Ballistics.timeTo(motion.speed, motion.drag, distance)
	if seconds == math.huge then
		return offset.Unit
	end
	local lift = motion.gravity * seconds * seconds / 2
	return (offset + Vector3.yAxis * lift).Unit
end

-- Rapidez media hasta "distance" studs (para apuntar adelantado a un blanco que se mueve).
function Ballistics.averageSpeed(speed: number, drag: number, distance: number): number
	local seconds = Ballistics.timeTo(speed, drag, distance)
	if seconds == math.huge or seconds < 1e-3 then
		return speed
	end
	return distance / seconds
end

-- La rapidez (studs/s) con que un proyectil de "profile" empuja a un mono de "targetMass", o 0 si no llega al mínimo.
function Ballistics.pushSpeed(profile: Profile?, targetMass: number): number
	if not profile then
		return 0
	end
	local settings = Config.Ballistics
	local speed = profile.mass * settings.PushScale / math.max(targetMass, 1)
	return if speed < settings.PushMinSpeed then 0 else math.min(speed, settings.PushMaxSpeed)
end

return Ballistics
