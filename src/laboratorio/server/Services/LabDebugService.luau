--!strict
-- Panel de pruebas del Laboratorio (solo Studio; Shared/DebugCommands.Laboratorio). En Studio no llega
-- nadie del Lobby: con "Empezar ya" la partida arranca con un solo bando y no cuenta para nada ("Siguiente
-- modo" cambia entre los tres, "Siguiente mapa" entre los de Config.Lab.Maps, "Caerme del mapa" prueba la caída y
-- "Punto para mí" suma uno según el modo); los muñecos de práctica (Combat/TrainingDummies) sirven de blanco a
-- las distancias de la calculadora.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local LabModes = require(ReplicatedStorage.Shared.LabModes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Killfeed = require(ServerScriptService.Combat.Killfeed)
local TrainingDummies = require(ServerScriptService.Combat.TrainingDummies)
local LabMatchService = require(script.Parent.LabMatchService)
local LabRespawnService = require(script.Parent.LabRespawnService)
local LabRewardService = require(script.Parent.LabRewardService)
local LabTeamService = require(script.Parent.LabTeamService)
local LabVoteService = require(script.Parent.LabVoteService)
local LabWorldService = require(script.Parent.LabWorldService)

local DUMMY_FOLDER = "MuñecosDePractica"

local LabDebugService = {}

local function humanoidOf(player: Player): Humanoid?
	return if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
end

local DUMMY_CENTER_HEIGHT = 3.9 -- del suelo al centro del muñeco
local DUMMY_FLOOR_TOLERANCE = 4 -- desnivel máximo respecto a la salida para contar como suelo
local DUMMY_SPACE = Vector3.new(4, 7, 4) -- hueco libre que necesita un muñeco
local DUMMY_BACKSTEP = 4 -- cuánto se acerca a la salida cada intento
local DUMMY_BACKSTEPS = 30
local DUMMY_SIDE_OFFSETS = { 0, 6, -6, 12, -12 }
local INVISIBLE = 0.95

-- Un sitio para un muñeco cerca de "wanted": con suelo a la altura de la salida (floorY) y sin nada sólido
-- en medio. En la azotea el tejado acaba antes de los 120 studs, hay una caseta y una barrera invisible, así
-- que si "wanted" no vale se acerca a la salida y se prueba a los lados. Nil si no hay ningún sitio.
local function dummySpot(wanted: Vector3, floorY: number, forward: Vector3, side: Vector3): Vector3?
	local characters: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(characters, other.Character)
		end
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = characters
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = characters
	for back = 0, DUMMY_BACKSTEPS do
		for _, offset in DUMMY_SIDE_OFFSETS do
			local candidate = wanted - forward * (back * DUMMY_BACKSTEP) + side * offset
			local from = Vector3.new(candidate.X, floorY + DUMMY_FLOOR_TOLERANCE, candidate.Z)
			local floor = Workspace:Raycast(from, Vector3.new(0, -2 * DUMMY_FLOOR_TOLERANCE, 0), rayParams)
			if floor and floor.Instance.Transparency < INVISIBLE then
				local center = Vector3.new(candidate.X, floor.Position.Y + 0.5 + DUMMY_SPACE.Y / 2, candidate.Z)
				local blocked = false
				for _, part in Workspace:GetPartBoundsInBox(CFrame.new(center), DUMMY_SPACE, overlapParams) do
					if part.CanCollide and part.Transparency < INVISIBLE then
						blocked = true
						break
					end
				end
				if not blocked then
					return Vector3.new(candidate.X, floor.Position.Y + DUMMY_CENTER_HEIGHT, candidate.Z)
				end
			end
		end
	end
	return nil
end

-- Pone (o quita, si ya están) los muñecos delante de la zona de salida de su bando, por el carril
-- central, a las distancias de Config.Lab.TestDummyDistances contadas desde la boca de la zona, siempre
-- sobre suelo (dummySpot).
local function toggleDummies(player: Player)
	local old = Workspace:FindFirstChild(DUMMY_FOLDER)
	if old then
		old:Destroy()
		return
	end
	local spawn, forward = LabWorldService.frontOf(Arena.teamOf(player) or Config.Lab.TeamOrder[1])
	local side = Vector3.new(-forward.Z, 0, forward.X)
	local spots = {}
	for index, distance in Config.Lab.TestDummyDistances do
		-- Separados un poco a lo ancho, para que no se tapen entre ellos.
		local spot = dummySpot(spawn + forward * distance + side * ((index - 2) * 5), spawn.Y, forward, side)
		if spot then
			table.insert(spots, spot)
		end
	end
	TrainingDummies.place(spots, spawn)
end

local cineCounter = 0
local CINE_STREAM_SECONDS = 3 -- lo que espera cada petición de carga antes de seguir
-- Por escena, los sitios (mapa y punto local) donde ocurre cada acto.
local CINE_STREAM_POINTS: { [string]: { { map: string, pos: Vector3 } } } = {
	LabEngine = { { map = "Central", pos = Vector3.new(47, 0, 0) } },
}
do
	local threeActs = {
		{ map = "Central", pos = Vector3.new(38, 0, 5) },
		{ map = "Alcantarillas", pos = Vector3.new(-35, 0, 0) },
		{ map = "Azotea", pos = Vector3.new(-10, 0, 20) },
	}
	CINE_STREAM_POINTS.Lab = threeActs
	CINE_STREAM_POINTS.Lab_Comic = threeActs
end

-- Lanza una cinemática del Laboratorio (Fase 25, G12): LabCineController (cliente) la lanza en local. El atributo LabCine
-- lleva «<id de la escena>:<contador>» para que repetir la misma orden también dispare el cambio.
local function startCine(player: Player, sceneId: string)
	cineCounter += 1
	local value = `{sceneId}:{cineCounter}`
	-- Con StreamingEnabled el servidor solo envía lo que rodea al personaje, y el personaje que aparca el cliente en cada
	-- acto no cambia de sitio para el servidor (está anclado en local): los mapas lejanos llegaban vacíos (el Central se vio sin
	-- baldosas ni muros). Antes de empezar se pide cargar el sitio de cada acto, como hace la Isla (CinematicService).
	task.spawn(function()
		local offsets = Config.Lab.MapOffsets
		for _, point in CINE_STREAM_POINTS[sceneId] or {} do
			pcall(player.RequestStreamAroundAsync, player, offsets[point.map] + point.pos, CINE_STREAM_SECONDS)
		end
		if player.Parent then
			player:SetAttribute("LabCine", value)
		end
	end)
end

local COMMANDS: { [string]: (player: Player) -> () } = {
	-- Escena de prueba del motor (armas del Laboratorio, luz y primera persona).
	CineLabEngine = function(player)
		startCine(player, "LabEngine")
	end,
	-- La escena de tres actos del tráiler (Central, Alcantarillas y Azotea) y su variante cómic.
	CineLab = function(player)
		startCine(player, "Lab")
	end,
	CineLabComic = function(player)
		startCine(player, "Lab_Comic")
	end,
	Solo = function()
		LabMatchService.debugSolo()
	end,
	SkipPhase = function()
		LabMatchService.debugSkipPhase()
	end,
	CloseVote = function()
		LabVoteService.debugCloseNow()
	end,
	NextFormat = function(player)
		local format = LabMatchService.debugNextFormat()
		if LabModes.isFreeForAll() then
			Remotes.Notify:FireClient(player, "👥 Formato {n} jugadores", { n = format })
		else
			Remotes.Notify:FireClient(player, "👥 Formato {n}v{n}", { n = format })
		end
	end,
	NextMode = function(player)
		local modeId = LabMatchService.debugNextMode()
		if modeId then
			Remotes.Notify:FireClient(player, "🎮 Modo: {name}", { name = { Config.Lab.ModeNames[modeId] } })
		else
			Remotes.Notify:FireClient(player, "🎮 El modo solo se cambia en la espera o en los resultados")
		end
	end,
	NextMap = function(player)
		local phase = Arena.phase()
		if phase ~= "Waiting" and phase ~= "Results" then
			Remotes.Notify:FireClient(player, "🏙️ El mapa solo se cambia en la espera o en los resultados")
			return
		end
		local maps = Config.Lab.Maps
		if #maps < 2 then
			Remotes.Notify:FireClient(player, "🏙️ Solo hay un mapa")
			return
		end
		local index = table.find(maps, LabWorldService.currentMap()) or 0
		local mapId = maps[index % #maps + 1]
		LabWorldService.setMap(mapId)
		LabRespawnService.respawnAll()
		Remotes.Notify:FireClient(player, "🏙️ Mapa: {name}", { name = { Config.Lab.MapNames[mapId] } })
	end,
	-- Te baja 50 studs bajo el límite de caída del mapa, para probarla.
	Fall = function(player)
		local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			root.CFrame = CFrame.new(root.Position.X, LabWorldService.fallY() - 50, root.Position.Z)
		end
	end,
	Score = function(player)
		LabMatchService.debugScore(player)
	end,
	RealWin = function(player)
		LabMatchService.debugRealWin(player)
	end,
	SwitchTeam = function(player)
		LabTeamService.switch(player)
	end,
	Dummies = toggleDummies,
	Die = function(player)
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.Health = 0
		end
	end,
	Heal = function(player)
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end,
	-- Para ver la vida volver sola (Config.Lab.RegenDelaySeconds).
	Hurt = function(player)
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.Health = 30
		end
	end,
	-- +100 bajas con el arma que llevas y las skins que eso da (L5b), sin jugar una partida.
	SkinKills = function(player)
		local weaponId = player:GetAttribute("LabWeapon")
		if typeof(weaponId) ~= "string" then
			weaponId = Config.Lab.DefaultWeapon
		end
		PlayerData.update(player, function(profile)
			local saved = if typeof(profile.lab.weaponKills) == "table" then profile.lab.weaponKills else {}
			saved[weaponId] = (saved[weaponId] or 0) + 100
			profile.lab.weaponKills = saved
		end)
		LabRewardService.checkSkins(player)
	end,
	Amber = function(player)
		PlayerData.update(player, function(profile)
			profile.amber += 500
		end)
	end,
}

function LabDebugService:Start()
	if not RunService:IsStudio() then
		return
	end
	Remotes.DebugCommand.OnServerEvent:Connect(function(player: Player, command: any, arg: any)
		if command == "FakeKill" then
			Killfeed.fake(player, arg)
			return
		end
		local handler = if typeof(command) == "string" then COMMANDS[command] else nil
		if handler then
			handler(player)
		end
	end)
	print("[LabDebugService] Panel de pruebas activo (solo Studio).")
end

return LabDebugService
