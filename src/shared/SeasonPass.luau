--!strict
-- Pase de temporada (Fase 9): las cuentas que comparten el servidor (ServerShared/SeasonPass), el
-- cliente (la ventana del pase y su cartel en el Lobby, los resultados) y la calculadora de la
-- economía. Sin efectos: qué temporada hay a una hora, en qué fase está, qué nivel da una XP y qué
-- premios se pueden reclamar con un estado del perfil ("season").
--
-- Niveles: el GANADO sale de la XP jugando (Config.Season.LevelXp por nivel); el TOTAL le suma los
-- comprados con Robux, sin pasar de Config.Season.Levels. Los premios gratis que no son solo un
-- cosmético piden nivel ganado; los cosméticos gratis y los premium (con la premium), nivel total.
-- Después del último nivel, cada Config.Season.LoopXp ganada da un premio en bucle (gratis).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local EggIncubation = require(script.Parent.EggIncubation)
local Seasons = require(script.Parent.Data.Seasons)

export type Phase = "Active" | "Rest" | "None"
export type Track = "Free" | "Premium"

export type Info = {
	phase: Phase,
	-- La temporada en curso o en descanso; con "None", la próxima (o nil si no hay ninguna prevista).
	season: Seasons.Season?,
	startsAt: number,
	endsAt: number, -- fin de la temporada (empieza el descanso)
	restEndsAt: number,
	day: number, -- día de la temporada (1..Days); 0 fuera de ella
	secondsLeft: number, -- hasta el siguiente cambio de fase
	lastWeek: boolean,
	multiplier: number,
}

-- Lo que se guarda en el perfil ("season") y se publica al cliente (atributo "Season").
export type State = {
	id: string,
	xp: number, -- ganada jugando en esta temporada
	bought: number, -- niveles comprados
	premium: boolean,
	claimedFree: { number },
	claimedPremium: { number },
	loops: number, -- premios en bucle ya cobrados
	xpDay: number, -- día (Shared/Daily) de "xpToday"
	xpToday: number, -- XP de partidas que cuenta para el tope de hoy
	closed: boolean, -- terminada y lo no reclamado ya entregado
}

export type Claim = { level: number, track: Track }

local SeasonPass = {}

local DAY = 24 * 60 * 60
local S = Config.Season

SeasonPass.LEVELS = S.Levels

-- Hora del pase: la del servidor (como los huevos) más el desplazamiento de prueba del panel de
-- Studio ("DebugSeasonShift" en ReplicatedStorage, en segundos).
function SeasonPass.now(): number
	local shift = if RunService:IsStudio() then ReplicatedStorage:GetAttribute("DebugSeasonShift") else nil
	return EggIncubation.now() + (if typeof(shift) == "number" then shift else 0)
end

function SeasonPass.find(seasonId: string): Seasons.Season?
	for _, season in Seasons do
		if season.id == seasonId then
			return season
		end
	end
	return nil
end

function SeasonPass.endsAt(season: Seasons.Season): number
	return season.startsAt + S.Days * DAY
end

-- Qué temporada hay a la hora "now" y en qué fase.
function SeasonPass.info(now: number): Info
	for _, season in Seasons do
		local endsAt = SeasonPass.endsAt(season)
		local restEndsAt = endsAt + S.RestDays * DAY
		if now >= season.startsAt and now < restEndsAt then
			local active = now < endsAt
			local lastWeek = active and endsAt - now <= S.LastWeekDays * DAY
			return {
				phase = if active then "Active" else "Rest",
				season = season,
				startsAt = season.startsAt,
				endsAt = endsAt,
				restEndsAt = restEndsAt,
				day = if active then (now - season.startsAt) // DAY + 1 else 0,
				secondsLeft = if active then endsAt - now else restEndsAt - now,
				lastWeek = lastWeek,
				multiplier = if lastWeek then S.LastWeekMultiplier else 1,
			}
		end
	end
	-- Sin temporada: la próxima que empiece, si hay.
	local upcoming: Seasons.Season? = nil
	for _, season in Seasons do
		if season.startsAt > now and (upcoming == nil or season.startsAt < upcoming.startsAt) then
			upcoming = season
		end
	end
	return {
		phase = "None",
		season = upcoming,
		startsAt = if upcoming then upcoming.startsAt else 0,
		endsAt = if upcoming then SeasonPass.endsAt(upcoming) else 0,
		restEndsAt = 0,
		day = 0,
		secondsLeft = if upcoming then upcoming.startsAt - now else 0,
		lastWeek = false,
		multiplier = 1,
	}
end

local function levelList(raw: any): { number }
	local list = {}
	if typeof(raw) == "table" then
		for _, value in raw do
			if typeof(value) == "number" and value >= 1 and value <= S.Levels and not table.find(list, value) then
				table.insert(list, value // 1)
			end
		end
	end
	return list
end

-- Estado con la forma correcta (del perfil o del JSON del cliente). Si es de otra temporada que
-- "seasonId", vacío para esa.
function SeasonPass.normalize(raw: any, seasonId: string?): State
	local state: State = {
		id = seasonId or "",
		xp = 0,
		bought = 0,
		premium = false,
		claimedFree = {},
		claimedPremium = {},
		loops = 0,
		xpDay = 0,
		xpToday = 0,
		closed = false,
	}
	if typeof(raw) ~= "table" or typeof(raw.id) ~= "string" or (seasonId ~= nil and raw.id ~= seasonId) then
		return state
	end
	local function number(value: any): number
		return if typeof(value) == "number" and value >= 0 then value // 1 else 0
	end
	state.id = raw.id
	state.xp = number(raw.xp)
	state.bought = number(raw.bought)
	state.premium = raw.premium == true
	state.claimedFree = levelList(raw.claimedFree)
	state.claimedPremium = levelList(raw.claimedPremium)
	state.loops = number(raw.loops)
	state.xpDay = number(raw.xpDay)
	state.xpToday = number(raw.xpToday)
	state.closed = raw.closed == true
	return state
end

-- Nivel ganado jugando con "xp" (0..Levels).
function SeasonPass.earnedLevel(xp: number): number
	return math.min(S.Levels, xp // S.LevelXp)
end

-- Nivel total: ganado más comprados, sin pasar del último.
function SeasonPass.level(state: State): number
	return math.min(S.Levels, SeasonPass.earnedLevel(state.xp) + state.bought)
end

-- Premios en bucle ganados (después del último nivel ganado jugando).
function SeasonPass.loopsEarned(xp: number): number
	return math.max(0, xp - S.Levels * S.LevelXp) // S.LoopXp
end

-- XP ganada dentro del nivel que se está llenando y la que pide (para la barra). Con el último nivel
-- ganado, la del siguiente premio en bucle.
function SeasonPass.progress(state: State): (number, number)
	local levelsXp = S.Levels * S.LevelXp
	if state.xp >= levelsXp then
		return (state.xp - levelsXp) % S.LoopXp, S.LoopXp
	end
	return state.xp % S.LevelXp, S.LevelXp
end

-- Premio en bucle número "index" (1, 2…).
function SeasonPass.loopReward(index: number): Config.Reward
	return S.LoopRewards[(index - 1) % #S.LoopRewards + 1]
end

-- ¿Es solo un cosmético? (lo único que pueden dar la premium y los niveles comprados).
function SeasonPass.isCosmeticOnly(reward: Seasons.PassReward): boolean
	for key in reward :: any do
		if key ~= "cosmetic" then
			return false
		end
	end
	return reward.cosmetic ~= nil
end

function SeasonPass.reward(season: Seasons.Season, level: number, track: Track): Seasons.PassReward?
	local entry = season.levels[level]
	if not entry then
		return nil
	end
	return if track == "Free" then entry.free else entry.premium
end

function SeasonPass.isClaimed(state: State, level: number, track: Track): boolean
	return table.find(if track == "Free" then state.claimedFree else state.claimedPremium, level) ~= nil
end

-- ¿Se ha llegado a ese premio? (sin mirar si ya se cobró). Lo no cosmético de la pista gratis pide
-- nivel ganado; lo premium, la premium.
function SeasonPass.unlocked(season: Seasons.Season, state: State, level: number, track: Track): boolean
	local reward = SeasonPass.reward(season, level, track)
	if not reward then
		return false
	end
	if track == "Premium" then
		return state.premium and SeasonPass.level(state) >= level
	end
	local reached = if SeasonPass.isCosmeticOnly(reward)
		then SeasonPass.level(state)
		else SeasonPass.earnedLevel(state.xp)
	return reached >= level
end

-- Premios que se pueden reclamar ya (por nivel, la gratis antes que la premium) y cuántos en bucle.
function SeasonPass.claimable(season: Seasons.Season, state: State): ({ Claim }, number)
	local list: { Claim } = {}
	for level = 1, S.Levels do
		for _, track: Track in { "Free", "Premium" } :: { Track } do
			if SeasonPass.unlocked(season, state, level, track) and not SeasonPass.isClaimed(state, level, track) then
				table.insert(list, { level = level, track = track })
			end
		end
	end
	return list, math.max(0, SeasonPass.loopsEarned(state.xp) - state.loops)
end

-- Línea de los resultados de una partida con lo que ha sumado (ServerShared/SeasonPass.Gain):
-- "⭐ +380 XP de pase · nivel 5 (420/1000) · amigos +38 · ×2 última semana".
function SeasonPass.gainText(gain: any): string?
	if typeof(gain) ~= "table" or typeof(gain.xp) ~= "number" then
		return nil
	end
	local level = if gain.levelsUp and gain.levelsUp > 0 then `¡nivel {gain.level}!` else `nivel {gain.level}`
	local parts = { `⭐ +{gain.xp} XP de pase · {level} ({gain.progress}/{gain.need})` }
	if (gain.friends or 0) > 0 then
		table.insert(parts, `amigos +{gain.friends}`)
	end
	if (gain.multiplier or 1) > 1 then
		table.insert(parts, `×{gain.multiplier} última semana`)
	end
	if (gain.capped or 0) > 0 then
		table.insert(parts, `tope de hoy: {gain.capped} sin contar`)
	end
	return table.concat(parts, " · ")
end

-- ¿Hay algo por reclamar? (el "!" del cartel y el punto de la barra).
function SeasonPass.hasClaimable(season: Seasons.Season?, state: State): boolean
	if not season or state.id ~= season.id or state.closed then
		return false
	end
	local list, loops = SeasonPass.claimable(season, state)
	return #list > 0 or loops > 0
end

return SeasonPass
