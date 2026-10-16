--!strict
-- Órdenes del panel de pruebas en el Lobby (solo Studio; en el juego publicado se ignoran).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

local DebugService = {}

local COMMANDS: { [string]: (player: Player) -> () } = {
	Amber = function(player)
		PlayerData.update(player, function(profile)
			profile.amber += 500
		end)
	end,
	RoleXp = function(player)
		PlayerData.update(player, function(profile)
			local role = Progression.validRole(profile.selectedRole)
			profile.roleXp[role] = (profile.roleXp[role] or 0) + 300
		end)
	end,
	-- Pasa a la siguiente mascota y la lleva puesta (se la da si no la tenía).
	Pet = function(player)
		local profile = PlayerData.get(player)
		if not profile then
			return
		end
		local petId = PetRoll.after(if profile.activePet ~= "" then profile.activePet else nil)
		PlayerData.update(player, function(current)
			if (current.pets[petId] or 0) <= 0 then
				current.pets[petId] = 1
			end
			current.activePet = petId
		end)
		Remotes.Notify:FireClient(player, `🐾 Mascota de prueba: {Pets[petId].icon} {Pets[petId].name}`)
	end,
}

function DebugService:Start()
	if not RunService:IsStudio() then
		return
	end
	Remotes.DebugCommand.OnServerEvent:Connect(function(player: Player, command: any)
		local handler = if typeof(command) == "string" then COMMANDS[command] else nil
		if handler then
			handler(player)
		end
	end)
end

return DebugService
