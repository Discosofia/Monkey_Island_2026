--!strict
-- Panel de administradores (también en el juego publicado; ver Shared/UI/AdminPanel) y, para
-- todos los jugadores, el cartel de sus anuncios (Shared/UI/AnnounceBanner).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminPanel = require(ReplicatedStorage.Shared.UI.AdminPanel)
local AnnounceBanner = require(ReplicatedStorage.Shared.UI.AnnounceBanner)

local AdminController = {}

function AdminController:Start()
	AnnounceBanner.start()
	AdminPanel.start("Island")
end

return AdminController
