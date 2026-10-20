--!strict
-- Panel de pruebas de la arena (solo Studio; Shared/DebugCommands.Dunas). En Studio no llega nadie
-- del Lobby: con "Empezar ya" la partida arranca con un solo equipo y no cuenta para nada.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ArenaMatchService = require(script.Parent.ArenaMatchService)

local DUMMY_HEALTH = 300

local ArenaDebugService = {}

local dummy: Model? = nil

-- Rival de práctica: un muñeco con la etiqueta de enemigo, 12 studs delante del jugador. Recibe el
-- daño de las armas y habilidades contra monos (no el de PvP), pero sirve para ver los efectos.
local function toggleDummy(player: Player)
	if dummy then
		dummy:Destroy()
		dummy = nil
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local pivot = character:GetPivot() * CFrame.new(0, 0, -12)
	local facing = CFrame.lookAt(pivot.Position, character:GetPivot().Position)
	local model = Instance.new("Model")
	model.Name = "Rival de práctica"
	model:SetAttribute("TrainingDummy", true)
	local function part(name: string, size: Vector3, offset: CFrame, color: Color3): Part
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Anchored = true
		piece.Size = size
		piece.CFrame = facing * offset
		piece.Color = color
		piece.Parent = model
		return piece
	end
	part("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 0, 0), Color3.fromRGB(190, 160, 110))
	local head = part("Head", Vector3.one * 1.6, CFrame.new(0, 1.8, 0), Color3.fromRGB(205, 175, 125))
	head.Shape = Enum.PartType.Ball
	part("Post", Vector3.new(0.6, 3, 0.6), CFrame.new(0, -2.5, 0), Color3.fromRGB(110, 72, 40))
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(), Color3.new())
	root.Transparency = 1
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = "Rival de práctica"
	humanoid.MaxHealth = DUMMY_HEALTH
	humanoid.Health = DUMMY_HEALTH
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	humanoid.HealthChanged:Connect(function(health)
		if health <= 0 then
			task.wait(1)
			humanoid.Health = DUMMY_HEALTH
		end
	end)
	CollectionService:AddTag(model, Config.Combat.EnemyTag)
	model.Parent = Workspace
	dummy = model
end

local COMMANDS: { [string]: (player: Player) -> () } = {
	Solo = function()
		ArenaMatchService.debugSolo()
	end,
	Format = function()
		local format = ArenaMatchService.debugNextFormat()
		Remotes.Notify:FireAllClients(`👥 Formato {format}v{format}`)
	end,
	SkipPhase = function()
		ArenaMatchService.debugSkipPhase()
	end,
	Abilities = function(player)
		for slot = 1, 5 do
			player:SetAttribute(`AbilityReadyAt{slot}`, nil)
		end
	end,
	Heal = function(player)
		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end,
	Dummy = toggleDummy,
}

function ArenaDebugService:Start()
	if not RunService:IsStudio() then
		return
	end
	Remotes.DebugCommand.OnServerEvent:Connect(function(player: Player, command: any)
		local handler = if typeof(command) == "string" then COMMANDS[command] else nil
		if handler then
			handler(player)
		end
	end)
	print("[ArenaDebugService] Panel de pruebas activo (solo Studio).")
end

return ArenaDebugService
