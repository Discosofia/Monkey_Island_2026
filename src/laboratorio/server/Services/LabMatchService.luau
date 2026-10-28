--!strict
-- Partida del Laboratorio (docs/LABORATORIO.md §3; como ArenaMatchService de Dunas), de principio a fin.
-- Aquí va lo común a los tres modos (Config.Lab.Modes: Duelo por equipos, Todos contra todos y Rondas); lo
-- que cambia de uno a otro (cómo se puntúa, cuándo acaba, quién gana) está en Modes/ (Modes/Types):
--   Waiting      cada uno elige arma y pulsa "Listo" en su zona de salida (LabLoadoutController), con las
--                compuertas cerradas. Con la sala completa (mode().full) y todos listos, empieza la cuenta
--                atrás; si no, a los Config.Lab.WaitSeconds de llegar el primero. Si entonces no hay gente
--                (mode().enough), se cancela y vuelven al Lobby (en Studio se espera: panel de pruebas).
--   Countdown    cuenta atrás con las compuertas cerradas. Si el modo da la sala por abandonada, vuelve a
--                Waiting.
--   Battle       se abren las compuertas y manda el modo (mode().tick): bajas, rondas y ganador.
--   SuddenDeath  desempate del modo.
--   Intermission la pausa entre rondas (solo Rondas).
--   Results      resultados (Remotes.ArenaResults: Shared/UI/MatchResults) y otra vez Waiting con los
--                bandos repartidos de nuevo (la revancha).
-- El estado va en atributos (Shared/Arena). El modo y el formato (jugadores por bando, o el total de la sala
-- en Todos contra todos) llegan del Lobby en el viaje (TeleportData "mode" y "format"); en Studio,
-- Config.Lab.StudioMode y StudioFormat, o el panel de pruebas. El modo en curso va en Workspace "LabMode"
-- (Shared/LabModes). Al terminar, LabRewardService da el Ámbar, la XP y las estadísticas (salvo en las
-- partidas de prueba) y los resultados las llevan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local LabModes = require(ReplicatedStorage.Shared.LabModes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)
local FreeForAll = require(script.Parent.Parent.Modes.FreeForAll)
local Rounds = require(script.Parent.Parent.Modes.Rounds)
local TeamDeathmatch = require(script.Parent.Parent.Modes.TeamDeathmatch)
local Types = require(script.Parent.Parent.Modes.Types)
local LabRespawnService = require(script.Parent.LabRespawnService)
local LabRewardService = require(script.Parent.LabRewardService)
local LabTeamService = require(script.Parent.LabTeamService)
local LabVoteService = require(script.Parent.LabVoteService)
local LabWorldService = require(script.Parent.LabWorldService)

local TICK_SECONDS = 0.25
local STAT_ATTRIBUTES = { "ArenaKills", "ArenaDeaths" }

-- Un modo por clave de Config.Lab.Modes.
local MODES: { [string]: Types.Mode } = {
	TeamDeathmatch = TeamDeathmatch,
	FreeForAll = FreeForAll,
	Rounds = Rounds,
}

local LabMatchService = {}

local formatLocked = false
-- Prueba con un solo bando (panel de pruebas): no se cancela ni gana nadie por abandono.
local solo = false

function LabMatchService.isSolo(): boolean
	return solo
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function mode(): Types.Mode
	return MODES[LabModes.current()]
end

local function setPhase(phase: Arena.Phase, seconds: number?)
	ReplicatedStorage:SetAttribute("ArenaPhase", phase)
	ReplicatedStorage:SetAttribute("ArenaPhaseEndsAt", if seconds then now() + seconds else nil)
end

local function endsAt(): number?
	local value = ReplicatedStorage:GetAttribute("ArenaPhaseEndsAt")
	return if typeof(value) == "number" then value else nil
end

-- El formato más cercano que admite el modo en curso (sin pasar de lo que él dice).
local function setFormat(format: number)
	local current = mode()
	format = current.format(format)
	ReplicatedStorage:SetAttribute("ArenaFormat", format)
	current.publish(format)
	LabWorldService.setFormat(format)
end

-- Cambia el modo: el anterior deshace lo suyo, y los bandos se rehacen para el nuevo (en Todos contra
-- todos no hay bando).
local function setMode(modeId: string)
	if not MODES[modeId] then
		return
	end
	mode().stop()
	Workspace:SetAttribute("LabMode", modeId)
	LabTeamService.applyMode()
	setFormat(Arena.format())
end

local function setScore(teamId: string, value: number)
	ReplicatedStorage:SetAttribute(`ArenaScore_{teamId}`, value)
end

-- El modo y el formato los trae el primero en llegar desde el Lobby (primero el modo: el formato se valida
-- con él).
local function readFormat(player: Player)
	if formatLocked then
		return
	end
	formatLocked = true
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local data = if ok and typeof(joinData) == "table" then joinData.TeleportData else nil
	if typeof(data) ~= "table" then
		return
	end
	if typeof(data.mode) == "string" and MODES[data.mode] then
		setMode(data.mode)
	end
	if typeof(data.format) == "number" then
		setFormat(data.format)
	end
end

local function startWaiting()
	solo = false
	mode().stop()
	for _, teamId in Arena.TEAM_IDS do
		setScore(teamId, 0)
	end
	ReplicatedStorage:SetAttribute("ArenaWinner", nil)
	ReplicatedStorage:SetAttribute("LabWinnerName", nil)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("ArenaReady", false)
	end
	LabWorldService.setGates(false)
	-- La votación del mapa (la llegada y cada revancha); si la cuenta atrás se abandona no se repite.
	LabVoteService.arm()
	setPhase("Waiting", if #Players:GetPlayers() > 0 then Config.Lab.WaitSeconds else nil)
end

local function startCountdown()
	setPhase("Countdown", Config.Lab.CountdownSeconds)
end

local finish: (winner: Types.Winner?) -> ()

local ctx: Types.Context = {
	setPhase = setPhase,
	finish = function(winner)
		finish(winner)
	end,
	isSolo = LabMatchService.isSolo,
}

local function startBattle()
	LabRewardService.reset()
	for _, player in Players:GetPlayers() do
		for _, attribute in STAT_ATTRIBUTES do
			player:SetAttribute(attribute, 0)
		end
	end
	mode().start(ctx)
end

local function stat(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

-- Los números de todos, para la tabla de los resultados (sin capturas: Shared/UI/MatchResults no saca
-- esa columna). En Todos contra todos entran también los que no tienen bando, con su puesto.
local function scoreboard(): { { [string]: any } }
	local freeForAll = LabModes.isFreeForAll()
	local rows = {}
	for _, player in Players:GetPlayers() do
		local teamId = Arena.teamOf(player)
		if teamId or freeForAll then
			table.insert(rows, {
				name = player.DisplayName,
				team = teamId,
				kills = stat(player, "ArenaKills"),
				deaths = stat(player, "ArenaDeaths"),
				-- Marco puesto (ServerShared/CosmeticsServer), para su fila de los resultados.
				frame = player:GetAttribute("Frame"),
				-- Para saber cuál es la fila de cada uno (en Todos contra todos).
				userId = player.UserId,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.kills ~= b.kills then
			return a.kills > b.kills
		end
		return a.deaths < b.deaths
	end)
	if freeForAll then
		for place, row in rows do
			row.place = place
		end
	end
	return rows
end

-- Resultados de los modos por bandos: "winner" es el id del bando (nil: empate).
local function sendTeamResults(winner: string?)
	local rows = scoreboard()
	local scores = {}
	for _, teamId in Arena.TEAM_IDS do
		scores[teamId] = Arena.score(teamId)
	end
	for _, player in Players:GetPlayers() do
		local teamId = Arena.teamOf(player)
		if teamId then
			local result: "Win" | "Tie" | "Loss" = if winner == nil
				then "Tie"
				elseif winner == teamId then "Win"
				else "Loss"
			local payload: { [string]: any } = {
				result = result,
				winner = winner,
				team = teamId,
				test = solo,
				scores = scores,
				players = rows,
			}
			if not solo then
				for key, value in LabRewardService.give(player, result, nil, teamId) do
					payload[key] = value
				end
			end
			Remotes.ArenaResults:FireClient(player, payload)
		end
	end
end

-- Resultados de Todos contra todos: el puesto de cada uno ("place", de "total"), el nombre del ganador y
-- la tabla ordenada (el puesto de cada fila es su lugar en la lista). Sin "scores".
local function sendFreeResults(winner: Player?)
	local rows = scoreboard()
	local placeOf: { [number]: number } = {}
	for place, row in rows do
		placeOf[row.userId] = place
	end
	for _, player in Players:GetPlayers() do
		local result: "Win" | "Tie" | "Loss" = if winner == nil then "Tie" elseif winner == player then "Win" else "Loss"
		local place = placeOf[player.UserId]
		local payload: { [string]: any } = {
			result = result,
			place = place,
			total = #rows,
			winnerName = if winner then winner.DisplayName else nil,
			test = solo,
			players = rows,
		}
		if not solo then
			for key, value in LabRewardService.give(player, result, place, nil) do
				payload[key] = value
			end
		end
		Remotes.ArenaResults:FireClient(player, payload)
	end
end

-- "winner" es un bando (id), un jugador (Todos contra todos) o nil (empate).
function finish(winner: Types.Winner?)
	local player = if typeof(winner) == "Instance" then winner :: Player else nil
	local teamId = if typeof(winner) == "string" then winner else nil
	ReplicatedStorage:SetAttribute("ArenaWinner", teamId or "")
	ReplicatedStorage:SetAttribute("LabWinnerName", if player then player.DisplayName else nil)
	setPhase("Results", Config.Lab.ResultsSeconds)
	if teamId then
		local team = Arena.TEAMS[teamId]
		Remotes.Notify:FireAllClients("🏆 ¡Gana el bando {icon} {name}!", { icon = team.icon, name = { team.name } })
	elseif player then
		Remotes.Notify:FireAllClients("🏆 ¡Gana {name}!", { name = player.DisplayName })
	else
		Remotes.Notify:FireAllClients("🤝 Empate")
	end
	if LabModes.isFreeForAll() then
		sendFreeResults(player)
	else
		sendTeamResults(teamId)
	end
	-- Después de los resultados: el modo deshace lo suyo (Rondas: el cambio de lado y los eliminados).
	mode().stop()
end

-- Un rival ha derribado a "victim" (LabRespawnService): el modo decide qué suma.
local function onKnockedOut(victim: Player, attacker: Player)
	mode().onKnockedOut(victim, attacker)
end

-- Fuera de Studio no hay nadie con quien jugar: de vuelta al Lobby.
local function cancel()
	if LabModes.isFreeForAll() then
		Remotes.Notify:FireAllClients("No llegaron jugadores suficientes: vuelven al Lobby")
	else
		Remotes.Notify:FireAllClients("No llegó el otro bando: vuelven al Lobby")
	end
	setPhase("Results", Config.Lab.ResultsSeconds)
	task.delay(3, function()
		local players = Players:GetPlayers()
		for _, player in players do
			PlayerData.saveNow(player)
		end
		Teleporter.send(players, Config.PlaceIds.Lobby, Strings.later("el Lobby"))
	end)
end

local function tickWaiting()
	local players = Players:GetPlayers()
	if #players == 0 then
		setPhase("Waiting", nil)
		return
	end
	local deadline = endsAt()
	if not deadline then
		setPhase("Waiting", Config.Lab.WaitSeconds)
		return
	end
	-- Con la votación del mapa abierta no empieza nada (ni los 60 s ni "Listo"); al cerrarse, sigue.
	LabVoteService.tick()
	if LabVoteService.isOpen() then
		return
	end
	local current = mode()
	local allReady = true
	for _, player in players do
		if player:GetAttribute("ArenaReady") ~= true then
			allReady = false
		end
	end
	if solo or (current.full() and allReady) then
		startCountdown()
	elseif now() >= deadline then
		if current.enough() then
			startCountdown()
		elseif RunService:IsStudio() then
			if LabModes.isFreeForAll() then
				Remotes.Notify:FireAllClients("🧪 Faltan jugadores: usa el panel de pruebas para empezar solo")
			else
				Remotes.Notify:FireAllClients("🧪 Falta el otro bando: usa el panel de pruebas para empezar solo")
			end
			setPhase("Waiting", Config.Lab.WaitSeconds)
		else
			cancel()
		end
	end
end

local function tick()
	local phase = Arena.phase()
	if phase == "Waiting" then
		tickWaiting()
	elseif phase == "Countdown" then
		if mode().abandoned(ctx) then
			if LabModes.isFreeForAll() then
				Remotes.Notify:FireAllClients("Faltan jugadores: se espera a más")
			else
				Remotes.Notify:FireAllClients("Un bando se ha quedado vacío: se espera a más jugadores")
			end
			setPhase("Waiting", Config.Lab.WaitSeconds)
		elseif now() >= (endsAt() or 0) then
			startBattle()
		end
	elseif phase == "Battle" or phase == "SuddenDeath" or phase == "Intermission" then
		mode().tick(ctx, phase)
	elseif phase == "Results" then
		if now() >= (endsAt() or 0) then
			LabTeamService.shuffle()
			startWaiting()
			LabRespawnService.respawnAll()
		end
	end
end

-- Panel de pruebas.
function LabMatchService.debugSolo()
	solo = true
	if Arena.phase() == "Waiting" then
		LabVoteService.close(true)
		startCountdown()
	end
end

function LabMatchService.debugNextFormat(): number
	local list = Config.Lab.ModeFormats[LabModes.current()]
	local index = table.find(list, Arena.format()) or 0
	local format = list[index % #list + 1]
	setFormat(format)
	return format
end

-- Pasa al modo siguiente (solo antes de empezar o en los resultados); devuelve su clave, o nil si no toca.
function LabMatchService.debugNextMode(): string?
	local phase = Arena.phase()
	if phase ~= "Waiting" and phase ~= "Results" then
		return nil
	end
	local modes = Config.Lab.Modes
	local index = table.find(modes, LabModes.current()) or 0
	local modeId = modes[index % #modes + 1]
	setMode(modeId)
	return modeId
end

-- Un punto para "player" (según el modo: una baja, un punto de bando o una ronda).
function LabMatchService.debugScore(player: Player)
	if Arena.inBattle() then
		mode().debugScore(player)
	end
end

-- Termina la partida en curso con "player" de ganador y como partida de verdad (cobra), para probar las
-- recompensas sin otro jugador.
function LabMatchService.debugRealWin(player: Player)
	if not Arena.inBattle() then
		return
	end
	solo = false
	finish(if LabModes.isFreeForAll() then player else Arena.teamOf(player))
end

function LabMatchService.debugSkipPhase()
	local phase = Arena.phase()
	local skip = mode().debugSkip
	if skip and skip(ctx) then
		return
	end
	if phase == "Waiting" then
		solo = true
		LabVoteService.close(true)
		startCountdown()
	elseif phase == "SuddenDeath" then
		finish(nil)
	else
		ReplicatedStorage:SetAttribute("ArenaPhaseEndsAt", now())
	end
end

function LabMatchService:Init()
	LabRespawnService.onKnockedOut(onKnockedOut)
end

function LabMatchService:Start()
	-- En Start y no en Init: usa el mapa (LabWorldService), que se prepara en su Init.
	setMode(Config.Lab.StudioMode)
	setFormat(Config.Lab.StudioFormat)
	startWaiting()
	Players.PlayerAdded:Connect(readFormat)
	for _, player in Players:GetPlayers() do
		readFormat(player)
	end
	Remotes.ArenaReady.OnServerEvent:Connect(function(player: Player, ready: any)
		if
			Arena.phase() == "Waiting"
			and (Arena.teamOf(player) or LabModes.isFreeForAll())
			and typeof(ready) == "boolean"
		then
			player:SetAttribute("ArenaReady", ready)
		end
	end)
	Remotes.ArenaLeave.OnServerEvent:Connect(function(player: Player)
		PlayerData.saveNow(player)
		Teleporter.send({ player }, Config.PlaceIds.Lobby, Strings.later("el Lobby"))
	end)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			tick()
		end
	end)
end

return LabMatchService
