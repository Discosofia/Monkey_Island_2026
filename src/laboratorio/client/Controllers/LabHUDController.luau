--!strict
-- HUD del Laboratorio (estado en Shared/Arena; como ArenaHUDController de Dunas). Según el modo (Shared/LabModes):
--   - Duelo por equipos: bajas de cada bando. Todos contra todos: casillas neutras "Tú" y "🥇" (el líder) y
--     tu puesto. Rondas: las casillas son rondas ganadas, el reloj el de la ronda y, bajo la línea de la fase,
--     quién sigue en pie; la línea de la fase lleva la alarma, la pausa o "Eliminado".
-- Disposición:
--   - Arriba a la derecha, dentro de la franja de la barra de Roblox (GuiService.TopbarInset): marcador
--     "🏴‍☠️ 7 · 4:12 · 5 🥼" con el color de cada bando y, debajo, a cuántas bajas se gana.
--   - Arriba en el centro, justo bajo la barra: la línea de la fase (elige arma y pulsa "Listo", cuenta
--     atrás, muerte súbita, ganador) y, en PC, cómo soltar el ratón (Ctrl, como el bloqueo de cámara de la Isla).
--   - Arriba a la izquierda (12, 10): barras de vida y estamina (la de la esquiva). Sin guardia: aquí no
--     hay.
--   - En el centro, solo mientras se espera para reaparecer: "Reapareces en 3" (encima va el selector de
--     arma, LabLoadoutController).
--   - Botón 😀 de la rueda de emotes (UI/EmoteWheel): abajo a la derecha en PC y arriba a la derecha, bajo
--     el marcador, en táctil. A su izquierda, el ⚙️ de Ajustes (UI/ArenaSettings: mira, opciones, controles);
--     con la ventana abierta el ratón va suelto (FirstPersonController.freeCursor "Settings").
-- En su Init pone los bandos del Laboratorio en Shared/Arena (los demás controladores los leen en Start).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local LabModes = require(ReplicatedStorage.Shared.LabModes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local ArenaSettings = require(ReplicatedStorage.Shared.UI.ArenaSettings)
local EmoteWheel = require(ReplicatedStorage.Shared.UI.EmoteWheel)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local Stamina = require(ReplicatedStorage.CombatClient.Stamina)
local FirstPersonController = require(script.Parent.FirstPersonController)

local T = Strings.t

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
local TARGET_ROW_HEIGHT = 20
-- Línea de la fase, justo bajo la barra de Roblox. LabLoadoutController cuelga su ventana debajo.
local PHASE_TOP = 6
local HINT_COLOR = Color3.fromRGB(210, 200, 185)
-- Casillas del marcador en Todos contra todos: no hay bandos, así que ningún color de bando.
local NEUTRAL_BOX_COLOR = Color3.fromRGB(70, 64, 56)
-- Segunda línea bajo la de la fase (quién sigue en pie en Rondas).
local EXTRA_TOP = PHASE_TOP + 30

local LabHUDController = {}

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

-- Casilla del marcador de un bando: su color de fondo, icono y bajas.
local function scoreBox(parent: Instance, teamId: string, anchorX: number): TextLabel
	local team = Arena.TEAMS[teamId]
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

local function numberAttribute(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- Sigue en la ronda: ni eliminado ni con la vida a 0 (uno que aún no ha aparecido cuenta como en pie).
local function isStanding(other: Player): boolean
	if other:GetAttribute("LabOut") == true then
		return false
	end
	local humanoid = if other.Character then other.Character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid == nil or humanoid.Health > 0
end

local function standingCount(teamId: string): number
	local count = 0
	for _, other in Arena.membersOf(teamId) do
		if isStanding(other) then
			count += 1
		end
	end
	return count
end

-- Su puesto por bajas en Todos contra todos (los empatados comparten puesto) y las bajas del líder.
local function freeForAllStanding(player: Player): (number, number)
	local mine = numberAttribute(player, "ArenaKills")
	local place, best = 1, mine
	for _, other in Players:GetPlayers() do
		local kills = numberAttribute(other, "ArenaKills")
		if other ~= player and kills > mine then
			place += 1
		end
		best = math.max(best, kills)
	end
	return place, best
end

-- Línea de alarma de la ronda: cuenta atrás o aviso de que ya suena.
local function alarmText(left: number): string
	if ReplicatedStorage:GetAttribute("LabAlarm") == true then
		return T("🔔 ¡Alarma! Todos se ven a través de las paredes")
	end
	local untilAlarm = left - (Config.Lab.RoundSeconds - Config.Lab.AlarmAtSeconds)
	return T("🔔 Alarma en {seconds}", { seconds = math.ceil(math.max(0, untilAlarm)) })
end

-- Texto de la línea de la fase.
local function phaseText(player: Player): string
	local phase = Arena.phase()
	local left = Arena.secondsLeft()
	local rounds = LabModes.isRounds()
	if rounds and phase == "Intermission" then
		return T(
			"Ronda {round} en {seconds} · puedes cambiar de arma",
			{ round = numberAttribute(ReplicatedStorage, "LabRound") + 1, seconds = math.ceil(left) }
		)
	elseif rounds and (phase == "Battle" or phase == "SuddenDeath") then
		if player:GetAttribute("LabOut") == true then
			return T("💀 Eliminado: vuelves en la siguiente ronda")
		end
		return if phase == "SuddenDeath" then T("⚡ ¡Ronda decisiva! La gana quien la gane") else alarmText(left)
	end
	if phase == "Waiting" then
		return if left > 0
			then T("Elige tu arma y pulsa «Listo» · {time}", { time = clock(left) })
			else T("Elige tu arma y pulsa «Listo»")
	elseif phase == "Countdown" then
		return T("⚔️ El duelo empieza en {seconds}", { seconds = math.ceil(left) })
	elseif phase == "SuddenDeath" then
		return T("⚡ ¡Muerte súbita! La siguiente baja gana")
	elseif phase == "Results" then
		local winnerName = ReplicatedStorage:GetAttribute("LabWinnerName")
		if typeof(winnerName) == "string" and winnerName ~= "" then
			return T("🏆 ¡Gana {name}!", { name = winnerName })
		end
		local winner = ReplicatedStorage:GetAttribute("ArenaWinner")
		if Arena.isTeam(winner) then
			local team = Arena.TEAMS[winner :: string]
			return T("🏆 ¡Gana el bando {icon} {name}!", { icon = team.icon, name = T(team.name) })
		end
		return T("🤝 Empate")
	end
	return ""
end

function LabHUDController:Init()
	Arena.configure(Config.Lab.Teams, Config.Lab.TeamOrder)
end

function LabHUDController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("LabHUD", player:WaitForChild("PlayerGui"))
	-- El marcador va en la barra de Roblox: en una pantalla que no la descuenta.
	local topGui = Widgets.screen("LabScore", player:WaitForChild("PlayerGui"))
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
	local firstId, secondId = Arena.TEAM_IDS[1], Arena.TEAM_IDS[2]
	local firstBox = scoreBox(score, firstId, 0)
	local secondBox = scoreBox(score, secondId, 1)
	local timer = Widgets.label("", score)
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(0.5, 0.5)
	timer.Position = UDim2.fromScale(0.5, 0.5)
	timer.Size = UDim2.fromScale(0.34, 0.7)
	-- A cuántas bajas se gana, bajo el marcador.
	local target = Widgets.label("", score)
	target.Name = "Target"
	target.AnchorPoint = Vector2.new(0.5, 0)
	target.Position = UDim2.new(0.5, 0, 1, 4)
	target.Size = UDim2.new(1, 0, 0, TARGET_ROW_HEIGHT)
	target.TextStrokeTransparency = 0.3

	local phaseLine = Widgets.label("", gui)
	phaseLine.Name = "Phase"
	phaseLine.AnchorPoint = Vector2.new(0.5, 0)
	phaseLine.Position = UDim2.new(0.5, 0, 0, PHASE_TOP)
	phaseLine.Size = UDim2.fromOffset(420, 28)
	phaseLine.TextStrokeTransparency = 0.3
	local extraLine = Widgets.label("", gui)
	extraLine.Name = "Extra"
	extraLine.AnchorPoint = Vector2.new(0.5, 0)
	extraLine.Position = UDim2.new(0.5, 0, 0, EXTRA_TOP)
	extraLine.Size = UDim2.fromOffset(320, 22)
	extraLine.TextStrokeTransparency = 0.3
	-- Cómo soltar el ratón (solo con teclado).
	local hint = Widgets.label("", gui)
	hint.Name = "CursorHint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -12)
	hint.Size = UDim2.fromOffset(320, 20)
	hint.TextColor3 = HINT_COLOR
	hint.TextStrokeTransparency = 0.4

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

	-- Rueda de emotes, la misma del Lobby y la Isla.
	local emoteButton = EmoteWheel.button(gui)
	local function placeEmoteButton()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			emoteButton.AnchorPoint = Vector2.new(1, 0)
			emoteButton.Position = UDim2.new(1, -12, 0, TARGET_ROW_HEIGHT + 12)
		else
			emoteButton.AnchorPoint = Vector2.new(1, 1)
			emoteButton.Position = UDim2.new(1, -12, 1, -12)
		end
	end
	placeEmoteButton()
	UserInputService.LastInputTypeChanged:Connect(placeEmoteButton)
	EmoteWheel.start()
	-- Ajustes (⚙️), pegado a la izquierda del 😀 aunque este cambie de sitio. Con la ventana abierta se suelta el ratón.
	ArenaSettings.attach(gui, emoteButton, {
		onOpen = function()
			FirstPersonController.freeCursor("Settings", true)
		end,
		onClose = function()
			FirstPersonController.freeCursor("Settings", false)
		end,
	})

	-- Cuenta atrás para reaparecer.
	local respawn = Widgets.label("", gui)
	respawn.Name = "Respawn"
	respawn.AnchorPoint = Vector2.new(0.5, 0.5)
	respawn.Position = UDim2.fromScale(0.5, 0.2)
	respawn.Size = UDim2.fromScale(0.5, 0.07)
	respawn.TextStrokeTransparency = 0.3
	local respawnLimit = Instance.new("UITextSizeConstraint")
	respawnLimit.MaxTextSize = 36
	respawnLimit.Parent = respawn

	local boxesNeutral: boolean? = nil
	RunService.RenderStepped:Connect(function()
		local firstTeam, secondTeam = Arena.TEAMS[firstId], Arena.TEAMS[secondId]
		local phase = Arena.phase()
		local freeForAll = LabModes.isFreeForAll()
		local rounds = LabModes.isRounds()
		local inRound = rounds and (phase == "Battle" or phase == "SuddenDeath")
		if boxesNeutral ~= freeForAll then
			boxesNeutral = freeForAll
			firstBox.BackgroundColor3 = if freeForAll then NEUTRAL_BOX_COLOR else firstTeam.color
			secondBox.BackgroundColor3 = if freeForAll then NEUTRAL_BOX_COLOR else secondTeam.color
		end
		local killsToWin = ReplicatedStorage:GetAttribute("LabKillsToWin")
		if freeForAll then
			local place, best = freeForAllStanding(player)
			firstBox.Text = T("Tú {n}", { n = numberAttribute(player, "ArenaKills") })
			secondBox.Text = T("🥇 {n}", { n = best })
			target.Text = if typeof(killsToWin) == "number"
				then T("Gana el primero a {kills} bajas · vas {place}.º", { kills = killsToWin, place = place })
				else ""
		else
			firstBox.Text = `{firstTeam.icon} {Arena.score(firstId)}`
			secondBox.Text = `{Arena.score(secondId)} {secondTeam.icon}`
			if rounds then
				local toWin = ReplicatedStorage:GetAttribute("LabRoundsToWin")
				target.Text = if typeof(toWin) == "number"
					then T(
						"Ronda {round} · gana el primero a {rounds}",
						{ round = math.max(1, numberAttribute(ReplicatedStorage, "LabRound")), rounds = toWin }
					)
					else ""
			else
				target.Text = if typeof(killsToWin) == "number"
					then T("Gana el primero a {kills} bajas", { kills = killsToWin })
					else ""
			end
		end
		-- En Rondas el reloj es el de la ronda (o el de la pausa); la muerte súbita de las rondas también acaba.
		timer.Text = if phase == "Battle"
				or phase == "Countdown"
				or (rounds and (phase == "SuddenDeath" or phase == "Intermission"))
			then clock(Arena.secondsLeft())
			elseif phase == "SuddenDeath" then "⚡"
			else "—"
		phaseLine.Text = phaseText(player)
		extraLine.Text = if inRound
			then T("🧍 En pie: {a} · {b}", {
				a = `{firstTeam.icon} {standingCount(firstId)}`,
				b = `{standingCount(secondId)} {secondTeam.icon}`,
			})
			else ""
		-- Con el selector o los resultados abiertos no se puede volver a apuntar: sin aviso.
		hint.Visible = UserInputService.KeyboardEnabled and not FirstPersonController.needsCursor()
		hint.Text = if FirstPersonController.isCursorFree()
			then T("Ctrl: volver a apuntar")
			else T("Ctrl: soltar el ratón")

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
			respawn.Text = T("Reapareces en {seconds}", { seconds = math.ceil(left) })
			respawn.Visible = true
		else
			respawn.Visible = false
		end
	end)
end

return LabHUDController
