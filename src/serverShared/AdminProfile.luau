--!strict
-- Perfil de un jugador desde el panel de administradores (T4d), en los tres places. Por Remotes.AdminProfile:
--   - "View" (UserId o nombre de usuario): devuelve su resumen, lo que tiene y sus copias de seguridad.
--     De un jugador de este servidor, su perfil cargado; de otro, lo guardado (solo para ver y restaurar).
--   - "Remove" (UserId, tipo, id): le quita una mascota, una montura, un cosmético o un huevo.
--   - "Reset" (UserId, "Calendar" | "Missions"): el calendario de 7 días vuelve al día 1, o las
--     misiones del día y de la semana se sortean de nuevo.
--   - "Backup" (UserId): copia lo guardado ahora (PlayerData.backup).
--   - "Restore" (UserId, clave): pone esa copia. Si está en este servidor, primero se le expulsa y se
--     espera a que su perfil quede guardado y suelto; si juega en otro servidor, no se puede.
-- Lo de quitar y reiniciar solo vale con el jugador en este servidor (su perfil está bloqueado aquí).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Daily = require(ReplicatedStorage.Shared.Daily)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local Pass = require(ReplicatedStorage.Shared.SeasonPass)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AdminLog = require(script.Parent.AdminLog)
local CosmeticsServer = require(script.Parent.CosmeticsServer)
local MountServer = require(script.Parent.MountServer)
local PlayerData = require(script.Parent.PlayerData)
local RequestCooldown = require(script.Parent.RequestCooldown)
local Retention = require(script.Parent.Retention)

-- Segundos que se espera a que un jugador expulsado suelte su perfil antes de restaurarlo.
local RELEASE_WAIT = 20
local EGG_PLACES = { nest = "nido", bag = "mochila", pending = "pendiente" }

export type Item = { kind: string, id: string, label: string, rarity: string }

local AdminProfile = {}

local canRequest = RequestCooldown.new(1)

local function count(map: any): number
	local total = 0
	if typeof(map) == "table" then
		for _, value in map do
			if value then
				total += 1
			end
		end
	end
	return total
end

local function missionsDone(state: any): (number, number)
	local done, total = 0, 0
	if typeof(state) == "table" and typeof(state.missions) == "table" then
		for _, mission in state.missions do
			total += 1
			if typeof(mission) == "table" and mission.done then
				done += 1
			end
		end
	end
	return done, total
end

-- Líneas del resumen a partir de un perfil (cargado o lo guardado, que puede venir de una versión vieja).
local function summary(data: any): { string }
	local function number(key: string): number
		return if typeof(data[key]) == "number" then data[key] else 0
	end
	local eggs = EggIncubation.normalize(data.eggs)
	local inNest = {}
	for slot = 1, #EggIncubation.NEST_KEYS do
		local egg = EggIncubation.inSlot(eggs, slot)
		if egg then
			table.insert(inNest, Rarities[egg.rarity].name)
		end
	end
	local nest = if #inNest > 0 then `{table.concat(inNest, " y ")} en el nido` else "nido vacío"
	local today, todayTotal = missionsDone(data.daily)
	local week, weekTotal = missionsDone(data.weekly)
	local currentSeason = Pass.info(Pass.now()).season
	local season = Pass.normalize(data.season, if currentSeason then currentSeason.id else nil)
	local arena = if typeof(data.arena) == "table" and typeof(data.arena.stats) == "table" then data.arena.stats else {}
	return {
		`✨ Ámbar: {number("amber")}`,
		`🎮 Partidas: {number("matches")} · 🏆 Mejor: {number("bestDays")} días · 🚁 Rescates: {number(
			"rescues"
		)}`,
		`🐾 Mascotas: {count(data.pets)} · 🦙 Monturas: {count(data.mounts)} · 👕 Cosméticos: {count(
			data.ownedCosmetics
		)}`,
		`🥚 Huevos: {nest} · mochila {#eggs.bag} · pendientes {#eggs.pending}`,
		`📅 Calendario: día {Daily.loginState(data.login).step} de {Daily.CALENDAR_DAYS}`,
		`🎯 Misiones: hoy {today}/{todayTotal} · semana {week}/{weekTotal}`,
		`🎟️ Pase: nivel {Pass.earnedLevel(season.xp)} · premium: {if season.premium then "sí" else "no"}`,
		`⚔️ Arena: {arena.wins or 0} victorias de {arena.matches or 0}`,
	}
end

-- Lo que se le puede quitar a un jugador cargado.
local function items(profile: PlayerData.Profile): { Item }
	local list: { Item } = {}
	local function add(kind: string, id: string, label: string, rarity: string)
		table.insert(list, { kind = kind, id = id, label = label, rarity = rarity })
	end
	for petId, owned in profile.pets do
		local pet = Pets[petId]
		if pet and owned > 0 then
			add("Pet", petId, `{pet.icon} {pet.name}`, pet.rarity)
		end
	end
	for mountId, owned in profile.mounts do
		local mount = Mounts[mountId]
		if mount and owned > 0 then
			add("Mount", mountId, `{mount.icon} {mount.name}`, mount.rarity)
		end
	end
	local eggs = EggIncubation.normalize(profile.eggs)
	for slot = 1, #EggIncubation.NEST_KEYS do
		local egg = EggIncubation.inSlot(eggs, slot)
		if egg then
			add("Egg", `nest:{slot}`, `🥚 Huevo {Rarities[egg.rarity].name} · nido`, egg.rarity)
		end
	end
	for _, where in { "bag", "pending" } do
		for index, egg in (eggs :: any)[where] do
			add("Egg", `{where}:{index}`, `🥚 Huevo {Rarities[egg.rarity].name} · {EGG_PLACES[where]}`, egg.rarity)
		end
	end
	for cosmeticId in profile.ownedCosmetics do
		local cosmetic = Cosmetics[cosmeticId]
		if cosmetic then
			add("Cosmetic", cosmeticId, `{cosmetic.icon} {cosmetic.name}`, cosmetic.rarity)
		end
	end
	return list
end

local function backups(userId: number): { { key: string, label: string } }
	local list = {}
	for _, key in PlayerData.listBackups(userId, Config.Data.BackupsShown) do
		local label, stamp = string.match(key, `^u_{userId}_(.+)_(%d+)$`)
		local time = tonumber(stamp)
		table.insert(list, {
			key = key,
			label = `{label or key} · {if time then os.date("%d-%m-%Y %H:%M", time) else "?"}`,
		})
	end
	return list
end

-- Manda al administrador lo que se sabe del jugador "userId" (en este servidor o no).
local function view(admin: Player, userId: number, name: string)
	local target = Players:GetPlayerByUserId(userId)
	local profile = if target then PlayerData.get(target) else nil
	local data: any = profile or PlayerData.readStored(userId)
	if not data then
		Remotes.AdminProfile:FireClient(admin, { userId = userId, name = name, online = false, missing = true })
		return
	end
	local where = if profile
		then "🟢 En este servidor"
		elseif typeof(data.session) == "table" then "🔒 Jugando en otro servidor (solo ver)"
		else "⚫ Desconectado (solo ver y restaurar)"
	local lines = summary(data)
	table.insert(lines, 1, where)
	Remotes.AdminProfile:FireClient(admin, {
		userId = userId,
		name = name,
		online = profile ~= nil,
		lines = lines,
		items = if profile then items(profile) else {},
		backups = backups(userId),
	})
end

local function removeItem(admin: Player, target: Player, kind: string, id: string): string?
	local profile = PlayerData.get(target)
	if not profile then
		return nil
	end
	if kind == "Cosmetic" then
		if not CosmeticsServer.revoke(target, id) then
			return "Ese cosmético no lo tiene guardado (puede venir de un Game Pass)"
		end
	elseif kind == "Pet" and (profile.pets[id] or 0) > 0 then
		PlayerData.update(target, function(current)
			current.pets[id] = nil
			if current.activePet == id then
				current.activePet = ""
			end
		end)
	elseif kind == "Mount" and (profile.mounts[id] or 0) > 0 then
		if profile.activeMount == id then
			MountServer.dismount(target)
		end
		PlayerData.update(target, function(current)
			current.mounts[id] = nil
			if current.activeMount == id then
				current.activeMount = ""
			end
		end)
	elseif kind == "Egg" then
		local where, index = string.match(id, "^(%a+):(%d+)$")
		local position = tonumber(index)
		local removed = false
		PlayerData.update(target, function(current)
			local eggs = EggIncubation.normalize(current.eggs)
			if where == "nest" and position and EggIncubation.inSlot(eggs, position) then
				EggIncubation.setSlot(eggs, position, nil)
				removed = true
			elseif (where == "bag" or where == "pending") and position and (eggs :: any)[where][position] then
				table.remove((eggs :: any)[where], position)
				removed = true
			end
			current.eggs = eggs :: any
		end)
		if not removed then
			return nil
		end
	else
		return nil
	end
	task.spawn(PlayerData.saveNow, target)
	AdminLog.add(admin, "Quitar", `{kind} {id} a {target.DisplayName} (@{target.Name})`)
	return `🗑️ Quitado a {target.DisplayName}`
end

local function reset(admin: Player, target: Player, what: string): string?
	if what == "Calendar" then
		PlayerData.update(target, function(current)
			current.login = {}
		end)
	elseif what == "Missions" then
		PlayerData.update(target, function(current)
			current.daily = {}
			current.weekly = {}
		end)
		Retention.refresh(target)
	else
		return nil
	end
	task.spawn(PlayerData.saveNow, target)
	local text = if what == "Calendar" then "calendario al día 1" else "misiones nuevas"
	AdminLog.add(admin, "Reiniciar", `{text} · {target.DisplayName} (@{target.Name})`)
	Remotes.Notify:FireClient(
		target,
		if what == "Calendar"
			then "📅 Un administrador ha reiniciado tu calendario: vuelves al día 1"
			else "🎯 Un administrador ha reiniciado tus misiones"
	)
	return `🔄 {target.DisplayName}: {text}`
end

local function restore(admin: Player, userId: number, key: string)
	local target = Players:GetPlayerByUserId(userId)
	if target then
		-- Su perfil está bloqueado aquí: sale, se guarda y se suelta, y entonces se restaura.
		target:Kick("Un administrador va a restaurar tu progreso. Vuelve a entrar en un minuto.")
		local started = os.clock()
		while PlayerData.hasSession(target) and os.clock() - started < RELEASE_WAIT do
			task.wait(0.5)
		end
	end
	local ok, text = PlayerData.restore(userId, key)
	if ok then
		AdminLog.add(admin, "Restaurar", `{userId} · {key}`)
	end
	Remotes.Notify:FireClient(admin, if ok then `📥 {text}: ya puede entrar` else `⚠️ {text}`)
end

local function onRequest(admin: Player, isAdmin: (Player) -> boolean, action: any, who: any, a: any, b: any)
	if not isAdmin(admin) or not canRequest(admin) then
		return
	end
	-- Por nombre (alguien que no está) o por UserId.
	local userId: number? = if typeof(who) == "number" then who else nil
	local name = ""
	if typeof(who) == "string" and who ~= "" then
		local ok, found = pcall(function()
			return Players:GetUserIdFromNameAsync(who)
		end)
		if not ok or typeof(found) ~= "number" then
			Remotes.Notify:FireClient(admin, `No existe el usuario «{who}»`)
			return
		end
		userId, name = found, `@{who}`
	end
	if not userId then
		return
	end
	local target = Players:GetPlayerByUserId(userId)
	if name == "" then
		name = if target then target.DisplayName else tostring(userId)
	end

	if action == "Backup" then
		if target then
			PlayerData.saveNow(target)
		end
		local key = PlayerData.backup(userId, "admin")
		if key then
			AdminLog.add(admin, "Copia", `{name} · {key}`)
		end
		Remotes.Notify:FireClient(
			admin,
			if key then `📦 Copia hecha de {name}` else "⚠️ No se pudo hacer la copia"
		)
	elseif action == "Restore" and typeof(a) == "string" then
		restore(admin, userId, a)
		return
	elseif action == "Remove" or action == "Reset" then
		if not target or not PlayerData.get(target) then
			Remotes.Notify:FireClient(admin, "Eso solo se puede con el jugador en este servidor")
			return
		end
		local text = if action == "Remove"
				and typeof(a) == "string"
				and typeof(b) == "string"
			then removeItem(admin, target, a, b)
			elseif action == "Reset" and typeof(a) == "string" then reset(admin, target, a)
			else nil
		if text then
			Remotes.Notify:FireClient(admin, text)
		end
	elseif action ~= "View" then
		return
	end
	view(admin, userId, name)
end

function AdminProfile.start(isAdmin: (Player) -> boolean)
	Remotes.AdminProfile.OnServerEvent:Connect(function(admin: Player, action: any, who: any, a: any, b: any)
		onRequest(admin, isAdmin, action, who, a, b)
	end)
end

return AdminProfile
