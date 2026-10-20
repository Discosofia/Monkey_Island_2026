--!strict
-- Habilidades de los roles (Fase 3): 4 activas y una definitiva por rol (Data/Roles), con sus números
-- en Config.Abilities. El cliente (RoleController) pide usar la del hueco 1-5 con la dirección en la
-- que apunta; aquí se comprueba el tiempo de espera y se aplica todo.
--   - Guerrero: Torbellino, Embestida, Grito de guerra, Pisotón (id "Quake") y Rompehuesos ("Smash").
--   - Cazador: Disparo múltiple, Marcar presas, Cepo, Lluvia de proyectiles y Flecha perforante.
--   - Mago: Bola de fuego, Nova de hielo, Parpadeo, Rayo encadenado y Meteoro.
--   - Médico: Ungüento en área, Dardo curativo, Escudo de hojas, Tótem sanador y Polvo somnífero. Su
--     pasiva "Savia protectora" también va aquí: al curar a un aliado gana un escudo pequeño.
-- Los movimientos (Embestida y Parpadeo) los hace el cliente, que es quien mueve a su personaje; el
-- servidor pone el daño. Lo que se ve lo dibuja cada cliente (Combat/AbilityFx y AbilityFxController),
-- salvo el Cepo, que es una pieza del mundo. Contra los jugadores que las reglas del place dejan herir
-- (CombatRules: PvP opt-in en la Isla, el otro equipo en la arena), las habilidades hacen menos daño y
-- aturden menos rato; curaciones y escudos solo van a los aliados. Los estados de los monos están en Status.
-- El cliente ve cuándo vuelve a estar lista cada una con el atributo "AbilityReadyAt<hueco>".
-- Combos (Data/Combos, ComboService), dos por rol: la primera habilidad de cada combo marca lo que
-- toca; las siguientes, enlazadas a tiempo, hacen críticos seguros con daño extra contra los marcados y
-- el remate un efecto extra. Lo que golpea un remate que conecta con el otro combo queda marcado para
-- ese (ComboService.touch). Los demás golpes pueden ser críticos con la probabilidad del arma (Shared/Crit).

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
local ComboService = require(script.Parent.ComboService)
local CombatService = require(script.Parent.CombatService)
local AbilityFx = require(script.Parent.Parent.AbilityFx)
local CombatRules = require(script.Parent.Parent.CombatRules)
local Status = require(script.Parent.Parent.Status)

local SETTINGS = Config.Abilities
local COMBO = Config.Combo
-- Velocidad (studs/s) de las flechas del Disparo múltiple.
local ARROW_SPEED = 200
-- Radio de las mandíbulas del cepo y cuánto se cierran (casi 90°: quedan de pie, una contra otra).
local TRAP_JAW_RADIUS = 1.5
local TRAP_CLOSED_ANGLE = math.rad(84)
-- Lo más lejos del personaje que se acepta el "desde/hasta" del Parpadeo que manda el cliente.
local BLINK_POINT_SLACK = 15

-- Algo a lo que una habilidad puede dañar: un enemigo o un jugador rival (CombatService.canHitPlayer).
type Target = { model: Model, humanoid: Humanoid, root: BasePart, player: Player? }
type Handler = (player: Player, character: Model, root: BasePart, aim: Vector3, extra: { any }) -> boolean

local AbilityService = {}

local traps: { [Player]: { Model } } = {}
-- Cuándo puede volver a ganar el escudo de la Savia protectora cada médico.
local sapReadyAt: { [Player]: number } = {}

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

-- El suelo bajo "position" y su inclinación (la normal; hacia arriba si no hay suelo).
local function groundBelow(position: Vector3, ignore: { Instance }): (Vector3, Vector3)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -200, 0), params)
	if result then
		return result.Position, result.Normal
	end
	return position, Vector3.yAxis
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

-- Enemigos vivos (y jugadores rivales) a menos de "radius" de "center".
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

-- Como targetsAround, pero midiendo en horizontal y con "height" de margen hacia arriba y hacia
-- abajo: para lo que está en el suelo (el cepo). En una ladera, la distancia en 3D deja fuera a los
-- que están encima pero más arriba o más abajo, y el centro de un mono está a varios studs del suelo.
local function targetsOnGround(attacker: Player, center: Vector3, radius: number, height: number): { Target }
	local found: { Target } = {}
	for _, target in targetsAround(attacker, center, radius + height) do
		local offset = target.root.Position - center
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) <= height then
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

-- Daña a un objetivo con la habilidad "abilityId"; a los jugadores, menos. Si la habilidad está
-- enlazada en el combo y el objetivo lleva su marca, es crítico seguro y hace el daño extra del combo
-- (Data/Combos "damageBonus"); si no, es crítico con la probabilidad del arma.
local function hurt(attacker: Player, target: Target, amount: number, abilityId: string)
	if target.humanoid.Health <= 0 then
		return
	end
	if target.player then
		CombatService.damagePvP(
			attacker,
			target.player,
			math.max(1, math.round(amount * CombatRules.get().pvpDamageMultiplier)),
			CombatService.rollPlayerCrit(attacker)
		)
	else
		local comboHit = ComboService.isComboHit(attacker, target.model, abilityId)
		if comboHit then
			amount *= 1 + ComboService.linkedDamageBonus(attacker, abilityId)
		end
		ComboService.touch(attacker, abilityId, target.model)
		local crit = comboHit or CombatService.rollPlayerCrit(attacker)
		CombatService.damage(
			target.model,
			target.humanoid,
			math.max(1, math.round(amount)),
			attacker,
			{ crit = crit, source = abilityId }
		)
	end
end

-- La primera habilidad del combo tocó a un enemigo (no a otro jugador en PvP): lo marca.
local function comboOpener(player: Player, abilityId: string, target: Target)
	if not target.player then
		ComboService.opener(player, abilityId, target.model)
	end
end

-- Aturde, congela, inmoviliza o duerme. A un jugador lo deja quieto (atributo "StunnedUntil"), menos
-- tiempo. Congelado, inmovilizado y dormido se ven en los clientes (bloque de hielo, brillo verde, "Zzz").
local function control(target: Target, seconds: number, look: ("Stun" | "Freeze" | "Root" | "Sleep")?)
	local duration = seconds
	if target.player then
		duration *= CombatRules.get().pvpControlMultiplier
		if not Status.holdPlayer(target.player, duration, "PvP") then
			return
		end
	else
		duration = Status.stun(target.model, seconds, look)
	end
	if look == "Freeze" then
		AbilityFx.all("Frozen", target.model, duration)
	elseif look == "Root" then
		AbilityFx.all("Rooted", target.model, duration)
	elseif look == "Sleep" then
		AbilityFx.all("Asleep", target.model, duration)
	end
end

-- El médico ("healer") cura a "player" con "abilityId". Puede ser crítica (Shared/Crit) y lo es seguro
-- si es el remate de su combo. Devuelve false si no se le puede curar (caído, del otro equipo…).
local function heal(healer: Player, player: Player, amount: number, abilityId: string): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (humanoid and humanoid.Health > 0 and LifeState.isAlive(player)) then
		return false
	end
	if player ~= healer and not CombatRules.get().isAlly(healer, player) then
		return false
	end
	CombatService.heal(
		player,
		amount,
		healer,
		{ canCrit = true, crit = ComboService.isPayoff(healer, abilityId), source = abilityId }
	)
	if character then
		ComboService.touch(healer, abilityId, character)
	end
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
-- De cerca el cono es más ancho y solo cuenta en horizontal (CombatService.aimDeviation).
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
	local bestAngle = math.huge
	for _, target in targetsAround(attacker, origin, range) do
		local angle = CombatService.aimDeviation(origin, aim, target.root.Position, degrees)
		if angle and angle < bestAngle then
			params.FilterDescendantsInstances = { character, target.model }
			if not Workspace:Raycast(origin, target.root.Position - origin, params) then
				best = target
				bestAngle = angle
			end
		end
	end
	return best
end

-- El objetivo que el jugador tiene delante a corta distancia (Config.Combat.CloseAimRange), o nil.
-- Para los disparos que irían rectos por encima de un mono pequeño pegado al jugador.
local function closeTarget(attacker: Player, character: Model, origin: Vector3, aim: Vector3): Target?
	local settings = Config.Combat
	return bestInCone(attacker, character, origin, aim, settings.CloseAimRange + settings.CloseAimHeight, 0)
end

-- La puntería de un disparo recto de "range": la misma si alcanza a alguien o no hay objetivo
-- cercano ("close", de closeTarget); si no, hacia él.
local function closeAim(
	attacker: Player,
	character: Model,
	origin: Vector3,
	aim: Vector3,
	range: number,
	close: Target?
): Vector3
	if not close then
		return aim
	end
	local _, result = castShot(character, origin, aim, range, 1)
	if result and targetFromPart(attacker, result.Instance) then
		return aim
	end
	return (close.root.Position - origin).Unit
end

-- ===================================== Guerrero =====================================

local function whirlwind(player: Player, character: Model, root: BasePart): boolean
	local seconds = Progression.perk(player, "WhirlwindSeconds")
	-- Remate del combo del guerrero: gira más rato (y hace críticos a los desequilibrados, en hurt).
	if ComboService.isPayoff(player, "Whirlwind") then
		seconds += COMBO.WhirlwindExtraSeconds
	end
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
	-- Enlazado en el combo, el grito aturde a los desequilibrados por la Embestida.
	local linked = ComboService.isPayoff(player, "WarCry")
	for _, target in targetsAround(player, root.Position, SETTINGS.WarCryRadius) do
		if not target.player then
			Status.taunt(target.model, player, seconds)
			taunted += 1
			if linked and ComboService.isMarkedBy(target.model, player) then
				control(target, COMBO.WarCryStun, "Stun")
			end
			-- Primer paso de "Martillo y yunque": los provocados quedan marcados.
			comboOpener(player, "WarCry", target)
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
		hurt(player, target, damage, "Quake")
		control(target, stun, "Stun")
	end
	Sfx.play("RockImpact", root)
	AbilityFx.all("Quake", ground, SETTINGS.QuakeRadius)
	return true
end

-- Rompehuesos: golpe pesado a los monos del cono de delante (el cliente gira al guerrero hacia donde
-- apunta). Como remate de "Martillo y yunque", a todos los de alrededor.
local function smash(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local damage = SETTINGS.SmashDamage
		* Progression.perk(player, "MeleeDamage")
		* Progression.perk(player, "SmashDamage")
	local around = ComboService.isPayoff(player, "Smash")
	local facing = flat(aim)
	local minDot = math.cos(math.rad(SETTINGS.SmashAngle / 2))
	local ground = groundBelow(root.Position, { character })
	AbilityFx.all("Smash", ground, facing, SETTINGS.SmashRange, if around then 360 else SETTINGS.SmashAngle)
	-- El golpe llega cuando el arma baja (el gesto tarda un poco).
	task.delay(0.25, function()
		if not (root.Parent and LifeState.isAlive(player)) then
			return
		end
		Sfx.play("RockImpact", root)
		for _, target in targetsAround(player, root.Position, SETTINGS.SmashRange) do
			local offset = target.root.Position - root.Position
			local inFront = flat(offset):Dot(facing) >= minDot or offset.Magnitude < 2
			if around or inFront then
				hurt(player, target, damage, "Smash")
				control(target, SETTINGS.SmashStun, "Stun")
			end
		end
	end)
	return true
end

-- ===================================== Cazador =====================================

local function multiShot(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local count = math.max(1, math.floor(Progression.perk(player, "MultiShotCount")))
	-- Remate del combo del cazador: más proyectiles (y críticos a los atrapados, en hurt).
	if ComboService.isPayoff(player, "MultiShot") then
		count += COMBO.MultiShotExtraArrows
	end
	local damage = SETTINGS.MultiShotDamage * Progression.perk(player, "RangedDamage")
	local origin = headOf(character, root)
	local spread = math.rad(SETTINGS.MultiShotSpreadDegrees)
	-- De cerca, el abanico se centra en el mono que tienes delante y la flecha del centro le da
	-- aunque esté pegado (un Spherecast no ve lo que ya toca al salir).
	local close = closeTarget(player, character, origin, aim)
	aim = closeAim(player, character, origin, aim, SETTINGS.MultiShotRange, close)
	local center = math.ceil(count / 2)
	Sfx.play("Shoot", root)
	local endPoints = {}
	for index = 1, count do
		local angle = if count == 1 then 0 else -spread / 2 + spread * (index - 1) / (count - 1)
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(aim)
		local endPoint, result = castShot(character, origin, direction, SETTINGS.MultiShotRange, 1)
		local target = if result then targetFromPart(player, result.Instance) else nil
		if not target and close and index == center then
			target = close
			endPoint = close.root.Position
		end
		table.insert(endPoints, endPoint)
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
	-- Enlazado en el combo, vuelve a sujetar a los atrapados por el cepo.
	local linked = ComboService.isPayoff(player, "MarkPrey")
	for _, enemy in CollectionService:GetTagged(Config.Combat.EnemyTag) do
		if enemy:IsA("Model") then
			local distance = (enemy:GetPivot().Position - root.Position).Magnitude
			if distance <= SETTINGS.MarkRadius then
				local target = enemyTarget(enemy)
				if target and linked and ComboService.isMarkedBy(enemy, player) then
					control(target, COMBO.MarkPreyRoot, "Root")
				end
				-- Primer paso de "Tiro de gracia": las presas quedan señaladas.
				if target then
					comboOpener(player, "MarkPrey", target)
				end
				enemy:SetAttribute("MarkedUntil", untilTime)
				enemy:SetAttribute("MarkBonus", bonus)
				-- Pisa la marca de una mascota (PetService): la suya es mayor y se ve como diana.
				enemy:SetAttribute("MarkSource", nil)
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
	-- Apoyado en el suelo siguiendo su inclinación (en una ladera no se entierra ni flota).
	local position, normal = groundBelow(root.Position, { character })
	local facing = flat(root.CFrame.LookVector)
	local along = facing - normal * facing:Dot(normal)
	if along.Magnitude < 0.01 then
		along = normal:Cross(Vector3.xAxis)
	end
	local origin = CFrame.lookAt(position, position + along.Unit, normal)
	local model, plate, pose = bearTrap()
	pose(origin, 0)
	model.Parent = Workspace
	table.insert(own, model)
	Sfx.play("Build", root)

	local damage = SETTINGS.TrapDamage * Progression.perk(player, "RangedDamage")
	local seconds = Progression.perk(player, "TrapRoot")
	task.spawn(function()
		local expires = os.clock() + SETTINGS.TrapLifetime
		while model.Parent and os.clock() < expires and player.Parent do
			if targetsOnGround(player, position, SETTINGS.TrapRadius + 1, SETTINGS.TrapHeight)[1] then
				-- Salta cuando lo pisa un mono y atrapa a todos los que estén en su radio de captura.
				AbilityFx.all("TrapSnap", position, SETTINGS.TrapCatchRadius)
				for _, victim in targetsOnGround(player, position, SETTINGS.TrapCatchRadius, SETTINGS.TrapHeight) do
					hurt(player, victim, damage, "Trap")
					control(victim, seconds, "Root")
					comboOpener(player, "Trap", victim)
				end
				-- Se cierra de golpe donde está y se queda cerrado mientras los sujeta.
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

-- Hasta dónde llega una flecha que atraviesa monos y jugadores: solo la para el terreno o el decorado.
local function pierceEnd(character: Model, origin: Vector3, direction: Vector3, range: number): Vector3
	local ignore: { Instance } = { character }
	for _, enemy in CollectionService:GetTagged(Config.Combat.EnemyTag) do
		table.insert(ignore, enemy)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(origin, direction * range, params)
	return if result then result.Position else origin + direction * range
end

type PierceHit = { target: Target, along: number }

-- Lo que atraviesa una flecha perforante en "direction": dónde acaba y a quién alcanza, con la
-- distancia a la que está cada uno.
local function pierceLine(
	player: Player,
	character: Model,
	origin: Vector3,
	direction: Vector3
): (Vector3, { PierceHit })
	local endPoint = pierceEnd(character, origin, direction, SETTINGS.PierceRange)
	local length = (endPoint - origin).Magnitude
	local hits: { PierceHit } = {}
	for _, target in targetsAround(player, origin, length + 3) do
		local offset = target.root.Position - origin
		local along = offset:Dot(direction)
		local apart = (offset - direction * along).Magnitude
		-- Con margen para el cuerpo del mono (su centro está a un par de studs de su borde).
		if along > 0 and along <= length + 1 and apart <= SETTINGS.PierceWidth + 2 then
			table.insert(hits, { target = target, along = along })
		end
	end
	return endPoint, hits
end

-- Flecha perforante: atraviesa a todos los que encuentra en línea recta, a cada uno cuando le llega.
-- Como remate de "Tiro de gracia", dispara más en un abanico estrecho.
local function piercingShot(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local damage = SETTINGS.PierceDamage
		* Progression.perk(player, "RangedDamage")
		* Progression.perk(player, "PierceDamage")
	local count = 1
	if ComboService.isPayoff(player, "PiercingShot") then
		count += COMBO.PierceExtraArrows
	end
	local origin = headOf(character, root)
	-- De cerca, si la flecha recta no atravesaría a nadie, va hacia el mono que tienes delante.
	local _, straightHits = pierceLine(player, character, origin, aim)
	if #straightHits == 0 then
		local close = closeTarget(player, character, origin, aim)
		if close then
			aim = (close.root.Position - origin).Unit
		end
	end
	local spread = math.rad(COMBO.PierceSpreadDegrees)
	local endPoints = {}
	for index = 1, count do
		local angle = if count == 1 then 0 else -spread / 2 + spread * (index - 1) / (count - 1)
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(aim)
		local endPoint, hits = pierceLine(player, character, origin, direction)
		table.insert(endPoints, endPoint)
		for _, hit in hits do
			task.delay(hit.along / SETTINGS.PierceSpeed, hurt, player, hit.target, damage, "PiercingShot")
		end
	end
	Sfx.play("Shoot", root)
	AbilityFx.all("PiercingShot", origin, endPoints, SETTINGS.PierceSpeed)
	return true
end

-- ===================================== Mago =====================================

local function fireball(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local scale = Progression.perk(player, "SpellDamage") * Progression.perk(player, "FireballDamage")
	local origin = headOf(character, root)
	local endPoint, result = castShot(character, origin, aim, SETTINGS.FireballRange, 1.5)
	local direct = if result then targetFromPart(player, result.Instance) else nil
	-- De cerca, la bola que pasaría por encima de un mono pequeño (o no lo vería por estar pegado) le da.
	if not direct then
		direct = closeTarget(player, character, origin, aim)
		if direct then
			endPoint = direct.root.Position
		end
	end
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
			-- Primer paso de "Lluvia de estrellas": lo que quema queda chamuscado.
			comboOpener(player, "Fireball", target)
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

-- Meteoro: una roca ardiente cae donde apunta el mago tras un aviso en el suelo. Como remate de
-- "Lluvia de estrellas", deja el suelo ardiendo unos segundos.
local function meteor(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	local endPoint = castShot(character, origin, aim, SETTINGS.MeteorMaxDistance, 0.5)
	local center = groundBelow(endPoint, { character })
	local scale = Progression.perk(player, "SpellDamage")
	local slow = Progression.perk(player, "MeteorSlow")
	local burnTicks = if ComboService.isPayoff(player, "Meteor") then COMBO.MeteorBurnTicks else 0
	AbilityFx.all("Meteor", center, SETTINGS.MeteorRadius, SETTINGS.MeteorDelay, burnTicks)
	Sfx.play("LavaLaunch", root)
	task.spawn(function()
		task.wait(SETTINGS.MeteorDelay)
		Sfx.play("LavaImpact", center)
		for _, target in targetsAround(player, center, SETTINGS.MeteorRadius) do
			hurt(player, target, SETTINGS.MeteorDamage * scale, "Meteor")
			if slow > 0 and not target.player then
				Status.slow(target.model, slow, SETTINGS.NovaSlowFactor)
			end
		end
		for _ = 1, burnTicks do
			task.wait(1)
			for _, target in targetsAround(player, center, SETTINGS.MeteorRadius) do
				hurt(player, target, COMBO.MeteorBurnDamage * scale, "Meteor")
			end
		end
	end)
	return true
end

-- ===================================== Médico =====================================

local function areaHeal(player: Player, _character: Model, root: BasePart): boolean
	local amount = SETTINGS.AreaHealAmount * Progression.perk(player, "HealPower")
	-- Remate de "Cura de urgencia": curaciones críticas seguras (heal), baja la fiebre y envenena a los
	-- monos del radio.
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
				CombatRules.get().addFever(other, -COMBO.SalveFeverCure)
			end
		end
	end
	local poisoned = 0
	if finisher then
		for _, target in targetsAround(player, root.Position, SETTINGS.AreaHealRadius) do
			if not target.player then
				Status.poison(target.model, COMBO.SalvePoisonDps, COMBO.SalvePoisonSeconds, player, "AreaHeal")
				poisoned += 1
			end
		end
	end
	AbilityFx.all("AreaHeal", root.Position, SETTINGS.AreaHealRadius)
	Sfx.play("Heal", root)
	Remotes.Notify:FireClient(
		player,
		if finisher
			then `⛑️ ¡Cura de urgencia! Has curado a {healed} jugador(es), les has bajado la fiebre y has envenenado a {poisoned} mono(s)`
			else `⛑️ Has curado a {healed} jugador(es)`
	)
	return true
end

local function healingDart(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	local endPoint, result = castShot(character, origin, aim, SETTINGS.DartRange, 1.5)
	local hitPlayer = if result then CombatService.playerFromPart(result.Instance) else nil
	local ally = if hitPlayer and CombatRules.get().isAlly(player, hitPlayer) then hitPlayer else nil
	local enemy = if result and not ally then targetFromPart(player, result.Instance) else nil
	-- De cerca, el dardo que pasaría por encima de un mono pequeño le da.
	if not (ally or enemy) then
		enemy = closeTarget(player, character, origin, aim)
		if enemy then
			endPoint = enemy.root.Position
		end
	end
	local seconds = (endPoint - origin).Magnitude / SETTINGS.DartSpeed
	AbilityFx.all("Dart", origin, endPoint, SETTINGS.DartSpeed)
	Sfx.play("Shoot", root)
	if not (ally or enemy) then
		return true
	end
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
	local rules = CombatRules.get()
	local chosen = player
	local chosenCharacter = character
	local bestDistance = SETTINGS.ShieldRange
	for _, other in Players:GetPlayers() do
		local otherCharacter = other.Character
		local otherRoot = if otherCharacter then otherCharacter:FindFirstChild("HumanoidRootPart") else nil
		local friendly = other == player or rules.isAlly(player, other)
		if friendly and otherCharacter and otherRoot and otherRoot:IsA("BasePart") and LifeState.isAlive(other) then
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
	-- Primer paso de "Nana de la selva": el protegido queda arropado.
	ComboService.opener(player, "LeafShield", chosenCharacter)
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

-- El tótem se planta donde apunta el médico (el cursor; en móvil y mando, hacia donde mira la
-- cámara), como mucho a TotemMaxDistance: más lejos, se queda a esa distancia en esa dirección.
local function healingTotem(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	local endPoint = castShot(character, origin, aim, SETTINGS.TotemMaxDistance, 0.5)
	local position = groundBelow(endPoint, { character })
	-- Mira hacia el médico, como si lo hubiera plantado de frente.
	local facing = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
	local lookVector = if facing.Magnitude > 0.1 then -facing.Unit else root.CFrame.LookVector
	AbilityFx.all("Totem", position, lookVector, SETTINGS.TotemRadius, SETTINGS.TotemSeconds)
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

-- Polvo somnífero: una nube donde apunta el médico. A los monos les entra sueño (van lentos) y luego
-- se duermen; los jefes no se duermen. Como remate de "Nana de la selva", duermen más, la nube cura a
-- los aliados que estén dentro y los dormidos reciben más daño hasta despertar (Status.expose).
local function sleepPowder(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	local endPoint = castShot(character, origin, aim, SETTINGS.PowderMaxDistance, 0.5)
	local center = groundBelow(endPoint, { character })
	local finisher = ComboService.isPayoff(player, "SleepPowder")
	local sleep = Progression.perk(player, "PowderSleep") + (if finisher then COMBO.PowderExtraSleep else 0)
	local drowsy = SETTINGS.PowderDrowsySeconds
	AbilityFx.all("SleepPowder", origin, center, SETTINGS.PowderRadius, drowsy + sleep)
	Sfx.play("Shoot", root)
	task.spawn(function()
		-- Lo que tarda el puñado de polvo en llegar.
		task.wait(0.5)
		local sleepers: { Target } = {}
		for _, target in targetsAround(player, center, SETTINGS.PowderRadius) do
			hurt(player, target, SETTINGS.PowderDamage, "SleepPowder")
			if target.player then
				table.insert(sleepers, target)
			elseif not Status.isBoss(target.model) then
				Status.slow(target.model, drowsy, SETTINGS.PowderSlowFactor)
				table.insert(sleepers, target)
			end
		end
		if finisher then
			local amount = COMBO.PowderHeal * Progression.perk(player, "HealPower")
			for _, other in Players:GetPlayers() do
				local otherCharacter = other.Character
				local otherRoot = if otherCharacter then otherCharacter:FindFirstChild("HumanoidRootPart") else nil
				if
					otherRoot
					and otherRoot:IsA("BasePart")
					and (otherRoot.Position - center).Magnitude <= SETTINGS.PowderRadius
				then
					heal(player, other, amount, "SleepPowder")
				end
			end
		end
		task.wait(drowsy)
		for _, target in sleepers do
			if target.humanoid.Health > 0 and target.model.Parent then
				-- Antes de dormirlo: el "💤" del cliente lee si está expuesto.
				if finisher and not target.player then
					Status.expose(target.model, COMBO.PowderExposed, sleep)
				end
				control(target, sleep, "Sleep")
			end
		end
	end)
	return true
end

-- "Savia protectora" (pasiva del médico, ventaja "SapShield"): cuando "healer" cura a un aliado, gana
-- un escudo pequeño, como mucho uno cada SapShieldCooldown. No pisa un escudo mayor (el de hojas).
local function sapShield(healer: Player)
	local amount = Progression.perk(healer, "SapShield")
	local time = now()
	if amount <= 0 or time < (sapReadyAt[healer] or 0) or not LifeState.isAlive(healer) then
		return
	end
	local character = healer.Character
	local shieldUntil = healer:GetAttribute("ShieldUntil")
	local shield = healer:GetAttribute("ShieldHealth")
	local stronger = typeof(shieldUntil) == "number"
		and time < shieldUntil
		and typeof(shield) == "number"
		and shield >= amount
	if not character or stronger then
		return
	end
	sapReadyAt[healer] = time + SETTINGS.SapShieldCooldown
	healer:SetAttribute("ShieldHealth", amount)
	healer:SetAttribute("ShieldUntil", time + SETTINGS.SapShieldSeconds)
	-- La burbuja sale de esos atributos en cada cliente; aquí, el destello al ponerla.
	AbilityFx.all("ShieldGlare", character)
end

local HANDLERS: { [string]: Handler } = {
	Whirlwind = whirlwind,
	Charge = charge,
	WarCry = warCry,
	Quake = quake,
	Smash = smash,
	MultiShot = multiShot,
	MarkPrey = markPrey,
	Trap = trap,
	ArrowRain = arrowRain,
	PiercingShot = piercingShot,
	Fireball = fireball,
	FrostNova = frostNova,
	Blink = blink,
	ChainLightning = chainLightning,
	Meteor = meteor,
	AreaHeal = areaHeal,
	HealingDart = healingDart,
	LeafShield = leafShield,
	HealingTotem = healingTotem,
	SleepPowder = sleepPowder,
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
	local linkedStep = ComboService.onAbilityUsed(player, ability.id)
	if handler(player, character, root, aim.Unit, { from, to }) then
		local rules = CombatRules.get()
		rules.telemetry.abilityUsed(player, ability.id, linkedStep)
		rules.progressMission(player, "Ability")
		local cooldown = ability.cooldownSeconds
			* Progression.perk(player, "CooldownRate")
			* ComboService.cooldownFactor(player)
		player:SetAttribute(`AbilityReadyAt{slot}`, now() + cooldown)
	end
end

function AbilityService:Start()
	Remotes.UseAbility.OnServerEvent:Connect(onUseAbility)
	CombatService.onPlayerHealed(function(_ally, healer)
		sapShield(healer)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, model in traps[player] or {} do
			model:Destroy()
		end
		traps[player] = nil
		sapReadyAt[player] = nil
	end)
end

return AbilityService
