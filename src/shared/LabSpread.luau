--!strict
-- Dispersión de las armas del Laboratorio (Fase 15, V8; números en Data/LabWeapons, campo "lab.spread").
-- Funciones puras con el estado de dispersión de un jugador: las usan el servidor (LabAmmoService, que
-- decide el desvío real de cada tiro) y el cliente (CombatClient/LabShooting, que dibuja la mira
-- dinámica), cada uno con su estado y su reloj.
--   - Ángulo (grados) = base según la situación (en el aire, moviéndose o quieto) + el acumulado "extra".
--   - Cada disparo suma "perShot" al acumulado, hasta "maxShots" disparos; al dejar de disparar baja a
--     "recover" grados por segundo.
--   - El primer tiro quieto (sin acumulado, en el suelo y sin moverse) es exacto aunque "still" valga más.
--     Solo en las armas que acumulan (perShot > 0): en las demás "still" vale siempre.
--   - Con "zoomExact" y el zoom puesto, en el suelo la base es 0 (el rifle).
--   - Sin "spread" el arma es exacta (0).

local LabWeapons = require(script.Parent.Data.LabWeapons)

local LabSpread = {}

-- Dónde va el acumulado de un jugador: grados y cuándo se anotó (reloj de quien lo use).
export type State = {
	extra: number,
	at: number,
}

function LabSpread.newState(): State
	return { extra = 0, at = -math.huge }
end

-- El acumulado a la hora "now", ya recuperado.
local function extraAt(spread: LabWeapons.SpreadFields, state: State, now: number): number
	local recover = spread.recover
	if state.extra <= 0 or not recover then
		return 0
	end
	return math.max(0, state.extra - recover * math.max(0, now - state.at))
end

-- Dispersión (grados) del siguiente tiro. No cambia el estado.
function LabSpread.angle(
	weapon: { lab: LabWeapons.LabFields? },
	state: State,
	now: number,
	moving: boolean,
	airborne: boolean,
	zoomed: boolean
): number
	local spread = if weapon.lab then weapon.lab.spread else nil
	if not spread then
		return 0
	end
	local extra = extraAt(spread, state, now)
	-- Exacto: con el zoom del rifle, o el primer tiro de un arma que acumula, quieto y sin acumulado.
	local exact = (spread.zoomExact == true and zoomed) or (not moving and extra <= 0 and spread.perShot > 0)
	local base: number
	if airborne then
		base = spread.air
	elseif exact then
		base = 0
	elseif moving then
		base = spread.moving
	else
		base = spread.still
	end
	return base + extra
end

-- Anota un disparo: suma "perShot" al acumulado (ya recuperado hasta "now"), con tope.
function LabSpread.fire(weapon: { lab: LabWeapons.LabFields? }, state: State, now: number)
	local spread = if weapon.lab then weapon.lab.spread else nil
	if not spread or spread.perShot <= 0 then
		return
	end
	local cap = spread.perShot * (spread.maxShots or 1)
	state.extra = math.min(cap, extraAt(spread, state, now) + spread.perShot)
	state.at = now
end

return LabSpread
