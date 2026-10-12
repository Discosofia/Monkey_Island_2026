--!strict
-- Estado público de la partida: día actual y fase (día o noche).
-- El servidor lo escribe (DayNightService) como atributos de ReplicatedStorage, que Roblox
-- replica solo a todos los clientes. Los clientes lo leen para el reloj y la iluminación.
-- Los tiempos usan Workspace:GetServerTimeNow(), que es el mismo reloj en servidor y clientes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Phase = "Day" | "Night"

export type State = {
	day: number,
	phase: Phase,
	phaseStartedAt: number,
	phaseEndsAt: number,
}

local MatchState = {}

function MatchState.write(state: State)
	ReplicatedStorage:SetAttribute("MatchDay", state.day)
	ReplicatedStorage:SetAttribute("MatchPhase", state.phase)
	ReplicatedStorage:SetAttribute("MatchPhaseStartedAt", state.phaseStartedAt)
	ReplicatedStorage:SetAttribute("MatchPhaseEndsAt", state.phaseEndsAt)
end

-- Devuelve nil si el servidor todavía no ha empezado el ciclo.
function MatchState.read(): State?
	local day = ReplicatedStorage:GetAttribute("MatchDay")
	local phase = ReplicatedStorage:GetAttribute("MatchPhase")
	local startedAt = ReplicatedStorage:GetAttribute("MatchPhaseStartedAt")
	local endsAt = ReplicatedStorage:GetAttribute("MatchPhaseEndsAt")
	if
		typeof(day) ~= "number"
		or (phase ~= "Day" and phase ~= "Night")
		or typeof(startedAt) ~= "number"
		or typeof(endsAt) ~= "number"
	then
		return nil
	end
	return {
		day = day,
		phase = phase,
		phaseStartedAt = startedAt,
		phaseEndsAt = endsAt,
	}
end

return MatchState
