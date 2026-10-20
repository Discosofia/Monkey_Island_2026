--!strict
-- Órdenes del panel de pruebas en el Lobby (solo Studio; en el juego publicado se ignoran).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)
local Eggs = require(ServerScriptService.ServerShared.Eggs)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Retention = require(ServerScriptService.ServerShared.Retention)
local Supplies = require(ServerScriptService.ServerShared.Supplies)

local DebugService = {}

-- Rareza del próximo huevo de prueba ("GrantEgg").
local DEBUG_EGG_RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local debugEggIndex = 0

local COMMANDS: { [string]: (player: Player) -> () } = {
	Guide = function(player)
		PlayerData.update(player, function(profile)
			profile.lobbyGuideDone = false
		end)
	end,
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
	-- Un huevo como los de la Isla, cada vez de la rareza siguiente (al nido, la mochila o pendiente).
	GrantEgg = function(player)
		debugEggIndex = debugEggIndex % #DEBUG_EGG_RARITIES + 1
		local rarity = DEBUG_EGG_RARITIES[debugEggIndex]
		Remotes.Notify:FireClient(player, `🥚 Huevo de prueba ({rarity}): {Eggs.grant(player, rarity) or "?"}`)
	end,
	EggReady = function(player)
		if not Eggs.makeReady(player) then
			Remotes.Notify:FireClient(player, "No hay huevo en el nido")
		end
	end,
	-- Provisiones como las del calendario: llegan al empezar la siguiente partida en la Isla.
	Supplies = function(player)
		Supplies.add(player, { Banana = 5, Bandage = 2, Antidote = 1 })
	end,
	-- Como si el último premio del calendario se hubiera cobrado ayer: hoy se puede cobrar otro.
	NextDay = function(player)
		Retention.debugNextDay(player)
		Remotes.Notify:FireClient(player, "📅 Día siguiente: ya puedes cobrar el premio del calendario")
	end,
	-- Da o quita el título que se gana al rescatarse, para ver cómo queda (no cuenta como victoria).
	SurvivorTitle = function(player)
		local has = CosmeticsServer.debugToggleEarned(player, "TitleSurvivor")
		Remotes.Notify:FireClient(
			player,
			if has then "🏝️ Título de prueba: lo tienes" else "🏝️ Título de prueba: quitado"
		)
	end,
	-- Adelanta una hora el reloj de los huevos de este servidor (Shared/EggIncubation.now).
	ClockHour = function(player)
		local shift = ReplicatedStorage:GetAttribute("DebugClockShift")
		local hours = (if typeof(shift) == "number" then shift else 0) / 3600 + 1
		ReplicatedStorage:SetAttribute("DebugClockShift", hours * 3600)
		Remotes.Notify:FireClient(player, `⏩ Reloj de los huevos: +{hours} h`)
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
