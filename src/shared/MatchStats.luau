--!strict
-- Estadísticas de la partida de cada jugador (Fase 2.7), guardadas como atributos del Player:
-- monos derrotados, aliados reanimados y veces que ha pasado a Espíritu. Las muestra la pantalla
-- de resultados y sirven para calcular el Ámbar.

local MatchStats = {}

MatchStats.KILLS = "Stat_Kills"
MatchStats.REVIVES = "Stat_Revives"
MatchStats.DEATHS = "Stat_Deaths"
MatchStats.BOSSES = "Stat_Bosses" -- jefes en los que participó (Fase 5)
MatchStats.BOUNTIES = "Stat_Bounties" -- recompensas PvP cobradas (Fase 5)
MatchStats.EGGS = "Stat_Eggs" -- huevos rescatados (Fase 5)

function MatchStats.get(player: Player, stat: string): number
	local value = player:GetAttribute(stat)
	return if typeof(value) == "number" then value else 0
end

-- Solo el servidor debe llamarla.
function MatchStats.add(player: Player, stat: string, amount: number?)
	player:SetAttribute(stat, MatchStats.get(player, stat) + (amount or 1))
end

return MatchStats
