--!strict
-- Rol y ventajas de cada jugador en la Isla (Fase 3).
--   - Lee el perfil guardado (PlayerData): rol elegido en el Lobby, talentos y mejoras de la tienda.
--   - Publica "Role" y las ventajas como atributos "Perk_<nombre>" (Shared/Progression.perk).
--   - Aplica las que son de una vez: vida máxima extra y el kit de náufrago.
--   - Marca "TutorialPending" si el jugador aún no ha hecho el tutorial (TutorialController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Analytics = require(ServerScriptService.ServerShared.Analytics)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local InventoryService = require(script.Parent.InventoryService)

local BASE_HEALTH = 100
local KIT_ITEMS = { "Wood", "Stone", "Fiber" }
local KIT_AMOUNT = 5

local RoleService = {}

local function applyHealth(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = BASE_HEALTH + Progression.perk(player, "MaxHealth")
	humanoid.Health = humanoid.MaxHealth
end

-- Calcula y publica las ventajas (rol, talentos, mejoras y mascota activa) como atributos "Perk_*".
local function publishPerks(player: Player): { [string]: number }
	local profile = PlayerData.get(player)
	local roleId = Progression.validRole(if profile then profile.selectedRole else nil)
	local petId = player:GetAttribute("ActivePet")
	local perks = Progression.computePerks(
		roleId,
		if profile then profile.talents else {},
		if profile then profile.upgrades else {},
		if typeof(petId) == "string" then petId else nil
	)
	for name, value in perks do
		player:SetAttribute(`Perk_{name}`, value)
	end
	player:SetAttribute("Role", roleId)
	return perks
end

-- Vuelve a calcular las ventajas a mitad de partida (p. ej. al nacer una mascota del huevo) y
-- ajusta la vida máxima sin rellenar la vida actual.
function RoleService.refreshPerks(player: Player)
	publishPerks(player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.MaxHealth = BASE_HEALTH + Progression.perk(player, "MaxHealth")
	end
end

local function onPlayer(player: Player)
	local profile = PlayerData.waitFor(player)
	if not player.Parent then
		return
	end
	local perks = publishPerks(player)
	local roleId = Progression.validRole(if profile then profile.selectedRole else nil)

	local kit = math.floor(perks.StartKit)
	if kit > 0 then
		for _, itemId in KIT_ITEMS do
			InventoryService.add(player, itemId, kit * KIT_AMOUNT)
		end
	end
	if profile and not profile.tutorialDone then
		player:SetAttribute("TutorialPending", true)
	end

	player.CharacterAdded:Connect(function(character)
		applyHealth(player, character)
	end)
	if player.Character then
		applyHealth(player, player.Character)
	end
	local role = Roles[roleId]
	Remotes.Notify:FireClient(player, `{role.icon} Juegas como {role.name}: {role.passive}`)
end

function RoleService:Start()
	Remotes.TutorialStep.OnServerEvent:Connect(function(player: Player, step: any)
		if typeof(step) == "number" and step >= 1 and step <= 10 then
			Analytics.tutorialStep(player, math.floor(step), `Paso {math.floor(step)}`)
		end
	end)
	Remotes.TutorialDone.OnServerEvent:Connect(function(player: Player)
		Analytics.tutorialStep(player, 99, "Completado")
		player:SetAttribute("TutorialPending", nil)
		PlayerData.update(player, function(profile)
			profile.tutorialDone = true
		end)
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return RoleService
