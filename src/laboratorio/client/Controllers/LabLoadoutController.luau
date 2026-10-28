--!strict
-- Selector de arma del Laboratorio (docs/LABORATORIO.md §2 y §3): se lleva 1 de las 4 de Data/LabWeapons.
-- Se abre solo antes de la partida (Waiting y Countdown), en la pausa entre rondas (Intermission) y mientras
-- se espera para reaparecer, y se cierra al empezar el duelo (o la ronda) o al reaparecer. En Todos contra
-- todos la cuenta de listos incluye a todos (no hay bandos). Se puede plegar: queda un botón "Cambiar de arma" bajo la línea de
-- la fase para volver a abrirlo.
--   - Cuatro tarjetas en fila: la imagen voxel del arma con el aspecto de tu bando (Shared/LabWeaponModels,
--     "LabFaction"), su nombre, para qué sirve y sus números (daño, cada cuánto dispara y alcance). La
--     tuya, con el borde dorado (Remotes.LabPickWeapon; el servidor la cambia, LabLoadoutService).
--   - Antes de la partida, "¡Listo!" y cuántos lo están (Remotes.ArenaReady); al morir, cuándo reapareces.
-- Con la ventana abierta el ratón va suelto (FirstPersonController.freeCursor). En una pantalla baja (un
-- teléfono apaisado) las tarjetas son más bajas y sin la descripción, para verlo todo sin desplazarse.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local LabModes = require(ReplicatedStorage.Shared.LabModes)
local LabWeaponModels = require(ReplicatedStorage.Shared.LabWeaponModels)
local LabWeapons = require(ReplicatedStorage.Shared.Data.LabWeapons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardModels = require(ReplicatedStorage.Shared.RewardModels)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local FirstPersonController = require(script.Parent.FirstPersonController)

local T = Strings.t

local WINDOW_COLOR = Color3.fromRGB(25, 20, 15)
local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local PICTURE_COLOR = Color3.fromRGB(32, 28, 24)
local GOLD = Color3.fromRGB(242, 178, 36)
local SECONDARY_TEXT = Color3.fromRGB(210, 200, 185)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
-- La ventana va debajo de la línea de la fase (LabHUDController, que acaba a 34 px).
local TOP = 40
local WIDTH = 0.94
local MAX_WIDTH = 760
local PADDING = 8
local TITLE_HEIGHT = 26
local BOTTOM_HEIGHT = 40
-- Alto de las tarjetas (y de su imagen) en PC y en una pantalla baja.
local COMPACT_BELOW = 500
local CARD_HEIGHT = 190
local PICTURE_HEIGHT = 84
local COMPACT_CARD_HEIGHT = 118
local COMPACT_PICTURE_HEIGHT = 52

local LabLoadoutController = {}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function textLimit(label: TextLabel | TextButton, size: number)
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = label
end

-- Número con la coma decimal en español.
local function decimal(value: number): string
	local text = tostring(value)
	if Strings.language() == "es" then
		text = (string.gsub(text, "%.", ","))
	end
	return text
end

-- El arma, tumbada con la boca a la derecha, en el ViewportFrame.
local function picture(view: ViewportFrame, weaponId: string, faction: LabWeaponModels.Faction)
	local holder = Instance.new("Tool")
	LabWeaponModels.build(holder, weaponId, faction)
	local model = Instance.new("Model")
	for _, part in holder:GetChildren() do
		part.Parent = model
	end
	holder:Destroy()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	model:PivotTo(CFrame.Angles(0, 0, -math.pi / 2) * CFrame.Angles(0, math.pi / 2, 0))
	RewardModels.frame(view, model, 1.5)
end

type Card = { button: TextButton, stroke: UIStroke, view: ViewportFrame, description: TextLabel }

function LabLoadoutController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("LabLoadout", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 8

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0)
	window.Position = UDim2.new(0.5, 0, 0, TOP)
	window.BackgroundColor3 = WINDOW_COLOR
	window.BackgroundTransparency = 0.1
	window.Parent = gui
	corner(window, 14)

	local title = Widgets.label(T("Elige tu arma"), window)
	title.Name = "Title"
	title.Position = UDim2.fromOffset(PADDING + 4, PADDING)
	title.Size = UDim2.new(1, -60, 0, TITLE_HEIGHT)
	title.TextXAlignment = Enum.TextXAlignment.Left
	textLimit(title, 22)

	local fold = Widgets.button("—", window)
	fold.Name = "Fold"
	fold.AnchorPoint = Vector2.new(1, 0)
	fold.Position = UDim2.new(1, -PADDING, 0, PADDING)
	fold.Size = UDim2.fromOffset(40, TITLE_HEIGHT)
	-- Sin el tamaño mínimo de los botones (taparía la primera tarjeta) ni su relleno.
	for _, child in fold:GetChildren() do
		if child:IsA("UISizeConstraint") or child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(PADDING, PADDING * 2 + TITLE_HEIGHT)
	row.Parent = window
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row

	local cards: { [string]: Card } = {}
	for index, weaponId in LabWeapons.ORDER do
		local weapon = LabWeapons.weapons[weaponId]
		local button = Instance.new("TextButton")
		button.Name = weaponId
		button.LayoutOrder = index
		button.Size = UDim2.new(0.25, -5, 1, 0)
		button.BackgroundColor3 = CARD_COLOR
		button.Text = ""
		button.AutoButtonColor = true
		button.Parent = row
		corner(button, 10)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = GOLD
		stroke.Thickness = 3
		stroke.Enabled = false
		stroke.Parent = button
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 2)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = button
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.PaddingLeft = UDim.new(0, 4)
		padding.PaddingRight = UDim.new(0, 4)
		padding.Parent = button

		local view = Instance.new("ViewportFrame")
		view.Name = "Picture"
		view.LayoutOrder = 1
		view.BackgroundColor3 = PICTURE_COLOR
		view.Size = UDim2.new(1, 0, 0, PICTURE_HEIGHT)
		view.Parent = button
		corner(view, 8)
		local name = Widgets.label(T(weapon.name), button)
		name.Name = "WeaponName"
		name.LayoutOrder = 2
		name.Size = UDim2.new(1, 0, 0, 34)
		name.TextWrapped = true
		textLimit(name, 17)
		local description = Widgets.label(T(weapon.description), button)
		description.Name = "Description"
		description.LayoutOrder = 3
		description.Size = UDim2.new(1, 0, 0, 36)
		description.TextWrapped = true
		description.TextColor3 = SECONDARY_TEXT
		textLimit(description, 13)
		local stats = Widgets.label(
			T(
				"Daño {damage} · cada {seconds} s · {range} studs",
				{ damage = weapon.damage, seconds = decimal(weapon.cooldownSeconds), range = weapon.range }
			),
			button
		)
		stats.Name = "Stats"
		stats.LayoutOrder = 4
		stats.Size = UDim2.new(1, 0, 0, 16)
		stats.TextColor3 = GOLD
		textLimit(stats, 13)
		button.Activated:Connect(function()
			Remotes.LabPickWeapon:FireServer(weaponId)
		end)
		cards[weaponId] = { button = button, stroke = stroke, view = view, description = description }
	end

	-- Abajo: "¡Listo!" y cuántos lo están (antes de la partida) o cuándo reapareces.
	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.new(0, PADDING, 1, -PADDING)
	bottom.Size = UDim2.new(1, -PADDING * 2, 0, BOTTOM_HEIGHT)
	bottom.Parent = window
	local ready = Widgets.button(T("✅ ¡Listo!"), bottom)
	ready.Name = "Ready"
	ready.Size = UDim2.fromScale(0.4, 1)
	local status = Widgets.label("", bottom)
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(1, 0)
	status.Position = UDim2.fromScale(1, 0)
	status.Size = UDim2.fromScale(0.58, 1)
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.TextColor3 = SECONDARY_TEXT
	textLimit(status, 18)
	ready.Activated:Connect(function()
		Remotes.ArenaReady:FireServer(player:GetAttribute("ArenaReady") ~= true)
	end)

	-- Botón para volver a abrirla, plegada.
	local reopen = Widgets.button(T("Cambiar de arma"), gui)
	reopen.Name = "Reopen"
	reopen.AnchorPoint = Vector2.new(0.5, 0)
	reopen.Position = UDim2.new(0.5, 0, 0, TOP)
	reopen.Size = UDim2.fromOffset(200, 36)

	local folded = false
	fold.Activated:Connect(function()
		folded = true
	end)
	reopen.Activated:Connect(function()
		folded = false
	end)

	-- Las imágenes, con el aspecto del bando (se rehacen al cambiar de bando).
	local shownFaction: string? = nil
	local function refreshPictures()
		local faction = LabWeaponModels.faction(player:GetAttribute("LabFaction"))
		if faction == shownFaction then
			return
		end
		shownFaction = faction
		for weaponId, card in cards do
			picture(card.view, weaponId, faction)
		end
	end

	-- Tamaño según la pantalla: todo a la vista, sin desplazarse.
	local function layout()
		local screen = gui.AbsoluteSize
		local compact = screen.Y > 0 and screen.Y < COMPACT_BELOW
		local cardHeight = if compact then COMPACT_CARD_HEIGHT else CARD_HEIGHT
		for _, card in cards do
			card.view.Size = UDim2.new(1, 0, 0, if compact then COMPACT_PICTURE_HEIGHT else PICTURE_HEIGHT)
			card.description.Visible = not compact
		end
		row.Size = UDim2.new(1, -PADDING * 2, 0, cardHeight)
		local height = PADDING * 4 + TITLE_HEIGHT + cardHeight + BOTTOM_HEIGHT
		window.Size = UDim2.new(math.min(WIDTH, MAX_WIDTH / math.max(1, screen.X)), 0, 0, height)
	end
	layout()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	local wasOpen: boolean? = nil
	RunService.Heartbeat:Connect(function()
		local phase = Arena.phase()
		local before = phase == "Waiting" or phase == "Countdown" or phase == "Intermission"
		local respawnAt = player:GetAttribute("RespawnAt")
		local dead = Arena.inBattle() and typeof(respawnAt) == "number"
		local wanted = before or dead
		if not wanted then
			-- La próxima vez que haga falta, abierta otra vez.
			folded = false
		end
		local open = wanted and not folded
		window.Visible = open
		reopen.Visible = wanted and folded
		if open ~= wasOpen then
			wasOpen = open
			FirstPersonController.freeCursor("Loadout", open)
		end
		if not open then
			return
		end
		refreshPictures()
		local chosen = player:GetAttribute("LabWeapon")
		for weaponId, card in cards do
			card.stroke.Enabled = weaponId == chosen or (chosen == nil and weaponId == LabWeapons.ORDER[1])
		end
		ready.Visible = phase == "Waiting"
		local isReady = player:GetAttribute("ArenaReady") == true
		ready.Text = if isReady then T("↩️ No estoy listo") else T("✅ ¡Listo!")
		ready.BackgroundColor3 = if isReady then Color3.fromRGB(90, 90, 110) else READY_COLOR
		if dead then
			status.Text = T(
				"Reapareces con ella en {seconds}",
				{ seconds = math.ceil(math.max(0, (respawnAt :: number) - Workspace:GetServerTimeNow())) }
			)
		elseif phase == "Countdown" then
			status.Text = T("⚔️ El duelo empieza en {seconds}", { seconds = math.ceil(Arena.secondsLeft()) })
		elseif phase == "Intermission" then
			local round = ReplicatedStorage:GetAttribute("LabRound")
			status.Text = T("Ronda {round} en {seconds}", {
				round = (if typeof(round) == "number" then round else 0) + 1,
				seconds = math.ceil(Arena.secondsLeft()),
			})
		else
			local freeForAll = LabModes.isFreeForAll()
			local total, readyCount = 0, 0
			for _, other in Players:GetPlayers() do
				if freeForAll or Arena.teamOf(other) then
					total += 1
					if other:GetAttribute("ArenaReady") == true then
						readyCount += 1
					end
				end
			end
			status.Text = T("Listos: {ready} de {total}", { ready = readyCount, total = total })
		end
	end)
end

return LabLoadoutController
