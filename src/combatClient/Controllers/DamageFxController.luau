--!strict
-- Pantalla roja al recibir daño (ajuste "damageFx", Config.DamageFx). Todo en rojo, hecho con Frame y
-- UIGradient, sin imágenes:
--   - Destello de bordes: se dispara con un golpe crítico, a la cabeza (entry.head) o de al menos
--     BigHitFraction de tu vida máxima. Más fuerte con la cabeza. Uno nuevo refresca el anterior.
--   - Pulso con salud baja: la viñeta late mientras la vida está bajo LowHealthFraction.
--   - Arco de dirección (PvP): un segmento rojo en un anillo alrededor del centro, hacia el atacante
--     según la cámara. El origen sale de entry.from o, si falta, del personaje del jugador entry.by.
-- Escucha el lote de Remotes.CombatText y solo mira las entradas "Taken" sobre tu personaje.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local FX = Config.DamageFx

-- Rojo del daño recibido (nunca verde ni morado).
local RED = Color3.fromRGB(220, 30, 30)
local RED_ARC = Color3.fromRGB(255, 50, 50)
-- Grosor de la viñeta (parte del alto o del ancho de la pantalla).
local EDGE_SIZE = 0.22
-- Anillo del arco: radio como parte del alto de pantalla, límites en píxeles, y tamaño del segmento.
local ARC_RADIUS = 0.28
local ARC_RADIUS_MIN = 80
local ARC_RADIUS_MAX = 260
local ARC_LENGTH = 130
local ARC_THICKNESS = 16

local DamageFxController = {}

local player = Players.LocalPlayer
local edges: { Frame } = {}
local arcsFolder: Frame
-- Destello: cuándo empezó y con qué fuerza.
local flashStart = -math.huge
local flashPeak = 0
-- Pulso con salud baja: si toca latir y cuánto pesa (0..1, se funde en PulseFadeSeconds).
local lowHealth = false
local pulseWeight = 0
local lastIntensity = -1
local humanoidConnections: { RBXScriptConnection } = {}

-- Un borde de la viñeta: opaco en el borde de la pantalla y transparente hacia dentro.
local function edge(parent: Instance, name: string, position: UDim2, size: UDim2, anchor: Vector2, rotation: number)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.Size = size
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = RED
	frame.BackgroundTransparency = 1
	frame.Active = false
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new(0, 1)
	gradient.Parent = frame
	frame.Parent = parent
	table.insert(edges, frame)
end

-- Fuerza de la viñeta entre 0 y 1 (transparencia de los cuatro bordes).
local function setIntensity(intensity: number)
	if intensity == lastIntensity then
		return
	end
	lastIntensity = intensity
	local transparency = 1 - math.clamp(intensity, 0, 1)
	for _, frame in edges do
		frame.BackgroundTransparency = transparency
	end
end

local function clearArcs()
	arcsFolder:ClearAllChildren()
end

local function enabled(): boolean
	return Settings.get().damageFx
end

-- Apaga lo que haya en pantalla.
local function reset()
	flashStart = -math.huge
	flashPeak = 0
	pulseWeight = 0
	setIntensity(0)
	clearArcs()
end

local function flash(peak: number)
	-- Uno nuevo refresca el anterior: nunca baja la fuerza de uno en marcha.
	local current = flashPeak * math.max(0, 1 - (os.clock() - flashStart) / FX.FlashSeconds)
	flashPeak = math.max(peak, current)
	flashStart = os.clock()
end

-- Segmento de arco hacia el punto "origin" del mundo, respecto a la cámara.
local function showArc(origin: Vector3)
	local camera = Workspace.CurrentCamera
	local character = player.Character
	local root = if character then character.PrimaryPart else nil
	if not (camera and root) then
		return
	end
	local offset = origin - root.Position
	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	local forward = Vector3.new(look.X, 0, look.Z)
	local side = Vector3.new(right.X, 0, right.Z)
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if forward.Magnitude < 0.01 or flat.Magnitude < 0.01 then
		return
	end
	local angle = math.deg(math.atan2(flat:Dot(side.Unit), flat:Dot(forward.Unit)))

	local scale = math.clamp(camera.ViewportSize.Y / 720, 0.85, 1.3)
	local radius = math.clamp(camera.ViewportSize.Y * ARC_RADIUS, ARC_RADIUS_MIN, ARC_RADIUS_MAX)
	local container = Instance.new("Frame")
	container.Name = "Arc"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Size = UDim2.fromOffset(radius * 2, radius * 2)
	container.BackgroundTransparency = 1
	container.Rotation = angle
	container.Active = false
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(ARC_RADIUS_MAX * 2, ARC_RADIUS_MAX * 2)
	constraint.Parent = container

	local segment = Instance.new("Frame")
	segment.Name = "Segment"
	segment.AnchorPoint = Vector2.new(0.5, 0.5)
	segment.Position = UDim2.fromScale(0.5, 0)
	segment.Size = UDim2.fromOffset(ARC_LENGTH * scale, ARC_THICKNESS * scale)
	segment.BorderSizePixel = 0
	segment.BackgroundColor3 = RED_ARC
	segment.BackgroundTransparency = 0.1
	segment.Active = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = segment
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = segment
	segment.Parent = container
	container.Parent = arcsFolder

	local tween = TweenService:Create(
		segment,
		TweenInfo.new(FX.ArcSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	)
	tween:Play()
	task.delay(FX.ArcSeconds, function()
		container:Destroy()
	end)
end

local function attackerPosition(entry: any): Vector3?
	if typeof(entry.from) == "Vector3" then
		return entry.from
	end
	if typeof(entry.by) == "number" then
		local attacker = Players:GetPlayerByUserId(entry.by)
		local root = if attacker and attacker.Character then attacker.Character.PrimaryPart else nil
		if root then
			return root.Position
		end
	end
	return nil
end

local function onEntry(entry: any, humanoid: Humanoid?)
	if typeof(entry) ~= "table" or entry.kind ~= "Taken" or entry.target ~= player.Character then
		return
	end
	local amount = if typeof(entry.amount) == "number" then entry.amount else 0
	local big = humanoid ~= nil and amount >= FX.BigHitFraction * humanoid.MaxHealth
	if entry.head == true then
		flash(FX.HeadFlashAlpha)
	elseif entry.crit == true or big then
		flash(FX.FlashAlpha)
	end
	local origin = attackerPosition(entry)
	if origin then
		showArc(origin)
	end
end

local function updateLow(humanoid: Humanoid)
	lowHealth = humanoid.Health > 0 and humanoid.Health / math.max(1, humanoid.MaxHealth) < FX.LowHealthFraction
end

-- Engancha el Humanoid del personaje para saber cuándo queda poca vida.
local function hook(character: Model)
	for _, connection in humanoidConnections do
		connection:Disconnect()
	end
	table.clear(humanoidConnections)
	lowHealth = false
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not (humanoid and humanoid:IsA("Humanoid")) then
		return
	end
	updateLow(humanoid)
	table.insert(
		humanoidConnections,
		humanoid.HealthChanged:Connect(function()
			updateLow(humanoid)
		end)
	)
	table.insert(
		humanoidConnections,
		humanoid.Died:Connect(function()
			lowHealth = false
		end)
	)
end

function DamageFxController:Start()
	local screenGui = Widgets.screen("DamageFx", player:WaitForChild("PlayerGui"))
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 5

	edge(screenGui, "Top", UDim2.fromScale(0, 0), UDim2.fromScale(1, EDGE_SIZE), Vector2.new(0, 0), 90)
	edge(screenGui, "Bottom", UDim2.fromScale(0, 1), UDim2.fromScale(1, EDGE_SIZE), Vector2.new(0, 1), 270)
	edge(screenGui, "Left", UDim2.fromScale(0, 0), UDim2.fromScale(EDGE_SIZE * 0.6, 1), Vector2.new(0, 0), 0)
	edge(screenGui, "Right", UDim2.fromScale(1, 0), UDim2.fromScale(EDGE_SIZE * 0.6, 1), Vector2.new(1, 0), 180)

	arcsFolder = Instance.new("Frame")
	arcsFolder.Name = "Arcs"
	arcsFolder.BackgroundTransparency = 1
	arcsFolder.Size = UDim2.fromScale(1, 1)
	arcsFolder.Active = false
	arcsFolder.Parent = screenGui

	player.CharacterAdded:Connect(hook)
	if player.Character then
		task.spawn(hook, player.Character)
	end

	Settings.onChanged(function(values)
		if not values.damageFx then
			reset()
		end
	end)

	Remotes.CombatText.OnClientEvent:Connect(function(batch: any)
		if typeof(batch) ~= "table" or not enabled() then
			return
		end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		for _, entry in batch do
			onEntry(entry, humanoid)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		if not enabled() then
			return
		end
		local now = os.clock()
		local flashLevel = flashPeak * math.max(0, 1 - (now - flashStart) / FX.FlashSeconds)
		-- El peso del pulso sube o baja en PulseFadeSeconds.
		local step = dt / FX.PulseFadeSeconds
		pulseWeight = if lowHealth then math.min(1, pulseWeight + step) else math.max(0, pulseWeight - step)
		local pulse = 0
		if pulseWeight > 0 then
			local wave = 0.5 + 0.5 * math.sin(now * 2 * math.pi / FX.PulseSeconds)
			pulse = pulseWeight * (FX.PulseMin + (FX.PulseMax - FX.PulseMin) * wave)
		end
		setIntensity(math.max(flashLevel, pulse))
	end)
end

return DamageFxController
