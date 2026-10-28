--!strict
-- Reglas del combate de la Isla (ServerScriptService.Combat.CombatRules): el combate es compartido con
-- la arena de Dunas y aquí se enchufa lo que solo existe en la Isla.
--   - PvP opt-in (GDD §12, Fase 5): ambos con PvP activo y ninguno dentro del Basecamp.
--   - Todos los jugadores son aliados para curar y proteger (no hay equipos).
--   - El Basecamp es zona segura contra los monos mientras el campamento no haya caído.
--   - Un golpe mortal deja caído (LifeService); en PvP, además, se cobra la recompensa del caído.
--   - La munición sale del inventario, el hacha y el pico trabajan los recursos, los mordiscos suben
--     la fiebre (el doble con lluvia tóxica, que el Ungüento en área del médico baja), las habilidades y los combos cuentan para las misiones diarias y todo va a la
--     telemetría de la partida.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Basecamp = require(ReplicatedStorage.Shared.Basecamp)
local Config = require(ReplicatedStorage.Shared.Config)
local MatchStats = require(ReplicatedStorage.Shared.MatchStats)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Survival = require(ReplicatedStorage.Shared.Survival)
local Retention = require(ServerScriptService.ServerShared.Retention)
local CombatRules = require(ServerScriptService.Combat.CombatRules)
local InventoryService = require(script.Parent.InventoryService)
local LifeService = require(script.Parent.LifeService)
local ResourceService = require(script.Parent.ResourceService)
local TelemetryService = require(script.Parent.TelemetryService)

local IslandCombatRules = {}

local function pvpReady(player: Player): boolean
	return player:GetAttribute("PvP") == true and player:GetAttribute("InBasecamp") ~= true
end

-- "attacker" ha dejado caído a "victim" en PvP: cobra su recompensa y sube la propia.
local function collectBounty(attacker: Player, victim: Player)
	local bounty = victim:GetAttribute("Bounty")
	local collected = if typeof(bounty) == "number" then bounty else 0
	local own = attacker:GetAttribute("Bounty")
	attacker:SetAttribute("Bounty", (if typeof(own) == "number" then own else 0) + 1)
	victim:SetAttribute("Bounty", 0)
	if collected > 0 then
		MatchStats.add(attacker, MatchStats.BOUNTIES, collected)
		Remotes.Notify:FireAllClients(
			"💰 {attacker} cobra la recompensa de {victim} ({amount})",
			{ attacker = attacker.DisplayName, victim = victim.DisplayName, amount = collected }
		)
	else
		Remotes.Notify:FireClient(attacker, "⚔️ Has derribado a {player}", { player = victim.DisplayName })
	end
end

local function removeOne(player: Player, itemId: string): boolean
	return InventoryService.remove(player, itemId, 1)
end

function IslandCombatRules:Init()
	CombatRules.set({
		movement = { staminaFree = false, slide = true, dodgeStyle = "Roll", slideKey = "LeftAlt" },
		canHitPlayer = function(attacker: Player, victim: Player): boolean
			return pvpReady(attacker) and pvpReady(victim)
		end,
		isSafe = function(player: Player): boolean
			-- Con el campamento caído (Shared/Basecamp) no hay zona segura.
			return player:GetAttribute("InBasecamp") == true and not Basecamp.isFallen()
		end,
		knockOut = function(player: Player, attacker: Player?, cause: string)
			LifeService.down(player, cause)
			if attacker then
				collectBounty(attacker, player)
			end
		end,
		useAmmo = removeOne,
		useBoost = removeOne,
		strikeResource = ResourceService.strike,
		-- Lo positivo son los mordiscos (CombatService): con lluvia tóxica, el doble.
		addFever = function(player: Player, amount: number)
			local toxic = amount > 0 and Survival.toxicRain()
			Survival.addFever(player, if toxic then amount * Config.MidEvents.ToxicRain.BiteFeverMultiplier else amount)
		end,
		salveFeverCure = function(): number
			return if Survival.toxicRain() then Config.MidEvents.ToxicRain.SalveFeverCure else 0
		end,
		progressMission = function(player: Player, kind: string)
			Retention.progress(player, kind)
		end,
		starterTools = function(): { string }
			return Config.Combat.StarterTools
		end,
		-- Con hambre o sed bajas, la estamina se recupera más despacio (lo mismo predice LocomotionController).
		staminaRegenFactor = function(player: Player): number
			return if Survival.isWeak(player) then Config.Survival.WeakStaminaRegenFactor else 1
		end,
		telemetry = TelemetryService,
	})
end

return IslandCombatRules
