--!strict
-- Plantillas de las páginas con viñetas del cómic (Fase 25, G7c). Cada una es una lista de rectángulos
-- { x0, y0, x1, y1 } en coordenadas 0–1 de la pantalla (0,0 arriba a la izquierda), ya con el medianil blanco entre
-- viñetas y el margen de la página. Cinematics/Comic las dibuja y Data/Cinematics las usa para encuadrar la cámara
-- en el centro de cada viñeta (cellCenter), así que viven aquí, sin dependencias.
--
--   grid6   rejilla 3×2: seis viñetas iguales (el montaje del principio)
--   four_a  tres viñetas arriba (de tamaños distintos) y la cuarta, grande, abajo a todo lo ancho
--   four_b  dos viñetas apiladas a la izquierda, una arriba a la derecha y la cuarta, grande, abajo a la derecha
--   four_c  dos viñetas arriba, una pequeña abajo a la izquierda y la cuarta, grande, abajo a la derecha
--   two     dos viñetas altas, una al lado de la otra (la persecución de Captura la bandera)
--   single  una sola viñeta a toda página (el cartel final)

export type Rect = { number }

local ComicPages = {}

-- Medianil y margen: mismos píxeles en horizontal y en vertical en una pantalla 16:9 (0,012 · 1920 ≈ 0,022 · 1080).
ComicPages.GAP_X = 0.012
ComicPages.GAP_Y = 0.022
local GAP_X, GAP_Y = ComicPages.GAP_X, ComicPages.GAP_Y
local LEFT, RIGHT = GAP_X, 1 - GAP_X
local TOP, BOTTOM = GAP_Y, 1 - GAP_Y

local function rect(x0: number, y0: number, x1: number, y1: number): Rect
	return { x0, y0, x1, y1 }
end

local function grid(columns: number, rows: number): { Rect }
	local out: { Rect } = {}
	local w = (RIGHT - LEFT - (columns - 1) * GAP_X) / columns
	local h = (BOTTOM - TOP - (rows - 1) * GAP_Y) / rows
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			local x0 = LEFT + column * (w + GAP_X)
			local y0 = TOP + row * (h + GAP_Y)
			table.insert(out, rect(x0, y0, x0 + w, y0 + h))
		end
	end
	return out
end

-- Tres viñetas en fila con estos pesos de ancho, entre y0 e y1.
local function row(weights: { number }, y0: number, y1: number): { Rect }
	local out: { Rect } = {}
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local free = RIGHT - LEFT - (#weights - 1) * GAP_X
	local x = LEFT
	for _, weight in weights do
		local w = free * weight / total
		table.insert(out, rect(x, y0, x + w, y1))
		x += w + GAP_X
	end
	return out
end

local function four_a(): { Rect }
	local split = 0.42
	local out = row({ 0.29, 0.33, 0.38 }, TOP, split)
	table.insert(out, rect(LEFT, split + GAP_Y, RIGHT, BOTTOM))
	return out
end

local function four_b(): { Rect }
	local columnX = LEFT + 0.3
	local midY = (TOP + BOTTOM) / 2
	local splitRight = 0.36
	return {
		rect(LEFT, TOP, columnX, midY - GAP_Y / 2),
		rect(LEFT, midY + GAP_Y / 2, columnX, BOTTOM),
		rect(columnX + GAP_X, TOP, RIGHT, splitRight),
		rect(columnX + GAP_X, splitRight + GAP_Y, RIGHT, BOTTOM),
	}
end

local function four_c(): { Rect }
	local split = 0.36
	local columnX = 0.28
	local out = row({ 0.46, 0.54 }, TOP, split)
	table.insert(out, rect(LEFT, split + GAP_Y, columnX, BOTTOM))
	table.insert(out, rect(columnX + GAP_X, split + GAP_Y, RIGHT, BOTTOM))
	return out
end

ComicPages.PAGES = {
	grid6 = grid(3, 2),
	four_a = four_a(),
	four_b = four_b(),
	four_c = four_c(),
	two = row({ 1, 1 }, TOP, BOTTOM),
	single = { rect(LEFT, TOP, RIGHT, BOTTOM) },
} :: { [string]: { Rect } }

-- Centro y tamaño (0–1 de la pantalla) de la viñeta `index` de una plantilla: cx, cy, ancho, alto. Una plantilla o
-- una viñeta que no existen dan la pantalla entera.
function ComicPages.cellCenter(layout: string, index: number): (number, number, number, number)
	local cells = ComicPages.PAGES[layout]
	local r = if cells then cells[index] else nil
	if not r then
		return 0.5, 0.5, 1, 1
	end
	return (r[1] + r[3]) / 2, (r[2] + r[4]) / 2, r[3] - r[1], r[4] - r[2]
end

-- Un punto dentro de la viñeta, en 0–1 de la pantalla: (fx, fy) = (0,0) su esquina de arriba a la izquierda y (1,1) la
-- de abajo a la derecha. Para colocar onomatopeyas dentro de la viñeta que está viva.
function ComicPages.cellPoint(layout: string, index: number, fx: number, fy: number): { number }
	local cells = ComicPages.PAGES[layout]
	local r = if cells then cells[index] else nil
	if not r then
		return { fx, fy }
	end
	return { r[1] + (r[3] - r[1]) * fx, r[2] + (r[4] - r[2]) * fy }
end

return ComicPages
