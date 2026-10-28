--!strict
-- Panel de pruebas del Laboratorio (solo Studio; Shared/DebugCommands.Laboratorio). En Studio no llega
-- nadie del Lobby: con "Empezar ya" el duelo arranca con un solo bando y no cuenta para nada; los
-- muñecos de práctica (Combat/TrainingDummies) sirven de blanco a las distancias de la calculadora.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local TrainingDummies = require(ServerScriptService.Combat.TrainingDummies)
local LabMatchService = require(script.Parent.LabMatchService)
local LabTeamService = require(script.Parent.LabTeamService)
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
		table.insert(spots, Vector3.new(spawn.X, 4, 0) + forward * distance + Vector3.new(0, 0, (index - 2) * 5))
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
	NextFormat = function(player)
		local format = LabMatchService.debugNextFormat()
		Remotes.Notify:FireClient(player, "👥 Formato {n}v{n}", { n = format })
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
	Remotes.DebugCommand.OnServerEvent:Connect(function(player: Player, command: any)
		local handler = if typeof(command) == "string" then COMMANDS[command] else nil
		if handler then
			handler(player)
		end
	end)
	print("[LabDebugService] Panel de pruebas activo (solo Studio).")
end

return LabDebugService
