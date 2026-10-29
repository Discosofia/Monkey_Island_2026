--!strict
-- Botón ⚙️ y ventana de Ajustes de las arenas (Laboratorio y Dunas; Fase 15, V6). Mismo aspecto que el
-- ⚙️ de la Isla (IslandHUDController.createSettingsButton) con el contenido de SettingsPanel en el
-- contexto "Arena": la mira, las opciones, los controles y el temblor/idioma.
--   ArenaSettings.attach(gui, anchorButton, { onOpen, onClose }) crea el botón en "gui", pegado a la
--   izquierda de "anchorButton" y centrado en su alto (lo sigue si el otro se mueve), y devuelve el botón.
--   Una sola columna con desplazamiento (en V6; el reparto en columnas del Lobby no se ha copiado).
--   En una pantalla baja (menos de 500 px de alto, un teléfono) la ventana ocupa casi todo el ancho y el alto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsPanel = require(script.Parent.SettingsPanel)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(script.Parent.Widgets)

local T = Strings.t

-- Pantalla más baja que esto: ventana a todo el alto libre.
local COMPACT_HEIGHT = 500
local SQUARE_COLOR = Color3.fromRGB(40, 34, 28)
local WINDOW_COLOR = Color3.fromRGB(25, 20, 15)
local CLOSE_COLOR = Color3.fromRGB(150, 60, 50)

export type Options = {
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
	-- true en el Laboratorio: sale la fila de recargar en los controles (SettingsPanel).
	laboratory: boolean?,
}

local ArenaSettings = {}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

function ArenaSettings.attach(gui: ScreenGui, anchorButton: GuiObject, options: Options): TextButton
	local gear = Instance.new("TextButton")
	gear.Name = "SettingsButton"
	gear.AnchorPoint = Vector2.new(1, 0.5)
	gear.Size = UDim2.fromOffset(52, 52)
	gear.BackgroundColor3 = SQUARE_COLOR
	gear.BackgroundTransparency = 0.2
	gear.Text = "⚙️"
	gear.TextScaled = true
	gear.Parent = gui
	corner(gear, 12)
	-- Pegado a la izquierda del botón de referencia y centrado en su alto, esté donde esté.
	local function place()
		local position, size = anchorButton.AbsolutePosition, anchorButton.AbsoluteSize
		gear.Position = UDim2.fromOffset(position.X - 6, position.Y + size.Y / 2)
	end
	anchorButton:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	anchorButton:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	-- La ventana va en su propia pantalla, por encima de los botones táctiles (5) y la rueda de emotes (7).
	local windowGui = Widgets.screen("SettingsUI", Players.LocalPlayer:WaitForChild("PlayerGui"))
	windowGui.DisplayOrder = 8
	local window = Instance.new("Frame")
	window.Name = "SettingsWindow"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.BackgroundColor3 = WINDOW_COLOR
	window.BackgroundTransparency = 0.05
	-- Activa: sus clics no atraviesan hasta el juego (disparar).
	window.Active = true
	window.Visible = false
	window.Parent = windowGui
	corner(window, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.Parent = window
	local function fit()
		local compact = windowGui.AbsoluteSize.Y < COMPACT_HEIGHT
		window.Size = if compact then UDim2.fromScale(0.96, 0.98) else UDim2.fromScale(0.8, 0.86)
		limit.MaxSize = if compact then Vector2.new(4096, 4096) else Vector2.new(720, 900)
	end
	windowGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local title = Widgets.label(T("⚙️ Ajustes"), window)
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -80, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(44, 44)
	close.BackgroundColor3 = CLOSE_COLOR
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.BuilderSansExtraBold
	close.TextScaled = true
	-- "X" y no "✕": BuilderSans no tiene ese signo y sale una caja vacía.
	close.Text = "X"
	close.Parent = window
	corner(close, 10)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(10, 58)
	scroll.Size = UDim2.new(1, -20, 1, -68)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	-- El panel se rehace al abrir (y al cambiar de idioma), como el de la Isla.
	local panel: Frame? = nil
	local function setOpen(open: boolean)
		local wasOpen = window.Visible
		window.Visible = open
		if panel then
			panel:Destroy()
			panel = nil
		end
		if open then
			panel = SettingsPanel.build(scroll, "Arena", options.laboratory)
			scroll.CanvasPosition = Vector2.zero
		end
		if open ~= wasOpen then
			local callback = if open then options.onOpen else options.onClose
			if callback then
				callback()
			end
		end
	end
	gear.Activated:Connect(function()
		setOpen(not window.Visible)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	Strings.onChanged(function()
		if window.Visible then
			setOpen(true)
		end
	end)
	return gear
end

return ArenaSettings
