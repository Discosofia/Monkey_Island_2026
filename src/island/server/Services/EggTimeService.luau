--!strict
-- El huevo del nido del Lobby también avanza jugando en la Isla (bucle de retención, octubre de 2026):
--   - Cada noche superada le quita Config.Egg.SecondsPerDaySurvived (con el tope de lo ganado jugando,
--     Shared/EggIncubation). Cuenta para quien estaba en la partida al empezar esa noche: entrar al
--     amanecer no da nada. Se guarda al momento, así que salir antes de acabar no lo pierde.
--   - Si el huevo queda listo mientras juega, se le avisa una vez: se abre en el nido del Lobby.
-- La tirada del rescate (al ganar) va en el resumen de la partida (MatchService, ServerShared/Eggs).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Eggs = require(ServerScriptService.ServerShared.Eggs)
local DayNightService = require(script.Parent.DayNightService)

local READY_CHECK_SECONDS = 30

local EggTimeService = {}

-- Quién estaba en la partida al empezar la noche en curso.
local atNightStart: { [Player]: boolean } = {}
-- A quién ya se avisó de que su huevo está listo (una vez por partida y huevo).
local toldReady: { [Player]: boolean } = {}

local function rewardDawn(player: Player)
	local before = Eggs.get(player)
	local nest = before and before.nest
	if not nest or EggIncubation.isReady(nest, EggIncubation.now()) then
		return
	end
	local name = Rarities[nest.rarity].name
	local applied = Eggs.addPlayTime(player, Config.Egg.SecondsPerDaySurvived)
	if applied > 0 then
		Remotes.Notify:FireClient(
			player,
			`🌅 Noche superada: tu huevo {name} del nido, −{EggIncubation.formatTime(applied)}`
		)
	else
		Remotes.Notify:FireClient(
			player,
			`🌅 Noche superada: tu huevo {name} ya va todo lo rápido que puede jugando`
		)
	end
end

local function onPhaseStarted(day: number, phase: MatchState.Phase)
	if phase == "Night" then
		table.clear(atNightStart)
		for _, player in Players:GetPlayers() do
			atNightStart[player] = true
		end
	elseif phase == "Day" and day > 1 then
		for player in atNightStart do
			if player.Parent then
				task.spawn(rewardDawn, player)
			end
		end
		table.clear(atNightStart)
	end
end

local function checkReady()
	for _, player in Players:GetPlayers() do
		local data = Eggs.get(player)
		local nest = data and data.nest
		local ready = nest ~= nil and EggIncubation.isReady(nest, EggIncubation.now())
		if ready and not toldReady[player] then
			toldReady[player] = true
			local name = Rarities[(nest :: EggIncubation.NestEgg).rarity].name
			Remotes.Notify:FireClient(player, `🐣 ¡Tu huevo {name} está listo! Ábrelo en el nido del Lobby`)
		elseif not ready then
			toldReady[player] = nil
		end
	end
end

function EggTimeService:Init()
	DayNightService.onPhaseStarted(onPhaseStarted)
end

function EggTimeService:Start()
	Players.PlayerRemoving:Connect(function(player)
		atNightStart[player] = nil
		toldReady[player] = nil
	end)
	while true do
		task.wait(READY_CHECK_SECONDS)
		checkReady()
	end
end

return EggTimeService
