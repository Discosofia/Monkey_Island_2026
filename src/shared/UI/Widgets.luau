--!strict
-- Piezas de interfaz reutilizables, pensadas para verse bien en móvil y en PC.

local RunService = game:GetService("RunService")

local Rarities = require(script.Parent.Parent.Data.Rarities)

-- Oro del degradado del borde mítico.
local MYTHIC_GOLD = Color3.fromRGB(255, 214, 110)

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

-- Borde de la rareza de una tarjeta (Armario, tiendas de cosméticos): fino y de su color; el legendario
-- más grueso, y el mítico con un degradado de su color y oro que gira.
function Widgets.rarityBorder(card: GuiObject, rarityId: string)
	local rarity = Rarities[rarityId] or Rarities.Common
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = rarity.color
	stroke.Thickness = if rarityId == "Mythic" then 3 elseif rarityId == "Legendary" then 2.5 else 1.5
	stroke.Parent = card
	if rarityId == "Mythic" then
		stroke.Color = Color3.new(1, 1, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarity.color),
			ColorSequenceKeypoint.new(0.5, MYTHIC_GOLD),
			ColorSequenceKeypoint.new(1, rarity.color),
		})
		gradient.Parent = stroke
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			if not card.Parent then
				connection:Disconnect()
				return
			end
			gradient.Rotation = (os.clock() * 120) % 360
		end)
	end
end

return Widgets
