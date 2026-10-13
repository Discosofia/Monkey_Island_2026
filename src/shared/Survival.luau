--!strict
-- Consultas de supervivencia que usan el cliente (HUD, botones) y el servidor (SurvivalService):
-- hambre y sed (atributos del Player), la mejor comida que lleva y si hay agua cerca.

local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local Inventory = require(script.Parent.Inventory)
local Items = require(script.Parent.Data.Items)

local Survival = {}

Survival.MAX = 100
Survival.HUNGER = "Hunger"
Survival.THIRST = "Thirst"

-- Valor actual de "Hunger" o "Thirst". Si aún no existe (al entrar), cuenta como lleno.
function Survival.get(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else Survival.MAX
end

-- La comida que más aprovecha el jugador ahora (lo que recupera sin pasarse de lleno), o nil si no
-- lleva ninguna. Así, con sed, "Comer" elige un coco antes que carne.
function Survival.bestFood(player: Player): string?
	local missingHunger = Survival.MAX - Survival.get(player, Survival.HUNGER)
	local missingThirst = Survival.MAX - Survival.get(player, Survival.THIRST)
	local bestId: string? = nil
	local bestScore = -1
	for itemId, item in Items do
		local food = item.food
		if food and Inventory.count(player, itemId) > 0 then
			local score = math.min(food.hunger, missingHunger) + math.min(food.thirst, missingThirst)
			if score > bestScore then
				bestId = itemId
				bestScore = score
			end
		end
	end
	return bestId
end

-- true si hay agua del terreno (río, mar, lagos) a menos de Config.Survival.DrinkReach de los pies.
function Survival.isNearWater(rootPosition: Vector3): boolean
	local reach = Config.Survival.DrinkReach
	local feet = rootPosition - Vector3.new(0, 3, 0)
	local region = Region3.new(feet - Vector3.new(reach, reach, reach), feet + Vector3.new(reach, 2, reach))
	local materials, occupancies = Workspace.Terrain:ReadVoxels(region:ExpandToGrid(4), 4)
	local size = materials.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				if materials[x][y][z] == Enum.Material.Water and occupancies[x][y][z] > 0 then
					return true
				end
			end
		end
	end
	return false
end

return Survival
