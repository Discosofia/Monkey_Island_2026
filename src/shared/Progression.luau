--!strict
-- Progresión permanente (Fase 3): niveles y puntos de talento por rol, ventajas calculadas y lectura
-- de los datos publicados para el cliente.
--
-- El servidor publica en el Player:
--   "Amber", "BestDays", "SelectedRole" y "Progress" (JSON con roleXp, talents, upgrades, matches,
--   tutorialDone y bestiary). En la Isla, además, "Role" y "Perk_<nombre>" (RoleService).

local HttpService = game:GetService("HttpService")

local Perks = require(script.Parent.Data.Perks)
local Pets = require(script.Parent.Data.Pets)
local Roles = require(script.Parent.Data.Roles)
local Talents = require(script.Parent.Data.Talents)
local Upgrades = require(script.Parent.Data.Upgrades)

export type ProgressData = {
	roleXp: { [string]: number },
	talents: { [string]: number },
	upgrades: { [string]: number },
	matches: number,
	tutorialDone: boolean,
	bestiary: { [string]: number },
	pets: { [string]: number },
	cosmetics: { [string]: string },
}

local Progression = {}

local NO_TALENTS: { [string]: Talents.Talent } = {}

Progression.XP_PER_LEVEL = 100
Progression.DEFAULT_ROLE = "Guerrero"

-- Nivel del rol: empieza en 1 y sube cada XP_PER_LEVEL de XP. Cada nivel por encima del 1 da un punto.
function Progression.level(xp: number): number
	return 1 + math.floor(xp / Progression.XP_PER_LEVEL)
end

function Progression.talentKey(roleId: string, talentId: string): string
	return `{roleId}.{talentId}`
end

function Progression.spentPoints(roleId: string, talents: { [string]: number }): number
	local spent = 0
	for talentId in Talents[roleId] or NO_TALENTS do
		spent += talents[Progression.talentKey(roleId, talentId)] or 0
	end
	return spent
end

function Progression.freePoints(roleId: string, data: ProgressData): number
	local earned = Progression.level(data.roleXp[roleId] or 0) - 1
	return earned - Progression.spentPoints(roleId, data.talents)
end

function Progression.validRole(roleId: any): string
	return if typeof(roleId) == "string" and Roles[roleId] then roleId else Progression.DEFAULT_ROLE
end

-- Ventajas de un rol con sus talentos, las mejoras de la tienda y la mascota activa. "extra": más
-- tablas de ventajas que se suman (el equipamiento de la arena, Data/ArenaGear.perksOf).
function Progression.computePerks(
	roleId: string,
	talents: { [string]: number },
	upgrades: { [string]: number },
	petId: string?,
	extra: { { [string]: number } }?
): { [string]: number }
	local perks = table.clone(Perks)
	local role = Roles[roleId]
	if role then
		for perk, value in role.perks do
			perks[perk] += value
		end
	end
	for talentId, talent in Talents[roleId] or NO_TALENTS do
		local rank = talents[Progression.talentKey(roleId, talentId)] or 0
		perks[talent.perk] += talent.perRank * rank
	end
	for upgradeId, upgrade in Upgrades do
		perks[upgrade.perk] += upgrade.perRank * (upgrades[upgradeId] or 0)
	end
	local pet = if petId then Pets[petId] else nil
	if pet and pet.perks then
		for perk, value in pet.perks do
			perks[perk] += value
		end
	end
	for _, more in extra or {} do
		for perk, value in more do
			perks[perk] += value
		end
	end
	return perks
end

-- Valor de una ventaja del jugador en la Isla (o su valor por defecto).
function Progression.perk(player: Player, name: string): number
	local value = player:GetAttribute(`Perk_{name}`)
	if typeof(value) == "number" then
		return value
	end
	return Perks[name] or 0
end

-- Datos de progreso publicados (para la interfaz del cliente).
function Progression.read(player: Player): ProgressData
	local raw = player:GetAttribute("Progress")
	local ok, decoded = pcall(function()
		return if typeof(raw) == "string" then HttpService:JSONDecode(raw) else nil
	end)
	local data = if ok and typeof(decoded) == "table" then decoded else {}
	return {
		roleXp = if typeof(data.roleXp) == "table" then data.roleXp else {},
		talents = if typeof(data.talents) == "table" then data.talents else {},
		upgrades = if typeof(data.upgrades) == "table" then data.upgrades else {},
		matches = if typeof(data.matches) == "number" then data.matches else 0,
		tutorialDone = data.tutorialDone == true,
		bestiary = if typeof(data.bestiary) == "table" then data.bestiary else {},
		pets = if typeof(data.pets) == "table" then data.pets else {},
		cosmetics = if typeof(data.cosmetics) == "table" then data.cosmetics else {},
	}
end

return Progression
