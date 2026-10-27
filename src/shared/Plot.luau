--!strict
-- Parcela permanente (Fase 12): lo que comparten el servidor (ServerShared/PlayerData la guarda en el
-- perfil "plot" y la publica en el atributo JSON "Plot"; BuildingService la levanta en la Isla) y el
-- cliente (la ventana de bienvenida, UI/PlotWelcome). Sin efectos.
--   - Se desbloquea al ganar por primera vez ("unlocked") y viaja con el jugador a cada partida: ocupa
--     uno de los 5 huecos del Basecamp con sus estructuras.
--   - Cada estructura tiene un nivel 0–3 (0 = aún no está). Su sitio en la parcela, Config.Plot.Layout.
--   - "noticeShown": ya vio la ventana de bienvenida a la parcela.
--   - "chest": lo guardado en el cofre (P4, ChestService), por objeto: "private" solo lo usa el dueño y
--     "shared" lo coge cualquiera de su partida. Todos lo ven en el atributo "Plot" del dueño.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)
local PlotStructures = require(script.Parent.Data.PlotStructures)

local Plot = {}

-- Estructuras de la parcela, en el orden en que se enseñan.
Plot.STRUCTURES = { "Forge", "Healer", "Garden", "Bed", "Chest", "Incubator", "Nest" }
Plot.MAX_LEVEL = 3

-- Cómo se escribe cada nivel (el 0 es "aún no está"). Coste, vida y efecto de cada uno:
-- Data/PlotStructures; su modelo, Shared/PlotModels.
Plot.ROMAN = { "I", "II", "III" }
-- Aviso del cartel de cada hueco (atributo "PlotIndex"): abre la ventana Parcela a su dueño.
Plot.PROMPT_NAME = "PlotPrompt"
-- Atributo del Player con el descuento (0–1) de su parcela en las recetas de una estación, seguido del
-- id de la estación (PlotService lo pone mientras la estructura está en pie; Shared/Crafting lo aplica).
Plot.DISCOUNT_ATTRIBUTE = "PlotDiscount_"
-- Aviso del cofre (todos lo ven: lo compartido es de cualquiera) y atributo del Player con el nivel con que
-- funciona su cofre (nil si no lo tiene o está roto; lo pone PlotService). Lo guardado en el cofre solo se
-- usa con el cofre en pie, también para pagar las mejoras.
Plot.CHEST_PROMPT = "ChestPrompt"
Plot.CHEST_ATTRIBUTE = "PlotChest"
Plot.CHEST_PARTS = { "private", "shared" }
-- Atributo del Player mientras se defiende un huevo en el nido de su parcela (P5, EggService): el nido
-- no se puede mejorar ni se reconstruye hasta que acaba (la ventana Parcela lo dice).
Plot.NEST_BUSY_ATTRIBUTE = "PlotNestBusy"

-- Cuánto pide de un material una receta de "stationId" a "player", con el descuento de su parcela (la
-- forja y el taller, Data/PlotStructures "discount"). Redondeado al más cercano (hacia arriba, los costes
-- pequeños se quedaban sin descuento: 3 × 0,7 = 2,1 → 3) y nunca por debajo de 1.
function Plot.discounted(player: Player, stationId: string, amount: number): number
	local discount = player:GetAttribute(Plot.DISCOUNT_ATTRIBUTE .. stationId)
	if typeof(discount) ~= "number" or discount <= 0 then
		return amount
	end
	return math.max(1, math.round(amount * (1 - discount)))
end

export type State = {
	unlocked: boolean,
	noticeShown: boolean,
	levels: { [string]: number },
	chest: { private: { [string]: number }, shared: { [string]: number } },
}

local function counts(raw: any): { [string]: number }
	local result = {}
	if typeof(raw) == "table" then
		for itemId, amount in raw do
			if typeof(itemId) == "string" and typeof(amount) == "number" and amount > 0 then
				result[itemId] = amount // 1
			end
		end
	end
	return result
end

-- Estado completo a partir de lo guardado o publicado (rellena lo que falte y descarta lo que no vale).
function Plot.normalize(raw: any): State
	local data = if typeof(raw) == "table" then raw else {}
	local levels = {}
	local rawLevels = if typeof(data.levels) == "table" then data.levels else {}
	for _, id in Plot.STRUCTURES do
		local level = rawLevels[id]
		levels[id] = if typeof(level) == "number" then math.clamp(level // 1, 0, Plot.MAX_LEVEL) else 0
	end
	local chest = if typeof(data.chest) == "table" then data.chest else {}
	return {
		unlocked = data.unlocked == true,
		noticeShown = data.noticeShown == true,
		levels = levels,
		chest = { private = counts(chest.private), shared = counts(chest.shared) },
	}
end

-- Incubadora (P5) de una parcela: huecos del nido del Lobby y factor del tiempo de sus huevos. Cuenta el
-- nivel del perfil (el nido del Lobby no sabe de asedios).
function Plot.incubator(state: State): (number, number)
	local level = if state.unlocked then state.levels.Incubator else 0
	local data = if level > 0 then PlotStructures.Incubator.levels[level] else nil
	return if data then data.nestSlots or 1 else 1, if data then data.eggTimeFactor or 1 else 1
end

-- Casillas del cofre en un nivel (0 sin cofre).
function Plot.chestSlots(level: number): number
	return Config.Plot.ChestSlots[level] or 0
end

-- Casillas que ocupa lo guardado: cada objeto de cada parte llena casillas de Config.Plot.ChestStack.
function Plot.slotsUsed(chest: { private: { [string]: number }, shared: { [string]: number } }): number
	local used = 0
	for _, part in Plot.CHEST_PARTS do
		for _, amount in (chest :: any)[part] do
			used += math.ceil(amount / Config.Plot.ChestStack)
		end
	end
	return used
end

-- Cuánto más de "itemId" cabe en la parte "part" de un cofre de nivel "level" (llena primero la última
-- casilla empezada de ese objeto y luego las libres).
function Plot.roomFor(state: State, level: number, part: string, itemId: string): number
	local stack = Config.Plot.ChestStack
	local current = ((state.chest :: any)[part] :: { [string]: number })[itemId] or 0
	local otherSlots = Plot.slotsUsed(state.chest) - math.ceil(current / stack)
	return math.max(0, (Plot.chestSlots(level) - otherSlots) * stack - current)
end

-- Parcela de "player" según su atributo "Plot" (sin desbloquear si aún no ha cargado).
function Plot.of(player: Player?): State
	local target = player or Players.LocalPlayer
	local raw = if target then target:GetAttribute("Plot") else nil
	local decoded = nil
	if typeof(raw) == "string" then
		local ok, value = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		decoded = if ok then value else nil
	end
	return Plot.normalize(decoded)
end

return Plot
