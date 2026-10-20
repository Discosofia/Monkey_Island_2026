--!strict
-- Rol de cada jugador en la arena. Se elige en la base antes de la partida (Remotes.ArenaPickRole) y
-- se recuerda para la próxima vez (perfil "arena.role"; la primera vez, el rol elegido en el Lobby).
-- Aquí todos juegan con los números base de su rol más su equipamiento de la arena (Data/ArenaGear,
-- ServerShared/ArenaShop): no cuentan talentos, mejoras de la tienda ni la mascota, que solo acompaña.
-- Publica "Role" y las ventajas "Perk_*" (Shared/Progression.perk), como RoleService en la Isla; las
-- armas del rol las da CombatService al cambiar "Role". El equipo se compra y se cambia antes de la
-- partida (en la ventana de la base).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Arena = require(ReplicatedStorage.Shared.Arena)
local ArenaGear = require(ReplicatedStorage.Shared.Data.ArenaGear)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local ArenaShop = require(ServerScriptService.ServerShared.ArenaShop)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

local BASE_HEALTH = 100
local ABILITY_SLOTS = 5 -- los huecos de Data/Roles (4 activas y la definitiva)

local ArenaRoleService = {}

local function rolesInOrder(): { string }
	local ids = {}
	for roleId in Roles do
		table.insert(ids, roleId)
	end
	table.sort(ids, function(a, b)
		return Roles[a].order < Roles[b].order
	end)
	return ids
end

local function applyHealth(player: Player, refill: boolean)
	local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.MaxHealth = BASE_HEALTH + Progression.perk(player, "MaxHealth")
		if refill then
			humanoid.Health = humanoid.MaxHealth
		end
	end
end

-- Ventajas de "roleId" con el equipo que "player" lleva puesto para ese rol.
local function publishPerks(player: Player, roleId: string)
	local gear = ArenaGear.perksOf(roleId, ArenaShop.loadout(player, roleId))
	for name, value in Progression.computePerks(roleId, {}, {}, nil, gear) do
		player:SetAttribute(`Perk_{name}`, value)
	end
end

-- Pone "roleId" a "player": ventajas del rol con su equipo, vida y habilidades listas.
local function setRole(player: Player, roleId: string)
	publishPerks(player, roleId)
	player:SetAttribute("Role", roleId)
	for slot = 1, ABILITY_SLOTS do
		player:SetAttribute(`AbilityReadyAt{slot}`, nil)
	end
	applyHealth(player, true)
end

-- Si su rol no cabe en su equipo (MaxSameRole), le pone el primero que quepa.
function ArenaRoleService.ensureAllowed(player: Player)
	local teamId = Arena.teamOf(player)
	local current = player:GetAttribute("Role")
	if not teamId or (typeof(current) == "string" and Arena.roleAllowed(player, teamId, current)) then
		return
	end
	for _, roleId in rolesInOrder() do
		if Arena.roleAllowed(player, teamId, roleId) then
			setRole(player, roleId)
			local role = Roles[roleId]
			Remotes.Notify:FireClient(
				player,
				`{role.icon} Tu rol ya está completo en el equipo: juegas como {role.name}`
			)
			return
		end
	end
end

local function onPickRole(player: Player, roleId: any)
	local phase = Arena.phase()
	if phase ~= "Waiting" and phase ~= "Countdown" then
		return
	end
	if typeof(roleId) ~= "string" or not Roles[roleId] or player:GetAttribute("Role") == roleId then
		return
	end
	local teamId = Arena.teamOf(player)
	if teamId and not Arena.roleAllowed(player, teamId, roleId) then
		Remotes.Notify:FireClient(player, `Ya hay demasiados {Roles[roleId].name} en tu equipo`)
		return
	end
	setRole(player, roleId)
	PlayerData.update(player, function(profile)
		profile.arena.role = roleId
	end)
end

local function onPlayer(player: Player)
	local profile = PlayerData.waitFor(player)
	if not player.Parent then
		return
	end
	local saved = if profile then profile.arena.role or profile.selectedRole else nil
	setRole(player, Progression.validRole(saved))
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applyHealth(player, true)
	end)
end

function ArenaRoleService:Start()
	Remotes.ArenaPickRole.OnServerEvent:Connect(onPickRole)
	-- Comprar o cambiar el equipo, solo antes de la partida; se nota al momento (vida incluida).
	ArenaShop.start(function()
		local phase = Arena.phase()
		return phase == "Waiting" or phase == "Countdown"
	end, function(player)
		local roleId = player:GetAttribute("Role")
		if typeof(roleId) == "string" and Roles[roleId] then
			publishPerks(player, roleId)
			applyHealth(player, true)
		end
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return ArenaRoleService
