--!strict
-- Parcela permanente en la Isla (Fase 12, Shared/Plot): la ventana de bienvenida al desbloquearla, cuando
-- se cierra la de resultados del rescate (UI/PlotWelcome).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotWelcome = require(ReplicatedStorage.Shared.UI.PlotWelcome)

local PlotController = {}

function PlotController:Start()
	PlotWelcome.watch({ "Results" })
end

return PlotController
