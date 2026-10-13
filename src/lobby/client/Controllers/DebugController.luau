--!strict
-- Panel de pruebas (solo Studio). Ver Shared/UI/DebugPanel y docs/VERIFICACION.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugPanel = require(ReplicatedStorage.Shared.UI.DebugPanel)

local DebugController = {}

function DebugController:Start()
	DebugPanel.start("Lobby")
end

return DebugController
