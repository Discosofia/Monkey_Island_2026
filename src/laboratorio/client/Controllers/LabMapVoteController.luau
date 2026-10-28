--!strict
-- Votación del mapa del Laboratorio (L4b; servidor: LabVoteService). Se ve mientras exista el atributo
-- LabVoteEndsAt y la fase sea la espera: tres tarjetas (una por mapa de Config.Lab.Maps) con su maqueta voxel
-- (Shared/LabMapModels), su nombre, su alcance y los votos que lleva (el atributo LabMapVote de cada jugador).
-- Pulsar una tarjeta vota (Remotes.LabMapVote; se puede cambiar); la tuya, con el borde dorado y "✅ Tu voto".
-- Con la ventana abierta el ratón va suelto (FirstPersonController.freeCursor). Mientras está abierta, el
-- selector de armas (LabLoadoutController) espera y se abre solo al cerrarse. En una pantalla baja las
-- tarjetas son más bajas y sin el alcance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local LabMapModels = require(ReplicatedStorage.Shared.LabMapModels)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardModels = require(ReplicatedStorage.Shared.RewardModels)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local FirstPersonController = require(script.Parent.FirstPersonController)

local T = Strings.t

local WINDOW_COLOR = Color3.fromRGB(25, 20, 15)
local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local PICTURE_COLOR = Color3.fromRGB(32, 28, 24)
local GOLD = Color3.fromRGB(242, 178, 36)
local SECONDARY_TEXT = Color3.fromRGB(210, 200, 185)
-- La ventana va debajo de la línea de la fase (LabHUDController, que acaba a 34 px).
local TOP = 40
local WIDTH = 0.94
local MAX_WIDTH = 760
local PADDING = 8
local TITLE_HEIGHT = 26
-- Alto de las tarjetas (y de su imagen) en PC y en una pantalla baja.
local COMPACT_BELOW = 500
local CARD_HEIGHT = 206
local PICTURE_HEIGHT = 104
local COMPACT_CARD_HEIGHT = 132
local COMPACT_PICTURE_HEIGHT = 52

local LabMapVoteController = {}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function textLimit(label: TextLabel | TextButton, size: number)
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = label
end

type Card = {
	button: TextButton,
	stroke: UIStroke,
	range: TextLabel,
	votes: TextLabel,
	mine: TextLabel,
}

function LabMapVoteController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("LabMapVote", player:WaitForChild("PlayerGui"))
	-- Por encima del selector de armas (8), por si coinciden un instante.
	gui.DisplayOrder = 9

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0)
	window.Position = UDim2.new(0.5, 0, 0, TOP)
	window.BackgroundColor3 = WINDOW_COLOR
	window.BackgroundTransparency = 0.1
	window.Visible = false
	window.Parent = gui
	corner(window, 14)

	local title = Widgets.label(T("🗳️ Vota el mapa"), window)
	title.Name = "Title"
	title.Position = UDim2.fromOffset(PADDING + 4, PADDING)
	title.Size = UDim2.new(0.55, 0, 0, TITLE_HEIGHT)
	title.TextXAlignment = Enum.TextXAlignment.Left
	textLimit(title, 22)

	local timer = Widgets.label("", window)
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(1, 0)
	timer.Position = UDim2.new(1, -PADDING - 4, 0, PADDING)
	timer.Size = UDim2.new(0.4, 0, 0, TITLE_HEIGHT)
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.TextColor3 = GOLD
	textLimit(timer, 20)

	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(PADDING, PADDING * 2 + TITLE_HEIGHT)
	row.Parent = window
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row

	local cards: { [string]: Card } = {}
	local views: { [string]: ViewportFrame } = {}
	for index, mapId in Config.Lab.Maps do
		local button = Instance.new("TextButton")
		button.Name = mapId
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / #Config.Lab.Maps, -5, 1, 0)
		button.BackgroundColor3 = CARD_COLOR
		button.Text = ""
		button.AutoButtonColor = true
		button.Parent = row
		corner(button, 10)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = GOLD
		stroke.Thickness = 3
		stroke.Enabled = false
		stroke.Parent = button
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 2)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = button
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.PaddingLeft = UDim.new(0, 4)
		padding.PaddingRight = UDim.new(0, 4)
		padding.Parent = button

		local view = Instance.new("ViewportFrame")
		view.Name = "Picture"
		view.LayoutOrder = 1
		view.BackgroundColor3 = PICTURE_COLOR
		view.Size = UDim2.new(1, 0, 0, PICTURE_HEIGHT)
		view.Parent = button
		corner(view, 8)
		views[mapId] = view
		local name = Widgets.label(T(Config.Lab.MapNames[mapId]), button)
		name.Name = "MapName"
		name.LayoutOrder = 2
		name.Size = UDim2.new(1, 0, 0, 24)
		textLimit(name, 18)
		local range = Widgets.label(T(Config.Lab.MapRanges[mapId]), button)
		range.Name = "Range"
		range.LayoutOrder = 3
		range.Size = UDim2.new(1, 0, 0, 18)
		range.TextColor3 = SECONDARY_TEXT
		textLimit(range, 14)
		local votes = Widgets.label("", button)
		votes.Name = "Votes"
		votes.LayoutOrder = 4
		votes.Size = UDim2.new(1, 0, 0, 20)
		votes.TextColor3 = GOLD
		textLimit(votes, 16)
		local mine = Widgets.label(T("✅ Tu voto"), button)
		mine.Name = "Mine"
		mine.LayoutOrder = 5
		mine.Size = UDim2.new(1, 0, 0, 18)
		mine.Visible = false
		textLimit(mine, 14)
		button.Activated:Connect(function()
			Remotes.LabMapVote:FireServer(mapId)
		end)
		cards[mapId] = { button = button, stroke = stroke, range = range, votes = votes, mine = mine }
	end

	-- Las maquetas, una sola vez (los ViewportFrame las conservan).
	for mapId, view in views do
		RewardModels.frame(view, LabMapModels.build(mapId), 1.2)
	end

	-- Tamaño según la pantalla: todo a la vista, sin desplazarse.
	local function layout()
		local screen = gui.AbsoluteSize
		local compact = screen.Y > 0 and screen.Y < COMPACT_BELOW
		local cardHeight = if compact then COMPACT_CARD_HEIGHT else CARD_HEIGHT
		for mapId, card in cards do
			views[mapId].Size = UDim2.new(1, 0, 0, if compact then COMPACT_PICTURE_HEIGHT else PICTURE_HEIGHT)
			card.range.Visible = not compact
		end
		row.Size = UDim2.new(1, -PADDING * 2, 0, cardHeight)
		local height = PADDING * 3 + TITLE_HEIGHT + cardHeight
		window.Size = UDim2.new(math.min(WIDTH, MAX_WIDTH / math.max(1, screen.X)), 0, 0, height)
	end
	layout()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	local wasOpen = false
	RunService.Heartbeat:Connect(function()
		local endsAt = ReplicatedStorage:GetAttribute("LabVoteEndsAt")
		local open = typeof(endsAt) == "number" and Arena.phase() == "Waiting"
		window.Visible = open
		if open ~= wasOpen then
			wasOpen = open
			FirstPersonController.freeCursor("MapVote", open)
		end
		if not open then
			return
		end
		timer.Text = T("Se cierra en {seconds}", {
			seconds = math.ceil(math.max(0, (endsAt :: number) - Workspace:GetServerTimeNow())),
		})
		local counts: { [string]: number } = {}
		for _, other in Players:GetPlayers() do
			local vote = other:GetAttribute("LabMapVote")
			if typeof(vote) == "string" then
				counts[vote] = (counts[vote] or 0) + 1
			end
		end
		local chosen = player:GetAttribute("LabMapVote")
		for mapId, card in cards do
			card.votes.Text = T("Votos: {n}", { n = counts[mapId] or 0 })
			card.stroke.Enabled = mapId == chosen
			card.mine.Visible = mapId == chosen
		end
	end)
end

return LabMapVoteController
