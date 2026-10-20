--!strict
-- Rol del jugador en el Lobby para probar sus habilidades y armas antes de zarpar (el combate
-- compartido, ServerScriptService.Combat; sus reglas del Lobby están en LobbyCombatRules).
-- Publica "Role" y las ventajas "Perk_*" del rol elegido con los talentos, las mejoras y la mascota
-- que lleva, como RoleService en la Isla, así lo que se prueba aquí es lo que tendrá en la partida.
-- ProgressionService llama a refresh al elegir rol, aprender un talento, comprar una mejora o
-- cambiar de mascota. Las armas del rol las da CombatService al cambiar "Role".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Progression = require(ReplicatedStorage.Shared.Progression)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

local ABILITY_SLOTS = 5 -- los huecos de Data/Roles (4 activas y la definitiva)

local LobbyRoleService = {}

-- Vuelve a calcular las ventajas de "player" con su perfil guardado; si cambia de rol, sus
-- habilidades quedan listas.
function LobbyRoleService.refresh(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local roleId = Progression.validRole(profile.selectedRole)
	local petId = if profile.activePet ~= "" then profile.activePet else nil
	for name, value in Progression.computePerks(roleId, profile.talents, profile.upgrades, petId) do
		player:SetAttribute(`Perk_{name}`, value)
	end
	if player:GetAttribute("Role") ~= roleId then
		player:SetAttribute("Role", roleId)
		for slot = 1, ABILITY_SLOTS do
			player:SetAttribute(`AbilityReadyAt{slot}`, nil)
		end
	end
end

local function onPlayer(player: Player)
	PlayerData.waitFor(player)
	if player.Parent then
		LobbyRoleService.refresh(player)
	end
end

function LobbyRoleService:Start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return LobbyRoleService
