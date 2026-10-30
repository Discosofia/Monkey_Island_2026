--!strict
-- Administradores (Config.Admins y el dueño del juego), en los tres places y también en el juego
-- publicado. Desde el panel (Shared/UI/AdminPanel) pueden:
--   - darle a un jugador de su servidor todo lo que se puede tener (grantAll: todos los cosméticos,
--     emotes incluidos, todas las mascotas y todas las monturas) o una sola cosa del listado (un
--     cosmético, una mascota, una montura o un huevo de una rareza);
--   - "Dar a todos": lo mismo a todos los jugadores de este servidor o de todos (ServerShared/AdminNet);
--   - mandar un anuncio a este servidor o a todos (filtrado por TextService);
--   - ver el registro de acciones de los administradores (ServerShared/AdminLog);
--   - lanzar y parar eventos en vivo (ServerShared/LiveEventsServer) y hacer cosas al momento en las
--     partidas de la Isla (Data/IslandActions), en este servidor o en todos;
--   - moderar a un jugador (ServerShared/Moderation), ver y arreglar su perfil (ServerShared/AdminProfile)
--     y ver los servidores o programar un mantenimiento (ServerShared/ServerOps);
--   - medir el rendimiento del servidor y de su cliente en la pestaña Rendimiento (ServerShared/Performance).
-- No toca el Ámbar, las mejoras ni los talentos. El cliente enseña el panel si el Player lleva el
-- atributo "IsAdmin", pero el servidor lo vuelve a comprobar en cada petición.
-- Lo cambia con PlayerData.update, así que respeta el bloqueo de sesión del perfil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local IslandActions = require(ReplicatedStorage.Shared.Data.IslandActions)
local LiveEventCatalog = require(ReplicatedStorage.Shared.Data.LiveEvents)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AdminLog = require(script.Parent.AdminLog)
local AdminNet = require(script.Parent.AdminNet)
local AdminProfile = require(script.Parent.AdminProfile)
local CosmeticsServer = require(script.Parent.CosmeticsServer)
local Eggs = require(script.Parent.Eggs)
local LiveEventsServer = require(script.Parent.LiveEventsServer)
local Moderation = require(script.Parent.Moderation)
local PlayerData = require(script.Parent.PlayerData)
local Performance = require(script.Parent.Performance)
local RequestCooldown = require(script.Parent.RequestCooldown)
local ServerOps = require(script.Parent.ServerOps)

local Admin = {}

-- Place de este servidor ("Lobby", "Island", "Dunas" o "Laboratorio"), de Admin.start.
local place = "?"

local canRequest = RequestCooldown.new(1)
-- Lo que llega a todos los jugadores (dar a todos, anuncios), más espaciado.
local canBroadcast = RequestCooldown.new(5)

local SCOPE_TEXT = { Server = "este servidor", All = "todos los servidores" }

function Admin.isAdmin(player: Player): boolean
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(Config.Admins, player.UserId) ~= nil
end

-- Le da a "player" todo lo que se puede tener y lo guarda. false si su perfil no está cargado.
function Admin.grantAll(player: Player): boolean
	if not PlayerData.get(player) then
		return false
	end
	PlayerData.update(player, function(current)
		for cosmeticId in Cosmetics do
			current.ownedCosmetics[cosmeticId] = true
		end
		for petId in Pets do
			current.pets[petId] = math.max(current.pets[petId] or 0, 1)
		end
		for mountId in Mounts do
			current.mounts[mountId] = math.max(current.mounts[mountId] or 0, 1)
		end
	end)
	CosmeticsServer.refresh(player)
	task.spawn(PlayerData.saveNow, player)
	return true
end

-- Dónde queda un huevo regalado (Eggs.grant).
local EGG_PLACES = { nest = "en el nido", bag = "en la mochila", pending = "pendiente (mochila llena)" }

-- Lo que dice el aviso de una cosa del listado, o nil si no existe. "All" es todo (grantAll). Las
-- rarezas de huevo son las que tienen tiempo de eclosión (Config.Egg.HatchHours).
local function describe(kind: string, id: string): string?
	if kind == "All" then
		return "🔓 Todo (cosméticos, emotes, mascotas y monturas)"
	elseif kind == "Cosmetic" and Cosmetics[id] then
		return `{Cosmetics[id].icon} {Cosmetics[id].name}`
	elseif kind == "Pet" and Pets[id] then
		return `{Pets[id].icon} {Pets[id].name}`
	elseif kind == "Mount" and Mounts[id] then
		return `{Mounts[id].icon} {Mounts[id].name}`
	elseif kind == "Egg" and (Config.Egg.HatchHours :: any)[id] then
		return `🥚 Huevo {Rarities[id].name}`
	end
	return nil
end

-- Le da a "target" la cosa "kind"/"id" (ya comprobada con describe) y le avisa si no es "admin".
-- Devuelve si la recibió y el texto para el administrador.
local function giveOne(target: Player, kind: string, id: string, label: string, admin: Player?): (boolean, string)
	local profile = PlayerData.get(target)
	if not profile then
		return false, `El perfil de {target.Name} aún no ha cargado: prueba en un momento`
	end
	local gift: string
	if kind == "All" then
		Admin.grantAll(target)
		if target ~= admin then
			Remotes.Notify:FireClient(
				target,
				"🎁 ¡Te han desbloqueado todo: cosméticos, emotes, mascotas y monturas!"
			)
		end
		return true, `🔓 {target.DisplayName} ya lo tiene todo`
	elseif kind == "Cosmetic" then
		-- grant avisa al jugador si es nuevo; si ya lo tenía no cambia nada.
		if not CosmeticsServer.grant(target, id) then
			return false, `{target.DisplayName} ya tenía {label}`
		end
		task.spawn(PlayerData.saveNow, target)
		return true, `🎁 {target.DisplayName} ya tiene {label}`
	elseif kind == "Pet" or kind == "Mount" then
		-- Se tiene una de cada, como al abrir un huevo (no se la pone).
		local owned = if kind == "Pet" then profile.pets else profile.mounts
		if (owned[id] or 0) > 0 then
			return false, `{target.DisplayName} ya tenía {label}`
		end
		PlayerData.update(target, function(current)
			local list = if kind == "Pet" then current.pets else current.mounts
			list[id] = 1
		end)
		gift = `🎁 ¡Te han regalado {if kind == "Pet" then "una mascota" else "una montura"}: {label}!`
	else
		local where = Eggs.grant(target, id)
		if not where then
			return false, `No se pudo dar el huevo a {target.DisplayName}`
		end
		if target ~= admin then
			Remotes.Notify:FireClient(target, `🎁 ¡Te han regalado un {label}! Está {EGG_PLACES[where]}`)
		end
		task.spawn(PlayerData.saveNow, target)
		return true, `🎁 {label} para {target.DisplayName}: {EGG_PLACES[where]}`
	end
	if target ~= admin then
		Remotes.Notify:FireClient(target, gift)
	end
	task.spawn(PlayerData.saveNow, target)
	return true, `🎁 {target.DisplayName} ya tiene {label}`
end

-- Una sola cosa elegida del listado del panel (o "All", todo) para un jugador del servidor.
local function onGive(admin: Player, userId: any, kind: any, id: any)
	if typeof(userId) ~= "number" or typeof(kind) ~= "string" or typeof(id) ~= "string" then
		return
	end
	if not Admin.isAdmin(admin) then
		return
	end
	local label = describe(kind, id)
	if not label or not canRequest(admin) then
		return
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target then
		Remotes.Notify:FireClient(admin, "Ese jugador ya no está en el servidor")
		return
	end
	local given, text = giveOne(target, kind, id, label, admin)
	if given then
		AdminLog.add(admin, "Dar", `{label} a {target.DisplayName} (@{target.Name})`)
	end
	Remotes.Notify:FireClient(admin, text)
end

local function onGiveAll(admin: Player, userId: any)
	onGive(admin, userId, "All", "All")
end

-- "Dar a todos": cada servidor que recibe el mensaje se lo da a sus jugadores (AdminNet).
AdminNet.on("GiveEveryone", function(data: any)
	local label = describe(data.kind, data.id)
	if not label then
		return
	end
	local count = 0
	for _, target in Players:GetPlayers() do
		if giveOne(target, data.kind, data.id, label, nil) then
			count += 1
		end
	end
	local admin = Players:GetPlayerByUserId(data.admin)
	if admin then
		Remotes.Notify:FireClient(admin, `🎁 {label}: dado a {count} jugador(es) de este servidor`)
	end
end)

local function onGiveEveryone(admin: Player, kind: any, id: any, scope: any)
	if typeof(kind) ~= "string" or typeof(id) ~= "string" or not AdminNet.isScope(scope) then
		return
	end
	if not Admin.isAdmin(admin) then
		return
	end
	local label = describe(kind, id)
	if not label or not canBroadcast(admin) then
		return
	end
	AdminLog.add(admin, "Dar a todos", `{label} · {SCOPE_TEXT[scope]}`)
	if not AdminNet.send("GiveEveryone", { kind = kind, id = id, admin = admin.UserId }, scope) then
		Remotes.Notify:FireClient(admin, "⚠️ No se pudo llegar a los demás servidores: solo en este")
	end
end

AdminNet.on("Announce", function(data: any)
	if typeof(data.text) == "string" and typeof(data.from) == "string" then
		-- Con "args", un aviso del juego (plantilla de Shared/Strings) que el cliente traduce.
		Remotes.Announce:FireAllClients(data.text, data.from, if typeof(data.args) == "table" then data.args else nil)
	end
end)

local function onAnnounce(admin: Player, text: any, scope: any)
	if typeof(text) ~= "string" or not AdminNet.isScope(scope) or not Admin.isAdmin(admin) then
		return
	end
	text = string.sub(string.gsub(text, "^%s+", ""), 1, Config.AdminTools.AnnounceMaxLength)
	if text == "" or not canBroadcast(admin) then
		return
	end
	-- Lo que se enseña a todos pasa por el filtro de Roblox, como cualquier texto de un jugador.
	local filtered = Moderation.filter(text, admin.UserId)
	if not filtered then
		Remotes.Notify:FireClient(admin, "⚠️ El filtro de texto no responde: prueba en un momento")
		return
	end
	AdminLog.add(admin, "Anuncio", `{SCOPE_TEXT[scope]}: {filtered}`)
	if not AdminNet.send("Announce", { text = filtered, from = admin.DisplayName }, scope) then
		Remotes.Notify:FireClient(admin, "⚠️ No se pudo llegar a los demás servidores: solo en este")
	end
end

local function onLog(admin: Player)
	if Admin.isAdmin(admin) and canRequest(admin) then
		Remotes.AdminLog:FireClient(admin, AdminLog.recent())
	end
end

-- Eventos en vivo (ServerShared/LiveEventsServer): "Start" con tipo, minutos, retraso y alcance, o
-- "Stop" con su id.
local function onLiveEvent(admin: Player, op: any, a: any, b: any, c: any, d: any)
	if not Admin.isAdmin(admin) or not canBroadcast(admin) then
		return
	end
	if op == "Stop" and typeof(a) == "string" then
		if LiveEventsServer.stop(a) then
			AdminLog.add(admin, "Parar evento", a)
			Remotes.Notify:FireClient(admin, "⏹ Evento parado")
		end
		return
	end
	local info = if typeof(a) == "string" then LiveEventCatalog[a] else nil
	if op ~= "Start" or not info or info.hidden or not AdminNet.isScope(d) then
		return
	end
	if not table.find(Config.LiveEvents.Durations, b) or not table.find(Config.LiveEvents.Delays, c) then
		return
	end
	local event, reached = LiveEventsServer.start(a, b, c, d, admin.DisplayName)
	if not event then
		return
	end
	local length = if info.seconds then `{info.seconds // 60} min` else `{b} min`
	local when = if c > 0 then `en {c} min` else "ya"
	AdminLog.add(admin, "Evento", `{info.icon} {info.name} · {when} · {length} · {SCOPE_TEXT[d]}`)
	if not reached then
		Remotes.Notify:FireClient(admin, "⚠️ No se pudo llegar a los demás servidores: solo en este")
	elseif c > 0 then
		Remotes.Notify:FireClient(admin, `{info.icon} {info.name} programado: empieza {when}`)
	end
end

-- Place de este servidor ("Lobby", "Island", "Dunas" o "Laboratorio"; "?" hasta que arranca Admin.start).
function Admin.place(): string
	return place
end

-- Acciones al momento en la Isla (Data/IslandActions). Las hace el AdminEventsService de la Isla al
-- recibir "IslandAction"; en los demás places solo tienen sentido para todos los servidores, salvo "Giant" y
-- "Boss", que valen en los 4 (A3 y A4 de la Fase 18). "bossId": el jefe elegido para "Boss" (opcional).
local function onIslandAction(admin: Player, action: any, scope: any, bossId: any)
	if typeof(action) ~= "string" or not IslandActions[action] or not AdminNet.isScope(scope) then
		return
	end
	if not Admin.isAdmin(admin) or not canRequest(admin) then
		return
	end
	-- "Ser gigante" y "Jefe" valen en los 4 places: en el servidor donde está quien lo pide.
	if scope == "Server" and place ~= "Island" and action ~= "Giant" and action ~= "Boss" and action ~= "RedMoon" then
		Remotes.Notify:FireClient(admin, "🏝️ Aquí no hay partida de la Isla: elige «Todos los servidores»")
		return
	end
	local info = IslandActions[action]
	AdminLog.add(admin, "Isla", `{info.icon} {info.name} · {SCOPE_TEXT[scope]}`)
	-- La luna roja es un evento en vivo (B3): el interruptor lo enciende o lo apaga aquí, sin pasar por la Isla.
	if action == "RedMoon" then
		local running = LiveEventsServer.runningId("RedMoon")
		if running then
			LiveEventsServer.stop(running)
			Remotes.Notify:FireClient(admin, `{info.icon} {info.name}: apagada`)
		else
			local event, reached =
				LiveEventsServer.start("RedMoon", Config.LiveEvents.RedMoon.DefaultMinutes, 0, scope, admin.DisplayName)
			if event and not reached then
				Remotes.Notify:FireClient(admin, "⚠️ No se pudo llegar a los demás servidores: solo en este")
			end
		end
		return
	end
	-- Un jefe que no existe se ignora: sale uno al azar de la rotación.
	local boss = if action == "Boss" and typeof(bossId) == "string" and Bosses[bossId] then bossId else nil
	if not AdminNet.send("IslandAction", { action = action, admin = admin.UserId, boss = boss }, scope) then
		Remotes.Notify:FireClient(admin, "⚠️ No se pudo llegar a los demás servidores: solo en este")
	end
end

-- Lo llaman los AdminService de cada place ("Lobby", "Island", "Dunas" o "Laboratorio", para el registro).
function Admin.start(placeName: string)
	place = placeName
	AdminLog.start(placeName)
	AdminNet.start()
	LiveEventsServer.run()
	Moderation.start(Admin.isAdmin)
	AdminProfile.start(Admin.isAdmin)
	ServerOps.start(placeName, Admin.isAdmin)
	Performance.start(placeName, Admin.isAdmin)
	Remotes.AdminLiveEvent.OnServerEvent:Connect(onLiveEvent)
	Remotes.AdminIslandAction.OnServerEvent:Connect(onIslandAction)
	Remotes.AdminGiveAll.OnServerEvent:Connect(onGiveAll)
	Remotes.AdminGive.OnServerEvent:Connect(onGive)
	Remotes.AdminGiveEveryone.OnServerEvent:Connect(onGiveEveryone)
	Remotes.AdminAnnounce.OnServerEvent:Connect(onAnnounce)
	Remotes.AdminLog.OnServerEvent:Connect(onLog)
	local function mark(player: Player)
		if Admin.isAdmin(player) then
			player:SetAttribute("IsAdmin", true)
		end
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
end

return Admin
