--!strict
-- HUD de la Isla. Fase 0: muestra datos de Config y un botón para volver al Lobby.
-- Fase 1: reloj de día/noche, vida, inventario y barra rápida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local IslandHUDController = {}

function IslandHUDController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Widgets.screen("IslandHUD", playerGui)

	local dayMinutes = Config.Match.DayLengthSeconds / 60
	local nightMinutes = Config.Match.NightLengthSeconds / 60
	local info = Widgets.label(`{Config.GameName}: la Isla\nDía {dayMinutes} min · Noche {nightMinutes} min`, gui)
	info.AnchorPoint = Vector2.new(0, 0)
	info.Position = UDim2.fromScale(0.02, 0.02)
	info.Size = UDim2.fromScale(0.4, 0.1)
	info.TextXAlignment = Enum.TextXAlignment.Left

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

return IslandHUDController
