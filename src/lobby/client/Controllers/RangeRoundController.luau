--!strict
-- Panel de la «Ronda de tiro» del campo de tiro (Fase 23, RangeRoundService). Un cartel pequeño arriba en
-- el centro, bajo la barra de Roblox (no pisa el joystick ni los botones de combate del teléfono, que
-- van abajo): el tiempo que queda, los puntos y los aciertos, críticos y disparos. Al acabar enseña la
-- tarjeta del resultado con la precisión y tu mejor puntuación de la sesión, unos segundos
-- (Config.Range.ResultSeconds). Sin botones: no tapa nada ni bloquea toques. Colores del HUD del Lobby:
-- madera oscura, dorado y naranja, sin verde, morado ni rojo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local T = Strings.t

local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local GOLD = Color3.fromRGB(255, 215, 90)
local WHITE = Color3.new(1, 1, 1)
local ORANGE = Color3.fromRGB(255, 122, 26)
local SECONDARY = Color3.fromRGB(215, 205, 190)
local PANEL_WIDTH = 300
-- Hueco bajo la barra de Roblox.
local TOP_MARGIN = 6

type Score = { points: number, hits: number, crits: number, shots: number }
type Result = {
	points: number,
	hits: number,
	crits: number,
	shots: number,
	best: number,
	newBest: boolean,
	left: boolean,
}

local RangeRoundController = {}

local panel: Frame
local titleLabel: TextLabel
local pointsLabel: TextLabel
local detailLabel: TextLabel
local bestLabel: TextLabel

-- Lo que enseña ahora: en juego (endsAt, score) o el resultado.
local endsAt = 0
local active = false
local score: Score = { points = 0, hits = 0, crits = 0, shots = 0 }
local result: Result? = nil
local shownSecond = -1
-- Distingue la tarjeta de cada ronda para que no la esconda el temporizador de la anterior.
local cardToken = 0

local function newLabel(text: string, size: number, color: Color3, order: number): TextLabel
	local label = Widgets.label(text, panel)
	label.TextScaled = false
	label.TextSize = size
	label.TextColor3 = color
	label.Size = UDim2.new(1, 0, 0, size + 4)
	label.LayoutOrder = order
	return label
end

local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function render()
	local current = result
	if current then
		titleLabel.Text = if current.left then T("Ronda cortada") else T("¡Ronda terminada!")
		pointsLabel.Text = T("{points} puntos", { points = current.points })
		local accuracy = if current.shots > 0 then math.min(100, math.round(current.hits / current.shots * 100)) else 0
		detailLabel.Text = T(
			"Aciertos {hits}/{shots} ({accuracy}%) · Críticos {crits}",
			{ hits = current.hits, shots = current.shots, accuracy = accuracy, crits = current.crits }
		)
		bestLabel.Text = if current.newBest
			then T("¡Nuevo récord! Mejor de la sesión: {best}", { best = current.best })
			else T("Mejor de la sesión: {best}", { best = current.best })
		bestLabel.TextColor3 = if current.newBest then ORANGE else SECONDARY
		bestLabel.Visible = true
		return
	end
	titleLabel.Text = T("Ronda de tiro · {time}", { time = clock(endsAt - Workspace:GetServerTimeNow()) })
	pointsLabel.Text = T("{points} puntos", { points = score.points })
	detailLabel.Text = T(
		"Aciertos {hits} · Críticos {crits} · Disparos {shots}",
		{ hits = score.hits, crits = score.crits, shots = score.shots }
	)
	bestLabel.Visible = false
end

local function onRound(kind: any, data: any)
	if typeof(data) ~= "table" then
		return
	end
	if kind == "Start" and typeof(data.endsAt) == "number" then
		cardToken += 1
		endsAt = data.endsAt
		active = true
		result = nil
		score = { points = 0, hits = 0, crits = 0, shots = 0 }
		shownSecond = -1
		panel.Visible = true
		render()
	elseif kind == "Score" and active then
		score = {
			points = tonumber(data.points) or 0,
			hits = tonumber(data.hits) or 0,
			crits = tonumber(data.crits) or 0,
			shots = tonumber(data.shots) or 0,
		}
		render()
	elseif kind == "End" then
		active = false
		cardToken += 1
		local token = cardToken
		result = {
			points = tonumber(data.points) or 0,
			hits = tonumber(data.hits) or 0,
			crits = tonumber(data.crits) or 0,
			shots = tonumber(data.shots) or 0,
			best = tonumber(data.best) or 0,
			newBest = data.newBest == true,
			left = data.left == true,
		}
		panel.Visible = true
		render()
		task.delay(Config.Range.ResultSeconds, function()
			if cardToken == token then
				panel.Visible = false
			end
		end)
	end
end

function RangeRoundController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Widgets.screen("RangeRound", playerGui)
	gui.DisplayOrder = 0

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, TOP_MARGIN)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = CARD_COLOR
	panel.BackgroundTransparency = 0.1
	panel.Active = false
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = panel

	titleLabel = newLabel("", 18, SECONDARY, 1)
	pointsLabel = newLabel("", 30, GOLD, 2)
	detailLabel = newLabel("", 15, WHITE, 3)
	bestLabel = newLabel("", 15, SECONDARY, 4)
	bestLabel.Visible = false

	Remotes.RangeRound.OnClientEvent:Connect(onRound)
	Strings.onChanged(render)
	-- El reloj se rehace cada vez que cambia el segundo que se enseña.
	RunService.Heartbeat:Connect(function()
		if not active then
			return
		end
		local second = math.ceil(endsAt - Workspace:GetServerTimeNow())
		if second ~= shownSecond then
			shownSecond = second
			render()
		end
	end)
end

return RangeRoundController
