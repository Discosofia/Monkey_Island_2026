--!strict
-- Al usar un arma (clic en PC, tocar la pantalla en móvil, gatillo en mando) envía al servidor
-- hacia dónde apunta el jugador. El servidor decide si el ataque vale y a quién golpea.
-- Las armas cuerpo a cuerpo pegan en cadena (Fase 10, C4; Shared/MeleeChain): aquí se predice el paso,
-- se reproduce su tajo ("Slash1"–"Slash4" de Shared/Data/WeaponAnimations, estirado a lo que dura el
-- paso), se guarda en el búfer la pulsación que llega un poco antes de tiempo y, si el tajo da a algo,
-- se para un instante (parón de impacto) y el remate hace temblar la cámara. El hacha, el pico y la
-- hoz (y un personaje R6) usan el tajo de Roblox, más rápido que el normal.
-- Las de distancia (R15) usan las animaciones de Shared/Data/WeaponAnimations: con el arma en la
-- mano, el brazo derecho cuelga junto al cuerpo ("Hold", en bucle) y al disparar hace el movimiento
-- de su tipo de arma (tensar el arco, estirar la honda, lanzar el hechizo, soplar la cerbatana),
-- con más prioridad que la pose de empuñar de Roblox. Como son animaciones del personaje del propio
-- jugador, los demás también las ven; la bocanada y el destello (AbilityFxController,
-- "WeaponShotFx") se los manda el servidor.

local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MeleeChain = require(ReplicatedStorage.Shared.MeleeChain)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponAnimations = require(ReplicatedStorage.Shared.Data.WeaponAnimations)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local AbilityFxController = require(script.Parent.AbilityFxController)
local Aim = require(script.Parent.Parent.Aim)

-- Tajo estándar de Roblox, por si el personaje no trae el suyo en su script Animate.
local DEFAULT_SLASH: { [Enum.HumanoidRigType]: string } = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://522635514",
	[Enum.HumanoidRigType.R6] = "rbxassetid://129967390",
}
-- Secuencias que deja en ReplicatedStorage el generador (ServerStorage.Tools.WeaponAnimationBuilder).
local STUDIO_FOLDER = "WeaponAnimations"
local HOLD_FADE = 0.15
-- Zona del golpe (ancho y alto) para predecir el parón de impacto: la misma que el servidor
-- (CombatService.MELEE_HITBOX).
local MELEE_HITBOX = Vector2.new(7, 6)
local SHAKE_SECONDS = 0.15

local WeaponController = {}

local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local slashTrack: AnimationTrack? = nil
local lastSwingAt = -math.huge
local lastShotAt = -math.huge
-- Animaciones de armas ya cargadas en el personaje actual, por clave.
local weaponTracks: { [string]: AnimationTrack } = {}
-- Ids temporales de Studio de las secuencias generadas, por clave (se registran una vez).
local studioIds: { [string]: string } = {}
-- Predicción de la cadena de golpes (el servidor lleva la suya con los mismos tiempos).
local chain = MeleeChain.newState()
local buffered = false

-- Usa el tajo del paquete de animaciones del avatar (script Animate) o el estándar.
local function loadSlash(character: Model): AnimationTrack?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not (humanoid and animator) then
		return nil
	end
	local animate = character:FindFirstChild("Animate")
	local slot = if animate then animate:FindFirstChild("toolslash") else nil
	local source = if slot then slot:FindFirstChildOfClass("Animation") else nil
	local animation = Instance.new("Animation")
	animation.AnimationId = if source then source.AnimationId else DEFAULT_SLASH[humanoid.RigType]
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	return track
end

local function playSwing(character: Model, weapon: Weapons.WeaponDefinition)
	local now = os.clock()
	if now - lastSwingAt < weapon.cooldownSeconds then
		return
	end
	lastSwingAt = now
	slashTrack = slashTrack or loadSlash(character)
	if slashTrack then
		slashTrack:Play(0.05, 1, weapon.swingAnimationSpeed or 1)
	end
end

-- Id de la animación "key": el publicado o, en Studio y mientras esté vacío, uno temporal de la
-- secuencia generada. nil si no hay ninguno.
local function animationId(key: string): string?
	local data = WeaponAnimations[key]
	if data and data.id ~= "" then
		return data.id
	end
	if not RunService:IsStudio() then
		return nil
	end
	local cached = studioIds[key]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:FindFirstChild(STUDIO_FOLDER)
	local sequence = if folder then folder:FindFirstChild(key) else nil
	if not (sequence and sequence:IsA("KeyframeSequence")) then
		return nil
	end
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	if not ok then
		warn(`[WeaponController] No se pudo usar la animación "{key}" generada: {result}`)
		return nil
	end
	studioIds[key] = result
	return result
end

-- Carga (una vez por personaje) la animación de arma "key". Solo R15.
local function weaponTrack(character: Model, key: string): AnimationTrack?
	local cached = weaponTracks[key]
	if cached then
		return cached
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not (humanoid and animator and humanoid.RigType == Enum.HumanoidRigType.R15) then
		return nil
	end
	local id = animationId(key)
	if not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		warn(`[WeaponController] No se pudo cargar la animación "{key}": {track}`)
		return nil
	end
	-- El disparo y los tajos van por encima del brazo colgando, y todos por encima de la pose de empuñar.
	-- La guardia (GuardController), por encima de todo.
	track.Priority = if key == "Hold"
		then Enum.AnimationPriority.Action
		elseif key == "Guard" then Enum.AnimationPriority.Action3
		else Enum.AnimationPriority.Action2
	track.Looped = key == "Hold" or key == "Guard"
	weaponTracks[key] = track
	return track
end

-- La animación de arma "key" del personaje del jugador (Shared/Data/WeaponAnimations), cargada una vez
-- por personaje; nil si no hay (R6, o sin publicar fuera de Studio). La usa GuardController.
function WeaponController.track(character: Model, key: string): AnimationTrack?
	return weaponTrack(character, key)
end

local function holdArm(character: Model)
	local track = weaponTrack(character, "Hold")
	if track and not track.IsPlaying then
		track:Play(HOLD_FADE)
	end
end

local function releaseArm()
	local track = weaponTracks.Hold
	if track then
		track:Stop(HOLD_FADE)
	end
end

local function shoot(character: Model, weapon: Weapons.WeaponDefinition)
	if os.clock() - lastShotAt < weapon.cooldownSeconds then
		return
	end
	lastShotAt = os.clock()
	local projectile = weapon.projectile or "Stone"
	local track = weaponTrack(character, projectile)
	if track then
		track:Play(0.05)
	end
	AbilityFxController.play("WeaponShotFx", character, projectile)
end

-- true si el tajo de "weapon" va a dar a un enemigo o a otro jugador (la misma caja que el servidor,
-- sin línea de visión: solo es para el parón de impacto, el daño lo decide el servidor).
local function swingConnects(character: Model, weapon: Weapons.WeaponDefinition): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local box = root.CFrame * CFrame.new(0, 0, -weapon.range / 2)
	local size = Vector3.new(MELEE_HITBOX.X, MELEE_HITBOX.Y, weapon.range)
	for _, part in Workspace:GetPartBoundsInBox(box, size, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		if
			model
			and humanoid
			and humanoid.Health > 0
			and (CollectionService:HasTag(model, Config.Combat.EnemyTag) or Players:GetPlayerFromCharacter(model))
		then
			return true
		end
	end
	return false
end

-- Temblor corto de la cámara (el remate que da).
local function shake(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local amount = Config.Chain.FinisherShakeStuds
	local finish = os.clock() + SHAKE_SECONDS
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if os.clock() >= finish or humanoid.Parent == nil then
			connection:Disconnect()
			humanoid.CameraOffset = Vector3.zero
			return
		end
		humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 2 * amount
	end)
end

-- El tajo del paso "step": su animación estirada a lo que dura el paso (el golpe, al WindupFraction de
-- la animación, cae a la vez que en el servidor) y, si da, el parón de impacto y en el remate el temblor.
local function playChainSwing(character: Model, weapon: Weapons.WeaponDefinition, step: number)
	local stepSeconds = MeleeChain.stepSeconds(weapon, step)
	local track = weaponTrack(character, `Slash{step}`)
	local speed = 1
	if track and track.Length > 0 then
		speed = track.Length / stepSeconds
		track:Play(0.05, 1, speed)
	else
		-- Sin la animación (R6, o aún no generada ni publicada): el tajo de Roblox.
		slashTrack = slashTrack or loadSlash(character)
		if slashTrack then
			slashTrack:Play(0.05, 1, weapon.swingAnimationSpeed or 1)
		end
	end
	task.delay(MeleeChain.windupSeconds(weapon, step), function()
		if character.Parent == nil or not swingConnects(character, weapon) then
			return
		end
		local finisher = MeleeChain.isFinisher(step)
		if track and track.IsPlaying then
			track:AdjustSpeed(0)
			task.delay(if finisher then Config.Chain.FinisherHitStopSeconds else Config.Chain.HitStopSeconds, function()
				track:AdjustSpeed(speed)
			end)
		end
		if finisher then
			shake(character)
		end
	end)
end

-- Pulsar con un arma de cadena: empieza el siguiente golpe si se puede; si falta poco
-- (Config.Chain.BufferSeconds), la pulsación se guarda y sale en cuanto se puede.
local function swingChain(character: Model, tool: Tool, weaponId: string, weapon: Weapons.WeaponDefinition)
	local now = os.clock()
	local step = MeleeChain.advance(chain, weaponId, weapon, now)
	if step then
		playChainSwing(character, weapon, step)
		Remotes.UseWeapon:FireServer(Aim.direction(character))
		return
	end
	local wait = chain.readyAt - now
	if buffered or wait > Config.Chain.BufferSeconds then
		return
	end
	buffered = true
	task.delay(wait, function()
		buffered = false
		local player = Players.LocalPlayer
		if
			player.Character == character
			and tool.Parent == character
			and LifeState.isAlive(player)
			and CombatState.canAct(player, "Attack")
		then
			swingChain(character, tool, weaponId, weapon)
		end
	end)
end

local function hook(instance: Instance)
	if not instance:IsA("Tool") or hooked[instance] or instance:GetAttribute("WeaponId") == nil then
		return
	end
	hooked[instance] = true
	local weaponId = instance:GetAttribute("WeaponId")
	local weapon = if typeof(weaponId) == "string" then Weapons[weaponId] else nil
	instance.Activated:Connect(function()
		local character = Players.LocalPlayer.Character
		-- Aturdido o caído no se pega (Shared/CombatState; el servidor lo comprueba otra vez).
		if not character or not LifeState.isAlive(Players.LocalPlayer) then
			return
		end
		if not CombatState.canAct(Players.LocalPlayer, "Attack") then
			return
		end
		if weapon and MeleeChain.uses(weapon) then
			swingChain(character, instance, weaponId :: string, weapon)
			return
		elseif weapon and weapon.kind == "Melee" then
			playSwing(character, weapon)
		elseif weapon and weapon.kind == "Ranged" then
			shoot(character, weapon)
		end
		Remotes.UseWeapon:FireServer(Aim.direction(character))
	end)
	if weapon and weapon.kind == "Ranged" then
		instance.Equipped:Connect(function()
			local character = Players.LocalPlayer.Character
			if character then
				holdArm(character)
			end
		end)
		instance.Unequipped:Connect(releaseArm)
		local character = Players.LocalPlayer.Character
		if character and instance.Parent == character then
			holdArm(character)
		end
	end
end

local function watch(container: Instance)
	for _, child in container:GetChildren() do
		hook(child)
	end
	container.ChildAdded:Connect(hook)
end

local function onCharacter(character: Model)
	-- Cada personaje nuevo carga sus propias animaciones.
	slashTrack = nil
	table.clear(weaponTracks)
	watch(character)
	watch(Players.LocalPlayer:WaitForChild("Backpack"))
end

function WeaponController:Start()
	local player = Players.LocalPlayer
	-- Si le tambalean (un parry, un golpe en PvP), le aturden o se pone en guardia, el servidor corta la
	-- cadena: aquí también vuelve al primer golpe.
	player:GetAttributeChangedSignal(CombatState.ATTRIBUTE):Connect(function()
		local state = CombatState.get(player)
		if state ~= "Idle" and state ~= "Attacking" then
			chain = MeleeChain.newState()
		end
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return WeaponController
