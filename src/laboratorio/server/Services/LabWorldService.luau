--!strict
-- El escenario del Laboratorio (World/LabBuilder): lo construye al arrancar si el place no lo tiene (o es
-- de otra versión), elige cuál de los mapas se juega (setMap; todos están construidos a la vez, cada uno en
-- su sitio: LabMap/<mapa>), abre y cierra las compuertas de las zonas de salida, cierra el paso del derrumbe
-- en los formatos pequeños, dice dónde aparece cada uno y si está en su zona de salida, y cuándo se ha
-- caído del mapa (fallY).
-- Las barreras de salida solo dejan salir: cada una choca solo con el bando rival (grupos de colisión de
-- LabBuilder; characterGroup es el del personaje de cada bando, que pone LabTeamService).
-- En Rondas, tras la tercera ronda las bases cambian de dueño (setSwapped): cada bando sigue siendo el
-- mismo, pero aparece en la base contraria (occupantBase), y las barreras y baldosas de cada base cambian de
-- grupo de colisión y de color al del nuevo ocupante. En Todos contra todos nadie tiene base: aparece en
-- los puntos de LabMap/<mapa>/SpawnsLibres (freeSpawnCFrame).

local Workspace = game:GetService("Workspace")

local Arena = require(game:GetService("ReplicatedStorage").Shared.Arena)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local LabBuilder = require(script.Parent.Parent.World.LabBuilder)

-- Separación al azar alrededor de la baldosa de aparición, para no aparecer unos encima de otros.
local SPAWN_SPREAD = 4
-- Lo mismo en los puntos libres: más corto, para no salirse de lo despejado alrededor de cada marcador.
local FREE_SPAWN_SPREAD = 2

local LabWorldService = {}

-- El mapa que se juega ahora (id de Config.Lab.Maps) y lo que se le ha pedido (setGates, setFormat,
-- setSwapped): setMap lo vuelve a aplicar al mapa nuevo.
local current: string = Config.Lab.StudioMap
local gatesOpen = false
local lastFormat: number? = nil
-- true si el derrumbe está cerrado (los formatos pequeños). Los mapas se construyen con él cerrado.
local collapseClosed = true
-- true mientras las bases están cambiadas (Rondas).
local swapped = false
-- Los últimos puntos libres elegidos y cuándo (os.clock): al empezar una partida todos aparecen a la vez,
-- y los personajes aún no están donde van a estar; así no se eligen dos veces seguidas el mismo punto.
local recentFreeSpawns: { { position: Vector3, at: number } } = {}
local RECENT_SECONDS = 3

-- El modelo del mapa que se juega (LabMap/<mapa>); espera a que exista (lo construye el Init de este
-- servicio).
local function mapFolder(): Model
	return (Workspace:WaitForChild(LabBuilder.NAME) :: Folder):WaitForChild(current) :: Model
end

-- El mapa que se juega ahora (id de Config.Lab.Maps).
function LabWorldService.currentMap(): string
	return current
end

-- El centro del mapa (su pivote: el suelo, en el centro de las dos bases).
function LabWorldService.center(): Vector3
	return mapFolder():GetPivot().Position
end

-- Por debajo de esta altura se ha caído del mapa (FallDepth studs bajo su suelo).
function LabWorldService.fallY(): number
	return LabWorldService.center().Y - (Config.Lab.FallDepth[current] or 30)
end

local function base(teamId: string): Model
	return (mapFolder():WaitForChild("Bases") :: Folder):WaitForChild(teamId) :: Model
end

-- La base (carpeta de LabMap/<mapa>/Bases) que ocupa el bando "teamId" ahora: la suya, o la contraria si han
-- cambiado de lado.
local function occupantBase(teamId: string): string
	return if swapped then Arena.otherTeam(teamId) else teamId
end

-- Grupo de colisión del personaje de cada bando (LabTeamService lo pone en todas sus piezas).
function LabWorldService.characterGroup(teamId: string): string
	return LabBuilder.characterGroup(teamId)
end

-- Abre (no se ve, no choca) o cierra las compuertas de las dos zonas de salida: cerradas antes de la
-- partida, para que nadie salga antes de tiempo.
function LabWorldService.setGates(open: boolean)
	gatesOpen = open
	for _, model in (mapFolder():WaitForChild("Bases") :: Folder):GetChildren() do
		for _, gate in model:GetChildren() do
			if gate.Name == "Gate" and gate:IsA("BasePart") then
				gate.Transparency = if open then 1 else 0.35
				gate.CanCollide = not open
			end
		end
	end
end

-- En 1v1 y 2v2 (hasta Config.Lab.CollapseUpToFormat) el paso del mapa se cierra con el derrumbe.
function LabWorldService.setFormat(format: number)
	lastFormat = format
	local closed = format <= Config.Lab.CollapseUpToFormat
	collapseClosed = closed
	local rubble = mapFolder():FindFirstChild("Derrumbes")
	if not rubble then
		return
	end
	for _, part in rubble:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = if closed then 0 else 1
			part.CanCollide = closed
			part.CanQuery = closed
		end
	end
end

-- Dónde aparece un jugador: en la baldosa de la zona de salida de su bando, mirando al centro.
function LabWorldService.spawnCFrame(teamId: string?): CFrame
	local spawn = base(occupantBase(teamId or Config.Lab.TeamOrder[1])):FindFirstChild("Spawn") :: BasePart
	local offset = Vector3.new((math.random() * 2 - 1) * SPAWN_SPREAD, 3.5, (math.random() * 2 - 1) * SPAWN_SPREAD)
	local position = spawn.Position + offset
	return CFrame.lookAt(position, Vector3.new(LabWorldService.center().X, position.Y, position.Z))
end

-- true si "position" está dentro de la zona de salida de "teamId".
function LabWorldService.inBase(teamId: string, position: Vector3): boolean
	local zone = base(occupantBase(teamId)):FindFirstChild("Zone") :: BasePart
	local localPoint = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

-- Delante de la zona de salida de "teamId", hacia el centro: donde van los muñecos del panel de pruebas.
function LabWorldService.frontOf(teamId: string): (Vector3, Vector3)
	local spawn = base(occupantBase(teamId)):FindFirstChild("Spawn") :: BasePart
	local towardCenter = Vector3.new(-math.sign(spawn.Position.X - LabWorldService.center().X), 0, 0)
	return spawn.Position, towardCenter
end

-- Cambia (o deshace) el cambio de lado: las barreras de cada base chocan con el rival de su ocupante y
-- toman su color; la baldosa de aparición, también el color.
function LabWorldService.setSwapped(on: boolean)
	swapped = on
	for _, model in (mapFolder():WaitForChild("Bases") :: Folder):GetChildren() do
		local occupant = occupantBase(model.Name)
		local color = Config.Lab.Teams[occupant].color
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Name == "Barrier" then
				part.CollisionGroup = LabBuilder.barrierGroup(occupant)
				part.Color = color
			elseif part:IsA("BasePart") and part.Name == "Spawn" then
				part.Color = color
			end
		end
	end
end

-- Dónde aparece quien no tiene bando (Todos contra todos): el punto de SpawnsLibres del mapa cuyo rival más
-- cercano está más lejos ("rivals" son las posiciones de los demás vivos), mirando al centro. Sin rivales,
-- uno al azar. Con el derrumbe cerrado se saltan los puntos "Closable".
function LabWorldService.freeSpawnCFrame(rivals: { Vector3 }): CFrame
	local folder = mapFolder():WaitForChild("SpawnsLibres")
	local nowClock = os.clock()
	local avoid = table.clone(rivals)
	for index = #recentFreeSpawns, 1, -1 do
		local recent = recentFreeSpawns[index]
		if nowClock - recent.at > RECENT_SECONDS then
			table.remove(recentFreeSpawns, index)
		else
			table.insert(avoid, recent.position)
		end
	end
	local best: BasePart? = nil
	local bestDistance = -1
	for _, marker in folder:GetChildren() do
		if marker:IsA("BasePart") and not (collapseClosed and marker:GetAttribute("Closable") == true) then
			local nearest = math.huge
			for _, position in avoid do
				nearest = math.min(nearest, (position - marker.Position).Magnitude)
			end
			if nearest == math.huge then
				nearest = math.random() * 100
			end
			if nearest > bestDistance then
				best = marker
				bestDistance = nearest
			end
		end
	end
	local anchor = best :: BasePart
	table.insert(recentFreeSpawns, { position = anchor.Position, at = nowClock })
	local offset =
		Vector3.new((math.random() * 2 - 1) * FREE_SPAWN_SPREAD, 0, (math.random() * 2 - 1) * FREE_SPAWN_SPREAD)
	-- La altura del marcador (a 0,1 sobre su suelo) más lo que falta para los pies del personaje.
	local position = Vector3.new(anchor.Position.X, anchor.Position.Y + 3.4, anchor.Position.Z) + offset
	local center = LabWorldService.center()
	return CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
end

-- Cambia el mapa que se juega: el atributo "Map" de LabMap (lo lee el cliente), su iluminación y lo que se
-- había pedido (compuertas, derrumbe, cambio de lado) aplicado al mapa nuevo. No recoloca a nadie: quien
-- llama hace respawnAll.
function LabWorldService.setMap(id: string)
	if not table.find(Config.Lab.Maps, id) then
		warn(`[LabWorldService] Mapa desconocido: {id}`)
		return
	end
	current = id
	Workspace:WaitForChild(LabBuilder.NAME):SetAttribute("Map", id)
	LabBuilder.applyLighting(id)
	table.clear(recentFreeSpawns)
	LabWorldService.setGates(gatesOpen)
	if lastFormat then
		LabWorldService.setFormat(lastFormat)
	end
	LabWorldService.setSwapped(swapped)
end

function LabWorldService:Init()
	LabBuilder.registerGroups()
	if not LabBuilder.isBuilt() then
		LabBuilder.build({ force = true })
	end
	LabWorldService.setMap(Config.Lab.StudioMap)
	LabWorldService.setGates(false)
end

return LabWorldService
