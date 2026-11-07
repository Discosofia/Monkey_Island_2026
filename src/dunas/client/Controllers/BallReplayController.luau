--!strict
-- Repetición del aro del Juego de pelota (Fase 27f). Al embocar, el servidor congela la partida y manda a todos las
-- posiciones de los últimos segundos de la pelota (Remotes.BallReplay); este controlador las reproduce a cámara lenta
-- (Config.Arena.Ballgame.Replay.Rate) con un plano lateral del aro, enseña el cartel del equipo que anota y celebra
-- con fanfarria y confeti de su paleta (Shared/PartyFx). Al acabar o saltar (botón «Saltar», Espacio o ✕/A del mando)
-- avisa al servidor con BallReplayDone, que da entonces la victoria.
--   - Con el ajuste «Cinemáticas» apagado no hay repetición ni cámara: solo cartel y sonido, y el aviso sale al instante.
--   - La cámara pasa a Scriptable con un enlace de RenderStep tras el de la cámara del jugador, y se devuelve al
--     acabar junto con el HUD y los controles. Un tope de seguridad la devuelve aunque falle algo.
-- Las posiciones son LOCALES de la cancha; el mundo es CourtGeometry.CENTER + posición.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local BallgameData = require(ReplicatedStorage.Shared.Data.Ballgame)
local FxQuality = require(ReplicatedStorage.Shared.FxQuality)
local PartyFx = require(ReplicatedStorage.Shared.PartyFx)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Strings = require(ReplicatedStorage.Shared.Strings)
local HudHider = require(ReplicatedStorage.Shared.UI.HudHider)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local BallController = require(script.Parent.BallController)

local T = Strings.t

local CENTER = CourtGeometry.CENTER
local RENDER_NAME = "BallReplayCamera"
local SKIP_ACTION = "BallReplaySkip"
local SKIP_GRACE = 0.6 -- segundos al empezar en que la tecla no salta (el que saltaba un momento antes no la corta)
local FOV_START = 55
local FOV_END = 40
local FOV_CELEBRATION = 36
local LATERAL_NEAR = 24 -- distancia (studs) de la cámara al aro, hacia el pasillo, con la pelota encima
local LATERAL_FAR = 16 -- lo que se suma cuando la pelota viene de lejos
local LATERAL_ZOOM = 8 -- lo que se acerca a lo largo de la repetición
local FAR_DISTANCE = 50 -- distancia en X de la pelota al aro a partir de la cual se considera lejos
local CAMERA_HEIGHT = -3 -- la cámara, un poco por debajo del punto que mira
local CAMERA_BEHIND = 8 -- desplazamiento en X contra el sentido de la pelota (plano en tres cuartos)
local CAMERA_SMOOTH = 6 -- 1/s del suavizado de posición y mirada
local SAFETY_MARGIN = 1.5 -- segundos sobre la duración total tras los que se fuerza el final
local BANNER_HEIGHT = 90
local BANNER_MAX_WIDTH = 640
local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local FEATHER_SIZE = Vector3.new(0.9, 0.06, 0.28)
local BLOCK_SIZE = Vector3.new(0.45, 0.08, 0.45)

local BallReplayController = {}

local rng = Random.new()
-- Termina la repetición en curso (nil si no hay ninguna).
local stopCurrent: ((completed: boolean) -> ())? = nil

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function setControls(enabled: boolean)
	pcall(function()
		local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if not module then
			return
		end
		local controls = (require(module :: ModuleScript) :: any):GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

-- El cartel grande del equipo que anota (la misma frase del aviso «Ring» del HUD, que no sale mientras dura la repetición).
local function makeBanner(gui: ScreenGui, team: string)
	local def = Config.Arena.Teams[team]
	local banner = Widgets.label(T(BallgameData.Calls.Ring, { icon = def.icon, name = def.name }), gui)
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.4)
	banner.Size = UDim2.new(0.8, 0, 0, BANNER_HEIGHT)
	banner.TextColor3 = def.color
	banner.TextStrokeTransparency = 0.2
	banner.BackgroundColor3 = PANEL_COLOR
	banner.BackgroundTransparency = 0.25
	corner(banner, 18)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(BANNER_MAX_WIDTH, math.huge)
	limit.Parent = banner
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 52
	textLimit.MinTextSize = 14
	textLimit.Parent = banner
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = banner
	-- Entra con un golpe de escala.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = banner
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

-- Una pieza de confeti (o pluma) sobre la cancha o sobre el aro que anotó.
local function spawnConfetti(folder: Folder, palette: { Color3 }, ringLocal: Vector3, halfLength: number): Part
	local celebration = BallgameData.Celebration
	local overCourt = rng:NextNumber() < 0.5
	local x: number = if overCourt
		then rng:NextNumber(-halfLength * 0.8, halfLength * 0.8)
		else ringLocal.X + rng:NextNumber(-8, 8)
	local z: number = if overCourt
		then rng:NextNumber(-CourtGeometry.ALLEY_HALF_WIDTH, CourtGeometry.ALLEY_HALF_WIDTH)
		else ringLocal.Z + rng:NextNumber(-6, 6)
	local ground = CourtGeometry.surfaceY(z) or CourtGeometry.WALL_TOP_Y
	local seconds = rng:NextNumber(celebration.Fall.Min, celebration.Fall.Max)
	return PartyFx.confettiPiece(
		folder,
		CENTER + Vector3.new(x, ground + celebration.Height, z),
		CENTER + Vector3.new(x + rng:NextNumber(-2, 2), ground + 0.1, z + rng:NextNumber(-2, 2)),
		palette,
		seconds,
		{ size = if rng:NextNumber() < 0.5 then FEATHER_SIZE else BLOCK_SIZE, linger = 0.4 }
	)
end

-- La pelota de la repetición: la misma de BallController, con una estela del color del equipo.
local function makeReplayBall(color: Color3): Part
	local ball = BallController.newBall()
	ball.Name = "ReplayBall"
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, CourtGeometry.BALL_RADIUS * 0.6, 0)
	top.Parent = ball
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -CourtGeometry.BALL_RADIUS * 0.6, 0)
	bottom.Parent = ball
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.5
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 0.4
	trail.Parent = ball
	return ball
end

local function onReplay(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local samples, hz, zSign, team = payload.samples, payload.hz, payload.zSign, payload.team
	if typeof(samples) ~= "table" or #samples < 1 or typeof(hz) ~= "number" or hz <= 0 then
		Remotes.BallReplayDone:FireServer()
		return
	end
	if typeof(zSign) ~= "number" or not Arena.isTeam(team) then
		Remotes.BallReplayDone:FireServer()
		return
	end
	if stopCurrent then
		stopCurrent(false)
	end

	local replay = Config.Arena.Ballgame.Replay
	local teamDef = Config.Arena.Teams[team :: string]
	local palette = BallgameData.Celebration.Palettes[team :: string] or { teamDef.color }
	local ring = CourtGeometry.ring
	local ringLocal = Vector3.new(ring.centerX, ring.centerY, (if zSign < 0 then -1 else 1) * ring.centerZ)
	local ringWorld = CENTER + ringLocal
	local player = Players.LocalPlayer
	local gui = Widgets.screen("BallReplay", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = true

	-- Sin cinemáticas: solo cartel y sonido; el servidor no espera.
	if not Settings.get().cinematics or #samples < 2 then
		makeBanner(gui, team)
		Sfx.playLocal("BallFanfare")
		Remotes.BallReplayDone:FireServer()
		task.delay(replay.CelebrationSeconds, function()
			gui:Destroy()
		end)
		return
	end

	local count = #samples
	local trajectorySeconds = (count - 1) / hz
	local slowSeconds = trajectorySeconds / replay.Rate
	local total = slowSeconds + replay.CelebrationSeconds
	local travel = (samples[count] :: Vector3).X - (samples[1] :: Vector3).X
	local dirX = if travel < 0 then -1 else 1

	local camera = Workspace.CurrentCamera
	local saved = {
		cameraType = camera.CameraType,
		subject = camera.CameraSubject,
		fov = camera.FieldOfView,
		cframe = camera.CFrame,
	}
	HudHider.hide({ gui })
	setControls(false)
	camera.CameraType = Enum.CameraType.Scriptable

	local ball = makeReplayBall(teamDef.color)
	ball.Parent = Workspace
	local folder = Instance.new("Folder")
	folder.Name = "BallgameCelebration"
	folder.Parent = Workspace
	local cap = Config.Budgets.BallgameConfetti[FxQuality.get()]
	local alive = 0
	local halfLength = CourtGeometry.forFormat(Arena.format()).halfLength

	-- Etiqueta de «Repetición» mientras dura la cámara lenta.
	local tag = Widgets.label(T("Repetición"), gui)
	tag.Name = "ReplayTag"
	tag.AnchorPoint = Vector2.new(0, 0)
	tag.Position = UDim2.fromOffset(24, 24)
	tag.Size = UDim2.fromOffset(180, 36)
	tag.TextXAlignment = Enum.TextXAlignment.Left

	local startedAt = os.clock()
	local celebrating = false
	local finished = false
	local nextConfetti = 0
	local camPos: Vector3? = nil
	local camLook: Vector3? = nil

	local function finish(_completed: boolean)
		if finished then
			return
		end
		finished = true
		stopCurrent = nil
		RunService:UnbindFromRenderStep(RENDER_NAME)
		ContextActionService:UnbindAction(SKIP_ACTION)
		ball:Destroy()
		folder:Destroy()
		gui:Destroy()
		-- La cámara vuelve a como estaba; si el personaje cambió mientras tanto, al de ahora.
		camera.FieldOfView = saved.fov
		camera.CameraType = saved.cameraType
		if saved.cameraType == Enum.CameraType.Scriptable then
			camera.CFrame = saved.cframe
		else
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local subject: any = saved.subject
			if subject == nil or not subject:IsDescendantOf(Workspace) then
				subject = humanoid
			end
			camera.CameraSubject = subject
		end
		HudHider.restore()
		setControls(true)
		Remotes.BallReplayDone:FireServer()
	end
	stopCurrent = finish

	local function startCelebration()
		celebrating = true
		tag.Visible = false
		makeBanner(gui, team)
		Sfx.playLocal("BallFanfare")
	end

	local function step(dt: number)
		local elapsed = os.clock() - startedAt
		if elapsed >= total then
			finish(true)
			return
		end
		if not celebrating and elapsed >= slowSeconds then
			startCelebration()
		end

		-- La pelota: la muestra que toca a la velocidad lenta (queda en la última durante la celebración).
		local f = math.clamp(elapsed * replay.Rate * hz, 0, count - 1)
		local index = math.floor(f)
		local from = samples[index + 1] :: Vector3
		local to = samples[math.min(index + 2, count)] :: Vector3
		local ballLocal = from:Lerp(to, f - index)
		ball.Position = CENTER + ballLocal

		-- Cámara lateral al aro: mira entre el aro y la pelota (más a la pelota si viene de lejos) y se acerca al final.
		local progress = math.clamp(elapsed / slowSeconds, 0, 1)
		local far = math.clamp(math.abs(ballLocal.X - ringLocal.X) / FAR_DISTANCE, 0, 1)
		local focus = ringWorld:Lerp(CENTER + ballLocal, 0.5 * far)
		local lateral = LATERAL_NEAR + LATERAL_FAR * far - LATERAL_ZOOM * progress
		local wantPos = focus
			+ Vector3.new(-dirX * CAMERA_BEHIND, CAMERA_HEIGHT, -(if zSign < 0 then -1 else 1) * lateral)
		local blend = 1 - math.exp(-dt * CAMERA_SMOOTH)
		camPos = if camPos then camPos:Lerp(wantPos, blend) else wantPos
		camLook = if camLook then camLook:Lerp(focus, blend) else focus
		camera.CFrame = CFrame.lookAt(camPos :: Vector3, camLook :: Vector3)
		camera.FieldOfView = if celebrating
			then FOV_END + (FOV_CELEBRATION - FOV_END) * math.clamp(
				(elapsed - slowSeconds) / replay.CelebrationSeconds,
				0,
				1
			)
			else FOV_START + (FOV_END - FOV_START) * progress

		-- Confeti y plumas durante la celebración, sin pasar del tope de piezas vivas.
		if celebrating and alive < cap and os.clock() >= nextConfetti then
			nextConfetti = os.clock() + 1 / BallgameData.Celebration.PerSecond
			alive += 1
			local piece = spawnConfetti(folder, palette, ringLocal, halfLength)
			piece.Destroying:Connect(function()
				alive -= 1
			end)
		end
	end

	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Last.Value, function(dt: number)
		local ok, err = pcall(step, dt)
		if not ok then
			warn(`[BallReplayController] {err}`)
			finish(false)
		end
	end)

	-- Saltar: el botón, o Espacio / A del mando pasado el margen inicial.
	local skip = Widgets.button(T("Saltar"), gui)
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -24, 1, -24)
	skip.Size = UDim2.fromOffset(160, 48)
	skip.ZIndex = 20
	skip.Activated:Connect(function()
		finish(false)
	end)
	ContextActionService:BindActionAtPriority(SKIP_ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin and os.clock() - startedAt >= SKIP_GRACE then
			finish(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	-- Tope de seguridad: si algo impide que el enlace de RenderStep llegue al final, se cierra igual.
	task.delay(total + SAFETY_MARGIN, function()
		finish(false)
	end)
end

function BallReplayController:Start()
	Remotes.BallReplay.OnClientEvent:Connect(onReplay)
end

return BallReplayController
