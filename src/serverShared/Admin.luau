--!strict
-- Administradores (Config.Admins y el dueño del juego), en los tres places y también en el juego
-- publicado: pueden darle a un jugador de su servidor todo lo que se puede tener (grantAll): todos los
-- cosméticos (emotes incluidos), todas las mascotas y todas las monturas. No toca el Ámbar, las
-- mejoras ni los talentos. El cliente enseña el panel (Shared/UI/AdminPanel) si el Player lleva el
-- atributo "IsAdmin", pero el servidor lo vuelve a comprobar en cada petición.
-- Lo cambia con PlayerData.update, así que respeta el bloqueo de sesión del perfil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CosmeticsServer = require(script.Parent.CosmeticsServer)
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

-- Lo llaman los AdminService de cada place.
function Admin.start()
	Remotes.AdminGiveAll.OnServerEvent:Connect(onGiveAll)
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
