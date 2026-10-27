--!strict
-- Esquiva: impulso rápido en la dirección en la que te mueves (o hacia atrás si estás quieto).
-- Q en PC, B en mando y un botón táctil en móvil. El servidor da una invulnerabilidad breve.
-- Cuesta estamina (Config.Survival.DodgeStaminaCost): sin estamina no se puede esquivar.
-- Evasivo (Fase 10, C7; Combat/Evasive): la misma esquiva estando atrapado (aturdido, con la guardia
-- rota, inmovilizado o lanzado: CombatState.isTrapped). Suelta, aparta más lejos y no gasta estamina,
-- pero recarga Config.Evasive.CooldownSeconds; atrapado y con él en recarga, no se esquiva. El botón
-- táctil pasa a decir "Evasivo" (con la cuenta atrás si recarga); el icono del HUD es
-- CombatClient/EvasiveIcon.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Stamina = require(script.Parent.Parent.Stamina)
local ActionButtons = require(script.Parent.Parent.ActionButtons)
local BodyAnimations = require(script.Parent.Parent.BodyAnimations)
local Dash = require(script.Parent.Parent.Dash)
local Feint = require(script.Parent.Parent.Feint)
local AbilityFxController = require(script.Parent.AbilityFxController)

local T = Strings.t

local ACTION = "Dodge"

local DodgeController = {}

local lastDodgeAt = -math.huge
-- Hasta cuándo (os.clock) se da por usado el Evasivo mientras llega "EvasiveReadyAt" del servidor.
local evasivePendingUntil = -math.huge

-- Dirección del salto: hacia donde se mueve o, quieto, hacia atrás. Pone la voltereta o el salto atrás.
local function dashDirection(humanoid: Humanoid, root: BasePart): Vector3
	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = -root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	-- Voltereta si va hacia donde mira (al andar casi siempre); si no, salto atrás.
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	BodyAnimations.play(if direction:Dot(look) > 0.3 then "DodgeRoll" else "DodgeBack")
	return direction
end

local function evasiveReady(player: Player): boolean
	return os.clock() >= evasivePendingUntil and CombatState.evasiveWait(player) <= 0
end

local function evasive(player: Player, humanoid: Humanoid, root: BasePart)
	if not (CombatState.canAct(player, "Evasive") and evasiveReady(player)) then
		return
	end
	evasivePendingUntil = os.clock() + 1
	local settings = Config.Evasive
	Dash.push(root, dashDirection(humanoid, root), settings.Speed, settings.DurationSeconds)
	AbilityFxController.play("EvasiveFx", player.Character)
	Remotes.Evasive:FireServer()
end

local function dodge()
	local player = Players.LocalPlayer
	if not LifeState.isAlive(player) then
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return
	end
	if CombatState.isTrapped(player) then
		evasive(player, humanoid, root)
		return
	end
	local now = os.clock()
	-- Preparando una habilidad no se esquiva (C8; el servidor tampoco deja: "Casting").
	if
		now - lastDodgeAt < Config.Combat.DodgeCooldownSeconds
		or not CombatState.canAct(player, "Dodge")
		or Feint.casting()
	then
		return
	end
	if not Stamina.tryConsume(Config.Survival.DodgeStaminaCost) then
		return
	end
	lastDodgeAt = now
	Dash.push(root, dashDirection(humanoid, root), Config.Combat.DodgeSpeed, Config.Combat.DodgeDurationSeconds)
	Remotes.Dodge:FireServer()
end

-- Texto del botón táctil: "Esquivar" o, atrapado, "Evasivo" (con los segundos que le faltan).
local function buttonTitle(player: Player): string
	if not CombatState.isTrapped(player) then
		return T("Esquivar")
	end
	local wait = CombatState.evasiveWait(player)
	return if wait > 0 then T("Evasivo {n}", { n = math.ceil(wait) }) else T("¡Evasivo!")
end

function DodgeController:Start()
	local player = Players.LocalPlayer
	Dash.keepUpright()
	local shown = T("Esquivar")
	ActionButtons.bind(ACTION, shown, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			dodge()
		end
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	RunService.Heartbeat:Connect(function()
		local title = buttonTitle(player)
		if title ~= shown then
			shown = title
			ActionButtons.setTitle(ACTION, title)
		end
	end)
end

return DodgeController
