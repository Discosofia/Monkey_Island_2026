--!strict
-- Deslizamiento del jugador local (Fase 15, V2). Corriendo, en el suelo y a buena velocidad (en el
-- Laboratorio, regla slideFromWalk, también andando, con la versión corta Config.Movement.Slide.Walking), un impulso
-- de Config.Movement.Slide.StartSpeed que baja hasta EndSpeed (Dash.push con velocidad final), con el
-- cuerpo agachado (BodyAnimations "Slide"). Sin invulnerabilidad: se puede pegar y disparar mientras.
--   - La dirección se fija al empezar y no gira. Se corta con una pared delante (Dash.push), si te
--     aturden o atrapan, caes, mueres o esquivas (DodgeController llama a Slide.cancel).
--   - Salto deslizado: saltar lo termina y conserva JumpKeep × la velocidad que llevaba, en esa
--     dirección, hasta aterrizar (como mucho JumpCarrySeconds). En el aire no se empieza, así que no
--     se encadena.
--   - Cuesta estamina (no en el Lobby: regla staminaFree) y tiene espera desde el inicio. El servidor lo
--     valida otra vez (CombatService.onSlide) y publica "SlidingUntil".
-- Lo llama LocomotionController (tecla, mando y botón táctil). La cámara del Laboratorio baja con
-- Slide.currentDrop().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Survival = require(ReplicatedStorage.Shared.Survival)
local MountRiders = require(ReplicatedStorage.Shared.UI.MountRiders)
local BodyAnimations = require(script.Parent.BodyAnimations)
local Dash = require(script.Parent.Dash)
local DodgeFeel = require(script.Parent.DodgeFeel)
local Feint = require(script.Parent.Feint)
local Movement = require(script.Parent.Movement)
local Stamina = require(script.Parent.Stamina)

-- Si tras pedir el salto no se ve en el aire en este tiempo (no saltó), se suelta el impulso.
local JUMP_GRACE_SECONDS = 0.15

local Slide = {}

local lastStartAt = -math.huge
local endedAt = -math.huge
local sliding: Dash.Handle? = nil
local carrying: Dash.Handle? = nil
local direction = Vector3.zero
local jumpAt = 0
local seenAir = false
local savedAutoRotate: boolean? = nil
local watching = false

local function localParts(): (Humanoid?, BasePart?)
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return humanoid, if root and root:IsA("BasePart") then root else nil
end

-- true mientras dura el deslizamiento (no el impulso del salto deslizado).
function Slide.active(): boolean
	return sliding ~= nil
end

local function endCarry()
	local handle = carrying
	if handle then
		carrying = nil
		handle.cancel()
	end
end

local function endSlide()
	local handle = sliding
	if not handle then
		return
	end
	sliding = nil
	handle.cancel()
	endedAt = os.clock()
	BodyAnimations.stop("Slide")
	local humanoid = localParts()
	if humanoid and savedAutoRotate ~= nil then
		humanoid.AutoRotate = savedAutoRotate
	end
	savedAutoRotate = nil
end

-- Corta todo (una esquiva, un aturdimiento, la muerte).
function Slide.cancel()
	endSlide()
	endCarry()
end

-- Saltar durante el deslizamiento: pasa a conservar parte de la velocidad en el aire.
local function jumpFromSlide()
	local handle = sliding
	local _, root = localParts()
	if not (handle and root) then
		return
	end
	local speed = handle.speed() * Config.Movement.Slide.JumpKeep
	endSlide()
	carrying = Dash.push(root, direction, speed, Config.Movement.Slide.JumpCarrySeconds)
	jumpAt = os.clock()
	seenAir = false
end

-- Cada fotograma: corta el deslizamiento o el impulso del salto cuando toca.
local function step()
	if not (sliding or carrying) then
		return
	end
	local player = Players.LocalPlayer
	local humanoid = localParts()
	if not humanoid or humanoid.Health <= 0 or not LifeState.isAlive(player) or CombatState.isTrapped(player) then
		Slide.cancel()
		return
	end
	local slide = sliding
	if slide and not slide.active() then
		-- Terminó el tiempo o chocó con una pared.
		endSlide()
	end
	local carry = carrying
	if carry then
		local air = humanoid.FloorMaterial == Enum.Material.Air
		seenAir = seenAir or air
		local elapsed = os.clock() - jumpAt
		if
			not carry.active()
			or elapsed >= Config.Movement.Slide.JumpCarrySeconds
			or (not air and (seenAir or elapsed > JUMP_GRACE_SECONDS))
		then
			endCarry()
		end
	end
end

local function watch()
	if watching then
		return
	end
	watching = true
	RunService.Heartbeat:Connect(step)
	UserInputService.JumpRequest:Connect(function()
		if sliding then
			jumpFromSlide()
		end
	end)
end

-- Intenta empezar a deslizar. "sprinting": si el jugador corre ahora (lo sabe LocomotionController).
-- Devuelve true si ha empezado.
function Slide.tryStart(sprinting: boolean): boolean
	local player = Players.LocalPlayer
	local rules = Movement.rules()
	local settings = Config.Movement.Slide
	local now = os.clock()
	-- Andando solo se desliza donde lo permite la regla (el Laboratorio), con la versión corta.
	local short = not sprinting and rules.slideFromWalk
	if
		not (rules.slide and (sprinting or short))
		or sliding
		or carrying
		or now - lastStartAt < settings.CooldownSeconds
	then
		return false
	end
	local humanoid, root = localParts()
	if not (humanoid and root) or humanoid.Health <= 0 then
		return false
	end
	-- En el suelo y a velocidad de correr de verdad (o, en la versión corta, de andar).
	local velocity = root.AssemblyLinearVelocity
	if
		humanoid.FloorMaterial == Enum.Material.Air
		or Vector3.new(velocity.X, 0, velocity.Z).Magnitude < (if short
			then settings.Walking.MinSpeed
			else settings.MinSpeed)
		or humanoid.MoveDirection.Magnitude < 0.1
	then
		return false
	end
	-- Caído, montado, en guardia, preparando una habilidad, atrapado o con la bandera: no.
	if
		not LifeState.isAlive(player)
		or MountRiders.speedOf(player) ~= nil
		or CombatState.isGuarding(player)
		or CombatState.isTrapped(player)
		or not CombatState.canAct(player, "Slide")
		or Feint.casting()
		or player:GetAttribute("CarryingFlag") ~= nil
	then
		return false
	end
	if not rules.staminaFree and Stamina.get() < settings.StaminaCost then
		return false
	end
	local weak = if Survival.isWeak(player) then settings.WeakFactor else 1
	local kind = if short then settings.Walking else settings
	local push = Dash.push(root, humanoid.MoveDirection, kind.StartSpeed * weak, kind.Seconds, kind.EndSpeed * weak)
	if not push then
		return false
	end
	if not rules.staminaFree then
		Stamina.tryConsume(settings.StaminaCost)
	end
	watch()
	sliding = push
	lastStartAt = now
	direction = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z).Unit
	-- Sin giro mientras dura (el personaje no se vuelve hacia donde se mueve el pulgar).
	savedAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false
	BodyAnimations.play("Slide")
	DodgeFeel.kick(Config.Movement.SpeedLines.SlideFovKick)
	Remotes.Slide:FireServer(short)
	return true
end

-- Cuánto baja la cámara ahora (studs): solo con la esquiva "Dash", es decir, en la primera persona del
-- Laboratorio. Entra y sale en Config.Movement.Slide.CameraSeconds.
function Slide.currentDrop(): number
	local settings = Config.Movement.Slide
	local now = os.clock()
	local factor = if sliding
		then math.clamp((now - lastStartAt) / settings.CameraSeconds, 0, 1)
		else 1 - math.clamp((now - endedAt) / settings.CameraSeconds, 0, 1)
	if factor <= 0 or Movement.rules().dodgeStyle ~= "Dash" then
		return 0
	end
	return settings.CameraDrop * factor
end

return Slide
