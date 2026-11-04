--!strict
-- Cargador del Laboratorio (Fase 15, V8): envoltorio del módulo compartido Combat/LabMagazine, que también usa el
-- modo shooter del campo de tiro del Lobby (Fase 24b). La regla "takeShot" de LabCombatRules llama aquí.

local ServerScriptService = game:GetService("ServerScriptService")

local LabMagazine = require(ServerScriptService.Combat.LabMagazine)

local LabAmmoService = {}

-- Gasta un disparo de "weapon" (el que lleva "player"): nil si no puede; si puede, la dispersión del tiro.
function LabAmmoService.takeShot(player: Player, weaponId: string, weapon: any, zoomed: boolean): number?
	return LabMagazine.takeShot(player, weaponId, weapon, zoomed)
end

-- Recarga a petición del jugador.
function LabAmmoService.reload(player: Player)
	LabMagazine.reload(player)
end

function LabAmmoService:Start()
	LabMagazine.start()
end

return LabAmmoService
