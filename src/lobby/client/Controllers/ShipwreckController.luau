--!strict
-- Cinemática de bienvenida «Shipwreck» (Fase 25, G6a), en el Lobby. Decide el cliente y el servidor solo marca:
--   - Cuando el perfil ya cargó (atributo Progress del Player) y la escena no está en cinematicsSeen, con el ajuste
--     «Cinemáticas» activo, pone la tarjeta de espera del logo (para no ver el Lobby), espera a que el mundo tenga el
--     carguero (Workspace.Naufragio.Esperanza) y al personaje, pone la noche y lanza la escena con playLocal.
--   - Si la escena se ve ENTERA, avisa con Remotes.CinematicDone("Shipwreck", true) y ShipwreckService la marca. Si el
--     jugador sale a mitad no se marca y la verá otra vez. La escena no se puede saltar (noSkip).
--   - La orden de depuración «🚢 Naufragio» sube el atributo ShipwreckReplay del Player: la repite aunque ya la haya visto
--     y sin marcar nada.
-- Mientras suena: HUD oculto, controles apagados y mascotas ocultas (CinematicClient); el personaje real se queda donde está.
-- Los eventos de la escena (shipSail, shipAvatar, birds, night) los registra ShipwreckSet.install.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CinematicClient = require(ReplicatedStorage.Shared.Cinematics.CinematicClient)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sequencer = require(ReplicatedStorage.Shared.Cinematics.Sequencer)
local Settings = require(ReplicatedStorage.Shared.Settings)
local ShipwreckSet = require(ReplicatedStorage.Shared.Cinematics.ShipwreckSet)

local SCENE_ID = "Shipwreck"
local REPLAY_ATTRIBUTE = "ShipwreckReplay"
local PROGRESS_WAIT_SECONDS = 30 -- espera al perfil
local WORLD_WAIT_SECONDS = 10 -- espera al carguero y al personaje
local POLL_SECONDS = 0.2

local ShipwreckController = {}

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

local function worldReady(): boolean
	local folder = Workspace:FindFirstChild("Naufragio")
	return folder ~= nil and folder:FindFirstChild("Esperanza") ~= nil
end

local function characterReady(): boolean
	local character = Players.LocalPlayer.Character
	return character ~= nil
		and character:FindFirstChild("HumanoidRootPart") ~= nil
		and character:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Lanza la escena. "replay" = repetición de depuración: no avisa al servidor al acabar.
local function play(replay: boolean)
	if running then
		return
	end
	running = true
	CinematicClient.holdScreen()
	if not (waitUntil(worldReady, WORLD_WAIT_SECONDS) and waitUntil(characterReady, WORLD_WAIT_SECONDS)) then
		CinematicClient.releaseHold(0.3)
		running = false
		return
	end
	-- La noche se pone con la tarjeta delante: el cambio de luz no se ve. La escena la devuelve al acabar.
	ShipwreckSet.applyNight(0)
	local started = CinematicClient.playLocal(SCENE_ID, {
		anchor = CFrame.identity,
		onFinished = function(completed: boolean)
			running = false
			if completed and not replay then
				Remotes.CinematicDone:FireServer(SCENE_ID, true)
			end
		end,
	})
	if not started then
		ShipwreckSet.restoreNight(0)
		CinematicClient.releaseHold(0.3)
		running = false
	end
end

function ShipwreckController:Start()
	ShipwreckSet.install(Sequencer)
	local player = Players.LocalPlayer

	player:GetAttributeChangedSignal(REPLAY_ATTRIBUTE):Connect(function()
		if player:GetAttribute(REPLAY_ATTRIBUTE) ~= nil then
			task.spawn(play, true)
		end
	end)

	-- Primera vez: solo con el perfil cargado (Progress existe) y sin haberla visto.
	local loaded = waitUntil(function()
		return typeof(player:GetAttribute("Progress")) == "string"
	end, PROGRESS_WAIT_SECONDS)
	if not loaded or CinematicClient.hasSeen(SCENE_ID) or not Settings.get().cinematics then
		return
	end
	play(false)
end

return ShipwreckController
