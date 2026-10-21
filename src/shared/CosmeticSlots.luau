--!strict
-- Huecos de equipo de los cosméticos (Fase 9). Lo equipado se guarda en el perfil como
-- "cosmetics" = { [hueco] = id }: un hueco por tipo para Trail, Title, Aura y Frame ("Trail"…), uno
-- por rol para Outfit y WeaponSkin ("Outfit.Guerrero"), uno por mascota para PetSkin
-- ("PetSkin.Capuchin") y Config.Cosmetics.EmoteSlots para los emotes ("Emote1"…"Emote6", la rueda).
-- Lo usan el servidor (equipar) y el cliente (qué está puesto).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)

local CosmeticSlots = {}

-- Hueco de un cosmético que no es un emote (los emotes van en la rueda: emoteSlot).
function CosmeticSlots.slot(cosmetic: Cosmetics.Cosmetic): string?
	local kind = cosmetic.kind
	if kind == "Emote" then
		return nil
	elseif kind == "Outfit" or kind == "WeaponSkin" then
		return if cosmetic.role then `{kind}.{cosmetic.role}` else nil
	elseif kind == "PetSkin" then
		return if cosmetic.petId then `PetSkin.{cosmetic.petId}` else nil
	end
	return kind
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
		for index = 1, Config.Cosmetics.EmoteSlots do
			local slot = CosmeticSlots.emoteSlot(index)
			if equipped[slot] == cosmeticId then
				return slot
			end
		end
		return nil
	end
	local slot = CosmeticSlots.slot(cosmetic)
	return if slot and equipped[slot] == cosmeticId then slot else nil
end

-- Pone o quita "cosmeticId" (pulsar en el equipado lo quita; si no, sustituye al de su hueco; un
-- emote va al primer hueco libre de la rueda). Devuelve false si no cabe (rueda llena o sin hueco).
function CosmeticSlots.toggle(equipped: { [string]: string }, cosmeticId: string): boolean
	local cosmetic = Cosmetics[cosmeticId]
	if not cosmetic then
		return false
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
