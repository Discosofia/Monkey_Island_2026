--!strict
-- Combate (GDD §6, Fase 1.3): armas cuerpo a cuerpo, a distancia (honda y arco, que gastan munición;
-- bastón mágico y cerbatanas, que no; los dardos de las cerbatanas envenenan) y esquiva.
-- El servidor decide todo: qué arma lleva el jugador, si el ataque está listo, a quién golpea y el daño.
-- Se daña a lo que tenga la etiqueta Config.Combat.EnemyTag (monos, muñecos de práctica) y a otros
-- jugadores cuando las reglas del place lo permiten (CombatRules: el PvP opt-in de la Isla, los
-- equipos de la arena). Cada jugador aparece con las armas de su rol (Data/Roles) y las herramientas
-- comunes del place.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Armor = require(ReplicatedStorage.Shared.Data.Armor)
local Config = require(ReplicatedStorage.Shared.Config)
local Crit = require(ReplicatedStorage.Shared.Crit)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local ComboService = require(script.Parent.ComboService)
local AbilityFx = require(script.Parent.Parent.AbilityFx)
local CombatRules = require(script.Parent.Parent.CombatRules)
local CombatText = require(script.Parent.Parent.CombatText)
local Status = require(script.Parent.Parent.Status)

-- Tamaño (ancho y alto) de la zona de golpe del cuerpo a cuerpo, delante del jugador.
local MELEE_HITBOX = Vector2.new(7, 6)

local CombatService = {}

local lastAttackAt: { [Player]: number } = {}
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
local enemyFromPart = CombatService.enemyFromPart

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
-- esquivando, o caído. La armadura y las defensas de los roles lo reducen (mitigate). Un golpe mortal
-- lo deja fuera de combate según el place (CombatRules.knockOut: caído en la Isla). Devuelve true si
-- el golpe entró.
-- "ignoreSafe": los monos del asedio (Fase 2.5) también hieren dentro del Basecamp.
-- "source": el mono o jefe que pega; según su categoría o fase puede hacer un crítico (Shared/Crit).
-- Sin él (rayos, lava, rocas…) nunca lo es. "cause": quién lo lanza si no hay "source", para la
-- telemetría de caídas (Combat/Hazards). "bite": es un mordisco de mono y sube la fiebre del mono.
function CombatService.damagePlayer(
	player: Player,
	amount: number,
	ignoreSafe: boolean?,
	source: Instance?,
	cause: string?,
	bite: boolean?
): boolean
	local rules = CombatRules.get()
	local safe = not ignoreSafe and rules.isSafe(player)
	if safe or CombatService.isInvulnerable(player) or not LifeState.isAlive(player) then
		return false
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (character and humanoid and humanoid.Health > 0) then
		return false
	end
	local crit = Crit.roll(Crit.sourceChance(source))
	if crit then
		amount = math.round(amount * Crit.MULTIPLIER)
	end
	amount = mitigate(player, amount)
	flash(character)
	if amount <= 0 then
		CombatText.absorbed(player)
		return true
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
	return true
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
local playerFromPart = CombatService.playerFromPart

-- Daño de un jugador a otro. Si le quita toda la vida, el place decide qué pasa
-- (CombatRules.knockOut: en la Isla queda caído y se cobra su recompensa PvP).
-- "crit": golpe crítico (lo tira quien llama, con el arma del atacante). "poison": es un golpe del
-- veneno (número morado, sin destello). Con CombatRules.pvpStatus, los marcados por un cazador y los
-- expuestos (dormidos por la "Nana de la selva") reciben su daño extra, como los monos.
function CombatService.damagePvP(
	attacker: Player,
	victim: Player,
	amount: number,
	crit: boolean?,
	poison: boolean?
): boolean
	if not CombatService.canHitPlayer(attacker, victim) then
		return false
	end
	local character = victim.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (character and humanoid and humanoid.Health > 0) then
		return false
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
		return true
	end
	if poison then
		CombatText.poison(character, amount, attacker, humanoid.Health - amount <= 0)
	else
		CombatText.taken(victim, amount, crit, attacker)
	end
	if humanoid.Health - amount > 0 then
		humanoid:TakeDamage(amount)
		return true
	end
	CombatRules.get().knockOut(victim, attacker, "PvP")
	return true
end

-- Fracción del daño de "weaponId" contra jugadores (CombatRules: el general y el de esa arma).
local function pvpWeaponScale(weaponId: string): number
	local rules = CombatRules.get()
	return rules.pvpWeaponMultiplier * (rules.pvpWeaponMultipliers[weaponId] or 1)
end

local function meleeAttack(
	player: Player,
	character: Model,
	root: BasePart,
	weaponId: string,
	weapon: Weapons.WeaponDefinition,
	critChance: number
)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local box = root.CFrame * CFrame.new(0, 0, -weapon.range / 2)
	local size = Vector3.new(MELEE_HITBOX.X, MELEE_HITBOX.Y, weapon.range)

	-- "+daño cuerpo a cuerpo" del guerrero.
	local damage = math.round(weapon.damage * Progression.perk(player, "MeleeDamage"))
	local alreadyHit: { [Model]: boolean } = {}
	local playersHit: { [Player]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInBox(box, size, params) do
		local model, humanoid = enemyFromPart(part)
		if model and humanoid and not alreadyHit[model] then
			alreadyHit[model] = true
			CombatService.damage(model, humanoid, damage, player, { crit = Crit.roll(critChance), source = weaponId })
		end
		local victim = playerFromPart(part)
		if victim and not playersHit[victim] then
			playersHit[victim] = true
			CombatService.damagePvP(player, victim, damage * pvpWeaponScale(weaponId), Crit.roll(critChance))
		end
	end
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

-- Ayuda de puntería: el enemigo vivo más alineado con la dirección de apuntado, dentro del alcance.
local function findAimTarget(origin: Vector3, aim: Vector3, weapon: Weapons.WeaponDefinition): (Model?, BasePart?)
	local bestModel: Model? = nil
	local bestPart: BasePart? = nil
	local bestAngle = math.huge
	for _, instance in CollectionService:GetTagged(Config.Combat.EnemyTag) do
		local humanoid = instance:FindFirstChildOfClass("Humanoid")
		local part = if instance:IsA("Model") then instance.PrimaryPart else nil
		if humanoid and humanoid.Health > 0 and part then
			local offset = part.Position - origin
			if offset.Magnitude <= weapon.range and offset.Magnitude > 0 then
				local angle = CombatService.aimDeviation(origin, aim, part.Position, weapon.aimAssistDegrees or 0)
				if angle and angle < bestAngle then
					bestAngle = angle
					bestModel = instance :: Model
					bestPart = part
				end
			end
		end
	end
	return bestModel, bestPart
end

-- Lo que se ve volar: piedra (honda), flecha (arco), dardo de savia (cerbatana) o bola de energía
-- (bastón y hechizos).
-- Devuelve los segundos que tarda en llegar y la pieza.
function CombatService.projectile(
	style: string,
	origin: Vector3,
	endPoint: Vector3,
	speed: number,
	color: Color3?
): (number, BasePart)
	local piece = Instance.new("Part")
	piece.Name = "Projectile"
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	if style == "Arrow" then
		piece.Size = Vector3.new(0.15, 0.15, 2.2)
		piece.Color = Color3.fromRGB(120, 85, 50)
		piece.Material = Enum.Material.Wood
	elseif style == "Dart" then
		piece.Size = Vector3.new(0.1, 0.1, 0.9)
		piece.Color = Color3.fromRGB(150, 225, 120)
		piece.Material = Enum.Material.Neon
	elseif style == "Spell" then
		piece.Shape = Enum.PartType.Ball
		piece.Size = Vector3.one * 0.9
		piece.Color = color or Color3.fromRGB(170, 110, 255)
		piece.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = piece.Color
		light.Range = 8
		light.Parent = piece
	else
		piece.Shape = Enum.PartType.Ball
		piece.Size = Vector3.one * 0.6
		piece.Color = Color3.fromRGB(130, 130, 135)
	end
	local offset = endPoint - origin
	piece.CFrame = if offset.Magnitude > 0.01 then CFrame.lookAt(origin, endPoint) else CFrame.new(origin)
	piece.Parent = Workspace
	local travelSeconds = offset.Magnitude / speed
	TweenService
		:Create(piece, TweenInfo.new(travelSeconds, Enum.EasingStyle.Linear), { CFrame = piece.CFrame + offset })
		:Play()
	Debris:AddItem(piece, travelSeconds + 0.05)
	return travelSeconds, piece
end

-- Cerbatanas del médico: el acierto cura al aliado vivo más herido cerca (o al propio médico). Solo a
-- los aliados según las reglas del place (en la arena, los de su equipo).
local function healWoundedAlly(healer: Player, amount: number, weaponId: string)
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
		CombatService.heal(best, amount, healer, { source = weaponId })
	end
end

local function rangedAttack(
	player: Player,
	character: Model,
	root: BasePart,
	weaponId: string,
	weapon: Weapons.WeaponDefinition,
	aim: Vector3,
	critChance: number
)
	local ammo = weapon.ammoItemId
	local rules = CombatRules.get()
	if ammo and not rules.useAmmo(player, ammo) then
		Remotes.Notify:FireClient(player, `Necesitas {Items[ammo].name} para usar: {weapon.name}`)
		return
	end
	-- "+daño a distancia" del cazador o "+daño de hechizos" del mago, con sus talentos (también el veneno).
	local scale = Progression.perk(player, if weapon.spell then "SpellDamage" else "RangedDamage")
	local damage = math.round(weapon.damage * scale)
	-- Dardos venenosos del médico: munición opcional; mientras queden, cada disparo gasta uno.
	local poison = weapon.poison
	local poisonDps = if poison then poison.dps * scale else 0
	local boost = if poison then poison.boostItemId else nil
	if boost and rules.useBoost(player, boost) then
		poisonDps *= Items[boost].poisonMultiplier or 1
	end
	local crit = Crit.roll(critChance)
	-- La animación del disparo se ve sola (es del personaje); la bocanada o el destello, a los demás
	-- (el que dispara ya los ha lanzado en su cliente).
	AbilityFx.others(player, "WeaponShotFx", character, weapon.projectile or "Stone")

	local head = character:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.new(0, 1.5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local targetModel, targetPart = findAimTarget(origin, aim, weapon)
	local endPoint: Vector3
	if targetModel and targetPart then
		-- Comprueba que no haya nada en medio (árboles, rocas, terreno).
		params.FilterDescendantsInstances = { character, targetModel }
		local blocked = Workspace:Raycast(origin, targetPart.Position - origin, params)
		if blocked then
			targetModel = nil
			endPoint = blocked.Position
		else
			endPoint = targetPart.Position
		end
	else
		local result = Workspace:Raycast(origin, aim * weapon.range, params)
		endPoint = if result then result.Position else origin + aim * weapon.range
		if result then
			targetModel = enemyFromPart(result.Instance)
			-- Otro jugador al que se puede herir: la piedra le da al llegar.
			local victim = playerFromPart(result.Instance)
			if victim then
				local seconds = (endPoint - origin).Magnitude / (weapon.projectileSpeed or 120)
				task.delay(seconds, function()
					local pvpScale = pvpWeaponScale(weaponId)
					local hit = CombatService.damagePvP(player, victim, damage * pvpScale, crit)
					-- Con pvpStatus, los dardos de las cerbatanas también envenenan a los rivales.
					local victimCharacter = victim.Character
					if hit and poison and rules.pvpStatus and victimCharacter then
						Status.poison(victimCharacter, poisonDps * pvpScale, poison.seconds, player, weaponId)
					end
				end)
			end
		end
	end

	-- Proyectil visible que vuela hasta el destino; el daño llega cuando impacta.
	local travelSeconds =
		CombatService.projectile(weapon.projectile or "Stone", origin, endPoint, weapon.projectileSpeed or 120)

	local hitModel = targetModel
	if hitModel then
		task.delay(travelSeconds, function()
			local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				CombatService.damage(hitModel, humanoid, damage, player, { crit = crit, source = weaponId })
				if poison and humanoid.Health > 0 then
					Status.poison(hitModel, poisonDps, poison.seconds, player, weaponId)
				end
				if weapon.healOnHit then
					healWoundedAlly(player, weapon.healOnHit, weaponId)
				end
			end
		end)
	end
end

local function onUseWeapon(player: Player, aim: any)
	if not LifeState.isAlive(player) then
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
	local last = lastAttackAt[player]
	if last and now - last < weapon.cooldownSeconds then
		return
	end
	lastAttackAt[player] = now

	if weapon.kind == "Melee" then
		WeaponTools.playUse(tool)
		meleeAttack(player, character, root, weaponId :: string, weapon, Crit.weaponChance(weaponId :: string))
		-- El hacha y el pico, además de golpear enemigos, trabajan el árbol o la roca de delante.
		if weapon.tool then
			CombatRules.get().strikeResource(player, root, weapon.tool)
		end
	elseif typeof(aim) == "Vector3" and aim.Magnitude > 0.5 then
		WeaponTools.playUse(tool)
		rangedAttack(
			player,
			character,
			root,
			weaponId :: string,
			weapon,
			aim.Unit,
			Crit.weaponChance(weaponId :: string)
		)
	end
end

local function onDodge(player: Player)
	local now = os.clock()
	local last = lastDodgeAt[player]
	-- Pequeño margen sobre el tiempo de espera del cliente por el retraso de la red.
	if last and now - last < Config.Combat.DodgeCooldownSeconds * 0.8 then
		return
	end
	lastDodgeAt[player] = now
	player:SetAttribute("InvulnerableUntil", Workspace:GetServerTimeNow() + Config.Combat.DodgeInvulnerableSeconds)
end

-- Las armas iniciales van a StarterGear: Roblox las copia a la mochila en cada reaparición.
-- Primero las del rol (atributo "RoleWeapon") y detrás las comunes del place (el hacha y el pico en la
-- Isla), así las teclas 3 y 4 son siempre las mismas. Si cambia el rol a mitad de partida (panel de pruebas), solo cambian las del rol.
local function giveWeapons(player: Player, weaponIds: { string }, roleWeapon: boolean)
	local starterGear = player:WaitForChild("StarterGear")
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, weaponId in weaponIds do
		-- Con el aspecto equipado (CosmeticsServer) del rol o del machete, si le vale.
		local tool = WeaponTools.build(weaponId, if roleWeapon then WeaponTools.skinOf(player, weaponId) else nil)
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

	Players.PlayerAdded:Connect(giveStarterWeapons)
	for _, player in Players:GetPlayers() do
		task.spawn(giveStarterWeapons, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAttackAt[player] = nil
		lastDodgeAt[player] = nil
	end)
end

return CombatService
