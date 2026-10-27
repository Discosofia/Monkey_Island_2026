--!strict
-- Ventana de bienvenida al entrar al Lobby (calendario de 7 días, octubre de 2026; pioneros, T6):
--   - Sale una vez al entrar si hay premio por cobrar o, a un pionero (Shared/Pioneer), también sin
--     premio si hace un rato que no la ve (Config.Pioneer.WelcomeGapMinutes; Remotes.WelcomeSeen).
--   - Al pionero le da las gracias y le dice cuántos cobros faltan para la tirada de montura del día 7,
--     con la probabilidad de cada una.
--   - Las casillas (UI/CalendarStrip), lo que da el de hoy y el botón Cobrar. Al cobrar enseña lo
--     recibido y se cierra sola.
--   - Si el cobro trae la tirada de pioneros: el huevo de pioneros tiembla cada vez más, estalla con un
--     destello del color de la rareza y sale la montura girando. Si ya la tenía, tachada y con su Ámbar.
-- Lo mismo se cobra en la pestaña Misiones (LobbyUIController): si de allí sale la tirada, esta
-- ventana se abre para enseñarla.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Daily = require(ReplicatedStorage.Shared.Daily)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local EggModel = require(ReplicatedStorage.Shared.EggModel)
local MountModels = require(ReplicatedStorage.Shared.MountModels)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local Pioneer = require(ReplicatedStorage.Shared.Pioneer)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardModels = require(ReplicatedStorage.Shared.RewardModels)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local CalendarStrip = require(ReplicatedStorage.Shared.UI.CalendarStrip)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local CLOSE_COLOR = Color3.fromRGB(150, 60, 50)
local GOLD = Color3.fromRGB(255, 205, 70)
local TEXT = Color3.fromRGB(230, 220, 200)
local DIM_TEXT = Color3.fromRGB(160, 150, 135)
local REVEAL_COLOR = Color3.fromRGB(14, 18, 34)
local CLOSE_AFTER_CLAIM_SECONDS = 5
local SHAKE_SECONDS = 1.8
local SPIN_SPEED = 0.9

local CalendarController = {}

local player = Players.LocalPlayer

local function readJson(name: string): any
	local raw = player:GetAttribute(name)
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok then decoded else nil
end

local function readLogin(): Daily.LoginState?
	local decoded = readJson("Retention")
	if typeof(decoded) ~= "table" then
		return nil
	end
	return Daily.loginState(decoded.login)
end

local function readPioneer(): Pioneer.State
	return Pioneer.normalize(readJson("Pioneer"))
end

-- "🦙 Llama 75 % · …": la probabilidad de cada montura de la tirada, con la primera palabra del nombre
-- (los nombres enteros no caben en una línea legible).
local function chancesText(): string
	local parts = {}
	for _, entry in Pioneer.chances() do
		local mount = Mounts[entry.id]
		local short = string.match(mount.name, "^[^%s,]+") or mount.name
		table.insert(parts, `{mount.icon} {short} {math.round(entry.chance * 100)} %`)
	end
	return table.concat(parts, " · ")
end

local window: ScreenGui? = nil
-- Se está enseñando la tirada: la ventana no se cierra sola.
local revealing = false
-- La ventana abierta tiene el botón Cobrar (si no, "¡A jugar!").
local windowClaimable = false

local function close()
	if window then
		window:Destroy()
		window = nil
	end
	revealing = false
end

local function open(login: Daily.LoginState, pioneer: Pioneer.State)
	close()
	local gui = Widgets.screen("CalendarUI", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 7
	window = gui
	local isPioneer = Pioneer.isPioneer(pioneer)
	local claimable = Daily.canClaim(login, EggIncubation.now())
	windowClaimable = claimable

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromScale(0.62, 0.72)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(320, 280)
	sizeLimit.MaxSize = Vector2.new(640, 480)
	sizeLimit.Parent = panel

	local title = Widgets.label(
		if isPioneer
			then "🌟 ¡Gracias por ser pionero!"
			else `📅 Premio diario · día {login.step} de {Daily.CALENDAR_DAYS}`,
		panel
	)
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -76, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left
	if isPioneer then
		title.TextColor3 = GOLD
	end

	local closeButton = Widgets.button("X", panel)
	closeButton.Font = Enum.Font.BuilderSansExtraBold
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -8, 0, 6)
	closeButton.Size = UDim2.fromOffset(44, 44)
	closeButton.BackgroundColor3 = CLOSE_COLOR
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	local closeLimit = closeButton:FindFirstChildOfClass("UISizeConstraint")
	if closeLimit then
		closeLimit.MinSize = Vector2.new(44, 44)
	end
	closeButton.Activated:Connect(close)

	-- Al pionero, una línea más bajo el título.
	local top = 56
	if isPioneer then
		local thanks = Widgets.label(
			`Juegas desde el principio. Cada {Daily.CALENDAR_DAYS} días de entrada, una montura de pioneros`,
			panel
		)
		thanks.Position = UDim2.fromOffset(14, 44)
		thanks.Size = UDim2.new(1, -28, 0, 22)
		thanks.TextXAlignment = Enum.TextXAlignment.Left
		thanks.Font = Enum.Font.BuilderSans
		thanks.TextColor3 = TEXT
		top = 74
	end

	local stripHolder = Instance.new("Frame")
	stripHolder.Name = "Strip"
	stripHolder.BackgroundTransparency = 1
	stripHolder.Position = UDim2.fromOffset(12, top)
	stripHolder.Size = UDim2.new(1, -24, 0.54, -top)
	stripHolder.Parent = panel
	CalendarStrip.build(stripHolder, login, EggIncubation.now())

	local today = Widgets.label(
		if claimable
			then `Hoy: {Rewards.describe(Config.Daily.Calendar[login.step])}`
			else `Hoy ya cobraste: mañana, el día {login.step}`,
		panel
	)
	today.Name = "Today"
	today.AnchorPoint = Vector2.new(0.5, 0)
	today.Position = UDim2.fromScale(0.5, 0.56)
	today.Size = UDim2.fromScale(0.92, 0.12)
	today.TextWrapped = true
	today.TextColor3 = GOLD

	if isPioneer then
		local left = Pioneer.claimsToRoll(login)
		local whenText = if left == 1 and claimable
			then "¡hoy!"
			elseif left == 1 then "el próximo cobro"
			else `en {left} cobros`
		local roll = Widgets.label(`🎁 Tirada de pioneros: {whenText}`, panel)
		roll.Name = "PioneerRoll"
		roll.AnchorPoint = Vector2.new(0.5, 0)
		roll.Position = UDim2.fromScale(0.5, 0.68)
		roll.Size = UDim2.fromScale(0.92, 0.06)
		roll.TextColor3 = TEXT
		local chances = Widgets.label(chancesText(), panel)
		chances.Name = "PioneerChances"
		chances.AnchorPoint = Vector2.new(0.5, 0)
		chances.Position = UDim2.fromScale(0.5, 0.74)
		chances.Size = UDim2.fromScale(0.92, 0.05)
		chances.Font = Enum.Font.BuilderSans
		chances.TextColor3 = DIM_TEXT
	else
		local hint = Widgets.label("Entra cada día: si faltas, no pierdes nada y sigues por donde ibas", panel)
		hint.Name = "Hint"
		hint.AnchorPoint = Vector2.new(0.5, 0)
		hint.Position = UDim2.fromScale(0.5, 0.7)
		hint.Size = UDim2.fromScale(0.92, 0.07)
		hint.Font = Enum.Font.BuilderSans
		hint.TextColor3 = TEXT
	end

	local claim = Widgets.button(if claimable then "Cobrar" else "¡A jugar!", panel)
	claim.Name = "Claim"
	claim.AnchorPoint = Vector2.new(0.5, 1)
	claim.Position = UDim2.new(0.5, 0, 1, -12)
	claim.Size = UDim2.fromScale(0.45, 0.12)
	local claiming = false
	claim.Activated:Connect(function()
		if not claimable then
			close()
			return
		end
		if claiming then
			return
		end
		claiming = true
		claim.Text = "Cobrando…"
		Remotes.ClaimLogin:FireServer()
	end)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = panel
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Remotes.WelcomeSeen:FireServer()
end

local function windowPanel(): Frame?
	local gui = window
	local panel = if gui then gui:FindFirstChildOfClass("Frame") else nil
	return if panel and panel:IsA("Frame") then panel else nil
end

local function setText(panel: Frame, name: string, text: string, color: Color3?)
	local label = panel:FindFirstChild(name)
	if label and label:IsA("TextLabel") then
		label.Text = text
		if color then
			label.TextColor3 = color
		end
	end
end

-- Gira el modelo sobre el centro de su caja mientras siga en el visor.
local function spin(model: Model, speed: number)
	local box = model:GetBoundingBox()
	local center = CFrame.new(box.Position)
	local offset = center:Inverse() * model:GetPivot()
	local started = os.clock()
	while model.Parent do
		local t = os.clock() - started
		model:PivotTo(center * CFrame.Angles(0, t * speed, 0) * offset)
		RunService.RenderStepped:Wait()
	end
end

-- La tirada de pioneros en la ventana, en lugar de las casillas.
local function playReveal(panel: Frame, roll: Pioneer.Roll)
	local mount = Mounts[roll.mount]
	local rarity = Rarities[mount.rarity]
	local strip = panel:FindFirstChild("Strip")
	if not (strip and strip:IsA("Frame")) then
		return
	end
	strip.Visible = false
	local stage = Instance.new("Frame")
	stage.Name = "Reveal"
	stage.Position = strip.Position
	stage.Size = strip.Size
	stage.BackgroundColor3 = REVEAL_COLOR
	stage.Parent = panel
	local stageCorner = Instance.new("UICorner")
	stageCorner.CornerRadius = UDim.new(0, 10)
	stageCorner.Parent = stage
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Parent = stage

	-- El huevo de pioneros tiembla cada vez más fuerte.
	local egg = EggModel.build("Pioneer")
	RewardModels.frame(viewport, egg, 1.1)
	local rest = egg:GetPivot()
	local started = os.clock()
	while os.clock() - started < SHAKE_SECONDS and stage.Parent do
		local t = (os.clock() - started) / SHAKE_SECONDS
		local shake = 0.04 + t * 0.28
		local clock = os.clock()
		egg:PivotTo(
			rest
				* CFrame.new(math.sin(clock * 50) * shake * 0.3, 0, 0)
				* CFrame.Angles(math.sin(clock * 37) * shake, 0, math.cos(clock * 41) * shake)
		)
		RunService.RenderStepped:Wait()
	end
	if not stage.Parent then
		return
	end
	egg:Destroy()

	-- Destello del color de la rareza y sale la montura.
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = rarity.color
	flash.ZIndex = 3
	flash.Parent = stage
	local flashCorner = stageCorner:Clone()
	flashCorner.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()

	local model = MountModels.build(roll.mount)
	if model then
		-- El visor es ancho y bajo: una montura alta (la llama) entera; una larga (jaguar, serpiente) más
		-- cerca, para que no quede pequeña.
		local _, size = model:GetBoundingBox()
		local tall = size.Y >= math.max(size.X, size.Z) * 0.8
		RewardModels.frame(viewport, model, if tall then 1 else 1.7)
		task.spawn(spin, model, SPIN_SPEED)
	end
	local name = Widgets.label(`{mount.icon} {mount.name}`, stage)
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.fromScale(0.5, 0.03)
	name.Size = UDim2.fromScale(0.94, 0.16)
	name.TextColor3 = rarity.color
	name.ZIndex = 2
	local tag = Widgets.label(rarity.name, stage)
	tag.AnchorPoint = Vector2.new(0.5, 1)
	tag.Position = UDim2.fromScale(0.5, 0.97)
	tag.Size = UDim2.fromScale(0.6, 0.11)
	tag.TextColor3 = rarity.color
	tag.ZIndex = 2
	local nameScale = Instance.new("UIScale")
	nameScale.Scale = 1.5
	nameScale.Parent = name
	TweenService:Create(nameScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	if roll.amber > 0 then
		-- Ya la tenía: velada y tachada, con lo que da a cambio.
		local veil = Instance.new("Frame")
		veil.Size = UDim2.fromScale(1, 1)
		veil.BackgroundColor3 = REVEAL_COLOR
		veil.BackgroundTransparency = 0.45
		veil.ZIndex = 1
		veil.Parent = stage
		local strike = Instance.new("Frame")
		strike.AnchorPoint = Vector2.new(0.5, 0.5)
		strike.Position = UDim2.fromScale(0.5, 0.5)
		strike.Size = UDim2.new(0.7, 0, 0, 6)
		strike.Rotation = -14
		strike.BackgroundColor3 = TEXT
		strike.BorderSizePixel = 0
		strike.ZIndex = 2
		strike.Parent = stage
		tag.Text = `{rarity.name} · Ya la tenías: +{roll.amber} ✨ Ámbar`
		tag.Size = UDim2.fromScale(0.94, 0.11)
	end
end

-- Premio cobrado: la ventana (si está abierta) enseña lo recibido y se cierra sola. Con la tirada de
-- pioneros, primero la revelación, y se queda abierta hasta que la cierre.
local function showClaimed(day: number, lines: { string }, roll: Pioneer.Roll?)
	if roll and not window then
		local login = readLogin()
		if not login then
			return
		end
		open(login, readPioneer())
	end
	local gui = window
	local panel = windowPanel()
	if not (gui and panel) then
		return
	end
	-- La línea de la tirada ya la enseña la revelación (en la pestaña Misiones sí se ve).
	local shown = {}
	for index, line in lines do
		if not (roll and index == #lines) then
			table.insert(shown, line)
		end
	end
	setText(panel, "Today", `🎉 ¡Día {day} cobrado! {table.concat(shown, " · ")}`)
	setText(panel, "Hint", "Vuelve mañana a por el siguiente")
	local claim = panel:FindFirstChild("Claim")
	if claim and claim:IsA("TextButton") then
		claim.Text = "¡Genial!"
		claim.Activated:Connect(close)
	end
	if roll then
		revealing = true
		local mount = Mounts[roll.mount]
		setText(
			panel,
			"PioneerRoll",
			`🎁 Tirada de pioneros: {mount.icon} {mount.name}`,
			Rarities[mount.rarity].color
		)
		setText(panel, "PioneerChances", `La próxima, dentro de {Daily.CALENDAR_DAYS} cobros`)
		task.spawn(playReveal, panel, roll)
		return
	end
	-- Las casillas, con el día recién cobrado ya marcado (el perfil llega justo después del aviso).
	local strip = panel:FindFirstChild("Strip")
	task.delay(0.3, function()
		local state = readLogin()
		if state and strip and strip:IsA("Frame") and strip.Parent then
			strip:ClearAllChildren()
			CalendarStrip.build(strip, state, EggIncubation.now())
		end
		local pioneer = readPioneer()
		if state and Pioneer.isPioneer(pioneer) then
			setText(panel, "PioneerRoll", `🎁 Tirada de pioneros: en {Pioneer.claimsToRoll(state)} cobros`)
		end
	end)
	task.delay(CLOSE_AFTER_CLAIM_SECONDS, function()
		if window == gui and not revealing then
			close()
		end
	end)
end

local function validRoll(raw: any): Pioneer.Roll?
	if typeof(raw) == "table" and typeof(raw.mount) == "string" and Mounts[raw.mount] then
		return { mount = raw.mount, amber = if typeof(raw.amber) == "number" then raw.amber else 0 }
	end
	return nil
end

function CalendarController:Start()
	Remotes.LoginClaimed.OnClientEvent:Connect(function(day: any, lines: any, roll: any)
		if typeof(day) == "number" and typeof(lines) == "table" then
			showClaimed(day, lines, validRoll(roll))
		end
	end)
	-- Si con la ventana abierta vuelve a haber premio (cambio de día con ella abierta o el panel de
	-- pruebas), se rehace con el botón Cobrar.
	player:GetAttributeChangedSignal("Retention"):Connect(function()
		local login = readLogin()
		if
			window
			and not windowClaimable
			and not revealing
			and login
			and Daily.canClaim(login, EggIncubation.now())
		then
			open(login, readPioneer())
		end
	end)
	-- Una vez al entrar, cuando llegan los datos del perfil.
	local state = readLogin()
	while not state and player.Parent do
		player:GetAttributeChangedSignal("Retention"):Wait()
		state = readLogin()
	end
	if state then
		local pioneer = readPioneer()
		if Pioneer.shouldWelcome(pioneer, state, EggIncubation.now()) then
			open(state, pioneer)
		end
	end
end

return CalendarController
