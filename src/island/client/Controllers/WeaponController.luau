--!strict
-- Al usar un arma (clic en PC, tocar la pantalla en móvil, gatillo en mando) envía al servidor
-- hacia dónde apunta el jugador. El servidor decide si el ataque vale y a quién golpea.
-- Las armas cuerpo a cuerpo reproducen aquí el tajo, más rápido que el de Roblox por defecto.
-- Las de distancia (R15) usan las animaciones de Shared/Data/WeaponAnimations: con el arma en la
-- mano, el brazo derecho cuelga junto al cuerpo ("Hold", en bucle) y al disparar hace el movimiento
-- de su tipo de arma (tensar el arco, estirar la honda, lanzar el hechizo, soplar la cerbatana),
-- con más prioridad que la pose de empuñar de Roblox. Como son animaciones del personaje del propio
-- jugador, los demás también las ven; la bocanada y el destello (AbilityFxController,
-- "WeaponShotFx") se los manda el servidor.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LifeState = require(ReplicatedStorage.Shared.LifeState)
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

local WeaponController = {}

local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local slashTrack: AnimationTrack? = nil
local lastSwingAt = -math.huge
local lastShotAt = -math.huge
-- Animaciones de armas a distancia ya cargadas en el personaje actual, por clave.
local rangedTracks: { [string]: AnimationTrack } = {}
-- Ids temporales de Studio de las secuencias generadas, por clave (se registran una vez).
local studioIds: { [string]: string } = {}

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

-- Carga (una vez por personaje) la animación de arma a distancia "key". Solo R15.
local function rangedTrack(character: Model, key: string): AnimationTrack?
	local cached = rangedTracks[key]
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
	-- El disparo va por encima del brazo colgando, y los dos por encima de la pose de empuñar.
	track.Priority = if key == "Hold" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Action2
	track.Looped = key == "Hold"
	rangedTracks[key] = track
	return track
end

local function holdArm(character: Model)
	local track = rangedTrack(character, "Hold")
	if track and not track.IsPlaying then
		track:Play(HOLD_FADE)
	end
end

local function releaseArm()
	local track = rangedTracks.Hold
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
	local track = rangedTrack(character, projectile)
	if track then
		track:Play(0.05)
	end
	AbilityFxController.play("WeaponShotFx", character, projectile)
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
		if not character or not LifeState.isAlive(Players.LocalPlayer) then
			return
		end
		if weapon and weapon.kind == "Melee" then
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
	table.clear(rangedTracks)
	watch(character)
	watch(Players.LocalPlayer:WaitForChild("Backpack"))
end

function WeaponController:Start()
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return WeaponController
