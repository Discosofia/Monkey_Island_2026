--!strict
-- Geometría de las pantallas de ajuste del campo de tiro (Fase 23, World/RangeBuilder), compartida por
-- RangeScreenService (las marcas) y RangeCalibrationService (el desvío medio de cada arma).

-- El impacto tiene que caer en la cara que se ve: a más de esto por delante del centro de la pieza.
local FACE_DEPTH = 0.3
-- Margen sobre el borde de la pantalla (el rayo toca justo en el canto).
local EDGE_SLACK = 0.05

local RangeScreenMath = {}

-- Dónde cae "position" en la pantalla "instance" (pieza con RangeScreen y un SurfaceGui "Pantalla"): su id y
-- los studs desde el centro hacia la derecha de quien la mira (dx) y hacia arriba (dy). nil si la pieza no es
-- una pantalla o el punto no cae en su cara.
function RangeScreenMath.locate(instance: Instance, position: Vector3): (string?, number, number)
	if not instance:IsA("BasePart") then
		return nil, 0, 0
	end
	local screenId = instance:GetAttribute("RangeScreen")
	local gui = instance:FindFirstChild("Pantalla")
	if not (typeof(screenId) == "string" and gui and gui:IsA("SurfaceGui")) then
		return nil, 0, 0
	end
	-- Ejes de la pantalla vista de frente: "right" es la derecha de quien la mira y arriba, el eje y.
	local normal = instance.CFrame:VectorToWorldSpace(Vector3.FromNormalId(gui.Face))
	local right = (-normal):Cross(Vector3.yAxis)
	if right.Magnitude < 1e-3 then
		return nil, 0, 0
	end
	right = right.Unit
	local relative = position - instance.Position
	local dx = relative:Dot(right)
	local dy = relative.Y
	local width = instance:GetAttribute("ScreenWidth")
	local height = instance:GetAttribute("ScreenHeight")
	if not (typeof(width) == "number" and typeof(height) == "number") then
		return nil, 0, 0
	end
	if
		relative:Dot(normal) < FACE_DEPTH
		or math.abs(dx) > width / 2 + EDGE_SLACK
		or math.abs(dy) > height / 2 + EDGE_SLACK
	then
		return nil, 0, 0
	end
	return screenId, dx, dy
end

return RangeScreenMath
