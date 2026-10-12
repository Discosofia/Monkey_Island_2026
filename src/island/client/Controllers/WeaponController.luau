--!strict
-- Al usar un arma (clic en PC, tocar la pantalla en móvil, gatillo en mando) envía al servidor
-- hacia dónde apunta el jugador. El servidor decide si el ataque vale y a quién golpea.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AIM_DISTANCE = 500

local WeaponController = {}

local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Con ratón: hacia el punto del mundo bajo el cursor. Sin ratón (móvil, mando): hacia donde
-- mira la cámara; el servidor ayuda a apuntar.
local function aimDirection(character: Model): Vector3
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

local function hook(instance: Instance)
	if not instance:IsA("Tool") or hooked[instance] or instance:GetAttribute("WeaponId") == nil then
		return
	end
	hooked[instance] = true
	instance.Activated:Connect(function()
		local character = Players.LocalPlayer.Character
		if character then
			Remotes.UseWeapon:FireServer(aimDirection(character))
		end
	end)
end

local function watch(container: Instance)
	for _, child in container:GetChildren() do
		hook(child)
	end
	container.ChildAdded:Connect(hook)
end

local function onCharacter(character: Model)
	watch(character)
	watch(Players.LocalPlayer:WaitForChild("Backpack"))
end

function WeaponController:Start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return WeaponController
