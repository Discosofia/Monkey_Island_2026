--!strict
-- Acciones de supervivencia del jugador local (Fase 2.1):
--   - Correr: mantener Mayús en PC; L3 en mando o el botón táctil "Correr" lo activan y desactivan.
--     Gasta estamina; al vaciarse vuelves a caminar.
--   - Comer: G, cruceta izquierda o el botón "Comer" (aparece si llevas comida). El servidor elige
--     la comida que más llena.
--   - Beber: junto al agua aparece un aviso "Beber" como los de recolectar (E en PC, X en mando,
--     tocar en móvil). Es un aviso local que sigue al jugador mientras está cerca del agua. Hasta la
--     Fase 10 era F, que ahora es la guardia (GuardController).
--   - En guardia (Fase 10, C5; Shared/CombatState) no se corre y se anda más despacio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Survival = require(ReplicatedStorage.Shared.Survival)
local Stamina = require(ReplicatedStorage.CombatClient.Stamina)
local ActionButtons = require(ReplicatedStorage.CombatClient.ActionButtons)
local BodyAnimations = require(ReplicatedStorage.CombatClient.BodyAnimations)

local SPRINT_ACTION = "Sprint"
local EAT_ACTION = "Eat"
local WATER_CHECK_SECONDS = 0.4

local SurvivalController = {}

local sprintHeld = false -- Mayús mantenida
local sprintToggled = false -- L3 o botón táctil

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

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Velocidad según corra o no. Solo toca la velocidad si está vivo: caído, el servidor la controla.
local function updateSprint(player: Player, deltaTime: number)
	local humanoid = humanoidOf(player)
	if not humanoid or not LifeState.isAlive(player) then
		sprintToggled = false
		Stamina.setSprinting(false)
		return
	end
	-- En guardia (Fase 10, C5) no se corre y se anda más despacio.
	local guarding = CombatState.isGuarding(player)
	local wantsSprint = (sprintHeld or sprintToggled) and humanoid.MoveDirection.Magnitude > 0.1 and not guarding
	local sprinting = wantsSprint and Stamina.get() > 0
	Stamina.setSprinting(sprinting)
	if sprinting then
		Stamina.drain(Config.Survival.SprintStaminaPerSecond * deltaTime)
		if Stamina.get() <= 0 then
			sprintToggled = false
		end
	end
	local speed = if sprinting then Config.Survival.SprintSpeed else Config.Survival.WalkSpeed
	-- Con el huevo a cuestas (Fase 5) se va más lento; el guerrero lo lleva mejor.
	if player:GetAttribute("CarryingEgg") == true then
		local warrior = player:GetAttribute("Role") == "Guerrero"
		speed *= if warrior then Config.Egg.WarriorCarrySpeedMultiplier else Config.Egg.CarrySpeedMultiplier
	end
	if guarding then
		speed *= Config.Guard.BlockWalkMultiplier
	end
	-- Aturdido o inmovilizado (pisotón del gorila, agarre del orangután; Combat/Status): no se puede mover.
	local stunnedUntil = player:GetAttribute("StunnedUntil")
	if typeof(stunnedUntil) == "number" and Workspace:GetServerTimeNow() < stunnedUntil then
		speed = 0
	end
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
end

function SurvivalController:Start()
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
		-- Con hambre o sed bajas, la estamina se recupera más despacio (igual que en el servidor).
		local weak = Survival.isWeak(player)
		Stamina.update(deltaTime, if weak then Config.Survival.WeakStaminaRegenFactor else 1)
		updateSprint(player, deltaTime)
	end)

	-- "Comer" solo aparece si llevas comida y estás vivo.
	local eatBound = false
	local function refreshEat()
		local show = Survival.bestFood(player) ~= nil and LifeState.isAlive(player)
		if show ~= eatBound then
			eatBound = show
			bindButton(EAT_ACTION, "Comer", show, function()
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
