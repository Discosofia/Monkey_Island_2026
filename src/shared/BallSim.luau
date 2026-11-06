--!strict
-- Simulación de la pelota del Juego de pelota de Dunas (Fase 26c). Matemática pura y determinista: sin
-- Instances, sin Remotes y sin relojes. El servidor (BallService) y cada cliente (BallController) ejecutan
-- el mismo código con el mismo paso fijo, así que el cliente puede predecir lo que el servidor confirma.
--
-- Coordenadas LOCALES de la cancha (ver Shared/CourtGeometry): origen en el centro del pasillo a nivel del
-- suelo, X el eje largo (Jaguar en X < 0), Z el ancho, Y arriba. La pelota es una esfera de radio
-- CourtGeometry.BALL_RADIUS; su centro nunca queda más cerca que eso de una superficie.
--
-- Colisión analítica (sin raycasts). La cancha es simétrica en ±X y ±Z, así que cada subpaso pliega la
-- posición y la velocidad al cuadrante (+X, +Z), resuelve contra los sólidos de ese cuadrante y las
-- desdobla. Los sólidos, compilados una vez por Layout:
--   - Prismas: un segmento del perfil (z, y) extruido a lo largo de X. El suelo (pasillo y cabeceras), la
--     contrahuella, la banqueta, el talud y el paramento (de 0 a halfLength) y el muro lateral de la cabecera.
--   - Caras: un polígono en (z, y) sobre un plano x = const: el muro del fondo (EndWall) y la cara del
--     extremo del bloque del pasillo que mira a la cabecera (AlleyEnd).
--   - Aros: la corona (innerRadius..outerRadius) en el plano (y, z), extruida |x| <= thickness/2. Se asume
--     el aro centrado en x = 0 (ring.centerX = 0, como en CourtGeometry).
-- La colisión esfera-sólido toma el punto del sólido más cercano al centro y expulsa a lo largo de la normal.
--
-- Eventos que devuelve step (cada uno { kind, ... }), en el orden en que ocurren dentro de cada subpaso:
-- "bounce" (y tras él "ringRim" si es un aro o "endWall" si es la primera vez en vuelo contra el muro del
-- fondo), "ringPass", "crossEndLine" / "returnEndLine", "out" y "rest".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Data = require(ReplicatedStorage.Shared.Data.Ballgame)

local BallSim = {}

export type RingTrack = { entry: number? } -- por aro: el sentido (-1 | 1) con que entró por una cara
export type State = {
	pos: Vector3,
	vel: Vector3,
	resting: boolean,
	dead: boolean, -- true tras "out": ya no se simula
	endArmed: boolean, -- el muro del fondo aún no se ha tocado desde que la pelota dejó el suelo
	ringState: { RingTrack }, -- [1] = aro en z < 0, [2] = aro en z > 0
}
export type Event = { kind: string, [string]: any }
export type Snapshot = { pos: Vector3, vel: Vector3, resting: boolean }

type Prism = {
	kind: string,
	x1: number,
	x2: number,
	z1: number,
	y1: number,
	z2: number,
	y2: number,
	nz: number, -- normal en el plano (z, y), hacia el lado libre
	ny: number,
}
type Face = { kind: string, x0: number, nx: number, poly: { { number } } }
type Compiled = { prisms: { Prism }, faces: { Face } }

BallSim.STEP = 1 / 60

-- Lo máximo que se mueve el centro en un subpaso (studs): menos que el radio, para no atravesar nada.
local MAX_SUB_DISTANCE = 0.8
local RADIUS = CourtGeometry.BALL_RADIUS
-- Por debajo de esta velocidad horizontal al rodar, la pelota se para.
local STOP_SPEED = 0.05
local EPSILON = 1e-6
-- Margen de inDomain (studs).
local DOMAIN_TOLERANCE = 0.05
-- Pasadas de resolución por subpaso (una esquina cóncava toca dos superficies).
local RESOLVE_PASSES = 3

-- ============================================================================ Sólidos compilados

local compiledCache: { [CourtGeometry.Layout]: Compiled } = setmetatable({}, { __mode = "k" }) :: any

local function compile(layout: CourtGeometry.Layout): Compiled
	local G = CourtGeometry
	local hl, endX = layout.halfLength, layout.endX
	local half = layout.headerHalfWidth
	local top = G.WALL_TOP_Y
	local prisms: { Prism } = {}

	-- Suelo continuo (pasillo y cabeceras): una sola superficie, sin costuras donde rodar.
	table.insert(prisms, { kind = "Floor", x1 = 0, x2 = endX, z1 = 0, y1 = 0, z2 = half, y2 = 0, nz = 0, ny = 1 })
	-- El perfil del muro lateral (sin el suelo ni la cornisa): la normal apunta hacia el pasillo.
	for _, seg in layout.profile do
		if seg.kind ~= "Floor" and seg.kind ~= "Cornice" then
			local dz, dy = seg.z2 - seg.z1, seg.y2 - seg.y1
			local len = math.sqrt(dz * dz + dy * dy)
			local nz, ny = -dy / len, dz / len
			-- De las dos perpendiculares, la que mira hacia -z (hacia dentro) o, si es horizontal, hacia arriba.
			if nz > EPSILON or (math.abs(nz) <= EPSILON and ny < 0) then
				nz, ny = -nz, -ny
			end
			table.insert(prisms, {
				kind = seg.kind,
				x1 = 0,
				x2 = hl,
				z1 = seg.z1,
				y1 = seg.y1,
				z2 = seg.z2,
				y2 = seg.y2,
				nz = nz,
				ny = ny,
			})
		end
	end
	-- Muro lateral de la cabecera.
	table.insert(
		prisms,
		{ kind = "HeaderWall", x1 = hl, x2 = endX, z1 = half, y1 = 0, z2 = half, y2 = top, nz = -1, ny = 0 }
	)

	local faces: { Face } = {
		-- Muro del fondo de la cabecera.
		{ kind = "EndWall", x0 = endX, nx = -1, poly = { { 0, 0 }, { half, 0 }, { half, top }, { 0, top } } },
		-- Cara del extremo del bloque del pasillo (banqueta, talud y paramento) hacia la cabecera.
		{
			kind = "AlleyEnd",
			x0 = hl,
			nx = 1,
			poly = {
				{ G.BENCH_INNER_Z, 0 },
				{ G.BENCH_INNER_Z, G.BENCH_HEIGHT },
				{ G.BENCH_OUTER_Z, G.BENCH_HEIGHT },
				{ G.TALUD_OUTER_Z, G.TALUD_TOP_Y },
				{ G.TALUD_OUTER_Z, top },
				{ half, top },
				{ half, 0 },
			},
		},
	}
	return { prisms = prisms, faces = faces }
end

local function compiled(layout: CourtGeometry.Layout): Compiled
	local found = compiledCache[layout]
	if not found then
		found = compile(layout)
		compiledCache[layout] = found
	end
	return found
end

-- ============================================================================ Distancias al sólido

-- Punto más cercano de un segmento (az, ay)-(bz, by) a (pz, py): devuelve (z, y, t).
local function closestOnSegment(az: number, ay: number, bz: number, by: number, pz: number, py: number)
	local dz, dy = bz - az, by - ay
	local len2 = dz * dz + dy * dy
	local t = 0
	if len2 > EPSILON then
		t = math.clamp(((pz - az) * dz + (py - ay) * dy) / len2, 0, 1)
	end
	return az + dz * t, ay + dy * t, t
end

-- Distancia (al cuadrado) de un punto plegado al prisma, con el punto más cercano y su parámetro en el segmento.
local function prismClosest(s: Prism, px: number, py: number, pz: number)
	local cx = math.clamp(px, s.x1, s.x2)
	local qz, qy, t = closestOnSegment(s.z1, s.y1, s.z2, s.y2, pz, py)
	local dx, dy, dz = px - cx, py - qy, pz - qz
	return dx * dx + dy * dy + dz * dz, cx, qy, qz, t
end

local function insidePolygon(poly: { { number } }, z: number, y: number): boolean
	local inside = false
	local count = #poly
	local j = count
	for i = 1, count do
		local zi, yi = poly[i][1], poly[i][2]
		local zj, yj = poly[j][1], poly[j][2]
		if (yi > y) ~= (yj > y) and z < (zj - zi) * (y - yi) / (yj - yi) + zi then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- Punto más cercano de una cara a un punto plegado que está delante de ella: devuelve (dist², z, y), o una
-- distancia infinita si el punto está detrás o más lejos que "reach".
local function faceClosest(f: Face, px: number, py: number, pz: number, reach: number)
	local side = (px - f.x0) * f.nx
	if side < 0 or side >= reach then
		return math.huge, pz, py
	end
	if insidePolygon(f.poly, pz, py) then
		return side * side, pz, py
	end
	local bestD2, bestZ, bestY = math.huge, pz, py
	local count = #f.poly
	local j = count
	for i = 1, count do
		local qz, qy = closestOnSegment(f.poly[j][1], f.poly[j][2], f.poly[i][1], f.poly[i][2], pz, py)
		local dz, dy = pz - qz, py - qy
		local d2 = side * side + dz * dz + dy * dy
		if d2 < bestD2 then
			bestD2, bestZ, bestY = d2, qz, qy
		end
		j = i
	end
	return bestD2, bestZ, bestY
end

-- ============================================================================ Contexto del subpaso

-- Estado plegado del subpaso en curso (cuadrante +X, +Z). Es un solo objeto reutilizado: step no cede.
type Ctx = {
	px: number,
	py: number,
	pz: number,
	vx: number,
	vy: number,
	vz: number,
	sx: number, -- signo con que se plegó X (los contactos se desdoblan con él)
	sz: number,
	events: { Event },
	state: State,
	rolling: string?, -- superficie plana sobre la que rueda (contacto sin rebote) en este subpaso
	ringTouched: { boolean },
}

local ctx: Ctx = {
	px = 0,
	py = 0,
	pz = 0,
	vx = 0,
	vy = 0,
	vz = 0,
	sx = 1,
	sz = 1,
	events = {},
	state = nil :: any,
	rolling = nil,
	ringTouched = { false, false },
}

-- Choque con una superficie de normal plegada (nx, ny, nz) tocada en (qx, qy, qz) plegado. La posición ya está
-- expulsada; aquí solo se corrige la velocidad y se anotan los eventos.
local function contact(kind: string, nx: number, ny: number, nz: number, qx: number, qy: number, qz: number)
	local c = ctx
	local state = c.state
	if kind == "Floor" or kind == "Bench" then
		state.endArmed = true
	end
	local vn = c.vx * nx + c.vy * ny + c.vz * nz
	if vn >= 0 then
		return -- ya se aleja
	end
	local speed = -vn
	local firstEndWall = kind == "EndWall" and state.endArmed
	if firstEndWall then
		state.endArmed = false
	end

	if speed < Data.RestSpeed then
		-- Sin rebote: queda en contacto (se quita la velocidad normal) y, si la superficie es plana, rueda.
		c.vx -= vn * nx
		c.vy -= vn * ny
		c.vz -= vn * nz
		if ny > 0.99 and (kind == "Floor" or kind == "Bench") then
			c.rolling = kind
		end
	else
		local e = Data.Restitution[kind] or 0.7
		local keep = Data.TangentialKeep
		c.vx = (c.vx - vn * nx) * keep - e * vn * nx
		c.vy = (c.vy - vn * ny) * keep - e * vn * ny
		c.vz = (c.vz - vn * nz) * keep - e * vn * nz
	end

	if speed > Data.MinBounceSpeed then
		table.insert(c.events, {
			kind = "bounce",
			surface = kind,
			pos = Vector3.new(qx * c.sx, qy, qz * c.sz),
			speed = speed,
			side = CourtGeometry.teamOfSide(c.px * c.sx),
		})
	end
	if kind == "Ring" then
		table.insert(c.events, { kind = "ringRim", zSign = c.sz })
	end
	if firstEndWall then
		table.insert(c.events, { kind = "endWall", sign = c.sx })
	end
end

-- Expulsa la pelota a q + n·radio y aplica el choque.
local function push(kind: string, nx: number, ny: number, nz: number, qx: number, qy: number, qz: number)
	ctx.px, ctx.py, ctx.pz = qx + nx * RADIUS, qy + ny * RADIUS, qz + nz * RADIUS
	contact(kind, nx, ny, nz, qx, qy, qz)
end

local function collidePrism(s: Prism): boolean
	local c = ctx
	local d2, cx, qy, qz, t = prismClosest(s, c.px, c.py, c.pz)
	if d2 >= RADIUS * RADIUS then
		return false
	end
	local dist = math.sqrt(d2)
	local nx, ny, nz = 0, s.ny, s.nz
	if dist > EPSILON then
		nx, ny, nz = (c.px - cx) / dist, (c.py - qy) / dist, (c.pz - qz) / dist
		-- Detrás de la superficie (tras un tunelado): se saca por su lado libre.
		if t > 0 and t < 1 and (c.py - qy) * s.ny + (c.pz - qz) * s.nz < 0 then
			nx, ny, nz = 0, s.ny, s.nz
		end
	end
	push(s.kind, nx, ny, nz, cx, qy, qz)
	return true
end

local function collideFace(f: Face): boolean
	local c = ctx
	local d2, qz, qy = faceClosest(f, c.px, c.py, c.pz, RADIUS)
	if d2 >= RADIUS * RADIUS then
		return false
	end
	local dist = math.sqrt(d2)
	local nx, ny, nz = f.nx, 0, 0
	if dist > EPSILON then
		nx, ny, nz = (c.px - f.x0) / dist, (c.py - qy) / dist, (c.pz - qz) / dist
	end
	push(f.kind, nx, ny, nz, f.x0, qy, qz)
	return true
end

-- La corona del aro del lado de ctx.sz (el cuadrante plegado siempre tiene su aro en z = +centerZ).
local function collideRing(ring: CourtGeometry.Ring): boolean
	local c = ctx
	local half = ring.thickness / 2
	if c.px > half + RADIUS then
		return false
	end
	local dyc, dzc = c.py - ring.centerY, c.pz - ring.centerZ
	local rho = math.sqrt(dyc * dyc + dzc * dzc)
	local dirY, dirZ = 1, 0
	if rho > EPSILON then
		dirY, dirZ = dyc / rho, dzc / rho
	end
	local radial = math.clamp(rho, ring.innerRadius, ring.outerRadius)
	local qx = math.min(c.px, half)
	local qy, qz = ring.centerY + dirY * radial, ring.centerZ + dirZ * radial
	local dx, dy, dz = c.px - qx, c.py - qy, c.pz - qz
	local d2 = dx * dx + dy * dy + dz * dz
	if d2 >= RADIUS * RADIUS then
		return false
	end
	local nx, ny, nz
	if d2 > EPSILON and (rho < ring.innerRadius or rho > ring.outerRadius or c.px > half) then
		local dist = math.sqrt(d2)
		nx, ny, nz = dx / dist, dy / dist, dz / dist
	else
		-- El centro está dentro de la piedra: sale por la salida más corta.
		local toFace = half - c.px
		local toInner = rho - ring.innerRadius
		local toOuter = ring.outerRadius - rho
		if toFace <= toInner and toFace <= toOuter then
			nx, ny, nz = 1, 0, 0
			qx, qy, qz = half, c.py, c.pz
		elseif toInner <= toOuter then
			nx, ny, nz = 0, -dirY, -dirZ
			qx, qy, qz = c.px, ring.centerY + dirY * ring.innerRadius, ring.centerZ + dirZ * ring.innerRadius
		else
			nx, ny, nz = 0, dirY, dirZ
			qx, qy, qz = c.px, ring.centerY + dirY * ring.outerRadius, ring.centerZ + dirZ * ring.outerRadius
		end
	end
	c.ringTouched[if c.sz < 0 then 1 else 2] = true
	push("Ring", nx, ny, nz, qx, qy, qz)
	return true
end

-- ============================================================================ Un subpaso

local function sign(value: number): number
	return if value < 0 then -1 else 1
end

-- true si (ax, az, y) queda por encima del borde de la plaza donde hay muro (la pelota se «sale»).
local function isOut(layout: CourtGeometry.Layout, ax: number, az: number, y: number): boolean
	if y <= CourtGeometry.WALL_TOP_Y then
		return false
	end
	if ax > layout.endX then
		return true
	end
	if ax <= layout.halfLength then
		return az > CourtGeometry.TALUD_OUTER_Z
	end
	return az > layout.headerHalfWidth
end

-- Sigue los cruces de las caras del aro con el centro de la pelota. Un pase es entrar por una cara dentro del
-- agujero y salir por la contraria sin tocar el anillo.
local function trackRings(state: State, ring: CourtGeometry.Ring, old: Vector3, new: Vector3, events: { Event })
	local half = ring.thickness / 2
	for index = 1, 2 do
		local zSign = if index == 1 then -1 else 1
		local track = state.ringState[index]
		if ctx.ringTouched[index] then
			track.entry = nil
			continue
		end
		local ox, nx = old.X, new.X
		local oin, nin = math.abs(ox) < half, math.abs(nx) < half
		if oin == nin then
			continue -- no cruza ninguna cara (o cruza las dos de golpe, imposible con subpasos < 3 studs)
		end
		-- Dónde estaba el centro al cruzar el plano de la cara.
		local face = if oin then sign(nx) * half else sign(ox) * half
		local f = (face - ox) / (nx - ox)
		local dy = old.Y + (new.Y - old.Y) * f - ring.centerY
		local dz = old.Z + (new.Z - old.Z) * f - zSign * ring.centerZ
		local inHole = math.sqrt(dy * dy + dz * dz) < ring.innerRadius
		local dir = sign(nx - ox)
		if not oin then
			track.entry = if inHole then dir else nil
		else
			if inHole and track.entry == dir then
				table.insert(events, { kind = "ringPass", zSign = zSign, dir = dir })
			end
			track.entry = nil
		end
	end
end

local function subStep(state: State, layout: CourtGeometry.Layout, comp: Compiled, sub: number, events: { Event })
	local c = ctx
	local old = state.pos

	-- Gravedad, arrastre y tope de velocidad.
	local drag = math.max(0, 1 - Data.AirDrag * sub)
	local vx, vy, vz = state.vel.X * drag, (state.vel.Y - Data.Gravity * sub) * drag, state.vel.Z * drag
	local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
	if speed > Data.MaxSpeed then
		local scale = Data.MaxSpeed / speed
		vx, vy, vz = vx * scale, vy * scale, vz * scale
	end
	local x, y, z = old.X + vx * sub, old.Y + vy * sub, old.Z + vz * sub

	-- Por encima del borde de la plaza: fuera.
	if isOut(layout, math.abs(x), math.abs(z), y) then
		state.pos = Vector3.new(x, y, z)
		state.vel = Vector3.new(vx, vy, vz)
		state.dead = true
		table.insert(events, { kind = "out", pos = state.pos })
		return
	end

	-- Se pliega al cuadrante (+X, +Z) y se resuelve.
	c.sx, c.sz = sign(x), sign(z)
	c.px, c.py, c.pz = math.abs(x), y, math.abs(z)
	c.vx, c.vy, c.vz = vx * c.sx, vy, vz * c.sz
	c.state, c.events, c.rolling = state, events, nil
	c.ringTouched[1], c.ringTouched[2] = false, false
	for _ = 1, RESOLVE_PASSES do
		local hit = false
		for _, prism in comp.prisms do
			hit = collidePrism(prism) or hit
		end
		for _, face in comp.faces do
			hit = collideFace(face) or hit
		end
		hit = collideRing(layout.ring) or hit
		if not hit then
			break
		end
	end

	-- Rodando por una superficie plana: pierde velocidad horizontal hasta pararse.
	local rolling = c.rolling
	local rested = false
	if rolling then
		local horizontal = math.sqrt(c.vx * c.vx + c.vz * c.vz)
		local remaining = horizontal - Data.RollingDecel * sub
		if remaining <= STOP_SPEED then
			c.vx, c.vz, c.vy = 0, 0, 0
			rested = true
		else
			local scale = remaining / horizontal
			c.vx, c.vz = c.vx * scale, c.vz * scale
		end
	end

	-- Se desdobla.
	local newPos = Vector3.new(c.px * c.sx, c.py, c.pz * c.sz)
	state.pos = newPos
	state.vel = Vector3.new(c.vx * c.sx, c.vy, c.vz * c.sz)

	trackRings(state, layout.ring, old, newPos, events)

	local oldAx, newAx = math.abs(old.X), math.abs(newPos.X)
	local hl = layout.halfLength
	if oldAx <= hl and newAx > hl then
		table.insert(events, { kind = "crossEndLine", sign = sign(newPos.X), pos = newPos })
	elseif oldAx > hl and newAx <= hl then
		table.insert(events, { kind = "returnEndLine", sign = sign(newPos.X), pos = newPos })
	end

	if rested then
		state.resting = true
		table.insert(events, { kind = "rest", pos = newPos, surface = rolling })
	end
end

-- ============================================================================ API

function BallSim.new(position: Vector3, velocity: Vector3?): State
	return {
		pos = position,
		vel = velocity or Vector3.zero,
		resting = false,
		dead = false,
		endArmed = true,
		ringState = { { entry = nil }, { entry = nil } },
	}
end

-- Avanza "dt" segundos (por defecto un paso fijo). Si dt > STEP lo divide en pasos de STEP. Devuelve los eventos.
function BallSim.step(state: State, layout: CourtGeometry.Layout, dt: number?): { Event }
	local events: { Event } = {}
	if state.resting or state.dead then
		return events
	end
	local comp = compiled(layout)
	local remaining = dt or BallSim.STEP
	while remaining > 1e-9 do
		local h = math.min(remaining, BallSim.STEP)
		remaining -= h
		-- Subpasos para que el centro no avance más de MAX_SUB_DISTANCE (a 140 studs/s, 3 por paso).
		local reach = (state.vel.Magnitude + Data.Gravity * h) * h
		local count = math.max(1, math.ceil(reach / MAX_SUB_DISTANCE))
		for _ = 1, count do
			subStep(state, layout, comp, h / count, events)
			if state.dead or state.resting then
				return events
			end
		end
	end
	return events
end

function BallSim.clone(state: State): State
	local rings: { RingTrack } = {}
	for index, track in state.ringState do
		rings[index] = { entry = track.entry }
	end
	return {
		pos = state.pos,
		vel = state.vel,
		resting = state.resting,
		dead = state.dead,
		endArmed = state.endArmed,
		ringState = rings,
	}
end

-- Lo que viaja por la red.
function BallSim.snapshot(state: State): Snapshot
	return { pos = state.pos, vel = state.vel, resting = state.resting }
end

-- Fija el estado a lo recibido por la red. Los pases de aro a medias se olvidan (no viajan).
function BallSim.restore(state: State, snapshot: Snapshot)
	state.pos = snapshot.pos
	state.vel = snapshot.vel
	state.resting = snapshot.resting
	state.dead = false
	for _, track in state.ringState do
		track.entry = nil
	end
end

-- Comprobación para pruebas: la pelota está dentro del recinto y no bajo ni dentro de ninguna superficie.
function BallSim.inDomain(state: State, layout: CourtGeometry.Layout): boolean
	local p = state.pos
	local ax, az, y = math.abs(p.X), math.abs(p.Z), p.Y
	if y > CourtGeometry.WALL_TOP_Y then
		return true -- por encima de la plaza no hay nada que atravesar
	end
	if ax > layout.endX + DOMAIN_TOLERANCE then
		return false
	end
	local zLimit = if ax <= layout.halfLength then CourtGeometry.TALUD_OUTER_Z else layout.headerHalfWidth
	if az > zLimit + DOMAIN_TOLERANCE then
		return false
	end
	local minimum = RADIUS - DOMAIN_TOLERANCE
	local comp = compiled(layout)
	for _, prism in comp.prisms do
		if (prismClosest(prism, ax, y, az)) < minimum * minimum then
			return false
		end
	end
	for _, face in comp.faces do
		if (faceClosest(face, ax, y, az, RADIUS)) < minimum * minimum then
			return false
		end
	end
	return true
end

return BallSim
