--!strict
-- Estilo cómic para las cinemáticas (Fase 25, G2b): viñetas, bocadillos y onomatopeyas sobre el ScreenGui
-- "Cinematic" de Presentation. Solo lo usan las escenas variante «cómic» (el juego normal sigue con las
-- franjas negras). Sin imágenes subidas: todo son GuiObjects. Sin dependencias de Remotes ni Settings, así
-- que corre en modo edición. Comic.install(Sequencer) registra los eventos:
--
--   panel  { shape = <id de Comic.PRESETS> | { {x,y}, … }, border = { color?, width? } | false, bg = { style =
--            "flat" | "halftone" | "speed", colors = { c1, c2 }, focus = {x,y}? }, seconds? }
--          El 3D se ve por una ventana poligonal convexa (3 a 6 vértices, coordenadas 0–1 de la pantalla, en el
--          sentido de las agujas del reloj) y fuera se dibuja el fondo. Solo hay UNA ventana viva: cambiar de plano
--          es cambiar su forma (con "seconds" se interpola). Las escenas cómic no incluyen el evento letterbox.
--   bubble { balloon = "speech" | "thought" | "narration" | "title" (como narration con sub, subArgs) (no se llama kind: ese ya es el tipo del evento),
--            text, args?, actor = "boss" | <nombre en ctx.actors>?,
--            point = {x,y}?, side = "auto" | "left" | "right" | "up" | "down"?, corner = "TL" | "TR" | "BL" | "BR"
--            (solo narration), seconds? }
--   sfx    { text, args?, pos = {x,y}, rot = grados?, size = 0..1 (alto relativo al lado corto), color?, seconds?,
--            bandMax = fracción del ancho de la banda que no pasa en modo reel (0,45) }
--
--   reel   { on = true }  modo REEL: pensado para grabar en Studio y recortar a 9:16 (ver Comic.reelBand). Dibuja
--          fuera de la banda central 9:16 un relleno liso del color del fondo, con una línea fina justo fuera de
--          su borde, y todo lo demás se calcula DENTRO de la banda: las viñetas (coordenadas 0–1 relativas a la
--          banda: x de su borde izquierdo a su borde derecho, y de la pantalla), la posición de `point`, `at` (solo
--          narration y title) y `pos` de sfx, y los textos (que se parten en líneas para no salir de ella). Los
--          bocadillos y carteles quedan además dentro de la zona segura de TikTok e Instagram: ni el 12 % de
--          arriba ni el 22 % de abajo. Va como primer evento de la escena. `bubble` admite `verbatim = true`
--          (el texto no se traduce: un nombre propio).
--
-- Todo se mide con el lado corto de la pantalla (igual en 1920×1080 que en un teléfono). Al saltar en el tiempo
-- (ctx.seeking) el panel se aplica al momento; bubble y sfx no se repiten. Al empezar y al acabar la escena se
-- borra todo.

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Presentation = require(script.Parent.Presentation)
local Strings = require(script.Parent.Parent.Strings)

local T = Strings.t

local Comic = {}

-- Ventanas predefinidas (esquinas TL, TR, BR, BL; el triángulo, ápice arriba). En los principales cabe el tercio
-- central 9:16 (x de 0,34 a 0,66) de una pantalla 16:9, el recorte de los Shorts.
Comic.PRESETS = {
	full = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } },
	wide = { { 0.03, 0.05 }, { 0.97, 0.05 }, { 0.97, 0.95 }, { 0.03, 0.95 } },
	diagLeft = { { 0.1, 0.05 }, { 0.98, 0.03 }, { 0.9, 0.95 }, { 0.02, 0.97 } },
	diagRight = { { 0.02, 0.03 }, { 0.9, 0.05 }, { 0.98, 0.97 }, { 0.1, 0.95 } },
	tallSlant = { { 0.3, 0.04 }, { 0.78, 0.04 }, { 0.7, 0.96 }, { 0.22, 0.96 } },
	tri = { { 0.5, 0.03 }, { 0.98, 0.96 }, { 0.02, 0.96 } },
	-- Ventanas altas del modo reel (evento `reel`): sus coordenadas son relativas a la banda 9:16, no a la
	-- pantalla (0 = borde izquierdo de la banda, 1 = el derecho; y sí es el alto de la pantalla). Con el modo reel
	-- activo, `full` se sustituye por reelFull (la banda entera con margen). Todas son convexas.
	reelFull = { { 0.03, 0.02 }, { 0.97, 0.02 }, { 0.97, 0.98 }, { 0.03, 0.98 } },
	reelTall = { { 0.05, 0.03 }, { 0.95, 0.03 }, { 0.95, 0.97 }, { 0.05, 0.97 } },
	reelTop = { { 0.04, 0.02 }, { 0.96, 0.02 }, { 0.96, 0.6 }, { 0.04, 0.6 } }, -- 60 % de arriba (centro y = 0,31)
	reelBottom = { { 0.04, 0.4 }, { 0.96, 0.4 }, { 0.96, 0.98 }, { 0.04, 0.98 } }, -- 60 % de abajo (centro y = 0,69)
	reelSlant = { { 0.25, 0.02 }, { 0.97, 0.02 }, { 0.75, 0.98 }, { 0.03, 0.98 } }, -- paralelogramo alto inclinado
	reelDiagL = { { 0.03, 0.12 }, { 0.97, 0.02 }, { 0.97, 0.88 }, { 0.03, 0.98 } }, -- sube hacia la derecha
	reelDiagR = { { 0.03, 0.02 }, { 0.97, 0.12 }, { 0.97, 0.98 }, { 0.03, 0.88 } }, -- baja hacia la derecha
} :: { [string]: { { number } } }

-- Banda 9:16 del reel y su zona segura (los porcentajes de las interfaces de TikTok e Instagram).
local REEL_ASPECT = 9 / 16
local REEL_SAFE_TOP = 0.12
local REEL_SAFE_BOTTOM = 0.22

export type Background = {
	style: string, -- "flat" | "halftone" | "speed"
	colors: { Color3 },
	focus: Vector2?,
}

type BorderSpec = { color: Color3, width: number }

type Edge = { a: Vector2, b: Vector2, dir: Vector2, normal: Vector2, length: number }

type Transition = { from: { Vector2 }, to: { Vector2 }, final: { Vector2 }, start: number, seconds: number }

-- Algo vivo en la capa de bocadillos (bocadillo, recuadro u onomatopeya): se actualiza cada cuadro.
type Live = {
	root: Frame,
	update: () -> (),
	dead: boolean,
	box: { center: Vector2, w: number, h: number }?, -- recuadros fijos (narración, título): los globos los esquivan
}

local LAYER_NAME = "ComicLayer"
local BUBBLES_NAME = "ComicBubbles"
local REFERENCE_SHORT = 1080 -- lado corto con el que están pensados los px de los datos
local FONT = Enum.Font.Bangers
local INK = Color3.new(0, 0, 0)
local PAPER = Color3.new(1, 1, 1)
local YELLOW = Color3.fromRGB(255, 222, 89)
local YELLOW_LIGHT = Color3.fromRGB(255, 244, 168)
local MAX_DOTS = 600
local SPEED_LINES = 48
local SFX_SCALE = 0.55 -- la onomatopeya mide este tanto de lo que dice size (así no tapa al jefe)
local DEFAULT_BORDER_WIDTH = 7
local DEFAULT_SECONDS = 3
local POP_SECONDS = 0.28
local FADE_SECONDS = 0.25
local HEAD_DROP = 0.15 -- el punto de la cabeza del jefe: este tanto (de su alto) por debajo de lo más alto
local DEFAULT_BACKGROUND: Background = {
	style = "flat",
	colors = { Color3.fromRGB(34, 38, 60), Color3.fromRGB(12, 14, 26) },
}

-- Estado (una sola escena a la vez).
local layer: Frame? = nil
local bubbleLayer: Frame? = nil
local edgeFrames: { Frame } = {}
local inkFrames: { Frame } = {}
local paperFrames: { Frame } = {}
local decor: CanvasGroup? = nil
local reelMode = false -- modo reel: viñetas y textos dentro de la banda 9:16
local sideFrames: { Frame } = {} -- relleno de fuera de la banda y sus dos líneas (solo en modo reel)
local poly: { Vector2 } = {} -- ventana actual, normalizada (interpolada si hay transición)
local background: Background = DEFAULT_BACKGROUND
local borderSpec: BorderSpec? = nil
local transition: Transition? = nil
local live: { Live } = {}
local connections: { RBXScriptConnection } = {}
local loopConnection: RBXScriptConnection? = nil -- el bucle de cada cuadro (aparte: connections lleva también otras)
local decorToken = 0
local generation = 0 -- sube al limpiar: los task.delay de una escena anterior no tocan la nueva

-- Ventana en píxeles, recalculada una vez por cuadro (refreshWindow).
local win = {
	edges = {} :: { Edge },
	min = Vector2.zero,
	max = Vector2.one,
	center = Vector2.zero,
	size = Vector2.one,
}

-- Geometría ----------------------------------------------------------------------------------------------

local function edgesOf(points: { Vector2 }): { Edge }
	local out: { Edge } = {}
	for i, a in points do
		local b = points[i % #points + 1]
		local delta = b - a
		local length = delta.Magnitude
		local dir = if length > 1e-4 then delta / length else Vector2.zero
		-- Normal hacia fuera: con los vértices en el sentido de las agujas del reloj (y hacia abajo) el
		-- interior queda a la derecha de la arista.
		table.insert(out, { a = a, b = b, dir = dir, normal = Vector2.new(dir.Y, -dir.X), length = length })
	end
	return out
end

-- Distancia (con signo) de un punto a la ventana: positiva fuera, negativa dentro. Exacta si lo más cercano es
-- una arista; si es un vértice se queda corta, lo que solo acerca un poco los puntos de trama al borde.
local function outsideDistance(edges: { Edge }, p: Vector2): number
	local best = -math.huge
	for _, e in edges do
		if e.length > 0 then
			best = math.max(best, (p - e.a):Dot(e.normal))
		end
	end
	return best
end

-- Ordena los vértices en el sentido de las agujas del reloj (y hacia abajo).
local function orient(points: { Vector2 }): { Vector2 }
	local area = 0
	for i, a in points do
		local b = points[i % #points + 1]
		area += a.X * b.Y - b.X * a.Y
	end
	if area >= 0 then
		return points
	end
	local out: { Vector2 } = {}
	for i = #points, 1, -1 do
		table.insert(out, points[i])
	end
	return out
end

-- Añade vértices (puntos medios de la arista más larga) hasta llegar a "count", para poder interpolar.
local function subdivide(points: { Vector2 }, count: number): { Vector2 }
	local out = table.clone(points)
	while #out < count do
		local best, bestLength = 1, -1
		for i, a in out do
			local length = (out[i % #out + 1] - a).Magnitude
			if length > bestLength then
				best, bestLength = i, length
			end
		end
		table.insert(out, best + 1, (out[best] + out[best % #out + 1]) / 2)
	end
	return out
end

local function toVectors(shape: { any }): { Vector2 }?
	if #shape < 3 or #shape > 6 then
		return nil
	end
	local out: { Vector2 } = {}
	for _, p in shape do
		local x = if typeof(p) == "table" then (p[1] or p.x) else nil
		local y = if typeof(p) == "table" then (p[2] or p.y) else nil
		if typeof(x) ~= "number" or typeof(y) ~= "number" then
			return nil
		end
		table.insert(out, Vector2.new(x, y))
	end
	return orient(out)
end

-- La forma de un evento panel: id de preset o lista de vértices. Devuelve también si es la pantalla completa.
local function resolveShape(shape: any): ({ Vector2 }, boolean)
	if typeof(shape) == "string" then
		-- En modo reel la pantalla completa es la banda entera con margen.
		if reelMode and shape == "full" then
			local points = toVectors(Comic.PRESETS.reelFull)
			return points :: { Vector2 }, true
		end
		local preset = Comic.PRESETS[shape]
		local points = if preset then toVectors(preset) else nil
		if points then
			return points, shape == "full"
		end
		warn(`Comic: preset de viñeta desconocido ({shape}); se usa wide`)
		return toVectors(Comic.PRESETS.wide) :: { Vector2 }, false
	elseif typeof(shape) == "table" then
		local points = toVectors(shape)
		if points then
			return points, false
		end
		warn("Comic: una viñeta necesita de 3 a 6 vértices {x, y}; se usa la pantalla completa")
	end
	return toVectors(Comic.PRESETS.full) :: { Vector2 }, true
end

-- Pantalla y ventana ---------------------------------------------------------------------------------------

local function screenSize(): Vector2
	local holder = layer or bubbleLayer
	if holder and holder.AbsoluteSize.X > 0 and holder.AbsoluteSize.Y > 0 then
		return holder.AbsoluteSize
	end
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1920, 1080)
end

-- Factor para pasar los px de los datos (pensados para 1080 de lado corto) a esta pantalla.
local function unitScale(): number
	local size = screenSize()
	return math.min(size.X, size.Y) / REFERENCE_SHORT
end

local function borderPixels(): number
	local spec = borderSpec
	return if spec then spec.width * unitScale() else 0
end

export type ReelBand = {
	width: number, -- ancho de la banda, 0–1 del ancho de la pantalla
	x0: number, -- borde izquierdo, 0–1 de la pantalla
	x1: number, -- borde derecho
	left: number, -- lo mismo en píxeles
	right: number,
	widthPx: number,
	safeTop: number, -- zona segura vertical en píxeles (sin el 12 % de arriba ni el 22 % de abajo)
	safeBottom: number,
}

-- LA función de la banda del reel: todo el modo reel (relleno, viñetas, textos, recorte) sale de aquí. En una
-- pantalla de proporción `viewport` la banda 9:16 centrada mide ancho = (9/16) · alto, o sea el 31,64 % del ancho
-- en 16:9 (x de 0,3418 a 0,6582). Con una pantalla más estrecha que 9:16 la banda es toda la pantalla.
-- Para recortar el vídeo grabado a 1920×1080: x = 656,25 → recorte de 608 × 1080 desde x = 656 (hasta 1264) y
-- escalado a 1080 × 1920; a 1280×720: 405 × 720 desde x = 437,5 (se usa 406 desde x = 437).
local function reelBand(viewport: Vector2): ReelBand
	local width = math.min(1, REEL_ASPECT * viewport.Y / math.max(viewport.X, 1))
	local x0 = (1 - width) / 2
	return {
		width = width,
		x0 = x0,
		x1 = x0 + width,
		left = x0 * viewport.X,
		right = (x0 + width) * viewport.X,
		widthPx = width * viewport.X,
		safeTop = REEL_SAFE_TOP * viewport.Y,
		safeBottom = (1 - REEL_SAFE_BOTTOM) * viewport.Y,
	}
end
Comic.reelBand = reelBand

-- Un punto normalizado a píxeles de la pantalla: en modo reel su x es relativa a la banda.
local function normToPixel(p: Vector2, size: Vector2): Vector2
	if reelMode then
		local band = reelBand(size)
		return Vector2.new(band.left + p.X * band.widthPx, p.Y * size.Y)
	end
	return Vector2.new(p.X * size.X, p.Y * size.Y)
end

local function pixelPoints(points: { Vector2 }, size: Vector2): { Vector2 }
	local out: { Vector2 } = {}
	for i, v in points do
		out[i] = normToPixel(v, size)
	end
	return out
end

local function refreshWindow()
	local size = screenSize()
	local points = pixelPoints(poly, size)
	if #points < 3 then
		points = { Vector2.zero, Vector2.new(size.X, 0), size, Vector2.new(0, size.Y) }
	end
	local lo = Vector2.new(math.huge, math.huge)
	local hi = Vector2.new(-math.huge, -math.huge)
	local sum = Vector2.zero
	for _, p in points do
		lo = Vector2.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y))
		hi = Vector2.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y))
		sum += p
	end
	win.edges = edgesOf(points)
	win.min, win.max, win.center, win.size = lo, hi, sum / #points, size
end

local function rectInside(center: Vector2, w: number, h: number, margin: number): boolean
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			local corner = center + Vector2.new(sx * w / 2, sy * h / 2)
			if outsideDistance(win.edges, corner) > -margin then
				return false
			end
		end
	end
	return true
end

local function clampRange(value: number, lo: number, hi: number): number
	if lo > hi then
		return (lo + hi) / 2
	end
	return math.clamp(value, lo, hi)
end

-- Deja un rectángulo dentro de la ventana: primero dentro de su caja y, si una esquina sigue fuera del polígono
-- (diagonales), lo acerca al centro poco a poco.
local function fitRect(center: Vector2, w: number, h: number, margin: number): Vector2
	-- En modo reel la caja de la ventana se recorta además a la zona segura vertical.
	local lo, hi = win.min, win.max
	if reelMode then
		local band = reelBand(win.size)
		lo = Vector2.new(math.max(lo.X, band.left), math.max(lo.Y, band.safeTop))
		hi = Vector2.new(math.min(hi.X, band.right), math.min(hi.Y, band.safeBottom))
	end
	local x = clampRange(center.X, lo.X + margin + w / 2, hi.X - margin - w / 2)
	local y = clampRange(center.Y, lo.Y + margin + h / 2, hi.Y - margin - h / 2)
	local pos = Vector2.new(x, y)
	for _ = 1, 24 do
		if rectInside(pos, w, h, margin) then
			break
		end
		pos = pos:Lerp(win.center, 0.08)
	end
	return pos
end

-- Capas -------------------------------------------------------------------------------------------------

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(object, info, goal):Play()
end

local function styleEdge(frame: Frame)
	local flat = background.style == "flat"
	local first, second = background.colors[1], background.colors[2]
	frame.BackgroundColor3 = if flat then PAPER else first
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Enabled = flat
		gradient.Color =
			ColorSequence.new({ ColorSequenceKeypoint.new(0, second), ColorSequenceKeypoint.new(1, first) })
	end
end

local function makeFrame(name: string, parent: Instance, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	frame.Parent = parent
	return frame
end

-- Mantiene exactamente "count" marcos en la lista.
local function ensureFrames(list: { Frame }, count: number, make: () -> Frame)
	while #list < count do
		table.insert(list, make())
	end
	while #list > count do
		local frame = table.remove(list)
		if frame then
			frame:Destroy()
		end
	end
end

-- Modo reel: relleno liso del color del fondo fuera de la banda (lo que se recorta) y una línea fina justo fuera de
-- cada borde de la banda, para ver en Studio el encuadre exacto. Son 4 marcos: lado izquierdo, lado derecho y las
-- dos líneas. Fuera del modo reel no existe ninguno.
local function layoutBand(current: Frame, size: Vector2)
	ensureFrames(sideFrames, if reelMode then 4 else 0, function()
		return makeFrame("ReelSide", current, 3)
	end)
	if not reelMode then
		return
	end
	local band = reelBand(size)
	local fill = background.colors[1]
	local lineWidth = math.max(2, 3 * unitScale())
	-- Posición y tamaño de cada marco: [1] y [2] los lados, [3] y [4] las líneas (justo fuera de la banda).
	local specs = {
		{ x = band.left / 2, w = band.left, color = fill, transparency = 0 },
		{ x = (band.right + size.X) / 2, w = size.X - band.right, color = fill, transparency = 0 },
		{ x = band.left - lineWidth / 2, w = lineWidth, color = PAPER, transparency = 0.45 },
		{ x = band.right + lineWidth / 2, w = lineWidth, color = PAPER, transparency = 0.45 },
	}
	for i, spec in specs do
		local frame = sideFrames[i]
		frame.Size = UDim2.fromOffset(math.max(spec.w, 0), size.Y)
		frame.Position = UDim2.fromOffset(spec.x, size.Y / 2)
		frame.BackgroundColor3 = spec.color
		frame.BackgroundTransparency = spec.transparency
		frame.ZIndex = if i <= 2 then 3 else 4
	end
end

-- Coloca los rectángulos del fondo (uno por arista, cubriendo el semiplano de fuera) y el borde.
local function layoutShapes()
	local current = layer
	if not current then
		return
	end
	local size = screenSize()
	layoutBand(current, size)
	local edges = edgesOf(pixelPoints(poly, size))
	local diag = size.Magnitude

	ensureFrames(edgeFrames, #edges, function()
		local frame = makeFrame("Edge", current, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Parent = frame
		styleEdge(frame)
		return frame
	end)
	local k = unitScale()
	local spec = borderSpec
	local count = if spec then #edges else 0
	ensureFrames(inkFrames, count, function()
		return makeFrame("BorderInk", current, 3)
	end)
	ensureFrames(paperFrames, count, function()
		return makeFrame("BorderPaper", current, 4)
	end)

	for i, e in edges do
		local frame = edgeFrames[i]
		local visible = e.length >= 0.5
		frame.Visible = visible
		local rotation = math.deg(math.atan2(e.dir.Y, e.dir.X))
		if visible then
			local h, w = diag * 1.2, diag * 3
			local center = (e.a + e.b) / 2 + e.normal * (h / 2)
			frame.Size = UDim2.fromOffset(w, h)
			frame.Position = UDim2.fromOffset(center.X, center.Y)
			frame.Rotation = rotation
		end
		if spec then
			local ink, paper = inkFrames[i], paperFrames[i]
			ink.Visible, paper.Visible = visible, visible
			if visible then
				local width = spec.width * k
				local outline = math.max(1.5, 2.5 * k)
				local mid = (e.a + e.b) / 2 + e.normal * (width / 2)
				local reach = width * 0.75
				ink.Size = UDim2.fromOffset(e.length + 2 * reach + 2 * outline, width + 2 * outline)
				ink.Position = UDim2.fromOffset(mid.X, mid.Y)
				ink.Rotation = rotation
				ink.BackgroundColor3 = INK
				paper.Size = UDim2.fromOffset(e.length + 2 * reach, width)
				paper.Position = UDim2.fromOffset(mid.X, mid.Y)
				paper.Rotation = rotation
				paper.BackgroundColor3 = spec.color
			end
		end
	end
end

local function buildDots(parent: Instance, edges: { Edge }, size: Vector2)
	local short = math.min(size.X, size.Y)
	-- En modo reel los puntos solo se reparten por la banda (fuera la tapa el relleno liso).
	local xMin, xMax = 0, size.X
	if reelMode then
		local band = reelBand(size)
		xMin, xMax = band.left, band.right
	end
	local step = math.max(short / 22, math.sqrt((xMax - xMin) * size.Y / (0.8 * 560)))
	local reach = short * 0.55
	local margin = borderPixels() * 0.5 + 4 * unitScale()
	local color = background.colors[2]
	local count = 0
	local row = 0
	local y = 0
	while y <= size.Y + step and count < MAX_DOTS do
		local x = xMin + (if row % 2 == 0 then 0 else step / 2)
		while x <= xMax + step and count < MAX_DOTS do
			local distance = outsideDistance(edges, Vector2.new(x, y))
			if distance > 0 then
				local radius = step * (0.13 + 0.33 * math.clamp(distance / reach, 0, 1))
				if distance >= radius + margin then
					local dot = makeFrame("Dot", parent, 1)
					dot.Size = UDim2.fromOffset(radius * 2, radius * 2)
					dot.Position = UDim2.fromOffset(x, y)
					dot.BackgroundColor3 = color
					local corner = Instance.new("UICorner")
					corner.CornerRadius = UDim.new(1, 0)
					corner.Parent = dot
					count += 1
				end
			end
			x += step
		end
		y += step * 0.8
		row += 1
	end
end

local function buildSpeed(parent: Instance, edges: { Edge }, size: Vector2)
	local k = unitScale()
	local focus = if background.focus then normToPixel(background.focus, size) else win.center
	local margin = borderPixels() * 0.5 + 4 * k
	local rng = Random.new(20261105)
	local transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(1, 0),
	})
	for i = 1, SPEED_LINES do
		local angle = (i - 1 + rng:NextNumber(-0.3, 0.3)) / SPEED_LINES * math.pi * 2
		local dir = Vector2.new(math.cos(angle), math.sin(angle))
		-- Recorte rayo-polígono (Cyrus-Beck): "exit" es donde el rayo sale de la ventana.
		local enter, exit, hit = -math.huge, math.huge, true
		for _, e in edges do
			if e.length > 0 then
				local num = (e.a - focus):Dot(e.normal)
				local denom = dir:Dot(e.normal)
				if math.abs(denom) < 1e-6 then
					if num < 0 then
						hit = false
						break
					end
				elseif denom < 0 then
					enter = math.max(enter, num / denom)
				else
					exit = math.min(exit, num / denom)
				end
			end
		end
		-- Sin salida de la ventana no se dibuja nada. El tramo útil va de ahí (más el margen) al borde de la pantalla.
		local rayToScreen = math.huge
		if dir.X > 1e-6 then
			rayToScreen = math.min(rayToScreen, (size.X - focus.X) / dir.X)
		elseif dir.X < -1e-6 then
			rayToScreen = math.min(rayToScreen, -focus.X / dir.X)
		end
		if dir.Y > 1e-6 then
			rayToScreen = math.min(rayToScreen, (size.Y - focus.Y) / dir.Y)
		elseif dir.Y < -1e-6 then
			rayToScreen = math.min(rayToScreen, -focus.Y / dir.Y)
		end
		local from = exit + margin
		local span = rayToScreen - from
		local fraction = rng:NextNumber(0.25, 0.6) -- se saca siempre, para que la semilla dé lo mismo en cualquier pantalla
		local thin = rng:NextNumber(0, 1) -- idem
		if hit and enter <= exit and exit > 0 and span > 4 * k then
			local length = span * fraction
			-- Alterna dos grosores (3 y 8 px a 1080); se estrecha hacia la ventana con la transparencia.
			local thickness = math.max(1.5, (if i % 2 == 0 then 8 else 3) * k * (0.9 + 0.2 * thin))
			local line = makeFrame("Line", parent, 1)
			-- Centrada (el giro de un Frame es sobre su centro): su centro va a mitad del tramo.
			local middle = focus + dir * (from + length / 2)
			line.Size = UDim2.fromOffset(length, thickness)
			line.Position = UDim2.fromOffset(middle.X, middle.Y)
			line.Rotation = math.deg(angle)
			line.BackgroundColor3 = background.colors[2]
			local gradient = Instance.new("UIGradient")
			gradient.Transparency = transparency
			gradient.Parent = line
		end
	end
end

-- Puntos de trama o líneas de velocidad del fondo (el degradado va en los rectángulos). Con "fade" entran con
-- un fundido corto.
local function rebuildDecor(fade: boolean)
	if decor then
		decor:Destroy()
		decor = nil
	end
	local current = layer
	if not current or (background.style ~= "halftone" and background.style ~= "speed") then
		return
	end
	refreshWindow()
	local group = Instance.new("CanvasGroup")
	group.Name = "Decor"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.BorderSizePixel = 0
	group.ZIndex = 2
	group.Parent = current
	local size = screenSize()
	if background.style == "halftone" then
		buildDots(group, win.edges, size)
	else
		buildSpeed(group, win.edges, size)
	end
	decor = group
	if fade then
		group.GroupTransparency = 1
		tween(group, if reelMode then 0.1 else 0.3, { GroupTransparency = 0 })
	end
end

local function fadeOut(root: Instance, seconds: number)
	for _, d in root:GetDescendants() do
		if d:IsA("Frame") then
			tween(d, seconds, { BackgroundTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, seconds, { Transparency = 1 })
		elseif d:IsA("TextLabel") then
			tween(d, seconds, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end
end

-- Un cuadro: avanza la transición de la ventana y actualiza lo que vive en la capa de bocadillos.
local function step()
	local tr = transition
	if tr then
		local alpha = math.clamp((os.clock() - tr.start) / tr.seconds, 0, 1)
		local eased = alpha * alpha * (3 - 2 * alpha)
		local current: { Vector2 } = {}
		for i, from in tr.from do
			current[i] = from:Lerp(tr.to[i], eased)
		end
		poly = current
		if alpha >= 1 then
			transition = nil
			poly = tr.final
			layoutShapes()
			rebuildDecor(true)
		else
			layoutShapes()
		end
	end
	refreshWindow()
	for i = #live, 1, -1 do
		local item = live[i]
		if item.dead or not item.root.Parent then
			table.remove(live, i)
		else
			local ok, err = pcall(item.update)
			if not ok then
				warn(`Comic: falla la actualización de un bocadillo: {err}`)
				item.dead = true
				item.root:Destroy()
			end
		end
	end
end

local function onResize()
	if not layer then
		return
	end
	layoutShapes()
	decorToken += 1
	local token = decorToken
	task.delay(0.15, function()
		if token == decorToken and layer and not transition then
			rebuildDecor(false)
		end
	end)
end

local function ensureLoop()
	if not loopConnection then
		loopConnection = RunService.RenderStepped:Connect(step)
	end
end

-- Borra todo lo del cómic y deja el módulo como nuevo.
local function reset()
	generation += 1
	decorToken += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	connections = {}
	if loopConnection then
		loopConnection:Disconnect()
		loopConnection = nil
	end
	if layer then
		layer:Destroy()
	end
	if bubbleLayer then
		bubbleLayer:Destroy()
	end
	layer, bubbleLayer, decor = nil, nil, nil
	edgeFrames, inkFrames, paperFrames, sideFrames, live = {}, {}, {}, {}, {}
	reelMode = false
	poly = {}
	background = DEFAULT_BACKGROUND
	borderSpec = nil
	transition = nil
end

local function ensureLayer(): boolean
	if layer and layer.Parent then
		return true
	end
	local gui = Presentation.gui()
	if not gui then
		return false
	end
	if layer then
		reset() -- la pantalla de Presentation se recreó: lo viejo ya no cuelga de ella
	end
	local new = Instance.new("Frame")
	new.Name = LAYER_NAME
	new.Size = UDim2.fromScale(1, 1)
	new.BackgroundTransparency = 1
	new.BorderSizePixel = 0
	new.ZIndex = 0 -- por debajo de los textos de Presentation (que están en 1)
	new.Parent = gui
	layer = new
	poly = resolveShape("full")
	table.insert(connections, new:GetPropertyChangedSignal("AbsoluteSize"):Connect(onResize))
	ensureLoop()
	return true
end

local function ensureBubbleLayer(): boolean
	if bubbleLayer and bubbleLayer.Parent then
		return true
	end
	local gui = Presentation.gui()
	if not gui then
		return false
	end
	local old = gui:FindFirstChild(BUBBLES_NAME)
	if old then
		old:Destroy()
	end
	local new = Instance.new("Frame")
	new.Name = BUBBLES_NAME
	new.Size = UDim2.fromScale(1, 1)
	new.BackgroundTransparency = 1
	new.BorderSizePixel = 0
	new.ZIndex = 2 -- encima de los textos de Presentation, debajo del fundido
	new.Parent = gui
	bubbleLayer = new
	ensureLoop()
	return true
end

-- panel ----------------------------------------------------------------------------------------------------

local function parseBackground(raw: any): Background
	if typeof(raw) ~= "table" then
		return background
	end
	local style = if raw.style == "halftone" or raw.style == "speed" then raw.style else "flat"
	local colors = raw.colors
	local first = if typeof(colors) == "table" and typeof(colors[1]) == "Color3"
		then colors[1]
		else DEFAULT_BACKGROUND.colors[1]
	local second = if typeof(colors) == "table" and typeof(colors[2]) == "Color3"
		then colors[2]
		else DEFAULT_BACKGROUND.colors[2]
	local focus: Vector2? = nil
	if typeof(raw.focus) == "table" then
		local x, y = raw.focus[1] or raw.focus.x, raw.focus[2] or raw.focus.y
		if typeof(x) == "number" and typeof(y) == "number" then
			focus = Vector2.new(x, y)
		end
	end
	return { style = style, colors = { first, second }, focus = focus }
end

local function setPanel(event: { [string]: any }, seeking: boolean)
	if not ensureLayer() then
		return
	end
	local target, isFull = resolveShape(event.shape)

	local rawBorder = event.border
	if rawBorder == false or (rawBorder == nil and isFull) then
		borderSpec = nil
	else
		local custom = if typeof(rawBorder) == "table" then rawBorder else {}
		borderSpec = {
			color = if typeof(custom.color) == "Color3" then custom.color else PAPER,
			width = if typeof(custom.width) == "number" then custom.width else DEFAULT_BORDER_WIDTH,
		}
	end
	background = parseBackground(event.bg)
	for _, frame in edgeFrames do
		styleEdge(frame)
	end

	local seconds: number = if seeking then 0 else (event.seconds or 0)
	if seconds > 0 and #poly >= 3 then
		-- Mientras se mueve la ventana solo se actualizan los rectángulos; puntos y líneas vuelven al final.
		if decor then
			decor:Destroy()
			decor = nil
		end
		local count = math.max(#poly, #target)
		local from = subdivide(poly, count)
		local to = subdivide(target, count)
		poly = from
		transition = { from = from, to = to, final = target, start = os.clock(), seconds = seconds }
		layoutShapes()
	else
		transition = nil
		poly = target
		layoutShapes()
		refreshWindow()
		rebuildDecor(not seeking)
	end
end

-- bocadillos ---------------------------------------------------------------------------------------------

local function newRoot(width: number, height: number): Frame
	local root = Instance.new("Frame")
	root.Name = "Bubble"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(width, height)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = bubbleLayer
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root
	return root
end

local function addStroke(parent: Instance, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness
	stroke.Parent = parent
end

local function round(parent: Instance, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

-- Entrada con golpe de escala (Back).
local function popIn(root: Frame)
	local uiScale = root:FindFirstChildOfClass("UIScale")
	if uiScale then
		uiScale.Scale = 0.3
		TweenService
			:Create(uiScale, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
end

-- Registra algo vivo y programa su salida: tras "seconds" se funde y se destruye.
local function addLive(root: Frame, update: () -> (), seconds: number): Live
	local item: Live = { root = root, update = update, dead = false, box = nil }
	table.insert(live, item)
	local mine = generation
	task.delay(seconds, function()
		if mine ~= generation or item.dead then
			return
		end
		fadeOut(root, FADE_SECONDS)
		task.delay(FADE_SECONDS + 0.05, function()
			item.dead = true
			root:Destroy()
		end)
	end)
	return item
end

-- Tamaño del texto con el ancho dado (TextService; si falla, una estimación). El tamaño máximo de fuente es 100.
local function measure(text: string, textSize: number, maxWidth: number): Vector2
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(text, textSize, FONT, Vector2.new(maxWidth, 10000))
	end)
	if ok then
		return bounds
	end
	local total = #text * textSize * 0.5
	local lines = math.max(1, math.ceil(total / maxWidth))
	return Vector2.new(math.min(total, maxWidth), lines * textSize * 1.1)
end

local function textLabel(parent: Instance, text: string, textSize: number, width: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(math.ceil(width) + 8, math.ceil(height) + 4)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = text
	label.TextColor3 = INK
	label.TextSize = textSize
	label.TextWrapped = true
	label.ZIndex = 5
	label.Parent = parent
	return label
end

-- Modelo del actor al que apunta un bocadillo: "boss" es el jefe (atributo Boss) más cercano al anchor; si no, el
-- actor de ctx.actors con ese nombre.
local function findActor(name: any, ctx: { [string]: any }): (Model?, boolean)
	if name == "boss" then
		local cached = ctx._comicBoss
		if typeof(cached) == "Instance" and cached.Parent then
			return cached :: Model, true
		end
		local anchor: CFrame = ctx.anchor or CFrame.identity
		local best: Model? = nil
		local bestDistance = math.huge
		for _, descendant in workspace:GetDescendants() do
			if descendant:IsA("Model") and descendant:GetAttribute("Boss") ~= nil then
				local distance = (descendant:GetPivot().Position - anchor.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = descendant, distance
				end
			end
		end
		ctx._comicBoss = best
		return best, true
	end
	local actors = ctx.actors
	local model = if typeof(name) == "string" and typeof(actors) == "table" then actors[name] else nil
	if typeof(model) == "Instance" and model:IsA("Model") then
		return model, false
	end
	-- Los monos de las batallas los pone el servidor, no scene.actors: AbilityShow deja en ctx una función que los busca.
	local resolver = ctx.resolveActor
	if typeof(resolver) == "function" then
		local found = resolver(name)
		if typeof(found) == "Instance" and found:IsA("Model") then
			return found, false
		end
	end
	return nil, false
end

-- Función que da el punto de la cabeza del actor en el mundo: la Head del maniquí o, en el jefe, un punto cerca de
-- lo más alto de su caja (se guarda relativo a su pivote para no recalcular la caja cada cuadro).
local function headGetter(model: Model, isBoss: boolean): () -> Vector3?
	if not isBoss then
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return function()
				return head.Position
			end
		end
	end
	local cf, boxSize = model:GetBoundingBox()
	-- Solo se guarda el desplazamiento en ejes del mundo: si la animación inclina o gira el pivote (el rugido),
	-- girar con él un punto a una altura de cuerpo entero lo mandaría lejos de la cabeza.
	local offset = cf.Position + Vector3.new(0, boxSize.Y * (0.5 - HEAD_DROP), 0) - model:GetPivot().Position
	return function()
		if not model.Parent then
			return nil
		end
		return model:GetPivot().Position + offset
	end
end

local function project(world: Vector3): Vector2?
	local camera = workspace.CurrentCamera
	local holder = bubbleLayer
	if not (camera and holder) then
		return nil
	end
	local view = camera:WorldToViewportPoint(world)
	if view.Z <= 0 then
		return nil
	end
	return Vector2.new(view.X, view.Y) - holder.AbsolutePosition
end

local function pointOf(raw: any): Vector2?
	if typeof(raw) == "table" then
		local x, y = raw[1] or raw.x, raw[2] or raw.y
		if typeof(x) == "number" and typeof(y) == "number" then
			return Vector2.new(x, y)
		end
	end
	return nil
end

local function pointAt(event: { [string]: any }, ctx: { [string]: any }): () -> Vector2?
	local getter: (() -> Vector3?)? = nil
	if event.actor ~= nil then
		local model, isBoss = findActor(event.actor, ctx)
		if model then
			getter = headGetter(model, isBoss)
		end
	end
	local fixed = pointOf(event.point)
	return function()
		if getter then
			local world = getter()
			return if world then project(world) else nil
		end
		return if fixed then normToPixel(fixed, win.size) else nil
	end
end

-- Globo de diálogo (speech) o de pensamiento (thought) que sigue a un actor.
local function buildBalloon(event: { [string]: any }, ctx: { [string]: any }, thought: boolean)
	if not ensureBubbleLayer() then
		return
	end
	refreshWindow()
	local short = math.min(win.size.X, win.size.Y)
	local k = short / REFERENCE_SHORT
	local text = T(event.text, event.args)
	local textSize = math.clamp(math.floor(short * 0.05), 14, 100)
	local windowWidth = win.max.X - win.min.X
	local maxWidth = math.min(short * 0.62, windowWidth * 0.8)
	if reelMode then
		maxWidth = reelBand(win.size).widthPx * 0.62 -- el texto largo se parte en líneas, no se sale de la banda
	end
	local bounds = measure(text, textSize, maxWidth)
	local pad = textSize * 0.5
	local bw = if thought then bounds.X * 1.28 + 2 * pad else bounds.X * 1.05 + 2 * pad
	local bh = if thought then bounds.Y * 1.4 + 2 * pad else bounds.Y + 2 * pad
	local root = newRoot(bw, bh)
	local thickness = math.max(2, 3 * k)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = PAPER
	body.BorderSizePixel = 0
	body.ZIndex = 2
	body.Parent = root
	round(body, if thought then UDim.new(1, 0) else UDim.new(0, math.min(bw, bh) * 0.38))
	addStroke(body, thickness)
	textLabel(root, text, textSize, bounds.X * 1.02, bounds.Y)

	local tail: Frame? = nil
	local patch: Frame? = nil
	local bubbles: { Frame } = {}
	if thought then
		for i = 1, 3 do
			local dot = makeFrame("Thought", root, 1)
			dot.BackgroundColor3 = PAPER
			round(dot, UDim.new(1, 0))
			addStroke(dot, thickness)
			bubbles[i] = dot
		end
	else
		tail = makeFrame("Tail", root, 1)
		tail.BackgroundColor3 = PAPER
		addStroke(tail, thickness)
		patch = makeFrame("TailPatch", root, 3)
		patch.BackgroundColor3 = PAPER
	end

	local getPoint = pointAt(event, ctx)
	local side: string = event.side or "auto"
	local sign: number? = nil
	local margin = borderPixels() + 10 * k
	local tailMin, tailMax = short * 0.035, short * 0.065
	local sizes = { 0.3, 0.21, 0.14 }
	local fractions = { 0.2, 0.5, 0.8 }

	local function update()
		local target = getPoint()
		local center = win.center
		if target then
			sign = sign or (if target.X > win.center.X then -1 else 1)
			local gap = tailMax + short * 0.02
			if side == "left" then
				center = target + Vector2.new(-(bw / 2 + gap), 0)
			elseif side == "right" then
				center = target + Vector2.new(bw / 2 + gap, 0)
			elseif side == "down" then
				center = target + Vector2.new(0, bh / 2 + gap)
			else
				center = target + Vector2.new(sign * bw * 0.28, -(bh / 2 + gap))
			end
		end
		center = fitRect(center, bw, bh, margin)
		-- Sube hasta no pisar los recuadros de narración o título que estén a la vista.
		for _, other in live do
			local box = other.box
			if box and not other.dead and other.root ~= root then
				local overlapX = math.abs(center.X - box.center.X) < (bw + box.w) / 2
				local overlapY = math.abs(center.Y - box.center.Y) < (bh + box.h) / 2
				if overlapX and overlapY then
					local up = Vector2.new(center.X, box.center.Y - box.h / 2 - bh / 2 - 4 * k)
					center = fitRect(up, bw, bh, margin)
				end
			end
		end
		root.Position = UDim2.fromOffset(center.X, center.Y)

		if tail and patch then
			tail.Visible = target ~= nil
			patch.Visible = target ~= nil
		end
		for _, dot in bubbles do
			dot.Visible = target ~= nil
		end
		if not target then
			return
		end
		local delta = target - center
		if tail and patch then
			-- Lado del cuerpo que mira al objetivo (eje dominante) y punto de unión desplazado hacia él.
			local useX = math.abs(delta.X) / bw > math.abs(delta.Y) / bh
			local nx = if useX then (if delta.X >= 0 then 1 else -1) else 0
			local ny = if useX then 0 else (if delta.Y >= 0 then 1 else -1)
			local ax = if useX then bw / 2 + nx * bw / 2 else bw / 2 + math.clamp(delta.X * 0.5, -0.28 * bw, 0.28 * bw)
			local ay = if useX then bh / 2 + math.clamp(delta.Y * 0.5, -0.28 * bh, 0.28 * bh) else bh / 2 + ny * bh / 2
			local world = center + Vector2.new(ax - bw / 2, ay - bh / 2)
			local toTarget = target - world
			local length = math.clamp(toTarget.Magnitude, tailMin, tailMax)
			local normalAngle = math.deg(math.atan2(ny, nx))
			local tilt = (math.deg(math.atan2(toTarget.Y, toTarget.X)) - normalAngle + 180) % 360 - 180
			local angle = normalAngle + math.clamp(tilt, -35, 35)
			-- Un cuadrado girado: su esquina señala "angle" cuando Rotation = angle - 45.
			local side2 = length * math.sqrt(2)
			for _, part in { tail, patch } do
				part.Size = UDim2.fromOffset(side2, side2)
				part.Position = UDim2.fromOffset(ax, ay)
				part.Rotation = angle - 45
			end
		else
			local toTarget = target - center
			local direction = if toTarget.Magnitude > 1 then toTarget.Unit else Vector2.new(0, 1)
			-- Radio de la elipse en esa dirección: dónde empiezan los circulitos.
			local rx, ry = bw / 2, bh / 2
			local edge = 1 / math.sqrt((direction.X / rx) ^ 2 + (direction.Y / ry) ^ 2)
			local span = math.max(toTarget.Magnitude - edge, short * 0.09)
			for i, dot in bubbles do
				local d = bh * sizes[i] * 0.55 + 4 * k
				local at = Vector2.new(bw / 2, bh / 2) + direction * (edge + span * fractions[i])
				dot.Size = UDim2.fromOffset(d, d)
				dot.Position = UDim2.fromOffset(at.X, at.Y)
			end
		end
	end
	update()
	popIn(root)
	addLive(root, update, event.seconds or DEFAULT_SECONDS)
end

-- Recuadro de narración (o de título, con balloon = "title": nombre y subtítulo debajo), pegado a una esquina de
-- la ventana.
local function buildNarration(event: { [string]: any })
	if not ensureBubbleLayer() then
		return
	end
	refreshWindow()
	local short = math.min(win.size.X, win.size.Y)
	local k = short / REFERENCE_SHORT
	local isTitle = event.balloon == "title"
	local text = if event.verbatim then tostring(event.text) else T(event.text, event.args)
	local textSize = math.clamp(math.floor(short * (if isTitle then 0.06 else 0.036)), 12, 100)
	local maxWidth = math.min(short * (if isTitle then 0.8 else 0.5), (win.max.X - win.min.X) * 0.45)
	if reelMode then
		-- Más grande y más ancho (la banda es estrecha): el texto se parte en líneas dentro de ella.
		textSize = math.clamp(math.floor(short * (if isTitle then 0.075 else 0.04)), 12, 100)
		maxWidth = reelBand(win.size).widthPx * (if isTitle then 0.8 else 0.7)
	end
	local bounds = measure(text, textSize, maxWidth)
	local pad = textSize * 0.45
	local padV = if isTitle then math.max(pad, bounds.Y * 0.45) else pad -- el título pide más aire arriba y abajo
	local subText, subSize, subBounds, gap = nil, 0, Vector2.zero, 0
	if isTitle and typeof(event.sub) == "string" and event.sub ~= "" then
		subText = T(event.sub, event.subArgs)
		subSize = math.clamp(math.floor(short * 0.032), 10, 100)
		subBounds = measure(subText, subSize, maxWidth)
		gap = subSize * 0.35
	end
	local bw = math.max(bounds.X, subBounds.X) * 1.04 + 2 * pad
	local bh = bounds.Y + (if subText then subBounds.Y + gap else 0) + 2 * padV
	local root = newRoot(bw, bh)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = YELLOW
	body.BorderSizePixel = 0
	body.ZIndex = 2
	body.Parent = root
	addStroke(body, math.max(2, 3 * k))
	local main = textLabel(root, text, textSize, math.max(bounds.X, subBounds.X) * 1.02, bounds.Y)
	if subText then
		main.Position = UDim2.new(0.5, 0, 0, padV + bounds.Y / 2)
		local sub = textLabel(root, subText, subSize, math.max(bounds.X, subBounds.X) * 1.02, subBounds.Y)
		sub.Position = UDim2.new(0.5, 0, 0, padV + bounds.Y + gap + subBounds.Y / 2)
	end

	local corner: string = event.corner or "TL"
	local top = string.sub(corner, 1, 1) ~= "B"
	local left = string.sub(corner, 2, 2) ~= "R"
	local margin = borderPixels() + 12 * k
	local item: Live? = nil
	local at = pointOf(event.at) -- centro fijo (en modo reel, relativo a la banda); sin él, pegado a la esquina
	local function update()
		local x = if left then win.min.X + margin + bw / 2 else win.max.X - margin - bw / 2
		local y = if top then win.min.Y + margin + bh / 2 else win.max.Y - margin - bh / 2
		local wanted = if at then normToPixel(at, win.size) else Vector2.new(x, y)
		local center = fitRect(wanted, bw, bh, margin)
		root.Position = UDim2.fromOffset(center.X, center.Y)
		if item then
			item.box = { center = center, w = bw, h = bh }
		end
	end
	update()
	popIn(root)
	item = addLive(root, update, event.seconds or DEFAULT_SECONDS)
end

-- "kind" ya es el tipo del evento (bubble), así que la clase del bocadillo va en "balloon".
local function addBubble(event: { [string]: any }, ctx: { [string]: any })
	local kind = event.balloon or "speech"
	if kind == "narration" or kind == "title" then
		buildNarration(event)
	else
		buildBalloon(event, ctx, kind == "thought")
	end
end

-- Onomatopeya: texto grande con contorno, sobre una «explosión» de cuadrados amarillos girados.
local function buildSfx(event: { [string]: any })
	if not ensureBubbleLayer() then
		return
	end
	refreshWindow()
	local size = win.size
	local short = math.min(size.X, size.Y)
	local height = math.clamp(tonumber(event.size) or 0.2, 0.02, 0.8) * short * SFX_SCALE
	local text = T(event.text, event.args)
	local measureSize = math.min(height, 100)
	local bounds = measure(text, measureSize, size.X * 2)
	local width = bounds.X * height / measureSize + 8
	if reelMode then
		-- Onomatopeya pequeña: su ancho no pasa de `bandMax` de la banda (0,45 por defecto); si es más ancha se encoge.
		local limit = reelBand(size).widthPx * (tonumber(event.bandMax) or 0.45)
		if width > limit then
			height *= limit / width
			width = limit
		end
	end
	local root = newRoot(width, height)
	local outline = math.max(3, height * 0.05)

	local rng = Random.new(#text * 31 + 7)
	local count = math.max(1, math.round(width / (height * 1.5)))
	local bursts: { { cx: number, cy: number, side: number, rot: number } } = {}
	for i = 1, count do
		table.insert(bursts, {
			cx = width * ((i - 0.5) / count),
			cy = height / 2 + rng:NextNumber(-0.08, 0.08) * height,
			side = height * rng:NextNumber(1.45, 1.8),
			rot = rng:NextNumber(-10, 10),
		})
	end
	local function square(
		b: { cx: number, cy: number, side: number, rot: number },
		scale: number,
		extra: number,
		turn: number,
		color: Color3,
		z: number
	)
		local frame = makeFrame("Burst", root, z)
		local s = b.side * scale + extra
		frame.Size = UDim2.fromOffset(s, s)
		frame.Position = UDim2.fromOffset(b.cx, b.cy)
		frame.Rotation = b.rot + turn
		frame.BackgroundColor3 = color
	end
	-- Primero todos los contornos y luego los rellenos: así los cuadrados que se solapan no dejan líneas dentro.
	for _, b in bursts do
		square(b, 1, 2 * outline, 0, INK, 1)
		square(b, 0.92, 2 * outline, 45, INK, 1)
	end
	for _, b in bursts do
		square(b, 1, 0, 0, YELLOW, 2)
		square(b, 0.92, 0, 45, YELLOW_LIGHT, 2)
	end

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(width, height)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = if typeof(event.color) == "Color3" then event.color else PAPER
	label.TextStrokeColor3 = INK
	label.TextStrokeTransparency = 0
	label.ZIndex = 5
	label.Parent = root
	addStroke(label, math.max(2, height * 0.07))

	local uiScale = root:FindFirstChildOfClass("UIScale")
	local pos = pointOf(event.pos) or Vector2.new(0.5, 0.5)
	local baseRotation = tonumber(event.rot) or 0
	local born = os.clock()
	local function update()
		local age = os.clock() - born
		local scale = 1
		if age < 0.1 then
			scale = 0.3 + (1.15 - 0.3) * (age / 0.1)
		elseif age < 0.2 then
			scale = 1.15 - 0.15 * ((age - 0.1) / 0.1)
		end
		if uiScale then
			uiScale.Scale = scale
		end
		local decay = math.exp(-age * 5)
		local shake = short * 0.005 * decay
		root.Rotation = baseRotation + math.sin(age * 70) * 3 * decay
		local at = normToPixel(pos, win.size)
		if reelMode then
			-- Dentro de la banda y de la zona segura vertical, contando la explosión (hasta ~2 veces el alto) y el
			-- golpe de escala de la entrada (×1,15).
			local band = reelBand(win.size)
			local halfX = math.max(width, height * 2) * 1.15 / 2
			local halfY = height * 2 * 1.15 / 2
			at = Vector2.new(
				clampRange(at.X, band.left + halfX, band.right - halfX),
				clampRange(at.Y, band.safeTop + halfY, band.safeBottom - halfY)
			)
		end
		root.Position = UDim2.fromOffset(at.X + math.sin(age * 53) * shake, at.Y + math.cos(age * 61) * shake)
	end
	update()
	addLive(root, update, event.seconds or 1.5)
end

-- Registro -------------------------------------------------------------------------------------------------

function Comic.install(sequencer: Presentation.SequencerModule)
	sequencer.registerHandler("reel", function(event)
		reelMode = event.on ~= false
		-- Si ya hay capa (el panel llegó antes), se recoloca todo con la banda.
		if layer then
			layoutShapes()
			rebuildDecor(false)
		end
	end)
	sequencer.registerHandler("panel", function(event, ctx)
		setPanel(event, ctx.seeking == true)
	end)
	sequencer.registerHandler("bubble", function(event, ctx)
		if ctx.seeking then
			return -- un bocadillo que ya pasó no se repite al saltar en el tiempo
		end
		addBubble(event, ctx)
	end)
	sequencer.registerHandler("sfx", function(event, ctx)
		if ctx.seeking then
			return
		end
		buildSfx(event)
	end)
	sequencer.addHooks({
		start = function()
			reset()
		end,
		finish = function()
			reset()
		end,
	})
end

return Comic
