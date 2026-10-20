--!strict
-- Escenario de la arena de Dunas (captura la bandera). Versión de bloques (greybox): la forma y las
-- piezas que usa el código; el aspecto de ruinas mayas en el desierto llega después (docs/PLAN.md,
-- fase 8).
--
-- Lo construye solo el servidor de Dunas al arrancar si no existe Workspace.Arena o es de otra
-- versión (ArenaWorldService). Para dejarlo fijo en el place, ejecútalo en Studio, en modo edición,
-- desde la barra de comandos:
--
--   require(game.ServerScriptService.Server.World.ArenaBuilder).build()
--
-- Forma (de oeste a este, el eje X): la base Jaguar (x < 0), el carril central con la pirámide en
-- el centro y la base Quetzal (x > 0). A los dos lados del carril, separados por muros de ruinas,
-- dos pasillos laterales; en 1v1 y 2v2 se cierran (carpeta "SideWalls", ArenaWorldService).
-- Piezas con nombre que lee el código, en Arena/Bases/<equipo>:
--   "Spawn"      baldosa donde reaparecen los del equipo
--   "Gate"       puerta de la base: cerrada antes de la partida
--   "FlagStand"  pedestal de la bandera
--   "Zone"       volumen invisible de la base
-- y en Arena: "SideWalls" (muros que cierran los pasillos) y un SpawnLocation neutro en lo alto de la
-- pirámide, donde aparecen los que aún no han elegido equipo.
--
-- ⚠️ Borra la carpeta Workspace.Arena, la Baseplate y los SpawnLocation sueltos antes de construir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

export type Options = { force: boolean? }

local FOLDER_NAME = "Arena"
-- Sube este número al cambiar el escenario: los places con una versión anterior guardada se
-- reconstruyen solos al arrancar (ArenaWorldService).
local VERSION = 1

-- Medidas (studs). El suelo está en y = 0.
local HALF_LENGTH = 200 -- de la pared oeste a la este
local HALF_WIDTH = 100 -- de la pared sur a la norte
local BOUNDARY_HEIGHT = 40
local BASE_INNER_X = 150 -- la pared de la base que mira al centro
local BASE_HALF_WIDTH = 40
local BASE_FLOOR = 2 -- la base está un poco elevada
local BASE_WALL_HEIGHT = 26
local GATE_HALF_WIDTH = 8
local LANE_WALL_Z = 35 -- muros entre el carril central y los pasillos
local LANE_WALL_HEIGHT = 12
local LANE_WALL_GAP = 30 -- hueco del centro (|x| < esto) que conecta carril y pasillos
local LANE_WALL_END = 130 -- desde aquí hasta la base, otro hueco
local PYRAMID_STEP = 4
local PYRAMID_SIZES = { 36, 28, 20, 12 }

local SAND = Color3.fromRGB(226, 196, 138)
local SANDSTONE = Color3.fromRGB(198, 158, 108)
local DARK_STONE = Color3.fromRGB(140, 112, 84)

local ArenaBuilder = {}

local function block(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Sandstone
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Pieza que no se ve ni choca ni la encuentran los rayos (marcas para el código).
local function marker(part: BasePart)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- Bloque entre dos esquinas (x1, z1) y (x2, z2), de "height" de alto desde "bottom".
local function between(
	name: string,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	bottom: number,
	height: number,
	color: Color3,
	parent: Instance
): Part
	local size = Vector3.new(math.abs(x2 - x1), height, math.abs(z2 - z1))
	local center = Vector3.new((x1 + x2) / 2, bottom + height / 2, (z1 + z2) / 2)
	return block(name, size, CFrame.new(center), color, nil, parent)
end

local function buildGround(folder: Folder)
	local ground = block(
		"Suelo",
		Vector3.new(HALF_LENGTH * 2 + 40, 4, HALF_WIDTH * 2 + 40),
		CFrame.new(0, -2, 0),
		SAND,
		Enum.Material.Sand,
		folder
	)
	ground.Locked = true
	local walls = Instance.new("Folder")
	walls.Name = "Limites"
	local thickness = 6
	between(
		"Norte",
		-HALF_LENGTH - thickness,
		HALF_WIDTH,
		HALF_LENGTH + thickness,
		HALF_WIDTH + thickness,
		0,
		BOUNDARY_HEIGHT,
		DARK_STONE,
		walls
	)
	between(
		"Sur",
		-HALF_LENGTH - thickness,
		-HALF_WIDTH - thickness,
		HALF_LENGTH + thickness,
		-HALF_WIDTH,
		0,
		BOUNDARY_HEIGHT,
		DARK_STONE,
		walls
	)
	between(
		"Oeste",
		-HALF_LENGTH - thickness,
		-HALF_WIDTH,
		-HALF_LENGTH,
		HALF_WIDTH,
		0,
		BOUNDARY_HEIGHT,
		DARK_STONE,
		walls
	)
	between(
		"Este",
		HALF_LENGTH,
		-HALF_WIDTH,
		HALF_LENGTH + thickness,
		HALF_WIDTH,
		0,
		BOUNDARY_HEIGHT,
		DARK_STONE,
		walls
	)
	walls.Parent = folder
end

-- Base de un equipo: patio elevado con muros, puerta hacia el centro, baldosa de aparición y pedestal
-- de la bandera. "side": -1 al oeste (Jaguar), 1 al este (Quetzal).
local function buildBase(bases: Folder, teamId: string, side: number)
	local team = Config.Arena.Teams[teamId]
	local model = Instance.new("Model")
	model.Name = teamId
	model:SetAttribute("Team", teamId)
	local inner = side * BASE_INNER_X
	local outer = side * HALF_LENGTH
	local depth = HALF_LENGTH - BASE_INNER_X
	local centerX = (inner + outer) / 2

	-- Suelo elevado con rampa hacia el carril.
	between("Patio", inner, -BASE_HALF_WIDTH, outer, BASE_HALF_WIDTH, 0, BASE_FLOOR, SANDSTONE, model)
	local ramp = block(
		"Rampa",
		Vector3.new(10, 1, GATE_HALF_WIDTH * 2),
		CFrame.new(inner - side * 4.6, BASE_FLOOR / 2 - 0.1, 0) * CFrame.Angles(0, 0, side * math.rad(12)),
		SANDSTONE,
		nil,
		model
	)
	ramp.Material = Enum.Material.Sandstone

	-- Muros: el que mira al centro (con el hueco de la puerta) y los de los lados.
	local top = BASE_FLOOR + BASE_WALL_HEIGHT
	local wallThickness = 4
	local wallX1 = inner - side * wallThickness / 2
	local wallX2 = inner + side * wallThickness / 2
	between("MuroNorte", wallX1, GATE_HALF_WIDTH, wallX2, BASE_HALF_WIDTH, 0, top, SANDSTONE, model)
	between("MuroSur", wallX1, -BASE_HALF_WIDTH, wallX2, -GATE_HALF_WIDTH, 0, top, SANDSTONE, model)
	between("Dintel", wallX1, -GATE_HALF_WIDTH, wallX2, GATE_HALF_WIDTH, top - 4, 4, SANDSTONE, model)
	between("LadoNorte", inner, BASE_HALF_WIDTH, outer, BASE_HALF_WIDTH + wallThickness, 0, top, SANDSTONE, model)
	between("LadoSur", inner, -BASE_HALF_WIDTH - wallThickness, outer, -BASE_HALF_WIDTH, 0, top, SANDSTONE, model)
	-- Franja del color del equipo en lo alto del muro de la puerta, para saber de quién es la base.
	local stripe = between(
		"Franja",
		wallX1 - side * 0.2,
		-BASE_HALF_WIDTH,
		wallX2 + side * 0.2,
		BASE_HALF_WIDTH,
		top - 7,
		2.5,
		team.color,
		model
	)
	stripe.Material = Enum.Material.SmoothPlastic

	-- Puerta: cerrada (se ve y choca) hasta que empieza la partida (ArenaWorldService.setGates).
	local gate = between(
		"Gate",
		inner - side * 1,
		-GATE_HALF_WIDTH,
		inner + side * 1,
		GATE_HALF_WIDTH,
		BASE_FLOOR,
		top - 4 - BASE_FLOOR,
		team.color,
		model
	)
	gate.Material = Enum.Material.ForceField

	-- Baldosa de aparición, al fondo del patio.
	local spawn = block(
		"Spawn",
		Vector3.new(10, 0.2, 10),
		CFrame.new(outer - side * 12, BASE_FLOOR + 0.1, 0),
		team.color,
		Enum.Material.SmoothPlastic,
		model
	)
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false

	-- Pedestal de la bandera, en medio del patio.
	local stand =
		block("FlagStand", Vector3.new(5, 1.5, 5), CFrame.new(centerX, BASE_FLOOR + 0.75, 0), DARK_STONE, nil, model)
	stand:SetAttribute("Team", teamId)

	-- Volumen de la base (para saber quién está dentro).
	local zone = block(
		"Zone",
		Vector3.new(depth, 30, BASE_HALF_WIDTH * 2),
		CFrame.new(centerX, BASE_FLOOR + 15, 0),
		team.color,
		nil,
		model
	)
	marker(zone)

	model.PrimaryPart = spawn
	model.Parent = bases
end

-- Pirámide escalonada del centro; en lo alto, el punto de aparición neutro.
local function buildPyramid(folder: Folder)
	local pyramid = Instance.new("Model")
	pyramid.Name = "Piramide"
	for index, size in PYRAMID_SIZES do
		block(
			`Escalon{index}`,
			Vector3.new(size, PYRAMID_STEP, size),
			CFrame.new(0, (index - 0.5) * PYRAMID_STEP, 0),
			if index % 2 == 0 then SANDSTONE else DARK_STONE,
			nil,
			pyramid
		)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "EsperaSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, #PYRAMID_SIZES * PYRAMID_STEP + 0.5, 0)
	spawn.Color = SANDSTONE
	spawn.Material = Enum.Material.Sandstone
	spawn.TopSurface = Enum.SurfaceType.Smooth
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = pyramid
	pyramid.Parent = folder
end

-- Muros de ruinas entre el carril y los pasillos, y los que cierran los pasillos en 1v1 y 2v2.
local function buildLanes(folder: Folder)
	local ruins = Instance.new("Folder")
	ruins.Name = "Ruinas"
	local closers = Instance.new("Folder")
	closers.Name = "SideWalls"
	for _, z in { -LANE_WALL_Z, LANE_WALL_Z } do
		local z1, z2 = z - 2, z + 2
		for _, side in { -1, 1 } do
			between(
				"MuroCarril",
				side * LANE_WALL_GAP,
				z1,
				side * LANE_WALL_END,
				z2,
				0,
				LANE_WALL_HEIGHT,
				SANDSTONE,
				ruins
			)
			-- Cierres: el hueco de la base y la mitad del hueco del centro.
			between(
				"CierreBase",
				side * LANE_WALL_END,
				z1,
				side * BASE_INNER_X,
				z2,
				0,
				LANE_WALL_HEIGHT,
				DARK_STONE,
				closers
			)
			between("CierreCentro", 0, z1, side * LANE_WALL_GAP, z2, 0, LANE_WALL_HEIGHT, DARK_STONE, closers)
		end
	end
	-- Coberturas del carril central: muretes y columnas, simétricos.
	for _, side in { -1, 1 } do
		between("Murete", side * 78, -10, side * 82, 10, 0, 4, DARK_STONE, ruins)
		for _, spot in { Vector2.new(58, 18), Vector2.new(58, -18), Vector2.new(108, 14), Vector2.new(108, -14) } do
			block("Columna", Vector3.new(4, 14, 4), CFrame.new(side * spot.X, 7, spot.Y), SANDSTONE, nil, ruins)
		end
		-- Pasillos laterales: obeliscos y bloques caídos.
		for _, z in { -1, 1 } do
			for _, spot in { Vector2.new(40, 70), Vector2.new(95, 60), Vector2.new(120, 82) } do
				block(
					"Obelisco",
					Vector3.new(5, 18, 5),
					CFrame.new(side * spot.X, 9, z * spot.Y),
					DARK_STONE,
					nil,
					ruins
				)
			end
			block(
				"BloqueCaido",
				Vector3.new(12, 5, 7),
				CFrame.new(side * 66, 2.5, z * 78) * CFrame.Angles(0, math.rad(25 * side * z), 0),
				SANDSTONE,
				nil,
				ruins
			)
		end
	end
	ruins.Parent = folder
	closers.Parent = folder
end

local function clearOld()
	local old = Workspace:FindFirstChild(FOLDER_NAME)
	if old then
		old:Destroy()
	end
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

-- true si el place ya tiene el escenario de esta versión.
function ArenaBuilder.isBuilt(): boolean
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	return folder ~= nil and folder:GetAttribute("Version") == VERSION
end

function ArenaBuilder.build(options: Options?)
	local force = options and options.force
	if not force and game.PlaceId ~= Config.PlaceIds.Dunas then
		warn(
			`[ArenaBuilder] Este place ({game.PlaceId}) no es Dunas ({Config.PlaceIds.Dunas}). `
				.. "Abre Dunas o usa build({ force = true })."
		)
		return
	end
	clearOld()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("Version", VERSION)
	buildGround(folder)
	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	buildBase(bases, "Jaguar", -1)
	buildBase(bases, "Quetzal", 1)
	bases.Parent = folder
	buildPyramid(folder)
	buildLanes(folder)
	folder.Parent = Workspace
	print("[ArenaBuilder] ¡Arena lista!")
end

return ArenaBuilder
