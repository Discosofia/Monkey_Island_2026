--!strict
-- Vida y reaparición en el Laboratorio (Fase 13, como RespawnService de Dunas): no hay caídos.
--   - Todos con Config.Lab.Health de vida, que vuelve sola tras RegenDelaySeconds sin recibir daño (el
--     script "Health" de Roblox está quitado).
--   - Un golpe mortal (CombatRules.knockOut) deja al jugador sin vida; también vale caerse del mapa.
--     Durante la partida cuenta la baja del que dispara y la caída del que cae ("ArenaKills" y
--     "ArenaDeaths", Shared/Arena) y avisa a quien escuche (onKnockedOut: LabMatchService suma la baja
--     al marcador del bando).
--   - Reaparece a los RespawnSeconds en plena partida, o casi al momento antes y después ("RespawnAt"
--     en el jugador dice cuándo; mientras, puede cambiar de arma, LabLoadoutService), en la zona de
--     salida de su bando (LabWorldService; el bando lo da LabTeamService antes de la primera aparición).
--   - Al aparecer en plena partida tiene SpawnProtectionSeconds sin recibir daño, que pierde al disparar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LabTeamService = require(script.Parent.LabTeamService)
local LabWorldService = require(script.Parent.LabWorldService)

-- Antes de la partida (o en los resultados) se reaparece casi al momento.
local QUICK_RESPAWN_SECONDS = 1

local LabRespawnService = {}

local lastHurtAt: { [Player]: number } = {}
local pending: { [Player]: thread } = {}
-- Hasta cuándo dura la protección de salida de cada uno (la misma hora que su "InvulnerableUntil").
local protectedUntil: { [Player]: number } = {}
local knockOutListeners: { (victim: Player, attacker: Player) -> () } = {}

-- Llama a "callback" cuando un rival derriba a un jugador en plena partida.
function LabRespawnService.onKnockedOut(callback: (victim: Player, attacker: Player) -> ())
	table.insert(knockOutListeners, callback)
end

local function addStat(player: Player, attribute: string)
	local value = player:GetAttribute(attribute)
	player:SetAttribute(attribute, (if typeof(value) == "number" then value else 0) + 1)
end

local function teamIcon(player: Player): string
	local teamId = Arena.teamOf(player)
	return if teamId then Arena.TEAMS[teamId].icon else ""
end

-- Golpe mortal de "attacker" (o de nada: caída, etc.). Lo registra el place en CombatRules.
function LabRespawnService.knockOut(victim: Player, attacker: Player?, _cause: string)
	local humanoid = if victim.Character then victim.Character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if attacker and attacker ~= victim and Arena.inBattle() then
		addStat(attacker, "ArenaKills")
		Remotes.Notify:FireAllClients("⚔️ {attacker} derriba a {victim}", {
			attacker = `{teamIcon(attacker)} {attacker.DisplayName}`,
			victim = `{teamIcon(victim)} {victim.DisplayName}`,
		})
		for _, listener in knockOutListeners do
			task.spawn(listener, victim, attacker)
		end
	end
	humanoid.Health = 0
end

-- Vuelve a cargar el personaje (aparece en su zona de salida por onCharacter).
function LabRespawnService.respawnNow(player: Player)
	local thread = pending[player]
	if thread then
		pending[player] = nil
		task.cancel(thread)
	end
	player:SetAttribute("RespawnAt", nil)
	if player.Parent then
		LabTeamService.ensureTeam(player)
		player:LoadCharacter()
	end
end

-- Todos de vuelta a su zona de salida (al empezar la partida y al volver a la espera).
function LabRespawnService.respawnAll()
	for _, player in Players:GetPlayers() do
		task.spawn(LabRespawnService.respawnNow, player)
	end
end

local function scheduleRespawn(player: Player)
	local seconds = if Arena.inBattle() then Config.Lab.RespawnSeconds else QUICK_RESPAWN_SECONDS
	player:SetAttribute("RespawnAt", Workspace:GetServerTimeNow() + seconds)
	pending[player] = task.delay(seconds, function()
		pending[player] = nil
		LabRespawnService.respawnNow(player)
	end)
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	LabTeamService.prepareCharacter(player, character)
	humanoid.MaxHealth = Config.Lab.Health
	humanoid.Health = Config.Lab.Health
	character:PivotTo(LabWorldService.spawnCFrame(Arena.teamOf(player)))
	root.AssemblyLinearVelocity = Vector3.zero
	if Arena.inBattle() then
		local untilTime = Workspace:GetServerTimeNow() + Config.Lab.SpawnProtectionSeconds
		protectedUntil[player] = untilTime
		player:SetAttribute("InvulnerableUntil", untilTime)
	end
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			lastHurtAt[player] = os.clock()
		end
		lastHealth = health
	end)
	humanoid.Died:Connect(function()
		if Arena.inBattle() then
			addStat(player, "ArenaDeaths")
		end
		if not pending[player] then
			scheduleRespawn(player)
		end
	end)
end

-- Disparar quita la protección de salida (no la invulnerabilidad de una esquiva, que es otra hora).
local function dropProtection(player: Player)
	local untilTime = protectedUntil[player]
	if untilTime and player:GetAttribute("InvulnerableUntil") == untilTime then
		player:SetAttribute("InvulnerableUntil", nil)
	end
	protectedUntil[player] = nil
end

local function regenerate(deltaTime: number)
	local settings = Config.Lab
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
		LabRespawnService.respawnNow(player)
	end
end

function LabRespawnService:Init()
	-- La aparición la decide este servicio (cuándo y dónde), no Roblox.
	Players.CharacterAutoLoads = false
end

function LabRespawnService:Start()
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
		protectedUntil[player] = nil
	end)
	Remotes.UseWeapon.OnServerEvent:Connect(dropProtection)
	RunService.Heartbeat:Connect(regenerate)
end

return LabRespawnService
