--!strict
-- Lista central de todos los eventos de red entre cliente y servidor.
-- El servidor los crea al cargar este módulo; el cliente espera a que existan.
-- Para añadir un evento nuevo, añade una línea a la tabla de abajo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local folder: Instance
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function remoteEvent(name: string): RemoteEvent
	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

local Remotes = {
	-- Cliente -> servidor (Lobby): el jugador quiere ir a la Isla.
	RequestJoinIsland = remoteEvent("RequestJoinIsland"),
	-- Cliente -> servidor (Isla): el jugador quiere volver al Lobby.
	RequestReturnToLobby = remoteEvent("RequestReturnToLobby"),
	-- Servidor -> cliente: mensaje corto para mostrar en pantalla.
	Notify = remoteEvent("Notify"),
	-- Cliente -> servidor (Isla): saltar a la siguiente fase del día. Solo funciona en Studio.
	DebugSkipPhase = remoteEvent("DebugSkipPhase"),
	-- Cliente -> servidor (Isla): usar el arma equipada. Envía la dirección de apuntado (Vector3).
	UseWeapon = remoteEvent("UseWeapon"),
	-- Cliente -> servidor (Isla): el jugador ha esquivado (para la invulnerabilidad breve).
	Dodge = remoteEvent("Dodge"),
	-- Cliente -> servidor (Isla): un Espíritu marca lo que apunta (Vector3 de dirección).
	SpiritMark = remoteEvent("SpiritMark"),
	-- Cliente -> servidor (Isla): fabricar una receta en la mesa de trabajo (id de Data/Recipes).
	Craft = remoteEvent("Craft"),
	-- Cliente -> servidor (Isla): usar una venda para curarse.
	UseBandage = remoteEvent("UseBandage"),
	-- Cliente -> servidor (Isla): comer la mejor comida que lleve el jugador.
	Eat = remoteEvent("Eat"),
	-- Cliente -> servidor (Isla): beber del río (el servidor comprueba que haya agua cerca).
	Drink = remoteEvent("Drink"),
	-- Cliente -> servidor (Isla): construir una pieza (id, punto Vector3, giro 0-3).
	Build = remoteEvent("Build"),
	-- Cliente -> servidor (Isla): derribar una pieza propia (el Model de la estructura).
	Demolish = remoteEvent("Demolish"),
}

return Remotes
