--!strict
-- HUD de la arena de Dunas (estado en Shared/Arena):
--   - Arriba a la derecha, dentro de la franja de la barra de Roblox (GuiService.TopbarInset: el hueco
--     que deja a los juegos, que en el móvil es más bajo): marcador "🐆 0 · 8:00 · 0 🦜" con el color
--     de cada equipo y, bajo cada casilla, dónde está la bandera de ese equipo (🏠 en casa, 🏃 robada,
--     ⏳ segundos para volver sola).
--   - Arriba en el centro, justo bajo la barra: la línea de la fase (elige equipo, cuenta atrás,
--     llevas la bandera, os la han robado, muerte súbita, ganador) y, debajo, durante la partida, la del
--     altar de la pirámide (Fase 10, C11; AltarService): cuándo se enciende, quién lo está tomando o si
--     está disputado, y el equipo que tiene su ventaja (✨ V ×2) con los segundos que le quedan. En el
--     centro y no bajo el marcador: ahí lo tapa la lista de jugadores de Roblox.
--   - Arriba a la izquierda (12, 10): barras de vida y estamina (con la guardia a su derecha,
--     CombatClient/GuardBar, y el Evasivo detrás, CombatClient/EvasiveIcon), como las de la Isla. Debajo quedan
--     las casillas de habilidades (RoleHUD, en 12, 118).
--   - En el centro, solo mientras se espera para reaparecer: "Reapareces en 4".

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local EvasiveIcon = require(ReplicatedStorage.CombatClient.EvasiveIcon)
local GuardBar = require(ReplicatedStorage.CombatClient.GuardBar)
local Stamina = require(ReplicatedStorage.CombatClient.Stamina)

local BAR_WIDTH = 170
local BAR_HEIGHT = 16
local ROW_HEIGHT = 24
local HEALTH_COLOR = Color3.fromRGB(230, 80, 80)
local STAMINA_COLOR = Color3.fromRGB(240, 220, 80)
local LOW_COLOR = Color3.fromRGB(235, 70, 60)
local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local SCORE_SIZE = Vector2.new(300, 44)
-- El marcador no baja de esto aunque la barra de Roblox sea más baja (móvil).
local SCORE_MIN_HEIGHT = 32
local FLAG_ROW_HEIGHT = 20
local ALTAR_ROW_HEIGHT = 22
local ALTAR_COLOR = Color3.fromRGB(255, 205, 90)
-- Línea de la fase, justo bajo la barra de Roblox. ArenaLobbyController cuelga su ventana debajo
-- (a 6 + 28 + 6 = 40 px).
local PHASE_TOP = 6

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

local function flagState(teamId: string): string
	local state = ReplicatedStorage:GetAttribute(`ArenaFlag_{teamId}`)
	return if typeof(state) == "string" then state else "Home"
end

-- Dónde está la bandera de "teamId", en corto (cabe bajo su casilla del marcador).
local function flagText(teamId: string): string
	local state = flagState(teamId)
	if state == "Carried" then
		return "🏃 ¡Robada!"
	elseif state == "Dropped" then
		local returnAt = ReplicatedStorage:GetAttribute(`ArenaFlagReturnAt_{teamId}`)
		local left = if typeof(returnAt) == "number" then returnAt - Workspace:GetServerTimeNow() else 0
		return `⏳ En el suelo {math.max(0, math.ceil(left))}`
	end
	return "🏠 En casa"
end

-- El altar de la pirámide y su ventaja, en corto (cabe bajo el marcador).
local function altarText(): string
	local now = Workspace:GetServerTimeNow()
	local parts = {}
	local state = ReplicatedStorage:GetAttribute("AltarState")
	local owner = ReplicatedStorage:GetAttribute("AltarTeam")
	if state == "Dormant" then
		local readyAt = ReplicatedStorage:GetAttribute("AltarReadyAt")
		local left = if typeof(readyAt) == "number" then readyAt - now else 0
		table.insert(parts, `⛩️ Altar en {clock(math.max(0, left))}`)
	elseif state == "Active" then
		if ReplicatedStorage:GetAttribute("AltarContested") == true then
			table.insert(parts, "⛩️ ⚔️ Altar disputado")
		elseif Arena.isTeam(owner) then
			local progress = ReplicatedStorage:GetAttribute("AltarProgress")
			local percent = if typeof(progress) == "number" then math.floor(progress * 100) else 0
			table.insert(parts, `⛩️ {Config.Arena.Teams[owner].icon} toma el altar {percent} %`)
		else
			table.insert(parts, "⛩️ ¡Altar encendido!")
		end
	end
	local buffTeam = ReplicatedStorage:GetAttribute("AltarBuffTeam")
	local buffUntil = ReplicatedStorage:GetAttribute("AltarBuffUntil")
	if Arena.isTeam(buffTeam) and typeof(buffUntil) == "number" and buffUntil > now then
		table.insert(parts, `✨ {Config.Arena.Teams[buffTeam].icon} V ×2 {math.ceil(buffUntil - now)}`)
	end
	return table.concat(parts, " · ")
end

-- Texto de la línea de la fase (debajo del marcador).
local function phaseText(player: Player): string
	local phase = Arena.phase()
	local left = Arena.secondsLeft()
	local myTeam = Arena.teamOf(player)
	if Arena.inBattle() then
		if player:GetAttribute("CarryingFlag") ~= nil then
			return "🚩 ¡Llevas la bandera! Llévala a tu pedestal"
		elseif myTeam and flagState(myTeam) == "Carried" then
			return "⚠️ ¡Os han robado la bandera! Recuperadla"
		end
	end
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
	-- El marcador va en la barra de Roblox: en una pantalla que no la descuenta.
	local topGui = Widgets.screen("ArenaScore", player:WaitForChild("PlayerGui"))
	topGui.IgnoreGuiInset = true

	-- Marcador y reloj.
	local score = Instance.new("Frame")
	score.Name = "Score"
	score.AnchorPoint = Vector2.new(1, 0)
	score.BackgroundColor3 = PANEL_COLOR
	score.BackgroundTransparency = 0.25
	score.Parent = topGui
	corner(score, 14)
	-- En la franja de la barra de Roblox, pegado a su borde derecho y centrado en su alto.
	local function placeScore()
		local inset = GuiService.TopbarInset
		local height = math.clamp(inset.Height - 8, SCORE_MIN_HEIGHT, SCORE_SIZE.Y)
		local right = if inset.Width > 0 then inset.Max.X else topGui.AbsoluteSize.X
		score.Size = UDim2.fromOffset(SCORE_SIZE.X * height / SCORE_SIZE.Y, height)
		score.Position = UDim2.fromOffset(right - 12, inset.Min.Y + math.max(4, (inset.Height - height) / 2))
	end
	placeScore()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeScore)
	topGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeScore)
	local jaguar = scoreBox(score, "Jaguar", 0)
	local quetzal = scoreBox(score, "Quetzal", 1)
	local timer = Widgets.label("", score)
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(0.5, 0.5)
	timer.Position = UDim2.fromScale(0.5, 0.5)
	timer.Size = UDim2.fromScale(0.34, 0.7)

	-- Estado de cada bandera, bajo su casilla del marcador.
	local flagLabels: { [string]: TextLabel } = {}
	for _, teamId in Arena.TEAM_IDS do
		local anchorX = if teamId == "Jaguar" then 0 else 1
		local label = Widgets.label("", score)
		label.Name = `Flag{teamId}`
		label.AnchorPoint = Vector2.new(anchorX, 0)
		label.Position = UDim2.new(anchorX, 0, 1, 4)
		label.Size = UDim2.new(0.48, 0, 0, FLAG_ROW_HEIGHT)
		label.TextXAlignment = if anchorX == 0 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		label.TextStrokeTransparency = 0.3
		flagLabels[teamId] = label
	end

	local phaseLine = Widgets.label("", gui)
	phaseLine.Name = "Phase"
	phaseLine.AnchorPoint = Vector2.new(0.5, 0)
	phaseLine.Position = UDim2.new(0.5, 0, 0, PHASE_TOP)
	phaseLine.Size = UDim2.fromOffset(420, 28)
	phaseLine.TextStrokeTransparency = 0.3
	-- El altar, debajo de la fase.
	local altarLabel = Widgets.label("", gui)
	altarLabel.Name = "Altar"
	altarLabel.AnchorPoint = Vector2.new(0.5, 0)
	altarLabel.Position = UDim2.new(0.5, 0, 0, PHASE_TOP + 28 + 2)
	altarLabel.Size = UDim2.fromOffset(420, ALTAR_ROW_HEIGHT)
	altarLabel.TextColor3 = ALTAR_COLOR
	altarLabel.TextStrokeTransparency = 0.3

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
	local updateGuard = GuardBar.attach(column:FindFirstChild("Row2") :: Frame, BAR_WIDTH + 30, BAR_HEIGHT)
	local updateEvasive = EvasiveIcon.attach(column:FindFirstChild("Row2") :: Frame, BAR_WIDTH + 30)

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
		altarLabel.Text = if Arena.inBattle() then altarText() else ""
		for teamId, label in flagLabels do
			label.Visible = Arena.inBattle()
			label.Text = flagText(teamId)
			local state = flagState(teamId)
			label.TextColor3 = if state == "Carried"
				then Color3.fromRGB(255, 170, 60)
				elseif state == "Dropped" then Color3.fromRGB(255, 220, 120)
				else Color3.new(1, 1, 1)
		end

		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		local health = if humanoid and humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0
		local blinkOn = os.clock() % 1 < 0.5
		healthFill.Size = UDim2.fromScale(math.clamp(health, 0, 1), 1)
		healthFill.Visible = health > 0
		healthFill.BackgroundColor3 = if health <= 0.25 and blinkOn then LOW_COLOR else HEALTH_COLOR
		local stamina = Stamina.get() / Stamina.MAX
		staminaFill.Size = UDim2.fromScale(stamina, 1)
		staminaFill.Visible = stamina > 0
		updateGuard()
		updateEvasive()

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
