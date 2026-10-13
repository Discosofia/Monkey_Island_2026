--!strict
-- Escenario del Lobby (naufragio del carguero «Esperanza»). Si el place no lo tiene guardado (nadie
-- ejecutó World/LobbyBuilder en Studio) o tiene una versión anterior, lo construye al arrancar el
-- servidor para que el Lobby nunca sea una placa vacía ni se quede desfasado.

local LobbyBuilder = require(script.Parent.Parent.World.LobbyBuilder)

local LobbyWorldService = {}

function LobbyWorldService:Init()
	if not LobbyBuilder.isBuilt() then
		LobbyBuilder.build({ force = true })
	end
end

return LobbyWorldService
