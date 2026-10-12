--!strict
-- Piezas de interfaz reutilizables, pensadas para verse bien en móvil y en PC.

local Widgets = {}

function Widgets.screen(name: string, parent: Instance): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.Parent = parent
	return gui
end

function Widgets.label(text: string, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Text = text
	label.Parent = parent
	return label
end

function Widgets.button(text: string, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Color3.fromRGB(242, 178, 36)
	button.TextColor3 = Color3.fromRGB(40, 25, 5)
	button.Font = Enum.Font.BuilderSansBold
	button.TextScaled = true
	button.AutoButtonColor = true
	button.Text = text
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = button

	-- Tamaño mínimo cómodo para el dedo en móvil y máximo razonable en PC.
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(160, 48)
	sizeLimit.MaxSize = Vector2.new(360, 80)
	sizeLimit.Parent = button

	return button
end

return Widgets
