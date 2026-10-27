--!strict
-- Parcela permanente (Fase 12, Shared/Plot): en el Lobby sale la ventana de bienvenida a quien la tiene y
-- aún no la ha visto (volvió al Lobby sin verla en la Isla, o ya había ganado antes de la Fase 12), tras
-- el calendario y la ceremonia del nido (UI/PlotWelcome).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotWelcome = require(ReplicatedStorage.Shared.UI.PlotWelcome)

local PlotWelcomeController = {}

function PlotWelcomeController:Start()
	PlotWelcome.watch({ "CalendarUI", "EggHatchedUI" })
end

return PlotWelcomeController
