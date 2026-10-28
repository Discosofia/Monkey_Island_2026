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
--   - Fase 10, C6: sus ataques se ven venir (Combat/EnemyAttack). El golpe normal avisa
--     Config.Windup.BossSeconds y solo entra si al acabar sigues delante y a su alcance; se puede
--     bloquear y parar (el parry le tambalea la mitad). No se pueden bloquear ("‼"): el agarre (lo
--     atraviesa), la embestida y el pisotón (rompen la guardia) y lo que cae del cielo (Hazards).
--   - Fase 12: la rotación se repite (días 10, 12…) y en cada vuelta los jefes ya derrotados salen
--     más fuertes (Config.Match.BossRoundHealth y BossRoundDamage, "strength"); uno que aún no han
--     derrotado vuelve con su fuerza normal. Una pieza de baliza que ya se tiene no se vuelve a anunciar.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
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
local Strings = require(ReplicatedStorage.Shared.Strings)
local AbilityFx = require(ServerScriptService.Combat.AbilityFx)
local BasecampService = require(script.Parent.BasecampService)
local CombatService = require(ServerScriptService.Combat.Services.CombatService)
local DayNightService = require(script.Parent.DayNightService)
local InventoryService = require(script.Parent.InventoryService)
local MonkeyService = require(script.Parent.MonkeyService)
local TelemetryService = require(script.Parent.TelemetryService)
local TorchService = require(script.Parent.TorchService)
local Hazards = require(script.Parent.Parent.Combat.Hazards)
local EnemyAttack = require(ServerScriptService.Combat.EnemyAttack)
local Guard = require(ServerScriptService.Combat.Guard)
local Poof = require(ServerScriptService.Combat.Poof)
local Status = require(ServerScriptService.Combat.Status)
local MonkeyAnimator = require(script.Parent.Parent.Monkeys.MonkeyAnimator)
local MonkeyModels = require(script.Parent.Parent.Monkeys.MonkeyModels)

local TICK_SECONDS = 0.2
-- Segundos que sigue "peleando" (y suena su tema) después de perder a su objetivo o del último golpe.
local FIGHT_GRACE_SECONDS = 8
-- El pisotón aterriza a la vez que la onda de choque (Hazards.shockwave): grietas y piedras como el
-- Pisotón del guerrero (AbilityFxController "Quake").
local STOMP_RADIUS = 20
local STOMP_IMPACT_SECONDS = 0.9
local later = Strings.later

local BIOME_NAMES: { [string]: string } = {
	Rios = later("los ríos"),
	Montanas = later("las montañas"),
	Cuevas = later("las cuevas"),
	Volcan = later("el volcán"),
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
	strength: { health: number, damage: number }, -- multiplicadores de la vuelta de la rotación
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

-- Aviso a todos: plantilla en español y sus argumentos, que traduce cada cliente.
local function announce(text: string, args: { [string]: any }?)
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, text, args)
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

-- true mientras hay atributos de un jefe publicados (para borrarlos una sola vez al irse: sin jefe, el
-- administrador gigante usa los mismos atributos, GiantAdminService).
local published = false

local function publish()
	local boss = current
	if not boss then
		if published then
			published = false
			for _, name in
				{ "BossId", "BossName", "BossHealth", "BossMaxHealth", "BossPhase", "BossPosition", "BossFighting" }
			do
				ReplicatedStorage:SetAttribute(name, nil)
			end
		end
		return
	end
	published = true
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

local function despawnCurrent(reason: string?, args: { [string]: any }?)
	local boss = current
	if not boss then
		return
	end
	current = nil
	if reason then
		announce(reason, args)
	end
	boss.model:Destroy()
	publish()
end

local function onBossDied(boss: ActiveBoss)
	if current ~= boss then
		return
	end
	current = nil
	local newPiece = not Beacon.has(boss.id)
	Beacon.add(boss.id)
	local item = Items[boss.definition.lootItemId]
	local reported = false
	for player in boss.contributors do
		if player.Parent and not reported then
			reported = true
			TelemetryService.bossDefeated(player, boss.id, os.clock() - (boss.firstHitAt or os.clock()), boss.fighters)
		end
		if player.Parent then
			InventoryService.collect(player, boss.definition.lootItemId, Config.Bosses.LootPerPlayer)
			MatchStats.add(player, MatchStats.BOSSES)
			Remotes.Notify:FireClient(
				player,
				"🏆 Botín del jefe: {icon} {name} ×{n}",
				{ icon = item.icon, name = { item.name }, n = Config.Bosses.LootPerPlayer }
			)
			for _, listener in defeatListeners do
				task.spawn(listener, player, boss.id)
			end
		end
	end
	local bossName = { boss.definition.name }
	if newPiece then
		announce(
			"🏆 ¡{boss} ha caído! Pieza de la baliza: {pieces}/{total}",
			{ boss = bossName, pieces = #Beacon.pieces(), total = Beacon.total() }
		)
	else
		announce("🏆 ¡{boss} ha caído!", { boss = bossName })
	end
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
	local maxHealth = math.round(boss.definition.maxHealth * boss.strength.health * healthMultiplier(fighters))
	local health = math.max(1, fraction * maxHealth)
	if maxHealth < humanoid.MaxHealth then
		humanoid.Health = health
		humanoid.MaxHealth = maxHealth
	else
		humanoid.MaxHealth = maxHealth
		humanoid.Health = health
	end
end

-- true si hay un jefe despierto en la isla.
function BossService.isAlive(): boolean
	return current ~= nil
end

-- Multiplicadores de vida y daño de la vuelta "round" de la rotación (0 la primera).
local function strengthFor(round: number): { health: number, damage: number }
	local settings = Config.Match
	local cap = Config.Difficulty.MaxMultiplier
	return {
		health = math.min(cap, 1 + settings.BossRoundHealth * round),
		damage = math.min(cap, 1 + settings.BossRoundDamage * round),
	}
end

-- "round": la vuelta de la rotación (0 o nil la primera, Fase 12), para salir más fuerte.
function BossService.spawn(bossId: string, round: number?)
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
	local strength = strengthFor(round or 0)
	look.maxHealth = math.round(definition.maxHealth * strength.health * healthMultiplier(1))
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
		damage = math.round(definition.damage * strength.damage),
		cooldowns = {},
		nextSpecialAt = now + 4,
		lastAttackAt = 0,
		channelUntil = 0,
		fightingUntil = 0,
		contributors = {},
		fighters = 1,
		strength = strength,
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
	announce(
		"👑 ¡{boss} ha despertado en {place}!",
		{ boss = { definition.name }, place = { BIOME_NAMES[definition.biome] or definition.biome } }
	)
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
			bubble(boss, later("💥 ¡PUM!"))
			local position = boss.root.Position
			-- Quieto y con el "‼" hasta que cae la onda (que ya avisa en el suelo).
			EnemyAttack.windup(boss.model, STOMP_IMPACT_SECONDS, "Unblockable", function() end)
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
			bubble(boss, later("¡A MÍ, TROPA!"))
			local offset = Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
			MonkeyService.spawnAmbush(
				special.species or "AulladorRojo",
				boss.root.Position + offset,
				special.count or 3,
				target
			)
		end,
		rockRain = function(boss, special)
			bubble(boss, later("¡ROCAS!"))
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
		-- Avisa (Config.Windup.BossChargeSeconds, "‼") y sale hacia donde estés entonces. No se puede
		-- bloquear: a quien está en guardia se la rompe; hay que apartarse o esquivar.
		charge = function(boss, _special, _target, targetRoot)
			bubble(boss, later("¡!"))
			EnemyAttack.face(boss.model, targetRoot.Position)
			EnemyAttack.windup(boss.model, Config.Windup.BossChargeSeconds, "Unblockable", function()
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
							local unblockable = Guard.enemyHit(boss.model)
							unblockable.unblockable = true
							if
								CombatService.damagePlayer(
									player,
									boss.damage,
									false,
									boss.model,
									nil,
									nil,
									unblockable
								)
							then
								Status.stunPlayer(player, 1, `Jefe {boss.id}`)
							end
						end
					end
				end
			end)
		end,
		-- Avisa como su golpe ("‼") y agarra si al acabar sigues delante y cerca. El agarre atraviesa la
		-- guardia (no la gasta ni la rompe: te agarra igual); hay que apartarse o esquivar.
		grab = function(boss, _special, target, targetRoot)
			local reach = boss.definition.attackRange * 1.6
			if (targetRoot.Position - boss.root.Position).Magnitude > reach then
				return
			end
			bubble(boss, later("¡TE TENGO!"))
			EnemyAttack.face(boss.model, targetRoot.Position)
			EnemyAttack.windup(boss.model, Config.Windup.BossSeconds, "Unblockable", function()
				EnemyAttack.strike(boss.model, target, reach, function()
					if
						current == boss
						and CombatService.damagePlayer(target, math.round(boss.damage * 0.6), false, boss.model)
						and Status.holdPlayer(target, 3, `Jefe {boss.id}`)
					then
						Remotes.Notify:FireClient(
							target,
							"🦧 ¡El jefe te ha agarrado! Que te ayuden tus compañeros"
						)
					end
				end)
			end)
		end,
		extinguish = function(boss)
			bubble(boss, later("¡GRRROOOAAAR!"))
			for _, player in playersAround(boss.root.Position, 45) do
				-- La antorcha de la mano izquierda se apaga un rato (TorchService).
				if TorchService.douse(player, Config.Monkeys.TorchRoarOutSeconds) then
					Remotes.Notify:FireClient(player, "🌑 ¡El rugido ha apagado tu antorcha!")
				end
				Status.stunPlayer(player, 1, `Jefe {boss.id}`)
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
	boss.damage = math.round(boss.definition.damage * boss.strength.damage * (1 + 0.2 * (phase - 1)))
	bubble(boss, "😡")
	Sfx.play("BossRoar", boss.root)
	MonkeyAnimator.play(boss.model, "Roar")
	announce("😡 ¡{boss} se enfurece! (fase {phase}/3)", { boss = { boss.definition.name }, phase = phase })
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
	-- Preparando un ataque (Combat/EnemyAttack): quieto hasta que golpea.
	if EnemyAttack.busy(boss.model) then
		boss.humanoid:MoveTo(boss.root.Position)
		return
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
				if channel or EnemyAttack.busy(boss.model) then
					return
				end
				break
			end
		end
	end

	if distance <= boss.definition.attackRange then
		boss.humanoid:MoveTo(boss.root.Position)
		-- La recarga cuenta desde que empieza a preparar el golpe: el ritmo no cambia.
		if now - boss.lastAttackAt >= boss.definition.attackCooldownSeconds then
			boss.lastAttackAt = now
			local seconds = Config.Windup.BossSeconds
			EnemyAttack.face(boss.model, targetRoot.Position)
			boss.humanoid:MoveTo(boss.root.Position)
			-- Su golpe normal se puede bloquear y parar (Combat/Guard).
			local victim = target
			EnemyAttack.windup(boss.model, seconds, "Strike", function()
				EnemyAttack.strike(boss.model, victim, boss.definition.attackRange, function(hit)
					if current == boss then
						CombatService.damagePlayer(victim, boss.damage, false, boss.model, nil, nil, hit)
					end
				end)
			end)
			Sfx.play("BossAttack", boss.root)
			task.delay(math.max(0, seconds - Config.Windup.AttackLeadSeconds), function()
				if EnemyAttack.busy(boss.model) then
					MonkeyAnimator.play(boss.model, "Attack")
				end
			end)
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
	local index = (day // interval) - 1
	local bossId = rotation[index % #rotation + 1]
	if current then
		despawnCurrent(
			Strings.later("🌫️ {boss} se retira a su guarida…"),
			{ boss = { current.definition.name } }
		)
	end
	-- Solo vuelve más fuerte si ya lo derrotaron (su pieza está en la baliza): uno que se les resistió
	-- vuelve igual, para que el grupo atascado pueda conseguir su pieza.
	local round = if Beacon.has(bossId) then index // #rotation else 0
	BossService.spawn(bossId, round)
	if round > 0 then
		announce(
			"👑 {boss} vuelve más fuerte (vuelta {round})",
			{ boss = { Bosses[bossId].name }, round = round + 1 }
		)
	end
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
