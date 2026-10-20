--!strict
-- Clasificaciones globales (Fase 6) con OrderedDataStore: récord de días sobrevividos y rescates.
-- La Isla las actualiza al terminar cada partida; el Lobby lee el top para mostrarlo.
-- Si DataStore no está disponible (Studio sin acceso a las API), no hace nada.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Entry = { userId: number, value: number }

local Leaderboards = {}

Leaderboards.STATS = { "BestDays", "Rescues" }
-- Los de la arena de Dunas (ArenaRewardService): victorias y banderas capturadas en total.
Leaderboards.ARENA_STATS = { "ArenaWins", "ArenaCaptures" }

local stores: { [string]: OrderedDataStore } = {}

local function storeFor(stat: string): OrderedDataStore?
	if stores[stat] then
		return stores[stat]
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(`{Config.Data.LeaderboardPrefix}{stat}`)
	end)
	if ok then
		stores[stat] = result
		return result
	end
	return nil
end

-- Guarda "value" si es mayor que el que había. Puede tardar: llámala desde un hilo propio.
function Leaderboards.record(userId: number, stat: string, value: number)
	local store = storeFor(stat)
	if not store or value <= 0 then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(tostring(userId), function(current: any): any
			local previous = if typeof(current) == "number" then current else 0
			return if value > previous then math.floor(value) else nil
		end)
	end)
	if not ok then
		warn(`[Leaderboards] No se pudo guardar {stat}: {err}`)
	end
end

-- Los "count" mejores de una clasificación (vacío si falla).
function Leaderboards.top(stat: string, count: number): { Entry }
	local store = storeFor(stat)
	if not store then
		return {}
	end
	local ok, result = pcall(function()
		local pages = store:GetSortedAsync(false, count)
		local entries: { Entry } = {}
		for _, item in pages:GetCurrentPage() do
			table.insert(entries, { userId = tonumber(item.key) or 0, value = item.value })
		end
		return entries
	end)
	return if ok then result else {}
end

return Leaderboards
