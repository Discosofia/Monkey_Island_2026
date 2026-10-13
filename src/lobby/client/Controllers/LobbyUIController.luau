--!strict
-- Interfaz del Lobby (Fase 3):
--   - Cabecera con el Ámbar y el récord de días.
--   - Pestañas: Rol (elegir médico, cazador o recolector), Talentos (del rol elegido), Tienda
--     (mejoras con Ámbar) y Grupo (invitar a jugadores del Lobby para viajar juntos).
--   - Botón "Ir a la Isla" (si estás en un grupo, viaja el grupo entero cuando lo pulsa el líder);
--     el bote del naufragio ("ZarparPrompt", World/LobbyBuilder) hace lo mismo.
--   - Botón para plegar el menú y pasear por el naufragio.
--   - Ventana de invitación cuando otro jugador te invita a su grupo.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Journal = require(ReplicatedStorage.Shared.UI.Journal)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Talents = require(ReplicatedStorage.Shared.Data.Talents)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local ROW_HEIGHT = 78
local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local ROW_COLOR = Color3.fromRGB(45, 38, 30)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local BLOCKED_COLOR = Color3.fromRGB(90, 90, 90)
local TABS = { "Rol", "Talentos", "Tienda", "Mascotas", "Estilo", "Grupo", "Diario", "Ranking" }

type Row = { frame: Frame, title: TextLabel, detail: TextLabel, button: TextButton }

local LobbyUIController = {}

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

local function sortedKeys<T>(map: { [string]: T }, order: (T) -> number): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return order(map[a]) < order(map[b])
	end)
	return keys
end

local function newRow(parent: Instance, order: number): Row
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -10, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = ROW_COLOR
	frame.BackgroundTransparency = 0.15
	frame.Parent = parent
	corner(frame, 10)

	local title = Widgets.label("", frame)
	title.Position = UDim2.fromOffset(10, 6)
	title.Size = UDim2.new(0.68, -10, 0, 30)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local detail = Widgets.label("", frame)
	detail.Position = UDim2.fromOffset(10, 38)
	detail.Size = UDim2.new(0.68, -10, 0, 34)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextYAlignment = Enum.TextYAlignment.Top
	detail.TextWrapped = true
	detail.Font = Enum.Font.BuilderSans
	detail.TextColor3 = Color3.fromRGB(215, 205, 190)

	local button = Widgets.button("", frame)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.new(0.3, -10, 0, 50)
	local limit = button:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit:Destroy()
	end
	return { frame = frame, title = title, detail = detail, button = button }
end

local function setButton(button: TextButton, text: string, enabled: boolean)
	button.Text = text
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then READY_COLOR else BLOCKED_COLOR
	button.TextColor3 = if enabled then Color3.fromRGB(40, 25, 5) else Color3.fromRGB(210, 210, 210)
end

local function clearRows(list: Instance)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function note(list: Instance, text: string, order: number)
	local label = Widgets.label(text, list)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -10, 0, 34)
	label.TextColor3 = Color3.fromRGB(255, 220, 150)
end

function LobbyUIController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("LobbyUI", player:WaitForChild("PlayerGui"))

	local title = Widgets.label(Config.GameName, gui)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.02)
	title.Size = UDim2.fromScale(0.8, 0.08)

	local subtitle = Widgets.label(Config.Subtitle, gui)
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.fromScale(0.5, 0.1)
	subtitle.Size = UDim2.fromScale(0.5, 0.04)
	subtitle.TextColor3 = READY_COLOR

	local header = Widgets.label("", gui)
	header.AnchorPoint = Vector2.new(0.5, 0)
	header.Position = UDim2.fromScale(0.5, 0.145)
	header.Size = UDim2.fromScale(0.7, 0.04)

	-- Panel con pestañas.
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, 0.2)
	panel.Size = UDim2.fromScale(0.64, 0.6)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.1
	panel.Parent = gui
	corner(panel, 14)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(320, 240)
	sizeLimit.MaxSize = Vector2.new(700, 520)
	sizeLimit.Parent = panel

	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(8, 8)
	tabBar.Size = UDim2.new(1, -16, 0, 40)
	tabBar.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabBar

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(8, 56)
	list.Size = UDim2.new(1, -16, 1, -64)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = list

	local currentTab = "Rol"
	local tabButtons: { [string]: TextButton } = {}
	local render: () -> ()

	for index, name in TABS do
		local button = Instance.new("TextButton")
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / #TABS, -5, 1, 0)
		button.Text = name
		button.Font = Enum.Font.BuilderSansBold
		button.TextScaled = true
		button.Parent = tabBar
		corner(button, 8)
		button.MouseButton1Click:Connect(function()
			currentTab = name
			render()
		end)
		tabButtons[name] = button
	end

	local function renderRoles(data: Progression.ProgressData)
		local selected = Progression.validRole(player:GetAttribute("SelectedRole"))
		for index, roleId in
			sortedKeys(Roles, function(role)
				return role.order
			end)
		do
			local role = Roles[roleId]
			local xp = data.roleXp[roleId] or 0
			local row = newRow(list, index)
			row.frame.Size = UDim2.new(1, -10, 0, ROW_HEIGHT + 22)
			row.detail.Size = UDim2.new(0.68, -10, 0, 56)
			row.title.Text = `{role.icon} {role.name} · nivel {Progression.level(xp)}`
			row.detail.Text = `{role.passive}\nHabilidad: {role.ability.name}. {role.ability.description}`
			local isSelected = roleId == selected
			setButton(row.button, if isSelected then "Elegido" else "Elegir", not isSelected)
			row.button.MouseButton1Click:Connect(function()
				Remotes.SelectRole:FireServer(roleId)
			end)
		end
	end

	local function renderTalents(data: Progression.ProgressData)
		local roleId = Progression.validRole(player:GetAttribute("SelectedRole"))
		local role = Roles[roleId]
		local points = Progression.freePoints(roleId, data)
		note(list, `{role.icon} {role.name}: {points} punto(s) libre(s) · 1 punto por nivel`, 0)
		local talents = Talents[roleId]
		for index, talentId in
			sortedKeys(talents, function(talent)
				return talent.order
			end)
		do
			local talent = talents[talentId]
			local rank = data.talents[Progression.talentKey(roleId, talentId)] or 0
			local row = newRow(list, index)
			row.title.Text = `{talent.name} ({rank}/{talent.maxRank})`
			row.detail.Text = talent.description
			local full = rank >= talent.maxRank
			setButton(row.button, if full then "Máximo" else "Aprender", not full and points > 0)
			row.button.MouseButton1Click:Connect(function()
				Remotes.LearnTalent:FireServer(roleId, talentId)
			end)
		end
	end

	local function renderShop(data: Progression.ProgressData)
		local amber = player:GetAttribute("Amber")
		local balance = if typeof(amber) == "number" then amber else 0
		for index, upgradeId in
			sortedKeys(Upgrades, function(upgrade)
				return upgrade.order
			end)
		do
			local upgrade = Upgrades[upgradeId]
			local rank = data.upgrades[upgradeId] or 0
			local cost = upgrade.costs[rank + 1]
			local row = newRow(list, index)
			row.title.Text = `{upgrade.icon} {upgrade.name} ({rank}/{#upgrade.costs})`
			row.detail.Text = upgrade.description
			if cost then
				setButton(row.button, `✨ {cost}`, balance >= cost)
			else
				setButton(row.button, "Máximo", false)
			end
			row.button.MouseButton1Click:Connect(function()
				Remotes.BuyUpgrade:FireServer(upgradeId)
			end)
		end
	end

	-- Colección de mascotas: las que tienes se pueden llevar (1 activa); las demás salen como "???".
	local function renderPets(data: Progression.ProgressData)
		local active = player:GetAttribute("ActivePet")
		note(list, "🥚 Las mascotas salen de los huevos que rescatáis en la isla", 0)
		local ids = {}
		for petId in Pets do
			table.insert(ids, petId)
		end
		table.sort(ids, function(a, b)
			local ra, rb = Rarities[Pets[a].rarity].order, Rarities[Pets[b].rarity].order
			if ra ~= rb then
				return ra < rb
			end
			return Pets[a].name < Pets[b].name
		end)
		for index, petId in ids do
			local pet = Pets[petId]
			local rarity = Rarities[pet.rarity]
			local owned = data.pets[petId] or 0
			local row = newRow(list, index)
			row.title.TextColor3 = rarity.color
			if owned > 0 then
				row.title.Text = `{pet.icon} {pet.name} ×{owned} · {rarity.name}`
				row.detail.Text = `{pet.kind}: {pet.description}`
				local isActive = active == petId
				setButton(row.button, if isActive then "Quitar" else "Llevar", true)
				row.button.MouseButton1Click:Connect(function()
					Remotes.SelectPet:FireServer(if isActive then "" else petId)
				end)
			else
				row.title.Text = `❓ ??? · {rarity.name}`
				row.detail.Text = "Aún no la tienes"
				setButton(row.button, "—", false)
			end
		end
	end

	-- Cosméticos de pago (Robux): solo aspecto, nunca ventaja.
	local function renderStyle(data: Progression.ProgressData)
		note(list, "🎨 Solo cambian tu aspecto. Uno equipado por tipo", 0)
		for index, cosmeticId in
			sortedKeys(Cosmetics, function(cosmetic)
				return cosmetic.order
			end)
		do
			local cosmetic = Cosmetics[cosmeticId]
			local owned = player:GetAttribute(`Cosmetic_{cosmeticId}`) == true
			local equipped = data.cosmetics[cosmetic.kind] == cosmeticId
			local row = newRow(list, index)
			row.title.Text = `{cosmetic.icon} {cosmetic.name}`
			row.title.TextColor3 = cosmetic.color
			row.detail.Text = cosmetic.description
			if owned then
				setButton(row.button, if equipped then "Quitar" else "Equipar", true)
				row.button.MouseButton1Click:Connect(function()
					Remotes.EquipCosmetic:FireServer(cosmeticId)
				end)
			elseif cosmetic.gamePassId == 0 then
				setButton(row.button, "Próximamente", false)
			else
				setButton(row.button, "Comprar", true)
				row.button.MouseButton1Click:Connect(function()
					MarketplaceService:PromptGamePassPurchase(player, cosmetic.gamePassId)
				end)
			end
		end
	end

	-- Clasificaciones globales (las publica LeaderboardService cada pocos minutos).
	local function renderRanking()
		local order = 0
		for _, board in
			{
				{ stat = "BestDays", title = "🏆 Más días sobrevividos" },
				{ stat = "Rescues", title = "🚁 Más rescates" },
			}
		do
			order += 1
			note(list, board.title, order)
			local raw = ReplicatedStorage:GetAttribute(`Leaderboard_{board.stat}`)
			local ok, rows = pcall(function()
				return if typeof(raw) == "string" then HttpService:JSONDecode(raw) else {}
			end)
			local entries = if ok and typeof(rows) == "table" then rows else {}
			if #entries == 0 then
				order += 1
				note(list, "Aún no hay datos (se actualiza cada pocos minutos)", order)
			end
			for position, entry in entries do
				order += 1
				local label = Widgets.label(`{position}. {entry.name} — {entry.value}`, list)
				label.LayoutOrder = order
				label.Size = UDim2.new(1, -10, 0, 28)
				label.TextXAlignment = Enum.TextXAlignment.Left
			end
		end
	end

	local function renderParty()
		local membersText = player:GetAttribute("PartyMembers")
		local leaderId = player:GetAttribute("PartyLeader")
		local inParty = typeof(membersText) == "string"
		local isLeader = not inParty or leaderId == player.UserId
		note(
			list,
			if inParty
				then `👥 Grupo: {membersText}`
				else "Invita a otros jugadores para viajar juntos a la misma isla",
			0
		)
		local order = 1
		if inParty then
			local row = newRow(list, order)
			row.title.Text = if isLeader then "Eres el líder" else "Viajáis cuando el líder pulse Ir a la Isla"
			row.detail.Text = "Salir del grupo te deja viajar por tu cuenta."
			setButton(row.button, "Salir", true)
			row.button.MouseButton1Click:Connect(function()
				Remotes.PartyLeave:FireServer()
			end)
			order += 1
		end
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local row = newRow(list, order)
				row.title.Text = other.DisplayName
				local otherMembers = other:GetAttribute("PartyMembers")
				local busy = typeof(otherMembers) == "string"
				row.detail.Text = if busy then "Ya está en un grupo" else "En el Lobby"
				setButton(row.button, "Invitar", isLeader and not busy)
				row.button.MouseButton1Click:Connect(function()
					Remotes.PartyInvite:FireServer(other.UserId)
				end)
				order += 1
			end
		end
	end

	function render()
		for name, button in tabButtons do
			local active = name == currentTab
			button.BackgroundColor3 = if active then READY_COLOR else ROW_COLOR
			button.TextColor3 = if active then Color3.fromRGB(40, 25, 5) else Color3.new(1, 1, 1)
		end
		local amber = player:GetAttribute("Amber")
		local best = player:GetAttribute("BestDays")
		local amberText = if typeof(amber) == "number" then tostring(amber) else "…"
		local bestText = if typeof(best) == "number" then tostring(best) else "0"
		header.Text = `✨ Ámbar: {amberText}   🏆 Récord: {bestText} días`

		clearRows(list)
		local data = Progression.read(player)
		if currentTab == "Rol" then
			renderRoles(data)
		elseif currentTab == "Talentos" then
			renderTalents(data)
		elseif currentTab == "Tienda" then
			renderShop(data)
		elseif currentTab == "Mascotas" then
			renderPets(data)
		elseif currentTab == "Estilo" then
			renderStyle(data)
		elseif currentTab == "Ranking" then
			renderRanking()
		elseif currentTab == "Diario" then
			Journal.fill(list, data.bestiary)
		else
			renderParty()
		end
	end

	player.AttributeChanged:Connect(render)
	Players.PlayerAdded:Connect(render)
	Players.PlayerRemoving:Connect(function()
		task.defer(render)
	end)
	render()

	-- Botón de viaje (y el bote del naufragio, que hace lo mismo).
	local joinButton = Widgets.button("Ir a la Isla", gui)
	joinButton.Name = "JoinIslandButton"
	joinButton.AnchorPoint = Vector2.new(0.5, 1)
	joinButton.Position = UDim2.fromScale(0.5, 0.95)
	joinButton.Size = UDim2.fromScale(0.3, 0.1)
	local waiting = false
	local function join()
		if waiting then
			return
		end
		waiting = true
		joinButton.Text = "Viajando..."
		Remotes.RequestJoinIsland:FireServer()
		-- Si el viaje no ocurre (por ejemplo en Studio), el botón vuelve a estar disponible.
		task.delay(Config.Teleport.CooldownSeconds + 4, function()
			waiting = false
			joinButton.Text = "Ir a la Isla"
		end)
	end
	joinButton.Activated:Connect(join)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "ZarparPrompt" then
			join()
		end
	end)

	-- El menú se puede plegar para pasear por el naufragio.
	local menuButton = Widgets.button("📜 Ocultar menú", gui)
	menuButton.Name = "MenuToggle"
	menuButton.AnchorPoint = Vector2.new(0, 1)
	menuButton.Position = UDim2.fromScale(0.02, 0.95)
	menuButton.Size = UDim2.fromScale(0.17, 0.07)
	menuButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
		menuButton.Text = if panel.Visible then "📜 Ocultar menú" else "📜 Abrir menú"
	end)

	-- Ventana de invitación.
	Remotes.PartyInvited.OnClientEvent:Connect(function(leaderUserId: number, leaderName: string)
		local popup = Instance.new("Frame")
		popup.AnchorPoint = Vector2.new(0.5, 0.5)
		popup.Position = UDim2.fromScale(0.5, 0.5)
		popup.Size = UDim2.fromScale(0.4, 0.22)
		popup.BackgroundColor3 = PANEL_COLOR
		popup.Parent = gui
		corner(popup, 14)
		local popupLimit = Instance.new("UISizeConstraint")
		popupLimit.MinSize = Vector2.new(280, 150)
		popupLimit.Parent = popup
		local text = Widgets.label(`👥 {leaderName} te invita a su grupo`, popup)
		text.Position = UDim2.fromScale(0.05, 0.08)
		text.Size = UDim2.fromScale(0.9, 0.35)
		local function respond(accept: boolean)
			Remotes.PartyRespond:FireServer(leaderUserId, accept)
			popup:Destroy()
		end
		local accept = Widgets.button("Aceptar", popup)
		accept.Position = UDim2.fromScale(0.05, 0.55)
		accept.Size = UDim2.fromScale(0.42, 0.35)
		accept.MouseButton1Click:Connect(function()
			respond(true)
		end)
		local decline = Widgets.button("Rechazar", popup)
		decline.Position = UDim2.fromScale(0.53, 0.55)
		decline.Size = UDim2.fromScale(0.42, 0.35)
		decline.BackgroundColor3 = BLOCKED_COLOR
		decline.MouseButton1Click:Connect(function()
			respond(false)
		end)
		task.delay(Config.Party.InviteSeconds, function()
			if popup.Parent then
				popup:Destroy()
			end
		end)
	end)
end

return LobbyUIController
