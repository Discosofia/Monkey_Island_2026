--!strict
-- Administradores: dar todo a un jugador del servidor. La lógica está en ServerShared/Admin.

local ServerScriptService = game:GetService("ServerScriptService")

local Admin = require(ServerScriptService.ServerShared.Admin)

local AdminService = {}

function AdminService:Start()
	Admin.start()
end

return AdminService
