--!strict
-- Andar y correr del jugador local en los cuatro places (Fase 15, V1; antes cada place tenía su copia):
--   - Correr: Mayús mantenida en PC; L3 en mando o el botón táctil "Correr" lo activan y desactivan.
--     Gasta estamina (CombatClient/Stamina); al vaciarse vuelves a caminar. Con la regla de movimiento
--     staminaFree (el Lobby) corre sin gastarla.
--   - Caído o montado no se corre ni se gasta estamina; en guardia tampoco.
--   - La velocidad la calcula y la escribe CombatClient/Movement (base × modificadores). Aquí se
--     registran los proveedores y modificadores del juego; el atributo que lee cada uno simplemente no
--     existe donde no aplica (el huevo fuera de la Isla, la bandera fuera de Dunas…):
--       montura y gateo (bases) · guardia · ralentizado · aturdido · huevo a cuestas · bandera rival a
--       cuestas · ventaja MoveSpeed del equipo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Survival = require(ReplicatedStorage.Shared.Survival)
local MountRiders = require(ReplicatedStorage.Shared.UI.MountRiders)
local ActionButtons = require(ReplicatedStorage.CombatClient.ActionButtons)
local Movement = require(ReplicatedStorage.CombatClient.Movement)
local Stamina = require(ReplicatedStorage.CombatClient.Stamina)

local T = Strings.t

local SPRINT_ACTION = "Sprint"

local LocomotionController = {}

local sprintHeld = false -- Mayús mantenida
local sprintToggled = false -- L3 o botón táctil

-- Proveedores y modificadores del juego. Todos son genéricos: no miran en qué place están.
local function registerMovement()
	-- Montado (Fase 11): corre la montura, con su velocidad.
	Movement.addBase("Mount", MountRiders.speedOf)
	-- Caído (Fase 2): gatea.
	Movement.addBase("Downed", function(player: Player): number?
		return if LifeState.get(player) == "Downed" then Config.Life.CrawlSpeed else nil
	end)
	-- En guardia (Fase 10, C5) se anda más despacio.
	Movement.addModifier("Guard", function(player: Player): number?
		return if CombatState.isGuarding(player) then Config.Guard.BlockWalkMultiplier else nil
	end)
	-- Ralentizado (Nova, Meteoro, dardos, red, Polvo somnífero; Combat/Status): anda a esa fracción.
	Movement.addModifier("Slow", function(player: Player): number?
		local character = player.Character
		if not character then
			return nil
		end
		local slowedUntil = character:GetAttribute("SlowedUntil")
		local slowFactor = character:GetAttribute("SlowFactor")
		if
			typeof(slowedUntil) == "number"
			and typeof(slowFactor) == "number"
			and Workspace:GetServerTimeNow() < slowedUntil
		then
			return slowFactor
		end
		return nil
	end)
	-- Aturdido o inmovilizado (pisotón del gorila, agarre del orangután; Combat/Status): no se mueve.
	Movement.addModifier("Stun", function(player: Player): number?
		local stunnedUntil = player:GetAttribute("StunnedUntil")
		return if typeof(stunnedUntil) == "number" and Workspace:GetServerTimeNow() < stunnedUntil then 0 else nil
	end)
	-- Con el huevo a cuestas (Fase 5) se va más lento; el guerrero lo lleva mejor.
	Movement.addModifier("Egg", function(player: Player): number?
		if player:GetAttribute("CarryingEgg") ~= true then
			return nil
		end
		local warrior = player:GetAttribute("Role") == "Guerrero"
		return if warrior then Config.Egg.WarriorCarrySpeedMultiplier else Config.Egg.CarrySpeedMultiplier
	end)
	-- Con la bandera rival a cuestas (Dunas) se va más lento, menos con la ventaja CarrySpeed.
	Movement.addModifier("Flag", function(player: Player): number?
		if player:GetAttribute("CarryingFlag") == nil then
			return nil
		end
		return math.min(1, Config.Arena.CarrierSpeedMultiplier + Progression.perk(player, "CarrySpeed"))
	end)
	-- Ventaja MoveSpeed del equipo (vale 1 si no hay).
	Movement.addModifier("MoveSpeed", function(player: Player): number?
		return Progression.perk(player, "MoveSpeed")
	end)
end

-- Un fotograma: estamina, si corre y velocidad.
local function update(player: Player, deltaTime: number)
	-- Con hambre o sed bajas, la estamina se recupera más despacio (igual que en el servidor).
	Stamina.update(deltaTime, if Survival.isWeak(player) then Config.Survival.WeakStaminaRegenFactor else 1)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		sprintToggled = false
		Stamina.setSprinting(false)
		return
	end
	local rules = Movement.rules()
	local sprinting = false
	if not LifeState.isAlive(player) or MountRiders.speedOf(player) ~= nil then
		-- Caído o montado: ni se corre ni se gasta estamina.
		sprintToggled = false
	else
		-- En guardia (Fase 10, C5) no se corre.
		local wantsSprint = (sprintHeld or sprintToggled)
			and humanoid.MoveDirection.Magnitude > 0.1
			and not CombatState.isGuarding(player)
		sprinting = wantsSprint and (rules.staminaFree or Stamina.get() > 0)
	end
	Stamina.setSprinting(sprinting)
	if sprinting and not rules.staminaFree then
		Stamina.drain(Config.Survival.SprintStaminaPerSecond * deltaTime)
		if Stamina.get() <= 0 then
			sprintToggled = false
		end
	end
	Movement.apply(humanoid, Movement.speedFor(player, sprinting))
end

function LocomotionController:Start()
	local player = Players.LocalPlayer

	registerMovement()

	ActionButtons.bind(SPRINT_ACTION, T("Correr"), function(_, state: Enum.UserInputState, input: InputObject)
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

return LocomotionController
