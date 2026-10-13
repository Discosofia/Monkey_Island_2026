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
-- "SelectedRole" y "Progress", un JSON con XP, talentos y mejoras; ver Shared/Progression).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

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
}

type Session = {
	profile: Profile,
	saveable: boolean, -- false si no se pudo cargar de DataStore (datos temporales)
	dirty: boolean,
}

local PlayerData = {}

local sessions: { [Player]: Session } = {}
local loadedSignal = Instance.new("BindableEvent")
local store: DataStore? = nil

local function defaultProfile(): Profile
	return {
		version = 1,
		amber = 0,
		bestDays = 0,
		matches = 0,
		roleXp = {},
		talents = {},
		upgrades = {},
		pets = {},
		selectedRole = "Recolector",
		tutorialDone = false,
		bestiary = {},
	}
end

-- Rellena los campos que falten (datos de versiones anteriores).
local function reconcile(data: any): Profile
	local profile = defaultProfile()
	if typeof(data) == "table" then
		for key, value in data do
			if (profile :: any)[key] ~= nil and typeof(value) == typeof((profile :: any)[key]) then
				(profile :: any)[key] = value
			end
		end
	end
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

local function publish(player: Player, profile: Profile)
	player:SetAttribute("Amber", profile.amber)
	player:SetAttribute("BestDays", profile.bestDays)
	player:SetAttribute("SelectedRole", profile.selectedRole)
	player:SetAttribute(
		"Progress",
		HttpService:JSONEncode({
			roleXp = profile.roleXp,
			talents = profile.talents,
			upgrades = profile.upgrades,
			matches = profile.matches,
			tutorialDone = profile.tutorialDone,
			bestiary = profile.bestiary,
		})
	)
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

local function save(player: Player, release: boolean)
	local session = sessions[player]
	local dataStore = getStore()
	if not (session and session.saveable and dataStore) then
		return
	end
	local profile = session.profile
	local ok, err = pcall(function()
		dataStore:UpdateAsync(keyFor(player), function(current: any)
			local lock = if typeof(current) == "table" then current.session else nil
			-- Si otro servidor se quedó los datos, no los pisamos.
			if typeof(lock) == "table" and lock.jobId ~= game.JobId then
				return nil
			end
			local stored = table.clone(profile) :: any
			stored.session = if release then nil else { jobId = game.JobId, time = os.time() }
			return stored
		end)
	end)
	if ok then
		session.dirty = false
	else
		warn(`[PlayerData] Error al guardar a {player.Name}: {err}`)
	end
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
	}
	sessions[player] = session
	publish(player, session.profile)
	loadedSignal:Fire(player)
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
	publish(player, session.profile)
end

-- Guarda ya (por ejemplo, antes de un viaje). Puede tardar: llámala desde un hilo propio.
function PlayerData.saveNow(player: Player)
	save(player, false)
end

-- Arranca la carga, el guardado automático y el guardado al cerrar. Llamar una vez por servidor.
function PlayerData.start()
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
