--!strict
-- Calendario de 7 días en el Lobby (bucle de retención, octubre de 2026): el cliente pide cobrar el
-- premio de hoy (la ventana al entrar o la pestaña Misiones; CalendarController, LobbyUIController) y
-- el servidor lo entrega (ServerShared/Retention) y le dice qué ha recibido.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(ServerScriptService.ServerShared.Analytics)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local Retention = require(ServerScriptService.ServerShared.Retention)

local RetentionService = {}

local canRequest = RequestCooldown.new(1)

local function onClaimLogin(player: Player)
	if not canRequest(player) then
		return
	end
	local day, lines = Retention.claimLogin(player)
	if day and lines then
		Remotes.LoginClaimed:FireClient(player, day, lines)
		Analytics.event(player, "LoginCalendarDay", day)
	end
end

function RetentionService:Start()
	Remotes.ClaimLogin.OnServerEvent:Connect(onClaimLogin)
end

return RetentionService
