--!strict
-- Indicador de combos y racha (Data/Combos, ComboService):
--   - Bajo las casillas de las habilidades: el nombre del combo en marcha (cada rol tiene dos), sus 3
--     pasos (los hechos se rellenan y el siguiente brilla; si lo abrió una conexión, el paso 1 lleva
--     "🔗"), una barra con el tiempo que queda para enlazar y la racha (x2…x5) con su barra de tiempo.
--   - "¡COMBO!" grande en el centro al cerrarlo, o "¡CONEXIÓN!" si se cerró tras otro combo.
-- Lee los atributos del jugador "ComboIndex", "ComboStep", "ComboStepUntil", "ComboConnected",
-- "ComboChain", "ComboStreak" y "ComboStreakUntil". Se oculta con el ajuste "Combos" (Shared/Settings).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Combos = require(ReplicatedStorage.Shared.Data.Combos)
local Config = require(ReplicatedStorage.Shared.Config)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local GOLD = Color3.fromRGB(255, 205, 70)
local NEXT = Color3.fromRGB(120, 230, 255)
local DONE_COLOR = Color3.fromRGB(242, 178, 36)
local IDLE_COLOR = Color3.fromRGB(45, 45, 45)

local ComboController = {}

type Pill = { frame: Frame, label: TextLabel, stroke: UIStroke }

local function number(player: Player, attribute: string): number
	local value = player:GetAttribute(attribute)
	return if typeof(value) == "number" then value else 0
end

-- Nombre corto (el del botón) de una habilidad del rol.
local function shortName(roleId: string, abilityId: string): string
	for _, ability in Roles[roleId].abilities do
		if ability.id == abilityId then
			return ability.short
		end
	end
	return abilityId
end

-- El combo en marcha del jugador (o el último que tuvo), o nil.
local function currentCombo(player: Player): Combos.Combo?
	local roleId = player:GetAttribute("Role")
	local combos = if typeof(roleId) == "string" then Combos[roleId] else nil
	if not combos then
		return nil
	end
	return combos[number(player, "ComboIndex")] or combos[1]
end

-- El siguiente paso del combo del jugador (id de la habilidad), o nil si no hay combo en marcha.
function ComboController.nextStep(player: Player): string?
	local combo = currentCombo(player)
	local step = number(player, "ComboStep")
	if not combo or step <= 0 or step >= #combo.steps then
		return nil
	end
	if Workspace:GetServerTimeNow() >= number(player, "ComboStepUntil") then
		return nil
	end
	return combo.steps[step + 1]
end

local function bar(parent: Instance, position: UDim2, color: Color3): Frame
	local back = Instance.new("Frame")
	back.Position = position
	back.Size = UDim2.new(1, -12, 0, 4)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	return fill
end

function ComboController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("ComboHUD", player:WaitForChild("PlayerGui"))

	-- Debajo de las casillas de las habilidades (RoleController).
	local panel = Instance.new("Frame")
	panel.Name = "Combo"
	panel.Position = UDim2.fromOffset(12, 170)
	panel.Size = UDim2.fromOffset(5 * 66 - 6, 62)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	panel.BackgroundTransparency = 0.4
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local title = Widgets.label("", panel)
	title.Position = UDim2.fromOffset(6, 2)
	title.Size = UDim2.new(1, -60, 0, 16)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = GOLD

	local streakLabel = Widgets.label("", panel)
	streakLabel.AnchorPoint = Vector2.new(1, 0)
	streakLabel.Position = UDim2.new(1, -6, 0, 1)
	streakLabel.Size = UDim2.fromOffset(54, 18)
	streakLabel.TextXAlignment = Enum.TextXAlignment.Right
	streakLabel.TextColor3 = GOLD

	local pills: { Pill } = {}
	for index = 1, 3 do
		local frame = Instance.new("Frame")
		frame.Position = UDim2.new((index - 1) / 3, 6, 0, 20)
		frame.Size = UDim2.new(1 / 3, -8, 0, 24)
		frame.BackgroundColor3 = IDLE_COLOR
		frame.Parent = panel
		local pillCorner = Instance.new("UICorner")
		pillCorner.CornerRadius = UDim.new(0, 6)
		pillCorner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = NEXT
		stroke.Transparency = 1
		stroke.Parent = frame
		local label = Widgets.label("", frame)
		label.Size = UDim2.new(1, -4, 1, -4)
		label.Position = UDim2.fromOffset(2, 2)
		table.insert(pills, { frame = frame, label = label, stroke = stroke })
	end
	local stepFill = bar(panel, UDim2.fromOffset(6, 48), NEXT)
	local streakFill = bar(panel, UDim2.fromOffset(6, 55), GOLD)

	-- "¡COMBO!" en el centro.
	local pop = Widgets.label("", gui)
	pop.Name = "ComboPop"
	pop.AnchorPoint = Vector2.new(0.5, 0.5)
	pop.Position = UDim2.fromScale(0.5, 0.3)
	pop.Size = UDim2.fromScale(0.5, 0.09)
	pop.TextColor3 = GOLD
	pop.TextTransparency = 1
	pop.TextStrokeTransparency = 1
	local popScale = Instance.new("UIScale")
	popScale.Parent = pop

	-- "chain": combos seguidos cerrados por conexiones (0 si este se empezó a mano).
	local function showPop(streak: number, chain: number)
		local headline = if chain >= 1 then `¡CONEXIÓN! {chain + 1} seguidos` else "¡COMBO!"
		pop.Text = if streak >= 2 then `{headline} · racha x{streak}` else headline
		pop.TextTransparency = 0
		pop.TextStrokeTransparency = 0.3
		popScale.Scale = 1.8
		TweenService:Create(popScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.9)
		TweenService:Create(pop, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end

	local lastStep = 0
	player:GetAttributeChangedSignal("ComboStep"):Connect(function()
		local step = number(player, "ComboStep")
		local combo = currentCombo(player)
		if combo and step >= #combo.steps and lastStep < step and Settings.get().showCombo then
			showPop(number(player, "ComboStreak"), number(player, "ComboChain"))
		end
		lastStep = step
	end)

	RunService.RenderStepped:Connect(function()
		local roleId = player:GetAttribute("Role")
		local combo = currentCombo(player)
		if not (combo and Settings.get().showCombo) then
			panel.Visible = false
			return
		end
		local now = Workspace:GetServerTimeNow()
		local stepUntil = number(player, "ComboStepUntil")
		local step = if now < stepUntil then number(player, "ComboStep") else 0
		local streakUntil = number(player, "ComboStreakUntil")
		local streak = if now < streakUntil then number(player, "ComboStreak") else 0
		panel.Visible = step > 0 or streak > 0

		title.Text = if step > 0 and step < #combo.steps then `{combo.name} {step}/{#combo.steps}` else combo.name
		streakLabel.Text = if streak > 0 then `x{streak}` else ""
		local connected = player:GetAttribute("ComboConnected") == true
		for index, pill in pills do
			local done = index <= step
			local isNext = index == step + 1 and step > 0 and step < #combo.steps
			local name = shortName(roleId :: string, combo.steps[index])
			-- El paso 1 que se ha saltado la conexión.
			pill.label.Text = if index == 1 and connected and step > 0 then `🔗 {name}` else name
			pill.frame.BackgroundColor3 = if done then DONE_COLOR else IDLE_COLOR
			pill.label.TextColor3 = if done then Color3.fromRGB(40, 25, 5) else Color3.new(1, 1, 1)
			-- El siguiente paso parpadea suave.
			pill.stroke.Transparency = if isNext then 0.2 + 0.5 * (0.5 + 0.5 * math.sin(now * 8)) else 1
		end
		local window = Config.Combo.StepWindowSeconds
		stepFill.Size = UDim2.fromScale(
			if step > 0 and step < #combo.steps then math.clamp((stepUntil - now) / window, 0, 1) else 0,
			1
		)
		streakFill.Size = UDim2.fromScale(
			if streak > 0 then math.clamp((streakUntil - now) / Config.Combo.StreakSeconds, 0, 1) else 0,
			1
		)
	end)
end

return ComboController
