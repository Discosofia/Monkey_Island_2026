--!strict
-- HUD de la Isla: reloj de día/noche, indicador del Basecamp y botón para volver al Lobby.
-- En Studio también muestra un botón para saltar de fase y probar la noche sin esperar.
-- Fase 1.2+: vida, inventario y barra rápida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local SAFE_COLOR = Color3.fromRGB(120, 230, 140)
local DANGER_COLOR = Color3.fromRGB(255, 170, 60)

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
	clock.AnchorPoint = Vector2.new(0.5, 0)
	clock.Position = UDim2.fromScale(0.5, 0.02)
	clock.Size = UDim2.fromScale(0.3, 0.06)

	task.spawn(function()
		while clock.Parent do
			local state = MatchState.read()
			clock.Text = if state then clockText(state, Workspace:GetServerTimeNow()) else ""
			task.wait(0.25)
		end
	end)
end

local function createBasecampIndicator(gui: ScreenGui)
	local player = Players.LocalPlayer
	local indicator = Widgets.label("", gui)
	indicator.Name = "BasecampIndicator"
	indicator.AnchorPoint = Vector2.new(0.5, 0)
	indicator.Position = UDim2.fromScale(0.5, 0.085)
	indicator.Size = UDim2.fromScale(0.3, 0.04)

	local function refresh()
		local inBasecamp = player:GetAttribute("InBasecamp")
		if inBasecamp == nil then
			indicator.Text = ""
		elseif inBasecamp then
			indicator.Text = "🏕️ Basecamp: zona segura"
			indicator.TextColor3 = SAFE_COLOR
		else
			indicator.Text = "⚠️ Fuera del Basecamp"
			indicator.TextColor3 = DANGER_COLOR
		end
	end

	player:GetAttributeChangedSignal("InBasecamp"):Connect(refresh)
	refresh()
end

local function createReturnButton(gui: ScreenGui)
	local returnButton = Widgets.button("Volver al Lobby", gui)
	returnButton.Name = "ReturnToLobbyButton"
	returnButton.AnchorPoint = Vector2.new(1, 0)
	returnButton.Position = UDim2.fromScale(0.98, 0.02)
	returnButton.Size = UDim2.fromScale(0.22, 0.08)

	local waiting = false
	returnButton.Activated:Connect(function()
		if waiting then
			return
		end
		waiting = true
		returnButton.Text = "Viajando..."
		Remotes.RequestReturnToLobby:FireServer()

		task.delay(Config.Teleport.CooldownSeconds, function()
			waiting = false
			returnButton.Text = "Volver al Lobby"
		end)
	end)
end

function IslandHUDController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Widgets.screen("IslandHUD", playerGui)

	createClock(gui)
	createBasecampIndicator(gui)
	createReturnButton(gui)

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
