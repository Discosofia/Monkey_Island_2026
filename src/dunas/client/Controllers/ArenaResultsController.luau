--!strict
-- Resultados de una partida de la arena (Remotes.ArenaResults, de ArenaRewardService): la ventana es la
-- de Shared/UI/MatchResults, con las capturas, los altares de la pirámide y el Ámbar de Dunas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchResults = require(ReplicatedStorage.Shared.UI.MatchResults)

local ArenaResultsController = {}

function ArenaResultsController:Start()
	MatchResults.start()
end

return ArenaResultsController
