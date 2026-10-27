--!strict
-- Panel de administradores (ServerShared/Admin), en los tres places y también en el juego publicado:
-- un botón "👑 Admin" encima del de Pruebas que despliega una ventana con pestañas (T4):
--   - 👥 Jugadores: los jugadores del servidor con "Dar todo" y "Elegir", que abre al lado el listado
--     de los huevos (por rareza), las mascotas, las monturas y los cosméticos del juego, con buscador,
--     para darle una sola cosa.
--   - 📢 Todos: un anuncio y "Dar a todos" (el mismo listado), en este servidor o en todos.
--   - 📜 Registro: lo último que han hecho los administradores, en cualquier servidor.
-- Solo sale si el servidor ha marcado al jugador con el atributo "IsAdmin", y el servidor lo vuelve
-- a comprobar al pedirlo.

local Players = game:GetService("Players")

local Config = require(script.Parent.Parent.Config)
local Cosmetics = require(script.Parent.Parent.Data.Cosmetics)
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

local function build(place: "Island" | "Lobby" | "Dunas")
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

	-- Página 👥 Jugadores: una fila por jugador del servidor (tú el primero) con "Elegir" y "Dar todo".
	local playersPage = scroller(pages)
	playersPage.Name = "Players"
	playersPage.Size = UDim2.fromScale(1, 1)
	list(playersPage, 4)

	local function renderPlayers()
		for _, child in playersPage:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local title = Widgets.label("Elegir un huevo, mascota, montura o cosmético, o dar todo", playersPage)
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
			name.Size = UDim2.new(0.44, -6, 1, 0)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local userId, displayName = other.UserId, other.DisplayName
			local giveAll = smallButton("🔓 Dar todo", row)
			giveAll.Name = "GiveAll"
			giveAll.AnchorPoint = Vector2.new(1, 0.5)
			giveAll.Position = UDim2.new(1, -4, 0.5, 0)
			giveAll.Size = UDim2.new(0.28, -6, 1, -8)
			giveAll.MouseButton1Click:Connect(function()
				Remotes.AdminGiveAll:FireServer(userId)
			end)
			local choose = smallButton("🎁 Elegir", row)
			choose.Name = "Choose"
			choose.AnchorPoint = Vector2.new(1, 0.5)
			choose.Position = UDim2.new(0.72, -4, 0.5, 0)
			choose.Size = UDim2.new(0.26, -6, 1, -8)
			choose.MouseButton1Click:Connect(function()
				openPicker({ kind = "Player", userId = userId, name = displayName })
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

	-- Pestañas.
	local tabs = {
		{ id = "Players", text = "👥 Jugadores", page = playersPage :: GuiObject, open = renderPlayers },
		{ id = "Everyone", text = "📢 Todos", page = everyonePage :: GuiObject, open = function() end },
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
		if window.Visible and current == "Players" then
			task.defer(renderPlayers)
		end
	end)
end

function AdminPanel.start(place: "Island" | "Lobby" | "Dunas")
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
