--!strict
-- Registro de lo que hacen los administradores (T4), compartido por todos los servidores: DataStore
-- Config.AdminTools.LogStoreName, clave "log", con las Config.AdminTools.LogKeep acciones más nuevas.
-- Las acciones se juntan y se escriben cada LogFlushSeconds (y al cerrar el servidor) para no gastar
-- escrituras. También salen por la consola del servidor. El panel lo pide con Remotes.AdminLog.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Entry = { t: number, by: string, id: number, place: string, action: string, detail: string }

local KEY = "log"

local AdminLog = {}

local pending: { Entry } = {}
local place = "?"
local store: DataStore? = nil

local function getStore(): DataStore?
	if not store then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(Config.AdminTools.LogStoreName)
		end)
		store = if ok then result else nil
	end
	return store
end

-- Apunta una acción de "admin" (p. ej. "Give", "🐾 Capi para Ana").
function AdminLog.add(admin: Player, action: string, detail: string)
	print(`[Admin] {admin.Name} ({admin.UserId}) · {action} · {detail}`)
	table.insert(pending, {
		t = os.time(),
		by = admin.DisplayName,
		id = admin.UserId,
		place = place,
		action = action,
		detail = string.sub(detail, 1, 200),
	})
end

local function flush()
	local dataStore = getStore()
	if #pending == 0 or not dataStore then
		return
	end
	local batch = pending
	pending = {}
	local ok, err = pcall(function()
		dataStore:UpdateAsync(KEY, function(current: any)
			local list = if typeof(current) == "table" then current else {}
			for _, entry in batch do
				table.insert(list, entry)
			end
			while #list > Config.AdminTools.LogKeep do
				table.remove(list, 1)
			end
			return list
		end)
	end)
	if not ok then
		warn(`[AdminLog] No se pudo guardar el registro: {err}`)
		-- Se reintenta en la siguiente vuelta, delante de lo nuevo.
		table.move(pending, 1, #pending, #batch + 1, batch)
		pending = batch
	end
end

-- Las acciones más nuevas primero (las que aún no se han escrito, también).
function AdminLog.recent(): { Entry }
	local list: { Entry } = {}
	local dataStore = getStore()
	if dataStore then
		local ok, stored = pcall(function()
			return dataStore:GetAsync(KEY)
		end)
		if ok and typeof(stored) == "table" then
			list = stored
		end
	end
	for _, entry in pending do
		table.insert(list, entry)
	end
	local shown: { Entry } = {}
	for index = #list, math.max(1, #list - Config.AdminTools.LogShown + 1), -1 do
		table.insert(shown, list[index])
	end
	return shown
end

function AdminLog.start(placeName: string)
	place = placeName
	task.spawn(function()
		while true do
			task.wait(Config.AdminTools.LogFlushSeconds)
			flush()
		end
	end)
	game:BindToClose(flush)
end

return AdminLog
