--!strict
-- Reglas de construcción compartidas por el cliente (vista previa) y el servidor (validación):
-- cuadrícula, giro, parcelas, zonas permitidas y si algo estorba.
--
-- El Basecamp se divide en:
--   - Núcleo compartido: un círculo de Config.Building.CoreRadius alrededor del centro.
--   - Parcelas personales: Config.Building.PlotCount cuadrados en un anillo, dejando libres los
--     caminos de los 4 portones. Cada jugador recibe una al entrar (atributo "PlotIndex").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local Building = {}

Building.STRUCTURES_FOLDER = "Estructuras"
-- Atributo de ReplicatedStorage con el centro del Basecamp (lo escribe BuildingService).
Building.CENTER_ATTRIBUTE = "BasecampCenter"
-- Atributo del Player con el número de su parcela.
Building.PLOT_ATTRIBUTE = "PlotIndex"

export type Zone = "Core" | "Plot"

-- Centro del Basecamp a ras de suelo, o nil si el servidor aún no lo ha publicado.
function Building.center(): Vector3?
	local value = ReplicatedStorage:GetAttribute(Building.CENTER_ATTRIBUTE)
	return if typeof(value) == "Vector3" then value else nil
end

-- Parcelas: CFrames en el suelo, mirando hacia el centro. Siempre salen en el mismo orden.
function Building.plots(center: Vector3): { CFrame }
	local settings = Config.Building
	local perQuadrant = math.max(1, settings.PlotCount // 4)
	local gap = math.rad(settings.GateGapDegrees)
	local plots = {}
	for quadrant = 0, 3 do
		local first = quadrant * math.pi / 2 + gap
		local last = (quadrant + 1) * math.pi / 2 - gap
		for i = 0, perQuadrant - 1 do
			local t = if perQuadrant == 1 then 0.5 else i / (perQuadrant - 1)
			local angle = first + (last - first) * t
			local position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * settings.PlotRingRadius
			table.insert(plots, CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z)))
		end
	end
	return plots
end

-- Encaja un punto en la cuadrícula y devuelve el CFrame de la pieza apoyada en "groundY".
function Building.placement(point: Vector3, groundY: number, rotation: number, size: Vector3): CFrame
	local grid = Config.Building.GridSize
	local x = math.round(point.X / grid) * grid
	local z = math.round(point.Z / grid) * grid
	return CFrame.new(x, groundY + size.Y / 2, z) * CFrame.Angles(0, rotation * math.pi / 2, 0)
end

local function corners(cframe: CFrame, size: Vector3): { Vector3 }
	local result = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(result, (cframe * CFrame.new(sx * size.X / 2, 0, sz * size.Z / 2)).Position)
		end
	end
	return result
end

-- Zona en la que cae la pieza entera, o nil si se sale (o está en la parcela de otro).
function Building.zoneFor(cframe: CFrame, size: Vector3, plotIndex: number?, center: Vector3): Zone?
	local footprint = corners(cframe, size)
	local inCore = true
	for _, corner in footprint do
		local offset = (corner - center) * Vector3.new(1, 0, 1)
		if offset.Magnitude > Config.Building.CoreRadius then
			inCore = false
			break
		end
	end
	if inCore then
		return "Core"
	end

	local plot = if plotIndex then Building.plots(center)[plotIndex] else nil
	if not plot then
		return nil
	end
	local half = Config.Building.PlotSize / 2
	for _, corner in footprint do
		local localCorner = plot:PointToObjectSpace(Vector3.new(corner.X, plot.Position.Y, corner.Z))
		if math.abs(localCorner.X) > half or math.abs(localCorner.Z) > half then
			return nil
		end
	end
	return "Plot"
end

-- Suelo bajo (x, z), ignorando "ignore" (personajes, estructuras, la vista previa). nil si no hay.
function Building.groundAt(x: number, z: number, fromY: number, ignore: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local result = Workspace:Raycast(Vector3.new(x, fromY + 30, z), Vector3.new(0, -120, 0), params)
	return if result then result.Position.Y else nil
end

-- true si algo (otra pieza, un banco, un jugador…) ocupa el sitio. El terreno no cuenta.
function Building.isBlocked(cframe: CFrame, size: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(ignore)
	table.insert(list, Workspace.Terrain)
	params.FilterDescendantsInstances = list
	local shrink = Config.Building.OverlapShrink
	local box =
		Vector3.new(math.max(0.1, size.X - shrink), math.max(0.1, size.Y - shrink), math.max(0.1, size.Z - shrink))
	return #Workspace:GetPartBoundsInBox(cframe, box, params) > 0
end

return Building
