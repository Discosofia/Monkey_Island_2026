--!strict
-- Eventos de la supervivencia de la Isla para las cinemáticas (Fase 25, G14b). SurvivalActor.install(Sequencer) registra:
--   nodeHit { actor, node, material }      un golpe del actor al prop `node` (otro actor de la escena: el árbol o la roca).
--       `material` = "wood" | "stone" (el campo no se llama «kind» porque ese es el tipo del evento). Sacudida corta del prop (inclinado hacia el lado contrario al actor), astillas o lascas del
--       color del material (ParticleEmitter con Emit) y el sonido Chop o Mine, como ResourceService.
--   nodeFall { node, dir?, seconds? }      el prop se agota, según su tipo (atributo ResourceNode de Shared/NodeModels): un
--       árbol o palmera cae girando sobre su base hacia `dir` (Vector3 relativo al anchor, solo X y Z; copia de `fall` de
--       ResourceService: 85 grados en 1,2 s) con TreeFall al tocar el suelo y luego se desvanece; una roca se encoge y se
--       rompe en lascas (RockBreak); una mata solo pierde el racimo (la carpeta «Cosecha») con Pickup.
--   loot { item, n, actor }                "+4 🌲 Madera" sobre la cabeza de `actor` con el aspecto del juego
--       (CombatTextController.showLootLocal). `item` es un id de Data/Items o, para un arma fabricada, de Data/Weapons.
--   survivalBars { show?, hunger?, thirst?, seconds?, flash? }   las barras 🍖 y 💧 del HUD de la Isla (UI/SurvivalBar, los
--       mismos iconos y colores) bajo la franja de arriba, en el ScreenGui de la cinemática. `hunger` y `thirst` son la
--       fracción (0 a 1) a la que van en `seconds` (0,6; la primera vez nacen llenas). Con `flash` (por defecto sí) la
--       barra que está por debajo de Config.Survival.LowThreshold parpadea en rojo como la real. show = false las quita.
--   holdProp { actor, item | false, sound?, delay? }   un plátano ("Banana") o un coco ("Coconut") voxel pequeño en la mano
--       izquierda del actor, o false para quitarlo. Va con la animación Consume (anim). `sound` ("Eat" o "Drink", de
--       Data/Sounds) suena `delay` segundos después (0,6): el bocado, cuando la mano llega a la boca.
--       Con `hand = "Right"` va en la mano derecha (la de Consume), tras soltar el arma con equip weapon = false.
--   equip { actor, weapon | false }        cambia el arma de la mano derecha (Actors.holdWeapon) o la suelta (false), y quita
--       la vista previa de craftFx.
--   hideReal { at, radius? }               esconde (solo en este cliente, se devuelve al acabar) la vegetación real del mapa
--       (carpetas Vegetacion, Recursos y Cultivos) a menos de `radius` studs de `at` (30 por defecto).
--   craftFx { at, weapon }                 chispas y el sonido Craft en `at` (relativo al anchor, sobre la mesa) y, desde ahí,
--       la vista previa del arma (WeaponTools.previewWeapon): sube unos 2 studs girando hasta el evento equip.
--   buildGhost { id, at, yaw?, key? }      el fantasma de una pieza construible (BuildModels.build + makeGhost + Highlight
--       verde, el de BuildController) en `at` (el suelo, relativo al anchor), girada `yaw` grados.
--   buildRise { id, at, yaw?, seconds?, key? }   quita el fantasma con la misma `key` (por defecto id y posición) y levanta la pieza
--       sólida: sube desde el suelo en `seconds` (0,7) con polvo y el sonido Build. La StandingTorch nace apagada y enciende
--       su Fire y su PointLight al terminar de subir.
-- Todo lo que crea (carpeta «CinematicSurvivalFx», vista previa, fantasmas, piezas, barras) lleva CinematicKeep y se borra al
-- acabar la escena. Los efectos con partículas no salen al saltar a un instante (seek); los cambios de estado, sí (queda el
-- resultado final). Solo cliente. Sin CombatClient, loot avisa y no hace nada.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Actors = require(script.Parent.Actors)
local BuildModels = require(script.Parent.Parent.BuildModels)
local Buildables = require(script.Parent.Parent.Data.Buildables)
local Config = require(script.Parent.Parent.Config)
local LabActor = require(script.Parent.LabActor)
local NodeModels = require(script.Parent.Parent.NodeModels)
local Presentation = require(script.Parent.Presentation)
local ScreenBands = require(script.Parent.ScreenBands)
local Sequencer = require(script.Parent.Sequencer)
local Sfx = require(script.Parent.Parent.Sfx)
local Survival = require(script.Parent.Parent.Survival)
local SurvivalBar = require(script.Parent.Parent.UI.SurvivalBar)
local WeaponTools = require(script.Parent.Parent.WeaponTools)

local SurvivalActor = {}

local FOLDER_NAME = "CinematicSurvivalFx"
local BARS_FADE_SECONDS = 0.3
local BARS_DEFAULT_SECONDS = 0.6
local WOOD_CHIPS = Color3.fromRGB(150, 105, 60)
local STONE_CHIPS = Color3.fromRGB(150, 150, 155)
local DUST = Color3.fromRGB(205, 185, 145)
local SPARKS = Color3.fromRGB(255, 210, 110)
local GHOST_COLOR = Color3.fromRGB(90, 230, 110) -- el verde de colocación de BuildController (VALID_COLOR)
local FALL_SECONDS = 1.2 -- las de fall de ResourceService
local FALL_DEGREES = 85
local FADE_DELAY_SECONDS = 0.5
local FADE_SECONDS = 0.4
local ROCK_BREAK_SECONDS = 0.35
local HIT_SECONDS = 0.3
local HOLD_SOUND_DELAY_SECONDS = 0.6
local HIT_TILT_WOOD = 1.4 -- grados de la sacudida del árbol
local HIT_TILT_STONE = 0.6
local PREVIEW_RISE_STUDS = 2
local PREVIEW_RISE_SPEED = 1.7 -- studs por segundo
local PREVIEW_SPIN_SPEED = 2.2 -- radianes por segundo
local BUILD_RISE_SECONDS = 0.7
local TORCH_BRIGHTNESS = 4 -- el doble de la PointLight de BuildModels.StandingTorch: es lo que marca el anochecer
local TORCH_RANGE = 34
local TORCH_FIRE_SIZE = 8
local TORCH_LIGHT_SECONDS = 0.4

type Rest = { pivot: CFrame, ground: Vector3 }
type BarState = { bar: SurvivalBar.Bar, value: number }
type State = {
	folder: Folder?,
	tweens: { { tween: Tween, value: NumberValue } },
	rest: { [Model]: Rest },
	held: { [Model]: Model },
	ghosts: { [string]: Model },
	done: { [Sequencer.Event]: boolean }, -- eventos de creación ya atendidos (un seek hacia atrás los repite)
	column: CanvasGroup?,
	bars: { hunger: BarState?, thirst: BarState? },
	flash: boolean,
	preview: { model: Model, t0: number, base: Vector3 }?,
	hook: ((t: number) -> ())?,
	hiddenReal: { { part: BasePart, old: number } }, -- vegetación real escondida en este cliente (hideReal)
}

-- Las barras que hay ahora (la lista no lleva huecos).
local function barsOf(state: State): { BarState }
	local list: { BarState } = {}
	if state.bars.hunger then
		table.insert(list, state.bars.hunger)
	end
	if state.bars.thirst then
		table.insert(list, state.bars.thirst)
	end
	return list
end

local function stateOf(ctx: Sequencer.Context): State
	local state = ctx._survival
	if state then
		return state
	end
	local fresh: State = {
		folder = nil,
		tweens = {},
		rest = {},
		held = {},
		ghosts = {},
		done = {},
		column = nil,
		bars = {},
		flash = true,
		preview = nil,
		hook = nil,
		hiddenReal = {},
	}
	ctx._survival = fresh
	-- Por cuadro, con el reloj de la escena: el parpadeo de las barras y el giro del arma sobre la mesa.
	local low = Config.Survival.LowThreshold / Survival.MAX
	local function frame(t: number)
		if fresh.flash then
			local blinkOn = os.clock() % 1 < 0.5
			for _, entry in barsOf(fresh) do
				-- El tamaño del relleno, no el valor de destino: el parpadeo empieza cuando la barra llega abajo.
				local alarm = entry.bar.fill.Size.X.Scale <= low
				entry.bar.fill.BackgroundColor3 = if alarm and blinkOn then SurvivalBar.LOW_COLOR else entry.bar.color
			end
		end
		local preview = fresh.preview
		if preview and preview.model.Parent then
			local age = math.max(t - preview.t0, 0)
			local lift = math.min(age * PREVIEW_RISE_SPEED, PREVIEW_RISE_STUDS)
			preview.model:PivotTo(
				CFrame.new(preview.base + Vector3.new(0, lift, 0))
					* CFrame.Angles(0, age * PREVIEW_SPIN_SPEED, 0)
					* CFrame.Angles(0, 0, math.rad(20))
			)
		end
	end
	fresh.hook = frame
	local hooks = ctx.frameHooks
	if not hooks then
		hooks = {}
		ctx.frameHooks = hooks
	end
	table.insert(hooks, frame)
	return fresh
end

local function actorOf(name: any, ctx: Sequencer.Context, kind: string): Model?
	local actors = ctx.actors
	local actor = if actors and typeof(name) == "string" then actors[name] else nil
	if not actor then
		warn(`SurvivalActor: el evento {kind} pide un actor que no existe ({name})`)
	end
	return actor
end

local function anchorOf(ctx: Sequencer.Context): CFrame
	return ctx.anchor or CFrame.identity
end

-- La carpeta del Workspace donde caen las piezas de esta escena (se borra al acabar).
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

-- Anima un NumberValue de 0 a 1 y llama a onStep(alpha) en cada paso y a onDone al acabar (no si se cancela).
local function animate(
	state: State,
	seconds: number,
	style: Enum.EasingStyle,
	direction: Enum.EasingDirection,
	onStep: (alpha: number) -> (),
	onDone: (() -> ())?
)
	local value = Instance.new("NumberValue")
	local tween = TweenService:Create(value, TweenInfo.new(seconds, style, direction), { Value = 1 })
	local entry = { tween = tween, value = value }
	table.insert(state.tweens, entry)
	value.Changed:Connect(onStep)
	tween.Completed:Connect(function(playback)
		local index = table.find(state.tweens, entry)
		if index then
			table.remove(state.tweens, index)
		end
		value:Destroy()
		if playback == Enum.PlaybackState.Completed and onDone then
			onDone()
		end
	end)
	tween:Play()
end

-- Dónde estaba un prop antes de tocarlo (su marco y el suelo bajo él), para inclinarlo y tirarlo siempre desde el reposo.
local function restOf(state: State, node: Model): Rest
	local rest = state.rest[node]
	if not rest then
		local pivot = node:GetPivot()
		local box, size = node:GetBoundingBox()
		rest = {
			pivot = pivot,
			ground = Vector3.new(pivot.Position.X, box.Position.Y - size.Y / 2, pivot.Position.Z),
		}
		state.rest[node] = rest
	end
	return rest
end

-- Un chorro de partículas (astillas, lascas, chispas o polvo) en `position`, hacia `direction`. La pieza que las emite
-- es invisible y se borra sola.
local function burst(
	state: State,
	position: Vector3,
	direction: Vector3,
	color: Color3,
	count: number,
	options: {
		speed: NumberRange,
		size: number,
		lifetime: NumberRange,
		spread: number,
		gravity: number,
		glow: number?,
	}
)
	local part = Instance.new("Part")
	part.Name = "Burst"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = CFrame.lookAt(position, position + direction)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, options.size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = options.lifetime
	emitter.Speed = options.speed
	emitter.SpreadAngle = Vector2.new(options.spread, options.spread)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Acceleration = Vector3.new(0, -options.gravity, 0)
	emitter.LightEmission = options.glow or 0
	emitter.Parent = part
	part.Parent = fxFolder(state)
	emitter:Emit(count)
	Debris:AddItem(part, 2)
end

local function fadeOut(model: Instance, seconds: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			TweenService:Create(descendant, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		end
	end
end

local function hide(model: Instance)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		end
	end
end

-- ===================================== nodeHit =====================================

local function onNodeHit(event: Sequencer.Event, ctx: Sequencer.Context)
	if ctx.seeking then
		return
	end
	local actor = actorOf(event.actor, ctx, "nodeHit")
	local node = actorOf(event.node, ctx, "nodeHit")
	if not (actor and node and node.Parent) then
		return
	end
	local state = stateOf(ctx)
	local stone = event.material == "stone"
	local rest = restOf(state, node)
	local toward = (actor:GetPivot().Position - rest.pivot.Position) * Vector3.new(1, 0, 1)
	toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.zAxis
	local anchor = node.PrimaryPart
	local radius = if anchor then math.min(anchor.Size.X / 2, 3) else 1
	local point = rest.pivot.Position + toward * radius

	burst(
		state,
		point,
		toward + Vector3.new(0, 0.5, 0),
		if stone then STONE_CHIPS else WOOD_CHIPS,
		if stone then 12 else 10,
		{
			speed = NumberRange.new(7, 13),
			size = 0.35,
			lifetime = NumberRange.new(0.35, 0.65),
			spread = 55,
			gravity = 40,
		}
	)
	Sfx.play(if stone then "Mine" else "Chop", point)

	-- Sacudida: se inclina hacia el lado contrario al actor y vuelve, amortiguada.
	local away = -toward
	local axis = Vector3.new(away.Z, 0, -away.X)
	local tilt = if stone then HIT_TILT_STONE else HIT_TILT_WOOD
	animate(state, HIT_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.In, function(alpha)
		if not node.Parent then
			return
		end
		local degrees = math.sin(alpha * math.pi * 3) * (1 - alpha) * tilt
		node:PivotTo(
			CFrame.new(rest.ground)
				* CFrame.fromAxisAngle(axis, math.rad(degrees))
				* CFrame.new(-rest.ground)
				* rest.pivot
		)
	end, function()
		if node.Parent then
			node:PivotTo(rest.pivot)
		end
	end)
end

-- ===================================== nodeFall =====================================

local function onNodeFall(event: Sequencer.Event, ctx: Sequencer.Context)
	local node = actorOf(event.node, ctx, "nodeFall")
	if not (node and node.Parent) then
		return
	end
	local state = stateOf(ctx)
	local nodeType = node:GetAttribute(NodeModels.ATTRIBUTE)
	local harvest = node:FindFirstChild(NodeModels.HARVEST_FOLDER)
	local rest = restOf(state, node)
	local seeking = ctx.seeking == true

	if harvest then
		-- Una mata: solo desaparece el racimo.
		if seeking then
			hide(harvest)
		else
			Sfx.play("Pickup", rest.pivot.Position)
			fadeOut(harvest, 0.3)
		end
		return
	end

	if nodeType == "Rock" or nodeType == "Obsidian" then
		if seeking then
			hide(node)
			return
		end
		Sfx.play("RockBreak", rest.pivot.Position)
		burst(state, rest.pivot.Position, Vector3.yAxis, STONE_CHIPS, 18, {
			speed = NumberRange.new(9, 16),
			size = 0.5,
			lifetime = NumberRange.new(0.4, 0.8),
			spread = 80,
			gravity = 45,
		})
		animate(state, ROCK_BREAK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(alpha)
			if node.Parent then
				node:ScaleTo(math.max(1 - alpha, 0.05))
			end
		end, function()
			if node.Parent then
				hide(node)
			end
		end)
		return
	end

	-- Un árbol o una palmera: cae girando sobre su base, hacia `dir` (por defecto, alejándose del origen del anchor).
	if seeking then
		hide(node)
		return
	end
	local anchor = anchorOf(ctx)
	local direction = if typeof(event.dir) == "Vector3"
		then anchor:VectorToWorldSpace(event.dir) * Vector3.new(1, 0, 1)
		else (rest.pivot.Position - anchor.Position) * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.1 then
		direction = Vector3.xAxis
	end
	-- Girar alrededor de (arriba × dirección) inclina la copa hacia `direction`.
	local unit = direction.Unit
	local axis = Vector3.new(unit.Z, 0, -unit.X)
	for _, descendant in node:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
		end
	end
	local seconds: number = event.seconds or FALL_SECONDS
	animate(state, seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function(alpha)
		if node.Parent then
			node:PivotTo(
				CFrame.new(rest.ground)
					* CFrame.fromAxisAngle(axis, math.rad(FALL_DEGREES * alpha))
					* CFrame.new(-rest.ground)
					* rest.pivot
			)
		end
	end, function()
		if not node.Parent then
			return
		end
		Sfx.play("TreeFall", rest.ground)
		task.delay(FADE_DELAY_SECONDS, function()
			if node.Parent then
				fadeOut(node, FADE_SECONDS)
			end
		end)
	end)
end

-- ===================================== loot =====================================

local function onLoot(event: Sequencer.Event, ctx: Sequencer.Context)
	if ctx.seeking then
		return
	end
	local actor = actorOf(event.actor, ctx, "loot")
	if not actor then
		return
	end
	local text = LabActor.combatModule("CombatTextController")
	if text and text.showLootLocal then
		pcall(text.showLootLocal, event.item, event.n or 1, actor)
	else
		warn("SurvivalActor: no hay CombatClient/CombatTextController; el evento loot no hace nada")
	end
end

-- ===================================== survivalBars =====================================

local function createBars(state: State, gui: ScreenGui, instant: boolean)
	local column = Instance.new("CanvasGroup")
	column.Name = "SurvivalBars"
	column.BackgroundTransparency = 1
	column.BorderSizePixel = 0
	column.Position = UDim2.new(0, 12, ScreenBands.TOP, ScreenBands.TOP_GAP)
	column.Size = UDim2.fromOffset(SurvivalBar.BAR_WIDTH + 30, SurvivalBar.ROW_HEIGHT * 2 + 4)
	column.GroupTransparency = if instant then 0 else 1
	column.ZIndex = 2
	column.Parent = gui
	-- En una grabación a 1920x1080 las barras del HUD (170 px) se leían diminutas: aquí van al doble de tamaño.
	local scale = Instance.new("UIScale")
	scale.Scale = 2
	scale.Parent = column
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = column
	state.column = column
	state.bars.hunger = { bar = SurvivalBar.new(column, 1, "🍖", SurvivalBar.HUNGER_COLOR), value = 1 }
	state.bars.thirst = { bar = SurvivalBar.new(column, 2, "💧", SurvivalBar.THIRST_COLOR), value = 1 }
	if not instant then
		TweenService:Create(column, TweenInfo.new(BARS_FADE_SECONDS), { GroupTransparency = 0 }):Play()
	end
end

local function setBar(entry: BarState?, target: any, seconds: number)
	if not entry or typeof(target) ~= "number" then
		return
	end
	local value = math.clamp(target, 0, 1)
	entry.value = value
	local size = UDim2.fromScale(value, 1)
	if seconds <= 0 then
		entry.bar.fill.Size = size
	else
		TweenService:Create(entry.bar.fill, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = size,
		}):Play()
	end
	entry.bar.fill.Visible = value > 0
end

local function onSurvivalBars(event: Sequencer.Event, ctx: Sequencer.Context)
	local state = stateOf(ctx)
	local instant = ctx.seeking == true
	if event.show == false then
		local column = state.column
		if column and column.Parent then
			if instant then
				column:Destroy()
			else
				TweenService:Create(column, TweenInfo.new(BARS_FADE_SECONDS), { GroupTransparency = 1 }):Play()
				Debris:AddItem(column, BARS_FADE_SECONDS + 0.1)
			end
		end
		state.column = nil
		state.bars = {}
		return
	end
	local column = state.column
	if not column or not column.Parent then
		local gui = Presentation.gui()
		if not gui then
			return
		end
		createBars(state, gui, instant)
	end
	if event.flash ~= nil then
		state.flash = event.flash == true
	end
	local seconds: number = if instant then 0 else (event.seconds or BARS_DEFAULT_SECONDS)
	setBar(state.bars.hunger, event.hunger, seconds)
	setBar(state.bars.thirst, event.thirst, seconds)
	if not state.flash then
		for _, entry in barsOf(state) do
			entry.bar.fill.BackgroundColor3 = entry.bar.color
		end
	end
end

-- ===================================== holdProp =====================================

local function propPart(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	offset: CFrame,
	main: BasePart?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = if main then main.CFrame * offset else offset
	if main then
		local weld = Instance.new("Weld")
		weld.Part0 = main
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
	end
	part.Parent = model
	return part
end

-- Un plátano (tres bloques amarillos en arco con la punta marrón) o un coco (un bloque marrón con la tapa clara y una
-- pajita): pocos bloques planos, como el resto del juego.
local function buildProp(item: string): Model?
	local model = Instance.new("Model")
	model.Name = "HeldProp"
	model:SetAttribute("CinematicKeep", true)
	if item == "Banana" then
		local yellow = Color3.fromRGB(250, 220, 70)
		local main = propPart(model, "Middle", Vector3.new(0.4, 0.4, 0.9), yellow, CFrame.identity, nil)
		model.PrimaryPart = main
		propPart(
			model,
			"Top",
			Vector3.new(0.4, 0.4, 0.7),
			yellow,
			CFrame.new(0, 0.28, -0.7) * CFrame.Angles(math.rad(35), 0, 0),
			main
		)
		propPart(
			model,
			"Bottom",
			Vector3.new(0.4, 0.4, 0.7),
			yellow,
			CFrame.new(0, 0.28, 0.7) * CFrame.Angles(math.rad(-35), 0, 0),
			main
		)
		propPart(
			model,
			"Tip",
			Vector3.new(0.25, 0.25, 0.25),
			Color3.fromRGB(95, 65, 35),
			CFrame.new(0, 0.55, -1.1),
			main
		)
		return model
	elseif item == "Coconut" then
		local main =
			propPart(model, "Shell", Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(105, 72, 45), CFrame.identity, nil)
		model.PrimaryPart = main
		propPart(model, "Cap", Vector3.new(0.6, 0.15, 0.6), Color3.fromRGB(238, 228, 205), CFrame.new(0, 0.5, 0), main)
		propPart(model, "Straw", Vector3.new(0.1, 0.5, 0.1), Color3.fromRGB(205, 70, 60), CFrame.new(0.1, 0.8, 0), main)
		return model
	end
	model:Destroy()
	return nil
end

local function onHoldProp(event: Sequencer.Event, ctx: Sequencer.Context)
	local actor = actorOf(event.actor, ctx, "holdProp")
	if not actor then
		return
	end
	local state = stateOf(ctx)
	local old = state.held[actor]
	if old then
		old:Destroy()
		state.held[actor] = nil
	end
	if typeof(event.item) ~= "string" then
		return
	end
	-- Con `hand = "Right"` va en la derecha (la que usa Consume): el actor suelta antes el arma con equip weapon = false.
	local right = event.hand == "Right"
	local hand = if right
		then actor:FindFirstChild("RightHand") or actor:FindFirstChild("Right Arm")
		else actor:FindFirstChild("LeftHand") or actor:FindFirstChild("Left Arm")
	if not (hand and hand:IsA("BasePart")) then
		warn(`SurvivalActor: el actor {event.actor} no tiene la mano pedida para holdProp`)
		return
	end
	local prop = buildProp(event.item)
	if not (prop and prop.PrimaryPart) then
		warn(`SurvivalActor: holdProp con un objeto desconocido ({event.item})`)
		return
	end
	-- Sobre la palma, algo hacia delante; el plátano de través para que se vea la curva.
	local offset = CFrame.new(0, -0.4, -0.35) * CFrame.Angles(0, math.rad(90), 0)
	prop:PivotTo(hand.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = prop.PrimaryPart
	weld.C0 = offset
	weld.Parent = prop.PrimaryPart
	prop.Parent = actor
	state.held[actor] = prop
	if typeof(event.sound) == "string" and not ctx.seeking then
		task.delay(event.delay or HOLD_SOUND_DELAY_SECONDS, function()
			if prop.Parent then
				Sfx.play(event.sound, hand.Position)
			end
		end)
	end
end

-- ===================================== craftFx y equip =====================================

local function onCraftFx(event: Sequencer.Event, ctx: Sequencer.Context)
	local state = stateOf(ctx)
	local at = anchorOf(ctx):PointToWorldSpace(event.at or Vector3.zero)
	if not ctx.seeking then
		burst(state, at, Vector3.yAxis, SPARKS, 16, {
			speed = NumberRange.new(8, 15),
			size = 0.3,
			lifetime = NumberRange.new(0.3, 0.6),
			spread = 70,
			gravity = 35,
			glow = 1,
		})
		Sfx.play("Craft", at)
	end
	if state.done[event] then
		return
	end
	state.done[event] = true
	if state.preview then
		state.preview.model:Destroy()
		state.preview = nil
	end
	local ok, model = pcall(WeaponTools.previewWeapon, event.weapon)
	if not ok then
		warn(`SurvivalActor: no se puede hacer la vista previa de {event.weapon}: {model}`)
		return
	end
	local preview = model :: Model
	preview.Name = "CraftPreview"
	preview:SetAttribute("CinematicKeep", true)
	for _, descendant in preview:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
	preview:PivotTo(CFrame.new(at))
	preview.Parent = fxFolder(state)
	state.preview = { model = preview, t0 = event.t, base = at }
end

local function onEquip(event: Sequencer.Event, ctx: Sequencer.Context)
	local actor = actorOf(event.actor, ctx, "equip")
	if not actor then
		return
	end
	local state = stateOf(ctx)
	if state.preview then
		state.preview.model:Destroy()
		state.preview = nil
	end
	if typeof(event.weapon) == "string" then
		Actors.holdWeapon(actor, event.weapon, event.skin)
	elseif event.weapon == false then
		Actors.dropWeapon(actor)
	end
end

-- Esconde (solo en este cliente) la vegetación real del mapa cercana a un punto: un árbol real a unos 12 studs de la tala
-- salía en plano como un poste blanco y una pieza gris. Solo modelos de Vegetacion, Recursos o Cultivos.
local HIDDEN_FOLDERS = { Vegetacion = true, Recursos = true, Cultivos = true }

local function onHideReal(event: Sequencer.Event, ctx: Sequencer.Context)
	local state = stateOf(ctx)
	if state.done[event] then
		return
	end
	state.done[event] = true
	local center = anchorOf(ctx):PointToWorldSpace(event.at or Vector3.zero)
	local radius: number = event.radius or 30
	local seen: { [Model]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInRadius(center, radius) do
		local model = part:FindFirstAncestorOfClass("Model")
		if not model and part.Parent and part.Parent:IsA("Folder") and HIDDEN_FOLDERS[part.Parent.Name] then
			-- Una pieza suelta de la carpeta (el Helecho no es un Model): se esconde ella sola.
			table.insert(state.hiddenReal, { part = part, old = part.LocalTransparencyModifier })
			part.LocalTransparencyModifier = 1
			continue
		end
		while model and model.Parent and model.Parent:IsA("Model") do
			model = model.Parent
		end
		local folder = if model then model.Parent else nil
		if model and not seen[model] and folder and folder:IsA("Folder") and HIDDEN_FOLDERS[folder.Name] then
			seen[model] = true
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(state.hiddenReal, { part = descendant, old = descendant.LocalTransparencyModifier })
					descendant.LocalTransparencyModifier = 1
				end
			end
		end
	end
end

-- ===================================== buildGhost y buildRise =====================================

local function buildKey(event: Sequencer.Event): string
	if typeof(event.key) == "string" then
		return event.key
	end
	local at: Vector3 = event.at or Vector3.zero
	return `{event.id}@{math.round(at.X)},{math.round(at.Z)}`
end

-- El marco del centro de la pieza `id` apoyada en el suelo `at` (relativo al anchor), girada `yaw`.
local function pieceFrame(id: string, at: Vector3, yaw: number?, ctx: Sequencer.Context, lowered: number): CFrame
	local height = Buildables[id].size.Y
	return anchorOf(ctx)
		* CFrame.new(at + Vector3.new(0, height / 2 - lowered * height, 0))
		* CFrame.Angles(0, math.rad(yaw or 0), 0)
end

local function onBuildGhost(event: Sequencer.Event, ctx: Sequencer.Context)
	if ctx.seeking then
		return
	end
	local state = stateOf(ctx)
	if state.done[event] then
		return
	end
	state.done[event] = true
	local model = BuildModels.build(event.id)
	BuildModels.makeGhost(model)
	model:SetAttribute("CinematicKeep", true)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = GHOST_COLOR
	highlight.OutlineColor = GHOST_COLOR
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	model:PivotTo(pieceFrame(event.id, event.at or Vector3.zero, event.yaw, ctx, 0))
	model.Parent = fxFolder(state)
	state.ghosts[buildKey(event)] = model
end

-- La StandingTorch nace apagada (el fuego y la luz se encienden al terminar de subir). Devuelve la función que la enciende.
local function torchOf(model: Model): (() -> ())?
	local fire = model:FindFirstChildWhichIsA("Fire", true)
	local light = model:FindFirstChildWhichIsA("PointLight", true)
	if not (fire or light) then
		return nil
	end
	if fire then
		fire.Enabled = false
	end
	if light then
		light.Brightness = 0
		light.Shadows = false
		light.Range = TORCH_RANGE
	end
	return function()
		if fire and fire.Parent then
			-- La llama de BuildModels (tamaño 3) no se veía a 15 studs en la grabación: aquí va más grande.
			fire.Size = TORCH_FIRE_SIZE
			fire.Heat = 12
			fire.Enabled = true
		end
		if light and light.Parent then
			TweenService:Create(light, TweenInfo.new(TORCH_LIGHT_SECONDS), { Brightness = TORCH_BRIGHTNESS }):Play()
		end
	end
end

local function onBuildRise(event: Sequencer.Event, ctx: Sequencer.Context)
	local state = stateOf(ctx)
	if state.done[event] then
		return
	end
	state.done[event] = true
	local key = buildKey(event)
	local ghost = state.ghosts[key]
	if ghost then
		ghost:Destroy()
		state.ghosts[key] = nil
	end
	local id: string = event.id
	local at: Vector3 = event.at or Vector3.zero
	local model = BuildModels.build(id)
	model:SetAttribute("CinematicKeep", true)
	local light = if id == "StandingTorch" then torchOf(model) else nil
	local final = pieceFrame(id, at, event.yaw, ctx, 0)
	local hidden = pieceFrame(id, at, event.yaw, ctx, 1)
	model.Parent = fxFolder(state)

	if ctx.seeking then
		model:PivotTo(final)
		if light then
			light()
		end
		return
	end
	model:PivotTo(hidden)
	local ground = anchorOf(ctx):PointToWorldSpace(at)
	Sfx.play("Build", ground)
	burst(state, ground + Vector3.new(0, 0.5, 0), Vector3.yAxis, DUST, 14, {
		speed = NumberRange.new(4, 8),
		size = 1.4,
		lifetime = NumberRange.new(0.5, 0.9),
		spread = 85,
		gravity = -2,
	})
	animate(state, event.seconds or BUILD_RISE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha)
		if model.Parent then
			model:PivotTo(hidden:Lerp(final, alpha))
		end
	end, function()
		if model.Parent then
			model:PivotTo(final)
			if light then
				light()
			end
		end
	end)
end

-- ===================================== instalación =====================================

function SurvivalActor.install(sequencer: typeof(Sequencer))
	sequencer.registerHandler("nodeHit", onNodeHit)
	sequencer.registerHandler("nodeFall", onNodeFall)
	sequencer.registerHandler("loot", onLoot)
	sequencer.registerHandler("survivalBars", onSurvivalBars)
	sequencer.registerHandler("holdProp", onHoldProp)
	sequencer.registerHandler("equip", onEquip)
	sequencer.registerHandler("hideReal", onHideReal)
	sequencer.registerHandler("craftFx", onCraftFx)
	sequencer.registerHandler("buildGhost", onBuildGhost)
	sequencer.registerHandler("buildRise", onBuildRise)

	sequencer.addHooks({
		finish = function(_, ctx)
			local state = ctx._survival
			if not state then
				return
			end
			for _, entry in table.clone(state.tweens) do
				entry.tween:Cancel()
				entry.value:Destroy()
			end
			table.clear(state.tweens)
			local hooks = ctx.frameHooks
			if hooks and state.hook then
				local index = table.find(hooks, state.hook)
				if index then
					table.remove(hooks, index)
				end
			end
			if state.column then
				state.column:Destroy()
			end
			for _, prop in state.held do
				prop:Destroy()
			end
			for _, entry in state.hiddenReal do
				if entry.part.Parent then
					entry.part.LocalTransparencyModifier = entry.old
				end
			end
			if state.folder then
				state.folder:Destroy()
			end
			ctx._survival = nil
		end,
	})
end

return SurvivalActor
