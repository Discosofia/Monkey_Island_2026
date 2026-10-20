--!strict
-- Misiones del día en la Isla (bucle de retención, octubre de 2026; ServerShared/Retention, Data/Missions).
-- Pone en marcha el apunte de las misiones y cuenta lo que no avisa nadie más: monos derrotados, daño
-- hecho a los monos (el del muñeco de práctica no cuenta) y noches superadas (para quien estaba al
-- empezar la noche, como el tiempo del huevo en EggTimeService). Lo demás lo avisan sus servicios
-- (recolectar, fabricar, construir, salvar un huevo, cerrar un combo, usar una habilidad).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Retention = require(ServerScriptService.ServerShared.Retention)
local CombatService = require(script.Parent.CombatService)
local DayNightService = require(script.Parent.DayNightService)
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
			end
		end
		table.clear(atNightStart)
	end
end

function MissionService:Init()
	MonkeyService.onKilled(function(player: Player)
		Retention.progress(player, "Kill")
	end)
	CombatService.onEnemyDamaged(function(model: Model, attacker: Player?, amount: number)
		if attacker and amount > 0 and model:GetAttribute("TrainingDummy") ~= true then
			Retention.progress(attacker, "Damage", amount)
		end
	end)
	DayNightService.onPhaseStarted(onPhaseStarted)
end

function MissionService:Start()
	Players.PlayerRemoving:Connect(function(player)
		atNightStart[player] = nil
	end)
	Retention.start()
end

return MissionService
