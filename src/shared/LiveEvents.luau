--!strict
-- Estado de los eventos en vivo (T4b), en el cliente y en el servidor: el servidor
-- (ServerShared/LiveEventsServer) publica la lista en el atributo "LiveEvents" de ReplicatedStorage
-- (JSON) y aquí se lee. Las horas son de Workspace:GetServerTimeNow (segundos UTC, igual en todos los
-- servidores y, aproximado, en el cliente).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.Data.LiveEvents)

export type Event = {
	id: string,
	kind: string,
	startsAt: number,
	endsAt: number,
	by: string,
	scope: string,
}

local ATTRIBUTE = "LiveEvents"

local LiveEvents = {}

LiveEvents.ATTRIBUTE = ATTRIBUTE

function LiveEvents.now(): number
	return Workspace:GetServerTimeNow()
end

-- Todos los eventos publicados (en marcha o programados), por orden de inicio.
function LiveEvents.list(): { Event }
	local raw = ReplicatedStorage:GetAttribute(ATTRIBUTE)
	if typeof(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or typeof(decoded) ~= "table" then
		return {}
	end
	local events: { Event } = {}
	for _, event in decoded do
		if typeof(event) == "table" and Catalog[event.kind] then
			table.insert(events, event)
		end
	end
	table.sort(events, function(a, b)
		return a.startsAt < b.startsAt
	end)
	return events
end

function LiveEvents.isRunning(event: Event, now: number?): boolean
	local time = now or LiveEvents.now()
	return event.startsAt <= time and time < event.endsAt
end

-- ¿Hay ahora un evento "kind" en marcha?
function LiveEvents.active(kind: string): boolean
	local now = LiveEvents.now()
	for _, event in LiveEvents.list() do
		if event.kind == kind and LiveEvents.isRunning(event, now) then
			return true
		end
	end
	return false
end

-- Multiplicadores de los eventos en marcha (1 si no hay).
function LiveEvents.amberMultiplier(): number
	return if LiveEvents.active("DoubleAmber") then Config.LiveEvents.AmberMultiplier else 1
end

function LiveEvents.xpMultiplier(): number
	return if LiveEvents.active("DoubleXp") then Config.LiveEvents.XpMultiplier else 1
end

-- Pesos de la rareza de un huevo que aparece ahora (nil = los normales).
function LiveEvents.eggWeights(): { [string]: number }?
	return if LiveEvents.active("EggLuck") then Config.LiveEvents.EggLuckWeights else nil
end

-- "12:34" o "1:02:03".
function LiveEvents.clock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours, minutes, rest = total // 3600, total % 3600 // 60, total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, rest)
	end
	return string.format("%d:%02d", minutes, rest)
end

return LiveEvents
