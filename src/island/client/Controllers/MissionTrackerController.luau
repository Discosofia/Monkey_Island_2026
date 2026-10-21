--!strict
-- Rastreador de las misiones en la Isla (bucle de retención, octubre de 2026; misiones v2 de la Fase 9):
-- las 3 del día y las de la semana, cada una con lo que llevas ("7/10") o ✅, para no tener que
-- volver al Lobby a mirarlas. La lista se pliega tocando su cabecera (🔼/🔽): plegada queda una
-- línea con lo cumplido ("hoy 1/3 · semana 2/5").
--   - En PC: debajo del panel de combos (ComboController), con su mismo estilo. Si está desplegada se
--     guarda en los ajustes del jugador (Settings "missionsOpen").
--   - En un teléfono (táctil sin teclado), la columna izquierda es la del joystick y la derecha la de
--     los botones de acción: van fichas compactas en la franja de la barra de Roblox
--     (GuiService.TopbarInset, libre en la Isla), tras sus botones (el icono de cada misión del día con
--     lo que llevas y "📆 2/5"), y tocarlas abre la lista entera justo debajo. Empieza plegada: tapa
--     las barras de arriba a la izquierda mientras se mira.
-- Lee el atributo "Retention" (misiones del día y de la semana, ServerShared/Retention), que se apunta
-- cada pocos segundos mientras juegas.
-- Debajo, la tarjeta del contrato de expedición de la partida (Fase 9, G6; Shared/Contract): el paso
-- abierto con lo que lleva el grupo y el siguiente. En PC va siempre a la vista (sigue al panel al
-- plegarlo); en el teléfono, una ficha "📜" en la franja y la tarjeta bajo la lista al abrirla.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Contract = require(ReplicatedStorage.Shared.Contract)
local Contracts = require(ReplicatedStorage.Shared.Data.Contracts)
local Daily = require(ReplicatedStorage.Shared.Daily)
local Missions = require(ReplicatedStorage.Shared.Data.Missions)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local GOLD = Color3.fromRGB(255, 205, 70)
local DONE = Color3.fromRGB(120, 230, 140)
local TEXT = Color3.fromRGB(230, 220, 200)
local PANEL = Color3.fromRGB(25, 25, 25)
local DIM = Color3.fromRGB(175, 165, 150)
local FAILED = Color3.fromRGB(235, 110, 90)
local LINE_HEIGHT = 18
local HEADER_HEIGHT = 20
local WIDTH = 5 * 66 - 6
-- Fichas de la franja de arriba en el teléfono: alto (según la franja) y separación.
local CHIP_MIN_HEIGHT = 24
local CHIP_MAX_HEIGHT = 34
local CHIP_GAP = 4
-- Separación entre el panel de misiones y la tarjeta del contrato.
local CARD_GAP = 6

local MissionTrackerController = {}

-- Lo que dibuja cada versión (PC o teléfono): las misiones y el contrato.
type Show = { missions: (Shown) -> (), contract: (Contract.State?) -> () }

type Shown = {
	daily: { Daily.DailyMission },
	weekly: { Daily.DailyMission },
	dailyDone: number,
	weeklyDone: number,
}

local function countDone(missions: { Daily.DailyMission }): number
	local done = 0
	for _, mission in missions do
		done += if mission.done then 1 else 0
	end
	return done
end

local function read(player: Player): Shown
	local raw = player:GetAttribute("Retention")
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
	end)
	local data = if ok and typeof(decoded) == "table" then decoded else {}
	local daily = Daily.missionState(data.daily).missions
	local weekly = Daily.weeklyState(data.weekly).missions
	return { daily = daily, weekly = weekly, dailyDone = countDone(daily), weeklyDone = countDone(weekly) }
end

local function progressText(mission: Daily.DailyMission): string
	return if mission.done then "✅" else `{math.floor(mission.progress)}/{Missions[mission.id].target}`
end

-- Columna vertical con el panel de misiones y, debajo, la tarjeta del contrato: la tarjeta sigue al
-- panel cuando crece o se pliega.
local function column(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Tracker"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(WIDTH, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, CARD_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

-- Panel con la cabecera que pliega y despliega y, desplegado, una línea por misión (las del día y,
-- tras su título, las de la semana). Devuelve el panel y la función que lo dibuja.
local function buildList(parent: Instance, onToggle: () -> ()): (Frame, (Shown, boolean) -> ())
	local panel = Instance.new("Frame")
	panel.Name = "Missions"
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.4
	panel.Visible = false
	panel.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	-- La cabecera entera es el botón (el panel es pequeño: así se acierta).
	local header = Instance.new("TextButton")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Text = ""
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT + 2)
	header.Parent = panel
	header.Activated:Connect(onToggle)
	local title = Widgets.label("", header)
	title.Position = UDim2.fromOffset(6, 2)
	title.Size = UDim2.new(1, -40, 0, HEADER_HEIGHT - 4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = GOLD
	local arrow = Widgets.label("", header)
	arrow.AnchorPoint = Vector2.new(1, 0)
	arrow.Position = UDim2.new(1, -6, 0, 2)
	arrow.Size = UDim2.fromOffset(28, HEADER_HEIGHT - 4)
	arrow.TextXAlignment = Enum.TextXAlignment.Right

	type Line = { text: TextLabel, count: TextLabel }
	local lines: { Line } = {}
	local function lineAt(index: number): Line
		local existing = lines[index]
		if existing then
			return existing
		end
		local y = HEADER_HEIGHT + 2 + (index - 1) * LINE_HEIGHT
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

	return panel,
		function(shown: Shown, open: boolean)
			local total = #shown.daily + #shown.weekly
			panel.Visible = total > 0
			arrow.Text = if open then "🔼" else "🔽"
			local week = if #shown.weekly > 0 then ` · semana {shown.weeklyDone}/{#shown.weekly}` else ""
			title.Text = if open
				then "🎯 Misiones del día"
				else `🎯 Misiones · hoy {shown.dailyDone}/{#shown.daily}{week}`

			local used = 0
			local function put(text: string, count: string, color: Color3)
				used += 1
				local line = lineAt(used)
				line.text.Text = text
				line.text.TextColor3 = color
				line.count.Text = count
				line.count.TextColor3 = color
			end
			if open then
				for _, mission in shown.daily do
					put(Daily.missionText(mission.id), progressText(mission), if mission.done then DONE else TEXT)
				end
				if #shown.weekly > 0 then
					local all = shown.weeklyDone >= #shown.weekly
					put(
						"📆 Misiones de la semana",
						if all then "✅" else `{shown.weeklyDone}/{#shown.weekly}`,
						if all then DONE else GOLD
					)
					for _, mission in shown.weekly do
						put(Daily.missionText(mission.id), progressText(mission), if mission.done then DONE else TEXT)
					end
				end
			end
			for index, line in lines do
				line.text.Visible = index <= used
				line.count.Visible = index <= used
			end
			panel.Size = UDim2.fromOffset(WIDTH, HEADER_HEIGHT + 4 + used * LINE_HEIGHT)
		end
end

-- Tarjeta del contrato: cabecera (contrato y pasos cumplidos), el paso abierto con su progreso y el
-- siguiente con su día. Devuelve la tarjeta y la función que la dibuja.
local function buildContractCard(parent: Instance): (Frame, (Contract.State?) -> ())
	local card = Instance.new("Frame")
	card.Name = "Contract"
	card.BackgroundColor3 = PANEL
	card.BackgroundTransparency = 0.4
	card.Size = UDim2.fromOffset(WIDTH, HEADER_HEIGHT + 4 + 2 * LINE_HEIGHT)
	card.Visible = false
	card.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local function row(y: number, height: number): (TextLabel, TextLabel)
		local text = Widgets.label("", card)
		text.Position = UDim2.fromOffset(6, y)
		text.Size = UDim2.new(1, -70, 0, height)
		text.TextXAlignment = Enum.TextXAlignment.Left
		local count = Widgets.label("", card)
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -6, 0, y)
		count.Size = UDim2.fromOffset(60, height)
		count.TextXAlignment = Enum.TextXAlignment.Right
		return text, count
	end
	local title, titleCount = row(2, HEADER_HEIGHT - 4)
	title.TextColor3 = GOLD
	titleCount.TextColor3 = GOLD
	local current, currentCount = row(HEADER_HEIGHT + 2, LINE_HEIGHT - 2)
	local upcoming, _ = row(HEADER_HEIGHT + 2 + LINE_HEIGHT, LINE_HEIGHT - 2)
	upcoming.Size = UDim2.new(1, -12, 0, LINE_HEIGHT - 2)
	upcoming.TextColor3 = DIM

	return card,
		function(state: Contract.State?)
			card.Visible = state ~= nil
			if not state then
				return
			end
			local contract = Contracts[state.id]
			local index = math.max(state.index, 1)
			local step = contract.steps[index]
			local entry = state.steps[index]
			title.Text = `📜 Contrato: {contract.icon} {contract.name}`
			titleCount.Text = `{Contract.doneCount(state)}/{#contract.steps} ✅`
			if entry.status == "done" then
				current.Text = `✅ {step.title}: cumplido`
				current.TextColor3 = DONE
				currentCount.Text = ""
			elseif entry.status == "failed" then
				current.Text = `❌ {step.title}: se acabó el plazo`
				current.TextColor3 = FAILED
				currentCount.Text = ""
			else
				current.Text = `{step.icon} {Contract.stepText(step, entry.target)}`
				current.TextColor3 = TEXT
				currentCount.Text = `{math.floor(entry.progress)}/{entry.target}`
				currentCount.TextColor3 = TEXT
			end
			local nextStep = contract.steps[index + 1]
			if nextStep then
				local days = Contract.daysText(contract, index)
				upcoming.Text =
					`{string.upper(string.sub(days, 1, 1))}{string.sub(days, 2)} · luego, día {nextStep.day}: {nextStep.icon} {nextStep.title}`
			else
				upcoming.Text = if entry.status == "done"
					then "🚁 Último paso cumplido"
					else "Último paso: encendedla de día y resistid la noche"
			end
		end
end

-- PC: la lista bajo los combos, desplegada o no según los ajustes del jugador.
local function buildPanel(player: Player): Show
	local gui = Widgets.screen("MissionHUD", player:WaitForChild("PlayerGui"))
	local last: Shown? = nil
	local draw: (Shown, boolean) -> ()
	local holder = column(gui)
	-- Debajo del panel de combos (12, 170, 62 de alto).
	holder.Position = UDim2.fromOffset(12, 240)
	local panel
	panel, draw = buildList(holder, function()
		Settings.set("missionsOpen", not Settings.get().missionsOpen)
	end)
	panel.LayoutOrder = 1
	local card, drawCard = buildContractCard(holder)
	card.LayoutOrder = 2
	Settings.onChanged(function(values)
		if last then
			draw(last, values.missionsOpen)
		end
	end)
	return {
		missions = function(shown: Shown)
			last = shown
			draw(shown, Settings.get().missionsOpen)
		end,
		contract = drawCard,
	}
end

-- Teléfono: fichas en la franja de la barra de Roblox, tras sus botones; tocarlas abre la lista debajo.
local function buildBand(player: Player): Show
	local gui = Widgets.screen("MissionBand", player:WaitForChild("PlayerGui"))
	gui.IgnoreGuiInset = true

	local open = false
	local last: Shown? = nil
	local lastContract: Contract.State? = nil
	local draw: (Shown, boolean) -> ()
	local refresh: () -> ()

	local strip = Instance.new("Frame")
	strip.Name = "Chips"
	strip.BackgroundTransparency = 1
	strip.AutomaticSize = Enum.AutomaticSize.X
	strip.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, CHIP_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip

	local function toggle()
		open = not open
		refresh()
	end
	local holder = column(gui)
	local list
	list, draw = buildList(holder, toggle)
	list.LayoutOrder = 1
	local card, drawCard = buildContractCard(holder)
	card.LayoutOrder = 2

	local chipHeight = CHIP_MAX_HEIGHT
	local function place()
		local inset = GuiService.TopbarInset
		local band = if inset.Height > 0 then inset.Height else 44
		chipHeight = math.clamp(band - 12, CHIP_MIN_HEIGHT, CHIP_MAX_HEIGHT)
		strip.Position = UDim2.fromOffset(inset.Min.X + 8, inset.Min.Y + (band - chipHeight) / 2)
		strip.Size = UDim2.fromOffset(0, chipHeight)
		for _, chip in strip:GetChildren() do
			if chip:IsA("TextButton") then
				chip.Size = UDim2.fromOffset(0, chipHeight)
				chip.TextSize = math.max(13, chipHeight - 14)
			end
		end
		-- La lista, justo debajo de la franja y alineada con las fichas.
		holder.Position = UDim2.fromOffset(inset.Min.X + 8, inset.Min.Y + band + 4)
	end
	place()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)

	local chips: { TextButton } = {}
	local function chipAt(index: number): TextButton
		local existing = chips[index]
		if existing then
			return existing
		end
		local chip = Instance.new("TextButton")
		chip.Name = `Chip{index}`
		chip.LayoutOrder = index
		chip.AutoButtonColor = false
		chip.Font = Enum.Font.BuilderSansBold
		chip.TextStrokeTransparency = 0.5
		chip.TextSize = math.max(13, chipHeight - 14)
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(0, chipHeight)
		chip.BackgroundColor3 = PANEL
		chip.BackgroundTransparency = 0.4
		chip.Parent = strip
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = chip
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.Parent = chip
		chip.Activated:Connect(toggle)
		chips[index] = chip
		return chip
	end

	function refresh()
		local shown = last
		local contract = lastContract
		local used = 0
		local function put(text: string, color: Color3)
			used += 1
			local chip = chipAt(used)
			chip.Text = text
			chip.TextColor3 = color
		end
		if shown then
			for _, mission in shown.daily do
				put(`{Missions[mission.id].icon} {progressText(mission)}`, if mission.done then DONE else TEXT)
			end
			if #shown.weekly > 0 then
				local all = shown.weeklyDone >= #shown.weekly
				put(if all then "📆 ✅" else `📆 {shown.weeklyDone}/{#shown.weekly}`, if all then DONE else GOLD)
			end
		end
		-- El contrato: lo que lleva el paso abierto (o ✅/❌ si ya se cerró).
		local step = if contract then contract.steps[math.max(contract.index, 1)] else nil
		if step then
			if step.status == "done" then
				put("📜 ✅", DONE)
			elseif step.status == "failed" then
				put("📜 ❌", FAILED)
			else
				put(`📜 {math.floor(step.progress)}/{step.target}`, GOLD)
			end
		end
		if used > 0 then
			put(if open then "🔼" else "🔽", TEXT)
		end
		for index, chip in chips do
			chip.Visible = index <= used
		end
		-- Plegada, la lista y la tarjeta no se ven (las fichas ya dicen lo cumplido).
		if shown then
			draw(shown, true)
		end
		list.Visible = open and shown ~= nil and list.Visible
		drawCard(contract)
		card.Visible = open and card.Visible
	end

	return {
		missions = function(shown: Shown)
			last = shown
			refresh()
		end,
		contract = function(state: Contract.State?)
			lastContract = state
			refresh()
		end,
	}
end

function MissionTrackerController:Start()
	local player = Players.LocalPlayer
	local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local show = if phone then buildBand(player) else buildPanel(player)
	local function refresh()
		show.missions(read(player))
	end
	local function refreshContract()
		show.contract(Contract.read())
	end
	player:GetAttributeChangedSignal("Retention"):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(Contract.ATTRIBUTE):Connect(refreshContract)
	refresh()
	refreshContract()
end

return MissionTrackerController
