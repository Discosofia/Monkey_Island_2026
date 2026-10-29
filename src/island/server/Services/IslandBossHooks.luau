--!strict
-- Lo que el jefe (combate compartido, Combat/Services/BossService) no sabe de la Isla, y su salida por días
-- (GDD §8.2, Fase 5): botín en la mochila, pieza de la baliza, estadísticas y telemetría de la partida,
-- antorchas que apaga su rugido, tropas de refuerzo, guarida de cada bioma y que no salga con la partida
-- acabada. Además saca un jefe cada Config.Match.BossIntervalDays días (2, 4, 6, 8…), en el orden de
-- Config.Match.BossRotation, y se queda hasta que lo derrotan o llega el siguiente.
-- Fase 12: la rotación se repite y en cada vuelta los jefes ya derrotados salen más fuertes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Beacon = require(ReplicatedStorage.Shared.Beacon)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Config = require(ReplicatedStorage.Shared.Config)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MatchStats = require(ReplicatedStorage.Shared.MatchStats)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local BossService = require(ServerScriptService.Combat.Services.BossService)
local BasecampService = require(script.Parent.BasecampService)
local DayNightService = require(script.Parent.DayNightService)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local MonkeyService = require(script.Parent.MonkeyService)
local TelemetryService = require(script.Parent.TelemetryService)
local TorchService = require(script.Parent.TorchService)

local IslandBossHooks = {}

local rng = Random.new()

-- Aviso a todos: plantilla en español y sus argumentos, que traduce cada cliente.
local function announce(text: string, args: { [string]: any }?)
	Remotes.Notify:FireAllClients(text, args)
end

-- La guarida de su bioma (Workspace.GuaridasJefes/Guarida_<bioma>); sin ella (mapa de pruebas), lejos del Basecamp.
local function lairPosition(definition: Bosses.Boss): Vector3
	local marker = Workspace:FindFirstChild(`Guarida_{definition.biome}`, true)
	if marker and marker:IsA("BasePart") then
		return marker.Position
	end
	local angle = rng:NextNumber(0, 2 * math.pi)
	return BasecampService.getCenter() + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 300
end

local function onPhaseStarted(day: number, phase: MatchState.Phase)
	local interval = Config.Match.BossIntervalDays
	if phase ~= "Day" or day % interval ~= 0 then
		return
	end
	local rotation = Config.Match.BossRotation
	local index = (day // interval) - 1
	local bossId = rotation[index % #rotation + 1]
	local previous = BossService.currentDefinition()
	if previous then
		BossService.despawn(Strings.later("🌫️ {boss} se retira a su guarida…"), { boss = { previous.name } })
	end
	-- Solo vuelve más fuerte si ya lo derrotaron (su pieza está en la baliza): uno que se les resistió
	-- vuelve igual, para que el grupo atascado pueda conseguir su pieza.
	local round = if Beacon.has(bossId) then index // #rotation else 0
	BossService.spawn(bossId, round)
	if round > 0 then
		announce(
			"👑 {boss} vuelve más fuerte (vuelta {round})",
			{ boss = { Bosses[bossId].name }, round = round + 1 }
		)
	end
end

function IslandBossHooks:Init()
	BossService.setHooks({
		isIsland = true,
		blocked = function(): string?
			return if MatchService.isOver() then "👑 La partida ya ha terminado" else nil
		end,
		lairPosition = lairPosition,
		collect = InventoryService.collect,
		telemetry = TelemetryService.bossDefeated,
		matchStat = function(player: Player)
			MatchStats.add(player, MatchStats.BOSSES)
		end,
		douse = TorchService.douse,
		spawnAmbush = function(species: string, position: Vector3, count: number, target: Player): number
			return MonkeyService.spawnAmbush(species, position, count, target)
		end,
	})
	DayNightService.onPhaseStarted(onPhaseStarted)
end

return IslandBossHooks
