--!strict
-- Cancha del Juego de pelota de Dunas (Fase 26b): un patio hundido de estilo maya, con el pasillo en «I»,
-- los muros con banqueta y talud, los aros de piedra y la plaza superior que lo rodea. Es el segundo mapa
-- de Dunas (el otro es Workspace.Arena, ArenaBuilder) y vive lejos de él.
--
-- Las medidas están en Shared/CourtGeometry (el mismo módulo que usará la simulación de la pelota en 26c).
-- Aquí solo se dibuja. Estilo voxel: pocas piezas grandes de tonos planos, y el detalle (bandas de color,
-- grecas, serpientes de los aros, soles) en cajas pequeñas.
--
-- Lo construye el servidor de Dunas al arrancar si no existe Workspace.Cancha o es de otra versión
-- (ArenaWorldService). Para dejarlo fijo en el place, en Studio, en modo edición, desde la barra de comandos:
--
--   require(game.ServerScriptService.Server.World.CourtBuilder).build()      -- todo, con el formato 5v5
--   require(game.ServerScriptService.Server.World.CourtBuilder).layout(3)    -- solo lo que cambia con el formato
--
-- Dos partes:
--   build()          Workspace.Cancha con lo ESTÁTICO: losa de base, plaza exterior, desierto, barandilla
--                    invisible del borde, "EsperaSpawn" (los que aún no tienen equipo) y la carpeta "Decor" (los
--                    dos templos en pirámide, estandartes e ídolos de la plaza: CourtDecor, Fase 27d).
--   layout(format)   Workspace.Cancha.Court con lo que depende del formato (jugadores por equipo, 1 a 5). Se
--                    construye aparte y sustituye a la anterior en el mismo fotograma, sin parpadeo. Su carpeta
--                    "Decor" lleva además "Extras" (relieves, greca de la cornisa y gradas con público, CourtDecor).
--
-- Piezas con nombre que lee el código (en Cancha.Court; _L es z negativa y _R z positiva):
--   Floor            suelo del pasillo (CanCollide)
--   Bench_L/R        banqueta; Talud_L/R, cuña del talud; Wall_L/R, paramento (CanCollide)
--   EndFloor_<equipo>, EndWall_<equipo>, HeaderWall_<equipo>_L/R   las cabeceras (CanCollide)
--   Ring_L/Ring_R    modelo del aro (decorado: la pelota es analítica)
--   Tlecotl          modelo de la línea central (decorado)
--   TeamBarrier      muro de equipo en x = 0, invisible, solo choca con los jugadores
--   Spawn_Jaguar/Spawn_Quetzal   volumen donde aparece cada equipo (invisible, sin colisión)
-- y en Cancha: "EsperaSpawn" (una Part, no un SpawnLocation: así Roblox no lo elige para aparecer solo).
-- Todo lo que no es superficie jugable lleva CanCollide, CanQuery y CanTouch en false (salvo las terrazas de
-- las pirámides de Cancha.Decor: CanCollide sí, CanQuery y CanTouch no).
-- El decorado (CourtDecor) se fusiona con VoxelMerge.mergeStatic al construirlo; el tope de piezas es
-- Config.Budgets.Matches.CourtParts y build() avisa si se pasa (el recuento sale en «¡Cancha lista!»).

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local CourtDecor = require(script.Parent.CourtDecor)

local FOLDER_NAME = "Cancha"
local COURT_NAME = "Court"
-- Sube este número al cambiar la cancha: los places con una versión anterior guardada la reconstruyen solos.
local VERSION = 7

-- Dónde queda el origen local de la cancha en el mundo (el valor y su porqué, en Shared/CourtGeometry).
local CENTER = CourtGeometry.CENTER

-- La plaza superior: sobre el nivel 30, con el borde exterior en x = ±132 y z = ±88 (40 studs desde el
-- paramento, y 40 desde el fondo de las cabeceras del formato 5v5).
local PLAZA_Y1 = -2 -- la plaza es maciza hasta la losa de base (sin huecos por debajo, vista desde las cabeceras)
local DESERT_Y1 = -8 -- y el desierto decorado, igual de macizo hasta el fondo
local PLAZA_HALF_X = 132 -- = 60 + 30 + 2 + 40 (fixedPlazaStart() más la cornisa)
local END_WALL_THICKNESS = 2
local SIDE_WALL_THICKNESS = 2
local WALL_BACK_Z = 54 -- hasta dónde llega el paramento (6 de grueso; las cabeceras están a 66)
local RAIL_HEIGHT = 32 -- barandilla invisible del borde exterior de la plaza
local DESERT_REACH = 400 -- el desierto decorado, más allá del borde de la plaza

-- Colores (voxel: tonos planos). El rojo es teja, no rojo puro (el rojo puro es el daño recibido).
local STUCCO = Color3.fromRGB(240, 234, 218) -- cal de los muros
local CREAM = Color3.fromRGB(238, 224, 186) -- suelo del pasillo: la pelota negra de hule se ve
local PLAZA = Color3.fromRGB(226, 214, 188)
local STONE = Color3.fromRGB(214, 200, 168) -- caliza clara de los aros
local STONE_DARK = Color3.fromRGB(196, 180, 146)
local LIMESTONE_DARK = Color3.fromRGB(132, 114, 90)
local SAND = Color3.fromRGB(222, 186, 128)
local RED = Color3.fromRGB(172, 52, 40)
local BLUE = Color3.fromRGB(48, 92, 152)
local YELLOW = Color3.fromRGB(232, 186, 52)
local BLACK = Color3.fromRGB(36, 32, 36)
local JADE = Color3.fromRGB(46, 125, 80)

local Concrete = Enum.Material.Concrete
local Limestone = Enum.Material.Limestone
local Paint = Enum.Material.SmoothPlastic

local CourtBuilder = {}
CourtBuilder.CENTER = CENTER
CourtBuilder.VERSION = VERSION
CourtBuilder.FOLDER_NAME = FOLDER_NAME

local groupsReady = false

-- El grupo de los muros invisibles: chocan con los personajes (Default) pero no con los rayos del combate.
local function registerGroups()
	if groupsReady then
		return
	end
	for _, group in { Config.ShotCollisionGroup, Config.Arena.CourtBarrierGroup } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(Config.Arena.CourtBarrierGroup, Config.ShotCollisionGroup, false)
	groupsReady = true
end

-- Caja entre las esquinas (x1, y1, z1) y (x2, y2, z2) del sistema local (en cualquier orden).
local function make(
	parent: Instance,
	name: string,
	frame: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	solid: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = CFrame.new(CENTER) * frame
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if not solid then
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		if size.Magnitude < 8 then
			part.CastShadow = false
		end
	end
	part.Parent = parent
	return part
end

local function span(
	parent: Instance,
	name: string,
	bounds: { number }, -- { x1, x2, y1, y2, z1, z2 }
	color: Color3,
	material: Enum.Material,
	solid: boolean
): Part
	local x1, x2, y1, y2, z1, z2 = bounds[1], bounds[2], bounds[3], bounds[4], bounds[5], bounds[6]
	return make(
		parent,
		name,
		CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2),
		Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1)),
		color,
		material,
		solid
	)
end

-- Superficie jugable (choca y la encuentran los rayos).
local function solid(parent: Instance, name: string, bounds: { number }, color: Color3, material: Enum.Material): Part
	return span(parent, name, bounds, color, material, true)
end

-- Decorado: se ve, pero no choca ni lo encuentran los rayos.
local function deco(parent: Instance, name: string, bounds: { number }, color: Color3, material: Enum.Material): Part
	return span(parent, name, bounds, color, material, false)
end

-- Barrera invisible: choca con los personajes, no con los rayos.
local function barrier(parent: Instance, name: string, bounds: { number })
	local part = span(parent, name, bounds, STUCCO, Paint, true)
	part.Transparency = 1
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.CollisionGroup = Config.Arena.CourtBarrierGroup
	return part
end

-- Pieza de ubicación (sin colisión, invisible).
local function marker(parent: Instance, name: string, bounds: { number }): Part
	local part = deco(parent, name, bounds, STUCCO, Paint)
	part.Transparency = 1
	return part
end

-- Lo que CourtDecor necesita de este módulo (sus creadores de cajas, materiales y colores).
local decorKit: CourtDecor.Kit = {
	deco = deco,
	solid = solid,
	Paint = Paint,
	Limestone = Limestone,
	STUCCO = STUCCO,
	STONE = STONE,
	STONE_DARK = STONE_DARK,
	LIMESTONE_DARK = LIMESTONE_DARK,
	RED = RED,
	BLUE = BLUE,
	YELLOW = YELLOW,
	BLACK = BLACK,
	JADE = JADE,
}

-- Color del cuadrante de las banquetas según (signo de X, signo de Z): los cuatro rumbos de los códices.
local function quadrantColor(xSign: number, zSign: number): Color3
	if xSign < 0 then
		return if zSign < 0 then RED else BLUE
	end
	return if zSign < 0 then YELLOW else BLACK
end

local function sideName(zSign: number): string
	return if zSign < 0 then "L" else "R"
end

-- Banda pegada a la pendiente del talud entre los puntos t1 y t2 (0 = pie, 1 = lo alto). "lift" la separa de la
-- superficie (para apilar una banda sobre otra sin que parpadeen).
local function slopeStrip(
	parent: Instance,
	name: string,
	zSign: number,
	x1: number,
	x2: number,
	t1: number,
	t2: number,
	color: Color3,
	lift: number?
)
	local G = CourtGeometry
	local run = G.TALUD_RUN
	local rise = G.TALUD_TOP_Y - G.BENCH_HEIGHT
	local length = math.sqrt(run * run + rise * rise)
	local normal = Vector3.new(0, run, -zSign * rise).Unit
	local tMid = (t1 + t2) / 2
	local surface = Vector3.new((x1 + x2) / 2, G.BENCH_HEIGHT + rise * tMid, zSign * (G.BENCH_OUTER_Z + run * tMid))
	local thick = 0.14
	local frame = CFrame.fromMatrix(surface + normal * ((lift or 0) + thick / 2), Vector3.xAxis, normal)
	make(parent, name, frame, Vector3.new(x2 - x1, thick, (t2 - t1) * length), color, Paint, false)
end

-- Dónde empieza la plaza fija de los extremos (|x|): justo tras el muro del fondo del formato más largo.
local function fixedPlazaStart(): number
	local G = CourtGeometry
	return G.LENGTHS[G.MAX_FORMAT] / 2 + G.HEADER_DEPTH + END_WALL_THICKNESS
end

-- ============================================================================ Lo que depende del formato

-- Los dos muros laterales: banqueta, talud, paramento, friso y plaza. "zSign" es el lado (-1 = L, +1 = R).
local function buildSide(court: Folder, art: Folder, geo: CourtGeometry.Layout, zSign: number)
	local G = CourtGeometry
	local hl = geo.halfLength
	local tag = sideName(zSign)
	local function z(a: number, b: number): { number }
		return { zSign * a, zSign * b }
	end
	local function box(xs: { number }, ys: { number }, zs: { number }): { number }
		return { xs[1], xs[2], ys[1], ys[2], zs[1], zs[2] }
	end
	local all = { -hl, hl }

	solid(court, `Bench_{tag}`, box(all, { 0, G.BENCH_HEIGHT }, z(G.BENCH_INNER_Z, G.TALUD_OUTER_Z)), STUCCO, Concrete)
	local wedge = Instance.new("WedgePart")
	wedge.Name = `Talud_{tag}`
	wedge.Anchored = true
	local run = G.TALUD_RUN
	local rise = G.TALUD_TOP_Y - G.BENCH_HEIGHT
	wedge.Size = Vector3.new(2 * hl, rise, run)
	-- La cuña sube hacia su +Z: en el lado negativo se gira media vuelta.
	wedge.CFrame = CFrame.new(CENTER)
		* CFrame.new(0, G.BENCH_HEIGHT + rise / 2, zSign * (G.BENCH_OUTER_Z + run / 2))
		* CFrame.Angles(0, if zSign < 0 then math.pi else 0, 0)
	wedge.Color = STUCCO
	wedge.Material = Concrete
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = court
	solid(
		court,
		`Wall_{tag}`,
		box(all, { G.TALUD_TOP_Y, G.WALL_TOP_Y }, z(G.TALUD_OUTER_Z, WALL_BACK_Z)),
		STUCCO,
		Concrete
	)
	-- El macizo bajo el paramento: sin él, donde el muro termina en la cabecera se ve el hueco por dentro.
	solid(court, `Core_{tag}`, box(all, { 0, G.TALUD_TOP_Y }, z(G.TALUD_OUTER_Z, WALL_BACK_Z)), STUCCO, Concrete)
	-- Cornisa: la plaza superior que sigue al paramento.
	solid(court, `Plaza_{tag}`, box(all, { PLAZA_Y1, G.WALL_TOP_Y }, z(WALL_BACK_Z, G.PLAZA_HALF_Z)), PLAZA, Limestone)
	deco(
		art,
		`Moldura_{tag}`,
		box(all, { G.WALL_TOP_Y, G.WALL_TOP_Y + 0.6 }, z(G.TALUD_OUTER_Z, G.TALUD_OUTER_Z + 0.8)),
		LIMESTONE_DARK,
		Limestone
	)

	-- Cada mitad (X negativa y X positiva) lleva el color de su cuadrante: banqueta, pie del talud y friso.
	for _, xSign in { -1, 1 } do
		local x1, x2 = if xSign < 0 then -hl else 0, if xSign < 0 then 0 else hl
		local xs = { x1, x2 }
		local color = quadrantColor(xSign, zSign)
		local name = `{tag}_{if xSign < 0 then "Jaguar" else "Quetzal"}`
		deco(
			art,
			`BenchTop_{name}`,
			box(xs, { G.BENCH_HEIGHT, G.BENCH_HEIGHT + 0.06 }, z(G.BENCH_INNER_Z, G.BENCH_OUTER_Z)),
			color,
			Paint
		)
		deco(
			art,
			`BenchFront_{name}`,
			box(xs, { 0, G.BENCH_HEIGHT }, z(G.BENCH_INNER_Z - 0.06, G.BENCH_INNER_Z)),
			color,
			Paint
		)
		slopeStrip(art, `TaludBand_{name}`, zSign, x1, x2, 0, 0.22, color)
		local face = G.TALUD_OUTER_Z
		deco(art, `Friso_{name}`, box(xs, { 27.5, 29.5 }, z(face - 0.3, face)), color, Paint)
		-- Grecas: escalones de cal sobre la banda, cada 5 studs.
		local x = x1 + 2.5
		while x < x2 - 1 do
			deco(art, "Greca", box({ x - 1, x + 1 }, { 28.1, 28.9 }, z(face - 0.5, face - 0.3)), STUCCO, Paint)
			x += 5
		end
	end
end

-- Emblema sobre el muro del fondo: un sol (con rayos en diagonal) o una cruz (sin ellos).
local function emblem(art: Folder, tag: string, face: number, sign: number, a: Color3, b: Color3, diagonals: boolean)
	local cy = 13
	local function onWall(depth: number, y1: number, y2: number, z1: number, z2: number): { number }
		return { face - sign * depth, face, y1, y2, z1, z2 }
	end
	deco(art, `Emblem_{tag}`, onWall(0.35, cy - 3.5, cy + 3.5, -3.5, 3.5), a, Paint)
	deco(art, `Emblem_{tag}`, onWall(0.6, cy - 1.5, cy + 1.5, -1.5, 1.5), b, Paint)
	deco(art, `Emblem_{tag}`, onWall(0.35, cy + 3.5, cy + 6.5, -0.7, 0.7), b, Paint)
	deco(art, `Emblem_{tag}`, onWall(0.35, cy - 6.5, cy - 3.5, -0.7, 0.7), b, Paint)
	deco(art, `Emblem_{tag}`, onWall(0.35, cy - 0.7, cy + 0.7, 3.5, 6.5), b, Paint)
	deco(art, `Emblem_{tag}`, onWall(0.35, cy - 0.7, cy + 0.7, -6.5, -3.5), b, Paint)
	if diagonals then
		for _, dy in { -1, 1 } do
			for _, dz in { -1, 1 } do
				deco(art, `Emblem_{tag}`, onWall(0.35, cy + dy * 4.2, cy + dy * 6, dz * 4.2, dz * 6), a, Paint)
			end
		end
	end
end

-- Una cabecera: la sala del fondo de cada equipo. Jaguar (X negativa): rojo y amarillo, el Sol, el día.
-- Quetzal (X positiva): jade y negro, el inframundo y la fertilidad.
local function buildHeader(court: Folder, art: Folder, geo: CourtGeometry.Layout, teamId: string, sign: number)
	local G = CourtGeometry
	local hl = geo.halfLength
	local inner = hl + G.HEADER_DEPTH
	local half = G.HEADER_HALF_WIDTH
	local colorA = if sign < 0 then RED else JADE
	local colorB = if sign < 0 then YELLOW else BLACK
	local x0, x1, xo = sign * hl, sign * inner, sign * (inner + END_WALL_THICKNESS)

	solid(court, `EndFloor_{teamId}`, { x0, x1, -2, 0, -half, half }, colorA, Concrete)
	-- Franjas del suelo: dos a lo largo y una de través.
	for _, zSign in { -1, 1 } do
		deco(art, `FloorStripe_{teamId}`, { x0, x1, 0, 0.06, zSign * 8, zSign * 10 }, colorB, Paint)
	end
	deco(art, `FloorStripe_{teamId}`, { sign * (hl + 10), sign * (hl + 12), 0, 0.06, -half, half }, colorB, Paint)
	-- La línea de fondo (el «fuera») cruza el pasillo.
	deco(
		art,
		`EndLine_{teamId}`,
		{ sign * (hl - 0.6), x0, 0, 0.06, -G.ALLEY_HALF_WIDTH, G.ALLEY_HALF_WIDTH },
		STUCCO,
		Paint
	)

	-- Muro del fondo y muros de los lados (el paramento ya cierra el pasillo hasta x0).
	solid(
		court,
		`EndWall_{teamId}`,
		{ x1, xo, 0, G.WALL_TOP_Y, -(half + SIDE_WALL_THICKNESS), half + SIDE_WALL_THICKNESS },
		STUCCO,
		Concrete
	)
	for _, zSign in { -1, 1 } do
		local tag = sideName(zSign)
		solid(
			court,
			`HeaderWall_{teamId}_{tag}`,
			{ x0, x1, 0, G.WALL_TOP_Y, zSign * half, zSign * (half + SIDE_WALL_THICKNESS) },
			STUCCO,
			Concrete
		)
		solid(
			court,
			`Plaza_{teamId}_{tag}`,
			{ x0, xo, PLAZA_Y1, G.WALL_TOP_Y, zSign * (half + SIDE_WALL_THICKNESS), zSign * G.PLAZA_HALF_Z },
			PLAZA,
			Limestone
		)
		-- Friso de la cara de dentro del muro lateral.
		deco(art, `Friso_{teamId}`, { x0, x1, 26, 27.2, zSign * (half - 0.3), zSign * half }, colorB, Paint)
		deco(art, `Friso_{teamId}`, { x0, x1, 27.2, 28.4, zSign * (half - 0.3), zSign * half }, colorA, Paint)
	end
	-- Friso del muro del fondo, emblema y almenas.
	deco(art, `Friso_{teamId}`, { x1 - sign * 0.3, x1, 26, 27.2, -half, half }, colorB, Paint)
	deco(art, `Friso_{teamId}`, { x1 - sign * 0.3, x1, 27.2, 28.4, -half, half }, colorA, Paint)
	emblem(art, teamId, x1, sign, colorA, colorB, sign < 0)
	-- Cada 6 studs a lo ancho de la cabecera, sin pasarse del muro.
	for step = -math.floor(half / 6) + 1, math.floor(half / 6) - 1 do
		local z = step * 6
		deco(art, `Almena_{teamId}`, { x1, xo, G.WALL_TOP_Y, G.WALL_TOP_Y + 1.4, z - 1.2, z + 1.2 }, colorA, Paint)
	end
	-- Lo que sobra de plaza entre el fondo de esta cabecera y la plaza fija (formatos pequeños).
	local fixedStart = fixedPlazaStart()
	if math.abs(xo) < fixedStart - 0.01 then
		solid(
			court,
			`Plaza_{teamId}_End`,
			{ xo, sign * fixedStart, PLAZA_Y1, G.WALL_TOP_Y, -G.PLAZA_HALF_Z, G.PLAZA_HALF_Z },
			PLAZA,
			Limestone
		)
	end
end

-- Aro de piedra (tlachtemalácatl) en el paramento de un lado: doce bloques en círculo con el agujero a lo largo
-- de X, y a cada cara una serpiente de jade y rojo (la otra cara, con los colores cambiados y la cabeza al
-- otro lado, para que se distinga también por detrás).
local function buildRing(art: Folder, geo: CourtGeometry.Layout, zSign: number)
	local ring = geo.ring
	local model = Instance.new("Model")
	model.Name = `Ring_{sideName(zSign)}`
	local count = 12
	local step = 2 * math.pi / count
	local mid = (ring.innerRadius + ring.outerRadius) / 2
	local radial = ring.outerRadius - ring.innerRadius
	local tangent = 2 * mid * math.tan(math.pi / count) + 0.2
	local center = Vector3.new(ring.centerX, ring.centerY, zSign * ring.centerZ)
	local function around(theta: number, x: number, radius: number): CFrame
		return CFrame.new(center + Vector3.new(x, 0, 0)) * CFrame.Angles(theta, 0, 0) * CFrame.new(0, radius, 0)
	end
	for index = 0, count - 1 do
		make(
			model,
			"Piedra",
			around(index * step, 0, mid),
			Vector3.new(ring.thickness, radial, tangent),
			if index % 2 == 0 then STONE else STONE_DARK,
			Limestone,
			false
		)
	end
	for _, face in { -1, 1 } do
		local x = face * (ring.thickness / 2 + 0.25)
		local headAt = if face > 0 then 0 else math.pi
		local shift = if face > 0 then 0 else step / 2
		for index = 0, count - 1 do
			local theta = index * step + shift
			local isHead = math.abs(((theta - headAt + math.pi) % (2 * math.pi)) - math.pi) < step / 2 + 0.01
			if not isHead then
				local jade = (index + (if face > 0 then 0 else 1)) % 2 == 0
				make(
					model,
					"Serpiente",
					around(theta, x, mid),
					Vector3.new(0.5, 1.0, 1.0),
					if jade then JADE else RED,
					Paint,
					false
				)
			end
		end
		-- Cabeza: un bloque mayor con dos ojos amarillos.
		local headColor = if face > 0 then JADE else RED
		make(model, "Cabeza", around(headAt, x + face * 0.15, mid), Vector3.new(0.8, 1.6, 1.8), headColor, Paint, false)
		for _, eye in { -0.5, 0.5 } do
			make(
				model,
				"Ojo",
				around(headAt, x + face * 0.65, mid) * CFrame.new(0, 0.3, eye),
				Vector3.new(0.2, 0.4, 0.4),
				YELLOW,
				Paint,
				false
			)
		end
	end
	model.Parent = art
end

-- Línea central (tlécotl): banda negra con un filete de jade. Cruza el pasillo y sigue por los dos lados: sube
-- el escalón, cruza la banqueta y recorre el talud hasta el pie del paramento.
local function buildTlecotl(art: Folder)
	local G = CourtGeometry
	local model = Instance.new("Model")
	model.Name = "Tlecotl"
	local w = G.ALLEY_HALF_WIDTH
	local halfBand, halfFillet = G.TLECOTL_WIDTH / 2, G.TLECOTL_FILLET / 2
	deco(model, "Banda", { -halfBand, halfBand, 0, 0.1, -w, w }, BLACK, Paint)
	deco(model, "Filete", { -halfFillet, halfFillet, 0.1, 0.14, -w, w }, JADE, Paint)
	local h, inner, outer = G.BENCH_HEIGHT, G.BENCH_INNER_Z, G.BENCH_OUTER_Z
	for _, zSign in { -1, 1 } do
		local function z(a: number, b: number): { number }
			return { zSign * a, zSign * b }
		end
		local tag = sideName(zSign)
		-- Contrahuella del escalón (por delante del color del cuadrante, que va a 0,06 de la pared).
		deco(
			model,
			`BandaEscalon_{tag}`,
			{ -halfBand, halfBand, 0, h + 0.1, table.unpack(z(inner - 0.12, inner - 0.06)) },
			BLACK,
			Paint
		)
		deco(
			model,
			`FileteEscalon_{tag}`,
			{ -halfFillet, halfFillet, 0, h + 0.14, table.unpack(z(inner - 0.16, inner - 0.12)) },
			JADE,
			Paint
		)
		-- Banqueta (por encima del color del cuadrante, que sube 0,06).
		deco(
			model,
			`BandaBanqueta_{tag}`,
			{ -halfBand, halfBand, h + 0.06, h + 0.12, table.unpack(z(inner - 0.06, outer)) },
			BLACK,
			Paint
		)
		deco(
			model,
			`FileteBanqueta_{tag}`,
			{ -halfFillet, halfFillet, h + 0.12, h + 0.16, table.unpack(z(inner - 0.1, outer)) },
			JADE,
			Paint
		)
		-- Talud (por encima de la banda de color del pie, que lleva 0,14).
		slopeStrip(model, `BandaTalud_{tag}`, zSign, -halfBand, halfBand, 0, 1, BLACK, 0.16)
		slopeStrip(model, `FileteTalud_{tag}`, zSign, -halfFillet, halfFillet, 0, 1, JADE, 0.3)
	end
	model.Parent = art
end

-- Reconstruye Workspace.Cancha.Court para el formato (jugadores por equipo, 1 a 5).
function CourtBuilder.layout(format: number, force: boolean?)
	registerGroups()
	local root = Workspace:FindFirstChild(FOLDER_NAME)
	if not root or root:GetAttribute("Version") ~= VERSION then
		root = CourtBuilder.build(true)
		if not root then
			return
		end
	end
	local geo = CourtGeometry.forFormat(format)
	local old = root:FindFirstChild(COURT_NAME)
	if old and not force and root:GetAttribute("Format") == geo.format then
		return
	end

	local G = CourtGeometry
	local court = Instance.new("Folder")
	court.Name = COURT_NAME
	local art = Instance.new("Folder")
	art.Name = "Decor"
	local hl = geo.halfLength
	solid(court, "Floor", { -hl, hl, -2, 0, -G.ALLEY_HALF_WIDTH, G.ALLEY_HALF_WIDTH }, CREAM, Concrete)
	for _, zSign in { -1, 1 } do
		buildSide(court, art, geo, zSign)
		buildRing(art, geo, zSign)
	end
	buildHeader(court, art, geo, "Jaguar", -1)
	buildHeader(court, art, geo, "Quetzal", 1)
	buildTlecotl(art)
	CourtDecor.buildLayout(art, geo, decorKit)
	art.Parent = court

	-- Muro de equipo: solo para jugadores (la pelota es analítica y no lo ve).
	barrier(court, "TeamBarrier", { -0.5, 0.5, 0, G.TEAM_WALL_HEIGHT, -G.TALUD_OUTER_Z, G.TALUD_OUTER_Z })
	for teamId, spawn in geo.spawns do
		marker(
			court,
			`Spawn_{teamId}`,
			{ spawn.x - 5, spawn.x + 5, spawn.y - 0.5, spawn.y + 0.5, spawn.zMin, spawn.zMax }
		)
	end

	-- Cambio en el mismo fotograma: nadie ve la cancha a medias.
	if old then
		old:Destroy()
	end
	court.Parent = root
	root:SetAttribute("Format", geo.format)
end

-- ============================================================================ Lo estático

local function buildStatic(): Folder
	registerGroups()
	local G = CourtGeometry
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("Version", VERSION)
	local maxHalf = fixedPlazaStart()
	local top = G.WALL_TOP_Y
	local edgeZ = G.PLAZA_HALF_Z

	-- Losa de base bajo el suelo del patio: red de seguridad por si algo cae.
	solid(
		folder,
		"Base",
		{ -PLAZA_HALF_X - 6, PLAZA_HALF_X + 6, -8, -2, -edgeZ - 6, edgeZ + 6 },
		LIMESTONE_DARK,
		Limestone
	)
	-- Plaza fija de los dos extremos (lo que queda entre las cabeceras y el borde lo pone layout).
	for _, sign in { -1, 1 } do
		solid(
			folder,
			`Plaza_Fixed_{if sign < 0 then "Jaguar" else "Quetzal"}`,
			{ sign * maxHalf, sign * PLAZA_HALF_X, PLAZA_Y1, top, -edgeZ, edgeZ },
			PLAZA,
			Limestone
		)
		deco(
			folder,
			"Borde",
			{ sign * (PLAZA_HALF_X - 1.5), sign * PLAZA_HALF_X, top, top + 0.5, -edgeZ, edgeZ },
			LIMESTONE_DARK,
			Limestone
		)
		deco(
			folder,
			"Borde",
			{ -PLAZA_HALF_X, PLAZA_HALF_X, top, top + 0.5, sign * (edgeZ - 1.5), sign * edgeZ },
			LIMESTONE_DARK,
			Limestone
		)
		-- Desierto decorado más allá del borde, a la altura de la plaza (el patio se ve hundido).
		deco(folder, "Desierto", {
			sign * PLAZA_HALF_X,
			sign * (PLAZA_HALF_X + DESERT_REACH),
			DESERT_Y1,
			top - 0.1,
			-(edgeZ + DESERT_REACH),
			edgeZ + DESERT_REACH,
		}, SAND, Enum.Material.Sand)
		deco(
			folder,
			"Desierto",
			{ -PLAZA_HALF_X, PLAZA_HALF_X, DESERT_Y1, top - 0.1, sign * edgeZ, sign * (edgeZ + DESERT_REACH) },
			SAND,
			Enum.Material.Sand
		)
		-- Barandilla invisible del borde exterior de la plaza.
		barrier(
			folder,
			"Barandilla",
			{ sign * PLAZA_HALF_X, sign * (PLAZA_HALF_X + 2), top, top + RAIL_HEIGHT, -edgeZ - 2, edgeZ + 2 }
		)
		barrier(
			folder,
			"Barandilla",
			{ -PLAZA_HALF_X, PLAZA_HALF_X, top, top + RAIL_HEIGHT, sign * edgeZ, sign * (edgeZ + 2) }
		)
	end

	-- Templos, estandartes e ídolos (Fase 27d).
	CourtDecor.buildStatic(folder, decorKit)

	-- Donde esperan los que aún no tienen equipo. Part, no SpawnLocation: Roblox no la elige para aparecer solo.
	local w = G.WAITING
	solid(folder, "EsperaSpawn", { w.X - 5, w.X + 5, w.Y - 1, w.Y, w.Z - 5, w.Z + 5 }, STONE, Limestone)
	return folder
end

-- true si el place ya tiene la cancha de esta versión.
function CourtBuilder.isBuilt(): boolean
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	return folder ~= nil and folder:GetAttribute("Version") == VERSION and folder:FindFirstChild(COURT_NAME) ~= nil
end

-- Pasa de un punto local de la cancha al mundo.
function CourtBuilder.toWorld(position: Vector3): Vector3
	return CENTER + position
end

function CourtBuilder.build(force: boolean?): Folder?
	if not force and game.PlaceId ~= Config.PlaceIds.Dunas then
		warn(
			`[CourtBuilder] Este place ({game.PlaceId}) no es Dunas ({Config.PlaceIds.Dunas}). `
				.. "Abre Dunas o usa build(true)."
		)
		return nil
	end
	local old = Workspace:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
	local folder = buildStatic()
	folder.Parent = Workspace
	CourtBuilder.layout(CourtGeometry.MAX_FORMAT, true)

	local parts = 0
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
		end
	end
	if parts > Config.Budgets.Matches.CourtParts then
		warn(`[CourtBuilder] La cancha tiene {parts} piezas y el tope es {Config.Budgets.Matches.CourtParts}`)
	end
	print(`[CourtBuilder] ¡Cancha lista! ({parts} piezas con el formato 5v5)`)
	local before, after = CourtDecor.lastStatic, CourtDecor.lastLayout
	if before and after then
		print(
			`[CourtBuilder] Decorado: {before.before + after.before} piezas sin fusionar, `
				.. `{before.after + after.after} fusionadas`
		)
	end
	return folder
end

return CourtBuilder
