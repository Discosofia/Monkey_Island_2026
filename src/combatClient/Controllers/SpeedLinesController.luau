--!strict
-- Líneas blancas de velocidad (Fase 18 L2 en el Laboratorio; Fase 19 W1 en los 4 places): finas y radiales,
-- hacia los bordes, que se recolocan a ratos. Suben con la esquiva (DodgeFeel.active: el empuje y su
-- arrastre), el deslizamiento (Slide.active, todo el rato) y correr rápido, y se apagan solas. Las escala el
-- ajuste "speedLines" (Config.Movement.SpeedLines.Scale; apagado = sin líneas), no el temblor de la cámara.
-- Sustituyen a la estela, que uno no ve en primera persona (AbilityFxController).
-- Los valores están en Config.Movement.SpeedLines.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local DodgeFeel = require(ReplicatedStorage.CombatClient.DodgeFeel)
local Slide = require(ReplicatedStorage.CombatClient.Slide)

local LINE_COLOR = Color3.new(1, 1, 1)
-- Largo de cada línea (px) y zona donde caen, como fracción de la mitad de la diagonal desde el centro.
local LINE_MIN_LENGTH = 70
local LINE_MAX_LENGTH = 170
local LINE_MIN_RADIUS = 0.42
local LINE_MAX_RADIUS = 0.95
-- Por debajo de esta intensidad no se dibuja nada.
local MIN_INTENSITY = 0.02
-- Alto de pantalla en el que el grosor y el largo valen lo escrito (px).
local REFERENCE_HEIGHT = 720

local SpeedLinesController = {}

function SpeedLinesController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local settings = Config.Movement.SpeedLines

	-- Por debajo del HUD y sin el margen de arriba de Roblox.
	local linesGui = Widgets.screen("SpeedLines", playerGui)
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
		local unit = math.max(size.Y, 1) / REFERENCE_HEIGHT
		local thickness = math.max(1, math.round(settings.ThicknessPx * unit))
		for _, line in lines do
			local angle = random:NextNumber(0, math.pi * 2)
			local direction = Vector2.new(math.cos(angle), math.sin(angle))
			local distance = half * random:NextNumber(LINE_MIN_RADIUS, LINE_MAX_RADIUS)
			local center = size / 2 + direction * distance
			line.Position = UDim2.fromOffset(center.X, center.Y)
			line.Size = UDim2.fromOffset(random:NextNumber(LINE_MIN_LENGTH, LINE_MAX_LENGTH) * unit, thickness)
			line.Rotation = math.deg(angle)
		end
	end

	local intensity = 0
	local sinceShuffle = math.huge
	RunService.RenderStepped:Connect(function(deltaTime)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local alive = humanoid ~= nil and humanoid.Health > 0 and root ~= nil and root:IsA("BasePart")

		-- Intensidad que piden la esquiva, el deslizamiento y correr rápido.
		local target = 0
		if alive then
			if DodgeFeel.active() then
				target = settings.DodgeStrength
			end
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
		target *= DodgeFeel.speedScale()
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
		local transparency = 1 - settings.Opacity * intensity
		for _, line in lines do
			line.Visible = visible
			line.BackgroundTransparency = transparency
		end
	end)
end

return SpeedLinesController
