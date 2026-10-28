--!strict
-- Sala de pruebas del Laboratorio (grupo L1, provisional hasta el mapa de la L2): un suelo de hormigón
-- con murete alrededor, dos coberturas (una alta y una baja, para ver el arco del suero) y muñecos de
-- práctica (Combat/TrainingDummies) delante del punto de salida, a las distancias de la calculadora
-- (Config.Lab.TestDummyDistances: corta, media y larga).

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local TrainingDummies = require(ServerScriptService.Combat.TrainingDummies)

local CONCRETE = Color3.fromRGB(150, 150, 146)
local CONCRETE_DARK = Color3.fromRGB(110, 110, 108)
local RUST = Color3.fromRGB(140, 82, 50)
local LENGTH = 200
local WIDTH = 60

local LabTestRoom = {}

LabTestRoom.NAME = "LabSalaDePruebas"
-- Punto de salida y hacia dónde mira (los muñecos están por delante, en +X).
LabTestRoom.SPAWN = Vector3.new(0, 4, 0)
LabTestRoom.FACING = Vector3.xAxis

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
end

function LabTestRoom.build()
	local room = Instance.new("Model")
	room.Name = LabTestRoom.NAME
	local centerX = LENGTH / 2 - 30
	block(room, "Suelo", Vector3.new(LENGTH, 2, WIDTH), Vector3.new(centerX, -1, 0), CONCRETE, Enum.Material.Concrete)
	-- Murete alrededor, para no caerse.
	for side = -1, 1, 2 do
		block(
			room,
			"Murete",
			Vector3.new(LENGTH, 3, 1),
			Vector3.new(centerX, 1.5, side * (WIDTH / 2 + 0.5)),
			CONCRETE_DARK,
			Enum.Material.Concrete
		)
		block(
			room,
			"Murete",
			Vector3.new(1, 3, WIDTH),
			Vector3.new(centerX + side * (LENGTH / 2 + 0.5), 1.5, 0),
			CONCRETE_DARK,
			Enum.Material.Concrete
		)
	end
	-- Una cobertura alta (tapa del todo) y una baja (el suero pasa por encima).
	block(room, "CoberturaAlta", Vector3.new(2, 7, 10), Vector3.new(30, 3.5, -12), RUST, Enum.Material.CorrodedMetal)
	block(room, "CoberturaBaja", Vector3.new(2, 3, 10), Vector3.new(35, 1.5, 10), RUST, Enum.Material.CorrodedMetal)
	room.Parent = Workspace

	local spots = {}
	for index, distance in Config.Lab.TestDummyDistances do
		-- Separados un poco a lo ancho, para que no se tapen entre ellos.
		table.insert(spots, LabTestRoom.SPAWN + Vector3.new(distance, 0, (index - 2) * 4))
	end
	-- Uno más detrás de la cobertura baja, para el arco del suero.
	table.insert(spots, Vector3.new(42, 4, 10))
	TrainingDummies.place(spots, LabTestRoom.SPAWN)
end

return LabTestRoom
