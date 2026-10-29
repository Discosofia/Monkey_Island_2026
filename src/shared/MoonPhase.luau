--!strict
-- Fase de la luna de la Isla (Fase 18, B2). DayNightService escribe el atributo "MoonPhase" (el id de la
-- fase) en ReplicatedStorage; los servicios y el cliente lo leen aquí. Los números están en Config.Moon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Phase = typeof(Config.Moon.Phases[1])

local MoonPhase = {}

-- Posición (1 a #Phases) de la fase que toca el día de partida "day".
function MoonPhase.indexForDay(day: number): number
	local count = #Config.Moon.Phases
	return math.floor((math.max(day, 1) - 1) / Config.Moon.DaysPerPhase) % count + 1
end

function MoonPhase.idForDay(day: number): string
	return Config.Moon.Phases[MoonPhase.indexForDay(day)].id
end

-- La fase actual según el atributo; nil si el servidor aún no lo ha escrito.
function MoonPhase.current(): Phase?
	local id = ReplicatedStorage:GetAttribute("MoonPhase")
	if typeof(id) ~= "string" then
		return nil
	end
	for _, phase in Config.Moon.Phases do
		if phase.id == id then
			return phase
		end
	end
	return nil
end

-- Multiplicador de un efecto en la fase actual (1 si la fase no lo toca).
function MoonPhase.effect(key: string): number
	local phase = MoonPhase.current()
	local effects = if phase then phase.effects :: { [string]: number } else nil
	return if effects and effects[key] then effects[key] else 1
end

return MoonPhase
