--!strict
-- Efectos de los emotes de la Temporada 1 (Fase 9, G11c), en el Lobby y en la Isla. Cada cliente escucha
-- las animaciones que empiezan en el personaje de cada jugador (Animator.AnimationPlayed, que también
-- llega con las de los demás porque las animaciones del jugador se replican), reconoce las de los emotes
-- (Shared/EmoteTracks) y saca el efecto en los marcadores de su animación (Data/EmoteAnimations). Así
-- todos lo ven a la vez y sin pasar por el servidor. Solo bloques y chispas: nada de verde (curación),
-- morado (veneno) ni rojo (daño recibido).
--   - Grito de gorila: polvo que salta del pecho en cada golpe ("Golpe") y, al rugir ("Rugido"), una
--     onda de polvo por el suelo con piedrecitas que saltan y aros de aire delante de la cara.
--   - Danza del fuego: llamas azules en las dos manos mientras baila y chispas de azufre en cada
--     pisotón ("Pisada").
--   - Erupción: grietas de lava que se abren alrededor de los pies mientras tiembla ("Temblor") y, al
--     saltar ("Erupcion"), un chorro de ceniza y brasas desde el suelo con un aro de lava.
-- Arranca con la rueda (UI/EmoteWheel.start).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EmoteTracks = require(ReplicatedStorage.Shared.EmoteTracks)

local GRAVITY = Vector3.new(0, -60, 0)
local RING_SEGMENTS = 18

local DUST = Color3.fromRGB(205, 180, 135)
local STONE = Color3.fromRGB(120, 112, 104)
local AIR = Color3.fromRGB(245, 240, 225)
local BLUE_FIRE = Color3.fromRGB(45, 120, 255)
local BLUE_FIRE_CORE = Color3.fromRGB(170, 225, 255)
local SULFUR = Color3.fromRGB(235, 205, 55)
-- En neón los naranjas claros se ven amarillos: la lava y las brasas van más oscuras.
local LAVA = Color3.fromRGB(255, 90, 0)
local EMBER = Color3.fromRGB(255, 130, 15)
local ASH = Color3.fromRGB(48, 45, 45)

local EmoteFx = {}

local rng = Random.new()
local folder: Folder? = nil
local started = false

local function fxFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "EmoteFx"
	created.Parent = Workspace
	folder = created
	return created
end

local function piece(size: Vector3, color: Color3, material: Enum.Material, transparency: number?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material
	part.Transparency = transparency or 0
	return part
end

-- Llama a "step" cada fotograma durante "seconds" (alpha de 0 a 1) y a "done" al final.
local function animate(seconds: number, step: (alpha: number, deltaTime: number) -> (), done: (() -> ())?)
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		elapsed += deltaTime
		local alpha = math.min(elapsed / seconds, 1)
		local ok, message = pcall(step, alpha, deltaTime)
		if not ok or alpha >= 1 then
			connection:Disconnect()
			if not ok then
				warn(`EmoteFx: {message}`)
			end
			if done then
				pcall(done)
			end
		end
	end)
end

-- Lanza una pieza por el aire con gravedad y giro; se desvanece al final.
local function fling(part: BasePart, velocity: Vector3, seconds: number, gravity: Vector3?)
	local base = part.Transparency
	local spin = rng:NextUnitVector() * 8
	part.Parent = fxFolder()
	animate(seconds, function(alpha, deltaTime)
		velocity += (gravity or GRAVITY) * deltaTime
		part.CFrame = (part.CFrame + velocity * deltaTime) * CFrame.Angles(spin.X * deltaTime, spin.Y * deltaTime, 0)
		if alpha > 0.6 then
			part.Transparency = base + (1 - base) * (alpha - 0.6) / 0.4
		end
	end, function()
		part:Destroy()
	end)
end

-- Aro plano de bloques que se abre en "cframe" (su eje Y es el del aro: hacia arriba, en el suelo), de
-- "width" de ancho y que empieza con "transparency".
local function ring(
	cframe: CFrame,
	fromRadius: number,
	toRadius: number,
	seconds: number,
	color: Color3,
	material: Enum.Material,
	width: number,
	transparency: number
)
	local segments: { Part } = {}
	for index = 1, RING_SEGMENTS do
		local segment = piece(Vector3.new(width, 0.25, 1), color, material, transparency)
		segment.Parent = fxFolder()
		segments[index] = segment
	end
	animate(seconds, function(alpha)
		local eased = 1 - (1 - alpha) ^ 2
		local radius = fromRadius + (toRadius - fromRadius) * eased
		local length = math.max(2 * math.pi * radius / RING_SEGMENTS * 1.05, 0.05)
		for index, segment in segments do
			local angle = index / RING_SEGMENTS * 2 * math.pi
			segment.Size = Vector3.new(width, 0.25, length)
			segment.CFrame = cframe
				* CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
				* CFrame.Angles(0, -angle, 0)
			segment.Transparency = transparency + (1 - transparency) * alpha
		end
	end, function()
		for _, segment in segments do
			segment:Destroy()
		end
	end)
end

local function groundUnder(character: Model, root: BasePart): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, fxFolder() }
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	return if result then result.Position else root.Position - Vector3.new(0, 3, 0)
end

local function partOf(character: Model, name: string): BasePart?
	local part = character:FindFirstChild(name)
	return if part and part:IsA("BasePart") then part else nil
end

-- Bloques de "colors" que salen de "origin" hacia "direction" (abriéndose "spread"), a "speed".
local function burst(
	origin: Vector3,
	direction: Vector3,
	count: number,
	speed: number,
	spread: number,
	colors: { Color3 },
	size: number,
	material: Enum.Material,
	seconds: number,
	gravity: Vector3?
)
	for _ = 1, count do
		local color = colors[rng:NextInteger(1, #colors)]
		local block = piece(Vector3.one * size * rng:NextNumber(0.6, 1.2), color, material)
		block.CFrame = CFrame.new(origin) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		local velocity = (direction.Unit + rng:NextUnitVector() * spread).Unit * speed * rng:NextNumber(0.7, 1.2)
		fling(block, velocity, seconds * rng:NextNumber(0.8, 1.2), gravity)
	end
end

-- Bloques de la llama de una mano, de abajo arriba: { lado, alto sobre la mano, desvío a un lado, color }.
-- Como las llamas en píxeles de los trajes de la temporada: azul oscuro abajo y claro en la punta.
local FLAME_BLOCKS: { { any } } = {
	{ 0.6, 0.3, 0, Color3.fromRGB(30, 80, 220) },
	{ 0.46, 0.75, 0.04, BLUE_FIRE },
	{ 0.32, 1.12, -0.05, BLUE_FIRE },
	{ 0.2, 1.42, 0.06, BLUE_FIRE_CORE },
	{ 0.24, 0.55, 0.36, BLUE_FIRE },
	{ 0.2, 0.62, -0.34, BLUE_FIRE_CORE },
}

-- Llama azul de bloques de neón en una mano mientras dura el baile: va con la mano pero siempre hacia
-- arriba, y cada bloque baila un poco. Con chispas azules y su luz. (Las partículas de fuego de Roblox
-- salían oscuras como humo o blancas al sol.)
local function handFlame(hand: BasePart): Folder
	local flame = Instance.new("Folder")
	flame.Name = "EmoteFlame"
	local blocks: { Part } = {}
	for index, block in FLAME_BLOCKS do
		local part = piece(Vector3.one * block[1], block[4], Enum.Material.Neon)
		part.Parent = flame
		blocks[index] = part
	end
	flame.Parent = fxFolder()
	local attachment = Instance.new("Attachment")
	attachment.Name = "EmoteFlame"
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(BLUE_FIRE_CORE, BLUE_FIRE)
	sparks.LightEmission = 0.4
	sparks.Size = NumberSequence.new(0.15, 0)
	sparks.Lifetime = NumberRange.new(0.4, 0.7)
	sparks.Rate = 18
	sparks.Speed = NumberRange.new(2, 4)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.Acceleration = Vector3.new(0, 4, 0)
	sparks.Parent = attachment
	local light = Instance.new("PointLight")
	light.Color = BLUE_FIRE
	light.Range = 7
	light.Brightness = 1.5
	light.Parent = attachment
	attachment.Parent = hand
	-- Al quitar la carpeta (se para el emote), se quitan las chispas.
	flame.Destroying:Connect(function()
		attachment:Destroy()
	end)
	local phase = rng:NextNumber(0, 10)
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not (flame.Parent and hand.Parent) then
			connection:Disconnect()
			return
		end
		local clock = os.clock() * 9 + phase
		local base = hand.Position
		for index, part in blocks do
			local block = FLAME_BLOCKS[index]
			local flicker = math.sin(clock + index * 1.7)
			part.Size = Vector3.one * block[1] * (1 + 0.12 * flicker)
			part.CFrame = CFrame.new(base + Vector3.new(block[3] + 0.04 * flicker, block[2] + 0.06 * flicker, 0))
				* CFrame.Angles(0, clock * 0.2 + index, 0)
		end
	end)
	return flame
end

type Handlers = {
	markers: { [string]: (character: Model, root: BasePart) -> () },
	-- Mientras suena: devuelve lo que hay que quitar al pararse.
	during: ((character: Model) -> { Instance })?,
}

local EFFECTS: { [string]: Handlers } = {
	EmoteGorillaRoar = {
		markers = {
			Golpe = function(character, root)
				local chest = partOf(character, "UpperTorso") or root
				local front = chest.CFrame * CFrame.new(0, 0.2, -chest.Size.Z / 2 - 0.2)
				burst(
					front.Position,
					front.LookVector + Vector3.new(0, 0.3, 0),
					6,
					14,
					0.6,
					{ DUST, AIR },
					0.3,
					Enum.Material.SmoothPlastic,
					0.35,
					Vector3.zero
				)
			end,
			Rugido = function(character, root)
				local ground = groundUnder(character, root)
				ring(
					CFrame.new(ground + Vector3.new(0, 0.15, 0)),
					1,
					9,
					0.7,
					DUST,
					Enum.Material.SmoothPlastic,
					0.6,
					0.1
				)
				burst(
					ground + Vector3.new(0, 0.3, 0),
					Vector3.yAxis,
					10,
					22,
					0.8,
					{ STONE, DUST },
					0.45,
					Enum.Material.Slate,
					0.9
				)
				-- Aros de aire delante de la cara, uno tras otro.
				local head = partOf(character, "Head") or root
				for index = 0, 2 do
					task.delay(index * 0.18, function()
						local face = head.CFrame
							* CFrame.new(0, 0, -2 - index * 0.6)
							* CFrame.Angles(math.rad(90), 0, 0)
						ring(face, 0.4, 1.8, 0.35, AIR, Enum.Material.SmoothPlastic, 0.15, 0.55)
					end)
				end
			end,
		},
	},
	EmoteFireDance = {
		markers = {
			Pisada = function(character, root)
				local ground = groundUnder(character, root)
				local right, left = partOf(character, "RightFoot"), partOf(character, "LeftFoot")
				local foot = if right and left
					then (if right.Position.Y < left.Position.Y then right else left)
					else root
				local at = Vector3.new(foot.Position.X, ground.Y + 0.2, foot.Position.Z)
				ring(CFrame.new(at), 0.3, 3, 0.4, SULFUR, Enum.Material.Neon, 0.3, 0.15)
				burst(at, Vector3.yAxis, 8, 14, 0.9, { SULFUR, BLUE_FIRE }, 0.22, Enum.Material.Neon, 0.5)
			end,
		},
		during = function(character)
			local made: { Instance } = {}
			for _, name in { "RightHand", "LeftHand" } do
				local hand = partOf(character, name)
				if hand then
					table.insert(made, handFlame(hand))
				end
			end
			return made
		end,
	},
	EmoteEruption = {
		markers = {
			Temblor = function(character, root)
				-- Grietas que salen de los pies y se van alargando; se apagan después del salto.
				local ground = groundUnder(character, root)
				local cracks: { Part } = {}
				for index = 1, 7 do
					local angle = index / 7 * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
					local crack = piece(Vector3.new(0.3, 0.12, 0.1), LAVA, Enum.Material.Neon)
					crack.CFrame = CFrame.new(ground + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, angle, 0)
					crack.Parent = fxFolder()
					cracks[index] = crack
				end
				animate(0.8, function(alpha)
					for _, crack in cracks do
						local length = 0.5 + 4.5 * alpha
						local base = crack.CFrame - crack.CFrame.Position
						crack.Size = Vector3.new(0.3, 0.12, length)
						crack.CFrame = CFrame.new(ground + Vector3.new(0, 0.06, 0))
							* base
							* CFrame.new(0, 0, -length / 2 - 0.6)
					end
				end, function()
					for _, crack in cracks do
						if crack.Parent then
							TweenService:Create(
								crack,
								TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.6),
								{ Transparency = 1 }
							):Play()
							Debris:AddItem(crack, 1.5)
						end
					end
				end)
			end,
			Erupcion = function(character, root)
				local ground = groundUnder(character, root)
				ring(CFrame.new(ground + Vector3.new(0, 0.15, 0)), 1, 7, 0.6, LAVA, Enum.Material.Neon, 0.7, 0)
				burst(
					ground + Vector3.new(0, 0.4, 0),
					Vector3.yAxis,
					16,
					38,
					0.25,
					{ ASH, ASH, STONE },
					0.6,
					Enum.Material.SmoothPlastic,
					1.1
				)
				burst(
					ground + Vector3.new(0, 0.4, 0),
					Vector3.yAxis,
					14,
					30,
					0.45,
					{ LAVA, LAVA, EMBER },
					0.3,
					Enum.Material.Neon,
					1.0
				)
			end,
		},
	},
}

local function onTrack(character: Model, track: AnimationTrack)
	local animation = track.Animation
	local cosmeticId = if animation then EmoteTracks.cosmeticOf(animation.AnimationId) else nil
	local handlers = if cosmeticId then EFFECTS[cosmeticId] else nil
	if not handlers then
		return
	end
	local connections: { RBXScriptConnection } = {}
	for name, effect in handlers.markers do
		table.insert(
			connections,
			track:GetMarkerReachedSignal(name):Connect(function()
				local root = partOf(character, "HumanoidRootPart")
				if root and character.Parent then
					effect(character, root)
				end
			end)
		)
	end
	local made = if handlers.during then handlers.during(character) else {}
	local stopped: RBXScriptConnection
	stopped = track.Stopped:Connect(function()
		stopped:Disconnect()
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, item in made do
			item:Destroy()
		end
	end)
end

local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local animator = if humanoid then humanoid:WaitForChild("Animator", 10) else nil
	if not (animator and animator:IsA("Animator")) then
		return
	end
	animator.AnimationPlayed:Connect(function(track)
		onTrack(character, track)
	end)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end

-- Empieza a escuchar a todos los jugadores (una vez por place).
function EmoteFx.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return EmoteFx
