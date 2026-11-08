--!strict
-- Cinemática del Juego de pelota (Fase 25, G9a), solo para grabar. La orden de depuración «🎬 Juego de pelota (cinemática)» del panel de
-- Dunas (ArenaDebugService) sube el atributo BallgameCine del Player con "<id de la escena>:<contador>"; este controlador
-- la lanza como escena local (CinematicClient.playLocal) anclada al centro de la cancha. Mientras suena:
--   - Lighting.ClockTime = 17,5 (atardecer): en Dunas no hay ciclo de día ni LightingController que lea el evento
--     `hour`/`clock`, así que la hora se pone aquí, en el cliente, y se devuelve al acabar.
--   - la pelota real (BallController) se esconde: la escena dibuja la suya (Cinematics/BallActor).
--   - el personaje se lleva a la cancha y se ancla hasta que acaba (la escena lo coloca y lo mueve con `move`); al
--     acabar vuelve a donde estaba. Hay que esperar a que la cancha (el formato de la orden) esté dibujada.
-- Los eventos de la escena (ballPath, animSpeed) los registra CinematicClient.start (CinematicController).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local CinematicClient = require(ReplicatedStorage.Shared.Cinematics.CinematicClient)
local CourtGeometry = require(ReplicatedStorage.Shared.CourtGeometry)
local BallController = require(script.Parent.BallController)

local ATTRIBUTE = "BallgameCine"
local SCENES: { [string]: boolean } = { Ballgame = true, Ballgame_Reel = true, Ballgame_Comic = true }
local CLOCK_TIME = 17.5
local COURT_FORMAT = 3 -- el formato (jugadores por equipo) con el que se calibró la escena
local COURT_WAIT_SECONDS = 8 -- espera a la cancha del formato y a su suelo
local POLL_SECONDS = 0.2
local FLOOR_RAY_UP = 20
local FLOOR_RAY_DOWN = 40

local BallgameCineController = {}

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

local function play(id: string)
	if running then
		return
	end
	running = true
	local savedClock = Lighting.ClockTime
	local character = Players.LocalPlayer.Character
	local savedPivot = if character then character:GetPivot() else nil
	local part = root()
	local wasAnchored = if part then part.Anchored else false

	local function restore()
		Lighting.ClockTime = savedClock
		BallController.setHiddenByScene(false)
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

	Lighting.ClockTime = CLOCK_TIME
	BallController.setHiddenByScene(true)
	-- El personaje, a la cancha y quieto: la escena lo coloca en cuanto empieza.
	if part and character then
		part.Anchored = true
		character:PivotTo(CFrame.new(CourtGeometry.CENTER + Vector3.new(0, 6, 0)))
	end
	if not waitUntil(courtReady, COURT_WAIT_SECONDS) then
		warn("[BallgameCineController] la cancha del formato 3 no está lista; se cancela la escena")
		restore()
		return
	end
	local started = CinematicClient.playLocal(id, {
		anchor = CFrame.new(CourtGeometry.CENTER),
		onFinished = restore,
	})
	if not started then
		restore()
	end
end

function BallgameCineController:Start()
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		local id = sceneOf(player:GetAttribute(ATTRIBUTE))
		if id and SCENES[id] then
			task.spawn(play, id)
		end
	end)
end

return BallgameCineController
