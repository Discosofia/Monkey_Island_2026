--!strict
-- Modelo del huevo de mascota (antes dentro de EggService): lo usan el evento de la Isla y el nido
-- del Lobby. Cada rareza tiene su cáscara, sus motas y su brillo, bien distintos entre sí.
--
-- Forma: perfil de revolución más ancho abajo que arriba (radio según la altura). Se construye con una
-- fila de esferas a lo largo del eje, cada una la más grande que cabe dentro del perfil: juntas dan un
-- contorno liso, sin las aristas que dejan dos óvalos cruzados.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

export type Palette = { shell: Color3, spots: Color3, spotsDark: Color3, glow: Color3, outline: Color3 }

local EggModel = {}

EggModel.HALF_HEIGHT = 1.65
EggModel.RADIUS = 1.2
local TAPER = 0.16 -- cuánto más estrecha es la punta de arriba que la base
local SPHERES = 12
local SPOT_COUNT = 16

local PALETTES: { [string]: Palette } = {
	-- Común: cáscara crema con motas pardas, como un huevo de verdad.
	Common = {
		shell = Color3.fromRGB(240, 230, 200),
		spots = Color3.fromRGB(175, 130, 80),
		spotsDark = Color3.fromRGB(115, 80, 45),
		glow = Color3.fromRGB(255, 235, 190),
		outline = Color3.fromRGB(255, 245, 220),
	},
	Uncommon = {
		shell = Color3.fromRGB(215, 240, 200),
		spots = Color3.fromRGB(80, 185, 80),
		spotsDark = Color3.fromRGB(40, 120, 55),
		glow = Color3.fromRGB(140, 255, 140),
		outline = Color3.fromRGB(200, 255, 200),
	},
	Rare = {
		shell = Color3.fromRGB(205, 225, 250),
		spots = Color3.fromRGB(60, 135, 240),
		spotsDark = Color3.fromRGB(30, 70, 175),
		glow = Color3.fromRGB(110, 180, 255),
		outline = Color3.fromRGB(190, 220, 255),
	},
	Epic = {
		shell = Color3.fromRGB(215, 190, 245),
		spots = Color3.fromRGB(165, 70, 230),
		spotsDark = Color3.fromRGB(95, 30, 160),
		glow = Color3.fromRGB(205, 130, 255),
		outline = Color3.fromRGB(235, 200, 255),
	},
	-- Legendario: cáscara dorada con vetas de fuego.
	Legendary = {
		shell = Color3.fromRGB(250, 205, 90),
		spots = Color3.fromRGB(240, 110, 25),
		spotsDark = Color3.fromRGB(175, 45, 15),
		glow = Color3.fromRGB(255, 190, 70),
		outline = Color3.fromRGB(255, 235, 150),
	},
	-- Mítico: cáscara rosa carmesí con vetas rojas, el color de la rareza.
	Mythic = {
		shell = Color3.fromRGB(250, 190, 205),
		spots = Color3.fromRGB(230, 40, 90),
		spotsDark = Color3.fromRGB(150, 15, 55),
		glow = Color3.fromRGB(255, 90, 130),
		outline = Color3.fromRGB(255, 200, 215),
	},
	-- Pioneros (T6): el huevo de la tirada de montura del día 7, azul marino con motas de oro. No es de
	-- ninguna rareza para no adelantar lo que sale.
	Pioneer = {
		shell = Color3.fromRGB(30, 45, 95),
		spots = Color3.fromRGB(245, 195, 70),
		spotsDark = Color3.fromRGB(190, 130, 35),
		glow = Color3.fromRGB(255, 215, 110),
		outline = Color3.fromRGB(255, 230, 160),
	},
}

function EggModel.palette(rarity: string): Palette
	return PALETTES[rarity] or PALETTES.Common
end

-- Radio del huevo a una altura (0 en el centro, ±HALF_HEIGHT en las puntas).
local function eggRadius(height: number): number
	local t = height / EggModel.HALF_HEIGHT
	if math.abs(t) >= 1 then
		return 0
	end
	return EggModel.RADIUS * math.sqrt(1 - t * t) * (1 - TAPER * t)
end

-- Esferas que rellenan el perfil: X = altura del centro, Y = radio. Se calculan una vez.
local eggSpheres: { Vector2 }? = nil
local function spheresOfEgg(): { Vector2 }
	local cached = eggSpheres
	if cached then
		return cached
	end
	local spheres = {}
	local first = -EggModel.HALF_HEIGHT + 0.5
	local step = 2 * (EggModel.HALF_HEIGHT - 0.5) / (SPHERES - 1)
	for i = 0, SPHERES - 1 do
		local center = first + i * step
		-- La esfera más grande con ese centro que no se sale del perfil.
		local radius = math.huge
		for sample = 0, 400 do
			local height = -EggModel.HALF_HEIGHT + sample * 2 * EggModel.HALF_HEIGHT / 400
			radius = math.min(radius, Vector2.new(height - center, eggRadius(height)).Magnitude)
		end
		table.insert(spheres, Vector2.new(center, radius))
	end
	eggSpheres = spheres
	return spheres
end

-- Pieza del huevo: esfera (Ball) o, con "oval", un óvalo aplastado (para las motas).
local function shellPart(name: string, size: Vector3, color: Color3, oval: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	if oval then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	else
		part.Shape = Enum.PartType.Ball
	end
	part.Size = size
	return part
end

-- Pega una pieza al huevo (la soldadura va dentro de la pieza, así no se confunde con la que lo
-- une a la cabeza del portador).
local function attach(core: BasePart, model: Model, piece: BasePart, offset: CFrame)
	piece.CFrame = core.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = core
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = model
end

-- Huevo de la rareza dada, de pie en el origen. Devuelve el modelo y su pieza principal (la esfera
-- central, anclada: lleva la luz y es la que se suelda o se mueve). Sin padre.
function EggModel.build(rarity: string, name: string?): (Model, BasePart)
	local palette = EggModel.palette(rarity)
	local model = Instance.new("Model")
	model.Name = name or "Huevo"
	model:SetAttribute("Rarity", rarity)

	-- La esfera más cercana al centro es la pieza principal; las demás se le sueldan.
	local spheres = spheresOfEgg()
	local coreIndex = 1
	for i, sphere in spheres do
		if math.abs(sphere.X) < math.abs(spheres[coreIndex].X) then
			coreIndex = i
		end
	end
	local core = spheres[coreIndex]
	local main = shellPart("Cascara", Vector3.one * core.Y * 2, palette.shell, false)
	main.Anchored = true
	main.CFrame = CFrame.new(0, core.X, 0)
	main.Parent = model
	model.PrimaryPart = main
	for i, sphere in spheres do
		if i ~= coreIndex then
			local shell = shellPart("Cascara", Vector3.one * sphere.Y * 2, palette.shell, false)
			attach(main, model, shell, CFrame.new(0, sphere.X - core.X, 0))
		end
	end

	-- Motas por toda la cáscara (espiral con el ángulo áureo), pegadas a la superficie y con su
	-- inclinación. Algo más grandes hacia la base.
	for i = 1, SPOT_COUNT do
		local height = EggModel.HALF_HEIGHT * (0.85 - 1.65 * (i - 0.5) / SPOT_COUNT)
		local angle = i * 2.39996
		local slope = (eggRadius(height + 0.01) - eggRadius(height - 0.01)) / 0.02
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local position = outward * (eggRadius(height) - 0.02) + Vector3.new(0, height - core.X, 0)
		local normal = (outward - Vector3.new(0, slope, 0)).Unit
		local size = 0.22 + (i % 4) * 0.07 + (1 - height / EggModel.HALF_HEIGHT) * 0.06
		local color = if i % 3 == 0 then palette.spotsDark else palette.spots
		local spot = shellPart("Mota", Vector3.new(size * 1.35, size, 0.08), color, true)
		attach(main, model, spot, CFrame.lookAt(position, position + normal) * CFrame.Angles(0, 0, angle))
	end

	local light = Instance.new("PointLight")
	light.Color = palette.glow
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = main
	-- En el modelo, no en una pieza: así resalta el huevo entero con un solo contorno.
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.88
	highlight.FillColor = palette.glow
	highlight.OutlineColor = palette.outline
	highlight.Parent = model
	return model, main
end

-- Trozos de cáscara que salen volando al eclosionar, y un destello del color de la rareza.
function EggModel.burst(position: Vector3, rarity: string, parent: Instance?)
	local palette = EggModel.palette(rarity)
	local rng = Random.new()
	local folder = parent or Workspace
	for i = 1, 10 do
		local shard = Instance.new("Part")
		shard.Name = "Cascara"
		shard.Size = Vector3.new(0.6, 0.15, 0.5)
		shard.Color = if i % 3 == 0 then palette.spots else palette.shell
		shard.Material = Enum.Material.SmoothPlastic
		shard.CanCollide = true
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CFrame = CFrame.new(position)
			* CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3))
		shard.Parent = folder
		local angle = i * math.pi / 5
		shard.AssemblyLinearVelocity = Vector3.new(math.cos(angle) * 12, rng:NextNumber(14, 22), math.sin(angle) * 12)
		Debris:AddItem(shard, 4)
	end
	local flash = Instance.new("Part")
	flash.Name = "Eclosion"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 2
	flash.Color = palette.glow
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CFrame = CFrame.new(position)
	flash.Parent = folder
	TweenService:Create(flash, TweenInfo.new(0.6), { Size = Vector3.one * 9, Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.7)
end

return EggModel
