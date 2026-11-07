--!strict
-- Jefe «de plató» (Fase 25: Plató y batallas contra jefes, solo para grabar): un jefe quieto, sin IA ni etiqueta
-- Enemy, en su sitio real del mapa (Data/BossStages) y mirando hacia donde dice su ficha. Lo comparten el Plató
-- (DebugService.runStage) y las batallas montadas (DebugService, ArrivalService). Sin Init ni Start: el Loader no
-- carga esta carpeta, se usa con require.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local BossStages = require(ReplicatedStorage.Shared.Data.BossStages)
local Monkeys = require(ReplicatedStorage.Shared.Data.Monkeys)
local MonkeyAnimator = require(script.Parent.MonkeyAnimator)
local MonkeyModels = require(script.Parent.MonkeyModels)

local StageBoss = {}

-- Crea al jefe "bossId" dentro de una carpeta nueva de Workspace llamada "folderName". Devuelve el modelo, el anchor
-- de las escenas (su pie, con -Z hacia donde mira) y la carpeta (quien llama la destruye para borrarlo).
function StageBoss.create(bossId: string, folderName: string): (Model, CFrame, Folder)
	local definition = Bosses[bossId]
	local spot = BossStages[bossId]
	local species = Monkeys[definition.baseSpecies]

	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = Workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(spot.position + Vector3.new(0, 6, 0), Vector3.new(0, -80, 0), params)
	local ground = if hit then hit.Position else spot.position
	local look = table.clone(species)
	look.name = definition.name
	look.scale = definition.scale
	look.bodyColor = definition.bodyColor
	look.faceColor = definition.faceColor
	look.maxHealth = definition.maxHealth
	look.walkSpeed = 0
	local model = MonkeyModels.spawnBoss(definition.baseSpecies, look, ground, bossId)
	model.Name = definition.name
	model:SetAttribute("Boss", bossId)
	model:SetAttribute("BossPhase", 1)
	model.Parent = folder
	model:PivotTo(CFrame.lookAt(model:GetPivot().Position, model:GetPivot().Position + spot.facing))
	local root = model.PrimaryPart
	if root then
		root.Anchored = true
	end
	MonkeyAnimator.attach(model)
	return model, CFrame.lookAt(ground, ground + spot.facing), folder
end

return StageBoss
