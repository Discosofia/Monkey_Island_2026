--!strict
-- Huecos de equipo de los cosméticos (Fase 9). Lo equipado se guarda en el perfil como
-- "cosmetics" = { [hueco] = id }: un hueco por tipo para Trail, Title, Aura y Frame ("Trail"…), uno
-- por rol para Outfit y WeaponSkin ("Outfit.Guerrero"; los aspectos de un arma que no es de rol, uno por
-- su familia: "WeaponSkin.Machete"), uno por mascota para PetSkin
-- ("PetSkin.Tortuga"; las que comparten modelo, uno por familia: "PetSkin.Felino") y
-- Config.Cosmetics.EmoteSlots para los emotes ("Emote1"…"Emote6", la rueda). Los tipos baratos
-- (NumberStyle, BurstStyle, NestDecor), uno de cada.
-- Los cosméticos por grados (Data/Cosmetics "line"/"grade") cuentan como uno solo: cualquier grado de
-- la línea puesto en su hueco es "la línea puesta", y se ve el más alto que se tiene (best).
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
	elseif kind == "WeaponSkin" and cosmetic.weapon then
		return `WeaponSkin.{cosmetic.weapon}`
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

-- Si "a" y "b" son el mismo cosmético o grados de la misma línea.
function CosmeticSlots.same(a: string, b: string): boolean
	if a == b then
		return true
	end
	local first, second = Cosmetics[a], Cosmetics[b]
	return first ~= nil and second ~= nil and first.line ~= nil and first.line == second.line
end

-- Los grados de la línea de "cosmeticId", del I al más alto (él solo si no tiene línea).
function CosmeticSlots.grades(cosmeticId: string): { string }
	local cosmetic = Cosmetics[cosmeticId]
	if not (cosmetic and cosmetic.line) then
		return { cosmeticId }
	end
	local result = {}
	for id, candidate in Cosmetics do
		if candidate.line == cosmetic.line then
			table.insert(result, id)
		end
	end
	table.sort(result, function(a, b)
		return (Cosmetics[a].grade or 1) < (Cosmetics[b].grade or 1)
	end)
	return result
end

-- El grado más alto de la línea de "cosmeticId" que se tiene ("owns"), o nil si no se tiene ninguno.
function CosmeticSlots.best(cosmeticId: string, owns: (string) -> boolean): string?
	local grades = CosmeticSlots.grades(cosmeticId)
	for index = #grades, 1, -1 do
		if owns(grades[index]) then
			return grades[index]
		end
	end
	return nil
end

-- Hueco donde está puesto "cosmeticId" (o otro grado de su línea), o nil si no lo está.
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
	local current = if slot then equipped[slot] else nil
	return if slot and current and CosmeticSlots.same(current, cosmeticId) then slot else nil
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
