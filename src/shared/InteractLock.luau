--!strict
-- Bloqueo de los menús de interacción en combate. El servidor marca al jugador cuando hace o recibe daño
-- (CombatService) y, mientras dura (Config.Combat.InteractLockSeconds), el cliente no abre las estaciones,
-- los cofres ni la parcela, para que un golpe de paso junto a la hoguera no tape la pantalla en plena pelea.
-- Reanimar a un compañero no se bloquea. Usa el reloj del servidor, que es el mismo en los dos lados.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local InteractLock = {}

InteractLock.ATTRIBUTE = "CombatUntil"

-- Solo el servidor: el jugador está en combate hasta dentro de InteractLockSeconds.
function InteractLock.mark(player: Player)
	if RunService:IsServer() then
		player:SetAttribute(InteractLock.ATTRIBUTE, Workspace:GetServerTimeNow() + Config.Combat.InteractLockSeconds)
	end
end

function InteractLock.locked(player: Player): boolean
	local untilTime = player:GetAttribute(InteractLock.ATTRIBUTE)
	return typeof(untilTime) == "number" and Workspace:GetServerTimeNow() < untilTime
end

return InteractLock
