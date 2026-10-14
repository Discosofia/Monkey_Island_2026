--!strict
-- Habilidades de los roles (Fase 3): 3 activas y una definitiva por rol (Data/Roles), con sus números
-- en Config.Abilities. El cliente (RoleController) pide usar la del hueco 1-4 con la dirección en la
-- que apunta; aquí se comprueba el tiempo de espera y se aplica todo.
--   - Guerrero: Torbellino, Embestida, Grito de guerra y Golpe sísmico.
--   - Cazador: Disparo múltiple, Marcar presas, Trampa de lianas y Lluvia de proyectiles.
--   - Mago: Bola de fuego, Nova de hielo, Parpadeo y Rayo encadenado.
--   - Médico: Ungüento en área, Dardo curativo, Escudo de hojas y Tótem sanador.
-- Los movimientos (Embestida y Parpadeo) los hace el cliente, que es quien mueve a su personaje; el
-- servidor pone el daño. Con PvP activo en los dos, las habilidades también afectan a otros jugadores,
-- con menos daño y aturdimientos más cortos. Los estados de los monos están en Combat/Status.
-- El cliente ve cuándo vuelve a estar lista cada una con el atributo "AbilityReadyAt<hueco>".

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local CombatService = require(script.Parent.CombatService)
local Status = require(script.Parent.Parent.Combat.Status)

local SETTINGS = Config.Abilities

-- Algo a lo que una habilidad puede dañar: un enemigo o un jugador con PvP.
type Target = { model: Model, humanoid: Humanoid, root: BasePart, player: Player? }
type Handler = (player: Player, character: Model, root: BasePart, aim: Vector3) -> boolean

local AbilityService = {}

local traps: { [Player]: { BasePart } } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function flat(vector: Vector3): Vector3
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	return if horizontal.Magnitude > 0.01 then horizontal.Unit else Vector3.zAxis
end

local function headOf(character: Model, root: BasePart): Vector3
	local head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.new(0, 1.5, 0)
end

local function effectPart(name: string, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	return part
end

-- Onda visible que se expande desde un punto.
local function pulse(position: Vector3, radius: number, color: Color3)
	local ring = effectPart("AbilityPulse", color, 0.5)
	ring.Shape = Enum.PartType.Ball
	ring.Size = Vector3.one * 2
	ring.Position = position
	ring.Parent = Workspace
	TweenService:Create(ring, TweenInfo.new(0.6), { Size = Vector3.one * radius * 2, Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.7)
end

-- Disco plano sobre el suelo (zona de la lluvia, trampa, tótem...).
local function disc(position: Vector3, radius: number, color: Color3, transparency: number): Part
	local part = effectPart("AbilityZone", color, transparency)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.2, radius * 2, radius * 2)
	part.CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = Workspace
	return part
end

-- Rayo visible entre dos puntos.
local function beam(from: Vector3, to: Vector3, color: Color3, width: number, seconds: number)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local part = effectPart("AbilityBeam", color, 0.1)
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Parent = Workspace
	TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 1 }):Play()
	Debris:AddItem(part, seconds)
end

local function groundBelow(position: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -200, 0), params)
	return if result then result.Position else position
end

local function enemyTarget(model: Instance): Target?
	if not model:IsA("Model") then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	if humanoid and humanoid.Health > 0 and root then
		return { model = model, humanoid = humanoid, root = root }
	end
	return nil
end

local function playerTarget(attacker: Player, victim: Player): Target?
	if not CombatService.canHitPlayer(attacker, victim) then
		return nil
	end
	local character = victim.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return { model = character, humanoid = humanoid, root = root, player = victim }
	end
	return nil
end

-- Enemigos vivos (y jugadores con PvP) a menos de "radius" de "center".
local function targetsAround(attacker: Player, center: Vector3, radius: number): { Target }
	local found: { Target } = {}
	for _, instance in CollectionService:GetTagged(Config.Combat.EnemyTag) do
		local target = enemyTarget(instance)
		if target and (target.root.Position - center).Magnitude <= radius then
			table.insert(found, target)
		end
	end
	for _, other in Players:GetPlayers() do
		local target = playerTarget(attacker, other)
		if target and (target.root.Position - center).Magnitude <= radius then
			table.insert(found, target)
		end
	end
	return found
end

local function targetFromPart(attacker: Player, part: Instance): Target?
	local model = CombatService.enemyFromPart(part)
	if model then
		return enemyTarget(model)
	end
	local victim = CombatService.playerFromPart(part)
	return if victim then playerTarget(attacker, victim) else nil
end

-- Daña a un objetivo; a los jugadores, menos.
local function hurt(attacker: Player, target: Target, amount: number)
	if target.humanoid.Health <= 0 then
		return
	end
	if target.player then
		CombatService.damagePvP(attacker, target.player, math.max(1, math.round(amount * SETTINGS.PvPDamageMultiplier)))
	else
		CombatService.damage(target.model, target.humanoid, math.max(1, math.round(amount)), attacker)
	end
end

-- Aturde, congela o inmoviliza. A un jugador lo deja quieto (atributo "StunnedUntil"), menos tiempo.
local function control(target: Target, seconds: number, look: ("Stun" | "Freeze" | "Root")?)
	if target.player then
		target.player:SetAttribute("StunnedUntil", now() + seconds * SETTINGS.PvPControlMultiplier)
	else
		Status.stun(target.model, seconds, look)
	end
end

local function heal(player: Player, amount: number): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (humanoid and humanoid.Health > 0 and LifeState.isAlive(player)) then
		return false
	end
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	return true
end

-- Disparo recto desde "origin": devuelve dónde acaba y a quién alcanza. "radius" da algo de margen.
local function castShot(
	character: Model,
	origin: Vector3,
	direction: Vector3,
	range: number,
	radius: number
): (Vector3, RaycastResult?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = Workspace:Spherecast(origin, radius, direction * range, params)
	if result then
		return result.Position, result
	end
	return origin + direction * range, nil
end

-- El objetivo mejor alineado con la puntería, dentro de un cono, al alcance y sin nada en medio.
local function bestInCone(
	attacker: Player,
	character: Model,
	origin: Vector3,
	aim: Vector3,
	range: number,
	degrees: number
): Target?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local best: Target? = nil
	local bestAngle = math.rad(degrees)
	for _, target in targetsAround(attacker, origin, range) do
		local offset = target.root.Position - origin
		local angle = math.acos(math.clamp(offset.Unit:Dot(aim), -1, 1))
		if angle <= bestAngle then
			params.FilterDescendantsInstances = { character, target.model }
			if not Workspace:Raycast(origin, offset, params) then
				best = target
				bestAngle = angle
			end
		end
	end
	return best
end

-- ===================================== Guerrero =====================================

local function whirlwind(player: Player, _character: Model, root: BasePart): boolean
	local seconds = Progression.perk(player, "WhirlwindSeconds")
	local damage = SETTINGS.WhirlwindDamage * Progression.perk(player, "MeleeDamage")
	local hits = math.max(1, math.round(seconds / SETTINGS.WhirlwindInterval))

	-- Anillo que gira alrededor del guerrero mientras dura.
	local ring = effectPart("Whirlwind", Color3.fromRGB(255, 200, 120), 0.65)
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, SETTINGS.WhirlwindRadius * 2, SETTINGS.WhirlwindRadius * 2)
	ring.Parent = Workspace
	local angle = 0
	local follow = RunService.Heartbeat:Connect(function(deltaTime)
		angle += deltaTime * 12
		ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 1.5, 0))
			* CFrame.Angles(0, angle, 0)
			* CFrame.Angles(0, 0, math.rad(90))
	end)
	task.spawn(function()
		for _ = 1, hits do
			if not (root.Parent and LifeState.isAlive(player)) then
				break
			end
			Sfx.play("Swing", root)
			for _, target in targetsAround(player, root.Position, SETTINGS.WhirlwindRadius) do
				hurt(player, target, damage)
			end
			task.wait(SETTINGS.WhirlwindInterval)
		end
		follow:Disconnect()
		ring:Destroy()
	end)
	return true
end

local function charge(player: Player, _character: Model, root: BasePart, aim: Vector3): boolean
	local damage = SETTINGS.ChargeDamage
		* Progression.perk(player, "MeleeDamage")
		* Progression.perk(player, "ChargeDamage")
	local direction = flat(aim)
	local hit: { [Model]: boolean } = {}
	Sfx.play("Swing", root)
	-- El cliente mueve al personaje; aquí se va mirando por dónde pasa.
	task.spawn(function()
		local finish = os.clock() + SETTINGS.ChargeSeconds + 0.15
		while os.clock() < finish and root.Parent do
			for _, target in targetsAround(player, root.Position, SETTINGS.ChargeWidth) do
				if not hit[target.model] then
					hit[target.model] = true
					hurt(player, target, damage)
					if not target.player and not Status.isBoss(target.model) then
						target.root.AssemblyLinearVelocity = direction * SETTINGS.ChargeKnockback
							+ Vector3.new(0, 20, 0)
					end
				end
			end
			task.wait(0.05)
		end
	end)
	return true
end

local function warCry(player: Player, _character: Model, root: BasePart): boolean
	local seconds = SETTINGS.WarCrySeconds
	local taunted = 0
	for _, target in targetsAround(player, root.Position, SETTINGS.WarCryRadius) do
		if not target.player then
			Status.taunt(target.model, player, seconds)
			taunted += 1
		end
	end
	player:SetAttribute("GuardUntil", now() + seconds)
	player:SetAttribute("GuardReduction", Progression.perk(player, "WarCryReduction"))
	pulse(root.Position, SETTINGS.WarCryRadius * 0.5, Color3.fromRGB(230, 60, 40))
	local reduction = math.round(Progression.perk(player, "WarCryReduction") * 100)
	Remotes.Notify:FireClient(
		player,
		`⚔️ ¡{taunted} mono(s) van a por ti! Recibes un {reduction} % menos de daño`
	)
	return true
end

local function quake(player: Player, character: Model, root: BasePart): boolean
	local damage = SETTINGS.QuakeDamage * Progression.perk(player, "MeleeDamage")
	local stun = Progression.perk(player, "QuakeStun")
	local ground = groundBelow(root.Position, { character })
	for _, target in targetsAround(player, root.Position, SETTINGS.QuakeRadius) do
		hurt(player, target, damage)
		control(target, stun, "Stun")
	end
	Sfx.play("RockImpact", root)
	local zone = disc(ground, 2, Color3.fromRGB(150, 110, 70), 0.3)
	TweenService:Create(zone, TweenInfo.new(0.5), {
		Size = Vector3.new(0.2, SETTINGS.QuakeRadius * 2, SETTINGS.QuakeRadius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(zone, 0.6)
	return true
end

-- ===================================== Cazador =====================================

local function multiShot(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local count = math.max(1, math.floor(Progression.perk(player, "MultiShotCount")))
	local damage = SETTINGS.MultiShotDamage * Progression.perk(player, "RangedDamage")
	local origin = headOf(character, root)
	local spread = math.rad(SETTINGS.MultiShotSpreadDegrees)
	Sfx.play("Shoot", root)
	for index = 1, count do
		local angle = if count == 1 then 0 else -spread / 2 + spread * (index - 1) / (count - 1)
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(aim)
		local endPoint, result = castShot(character, origin, direction, SETTINGS.MultiShotRange, 1)
		local seconds = CombatService.projectile("Arrow", origin, endPoint, 200)
		local target = if result then targetFromPart(player, result.Instance) else nil
		if target then
			task.delay(seconds, hurt, player, target, damage)
		end
	end
	return true
end

local function markPrey(player: Player, _character: Model, root: BasePart): boolean
	local seconds = Progression.perk(player, "MarkSeconds")
	local bonus = Progression.perk(player, "MarkedBonus")
	local untilTime = now() + seconds
	local marked = 0
	for _, enemy in CollectionService:GetTagged(Config.Combat.EnemyTag) do
		if enemy:IsA("Model") then
			local distance = (enemy:GetPivot().Position - root.Position).Magnitude
			if distance <= SETTINGS.MarkRadius then
				enemy:SetAttribute("MarkedUntil", untilTime)
				enemy:SetAttribute("MarkBonus", bonus)
				local highlight = Instance.new("Highlight")
				highlight.Name = "PreyMark"
				highlight.FillTransparency = 1
				highlight.OutlineColor = Color3.fromRGB(255, 70, 50)
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = enemy
				Debris:AddItem(highlight, seconds)
				marked += 1
			end
		end
	end
	pulse(root.Position, 12, Color3.fromRGB(255, 90, 60))
	Remotes.Notify:FireClient(player, `🏹 {marked} presa(s) marcada(s) durante {seconds} s`)
	return true
end

local function trap(player: Player, character: Model, root: BasePart): boolean
	local own = traps[player] or {}
	traps[player] = own
	-- Como mucho TrapMaxActive a la vez: la más vieja desaparece.
	while #own >= SETTINGS.TrapMaxActive do
		local oldest = table.remove(own, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local position = groundBelow(root.Position, { character })
	local base = disc(position, SETTINGS.TrapRadius, Color3.fromRGB(70, 140, 50), 0.35)
	base.Name = "VineTrap"
	base.Material = Enum.Material.Grass
	for index = 1, 4 do
		local vine = effectPart("Vine", Color3.fromRGB(60, 110, 40), 0)
		vine.Material = Enum.Material.Grass
		vine.Size = Vector3.new(0.25, 0.25, SETTINGS.TrapRadius * 1.6)
		vine.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, index * math.pi / 4, 0)
		vine.Parent = base
	end
	table.insert(own, base)
	Sfx.play("Build", root)

	local damage = SETTINGS.TrapDamage * Progression.perk(player, "RangedDamage")
	local seconds = Progression.perk(player, "TrapRoot")
	task.spawn(function()
		local expires = os.clock() + SETTINGS.TrapLifetime
		while base.Parent and os.clock() < expires and player.Parent do
			local victim = targetsAround(player, position, SETTINGS.TrapRadius + 1)[1]
			if victim then
				hurt(player, victim, damage)
				control(victim, seconds, "Root")
				Sfx.play("Hit", base)
				break
			end
			task.wait(0.1)
		end
		local index = table.find(own, base)
		if index then
			table.remove(own, index)
		end
		base:Destroy()
	end)
	return true
end

local function arrowRain(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	local endPoint = castShot(character, origin, aim, SETTINGS.RainMaxDistance, 0.5)
	local center = groundBelow(endPoint, { character })
	local zone = disc(center, SETTINGS.RainRadius, Color3.fromRGB(255, 90, 60), 0.75)
	local damage = SETTINGS.RainDamage
		* Progression.perk(player, "RangedDamage")
		* Progression.perk(player, "RainDamage")
	local interval = SETTINGS.RainSeconds / SETTINGS.RainTicks
	local rng = Random.new()
	Sfx.play("Shoot", root)
	task.spawn(function()
		for _ = 1, SETTINGS.RainTicks do
			-- Unas cuantas flechas que caen sobre la zona.
			for _ = 1, 5 do
				local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * SETTINGS.RainRadius * 0.8
				local landing = center + offset
				CombatService.projectile("Arrow", landing + Vector3.new(2, 30, 0), landing, 140)
			end
			task.wait(0.2)
			for _, target in targetsAround(player, center, SETTINGS.RainRadius) do
				hurt(player, target, damage)
			end
			task.wait(math.max(0, interval - 0.2))
		end
		zone:Destroy()
	end)
	return true
end

-- ===================================== Mago =====================================

local function fireball(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local scale = Progression.perk(player, "SpellDamage") * Progression.perk(player, "FireballDamage")
	local origin = headOf(character, root)
	local endPoint, result = castShot(character, origin, aim, SETTINGS.FireballRange, 1.5)
	local direct = if result then targetFromPart(player, result.Instance) else nil
	local seconds, ball =
		CombatService.projectile("Spell", origin, endPoint, SETTINGS.FireballSpeed, Color3.fromRGB(255, 120, 30))
	ball.Size = Vector3.one * 1.6
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Parent = ball
	Sfx.play("Shoot", root)
	task.delay(seconds, function()
		pulse(endPoint, SETTINGS.FireballSplashRadius, Color3.fromRGB(255, 120, 30))
		Sfx.play("LavaImpact", ball)
		if direct then
			hurt(player, direct, SETTINGS.FireballDamage * scale)
		end
		for _, target in targetsAround(player, endPoint, SETTINGS.FireballSplashRadius) do
			if not (direct and target.model == direct.model) then
				hurt(player, target, SETTINGS.FireballSplashDamage * scale)
			end
		end
	end)
	return true
end

local function frostNova(player: Player, _character: Model, root: BasePart): boolean
	local damage = SETTINGS.NovaDamage * Progression.perk(player, "SpellDamage")
	local freeze = Progression.perk(player, "NovaFreeze")
	for _, target in targetsAround(player, root.Position, SETTINGS.NovaRadius) do
		hurt(player, target, damage)
		control(target, freeze, "Freeze")
		if not target.player then
			Status.slow(target.model, freeze + SETTINGS.NovaSlowSeconds, SETTINGS.NovaSlowFactor)
		end
	end
	pulse(root.Position, SETTINGS.NovaRadius, Color3.fromRGB(140, 210, 255))
	Sfx.play("Hit", root)
	return true
end

local function blink(_player: Player, _character: Model, root: BasePart): boolean
	-- El cliente ya se ha movido (o está a punto): destellos en la salida y en la llegada.
	pulse(root.Position, 4, Color3.fromRGB(170, 110, 255))
	Sfx.play("Pickup", root)
	task.delay(0.15, function()
		if root.Parent then
			pulse(root.Position, 4, Color3.fromRGB(170, 110, 255))
		end
	end)
	return true
end

local function chainLightning(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	local first = bestInCone(player, character, origin, aim, SETTINGS.ChainRange, 25)
	if not first then
		Remotes.Notify:FireClient(player, "🔮 No hay ningún mono a tiro: apunta hacia uno")
		return false
	end
	local jumps = math.floor(Progression.perk(player, "ChainJumps"))
	local damage = SETTINGS.ChainDamage * Progression.perk(player, "SpellDamage")
	local color = Color3.fromRGB(255, 240, 120)
	Sfx.play("LavaLaunch", root)
	task.spawn(function()
		local hit: { [Model]: boolean } = {}
		local current: Target? = first
		local from = origin
		for _ = 0, jumps do
			local target = current
			if not target then
				break
			end
			hit[target.model] = true
			beam(from, target.root.Position, color, 0.4, 0.3)
			hurt(player, target, damage)
			damage *= SETTINGS.ChainFalloff
			from = target.root.Position
			-- Siguiente: el más cercano que aún no ha recibido el rayo.
			local nextTarget: Target? = nil
			local nextDistance = SETTINGS.ChainJumpRange
			for _, candidate in targetsAround(player, from, SETTINGS.ChainJumpRange) do
				local distance = (candidate.root.Position - from).Magnitude
				if not hit[candidate.model] and distance <= nextDistance then
					nextTarget = candidate
					nextDistance = distance
				end
			end
			current = nextTarget
			task.wait(0.08)
		end
	end)
	return true
end

-- ===================================== Médico =====================================

local function areaHeal(player: Player, _character: Model, root: BasePart): boolean
	local amount = SETTINGS.AreaHealAmount * Progression.perk(player, "HealPower")
	local healed = 0
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local otherRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local near = otherRoot
			and otherRoot:IsA("BasePart")
			and (otherRoot.Position - root.Position).Magnitude <= SETTINGS.AreaHealRadius
		if near and heal(other, amount) then
			healed += 1
		end
	end
	pulse(root.Position, SETTINGS.AreaHealRadius, Color3.fromRGB(110, 240, 140))
	Sfx.play("Heal", root)
	Remotes.Notify:FireClient(player, `⛑️ Has curado a {healed} jugador(es)`)
	return true
end

local function healingDart(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	local endPoint, result = castShot(character, origin, aim, SETTINGS.DartRange, 1.5)
	local seconds =
		CombatService.projectile("Spell", origin, endPoint, SETTINGS.DartSpeed, Color3.fromRGB(110, 240, 140))
	Sfx.play("Shoot", root)
	if not result then
		return true
	end
	local ally = CombatService.playerFromPart(result.Instance)
	local enemy = if ally then nil else targetFromPart(player, result.Instance)
	task.delay(seconds, function()
		if ally and heal(ally, SETTINGS.DartHeal * Progression.perk(player, "HealPower")) then
			local allyCharacter = ally.Character
			local allyRoot = if allyCharacter then allyCharacter:FindFirstChild("HumanoidRootPart") else nil
			if allyRoot and allyRoot:IsA("BasePart") then
				pulse(allyRoot.Position, 4, Color3.fromRGB(110, 240, 140))
				Sfx.play("Heal", allyRoot)
			end
			Remotes.Notify:FireClient(player, `⛑️ Dardo curativo a {ally.DisplayName}`)
		elseif enemy then
			hurt(player, enemy, SETTINGS.DartDamage)
		end
	end)
	return true
end

local function leafShield(player: Player, character: Model, root: BasePart): boolean
	-- El aliado vivo más cercano; si no hay ninguno al alcance, el propio médico.
	local chosen = player
	local chosenCharacter = character
	local bestDistance = SETTINGS.ShieldRange
	for _, other in Players:GetPlayers() do
		local otherCharacter = other.Character
		local otherRoot = if otherCharacter then otherCharacter:FindFirstChild("HumanoidRootPart") else nil
		if
			other ~= player
			and otherCharacter
			and otherRoot
			and otherRoot:IsA("BasePart")
			and LifeState.isAlive(other)
		then
			local distance = (otherRoot.Position - root.Position).Magnitude
			if distance <= bestDistance then
				chosen = other
				chosenCharacter = otherCharacter
				bestDistance = distance
			end
		end
	end
	local amount = Progression.perk(player, "ShieldAmount")
	chosen:SetAttribute("ShieldHealth", amount)
	chosen:SetAttribute("ShieldUntil", now() + SETTINGS.ShieldSeconds)
	local old = chosenCharacter:FindFirstChild("LeafShield")
	if old then
		old:Destroy()
	end
	local glow = Instance.new("Highlight")
	glow.Name = "LeafShield"
	glow.FillColor = Color3.fromRGB(90, 200, 90)
	glow.FillTransparency = 0.7
	glow.OutlineColor = Color3.fromRGB(150, 255, 130)
	glow.Parent = chosenCharacter
	Debris:AddItem(glow, SETTINGS.ShieldSeconds)
	Sfx.play("Heal", root)
	if chosen ~= player then
		Remotes.Notify:FireClient(chosen, `🍃 {player.DisplayName} te protege con un escudo de {amount}`)
		Remotes.Notify:FireClient(player, `🍃 Escudo de {amount} para {chosen.DisplayName}`)
	else
		Remotes.Notify:FireClient(player, `🍃 Te proteges con un escudo de {amount}`)
	end
	return true
end

local function healingTotem(player: Player, character: Model, root: BasePart): boolean
	local position = groundBelow(root.Position, { character })
	local totem = Instance.new("Model")
	totem.Name = "HealingTotem"
	local pole = effectPart("Pole", Color3.fromRGB(110, 72, 40), 0)
	pole.Material = Enum.Material.Wood
	pole.Size = Vector3.new(0.8, 5, 0.8)
	pole.Position = position + Vector3.new(0, 2.5, 0)
	pole.Parent = totem
	local top = effectPart("Top", Color3.fromRGB(110, 240, 140), 0.1)
	top.Shape = Enum.PartType.Ball
	top.Size = Vector3.one * 1.4
	top.Position = position + Vector3.new(0, 5.4, 0)
	top.Parent = totem
	local light = Instance.new("PointLight")
	light.Color = top.Color
	light.Range = SETTINGS.TotemRadius
	light.Parent = top
	local zone = disc(position, SETTINGS.TotemRadius, Color3.fromRGB(110, 240, 140), 0.8)
	zone.Parent = totem
	totem.Parent = Workspace
	Sfx.play("Build", root)

	local amount = SETTINGS.TotemHealPerSecond * Progression.perk(player, "HealPower")
	task.spawn(function()
		for _ = 1, SETTINGS.TotemSeconds do
			task.wait(1)
			for _, other in Players:GetPlayers() do
				local otherCharacter = other.Character
				local otherRoot = if otherCharacter then otherCharacter:FindFirstChild("HumanoidRootPart") else nil
				if
					otherRoot
					and otherRoot:IsA("BasePart")
					and (otherRoot.Position - position).Magnitude <= SETTINGS.TotemRadius
				then
					heal(other, amount)
				end
			end
			pulse(top.Position, 3, Color3.fromRGB(110, 240, 140))
		end
		totem:Destroy()
	end)
	Remotes.Notify:FireClient(player, `⛑️ Tótem sanador durante {SETTINGS.TotemSeconds} s`)
	return true
end

local HANDLERS: { [string]: Handler } = {
	Whirlwind = whirlwind,
	Charge = charge,
	WarCry = warCry,
	Quake = quake,
	MultiShot = multiShot,
	MarkPrey = markPrey,
	Trap = trap,
	ArrowRain = arrowRain,
	Fireball = fireball,
	FrostNova = frostNova,
	Blink = blink,
	ChainLightning = chainLightning,
	AreaHeal = areaHeal,
	HealingDart = healingDart,
	LeafShield = leafShield,
	HealingTotem = healingTotem,
}

local function onUseAbility(player: Player, slot: any, aim: any)
	if typeof(slot) ~= "number" or typeof(aim) ~= "Vector3" or aim.Magnitude < 0.5 then
		return
	end
	local roleId = player:GetAttribute("Role")
	local role = if typeof(roleId) == "string" then Roles[roleId] else nil
	local ability = if role then role.abilities[slot] else nil
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (ability and character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return
	end
	if not LifeState.isAlive(player) then
		return
	end
	local readyAt = player:GetAttribute(`AbilityReadyAt{slot}`)
	-- Pequeño margen por el retraso de la red (el cliente ya comprobó el tiempo de espera).
	if typeof(readyAt) == "number" and now() < readyAt - 0.25 then
		return
	end
	local handler = HANDLERS[ability.id]
	if handler and handler(player, character, root, aim.Unit) then
		local cooldown = ability.cooldownSeconds * Progression.perk(player, "CooldownRate")
		player:SetAttribute(`AbilityReadyAt{slot}`, now() + cooldown)
	end
end

function AbilityService:Start()
	Remotes.UseAbility.OnServerEvent:Connect(onUseAbility)
	Players.PlayerRemoving:Connect(function(player)
		for _, part in traps[player] or {} do
			part:Destroy()
		end
		traps[player] = nil
	end)
end

return AbilityService
