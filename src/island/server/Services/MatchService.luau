--!strict
-- Fin de la partida (GDD §5.3, Fase 2.7).
--   - Derrota: de noche, si todos los jugadores están caídos a la vez durante
--     Config.Match.DefeatGraceSeconds seguidos.
--   - Al terminar: se para el ciclo de día y noche, cada jugador ve su resumen (días, monos,
--     reanimaciones, caídas y Ámbar ganado) y a los Config.Match.ResultsSeconds todos vuelven al Lobby.
--   - Otros servicios (el guardado de datos, 2.8) se enteran con MatchService.onMatchEnded.
--   - Victoria (la baliza, BeaconService): si el jugador tiene un huevo incubando en el nido del Lobby,
--     le toca una tirada que le quita horas o lo deja listo (ServerShared/Eggs); el resultado va en su
--     resumen ("eggRoll") y la pantalla de resultados lo enseña con una ruleta. La primera victoria de
--     verdad (no la del panel de pruebas) da el título "Superviviente de la Isla" ("newTitle").
--   - XP del pase de temporada (Config.Season.IslandXp, ServerShared/SeasonPass): por día, jefe, huevo
--     salvado y rescate, con el tope de hoy; lo sumado va en el resumen ("pass") para los resultados.
--   - Fase 12, P1, "Seguir sobreviviendo": la victoria no cierra la partida. Al rescate se paga todo
--     (resumen con phase "Rescue") y cada jugador elige en Config.Match.ResultsSeconds si sigue
--     (remoto ChooseContinue) o vuelve al Lobby; quien no elige, vuelve. Si sigue alguien, la partida
--     continúa sin admitir a nadie nuevo, y su final (todos caídos de noche) solo paga lo de después
--     del rescate (phase "Endless": días, bajas y jefes extra, sin otro rescate). "days" es el total,
--     para el récord.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MatchStats = require(ReplicatedStorage.Shared.MatchStats)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)
local Eggs = require(ServerScriptService.ServerShared.Eggs)
local SeasonPass = require(ServerScriptService.ServerShared.SeasonPass)
local Teleporter = require(ServerScriptService.ServerShared.Teleporter)
local DayNightService = require(script.Parent.DayNightService)

export type Result = "Defeat" | "Victory"
-- "Rescue": la victoria (se paga todo y se puede seguir). "Endless": el final de una partida que siguió
-- tras el rescate. nil: una derrota sin rescate.
export type Phase = "Rescue" | "Endless"

export type Summary = {
	result: Result,
	phase: Phase?,
	-- Días sobrevividos en total (para el récord), también en "Endless".
	days: number,
	-- "Endless": los días después del rescate (los que se pagan).
	extraDays: number?,
	-- "Rescue": el jugador puede elegir seguir sobreviviendo.
	canContinue: boolean?,
	kills: number,
	revives: number,
	deaths: number,
	bosses: number,
	amber: number,
	-- Multiplicador del evento en vivo "Doble Ámbar" (T4b), si lo había al terminar.
	amberBoost: number?,
	eggRoll: Eggs.RescueOutcome?,
	-- Terminada con el panel de pruebas de Studio: no cuenta para el récord, los rescates ni el ranking.
	test: boolean?,
	-- Primera victoria de verdad: acaba de ganar el título "Superviviente de la Isla".
	newTitle: boolean?,
	-- XP del pase de temporada sumada (nil sin temporada en marcha).
	pass: SeasonPass.Gain?,
}

local MatchService = {}

-- Título que se gana al rescatarse por primera vez (Data/Cosmetics, sin Game Pass).
local SURVIVOR_TITLE = "TitleSurvivor"

local ended = false
-- Rescatados (Fase 12): la partida sigue para quien lo elija.
local rescued = false
local rescueDays = 0
local rescueTest = false
-- Lo que llevaba cada jugador al rescate: el final "Endless" solo paga lo de después.
local snapshots: { [Player]: { [string]: number } } = {}
-- Quien eligió seguir sobreviviendo durante la ventana del rescate.
local continuing: { [Player]: boolean } = {}
local choosing = false
local listeners: { (player: Player, summary: Summary) -> () } = {}

-- Llama a "callback" con cada jugador y su resumen cuando termina la partida. Regístralo en Init.
function MatchService.onMatchEnded(callback: (player: Player, summary: Summary) -> ())
	table.insert(listeners, callback)
end

function MatchService.isOver(): boolean
	return ended
end

-- true desde el rescate: la partida sigue en "Seguir sobreviviendo".
function MatchService.isRescued(): boolean
	return rescued
end

local SNAPSHOT_STATS =
	{ MatchStats.KILLS, MatchStats.REVIVES, MatchStats.BOSSES, MatchStats.EGGS, MatchStats.BOUNTIES, MatchStats.DEATHS }

local function snapshotOf(player: Player): { [string]: number }
	local snapshot = {}
	for _, stat in SNAPSHOT_STATS do
		snapshot[stat] = MatchStats.get(player, stat)
	end
	return snapshot
end

local function summaryFor(player: Player, result: Result, days: number, test: boolean, phase: Phase?): Summary
	-- En "Endless" se descuenta lo que ya se pagó en el rescate.
	local base = if phase == "Endless" then snapshots[player] or snapshotOf(player) else {}
	local function stat(name: string): number
		return MatchStats.get(player, name) - (base[name] or 0)
	end
	local paidDays = if phase == "Endless" then math.max(0, days - rescueDays) else days
	local kills = stat(MatchStats.KILLS)
	local revives = stat(MatchStats.REVIVES)
	local bosses = stat(MatchStats.BOSSES)
	local eggs = stat(MatchStats.EGGS)
	local settings = Config.Match
	local amber = paidDays * settings.AmberPerDay
		+ kills * settings.AmberPerKill
		+ revives * settings.AmberPerRevive
		+ bosses * settings.AmberPerBoss
		+ stat(MatchStats.BOUNTIES) * settings.AmberPerBounty
		+ eggs * settings.AmberPerEgg
		+ (if result == "Victory" then settings.AmberForRescue else 0)
	-- Evento en vivo "Doble Ámbar" (T4b).
	local boost = LiveEvents.amberMultiplier()
	amber *= boost
	local passXp = Config.Season.IslandXp
	local xp = paidDays * passXp.PerDay
		+ bosses * passXp.PerBoss
		+ eggs * passXp.PerEgg
		+ (if result == "Victory" then passXp.Rescue else 0)
	return {
		result = result,
		phase = phase,
		days = days,
		extraDays = if phase == "Endless" then paidDays else nil,
		canContinue = if phase == "Rescue" then true else nil,
		kills = kills,
		revives = revives,
		deaths = stat(MatchStats.DEATHS),
		bosses = bosses,
		amber = amber,
		amberBoost = if boost > 1 then boost else nil,
		eggRoll = if result == "Victory" then Eggs.rescueRoll(player) else nil,
		test = if test then true else nil,
		newTitle = if result == "Victory"
				and not test
				and CosmeticsServer.grant(player, SURVIVOR_TITLE)
			then true
			else nil,
		pass = SeasonPass.addXp(player, "Match", xp),
	}
end

-- Días sobrevividos: el día actual cuenta si se llegó a su noche.
local function daysSurvived(): number
	local state = MatchState.read()
	return if state then (if state.phase == "Night" then state.day else state.day - 1) else 0
end

local function payOut(player: Player, summary: Summary)
	for _, listener in listeners do
		task.spawn(listener, player, summary)
	end
	Remotes.MatchEnded:FireClient(player, summary)
end

-- El final de verdad: se para el día y la noche y a los ResultsSeconds todos vuelven al Lobby.
local function finish(result: Result, test: boolean)
	ended = true
	DayNightService.stop()
	local days = daysSurvived()
	ReplicatedStorage:SetAttribute("MatchOver", result)
	local phase: Phase? = if rescued then "Endless" else nil
	for _, player in Players:GetPlayers() do
		payOut(player, summaryFor(player, result, days, test or rescueTest, phase))
	end
	task.delay(Config.Match.ResultsSeconds, function()
		local players = Players:GetPlayers()
		if #players > 0 then
			Teleporter.send(players, Config.PlaceIds.Lobby, "el Lobby")
		end
	end)
end

-- El rescate: se paga todo y cada uno elige si sigue. Si no sigue nadie, la partida acaba como antes.
local function rescue(test: boolean)
	rescued = true
	rescueTest = test
	rescueDays = daysSurvived()
	choosing = true
	ReplicatedStorage:SetAttribute("MatchRescued", true)
	for _, player in Players:GetPlayers() do
		local summary = summaryFor(player, "Victory", rescueDays, test, "Rescue")
		snapshots[player] = snapshotOf(player)
		payOut(player, summary)
	end
	task.delay(Config.Match.ResultsSeconds, function()
		choosing = false
		local leaving = {}
		for _, player in Players:GetPlayers() do
			if not continuing[player] then
				table.insert(leaving, player)
			end
		end
		if #leaving > 0 then
			Teleporter.send(leaving, Config.PlaceIds.Lobby, "el Lobby")
		end
		if next(continuing) == nil then
			ended = true
			DayNightService.stop()
			ReplicatedStorage:SetAttribute("MatchOver", "Victory")
		else
			for player in continuing do
				Remotes.Notify:FireClient(
					player,
					"♾️ ¡A seguir sobreviviendo! Cada día de más cuenta para tu récord"
				)
			end
		end
	end)
end

-- "test": la termina el panel de pruebas (DebugService), para que no cuente en el ranking.
-- Una victoria es el rescate (se puede seguir); después solo puede acabar con todos caídos.
function MatchService.endMatch(result: Result, test: boolean?)
	if ended then
		return
	end
	if result == "Victory" then
		if not rescued then
			rescue(test == true)
		end
		return
	end
	finish(result, test == true)
end

local function everyoneDown(): boolean
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		if LifeState.isAlive(player) then
			return false
		end
	end
	return true
end

function MatchService:Start()
	-- Quien entre en una partida ya terminada (o ya ganada: Fase 12) vuelve al Lobby.
	Players.PlayerAdded:Connect(function(player)
		if ended or rescued then
			Remotes.Notify:FireClient(player, "Esta partida ha terminado: volviendo al Lobby")
			task.wait(3)
			Teleporter.send({ player }, Config.PlaceIds.Lobby, "el Lobby")
		end
	end)
	Remotes.ChooseContinue.OnServerEvent:Connect(function(player: Player)
		if choosing and not ended then
			continuing[player] = true
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		continuing[player] = nil
		snapshots[player] = nil
	end)
	local downSince: number? = nil
	while not ended do
		task.wait(1)
		local state = MatchState.read()
		local night = state ~= nil and state.phase == "Night"
		if night and everyoneDown() then
			downSince = downSince or os.clock()
			if os.clock() - (downSince :: number) >= Config.Match.DefeatGraceSeconds then
				MatchService.endMatch("Defeat")
			end
		else
			downSince = nil
		end
	end
end

return MatchService
