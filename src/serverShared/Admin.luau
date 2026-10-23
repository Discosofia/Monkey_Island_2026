--!strict
-- Administradores (Config.Admins y el dueño del juego), en los tres places y también en el juego
-- publicado: pueden darle a un jugador de su servidor todo lo que se puede tener (grantAll): todos los
-- cosméticos (emotes incluidos), todas las mascotas y todas las monturas; o una sola cosa elegida del
-- listado (onGive): un cosmético, una mascota, una montura o un huevo de una rareza. No toca el Ámbar, las mejoras
-- ni los talentos. El cliente enseña el panel (Shared/UI/AdminPanel) si el Player lleva el
-- atributo "IsAdmin", pero el servidor lo vuelve a comprobar en cada petición.
-- Lo cambia con PlayerData.update, así que respeta el bloqueo de sesión del perfil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CosmeticsServer = require(script.Parent.CosmeticsServer)
local Eggs = require(script.Parent.Eggs)
local PlayerData = require(script.Parent.PlayerData)
local RequestCooldown = require(script.Parent.RequestCooldown)

local Admin = {}

local canRequest = RequestCooldown.new(1)

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

local function onGiveAll(admin: Player, userId: any)
	if typeof(userId) ~= "number" or not Admin.isAdmin(admin) or not canRequest(admin) then
		return
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target then
		Remotes.Notify:FireClient(admin, "Ese jugador ya no está en el servidor")
		return
	end
	if not Admin.grantAll(target) then
		Remotes.Notify:FireClient(admin, `El perfil de {target.Name} aún no ha cargado: prueba en un momento`)
		return
	end
	print(`[Admin] {admin.Name} ({admin.UserId}) le ha dado todo a {target.Name} ({target.UserId})`)
	Remotes.Notify:FireClient(admin, `🔓 {target.DisplayName} ya lo tiene todo`)
	if target ~= admin then
		Remotes.Notify:FireClient(target, "🎁 ¡Te han desbloqueado todo: cosméticos, emotes, mascotas y monturas!")
	end
end

-- Dónde queda un huevo regalado (Eggs.grant).
local EGG_PLACES = { nest = "en el nido", bag = "en la mochila", pending = "pendiente (mochila llena)" }

-- Lo que dice el aviso de una cosa del listado, o nil si no existe. Las rarezas de huevo son las que
-- tienen tiempo de eclosión (Config.Egg.HatchHours: el Mítico no sale de los huevos).
local function describe(kind: string, id: string): string?
	if kind == "Cosmetic" and Cosmetics[id] then
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

-- Una sola cosa elegida del listado del panel: "kind" es "Cosmetic", "Pet", "Mount" o "Egg" e "id" su
-- id de Data/Cosmetics, Data/Pets o Data/Mounts, o la rareza del huevo.
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
	if not PlayerData.get(target) then
		Remotes.Notify:FireClient(admin, `El perfil de {target.Name} aún no ha cargado: prueba en un momento`)
		return
	end
	local done: string
	if kind == "Cosmetic" then
		-- grant avisa al jugador si es nuevo; si ya lo tenía no cambia nada.
		if not CosmeticsServer.grant(target, id) then
			Remotes.Notify:FireClient(admin, `{target.DisplayName} ya tenía {label}`)
			return
		end
		done = `🎁 {target.DisplayName} ya tiene {label}`
	elseif kind == "Pet" then
		-- Como al abrir un huevo: una más en su colección (no se la pone).
		PlayerData.update(target, function(current)
			current.pets[id] = (current.pets[id] or 0) + 1
		end)
		done = `🎁 {target.DisplayName} ya tiene {label}`
		if target ~= admin then
			Remotes.Notify:FireClient(target, `🎁 ¡Te han regalado una mascota: {label}!`)
		end
	elseif kind == "Mount" then
		-- Una montura se tiene o no (los huevos solo dan las que faltan): no se le pone.
		local profile = PlayerData.get(target)
		if profile and (profile.mounts[id] or 0) > 0 then
			Remotes.Notify:FireClient(admin, `{target.DisplayName} ya tenía {label}`)
			return
		end
		PlayerData.update(target, function(current)
			current.mounts[id] = 1
		end)
		done = `🎁 {target.DisplayName} ya tiene {label}`
		if target ~= admin then
			Remotes.Notify:FireClient(target, `🎁 ¡Te han regalado una montura: {label}!`)
		end
	else
		local where = Eggs.grant(target, id)
		if not where then
			return
		end
		done = `🎁 {label} para {target.DisplayName}: {EGG_PLACES[where]}`
		if target ~= admin then
			Remotes.Notify:FireClient(target, `🎁 ¡Te han regalado un {label}! Está {EGG_PLACES[where]}`)
		end
	end
	task.spawn(PlayerData.saveNow, target)
	print(`[Admin] {admin.Name} ({admin.UserId}) le ha dado {kind} {id} a {target.Name} ({target.UserId})`)
	Remotes.Notify:FireClient(admin, done)
end

-- Lo llaman los AdminService de cada place.
function Admin.start()
	Remotes.AdminGiveAll.OnServerEvent:Connect(onGiveAll)
	Remotes.AdminGive.OnServerEvent:Connect(onGive)
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
