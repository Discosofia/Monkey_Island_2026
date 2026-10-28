--!strict
-- Habilidades de los roles (Fase 3): 4 activas y una definitiva por rol (Data/Roles), con sus números
-- en Config.Abilities. El cliente (RoleController) pide usar la del hueco 1-5 con la dirección en la
-- que apunta; aquí se comprueba el tiempo de espera y se aplica todo.
--   - Guerrero: Torbellino, Embestida, Grito de guerra, Pisotón (id "Quake") y Rompehuesos ("Smash").
--   - Cazador: Disparo múltiple, Marcar presas, Cepo, Lluvia de proyectiles y Flecha perforante.
--   - Mago: Bola de fuego, Nova de hielo, Parpadeo, Rayo encadenado y Meteoro.
--   - Médico: Ungüento en área, Dardo curativo, Escudo de hojas, Tótem sanador y Polvo somnífero. Su
--     pasiva "Savia protectora" también va aquí: al curar a un aliado gana un escudo pequeño.
-- Cada rol tiene otra definitiva para elegir en el Lobby (T7, Data/Roles "altUltimates"; la que lleva cada
-- jugador, Shared/RoleAbilities): Salto del gorila ("Leap"), Disparo certero ("TrueShot"), Haz volcánico
-- ("LavaBeam") y Resurgir ("Resurgence"). Las de un solo objetivo llevan "pvpMultiplier" contra jugadores.
-- Los movimientos (Embestida, Parpadeo y Salto del gorila) los hace el cliente, que es quien mueve a su personaje; el
-- servidor pone el daño. Lo que se ve lo dibuja cada cliente (Combat/AbilityFx y AbilityFxController),
-- salvo el Cepo, que es una pieza del mundo. Contra los jugadores que las reglas del place dejan herir
-- (CombatRules: PvP opt-in en la Isla, el otro equipo en la arena), las habilidades hacen menos daño y
-- aturden menos rato; curaciones y escudos solo van a los aliados. Los estados de los monos están en Status.
-- El cliente ve cuándo vuelve a estar lista cada una con el atributo "AbilityReadyAt<hueco>".
-- Combos (Data/Combos, ComboService), dos por rol: la primera habilidad de cada combo marca lo que
-- toca; las siguientes, enlazadas a tiempo, hacen críticos seguros con daño extra contra los marcados y
-- el remate un efecto extra. Lo que golpea un remate que conecta con el otro combo queda marcado para
-- ese (ComboService.touch). Los demás golpes pueden ser críticos con la probabilidad del arma (Shared/Crit).
-- A quién alcanza cada una lo dice Combat/Hitbox: las áreas, solo a quien se ve desde su centro (las
-- paredes y las rocas protegen). Marcar presas no la necesita: señala por el olfato del cazador.
-- Las que viajan (Disparo múltiple, Flecha perforante, Bola de fuego y Dardo curativo) son proyectiles
-- reales (C9, Combat/Projectiles): van rectos desde donde apunta la ayuda de puntería
-- (CombatService.aimShot) y dan a quien encuentran; quien se aparta, se libra.
-- Preparación (Fase 10, C8): al pulsar, el jugador queda "Casting" (Shared/CombatState) lo que diga su
-- "castSeconds" (Data/Roles; menos su retraso de red, que ya la empezó en su pantalla) y la habilidad
-- sale al acabar: entonces cuenta el paso del combo, se aplica y empieza la recarga. Si en ese tiempo
-- le aturden, le tambalean o cae, no sale y no gasta la recarga. Pulsar la guardia es un amago
-- (Combat/Feint): cuesta estamina y deja la recarga corta de Config.Feint. Las de castSeconds = 0
-- (Grito, Parpadeo, Escudo) salen al momento, como antes.
-- Empujes y zonas (C10): la Embestida y el Rompehuesos empujan (Combat/Knockback; contra un muro, rebote).
-- La Nova deja el suelo helado, la nube del Polvo se queda y el Meteoro rematado deja el suelo ardiendo:
-- zonas de Combat/Zones que solo alcanzan a los monos y a los rivales.
-- Coberturas (C11, Combat/Destructibles): las habilidades de daño alcanzan las que tocan (su área, o el
-- proyectil que se para en una); el Rayo encadenado salta entre enemigos y no las toca.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Perks = require(ReplicatedStorage.Shared.Data.Perks)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoleAbilities = require(ReplicatedStorage.Shared.RoleAbilities)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Strings = require(ReplicatedStorage.Shared.Strings)
local ComboService = require(script.Parent.ComboService)
local CombatService = require(script.Parent.CombatService)
local AbilityFx = require(script.Parent.Parent.AbilityFx)
local CombatRules = require(script.Parent.Parent.CombatRules)
local Destructibles = require(script.Parent.Parent.Destructibles)
local Feint = require(script.Parent.Parent.Feint)
local Guard = require(script.Parent.Parent.Guard)
local Hitbox = require(script.Parent.Parent.Hitbox)
local Knockback = require(script.Parent.Parent.Knockback)
local Latency = require(script.Parent.Parent.Latency)
local Projectiles = require(script.Parent.Parent.Projectiles)
local StateMachine = require(script.Parent.Parent.StateMachine)
local Status = require(script.Parent.Parent.Status)
local Zones = require(script.Parent.Parent.Zones)

local later = Strings.later

local SETTINGS = Config.Abilities
local COMBO = Config.Combo
local ZONES = Config.Zones
-- Radio de las mandíbulas del cepo y cuánto se cierran (casi 90°: quedan de pie, una contra otra).
local TRAP_JAW_RADIUS = 1.5
local TRAP_CLOSED_ANGLE = math.rad(84)
-- Lo más lejos del personaje que se acepta el "desde/hasta" del Parpadeo que manda el cliente.
local BLINK_POINT_SLACK = 15
-- Habilidades que mueven al personaje: no se pueden usar con el atributo "MovementLocked" (en la
-- arena, quien lleva la bandera rival). El cliente (RoleController) tampoco las lanza.
local MOVEMENT_ABILITIES = { Charge = true, Blink = true, Leap = true }
-- El estado "Casting" dura la preparación más esto (s); al salir la habilidad se quita antes.
local CAST_STATE_MARGIN = 0.5
-- Lo que ven los demás mientras se prepara una habilidad (AbilityFxController), con (personaje, puntería,
-- segundos): la línea de aviso del Disparo certero, para que el apuntado pueda apartarse o bloquear.
local CAST_FX: { [string]: string } = { TrueShot = "TrueShotAim" }

-- Algo a lo que una habilidad puede dañar: un enemigo o un jugador rival (CombatService.canHitPlayer).
type Target = { model: Model, humanoid: Humanoid, root: BasePart, player: Player? }
type Handler = (player: Player, character: Model, root: BasePart, aim: Vector3, extra: { any }) -> boolean

local AbilityService = {}

local traps: { [Player]: { Model } } = {}
-- Cuándo puede volver a ganar el escudo de la Savia protectora cada médico.
local sapReadyAt: { [Player]: number } = {}
-- Cuántas veces ha salido cada habilidad de cada jugador (useKey).
local uses: { [Player]: { [string]: number } } = {}
-- Preparación en curso de cada jugador: cambia con cada una, así una cancelada no sale después.
local castTickets: { [Player]: number } = {}

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

-- Los objetivos (enemigos vivos y jugadores rivales) entre los combatientes de una consulta de Hitbox.
local function targetsOf(attacker: Player, models: { Model }): { Target }
	local found: { Target } = {}
	for _, model in models do
		local victim = Players:GetPlayerFromCharacter(model)
		local target = if victim then playerTarget(attacker, victim) else enemyTarget(model)
		if target then
			table.insert(found, target)
		end
	end
	return found
end

-- Enemigos vivos (y jugadores rivales) a menos de "radius" de "center" que se ven desde "from" (por
-- defecto, el centro): las paredes y las rocas protegen (Combat/Hitbox).
local function targetsAround(attacker: Player, center: Vector3, radius: number, from: Vector3?): { Target }
	return targetsOf(attacker, Hitbox.inSphere(center, radius, { exclude = attacker.Character, from = from }))
end

-- Lo que alcanza un área que cae en el suelo ("ground", de groundBelow): mira desde un poco más arriba
-- (Config.Combat.AreaSightLift) para que el terreno no tape a quien está encima.
local function targetsAroundGround(attacker: Player, ground: Vector3, radius: number): { Target }
	return targetsAround(attacker, ground, radius, ground + Vector3.new(0, Config.Combat.AreaSightLift, 0))
end

-- Como targetsAroundGround, pero midiendo en horizontal y con "height" de margen hacia arriba y hacia
-- abajo: para lo que está en el suelo (el cepo). En una ladera, la distancia en 3D deja fuera a los
-- que están encima pero más arriba o más abajo, y el centro de un mono está a varios studs del suelo.
local function targetsOnGround(attacker: Player, center: Vector3, radius: number, height: number): { Target }
	return targetsOf(
		attacker,
		Hitbox.inSphere(center, radius, {
			exclude = attacker.Character,
			from = center + Vector3.new(0, Config.Combat.AreaSightLift, 0),
			flatHeight = height,
		})
	)
end

-- El objetivo que es "model" (un combatiente que ha tocado un proyectil), o nil si no se le puede dañar
-- (un aliado, uno caído, un mono muerto): el proyectil lo atraviesa.
local function targetOfModel(attacker: Player, model: Model): Target?
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		return playerTarget(attacker, victim)
	end
	return if CollectionService:HasTag(model, Config.Combat.EnemyTag) then enemyTarget(model) else nil
end

-- Clave del uso en curso de "abilityId" de "player": todos sus golpes la llevan, así contra un jugador
-- gastan la guardia una vez y cuentan como un golpe en el escalado del combo (CombatService.damagePvP).
local function useKey(player: Player, abilityId: string): string
	local count = if uses[player] then uses[player][abilityId] or 0 else 0
	return `{player.UserId}:{abilityId}:{count}`
end

-- La habilidad "abilityId" del rol de "player" (Data/Roles, con la definitiva que ha elegido), o nil.
local function abilityOf(player: Player, abilityId: string): Roles.Ability?
	for _, ability in RoleAbilities.of(player) do
		if ability.id == abilityId then
			return ability
		end
	end
	return nil
end

-- Cómo alcanza una cobertura la habilidad "abilityId" (Combat/Destructibles): como definitiva o no.
local function coverKind(player: Player, abilityId: string): Destructibles.Kind
	local ability = abilityOf(player, abilityId)
	return if ability and ability.ultimate then "Ultimate" else "Ability"
end

-- El área de la habilidad "abilityId" alcanza las coberturas que toca, vistas desde "from" (por defecto,
-- el centro); con la misma tabla "once", una vez en todo el uso.
local function breakCovers(
	player: Player,
	abilityId: string,
	center: Vector3,
	radius: number,
	once: Destructibles.Once?,
	from: Vector3?
)
	Destructibles.blast(center, radius, coverKind(player, abilityId), player, once, from)
end

-- Daña a un objetivo con la habilidad "abilityId"; a los jugadores, menos (y las definitivas aún menos:
-- CombatRules.pvpUltimateMultiplier y su "pvpMultiplier"). Si la habilidad está enlazada en el combo y el objetivo lleva su
-- marca, es crítico seguro y hace el daño extra del combo (Data/Combos "damageBonus"); si no, es crítico
-- con la probabilidad del arma. Contra jugadores, el combo solo cuenta con CombatRules.pvpStatus (la arena).
-- Un jugador la puede bloquear o parar de frente (Combat/Guard): gasta el "guardDamage" de la habilidad
-- (o Config.Guard.AbilityGuardDamage) y las "unblockable" le rompen la guardia. Bloqueada o parada,
-- tampoco le aplica su control (control, slowDown y los empujes miran Guard.defended). Contra jugadores
-- lleva el escalado del combo (C7): todos los golpes de un uso cuentan como uno y gastan la guardia una
-- vez (C8).
local function hurt(attacker: Player, target: Target, amount: number, abilityId: string)
	if target.humanoid.Health <= 0 then
		return
	end
	if target.player then
		local rules = CombatRules.get()
		local ability = abilityOf(attacker, abilityId)
		if ability and ability.ultimate then
			amount *= rules.pvpUltimateMultiplier * (ability.pvpMultiplier or 1)
		end
		local crit = false
		if rules.pvpStatus then
			local comboHit = ComboService.isComboHit(attacker, target.model, abilityId)
			if comboHit then
				amount *= 1 + ComboService.linkedDamageBonus(attacker, abilityId)
			end
			ComboService.touch(attacker, abilityId, target.model)
			crit = comboHit
		end
		CombatService.damagePvP(
			attacker,
			target.player,
			math.max(1, math.round(amount * rules.pvpDamageMultiplier)),
			crit or CombatService.rollPlayerCrit(attacker),
			false,
			{
				guardDamage = if ability and ability.guardDamage
					then ability.guardDamage
					else Config.Guard.AbilityGuardDamage,
				unblockable = ability ~= nil and ability.unblockable == true,
				-- Todos los golpes de un uso cuentan como uno (Combat/ComboScaling) y gastan la guardia una vez.
				hitKey = useKey(attacker, abilityId),
			}
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

-- La primera habilidad del combo tocó a un enemigo: lo marca. A otro jugador, solo con
-- CombatRules.pvpStatus (la arena).
local function comboOpener(player: Player, abilityId: string, target: Target)
	if not target.player or CombatRules.get().pvpStatus then
		ComboService.opener(player, abilityId, target.model)
	end
end

-- Ralentiza al objetivo (Status.slow). A un jugador, solo con CombatRules.pvpStatus y menos rato
-- (pvpControlMultiplier); lo aplica su cliente (el controlador de movimiento del place).
local function slowDown(target: Target, seconds: number, factor: number)
	if target.player then
		local rules = CombatRules.get()
		if not rules.pvpStatus or Guard.defended(target.player) then
			return
		end
		seconds *= rules.pvpControlMultiplier
	end
	Status.slow(target.model, seconds, factor)
end

-- Hace resbalar a un jugador rival (el hielo de la Nova): con las mismas reglas que slowDown, su cliente
-- (ZoneController) lo nota con el atributo "SlipperyUntil" del personaje. Los monos no resbalan.
local function slip(target: Target, seconds: number)
	if target.player and CombatRules.get().pvpStatus then
		target.model:SetAttribute("SlipperyUntil", now() + seconds)
	end
end

-- Aturde, congela, inmoviliza o duerme. A un jugador, menos tiempo: aturdir y dormir lo aturden de
-- verdad (Status.stunPlayer: no anda ni pega); congelar e inmovilizar solo lo dejan quieto
-- (Status.holdPlayer: puede pegar). Congelado, inmovilizado y dormido se ven en los clientes (bloque de
-- hielo, brillo verde, "Zzz").
local function control(target: Target, seconds: number, look: ("Stun" | "Freeze" | "Root" | "Sleep")?)
	local duration = seconds
	if target.player then
		-- Lo ha bloqueado o parado (Combat/Guard): no le aturde.
		if Guard.defended(target.player) then
			return
		end
		duration *= CombatRules.get().pvpControlMultiplier
		local stuns = look == nil or look == "Stun" or look == "Sleep"
		local landed = if stuns
			then Status.stunPlayer(target.player, duration, "PvP")
			else Status.holdPlayer(target.player, duration, "PvP")
		if not landed then
			return
		end
	else
		-- Con los rendimientos decrecientes (Status), 0 si ya lo ha resistido.
		duration = Status.stun(target.model, seconds, look)
		if duration <= 0 then
			return
		end
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
	local result = Hitbox.sweepSphere(origin, radius, direction * range, { character })
	if result then
		return result.Position, result
	end
	return origin + direction * range, nil
end

-- El objetivo mejor alineado con la puntería, dentro de un cono, al alcance y sin nada en medio.
-- De cerca el cono es más ancho y solo cuenta en horizontal (CombatService.aimDeviation).
local function bestInCone(attacker: Player, origin: Vector3, aim: Vector3, range: number, degrees: number): Target?
	local best: Target? = nil
	local bestAngle = math.huge
	for _, target in targetsAround(attacker, origin, range) do
		local angle = CombatService.aimDeviation(origin, aim, target.root.Position, degrees)
		if angle and angle < bestAngle then
			best = target
			bestAngle = angle
		end
	end
	return best
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
	local coverOnce: Destructibles.Once = {}
	task.spawn(function()
		for _ = 1, hits do
			if not (root.Parent and LifeState.isAlive(player)) then
				break
			end
			Sfx.play("Swing", root)
			for _, target in targetsAround(player, root.Position, SETTINGS.WhirlwindRadius) do
				hurt(player, target, damage, "Whirlwind")
			end
			breakCovers(player, "Whirlwind", root.Position, SETTINGS.WhirlwindRadius, coverOnce)
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
	local coverOnce: Destructibles.Once = {}
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
					-- También a los jugadores rivales (lo aplica su cliente), salvo si la han bloqueado o
					-- parado (Combat/Guard); a los jefes, no.
					if not (target.player and Guard.defended(target.player)) then
						Knockback.push(
							target.model,
							direction,
							SETTINGS.ChargeKnockback,
							SETTINGS.ChargeKnockbackSeconds,
							nil,
							player
						)
					end
				end
			end
			breakCovers(player, "Charge", root.Position, SETTINGS.ChargeWidth, coverOnce)
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
		end
		-- A los rivales no se les puede provocar, pero en la arena el grito también los marca y aturde.
		if not target.player or CombatRules.get().pvpStatus then
			if linked and ComboService.isMarkedBy(target.model, player) then
				control(target, COMBO.WarCryStun, "Stun")
			end
			-- Primer paso de "Martillo y yunque": los provocados quedan marcados.
			comboOpener(player, "WarCry", target)
		end
	end
	local reductionPerk = Progression.perk(player, "WarCryReduction")
	player:SetAttribute("GuardUntil", now() + seconds)
	player:SetAttribute("GuardReduction", reductionPerk)
	-- "Peto de escamas de ámbar" (equipo de la arena, ventaja WarCryAllies): también protege a los
	-- aliados del radio, sin quitarles una protección mayor que ya tengan.
	if Progression.perk(player, "WarCryAllies") >= 1 then
		local rules = CombatRules.get()
		for _, ally in Players:GetPlayers() do
			local allyCharacter = ally.Character
			local allyRoot = if allyCharacter then allyCharacter:FindFirstChild("HumanoidRootPart") else nil
			local guarded = ally:GetAttribute("GuardUntil")
			local stronger = typeof(guarded) == "number"
				and now() < guarded
				and (ally:GetAttribute("GuardReduction") or 0) > reductionPerk
			if
				ally ~= player
				and not stronger
				and rules.isAlly(player, ally)
				and allyRoot
				and allyRoot:IsA("BasePart")
				and (allyRoot.Position - root.Position).Magnitude <= SETTINGS.WarCryRadius
			then
				ally:SetAttribute("GuardUntil", now() + seconds)
				ally:SetAttribute("GuardReduction", reductionPerk)
				AbilityFx.all("ShieldGlare", allyCharacter)
			end
		end
	end
	AbilityFx.all("WarCry", character, seconds)
	local reduction = math.round(Progression.perk(player, "WarCryReduction") * 100)
	Remotes.Notify:FireClient(
		player,
		if taunted == 1
			then later("⚔️ ¡Un mono va a por ti! Recibes un {reduction} % menos de daño")
			else later("⚔️ ¡{taunted} monos van a por ti! Recibes un {reduction} % menos de daño"),
		{ taunted = taunted, reduction = reduction }
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
	breakCovers(player, "Quake", root.Position, SETTINGS.QuakeRadius)
	Sfx.play("RockImpact", root)
	AbilityFx.all("Quake", ground, SETTINGS.QuakeRadius)
	return true
end

-- Rompehuesos: golpe pesado a los monos del cono de delante (el cliente gira al guerrero hacia donde
-- apunta), que los tumba y los aparta un poco (contra un muro, rebotan: Combat/Knockback). Como remate de
-- "Martillo y yunque", a todos los de alrededor.
local function smash(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local damage = SETTINGS.SmashDamage
		* Progression.perk(player, "MeleeDamage")
		* Progression.perk(player, "SmashDamage")
	local around = ComboService.isPayoff(player, "Smash")
	local facing = flat(aim)
	local minDot = math.cos(math.rad(SETTINGS.SmashAngle / 2))
	local ground = groundBelow(root.Position, { character })
	-- Sale cuando el arma baja: la preparación (castSeconds) dura lo que el gesto hasta el golpe.
	AbilityFx.all("Smash", ground, facing, SETTINGS.SmashRange, if around then 360 else SETTINGS.SmashAngle)
	Sfx.play("RockImpact", root)
	for _, target in targetsAround(player, root.Position, SETTINGS.SmashRange) do
		local offset = target.root.Position - root.Position
		local inFront = flat(offset):Dot(facing) >= minDot or offset.Magnitude < 2
		if around or inFront then
			hurt(player, target, damage, "Smash")
			control(target, SETTINGS.SmashStun, "Stun")
			-- Hacia fuera desde el guerrero (al que está pegado, hacia delante). A los jefes, no.
			if not (target.player and Guard.defended(target.player)) then
				local away = if offset.Magnitude < 2 then facing else flat(offset)
				Knockback.push(target.model, away, SETTINGS.SmashKnockback, SETTINGS.SmashKnockbackSeconds, nil, player)
			end
		end
	end
	-- Las coberturas, en el cono de delante (una esfera que lo cubre) o, rematado, alrededor.
	if around then
		breakCovers(player, "Smash", root.Position, SETTINGS.SmashRange)
	else
		breakCovers(
			player,
			"Smash",
			root.Position + facing * SETTINGS.SmashRange / 2,
			SETTINGS.SmashRange / 2,
			nil,
			root.Position
		)
	end
	return true
end

-- Salto del gorila (T7): el cliente salta (RoleController) hasta el punto que manda en "extra[2]" (solo
-- se acepta al alcance; si no, cae al frente). Aquí, la sombra que avisa a todos de dónde cae y, al caer,
-- el golpe: al que cae encima (el más cercano al punto), el daño grande y el inmovilizado ("QuakeStun",
-- como el Pisotón); a los demás del radio, la salpicadura. No se puede bloquear.
local function leap(player: Player, character: Model, root: BasePart, aim: Vector3, extra: { any }): boolean
	local landing = extra[2]
	local reach = SETTINGS.LeapRange + BLINK_POINT_SLACK
	if typeof(landing) ~= "Vector3" or (landing - root.Position).Magnitude > reach then
		landing = root.Position + flat(aim) * SETTINGS.LeapRange
	end
	local ground = groundBelow(landing, { character })
	local flight = SETTINGS.LeapFlightSeconds
	local melee = Progression.perk(player, "MeleeDamage")
	local hold = Progression.perk(player, "QuakeStun")
	AbilityFx.all("LeapMark", ground, SETTINGS.LeapSplashRadius, flight)
	Sfx.play("Swing", root)
	task.delay(flight, function()
		if not (player.Parent and LifeState.isAlive(player)) then
			return
		end
		local targets = targetsAroundGround(player, ground, SETTINGS.LeapSplashRadius)
		local main: Target? = nil
		local closest = math.huge
		for _, target in targets do
			local distance = (target.root.Position - ground).Magnitude
			if distance < closest then
				main = target
				closest = distance
			end
		end
		for _, target in targets do
			if target == main then
				hurt(player, target, SETTINGS.LeapDamage * melee, "Leap")
				control(target, hold, "Root")
			else
				hurt(player, target, SETTINGS.LeapSplashDamage * melee, "Leap")
			end
		end
		breakCovers(
			player,
			"Leap",
			ground,
			SETTINGS.LeapSplashRadius,
			nil,
			ground + Vector3.new(0, Config.Combat.AreaSightLift, 0)
		)
		Sfx.play("RockImpact", ground)
		AbilityFx.all("Quake", ground, SETTINGS.LeapSplashRadius)
	end)
	return true
end

-- ===================================== Cazador =====================================

-- Disparo múltiple: flechas en abanico, cada una un proyectil (Combat/Projectiles) que da al primero
-- que encuentra. El abanico se centra con la ayuda de puntería (CombatService.aimShot: el mono de delante,
-- también si está pegado).
local function multiShot(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local count = math.max(1, math.floor(Progression.perk(player, "MultiShotCount")))
	-- Remate del combo del cazador: más proyectiles (y críticos a los atrapados, en hurt).
	if ComboService.isPayoff(player, "MultiShot") then
		count += COMBO.MultiShotExtraArrows
	end
	local damage = SETTINGS.MultiShotDamage * Progression.perk(player, "RangedDamage")
	local origin = headOf(character, root)
	local spread = math.rad(SETTINGS.MultiShotSpreadDegrees)
	aim = CombatService.aimShot(player, origin, aim, SETTINGS.MultiShotRange, SETTINGS.MultiShotSpeed)
	Sfx.play("Shoot", root)
	-- Todas las flechas del abanico alcanzan una cobertura una sola vez.
	local coverOnce: Destructibles.Once = {}
	for index = 1, count do
		local angle = if count == 1 then 0 else -spread / 2 + spread * (index - 1) / (count - 1)
		Projectiles.fire({
			owner = player,
			look = "MultiShot",
			origin = origin,
			direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(aim),
			speed = SETTINGS.MultiShotSpeed,
			range = SETTINGS.MultiShotRange,
			radius = 1,
			-- Las del borde del abanico fallan a propósito: no cuentan en la tasa de acierto.
			counts = false,
			breaks = coverKind(player, "MultiShot"),
			breakOnce = coverOnce,
			onHit = function(model)
				local target = targetOfModel(player, model)
				if not target then
					return false
				end
				hurt(player, target, damage, "MultiShot")
				return true
			end,
		})
	end
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
	-- En la arena también se marca a los rivales (reciben el daño extra en CombatService.damagePvP).
	if CombatRules.get().pvpStatus then
		for _, other in Players:GetPlayers() do
			local target = playerTarget(player, other)
			if target and (target.root.Position - root.Position).Magnitude <= SETTINGS.MarkRadius then
				if linked and ComboService.isMarkedBy(target.model, player) then
					control(target, COMBO.MarkPreyRoot, "Root")
				end
				comboOpener(player, "MarkPrey", target)
				target.model:SetAttribute("MarkedUntil", untilTime)
				target.model:SetAttribute("MarkBonus", bonus)
				local highlight = Instance.new("Highlight")
				highlight.Name = "PreyMark"
				highlight.FillTransparency = 1
				highlight.OutlineColor = Color3.fromRGB(255, 70, 50)
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = target.model
				Debris:AddItem(highlight, seconds)
				marked += 1
			end
		end
	end
	-- Las dianas sobre las presas salen del atributo "MarkedUntil" en cada cliente.
	AbilityFx.all("MarkPrey", root.Position, SETTINGS.MarkRadius)
	Remotes.Notify:FireClient(
		player,
		if marked == 1
			then later("🏹 Una presa marcada durante {seconds} s")
			else later("🏹 {marked} presas marcadas durante {seconds} s"),
		{ marked = marked, seconds = seconds }
	)
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
	local coverOnce: Destructibles.Once = {}
	local lift = Config.Combat.AreaSightLift
	Sfx.play("Shoot", root)
	-- La nube y las flechas que caen las dibujan los clientes.
	AbilityFx.all("ArrowRain", center, SETTINGS.RainRadius, SETTINGS.RainSeconds)
	task.spawn(function()
		for _ = 1, SETTINGS.RainTicks do
			task.wait(0.2)
			for _, target in targetsAroundGround(player, center, SETTINGS.RainRadius) do
				hurt(player, target, damage, "ArrowRain")
			end
			breakCovers(player, "ArrowRain", center, SETTINGS.RainRadius, coverOnce, center + Vector3.new(0, lift, 0))
			task.wait(math.max(0, interval - 0.2))
		end
	end)
	return true
end

-- Disparo certero (T7): un proyectil rápido a uno. Mientras se prepara, los demás ven su línea de aviso
-- (CAST_FX). Para en el primero que toca; una cobertura la rompe de un golpe (como definitiva).
local function trueShot(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local damage = SETTINGS.TrueShotDamage
		* Progression.perk(player, "RangedDamage")
		* Progression.perk(player, "RainDamage")
	local origin = headOf(character, root)
	aim = CombatService.aimShot(player, origin, aim, SETTINGS.TrueShotRange, SETTINGS.TrueShotSpeed)
	Sfx.play("Shoot", root)
	Projectiles.fire({
		owner = player,
		look = "TrueShot",
		origin = origin,
		direction = aim,
		speed = SETTINGS.TrueShotSpeed,
		range = SETTINGS.TrueShotRange,
		radius = 1,
		breaks = coverKind(player, "TrueShot"),
		onHit = function(model)
			local target = targetOfModel(player, model)
			if not target then
				return false
			end
			hurt(player, target, damage, "TrueShot")
			return true
		end,
	})
	return true
end

-- Flecha perforante: un proyectil que atraviesa a todos los que encuentra en línea recta (a cada uno una
-- vez, cuando le llega); solo la para el terreno o una pared. Como remate de "Tiro de gracia", dispara
-- más en un abanico estrecho.
local function piercingShot(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local damage = SETTINGS.PierceDamage
		* Progression.perk(player, "RangedDamage")
		* Progression.perk(player, "PierceDamage")
	local count = 1
	if ComboService.isPayoff(player, "PiercingShot") then
		count += COMBO.PierceExtraArrows
	end
	local origin = headOf(character, root)
	aim = CombatService.aimShot(player, origin, aim, SETTINGS.PierceRange, SETTINGS.PierceSpeed)
	local spread = math.rad(COMBO.PierceSpreadDegrees)
	local coverOnce: Destructibles.Once = {}
	for index = 1, count do
		local angle = if count == 1 then 0 else -spread / 2 + spread * (index - 1) / (count - 1)
		Projectiles.fire({
			owner = player,
			look = "PiercingShot",
			origin = origin,
			direction = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(aim),
			speed = SETTINGS.PierceSpeed,
			range = SETTINGS.PierceRange,
			radius = SETTINGS.PierceWidth,
			pierce = true,
			counts = false,
			breaks = coverKind(player, "PiercingShot"),
			breakOnce = coverOnce,
			onHit = function(model)
				local target = targetOfModel(player, model)
				if not target then
					return false
				end
				hurt(player, target, damage, "PiercingShot")
				return true
			end,
		})
	end
	Sfx.play("Shoot", root)
	return true
end

-- ===================================== Mago =====================================

-- Bola de fuego: un proyectil (Combat/Projectiles) que estalla donde para (en el primero que toca, en
-- una pared o al final de su alcance): daño al impactado y salpicadura a los de alrededor.
local function fireball(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local scale = Progression.perk(player, "SpellDamage") * Progression.perk(player, "FireballDamage")
	local origin = headOf(character, root)
	aim = CombatService.aimShot(player, origin, aim, SETTINGS.FireballRange, SETTINGS.FireballSpeed)
	-- Remate del combo del mago: rompe el hielo con una explosión más grande.
	local finisher = ComboService.isPayoff(player, "Fireball")
	local radius = SETTINGS.FireballSplashRadius * (if finisher then 1 + COMBO.FireballSplashBonus else 1)
	Sfx.play("Shoot", root)
	local direct: Target? = nil
	Projectiles.fire({
		owner = player,
		look = "Fireball",
		origin = origin,
		direction = aim,
		speed = SETTINGS.FireballSpeed,
		range = SETTINGS.FireballRange,
		radius = 1.5,
		extra = { radius },
		onHit = function(model)
			direct = targetOfModel(player, model)
			return direct ~= nil
		end,
		onEnd = function(endPoint)
			Sfx.play("LavaImpact", endPoint)
			local function strike(target: Target, amount: number)
				if finisher and ComboService.isMarkedBy(target.model, player) then
					AbilityFx.all("IceShatter", target.root.Position)
				end
				hurt(player, target, amount, "Fireball")
				-- Primer paso de "Lluvia de estrellas": lo que quema queda chamuscado.
				comboOpener(player, "Fireball", target)
			end
			local hit = direct
			if hit then
				strike(hit, SETTINGS.FireballDamage * scale)
			end
			-- La explosión mira desde un stud antes del impacto: si la bola da en una pared, lo de detrás no
			-- se quema.
			for _, target in targetsAround(player, endPoint, radius, endPoint - aim) do
				if not (hit and target.model == hit.model) then
					strike(target, SETTINGS.FireballSplashDamage * scale)
				end
			end
			breakCovers(player, "Fireball", endPoint, radius, nil, endPoint - aim)
		end,
	})
	return true
end

-- Nova de hielo: congela y ralentiza a los de alrededor, y deja su radio helado unos segundos
-- (Config.Zones.Ice): quien entra va lento y, si es un rival, resbala.
local function frostNova(player: Player, character: Model, root: BasePart): boolean
	local damage = SETTINGS.NovaDamage * Progression.perk(player, "SpellDamage")
	local freeze = Progression.perk(player, "NovaFreeze")
	for _, target in targetsAround(player, root.Position, SETTINGS.NovaRadius) do
		hurt(player, target, damage, "FrostNova")
		control(target, freeze, "Freeze")
		comboOpener(player, "FrostNova", target)
		slowDown(target, freeze + SETTINGS.NovaSlowSeconds, SETTINGS.NovaSlowFactor)
	end
	breakCovers(player, "FrostNova", root.Position, SETTINGS.NovaRadius)
	AbilityFx.all("FrostNova", root.Position, SETTINGS.NovaRadius)
	Sfx.play("Hit", root)
	local ground = groundBelow(root.Position, { character })
	local ice = ZONES.Ice
	local lasts = ZONES.TickSeconds + ZONES.LingerSeconds
	Zones.create({
		kind = "Ice",
		owner = player,
		center = ground,
		radius = SETTINGS.NovaRadius,
		seconds = ice.Seconds,
		tickSeconds = ZONES.TickSeconds,
		onTick = function()
			for _, target in targetsOnGround(player, ground, SETTINGS.NovaRadius, ZONES.Height) do
				slowDown(target, lasts, ice.SlowFactor)
				slip(target, lasts)
			end
		end,
	})
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
	local first = bestInCone(player, origin, aim, SETTINGS.ChainRange, 25)
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

-- Haz volcánico (T7): un rayo de lava fijo en el enemigo mejor alineado con la puntería, un golpe cada
-- BeamSeconds ÷ BeamTicks (y uno más por cada salto de más del talento Tormenta). Mientras dura, el mago
-- sigue "Casting" (anda, pero no pega ni usa otra habilidad): si le aturden, se corta. También se corta
-- si el enemigo cae o se aleja más de BeamLeash. Si algo lo tapa, ese golpe no entra; si es una
-- cobertura, el haz la quema (de un golpe, como definitiva).
local function lavaBeam(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local target = bestInCone(player, headOf(character, root), aim, SETTINGS.BeamRange, 25)
	if not target then
		Remotes.Notify:FireClient(player, "🔮 No hay ningún enemigo a tiro: apunta hacia uno")
		return false
	end
	local extraTicks = math.max(0, math.floor(Progression.perk(player, "ChainJumps") - Perks.ChainJumps))
	local ticks = SETTINGS.BeamTicks + extraTicks
	local interval = SETTINGS.BeamSeconds / SETTINGS.BeamTicks
	local seconds = ticks * interval
	local damage = SETTINGS.BeamDamage * Progression.perk(player, "SpellDamage")
	-- Con margen (cada espera se retrasa un poco): al acabar se quita.
	StateMachine.enter(player, "Casting", seconds + CAST_STATE_MARGIN)
	-- El rayo lo dibuja cada cliente mientras dure este atributo (se quita antes si se corta).
	character:SetAttribute("LavaBeamUntil", now() + seconds)
	AbilityFx.all("LavaBeam", character, target.model, seconds)
	Sfx.play("LavaLaunch", root)
	local coverOnce: Destructibles.Once = {}
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(interval)
			local casting = player.Parent and LifeState.isAlive(player) and CombatState.get(player) == "Casting"
			local reachable = root.Parent
				and target.root.Parent
				and target.humanoid.Health > 0
				and (target.root.Position - root.Position).Magnitude <= SETTINGS.BeamLeash
			if not (casting and reachable) then
				break
			end
			local from = headOf(character, root)
			local blocked = Hitbox.ray(from, target.root.Position - from)
			if blocked then
				Destructibles.hitPart(
					blocked.Instance,
					coverKind(player, "LavaBeam"),
					player,
					blocked.Position,
					coverOnce
				)
			else
				hurt(player, target, damage, "LavaBeam")
			end
		end
		StateMachine.leave(player, "Casting")
		if character.Parent then
			character:SetAttribute("LavaBeamUntil", nil)
		end
	end)
	return true
end

-- Meteoro: una roca ardiente cae donde apunta el mago tras un aviso en el suelo. Como remate de
-- "Lluvia de estrellas", deja el suelo ardiendo unos segundos (zona "Fire" de Combat/Zones: un golpe por
-- segundo a quien siga en el radio).
local function meteor(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	local endPoint = castShot(character, origin, aim, SETTINGS.MeteorMaxDistance, 0.5)
	local center = groundBelow(endPoint, { character })
	local scale = Progression.perk(player, "SpellDamage")
	local slow = Progression.perk(player, "MeteorSlow")
	local burnTicks = if ComboService.isPayoff(player, "Meteor") then COMBO.MeteorBurnTicks else 0
	AbilityFx.all("Meteor", center, SETTINGS.MeteorRadius, SETTINGS.MeteorDelay)
	Sfx.play("LavaLaunch", root)
	task.spawn(function()
		task.wait(SETTINGS.MeteorDelay)
		Sfx.play("LavaImpact", center)
		for _, target in targetsAroundGround(player, center, SETTINGS.MeteorRadius) do
			hurt(player, target, SETTINGS.MeteorDamage * scale, "Meteor")
			if slow > 0 then
				slowDown(target, slow, SETTINGS.NovaSlowFactor)
			end
		end
		breakCovers(
			player,
			"Meteor",
			center,
			SETTINGS.MeteorRadius,
			nil,
			center + Vector3.new(0, Config.Combat.AreaSightLift, 0)
		)
		if burnTicks > 0 and player.Parent then
			Zones.create({
				kind = "Fire",
				owner = player,
				center = center,
				radius = SETTINGS.MeteorRadius,
				seconds = burnTicks,
				tickSeconds = 1,
				firstTick = 1,
				onTick = function()
					for _, target in targetsAroundGround(player, center, SETTINGS.MeteorRadius) do
						hurt(player, target, COMBO.MeteorBurnDamage * scale, "Meteor")
					end
				end,
			})
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
	local feverCure = (if finisher then COMBO.SalveFeverCure else 0) + CombatRules.get().salveFeverCure()
	local healed = 0
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local otherRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local near = otherRoot
			and otherRoot:IsA("BasePart")
			and (otherRoot.Position - root.Position).Magnitude <= SETTINGS.AreaHealRadius
		if near and heal(player, other, amount, "AreaHeal") then
			healed += 1
			if feverCure > 0 then
				CombatRules.get().addFever(other, -feverCure)
			end
		end
	end
	local poisoned = 0
	if finisher then
		local rules = CombatRules.get()
		for _, target in targetsAround(player, root.Position, SETTINGS.AreaHealRadius) do
			if not target.player then
				Status.poison(target.model, COMBO.SalvePoisonDps, COMBO.SalvePoisonSeconds, player, "AreaHeal")
				poisoned += 1
			elseif rules.pvpStatus then
				-- A un rival, con el daño de las habilidades contra jugadores.
				Status.poison(
					target.model,
					COMBO.SalvePoisonDps * rules.pvpDamageMultiplier,
					COMBO.SalvePoisonSeconds,
					player,
					"AreaHeal"
				)
				poisoned += 1
			end
		end
	end
	AbilityFx.all("AreaHeal", root.Position, SETTINGS.AreaHealRadius)
	Sfx.play("Heal", root)
	Remotes.Notify:FireClient(
		player,
		if finisher
			then later(
				"⛑️ ¡Cura de urgencia! Has curado a {healed} jugadores, les has bajado la fiebre y has envenenado a {poisoned} monos"
			)
			elseif healed == 1 then later("⛑️ Has curado a un jugador")
			else later("⛑️ Has curado a {healed} jugadores"),
		{ healed = healed, poisoned = poisoned }
	)
	return true
end

-- Dardo curativo: un proyectil (Combat/Projectiles) que cura al primer aliado que toca o hiere al primer
-- mono o rival. La ayuda de puntería también busca a los aliados.
local function healingDart(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	aim = CombatService.aimShot(player, origin, aim, SETTINGS.DartRange, SETTINGS.DartSpeed, true)
	Sfx.play("Shoot", root)
	Projectiles.fire({
		owner = player,
		look = "HealingDart",
		origin = origin,
		direction = aim,
		speed = SETTINGS.DartSpeed,
		range = SETTINGS.DartRange,
		radius = 1.5,
		onHit = function(model)
			local ally = Players:GetPlayerFromCharacter(model)
			if ally and CombatRules.get().isAlly(player, ally) then
				if not heal(player, ally, SETTINGS.DartHeal * Progression.perk(player, "HealPower"), "HealingDart") then
					return false
				end
				local allyRoot = model:FindFirstChild("HumanoidRootPart")
				if allyRoot and allyRoot:IsA("BasePart") then
					AbilityFx.all("HealBurst", allyRoot.Position)
					Sfx.play("Heal", allyRoot)
				end
				-- Primer paso del combo del médico: el aliado queda "revitalizado".
				ComboService.opener(player, "HealingDart", model)
				Remotes.Notify:FireClient(player, "⛑️ Dardo curativo a {name}", { name = ally.DisplayName })
				return true
			end
			local enemy = targetOfModel(player, model)
			if not enemy then
				return false
			end
			hurt(player, enemy, SETTINGS.DartDamage, "HealingDart")
			comboOpener(player, "HealingDart", enemy)
			return true
		end,
	})
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
		Remotes.Notify:FireClient(
			chosen,
			"🍃 {name} te protege con un escudo de {amount}",
			{ name = player.DisplayName, amount = amount }
		)
		Remotes.Notify:FireClient(
			player,
			"🍃 Escudo de {amount} para {name}",
			{ amount = amount, name = chosen.DisplayName }
		)
	else
		Remotes.Notify:FireClient(player, "🍃 Te proteges con un escudo de {amount}", { amount = amount })
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
	Remotes.Notify:FireClient(player, "⛑️ Tótem sanador durante {seconds} s", { seconds = SETTINGS.TotemSeconds })
	return true
end

-- Resurgir (T7): cura de golpe a los aliados del radio (y al médico) y les quita el veneno y, salvo en la
-- arena (CombatRules.pvpStatus), el aturdido, el agarre y el lanzamiento (Status.cleansePlayer): allí el
-- control del rival se respeta y la salida es el Evasivo.
local function resurgence(player: Player, _character: Model, root: BasePart): boolean
	local amount = SETTINGS.SurgeHeal * Progression.perk(player, "HealPower")
	local controls = not CombatRules.get().pvpStatus
	local healed = 0
	for _, other in Players:GetPlayers() do
		local otherCharacter = other.Character
		local otherRoot = if otherCharacter then otherCharacter:FindFirstChild("HumanoidRootPart") else nil
		if
			otherRoot
			and otherRoot:IsA("BasePart")
			and (otherRoot.Position - root.Position).Magnitude <= SETTINGS.SurgeRadius
			and heal(player, other, amount, "Resurgence")
		then
			Status.cleansePlayer(other, controls)
			AbilityFx.all("HealBurst", otherRoot.Position)
			healed += 1
		end
	end
	AbilityFx.all("Resurgence", root.Position, SETTINGS.SurgeRadius)
	Sfx.play("Heal", root)
	Remotes.Notify:FireClient(
		player,
		if healed == 1
			then later("⛑️ ¡Resurgir! Has curado y limpiado a un jugador")
			else later("⛑️ ¡Resurgir! Has curado y limpiado a {healed} jugadores"),
		{ healed = healed }
	)
	return true
end

-- Polvo somnífero: una nube donde apunta el médico. A los monos les entra sueño (van lentos) y luego
-- se duermen; los jefes no se duermen. La nube se queda unos segundos (zona "Cloud", Config.Zones): a
-- quien entra después le entra sueño, sin dormirle. Como remate de "Nana de la selva", duermen más, la
-- nube cura a los aliados que estén dentro y los dormidos reciben más daño hasta despertar (Status.expose).
local function sleepPowder(player: Player, character: Model, root: BasePart, aim: Vector3): boolean
	local origin = headOf(character, root)
	local endPoint = castShot(character, origin, aim, SETTINGS.PowderMaxDistance, 0.5)
	local center = groundBelow(endPoint, { character })
	local finisher = ComboService.isPayoff(player, "SleepPowder")
	local sleep = Progression.perk(player, "PowderSleep") + (if finisher then COMBO.PowderExtraSleep else 0)
	local drowsy = SETTINGS.PowderDrowsySeconds
	AbilityFx.all("SleepPowder", origin, center, SETTINGS.PowderRadius)
	Sfx.play("Shoot", root)
	task.spawn(function()
		-- Lo que tarda el puñado de polvo en llegar.
		task.wait(0.5)
		if not player.Parent then
			return
		end
		local lasts = ZONES.TickSeconds + ZONES.LingerSeconds
		Zones.create({
			kind = "Cloud",
			owner = player,
			center = center,
			radius = SETTINGS.PowderRadius,
			seconds = ZONES.Cloud.Seconds,
			tickSeconds = ZONES.TickSeconds,
			onTick = function()
				for _, target in targetsAroundGround(player, center, SETTINGS.PowderRadius) do
					if target.player then
						slowDown(target, lasts, SETTINGS.PowderSlowFactor)
					elseif not Status.isBoss(target.model) then
						Status.slow(target.model, lasts, SETTINGS.PowderSlowFactor)
					end
				end
			end,
		})
		local sleepers: { Target } = {}
		for _, target in targetsAroundGround(player, center, SETTINGS.PowderRadius) do
			hurt(player, target, SETTINGS.PowderDamage, "SleepPowder")
			if target.player then
				slowDown(target, drowsy, SETTINGS.PowderSlowFactor)
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
				if finisher and (not target.player or CombatRules.get().pvpStatus) then
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
	Leap = leap,
	Smash = smash,
	MultiShot = multiShot,
	MarkPrey = markPrey,
	Trap = trap,
	ArrowRain = arrowRain,
	TrueShot = trueShot,
	PiercingShot = piercingShot,
	Fireball = fireball,
	FrostNova = frostNova,
	Blink = blink,
	ChainLightning = chainLightning,
	LavaBeam = lavaBeam,
	Meteor = meteor,
	AreaHeal = areaHeal,
	HealingDart = healingDart,
	LeafShield = leafShield,
	HealingTotem = healingTotem,
	Resurgence = resurgence,
	SleepPowder = sleepPowder,
}

-- Sale la habilidad del hueco "slot": cuenta el paso del combo, la aplica y, si se ha podido usar,
-- empieza su recarga.
local function release(player: Player, slot: number, ability: Roles.Ability, aim: Vector3, extra: { any })
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local handler = HANDLERS[ability.id]
	if not (character and root and root:IsA("BasePart") and handler and LifeState.isAlive(player)) then
		return
	end
	local count = uses[player] or {}
	uses[player] = count
	count[ability.id] = (count[ability.id] or 0) + 1
	-- Antes de aplicarla: si es el siguiente paso del combo, sus golpes ya cuentan como enlazados.
	local linkedStep = ComboService.onAbilityUsed(player, ability.id)
	if handler(player, character, root, aim, extra) then
		local rules = CombatRules.get()
		rules.telemetry.abilityUsed(player, ability.id, linkedStep)
		rules.progressMission(player, "Ability")
		-- Algunas habilidades tienen su propia ventaja de recarga ("<id>Cooldown" en Data/Perks, p. ej.
		-- SmashCooldown, del equipo de la arena).
		local ownRate = if Perks[`{ability.id}Cooldown`] ~= nil
			then Progression.perk(player, `{ability.id}Cooldown`)
			else 1
		local cooldown = ability.cooldownSeconds
			* Progression.perk(player, "CooldownRate")
			* ownRate
			* ComboService.cooldownFactor(player)
		player:SetAttribute(`AbilityReadyAt{slot}`, now() + cooldown)
	end
end

-- Preparación de la habilidad del hueco "slot" (C8): "Casting" hasta que sale. Si al acabar ya no está
-- en "Casting" (le han aturdido, tambaleado o ha caído) no sale; si amaga (Combat/Feint), tampoco, y
-- queda la recarga de penalización.
local function cast(player: Player, slot: number, ability: Roles.Ability, aim: Vector3, extra: { any }, seconds: number)
	local ticket = (castTickets[player] or 0) + 1
	castTickets[player] = ticket
	local delay = math.max(0, seconds - Latency.compensation(player))
	-- Con margen, para que el estado no se quede puesto si cae a mitad (al salir se quita).
	StateMachine.enter(player, "Casting", delay + CAST_STATE_MARGIN)
	local castFx = CAST_FX[ability.id]
	local character = player.Character
	if castFx and character then
		AbilityFx.others(player, castFx, character, aim, delay)
	end
	local mark = Feint.begin(player, "Ability", delay, function()
		castTickets[player] = ticket + 1
		StateMachine.leave(player, "Casting")
		player:SetAttribute(`AbilityReadyAt{slot}`, now() + Config.Feint.AbilityPenaltySeconds)
	end)
	task.delay(delay, function()
		Feint.finish(player, mark)
		if castTickets[player] ~= ticket or not player.Parent or CombatState.get(player) ~= "Casting" then
			return
		end
		StateMachine.leave(player, "Casting")
		if MOVEMENT_ABILITIES[ability.id] and player:GetAttribute("MovementLocked") == true then
			return
		end
		release(player, slot, ability, aim, extra)
	end)
end

-- "from" y "to": dónde empezó y acabó el Parpadeo en el cliente (solo para su efecto), o dónde cae el
-- Salto del gorila ("to").
local function onUseAbility(player: Player, slot: any, aim: any, from: any, to: any)
	if typeof(slot) ~= "number" or typeof(aim) ~= "Vector3" or aim.Magnitude < 0.5 then
		return
	end
	local ability = RoleAbilities.of(player)[slot]
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (ability and character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return
	end
	if not LifeState.isAlive(player) or not CombatState.canAct(player, "Ability") then
		return
	end
	local readyAt = player:GetAttribute(`AbilityReadyAt{slot}`)
	-- Pequeño margen por el retraso de la red (el cliente ya comprobó el tiempo de espera).
	if typeof(readyAt) == "number" and now() < readyAt - 0.25 then
		return
	end
	if not HANDLERS[ability.id] then
		return
	end
	if MOVEMENT_ABILITIES[ability.id] and player:GetAttribute("MovementLocked") == true then
		return
	end
	local seconds = ability.castSeconds or Config.Windup.AbilityDefaultSeconds
	if seconds > 0 then
		cast(player, slot, ability, aim.Unit, { from, to }, seconds)
	else
		release(player, slot, ability, aim.Unit, { from, to })
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
		uses[player] = nil
		castTickets[player] = nil
	end)
end

return AbilityService
