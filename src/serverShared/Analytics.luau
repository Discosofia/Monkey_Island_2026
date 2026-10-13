--!strict
-- Analítica (Fase 6) con AnalyticsService de Roblox: embudo del tutorial, economía del Ámbar y
-- eventos de partida. Los datos se ven en el Creator Hub → tu experiencia → Analítica.
-- Todo va protegido con pcall: si falla, el juego sigue igual.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local function safely(name: string, action: () -> ())
	local ok, err = pcall(function()
		action()
	end)
	if not ok then
		warn(`[Analytics] {name}: {err}`)
	end
end

-- Paso del tutorial (embudo de incorporación). Los pasos empiezan en 1.
function Analytics.tutorialStep(player: Player, step: number, name: string)
	safely("tutorialStep", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

-- Ámbar ganado ("Source") o gastado ("Sink").
function Analytics.amber(player: Player, flow: "Source" | "Sink", amount: number, balance: number, reason: string)
	if amount <= 0 then
		return
	end
	safely("amber", function()
		AnalyticsService:LogEconomyEvent(
			player,
			if flow == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			"Amber",
			amount,
			balance,
			if flow == "Source"
				then Enum.AnalyticsEconomyTransactionType.Gameplay.Name
				else Enum.AnalyticsEconomyTransactionType.Shop.Name,
			reason
		)
	end)
end

-- Evento propio con un valor (p. ej. "MatchDefeat" con los días sobrevividos).
function Analytics.event(player: Player, name: string, value: number?)
	safely("event", function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

return Analytics
