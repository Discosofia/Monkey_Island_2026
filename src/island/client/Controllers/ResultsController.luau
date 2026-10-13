--!strict
-- Pantalla de resultados al terminar la partida (Fase 2.7): días sobrevividos, tus estadísticas,
-- el Ámbar ganado y un botón para volver ya al Lobby (si no, el servidor os envía a todos).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local ResultsController = {}

local function show(summary: { [string]: any })
	local player = Players.LocalPlayer
	local gui = Widgets.screen("Results", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = true

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(10, 8, 6)
	shade.BackgroundTransparency = 0.25
	shade.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.6, 0.7)
	panel.BackgroundColor3 = Color3.fromRGB(30, 24, 18)
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(300, 280)
	sizeLimit.MaxSize = Vector2.new(560, 480)
	sizeLimit.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.05, 0)
	padding.Parent = panel

	local victory = summary.result == "Victory"
	type Line = { text: string, height: number, color: Color3 }
	local plain = Color3.fromRGB(230, 220, 200)
	local lines: { Line } = {
		{
			text = if victory then "🚁 ¡Rescatados!" else "💀 El Basecamp ha caído",
			height = 0.14,
			color = Color3.fromRGB(255, 210, 120),
		},
		{ text = `Sobrevivisteis {summary.days} día(s)`, height = 0.09, color = Color3.new(1, 1, 1) },
		{ text = `🐒 Monos derrotados: {summary.kills}`, height = 0.08, color = plain },
		{ text = `💚 Aliados reanimados: {summary.revives}`, height = 0.08, color = plain },
		{ text = `👻 Caídas: {summary.deaths}`, height = 0.08, color = plain },
		{ text = `👑 Jefes: {summary.bosses or 0}`, height = 0.08, color = plain },
		{ text = `✨ Ámbar ganado: {summary.amber}`, height = 0.1, color = Color3.fromRGB(255, 200, 80) },
	}
	for index, line in lines do
		local label = Widgets.label(line.text, panel)
		label.LayoutOrder = index
		label.Size = UDim2.fromScale(0.9, line.height)
		label.TextColor3 = line.color
	end

	local button = Widgets.button("Volver al Lobby", panel)
	button.LayoutOrder = #lines + 1
	button.Size = UDim2.fromScale(0.6, 0.13)
	button.MouseButton1Click:Connect(function()
		button.Text = "Viajando…"
		Remotes.RequestReturnToLobby:FireServer()
	end)

	local countdown = Widgets.label("", panel)
	countdown.LayoutOrder = #lines + 2
	countdown.Size = UDim2.fromScale(0.9, 0.06)
	countdown.TextColor3 = Color3.fromRGB(180, 170, 160)
	task.spawn(function()
		for remaining = Config.Match.ResultsSeconds, 0, -1 do
			countdown.Text = `Volvéis todos al Lobby en {remaining} s`
			task.wait(1)
		end
	end)
end

function ResultsController:Start()
	Remotes.MatchEnded.OnClientEvent:Connect(function(summary: any)
		if typeof(summary) == "table" then
			show(summary)
		end
	end)
end

return ResultsController
