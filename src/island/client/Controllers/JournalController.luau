--!strict
-- Diario de campo en la Isla (Fase 4): J en PC, Select en mando o el botón táctil "Diario".

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Journal = require(ReplicatedStorage.Shared.UI.Journal)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local ACTION = "ToggleJournal"

local JournalController = {}

function JournalController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("JournalHUD", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 6
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromScale(0.62, 0.78)
	panel.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
	panel.BackgroundTransparency = 0.08
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(320, 260)
	limit.MaxSize = Vector2.new(680, 620)
	limit.Parent = panel

	local title = Widgets.label("", panel)
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -28, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(8, 52)
	list.Size = UDim2.new(1, -16, 1, -60)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	local total = 0
	for _ in Monkeys do
		total += 1
	end

	local function refresh()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local discovered = Journal.fill(list, Progression.read(player).bestiary)
		title.Text = `📖 Diario de campo · {discovered}/{total} especies (J para cerrar)`
	end

	ContextActionService:BindAction(ACTION, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			gui.Enabled = not gui.Enabled
			if gui.Enabled then
				refresh()
			end
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.J, Enum.KeyCode.ButtonSelect)
	ContextActionService:SetTitle(ACTION, "Diario")

	player:GetAttributeChangedSignal("Progress"):Connect(function()
		if gui.Enabled then
			refresh()
		end
	end)
end

return JournalController
