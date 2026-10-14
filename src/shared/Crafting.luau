--!strict
-- Consultas de crafteo que usan el cliente (para la pantalla) y el servidor (para validar).
-- Las herramientas y armaduras fabricadas se apuntan en el atributo "Crafted_<receta>" del Player.

local Inventory = require(script.Parent.Inventory)
local Recipes = require(script.Parent.Data.Recipes)

local PREFIX = "Crafted_"

local Crafting = {}

function Crafting.ownedAttribute(recipeId: string): string
	return PREFIX .. recipeId
end

-- Las herramientas y armaduras solo se fabrican una vez; los ítems (vendas) se acumulan.
function Crafting.isUnique(recipe: Recipes.Recipe): boolean
	return recipe.weaponId ~= nil or recipe.armorId ~= nil
end

function Crafting.isOwned(player: Player, recipeId: string): boolean
	return player:GetAttribute(PREFIX .. recipeId) == true
end

-- Las mejoras de un arma de rol solo son para ese rol (atributo "Role", lo publica RoleService).
function Crafting.isForRole(player: Player, recipe: Recipes.Recipe): boolean
	return recipe.role == nil or player:GetAttribute("Role") == recipe.role
end

function Crafting.canAfford(player: Player, recipe: Recipes.Recipe): boolean
	for _, cost in recipe.cost do
		if Inventory.count(player, cost.itemId) < cost.amount then
			return false
		end
	end
	return true
end

return Crafting
