--!strict
-- Golpes críticos (Config.Crit): hacen ×Multiplier de daño o de curación y su número sale más grande.
--   - Jugadores: la probabilidad es la del arma ("critChance" en Data/Weapons), que sube al mejorarla
--     en la forja. Las habilidades usan la del arma que llevas en la mano o, si no es un arma, la de
--     la mejor que tengas en la mochila.
--   - Monos: según su categoría; jefes: según su fase (la 3, la furia, es la más alta).
--   - Curaciones del médico: base + la del arma + "salvada" si el aliado tiene poca vida.
-- Son funciones puras: el servidor tira los dados con ellas (CombatService) y el panel de Ajustes
-- enseña los mismos porcentajes.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local Monkeys = require(script.Parent.Data.Monkeys)
local Weapons = require(script.Parent.Data.Weapons)

local SETTINGS = Config.Crit

local Crit = {}

Crit.MULTIPLIER = SETTINGS.Multiplier

-- Probabilidad de crítico de un arma (0 si no es un arma).
function Crit.weaponChance(weaponId: string?): number
	local weapon = if weaponId then Weapons[weaponId] else nil
	if not weapon then
		return 0
	end
	return weapon.critChance or SETTINGS.DefaultWeaponChance
end

local function weaponIdOf(tool: Instance): string?
	local weaponId = tool:GetAttribute("WeaponId")
	return if typeof(weaponId) == "string" and Weapons[weaponId] then weaponId else nil
end

-- El arma que cuenta para las habilidades del jugador: la de la mano si es un arma (no el hacha ni
-- el pico) o la de mayor probabilidad que lleve encima. Devuelve su id (o nil) y su probabilidad.
function Crit.playerWeapon(player: Player): (string?, number)
	local character = player.Character
	local held = if character then character:FindFirstChildOfClass("Tool") else nil
	local heldId = if held then weaponIdOf(held) else nil
	if heldId and not Weapons[heldId].tool then
		return heldId, Crit.weaponChance(heldId)
	end
	local bestId: string? = nil
	local bestChance = 0
	local tools: { Instance } = {}
	for _, container in { character, player:FindFirstChildOfClass("Backpack") } :: { Instance? } do
		if container then
			for _, child in container:GetChildren() do
				table.insert(tools, child)
			end
		end
	end
	for _, child in tools do
		local weaponId = if child:IsA("Tool") then weaponIdOf(child) else nil
		if weaponId and not Weapons[weaponId].tool then
			local chance = Crit.weaponChance(weaponId)
			if chance > bestChance then
				bestId = weaponId
				bestChance = chance
			end
		end
	end
	if bestId then
		return bestId, bestChance
	end
	-- Solo herramientas (o nada): la probabilidad básica.
	return heldId, SETTINGS.DefaultWeaponChance
end

-- Probabilidad de que un mono o un jefe ("source", su modelo) haga un crítico.
function Crit.sourceChance(source: Instance?): number
	if not source then
		return 0
	end
	if source:GetAttribute("Boss") ~= nil then
		local phase = source:GetAttribute("BossPhase")
		local index = if typeof(phase) == "number" then math.clamp(phase, 1, #SETTINGS.BossPhaseChance) else 1
		return SETTINGS.BossPhaseChance[index]
	end
	local speciesId = source:GetAttribute("MonkeyType")
	local species = if typeof(speciesId) == "string" then Monkeys[speciesId] else nil
	return if species then SETTINGS.MonkeyTierChance[species.tier] or 0 else 0
end

-- Probabilidad de que una curación del médico sea crítica. "healthFraction": vida del aliado (0-1)
-- antes de curarle; por debajo de SaveThreshold es una "salvada".
function Crit.healChance(weaponChance: number, healthFraction: number): number
	local chance = SETTINGS.HealBaseChance + weaponChance
	if healthFraction < SETTINGS.SaveThreshold then
		chance += SETTINGS.SaveBonusChance
	end
	return math.min(1, chance)
end

-- Tira los dados. En Studio, el panel de pruebas puede hacer que todo sea crítico.
function Crit.roll(chance: number): boolean
	if RunService:IsStudio() and Workspace:GetAttribute("DebugAlwaysCrit") == true then
		return true
	end
	return chance > 0 and math.random() < chance
end

-- "12 %" para la interfaz.
function Crit.percent(chance: number): string
	return `{math.round(chance * 100)} %`
end

return Crit
