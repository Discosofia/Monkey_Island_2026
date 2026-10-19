--!strict
-- Consultas de crafteo que usan el cliente (para la pantalla) y el servidor (para validar).
-- Las herramientas y armaduras fabricadas se apuntan en el atributo "Crafted_<receta>" del Player.
-- Las mejoras no se saltan: para fabricar una (receta con "upgrades") hace falta tener la anterior,
-- de serie (herramientas comunes y armas del rol) o fabricada.

local Armor = require(script.Parent.Data.Armor)
local Config = require(script.Parent.Config)
local Inventory = require(script.Parent.Inventory)
local Recipes = require(script.Parent.Data.Recipes)
local Roles = require(script.Parent.Data.Roles)
local Weapons = require(script.Parent.Data.Weapons)

local PREFIX = "Crafted_"

local Crafting = {}

-- Receta que fabrica cada arma o armadura, para seguir la cadena de mejoras.
Crafting.recipeOfGear = {} :: { [string]: string }
for recipeId, recipe in Recipes do
	local gearId = recipe.weaponId or recipe.armorId
	if gearId then
		Crafting.recipeOfGear[gearId] = recipeId
	end
end

function Crafting.ownedAttribute(recipeId: string): string
	return PREFIX .. recipeId
end

-- Las herramientas, las armaduras y la antorcha solo se fabrican una vez; los ítems (vendas) se
-- acumulan.
function Crafting.isUnique(recipe: Recipes.Recipe): boolean
	return recipe.weaponId ~= nil or recipe.armorId ~= nil or recipe.offhand ~= nil
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

-- Equipo con el que aparece el jugador: las herramientas comunes y las armas de su rol.
local function isStarterGear(player: Player, gearId: string): boolean
	if table.find(Config.Combat.StarterTools, gearId) then
		return true
	end
	local roleId = player:GetAttribute("Role")
	local role = if typeof(roleId) == "string" then Roles[roleId] else nil
	return role ~= nil and table.find(role.weapons, gearId) ~= nil
end

local function gearName(gearId: string): string
	local weapon = Weapons[gearId]
	local armor = Armor[gearId]
	return if weapon then weapon.name elseif armor then armor.name else gearId
end

-- Lo que le falta para fabricar una mejora: el nombre del equipo anterior de la cadena (el hacha de
-- piedra para la de hueso), o nil si la receta no es una mejora o ya lo tiene, de serie o fabricado.
function Crafting.missingPrerequisite(player: Player, recipe: Recipes.Recipe): string?
	local gearId = recipe.upgrades
	if not gearId or isStarterGear(player, gearId) then
		return nil
	end
	local previous = Crafting.recipeOfGear[gearId]
	if previous and Crafting.isOwned(player, previous) then
		return nil
	end
	return gearName(gearId)
end

-- true si este jugador nunca podrá fabricar la mejora: la cadena empieza en un equipo que no tiene
-- de serie y que no se fabrica (el machete afilado para el guerrero, que no tiene machete; la honda
-- de liana para quien no es guerrero). La pantalla de fabricación no las enseña.
function Crafting.isUnreachable(player: Player, recipe: Recipes.Recipe): boolean
	local gearId = recipe.upgrades
	while gearId do
		if isStarterGear(player, gearId) then
			return false
		end
		local previous = Crafting.recipeOfGear[gearId]
		if not previous then
			return true
		end
		gearId = Recipes[previous].upgrades
	end
	return false
end

return Crafting
