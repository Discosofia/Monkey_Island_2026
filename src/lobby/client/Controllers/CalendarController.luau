--!strict
-- Ventana del calendario de 7 días al entrar al Lobby (bucle de retención, octubre de 2026): si hoy
-- hay premio por cobrar, sale una vez con las casillas (UI/CalendarStrip), lo que da el de hoy y el
-- botón Cobrar. Al cobrar enseña lo recibido y se cierra sola. Lo mismo está en la pestaña Misiones
-- (LobbyUIController), que también enseña los premios cobrados aquí (Remotes.LoginClaimed).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Daily = require(ReplicatedStorage.Shared.Daily)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local CalendarStrip = require(ReplicatedStorage.Shared.UI.CalendarStrip)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local CLOSE_COLOR = Color3.fromRGB(150, 60, 50)
local GOLD = Color3.fromRGB(255, 205, 70)
local TEXT = Color3.fromRGB(230, 220, 200)
local CLOSE_AFTER_CLAIM_SECONDS = 5

local CalendarController = {}

local player = Players.LocalPlayer

local function readLogin(): Daily.LoginState?
	local raw = player:GetAttribute("Retention")
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return Daily.loginState(if ok and typeof(decoded) == "table" then decoded.login else nil)
end

local window: ScreenGui? = nil

local function close()
	if window then
		window:Destroy()
		window = nil
	end
end

local function open(state: Daily.LoginState)
	close()
	local gui = Widgets.screen("CalendarUI", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 7
	window = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromScale(0.62, 0.66)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(320, 260)
	sizeLimit.MaxSize = Vector2.new(640, 440)
	sizeLimit.Parent = panel

	local title = Widgets.label(`📅 Premio diario · día {state.step} de {Daily.CALENDAR_DAYS}`, panel)
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -76, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local closeButton = Widgets.button("X", panel)
	closeButton.Font = Enum.Font.BuilderSansExtraBold
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -8, 0, 6)
	closeButton.Size = UDim2.fromOffset(44, 44)
	closeButton.BackgroundColor3 = CLOSE_COLOR
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	local closeLimit = closeButton:FindFirstChildOfClass("UISizeConstraint")
	if closeLimit then
		closeLimit.MinSize = Vector2.new(44, 44)
	end
	closeButton.Activated:Connect(close)

	local stripHolder = Instance.new("Frame")
	stripHolder.Name = "Strip"
	stripHolder.BackgroundTransparency = 1
	stripHolder.Position = UDim2.fromOffset(12, 56)
	stripHolder.Size = UDim2.new(1, -24, 0.56, -56)
	stripHolder.Parent = panel
	CalendarStrip.build(stripHolder, state, EggIncubation.now())

	local today = Widgets.label(`Hoy: {Rewards.describe(Config.Daily.Calendar[state.step])}`, panel)
	today.Name = "Today"
	today.AnchorPoint = Vector2.new(0.5, 0)
	today.Position = UDim2.fromScale(0.5, 0.6)
	today.Size = UDim2.fromScale(0.92, 0.14)
	today.TextWrapped = true
	today.TextColor3 = GOLD

	local hint = Widgets.label("Entra cada día: si faltas, no pierdes nada y sigues por donde ibas", panel)
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.fromScale(0.5, 0.74)
	hint.Size = UDim2.fromScale(0.92, 0.07)
	hint.Font = Enum.Font.BuilderSans
	hint.TextColor3 = TEXT

	local claim = Widgets.button("Cobrar", panel)
	claim.Name = "Claim"
	claim.AnchorPoint = Vector2.new(0.5, 1)
	claim.Position = UDim2.new(0.5, 0, 1, -12)
	claim.Size = UDim2.fromScale(0.45, 0.13)
	local claiming = false
	claim.Activated:Connect(function()
		if claiming then
			return
		end
		claiming = true
		claim.Text = "Cobrando…"
		Remotes.ClaimLogin:FireServer()
	end)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = panel
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Premio cobrado: la ventana (si está abierta) enseña lo recibido y se cierra sola.
local function showClaimed(day: number, lines: { string })
	local gui = window
	if not gui then
		return
	end
	local panel = gui:FindFirstChildOfClass("Frame")
	if not panel then
		return
	end
	local today = panel:FindFirstChild("Today")
	if today and today:IsA("TextLabel") then
		today.Text = `🎉 ¡Día {day} cobrado! {table.concat(lines, " · ")}`
	end
	local hint = panel:FindFirstChild("Hint")
	if hint and hint:IsA("TextLabel") then
		hint.Text = "Vuelve mañana a por el siguiente"
	end
	local claim = panel:FindFirstChild("Claim")
	if claim and claim:IsA("TextButton") then
		claim.Text = "¡Genial!"
		claim.Activated:Connect(close)
	end
	-- Las casillas, con el día recién cobrado ya marcado (el perfil llega justo después del aviso).
	local strip = panel:FindFirstChild("Strip")
	task.delay(0.3, function()
		local state = readLogin()
		if state and strip and strip:IsA("Frame") and strip.Parent then
			strip:ClearAllChildren()
			CalendarStrip.build(strip, state, EggIncubation.now())
		end
	end)
	task.delay(CLOSE_AFTER_CLAIM_SECONDS, function()
		if window == gui then
			close()
		end
	end)
end

function CalendarController:Start()
	Remotes.LoginClaimed.OnClientEvent:Connect(function(day: any, lines: any)
		if typeof(day) == "number" and typeof(lines) == "table" then
			showClaimed(day, lines)
		end
	end)
	-- Una vez al entrar, cuando llegan los datos del perfil.
	local state = readLogin()
	while not state and player.Parent do
		player:GetAttributeChangedSignal("Retention"):Wait()
		state = readLogin()
	end
	if state and Daily.canClaim(state, EggIncubation.now()) then
		open(state)
	end
end

return CalendarController
