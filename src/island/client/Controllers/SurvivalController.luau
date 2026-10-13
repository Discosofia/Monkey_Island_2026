--!strict
-- Acciones de supervivencia del jugador local (Fase 2.1):
--   - Correr: mantener Mayús en PC; L3 en mando o el botón táctil "Correr" lo activan y desactivan.
--     Gasta estamina; al vaciarse vuelves a caminar.
--   - Comer: C, cruceta izquierda o el botón "Comer" (aparece si llevas comida). El servidor elige
--     la comida que más llena.
--   - Beber: F, X en mando o el botón "Beber" (aparece junto al agua).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Survival = require(ReplicatedStorage.Shared.Survival)
local Stamina = require(script.Parent.Parent.Stamina)

local SPRINT_ACTION = "Sprint"
local EAT_ACTION = "Eat"
local DRINK_ACTION = "Drink"
local WATER_CHECK_SECONDS = 0.5

local SurvivalController = {}

local sprintHeld = false -- Mayús mantenida
local sprintToggled = false -- L3 o botón táctil

local function bindButton(action: string, title: string, enabled: boolean, handler: () -> (), ...: Enum.KeyCode)
	if enabled then
		ContextActionService:BindAction(action, function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				handler()
			end
			return Enum.ContextActionResult.Sink
		end, true, ...)
		ContextActionService:SetTitle(action, title)
	else
		ContextActionService:UnbindAction(action)
	end
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Velocidad según corra o no. Solo toca la velocidad si está vivo: caído, el servidor la controla.
local function updateSprint(player: Player, deltaTime: number)
	local humanoid = humanoidOf(player)
	if not humanoid or not LifeState.isAlive(player) then
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
	local speed = if sprinting then Config.Survival.SprintSpeed else Config.Survival.WalkSpeed
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
end

function SurvivalController:Start()
	local player = Players.LocalPlayer

	ContextActionService:BindAction(SPRINT_ACTION, function(_, state: Enum.UserInputState, input: InputObject)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			sprintHeld = state == Enum.UserInputState.Begin
		elseif state == Enum.UserInputState.Begin then
			sprintToggled = not sprintToggled
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle(SPRINT_ACTION, "Correr")

	RunService.RenderStepped:Connect(function(deltaTime)
		Stamina.update(deltaTime)
		updateSprint(player, deltaTime)
	end)

	-- "Comer" solo aparece si llevas comida y estás vivo.
	local eatBound = false
	local function refreshEat()
		local show = Survival.bestFood(player) ~= nil and LifeState.isAlive(player)
		if show ~= eatBound then
			eatBound = show
			bindButton(EAT_ACTION, "Comer", show, function()
				Remotes.Eat:FireServer()
			end, Enum.KeyCode.C, Enum.KeyCode.DPadLeft)
		end
	end
	for itemId, item in Items do
		if item.food then
			player:GetAttributeChangedSignal(Inventory.attributeName(itemId)):Connect(refreshEat)
		end
	end
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(refreshEat)
	refreshEat()

	-- "Beber" solo aparece cerca del agua.
	local drinkBound = false
	task.spawn(function()
		while true do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local show = root ~= nil
				and root:IsA("BasePart")
				and LifeState.isAlive(player)
				and Survival.isNearWater(root.Position)
			if show ~= drinkBound then
				drinkBound = show
				bindButton(DRINK_ACTION, "Beber", show, function()
					Remotes.Drink:FireServer()
				end, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
			end
			task.wait(WATER_CHECK_SECONDS)
		end
	end)
end

return SurvivalController
