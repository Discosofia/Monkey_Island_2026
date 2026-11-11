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
local StageBosses = require(ReplicatedStorage.Shared.Data.StageBosses)
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

-- Monta al jefe de plató de la escena "sceneId" según Data/StageBosses. Con place = "basecamp" lo lleva a "basecampAnchor"
-- (el suelo bajo el centro del Basecamp) + offset, con el suelo medido por rayo. Siempre deja su sitio en el atributo
-- StageSpot, y si la entrada es hidden lo entierra HIDE_DEPTH studs (el evento stageShow de la escena lo sube).
function StageBoss.mount(sceneId: string, basecampAnchor: CFrame?): (Model, CFrame, Folder)
	local entry = StageBosses.get(sceneId)
	assert(entry, `StageBoss.mount: la escena {sceneId} no tiene jefe de plató en Data/StageBosses`)
	local model, anchor, folder = StageBoss.create(entry.boss, entry.folder)
	if entry.place == "basecamp" then
		assert(basecampAnchor, "StageBoss.mount: place basecamp pide el anchor del Basecamp")
		-- Del sitio de plató del jefe a su sitio del Basecamp, con el suelo medido por rayo.
		local target = basecampAnchor:PointToWorldSpace(entry.offset or Vector3.zero)
		local terrainOnly = RaycastParams.new()
		terrainOnly.FilterType = Enum.RaycastFilterType.Include
		terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }
		local hit = Workspace:Raycast(target + Vector3.new(0, 80, 0), Vector3.new(0, -300, 0), terrainOnly)
		local groundY = if hit then hit.Position.Y else basecampAnchor.Position.Y
		-- El pivote del modelo está algo por encima de su pie: se conserva esa diferencia.
		local lift = model:GetPivot().Position.Y - anchor.Position.Y
		local spot = Vector3.new(target.X, groundY + lift, target.Z)
		local facing = entry.facing or Vector3.new(0, 0, -1)
		local placed = CFrame.lookAt(spot, spot + facing)
		model:SetAttribute("StageSpot", placed)
		model:PivotTo(if entry.hidden then placed - Vector3.new(0, StageBosses.HIDE_DEPTH, 0) else placed)
	else
		model:SetAttribute("StageSpot", model:GetPivot())
		if entry.hidden then
			model:PivotTo(model:GetPivot() - Vector3.new(0, StageBosses.HIDE_DEPTH, 0))
		end
	end
	return model, anchor, folder
end

return StageBoss
