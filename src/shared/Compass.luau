--!strict
-- Dirección aproximada de un punto visto desde el Basecamp ("el norte", "el sureste"…), para los
-- avisos de huevos, cajas y jefes. Norte = -Z, igual que los portones de MapBuilder.

local Compass = {}

local NAMES = { "el este", "el sureste", "el sur", "el suroeste", "el oeste", "el noroeste", "el norte", "el noreste" }

function Compass.direction(from: Vector3, to: Vector3): string
	local offset = to - from
	local angle = math.atan2(offset.Z, offset.X) -- 0 = este, π/2 = sur
	local index = math.round(angle / (math.pi / 4)) % 8 + 1
	return NAMES[index]
end

return Compass
