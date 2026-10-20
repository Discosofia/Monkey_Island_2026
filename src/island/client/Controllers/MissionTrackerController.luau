--!strict
-- Rastreador de las misiones del día en la Isla (bucle de retención, octubre de 2026): las 3 misiones
-- con lo que llevas ("7/15") o ✅, debajo del panel de combos (ComboController), con su mismo estilo.
-- Solo en pantallas sin táctil: en un teléfono la columna izquierda es la del joystick y la derecha la
-- de los botones de acción. Allí basta el aviso al cumplir cada una y la pestaña Misiones del Lobby.
-- Lee el atributo "Retention" (misiones del día, ServerShared/Retention), que se apunta cada pocos
-- segundos mientras juegas.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Daily = require(ReplicatedStorage.Shared.Daily)
local Missions = require(ReplicatedStorage.Shared.Data.Missions)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local GOLD = Color3.fromRGB(255, 205, 70)
local DONE = Color3.fromRGB(120, 230, 140)
local TEXT = Color3.fromRGB(230, 220, 200)
local LINE_HEIGHT = 18
local WIDTH = 5 * 66 - 6

local MissionTrackerController = {}

function MissionTrackerController:Start()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return
	end
	local player = Players.LocalPlayer
	local gui = Widgets.screen("MissionHUD", player:WaitForChild("PlayerGui"))

	-- Debajo del panel de combos (12, 170, 62 de alto).
	local panel = Instance.new("Frame")
	panel.Name = "Missions"
	panel.Position = UDim2.fromOffset(12, 240)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	panel.BackgroundTransparency = 0.4
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local title = Widgets.label("🎯 Misiones del día", panel)
	title.Position = UDim2.fromOffset(6, 2)
	title.Size = UDim2.new(1, -12, 0, 16)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = GOLD

	type Line = { text: TextLabel, count: TextLabel }
	local lines: { Line } = {}
	local function lineAt(index: number): Line
		local existing = lines[index]
		if existing then
			return existing
		end
		local y = 20 + (index - 1) * LINE_HEIGHT
		local text = Widgets.label("", panel)
		text.Position = UDim2.fromOffset(6, y)
		text.Size = UDim2.new(1, -82, 0, LINE_HEIGHT - 2)
		text.TextXAlignment = Enum.TextXAlignment.Left
		local count = Widgets.label("", panel)
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -6, 0, y)
		count.Size = UDim2.fromOffset(72, LINE_HEIGHT - 2)
		count.TextXAlignment = Enum.TextXAlignment.Right
		local line = { text = text, count = count }
		lines[index] = line
		return line
	end

	local function refresh()
		local raw = player:GetAttribute("Retention")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
		end)
		local state = Daily.missionState(if ok and typeof(decoded) == "table" then decoded.daily else nil)
		local missions = state.missions
		panel.Visible = #missions > 0
		panel.Size = UDim2.fromOffset(WIDTH, 22 + #missions * LINE_HEIGHT)
		for index, line in lines do
			line.text.Visible = index <= #missions
			line.count.Visible = index <= #missions
		end
		for index, mission in missions do
			local definition = Missions[mission.id]
			local line = lineAt(index)
			line.text.Text = Daily.missionText(mission.id)
			line.text.TextColor3 = if mission.done then DONE else TEXT
			line.count.Text = if mission.done then "✅" else `{math.floor(mission.progress)}/{definition.target}`
			line.count.TextColor3 = if mission.done then DONE else TEXT
		end
	end
	player:GetAttributeChangedSignal("Retention"):Connect(refresh)
	refresh()
end

return MissionTrackerController
