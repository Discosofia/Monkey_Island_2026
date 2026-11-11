--!strict
-- Eventos de la parcela permanente y del modo infinito de la Isla para las cinemáticas (Fase 25, G14d).
-- PlotActor.install(Sequencer) registra:
--   plotHide { at, radius? }               esconde (solo en este cliente, se devuelve al acabar) el borde, el cartel y las
--       estructuras reales de las parcelas (carpeta Parcelas y piezas con el atributo PlotStructure) a menos de `radius` studs
--       de `at` (relativo al anchor; 30 por defecto): así el hueco de la escena no enseña lo que haya de verdad.
--   plotMarker { at, yaw? }                el borde dorado de 24x24 de una parcela permanente (los colores y el grosor de
--       BuildingService.setPlotLook) y el poste con el cartel «🏡 Parcela de {nombre}» (el del jugador local). `at` es el centro
--       de la parcela sobre el suelo (relativo al anchor) y `yaw` su giro (-Z mira al centro del Basecamp, donde va el poste).
--   plotPiece { key, id, level, at, yaw? } una estructura de la parcela (PlotModels.build) en `at` (relativo al anchor, el
--       suelo se mide con un rayo) girada `yaw` grados. `key` la nombra para plotUpgrade. En la Incubadora, los huevos van del
--       color de una rareza (Rarities), como los pinta PlotService con el huevo del nido.
--   plotUpgrade { key, level }             la estructura `key` cambia al grado `level` (1 a 3): destello, polvo y sonido Build
--       (como buildRise de SurvivalActor) y rebote de escala del modelo nuevo.
--   dayClock { show?, day?, hour? }        el reloj del HUD de la Isla («Día {day} · {icono} {hora}», IslandHUDController) en
--       grande, arriba al centro, bajo la franja de arriba. `day` lo cambia (con un latido), `hour` fija la hora (si falta, se
--       lee de Lighting.ClockTime, que es la que dibuja la escena); show = false lo quita.
-- Todo lo que crea (carpeta «CinematicPlotFx», reloj) lleva CinematicKeep y se borra al acabar la escena; lo escondido se
-- devuelve. Los efectos con partículas no salen al saltar a un instante (seek); los cambios de estado, sí. Solo cliente.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Actors = require(script.Parent.Actors)
local Config = require(script.Parent.Parent.Config)
local PlotModels = require(script.Parent.Parent.PlotModels)
local Presentation = require(script.Parent.Presentation)
local Rarities = require(script.Parent.Parent.Data.Rarities)
local Sequencer = require(script.Parent.Sequencer)
local Sfx = require(script.Parent.Parent.Sfx)
local Strings = require(script.Parent.Parent.Strings)

local T = Strings.t

local PlotActor = {}

local FOLDER_NAME = "CinematicPlotFx"
local MARKERS_FOLDER = "Parcelas" -- la carpeta de BuildingService con los bordes y carteles reales
local PLOT_ATTRIBUTE = "PlotStructure"
local TOP_BAND = 0.12 -- el alto de la franja negra de arriba (Presentation), en fracción de la pantalla
local PERMANENT_BORDER_COLOR = Color3.fromRGB(240, 190, 60) -- el de BuildingService
local SIGN_POST_COLOR = Color3.fromRGB(205, 175, 115)
local SIGN_TEXT_COLOR = Color3.fromRGB(255, 235, 190)
local BORDER_HEIGHT = 0.4
local BORDER_THICKNESS = 0.8
local DUST = Color3.fromRGB(205, 185, 145)
local SPARKS = Color3.fromRGB(255, 210, 110)
local FLASH_COLOR = Color3.fromRGB(255, 236, 170)
local UPGRADE_BOUNCE_SECONDS = 0.45
local UPGRADE_START_SCALE = 0.7
local FLASH_SECONDS = 0.6
local CLOCK_FADE_SECONDS = 0.4
local CLOCK_POP_SECONDS = 0.35
local CLOCK_POP_SCALE = 1.25
-- Colores de rareza de los huevos de la incubadora, uno por hueco (el II lleva uno y el III dos).
local EGG_RARITIES = { "Rare", "Legendary" }

type Piece = { model: Model, id: string, level: number, frame: CFrame, height: number }
type State = {
	folder: Folder?,
	tweens: { { tween: Tween, value: NumberValue } },
	pieces: { [string]: Piece },
	done: { [Sequencer.Event]: boolean },
	hidden: { { part: BasePart, old: number } },
	label: TextLabel?,
	scale: UIScale?,
	day: number,
	hour: number?,
	shownText: string,
	hook: ((t: number) -> ())?,
}

local function anchorOf(ctx: Sequencer.Context): CFrame
	return ctx.anchor or CFrame.identity
end

-- La hora del reloj en grande: «Día 8 · ☀️ 14:30», con las mismas frases que el HUD de la Isla.
local function clockText(state: State): string
	local hour = state.hour or Lighting.ClockTime
	local minutes = math.floor(hour * 60) % (24 * 60)
	local icon = if hour % 24 >= 6 and hour % 24 < 18 then "☀️" else "🌙"
	return T(
		"Día {day} · {icon} {time}",
		{ day = state.day, icon = icon, time = string.format("%02d:%02d", minutes // 60, minutes % 60) }
	)
end

local function stateOf(ctx: Sequencer.Context): State
	local state = ctx._plot
	if state then
		return state
	end
	local fresh: State = {
		folder = nil,
		tweens = {},
		pieces = {},
		done = {},
		hidden = {},
		label = nil,
		scale = nil,
		day = 1,
		hour = nil,
		shownText = "",
		hook = nil,
	}
	ctx._plot = fresh
	-- Por cuadro: el texto del reloj sigue a la hora de la escena (solo se reescribe cuando cambia).
	local function frame(_t: number)
		local label = fresh.label
		if label and label.Parent then
			local text = clockText(fresh)
			if text ~= fresh.shownText then
				fresh.shownText = text
				label.Text = text
			end
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

-- Un chorro de partículas (polvo o chispas) en `position`. La pieza que las emite es invisible y se borra sola.
local function burst(state: State, position: Vector3, color: Color3, count: number, size: number, glow: number)
	local part = Instance.new("Part")
	part.Name = "Burst"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = CFrame.lookAt(position, position + Vector3.yAxis)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(5, 10)
	emitter.SpreadAngle = Vector2.new(85, 85)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Acceleration = Vector3.new(0, if glow > 0 then -30 else -2, 0)
	emitter.LightEmission = glow
	emitter.Parent = part
	part.Parent = fxFolder(state)
	emitter:Emit(count)
	Debris:AddItem(part, 2)
end

-- ===================================== plotHide =====================================

-- La parcela real a la que pertenece una pieza: el modelo de borde y cartel (carpeta Parcelas del Workspace) o la estructura
-- con el atributo PlotStructure.
local function realPlotRoot(part: BasePart): Instance?
	local node: Instance? = part
	while node and node ~= Workspace do
		if node:GetAttribute(PLOT_ATTRIBUTE) ~= nil then
			return node
		end
		local parent = node.Parent
		if parent and parent.Name == MARKERS_FOLDER and parent.Parent == Workspace then
			return node
		end
		node = parent
	end
	return nil
end

local function onPlotHide(event: Sequencer.Event, ctx: Sequencer.Context)
	local state = stateOf(ctx)
	if state.done[event] then
		return
	end
	state.done[event] = true
	local center = anchorOf(ctx):PointToWorldSpace(event.at or Vector3.zero)
	local radius: number = event.radius or 30
	local seen: { [Instance]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInRadius(center, radius) do
		local root = realPlotRoot(part)
		if root and not seen[root] then
			seen[root] = true
			for _, descendant in root:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(state.hidden, { part = descendant, old = descendant.LocalTransparencyModifier })
					descendant.LocalTransparencyModifier = 1
				end
			end
		end
	end
end

-- ===================================== plotMarker =====================================

local function decorPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function onPlotMarker(event: Sequencer.Event, ctx: Sequencer.Context)
	local state = stateOf(ctx)
	if state.done[event] then
		return
	end
	state.done[event] = true
	local anchor = anchorOf(ctx)
	local at = Actors.snapToTerrain(anchor, event.at or Vector3.zero)
	local base = CFrame.new(anchor:PointToWorldSpace(at))
		* anchor.Rotation
		* CFrame.Angles(0, math.rad(event.yaw or 0), 0)
	local size = Config.Building.PlotSize
	local half = size / 2
	local model = Instance.new("Model")
	model.Name = "PlotMarker"
	model:SetAttribute("CinematicKeep", true)
	for _, side in { -1, 1 } do
		decorPart(
			"Border",
			Vector3.new(size, BORDER_HEIGHT, BORDER_THICKNESS),
			base * CFrame.new(0, BORDER_HEIGHT / 2, side * half),
			PERMANENT_BORDER_COLOR,
			Enum.Material.Slate,
			model
		)
		decorPart(
			"Border",
			Vector3.new(BORDER_THICKNESS, BORDER_HEIGHT, size),
			base * CFrame.new(side * half, BORDER_HEIGHT / 2, 0),
			PERMANENT_BORDER_COLOR,
			Enum.Material.Slate,
			model
		)
	end
	-- El poste con el cartel, en el lado que mira al centro (-Z de la parcela), como el de BuildingService.
	local post = decorPart(
		"SignPost",
		Vector3.new(0.4, 3, 0.4),
		base * CFrame.new(0, 1.5, -half),
		SIGN_POST_COLOR,
		Enum.Material.Wood,
		model
	)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(320, 56)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = 400
	billboard:SetAttribute("CinematicKeep", true) -- HudHider esconde los carteles del mundo salvo los que lo llevan
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = T("🏡 Parcela de {player}", { player = Players.LocalPlayer.DisplayName })
	label.TextColor3 = SIGN_TEXT_COLOR
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Parent = billboard
	billboard.Parent = post
	model.Parent = fxFolder(state)
end

-- ===================================== plotPiece y plotUpgrade =====================================

-- Pinta los huevos de la incubadora con el color de una rareza por hueco (Egg y EggTop; Egg2 y Egg2Top en el III).
local function paintEggs(model: Model)
	for slot, rarity in EGG_RARITIES do
		local suffix = if slot == 1 then "" else tostring(slot)
		for _, name in { `Egg{suffix}`, `Egg{suffix}Top` } do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Color = Rarities[rarity].color
			end
		end
	end
end

local function makePiece(id: string, level: number): Model
	local model = PlotModels.build(id, level)
	if id == "Incubator" then
		paintEggs(model)
	end
	model:SetAttribute("CinematicKeep", true)
	return model
end

local function placePiece(state: State, model: Model, frame: CFrame)
	model:PivotTo(frame)
	model.Parent = fxFolder(state)
end

local function onPlotPiece(event: Sequencer.Event, ctx: Sequencer.Context)
	local state = stateOf(ctx)
	if state.done[event] then
		return
	end
	state.done[event] = true
	local anchor = anchorOf(ctx)
	local id: string = event.id
	local level: number = event.level or 1
	local ground = anchor:PointToWorldSpace(Actors.snapToTerrain(anchor, event.at or Vector3.zero))
	-- Un modelo de parcela tiene su centro en la pieza invisible Bounds: se apoya en el suelo por su altura.
	local model = makePiece(id, level)
	local height = if model.PrimaryPart then model.PrimaryPart.Size.Y else 1
	local frame = CFrame.new(ground + Vector3.new(0, height / 2, 0))
		* anchor.Rotation
		* CFrame.Angles(0, math.rad(event.yaw or 0), 0)
	placePiece(state, model, frame)
	local key: string = event.key or id
	local old = state.pieces[key]
	if old then
		old.model:Destroy()
	end
	state.pieces[key] = { model = model, id = id, level = level, frame = frame, height = height }
end

local function onPlotUpgrade(event: Sequencer.Event, ctx: Sequencer.Context)
	local state = stateOf(ctx)
	if state.done[event] then
		return
	end
	state.done[event] = true
	local piece = state.pieces[event.key]
	if not piece then
		warn(`PlotActor: plotUpgrade pide una estructura que no existe ({event.key})`)
		return
	end
	local level: number = math.clamp(event.level or piece.level + 1, 1, 3)
	piece.model:Destroy()
	local model = makePiece(piece.id, level)
	placePiece(state, model, piece.frame)
	piece.model = model
	piece.level = level
	if ctx.seeking then
		return
	end
	local center = piece.frame.Position
	local foot = center - Vector3.new(0, piece.height / 2, 0)
	Sfx.play("Build", foot)
	burst(state, foot + Vector3.new(0, 0.5, 0), DUST, 14, 1.4, 0)
	burst(state, center, SPARKS, 16, 0.3, 1)
	-- Destello: el modelo nuevo se enciende en dorado y se apaga.
	local highlight = Instance.new("Highlight")
	highlight.FillColor = FLASH_COLOR
	highlight.OutlineColor = FLASH_COLOR
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	TweenService:Create(highlight, TweenInfo.new(FLASH_SECONDS), { FillTransparency = 1, OutlineTransparency = 1 })
		:Play()
	Debris:AddItem(highlight, FLASH_SECONDS + 0.1)
	-- Rebote de escala apoyado en el suelo: nace al 70 %, se pasa un poco y se asienta.
	local function setScale(scale: number)
		if model.Parent then
			model:ScaleTo(scale)
			model:PivotTo(piece.frame * CFrame.new(0, -(1 - scale) * piece.height / 2, 0))
		end
	end
	setScale(UPGRADE_START_SCALE)
	animate(state, UPGRADE_BOUNCE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function(alpha)
		setScale(UPGRADE_START_SCALE + (1 - UPGRADE_START_SCALE) * alpha)
	end, function()
		setScale(1)
	end)
end

-- ===================================== dayClock =====================================

local function createClock(state: State, instant: boolean): TextLabel?
	local gui = Presentation.gui()
	if not gui then
		return nil
	end
	-- Como el reloj de IslandHUDController (Widgets.label): BuilderSansBold, texto escalado, contorno; aquí centrado y grande.
	local label = Instance.new("TextLabel")
	label.Name = "DayClock"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, TOP_BAND, 12)
	label.Size = UDim2.fromScale(0.42, 0.09)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.35
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Text = ""
	label.ZIndex = 2
	label.TextTransparency = if instant then 0 else 1
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = label
	state.label = label
	state.scale = scale
	state.shownText = ""
	if not instant then
		TweenService:Create(label, TweenInfo.new(CLOCK_FADE_SECONDS), { TextTransparency = 0 }):Play()
	end
	return label
end

local function onDayClock(event: Sequencer.Event, ctx: Sequencer.Context)
	local state = stateOf(ctx)
	local instant = ctx.seeking == true
	if event.show == false then
		local label = state.label
		if label and label.Parent then
			if instant then
				label:Destroy()
			else
				TweenService
					:Create(
						label,
						TweenInfo.new(CLOCK_FADE_SECONDS),
						{ TextTransparency = 1, TextStrokeTransparency = 1 }
					)
					:Play()
				Debris:AddItem(label, CLOCK_FADE_SECONDS + 0.1)
			end
		end
		state.label = nil
		state.scale = nil
		return
	end
	local changed = typeof(event.day) == "number" and event.day ~= state.day
	if typeof(event.day) == "number" then
		state.day = event.day
	end
	if typeof(event.hour) == "number" then
		state.hour = event.hour
	end
	local label = state.label
	local existed = label ~= nil and label.Parent ~= nil
	if not existed then
		label = createClock(state, instant)
	end
	if not label then
		return
	end
	state.shownText = "" -- que el siguiente cuadro reescriba el texto
	label.Text = clockText(state)
	-- Latido al cambiar de día: se hincha y vuelve a su tamaño.
	local scale = state.scale
	if existed and changed and scale and not instant then
		scale.Scale = CLOCK_POP_SCALE
		animate(state, CLOCK_POP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function(alpha)
			scale.Scale = CLOCK_POP_SCALE + (1 - CLOCK_POP_SCALE) * alpha
		end, function()
			scale.Scale = 1
		end)
	end
end

-- ===================================== instalación =====================================

function PlotActor.install(sequencer: typeof(Sequencer))
	sequencer.registerHandler("plotHide", onPlotHide)
	sequencer.registerHandler("plotMarker", onPlotMarker)
	sequencer.registerHandler("plotPiece", onPlotPiece)
	sequencer.registerHandler("plotUpgrade", onPlotUpgrade)
	sequencer.registerHandler("dayClock", onDayClock)

	sequencer.addHooks({
		finish = function(_, ctx)
			local state = ctx._plot
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
			if state.label then
				state.label:Destroy()
			end
			for _, entry in state.hidden do
				if entry.part.Parent then
					entry.part.LocalTransparencyModifier = entry.old
				end
			end
			if state.folder then
				state.folder:Destroy()
			end
			ctx._plot = nil
		end,
	})
end

return PlotActor
