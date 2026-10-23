--!strict
-- Panel de administradores (también en el juego publicado). Ver Shared/UI/AdminPanel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminPanel = require(ReplicatedStorage.Shared.UI.AdminPanel)

local AdminController = {}

function AdminController:Start()
	AdminPanel.start("Island")
end

return AdminController
