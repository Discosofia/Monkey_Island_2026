--!strict
-- Eventos en vivo (T4b): un administrador lanza uno del catálogo (Data/LiveEvents) ahora o con
-- retraso, en este servidor o en todos (ServerShared/AdminNet), y lo puede parar. Los de "todos" se
-- guardan también en un DataStore (Config.LiveEvents.StoreName) para que un servidor que arranca
-- después los vea. Cada servidor publica los suyos en ReplicatedStorage (Shared/LiveEvents) y:
--   - avisa a sus jugadores cuando uno empieza y llama a los de onStarted (la fiesta y la lluvia de
--     huevos del Lobby);
--   - con "Huevo acelerado", quita tiempo al huevo del nido de cada jugador cada EggTickSeconds.
-- El doble de Ámbar y de XP y la suerte de huevo los aplican MatchService, ArenaRewardService,
-- SeasonPass y EggService leyendo Shared/LiveEvents.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Data.LiveEvents)
local Config = require(ReplicatedStorage.Shared.Config)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local AdminNet = require(script.Parent.AdminNet)
local Eggs = require(script.Parent.Eggs)

type Event = LiveEvents.Event

local KEY = "active"

local LiveEventsServer = {}

local events: { [string]: Event } = {}
-- Eventos ya empezados en este servidor (para avisar y llamar a onStarted una sola vez).
local started: { [string]: boolean } = {}
local startedListeners: { (event: Event) -> () } = {}
local store: DataStore? = nil

local function getStore(): DataStore?
	if not store then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Config.LiveEvents.StoreName)
		end)
		store = if ok then result else nil
	end
	return store
end

local function publish()
	local list = {}
	for _, event in events do
		table.insert(list, event)
	end
	ReplicatedStorage:SetAttribute(LiveEvents.ATTRIBUTE, HttpService:JSONEncode(list))
end

local function valid(event: any): boolean
	return typeof(event) == "table"
		and typeof(event.id) == "string"
		and Catalog[event.kind] ~= nil
		and typeof(event.startsAt) == "number"
		and typeof(event.endsAt) == "number"
end

local function add(event: Event)
	if valid(event) and event.endsAt > LiveEvents.now() then
		events[event.id] = event
		publish()
	end
end

local function remove(id: string)
	if events[id] then
		events[id] = nil
		publish()
	end
end

-- Cambia la lista guardada de los eventos de "todos los servidores" (quita los ya acabados).
local function editStored(change: (list: { Event }) -> ())
	local dataStore = getStore()
	if not dataStore then
		return
	end
	local ok, err = pcall(function()
		dataStore:UpdateAsync(KEY, function(current: any)
			local list: { Event } = {}
			local now = LiveEvents.now()
			if typeof(current) == "table" then
				for _, event in current do
					if valid(event) and event.endsAt > now then
						table.insert(list, event)
					end
				end
			end
			change(list)
			return list
		end)
	end)
	if not ok then
		warn(`[LiveEvents] No se pudo guardar la lista: {err}`)
	end
end

AdminNet.on("LiveEventStart", add)
AdminNet.on("LiveEventStop", function(id: any)
	if typeof(id) == "string" then
		remove(id)
	end
end)

-- Llama a "callback" en este servidor cuando empieza un evento (también uno programado).
function LiveEventsServer.onStarted(callback: (event: Event) -> ())
	table.insert(startedListeners, callback)
end

-- Lanza "kind" dentro de "delayMinutes" durante "minutes" (o su duración fija). Devuelve el evento
-- y si llegó a donde se pidió (false: solo en este servidor).
function LiveEventsServer.start(
	kind: string,
	minutes: number,
	delayMinutes: number,
	scope: AdminNet.Scope,
	by: string
): (Event?, boolean)
	local info = Catalog[kind]
	if not info then
		return nil, false
	end
	if info.unique then
		local now = LiveEvents.now()
		for _, other in events do
			if other.kind == kind and other.endsAt > now then
				return nil, false
			end
		end
	end
	local startsAt = math.floor(LiveEvents.now()) + delayMinutes * 60
	local event: Event = {
		id = HttpService:GenerateGUID(false),
		kind = kind,
		startsAt = startsAt,
		endsAt = startsAt + (info.seconds or minutes * 60),
		by = by,
		scope = scope,
	}
	if scope == "All" then
		editStored(function(list)
			table.insert(list, event)
		end)
	end
	return event, AdminNet.send("LiveEventStart", event, scope)
end

-- El id de un evento "kind" que está en marcha o programado en este servidor (nil si no hay).
function LiveEventsServer.runningId(kind: string): string?
	local now = LiveEvents.now()
	for id, event in events do
		if event.kind == kind and event.endsAt > now then
			return id
		end
	end
	return nil
end

-- Para el evento "id" (donde se lanzó). false si no está en este servidor.
function LiveEventsServer.stop(id: string): boolean
	local event = events[id]
	if not event then
		return false
	end
	local scope: AdminNet.Scope = if event.scope == "All" then "All" else "Server"
	if scope == "All" then
		editStored(function(list)
			for index, stored in list do
				if stored.id == id then
					table.remove(list, index)
					break
				end
			end
		end)
	end
	AdminNet.send("LiveEventStop", id, scope)
	if event.kind == "Maintenance" then
		AdminNet.send("Announce", {
			text = Strings.later("🛠️ Mantenimiento cancelado: puedes seguir jugando."),
			from = Strings.later("Mantenimiento"),
		}, scope)
	end
	return true
end

-- Cada segundo: quita los acabados, avisa de los que empiezan y acelera los huevos.
local function tick()
	local now = LiveEvents.now()
	local changed = false
	for id, event in events do
		if event.endsAt <= now then
			events[id] = nil
			started[id] = nil
			changed = true
			local info = Catalog[event.kind]
			Remotes.Notify:FireAllClients("{icon} Terminó: {name}", { icon = info.icon, name = { info.name } })
		elseif event.startsAt <= now and not started[id] then
			started[id] = true
			local info = Catalog[event.kind]
			Remotes.Notify:FireAllClients("{icon} ¡Empieza {name}! {detail} ({time})", {
				icon = info.icon,
				name = { info.name },
				detail = { info.detail },
				time = LiveEvents.clock(event.endsAt - now),
			})
			for _, callback in startedListeners do
				task.spawn(callback, event)
			end
		end
	end
	if changed then
		publish()
	end
end

-- Lo llama Admin.start en cada place.
function LiveEventsServer.run()
	publish()
	task.spawn(function()
		local dataStore = getStore()
		if not dataStore then
			return
		end
		local ok, stored = pcall(function()
			return dataStore:GetAsync(KEY)
		end)
		if ok and typeof(stored) == "table" then
			for _, event in stored do
				add(event)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.LiveEvents.EggTickSeconds)
			if LiveEvents.active("FastEgg") then
				local bonus = Config.LiveEvents.EggTickSeconds * (Config.LiveEvents.EggSpeed - 1)
				for _, player in Players:GetPlayers() do
					Eggs.addFreeTime(player, bonus)
				end
			end
		end
	end)
end

return LiveEventsServer
