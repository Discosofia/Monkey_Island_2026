--!strict
-- Panel de Ajustes (Lobby: pestaña "Ajustes"; Isla: botón ⚙️). De arriba abajo:
--   1. Tu personaje: tu avatar girando con su armadura y su arma en la mano (con tu mascota al lado),
--      números de ejemplo en la disposición elegida y, de vez en cuando, un estallido de cómic del
--      tamaño elegido, para ver cómo quedará cada opción antes de elegirla (UI/CombatTextColumn,
--      UI/ComicBurst).
--   2. Tus números de combate: el arma que cuenta, su daño (con las ventajas del rol y los talentos)
--      y su probabilidad de crítico (Shared/Crit, los mismos números con que juega el servidor), el
--      daño o la curación de tus 5 habilidades, tus dos combos y lo que aporta tu mascota.
--      En la Isla cuenta el arma de la mano o la mejor de la mochila; en el Lobby, la inicial del rol.
--   3. Opciones: disposición de los números, ajustes sí/no y efectos de cómic (Shared/Settings, se
--      guardan en el perfil).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combos = require(ReplicatedStorage.Shared.Data.Combos)
local Config = require(ReplicatedStorage.Shared.Config)
local Crit = require(ReplicatedStorage.Shared.Crit)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Perks = require(ReplicatedStorage.Shared.Data.Perks)
local PetModels = require(ReplicatedStorage.Shared.PetModels)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local CombatTextColumn = require(script.Parent.CombatTextColumn)
local ComicBurst = require(script.Parent.ComicBurst)
local Widgets = require(script.Parent.Widgets)

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

-- Qué número de Config.Abilities enseña cada habilidad y qué ventajas (Data/Perks) lo multiplican.
type AbilityInfo = { amount: string, perks: { string }, heal: boolean?, note: string? }
local ABILITY_INFO: { [string]: AbilityInfo } = {
	Whirlwind = { amount = "WhirlwindDamage", perks = { "MeleeDamage" }, note = "por golpe" },
	Charge = { amount = "ChargeDamage", perks = { "MeleeDamage", "ChargeDamage" } },
	Quake = { amount = "QuakeDamage", perks = { "MeleeDamage" } },
	MultiShot = { amount = "MultiShotDamage", perks = { "RangedDamage" }, note = "por flecha" },
	Trap = { amount = "TrapDamage", perks = { "RangedDamage" } },
	ArrowRain = { amount = "RainDamage", perks = { "RangedDamage", "RainDamage" }, note = "por golpe" },
	Fireball = { amount = "FireballDamage", perks = { "SpellDamage", "FireballDamage" } },
	FrostNova = { amount = "NovaDamage", perks = { "SpellDamage" } },
	ChainLightning = { amount = "ChainDamage", perks = { "SpellDamage" } },
	AreaHeal = { amount = "AreaHealAmount", perks = { "HealPower" }, heal = true },
	HealingDart = { amount = "DartHeal", perks = { "HealPower" }, heal = true },
	HealingTotem = { amount = "TotemHealPerSecond", perks = { "HealPower" }, heal = true, note = "por segundo" },
	Smash = { amount = "SmashDamage", perks = { "MeleeDamage", "SmashDamage" } },
	PiercingShot = { amount = "PierceDamage", perks = { "RangedDamage", "PierceDamage" }, note = "por mono" },
	Meteor = { amount = "MeteorDamage", perks = { "SpellDamage" } },
	SleepPowder = { amount = "PowderDamage", perks = {}, note = "y duerme" },
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

type PerkGetter = (name: string) -> number

local function roleOf(player: Player, context: Context): string
	return Progression.validRole(player:GetAttribute(if context == "Island" then "Role" else "SelectedRole"))
end

local function activePet(player: Player): string?
	local petId = player:GetAttribute("ActivePet")
	return if typeof(petId) == "string" and Pets[petId] then petId else nil
end

-- Ventajas del jugador: en la Isla, las publicadas; en el Lobby, las de su rol, talentos y mejoras.
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

local function abilityLine(ability: Roles.Ability, perk: PerkGetter): string
	local info = ABILITY_INFO[ability.id]
	if ability.id == "LeafShield" then
		return `{ability.name}: escudo de {math.round(perk("ShieldAmount"))}`
	elseif not info then
		return ability.name
	end
	local amount = (Config.Abilities :: any)[info.amount] :: number
	if not info.heal then
		amount *= Config.Combat.PlayerDamageMultiplier
	end
	for _, name in info.perks do
		amount *= perk(name)
	end
	local verb = if info.heal then "cura" else "daño"
	local note = if info.note then ` {info.note}` else ""
	return `{ability.name}: {verb} {math.round(amount)}{note}`
end

local function fillStats(parent: Frame, player: Player, context: Context)
	local roleId = roleOf(player, context)
	local role = Roles[roleId]
	local perk = perkGetter(player, context)
	local critPercent = Crit.percent(Crit.MULTIPLIER - 1)
	heading(parent, `{role.icon} Tus números de combate ({role.name})`, 1)

	local weaponId, chance = weaponOf(player, context)
	local weapon = if weaponId then Weapons[weaponId] else nil
	if weapon then
		local damage = math.round(weapon.damage * perk(weaponPerk(weapon)) * Config.Combat.PlayerDamageMultiplier)
		text(
			parent,
			`⚔️ <b>{weapon.name}</b>: {damage} de daño · <font color="#ffdc5a">{Crit.percent(chance)} de crítico</font> (+{critPercent} de daño)`,
			2
		)
		if chance < BEST_FORGE_CHANCE then
			text(
				parent,
				`⬆️ Las mejoras de la forja suben el crítico de tus armas hasta un {Crit.percent(BEST_FORGE_CHANCE)}.`,
				3,
				SOFT_COLOR
			)
		end
	end
	if roleId == "Medico" then
		local normal = Crit.percent(Crit.healChance(chance, 1))
		local save = Crit.percent(Crit.healChance(chance, 0))
		local threshold = Crit.percent(Config.Crit.SaveThreshold)
		text(parent, `💚 Curación crítica: {normal}; {save} si el aliado tiene menos del {threshold} de vida`, 4)
	end
	local lines = {}
	for _, ability in role.abilities do
		table.insert(lines, abilityLine(ability, perk))
	end
	text(parent, `✨ Habilidades (crítico {Crit.percent(chance)}): {table.concat(lines, " · ")}`, 5)

	local combos = Combos[roleId] or {}
	local comboLines = {}
	for _, combo in combos do
		local names = {}
		for _, stepId in combo.steps do
			for _, ability in role.abilities do
				if ability.id == stepId then
					table.insert(names, ability.name)
				end
			end
		end
		local extra = if combo.damageBonus then ` con +{math.round(combo.damageBonus * 100)} % de daño` else ""
		table.insert(
			comboLines,
			`🔗 Combo «{combo.name}»: {table.concat(names, " → ")}. Los pasos 2 y 3 hacen críticos seguros{extra} a lo que lleva {combo.icon}. {combo.finisher}`
		)
	end
	if #combos >= 2 then
		table.insert(
			comboLines,
			"⛓️ Conexión: al cerrar un combo, el otro queda abierto; sigue con su paso 2 sin hacer el 1."
		)
	end
	if #comboLines > 0 then
		text(parent, table.concat(comboLines, "\n"), 6, SOFT_COLOR)
	end

	local petId = activePet(player)
	local pet = if petId then Pets[petId] else nil
	if pet then
		local rarity = Rarities[pet.rarity]
		local help = {}
		local seconds = Config.Pets.TickSeconds
		if pet.attackDamage then
			table.insert(help, `{pet.attackDamage} de daño cada {seconds} s`)
		end
		if pet.healPerTick then
			table.insert(help, `cura {pet.healPerTick} cada {seconds} s`)
		end
		local helpText = if #help > 0
			then table.concat(help, " y ")
			else "te ayuda de otra forma (carga, rastreo o apoyo)"
		text(
			parent,
			`🐾 {pet.icon} <b>{pet.name}</b> ({rarity.name}): {helpText} · {Crit.percent(Config.Crit.PetChance)} de crítico`,
			7
		)
	else
		text(parent, "🐾 Sin mascota: los huevos de la isla te dan una.", 7, SOFT_COLOR)
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
		local note = Widgets.label("Tu personaje aparecerá aquí", holder)
		note.Size = UDim2.fromScale(0.6, 0.12)
		note.AnchorPoint = Vector2.new(0.5, 0.5)
		note.Position = UDim2.fromScale(0.5, 0.5)
	end

	local petId = activePet(player)
	local petModel = if petId then PetModels.build(petId) else nil
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
		screenHint.Text = if layout == "Screen" then "↔ fijos en la pantalla" else ""
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
		local life = ComicBurst.play(frame, chosen, ComicBurst.word(chosen), pixels)
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
				columns.loot:push(`+{lootTotal} {item.icon} {item.name}`, { color = TEXT_COLOR, key = itemId })
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
	{ key = "showNumbers", label = "Números de daño y curación" },
	{ key = "allyNumbers", label = "Daño de los aliados (tenue)" },
	{ key = "showLoot", label = "Lo que recoges (+2 🌲 Madera)" },
	{ key = "showCombo", label = "Combos y racha" },
	{ key = "music", label = "Música (tecla M)" },
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
		local option = button(row, names[choice])
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
	local name = text(line, label, 1)
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
	heading(parent, "📍 Dónde salen tus números", 1)
	text(
		parent,
		"Rojo a la izquierda: daño que recibes. Verde a la derecha: curaciones; debajo, lo que recoges.",
		2,
		SOFT_COLOR
	)
	local refreshLayout = choiceRow(parent, 3, "textLayout", Settings.LAYOUTS, Settings.LAYOUT_NAMES)
	text(parent, "Letra de los números", 4, SOFT_COLOR)
	local refreshFont = choiceRow(parent, 5, "numberFont", Settings.NUMBER_FONTS, Settings.NUMBER_FONT_NAMES)
	return function(values: Settings.Values)
		refreshLayout(values)
		refreshFont(values)
	end
end

local function buildOptions(parent: Frame): (values: Settings.Values) -> ()
	heading(parent, "⚙️ Opciones", 4)
	local toggleButtons: { [string]: TextButton } = {}
	for index, toggle in TOGGLES do
		toggleButtons[toggle.key] = toggleLine(parent, 4 + index, toggle.key, toggle.label)
	end

	heading(parent, "💥 Efectos de cómic", 20)
	text(
		parent,
		"Estallidos al golpear (BAM!), en los críticos (POW!), al derribar (K.O.!) y cuando te pegan fuerte (OUCH!).",
		21,
		SOFT_COLOR
	)
	toggleButtons.comicFx = toggleLine(parent, 22, "comicFx", "Efectos de cómic")
	text(parent, "Cuáles: todos, o solo críticos, K.O. y golpes fuertes que recibes", 23, SOFT_COLOR)
	local refreshLevel = choiceRow(parent, 24, "comicLevel", Settings.COMIC_LEVELS, Settings.COMIC_LEVEL_NAMES)
	text(parent, "Tamaño", 25, SOFT_COLOR)
	local refreshSize = choiceRow(parent, 26, "comicSize", Settings.COMIC_SIZES, Settings.COMIC_SIZE_NAMES)

	return function(values: Settings.Values)
		refreshLevel(values)
		refreshSize(values)
		for key, switch in toggleButtons do
			local on = (values :: any)[key] == true
			switch.Text = if on then "Sí" else "No"
			paint(switch, on)
		end
	end
end

-- Construye el panel dentro de "parent" (que debe poder desplazarse si no cabe). Se limpia solo al
-- destruirse.
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
	fillStats(section(root, 2), player, context)
	local refreshOptions = buildOptions(section(root, 3))

	-- Al cambiar algo de los efectos de cómic se enseña uno al momento (un crítico, que siempre sale).
	local shownComic = ""
	local function apply(values: Settings.Values)
		preview.setLayout(values.textLayout)
		refreshLayout(values)
		refreshOptions(values)
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
	end)
	return root
end

return SettingsPanel
