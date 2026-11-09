--!strict
-- Cinemáticas del Laboratorio (Fase 25, G12), solo para grabar y probar. Las órdenes de depuración «🎬 …» del panel del
-- Laboratorio (LabDebugService) suben el atributo LabCine del Player con "<id de la escena>:<contador>"; este controlador
-- lanza la escena local (CinematicClient.playLocal) y lo devuelve todo al acabar. Las escenas están en LAB_SCENES (lista
-- blanca): el mapa donde se ruedan, el punto del mapa donde se ancla y dónde espera el personaje.
--   - Espera a que el mapa de la escena esté construido (Workspace.LabMap).
--   - Aparca el personaje quieto (anclado) fuera de plano, suelta el ratón (FirstPersonController.freeCursor: el botón
--     «Saltar» se pulsa) y lo devuelve todo al acabar: sitio, anclaje, ratón, la luz del mapa de la partida y la cámara en
--     primera persona (LockFirstPerson).
--   - La hora y la luz las pone la propia escena (labLight, Cinematics/LabActor); el motor no toca ClockTime.
-- Los eventos (labShot, labLight, fpView…) los registra CinematicClient.start (CinematicController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CinematicClient = require(ReplicatedStorage.Shared.Cinematics.CinematicClient)
local LabActor = require(ReplicatedStorage.Shared.Cinematics.LabActor)
local FirstPersonController = require(ReplicatedStorage.CombatClient.Controllers.FirstPersonController)
local ViewMode = require(ReplicatedStorage.CombatClient.ViewMode)

local ATTRIBUTE = "LabCine"
local CURSOR_REASON = "Cinematic"
local ACTIVE_ATTRIBUTE = "CinematicActive"
local MAP_FOLDER = "LabMap"
local WAIT_SECONDS = 8
local POLL_SECONDS = 0.2

-- Dónde empieza cada mapa en el mundo (las mismas posiciones que OFFSETS de LabBuilder, en el servidor).
local MAP_ORIGINS: { [string]: Vector3 } = {
	Central = Vector3.zero,
	Azotea = Vector3.new(2000, 160, 0),
	Alcantarillas = Vector3.new(-2000, 0, 0),
}

-- Escena → mapa, punto del ancla (en coordenadas del mapa) y sitio donde espera el personaje (idem).
type SceneInfo = { map: string, anchor: Vector3, park: Vector3 }
local LAB_SCENES: { [string]: SceneInfo } = {
	-- Explanada este del Central (x 47, entre las cajas de x 40 y x 57); el personaje espera en la sala del reactor oeste.
	LabEngine = { map = "Central", anchor = Vector3.new(47, 0, 0), park = Vector3.new(-30, 3, 4) },
}

local LabCineController = {}

local running = false

-- "LabEngine:3" -> "LabEngine".
local function sceneOf(value: any): string?
	if typeof(value) ~= "string" then
		return nil
	end
	return string.match(value, "^([^:]+)")
end

local function root(): BasePart?
	local character = Players.LocalPlayer.Character
	local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if part and part:IsA("BasePart") then part else nil
end

local function mapReady(mapId: string): boolean
	local folder = Workspace:FindFirstChild(MAP_FOLDER)
	return folder ~= nil and folder:FindFirstChild(mapId) ~= nil
end

local function play(id: string, info: SceneInfo)
	if running then
		return
	end
	running = true
	local deadline = os.clock() + WAIT_SECONDS
	while not mapReady(info.map) and os.clock() < deadline do
		task.wait(POLL_SECONDS)
	end
	if not mapReady(info.map) then
		warn(`[LabCineController] {id}: el mapa {info.map} no está construido; se cancela la escena`)
		running = false
		return
	end

	local origin = MAP_ORIGINS[info.map] or Vector3.zero
	local character = Players.LocalPlayer.Character
	local savedPivot = if character then character:GetPivot() else nil
	local part = root()
	local wasAnchored = if part then part.Anchored else false

	local player = Players.LocalPlayer
	local function restore()
		-- La vista del jugador vuelve a montarse con su arma (FirstPersonController escucha este atributo).
		player:SetAttribute(ACTIVE_ATTRIBUTE, nil)
		FirstPersonController.freeCursor(CURSOR_REASON, false)
		-- La luz de la escena se quita aunque no llegara a haber labLight (LabActor ya lo hace al acabar, esto es la red).
		LabActor.restoreMapLighting()
		local current = root()
		if current then
			current.Anchored = wasAnchored
		end
		local now = Players.LocalPlayer.Character
		if now and savedPivot then
			now:PivotTo(savedPivot)
		end
		-- Primera persona otra vez: el Sequencer deja la cámara en Custom; ViewMode.set no repite lo ya aplicado.
		if ViewMode.get() == "First" then
			Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
		end
		running = false
	end

	-- Mientras dura la escena la vista propia del jugador está apagada: la cámara es la de la escena y sus brazos
	-- saldrían flotando en los planos en tercera persona.
	player:SetAttribute(ACTIVE_ATTRIBUTE, true)
	FirstPersonController.freeCursor(CURSOR_REASON, true)
	-- El personaje, quieto y fuera de plano mientras dura la escena.
	if part and character then
		part.Anchored = true
		character:PivotTo(CFrame.new(origin + info.park))
	end
	local started = CinematicClient.playLocal(id, {
		anchor = CFrame.new(origin + info.anchor),
		onFinished = restore,
	})
	if not started then
		restore()
	end
end

function LabCineController:Start()
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		local id = sceneOf(player:GetAttribute(ATTRIBUTE))
		local info = if id then LAB_SCENES[id] else nil
		if id and info then
			task.spawn(play, id, info)
		end
	end)
end

return LabCineController
