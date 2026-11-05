--!strict
-- Estado del bloqueo de cámara del juego (el "shift lock" propio, en Ctrl; CameraLockController lo enciende y lo
-- apaga y ShoulderAimController lo aplica). Sustituye al bloqueo de Roblox, que solo existe si el jugador pone
-- "Shift Lock Switch" en el menú de Roblox (en Studio viene en Classic y el código no puede cambiarlo) y cuyo
-- estado no se puede leer del PlayerModule actual. Con el bloqueo puesto, el ratón queda en el centro, el personaje
-- mira hacia donde mira la cámara y la cámara pasa al hombro (Config.Aim.LockOffset).

local CameraLock = {}

local locked = false
local changedEvent = Instance.new("BindableEvent")

-- Evento que se dispara con el estado nuevo cada vez que cambia.
CameraLock.changed = changedEvent.Event

function CameraLock.isLocked(): boolean
	return locked
end

function CameraLock.set(value: boolean)
	if value == locked then
		return
	end
	locked = value
	changedEvent:Fire(locked)
end

function CameraLock.toggle()
	CameraLock.set(not locked)
end

-- true mientras ShoulderAimController mantiene el ratón al centro (bloqueo de cámara o apuntando). La puntería
-- (CombatClient/Aim) usa el centro de la pantalla en ese caso sin mirar UserInputService.MouseBehavior: la
-- cámara de Roblox lo cambia cada fotograma (LockCurrentPosition con el clic derecho) y entre ese cambio y el
-- paso de ShoulderAimController, GetMouseLocation da la posición real del cursor, que no es el centro.
local centered = false

function CameraLock.setCentered(value: boolean)
	centered = value
end

function CameraLock.isCentered(): boolean
	return centered
end

return CameraLock
