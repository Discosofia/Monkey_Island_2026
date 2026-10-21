--!strict
-- Rastreador de las misiones en la Isla (bucle de retención, octubre de 2026; misiones v2 de la Fase 9):
--   - En PC: las 3 misiones del día con lo que llevas ("7/10") o ✅ y una línea con las semanales
--     cumplidas, debajo del panel de combos (ComboController), con su mismo estilo.
--   - En un teléfono (táctil sin teclado), la columna izquierda es la del joystick y la derecha la de
--     los botones de acción: va en la franja de la barra de Roblox (GuiService.TopbarInset, libre en la
--     Isla), tras sus botones, en fichas compactas: el icono de cada misión con lo que llevas y "📆 2/5".
-- Lee el atributo "Retention" (misiones del día y de la semana, ServerShared/Retention), que se apunta
-- cada pocos segundos mientras juegas.

local GuiService = game:GetService("GuiService")
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
local PANEL = Color3.fromRGB(25, 25, 25)
local LINE_HEIGHT = 18
local WIDTH = 5 * 66 - 6
-- Fichas de la franja de arriba en el teléfono: alto (según la franja) y separación.
local CHIP_MIN_HEIGHT = 24
local CHIP_MAX_HEIGHT = 34
local CHIP_GAP = 4

local MissionTrackerController = {}

type Shown = { daily: { Daily.DailyMission }, weeklyDone: number, weeklyTotal: number }

local function read(player: Player): Shown
	local raw = player:GetAttribute("Retention")
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
	end)
	local data = if ok and typeof(decoded) == "table" then decoded else {}
	local weekly = Daily.weeklyState(data.weekly)
	local done = 0
	for _, mission in weekly.missions do
		done += if mission.done then 1 else 0
	end
	return { daily = Daily.missionState(data.daily).missions, weeklyDone = done, weeklyTotal = #weekly.missions }
end

local function progressText(mission: Daily.DailyMission): string
	return if mission.done then "✅" else `{math.floor(mission.progress)}/{Missions[mission.id].target}`
end

-- PC: panel con una línea por misión del día y otra para las semanales.
local function buildPanel(player: Player): (Shown) -> ()
	local gui = Widgets.screen("MissionHUD", player:WaitForChild("PlayerGui"))

	-- Debajo del panel de combos (12, 170, 62 de alto).
	local panel = Instance.new("Frame")
	panel.Name = "Missions"
	panel.Position = UDim2.fromOffset(12, 240)
	panel.BackgroundColor3 = PANEL
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

	return function(shown: Shown)
		local missions = shown.daily
		local rows = #missions + (if shown.weeklyTotal > 0 then 1 else 0)
		panel.Visible = rows > 0
		panel.Size = UDim2.fromOffset(WIDTH, 22 + rows * LINE_HEIGHT)
		for index, line in lines do
			line.text.Visible = index <= rows
			line.count.Visible = index <= rows
		end
		for index, mission in missions do
			local line = lineAt(index)
			line.text.Text = Daily.missionText(mission.id)
			line.text.TextColor3 = if mission.done then DONE else TEXT
			line.count.Text = progressText(mission)
			line.count.TextColor3 = if mission.done then DONE else TEXT
		end
		if shown.weeklyTotal > 0 then
			local line = lineAt(#missions + 1)
			local all = shown.weeklyDone >= shown.weeklyTotal
			line.text.Text = "📆 Semanales cumplidas"
			line.text.TextColor3 = if all then DONE else GOLD
			line.count.Text = if all then "✅" else `{shown.weeklyDone}/{shown.weeklyTotal}`
			line.count.TextColor3 = if all then DONE else GOLD
		end
	end
end

-- Teléfono: fichas en la franja de la barra de Roblox, tras sus botones.
local function buildBand(player: Player): (Shown) -> ()
	local gui = Widgets.screen("MissionBand", player:WaitForChild("PlayerGui"))
	gui.IgnoreGuiInset = true

	local strip = Instance.new("Frame")
	strip.Name = "Missions"
	strip.BackgroundTransparency = 1
	strip.AutomaticSize = Enum.AutomaticSize.X
	strip.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, CHIP_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip

	local chipHeight = CHIP_MAX_HEIGHT
	local function place()
		local inset = GuiService.TopbarInset
		local band = if inset.Height > 0 then inset.Height else 44
		chipHeight = math.clamp(band - 12, CHIP_MIN_HEIGHT, CHIP_MAX_HEIGHT)
		strip.Position = UDim2.fromOffset(inset.Min.X + 8, inset.Min.Y + (band - chipHeight) / 2)
		strip.Size = UDim2.fromOffset(0, chipHeight)
		for _, chip in strip:GetChildren() do
			if chip:IsA("TextLabel") then
				chip.Size = UDim2.fromOffset(0, chipHeight)
				chip.TextSize = math.max(13, chipHeight - 14)
			end
		end
	end
	place()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)

	local chips: { TextLabel } = {}
	local function chipAt(index: number): TextLabel
		local existing = chips[index]
		if existing then
			return existing
		end
		local chip = Widgets.label("", strip)
		chip.LayoutOrder = index
		chip.TextScaled = false
		chip.TextSize = math.max(13, chipHeight - 14)
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(0, chipHeight)
		chip.BackgroundColor3 = PANEL
		chip.BackgroundTransparency = 0.4
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = chip
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.Parent = chip
		chips[index] = chip
		return chip
	end

	return function(shown: Shown)
		local count = #shown.daily + (if shown.weeklyTotal > 0 then 1 else 0)
		for index, chip in chips do
			chip.Visible = index <= count
		end
		for index, mission in shown.daily do
			local chip = chipAt(index)
			chip.Text = `{Missions[mission.id].icon} {progressText(mission)}`
			chip.TextColor3 = if mission.done then DONE else TEXT
		end
		if shown.weeklyTotal > 0 then
			local chip = chipAt(#shown.daily + 1)
			local all = shown.weeklyDone >= shown.weeklyTotal
			chip.Text = if all then "📆 ✅" else `📆 {shown.weeklyDone}/{shown.weeklyTotal}`
			chip.TextColor3 = if all then DONE else GOLD
		end
	end
end

function MissionTrackerController:Start()
	local player = Players.LocalPlayer
	local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local show = if phone then buildBand(player) else buildPanel(player)
	local function refresh()
		show(read(player))
	end
	player:GetAttributeChangedSignal("Retention"):Connect(refresh)
	refresh()
end

return MissionTrackerController
