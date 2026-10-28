--!strict
-- Primera persona del Laboratorio (docs/LABORATORIO.md §2). La cámara la fija el place
-- (StarterPlayer.CameraMode = LockFirstPerson, laboratorio.project.json); aquí:
--   - La mira: una cruz fija en el centro de la pantalla, en lugar del cursor. Se apunta con el centro
--     en todos los dispositivos (CombatClient/Aim: con ratón, el cursor está ahí; sin él, la cámara).
--   - El arma en primera persona: Roblox esconde el personaje propio (y el arma en su mano; aquí se
--     esconde también la que cambia de piezas al cambiar de facción), así que se dibuja una copia del arma equipada (Shared/LabWeaponModels, con la facción "LabFaction") con las
--     manos, pegada a la cámara abajo a la derecha. Con el rifle acercado (WeaponController) se centra
--     para apuntar por la mira, y cada disparo la echa un poco atrás (retroceso).
-- Los demás ven el arma en la mano del personaje, con sus animaciones de siempre.
-- El ratón va bloqueado en el centro. Para pulsar una ventana (el selector de arma, los resultados, el
-- panel de pruebas) se suelta con freeCursor: mientras alguien lo pida, un botón invisible con Modal deja
-- el ratón libre (es lo que respeta la cámara de Roblox), se ve el cursor y se esconde la mira. En PC,
-- Ctrl lo suelta y lo vuelve a bloquear a mano: la misma tecla que bloquea el ratón en el centro en la
-- Isla y el Lobby (CameraLockController, que aquí no se carga). No Alt: en Studio, Alt es un atajo que
-- dibuja el esqueleto del personaje, y en Windows activa el menú. Con el ratón suelto, Ctrl vuelve a apuntar
-- siempre: también cierra lo que se puede cerrar (el panel de pruebas, onLockRequested). Solo el selector
-- de arma y los resultados lo tienen suelto mientras están abiertos (needsCursor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LabWeaponModels = require(ReplicatedStorage.Shared.LabWeaponModels)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local WeaponController = require(ReplicatedStorage.CombatClient.Controllers.WeaponController)

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
local RECOIL_STUDS = 0.18
local RECOIL_RETURN = 12 -- por segundo
local SWAY = 0.04
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
local recoil = 0
local normalFieldOfView = 70
-- Teclas para soltar y volver a bloquear el ratón a mano.
local CURSOR_KEYS = { [Enum.KeyCode.LeftControl] = true, [Enum.KeyCode.RightControl] = true }
-- Quién pide ahora el ratón libre (el selector, los resultados, la tecla Ctrl…).
local cursorReasons: { [string]: true } = {}
local cursorGui: ScreenGui? = nil
local crosshairGui: ScreenGui? = nil
local cursorChangedListeners: { (free: boolean) -> () } = {}
local lockRequestedListeners: { () -> () } = {}
-- Las ventanas que necesitan el ratón mientras están abiertas (Ctrl no se lo quita).
local WINDOW_REASONS = { Loadout = true, Results = true }

local function clearViewModel()
	if viewModel then
		viewModel:Destroy()
		viewModel = nil
	end
	shownKey = nil
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
	local faction = LabWeaponModels.faction(player:GetAttribute("LabFaction"))
	local key = `{weaponId}/{faction}`
	if key == shownKey and viewModel and viewModel.Parent then
		return
	end
	clearViewModel()
	-- Las piezas se hacen en una Tool suelta y se pasan a un modelo pegado a la cámara.
	local holder = Instance.new("Tool")
	local handle = LabWeaponModels.build(holder, weaponId, faction)
	local model = Instance.new("Model")
	model.Name = "ArmaEnPrimeraPersona"
	for _, part in holder:GetChildren() do
		part.Parent = model
	end
	holder:Destroy()
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

-- Cruz fija en el centro de la pantalla (sin el cursor de Roblox). Blanca con borde oscuro: se ve en
-- cualquier fondo y no usa los colores con significado.
local function crosshair(player: Player)
	local gui = Widgets.screen("Mira", player:WaitForChild("PlayerGui"))
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Enabled = not isCursorFree()
	crosshairGui = gui
	local function bar(size: UDim2, offset: UDim2)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5) + offset
		frame.Size = size
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BorderSizePixel = 0
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 20, 20)
		stroke.Transparency = 0.3
		stroke.Thickness = 1
		stroke.Parent = frame
		frame.Parent = gui
	end
	bar(UDim2.fromOffset(3, 3), UDim2.new())
	for _, offset in { UDim2.fromOffset(-11, 0), UDim2.fromOffset(11, 0) } do
		bar(UDim2.fromOffset(9, 2), offset)
	end
	for _, offset in { UDim2.fromOffset(0, -11), UDim2.fromOffset(0, 11) } do
		bar(UDim2.fromOffset(2, 9), offset)
	end
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
	-- Muerto (o eliminado de la ronda, de espectador): sin el arma delante de la cámara.
	if viewModel and isDead(Players.LocalPlayer.Character) then
		clearViewModel()
	end
	if not (viewModel and camera and viewModel.PrimaryPart) then
		return
	end
	recoil = math.max(0, recoil - recoil * math.min(1, RECOIL_RETURN * deltaTime))
	-- Acercado con la mira: de 0 (normal) a 1 (del todo).
	local zoom = math.clamp(
		(normalFieldOfView - camera.FieldOfView) / math.max(1, normalFieldOfView - Config.Lab.RifleZoomFieldOfView),
		0,
		1
	)
	local offset = HIP_OFFSET:Lerp(AIM_OFFSET, zoom) + Vector3.new(0, 0, recoil)
	-- Un poco de balanceo al andar (no al apuntar).
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		local t = os.clock() * 8
		offset += Vector3.new(math.sin(t) * SWAY, math.abs(math.cos(t)) * SWAY, 0) * (1 - zoom)
	end
	local hip = 1 - zoom
	local hand = camera.CFrame * CFrame.new(offset) * CFrame.Angles(HIP_PITCH * hip, HIP_YAW * hip, 0) * WEAPON_TURN
	viewModel:PivotTo(hand * GRIP:Inverse())
end

function FirstPersonController:Start()
	local player = Players.LocalPlayer
	UserInputService.MouseIconEnabled = isCursorFree()
	crosshair(player)
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
		if weapon.lab then
			recoil = RECOIL_STUDS * (if weapon.lab.zoom then 2 else 1)
		end
	end)
	player:GetAttributeChangedSignal("LabFaction"):Connect(function()
		refresh(player)
	end)
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
