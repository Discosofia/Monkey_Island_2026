--!strict
-- Resultados de la partida (Remotes.ArenaResults, de LabMatchService): la ventana es la de
-- Shared/UI/MatchResults (sin capturas ni altares, con el Ámbar y la XP del pase de LabRewardService). Con
-- ella abierta el ratón va suelto (FirstPersonController.freeCursor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchResults = require(ReplicatedStorage.Shared.UI.MatchResults)
local FirstPersonController = require(script.Parent.FirstPersonController)

local LabResultsController = {}

function LabResultsController:Start()
	MatchResults.start({
		onToggle = function(open: boolean)
			FirstPersonController.freeCursor("Results", open)
		end,
	})
end

return LabResultsController
