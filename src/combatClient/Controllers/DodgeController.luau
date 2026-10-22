--!strict
-- Esquiva: impulso rápido en la dirección en la que te mueves (o hacia atrás si estás quieto).
-- Q en PC, B en mando y un botón táctil en móvil. El servidor da una invulnerabilidad breve.
-- Cuesta estamina (Config.Survival.DodgeStaminaCost): sin estamina no se puede esquivar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stamina = require(script.Parent.Parent.Stamina)
local ActionButtons = require(script.Parent.Parent.ActionButtons)
local BodyAnimations = require(script.Parent.Parent.BodyAnimations)
local Dash = require(script.Parent.Parent.Dash)

local ACTION = "Dodge"

local DodgeController = {}

local lastDodgeAt = -math.huge

local function dodge()
	local now = os.clock()
	if now - lastDodgeAt < Config.Combat.DodgeCooldownSeconds or not LifeState.isAlive(Players.LocalPlayer) then
		return
	end
	-- Aturdido no se esquiva (desde C7, esquivar aturdido será el Evasivo).
	if not CombatState.canAct(Players.LocalPlayer, "Dodge") then
		return
	end
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return
	end
	if not Stamina.tryConsume(Config.Survival.DodgeStaminaCost) then
		return
	end
	lastDodgeAt = now

	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = -root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	-- Voltereta si va hacia donde mira (al andar casi siempre); si no, salto atrás.
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	BodyAnimations.play(if direction:Dot(look) > 0.3 then "DodgeRoll" else "DodgeBack")

	Dash.push(root, direction, Config.Combat.DodgeSpeed, Config.Combat.DodgeDurationSeconds)

	Remotes.Dodge:FireServer()
end

function DodgeController:Start()
	Dash.keepUpright()
	ActionButtons.bind(ACTION, "Esquivar", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			dodge()
		end
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
end

return DodgeController
