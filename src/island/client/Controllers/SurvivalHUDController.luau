--!strict
-- Barras de supervivencia arriba a la izquierda (Fase 2.1): hambre, sed y estamina.
-- Parpadean en rojo cuando bajan de Config.Survival.LowThreshold.
-- Fase 2.6: barra de fiebre (solo si tienes) y vista nublada con fiebre alta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Survival = require(ReplicatedStorage.Shared.Survival)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local Stamina = require(ReplicatedStorage.CombatClient.Stamina)

local BAR_WIDTH = 170
local BAR_HEIGHT = 16
local ROW_HEIGHT = 24
local LOW_COLOR = Color3.fromRGB(235, 70, 60)

type Bar = { row: Frame, fill: Frame, color: Color3, read: () -> number, inverted: boolean? }

local SurvivalHUDController = {}

local function newBar(parent: Instance, order: number, icon: string, color: Color3, read: () -> number): Bar
	local row = Instance.new("Frame")
	row.Name = `Row{order}`
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(BAR_WIDTH + 30, ROW_HEIGHT)
	row.Parent = parent

	local label = Widgets.label(icon, row)
	label.Size = UDim2.fromOffset(24, ROW_HEIGHT)

	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0, 0.5)
	back.Position = UDim2.new(0, 30, 0.5, 0)
	back.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BackgroundTransparency = 0.35
	back.Parent = row
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = back

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = color
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	return { row = row, fill = fill, color = color, read = read }
end

function SurvivalHUDController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("SurvivalHUD", player:WaitForChild("PlayerGui"))

	local column = Instance.new("Frame")
	column.Name = "Bars"
	column.BackgroundTransparency = 1
	column.Position = UDim2.fromOffset(12, 10)
	column.Size = UDim2.fromOffset(BAR_WIDTH + 30, ROW_HEIGHT * 4 + 12)
	column.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = column

	local bars = {
		newBar(column, 1, "🍖", Color3.fromRGB(230, 150, 70), function()
			return Survival.get(player, Survival.HUNGER) / Survival.MAX
		end),
		newBar(column, 2, "💧", Color3.fromRGB(80, 170, 240), function()
			return Survival.get(player, Survival.THIRST) / Survival.MAX
		end),
		newBar(column, 3, "⚡", Color3.fromRGB(240, 220, 80), function()
			return Stamina.get() / Stamina.MAX
		end),
	}
	local feverBar = newBar(column, 4, "🤒", Color3.fromRGB(190, 90, 200), function()
		return Survival.fever(player) / Survival.MAX
	end)
	feverBar.inverted = true
	table.insert(bars, feverBar)

	-- Síntomas: nada por debajo de Config.Fever.SymptomsAt. Por encima, un tinte morado suave y
	-- oleadas cortas de vista borrosa, más seguidas y fuertes cuanto más fiebre. Entre oleadas se ve bien.
	local fever = Config.Fever
	local blur = Instance.new("BlurEffect")
	blur.Name = "FeverBlur"
	blur.Size = 0
	blur.Parent = Lighting
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "FeverTint"
	tint.Parent = Lighting
	local white = Color3.new(1, 1, 1)
	local feverColor = Color3.fromRGB(225, 200, 255)
	local waveStartedAt = -math.huge
	local nextWaveAt: number? = nil

	local low = Config.Survival.LowThreshold / Survival.MAX
	local feverAlarm = fever.SymptomsAt / Survival.MAX
	RunService.RenderStepped:Connect(function()
		-- Parpadeo: medio segundo encendido, medio apagado.
		local blinkOn = os.clock() % 1 < 0.5
		for _, bar in bars do
			local value = math.clamp(bar.read(), 0, 1)
			bar.fill.Size = UDim2.fromScale(value, 1)
			bar.fill.Visible = value > 0
			-- La fiebre es al revés: alarma con síntomas, y solo se ve si tienes.
			local alarm = if bar.inverted then value >= feverAlarm else value <= low
			bar.fill.BackgroundColor3 = if alarm and blinkOn then LOW_COLOR else bar.color
			if bar.inverted then
				bar.row.Visible = value > 0
			end
		end
		local value = Survival.fever(player)
		if value < fever.SymptomsAt then
			blur.Size = 0
			tint.TintColor = white
			tint.Saturation = 0
			nextWaveAt = nil
			return
		end
		local symptoms = math.clamp((value - fever.SymptomsAt) / (Survival.MAX - fever.SymptomsAt), 0, 1)
		local now = os.clock()
		-- La primera oleada llega al empezar los síntomas, para que se note el cambio.
		if not nextWaveAt or now >= nextWaveAt then
			waveStartedAt = now
			local every = fever.WaveEverySeconds
			nextWaveAt = now + every.atSymptoms + (every.atMax - every.atSymptoms) * symptoms
		end
		local progress = (now - waveStartedAt) / fever.WaveSeconds
		local wave = if progress < 1 then math.sin(progress * math.pi) else 0
		local peak = fever.WaveBlur.atSymptoms + (fever.WaveBlur.atMax - fever.WaveBlur.atSymptoms) * symptoms
		blur.Size = wave * peak
		tint.TintColor = white:Lerp(feverColor, 0.4 + 0.3 * symptoms + 0.3 * wave)
		tint.Saturation = -0.1 - 0.15 * symptoms
	end)
end

return SurvivalHUDController
