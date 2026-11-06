--!strict
-- Juego de pelota de Dunas (Fase 26e): las reglas y el partido. Gana el primero en llegar a RaysToWin rayas, el
-- primero que pase la pelota por el aro, o el que más rayas tenga al acabar el tiempo (con empate, muerte súbita:
-- la siguiente raya gana). La pelota (BallService) y el golpe (BallHitService) ya existen; aquí solo se escuchan sus
-- eventos y se decide quién anota. Todo va en coordenadas LOCALES de la cancha (Shared/CourtGeometry).
-- Los avisos para el HUD (26g): atributos BallgameCall / BallgameCallTeam / BallgameCallSeq de ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local BallgameData = require(ReplicatedStorage.Shared.Data.Ballgame)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local BallHitService = require(script.Parent.Parent.Services.BallHitService)
local BallService = require(script.Parent.Parent.Services.BallService)
local RespawnService = require(script.Parent.Parent.Services.RespawnService)
local Types = require(script.Parent.Types)

local T = Strings.later

type RingAttempt = { team: string, minDist: number, rim: boolean }

local Ballgame = {}

local state = "Idle" -- Idle | Live | Pause | Over
local savedCtx: Types.Context? = nil
local bounces: { [string]: number } = { Jaguar = 0, Quetzal = 0 }
local lastToucher: string? = nil
local flightClean = false
local servingTeam: string? = nil
local pauseUntil = 0
local restSince: number? = nil
local ringAttempt: RingAttempt? = nil
local callSeq = 0
local disconnects: { () -> () } = {}
local heartbeat: RBXScriptConnection? = nil
-- Saque lento (pruebas, Fase 27b): la pelota espera quieta en el suelo y no se cuentan botes ni pelota parada hasta
-- el primer golpe o roce (waitingServe).
local slowServe = false
local waitingServe = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rival(team: string): string
	return Arena.otherTeam(team)
end

local function setScore(teamId: string, value: number)
	ReplicatedStorage:SetAttribute(`ArenaScore_{teamId}`, value)
end

local function resetScores()
	for _, teamId in Arena.TEAM_IDS do
		setScore(teamId, 0)
	end
end

-- Botes seguidos en el campo de cada equipo, para los puntos del HUD (BallgameBounces_<equipo>).
local function publishBounces()
	for _, teamId in Arena.TEAM_IDS do
		ReplicatedStorage:SetAttribute(`BallgameBounces_{teamId}`, bounces[teamId])
	end
end

local function resetRound()
	bounces = { Jaguar = 0, Quetzal = 0 }
	publishBounces()
	lastToucher = nil
	flightClean = false
	restSince = nil
	ringAttempt = nil
	waitingServe = false
end

local function teamSizes(): (number, number)
	return #Arena.membersOf("Jaguar"), #Arena.membersOf("Quetzal")
end

-- Publica el aviso de la raya: atributos para el HUD y el cartel para todos.
local function announce(call: string, team: string, notify: boolean)
	callSeq += 1
	ReplicatedStorage:SetAttribute("BallgameCall", call)
	ReplicatedStorage:SetAttribute("BallgameCallTeam", team)
	ReplicatedStorage:SetAttribute("BallgameCallSeq", callSeq)
	local template = BallgameData.Calls[call]
	local teamDef = Config.Arena.Teams[team]
	if notify and template and teamDef then
		Remotes.Notify:FireAllClients(template, { icon = teamDef.icon, name = teamDef.name })
	end
end

local function endMatch(winner: string, call: string)
	if state == "Over" then
		return
	end
	state = "Over"
	BallService.setActive(false)
	-- Sin Notify: el banner del HUD (BallgameCall) ya dice «¡Aro! Gana …» y el de ArenaMatchService.finish
	-- anuncia al ganador; con los dos carteles el segundo borraba al primero.
	announce(call, winner, false)
	local ctx = savedCtx
	if ctx then
		ctx.finish(winner)
	end
end

-- Saca la pelota: el lob va al campo del equipo que perdió la última raya (o del sorteado).
local function serveNow()
	state = "Live"
	resetRound()
	BallService.setActive(true)
	if slowServe then
		-- Quieta en el suelo, en el campo del equipo que saca (el mismo al que iría el lob); al azar si no hay.
		local sign = CourtGeometry.sideSign(servingTeam or Arena.TEAM_IDS[math.random(1, #Arena.TEAM_IDS)])
		local x = sign * BallService.layout().halfLength / 2
		BallService.place(Vector3.new(x, CourtGeometry.BALL_RADIUS + BallgameData.Serve.RestClearance, 0), Vector3.zero)
		waitingServe = true
	else
		BallService.serve(servingTeam)
	end
end

local function addPoint(team: string, call: string)
	if state ~= "Live" or not Arena.inBattle() then
		return
	end
	setScore(team, Arena.score(team) + 1)
	ringAttempt = nil
	waitingServe = false
	if Arena.score(team) >= Config.Arena.Ballgame.RaysToWin or Arena.phase() == "SuddenDeath" then
		endMatch(team, call)
		return
	end
	state = "Pause"
	pauseUntil = now() + Config.Arena.Ballgame.PointPauseSeconds
	servingTeam = rival(team)
	BallService.setActive(false)
	announce(call, team, false)
end

-- Cierra el intento al aro: si fue un tiro bueno (Perfect) que se acercó o tocó el borde y no pasó, falta del que tiró.
local function resolveAttempt()
	local attempt = ringAttempt
	ringAttempt = nil
	if attempt and (attempt.rim or attempt.minDist <= Config.Arena.Ballgame.RingAttemptDistance) then
		addPoint(rival(attempt.team), "RingMiss")
	end
end

local function onHit(info: BallHitService.HitInfo)
	if state ~= "Live" then
		return
	end
	waitingServe = false -- el primer golpe o roce acaba el saque lento
	if not info.team then
		return
	end
	if info.zone == "Foot" then
		ringAttempt = nil
		addPoint(rival(info.team), "Foot")
		return
	end
	-- Cualquier otro golpe cierra el intento anterior antes de empezar el suyo.
	resolveAttempt()
	if state ~= "Live" then
		return
	end
	-- El roce pasivo también cuenta como toque.
	lastToucher = info.team
	bounces[info.team] = 0
	publishBounces()
	flightClean = true
	restSince = nil
	if info.quality == "Perfect" then
		ringAttempt = { team = info.team, minDist = math.huge, rim = false }
	end
end

local function onBounce(event: any)
	local surface = event.surface
	if surface ~= "Floor" and surface ~= "Bench" and surface ~= "Riser" and surface ~= "Talud" then
		return
	end
	local side = event.side
	if (surface == "Floor" or surface == "Bench") and typeof(side) == "string" then
		bounces[side] += 1
		bounces[rival(side)] = 0
		publishBounces()
		if bounces[side] > Config.Arena.Ballgame.MaxBounces then
			addPoint(rival(side), "ThreeBounces")
		end
	end
	if state ~= "Live" then
		return
	end
	flightClean = false
	resolveAttempt()
end

local function onEndWall(event: any)
	resolveAttempt()
	local defender = if typeof(event.sign) == "number" then CourtGeometry.teamOfSide(event.sign) else nil
	local toucher = lastToucher
	if state ~= "Live" or not flightClean or toucher == nil or defender == nil then
		return
	end
	if toucher ~= defender then
		addPoint(toucher, "EndWall")
	else
		addPoint(rival(defender), "OwnEndWall")
	end
end

local function onOut(event: any)
	resolveAttempt()
	if state ~= "Live" then
		return
	end
	local culprit = lastToucher
	if culprit == nil and typeof(event.pos) == "Vector3" then
		culprit = CourtGeometry.teamOfSide(event.pos.X)
	end
	if culprit then
		addPoint(rival(culprit), "Out")
	else
		serveNow() -- nadie tiene la culpa: se repite el saque sin raya
	end
end

local function onRingPass()
	local toucher = lastToucher
	if state ~= "Live" or toucher == nil then
		return
	end
	ringAttempt = nil
	setScore(toucher, Arena.score(toucher) + 1)
	endMatch(toucher, "Ring")
end

local function onBallEvent(event: any)
	if state ~= "Live" then
		return
	end
	local kind = event.kind
	if kind == "bounce" then
		if not waitingServe then
			onBounce(event)
		end
	elseif kind == "endWall" then
		onEndWall(event)
	elseif kind == "out" then
		onOut(event)
	elseif kind == "ringPass" then
		onRingPass()
	elseif kind == "ringRim" then
		local attempt = ringAttempt
		if attempt then
			attempt.rim = true
		end
	end
end

-- Mientras hay un intento al aro, anota lo cerca que pasa la pelota del centro de cada aro.
local function onHeartbeat()
	local attempt = ringAttempt
	if state ~= "Live" or attempt == nil then
		return
	end
	local ring = BallService.layout().ring
	local pos = BallService.state().pos
	for _, sign in { -1, 1 } do
		local center = Vector3.new(ring.centerX, ring.centerY, sign * ring.centerZ)
		attempt.minDist = math.min(attempt.minDist, (pos - center).Magnitude)
	end
end

local function disconnectAll()
	for _, disconnect in disconnects do
		disconnect()
	end
	disconnects = {}
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

function Ballgame.format(requested: number): number
	return math.clamp(math.floor(requested), Config.Arena.MinFormat, Config.Arena.MaxFormat)
end

function Ballgame.publish(_format: number) end

function Ballgame.full(): boolean
	local jaguar, quetzal = teamSizes()
	local format = Arena.format()
	return jaguar == format and quetzal == format
end

function Ballgame.enough(): boolean
	local jaguar, quetzal = teamSizes()
	return jaguar > 0 and quetzal > 0
end

function Ballgame.abandoned(ctx: Types.Context): boolean
	local jaguar, quetzal = teamSizes()
	return not ctx.isSolo() and (jaguar == 0 or quetzal == 0)
end

-- Deja el modo parado sin tocar el saque lento (start lo usa: la bandera la pone el panel antes de empezar).
local function halt()
	disconnectAll()
	state = "Idle"
	savedCtx = nil
	waitingServe = false
	BallService.setActive(false)
end

function Ballgame.stop()
	halt()
	slowServe = false
end

function Ballgame.reset()
	Ballgame.stop()
	resetScores()
	resetRound()
end

function Ballgame.start(ctx: Types.Context)
	halt()
	savedCtx = ctx
	resetScores()
	resetRound()
	ctx.setPhase("Battle", Config.Arena.Ballgame.MatchSeconds)
	RespawnService.respawnAll()
	-- La pelota se activa al sacar (serveNow), no durante la pausa del primer saque.
	servingTeam = Arena.TEAM_IDS[math.random(1, #Arena.TEAM_IDS)]
	state = "Pause"
	pauseUntil = now() + Config.Arena.Ballgame.PointPauseSeconds
	table.insert(disconnects, BallHitService.onHit(onHit))
	table.insert(disconnects, BallService.onEvent(onBallEvent))
	heartbeat = RunService.Heartbeat:Connect(onHeartbeat)
	Remotes.Notify:FireAllClients(
		T("¡Que empiece el partido! Primero a {n} rayas o el aro"),
		{ n = Config.Arena.Ballgame.RaysToWin }
	)
end

function Ballgame.tick(ctx: Types.Context, phase: Arena.Phase)
	if state == "Over" then
		return
	end
	if Ballgame.abandoned(ctx) then
		local jaguar, quetzal = teamSizes()
		local winner = if jaguar > 0 then "Jaguar" elseif quetzal > 0 then "Quetzal" else nil
		if winner then
			endMatch(winner, "Time")
		else
			state = "Over"
			BallService.setActive(false)
			ctx.finish(nil)
		end
		return
	end

	if phase == "Battle" then
		local endsAt = ReplicatedStorage:GetAttribute("ArenaPhaseEndsAt")
		if now() >= (if typeof(endsAt) == "number" then endsAt else 0) then
			local jaguarScore, quetzalScore = Arena.score("Jaguar"), Arena.score("Quetzal")
			if jaguarScore == quetzalScore then
				ctx.setPhase("SuddenDeath", nil)
				Remotes.Notify:FireAllClients(T("¡Empate! Muerte súbita: la siguiente raya gana"))
			else
				endMatch(if jaguarScore > quetzalScore then "Jaguar" else "Quetzal", "Time")
				return
			end
		end
	end

	if state == "Pause" then
		if now() >= pauseUntil then
			serveNow()
		end
	elseif state == "Live" then
		-- Con la pelota esperando el saque lento no cuenta como parada.
		if BallService.state().resting and not waitingServe then
			local since = restSince
			if since == nil then
				restSince = now()
				resolveAttempt()
			elseif now() - since >= Config.Arena.Ballgame.RestSeconds then
				ringAttempt = nil
				local defender = CourtGeometry.teamOfSide(BallService.state().pos.X)
				if defender then
					addPoint(rival(defender), "Stalled")
				else
					serveNow() -- parada justo en la línea central: se repite el saque sin raya
				end
			end
		else
			restSince = nil
		end
	end
end

-- El juego de pelota no puntúa por capturas.
function Ballgame.capture(_teamId: string) end

-- Pruebas (ArenaDebugService): da la raya ya, también en la pausa entre rayas.
function Ballgame.debugPoint(team: string, call: string)
	if state == "Pause" then
		state = "Live"
	end
	addPoint(team, call)
end

-- Saque lento (Fase 27b): con él, el saque deja la pelota quieta en el suelo hasta el primer golpe. Al apagarlo
-- con la pelota esperando, se repite el saque con el lob de siempre.
function Ballgame.debugSlowServe(enabled: boolean)
	slowServe = enabled
	if not enabled and waitingServe and state == "Live" then
		serveNow()
	end
end

function Ballgame.debugIsSlowServe(): boolean
	return slowServe
end

-- Con el saque lento, una pelota colocada a mano (BallPlace) también espera quieta al primer golpe.
function Ballgame.debugHold()
	if slowServe and state == "Live" then
		waitingServe = true
	end
end

-- ¿La pelota espera el primer golpe del saque lento?
function Ballgame.debugWaitingServe(): boolean
	return waitingServe
end

function Ballgame.debugState(): string
	local attempt = ringAttempt
	return string.format(
		"state=%s slowServe=%s waitingServe=%s score=%d-%d bounces=%d/%d lastToucher=%s flightClean=%s serving=%s ringAttempt=%s",
		state,
		tostring(slowServe),
		tostring(waitingServe),
		Arena.score("Jaguar"),
		Arena.score("Quetzal"),
		bounces.Jaguar,
		bounces.Quetzal,
		tostring(lastToucher),
		tostring(flightClean),
		tostring(servingTeam),
		if attempt
			then string.format("{team=%s minDist=%.1f rim=%s}", attempt.team, attempt.minDist, tostring(attempt.rim))
			else "nil"
	)
end

return Ballgame :: Types.Mode & {
	debugPoint: (team: string, call: string) -> (),
	debugState: () -> string,
	debugSlowServe: (enabled: boolean) -> (),
	debugIsSlowServe: () -> boolean,
	debugWaitingServe: () -> boolean,
	debugHold: () -> (),
}
