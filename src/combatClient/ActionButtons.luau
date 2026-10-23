--!strict
-- Botones táctiles de las acciones (Correr, Esquivar, Bolsa…). Sustituye a los botones automáticos
-- de ContextActionService, que en móviles pequeños tapaban el salto o se salían de la pantalla.
--
-- Todos van en una cuadrícula encima y a la izquierda del botón de salto. Cada acción tiene su
-- casilla fija (SLOTS), así no cambian de sitio cuando otra aparece o desaparece (Comer, Curar…).
-- Las teclas y los botones del mando se siguen enlazando con ContextActionService.
--
-- Uso, igual que ContextActionService:BindAction pero con el título del botón:
--   ActionButtons.bind("Dodge", "Esquivar", handler, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
--   ActionButtons.unbind("Dodge")

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

export type Handler = (actionName: string, state: Enum.UserInputState, input: InputObject) -> Enum.ContextActionResult?

-- Casilla de cada acción: columna contando desde el salto hacia la izquierda y fila contando
-- hacia arriba (0 = la fila justo encima del salto). Las más usadas, junto al pulgar.
-- Las 5 habilidades del rol van en un bloque de 2 columnas (la definitiva a la izquierda y la cuarta
-- activa, la R, encima de la C). La guardia (Fase 10, C5), justo encima de esquivar: las dos defensas
-- bajo el pulgar.
local SLOTS: { [string]: Vector2 } = {
	Dodge = Vector2.new(0, 0),
	Sprint = Vector2.new(1, 0),
	Ability1 = Vector2.new(2, 0),
	Ability2 = Vector2.new(3, 0),
	Eat = Vector2.new(4, 0),
	UseHeal = Vector2.new(5, 0),
	Guard = Vector2.new(0, 1),
	ToggleJournal = Vector2.new(1, 1),
	Ability3 = Vector2.new(2, 1),
	Ability4 = Vector2.new(3, 1),
	Surrender = Vector2.new(4, 1),
	ToggleMaterials = Vector2.new(5, 1),
	BuildRotate = Vector2.new(0, 2),
	BuildNext = Vector2.new(1, 2),
	Ability5 = Vector2.new(2, 2),
	BuildDemolish = Vector2.new(3, 2),
	Mount = Vector2.new(4, 2), -- montar y bajar (Fase 11, UI/MountRiders)
}
-- Acciones sin casilla fija: a partir de aquí, en la cuarta fila.
local EXTRA_ROW = 3
local COLUMNS = 6

local GAP = 6
local MIN_BUTTON = 46 -- tamaño mínimo cómodo para el dedo
local MAX_BUTTON = 72

local ActionButtons = {}

local gui: ScreenGui? = nil
local jumpButton: GuiObject? = nil
local buttons: { [string]: TextButton } = {}
local extraSlots: { [string]: Vector2 } = {}

local function slotOf(action: string): Vector2
	local slot = SLOTS[action] or extraSlots[action]
	if slot then
		return slot
	end
	local used = 0
	for _ in extraSlots do
		used += 1
	end
	slot = Vector2.new(used % COLUMNS, EXTRA_ROW + used // COLUMNS)
	extraSlots[action] = slot
	return slot
end

-- Posición y tamaño del salto. Si aún no existe, los mismos que calcula el PlayerModule de Roblox.
local function jumpRect(screen: Vector2): (Vector2, Vector2)
	local jump = jumpButton
	if jump and jump.Parent and jump.AbsoluteSize.X > 0 then
		return jump.AbsolutePosition, jump.AbsoluteSize
	end
	local small = math.min(screen.X, screen.Y) <= 500
	local size = if small then 70 else 120
	local position = if small
		then Vector2.new(screen.X - 95, screen.Y - 90)
		else Vector2.new(screen.X - 170, screen.Y - 210)
	return position, Vector2.new(size, size)
end

local function layout()
	local screenGui = gui
	if not screenGui then
		return
	end
	local jumpPosition, jumpSize = jumpRect(screenGui.AbsoluteSize)
	local size = math.clamp(math.floor(jumpSize.X * 0.75), MIN_BUTTON, MAX_BUTTON)
	local pitch = size + GAP
	-- Esquina inferior derecha de la cuadrícula: alineada con el borde derecho del salto, justo encima.
	local right = jumpPosition.X + jumpSize.X
	local bottom = jumpPosition.Y - GAP
	for action, button in buttons do
		local slot = slotOf(action)
		button.Size = UDim2.fromOffset(size, size)
		button.Position = UDim2.fromOffset(right - (slot.X + 1) * pitch + GAP, bottom - (slot.Y + 1) * pitch + GAP)
	end
end

-- Copia los márgenes de pantalla de la TouchGui de Roblox: así las coordenadas del salto y las de
-- nuestros botones coinciden.
local function adoptJumpButton(candidate: Instance)
	local screenGui = gui
	if not (screenGui and candidate.Name == "JumpButton" and candidate:IsA("GuiObject")) then
		return
	end
	jumpButton = candidate
	local touchGui = candidate:FindFirstAncestorWhichIsA("ScreenGui")
	if touchGui then
		screenGui.IgnoreGuiInset = touchGui.IgnoreGuiInset
		screenGui.ScreenInsets = touchGui.ScreenInsets
	end
	candidate:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout)
	candidate:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()
end

local function ensureGui(): ScreenGui
	local existing = gui
	if existing then
		return existing
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ActionButtons"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 5
	screenGui.Parent = playerGui
	gui = screenGui
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	for _, descendant in playerGui:GetDescendants() do
		adoptJumpButton(descendant)
	end
	playerGui.DescendantAdded:Connect(adoptJumpButton)
	return screenGui
end

local function newButton(action: string, title: string, handler: Handler): TextButton
	local button = Instance.new("TextButton")
	button.Name = action
	button.Text = title
	button.Font = Enum.Font.BuilderSansBold
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.TextWrapped = true
	button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	button.BackgroundTransparency = 0.4
	button.AutoButtonColor = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.5
	stroke.Thickness = 2
	stroke.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.1, 0)
	padding.PaddingRight = UDim.new(0.1, 0)
	padding.PaddingTop = UDim.new(0.2, 0)
	padding.PaddingBottom = UDim.new(0.2, 0)
	padding.Parent = button
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 18
	textLimit.Parent = button

	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	button.InputBegan:Connect(function(input)
		if isPress(input) then
			button.BackgroundTransparency = 0.1
			handler(action, Enum.UserInputState.Begin, input)
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) then
			button.BackgroundTransparency = 0.4
			handler(action, Enum.UserInputState.End, input)
		end
	end)
	return button
end

-- Enlaza las teclas con ContextActionService y, en pantallas táctiles, pone el botón en su casilla.
-- Volver a enlazar la misma acción la sustituye.
function ActionButtons.bind(action: string, title: string, handler: Handler, ...: Enum.KeyCode)
	ContextActionService:BindAction(action, handler, false, ...)
	if not UserInputService.TouchEnabled then
		return
	end
	local screenGui = ensureGui()
	local old = buttons[action]
	if old then
		old:Destroy()
	end
	local button = newButton(action, title, handler)
	buttons[action] = button
	button.Parent = screenGui
	layout()
end

-- Cambia el texto de un botón táctil ya puesto (p. ej. la cuenta atrás de una habilidad).
function ActionButtons.setTitle(action: string, title: string)
	local button = buttons[action]
	if button and button.Text ~= title then
		button.Text = title
	end
end

function ActionButtons.unbind(action: string)
	ContextActionService:UnbindAction(action)
	local button = buttons[action]
	if button then
		button:Destroy()
		buttons[action] = nil
	end
end

return ActionButtons
