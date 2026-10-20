--!strict
-- Calendario y misiones diarias (bucle de retención, octubre de 2026), en el Lobby y en la Isla.
--   - claimLogin: cobra el premio del día del calendario de 7 días (Config.Daily.Calendar). Uno por
--     día (Shared/Daily); faltar un día no lo reinicia.
--   - grant: entrega un premio: Ámbar, provisiones (ServerShared/Supplies), tiempo para el huevo del
--     nido (con o sin el tope de lo ganado jugando; sin huevo en el nido se cambia por Ámbar) y huevos.
--   - Misiones del día (Data/Missions): cada día tocan Config.Daily.GeneralMissions generales y una del
--     rol elegido (si cambia de rol, cambia esa, salvo que ya la hubiera cumplido). Los servicios de la
--     Isla avisan con progress(jugador, evento, cantidad); se apunta en el perfil cada
--     Config.Daily.MissionFlushSeconds y, al cumplir una, se entrega su premio con aviso.
--     start() lo pone en marcha (una vez por servidor, en el Lobby y en la Isla).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Daily = require(ReplicatedStorage.Shared.Daily)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Missions = require(ReplicatedStorage.Shared.Data.Missions)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Analytics = require(script.Parent.Analytics)
local Eggs = require(script.Parent.Eggs)
local PlayerData = require(script.Parent.PlayerData)
local Supplies = require(script.Parent.Supplies)

local Retention = {}

local rng = Random.new()
-- Lo que han avanzado las misiones de cada jugador desde la última vez que se apuntó (por evento).
local pending: { [Player]: { [string]: number } } = {}
local started = false

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

-- Una misión al azar de las que valen ("role" = nil para las generales), sin repetir "taken".
local function pickMission(role: string?, taken: { [string]: boolean }): string?
	local candidates = {}
	for missionId, mission in Missions do
		if mission.role == role and not taken[missionId] then
			table.insert(candidates, missionId)
		end
	end
	if #candidates == 0 then
		return nil
	end
	table.sort(candidates)
	return candidates[rng:NextInteger(1, #candidates)]
end

-- ¿Hay que renovar las misiones (otro día) o cambiar la del rol?
local function needsRefresh(profile: PlayerData.Profile, time: number): boolean
	local state = Daily.missionState(profile.daily)
	return state.day ~= Daily.today(time) or state.role ~= Progression.validRole(profile.selectedRole)
end

local function refreshMissions(profile: PlayerData.Profile, time: number)
	local state = Daily.missionState(profile.daily)
	local today = Daily.today(time)
	local role = Progression.validRole(profile.selectedRole)
	if state.day ~= today then
		local taken = {}
		local missions: { Daily.DailyMission } = {}
		for _ = 1, Config.Daily.GeneralMissions do
			local missionId = pickMission(nil, taken)
			if missionId then
				taken[missionId] = true
				table.insert(missions, { id = missionId, progress = 0, done = false })
			end
		end
		local roleMission = pickMission(role, taken)
		if roleMission then
			table.insert(missions, { id = roleMission, progress = 0, done = false })
		end
		state = { day = today, role = role, missions = missions }
	elseif state.role ~= role then
		-- Otro rol: su misión cambia por una del nuevo (si la del viejo ya estaba cumplida, se queda).
		for index, mission in state.missions do
			if Missions[mission.id].role and not mission.done then
				local replacement = pickMission(role, {})
				if replacement then
					state.missions[index] = { id = replacement, progress = 0, done = false }
				end
			end
		end
		state.role = role
	end
	profile.daily = state :: any
end

-- Pone al día las misiones del jugador si ha cambiado el día o su rol (al cargar, al elegir rol).
function Retention.refresh(player: Player)
	local profile = PlayerData.get(player)
	if profile and needsRefresh(profile, now()) then
		PlayerData.update(player, function(current)
			refreshMissions(current, now())
		end)
	end
end

-- Lo cuentan los servicios de la Isla: "event" como en Data/Missions ("Kill", "Gather"…).
function Retention.progress(player: Player, event: string, amount: number?)
	local events = pending[player]
	if not events then
		events = {}
		pending[player] = events
	end
	events[event] = (events[event] or 0) + (amount or 1)
end

-- Apunta en el perfil lo que han avanzado y entrega las misiones que se acaban de cumplir.
local function flush(player: Player)
	local events = pending[player]
	pending[player] = nil
	if not events or not PlayerData.get(player) then
		return
	end
	local completed: { string } = {}
	PlayerData.update(player, function(profile)
		local time = now()
		if needsRefresh(profile, time) then
			refreshMissions(profile, time)
		end
		local state = Daily.missionState(profile.daily)
		for _, mission in state.missions do
			local definition = Missions[mission.id]
			local added = events[definition.event]
			if added and not mission.done then
				mission.progress = math.min(definition.target, mission.progress + added)
				if mission.progress >= definition.target then
					mission.done = true
					table.insert(completed, mission.id)
				end
			end
		end
		profile.daily = state :: any
	end)
	for _, missionId in completed do
		local lines = Retention.grant(player, Missions[missionId].reward, true, "DailyMission")
		Remotes.Notify:FireClient(
			player,
			`🎯 ¡Misión cumplida! {Daily.missionText(missionId)}: {table.concat(lines, " · ")}`
		)
	end
end

function Retention.start()
	if started then
		return
	end
	started = true
	local function onPlayer(player: Player)
		if PlayerData.waitFor(player) then
			Retention.refresh(player)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
	task.spawn(function()
		local sinceRefresh = 0
		while true do
			task.wait(Config.Daily.MissionFlushSeconds)
			for player in table.clone(pending) do
				task.spawn(flush, player)
			end
			-- Cada minuto, por si cambia el día con el jugador dentro.
			sinceRefresh += Config.Daily.MissionFlushSeconds
			if sinceRefresh >= 60 then
				sinceRefresh = 0
				for _, player in Players:GetPlayers() do
					task.spawn(Retention.refresh, player)
				end
			end
		end
	end)
end

-- Prueba (panel de Studio): hace como si el último cobro y las misiones fueran de ayer.
function Retention.debugNextDay(player: Player)
	PlayerData.update(player, function(profile)
		local state = Daily.loginState(profile.login)
		profile.login = { lastClaimDay = math.min(state.lastClaimDay, Daily.today(now()) - 1), step = state.step }
		local missions = Daily.missionState(profile.daily)
		missions.day = Daily.today(now()) - 1
		profile.daily = missions :: any
	end)
	Retention.refresh(player)
end

-- Prueba (panel de Studio): completa todas las misiones del día (se entregan en el siguiente apunte).
function Retention.debugCompleteMissions(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	for _, mission in Daily.missionState(profile.daily).missions do
		local definition = Missions[mission.id]
		Retention.progress(player, definition.event, definition.target)
	end
end

return Retention
