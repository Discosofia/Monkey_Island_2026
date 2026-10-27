--!strict
-- Huevos guardados de cada jugador (bucle de retención, octubre de 2026), en el Lobby y en la Isla.
-- Las cuentas están en Shared/EggIncubation; aquí se cambian dentro del perfil (PlayerData) y se
-- reparten los premios.
--   - grant: un huevo nuevo (de la defensa en la Isla o del calendario). Si el nido está vacío entra
--     directo en él; si no, a la mochila; si está llena, queda pendiente.
--   - placeInNest / discard: lo que el jugador decide en el nido del Lobby.
--   - hatch: abre el huevo del nido ya listo y da una mascota de su rareza (o una montura, Fase 11).
--   - addPlayTime / addFreeTime / makeReady: le quitan tiempo al huevo del nido.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Analytics = require(script.Parent.Analytics)
local PlayerData = require(script.Parent.PlayerData)

type EggData = EggIncubation.EggData
export type Source = "bag" | "pending"
export type GrantResult = "nest" | "bag" | "pending"

local Eggs = {}

local rng = Random.new()

local function now(): number
	return math.floor(EggIncubation.now())
end

-- Cambia los huevos del jugador dentro de su perfil. Devuelve lo que devuelva "change" (nil si el
-- perfil aún no ha cargado).
local function edit<T>(player: Player, change: (data: EggData, profile: PlayerData.Profile) -> T): T?
	local result: T? = nil
	PlayerData.update(player, function(profile)
		local data = EggIncubation.normalize(profile.eggs)
		result = change(data, profile)
		profile.eggs = data :: any
	end)
	return result
end

-- Los pendientes pasan a la mochila en cuanto hay sitio.
local function refill(data: EggData)
	while #data.bag < Config.Egg.BagSize and #data.pending > 0 do
		table.insert(data.bag, table.remove(data.pending, 1) :: EggIncubation.StoredEgg)
	end
end

local function listOf(data: EggData, source: Source): { EggIncubation.StoredEgg }
	return if source == "pending" then data.pending else data.bag
end

-- Huevos del jugador (copia normalizada), o nil si el perfil aún no ha cargado.
function Eggs.get(player: Player): EggData?
	local profile = PlayerData.get(player)
	return if profile then EggIncubation.normalize(profile.eggs) else nil
end

function Eggs.grant(player: Player, rarity: string): GrantResult?
	if not Rarities[rarity] then
		return nil
	end
	return edit(player, function(data): GrantResult
		if not data.nest then
			data.nest = EggIncubation.newNest(rarity, now())
			return "nest"
		elseif #data.bag < Config.Egg.BagSize then
			table.insert(data.bag, { rarity = rarity })
			return "bag"
		end
		table.insert(data.pending, { rarity = rarity })
		return "pending"
	end)
end

-- Pone en el nido (vacío) el huevo "index" de la mochila o de los pendientes.
function Eggs.placeInNest(player: Player, source: Source, index: number): boolean
	return edit(player, function(data): boolean
		local list = listOf(data, source)
		local egg = list[index]
		if data.nest or not egg then
			return false
		end
		table.remove(list, index)
		data.nest = EggIncubation.newNest(egg.rarity, now())
		refill(data)
		return true
	end) == true
end

-- Descarta el huevo "index" de la mochila o de los pendientes a cambio de Ámbar. Devuelve el Ámbar.
function Eggs.discard(player: Player, source: Source, index: number): number
	local amber = edit(player, function(data, profile): number
		local list = listOf(data, source)
		local egg = list[index]
		if not egg then
			return 0
		end
		table.remove(list, index)
		refill(data)
		local gained = EggIncubation.discardAmber(egg.rarity)
		profile.amber += gained
		Analytics.amber(player, "Source", gained, profile.amber, "EggDiscard")
		return gained
	end)
	return amber or 0
end

-- Abre el huevo del nido si ya está listo: una mascota de su rareza a la colección. Si es más rara
-- que la que lleva (o no lleva ninguna), pasa a acompañarle. Si ya la tenía, da en su lugar
-- Config.Egg.DuplicateAmber (se tiene una de cada). Puede salir, en cambio, una montura de su rareza
-- que aún no tenga (PetRoll.rollMount): se la pone si no llevaba ninguna. Devuelve lo que ha salido,
-- si se lo puso, si es una montura y el Ámbar de la repetida (0 si es nueva).
function Eggs.hatch(player: Player): (string?, boolean, boolean, number)
	local equipped = false
	local isMount = false
	local amber = 0
	local petId = edit(player, function(data, profile): string?
		local nest = data.nest
		if not (nest and EggIncubation.isReady(nest, now())) then
			return nil
		end
		local mountId = PetRoll.rollMount(nest.rarity, profile.mounts, rng)
		if mountId then
			data.nest = nil
			profile.mounts[mountId] = 1
			isMount = true
			if profile.activeMount == "" then
				profile.activeMount = mountId
				equipped = true
			end
			return mountId
		end
		local pet = PetRoll.rollPet(nest.rarity, rng)
		data.nest = nil
		if (profile.pets[pet] or 0) > 0 then
			amber = Config.Egg.DuplicateAmber[Pets[pet].rarity] or 0
			profile.amber += amber
			Analytics.amber(player, "Source", amber, profile.amber, "PetDuplicate")
			return pet
		end
		profile.pets[pet] = 1
		local current = Pets[profile.activePet]
		if not current or Rarities[current.rarity].order <= Rarities[Pets[pet].rarity].order then
			profile.activePet = pet
			equipped = true
		end
		return pet
	end)
	return petId, equipped, isMount, amber
end

-- Quita tiempo ganado jugando al huevo del nido (con tope). Devuelve los segundos quitados.
function Eggs.addPlayTime(player: Player, seconds: number): number
	return edit(player, function(data): number
		return if data.nest then EggIncubation.addPlayTime(data.nest, seconds, now()) else 0
	end) or 0
end

-- Quita tiempo sin tope (calendario). Devuelve los segundos quitados.
function Eggs.addFreeTime(player: Player, seconds: number): number
	return edit(player, function(data): number
		return if data.nest then EggIncubation.addFreeTime(data.nest, seconds, now()) else 0
	end) or 0
end

-- Resultado de la tirada del rescate: lo que salió en la ruleta y lo que de verdad se le quitó al
-- huevo (puede ser menos por el tope de lo ganado jugando, o lo que faltaba si salió la eclosión).
export type RescueOutcome = { rarity: string, hatch: boolean, rolledSeconds: number, appliedSeconds: number }

-- Tirada al ganar una partida (Config.Egg.RescueRoll). nil si no hay huevo en el nido o ya está listo.
function Eggs.rescueRoll(player: Player): RescueOutcome?
	local roll = EggIncubation.rollRescue(rng)
	return edit(player, function(data): RescueOutcome?
		local nest = data.nest
		local time = now()
		if not nest or EggIncubation.isReady(nest, time) then
			return nil
		end
		if roll.hatch then
			local left = EggIncubation.remaining(nest, time)
			nest.ready = true
			return { rarity = nest.rarity, hatch = true, rolledSeconds = 0, appliedSeconds = left }
		end
		local applied = EggIncubation.addPlayTime(nest, roll.seconds, time)
		return { rarity = nest.rarity, hatch = false, rolledSeconds = roll.seconds, appliedSeconds = applied }
	end)
end

-- Deja listo ya el huevo del nido (eclosión inmediata del rescate). false si no hay huevo.
function Eggs.makeReady(player: Player): boolean
	return edit(player, function(data): boolean
		local nest = data.nest
		if not nest then
			return false
		end
		nest.ready = true
		return true
	end) == true
end

return Eggs
