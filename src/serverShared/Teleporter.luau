--!strict
-- Envía jugadores a otro place de la experiencia, con reintentos y mensajes claros.
-- Lo usan los servidores del Lobby y de la Isla.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Teleporter = {}

local function notify(players: { Player }, message: string)
	for _, player in players do
		Remotes.Notify:FireClient(player, message)
	end
end

-- Si el viaje falla después de empezar (por ejemplo, el servidor de destino no responde),
-- se avisa al jugador para que lo intente de nuevo.
TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
	warn(`[Teleporter] Falló el viaje de {player.Name}: {result.Name} {message}`)
	notify({ player }, "No se pudo completar el viaje. Inténtalo de nuevo.")
end)

-- Devuelve true si el viaje empezó. destinationName se usa en los mensajes al jugador.
function Teleporter.send(players: { Player }, placeId: number, destinationName: string): boolean
	if placeId == 0 then
		warn(`[Teleporter] Config.PlaceIds no tiene el ID de {destinationName}. Ver docs/SETUP.md.`)
		notify(players, `Falta configurar el ID de {destinationName} (ver docs/SETUP.md).`)
		return false
	end

	if RunService:IsStudio() then
		notify(players, `Los viajes no funcionan en Studio. Prueba {destinationName} en el juego publicado.`)
		return false
	end

	notify(players, `Viajando a {destinationName}...`)
	for attempt = 1, Config.Teleport.MaxAttempts do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(placeId, players)
		end)
		if ok then
			return true
		end
		warn(`[Teleporter] Intento {attempt} hacia {destinationName} fallido: {err}`)
		if attempt < Config.Teleport.MaxAttempts then
			task.wait(Config.Teleport.RetryDelaySeconds)
		end
	end

	notify(players, `No se pudo viajar a {destinationName}. Inténtalo de nuevo.`)
	return false
end

return Teleporter
