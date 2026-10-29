--!strict
-- Primera persona del Laboratorio (docs/LABORATORIO.md §2). La cámara la fija el place
-- (StarterPlayer.CameraMode = LockFirstPerson, laboratorio.project.json); aquí:
--   - La mira (UI/Crosshair, configurable en Ajustes: forma, color, tamaño, grosor y dinámica): fija en el
--     centro de la pantalla, en lugar del cursor. FirstPersonController.crosshair() da su Handle (dispersión y
--     recarga). Se apunta con el centro en todos los dispositivos (CombatClient/Aim: con ratón, el cursor está ahí; sin él, la cámara).
--   - El arma en primera persona: Roblox esconde el personaje propio (y el arma en su mano; aquí se
--     esconde también la que cambia de piezas al cambiar de facción), así que se dibuja una copia del arma equipada (Shared/LabWeaponModels, con la facción "LabFaction" y la skin de bajas "<arma>Skin", sin sus piezas
--     "LabBack" de la espalda ni sus partículas) con las
--     manos, pegada a la cámara abajo a la derecha. Con el rifle acercado (WeaponController) se centra
--     para apuntar por la mira. Fase 15, V9: cada disparo la echa atrás y le levanta la boca (retroceso por
--     arma, Config.Lab.View), sube la cámara un poco (CameraShake.scale() a 0 lo apaga) y sale el fogonazo
--     de su boca; al recargar baja y se inclina (el cargador entra con un golpe); al sacarla sube desde abajo.
--   - Deslizarse (CombatClient/Slide): la cámara baja Config.Movement.Slide.CameraDrop con un fundido corto.
--   - Esquivar (Fase 15, V3; CombatClient/DodgeFeel): la cámara se inclina hacia el lado de la esquiva y el
--     arma se aparta un poco.
-- Los demás ven el arma en la mano del personaje, con sus animaciones de siempre.
-- El ratón va bloqueado en el centro. Para pulsar una ventana (el selector de arma, los resultados, el
-- panel de pruebas) se suelta con freeCursor: mientras alguien lo pida, un botón invisible con Modal deja
-- el ratón libre (es lo que respeta la cámara de Roblox), se ve el cursor y se esconde la mira. En PC,
-- Ctrl lo suelta y lo vuelve a bloquear a mano: la misma tecla que bloquea el ratón en el centro en la
-- Isla y el Lobby (CameraLockController, que aquí no se carga). No Alt: en Studio, Alt es un atajo que
-- dibuja el esqueleto del personaje, y en Windows activa el menú. Con el ratón suelto, Ctrl vuelve a apuntar
-- siempre: también cierra lo que se puede cerrar (el panel de pruebas, onLockRequested). Solo el selector
-- de arma, los resultados y los Ajustes (⚙️) lo tienen suelto mientras están abiertos (needsCursor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local LabWeaponModels = require(ReplicatedStorage.Shared.LabWeaponModels)
local LabWeapons = require(ReplicatedStorage.Shared.Data.LabWeapons)
local Crosshair = require(ReplicatedStorage.Shared.UI.Crosshair)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local AbilityFxController = require(ReplicatedStorage.CombatClient.Controllers.AbilityFxController)
local WeaponController = require(ReplicatedStorage.CombatClient.Controllers.WeaponController)
local CameraShake = require(ReplicatedStorage.CombatClient.CameraShake)
local LabShooting = require(ReplicatedStorage.CombatClient.LabShooting)
local DodgeFeel = require(ReplicatedStorage.CombatClient.DodgeFeel)
local Slide = require(ReplicatedStorage.CombatClient.Slide)

-- Dónde va la mano respecto a la cámara (derecha, arriba, delante): abajo a la derecha, con el arma
-- girada un poco hacia el centro (HIP_YAW, HIP_PITCH) para que se le vea el costado; al apuntar con la
-- mira, centrada y recta, con el visor justo bajo la cruz.
local HIP_OFFSET = Vector3.new(1.25, -1.45, -3.0)
local HIP_YAW = math.rad(16)
local HIP_PITCH = 0.08
local AIM_OFFSET = Vector3.new(0, -0.78, -1.6)
-- El arma mira hacia -Z de la cámara con su lado de arriba hacia +Y (ejes de Shared/LabWeaponModels:
-- +Y del mango hacia la boca, -Z del mango hacia arriba).
local WEAPON_TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, -1, 0))
local GRIP = CFrame.new(0, -0.8, 0)
-- Retroceso por defecto si un arma no tiene su fila en Config.Lab.View.
local DEFAULT_KICK = { kickBack = 0.18, kickPitch = 0, kickRoll = 0, camKick = 0, recover = 12 }
local SWAY = 0.04
-- Recarga en la vista (fracciones del tiempo de recarga): baja hasta RELOAD_DOWN, vaivén hasta RELOAD_CLICK,
-- el cargador entra con un golpe corto y vuelve a la posición desde RELOAD_UP.
local RELOAD_DOWN = 0.15
local RELOAD_CLICK = 0.55
local RELOAD_CLICK_WIDTH = 0.05
local RELOAD_UP = 0.85
local RELOAD_DROP = 0.9 -- studs que baja el arma
local RELOAD_TILT = math.rad(35) -- boca arriba
local RELOAD_WOBBLE = 0.12 -- studs de vaivén lateral
local RELOAD_BUMP = 0.12 -- studs que empuja hacia delante el golpe del cargador
-- Sacar el arma: sube desde abajo en DRAW_SECONDS con easing cúbico de salida.
local DRAW_SECONDS = 0.35
local DRAW_DROP = 1.3
local DRAW_TILT = math.rad(40)
-- Mangas de cada facción (la del laboratorio, bata blanca con puño azul; la pirata, negra con oro).
local SLEEVES: { [LabWeaponModels.Faction]: { sleeve: Color3, cuff: Color3 } } = {
	Guardians = { sleeve = Color3.fromRGB(232, 236, 240), cuff = Color3.fromRGB(40, 115, 215) },
	Pirates = { sleeve = Color3.fromRGB(34, 31, 30), cuff = Color3.fromRGB(234, 194, 80) },
}

local FirstPersonController = {}

local viewModel: Model? = nil
-- El arma de la mano del personaje propio, que no se ve en primera persona.
local heldTool: Tool? = nil
local shownKey: string? = nil
type KickView = { kickBack: number, kickPitch: number, kickRoll: number, camKick: number, recover: number }
local kickViews: { [string]: KickView } = Config.Lab.View
-- Retroceso en curso (1 por disparo, hasta 2 en ráfaga) con los números del arma que disparó.
local recoil = 0
local kickView: KickView = DEFAULT_KICK
local kickScale = 1 -- el doble en el arma con zoom
local rollSign = 1
-- Grados que la cámara va subida por el último disparo.
local camPitch = 0
-- Recarga en la vista: ya suena, con qué vista, cuánto había avanzado y si ya dio el golpe del cargador.
local reloadActive = false
local reloadKey: string? = nil
local reloadLastProgress = 0
-- Cuándo se sacó el arma (os.clock).
local drawStart = -math.huge
local normalFieldOfView = 70
-- Teclas para soltar y volver a bloquear el ratón a mano.
local CURSOR_KEYS = { [Enum.KeyCode.LeftControl] = true, [Enum.KeyCode.RightControl] = true }
-- Quién pide ahora el ratón libre (el selector, los resultados, la tecla Ctrl…).
local cursorReasons: { [string]: true } = {}
local cursorGui: ScreenGui? = nil
local crosshairGui: ScreenGui? = nil
local crosshairHandle: Crosshair.Handle? = nil
local cursorChangedListeners: { (free: boolean) -> () } = {}
local lockRequestedListeners: { () -> () } = {}
-- Las ventanas que necesitan el ratón mientras están abiertas (Ctrl no se lo quita).
local WINDOW_REASONS = { Loadout = true, Results = true, Settings = true }

local function clearViewModel()
	if viewModel then
		viewModel:Destroy()
		viewModel = nil
	end
	shownKey = nil
	-- Cambiar de arma o morir corta la recarga de la vista sin sonido de cargador listo.
	reloadActive = false
	reloadKey = nil
end

-- Suena "effect" en el personaje propio.
local function playSfx(effect: string)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root then
		Sfx.play(effect, root)
	end
end

local function block(model: Model, handle: BasePart, name: string, size: Vector3, at: CFrame, color: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = handle.CFrame * at
	part.Parent = model
end

-- Las dos manos y los antebrazos (bloques), sujetando el arma: la derecha en la empuñadura y la izquierda
-- delante, bajo el cajón.
local function arms(model: Model, handle: BasePart, faction: LabWeaponModels.Faction, skin: Color3)
	local colors = SLEEVES[faction]
	-- En los ejes del mango: +Y hacia la boca, +Z hacia abajo.
	block(model, handle, "RightHand", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, -0.8, 0.15), skin)
	block(
		model,
		handle,
		"RightCuff",
		Vector3.new(0.5, 0.2, 0.5),
		CFrame.new(0, -1.15, 0.45) * CFrame.Angles(-0.6, 0, 0),
		colors.cuff
	)
	block(
		model,
		handle,
		"RightSleeve",
		Vector3.new(0.5, 1.4, 0.5),
		CFrame.new(0, -1.75, 0.85) * CFrame.Angles(-0.6, 0, 0),
		colors.sleeve
	)
	block(model, handle, "LeftHand", Vector3.new(0.45, 0.45, 0.45), CFrame.new(-0.05, 0.3, 0.45), skin)
	block(
		model,
		handle,
		"LeftCuff",
		Vector3.new(0.5, 0.2, 0.5),
		CFrame.new(-0.35, 0.05, 0.75) * CFrame.Angles(-0.4, 0, 0.5),
		colors.cuff
	)
	block(
		model,
		handle,
		"LeftSleeve",
		Vector3.new(0.5, 1.4, 0.5),
		CFrame.new(-0.75, -0.35, 1.15) * CFrame.Angles(-0.4, 0, 0.5),
		colors.sleeve
	)
end

local function skinColor(character: Model): Color3
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return if hand and hand:IsA("BasePart") then hand.Color else Color3.fromRGB(205, 160, 120)
end

-- true si el humanoide del personaje está muerto.
local function isDead(character: Model?): boolean
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.Health <= 0
end

-- Monta (o deja como está) el arma en primera persona de lo que lleva en la mano.
local function refresh(player: Player)
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	heldTool = tool
	local weaponId = if tool then tool:GetAttribute("WeaponId") else nil
	local camera = Workspace.CurrentCamera
	if
		not (character and camera and typeof(weaponId) == "string" and LabWeaponModels.has(weaponId))
		or isDead(character)
	then
		clearViewModel()
		return
	end
	local look = LabWeaponModels.lookOf(player, weaponId)
	local faction, skinId = LabWeaponModels.look(look)
	local key = `{weaponId}/{look}`
	if key == shownKey and viewModel and viewModel.Parent then
		return
	end
	clearViewModel()
	-- Las piezas se hacen en una Tool suelta y se pasan a un modelo pegado a la cámara.
	local holder = Instance.new("Tool")
	local handle = LabWeaponModels.build(holder, weaponId, faction, skinId)
	local model = Instance.new("Model")
	model.Name = "ArmaEnPrimeraPersona"
	for _, part in holder:GetChildren() do
		-- Las piezas de la espalda de la skin taparían la mira: solo las ven los demás.
		if part:GetAttribute("LabBack") then
			part:Destroy()
		else
			part.Parent = model
		end
	end
	holder:Destroy()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant:Destroy()
		end
	end
	model.PrimaryPart = handle
	arms(model, handle, faction, skinColor(character))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		elseif part:IsA("WeldConstraint") then
			part:Destroy()
		end
	end
	model.Parent = camera
	viewModel = model
	shownKey = key
	drawStart = os.clock()
	playSfx("LabDraw")
end

local function isCursorFree(): boolean
	return next(cursorReasons) ~= nil
end

-- true mientras el ratón va suelto.
function FirstPersonController.isCursorFree(): boolean
	return isCursorFree()
end

-- true si una ventana que se pulsa (el selector, los resultados) tiene el ratón suelto.
function FirstPersonController.needsCursor(): boolean
	for reason in cursorReasons do
		if WINDOW_REASONS[reason] then
			return true
		end
	end
	return false
end

-- Llama a "callback" cuando se pulsa Ctrl para volver a apuntar: cierra lo suyo (el panel de pruebas).
function FirstPersonController.onLockRequested(callback: () -> ())
	table.insert(lockRequestedListeners, callback)
end

-- Llama a "callback" cada vez que el ratón se suelta o se vuelve a bloquear.
function FirstPersonController.onCursorChanged(callback: (free: boolean) -> ())
	table.insert(cursorChangedListeners, callback)
end

-- Suelta el ratón ("on" true) o deja de pedirlo, por "reason" (cada ventana el suyo).
function FirstPersonController.freeCursor(reason: string, on: boolean)
	local wasFree = isCursorFree()
	cursorReasons[reason] = if on then true else nil
	local free = isCursorFree()
	if not cursorGui then
		local gui = Widgets.screen("RatonLibre", Players.LocalPlayer:WaitForChild("PlayerGui"))
		local button = Instance.new("TextButton")
		button.Name = "Modal"
		button.Size = UDim2.fromOffset(1, 1)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Modal = true
		button.Parent = gui
		cursorGui = gui
	end
	local gui = cursorGui :: ScreenGui
	gui.Enabled = free
	UserInputService.MouseIconEnabled = free
	if crosshairGui then
		crosshairGui.Enabled = not free
	end
	if free ~= wasFree then
		for _, listener in cursorChangedListeners do
			task.spawn(listener, free)
		end
	end
end

-- Mira en el centro de la pantalla (sin el cursor de Roblox), la de UI/Crosshair según los Ajustes.
local function mountCrosshair(player: Player)
	local gui = Widgets.screen("Mira", player:WaitForChild("PlayerGui"))
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Enabled = not isCursorFree()
	crosshairGui = gui
	crosshairHandle = Crosshair.mount(gui)
end

-- La mira (dispersión y recarga la ponen las armas), o nil si aún no está montada.
function FirstPersonController.crosshair(): Crosshair.Handle?
	return crosshairHandle
end

-- Posición y giro del arma al recargar según el avance "progress" (0 a 1): baja y gira con la boca arriba,
-- un vaivén lateral, el golpe del cargador y la vuelta. Devuelve el desplazamiento y el giro (radianes).
local function reloadPose(progress: number): (Vector3, number)
	local dip: number
	if progress < RELOAD_DOWN then
		dip = progress / RELOAD_DOWN
	elseif progress < RELOAD_UP then
		dip = 1
	else
		dip = (1 - progress) / (1 - RELOAD_UP)
	end
	dip = dip * dip * (3 - 2 * dip)
	local wobble = 0
	if progress > RELOAD_DOWN and progress < RELOAD_CLICK then
		wobble = math.sin((progress - RELOAD_DOWN) / (RELOAD_CLICK - RELOAD_DOWN) * math.pi * 3) * RELOAD_WOBBLE * dip
	end
	local bump = math.max(0, 1 - math.abs(progress - RELOAD_CLICK) / RELOAD_CLICK_WIDTH)
	return Vector3.new(wobble, -RELOAD_DROP * dip, -RELOAD_BUMP * bump), RELOAD_TILT * dip
end

-- Acercado con la mira: de 0 (normal) a 1 (del todo).
local function currentZoom(camera: Camera?): number
	if not camera then
		return 0
	end
	return math.clamp(
		(normalFieldOfView - camera.FieldOfView) / math.max(1, normalFieldOfView - Config.Lab.RifleZoomFieldOfView),
		0,
		1
	)
end

-- Avance de la recarga del arma de la mano (0 a 1), o nil si no recarga.
local function reloadProgress(): number?
	local weapon = LabShooting.weapon()
	local finish = LabShooting.reloadingUntil()
	if not (weapon and weapon.lab and finish) then
		return nil
	end
	local seconds = math.max(weapon.lab.reloadSeconds, 0.05)
	return math.clamp(1 - (finish - Workspace:GetServerTimeNow()) / seconds, 0, 1)
end

local function follow(deltaTime: number)
	if heldTool then
		for _, part in heldTool:GetChildren() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
			end
		end
	end
	local camera = Workspace.CurrentCamera
	-- Acercado con la mira: de 0 (normal) a 1 (del todo).
	local zoom = currentZoom(camera)
	-- Deslizándose (Fase 15, V2) la cámara baja. Este paso va después de la cámara de Roblox, que
	-- recalcula su CFrame cada fotograma, así que no se acumula; el arma de la vista la sigue.
	local drop = Slide.currentDrop()
	if camera and drop > 0 then
		camera.CFrame += Vector3.new(0, -drop, 0)
	end
	-- Esquivando (Fase 15, V3) la cámara se inclina hacia el lado de la esquiva; tampoco se acumula.
	local tilt = DodgeFeel.tilt()
	if camera and tilt ~= 0 then
		camera.CFrame *= CFrame.Angles(0, 0, tilt)
	end
	-- Golpe de cámara del disparo (V9): sube y vuelve; tampoco se acumula en el CFrame del jugador.
	camPitch = math.max(0, camPitch - camPitch * math.min(1, kickView.recover * deltaTime))
	if camera and camPitch > 0.001 then
		camera.CFrame *= CFrame.Angles(math.rad(camPitch), 0, 0)
	end
	-- Muerto (o eliminado de la ronda, de espectador): sin el arma delante de la cámara.
	if viewModel and isDead(Players.LocalPlayer.Character) then
		clearViewModel()
	end
	if not (viewModel and camera and viewModel.PrimaryPart) then
		return
	end
	recoil = math.max(0, recoil - recoil * math.min(1, kickView.recover * deltaTime))
	local back = kickView.kickBack * kickScale * recoil
	local offset = HIP_OFFSET:Lerp(AIM_OFFSET, zoom) + Vector3.new(0, 0, back) + DodgeFeel.weaponShift()
	-- El retroceso también gira el arma: la boca sube (pitch) y se tuerce (roll).
	local pitch = math.rad(kickView.kickPitch) * recoil
	local roll = math.rad(kickView.kickRoll) * rollSign * recoil
	-- Recarga: el arma baja y se inclina; suena al empezar y al acabar (si acaba de verdad, no por cambiar de arma).
	local progress = reloadProgress()
	if progress then
		if not reloadActive then
			reloadActive = true
			reloadKey = shownKey
			playSfx("LabReload")
		end
		reloadLastProgress = progress
		local shift, reloadTilt = reloadPose(progress)
		offset += shift
		pitch += reloadTilt
	elseif reloadActive then
		reloadActive = false
		if reloadKey == shownKey and reloadLastProgress > RELOAD_UP then
			playSfx("LabReloadDone")
		end
		reloadKey = nil
	end
	-- Sacar el arma: sube desde abajo, solo visual.
	local drawAlpha = (os.clock() - drawStart) / DRAW_SECONDS
	if drawAlpha < 1 then
		local left = (1 - math.max(drawAlpha, 0)) ^ 3 -- cúbico de salida
		offset += Vector3.new(0, -DRAW_DROP * left, 0)
		pitch += DRAW_TILT * left
	end
	-- Un poco de balanceo al andar (no al apuntar con el rifle acercado).
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 and zoom <= 0.5 then
		local t = os.clock() * 8
		offset += Vector3.new(math.sin(t) * SWAY, math.abs(math.cos(t)) * SWAY, 0) * (1 - zoom)
	end
	local hip = 1 - zoom
	local hand = camera.CFrame
		* CFrame.new(offset)
		* CFrame.Angles(HIP_PITCH * hip + pitch, HIP_YAW * hip, roll)
		* WEAPON_TURN
	viewModel:PivotTo(hand * GRIP:Inverse())
end

function FirstPersonController:Start()
	local player = Players.LocalPlayer
	UserInputService.MouseIconEnabled = isCursorFree()
	mountCrosshair(player)
	UserInputService.InputBegan:Connect(function(input)
		if not CURSOR_KEYS[input.KeyCode] or UserInputService:GetFocusedTextBox() then
			return
		end
		if isCursorFree() then
			FirstPersonController.freeCursor("Key", false)
			for _, listener in lockRequestedListeners do
				task.spawn(listener)
			end
		else
			FirstPersonController.freeCursor("Key", true)
		end
	end)
	local camera = Workspace.CurrentCamera
	if camera then
		normalFieldOfView = camera.FieldOfView
	end
	WeaponController.onShot(function(weapon)
		if not weapon.lab then
			return
		end
		local weaponId = if heldTool then heldTool:GetAttribute("WeaponId") else nil
		kickView = if typeof(weaponId) == "string" and kickViews[weaponId] then kickViews[weaponId] else DEFAULT_KICK
		kickScale = if weapon.lab.zoom then 2 else 1
		recoil = math.min(recoil + 1, 2)
		rollSign = -rollSign
		-- La cámara sube camKick grados (la mitad con el rifle acercado) si los temblores no están apagados.
		local zoomed = weapon.lab.zoom == true and currentZoom(Workspace.CurrentCamera) > 0.5
		local camKick = kickView.camKick * CameraShake.scale() * (if zoomed then 0.5 else 1)
		camPitch = math.min(camPitch + camKick, camKick * 2)
		-- Fogonazo en la boca del arma de la vista (su pieza "Muzzle" o, si no, el Handle).
		local muzzle = if viewModel then viewModel:FindFirstChild("Muzzle", true) or viewModel.PrimaryPart else nil
		if muzzle then
			AbilityFxController.play("LabMuzzle", muzzle, weapon.projectile)
		end
	end)
	player:GetAttributeChangedSignal("LabFaction"):Connect(function()
		refresh(player)
	end)
	for _, weaponId in LabWeapons.ORDER do
		player:GetAttributeChangedSignal(`{weaponId}Skin`):Connect(function()
			refresh(player)
		end)
	end
	local function watch(character: Model)
		clearViewModel()
		character.ChildAdded:Connect(function()
			refresh(player)
		end)
		character.ChildRemoved:Connect(function()
			refresh(player)
		end)
		refresh(player)
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
	RunService:BindToRenderStep("LabViewModel", Enum.RenderPriority.Camera.Value + 1, follow)
end

return FirstPersonController
