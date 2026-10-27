--!strict
-- Moderación desde el panel de administradores (T4c), en los tres places:
--   - Silenciar unos minutos (Config.AdminTools.MuteMinutes): el jugador no puede escribir en el chat
--     de este servidor (TextChatService, TextSource.CanSend) aunque salga y vuelva a entrar.
--   - Expulsar con un motivo.
--   - Banear unas horas (Config.AdminTools.BanHours) con un motivo: la API de baneos de Roblox
--     (Players:BanAsync, en toda la experiencia: no puede entrar a ningún place hasta que acaba, y le
--     enseña el motivo). Se quita con "Unban" por nombre de usuario.
--   - Ir hasta el jugador y congelarlo (anclado hasta que se le descongela, también si reaparece).
--     Espiar es solo del cliente (la cámara del admin, Shared/UI/AdminPanel).
-- Nada de esto vale contra otro administrador ni contra uno mismo (en Studio sí contra uno mismo,
-- salvo el baneo, para poder probarlo con un solo jugador). Los motivos pasan por el filtro de texto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AdminLog = require(script.Parent.AdminLog)
local RequestCooldown = require(script.Parent.RequestCooldown)

local Moderation = {}

local canRequest = RequestCooldown.new(1)
-- Hasta cuándo (os.clock) está silenciado cada UserId en este servidor.
local mutedUntil: { [number]: number } = {}
local frozen: { [number]: boolean } = {}

-- Texto de un administrador que verán otros, filtrado como el de cualquier jugador. nil si el
-- filtro no responde.
function Moderation.filter(text: string, fromUserId: number): string?
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, fromUserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	return if ok then filtered else nil
end

local function applyMute(userId: number)
	local muted = (mutedUntil[userId] or 0) > os.clock()
	for _, source in TextChatService:GetDescendants() do
		if source:IsA("TextSource") and source.UserId == userId then
			source.CanSend = not muted
		end
	end
end

local function setFrozen(player: Player, value: boolean)
	frozen[player.UserId] = if value then true else nil
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		root.Anchored = value
	end
	player:SetAttribute("Frozen", if value then true else nil)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Motivo limpio y filtrado (o el de por defecto si viene vacío). nil si el filtro falla.
local function reasonFrom(admin: Player, raw: any): string?
	local text = if typeof(raw) == "string" then string.gsub(raw, "^%s+", "") else ""
	text = string.sub(text, 1, Config.AdminTools.ReasonMaxLength)
	if text == "" then
		return "Decisión de un administrador"
	end
	return Moderation.filter(text, admin.UserId)
end

local function hoursText(hours: number): string
	if hours < 24 then
		return `{hours} h`
	end
	return `{hours // 24} día(s)`
end

-- Las acciones sobre un jugador de este servidor. Devuelven el texto para el administrador.
type Handler = (admin: Player, target: Player, a: any, b: any) -> string?
local ACTIONS: { [string]: Handler } = {
	Mute = function(admin, target, minutes)
		if not table.find(Config.AdminTools.MuteMinutes, minutes) then
			return nil
		end
		mutedUntil[target.UserId] = os.clock() + minutes * 60
		applyMute(target.UserId)
		task.delay(minutes * 60, function()
			applyMute(target.UserId)
		end)
		Remotes.Notify:FireClient(target, `🔇 Un administrador te ha silenciado en el chat {minutes} min`)
		AdminLog.add(admin, "Silenciar", `{target.DisplayName} (@{target.Name}) · {minutes} min`)
		return `🔇 {target.DisplayName} silenciado {minutes} min`
	end,
	Unmute = function(admin, target)
		mutedUntil[target.UserId] = nil
		applyMute(target.UserId)
		Remotes.Notify:FireClient(target, "🔊 Ya puedes volver a escribir en el chat")
		AdminLog.add(admin, "Quitar silencio", `{target.DisplayName} (@{target.Name})`)
		return `🔊 {target.DisplayName} puede volver a escribir`
	end,
	Kick = function(admin, target, rawReason)
		local reason = reasonFrom(admin, rawReason)
		if not reason then
			return "⚠️ El filtro de texto no responde: prueba en un momento"
		end
		AdminLog.add(admin, "Expulsar", `{target.DisplayName} (@{target.Name}) · {reason}`)
		target:Kick(`Te ha expulsado un administrador. Motivo: {reason}`)
		return `👢 {target.DisplayName} expulsado`
	end,
	Ban = function(admin, target, hours, rawReason)
		if not table.find(Config.AdminTools.BanHours, hours) then
			return nil
		end
		if target == admin then
			return "⛔ No puedes banearte a ti mismo"
		end
		local reason = reasonFrom(admin, rawReason)
		if not reason then
			return "⚠️ El filtro de texto no responde: prueba en un momento"
		end
		local ok, err = pcall(function()
			Players:BanAsync({
				UserIds = { target.UserId },
				ApplyToUniverse = true,
				Duration = hours * 3600,
				DisplayReason = reason,
				PrivateReason = `Panel de administración · {admin.Name} ({admin.UserId})`,
				ExcludeAltAccounts = false,
			})
		end)
		if not ok then
			warn(`[Moderation] BanAsync falló: {err}`)
			return "⚠️ Roblox no aceptó el baneo (en Studio no se puede): no se ha baneado"
		end
		AdminLog.add(admin, "Banear", `{target.DisplayName} (@{target.Name}) · {hoursText(hours)} · {reason}`)
		return `⛔ {target.DisplayName} baneado {hoursText(hours)}`
	end,
	Goto = function(admin, target)
		local from, to = rootOf(admin), rootOf(target)
		if not (from and to and admin.Character) then
			return "📍 Uno de los dos no tiene personaje ahora"
		end
		(admin.Character :: Model):PivotTo(to.CFrame * CFrame.new(0, 0, 5))
		AdminLog.add(admin, "Ir hasta", `{target.DisplayName} (@{target.Name})`)
		return `📍 Junto a {target.DisplayName}`
	end,
	Freeze = function(admin, target)
		setFrozen(target, true)
		Remotes.Notify:FireClient(target, "❄️ Un administrador te ha congelado")
		AdminLog.add(admin, "Congelar", `{target.DisplayName} (@{target.Name})`)
		return `❄️ {target.DisplayName} congelado`
	end,
	Unfreeze = function(admin, target)
		setFrozen(target, false)
		Remotes.Notify:FireClient(target, "🔥 Ya puedes moverte")
		AdminLog.add(admin, "Descongelar", `{target.DisplayName} (@{target.Name})`)
		return `🔥 {target.DisplayName} descongelado`
	end,
}

-- Quitar un baneo por nombre de usuario (el jugador no está: no puede entrar).
local function unban(admin: Player, name: any)
	if typeof(name) ~= "string" or name == "" then
		return
	end
	local ok, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(name)
	end)
	if not ok or typeof(userId) ~= "number" then
		Remotes.Notify:FireClient(admin, `No existe el usuario «{name}»`)
		return
	end
	local done, err = pcall(function()
		Players:UnbanAsync({ UserIds = { userId }, ApplyToUniverse = true })
	end)
	if not done then
		warn(`[Moderation] UnbanAsync falló: {err}`)
		Remotes.Notify:FireClient(admin, "⚠️ Roblox no aceptó quitar el baneo")
		return
	end
	AdminLog.add(admin, "Quitar baneo", `@{name} ({userId})`)
	Remotes.Notify:FireClient(admin, `✅ @{name} ya puede volver a entrar`)
end

function Moderation.start(isAdmin: (Player) -> boolean)
	Remotes.AdminModerate.OnServerEvent:Connect(function(admin: Player, action: any, userId: any, a: any, b: any)
		if not isAdmin(admin) or not canRequest(admin) then
			return
		end
		if action == "Unban" then
			unban(admin, userId)
			return
		end
		local handler = if typeof(action) == "string" then ACTIONS[action] else nil
		local target = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		if not handler then
			return
		end
		if not target then
			Remotes.Notify:FireClient(admin, "Ese jugador ya no está en el servidor")
			return
		end
		if target == admin and not RunService:IsStudio() then
			Remotes.Notify:FireClient(admin, "🛡️ No puedes moderarte a ti mismo")
			return
		end
		if target ~= admin and isAdmin(target) then
			Remotes.Notify:FireClient(admin, "🛡️ No se puede moderar a otro administrador")
			return
		end
		local text = handler(admin, target, a, b)
		if text then
			Remotes.Notify:FireClient(admin, text)
		end
	end)

	-- Un silenciado que vuelve a entrar (o un canal nuevo, como un susurro) sigue silenciado.
	TextChatService.DescendantAdded:Connect(function(object)
		if object:IsA("TextSource") and mutedUntil[object.UserId] then
			applyMute(object.UserId)
		end
	end)
	-- Un congelado que reaparece sigue congelado.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			if frozen[player.UserId] then
				task.defer(setFrozen, player, true)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return Moderation
