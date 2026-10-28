--!strict
-- Panel de pruebas del Laboratorio (solo Studio; Shared/DebugCommands.Laboratorio).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

local LabDebugService = {}

local function humanoidOf(player: Player): Humanoid?
	return if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
end

local COMMANDS: { [string]: (player: Player) -> () } = {
	-- Cambia de facción (piratas / guardianes): las armas cambian de aspecto.
	Faction = function(player)
		local faction = if player:GetAttribute("LabFaction") == "Pirates" then "Guardians" else "Pirates"
		player:SetAttribute("LabFaction", faction)
		WeaponTools.reskin(player)
	end,
	Heal = function(player)
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end,
	-- Para ver la vida volver sola (Config.Lab.RegenDelaySeconds).
	Hurt = function(player)
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.Health = 30
		end
	end,
	Amber = function(player)
		PlayerData.update(player, function(profile)
			profile.amber += 500
		end)
	end,
}

function LabDebugService:Start()
	if not RunService:IsStudio() then
		return
	end
	Remotes.DebugCommand.OnServerEvent:Connect(function(player: Player, command: any)
		local handler = if typeof(command) == "string" then COMMANDS[command] else nil
		if handler then
			handler(player)
		end
	end)
	print("[LabDebugService] Panel de pruebas activo (solo Studio).")
end

return LabDebugService
