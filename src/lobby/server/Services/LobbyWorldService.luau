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
	-- Con streaming, cada cliente solo carga lo cercano y las islas del horizonte (a 500-1.300 studs)
	-- desaparecen, sobre todo en móviles. El Lobby es ligero y no lo necesita.
	if workspace.StreamingEnabled then
		warn(
			"[LobbyWorldService] StreamingEnabled está activado en el Lobby: las islas lejanas no se verán. "
				.. "Desactívalo en Workspace (docs/RENDIMIENTO.md)."
		)
	end
end

return LobbyWorldService
