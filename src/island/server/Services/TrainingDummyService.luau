--!strict
-- Muñecos de práctica en el Basecamp para probar el combate hasta que lleguen los monos (Fase 1.4).
-- Los construye y los hace reaparecer Combat/TrainingDummies (los mismos de la plaza del Lobby), con
-- el de sparring, que devuelve los golpes para practicar el bloqueo y el parry.

local ServerScriptService = game:GetService("ServerScriptService")

local TrainingDummies = require(ServerScriptService.Combat.TrainingDummies)
local BasecampService = require(script.Parent.BasecampService)

-- Posiciones respecto al centro del Basecamp: al este de la hoguera, mirando hacia ella.
local DUMMY_OFFSETS = { Vector3.new(45, 0, -10), Vector3.new(45, 0, 0), Vector3.new(45, 0, 10) }
-- El de sparring (devuelve los golpes, Fase 10 C6), al final de la fila.
local SPARRING_OFFSET = Vector3.new(45, 0, 22)

local TrainingDummyService = {}

function TrainingDummyService:Start()
	local center = BasecampService.getCenter()
	local spots = {}
	for _, offset in DUMMY_OFFSETS do
		table.insert(spots, center + offset)
	end
	TrainingDummies.place(spots, center)
	TrainingDummies.placeSparring(center + SPARRING_OFFSET, center)
end

return TrainingDummyService
