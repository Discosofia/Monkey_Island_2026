--!strict
-- Ayudas para dibujar en bloques de rejilla las armas del Laboratorio (Shared/LabWeaponModels, las armas base
-- de cada bando, y Shared/LabWeaponSkins, las piezas de sus skins). Ejes: +Y va de la mano hacia la boca del
-- arma; las piezas se colocan con "at(lado, largo, arriba)" en studs y quedan soldadas al "Handle".

local LabVoxel = {}

-- Lado del arma que queda "arriba" al apuntar, en la Z del "Handle".
LabVoxel.UP = -1
LabVoxel.CELL = 0.05

function LabVoxel.at(side: number, along: number, up: number): CFrame
	return CFrame.new(side, along, up * LabVoxel.UP)
end

-- Redondea a la rejilla: las piezas quedan en bloques.
function LabVoxel.snap(value: number): number
	return math.max(LabVoxel.CELL, math.round(value / LabVoxel.CELL) * LabVoxel.CELL)
end

-- Bloque de "size" (lado, largo, alto) en "where", soldado al "Handle".
function LabVoxel.cube(
	handle: BasePart,
	name: string,
	where: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): BasePart
	local snap = LabVoxel.snap
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = Vector3.new(snap(size.X), snap(size.Y), snap(size.Z))
	piece.Color = color
	piece.Material = material
	piece.CanCollide = false
	piece.CanQuery = false
	piece.Massless = true
	piece.CFrame = handle.CFrame * where
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = handle.Parent
	return piece
end

function LabVoxel.glow(part: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 1.2
	light.Parent = part
end

return LabVoxel
