--!strict
-- Administradores: panel de administración (dar, dar a todos, anuncios y registro). La lógica está en ServerShared/Admin.

local ServerScriptService = game:GetService("ServerScriptService")

local Admin = require(ServerScriptService.ServerShared.Admin)

local AdminService = {}

function AdminService:Start()
	Admin.start("Dunas")
end

return AdminService
