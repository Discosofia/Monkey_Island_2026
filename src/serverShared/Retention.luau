--!strict
-- Calendario y misiones diarias (bucle de retención, octubre de 2026), en el Lobby y en la Isla.
--   - claimLogin: cobra el premio del día del calendario de 7 días (Config.Daily.Calendar). Uno por
--     día (Shared/Daily); faltar un día no lo reinicia. Al cobrar el 7, los pioneros tienen una
--     tirada de montura (T6, Shared/Pioneer).
--   - grant: entrega un premio: Ámbar, provisiones (ServerShared/Supplies), tiempo para el huevo del
--     nido (con o sin el tope de lo ganado jugando; sin huevo en el nido se cambia por Ámbar), huevos
--     y XP del pase de temporada (la suma ServerShared/SeasonPass, que se apunta con setXpHandler).
--   - Misiones (Data/Missions, misiones v2): cada día una de cada dificultad de
--     Config.Daily.Difficulties (la media es la del rol elegido: si cambia de rol, cambia esa, salvo que
--     ya la hubiera cumplido) y cada semana Config.Daily.WeeklyMissions semanales, con un extra al
--     cumplirlas todas. Cambios gratis con reroll (Config.Daily.DailyRerolls y WeeklyRerolls). Los
--     servicios de la Isla y de Dunas avisan con progress(jugador, evento, cantidad, clave); se apunta
--     en el perfil cada Config.Daily.MissionFlushSeconds y, al cumplir una, se entrega su premio con
--     aviso. start() lo pone en marcha (una vez por servidor, en el Lobby, la Isla y Dunas).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Daily = require(ReplicatedStorage.Shared.Daily)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Missions = require(ReplicatedStorage.Shared.Data.Missions)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Pioneer = require(ReplicatedStorage.Shared.Pioneer)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Analytics = require(script.Parent.Analytics)
local Eggs = require(script.Parent.Eggs)
local PlayerData = require(script.Parent.PlayerData)
local Supplies = require(script.Parent.Supplies)

local later = Strings.later

local Retention = {}

local rng = Random.new()
-- Lo que han avanzado las misiones de cada jugador desde la última vez que se apuntó, por evento: la
-- suma, el valor más alto (misiones "best") y las claves vistas (misiones "distinct").
type Events = { [string]: { sum: number, best: number, keys: { [string]: boolean } } }
local pending: { [Player]: Events } = {}
local progressListeners: { (player: Player, event: string, amount: number, key: string?) -> () } = {}
local started = false
-- Quién suma la XP del pase de los premios (ServerShared/SeasonPass; así no se requieren el uno al
-- otro). Devuelve la línea para el aviso (una frase con argumentos, Shared/Strings), o nil si no ha sumado
-- nada.
local xpHandler: ((player: Player, xp: number) -> any?)? = nil

local function now(): number
	return math.floor(EggIncubation.now())
end

local function addAmber(player: Player, amount: number, reason: string)
	PlayerData.update(player, function(profile)
		profile.amber += amount
		Analytics.amber(player, "Source", amount, profile.amber, reason)
	end)
end

-- Entrega un premio y devuelve, línea a línea, lo que ha recibido el jugador: frases con argumentos
-- (Shared/Strings), que el cliente traduce ({ list = lines }). "capped": el tiempo de huevo cuenta para
-- el tope de lo ganado jugando (misiones); sin él, se quita entero (calendario).
function Retention.grant(player: Player, reward: Config.Reward, capped: boolean, reason: string): { any }
	local lines: { any } = {}
	if reward.egg then
		local rarity = PetRoll.rollRarity(rng, reward.egg)
		local where = Eggs.grant(player, rarity)
		local place = if where == "nest"
			then later("ya se incuba en tu nido")
			elseif where == "bag" then later("a tu mochila de huevos")
			else later("pendiente: tu mochila está llena")
		table.insert(
			lines,
			{ later("🥚 Huevo {rarity} ({place})"), { rarity = { Rarities[rarity].name }, place = { place } } }
		)
	end
	if reward.amber then
		addAmber(player, reward.amber, reason)
		table.insert(lines, { later("{n} ✨ Ámbar"), { n = reward.amber } })
	end
	if reward.eggSeconds then
		local data = Eggs.get(player)
		local nest = if data then EggIncubation.active(data, now()) else nil
		if nest then
			local applied = if capped
				then Eggs.addPlayTime(player, reward.eggSeconds)
				else Eggs.addFreeTime(player, reward.eggSeconds)
			table.insert(lines, {
				later("⏩ −{time} a tu huevo {rarity}"),
				{ time = EggIncubation.formatTime(applied), rarity = { Rarities[nest.rarity].name } },
			})
		else
			local amber = math.ceil(reward.eggSeconds / 3600 * Config.Daily.AmberPerUnusedEggHour)
			addAmber(player, amber, reason)
			table.insert(lines, { later("{n} ✨ Ámbar (no tenías huevo incubando)"), { n = amber } })
		end
	end
	if reward.items then
		local items = Rewards.sanitizeItems(reward.items)
		if next(items) ~= nil then
			Supplies.add(player, items)
			table.insert(
				lines,
				{ later("🎒 {items} (para tu próxima partida)"), { items = Rewards.itemsArg(items) } }
			)
		end
	end
	if reward.xp and xpHandler then
		local line = xpHandler(player, reward.xp)
		if line then
			table.insert(lines, line)
		end
	end
	return lines
end

-- Lo llama ServerShared/SeasonPass al arrancar.
function Retention.setXpHandler(handler: (player: Player, xp: number) -> any?)
	xpHandler = handler
end

-- Cobra el premio de hoy del calendario. Devuelve el día cobrado (1..7) y lo recibido, o nil si hoy
-- ya lo cobró (o su perfil aún no ha cargado). Al cobrar el día 7, un pionero tiene además la tirada
-- de montura (T6; Shared/Pioneer): la tercera respuesta es lo que ha salido.
function Retention.claimLogin(player: Player): (number?, { any }?, Pioneer.Roll?)
	local time = now()
	local day: number? = nil
	local roll: Pioneer.Roll? = nil
	PlayerData.update(player, function(profile)
		local state = Daily.loginState(profile.login)
		if not Daily.canClaim(state, time) then
			return
		end
		day = state.step
		profile.login = { lastClaimDay = Daily.today(time), step = state.step % Daily.CALENDAR_DAYS + 1 }
		local pioneer = Pioneer.normalize(profile.pioneer)
		if state.step ~= Daily.CALENDAR_DAYS or not Pioneer.isPioneer(pioneer) then
			return
		end
		-- No evita las que ya tiene: una repetida se cambia por Ámbar de su rareza.
		local mountId = PetRoll.rollPioneer(rng)
		local amber = 0
		if (profile.mounts[mountId] or 0) > 0 then
			amber = Config.Egg.DuplicateAmber[Mounts[mountId].rarity] or 0
			profile.amber += amber
			Analytics.amber(player, "Source", amber, profile.amber, "PioneerDuplicate")
		else
			profile.mounts[mountId] = 1
			if profile.activeMount == "" then
				profile.activeMount = mountId
			end
		end
		pioneer.cycles += 1
		profile.pioneer = pioneer :: any
		roll = { mount = mountId, amber = amber }
	end)
	if not day then
		return nil, nil, nil
	end
	local claimed = day :: number
	local lines = Retention.grant(player, Config.Daily.Calendar[claimed], false, "LoginCalendar")
	if roll then
		local mount = Mounts[roll.mount]
		local args = { icon = mount.icon, name = { mount.name }, amber = roll.amber }
		table.insert(
			lines,
			if roll.amber > 0
				then { later("🌟 Tirada de pioneros: {icon} {name} otra vez (+{amber} ✨ Ámbar)"), args }
				else { later("🌟 Tirada de pioneros: ¡{icon} {name}!"), args }
		)
		Analytics.event(player, "PioneerRoll", 1, { roll.mount, if roll.amber > 0 then "Duplicate" else "New" })
	end
	return claimed, lines, roll
end

-- La ventana de bienvenida se ha visto (Shared/Pioneer.shouldWelcome no la repite enseguida).
function Retention.welcomeSeen(player: Player)
	PlayerData.update(player, function(profile)
		local pioneer = Pioneer.normalize(profile.pioneer)
		pioneer.welcomeAt = now()
		profile.pioneer = pioneer :: any
	end)
end

-- ¿Vale "missionId" para la clase "slot"? Una dificultad diaria ("Media" = la del rol) o "Semanal".
local function fits(missionId: string, slot: string, role: string): boolean
	local mission = Missions[missionId]
	if slot == "Semanal" then
		return mission.weekly == true
	elseif mission.weekly or mission.difficulty ~= slot then
		return false
	end
	return if slot == "Media" then mission.role == role else mission.role == nil
end

-- La clase de una misión ya repartida (para cambiarla por otra igual).
local function slotOf(missionId: string): string
	local mission = Missions[missionId]
	return if mission.weekly then "Semanal" else mission.difficulty or "Facil"
end

-- Una misión al azar de la clase "slot", sin repetir "taken" ni una "family" de "families".
local function pickMission(
	slot: string,
	role: string,
	taken: { [string]: boolean },
	families: { [string]: boolean }?
): string?
	local candidates = {}
	for missionId, mission in Missions do
		if
			fits(missionId, slot, role)
			and not taken[missionId]
			and not (families and mission.family and families[mission.family])
		then
			table.insert(candidates, missionId)
		end
	end
	if #candidates == 0 then
		return nil
	end
	table.sort(candidates)
	return candidates[rng:NextInteger(1, #candidates)]
end

local function newMission(missionId: string): Daily.DailyMission
	return { id = missionId, progress = 0, done = false }
end

-- ¿Hay que renovar las misiones (otro día u otra semana) o cambiar la del rol?
local function needsRefresh(profile: PlayerData.Profile, time: number): boolean
	local state = Daily.missionState(profile.daily)
	return state.day ~= Daily.today(time)
		or state.role ~= Progression.validRole(profile.selectedRole)
		or Daily.weeklyState(profile.weekly).week ~= Daily.week(time)
end

local function refreshMissions(profile: PlayerData.Profile, time: number)
	local state = Daily.missionState(profile.daily)
	local today = Daily.today(time)
	local role = Progression.validRole(profile.selectedRole)
	if state.day ~= today then
		local taken = {}
		local missions: { Daily.DailyMission } = {}
		for _, difficulty in Config.Daily.Difficulties do
			local missionId = pickMission(difficulty, role, taken)
			if missionId then
				taken[missionId] = true
				table.insert(missions, newMission(missionId))
			end
		end
		state = { day = today, role = role, missions = missions, rerolls = 0 }
	elseif state.role ~= role then
		-- Otro rol: su misión cambia por una del nuevo (si la del viejo ya estaba cumplida, se queda).
		for index, mission in state.missions do
			if Missions[mission.id].role and not mission.done then
				local replacement = pickMission("Media", role, {})
				if replacement then
					state.missions[index] = newMission(replacement)
				end
			end
		end
		state.role = role
	end
	profile.daily = state :: any

	local week = Daily.week(time)
	if Daily.weeklyState(profile.weekly).week ~= week then
		local taken, families = {}, {}
		local missions: { Daily.DailyMission } = {}
		for _ = 1, Config.Daily.WeeklyMissions do
			local missionId = pickMission("Semanal", role, taken, families)
			if missionId then
				taken[missionId] = true
				local family = Missions[missionId].family
				if family then
					families[family] = true
				end
				table.insert(missions, newMission(missionId))
			end
		end
		profile.weekly = { week = week, missions = missions, rerolls = 0, bonus = false } :: any
	end
end

-- Pone al día las misiones del jugador si ha cambiado el día, la semana o su rol (al cargar, al
-- elegir rol).
function Retention.refresh(player: Player)
	local profile = PlayerData.get(player)
	if profile and needsRefresh(profile, now()) then
		PlayerData.update(player, function(current)
			refreshMissions(current, now())
		end)
	end
end

-- Llama a "callback" con cada aviso de progress (el contrato de expedición de la Isla, ContractService,
-- cuenta con los mismos avisos que las misiones).
function Retention.onProgress(callback: (player: Player, event: string, amount: number, key: string?) -> ())
	table.insert(progressListeners, callback)
end

-- Lo cuentan los servicios de la Isla y de Dunas: "event" como en Data/Missions ("Kill", "Gather"…).
-- "amount" se suma (o, en las misiones "best", cuenta el más alto); "key" es lo que cuentan las
-- "distinct" (la especie del mono) y lo que miran los contratos (el jefe, el recurso, la pieza).
function Retention.progress(player: Player, event: string, amount: number?, key: string?)
	for _, listener in progressListeners do
		task.spawn(listener, player, event, amount or 1, key)
	end
	local events = pending[player]
	if not events then
		events = {}
		pending[player] = events
	end
	local entry = events[event]
	if not entry then
		entry = { sum = 0, best = 0, keys = {} }
		events[event] = entry
	end
	local value = amount or 1
	entry.sum += value
	entry.best = math.max(entry.best, value)
	if key then
		entry.keys[key] = true
	end
end

-- Avanza las misiones de "list" con "events" y apunta en "completed" las que se acaban de cumplir.
local function advance(list: { Daily.DailyMission }, events: Events, completed: { string })
	for _, mission in list do
		local definition = Missions[mission.id]
		local entry = events[definition.event]
		if entry and not mission.done then
			if definition.distinct then
				local seen = {}
				for _, key in mission.seen or {} do
					seen[key] = true
				end
				for key in entry.keys do
					seen[key] = true
				end
				local keys = {}
				for key in seen do
					table.insert(keys, key)
				end
				table.sort(keys)
				mission.seen = keys
				mission.progress = math.min(definition.target, #keys)
			elseif definition.best then
				mission.progress = math.min(definition.target, math.max(mission.progress, entry.best))
			else
				mission.progress = math.min(definition.target, mission.progress + entry.sum)
			end
			if mission.progress >= definition.target then
				mission.done = true
				mission.seen = nil
				table.insert(completed, mission.id)
			end
		end
	end
end

-- Apunta lo avanzado en las misiones del día ("daily") y de la semana ("weekly") y entrega las que se
-- acaban de cumplir (y el extra de la semana si ya están todas).
local function deliver(player: Player, events: Events, daily: boolean, weekly: boolean)
	local completed: { string } = {}
	local bonus = false
	PlayerData.update(player, function(profile)
		local time = now()
		if needsRefresh(profile, time) then
			refreshMissions(profile, time)
		end
		if daily then
			local state = Daily.missionState(profile.daily)
			advance(state.missions, events, completed)
			profile.daily = state :: any
		end
		if weekly then
			local state = Daily.weeklyState(profile.weekly)
			advance(state.missions, events, completed)
			if not state.bonus and Daily.allDone(state.missions) then
				state.bonus = true
				bonus = true
			end
			profile.weekly = state :: any
		end
	end)
	for _, missionId in completed do
		local definition = Missions[missionId]
		local lines = Retention.grant(player, definition.reward, true, "DailyMission")
		local args = { mission = Daily.missionArg(missionId), lines = { list = lines, sep = " · " } }
		if definition.weekly then
			Remotes.Notify:FireClient(player, "📆 ¡Semanal cumplida! {mission}: {lines}", args)
		else
			Remotes.Notify:FireClient(player, "🎯 ¡Misión cumplida! {mission}: {lines}", args)
		end
	end
	if bonus then
		local lines = Retention.grant(player, Config.Daily.WeeklyBonus, true, "WeeklyBonus")
		Remotes.Notify:FireClient(
			player,
			"🏅 ¡Todas las semanales cumplidas! Extra: {lines}",
			{ lines = { list = lines, sep = " · " } }
		)
	end
end

local function flush(player: Player)
	local events = pending[player]
	pending[player] = nil
	if events and PlayerData.get(player) then
		deliver(player, events, true, true)
	end
end

-- Apunta ya lo pendiente (antes de un teletransporte: al acabar la partida en la Isla o en Dunas).
function Retention.flushNow(player: Player)
	flush(player)
end

-- Cambia gratis una misión sin cumplir ("daily" o "weekly", su posición) por otra de la misma clase
-- que no tenga ya. Devuelve si la ha cambiado y el aviso para el jugador (plantilla y argumentos).
function Retention.reroll(player: Player, scope: string, index: number): (boolean, string, any?)
	local profile = PlayerData.get(player)
	if not profile then
		return false, later("Tus datos aún se están cargando"), nil
	end
	Retention.refresh(player)
	local message = later("No se puede cambiar esa misión")
	local args: any? = nil
	local changed = false
	PlayerData.update(player, function(current)
		local role = Progression.validRole(current.selectedRole)
		local state: any = if scope == "weekly"
			then Daily.weeklyState(current.weekly)
			else Daily.missionState(current.daily)
		local limit = if scope == "weekly" then Config.Daily.WeeklyRerolls else Config.Daily.DailyRerolls
		local mission = state.missions[index]
		if not mission or mission.done then
			return
		elseif state.rerolls >= limit then
			message = if scope == "weekly"
				then later("Ya has cambiado una semanal esta semana")
				else later("Ya has usado el cambio de hoy")
			return
		end
		local taken, families = {}, {}
		for other, entry in state.missions do
			taken[entry.id] = true
			local family = Missions[entry.id].family
			if family and other ~= index then
				families[family] = true
			end
		end
		local replacement = pickMission(slotOf(mission.id), role, taken, families)
		if not replacement then
			message = later("No hay otra misión de esa clase")
			return
		end
		state.missions[index] = newMission(replacement)
		state.rerolls += 1
		if scope == "weekly" then
			current.weekly = state
		else
			current.daily = state
		end
		changed = true
		message = later("🔄 Nueva misión: {mission}")
		args = { mission = Daily.missionArg(replacement) }
	end)
	return changed, message, args
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

-- Prueba (panel de Studio): el próximo cobro es el día 7 y se puede cobrar ya (tirada de pioneros).
function Retention.debugCalendarDay7(player: Player)
	PlayerData.update(player, function(profile)
		profile.login = { lastClaimDay = Daily.today(now()) - 1, step = Daily.CALENDAR_DAYS }
	end)
end

-- Prueba (panel de Studio): hace como si las semanales fueran de la semana pasada.
function Retention.debugNextWeek(player: Player)
	PlayerData.update(player, function(profile)
		local weekly = Daily.weeklyState(profile.weekly)
		weekly.week = Daily.week(now()) - 1
		profile.weekly = weekly :: any
	end)
	Retention.refresh(player)
end

-- Prueba (panel de Studio): cumple todas las misiones del día ("weekly": las de la semana).
function Retention.debugCompleteMissions(player: Player, weekly: boolean?)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local list = if weekly
		then Daily.weeklyState(profile.weekly).missions
		else Daily.missionState(profile.daily).missions
	local events: Events = {}
	for _, mission in list do
		local definition = Missions[mission.id]
		local keys = {}
		for index = 1, definition.target do
			keys[`Prueba{index}`] = true
		end
		local entry = events[definition.event]
		if not entry or entry.sum < definition.target then
			events[definition.event] = { sum = definition.target, best = definition.target, keys = keys }
		end
	end
	deliver(player, events, not weekly, weekly == true)
end

return Retention
