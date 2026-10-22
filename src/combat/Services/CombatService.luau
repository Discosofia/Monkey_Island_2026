--!strict
-- Combate (GDD §6, Fase 1.3): armas cuerpo a cuerpo, a distancia (honda y arco, que gastan munición;
-- bastón mágico y cerbatanas, que no; los dardos de las cerbatanas envenenan) y esquiva.
-- Los disparos son proyectiles reales (Fase 10, C9; Combat/Projectiles): van rectos, se pueden esquivar
-- y la ayuda de puntería (aimShot) solo elige hacia dónde salen.
-- El servidor decide todo: qué arma lleva el jugador, si el ataque está listo, a quién golpea y el daño.
-- Se daña a lo que tenga la etiqueta Config.Combat.EnemyTag (monos, muñecos de práctica) y a otros
-- jugadores cuando las reglas del place lo permiten (CombatRules: el PvP opt-in de la Isla, los
-- equipos de la arena). Cada jugador aparece con las armas de su rol (Data/Roles) y las herramientas
-- comunes del place. A quién alcanza cada golpe lo dice Combat/Hitbox (con línea de visión).
-- Las armas cuerpo a cuerpo pegan en cadena (Fase 10, C4; Shared/MeleeChain): 4 golpes con preparación,
-- el 4.º remata y empuja (o lanza hacia arriba si se da en el aire); en PvP cada golpe tambalea un poco.
-- El hacha, el pico y la hoz siguen con el golpe suelto.
-- Guardia (C5, Combat/Guard): los golpes de monos y jefes que la pasan (damagePlayer con "guard") y los
-- de otros jugadores (damagePvP con "guard") se pueden bloquear y parar.
-- Escape y equidad del combo (C7): esquivar atrapado es el Evasivo (Combat/Evasive) y los golpes de un
-- jugador a otro llevan el escalado del combo (Combat/ComboScaling).
-- Amagos (C8, Combat/Feint): pulsar la guardia durante la preparación de un golpe de la cadena lo cancela.
-- Disparo de remate (C9b, Shared/RangedChain): el 4.º disparo seguido al mismo ritmo con un arma a
-- distancia es un remate, distinto por arma (atraviesa, estalla, cura el doble o tambalea a un mono).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Armor = require(ReplicatedStorage.Shared.Data.Armor)
local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local Crit = require(ReplicatedStorage.Shared.Crit)
local Guard = require(script.Parent.Parent.Guard)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local MeleeChain = require(ReplicatedStorage.Shared.MeleeChain)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local Progression = require(ReplicatedStorage.Shared.Progression)
local RangedChain = require(ReplicatedStorage.Shared.RangedChain)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local ComboService = require(script.Parent.ComboService)
local AbilityFx = require(script.Parent.Parent.AbilityFx)
local CombatRules = require(script.Parent.Parent.CombatRules)
local CombatText = require(script.Parent.Parent.CombatText)
local ComboScaling = require(script.Parent.Parent.ComboScaling)
local Evasive = require(script.Parent.Parent.Evasive)
local Feint = require(script.Parent.Parent.Feint)
local Hitbox = require(script.Parent.Parent.Hitbox)
local Knockback = require(script.Parent.Parent.Knockback)
local Latency = require(script.Parent.Parent.Latency)
local Projectiles = require(script.Parent.Parent.Projectiles)
local StaminaServer = require(script.Parent.Parent.StaminaServer)
local StateMachine = require(script.Parent.Parent.StateMachine)
local Status = require(script.Parent.Parent.Status)

-- Tamaño (ancho y alto) de la zona de golpe del cuerpo a cuerpo, delante del jugador.
local MELEE_HITBOX = Vector2.new(7, 6)

local CombatService = {}

local lastAttackAt: { [Player]: number } = {}
-- Dónde va la cadena de golpes de cada jugador (Shared/MeleeChain).
local chains: { [Player]: MeleeChain.State } = {}
-- Y la cuenta de disparos seguidos de las armas a distancia (Shared/RangedChain).
local shots: { [Player]: RangedChain.State } = {}
local damageListeners: { (model: Model, attacker: Player?, amount: number) -> () } = {}
local healListeners: { (player: Player, healer: Player, amount: number) -> () } = {}

-- Llama a "callback" cada vez que un enemigo recibe daño (BossService cuenta quién participa).
function CombatService.onEnemyDamaged(callback: (model: Model, attacker: Player?, amount: number) -> ())
	table.insert(damageListeners, callback)
end

-- Llama a "callback" cada vez que alguien cura de verdad a otro jugador (MonkeyService reparte el
-- botín también con el médico de quien pelea). No cuenta curarse a uno mismo ni las mascotas.
function CombatService.onPlayerHealed(callback: (player: Player, healer: Player, amount: number) -> ())
	table.insert(healListeners, callback)
end
local lastDodgeAt: { [Player]: number } = {}

local function livingCharacter(player: Player): (Model?, BasePart?)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return nil, nil
	end
	return character, root
end

-- Si la pieza pertenece a un enemigo vivo, devuelve su modelo y su Humanoid.
function CombatService.enemyFromPart(part: Instance): (Model?, Humanoid?)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if CollectionService:HasTag(model, Config.Combat.EnemyTag) then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				return model, humanoid
			end
			return nil, nil
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil, nil
end

-- Destello rojo sobre el objetivo. Los números flotantes los dibuja cada cliente (Combat/CombatText).
local function flash(model: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.Parent = model
	Debris:AddItem(highlight, 0.15)
end

export type HitOptions = {
	crit: boolean?, -- golpe crítico: ×Config.Crit.Multiplier y número más grande
	pet: boolean?, -- lo hizo la mascota del atacante (su número sale más pequeño)
	poison: boolean?, -- un golpe del veneno (Combat/Status.poison): número morado, sin destello ni sonido
	source: string?, -- con qué (id de habilidad o de arma), para la telemetría
}

local NO_HIT_OPTIONS: HitOptions = {}

-- Fracción de daño extra mientras dura un estado de "model" que la guarda en "bonusAttribute".
local function bonusWhile(model: Model, untilAttribute: string, bonusAttribute: string): number
	local untilTime = model:GetAttribute(untilAttribute)
	local bonus = model:GetAttribute(bonusAttribute)
	if typeof(untilTime) == "number" and Workspace:GetServerTimeNow() < untilTime and typeof(bonus) == "number" then
		return bonus
	end
	return 0
end

-- Tira el crítico de una habilidad de "player": con la probabilidad de su arma (Shared/Crit).
function CombatService.rollPlayerCrit(player: Player): boolean
	local _, chance = Crit.playerWeapon(player)
	return Crit.roll(chance)
end

-- Daña a un enemigo. "attacker" queda apuntado para repartir el botín si lo derrota.
-- Los monos marcados por un cazador (Fase 3) reciben daño extra mientras dura la marca, y los
-- expuestos (Combat/Status.expose: dormidos por la "Nana de la selva" del médico), también.
function CombatService.damage(model: Model, humanoid: Humanoid, amount: number, attacker: Player?, options: HitOptions?)
	local hit = options or NO_HIT_OPTIONS
	if attacker then
		model:SetAttribute("LastAttackerUserId", attacker.UserId)
		if not hit.pet then
			amount = math.max(1, math.round(amount * Config.Combat.PlayerDamageMultiplier))
		end
	end
	-- Intimidado por el rugido de un mandril (Fase 4): hace menos daño.
	local intimidatedUntil = if attacker then attacker:GetAttribute("IntimidatedUntil") else nil
	if typeof(intimidatedUntil) == "number" and Workspace:GetServerTimeNow() < intimidatedUntil then
		amount = math.max(1, math.round(amount * Config.Combat.IntimidatedDamageMultiplier))
	end
	local markBonus = bonusWhile(model, "MarkedUntil", "MarkBonus")
	if markBonus ~= 0 then
		amount = math.round(amount * (1 + markBonus))
	end
	local exposedBonus = bonusWhile(model, "ExposedUntil", "ExposedBonus")
	if exposedBonus ~= 0 then
		amount = math.round(amount * (1 + exposedBonus))
	end
	if hit.crit then
		amount = math.round(amount * Crit.MULTIPLIER)
	end
	local alive = humanoid.Health > 0
	if attacker then
		local source = if hit.pet then "Mascota" else hit.source or "Otro"
		CombatRules.get().telemetry.damageDealt(attacker, source, math.min(amount, math.max(0, humanoid.Health)))
	end
	humanoid:TakeDamage(amount)
	local ko = alive and humanoid.Health <= 0
	if hit.poison then
		CombatText.poison(model, amount, attacker, ko)
	else
		flash(model)
		CombatText.dealt(model, amount, hit.crit, attacker, hit.pet, ko)
		Sfx.play("Hit", model.PrimaryPart or model)
	end
	if attacker and not hit.pet then
		ComboService.onActivity(attacker)
	end
	for _, listener in damageListeners do
		task.spawn(listener, model, attacker, amount)
	end
end

-- true mientras dura la invulnerabilidad de la esquiva.
function CombatService.isInvulnerable(player: Player): boolean
	local untilTime = player:GetAttribute("InvulnerableUntil")
	return typeof(untilTime) == "number" and Workspace:GetServerTimeNow() < untilTime
end

-- Reduce el daño que recibe un jugador: armadura (Data/Armor), "Grito de guerra" del guerrero y
-- "Escudo de hojas" del médico, que absorbe hasta romperse. Puede devolver 0 (todo absorbido).
local function mitigate(player: Player, amount: number): number
	local armorId = player:GetAttribute("Armor")
	local armor = if typeof(armorId) == "string" then Armor[armorId] else nil
	if armor then
		amount = math.max(1, math.round(amount * (1 - armor.damageReduction)))
	end
	-- Aura del tótem guardián de la Isla (Fase 9, G8; DefenseService).
	local ward = player:GetAttribute("WardReduction")
	if typeof(ward) == "number" and ward > 0 then
		amount = math.max(1, math.round(amount * (1 - math.clamp(ward, 0, 0.9))))
	end
	local now = Workspace:GetServerTimeNow()
	local guardUntil = player:GetAttribute("GuardUntil")
	local guard = player:GetAttribute("GuardReduction")
	if typeof(guardUntil) == "number" and now < guardUntil and typeof(guard) == "number" then
		amount = math.max(1, math.round(amount * (1 - math.clamp(guard, 0, 0.9))))
	end
	local shieldUntil = player:GetAttribute("ShieldUntil")
	local shield = player:GetAttribute("ShieldHealth")
	if typeof(shieldUntil) == "number" and now < shieldUntil and typeof(shield) == "number" and shield > 0 then
		local absorbed = math.min(shield, amount)
		amount -= absorbed
		-- Al llegar a 0, la burbuja estalla en los clientes (AbilityFxController).
		player:SetAttribute("ShieldHealth", shield - absorbed)
	end
	return amount
end

-- Daño de un enemigo (un mono) a un jugador. No hace nada si está en la zona segura (el Basecamp),
-- esquivando, o caído. La guardia (Combat/Guard), la armadura y las defensas de los roles lo reducen
-- (mitigate). Un golpe mortal lo deja fuera de combate según el place (CombatRules.knockOut: caído en
-- la Isla). Devuelve true si el golpe entró (también bloqueado) y el resultado de la guardia: con un
-- parry, false y "Parried".
-- "ignoreSafe": los monos del asedio (Fase 2.5) también hieren dentro del Basecamp.
-- "source": el mono o jefe que pega; según su categoría o fase puede hacer un crítico (Shared/Crit).
-- Sin él (rayos, lava, rocas…) nunca lo es. "cause": quién lo lanza si no hay "source", para la
-- telemetría de caídas (Combat/Hazards). "bite": es un mordisco de mono y sube la fiebre del mono.
-- "guard": el golpe se puede bloquear y parar (Guard.enemyHit: los golpes básicos de monos y jefes);
-- sin él, la guardia no cuenta (los especiales y los peligros, hasta C6).
function CombatService.damagePlayer(
	player: Player,
	amount: number,
	ignoreSafe: boolean?,
	source: Instance?,
	cause: string?,
	bite: boolean?,
	guard: Guard.Hit?
): (boolean, Guard.Outcome?)
	local rules = CombatRules.get()
	local safe = not ignoreSafe and rules.isSafe(player)
	if safe or CombatService.isInvulnerable(player) or not LifeState.isAlive(player) then
		return false, nil
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (character and humanoid and humanoid.Health > 0) then
		return false, nil
	end
	local outcome: Guard.Outcome = "Hit"
	if guard then
		local scale
		outcome, scale = Guard.resolve(player, guard)
		if outcome == "Parried" then
			return false, outcome
		end
		amount *= scale
	end
	local crit = Crit.roll(Crit.sourceChance(source))
	if crit then
		amount *= Crit.MULTIPLIER
	end
	amount = mitigate(player, math.max(1, math.round(amount)))
	flash(character)
	if amount <= 0 then
		CombatText.absorbed(player)
		return true, outcome
	end
	CombatText.taken(player, amount, crit)
	-- Los mordiscos suben la fiebre del mono (Fase 2.6) según lo que quitan de la vida máxima.
	if bite then
		rules.addFever(player, Config.Fever.PerHealthBar * amount / math.max(1, humanoid.MaxHealth))
	end
	if humanoid.Health - amount <= 0 then
		Sfx.play("PlayerDown", character.PrimaryPart or character)
		rules.knockOut(player, nil, cause or rules.telemetry.causeOf(source))
	else
		Sfx.play("PlayerHurt", character.PrimaryPart or character)
		humanoid:TakeDamage(amount)
	end
	return true, outcome
end

export type HealOptions = {
	pet: boolean?, -- la curación es de la mascota de "healer" (Config.Crit.PetChance)
	canCrit: boolean?, -- puede ser crítica (las vendas y la reanimación no)
	crit: boolean?, -- crítica segura (el remate del combo del médico)
	source: string?, -- con qué (id de habilidad o de arma), para la telemetría
}

local NO_HEAL_OPTIONS: HealOptions = {}

-- Cura a un jugador vivo y enseña el número verde. "healer": quién cura (el médico, o el propio
-- jugador con su mascota). Las críticas curan ×Config.Crit.Multiplier; las del médico lo son más a
-- menudo si el aliado tiene poca vida (Shared/Crit). Devuelve lo que ha curado de verdad.
function CombatService.heal(player: Player, amount: number, healer: Player?, options: HealOptions?): number
	local heal = options or NO_HEAL_OPTIONS
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (humanoid and humanoid.Health > 0 and LifeState.isAlive(player)) then
		return 0
	end
	local crit = heal.crit == true
	if not crit and heal.canCrit then
		local chance = 0
		if heal.pet then
			chance = Config.Crit.PetChance
		elseif healer then
			local _, weaponChance = Crit.playerWeapon(healer)
			chance = Crit.healChance(weaponChance, humanoid.Health / humanoid.MaxHealth)
		end
		crit = Crit.roll(chance)
	end
	if crit then
		amount *= Crit.MULTIPLIER
	end
	-- Las curaciones de un jugador (no las de la mascota) llevan el ajuste del place (en la arena, menos).
	if healer and not heal.pet then
		amount *= CombatRules.get().healMultiplier
	end
	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, before + amount)
	local healed = humanoid.Health - before
	if healed >= 0.5 then
		CombatText.heal(player, healed, crit, healer, heal.pet)
	end
	if healer and not heal.pet then
		ComboService.onActivity(healer)
	end
	-- Solo las de combate (habilidades, cerbatanas y mascotas), no vendas ni reanimaciones.
	local source = if heal.pet then "Mascota" else heal.source
	if healer and source then
		CombatRules.get().telemetry.healed(healer, source, healed)
	end
	if healer and healer ~= player and not heal.pet and healed > 0 then
		for _, listener in healListeners do
			task.spawn(listener, player, healer, healed)
		end
	end
	return healed
end

-- true si "attacker" puede herir a "victim" en PvP ahora mismo. Quién es rival lo deciden las reglas
-- del place (CombatRules.canHitPlayer).
function CombatService.canHitPlayer(attacker: Player, victim: Player): boolean
	return attacker ~= victim
		and LifeState.isAlive(victim)
		and not CombatService.isInvulnerable(victim)
		and CombatRules.get().canHitPlayer(attacker, victim)
end

function CombatService.playerFromPart(part: Instance): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local owner = Players:GetPlayerFromCharacter(model)
		if owner then
			return owner
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Cómo se puede defender un golpe de un jugador a otro (CombatService.damagePvP).
export type PvPGuard = {
	guardDamage: number, -- guardia que gasta si se bloquea (Config.Guard)
	unblockable: boolean?, -- rompe la guardia y entra entero
	-- Un golpe de arma: espera el margen del defensor para el parry (Guard.grace) antes de resolverse.
	waitForParry: boolean?,
	-- Se llama al resolverse con el resultado ("Hit", "Blocked", "Parried" o "Broken"): lo que el golpe
	-- hace además del daño (tambaleo, empuje, veneno) va aquí, porque puede resolverse más tarde.
	onResult: ((outcome: Guard.Outcome) -> ())?,
	-- Los golpes con la misma clave (los de un uso de una habilidad) cuentan como uno en el escalado del
	-- combo (Combat/ComboScaling) y gastan la guardia una sola vez (C8: el Torbellino bloqueado entero
	-- gasta lo que un golpe); sin ella, cada golpe cuenta.
	hitKey: string?,
}

-- Claves de golpe (PvPGuard.hitKey) que ya han gastado la guardia de cada víctima, con su hora (os.clock).
local guardSpent: { [Player]: { [string]: number } } = {}
-- Una clave se olvida pasado esto (s): ningún uso de una habilidad dura tanto.
local GUARD_KEY_SECONDS = 15

-- true si "key" ya gastó la guardia de "victim".
local function guardAlreadySpent(victim: Player, key: string): boolean
	local spent = guardSpent[victim]
	local at = if spent then spent[key] else nil
	return at ~= nil and os.clock() - at < GUARD_KEY_SECONDS
end

local function markGuardSpent(victim: Player, key: string)
	local spent = guardSpent[victim]
	if not spent then
		spent = {}
		guardSpent[victim] = spent
	end
	local clock = os.clock()
	for other, at in spent do
		if clock - at >= GUARD_KEY_SECONDS then
			spent[other] = nil
		end
	end
	spent[key] = clock
end

local function applyPvP(attacker: Player, victim: Player, amount: number, crit: boolean?, poison: boolean?)
	local character = victim.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (character and humanoid and humanoid.Health > 0) then
		return
	end
	if CombatRules.get().pvpStatus then
		local bonus = bonusWhile(character, "MarkedUntil", "MarkBonus")
			+ bonusWhile(character, "ExposedUntil", "ExposedBonus")
		if bonus ~= 0 then
			amount *= 1 + bonus
		end
	end
	if crit then
		amount *= Crit.MULTIPLIER
	end
	amount = mitigate(victim, math.max(1, math.round(amount)))
	if not poison then
		flash(character)
	end
	ComboService.onActivity(attacker)
	if amount <= 0 then
		CombatText.absorbed(victim, attacker)
		return
	end
	if poison then
		CombatText.poison(character, amount, attacker, humanoid.Health - amount <= 0)
	else
		CombatText.taken(victim, amount, crit, attacker)
	end
	if humanoid.Health - amount > 0 then
		humanoid:TakeDamage(amount)
		return
	end
	CombatRules.get().knockOut(victim, attacker, "PvP")
end

-- Daño de un jugador a otro. Si le quita toda la vida, el place decide qué pasa
-- (CombatRules.knockOut: en la Isla queda caído y se cobra su recompensa PvP).
-- "crit": golpe crítico (lo tira quien llama, con el arma del atacante). "poison": es un golpe del
-- veneno (número morado, sin destello; no se defiende). Con CombatRules.pvpStatus, los marcados por un
-- cazador y los expuestos (dormidos por la "Nana de la selva") reciben su daño extra, como los monos.
-- "guard": el golpe se puede bloquear y parar (Combat/Guard); un golpe de arma espera antes el margen
-- del defensor para el parry. Devuelve true si "victim" se podía herir (el golpe puede resolverse
-- después: lo que dependa de que entre va en "guard.onResult").
-- Los golpes con "guard" que entran llevan el escalado del combo (C7, Combat/ComboScaling): desde el
-- 4.º seguido hacen menos; bloquear o parar uno termina el combo.
function CombatService.damagePvP(
	attacker: Player,
	victim: Player,
	amount: number,
	crit: boolean?,
	poison: boolean?,
	guard: PvPGuard?
): boolean
	if not CombatService.canHitPlayer(attacker, victim) then
		return false
	end
	if poison or not guard then
		applyPvP(attacker, victim, amount, crit, poison)
		return true
	end
	local at = Workspace:GetServerTimeNow()
	local function resolve()
		-- Mientras esperaba ha podido esquivar o caer.
		if not CombatService.canHitPlayer(attacker, victim) then
			return
		end
		local attackerRoot = if attacker.Character then attacker.Character:FindFirstChild("HumanoidRootPart") else nil
		local key = guard.hitKey
		local outcome, scale = Guard.resolve(victim, {
			guardDamage = if key and guardAlreadySpent(victim, key) then 0 else guard.guardDamage,
			unblockable = guard.unblockable,
			from = if attackerRoot and attackerRoot:IsA("BasePart") then attackerRoot.Position else nil,
			attacker = attacker.Character,
		}, at)
		if key and outcome == "Blocked" then
			markGuardSpent(victim, key)
		end
		if outcome == "Blocked" or outcome == "Parried" then
			ComboScaling.reset(victim)
		else
			scale *= ComboScaling.damageFactor(ComboScaling.register(victim, guard.hitKey))
		end
		if outcome ~= "Parried" then
			applyPvP(attacker, victim, amount * scale, crit, false)
		end
		if guard.onResult then
			guard.onResult(outcome)
		end
	end
	local wait = if guard.waitForParry then Guard.grace(victim) else 0
	if wait > 0 then
		task.delay(wait, resolve)
	else
		resolve()
	end
	return true
end

-- Fracción del daño de "weaponId" contra jugadores (CombatRules: el general y el de esa arma).
local function pvpWeaponScale(weaponId: string): number
	local rules = CombatRules.get()
	return rules.pvpWeaponMultiplier * (rules.pvpWeaponMultipliers[weaponId] or 1)
end

-- true si el remate de la cadena tambalea a este enemigo: monos de categoría hasta
-- Config.Chain.FinisherStaggerTier y los muñecos; no los alfas ni los jefes.
local function staggersOnFinisher(model: Model): boolean
	if Status.isBoss(model) or model:GetAttribute("Alpha") == true then
		return false
	end
	local speciesId = model:GetAttribute("MonkeyType")
	local species = if typeof(speciesId) == "string" then Monkeys[speciesId] else nil
	return (if species then species.tier else 1) <= Config.Chain.FinisherStaggerTier
end

-- El remate de la cadena (Shared/MeleeChain): empuja hacia donde mira el atacante o, si va en el aire
-- (sin suelo a Config.Chain.AirborneGroundDistance), lo lanza hacia arriba. Los jefes no se mueven
-- (Combat/Knockback).
local function finisherPush(root: BasePart, model: Model)
	local settings = Config.Chain
	local airborne = Hitbox.ray(root.Position, Vector3.new(0, -settings.AirborneGroundDistance, 0)) == nil
	Knockback.push(
		model,
		root.CFrame.LookVector,
		settings.FinisherKnockback,
		settings.FinisherKnockbackSeconds,
		if airborne then settings.FinisherLaunch else nil
	)
end

-- Un golpe con arma cuerpo a cuerpo: el paso "step" de la cadena (Shared/MeleeChain; su multiplicador
-- de daño, el tambaleo en PvP y el remate) o, sin "step", el golpe suelto de las herramientas.
local function meleeAttack(
	player: Player,
	character: Model,
	root: BasePart,
	weaponId: string,
	weapon: Weapons.WeaponDefinition,
	critChance: number,
	step: number?
)
	local box = root.CFrame * CFrame.new(0, 0, -weapon.range / 2)
	local size = Vector3.new(MELEE_HITBOX.X, MELEE_HITBOX.Y, weapon.range)

	-- "+daño cuerpo a cuerpo" del guerrero.
	local damage = weapon.damage * Progression.perk(player, "MeleeDamage")
	if step then
		damage *= MeleeChain.damageMultiplier(step)
	end
	damage = math.round(damage)
	local finisher = step ~= nil and MeleeChain.isFinisher(step)
	-- Cada uno una vez, solo si no hay pared entre el jugador y él, y también donde lo veía el
	-- atacante con su retraso de red (Combat/Latency, con tope).
	local hits = Hitbox.inBox(box, size, {
		exclude = character,
		from = root.Position,
		rewind = Latency.compensation(player),
	})
	-- Guardia que gasta cada golpe (Config.Guard): la de un arma de ChainReferenceCooldown s, escalada
	-- con la suya (todas rompen la guardia en el mismo tiempo); el remate, más.
	local guardSettings = Config.Guard
	local guardDamage = (if finisher then guardSettings.FinisherGuardDamage else guardSettings.ChainGuardDamage)
		* weapon.cooldownSeconds
		/ guardSettings.ChainReferenceCooldown
	if finisher and #hits > 0 then
		CombatRules.get().telemetry.mechanic(player, "ChainFinishers")
	end
	for _, model in hits do
		local victim = Players:GetPlayerFromCharacter(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if victim then
			CombatService.damagePvP(player, victim, damage * pvpWeaponScale(weaponId), Crit.roll(critChance), false, {
				guardDamage = guardDamage,
				waitForParry = true,
				onResult = function(outcome)
					-- Solo si entra: bloqueado no tambalea ni empuja.
					if not (step and (outcome == "Hit" or outcome == "Broken") and LifeState.isAlive(victim)) then
						return
					end
					if finisher then
						finisherPush(root, model)
					elseif outcome == "Hit" then
						-- Tambaleo corto: no pega ni usa habilidades, pero puede esquivar antes del siguiente.
						-- Más corto cuanto más largo el combo que lleva encima (Combat/ComboScaling).
						local hitstun = MeleeChain.hitstunSeconds(weapon, step)
							* ComboScaling.hitstunFactor(ComboScaling.current(victim))
						if hitstun > 0 then
							StateMachine.enter(victim, "Staggered", hitstun)
						end
					end
				end,
			})
		elseif humanoid and humanoid.Health > 0 then
			CombatService.damage(model, humanoid, damage, player, { crit = Crit.roll(critChance), source = weaponId })
			if finisher and humanoid.Health > 0 then
				if staggersOnFinisher(model) then
					Status.stun(model, Config.Chain.FinisherStaggerSeconds)
				end
				finisherPush(root, model)
			end
		end
	end
end

-- Un paso de la cadena: el golpe cae al acabar la preparación (Shared/MeleeChain.windupSeconds, menos
-- el retraso de red del atacante, que ya la empezó en su pantalla). Si en ese tiempo le tambalean, le
-- aturden, cae o cambia de arma, el golpe no sale. Pulsar la guardia en ese tiempo es un amago (C8,
-- Combat/Feint): el golpe no sale y la cadena vuelve al primero.
local function chainAttack(player: Player, tool: Tool, weaponId: string, weapon: Weapons.WeaponDefinition, step: number)
	local stepSeconds = MeleeChain.stepSeconds(weapon, step)
	StateMachine.enter(player, "Attacking", stepSeconds)
	player:SetAttribute("ChainStep", step)
	local delay = math.max(0, MeleeChain.windupSeconds(weapon, step) - Latency.compensation(player))
	local feinted = false
	local mark = Feint.begin(player, "Attack", delay, function()
		feinted = true
		chains[player] = nil
		StateMachine.leave(player, "Attacking")
	end)
	task.delay(delay, function()
		Feint.finish(player, mark)
		local character, root = livingCharacter(player)
		if
			feinted
			or not (character and root)
			or tool.Parent ~= character
			or not LifeState.isAlive(player)
			or not CombatState.canAct(player, "Attack")
		then
			return
		end
		meleeAttack(player, character, root, weaponId, weapon, Crit.weaponChance(weaponId), step)
	end)
end

-- Cuánto se desvía "point" de la puntería "aim" desde "origin" (en radianes), o nil si queda fuera
-- del cono de "degrees". La cámara mira por encima del hombro: de cerca, un mono pequeño queda muy por
-- debajo de la línea de tiro aunque el jugador lo tenga delante. Por eso, a corta distancia
-- (Config.Combat.CloseAimRange y CloseAimHeight) solo cuenta la dirección en horizontal, con un cono
-- de al menos CloseAimDegrees.
function CombatService.aimDeviation(origin: Vector3, aim: Vector3, point: Vector3, degrees: number): number?
	local settings = Config.Combat
	local offset = point - origin
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	local flatAim = Vector3.new(aim.X, 0, aim.Z)
	local close = flatOffset.Magnitude <= settings.CloseAimRange and math.abs(offset.Y) <= settings.CloseAimHeight
	local angle: number
	local limit = math.rad(degrees)
	if close and flatAim.Magnitude > 0.1 then
		angle = if flatOffset.Magnitude > 0.1
			then math.acos(math.clamp(flatOffset.Unit:Dot(flatAim.Unit), -1, 1))
			else 0
		limit = math.max(limit, math.rad(settings.CloseAimDegrees))
	elseif offset.Magnitude > 0.01 then
		angle = math.acos(math.clamp(offset.Unit:Dot(aim.Unit), -1, 1))
	else
		angle = 0
	end
	return if angle <= limit then angle else nil
end

-- Adónde apuntar a un mono para que le dé un proyectil de "speed" que sale de "origin": adonde estará
-- al llegar, si sigue como va (en horizontal: los saltos no se adivinan), como mucho
-- Config.Projectiles.LeadMaxSeconds por delante.
local function leadPoint(origin: Vector3, root: BasePart, speed: number): Vector3
	local velocity = root.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local point = root.Position
	for _ = 1, 2 do
		local seconds = math.min((point - origin).Magnitude / speed, Config.Projectiles.LeadMaxSeconds)
		point = root.Position + flatVelocity * seconds
	end
	return point
end

-- Cuánto se aparta "point" de la línea de tiro que sale de "origin" hacia "aim" (studs), y a qué
-- distancia está a lo largo de ella; nil si queda detrás. Con "flatClose", de cerca (Config.Combat.
-- CloseAimRange y CloseAimHeight) solo cuenta en horizontal: la cámara mira por encima del hombro y un
-- mono pequeño pegado al jugador queda muy por debajo de la línea.
local function offAimLine(origin: Vector3, aim: Vector3, point: Vector3, flatClose: boolean): (number?, number)
	local offset = point - origin
	local along = offset:Dot(aim)
	if along <= 0 then
		return nil, along
	end
	local settings = Config.Combat
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	local flatAim = Vector3.new(aim.X, 0, aim.Z)
	if
		flatClose
		and flatOffset.Magnitude <= settings.CloseAimRange
		and math.abs(offset.Y) <= settings.CloseAimHeight
		and flatAim.Magnitude > 0.1
	then
		local direction = flatAim.Unit
		local flatAlong = flatOffset:Dot(direction)
		if flatAlong <= 0 then
			return nil, along
		end
		return (flatOffset - direction * flatAlong).Magnitude, along
	end
	return (offset - aim * along).Magnitude, along
end

-- Ayuda de puntería de un disparo (C9): la dirección con la que sale desde "origin". Solo engancha a
-- quien la línea de tiro ya casi toca (Config.Projectiles): apuntando entre dos, el disparo pasa entre
-- ellos. Entre los que se ven a menos de "range", el más cercano a la línea:
--   - un mono vivo a menos de MonkeyAimStuds de ella (de lejos, dentro de MonkeyAimMinDegrees),
--     apuntando adonde estará al llegar el proyectil (leadPoint);
--   - un jugador rival (o, con "allies", un aliado vivo) a menos de PlayerAimStuds (PlayerAimMinDegrees),
--     apuntando adonde está: se puede apartar.
-- El proyectil va recto desde ahí: no persigue a nadie. Sin nadie, sale hacia "aim".
function CombatService.aimShot(
	player: Player,
	origin: Vector3,
	aim: Vector3,
	range: number,
	speed: number,
	allies: boolean?
): Vector3
	local settings = Config.Projectiles
	local best: Vector3? = nil
	local bestOff = math.huge
	for _, model in Hitbox.inSphere(origin, range, { exclude = player.Character }) do
		local root = Hitbox.rootOf(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local victim = Players:GetPlayerFromCharacter(model)
			local valid, studs, degrees, point
			if victim then
				valid = CombatService.canHitPlayer(player, victim)
					or (allies == true and LifeState.isAlive(victim) and CombatRules.get().isAlly(player, victim))
				studs, degrees, point = settings.PlayerAimStuds, settings.PlayerAimMinDegrees, root.Position
			else
				valid = CollectionService:HasTag(model, Config.Combat.EnemyTag)
				studs, degrees, point = settings.MonkeyAimStuds, settings.MonkeyAimMinDegrees, nil
			end
			if valid then
				local off, along = offAimLine(origin, aim, root.Position, victim == nil)
				if off and off <= math.max(studs, along * math.tan(math.rad(degrees))) and off < bestOff then
					bestOff = off
					best = point or leadPoint(origin, root, speed)
				end
			end
		end
	end
	local offset = if best then best - origin else Vector3.zero
	return if offset.Magnitude > 0.01 then offset.Unit else aim
end

-- Cerbatanas del médico: el acierto cura al aliado vivo más herido cerca (o al propio médico). Solo a
-- los aliados según las reglas del place (en la arena, los de su equipo). "allyMultiplier": el remate
-- (C9b) cura más a un aliado, no al propio médico (en un duelo no se sostiene más).
local function healWoundedAlly(healer: Player, amount: number, weaponId: string, allyMultiplier: number?)
	local _, healerRoot = livingCharacter(healer)
	if not healerRoot then
		return
	end
	local best: Player? = nil
	local bestFraction = 1
	for _, ally in Players:GetPlayers() do
		local character, root = livingCharacter(ally)
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if
			humanoid
			and root
			and LifeState.isAlive(ally)
			and (ally == healer or CombatRules.get().isAlly(healer, ally))
			and (root.Position - healerRoot.Position).Magnitude <= Config.Combat.WeaponHealRadius
		then
			local fraction = humanoid.Health / humanoid.MaxHealth
			if fraction < bestFraction then
				best = ally
				bestFraction = fraction
			end
		end
	end
	if best then
		local multiplier = if best ~= healer then allyMultiplier or 1 else 1
		CombatService.heal(best, amount * multiplier, healer, { source = weaponId })
	end
end

-- Un disparo de un arma a distancia (C9): un proyectil real (Combat/Projectiles) que sale hacia donde
-- dice la ayuda de puntería (aimShot) y da al primero que encuentra: si se aparta, falla. Atraviesa a
-- los aliados. Contra un jugador se puede bloquear y parar (con el margen del defensor, como el golpe);
-- el veneno de las cerbatanas entra al impactar.
-- "shot": el número del disparo seguido (Shared/RangedChain). El último es el remate (C9b): otro
-- proyectil, más fuerte, y lo suyo según el arma (Config.RangedChain.Finishers): el del arco atraviesa
-- al primero y da también al siguiente; el del bastón estalla donde se para; el de la cerbatana cura
-- el doble a un aliado; el de la honda tambalea a un mono pequeño (no a jugadores).
local function rangedAttack(
	player: Player,
	character: Model,
	root: BasePart,
	weaponId: string,
	weapon: Weapons.WeaponDefinition,
	aim: Vector3,
	critChance: number,
	shot: number
)
	local ammo = weapon.ammoItemId
	local rules = CombatRules.get()
	if ammo and not rules.useAmmo(player, ammo) then
		Remotes.Notify:FireClient(player, `Necesitas {Items[ammo].name} para usar: {weapon.name}`)
		return
	end
	local finisher = if RangedChain.isFinisher(weapon, shot) then RangedChain.settings(weapon) else nil
	-- "+daño a distancia" del cazador o "+daño de hechizos" del mago, con sus talentos (también el veneno).
	local scale = Progression.perk(player, if weapon.spell then "SpellDamage" else "RangedDamage")
	local damage = math.round(weapon.damage * scale * RangedChain.damageMultiplier(weapon, shot))
	-- Dardos venenosos del médico: munición opcional; mientras queden, cada disparo gasta uno.
	local poison = weapon.poison
	local poisonDps = if poison then poison.dps * scale else 0
	local boost = if poison then poison.boostItemId else nil
	if boost and rules.useBoost(player, boost) then
		poisonDps *= Items[boost].poisonMultiplier or 1
	end
	local crit = Crit.roll(critChance)
	local style = weapon.projectile or "Stone"
	-- La animación del disparo se ve sola (es del personaje); la bocanada o el destello, a los demás
	-- (el que dispara ya los ha lanzado en su cliente).
	AbilityFx.others(player, "WeaponShotFx", character, style, finisher ~= nil)
	if finisher then
		rules.telemetry.mechanic(player, "ShotFinishers")
	end

	-- El daño de este disparo a "model" (true si le vale; si no, el proyectil lo atraviesa). "main": el
	-- primero al que da, el único al que envenena, por el que cura y al que tambalea.
	local function strike(model: Model, amount: number, main: boolean): boolean
		local victim = Players:GetPlayerFromCharacter(model)
		if victim then
			if not CombatService.canHitPlayer(player, victim) then
				return false
			end
			local pvpScale = pvpWeaponScale(weaponId)
			CombatService.damagePvP(player, victim, amount * pvpScale, crit, false, {
				guardDamage = Config.Guard.ProjectileGuardDamage,
				waitForParry = true,
				onResult = function(outcome)
					-- Con pvpStatus, los dardos de las cerbatanas también envenenan a los rivales (si entran).
					local victimCharacter = victim.Character
					if main and outcome == "Hit" and poison and rules.pvpStatus and victimCharacter then
						Status.poison(victimCharacter, poisonDps * pvpScale, poison.seconds, player, weaponId)
					end
				end,
			})
			return true
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not (CollectionService:HasTag(model, Config.Combat.EnemyTag) and humanoid and humanoid.Health > 0) then
			return false
		end
		CombatService.damage(model, humanoid, amount, player, { crit = crit, source = weaponId })
		if not main then
			return true
		end
		if poison and humanoid.Health > 0 then
			Status.poison(model, poisonDps, poison.seconds, player, weaponId)
		end
		if weapon.healOnHit then
			healWoundedAlly(player, weapon.healOnHit, weaponId, if finisher then finisher.healMultiplier else nil)
		end
		if finisher and finisher.staggerSeconds and humanoid.Health > 0 and staggersOnFinisher(model) then
			Status.stun(model, finisher.staggerSeconds)
		end
		return true
	end

	local head = character:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.new(0, 1.5, 0)
	local speed = weapon.projectileSpeed or 120
	local direction = CombatService.aimShot(player, origin, aim, weapon.range, speed)
	local others = if finisher then math.round(damage * (finisher.othersDamage or 0)) else 0
	local direct: Model? = nil
	Projectiles.fire({
		owner = player,
		look = if finisher then `{style}Finisher` else style,
		origin = origin,
		direction = direction,
		speed = speed,
		range = weapon.range,
		radius = Config.Projectiles.WeaponRadius,
		pierce = finisher ~= nil and finisher.pierceTargets ~= nil,
		maxHits = if finisher then finisher.pierceTargets else nil,
		extra = if finisher and finisher.radius then { finisher.radius } else nil,
		onHit = function(model)
			if direct == nil then
				if strike(model, damage, true) then
					direct = model
					return true
				end
				return false
			end
			-- Los siguientes, solo el remate que atraviesa.
			return others > 0 and strike(model, others, false)
		end,
		-- El remate del bastón estalla donde se para (en el primero, en una pared o al final de su
		-- alcance), mirando desde un poco antes: lo que hay detrás de una pared no se alcanza.
		onEnd = if finisher and finisher.radius
			then function(position)
				local radius = finisher.radius :: number
				for _, model in Hitbox.inSphere(position, radius, { exclude = character, from = position - direction }) do
					if model ~= direct then
						strike(model, others, false)
					end
				end
			end
			else nil,
	})
end

local function onUseWeapon(player: Player, aim: any)
	if not LifeState.isAlive(player) or not CombatState.canAct(player, "Attack") then
		return
	end
	local character, root = livingCharacter(player)
	if not (character and root) then
		return
	end
	local tool = character:FindFirstChildOfClass("Tool")
	local weaponId = if tool then tool:GetAttribute("WeaponId") else nil
	local weapon = if typeof(weaponId) == "string" then Weapons[weaponId] else nil
	if not (tool and weapon) then
		return
	end

	local now = os.clock()
	-- Margen del retraso de red del atacante (como la esquiva) y el de Config.Net.JitterSeconds: el
	-- cliente lleva el ritmo con su reloj.
	local slack = Config.Net.JitterSeconds + 2 * Latency.compensation(player)
	if MeleeChain.uses(weapon) then
		-- Cadena de golpes: el ritmo lo lleva la cadena, con el margen del retraso de red del atacante
		-- (como la esquiva) y el de Config.Net.JitterSeconds; no se acumula de un golpe a otro.
		local chain = chains[player] or MeleeChain.newState()
		chains[player] = chain
		local step = MeleeChain.advance(chain, weaponId :: string, weapon, now, slack)
		if step then
			WeaponTools.playUse(tool)
			chainAttack(player, tool, weaponId :: string, weapon, step)
		end
		return
	end
	if weapon.kind == "Ranged" then
		-- Disparos seguidos: el ritmo y el remate los lleva Shared/RangedChain.
		if not (typeof(aim) == "Vector3" and aim.Magnitude > 0.5) then
			return
		end
		local count = shots[player] or RangedChain.newState()
		shots[player] = count
		local shot = RangedChain.advance(count, weaponId :: string, weapon, now, slack)
		if shot then
			WeaponTools.playUse(tool)
			rangedAttack(
				player,
				character,
				root,
				weaponId :: string,
				weapon,
				aim.Unit,
				Crit.weaponChance(weaponId :: string),
				shot
			)
		end
		return
	end
	local last = lastAttackAt[player]
	if last and now - last < weapon.cooldownSeconds then
		return
	end
	lastAttackAt[player] = now

	WeaponTools.playUse(tool)
	meleeAttack(player, character, root, weaponId :: string, weapon, Crit.weaponChance(weaponId :: string))
	-- El hacha y el pico, además de golpear enemigos, trabajan el árbol o la roca de delante.
	if weapon.tool then
		CombatRules.get().strikeResource(player, root, weapon.tool)
	end
end

-- La esquiva: el cliente ya ha movido al personaje; aquí se comprueba que podía (estado, tiempo de
-- espera con el margen de su ping y estamina del servidor) y se le da la invulnerabilidad. Atrapado
-- (aturdido, inmovilizado o lanzado) no hay esquiva: su esquiva es el Evasivo (Combat/Evasive).
local function onDodge(player: Player)
	local now = os.clock()
	local last = lastDodgeAt[player]
	-- Margen sobre el tiempo de espera del cliente por el retraso de la red (Combat/Latency, con tope).
	local slack = 2 * Latency.compensation(player)
	if last and now - last < Config.Combat.DodgeCooldownSeconds - slack then
		return
	end
	if not LifeState.isAlive(player) or not CombatState.canAct(player, "Dodge") or CombatState.isTrapped(player) then
		return
	end
	-- El cliente predice su estamina y puede ir un poco por delante (Config.Survival.StaminaSyncTolerance).
	if not StaminaServer.tryConsume(player, Config.Survival.DodgeStaminaCost, Config.Survival.StaminaSyncTolerance) then
		return
	end
	lastDodgeAt[player] = now
	player:SetAttribute("InvulnerableUntil", Workspace:GetServerTimeNow() + Config.Combat.DodgeInvulnerableSeconds)
	-- Esquivar suelta la guardia (Combat/Guard).
	Guard.drop(player)
end

-- Las armas iniciales van a StarterGear: Roblox las copia a la mochila en cada reaparición.
-- Primero las del rol (atributo "RoleWeapon") y detrás las comunes del place (el hacha y el pico en la
-- Isla), así las teclas 3 y 4 son siempre las mismas. Si cambia el rol a mitad de partida (panel de pruebas), solo cambian las del rol.
local function giveWeapons(player: Player, weaponIds: { string }, roleWeapon: boolean)
	local starterGear = player:WaitForChild("StarterGear")
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, weaponId in weaponIds do
		-- Con el aspecto equipado (CosmeticsServer) del rol o del machete, si le vale, y las de rol con el
		-- modelo del nivel que lucen en el Lobby y en Dunas ("WeaponLook").
		local tool = if roleWeapon
			then WeaponTools.build(weaponId, WeaponTools.skinOf(player, weaponId), WeaponTools.lookOf(player))
			else WeaponTools.build(weaponId)
		if roleWeapon then
			tool:SetAttribute("RoleWeapon", true)
		end
		tool.Parent = starterGear
		-- Si el personaje ya apareció, esta vida también la recibe.
		if player.Character and backpack then
			tool:Clone().Parent = backpack
		end
	end
end

local function roleWeapons(player: Player): { string }
	return Roles[Progression.validRole(player:GetAttribute("Role"))].weapons
end

local function giveStarterWeapons(player: Player)
	-- El rol lo publica RoleService al cargar los datos guardados.
	local deadline = os.clock() + 15
	while player.Parent and player:GetAttribute("Role") == nil and os.clock() < deadline do
		task.wait(0.1)
	end
	if not player.Parent then
		return
	end
	giveWeapons(player, roleWeapons(player), true)
	giveWeapons(player, CombatRules.get().starterTools(player), false)
	player:GetAttributeChangedSignal("Role"):Connect(function()
		local containers: { Instance? } =
			{ player:FindFirstChild("StarterGear"), player:FindFirstChildOfClass("Backpack"), player.Character }
		for _, container in containers do
			for _, child in if container then container:GetChildren() else {} do
				if child:IsA("Tool") and child:GetAttribute("RoleWeapon") == true then
					child:Destroy()
				end
			end
		end
		giveWeapons(player, roleWeapons(player), true)
	end)
end

function CombatService:Start()
	StateMachine.start()
	StaminaServer.start()
	Hitbox.start()
	Guard.start()
	Evasive.start()
	Feint.start()
	Projectiles.start()
	-- Cada golpe del veneno es daño de quien lo puso, sin crítico (a un jugador, por damagePvP).
	Status.setPoisonDamage(function(model, humanoid, amount, attacker, source)
		local victim = Players:GetPlayerFromCharacter(model)
		if victim then
			if attacker then
				CombatService.damagePvP(attacker, victim, amount, false, true)
			end
		else
			CombatService.damage(model, humanoid, amount, attacker, { poison = true, source = source })
		end
	end)
	Remotes.UseWeapon.OnServerEvent:Connect(onUseWeapon)
	Remotes.Dodge.OnServerEvent:Connect(onDodge)

	-- Si le tambalean (un parry, un golpe en PvP), le aturden o se pone en guardia, la cadena vuelve al
	-- primer golpe y la cuenta de disparos al primero, sin adelantar el siguiente (WeaponController hace
	-- lo mismo con su predicción).
	local function watchState(player: Player)
		player:GetAttributeChangedSignal(CombatState.ATTRIBUTE):Connect(function()
			local state = CombatState.get(player)
			if state ~= "Idle" and state ~= "Attacking" then
				chains[player] = nil
				local count = shots[player]
				if count then
					count.shot = 0
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		watchState(player)
		giveStarterWeapons(player)
	end)
	for _, player in Players:GetPlayers() do
		watchState(player)
		task.spawn(giveStarterWeapons, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAttackAt[player] = nil
		chains[player] = nil
		shots[player] = nil
		guardSpent[player] = nil
		lastDodgeAt[player] = nil
	end)
end

return CombatService
