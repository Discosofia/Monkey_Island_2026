--!strict
-- Dirección en la que apunta el jugador. Con ratón: hacia el punto del mundo bajo el cursor.
-- Sin ratón (móvil, mando): hacia donde mira la cámara; el servidor ayuda a apuntar.

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AIM_DISTANCE = 500

local Aim = {}

function Aim.direction(character: Model): Vector3
	local camera = Workspace.CurrentCamera
	if UserInputService.MouseEnabled then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_DISTANCE, params)
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
