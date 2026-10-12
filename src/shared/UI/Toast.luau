--!strict
-- Muestra mensajes cortos en la parte superior de la pantalla (solo cliente).

local Players = game:GetService("Players")

local DISPLAY_SECONDS = 4

local Toast = {}

local label: TextLabel? = nil
local showCount = 0

local function getLabel(): TextLabel
	if label then
		return label
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Toasts"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10

	local text = Instance.new("TextLabel")
	text.Name = "Message"
	text.AnchorPoint = Vector2.new(0.5, 0)
	-- Debajo del reloj y del indicador del Basecamp de la Isla.
	text.Position = UDim2.fromScale(0.5, 0.15)
	text.Size = UDim2.fromScale(0.7, 0.07)
	text.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	text.BackgroundTransparency = 0.2
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.BuilderSansBold
	text.TextScaled = true
	text.Visible = false
	text.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(700, 60)
	sizeLimit.Parent = text

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = text

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = text

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	label = text
	return text
end

function Toast.show(message: string)
	local text = getLabel()
	text.Text = message
	text.Visible = true

	showCount += 1
	local thisShow = showCount
	task.delay(DISPLAY_SECONDS, function()
		-- Solo se oculta si no ha llegado otro mensaje mientras tanto.
		if showCount == thisShow then
			text.Visible = false
		end
	end)
end

return Toast
