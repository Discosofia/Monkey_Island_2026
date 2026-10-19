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
-- Fase 2.5: los grupos de asedio (SiegeService) entran por un portón; dentro, cada mono se abre hacia
-- un lado y va a su hueco alrededor de la hoguera (newSiegePath). Atacan las piezas que les cierran
-- el paso y a los jugadores, también dentro del Basecamp; los macacos desarman las estacas primero.
-- Al amanecer se repueblan los grupos; los monos de día se retiran de noche (y viceversa).
-- Además, un grupo con bajas recupera un mono cada cierto tiempo si no hay jugadores cerca de su
-- zona (Config.Monkeys.GroupRegrowSeconds): la selva nunca se queda vacía.
-- Las tropas solo existen cerca de los jugadores (updatePopulation): lejos se guardan como un
-- número y aparecen cuando alguien se acerca, así hay monos por toda la isla y el límite de monos
-- a la vez (MaxActive) solo cuenta los que hay alrededor de algún jugador.

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
local Buildables = require(ReplicatedStorage.Shared.Data.Buildables)
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
-- Para medir distancias en horizontal.
local FLAT = Vector3.new(1, 0, 1)

type State = "Idle" | "Chase" | "Flee" | "Return"

type Group = {
	speciesId: string,
	home: Vector3,
	size: number,
	temporary: boolean, -- refuerzos de un aullido: no se repueblan
	members: { Monkey },
	-- Las tropas lejos de los jugadores no existen: se guardan como cuántos monos tienen ("stored")
	-- y aparecen al acercarse alguien (updatePopulation). "awake": sus monos están en el mapa.
	awake: boolean,
	stored: number,
	nextRegrowAt: number, -- os.clock() a partir del cual puede recuperar un mono
	siege: boolean?, -- grupo del asedio nocturno
	gate: Vector3?, -- portón por el que entra el grupo de asedio
	alpha: Monkey?, -- líder de la tropa (especies con "alpha")
	ignoreCap: boolean?, -- no cuenta el límite de monos a la vez (los del panel de pruebas)
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
	-- Asedio: su recorrido (portón → abierto a un lado → su hueco junto a la hoguera), el punto al
	-- que va y el rodeo si algo le tapa el paso (siegeUnstick).
	siegePath: { Vector3 }?,
	siegeStep: number,
	checkpoint: Vector3?,
	checkpointAt: number,
	detour: Vector3?,
	detourUntil: number,
	pounceReadyAt: number,
	pounced: boolean, -- el siguiente golpe hace el doble
	roarReadyAt: number,
	throwReadyAt: number,
	stompReadyAt: number,
	fighters: { [Player]: number }, -- quién le ha golpeado y cuándo (os.clock), para el botín
}

type PlayerInfo = { player: Player, position: Vector3, safe: boolean, hasTorch: boolean }

local MonkeyService = {}

local monkeys: { [Model]: Monkey } = {}
local killListeners: { (player: Player, speciesId: string) -> () } = {}
-- Médicos que han curado a cada jugador y cuándo (os.clock): comparten el botín de sus peleas.
local healedBy: { [Player]: { [Player]: number } } = {}
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

-- Un sitio al azar en la zona de su especie (ver Data/Monkeys), o nil si no hay.
local function randomSpot(definition: Monkeys.MonkeyDefinition): Vector3?
	local center = BasecampService.getCenter()
	local zone = definition.zone or "Selva"
	local origin = center
	local minDistance = Config.Monkeys.SpawnMinDistance
	local maxDistance = Config.Monkeys.SpawnMaxDistance
	local materials: { [Enum.Material]: boolean }? = SPAWN_MATERIALS
	if zone == "Playa" then
		minDistance, maxDistance, materials =
			Config.Monkeys.BeachMinDistance, Config.Monkeys.BeachMaxDistance, BEACH_MATERIALS
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
		-- Repartidas por superficie: con la distancia al azar sin más, se amontonaban cerca del
		-- Basecamp (125 monos a su alrededor) y las orillas de la isla se quedaban casi vacías.
		local distance = math.sqrt(rng:NextNumber(minDistance ^ 2, maxDistance ^ 2))
		local ground = findGround(origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance, materials)
		if ground then
			return ground
		end
	end
	-- Sin sitio en su zona (mapa de pruebas): cualquier selva.
	if zone ~= "Selva" then
		return randomSpot(Monkeys.MonoArdilla)
	end
	return nil
end

-- Si dos especies llegan a estar en el mapa a la vez (de día, de noche o las dos).
local function sharePhase(a: Monkeys.MonkeyDefinition, b: Monkeys.MonkeyDefinition): boolean
	return a.activeAt == "Both" or b.activeAt == "Both" or a.activeAt == b.activeAt
end

-- Zona de una tropa nueva: de Config.Monkeys.HomeCandidates sitios al azar, el más alejado de las
-- tropas de su mismo turno. Al azar sin más, unas caían juntas y quedaban claros grandes sin monos.
local function newHome(definition: Monkeys.MonkeyDefinition): Vector3?
	local best: Vector3? = nil
	local bestDistance = -1
	for _ = 1, Config.Monkeys.HomeCandidates do
		local spot = randomSpot(definition)
		if not spot then
			break
		end
		local nearest = math.huge
		for _, group in groups do
			if sharePhase(definition, Monkeys[group.speciesId]) then
				local offset = group.home - spot
				nearest = math.min(nearest, Vector3.new(offset.X, 0, offset.Z).Magnitude)
			end
		end
		if nearest > bestDistance then
			best, bestDistance = spot, nearest
		end
	end
	return best
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

-- Quienes pelearon contra el mono (Config.Monkeys.LootShareSeconds): los que le golpearon, los
-- médicos que curaron a alguno de ellos y siempre quien lo derrotó. Solo jugadores vivos en el server.
local function lootSharers(monkey: Monkey, killer: Player): { Player }
	local since = os.clock() - Config.Monkeys.LootShareSeconds
	local set: { [Player]: boolean } = { [killer] = true }
	for player, at in monkey.fighters do
		if at >= since then
			set[player] = true
		end
	end
	for player in table.clone(set) do
		for healer, at in healedBy[player] or {} do
			if at >= since then
				set[healer] = true
			end
		end
	end
	local list = {}
	for player in set do
		if player.Parent == Players and (player == killer or LifeState.isAlive(player)) then
			table.insert(list, player)
		end
	end
	return list
end

-- El botín sale junto al personaje de quien lo recibe (InventoryService.collect). Cada unidad va
-- al azar a uno de los que pelearon (lootSharers): en solitario, todo para quien lo derrotó.
local function giveLoot(sharers: { Player }, definition: Monkeys.MonkeyDefinition)
	for _, entry in definition.loot do
		if rng:NextNumber() < entry.chance * Config.Monkeys.LootChanceMultiplier then
			local shares: { [Player]: number } = {}
			for _ = 1, rng:NextInteger(entry.min, entry.max) do
				local player = sharers[rng:NextInteger(1, #sharers)]
				shares[player] = (shares[player] or 0) + 1
			end
			for player, amount in shares do
				InventoryService.collect(player, entry.itemId, amount)
			end
		end
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
		giveLoot(lootSharers(monkey, killer), monkey.definition)
		local stolen = monkey.stolen
		if stolen then
			InventoryService.collect(killer, stolen.itemId, stolen.amount)
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

-- El alfa: más vida y daño, y una corona sobre la cabeza (el modelo más grande y de colores más
-- marcados lo pone MonkeyModels.spawn).
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

-- Recorrido de un mono del asedio (Config.Siege): entra por el portón de su grupo, se abre hacia un
-- lado al azar y acaba en su hueco alrededor de la hoguera, a ras de suelo y del mismo lado. Cada
-- uno el suyo: cruzan las estacas por sitios distintos y no se amontonan en el mismo punto.
local function newSiegePath(group: Group): { Vector3 }?
	local gate = group.gate
	if not gate then
		return nil
	end
	local settings = Config.Siege
	local center = Building.center() or BasecampService.getCenter()
	local inward = (center - gate) * FLAT
	if inward.Magnitude < 1 then
		return { gate }
	end
	inward = inward.Unit
	local side = Vector3.new(-inward.Z, 0, inward.X)
	local lateral = rng:NextNumber(-1, 1)
	local spread = gate + inward * settings.SpreadDepth + side * lateral * settings.SpreadWidth
	-- Girar el ángulo del portón hacia "-lateral" lleva el hueco hacia el mismo lado que "side".
	local angle = math.atan2(-inward.Z, -inward.X) - lateral * math.rad(settings.CampRingSpreadDegrees)
	local radius = rng:NextNumber(settings.CampRingMin, settings.CampRingMax)
	local slot = Vector3.new(center.X + math.cos(angle) * radius, center.Y, center.Z + math.sin(angle) * radius)
	return { gate, spread, slot }
end

local function spawnMonkey(group: Group, near: Vector3): Monkey?
	local definition = Monkeys[group.speciesId]
	local offset = Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
	local ground = findGround(near + offset, nil) or findGround(near, nil)
	if not ground or (not group.siege and not group.ignoreCap and activeCount() >= Config.Monkeys.MaxActive) then
		return nil
	end

	-- El primero de una tropa con alfa es el alfa: se decide antes porque tiene su propio modelo.
	local isAlpha = definition.alpha == true and not group.alpha
	local model = MonkeyModels.spawn(group.speciesId, definition, ground, isAlpha)
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
		siegePath = if group.siege then newSiegePath(group) else nil,
		siegeStep = 1,
		checkpoint = nil,
		checkpointAt = 0,
		detour = nil,
		detourUntil = 0,
		pounceReadyAt = 0,
		pounced = false,
		roarReadyAt = 0,
		throwReadyAt = 0,
		stompReadyAt = 0,
		fighters = {},
	}
	monkeys[model] = monkey
	table.insert(group.members, monkey)
	MonkeyAnimator.attach(model)
	if isAlpha then
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
	-- Al volver a aparecer, el primero vuelve a ser el alfa (antes se quedaba apuntando al alfa
	-- borrado y la tropa reaparecía sin alfa).
	group.alpha = nil
end

-- Tamaño de una tropa nueva: el de su especie por Config.Monkeys.GroupSizeMultiplier.
local function groupSize(definition: Monkeys.MonkeyDefinition): number
	local size = rng:NextInteger(definition.groupMin, definition.groupMax)
	return math.max(1, math.round(size * Config.Monkeys.GroupSizeMultiplier))
end

local function createGroups()
	for speciesId, definition in Monkeys do
		for _ = 1, definition.groups do
			local home = newHome(definition)
			if home then
				table.insert(groups, {
					speciesId = speciesId,
					home = home,
					size = groupSize(definition),
					temporary = false,
					members = {},
					awake = false,
					stored = 0,
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

-- Dónde están los jugadores con personaje (también los del Basecamp: las tropas de alrededor tienen
-- que estar ahí cuando salgan).
local function playerPositions(): { Vector3 }
	local positions = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	return positions
end

local function nearestDistance(positions: { Vector3 }, point: Vector3): number
	local nearest = math.huge
	for _, position in positions do
		nearest = math.min(nearest, (position - point).Magnitude)
	end
	return nearest
end

-- Guarda las tropas que se han quedado sin jugadores alrededor (ni de su zona ni de ninguno de sus
-- monos, que pueden haberse ido persiguiendo a alguien) y despierta las que tienen a alguien cerca,
-- las más cercanas primero por si se llega al límite de monos a la vez. No mira si pelean: a más de
-- SleepDistance un mono deja de pensar y se quedaría "persiguiendo" para siempre. Un ladrón con lo
-- robado sigue en el mapa para que el jugador pueda volver a recuperarlo.
local function updatePopulation()
	local state = MatchState.read()
	if not state then
		return
	end
	local positions = playerPositions()
	local waking: { { group: Group, distance: number } } = {}
	for _, group in groups do
		if group.temporary then
			continue
		end
		local distance = nearestDistance(positions, group.home)
		if group.awake and distance > Config.Monkeys.DormantDistance then
			local busy = false
			for _, monkey in group.members do
				local seen = nearestDistance(positions, monkey.root.Position) <= Config.Monkeys.DormantDistance
				if seen or monkey.stolen then
					busy = true
					break
				end
			end
			if not busy then
				group.stored += #group.members
				despawnGroup(group)
				group.awake = false
			end
		elseif
			group.stored > 0
			and distance <= Config.Monkeys.WakeDistance
			and isActive(Monkeys[group.speciesId], state.phase)
			-- Lo que faltaba en una tropa ya despierta (por el límite) no aparece delante del jugador.
			and (not group.awake or distance > Config.Monkeys.RegrowMinPlayerDistance)
		then
			table.insert(waking, { group = group, distance = distance })
		end
	end
	table.sort(waking, function(a, b)
		return a.distance < b.distance
	end)
	for _, entry in waking do
		local group = entry.group
		group.awake = true
		while group.stored > 0 and spawnMonkey(group, group.home) do
			group.stored -= 1
		end
		if activeCount() >= Config.Monkeys.MaxActive then
			break
		end
	end
end

local function onPhaseStarted(_day: number, phase: MatchState.Phase)
	if #groups == 0 then
		createGroups()
	end
	for _, group in groups do
		local definition = Monkeys[group.speciesId]
		if not isActive(definition, phase) then
			despawnGroup(group)
			group.awake = false
			group.stored = 0
		elseif phase == "Day" or definition.activeAt == phase then
			-- Las especies de día y "Both" se repueblan al amanecer; las nocturnas, al anochecer. Lo que
			-- falta queda guardado y aparece cuando haya alguien cerca (updatePopulation).
			if not group.temporary then
				group.stored = group.size - #group.members
			end
		end
	end
	updatePopulation()
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
		awake = true,
		stored = 0,
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
			table.insert(infos, {
				player = player,
				position = root.Position,
				safe = player:GetAttribute("InBasecamp") == true,
				-- Antorcha encendida en la mano izquierda (TorchService).
				hasTorch = player:GetAttribute("TorchLit") == true,
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
		-- El equipo ("keep", la antorcha) no se roba.
		if Inventory.count(player, itemId) > 0 and not item.keep and (not foodOnly or item.food ~= nil) then
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
	-- El nombre de su especie, en minúscula ("capuchino ladrón", "mono de cola larga").
	local name = monkey.definition.name
	local species = string.lower(string.sub(name, 1, 1)) .. string.sub(name, 2)
	Remotes.Notify:FireClient(
		player,
		`🐒 ¡Un {species} te ha robado {amount} {item.icon} {item.name}! Atrápalo para recuperarlo`
	)
end

-- Mordisco normal. Tras un salto pega el doble; el orangután además inmoviliza (no si te acaba de
-- soltar: Status.holdPlayer).
function bite(monkey: Monkey, player: Player)
	local damage = if monkey.pounced then monkey.damage * 2 else monkey.damage
	monkey.pounced = false
	MonkeyAnimator.play(monkey.model, "Attack")
	local landed = CombatService.damagePlayer(player, damage, false, monkey.model, nil, true)
	if landed then
		playVoice(monkey, "Attack")
	end
	local grab = monkey.definition.grab
	if landed and grab and Status.holdPlayer(player, grab, monkey.group.speciesId) then
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
			CombatService.damagePlayer(info.player, damage, false, monkey.model)
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
			if CombatService.damagePlayer(info.player, damage, false, monkey.model) then
				Status.holdPlayer(info.player, settings.stunSeconds, monkey.group.speciesId)
			end
		end
	end
end

-- Antorchas encendidas en la mano de los jugadores (TorchService) y antorchas de pie construidas.
local function collectFires(): { Vector3 }
	local fires = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and player:GetAttribute("TorchLit") == true then
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

-- true si la pieza no cierra el paso ("walkable" en Data/Buildables, como las estacas).
local function isWalkable(model: Model): boolean
	local buildableId = model:GetAttribute("BuildableId")
	local definition = if typeof(buildableId) == "string" then Buildables[buildableId] else nil
	return definition ~= nil and definition.walkable == true
end

-- Pieza construida más cercana al alcance que cierra el paso, o nil. Las transitables (estacas) no
-- cuentan: el mono las cruza en vez de pararse a romperlas.
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
		if model and not isWalkable(model) then
			local distance = (part.Position - position).Magnitude
			if distance < bestDistance then
				best = model
				bestDistance = distance
			end
		end
	end
	return best
end

-- Asedio: si en Config.Siege.DetourAfterSeconds no ha avanzado ni 3 studs hacia "goal" (algo le
-- tapa el paso, como el tótem o una mesa), rodea hacia un lado un momento. Además salta (unstick).
local function siegeUnstick(monkey: Monkey, goal: Vector3, now: number)
	unstick(monkey, now)
	local settings = Config.Siege
	local position = monkey.root.Position
	local checkpoint = monkey.checkpoint
	if not checkpoint or ((position - checkpoint) * FLAT).Magnitude > 3 then
		monkey.checkpoint = position
		monkey.checkpointAt = now
	elseif now - monkey.checkpointAt > settings.DetourAfterSeconds and now >= monkey.detourUntil then
		local toGoal = (goal - position) * FLAT
		if toGoal.Magnitude > 0.1 then
			local side = Vector3.new(-toGoal.Z, 0, toGoal.X).Unit * (if rng:NextNumber() < 0.5 then -1 else 1)
			monkey.detour = position + side * settings.DetourDistance + toGoal.Unit * 2
			monkey.detourUntil = now + settings.DetourSeconds
		end
		monkey.checkpointAt = now
	end
end

-- IA del asedio: su recorrido (portón → abierto a un lado → su hueco junto a la hoguera). Jugadores
-- cerca: a por ellos. Una pieza que le cierra el paso: la rompe. Los macacos desarman las estacas.
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
	local inReach = target ~= nil and targetDistance <= definition.attackRange
	if target and inReach then
		humanoid:MoveTo(position)
		if canAttack then
			monkey.lastAttackAt = now
			CombatService.damagePlayer(target.player, monkey.damage, true, monkey.model, nil, true)
		end
		return
	end

	-- Los que desarman trampas (macaco) van a por las estacas cercanas antes que a por los jugadores
	-- (salvo que tengan uno al alcance del golpe, arriba).
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
					BuildingService.damageStructure(spikes, Config.Siege.SpikeDisarmPerHit)
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

	if target then
		humanoid:MoveTo(target.position)
		unstick(monkey, now)
		return
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

	-- Su recorrido, punto a punto. En su hueco junto a la hoguera se queda esperando.
	local path = monkey.siegePath
	local reach = Config.Siege.WaypointReach
	local goal = BasecampService.getCenter()
	if path then
		while monkey.siegeStep < #path and ((position - path[monkey.siegeStep]) * FLAT).Magnitude <= reach do
			monkey.siegeStep += 1
		end
		goal = path[monkey.siegeStep]
		if monkey.siegeStep == #path and ((position - goal) * FLAT).Magnitude <= reach then
			humanoid:MoveTo(position)
			return
		end
	end
	local detour = monkey.detour
	humanoid:MoveTo(if detour and now < monkey.detourUntil then detour else goal)
	siegeUnstick(monkey, goal, now)
end

-- Lanza un grupo de asedio que aparece en "spawnPoint" y entra por "gatePoint".
function MonkeyService.spawnSiegeGroup(speciesId: string, spawnPoint: Vector3, gatePoint: Vector3, count: number)
	local group: Group = {
		speciesId = speciesId,
		home = spawnPoint,
		size = count,
		temporary = true,
		members = {},
		awake = true,
		stored = 0,
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

-- Tropa que aparece en "position" y va a por "target" (refuerzos de un jefe, Fase 5). Devuelve
-- cuántos monos han aparecido: ninguno si ahí no se puede (dentro del Basecamp, sobre agua o sobre
-- una pieza) o, salvo con "ignoreCap", si ya hay el máximo de monos a la vez.
function MonkeyService.spawnAmbush(
	speciesId: string,
	position: Vector3,
	count: number,
	target: Player,
	ignoreCap: boolean?
): number
	local group: Group = {
		speciesId = speciesId,
		home = position,
		size = count,
		temporary = true,
		members = {},
		awake = true,
		stored = 0,
		nextRegrowAt = math.huge,
		ignoreCap = ignoreCap,
	}
	fillGroup(group)
	if #group.members == 0 then
		return 0
	end
	table.insert(groups, group)
	for _, monkey in group.members do
		chase(monkey, target)
	end
	return #group.members
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
-- Si la tropa está guardada, solo suma uno a los que aparecerán cuando alguien se acerque.
local function regrowGroups()
	local state = MatchState.read()
	if not state then
		return
	end
	local now = os.clock()
	for _, group in groups do
		local definition = Monkeys[group.speciesId]
		local missing = #group.members + group.stored < group.size
		local ready = not group.temporary and missing and now >= group.nextRegrowAt
		if not (ready and isActive(definition, state.phase)) then
			continue
		end
		if not group.awake then
			group.stored += 1
			group.nextRegrowAt = now + Config.Monkeys.GroupRegrowSeconds
		elseif not anyPlayerNear(group.home, Config.Monkeys.RegrowMinPlayerDistance) then
			spawnMonkey(group, group.home)
			group.nextRegrowAt = now + Config.Monkeys.GroupRegrowSeconds
		end
	end
end

function MonkeyService:Init()
	-- Solo registra el aviso; DayNightService lo llamará al empezar el día 1.
	DayNightService.onPhaseStarted(onPhaseStarted)

	-- Botín compartido (lootSharers): quién golpea a cada mono y quién cura a quién.
	CombatService.onEnemyDamaged(function(model, attacker)
		local monkey = monkeys[model]
		if monkey and attacker then
			monkey.fighters[attacker] = os.clock()
		end
	end)
	CombatService.onPlayerHealed(function(player, healer)
		local healers = healedBy[player]
		if not healers then
			healers = {}
			healedBy[player] = healers
		end
		healers[healer] = os.clock()
	end)
	Players.PlayerRemoving:Connect(function(player)
		healedBy[player] = nil
		for _, healers in healedBy do
			healers[player] = nil
		end
		for _, monkey in monkeys do
			monkey.fighters[player] = nil
		end
	end)
end

function MonkeyService:Start()
	task.spawn(function()
		while true do
			task.wait(5)
			regrowGroups()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Monkeys.PopulationCheckSeconds)
			updatePopulation()
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
