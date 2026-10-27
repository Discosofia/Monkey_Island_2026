--!strict
-- Lo que un administrador lanza "en este servidor" o "en todos los servidores" (T4): anuncios, "Dar a
-- todos" y, más adelante, eventos y mantenimiento. Cada tipo de mensaje tiene su manejador (on) y se
-- lanza con send:
--   - "Server": se ejecuta solo aquí, al momento.
--   - "All": va por MessagingService (tema Config.AdminTools.Topic) y lo ejecuta cada servidor de la
--     experiencia (los tres places), este incluido, al recibirlo. Si MessagingService falla (o la
--     suscripción no está lista), se ejecuta solo aquí y send devuelve false para avisar al admin.
-- Los mensajes solo los publica este código tras comprobar que quien lo pide es administrador.

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Scope = "Server" | "All"

local AdminNet = {}

local handlers: { [string]: (data: any) -> () } = {}
local subscribed = false

-- Mensajes ya ejecutados (por id): la entrega de MessagingService puede repetirse.
local seen: { [string]: boolean } = {}

local function run(kind: string, data: any)
	-- Algunos mensajes solo los entiende un place (las acciones de la Isla): los demás los ignoran.
	local handler = handlers[kind]
	if handler then
		task.spawn(handler, data)
	end
end

function AdminNet.on(kind: string, handler: (data: any) -> ())
	handlers[kind] = handler
end

function AdminNet.isScope(value: any): boolean
	return value == "Server" or value == "All"
end

-- Lanza el mensaje "kind" con "data" (una tabla pequeña: MessagingService admite 1 kB). Devuelve
-- false si se pidió "All" y solo se pudo hacer en este servidor.
function AdminNet.send(kind: string, data: any, scope: Scope): boolean
	if scope == "All" and subscribed then
		local id = HttpService:GenerateGUID(false)
		local ok, err = pcall(function()
			MessagingService:PublishAsync(Config.AdminTools.Topic, { id = id, kind = kind, data = data })
		end)
		if ok then
			return true
		end
		warn(`[AdminNet] No se pudo publicar {kind}: {err}`)
	end
	run(kind, data)
	return scope == "Server"
end

function AdminNet.start()
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(Config.AdminTools.Topic, function(message)
				local body = message.Data
				if typeof(body) ~= "table" or typeof(body.id) ~= "string" or typeof(body.kind) ~= "string" then
					return
				end
				if seen[body.id] then
					return
				end
				seen[body.id] = true
				task.delay(300, function()
					seen[body.id] = nil
				end)
				run(body.kind, body.data)
			end)
		end)
		subscribed = ok
		if not ok then
			warn(`[AdminNet] Sin MessagingService: lo de "todos los servidores" se hará solo aquí ({err})`)
		end
	end)
end

return AdminNet
