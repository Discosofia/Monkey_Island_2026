--!strict
-- Progresión en el Lobby (Fase 3): elegir rol y su definitiva (T7), aprender talentos y comprar mejoras
-- con Ámbar.
-- Todo se valida contra el perfil guardado (PlayerData) y se publica de vuelta al cliente. Cada
-- cambio de rol, talento, mejora o mascota rehace las ventajas con las que se prueban las
-- habilidades en el Lobby (LobbyRoleService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoleAbilities = require(ReplicatedStorage.Shared.RoleAbilities)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Talents = require(ReplicatedStorage.Shared.Data.Talents)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)
local Analytics = require(ServerScriptService.ServerShared.Analytics)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)
local Retention = require(ServerScriptService.ServerShared.Retention)
local LobbyRoleService = require(script.Parent.LobbyRoleService)

local ProgressionService = {}

local canRequest = RequestCooldown.new(0.3)

local function onSelectRole(player: Player, roleId: any)
	if typeof(roleId) ~= "string" or not Roles[roleId] or not canRequest(player) then
		return
	end
	PlayerData.update(player, function(profile)
		profile.selectedRole = roleId
	end)
	-- La misión del día del rol cambia con él.
	Retention.refresh(player)
	LobbyRoleService.refresh(player)
end

local function onLearnTalent(player: Player, roleId: any, talentId: any)
	if typeof(roleId) ~= "string" or typeof(talentId) ~= "string" or not canRequest(player) then
		return
	end
	local talent = Talents[roleId] and Talents[roleId][talentId]
	local profile = PlayerData.get(player)
	if not (talent and profile) then
		return
	end
	local key = Progression.talentKey(roleId, talentId)
	local rank = profile.talents[key] or 0
	local data: Progression.ProgressData = {
		roleXp = profile.roleXp,
		talents = profile.talents,
		upgrades = profile.upgrades,
		matches = profile.matches,
		tutorialDone = profile.tutorialDone,
		bestiary = profile.bestiary,
		pets = profile.pets,
		mounts = profile.mounts,
		cosmetics = profile.cosmetics,
	}
	if rank >= talent.maxRank then
		Remotes.Notify:FireClient(player, "{name} ya está al máximo", { name = { talent.name } })
		return
	end
	if Progression.freePoints(roleId, data) <= 0 then
		Remotes.Notify:FireClient(player, "No tienes puntos de talento: juega con este rol para subir de nivel")
		return
	end
	PlayerData.update(player, function(current)
		current.talents[key] = rank + 1
	end)
	LobbyRoleService.refresh(player)
	Remotes.Notify:FireClient(player, "Aprendido: {name} (rango {rank})", { name = { talent.name }, rank = rank + 1 })
end

-- La definitiva que lleva con el rol "roleId" (T7): la del hueco 4 o una de sus "altUltimates".
local function onSelectUltimate(player: Player, roleId: any, abilityId: any)
	if typeof(roleId) ~= "string" or typeof(abilityId) ~= "string" or not canRequest(player) then
		return
	end
	local ability = RoleAbilities.findUltimate(roleId, abilityId)
	if not ability then
		return
	end
	PlayerData.update(player, function(profile)
		profile.ultimates[roleId] = abilityId
	end)
	LobbyRoleService.refresh(player, true)
	Remotes.Notify:FireClient(
		player,
		"Definitiva de {role}: {ability}",
		{ role = { Roles[roleId].name }, ability = { ability.name } }
	)
end

local function onBuyUpgrade(player: Player, upgradeId: any)
	if typeof(upgradeId) ~= "string" or not canRequest(player) then
		return
	end
	local upgrade = Upgrades[upgradeId]
	local profile = PlayerData.get(player)
	if not (upgrade and profile) then
		return
	end
	local rank = profile.upgrades[upgradeId] or 0
	local cost = upgrade.costs[rank + 1]
	if not cost then
		Remotes.Notify:FireClient(player, "{name} ya está al máximo", { name = { upgrade.name } })
		return
	end
	if profile.amber < cost then
		Remotes.Notify:FireClient(player, "Te faltan {n} de Ámbar", { n = cost - profile.amber })
		return
	end
	PlayerData.update(player, function(current)
		current.amber -= cost
		current.upgrades[upgradeId] = rank + 1
	end)
	LobbyRoleService.refresh(player)
	PlayerData.saveNow(player)
	Analytics.amber(player, "Sink", cost, profile.amber, upgradeId)
	Remotes.Notify:FireClient(
		player,
		"Comprado: {icon} {name} (rango {rank})",
		{ icon = upgrade.icon, name = { upgrade.name }, rank = rank + 1 }
	)
end

local function onSelectPet(player: Player, petId: any)
	if typeof(petId) ~= "string" or not canRequest(player) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if petId ~= "" and (not Pets[petId] or (profile.pets[petId] or 0) <= 0) then
		return
	end
	PlayerData.update(player, function(current)
		current.activePet = petId
	end)
	LobbyRoleService.refresh(player)
end

local function onSelectMount(player: Player, mountId: any)
	if typeof(mountId) ~= "string" or not canRequest(player) then
		return
	end
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	if mountId ~= "" and (not Mounts[mountId] or (profile.mounts[mountId] or 0) <= 0) then
		return
	end
	PlayerData.update(player, function(current)
		current.activeMount = mountId
	end)
end

function ProgressionService:Start()
	Remotes.SelectPet.OnServerEvent:Connect(onSelectPet)
	Remotes.SelectMount.OnServerEvent:Connect(onSelectMount)
	Remotes.SelectRole.OnServerEvent:Connect(onSelectRole)
	Remotes.LearnTalent.OnServerEvent:Connect(onLearnTalent)
	Remotes.SelectUltimate.OnServerEvent:Connect(onSelectUltimate)
	Remotes.BuyUpgrade.OnServerEvent:Connect(onBuyUpgrade)
end

return ProgressionService
