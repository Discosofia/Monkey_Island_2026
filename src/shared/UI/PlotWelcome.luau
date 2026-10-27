--!strict
-- Ventana de bienvenida a la parcela permanente (Fase 12, Shared/Plot): sale una sola vez, en la Isla o
-- en el Lobby, la primera vez que el jugador tiene la parcela desbloqueada (al ganar, o al entrar si ya
-- había ganado antes de la versión 12 del perfil). Espera a que se cierren las ventanas que tapaba
-- ("blocking": la de resultados, la del calendario) y avisa al servidor (Remotes.PlotWelcomeSeen).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Plot = require(ReplicatedStorage.Shared.Plot)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(script.Parent.Widgets)

local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local GOLD = Color3.fromRGB(255, 205, 70)
local TEXT = Color3.fromRGB(230, 220, 200)
local CHECK_SECONDS = 1

local LINES = {
	"Has ganado: tu parcela del Basecamp es tuya para siempre.",
	"Viaja contigo a cada partida y aparece con tu nombre en uno de los 5 huecos.",
	"En ella irás levantando y mejorando forja, taller, huerto, cama, cofre, incubadora y nido.",
}

local PlotWelcome = {}

local function open(playerGui: PlayerGui)
	local gui = Widgets.screen("PlotWelcome", playerGui)
	gui.DisplayOrder = 8

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(320, 240)
	sizeLimit.MaxSize = Vector2.new(560, 330)
	sizeLimit.Parent = panel

	local title = Widgets.label("🏡 ¡Tienes parcela propia!", panel)
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 10)
	title.Size = UDim2.new(1, -28, 0.16, 0)
	title.TextColor3 = GOLD

	for index, text in LINES do
		local line = Widgets.label(text, panel)
		line.Name = `Line{index}`
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.fromScale(0.5, 0.22 + (index - 1) * 0.19)
		line.Size = UDim2.new(1, -36, 0.17, 0)
		line.Font = Enum.Font.BuilderSans
		line.TextWrapped = true
		line.TextColor3 = TEXT
	end

	local ok = Widgets.button("¡Genial!", panel)
	ok.Name = "Ok"
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -12)
	ok.Size = UDim2.fromScale(0.4, 0.16)
	ok.Activated:Connect(function()
		gui:Destroy()
	end)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = panel
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Remotes.PlotWelcomeSeen:FireServer()
end

-- Vigila el atributo "Plot" del jugador y enseña la ventana cuando toca, sin tapar las ventanas
-- "blocking" (nombres de ScreenGui de PlayerGui).
function PlotWelcome.watch(blocking: { string })
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	task.spawn(function()
		-- Dos comprobaciones seguidas sin nada delante: la ventana de resultados llega casi a la vez que
		-- el desbloqueo y no debe quedar encima.
		local readyChecks = 0
		while true do
			local state = Plot.of(player)
			if state.noticeShown then
				return
			end
			local blocked = false
			for _, name in blocking do
				if playerGui:FindFirstChild(name) then
					blocked = true
				end
			end
			readyChecks = if state.unlocked and not blocked then readyChecks + 1 else 0
			if readyChecks >= 2 then
				open(playerGui)
				return
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return PlotWelcome
