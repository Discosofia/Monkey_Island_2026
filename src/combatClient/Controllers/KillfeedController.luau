--!strict
-- Registro de bajas (Fase 19, W9; servidor en Combat/Killfeed). Escucha Remotes.Killfeed y lo dibuja con
-- Shared/UI/Killfeed arriba a la derecha, debajo de los marcadores de cada place. Capa baja (3): no tapa nada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Killfeed = require(ReplicatedStorage.Shared.UI.Killfeed)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local KillfeedController = {}

function KillfeedController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Widgets.screen("Killfeed", playerGui)
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 3
	local feed = Killfeed.mount(gui)

	Remotes.Killfeed.OnClientEvent:Connect(function(entry: any)
		if typeof(entry) ~= "table" or typeof(entry.victim) ~= "string" then
			return
		end
		feed.add({
			killer = if typeof(entry.killer) == "string" then entry.killer else nil,
			killerId = if typeof(entry.killerId) == "number" then entry.killerId else nil,
			victim = entry.victim,
			victimId = if typeof(entry.victimId) == "number" then entry.victimId else nil,
			weaponId = if typeof(entry.weaponId) == "string" then entry.weaponId else nil,
			zone = if typeof(entry.zone) == "string" then entry.zone else nil,
			boss = entry.boss == true,
		})
	end)
end

return KillfeedController
