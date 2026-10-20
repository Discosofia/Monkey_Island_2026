--!strict
-- Días del bucle de retención (octubre de 2026): qué día es (cambia a las 00:00 UTC más
-- Config.Daily.ResetOffsetSeconds, igual en todos los servidores) y el estado del calendario de 7 días
-- y las misiones del día. Lo usan el servidor (ServerShared/Retention) y el cliente (la ventana del
-- calendario, la pestaña Misiones y el rastreador de la Isla), con la misma hora (Shared/EggIncubation.now).

local Config = require(script.Parent.Config)
local Missions = require(script.Parent.Data.Missions)

export type LoginState = { lastClaimDay: number, step: number }
export type DailyMission = { id: string, progress: number, done: boolean }
export type MissionState = { day: number, role: string, missions: { DailyMission } }

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

-- Misiones del día (Data/Missions): de qué día y rol son, y cómo va cada una.
function Daily.missionState(raw: any): MissionState
	local state: MissionState = { day = 0, role = "", missions = {} }
	if typeof(raw) ~= "table" then
		return state
	end
	if typeof(raw.day) == "number" then
		state.day = raw.day
	end
	if typeof(raw.role) == "string" then
		state.role = raw.role
	end
	if typeof(raw.missions) == "table" then
		for _, entry in raw.missions do
			if typeof(entry) == "table" and typeof(entry.id) == "string" and Missions[entry.id] then
				table.insert(state.missions, {
					id = entry.id,
					progress = if typeof(entry.progress) == "number" then entry.progress else 0,
					done = entry.done == true,
				})
			end
		end
	end
	return state
end

-- "🐒 Derrota 15 monos".
function Daily.missionText(missionId: string): string
	local mission = Missions[missionId]
	if not mission then
		return missionId
	end
	local text = string.gsub(mission.text, "{target}", tostring(mission.target))
	return `{mission.icon} {text}`
end

return Daily
