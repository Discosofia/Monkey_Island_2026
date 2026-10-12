--!strict
-- Interfaz del Lobby. Fase 0: título del juego y botón para viajar a la Isla.
-- Fase 3: selección de rol, tienda de mejoras y mascota activa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local LobbyUIController = {}

function LobbyUIController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Widgets.screen("LobbyUI", playerGui)

	local title = Widgets.label(Config.GameName, gui)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.02)
	title.Size = UDim2.fromScale(0.8, 0.09)

	local subtitle = Widgets.label(Config.Subtitle, gui)
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.fromScale(0.5, 0.11)
	subtitle.Size = UDim2.fromScale(0.5, 0.045)
	subtitle.TextColor3 = Color3.fromRGB(242, 178, 36)

	local joinButton = Widgets.button("Ir a la Isla", gui)
	joinButton.Name = "JoinIslandButton"
	joinButton.AnchorPoint = Vector2.new(0.5, 1)
	joinButton.Position = UDim2.fromScale(0.5, 0.92)
	joinButton.Size = UDim2.fromScale(0.3, 0.1)

	local waiting = false
	joinButton.Activated:Connect(function()
		if waiting then
			return
		end
		waiting = true
		joinButton.Text = "Viajando..."
		Remotes.RequestJoinIsland:FireServer()

		-- Si el viaje no ocurre (por ejemplo en Studio), el botón vuelve a estar disponible.
		task.delay(Config.Teleport.CooldownSeconds, function()
			waiting = false
			joinButton.Text = "Ir a la Isla"
		end)
	end)
end

return LobbyUIController
