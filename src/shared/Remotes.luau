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
	-- Cliente -> servidor (Lobby e Isla): guardar los ajustes del jugador (tabla, ver Shared/Settings).
	SaveSettings = remoteEvent("SaveSettings"),
	-- Servidor -> clientes (Isla): lote de números de combate (Combat/CombatText). Cada uno:
	-- { target = modelo, amount, kind = "Taken"|"Heal"|"Dealt"|"Poison"|"Absorbed", crit, by = UserId?, pet }.
	CombatText = remoteEvent("CombatText"),
	-- Servidor -> cliente (Isla): has recogido algo (itemId, cantidad). Lo dibuja CombatTextController
	-- en la columna de lo recogido, como los números de combate.
	Loot = remoteEvent("Loot"),
	-- Cliente -> servidor (Isla): saltar a la siguiente fase del día. Solo funciona en Studio.
	DebugSkipPhase = remoteEvent("DebugSkipPhase"),
	-- Cliente -> servidor (Lobby e Isla): orden del panel de pruebas (nombre). Solo funciona en Studio.
	DebugCommand = remoteEvent("DebugCommand"),
	-- Cliente -> servidor (Isla): usar el arma equipada. Envía la dirección de apuntado (Vector3).
	UseWeapon = remoteEvent("UseWeapon"),
	-- Cliente -> servidor (Isla): el jugador ha esquivado (para la invulnerabilidad breve).
	Dodge = remoteEvent("Dodge"),
	-- Cliente -> servidor (Isla): el caído se rinde y reaparece ya (mantener pulsado "Rendirse").
	Surrender = remoteEvent("Surrender"),
	-- Cliente -> servidor (Isla): fabricar una receta en la mesa de trabajo (id de Data/Recipes).
	Craft = remoteEvent("Craft"),
	-- Cliente -> servidor (Isla): curarse (el servidor elige venda, ungüento o antídoto).
	UseBandage = remoteEvent("UseBandage"),
	-- Cliente -> servidor (Isla): comer la mejor comida que lleve el jugador.
	Eat = remoteEvent("Eat"),
	-- Cliente -> servidor (Isla): beber del río (el servidor comprueba que haya agua cerca).
	Drink = remoteEvent("Drink"),
	-- Cliente -> servidor (Isla): construir una pieza (id, punto Vector3, giro 0-3).
	Build = remoteEvent("Build"),
	-- Cliente -> servidor (Isla): derribar una pieza propia (el Model de la estructura).
	Demolish = remoteEvent("Demolish"),
	-- Servidor -> cliente (Isla): la partida ha terminado; lleva el resumen para la pantalla final.
	MatchEnded = remoteEvent("MatchEnded"),
	-- Cliente -> servidor (Lobby): elegir rol (id de Data/Roles).
	SelectRole = remoteEvent("SelectRole"),
	-- Cliente -> servidor (Lobby): la guía de la primera vez está hecha (LobbyGuideController).
	LobbyGuideDone = remoteEvent("LobbyGuideDone"),
	-- Cliente -> servidor (Lobby): aprender un rango de talento (rol, talento).
	LearnTalent = remoteEvent("LearnTalent"),
	-- Cliente -> servidor (Lobby): comprar un rango de mejora con Ámbar (id de Data/Upgrades).
	BuyUpgrade = remoteEvent("BuyUpgrade"),
	-- Cliente -> servidor (Lobby): invitar a un jugador al grupo (UserId).
	PartyInvite = remoteEvent("PartyInvite"),
	-- Cliente -> servidor (Lobby): responder a una invitación (UserId del líder, aceptar).
	PartyRespond = remoteEvent("PartyRespond"),
	-- Cliente -> servidor (Lobby): salir del grupo.
	PartyLeave = remoteEvent("PartyLeave"),
	-- Servidor -> cliente (Lobby): invitación recibida (UserId y nombre del líder).
	PartyInvited = remoteEvent("PartyInvited"),
	-- Cliente -> servidor (Isla): usar la habilidad del rol.
	UseAbility = remoteEvent("UseAbility"),
	-- Cliente -> servidor (Lobby): llevar una mascota (id de Data/Pets, o "" para ninguna).
	SelectPet = remoteEvent("SelectPet"),
	-- Cliente -> servidor (Isla): paso del tutorial alcanzado (número), para la analítica.
	TutorialStep = remoteEvent("TutorialStep"),
	-- Cliente -> servidor (Lobby e Isla): equipar o quitar un cosmético (id de Data/Cosmetics).
	EquipCosmetic = remoteEvent("EquipCosmetic"),
	-- Cliente -> servidor (Isla): el tutorial se ha completado.
	TutorialDone = remoteEvent("TutorialDone"),
	-- Servidor -> clientes (Isla): la mascota de un jugador ataca a un mono (Player, Model).
	PetAttack = remoteEvent("PetAttack"),
	-- Servidor -> clientes (Isla): "¡puf!" de humo al derrotar un mono, un jefe o un muñeco
	-- (posición Vector3, tamaño en studs). Cada cliente dibuja las partículas (PoofController).
	Poof = remoteEvent("Poof"),
	-- Servidor -> clientes (Isla): efecto visual de una habilidad de rol (tipo y sus datos; ver
	-- AbilityFxController). El daño lo pone el servidor; esto es solo lo que se ve.
	AbilityFx = remoteEvent("AbilityFx"),
	-- Cliente -> servidor (Lobby): poner en el nido o descartar un huevo guardado
	-- ("bag" | "pending", posición en esa lista; ServerShared/Eggs).
	PlaceEgg = remoteEvent("PlaceEgg"),
	DiscardEgg = remoteEvent("DiscardEgg"),
	-- Cliente -> servidor (Lobby): abrir el huevo del nido si ya está listo.
	HatchEgg = remoteEvent("HatchEgg"),
	-- Servidor -> cliente (Lobby): ha nacido una mascota (id, rareza del huevo, si se la ha puesto),
	-- para la ceremonia del nido (NestController).
	EggHatched = remoteEvent("EggHatched"),
	-- Cliente -> servidor (Lobby): cobrar el premio de hoy del calendario de 7 días.
	ClaimLogin = remoteEvent("ClaimLogin"),
	-- Servidor -> cliente (Lobby): premio cobrado (día 1..7 y lo recibido, línea a línea).
	LoginClaimed = remoteEvent("LoginClaimed"),
	-- Cliente -> servidor (Dunas): antes de la partida, unirse a un equipo ("Jaguar" | "Quetzal"),
	-- elegir rol (id de Data/Roles) y marcar si está listo (true/false). El estado de la partida va en
	-- atributos de ReplicatedStorage (Shared/Arena).
	ArenaPickTeam = remoteEvent("ArenaPickTeam"),
	ArenaPickRole = remoteEvent("ArenaPickRole"),
	ArenaReady = remoteEvent("ArenaReady"),
	-- Servidor -> cliente (Dunas): resultados de la partida para ese jugador (ArenaRewardService):
	-- ganador, su Ámbar, el tope diario y los números de cada jugador.
	ArenaResults = remoteEvent("ArenaResults"),
	-- Cliente -> servidor (Dunas): volver al Lobby (desde los resultados).
	ArenaLeave = remoteEvent("ArenaLeave"),
	-- Cliente -> servidor (Lobby y Dunas): comprar equipamiento de la arena (id de Data/ArenaGear) y
	-- poner una variante en una ranura (rol, ranura, id; sin id, lo básico). ServerShared/ArenaShop.
	ArenaBuyGear = remoteEvent("ArenaBuyGear"),
	ArenaEquipGear = remoteEvent("ArenaEquipGear"),
	-- Cliente -> servidor (Lobby): entrar en la cola de la arena con un formato (1..5 por equipo; el
	-- líder lleva a su grupo) y salir de ella. ArenaQueueService.
	ArenaQueueJoin = remoteEvent("ArenaQueueJoin"),
	ArenaQueueLeave = remoteEvent("ArenaQueueLeave"),
}

return Remotes
