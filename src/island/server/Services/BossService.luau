--!strict
-- Jefes de bioma (GDD §8.2, Fase 5).
--   - Uno cada Config.Match.BossIntervalDays días (días 2, 4, 6, 8…), en el orden de
--     Config.Match.BossRotation. Aparece en la guarida de su bioma y se queda hasta que lo derrotan o
--     llega el siguiente.
--   - Tres fases (al 66 % y al 33 % de vida): más rápido, más fuerte y con más ataques especiales.
--   - Su vida depende de los jugadores que pelean con él (Config.Bosses): vivos, fuera del Basecamp y
--     en su zona. Se recalcula cuando entra o sale alguien sin cambiar el % que le queda.
--   - Al derrotarlo: una pieza de la baliza para el servidor (Shared/Beacon) y su botín especial para
--     cada jugador que le hizo daño.
--   - El HUD lee su estado de ReplicatedStorage ("BossName", "BossHealth", "BossMaxHealth",
--     "BossPhase", "BossPosition"). La música lee "BossId" y "BossFighting" (está peleando).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Beacon = require(ReplicatedStorage.Shared.Beacon)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MatchStats = require(ReplicatedStorage.Shared.MatchStats)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AbilityFx = require(script.Parent.Parent.Combat.AbilityFx)
local BasecampService = require(script.Parent.BasecampService)
local CombatService = require(script.Parent.CombatService)
local DayNightService = require(script.Parent.DayNightService)
local InventoryService = require(script.Parent.InventoryService)
local MonkeyService = require(script.Parent.MonkeyService)
local TelemetryService = require(script.Parent.TelemetryService)
local Hazards = require(script.Parent.Parent.Combat.Hazards)
local Poof = require(script.Parent.Parent.Combat.Poof)
local Status = require(script.Parent.Parent.Combat.Status)
local MonkeyAnimator = require(script.Parent.Parent.Monkeys.MonkeyAnimator)
local MonkeyModels = require(script.Parent.Parent.Monkeys.MonkeyModels)

local TICK_SECONDS = 0.2
-- Segundos que sigue "peleando" (y suena su tema) después de perder a su objetivo o del último golpe.
local FIGHT_GRACE_SECONDS = 8
-- El pisotón aterriza a la vez que la onda de choque (Hazards.shockwave): grietas y piedras como el
-- Pisotón del guerrero (AbilityFxController "Quake").
local STOMP_RADIUS = 20
local STOMP_IMPACT_SECONDS = 0.9
local BIOME_NAMES: { [string]: string } = {
	Rios = "los ríos",
	Montanas = "las montañas",
	Cuevas = "las cuevas",
	Volcan = "el volcán",
}

type ActiveBoss = {
	id: string,
	definition: Bosses.Boss,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	lair: Vector3,
	phase: number,
	damage: number,
	cooldowns: { [string]: number },
	nextSpecialAt: number,
	lastAttackAt: number,
	channelUntil: number, -- os.clock() hasta el que se queda quieto invocando (Special.channelFromPhase)
	fightingUntil: number, -- os.clock(); ver FIGHT_GRACE_SECONDS
	contributors: { [Player]: boolean },
	fighters: number, -- jugadores peleando con los que está calculada su vida (rescaleHealth)
	firstHitAt: number?, -- os.clock() del primer golpe de un jugador (telemetría de duración)
}

-- Animación de cada ataque especial (Data/MonkeyAnimations).
local SPECIAL_ANIMATIONS: { [string]: MonkeyAnimator.Action } = {
	stomp = "Stomp",
	summon = "Howl",
	rockRain = "Throw",
	charge = "Pounce",
	grab = "Attack",
	extinguish = "Roar",
}

local BossService = {}

local current: ActiveBoss? = nil
local rng = Random.new()
local phaseListeners: { (bossId: string, phase: number) -> () } = {}
local defeatListeners: { (player: Player, bossId: string) -> () } = {}

-- Llama a "callback" cuando un jefe cambia de fase (WeatherService: erupción del Gorila de Ceniza).
-- Avisa cuando cae un jefe a cada jugador que le hizo daño (DataService: diario de campo).
function BossService.onDefeated(callback: (player: Player, bossId: string) -> ())
	table.insert(defeatListeners, callback)
end

function BossService.onPhaseChanged(callback: (bossId: string, phase: number) -> ())
	table.insert(phaseListeners, callback)
end

local function announce(text: string)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text)
	end
end

local function bubble(boss: ActiveBoss, text: string)
	local head = boss.model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 50)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 120, 60)
	label.TextStrokeTransparency = 0.2
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Parent = billboard
	Debris:AddItem(billboard, 1.5)
end

local function publish()
	local boss = current
	if not boss then
		for _, name in
			{ "BossId", "BossName", "BossHealth", "BossMaxHealth", "BossPhase", "BossPosition", "BossFighting" }
		do
			ReplicatedStorage:SetAttribute(name, nil)
		end
		return
	end
	ReplicatedStorage:SetAttribute("BossId", boss.id)
	ReplicatedStorage:SetAttribute("BossName", boss.definition.name)
	ReplicatedStorage:SetAttribute("BossHealth", math.max(0, boss.humanoid.Health))
	ReplicatedStorage:SetAttribute("BossMaxHealth", boss.humanoid.MaxHealth)
	ReplicatedStorage:SetAttribute("BossPhase", boss.phase)
	ReplicatedStorage:SetAttribute("BossPosition", boss.root.Position)
	ReplicatedStorage:SetAttribute("BossFighting", os.clock() < boss.fightingUntil)
end

local function lairPosition(definition: Bosses.Boss): Vector3
	local marker = Workspace:FindFirstChild(`Guarida_{definition.biome}`, true)
	if marker and marker:IsA("BasePart") then
		return marker.Position
	end
	-- Mapa sin guaridas (pruebas): lejos del Basecamp.
	local angle = rng:NextNumber(0, 2 * math.pi)
	return BasecampService.getCenter() + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 300
end

local function groundBelow(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local result = Workspace:Raycast(position + Vector3.new(0, 80, 0), Vector3.new(0, -300, 0), params)
	return if result then result.Position else position
end

local function despawnCurrent(reason: string?)
	local boss = current
	if not boss then
		return
	end
	current = nil
	if reason then
		announce(reason)
	end
	boss.model:Destroy()
	publish()
end

local function onBossDied(boss: ActiveBoss)
	if current ~= boss then
		return
	end
	current = nil
	Beacon.add(boss.id)
	local item = Items[boss.definition.lootItemId]
	local reported = false
	for player in boss.contributors do
		if player.Parent and not reported then
			reported = true
			TelemetryService.bossDefeated(player, boss.id, os.clock() - (boss.firstHitAt or os.clock()), boss.fighters)
		end
		if player.Parent then
			InventoryService.collect(player, boss.definition.lootItemId, 1)
			MatchStats.add(player, MatchStats.BOSSES)
			Remotes.Notify:FireClient(player, `🏆 Botín del jefe: {item.icon} {item.name}`)
			for _, listener in defeatListeners do
				task.spawn(listener, player, boss.id)
			end
		end
	end
	announce(`🏆 ¡{boss.definition.name} ha caído! Pieza de la baliza: {#Beacon.pieces()}/{Beacon.total()}`)
	MonkeyAnimator.die(boss.model)
	Poof.vanish(boss.model)
	publish()
end

-- Más jugadores peleando, más vida (Config.Bosses): ×HealthBase con uno y +HealthPerExtraPlayer por
-- cada uno más, hasta MaxHealthMultiplier.
local function healthMultiplier(fighters: number): number
	local settings = Config.Bosses
	return math.min(
		settings.MaxHealthMultiplier,
		settings.HealthBase + settings.HealthPerExtraPlayer * (math.max(1, fighters) - 1)
	)
end

-- Jugadores que pelean con el jefe: vivos, fuera del Basecamp y en su zona (a menos de leashRange de
-- su guarida, la misma zona en la que los persigue). Al menos 1.
local function countFighters(boss: ActiveBoss): number
	local count = 0
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if
			root
			and root:IsA("BasePart")
			and LifeState.isAlive(player)
			and player:GetAttribute("InBasecamp") ~= true
			and (root.Position - boss.lair).Magnitude <= boss.definition.leashRange
		then
			count += 1
		end
	end
	return math.max(1, count)
end

-- Ajusta la vida máxima a los que pelean sin cambiar el % que le queda (las fases van por %). Se pone
-- primero el valor que no se sale del máximo vigente para que la vida no se recorte por el camino.
local function rescaleHealth(boss: ActiveBoss)
	local fighters = countFighters(boss)
	local humanoid = boss.humanoid
	if fighters == boss.fighters or humanoid.Health <= 0 then
		return
	end
	boss.fighters = fighters
	local fraction = humanoid.Health / humanoid.MaxHealth
	local maxHealth = math.round(boss.definition.maxHealth * healthMultiplier(fighters))
	local health = math.max(1, fraction * maxHealth)
	if maxHealth < humanoid.MaxHealth then
		humanoid.Health = health
		humanoid.MaxHealth = maxHealth
	else
		humanoid.MaxHealth = maxHealth
		humanoid.Health = health
	end
end

function BossService.spawn(bossId: string)
	local definition = Bosses[bossId]
	local species = Monkeys[definition.baseSpecies]
	if not (definition and species) then
		warn(`[BossService] Jefe desconocido: {bossId}`)
		return
	end
	despawnCurrent(nil)

	local lair = lairPosition(definition)
	local look = table.clone(species)
	look.name = definition.name
	look.scale = definition.scale
	look.bodyColor = definition.bodyColor
	look.faceColor = definition.faceColor
	look.maxHealth = math.round(definition.maxHealth * healthMultiplier(1))
	look.walkSpeed = definition.walkSpeed
	local model = MonkeyModels.spawnBoss(definition.baseSpecies, look, groundBelow(lair), bossId)
	model.Name = definition.name
	model:SetAttribute("Boss", bossId)
	model:SetAttribute("BossPhase", 1)
	model.Parent = Workspace
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	root:SetNetworkOwner(nil)
	CollectionService:AddTag(model, Config.Combat.EnemyTag)
	MonkeyAnimator.attach(model)

	local now = os.clock()
	local boss: ActiveBoss = {
		id = bossId,
		definition = definition,
		model = model,
		humanoid = humanoid,
		root = root,
		lair = lair,
		phase = 1,
		damage = definition.damage,
		cooldowns = {},
		nextSpecialAt = now + 4,
		lastAttackAt = 0,
		channelUntil = 0,
		fightingUntil = 0,
		contributors = {},
		fighters = 1,
	}
	for _, special in definition.specials do
		boss.cooldowns[special.id] = now + rng:NextNumber(3, 6)
	end
	current = boss
	humanoid.Died:Connect(function()
		Sfx.play("BossDeath", root.Position)
		onBossDied(boss)
	end)
	-- Se queja al perder vida. Se compara el % (no la vida) para que no lo haga cuando rescaleHealth
	-- le baja el máximo porque alguien se va.
	local lastFraction = 1
	local lastGruntAt = 0
	humanoid.HealthChanged:Connect(function(health)
		local clock = os.clock()
		local fraction = health / humanoid.MaxHealth
		if health > 0 and fraction < lastFraction - 0.001 and clock - lastGruntAt > 1.2 then
			lastGruntAt = clock
			Sfx.play("BossHurt", root)
			MonkeyAnimator.play(model, "Hurt")
		end
		lastFraction = fraction
	end)
	Sfx.play("BossRoar", root)
	MonkeyAnimator.play(model, "Roar")
	announce(`👑 ¡{definition.name} ha despertado en {BIOME_NAMES[definition.biome] or definition.biome}!`)
	publish()
end

local function nearestTarget(boss: ActiveBoss): (Player?, BasePart?)
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = boss.definition.aggroRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if
			root
			and root:IsA("BasePart")
			and LifeState.isAlive(player)
			and player:GetAttribute("InBasecamp") ~= true
			and (root.Position - boss.lair).Magnitude <= boss.definition.leashRange
		then
			local distance = (root.Position - boss.root.Position).Magnitude
			if distance < bestDistance then
				best = player
				bestRoot = root
				bestDistance = distance
			end
		end
	end
	return best, bestRoot
end

local function playersAround(position: Vector3, radius: number): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and (root.Position - position).Magnitude <= radius then
			table.insert(list, player)
		end
	end
	return list
end

local SPECIALS: { [string]: (boss: ActiveBoss, special: Bosses.Special, target: Player, targetRoot: BasePart) -> () } =
	{
		stomp = function(boss)
			bubble(boss, "💥 ¡PUM!")
			local position = boss.root.Position
			Hazards.shockwave(
				position,
				STOMP_RADIUS,
				math.round(boss.damage * 0.8),
				1.5,
				STOMP_IMPACT_SECONDS,
				`Jefe {boss.id}`
			)
			task.delay(STOMP_IMPACT_SECONDS, function()
				if current == boss then
					Sfx.play("RockImpact", position)
					AbilityFx.all("Quake", groundBelow(position), STOMP_RADIUS)
				end
			end)
		end,
		summon = function(boss, special, target)
			bubble(boss, "¡A MÍ, TROPA!")
			local offset = Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
			MonkeyService.spawnAmbush(
				special.species or "AulladorRojo",
				boss.root.Position + offset,
				special.count or 3,
				target
			)
		end,
		rockRain = function(boss, special)
			bubble(boss, "¡ROCAS!")
			local lava = boss.definition.eruption == true
			local color = if lava then Color3.fromRGB(255, 110, 30) else Color3.fromRGB(110, 105, 100)
			local victims = playersAround(boss.root.Position, 60)
			for index = 1, special.count or 5 do
				local victim = victims[rng:NextInteger(1, math.max(1, #victims))]
				local character = if victim then victim.Character else nil
				local center = if character then character:GetPivot().Position else boss.root.Position
				local spot = center + Vector3.new(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7))
				if lava then
					local origin = boss.root.Position + Vector3.new(0, 6, 0)
					Hazards.lavaBomb(
						spot,
						math.round(boss.damage * 0.7),
						6,
						1.3 + index * 0.2,
						origin,
						`Jefe {boss.id}`
					)
				else
					Hazards.fallingRock(
						spot,
						math.round(boss.damage * 0.7),
						6,
						color,
						1.1 + index * 0.2,
						`Jefe {boss.id}`
					)
				end
			end
		end,
		charge = function(boss, _special, _target, targetRoot)
			bubble(boss, "¡!")
			task.delay(0.6, function()
				if current ~= boss then
					return
				end
				local offset = (targetRoot.Position - boss.root.Position) * Vector3.new(1, 0, 1)
				if offset.Magnitude < 1 then
					return
				end
				boss.root.AssemblyLinearVelocity = offset.Unit * 90 + Vector3.new(0, 8, 0)
				local hit: { [Player]: boolean } = {}
				for _ = 1, 6 do
					task.wait(0.1)
					for _, player in playersAround(boss.root.Position, 9) do
						if not hit[player] then
							hit[player] = true
							if CombatService.damagePlayer(player, boss.damage, false, boss.model) then
								Status.holdPlayer(player, 1, `Jefe {boss.id}`)
							end
						end
					end
				end
			end)
		end,
		grab = function(boss, _special, target, targetRoot)
			if (targetRoot.Position - boss.root.Position).Magnitude > boss.definition.attackRange * 1.6 then
				return
			end
			bubble(boss, "¡TE TENGO!")
			if
				CombatService.damagePlayer(target, math.round(boss.damage * 0.6), false, boss.model)
				and Status.holdPlayer(target, 3, `Jefe {boss.id}`)
			then
				Remotes.Notify:FireClient(target, "🦧 ¡El jefe te ha agarrado! Que te ayuden tus compañeros")
			end
		end,
		extinguish = function(boss)
			bubble(boss, "¡GRRROOOAAAR!")
			for _, player in playersAround(boss.root.Position, 45) do
				local character = player.Character
				local tool = if character then character:FindFirstChildOfClass("Tool") else nil
				local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
				if tool and humanoid and tool:GetAttribute("WeaponId") == "Torch" then
					humanoid:UnequipTools()
					Remotes.Notify:FireClient(player, "🌑 ¡El rugido ha apagado tu antorcha!")
				end
				Status.holdPlayer(player, 1, `Jefe {boss.id}`)
			end
		end,
	}

local function updatePhase(boss: ActiveBoss)
	local fraction = boss.humanoid.Health / boss.humanoid.MaxHealth
	local phase = if fraction <= 0.33 then 3 elseif fraction <= 0.66 then 2 else 1
	if phase <= boss.phase then
		return
	end
	boss.phase = phase
	-- Su probabilidad de crítico depende de la fase (Shared/Crit).
	boss.model:SetAttribute("BossPhase", phase)
	boss.damage = math.round(boss.definition.damage * (1 + 0.2 * (phase - 1)))
	bubble(boss, "😡")
	Sfx.play("BossRoar", boss.root)
	MonkeyAnimator.play(boss.model, "Roar")
	announce(`😡 ¡{boss.definition.name} se enfurece! (fase {phase}/3)`)
	for _, listener in phaseListeners do
		task.spawn(listener, boss.id, phase)
	end
end

local function tick(now: number)
	local boss = current
	if not boss or boss.humanoid.Health <= 0 then
		return
	end
	rescaleHealth(boss)
	updatePhase(boss)
	-- Habilidades de los roles (Combat/Status): aturdido no hace nada y ralentizado anda más despacio.
	if Status.isStunned(boss.model) then
		if boss.channelUntil > now then
			boss.channelUntil = 0
			MonkeyAnimator.stop(boss.model, "Invoke")
		end
		boss.humanoid:MoveTo(boss.root.Position)
		return
	end
	-- Invocando: quieto, sin golpear, hasta que acaba.
	if boss.channelUntil > now then
		boss.humanoid:MoveTo(boss.root.Position)
		return
	elseif boss.channelUntil > 0 then
		boss.channelUntil = 0
		MonkeyAnimator.stop(boss.model, "Invoke")
	end
	local speed = boss.definition.walkSpeed * (1 + 0.15 * (boss.phase - 1)) * Status.speedFactor(boss.model)
	if boss.humanoid.WalkSpeed ~= speed then
		boss.humanoid.WalkSpeed = speed
	end
	local target, targetRoot = nearestTarget(boss)
	-- Provocado por el "Grito de guerra" de un guerrero: va a por él aunque haya otro más cerca.
	local taunter = Status.tauntTarget(boss.model)
	local taunterRoot = if taunter and taunter.Character
		then taunter.Character:FindFirstChild("HumanoidRootPart")
		else nil
	if
		taunter
		and taunterRoot
		and taunterRoot:IsA("BasePart")
		and LifeState.isAlive(taunter)
		and taunter:GetAttribute("InBasecamp") ~= true
	then
		target, targetRoot = taunter, taunterRoot
	end
	if not (target and targetRoot) then
		if (boss.root.Position - boss.lair).Magnitude > 12 then
			boss.humanoid:MoveTo(boss.lair)
		end
		return
	end
	boss.fightingUntil = now + FIGHT_GRACE_SECONDS

	local distance = (targetRoot.Position - boss.root.Position).Magnitude
	if now >= boss.nextSpecialAt then
		for _, special in boss.definition.specials do
			local channel = special.channelFromPhase ~= nil and boss.phase >= special.channelFromPhase
			-- La invocación no se lanza en plena pelea cuerpo a cuerpo: espera a que haya distancia.
			local ready = not (channel and distance <= boss.definition.attackRange)
			if ready and special.fromPhase <= boss.phase and now >= (boss.cooldowns[special.id] or 0) then
				boss.cooldowns[special.id] = now + special.cooldownSeconds
				boss.nextSpecialAt = now + 3
				local animation = if channel then "Invoke" else SPECIAL_ANIMATIONS[special.id]
				if animation then
					MonkeyAnimator.play(boss.model, animation)
				end
				if channel then
					boss.channelUntil = now + (special.channelSeconds or 2)
					boss.nextSpecialAt = boss.channelUntil + 2
					boss.humanoid:MoveTo(boss.root.Position)
				end
				SPECIALS[special.id](boss, special, target, targetRoot)
				if channel then
					return
				end
				break
			end
		end
	end

	if distance <= boss.definition.attackRange then
		boss.humanoid:MoveTo(boss.root.Position)
		if now - boss.lastAttackAt >= boss.definition.attackCooldownSeconds then
			boss.lastAttackAt = now
			MonkeyAnimator.play(boss.model, "Attack")
			if CombatService.damagePlayer(target, boss.damage, false, boss.model) then
				Sfx.play("BossAttack", boss.root)
			end
		end
	else
		boss.humanoid:MoveTo(targetRoot.Position)
	end
end

local function onPhaseStarted(day: number, phase: MatchState.Phase)
	local interval = Config.Match.BossIntervalDays
	if phase ~= "Day" or day % interval ~= 0 then
		return
	end
	local rotation = Config.Match.BossRotation
	local bossId = rotation[((day // interval) - 1) % #rotation + 1]
	if current then
		despawnCurrent(`🌫️ {current.definition.name} se retira a su guarida…`)
	end
	BossService.spawn(bossId)
end

function BossService:Init()
	DayNightService.onPhaseStarted(onPhaseStarted)
	CombatService.onEnemyDamaged(function(model, attacker)
		local boss = current
		if boss and attacker and model == boss.model then
			boss.contributors[attacker] = true
			boss.fightingUntil = os.clock() + FIGHT_GRACE_SECONDS
			boss.firstHitAt = boss.firstHitAt or os.clock()
		end
	end)
end

function BossService:Start()
	local elapsed = 0
	while true do
		task.wait(TICK_SECONDS)
		tick(os.clock())
		elapsed += TICK_SECONDS
		if elapsed >= 0.5 then
			elapsed = 0
			publish()
		end
	end
end

return BossService
