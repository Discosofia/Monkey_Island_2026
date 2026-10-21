--!strict
-- Días del bucle de retención (octubre de 2026): qué día y qué semana es (cambian a las 00:00 UTC más
-- Config.Daily.ResetOffsetSeconds, igual en todos los servidores; la semana, el lunes) y el estado del
-- calendario de 7 días, las misiones del día y las de la semana. Lo usan el servidor (ServerShared/Retention) y el cliente (la ventana del
-- calendario, la pestaña Misiones y el rastreador de la Isla), con la misma hora (Shared/EggIncubation.now).

local Config = require(script.Parent.Config)
local Missions = require(script.Parent.Data.Missions)

export type LoginState = { lastClaimDay: number, step: number }
-- "seen": lo ya contado de las misiones "distinct" (especies de mono).
export type DailyMission = { id: string, progress: number, done: boolean, seen: { string }? }
-- "rerolls": cambios gratis ya usados hoy.
export type MissionState = { day: number, role: string, missions: { DailyMission }, rerolls: number }
-- "bonus": ya se entregó el extra por cumplirlas todas.
export type WeeklyState = { week: number, missions: { DailyMission }, rerolls: number, bonus: boolean }

local Daily = {}

local DAY = 24 * 60 * 60
-- El día 0 (1-1-1970) fue jueves: con este desfase, las semanas empiezan el lunes.
local MONDAY_OFFSET = 3

Daily.CALENDAR_DAYS = #Config.Daily.Calendar

-- Número del día (cuenta desde 1970) a la hora "now".
function Daily.today(now: number): number
	return (now + Config.Daily.ResetOffsetSeconds) // DAY
end

-- Segundos que faltan para el cambio de día.
function Daily.secondsToReset(now: number): number
	return DAY - (now + Config.Daily.ResetOffsetSeconds) % DAY
end

-- Número de la semana (empieza el lunes) a la hora "now".
function Daily.week(now: number): number
	return (Daily.today(now) + MONDAY_OFFSET) // 7
end

-- Segundos que faltan para el cambio de semana.
function Daily.secondsToWeekReset(now: number): number
	local dayInWeek = (Daily.today(now) + MONDAY_OFFSET) % 7
	return (6 - dayInWeek) * DAY + Daily.secondsToReset(now)
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

local function missionList(raw: any): { DailyMission }
	local list: { DailyMission } = {}
	if typeof(raw) ~= "table" then
		return list
	end
	for _, entry in raw do
		if typeof(entry) == "table" and typeof(entry.id) == "string" and Missions[entry.id] then
			local seen: { string }? = nil
			if typeof(entry.seen) == "table" then
				local keys: { string } = {}
				for _, key in entry.seen do
					if typeof(key) == "string" then
						table.insert(keys, key)
					end
				end
				seen = keys
			end
			table.insert(list, {
				id = entry.id,
				progress = if typeof(entry.progress) == "number" then entry.progress else 0,
				done = entry.done == true,
				seen = seen,
			})
		end
	end
	return list
end

-- Misiones del día (Data/Missions): de qué día y rol son, cómo va cada una y los cambios usados.
function Daily.missionState(raw: any): MissionState
	local state: MissionState = { day = 0, role = "", missions = {}, rerolls = 0 }
	if typeof(raw) ~= "table" then
		return state
	end
	if typeof(raw.day) == "number" then
		state.day = raw.day
	end
	if typeof(raw.role) == "string" then
		state.role = raw.role
	end
	if typeof(raw.rerolls) == "number" then
		state.rerolls = raw.rerolls
	end
	state.missions = missionList(raw.missions)
	return state
end

-- Misiones de la semana: de qué semana son, cómo va cada una, los cambios usados y si ya se cobró el
-- extra por cumplirlas todas.
function Daily.weeklyState(raw: any): WeeklyState
	local state: WeeklyState = { week = 0, missions = {}, rerolls = 0, bonus = false }
	if typeof(raw) ~= "table" then
		return state
	end
	if typeof(raw.week) == "number" then
		state.week = raw.week
	end
	if typeof(raw.rerolls) == "number" then
		state.rerolls = raw.rerolls
	end
	state.bonus = raw.bonus == true
	state.missions = missionList(raw.missions)
	return state
end

-- ¿Están todas cumplidas? (falso si no hay ninguna).
function Daily.allDone(missions: { DailyMission }): boolean
	for _, mission in missions do
		if not mission.done then
			return false
		end
	end
	return #missions > 0
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
