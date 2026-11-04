--!strict
-- Nombre y color de cada cosa que dispara un proyectil en el campo de tiro del Lobby (Fase 24d: marcas de las
-- pantallas de ajuste, RangeScreenController, y panel de calibración, RangeCalibrationController). La clave es
-- el "source" de Combat/Projectiles: el id de un arma (Data/Weapons, Data/LabWeapons) o de una habilidad
-- (Data/Roles). Las armas de rol comparten color por su proyectil (piedra, flecha, hechizo, dardo); las del
-- Laboratorio y cada habilidad tienen el suyo. Verde solo para la curación (Dardo curativo) y violeta para el
-- veneno (cañón de suero), como en el resto del juego.

local Roles = require(script.Parent.Roles)
local Weapons = require(script.Parent.Weapons)

export type Source = { name: string, color: Color3 }

local FALLBACK = Color3.fromRGB(190, 190, 190)

-- Armas de rol, por cómo se ve su proyectil.
local PROJECTILE_COLORS: { [string]: Color3 } = {
	Stone = Color3.fromRGB(235, 200, 140),
	Arrow = Color3.fromRGB(110, 180, 255),
	Spell = Color3.fromRGB(255, 125, 205),
	Dart = Color3.fromRGB(255, 255, 255),
}

-- Armas del Laboratorio y habilidades, cada una la suya.
local SOURCE_COLORS: { [string]: Color3 } = {
	LabDartGun = Color3.fromRGB(90, 230, 230),
	LabBananaRifle = Color3.fromRGB(255, 205, 40),
	LabNetHarpoon = Color3.fromRGB(255, 150, 90),
	LabAcidCannon = Color3.fromRGB(175, 95, 235),
	MultiShot = Color3.fromRGB(40, 110, 255),
	PiercingShot = Color3.fromRGB(0, 170, 200),
	TrueShot = Color3.fromRGB(215, 255, 255),
	Fireball = Color3.fromRGB(255, 110, 40),
	HealingDart = Color3.fromRGB(90, 220, 120),
}

local abilityNames: { [string]: string }? = nil

local function abilityName(id: string): string?
	if not abilityNames then
		local names: { [string]: string } = {}
		for _, role in Roles do
			for _, list in { role.abilities, role.altUltimates or {} } do
				for _, ability in list do
					names[ability.id] = ability.name
				end
			end
		end
		abilityNames = names
	end
	return (abilityNames :: { [string]: string })[id]
end

local RangeSources = {}

-- Nombre (en español, para T) y color de "source". Algo desconocido (un "look" sin id) sale con su texto y gris.
function RangeSources.get(source: string): Source
	local weapon = Weapons[source]
	if weapon then
		local color = SOURCE_COLORS[source] or PROJECTILE_COLORS[weapon.projectile or "Stone"] or FALLBACK
		return { name = weapon.name, color = color }
	end
	local name = abilityName(source)
	if name then
		return { name = name, color = SOURCE_COLORS[source] or FALLBACK }
	end
	return { name = source, color = PROJECTILE_COLORS[source] or FALLBACK }
end

return RangeSources
