--!strict
-- Al usar un arma (clic en PC, tocar la pantalla en móvil, gatillo en mando) envía al servidor
-- hacia dónde apunta el jugador. El servidor decide si el ataque vale y a quién golpea.
-- Las armas cuerpo a cuerpo pegan en cadena (Fase 10, C4; Shared/MeleeChain): aquí se predice el paso,
-- se reproduce su tajo ("Slash1"–"Slash4" de Shared/Data/WeaponAnimations, estirado a lo que dura el
-- paso), se guarda en el búfer la pulsación que llega un poco antes de tiempo y, si el tajo da a algo,
-- se para un instante (parón de impacto) y el remate hace temblar la cámara. El hacha, el pico y la
-- hoz (y un personaje R6) usan el tajo de Roblox, más rápido que el normal.
-- Amago (C8, CombatClient/Feint): pulsar la guardia durante la preparación de un tajo lo corta y la
-- cadena vuelve al primer golpe. Mientras se prepara una habilidad no se pega.
-- Las de distancia (R15) usan las animaciones de Shared/Data/WeaponAnimations: con el arma en la
-- mano, el brazo derecho cuelga junto al cuerpo ("Hold", en bucle) y al disparar hace el movimiento
-- de su tipo de arma (tensar el arco, estirar la honda, lanzar el hechizo, soplar la cerbatana),
-- con más prioridad que la pose de empuñar de Roblox. Como son animaciones del personaje del propio
-- jugador, los demás también las ven; la bocanada y el destello (AbilityFxController,
-- "WeaponShotFx") se los manda el servidor.
-- Disparo de remate (C9b, Shared/RangedChain): aquí se predice la cuenta de disparos seguidos para que
-- el destello del remate salga al momento; el proyectil y lo que hace los decide el servidor.
-- Laboratorio (Fase 13, Data/LabWeapons): cada arma dispara con la animación de su "pose", y el rifle
-- acerca la vista (Config.Lab.RifleZoomFieldOfView) mientras se mantiene apuntado: clic derecho o gatillo
-- izquierdo del mando, o el botón "Mira" en el móvil (uno lo pone y otro lo quita).
-- Cargador (Fase 15, V8; CombatClient/LabShooting): con un arma de "lab.magazine" solo se dispara si hay
-- balas y no se recarga (vacía, pide recargar y suena un clic una vez por pulsación), cada tiro gasta una
-- y se manda al servidor si la mira está acercada (5.º argumento de UseWeapon), que pone la dispersión.
-- Las automáticas ("lab.automatic") repiten el disparo a su cadencia mientras se mantiene el gatillo.

local CollectionService = game:GetService("CollectionService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MeleeChain = require(ReplicatedStorage.Shared.MeleeChain)
local RangedChain = require(ReplicatedStorage.Shared.RangedChain)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local WeaponAnimations = require(ReplicatedStorage.Shared.Data.WeaponAnimations)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local AbilityFxController = require(script.Parent.AbilityFxController)
local ActionButtons = require(script.Parent.Parent.ActionButtons)
local Aim = require(script.Parent.Parent.Aim)
local CameraShake = require(script.Parent.Parent.CameraShake)
local Feint = require(script.Parent.Parent.Feint)
local LabShooting = require(script.Parent.Parent.LabShooting)

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
local ZOOM_ACTION = "Zoom"
local ZOOM_SECONDS = 0.15

local WeaponController = {}

local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local slashTrack: AnimationTrack? = nil
local lastSwingAt = -math.huge
-- Animaciones de armas ya cargadas en el personaje actual, por clave.
local weaponTracks: { [string]: AnimationTrack } = {}
-- Ids temporales de Studio de las secuencias generadas, por clave (se registran una vez).
local studioIds: { [string]: string } = {}
-- Predicción de la cadena de golpes (el servidor lleva la suya con los mismos tiempos).
local chain = MeleeChain.newState()
local buffered = false
-- Y de la cuenta de disparos de las armas a distancia.
local shots = RangedChain.newState()
-- Quién quiere saber de cada disparo que sale (el arma en primera persona del Laboratorio).
local shotListeners: { (weapon: Weapons.WeaponDefinition) -> () } = {}

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

-- Por dónde va la cadena de golpes o la cuenta de disparos que se usó la última, para el indicador
-- (ChainPipsController): golpes dados, cuántos tiene y hasta cuándo sigue (os.clock). nil si no hay
-- ninguna en curso (o el arma a distancia no tiene remate).
export type Progress = { step: number, length: number, untilTime: number }
function WeaponController.progress(): Progress?
	local melee: Progress? = nil
	if chain.step > 0 then
		-- Tras el remate se ve llena hasta que acaba su tajo; si no, hasta que se pasa la ventana.
		local finished = chain.step >= MeleeChain.LENGTH
		melee = {
			step = chain.step,
			length = MeleeChain.LENGTH,
			untilTime = chain.readyAt + if finished then 0 else Config.Chain.LinkWindowSeconds,
		}
	end
	local ranged: Progress? = nil
	local weapon = if shots.weaponId then Weapons[shots.weaponId] else nil
	if shots.shot > 0 and weapon and weapon.finisher then
		local finished = shots.shot >= RangedChain.LENGTH
		ranged = {
			step = shots.shot,
			length = RangedChain.LENGTH,
			untilTime = shots.readyAt + if finished then 0 else Config.RangedChain.LinkWindowSeconds,
		}
	end
	if melee and ranged then
		return if melee.untilTime >= ranged.untilTime then melee else ranged
	end
	return melee or ranged
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

-- Dispara si el arma está lista (true): solo entonces se avisa al servidor, que lleva la misma cuenta.
local function shoot(character: Model, weaponId: string, weapon: Weapons.WeaponDefinition): boolean
	local shot = RangedChain.advance(shots, weaponId, weapon, os.clock())
	if not shot then
		return false
	end
	local projectile = weapon.projectile or "Stone"
	local track = weaponTrack(character, if weapon.lab then weapon.lab.pose else projectile)
	if track then
		track:Play(0.05)
	end
	AbilityFxController.play("WeaponShotFx", character, projectile, RangedChain.isFinisher(weapon, shot))
	for _, listener in shotListeners do
		task.spawn(listener, weapon)
	end
	return true
end

-- Llama a "callback" cada vez que sale un disparo de un arma a distancia de este jugador.
function WeaponController.onShot(callback: (weapon: Weapons.WeaponDefinition) -> ())
	table.insert(shotListeners, callback)
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

-- Temblor corto de la cámara (el remate que da), con el ajuste "cameraShake" (CombatClient/CameraShake).
local function shake(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local amount = Config.Chain.FinisherShakeStuds * CameraShake.scale()
	if not humanoid or amount <= 0 then
		return
	end
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
	local feinted = false
	local mark = Feint.begin("Attack", MeleeChain.windupSeconds(weapon, step), function()
		feinted = true
		chain = MeleeChain.newState()
		if track and track.IsPlaying then
			track:Stop(0.1)
		elseif slashTrack and slashTrack.IsPlaying then
			slashTrack:Stop(0.1)
		end
	end)
	task.delay(MeleeChain.windupSeconds(weapon, step), function()
		Feint.finish(mark)
		if feinted or character.Parent == nil or not swingConnects(character, weapon) then
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
			and not Feint.casting()
		then
			swingChain(character, tool, weaponId, weapon)
		end
	end)
end

-- Zoom del rifle del Laboratorio: el campo de visión de antes, mientras está acercado.
local normalFieldOfView: number? = nil

local function setZoom(on: boolean)
	local camera = Workspace.CurrentCamera
	if not camera or on == (normalFieldOfView ~= nil) then
		return
	end
	local target: number
	if on then
		normalFieldOfView = camera.FieldOfView
		target = Config.Lab.RifleZoomFieldOfView
	else
		target = normalFieldOfView or 70
		normalFieldOfView = nil
	end
	TweenService:Create(camera, TweenInfo.new(ZOOM_SECONDS), { FieldOfView = target }):Play()
end

-- true mientras la mira del rifle está acercada.
function WeaponController.isZoomed(): boolean
	return normalFieldOfView ~= nil
end

local function bindZoom()
	ActionButtons.bind(ZOOM_ACTION, Strings.t("Mira"), function(_, state: Enum.UserInputState, input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			if state == Enum.UserInputState.Begin then
				setZoom(normalFieldOfView == nil)
			end
		elseif state == Enum.UserInputState.Begin then
			setZoom(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setZoom(false)
		end
		return Enum.ContextActionResult.Pass
	end, Enum.UserInputType.MouseButton2 :: any, Enum.KeyCode.ButtonL2)
end

local function unbindZoom()
	ActionButtons.unbind(ZOOM_ACTION)
	setZoom(false)
end

-- Disparo automático en curso: sube con cada pulsación nueva o al soltar, y el bucle anterior se acaba.
local autoFireToken = 0
-- Ya ha sonado el clic de "sin balas" en esta pulsación.
local emptyClicked = false

-- Un uso del arma (un clic, un toque, un disparo del bucle automático). true si ha salido.
local function fire(character: Model, tool: Tool, weaponId: string?, weapon: Weapons.WeaponDefinition?): boolean
	local player = Players.LocalPlayer
	-- Aturdido o caído no se pega (Shared/CombatState; el servidor lo comprueba otra vez).
	if not LifeState.isAlive(player) or not CombatState.canAct(player, "Attack") or Feint.casting() then
		return false
	end
	if weapon and MeleeChain.uses(weapon) then
		swingChain(character, tool, weaponId :: string, weapon)
		return true
	elseif weapon and weapon.kind == "Melee" then
		playSwing(character, weapon)
	elseif weapon and weapon.kind == "Ranged" then
		local magazine = weapon.lab ~= nil and weapon.lab.magazine ~= nil
		if magazine and not LabShooting.canShoot() then
			-- Sin balas: pide recargar y suena el clic una vez por pulsación (si ya recarga, nada).
			if LabShooting.reloadingUntil() == nil then
				LabShooting.reload()
				if not emptyClicked then
					emptyClicked = true
					-- Provisional: el clic de "Pickup"; V9 pondrá el sonido propio de cargador vacío.
					local root = character:FindFirstChild("HumanoidRootPart")
					if root then
						Sfx.play("Pickup", root)
					end
				end
			end
			return false
		end
		if not shoot(character, weaponId :: string, weapon) then
			return false
		end
		if magazine then
			LabShooting.consume()
		end
	end
	-- El cañón de suero (en arco) cae en el punto al que se apunta.
	local lobbed = weapon and weapon.lab and weapon.lab.effect == "AcidBurst"
	-- Dirección, punto (solo el cañón), de dónde sale y la hora: el servidor compensa el lag y comprueba el origen.
	-- Y si la mira está acercada (el rifle): la dispersión del tiro la pone el servidor.
	Remotes.UseWeapon:FireServer(
		Aim.direction(character),
		if lobbed then Aim.point(character) else nil,
		Aim.origin(character),
		Workspace:GetServerTimeNow(),
		normalFieldOfView ~= nil
	)
	return true
end

-- Repite el disparo mientras se mantenga el gatillo (se corta con Deactivated, al desequipar, al morir o
-- si el estado ya no deja atacar). El ritmo lo marca la cadencia del arma (RangedChain), que no deja salir
-- el tiro antes de tiempo: el bucle solo lo intenta en cada fotograma.
local function autoFire(tool: Tool, weaponId: string, weapon: Weapons.WeaponDefinition)
	autoFireToken += 1
	local token = autoFireToken
	task.spawn(function()
		local player = Players.LocalPlayer
		while
			autoFireToken == token
			and tool.Parent == player.Character
			and LifeState.isAlive(player)
			and CombatState.canAct(player, "Attack")
		do
			local character = player.Character
			if character then
				fire(character, tool, weaponId, weapon)
			end
			task.wait()
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
		if not character then
			return
		end
		emptyClicked = false
		if weapon and weapon.lab and weapon.lab.automatic then
			autoFire(instance, weaponId :: string, weapon)
		else
			fire(character, instance, weaponId :: string?, weapon)
		end
	end)
	instance.Deactivated:Connect(function()
		autoFireToken += 1
	end)
	instance.Unequipped:Connect(function()
		autoFireToken += 1
	end)
	if weapon and weapon.kind == "Ranged" then
		instance.Equipped:Connect(function()
			local character = Players.LocalPlayer.Character
			if character then
				holdArm(character)
			end
		end)
		instance.Unequipped:Connect(releaseArm)
		if weapon.lab and weapon.lab.zoom then
			instance.Equipped:Connect(bindZoom)
			instance.Unequipped:Connect(unbindZoom)
		end
		local character = Players.LocalPlayer.Character
		if character and instance.Parent == character then
			holdArm(character)
			if weapon.lab and weapon.lab.zoom then
				bindZoom()
			end
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
	autoFireToken += 1
	table.clear(weaponTracks)
	unbindZoom()
	watch(character)
	watch(Players.LocalPlayer:WaitForChild("Backpack"))
end

function WeaponController:Start()
	local player = Players.LocalPlayer
	-- Si le tambalean (un parry, un golpe en PvP), le aturden o se pone en guardia, el servidor corta la
	-- cadena y la cuenta de disparos: aquí también vuelven al primero.
	player:GetAttributeChangedSignal(CombatState.ATTRIBUTE):Connect(function()
		local state = CombatState.get(player)
		if state ~= "Idle" and state ~= "Attacking" then
			chain = MeleeChain.newState()
			shots.shot = 0
		end
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return WeaponController
