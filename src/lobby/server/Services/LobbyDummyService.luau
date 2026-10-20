--!strict
-- Muñecos de práctica en la plaza del Lobby, para probar las armas y las habilidades del rol antes de
-- zarpar (Combat/TrainingDummies, los mismos del Basecamp de la Isla). Dónde van lo dice el escenario
-- (World/LobbyBuilder.practiceSpots), que ya está construido al llegar aquí (LobbyWorldService:Init).

local ServerScriptService = game:GetService("ServerScriptService")

local TrainingDummies = require(ServerScriptService.Combat.TrainingDummies)
local LobbyBuilder = require(script.Parent.Parent.World.LobbyBuilder)

local LobbyDummyService = {}

function LobbyDummyService:Start()
	local spots, lookAt = LobbyBuilder.practiceSpots()
	TrainingDummies.place(spots, lookAt)
end

return LobbyDummyService
