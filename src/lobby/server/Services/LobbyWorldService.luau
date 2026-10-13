--!strict
-- Escenario del Lobby (naufragio de la «Esperanza»). Si el place no lo tiene guardado (nadie ejecutó
-- World/LobbyBuilder en Studio), lo construye al arrancar el servidor para que el Lobby nunca sea
-- una placa vacía.

local LobbyBuilder = require(script.Parent.Parent.World.LobbyBuilder)

local LobbyWorldService = {}

function LobbyWorldService:Init()
	if not LobbyBuilder.isBuilt() then
		LobbyBuilder.build({ force = true })
	end
end

return LobbyWorldService
