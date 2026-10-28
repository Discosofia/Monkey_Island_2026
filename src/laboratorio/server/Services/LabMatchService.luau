--!strict
-- Duelo por equipos del Laboratorio (docs/LABORATORIO.md §3; como ArenaMatchService de Dunas), de
-- principio a fin:
--   Waiting     cada uno elige arma y pulsa "Listo" en su zona de salida (LabLoadoutController), con las
--               compuertas cerradas. Con los dos bandos completos y todos listos, empieza la cuenta
--               atrás; si no, a los Config.Lab.WaitSeconds de llegar el primero. Si entonces falta un
--               bando entero, se cancela y vuelven al Lobby (en Studio se espera: panel de pruebas).
--   Countdown   cuenta atrás con las compuertas cerradas. Si un bando se queda vacío, vuelve a Waiting.
--   Battle      se abren las compuertas. Cada baja suma un punto a su bando (LabRespawnService). Gana
--               el primero en llegar a KillsToWin[formato] o el que más tenga a los MatchSeconds; con
--               empate, SuddenDeath. Si un bando se queda vacío, gana el otro.
--   SuddenDeath la siguiente baja gana.
--   Results     resultados (Remotes.ArenaResults: Shared/UI/MatchResults) y otra vez Waiting con los
--               bandos repartidos de nuevo (la revancha).
-- El estado va en atributos (Shared/Arena). El formato (jugadores por bando) llega del Lobby en el viaje
-- (TeleportData "format"); en Studio, Config.Lab.StudioFormat o el panel de pruebas. Las recompensas
-- llegan en la L5: de momento, los resultados no llevan Ámbar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)
local LabRespawnService = require(script.Parent.LabRespawnService)
local LabTeamService = require(script.Parent.LabTeamService)
local LabWorldService = require(script.Parent.LabWorldService)

local TICK_SECONDS = 0.25
local STAT_ATTRIBUTES = { "ArenaKills", "ArenaDeaths" }

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

local function setPhase(phase: Arena.Phase, seconds: number?)
	ReplicatedStorage:SetAttribute("ArenaPhase", phase)
	ReplicatedStorage:SetAttribute("ArenaPhaseEndsAt", if seconds then now() + seconds else nil)
end

local function endsAt(): number?
	local value = ReplicatedStorage:GetAttribute("ArenaPhaseEndsAt")
	return if typeof(value) == "number" then value else nil
end

-- Bajas que hacen falta para ganar con el formato de ahora.
function LabMatchService.killsToWin(): number
	local kills = Config.Lab.KillsToWin
	return kills[math.clamp(Arena.format(), 1, #kills)]
end

local function setFormat(format: number)
	format = math.clamp(math.floor(format), 1, #Config.Lab.KillsToWin)
	ReplicatedStorage:SetAttribute("ArenaFormat", format)
	ReplicatedStorage:SetAttribute("LabKillsToWin", LabMatchService.killsToWin())
	LabWorldService.setFormat(format)
end

local function setScore(teamId: string, value: number)
	ReplicatedStorage:SetAttribute(`ArenaScore_{teamId}`, value)
end

local function teamSizes(): (number, number)
	return #Arena.membersOf(Arena.TEAM_IDS[1]), #Arena.membersOf(Arena.TEAM_IDS[2])
end

-- El formato lo trae el primero en llegar desde el Lobby.
local function readFormat(player: Player)
	if formatLocked then
		return
	end
	formatLocked = true
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local data = if ok and typeof(joinData) == "table" then joinData.TeleportData else nil
	local format = if typeof(data) == "table" then data.format else nil
	if typeof(format) == "number" then
		setFormat(format)
	end
end

local function startWaiting()
	solo = false
	for _, teamId in Arena.TEAM_IDS do
		setScore(teamId, 0)
	end
	ReplicatedStorage:SetAttribute("ArenaWinner", nil)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("ArenaReady", false)
	end
	LabWorldService.setGates(false)
	setPhase("Waiting", if #Players:GetPlayers() > 0 then Config.Lab.WaitSeconds else nil)
end

local function startCountdown()
	setPhase("Countdown", Config.Lab.CountdownSeconds)
end

local function startBattle()
	for _, teamId in Arena.TEAM_IDS do
		setScore(teamId, 0)
	end
	for _, player in Players:GetPlayers() do
		for _, attribute in STAT_ATTRIBUTES do
			player:SetAttribute(attribute, 0)
		end
	end
	setPhase("Battle", Config.Lab.MatchSeconds)
	LabWorldService.setGates(true)
	LabRespawnService.respawnAll()
	Remotes.Notify:FireAllClients("⚔️ ¡Que empiece el duelo! Gana el primer bando en llegar a {kills} bajas", {
		kills = LabMatchService.killsToWin(),
	})
end

local function stat(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

-- Los números de todos, para la tabla de los resultados (sin capturas: Shared/UI/MatchResults no saca
-- esa columna).
local function scoreboard(): { { [string]: any } }
	local rows = {}
	for _, player in Players:GetPlayers() do
		local teamId = Arena.teamOf(player)
		if teamId then
			table.insert(rows, {
				name = player.DisplayName,
				team = teamId,
				kills = stat(player, "ArenaKills"),
				deaths = stat(player, "ArenaDeaths"),
				-- Marco puesto (ServerShared/CosmeticsServer), para su fila de los resultados.
				frame = player:GetAttribute("Frame"),
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.kills ~= b.kills then
			return a.kills > b.kills
		end
		return a.deaths < b.deaths
	end)
	return rows
end

local function sendResults(winner: string?)
	local rows = scoreboard()
	local scores = {}
	for _, teamId in Arena.TEAM_IDS do
		scores[teamId] = Arena.score(teamId)
	end
	for _, player in Players:GetPlayers() do
		local teamId = Arena.teamOf(player)
		if teamId then
			Remotes.ArenaResults:FireClient(player, {
				result = if winner == nil then "Tie" elseif winner == teamId then "Win" else "Loss",
				winner = winner,
				team = teamId,
				test = solo,
				scores = scores,
				players = rows,
			})
		end
	end
end

local function finish(winner: string?)
	ReplicatedStorage:SetAttribute("ArenaWinner", winner or "")
	setPhase("Results", Config.Lab.ResultsSeconds)
	if winner then
		local team = Arena.TEAMS[winner]
		Remotes.Notify:FireAllClients("🏆 ¡Gana el bando {icon} {name}!", { icon = team.icon, name = { team.name } })
	else
		Remotes.Notify:FireAllClients("🤝 Empate")
	end
	sendResults(winner)
end

-- Un rival ha derribado a "victim" (LabRespawnService): un punto para el bando de "attacker". En muerte
-- súbita, gana.
local function onKnockedOut(_victim: Player, attacker: Player)
	local teamId = Arena.teamOf(attacker)
	if teamId and Arena.inBattle() then
		setScore(teamId, Arena.score(teamId) + 1)
	end
end

-- Fuera de Studio no hay nadie con quien jugar: de vuelta al Lobby.
local function cancel()
	Remotes.Notify:FireAllClients("No llegó el otro bando: vuelven al Lobby")
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
	local first, second = teamSizes()
	local format = Arena.format()
	local allReady = true
	for _, player in players do
		if player:GetAttribute("ArenaReady") ~= true then
			allReady = false
		end
	end
	if solo or (first == format and second == format and allReady) then
		startCountdown()
	elseif now() >= deadline then
		if first > 0 and second > 0 then
			startCountdown()
		elseif RunService:IsStudio() then
			Remotes.Notify:FireAllClients("🧪 Falta el otro bando: usa el panel de pruebas para empezar solo")
			setPhase("Waiting", Config.Lab.WaitSeconds)
		else
			cancel()
		end
	end
end

local function tick()
	local phase = Arena.phase()
	local first, second = teamSizes()
	local teamMissing = not solo and (first == 0 or second == 0)
	if phase == "Waiting" then
		tickWaiting()
	elseif phase == "Countdown" then
		if teamMissing then
			Remotes.Notify:FireAllClients("Un bando se ha quedado vacío: se espera a más jugadores")
			setPhase("Waiting", Config.Lab.WaitSeconds)
		elseif now() >= (endsAt() or 0) then
			startBattle()
		end
	elseif phase == "Battle" or phase == "SuddenDeath" then
		local firstId, secondId = Arena.TEAM_IDS[1], Arena.TEAM_IDS[2]
		local firstScore, secondScore = Arena.score(firstId), Arena.score(secondId)
		local target = LabMatchService.killsToWin()
		if firstScore >= target or (phase == "SuddenDeath" and firstScore > secondScore) then
			finish(firstId)
		elseif secondScore >= target or (phase == "SuddenDeath" and secondScore > firstScore) then
			finish(secondId)
		elseif teamMissing then
			finish(if first > 0 then firstId elseif second > 0 then secondId else nil)
		elseif phase == "Battle" and now() >= (endsAt() or 0) then
			if firstScore == secondScore then
				setPhase("SuddenDeath", nil)
				Remotes.Notify:FireAllClients("⚡ ¡Empate! Muerte súbita: la siguiente baja gana")
			else
				finish(if firstScore > secondScore then firstId else secondId)
			end
		end
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
		startCountdown()
	end
end

function LabMatchService.debugNextFormat(): number
	local format = Arena.format() % #Config.Lab.KillsToWin + 1
	setFormat(format)
	return format
end

function LabMatchService.debugSkipPhase()
	local phase = Arena.phase()
	if phase == "Waiting" then
		solo = true
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
	setFormat(Config.Lab.StudioFormat)
	startWaiting()
	Players.PlayerAdded:Connect(readFormat)
	for _, player in Players:GetPlayers() do
		readFormat(player)
	end
	Remotes.ArenaReady.OnServerEvent:Connect(function(player: Player, ready: any)
		if Arena.phase() == "Waiting" and Arena.teamOf(player) and typeof(ready) == "boolean" then
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
