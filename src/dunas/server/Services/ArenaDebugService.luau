--!strict
-- Panel de pruebas de la arena (solo Studio; Shared/DebugCommands.Dunas). En Studio no llega nadie
-- del Lobby: con "Empezar ya" la partida arranca con un solo equipo y no cuenta para nada.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local ArenaModes = require(ReplicatedStorage.Shared.ArenaModes)
local Ballgame = require(ReplicatedStorage.Shared.Data.Ballgame)
local Config = require(ReplicatedStorage.Shared.Config)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Killfeed = require(ServerScriptService.Combat.Killfeed)
local CosmeticsServer = require(ServerScriptService.ServerShared.CosmeticsServer)
local GearShowcase = require(ServerScriptService.ServerShared.GearShowcase)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local ArenaMatchService = require(script.Parent.ArenaMatchService)
local ArenaWorldService = require(script.Parent.ArenaWorldService)
local BallBotService = require(script.Parent.BallBotService)
local BallHitService = require(script.Parent.BallHitService)
local BallService = require(script.Parent.BallService)
local BallgameMode = require(script.Parent.Parent.Modes.Ballgame)

local DUMMY_HEALTH = 300
-- BallRing: la pelota sale de aquí (x local, y) hacia el centro del aro, con esta velocidad en X.
local RING_SHOT_X = -12
-- Por encima del talud (en z = centerZ su superficie está a y ≈ 13,9): si saliera de dentro, BallSim la empujaría
-- fuera y la dejaría a más de 2,2 del centro del aro, que es lo que roza la piedra.
local RING_SHOT_Y = 18
local RING_SHOT_SPEED = 40
-- BallPlace «center»: altura (local) a la que se deja la pelota en el centro.
local CENTER_PLACE_HEIGHT = 2
-- Cinemática del Juego de pelota (Fase 25, G9a): el formato (jugadores por equipo) de la cancha en que se graba.
local CINE_FORMAT = 3

local ArenaDebugService = {}

local dummy: Model? = nil
local cineCounter = 0

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
	local gravity, airDrag = Ballgame.Gravity, Ballgame.AirDrag
	-- Altura del centro al cruzar x = 0 (mismas cuentas que BallSim: gravedad y arrastre lineal), según la vertical.
	local function heightAtRing(vy0: number): number
		local step = 1 / 240
		local drag = 1 - airDrag * step
		local x, y, vx, vy = RING_SHOT_X, RING_SHOT_Y, RING_SHOT_SPEED, vy0
		while x < 0 do
			vy = (vy - gravity * step) * drag
			vx *= drag
			x += vx * step
			y += vy * step
		end
		return y
	end
	-- Bisección: la vertical para que el centro llegue a la altura del aro.
	local low, high = 0, 120
	for _ = 1, 40 do
		local mid = (low + high) / 2
		if heightAtRing(mid) < ring.centerY then
			low = mid
		else
			high = mid
		end
	end
	local vy = (low + high) / 2
	BallService.setActive(true)
	BallService.place(Vector3.new(RING_SHOT_X, RING_SHOT_Y, zSign * ring.centerZ), Vector3.new(RING_SHOT_SPEED, vy, 0))
end

-- Equipo del jugador (Jaguar si no tiene).
local function teamOfPlayer(player: Player): string
	return Arena.teamOf(player) or "Jaguar"
end

-- Los equipos que acepta un argumento de texto ("Jaguar" o "Quetzal"), o nil.
local function teamArg(arg: any): string?
	return if arg == "Jaguar" or arg == "Quetzal" then arg else nil
end

-- BallPlace con un atajo: en el campo del jugador («mine»), en el del rival («rival») o al centro («center»).
-- Devuelve el punto local, o nil si "arg" no es un atajo.
local function presetPlace(player: Player, arg: any): Vector3?
	local halfLength = BallService.layout().halfLength
	local resting = CourtGeometry.BALL_RADIUS + Ballgame.Serve.RestClearance
	if arg == "mine" then
		return Vector3.new(CourtGeometry.sideSign(teamOfPlayer(player)) * halfLength / 2, resting, 0)
	elseif arg == "rival" then
		return Vector3.new(-CourtGeometry.sideSign(teamOfPlayer(player)) * halfLength / 2, resting, 0)
	elseif arg == "center" then
		return Vector3.new(0, CENTER_PLACE_HEIGHT, 0)
	end
	return nil
end

local COMMANDS: { [string]: (player: Player, arg: any) -> () } = {
	-- La pelota del Juego de pelota (Fase 26c).
	BallOn = function()
		BallService.setActive(true)
		if BallService.state().dead then
			BallService.place(Vector3.new(0, Ballgame.Serve.Height, 0))
		end
	end,
	BallOff = function()
		BallService.setActive(false)
	end,
	-- «Jaguar» o «Quetzal»: el lob va al campo de ese equipo; sin argumento, al azar.
	BallServe = function(_player, arg)
		BallService.setActive(true)
		BallService.serve(teamArg(arg))
	end,
	-- «mine», «rival» o «center» (atajos), o "x y z vx vy vz" en coordenadas locales de la cancha (la velocidad es
	-- opcional).
	BallPlace = function(player, arg)
		local preset = presetPlace(player, arg)
		if preset then
			BallService.setActive(true)
			BallService.place(preset, Vector3.zero)
			BallgameMode.debugHold() -- con el saque lento, espera quieta al primer golpe
			return
		end
		local n = numbersOf(arg)
		if #n < 3 then
			return
		end
		BallService.setActive(true)
		BallService.place(Vector3.new(n[1], n[2], n[3]), Vector3.new(n[4] or 0, n[5] or 0, n[6] or 0))
	end,
	-- Lado del aro (-1 o 1); sin argumento, alterna.
	BallRing = function(player, arg)
		-- El panel manda el lado como texto ("-1" o "1").
		local side = if typeof(arg) == "string" then tonumber(arg) else arg
		local zSign = if side == -1 or side == 1 then side else nextRingSide
		nextRingSide = -zSign
		shootAtRing(zSign)
		BallgameMode.debugToucher(teamOfPlayer(player)) -- sin esto la embocada no cuenta ni hay repetición
	end,
	-- Golpe forzado (Fase 26d): "zona calidad" (Foot, Knee, Hip, Elbow / Perfect, Good, Weak, Passive); por defecto
	-- Hip Perfect, hacia donde mira el jugador. Se salta distancia, mitad y enfriamientos.
	BallHit = function(player, arg)
		local zone, quality = "Hip", "Perfect"
		if typeof(arg) == "string" then
			local words = string.split(arg, " ")
			if words[1] and words[1] ~= "" then
				zone = words[1]
			end
			if words[2] and words[2] ~= "" then
				quality = words[2]
			end
		end
		local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
		if not (root and root:IsA("BasePart")) or not (zone == "Foot" or Ballgame.Hit.Pitch[zone]) then
			return
		end
		if quality ~= "Passive" and not Ballgame.Hit.Speed[zone == "Foot" and "Hip" or zone][quality] then
			return
		end
		BallHitService.force(player, zone, quality, root.CFrame.LookVector)
	end,
	-- Juego de pelota (26e): "equipo [aviso]" da la raya a ese equipo (aviso por defecto "Debug").
	BallScore = function(_player, arg)
		local words = if typeof(arg) == "string" then string.split(arg, " ") else {}
		local team = words[1]
		if team ~= "Jaguar" and team ~= "Quetzal" then
			return
		end
		local call = if words[2] and words[2] ~= "" then words[2] else "Debug"
		BallgameMode.debugPoint(team, call)
	end,
	BallState = function()
		print(`[ArenaDebugService] {BallgameMode.debugState()}`)
	end,
	-- Saque lento (Fase 27b): «on», «off» o, sin argumento, alterna.
	SlowServe = function(player, arg)
		local enabled = if arg == "on" then true elseif arg == "off" then false else not BallgameMode.debugIsSlowServe()
		BallgameMode.debugSlowServe(enabled)
		Remotes.Notify:FireClient(player, `🏀 Saque lento: {if enabled then "sí" else "no"}`)
	end,
	-- Rivales de prueba (BallBotService): «1», «3», «5» u «off»; van en el campo CONTRARIO al del jugador.
	BotRivals = function(player, arg)
		local count = if arg == "off" then 0 else tonumber(arg) or 0
		BallBotService.setRivals(Arena.otherTeam(teamOfPlayer(player)), count)
	end,
	-- Cambia de modo («Ballgame» o «CaptureFlag») y vuelve a la espera (ArenaMatchService.debugSetMode).
	Mode = function(player, arg)
		if typeof(arg) == "string" and ArenaMatchService.debugSetMode(arg) then
			Remotes.Notify:FireClient(player, `🎮 Modo: {Config.Arena.ModeNames[arg]}`)
		end
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
	-- Cinemática del Juego de pelota (Fase 25, G9a): pone el modo Juego de pelota y el formato 3 si hace falta, aparta los
	-- rivales de prueba y apaga la pelota; BallgameCineController (cliente) espera a la cancha y lanza la escena.
	CineBallgame = function(player)
		if ArenaModes.current() ~= "Ballgame" then
			ArenaMatchService.debugSetMode("Ballgame")
		end
		for _ = 1, Config.Arena.MaxFormat do
			if Arena.format() == CINE_FORMAT then
				break
			end
			ArenaMatchService.debugNextFormat()
		end
		BallBotService.clear()
		BallService.setActive(false)
		cineCounter += 1
		player:SetAttribute("BallgameCine", `Ballgame:{cineCounter}`)
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
