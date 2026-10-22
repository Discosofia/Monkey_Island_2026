--!strict
-- Cadena de golpes de las armas cuerpo a cuerpo (Fase 10, C4; números en Config.Chain). Funciones puras
-- con los tiempos de cada golpe: las usan el servidor (CombatService, que decide el golpe y el daño) y
-- el cliente (WeaponController, que predice el tajo y guarda la pulsación en el búfer), cada uno con
-- su reloj. La calculadora (ServerStorage.Tools.Equilibrio, sección 7) mide lo mismo.
--   - Cada paso dura "time" × el cooldownSeconds del arma; el golpe cae tras WindupFraction de él
--     (la preparación) y el resto es la recuperación.
--   - El siguiente golpe sigue la cadena si se pulsa antes de LinkWindowSeconds desde que se puede; si
--     no, si se cambia de arma o tras el remate, se vuelve al primero.
--   - Las herramientas (hacha, pico, hoz: "tool" en Data/Weapons) siguen con el golpe suelto.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local SETTINGS = Config.Chain
local STEPS = SETTINGS.Steps

local MeleeChain = {}

MeleeChain.LENGTH = #STEPS

-- Dónde va la cadena de un jugador.
export type State = {
	weaponId: string?,
	step: number, -- el último golpe empezado (0: ninguno)
	readyAt: number, -- cuándo se puede empezar el siguiente
}

function MeleeChain.newState(): State
	return { weaponId = nil, step = 0, readyAt = -math.huge }
end

-- true si "weapon" pega en cadena (cuerpo a cuerpo y no es una herramienta de recolección).
function MeleeChain.uses(weapon: Weapons.WeaponDefinition): boolean
	return weapon.kind == "Melee" and weapon.tool == nil
end

-- Segundos que dura el paso "step" con "weapon" (preparación, golpe y recuperación).
function MeleeChain.stepSeconds(weapon: Weapons.WeaponDefinition, step: number): number
	return STEPS[step].time * weapon.cooldownSeconds
end

-- Segundos desde que empieza el paso "step" hasta que cae el golpe.
function MeleeChain.windupSeconds(weapon: Weapons.WeaponDefinition, step: number): number
	return SETTINGS.WindupFraction * MeleeChain.stepSeconds(weapon, step)
end

function MeleeChain.damageMultiplier(step: number): number
	return STEPS[step].damage
end

function MeleeChain.isFinisher(step: number): boolean
	return step == #STEPS
end

-- Tambaleo que deja el golpe "step" a un jugador: PvPHitstunSeconds, recortado para que entre el final
-- del tambaleo y el golpe siguiente quede siempre Config.Reaction.Seconds (bloquear, parry o esquivar).
-- El remate no tambalea (empuja).
function MeleeChain.hitstunSeconds(weapon: Weapons.WeaponDefinition, step: number): number
	if MeleeChain.isFinisher(step) then
		return 0
	end
	local untilNext = MeleeChain.stepSeconds(weapon, step)
		- MeleeChain.windupSeconds(weapon, step)
		+ MeleeChain.windupSeconds(weapon, step + 1)
	return math.max(0, math.min(SETTINGS.PvPHitstunSeconds, untilNext - Config.Reaction.Seconds))
end

-- Intenta empezar un golpe en "now" con "weaponId". "slack": margen por el retraso de la red (solo el
-- servidor). Devuelve el paso (1 a LENGTH) y apunta en "state", o nil si aún no se puede.
function MeleeChain.advance(
	state: State,
	weaponId: string,
	weapon: Weapons.WeaponDefinition,
	now: number,
	slack: number?
): number?
	if now < state.readyAt - (slack or 0) then
		return nil
	end
	local continues = state.weaponId == weaponId
		and state.step > 0
		and state.step < #STEPS
		and now <= state.readyAt + SETTINGS.LinkWindowSeconds
	local step = if continues then state.step + 1 else 1
	state.weaponId = weaponId
	state.step = step
	-- Quien llega tarde no gana tiempo, y el margen del servidor no se acumula de un golpe a otro.
	state.readyAt = math.max(now, state.readyAt) + MeleeChain.stepSeconds(weapon, step)
	return step
end

return MeleeChain
