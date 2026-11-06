--!strict
-- Escenario de la arena (World/ArenaBuilder): lo construye al arrancar si el place no lo tiene (o es
-- de otra versión), abre y cierra las puertas de las bases, cierra los pasillos laterales en los
-- formatos pequeños y dice dónde aparece cada jugador.

local Workspace = game:GetService("Workspace")

local ArenaBuilder = require(script.Parent.Parent.World.ArenaBuilder)
local CourtBuilder = require(script.Parent.Parent.World.CourtBuilder)

-- El modo del Juego de pelota (Config.Arena.ModeNames): su mapa es Workspace.Cancha.
local BALLGAME = "Ballgame"
-- El modo en curso (ArenaMatchService.setMode). Fuera del Juego de pelota nada cambia respecto a la bandera.
local currentMode: string? = nil

-- Hasta qué formato (jugadores por equipo) se cierran los pasillos laterales.
local SIDE_CORRIDORS_CLOSED_UP_TO = 2
-- Separación al azar alrededor de la baldosa de aparición, para no aparecer unos encima de otros.
local SPAWN_SPREAD = 4

local ArenaWorldService = {}

-- La carpeta del escenario; espera a que exista (la construye el Init de este servicio).
local function arenaFolder(): Folder
	return Workspace:WaitForChild("Arena") :: Folder
end

local function base(teamId: string): Model
	return (arenaFolder():WaitForChild("Bases") :: Folder):WaitForChild(teamId) :: Model
end

function ArenaWorldService.base(teamId: string): Model
	return base(teamId)
end

-- Abre (no se ve, no choca, el Parpadeo pasa) o cierra las puertas de las dos bases.
function ArenaWorldService.setGates(open: boolean)
	if currentMode == BALLGAME then
		return -- la cancha no tiene puertas
	end
	for _, model in (arenaFolder():WaitForChild("Bases") :: Folder):GetChildren() do
		local gate = model:FindFirstChild("Gate")
		if gate and gate:IsA("BasePart") then
			gate.Transparency = if open then 1 else 0.15
			gate.CanCollide = not open
			gate.CanQuery = not open
		end
	end
end

-- En 1v1 y 2v2 solo se juega en el carril central: los pasillos laterales se cierran.
function ArenaWorldService.setFormat(format: number)
	if currentMode == BALLGAME then
		CourtBuilder.layout(format) -- la cancha cambia de largo con el formato
		return
	end
	local closers = arenaFolder():FindFirstChild("SideWalls")
	if not closers then
		return
	end
	local closed = format <= SIDE_CORRIDORS_CLOSED_UP_TO
	for _, wall in closers:GetChildren() do
		if wall:IsA("BasePart") then
			wall.Transparency = if closed then 0 else 1
			wall.CanCollide = closed
			wall.CanQuery = closed
		end
	end
end

function ArenaWorldService.setMode(mode: string)
	currentMode = mode
end

function ArenaWorldService.mode(): string?
	return currentMode
end

-- Dónde aparece un jugador: en la baldosa de su base o, sin equipo, en lo alto de la pirámide. En el Juego de
-- pelota, en el volumen de su equipo en la cancha (mirando al centro) o, sin equipo, en la plaza superior.
function ArenaWorldService.spawnCFrame(teamId: string?): CFrame
	if currentMode == BALLGAME then
		local cancha = Workspace:WaitForChild(CourtBuilder.FOLDER_NAME)
		if teamId then
			local zone = (cancha:WaitForChild("Court") :: Folder):WaitForChild(`Spawn_{teamId}`) :: BasePart
			local half = zone.Size / 2
			local offset = Vector3.new((math.random() * 2 - 1) * (half.X - 1), 3, (math.random() * 2 - 1) * half.Z)
			local position = zone.Position + offset
			return CFrame.lookAt(position, Vector3.new(CourtBuilder.CENTER.X, position.Y, position.Z))
		end
		return (cancha:WaitForChild("EsperaSpawn") :: BasePart).CFrame + Vector3.new(0, 3.5, 0)
	end
	if teamId then
		local spawn = base(teamId):FindFirstChild("Spawn") :: BasePart
		local offset = Vector3.new((math.random() * 2 - 1) * SPAWN_SPREAD, 3.5, (math.random() * 2 - 1) * SPAWN_SPREAD)
		-- Mirando hacia el centro de la arena.
		local position = spawn.Position + offset
		return CFrame.lookAt(position, Vector3.new(0, position.Y, position.Z))
	end
	local neutral = arenaFolder():FindFirstChild("EsperaSpawn", true) :: BasePart
	return neutral.CFrame + Vector3.new(0, 3.5, 0)
end

-- true si "position" está dentro de la base de "teamId".
function ArenaWorldService.inBase(teamId: string, position: Vector3): boolean
	local zone = base(teamId):FindFirstChild("Zone") :: BasePart
	local localPoint = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

function ArenaWorldService:Init()
	if not ArenaBuilder.isBuilt() then
		ArenaBuilder.build({ force = true })
	end
	if not CourtBuilder.isBuilt() then
		CourtBuilder.build(true)
	end
	ArenaWorldService.setGates(false)
end

return ArenaWorldService
