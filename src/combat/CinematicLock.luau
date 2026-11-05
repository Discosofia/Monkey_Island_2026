--!strict
-- Bloqueo de las cinemáticas con "freeze" (Fase 25). Mientras dura, los monos y jefes no actúan, nadie recibe
-- daño (CombatService) y el hambre y la sed se paran. Lo guarda el atributo "CinematicUntil" de ReplicatedStorage
-- (hora de Workspace:GetServerTimeNow). Lo activa CinematicService (solo en la Isla): en el Lobby, Dunas y el
-- Laboratorio nadie lo pone, así que active() es siempre false.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ATTRIBUTE = "CinematicUntil"

local CinematicLock = {}

-- Bloquea hasta la hora "untilTime" (GetServerTimeNow). Si ya había un bloqueo más largo, se queda ese.
function CinematicLock.lock(untilTime: number)
	local current = ReplicatedStorage:GetAttribute(ATTRIBUTE)
	if typeof(current) == "number" and current > untilTime then
		return
	end
	ReplicatedStorage:SetAttribute(ATTRIBUTE, untilTime)
end

function CinematicLock.unlock()
	ReplicatedStorage:SetAttribute(ATTRIBUTE, nil)
end

-- true mientras dura el bloqueo.
function CinematicLock.active(): boolean
	local untilTime = ReplicatedStorage:GetAttribute(ATTRIBUTE)
	return typeof(untilTime) == "number" and Workspace:GetServerTimeNow() < untilTime
end

return CinematicLock
