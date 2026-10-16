--!strict
-- Órdenes del panel de pruebas en la Isla (solo Studio; en el juego publicado se ignoran).
-- Sirven para verificar cada entrega sin esperar días de partida (docs/VERIFICACION.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Armor = require(ReplicatedStorage.Shared.Data.Armor)
local Beacon = require(ReplicatedStorage.Shared.Beacon)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Sounds = require(ReplicatedStorage.Shared.Data.Sounds)
local Survival = require(ReplicatedStorage.Shared.Survival)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local BasecampService = require(script.Parent.BasecampService)
local BossService = require(script.Parent.BossService)
local EggService = require(script.Parent.EggService)
local InventoryService = require(script.Parent.InventoryService)
local LifeService = require(script.Parent.LifeService)
local MatchService = require(script.Parent.MatchService)
local MonkeyService = require(script.Parent.MonkeyService)
local RoleService = require(script.Parent.RoleService)
local SiegeService = require(script.Parent.SiegeService)
local SupplyService = require(script.Parent.SupplyService)
local WeatherService = require(script.Parent.WeatherService)
local ArmorModels = require(script.Parent.Parent.Combat.ArmorModels)
local Hazards = require(script.Parent.Parent.Combat.Hazards)
local MonkeyModels = require(script.Parent.Parent.Monkeys.MonkeyModels)

local DebugService = {}

local nextBoss = 1

-- Orden del expositor: cada arma seguida de sus mejoras; las que falten van al final.
local SHOWCASE_ORDER = {
	"Machete",
	"SharpMachete",
	"Honda",
	"LianaSling",
	"WoodenAxe",
	"StoneAxe",
	"BoneAxe",
	"WoodenPick",
	"StonePick",
	"BonePick",
	"Torch",
	"Spear",
	"Club",
	"BigFangClub",
	"StoneClub",
	"BoneMace",
	"ThickBoneMaul",
	"Bow",
	"ReinforcedBow",
	"LianaBow",
	"MagicStaff",
	"GoldenStaff",
	"SilverStaff",
	"Blowgun",
	"BoneBlowgun",
	"ShamanBlowgun",
}
local SHOWCASE_RADIUS = 11

-- Cartel con el nombre encima de un modelo del expositor, a "height" studs del suelo.
local function showcaseLabel(anchor: BasePart, text: string, height: number)
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(170, 26)
	label.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	label.MaxDistance = 150
	label.Parent = anchor
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.BuilderSansBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.3
	textLabel.Text = text
	textLabel.Parent = label
end

-- Todas las armas en círculo alrededor del jugador, de pie, de perfil (el filo a un lado) y con su
-- nombre encima, para revisar los modelos de WeaponTools. Pulsar otra vez las quita.
local function weaponShowcase(player: Player)
	local existing = Workspace:FindFirstChild("DebugWeaponShowcase")
	if existing then
		existing:Destroy()
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local ids = table.clone(SHOWCASE_ORDER)
	for weaponId in Weapons do
		if not table.find(ids, weaponId) then
			table.insert(ids, weaponId)
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "DebugWeaponShowcase"
	local center = character:GetPivot().Position
	for index, weaponId in ids do
		local tool = WeaponTools.build(weaponId)
		local model = Instance.new("Model")
		model.Name = tool.Name
		for _, child in tool:GetChildren() do
			if child:IsA("BasePart") then
				child.Anchored = true
				child.Parent = model
			end
		end
		local handle = model:FindFirstChild("Handle") :: BasePart
		model.PrimaryPart = handle
		local angle = (index - 1) / #ids * math.pi * 2
		local position = center + Vector3.new(math.sin(angle), 0, math.cos(angle)) * SHOWCASE_RADIUS
		local facing = Vector3.new(center.X, position.Y, center.Z)
		-- De perfil: su -X mira al jugador, así el filo (-Z) queda a un lado.
		model:PivotTo(CFrame.lookAt(position, facing) * CFrame.Angles(0, -math.rad(90), 0))

		showcaseLabel(handle, model.Name, 3.6)

		model.Parent = folder
		tool:Destroy()
	end
	folder.Parent = Workspace
end

local MONKEY_ROW_START = 12 -- de la primera fila (categoría 1) al jugador
local MONKEY_ROW_STEP = 9 -- entre una fila de monos y la siguiente
local BOSS_ROW_EXTRA = 6 -- los jefes, más grandes, un poco más separados de la última fila
local MONKEY_GAP = 3

-- Todos los monos en filas delante del jugador, como en una foto de grupo: una fila por categoría
-- (los pequeños delante) y los jefes al fondo. Quietos en su postura de reposo, mirándolo,
-- apoyados en el suelo y con su nombre y su alto encima, para revisar los modelos de
-- Monkeys/MonkeyModels. Pulsar otra vez los quita.
local function monkeyShowcase(player: Player)
	local existing = Workspace:FindFirstChild("DebugMonkeyShowcase")
	if existing then
		existing:Destroy()
		return
	end
	local character = player.Character
	if not character then
		return
	end

	local species = {}
	for speciesId in Monkeys do
		table.insert(species, speciesId)
	end
	table.sort(species, function(a, b)
		if Monkeys[a].tier ~= Monkeys[b].tier then
			return Monkeys[a].tier < Monkeys[b].tier
		end
		return Monkeys[a].name < Monkeys[b].name
	end)
	local rows: { { distance: number, models: { Model } } } = {}
	local tierRows: { [number]: { distance: number, models: { Model } } } = {}
	for _, speciesId in species do
		local tier = Monkeys[speciesId].tier
		local row = tierRows[tier]
		if not row then
			row = { distance = MONKEY_ROW_START + #rows * MONKEY_ROW_STEP, models = {} }
			tierRows[tier] = row
			table.insert(rows, row)
		end
		table.insert(row.models, MonkeyModels.build(speciesId, Monkeys[speciesId], Vector3.zero))
	end
	-- Los jefes, en el orden en que salen en la partida y montados como en BossService.
	local bossRow = { distance = MONKEY_ROW_START + #rows * MONKEY_ROW_STEP + BOSS_ROW_EXTRA, models = {} }
	table.insert(rows, bossRow)
	for _, bossId in Config.Match.BossRotation do
		local boss = Bosses[bossId]
		local look = table.clone(Monkeys[boss.baseSpecies])
		look.name, look.scale = boss.name, boss.scale
		look.bodyColor, look.faceColor = boss.bodyColor, boss.faceColor
		table.insert(bossRow.models, MonkeyModels.build(boss.baseSpecies, look, Vector3.zero, bossId))
	end

	local folder = Instance.new("Folder")
	folder.Name = "DebugMonkeyShowcase"
	folder.Parent = Workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, character }

	local pivot = character:GetPivot()
	local forward = (pivot.LookVector * Vector3.new(1, 0, 1)).Unit
	local right = forward:Cross(Vector3.yAxis)
	for _, row in rows do
		local sizes = {}
		local total = 0
		for index, model in row.models do
			local _, size = model:GetBoundingBox()
			sizes[index] = size
			total += size.X + MONKEY_GAP
		end
		local offset = -total / 2
		for index, model in row.models do
			local size = sizes[index]
			local spot = pivot.Position + forward * row.distance + right * (offset + size.X / 2)
			offset += size.X + MONKEY_GAP
			local hit = Workspace:Raycast(spot + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
			local ground = if hit then hit.Position else Vector3.new(spot.X, pivot.Position.Y - 3, spot.Z)
			-- Se construyeron con el suelo en Y = 0: la raíz queda a la misma altura sobre el suelo real,
			-- y la cara (-Z) mira al jugador.
			local root = model.PrimaryPart :: BasePart
			local rootPosition = ground + Vector3.new(0, root.Position.Y, 0)
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
			model:PivotTo(CFrame.lookAt(rootPosition, rootPosition - forward))
			showcaseLabel(
				root,
				`{model.Name} · {string.format("%.1f", size.Y)} studs`,
				size.Y - (rootPosition.Y - ground.Y) + 1.5
			)
			model.Parent = folder
		end
	end
end

-- Armaduras por las que va pasando "Siguiente armadura" (nil = ninguna).
local ARMOR_CYCLE = { "FurVest", "BoneArmor", "SilverArmor" }

-- Pone la siguiente armadura (o ninguna, tras la última) para ver sus modelos (Combat/ArmorModels).
local function nextArmor(player: Player)
	local current = player:GetAttribute("Armor")
	local index = if typeof(current) == "string" then table.find(ARMOR_CYCLE, current) else nil
	local armorId = ARMOR_CYCLE[(index or 0) + 1]
	player:SetAttribute("Armor", armorId)
	local character = player.Character
	if not character then
		return
	end
	if armorId then
		ArmorModels.wear(character, armorId)
	else
		local piece = character:FindFirstChild("ArmorPiece")
		if piece then
			piece:Destroy()
		end
	end
	Remotes.Notify:FireClient(player, `🛡️ {if armorId then Armor[armorId].name else "Sin armadura"}`)
end

local COMMANDS: { [string]: (player: Player) -> () } = {
	Materials = function(player)
		for itemId in Items do
			InventoryService.add(player, itemId, 50)
		end
	end,
	NextRole = function(player)
		RoleService.debugNextRole(player)
	end,
	Abilities = function(player)
		for slot = 1, 4 do
			player:SetAttribute(`AbilityReadyAt{slot}`, nil)
		end
	end,
	Heal = function(player)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
		player:SetAttribute(Survival.HUNGER, Survival.MAX)
		player:SetAttribute(Survival.THIRST, Survival.MAX)
		player:SetAttribute(Survival.FEVER, 0)
	end,
	-- Caído o Espíritu: de vuelta a la vida ya, sin esperar a un aliado ni a la reaparición.
	Revive = function(player)
		if not LifeService.debugRevive(player) then
			Remotes.Notify:FireClient(player, "💚 Ya estás vivo: sirve cuando estás Caído o eres Espíritu")
		end
	end,
	WeaponShowcase = weaponShowcase,
	MonkeyShowcase = monkeyShowcase,
	NextArmor = nextArmor,
	Hungry = function(player)
		player:SetAttribute(Survival.HUNGER, 10)
		player:SetAttribute(Survival.THIRST, 10)
	end,
	Fever = function(player)
		player:SetAttribute(Survival.FEVER, 90)
	end,
	Boss = function()
		local rotation = Config.Match.BossRotation
		BossService.spawn(rotation[(nextBoss - 1) % #rotation + 1])
		nextBoss += 1
	end,
	BossHurt = function()
		for _, model in Workspace:GetChildren() do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if model:GetAttribute("Boss") ~= nil and humanoid then
				humanoid.Health = humanoid.MaxHealth * 0.3
			end
		end
	end,
	-- Un mono de categoría 2 que va a por ti: para ver sus críticos (números rojos más grandes).
	Mandrill = function(player)
		local character = player.Character
		if not character then
			return
		end
		-- Delante del jugador; si ahí no puede aparecer (Basecamp, agua, una pieza), más lejos y a
		-- los lados. No cuenta para el límite de monos a la vez.
		local pivot = character:GetPivot()
		for _, distance in { 20, 35, 50, 70, 95, 120 } do
			for _, angle in { 0, 45, -45, 90, -90, 180 } do
				local spot = (pivot * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -distance)).Position
				if MonkeyService.spawnAmbush("Mandril", spot, 1, player, true) > 0 then
					if BasecampService.isInside(pivot.Position) then
						Remotes.Notify:FireClient(
							player,
							"🐒 Mandril en camino. Estás en el Basecamp: aquí no te puede hacer daño, sal para probar"
						)
					end
					return
				end
			end
		end
		Remotes.Notify:FireClient(player, "🐒 No hay sitio para el mandril cerca: prueba fuera del Basecamp")
	end,
	-- Todo golpe y curación es crítico (Shared/Crit), para ver los números grandes al momento.
	AlwaysCrit = function(player)
		local enabled = Workspace:GetAttribute("DebugAlwaysCrit") ~= true
		Workspace:SetAttribute("DebugAlwaysCrit", enabled)
		Remotes.Notify:FireClient(player, if enabled then "🎯 Críticos al 100 %" else "🎯 Críticos normales")
	end,
	Egg = function()
		EggService.spawnEgg()
	end,
	HatchNow = function(player)
		if not EggService.hatchNow() then
			Remotes.Notify:FireClient(player, "Primero lleva un huevo al nido")
		end
	end,
	Crate = function()
		SupplyService.spawnCrate()
	end,
	Pet = function(player)
		local current = player:GetAttribute("ActivePet")
		local petId = PetRoll.after(if typeof(current) == "string" then current else nil)
		player:SetAttribute("ActivePet", petId)
		RoleService.refreshPerks(player)
		Remotes.Notify:FireClient(player, `🐾 Mascota de prueba: {Pets[petId].icon} {Pets[petId].name}`)
	end,
	Rain = function()
		ReplicatedStorage:SetAttribute("Weather", "Rain")
	end,
	Storm = function()
		ReplicatedStorage:SetAttribute("Weather", "Storm")
	end,
	Clear = function()
		ReplicatedStorage:SetAttribute("Weather", "Clear")
	end,
	Eruption = function()
		WeatherService.erupt()
	end,
	Lightning = function(player)
		local character = player.Character
		if character then
			Hazards.lightning(
				(character:GetPivot() * CFrame.new(0, 0, -14)).Position,
				Config.Weather.LightningDamage,
				5,
				1.5
			)
			ReplicatedStorage:SetAttribute("LightningAt", Workspace:GetServerTimeNow() + 1.5)
		end
	end,
	LavaBomb = function(player)
		local character = player.Character
		if character then
			local pivot = character:GetPivot()
			local origin = (pivot * CFrame.new(0, 40, 60)).Position
			for i = 1, 3 do
				Hazards.lavaBomb(
					(pivot * CFrame.new((i - 2) * 10, 0, -16)).Position,
					Config.Weather.LavaBombDamage,
					7,
					1.4 + i * 0.4,
					origin
				)
			end
		end
	end,
	GreatTroop = function()
		SiegeService.debugGreatTroop()
	end,
	Sounds = function(player)
		local keys = {}
		for key in Sounds.Effects do
			table.insert(keys, key)
		end
		table.sort(keys)
		task.spawn(function()
			for _, key in keys do
				local character = player.Character
				if not character then
					return
				end
				Remotes.Notify:FireClient(player, `🔊 {key}`)
				Sfx.play(key, character:GetPivot().Position)
				task.wait(1.6)
			end
		end)
	end,
	Beacon = function(player)
		for bossId in Bosses do
			Beacon.add(bossId)
		end
		ReplicatedStorage:SetAttribute("DebugBeaconUnlocked", true)
		Remotes.Notify:FireClient(player, "📡 Tienes las 4 piezas y la baliza se puede encender ya (de día)")
	end,
	Defeat = function()
		MatchService.endMatch("Defeat")
	end,
}

function DebugService:Start()
	if not RunService:IsStudio() then
		return
	end
	Remotes.DebugCommand.OnServerEvent:Connect(function(player: Player, command: any)
		local handler = if typeof(command) == "string" then COMMANDS[command] else nil
		if handler then
			handler(player)
		end
	end)
	print("[DebugService] Panel de pruebas activo (solo Studio).")
end

return DebugService
