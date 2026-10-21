--!strict
-- Pase de temporada en este place (ServerShared/SeasonPass): registra sus compras (la premium, el
-- pack y los niveles; ServerShared/Purchases) y lo pone en marcha. Aquí se gana la XP de
-- las partidas (con el extra si juegas con amigos).

local ServerScriptService = game:GetService("ServerScriptService")

local SeasonPass = require(ServerScriptService.ServerShared.SeasonPass)

local SeasonService = {}

function SeasonService:Start()
	SeasonPass.init()
	SeasonPass.start()
	SeasonPass.trackFriends()
end

return SeasonService
