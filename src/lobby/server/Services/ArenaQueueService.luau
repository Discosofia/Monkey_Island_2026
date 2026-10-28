--!strict
-- Colas de las arenas PvP (la de Dunas, captura la bandera, y la del Laboratorio en ruinas), compartidas
-- por todos los servidores del Lobby con MemoryStore. Un solo servicio para los dos destinos (GAMES):
--   - Un jugador (o el líder de un grupo, con todo el grupo) elige formato (1v1…5v5) y entra en la cola
--     (Remotes.ArenaQueueJoin(formato, juego?, modo?): sin juego es Dunas; "Lab" pide un modo de
--     Config.Lab.Modes). Su "ticket" va a la lista ordenada del destino (por hora de llegada) con
--     quiénes son: "ArenaQueue_<formato>" en Dunas y "LabQueue_<modo>_<formato>" en el Laboratorio.
--   - Cada pocos segundos, un solo servidor por lista (el que coge su candado en "ArenaQueueLock")
--     reparte los tickets más antiguos en dos equipos de <formato> plazas (un grupo nunca se separa).
--     Si se completan los dos, reserva un servidor del destino y deja a cada ticket su código en
--     "ArenaMatches".
--   - Cada servidor mira si a sus tickets les ha llegado partida y teletransporta a los suyos (con el
--     formato, el modo, su equipo y el líder del grupo en TeleportData; ArenaMatchService y TeamService en
--     Dunas, LabMatchService y LabTeamService en el Laboratorio los leen al llegar).
-- Un jugador está en una sola cola: entrar en una retira su ticket anterior, sea del destino que sea.
-- El estado se ve en el atributo "ArenaQueue" del jugador (JSON: formato, desde cuándo, juego y modo; sin
-- juego es Dunas). Salir de la cola: Remotes.ArenaQueueLeave, o irse del Lobby (cualquiera del grupo).
-- Cada COUNT_SECONDS cuenta cuántos jugadores esperan en cada formato (todos los servidores) y lo
-- publica en ReplicatedStorage: "ArenaQueueCounts" (Dunas, JSON por formato) para el cartel de la Isla
-- de dunas (ArenaBoardController) y "LabQueueCounts" (JSON { [modo] = { [formato] = n } }) para el del
-- Laboratorio.

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
local Strings = require(ReplicatedStorage.Shared.Strings)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)
local MatchmakingService = require(script.Parent.MatchmakingService)

local SETTINGS = Config.Arena.Queue
-- Cada cuánto se cuentan los jugadores en la cola de cada formato (una lectura por formato y modo).
local COUNT_SECONDS = 10

type Game = {
	place: number,
	teams: { string },
	minFormat: number,
	maxFormat: number,
	-- Textos (se traducen en el cliente): buscando, partida encontrada, salir, y cuando se va alguien.
	searching: string,
	found: string,
	left: string,
	memberLeft: string,
	-- Nombre del destino para el aviso del viaje.
	placeName: string,
}

-- Los destinos de la cola. En el Lobby Arena.TEAM_IDS es Jaguar/Quetzal (Dunas); el Laboratorio tiene
-- los suyos.
local GAMES: { [string]: Game } = {
	Dunas = {
		place = Config.PlaceIds.Dunas,
		teams = Arena.TEAM_IDS,
		minFormat = Config.Arena.MinFormat,
		maxFormat = Config.Arena.MaxFormat,
		searching = Strings.later("⚔️ Buscando partida {n}v{n} en la Isla de dunas…"),
		found = Strings.later("🎖️ ¡Partida encontrada! Zarpando a la Isla de dunas ☠️…"),
		left = Strings.later("Has salido de la cola de la arena"),
		memberLeft = Strings.later("{name} se fue: salen de la cola de la arena"),
		placeName = Strings.later("la Isla de dunas"),
	},
	Lab = {
		place = Config.PlaceIds.Laboratorio,
		teams = Config.Lab.TeamOrder,
		minFormat = Config.Lab.MinFormat,
		maxFormat = Config.Lab.MaxFormat,
		searching = Strings.later("🧪 Buscando partida {n}v{n} en el Laboratorio…"),
		found = Strings.later("🧪 ¡Partida encontrada! Zarpando al Laboratorio en ruinas…"),
		left = Strings.later("Has salido de la cola del Laboratorio"),
		memberLeft = Strings.later("{name} se fue: salen de la cola del Laboratorio"),
		placeName = Strings.later("el Laboratorio en ruinas"),
	},
}

type Ticket = {
	key: string,
	game: string,
	mode: string?,
	format: number,
	leader: Player,
	members: { Player },
	since: number,
}

local ArenaQueueService = {}

-- Los nombres de los modos (Config.Lab.ModeNames) se traducen al dibujarlos (la ventana y el cartel).
local _MODE_NAMES = { Strings.later("Duelo por equipos") }

local canRequest = RequestCooldown.new(1)
-- Tickets de este servidor, por clave.
local tickets: { [string]: Ticket } = {}

-- Nombre de la lista de un destino, modo y formato. Dunas conserva el de siempre, para no perder
-- tickets al actualizar.
local function listName(gameId: string, mode: string?, format: number): string
	return if gameId == "Lab" then `LabQueue_{mode or ""}_{format}` else `ArenaQueue_{format}`
end

local function queueOf(gameId: string, mode: string?, format: number): MemoryStoreSortedMap
	return MemoryStoreService:GetSortedMap(listName(gameId, mode, format))
end

local locks = MemoryStoreService:GetHashMap("ArenaQueueLock")
local matches = MemoryStoreService:GetHashMap("ArenaMatches")

local function publish(ticket: Ticket?, players: { Player })
	for _, player in players do
		player:SetAttribute(
			"ArenaQueue",
			if ticket
				then HttpService:JSONEncode({
					format = ticket.format,
					since = ticket.since,
					game = ticket.game,
					mode = ticket.mode,
				})
				else nil
		)
	end
end

-- Escribe (o renueva, para que no caduque) el ticket en la cola de su destino y formato.
local function store(ticket: Ticket)
	local ids = {}
	for _, member in ticket.members do
		table.insert(ids, member.UserId)
	end
	local ok, err = pcall(function()
		queueOf(ticket.game, ticket.mode, ticket.format):SetAsync(
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

local function removeTicket(ticket: Ticket, message: string?, args: { [string]: any }?)
	tickets[ticket.key] = nil
	publish(nil, ticket.members)
	pcall(function()
		queueOf(ticket.game, ticket.mode, ticket.format):RemoveAsync(ticket.key)
	end)
	if message then
		for _, member in ticket.members do
			if member.Parent then
				Remotes.Notify:FireClient(member, message, args)
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

-- Los datos vienen del cliente: se validan todos.
local function onJoin(player: Player, format: any, gameId: any, mode: any)
	if not canRequest(player) then
		return
	end
	local id = if gameId == nil then "Dunas" else gameId
	if id ~= "Dunas" and id ~= "Lab" then
		return
	end
	local destination = GAMES[id :: string]
	local gameName = id :: string
	if
		typeof(format) ~= "number"
		or format % 1 ~= 0
		or format < destination.minFormat
		or format > destination.maxFormat
	then
		return
	end
	local queueMode: string? = nil
	if gameName == "Lab" then
		if typeof(mode) ~= "string" or not table.find(Config.Lab.Modes, mode) then
			return
		end
		queueMode = mode
	end
	local leader, members = MatchmakingService.partyOf(player)
	if leader ~= player then
		Remotes.Notify:FireClient(player, "Solo el líder del grupo puede buscar partida")
		return
	end
	if #members > format then
		Remotes.Notify:FireClient(player, "Tu grupo es de {n}: elige un formato de {n}v{n} o más", { n = #members })
		return
	end
	-- Una sola cola por jugador: se retira el ticket anterior, sea de Dunas o del Laboratorio.
	local current = ticketOf(player)
	if current then
		removeTicket(current)
	end
	local ticket: Ticket = {
		key = if gameName == "Lab" then `Lab:{game.JobId}:{player.UserId}` else `{game.JobId}:{player.UserId}`,
		game = gameName,
		mode = queueMode,
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
		Remotes.Notify:FireClient(member, destination.searching, { n = format })
	end
end

local function onLeave(player: Player)
	local ticket = ticketOf(player)
	if ticket then
		removeTicket(ticket, GAMES[ticket.game].left)
	end
end

-- ¿Este servidor tiene el candado de la lista? Lo coge si está libre o caducado.
local function takeLock(gameId: string, mode: string?, format: number): boolean
	local now = Workspace:GetServerTimeNow()
	local name = if gameId == "Lab" then `lock_{listName(gameId, mode, format)}` else `format_{format}`
	local ok, result = pcall(function()
		return locks:UpdateAsync(name, function(old: any): any
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

-- Un servidor por lista junta equipos y reserva la partida.
local function matchFormat(gameId: string, mode: string?, format: number)
	if not takeLock(gameId, mode, format) then
		return
	end
	local queue = queueOf(gameId, mode, format)
	local ok, entries = pcall(function()
		return queue:GetRangeAsync(Enum.SortDirection.Ascending, 100)
	end)
	if not ok or typeof(entries) ~= "table" then
		return
	end
	local teamA, teamB = pack(format, entries)
	if not (teamA and teamB) then
		return
	end
	local destination = GAMES[gameId]
	local reserved, code = pcall(function()
		return (TeleportService:ReserveServer(destination.place))
	end)
	if not reserved then
		warn(`[ArenaQueue] No se pudo reservar un servidor ({gameId}): {code}`)
		return
	end
	-- Líder de cada ticket (para el grupo que viaja junto): el primero de sus miembros.
	local leaders: { [string]: number } = {}
	for _, entry in entries do
		local members = if typeof(entry.value) == "table" then entry.value.members else nil
		if typeof(members) == "table" and typeof(members[1]) == "number" then
			leaders[entry.key] = members[1]
		end
	end
	for index, keys in { teamA, teamB } do
		for _, key in keys do
			pcall(function()
				matches:SetAsync(key, {
					code = code,
					format = format,
					team = destination.teams[index],
					mode = mode,
					party = leaders[key],
				}, SETTINGS.MatchSeconds)
				queue:RemoveAsync(key)
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
			local destination = GAMES[ticket.game]
			local travellers = {}
			for _, member in ticket.members do
				if member.Parent then
					table.insert(travellers, member)
					Remotes.Notify:FireClient(member, destination.found)
				end
			end
			task.spawn(function()
				for _, member in travellers do
					PlayerData.saveNow(member)
				end
				local options = Instance.new("TeleportOptions")
				options.ReservedServerAccessCode = found.code
				options:SetTeleportData({
					format = found.format,
					team = found.team,
					mode = found.mode,
					party = if typeof(found.party) == "number" then found.party else ticket.leader.UserId,
				})
				Teleporter.send(travellers, destination.place, destination.placeName, options)
			end)
		end
	end
end

-- Jugadores esperando en un formato de una lista, de todos los servidores (suma el tamaño de cada
-- ticket). nil si no se puede leer.
local function countOf(gameId: string, mode: string?, format: number): number?
	local ok, entries = pcall(function()
		return queueOf(gameId, mode, format):GetRangeAsync(Enum.SortDirection.Ascending, 100)
	end)
	if not ok or typeof(entries) ~= "table" then
		return nil
	end
	local players = 0
	for _, entry in entries do
		local value = entry.value
		players += if typeof(value) == "table" and typeof(value.size) == "number" then value.size else 1
	end
	return players
end

-- Jugadores esperando en cada formato. Si no se puede leer alguno, no se publica (el cartel enseña "—").
local function publishCounts()
	local dunas: { [string]: number } = {}
	local complete = true
	for format = GAMES.Dunas.minFormat, GAMES.Dunas.maxFormat do
		local players = countOf("Dunas", nil, format)
		if not players then
			complete = false
			break
		end
		dunas[tostring(format)] = players
	end
	if complete then
		ReplicatedStorage:SetAttribute("ArenaQueueCounts", HttpService:JSONEncode(dunas))
	end

	local lab: { [string]: { [string]: number } } = {}
	complete = true
	for _, mode in Config.Lab.Modes do
		local byFormat: { [string]: number } = {}
		for format = GAMES.Lab.minFormat, GAMES.Lab.maxFormat do
			local players = countOf("Lab", mode, format)
			if not players then
				complete = false
				break
			end
			byFormat[tostring(format)] = players
		end
		if not complete then
			break
		end
		lab[mode] = byFormat
	end
	if complete then
		ReplicatedStorage:SetAttribute("LabQueueCounts", HttpService:JSONEncode(lab))
	end
end

function ArenaQueueService:Start()
	task.spawn(function()
		while true do
			publishCounts()
			task.wait(COUNT_SECONDS)
		end
	end)
	Remotes.ArenaQueueJoin.OnServerEvent:Connect(onJoin)
	Remotes.ArenaQueueLeave.OnServerEvent:Connect(onLeave)
	-- Si alguien del grupo se va del Lobby, el ticket se cancela (el grupo ya no es el mismo).
	Players.PlayerRemoving:Connect(function(player)
		local ticket = ticketOf(player)
		if ticket then
			removeTicket(ticket, GAMES[ticket.game].memberLeft, { name = player.DisplayName })
		end
	end)
	task.spawn(function()
		local lastRefresh = os.clock()
		while true do
			task.wait(SETTINGS.TickSeconds)
			-- Solo las listas en las que este servidor tiene a alguien esperando.
			local lists: { [string]: Ticket } = {}
			for _, ticket in tickets do
				lists[listName(ticket.game, ticket.mode, ticket.format)] = ticket
			end
			for _, ticket in lists do
				matchFormat(ticket.game, ticket.mode, ticket.format)
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
