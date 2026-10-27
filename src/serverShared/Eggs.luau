--!strict
-- Huevos guardados de cada jugador (bucle de retención, octubre de 2026), en el Lobby y en la Isla.
-- Las cuentas están en Shared/EggIncubation; aquí se cambian dentro del perfil (PlayerData) y se
-- reparten los premios.
--   - grant: un huevo nuevo (de la defensa en la Isla o del calendario). Si el nido tiene un hueco libre
--     entra directo en él; si no, a la mochila; si está llena, queda pendiente.
--   - placeInNest / discard: lo que el jugador decide en el nido del Lobby.
--   - hatch: abre el huevo de un hueco del nido ya listo y da una mascota de su rareza (o una montura,
--     Fase 11).
--   - addPlayTime / addFreeTime / rescueRoll / makeReady: le quitan tiempo al huevo activo del nido (el
--     primero que no está listo, EggIncubation.active).
-- La incubadora de la parcela (Fase 12, P5; Shared/Plot.incubator) da el segundo hueco ("nest2") y acorta
-- los huevos: los nuevos nacen con su factor y, al mejorarla, speedUp acorta los que ya están.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Plot = require(ReplicatedStorage.Shared.Plot)
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

-- Pone un huevo nuevo en el primer hueco libre del nido (con el factor de la incubadora). false si no
-- hay ninguno libre.
local function putInNest(data: EggData, profile: PlayerData.Profile, rarity: string): boolean
	local slots, factor = Plot.incubator(Plot.normalize(profile.plot))
	local slot = EggIncubation.freeSlot(data, slots)
	if not slot then
		return false
	end
	EggIncubation.setSlot(data, slot, EggIncubation.newNest(rarity, now(), factor))
	return true
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
	return edit(player, function(data, profile): GrantResult
		if putInNest(data, profile, rarity) then
			return "nest"
		elseif #data.bag < Config.Egg.BagSize then
			table.insert(data.bag, { rarity = rarity })
			return "bag"
		end
		table.insert(data.pending, { rarity = rarity })
		return "pending"
	end)
end

-- Pone en un hueco libre del nido el huevo "index" de la mochila o de los pendientes.
function Eggs.placeInNest(player: Player, source: Source, index: number): boolean
	return edit(player, function(data, profile): boolean
		local list = listOf(data, source)
		local egg = list[index]
		if not egg or not putInNest(data, profile, egg.rarity) then
			return false
		end
		table.remove(list, index)
		refill(data)
		return true
	end) == true
end

-- Al mejorar la incubadora de "profile" (dentro de su PlayerData.update): acorta lo que les falta a los
-- huevos del nido según el nuevo factor.
function Eggs.speedUp(profile: PlayerData.Profile, fromFactor: number, toFactor: number)
	local data = EggIncubation.normalize(profile.eggs)
	for slot = 1, #EggIncubation.NEST_KEYS do
		local nest = EggIncubation.inSlot(data, slot)
		if nest then
			EggIncubation.speedUp(nest, fromFactor, toFactor, now())
		end
	end
	profile.eggs = data :: any
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

-- Abre el huevo del hueco "slot" del nido si ya está listo: una mascota de su rareza a la colección. Si es más rara
-- que la que lleva (o no lleva ninguna), pasa a acompañarle. Si ya la tenía, da en su lugar
-- Config.Egg.DuplicateAmber (se tiene una de cada). Puede salir, en cambio, una montura de su rareza
-- que aún no tenga (PetRoll.rollMount): se la pone si no llevaba ninguna. Devuelve lo que ha salido,
-- si se lo puso, si es una montura y el Ámbar de la repetida (0 si es nueva).
function Eggs.hatch(player: Player, slot: number): (string?, boolean, boolean, number)
	local equipped = false
	local isMount = false
	local amber = 0
	local petId = edit(player, function(data, profile): string?
		local nest = EggIncubation.inSlot(data, slot)
		if not (nest and EggIncubation.isReady(nest, now())) then
			return nil
		end
		local mountId = PetRoll.rollMount(nest.rarity, profile.mounts, rng)
		if mountId then
			EggIncubation.setSlot(data, slot, nil)
			profile.mounts[mountId] = 1
			isMount = true
			if profile.activeMount == "" then
				profile.activeMount = mountId
				equipped = true
			end
			return mountId
		end
		local pet = PetRoll.rollPet(nest.rarity, rng)
		EggIncubation.setSlot(data, slot, nil)
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

-- Quita tiempo ganado jugando al huevo activo del nido (con tope). Devuelve los segundos quitados.
function Eggs.addPlayTime(player: Player, seconds: number): number
	return edit(player, function(data): number
		local nest = EggIncubation.active(data, now())
		return if nest then EggIncubation.addPlayTime(nest, seconds, now()) else 0
	end) or 0
end

-- Quita tiempo sin tope (calendario) al huevo activo. Devuelve los segundos quitados.
function Eggs.addFreeTime(player: Player, seconds: number): number
	return edit(player, function(data): number
		local nest = EggIncubation.active(data, now())
		return if nest then EggIncubation.addFreeTime(nest, seconds, now()) else 0
	end) or 0
end

-- Resultado de la tirada del rescate: lo que salió en la ruleta y lo que de verdad se le quitó al
-- huevo (puede ser menos por el tope de lo ganado jugando, o lo que faltaba si salió la eclosión).
export type RescueOutcome = { rarity: string, hatch: boolean, rolledSeconds: number, appliedSeconds: number }

-- Tirada al ganar una partida (Config.Egg.RescueRoll), al huevo activo. nil si no hay ninguno sin estar
-- listo.
function Eggs.rescueRoll(player: Player): RescueOutcome?
	local roll = EggIncubation.rollRescue(rng)
	return edit(player, function(data): RescueOutcome?
		local time = now()
		local nest = EggIncubation.active(data, time)
		if not nest then
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

-- Deja listo ya el huevo activo del nido (eclosión inmediata del rescate). false si no hay ninguno.
function Eggs.makeReady(player: Player): boolean
	return edit(player, function(data): boolean
		local nest = EggIncubation.active(data, now())
		if not nest then
			return false
		end
		nest.ready = true
		return true
	end) == true
end

return Eggs
