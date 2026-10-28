--!strict
-- Andar y correr del jugador local en los cuatro places (Fase 15, V1; antes cada place tenía su copia):
--   - Correr: Mayús mantenida en PC; L3 en mando o el botón táctil "Correr" lo activan y desactivan.
--     Gasta estamina (CombatClient/Stamina); al vaciarse vuelves a caminar. Con la regla de movimiento
--     staminaFree (el Lobby) corre sin gastarla. El correr alternado se apaga tras 0,3 s sin moverte.
--   - Deslizar (Fase 15, V2; CombatClient/Slide): solo corriendo. Alt izquierdo (C en el Laboratorio,
--     regla slideKey) y R3 en el mando; en el móvil el botón "Correr" pasa a "Deslizar" mientras se corre.
--   - Caído o montado no se corre ni se gasta estamina; en guardia tampoco.
--   - La velocidad la calcula y la escribe CombatClient/Movement (base × modificadores). Aquí se
--     registran los proveedores y modificadores del juego; el atributo que lee cada uno simplemente no
--     existe donde no aplica (el huevo fuera de la Isla, la bandera fuera de Dunas…):
--       montura y gateo (bases) · guardia · ralentizado · aturdido · huevo a cuestas · bandera rival a
--       cuestas · ventaja MoveSpeed del equipo.

local ContextActionService = game:GetService("ContextActionService")
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
local Slide = require(ReplicatedStorage.CombatClient.Slide)
local Stamina = require(ReplicatedStorage.CombatClient.Stamina)

local T = Strings.t

local SPRINT_ACTION = "Sprint"
local SLIDE_ACTION = "Slide"
-- Segundos quieto tras los que el correr alternado (L3, botón táctil) se apaga solo: ya no hay botón
-- que lo pare, porque con el correr activo el botón táctil desliza.
local TOGGLE_IDLE_SECONDS = 0.3
-- Cuánto esperar a que el servidor publique las reglas (la tecla del deslizamiento) antes de usar la
-- de siempre.
local RULES_WAIT_SECONDS = 10

local LocomotionController = {}

local sprintHeld = false -- Mayús mantenida
local sprintToggled = false -- L3 o botón táctil
local sprintingNow = false -- corre en este fotograma (el botón táctil entonces desliza)
local idleSeconds = 0

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
		sprintingNow = false
		Stamina.setSprinting(false)
		return
	end
	local rules = Movement.rules()
	-- El correr alternado se apaga tras un rato sin moverte.
	if sprintToggled and humanoid.MoveDirection.Magnitude <= 0.1 then
		idleSeconds += deltaTime
		if idleSeconds > TOGGLE_IDLE_SECONDS then
			sprintToggled = false
		end
	else
		idleSeconds = 0
	end
	local sprinting = false
	if not LifeState.isAlive(player) or MountRiders.speedOf(player) ~= nil then
		-- Caído o montado: ni se corre ni se gasta estamina.
		sprintToggled = false
		Slide.cancel()
	else
		-- En guardia (Fase 10, C5) no se corre.
		local wantsSprint = (sprintHeld or sprintToggled)
			and humanoid.MoveDirection.Magnitude > 0.1
			and not CombatState.isGuarding(player)
		sprinting = wantsSprint and (rules.staminaFree or Stamina.get() > 0)
	end
	sprintingNow = sprinting
	-- El botón táctil: "Deslizar" mientras se corre (y hay regla), "Correr" si no.
	ActionButtons.setTitle(SPRINT_ACTION, if sprinting and rules.slide then T("Deslizar") else T("Correr"))
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
			if input.KeyCode ~= Enum.KeyCode.ButtonL3 and sprintingNow and Movement.rules().slide then
				-- El botón táctil, ya corriendo, dice "Deslizar" (L3 sigue alternando el correr).
				Slide.tryStart(true)
			else
				sprintToggled = not sprintToggled
			end
		end
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

	-- Deslizar: la tecla la fija la regla del place (LeftAlt, o C en el Laboratorio) y R3 en el mando.
	-- Las reglas las publica el servidor al arrancar: se espera a su atributo (con un tope) para enlazar.
	-- No tiene botón táctil propio: lo hace el de Correr.
	task.spawn(function()
		local waited = 0
		while typeof(ReplicatedStorage:GetAttribute("MovementSlideKey")) ~= "string" and waited < RULES_WAIT_SECONDS do
			waited += task.wait(0.1)
		end
		local keyName = Movement.rules().slideKey
		local keyCode = Enum.KeyCode.LeftAlt
		local ok, found = pcall(function()
			return (Enum.KeyCode :: any)[keyName]
		end)
		if ok and typeof(found) == "EnumItem" then
			keyCode = found :: Enum.KeyCode
		end
		ContextActionService:BindAction(SLIDE_ACTION, function(_, state: Enum.UserInputState)
			if state == Enum.UserInputState.Begin then
				Slide.tryStart(sprintingNow)
			end
			return Enum.ContextActionResult.Sink
		end, false, keyCode, Enum.KeyCode.ButtonR3)
	end)

	RunService.RenderStepped:Connect(function(deltaTime)
		update(player, deltaTime)
	end)
end

return LocomotionController
