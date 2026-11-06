--!strict
-- Panel de pruebas de la arena (solo Studio; Shared/DebugCommands.Dunas). En Studio no llega nadie
-- del Lobby: con "Empezar ya" la partida arranca con un solo equipo y no cuenta para nada.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Ballgame = require(ReplicatedStorage.Shared.Data.Ballgame)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Killfeed = require(ServerScriptService.Combat.Killfeed)
local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)
local GearShowcase = require(ServerScriptService.ServerShared.GearShowcase)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local ArenaMatchService = require(script.Parent.ArenaMatchService)
local ArenaWorldService = require(script.Parent.ArenaWorldService)
local BallService = require(script.Parent.BallService)

local DUMMY_HEALTH = 300
-- BallRing: la pelota sale de aquí (x local, y) hacia el centro del aro, con esta velocidad en X.
local RING_SHOT_X = -12
local RING_SHOT_Y = 12
local RING_SHOT_SPEED = 40

local ArenaDebugService = {}

local dummy: Model? = nil

-- Rival de práctica: un muñeco con la etiqueta de enemigo, 12 studs delante del jugador. Recibe el
-- daño de las armas y habilidades contra monos (no el de PvP), pero sirve para ver los efectos.
local function toggleDummy(player: Player)
	if dummy then
		dummy:Destroy()
		dummy = nil
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local pivot = character:GetPivot() * CFrame.new(0, 0, -12)
	local facing = CFrame.lookAt(pivot.Position, character:GetPivot().Position)
	local model = Instance.new("Model")
	model.Name = "Rival de práctica"
	model:SetAttribute("TrainingDummy", true)
	local function part(name: string, size: Vector3, offset: CFrame, color: Color3): Part
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Anchored = true
		piece.Size = size
		piece.CFrame = facing * offset
		piece.Color = color
		piece.Parent = model
		return piece
	end
	part("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 0, 0), Color3.fromRGB(190, 160, 110))
	local head = part("Head", Vector3.one * 1.6, CFrame.new(0, 1.8, 0), Color3.fromRGB(205, 175, 125))
	head.Shape = Enum.PartType.Ball
	part("Post", Vector3.new(0.6, 3, 0.6), CFrame.new(0, -2.5, 0), Color3.fromRGB(110, 72, 40))
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(), Color3.new())
	root.Transparency = 1
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = "Rival de práctica"
	humanoid.MaxHealth = DUMMY_HEALTH
	humanoid.Health = DUMMY_HEALTH
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	humanoid.HealthChanged:Connect(function(health)
		if health <= 0 then
			task.wait(1)
			humanoid.Health = DUMMY_HEALTH
		end
	end)
	CollectionService:AddTag(model, Config.Combat.EnemyTag)
	model.Parent = Workspace
	dummy = model
end

-- Lleva al jugador junto al pedestal de "teamId" (para probar las banderas sin cruzar la arena).
local function goToStand(player: Player, teamId: string?)
	local character = player.Character
	if not (character and teamId) then
		return
	end
	local stand = ArenaWorldService.base(teamId):FindFirstChild("FlagStand") :: BasePart
	-- Hacia el centro de la arena, a unos pasos del pedestal.
	local side = if stand.Position.X < 0 then 1 else -1
	character:PivotTo(CFrame.new(stand.Position + Vector3.new(side * 6, 4, 0)))
end

-- Los números sueltos de un texto "x y z vx vy vz" (o una tabla de ellos).
local function numbersOf(arg: any): { number }
	local values: { number } = {}
	if typeof(arg) == "string" then
		for token in string.gmatch(arg, "%-?%d+%.?%d*") do
			table.insert(values, tonumber(token) or 0)
		end
	elseif typeof(arg) == "table" then
		for _, value in arg do
			if typeof(value) == "number" then
				table.insert(values, value)
			end
		end
	end
	return values
end

-- Lado del aro que toca el siguiente BallRing sin argumento (alterna).
local nextRingSide = -1

-- Lanza la pelota desde x = RING_SHOT_X hacia el centro del aro del lado "zSign", para probar el pase.
local function shootAtRing(zSign: number)
	local ring = BallService.layout().ring
	local time = -RING_SHOT_X / RING_SHOT_SPEED
	local gravity = Ballgame.Gravity
	-- Vertical para que el centro llegue a la altura del aro al cabo de "time" (la gravedad lo baja).
	local vy = (ring.centerY - RING_SHOT_Y + 0.5 * gravity * time * time) / time
	BallService.setActive(true)
	BallService.place(Vector3.new(RING_SHOT_X, RING_SHOT_Y, zSign * ring.centerZ), Vector3.new(RING_SHOT_SPEED, vy, 0))
end

local COMMANDS: { [string]: (player: Player, arg: any) -> () } = {
	-- La pelota del Juego de pelota (Fase 26c). El modo aún no está en Config.Arena.Modes: se activa a mano.
	BallOn = function()
		BallService.setActive(true)
		if BallService.state().dead then
			BallService.place(Vector3.new(0, Ballgame.Serve.Height, 0))
		end
	end,
	BallOff = function()
		BallService.setActive(false)
	end,
	BallServe = function()
		BallService.setActive(true)
		BallService.serve()
	end,
	-- "x y z vx vy vz" en coordenadas locales de la cancha (la velocidad es opcional).
	BallPlace = function(_player, arg)
		local n = numbersOf(arg)
		if #n < 3 then
			return
		end
		BallService.setActive(true)
		BallService.place(Vector3.new(n[1], n[2], n[3]), Vector3.new(n[4] or 0, n[5] or 0, n[6] or 0))
	end,
	-- Lado del aro (-1 o 1); sin argumento, alterna.
	BallRing = function(_player, arg)
		local zSign = if arg == -1 or arg == 1 then arg else nextRingSide
		nextRingSide = -zSign
		shootAtRing(zSign)
	end,
	GoEnemyFlag = function(player)
		local teamId = Arena.teamOf(player)
		goToStand(player, if teamId then Arena.otherTeam(teamId) else nil)
	end,
	GoHome = function(player)
		goToStand(player, Arena.teamOf(player))
	end,
	-- El altar de la pirámide (C11, AltarService) se enciende ya (si está apagado en la partida) y el
	-- jugador sube a él.
	Altar = function(player)
		if ReplicatedStorage:GetAttribute("AltarState") == "Dormant" then
			ReplicatedStorage:SetAttribute("AltarReadyAt", Workspace:GetServerTimeNow())
		end
		local arena = Workspace:FindFirstChild("Arena")
		local altar = if arena then arena:FindFirstChild("Altar") else nil
		local center = if altar then altar:FindFirstChild("Captura") else nil
		if player.Character and center and center:IsA("BasePart") then
			player.Character:PivotTo(CFrame.new(center.Position + Vector3.new(0, 4, 2)))
		end
	end,
	Solo = function()
		ArenaMatchService.debugSolo()
	end,
	Format = function()
		local format = ArenaMatchService.debugNextFormat()
		Remotes.Notify:FireAllClients(`👥 Formato {format}v{format}`)
	end,
	SkipPhase = function()
		ArenaMatchService.debugSkipPhase()
	end,
	Abilities = function(player)
		for slot = 1, 5 do
			player:SetAttribute(`AbilityReadyAt{slot}`, nil)
		end
	end,
	Heal = function(player)
		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end,
	Dummy = toggleDummy,
	-- Todas las armaduras de cada rol, con su arma del mismo nivel, en copias del personaje.
	GearShowcase = GearShowcase.toggle,
	-- Mejor equipo guardado del rol al grado siguiente (0–4), para ver cómo se luce.
	BestGear = function(player)
		local grade = CosmeticsServer.debugNextBestGear(player)
		Remotes.Notify:FireClient(
			player,
			if grade > 0 then `🛡️ Equipo lucido: nivel {grade}` else "🛡️ Equipo lucido: ninguno"
		)
	end,
	Amber = function(player)
		PlayerData.update(player, function(profile)
			profile.amber += 500
		end)
	end,
}

function ArenaDebugService:Start()
	if not RunService:IsStudio() then
		return
	end
	Remotes.DebugCommand.OnServerEvent:Connect(function(player: Player, command: any, arg: any)
		if command == "FakeKill" then
			Killfeed.fake(player, arg)
			return
		end
		local handler = if typeof(command) == "string" then COMMANDS[command] else nil
		if handler then
			handler(player, arg)
		end
	end)
	print("[ArenaDebugService] Panel de pruebas activo (solo Studio).")
end

return ArenaDebugService
