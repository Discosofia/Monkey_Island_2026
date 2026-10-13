--!strict
-- Progresión en el Lobby (Fase 3): elegir rol, aprender talentos y comprar mejoras con Ámbar.
-- Todo se valida contra el perfil guardado (PlayerData) y se publica de vuelta al cliente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Talents = require(ReplicatedStorage.Shared.Data.Talents)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local RequestCooldown = require(ServerScriptService.ServerShared.RequestCooldown)

local ProgressionService = {}

local canRequest = RequestCooldown.new(0.3)

local function onSelectRole(player: Player, roleId: any)
	if typeof(roleId) ~= "string" or not Roles[roleId] or not canRequest(player) then
		return
	end
	PlayerData.update(player, function(profile)
		profile.selectedRole = roleId
	end)
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
	}
	if rank >= talent.maxRank then
		Remotes.Notify:FireClient(player, `{talent.name} ya está al máximo`)
		return
	end
	if Progression.freePoints(roleId, data) <= 0 then
		Remotes.Notify:FireClient(player, "No tienes puntos de talento: juega con este rol para subir de nivel")
		return
	end
	PlayerData.update(player, function(current)
		current.talents[key] = rank + 1
	end)
	Remotes.Notify:FireClient(player, `Aprendido: {talent.name} (rango {rank + 1})`)
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
		Remotes.Notify:FireClient(player, `{upgrade.name} ya está al máximo`)
		return
	end
	if profile.amber < cost then
		Remotes.Notify:FireClient(player, `Te faltan {cost - profile.amber} de Ámbar`)
		return
	end
	PlayerData.update(player, function(current)
		current.amber -= cost
		current.upgrades[upgradeId] = rank + 1
	end)
	PlayerData.saveNow(player)
	Remotes.Notify:FireClient(player, `Comprado: {upgrade.icon} {upgrade.name} (rango {rank + 1})`)
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
end

function ProgressionService:Start()
	Remotes.SelectPet.OnServerEvent:Connect(onSelectPet)
	Remotes.SelectRole.OnServerEvent:Connect(onSelectRole)
	Remotes.LearnTalent.OnServerEvent:Connect(onLearnTalent)
	Remotes.BuyUpgrade.OnServerEvent:Connect(onBuyUpgrade)
end

return ProgressionService
