--!strict
-- Órdenes del panel de pruebas en la Isla (solo Studio; en el juego publicado se ignoran).
-- Sirven para verificar cada entrega sin esperar días de partida (docs/VERIFICACION.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Beacon = require(ReplicatedStorage.Shared.Beacon)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Sounds = require(ReplicatedStorage.Shared.Data.Sounds)
local Survival = require(ReplicatedStorage.Shared.Survival)
local BossService = require(script.Parent.BossService)
local EggService = require(script.Parent.EggService)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local MonkeyService = require(script.Parent.MonkeyService)
local RoleService = require(script.Parent.RoleService)
local SiegeService = require(script.Parent.SiegeService)
local SupplyService = require(script.Parent.SupplyService)
local WeatherService = require(script.Parent.WeatherService)
local Hazards = require(script.Parent.Parent.Combat.Hazards)

local DebugService = {}

local rng = Random.new()
local nextBoss = 1

local COMMANDS: { [string]: (player: Player) -> () } = {
	Materials = function(player)
		for itemId in Items do
			InventoryService.add(player, itemId, 50)
		end
	end,
	NextRole = function(player)
		RoleService.debugNextRole(player)
	end,
	Abilities = function(player)
		for slot = 1, 4 do
			player:SetAttribute(`AbilityReadyAt{slot}`, nil)
		end
	end,
	Heal = function(player)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
		player:SetAttribute(Survival.HUNGER, Survival.MAX)
		player:SetAttribute(Survival.THIRST, Survival.MAX)
		player:SetAttribute(Survival.FEVER, 0)
	end,
	Hungry = function(player)
		player:SetAttribute(Survival.HUNGER, 10)
		player:SetAttribute(Survival.THIRST, 10)
	end,
	Fever = function(player)
		player:SetAttribute(Survival.FEVER, 90)
	end,
	Boss = function()
		local rotation = Config.Match.BossRotation
		BossService.spawn(rotation[(nextBoss - 1) % #rotation + 1])
		nextBoss += 1
	end,
	BossHurt = function()
		for _, model in Workspace:GetChildren() do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if model:GetAttribute("Boss") ~= nil and humanoid then
				humanoid.Health = humanoid.MaxHealth * 0.3
			end
		end
	end,
	-- Un mono de categoría 2 que va a por ti: para ver sus críticos (números rojos más grandes).
	Mandrill = function(player)
		local character = player.Character
		if character then
			MonkeyService.spawnAmbush("Mandril", (character:GetPivot() * CFrame.new(0, 0, -20)).Position, 1, player)
		end
	end,
	-- Todo golpe y curación es crítico (Shared/Crit), para ver los números grandes al momento.
	AlwaysCrit = function(player)
		local enabled = Workspace:GetAttribute("DebugAlwaysCrit") ~= true
		Workspace:SetAttribute("DebugAlwaysCrit", enabled)
		Remotes.Notify:FireClient(player, if enabled then "🎯 Críticos al 100 %" else "🎯 Críticos normales")
	end,
	Egg = function()
		EggService.spawnEgg()
	end,
	HatchNow = function(player)
		if not EggService.hatchNow() then
			Remotes.Notify:FireClient(player, "Primero lleva un huevo al nido")
		end
	end,
	Crate = function()
		SupplyService.spawnCrate()
	end,
	Pet = function(player)
		local petId = PetRoll.roll(rng)
		player:SetAttribute("ActivePet", petId)
		RoleService.refreshPerks(player)
		Remotes.Notify:FireClient(player, `🐾 Mascota de prueba: {Pets[petId].icon} {Pets[petId].name}`)
	end,
	Rain = function()
		ReplicatedStorage:SetAttribute("Weather", "Rain")
	end,
	Storm = function()
		ReplicatedStorage:SetAttribute("Weather", "Storm")
	end,
	Clear = function()
		ReplicatedStorage:SetAttribute("Weather", "Clear")
	end,
	Eruption = function()
		WeatherService.erupt()
	end,
	Lightning = function(player)
		local character = player.Character
		if character then
			Hazards.lightning(
				(character:GetPivot() * CFrame.new(0, 0, -14)).Position,
				Config.Weather.LightningDamage,
				5,
				1.5
			)
			ReplicatedStorage:SetAttribute("LightningAt", Workspace:GetServerTimeNow() + 1.5)
		end
	end,
	LavaBomb = function(player)
		local character = player.Character
		if character then
			local pivot = character:GetPivot()
			local origin = (pivot * CFrame.new(0, 40, 60)).Position
			for i = 1, 3 do
				Hazards.lavaBomb(
					(pivot * CFrame.new((i - 2) * 10, 0, -16)).Position,
					Config.Weather.LavaBombDamage,
					7,
					1.4 + i * 0.4,
					origin
				)
			end
		end
	end,
	GreatTroop = function()
		SiegeService.debugGreatTroop()
	end,
	Sounds = function(player)
		local keys = {}
		for key in Sounds.Effects do
			table.insert(keys, key)
		end
		table.sort(keys)
		task.spawn(function()
			for _, key in keys do
				local character = player.Character
				if not character then
					return
				end
				Remotes.Notify:FireClient(player, `🔊 {key}`)
				Sfx.play(key, character:GetPivot().Position)
				task.wait(1.6)
			end
		end)
	end,
	Beacon = function(player)
		for bossId in Bosses do
			Beacon.add(bossId)
		end
		ReplicatedStorage:SetAttribute("DebugBeaconUnlocked", true)
		Remotes.Notify:FireClient(player, "📡 Tienes las 4 piezas y la baliza se puede encender ya (de día)")
	end,
	Defeat = function()
		MatchService.endMatch("Defeat")
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
	print("[DebugService] Panel de pruebas activo (solo Studio).")
end

return DebugService
