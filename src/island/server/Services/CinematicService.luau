--!strict
-- Cinemáticas de la Isla (Fase 25). El servidor decide quién ve qué escena de Data/Cinematics y cuándo
-- termina; el dibujo, la cámara y los actores son del cliente (CinematicController, con Shared/Cinematics).
--   - play(id, opts): avisa a la audiencia (Remotes.Cinematic "Play" con la hora del servidor de arranque, y el
--     cliente hace seek si llega tarde). Con scene.freeze bloquea la IA, el daño, el hambre y la sed
--     (Combat/CinematicLock). Los de la audiencia quedan protegidos (InvulnerableUntil, el atributo que lee
--     CombatService) con o sin freeze.
--   - La escena termina cuando todos los de la audiencia mandan Remotes.CinematicDone, o a los duration + 2 s.
--     Quien se va no bloquea el final. Si se vio entera (watchedFully), la escena entra en el perfil
--     (cinematicsSeen) y el cliente la puede saltar la próxima vez.
--   - Una escena con audiencia "All" (sin opts.audience) también la ve quien entra a mitad.
--   - Una escena a la vez por id, y ninguna con freeze si ya hay un bloqueo en marcha. Excepción: una escena sin
--     freeze con un solo jugador de audiencia (la llegada, la travesía) es una ejecución propia de ese jugador, así
--     que varios amigos pueden verla a la vez cada uno con la suya (la clave de `running` lleva su UserId).
--   - Eventos de servidor: un evento de la escena con server = true no lo toca el cliente; el servidor llama a
--     la función que registró registerServerEvent(kind, fn(event, run)) a los event.t segundos. Si la escena
--     acaba antes (todos la saltan o el ajuste está apagado), los que no han salido y son essential = true se
--     ejecutan en ese momento, y el resto se descartan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CameraPath = require(ReplicatedStorage.Shared.Cinematics.CameraPath)
local Cinematics = require(ReplicatedStorage.Shared.Data.Cinematics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CinematicLock = require(ServerScriptService.Combat.CinematicLock)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

-- Margen sobre la duración de la escena antes de darla por terminada aunque falte alguien.
local END_MARGIN_SECONDS = 4
-- Espera antes de avisar a quien entra a mitad de una escena (que su cliente tenga el controlador listo).
local JOIN_DELAY_SECONDS = 1.5
-- Cuánto espera la carga del terreno de la escena (RequestStreamAroundAsync) antes de empezar.
local STREAM_TIMEOUT_SECONDS = 1.5
-- Cada cuánto se renueva esa petición mientras dura la escena.
local STREAM_RENEW_SECONDS = 1
-- Escenas que cruzan la isla (scene.streamFollowsCamera): el terreno se pide donde estará la cámara dentro de
-- STREAM_LEAD_SECONDS, y la primera carga espera más (el primer plano está lejos del jugador).
local STREAM_LEAD_SECONDS = 2.5
local STREAM_FOLLOW_TIMEOUT_SECONDS = 5

export type PlayOptions = {
	audience: { Player }?, -- por defecto, todos los jugadores (y quien entre a mitad)
	anchor: CFrame?, -- dónde se ancla la escena; sin él, el cliente usa el de la escena
	bossId: string?, -- qué jefe es el anchor "boss" (si no, el primero que haya)
	noFreeze: boolean?, -- ignora scene.freeze (el plató de grabación no debe congelar el juego real)
	context: { [string]: any }?, -- datos para los eventos de servidor (run.context)
	onFinished: (() -> ())?,
}

export type Run = {
	id: string,
	startTime: number, -- hora del servidor en que arrancó
	endTime: number, -- hora del servidor en que acaba la escena
	freeze: boolean,
	args: { [string]: any },
	everyone: boolean, -- audiencia "All": entra también quien llegue a mitad
	audience: { [Player]: boolean },
	pending: { [Player]: boolean }, -- aún no han mandado CinematicDone
	protectedUntil: { [Player]: number },
	context: { [string]: any },
	serverEvents: { { event: { [string]: any }, fired: boolean } },
	cleanups: { () -> () }, -- lo que los eventos de servidor piden borrar al acabar (CinematicService.onEnd)
	onFinished: (() -> ())?,
	finished: boolean,
	key: string, -- clave en `running`
}

local CinematicService = {}

local running: { [string]: Run } = {}

-- Clave de `running`: el id, o id + UserId si es una escena sin freeze de un solo jugador (ejecución independiente).
local function runKey(id: string, audience: { Player }?, freeze: boolean): string
	if not freeze and audience and #audience == 1 then
		return `{id}#{audience[1].UserId}`
	end
	return id
end

-- La ejecución en marcha de "id" que ve "player" (la suya o la compartida).
local function runOf(id: string, player: Player): Run?
	for _, run in running do
		if run.id == id and run.audience[player] then
			return run
		end
	end
	return nil
end
local serverHandlers: { [string]: (event: { [string]: any }, run: Run) -> () } = {}

-- Registra la función de un tipo de evento de servidor (server = true en la escena). Una por tipo.
function CinematicService.registerServerEvent(kind: string, fn: (event: { [string]: any }, run: Run) -> ())
	serverHandlers[kind] = fn
end

-- Apunta una función que se llama cuando la ejecución "run" acaba (por duración, por saltarla o por margen), para
-- que un evento de servidor borre lo que creó (los monos de las batallas). Si ya acabó, se llama al momento.
function CinematicService.onEnd(run: Run, fn: () -> ())
	if run.finished then
		task.spawn(fn)
		return
	end
	table.insert(run.cleanups, fn)
end

local function fireServerEvent(run: Run, entry: { event: { [string]: any }, fired: boolean })
	if entry.fired then
		return
	end
	entry.fired = true
	local fn = serverHandlers[entry.event.kind]
	if not fn then
		warn(`[CinematicService] Evento de servidor sin handler: {entry.event.kind}`)
		return
	end
	local ok, err = pcall(fn, entry.event, run)
	if not ok then
		warn(`[CinematicService] Falla el evento de servidor {entry.event.kind}: {err}`)
	end
end

-- true si hay alguna ejecución de la escena "id" en marcha (de cualquier jugador).
function CinematicService.isRunning(id: string): boolean
	for _, run in running do
		if run.id == id then
			return true
		end
	end
	return false
end

-- true si "player" ve ahora mismo alguna escena, sea cual sea (WeatherService no le echa rayos en mitad de una).
function CinematicService.isPlayingFor(player: Player): boolean
	for _, run in running do
		if not run.finished and run.audience[player] then
			return true
		end
	end
	return false
end

-- true si "player" tiene en marcha la escena "id" (su ejecución propia o una compartida que ve).
function CinematicService.isRunningFor(id: string, player: Player): boolean
	return runOf(id, player) ~= nil
end

-- true si ya vio la escena entera (perfil cinematicsSeen).
function CinematicService.hasSeen(player: Player, id: string): boolean
	local profile = PlayerData.get(player)
	return profile ~= nil and profile.cinematicsSeen[id] == true
end

-- Protege a "player" hasta que acabe la escena (y un margen).
local function protect(run: Run, player: Player)
	local untilTime = run.endTime + END_MARGIN_SECONDS
	local current = player:GetAttribute("InvulnerableUntil")
	if typeof(current) == "number" and current >= untilTime then
		return
	end
	run.protectedUntil[player] = untilTime
	player:SetAttribute("InvulnerableUntil", untilTime)
end

local function finish(run: Run, timedOut: boolean)
	if run.finished then
		return
	end
	run.finished = true
	if running[run.key] == run then
		running[run.key] = nil
	end
	-- Los eventos esenciales que no han salido (la escena acabó antes) salen ahora; el resto se descarta.
	for _, entry in run.serverEvents do
		if not entry.fired and entry.event.essential == true then
			fireServerEvent(run, entry)
		end
		entry.fired = true
	end
	for _, cleanup in run.cleanups do
		local ok, err = pcall(cleanup)
		if not ok then
			warn(`[CinematicService] Falla una limpieza de {run.id}: {err}`)
		end
	end
	table.clear(run.cleanups)
	if run.freeze then
		CinematicLock.unlock()
	end
	for player, untilTime in run.protectedUntil do
		-- Solo se quita lo nuestro: si otra cosa (la esquiva) lo cambió, se deja.
		if player.Parent and player:GetAttribute("InvulnerableUntil") == untilTime then
			player:SetAttribute("InvulnerableUntil", nil)
		end
	end
	if timedOut then
		for player in run.pending do
			if player.Parent then
				Remotes.Cinematic:FireClient(player, "Stop", run.id)
			end
		end
	end
	table.clear(run.pending)
	local onFinished = run.onFinished
	if onFinished then
		task.spawn(onFinished)
	end
end

local function checkFinished(run: Run)
	if not run.finished and next(run.pending) == nil then
		finish(run, false)
	end
end

local function addViewer(run: Run, player: Player, startTime: number)
	run.audience[player] = true
	run.pending[player] = true
	protect(run, player)
	local anchor = run.args.anchor
	if typeof(anchor) == "CFrame" then
		local scene = Cinematics[run.id]
		local follow = scene ~= nil and scene.streamFollowsCamera == true
		-- Dónde pedir el terreno en el instante "seconds" de la escena: el ancla o, si la escena la sigue, la cámara.
		local function streamPoint(seconds: number): Vector3
			if follow then
				local position = CameraPath.sampleTimed(scene.camera, seconds)
				return anchor:PointToWorldSpace(position)
			end
			return anchor.Position
		end
		-- Con StreamingEnabled la escena puede estar lejos del jugador: se pide que se cargue antes de empezar
		-- (el cliente salta al tiempo que le toca si tarda). Sin streaming no hace nada.
		task.spawn(function()
			local first = if follow then STREAM_FOLLOW_TIMEOUT_SECONDS else STREAM_TIMEOUT_SECONDS
			pcall(player.RequestStreamAroundAsync, player, streamPoint(0), first)
			if not run.finished and player.Parent then
				Remotes.Cinematic:FireClient(player, "Play", run.id, startTime, run.args)
			end
			-- La carga caduca a los pocos segundos y el jefe y el decorado, lejos del jugador, se descargan en
			-- mitad de la escena: se renueva la petición mientras dure.
			while not run.finished and player.Parent do
				task.wait(STREAM_RENEW_SECONDS)
				if run.finished or not player.Parent then
					break
				end
				local elapsed = Workspace:GetServerTimeNow() - run.startTime
				pcall(
					player.RequestStreamAroundAsync,
					player,
					streamPoint(elapsed + STREAM_LEAD_SECONDS),
					STREAM_RENEW_SECONDS
				)
			end
		end)
		return
	end
	Remotes.Cinematic:FireClient(player, "Play", run.id, startTime, run.args)
end

-- Lanza la escena "id" de Data/Cinematics. Devuelve false si no existe o no se puede (ya está en marcha o
-- hay otra con bloqueo).
function CinematicService.play(id: string, opts: PlayOptions?): boolean
	local options: PlayOptions = opts or {}
	local scene = Cinematics[id]
	if not scene then
		warn(`[CinematicService] No existe la escena {id}`)
		return false
	end
	local freeze = scene.freeze and options.noFreeze ~= true
	local key = runKey(id, options.audience, freeze)
	if running[key] or (freeze and CinematicLock.active()) then
		return false
	end
	local now = Workspace:GetServerTimeNow()
	local args: { [string]: any } = {}
	args.anchor = options.anchor
	args.bossId = options.bossId
	local run: Run = {
		id = id,
		startTime = now,
		endTime = now + scene.duration,
		freeze = freeze,
		args = args,
		everyone = options.audience == nil,
		audience = {},
		pending = {},
		protectedUntil = {},
		context = options.context or {},
		serverEvents = {},
		cleanups = {},
		onFinished = options.onFinished,
		finished = false,
		key = key,
	}
	running[key] = run
	if freeze then
		CinematicLock.lock(run.endTime + END_MARGIN_SECONDS)
	end
	for _, event in scene.events do
		if event.server == true then
			local entry = { event = event :: { [string]: any }, fired = false }
			table.insert(run.serverEvents, entry)
			task.delay(event.t, function()
				if not run.finished then
					fireServerEvent(run, entry)
				end
			end)
		end
	end
	for _, player in options.audience or Players:GetPlayers() do
		if player.Parent then
			addViewer(run, player, now)
		end
	end
	-- Sin nadie que la vea acaba al momento.
	if next(run.pending) == nil then
		task.defer(checkFinished, run)
	end
	task.delay(scene.duration + END_MARGIN_SECONDS, finish, run, true)
	return true
end

-- Quien entra a mitad de una escena con audiencia "All": protección y "Play" con la hora original.
local function onCharacterAdded(player: Player)
	task.wait(JOIN_DELAY_SECONDS)
	if not player.Parent then
		return
	end
	for _, run in running do
		if run.everyone and not run.finished and not run.audience[player] then
			if Workspace:GetServerTimeNow() < run.endTime then
				addViewer(run, player, run.startTime)
			end
		end
	end
end

local function onPlayerAdded(player: Player)
	-- Con freeze, CinematicLock ya protege a quien entra desde el primer momento; el aviso llega tras la espera.
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player)
	end
end

function CinematicService:Start()
	Remotes.CinematicDone.OnServerEvent:Connect(function(player: Player, id: any, watchedFully: any)
		if typeof(id) ~= "string" then
			return
		end
		local run = runOf(id, player)
		if not run then
			return
		end
		if watchedFully == true and not CinematicService.hasSeen(player, id) then
			PlayerData.update(player, function(profile)
				profile.cinematicsSeen[id] = true
			end)
		end
		run.pending[player] = nil
		checkFinished(run)
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, run in running do
			run.pending[player] = nil
			run.protectedUntil[player] = nil
			checkFinished(run)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CinematicService
