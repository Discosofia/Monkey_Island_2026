--!strict
-- Huevos guardados (bucle de retención, octubre de 2026): cuentas puras que usan el servidor
-- (ServerShared/Eggs) y los clientes (el nido del Lobby, el HUD de la Isla).
--   - La mochila guarda hasta Config.Egg.BagSize huevos; los que no caben quedan "pendientes".
--   - Solo el del nido avanza con el reloj real (también sin conectarse).
--   - Jugar le quita tiempo ("playBonus", con tope Config.Egg.PlayCapFraction del total); el calendario
--     se lo quita sin tope ("freeBonus"); "ready" lo deja listo ya (eclosión inmediata del rescate).
-- Las horas son las del servidor (workspace:GetServerTimeNow, igual en cliente y servidor). En Studio
-- se pueden adelantar con el atributo "DebugClockShift" (segundos) de ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)
local Rarities = require(script.Parent.Data.Rarities)

export type StoredEgg = { rarity: string }
export type NestEgg = {
	rarity: string,
	totalSeconds: number,
	startedAt: number,
	playBonus: number,
	freeBonus: number,
	ready: boolean?,
}
export type EggData = { nest: NestEgg?, bag: { StoredEgg }, pending: { StoredEgg } }
export type RescueResult = { seconds: number, hatch: boolean }

local EggIncubation = {}

local function validRarity(value: any): string?
	return if typeof(value) == "string" and Rarities[value] then value else nil
end

-- Hora actual (segundos Unix del servidor), con el adelanto de pruebas de Studio.
function EggIncubation.now(): number
	local shift = if RunService:IsStudio() then ReplicatedStorage:GetAttribute("DebugClockShift") else nil
	return Workspace:GetServerTimeNow() + (if typeof(shift) == "number" then shift else 0)
end

function EggIncubation.hatchSeconds(rarity: string): number
	return (Config.Egg.HatchHours :: any)[rarity] * 3600
end

-- Deja unos datos de huevos (del perfil o del JSON del cliente) con la forma correcta.
function EggIncubation.normalize(raw: any): EggData
	local data: EggData = { nest = nil, bag = {}, pending = {} }
	if typeof(raw) ~= "table" then
		return data
	end
	for _, key in { "bag", "pending" } do
		local list = raw[key]
		if typeof(list) == "table" then
			for _, entry in list do
				local rarity = if typeof(entry) == "table" then validRarity(entry.rarity) else nil
				if rarity then
					table.insert((data :: any)[key], { rarity = rarity })
				end
			end
		end
	end
	local nest = raw.nest
	local rarity = if typeof(nest) == "table" then validRarity(nest.rarity) else nil
	if rarity then
		local function number(value: any): number
			return if typeof(value) == "number" then value else 0
		end
		data.nest = {
			rarity = rarity,
			totalSeconds = if number(nest.totalSeconds) > 0
				then nest.totalSeconds
				else EggIncubation.hatchSeconds(rarity),
			startedAt = number(nest.startedAt),
			playBonus = number(nest.playBonus),
			freeBonus = number(nest.freeBonus),
			ready = if nest.ready == true then true else nil,
		}
	end
	return data
end

function EggIncubation.newNest(rarity: string, now: number): NestEgg
	return {
		rarity = rarity,
		totalSeconds = EggIncubation.hatchSeconds(rarity),
		startedAt = now,
		playBonus = 0,
		freeBonus = 0,
	}
end

-- Segundos que le faltan al huevo del nido (0 = listo para eclosionar).
function EggIncubation.remaining(nest: NestEgg, now: number): number
	if nest.ready then
		return 0
	end
	local left = nest.totalSeconds - (now - nest.startedAt) - nest.playBonus - nest.freeBonus
	return math.max(0, left)
end

function EggIncubation.isReady(nest: NestEgg, now: number): boolean
	return EggIncubation.remaining(nest, now) <= 0
end

-- Fracción ya incubada (0..1), para las barras.
function EggIncubation.progress(nest: NestEgg, now: number): number
	return 1 - EggIncubation.remaining(nest, now) / nest.totalSeconds
end

-- Cuánto tiempo más se le puede quitar jugando.
function EggIncubation.playRoom(nest: NestEgg): number
	return math.max(0, nest.totalSeconds * Config.Egg.PlayCapFraction - nest.playBonus)
end

-- Quita tiempo ganado jugando (respeta el tope). Devuelve los segundos que de verdad quitó.
function EggIncubation.addPlayTime(nest: NestEgg, seconds: number, now: number): number
	local applied = math.min(seconds, EggIncubation.playRoom(nest), EggIncubation.remaining(nest, now))
	applied = math.max(0, applied)
	nest.playBonus += applied
	return applied
end

-- Quita tiempo sin tope (calendario). Devuelve los segundos que de verdad quitó.
function EggIncubation.addFreeTime(nest: NestEgg, seconds: number, now: number): number
	local applied = math.max(0, math.min(seconds, EggIncubation.remaining(nest, now)))
	nest.freeBonus += applied
	return applied
end

-- Tirada del rescate (Config.Egg.RescueRoll).
function EggIncubation.rollRescue(rng: Random): RescueResult
	local total = 0
	for _, option in Config.Egg.RescueRoll do
		total += option.weight
	end
	local pick = rng:NextNumber(0, total)
	for _, option in Config.Egg.RescueRoll do
		pick -= option.weight
		if pick <= 0 then
			return { seconds = option.hours * 3600, hatch = option.hatch }
		end
	end
	return { seconds = 0, hatch = false }
end

function EggIncubation.discardAmber(rarity: string): number
	return (Config.Egg.DiscardAmber :: any)[rarity] or 0
end

-- "8 h 05 min", "12 min", "45 s".
function EggIncubation.formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return string.format("%d h %02d min", hours, minutes)
	elseif minutes > 0 then
		return `{minutes} min`
	end
	return `{seconds} s`
end

return EggIncubation
