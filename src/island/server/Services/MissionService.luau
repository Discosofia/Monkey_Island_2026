--!strict
-- Misiones en la Isla (bucle de retención, octubre de 2026; misiones v2 de la Fase 9;
-- ServerShared/Retention, Data/Missions). Pone en marcha el apunte de las misiones y cuenta lo que no
-- avisa nadie más: monos derrotados (su especie y si era un alfa), daño hecho a los monos (el del
-- muñeco de práctica no cuenta), jefes derrotados, noches superadas y el día al que se llega (para
-- quien estaba al empezar la noche, como el tiempo del huevo en EggTimeService) y la victoria con el
-- rescate. Lo demás lo avisan sus servicios (recolectar, fabricar, construir, salvar un huevo, cerrar
-- un combo, usar una habilidad).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Retention = require(ServerScriptService.ServerShared.Retention)
local CombatService = require(ServerScriptService.Combat.Services.CombatService)
local BossService = require(script.Parent.BossService)
local DayNightService = require(script.Parent.DayNightService)
local MatchService = require(script.Parent.MatchService)
local MonkeyService = require(script.Parent.MonkeyService)

local MissionService = {}

-- Quién estaba en la partida al empezar la noche en curso.
local atNightStart: { [Player]: boolean } = {}

local function onPhaseStarted(day: number, phase: MatchState.Phase)
	if phase == "Night" then
		table.clear(atNightStart)
		for _, player in Players:GetPlayers() do
			atNightStart[player] = true
		end
	elseif phase == "Day" and day > 1 then
		for player in atNightStart do
			if player.Parent then
				Retention.progress(player, "Night")
				Retention.progress(player, "ReachDay", day)
			end
		end
		table.clear(atNightStart)
	end
end

function MissionService:Init()
	MonkeyService.onKilled(function(player: Player, speciesId: string, alpha: boolean)
		Retention.progress(player, "Kill")
		Retention.progress(player, "Species", 1, speciesId)
		if alpha then
			Retention.progress(player, "Alpha")
		end
	end)
	CombatService.onEnemyDamaged(function(model: Model, attacker: Player?, amount: number)
		if attacker and amount > 0 and model:GetAttribute("TrainingDummy") ~= true then
			Retention.progress(attacker, "Damage", amount)
		end
	end)
	BossService.onDefeated(function(player: Player, bossId: string)
		Retention.progress(player, "Boss", 1, bossId)
	end)
	DayNightService.onPhaseStarted(onPhaseStarted)
	-- Al acabar se apunta ya lo pendiente: en unos segundos se van al Lobby. Las partidas que termina el
	-- panel de pruebas no cuentan como rescate (tampoco para el ranking).
	MatchService.onMatchEnded(function(player: Player, summary: MatchService.Summary)
		if summary.result == "Victory" and not summary.test then
			Retention.progress(player, "Rescue")
		end
		Retention.flushNow(player)
	end)
end

function MissionService:Start()
	Players.PlayerRemoving:Connect(function(player)
		atNightStart[player] = nil
	end)
	Retention.start()
end

return MissionService
