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
-- mano se mantiene su pose de apuntar ("Aim*", en bucle; Data/WeaponAim) y al disparar hace el movimiento
-- de su tipo de arma (tensar el arco, estirar la honda, lanzar el hechizo, soplar la cerbatana),
-- con más prioridad que la pose de empuñar de Roblox. Corriendo, el arma baja ("Hold": el brazo colgando)
-- y vuelve a apuntar al parar (Config.WeaponPose; Fase 19, W2). Sin la pista de apuntar publicada, se
-- queda en Hold. Los demás las ven por el atributo "AimPose" del servidor (RemoteWeaponPoseController);
-- la bocanada y el destello (AbilityFxController, "WeaponShotFx") también se los manda el servidor.
-- Disparo de remate (C9b, Shared/RangedChain): aquí se predice la cuenta de disparos seguidos para que
-- el destello del remate salga al momento; el proyectil y lo que hace los decide el servidor.
-- Laboratorio (Fase 13, Data/LabWeapons): cada arma dispara con la animación de su "pose".
-- Apuntar (Fase 19, W7; Config.Aim): todas las armas a distancia acercan la vista (su "aimFov") mientras se
-- mantiene apuntado: clic derecho o gatillo izquierdo del mando, o el botón "Mira" en el móvil (uno lo pone y
-- otro lo quita). En tercera persona, ShoulderAimController pone además la cámara al hombro.
-- Cargador (Fase 15, V8; CombatClient/LabShooting): con un arma de "lab.magazine" solo se dispara si hay
-- balas y no se recarga (vacía, pide recargar y suena un clic una vez por pulsación), cada tiro gasta una
-- y se manda al servidor si se apunta (5.º argumento de UseWeapon), que pone la dispersión (la del cargador en
-- el Laboratorio; en los demás places, la de la cadera o la de apuntar: LabSpread.hip).
-- Las automáticas ("lab.automatic") repiten el disparo a su cadencia mientras se mantiene el gatillo.
-- Bala inmediata (Fase 19, W4): el disparo directo de un arma a distancia (no el cañón de suero en arco) dibuja
-- su bala al momento (AbilityFxController.localShot) desde la boca del arma, con la dispersión del tiro
-- calculada con el número de disparo (6.º argumento de UseWeapon) y la semilla ShotSeed (Shared/LabSpread), y el
-- servidor le manda solo el ack con su dirección real.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)
local LabSpread = require(ReplicatedStorage.Shared.LabSpread)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MeleeBox = require(ReplicatedStorage.Shared.MeleeBox)
local MeleeChain = require(ReplicatedStorage.Shared.MeleeChain)
local RangedChain = require(ReplicatedStorage.Shared.RangedChain)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local WeaponAim = require(ReplicatedStorage.Shared.Data.WeaponAim)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local AbilityFxController = require(script.Parent.AbilityFxController)
local ActionButtons = require(script.Parent.Parent.ActionButtons)
local Aim = require(script.Parent.Parent.Aim)
local CameraShake = require(script.Parent.Parent.CameraShake)
local Feint = require(script.Parent.Parent.Feint)
local LabShooting = require(script.Parent.Parent.LabShooting)
local MuzzleSource = require(script.Parent.Parent.MuzzleSource)
local Stamina = require(script.Parent.Parent.Stamina)
local WeaponAnimationIds = require(script.Parent.Parent.WeaponAnimationIds)

-- Tajo estándar de Roblox, por si el personaje no trae el suyo en su script Animate.
local DEFAULT_SLASH: { [Enum.HumanoidRigType]: string } = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://522635514",
	[Enum.HumanoidRigType.R6] = "rbxassetid://129967390",
}
local SHAKE_SECONDS = 0.15
local ZOOM_ACTION = "Zoom"

local WeaponController = {}

local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local slashTrack: AnimationTrack? = nil
local lastSwingAt = -math.huge
-- Animaciones de armas ya cargadas en el personaje actual, por clave.
local weaponTracks: { [string]: AnimationTrack } = {}
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
	local id = WeaponAnimationIds.get(key)
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
	-- Las poses de apuntar (Aim*, en bucle) van al nivel de Hold: el disparo las tapa.
	local aiming = string.sub(key, 1, 3) == "Aim"
	track.Priority = if key == "Hold" or aiming
		then Enum.AnimationPriority.Action
		elseif key == "Guard" then Enum.AnimationPriority.Action3
		else Enum.AnimationPriority.Action2
	track.Looped = key == "Hold" or key == "Guard" or aiming
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

-- El arma a distancia equipada (clave de su disparo) y el bucle que la baja al correr (Fase 19, W2).
local aimKey: string? = nil
local aimLoop: RBXScriptConnection? = nil
local aimLowered = false

-- Pone la pose que toca: apuntando (su Aim*, o Hold si aún no está publicada) o, corriendo, el arma
-- bajada (Hold). Las dos van al mismo nivel y la que entra funde con la que sale.
local function applyAim(character: Model)
	local key = aimKey
	if not key then
		return
	end
	local hold = weaponTrack(character, "Hold")
	local aimName = WeaponAim.AimOf[key]
	local aim = if aimName then weaponTrack(character, aimName) else nil
	local want = if aim and not aimLowered then aim else hold
	local other = if want == aim then hold else aim
	local fade = if aimLowered then Config.WeaponPose.LowerFadeSeconds else Config.WeaponPose.AimFadeSeconds
	if want and not want.IsPlaying then
		want:Play(fade)
	end
	if other and other.IsPlaying then
		other:Stop(fade)
	end
end

local function stopAimLoop()
	if aimLoop then
		aimLoop:Disconnect()
		aimLoop = nil
	end
	aimKey = nil
	aimLowered = false
end

-- Saca el arma a distancia "weapon": la pose de apuntar y, mientras dura, vigila si corre.
local function aimArm(character: Model, weapon: Weapons.WeaponDefinition)
	aimKey = if weapon.lab then weapon.lab.pose else weapon.projectile or "Stone"
	aimLowered = Config.WeaponPose.LowerWhileSprinting and Stamina.isSprinting()
	applyAim(character)
	if aimLoop then
		return
	end
	aimLoop = RunService.Heartbeat:Connect(function()
		local current = Players.LocalPlayer.Character
		local sprinting = Config.WeaponPose.LowerWhileSprinting and Stamina.isSprinting()
		if current and sprinting ~= aimLowered then
			aimLowered = sprinting
			applyAim(current)
		end
	end)
end

local function releaseArm()
	stopAimLoop()
	local fade = Config.WeaponPose.AimFadeSeconds
	if weaponTracks.Hold then
		weaponTracks.Hold:Stop(fade)
	end
	for _, aimName in WeaponAim.AimOf do
		if weaponTracks[aimName] then
			weaponTracks[aimName]:Stop(fade)
		end
	end
end

-- Dispara si el arma está lista (true): solo entonces se avisa al servidor, que lleva la misma cuenta.
-- El segundo valor dice si es el disparo de remate.
local function shoot(character: Model, weaponId: string, weapon: Weapons.WeaponDefinition): (boolean, boolean)
	local shot = RangedChain.advance(shots, weaponId, weapon, os.clock())
	if not shot then
		return false, false
	end
	local finisher = RangedChain.isFinisher(weapon, shot)
	local projectile = weapon.projectile or "Stone"
	local pose = if weapon.lab then weapon.lab.pose else projectile
	local fallback = WeaponAim.Fallback[pose]
	local track = weaponTrack(character, pose) or (fallback and weaponTrack(character, fallback))
	if track then
		track:Play(0.05)
	end
	AbilityFxController.play("WeaponShotFx", character, projectile, finisher)
	for _, listener in shotListeners do
		task.spawn(listener, weapon)
	end
	return true, finisher
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
	local box, size = MeleeBox.compute(character, root, weapon.range)
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
-- Sale por CameraShake.play y no por Humanoid.CameraOffset: ese lo usa la cámara al hombro (W7).
local function shake()
	-- "fuerza" 1 de CameraShake ≈ 0,4 studs de temblor.
	CameraShake.play(Config.Chain.FinisherShakeStuds / 0.4, SHAKE_SECONDS)
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
			shake()
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

-- Apuntar (Fase 19, W7), con cualquier arma a distancia: clic derecho, gatillo izquierdo o el botón "Mira"
-- (en móvil uno lo pone y otro lo quita). El campo de visión baja al "aimFov" del arma. La cámara al hombro la
-- pone ShoulderAimController; la dispersión del tiro, el servidor (CombatRules.takeShot).
local aiming = false
-- El campo de visión de antes de apuntar y el de apuntar con el arma de la mano. Se conservan al soltar:
-- aimAlpha() los necesita mientras el campo de visión vuelve.
local aimBase = 70
local aimTarget = 70
local heldWeapon: Weapons.WeaponDefinition? = nil

-- Cuánto se ha acercado la vista: de 0 (normal) a 1 (del todo).
local function aimAlphaNow(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 0
	end
	return math.clamp((aimBase - camera.FieldOfView) / math.max(1, aimBase - aimTarget), 0, 1)
end

local function setAim(on: boolean)
	local camera = Workspace.CurrentCamera
	local weapon = heldWeapon
	if not camera or on == aiming or (on and not weapon) then
		return
	end
	aiming = on
	if on and weapon then
		-- Con la vista aún volviendo de apuntar, el normal sigue siendo el de antes.
		if aimAlphaNow() <= 0.01 then
			aimBase = camera.FieldOfView
		end
		aimTarget = math.min(weapon.aimFov or Config.Aim.ShoulderFov, aimBase * 0.85)
	end
	TweenService
		:Create(
			camera,
			TweenInfo.new(Config.Aim.TransitionSeconds),
			{ FieldOfView = if on then aimTarget else aimBase }
		)
		:Play()
end

-- true mientras se apunta (y se está vivo con el arma en la mano).
function WeaponController.isAiming(): boolean
	return aiming
end

-- De 0 a 1, cuánto se ha acercado la vista al apuntar (sigue el campo de visión real, con su transición).
function WeaponController.aimAlpha(): number
	return aimAlphaNow()
end

local function bindAim(weapon: Weapons.WeaponDefinition)
	heldWeapon = weapon
	ActionButtons.bind(ZOOM_ACTION, Strings.t("Mira"), function(_, state: Enum.UserInputState, input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			if state == Enum.UserInputState.Begin then
				setAim(not aiming)
			end
		elseif state == Enum.UserInputState.Begin then
			setAim(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setAim(false)
		end
		return Enum.ContextActionResult.Pass
	end, Enum.UserInputType.MouseButton2 :: any, Enum.KeyCode.ButtonL2)
end

-- "weapon": el arma que se suelta; si ya hay otra en la mano (cambio de arma), no se toca.
local function unbindAim(weapon: Weapons.WeaponDefinition?)
	if weapon and heldWeapon ~= weapon then
		return
	end
	ActionButtons.unbind(ZOOM_ACTION)
	setAim(false)
	heldWeapon = nil
end

-- Disparo automático en curso: sube con cada pulsación nueva o al soltar, y el bucle anterior se acaba.
local autoFireToken = 0
-- Ya ha sonado el clic de "sin balas" en esta pulsación.
local emptyClicked = false

-- Número del último disparo propio de esta vida, y la semilla y el personaje con los que se cuenta (vuelve a
-- 0 al aparecer de nuevo o al cambiar el atributo ShotSeed del servidor).
local shotSeq = 0
local seqSeed: any = nil
local seqCharacter: Model? = nil

-- De dónde se ve salir la bala propia: la boca del arma de la vista (Laboratorio, MuzzleSource) y, si no, el
-- Attachment "Muzzle" o el Handle de la herramienta. El segundo valor dice si es la vista en primera persona.
local function muzzlePosition(tool: Tool): (Vector3?, boolean)
	local viewMuzzle = MuzzleSource.get()
	if viewMuzzle then
		return viewMuzzle, true
	end
	local muzzle = tool:FindFirstChild("Muzzle", true)
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle.WorldPosition, false
	end
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle.Position, false
	end
	return nil, false
end

-- Dibuja ya la bala del disparo directo de "weapon" y devuelve su número de disparo para mandarlo al
-- servidor (nil si no hay semilla o boca: entonces el servidor la manda a todos, como antes). Hay que llamarla
-- antes de LabShooting.consume(), que suma la dispersión de este tiro.
local function launchLocalShot(
	character: Model,
	tool: Tool,
	weapon: Weapons.WeaponDefinition,
	finisher: boolean,
	aimOrigin: Vector3,
	aimDirection: Vector3
): number?
	local seed = Players.LocalPlayer:GetAttribute("ShotSeed")
	local muzzle, firstPerson = muzzlePosition(tool)
	if typeof(seed) ~= "number" or not muzzle then
		return nil
	end
	if seqCharacter ~= character or seqSeed ~= seed then
		seqCharacter = character
		seqSeed = seed
		shotSeq = 0
	end
	shotSeq += 1
	local seq = shotSeq
	-- La misma dispersión que pone el servidor: la del cargador (Laboratorio) o la de la cadera / de apuntar.
	local degrees = if weapon.lab and weapon.lab.magazine
		then LabShooting.spreadDegrees(aiming)
		else LabSpread.hip(weapon, aiming)
	local spreadDirection = LabSpread.apply(aimDirection, seed, seq, degrees)
	local settings = if finisher then RangedChain.settings(weapon) else nil
	local style = weapon.projectile or "Stone"
	-- A qué distancia converge lo que se ve con la línea de tiro: la del punto al que se apunta.
	local distance = math.clamp((Aim.point(character) - aimOrigin).Magnitude, 10, weapon.range)
	AbilityFxController.localShot({
		seq = seq,
		lookId = if finisher then `{style}Finisher` else style,
		muzzle = muzzle,
		aimOrigin = aimOrigin,
		aimDirection = spreadDirection,
		distance = distance,
		speed = weapon.projectileSpeed or 120,
		range = weapon.range,
		pierce = settings ~= nil and settings.pierceTargets ~= nil,
		extra = if settings and settings.radius then { settings.radius } else nil,
		firstPerson = firstPerson,
	})
	return seq
end

-- Un uso del arma (un clic, un toque, un disparo del bucle automático). true si ha salido.
local function fire(character: Model, tool: Tool, weaponId: string?, weapon: Weapons.WeaponDefinition?): boolean
	local player = Players.LocalPlayer
	-- Aturdido o caído no se pega (Shared/CombatState; el servidor lo comprueba otra vez).
	if not LifeState.isAlive(player) or not CombatState.canAct(player, "Attack") or Feint.casting() then
		return false
	end
	local aimOrigin: Vector3? = nil
	local aimDirection: Vector3? = nil
	local claimedSeq: number? = nil
	local lobbedShot = false
	if weapon and MeleeChain.uses(weapon) then
		swingChain(character, tool, weaponId :: string, weapon)
		return true
	elseif weapon and weapon.kind == "Melee" then
		playSwing(character, weapon)
	elseif weapon and weapon.kind == "Ranged" then
		local lobbed = weapon.lab ~= nil and weapon.lab.effect == "AcidBurst"
		local magazine = weapon.lab ~= nil and weapon.lab.magazine ~= nil
		if magazine and not LabShooting.canShoot() then
			-- Sin balas: pide recargar y suena el clic una vez por pulsación (si ya recarga, nada).
			if LabShooting.reloadingUntil() == nil then
				LabShooting.reload()
				if not emptyClicked then
					emptyClicked = true
					local root = character:FindFirstChild("HumanoidRootPart")
					if root then
						Sfx.play("LabEmpty", root)
					end
				end
			end
			return false
		end
		local ready, finisher = shoot(character, weaponId :: string, weapon)
		if not ready then
			return false
		end
		aimOrigin = Aim.origin(character)
		aimDirection = Aim.direction(character)
		-- El cañón de suero (en arco) lo dibuja el servidor; el resto, la bala propia al momento.
		if not lobbed then
			claimedSeq = launchLocalShot(character, tool, weapon, finisher, aimOrigin, aimDirection)
		end
		if magazine then
			LabShooting.consume()
		end
		lobbedShot = lobbed
	end
	-- Dirección, punto (solo el cañón de suero, que cae en el punto al que se apunta), de dónde sale y la hora:
	-- el servidor compensa el lag y comprueba el origen. Y si la mira está acercada (el rifle): la dispersión
	-- del tiro la pone el servidor, con el número de disparo y la semilla si se ha dibujado la bala propia.
	Remotes.UseWeapon:FireServer(
		aimDirection or Aim.direction(character),
		if lobbedShot then Aim.point(character) else nil,
		aimOrigin or Aim.origin(character),
		Workspace:GetServerTimeNow(),
		aiming,
		claimedSeq
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
				aimArm(character, weapon)
			end
		end)
		instance.Unequipped:Connect(releaseArm)
		instance.Equipped:Connect(function()
			bindAim(weapon)
		end)
		instance.Unequipped:Connect(function()
			unbindAim(weapon)
		end)
		local character = Players.LocalPlayer.Character
		if character and instance.Parent == character then
			aimArm(character, weapon)
			bindAim(weapon)
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
	stopAimLoop()
	autoFireToken += 1
	table.clear(weaponTracks)
	unbindAim(nil)
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
	-- Caído, deja de apuntar (el arma sigue en la mano).
	player:GetAttributeChangedSignal(LifeState.ATTRIBUTE):Connect(function()
		if not LifeState.isAlive(player) then
			setAim(false)
		end
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return WeaponController
