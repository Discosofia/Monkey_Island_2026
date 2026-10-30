--!strict
-- Dirección en la que apunta el jugador. Con ratón: hacia el punto del mundo bajo el cursor.
-- Sin ratón (móvil, mando): hacia donde mira la cámara; el servidor ayuda a apuntar.
-- Aim.point: el punto del mundo al que apunta (bajo el cursor, o en el centro de la cámara): el cañón
-- de suero del Laboratorio cae ahí aunque haya una cobertura en medio.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local AIM_DISTANCE = 500
-- A esta distancia o menos de la cabeza, la cámara cuenta como primera persona.
local FIRST_PERSON_STUDS = 3

local Aim = {}

-- Rayo de puntería: como los disparos del servidor, en el grupo Config.ShotCollisionGroup (así cruza los
-- muros invisibles del Laboratorio). El servidor registra el grupo y replica: si aún no está, sin grupo.
local function aimParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	if PhysicsService:IsCollisionGroupRegistered(Config.ShotCollisionGroup) then
		params.CollisionGroup = Config.ShotCollisionGroup
	end
	return params
end

-- Dónde está el cursor en la pantalla. Con el ratón bloqueado en el centro (primera persona del
-- Laboratorio, bloqueo de cámara), el centro: GetMouseLocation puede dar otra cosa (en Studio, la
-- posición real del ratón aunque la cámara lo tenga bloqueado).
local function cursor(camera: Camera): Vector2
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return camera.ViewportSize / 2
	end
	return UserInputService:GetMouseLocation()
end

local function cameraRay(): Ray
	local camera = Workspace.CurrentCamera
	if UserInputService.MouseEnabled then
		local mouse = cursor(camera)
		return camera:ViewportPointToRay(mouse.X, mouse.Y)
	end
	return Ray.new(camera.CFrame.Position, camera.CFrame.LookVector)
end

function Aim.point(character: Model): Vector3
	local ray = cameraRay()
	local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, aimParams(character))
	return if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE
end

-- De dónde sale el disparo (Fase 15, V7): la cámara si está pegada a la cabeza (primera persona, a
-- FIRST_PERSON_STUDS o menos) y, si no, la cabeza. El servidor la acepta si está cerca de la cabeza.
function Aim.origin(character: Model): Vector3
	local camera = Workspace.CurrentCamera
	local head = character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return camera.CFrame.Position
	end
	if (camera.CFrame.Position - head.Position).Magnitude <= FIRST_PERSON_STUDS then
		return camera.CFrame.Position
	end
	return head.Position
end

function Aim.direction(character: Model): Vector3
	-- Con ratón, desde el cursor; en táctil y mando, desde el centro de la cámara. En los dos casos, hacia el
	-- punto al que se apunta y desde donde sale el disparo: con la cámara al hombro (Fase 19, W7) la línea de
	-- la vista no pasa por la cabeza, y sin esto el tiro saldría paralelo y fallaría de cerca.
	local direction = Aim.point(character) - Aim.origin(character)
	if direction.Magnitude > 0.1 then
		return direction.Unit
	end
	return Workspace.CurrentCamera.CFrame.LookVector
end

return Aim
