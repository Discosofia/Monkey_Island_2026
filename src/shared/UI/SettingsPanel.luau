--!strict
-- Panel de Ajustes (Lobby: pestaña "Ajustes"; Isla: botón ⚙️). De arriba abajo:
--   1. Tu personaje: tu avatar girando con su armadura y su arma en la mano (con tu mascota al lado),
--      números de ejemplo en la disposición elegida y, de vez en cuando, un estallido de cómic del
--      tamaño elegido, para ver cómo quedará cada opción antes de elegirla (UI/CombatTextColumn,
--      UI/ComicBurst).
--   2. Tus números de combate, con las ventajas del rol, los talentos, las mejoras y la mascota:
--      el arma que cuenta en una línea (daño, veneno y crítico, con Shared/Crit: los mismos números con
--      que juega el servidor), una casilla por habilidad (tecla, nombre corto y su número), una línea
--      por combo ("A → B → C · remate") y lo que hace tu mascota, con sus números.
--      En la Isla cuenta el arma de la mano o la mejor de la mochila, y la sección se rehace al
--      cambiar el arma, el rol, la mascota o una ventaja; en el Lobby, la inicial del rol.
--   3. Opciones: disposición de los números, ajustes sí/no y efectos de cómic (Shared/Settings, se
--      guardan en el perfil).
--   4. Controles del combate (Fase 10, C12): qué tecla, botón del mando o botón táctil hace cada cosa
--      (la guardia, el amago, el Evasivo, el bloqueo de cámara…).
--   5. Temblor de la cámara (encendido, suave o apagado; C12).
-- En "Tus números" también salen la cadena del arma (sus golpes y su remate) y la guardia.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combos = require(ReplicatedStorage.Shared.Data.Combos)
local Config = require(ReplicatedStorage.Shared.Config)
local Crit = require(ReplicatedStorage.Shared.Crit)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local MeleeChain = require(ReplicatedStorage.Shared.MeleeChain)
local Perks = require(ReplicatedStorage.Shared.Data.Perks)
local PetModels = require(ReplicatedStorage.Shared.PetModels)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Progression = require(ReplicatedStorage.Shared.Progression)
local RangedChain = require(ReplicatedStorage.Shared.RangedChain)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local RoleAbilities = require(ReplicatedStorage.Shared.RoleAbilities)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local CombatTextColumn = require(script.Parent.CombatTextColumn)
local ComicBurst = require(script.Parent.ComicBurst)
local Widgets = require(script.Parent.Widgets)

local T = Strings.t
local later = Strings.later

export type Context = "Island" | "Lobby"

local ROW_COLOR = Color3.fromRGB(45, 38, 30)
local ACTIVE_COLOR = Color3.fromRGB(242, 178, 36)
local TEXT_COLOR = Color3.fromRGB(235, 228, 215)
local SOFT_COLOR = Color3.fromRGB(200, 190, 175)
local RED = Color3.fromRGB(255, 70, 70)
local GREEN = Color3.fromRGB(90, 230, 110)
local YELLOW = Color3.fromRGB(255, 220, 90)
local PREVIEW_HEIGHT = 240
-- Los estallidos de ejemplo, más pequeños que en la partida (el recuadro es bajo).
local PREVIEW_COMIC_SCALE = 0.6
-- Orden en que la vista previa enseña los estallidos.
local COMIC_SAMPLES: { ComicBurst.Kind } = { "Crit", "Hit", "Hurt", "KO" }
-- Mejor probabilidad de crítico que dan las armas de la forja (Data/Weapons).
local BEST_FORGE_CHANCE = 0.15
-- Colores de los números en el texto enriquecido: veneno (morado, nunca verde), crítico y lo secundario.
local POISON_HEX = "#be6eff"
local CRIT_HEX = "#ffdc5a"
local SOFT_HEX = "#c8beaf"
local KEY_HEX = "#ffdc78"
-- Teclas de los huecos de habilidad, en el orden de Data/Roles, y el orden en que se ven: el de las
-- casillas del HUD (Z X C R V, la definitiva al final). Los dos, como en RoleController.
local ABILITY_KEYS = { "Z", "X", "C", "V", "R" }
local ABILITY_ORDER = { 1, 2, 3, 5, 4 }
-- Casillas de habilidades: 5 en fila si caben con este ancho cada una; si no, 3 por fila.
local CELL_MIN_WIDTH = 104
local CELL_HEIGHT = 70
local CELL_GAP = 6
local CELL_COLOR = Color3.fromRGB(25, 20, 15)

type PerkGetter = (name: string) -> number

-- Lo que enseña la casilla de cada habilidad:
--   - Daño o curación ("amount"): el número de Config.Abilities multiplicado por las ventajas
--     ("perks", Data/Perks) que lo suben (el daño, también por Config.Combat.PlayerDamageMultiplier).
--   - Si no hace daño ni cura, "effect" da el número (una ventaja: el escudo, el salto del Parpadeo…).
--   - "note" es la línea pequeña de debajo (puede leer ventajas: los segundos que aturde…).
type AbilityInfo = {
	amount: string?,
	perks: { string }?,
	heal: boolean?,
	effect: ((perk: PerkGetter) -> string)?,
	note: ((perk: PerkGetter) -> string)?,
}

-- 1.8 → "1,8" (en inglés, "1.8"); 2 → "2".
local function decimal(value: number): string
	local rounded = math.round(value * 10) / 10
	local result = if rounded % 1 == 0 then tostring(math.round(rounded)) else string.format("%.1f", rounded)
	return if Strings.language() == "es" then (result:gsub("%.", ",")) else result
end

-- 0.05 → "+5 %"; -0.2 → "−20 %".
local function signedPercent(value: number): string
	return `{if value < 0 then "−" else "+"}{math.round(math.abs(value) * 100)} %`
end

-- Una nota sin números ("por golpe"), marcada con later para traducirla al dibujarla.
local function fixed(note: string): (perk: PerkGetter) -> string
	return function()
		return T(note)
	end
end

local ABILITY_INFO: { [string]: AbilityInfo } = {
	-- Guerrero.
	Whirlwind = { amount = "WhirlwindDamage", perks = { "MeleeDamage" }, note = fixed(later("por golpe")) },
	Charge = { amount = "ChargeDamage", perks = { "MeleeDamage", "ChargeDamage" }, note = fixed(later("y empuja")) },
	WarCry = {
		effect = function(perk)
			return signedPercent(-perk("WarCryReduction"))
		end,
		note = fixed(later("de daño recibido")),
	},
	Quake = {
		amount = "QuakeDamage",
		perks = { "MeleeDamage" },
		note = function(perk)
			return T("aturde {s} s", { s = decimal(perk("QuakeStun")) })
		end,
	},
	Leap = {
		amount = "LeapDamage",
		perks = { "MeleeDamage" },
		note = function(perk)
			return T("y sujeta {s} s", { s = decimal(perk("QuakeStun")) })
		end,
	},
	Smash = { amount = "SmashDamage", perks = { "MeleeDamage", "SmashDamage" }, note = fixed(later("por mono")) },
	-- Cazador.
	MultiShot = {
		amount = "MultiShotDamage",
		perks = { "RangedDamage" },
		note = function(perk)
			return T("×{n} proyectiles", { n = math.round(perk("MultiShotCount")) })
		end,
	},
	MarkPrey = {
		effect = function(perk)
			return signedPercent(perk("MarkedBonus"))
		end,
		note = function(perk)
			return T("de daño, {s} s", { s = decimal(perk("MarkSeconds")) })
		end,
	},
	Trap = {
		amount = "TrapDamage",
		perks = { "RangedDamage" },
		note = function(perk)
			return T("sujeta {s} s", { s = decimal(perk("TrapRoot")) })
		end,
	},
	ArrowRain = { amount = "RainDamage", perks = { "RangedDamage", "RainDamage" }, note = fixed(later("por golpe")) },
	TrueShot = { amount = "TrueShotDamage", perks = { "RangedDamage", "RainDamage" }, note = fixed(later("a uno")) },
	PiercingShot = {
		amount = "PierceDamage",
		perks = { "RangedDamage", "PierceDamage" },
		note = fixed(later("por mono")),
	},
	-- Mago.
	Fireball = {
		amount = "FireballDamage",
		perks = { "SpellDamage", "FireballDamage" },
		note = fixed(later("y salpica")),
	},
	FrostNova = {
		amount = "NovaDamage",
		perks = { "SpellDamage" },
		note = function(perk)
			return T("congela {s} s", { s = decimal(perk("NovaFreeze")) })
		end,
	},
	Blink = {
		effect = function(perk)
			return `{math.round(perk("BlinkDistance"))}`
		end,
		note = fixed(later("studs de salto")),
	},
	ChainLightning = {
		amount = "ChainDamage",
		perks = { "SpellDamage" },
		note = function(perk)
			return T("y {n} saltos", { n = math.round(perk("ChainJumps")) })
		end,
	},
	LavaBeam = {
		amount = "BeamDamage",
		perks = { "SpellDamage" },
		note = function(perk)
			return T(
				"×{n} golpes",
				{ n = Config.Abilities.BeamTicks + math.max(0, math.floor(perk("ChainJumps") - Perks.ChainJumps)) }
			)
		end,
	},
	Meteor = { amount = "MeteorDamage", perks = { "SpellDamage" }, note = fixed(later("por mono")) },
	-- Médico.
	AreaHeal = { amount = "AreaHealAmount", perks = { "HealPower" }, heal = true, note = fixed(later("a cada aliado")) },
	HealingDart = { amount = "DartHeal", perks = { "HealPower" }, heal = true, note = fixed(later("al aliado")) },
	LeafShield = {
		effect = function(perk)
			return `{math.round(perk("ShieldAmount"))}`
		end,
		note = fixed(later("de escudo")),
	},
	HealingTotem = {
		amount = "TotemHealPerSecond",
		perks = { "HealPower" },
		heal = true,
		note = fixed(later("por segundo")),
	},
	Resurgence = { amount = "SurgeHeal", perks = { "HealPower" }, heal = true, note = fixed(later("y quita males")) },
	SleepPowder = {
		amount = "PowderDamage",
		perks = {},
		note = function(perk)
			return T("y duerme {s} s", { s = decimal(perk("PowderSleep")) })
		end,
	},
}

-- Las ventajas de una mascota ("perks" de Data/Pets, lo que suman a Data/Perks) en palabras.
local PERK_TEXT: { [string]: (value: number) -> string } = {
	MeleeDamage = function(value)
		return T("{percent} de daño cuerpo a cuerpo", { percent = signedPercent(value) })
	end,
	RangedDamage = function(value)
		return T("{percent} de daño a distancia", { percent = signedPercent(value) })
	end,
	SpellDamage = function(value)
		return T("{percent} de daño de hechizos", { percent = signedPercent(value) })
	end,
	HealPower = function(value)
		return T("{percent} de curación", { percent = signedPercent(value) })
	end,
	CooldownRate = function(value)
		return T("{percent} de recarga de habilidades", { percent = signedPercent(value) })
	end,
	MaxHealth = function(value)
		return T("+{n} de vida máxima", { n = math.round(value) })
	end,
	HungerRate = function(value)
		return T("el hambre y la sed bajan un {n} % más despacio", { n = math.round(math.abs(value) * 100) })
	end,
	SprintCost = function(value)
		return T("correr gasta un {n} % menos de estamina", { n = math.round(math.abs(value) * 100) })
	end,
	HarvestBonus = function(value)
		return T("+{n} material en cada recolección", { n = math.round(value) })
	end,
	HarvestSpeed = function(value)
		return T("recolectas un {n} % más rápido", { n = math.round(math.abs(value) * 100) })
	end,
	ToolPower = function(value)
		return T("+{n} de potencia del hacha y el pico", { n = math.round(value) })
	end,
	LootBonus = function(value)
		return T("un {n} % de un objeto más del botín de cada mono", { n = math.round(value * 100) })
	end,
}

local SettingsPanel = {}

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

local function text(parent: Instance, content: string, order: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Font = Enum.Font.BuilderSans
	label.TextSize = 17
	label.TextWrapped = true
	label.RichText = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color or TEXT_COLOR
	label.Text = content
	label.Parent = parent
	return label
end

local function heading(parent: Instance, content: string, order: number): TextLabel
	local label = text(parent, content, order, Color3.fromRGB(255, 220, 150))
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 20
	return label
end

local function section(parent: Instance, order: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = ROW_COLOR
	frame.BackgroundTransparency = 0.15
	frame.Parent = parent
	corner(frame, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame
	return frame
end

local function button(parent: Instance, content: string): TextButton
	local result = Instance.new("TextButton")
	result.Font = Enum.Font.BuilderSansBold
	result.TextScaled = true
	result.Text = content
	result.AutoButtonColor = true
	result.Parent = parent
	corner(result, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = result
	return result
end

local function paint(target: TextButton, active: boolean)
	target.BackgroundColor3 = if active then ACTIVE_COLOR else Color3.fromRGB(70, 62, 52)
	target.TextColor3 = if active then Color3.fromRGB(40, 25, 5) else Color3.new(1, 1, 1)
end

-- ===================================== Números del jugador =====================================

local function roleOf(player: Player, context: Context): string
	return Progression.validRole(player:GetAttribute(if context == "Island" then "Role" else "SelectedRole"))
end

local function activePet(player: Player): string?
	local petId = player:GetAttribute("ActivePet")
	return if typeof(petId) == "string" and Pets[petId] then petId else nil
end

-- Ventajas del jugador: en la Isla, las publicadas; en el Lobby, las de su rol, talentos y mejoras.
-- En los dos casos ya llevan sumadas las de la mascota activa (Progression.computePerks).
local function perkGetter(player: Player, context: Context): PerkGetter
	if context == "Island" then
		return function(name: string): number
			return Progression.perk(player, name)
		end
	end
	local data = Progression.read(player)
	local perks = Progression.computePerks(roleOf(player, context), data.talents, data.upgrades, activePet(player))
	return function(name: string): number
		return perks[name] or Perks[name] or 0
	end
end

-- El arma que cuenta: en la Isla, la de Crit.playerWeapon; en el Lobby, la inicial del rol.
local function weaponOf(player: Player, context: Context): (string?, number)
	if context == "Island" then
		return Crit.playerWeapon(player)
	end
	local weaponId = Roles[roleOf(player, context)].weapons[1]
	return weaponId, Crit.weaponChance(weaponId)
end

local function weaponPerk(weapon: Weapons.WeaponDefinition): string
	if weapon.kind == "Melee" then
		return "MeleeDamage"
	end
	return if weapon.spell then "SpellDamage" else "RangedDamage"
end

-- Número grande de la casilla de una habilidad y su color: daño (amarillo, como los números del
-- daño que haces), curación (verde, con "+") o efecto (blanco).
local function abilityValue(ability: Roles.Ability, perk: PerkGetter): (string, Color3)
	local info = ABILITY_INFO[ability.id]
	if not info then
		return "", TEXT_COLOR
	elseif info.effect then
		return info.effect(perk), TEXT_COLOR
	end
	local amount = (Config.Abilities :: any)[info.amount] :: number
	if not info.heal then
		amount *= Config.Combat.PlayerDamageMultiplier
	end
	for _, name in info.perks or {} do
		amount *= perk(name)
	end
	if info.heal then
		return `+{math.round(amount)}`, GREEN
	end
	return `{math.round(amount)}`, YELLOW
end

local function cellLabel(parent: Instance, order: number, size: number, font: Enum.Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, size + 2)
	label.Font = font
	label.TextSize = size
	label.RichText = true
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.Parent = parent
	return label
end

-- Cuadrícula de las 5 habilidades (con la definitiva elegida: Shared/RoleAbilities): tecla y nombre
-- corto (los de las casillas del HUD), el número y una nota. Fondo oscuro de ventana, sin borde dorado:
-- se lee como información, no como botón.
local function abilityGrid(parent: Instance, order: number, abilities: { Roles.Ability }, perk: PerkGetter)
	local grid = Instance.new("Frame")
	grid.LayoutOrder = order
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP)
	layout.Parent = grid
	-- 5 en fila si caben (Ajustes de la Isla y el Lobby en PC); en una ventana estrecha, 3 y 2.
	local function fit()
		local columns = if grid.AbsoluteSize.X >= 5 * CELL_MIN_WIDTH + 4 * CELL_GAP then 5 else 3
		-- El desfase de UDim es entero: redondeado hacia arriba para que la última casilla quepa.
		layout.CellSize = UDim2.new(1 / columns, -math.ceil(CELL_GAP * (columns - 1) / columns), 0, CELL_HEIGHT)
	end
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	for index, ability in abilities do
		local cell = Instance.new("Frame")
		cell.Name = ability.id
		cell.LayoutOrder = ABILITY_ORDER[index] or index
		cell.BackgroundColor3 = CELL_COLOR
		cell.BackgroundTransparency = 0.25
		cell.Parent = grid
		corner(cell, 8)
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 5)
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 6)
		padding.Parent = cell
		local stack = Instance.new("UIListLayout")
		stack.SortOrder = Enum.SortOrder.LayoutOrder
		stack.Parent = cell

		local title = cellLabel(cell, 1, 15, Enum.Font.BuilderSans, TEXT_COLOR)
		title.Text = `<font color="{KEY_HEX}"><b>{ABILITY_KEYS[index] or ""}</b></font> {T(ability.short)}`
		local value, color = abilityValue(ability, perk)
		local number = cellLabel(cell, 2, 22, Enum.Font.BuilderSansBold, color)
		number.Text = value
		local info = ABILITY_INFO[ability.id]
		local note = cellLabel(cell, 3, 13, Enum.Font.BuilderSans, SOFT_COLOR)
		note.Text = if info and info.note then info.note(perk) else ""
	end
end

-- "A → B → C · remate" con los nombres cortos de las habilidades (los de las casillas).
local function comboLine(combo: Combos.Combo, role: Roles.Role): string
	local names = {}
	for _, stepId in combo.steps do
		for _, ability in role.abilities do
			if ability.id == stepId then
				table.insert(names, T(ability.short))
			end
		end
	end
	return `{combo.icon} <b>{T(combo.name)}</b>: {table.concat(names, " → ")} · <font color="{SOFT_HEX}">{T(
		combo.short
	)}</font>`
end

-- Lo que hace la mascota, con sus números: ataque y curación, rastreo y sus ventajas (Data/Perks, ya
-- sumadas a tus números de arriba).
local function petHelp(pet: Pets.Pet): string
	local help = {}
	local seconds = Config.Pets.TickSeconds
	if pet.attackDamage and pet.healPerTick then
		table.insert(
			help,
			T(
				"{damage} de daño y +{heal} de vida cada {seconds} s",
				{ damage = pet.attackDamage, heal = pet.healPerTick, seconds = seconds }
			)
		)
	elseif pet.attackDamage then
		table.insert(
			help,
			T(
				"{damage} de daño al mono más cercano cada {seconds} s",
				{ damage = pet.attackDamage, seconds = seconds }
			)
		)
	elseif pet.healPerTick then
		table.insert(help, T("+{heal} de vida cada {seconds} s", { heal = pet.healPerTick, seconds = seconds }))
	end
	if pet.tracks then
		table.insert(
			help,
			T(
				"resalta los monos a menos de {radius} studs cada {seconds} s",
				{ radius = Config.Pets.TrackRadius, seconds = Config.Pets.TrackSeconds }
			)
		)
	end
	if pet.sniffsEggs then
		table.insert(
			help,
			T(
				"huele el huevo a menos de {radius} studs y te deja huellas hacia él",
				{ radius = Config.Pets.EggSniffRadius }
			)
		)
	end
	if pet.marks then
		table.insert(
			help,
			T("marca al mono más cercano: todos le hacen {percent} de daño (a los jefes, +{boss} %)", {
				percent = signedPercent(Config.Pets.MarkBonus),
				boss = decimal(Config.Pets.MarkBonus * Config.Pets.MarkBossMultiplier * 100),
			})
		)
	end
	local names = {}
	for name in pet.perks or {} do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local describe = PERK_TEXT[name]
		if describe then
			table.insert(help, describe((pet.perks :: { [string]: number })[name]))
		end
	end
	if pet.attackDamage or pet.healPerTick then
		table.insert(
			help,
			`<font color="{CRIT_HEX}">{T("{percent} de crítico", { percent = Crit.percent(Config.Crit.PetChance) })}</font>`
		)
	end
	-- Una ayuda que el panel aún no sabe contar: la descripción de Data/Pets.
	return if #help > 0 then table.concat(help, " · ") else T(pet.description)
end

-- Cadena del arma (Fase 10, C4 y C9b): el daño de cada golpe seguido y lo que hace el remate. nil si el
-- arma pega suelta (herramientas, armas a distancia sin remate).
local function chainHelp(weapon: Weapons.WeaponDefinition, damage: number): string?
	if MeleeChain.uses(weapon) then
		local hits = {}
		for step = 1, MeleeChain.LENGTH do
			table.insert(hits, `{math.round(damage * MeleeChain.damageMultiplier(step))}`)
		end
		return T(
			"🔗 Cadena de {n} golpes al ritmo: {hits}; el último empuja (si saltas, lanza hacia arriba; contra un muro, aturde)",
			{ n = MeleeChain.LENGTH, hits = table.concat(hits, " · ") }
		)
	end
	local finisher = RangedChain.settings(weapon)
	if not finisher then
		return nil
	end
	local shot = math.round(damage * finisher.shot)
	local last = math.round(damage * finisher.finisher)
	local does = if weapon.finisher == "Pierce"
		then T("atraviesa y da a {n} enemigos", { n = finisher.pierceTargets })
		elseif weapon.finisher == "Burst" then T("estalla en {radius} studs", { radius = finisher.radius })
		elseif weapon.finisher == "Sap" then T("cura el doble a un aliado")
		else T("tambalea a los monos pequeños")
	return T(
		"🎯 Cada {n}.º disparo seguido es un remate: {shot} → {last} y {does}",
		{ n = RangedChain.LENGTH, shot = shot, last = last, does = does }
	)
end

-- La guardia (Fase 10, C5): lo que quita el bloqueo, la ventana del parry y la rotura.
local function guardHelp(): string
	local guard = Config.Guard
	return T(
		"🛡️ Guardia {max}: bloquear quita el {block} % del daño de frente (de los monos, el {enemies} %); pulsar justo antes del golpe es un parry ({parry} s). Sin guardia, aturdido {stun} s",
		{
			max = guard.Max,
			block = math.round(guard.BlockReduction * 100),
			enemies = math.round(guard.BlockReductionEnemies * 100),
			parry = decimal(guard.ParryWindowSeconds),
			stun = decimal(guard.BreakStunSeconds),
		}
	)
end

local function fillStats(parent: Frame, player: Player, context: Context)
	local roleId = roleOf(player, context)
	local role = Roles[roleId]
	local perk = perkGetter(player, context)
	local critPercent = Crit.percent(Crit.MULTIPLIER - 1)
	heading(parent, T("{icon} Tus números de combate ({role})", { icon = role.icon, role = T(role.name) }), 10)

	-- Arma: una línea con el daño (y el veneno de las cerbatanas) y el crítico.
	local weaponId, chance = weaponOf(player, context)
	local weapon = if weaponId then Weapons[weaponId] else nil
	if weapon then
		local scale = perk(weaponPerk(weapon)) * Config.Combat.PlayerDamageMultiplier
		local damage = math.round(weapon.damage * scale)
		local poison = if weapon.poison
			then ` + <font color="{POISON_HEX}">{T("veneno {dps}/s ({seconds} s)", {
				dps = math.round(weapon.poison.dps * scale),
				seconds = decimal(weapon.poison.seconds),
			})}</font>`
			else ""
		local forge = if chance < BEST_FORGE_CHANCE
			then ` <font color="{SOFT_HEX}">{T(
				"(forja: hasta {percent})",
				{ percent = Crit.percent(BEST_FORGE_CHANCE) }
			)}</font>`
			else ""
		text(
			parent,
			`⚔️ <b>{T(weapon.name)}</b>: {T("{damage} de daño", { damage = damage })}{poison} · <font color="{CRIT_HEX}">{T(
				"{percent} de crítico",
				{ percent = Crit.percent(chance) }
			)}</font> (+{critPercent}){forge}`,
			20
		)
		local chainLine = chainHelp(weapon, damage)
		if chainLine then
			text(parent, chainLine, 21, SOFT_COLOR)
		end
	end
	text(parent, guardHelp(), 22, SOFT_COLOR)
	if roleId == "Medico" then
		local normal = Crit.percent(Crit.healChance(chance, 1))
		local save = Crit.percent(Crit.healChance(chance, 0))
		local threshold = Crit.percent(Config.Crit.SaveThreshold)
		text(
			parent,
			T(
				"💚 Curas críticas: {normal}; {save} si el aliado tiene menos del {threshold} de vida",
				{ normal = normal, save = save, threshold = threshold }
			),
			30
		)
	end

	text(parent, T("✨ Habilidades · {percent} de crítico", { percent = Crit.percent(chance) }), 40, SOFT_COLOR)
	abilityGrid(parent, 50, RoleAbilities.of(player, roleId), perk)

	local combos = Combos[roleId] or {}
	for index, combo in combos do
		text(parent, comboLine(combo, role), 50 + index)
	end
	if #combos > 0 then
		local bonus = combos[1].damageBonus
		local line = if bonus
			then T("🔗 Pasos 2 y 3: crítico seguro y +{n} % a lo marcado.", { n = math.round(bonus * 100) })
			else T("🔗 Pasos 2 y 3: crítico seguro a lo marcado.")
		if #combos >= 2 then
			line ..= " " .. T("Cerrar uno abre el paso 2 del otro.")
		end
		text(parent, line, 90, SOFT_COLOR)
	end

	local petId = activePet(player)
	local pet = if petId then Pets[petId] else nil
	if pet then
		local rarity = Rarities[pet.rarity]
		text(
			parent,
			`🐾 {pet.icon} <b>{T(pet.name)}</b> <font color="#{rarity.color:ToHex()}">({T(rarity.name)})</font>: {petHelp(
				pet
			)}`,
			100
		)
	else
		text(parent, T("🐾 Sin mascota: los huevos de la isla te dan una."), 100, SOFT_COLOR)
	end
end

-- En la Isla la ventana se queda abierta mientras juegas: los números se rehacen al cambiar el rol, la
-- mascota, una ventaja o el arma (la de la mano o las de la mochila). Devuelve cómo dejar de mirar.
-- En el Lobby no hace falta: LobbyUIController rehace la pestaña entera con cada cambio de atributo.
local function watchStats(player: Player, refresh: () -> ()): () -> ()
	local queued = false
	local function queue()
		if queued then
			return
		end
		queued = true
		-- Equipar un arma la saca de la mochila y la pone en el personaje: un solo repintado.
		task.defer(function()
			queued = false
			refresh()
		end)
	end
	local function onTool(child: Instance)
		if child:IsA("Tool") then
			queue()
		end
	end
	local holders: { RBXScriptConnection } = {}
	local function watchHolders()
		for _, connection in holders do
			connection:Disconnect()
		end
		table.clear(holders)
		for _, holder in { player.Character, player:FindFirstChildOfClass("Backpack") } :: { Instance? } do
			if holder then
				table.insert(holders, holder.ChildAdded:Connect(onTool))
				table.insert(holders, holder.ChildRemoved:Connect(onTool))
			end
		end
	end
	watchHolders()
	local connections = {
		player.AttributeChanged:Connect(function(name: string)
			if name == "Role" or name == "ActivePet" or name == "PetSkin" or name:sub(1, 5) == "Perk_" then
				queue()
			end
		end),
		-- Al reaparecer cambian el personaje y la mochila.
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				watchHolders()
				queue()
			end
		end),
		player.CharacterAdded:Connect(function()
			watchHolders()
			queue()
		end),
	}
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, connection in holders do
			connection:Disconnect()
		end
	end
end

-- ===================================== Vista previa =====================================

type Preview = {
	setLayout: (layout: Settings.Layout) -> (),
	showComic: (kind: ComicBurst.Kind?) -> (),
	stop: () -> (),
}

-- Sube el brazo derecho de la copia hacia delante (como al empuñar) y le pone en la mano el arma,
-- colocada igual que la coloca Roblox al equiparla (RightGripAttachment y tool.Grip).
local function holdWeapon(copy: Model, weaponId: string)
	local root = copy:FindFirstChild("HumanoidRootPart")
	local hand = copy:FindFirstChild("RightHand") or copy:FindFirstChild("Right Arm")
	local grip = if hand then hand:FindFirstChild("RightGripAttachment") else nil
	local upper = copy:FindFirstChild("RightUpperArm") or copy:FindFirstChild("Right Arm")
	if
		not (
			root
			and root:IsA("BasePart")
			and hand
			and hand:IsA("BasePart")
			and grip
			and grip:IsA("Attachment")
			and upper
			and upper:IsA("BasePart")
		)
	then
		return
	end
	-- Brazo hacia delante: sus piezas giran 90° alrededor del hombro, en los ejes del personaje.
	local rig = upper:FindFirstChild("RightShoulderRigAttachment") or upper:FindFirstChild("RightShoulderAttachment")
	local shoulder = if rig and rig:IsA("Attachment")
		then rig.WorldPosition
		else (upper.CFrame * CFrame.new(0, upper.Size.Y / 2 - 0.5, 0)).Position
	local pivot = CFrame.new(shoulder) * root.CFrame.Rotation
	local raise = pivot * CFrame.Angles(math.rad(90), 0, 0) * pivot:Inverse()
	for _, name in { "RightUpperArm", "RightLowerArm", "RightHand", "Right Arm" } do
		local part = copy:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.CFrame = raise * part.CFrame
		end
	end

	local tool = WeaponTools.build(weaponId)
	local weapon = Instance.new("Model")
	weapon.Name = "Weapon"
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			child.Parent = weapon
		end
	end
	local handle = weapon:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		weapon.PrimaryPart = handle
		weapon:PivotTo(hand.CFrame * grip.CFrame * tool.Grip:Inverse())
		weapon.Parent = copy
	end
	tool:Destroy()
end

-- Copia del personaje para la vista previa (sin scripts), con su armadura y su arma: la que lleva en
-- la mano o, si no lleva ninguna, la de sus números de combate (weaponOf).
local function avatarCopy(player: Player, context: Context): Model?
	local character = player.Character
	if not character then
		return nil
	end
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return nil
	end
	for _, child in copy:GetDescendants() do
		if child:IsA("BaseScript") or child:IsA("Sound") or child:IsA("BillboardGui") then
			child:Destroy()
		end
	end
	if not copy:FindFirstChildOfClass("Tool") then
		local weaponId = weaponOf(player, context)
		if weaponId then
			holdWeapon(copy, weaponId)
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	return copy
end

-- Dónde salen las columnas de ejemplo en cada disposición (dentro del recuadro de la vista previa).
-- "loot": lo que recoges, debajo de la columna de la derecha.
local PREVIEW_RECTS: { [string]: { left: { UDim2 }, right: { UDim2 }, loot: { UDim2 } } } = {
	-- { AnchorPoint como UDim2 (X, Y en Scale), Position, Size }
	Head = {
		left = { UDim2.fromScale(1, 0), UDim2.new(0.5, -26, 0, 4), UDim2.new(0, 96, 0.36, 0) },
		right = { UDim2.fromScale(0, 0), UDim2.new(0.5, 26, 0, 4), UDim2.new(0, 96, 0.36, 0) },
		loot = { UDim2.fromScale(0, 0), UDim2.new(0.5, 26, 0.38, 0), UDim2.new(0, 150, 0.32, 0) },
	},
	Column = {
		left = { UDim2.fromScale(1, 0), UDim2.new(0.5, -46, 0.08, 0), UDim2.new(0, 96, 0.88, 0) },
		right = { UDim2.fromScale(0, 0), UDim2.new(0.5, 46, 0.08, 0), UDim2.new(0, 96, 0.6, 0) },
		loot = { UDim2.fromScale(0, 0), UDim2.new(0.5, 46, 0.68, 0), UDim2.new(0, 150, 0.3, 0) },
	},
	Screen = {
		left = { UDim2.fromScale(0, 0.5), UDim2.fromScale(0.03, 0.5), UDim2.fromScale(0.26, 0.6) },
		right = { UDim2.fromScale(1, 0.5), UDim2.fromScale(0.97, 0.4), UDim2.fromScale(0.26, 0.5) },
		loot = { UDim2.fromScale(1, 0), UDim2.fromScale(0.97, 0.67), UDim2.fromScale(0.3, 0.3) },
	},
}
-- Lo que se "recoge" en la vista previa (se repite el primero para que se vea cómo suma).
local PREVIEW_LOOT = { "Wood", "Wood", "Wood", "Banana", "Fiber", "Fiber" }

local function buildPreview(parent: Frame, player: Player, context: Context): Preview
	local holder = Instance.new("Frame")
	holder.LayoutOrder = 1
	holder.Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT)
	holder.BackgroundColor3 = Color3.fromRGB(30, 45, 40)
	holder.ClipsDescendants = true
	holder.Parent = parent
	corner(holder, 10)

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(170, 170, 170)
	viewport.LightColor = Color3.fromRGB(255, 245, 230)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = holder
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local avatar = avatarCopy(player, context)
	local center = Vector3.zero
	local baseY = 0
	if avatar then
		avatar:PivotTo(CFrame.new())
		avatar.Parent = viewport
		local box, extents = avatar:GetBoundingBox()
		center = box.Position
		baseY = box.Position.Y - extents.Y / 2
		local distance = (extents.Y / 2) / math.tan(math.rad(camera.FieldOfView / 2)) * 1.25
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 0.4, -distance), center)
	else
		local note = Widgets.label(T("Tu personaje aparecerá aquí"), holder)
		note.Size = UDim2.fromScale(0.6, 0.12)
		note.AnchorPoint = Vector2.new(0.5, 0.5)
		note.Position = UDim2.fromScale(0.5, 0.5)
	end

	local petId = activePet(player)
	local skinId = player:GetAttribute("PetSkin")
	local petModel = if petId then PetModels.build(petId, if typeof(skinId) == "string" then skinId else nil) else nil
	if petModel then
		local height = petModel:GetAttribute("Height")
		local lift = if typeof(height) == "number" then height else 1
		local motion = petModel:GetAttribute("Motion")
		if motion == "Fly" or motion == "Hover" then
			lift += 2
		end
		-- Al lado del avatar; con su -Z hacia delante, ya mira a la cámara (que está en -Z).
		petModel:PivotTo(CFrame.new(center.X - 3.2, baseY + lift, center.Z))
		petModel.Parent = viewport
	end

	-- Columnas de ejemplo encima del dibujo.
	local overlay = Instance.new("Frame")
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 2
	overlay.Parent = holder
	local frames: { [string]: Frame } = {}
	local columns: { [string]: CombatTextColumn.Column } = {}
	for _, side in { "left", "right", "loot" } do
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Parent = overlay
		frames[side] = frame
		columns[side] = if side == "loot"
			then CombatTextColumn.new(frame, "Left", {
				slots = Config.CombatText.LootSlots,
				lifetime = Config.CombatText.LootLifetimeSeconds,
			})
			else CombatTextColumn.new(frame, if side == "left" then "Right" else "Left")
	end
	local screenHint = Widgets.label("pantalla", overlay)
	screenHint.AnchorPoint = Vector2.new(0.5, 1)
	screenHint.Position = UDim2.new(0.5, 0, 1, -4)
	screenHint.Size = UDim2.fromOffset(160, 18)
	screenHint.TextColor3 = SOFT_COLOR

	local function setLayout(layout: Settings.Layout)
		local rects = PREVIEW_RECTS[layout]
		for side, frame in frames do
			local rect = (rects :: any)[side] :: { UDim2 }
			frame.AnchorPoint = Vector2.new(rect[1].X.Scale, rect[1].Y.Scale)
			frame.Position = rect[2]
			frame.Size = rect[3]
			columns[side]:clear()
		end
		screenHint.Text = if layout == "Screen" then T("↔ fijos en la pantalla") else ""
	end

	-- Un estallido de cómic sobre el pecho del avatar, del tamaño elegido. Sin "kind", el siguiente
	-- de COMIC_SAMPLES (sin el golpe normal si solo se ven los fuertes).
	local comicIndex = 0
	local function showComic(kind: ComicBurst.Kind?)
		local values = Settings.get()
		if not values.comicFx or not holder.Parent then
			return
		end
		local chosen: ComicBurst.Kind = kind or COMIC_SAMPLES[1]
		if not kind then
			for _ = 1, #COMIC_SAMPLES do
				comicIndex = comicIndex % #COMIC_SAMPLES + 1
				chosen = COMIC_SAMPLES[comicIndex]
				if not (chosen == "Hit" and values.comicLevel == "Strong") then
					break
				end
			end
		end
		local comic = Config.ComicFx
		local pixels = math.round(comic.Pixels[chosen] * PREVIEW_COMIC_SCALE * (comic.SizeScale[values.comicSize] or 1))
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.6)
		frame.Size = UDim2.fromOffset(pixels, pixels)
		frame.Parent = overlay
		-- Con tu estilo de estallido, si llevas uno (como en el combate).
		local styleId = Players.LocalPlayer:GetAttribute("BurstStyle")
		local style = if typeof(styleId) == "string" then styleId else nil
		local life = ComicBurst.play(frame, chosen, ComicBurst.word(chosen, nil, style), pixels, false, style)
		task.delay(life + 0.05, function()
			frame:Destroy()
		end)
	end

	-- Números de ejemplo: daño recibido, curaciones y, si la mascota cura, las suyas (más pequeñas);
	-- y lo recogido, si está activado.
	local running = true
	local pet = if petId then Pets[petId] else nil
	task.spawn(function()
		local tick = 0
		local lootIndex, lootTotal, lastItem = 0, 0, ""
		while running and holder.Parent do
			tick += 1
			if tick % 2 == 0 and Settings.get().showLoot then
				lootIndex = lootIndex % #PREVIEW_LOOT + 1
				local itemId = PREVIEW_LOOT[lootIndex]
				lootTotal = if itemId == lastItem then lootTotal + 1 else 1
				lastItem = itemId
				local item = Items[itemId]
				columns.loot:push(`+{lootTotal} {item.icon} {T(item.name)}`, { color = TEXT_COLOR, key = itemId })
			end
			local crit = math.random() < 0.25
			if tick % 2 == 1 then
				local amount = math.random(6, 18)
				columns.left:push(`-{if crit then math.round(amount * Crit.MULTIPLIER) else amount}`, {
					color = RED,
					crit = crit,
				})
			else
				local amount = math.random(8, 22)
				columns.right:push(`+{if crit then math.round(amount * Crit.MULTIPLIER) else amount}`, {
					color = GREEN,
					crit = crit,
				})
			end
			if pet and pet.healPerTick and tick % 3 == 0 then
				columns.right:push(`+{pet.healPerTick}`, { color = GREEN, scale = Config.CombatText.PetTextScale })
			elseif pet and pet.attackDamage and tick % 3 == 0 then
				columns.left:push(`{pet.attackDamage}`, { color = YELLOW, scale = Config.CombatText.PetTextScale })
			end
			if tick % 3 == 0 then
				showComic()
			end
			task.wait(0.7)
		end
	end)

	local clock = 0
	local connection = RunService.RenderStepped:Connect(function(deltaTime)
		clock += deltaTime
		if avatar then
			avatar:PivotTo(CFrame.new(center) * CFrame.Angles(0, clock * 0.6, 0) * CFrame.new(-center))
		end
		if petModel then
			PetModels.animate(petModel, clock, 0)
		end
	end)

	return {
		setLayout = setLayout,
		showComic = showComic,
		stop = function()
			running = false
			connection:Disconnect()
			for _, column in columns do
				column:destroy()
			end
		end,
	}
end

-- ===================================== Opciones =====================================

local TOGGLES = {
	{ key = "showNumbers", label = later("Números de daño y curación") },
	{ key = "allyNumbers", label = later("Daño de los aliados (tenue)") },
	{ key = "showLoot", label = later("Lo que recoges (+2 🌲 Madera)") },
	{ key = "showCombo", label = later("Combos y racha") },
	{ key = "damageFx", label = later("Pantalla roja al recibir daño") },
	{ key = "music", label = later("Música (tecla M)") },
}

-- Fila de botones para elegir uno de "choices" en el ajuste "key". Devuelve cómo repintarla.
local function choiceRow(
	parent: Instance,
	order: number,
	key: string,
	choices: { string },
	names: { [string]: string }
): (values: Settings.Values) -> ()
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 46)
	row.Parent = parent
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.Parent = row
	local buttons: { [string]: TextButton } = {}
	for index, choice in choices do
		local option = button(row, T(names[choice]))
		option.LayoutOrder = index
		option.Size = UDim2.new(1 / #choices, -4, 1, 0)
		option.Activated:Connect(function()
			Settings.set(key, choice)
		end)
		buttons[choice] = option
	end
	return function(values: Settings.Values)
		for choice, option in buttons do
			paint(option, (values :: any)[key] == choice)
		end
	end
end

-- Línea con un texto a la izquierda y un interruptor Sí/No a la derecha para el ajuste "key".
local function toggleLine(parent: Instance, order: number, key: string, label: string): TextButton
	local line = Instance.new("Frame")
	line.LayoutOrder = order
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, 0, 0, 40)
	line.Parent = parent
	local name = text(line, T(label), 1)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.Size = UDim2.fromScale(0.65, 1)
	local switch = button(line, "")
	switch.AnchorPoint = Vector2.new(1, 0.5)
	switch.Position = UDim2.fromScale(1, 0.5)
	switch.Size = UDim2.new(0.3, 0, 0, 36)
	switch.Activated:Connect(function()
		Settings.set(key, not (Settings.get() :: any)[key])
	end)
	return switch
end

-- Va arriba del todo, encima de la vista previa: es lo que más se cambia y la vista previa enseña
-- al momento cómo queda.
local function buildLayoutChoice(parent: Frame): (values: Settings.Values) -> ()
	heading(parent, T("📍 Dónde salen tus números"), 1)
	text(
		parent,
		T("Rojo a la izquierda: daño que recibes. Verde a la derecha: curaciones; debajo, lo que recoges."),
		2,
		SOFT_COLOR
	)
	local refreshLayout = choiceRow(parent, 3, "textLayout", Settings.LAYOUTS, Settings.LAYOUT_NAMES)
	text(parent, T("Letra de los números"), 4, SOFT_COLOR)
	local refreshFont = choiceRow(parent, 5, "numberFont", Settings.NUMBER_FONTS, Settings.NUMBER_FONT_NAMES)
	return function(values: Settings.Values)
		refreshLayout(values)
		refreshFont(values)
	end
end

local function buildOptions(parent: Frame): (values: Settings.Values) -> ()
	heading(parent, T("⚙️ Opciones"), 4)
	local toggleButtons: { [string]: TextButton } = {}
	for index, toggle in TOGGLES do
		toggleButtons[toggle.key] = toggleLine(parent, 4 + index, toggle.key, toggle.label)
	end

	heading(parent, T("💥 Efectos de cómic"), 20)
	text(
		parent,
		T(
			"Estallidos al golpear (BAM!), en los críticos (POW!), al derribar (K.O.!), cuando te pegan fuerte (OUCH!) y en la guardia (¡PARRY!, ¡GUARDIA ROTA!, ¡CONTRA!)."
		),
		21,
		SOFT_COLOR
	)
	toggleButtons.comicFx = toggleLine(parent, 22, "comicFx", later("Efectos de cómic"))
	text(parent, T("Cuáles: todos, o solo críticos, K.O. y golpes fuertes que recibes"), 23, SOFT_COLOR)
	local refreshLevel = choiceRow(parent, 24, "comicLevel", Settings.COMIC_LEVELS, Settings.COMIC_LEVEL_NAMES)
	text(parent, T("Tamaño"), 25, SOFT_COLOR)
	local refreshSize = choiceRow(parent, 26, "comicSize", Settings.COMIC_SIZES, Settings.COMIC_SIZE_NAMES)

	return function(values: Settings.Values)
		refreshLevel(values)
		refreshSize(values)
		for key, switch in toggleButtons do
			local on = (values :: any)[key] == true
			switch.Text = if on then T("Sí") else T("No")
			paint(switch, on)
		end
	end
end

-- ===================================== Controles =====================================

-- Lo que se hace en combate y con qué: PC · mando · móvil (los mismos que ActionButtons y los
-- controladores de combate: WeaponController, RoleController, GuardController, DodgeController…).
local CONTROLS: { { name: string, keys: string, help: string? } } = {
	{
		name = later("Pegar o disparar"),
		keys = later("clic · R2 · tocar la pantalla"),
		help = later("4 golpes al ritmo son una cadena"),
	},
	{ name = later("Habilidades"), keys = later("Z X C R y V · R1 + A B X Y L1 · sus botones") },
	{
		name = later("Guardia"),
		keys = later("F · L2 · «Guardia»"),
		help = later("presiona justo antes del golpe para un parry; mantén para bloquear"),
	},
	{
		name = later("Amago"),
		keys = later("la guardia mientras preparas un golpe o una habilidad"),
		help = later("engaña al que para"),
	},
	{ name = later("Esquivar"), keys = later("Q · B · «Esquivar»") },
	{
		name = later("Evasivo"),
		keys = later("esquivar estando aturdido o sujeto"),
		help = later("te saca del combo"),
	},
	{ name = later("Correr"), keys = later("Mayús · L3 · «Correr»") },
	{
		name = later("Deslizar"),
		keys = later("Alt izquierdo (C en el Laboratorio) · R3 · «Deslizar» mientras corres"),
		help = later("solo corriendo; no te hace invulnerable"),
	},
	{
		name = later("Bloqueo de cámara"),
		keys = later("Ctrl (en PC)"),
		help = later("actívalo en el menú de Roblox; apuntas hacia donde miras"),
	},
}

local function buildControls(parent: Frame)
	heading(parent, T("🎮 Controles del combate"), 1)
	text(parent, T("PC · control · celular"), 2, SOFT_COLOR)
	for index, control in CONTROLS do
		local help = if control.help then ` <font color="{SOFT_HEX}">({T(control.help)})</font>` else ""
		text(parent, `<b>{T(control.name)}</b>: <font color="{KEY_HEX}">{T(control.keys)}</font>{help}`, 2 + index)
	end
	text(
		parent,
		T("💨 El Evasivo se recarga en {seconds} s.", { seconds = Config.Evasive.CooldownSeconds }),
		20,
		SOFT_COLOR
	)
end

-- Va en su propia sección, detrás de los controles: en el Lobby las secciones se reparten en columnas
-- por orden y así cae debajo de ellos (en la de opciones ya no cabía sin desplazarse).
local function buildShake(parent: Frame): (values: Settings.Values) -> ()
	heading(parent, T("📳 Temblor de la cámara"), 1)
	text(parent, T("En los remates, las habilidades fuertes, los rebotes contra muros y la guardia"), 2, SOFT_COLOR)
	local refreshShake = choiceRow(parent, 3, "cameraShake", Settings.CAMERA_SHAKES, Settings.CAMERA_SHAKE_NAMES)
	-- Idioma (GDD §18): cada opción en su idioma; "Automático" sigue el de la cuenta de Roblox.
	heading(parent, T("🌐 Idioma · Language"), 4)
	local refreshLanguage = choiceRow(parent, 5, "language", Settings.LANGUAGES, Settings.LANGUAGE_NAMES)
	return function(values: Settings.Values)
		refreshShake(values)
		refreshLanguage(values)
	end
end

-- Construye el panel dentro de "parent" (que debe poder desplazarse si no cabe). Se limpia solo al
-- destruirse. Al cambiar de idioma (Strings.onChanged) lo rehace quien lo abrió: el Lobby reparte sus
-- apartados en columnas después de construirlo.
function SettingsPanel.build(parent: Instance, context: Context): Frame
	local player = Players.LocalPlayer
	local root = Instance.new("Frame")
	root.Name = "SettingsPanel"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, -10, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = root

	local refreshLayout = buildLayoutChoice(section(root, 0))
	local preview = buildPreview(root, player, context)
	local stats = section(root, 2)
	local function refreshStats()
		for _, child in stats:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		fillStats(stats, player, context)
	end
	refreshStats()
	local stopWatching = if context == "Island" then watchStats(player, refreshStats) else nil
	local refreshOptions = buildOptions(section(root, 3))
	buildControls(section(root, 4))
	local refreshShake = buildShake(section(root, 5))

	-- Al cambiar algo de los efectos de cómic se enseña uno al momento (un crítico, que siempre sale).
	local shownComic = ""
	local function apply(values: Settings.Values)
		preview.setLayout(values.textLayout)
		refreshLayout(values)
		refreshOptions(values)
		refreshShake(values)
		local comic = `{values.comicFx}/{values.comicLevel}/{values.comicSize}`
		if shownComic ~= "" and comic ~= shownComic then
			preview.showComic("Crit")
		end
		shownComic = comic
	end
	apply(Settings.get())
	local connection = Settings.onChanged(apply)
	root.Destroying:Connect(function()
		connection:Disconnect()
		preview.stop()
		if stopWatching then
			stopWatching()
		end
	end)
	return root
end

return SettingsPanel
