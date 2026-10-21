--!strict
-- Huecos de equipo de los cosméticos (Fase 9). Lo equipado se guarda en el perfil como
-- "cosmetics" = { [hueco] = id }: un hueco por tipo para Trail, Title, Aura y Frame ("Trail"…), uno
-- por rol para Outfit y WeaponSkin ("Outfit.Guerrero"), uno por mascota para PetSkin
-- ("PetSkin.Tortuga"; las que comparten modelo, uno por familia: "PetSkin.Felino") y
-- Config.Cosmetics.EmoteSlots para los emotes ("Emote1"…"Emote6", la rueda).
-- Lo usan el servidor (equipar) y el cliente (qué está puesto).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)

local CosmeticSlots = {}

-- Hueco de un cosmético que no es un emote (los emotes van en la rueda: emoteSlot).
function CosmeticSlots.slot(cosmetic: Cosmetics.Cosmetic): string?
	local kind = cosmetic.kind
	if kind == "Emote" then
		return nil
	elseif kind == "Outfit" or kind == "WeaponSkin" then
		return if cosmetic.role then `{kind}.{cosmetic.role}` else nil
	elseif kind == "PetSkin" then
		local target = cosmetic.petFamily or cosmetic.petId
		return if target then `PetSkin.{target}` else nil
	end
	return kind
end

-- Hueco de las skins de la mascota "petId": el de su familia si la tiene, si no el suyo.
function CosmeticSlots.petSkinSlot(petId: string): string
	local pet = Pets[petId]
	return `PetSkin.{if pet and pet.family then pet.family else petId}`
end

-- Si la skin "cosmetic" le vale a la mascota "petId".
function CosmeticSlots.fitsPet(cosmetic: Cosmetics.Cosmetic, petId: string): boolean
	local pet = Pets[petId]
	return cosmetic.kind == "PetSkin"
		and (cosmetic.petId == petId or (cosmetic.petFamily ~= nil and pet ~= nil and pet.family == cosmetic.petFamily))
end

-- Los emotes de la rueda, en su orden ("Emote1"…): los puestos o, si no hay ninguno, los de serie.
function CosmeticSlots.wheel(equipped: { [string]: string }): { string? }
	local result: { string? } = {}
	local any = false
	for index = 1, Config.Cosmetics.EmoteSlots do
		local cosmeticId = equipped[CosmeticSlots.emoteSlot(index)]
		if cosmeticId and Cosmetics[cosmeticId] then
			result[index] = cosmeticId
			any = true
		end
	end
	if not any then
		for index, cosmeticId in Config.Cosmetics.DefaultEmotes do
			result[index] = cosmeticId
		end
	end
	return result
end

function CosmeticSlots.emoteSlot(index: number): string
	return `Emote{index}`
end

-- Hueco donde está puesto "cosmeticId", o nil si no lo está.
function CosmeticSlots.equippedIn(equipped: { [string]: string }, cosmeticId: string): string?
	local cosmetic = Cosmetics[cosmeticId]
	if not cosmetic then
		return nil
	end
	if cosmetic.kind == "Emote" then
		local wheel = CosmeticSlots.wheel(equipped)
		for index = 1, Config.Cosmetics.EmoteSlots do
			if wheel[index] == cosmeticId then
				return CosmeticSlots.emoteSlot(index)
			end
		end
		return nil
	end
	local slot = CosmeticSlots.slot(cosmetic)
	return if slot and equipped[slot] == cosmeticId then slot else nil
end

-- La rueda vacía enseña los de serie: antes de cambiarla se escriben en sus huecos, para que quitar o
-- añadir uno no haga desaparecer los demás.
local function seedWheel(equipped: { [string]: string })
	local wheel = CosmeticSlots.wheel(equipped)
	for index = 1, Config.Cosmetics.EmoteSlots do
		local cosmeticId = wheel[index]
		if cosmeticId then
			equipped[CosmeticSlots.emoteSlot(index)] = cosmeticId
		end
	end
end

-- Pone o quita "cosmeticId" (pulsar en el equipado lo quita; si no, sustituye al de su hueco; un
-- emote va al primer hueco libre de la rueda). Devuelve false si no cabe (rueda llena o sin hueco).
function CosmeticSlots.toggle(equipped: { [string]: string }, cosmeticId: string): boolean
	local cosmetic = Cosmetics[cosmeticId]
	if not cosmetic then
		return false
	end
	if cosmetic.kind == "Emote" then
		seedWheel(equipped)
	end
	local current = CosmeticSlots.equippedIn(equipped, cosmeticId)
	if current then
		equipped[current] = nil
		return true
	end
	if cosmetic.kind == "Emote" then
		for index = 1, Config.Cosmetics.EmoteSlots do
			local slot = CosmeticSlots.emoteSlot(index)
			if equipped[slot] == nil then
				equipped[slot] = cosmeticId
				return true
			end
		end
		return false
	end
	local slot = CosmeticSlots.slot(cosmetic)
	if not slot then
		return false
	end
	equipped[slot] = cosmeticId
	return true
end

-- Quita "cosmeticId" de donde esté puesto (si se deja de tener).
function CosmeticSlots.unequip(equipped: { [string]: string }, cosmeticId: string)
	local current = CosmeticSlots.equippedIn(equipped, cosmeticId)
	if current then
		equipped[current] = nil
	end
end

return CosmeticSlots
