--!strict
-- Estado de vida de un jugador en la Isla (GDD §6.2), guardado en el atributo "LifeState":
--   Alive  → normal.
--   Downed → caído: se arrastra, no ataca ni recolecta; un aliado puede reanimarlo.
--   Spirit → Espíritu: no recibe daño ni ataca; marca enemigos y reaparece al amanecer.
-- Solo LifeService (servidor) lo cambia; cualquiera puede leerlo.

export type State = "Alive" | "Downed" | "Spirit"

local LifeState = {}

LifeState.ATTRIBUTE = "LifeState"

function LifeState.get(player: Player): State
	local value = player:GetAttribute(LifeState.ATTRIBUTE)
	if value == "Downed" or value == "Spirit" then
		return value
	end
	return "Alive"
end

function LifeState.isAlive(player: Player): boolean
	return LifeState.get(player) == "Alive"
end

return LifeState
