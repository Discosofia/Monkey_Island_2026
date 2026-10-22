--!strict
-- Telemetría de combate: qué habilidades se usan y cuánto aportan, si se hacen combos, quién te
-- deja quieto y qué te tumba. Sirve para comparar con la calculadora de equilibrio
-- (tools/Equilibrio) lo que hacen los jugadores de verdad.
-- Se cuenta durante la partida y se manda junto al terminarla (o al salir el jugador), un evento por
-- cosa con su total: Roblox pide agrupar los eventos para no pasarse de sus límites. Los dos que
-- pasan pocas veces (caídas y jefes) salen al momento. Se ven en el Creator Hub → Analítica →
-- Eventos propios, desglosados por sus campos (Analytics.event).
--
-- Eventos (valor · campos):
--   AbilityUses      usos en la partida · Rol, Habilidad
--   AbilityLinked    usos enlazados como paso 2 o 3 de un combo · Rol, Habilidad
--   ComboCompleted   combos completos · Rol
--   ComboBestStreak  mejor racha (1-5) · Rol
--   DamageBySource   daño hecho a monos, jefes y muñecos · Rol, Fuente (id de habilidad, id de arma
--                    o "Mascota")
--   HealingBySource  curación hecha a jugadores · Rol, Fuente
--   TimeHeld         segundos quieto por agarres y aturdimientos · Rol, Causa
--   MinutesPlayed    minutos en la partida · Rol (para pasar lo demás a "por minuto")
--   PlayerDowned     día de la partida · Rol, Causa (al momento)
--   BossDefeated     segundos desde el primer golpe · Jefe, jugadores que peleaban (al momento)
--   Parries, Blocks, GuardBreaks, Evasives, ChainFinishers, Feints, WallBangs, ShotsHit,
--   ShotsMissed, ShotFinishers
--                    veces en la partida · Rol, Place ("Isla"; en Dunas los cuenta
--                    ArenaTelemetryService con "Dunas"). Quién cuenta cada una: CombatRules.Mechanic.
-- Causa: id de la especie del mono, "Jefe <id>", "Peligro" (rocas, lava, rayos), "Hambre" o "PvP".

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Analytics = require(ServerScriptService.ServerShared.Analytics)
local MatchService = require(script.Parent.MatchService)

type Entry = {
	name: string,
	fields: { string },
	value: number,
}

type Tally = {
	joinedAt: number,
	entries: { [string]: Entry },
}

local TelemetryService = {}

local tallies: { [Player]: Tally } = {}
local ended = false

local function roleOf(player: Player): string
	local role = player:GetAttribute("Role")
	return if typeof(role) == "string" then role else "SinRol"
end

local function tallyOf(player: Player): Tally?
	if ended or player.Parent == nil then
		return nil
	end
	local tally = tallies[player]
	if not tally then
		tally = { joinedAt = os.clock(), entries = {} }
		tallies[player] = tally
	end
	return tally
end

-- Suma "amount" (o se queda con el mayor si "keepMax") al evento "name" con esos campos.
local function count(player: Player, name: string, fields: { string }, amount: number, keepMax: boolean?)
	local tally = tallyOf(player)
	if not tally or amount <= 0 then
		return
	end
	local key = name .. "|" .. table.concat(fields, "|")
	local entry = tally.entries[key]
	if not entry then
		entry = { name = name, fields = fields, value = 0 }
		tally.entries[key] = entry
	end
	entry.value = if keepMax then math.max(entry.value, amount) else entry.value + amount
end

-- Quién causa un golpe o un agarre: el mono o jefe que lo da; sin él, un peligro del entorno.
function TelemetryService.causeOf(source: Instance?): string
	if source then
		local boss = source:GetAttribute("Boss")
		if typeof(boss) == "string" then
			return `Jefe {boss}`
		end
		local species = source:GetAttribute("MonkeyType")
		if typeof(species) == "string" then
			return species
		end
	end
	return "Peligro"
end

-- "linkedStep": el paso del combo que ha enlazado (2 o 3), o nil.
function TelemetryService.abilityUsed(player: Player, abilityId: string, linkedStep: number?)
	local role = roleOf(player)
	count(player, "AbilityUses", { role, abilityId }, 1)
	if linkedStep then
		count(player, "AbilityLinked", { role, abilityId }, 1)
	end
end

function TelemetryService.comboCompleted(player: Player, streak: number)
	local role = roleOf(player)
	count(player, "ComboCompleted", { role }, 1)
	count(player, "ComboBestStreak", { role }, streak, true)
end

function TelemetryService.damageDealt(player: Player, source: string, amount: number)
	count(player, "DamageBySource", { roleOf(player), source }, amount)
end

function TelemetryService.healed(player: Player, source: string, amount: number)
	count(player, "HealingBySource", { roleOf(player), source }, amount)
end

function TelemetryService.held(player: Player, seconds: number, cause: string)
	count(player, "TimeHeld", { roleOf(player), cause }, seconds)
end

-- Una mecánica de combate (Fase 10, C7; CombatRules.Mechanic).
function TelemetryService.mechanic(player: Player, mechanic: string)
	count(player, mechanic, { roleOf(player), "Isla" }, 1)
end

function TelemetryService.downed(player: Player, cause: string)
	if ended then
		return
	end
	local state = MatchState.read()
	Analytics.event(player, "PlayerDowned", if state then state.day else 0, { roleOf(player), cause })
end

-- Se manda con uno de los que pelearon (vale uno por jefe, no uno por jugador).
function TelemetryService.bossDefeated(player: Player, bossId: string, seconds: number, fighters: number)
	Analytics.event(player, "BossDefeated", math.round(seconds), { bossId, tostring(fighters) })
end

local function flush(player: Player)
	local tally = tallies[player]
	tallies[player] = nil
	if not tally then
		return
	end
	Analytics.event(player, "MinutesPlayed", math.round((os.clock() - tally.joinedAt) / 6) / 10, { roleOf(player) })
	for _, entry in tally.entries do
		Analytics.event(player, entry.name, math.round(entry.value * 10) / 10, entry.fields)
	end
end

function TelemetryService:Init()
	MatchService.onMatchEnded(function(player)
		flush(player)
		ended = true
	end)
end

function TelemetryService:Start()
	Players.PlayerAdded:Connect(tallyOf)
	for _, player in Players:GetPlayers() do
		tallyOf(player)
	end
	Players.PlayerRemoving:Connect(flush)
end

return TelemetryService
