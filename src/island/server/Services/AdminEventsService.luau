--!strict
-- Lo que un administrador hace al momento en esta partida de la Isla desde su panel (T4b,
-- Data/IslandActions), mandado por ServerShared/Admin a este servidor o a todos (AdminNet
-- "IslandAction"). Reutiliza lo mismo que el panel de pruebas (DebugService), pero vale también en el
-- juego publicado: el permiso lo comprueba Admin antes de mandarlo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local IslandActions = require(ReplicatedStorage.Shared.Data.IslandActions)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AdminNet = require(ServerScriptService.ServerShared.AdminNet)
local BasecampService = require(script.Parent.BasecampService)
local BossService = require(script.Parent.BossService)
local DayNightService = require(script.Parent.DayNightService)
local GiantAdminService = require(script.Parent.GiantAdminService)
local MatchService = require(script.Parent.MatchService)
local MonkeyService = require(script.Parent.MonkeyService)
local SupplyService = require(script.Parent.SupplyService)
local WeatherService = require(script.Parent.WeatherService)

-- Lo que dura el clima que pone el admin; después vuelve a despejarse.
local WEATHER_SECONDS = 180

local AdminEventsService = {}

local rng = Random.new()

-- Especies que tienen alfa (su tropa aparece con líder).
local alphaSpecies: { string } = {}
for speciesId, species in Monkeys do
	if (species :: any).alpha == true then
		table.insert(alphaSpecies, speciesId)
	end
end
table.sort(alphaSpecies)

-- Una tropa con alfa que va a por un jugador vivo, mejor uno fuera del Basecamp (si todos están dentro,
-- aparece fuera y los espera allí). false si no hay sitio.
local function spawnAlpha(): boolean
	local outside, inside = {}, {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and LifeState.isAlive(player) then
			local list = if BasecampService.isInside(character:GetPivot().Position) then inside else outside
			table.insert(list, player)
		end
	end
	local targets = if #outside > 0 then outside else inside
	if #targets == 0 or #alphaSpecies == 0 then
		return false
	end
	local target = targets[rng:NextInteger(1, #targets)]
	local speciesId = alphaSpecies[rng:NextInteger(1, #alphaSpecies)]
	local count = (Monkeys[speciesId] :: any).groupMin or 3
	local pivot = (target.Character :: Model):GetPivot()
	for _, distance in { 40, 60, 85, 120 } do
		for _, angle in { 0, 90, -90, 180, 45, -45 } do
			local spot = (pivot * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -distance)).Position
			if MonkeyService.spawnAmbush(speciesId, spot, count, target, true) > 0 then
				Remotes.Notify:FireAllClients(
					`🐒 ¡Una tropa de {Monkeys[speciesId].name} con su alfa va a por {target.DisplayName}!`
				)
				return true
			end
		end
	end
	return false
end

local ACTIONS: { [string]: () -> boolean } = {
	Boss = function()
		local rotation = Config.Match.BossRotation
		BossService.spawn(rotation[rng:NextInteger(1, #rotation)])
		return true
	end,
	Alpha = spawnAlpha,
	SkipPhase = function()
		DayNightService.skipPhase()
		return true
	end,
	Supplies = function()
		SupplyService.spawnCrate()
		return true
	end,
	Rain = function()
		WeatherService.force("Rain", WEATHER_SECONDS)
		return true
	end,
	Storm = function()
		WeatherService.force("Storm", WEATHER_SECONDS)
		return true
	end,
	Clear = function()
		WeatherService.force("Clear", 1)
		return true
	end,
	Eruption = function()
		WeatherService.erupt()
		return true
	end,
}

function AdminEventsService:Start()
	AdminNet.on("IslandAction", function(data: any)
		-- "Ser gigante": al propio administrador, si está en esta partida (GiantAdminService).
		if typeof(data) == "table" and data.action == "Giant" then
			local admin = Players:GetPlayerByUserId(data.admin)
			if admin and not MatchService.isOver() then
				local done, reason = GiantAdminService.toggle(admin)
				if not done and reason then
					Remotes.Notify:FireClient(admin, reason)
				end
			end
			return
		end
		local action = if typeof(data) == "table" then ACTIONS[data.action] else nil
		if not action or MatchService.isOver() then
			return
		end
		local done = action()
		local admin = Players:GetPlayerByUserId(data.admin)
		if admin then
			local info = IslandActions[data.action]
			Remotes.Notify:FireClient(
				admin,
				if done then `{info.icon} {info.name}: hecho` else `{info.icon} {info.name}: no hay sitio ahora`
			)
		end
	end)
end

return AdminEventsService
