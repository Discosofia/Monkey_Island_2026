--!strict
-- Orquestador del escenario del Laboratorio en ruinas (Fase 13, docs/LABORATORIO.md §4). Crea
-- Workspace.LabMap, una carpeta con el atributo Version y, dentro, un Model por mapa de Config.Lab.Maps
-- (Central, y después Azotea y Alcantarillas). Cada mapa vive en World/Maps/<id> (GEOMETRY, LIGHTING, SEED,
-- OVERHEAD_HEIGHT y build) y se construye en coordenadas locales (suelo en y = 0, simétrico de oeste a este);
-- aquí se pone en su sitio (OFFSETS) para que no se pisen. Las piezas comunes están en World/LabParts.
--
-- Lo construye solo el servidor del Laboratorio al arrancar si no existe Workspace.LabMap o es de otra
-- versión (LabWorldService). Para dejarlo fijo en el place, ejecútalo en Studio, en modo edición, desde la
-- barra de comandos:
--
--   require(game.ServerScriptService.Server.World.LabBuilder).build()
--
-- ⚠️ Borra la carpeta Workspace.LabMap, la sala de pruebas de la L1, la Baseplate y los SpawnLocation
-- sueltos antes de construir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local LabParts = require(script.Parent.LabParts)

export type Options = { force: boolean? }

type MapModule = {
	GEOMETRY: LabParts.Geometry,
	LIGHTING: LabParts.LightingPreset,
	SEED: number,
	OVERHEAD_HEIGHT: number,
	OVERHEAD_BACK: number?,
	build: (model: Model) -> (),
}

local FOLDER_NAME = "LabMap"
-- Sube este número al cambiar el mapa: los places con una versión anterior guardada se reconstruyen
-- solos al arrancar (LabWorldService).
local VERSION = 3

-- Un módulo y un sitio por cada mapa (Config.Lab.Maps). Los mapas nuevos añaden aquí una línea en cada tabla.
local MODULES: { [string]: MapModule } = {
	Central = require(script.Parent.Maps.Central),
	Azotea = require(script.Parent.Maps.Azotea),
	Alcantarillas = require(script.Parent.Maps.Alcantarillas),
}
local OFFSETS: { [string]: Vector3 } = {
	Central = Vector3.zero,
	Azotea = Vector3.new(2000, 160, 0),
	Alcantarillas = Vector3.new(-2000, 0, 0),
}

local LabBuilder = {}

LabBuilder.NAME = FOLDER_NAME

-- Grupos de colisión (LabParts): los usan LabWorldService y LabTeamService.
LabBuilder.characterGroup = LabParts.characterGroup
LabBuilder.barrierGroup = LabParts.barrierGroup
LabBuilder.registerGroups = LabParts.registerGroups

local function clearOld()
	for _, name in { FOLDER_NAME, "LabSalaDePruebas", "MuñecosDePractica", "Baseplate" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

-- true si el place ya tiene el mapa de esta versión, con un Model por cada mapa.
function LabBuilder.isBuilt(): boolean
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if folder == nil or folder:GetAttribute("Version") ~= VERSION then
		return false
	end
	for _, mapId in Config.Lab.Maps do
		local model = folder:FindFirstChild(mapId)
		if not (model and model:IsA("Model")) then
			return false
		end
	end
	return true
end

-- Pone la iluminación del mapa "mapId" (global: cada mapa deja la suya).
function LabBuilder.applyLighting(mapId: string)
	local module = MODULES[mapId]
	if module then
		LabParts.applyLighting(module.LIGHTING)
	end
end

function LabBuilder.build(options: Options?)
	local force = options and options.force
	if not force and game.PlaceId ~= Config.PlaceIds.Laboratorio then
		warn(
			`[LabBuilder] Este place ({game.PlaceId}) no es el Laboratorio ({Config.PlaceIds.Laboratorio}). `
				.. "Abre el Laboratorio o usa build({ force = true })."
		)
		return
	end
	clearOld()
	LabParts.registerGroups()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("Version", VERSION)
	for _, mapId in Config.Lab.Maps do
		local module = MODULES[mapId]
		assert(module, `[LabBuilder] Falta el módulo del mapa {mapId}`)
		local model = Instance.new("Model")
		model.Name = mapId
		model:SetAttribute("OverheadHeight", module.OVERHEAD_HEIGHT)
		if module.OVERHEAD_BACK ~= nil then
			model:SetAttribute("OverheadBack", module.OVERHEAD_BACK)
		end
		model.Parent = folder
		LabParts.seed(module.SEED)
		module.build(model)
		-- El pivote al origen antes de mover: así el Model queda exactamente en su OFFSET (sin esto, el
		-- pivote sería el centro de sus piezas y cada mapa acabaría desplazado).
		model.WorldPivot = CFrame.identity
		model:PivotTo(CFrame.new(OFFSETS[mapId] or Vector3.zero))
	end
	folder.Parent = Workspace
	for _, mapId in Config.Lab.Maps do
		local model = folder:FindFirstChild(mapId)
		if model then
			LabParts.checkFreeSpawns(model)
		end
	end
	LabBuilder.applyLighting(Config.Lab.StudioMap)
	print("[LabBuilder] ¡Laboratorio listo!")
end

return LabBuilder
