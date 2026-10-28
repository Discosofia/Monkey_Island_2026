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

function Aim.direction(character: Model): Vector3
	local camera = Workspace.CurrentCamera
	if UserInputService.MouseEnabled then
		local mouse = cursor(camera)
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, aimParams(character))
		local target = if result then result.Position else ray.Origin + ray.Direction * AIM_DISTANCE
		local head = character:FindFirstChild("Head")
		local origin = if head and head:IsA("BasePart") then head.Position else camera.CFrame.Position
		local direction = target - origin
		if direction.Magnitude > 0.1 then
			return direction.Unit
		end
	end
	return camera.CFrame.LookVector
end

return Aim
