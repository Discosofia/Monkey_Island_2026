--!strict
-- Muñecos de práctica para probar las armas y las habilidades: en el Basecamp de la Isla
-- (TrainingDummyService) y en la plaza del Lobby (LobbyDummyService). Tienen la etiqueta de enemigo,
-- así que las armas y las habilidades les hacen daño, les ponen estados y sirven para enlazar
-- combos. Al romperse hacen "¡puf!" y reaparecen en el mismo sitio.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Poof = require(script.Parent.Poof)

local TrainingDummies = {}

local function newPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Parent = parent
	return part
end

-- El suelo bajo "position" (o "position" si no hay nada debajo).
local function groundAt(position: Vector3): Vector3
	local result = Workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0))
	return if result then result.Position else position
end

local function spawnDummy(folder: Instance, ground: Vector3, lookAt: Vector3)
	local model = Instance.new("Model")
	model.Name = "Muñeco de práctica"
	-- Su daño no cuenta para las misiones del día (MissionService).
	model:SetAttribute("TrainingDummy", true)
	local facing = CFrame.lookAt(ground, Vector3.new(lookAt.X, ground.Y, lookAt.Z))

	newPart("Post", Vector3.new(0.6, 3, 0.6), facing * CFrame.new(0, 1.5, 0), Color3.fromRGB(110, 72, 40), model)
	newPart("Torso", Vector3.new(2, 2, 1), facing * CFrame.new(0, 4, 0), Color3.fromRGB(190, 160, 110), model)
	local head =
		newPart("Head", Vector3.one * 1.6, facing * CFrame.new(0, 5.8, 0), Color3.fromRGB(205, 175, 125), model)
	head.Shape = Enum.PartType.Ball
	local root = newPart("HumanoidRootPart", Vector3.new(2, 2, 1), facing * CFrame.new(0, 4, 0), Color3.new(), model)
	root.Transparency = 1
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = "Muñeco de práctica"
	humanoid.MaxHealth = Config.Combat.DummyHealth
	humanoid.Health = Config.Combat.DummyHealth
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	CollectionService:AddTag(model, Config.Combat.EnemyTag)
	model.Parent = folder

	local respawning = false
	humanoid.HealthChanged:Connect(function(health)
		if health > 0 or respawning then
			return
		end
		respawning = true
		Poof.vanish(model)
		task.delay(Config.Combat.DummyRespawnSeconds, function()
			spawnDummy(folder, ground, lookAt)
		end)
	end)
end

-- Pone un muñeco en el suelo bajo cada punto de "spots", mirando hacia "lookAt", dentro de una
-- carpeta nueva "MuñecosDePractica" del Workspace.
function TrainingDummies.place(spots: { Vector3 }, lookAt: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "MuñecosDePractica"
	folder.Parent = Workspace
	for _, spot in spots do
		spawnDummy(folder, groundAt(spot), lookAt)
	end
end

return TrainingDummies
