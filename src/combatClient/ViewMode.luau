--!strict
-- Vista de cámara del jugador (Fase 24a): "Third" (tercera persona, zoom libre pero sin entrar en primera
-- persona; Lobby, Isla y Dunas) o "First" (primera persona bloqueada; Laboratorio y modo shooter del campo de
-- tiro). Los controladores de cada vista (FirstPersonController, ShoulderAimController, RangedCrosshairController,
-- CameraLockController) consultan get() y se apagan o encienden con changed. El estado inicial es "Third" y se
-- aplica al primer get/set/init (nunca antes de que exista LocalPlayer).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Mode = "Third" | "First"

local ViewMode = {}

local mode: Mode = "Third"
local applied = false
local changedEvent = Instance.new("BindableEvent")

-- Evento que se dispara con el modo nuevo cada vez que cambia.
ViewMode.changed = changedEvent.Event

-- Pone en el jugador local las propiedades de cámara del modo actual.
local function apply()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	applied = true
	if mode == "First" then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = Config.View.ThirdMinZoom
		player.CameraMaxZoomDistance = Config.View.ThirdMaxZoom
	end
end

-- Aplica el estado inicial ("Third") si aún no se ha aplicado ninguno.
function ViewMode.init()
	if not applied then
		apply()
	end
end

function ViewMode.get(): Mode
	ViewMode.init()
	return mode
end

function ViewMode.set(newMode: Mode)
	if newMode == mode and applied then
		return
	end
	local changed = newMode ~= mode
	mode = newMode
	apply()
	if changed then
		changedEvent:Fire(mode)
	end
end

-- Llama a "callback" con el modo nuevo cada vez que cambia.
function ViewMode.onChanged(callback: (Mode) -> ())
	changedEvent.Event:Connect(callback)
end

return ViewMode
