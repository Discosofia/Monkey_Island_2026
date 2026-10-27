--!strict
-- Partida de la arena (captura la bandera), de principio a fin:
--   Waiting     llegan los jugadores, eligen equipo, rol y equipo, y pulsan "Listo". Con los dos
--               equipos completos y todos listos, empieza la cuenta atrás; si no, a los
--               Config.Arena.WaitSeconds de llegar el primero (se reparten los que no eligieron). Si
--               entonces falta un equipo entero, se cancela y vuelven al Lobby.
--   Countdown   cuenta atrás con las puertas cerradas. Si un equipo se queda vacío, vuelve a Waiting.
--   Battle      se abren las puertas. Gana quien llegue a CapturesToWin (addCapture) o quien tenga
--               más al acabar el tiempo; con empate, SuddenDeath. Si un equipo se queda vacío, gana
--               el otro.
--   SuddenDeath la siguiente captura gana.
--   Results     resultados unos segundos y otra vez Waiting con los mismos equipos (la revancha).
-- El estado va en atributos (Shared/Arena). El formato (jugadores por equipo) llega del Lobby en el
-- viaje (TeleportData "format"); en Studio, Config.Arena.StudioFormat o el panel de pruebas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)
local ArenaWorldService = require(script.Parent.ArenaWorldService)
local RespawnService = require(script.Parent.RespawnService)
local TeamService = require(script.Parent.TeamService)

local TICK_SECONDS = 0.25
local STAT_ATTRIBUTES = { "ArenaKills", "ArenaDeaths", "ArenaCaptures" }

local ArenaMatchService = {}

local formatLocked = false
-- Prueba con un solo equipo (panel de pruebas): no se cancela ni gana nadie por abandono.
local solo = false
local finishListeners: { (winner: string?) -> () } = {}

-- Llama a "callback" al acabar una partida, con el equipo ganador (nil si es empate).
function ArenaMatchService.onFinished(callback: (winner: string?) -> ())
	table.insert(finishListeners, callback)
end

function ArenaMatchService.isSolo(): boolean
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

local function setFormat(format: number)
	format = math.clamp(math.floor(format), Config.Arena.MinFormat, Config.Arena.MaxFormat)
	ReplicatedStorage:SetAttribute("ArenaFormat", format)
	ArenaWorldService.setFormat(format)
end

local function setScore(teamId: string, value: number)
	ReplicatedStorage:SetAttribute(`ArenaScore_{teamId}`, value)
end

local function teamSizes(): (number, number)
	return #Arena.membersOf("Jaguar"), #Arena.membersOf("Quetzal")
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
	ArenaWorldService.setGates(false)
	setPhase("Waiting", if #Players:GetPlayers() > 0 then Config.Arena.WaitSeconds else nil)
end

local function startCountdown()
	TeamService.assignMissing()
	setPhase("Countdown", Config.Arena.CountdownSeconds)
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
	setPhase("Battle", Config.Arena.MatchSeconds)
	ArenaWorldService.setGates(true)
	RespawnService.respawnAll()
	Remotes.Notify:FireAllClients("⚔️ ¡Que empiece la batalla! Roba la bandera rival y tráela a tu base")
end

local function finish(winner: string?)
	ReplicatedStorage:SetAttribute("ArenaWinner", winner or "")
	setPhase("Results", Config.Arena.ResultsSeconds)
	if winner then
		local team = Config.Arena.Teams[winner]
		Remotes.Notify:FireAllClients(`🏆 ¡Gana el equipo {team.icon} {team.name}!`)
	else
		Remotes.Notify:FireAllClients("🤝 Empate")
	end
	for _, listener in finishListeners do
		task.spawn(listener, winner)
	end
end

-- Un equipo ha capturado la bandera rival (FlagService). En muerte súbita, gana.
function ArenaMatchService.addCapture(teamId: string)
	if not Arena.inBattle() then
		return
	end
	setScore(teamId, Arena.score(teamId) + 1)
end

-- Fuera de Studio no hay nadie con quien jugar: de vuelta al Lobby.
local function cancel()
	Remotes.Notify:FireAllClients("No llegó el otro equipo: vuelven al Lobby")
	setPhase("Results", Config.Arena.ResultsSeconds)
	task.delay(3, function()
		local players = Players:GetPlayers()
		for _, player in players do
			PlayerData.saveNow(player)
		end
		Teleporter.send(players, Config.PlaceIds.Lobby, "el Lobby")
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
		setPhase("Waiting", Config.Arena.WaitSeconds)
		return
	end
	local jaguar, quetzal = teamSizes()
	local format = Arena.format()
	local allReady = true
	for _, player in players do
		if not (Arena.teamOf(player) and player:GetAttribute("ArenaReady") == true) then
			allReady = false
		end
	end
	if solo or (jaguar == format and quetzal == format and allReady) then
		startCountdown()
	elseif now() >= deadline then
		TeamService.assignMissing()
		jaguar, quetzal = teamSizes()
		if jaguar > 0 and quetzal > 0 then
			startCountdown()
		elseif RunService:IsStudio() then
			Remotes.Notify:FireAllClients("🧪 Falta el otro equipo: usa el panel de pruebas para empezar solo")
			setPhase("Waiting", Config.Arena.WaitSeconds)
		else
			cancel()
		end
	end
end

local function tick()
	local phase = Arena.phase()
	local jaguar, quetzal = teamSizes()
	local teamMissing = not solo and (jaguar == 0 or quetzal == 0)
	if phase == "Waiting" then
		tickWaiting()
	elseif phase == "Countdown" then
		if teamMissing then
			Remotes.Notify:FireAllClients("Un equipo se ha quedado vacío: se espera a más jugadores")
			setPhase("Waiting", Config.Arena.WaitSeconds)
		elseif now() >= (endsAt() or 0) then
			startBattle()
		end
	elseif phase == "Battle" or phase == "SuddenDeath" then
		local jaguarScore, quetzalScore = Arena.score("Jaguar"), Arena.score("Quetzal")
		local target = Config.Arena.CapturesToWin
		if jaguarScore >= target or (phase == "SuddenDeath" and jaguarScore > quetzalScore) then
			finish("Jaguar")
		elseif quetzalScore >= target or (phase == "SuddenDeath" and quetzalScore > jaguarScore) then
			finish("Quetzal")
		elseif teamMissing then
			finish(if jaguar > 0 then "Jaguar" elseif quetzal > 0 then "Quetzal" else nil)
		elseif phase == "Battle" and now() >= (endsAt() or 0) then
			if jaguarScore == quetzalScore then
				setPhase("SuddenDeath", nil)
				Remotes.Notify:FireAllClients("⚡ ¡Empate! Muerte súbita: la siguiente captura gana")
			else
				finish(if jaguarScore > quetzalScore then "Jaguar" else "Quetzal")
			end
		end
	elseif phase == "Results" then
		if now() >= (endsAt() or 0) then
			startWaiting()
			RespawnService.respawnAll()
		end
	end
end

-- Panel de pruebas.
function ArenaMatchService.debugSolo()
	solo = true
	if Arena.phase() == "Waiting" then
		startCountdown()
	end
end

function ArenaMatchService.debugNextFormat(): number
	local format = Arena.format() % Config.Arena.MaxFormat + 1
	setFormat(format)
	return format
end

function ArenaMatchService.debugSkipPhase()
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

function ArenaMatchService:Start()
	-- En Start y no en Init: usa el escenario (ArenaWorldService), que se prepara en su Init.
	setFormat(Config.Arena.StudioFormat)
	startWaiting()
	Players.PlayerAdded:Connect(readFormat)
	for _, player in Players:GetPlayers() do
		readFormat(player)
	end
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			tick()
		end
	end)
end

return ArenaMatchService
