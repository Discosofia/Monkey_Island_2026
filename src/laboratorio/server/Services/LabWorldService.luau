--!strict
-- El escenario del Laboratorio. Mientras no hay mapa (grupo L1; el LabBuilder llega en la L2), monta la
-- sala de pruebas (World/LabTestRoom) al arrancar si no hay ya un "LabMap" en el Workspace, y dice dónde
-- aparece cada uno.

local Workspace = game:GetService("Workspace")

local LabTestRoom = require(script.Parent.Parent.World.LabTestRoom)

local LabWorldService = {}

-- Dónde aparece un jugador: el punto de salida de la sala, un poco al azar para no salir encima de otro.
function LabWorldService.spawnCFrame(): CFrame
	local spot = LabTestRoom.SPAWN + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
	return CFrame.lookAt(spot, spot + LabTestRoom.FACING)
end

function LabWorldService:Init()
	if not Workspace:FindFirstChild("LabMap") and not Workspace:FindFirstChild(LabTestRoom.NAME) then
		LabTestRoom.build()
	end
end

return LabWorldService
