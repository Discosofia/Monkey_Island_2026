--!strict
-- Estado de vida de un jugador en la Isla (GDD §6.2), guardado en el atributo "LifeState":
--   Alive  → normal.
--   Downed → caído: se arrastra, no ataca ni recolecta; un aliado puede reanimarlo. Si nadie lo hace
--            a tiempo (o se rinde), reaparece en su cama o en el Basecamp (LifeService).
-- Solo LifeService (servidor) lo cambia; cualquiera puede leerlo.

export type State = "Alive" | "Downed"

local LifeState = {}

LifeState.ATTRIBUTE = "LifeState"

function LifeState.get(player: Player): State
	return if player:GetAttribute(LifeState.ATTRIBUTE) == "Downed" then "Downed" else "Alive"
end

function LifeState.isAlive(player: Player): boolean
	return LifeState.get(player) == "Alive"
end

return LifeState
