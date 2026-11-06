--!strict
-- Lado cliente de las cinemáticas del juego (Fase 25, G1b), común a la Isla y al Lobby. Cada
-- CinematicController es una línea que llama a CinematicClient.start(place).
--
-- Escucha Remotes.Cinematic: ("Play", id, startServerTime, args?) y ("Stop", id). Con el ajuste «Cinemáticas»
-- apagado responde enseguida CinematicDone(id, false) y no enseña nada. Si no: apaga los controles, oculta el
-- HUD (menos el ScreenGui de la cinemática), reproduce la escena con el Sequencer (con seek si llega tarde) y
-- al acabar (+0,4 s) lo devuelve todo y avisa al servidor con CinematicDone(id, vista_entera).
-- El botón «Saltar» sale si la escena ya está en cinematicsSeen del atributo Progress, o si es skippable
-- (en las locales, siempre).
--
-- Escenas locales (CinematicClient.playLocal, Fase 25 G3a): las lanza el propio cliente, sin servidor y sin
-- CinematicDone (la eclosión del huevo del Lobby). args = { anchor?, context? (tabla libre que los handlers
-- leen en ctx.data), onFinished?(completed) (tras devolver HUD y controles) }.
--
-- Maniquí: Actors ya crea el rig R15 con Players:CreateHumanoidModelFromDescription (no es de uso restringido
-- y también corre en el cliente). La fábrica que se registra aquí es solo la salida de emergencia: si existe
-- una plantilla "CinematicDummy" (Model R15) en ReplicatedStorage.Shared la clona; si no, devuelve nil y
-- Actors sigue con su camino normal.

local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AbilityShow = require(script.Parent.AbilityShow)
local Actors = require(script.Parent.Actors)
local Comic = require(script.Parent.Comic)
local Branding = require(script.Parent.Parent.Data.Branding)
local Cinematics = require(script.Parent.Parent.Data.Cinematics)
local PlayerAnimations = require(script.Parent.Parent.Data.PlayerAnimations)
local WeaponAnimations = require(script.Parent.Parent.Data.WeaponAnimations)
local HudHider = require(script.Parent.Parent.UI.HudHider)
local PetFollowers = require(script.Parent.Parent.UI.PetFollowers)
local Presentation = require(script.Parent.Presentation)
local SceneLight = require(script.Parent.SceneLight)
local Remotes = require(script.Parent.Parent.Remotes)
local RescueCrew = require(script.Parent.RescueCrew)
local Sequencer = require(script.Parent.Sequencer)
local Settings = require(script.Parent.Parent.Settings)
local Strings = require(script.Parent.Parent.Strings)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local T = Strings.t

local CinematicClient = {}

local TERRAIN_WAIT_SECONDS = 4
local GROUND_CHECK_DISTANCE = 30 -- studs bajo el personaje donde se busca el suelo al volver al Basecamp
local GROUND_CHECK_STREAK = 4 -- lecturas seguidas con suelo antes de avisar al servidor
local TERRAIN_TOLERANCE = 0.9 -- studs de diferencia admitidos entre el suelo de diseño y el cargado
-- Gestos que usan el brazo del arma: la pose de llevarla se para mientras duran. Los gestos de las habilidades de
-- los roles (batallas, G5) lo mueven entero.
local GESTURES_WITH_WEAPON_ARM = {
	Point = true,
	LookAround = true,
	Quake = true,
	WarCry = true,
	Charge = true,
	Smash = true,
	Whirlwind = true,
	CastForward = true,
	CastArea = true,
}
local END_DELAY = 0.4 -- espera antes de devolver el HUD, para que un fundido final no se corte de golpe
local TEMPLATE_NAME = "CinematicDummy"

type Active = {
	id: string,
	handle: Sequencer.Handle,
	stoppedByServer: boolean,
	isLocal: boolean,
}

local active: Active? = nil

-- Escenas ya vistas por el jugador (cinematicsSeen del JSON de Progress; lista o mapa, tolerante).
local function hasSeen(id: string): boolean
	local player = Players.LocalPlayer
	local raw = player:GetAttribute("Progress")
	if typeof(raw) ~= "string" then
		return false
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not (ok and typeof(decoded) == "table") then
		return false
	end
	local seen = decoded.cinematicsSeen
	if typeof(seen) ~= "table" then
		return false
	end
	return seen[id] == true or table.find(seen, id) ~= nil
end

local function setControls(enabled: boolean)
	pcall(function()
		-- Sin esperas: la escena no puede retrasarse (el servidor la da por acabada a duration + margen).
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

-- Dónde se ancla la escena: args.anchor, o el jefe si scene.anchor = "boss", o los pies del personaje.
local function resolveAnchor(scene: Cinematics.Scene, args: { [string]: any }): CFrame
	if typeof(args.anchor) == "CFrame" then
		return args.anchor
	end
	if scene.anchor == "boss" then
		for _, descendant in workspace:GetDescendants() do
			if descendant:IsA("Model") then
				local boss = descendant:GetAttribute("Boss")
				if boss ~= nil and (args.bossId == nil or boss == args.bossId) then
					local cf, size = descendant:GetBoundingBox()
					return CFrame.new(cf.X, cf.Y - size.Y / 2, cf.Z) * cf.Rotation
				end
			end
		end
	end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local lift = (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2
		return CFrame.new(root.Position - Vector3.new(0, lift, 0)) * root.CFrame.Rotation
	end
	return CFrame.identity
end

-- Cuerpo común de play (escena de servidor) y playLocal. Devuelve false si no se reproduce.
-- Pantalla en negro mientras el servidor prepara la escena (ArrivalService lleva al personaje a la playa y espera a que
-- se dibuje el terreno) y al volver al Basecamp mientras carga: sin ella se ve el personaje flotando, el HUD y la
-- arena de al lado. La pide el atributo ArrivalHold del jugador; la quitan el arranque de la escena (con fundido),
-- que el servidor lo borre o un tope de seguridad. Al acabar la escena se vuelve a poner si el atributo sigue.
local HOLD_MAX_SECONDS = 25
local hold: ScreenGui? = nil
local holdStatus: TextLabel? = nil -- el texto de qué se está preparando

local function releaseHold(fadeSeconds: number)
	local current = hold
	if not current then
		return
	end
	hold = nil
	if fadeSeconds > 0 then
		-- Funde el fondo y todos los textos y puntos a la vez.
		local info = TweenInfo.new(fadeSeconds)
		for _, item in current:GetDescendants() do
			if item:IsA("TextLabel") then
				TweenService:Create(item, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif item:IsA("ImageLabel") then
				TweenService:Create(item, info, { ImageTransparency = 1 }):Play()
			elseif item:IsA("Frame") then
				TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(fadeSeconds + 0.1, function()
			current:Destroy()
		end)
	else
		current:Destroy()
	end
end

local function startHold(returning: boolean?)
	if hold then
		return
	end
	local playerGui = if Players.LocalPlayer then Players.LocalPlayer:FindFirstChild("PlayerGui") else nil
	if not playerGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CinematicHold"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	-- Tarjeta de espera: fondo azul noche, el nombre del juego, qué se está preparando, un consejo y tres puntos que
	-- laten. "ArrivalHold" vale "Return" al volver al Basecamp y "Arrive" antes de la escena.
	local isReturning = returning == true or Players.LocalPlayer:GetAttribute("ArrivalHold") == "Return"
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(12, 16, 30)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(8, 10, 20), Color3.fromRGB(26, 34, 58))
	gradient.Parent = frame
	local function label(text: string, y: number, height: number, size: number, color: Color3, bold: boolean)
		local item = Instance.new("TextLabel")
		item.AnchorPoint = Vector2.new(0.5, 0.5)
		item.Position = UDim2.fromScale(0.5, y)
		item.Size = UDim2.fromScale(0.8, height)
		item.BackgroundTransparency = 1
		item.Font = if bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSans
		item.TextScaled = true
		item.TextColor3 = color
		item.TextStrokeColor3 = Color3.new(0, 0, 0)
		item.TextStrokeTransparency = 0.5
		item.Text = text
		item.Parent = frame
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = size
		limit.Parent = item
		return item
	end
	if Branding.Logo ~= "" then
		-- El título de la portada, como en la miniatura del juego.
		local logo = Instance.new("ImageLabel")
		logo.Name = "Logo"
		logo.AnchorPoint = Vector2.new(0.5, 0.5)
		logo.Position = UDim2.fromScale(0.5, 0.36)
		logo.Size = UDim2.fromScale(0.6, 0.44)
		logo.BackgroundTransparency = 1
		logo.Image = Branding.Logo
		logo.ScaleType = Enum.ScaleType.Fit
		logo.Parent = frame
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = Branding.LogoAspect
		aspect.AspectType = Enum.AspectType.FitWithinMaxSize
		aspect.DominantAxis = Enum.DominantAxis.Height
		aspect.Parent = logo
	else
		label("Primal Banana Islands", 0.36, 0.14, 56, Color3.fromRGB(255, 214, 90), true)
	end
	holdStatus = label(
		if isReturning then T("Volviendo al Basecamp…") else T("Preparando la isla…"),
		0.66,
		0.07,
		28,
		Color3.fromRGB(235, 240, 250),
		true
	)
	label(
		T("Sobrevive, defiende el Basecamp y busca a los jefes de la isla"),
		0.86,
		0.05,
		20,
		Color3.fromRGB(170, 180, 205),
		false
	)
	local dots: { Frame } = {}
	for index = 1, 3 do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(0.5, (index - 2) * 28, 0.75, 0)
		dot.Size = UDim2.fromOffset(14, 14)
		dot.BackgroundColor3 = Color3.fromRGB(255, 214, 90)
		dot.BorderSizePixel = 0
		dot.Parent = frame
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = dot
		table.insert(dots, dot)
	end
	task.spawn(function()
		local started = os.clock()
		while gui.Parent and hold == gui do
			local now = os.clock() - started
			for index, dot in dots do
				dot.BackgroundTransparency = 0.7 - 0.7 * (0.5 + 0.5 * math.sin(now * 5 - index * 0.9))
			end
			task.wait()
		end
	end)
	gui.Parent = playerGui
	hold = gui
	task.delay(HOLD_MAX_SECONDS, function()
		if hold == gui then
			releaseHold(0.3)
		end
	end)
end

local function run(id: string, startServerTime: number, args: { [string]: any }?, isLocal: boolean): boolean
	local params = args or {}
	local scene = Cinematics[id]
	if not scene then
		warn(`CinematicClient: escena desconocida ({id})`)
		if not isLocal then
			Remotes.CinematicDone:FireServer(id, false)
		end
		return false
	end
	if not Settings.get().cinematics then
		releaseHold(0.2)
		if not isLocal then
			Remotes.CinematicDone:FireServer(id, false)
		end
		return false
	end
	if active then
		if isLocal and not active.isLocal then
			return false -- una escena local no corta una de servidor
		end
		active.handle.stop()
	end

	-- Con StreamingEnabled el terreno lejano llega primero grueso y más alto que el real: los maniquíes salían
	-- hundidos en la arena. Si la escena pide waitTerrain, se espera (hasta 4 s) a que cada punto tenga el suelo
	-- cerca de su altura de diseño; el resto se recupera con el salto al tiempo que toca.
	local waitPoints = (scene :: any).waitTerrain :: { Vector3 }?
	if waitPoints then
		local anchor = resolveAnchor(scene, params)
		local terrainOnly = RaycastParams.new()
		terrainOnly.FilterType = Enum.RaycastFilterType.Include
		terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
		local deadline = os.clock() + TERRAIN_WAIT_SECONDS
		while os.clock() < deadline do
			local ready = true
			for _, point in waitPoints do
				local world = anchor:PointToWorldSpace(Vector3.new(point.X, 0, point.Z))
				local hit = workspace:Raycast(world + Vector3.new(0, 60, 0), Vector3.new(0, -120, 0), terrainOnly)
				if not hit or math.abs(hit.Position.Y - (anchor.Position.Y + point.Y)) > TERRAIN_TOLERANCE then
					ready = false
					break
				end
			end
			if ready then
				break
			end
			task.wait(0.15)
		end
	end

	local entry: Active? = nil
	local gui = Presentation.gui()
	HudHider.hide(if gui then { gui } else nil)
	PetFollowers.setHidden(true)
	setControls(false)
	releaseHold(0.4)

	local finished = false
	local function onFinished(completed: boolean)
		if finished then
			return
		end
		finished = true
		local mine = entry
		task.delay(END_DELAY, function()
			-- Si el servidor aún tiene al personaje de camino a casa, se queda en negro hasta que lo suelte.
			-- "Next": sigue otra escena (la travesía antes de la llegada), no se vuelve al Basecamp.
			local holdValue = if Players.LocalPlayer then Players.LocalPlayer:GetAttribute("ArrivalHold") else nil
			if holdValue ~= nil then
				startHold(holdValue ~= "Next")
			end
			HudHider.restore()
			PetFollowers.setHidden(false)
			setControls(true)
			if mine and active == mine then
				active = nil
			end
			if not isLocal and not (mine and mine.stoppedByServer) then
				Remotes.CinematicDone:FireServer(id, completed)
			end
			if typeof(params.onFinished) == "function" then
				local ok, err = pcall(params.onFinished, completed)
				if not ok then
					warn(`CinematicClient: falla onFinished de {id}: {err}`)
				end
			end
		end)
	end

	local handle = Sequencer.play(
		scene :: any,
		{ anchor = resolveAnchor(scene, params), onFinished = onFinished, data = params.context }
	)
	entry = { id = id, handle = handle, stoppedByServer = false, isLocal = isLocal }
	active = entry

	-- Botón Saltar (abajo a la derecha, dentro del ScreenGui de la cinemática: se borra solo al terminar).
	if gui and handle.isPlaying() and (isLocal or hasSeen(id) or (scene :: any).skippable == true) then
		local skip = Widgets.button(T("Saltar"), gui)
		skip.Name = "Skip"
		skip.AnchorPoint = Vector2.new(1, 1)
		skip.Position = UDim2.new(1, -24, 1, -24)
		skip.Size = UDim2.fromOffset(160, 48)
		skip.ZIndex = 20
		skip.Activated:Connect(function()
			skip.Visible = false
			handle.skip()
		end)
	end

	-- Llega tarde (entró a mitad de escena o hubo retraso): salta al tiempo que le toca.
	local late = workspace:GetServerTimeNow() - startServerTime
	if not isLocal and late > 0.1 and handle.isPlaying() then
		handle.seek(late)
	end
	return true
end

local function play(id: string, startServerTime: number, args: { [string]: any }?)
	run(id, startServerTime, args, false)
end

-- Escena local (sin servidor ni CinematicDone). false = no se ha reproducido (ajuste «Cinemáticas» apagado,
-- escena desconocida o una cinemática de servidor en marcha): quien llama hace entonces su versión sin cámara.
function CinematicClient.playLocal(id: string, args: { [string]: any }?): boolean
	return run(id, workspace:GetServerTimeNow(), args, true)
end

-- Pose de arma de un maniquí: «WeaponCarry» (Data/PlayerAnimations): brazo derecho abierto y adelantado con el arma en
-- diagonal hacia delante y fuera, la punta lejos de la cabeza. Las poses del juego (apuntar, empuñar de Roblox,
-- Hold) ponen el arma en la cara o la dejan vertical a la altura de la cabeza. Va en bucle y por encima de los
-- gestos (Action4 sobre Action3): en cada articulación manda la pista de más prioridad, así que al celebrar el
-- brazo del arma sigue sujetándola y solo sube el otro. Los gestos que usan el brazo del arma (los de
-- GESTURES_WITH_WEAPON_ARM) y los ataques de arma (WeaponAnimations) la paran mientras duran.
local weaponPoses: { [Model]: () -> () } = setmetatable({}, { __mode = "k" }) :: any
-- Hasta cuándo (os.clock) tiene la pose parada cada maniquí con pose; su presencia dice que el maniquí la lleva.
local poseResumeAt: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function ensureAnimator(actor: Model): Humanoid?
	local humanoid = actor:FindFirstChildOfClass("Humanoid")
	if humanoid and not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	return humanoid
end

local function startWeaponPose(BodyAnimations: any, actor: Model)
	local id = BodyAnimations.idOf("WeaponCarry")
	if not (id and ensureAnimator(actor)) then
		return
	end
	poseResumeAt[actor] = poseResumeAt[actor] or 0
	weaponPoses[actor] = BodyAnimations.playIdOn(actor, id, Enum.AnimationPriority.Action4, true, nil)
end

-- Para la pose del arma mientras dura un gesto o un ataque que usa su brazo y la devuelve al acabar. Si llega otro
-- mientras está parada, la pose vuelve cuando acabe el último.
local function pauseWeaponPose(BodyAnimations: any, actor: Model, seconds: number)
	if poseResumeAt[actor] == nil then
		return
	end
	poseResumeAt[actor] = math.max(poseResumeAt[actor], os.clock() + seconds)
	local stop = weaponPoses[actor]
	if stop then
		stop()
		weaponPoses[actor] = nil
	end
	task.delay(seconds, function()
		if actor.Parent and weaponPoses[actor] == nil and os.clock() >= poseResumeAt[actor] - 0.01 then
			startWeaponPose(BodyAnimations, actor)
		end
	end)
end

-- Animación de arma (Data/WeaponAnimations: Slash1–4, Aim*, Arrow, Spell, Stone, Dart…) en un maniquí. Como en el juego
-- (WeaponController), las poses Aim* y Hold van en bucle a nivel Action y el resto (tajos y disparos), una vez a Action2;
-- sin "seconds", los disparos duran 1 s y las poses de apuntar, 2 s.
local function playWeaponAnimation(
	BodyAnimations: any,
	WeaponAnimationIds: any,
	actor: Model,
	key: string,
	seconds: number?
)
	local id = WeaponAnimationIds.get(key)
	if not (id and ensureAnimator(actor)) then
		return
	end
	local holding = key == "Hold" or string.sub(key, 1, 3) == "Aim"
	BodyAnimations.playIdOn(
		actor,
		id,
		if holding then Enum.AnimationPriority.Action else Enum.AnimationPriority.Action2,
		holding,
		seconds or (if holding then 2 else 1)
	)
end

-- "place" solo sirve para los avisos; los dos places cargan CombatClient, así que el animador es el mismo.
function CinematicClient.start(place: string)
	Presentation.install(Sequencer)
	Actors.install(Sequencer)
	AbilityShow.install(Sequencer)
	Comic.install(Sequencer)
	RescueCrew.install(Sequencer)
	SceneLight.install(Sequencer)

	local shared = ReplicatedStorage:FindFirstChild("Shared")
	Actors.setDummyFactory(function()
		local template = if shared then shared:FindFirstChild(TEMPLATE_NAME) else nil
		if template and template:IsA("Model") then
			return template:Clone()
		end
		return nil
	end)

	local combatClient = ReplicatedStorage:FindFirstChild("CombatClient")
	local bodyModule = if combatClient then combatClient:FindFirstChild("BodyAnimations") else nil
	if bodyModule and bodyModule:IsA("ModuleScript") then
		local BodyAnimations = require(bodyModule) :: any
		local idsModule = combatClient and combatClient:FindFirstChild("WeaponAnimationIds")
		local WeaponAnimationIds = if idsModule and idsModule:IsA("ModuleScript")
			then require(idsModule) :: any
			else nil
		Actors.setAnimator(function(actor, action, event)
			if action == "WeaponPose" then
				startWeaponPose(BodyAnimations, actor)
				return
			end
			if (PlayerAnimations.Animations :: any)[action] then
				-- Gestos del cuerpo (PlayerAnimations): Cheer, Point… y los de las habilidades de los roles.
				if GESTURES_WITH_WEAPON_ARM[action] then
					pauseWeaponPose(BodyAnimations, actor, event.seconds or 2)
				end
				BodyAnimations.playOn(actor, action, event.seconds or 2)
			elseif WeaponAnimations[action] and WeaponAnimationIds then
				-- Ataques y poses de arma (WeaponAnimations): usan el brazo del arma, que deja la pose de llevarla.
				pauseWeaponPose(
					BodyAnimations,
					actor,
					event.seconds or (if string.sub(action, 1, 3) == "Aim" then 2 else 1)
				)
				playWeaponAnimation(BodyAnimations, WeaponAnimationIds, actor, action, event.seconds)
			else
				warn(`CinematicClient: animación desconocida ({action})`)
			end
		end)
	else
		warn(`CinematicClient({place}): sin CombatClient; los eventos anim no harán nada`)
	end

	-- El logo de la tarjeta de espera se pide ya, para que esté cargado cuando salga (si no, la primera vez aparece tarde).
	if Branding.Logo ~= "" then
		task.spawn(function()
			local logo = Instance.new("ImageLabel")
			logo.Image = Branding.Logo
			pcall(function()
				ContentProvider:PreloadAsync({ logo })
			end)
			logo:Destroy()
		end)
	end

	local localPlayer = Players.LocalPlayer
	if localPlayer then
		-- Al volver al Basecamp avisa al servidor cuando hay suelo cargado bajo el personaje (varias lecturas seguidas):
		-- hasta entonces el servidor lo tiene quieto y la tarjeta puesta. Sin esto se soltaba con el terreno a medio
		-- cargar y el personaje volaba y caía.
		local watchingGround = false
		local function watchGround()
			if watchingGround then
				return
			end
			watchingGround = true
			task.spawn(function()
				local streak = 0
				while localPlayer:GetAttribute("ArrivalHold") == "Return" do
					local character = localPlayer.Character
					local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
					if root and root:IsA("BasePart") then
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						params.FilterDescendantsInstances = { character :: Instance }
						local hit = workspace:Raycast(root.Position, Vector3.new(0, -GROUND_CHECK_DISTANCE, 0), params)
						streak = if hit then streak + 1 else 0
						if streak >= GROUND_CHECK_STREAK then
							Remotes.ArrivalGround:FireServer()
							break
						end
					end
					task.wait(0.15)
				end
				watchingGround = false
			end)
		end
		local function syncHold()
			local value = localPlayer:GetAttribute("ArrivalHold")
			if value == "Next" and active then
				return -- el servidor avisa de que sigue otra escena: la tarjeta sale al acabar esta (onFinished)
			end
			if value ~= nil then
				startHold()
				if value == "Return" then
					if holdStatus then
						holdStatus.Text = T("Volviendo al Basecamp…")
					end
					watchGround()
				end
			else
				releaseHold(0.4)
			end
		end
		localPlayer:GetAttributeChangedSignal("ArrivalHold"):Connect(syncHold)
		syncHold()
	end

	Remotes.Cinematic.OnClientEvent:Connect(function(kind: string, id: string, startServerTime: number?, args: any?)
		if kind == "Play" then
			play(id, startServerTime or workspace:GetServerTimeNow(), args)
		elseif kind == "Stop" then
			local current = active
			if current and current.id == id then
				current.stoppedByServer = true
				current.handle.stop()
			end
		end
	end)
end

return CinematicClient
