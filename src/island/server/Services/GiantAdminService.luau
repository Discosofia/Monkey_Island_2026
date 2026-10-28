--!strict
-- El administrador convertido en jefe gigante (T4e), desde el panel de administradores ("👹 Ser
-- gigante", Data/IslandActions; lo manda AdminEventsService). Solo en su partida de la Isla:
--   - Su personaje crece Config.GiantAdmin.Scale, con una corona voxel, y su vida pasa a la de un jefe
--     según cuántos jugadores hay (BaseHealth × (1 + HealthPerExtraPlayer × (jugadores − 1))). Sale en la
--     barra de jefe (atributos "Boss*" de ReplicatedStorage, como BossService); no se puede si hay un
--     jefe despierto.
--   - Todos pueden pegarle y él puede pegar a todos los que no estén en el Basecamp (CombatRules:
--     canHitPlayer), con su rol y con tres golpes de jefe con aviso en el suelo (Remotes.GiantAttack:
--     pisotón, ola de choque en línea y rugido que aturde; island/client/Controllers/GiantAdminController).
--     Los que tumba quedan caídos como en el PvP, pero sin recompensa.
--   - Cuando cae, vuelve a su tamaño y los que le han pegado se llevan el título «Matagigantes» y un
--     huevo legendario. Volver a pulsar "Ser gigante" lo deshace sin premio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local CombatRules = require(ServerScriptService.Combat.CombatRules)
local Status = require(ServerScriptService.Combat.Status)
local CombatService = require(ServerScriptService.Combat.Services.CombatService)
local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)
local Eggs = require(ServerScriptService.ServerShared.Eggs)
local Hazards = require(script.Parent.Parent.Combat.Hazards)
local BossService = require(script.Parent.BossService)
local RoleService = require(script.Parent.RoleService)

local ATTRIBUTE = "AdminBoss"
local CAUSE = "Gigante"
local WARNING = Color3.fromRGB(255, 160, 40) -- naranja: aviso
local GOLD = Color3.fromRGB(255, 205, 70)
local GEM = Color3.fromRGB(90, 160, 255)
local BOSS_ATTRIBUTES = { "BossName", "BossHealth", "BossMaxHealth", "BossPhase", "BossPosition", "BossFighting" }

type Giant = {
	player: Player,
	humanoid: Humanoid,
	-- Último intento de golpe de cada jugador (os.clock), para saber quién le ha pegado.
	attempts: { [Player]: number },
	credited: { [Player]: boolean },
	readyAt: { [string]: number },
	connections: { RBXScriptConnection },
}

local GiantAdminService = {}

local giant: Giant? = nil

local function settingsOf(attack: string): any
	return (Config.GiantAdmin :: any)[attack]
end

-- Corona voxel dorada con gemas, pegada a la cabeza (se ve también por detrás).
local function crown(head: BasePart, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "CoronaGigante"
	local block = 0.32 * scale
	local radius = head.Size.X * 0.5
	local top = head.CFrame * CFrame.new(0, head.Size.Y * 0.5 + block * 0.5, 0)
	local function piece(offset: CFrame, size: Vector3, color: Color3, neon: boolean?)
		local part = Instance.new("Part")
		part.Size = size
		part.CFrame = top * offset
		part.Color = color
		part.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = part
		weld.Parent = part
	end
	-- Aro de 12 bloques y 6 puntas altas alternas, con una gema en cada punta.
	for index = 0, 11 do
		local angle = index / 12 * math.pi * 2
		local around = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
		piece(around, Vector3.new(block * 1.4, block, block), GOLD)
		if index % 2 == 0 then
			piece(around * CFrame.new(0, block, 0), Vector3.new(block, block, block), GOLD)
			piece(around * CFrame.new(0, block * 2, 0), Vector3.new(block * 0.7, block * 0.7, block * 0.7), GEM, true)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 12 * scale
	light.Brightness = 1.5
	light.Parent = head
	light.Name = "LuzCorona"
	model.Parent = head.Parent
	return model
end

local function clearBossAttributes()
	for _, name in BOSS_ATTRIBUTES do
		ReplicatedStorage:SetAttribute(name, nil)
	end
end

local function publish(current: Giant)
	-- Si despierta un jefe de verdad mientras tanto, la barra es suya.
	if BossService.isAlive() then
		return
	end
	local humanoid = current.humanoid
	local root = humanoid.RootPart
	local fraction = humanoid.Health / math.max(1, humanoid.MaxHealth)
	ReplicatedStorage:SetAttribute(
		"BossName",
		Strings.pack("👹 {player}, el gigante", { player = current.player.DisplayName })
	)
	ReplicatedStorage:SetAttribute("BossHealth", math.max(0, humanoid.Health))
	ReplicatedStorage:SetAttribute("BossMaxHealth", humanoid.MaxHealth)
	ReplicatedStorage:SetAttribute("BossPhase", if fraction > 2 / 3 then 1 elseif fraction > 1 / 3 then 2 else 3)
	ReplicatedStorage:SetAttribute("BossFighting", true)
	if root then
		ReplicatedStorage:SetAttribute("BossPosition", root.Position)
	end
end

-- Vuelve a su tamaño y a su vida; con "defeated", reparte el premio.
local function finish(defeated: boolean)
	local current = giant
	if not current then
		return
	end
	giant = nil
	for _, connection in current.connections do
		connection:Disconnect()
	end
	local player = current.player
	player:SetAttribute(ATTRIBUTE, nil)
	for attack in current.readyAt do
		player:SetAttribute(`GiantReadyAt_{attack}`, nil)
	end
	if not BossService.isAlive() then
		clearBossAttributes()
	end
	local character = player.Character
	if character and character.Parent then
		local head = character:FindFirstChild("Head")
		local old = character:FindFirstChild("CoronaGigante")
		if old then
			old:Destroy()
		end
		local light = if head then head:FindFirstChild("LuzCorona") else nil
		if light then
			light:Destroy()
		end
		character:ScaleTo(1)
		RoleService.refreshPerks(player)
		current.humanoid.Health = current.humanoid.MaxHealth
	end
	if not defeated then
		Remotes.Notify:FireAllClients("👹 {player} ha vuelto a su tamaño", { player = player.DisplayName })
		return
	end
	Sfx.play("TreeFall", if character then character:GetPivot().Position else Vector3.zero)
	local names = {}
	local egg = { lower = { Rarities[Config.GiantAdmin.RewardEgg].name } }
	for winner in current.credited do
		if winner.Parent and winner ~= player then
			table.insert(names, winner.DisplayName)
			CosmeticsServer.grant(winner, Config.GiantAdmin.RewardTitle)
			Eggs.grant(winner, Config.GiantAdmin.RewardEgg)
			Remotes.Notify:FireClient(
				winner,
				"👹 ¡Has derribado al gigante! Título «Matagigantes» y un huevo {rarity}",
				{ rarity = egg }
			)
		end
	end
	if #names > 0 then
		Remotes.Notify:FireAllClients(
			"👹 ¡El gigante ha caído! Premio para {players}",
			{ players = table.concat(names, ", ") }
		)
	else
		Remotes.Notify:FireAllClients("👹 ¡El gigante ha caído!")
	end
end

-- Alguien ha intentado pegarle: si pierde vida enseguida, cuenta para el premio.
local function noteAttempt(attacker: Player)
	local current = giant
	if current then
		current.attempts[attacker] = os.clock()
	end
end

local function become(player: Player): string?
	if giant then
		return if giant.player == player then nil else "👹 Ya hay un gigante en esta partida"
	end
	if BossService.isAlive() then
		return "👑 Hay un jefe despierto: espera a que caiga"
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local head = if character then character:FindFirstChild("Head") else nil
	if not (character and humanoid and humanoid.Health > 0 and head and head:IsA("BasePart")) then
		return "👹 Necesitas estar vivo en la isla"
	end
	local settings = Config.GiantAdmin
	character:ScaleTo(settings.Scale)
	crown(head, settings.Scale)
	local players = #Players:GetPlayers()
	humanoid.MaxHealth = math.round(settings.BaseHealth * (1 + settings.HealthPerExtraPlayer * (players - 1)))
	humanoid.Health = humanoid.MaxHealth
	player:SetAttribute(ATTRIBUTE, true)
	local current: Giant = {
		player = player,
		humanoid = humanoid,
		attempts = {},
		credited = {},
		readyAt = {},
		connections = {},
	}
	giant = current
	local lastHealth = humanoid.Health
	table.insert(
		current.connections,
		humanoid.HealthChanged:Connect(function(health)
			if health < lastHealth then
				local now = os.clock()
				for attacker, at in current.attempts do
					if now - at <= settings.CreditSeconds then
						current.credited[attacker] = true
					end
				end
			end
			lastHealth = health
			publish(current)
		end)
	)
	-- Si muere por algo que no pasa por CombatRules.knockOut (caerse al vacío…), también ha caído.
	table.insert(
		current.connections,
		humanoid.Died:Connect(function()
			finish(true)
		end)
	)
	table.insert(
		current.connections,
		player.CharacterRemoving:Connect(function()
			finish(false)
		end)
	)
	table.insert(
		current.connections,
		player.AncestryChanged:Connect(function()
			if not player.Parent then
				finish(false)
			end
		end)
	)
	task.spawn(function()
		while giant == current do
			publish(current)
			task.wait(0.25)
		end
	end)
	Remotes.Notify:FireAllClients(
		"👹 ¡{player} se ha convertido en un gigante! Pégale entre todos: quien le dé se lleva un premio",
		{ player = player.DisplayName }
	)
	return nil
end

-- Vuelve a su tamaño (sin premio) o se convierte en gigante. Devuelve el aviso para el administrador.
function GiantAdminService.toggle(player: Player): (boolean, string?)
	if giant and giant.player == player then
		finish(false)
		return true, nil
	end
	local reason = become(player)
	return reason == nil, reason
end

-- Daña y, si hace falta, aturde a los jugadores alcanzados (no a él ni a los del Basecamp).
local function hit(players: { Player }, damage: number, stunSeconds: number?)
	local current = giant
	if not current then
		return
	end
	for _, victim in players do
		if
			victim ~= current.player
			and CombatService.damagePlayer(victim, damage, false, nil, CAUSE)
			and stunSeconds
		then
			Status.stunPlayer(victim, stunSeconds, CAUSE)
		end
	end
end

local ATTACKS: { [string]: (root: BasePart, aim: Vector3) -> () } = {
	-- Pisotón: un aro a su alrededor.
	Stomp = function(root)
		local settings = Config.GiantAdmin.Stomp
		Hazards.warnArea(root.Position, settings.radius, WARNING, settings.warnSeconds, function(players, ground)
			Sfx.play("TreeFall", ground)
			hit(players, settings.damage, settings.stunSeconds)
		end)
	end,
	-- Ola de choque: impactos seguidos en línea hacia donde apunta.
	Wave = function(root, aim)
		local settings = Config.GiantAdmin.Wave
		for index = 1, settings.impacts do
			local spot = root.Position + aim * (settings.spacing * index)
			local warn = settings.warnSeconds + settings.stepSeconds * index
			Hazards.warnArea(spot, settings.radius, WARNING, warn, function(players, ground)
				Sfx.play("LavaImpact", ground)
				hit(players, settings.damage)
			end)
		end
	end,
	-- Rugido: poco daño y aturde a todos los de alrededor.
	Roar = function(root)
		local settings = Config.GiantAdmin.Roar
		Hazards.warnArea(root.Position, settings.radius, WARNING, settings.warnSeconds, function(players)
			Sfx.play("Thunder", root.Position)
			hit(players, settings.damage, settings.stunSeconds)
		end)
	end,
}

local function onAttack(player: Player, attack: any, aim: any)
	local current = giant
	if not current or current.player ~= player or typeof(attack) ~= "string" or not ATTACKS[attack] then
		return
	end
	local root = current.humanoid.RootPart
	local now = Workspace:GetServerTimeNow()
	-- Aturdido (Status.stunPlayer pone la hora en el Player) no puede golpear.
	local stunnedUntil = player:GetAttribute("StunnedUntil")
	if not root or current.humanoid.Health <= 0 or (typeof(stunnedUntil) == "number" and stunnedUntil > now) then
		return
	end
	if now < (current.readyAt[attack] or 0) then
		return
	end
	local direction = if typeof(aim) == "Vector3" then Vector3.new(aim.X, 0, aim.Z) else Vector3.zero
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	local readyAt = now + settingsOf(attack).cooldown
	current.readyAt[attack] = readyAt
	player:SetAttribute(`GiantReadyAt_{attack}`, readyAt)
	ATTACKS[attack](root, direction.Unit)
end

function GiantAdminService:Start()
	Remotes.GiantAttack.OnServerEvent:Connect(onAttack)
	-- Las reglas de la Isla ya están puestas (IslandCombatRules, en su Init): se envuelven.
	local rules = CombatRules.get()
	local canHitPlayer, knockOut = rules.canHitPlayer, rules.knockOut
	CombatRules.set({
		canHitPlayer = function(attacker: Player, victim: Player): boolean
			if victim:GetAttribute(ATTRIBUTE) == true then
				noteAttempt(attacker)
				return true
			end
			if attacker:GetAttribute(ATTRIBUTE) == true then
				return victim:GetAttribute("InBasecamp") ~= true
			end
			return canHitPlayer(attacker, victim)
		end,
		knockOut = function(player: Player, attacker: Player?, cause: string)
			if player:GetAttribute(ATTRIBUTE) == true then
				if attacker then
					noteAttempt(attacker)
					local current = giant
					if current then
						current.credited[attacker] = true
					end
				end
				finish(true)
				return
			end
			-- Tumbado por el gigante: caído, sin recompensa PvP.
			if attacker and attacker:GetAttribute(ATTRIBUTE) == true then
				knockOut(player, nil, CAUSE)
				return
			end
			knockOut(player, attacker, cause)
		end,
	})
end

return GiantAdminService
