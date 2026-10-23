--!strict
-- Monturas (Fase 11). La lógica está en ServerShared/MountServer.

local ServerScriptService = game:GetService("ServerScriptService")

local MountServer = require(ServerScriptService.ServerShared.MountServer)

local MountService = {}

function MountService:Start()
	MountServer.start()
end

return MountService
