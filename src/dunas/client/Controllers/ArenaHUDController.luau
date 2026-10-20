--!strict
-- HUD de la arena de Dunas (estado en Shared/Arena):
--   - Arriba en el centro: marcador "🐆 0 · 8:00 · 0 🦜" con el color de cada equipo y, debajo, la
--     línea de la fase (elige equipo, cuenta atrás, muerte súbita, ganador).
--   - Arriba a la izquierda (12, 10): barras de vida y estamina, como las de la Isla. Debajo quedan
--     las casillas de habilidades (RoleHUD, en 12, 118).
--   - En el centro, solo mientras se espera para reaparecer: "Reapareces en 4".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local Stamina = require(ReplicatedStorage.CombatClient.Stamina)

local BAR_WIDTH = 170
local BAR_HEIGHT = 16
local ROW_HEIGHT = 24
local HEALTH_COLOR = Color3.fromRGB(230, 80, 80)
local STAMINA_COLOR = Color3.fromRGB(240, 220, 80)
local LOW_COLOR = Color3.fromRGB(235, 70, 60)
local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local SCORE_SIZE = Vector2.new(300, 44)

local ArenaHUDController = {}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function newBar(parent: Instance, order: number, icon: string, color: Color3): Frame
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
	corner(back, 6)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	corner(fill, 6)
	return fill
end

-- Casilla del marcador de un equipo: su color de fondo, icono y capturas.
local function scoreBox(parent: Instance, teamId: string, anchorX: number): TextLabel
	local team = Config.Arena.Teams[teamId]
	local box = Widgets.label("", parent)
	box.Name = teamId
	box.AnchorPoint = Vector2.new(anchorX, 0)
	box.Position = UDim2.fromScale(anchorX, 0)
	box.Size = UDim2.fromScale(0.32, 1)
	box.BackgroundColor3 = team.color
	box.BackgroundTransparency = 0.2
	box.TextStrokeTransparency = 0.3
	corner(box, 12)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = box
	return box
end

local function clock(seconds: number): string
	local whole = math.ceil(seconds)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Texto de la línea de la fase (debajo del marcador).
local function phaseText(player: Player): string
	local phase = Arena.phase()
	local left = Arena.secondsLeft()
	if phase == "Waiting" then
		if not Arena.teamOf(player) then
			return "Elige tu equipo"
		end
		return if left > 0 then `Esperando a los equipos · {clock(left)}` else "Esperando a los equipos"
	elseif phase == "Countdown" then
		return `⚔️ La batalla empieza en {math.ceil(left)}`
	elseif phase == "SuddenDeath" then
		return "⚡ ¡Muerte súbita! La siguiente captura gana"
	elseif phase == "Results" then
		local winner = ReplicatedStorage:GetAttribute("ArenaWinner")
		if Arena.isTeam(winner) then
			local team = Config.Arena.Teams[winner :: string]
			return `🏆 ¡Gana el equipo {team.icon} {team.name}!`
		end
		return "🤝 Empate"
	end
	return ""
end

function ArenaHUDController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("ArenaHUD", player:WaitForChild("PlayerGui"))

	-- Marcador y reloj.
	local score = Instance.new("Frame")
	score.Name = "Score"
	score.AnchorPoint = Vector2.new(0.5, 0)
	score.Position = UDim2.new(0.5, 0, 0, 10)
	score.Size = UDim2.fromOffset(SCORE_SIZE.X, SCORE_SIZE.Y)
	score.BackgroundColor3 = PANEL_COLOR
	score.BackgroundTransparency = 0.25
	score.Parent = gui
	corner(score, 14)
	local jaguar = scoreBox(score, "Jaguar", 0)
	local quetzal = scoreBox(score, "Quetzal", 1)
	local timer = Widgets.label("", score)
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(0.5, 0.5)
	timer.Position = UDim2.fromScale(0.5, 0.5)
	timer.Size = UDim2.fromScale(0.34, 0.7)

	local phaseLine = Widgets.label("", gui)
	phaseLine.Name = "Phase"
	phaseLine.AnchorPoint = Vector2.new(0.5, 0)
	phaseLine.Position = UDim2.new(0.5, 0, 0, 10 + SCORE_SIZE.Y + 6)
	phaseLine.Size = UDim2.fromOffset(420, 28)
	phaseLine.TextStrokeTransparency = 0.3

	-- Vida y estamina.
	local column = Instance.new("Frame")
	column.Name = "Bars"
	column.BackgroundTransparency = 1
	column.Position = UDim2.fromOffset(12, 10)
	column.Size = UDim2.fromOffset(BAR_WIDTH + 30, ROW_HEIGHT * 2 + 4)
	column.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = column
	local healthFill = newBar(column, 1, "❤️", HEALTH_COLOR)
	local staminaFill = newBar(column, 2, "⚡", STAMINA_COLOR)

	-- Cuenta atrás para reaparecer.
	local respawn = Widgets.label("", gui)
	respawn.Name = "Respawn"
	respawn.AnchorPoint = Vector2.new(0.5, 0.5)
	respawn.Position = UDim2.fromScale(0.5, 0.4)
	respawn.Size = UDim2.fromScale(0.5, 0.08)
	respawn.TextStrokeTransparency = 0.3
	local respawnLimit = Instance.new("UITextSizeConstraint")
	respawnLimit.MaxTextSize = 40
	respawnLimit.Parent = respawn

	RunService.RenderStepped:Connect(function()
		jaguar.Text = `{Config.Arena.Teams.Jaguar.icon} {Arena.score("Jaguar")}`
		quetzal.Text = `{Arena.score("Quetzal")} {Config.Arena.Teams.Quetzal.icon}`
		local phase = Arena.phase()
		timer.Text = if phase == "Battle" or phase == "Countdown"
			then clock(Arena.secondsLeft())
			elseif phase == "SuddenDeath" then "⚡"
			else "—"
		phaseLine.Text = phaseText(player)

		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		local health = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0
		local blinkOn = os.clock() % 1 < 0.5
		healthFill.Size = UDim2.fromScale(math.clamp(health, 0, 1), 1)
		healthFill.Visible = health > 0
		healthFill.BackgroundColor3 = if health <= 0.25 and blinkOn then LOW_COLOR else HEALTH_COLOR
		local stamina = Stamina.get() / Stamina.MAX
		staminaFill.Size = UDim2.fromScale(stamina, 1)
		staminaFill.Visible = stamina > 0

		local respawnAt = player:GetAttribute("RespawnAt")
		if typeof(respawnAt) == "number" then
			local left = math.max(0, respawnAt - Workspace:GetServerTimeNow())
			respawn.Text = `Reapareces en {math.ceil(left)}`
			respawn.Visible = true
		else
			respawn.Visible = false
		end
	end)
end

return ArenaHUDController
