-- Vuelca un modelo que está en el place (hecho a mano, de la Caja de herramientas o salido de
-- generate_procedural_model) a texto: un resumen y código Luau con una llamada por pieza, en
-- coordenadas relativas al pivote del modelo. Sirve para inspeccionarlo y para pasarlo al estilo de
-- los constructores del repo. Se manda con execute_luau (datamodel_type = "Edit") cambiando RUTA.
--
-- El código usa una función piece(shape, size, offset, color, material, transparency?) que no
-- existe en el repo: adáptalo al constructor del módulo de destino (newPart, make.block, piece…).

local RUTA = "Workspace._VistaPrevia.Modelo" -- <- cámbiala
local MAX_PIEZAS = 400 -- más que esto es demasiado para un modelo del juego; se corta el volcado

local target = game
for name in string.gmatch(RUTA, "[^%.]+") do
	local child = if target == game then game:GetService(name) else target:FindFirstChild(name)
	assert(child, "No existe " .. name .. " en " .. target:GetFullName())
	target = child
end

local pivot: CFrame = if target:IsA("PVInstance") then (target :: PVInstance):GetPivot() else CFrame.identity

local function num(value: number): string
	local rounded = math.floor(value * 100 + 0.5) / 100
	if rounded == math.floor(rounded) then
		return string.format("%d", rounded)
	end
	return (string.format("%.2f", rounded):gsub("0$", ""))
end

local function vec(value: Vector3): string
	return string.format("Vector3.new(%s, %s, %s)", num(value.X), num(value.Y), num(value.Z))
end

local function frame(value: CFrame): string
	local position = "CFrame.new(" .. num(value.X) .. ", " .. num(value.Y) .. ", " .. num(value.Z) .. ")"
	local rx, ry, rz = value:ToOrientation()
	if math.abs(rx) + math.abs(ry) + math.abs(rz) < 1e-3 then
		return position
	end
	return string.format(
		"%s * CFrame.fromOrientation(math.rad(%s), math.rad(%s), math.rad(%s))",
		position,
		num(math.deg(rx)),
		num(math.deg(ry)),
		num(math.deg(rz))
	)
end

local function shapeOf(part: BasePart): string
	if part:IsA("WedgePart") then
		return "Wedge"
	elseif part:IsA("CornerWedgePart") then
		return "CornerWedge"
	elseif part:IsA("MeshPart") then
		return "Mesh:" .. part.MeshId
	elseif part:IsA("UnionOperation") then
		return "Union"
	elseif part:IsA("Part") then
		local mesh = part:FindFirstChildOfClass("SpecialMesh")
		if mesh and mesh.MeshType == Enum.MeshType.Sphere then
			return "Oval"
		elseif mesh then
			return "SpecialMesh:" .. mesh.MeshType.Name
		end
		return part.Shape.Name -- Block, Ball, Cylinder, Wedge, CornerWedge
	end
	return part.ClassName
end

local colors: { [string]: number } = {}
local lines = {}
local counts: { [string]: number } = {}
local total = 0
local minCorner, maxCorner = Vector3.one * math.huge, -Vector3.one * math.huge

for _, descendant in target:GetDescendants() do
	if not descendant:IsA("BasePart") then
		continue
	end
	total += 1
	local shape = shapeOf(descendant)
	counts[shape] = (counts[shape] or 0) + 1
	local offset = pivot:ToObjectSpace(descendant.CFrame)
	local half = descendant.Size / 2
	minCorner = minCorner:Min(offset.Position - half)
	maxCorner = maxCorner:Max(offset.Position + half)
	local color = descendant.Color
	local key = string.format(
		"%d, %d, %d",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
	colors[key] = (colors[key] or 0) + 1
	if total <= MAX_PIEZAS then
		local extra = if descendant.Transparency > 0 then ", " .. num(descendant.Transparency) else ""
		table.insert(
			lines,
			string.format(
				'piece("%s", %s, %s, Color3.fromRGB(%s), Enum.Material.%s%s) -- %s',
				shape,
				vec(descendant.Size),
				frame(offset),
				key,
				descendant.Material.Name,
				extra,
				descendant.Name
			)
		)
	end
end

local summary = {
	"-- " .. target:GetFullName() .. " (" .. target.ClassName .. ")",
	"-- Piezas: " .. total .. (if total > MAX_PIEZAS then " (volcadas solo " .. MAX_PIEZAS .. ")" else ""),
}
local shapeList = {}
for shape, count in counts do
	table.insert(shapeList, shape .. " x" .. count)
end
table.sort(shapeList)
table.insert(summary, "-- Formas: " .. table.concat(shapeList, ", "))
if total > 0 then
	table.insert(summary, "-- Caja (respecto al pivote): de " .. vec(minCorner) .. " a " .. vec(maxCorner))
end
local colorList = {}
for key, count in colors do
	table.insert(colorList, { key = key, count = count })
end
table.sort(colorList, function(a, b)
	return a.count > b.count
end)
for index, entry in colorList do
	if index > 12 then
		table.insert(summary, "-- (" .. (#colorList - 12) .. " colores más)")
		break
	end
	table.insert(summary, "-- Color(" .. entry.key .. ") x" .. entry.count)
end

return table.concat(summary, "\n") .. "\n\n" .. table.concat(lines, "\n")
