--!strict
-- Tirada de mascota al eclosionar un huevo (Fase 5): primero la rareza (Config.Pets.RarityWeights) y
-- luego una mascota al azar de esa rareza. También da la siguiente mascota para recorrerlas todas
-- desde el panel de pruebas.

local Config = require(script.Parent.Config)
local Pets = require(script.Parent.Data.Pets)
local Rarities = require(script.Parent.Data.Rarities)

local PetRoll = {}

function PetRoll.roll(rng: Random): string
	local weights: { [string]: number } = Config.Pets.RarityWeights
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local pick = rng:NextNumber(0, total)
	local rarity = "Common"
	for name, weight in weights do
		pick -= weight
		if pick <= 0 then
			rarity = name
			break
		end
	end
	local candidates = {}
	for petId, pet in Pets do
		if pet.rarity == rarity then
			table.insert(candidates, petId)
		end
	end
	if #candidates == 0 then
		for petId in Pets do
			table.insert(candidates, petId)
		end
	end
	table.sort(candidates)
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Mascota que va después de "current" (de común a legendaria y, dentro de cada rareza, por id);
-- tras la última vuelve a la primera.
function PetRoll.after(current: string?): string
	local order = {}
	for petId in Pets do
		table.insert(order, petId)
	end
	table.sort(order, function(a, b)
		local rankA, rankB = Rarities[Pets[a].rarity].order, Rarities[Pets[b].rarity].order
		if rankA ~= rankB then
			return rankA < rankB
		end
		return a < b
	end)
	local index = if current then table.find(order, current) else nil
	return order[(index or 0) % #order + 1]
end

return PetRoll
