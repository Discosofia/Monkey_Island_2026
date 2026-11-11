--!strict
-- Una fila de las barras de supervivencia (icono y barra con su relleno). La usan el HUD de la Isla
-- (SurvivalHUDController: hambre, sed, estamina y fiebre) y las cinemáticas (Cinematics/SurvivalActor), para que se vean
-- igual. Solo dibuja: quien la crea mueve el tamaño del relleno y su color.

local Widgets = require(script.Parent.Widgets)

local SurvivalBar = {}

SurvivalBar.BAR_WIDTH = 170
SurvivalBar.BAR_HEIGHT = 16
SurvivalBar.ROW_HEIGHT = 24
SurvivalBar.LOW_COLOR = Color3.fromRGB(235, 70, 60) -- parpadeo de alarma (rojo: daño o peligro)

-- Colores de cada barra (el verde es solo de la curación).
SurvivalBar.HUNGER_COLOR = Color3.fromRGB(230, 150, 70)
SurvivalBar.THIRST_COLOR = Color3.fromRGB(80, 170, 240)

export type Bar = { row: Frame, fill: Frame, color: Color3 }

local BAR_WIDTH = SurvivalBar.BAR_WIDTH
local BAR_HEIGHT = SurvivalBar.BAR_HEIGHT
local ROW_HEIGHT = SurvivalBar.ROW_HEIGHT

function SurvivalBar.new(parent: Instance, order: number, icon: string, color: Color3): Bar
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

	return { row = row, fill = fill, color = color }
end

return SurvivalBar
