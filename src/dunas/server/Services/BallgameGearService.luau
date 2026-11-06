--!strict
-- Equipo visual del Juego de pelota (Fase 27e): viste a todos los jugadores con el yugo, las rodilleras, la
-- palma y el tocado de su equipo (Shared/BallgameGear) solo mientras dura el partido (fase Battle o SuddenDeath
-- con el modo Ballgame), y se lo quita al acabar (Results), al volver a Waiting, al cambiar de modo o al
-- irse el jugador. Se reaplica en cada reaparición. Lee la fase y el modo de los atributos que publica
-- ArenaMatchService, así cubre también los cambios desde el panel de pruebas.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local ArenaModes = require(ReplicatedStorage.Shared.ArenaModes)
local BallgameGear = require(ReplicatedStorage.Shared.BallgameGear)

-- Cuánto se espera a que el personaje tenga todos los miembros del R15.
local LOAD_TIMEOUT = 5

local BallgameGearService = {}

-- ¿Está en marcha un partido del Juego de pelota?
local function active(): boolean
	if ArenaModes.current() ~= "Ballgame" then
		return false
	end
	local phase = Arena.phase()
	return phase == "Battle" or phase == "SuddenDeath"
end

local function dress(player: Player, character: Model)
	local team = Arena.teamOf(player)
	if not (team and active()) then
		return
	end
	-- El personaje recién creado puede no tener aún todas sus partes.
	for _, name in { "Head", "UpperTorso", "LowerTorso", "LeftLowerLeg", "RightLowerLeg" } do
		character:WaitForChild(name, LOAD_TIMEOUT)
	end
	-- Tras la espera puede haber cambiado todo: otro personaje, otra fase u otro equipo.
	local current = Arena.teamOf(player)
	if player.Character ~= character or not character.Parent or not current or not active() then
		return
	end
	BallgameGear.build(current, character)
end

local function undress(player: Player)
	if player.Character then
		BallgameGear.remove(player.Character)
	end
end

-- Pone o quita el equipo a todos según el estado del partido.
local function refresh()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			if active() then
				task.spawn(dress, player, character)
			else
				BallgameGear.remove(character)
			end
		end
	end
end

local function track(player: Player)
	player.CharacterAdded:Connect(function(character)
		dress(player, character)
	end)
	-- Un cambio de equipo en pleno partido (el panel de pruebas) cambia también los colores.
	player:GetAttributeChangedSignal("Team"):Connect(function()
		local character = player.Character
		if character then
			if active() then
				task.spawn(dress, player, character)
			else
				BallgameGear.remove(character)
			end
		end
	end)
end

function BallgameGearService:Start()
	ReplicatedStorage:GetAttributeChangedSignal("ArenaPhase"):Connect(refresh)
	Workspace:GetAttributeChangedSignal("ArenaMode"):Connect(refresh)
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerRemoving:Connect(undress)
	refresh()
end

return BallgameGearService
