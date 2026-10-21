--!strict
-- Tiendas de cosméticos del Lobby (Fase 9, G10): qué se vende y qué toca hoy. Sin efectos; lo usan el
-- servidor (CosmeticShopService del Lobby), la ventana Tienda (UI/CosmeticShopPanel), el Armario y la
-- calculadora de la economía.
--   - Ámbar: los cosméticos con "source.amber" (Data/Cosmetics); cada día (Shared/Daily, 00:00 UTC)
--     Config.CosmeticShop.AmberSlots.
--   - Robux: los sueltos con "source.productId" (un Developer Product cada uno); cada semana (el lunes)
--     Config.CosmeticShop.RobuxSlots.
--   - Siempre a la venta: los Game Passes ("source.gamePassId").
-- La rotación es la misma para todos (un orden barajado con la semilla del día o de la semana), pero
-- cada jugador ve los primeros de ese orden que aún no tiene: nunca le toca algo suyo y dos amigos
-- que no tienen nada ven lo mismo. El servidor fija la de cada jugador la primera vez que la mira en
-- el día o la semana (perfil "cosmeticShop"), para que comprar uno no destape otro.
-- Nunca entra un premio de la temporada en curso ("source.season"), tampoco en su descanso.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Cosmetics = require(script.Parent.Data.Cosmetics)
local Daily = require(script.Parent.Daily)
local EggIncubation = require(script.Parent.EggIncubation)
local SeasonPass = require(script.Parent.SeasonPass)

export type Currency = "Amber" | "Robux"

-- Lo que se guarda en el perfil ("cosmeticShop") y, con "bought" (los de la oferta que ya tiene), se
-- publica al cliente (atributo "CosmeticShop").
export type State = { day: number, amber: { string }, week: number, robux: { string } }

local CosmeticShop = {}

local DAY = 24 * 60 * 60
-- Semillas distintas para que la rotación de Robux no siga a la de Ámbar.
local SALT: { [Currency]: number } = { Amber = 101, Robux = 211 }

-- Hora de las tiendas: la del servidor (como los huevos) más el desplazamiento de prueba del panel de
-- Studio ("DebugShopShift" en ReplicatedStorage, en segundos; "📅 Tienda: día siguiente").
function CosmeticShop.now(): number
	local shift = if RunService:IsStudio() then ReplicatedStorage:GetAttribute("DebugShopShift") else nil
	return EggIncubation.now() + (if typeof(shift) == "number" then shift else 0)
end

-- Día y semana de la rotación a la hora "now".
function CosmeticShop.period(now: number): (number, number)
	return Daily.today(now), Daily.week(now)
end

-- La temporada cuyos premios no se venden a la hora "now" (en curso o en su descanso), o nil.
function CosmeticShop.seasonAt(now: number): string?
	local info = SeasonPass.info(now)
	return if info.phase ~= "None" and info.season then info.season.id else nil
end

-- Precio de "cosmeticId" en "currency" (Ámbar, o los Robux que se enseñan), o nil si no se vende así.
function CosmeticShop.price(cosmeticId: string, currency: Currency): number?
	local cosmetic = Cosmetics[cosmeticId]
	if not cosmetic then
		return nil
	end
	local source = cosmetic.source
	if currency == "Amber" then
		return source.amber
	end
	return if source.productId then source.price or 0 else nil
end

local function byOrder(ids: { string }): { string }
	table.sort(ids, function(a, b)
		local oa, ob = Cosmetics[a].order, Cosmetics[b].order
		if oa ~= ob then
			return oa < ob
		end
		return a < b
	end)
	return ids
end

-- Todo lo que puede salir en la tienda de "currency" (en orden fijo), sin los premios de "seasonId".
function CosmeticShop.pool(currency: Currency, seasonId: string?): { string }
	local ids = {}
	for cosmeticId, cosmetic in Cosmetics do
		local season = cosmetic.source.season
		if CosmeticShop.price(cosmeticId, currency) and not (season and season == seasonId) then
			table.insert(ids, cosmeticId)
		end
	end
	return byOrder(ids)
end

-- Los Game Passes (siempre a la venta), en orden.
function CosmeticShop.fixed(): { string }
	local ids = {}
	for cosmeticId, cosmetic in Cosmetics do
		if cosmetic.source.gamePassId then
			table.insert(ids, cosmeticId)
		end
	end
	return byOrder(ids)
end

-- La oferta del periodo "period" (día para Ámbar, semana para Robux): el orden barajado con su semilla
-- y, de él, los primeros que no tiene ("owns").
function CosmeticShop.offer(
	currency: Currency,
	period: number,
	owns: (string) -> boolean,
	seasonId: string?
): { string }
	local order = CosmeticShop.pool(currency, seasonId)
	local random = Random.new(period * 7919 + SALT[currency])
	for index = #order, 2, -1 do
		local other = random:NextInteger(1, index)
		order[index], order[other] = order[other], order[index]
	end
	local slots = if currency == "Amber" then Config.CosmeticShop.AmberSlots else Config.CosmeticShop.RobuxSlots
	local offer = {}
	for _, cosmeticId in order do
		if #offer >= slots then
			break
		end
		if not owns(cosmeticId) then
			table.insert(offer, cosmeticId)
		end
	end
	return offer
end

local function idList(raw: any, pool: { string }): { string }
	local list = {}
	if typeof(raw) == "table" then
		for _, value in raw do
			if typeof(value) == "string" and table.find(pool, value) and not table.find(list, value) then
				table.insert(list, value)
			end
		end
	end
	return list
end

-- Estado con la forma correcta (del perfil o del JSON del cliente): sin lo que ya no se vende.
function CosmeticShop.normalize(raw: any, seasonId: string?): State
	local data = if typeof(raw) == "table" then raw else {}
	return {
		day = if typeof(data.day) == "number" then data.day else 0,
		amber = idList(data.amber, CosmeticShop.pool("Amber", seasonId)),
		week = if typeof(data.week) == "number" then data.week else 0,
		robux = idList(data.robux, CosmeticShop.pool("Robux", seasonId)),
	}
end

-- Segundos que faltan para que cambie la tienda de "currency".
function CosmeticShop.secondsLeft(currency: Currency, now: number): number
	return if currency == "Amber" then Daily.secondsToReset(now) else Daily.secondsToWeekReset(now)
end

-- Cuenta atrás corta ("5 h 12 min", "3 d 4 h").
function CosmeticShop.formatLeft(seconds: number): string
	if seconds >= DAY then
		return `{seconds // DAY} d {(seconds % DAY) // 3600} h`
	elseif seconds >= 3600 then
		return `{seconds // 3600} h {(seconds % 3600) // 60} min`
	end
	return `{math.max(1, seconds // 60)} min`
end

return CosmeticShop
