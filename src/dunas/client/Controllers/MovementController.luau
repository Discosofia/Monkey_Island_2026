--!strict
-- Correr y velocidad en la arena (lo que en la Isla hace SurvivalController, sin hambre ni sed):
--   - Correr (Mayús mantenida; L3 o el botón táctil lo alternan) gasta estamina, que se recupera sola
--     (CombatClient/Stamina). Esquivar también la gasta (DodgeController).
--   - Aturdido o sujeto ("StunnedUntil", habilidades rivales): no se mueve.
--   - Ralentizado ("SlowedUntil" y "SlowFactor" en el personaje: Nova, Meteoro, Polvo somnífero de un
--     rival): anda a esa fracción.
--   - Con la bandera rival a cuestas ("CarryingFlag") se va más lento (Config.Arena, menos con la
--     ventaja CarrySpeed). El equipo de la arena puede cambiar la velocidad (ventaja MoveSpeed).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local ActionButtons = require(ReplicatedStorage.CombatClient.ActionButtons)
local Stamina = require(ReplicatedStorage.CombatClient.Stamina)

local SPRINT_ACTION = "Sprint"

local MovementController = {}

local sprintHeld = false -- Mayús mantenida
local sprintToggled = false -- L3 o botón táctil

local function update(player: Player, deltaTime: number)
	Stamina.update(deltaTime)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (character and humanoid) or humanoid.Health <= 0 then
		sprintToggled = false
		return
	end
	local wantsSprint = (sprintHeld or sprintToggled) and humanoid.MoveDirection.Magnitude > 0.1
	local sprinting = wantsSprint and Stamina.get() > 0
	if sprinting then
		Stamina.drain(Config.Survival.SprintStaminaPerSecond * deltaTime)
		if Stamina.get() <= 0 then
			sprintToggled = false
		end
	end
	local speed = (if sprinting then Config.Survival.SprintSpeed else Config.Survival.WalkSpeed)
		* Progression.perk(player, "MoveSpeed")
	if player:GetAttribute("CarryingFlag") ~= nil then
		speed *= math.min(1, Config.Arena.CarrierSpeedMultiplier + Progression.perk(player, "CarrySpeed"))
	end
	local slowedUntil = character:GetAttribute("SlowedUntil")
	local slowFactor = character:GetAttribute("SlowFactor")
	if
		typeof(slowedUntil) == "number"
		and typeof(slowFactor) == "number"
		and Workspace:GetServerTimeNow() < slowedUntil
	then
		speed *= slowFactor
	end
	local stunnedUntil = player:GetAttribute("StunnedUntil")
	if typeof(stunnedUntil) == "number" and Workspace:GetServerTimeNow() < stunnedUntil then
		speed = 0
	end
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
end

function MovementController:Start()
	local player = Players.LocalPlayer
	ActionButtons.bind(SPRINT_ACTION, "Correr", function(_, state: Enum.UserInputState, input: InputObject)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			sprintHeld = state == Enum.UserInputState.Begin
		elseif state == Enum.UserInputState.Begin then
			sprintToggled = not sprintToggled
		end
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	RunService.RenderStepped:Connect(function(deltaTime)
		update(player, deltaTime)
	end)
end

return MovementController
