--!strict
-- Monos (GDD §8, Fase 1.4): grupos repartidos por la selva, IA por estados, aullidos y botín.
--
-- Estados de cada mono:
--   Idle   → deambula cerca de su zona. Si un jugador se acerca, pasa a Chase.
--   Chase  → lo persigue y le ataca cuando está a su alcance.
--   Flee   → huye cuando le queda poca vida (si su especie huye).
--   Return → vuelve a su zona si el jugador escapa, entra al Basecamp o se aleja demasiado.
-- Los monos sin jugadores cerca "duermen" para ahorrar rendimiento.
-- Fase 2.4: los capuchinos roban en vez de morder y huyen con lo robado (se recupera al derrotarlos).
-- Las especies con "fearsFire" se apartan de antorchas y hogueras.
-- Fase 4: zonas por bioma, alfas (si mueren, la tropa huye), saltos, rugidos, piedras, agarres,
-- golpes en área y un límite de monos activos (Config.Monkeys.MaxActive).
-- Fase 2.5: los grupos de asedio (SiegeService) van hacia un portón y luego al centro del Basecamp;
-- atacan las piezas que les cierran el paso y a los jugadores, también dentro del Basecamp.
-- Al amanecer se repueblan los grupos; los monos de día se retiran de noche (y viceversa).
-- Además, un grupo con bajas recupera un mono cada cierto tiempo si no hay jugadores cerca de su
-- zona (Config.Monkeys.GroupRegrowSeconds): la selva nunca se queda vacía.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MatchStats = require(ReplicatedStorage.Shared.MatchStats)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Building = require(ReplicatedStorage.Shared.Building)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local BasecampService = require(script.Parent.BasecampService)
local BuildingService = require(script.Parent.BuildingService)
local CombatService = require(script.Parent.CombatService)
local DayNightService = require(script.Parent.DayNightService)
local InventoryService = require(script.Parent.InventoryService)
local Poof = require(script.Parent.Parent.Combat.Poof)
local Status = require(script.Parent.Parent.Combat.Status)
local MonkeyAnimator = require(script.Parent.Parent.Monkeys.MonkeyAnimator)
local MonkeyModels = require(script.Parent.Parent.Monkeys.MonkeyModels)

-- Materiales de terreno donde pueden aparecer (selva, no playa, roca ni agua).
local SPAWN_MATERIALS: { [Enum.Material]: boolean } = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Mud] = true,
}
local WANDER_RADIUS = 20
local HOME_REACHED_DISTANCE = 8

type State = "Idle" | "Chase" | "Flee" | "Return"

type Group = {
	speciesId: string,
	home: Vector3,
	size: number,
	temporary: boolean, -- refuerzos de un aullido: no se repueblan
	members: { Monkey },
	nextRegrowAt: number, -- os.clock() a partir del cual puede recuperar un mono
	siege: boolean?, -- grupo del asedio nocturno
	gate: Vector3?, -- portón por el que entra el grupo de asedio
	alpha: Monkey?, -- líder de la tropa (especies con "alpha")
}

type Monkey = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	definition: Monkeys.MonkeyDefinition,
	group: Group,
	state: State,
	target: Player?,
	lastAttackAt: number,
	nextWanderAt: number,
	howled: boolean,
	stuckSince: number?,
	damage: number, -- daño ya ajustado a la dificultad del día
	stolen: { itemId: string, amount: number }?,
	scaredUntil: number,
	passedGate: boolean,
	pounceReadyAt: number,
	pounced: boolean, -- el siguiente golpe hace el doble
	roarReadyAt: number,
	throwReadyAt: number,
	stompReadyAt: number,
}

type PlayerInfo = { player: Player, position: Vector3, safe: boolean, hasTorch: boolean }

local MonkeyService = {}

local monkeys: { [Model]: Monkey } = {}
local killListeners: { (player: Player, speciesId: string) -> () } = {}
local groups: { Group } = {}
local rng = Random.new()
local folder: Folder? = nil

local function monkeyFolder(): Folder
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "Monos"
		newFolder.Parent = Workspace
		folder = newFolder
	end
	return folder :: Folder
end

-- Suelo bajo un punto, o nil si ahí hay agua, un árbol, el Basecamp… "materials" dice qué terreno
-- vale (nil = cualquiera menos agua y lava).
local function findGround(position: Vector3, materials: { [Enum.Material]: boolean }?): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { monkeyFolder() }
	local result = Workspace:Raycast(Vector3.new(position.X, 400, position.Z), Vector3.new(0, -800, 0), params)
	if not result then
		return nil
	end
	local material = result.Material
	local allowed = if materials
		then materials[material] == true
		else material ~= Enum.Material.Water and material ~= Enum.Material.CrackedLava
	local onTerrain = result.Instance == Workspace.Terrain and allowed
	-- En un place de pruebas sin terreno, vale la Baseplate.
	local onBaseplate = result.Instance.Name == "Baseplate"
	if not (onTerrain or onBaseplate) or BasecampService.isInside(result.Position) then
		return nil
	end
	return result.Position
end

local BEACH_MATERIALS = { [Enum.Material.Sand] = true }

-- Guarida de un bioma (MapBuilder la crea en GuaridasJefes), o nil si el mapa no la tiene.
local function biomeAnchor(zone: string): Vector3?
	local marker = Workspace:FindFirstChild(`Guarida_{zone}`, true)
	return if marker and marker:IsA("BasePart") then marker.Position else nil
end

-- Busca dónde poner un grupo según la zona de su especie (ver Data/Monkeys).
local function randomHome(definition: Monkeys.MonkeyDefinition): Vector3?
	local center = BasecampService.getCenter()
	local zone = definition.zone or "Selva"
	local origin = center
	local minDistance = Config.Monkeys.SpawnMinDistance
	local maxDistance = Config.Monkeys.SpawnMaxDistance
	local materials: { [Enum.Material]: boolean }? = SPAWN_MATERIALS
	if zone == "Playa" then
		minDistance, maxDistance, materials =
			Config.Monkeys.SpawnMaxDistance * 0.6, Config.Monkeys.SpawnMaxDistance * 1.4, BEACH_MATERIALS
	elseif zone == "Basecamp" then
		minDistance, maxDistance = Config.Monkeys.SpawnMinDistance - 20, Config.Monkeys.SpawnMinDistance + 110
	elseif zone ~= "Selva" then
		local anchor = biomeAnchor(zone)
		if anchor then
			origin, minDistance, maxDistance, materials = anchor, 20, Config.Monkeys.BiomeRadius, nil
		end
	end
	for _ = 1, 80 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = rng:NextNumber(minDistance, maxDistance)
		local ground = findGround(origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance, materials)
		if ground then
			return ground
		end
	end
	-- Sin sitio en su zona (mapa de pruebas): cualquier selva.
	if zone ~= "Selva" then
		return randomHome(Monkeys.MonoArdilla)
	end
	return nil
end

local function showBubble(monkey: Monkey, text: string)
	local head = monkey.model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(110, 40)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 120, 80)
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Parent = billboard
	Debris:AddItem(billboard, 1.5)
end

-- Voz del mono según su tamaño (Data/Sounds: MonkeyVoices): "Attack", "Call" o "Hurt".
local function playVoice(monkey: Monkey, action: string, at: (Vector3 | Instance)?)
	Sfx.play(`Monkey{monkey.definition.voice}{action}`, at or monkey.root)
end

local function giveLoot(player: Player, definition: Monkeys.MonkeyDefinition)
	local gained = {}
	for _, entry in definition.loot do
		if rng:NextNumber() < entry.chance then
			local amount = rng:NextInteger(entry.min, entry.max)
			InventoryService.add(player, entry.itemId, amount)
			local item = Items[entry.itemId]
			table.insert(gained, `+{amount} {item.icon} {item.name}`)
		end
	end
	if #gained > 0 then
		Remotes.Notify:FireClient(player, `{definition.name}: {table.concat(gained, ", ")}`)
	end
end

local function removeFromGroup(monkey: Monkey)
	local members = monkey.group.members
	local index = table.find(members, monkey)
	if index then
		table.remove(members, index)
	end
end

local function onDied(monkey: Monkey)
	if not monkeys[monkey.model] then
		return
	end
	monkeys[monkey.model] = nil
	removeFromGroup(monkey)
	playVoice(monkey, "Hurt", monkey.root.Position)
	-- La espera para recuperar un mono empieza con la primera baja.
	local group = monkey.group
	group.nextRegrowAt = math.max(group.nextRegrowAt, os.clock() + Config.Monkeys.GroupRegrowSeconds)

	-- Sin su alfa, la tropa huye.
	if group.alpha == monkey then
		group.alpha = nil
		for _, member in group.members do
			member.state = "Flee"
			member.target = nil
			showBubble(member, "😱")
		end
	end

	local killerId = monkey.model:GetAttribute("LastAttackerUserId")
	local killer = if typeof(killerId) == "number" then Players:GetPlayerByUserId(killerId) else nil
	if killer then
		for _, listener in killListeners do
			task.spawn(listener, killer, monkey.model:GetAttribute("MonkeyType") :: string)
		end
		MatchStats.add(killer, MatchStats.KILLS)
		giveLoot(killer, monkey.definition)
		local stolen = monkey.stolen
		if stolen then
			InventoryService.add(killer, stolen.itemId, stolen.amount)
			local item = Items[stolen.itemId]
			Remotes.Notify:FireClient(killer, `Recuperas lo robado: {stolen.amount} {item.icon} {item.name}`)
		end
	end

	-- "¡Puf!" de caricatura: el mono desaparece en una nube de humo con estrellas (sin caerse muerto).
	MonkeyAnimator.die(monkey.model)
	Poof.vanish(monkey.model)
end

local onHurt: (monkey: Monkey, health: number) -> ()
local bite: (monkey: Monkey, player: Player) -> ()
local pounce: (monkey: Monkey, target: Vector3, now: number) -> ()
local roar: (monkey: Monkey, infos: { PlayerInfo }, now: number) -> ()
local throwStone: (monkey: Monkey, info: PlayerInfo, now: number) -> ()
local stomp: (monkey: Monkey, infos: { PlayerInfo }, now: number) -> ()

local function activeCount(): number
	local count = 0
	for _ in monkeys do
		count += 1
	end
	return count
end

-- El alfa: más vida y daño, y una corona sobre la cabeza.
local function makeAlpha(monkey: Monkey)
	monkey.group.alpha = monkey
	monkey.humanoid.MaxHealth *= Config.Monkeys.AlphaHealthMultiplier
	monkey.humanoid.Health = monkey.humanoid.MaxHealth
	monkey.damage = math.round(monkey.damage * Config.Monkeys.AlphaDamageMultiplier)
	monkey.model:SetAttribute("Alpha", true)
	monkey.humanoid.DisplayName = `{monkey.definition.name} alfa`
	local head = monkey.model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local crown = Instance.new("BillboardGui")
		crown.Size = UDim2.fromOffset(40, 40)
		crown.StudsOffset = Vector3.new(0, 2.6, 0)
		crown.MaxDistance = 90
		crown.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "👑"
		label.TextScaled = true
		label.Parent = crown
	end
end

local function spawnMonkey(group: Group, near: Vector3): Monkey?
	local definition = Monkeys[group.speciesId]
	local offset = Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
	local ground = findGround(near + offset, nil) or findGround(near, nil)
	if not ground or (not group.siege and activeCount() >= Config.Monkeys.MaxActive) then
		return nil
	end

	local model = MonkeyModels.spawn(group.speciesId, definition, ground)
	model.Parent = monkeyFolder()
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	-- Dificultad por día (Fase 2.7): más vida y más daño cuanto más avanza la partida.
	local state = MatchState.read()
	local daysPassed = if state then state.day - 1 else 0
	local settings = Config.Difficulty
	local healthMultiplier = math.min(1 + daysPassed * settings.HealthPerDay, settings.MaxMultiplier)
	local damageMultiplier = math.min(1 + daysPassed * settings.DamagePerDay, settings.MaxMultiplier)
	humanoid.MaxHealth = math.round(definition.maxHealth * healthMultiplier)
	humanoid.Health = humanoid.MaxHealth
	-- El servidor controla su física: los clientes no pueden moverlos.
	root:SetNetworkOwner(nil)
	CollectionService:AddTag(model, Config.Combat.EnemyTag)

	local monkey: Monkey = {
		model = model,
		humanoid = humanoid,
		root = root,
		definition = definition,
		group = group,
		state = "Idle",
		target = nil,
		lastAttackAt = 0,
		nextWanderAt = 0,
		howled = false,
		stuckSince = nil,
		damage = math.round(definition.damage * damageMultiplier),
		stolen = nil,
		scaredUntil = 0,
		passedGate = false,
		pounceReadyAt = 0,
		pounced = false,
		roarReadyAt = 0,
		throwReadyAt = 0,
		stompReadyAt = 0,
	}
	monkeys[model] = monkey
	table.insert(group.members, monkey)
	MonkeyAnimator.attach(model)
	if definition.alpha and not group.alpha then
		makeAlpha(monkey)
	end
	humanoid.Died:Connect(function()
		onDied(monkey)
	end)
	local lastHealth = humanoid.Health
	local lastCryAt = 0
	humanoid.HealthChanged:Connect(function(health)
		-- Chillido al recibir un golpe (como mucho uno cada medio segundo).
		local now = os.clock()
		if health > 0 and health < lastHealth and now - lastCryAt > 0.5 then
			lastCryAt = now
			playVoice(monkey, "Hurt")
			MonkeyAnimator.play(model, "Hurt")
		end
		lastHealth = health
		onHurt(monkey, health)
	end)
	return monkey
end

local function fillGroup(group: Group)
	local attempts = 0
	while #group.members < group.size and attempts < group.size * 3 do
		attempts += 1
		spawnMonkey(group, group.home)
	end
end

local function despawnGroup(group: Group)
	for _, monkey in table.clone(group.members) do
		monkeys[monkey.model] = nil
		monkey.model:Destroy()
	end
	table.clear(group.members)
end

local function createGroups()
	for speciesId, definition in Monkeys do
		for _ = 1, definition.groups do
			local home = randomHome(definition)
			if home then
				table.insert(groups, {
					speciesId = speciesId,
					home = home,
					size = rng:NextInteger(definition.groupMin, definition.groupMax),
					temporary = false,
					members = {},
					nextRegrowAt = 0,
				})
			end
		end
	end
	print(`[MonkeyService] {#groups} grupos de monos repartidos por la isla.`)
end

local function isActive(definition: Monkeys.MonkeyDefinition, phase: MatchState.Phase): boolean
	return definition.activeAt == "Both" or definition.activeAt == phase
end

local function onPhaseStarted(_day: number, phase: MatchState.Phase)
	if #groups == 0 then
		createGroups()
	end
	for _, group in groups do
		local definition = Monkeys[group.speciesId]
		if not isActive(definition, phase) then
			despawnGroup(group)
		elseif phase == "Day" or definition.activeAt == phase then
			-- Las especies de día y "Both" se repueblan al amanecer; las nocturnas, al anochecer.
			if not group.temporary then
				fillGroup(group)
			end
		end
	end
	-- Los grupos de refuerzo vacíos ya no hacen falta.
	for index = #groups, 1, -1 do
		if groups[index].temporary and #groups[index].members == 0 then
			table.remove(groups, index)
		end
	end
end

local function chase(monkey: Monkey, player: Player)
	monkey.state = "Chase"
	monkey.target = player
	monkey.stuckSince = nil
end

local function spawnReinforcements(position: Vector3, target: Player)
	local group: Group = {
		speciesId = Config.Monkeys.HowlReinforcementSpecies,
		home = position,
		size = Config.Monkeys.HowlReinforcementCount,
		temporary = true,
		members = {},
		nextRegrowAt = math.huge,
	}
	table.insert(groups, group)
	fillGroup(group)
	for _, monkey in group.members do
		chase(monkey, target)
	end
end

-- El aullador avisa a los monos cercanos y, si sigue vivo y persiguiendo, llegan refuerzos.
local function howl(monkey: Monkey, target: Player)
	monkey.howled = true
	showBubble(monkey, "¡AUUU!")
	playVoice(monkey, "Call")
	MonkeyAnimator.play(monkey.model, "Howl")
	Remotes.Notify:FireClient(target, "🐒 ¡Un aullador está llamando a la tropa!")
	for _, other in monkeys do
		local near = (other.root.Position - monkey.root.Position).Magnitude <= Config.Monkeys.HowlRadius
		if other ~= monkey and other.state == "Idle" and near then
			chase(other, target)
		end
	end
	task.delay(Config.Monkeys.HowlReinforcementSeconds, function()
		if monkeys[monkey.model] and monkey.state == "Chase" and monkey.target == target then
			spawnReinforcements(monkey.root.Position, target)
		end
	end)
end

-- Si le hieren (por ejemplo, con la honda desde lejos), va a por quien le atacó.
function onHurt(monkey: Monkey, health: number)
	if health <= 0 or monkey.state == "Flee" or monkey.state == "Chase" then
		return
	end
	local attackerId = monkey.model:GetAttribute("LastAttackerUserId")
	local attacker = if typeof(attackerId) == "number" then Players:GetPlayerByUserId(attackerId) else nil
	if attacker and attacker:GetAttribute("InBasecamp") ~= true then
		chase(monkey, attacker)
		if monkey.definition.howl and not monkey.howled then
			howl(monkey, attacker)
		end
	end
end

local function collectPlayers(): { PlayerInfo }
	local infos = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		-- Los caídos y los Espíritus no cuentan: los monos los dejan en paz.
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and LifeState.isAlive(player) then
			local tool = character and character:FindFirstChildOfClass("Tool")
			table.insert(infos, {
				player = player,
				position = root.Position,
				safe = player:GetAttribute("InBasecamp") == true,
				hasTorch = tool ~= nil and tool:GetAttribute("WeaponId") == "Torch",
			})
		end
	end
	return infos
end

local function findInfo(infos: { PlayerInfo }, player: Player): PlayerInfo?
	for _, info in infos do
		if info.player == player then
			return info
		end
	end
	return nil
end

-- Jugador vulnerable (fuera del Basecamp) más cercano dentro de "range". "skipTorch": ignora a
-- quien lleva una antorcha en la mano (marteja).
local function nearestTarget(infos: { PlayerInfo }, position: Vector3, range: number, skipTorch: boolean?): PlayerInfo?
	local best: PlayerInfo? = nil
	local bestDistance = range
	for _, info in infos do
		local distance = (info.position - position).Magnitude
		if not info.safe and distance <= bestDistance and not (skipTorch and info.hasTorch) then
			best = info
			bestDistance = distance
		end
	end
	return best
end

-- Si no avanza mientras debería moverse, salta para superar raíces, rocas o desniveles.
local function unstick(monkey: Monkey, now: number)
	if monkey.root.AssemblyLinearVelocity.Magnitude > 2 then
		monkey.stuckSince = nil
	elseif not monkey.stuckSince then
		monkey.stuckSince = now
	elseif now - monkey.stuckSince > 1 then
		monkey.humanoid.Jump = true
		monkey.stuckSince = now
	end
end

-- Roba una cantidad de un material al azar de los que lleva el jugador y huye con él.
local function steal(monkey: Monkey, player: Player)
	local candidates = {}
	local foodOnly = monkey.definition.thiefFoodOnly == true
	for itemId, item in Items do
		if Inventory.count(player, itemId) > 0 and (not foodOnly or item.food ~= nil) then
			table.insert(candidates, itemId)
		end
	end
	if #candidates == 0 then
		return
	end
	local itemId = candidates[rng:NextInteger(1, #candidates)]
	local amount = math.min(Inventory.count(player, itemId), monkey.definition.thief or 1)
	if not InventoryService.remove(player, itemId, amount) then
		return
	end
	monkey.stolen = { itemId = itemId, amount = amount }
	monkey.state = "Flee"
	monkey.target = nil
	local item = Items[itemId]
	showBubble(monkey, `{item.icon} ¡JE JE!`)
	Sfx.play("MonkeySteal", monkey.root)
	MonkeyAnimator.play(monkey.model, "Steal")
	Remotes.Notify:FireClient(
		player,
		`🐒 ¡Un capuchino te ha robado {amount} {item.icon} {item.name}! Atrápalo para recuperarlo`
	)
end

-- Mordisco normal. Tras un salto pega el doble; el orangután además inmoviliza.
function bite(monkey: Monkey, player: Player)
	local damage = if monkey.pounced then monkey.damage * 2 else monkey.damage
	monkey.pounced = false
	MonkeyAnimator.play(monkey.model, "Attack")
	local landed = CombatService.damagePlayer(player, damage)
	if landed then
		playVoice(monkey, "Attack")
	end
	local grab = monkey.definition.grab
	if landed and grab then
		player:SetAttribute("StunnedUntil", Workspace:GetServerTimeNow() + grab)
		Remotes.Notify:FireClient(player, `🦧 ¡El {monkey.definition.name} te ha agarrado!`)
	end
end

-- Salto hacia la presa (marimonda, gibón).
function pounce(monkey: Monkey, target: Vector3, now: number)
	local offset = (target - monkey.root.Position) * Vector3.new(1, 0, 1)
	if offset.Magnitude < 0.1 then
		return
	end
	monkey.pounceReadyAt = now + Config.Monkeys.PounceCooldownSeconds
	monkey.pounced = true
	monkey.root.AssemblyLinearVelocity = offset.Unit * 55 + Vector3.new(0, 35, 0)
	showBubble(monkey, "¡IIIH!")
	playVoice(monkey, "Attack")
	MonkeyAnimator.play(monkey.model, "Pounce")
end

-- Rugido del mandril: quien lo oye hace menos daño un rato.
function roar(monkey: Monkey, infos: { PlayerInfo }, now: number)
	local settings = monkey.definition.roar
	if not settings then
		return
	end
	monkey.roarReadyAt = now + Config.Monkeys.RoarCooldownSeconds
	showBubble(monkey, "¡GRRRAAH!")
	playVoice(monkey, "Call")
	MonkeyAnimator.play(monkey.model, "Roar")
	for _, info in infos do
		if (info.position - monkey.root.Position).Magnitude <= settings.radius then
			info.player:SetAttribute("IntimidatedUntil", Workspace:GetServerTimeNow() + settings.seconds)
			Remotes.Notify:FireClient(info.player, "😰 El rugido te intimida: haces menos daño unos segundos")
		end
	end
end

-- Piedra lanzada (chimpancé): vuela hasta donde estaba el jugador y daña si sigue cerca.
function throwStone(monkey: Monkey, info: PlayerInfo, now: number)
	local settings = monkey.definition.throws
	if not settings then
		return
	end
	monkey.throwReadyAt = now + settings.cooldownSeconds
	MonkeyAnimator.play(monkey.model, "Throw")
	local origin = monkey.root.Position + Vector3.new(0, 2, 0)
	local target = info.position
	local stone = Instance.new("Part")
	stone.Name = "MonkeyStone"
	stone.Shape = Enum.PartType.Ball
	stone.Size = Vector3.one * 0.9
	stone.Color = Color3.fromRGB(120, 115, 110)
	stone.Anchored = true
	stone.CanCollide = false
	stone.CanQuery = false
	stone.CanTouch = false
	stone.Position = origin
	stone.Parent = Workspace
	local seconds = (target - origin).Magnitude / 70
	TweenService:Create(stone, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Position = target }):Play()
	Debris:AddItem(stone, seconds + 0.05)
	local damage = math.round(settings.damage * monkey.damage / math.max(1, monkey.definition.damage))
	task.delay(seconds, function()
		local character = info.player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and (root.Position - target).Magnitude <= 5 then
			CombatService.damagePlayer(info.player, damage)
		end
	end)
end

-- Golpe en el pecho del gorila: daña y aturde a todos los que estén cerca.
function stomp(monkey: Monkey, infos: { PlayerInfo }, now: number)
	local settings = monkey.definition.stomp
	if not settings then
		return
	end
	monkey.stompReadyAt = now + settings.cooldownSeconds
	showBubble(monkey, "💥 ¡PUM!")
	playVoice(monkey, "Call")
	Sfx.play("RockImpact", monkey.root.Position)
	MonkeyAnimator.play(monkey.model, "Stomp")
	local damage = math.round(settings.damage * monkey.damage / math.max(1, monkey.definition.damage))
	for _, info in infos do
		if not info.safe and (info.position - monkey.root.Position).Magnitude <= settings.radius then
			if CombatService.damagePlayer(info.player, damage) then
				info.player:SetAttribute("StunnedUntil", Workspace:GetServerTimeNow() + settings.stunSeconds)
			end
		end
	end
end

-- Antorchas en la mano de los jugadores y antorchas de pie construidas.
local function collectFires(): { Vector3 }
	local fires = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local tool = if character then character:FindFirstChildOfClass("Tool") else nil
		if tool and tool:GetAttribute("WeaponId") == "Torch" and character then
			table.insert(fires, character:GetPivot().Position)
		end
	end
	local structures = Workspace:FindFirstChild(Building.STRUCTURES_FOLDER)
	for _, model in if structures then structures:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("BuildableId") == "StandingTorch" then
			table.insert(fires, model:GetPivot().Position)
		end
	end
	return fires
end

-- Si hay fuego cerca, se aparta de él. Devuelve true si este turno lo dedica a apartarse.
local function avoidFire(monkey: Monkey, fires: { Vector3 }, now: number): boolean
	local position = monkey.root.Position
	for _, fire in fires do
		local away = (position - fire) * Vector3.new(1, 0, 1)
		if away.Magnitude <= Config.Monkeys.FireFearRadius then
			if now >= monkey.scaredUntil then
				showBubble(monkey, "🔥 ¡IIH!")
			end
			monkey.scaredUntil = now + 1.5
			local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
			monkey.humanoid:MoveTo(position + direction * 16)
			return true
		end
	end
	return now < monkey.scaredUntil
end

local function think(monkey: Monkey, infos: { PlayerInfo }, fires: { Vector3 }, now: number)
	local definition = monkey.definition
	local position = monkey.root.Position
	local humanoid = monkey.humanoid

	-- Dormido: nadie cerca.
	local anyoneNear = false
	for _, info in infos do
		if (info.position - position).Magnitude <= Config.Monkeys.SleepDistance then
			anyoneNear = true
			break
		end
	end
	if not anyoneNear then
		return
	end

	-- Habilidades de los roles (Combat/Status): aturdido no hace nada; ralentizado anda más despacio;
	-- provocado por un guerrero va a por él.
	if Status.isStunned(monkey.model) then
		humanoid:MoveTo(position)
		return
	end
	local speed = definition.walkSpeed * Status.speedFactor(monkey.model)
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
	local taunter = Status.tauntTarget(monkey.model)
	local nearHome = (position - monkey.group.home).Magnitude <= definition.leashRange
	if taunter and monkey.target ~= taunter and nearHome and LifeState.isAlive(taunter) then
		chase(monkey, taunter)
	end

	-- Nunca dentro del Basecamp.
	if BasecampService.isInside(position) and monkey.state ~= "Return" then
		monkey.state = "Return"
		monkey.target = nil
	end

	if definition.fearsFire and avoidFire(monkey, fires, now) then
		return
	end

	-- Con poca vida, huye si hay un jugador cerca (solo las especies que huyen).
	local fleeFraction = definition.fleeHealthFraction
	local wounded = fleeFraction ~= nil and humanoid.Health < humanoid.MaxHealth * fleeFraction
	if wounded and monkey.state ~= "Return" and nearestTarget(infos, position, definition.aggroRange) then
		monkey.state = "Flee"
	end

	if monkey.state == "Idle" then
		-- Un ladrón con botín ya no busca pelea.
		local found = if monkey.stolen
			then nil
			else nearestTarget(infos, position, definition.aggroRange, definition.ignoresTorchBearers)
		if found and (found.position - monkey.group.home).Magnitude <= definition.leashRange then
			chase(monkey, found.player)
			if definition.howl and not monkey.howled then
				howl(monkey, found.player)
			end
			if definition.roar and now >= monkey.roarReadyAt then
				roar(monkey, infos, now)
			end
			return
		end
		if now >= monkey.nextWanderAt then
			local wander = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * WANDER_RADIUS
			humanoid:MoveTo(monkey.group.home + wander)
			monkey.nextWanderAt = now + rng:NextNumber(4, 9)
		end
	elseif monkey.state == "Chase" then
		local target = monkey.target
		local info = if target then findInfo(infos, target) else nil
		local tooFarFromHome = (position - monkey.group.home).Magnitude > definition.leashRange
		if
			not info
			or info.safe
			or tooFarFromHome
			or (info.position - position).Magnitude > definition.aggroRange * 2
			or (definition.ignoresTorchBearers and info.hasTorch)
		then
			monkey.state = "Return"
			monkey.target = nil
			return
		end
		local distance = (info.position - position).Magnitude
		if definition.stomp and distance <= definition.stomp.radius * 0.6 and now >= monkey.stompReadyAt then
			stomp(monkey, infos, now)
		end
		if distance <= definition.attackRange then
			humanoid:MoveTo(position)
			if now - monkey.lastAttackAt >= definition.attackCooldownSeconds then
				monkey.lastAttackAt = now
				if definition.thief then
					steal(monkey, info.player)
				else
					bite(monkey, info.player)
				end
			end
		else
			humanoid:MoveTo(info.position)
			unstick(monkey, now)
			if definition.pounce and distance >= 8 and distance <= 18 and now >= monkey.pounceReadyAt then
				pounce(monkey, info.position, now)
			elseif definition.throws and distance <= definition.throws.range and now >= monkey.throwReadyAt then
				throwStone(monkey, info, now)
			end
		end
	elseif monkey.state == "Flee" then
		local threat = nearestTarget(infos, position, definition.aggroRange * 1.5)
		if not threat then
			monkey.state = "Return"
			return
		end
		local away = position - threat.position
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude < 0.1 then
			away = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		end
		humanoid:MoveTo(position + away.Unit * 30)
		unstick(monkey, now)
	elseif monkey.state == "Return" then
		local home = monkey.group.home
		if (position - home).Magnitude <= HOME_REACHED_DISTANCE then
			monkey.state = "Idle"
			monkey.nextWanderAt = now + rng:NextNumber(2, 5)
		else
			humanoid:MoveTo(home)
			unstick(monkey, now)
		end
	end
end

-- Pieza construida más cercana al alcance, o nil.
local function nearestStructure(position: Vector3, reach: number): Model?
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { BuildingService.getStructures() }
	local best: Model? = nil
	local bestDistance = math.huge
	for _, part in Workspace:GetPartBoundsInRadius(position, reach, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and model.Parent ~= BuildingService.getStructures() do
			model = model:FindFirstAncestorOfClass("Model")
		end
		if model then
			local distance = (part.Position - position).Magnitude
			if distance < bestDistance then
				best = model
				bestDistance = distance
			end
		end
	end
	return best
end

-- IA del asedio: portón → centro. Jugadores cerca: a por ellos. Una pieza cerca: la rompe.
local function siegeThink(monkey: Monkey, infos: { PlayerInfo }, now: number)
	local definition = monkey.definition
	local position = monkey.root.Position
	local humanoid = monkey.humanoid
	local canAttack = now - monkey.lastAttackAt >= definition.attackCooldownSeconds
	if Status.isStunned(monkey.model) then
		humanoid:MoveTo(position)
		return
	end
	local speed = definition.walkSpeed * Status.speedFactor(monkey.model)
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end

	-- Jugador vivo más cercano (dentro o fuera del Basecamp).
	local target: PlayerInfo? = nil
	local targetDistance = Config.Siege.PlayerAggroRange
	for _, info in infos do
		local distance = (info.position - position).Magnitude
		if distance <= targetDistance then
			target = info
			targetDistance = distance
		end
	end
	if target then
		if targetDistance <= definition.attackRange then
			humanoid:MoveTo(position)
			if canAttack then
				monkey.lastAttackAt = now
				CombatService.damagePlayer(target.player, monkey.damage, true)
			end
		else
			humanoid:MoveTo(target.position)
			unstick(monkey, now)
		end
		return
	end

	-- Los que desarman trampas (macaco) van primero a por las estacas cercanas.
	if definition.disarmsTraps then
		local spikes: Model? = nil
		local best = Config.Siege.TrapSearchRadius
		for _, model in BuildingService.getStructures():GetChildren() do
			if model:IsA("Model") and model:GetAttribute("BuildableId") == "Spikes" then
				local distance = (model:GetPivot().Position - position).Magnitude
				if distance < best then
					spikes = model
					best = distance
				end
			end
		end
		if spikes then
			if best <= Config.Siege.StructureReach then
				humanoid:MoveTo(position)
				if canAttack then
					monkey.lastAttackAt = now
					BuildingService.damageStructure(spikes, monkey.damage * Config.Siege.StructureDamageMultiplier * 2)
					MonkeyAnimator.play(monkey.model, "Attack")
					showBubble(monkey, "🔧")
				end
			else
				humanoid:MoveTo(spikes:GetPivot().Position)
				unstick(monkey, now)
			end
			return
		end
	end

	local structure = nearestStructure(position, Config.Siege.StructureReach)
	if structure then
		humanoid:MoveTo(position)
		if canAttack then
			monkey.lastAttackAt = now
			BuildingService.damageStructure(structure, monkey.damage * Config.Siege.StructureDamageMultiplier)
			MonkeyAnimator.play(monkey.model, "Attack")
			showBubble(monkey, "💥")
		end
		return
	end

	local gate = monkey.group.gate
	if gate and not monkey.passedGate and ((position - gate) * Vector3.new(1, 0, 1)).Magnitude <= 10 then
		monkey.passedGate = true
	end
	local goal = if gate and not monkey.passedGate then gate else BasecampService.getCenter()
	humanoid:MoveTo(goal)
	unstick(monkey, now)
end

-- Lanza un grupo de asedio que aparece en "spawnPoint" y entra por "gatePoint".
function MonkeyService.spawnSiegeGroup(speciesId: string, spawnPoint: Vector3, gatePoint: Vector3, count: number)
	local group: Group = {
		speciesId = speciesId,
		home = spawnPoint,
		size = count,
		temporary = true,
		members = {},
		nextRegrowAt = math.huge,
		siege = true,
		gate = gatePoint,
	}
	table.insert(groups, group)
	fillGroup(group)
end

-- Al amanecer: los monos del asedio que queden se retiran.
function MonkeyService.endSiege()
	for index = #groups, 1, -1 do
		local group = groups[index]
		if group.siege then
			despawnGroup(group)
			table.remove(groups, index)
		end
	end
end

-- Los monos tranquilos cerca de "position" van a por "target" (el portador del huevo, Fase 5).
function MonkeyService.alert(position: Vector3, radius: number, target: Player)
	for _, monkey in monkeys do
		local near = (monkey.root.Position - position).Magnitude <= radius
		if near and monkey.state == "Idle" and not monkey.group.siege and not monkey.definition.thief then
			chase(monkey, target)
		end
	end
end

-- Tropa que aparece en "position" y va a por "target" (refuerzos de un jefe, Fase 5).
function MonkeyService.spawnAmbush(speciesId: string, position: Vector3, count: number, target: Player)
	local group: Group = {
		speciesId = speciesId,
		home = position,
		size = count,
		temporary = true,
		members = {},
		nextRegrowAt = math.huge,
	}
	table.insert(groups, group)
	fillGroup(group)
	for _, monkey in group.members do
		chase(monkey, target)
	end
end

-- Llama a "callback" cada vez que un jugador derrota a un mono (para el diario de campo).
function MonkeyService.onKilled(callback: (player: Player, speciesId: string) -> ())
	table.insert(killListeners, callback)
end

-- Monos del asedio que siguen vivos.
function MonkeyService.siegeAlive(): number
	local count = 0
	for _, monkey in monkeys do
		if monkey.group.siege and monkey.humanoid.Health > 0 then
			count += 1
		end
	end
	return count
end

local function anyPlayerNear(position: Vector3, distance: number): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and (root.Position - position).Magnitude < distance then
			return true
		end
	end
	return false
end

-- Cada grupo incompleto de una especie activa recupera un mono, lejos de la vista de los jugadores.
local function regrowGroups()
	local state = MatchState.read()
	if not state then
		return
	end
	local now = os.clock()
	for _, group in groups do
		local definition = Monkeys[group.speciesId]
		local ready = not group.temporary and #group.members < group.size and now >= group.nextRegrowAt
		if
			ready
			and isActive(definition, state.phase)
			and not anyPlayerNear(group.home, Config.Monkeys.RegrowMinPlayerDistance)
		then
			spawnMonkey(group, group.home)
			group.nextRegrowAt = now + Config.Monkeys.GroupRegrowSeconds
		end
	end
end

function MonkeyService:Init()
	-- Solo registra el aviso; DayNightService lo llamará al empezar el día 1.
	DayNightService.onPhaseStarted(onPhaseStarted)
end

function MonkeyService:Start()
	task.spawn(function()
		while true do
			task.wait(5)
			regrowGroups()
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < Config.Monkeys.ThinkIntervalSeconds then
			return
		end
		elapsed = 0
		local infos = collectPlayers()
		local fires = collectFires()
		local now = os.clock()
		for _, monkey in monkeys do
			if monkey.humanoid.Health > 0 then
				if monkey.group.siege then
					siegeThink(monkey, infos, now)
				else
					think(monkey, infos, fires, now)
				end
			end
		end
	end)
end

return MonkeyService
