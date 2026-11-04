--!strict
-- Marcas de las pantallas de ajuste del campo de tiro (Fase 23, World/RangeBuilder). El servidor avisa al
-- tirador de cada disparo contra una pantalla (Remotes.RangeShot: pantalla, dx, dy en studs desde el
-- centro y distancia del tirador); aquí se dibuja cada marca en el Frame "Marks" del SurfaceGui de esa
-- pantalla, la línea naranja del centro al desvío medio de las últimas Config.Range.MarkAverageOver y la
-- lectura de abajo. Las marcas son locales: cada jugador ve solo las suyas. El aviso «Borrar marcas»
-- (BorrarMarcasPrompt, junto a la línea de tiro) las vacía en las dos pantallas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)

local ORANGE = Color3.fromRGB(255, 122, 26)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
-- Lienzo de la pantalla (1920 × 1080 píxeles, World/RangeBuilder), marcas y líneas (píxeles).
local CANVAS_W = 1920
local CANVAS_H = 1080
local DOT_SIZE = 18
local LAST_DOT_SIZE = 26
local LINE_OUTLINE = 9
local LINE_WIDTH = 4
local CLEAR_PROMPT = "BorrarMarcasPrompt"

type Mark = { dx: number, dy: number, dot: Frame }

type Screen = {
	id: string,
	ppu: number, -- píxeles por stud
	marks: Frame,
	readout: TextLabel,
	outline: Frame,
	line: Frame,
	list: { Mark },
	total: number, -- disparos desde el último borrado
	distance: number,
}

local RangeScreenController = {}

local screens: { [string]: Screen } = {}

local function setReadout(screen: Screen)
	local label = screen.readout
	local list = screen.list
	if #list == 0 then
		Strings.setWorldText(label, "Dispara a la cruz central para medir el desvío")
		return
	end
	local count = math.min(#list, Config.Range.MarkAverageOver)
	local sumX, sumY = 0, 0
	for index = #list - count + 1, #list do
		sumX += list[index].dx
		sumY += list[index].dy
	end
	local meanX, meanY = sumX / count, sumY / count
	local variance = 0
	for index = #list - count + 1, #list do
		variance += (list[index].dx - meanX) ^ 2 + (list[index].dy - meanY) ^ 2
	end
	local spread = math.sqrt(variance / count)
	local degrees = math.deg(math.atan(math.sqrt(meanX * meanX + meanY * meanY) / math.max(screen.distance, 1)))

	-- Línea naranja del centro al desvío medio (con borde negro debajo).
	local length = math.sqrt(meanX * meanX + meanY * meanY) * screen.ppu
	local angle = math.deg(math.atan2(-meanY, meanX))
	for _, frame in { screen.outline, screen.line } do
		frame.Size = UDim2.fromOffset(length, if frame == screen.outline then LINE_OUTLINE else LINE_WIDTH)
		frame.Rotation = angle
		frame.Visible = true
	end

	Strings.setWorldText(label, "Δx {dx}  Δy {dy} studs ({degrees}°) · dispersión {spread} · tiros {shots}", {
		dx = string.format("%+.2f", meanX),
		dy = string.format("%+.2f", meanY),
		degrees = string.format("%.1f", degrees),
		spread = string.format("%.2f", spread),
		shots = screen.total,
	})
end

local function dotAppearance(dot: Frame, latest: boolean)
	local size = if latest then LAST_DOT_SIZE else DOT_SIZE
	dot.Size = UDim2.fromOffset(size, size)
	dot.BackgroundColor3 = if latest then ORANGE else WHITE
	dot.ZIndex = if latest then 3 else 2
end

local function newDot(parent: Frame, x: number, y: number): Frame
	local dot = Instance.new("Frame")
	dot.Name = "Marca"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromOffset(x, y)
	dot.BorderSizePixel = 0
	dot.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Color = BLACK
	stroke.Thickness = 3
	stroke.Parent = dot
	return dot
end

local function newLine(parent: Frame, name: string, color: Color3, zIndex: number): Frame
	local line = Instance.new("Frame")
	line.Name = name
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Position = UDim2.fromOffset(CANVAS_W / 2, CANVAS_H / 2)
	line.BackgroundColor3 = color
	line.BorderSizePixel = 0
	line.Size = UDim2.fromOffset(0, LINE_WIDTH)
	line.ZIndex = zIndex
	line.Visible = false
	line.Parent = parent
	return line
end

local function clear(screen: Screen)
	for _, mark in screen.list do
		mark.dot:Destroy()
	end
	table.clear(screen.list)
	screen.total = 0
	screen.outline.Visible = false
	screen.line.Visible = false
	setReadout(screen)
end

local function onShot(id: any, dx: any, dy: any, distance: any)
	local screen = if typeof(id) == "string" then screens[id] else nil
	if not (screen and typeof(dx) == "number" and typeof(dy) == "number" and typeof(distance) == "number") then
		return
	end
	-- Un número raro (NaN, infinito) no se dibuja.
	if dx ~= dx or dy ~= dy or distance ~= distance or math.abs(dx) > 1e4 or math.abs(dy) > 1e4 then
		return
	end
	local list = screen.list
	if #list > 0 then
		dotAppearance(list[#list].dot, false)
	end
	local dot = newDot(screen.marks, CANVAS_W / 2 + dx * screen.ppu, CANVAS_H / 2 - dy * screen.ppu)
	dotAppearance(dot, true)
	table.insert(list, { dx = dx, dy = dy, dot = dot })
	while #list > Config.Range.MarksKept do
		local oldest = table.remove(list, 1)
		if oldest then
			oldest.dot:Destroy()
		end
	end
	screen.total += 1
	screen.distance = distance
	setReadout(screen)
end

-- Prepara una pantalla: sus capas ya vienen del servidor (World/RangeBuilder); aquí se añaden las líneas.
local function setUp(part: Instance)
	local id = part:GetAttribute("RangeScreen")
	local width = part:GetAttribute("ScreenWidth")
	local gui = part:WaitForChild("Pantalla", 10)
	local marks = if gui then gui:WaitForChild("Marks", 10) else nil
	local readout = if gui then gui:WaitForChild("Readout", 10) else nil
	if
		not (
			typeof(id) == "string"
			and typeof(width) == "number"
			and marks
			and marks:IsA("Frame")
			and readout
			and readout:IsA("TextLabel")
		)
	then
		return
	end
	local screen: Screen = {
		id = id,
		ppu = CANVAS_W / width,
		marks = marks,
		readout = readout,
		outline = newLine(marks, "LineaBorde", BLACK, 1),
		line = newLine(marks, "Linea", ORANGE, 2),
		list = {},
		total = 0,
		distance = 30,
	}
	screens[id] = screen
end

function RangeScreenController:Start()
	Remotes.RangeShot.OnClientEvent:Connect(onShot)

	local range = Workspace:WaitForChild("CampoDeTiro")
	local function consider(instance: Instance)
		if instance:IsA("BasePart") and instance:GetAttribute("RangeScreen") ~= nil then
			task.spawn(setUp, instance)
		elseif instance:IsA("ProximityPrompt") and instance.Name == CLEAR_PROMPT then
			instance.Triggered:Connect(function()
				for _, screen in screens do
					clear(screen)
				end
			end)
		end
	end
	for _, instance in range:GetDescendants() do
		consider(instance)
	end
	range.DescendantAdded:Connect(consider)
end

return RangeScreenController
