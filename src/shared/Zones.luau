--!strict
-- Zonas de daño por piezas (Fase 19, W6): cuánto multiplica el daño de un arma a distancia según la zona
-- del cuerpo que toca el proyectil ("Head", "Torso", "Limb" o "Weak", el punto débil de un jefe).
-- Módulo puro, sin estado: lo usan el servidor (Combat/CombatService, Combat/Hitbox) y la calculadora.
-- Orden: el valor del arma ("zoneMultipliers" en Data/Weapons y Data/LabWeapons); si no lo trae y es la
-- cabeza, el de su proyectil (Config.Combat.Zones.HeadByProjectile; sin "projectile", la piedra); y si no, el
-- general de Config.Combat.Zones. Las armas que no son a distancia y el cañón de suero (área) no usan zonas.
-- Sin relación con Combat/Zones, que son las zonas de peligro del suelo.

local Config = require(script.Parent.Config)
local Weapons = require(script.Parent.Data.Weapons)

local SETTINGS = Config.Combat.Zones

export type Weapon = Weapons.WeaponDefinition
export type Zone = "Head" | "Torso" | "Limb" | "Weak"

local BodyZones = {}

-- true si el arma cuenta zonas: a distancia y de impacto directo (no el cañón de suero, que es de área).
function BodyZones.applies(weapon: Weapon): boolean
	if weapon.kind ~= "Ranged" then
		return false
	end
	local lab = weapon.lab
	return not (lab and lab.effect == "AcidBurst")
end

-- Multiplicador del daño de "weapon" al acertar en "zone" (1 si el arma no usa zonas o la zona es desconocida).
function BodyZones.multiplier(weapon: Weapon, zone: string): number
	if not BodyZones.applies(weapon) then
		return 1
	end
	local own = if weapon.zoneMultipliers then (weapon.zoneMultipliers :: any)[zone] else nil
	if typeof(own) == "number" then
		return own
	end
	if zone == "Head" then
		return SETTINGS.HeadByProjectile[weapon.projectile or "Stone"] or SETTINGS.Head
	end
	local general = (SETTINGS :: any)[zone]
	return if typeof(general) == "number" then general else 1
end

return BodyZones
