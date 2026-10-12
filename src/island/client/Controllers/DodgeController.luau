--!strict
-- Esquiva: impulso rápido en la dirección en la que te mueves (o hacia atrás si estás quieto).
-- Q en PC, B en mando y un botón táctil en móvil. El servidor da una invulnerabilidad breve.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ACTION = "Dodge"

local DodgeController = {}

local lastDodgeAt = -math.huge

local function dodge()
	local now = os.clock()
	if now - lastDodgeAt < Config.Combat.DodgeCooldownSeconds or not LifeState.isAlive(Players.LocalPlayer) then
		return
	end
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local attachment = if root then root:FindFirstChild("RootAttachment") else nil
	if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and attachment) then
		return
	end
	if not attachment:IsA("Attachment") then
		return
	end
	lastDodgeAt = now

	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = -root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	-- Empuje horizontal durante un instante; la gravedad sigue actuando.
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = attachment
	push.MaxForce = math.huge
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.xAxis
	push.SecondaryTangentAxis = Vector3.zAxis
	push.PlaneVelocity = Vector2.new(direction.X, direction.Z) * Config.Combat.DodgeSpeed
	push.Parent = root
	task.delay(Config.Combat.DodgeDurationSeconds, function()
		push:Destroy()
	end)

	Remotes.Dodge:FireServer()
end

function DodgeController:Start()
	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			dodge()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle(ACTION, "Esquivar")
end

return DodgeController
