--!strict
-- Decoraciones del nido del Lobby (cosmético NestDecor, Fase 9 G9d): lo que rodea al nido de huevos de
-- la plaza. Cada jugador ve la suya (NestController la dibuja en su cliente, como su huevo) y su
-- imagen del pase y del Armario es la misma decoración alrededor de un nido pequeño (RewardModels).
--
--   NestDecor.build(cosmeticId, radius)  -- la decoración de un nido de "radius" studs, o nil
--   NestDecor.settle(decor, groundAt)    -- apoya cada roca y cada aguja en el suelo de verdad
--
-- Sale en el origen, con el suelo en y = 0 y el centro del nido en (0, 0, 0); el frente (por donde se
-- llega y se ve el huevo) mira a -Z: lo alto va detrás, en +Z, para no tapar el huevo. Bloques voxel
-- como los demás modelos, con neón donde hay lava y, en el mundo, brasas que suben y una luz floja.

local NestDecor = {}

local BASALT = Color3.fromRGB(52, 50, 54)
local BASALT_LIGHT = Color3.fromRGB(92, 88, 92)
local BASALT_DARK = Color3.fromRGB(34, 32, 36)
local OBSIDIAN = Color3.fromRGB(28, 24, 28)
local OBSIDIAN_SHINE = Color3.fromRGB(70, 62, 75)
local LAVA = Color3.fromRGB(255, 105, 25)
local LAVA_CORE = Color3.fromRGB(255, 195, 80)

local function block(model: Model, cframe: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.Parent = model
	return part
end

-- Un grupo (una roca, una grieta, una aguja) con su punto de apoyo en el suelo: NestDecor.settle lo
-- baja o lo sube hasta el suelo de verdad, que alrededor del nido no es plano.
local function group(model: Model, ground: Vector3): Model
	local piece = Instance.new("Model")
	piece.Name = "Pieza"
	piece.WorldPivot = CFrame.new(ground)
	piece.Parent = model
	return piece
end

-- Punto del anillo a "angle" grados (0 = delante, en -Z; 180 = detrás) y "distance" studs del centro.
local function around(angle: number, distance: number): Vector3
	local radians = math.rad(angle)
	return Vector3.new(math.sin(radians) * distance, 0, -math.cos(radians) * distance)
end

-- Roca de basalto voxel en "piece": tres bloques que se pisan (silueta de canto rodado), la cara de
-- arriba más clara y, si "vein", una veta de lava por la cara de fuera. "at" mira al centro del nido
-- (su -Z), así que la cara de fuera es +Z.
local function boulder(piece: Model, at: CFrame, width: number, height: number, vein: boolean, s: number)
	block(
		piece,
		at * CFrame.new(0, height * 0.37, 0),
		Vector3.new(width, height * 0.74, width * 0.85),
		BASALT,
		Enum.Material.Slate
	)
	block(
		piece,
		at * CFrame.new(-width * 0.15, height * 0.5, width * 0.05) * CFrame.Angles(0, math.rad(14), 0),
		Vector3.new(width * 0.72, height, width * 0.62),
		BASALT,
		Enum.Material.Slate
	)
	block(
		piece,
		at * CFrame.new(width * 0.32, height * 0.27, -width * 0.05),
		Vector3.new(width * 0.55, height * 0.54, width * 0.9),
		BASALT_DARK,
		Enum.Material.Slate
	)
	block(
		piece,
		at * CFrame.new(-width * 0.12, height + 0.06 * s, 0) * CFrame.Angles(0, math.rad(14), 0),
		Vector3.new(width * 0.5, 0.12 * s, width * 0.42),
		BASALT_LIGHT,
		Enum.Material.Slate
	)
	if vein then
		-- Veta en zigzag: dos tramos finos que bajan por la cara de fuera hasta el suelo.
		local face = width * 0.47
		block(
			piece,
			at * CFrame.new(-width * 0.05, height * 0.62, face) * CFrame.Angles(0, 0, math.rad(25)),
			Vector3.new(0.1 * s, height * 0.42, 0.06 * s),
			LAVA_CORE,
			Enum.Material.Neon
		)
		block(
			piece,
			at * CFrame.new(width * 0.08, height * 0.25, face + 0.04 * s) * CFrame.Angles(0, 0, math.rad(-20)),
			Vector3.new(0.12 * s, height * 0.45, 0.06 * s),
			LAVA,
			Enum.Material.Neon
		)
	end
end

-- Volcánico: un foso de lava alrededor del nido (tramos de lava con costras de basalto encima), un
-- muro de rocas de basalto casi pegadas (más bajas delante, para ver el huevo; algunas con vetas de
-- lava) y detrás tres agujas de obsidiana con grietas que brillan y lava en la base. Brasas que suben
-- del foso y una luz naranja floja (el cartel de detrás no se tiñe).
local function volcanic(radius: number): Model
	local model = Instance.new("Model")
	model.Name = "NidoVolcanico"
	local s = radius / 5
	local center = Vector3.zero
	-- El foso: un anillo de tramos de lava tangentes, con un hilo más claro y costras cada pocos tramos.
	local moat = radius * 1.16
	local segments = 28
	local length = 2 * math.pi * moat / segments * 1.15
	for index = 1, segments do
		local angle = (index - 0.5) * 360 / segments
		local at = CFrame.lookAt(around(angle, moat), center)
		local piece = group(model, around(angle, moat))
		block(piece, at * CFrame.new(0, 0.06 * s, 0), Vector3.new(length, 0.12 * s, 1.3 * s), LAVA, Enum.Material.Neon)
		block(
			piece,
			at * CFrame.new(0, 0.1 * s, 0.05 * s),
			Vector3.new(length, 0.1 * s, 0.4 * s),
			LAVA_CORE,
			Enum.Material.Neon
		)
		if index % 3 == 0 then
			block(
				piece,
				at * CFrame.new(length * 0.15, 0.16 * s, -0.12 * s) * CFrame.Angles(0, math.rad(20), 0),
				Vector3.new(length * 0.55, 0.14 * s, 0.5 * s),
				BASALT_DARK,
				Enum.Material.Slate
			)
		end
	end
	-- El muro de rocas: 14, la de delante del todo más baja y las de detrás más altas.
	local wall = radius * 1.48
	local rocks = 14
	for index = 1, rocks do
		local angle = (index - 1) * 360 / rocks + (if index % 2 == 0 then 6 else -4)
		local back = (1 - math.cos(math.rad(angle))) / 2 -- 0 delante, 1 detrás
		local height = (0.7 + back * 1.3 + (index % 3) * 0.15) * s
		local width = (1.5 + back * 0.6 + (index % 2) * 0.25) * s
		local at = CFrame.lookAt(around(angle, wall), center) * CFrame.Angles(0, math.rad((index % 4) * 9 - 13), 0)
		boulder(group(model, around(angle, wall)), at, width, height, index % 2 == 1, s)
	end
	-- Agujas de obsidiana detrás, inclinadas hacia fuera: tres tramos que se afilan, un canto claro y
	-- una grieta de lava que sube por la cara de delante.
	for _, spike in { { 150, 4.2, -14 }, { 180, 6.2, 0 }, { 210, 4.8, 14 } } do
		local height = spike[2] * s
		local base = around(spike[1], wall + 1.1 * s)
		local piece = group(model, base)
		local at = CFrame.lookAt(base, center) * CFrame.Angles(math.rad(-9), 0, math.rad(spike[3] * 0.5))
		block(
			piece,
			at * CFrame.new(0, height * 0.25, 0),
			Vector3.new(1.9 * s, height * 0.5, 1.6 * s),
			OBSIDIAN,
			Enum.Material.Glass
		)
		block(
			piece,
			at * CFrame.new(0, height * 0.62, 0),
			Vector3.new(1.25 * s, height * 0.3, 1.05 * s),
			OBSIDIAN,
			Enum.Material.Glass
		)
		block(
			piece,
			at * CFrame.new(0, height * 0.88, 0),
			Vector3.new(0.65 * s, height * 0.24, 0.55 * s),
			OBSIDIAN,
			Enum.Material.Glass
		)
		block(
			piece,
			at * CFrame.new(-0.72 * s, height * 0.4, -0.68 * s),
			Vector3.new(0.1 * s, height * 0.65, 0.1 * s),
			OBSIDIAN_SHINE,
			Enum.Material.Glass
		)
		block(
			piece,
			at * CFrame.new(0.15 * s, height * 0.3, -0.82 * s) * CFrame.Angles(0, 0, math.rad(8)),
			Vector3.new(0.18 * s, height * 0.5, 0.06 * s),
			LAVA,
			Enum.Material.Neon
		)
		block(
			piece,
			at * CFrame.new(0.05 * s, height * 0.62, -0.55 * s) * CFrame.Angles(0, 0, math.rad(-12)),
			Vector3.new(0.14 * s, height * 0.25, 0.06 * s),
			LAVA_CORE,
			Enum.Material.Neon
		)
		block(piece, at * CFrame.new(0, 0.07 * s, 0), Vector3.new(2.8 * s, 0.14 * s, 2.5 * s), LAVA, Enum.Material.Neon)
		block(
			piece,
			at * CFrame.new(1 * s, 0.2 * s, 0.6 * s),
			Vector3.new(0.9 * s, 0.4 * s, 0.6 * s),
			BASALT,
			Enum.Material.Slate
		)
	end
	-- Brasas y luz (en un ViewportFrame no se ven; en el mundo, sí).
	local glow = block(model, CFrame.new(0, 0.05, 0), Vector3.new(0.2, 0.1, 0.2), LAVA, Enum.Material.Neon)
	glow.Name = "Brillo"
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = LAVA
	light.Range = radius * 2.2
	light.Brightness = 0.8
	light.Parent = glow
	local lit = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Color == LAVA and part.Size.Y < 0.2 * s then
			lit += 1
			if lit % 4 == 0 then
				local embers = Instance.new("ParticleEmitter")
				embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				embers.Color = ColorSequence.new(LAVA_CORE, LAVA)
				embers.Size = NumberSequence.new(0.15 * s, 0)
				embers.LightEmission = 1
				embers.Rate = 1.5
				embers.Lifetime = NumberRange.new(1.5, 2.5)
				embers.Speed = NumberRange.new(1.5, 3)
				embers.Acceleration = Vector3.new(0, 1, 0)
				embers.EmissionDirection = Enum.NormalId.Top
				embers.SpreadAngle = Vector2.new(20, 20)
				embers.Parent = part
			end
		end
	end
	return model
end

local BUILDERS: { [string]: (radius: number) -> Model } = {
	VolcanicNest = volcanic,
}

-- Apoya cada grupo de "decor" (ya colocada) en el suelo: "groundAt" da la altura del suelo bajo un
-- punto, o nil si no lo encuentra (el grupo se queda donde está).
function NestDecor.settle(decor: Model, groundAt: (Vector3) -> number?)
	for _, piece in decor:GetChildren() do
		if piece:IsA("Model") then
			local pivot = piece:GetPivot()
			local ground = groundAt(pivot.Position)
			if ground then
				piece:PivotTo(pivot + Vector3.new(0, ground - pivot.Position.Y, 0))
			end
		end
	end
end

-- ¿Tiene modelo la decoración "cosmeticId"?
function NestDecor.has(cosmeticId: string): boolean
	return BUILDERS[cosmeticId] ~= nil
end

function NestDecor.build(cosmeticId: string, radius: number): Model?
	local builder = BUILDERS[cosmeticId]
	if not builder then
		return nil
	end
	local model = builder(radius)
	model.WorldPivot = CFrame.identity
	return model
end

return NestDecor
