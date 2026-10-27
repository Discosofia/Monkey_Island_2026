--!strict
-- Datos guardados de cada jugador (Fase 2.8): Ámbar, récord de días, partidas, XP por rol,
-- talentos y mejoras compradas. Lo usan el Lobby y la Isla.
--
-- Funciona como ProfileStore pero sin librerías externas:
--   - Carga con UpdateAsync y "bloquea" la sesión (el servidor que tiene los datos se apunta en
--     ellos). Si otro servidor los tiene (por ejemplo, la Isla aún guardando al viajar al Lobby),
--     espera y reintenta; si el bloqueo es muy viejo (servidor caído), se lo queda.
--   - Guarda cada Config.Data.AutosaveSeconds, al salir el jugador y al cerrarse el servidor.
--   - Si DataStore falla (por ejemplo, en Studio sin "Enable Studio Access to API Services"), el
--     jugador juega con datos temporales y se avisa en la Salida: no se pierde nada guardado.
-- Los valores que ve el cliente se copian a atributos del Player ("Amber", "BestDays",
-- "SelectedRole" y "Progress", un JSON con XP, talentos y mejoras; ver Shared/Progression), y
-- "Settings", un JSON con los ajustes del jugador (Shared/Settings), que el cliente cambia con
-- Remotes.SaveSettings, "Eggs", un JSON con sus huevos guardados (Shared/EggIncubation), y "Retention",
-- un JSON con sus provisiones, su calendario y sus misiones del día y de la semana (ServerShared/Retention), y
-- "Season", un JSON con su progreso en el pase de temporada (Shared/SeasonPass).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)

export type Profile = {
	version: number,
	amber: number,
	bestDays: number,
	matches: number,
	roleXp: { [string]: number },
	talents: { [string]: number },
	upgrades: { [string]: number },
	pets: { [string]: number },
	selectedRole: string,
	tutorialDone: boolean,
	bestiary: { [string]: number }, -- monos derrotados por especie (diario de campo, Fase 4)
	activePet: string, -- mascota que lleva ("" = ninguna; Fase 5)
	rescues: number, -- partidas ganadas con la baliza (Fase 6)
	cosmetics: { [string]: string }, -- cosmético equipado por tipo (Trail, Title, Aura; Fase 6)
	settings: { [string]: any }, -- ajustes del jugador (Shared/Settings)
	-- Bucle de retención (versión 3, octubre de 2026):
	eggs: { [string]: any }, -- huevos guardados: nido, mochila y pendientes (Shared/EggIncubation)
	login: { [string]: any }, -- calendario de 7 días (ServerShared/Retention)
	daily: { [string]: any }, -- misiones del día (ServerShared/Retention)
	supplies: { [string]: number }, -- provisiones para la próxima partida en la Isla
	-- Arena de Dunas (versión 4, octubre de 2026): equipamiento comprado y puesto por rol,
	-- estadísticas y Ámbar ganado hoy en la arena (Shared/Arena).
	arena: { [string]: any },
	-- Guía de la primera vez en el Lobby hecha (roles y nido, LobbyGuideController; 20-10-2026).
	lobbyGuideDone: boolean,
	-- Paso de la guardia de esa guía hecho (parar el golpe del muñeco de sparring; Fase 10, C12). Aparte
	-- para que también lo hagan quienes ya tenían la guía hecha.
	combatGuideDone: boolean,
	-- Pase de temporada, misiones semanales y compras (versión 5, octubre de 2026):
	season: { [string]: any }, -- progreso en el pase de la temporada en curso (ServerShared/SeasonPass)
	weekly: { [string]: any }, -- misiones de la semana (ServerShared/Retention)
	purchases: { [string]: any }, -- recibos de Developer Products ya entregados (ServerShared/Purchases)
	-- Cosméticos que se tienen sin Game Pass: ganados jugando, del pase, comprados con Ámbar o con un
	-- Developer Product (ServerShared/CosmeticsServer). Antes "earnedCosmetics".
	ownedCosmetics: { [string]: boolean },
	-- Tiendas de cosméticos (versión 6, octubre de 2026): la oferta de hoy en Ámbar y la de esta semana
	-- en Robux de este jugador (Shared/CosmeticShop, CosmeticShopService del Lobby).
	cosmeticShop: { [string]: any },
	-- Mejor equipo fabricado en la Isla por rol (versión 7, octubre de 2026): { armor = id de Data/Armor,
	-- weapon = nivel 1–4 del arma de rol }. Se luce en el Lobby y en Dunas, solo como aspecto
	-- (ServerShared/CosmeticsServer).
	bestGear: { [string]: any },
	-- Monturas (versión 8, Fase 11): las que tiene (Data/Mounts) y la que lleva ("" = ninguna).
	mounts: { [string]: number },
	activeMount: string,
	-- Avisos para la próxima vez que entra (versión 9, 26-10-2026): se enseñan una vez y se borran.
	notices: { string },
}

type Session = {
	profile: Profile,
	saveable: boolean, -- false si no se pudo cargar de DataStore (datos temporales)
	dirty: boolean,
	-- Mascota activa publicada la última vez ("ActivePet"); false hasta la primera publicación.
	publishedPet: string? | false,
}

local PlayerData = {}

local sessions: { [Player]: Session } = {}
local loadedSignal = Instance.new("BindableEvent")
local store: DataStore? = nil

local function defaultProfile(): Profile
	return {
		version = 9,
		amber = 0,
		bestDays = 0,
		matches = 0,
		roleXp = {},
		talents = {},
		upgrades = {},
		pets = {},
		selectedRole = "Guerrero",
		tutorialDone = false,
		bestiary = {},
		activePet = "",
		rescues = 0,
		cosmetics = {},
		settings = Settings.defaults() :: any,
		eggs = {},
		login = {},
		daily = {},
		supplies = {},
		arena = {},
		lobbyGuideDone = false,
		combatGuideDone = false,
		season = {},
		weekly = {},
		purchases = { receipts = {} },
		ownedCosmetics = {},
		cosmeticShop = {},
		bestGear = {},
		mounts = {},
		activeMount = "",
		notices = {},
	}
end

-- Versión 9: se tiene una mascota (y una montura) de cada. Las copias de más se cambian por
-- Config.Egg.DuplicateAmber de su rareza, con un aviso al entrar.
-- Versión 8: las monturas ("mounts" y "activeMount"; "reconcile" los rellena vacíos).
-- Versión 7: el mejor equipo fabricado por rol ("bestGear"; "reconcile" lo rellena vacío).
-- Versión 6: las tiendas de cosméticos ("cosmeticShop"; "reconcile" lo rellena vacío).
-- Versión 5: pase de temporada, semanales y compras ("reconcile" los rellena vacíos); los cosméticos
-- ganados jugando ("earnedCosmetics") pasan a "ownedCosmetics", con los del pase y los comprados.
-- Versión 4: el campo "arena" (Dunas); "reconcile" ya lo rellena vacío.
-- Versión 3: campos nuevos del bucle de retención; "reconcile" ya los rellena vacíos.
-- Versión 2: el Recolector pasa a ser el Mago. Su XP se suma a la del Mago y los puntos que tenía
-- en talentos del Recolector quedan libres (esos talentos ya no existen).
local function migrate(profile: Profile, fromVersion: number, data: any)
	if fromVersion < 2 then
		local gathererXp = profile.roleXp.Recolector
		if gathererXp then
			profile.roleXp.Mago = (profile.roleXp.Mago or 0) + gathererXp
			profile.roleXp.Recolector = nil
		end
		for key in table.clone(profile.talents) do
			if string.sub(key, 1, #"Recolector.") == "Recolector." then
				profile.talents[key] = nil
			end
		end
		if profile.selectedRole == "Recolector" then
			profile.selectedRole = "Mago"
		end
	end
	if fromVersion < 5 and typeof(data) == "table" and typeof(data.earnedCosmetics) == "table" then
		for cosmeticId, earned in data.earnedCosmetics do
			if typeof(cosmeticId) == "string" and earned == true then
				profile.ownedCosmetics[cosmeticId] = true
			end
		end
	end
	if fromVersion < 9 then
		local refund = 0
		for petId, count in profile.pets do
			local pet = Pets[petId]
			if typeof(count) == "number" and count > 1 then
				refund += (count - 1) * (if pet then Config.Egg.DuplicateAmber[pet.rarity] or 0 else 0)
				profile.pets[petId] = 1
			end
		end
		for mountId, count in profile.mounts do
			if typeof(count) == "number" and count > 1 then
				profile.mounts[mountId] = 1
			end
		end
		if refund > 0 then
			profile.amber += refund
			table.insert(
				profile.notices,
				`🐾 Ahora tienes una mascota de cada: tus repetidas te dieron +{refund} ✨ Ámbar`
			)
		end
	end
	profile.version = defaultProfile().version
end

-- Rellena los campos que falten (datos de versiones anteriores) y los pone al día.
local function reconcile(data: any): Profile
	local profile = defaultProfile()
	local fromVersion = 1
	if typeof(data) == "table" then
		for key, value in data do
			if (profile :: any)[key] ~= nil and typeof(value) == typeof((profile :: any)[key]) then
				(profile :: any)[key] = value
			end
		end
		fromVersion = if typeof(data.version) == "number" then data.version else 1
	end
	migrate(profile, fromVersion, data)
	return profile
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
		return result
	end
	warn(`[PlayerData] No se pudo abrir DataStore: {result}`)
	return nil
end

local function keyFor(player: Player): string
	return `u_{player.UserId}`
end

local function publish(player: Player, session: Session)
	local profile = session.profile
	player:SetAttribute("Amber", profile.amber)
	player:SetAttribute("BestDays", profile.bestDays)
	-- Rescates (partidas ganadas): el cliente del Lobby lo enseña en la ventana del ranking.
	player:SetAttribute("Rescues", profile.rescues)
	player:SetAttribute("SelectedRole", profile.selectedRole)
	-- Solo si la tiene de verdad en su colección, y solo cuando cambia la guardada: así no pisa una
	-- mascota puesta solo para esta partida (la de prueba del panel, DebugService) cada vez que se
	-- actualiza otra cosa del perfil (el diario de campo al derrotar un mono, por ejemplo).
	local hasPet = profile.activePet ~= "" and (profile.pets[profile.activePet] or 0) > 0
	local petId = if hasPet then profile.activePet else nil
	if session.publishedPet == false or session.publishedPet ~= petId then
		session.publishedPet = petId
		player:SetAttribute("ActivePet", petId)
	end
	-- Montura que lleva, solo si la tiene (ServerShared/MountServer pone "Mounted" al montarla).
	local hasMount = profile.activeMount ~= "" and (profile.mounts[profile.activeMount] or 0) > 0
	player:SetAttribute("ActiveMount", if hasMount then profile.activeMount else nil)
	player:SetAttribute(
		"Progress",
		HttpService:JSONEncode({
			roleXp = profile.roleXp,
			talents = profile.talents,
			upgrades = profile.upgrades,
			matches = profile.matches,
			tutorialDone = profile.tutorialDone,
			bestiary = profile.bestiary,
			pets = profile.pets,
			mounts = profile.mounts,
			cosmetics = profile.cosmetics,
		})
	)
	player:SetAttribute("Settings", HttpService:JSONEncode(Settings.sanitize(profile.settings)))
	player:SetAttribute("Eggs", HttpService:JSONEncode(EggIncubation.normalize(profile.eggs)))
	player:SetAttribute(
		"Retention",
		HttpService:JSONEncode({
			supplies = profile.supplies,
			login = profile.login,
			daily = profile.daily,
			weekly = profile.weekly,
		})
	)
	-- Arena de Dunas: lo comprado y lo puesto (ServerShared/ArenaShop), estadísticas y Ámbar de hoy.
	player:SetAttribute("Arena", HttpService:JSONEncode(profile.arena))
	player:SetAttribute("Season", HttpService:JSONEncode(profile.season))
	player:SetAttribute("LobbyGuideDone", profile.lobbyGuideDone)
	player:SetAttribute("CombatGuideDone", profile.combatGuideDone)
end

-- Carga y bloquea los datos. Devuelve el perfil (o nil y si fue por un error de DataStore).
local function loadLocked(player: Player): (Profile?, boolean)
	local dataStore = getStore()
	if not dataStore then
		return nil, true
	end
	for attempt = 1, Config.Data.LoadAttempts do
		local blocked = false
		local profile: Profile? = nil
		local ok, err = pcall(function()
			dataStore:UpdateAsync(keyFor(player), function(current: any)
				local lock = if typeof(current) == "table" then current.session else nil
				local now = os.time()
				local lockedByOther = typeof(lock) == "table" and lock.jobId ~= game.JobId
				local stale = typeof(lock) == "table" and now - (lock.time or 0) > Config.Data.LockTimeoutSeconds
				if lockedByOther and not stale and attempt < Config.Data.LoadAttempts then
					blocked = true
					return nil -- no se cambia nada; se reintenta
				end
				local data = reconcile(current)
				local stored = table.clone(data) :: any
				stored.session = { jobId = game.JobId, time = now }
				profile = data
				return stored
			end)
		end)
		if not ok then
			warn(`[PlayerData] Error al cargar a {player.Name} (intento {attempt}): {err}`)
			-- 403: Studio sin acceso a las API. Reintentar no sirve.
			if attempt == Config.Data.LoadAttempts or string.find(tostring(err), "403") then
				return nil, true
			end
		elseif not blocked and profile then
			return profile, false
		end
		task.wait(Config.Data.RetrySeconds)
	end
	return nil, true
end

-- Devuelve true si los datos quedaron escritos en DataStore.
local function save(player: Player, release: boolean): boolean
	local session = sessions[player]
	local dataStore = getStore()
	if not (session and session.saveable and dataStore) then
		return false
	end
	local profile = session.profile
	local written = false
	local ok, err = pcall(function()
		dataStore:UpdateAsync(keyFor(player), function(current: any)
			local lock = if typeof(current) == "table" then current.session else nil
			-- Si otro servidor se quedó los datos, no los pisamos.
			if typeof(lock) == "table" and lock.jobId ~= game.JobId then
				written = false
				return nil
			end
			local stored = table.clone(profile) :: any
			stored.session = if release then nil else { jobId = game.JobId, time = os.time() }
			written = true
			return stored
		end)
	end)
	if ok then
		session.dirty = false
	else
		written = false
		warn(`[PlayerData] Error al guardar a {player.Name}: {err}`)
	end
	return written
end

local function onPlayerAdded(player: Player)
	local profile, failed = loadLocked(player)
	if not player.Parent then
		return
	end
	if not profile then
		warn(`[PlayerData] {player.Name} juega con datos temporales (no se guardarán).`)
	end
	local session: Session = {
		profile = profile or defaultProfile(),
		saveable = not failed and profile ~= nil,
		dirty = false,
		publishedPet = false,
	}
	sessions[player] = session
	publish(player, session)
	loadedSignal:Fire(player)
	if #session.profile.notices > 0 then
		task.delay(Config.Data.NoticeDelaySeconds, function()
			if sessions[player] ~= session then
				return
			end
			for _, notice in session.profile.notices do
				Remotes.Notify:FireClient(player, notice)
			end
			table.clear(session.profile.notices)
			session.dirty = true
		end)
	end
end

local function onPlayerRemoving(player: Player)
	save(player, true)
	sessions[player] = nil
end

-- Perfil del jugador, o nil si aún no ha cargado.
function PlayerData.get(player: Player): Profile?
	local session = sessions[player]
	return if session then session.profile else nil
end

-- Espera a que carguen los datos del jugador (o a que se vaya). Devuelve el perfil o nil.
function PlayerData.waitFor(player: Player): Profile?
	while player.Parent and not sessions[player] do
		loadedSignal.Event:Wait()
	end
	return PlayerData.get(player)
end

-- Cambia el perfil con "change" y lo marca para guardar. Actualiza los atributos del cliente.
function PlayerData.update(player: Player, change: (profile: Profile) -> ())
	local session = sessions[player]
	if not session then
		return
	end
	change(session.profile)
	session.dirty = true
	publish(player, session)
end

-- Guarda ya (por ejemplo, antes de un viaje o al entregar una compra). Puede tardar: llámala desde
-- un hilo propio. Devuelve true si quedó guardado (false con datos temporales o si DataStore falla).
function PlayerData.saveNow(player: Player): boolean
	return save(player, false)
end

-- true si los datos del jugador se guardan de verdad (false: datos temporales, sin DataStore).
function PlayerData.isSaveable(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.saveable
end

-- Lo equipado de otro jugador, conectado o no (el marco de los puestos del ranking, LeaderboardService),
-- leído sin bloquear su perfil. nil si no tiene datos o DataStore falla. Puede tardar: desde un hilo.
function PlayerData.peekCosmetics(userId: number): { [string]: string }?
	local dataStore = getStore()
	if not dataStore or userId <= 0 then
		return nil
	end
	local ok, data = pcall(function()
		return dataStore:GetAsync(`u_{userId}`)
	end)
	if ok and typeof(data) == "table" and typeof(data.cosmetics) == "table" then
		return data.cosmetics
	end
	return nil
end

-- Arranca la carga, el guardado automático y el guardado al cerrar. Llamar una vez por servidor.
function PlayerData.start()
	Remotes.SaveSettings.OnServerEvent:Connect(function(player, raw)
		local values = Settings.sanitize(raw)
		PlayerData.update(player, function(profile)
			profile.settings = values :: any
		end)
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveSeconds)
			for player, session in sessions do
				if session.dirty then
					task.spawn(save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

return PlayerData
