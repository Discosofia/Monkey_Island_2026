--!strict
-- Calendario y misiones diarias (bucle de retención, octubre de 2026), en el Lobby y en la Isla.
--   - claimLogin: cobra el premio del día del calendario de 7 días (Config.Daily.Calendar). Uno por
--     día (Shared/Daily); faltar un día no lo reinicia.
--   - grant: entrega un premio: Ámbar, provisiones (ServerShared/Supplies), tiempo para el huevo del
--     nido (con o sin el tope de lo ganado jugando; sin huevo en el nido se cambia por Ámbar) y huevos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Daily = require(ReplicatedStorage.Shared.Daily)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Analytics = require(script.Parent.Analytics)
local Eggs = require(script.Parent.Eggs)
local PlayerData = require(script.Parent.PlayerData)
local Supplies = require(script.Parent.Supplies)

local Retention = {}

local rng = Random.new()

local function now(): number
	return math.floor(EggIncubation.now())
end

local function addAmber(player: Player, amount: number, reason: string)
	PlayerData.update(player, function(profile)
		profile.amber += amount
		Analytics.amber(player, "Source", amount, profile.amber, reason)
	end)
end

-- Entrega un premio y devuelve, línea a línea, lo que ha recibido el jugador. "capped": el tiempo de
-- huevo cuenta para el tope de lo ganado jugando (misiones); sin él, se quita entero (calendario).
function Retention.grant(player: Player, reward: Config.Reward, capped: boolean, reason: string): { string }
	local lines = {}
	if reward.egg then
		local rarity = PetRoll.rollRarity(rng, reward.egg)
		local where = Eggs.grant(player, rarity)
		local place = if where == "nest"
			then "ya se incuba en tu nido"
			elseif where == "bag" then "a tu mochila de huevos"
			else "pendiente: tu mochila está llena"
		table.insert(lines, `🥚 Huevo {Rarities[rarity].name} ({place})`)
	end
	if reward.amber then
		addAmber(player, reward.amber, reason)
		table.insert(lines, `{reward.amber} ✨ Ámbar`)
	end
	if reward.eggSeconds then
		local data = Eggs.get(player)
		local nest = data and data.nest
		if nest and not EggIncubation.isReady(nest, now()) then
			local applied = if capped
				then Eggs.addPlayTime(player, reward.eggSeconds)
				else Eggs.addFreeTime(player, reward.eggSeconds)
			table.insert(lines, `⏩ −{EggIncubation.formatTime(applied)} a tu huevo {Rarities[nest.rarity].name}`)
		else
			local amber = math.ceil(reward.eggSeconds / 3600 * Config.Daily.AmberPerUnusedEggHour)
			addAmber(player, amber, reason)
			table.insert(lines, `{amber} ✨ Ámbar (no tenías huevo incubando)`)
		end
	end
	if reward.items then
		local items = Rewards.sanitizeItems(reward.items)
		if next(items) ~= nil then
			Supplies.add(player, items)
			table.insert(lines, `🎒 {Rewards.describeItems(items)} (para tu próxima partida)`)
		end
	end
	return lines
end

-- Cobra el premio de hoy del calendario. Devuelve el día cobrado (1..7) y lo recibido, o nil si hoy
-- ya lo cobró (o su perfil aún no ha cargado).
function Retention.claimLogin(player: Player): (number?, { string }?)
	local time = now()
	local day: number? = nil
	PlayerData.update(player, function(profile)
		local state = Daily.loginState(profile.login)
		if Daily.canClaim(state, time) then
			day = state.step
			profile.login = { lastClaimDay = Daily.today(time), step = state.step % Daily.CALENDAR_DAYS + 1 }
		end
	end)
	if not day then
		return nil, nil
	end
	local claimed = day :: number
	local lines = Retention.grant(player, Config.Daily.Calendar[claimed], false, "LoginCalendar")
	return claimed, lines
end

-- Prueba (panel de Studio): hace como si el último cobro hubiera sido ayer.
function Retention.debugNextDay(player: Player)
	PlayerData.update(player, function(profile)
		local state = Daily.loginState(profile.login)
		profile.login = { lastClaimDay = math.min(state.lastClaimDay, Daily.today(now()) - 1), step = state.step }
	end)
end

return Retention
