--!strict
-- Muñecos de práctica en el Basecamp para probar el combate hasta que lleguen los monos (Fase 1.4).
-- Los construye y los hace reaparecer Combat/TrainingDummies (los mismos de la plaza del Lobby).

local ServerScriptService = game:GetService("ServerScriptService")

local TrainingDummies = require(ServerScriptService.Combat.TrainingDummies)
local BasecampService = require(script.Parent.BasecampService)

-- Posiciones respecto al centro del Basecamp: al este de la hoguera, mirando hacia ella.
local DUMMY_OFFSETS = { Vector3.new(45, 0, -10), Vector3.new(45, 0, 0), Vector3.new(45, 0, 10) }

local TrainingDummyService = {}

function TrainingDummyService:Start()
	local center = BasecampService.getCenter()
	local spots = {}
	for _, offset in DUMMY_OFFSETS do
		table.insert(spots, center + offset)
	end
	TrainingDummies.place(spots, center)
end

return TrainingDummyService
