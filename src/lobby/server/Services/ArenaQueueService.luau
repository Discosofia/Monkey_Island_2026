--!strict
-- Cola de la arena de Dunas (captura la bandera), compartida por todos los servidores del Lobby con
-- MemoryStore:
--   - Un jugador (o el líder de un grupo, con todo el grupo) elige formato (1v1…5v5) y entra en la cola
--     (Remotes.ArenaQueueJoin). Su "ticket" va a la lista ordenada "ArenaQueue_<formato>" (por hora de
--     llegada) con quiénes son.
--   - Cada pocos segundos, un solo servidor por formato (el que coge el candado "ArenaQueueLock")
--     reparte los tickets más antiguos en dos equipos de <formato> plazas (un grupo nunca se separa).
--     Si se completan los dos, reserva un servidor de Dunas y deja a cada ticket su código en
--     "ArenaMatches".
--   - Cada servidor mira si a sus tickets les ha llegado partida y teletransporta a los suyos (con el
--     formato y su equipo en TeleportData; ArenaMatchService y TeamService los leen al llegar).
-- El estado se ve en el atributo "ArenaQueue" del jugador (JSON: formato y desde cuándo). Salir de la
-- cola: Remotes.ArenaQueueLeave, o irse del Lobby (cualquiera del grupo).

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)
local MatchmakingService = require(script.Parent.MatchmakingService)

local SETTINGS = Config.Arena.Queue

type Ticket = {
	key: string,
	format: number,
	leader: Player,
	members: { Player },
	since: number,
}

local ArenaQueueService = {}

local canRequest = RequestCooldown.new(1)
-- Tickets de este servidor, por clave.
local tickets: { [string]: Ticket } = {}

local function queueOf(format: number): MemoryStoreSortedMap
	return MemoryStoreService:GetSortedMap(`ArenaQueue_{format}`)
end

local locks = MemoryStoreService:GetHashMap("ArenaQueueLock")
local matches = MemoryStoreService:GetHashMap("ArenaMatches")

local function publish(ticket: Ticket?, players: { Player })
	for _, player in players do
		player:SetAttribute(
			"ArenaQueue",
			if ticket then HttpService:JSONEncode({ format = ticket.format, since = ticket.since }) else nil
		)
	end
end

-- Escribe (o renueva, para que no caduque) el ticket en la cola de su formato.
local function store(ticket: Ticket)
	local ids = {}
	for _, member in ticket.members do
		table.insert(ids, member.UserId)
	end
	local ok, err = pcall(function()
		queueOf(ticket.format):SetAsync(
			ticket.key,
			{ members = ids, size = #ids, job = game.JobId },
			SETTINGS.TicketSeconds,
			ticket.since
		)
	end)
	if not ok then
		warn(`[ArenaQueue] No se pudo guardar el ticket: {err}`)
	end
	return ok
end

local function removeTicket(ticket: Ticket, message: string?)
	tickets[ticket.key] = nil
	publish(nil, ticket.members)
	pcall(function()
		queueOf(ticket.format):RemoveAsync(ticket.key)
	end)
	if message then
		for _, member in ticket.members do
			if member.Parent then
				Remotes.Notify:FireClient(member, message)
			end
		end
	end
end

local function ticketOf(player: Player): Ticket?
	for _, ticket in tickets do
		if table.find(ticket.members, player) then
			return ticket
		end
	end
	return nil
end

local function onJoin(player: Player, format: any)
	if not canRequest(player) then
		return
	end
	local settings = Config.Arena
	if typeof(format) ~= "number" or format % 1 ~= 0 or format < settings.MinFormat or format > settings.MaxFormat then
		return
	end
	local leader, members = MatchmakingService.partyOf(player)
	if leader ~= player then
		Remotes.Notify:FireClient(player, "Solo el líder del grupo puede buscar partida")
		return
	end
	if #members > format then
		Remotes.Notify:FireClient(player, `Tu grupo es de {#members}: elige un formato de {#members}v{#members} o más`)
		return
	end
	local current = ticketOf(player)
	if current then
		removeTicket(current)
	end
	local ticket: Ticket = {
		key = `{game.JobId}:{player.UserId}`,
		format = format,
		leader = player,
		members = members,
		since = Workspace:GetServerTimeNow(),
	}
	if not store(ticket) then
		Remotes.Notify:FireClient(player, "No se pudo entrar en la cola: prueba otra vez")
		return
	end
	tickets[ticket.key] = ticket
	publish(ticket, members)
	for _, member in members do
		Remotes.Notify:FireClient(member, `⚔️ Buscando partida {format}v{format} en las Dunas…`)
	end
end

local function onLeave(player: Player)
	local ticket = ticketOf(player)
	if ticket then
		removeTicket(ticket, "Has salido de la cola de la arena")
	end
end

-- ¿Este servidor tiene el candado del formato? Lo coge si está libre o caducado.
local function takeLock(format: number): boolean
	local now = Workspace:GetServerTimeNow()
	local ok, result = pcall(function()
		return locks:UpdateAsync(`format_{format}`, function(old: any): any
			if typeof(old) == "table" and old.job ~= game.JobId and (old.untilTime or 0) > now then
				return nil
			end
			return { job = game.JobId, untilTime = now + SETTINGS.LockSeconds }
		end, SETTINGS.LockSeconds * 2)
	end)
	return ok and typeof(result) == "table" and result.job == game.JobId
end

-- Reparte los tickets más antiguos en dos equipos de "format" plazas. Devuelve los dos equipos (lista
-- de claves) si los completa, o nil.
local function pack(format: number, entries: { any }): ({ string }?, { string }?)
	local teams: { { string } } = { {}, {} }
	local room = { format, format }
	for _, entry in entries do
		local size = if typeof(entry.value) == "table" then entry.value.size else nil
		if typeof(size) == "number" and size >= 1 then
			-- Al equipo con más hueco en que quepa entero (un grupo no se separa).
			local first = if room[1] >= room[2] then 1 else 2
			local chosen = if size <= room[first] then first elseif size <= room[3 - first] then 3 - first else nil
			if chosen then
				table.insert(teams[chosen], entry.key)
				room[chosen] -= size
			end
			if room[1] == 0 and room[2] == 0 then
				return teams[1], teams[2]
			end
		end
	end
	return nil, nil
end

-- Un servidor por formato junta equipos y reserva la partida.
local function matchFormat(format: number)
	if not takeLock(format) then
		return
	end
	local ok, entries = pcall(function()
		return queueOf(format):GetRangeAsync(Enum.SortDirection.Ascending, 100)
	end)
	if not ok or typeof(entries) ~= "table" then
		return
	end
	local teamA, teamB = pack(format, entries)
	if not (teamA and teamB) then
		return
	end
	local reserved, code = pcall(function()
		return (TeleportService:ReserveServer(Config.PlaceIds.Dunas))
	end)
	if not reserved then
		warn(`[ArenaQueue] No se pudo reservar un servidor de Dunas: {code}`)
		return
	end
	for index, keys in { teamA, teamB } do
		for _, key in keys do
			pcall(function()
				matches:SetAsync(
					key,
					{ code = code, format = format, team = Arena.TEAM_IDS[index] },
					SETTINGS.MatchSeconds
				)
				queueOf(format):RemoveAsync(key)
			end)
		end
	end
end

-- ¿Le ha llegado partida a algún ticket de este servidor? Entonces, de viaje.
local function checkMatches()
	for key, ticket in tickets do
		local ok, found = pcall(function()
			return matches:GetAsync(key)
		end)
		if ok and typeof(found) == "table" and typeof(found.code) == "string" then
			pcall(function()
				matches:RemoveAsync(key)
			end)
			tickets[key] = nil
			publish(nil, ticket.members)
			local travellers = {}
			for _, member in ticket.members do
				if member.Parent then
					table.insert(travellers, member)
					Remotes.Notify:FireClient(member, "🏜️ ¡Partida encontrada! Zarpando a las Dunas…")
				end
			end
			task.spawn(function()
				for _, member in travellers do
					PlayerData.saveNow(member)
				end
				local options = Instance.new("TeleportOptions")
				options.ReservedServerAccessCode = found.code
				options:SetTeleportData({ format = found.format, team = found.team })
				Teleporter.send(travellers, Config.PlaceIds.Dunas, "las Dunas", options)
			end)
		end
	end
end

function ArenaQueueService:Start()
	Remotes.ArenaQueueJoin.OnServerEvent:Connect(onJoin)
	Remotes.ArenaQueueLeave.OnServerEvent:Connect(onLeave)
	-- Si alguien del grupo se va del Lobby, el ticket se cancela (el grupo ya no es el mismo).
	Players.PlayerRemoving:Connect(function(player)
		local ticket = ticketOf(player)
		if ticket then
			removeTicket(ticket, `{player.DisplayName} se ha ido: salís de la cola de la arena`)
		end
	end)
	task.spawn(function()
		local lastRefresh = os.clock()
		while true do
			task.wait(SETTINGS.TickSeconds)
			-- Solo los formatos en los que este servidor tiene a alguien esperando.
			local formats: { [number]: boolean } = {}
			for _, ticket in tickets do
				formats[ticket.format] = true
			end
			for format in formats do
				matchFormat(format)
			end
			checkMatches()
			-- Renueva los tickets para que no caduquen mientras se espera.
			if os.clock() - lastRefresh >= SETTINGS.TicketSeconds / 2 then
				lastRefresh = os.clock()
				for _, ticket in tickets do
					store(ticket)
				end
			end
		end
	end)
end

return ArenaQueueService
