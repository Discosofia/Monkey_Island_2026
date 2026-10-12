--!strict
-- Al usar un arma (clic en PC, tocar la pantalla en móvil, gatillo en mando) envía al servidor
-- hacia dónde apunta el jugador. El servidor decide si el ataque vale y a quién golpea.
-- Las armas cuerpo a cuerpo reproducen aquí el tajo, más rápido que el de Roblox por defecto;
-- como es el personaje del propio jugador, los demás también lo ven.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local AIM_DISTANCE = 500
-- Tajo estándar de Roblox, por si el personaje no trae el suyo en su script Animate.
local DEFAULT_SLASH: { [Enum.HumanoidRigType]: string } = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://522635514",
	[Enum.HumanoidRigType.R6] = "rbxassetid://129967390",
}

local WeaponController = {}

local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local slashTrack: AnimationTrack? = nil
local lastSwingAt = -math.huge

-- Usa el tajo del paquete de animaciones del avatar (script Animate) o el estándar.
local function loadSlash(character: Model): AnimationTrack?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not (humanoid and animator) then
		return nil
	end
	local animate = character:FindFirstChild("Animate")
	local slot = if animate then animate:FindFirstChild("toolslash") else nil
	local source = if slot then slot:FindFirstChildOfClass("Animation") else nil
	local animation = Instance.new("Animation")
	animation.AnimationId = if source then source.AnimationId else DEFAULT_SLASH[humanoid.RigType]
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	return track
end

local function playSwing(character: Model, weapon: Weapons.WeaponDefinition)
	local now = os.clock()
	if now - lastSwingAt < weapon.cooldownSeconds then
		return
	end
	lastSwingAt = now
	slashTrack = slashTrack or loadSlash(character)
	if slashTrack then
		slashTrack:Play(0.05, 1, weapon.swingAnimationSpeed or 1)
	end
end

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
	local weaponId = instance:GetAttribute("WeaponId")
	local weapon = if typeof(weaponId) == "string" then Weapons[weaponId] else nil
	instance.Activated:Connect(function()
		local character = Players.LocalPlayer.Character
		if not character then
			return
		end
		if weapon and weapon.kind == "Melee" then
			playSwing(character, weapon)
		end
		Remotes.UseWeapon:FireServer(aimDirection(character))
	end)
end

local function watch(container: Instance)
	for _, child in container:GetChildren() do
		hook(child)
	end
	container.ChildAdded:Connect(hook)
end

local function onCharacter(character: Model)
	-- Cada personaje nuevo carga su propia animación.
	slashTrack = nil
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
