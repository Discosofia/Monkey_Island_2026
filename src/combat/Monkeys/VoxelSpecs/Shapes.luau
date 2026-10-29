--!strict
-- Formas que se repiten en los specs voxel de los monos (colas en fila de bloques, dedos). Devuelven
-- cajas con el formato de siempre: { x, y, z, ancho, alto, fondo, tono, nombre?, simétrica? }.

local Shapes = {}

-- Cola como una fila de bloques que pasa por "points" (celdas; el primero es la base). Cada tramo se
-- reparte en bloques de unas "step" celdas, estirados en el eje por el que avanza para que se toquen
-- y formen escalones. El ancho baja de "width" a width × "taper" en la punta. "colorAt(i, n)" da el
-- tono del bloque i de n (anillos, punta negra).
function Shapes.tail(
	points: { Vector3 },
	width: number,
	taper: number,
	step: number,
	colorAt: (index: number, count: number) -> any
): { { any } }
	local centers: { Vector3 } = {}
	local steps: { Vector3 } = {}
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		local count = math.max(1, math.ceil((to - from).Magnitude / step))
		for k = 0, count - 1 do
			local at = from:Lerp(to, (k + 0.5) / count)
			-- En la rejilla de media celda: los escalones salen iguales y no en rampa.
			table.insert(
				centers,
				Vector3.new(math.round(at.X * 2) / 2, math.round(at.Y * 2) / 2, math.round(at.Z * 2) / 2)
			)
			table.insert(steps, (to - from) / count)
		end
	end
	local boxes = {}
	for index, at in centers do
		local w = width * (1 + (taper - 1) * (index - 1) / math.max(1, #centers - 1))
		local d = steps[index]
		table.insert(boxes, {
			at.X,
			at.Y,
			at.Z,
			w + math.abs(d.X),
			w + math.abs(d.Y),
			w + math.abs(d.Z),
			colorAt(index, #centers),
		})
	end
	return boxes
end

-- "count" dedos de "width" celdas delante (-Z) o detrás (+Z, "back") de una mano o un pie apoyado en el
-- suelo, centrados en x; la rendija entre ellos se lee como dedos.
function Shapes.fingers(
	x: number,
	z: number,
	count: number,
	width: number,
	length: number,
	color: any,
	back: boolean?
): { { any } }
	local boxes = {}
	local spacing = width * 1.5
	for index = 1, count do
		local offset = (index - (count + 1) / 2) * spacing
		local along = if back then length / 2 else -length / 2
		table.insert(boxes, { x + offset, 0.4, z + along, width, 0.8, length, color, "Finger" })
	end
	return boxes
end

return Shapes
