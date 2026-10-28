--!strict
-- El escenario del Laboratorio (World/LabBuilder): lo construye al arrancar si el place no lo tiene (o es
-- de otra versión), abre y cierra las compuertas de las zonas de salida, cierra el invernadero con el
-- derrumbe en los formatos pequeños, dice dónde aparece cada uno y si está en su zona de salida.
-- Las barreras de salida solo dejan salir: cada una choca solo con el bando rival (grupos de colisión de
-- LabBuilder; characterGroup es el del personaje de cada bando, que pone LabTeamService).

local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local LabBuilder = require(script.Parent.Parent.World.LabBuilder)

-- Separación al azar alrededor de la baldosa de aparición, para no aparecer unos encima de otros.
local SPAWN_SPREAD = 4

local LabWorldService = {}

-- La carpeta del mapa; espera a que exista (la construye el Init de este servicio).
local function mapFolder(): Folder
	return Workspace:WaitForChild(LabBuilder.NAME) :: Folder
end

local function base(teamId: string): Model
	return (mapFolder():WaitForChild("Bases") :: Folder):WaitForChild(teamId) :: Model
end

-- Grupo de colisión del personaje de cada bando (LabTeamService lo pone en todas sus piezas).
function LabWorldService.characterGroup(teamId: string): string
	return LabBuilder.characterGroup(teamId)
end

-- Abre (no se ve, no choca) o cierra las compuertas de las dos zonas de salida: cerradas antes de la
-- partida, para que nadie salga antes de tiempo.
function LabWorldService.setGates(open: boolean)
	for _, model in (mapFolder():WaitForChild("Bases") :: Folder):GetChildren() do
		for _, gate in model:GetChildren() do
			if gate.Name == "Gate" and gate:IsA("BasePart") then
				gate.Transparency = if open then 1 else 0.35
				gate.CanCollide = not open
			end
		end
	end
end

-- En 1v1 y 2v2 (hasta Config.Lab.CollapseUpToFormat) el invernadero se cierra con el derrumbe.
function LabWorldService.setFormat(format: number)
	local rubble = mapFolder():FindFirstChild("Derrumbes")
	if not rubble then
		return
	end
	local closed = format <= Config.Lab.CollapseUpToFormat
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
	local spawn = base(teamId or Config.Lab.TeamOrder[1]):FindFirstChild("Spawn") :: BasePart
	local offset = Vector3.new((math.random() * 2 - 1) * SPAWN_SPREAD, 3.5, (math.random() * 2 - 1) * SPAWN_SPREAD)
	local position = spawn.Position + offset
	return CFrame.lookAt(position, Vector3.new(0, position.Y, position.Z))
end

-- true si "position" está dentro de la zona de salida de "teamId".
function LabWorldService.inBase(teamId: string, position: Vector3): boolean
	local zone = base(teamId):FindFirstChild("Zone") :: BasePart
	local localPoint = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

-- Delante de la zona de salida de "teamId", hacia el centro: donde van los muñecos del panel de pruebas.
function LabWorldService.frontOf(teamId: string): (Vector3, Vector3)
	local spawn = base(teamId):FindFirstChild("Spawn") :: BasePart
	local towardCenter = Vector3.new(-math.sign(spawn.Position.X), 0, 0)
	return spawn.Position, towardCenter
end

function LabWorldService:Init()
	LabBuilder.registerGroups()
	if not LabBuilder.isBuilt() then
		LabBuilder.build({ force = true })
	end
	LabWorldService.setGates(false)
end

return LabWorldService
