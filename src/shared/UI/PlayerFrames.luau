--!strict
-- Marcos de jugador (Fase 9, G9c; Data/Cosmetics, tipo Frame): el borde que rodea el nombre del jugador
-- en las filas del ranking, en la ventana Grupo y en los resultados de la Isla y de Dunas. El marco
-- puesto lo publica el servidor en el atributo "Frame" (ServerShared/CosmeticsServer); el ranking lo
-- trae en cada puesto (LeaderboardService). Se dibuja solo con piezas de interfaz (UIStroke,
-- UIGradient y marcos pequeños), sin imágenes.
--
-- Cuanto más raro, más detalle (Data/Cosmetics): Poco común, un degradado y remaches en las esquinas;
-- Raro, además, un brillo que corre por el borde; Épico y Legendario, esquirlas en las esquinas y
-- chispas o brasas que suben.

local RunService = game:GetService("RunService")

type Style = {
	thickness: number,
	colors: { Color3 }, -- degradado del borde, de un extremo al otro
	rotation: number, -- giro del degradado (90: de arriba abajo)
	flow: number?, -- vueltas por segundo del degradado a lo largo del borde (la lava que corre)
	corner: "Rivet" | "Shard",
	cornerColor: Color3,
	cornerEdge: Color3,
	embers: Color3?, -- brasas que suben desde el borde de abajo
}

local STYLES: { [string]: Style } = {
	BronzeFrame = {
		thickness = 2.5,
		colors = { Color3.fromRGB(240, 180, 110), Color3.fromRGB(190, 115, 55), Color3.fromRGB(120, 70, 35) },
		rotation = 90,
		corner = "Rivet",
		cornerColor = Color3.fromRGB(235, 170, 100),
		cornerEdge = Color3.fromRGB(90, 50, 25),
	},
	MoltenObsidianFrame = {
		thickness = 3,
		colors = {
			Color3.fromRGB(40, 30, 35),
			Color3.fromRGB(255, 90, 15),
			Color3.fromRGB(255, 190, 60),
			Color3.fromRGB(255, 90, 15),
			Color3.fromRGB(40, 30, 35),
		},
		rotation = 0,
		flow = 0.35,
		corner = "Shard",
		cornerColor = Color3.fromRGB(34, 27, 30),
		cornerEdge = Color3.fromRGB(255, 110, 30),
		embers = Color3.fromRGB(255, 140, 40),
	},
	-- Plata (pase, gratis, raro): plata pulida con un brillo que la recorre despacio y tachuelas de acero.
	SilverFrame = {
		thickness = 2.5,
		colors = {
			Color3.fromRGB(140, 150, 165),
			Color3.fromRGB(215, 222, 232),
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(215, 222, 232),
			Color3.fromRGB(140, 150, 165),
		},
		rotation = 0,
		flow = 0.15,
		corner = "Rivet",
		cornerColor = Color3.fromRGB(110, 120, 135),
		cornerEdge = Color3.fromRGB(45, 50, 60),
	},
	-- Fuego azul (pase, premium, épico): el de los trajes de la temporada 1, fuego azul que corre por la
	-- piedra pómez, esquirlas de azufre y chispas azules.
	BlueFireFrame = {
		thickness = 3,
		colors = {
			Color3.fromRGB(165, 160, 150),
			Color3.fromRGB(45, 120, 255),
			Color3.fromRGB(190, 230, 255),
			Color3.fromRGB(45, 120, 255),
			Color3.fromRGB(165, 160, 150),
		},
		rotation = 0,
		flow = 0.4,
		corner = "Shard",
		cornerColor = Color3.fromRGB(235, 205, 55),
		cornerEdge = Color3.fromRGB(120, 95, 20),
		embers = Color3.fromRGB(150, 210, 255),
	},
	-- Bambú (tienda): caña clara con nudos oscuros cada poco y las esquinas atadas.
	BambooFrame = {
		thickness = 2.5,
		colors = (function()
			local cane, node = Color3.fromRGB(225, 200, 120), Color3.fromRGB(120, 95, 45)
			local list = {}
			for index = 1, 13 do
				table.insert(list, if index % 3 == 0 then node else cane)
			end
			return list
		end)(),
		rotation = 0,
		corner = "Rivet",
		cornerColor = Color3.fromRGB(140, 100, 55),
		cornerEdge = Color3.fromRGB(70, 45, 25),
	},
	-- Coral (tienda): rosa coral y blanco, con una perla en cada esquina.
	CoralFrame = {
		thickness = 3,
		colors = {
			Color3.fromRGB(255, 225, 220),
			Color3.fromRGB(255, 130, 115),
			Color3.fromRGB(235, 85, 95),
			Color3.fromRGB(255, 130, 115),
			Color3.fromRGB(255, 225, 220),
		},
		rotation = 45,
		corner = "Rivet",
		cornerColor = Color3.fromRGB(250, 248, 240),
		cornerEdge = Color3.fromRGB(200, 170, 165),
	},
	-- Oro del templo (tienda, épico): el brillo corre por el oro y las esquinas son turquesas.
	TempleGoldFrame = {
		thickness = 3,
		colors = {
			Color3.fromRGB(150, 100, 25),
			Color3.fromRGB(255, 205, 60),
			Color3.fromRGB(255, 250, 200),
			Color3.fromRGB(255, 205, 60),
			Color3.fromRGB(150, 100, 25),
		},
		rotation = 0,
		flow = 0.25,
		corner = "Shard",
		cornerColor = Color3.fromRGB(60, 205, 200),
		cornerEdge = Color3.fromRGB(120, 80, 20),
	},
	-- Diamante (Robux, épico): blanco y celeste que destella al correr, gemas y chispas que suben.
	DiamondFrame = {
		thickness = 3,
		colors = {
			Color3.fromRGB(150, 215, 255),
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(110, 190, 245),
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(150, 215, 255),
		},
		rotation = 0,
		flow = 0.45,
		corner = "Shard",
		cornerColor = Color3.fromRGB(235, 250, 255),
		cornerEdge = Color3.fromRGB(80, 160, 230),
		embers = Color3.fromRGB(230, 248, 255),
	},
}

-- Prefijo de lo que pone el marco en la pieza (para quitarlo al cambiarlo).
local PREFIX = "PlayerFrame"
local EMBER_COUNT = 3
local EMBER_SECONDS = 1.4

local PlayerFrames = {}

-- Si "frameId" es un marco que se sabe dibujar.
function PlayerFrames.has(frameId: string?): boolean
	return frameId ~= nil and STYLES[frameId] ~= nil
end

local function clear(target: GuiObject)
	for _, child in target:GetChildren() do
		if string.sub(child.Name, 1, #PREFIX) == PREFIX then
			child:Destroy()
		end
	end
end

local function cornerPiece(target: GuiObject, style: Style, anchor: Vector2)
	local piece = Instance.new("Frame")
	piece.Name = `{PREFIX}Corner`
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.BackgroundColor3 = style.cornerColor
	piece.ZIndex = target.ZIndex + 2
	-- En la esquina misma, un poco hacia dentro para que no sobresalga de la fila.
	local inset = if style.corner == "Rivet" then 5 else 4
	piece.Position =
		UDim2.new(anchor.X, if anchor.X == 0 then inset else -inset, anchor.Y, if anchor.Y == 0 then inset else -inset)
	local edge = Instance.new("UIStroke")
	edge.Color = style.cornerEdge
	edge.Parent = piece
	if style.corner == "Rivet" then
		piece.Size = UDim2.fromOffset(6, 6)
		edge.Thickness = 1
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = piece
	else
		piece.Size = UDim2.fromOffset(8, 8)
		piece.Rotation = 45
		edge.Thickness = 1.5
	end
	piece.Parent = target
end

-- Pone el marco "frameId" en "target" (una fila o una tarjeta), o lo quita con nil o uno que no existe.
function PlayerFrames.apply(target: GuiObject, frameId: string?)
	clear(target)
	local style = if frameId then STYLES[frameId] else nil
	if not style then
		return
	end
	local stroke = Instance.new("UIStroke")
	stroke.Name = `{PREFIX}Stroke`
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = style.thickness
	stroke.Parent = target
	local keypoints = {}
	for index, color in style.colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#style.colors - 1), color))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(keypoints)
	gradient.Rotation = style.rotation
	gradient.Parent = stroke
	for _, anchor in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		cornerPiece(target, style, anchor)
	end

	local embers: { Frame } = {}
	if style.embers then
		for index = 1, EMBER_COUNT do
			local ember = Instance.new("Frame")
			ember.Name = `{PREFIX}Ember{index}`
			ember.AnchorPoint = Vector2.new(0.5, 0.5)
			ember.Size = UDim2.fromOffset(3, 3)
			ember.BackgroundColor3 = style.embers
			ember.BorderSizePixel = 0
			ember.ZIndex = target.ZIndex + 2
			ember.Parent = target
			table.insert(embers, ember)
		end
	end
	if not (style.flow or #embers > 0) then
		return
	end
	-- La lava corre por el borde y las brasas suben desde abajo, cada una en su momento y su sitio.
	local seeds = {}
	for index in embers do
		seeds[index] = { phase = (index - 1) / #embers, x = math.random() }
	end
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not (stroke.Parent and target.Parent) then
			connection:Disconnect()
			return
		end
		local now = os.clock()
		if style.flow then
			gradient.Offset = Vector2.new(((now * style.flow) % 2) - 1, 0)
		end
		for index, ember in embers do
			local seed = seeds[index]
			local t = (now / EMBER_SECONDS + seed.phase) % 1
			if t < 0.02 then
				seed.x = 0.1 + math.random() * 0.8
			end
			ember.Position = UDim2.new(seed.x, math.sin(t * 9) * 3, 1, -t * 18)
			ember.BackgroundTransparency = t
		end
	end)
end

return PlayerFrames
