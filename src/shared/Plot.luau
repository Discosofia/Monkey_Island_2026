--!strict
-- Parcela permanente (Fase 12): lo que comparten el servidor (ServerShared/PlayerData la guarda en el
-- perfil "plot" y la publica en el atributo JSON "Plot"; BuildingService la levanta en la Isla) y el
-- cliente (la ventana de bienvenida, UI/PlotWelcome). Sin efectos.
--   - Se desbloquea al ganar por primera vez ("unlocked") y viaja con el jugador a cada partida: ocupa
--     uno de los 5 huecos del Basecamp con sus estructuras.
--   - Cada estructura tiene un nivel 0–3 (0 = aún no está). Su sitio en la parcela, Config.Plot.Layout.
--   - "noticeShown": ya vio la ventana de bienvenida a la parcela.
--   - "chest": lo guardado en el cofre (privado y compartido; P4).

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Plot = {}

-- Estructuras de la parcela, en el orden en que se enseñan.
Plot.STRUCTURES = { "Forge", "Healer", "Garden", "Bed", "Chest", "Incubator", "Nest" }
Plot.MAX_LEVEL = 3

-- Pieza de Data/Buildables con que se dibuja cada una mientras no tenga modelo propio por nivel (P3).
Plot.BUILDABLE = {
	Forge = "StoneForge",
	Healer = "HealerTent",
	Bed = "Bed",
	Nest = "Nest",
} :: { [string]: string }

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
