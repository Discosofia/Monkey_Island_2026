--!strict
-- El golpe a la pelota del Juego de pelota en este cliente (Fase 26d). Mientras ReplicatedStorage "BallActive" sea
-- true: clic izquierdo o F (PC), R2 o X (mando) y el botón «Golpear» (móvil) mandan Remotes.BallHit con hacia dónde
-- mira el jugador, y aplican el golpe en local a la pelota predicha (BallController.predictHit) con la misma
-- matemática que el servidor (Shared/BallHit), para que no haya espera. Un anillo sobre la pelota se cierra hacia
-- su tamaño según el tiempo hasta el contacto y se enciende en la ventana buena y en la perfecta. Al golpear suena
-- la animación de la zona (BallHip, BallKnee, BallElbow de Data/PlayerAnimations; sin id publicado no se hace nada).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local BallHit = require(ReplicatedStorage.Shared.BallHit)
local BallSim = require(ReplicatedStorage.Shared.BallSim)
local ActionButtons = require(ReplicatedStorage.CombatClient.ActionButtons)
local Aim = require(ReplicatedStorage.CombatClient.Aim)
local BodyAnimations = require(ReplicatedStorage.CombatClient.BodyAnimations)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Data = require(ReplicatedStorage.Shared.Data.Ballgame)
local PlayerAnimations = require(ReplicatedStorage.Shared.Data.PlayerAnimations)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local BallController = require(script.Parent.BallController)

local T = Strings.t
local Hit = Data.Hit
local CENTER = CourtGeometry.CENTER
local RADIUS = CourtGeometry.BALL_RADIUS

local ACTION = "BallHit"
-- Casilla del botón táctil: junto al pulgar, donde en la Isla va el diario (en Dunas no hay).
local BUTTON_SLOT = Vector2.new(1, 1)
-- Animación de cada zona (Shared/Data/WeaponAnimations) y lo que dura sonando.
local ANIMATION_OF: { [string]: PlayerAnimations.Key } = { Knee = "BallKnee", Hip = "BallHip", Elbow = "BallElbow" }
local ANIMATION_SECONDS = 0.7
-- El anillo: lado del BillboardGui en studs; el círculo va de START_SCALE veces la pelota a su tamaño.
local RING_STUDS = 6
local RING_START_SCALE = 3
local RING_THICKNESS = 3
-- Colores: amarillo cálido en la ventana buena, blanco dorado en la perfecta, tenue fuera de ellas.
local RING_WEAK = Color3.fromRGB(210, 190, 140)
local RING_GOOD = Color3.fromRGB(255, 190, 60)
local RING_PERFECT = Color3.fromRGB(255, 244, 190)

local BallHitController = {}

local nextHitAt = 0 -- reloj local (os.clock) desde el que se puede volver a golpear
local bound = false
local ring: BillboardGui? = nil
local ringFrame: Frame? = nil
local ringStroke: UIStroke? = nil
local lastAnimationAt = -math.huge

local function active(): boolean
	return ReplicatedStorage:GetAttribute("BallActive") == true
end

local function myRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Hacia dónde mira el jugador: del cuerpo al punto que apunta (Aim); sin él, la cámara.
local function lookDirection(root: BasePart): Vector3
	local camera = Workspace.CurrentCamera
	local fallback = if camera then camera.CFrame.LookVector else root.CFrame.LookVector
	local character = Players.LocalPlayer.Character
	if not character then
		return fallback
	end
	local offset = Aim.point(character) - root.Position
	if offset.Magnitude < 1e-3 then
		return fallback
	end
	return offset.Unit
end

-- Reproduce la animación de la zona; sin id publicado no hace nada.
local function playAnimation(zone: string)
	local key = ANIMATION_OF[zone]
	if not key or not BodyAnimations.has(key) then
		return
	end
	lastAnimationAt = os.clock()
	-- La pista suena en el Animator propio y Roblox la replica: los demás jugadores la ven sin más.
	BodyAnimations.play(key)
end

-- ¿Puede golpear la pelota predicha este jugador ahora? Devuelve su estado, su posición local y la zona.
local function reachable(root: BasePart): (BallSim.State?, Vector3, string?)
	local ball = BallController.predictedState()
	local playerPos = root.Position - CENTER
	if ball == nil then
		return nil, playerPos, nil
	end
	local team = Arena.teamOf(Players.LocalPlayer)
	local side = CourtGeometry.teamOfSide(ball.pos.X)
	if team == nil or (side ~= nil and side ~= team) or (ball.pos - playerPos).Magnitude > Hit.Reach then
		return nil, playerPos, nil
	end
	return ball, playerPos, BallHit.zoneOf(ball.pos.Y - playerPos.Y)
end

local layoutCache: CourtGeometry.Layout? = nil
local layoutFormat = -1

local function layout(): CourtGeometry.Layout
	local format = Arena.format()
	local cached = layoutCache
	if cached == nil or format ~= layoutFormat then
		cached = CourtGeometry.forFormat(format)
		layoutCache = cached
		layoutFormat = format
	end
	return cached :: CourtGeometry.Layout
end

local function hit()
	if not active() or os.clock() < nextHitAt then
		return
	end
	local root = myRoot()
	if not root then
		return
	end
	local ball, playerPos, zone = reachable(root)
	if ball == nil or zone == nil then
		return
	end
	nextHitAt = os.clock() + Hit.CooldownSeconds
	local lookDir = lookDirection(root)
	Remotes.BallHit:FireServer(lookDir)

	local ttc = BallHit.timeToContact(ball, layout(), playerPos, Hit.ContactDist, Hit.RingLeadSeconds)
	local quality = BallHit.quality(ttc, 0)
	local rivalSign = BallHit.rivalSign(Arena.teamOf(Players.LocalPlayer))
	BallController.predictHit(BallHit.velocity(zone, quality, lookDir, rivalSign))
	playAnimation(zone)
end

-- ============================================================================ Anillo

local function ensureRing(): BillboardGui
	local existing = ring
	if existing then
		return existing
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BallHitRing"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromScale(RING_STUDS, RING_STUDS)
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = RING_THICKNESS
	stroke.Color = RING_WEAK
	stroke.Parent = frame
	frame.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	ring = gui
	ringFrame = frame
	ringStroke = stroke
	return gui
end

local function hideRing()
	local gui = ring
	if gui and gui.Enabled then
		gui.Enabled = false
	end
end

local function onRender()
	local part = BallController.part()
	local root = myRoot()
	if not (active() and part and root) or os.clock() < nextHitAt then
		hideRing()
		return
	end
	local ball, playerPos, zone = reachable(root)
	if ball == nil or zone == nil then
		hideRing()
		return
	end
	local ttc = BallHit.timeToContact(ball, layout(), playerPos, Hit.ContactDist, Hit.RingLeadSeconds)
	if ttc == nil then
		hideRing()
		return
	end
	local gui = ensureRing()
	local frame, stroke = ringFrame :: Frame, ringStroke :: UIStroke
	-- Del tamaño de arranque (progress 1) al de la pelota (progress 0), en fracción del lado del BillboardGui.
	local progress = math.clamp(ttc / Hit.RingLeadSeconds, 0, 1)
	local ballFraction = 2 * RADIUS / RING_STUDS
	local scale = ballFraction * (1 + (RING_START_SCALE - 1) * progress)
	frame.Size = UDim2.fromScale(scale, scale)
	local quality = BallHit.quality(ttc, 0)
	stroke.Color = if quality == "Perfect" then RING_PERFECT elseif quality == "Good" then RING_GOOD else RING_WEAK
	gui.Adornee = part
	gui.Enabled = true
end

-- ============================================================================ Entradas

local function onAction(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult?
	if state == Enum.UserInputState.Begin then
		hit()
	end
	return Enum.ContextActionResult.Sink
end

-- Enlaza el botón táctil y el mando mientras la pelota está activa; los suelta al apagarse.
local function refreshBinding()
	local shouldBind = active()
	if shouldBind == bound then
		return
	end
	bound = shouldBind
	if shouldBind then
		ActionButtons.setSlot(ACTION, BUTTON_SLOT)
		ActionButtons.bind(ACTION, T("Golpear"), onAction, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonX)
	else
		ActionButtons.unbind(ACTION)
		hideRing()
	end
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or not active() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F then
		hit()
	end
end

-- El golpe propio confirmado por el servidor (también el roce): si no sonó ya la animación, suena.
local function onEvent(event: any)
	if typeof(event) ~= "table" or event.kind ~= "hit" or event.userId ~= Players.LocalPlayer.UserId then
		return
	end
	if
		event.quality ~= "Passive"
		and typeof(event.zone) == "string"
		and os.clock() - lastAnimationAt > ANIMATION_SECONDS
	then
		playAnimation(event.zone)
	end
end

function BallHitController:Start()
	UserInputService.InputBegan:Connect(onInputBegan)
	Remotes.BallEvent.OnClientEvent:Connect(onEvent)
	ReplicatedStorage:GetAttributeChangedSignal("BallActive"):Connect(refreshBinding)
	refreshBinding()
	RunService.RenderStepped:Connect(onRender)
end

return BallHitController
