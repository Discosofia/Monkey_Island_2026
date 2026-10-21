--!strict
-- Tótem guardián (Fase 9, G8; Data/Buildables "WarTotem", Config.Siege.Totem). A menos de su radio:
--   - Las piezas reciben menos daño (BuildingService.damageStructure) y, de noche, las que llevan un
--     rato sin recibir golpes se van reparando (aquí). Las derribadas (la baliza) esperan al amanecer.
--   - Los jugadores reciben menos daño: atributo "WardReduction" del Player, que lee
--     CombatService.mitigate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local BuildingService = require(script.Parent.BuildingService)

local WARD_ATTRIBUTE = "WardReduction"
local TICK_SECONDS = 0.5

local DefenseService = {}

local function updatePlayers()
	local reduction = Config.Siege.Totem.PlayerReduction
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local warded = character ~= nil and BuildingService.totemNear(character:GetPivot().Position) ~= nil
		player:SetAttribute(WARD_ATTRIBUTE, if warded then reduction else nil)
	end
end

local function repairPieces()
	local state = MatchState.read()
	if not (state and state.phase == "Night") then
		return
	end
	local settings = Config.Siege.Totem
	local now = os.clock()
	for _, model in BuildingService.getStructures():GetChildren() do
		local maxHealth = model:GetAttribute("MaxHealth")
		if
			model:IsA("Model")
			and typeof(maxHealth) == "number"
			and not BuildingService.isBroken(model)
			and now - BuildingService.lastHitAt(model) >= settings.QuietSeconds
			and BuildingService.totemNear(model:GetPivot().Position)
		then
			BuildingService.repair(model, maxHealth * settings.RepairPerSecond * TICK_SECONDS)
		end
	end
end

function DefenseService:Start()
	while true do
		task.wait(TICK_SECONDS)
		updatePlayers()
		repairPieces()
	end
end

return DefenseService
