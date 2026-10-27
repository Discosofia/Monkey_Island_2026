--!strict
-- Servidores desde el panel de administradores (T4d, pestaña 🖥️ Servidor), en los tres places:
--   - Lista de servidores: cada servidor responde con su place, jugadores, FPS y tiempo encendido
--     (ServerShared/AdminNet "ServerPing" / "ServerPong"); se juntan las respuestas
--     Config.AdminTools.ServerListSeconds.
--   - Mantenimiento: un evento en vivo oculto ("Maintenance", ServerShared/LiveEventsServer) con aviso
--     de unos minutos (Config.AdminTools.MaintenanceMinutes) que se ve en la franja de eventos. Al
--     empezar, cada servidor guarda los perfiles y expulsa a los jugadores; mientras dura no se puede
--     entrar (los administradores sí, para comprobar). Se cancela parándolo en la pestaña 🎉 Eventos.
-- En Studio todo se queda en este servidor: no se llama a los servidores publicados.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AdminLog = require(script.Parent.AdminLog)
local AdminNet = require(script.Parent.AdminNet)
local LiveEventsServer = require(script.Parent.LiveEventsServer)
local PlayerData = require(script.Parent.PlayerData)
local RequestCooldown = require(script.Parent.RequestCooldown)

local KICK_MESSAGE = "🛠️ El juego está en mantenimiento para actualizarse. Vuelve a entrar en unos minutos."

export type Info = { place: string, job: string, players: number, max: number, fps: number, uptime: number }

local ServerOps = {}

local canRequest = RequestCooldown.new(3)
local place = "?"
local fps = 60
-- Respuestas de cada lista pedida desde este servidor (por id).
local requests: { [string]: { Info } } = {}

local function scope(): AdminNet.Scope
	return if RunService:IsStudio() then "Server" else "All"
end

local function info(): Info
	return {
		place = place,
		job = if RunService:IsStudio() then "Studio" else string.sub(game.JobId, 1, 8),
		players = #Players:GetPlayers(),
		max = Players.MaxPlayers,
		fps = fps,
		uptime = math.floor(time()),
	}
end

AdminNet.on("ServerPing", function(data: any)
	if typeof(data) == "table" and typeof(data.id) == "string" then
		AdminNet.send("ServerPong", { id = data.id, info = info() }, if data.scope == "All" then "All" else "Server")
	end
end)
AdminNet.on("ServerPong", function(data: any)
	local list = if typeof(data) == "table" then requests[data.id] else nil
	if list and typeof(data.info) == "table" then
		table.insert(list, data.info)
	end
end)

local function list(admin: Player)
	local id = HttpService:GenerateGUID(false)
	requests[id] = {}
	local where = scope()
	AdminNet.send("ServerPing", { id = id, scope = where }, where)
	task.wait(Config.AdminTools.ServerListSeconds)
	local servers = requests[id]
	requests[id] = nil
	table.sort(servers, function(a, b)
		if a.place ~= b.place then
			return a.place < b.place
		end
		return a.players > b.players
	end)
	Remotes.AdminServer:FireClient(admin, "List", servers, where)
end

local function maintenance(admin: Player, minutes: number)
	local where = scope()
	local event = LiveEventsServer.start("Maintenance", 0, minutes, where, admin.DisplayName)
	if not event then
		return
	end
	AdminNet.send("Announce", {
		text = `🛠️ Mantenimiento en {minutes} min: el juego se cerrará para actualizarse. Termina lo que estés haciendo.`,
		from = "Mantenimiento",
	}, where)
	AdminLog.add(
		admin,
		"Mantenimiento",
		`en {minutes} min · {if where == "All" then "todos los servidores" else "este servidor"}`
	)
	Remotes.Notify:FireClient(admin, `🛠️ Mantenimiento programado: en {minutes} min`)
end

-- Guarda a todos y expulsa a los que no son administradores.
local function closeServer(isAdmin: (Player) -> boolean)
	for _, player in Players:GetPlayers() do
		if not isAdmin(player) then
			task.spawn(function()
				PlayerData.saveNow(player)
				player:Kick(KICK_MESSAGE)
			end)
		else
			Remotes.Notify:FireClient(
				player,
				"🛠️ Mantenimiento: los jugadores han salido (tú sigues por ser administrador)"
			)
		end
	end
end

function ServerOps.start(placeName: string, isAdmin: (Player) -> boolean)
	place = placeName
	Remotes.AdminServer.OnServerEvent:Connect(function(admin: Player, action: any, minutes: any)
		if not isAdmin(admin) or not canRequest(admin) then
			return
		end
		if action == "List" then
			list(admin)
		elseif action == "Maintenance" and table.find(Config.AdminTools.MaintenanceMinutes, minutes) then
			maintenance(admin, minutes)
		end
	end)
	LiveEventsServer.onStarted(function(event)
		if event.kind == "Maintenance" then
			closeServer(isAdmin)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		if LiveEvents.active("Maintenance") and not isAdmin(player) then
			player:Kick(KICK_MESSAGE)
		end
	end)
	-- FPS del servidor: pasos de Heartbeat contados cada segundo.
	task.spawn(function()
		local frames = 0
		RunService.Heartbeat:Connect(function()
			frames += 1
		end)
		while true do
			task.wait(1)
			fps = frames
			frames = 0
		end
	end)
end

return ServerOps
