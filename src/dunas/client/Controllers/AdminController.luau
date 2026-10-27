--!strict
-- Panel de administradores (también en el juego publicado; ver Shared/UI/AdminPanel) y, para
-- todos los jugadores, el cartel de sus anuncios (Shared/UI/AnnounceBanner) y la franja de los
-- eventos en vivo (Shared/UI/LiveEventsBand).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminPanel = require(ReplicatedStorage.Shared.UI.AdminPanel)
local AnnounceBanner = require(ReplicatedStorage.Shared.UI.AnnounceBanner)
local LiveEventsBand = require(ReplicatedStorage.Shared.UI.LiveEventsBand)

local AdminController = {}

function AdminController:Start()
	AnnounceBanner.start()
	LiveEventsBand.start()
	AdminPanel.start("Dunas")
end

return AdminController
