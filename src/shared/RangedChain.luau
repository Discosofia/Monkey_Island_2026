--!strict
-- Disparo de remate de las armas a distancia (Fase 10, C9b; números en Config.RangedChain). Funciones
-- puras con la cuenta de disparos seguidos: las usan el servidor (CombatService, que decide el disparo y
-- lo que hace el remate) y el cliente (WeaponController, que predice el destello del remate), cada uno con
-- su reloj. La calculadora (ServerStorage.Tools.Equilibrio, sección 7) mide lo mismo.
--   - Cada disparo deja el arma lista tras su cooldownSeconds. El siguiente sigue la cuenta si se dispara
--     antes de LinkWindowSeconds desde que se puede; si no, si se cambia de arma o tras el remate, se
--     vuelve al primero.
--   - El Length.º disparo seguido es el remate del arma ("finisher" en Data/Weapons).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local SETTINGS = Config.RangedChain

local RangedChain = {}

RangedChain.LENGTH = SETTINGS.Length

export type Finisher = {
	shot: number,
	finisher: number,
	pierceTargets: number?,
	radius: number?,
	othersDamage: number?,
	healMultiplier: number?,
	staggerSeconds: number?,
}

-- Dónde va la cuenta de un jugador.
export type State = {
	weaponId: string?,
	shot: number, -- el último disparo (0: ninguno)
	readyAt: number, -- cuándo se puede disparar otra vez
}

function RangedChain.newState(): State
	return { weaponId = nil, shot = 0, readyAt = -math.huge }
end

-- Los números del remate de "weapon" (Config.RangedChain.Finishers), o nil si no tiene.
function RangedChain.settings(weapon: Weapons.WeaponDefinition): Finisher?
	return if weapon.finisher then SETTINGS.Finishers[weapon.finisher] else nil
end

function RangedChain.isFinisher(weapon: Weapons.WeaponDefinition, shot: number): boolean
	return shot == SETTINGS.Length and weapon.finisher ~= nil
end

function RangedChain.damageMultiplier(weapon: Weapons.WeaponDefinition, shot: number): number
	local settings = RangedChain.settings(weapon)
	if not settings then
		return 1
	end
	return if shot == SETTINGS.Length then settings.finisher else settings.shot
end

-- Intenta disparar en "now" con "weaponId". "slack": margen por el retraso de la red (solo el servidor).
-- Devuelve el número del disparo (1 a LENGTH) y apunta en "state", o nil si aún no se puede.
function RangedChain.advance(
	state: State,
	weaponId: string,
	weapon: Weapons.WeaponDefinition,
	now: number,
	slack: number?
): number?
	-- También al cambiar de arma: cambiar de una a otra no dispara antes.
	if now < state.readyAt - (slack or 0) then
		return nil
	end
	local continues = state.weaponId == weaponId
		and state.shot > 0
		and state.shot < SETTINGS.Length
		and now <= state.readyAt + SETTINGS.LinkWindowSeconds
	local shot = if continues then state.shot + 1 else 1
	state.weaponId = weaponId
	state.shot = shot
	-- Quien llega tarde no gana tiempo, y el margen del servidor no se acumula de un disparo a otro.
	state.readyAt = math.max(now, state.readyAt) + weapon.cooldownSeconds
	return shot
end

return RangedChain
