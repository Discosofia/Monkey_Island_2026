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
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Building = require(ReplicatedStorage.Shared.Building)
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local BasecampService = require(script.Parent.BasecampService)
local CombatService = require(script.Parent.CombatService)
local DayNightService = require(script.Parent.DayNightService)
local InventoryService = require(script.Parent.InventoryService)
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
	stolen: { itemId: string, amount: number }?,
	scaredUntil: number,
}

type PlayerInfo = { player: Player, position: Vector3, safe: boolean }

local MonkeyService = {}

local monkeys: { [Model]: Monkey } = {}
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

-- Suelo de selva bajo un punto, o nil si ahí hay agua, playa, roca, un árbol…
local function findGround(position: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { monkeyFolder() }
	local result = Workspace:Raycast(Vector3.new(position.X, 400, position.Z), Vector3.new(0, -800, 0), params)
	if not result then
		return nil
	end
	local onTerrain = result.Instance == Workspace.Terrain and SPAWN_MATERIALS[result.Material] == true
	-- En un place de pruebas sin terreno, vale la Baseplate.
	local onBaseplate = result.Instance.Name == "Baseplate"
	if not (onTerrain or onBaseplate) or BasecampService.isInside(result.Position) then
		return nil
	end
	return result.Position
end

local function randomHome(): Vector3?
	local center = BasecampService.getCenter()
	for _ = 1, 60 do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = rng:NextNumber(Config.Monkeys.SpawnMinDistance, Config.Monkeys.SpawnMaxDistance)
		local ground = findGround(center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance)
		if ground then
			return ground
		end
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
	-- La espera para recuperar un mono empieza con la primera baja.
	local group = monkey.group
	group.nextRegrowAt = math.max(group.nextRegrowAt, os.clock() + Config.Monkeys.GroupRegrowSeconds)

	local killerId = monkey.model:GetAttribute("LastAttackerUserId")
	local killer = if typeof(killerId) == "number" then Players:GetPlayerByUserId(killerId) else nil
	if killer then
		giveLoot(killer, monkey.definition)
		local stolen = monkey.stolen
		if stolen then
			InventoryService.add(killer, stolen.itemId, stolen.amount)
			local item = Items[stolen.itemId]
			Remotes.Notify:FireClient(killer, `Recuperas lo robado: {stolen.amount} {item.icon} {item.name}`)
		end
	end

	-- El cuerpo se queda quieto y se desvanece.
	monkey.root.Anchored = true
	local fade = TweenInfo.new(Config.Monkeys.CorpseSeconds)
	for _, part in monkey.model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			TweenService:Create(part, fade, { Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(monkey.model, Config.Monkeys.CorpseSeconds + 0.1)
end

local onHurt: (monkey: Monkey, health: number) -> ()

local function spawnMonkey(group: Group, near: Vector3): Monkey?
	local definition = Monkeys[group.speciesId]
	local offset = Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
	local ground = findGround(near + offset) or findGround(near)
	if not ground then
		return nil
	end

	local model = MonkeyModels.build(group.speciesId, definition, ground)
	model.Parent = monkeyFolder()
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
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
		stolen = nil,
		scaredUntil = 0,
	}
	monkeys[model] = monkey
	table.insert(group.members, monkey)
	humanoid.Died:Connect(function()
		onDied(monkey)
	end)
	humanoid.HealthChanged:Connect(function(health)
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
			local home = randomHome()
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
			table.insert(infos, {
				player = player,
				position = root.Position,
				safe = player:GetAttribute("InBasecamp") == true,
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

-- Jugador vulnerable (fuera del Basecamp) más cercano dentro de "range".
local function nearestTarget(infos: { PlayerInfo }, position: Vector3, range: number): PlayerInfo?
	local best: PlayerInfo? = nil
	local bestDistance = range
	for _, info in infos do
		local distance = (info.position - position).Magnitude
		if not info.safe and distance <= bestDistance then
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
	for itemId in Items do
		if Inventory.count(player, itemId) > 0 then
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
	Remotes.Notify:FireClient(
		player,
		`🐒 ¡Un capuchino te ha robado {amount} {item.icon} {item.name}! Atrápalo para recuperarlo`
	)
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
		local found = if monkey.stolen then nil else nearestTarget(infos, position, definition.aggroRange)
		if found and (found.position - monkey.group.home).Magnitude <= definition.leashRange then
			chase(monkey, found.player)
			if definition.howl and not monkey.howled then
				howl(monkey, found.player)
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
		then
			monkey.state = "Return"
			monkey.target = nil
			return
		end
		local distance = (info.position - position).Magnitude
		if distance <= definition.attackRange then
			humanoid:MoveTo(position)
			if now - monkey.lastAttackAt >= definition.attackCooldownSeconds then
				monkey.lastAttackAt = now
				if definition.thief then
					steal(monkey, info.player)
				else
					CombatService.damagePlayer(info.player, definition.damage)
				end
			end
		else
			humanoid:MoveTo(info.position)
			unstick(monkey, now)
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
				think(monkey, infos, fires, now)
			end
		end
	end)
end

return MonkeyService
