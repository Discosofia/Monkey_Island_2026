--!strict
-- HUD de la Isla: reloj de día/noche e indicador del Basecamp (arriba a la derecha), vida del
-- campamento (arriba en el centro, de noche o si está dañado), botón para volver al Lobby (pide un
-- segundo toque: salir pierde lo de la isla) y botón ⚙️ de Ajustes (abajo a la derecha; en pantallas
-- táctiles, bajo el reloj, porque abajo a la derecha están el salto y los botones de acción) y, a la
-- izquierda del ⚙️, el botón 😀 de la rueda de emotes (UI/EmoteWheel).
-- En Studio también muestra un botón para saltar de fase y probar la noche sin esperar.
-- Fase 1.2+: vida, inventario y barra rápida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Basecamp = require(ReplicatedStorage.Shared.Basecamp)
local Config = require(ReplicatedStorage.Shared.Config)
local EmoteWheel = require(ReplicatedStorage.Shared.UI.EmoteWheel)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SettingsPanel = require(ReplicatedStorage.Shared.UI.SettingsPanel)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local SAFE_COLOR = Color3.fromRGB(120, 230, 140)
local DANGER_COLOR = Color3.fromRGB(255, 170, 60)
local FALLEN_COLOR = Color3.fromRGB(235, 70, 60)
local HEALTHY_COLOR = Color3.fromRGB(90, 230, 110)
-- "Volver al Lobby": dorado como todo botón; rojo de cerrar mientras pide confirmación.
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local READY_TEXT = Color3.fromRGB(40, 25, 5)
local LEAVE_COLOR = Color3.fromRGB(150, 60, 50)
-- Segundos que espera el segundo toque de "Volver al Lobby" antes de volver a su texto.
local CONFIRM_SECONDS = 4

local IslandHUDController = {}

local function formatTime(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(total / 60), total % 60)
end

local function clockText(state: MatchState.State, now: number): string
	local icon = if state.phase == "Day" then "☀️" else "🌙"
	return `Día {state.day} · {icon} {formatTime(state.phaseEndsAt - now)}`
end

local function createClock(gui: ScreenGui)
	local clock = Widgets.label("", gui)
	clock.Name = "Clock"
	clock.AnchorPoint = Vector2.new(1, 0)
	clock.Position = UDim2.fromScale(0.98, 0.02)
	clock.Size = UDim2.fromScale(0.3, 0.06)
	clock.TextXAlignment = Enum.TextXAlignment.Right

	task.spawn(function()
		while clock.Parent do
			local state = MatchState.read()
			clock.Text = if state then clockText(state, Workspace:GetServerTimeNow()) else ""
			task.wait(0.25)
		end
	end)
end

-- Línea de estado arriba en el centro, leída de un atributo de ReplicatedStorage:
-- el asedio nocturno (Fase 2.5) y el huevo (Fase 5).
local function createStatusLine(gui: ScreenGui, attribute: string, y: number, color: Color3)
	local label = Widgets.label("", gui)
	label.Name = attribute
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.fromScale(0.34, 0.035)
	label.TextColor3 = color
	local function refresh()
		local status = ReplicatedStorage:GetAttribute(attribute)
		label.Text = if typeof(status) == "string" then status else ""
	end
	ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(refresh)
	refresh()
end

local function createBasecampIndicator(gui: ScreenGui)
	local player = Players.LocalPlayer
	local indicator = Widgets.label("", gui)
	indicator.Name = "BasecampIndicator"
	indicator.AnchorPoint = Vector2.new(1, 0)
	indicator.Position = UDim2.fromScale(0.98, 0.085)
	indicator.Size = UDim2.fromScale(0.3, 0.04)
	indicator.TextXAlignment = Enum.TextXAlignment.Right

	local function refresh()
		local inBasecamp = player:GetAttribute("InBasecamp")
		if inBasecamp == nil then
			indicator.Text = ""
		elseif inBasecamp and Basecamp.isFallen() then
			indicator.Text = "🔥 Basecamp caído: no es zona segura"
			indicator.TextColor3 = FALLEN_COLOR
		elseif inBasecamp then
			indicator.Text = "🏕️ Basecamp: zona segura"
			indicator.TextColor3 = SAFE_COLOR
		else
			indicator.Text = "⚠️ Fuera del Basecamp"
			indicator.TextColor3 = DANGER_COLOR
		end
	end

	player:GetAttributeChangedSignal("InBasecamp"):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(Basecamp.FALLEN):Connect(refresh)
	refresh()
end

-- Vida del campamento (Shared/Basecamp) arriba en el centro, en la franja libre entre las barras de
-- la izquierda y el reloj (encima de la línea del asedio, a 0.13). Se ve de noche, si no está
-- entero o si ha caído.
local function createBasecampHealth(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "BasecampHealth"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.02)
	frame.Size = UDim2.fromOffset(240, 30)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui

	local label = Widgets.label("", frame)
	label.Size = UDim2.new(1, 0, 0, 18)

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 20)
	back.Size = UDim2.new(1, 0, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BackgroundTransparency = 0.35
	back.BorderSizePixel = 0
	back.Parent = frame
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 6)
	backCorner.Parent = back
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	task.spawn(function()
		while frame.Parent do
			local health, maxHealth = Basecamp.health()
			local state = MatchState.read()
			if health and maxHealth then
				local fraction = math.clamp(health / maxHealth, 0, 1)
				local fallen = Basecamp.isFallen()
				local night = state ~= nil and state.phase == "Night"
				frame.Visible = night or fallen or fraction < 1
				-- Corto para que se lea en un teléfono; el indicador de la derecha ya dice que no es zona segura.
				label.Text = if fallen then "🔥 ¡Campamento caído!" else `🏕️ Campamento {health}/{maxHealth}`
				label.TextColor3 = if fallen then FALLEN_COLOR else Color3.new(1, 1, 1)
				fill.Size = UDim2.fromScale(fraction, 1)
				fill.BackgroundColor3 = if fallen or fraction < 0.25
					then FALLEN_COLOR
					elseif fraction < 0.5 then DANGER_COLOR
					else HEALTHY_COLOR
			else
				frame.Visible = false
			end
			task.wait(0.25)
		end
	end)
end

local function createReturnButton(gui: ScreenGui): TextButton
	local returnButton = Widgets.button("Volver al Lobby", gui)
	returnButton.Name = "ReturnToLobbyButton"
	returnButton.Size = UDim2.fromScale(0.22, 0.08)
	if UserInputService.TouchEnabled then
		-- Justo debajo del indicador del Basecamp (0.085 + 0.04).
		returnButton.AnchorPoint = Vector2.new(1, 0)
		returnButton.Position = UDim2.new(0.98, 0, 0.125, 8)
	else
		returnButton.AnchorPoint = Vector2.new(1, 1)
		returnButton.Position = UDim2.fromScale(0.98, 0.98)
	end

	-- Salir pierde todo lo de la isla: el primer toque pide confirmación (en rojo) y solo el segundo,
	-- antes de CONFIRM_SECONDS, viaja. Un clic perdido ya no te saca de la partida.
	local waiting = false
	local confirming = 0
	local function reset()
		confirming = 0
		returnButton.Text = "Volver al Lobby"
		returnButton.BackgroundColor3 = READY_COLOR
		returnButton.TextColor3 = READY_TEXT
	end
	returnButton.Activated:Connect(function()
		if waiting then
			return
		end
		if confirming == 0 then
			confirming += 1
			local attempt = confirming
			returnButton.Text = "¿Salir? Pierdes todo"
			Toast.show("⚠️ Si vuelves al Lobby pierdes lo que llevas de la isla. Toca otra vez para salir")
			returnButton.BackgroundColor3 = LEAVE_COLOR
			returnButton.TextColor3 = Color3.new(1, 1, 1)
			task.delay(CONFIRM_SECONDS, function()
				if confirming == attempt and not waiting then
					reset()
				end
			end)
			return
		end
		reset()
		waiting = true
		returnButton.Text = "Viajando..."
		Remotes.RequestReturnToLobby:FireServer()

		task.delay(Config.Teleport.CooldownSeconds, function()
			waiting = false
			reset()
		end)
	end)
	return returnButton
end

-- Botón ⚙️ a la izquierda de "Volver al Lobby": abre los Ajustes (UI/SettingsPanel) en una ventana. Se
-- construye cada vez que se abre, para que enseñe el arma y las ventajas de ese momento.
local function createSettingsButton(gui: ScreenGui, returnButton: TextButton): TextButton
	local gear = Instance.new("TextButton")
	gear.Name = "SettingsButton"
	gear.AnchorPoint = Vector2.new(1, 0.5)
	gear.Size = UDim2.fromOffset(52, 52)
	gear.BackgroundColor3 = Color3.fromRGB(40, 34, 28)
	gear.BackgroundTransparency = 0.2
	gear.Text = "⚙️"
	gear.TextScaled = true
	gear.Parent = gui
	local gearCorner = Instance.new("UICorner")
	gearCorner.CornerRadius = UDim.new(0, 12)
	gearCorner.Parent = gear
	-- Pegado a la izquierda del botón de volver y centrado en su alto, esté donde esté (su sitio y su
	-- tamaño dependen de la pantalla y de si es táctil).
	local function place()
		local position, size = returnButton.AbsolutePosition, returnButton.AbsoluteSize
		gear.Position = UDim2.fromOffset(position.X - 6, position.Y + size.Y / 2)
	end
	returnButton:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	returnButton:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	-- La ventana va en su propia pantalla, por encima de los botones táctiles (5), la mesa de
	-- fabricación (5) y el diario (6), y por debajo de los avisos (10).
	local windowGui = Widgets.screen("SettingsUI", gui.Parent :: Instance)
	windowGui.DisplayOrder = 8
	local window = Instance.new("Frame")
	window.Name = "SettingsWindow"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.8, 0.86)
	window.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
	window.BackgroundTransparency = 0.05
	window.Visible = false
	window.Parent = windowGui
	local windowCorner = Instance.new("UICorner")
	windowCorner.CornerRadius = UDim.new(0, 14)
	windowCorner.Parent = window
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(720, 900)
	limit.Parent = window

	local title = Widgets.label("⚙️ Ajustes", window)
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -80, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(44, 44)
	close.BackgroundColor3 = Color3.fromRGB(150, 60, 50)
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.BuilderSansExtraBold
	close.TextScaled = true
	-- "X" y no "✕": BuilderSans no tiene ese signo y sale una caja vacía.
	close.Text = "X"
	close.Parent = window
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 10)
	closeCorner.Parent = close

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

	local panel: Frame? = nil
	local function setOpen(open: boolean)
		window.Visible = open
		if panel then
			panel:Destroy()
			panel = nil
		end
		if open then
			panel = SettingsPanel.build(scroll, "Island")
		end
	end
	gear.Activated:Connect(function()
		setOpen(not window.Visible)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	-- Otro idioma (elegido en este mismo panel): se rehace en él.
	Strings.onChanged(function()
		if window.Visible then
			setOpen(true)
		end
	end)
	return gear
end

-- Botón 😀 de la rueda de emotes, pegado a la izquierda del ⚙️ como este al de volver.
local function createEmoteButton(gui: ScreenGui, gear: TextButton)
	local button = EmoteWheel.button(gui)
	button.AnchorPoint = Vector2.new(1, 0.5)
	local function place()
		local position, size = gear.AbsolutePosition, gear.AbsoluteSize
		button.Position = UDim2.fromOffset(position.X - 6, position.Y + size.Y / 2)
	end
	gear:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	gear:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
	EmoteWheel.start()
end

function IslandHUDController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Widgets.screen("IslandHUD", playerGui)

	createClock(gui)
	createBasecampIndicator(gui)
	createBasecampHealth(gui)
	createStatusLine(gui, "SiegeStatus", 0.13, Color3.fromRGB(255, 120, 90))
	createStatusLine(gui, "EggStatus", 0.24, Color3.fromRGB(150, 240, 255))
	createStatusLine(gui, "BeaconStatus", 0.275, Color3.fromRGB(255, 150, 140))
	-- Evento de mitad de partida (G7, MidEventService): el de ahora o, de noche, el de mañana.
	createStatusLine(gui, "MidEventStatus", 0.31, Color3.fromRGB(215, 170, 255))
	createEmoteButton(gui, createSettingsButton(gui, createReturnButton(gui)))

	if RunService:IsStudio() then
		local skipButton = Widgets.button("⏩ Saltar fase (Studio)", gui)
		skipButton.Name = "DebugSkipPhaseButton"
		skipButton.AnchorPoint = Vector2.new(0, 1)
		skipButton.Position = UDim2.fromScale(0.02, 0.98)
		skipButton.Size = UDim2.fromScale(0.2, 0.07)
		skipButton.BackgroundColor3 = Color3.fromRGB(90, 90, 110)
		skipButton.TextColor3 = Color3.new(1, 1, 1)
		skipButton.Activated:Connect(function()
			Remotes.DebugSkipPhase:FireServer()
		end)
	end
end

return IslandHUDController
