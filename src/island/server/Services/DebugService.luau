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
local Survival = require(ReplicatedStorage.Shared.Survival)
local BossService = require(script.Parent.BossService)
local EggService = require(script.Parent.EggService)
local InventoryService = require(script.Parent.InventoryService)
local MatchService = require(script.Parent.MatchService)
local SupplyService = require(script.Parent.SupplyService)
local WeatherService = require(script.Parent.WeatherService)

local DebugService = {}

local rng = Random.new()
local nextBoss = 1

local COMMANDS: { [string]: (player: Player) -> () } = {
	Materials = function(player)
		for itemId in Items do
			InventoryService.add(player, itemId, 50)
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
	Egg = function()
		EggService.spawnEgg()
	end,
	Crate = function()
		SupplyService.spawnCrate()
	end,
	Pet = function(player)
		local petId = PetRoll.roll(rng)
		player:SetAttribute("ActivePet", petId)
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
