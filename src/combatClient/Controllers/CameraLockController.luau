--!strict
-- Bloqueo de cámara (el "shift lock"; Fase 10, C2; propio del juego desde la calibración de la mira) en Ctrl:
-- Mayús ya es correr. Ctrl lo enciende y lo apaga (CombatClient/CameraLock guarda el estado) y
-- ShoulderAimController lo aplica: ratón al centro, personaje de cara a la mira y cámara al hombro. Ayuda a
-- apuntar el tajo y a encarar la guardia (C5), que solo cubre de frente. No usa el bloqueo de Roblox (los places
-- llevan StarterPlayer.EnableMouseLockOption en false): ese depende de un ajuste del jugador que en Studio está
-- apagado y su estado no se puede leer del PlayerModule actual.
-- Con ViewMode.get() == "First" (Fase 24: modo shooter del campo de tiro y Laboratorio) el bloqueo se apaga y Ctrl
-- pasa a ser del cursor de FirstPersonController.

local UserInputService = game:GetService("UserInputService")

local CameraLock = require(script.Parent.Parent.CameraLock)
local ViewMode = require(script.Parent.Parent.ViewMode)

local TOGGLE_KEYS = { [Enum.KeyCode.LeftControl] = true, [Enum.KeyCode.RightControl] = true }
-- La mirilla que usa Roblox con su bloqueo de cámara.
local LOCKED_CURSOR = "rbxasset://textures/MouseLockedCursor.png"

local CameraLockController = {}

function CameraLockController:Start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not TOGGLE_KEYS[input.KeyCode] or ViewMode.get() == "First" then
			return
		end
		CameraLock.toggle()
	end)
	CameraLock.changed:Connect(function(locked: boolean)
		UserInputService.MouseIcon = if locked then LOCKED_CURSOR else ""
	end)
	ViewMode.onChanged(function(mode)
		if mode == "First" then
			CameraLock.set(false)
		end
	end)
end

return CameraLockController
