--!strict
-- Bienvenida de pioneros (T6, 27-10-2026): las cuentas que comparten el servidor (ServerShared/
-- PlayerData marca al pionero al cargar, ServerShared/Retention hace la tirada) y el cliente (la ventana
-- de bienvenida del Lobby, CalendarController). Sin efectos.
--   - Es pionero quien entra antes de que acabe la primera temporada del pase (Data/Seasons; la fecha
--     se mueve sola con la de la T1). Queda marcado para siempre ("since").
--   - Cada vez que cobra el día 7 del calendario (un ciclo) tiene una tirada de montura
--     (PetRoll.rollPioneer, Config.Pioneer.Weights). "cycles" cuenta las cobradas.
--   - "welcomeAt": la última vez que vio la ventana (para no repetirla al volver de una partida).

local Config = require(script.Parent.Config)
local Daily = require(script.Parent.Daily)
local Mounts = require(script.Parent.Data.Mounts)
local SeasonPass = require(script.Parent.SeasonPass)
local Seasons = require(script.Parent.Data.Seasons)

-- Lo que se guarda en el perfil ("pioneer") y se publica al cliente (atributo "Pioneer").
export type State = {
	since: number, -- hora en que quedó marcado (0 = no es pionero)
	cycles: number,
	welcomeAt: number,
}

-- Lo que sale de una tirada: la montura y el Ámbar si ya la tenía (0 si es nueva).
export type Roll = { mount: string, amber: number }

local Pioneer = {}

-- Fin de la primera temporada: quien entra antes es pionero.
function Pioneer.deadline(): number
	local first = Seasons[1]
	return if first then SeasonPass.endsAt(first) else 0
end

function Pioneer.normalize(raw: any): State
	local state: State = { since = 0, cycles = 0, welcomeAt = 0 }
	if typeof(raw) == "table" then
		for key in state :: any do
			local value = raw[key]
			if typeof(value) == "number" and value >= 0 then
				(state :: any)[key] = value // 1
			end
		end
	end
	return state
end

function Pioneer.isPioneer(state: State): boolean
	return state.since > 0
end

-- Cobros del calendario que faltan para la próxima tirada, contando el de hoy si aún no lo ha cobrado
-- (1 = la de hoy o la de la próxima vez que cobre el día 7).
function Pioneer.claimsToRoll(login: Daily.LoginState): number
	return Daily.CALENDAR_DAYS - login.step + 1
end

-- ¿Sale la ventana al entrar al Lobby? Si hay que cobrar, siempre; si no, solo a los pioneros y si
-- hace Config.Pioneer.WelcomeGapMinutes desde la última vez.
function Pioneer.shouldWelcome(state: State, login: Daily.LoginState, now: number): boolean
	if Daily.canClaim(login, now) then
		return true
	end
	return Pioneer.isPioneer(state) and now - state.welcomeAt >= Config.Pioneer.WelcomeGapMinutes * 60
end

-- Probabilidad de cada montura de la tirada, de la más probable a la menos ({ id, chance 0..1 }).
function Pioneer.chances(): { { id: string, chance: number } }
	local list = {}
	local total = 0
	for mountId, weight in Config.Pioneer.Weights do
		if Mounts[mountId] then
			table.insert(list, { id = mountId, chance = weight })
			total += weight
		end
	end
	for _, entry in list do
		entry.chance /= total
	end
	table.sort(list, function(a, b)
		return a.chance > b.chance
	end)
	return list
end

return Pioneer
