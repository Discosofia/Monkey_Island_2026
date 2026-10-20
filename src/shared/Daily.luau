--!strict
-- Días del bucle de retención (octubre de 2026): qué día es (cambia a las 00:00 UTC más
-- Config.Daily.ResetOffsetSeconds, igual en todos los servidores) y el estado del calendario de 7 días.
-- Lo usan el servidor (ServerShared/Retention) y el cliente (la ventana del calendario y la pestaña
-- Misiones), con la misma hora (Shared/EggIncubation.now).

local Config = require(script.Parent.Config)

export type LoginState = { lastClaimDay: number, step: number }

local Daily = {}

local DAY = 24 * 60 * 60

Daily.CALENDAR_DAYS = #Config.Daily.Calendar

-- Número del día (cuenta desde 1970) a la hora "now".
function Daily.today(now: number): number
	return (now + Config.Daily.ResetOffsetSeconds) // DAY
end

-- Segundos que faltan para el cambio de día.
function Daily.secondsToReset(now: number): number
	return DAY - (now + Config.Daily.ResetOffsetSeconds) % DAY
end

-- Estado del calendario con la forma correcta (del perfil o del JSON del cliente).
function Daily.loginState(raw: any): LoginState
	local state: LoginState = { lastClaimDay = 0, step = 1 }
	if typeof(raw) == "table" then
		if typeof(raw.lastClaimDay) == "number" then
			state.lastClaimDay = raw.lastClaimDay
		end
		if typeof(raw.step) == "number" and raw.step >= 1 and raw.step <= Daily.CALENDAR_DAYS then
			state.step = raw.step // 1
		end
	end
	return state
end

-- ¿Se puede cobrar hoy? (un premio por día; el que toca es "step").
function Daily.canClaim(state: LoginState, now: number): boolean
	return state.lastClaimDay < Daily.today(now)
end

return Daily
