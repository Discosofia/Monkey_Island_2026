--!strict
-- Las habilidades de un jugador con la definitiva que ha elegido (T7). Cada rol tiene la suya en el
-- hueco 4 de Data/Roles y otras en "altUltimates"; el jugador elige una por rol en el Lobby (ventana de
-- Talentos) y el servidor la publica en el atributo "Ultimates" del Player, un JSON { [rol] = id }
-- (ServerShared/PlayerData). Sin elegir, o con un id que ya no existe, va la del hueco 4.
-- Lo usan los dos lados: AbilityService, ComboService y RoleController para saber qué hay en cada hueco,
-- y las ventanas del Lobby para enseñar las dos.

local HttpService = game:GetService("HttpService")

local Roles = require(script.Parent.Data.Roles)

local RoleAbilities = {}

-- Hueco de la definitiva (V) en Data/Roles.
RoleAbilities.ULTIMATE_SLOT = 4

-- Lo último decodificado de cada texto del atributo: AbilityService pregunta en cada golpe.
local decoded: { [string]: { [string]: string } } = {}
local decodedCount = 0

local function chosenMap(player: Player): { [string]: string }
	local raw = player:GetAttribute("Ultimates")
	if typeof(raw) ~= "string" then
		return {}
	end
	local cached = decoded[raw]
	if cached then
		return cached
	end
	local ok, value = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	local map = if ok and typeof(value) == "table" then value else {}
	-- Pocas combinaciones distintas (una por jugador y cambio): si crece mucho, se vacía.
	if decodedCount > 200 then
		table.clear(decoded)
		decodedCount = 0
	end
	decoded[raw] = map
	decodedCount += 1
	return map
end

-- Las definitivas que puede elegir el rol: la de siempre primero.
function RoleAbilities.ultimates(roleId: string): { Roles.Ability }
	local role = Roles[roleId]
	if not role then
		return {}
	end
	local list = { role.abilities[RoleAbilities.ULTIMATE_SLOT] }
	for _, ability in role.altUltimates or {} do
		table.insert(list, ability)
	end
	return list
end

-- La definitiva "abilityId" del rol (la de siempre o una de "altUltimates"), o nil.
function RoleAbilities.findUltimate(roleId: string, abilityId: string): Roles.Ability?
	for _, ability in RoleAbilities.ultimates(roleId) do
		if ability.id == abilityId then
			return ability
		end
	end
	return nil
end

-- El id de la definitiva que lleva "player" con el rol "roleId".
function RoleAbilities.chosenUltimate(player: Player, roleId: string): string
	local role = Roles[roleId]
	local default = if role then role.abilities[RoleAbilities.ULTIMATE_SLOT].id else ""
	local chosen = chosenMap(player)[roleId]
	if typeof(chosen) == "string" and RoleAbilities.findUltimate(roleId, chosen) then
		return chosen
	end
	return default
end

-- Las 5 habilidades del rol, en el orden de sus huecos, con la definitiva "ultimateId" en el 4.
function RoleAbilities.list(roleId: string, ultimateId: string?): { Roles.Ability }
	local role = Roles[roleId]
	if not role then
		return {}
	end
	local ultimate = if ultimateId then RoleAbilities.findUltimate(roleId, ultimateId) else nil
	if not ultimate then
		return role.abilities
	end
	local list = table.clone(role.abilities)
	list[RoleAbilities.ULTIMATE_SLOT] = ultimate
	return list
end

-- Las 5 habilidades de "player" con el rol "roleId" (por defecto, el de su atributo "Role").
function RoleAbilities.of(player: Player, roleId: string?): { Roles.Ability }
	local id = roleId or player:GetAttribute("Role")
	if typeof(id) ~= "string" or not Roles[id] then
		return {}
	end
	return RoleAbilities.list(id, RoleAbilities.chosenUltimate(player, id))
end

-- Cualquier habilidad del rol con ese id, también las definitivas que no lleva (nombres de combos,
-- telemetría…).
function RoleAbilities.find(roleId: string, abilityId: string): Roles.Ability?
	local role = Roles[roleId]
	if not role then
		return nil
	end
	for _, ability in role.abilities do
		if ability.id == abilityId then
			return ability
		end
	end
	return RoleAbilities.findUltimate(roleId, abilityId)
end

return RoleAbilities
