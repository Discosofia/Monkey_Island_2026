--!strict
-- Zonas de peligro que pisa el jugador local (Fase 10, C10; Combat/Zones). En el hielo de la Nova de un
-- rival resbala: el servidor pone "SlipperyUntil" (hora del servidor) en el personaje mientras está
-- dentro, y aquí su velocidad en horizontal sigue a la que quiere con retraso
-- (Config.Zones.Ice.Traction): tarda en arrancar, en girar y en frenar. Lo mueve una LinearVelocity de
-- fuerza limitada, como Dash; si hay otro empuje en marcha (esquiva, empujón), lo deja hacer. La
-- lentitud del hielo la pone el controlador de movimiento del place ("SlowedUntil").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

-- Aceleración máxima del deslizamiento (studs/s²), la misma que Dash: puede más que el Humanoid.
local MAX_ACCELERATION = 3000

local ZoneController = {}

local slide: LinearVelocity? = nil
local velocity = Vector3.zero

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function stop()
	if slide then
		slide:Destroy()
		slide = nil
	end
end

-- true si otro empuje (Dash) mueve ahora a "root".
local function pushed(root: BasePart): boolean
	for _, child in root:GetChildren() do
		if child:IsA("LinearVelocity") and child ~= slide then
			return true
		end
	end
	return false
end

local function slippery(character: Model): boolean
	local untilTime = character:GetAttribute("SlipperyUntil")
	return typeof(untilTime) == "number" and Workspace:GetServerTimeNow() < untilTime
end

local function update(deltaTime: number)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local attachment = if root then root:FindFirstChild("RootAttachment") else nil
	if
		not (character and root and root:IsA("BasePart") and humanoid and attachment and attachment:IsA("Attachment"))
		or humanoid.Health <= 0
		or not slippery(character)
		or pushed(root)
	then
		stop()
		if root and root:IsA("BasePart") then
			velocity = flat(root.AssemblyLinearVelocity)
		end
		return
	end
	local current = slide
	if not current or current.Parent ~= root then
		stop()
		local created = Instance.new("LinearVelocity")
		created.Name = "IceSlide"
		created.Attachment0 = attachment
		created.MaxForce = root.AssemblyMass * MAX_ACCELERATION
		created.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		created.PrimaryTangentAxis = Vector3.xAxis
		created.SecondaryTangentAxis = Vector3.zAxis
		created.Parent = root
		slide = created
		current = created
		velocity = flat(root.AssemblyLinearVelocity)
	end
	-- Contra una pared (o frenado por algo) se queda con lo que de verdad lleva.
	local actual = flat(root.AssemblyLinearVelocity)
	if actual.Magnitude < velocity.Magnitude * 0.5 then
		velocity = actual
	end
	local wanted = flat(humanoid.MoveDirection) * humanoid.WalkSpeed
	velocity += (wanted - velocity) * (1 - math.exp(-Config.Zones.Ice.Traction * deltaTime))
	if current then
		current.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	end
end

function ZoneController:Start()
	RunService.Heartbeat:Connect(update)
end

return ZoneController
