--!strict
-- Lo que un administrador hace al momento en esta partida de la Isla desde su panel (T4b,
-- Data/IslandActions), mandado por ServerShared/Admin a este servidor o a todos (AdminNet
-- "IslandAction"). Reutiliza lo mismo que el panel de pruebas (DebugService), pero vale también en el
-- juego publicado: el permiso lo comprueba Admin antes de mandarlo.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local IslandActions = require(ReplicatedStorage.Shared.Data.IslandActions)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
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
					"🐒 ¡Una tropa de {monkey} con su alfa va a por {player}!",
					{ monkey = { Monkeys[speciesId].name }, player = target.DisplayName }
				)
				return true
			end
		end
	end
	return false
end

local function serverName(): string
	return if RunService:IsStudio() then "Studio" else string.sub(game.JobId, 1, 8)
end

-- Interruptor del clima: si ya hay ese, despeja.
local function weatherToggle(name: string)
	if ReplicatedStorage:GetAttribute("Weather") == name then
		WeatherService.force("Clear", 1)
	else
		WeatherService.force(name, WEATHER_SECONDS)
	end
end

-- Cada acción recibe el administrador que la pidió (nil si juega en otro servidor).
local ACTIONS: { [string]: (admin: Player?, scope: string?) -> boolean } = {
	-- Interruptor: si hay jefe vivo lo quita; si no, lo saca junto al administrador (en su guarida si no
	-- está aquí) y avisa a todos los servidores desde el del administrador.
	Boss = function(admin, scope)
		if BossService.isAlive() then
			BossService.despawn()
			return true
		end
		local rotation = Config.Match.BossRotation
		local bossId = rotation[rng:NextInteger(1, #rotation)]
		local character = if admin then admin.Character else nil
		local position = if character then character:GetPivot().Position else nil
		BossService.spawn(bossId, nil, position)
		if admin then
			AdminNet.send("Announce", {
				text = Strings.later("👑 ¡{boss} ha aparecido en {place}, servidor {server}!"),
				args = { boss = { Bosses[bossId].name }, place = { Strings.later("la Isla") }, server = serverName() },
				from = Strings.later("Evento"),
			}, if scope == "All" then "All" else "Server")
		end
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
		weatherToggle("Rain")
		return true
	end,
	Storm = function()
		weatherToggle("Storm")
		return true
	end,
	Clear = function()
		WeatherService.force("Clear", 1)
		return true
	end,
	Eruption = function()
		if ReplicatedStorage:GetAttribute("Eruption") == true then
			WeatherService.calm()
		else
			WeatherService.erupt()
		end
		return true
	end,
}

-- Lo que está en marcha, para pintar resaltado el tablero del panel (UI/AdminPanel lo lee).
local function publishState()
	local giant = false
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("AdminBoss") == true then
			giant = true
			break
		end
	end
	local weather = ReplicatedStorage:GetAttribute("Weather")
	ReplicatedStorage:SetAttribute(
		Config.AdminTools.IslandStateAttribute,
		HttpService:JSONEncode({
			Boss = BossService.isAlive(),
			Rain = weather == "Rain",
			Storm = weather == "Storm",
			Eruption = ReplicatedStorage:GetAttribute("Eruption") == true,
			Giant = giant,
		})
	)
end

function AdminEventsService:Start()
	task.spawn(function()
		while true do
			publishState()
			task.wait(1)
		end
	end)
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
		local admin = Players:GetPlayerByUserId(data.admin)
		local done = action(admin, data.scope)
		publishState()
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
