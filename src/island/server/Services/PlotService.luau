--!strict
-- Parcela permanente (Fase 12, Shared/Plot) en la Isla.
--   - Se desbloquea al ganar por primera vez: en el amanecer del rescate (resumen con phase "Rescue";
--     en Studio también con una victoria del panel de pruebas, para poder probarlo). Su hueco pasa a
--     ser permanente enseguida y el cliente enseña la ventana de bienvenida (UI/PlotWelcome).
--   - Levantar las estructuras en su hueco lo hace BuildingService.refreshPlot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Plot = require(ReplicatedStorage.Shared.Plot)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(ServerScriptService.ServerShared.Analytics)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local BuildingService = require(script.Parent.BuildingService)
local MatchService = require(script.Parent.MatchService)

local PlotService = {}

local function onMatchEnded(player: Player, summary: MatchService.Summary)
	if summary.phase ~= "Rescue" or (summary.test and not RunService:IsStudio()) then
		return
	end
	local unlocked = false
	PlayerData.update(player, function(profile)
		local state = Plot.normalize(profile.plot)
		if not state.unlocked then
			state.unlocked = true
			profile.plot = state :: any
			unlocked = true
		end
	end)
	if unlocked then
		BuildingService.refreshPlot(player)
		Remotes.Notify:FireClient(player, "🏡 ¡Parcela desbloqueada! Ahora viaja contigo a cada partida")
		Analytics.event(player, "PlotUnlocked", 1)
	end
end

function PlotService:Init()
	MatchService.onMatchEnded(onMatchEnded)
end

return PlotService
