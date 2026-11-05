--!strict
-- Cuentas de los caminos de cámara (Fase 25): spline Catmull-Rom de la posición y de la mirada, suavizado,
-- campo de visión y órbita. Son funciones puras, sin cámara ni interfaz ni red: las usan el Sequencer
-- (escenas del juego) y Tools/TrailerCamara (tomas del tráiler).

local CameraPath = {}

export type Point = {
	pos: Vector3,
	look: Vector3,
	fov: number?,
	t: number?, -- segundos en la escena (solo en las escenas del Sequencer, ver sampleTimed)
}

CameraPath.DEFAULT_FOV = 70
local ORBIT_STEP = 15 -- grados entre punto y punto de la órbita

-- Catmull-Rom uniforme entre p1 y p2 (p0 y p3 son los vecinos).
local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2 = t * t
	local t3 = t2 * t
	return (p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
end

-- Campo de visión del punto i: el suyo, o el del anterior (el primero, 70 por defecto).
local function fovOf(points: { Point }, i: number): number
	for j = i, 1, -1 do
		local fov = points[j].fov
		if fov then
			return fov
		end
	end
	return CameraPath.DEFAULT_FOV
end

-- Posición, mirada y fov del tramo i (entre el punto i y el i + 1) en su fracción f (0 a 1).
local function segment(points: { Point }, i: number, f: number): (Vector3, Vector3, number)
	local n = #points
	local a, b = points[math.max(i - 1, 1)], points[math.min(i + 2, n)]
	local p1, p2 = points[i], points[i + 1]
	local pos = catmull(a.pos, p1.pos, p2.pos, b.pos, f)
	local look = catmull(a.look, p1.look, p2.look, b.look, f)
	local fov1, fov2 = fovOf(points, i), fovOf(points, i + 1)
	return pos, look, fov1 + (fov2 - fov1) * f
end

function CameraPath.smoothstep(u: number): number
	return u * u * (3 - 2 * u)
end

-- Posición, mirada y fov del camino en alpha (0 a 1), repartido a partes iguales entre los puntos. Con
-- "smooth", con aceleración suave al empezar y al acabar.
function CameraPath.sampleRaw(points: { Point }, alpha: number, smooth: boolean?): (Vector3, Vector3, number)
	local n = #points
	if n == 1 then
		return points[1].pos, points[1].look, fovOf(points, 1)
	end
	local u = math.clamp(alpha, 0, 1)
	if smooth then
		u = CameraPath.smoothstep(u)
	end
	local tramos = n - 1
	local s = u * tramos
	local i = math.min(math.floor(s) + 1, tramos)
	return segment(points, i, s - (i - 1))
end

-- Igual que sampleRaw, pero ya como CFrame de cámara y fov.
function CameraPath.sample(points: { Point }, alpha: number, smooth: boolean?): (CFrame, number)
	local pos, look, fov = CameraPath.sampleRaw(points, alpha, smooth)
	return CFrame.lookAt(pos, look), fov
end

-- Cámara en el segundo "t" de una lista con tiempos (campo t de cada punto, en orden creciente): los
-- tramos duran lo que digan sus puntos. Antes del primero y después del último, se queda quieta.
function CameraPath.sampleTimed(points: { Point }, t: number): (Vector3, Vector3, number)
	local n = #points
	local first, last = points[1], points[n]
	if n == 1 or t <= (first.t or 0) then
		return first.pos, first.look, fovOf(points, 1)
	end
	if t >= (last.t or 0) then
		return last.pos, last.look, fovOf(points, n)
	end
	local i = 1
	while i < n - 1 and t >= (points[i + 1].t or 0) do
		i += 1
	end
	local t1, t2 = points[i].t or 0, points[i + 1].t or 0
	local f = if t2 > t1 then (t - t1) / (t2 - t1) else 1
	return segment(points, i, f)
end

-- Puntos de una vuelta alrededor de "center": la cámara a "radius" studs y "height" por encima, girando
-- "degrees" (360 es una vuelta entera; negativo, al revés), siempre mirando al centro. "seconds" no cambia
-- los puntos (la duración la pone quien los recorre); se acepta para que la firma diga el uso.
function CameraPath.orbit(center: Vector3, radius: number, height: number, degrees: number, seconds: number): { Point }
	local _ = seconds
	local steps = math.max(3, math.ceil(math.abs(degrees) / ORBIT_STEP))
	local points: { Point } = {}
	for i = 0, steps do
		local a = math.rad(degrees * i / steps)
		table.insert(points, {
			pos = center + Vector3.new(math.sin(a) * radius, height, math.cos(a) * radius),
			look = center,
		})
	end
	return points
end

return CameraPath
