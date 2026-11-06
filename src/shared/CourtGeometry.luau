--!strict
-- Geometría de la cancha del Juego de pelota de Dunas (Fase 26b): un módulo de datos y cuentas, sin
-- Instances. Lo leen el constructor (Dunas/World/CourtBuilder) y, en la Fase 26c, la simulación de la
-- pelota (BallSim), así que las medidas están SOLO aquí.
--
-- Fuente: docs/juego de pelota.txt. Modelo: el gran juego de pelota de Chichén Itzá (~166 m de largo total,
-- pasillo de ~30 m de ancho, muros de ~8 m con el talud en la base, aros a ~6 m del suelo). Escala de juego:
-- 1 stud ≈ 0,28 m, redondeada a lo jugable (el pasillo es de 26 studs; el aro, a 15).
--
-- Sistema de coordenadas LOCAL (el constructor lo traslada con CourtBuilder.CENTER):
--   origen: el centro del pasillo, a nivel del suelo de juego (y = 0)
--   X: el eje largo del pasillo. El equipo Jaguar, en X negativa; el Quetzal, en X positiva
--   Z: el ancho (los muros laterales son simétricos en ±Z)
--   Y: arriba
--
-- Perfil de cada muro lateral, de dentro (z = 0) a fuera, en (z, y):
--   suelo        (0, 0) → (13, 0)
--   contrahuella (13, 0) → (13, 2)         salto de la banqueta
--   banqueta     (13, 2) → (16, 2)
--   talud        (16, 2) → (22.5, 10)      ~51° (se sube andando; la pelota rebota)
--   paramento    (22.5, 10) → (22.5, 20)   vertical
--   cornisa      (22.5, 20) → (62.5, 20)   la plaza superior que rodea la cancha
-- Las cabeceras (planta en «I» o doble T) son salas de 22 × 80 en cada extremo del pasillo.

local CourtGeometry = {}

export type Segment = { kind: string, z1: number, y1: number, z2: number, y2: number }

export type Ring = {
	centerX: number,
	centerY: number,
	centerZ: number, -- valor absoluto: hay un aro en z = -centerZ y otro en z = +centerZ
	innerRadius: number,
	outerRadius: number,
	thickness: number, -- grosor a lo largo de X
	embed: number, -- lo que la piedra exterior entra en el paramento
}

export type Spawn = { x: number, y: number, zMin: number, zMax: number }

export type Layout = {
	format: number,
	length: number, -- largo del pasillo
	halfLength: number,
	halfWidth: number,
	endX: number, -- |x| del fondo de cada cabecera (la cara de dentro del muro del fondo)
	headerHalfWidth: number,
	profile: { Segment }, -- medio perfil (z ≥ 0); el otro lado es su espejo
	ring: Ring,
	spawns: { Jaguar: Spawn, Quetzal: Spawn },
	waiting: Vector3,
}

-- Dónde queda el origen local de la cancha en el mundo. Z = 1400: Workspace.Arena tiene un suelo de 1800 × 1800
-- (hasta z = 900) y su horizonte llega a ~800, y el desierto de la cancha empieza en z ≈ 940. Lo usan el
-- constructor (servidor) y el dibujo de la pelota (cliente).
CourtGeometry.CENTER = Vector3.new(0, 0, 1400)

CourtGeometry.MIN_FORMAT = 1
CourtGeometry.MAX_FORMAT = 5
-- Largo del pasillo por formato (jugadores por equipo).
CourtGeometry.LENGTHS = { 56, 72, 88, 104, 120 }

CourtGeometry.ALLEY_HALF_WIDTH = 13 -- pasillo de 26
CourtGeometry.BENCH_INNER_Z = 13
CourtGeometry.BENCH_OUTER_Z = 16
CourtGeometry.BENCH_HEIGHT = 2
CourtGeometry.TALUD_OUTER_Z = 22.5
CourtGeometry.TALUD_TOP_Y = 10
CourtGeometry.WALL_TOP_Y = 20 -- alto del paramento y de las cabeceras: el nivel de la plaza
CourtGeometry.CORNICE_DEPTH = 40 -- cuánto se extiende la plaza hacia fuera desde el paramento
CourtGeometry.PLAZA_HALF_Z = 62.5 -- TALUD_OUTER_Z + CORNICE_DEPTH

CourtGeometry.HEADER_DEPTH = 22 -- largo de cada cabecera en X
CourtGeometry.HEADER_HALF_WIDTH = 40 -- cabecera de 80 de ancho: sobresale de los taludes (±22,5) y marca la doble T

-- Línea central (tlécotl): ancho de la banda negra y del filete de jade del centro.
CourtGeometry.TLECOTL_WIDTH = 2.4
CourtGeometry.TLECOTL_FILLET = 0.8

-- Muro de equipo (solo para jugadores): el plano x = 0 de z ±TALUD_OUTER_Z y de y = 0 a esto.
CourtGeometry.TEAM_WALL_HEIGHT = 24

-- Aros (tlachtemalácatl): uno en cada paramento, en x = 0, con el agujero a lo largo de X.
CourtGeometry.ring = {
	centerX = 0,
	centerY = 15,
	centerZ = 19.5,
	innerRadius = 1.6, -- agujero de 3,2 de diámetro
	outerRadius = 3.6,
	thickness = 3,
	embed = 0.6, -- 19,5 + 3,6 = 23,1 contra el paramento en 22,5
} :: Ring

-- La pelota de hule (la usa BallSim en 26c).
CourtGeometry.BALL_RADIUS = 1

-- Dónde aparece cada equipo: a 11 studs de la línea de fondo, repartido en z ±20, y = 0,5.
CourtGeometry.SPAWN_OFFSET = 11
CourtGeometry.SPAWN_HALF_Z = 20
CourtGeometry.SPAWN_Y = 0.5
-- Los jugadores sin equipo esperan en la plaza superior.
CourtGeometry.WAITING = Vector3.new(0, 21, -45)

local function clampFormat(format: number): number
	return math.clamp(math.floor(format + 0.5), CourtGeometry.MIN_FORMAT, CourtGeometry.MAX_FORMAT)
end

-- Medio perfil del muro lateral (z ≥ 0), de dentro a fuera.
local function buildProfile(): { Segment }
	local G = CourtGeometry
	local top = G.WALL_TOP_Y
	return {
		{ kind = "Floor", z1 = 0, y1 = 0, z2 = G.BENCH_INNER_Z, y2 = 0 },
		{ kind = "Riser", z1 = G.BENCH_INNER_Z, y1 = 0, z2 = G.BENCH_INNER_Z, y2 = G.BENCH_HEIGHT },
		{ kind = "Bench", z1 = G.BENCH_INNER_Z, y1 = G.BENCH_HEIGHT, z2 = G.BENCH_OUTER_Z, y2 = G.BENCH_HEIGHT },
		{ kind = "Talud", z1 = G.BENCH_OUTER_Z, y1 = G.BENCH_HEIGHT, z2 = G.TALUD_OUTER_Z, y2 = G.TALUD_TOP_Y },
		{ kind = "Wall", z1 = G.TALUD_OUTER_Z, y1 = G.TALUD_TOP_Y, z2 = G.TALUD_OUTER_Z, y2 = top },
		{ kind = "Cornice", z1 = G.TALUD_OUTER_Z, y1 = top, z2 = G.PLAZA_HALF_Z, y2 = top },
	}
end

-- Las medidas de la cancha para un formato (jugadores por equipo, de 1 a 5).
function CourtGeometry.forFormat(format: number): Layout
	local G = CourtGeometry
	local clamped = clampFormat(format)
	local length = G.LENGTHS[clamped]
	local halfLength = length / 2
	local spawnX = halfLength + G.SPAWN_OFFSET
	return {
		format = clamped,
		length = length,
		halfLength = halfLength,
		halfWidth = G.ALLEY_HALF_WIDTH,
		endX = halfLength + G.HEADER_DEPTH,
		headerHalfWidth = G.HEADER_HALF_WIDTH,
		profile = buildProfile(),
		ring = G.ring,
		spawns = {
			Jaguar = { x = -spawnX, y = G.SPAWN_Y, zMin = -G.SPAWN_HALF_Z, zMax = G.SPAWN_HALF_Z },
			Quetzal = { x = spawnX, y = G.SPAWN_Y, zMin = -G.SPAWN_HALF_Z, zMax = G.SPAWN_HALF_Z },
		},
		waiting = G.WAITING,
	}
end

-- Altura de la superficie por la que se anda (o rebota la pelota) a la distancia lateral "absZ" del eje del
-- pasillo, o nil si ahí hay un muro vertical (más allá del paramento). La contrahuella cuenta como la
-- altura de la banqueta.
function CourtGeometry.surfaceY(absZ: number): number?
	local G = CourtGeometry
	absZ = math.abs(absZ)
	if absZ < G.BENCH_INNER_Z then
		return 0
	elseif absZ < G.BENCH_OUTER_Z then
		return G.BENCH_HEIGHT
	elseif absZ < G.TALUD_OUTER_Z then
		local t = (absZ - G.BENCH_OUTER_Z) / (G.TALUD_OUTER_Z - G.BENCH_OUTER_Z)
		return G.BENCH_HEIGHT + t * (G.TALUD_TOP_Y - G.BENCH_HEIGHT)
	end
	return nil
end

-- true si "x" (local) queda más allá de la línea de fondo del pasillo del formato (la pelota está «fuera»).
function CourtGeometry.isOut(layout: Layout, x: number): boolean
	return math.abs(x) > layout.halfLength
end

-- Equipo que defiende el lado de "x" (el Jaguar, en X negativa); nil justo en la línea central.
function CourtGeometry.teamOfSide(x: number): string?
	if x < 0 then
		return "Jaguar"
	elseif x > 0 then
		return "Quetzal"
	end
	return nil
end

return CourtGeometry
