--!strict
-- Notificaciones del juego: cuando alguien entra al Lobby, avisa a sus amigos de Roblox con
-- "{amigo} está jugando… ¡Únete a su tropa!" (solo les llega a los que activaron las notificaciones
-- del juego; ver SocialPromptsController).
--
-- Necesita, en el Creator Hub y en Studio (docs/LANZAMIENTO.md §9):
--   - La cadena de notificación creada y su Asset ID en Config.Social.FriendJoinedMessageId.
--   - El paquete "Open Cloud" de Roblox (Creator Store) dentro de ServerScriptService del Lobby.
-- Sin alguna de las dos, no hace nada. Roblox limita a 1 notificación al día por jugador y juego.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)

local FriendNotifyService = {}

-- Módulo UserNotification del paquete Open Cloud (nil si no está instalado).
local userNotification: any = nil

-- true si este jugador ya avisó a sus amigos hace poco (en cualquier servidor). Si no, lo apunta.
local function claimCooldown(player: Player): boolean
	local ok, alreadyClaimed = pcall(function()
		local map = MemoryStoreService:GetHashMap("FriendNotify")
		local claimed = false
		map:UpdateAsync(tostring(player.UserId), function(previous)
			claimed = previous ~= nil
			return if claimed then nil else true
		end, Config.Social.FriendNotifyCooldownSeconds)
		return claimed
	end)
	return not ok or alreadyClaimed
end

local function friendIds(player: Player): { number }
	local ids = {}
	local ok, err = pcall(function()
		local pages = Players:GetFriendsAsync(player.UserId)
		while #ids < Config.Social.FriendNotifyMax do
			for _, friend in pages:GetCurrentPage() do
				if not Players:GetPlayerByUserId(friend.Id) then
					table.insert(ids, friend.Id)
					if #ids >= Config.Social.FriendNotifyMax then
						break
					end
				end
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then
		warn(`[FriendNotify] No se pudo leer la lista de amigos de {player.Name}: {err}`)
	end
	return ids
end

local function notifyFriends(player: Player)
	if claimCooldown(player) then
		return
	end
	local notification = {
		payload = {
			messageId = Config.Social.FriendJoinedMessageId,
			type = "MOMENT",
			parameters = {
				["userId-friend"] = { int64Value = player.UserId },
			},
			analyticsData = { category = "Amigo jugando" },
		},
	}
	local failures = 0
	local lastError = ""
	for _, friendId in friendIds(player) do
		local ok, result = pcall(userNotification.createUserNotification, friendId, notification)
		if not ok then
			failures += 1
			lastError = tostring(result)
		elseif typeof(result) == "table" and result.statusCode ~= 200 then
			failures += 1
			local err = result.error
			lastError = if typeof(err) == "table" then `{err.code} {err.message}` else tostring(result.statusCode)
		end
	end
	-- Un solo aviso por jugador para no llenar la Salida (los amigos sin notificaciones también fallan).
	if failures > 0 then
		warn(`[FriendNotify] {failures} aviso(s) sin enviar para {player.Name}. Último error: {lastError}`)
	end
end

function FriendNotifyService:Start()
	if Config.Social.FriendJoinedMessageId == "" or RunService:IsStudio() then
		return
	end
	local package = ServerScriptService:FindFirstChild("OpenCloud")
	local v2 = if package then package:FindFirstChild("V2") else nil
	local module = if v2 then v2:FindFirstChild("UserNotification") else nil
	if not (module and module:IsA("ModuleScript")) then
		warn("[FriendNotify] Falta el paquete Open Cloud en ServerScriptService (docs/LANZAMIENTO.md §9)")
		return
	end
	userNotification = (require :: any)(module)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(notifyFriends, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(notifyFriends, player)
	end
end

return FriendNotifyService
