--!strict
-- Eventos de las batallas contra jefes para las cinemáticas (Fase 25, G14a). BattleActor.install(Sequencer) registra:
--   hit { actor, amount, hitKind, crit?, ko?, pow? }   un golpe sobre un actor de la escena (el jefe es `boss`). `hitKind` es
--       "Dealt" (daño hecho, amarillo), "Taken" (daño recibido, rojo) o "Heal" (curación, «+N»); el campo no se llama «kind»
--       porque ese es el tipo del evento. Hace lo mismo que el combate de verdad con el código del juego: destello rojo
--       (LabHitFx.flash, no en curaciones), número de daño (CombatTextController; respeta el ajuste de números), cómic de
--       impacto POW/BAM (ComicFxController; K.O.! con `ko`, y no sale con pow = false ni en curaciones) y hitmarker
--       (HitFeedbackController, solo en "Dealt").
--   bossBar { name, color?, from, to, seconds? }   la barra de vida del jefe, centrada bajo la franja de arriba. `from` y `to`
--       son la fracción de vida (0 a 1). El primer evento la crea en `from`; cada uno la lleva a `to` en `seconds` (0,25)
--       con una estela más clara que baja con retraso. Con to <= 0 se apaga con un fundido 0,6 s después. `name` es el
--       nombre del jefe sin traducir (Bosses[id].name): se traduce aquí. Cuelga del ScreenGui "Cinematic" (Presentation).
--   bossFx { fx, style, actor?, pos?, warn?, flight?, radius?, direction?, origin?, seed? }   un efecto real del jefe
--       (CombatClient/BossFx.play): fx = "stomp" | "rock" | "lavaBomb" | "charge" | "grab" | "roar". El suelo es el que hay
--       bajo `actor` en ese instante o el de `pos` (Vector3 relativo al anchor, cuentan X y Z). `direction` y `origin` (la
--       bomba de lava) también van relativos al anchor. Lo que falta sale de los valores de BossService.demo.
--   torch { actor, lit, brightness? }   enciende o apaga la antorcha del actor (el modelo con el atributo CinematicTorch que le
--       pone Actors con `torch = true`). Apagar: el Fire deja de emitir (las llamas que ya salieron se desvanecen solas) y la
--       PointLight baja a 0 en 0,15 s y se apaga. Encender: el Fire emite y la luz sube en 0,25 s hasta `brightness` (2, el de
--       WeaponTools.buildTorch). Al saltar a un instante (seek) queda el estado final, sin animación. El evento dimLights de
--       battleLight() baja las luces de los maniquíes al 30 %, también la de la antorcha: un `torch lit = true` justo después
--       le devuelve el brillo.
-- Al acabar la escena se borran la barra y la carpeta con las piezas de los efectos. Solo cliente. Necesita CombatClient;
-- si no está, los eventos avisan o se omiten.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Actors = require(script.Parent.Actors)
local FxQuality = require(script.Parent.Parent.FxQuality)
local LabActor = require(script.Parent.LabActor)
local LabHitFx = require(script.Parent.LabHitFx)
local Presentation = require(script.Parent.Presentation)
local Sequencer = require(script.Parent.Sequencer)
local Strings = require(script.Parent.Parent.Strings)

local T = Strings.t

local BattleActor = {}

local FOLDER_NAME = "CinematicBossFx"
local TOP_BAND = 0.12 -- el alto de la franja negra de arriba (Presentation), en fracción de la pantalla
local BAR_WIDTH_SCALE = 0.34
local BAR_MIN_WIDTH = 220
local BAR_HEIGHT = 16
local NAME_HEIGHT = 22
local DEFAULT_BAR_COLOR = Color3.fromRGB(222, 150, 40) -- ámbar; el verde es solo de la curación
local DEFAULT_BAR_SECONDS = 0.25
local TRAIL_DELAY = 0.35
local TRAIL_SECONDS = 0.45
local FADE_DELAY = 0.6
local FADE_SECONDS = 0.6
local FADE_IN_SECONDS = 0.3
-- Valores por defecto de BossService.demo.
local FX_DEFAULTS: { [string]: { warn: number?, flight: number?, radius: number? } } = {
	stomp = { warn = 0.9, radius = 20 },
	rock = { warn = 1.1, flight = 0.4, radius = 6 },
	lavaBomb = { warn = 1.6, flight = 1.1, radius = 6 },
	roar = { radius = 45 },
	charge = {},
	grab = {},
}
local LAVA_BOMB_HEIGHT = 40 -- si falta `origin`, la bomba sale 40 studs sobre el jefe
local TORCH_ATTRIBUTE = "CinematicTorch" -- lo pone Actors.holdTorch
local TORCH_OUT_SECONDS = 0.15
local TORCH_IN_SECONDS = 0.25
local TORCH_BRIGHTNESS = 2 -- el de WeaponTools.buildTorch

type Bar = {
	holder: CanvasGroup,
	fill: Frame,
	trail: Frame,
	value: number,
	token: number,
}
type State = {
	bar: Bar?,
	folder: Folder?,
	tweens: { Tween }, -- los de las antorchas, para cancelarlos al acabar
}

local function stateOf(ctx: Sequencer.Context): State
	local state = ctx._battle
	if not state then
		state = { bar = nil, folder = nil, tweens = {} }
		ctx._battle = state
	end
	return state
end

local function actorOf(event: Sequencer.Event, ctx: Sequencer.Context): Model?
	local actors = ctx.actors
	local actor = if actors and event.actor then actors[event.actor] else nil
	if not actor then
		warn(`BattleActor: el evento {event.kind} pide un actor que no existe ({event.actor})`)
	end
	return actor
end

-- ===================================== hit =====================================

local function onHit(event: Sequencer.Event, ctx: Sequencer.Context)
	if ctx.seeking then
		return
	end
	local actor = actorOf(event, ctx)
	if not actor or not actor.Parent then
		return
	end
	local hitKind: string = event.hitKind or "Dealt"
	local heal = hitKind == "Heal"
	local amount: number = event.amount or 0

	if not heal then
		pcall(LabHitFx.flash, actor)
	end

	local text = LabActor.combatModule("CombatTextController")
	if text and text.showLocal then
		pcall(text.showLocal, {
			target = actor,
			amount = amount,
			kind = hitKind,
			crit = event.crit == true,
			head = false,
		})
	end

	if not heal and event.pow ~= false then
		local comic = LabActor.combatModule("ComicFxController")
		if comic and comic.burstLocal then
			pcall(comic.burstLocal, actor, if event.ko == true then "KO" else "Hit")
		end
	end

	if hitKind == "Dealt" then
		local feedback = LabActor.combatModule("HitFeedbackController")
		if feedback and feedback.showLocal then
			pcall(feedback.showLocal, if event.ko == true then "Kill" else "Body")
		end
	end
end

-- ===================================== bossBar =====================================

local function frame(name: string, parent: Instance, color: Color3, size: UDim2): Frame
	local item = Instance.new("Frame")
	item.Name = name
	item.BackgroundColor3 = color
	item.BorderSizePixel = 0
	item.Size = size
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, BAR_HEIGHT / 2)
	corner.Parent = item
	return item
end

local function createBar(event: Sequencer.Event, gui: ScreenGui, instant: boolean): Bar
	local color: Color3 = event.color or DEFAULT_BAR_COLOR
	local from = math.clamp(event.from or 1, 0, 1)

	local holder = Instance.new("CanvasGroup")
	holder.Name = "BossBar"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, TOP_BAND, 14)
	holder.Size = UDim2.new(BAR_WIDTH_SCALE, 0, 0, NAME_HEIGHT + 4 + BAR_HEIGHT)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.GroupTransparency = if instant then 0 else 1
	holder.ZIndex = 2
	holder.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(BAR_MIN_WIDTH, NAME_HEIGHT + 4 + BAR_HEIGHT)
	limit.Parent = holder

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, NAME_HEIGHT)
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 20
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = T(event.name or "")
	label.Parent = holder

	local track = frame("Track", holder, Color3.fromRGB(26, 20, 16), UDim2.new(1, 0, 0, BAR_HEIGHT))
	track.Position = UDim2.fromOffset(0, NAME_HEIGHT + 4)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(255, 236, 200)
	stroke.Transparency = 0.35
	stroke.Parent = track

	local trail = frame("Trail", track, color:Lerp(Color3.new(1, 1, 1), 0.6), UDim2.fromScale(from, 1))
	local fill = frame("Fill", track, color, UDim2.fromScale(from, 1))
	fill.ZIndex = trail.ZIndex + 1

	if not instant then
		TweenService:Create(holder, TweenInfo.new(FADE_IN_SECONDS), { GroupTransparency = 0 }):Play()
	end
	return { holder = holder, fill = fill, trail = trail, value = from, token = 0 }
end

local function onBossBar(event: Sequencer.Event, ctx: Sequencer.Context)
	local state = stateOf(ctx)
	local instant = ctx.seeking == true
	local bar = state.bar
	if not bar or not bar.holder.Parent then
		local gui = Presentation.gui()
		if not gui then
			return
		end
		bar = createBar(event, gui, instant)
		state.bar = bar
	end
	local current = bar :: Bar
	local to = math.clamp(event.to or current.value, 0, 1)
	local seconds: number = event.seconds or DEFAULT_BAR_SECONDS
	local size = UDim2.fromScale(to, 1)
	local losing = to < current.value
	current.value = to
	current.token += 1
	local token = current.token

	if instant or seconds <= 0 then
		current.fill.Size = size
		current.trail.Size = size
	else
		TweenService:Create(current.fill, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = size,
		}):Play()
		if losing then
			-- La estela espera un momento y baja detrás, como en un juego de lucha.
			TweenService:Create(
				current.trail,
				TweenInfo.new(
					TRAIL_SECONDS,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out,
					0,
					false,
					seconds + TRAIL_DELAY
				),
				{ Size = size }
			):Play()
		else
			current.trail.Size = size
		end
	end

	if to <= 0 then
		local holder = current.holder
		task.delay(seconds + FADE_DELAY, function()
			if current.token == token and holder.Parent then
				TweenService:Create(holder, TweenInfo.new(FADE_SECONDS), { GroupTransparency = 1 }):Play()
			end
		end)
	end
end

-- ===================================== bossFx =====================================

-- La carpeta del Workspace donde caen las piezas de los efectos de esta escena (se borra al acabar).
local function fxFolder(state: State): Folder
	local folder = state.folder
	if folder and folder.Parent then
		return folder
	end
	local fresh = Instance.new("Folder")
	fresh.Name = FOLDER_NAME
	fresh:SetAttribute("CinematicKeep", true)
	fresh.Parent = Workspace
	state.folder = fresh
	return fresh
end

-- El suelo donde cae el efecto: bajo `actor` ahora mismo, o el de `pos` (relativo al anchor).
local function groundOf(event: Sequencer.Event, ctx: Sequencer.Context): Vector3?
	if event.actor then
		local actor = actorOf(event, ctx)
		return if actor then Actors.snapToTerrain(CFrame.identity, actor:GetPivot().Position) else nil
	elseif typeof(event.pos) == "Vector3" then
		local anchor: CFrame = ctx.anchor or CFrame.identity
		return Actors.snapToTerrain(CFrame.identity, anchor:PointToWorldSpace(event.pos))
	end
	warn("BattleActor: bossFx necesita `actor` o `pos`")
	return nil
end

local function onBossFx(event: Sequencer.Event, ctx: Sequencer.Context)
	if ctx.seeking then
		return
	end
	local fx = event.fx
	local defaults = if typeof(fx) == "string" then FX_DEFAULTS[fx] else nil
	if not defaults then
		warn(`BattleActor: bossFx con un efecto desconocido ({fx})`)
		return
	end
	local bossFx = LabActor.combatModule("BossFx")
	if not bossFx then
		warn("BattleActor: no hay CombatClient/BossFx; el evento bossFx no hace nada")
		return
	end
	local ground = groundOf(event, ctx)
	if not ground then
		return
	end
	local anchor: CFrame = ctx.anchor or CFrame.identity
	local origin: Vector3? = nil
	if fx == "lavaBomb" then
		origin = if typeof(event.origin) == "Vector3"
			then anchor:PointToWorldSpace(event.origin)
			else ground + Vector3.new(0, LAVA_BOMB_HEIGHT, 0)
	end
	local ok, err = pcall(function()
		bossFx.play(fx, event.style or "ChimpanceCaudillo", fxFolder(stateOf(ctx)), FxQuality.get(), {
			position = ground,
			warn = event.warn or defaults.warn,
			flight = event.flight or defaults.flight,
			radius = event.radius or defaults.radius,
			direction = if typeof(event.direction) == "Vector3"
				then anchor:VectorToWorldSpace(event.direction)
				else nil,
			origin = origin,
			serverTime = Workspace:GetServerTimeNow(),
			seed = event.seed or math.random(1, 1000000),
		})
	end)
	if not ok then
		warn(`BattleActor: bossFx {fx} falla: {err}`)
	end
end

-- ===================================== torch =====================================

-- El modelo de la antorcha de un actor (el que lleva el atributo CinematicTorch).
local function torchOf(actor: Model): Model?
	for _, descendant in actor:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute(TORCH_ATTRIBUTE) then
			return descendant
		end
	end
	return nil
end

local function onTorch(event: Sequencer.Event, ctx: Sequencer.Context)
	local actor = actorOf(event, ctx)
	if not actor or not actor.Parent then
		return
	end
	local torch = torchOf(actor)
	if not torch then
		warn(`BattleActor: el evento torch pide un actor sin antorcha ({event.actor})`)
		return
	end
	local fire = torch:FindFirstChildWhichIsA("Fire", true)
	local light = torch:FindFirstChildWhichIsA("PointLight", true)
	local lit = event.lit == true
	local brightness: number = event.brightness or TORCH_BRIGHTNESS
	local instant = ctx.seeking == true
	local state = stateOf(ctx)

	if fire then
		fire.Enabled = lit
	end
	if not light then
		return
	end
	-- Un contador en la luz: si llega otro evento antes de acabar el fundido, el viejo no apaga la luz.
	local token = (light:GetAttribute("TorchToken") or 0) + 1
	light:SetAttribute("TorchToken", token)
	if instant then
		light.Brightness = if lit then brightness else 0
		light.Enabled = lit
		return
	end
	if lit then
		light.Enabled = true
		local tween = TweenService:Create(light, TweenInfo.new(TORCH_IN_SECONDS), { Brightness = brightness })
		table.insert(state.tweens, tween)
		tween:Play()
	else
		local tween = TweenService:Create(light, TweenInfo.new(TORCH_OUT_SECONDS), { Brightness = 0 })
		table.insert(state.tweens, tween)
		tween.Completed:Connect(function(playback)
			if
				playback == Enum.PlaybackState.Completed
				and light.Parent
				and light:GetAttribute("TorchToken") == token
			then
				light.Enabled = false
			end
		end)
		tween:Play()
	end
end

-- ===================================== instalación =====================================

function BattleActor.install(sequencer: typeof(Sequencer))
	sequencer.registerHandler("hit", onHit)
	sequencer.registerHandler("bossBar", onBossBar)
	sequencer.registerHandler("bossFx", onBossFx)
	sequencer.registerHandler("torch", onTorch)

	sequencer.addHooks({
		finish = function(_, ctx)
			local state = ctx._battle
			if not state then
				return
			end
			for _, tween in state.tweens do
				tween:Cancel()
			end
			-- La barra cuelga del ScreenGui de Presentation (que se borra solo), pero se quita ya para no depender del orden.
			if state.bar then
				state.bar.holder:Destroy()
			end
			if state.folder then
				state.folder:Destroy()
			end
			ctx._battle = nil
		end,
	})
end

return BattleActor
