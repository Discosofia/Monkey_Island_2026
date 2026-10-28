--!strict
-- Barra de vida del jefe (Fase 5): arriba, cuando hay un jefe a menos de 220 studs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local T = Strings.t

local SHOW_DISTANCE = 220

local BossHUDController = {}

function BossHUDController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("BossHUD", player:WaitForChild("PlayerGui"))

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.175)
	frame.Size = UDim2.fromScale(0.42, 0.06)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui

	local title = Widgets.label("", frame)
	title.Size = UDim2.fromScale(1, 0.5)
	title.TextColor3 = Color3.fromRGB(255, 200, 120)

	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0, 0.55)
	back.Size = UDim2.fromScale(1, 0.4)
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 20)
	back.Parent = frame
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(220, 50, 40)
	fill.BorderSizePixel = 0
	fill.Parent = back

	while true do
		local name = ReplicatedStorage:GetAttribute("BossName")
		local health = ReplicatedStorage:GetAttribute("BossHealth")
		local maxHealth = ReplicatedStorage:GetAttribute("BossMaxHealth")
		local phase = ReplicatedStorage:GetAttribute("BossPhase")
		local position = ReplicatedStorage:GetAttribute("BossPosition")
		local character = player.Character
		local near = character ~= nil
			and typeof(position) == "Vector3"
			and (character:GetPivot().Position - position).Magnitude <= SHOW_DISTANCE
		local valid = typeof(name) == "string" and typeof(health) == "number" and typeof(maxHealth) == "number"
		frame.Visible = valid and near
		if valid and near then
			-- El nombre es el de Data (un jefe) o una frase de Strings.pack (el gigante del administrador).
			title.Text =
				T("👑 {name} · fase {phase}/3", { name = Strings.unpack(name :: string), phase = phase or 1 })
			fill.Size = UDim2.fromScale(math.clamp((health :: number) / (maxHealth :: number), 0, 1), 1)
		end
		task.wait(0.25)
	end
end

return BossHUDController
