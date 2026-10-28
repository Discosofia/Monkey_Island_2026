--!strict
-- Dirección aproximada de un punto visto desde el Basecamp ("el norte", "el sureste"…), para los
-- avisos de huevos, cajas y jefes. Norte = -Z, igual que los portones de MapBuilder.

-- Devuelve la frase en español (Shared/Strings): se manda como argumento anidado, { Compass.direction(…) },
-- y la traduce cada cliente.

local Strings = require(script.Parent.Strings)

local later = Strings.later

local Compass = {}

local NAMES = {
	later("el este"),
	later("el sureste"),
	later("el sur"),
	later("el suroeste"),
	later("el oeste"),
	later("el noroeste"),
	later("el norte"),
	later("el noreste"),
}
-- Con "de" delante ("la playa del norte").
local OF_NAMES = {
	later("del este"),
	later("del sureste"),
	later("del sur"),
	later("del suroeste"),
	later("del oeste"),
	later("del noroeste"),
	later("del norte"),
	later("del noreste"),
}

local function index(from: Vector3, to: Vector3): number
	local offset = to - from
	local angle = math.atan2(offset.Z, offset.X) -- 0 = este, π/2 = sur
	return math.round(angle / (math.pi / 4)) % 8 + 1
end

function Compass.direction(from: Vector3, to: Vector3): string
	return NAMES[index(from, to)]
end

-- La misma dirección con "de" delante: "del norte".
function Compass.directionOf(from: Vector3, to: Vector3): string
	return OF_NAMES[index(from, to)]
end

return Compass
