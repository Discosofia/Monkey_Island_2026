--!strict
-- Barras de supervivencia arriba a la izquierda (Fase 2.1): hambre, sed y estamina.
-- Parpadean en rojo cuando bajan de Config.Survival.LowThreshold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Survival = require(ReplicatedStorage.Shared.Survival)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local Stamina = require(script.Parent.Parent.Stamina)

local BAR_WIDTH = 170
local BAR_HEIGHT = 16
local ROW_HEIGHT = 24
local LOW_COLOR = Color3.fromRGB(235, 70, 60)

type Bar = { fill: Frame, color: Color3, read: () -> number }

local SurvivalHUDController = {}

local function newBar(parent: Instance, order: number, icon: string, color: Color3, read: () -> number): Bar
	local row = Instance.new("Frame")
	row.Name = `Row{order}`
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(BAR_WIDTH + 30, ROW_HEIGHT)
	row.Parent = parent

	local label = Widgets.label(icon, row)
	label.Size = UDim2.fromOffset(24, ROW_HEIGHT)

	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0, 0.5)
	back.Position = UDim2.new(0, 30, 0.5, 0)
	back.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BackgroundTransparency = 0.35
	back.Parent = row
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = back

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = color
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	return { fill = fill, color = color, read = read }
end

function SurvivalHUDController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("SurvivalHUD", player:WaitForChild("PlayerGui"))

	local column = Instance.new("Frame")
	column.Name = "Bars"
	column.BackgroundTransparency = 1
	column.Position = UDim2.fromOffset(12, 10)
	column.Size = UDim2.fromOffset(BAR_WIDTH + 30, ROW_HEIGHT * 3 + 8)
	column.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = column

	local bars = {
		newBar(column, 1, "🍖", Color3.fromRGB(230, 150, 70), function()
			return Survival.get(player, Survival.HUNGER) / Survival.MAX
		end),
		newBar(column, 2, "💧", Color3.fromRGB(80, 170, 240), function()
			return Survival.get(player, Survival.THIRST) / Survival.MAX
		end),
		newBar(column, 3, "⚡", Color3.fromRGB(240, 220, 80), function()
			return Stamina.get() / Stamina.MAX
		end),
	}

	local low = Config.Survival.LowThreshold / Survival.MAX
	RunService.RenderStepped:Connect(function()
		-- Parpadeo: medio segundo encendido, medio apagado.
		local blinkOn = os.clock() % 1 < 0.5
		for _, bar in bars do
			local value = math.clamp(bar.read(), 0, 1)
			bar.fill.Size = UDim2.fromScale(value, 1)
			bar.fill.Visible = value > 0
			bar.fill.BackgroundColor3 = if value <= low and blinkOn then LOW_COLOR else bar.color
		end
	end)
end

return SurvivalHUDController
