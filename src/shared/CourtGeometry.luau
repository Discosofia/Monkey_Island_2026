--!strict
-- Geometría de la cancha del Juego de pelota de Dunas (Fase 26b): un módulo de datos y cuentas, sin
-- Instances. Lo leen el constructor (Dunas/World/CourtBuilder) y, en la Fase 26c, la simulación de la
-- pelota (BallSim), así que las medidas están SOLO aquí.
--
-- Fuente: docs/juego de pelota.txt. Modelo: el gran juego de pelota de Chichén Itzá (~166 m de largo total,
-- pasillo de ~30 m de ancho, muros de ~8 m con el talud en la base, aros a ~6 m del suelo; el talud, más
-- tendido que el real: 25°). Escala de juego:
-- 1 stud ≈ 0,28 m, redondeada a lo jugable (el pasillo es de 30 studs; el aro, a y = 22, unos 6 m a 0,28 m/stud).
--
-- Sistema de coordenadas LOCAL (el constructor lo traslada con CourtBuilder.CENTER):
--   origen: el centro del pasillo, a nivel del suelo de juego (y = 0)
--   X: el eje largo del pasillo. El equipo Jaguar, en X negativa; el Quetzal, en X positiva
--   Z: el ancho (los muros laterales son simétricos en ±Z)
--   Y: arriba
--
-- Perfil de cada muro lateral, de dentro (z = 0) a fuera, en (z, y):
--   suelo        (0, 0) → (15, 0)
--   contrahuella (15, 0) → (15, 2)         salto de la banqueta
--   banqueta     (15, 2) → (18, 2)
--   talud        (18, 2) → (48, 16)        a 25° (30 de tramo, igual que el ancho del pasillo, y 14 de subida; la
--                                          pelota rebota y al jugador lo desliza hacia el pasillo, ver
--                                          Data/Ballgame.Talud)
--   paramento    (48, 16) → (48, 30)       vertical; el aro está en él, a y = 22
--   cornisa      (48, 30) → (88, 30)       la plaza superior que rodea la cancha
-- Las cabeceras (planta en «I» o doble T) son salas de 30 de fondo × 132 de ancho en cada extremo del pasillo.

local CourtGeometry = {}

export type Segment = { kind: string, z1: number, y1: number, z2: number, y2: number }

export type Ring = {
	centerX: number,
	centerY: number,
	centerZ: number, -- valor absoluto: hay un aro en z = -centerZ y otro en z = +centerZ
	innerRadius: number,
	outerRadius: number,
	thickness: number, -- grosor a lo largo de X
}

export type Spawn = { x: number, y: number, zMin: number, zMax: number }

-- Lo que dice taludAt de un jugador que está sobre el talud (coordenadas locales de la cancha).
export type TaludInfo = {
	zSign: number, -- lado del talud (-1 | 1)
	surfaceY: number, -- altura de la superficie bajo los pies
	downhill: Vector3, -- unitario: la dirección de máxima bajada, hacia el pasillo
	normal: Vector3, -- unitario: perpendicular a la pendiente, hacia el pasillo y arriba
}

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

CourtGeometry.ALLEY_HALF_WIDTH = 15 -- pasillo de 30
CourtGeometry.BENCH_INNER_Z = 15
CourtGeometry.BENCH_OUTER_Z = 18
CourtGeometry.BENCH_HEIGHT = 2
CourtGeometry.TALUD_TOP_Y = 16
-- Tramo horizontal del talud: igual que el ancho del pasillo (30). Con la subida de 14 queda a ~25°.
CourtGeometry.TALUD_RUN = 30
CourtGeometry.TALUD_OUTER_Z = CourtGeometry.BENCH_OUTER_Z + CourtGeometry.TALUD_RUN
CourtGeometry.WALL_TOP_Y = 30 -- alto del paramento y de las cabeceras: el nivel de la plaza
CourtGeometry.CORNICE_DEPTH = 40 -- cuánto se extiende la plaza hacia fuera desde el paramento
CourtGeometry.PLAZA_HALF_Z = CourtGeometry.TALUD_OUTER_Z + CourtGeometry.CORNICE_DEPTH
-- Altura sobre la superficie del talud hasta la que un jugador en el aire sigue contando «sobre el talud».
CourtGeometry.TALUD_AIR_REACH = 40

CourtGeometry.HEADER_DEPTH = 30 -- largo de cada cabecera en X
CourtGeometry.HEADER_HALF_WIDTH = 66 -- cabecera de 132 de ancho: sobresale 18 de cada muro (±48) y marca la «I»

-- Línea central (tlécotl): ancho de la banda negra y del filete de jade del centro.
CourtGeometry.TLECOTL_WIDTH = 2.4
CourtGeometry.TLECOTL_FILLET = 0.8

-- Muro de equipo (solo para jugadores): el plano x = 0 de z ±TALUD_OUTER_Z y de y = 0 a esto.
CourtGeometry.TEAM_WALL_HEIGHT = 34

-- Aros (tlachtemalácatl): uno en cada paramento, en x = 0, con el agujero a lo largo de X.
CourtGeometry.ring = {
	centerX = 0,
	centerY = 22,
	centerZ = CourtGeometry.TALUD_OUTER_Z - 4.6, -- la piedra exterior (5,2) entra 0,6 en el paramento
	-- Hueco de 6,4 de diámetro (la pelota mide 2). Con el aro a 30 studs del pasillo y el hueco a lo largo de X,
	-- 1,6 de radio no lo emboca ningún golpe: con 3,2 se iguala o supera lo que se embocaba con el aro original
	-- (tools/luau/BallRingOdds.luau, 27a).
	innerRadius = 3.2,
	outerRadius = 5.2,
	thickness = 3,
} :: Ring

-- La pelota de hule (la usa BallSim en 26c).
CourtGeometry.BALL_RADIUS = 1

-- Dónde aparece cada equipo: a 11 studs de la línea de fondo, repartido en z ±20, y = 0,5.
CourtGeometry.SPAWN_OFFSET = 11
CourtGeometry.SPAWN_HALF_Z = 20
CourtGeometry.SPAWN_Y = 0.5
-- Los jugadores sin equipo esperan en la plaza superior.
CourtGeometry.WAITING = Vector3.new(0, 31, -71) -- el centro de la plaza entre el paramento (54) y el borde (88)

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

-- Si los pies (coordenadas LOCALES de la cancha) están sobre el talud, o cerca de él en el aire, devuelve la
-- pendiente que los desliza; si no, nil. La banqueta es plana y no desliza.
function CourtGeometry.taludAt(layout: Layout, feet: Vector3): TaludInfo?
	local G = CourtGeometry
	local absZ = math.abs(feet.Z)
	if math.abs(feet.X) > layout.halfLength or absZ < G.BENCH_OUTER_Z or absZ >= G.TALUD_OUTER_Z then
		return nil
	end
	local surface = G.surfaceY(absZ) :: number
	if feet.Y > surface + G.TALUD_AIR_REACH or feet.Y < surface - 3 then
		return nil
	end
	local zSign = if feet.Z < 0 then -1 else 1
	-- La pendiente real: el tramo y la subida no son iguales (a 25°).
	local run = G.TALUD_RUN
	local rise = G.TALUD_TOP_Y - G.BENCH_HEIGHT
	return {
		zSign = zSign,
		surfaceY = surface,
		downhill = Vector3.new(0, -rise, -zSign * run).Unit,
		normal = Vector3.new(0, run, -zSign * rise).Unit,
	}
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

-- Signo en X del campo de un equipo: el Jaguar defiende X negativa (-1); el otro, +1.
function CourtGeometry.sideSign(teamId: string?): number
	return if teamId == "Jaguar" then -1 else 1
end

return CourtGeometry
