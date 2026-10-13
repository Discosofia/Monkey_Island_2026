--!strict
-- Combate (GDD §6, Fase 1.3): machete (cuerpo a cuerpo), honda (a distancia, gasta piedras) y esquiva.
-- El servidor decide todo: qué arma lleva el jugador, si el ataque está listo, a quién golpea y el daño.
-- Solo se puede dañar a lo que tenga la etiqueta Config.Combat.EnemyTag (monos, muñecos de práctica),
-- nunca a otros jugadores: el PvP opt-in llega en la Fase 5.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Armor = require(ReplicatedStorage.Shared.Data.Armor)
local Config = require(ReplicatedStorage.Shared.Config)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local LifeState = require(ReplicatedStorage.Shared.LifeState)
local Progression = require(ReplicatedStorage.Shared.Progression)
local MatchStats = require(ReplicatedStorage.Shared.MatchStats)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Survival = require(ReplicatedStorage.Shared.Survival)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local InventoryService = require(script.Parent.InventoryService)
local LifeService = require(script.Parent.LifeService)
local ResourceService = require(script.Parent.ResourceService)
local WeaponTools = require(script.Parent.Parent.Combat.WeaponTools)

-- Tamaño (ancho y alto) de la zona de golpe del cuerpo a cuerpo, delante del jugador.
local MELEE_HITBOX = Vector2.new(7, 6)

local CombatService = {}

local lastAttackAt: { [Player]: number } = {}
local damageListeners: { (model: Model, attacker: Player?, amount: number) -> () } = {}

-- Llama a "callback" cada vez que un enemigo recibe daño (BossService cuenta quién participa).
function CombatService.onEnemyDamaged(callback: (model: Model, attacker: Player?, amount: number) -> ())
	table.insert(damageListeners, callback)
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
local function enemyFromPart(part: Instance): (Model?, Humanoid?)
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

-- Destello rojo y número de daño flotante sobre el objetivo.
local function showHit(model: Model, amount: number)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.Parent = model
	Debris:AddItem(highlight, 0.15)

	local anchor = model:FindFirstChild("Head") or model.PrimaryPart
	if not (anchor and anchor:IsA("BasePart")) then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(80, 36)
	billboard.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = `-{amount}`
	label.TextColor3 = Color3.fromRGB(255, 220, 90)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.BuilderSansBold
	label.TextScaled = true
	label.Parent = billboard
	TweenService:Create(billboard, TweenInfo.new(0.7), { StudsOffset = billboard.StudsOffset + Vector3.new(0, 2, 0) })
		:Play()
	Debris:AddItem(billboard, 0.7)
end

-- Daña a un enemigo. "attacker" queda apuntado para repartir el botín si lo derrota.
-- Los monos marcados por un cazador (Fase 3) reciben daño extra mientras dura la marca.
function CombatService.damage(model: Model, humanoid: Humanoid, amount: number, attacker: Player?)
	if attacker then
		model:SetAttribute("LastAttackerUserId", attacker.UserId)
	end
	-- Intimidado por el rugido de un mandril (Fase 4): hace menos daño.
	local intimidatedUntil = if attacker then attacker:GetAttribute("IntimidatedUntil") else nil
	if typeof(intimidatedUntil) == "number" and Workspace:GetServerTimeNow() < intimidatedUntil then
		amount = math.max(1, math.round(amount * Config.Combat.IntimidatedDamageMultiplier))
	end
	local markedUntil = model:GetAttribute("MarkedUntil")
	local markBonus = model:GetAttribute("MarkBonus")
	if
		typeof(markedUntil) == "number"
		and Workspace:GetServerTimeNow() < markedUntil
		and typeof(markBonus) == "number"
	then
		amount = math.round(amount * (1 + markBonus))
	end
	humanoid:TakeDamage(amount)
	showHit(model, amount)
	Sfx.play("Hit", model.PrimaryPart or model)
	for _, listener in damageListeners do
		task.spawn(listener, model, attacker, amount)
	end
end

-- true mientras dura la invulnerabilidad de la esquiva.
function CombatService.isInvulnerable(player: Player): boolean
	local untilTime = player:GetAttribute("InvulnerableUntil")
	return typeof(untilTime) == "number" and Workspace:GetServerTimeNow() < untilTime
end

-- Daño de un enemigo (un mono) a un jugador. No hace nada si está en el Basecamp, esquivando,
-- caído o como Espíritu. La armadura reduce el daño (Data/Armor). Un golpe mortal no mata:
-- deja al jugador caído (LifeService). Devuelve true si el golpe entró.
-- "ignoreSafe": los monos del asedio (Fase 2.5) también hieren dentro del Basecamp.
function CombatService.damagePlayer(player: Player, amount: number, ignoreSafe: boolean?): boolean
	local safe = player:GetAttribute("InBasecamp") == true and not ignoreSafe
	if safe or CombatService.isInvulnerable(player) or not LifeState.isAlive(player) then
		return false
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (character and humanoid and humanoid.Health > 0) then
		return false
	end
	local armorId = player:GetAttribute("Armor")
	local armor = if typeof(armorId) == "string" then Armor[armorId] else nil
	if armor then
		amount = math.max(1, math.round(amount * (1 - armor.damageReduction)))
	end
	showHit(character, amount)
	-- Cada mordisco sube la fiebre del mono (Fase 2.6).
	Survival.addFever(player, Config.Fever.PerBite)
	if humanoid.Health - amount <= 0 then
		Sfx.play("PlayerDown", character.PrimaryPart or character)
		LifeService.down(player)
	else
		Sfx.play("PlayerHurt", character.PrimaryPart or character)
		humanoid:TakeDamage(amount)
	end
	return true
end

-- PvP opt-in (GDD §12, Fase 5): ambos con PvP activo y ninguno dentro del Basecamp.
local function pvpReady(player: Player): boolean
	return player:GetAttribute("PvP") == true and player:GetAttribute("InBasecamp") ~= true
end

local function playerFromPart(part: Instance): Player?
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

-- Daño de un jugador a otro. Si lo deja caído, cobra su recompensa por cabeza y sube la propia.
function CombatService.damagePvP(attacker: Player, victim: Player, amount: number): boolean
	if attacker == victim or not (pvpReady(attacker) and pvpReady(victim)) then
		return false
	end
	if CombatService.isInvulnerable(victim) or not LifeState.isAlive(victim) then
		return false
	end
	local character = victim.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not (character and humanoid and humanoid.Health > 0) then
		return false
	end
	local armorId = victim:GetAttribute("Armor")
	local armor = if typeof(armorId) == "string" then Armor[armorId] else nil
	if armor then
		amount = math.max(1, math.round(amount * (1 - armor.damageReduction)))
	end
	showHit(character, amount)
	if humanoid.Health - amount > 0 then
		humanoid:TakeDamage(amount)
		return true
	end
	LifeService.down(victim)
	local bounty = victim:GetAttribute("Bounty")
	local collected = if typeof(bounty) == "number" then bounty else 0
	local own = attacker:GetAttribute("Bounty")
	attacker:SetAttribute("Bounty", (if typeof(own) == "number" then own else 0) + 1)
	victim:SetAttribute("Bounty", 0)
	if collected > 0 then
		MatchStats.add(attacker, MatchStats.BOUNTIES, collected)
		Remotes.Notify:FireAllClients(
			`💰 {attacker.DisplayName} cobra la recompensa de {victim.DisplayName} ({collected})`
		)
	else
		Remotes.Notify:FireClient(attacker, `⚔️ Has derribado a {victim.DisplayName}`)
	end
	return true
end

local function meleeAttack(player: Player, character: Model, root: BasePart, weapon: Weapons.WeaponDefinition)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local box = root.CFrame * CFrame.new(0, 0, -weapon.range / 2)
	local size = Vector3.new(MELEE_HITBOX.X, MELEE_HITBOX.Y, weapon.range)

	local alreadyHit: { [Model]: boolean } = {}
	local playersHit: { [Player]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInBox(box, size, params) do
		local model, humanoid = enemyFromPart(part)
		if model and humanoid and not alreadyHit[model] then
			alreadyHit[model] = true
			CombatService.damage(model, humanoid, weapon.damage, player)
		end
		local victim = playerFromPart(part)
		if victim and not playersHit[victim] then
			playersHit[victim] = true
			CombatService.damagePvP(player, victim, weapon.damage)
		end
	end
end

-- Ayuda de puntería: el enemigo vivo más alineado con la dirección de apuntado, dentro del alcance.
local function findAimTarget(origin: Vector3, aim: Vector3, weapon: Weapons.WeaponDefinition): (Model?, BasePart?)
	local bestModel: Model? = nil
	local bestPart: BasePart? = nil
	local bestAngle = math.rad(weapon.aimAssistDegrees or 0)
	for _, instance in CollectionService:GetTagged(Config.Combat.EnemyTag) do
		local humanoid = instance:FindFirstChildOfClass("Humanoid")
		local part = if instance:IsA("Model") then instance.PrimaryPart else nil
		if humanoid and humanoid.Health > 0 and part then
			local offset = part.Position - origin
			if offset.Magnitude <= weapon.range and offset.Magnitude > 0 then
				local angle = math.acos(math.clamp(offset.Unit:Dot(aim), -1, 1))
				if angle <= bestAngle then
					bestAngle = angle
					bestModel = instance :: Model
					bestPart = part
				end
			end
		end
	end
	return bestModel, bestPart
end

local function rangedAttack(
	player: Player,
	character: Model,
	root: BasePart,
	weapon: Weapons.WeaponDefinition,
	aim: Vector3
)
	local ammo = weapon.ammoItemId
	if ammo and not InventoryService.remove(player, ammo, 1) then
		Remotes.Notify:FireClient(player, `Necesitas {Items[ammo].name} para usar la {weapon.name}`)
		return
	end

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
			-- Otro jugador con PvP: la piedra le da al llegar.
			local victim = playerFromPart(result.Instance)
			if victim then
				local seconds = (endPoint - origin).Magnitude / (weapon.projectileSpeed or 120)
				local damage = math.round(weapon.damage * Progression.perk(player, "RangedDamage"))
				task.delay(seconds, function()
					CombatService.damagePvP(player, victim, damage)
				end)
			end
		end
	end

	-- Piedra visible que vuela hasta el destino; el daño llega cuando impacta.
	local stone = Instance.new("Part")
	stone.Name = "HondaStone"
	stone.Shape = Enum.PartType.Ball
	stone.Size = Vector3.one * 0.6
	stone.Color = Color3.fromRGB(130, 130, 135)
	stone.Anchored = true
	stone.CanCollide = false
	stone.CanQuery = false
	stone.CanTouch = false
	stone.Position = origin
	stone.Parent = Workspace
	local travelSeconds = (endPoint - origin).Magnitude / (weapon.projectileSpeed or 120)
	TweenService:Create(stone, TweenInfo.new(travelSeconds, Enum.EasingStyle.Linear), { Position = endPoint }):Play()
	Debris:AddItem(stone, travelSeconds + 0.05)

	local hitModel = targetModel
	if hitModel then
		task.delay(travelSeconds, function()
			local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				-- "+daño a distancia" del cazador y sus talentos.
				local damage = math.round(weapon.damage * Progression.perk(player, "RangedDamage"))
				CombatService.damage(hitModel, humanoid, damage, player)
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
		meleeAttack(player, character, root, weapon)
		-- El hacha y el pico, además de golpear enemigos, trabajan el árbol o la roca de delante.
		if weapon.tool then
			ResourceService.strike(player, root, weapon.tool)
		end
	elseif typeof(aim) == "Vector3" and aim.Magnitude > 0.5 then
		WeaponTools.playUse(tool)
		rangedAttack(player, character, root, weapon, aim.Unit)
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
local function giveStarterWeapons(player: Player)
	local starterGear = player:WaitForChild("StarterGear")
	for _, weaponId in Config.Combat.StarterWeapons do
		WeaponTools.build(weaponId).Parent = starterGear
	end
	-- Si el personaje ya apareció, esta vida también las recibe.
	local backpack = player:FindFirstChildOfClass("Backpack")
	if player.Character and backpack then
		for _, tool in starterGear:GetChildren() do
			tool:Clone().Parent = backpack
		end
	end
end

function CombatService:Start()
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
