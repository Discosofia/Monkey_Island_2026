--!strict
-- Fusión de bloques vecinos (greedy meshing sobre Parts, Fase 16). El aspecto no cambia: las cajas del mismo
-- color, material y demás propiedades que se tocan por una cara entera pasan a ser una sola Part. Menos
-- instancias = menos CPU, memoria y replicación (Config.Budgets).
--
--   merge(parts, frame, opts)   fusiona "parts", que están fijas respecto a "frame" (el CFrame del ancla: el
--                               Handle, un miembro, un hueso o la Root).
--   mergeWelded(model, opts)    agrupa por la Part0 de sus soldaduras y llama a merge por cada ancla.
--   count(model)                piezas del modelo y cuántas llevan la etiqueta "Detalle".
--
-- Cómo funciona: pasa cada caja al espacio local del ancla, las agrupa por una clave (color, material,
-- transparencia, colisiones, sombra, Massless, Anchored, atributo Bone y si es detalle) y, dentro de cada grupo,
-- borra las cajas contenidas en otra y hace barridos por eje: dos cajas que coinciden en los otros dos ejes y se
-- tocan en el tercero pasan a una. Se repite hasta que no cambia nada.
--
-- Nunca fusiona: cuñas, bolas, cilindros, MeshPart, SpecialMesh, piezas con Transparency 1, piezas con hijos
-- que no sean su soldadura, piezas con atributos distintos de Bone, piezas giradas fuera de los ejes del ancla
-- ni los nombres de KEEP (ni los que se añadan en opts.keep).
--
-- Marca con la etiqueta "Detalle" las piezas cuyo lado mayor queda por debajo de Config.Budgets.Lod.DetailMaxSize
-- (las oculta DetailLodController a los otros jugadores lejos), para no tocar los constructores.
--
-- Funciona en modo edición: solo usa Config (ni Remotes ni Settings), así la calculadora Rendimiento la puede
-- cargar desde una copia de Shared. Con Config.Budgets.Merge = false no fusiona (para comparar), salvo
-- opts.force = true.

local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)

export type Options = {
	keep: { [string]: boolean }?, -- nombres que no se fusionan, además de KEEP
	detailMaxSize: number?, -- lado mayor por debajo del que una pieza es "Detalle" (de serie, el de Config)
	force: boolean?, -- fusiona aunque Config.Budgets.Merge sea false (la calculadora)
	tag: boolean?, -- false: no pone ni quita la etiqueta "Detalle"
}

export type Result = {
	before: number, -- piezas que había
	after: number, -- piezas que quedan
	detail: number, -- de las que quedan, las marcadas como Detalle
}

local VoxelMerge = {}

VoxelMerge.DETAIL_TAG = "Detalle"

-- Dos coordenadas más cerca que esto (studs) son la misma.
local TOLERANCE = 1e-3

-- Nombres de pieza que nunca se fusionan: el resto del juego las busca por nombre o las trata aparte.
local KEEP: { [string]: boolean } = {
	Handle = true,
	Crystal = true,
	Muzzle = true,
	Eye = true,
	Greca = true,
	Feather = true,
	Border = true,
	Bounds = true,
	Root = true,
	Seat = true,
}

-- Una caja alineada con los ejes del ancla: esquinas mínima y máxima (x, y, z) en su espacio local, la parte
-- que la rota respecto al ancla y la Part que la lleva.
type Box = {
	part: BasePart,
	min: { number },
	max: { number },
	rotation: CFrame,
	merged: boolean,
}

local function quantize(value: number): number
	return math.round(value / TOLERANCE)
end

local function detailLimit(opts: Options): number
	return opts.detailMaxSize or Config.Budgets.Lod.DetailMaxSize
end

local function longestSide(part: BasePart): number
	local size = part.Size
	return math.max(size.X, size.Y, size.Z)
end

-- ¿Cada fila y columna de la rotación es un eje (±1, 0, 0)? Solo entonces la pieza es una caja alineada.
local function axisAligned(rotation: { number }): boolean
	for _, value in rotation do
		local absolute = math.abs(value)
		if absolute > TOLERANCE and math.abs(absolute - 1) > TOLERANCE then
			return false
		end
	end
	return true
end

-- ¿Se puede fusionar esta pieza? (los hijos permitidos son su soldadura)
local function mergeable(part: BasePart, keep: { [string]: boolean }): boolean
	if part.ClassName ~= "Part" or (part :: Part).Shape ~= Enum.PartType.Block then
		return false
	end
	if part.Transparency >= 1 or KEEP[part.Name] or keep[part.Name] then
		return false
	end
	for _, child in part:GetChildren() do
		if child:IsA("WeldConstraint") then
			if (child :: WeldConstraint).Part1 ~= part then
				return false
			end
		elseif child:IsA("Weld") then
			if (child :: Weld).Part1 ~= part then
				return false
			end
		else
			return false
		end
	end
	for name in part:GetAttributes() do
		if name ~= "Bone" then
			return false
		end
	end
	return true
end

-- La caja de "part" en el espacio de "frame", o nil si no está alineada con sus ejes.
local function boxOf(part: BasePart, frame: CFrame): Box?
	local localFrame = frame:ToObjectSpace(part.CFrame)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = localFrame:GetComponents()
	if not axisAligned({ r00, r01, r02, r10, r11, r12, r20, r21, r22 }) then
		return nil
	end
	local size = part.Size
	-- Largo de cada eje local: la fila de la rotación dice qué lado de la pieza cae en él.
	local extents = {
		math.abs(r00) * size.X + math.abs(r01) * size.Y + math.abs(r02) * size.Z,
		math.abs(r10) * size.X + math.abs(r11) * size.Y + math.abs(r12) * size.Z,
		math.abs(r20) * size.X + math.abs(r21) * size.Y + math.abs(r22) * size.Z,
	}
	local center = { x, y, z }
	local min, max = {}, {}
	for axis = 1, 3 do
		min[axis] = center[axis] - extents[axis] / 2
		max[axis] = center[axis] + extents[axis] / 2
	end
	return { part = part, min = min, max = max, rotation = localFrame.Rotation, merged = false }
end

-- Clave del grupo: dos piezas solo se funden si coinciden en todo esto.
local function groupKey(part: BasePart, detail: boolean): string
	local bone = part:GetAttribute("Bone")
	return string.format(
		"%s|%d|%.3f|%.3f|%s%s%s%s%s%s|%s|%s",
		part.Color:ToHex(),
		part.Material.Value,
		part.Transparency,
		part.Reflectance,
		if part.CanCollide then "c" else "-",
		if part.CanQuery then "q" else "-",
		if part.CanTouch then "t" else "-",
		if part.CastShadow then "s" else "-",
		if part.Massless then "m" else "-",
		if part.Anchored then "a" else "-",
		if bone ~= nil then tostring(bone) else "",
		if detail then "D" else "N"
	)
end

local function contains(outer: Box, inner: Box): boolean
	for axis = 1, 3 do
		if inner.min[axis] < outer.min[axis] - TOLERANCE or inner.max[axis] > outer.max[axis] + TOLERANCE then
			return false
		end
	end
	return true
end

-- Quita las cajas que quedan dentro de otra (las iguales, todas menos una). Devuelve las que sobran.
local function dropContained(boxes: { Box }, absorbed: { BasePart }): { Box }
	local kept: { Box } = {}
	for index, box in boxes do
		local hidden = false
		for other, outer in boxes do
			if other ~= index and contains(outer, box) and (other < index or not contains(box, outer)) then
				hidden = true
				break
			end
		end
		if hidden then
			table.insert(absorbed, box.part)
		else
			table.insert(kept, box)
		end
	end
	return kept
end

-- Un barrido por el eje "axis": une las cajas con la misma sección (en los otros dos ejes) que se tocan o
-- se solapan a lo largo de él. Devuelve las cajas que quedan y si unió alguna.
local function sweep(boxes: { Box }, axis: number, absorbed: { BasePart }): ({ Box }, boolean)
	local first, second = if axis == 1 then 2 else 1, if axis == 3 then 2 else 3
	local buckets: { [string]: { Box } } = {}
	local order: { string } = {}
	for _, box in boxes do
		local key = string.format(
			"%d_%d_%d_%d",
			quantize(box.min[first]),
			quantize(box.max[first]),
			quantize(box.min[second]),
			quantize(box.max[second])
		)
		local bucket = buckets[key]
		if not bucket then
			bucket = {}
			buckets[key] = bucket
			table.insert(order, key)
		end
		table.insert(bucket, box)
	end
	local result: { Box } = {}
	local changed = false
	for _, key in order do
		local bucket = buckets[key]
		table.sort(bucket, function(a, b)
			return a.min[axis] < b.min[axis]
		end)
		local current = bucket[1]
		for index = 2, #bucket do
			local nextBox = bucket[index]
			if nextBox.min[axis] <= current.max[axis] + TOLERANCE then
				current.max[axis] = math.max(current.max[axis], nextBox.max[axis])
				current.merged = true
				table.insert(absorbed, nextBox.part)
				changed = true
			else
				table.insert(result, current)
				current = nextBox
			end
		end
		table.insert(result, current)
	end
	return result, changed
end

-- Escribe la caja fusionada en su Part: tamaño en los ejes de la pieza y posición en el espacio de "frame".
local function apply(box: Box, frame: CFrame)
	local part = box.part
	local extents = {}
	local center = {}
	for axis = 1, 3 do
		extents[axis] = box.max[axis] - box.min[axis]
		center[axis] = (box.min[axis] + box.max[axis]) / 2
	end
	-- La rotación es una permutación de ejes: el largo de cada lado de la pieza es el del eje local que cae en él.
	local _px, _py, _pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = box.rotation:GetComponents()
	part.Size = Vector3.new(
		math.abs(r00) * extents[1] + math.abs(r10) * extents[2] + math.abs(r20) * extents[3],
		math.abs(r01) * extents[1] + math.abs(r11) * extents[2] + math.abs(r21) * extents[3],
		math.abs(r02) * extents[1] + math.abs(r12) * extents[2] + math.abs(r22) * extents[3]
	)
	part.CFrame = frame * (CFrame.new(center[1], center[2], center[3]) * box.rotation)
end

-- Pone o quita la etiqueta "Detalle" según el lado mayor de la pieza.
local function tagDetail(part: BasePart, limit: number)
	local detail = longestSide(part) < limit
	if detail ~= CollectionService:HasTag(part, VoxelMerge.DETAIL_TAG) then
		if detail then
			CollectionService:AddTag(part, VoxelMerge.DETAIL_TAG)
		else
			CollectionService:RemoveTag(part, VoxelMerge.DETAIL_TAG)
		end
	end
end

-- Fusiona las piezas de "parts", que no se mueven unas respecto a otras ni respecto a "frame". Cambia el
-- tamaño y la posición de las que sobreviven y destruye las absorbidas. Devuelve cuántas había, cuántas quedan
-- y cuántas de ellas son Detalle.
function VoxelMerge.merge(parts: { BasePart }, frame: CFrame, opts: Options?): Result
	local options: Options = opts or {}
	local keep = options.keep or {}
	local limit = detailLimit(options)
	local tagging = options.tag ~= false
	local before = #parts
	local absorbed: { BasePart } = {}

	if Config.Budgets.Merge or options.force then
		local groups: { [string]: { Box } } = {}
		local order: { string } = {}
		for _, part in parts do
			if mergeable(part, keep) then
				local box = boxOf(part, frame)
				if box then
					local key = groupKey(part, longestSide(part) < limit)
					local group = groups[key]
					if not group then
						group = {}
						groups[key] = group
						table.insert(order, key)
					end
					table.insert(group, box)
				end
			end
		end
		for _, key in order do
			local boxes = dropContained(groups[key], absorbed)
			repeat
				local any = false
				for axis = 1, 3 do
					local changed
					boxes, changed = sweep(boxes, axis, absorbed)
					any = any or changed
				end
			until not any
			for _, box in boxes do
				if box.merged then
					apply(box, frame)
				end
			end
		end
		for _, part in absorbed do
			part:Destroy()
		end
	end

	local gone: { [BasePart]: boolean } = {}
	for _, part in absorbed do
		gone[part] = true
	end
	local after, detail = 0, 0
	for _, part in parts do
		if not gone[part] then
			after += 1
			if tagging and part.Transparency < 1 and not (KEEP[part.Name] or keep[part.Name]) then
				tagDetail(part, limit)
			end
			if CollectionService:HasTag(part, VoxelMerge.DETAIL_TAG) then
				detail += 1
			end
		end
	end
	return { before = before, after = after, detail = detail }
end

-- Fusiona las piezas de "model" soldadas a un ancla (Part0 de una WeldConstraint o Weld), por ancla. Las
-- que hacen de ancla de otras no se tocan. Devuelve el total de todos los anclas.
function VoxelMerge.mergeWelded(model: Instance, opts: Options?): Result
	local byAnchor: { [BasePart]: { BasePart } } = {}
	local anchors: { BasePart } = {}
	local isAnchor: { [BasePart]: boolean } = {}
	local seen: { [BasePart]: boolean } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("WeldConstraint") or descendant:IsA("Weld") then
			local joint = descendant :: any
			local part0, part1 = joint.Part0 :: BasePart?, joint.Part1 :: BasePart?
			if part0 and part1 and not seen[part1] then
				seen[part1] = true
				isAnchor[part0] = true
				if not byAnchor[part0] then
					byAnchor[part0] = {}
					table.insert(anchors, part0)
				end
				table.insert(byAnchor[part0], part1)
			end
		end
	end
	local total: Result = { before = 0, after = 0, detail = 0 }
	for _, anchor in anchors do
		local members: { BasePart } = {}
		for _, part in byAnchor[anchor] do
			if not isAnchor[part] then
				table.insert(members, part)
			end
		end
		local result = VoxelMerge.merge(members, anchor.CFrame, opts)
		total.before += result.before
		total.after += result.after
		total.detail += result.detail
	end
	return total
end

-- Piezas (BasePart) de "model" y cuántas llevan la etiqueta "Detalle".
function VoxelMerge.count(model: Instance): (number, number)
	local total, detail = 0, 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			total += 1
			if CollectionService:HasTag(descendant, VoxelMerge.DETAIL_TAG) then
				detail += 1
			end
		end
	end
	return total, detail
end

return VoxelMerge
