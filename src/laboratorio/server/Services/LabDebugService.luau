--!strict
-- Panel de pruebas del Laboratorio (solo Studio; Shared/DebugCommands.Laboratorio). En Studio no llega
-- nadie del Lobby: con "Empezar ya" la partida arranca con un solo bando y no cuenta para nada ("Siguiente
-- modo" cambia entre los tres, "Siguiente mapa" entre los de Config.Lab.Maps, "Caerme del mapa" prueba la caída y
-- "Punto para mí" suma uno según el modo); los muñecos de práctica (Combat/TrainingDummies) sirven de blanco a
-- las distancias de la calculadora.

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

-- Pone (o quita, si ya están) los muñecos delante de la zona de salida de su bando, por el carril
-- central, a las distancias de Config.Lab.TestDummyDistances contadas desde la boca de la zona.
local function toggleDummies(player: Player)
	local old = Workspace:FindFirstChild(DUMMY_FOLDER)
	if old then
		old:Destroy()
		return
	end
	local spawn, forward = LabWorldService.frontOf(Arena.teamOf(player) or Config.Lab.TeamOrder[1])
	local spots = {}
	for index, distance in Config.Lab.TestDummyDistances do
		-- Separados un poco a lo ancho, para que no se tapen entre ellos.
		table.insert(
			spots,
			Vector3.new(spawn.X, spawn.Y + 3.9, spawn.Z) + forward * distance + Vector3.new(0, 0, (index - 2) * 5)
		)
	end
	TrainingDummies.place(spots, spawn)
end

local COMMANDS: { [string]: (player: Player) -> () } = {
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
