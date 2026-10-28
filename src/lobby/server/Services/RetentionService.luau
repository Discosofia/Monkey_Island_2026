--!strict
-- Calendario de 7 días en el Lobby (bucle de retención, octubre de 2026): el cliente pide cobrar el
-- premio de hoy (la ventana al entrar o la pestaña Misiones; CalendarController, LobbyUIController) y
-- el servidor lo entrega (ServerShared/Retention) y le dice qué ha recibido. También tiene al día las
-- misiones del día y de la semana, que se cumplen en la Isla y en Dunas, y hace los cambios gratis.

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
	local day, lines, roll = Retention.claimLogin(player)
	if day and lines then
		Remotes.LoginClaimed:FireClient(player, day, lines, roll)
		Analytics.event(player, "LoginCalendarDay", day)
	end
end

local function onWelcomeSeen(player: Player)
	if canRequest(player) then
		Retention.welcomeSeen(player)
	end
end

local function onReroll(player: Player, scope: unknown, index: unknown)
	if not canRequest(player) or (scope ~= "daily" and scope ~= "weekly") or typeof(index) ~= "number" then
		return
	end
	local changed, message, args = Retention.reroll(player, scope :: string, index // 1)
	if changed then
		Remotes.Notify:FireClient(player, message, args)
	else
		Remotes.Notify:FireClient(player, "⚠️ {message}", { message = { message, args } })
	end
	if changed then
		Analytics.event(player, "MissionReroll", 1, { scope :: string })
	end
end

function RetentionService:Start()
	Remotes.ClaimLogin.OnServerEvent:Connect(onClaimLogin)
	Remotes.WelcomeSeen.OnServerEvent:Connect(onWelcomeSeen)
	Remotes.RerollMission.OnServerEvent:Connect(onReroll)
	-- Las misiones del día se ven ya en el Lobby (pestaña Misiones), antes de jugar.
	Retention.start()
end

return RetentionService
