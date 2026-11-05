--!strict
-- Presentación de las cinemáticas (Fase 25): franjas negras, cartel de título, subtítulo inferior y fundido
-- a negro, en un ScreenGui propio "Cinematic". Los textos pasan por Strings.t. El cartel y el subtítulo
-- se colocan dentro de la zona segura 9:16 (docs/videos/README.md), para que el recorte vertical de un
-- Short no los corte. Sin dependencias de Remotes ni Settings: corre en modo edición (allí cuelga de la
-- CoreGui). Presentation.install(Sequencer) registra los eventos letterbox, title, caption y fade.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Sequencer = require(script.Parent.Sequencer)
local Strings = require(script.Parent.Parent.Strings)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local T = Strings.t

local Presentation = {}

-- El Sequencer se pasa a install (no se requiere aquí) para que las escenas del juego y el Plató usen el mismo.
export type SequencerModule = {
	registerHandler: (kind: string, fn: Sequencer.Handler) -> (),
	addHooks: (hooks: Sequencer.Hooks) -> (),
}

export type TextOptions = {
	args: Strings.Args?, -- argumentos del texto principal
	subArgs: Strings.Args?, -- argumentos del subtítulo
	seconds: number?, -- cuánto se queda en pantalla (sin contar los fundidos)
}

local GUI_NAME = "Cinematic"
local BAR_HEIGHT = 0.12 -- alto de cada franja, en fracción de la pantalla
local GOLD = Color3.fromRGB(242, 178, 36)
local FADE_IN = 0.5
local FADE_OUT = 0.6
local TITLE_SECONDS = 3
local CAPTION_SECONDS = 3

local gui: ScreenGui? = nil
local topBar: Frame? = nil
local bottomBar: Frame? = nil
local safe: Frame? = nil
local fadeFrame: Frame? = nil
local titleToken = 0
local captionToken = 0

-- Dónde colgar la interfaz: el PlayerGui en Play y la CoreGui en modo edición.
local function container(): Instance?
	local player = Players.LocalPlayer
	if player then
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			return playerGui
		end
	end
	local ok, core = pcall(function()
		return game:GetService("CoreGui")
	end)
	return if ok then core else nil
end

local function tween(object: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), goal):Play()
end

-- Una franja fuera de pantalla: la de arriba anclada por su borde de abajo (en y = 0 no se ve), la de abajo
-- por su borde de arriba (en y = 1 no se ve).
local function bar(name: string, top: boolean, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0, if top then 1 else 0)
	frame.Position = UDim2.fromScale(0, if top then 0 else 1)
	frame.Size = UDim2.fromScale(1, BAR_HEIGHT)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- El ScreenGui "Cinematic" (se crea al primer uso). Las cinemáticas lo excluyen de HudHider.hide.
function Presentation.gui(): ScreenGui?
	if gui and gui.Parent then
		return gui
	end
	local parent = container()
	if not parent then
		return nil
	end
	local old = parent:FindFirstChild(GUI_NAME)
	if old then
		old:Destroy()
	end
	local screen = Widgets.screen(GUI_NAME, parent)
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 100
	gui = screen

	topBar = bar("Top", true, screen)
	bottomBar = bar("Bottom", false, screen)

	-- Zona segura 9:16 centrada, la mayor que cabe en la pantalla.
	local zone = Instance.new("Frame")
	zone.Name = "Safe"
	zone.AnchorPoint = Vector2.new(0.5, 0.5)
	zone.Position = UDim2.fromScale(0.5, 0.5)
	zone.Size = UDim2.fromScale(1, 1)
	zone.BackgroundTransparency = 1
	zone.Parent = screen
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 9 / 16
	ratio.AspectType = Enum.AspectType.FitWithinMaxSize
	ratio.Parent = zone
	safe = zone

	-- El fundido va encima de todo.
	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BackgroundTransparency = 1
	fade.BorderSizePixel = 0
	fade.ZIndex = 10
	fade.Parent = screen
	fadeFrame = fade
	return screen
end

-- Desliza las franjas negras (arriba y abajo, ~12 % de alto cada una). "instant" las pone sin animar.
function Presentation.letterbox(on: boolean, seconds: number?, instant: boolean?)
	if not Presentation.gui() or not (topBar and bottomBar) then
		return
	end
	if gui and gui:FindFirstChild("ComicLayer") then
		return -- las escenas cómic llevan viñetas (Comic), no franjas negras
	end
	local top = UDim2.fromScale(0, if on then BAR_HEIGHT else 0)
	local bottom = UDim2.fromScale(0, if on then 1 - BAR_HEIGHT else 1)
	if instant then
		topBar.Position, bottomBar.Position = top, bottom
	else
		tween(topBar, seconds or 0.6, { Position = top })
		tween(bottomBar, seconds or 0.6, { Position = bottom })
	end
end

local function textLabel(name: string, parent: Instance, position: UDim2, size: UDim2, color: Color3): TextLabel
	local label = Widgets.label("", parent)
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.TextColor3 = color
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	return label
end

-- Enseña "text" en "label" con fundido de entrada, lo mantiene "seconds" y lo retira con fundido de salida.
-- "current" devuelve el token vigente: si llega otro texto antes, este deja de tocar la etiqueta.
local function showText(label: TextLabel, text: string, seconds: number, token: number, current: () -> number)
	label.Text = text
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	tween(label, FADE_IN, { TextTransparency = 0, TextStrokeTransparency = 0.4 })
	task.delay(FADE_IN + seconds, function()
		if current() == token and label.Parent then
			tween(label, FADE_OUT, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

-- Cartel de título: el nombre grande y, debajo, el subtítulo pequeño. Aparece y se va con fundido.
function Presentation.title(text: string, sub: string?, options: TextOptions?)
	local opts: TextOptions = options or {}
	if not (Presentation.gui() and safe) then
		return
	end
	titleToken += 1
	local token = titleToken
	local main = safe:FindFirstChild("Title") :: TextLabel?
	if not main then
		main = textLabel("Title", safe, UDim2.fromScale(0.5, 0.7), UDim2.fromScale(0.92, 0.12), Color3.new(1, 1, 1))
	end
	local subLabel = safe:FindFirstChild("Subtitle") :: TextLabel?
	if not subLabel then
		subLabel = textLabel("Subtitle", safe, UDim2.fromScale(0.5, 0.8), UDim2.fromScale(0.8, 0.055), GOLD)
	end
	local seconds = opts.seconds or TITLE_SECONDS
	local function current(): number
		return titleToken
	end
	if main then
		showText(main, T(text, opts.args), seconds, token, current)
	end
	if subLabel then
		if sub and sub ~= "" then
			showText(subLabel, T(sub, opts.subArgs), seconds, token, current)
		else
			subLabel.TextTransparency = 1
			subLabel.TextStrokeTransparency = 1
		end
	end
end

-- Subtítulo inferior (dentro de la zona segura, por encima de la franja de abajo).
function Presentation.caption(text: string, options: TextOptions?)
	local opts: TextOptions = options or {}
	if not (Presentation.gui() and safe) then
		return
	end
	captionToken += 1
	local label = safe:FindFirstChild("Caption") :: TextLabel?
	if not label then
		label = textLabel("Caption", safe, UDim2.fromScale(0.5, 0.8), UDim2.fromScale(0.92, 0.05), Color3.new(1, 1, 1))
	end
	if label then
		showText(label, T(text, opts.args), opts.seconds or CAPTION_SECONDS, captionToken, function()
			return captionToken
		end)
	end
end

-- Fundido a negro (toBlack = true, por defecto) o de vuelta a la imagen (false). "instant" sin animar.
function Presentation.fade(seconds: number, toBlack: boolean?, instant: boolean?)
	if not Presentation.gui() or not fadeFrame then
		return
	end
	local goal = if toBlack == false then 1 else 0
	if instant or seconds <= 0 then
		fadeFrame.BackgroundTransparency = goal
	else
		tween(fadeFrame, seconds, { BackgroundTransparency = goal })
	end
end

-- Quita todo lo que dejó la cinemática (franjas, textos, fundido).
function Presentation.clear()
	titleToken += 1
	captionToken += 1
	if gui then
		gui:Destroy()
	end
	gui, topBar, bottomBar, safe, fadeFrame = nil, nil, nil, nil, nil
end

-- Registra en el Sequencer los eventos letterbox { on? = true, seconds? }, title { text, sub?, args?,
-- subArgs?, seconds? }, caption { text, args?, seconds? } y fade { seconds?, toBlack? }, y limpia al acabar.
function Presentation.install(sequencer: SequencerModule)
	sequencer.registerHandler("letterbox", function(event, ctx)
		Presentation.letterbox(event.on ~= false, event.seconds, ctx.seeking == true)
	end)
	sequencer.registerHandler("title", function(event, ctx)
		if ctx.seeking then
			return -- un cartel que ya pasó no se repite al saltar en el tiempo
		end
		Presentation.title(
			event.text,
			event.sub,
			{ args = event.args, subArgs = event.subArgs, seconds = event.seconds }
		)
	end)
	sequencer.registerHandler("caption", function(event, ctx)
		if ctx.seeking then
			return
		end
		Presentation.caption(event.text, { args = event.args, seconds = event.seconds })
	end)
	sequencer.registerHandler("fade", function(event, ctx)
		Presentation.fade(event.seconds or 1, event.toBlack, ctx.seeking == true)
	end)
	sequencer.addHooks({
		finish = function()
			-- Si la escena acaba en negro, se devuelve la imagen con un fundido en vez de cortarla de golpe.
			local current = gui
			if current and fadeFrame and fadeFrame.BackgroundTransparency < 0.5 then
				Presentation.fade(0.5, false)
				task.delay(0.55, function()
					if gui == current then -- si empezó otra escena entretanto, no se toca su pantalla
						Presentation.clear()
					end
				end)
			else
				Presentation.clear()
			end
		end,
	})
end

return Presentation
