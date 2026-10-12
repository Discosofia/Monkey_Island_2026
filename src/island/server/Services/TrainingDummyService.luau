--!strict
-- Muñecos de práctica en el Basecamp para probar el combate hasta que lleguen los monos (Fase 1.4).
-- Tienen la etiqueta de enemigo, así que las armas les hacen daño. Al romperse, reaparecen.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local BasecampService = require(script.Parent.BasecampService)

-- Posiciones respecto al centro del Basecamp: al este de la hoguera, mirando hacia ella.
local DUMMY_OFFSETS = { Vector3.new(45, 0, -10), Vector3.new(45, 0, 0), Vector3.new(45, 0, 10) }

local TrainingDummyService = {}

local folder: Folder? = nil

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

local function groundAt(position: Vector3): Vector3
	local result = Workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0))
	return if result then result.Position else position
end

local function spawnDummy(ground: Vector3, lookAt: Vector3)
	local model = Instance.new("Model")
	model.Name = "Muñeco de práctica"
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
		task.delay(Config.Combat.DummyRespawnSeconds, function()
			model:Destroy()
			spawnDummy(ground, lookAt)
		end)
	end)
end

function TrainingDummyService:Start()
	local newFolder = Instance.new("Folder")
	newFolder.Name = "MuñecosDePractica"
	newFolder.Parent = Workspace
	folder = newFolder

	local center = BasecampService.getCenter()
	for _, offset in DUMMY_OFFSETS do
		spawnDummy(groundAt(center + offset), center)
	end
end

return TrainingDummyService
