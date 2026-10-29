--!strict
-- Espectador de la arena de Dunas (Fase 15, V10): quien cae en plena partida (también en muerte súbita) y
-- espera su "RespawnAt" mira primero, Config.Arena.KillcamSeconds, a quien lo derribó, y después a sus
-- aliados en pie (◀ ▶ para cambiar). Sin aliados, vista fija desde arriba del centro de la arena. La cámara,
-- la ficha y la barra son de CombatClient/SpectateCamera; al reaparecer se restaura la cámara.
-- Dunas usa la cámara estándar de Roblox y no suelta el ratón: no hay primera persona que lo bloquee.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local SpectateCamera = require(ReplicatedStorage.CombatClient.SpectateCamera)

local ArenaSpectateController = {}

function ArenaSpectateController:Start()
	local player = Players.LocalPlayer
	local settings = Config.Arena
	SpectateCamera.new({
		guiName = "ArenaSpectate",
		distance = settings.SpectateDistance,
		killcamSeconds = settings.KillcamSeconds,
		candidates = function()
			return SpectateCamera.allies(player)
		end,
		-- Justo encima del centro: no hay techo que ocultar y la altura abarca la arena entera.
		overhead = function()
			return settings.SpectateOverheadCenter, settings.SpectateOverheadHeight, 0
		end,
		wantsSpectate = function()
			local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
			return Arena.inBattle()
				and typeof(player:GetAttribute("RespawnAt")) == "number"
				and humanoid ~= nil
				and humanoid.Health <= 0
		end,
	}):Start()
end

return ArenaSpectateController
