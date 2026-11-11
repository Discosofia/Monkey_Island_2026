--!strict
-- Tabla de bandas de pantalla de las cinemáticas (Fase 25, A6). Aquí viven las posiciones de la interfaz de una escena:
-- la franja negra de arriba, el hueco de «Saltar» y las alturas del título, el subtítulo y el caption. Ningún módulo
-- escribe estos números a mano: los lee de aquí. Arriba al centro hay una pila (la barra del jefe y el reloj del día):
-- cada ocupante se registra con setTop y los de después bajan solos para no pisarlo. No requiere ningún actor ni
-- Presentation (los usan ellos); no tiene Init ni Start. Solo cliente.

local ScreenBands = {}

-- La franja negra de arriba y de abajo (Presentation), en fracción de la pantalla. Es también la zona que los Shorts
-- 9:16 recortan por arriba (Comic.REEL_SAFE_TOP).
ScreenBands.TOP = 0.12
ScreenBands.TOP_GAP = 14 -- px bajo la franja del primer elemento de la pila (la barra del jefe, las barras de supervivencia)
ScreenBands.STACK_GAP = 8 -- px entre dos elementos apilados

-- Alturas (fracción de la zona segura 9:16) del texto de Presentation. El caption baja cuando el subtítulo del título
-- está a la vista, para que no se pisen.
ScreenBands.TITLE_Y = 0.70
ScreenBands.SUB_Y = 0.80
ScreenBands.CAPTION_Y = 0.80
ScreenBands.CAPTION_Y_WITH_SUB = 0.87

-- El botón «Saltar» (abajo a la derecha, anclado a su esquina). El texto de las esquinas no invade su zona.
ScreenBands.SKIP = { size = Vector2.new(160, 48), margin = 24 }

-- Pila de arriba al centro: de arriba abajo. Cada ocupante tiene su hueco bajo la franja cuando va el primero.
local ORDER = { "BossBar", "Clock" }
local OWN_GAP: { [string]: number } = { BossBar = 14, Clock = 12 }
ScreenBands.OWN_GAP = OWN_GAP -- lo lee el arnés tools/cine_qa.luau para calcular dónde debe estar cada ocupante

local heights: { [string]: number } = {}
local listeners: { [number]: () -> () } = {}
local nextListener = 0
local titleSub = false

local function notify()
	for _, fn in table.clone(listeners) do
		task.spawn(fn)
	end
end

-- Registra (alto en px) o quita (nil) un ocupante de la pila de arriba y avisa a los demás si algo cambió.
function ScreenBands.setTop(name: string, heightPx: number?)
	if heights[name] == heightPx then
		return
	end
	heights[name] = heightPx
	notify()
end

-- Px bajo la franja a los que va `name`: su hueco propio si nadie visible va antes; si no, el borde de abajo del
-- anterior más STACK_GAP.
function ScreenBands.topOffset(name: string): number
	local cursor: number? = nil
	for _, other in ORDER do
		if other == name then
			break
		end
		local height = heights[other]
		if height then
			cursor = (cursor or OWN_GAP[other]) + height + ScreenBands.STACK_GAP
		end
	end
	return cursor or OWN_GAP[name] or ScreenBands.TOP_GAP
end

-- Llama a `fn` cada vez que cambia la pila. Devuelve la función que lo desconecta.
function ScreenBands.onTopChanged(fn: () -> ()): () -> ()
	nextListener += 1
	local id = nextListener
	listeners[id] = fn
	return function()
		listeners[id] = nil
	end
end

-- ¿Hay un subtítulo de título a la vista? (lo marca Presentation.title)
function ScreenBands.setTitleSub(visible: boolean)
	titleSub = visible
end

function ScreenBands.captionY(): number
	return if titleSub then ScreenBands.CAPTION_Y_WITH_SUB else ScreenBands.CAPTION_Y
end

-- Al acabar la escena: nadie queda registrado. Los oyentes se quedan (cada actor quita el suyo al terminar).
function ScreenBands.reset()
	heights = {}
	titleSub = false
end

return ScreenBands
