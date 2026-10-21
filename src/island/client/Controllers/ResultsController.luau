--!strict
-- Pantalla de resultados al terminar la partida (Fase 2.7): días sobrevividos, tus estadísticas,
-- el Ámbar ganado y un botón para volver ya al Lobby (si no, el servidor os envía a todos).
-- Al ganar con un huevo incubando en el nido del Lobby, una ruleta enseña su tirada del rescate
-- ("eggRoll" del resumen, MatchService): las horas que le quita o la eclosión inmediata. Con una
-- temporada en marcha, también la XP del pase sumada ("pass"). Y los pasos cumplidos del contrato de
-- expedición (Shared/Contract). Bajo los días, el grupo: una ficha por jugador con su nombre y su marco
-- (Shared/UI/PlayerFrames).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Contract = require(ReplicatedStorage.Shared.Contract)
local Contracts = require(ReplicatedStorage.Shared.Data.Contracts)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local PlayerFrames = require(ReplicatedStorage.Shared.UI.PlayerFrames)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

-- Cian del huevo (como su línea de estado en el HUD).
local EGG_COLOR = Color3.fromRGB(150, 240, 255)
-- Ruleta: cuántas veces cambia antes de pararse y cuánto se frena en cada cambio.
local ROULETTE_STEPS = 20
local ROULETTE_FIRST_DELAY = 0.05
local ROULETTE_SLOWDOWN = 1.17
-- Fichas del grupo: fondo de fila y alto (fracción de la ventana).
local CHIP_COLOR = Color3.fromRGB(45, 38, 30)
local TEAM_HEIGHT = 0.11

local ResultsController = {}

local function rollText(hatch: boolean, seconds: number): string
	return if hatch then "🐣 ¡Eclosión!" else `⏩ −{seconds // 3600} h`
end

-- La ruleta pasa por todos los premios posibles, se frena y se para en el que tocó. Luego dice qué
-- le ha pasado al huevo (con el tope de lo que se acelera jugando, puede ser menos de lo que salió).
local function playRoulette(wheel: TextLabel, detail: TextLabel, roll: { [string]: any })
	local options = {}
	for _, option in Config.Egg.RescueRoll do
		table.insert(options, rollText(option.hatch, option.hours * 3600))
	end
	local final = rollText(roll.hatch == true, tonumber(roll.rolledSeconds) or 0)
	local delay = ROULETTE_FIRST_DELAY
	for step = 1, ROULETTE_STEPS do
		wheel.Text = `🥚 Tirada del rescate: {options[step % #options + 1]}`
		task.wait(delay)
		delay *= ROULETTE_SLOWDOWN
	end
	wheel.Text = `🥚 Tirada del rescate: {final}`
	local scale = Instance.new("UIScale")
	scale.Scale = 1.35
	scale.Parent = wheel
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	local rarity = Rarities[roll.rarity]
	local name = if rarity then rarity.name else ""
	local applied = tonumber(roll.appliedSeconds) or 0
	if roll.hatch then
		detail.Text = `¡Tu huevo {name} está listo! Ábrelo en el nido del Lobby`
	elseif applied < (tonumber(roll.rolledSeconds) or 0) then
		detail.Text =
			`Tu huevo {name}: −{EggIncubation.formatTime(applied)} (llegó al tope de lo que se acelera jugando)`
	else
		detail.Text = `Tu huevo {name} del nido: −{EggIncubation.formatTime(applied)}`
	end
end

local function show(summary: { [string]: any })
	local player = Players.LocalPlayer
	local gui = Widgets.screen("Results", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = true

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(10, 8, 6)
	shade.BackgroundTransparency = 0.25
	shade.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	-- Con la tirada del huevo hay dos líneas más: la ventana crece y lo demás encoge un poco.
	local roll = if typeof(summary.eggRoll) == "table" then summary.eggRoll else nil
	local passText = SeasonPass.gainText(summary.pass)
	local contract = Contract.read()
	local panelHeight = (if roll then 0.86 else 0.7)
		+ TEAM_HEIGHT
		+ (if summary.newTitle then 0.07 else 0)
		+ (if passText then 0.07 else 0)
		+ (if contract then 0.07 else 0)
	local fit = 0.7 / panelHeight
	panel.Size = UDim2.fromScale(0.6, panelHeight)
	panel.BackgroundColor3 = Color3.fromRGB(30, 24, 18)
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(300, 280)
	sizeLimit.MaxSize = Vector2.new(560, 480 / fit)
	sizeLimit.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.02 * fit, 0)
	layout.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.05, 0)
	padding.Parent = panel

	local victory = summary.result == "Victory"
	type Line = { text: string, height: number, color: Color3 }
	local plain = Color3.fromRGB(230, 220, 200)
	local lines: { Line } = {
		{
			text = if victory then "🚁 ¡Rescatados!" else "💀 El Basecamp ha caído",
			height = 0.14,
			color = Color3.fromRGB(255, 210, 120),
		},
		{ text = `Sobrevivisteis {summary.days} día(s)`, height = 0.09, color = Color3.new(1, 1, 1) },
		{ text = `🐒 Monos derrotados: {summary.kills}`, height = 0.08, color = plain },
		{ text = `💚 Aliados reanimados: {summary.revives}`, height = 0.08, color = plain },
		{ text = `👻 Caídas: {summary.deaths}`, height = 0.08, color = plain },
		{ text = `👑 Jefes: {summary.bosses or 0}`, height = 0.08, color = plain },
		{ text = `✨ Ámbar ganado: {summary.amber}`, height = 0.1, color = Color3.fromRGB(255, 200, 80) },
	}
	if passText then
		table.insert(lines, { text = passText, height = 0.07, color = Color3.fromRGB(255, 150, 80) })
	end
	if contract then
		local definition = Contracts[contract.id]
		table.insert(lines, {
			text = `📜 Contrato «{definition.name}»: {Contract.doneCount(contract)}/{#definition.steps} pasos`,
			height = 0.07,
			color = Color3.fromRGB(255, 205, 70),
		})
	end
	if summary.newTitle then
		table.insert(lines, {
			text = "🏝️ ¡Nuevo título: Superviviente de la Isla! Póntelo en el Armario (Lobby)",
			height = 0.07,
			color = Color3.fromRGB(255, 160, 70),
		})
	end
	for index, line in lines do
		local label = Widgets.label(line.text, panel)
		-- De diez en diez: el grupo va entre los días (2) y los monos (3).
		label.LayoutOrder = index * 10
		label.Size = UDim2.fromScale(0.9, line.height * fit)
		label.TextColor3 = line.color
	end
	local team = Instance.new("Frame")
	team.LayoutOrder = 25
	team.BackgroundTransparency = 1
	team.Size = UDim2.fromScale(0.94, TEAM_HEIGHT * fit)
	team.Parent = panel
	local teamLayout = Instance.new("UIListLayout")
	teamLayout.FillDirection = Enum.FillDirection.Horizontal
	teamLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	teamLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	teamLayout.Padding = UDim.new(0, 8)
	teamLayout.Parent = team
	local members = Players:GetPlayers()
	local chipWidth = 1 / math.max(#members, 3)
	for index, member in members do
		local chip = Widgets.label(member.DisplayName, team)
		chip.LayoutOrder = if member == player then 0 else index
		chip.Size = UDim2.new(chipWidth, -8, 0.86, 0)
		chip.BackgroundColor3 = CHIP_COLOR
		chip.BackgroundTransparency = 0.1
		chip.TextColor3 = if member == player then Color3.fromRGB(242, 178, 36) else plain
		local chipCorner = Instance.new("UICorner")
		chipCorner.CornerRadius = UDim.new(0, 8)
		chipCorner.Parent = chip
		local chipPadding = Instance.new("UIPadding")
		chipPadding.PaddingLeft = UDim.new(0, 8)
		chipPadding.PaddingRight = UDim.new(0, 8)
		chipPadding.PaddingTop = UDim.new(0, 3)
		chipPadding.PaddingBottom = UDim.new(0, 3)
		chipPadding.Parent = chip
		local chipLimit = Instance.new("UITextSizeConstraint")
		chipLimit.MaxTextSize = 22
		chipLimit.Parent = chip
		local frameId = member:GetAttribute("Frame")
		PlayerFrames.apply(chip, if typeof(frameId) == "string" then frameId else nil)
	end
	local order = #lines * 10
	if roll then
		local wheel = Widgets.label("🥚 Tirada del rescate", panel)
		wheel.LayoutOrder = order + 1
		wheel.Size = UDim2.fromScale(0.9, 0.1 * fit)
		wheel.TextColor3 = EGG_COLOR
		local detail = Widgets.label("", panel)
		detail.LayoutOrder = order + 2
		detail.Size = UDim2.fromScale(0.9, 0.06 * fit)
		detail.TextColor3 = plain
		order += 2
		task.spawn(playRoulette, wheel, detail, roll)
	end

	local button = Widgets.button("Volver al Lobby", panel)
	button.LayoutOrder = order + 1
	button.Size = UDim2.fromScale(0.6, 0.13 * fit)
	button.MouseButton1Click:Connect(function()
		button.Text = "Viajando…"
		Remotes.RequestReturnToLobby:FireServer()
	end)

	local countdown = Widgets.label("", panel)
	countdown.LayoutOrder = order + 2
	countdown.Size = UDim2.fromScale(0.9, 0.06 * fit)
	countdown.TextColor3 = Color3.fromRGB(180, 170, 160)
	task.spawn(function()
		for remaining = Config.Match.ResultsSeconds, 0, -1 do
			countdown.Text = `Volvéis todos al Lobby en {remaining} s`
			task.wait(1)
		end
	end)
end

function ResultsController:Start()
	Remotes.MatchEnded.OnClientEvent:Connect(function(summary: any)
		if typeof(summary) == "table" then
			show(summary)
		end
	end)
end

return ResultsController
