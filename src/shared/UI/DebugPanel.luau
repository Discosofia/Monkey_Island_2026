--!strict
-- Panel de pruebas (solo Studio): un botón "🛠️ Pruebas" abajo a la izquierda que despliega las
-- órdenes de Shared/DebugCommands. En el juego publicado no aparece y el servidor las ignora.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DebugCommands = require(script.Parent.Parent.DebugCommands)
local Remotes = require(script.Parent.Parent.Remotes)
local Widgets = require(script.Parent.Widgets)

local DebugPanel = {}

-- Modo grabación (solo cliente, no se manda al servidor): esconde los ScreenGui del jugador (salvo el panel)
-- y la CoreGui, para grabar vídeos sin HUD. Al volver a pulsar, deja cada cosa como estaba.
local RECORD_MODE = "RecordMode"
local recording = false
local savedGuis: { [ScreenGui]: boolean } = {}
local savedCore: { [Enum.CoreGuiType]: boolean } = {}
local guiConnections: { RBXScriptConnection } = {}

local function hideGui(gui: ScreenGui)
	savedGuis[gui] = gui.Enabled
	gui.Enabled = false
	-- Si el juego vuelve a encender esa pantalla mientras se graba, se apunta su estado y se vuelve a ocultar.
	table.insert(
		guiConnections,
		gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if recording and gui.Enabled then
				savedGuis[gui] = true
				gui.Enabled = false
			end
		end)
	)
end

local function toggleRecordMode(panel: ScreenGui)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local StarterGui = game:GetService("StarterGui")
	recording = not recording
	if recording then
		for _, child in playerGui:GetChildren() do
			if child:IsA("ScreenGui") and child ~= panel then
				hideGui(child)
			end
		end
		table.insert(
			guiConnections,
			playerGui.ChildAdded:Connect(function(child)
				if recording and child:IsA("ScreenGui") and child ~= panel then
					hideGui(child)
				end
			end)
		)
		for _, item in Enum.CoreGuiType:GetEnumItems() do
			if item ~= Enum.CoreGuiType.All then
				savedCore[item] = StarterGui:GetCoreGuiEnabled(item)
			end
		end
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	else
		for _, connection in guiConnections do
			connection:Disconnect()
		end
		guiConnections = {}
		for gui, enabled in savedGuis do
			if gui.Parent then
				gui.Enabled = enabled
			end
		end
		savedGuis = {}
		for item, enabled in savedCore do
			StarterGui:SetCoreGuiEnabled(item, enabled)
		end
		savedCore = {}
	end
end

-- Devuelve la lista de órdenes (nil fuera de Studio), por si el place quiere saber cuándo se abre.
function DebugPanel.start(place: "Island" | "Lobby" | "Dunas" | "Laboratorio"): ScrollingFrame?
	if not RunService:IsStudio() then
		return nil
	end
	local gui = Widgets.screen("DebugPanel", Players.LocalPlayer:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 20

	-- Abajo a la izquierda; en el Lobby, abajo a la derecha (a la izquierda van la barra del menú y
	-- "Invitar amigos").
	local side = if place == "Lobby" then 0.98 else 0.02
	local anchorX = if place == "Lobby" then 1 else 0
	local toggle = Widgets.button("🛠️ Pruebas", gui)
	toggle.AnchorPoint = Vector2.new(anchorX, 1)
	toggle.Position = UDim2.fromScale(side, if place == "Island" then 0.9 else 0.98)
	toggle.Size = UDim2.fromScale(0.14, 0.06)

	local list = Instance.new("ScrollingFrame")
	list.AnchorPoint = Vector2.new(anchorX, 1)
	list.Position = UDim2.fromScale(side, if place == "Island" then 0.83 else 0.91)
	list.Size = UDim2.fromScale(0.22, 0.55)
	list.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	list.BackgroundTransparency = 0.2
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Visible = false
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index, command in DebugCommands[place] do
		local button = Instance.new("TextButton")
		button.LayoutOrder = index
		button.Size = UDim2.new(1, -8, 0, 34)
		button.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.BuilderSansBold
		button.TextScaled = true
		button.Text = command.label
		button.Parent = list
		button.MouseButton1Click:Connect(function()
			if command.id == RECORD_MODE then
				toggleRecordMode(gui)
				return
			end
			Remotes.DebugCommand:FireServer(command.id)
		end)
	end

	toggle.MouseButton1Click:Connect(function()
		list.Visible = not list.Visible
	end)
	return list
end

return DebugPanel
