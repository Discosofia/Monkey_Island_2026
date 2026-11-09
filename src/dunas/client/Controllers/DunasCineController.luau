--!strict
-- Cinemáticas de Dunas (Fase 25, G9 y G10), solo para grabar. Las órdenes de depuración «🎬 …» del panel de Dunas
-- (ArenaDebugService) suben un atributo del Player con "<id de la escena>:<contador>"; este controlador lanza la escena local
-- (CinematicClient.playLocal) y lo devuelve todo al acabar:
--   BallgameCine  Ballgame, Ballgame_Reel y Ballgame_Comic (el 3 contra 3). Anclada al centro de la cancha. Mientras suena:
--       la pelota real (BallController) se esconde (la escena dibuja la suya, Cinematics/BallActor) y el personaje se lleva a
--       la cancha. Hay que esperar a que la cancha (el formato de la orden) esté dibujada.
--   DunasCine     Flag y Flag_Comic (Captura la bandera 5 contra 5). Anclada al origen del mundo: espera a que existan la arena
--       y las banderas (Workspace.Arena y Workspace.Banderas) y deja el personaje sobre la pirámide.
-- En los dos casos Lighting.ClockTime se pone a la hora de la escena (en Dunas no hay ciclo de día ni LightingController que
-- lea el evento `hour`/`clock`) y el personaje se ancla hasta que acaba; al acabar vuelve a donde estaba.
-- Los eventos de la escena (ballPath, animSpeed, flagProp…) los registra CinematicClient.start (CinematicController).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local CinematicClient = require(ReplicatedStorage.Shared.Cinematics.CinematicClient)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local BallController = require(script.Parent.BallController)

local BALLGAME_ATTRIBUTE = "BallgameCine"
local DUNAS_ATTRIBUTE = "DunasCine"
local BALLGAME_SCENES: { [string]: boolean } = { Ballgame = true, Ballgame_Reel = true, Ballgame_Comic = true }
local FLAG_SCENES: { [string]: boolean } = { Flag = true, Flag_Comic = true }
local BALLGAME_CLOCK_TIME = 17.5
local FLAG_CLOCK_TIME = 16.5 -- la misma que FLAG_HOUR de Data/Cinematics
local COURT_FORMAT = 3 -- el formato (jugadores por equipo) con el que se calibró la escena del juego de pelota
local WAIT_SECONDS = 8 -- espera a la cancha del formato y a su suelo, o a la arena y las banderas
local POLL_SECONDS = 0.2
local FLOOR_RAY_UP = 20
local FLOOR_RAY_DOWN = 40
local FLAG_PARK = Vector3.new(0, 30, 0) -- el personaje espera sobre la pirámide (16 de alto): la escena lo coloca al empezar
local ARENA_FOLDER = "Arena"
local FLAGS_FOLDER = "Banderas"

local DunasCineController = {}

local running = false

local function waitUntil(condition: () -> boolean, seconds: number): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if condition() then
			return true
		end
		task.wait(POLL_SECONDS)
	end
	return condition()
end

-- ¿La cancha del formato está dibujada? Un rayo al centro encuentra su suelo.
local function courtReady(): boolean
	if Arena.format() ~= COURT_FORMAT then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer.Character
	params.FilterDescendantsInstances = if character then { character } else {}
	local origin = CourtGeometry.CENTER + Vector3.new(0, FLOOR_RAY_UP, 0)
	return Workspace:Raycast(origin, Vector3.new(0, -FLOOR_RAY_DOWN, 0), params) ~= nil
end

-- ¿Están la arena y las dos banderas? (FlagService las crea al arrancar; el mundo de la arena, ArenaBuilder.)
local function flagArenaReady(): boolean
	local banderas = Workspace:FindFirstChild(FLAGS_FOLDER)
	return Workspace:FindFirstChild(ARENA_FOLDER) ~= nil
		and banderas ~= nil
		and #banderas:GetChildren() >= #Arena.TEAM_IDS
end

local function root(): BasePart?
	local character = Players.LocalPlayer.Character
	local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if part and part:IsA("BasePart") then part else nil
end

-- "Ballgame:3" -> "Ballgame".
local function sceneOf(value: any): string?
	if typeof(value) ~= "string" then
		return nil
	end
	local id = string.match(value, "^([^:]+)")
	return id
end

-- Una escena: pone la hora, aparca al personaje en `park`, espera a `ready` (hasta WAIT_SECONDS) y la lanza anclada en
-- `anchor`. `hideBall` esconde la pelota real mientras suena. Todo se devuelve al acabar (o si no llega a empezar).
local function play(
	id: string,
	clockTime: number,
	park: Vector3,
	anchor: CFrame,
	ready: () -> boolean,
	hideBall: boolean,
	setup: (() -> () -> ())? -- prepara el mundo para la escena y devuelve cómo dejarlo como estaba
)
	if running then
		return
	end
	running = true
	local savedClock = Lighting.ClockTime
	local character = Players.LocalPlayer.Character
	local savedPivot = if character then character:GetPivot() else nil
	local part = root()
	local wasAnchored = if part then part.Anchored else false

	local undoSetup: (() -> ())? = nil
	local function restore()
		Lighting.ClockTime = savedClock
		if undoSetup then
			undoSetup()
			undoSetup = nil
		end
		if hideBall then
			BallController.setHiddenByScene(false)
		end
		local current = root()
		if current then
			current.Anchored = wasAnchored
		end
		local now = Players.LocalPlayer.Character
		if now and savedPivot then
			now:PivotTo(savedPivot)
		end
		running = false
	end

	Lighting.ClockTime = clockTime
	if hideBall then
		BallController.setHiddenByScene(true)
	end
	-- El personaje, al sitio de la escena y quieto: la escena lo coloca en cuanto empieza.
	if part and character then
		part.Anchored = true
		character:PivotTo(CFrame.new(park))
	end
	if not waitUntil(ready, WAIT_SECONDS) then
		warn(`[DunasCineController] {id}: la arena no está lista; se cancela la escena`)
		restore()
		return
	end
	if setup then
		undoSetup = setup() -- ya existe la arena
	end
	local started = CinematicClient.playLocal(id, {
		anchor = anchor,
		onFinished = restore,
	})
	if not started then
		restore()
	end
end

local function playBallgame(id: string)
	play(
		id,
		BALLGAME_CLOCK_TIME,
		CourtGeometry.CENTER + Vector3.new(0, 6, 0),
		CFrame.new(CourtGeometry.CENTER),
		courtReady,
		true,
		nil
	)
end

-- Las puertas de las bases (Bases.*.Gate) están cerradas fuera de partida (ForceField que tapa la cámara en x = ±150) y la
-- escena corre con ellas abiertas: solo en este cliente se esconden (LocalTransparencyModifier) y se devuelven al acabar. La
-- colisión no importa: los actores van por CFrame.
local function hideGates(): () -> ()
	local hidden: { BasePart } = {}
	local arena = Workspace:FindFirstChild(ARENA_FOLDER)
	local bases = if arena then arena:FindFirstChild("Bases") else nil
	if bases then
		for _, base in bases:GetChildren() do
			local gate = base:FindFirstChild("Gate")
			if gate and gate:IsA("BasePart") then
				gate.LocalTransparencyModifier = 1
				table.insert(hidden, gate)
			end
		end
	end
	return function()
		for _, gate in hidden do
			gate.LocalTransparencyModifier = 0
		end
	end
end

local function playFlag(id: string)
	-- La pelota real no se esconde: en Captura la bandera no hay pelota.
	play(id, FLAG_CLOCK_TIME, FLAG_PARK, CFrame.identity, flagArenaReady, false, hideGates)
end

function DunasCineController:Start()
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal(BALLGAME_ATTRIBUTE):Connect(function()
		local id = sceneOf(player:GetAttribute(BALLGAME_ATTRIBUTE))
		if id and BALLGAME_SCENES[id] then
			task.spawn(playBallgame, id)
		end
	end)
	player:GetAttributeChangedSignal(DUNAS_ATTRIBUTE):Connect(function()
		local id = sceneOf(player:GetAttribute(DUNAS_ATTRIBUTE))
		if id and BALLGAME_SCENES[id] then
			task.spawn(playBallgame, id)
		elseif id and FLAG_SCENES[id] then
			task.spawn(playFlag, id)
		end
	end)
end

return DunasCineController
