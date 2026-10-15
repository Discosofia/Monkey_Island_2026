--!strict
-- Habilidades de los roles (Fase 3): 3 activas y una definitiva por rol (Data/Roles), con sus números
-- en Config.Abilities. El cliente (RoleController) pide usar la del hueco 1-4 con la dirección en la
-- que apunta; aquí se comprueba el tiempo de espera y se aplica todo.
--   - Guerrero: Torbellino, Embestida, Grito de guerra y Pisotón (id "Quake").
--   - Cazador: Disparo múltiple, Marcar presas, Cepo y Lluvia de proyectiles.
--   - Mago: Bola de fuego, Nova de hielo, Parpadeo y Rayo encadenado.
--   - Médico: Ungüento en área, Dardo curativo, Escudo de hojas y Tótem sanador.
-- Los movimientos (Embestida y Parpadeo) los hace el cliente, que es quien mueve a su personaje; el
-- servidor pone el daño. Lo que se ve lo dibuja cada cliente (Combat/AbilityFx y AbilityFxController),
-- salvo el Cepo, que es una pieza del mundo. Con PvP activo en los dos, las habilidades también
-- afectan a otros jugadores, con menos daño y aturdimientos más cortos. Los estados de los monos están en Combat/Status.
-- El cliente ve cuándo vuelve a estar lista cada una con el atributo "AbilityReadyAt<hueco>".
-- Combos (Data/Combos, ComboService): la primera habilidad del combo marca lo que toca; las
-- siguientes, enlazadas a tiempo, hacen críticos seguros contra los marcados y el remate un efecto
-- extra. Los demás golpes pueden ser críticos con la probabilidad del arma (Shared/Crit).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Survival = require(ReplicatedStorage.Shared.Survival)
local ComboService = require(script.Parent.ComboService)
local CombatService = require(script.Parent.CombatService)
local AbilityFx = require(script.Parent.Parent.Combat.AbilityFx)
local Status = require(script.Parent.Parent.Combat.Status)

local SETTINGS = Config.Abilities
local COMBO = Config.Combo
-- Velocidad (studs/s) de las flechas del Disparo múltiple.
local ARROW_SPEED = 200
-- Radio de las mandíbulas del cepo y cuánto se cierran (casi 90°: quedan de pie, una contra otra).
local TRAP_JAW_RADIUS = 1.5
local TRAP_CLOSED_ANGLE = math.rad(84)
-- Lo más lejos del personaje que se acepta el "desde/hasta" del Parpadeo que manda el cliente.
local BLINK_POINT_SLACK = 15

-- Algo a lo que una habilidad puede dañar: un enemigo o un jugador con PvP.
type Target = { model: Model, humanoid: Humanoid, root: BasePart, player: Player? }
type Handler = (player: Player, character: Model, root: BasePart, aim: Vector3, extra: { any }) -> boolean

local AbilityService = {}

local traps: { [Player]: { Model } } = {}

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

-- Daña a un objetivo con la habilidad "abilityId"; a los jugadores, menos. Es crítico seguro si la
-- habilidad está enlazada en el combo y el objetivo lleva su marca; si no, con la probabilidad del arma.
local function hurt(attacker: Player, target: Target, amount: number, abilityId: string)
	if target.humanoid.Health <= 0 then
		return
	end
	if target.player then
		CombatService.damagePvP(
			attacker,
			target.player,
			math.max(1, math.round(amount * SETTINGS.PvPDamageMultiplier)),
			CombatService.rollPlayerCrit(attacker)
		)
	else
		local crit = ComboService.isComboHit(attacker, target.model, abilityId)
			or CombatService.rollPlayerCrit(attacker)
		CombatService.damage(target.model, target.humanoid, math.max(1, math.round(amount)), attacker, { crit = crit })
	end
end

-- La primera habilidad del combo tocó a un enemigo (no a otro jugador en PvP): lo marca.
local function comboOpener(player: Player, abilityId: string, target: Target)
	if not target.player then
		ComboService.opener(player, abilityId, target.model)
	end
end

-- Aturde, congela o inmoviliza. A un jugador lo deja quieto (atributo "StunnedUntil"), menos tiempo.
-- Congelado e inmovilizado se ven en los clientes (bloque de hielo y brillo verde).
local function control(target: Target, seconds: number, look: ("Stun" | "Freeze" | "Root")?)
	local duration = seconds
	if target.player then
		duration *= SETTINGS.PvPControlMultiplier
		target.player:SetAttribute("StunnedUntil", now() + duration)
	else
		duration = Status.stun(target.model, seconds, look)
	end
	if look == "Freeze" then
		AbilityFx.all("Frozen", target.model, duration)
	elseif look == "Root" then
		AbilityFx.all("Rooted", target.model, duration)
	end
end

-- El médico ("healer") cura a "player" con "abilityId". Puede ser crítica (Shared/Crit) y lo es seguro
-- si es el remate de su combo. Devuelve false si no se le puede curar (caído, Espíritu…).
local function heal(healer: Player, player: Player, amount: number, abilityId: string): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (humanoid and humanoid.Health > 0 and LifeState.isAlive(player)) then
		return false
	end
	CombatService.heal(player, amount, healer, { canCrit = true, crit = ComboService.isPayoff(healer, abilityId) })
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

local function whirlwind(player: Player, character: Model, root: BasePart): boolean
	local seconds = Progression.perk(player, "WhirlwindSeconds")
	local damage = SETTINGS.WhirlwindDamage * Progression.perk(player, "MeleeDamage")
	local hits = math.max(1, math.round(seconds / SETTINGS.WhirlwindInterval))
	AbilityFx.others(player, "Whirlwind", character, seconds)
	task.spawn(function()
		for _ = 1, hits do
			if not (root.Parent and LifeState.isAlive(player)) then
				break
			end
			Sfx.play("Swing", root)
			for _, target in targetsAround(player, root.Position, SETTINGS.WhirlwindRadius) do
				hurt(player, target, damage, "Whirlwind")
			end
			task.wait(SETTINGS.WhirlwindInterval)
		end
	end)
	return true
end

local function charge(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local damage = SETTINGS.ChargeDamage
		* Progression.perk(player, "MeleeDamage")
		* Progression.perk(player, "ChargeDamage")
	local direction = flat(aim)
	local hit: { [Model]: boolean } = {}
	Sfx.play("Swing", root)
	AbilityFx.others(player, "Charge", character, SETTINGS.ChargeSeconds)
	-- El cliente mueve al personaje; aquí se va mirando por dónde pasa.
	task.spawn(function()
		local finish = os.clock() + SETTINGS.ChargeSeconds + 0.15
		while os.clock() < finish and root.Parent do
			for _, target in targetsAround(player, root.Position, SETTINGS.ChargeWidth) do
				if not hit[target.model] then
					hit[target.model] = true
					hurt(player, target, damage, "Charge")
					comboOpener(player, "Charge", target)
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

local function warCry(player: Player, character: Model, root: BasePart): boolean
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
	AbilityFx.all("WarCry", character, seconds)
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
		-- Remate del combo del guerrero: los desequilibrados se quedan aturdidos más tiempo.
		local finisher = ComboService.isComboHit(player, target.model, "Quake")
		hurt(player, target, damage, "Quake")
		control(target, if finisher then stun + COMBO.QuakeExtraStun else stun, "Stun")
	end
	Sfx.play("RockImpact", root)
	AbilityFx.all("Quake", ground, SETTINGS.QuakeRadius)
	return true
end

-- ===================================== Cazador =====================================

local function multiShot(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local count = math.max(1, math.floor(Progression.perk(player, "MultiShotCount")))
	local damage = SETTINGS.MultiShotDamage * Progression.perk(player, "RangedDamage")
	local origin = headOf(character, root)
	local spread = math.rad(SETTINGS.MultiShotSpreadDegrees)
	Sfx.play("Shoot", root)
	local endPoints = {}
	for index = 1, count do
		local angle = if count == 1 then 0 else -spread / 2 + spread * (index - 1) / (count - 1)
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(aim)
		local endPoint, result = castShot(character, origin, direction, SETTINGS.MultiShotRange, 1)
		table.insert(endPoints, endPoint)
		local target = if result then targetFromPart(player, result.Instance) else nil
		if target then
			task.delay((endPoint - origin).Magnitude / ARROW_SPEED, hurt, player, target, damage, "MultiShot")
		end
	end
	AbilityFx.all("MultiShot", origin, endPoints, ARROW_SPEED)
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
	-- Las dianas sobre las presas salen del atributo "MarkedUntil" en cada cliente.
	AbilityFx.all("MarkPrey", root.Position, SETTINGS.MarkRadius)
	Remotes.Notify:FireClient(player, `🏹 {marked} presa(s) marcada(s) durante {seconds} s`)
	return true
end

-- Pieza de metal oxidado del cepo.
local function trapPart(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.CorrodedMetal
	part.Color = color
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	return part
end

-- Cepo del cazador: dos mandíbulas en semicírculo con dientes, muelles, placa, cadena y estaca.
-- Devuelve el modelo, la placa (para el sonido) y "pose", que lo coloca en "origin" con las
-- mandíbulas levantadas "angle" radianes (0 abierto, TRAP_CLOSED_ANGLE cerrado).
local function bearTrap(): (Model, BasePart, (origin: CFrame, angle: number) -> ())
	local model = Instance.new("Model")
	model.Name = "BearTrap"
	-- "jaw": 0 las piezas fijas; 1 y -1 cada mandíbula, que gira sobre la bisagra (eje X).
	type Piece = { part: BasePart, offset: CFrame, jaw: number }
	local pieces: { Piece } = {}
	local function add(part: BasePart, offset: CFrame, jaw: number)
		part.Parent = model
		table.insert(pieces, { part = part, offset = offset, jaw = jaw })
	end
	local metal = Color3.fromRGB(78, 74, 70)
	local rust = Color3.fromRGB(125, 78, 48)
	local radius = TRAP_JAW_RADIUS

	add(trapPart("Hinge", Vector3.new(radius * 2 + 0.5, 0.2, 0.2), metal), CFrame.new(0, 0.1, 0), 0)
	for _, side in { -1, 1 } do
		add(trapPart("Spring", Vector3.new(1.4, 0.12, 0.4), rust), CFrame.new(side * (radius + 0.9), 0.08, 0), 0)
		add(
			trapPart("SpringEye", Vector3.new(0.12, 0.5, 0.5), metal, Enum.PartType.Cylinder),
			CFrame.new(side * (radius + 1.6), 0.2, 0),
			0
		)
	end
	local plate = trapPart("Plate", Vector3.new(0.1, 1.2, 1.2), rust, Enum.PartType.Cylinder)
	add(plate, CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), 0)
	for index = 1, 3 do
		add(
			trapPart("Chain", Vector3.new(0.12, 0.12, 0.45), metal),
			CFrame.new(radius + 1.6 + index * 0.4, 0.06, 0) * CFrame.Angles(0, math.rad(90), index % 2 * math.rad(90)),
			0
		)
	end
	local stake = trapPart("Stake", Vector3.new(0.25, 0.9, 0.25), Color3.fromRGB(110, 75, 45))
	stake.Material = Enum.Material.Wood
	add(stake, CFrame.new(radius + 3.3, 0.3, 0), 0)

	-- Mandíbulas: tramos de un semicírculo con un diente (cuña) de pie sobre cada uno.
	local segments = 6
	for _, jaw in { 1, -1 } do
		local previous = Vector3.new(radius, 0, 0)
		for index = 1, segments do
			local angle = index / segments * math.pi
			local point = Vector3.new(radius * math.cos(angle), 0, jaw * radius * math.sin(angle))
			local length = (point - previous).Magnitude
			local along = CFrame.lookAt((previous + point) / 2, point)
			add(trapPart("Jaw", Vector3.new(0.2, 0.2, length + 0.1), metal), along, jaw)
			add(
				trapPart(
					"Tooth",
					Vector3.new(0.08, 0.38, length * 0.7),
					Color3.fromRGB(150, 145, 140),
					Enum.PartType.Wedge
				),
				along * CFrame.new(0, 0.28, 0),
				jaw
			)
			previous = point
		end
	end

	local hinge = CFrame.new(0, 0.1, 0)
	local function pose(origin: CFrame, angle: number)
		for _, item in pieces do
			if item.jaw == 0 then
				item.part.CFrame = origin * item.offset
			else
				item.part.CFrame = origin * hinge * CFrame.Angles(-item.jaw * angle, 0, 0) * item.offset
			end
		end
	end
	return model, plate, pose
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
	local facing = flat(root.CFrame.LookVector)
	local model, plate, pose = bearTrap()
	pose(CFrame.lookAt(position, position + facing), 0)
	model.Parent = Workspace
	table.insert(own, model)
	Sfx.play("Build", root)

	local damage = SETTINGS.TrapDamage * Progression.perk(player, "RangedDamage")
	local seconds = Progression.perk(player, "TrapRoot")
	task.spawn(function()
		local expires = os.clock() + SETTINGS.TrapLifetime
		while model.Parent and os.clock() < expires and player.Parent do
			local victim = targetsAround(player, position, SETTINGS.TrapRadius + 1)[1]
			if victim then
				hurt(player, victim, damage, "Trap")
				control(victim, seconds, "Root")
				comboOpener(player, "Trap", victim)
				-- El cepo salta a los pies del mono y se cierra de golpe; se queda cerrado mientras le sujeta.
				local feet = groundBelow(victim.root.Position, { victim.model, character })
				local origin = CFrame.lookAt(feet, feet + facing)
				for step = 1, 3 do
					pose(origin, TRAP_CLOSED_ANGLE * step / 3)
					task.wait()
				end
				Sfx.play("Hit", plate)
				task.wait(seconds)
				break
			end
			task.wait(0.1)
		end
		local index = table.find(own, model)
		if index then
			table.remove(own, index)
		end
		model:Destroy()
	end)
	return true
end

local function arrowRain(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	local endPoint = castShot(character, origin, aim, SETTINGS.RainMaxDistance, 0.5)
	local center = groundBelow(endPoint, { character })
	local damage = SETTINGS.RainDamage
		* Progression.perk(player, "RangedDamage")
		* Progression.perk(player, "RainDamage")
	local interval = SETTINGS.RainSeconds / SETTINGS.RainTicks
	Sfx.play("Shoot", root)
	-- La nube y las flechas que caen las dibujan los clientes.
	AbilityFx.all("ArrowRain", center, SETTINGS.RainRadius, SETTINGS.RainSeconds)
	task.spawn(function()
		for _ = 1, SETTINGS.RainTicks do
			task.wait(0.2)
			for _, target in targetsAround(player, center, SETTINGS.RainRadius) do
				hurt(player, target, damage, "ArrowRain")
			end
			task.wait(math.max(0, interval - 0.2))
		end
	end)
	return true
end

-- ===================================== Mago =====================================

local function fireball(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local scale = Progression.perk(player, "SpellDamage") * Progression.perk(player, "FireballDamage")
	local origin = headOf(character, root)
	local endPoint, result = castShot(character, origin, aim, SETTINGS.FireballRange, 1.5)
	local direct = if result then targetFromPart(player, result.Instance) else nil
	local seconds = (endPoint - origin).Magnitude / SETTINGS.FireballSpeed
	-- Remate del combo del mago: rompe el hielo con una explosión más grande.
	local finisher = ComboService.isPayoff(player, "Fireball")
	local radius = SETTINGS.FireballSplashRadius * (if finisher then 1 + COMBO.FireballSplashBonus else 1)
	AbilityFx.all("Fireball", origin, endPoint, SETTINGS.FireballSpeed, radius)
	Sfx.play("Shoot", root)
	task.delay(seconds, function()
		Sfx.play("LavaImpact", endPoint)
		local function strike(target: Target, amount: number)
			if finisher and ComboService.isMarkedBy(target.model, player) then
				AbilityFx.all("IceShatter", target.root.Position)
			end
			hurt(player, target, amount, "Fireball")
		end
		if direct then
			strike(direct, SETTINGS.FireballDamage * scale)
		end
		for _, target in targetsAround(player, endPoint, radius) do
			if not (direct and target.model == direct.model) then
				strike(target, SETTINGS.FireballSplashDamage * scale)
			end
		end
	end)
	return true
end

local function frostNova(player: Player, _character: Model, root: BasePart): boolean
	local damage = SETTINGS.NovaDamage * Progression.perk(player, "SpellDamage")
	local freeze = Progression.perk(player, "NovaFreeze")
	for _, target in targetsAround(player, root.Position, SETTINGS.NovaRadius) do
		hurt(player, target, damage, "FrostNova")
		control(target, freeze, "Freeze")
		comboOpener(player, "FrostNova", target)
		if not target.player then
			Status.slow(target.model, freeze + SETTINGS.NovaSlowSeconds, SETTINGS.NovaSlowFactor)
		end
	end
	AbilityFx.all("FrostNova", root.Position, SETTINGS.NovaRadius)
	Sfx.play("Hit", root)
	return true
end

local function blink(player: Player, _character: Model, root: BasePart, _aim: Vector3, extra: { any }): boolean
	-- El cliente ya se ha movido y ha dibujado el punto negro y la chispa; manda desde dónde y hasta
	-- dónde para que lo vean los demás (solo se acepta cerca del personaje).
	local reach = Progression.perk(player, "BlinkDistance") + BLINK_POINT_SLACK
	local function near(point: any): Vector3
		return if typeof(point) == "Vector3" and (point - root.Position).Magnitude <= reach
			then point
			else root.Position
	end
	AbilityFx.others(player, "Blink", near(extra[1]), near(extra[2]))
	Sfx.play("Pickup", root)
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
			AbilityFx.all("Lightning", from, target.root.Position, target.model)
			hurt(player, target, damage, "ChainLightning")
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
	-- Remate del combo del médico: curaciones críticas seguras (heal) y baja la fiebre.
	local finisher = ComboService.isPayoff(player, "AreaHeal")
	local healed = 0
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local otherRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local near = otherRoot
			and otherRoot:IsA("BasePart")
			and (otherRoot.Position - root.Position).Magnitude <= SETTINGS.AreaHealRadius
		if near and heal(player, other, amount, "AreaHeal") then
			healed += 1
			if finisher then
				Survival.addFever(other, -COMBO.SalveFeverCure)
			end
		end
	end
	AbilityFx.all("AreaHeal", root.Position, SETTINGS.AreaHealRadius)
	Sfx.play("Heal", root)
	Remotes.Notify:FireClient(
		player,
		if finisher
			then `⛑️ ¡Cura de urgencia! Has curado a {healed} jugador(es) y les has bajado la fiebre`
			else `⛑️ Has curado a {healed} jugador(es)`
	)
	return true
end

local function healingDart(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	local endPoint, result = castShot(character, origin, aim, SETTINGS.DartRange, 1.5)
	local seconds = (endPoint - origin).Magnitude / SETTINGS.DartSpeed
	AbilityFx.all("Dart", origin, endPoint, SETTINGS.DartSpeed)
	Sfx.play("Shoot", root)
	if not result then
		return true
	end
	local ally = CombatService.playerFromPart(result.Instance)
	local enemy = if ally then nil else targetFromPart(player, result.Instance)
	task.delay(seconds, function()
		if ally and heal(player, ally, SETTINGS.DartHeal * Progression.perk(player, "HealPower"), "HealingDart") then
			local allyCharacter = ally.Character
			local allyRoot = if allyCharacter then allyCharacter:FindFirstChild("HumanoidRootPart") else nil
			if allyRoot and allyRoot:IsA("BasePart") then
				AbilityFx.all("HealBurst", allyRoot.Position)
				Sfx.play("Heal", allyRoot)
			end
			-- Primer paso del combo del médico: el aliado queda "revitalizado".
			if allyCharacter then
				ComboService.opener(player, "HealingDart", allyCharacter)
			end
			Remotes.Notify:FireClient(player, `⛑️ Dardo curativo a {ally.DisplayName}`)
		elseif enemy then
			hurt(player, enemy, SETTINGS.DartDamage, "HealingDart")
			comboOpener(player, "HealingDart", enemy)
		end
	end)
	return true
end

-- A quién va el Escudo de hojas: con el combo enlazado, al aliado que revitalizó el dardo; si no, al
-- aliado vivo más cercano; si no hay ninguno al alcance, al propio médico. Devuelve también si es el
-- revitalizado (absorbe más).
local function shieldTarget(player: Player, character: Model, root: BasePart): (Player, Model, boolean)
	local linked = ComboService.isPayoff(player, "LeafShield")
	local chosen = player
	local chosenCharacter = character
	local bestDistance = SETTINGS.ShieldRange
	for _, other in Players:GetPlayers() do
		local otherCharacter = other.Character
		local otherRoot = if otherCharacter then otherCharacter:FindFirstChild("HumanoidRootPart") else nil
		if otherCharacter and otherRoot and otherRoot:IsA("BasePart") and LifeState.isAlive(other) then
			local distance = (otherRoot.Position - root.Position).Magnitude
			local revitalized = linked and ComboService.isMarkedBy(otherCharacter, player)
			if revitalized and distance <= SETTINGS.ShieldRange then
				return other, otherCharacter, true
			end
			if other ~= player and distance <= bestDistance then
				chosen = other
				chosenCharacter = otherCharacter
				bestDistance = distance
			end
		end
	end
	return chosen, chosenCharacter, false
end

local function leafShield(player: Player, character: Model, root: BasePart): boolean
	local chosen, chosenCharacter, revitalized = shieldTarget(player, character, root)
	local amount = Progression.perk(player, "ShieldAmount")
	if revitalized then
		amount = math.round(amount * (1 + COMBO.ShieldBonus))
	end
	chosen:SetAttribute("ShieldHealth", amount)
	chosen:SetAttribute("ShieldUntil", now() + SETTINGS.ShieldSeconds)
	-- La burbuja sale de esos atributos en cada cliente; aquí, el destello al ponerla.
	AbilityFx.all("ShieldGlare", chosenCharacter)
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
	AbilityFx.all("Totem", position, root.CFrame.LookVector, SETTINGS.TotemRadius, SETTINGS.TotemSeconds)
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
					heal(player, other, amount, "HealingTotem")
				end
			end
		end
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

-- "from" y "to": dónde empezó y acabó el Parpadeo en el cliente (solo para su efecto).
local function onUseAbility(player: Player, slot: any, aim: any, from: any, to: any)
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
	if not handler then
		return
	end
	-- Antes de aplicarla: si es el siguiente paso del combo, sus golpes ya cuentan como enlazados.
	ComboService.onAbilityUsed(player, ability.id)
	if handler(player, character, root, aim.Unit, { from, to }) then
		local cooldown = ability.cooldownSeconds
			* Progression.perk(player, "CooldownRate")
			* ComboService.cooldownFactor(player)
		player:SetAttribute(`AbilityReadyAt{slot}`, now() + cooldown)
	end
end

function AbilityService:Start()
	Remotes.UseAbility.OnServerEvent:Connect(onUseAbility)
	Players.PlayerRemoving:Connect(function(player)
		for _, model in traps[player] or {} do
			model:Destroy()
		end
		traps[player] = nil
	end)
end

return AbilityService
