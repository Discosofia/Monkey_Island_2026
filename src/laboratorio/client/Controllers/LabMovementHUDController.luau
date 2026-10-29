--!strict
-- Movimiento del Laboratorio en pantalla (Fase 18, L2):
--   - Líneas blancas de movimiento: finas y radiales, hacia los bordes, que se recolocan a ratos. Suben con
--     la esquiva (DodgeFeel.intensity), el deslizamiento (Slide.active) y correr rápido, y se apagan solas.
--     Las escala el ajuste "cameraShake" (apagado = sin líneas). Sustituyen a la estela, que uno no ve en
--     primera persona (AbilityFxController).
--   - Aviso de la tecla de deslizar ("C · Deslizar") abajo a la izquierda, solo con teclado o mando; en el móvil
--     el botón de Correr ya dice "Deslizar" (LocomotionController).
-- Los valores están en Config.Movement.SpeedLines.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local CameraShake = require(ReplicatedStorage.CombatClient.CameraShake)
local DodgeFeel = require(ReplicatedStorage.CombatClient.DodgeFeel)
local Movement = require(ReplicatedStorage.CombatClient.Movement)
local Slide = require(ReplicatedStorage.CombatClient.Slide)

local T = Strings.t

local LINE_COLOR = Color3.new(1, 1, 1)
local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local LINE_THICKNESS = 2
-- Largo de cada línea (px) y zona donde caen, como fracción de la mitad de la diagonal desde el centro.
local LINE_MIN_LENGTH = 70
local LINE_MAX_LENGTH = 170
local LINE_MIN_RADIUS = 0.42
local LINE_MAX_RADIUS = 0.95
-- Por debajo de esta intensidad no se dibuja nada.
local MIN_INTENSITY = 0.02
local HINT_SIZE = Vector2.new(130, 30)
local MARGIN = 12

local LabMovementHUDController = {}

local function keyLabel(keyName: string): string
	if #keyName == 1 then
		return keyName
	end
	return (keyName:gsub("(%l)(%u)", "%1 %2"))
end

function LabMovementHUDController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local settings = Config.Movement.SpeedLines

	-- Líneas de movimiento.
	local linesGui = Widgets.screen("LabSpeedLines", playerGui)
	linesGui.IgnoreGuiInset = true
	linesGui.DisplayOrder = -1
	local lines: { Frame } = {}
	for index = 1, settings.Count do
		local line = Instance.new("Frame")
		line.Name = `Line{index}`
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = LINE_COLOR
		line.BorderSizePixel = 0
		line.Visible = false
		line.Parent = linesGui
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = line
		lines[index] = line
	end

	local random = Random.new()
	local function shuffle()
		local size = linesGui.AbsoluteSize
		local half = size.Magnitude / 2
		for _, line in lines do
			local angle = random:NextNumber(0, math.pi * 2)
			local direction = Vector2.new(math.cos(angle), math.sin(angle))
			local distance = half * random:NextNumber(LINE_MIN_RADIUS, LINE_MAX_RADIUS)
			local center = size / 2 + direction * distance
			line.Position = UDim2.fromOffset(center.X, center.Y)
			line.Size = UDim2.fromOffset(random:NextNumber(LINE_MIN_LENGTH, LINE_MAX_LENGTH), LINE_THICKNESS)
			line.Rotation = math.deg(angle)
		end
	end

	-- Aviso de la tecla.
	local hudGui = Widgets.screen("LabMovementHint", playerGui)
	local hint = Instance.new("Frame")
	hint.Name = "SlideHint"
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, MARGIN, 1, -MARGIN)
	hint.Size = UDim2.fromOffset(HINT_SIZE.X, HINT_SIZE.Y)
	hint.BackgroundColor3 = PANEL_COLOR
	hint.BackgroundTransparency = 0.35
	hint.Visible = false
	hint.Parent = hudGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = hint
	local hintText = Widgets.label("", hint)
	hintText.Size = UDim2.fromScale(1, 1)
	hintText.TextStrokeTransparency = 0.3
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = hintText
	local hintKey = ""

	local intensity = 0
	local sinceShuffle = math.huge
	RunService.RenderStepped:Connect(function(deltaTime)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local alive = humanoid ~= nil and humanoid.Health > 0 and root ~= nil and root:IsA("BasePart")
		local rules = Movement.rules()

		-- Aviso de la tecla: con teclado o mando, no en un móvil sin ratón.
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		hint.Visible = alive and rules.slide and not touchOnly
		if hint.Visible and rules.slideKey ~= hintKey then
			hintKey = rules.slideKey
			hintText.Text = T("{key} · Deslizar", { key = keyLabel(hintKey) })
		end

		-- Intensidad que piden la esquiva, el deslizamiento y correr rápido.
		local target = 0
		if alive then
			target = DodgeFeel.intensity() * settings.DodgeStrength
			if Slide.active() then
				target = math.max(target, settings.SlideStrength)
			end
			if root and humanoid then
				local velocity = (root :: BasePart).AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if speed >= settings.SprintMinSpeed and humanoid.FloorMaterial ~= Enum.Material.Air then
					target = math.max(target, settings.SprintStrength)
				end
			end
		end
		target *= math.min(CameraShake.scale(), 1)
		-- Sube y baja en FadeSeconds.
		local step = deltaTime / math.max(settings.FadeSeconds, 0.01)
		intensity = if target > intensity
			then math.min(target, intensity + step)
			else math.max(target, intensity - step)

		local visible = intensity > MIN_INTENSITY
		sinceShuffle += deltaTime
		if visible and sinceShuffle >= settings.ShuffleSeconds then
			sinceShuffle = 0
			shuffle()
		end
		for _, line in lines do
			line.Visible = visible
			line.BackgroundTransparency = 1 - intensity * 0.85
		end
	end)
end

return LabMovementHUDController
