--!strict
-- Lo que comparten las escenas de las cinemáticas (Data/Cinematics y Data/Scenes/*): tipos, la hora de anochecer y
-- los ayudantes de cámara y de eventos. No requiere Data/Cinematics (evita ciclos).

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
	redMoonOff: boolean?, -- luna normal aunque el evento en vivo de la luna roja esté en marcha (SceneLight, evento redMoon)
	actors: { [string]: { [string]: any } },
	camera: { { t: number, pos: Vector3, look: Vector3, fov: number? } },
	events: { { t: number, kind: string, [string]: any } },
}

export type CameraKey = { pos: Vector3, look: Vector3, fov: number }
export type CameraShot = { t0: number, t1: number, a: CameraKey, b: CameraKey }
export type EventList = { { t: number, kind: string, [string]: any } }

-- Anochecer ya oscuro (cielo morado con estrellas, sin sol): la hora con la que se calibraron las luces de las escenas.
local DUSK_HOUR = 18.8

local Kit = {}

Kit.DUSK_HOUR = DUSK_HOUR

function Kit.cameraKey(pos: Vector3, look: Vector3, fov: number): CameraKey
	return { pos = pos, look = look, fov = fov }
end

-- Puntos de cámara de una lista de planos seguidos: cada plano va de "a" a "b" y entre uno y otro hay un corte. Se
-- repite el primer y el último punto de cada plano (con 0,01 s de diferencia) para que la spline Catmull-Rom del
-- plano no se curve hacia el siguiente (ver el corte del Rescate).
function Kit.cutShots(shots: { CameraShot }): { { t: number, pos: Vector3, look: Vector3, fov: number? } }
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

-- Escritores de los eventos de acción de una batalla: add(evento), anim(t, actor, acción, segundos?) y
-- skill(t, efecto, de, a, args?) (evento abilityFx; el campo es «fx», no «kind»).
function Kit.actionWriters(events: EventList)
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

-- Giro (grados, como el yaw de los actores: 0 mira a -Z) para ir de un punto a otro.
function Kit.yawBetween(from: Vector3, to: Vector3): number
	return math.deg(math.atan2(-(to.X - from.X), -(to.Z - from.Z)))
end

return Kit
