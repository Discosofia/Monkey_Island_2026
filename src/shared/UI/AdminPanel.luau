--!strict
-- Panel de administradores (ServerShared/Admin), en los tres places y también en el juego publicado:
-- un botón "👑 Admin" encima del de Pruebas que despliega una ventana con pestañas (T4):
--   - 👥 Jugadores: los jugadores del servidor con 🛡️ (moderar: silenciar, expulsar, banear, ir hasta él,
--     espiarlo y congelarlo; ServerShared/Moderation), "Dar todo" y "Elegir", que abre al lado el listado
--     de los huevos (por rareza), las mascotas, las monturas y los cosméticos del juego, con buscador,
--     para darle una sola cosa. Arriba, quitar un baneo por nombre de usuario.
--   - 📢 Todos: un anuncio y "Dar a todos" (el mismo listado), en este servidor o en todos.
--   - 🎉 Eventos: eventos en vivo (Data/LiveEvents) ahora o programados, los que están en marcha con
--     ⏹ para pararlos, y lo que se hace al momento en la Isla (Data/IslandActions).
--   - 🖥️ Servidor: mantenimiento con aviso y la lista de servidores (ServerShared/ServerOps).
--   - 📈 Rendimiento: instancias, piezas por categoría, FPS y memoria del servidor y del propio cliente,
--     contra Config.Budgets (ServerShared/Performance). Solo mide mientras está abierta.
--   - 📜 Registro: lo último que han hecho los administradores, en cualquier servidor.
-- Solo sale si el servidor ha marcado al jugador con el atributo "IsAdmin", y el servidor lo vuelve
-- a comprobar al pedirlo.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local Bosses = require(script.Parent.Parent.Data.Bosses)
local Config = require(script.Parent.Parent.Config)
local Cosmetics = require(script.Parent.Parent.Data.Cosmetics)
local IslandActions = require(script.Parent.Parent.Data.IslandActions)
local LiveEventCatalog = require(script.Parent.Parent.Data.LiveEvents)
local LiveEvents = require(script.Parent.Parent.LiveEvents)
local Mounts = require(script.Parent.Parent.Data.Mounts)
local Pets = require(script.Parent.Parent.Data.Pets)
local Rarities = require(script.Parent.Parent.Data.Rarities)
local Remotes = require(script.Parent.Parent.Remotes)
local Rewards = require(script.Parent.Parent.Rewards)
local Widgets = require(script.Parent.Widgets)

local WOOD = Color3.fromRGB(25, 20, 15)
local ROW = Color3.fromRGB(45, 38, 30)
local GOLD = Color3.fromRGB(242, 178, 36)
local GOLD_TEXT = Color3.fromRGB(40, 25, 5)
local TITLE = Color3.fromRGB(255, 220, 150)
local SECONDARY = Color3.fromRGB(190, 180, 160)
local CLOSE = Color3.fromRGB(150, 60, 50)
local ACTIVE = Color3.fromRGB(50, 120, 190)

-- Segundos que espera el segundo toque de "Dar" cuando es para todos.
local CONFIRM_SECONDS = 3

type Scope = "Server" | "All"
type Target = { kind: "Player", userId: number, name: string } | { kind: "Everyone", scope: Scope }

local SCOPE_TEXT = { Server = "este servidor", All = "todos los servidores" }

local AdminPanel = {}

local function corner(parent: GuiObject, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

-- Botón dorado pequeño (filas y pestañas del panel; Widgets.button tiene un mínimo de 160 px).
local function smallButton(text: string, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = GOLD
	button.TextColor3 = GOLD_TEXT
	button.Font = Enum.Font.BuilderSansBold
	button.TextScaled = true
	button.Text = text
	button.Parent = parent
	corner(button, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = button
	-- Mismo tope en todos, para que un texto corto no salga más grande que el de al lado.
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 18
	textLimit.Parent = button
	return button
end

local function list(parent: Instance, padding: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

local function scroller(parent: Instance): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.Parent = parent
	return frame
end

local function ago(t: number): string
	local seconds = os.time() - t
	if seconds < 60 then
		return "ahora"
	elseif seconds < 3600 then
		return `hace {seconds // 60} min`
	elseif seconds < 86400 then
		return `hace {seconds // 3600} h`
	end
	return os.date("%d-%m %H:%M", t)
end

-- Todo lo que se puede elegir: todo junto, los huevos (una rareza cada uno), las mascotas, las
-- monturas y los cosméticos, en este orden.
type Entry = {
	kind: "All" | "Egg" | "Pet" | "Mount" | "Cosmetic",
	id: string,
	title: string,
	info: string,
	rarity: string,
}

local function byRarity(a: string, b: string): boolean
	return (Rarities[a] or Rarities.Common).order < (Rarities[b] or Rarities.Common).order
end

local function catalog(): { Entry }
	local entries: { Entry } = {
		{
			kind = "All",
			id = "All",
			title = "🔓 Todo",
			info = "Cosméticos, emotes, mascotas y monturas",
			rarity = "Legendary",
		},
	}

	-- Huevos: las rarezas con tiempo de eclosión (el Mítico no sale de los huevos).
	local eggRarities = {}
	for rarityId in Config.Egg.HatchHours :: any do
		table.insert(eggRarities, rarityId :: string)
	end
	table.sort(eggRarities, byRarity)
	for _, rarityId in eggRarities do
		local name = Rarities[rarityId].name
		table.insert(
			entries,
			{ kind = "Egg", id = rarityId, title = `🥚 Huevo {name}`, info = `Huevo · {name}`, rarity = rarityId }
		)
	end

	-- Mascotas y monturas: por rareza y después por nombre.
	local function sorted(data: { [string]: any }): { string }
		local ids = {}
		for id in data do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			if data[a].rarity ~= data[b].rarity then
				return byRarity(data[a].rarity, data[b].rarity)
			end
			return data[a].name < data[b].name
		end)
		return ids
	end
	for _, petId in sorted(Pets) do
		local pet = Pets[petId]
		local rarityName = (Rarities[pet.rarity] or Rarities.Common).name
		table.insert(entries, {
			kind = "Pet",
			id = petId,
			title = `{pet.icon} {pet.name}`,
			info = `Mascota · {pet.kind} · {rarityName}`,
			rarity = pet.rarity,
		})
	end
	for _, mountId in sorted(Mounts) do
		local mount = Mounts[mountId]
		local rarityName = (Rarities[mount.rarity] or Rarities.Common).name
		table.insert(entries, {
			kind = "Mount",
			id = mountId,
			title = `{mount.icon} {mount.name}`,
			info = `Montura · {rarityName}`,
			rarity = mount.rarity,
		})
	end

	-- Cosméticos: por tipo y después en el orden del Armario.
	local cosmeticIds = {}
	for cosmeticId in Cosmetics do
		table.insert(cosmeticIds, cosmeticId)
	end
	table.sort(cosmeticIds, function(a, b)
		local ca, cb = Cosmetics[a], Cosmetics[b]
		if ca.kind ~= cb.kind then
			return Rewards.kindName(ca.kind) < Rewards.kindName(cb.kind)
		end
		if ca.order ~= cb.order then
			return ca.order < cb.order
		end
		return a < b
	end)
	for _, cosmeticId in cosmeticIds do
		local cosmetic = Cosmetics[cosmeticId]
		local rarityName = (Rarities[cosmetic.rarity] or Rarities.Common).name
		table.insert(entries, {
			kind = "Cosmetic",
			id = cosmeticId,
			title = `{cosmetic.icon} {cosmetic.name}`,
			info = `{Rewards.kindName(cosmetic.kind)} · {rarityName}`,
			rarity = cosmetic.rarity,
		})
	end
	return entries
end

local function build(place: "Island" | "Lobby" | "Dunas" | "Laboratorio")
	local player = Players.LocalPlayer
	local gui = Widgets.screen("AdminPanel", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 21

	-- En el mismo lado que el panel de pruebas (Shared/UI/DebugPanel), justo encima.
	local side = if place == "Lobby" then 0.98 else 0.02
	local anchorX = if place == "Lobby" then 1 else 0
	local bottom = if place == "Island" then 0.83 else 0.91
	local toggle = Widgets.button("👑 Admin", gui)
	toggle.AnchorPoint = Vector2.new(anchorX, 1)
	toggle.Position = UDim2.fromScale(side, bottom)
	toggle.Size = UDim2.fromScale(0.12, 0.055)

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(anchorX, 1)
	window.Position = UDim2.fromScale(side, bottom - 0.07)
	window.Size = UDim2.fromScale(0.3, 0.62)
	window.BackgroundColor3 = WOOD
	window.BackgroundTransparency = 0.1
	window.BorderSizePixel = 0
	window.Active = true
	window.Visible = false
	window.Parent = gui
	corner(window, 12)
	local windowLimit = Instance.new("UISizeConstraint")
	windowLimit.MinSize = Vector2.new(340, 280)
	windowLimit.MaxSize = Vector2.new(480, 580)
	windowLimit.Parent = window

	-- Pestañas: la elegida en dorado, como las de Misiones del Lobby.
	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.Position = UDim2.fromOffset(6, 6)
	tabBar.Size = UDim2.new(1, -12, 0, 34)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = window
	local tabLayout = list(tabBar, 4)
	tabLayout.FillDirection = Enum.FillDirection.Horizontal

	local pages = Instance.new("Frame")
	pages.Name = "Pages"
	pages.Position = UDim2.fromOffset(6, 46)
	pages.Size = UDim2.new(1, -12, 1, -52)
	pages.BackgroundTransparency = 1
	pages.Parent = window

	-- Listado de lo que se puede dar, al lado de la ventana (hacia el centro de la pantalla).
	local picker = Instance.new("Frame")
	picker.Name = "Picker"
	picker.AnchorPoint = Vector2.new(anchorX, 1)
	picker.Position = UDim2.fromScale(if place == "Lobby" then side - 0.31 else side + 0.31, bottom - 0.07)
	picker.Size = UDim2.fromScale(0.3, 0.62)
	picker.BackgroundColor3 = WOOD
	picker.BackgroundTransparency = 0.1
	picker.BorderSizePixel = 0
	picker.Active = true
	picker.Visible = false
	picker.Parent = gui
	corner(picker, 12)
	local pickerTitle = Widgets.label("", picker)
	pickerTitle.Position = UDim2.fromOffset(8, 4)
	pickerTitle.Size = UDim2.new(1, -52, 0, 26)
	pickerTitle.TextColor3 = TITLE
	pickerTitle.TextXAlignment = Enum.TextXAlignment.Left
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -4, 0, 4)
	close.Size = UDim2.fromOffset(36, 28)
	close.BackgroundColor3 = CLOSE
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.BuilderSansExtraBold
	close.TextScaled = true
	close.Text = "X"
	close.Parent = picker
	corner(close, 8)
	local search = Instance.new("TextBox")
	search.Position = UDim2.fromOffset(6, 36)
	search.Size = UDim2.new(1, -12, 0, 30)
	search.BackgroundColor3 = ROW
	search.BorderSizePixel = 0
	search.TextColor3 = Color3.new(1, 1, 1)
	search.PlaceholderText = "🔍 Buscar (nombre, huevo, mascota, montura, tipo o rareza)"
	search.PlaceholderColor3 = Color3.fromRGB(160, 150, 130)
	search.Font = Enum.Font.BuilderSans
	search.TextSize = 18
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.ClearTextOnFocus = false
	search.Text = ""
	search.Parent = picker
	corner(search, 8)
	local items = scroller(picker)
	items.Position = UDim2.fromOffset(6, 72)
	items.Size = UDim2.new(1, -12, 1, -78)
	list(items, 3)

	-- A quién va lo que se pulse en el listado.
	local target: Target? = nil
	-- Botón "Dar" que espera el segundo toque (para todos) y hasta cuándo.
	local armed: TextButton? = nil
	local armedUntil = 0

	local function give(entry: Entry, button: TextButton)
		local current = target
		if not current then
			return
		end
		if current.kind == "Player" then
			if entry.kind == "All" then
				Remotes.AdminGiveAll:FireServer(current.userId)
			else
				Remotes.AdminGive:FireServer(current.userId, entry.kind, entry.id)
			end
			return
		end
		-- Para todos, un segundo toque: llega a muchos perfiles y no se puede deshacer.
		if armed ~= button or os.clock() > armedUntil then
			if armed then
				armed.Text = "🎁 Dar"
			end
			armed = button
			armedUntil = os.clock() + CONFIRM_SECONDS
			button.Text = "¿A todos?"
			task.delay(CONFIRM_SECONDS, function()
				if armed == button and os.clock() >= armedUntil then
					button.Text = "🎁 Dar"
					armed = nil
				end
			end)
			return
		end
		armed = nil
		button.Text = "🎁 Dar"
		Remotes.AdminGiveEveryone:FireServer(entry.kind, entry.id, current.scope)
	end

	-- Una fila por cosa. Se hacen una vez: el buscador solo las esconde.
	local searchable: { [Frame]: string } = {}
	for index, entry in catalog() do
		local rarity = Rarities[entry.rarity] or Rarities.Common
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 36)
		row.BackgroundColor3 = ROW
		row.BorderSizePixel = 0
		row.Parent = items
		corner(row, 8)
		local name = Widgets.label(entry.title, row)
		name.Position = UDim2.fromOffset(6, 1)
		name.Size = UDim2.new(0.72, -6, 0.6, 0)
		name.TextColor3 = rarity.color
		name.TextXAlignment = Enum.TextXAlignment.Left
		local info = Widgets.label(entry.info, row)
		info.Position = UDim2.new(0, 6, 0.6, 0)
		info.Size = UDim2.new(0.72, -6, 0.4, -1)
		info.TextColor3 = SECONDARY
		info.Font = Enum.Font.BuilderSans
		info.TextXAlignment = Enum.TextXAlignment.Left
		local button = smallButton("🎁 Dar", row)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -4, 0.5, 0)
		button.Size = UDim2.new(0.28, -6, 1, -8)
		button.MouseButton1Click:Connect(function()
			give(entry, button)
		end)
		searchable[row] = string.lower(`{entry.id} {entry.title} {entry.info}`)
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		local query = string.lower(search.Text)
		for row, text in searchable do
			row.Visible = string.find(text, query, 1, true) ~= nil
		end
	end)

	local function openPicker(newTarget: Target)
		target = newTarget
		pickerTitle.Text = if newTarget.kind == "Player"
			then `Dar a {newTarget.name}`
			else `Dar a todos · {SCOPE_TEXT[newTarget.scope]}`
		picker.Visible = true
	end
	close.MouseButton1Click:Connect(function()
		picker.Visible = false
	end)

	-- Ventana de moderación de un jugador, en el mismo sitio que el listado (se ve una de las dos):
	-- motivo, silenciar, expulsar y banear (estos dos con segundo toque), ir hasta él, espiarlo y
	-- congelarlo. Lo comprueba y lo hace ServerShared/Moderation.
	local moderate = Instance.new("Frame")
	moderate.Name = "Moderate"
	moderate.AnchorPoint = picker.AnchorPoint
	moderate.Position = picker.Position
	moderate.Size = picker.Size
	moderate.BackgroundColor3 = WOOD
	moderate.BackgroundTransparency = 0.1
	moderate.BorderSizePixel = 0
	moderate.Active = true
	moderate.Visible = false
	moderate.Parent = gui
	corner(moderate, 12)
	local moderateLimit = Instance.new("UISizeConstraint")
	moderateLimit.MinSize = Vector2.new(340, 280)
	moderateLimit.MaxSize = Vector2.new(480, 580)
	moderateLimit.Parent = moderate
	local moderateTitle = Widgets.label("", moderate)
	moderateTitle.Position = UDim2.fromOffset(8, 4)
	moderateTitle.Size = UDim2.new(1, -52, 0, 26)
	moderateTitle.TextColor3 = TITLE
	moderateTitle.TextXAlignment = Enum.TextXAlignment.Left
	local moderateClose = close:Clone()
	moderateClose.Parent = moderate
	-- Dos pestañas: 🛡️ Moderar (ServerShared/Moderation) y 📋 Perfil (ServerShared/AdminProfile). De
	-- alguien que no está en el servidor (abierto por nombre) solo el perfil.
	local sideTabs = Instance.new("Frame")
	sideTabs.Name = "SideTabs"
	sideTabs.Position = UDim2.fromOffset(6, 36)
	sideTabs.Size = UDim2.new(1, -12, 0, 30)
	sideTabs.BackgroundTransparency = 1
	sideTabs.Parent = moderate
	local sideLayout = list(sideTabs, 4)
	sideLayout.FillDirection = Enum.FillDirection.Horizontal
	local moderateTab = smallButton("🛡️ Moderar", sideTabs)
	moderateTab.Name = "ModerateTab"
	moderateTab.LayoutOrder = 1
	moderateTab.Size = UDim2.new(0.5, -2, 1, 0)
	local profileTab = smallButton("📋 Perfil", sideTabs)
	profileTab.Name = "ProfileTab"
	profileTab.LayoutOrder = 2
	profileTab.Size = UDim2.new(0.5, -2, 1, 0)

	local moderateBody = scroller(moderate)
	moderateBody.Position = UDim2.fromOffset(6, 72)
	moderateBody.Size = UDim2.new(1, -12, 1, -78)
	list(moderateBody, 6)
	local profileBody = scroller(moderate)
	profileBody.Name = "Profile"
	profileBody.Position = moderateBody.Position
	profileBody.Size = moderateBody.Size
	profileBody.Visible = false
	list(profileBody, 4)

	local moderated: { userId: number, name: string }? = nil
	-- A quién espía la cámara (nil: a ti).
	local spying: Player? = nil
	local spyButton: TextButton

	local function stopSpying()
		spying = nil
		local camera = Workspace.CurrentCamera
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if camera and humanoid then
			camera.CameraSubject = humanoid
		end
		spyButton.Text = "👁 Espiar"
	end

	local function moderateHeading(text: string, order: number)
		local label = Widgets.label(text, moderateBody)
		label.LayoutOrder = order
		label.Size = UDim2.new(1, -8, 0, 22)
		label.TextColor3 = TITLE
		label.TextXAlignment = Enum.TextXAlignment.Left
	end
	local function buttonRow(name: string, order: number, texts: { string }, parent: Instance?): { TextButton }
		local row = Instance.new("Frame")
		row.Name = name
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 36)
		row.BackgroundTransparency = 1
		row.Parent = parent or moderateBody
		local layout = list(row, 4)
		layout.FillDirection = Enum.FillDirection.Horizontal
		local buttons = {}
		for index, text in texts do
			local button = smallButton(text, row)
			button.Name = `B{index}`
			button.LayoutOrder = index
			button.Size = UDim2.new(1 / #texts, -4, 1, 0)
			table.insert(buttons, button)
		end
		return buttons
	end

	-- Expulsar y banear piden un segundo toque.
	local armedModeration: TextButton? = nil
	local armedModerationUntil = 0
	local function twoTaps(button: TextButton, text: string): boolean
		if armedModeration == button and os.clock() <= armedModerationUntil then
			armedModeration = nil
			button.Text = text
			return true
		end
		if armedModeration then
			armedModeration.Text = armedModeration:GetAttribute("Label") :: string
		end
		armedModeration = button
		armedModerationUntil = os.clock() + CONFIRM_SECONDS
		button.Text = "¿Seguro?"
		task.delay(CONFIRM_SECONDS, function()
			if armedModeration == button and os.clock() >= armedModerationUntil then
				button.Text = text
				armedModeration = nil
			end
		end)
		return false
	end

	local function send(action: string, a: any?, b: any?)
		local current = moderated
		if current then
			Remotes.AdminModerate:FireServer(action, current.userId, a, b)
		end
	end

	moderateHeading("Motivo (expulsar y banear)", 1)
	local reason = Instance.new("TextBox")
	reason.Name = "Reason"
	reason.LayoutOrder = 2
	reason.Size = UDim2.new(1, -8, 0, 32)
	reason.BackgroundColor3 = ROW
	reason.BorderSizePixel = 0
	reason.TextColor3 = Color3.new(1, 1, 1)
	reason.PlaceholderText = "Ej.: insultos en el chat"
	reason.PlaceholderColor3 = Color3.fromRGB(160, 150, 130)
	reason.Font = Enum.Font.BuilderSans
	reason.TextSize = 18
	reason.TextXAlignment = Enum.TextXAlignment.Left
	reason.ClearTextOnFocus = false
	reason.Text = ""
	reason.Parent = moderateBody
	corner(reason, 8)
	local reasonPadding = Instance.new("UIPadding")
	reasonPadding.PaddingLeft = UDim.new(0, 6)
	reasonPadding.Parent = reason
	reason:GetPropertyChangedSignal("Text"):Connect(function()
		if #reason.Text > Config.AdminTools.ReasonMaxLength then
			reason.Text = string.sub(reason.Text, 1, Config.AdminTools.ReasonMaxLength)
		end
	end)

	moderateHeading("🔇 Silenciar el chat", 3)
	local muteTexts = {}
	for _, minutes in Config.AdminTools.MuteMinutes do
		table.insert(muteTexts, `{minutes} min`)
	end
	table.insert(muteTexts, "🔊 Quitar")
	local muteButtons = buttonRow("Mute", 4, muteTexts)
	for index, button in muteButtons do
		local minutes = Config.AdminTools.MuteMinutes[index]
		button.MouseButton1Click:Connect(function()
			if minutes then
				send("Mute", minutes)
			else
				send("Unmute")
			end
		end)
	end

	moderateHeading("⛔ Banear de toda la experiencia (pide un segundo toque)", 5)
	local banTexts = {}
	for _, hours in Config.AdminTools.BanHours do
		table.insert(banTexts, if hours < 24 then `{hours} h` else `{hours // 24} d`)
	end
	for index, button in buttonRow("Ban", 6, banTexts) do
		local hours = Config.AdminTools.BanHours[index]
		button:SetAttribute("Label", button.Text)
		button.BackgroundColor3 = CLOSE
		button.TextColor3 = Color3.new(1, 1, 1)
		button.MouseButton1Click:Connect(function()
			if twoTaps(button, banTexts[index]) then
				send("Ban", hours, reason.Text)
			end
		end)
	end

	moderateHeading("Otras", 7)
	local others = buttonRow("Other", 8, { "👢 Expulsar", "📍 Ir hasta", "👁 Espiar" })
	local kick = others[1]
	kick:SetAttribute("Label", kick.Text)
	kick.BackgroundColor3 = CLOSE
	kick.TextColor3 = Color3.new(1, 1, 1)
	kick.MouseButton1Click:Connect(function()
		if twoTaps(kick, "👢 Expulsar") then
			send("Kick", reason.Text)
		end
	end)
	others[2].MouseButton1Click:Connect(function()
		send("Goto")
	end)
	spyButton = others[3]
	spyButton.MouseButton1Click:Connect(function()
		local current = moderated
		if spying or not current then
			stopSpying()
			return
		end
		local other = Players:GetPlayerByUserId(current.userId)
		local character = if other then other.Character else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local camera = Workspace.CurrentCamera
		if other and humanoid and camera then
			spying = other
			camera.CameraSubject = humanoid
			spyButton.Text = "👁 Dejar de espiar"
		end
	end)
	local freezeButtons = buttonRow("Freeze", 9, { "❄️ Congelar", "🔥 Descongelar" })
	freezeButtons[1].MouseButton1Click:Connect(function()
		send("Freeze")
	end)
	freezeButtons[2].MouseButton1Click:Connect(function()
		send("Unfreeze")
	end)

	-- De quién es la pestaña 📋 Perfil: su UserId (en el servidor) o su nombre de usuario (fuera).
	local profileWho: (number | string)? = nil
	local function requestProfile(action: string, a: any?, b: any?)
		if profileWho then
			Remotes.AdminProfile:FireServer(action, profileWho, a, b)
		end
	end
	local function profileLabel(text: string, order: number, color: Color3?)
		local label = Widgets.label(text, profileBody)
		label.LayoutOrder = order
		label.Size = UDim2.new(1, -8, 0, 20)
		label.TextColor3 = color or Color3.new(1, 1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 16
		limit.Parent = label
	end
	-- Fila con un texto y un botón (copias para restaurar, cosas para quitar), de segundo toque.
	local function profileRow(order: number, text: string, color: Color3, button: string, action: () -> ())
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 30)
		row.BackgroundColor3 = ROW
		row.BorderSizePixel = 0
		row.Parent = profileBody
		corner(row, 8)
		local label = Widgets.label(text, row)
		label.Position = UDim2.fromOffset(6, 0)
		label.Size = UDim2.new(0.72, -6, 1, 0)
		label.TextColor3 = color
		label.TextXAlignment = Enum.TextXAlignment.Left
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 16
		limit.Parent = label
		local go = smallButton(button, row)
		go.Name = "Go"
		go.AnchorPoint = Vector2.new(1, 0.5)
		go.Position = UDim2.new(1, -3, 0.5, 0)
		go.Size = UDim2.new(0.28, -3, 1, -6)
		go.BackgroundColor3 = CLOSE
		go.TextColor3 = Color3.new(1, 1, 1)
		go:SetAttribute("Label", button)
		go.MouseButton1Click:Connect(function()
			if twoTaps(go, button) then
				action()
			end
		end)
	end

	Remotes.AdminProfile.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		for _, child in profileBody:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if data.missing then
			profileLabel(`No hay perfil guardado de {tostring(data.name)}`, 1, SECONDARY)
			return
		end
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		for _, line in data.lines or {} do
			profileLabel(tostring(line), nextOrder())
		end
		local online = data.online == true
		local actions =
			buttonRow("Actions", nextOrder(), { "📦 Hacer copia", "📅 Calendario", "🎯 Misiones" }, profileBody)
		actions[1].MouseButton1Click:Connect(function()
			requestProfile("Backup")
		end)
		for index, what in { "Calendar", "Missions" } do
			local button = actions[index + 1]
			local text = button.Text
			button:SetAttribute("Label", text)
			if not online then
				button.BackgroundColor3 = ROW
				button.TextColor3 = SECONDARY
				button.AutoButtonColor = false
				continue
			end
			button.MouseButton1Click:Connect(function()
				if twoTaps(button, text) then
					requestProfile("Reset", what)
				end
			end)
		end
		profileLabel("📥 Copias de seguridad (restaurar pide un segundo toque)", nextOrder(), TITLE)
		if #(data.backups or {}) == 0 then
			profileLabel("Ninguna", nextOrder(), SECONDARY)
		end
		for _, backup in data.backups or {} do
			local key = backup.key
			profileRow(nextOrder(), tostring(backup.label), SECONDARY, "📥 Restaurar", function()
				requestProfile("Restore", key)
			end)
		end
		if online then
			profileLabel("🗑️ Quitar (pide un segundo toque)", nextOrder(), TITLE)
			for _, item in data.items or {} do
				local rarity = Rarities[item.rarity] or Rarities.Common
				local kind, id = item.kind, item.id
				profileRow(nextOrder(), tostring(item.label), rarity.color, "🗑️ Quitar", function()
					requestProfile("Remove", kind, id)
				end)
			end
		end
	end)

	local function showSide(which: "Moderate" | "Profile")
		moderateBody.Visible = which == "Moderate"
		profileBody.Visible = which == "Profile"
		for _, pair in { { moderateTab, "Moderate" }, { profileTab, "Profile" } } do
			local button, id = pair[1] :: TextButton, pair[2]
			button.BackgroundColor3 = if id == which then GOLD else ROW
			button.TextColor3 = if id == which then GOLD_TEXT else Color3.new(1, 1, 1)
		end
		if which == "Profile" then
			requestProfile("View")
		end
	end
	moderateTab.MouseButton1Click:Connect(function()
		if moderated then
			showSide("Moderate")
		end
	end)
	profileTab.MouseButton1Click:Connect(function()
		showSide("Profile")
	end)

	local function openModerate(userId: number, name: string)
		if spying then
			stopSpying()
		end
		moderated = { userId = userId, name = name }
		profileWho = userId
		moderateTitle.Text = `🛡️ {name}`
		moderateTab.Visible = true
		picker.Visible = false
		moderate.Visible = true
		showSide("Moderate")
	end
	-- Perfil de alguien por su nombre de usuario (puede no estar en el servidor).
	local function openProfileByName(name: string)
		if spying then
			stopSpying()
		end
		moderated = nil
		profileWho = name
		moderateTitle.Text = `📋 @{name}`
		moderateTab.Visible = false
		picker.Visible = false
		moderate.Visible = true
		showSide("Profile")
	end
	local function closeModerate()
		moderate.Visible = false
		moderated = nil
		profileWho = nil
		if spying then
			stopSpying()
		end
	end
	moderateClose.MouseButton1Click:Connect(closeModerate)
	-- Abrir el listado cierra la moderación (y al revés, en openModerate).
	picker:GetPropertyChangedSignal("Visible"):Connect(function()
		if picker.Visible and moderate.Visible then
			closeModerate()
		end
	end)

	-- Página 👥 Jugadores: quitar un baneo por nombre y una fila por jugador del servidor (tú el
	-- primero) con 🛡️, "Elegir" y "Dar todo".
	local playersPage = scroller(pages)
	playersPage.Name = "Players"
	playersPage.Size = UDim2.fromScale(1, 1)
	list(playersPage, 4)

	-- Por nombre de usuario (alguien que puede no estar en el servidor): ver su perfil o quitarle el baneo.
	local unbanRow = Instance.new("Frame")
	unbanRow.Name = "Unban"
	unbanRow.LayoutOrder = -1
	unbanRow.Size = UDim2.new(1, -8, 0, 32)
	unbanRow.BackgroundTransparency = 1
	unbanRow.Parent = playersPage
	local unbanName = Instance.new("TextBox")
	unbanName.Name = "Name"
	unbanName.Size = UDim2.new(0.42, -4, 1, 0)
	unbanName.BackgroundColor3 = ROW
	unbanName.BorderSizePixel = 0
	unbanName.TextColor3 = Color3.new(1, 1, 1)
	unbanName.PlaceholderText = "Usuario (sin @)"
	unbanName.PlaceholderColor3 = Color3.fromRGB(160, 150, 130)
	unbanName.Font = Enum.Font.BuilderSans
	unbanName.TextSize = 17
	unbanName.TextXAlignment = Enum.TextXAlignment.Left
	unbanName.ClearTextOnFocus = false
	unbanName.Text = ""
	unbanName.Parent = unbanRow
	corner(unbanName, 8)
	local unbanPadding = Instance.new("UIPadding")
	unbanPadding.PaddingLeft = UDim.new(0, 6)
	unbanPadding.Parent = unbanName
	local unbanButton = smallButton("✅ Quitar baneo", unbanRow)
	unbanButton.Name = "Go"
	unbanButton.AnchorPoint = Vector2.new(1, 0)
	unbanButton.Position = UDim2.fromScale(1, 0)
	unbanButton.Size = UDim2.fromScale(0.34, 1)
	local profileButton = smallButton("📋 Perfil", unbanRow)
	profileButton.Name = "Profile"
	profileButton.Position = UDim2.fromScale(0.42, 0)
	profileButton.Size = UDim2.new(0.24, -4, 1, 0)
	profileButton.MouseButton1Click:Connect(function()
		local name = string.gsub(unbanName.Text, "[@%s]", "")
		if name ~= "" then
			openProfileByName(name)
		end
	end)
	unbanButton.MouseButton1Click:Connect(function()
		local name = string.gsub(unbanName.Text, "[@%s]", "")
		if name ~= "" then
			Remotes.AdminModerate:FireServer("Unban", name)
			unbanName.Text = ""
		end
	end)

	local function renderPlayers()
		for _, child in playersPage:GetChildren() do
			if (child:IsA("Frame") and child ~= unbanRow) or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local title = Widgets.label("🛡️ moderar · 🎁 elegir qué dar · 🔓 dar todo", playersPage)
		title.LayoutOrder = 0
		title.Size = UDim2.new(1, -8, 0, 24)
		title.TextColor3 = TITLE
		local players = Players:GetPlayers()
		table.sort(players, function(a, b)
			if a == player or b == player then
				return a == player
			end
			return a.Name:lower() < b.Name:lower()
		end)
		for index, other in players do
			local row = Instance.new("Frame")
			row.Name = `P{index}`
			row.LayoutOrder = index
			row.Size = UDim2.new(1, -8, 0, 40)
			row.BackgroundColor3 = ROW
			row.BorderSizePixel = 0
			row.Parent = playersPage
			corner(row, 8)
			local name = Widgets.label(`{other.DisplayName} (@{other.Name})`, row)
			name.Position = UDim2.fromOffset(6, 0)
			name.Size = UDim2.new(0.4, -6, 1, 0)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local userId, displayName = other.UserId, other.DisplayName
			local function rowButton(text: string, buttonName: string, right: number, width: number): TextButton
				local button = smallButton(text, row)
				button.Name = buttonName
				button.AnchorPoint = Vector2.new(1, 0.5)
				button.Position = UDim2.new(1 - right, -4, 0.5, 0)
				button.Size = UDim2.new(width, -6, 1, -8)
				return button
			end
			rowButton("🔓 Dar todo", "GiveAll", 0, 0.24).MouseButton1Click:Connect(function()
				Remotes.AdminGiveAll:FireServer(userId)
			end)
			rowButton("🎁 Elegir", "Choose", 0.24, 0.22).MouseButton1Click:Connect(function()
				openPicker({ kind = "Player", userId = userId, name = displayName })
			end)
			local shield = rowButton("🛡️", "Moderate", 0.46, 0.14)
			shield.BackgroundColor3 = CLOSE
			shield.TextColor3 = Color3.new(1, 1, 1)
			shield.MouseButton1Click:Connect(function()
				openModerate(userId, displayName)
			end)
		end
	end

	-- Página 📢 Todos: anuncio y "Dar a todos", en este servidor o en todos.
	local everyonePage = Instance.new("Frame")
	everyonePage.Name = "Everyone"
	everyonePage.Size = UDim2.fromScale(1, 1)
	everyonePage.BackgroundTransparency = 1
	everyonePage.Parent = pages
	list(everyonePage, 6)

	local function heading(text: string, order: number)
		local label = Widgets.label(text, everyonePage)
		label.LayoutOrder = order
		label.Size = UDim2.new(1, 0, 0, 24)
		label.TextColor3 = TITLE
		label.TextXAlignment = Enum.TextXAlignment.Left
	end
	local function pair(name: string, order: number, left: string, right: string): (TextButton, TextButton)
		local row = Instance.new("Frame")
		row.Name = name
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 40)
		row.BackgroundTransparency = 1
		row.Parent = everyonePage
		local a = smallButton(left, row)
		a.Size = UDim2.new(0.5, -3, 1, 0)
		local b = smallButton(right, row)
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.fromScale(1, 0)
		b.Size = UDim2.new(0.5, -3, 1, 0)
		return a, b
	end

	heading("📢 Anuncio", 1)
	local message = Instance.new("TextBox")
	message.Name = "Message"
	message.LayoutOrder = 2
	message.Size = UDim2.new(1, 0, 0, 64)
	message.BackgroundColor3 = ROW
	message.BorderSizePixel = 0
	message.TextColor3 = Color3.new(1, 1, 1)
	message.PlaceholderText = `Escribe el anuncio (hasta {Config.AdminTools.AnnounceMaxLength} letras)`
	message.PlaceholderColor3 = Color3.fromRGB(160, 150, 130)
	message.Font = Enum.Font.BuilderSans
	message.TextSize = 18
	message.TextWrapped = true
	message.MultiLine = true
	message.TextXAlignment = Enum.TextXAlignment.Left
	message.TextYAlignment = Enum.TextYAlignment.Top
	message.ClearTextOnFocus = false
	message.Text = ""
	message.Parent = everyonePage
	corner(message, 8)
	local messagePadding = Instance.new("UIPadding")
	messagePadding.PaddingLeft = UDim.new(0, 6)
	messagePadding.PaddingTop = UDim.new(0, 4)
	messagePadding.Parent = message
	message:GetPropertyChangedSignal("Text"):Connect(function()
		if #message.Text > Config.AdminTools.AnnounceMaxLength then
			message.Text = string.sub(message.Text, 1, Config.AdminTools.AnnounceMaxLength)
		end
	end)
	local announceHere, announceAll = pair("AnnounceRow", 3, "📢 Este servidor", "🌍 Todos los servidores")
	announceHere.Name = "AnnounceServer"
	announceAll.Name = "AnnounceAll"
	local function announce(scope: Scope)
		if message.Text ~= "" then
			Remotes.AdminAnnounce:FireServer(message.Text, scope)
			message.Text = ""
		end
	end
	announceHere.MouseButton1Click:Connect(function()
		announce("Server")
	end)
	announceAll.MouseButton1Click:Connect(function()
		announce("All")
	end)

	heading("🎁 Dar a todos", 4)
	local giveHere, giveAllServers = pair("GiveRow", 5, "🎁 Elegir · este servidor", "🌍 Elegir · todos")
	giveHere.Name = "GiveServer"
	giveAllServers.Name = "GiveAll"
	giveHere.MouseButton1Click:Connect(function()
		openPicker({ kind = "Everyone", scope = "Server" })
	end)
	giveAllServers.MouseButton1Click:Connect(function()
		openPicker({ kind = "Everyone", scope = "All" })
	end)
	local note = Widgets.label("Llega a quien esté conectado ahora. Pide un segundo toque en «Dar».", everyonePage)
	note.LayoutOrder = 6
	note.Size = UDim2.new(1, 0, 0, 20)
	note.TextColor3 = SECONDARY
	note.Font = Enum.Font.BuilderSans
	note.TextXAlignment = Enum.TextXAlignment.Left

	-- Página 📜 Registro: lo último de los administradores (lo pide al abrirla y con 🔄).
	local logPage = Instance.new("Frame")
	logPage.Name = "Log"
	logPage.Size = UDim2.fromScale(1, 1)
	logPage.BackgroundTransparency = 1
	logPage.Parent = pages
	local refresh = smallButton("🔄 Actualizar", logPage)
	refresh.Name = "Refresh"
	refresh.Size = UDim2.new(0.4, 0, 0, 32)
	local logList = scroller(logPage)
	logList.Position = UDim2.fromOffset(0, 38)
	logList.Size = UDim2.new(1, 0, 1, -38)
	list(logList, 3)
	local function requestLog()
		Remotes.AdminLog:FireServer()
	end
	refresh.MouseButton1Click:Connect(requestLog)
	Remotes.AdminLog.OnClientEvent:Connect(function(entries: any)
		for _, child in logList:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		if typeof(entries) ~= "table" or #entries == 0 then
			local empty = Widgets.label("Aún no hay nada en el registro", logList)
			empty.Size = UDim2.new(1, -8, 0, 24)
			empty.TextColor3 = SECONDARY
			return
		end
		for index, entry in entries do
			local row = Instance.new("Frame")
			row.LayoutOrder = index
			-- Alto según el texto: un anuncio largo se parte en líneas en vez de encogerse.
			row.Size = UDim2.new(1, -8, 0, 0)
			row.AutomaticSize = Enum.AutomaticSize.Y
			row.BackgroundColor3 = ROW
			row.BorderSizePixel = 0
			row.Parent = logList
			corner(row, 8)
			local rowPadding = Instance.new("UIPadding")
			rowPadding.PaddingLeft = UDim.new(0, 6)
			rowPadding.PaddingRight = UDim.new(0, 6)
			rowPadding.PaddingTop = UDim.new(0, 2)
			rowPadding.PaddingBottom = UDim.new(0, 4)
			rowPadding.Parent = row
			list(row, 0)
			local head =
				Widgets.label(`{ago(tonumber(entry.t) or 0)} · {tostring(entry.by)} · {tostring(entry.place)}`, row)
			head.LayoutOrder = 1
			head.Size = UDim2.new(1, 0, 0, 16)
			head.TextColor3 = SECONDARY
			head.Font = Enum.Font.BuilderSans
			head.TextXAlignment = Enum.TextXAlignment.Left
			local body = Widgets.label(`{tostring(entry.action)}: {tostring(entry.detail)}`, row)
			body.LayoutOrder = 2
			body.Size = UDim2.fromScale(1, 0)
			body.AutomaticSize = Enum.AutomaticSize.Y
			body.TextScaled = false
			body.TextSize = 16
			body.TextWrapped = true
			body.TextXAlignment = Enum.TextXAlignment.Left
		end
	end)

	-- Página 🎉 Eventos: alcance, duración y retraso elegidos arriba; los eventos con tiempo
	-- (Data/LiveEvents), los que están en marcha o programados con ⏹ para pararlos, y lo que se hace al
	-- momento en la Isla (Data/IslandActions). Para todos los servidores piden un segundo toque.
	local eventsPage = scroller(pages)
	eventsPage.Name = "Events"
	eventsPage.Size = UDim2.fromScale(1, 1)
	list(eventsPage, 6)

	local chosenScope: Scope = "Server"
	local chosenMinutes = Config.LiveEvents.Durations[1]
	local chosenDelay = 0

	-- Fila de opciones (la elegida en dorado): "values" con su texto.
	local function choiceRow(order: number, title: string, values: { any }, texts: { string }, pick: (any) -> ())
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 32)
		row.BackgroundTransparency = 1
		row.Parent = eventsPage
		local label = Widgets.label(title, row)
		label.Size = UDim2.fromScale(0.22, 1)
		label.TextColor3 = TITLE
		label.TextXAlignment = Enum.TextXAlignment.Left
		local buttons = Instance.new("Frame")
		buttons.Position = UDim2.fromScale(0.22, 0)
		buttons.Size = UDim2.fromScale(0.78, 1)
		buttons.BackgroundTransparency = 1
		buttons.Parent = row
		local layout = list(buttons, 4)
		layout.FillDirection = Enum.FillDirection.Horizontal
		local all: { TextButton } = {}
		local function paint(selected: number)
			for index, button in all do
				button.BackgroundColor3 = if index == selected then GOLD else ROW
				button.TextColor3 = if index == selected then GOLD_TEXT else Color3.new(1, 1, 1)
			end
		end
		for index, value in values do
			local button = smallButton(texts[index], buttons)
			button.LayoutOrder = index
			button.Size = UDim2.new(1 / #values, -4, 1, 0)
			button.MouseButton1Click:Connect(function()
				paint(index)
				pick(value)
			end)
			table.insert(all, button)
		end
		paint(1)
	end

	local function eventHeading(text: string, order: number)
		local label = Widgets.label(text, eventsPage)
		label.LayoutOrder = order
		label.Size = UDim2.new(1, -8, 0, 22)
		label.TextColor3 = TITLE
		label.TextXAlignment = Enum.TextXAlignment.Left
	end

	-- Cuadrícula de botones de "columns" columnas.
	local function grid(name: string, order: number, columns: number): Frame
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -8, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.BackgroundTransparency = 1
		frame.Parent = eventsPage
		local layout = Instance.new("UIGridLayout")
		layout.CellPadding = UDim2.fromOffset(4, 4)
		layout.CellSize = UDim2.new(1 / columns, -4, 0, 36)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = frame
		return frame
	end

	-- Un botón que, para todos los servidores, pide un segundo toque antes de "action".
	local waiting: TextButton? = nil
	local waitingUntil = 0
	local function confirmed(button: TextButton, text: string): boolean
		if chosenScope == "Server" then
			return true
		end
		if waiting == button and os.clock() <= waitingUntil then
			waiting = nil
			button.Text = text
			return true
		end
		if waiting then
			waiting.Text = waiting:GetAttribute("Label") :: string
		end
		waiting = button
		waitingUntil = os.clock() + CONFIRM_SECONDS
		button.Text = "¿En todos?"
		task.delay(CONFIRM_SECONDS, function()
			if waiting == button and os.clock() >= waitingUntil then
				button.Text = text
				waiting = nil
			end
		end)
		return false
	end

	choiceRow(1, "Dónde", { "Server", "All" }, { "📍 Este servidor", "🌍 Todos" }, function(value)
		chosenScope = value
	end)
	local durationTexts = {}
	for _, minutes in Config.LiveEvents.Durations do
		table.insert(durationTexts, `{minutes} min`)
	end
	choiceRow(2, "Dura", Config.LiveEvents.Durations, durationTexts, function(value)
		chosenMinutes = value
	end)
	local delayTexts = {}
	for _, minutes in Config.LiveEvents.Delays do
		table.insert(delayTexts, if minutes == 0 then "Ya" else `+{minutes}`)
	end
	choiceRow(3, "Empieza", Config.LiveEvents.Delays, delayTexts, function(value)
		chosenDelay = value
	end)

	eventHeading("🎉 Eventos (la fiesta y la lluvia de huevos, en el Lobby)", 4)
	local eventGrid = grid("EventGrid", 5, 2)
	local eventKinds = {}
	for kind, info in LiveEventCatalog do
		if not info.hidden then
			table.insert(eventKinds, kind)
		end
	end
	table.sort(eventKinds, function(a, b)
		return LiveEventCatalog[a].order < LiveEventCatalog[b].order
	end)
	for index, kind in eventKinds do
		local info = LiveEventCatalog[kind]
		local text = `{info.icon} {info.name}`
		local button = smallButton(text, eventGrid)
		button.Name = kind
		button.LayoutOrder = index
		button:SetAttribute("Label", text)
		button.MouseButton1Click:Connect(function()
			if confirmed(button, text) then
				Remotes.AdminLiveEvent:FireServer("Start", kind, chosenMinutes, chosenDelay, chosenScope)
			end
		end)
	end

	eventHeading("⏱️ En marcha y programados", 6)
	local running = Instance.new("Frame")
	running.Name = "Running"
	running.LayoutOrder = 7
	running.Size = UDim2.new(1, -8, 0, 0)
	running.AutomaticSize = Enum.AutomaticSize.Y
	running.BackgroundTransparency = 1
	running.Parent = eventsPage
	list(running, 3)
	local function renderRunning()
		for _, child in running:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local now = LiveEvents.now()
		local any = false
		for index, event in LiveEvents.list() do
			if event.endsAt <= now then
				continue
			end
			any = true
			local info = LiveEventCatalog[event.kind]
			local row = Instance.new("Frame")
			row.Name = event.kind
			row.LayoutOrder = index
			row.Size = UDim2.new(1, 0, 0, 32)
			row.BackgroundColor3 = ROW
			row.BorderSizePixel = 0
			row.Parent = running
			corner(row, 8)
			local state = if LiveEvents.isRunning(event, now)
				then `queda {LiveEvents.clock(event.endsAt - now)}`
				else `empieza en {LiveEvents.clock(event.startsAt - now)}`
			local where = if event.scope == "All" then "🌍" else "📍"
			local label = Widgets.label(`{where} {info.icon} {info.name} · {state}`, row)
			label.Position = UDim2.fromOffset(6, 0)
			label.Size = UDim2.new(0.78, -6, 1, 0)
			label.TextXAlignment = Enum.TextXAlignment.Left
			local labelLimit = Instance.new("UITextSizeConstraint")
			labelLimit.MaxTextSize = 16
			labelLimit.Parent = label
			local stop = smallButton("⏹ Parar", row)
			stop.Name = "Stop"
			stop.AnchorPoint = Vector2.new(1, 0.5)
			stop.Position = UDim2.new(1, -3, 0.5, 0)
			stop.Size = UDim2.new(0.22, -3, 1, -6)
			stop.BackgroundColor3 = CLOSE
			stop.TextColor3 = Color3.new(1, 1, 1)
			local id = event.id
			stop.MouseButton1Click:Connect(function()
				Remotes.AdminLiveEvent:FireServer("Stop", id)
			end)
		end
		if not any then
			local empty = Widgets.label("Ninguno", running)
			empty.Size = UDim2.new(1, 0, 0, 22)
			empty.TextColor3 = SECONDARY
			empty.TextXAlignment = Enum.TextXAlignment.Left
		end
	end

	eventHeading("🎮 Ahora en el juego (azul: en marcha, otro toque lo apaga)", 8)
	-- Qué jefe saca el botón 👑 Jefe: "" es al azar (de la rotación de la Isla); los demás, el id de Data/Bosses.
	local chosenBoss = ""
	local bossValues: { any } = { "" }
	local bossTexts = { "Al azar" }
	for _, bossId in Config.Match.BossRotation do
		table.insert(bossValues, bossId)
		table.insert(bossTexts, Bosses[bossId].name)
	end
	choiceRow(9, "Jefe", bossValues, bossTexts, function(value)
		chosenBoss = value
	end)
	local islandGrid = grid("IslandGrid", 10, 4)
	local actionButtons: { [string]: TextButton } = {}
	local actionIds = {}
	for action in IslandActions do
		table.insert(actionIds, action)
	end
	table.sort(actionIds, function(a, b)
		return IslandActions[a].order < IslandActions[b].order
	end)
	for index, action in actionIds do
		local info = IslandActions[action]
		local text = `{info.icon} {info.name}`
		local button = smallButton(text, islandGrid)
		button.Name = action
		button.LayoutOrder = index
		button:SetAttribute("Label", text)
		actionButtons[action] = button
		button.MouseButton1Click:Connect(function()
			if confirmed(button, text) then
				if action == "Boss" then
					Remotes.AdminIslandAction:FireServer(action, chosenScope, chosenBoss)
				else
					Remotes.AdminIslandAction:FireServer(action, chosenScope)
				end
			end
		end)
	end
	-- Resalta las acciones que la Isla dice que están en marcha (AdminEventsService la publica).
	local function renderActions()
		local state = {}
		local raw = ReplicatedStorage:GetAttribute(Config.AdminTools.IslandStateAttribute)
		if typeof(raw) == "string" then
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and typeof(decoded) == "table" then
				state = decoded
			end
		end
		for action, button in actionButtons do
			local on = state[action] == true
			button.BackgroundColor3 = if on then ACTIVE else GOLD
			button.TextColor3 = if on then Color3.new(1, 1, 1) else GOLD_TEXT
		end
	end

	-- Mientras se ve la página, la lista de los que están en marcha se rehace cada segundo.
	task.spawn(function()
		while true do
			if window.Visible and eventsPage.Visible then
				renderRunning()
				renderActions()
			end
			task.wait(1)
		end
	end)

	-- Página 🖥️ Servidor: mantenimiento con aviso (segundo toque) y la lista de servidores con su place,
	-- jugadores y FPS (ServerShared/ServerOps; en Studio solo este).
	local serverPage = scroller(pages)
	serverPage.Name = "Server"
	serverPage.Size = UDim2.fromScale(1, 1)
	list(serverPage, 6)
	local function serverLabel(text: string, order: number, color: Color3)
		local label = Widgets.label(text, serverPage)
		label.LayoutOrder = order
		label.Size = UDim2.new(1, -8, 0, 22)
		label.TextColor3 = color
		label.TextXAlignment = Enum.TextXAlignment.Left
		return label
	end
	serverLabel("🛠️ Mantenimiento en todos los servidores", 1, TITLE)
	local maintenanceRow = Instance.new("Frame")
	maintenanceRow.Name = "Maintenance"
	maintenanceRow.LayoutOrder = 2
	maintenanceRow.Size = UDim2.new(1, -8, 0, 36)
	maintenanceRow.BackgroundTransparency = 1
	maintenanceRow.Parent = serverPage
	local maintenanceLayout = list(maintenanceRow, 4)
	maintenanceLayout.FillDirection = Enum.FillDirection.Horizontal
	for index, minutes in Config.AdminTools.MaintenanceMinutes do
		local text = `🛠️ En {minutes} min`
		local button = smallButton(text, maintenanceRow)
		button.Name = `M{minutes}`
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / #Config.AdminTools.MaintenanceMinutes, -4, 1, 0)
		button.BackgroundColor3 = CLOSE
		button.TextColor3 = Color3.new(1, 1, 1)
		button:SetAttribute("Label", text)
		button.MouseButton1Click:Connect(function()
			if twoTaps(button, text) then
				Remotes.AdminServer:FireServer("Maintenance", minutes)
			end
		end)
	end
	local maintenanceNote =
		serverLabel("Avisa a todos, guarda y cierra al acabar la cuenta. Solo puede haber uno a la vez.", 3, SECONDARY)
	maintenanceNote.Font = Enum.Font.BuilderSans

	-- El mantenimiento programado o en marcha, con su hora y un botón para cancelarlo.
	local scheduledRow = Instance.new("Frame")
	scheduledRow.Name = "Scheduled"
	scheduledRow.LayoutOrder = 4
	scheduledRow.Size = UDim2.new(1, -8, 0, 36)
	scheduledRow.BackgroundColor3 = ROW
	scheduledRow.BorderSizePixel = 0
	scheduledRow.Visible = false
	scheduledRow.Parent = serverPage
	corner(scheduledRow, 8)
	local scheduledLabel = Widgets.label("", scheduledRow)
	scheduledLabel.Position = UDim2.fromOffset(6, 0)
	scheduledLabel.Size = UDim2.new(0.68, -6, 1, 0)
	scheduledLabel.TextXAlignment = Enum.TextXAlignment.Left
	local scheduledLimit = Instance.new("UITextSizeConstraint")
	scheduledLimit.MaxTextSize = 16
	scheduledLimit.Parent = scheduledLabel
	local cancelMaintenance = smallButton("✖ Cancelar", scheduledRow)
	cancelMaintenance.Name = "Cancel"
	cancelMaintenance.AnchorPoint = Vector2.new(1, 0.5)
	cancelMaintenance.Position = UDim2.new(1, -3, 0.5, 0)
	cancelMaintenance.Size = UDim2.new(0.32, -3, 1, -6)
	cancelMaintenance.BackgroundColor3 = CLOSE
	cancelMaintenance.TextColor3 = Color3.new(1, 1, 1)
	cancelMaintenance.MouseButton1Click:Connect(function()
		Remotes.AdminServer:FireServer("CancelMaintenance")
	end)
	local function renderMaintenance()
		local now = LiveEvents.now()
		local found: LiveEvents.Event? = nil
		for _, event in LiveEvents.list() do
			if event.kind == "Maintenance" and event.endsAt > now then
				found = event
				break
			end
		end
		scheduledRow.Visible = found ~= nil
		if found then
			local state = if LiveEvents.isRunning(found, now)
				then "en marcha"
				else `empieza en {LiveEvents.clock(found.startsAt - now)}`
			local where = if found.scope == "All" then "🌍" else "📍"
			scheduledLabel.Text = `{where} 🛠️ {found.by or "?"}: {state}`
		end
	end
	task.spawn(function()
		while true do
			if window.Visible and serverPage.Visible then
				renderMaintenance()
			end
			task.wait(1)
		end
	end)

	serverLabel("🖥️ Servidores", 5, TITLE)
	local refreshServers = smallButton("🔄 Actualizar", serverPage)
	refreshServers.Name = "Refresh"
	refreshServers.LayoutOrder = 6
	refreshServers.Size = UDim2.new(0.4, 0, 0, 32)
	local serverList = Instance.new("Frame")
	serverList.Name = "List"
	serverList.LayoutOrder = 7
	serverList.Size = UDim2.new(1, -8, 0, 0)
	serverList.AutomaticSize = Enum.AutomaticSize.Y
	serverList.BackgroundTransparency = 1
	serverList.Parent = serverPage
	list(serverList, 3)
	local function requestServers()
		for _, child in serverList:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local asking = Widgets.label("Preguntando a los servidores…", serverList)
		asking.Size = UDim2.new(1, 0, 0, 22)
		asking.TextColor3 = SECONDARY
		Remotes.AdminServer:FireServer("List")
	end
	refreshServers.MouseButton1Click:Connect(requestServers)
	local PLACE_NAMES = { Lobby = "🏝️ Lobby", Island = "🍌 Isla", Dunas = "🎖️ Dunas" }
	Remotes.AdminServer.OnClientEvent:Connect(function(action: any, servers: any, scope: any)
		if action ~= "List" or typeof(servers) ~= "table" then
			return
		end
		for _, child in serverList:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local total = 0
		for index, server in servers do
			total += tonumber(server.players) or 0
			local minutes = (tonumber(server.uptime) or 0) // 60
			local uptime = if minutes >= 60 then `{minutes // 60} h {minutes % 60} min` else `{minutes} min`
			local fps = tonumber(server.fps) or 0
			local row = Widgets.label(
				`{PLACE_NAMES[server.place] or tostring(server.place)} · 👥 {server.players}/{server.max} · {fps} FPS · ⏱️ {uptime} · {server.job}`,
				serverList
			)
			row.LayoutOrder = index
			row.Size = UDim2.new(1, 0, 0, 24)
			row.BackgroundColor3 = ROW
			row.BackgroundTransparency = 0
			row.TextXAlignment = Enum.TextXAlignment.Left
			-- Por debajo de 40 FPS el servidor va cargado: en naranja (aviso).
			row.TextColor3 = if fps < 40 then Color3.fromRGB(255, 170, 60) else Color3.new(1, 1, 1)
			corner(row, 8)
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 16
			limit.Parent = row
		end
		local footer = Widgets.label(
			`{#servers} servidor(es) · {total} jugador(es){if scope == "Server" then " · solo este (Studio)" else ""}`,
			serverList
		)
		footer.LayoutOrder = #servers + 1
		footer.Size = UDim2.new(1, 0, 0, 22)
		footer.TextColor3 = SECONDARY
		footer.TextXAlignment = Enum.TextXAlignment.Left
	end)

	-- Página 📈 Rendimiento: mientras está abierta, el servidor manda una muestra cada
	-- Config.Performance.SampleSeconds (ServerShared/Performance) y este cliente le devuelve la suya.
	-- Ámbar al pasar del 80 % del tope de Config.Budgets.Matches y rojo al pasarlo (no verde: es de la curación).
	local perfPage = scroller(pages)
	perfPage.Name = "Perf"
	perfPage.Size = UDim2.fromScale(1, 1)
	list(perfPage, 4)
	local budgets = Config.Budgets.Matches
	local partsBudget = if place == "Island"
		then budgets.IslandSiegeParts
		elseif place == "Dunas" then budgets.DunasParts
		elseif place == "Laboratorio" then budgets.LaboratorioParts
		else budgets.LobbyParts
	local function perfTitle(text: string, order: number)
		local label = Widgets.label(text, perfPage)
		label.LayoutOrder = order
		label.Size = UDim2.new(1, -8, 0, 22)
		label.TextColor3 = TITLE
		label.TextXAlignment = Enum.TextXAlignment.Left
	end
	-- Una cuadrícula de dos columnas con una celda por clave; devuelve la celda de cada una.
	local function perfGrid(order: number, keys: { string }, names: { [string]: string }): { [string]: TextLabel }
		local rows = (#keys + 1) // 2
		local box = Instance.new("Frame")
		box.LayoutOrder = order
		box.Size = UDim2.new(1, -8, 0, rows * 24)
		box.BackgroundTransparency = 1
		box.Parent = perfPage
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0.5, -3, 0, 22)
		layout.CellPadding = UDim2.fromOffset(6, 2)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = box
		local cells: { [string]: TextLabel } = {}
		for index, key in keys do
			local cell = Widgets.label(`{names[key]}: …`, box)
			cell.LayoutOrder = index
			cell.BackgroundColor3 = ROW
			cell.BackgroundTransparency = 0
			cell.TextXAlignment = Enum.TextXAlignment.Left
			corner(cell, 6)
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 15
			limit.Parent = cell
			cells[key] = cell
		end
		return cells
	end
	local PERF_OVER = Color3.fromRGB(235, 80, 70) -- pasa el tope
	local PERF_NEAR = Color3.fromRGB(255, 170, 60) -- pasa del 80 % del tope
	local function level(value: number, cap: number?): Color3
		if cap and value > cap then
			return PERF_OVER
		elseif cap and value > cap * 0.8 then
			return PERF_NEAR
		end
		return Color3.new(1, 1, 1)
	end
	-- Miles con punto: 45.000.
	local function fmt(value: number): string
		local text = string.format("%d", math.floor(value + 0.5))
		while true do
			local replaced, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1.%2")
			text = replaced
			if count == 0 then
				break
			end
		end
		return text
	end
	local function show(cell: TextLabel, name: string, value: number?, text: string?, color: Color3?)
		if value == nil then
			cell.Text = `{name}: n/d`
			cell.TextColor3 = SECONDARY
			return
		end
		cell.Text = `{name}: {text or fmt(value)}`
		cell.TextColor3 = color or Color3.new(1, 1, 1)
	end
	local PERF_SERVER_NAMES = {
		instances = "Instancias",
		parts = "Piezas",
		moving = "En movimiento",
		fps = "FPS",
		physics = "Físicas (ms)",
		memory = "Memoria (MB)",
	}
	local PERF_CATEGORY_NAMES = {
		characters = "Personajes",
		armor = "Armadura",
		tools = "Herramientas",
		pets = "Mascotas",
		mounts = "Monturas",
		structures = "Estructuras",
		enemies = "Enemigos",
		fx = "Efectos",
		map = "Mapa",
		other = "Otros",
	}
	local PERF_CLIENT_NAMES = {
		drawCalls = "Draw calls",
		triangles = "Triángulos",
		memory = "Memoria (MB)",
		fps = "FPS",
	}
	local perfStatus = Widgets.label("Esperando la primera muestra…", perfPage)
	perfStatus.LayoutOrder = 1
	perfStatus.Size = UDim2.new(1, -8, 0, 20)
	perfStatus.TextColor3 = SECONDARY
	perfStatus.Font = Enum.Font.BuilderSans
	perfStatus.TextXAlignment = Enum.TextXAlignment.Left
	perfTitle("🖥️ Servidor", 2)
	local serverCells = perfGrid(3, { "instances", "parts", "moving", "fps", "physics", "memory" }, PERF_SERVER_NAMES)
	perfTitle("🧱 Piezas por categoría", 4)
	local categoryKeys =
		{ "characters", "armor", "tools", "pets", "mounts", "structures", "enemies", "fx", "map", "other" }
	local categoryCells = perfGrid(5, categoryKeys, PERF_CATEGORY_NAMES)
	perfTitle("📱 Tu cliente", 6)
	local clientCells = perfGrid(7, { "drawCalls", "triangles", "memory", "fps" }, PERF_CLIENT_NAMES)
	local perfNote = Widgets.label("Ámbar: más del 80 % del tope · Rojo: pasa el tope (Config.Budgets).", perfPage)
	perfNote.LayoutOrder = 8
	perfNote.Size = UDim2.new(1, -8, 0, 20)
	perfNote.TextColor3 = SECONDARY
	perfNote.Font = Enum.Font.BuilderSans
	perfNote.TextXAlignment = Enum.TextXAlignment.Left

	local clientFrames = 0
	local clientLast = os.clock()
	local frameConnection: RBXScriptConnection? = nil
	local perfOn = false
	local function setPerf(on: boolean)
		if on == perfOn then
			return
		end
		perfOn = on
		Remotes.AdminPerf:FireServer("Sub", on)
		if frameConnection then
			frameConnection:Disconnect()
			frameConnection = nil
		end
		if on then
			clientFrames = 0
			clientLast = os.clock()
			frameConnection = RunService.RenderStepped:Connect(function()
				clientFrames += 1
			end)
		end
	end
	-- Lo que mide este cliente; lo que no existe en esta versión de Roblox no se manda.
	local function readStat(name: string): number?
		local ok, value = pcall(function()
			return (Stats :: any)[name]
		end)
		return if ok and typeof(value) == "number" then value else nil
	end
	local function clientSample(): { [string]: number }
		local now = os.clock()
		local sample: { [string]: number } = { fps = clientFrames / math.max(now - clientLast, 0.001) }
		clientFrames = 0
		clientLast = now
		sample.drawCalls = readStat("SceneDrawcallCount") :: any
		sample.triangles = readStat("SceneTriangleCount") :: any
		local ok, memory = pcall(function()
			return Stats:GetTotalMemoryUsageMb()
		end)
		if ok then
			sample.memory = memory
		end
		return sample
	end
	Remotes.AdminPerf.OnClientEvent:Connect(function(kind: any, data: any)
		if not perfOn or typeof(data) ~= "table" then
			return
		end
		if kind == "Server" then
			perfStatus.Text = `{data.players or 0} jugador(es) · cada {Config.Performance.SampleSeconds} s`
			local fps = tonumber(data.fps) or 0
			local fpsColor = if fps < budgets.ServerFps
				then PERF_OVER
				elseif fps < budgets.ServerFps + 3 then PERF_NEAR
				else nil
			local parts = tonumber(data.parts)
			local moving = tonumber(data.moving)
			local physics = tonumber(data.physics)
			show(serverCells.instances, PERF_SERVER_NAMES.instances, tonumber(data.instances))
			show(serverCells.parts, PERF_SERVER_NAMES.parts, parts, nil, level(parts or 0, partsBudget))
			show(
				serverCells.moving,
				PERF_SERVER_NAMES.moving,
				moving,
				nil,
				level(moving or 0, budgets.MovedPartsPerFrame)
			)
			show(serverCells.fps, PERF_SERVER_NAMES.fps, fps, string.format("%.0f", fps), fpsColor)
			show(
				serverCells.physics,
				PERF_SERVER_NAMES.physics,
				if physics and physics >= 0 then physics else nil,
				if physics then string.format("%.2f", physics) else nil
			)
			show(serverCells.memory, PERF_SERVER_NAMES.memory, tonumber(data.memory))
			local cats = if typeof(data.cats) == "table" then data.cats else {}
			for _, key in categoryKeys do
				show(categoryCells[key], PERF_CATEGORY_NAMES[key], tonumber(cats[key]))
			end
			-- El cliente contesta con su muestra y el servidor la reenvía ya validada.
			Remotes.AdminPerf:FireServer("Client", clientSample())
		elseif kind == "Client" then
			local drawCalls = tonumber(data.drawCalls)
			local memory = tonumber(data.memory)
			local clientFps = tonumber(data.fps)
			local drawCap = if place == "Island" then budgets.IslandSiegeDrawCalls else nil
			show(clientCells.drawCalls, PERF_CLIENT_NAMES.drawCalls, drawCalls, nil, level(drawCalls or 0, drawCap))
			show(clientCells.triangles, PERF_CLIENT_NAMES.triangles, tonumber(data.triangles))
			show(clientCells.memory, PERF_CLIENT_NAMES.memory, memory, nil, level(memory or 0, budgets.MemoryMB))
			show(
				clientCells.fps,
				PERF_CLIENT_NAMES.fps,
				clientFps,
				if clientFps then string.format("%.0f", clientFps) else nil
			)
		end
	end)

	-- Pestañas.
	local tabs = {
		{ id = "Players", text = "👥 Jugadores", page = playersPage :: GuiObject, open = renderPlayers },
		{ id = "Everyone", text = "📢 Todos", page = everyonePage :: GuiObject, open = function() end },
		{ id = "Events", text = "🎉 Eventos", page = eventsPage :: GuiObject, open = renderRunning },
		{ id = "Server", text = "🖥️ Servidor", page = serverPage :: GuiObject, open = requestServers },
		{ id = "Perf", text = "📈 Rendimiento", page = perfPage :: GuiObject, open = function() end },
		{ id = "Log", text = "📜 Registro", page = logPage :: GuiObject, open = requestLog },
	}
	local tabButtons: { TextButton } = {}
	local current = "Players"
	local function showTab(id: string)
		current = id
		for index, tab in tabs do
			local chosen = tab.id == id
			tab.page.Visible = chosen
			tabButtons[index].BackgroundColor3 = if chosen then GOLD else ROW
			tabButtons[index].TextColor3 = if chosen then GOLD_TEXT else Color3.new(1, 1, 1)
			if chosen then
				tab.open()
			end
		end
		picker.Visible = false
		closeModerate()
		setPerf(id == "Perf")
	end
	for index, tab in tabs do
		local button = smallButton(tab.text, tabBar)
		button.Name = tab.id
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / #tabs, -3, 1, 0)
		button.MouseButton1Click:Connect(function()
			showTab(tab.id)
		end)
		tabButtons[index] = button
	end

	toggle.MouseButton1Click:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			showTab(current)
		else
			picker.Visible = false
			closeModerate()
			setPerf(false)
		end
	end)
	Players.PlayerAdded:Connect(function()
		if window.Visible and current == "Players" then
			renderPlayers()
		end
	end)
	Players.PlayerRemoving:Connect(function(other)
		if target and target.kind == "Player" and other.UserId == target.userId then
			picker.Visible = false
		end
		if moderated and other.UserId == moderated.userId then
			closeModerate()
		end
		if window.Visible and current == "Players" then
			task.defer(renderPlayers)
		end
	end)
end

function AdminPanel.start(place: "Island" | "Lobby" | "Dunas" | "Laboratorio")
	local player = Players.LocalPlayer
	if player:GetAttribute("IsAdmin") == true then
		build(place)
		return
	end
	-- El servidor lo marca al entrar: puede llegar un poco después.
	local connection: RBXScriptConnection
	connection = player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
		if player:GetAttribute("IsAdmin") == true then
			connection:Disconnect()
			build(place)
		end
	end)
end

return AdminPanel
