--!strict
-- Coberturas que se rompen (Fase 10, C11): lo que se ve en este cliente de lo que decide CoverService
-- (atributos del modelo "CoverHealth", "CoverMaxHealth" y "CoverBroken"):
--   - Cada golpe que la alcanza: esquirlas de piedra que saltan y un poco de polvo.
--   - Con dos tercios y con un tercio de piedra: grietas voxel (bloques oscuros en zigzag que bajan desde
--     arriba) en dos caras de sus piezas grandes. Salen igual en todos los clientes (al azar con la
--     semilla de su posición).
--   - Al romperse: trozos voxel del color de cada pieza que saltan, caen y rebotan en el suelo, y una
--     nube de polvo. Las piezas de verdad ya no se ven (las esconde el servidor).
--   - Al volver: polvo.
-- Todo va en workspace.CoverFx y se va solo. Los trozos se mueven aquí (anclados, sin física): no
-- empujan a nadie.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local CRACK_COLOR = Color3.fromRGB(45, 34, 26)
local DUST_COLOR = Color3.fromRGB(220, 190, 140)
local GRAVITY = 150
local CHUNK_LIFE = 2.2
local CHUNK_FADE = 0.6
local CHIP_LIFE = 0.8
-- Lado de cada bloque de las grietas (studs).
local CRACK_BLOCK = 0.38
-- Piezas que cuentan como grandes (para las grietas y los trozos), por volumen (studs³).
local BIG_VOLUME = 20

type Chunk = {
	part: BasePart,
	velocity: Vector3,
	spin: Vector3,
	ground: number,
	born: number,
	life: number,
}
type Cover = {
	model: Model,
	parts: { BasePart },
	big: { BasePart }, -- de mayor a menor
	cracks: Folder?,
	stage: number,
}

local CoverController = {}

local fxFolder: Folder
local chunks: { Chunk } = {}

local function fxPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function volume(part: BasePart): number
	return part.Size.X * part.Size.Y * part.Size.Z
end

-- La altura del suelo bajo "position" (sin las coberturas ni los efectos).
local function groundBelow(position: Vector3, cover: Model): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { cover, fxFolder }
	local hit = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else position.Y - 10
end

local function throw(part: BasePart, velocity: Vector3, ground: number, life: number)
	part.Parent = fxFolder
	table.insert(chunks, {
		part = part,
		velocity = velocity,
		spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 10,
		ground = ground,
		born = os.clock(),
		life = life,
	})
end

local function dust(position: Vector3, amount: number, size: number)
	local holder = fxPart("Polvo", Vector3.one, CFrame.new(position), DUST_COLOR, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(DUST_COLOR)
	emitter.Size = NumberSequence.new(size * 0.5, size)
	emitter.Transparency = NumberSequence.new(0.35, 1)
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Speed = NumberRange.new(3, 8)
	emitter.SpreadAngle = Vector2.new(180, 30)
	emitter.Acceleration = Vector3.new(0, 2, 0)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Rate = 0
	emitter.Parent = holder
	holder.Parent = fxFolder
	emitter:Emit(amount)
	task.delay(3, function()
		holder:Destroy()
	end)
end

local function centerOf(cover: Cover): Vector3
	return cover.model:GetBoundingBox().Position
end

-- Esquirlas de un golpe: unas pocas piedrecitas desde la parte alta de la pieza mayor.
local function chips(cover: Cover)
	local main = cover.big[1]
	if not main then
		return
	end
	local ground = groundBelow(main.Position, cover.model)
	for _ = 1, 6 do
		local at = main.CFrame
			* CFrame.new(
				(math.random() - 0.5) * main.Size.X,
				(math.random() * 0.4 + 0.1) * main.Size.Y,
				(math.random() - 0.5) * main.Size.Z
			)
		local away = (at.Position - main.Position) * Vector3.new(1, 0, 1)
		local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
		local chip = fxPart("Esquirla", Vector3.one * 0.35, at, main.Color, main.Material)
		throw(chip, direction * (4 + math.random() * 6) + Vector3.new(0, 8 + math.random() * 6, 0), ground, CHIP_LIFE)
	end
	dust(main.Position, 4, 3)
end

-- Al romperse: trozos de cada pieza visible, con su color, que saltan hacia fuera.
local function crumble(cover: Cover)
	local center = centerOf(cover)
	local ground = groundBelow(center, cover.model)
	local budget = 40
	for _, part in cover.parts do
		if budget <= 0 then
			break
		end
		if part.Size.Magnitude >= 1.5 then
			local count = math.clamp(math.round(volume(part) / 12), 2, 8)
			local side = math.clamp(math.min(part.Size.X, part.Size.Y, part.Size.Z) * 0.6, 0.6, 1.8)
			for _ = 1, math.min(count, budget) do
				budget -= 1
				local at = part.CFrame
					* CFrame.new(
						(math.random() - 0.5) * part.Size.X,
						(math.random() - 0.5) * part.Size.Y,
						(math.random() - 0.5) * part.Size.Z
					)
				local away = (at.Position - center) * Vector3.new(1, 0, 1)
				local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
				local chunk =
					fxPart("Trozo", Vector3.one * side * (0.7 + math.random() * 0.5), at, part.Color, part.Material)
				throw(
					chunk,
					direction * (5 + math.random() * 9) + Vector3.new(0, 6 + math.random() * 12, 0),
					ground,
					CHUNK_LIFE + math.random() * 0.4
				)
			end
		end
	end
	dust(Vector3.new(center.X, ground + 2, center.Z), 22, 7)
end

-- Una grieta voxel en "part": bloques oscuros en zigzag que bajan por la cara que mira hacia "angle" (en
-- horizontal) desde "fromY" (o desde lo más alto de esa cara), "steps" bloques, cada uno a un lado o
-- debajo del anterior. Los encuentra con un rayo contra las piezas de la cobertura ("surface": así pasa
-- también por encima del relieve de la cara), centrado en "part" (vale para losas y tambores).
local function crack(
	part: BasePart,
	surface: { Instance },
	angle: number,
	fromY: number?,
	steps: number,
	random: Random,
	folder: Folder
)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = surface
	local reach = part.Size.Magnitude
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local across = Vector3.new(-direction.Z, 0, direction.X)
	local bottom = part.Position.Y - reach / 2
	local y = fromY or part.Position.Y + reach / 2
	local offset = (random:NextNumber() - 0.5) * 1.2
	local placed = 0
	while placed < steps and y > bottom do
		local origin = Vector3.new(part.Position.X, y, part.Position.Z) + direction * reach + across * offset
		local hit = Workspace:Raycast(origin, -direction * reach, params)
		if hit then
			local position = hit.Position + hit.Normal * 0.06
			local stone = fxPart(
				"Grieta",
				Vector3.new(CRACK_BLOCK, CRACK_BLOCK, 0.2),
				CFrame.lookAt(position, position + hit.Normal),
				CRACK_COLOR,
				Enum.Material.SmoothPlastic
			)
			stone.Parent = folder
			placed += 1
			-- Un escalón más abajo, en diagonal a un lado (casi siempre) o recto: el zigzag.
			local roll = random:NextNumber()
			if roll < 0.4 then
				offset -= CRACK_BLOCK
			elseif roll < 0.8 then
				offset += CRACK_BLOCK
			end
			offset = math.clamp(offset, -1.4, 1.4)
			y -= CRACK_BLOCK
		else
			y -= 0.25
		end
	end
end

local function drawCracks(cover: Cover, stage: number)
	if cover.cracks then
		cover.cracks:Destroy()
		cover.cracks = nil
	end
	cover.stage = stage
	if stage <= 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = `Grietas_{cover.model.Name}`
	-- El relieve, los ojos y la boca son decorado (los rayos no los ven): solo en este cliente y mientras
	-- se dibujan las grietas, que sí.
	local hidden: { BasePart } = {}
	local surface: { Instance } = {}
	for _, piece in cover.parts do
		table.insert(surface, piece)
		if not piece.CanQuery then
			piece.CanQuery = true
			table.insert(hidden, piece)
		end
	end
	local seed = cover.model:GetPivot().Position
	local random = Random.new(math.floor(seed.X * 7 + seed.Z * 13))
	for index, part in cover.big do
		if index > stage then
			break
		end
		-- Las dos caras anchas de una losa (su ±Z) o dos lados opuestos de un tambor.
		local look = part.CFrame.LookVector
		local base = if part.Shape == Enum.PartType.Cylinder
			then random:NextNumber(0, math.pi)
			else math.atan2(look.Z, look.X)
		for _, side in { 0, math.pi } do
			-- Una desde arriba y, más rota, otra que nace a media altura.
			crack(part, surface, base + side, nil, if stage >= 2 then 16 else 9, random, folder)
			if stage >= 2 then
				crack(part, surface, base + side, part.Position.Y + random:NextNumber(-1, 1.5), 7, random, folder)
			end
		end
	end
	for _, piece in hidden do
		piece.CanQuery = false
	end
	folder.Parent = fxFolder
	cover.cracks = folder
end

local function stageOf(model: Model): number
	local health = model:GetAttribute("CoverHealth")
	local max = model:GetAttribute("CoverMaxHealth")
	if model:GetAttribute("CoverBroken") == true or typeof(health) ~= "number" or typeof(max) ~= "number" then
		return 0
	end
	local fraction = health / max
	return if fraction <= 1 / 3 then 2 elseif fraction <= 2 / 3 then 1 else 0
end

local function watch(model: Model)
	local parts: { BasePart } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	local big = {}
	for _, part in parts do
		if part.CanCollide and volume(part) >= BIG_VOLUME then
			table.insert(big, part)
		end
	end
	table.sort(big, function(a, b)
		return volume(a) > volume(b)
	end)
	local cover: Cover = { model = model, parts = parts, big = big, cracks = nil, stage = 0 }
	local lastHealth = model:GetAttribute("CoverHealth")
	local broken = model:GetAttribute("CoverBroken") == true
	drawCracks(cover, stageOf(model))
	model:GetAttributeChangedSignal("CoverHealth"):Connect(function()
		local health = model:GetAttribute("CoverHealth")
		if typeof(health) == "number" and typeof(lastHealth) == "number" and health < lastHealth and health > 0 then
			chips(cover)
		end
		lastHealth = health
		local stage = stageOf(model)
		if stage ~= cover.stage then
			drawCracks(cover, stage)
		end
	end)
	model:GetAttributeChangedSignal("CoverBroken"):Connect(function()
		local now = model:GetAttribute("CoverBroken") == true
		if now and not broken then
			drawCracks(cover, 0)
			crumble(cover)
		elseif broken and not now then
			dust(centerOf(cover), 12, 5)
		end
		broken = now
	end)
end

local function step(deltaTime: number)
	local now = os.clock()
	local index = 1
	while index <= #chunks do
		local chunk = chunks[index]
		local age = now - chunk.born
		if age >= chunk.life + CHUNK_FADE then
			chunk.part:Destroy()
			chunks[index] = chunks[#chunks]
			chunks[#chunks] = nil
		else
			local part = chunk.part
			chunk.velocity -= Vector3.new(0, GRAVITY * deltaTime, 0)
			local position = part.Position + chunk.velocity * deltaTime
			local floor = chunk.ground + part.Size.Y / 2
			if position.Y < floor then
				position = Vector3.new(position.X, floor, position.Z)
				chunk.velocity = Vector3.new(chunk.velocity.X * 0.55, -chunk.velocity.Y * 0.3, chunk.velocity.Z * 0.55)
				chunk.spin *= 0.5
			end
			local turn = chunk.spin * deltaTime
			part.CFrame = CFrame.new(position) * part.CFrame.Rotation * CFrame.Angles(turn.X, turn.Y, turn.Z)
			if age > chunk.life then
				part.Transparency = (age - chunk.life) / CHUNK_FADE
			end
			index += 1
		end
	end
end

function CoverController:Start()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "CoverFx"
	fxFolder.Parent = Workspace
	RunService.RenderStepped:Connect(step)
	local arena = Workspace:WaitForChild("Arena")
	local tag = Config.Combat.DestructibleTag
	local watched: { [Model]: boolean } = {}
	local function consider(instance: Instance)
		if instance:IsA("Model") and instance:IsDescendantOf(arena) and not watched[instance] then
			watched[instance] = true
			watch(instance)
		end
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(consider)
	for _, instance in CollectionService:GetTagged(tag) do
		consider(instance)
	end
end

return CoverController
