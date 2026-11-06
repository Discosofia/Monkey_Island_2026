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
-- Aquí va lo común a todos los modos (Config.Arena.Modes: Captura la bandera y Juego de pelota); lo que cambia de uno a
-- otro (cómo se puntúa, cuándo acaba, quién gana) está en Modes/ (Modes/Types).
-- El estado va en atributos (Shared/Arena). El modo y el formato (jugadores por equipo) llegan del Lobby en
-- el viaje (TeleportData "mode" y "format"); en Studio, Config.Arena.StudioMode y StudioFormat o el panel de
-- pruebas. El modo en curso va en Workspace "ArenaMode" (Shared/ArenaModes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local ArenaModes = require(ReplicatedStorage.Shared.ArenaModes)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)
local Ballgame = require(script.Parent.Parent.Modes.Ballgame)
local CaptureFlag = require(script.Parent.Parent.Modes.CaptureFlag)
local Types = require(script.Parent.Parent.Modes.Types)
local ArenaWorldService = require(script.Parent.ArenaWorldService)
local BallBotService = require(script.Parent.BallBotService)
local RespawnService = require(script.Parent.RespawnService)
local TeamService = require(script.Parent.TeamService)

local TICK_SECONDS = 0.25
-- Las estadísticas comunes; el modo reinicia las suyas (Captura la bandera: "ArenaCaptures").
local STAT_ATTRIBUTES = { "ArenaKills", "ArenaDeaths" }

-- Un modo por clave de Config.Arena.ModeNames.
local MODES: { [string]: Types.Mode } = {
	CaptureFlag = CaptureFlag,
	Ballgame = Ballgame,
}

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

local function mode(): Types.Mode
	return MODES[ArenaModes.current()]
end

local function setPhase(phase: Arena.Phase, seconds: number?)
	ReplicatedStorage:SetAttribute("ArenaPhase", phase)
	ReplicatedStorage:SetAttribute("ArenaPhaseEndsAt", if seconds then now() + seconds else nil)
end

local function endsAt(): number?
	local value = ReplicatedStorage:GetAttribute("ArenaPhaseEndsAt")
	return if typeof(value) == "number" then value else nil
end

-- El formato más cercano que admite el modo en curso.
local function setFormat(format: number)
	local current = mode()
	format = current.format(format)
	ReplicatedStorage:SetAttribute("ArenaFormat", format)
	current.publish(format)
	ArenaWorldService.setFormat(format)
end

-- Cambia el modo (solo uno de Config.Arena.Modes): el anterior deshace lo suyo y el escenario se prepara
-- para el nuevo.
local function setMode(modeId: string)
	if not (MODES[modeId] and table.find(Config.Arena.Modes, modeId)) then
		return
	end
	mode().stop()
	Workspace:SetAttribute("ArenaMode", modeId)
	ArenaWorldService.setMode(modeId)
	setFormat(Arena.format())
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
	if typeof(data.mode) == "string" then
		setMode(data.mode)
	end
	if typeof(data.format) == "number" then
		setFormat(data.format)
	end
end

local function startWaiting()
	solo = false
	mode().reset()
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

local function finish(winner: string?)
	ReplicatedStorage:SetAttribute("ArenaWinner", winner or "")
	setPhase("Results", Config.Arena.ResultsSeconds)
	if winner then
		local team = Config.Arena.Teams[winner]
		Remotes.Notify:FireAllClients("🏆 ¡Gana el equipo {icon} {name}!", { icon = team.icon, name = team.name })
	else
		Remotes.Notify:FireAllClients("🤝 Empate")
	end
	for _, listener in finishListeners do
		task.spawn(listener, winner)
	end
end

local ctx: Types.Context = {
	setPhase = setPhase,
	finish = finish,
	isSolo = ArenaMatchService.isSolo,
}

local function startBattle()
	for _, player in Players:GetPlayers() do
		for _, attribute in STAT_ATTRIBUTES do
			player:SetAttribute(attribute, 0)
		end
	end
	mode().start(ctx)
end

-- Un equipo ha capturado la bandera rival (FlagService): el modo en curso decide qué suma.
function ArenaMatchService.addCapture(teamId: string)
	mode().capture(teamId)
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
		setPhase("Waiting", Config.Arena.WaitSeconds)
		return
	end
	local current = mode()
	local allReady = true
	for _, player in players do
		if not (Arena.teamOf(player) and player:GetAttribute("ArenaReady") == true) then
			allReady = false
		end
	end
	if solo or (current.full() and allReady) then
		startCountdown()
	elseif now() >= deadline then
		TeamService.assignMissing()
		if current.enough() then
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
	if phase == "Waiting" then
		tickWaiting()
	elseif phase == "Countdown" then
		if mode().abandoned(ctx) then
			Remotes.Notify:FireAllClients("Un equipo se ha quedado vacío: se espera a más jugadores")
			setPhase("Waiting", Config.Arena.WaitSeconds)
		elseif now() >= (endsAt() or 0) then
			startBattle()
		end
	elseif phase == "Battle" or phase == "SuddenDeath" then
		mode().tick(ctx, phase)
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
	-- En el Juego de pelota, probar en solitario es con el saque lento (el panel lo apaga).
	if ArenaModes.current() == "Ballgame" then
		Ballgame.debugSlowServe(true)
	end
	if Arena.phase() == "Waiting" then
		startCountdown()
	end
end

-- Cambia el modo desde el panel, en cualquier fase: el modo en curso se para y se limpia (se cancela la partida y
-- se apagan los rivales de prueba), se prepara el mapa del nuevo y se vuelve a Waiting con todos en su punto de
-- espera. Devuelve false si el modo no existe.
function ArenaMatchService.debugSetMode(modeId: string): boolean
	if not (MODES[modeId] and table.find(Config.Arena.Modes, modeId)) then
		return false
	end
	BallBotService.clear()
	mode().reset() -- el modo viejo: se para (deja la pelota y el saque lento) y borra su marcador
	setMode(modeId)
	startWaiting() -- solo = false, marcador del nuevo a cero, puertas abiertas, fase Waiting y reloj de espera
	RespawnService.respawnAll()
	return true
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
	setMode(Config.Arena.StudioMode)
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
