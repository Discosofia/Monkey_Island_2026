--!strict
-- Muñeco de calibración del campo de tiro del Lobby (Fase 24d, World/RangeBuilder). Un solo muñeco
-- (Workspace.CampoDeTiro.Munecos.MuniecoCalibracion, en el eje central) que sirve para medir los proyectiles a
-- una distancia elegida de la línea de tiro. Es combatiente (lo prepara RangeTargetService: vida enorme que se
-- rellena) pero sin el atributo RangeTarget, así que la ayuda de puntería del táctil sí puede engancharlo y se
-- mide también el autoaim. El estado (distancia de Config.Range.Calibration.Distances; quieto, o de lado a lado
-- ±MoveAmplitude a MoveSpeed rad/s) es del campo y lo comparten todos los jugadores: lo cambia el panel de
-- calibración por Remotes.RangeCalibrationControl, que valida RangeCalibrationService y llega aquí por setDistance
-- y setMoving. Se publica como atributos del muñeco (CalibrationDistance, CalibrationMoving).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local SETTINGS = Config.Range.Calibration

local RangeCalibrationDummyService = {}

local dummy: Model? = nil
local basePivot = CFrame.identity
local builtDistance = SETTINGS.Distances[SETTINGS.DefaultIndex]
local distance = builtDistance
local moving = false
local dirty = true

local function centerOffset(studs: number): number
	return SETTINGS.CenterOffsets[studs] or 0
end

-- Publica el estado como atributos del muñeco (lo lee el panel de RangeCalibrationController).
local function publish()
	if dummy then
		dummy:SetAttribute("CalibrationDistance", distance)
		dummy:SetAttribute("CalibrationMoving", moving)
	end
end

-- Pone la distancia del muñeco a la línea de tiro; solo vale una de Config.Range.Calibration.Distances.
function RangeCalibrationDummyService.setDistance(studs: number)
	if table.find(SETTINGS.Distances, studs) then
		distance = studs
		dirty = true
		publish()
	end
end

function RangeCalibrationDummyService.setMoving(value: boolean)
	moving = value
	dirty = true
	publish()
end

-- Pone el muñeco en su sitio: la distancia elegida, y el vaivén si se mueve.
local function place(now: number)
	local model = dummy
	if not model then
		return
	end
	local sway = if moving then SETTINGS.MoveAmplitude * math.sin(now * SETTINGS.MoveSpeed) else 0
	local offset = Vector3.new(centerOffset(distance) - centerOffset(builtDistance) + sway, 0, builtDistance - distance)
	model:PivotTo(basePivot + offset)
end

function RangeCalibrationDummyService:Start()
	local range = Workspace:WaitForChild("CampoDeTiro", 30)
	local dummies = if range then range:WaitForChild("Munecos", 30) else nil
	local found = if dummies then dummies:WaitForChild("MuniecoCalibracion", 30) else nil
	if not (found and found:IsA("Model") and found.PrimaryPart) then
		warn("[RangeCalibrationDummyService] No hay Workspace.CampoDeTiro.Munecos.MuniecoCalibracion")
		return
	end
	dummy = found
	basePivot = found:GetPivot()
	publish()
	RunService.Heartbeat:Connect(function()
		if moving or dirty then
			dirty = false
			place(Workspace:GetServerTimeNow())
		end
	end)
end

return RangeCalibrationDummyService
