--!strict
-- Efectos visuales de las habilidades de los roles. El servidor (AbilityService) dice qué efecto y dónde;
-- las estelas, partículas y piezas que se mueven las dibuja cada cliente (AbilityFxController), que así
-- se ven fluidas y no cargan la red. La lista de efectos y sus datos está en AbilityFxController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AbilityFx = {}

-- Para todos los jugadores.
function AbilityFx.all(kind: string, ...: any)
	Remotes.AbilityFx:FireAllClients(kind, ...)
end

-- Para todos menos "player": los movimientos (Embestida, Torbellino, Parpadeo) ya los ha dibujado su
-- propio cliente al momento (RoleController).
function AbilityFx.others(player: Player, kind: string, ...: any)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.AbilityFx:FireClient(other, kind, ...)
		end
	end
end

return AbilityFx
