--!strict
-- Panel de pruebas (solo Studio). Ver Shared/UI/DebugPanel y docs/VERIFICACION.md. Con la lista abierta
-- el ratón va suelto (FirstPersonController.freeCursor); para pulsar "🛠️ Pruebas", Ctrl. Con Ctrl otra vez
-- se cierra y se vuelve a apuntar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugPanel = require(ReplicatedStorage.Shared.UI.DebugPanel)
local FirstPersonController = require(script.Parent.FirstPersonController)

local DebugController = {}

function DebugController:Start()
	local list = DebugPanel.start("Laboratorio")
	if list then
		list:GetPropertyChangedSignal("Visible"):Connect(function()
			FirstPersonController.freeCursor("Debug", list.Visible)
		end)
		FirstPersonController.onLockRequested(function()
			list.Visible = false
		end)
	end
end

return DebugController
