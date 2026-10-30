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
--   - Apuntando, "adsSpreadFactor" multiplica la dispersión (Fase 19, W7).
--   - Sin "spread" el arma es exacta (0).
--   - Fase 19, W4: el desvío de cada tiro es determinista (offset/apply con la semilla ShotSeed y el número de
--     disparo), así el tirador dibuja su bala al momento con el mismo desvío que aplica el servidor.

local Config = require(script.Parent.Config)
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
	local angle = base + extra
	if zoomed and spread.adsSpreadFactor then
		angle *= spread.adsSpreadFactor
	end
	return angle
end

-- Dispersión (grados) de un disparo fuera del Laboratorio, sin cargador ni estado (Fase 19, W7): la de la
-- cadera (el "hipSpread" del arma o Config.Aim.HipSpreadDegrees) o, apuntando, Config.Aim.AdsSpreadDegrees.
function LabSpread.hip(weapon: { hipSpread: number? }, aiming: boolean): number
	if aiming then
		return Config.Aim.AdsSpreadDegrees
	end
	return weapon.hipSpread or Config.Aim.HipSpreadDegrees
end

-- Desvío determinista del disparo número "seq" de una vida con la semilla "seed" (atributo ShotSeed del
-- Player): un punto de un disco uniforme del cono de "degrees" grados (radio ∝ raíz de un número al azar,
-- acimut al azar), como vector local con -Z hacia delante. El servidor y el cliente sacan el mismo.
function LabSpread.offset(seed: number, seq: number, degrees: number): Vector3
	local random = Random.new(seed * 1000003 + seq)
	local radius = math.rad(degrees) * math.sqrt(random:NextNumber())
	local azimuth = random:NextNumber(0, 2 * math.pi)
	return Vector3.new(math.sin(radius) * math.cos(azimuth), math.sin(radius) * math.sin(azimuth), -math.cos(radius))
end

-- "direction" (unitaria) desviada con ese desvío, en el mundo.
function LabSpread.apply(direction: Vector3, seed: number, seq: number, degrees: number): Vector3
	if degrees <= 0 then
		return direction
	end
	return CFrame.lookAt(Vector3.zero, direction):VectorToWorldSpace(LabSpread.offset(seed, seq, degrees))
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
