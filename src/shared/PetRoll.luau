--!strict
-- Tiradas de mascotas y huevos. El huevo saca su rareza al aparecer en la Isla (rollRarity, con
-- Config.Pets.RarityWeights) y, al eclosionar en el nido del Lobby, una mascota al azar de esa rareza
-- (rollPet). También da la siguiente mascota para recorrerlas todas desde el panel de pruebas.
-- Monturas (Fase 11): antes de la mascota, un huevo de una rareza que tenga monturas que aún no
-- tienes da una de ellas con Config.Mounts.EggChance (rollMount). La tirada de pioneros (T6) da una
-- de las tres con Config.Pioneer.Weights (rollPioneer). El nido de la parcela puede subir un grado la
-- rareza del huevo que se defiende en él (upgradeRarity, Fase 12).

local Config = require(script.Parent.Config)
local Mounts = require(script.Parent.Data.Mounts)
local Pets = require(script.Parent.Data.Pets)
local Rarities = require(script.Parent.Data.Rarities)

local PetRoll = {}

-- Rareza al azar según los pesos (por defecto los de un huevo de la selva).
function PetRoll.rollRarity(rng: Random, weights: { [string]: number }?): string
	local pool: { [string]: number } = weights or Config.Pets.RarityWeights
	-- En orden de rareza, para que la misma tirada dé siempre lo mismo.
	local names = {}
	local total = 0
	for name, weight in pool do
		table.insert(names, name)
		total += weight
	end
	table.sort(names, function(a, b)
		return Rarities[a].order < Rarities[b].order
	end)
	local pick = rng:NextNumber(0, total)
	for _, name in names do
		pick -= pool[name]
		if pick <= 0 then
			return name
		end
	end
	return names[#names] or "Common"
end

-- Nido de la parcela (Fase 12, P5): con probabilidad "chance", la rareza de un huevo defendido sube un
-- grado. Nunca a Mítico (ningún huevo normal lo es) ni más allá de Legendario. Devuelve la rareza final.
function PetRoll.upgradeRarity(rarity: string, chance: number, rng: Random): string
	local current = Rarities[rarity]
	if not current or chance <= 0 or rng:NextNumber() >= chance then
		return rarity
	end
	for name, data in Rarities do
		if data.order == current.order + 1 and name ~= "Mythic" then
			return name
		end
	end
	return rarity
end

-- Mascotas de una rareza, ordenadas por id (las que pueden salir de un huevo de esa rareza). Las que
-- tienen "origin" (las míticas) nunca salen de un huevo normal: se dan desde el panel de admin y
-- saldrán del huevo mítico.
function PetRoll.petsOfRarity(rarity: string): { string }
	local candidates = {}
	for petId, pet in Pets do
		if pet.rarity == rarity and not pet.origin then
			table.insert(candidates, petId)
		end
	end
	table.sort(candidates)
	return candidates
end

-- Monturas de una rareza, ordenadas por id (las que pueden salir de un huevo de esa rareza). Las míticas
-- (el Quetzalcóatl) salen de la tirada de pioneros (rollPioneer) y saldrán del huevo mítico, que aún no
-- existe: ningún huevo normal es Mítico.
function PetRoll.mountsOfRarity(rarity: string): { string }
	local candidates = {}
	for mountId, mount in Mounts do
		if mount.rarity == rarity then
			table.insert(candidates, mountId)
		end
	end
	table.sort(candidates)
	return candidates
end

-- Montura que sale de un huevo de "rarity" (nil si sale mascota): con Config.Mounts.EggChance, una
-- de las de su rareza que no tenga aún ("owned"). Si ya las tiene todas, mascota.
function PetRoll.rollMount(rarity: string, owned: { [string]: number }, rng: Random): string?
	local candidates = {}
	for _, mountId in PetRoll.mountsOfRarity(rarity) do
		if (owned[mountId] or 0) <= 0 then
			table.insert(candidates, mountId)
		end
	end
	if #candidates == 0 or rng:NextNumber() >= Config.Mounts.EggChance then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

-- Tirada de pioneros (T6): una montura con Config.Pioneer.Weights, tenga o no las que salen (una
-- repetida se cambia por Ámbar donde se entrega, ServerShared/Retention).
function PetRoll.rollPioneer(rng: Random): string
	local weights: { [string]: number } = Config.Pioneer.Weights
	-- Por id, para que la misma tirada dé siempre lo mismo.
	local ids = {}
	local total = 0
	for mountId, weight in weights do
		if Mounts[mountId] then
			table.insert(ids, mountId)
			total += weight
		end
	end
	table.sort(ids)
	local pick = rng:NextNumber(0, total)
	for _, mountId in ids do
		pick -= weights[mountId]
		if pick <= 0 then
			return mountId
		end
	end
	return ids[#ids]
end

-- Mascota al azar de una rareza (si no hay ninguna de esa rareza, de todas).
function PetRoll.rollPet(rarity: string, rng: Random): string
	local candidates = PetRoll.petsOfRarity(rarity)
	if #candidates == 0 then
		for petId, pet in Pets do
			if not pet.origin then
				table.insert(candidates, petId)
			end
		end
		table.sort(candidates)
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

function PetRoll.roll(rng: Random): string
	return PetRoll.rollPet(PetRoll.rollRarity(rng), rng)
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
