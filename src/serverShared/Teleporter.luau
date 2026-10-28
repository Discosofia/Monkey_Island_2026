--!strict
-- Envía jugadores a otro place de la experiencia, con reintentos y mensajes claros.
-- Lo usan los servidores del Lobby y de la Isla.
--
-- Al arrancar, pide a Roblox la lista de places de esta experiencia y la escribe en la Salida
-- (en el juego publicado: consola F9 → pestaña Server). Así se puede comprobar que los IDs de
-- Config.PlaceIds son correctos, y un ID equivocado da un aviso claro en vez del error 773.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Teleporter = {}

-- ID -> nombre de los places de esta experiencia. nil si Roblox aún no respondió o falló.
local experiencePlaces: { [number]: string }? = nil

local function notify(players: { Player }, message: string, args: { [string]: any }?)
	for _, player in players do
		Remotes.Notify:FireClient(player, message, args)
	end
end

local function fetchExperiencePlaces(): { [number]: string }?
	local ok, result = pcall(function()
		local places: { [number]: string } = {}
		local pages = AssetService:GetGamePlacesAsync()
		while true do
			for _, place in pages:GetCurrentPage() do
				places[place.PlaceId] = place.Name
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
		return places
	end)
	if not ok then
		warn(`[Teleporter] No se pudo obtener la lista de places de la experiencia: {result}`)
		return nil
	end
	return result
end

local function describePlaces(places: { [number]: string }): string
	local lines = {}
	for id, name in places do
		table.insert(lines, `"{name}" = {id}`)
	end
	return table.concat(lines, ", ")
end

local function checkConfiguredPlaceIds(places: { [number]: string })
	local configured: { [string]: number } = {
		Lobby = Config.PlaceIds.Lobby,
		Island = Config.PlaceIds.Island,
		Dunas = Config.PlaceIds.Dunas,
		Laboratorio = Config.PlaceIds.Laboratorio,
	}
	for key, id in configured do
		if id ~= 0 and not places[id] then
			warn(`[Teleporter] Config.PlaceIds.{key} = {id} NO es un place de esta experiencia.`)
		end
	end
end

task.spawn(function()
	local places = fetchExperiencePlaces()
	if places then
		experiencePlaces = places
		print(`[Teleporter] Places de esta experiencia: {describePlaces(places)}`)
		checkConfiguredPlaceIds(places)
	end
end)

-- Si el viaje falla después de empezar (por ejemplo, el servidor de destino no responde),
-- se avisa al jugador para que lo intente de nuevo.
TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
	warn(`[Teleporter] Falló el viaje de {player.Name}: {result.Name} {message}`)
	notify({ player }, "No se pudo completar el viaje. Inténtalo de nuevo.")
end)

-- Devuelve true si el viaje empezó. destinationName se usa en los mensajes al jugador: una frase de
-- Shared/Strings (Strings.later("el Lobby")), que el cliente traduce.
-- "options" (opcional) permite, por ejemplo, ir a un servidor reservado (servidores privados).
function Teleporter.send(
	players: { Player },
	placeId: number,
	destinationName: string,
	options: TeleportOptions?
): boolean
	if placeId == 0 then
		warn(`[Teleporter] Config.PlaceIds no tiene el ID de {destinationName}. Ver docs/SETUP.md.`)
		notify(players, "Falta configurar el ID de {place} (ver docs/SETUP.md).", { place = { destinationName } })
		return false
	end

	if RunService:IsStudio() then
		notify(
			players,
			"Los viajes no funcionan en Studio. Prueba {place} en el juego publicado.",
			{ place = { destinationName } }
		)
		return false
	end

	local places = experiencePlaces
	if places and not places[placeId] then
		warn(`[Teleporter] {placeId} no es un place de esta experiencia. Places: {describePlaces(places)}`)
		notify(
			players,
			"El ID de {place} en Config no es de esta experiencia (ver consola F9).",
			{ place = { destinationName } }
		)
		return false
	end

	notify(players, "Viajando a {place}...", { place = { destinationName } })
	for attempt = 1, Config.Teleport.MaxAttempts do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(placeId, players, options)
		end)
		if ok then
			return true
		end
		warn(`[Teleporter] Intento {attempt} hacia {destinationName} fallido: {err}`)
		if attempt < Config.Teleport.MaxAttempts then
			task.wait(Config.Teleport.RetryDelaySeconds)
		end
	end

	notify(players, "No se pudo viajar a {place}. Inténtalo de nuevo.", { place = { destinationName } })
	return false
end

return Teleporter
