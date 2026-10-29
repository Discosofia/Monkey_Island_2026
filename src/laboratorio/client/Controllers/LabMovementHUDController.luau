--!strict
-- Aviso de la tecla de deslizar del Laboratorio ("C · Deslizar") abajo a la izquierda, solo con teclado o
-- mando; en el móvil el botón de Correr ya dice "Deslizar" (LocomotionController). Las líneas de velocidad
-- (antes aquí) las dibuja CombatClient/SpeedLinesController en todos los places.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local Movement = require(ReplicatedStorage.CombatClient.Movement)

local T = Strings.t

local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
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

	RunService.RenderStepped:Connect(function()
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
	end)
end

return LabMovementHUDController
