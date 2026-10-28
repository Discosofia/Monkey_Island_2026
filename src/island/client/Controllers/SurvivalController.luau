--!strict
-- Acciones de supervivencia del jugador local (Fase 2.1):
--   - Comer: G, cruceta izquierda o el botón "Comer" (aparece si llevas comida). El servidor elige
--     la comida que más llena.
--   - Beber: junto al agua aparece un aviso "Beber" como los de recolectar (E en PC, X en mando,
--     tocar en móvil). Es un aviso local que sigue al jugador mientras está cerca del agua. Hasta la
--     Fase 10 era F, que ahora es la guardia (GuardController).
-- Correr y la velocidad ya no son de aquí: son de CombatClient/Controllers/LocomotionController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Survival = require(ReplicatedStorage.Shared.Survival)
local ActionButtons = require(ReplicatedStorage.CombatClient.ActionButtons)
local BodyAnimations = require(ReplicatedStorage.CombatClient.BodyAnimations)

local T = Strings.t

local EAT_ACTION = "Eat"
local WATER_CHECK_SECONDS = 0.4

local SurvivalController = {}

-- Aviso "Beber": una pieza invisible solo de este cliente con un ProximityPrompt.
local function createDrinkPrompt(): (BasePart, ProximityPrompt)
	local anchor = Instance.new("Part")
	anchor.Name = "DrinkPromptAnchor"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrinkPrompt"
	prompt.ActionText = "Beber"
	prompt.ObjectText = "Agua"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function()
		BodyAnimations.play("Consume")
		Remotes.Drink:FireServer()
	end)
	return anchor, prompt
end

local function bindButton(action: string, title: string, enabled: boolean, handler: () -> (), ...: Enum.KeyCode)
	if enabled then
		ActionButtons.bind(action, title, function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				handler()
			end
			return Enum.ContextActionResult.Sink
		end, ...)
	else
		ActionButtons.unbind(action)
	end
end

function SurvivalController:Start()
	local player = Players.LocalPlayer

	-- "Comer" solo aparece si llevas comida y estás vivo.
	local eatBound = false
	local function refreshEat()
		local show = Survival.bestFood(player) ~= nil and LifeState.isAlive(player)
		if show ~= eatBound then
			eatBound = show
			bindButton(EAT_ACTION, T("Comer"), show, function()
				BodyAnimations.play("Consume")
				Remotes.Eat:FireServer()
			end, Enum.KeyCode.G, Enum.KeyCode.DPadLeft)
		end
	end
	for itemId, item in Items do
		if item.food then
			player:GetAttributeChangedSignal(Inventory.attributeName(itemId)):Connect(refreshEat)
		end
	end
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(refreshEat)
	refreshEat()

	-- "Beber" solo aparece cerca del agua; el aviso acompaña al jugador a la altura del pecho.
	local drinkAnchor, drinkPrompt = createDrinkPrompt()
	drinkAnchor.Parent = Workspace
	task.spawn(function()
		while true do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local nearWater = false
			if root and root:IsA("BasePart") and LifeState.isAlive(player) then
				nearWater = Survival.isNearWater(root.Position)
				drinkAnchor.Position = root.Position + root.CFrame.LookVector * 2
			end
			drinkPrompt.Enabled = nearWater
			task.wait(WATER_CHECK_SECONDS)
		end
	end)
end

return SurvivalController
