--!strict
-- Vida y reaparición en la arena: aquí no hay caídos ni reanimaciones (eso es de la Isla).
--   - Un golpe mortal (CombatRules.knockOut) cuenta la baja y deja al jugador sin vida; también
--     vale caerse del mapa.
--   - Reaparece en la baldosa de su base tras Config.Arena.RespawnSeconds (CarrierRespawnSeconds si
--     llevaba la bandera), o al momento antes de la partida. "RespawnAt" en el jugador dice cuándo.
--   - Al aparecer en plena partida tiene SPAWN_PROTECTION_SECONDS de invulnerabilidad.
--   - La vida se recupera sola tras RegenDelaySeconds sin recibir daño (el script "Health" de Roblox
--     está quitado, como en la Isla).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ArenaWorldService = require(script.Parent.ArenaWorldService)

local SPAWN_PROTECTION_SECONDS = 2
-- Antes de la partida (o en los resultados) se reaparece casi al momento.
local QUICK_RESPAWN_SECONDS = 1

local RespawnService = {}

local lastHurtAt: { [Player]: number } = {}
local pending: { [Player]: thread } = {}
local knockOutListeners: { (victim: Player, attacker: Player?) -> () } = {}
local diedListeners: { (player: Player, position: Vector3) -> () } = {}

-- Llama a "callback" cuando un rival derriba a un jugador (golpe mortal en combate).
function RespawnService.onKnockedOut(callback: (victim: Player, attacker: Player?) -> ())
	table.insert(knockOutListeners, callback)
end

-- Llama a "callback" cada vez que un jugador se queda sin vida, por lo que sea (también al caerse del
-- mapa), con dónde estaba: FlagService suelta ahí la bandera que llevaba.
function RespawnService.onDied(callback: (player: Player, position: Vector3) -> ())
	table.insert(diedListeners, callback)
end

local function addStat(player: Player, attribute: string)
	local value = player:GetAttribute(attribute)
	player:SetAttribute(attribute, (if typeof(value) == "number" then value else 0) + 1)
end

local function teamIcon(player: Player): string
	local teamId = Arena.teamOf(player)
	return if teamId then Config.Arena.Teams[teamId].icon else ""
end

-- Golpe mortal de "attacker" (o de nada: caída, etc.). Lo registra el place en CombatRules.
function RespawnService.knockOut(victim: Player, attacker: Player?, _cause: string)
	local humanoid = if victim.Character then victim.Character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if attacker and attacker ~= victim then
		addStat(attacker, "ArenaKills")
		Remotes.Notify:FireAllClients("⚔️ {attacker} derriba a {victim}", {
			attacker = `{teamIcon(attacker)} {attacker.DisplayName}`,
			victim = `{teamIcon(victim)} {victim.DisplayName}`,
		})
	end
	for _, listener in knockOutListeners do
		task.spawn(listener, victim, attacker)
	end
	-- Quién lo derribó y con qué, para la killcam del cliente (SpectateCamera).
	Arena.markKiller(victim, attacker)
	humanoid.Health = 0
end

-- Vuelve a cargar el personaje (aparece en su base por onCharacter).
function RespawnService.respawnNow(player: Player)
	local thread = pending[player]
	if thread then
		pending[player] = nil
		task.cancel(thread)
	end
	player:SetAttribute("RespawnAt", nil)
	Arena.markKiller(player, nil)
	if player.Parent then
		player:LoadCharacter()
	end
end

-- Todos de vuelta a su base (al empezar y al acabar la partida).
function RespawnService.respawnAll()
	for _, player in Players:GetPlayers() do
		task.spawn(RespawnService.respawnNow, player)
	end
end

local function scheduleRespawn(player: Player, carrying: boolean)
	local seconds = QUICK_RESPAWN_SECONDS
	if Arena.inBattle() then
		seconds = if carrying then Config.Arena.CarrierRespawnSeconds else Config.Arena.RespawnSeconds
	end
	player:SetAttribute("RespawnAt", Workspace:GetServerTimeNow() + seconds)
	pending[player] = task.delay(seconds, function()
		pending[player] = nil
		RespawnService.respawnNow(player)
	end)
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	character:PivotTo(ArenaWorldService.spawnCFrame(Arena.teamOf(player)))
	root.AssemblyLinearVelocity = Vector3.zero
	Arena.markKiller(player, nil)
	if Arena.inBattle() then
		player:SetAttribute("InvulnerableUntil", Workspace:GetServerTimeNow() + SPAWN_PROTECTION_SECONDS)
	end
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			lastHurtAt[player] = os.clock()
		end
		lastHealth = health
	end)
	humanoid.Died:Connect(function()
		-- La bandera se suelta en los oyentes de knockOut; quién la llevaba se mira aquí antes.
		local carrying = player:GetAttribute("CarryingFlag") ~= nil
		if Arena.inBattle() then
			addStat(player, "ArenaDeaths")
		end
		if not pending[player] then
			scheduleRespawn(player, carrying)
		end
		for _, listener in diedListeners do
			task.spawn(listener, player, root.Position)
		end
	end)
end

local function regenerate(deltaTime: number)
	local settings = Config.Arena
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		if
			humanoid
			and humanoid.Health > 0
			and humanoid.Health < humanoid.MaxHealth
			and now - (lastHurtAt[player] or 0) >= settings.RegenDelaySeconds
		then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + settings.RegenPerSecond * deltaTime)
		end
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	else
		player:LoadCharacter()
	end
end

function RespawnService:Init()
	-- La aparición la decide este servicio (cuándo y dónde), no Roblox.
	Players.CharacterAutoLoads = false
end

function RespawnService:Start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local thread = pending[player]
		if thread then
			task.cancel(thread)
		end
		pending[player] = nil
		lastHurtAt[player] = nil
	end)
	RunService.Heartbeat:Connect(regenerate)
end

return RespawnService
