--!strict
-- Amagos (Fase 10, C8): pulsar la guardia durante la preparación de un golpe de la cadena
-- (CombatService.chainAttack) o de una habilidad (AbilityService) la cancela. Es la respuesta al parry:
-- quien para por reflejo gasta su ventana (y tarda Config.Guard.ParryRearmSeconds en volver a tenerla).
--   - El del golpe es gratis, como mucho uno cada Config.Feint.WeaponCooldownSeconds.
--   - El de una habilidad cuesta AbilityStaminaCost de estamina (Combat/StaminaServer) y deja su
--     recarga en AbilityPenaltySeconds en vez de la entera (lo pone quien la registra, en "cancel").
--   - Si no se puede amagar, no pasa nada: la guardia se pone al acabar el golpe, como siempre.
-- Combat/Guard lo prueba al pulsar (Feint.try) antes de poner la guardia: amagar y parar en la misma
-- pulsación vale. Se ve un humo corto ("FeintFx") para que el rival pueda leerlo (el propio cliente lo
-- dibuja al momento, CombatClient/Feint) y se oye (sonido "Feint", C12), y se cuenta en la telemetría ("Feints").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local AbilityFx = require(script.Parent.AbilityFx)
local CombatRules = require(script.Parent.CombatRules)
local StaminaServer = require(script.Parent.StaminaServer)

local SETTINGS = Config.Feint

export type Kind = "Attack" | "Ability"

-- Una preparación en curso que se puede cancelar.
type Pending = {
	kind: Kind,
	untilTime: number, -- hora del servidor en que sale el golpe o la habilidad
	cancel: () -> (),
}

local Feint = {}

local pending: { [Player]: Pending } = {}
local lastWeaponFeintAt: { [Player]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Empieza una preparación de "player" que sale a los "seconds" s; "cancel" la deshace si amaga.
-- Devuelve la marca que hay que pasar a "finish" cuando salga.
function Feint.begin(player: Player, kind: Kind, seconds: number, cancel: () -> ()): any
	local entry: Pending = { kind = kind, untilTime = now() + seconds, cancel = cancel }
	pending[player] = entry
	return entry
end

-- La preparación "mark" (de Feint.begin) ha terminado: ya no se puede amagar.
function Feint.finish(player: Player, mark: any)
	if pending[player] == mark then
		pending[player] = nil
	end
end

-- Intenta amagar lo que "player" está preparando. Devuelve true si lo ha cancelado.
function Feint.try(player: Player): boolean
	local entry = pending[player]
	if not entry or now() >= entry.untilTime then
		return false
	end
	if entry.kind == "Attack" then
		local clock = os.clock()
		if clock - (lastWeaponFeintAt[player] or -math.huge) < SETTINGS.WeaponCooldownSeconds then
			return false
		end
		lastWeaponFeintAt[player] = clock
	elseif not StaminaServer.tryConsume(player, SETTINGS.AbilityStaminaCost, Config.Survival.StaminaSyncTolerance) then
		return false
	end
	pending[player] = nil
	entry.cancel()
	local character = player.Character
	if character then
		AbilityFx.others(player, "FeintFx", character)
		Sfx.play("Feint", character.PrimaryPart or character)
	end
	CombatRules.get().telemetry.mechanic(player, "Feints")
	return true
end

-- Lo llama CombatService al empezar.
function Feint.start()
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
		lastWeaponFeintAt[player] = nil
	end)
end

return Feint
