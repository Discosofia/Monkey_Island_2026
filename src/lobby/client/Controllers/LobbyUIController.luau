--!strict
-- Interfaz del Lobby (Fase 3):
--   - Cabecera con el Ámbar y el récord de días.
--   - Pestañas: Rol (elegir guerrero, cazador, mago o médico), Arena (la arena PvP de Dunas: formato
--     1v1…5v5 y cola, tus números y el equipo de la arena de cada rol), Talentos (del rol elegido), Tienda
--     (mejoras con Ámbar), Mascotas (arriba el nido de huevos: el que se incuba, la mochila, los
--     pendientes y qué puede salir; debajo la colección), Misiones (el calendario de 7 días, las
--     misiones del día y lo que te llevas a la próxima partida), Grupo (invitar a jugadores del Lobby
--     para viajar juntos) y Ajustes (tu personaje, tus números de combate y dónde salen los números;
--     UI/SettingsPanel).
--   - Botón "Ir a la Isla de monos" (si estás en un grupo, viaja el grupo entero cuando lo pulsa el líder);
--     el bote del naufragio ("ZarparPrompt", World/LobbyBuilder) hace lo mismo.
--   - Botón para plegar el menú y pasear por el naufragio, y X de cerrar en el menú. El menú empieza
--     plegado; el cartel de roles de la playa ("RolesPrompt", tecla E) lo abre en la pestaña Rol, y
--     el nido de huevos ("NidoPrompt") en la pestaña Mascotas, y el velero de las Dunas
--     ("ZarparDunasPrompt") en la pestaña Arena.
--   - Botón "Invitar amigos" (invitación de Roblox a tus amigos para que vengan a este Lobby).
--   - Ventana de invitación cuando otro jugador te invita a su grupo.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local ArenaGearPicker = require(ReplicatedStorage.Shared.UI.ArenaGearPicker)
local ArenaRoleCards = require(ReplicatedStorage.Shared.UI.ArenaRoleCards)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Journal = require(ReplicatedStorage.Shared.UI.Journal)
local Daily = require(ReplicatedStorage.Shared.Daily)
local Missions = require(ReplicatedStorage.Shared.Data.Missions)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local SettingsPanel = require(ReplicatedStorage.Shared.UI.SettingsPanel)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Talents = require(ReplicatedStorage.Shared.Data.Talents)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)
local CalendarStrip = require(ReplicatedStorage.Shared.UI.CalendarStrip)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local ROW_HEIGHT = 78
local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local ROW_COLOR = Color3.fromRGB(45, 38, 30)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local BLOCKED_COLOR = Color3.fromRGB(90, 90, 90)
local CLOSE_COLOR = Color3.fromRGB(150, 60, 50)
-- Barra de incubación del huevo del nido (cian = huevo, como su línea de estado en la Isla).
local EGG_BAR_COLOR = Color3.fromRGB(150, 240, 255)
-- Píxeles que se deja libres abajo en el centro para la barra de objetos de Roblox (las armas del
-- rol): en PC su borde de arriba queda a unos 100 px del de abajo de la pantalla.
local HOTBAR_CLEARANCE = 112
-- Pantallas del combate compartido que tapa el menú abierto.
local COMBAT_HUDS = { RoleHUD = true, ComboHUD = true }
-- Nombre de la Isla en las frases y texto del botón de viaje.
local ISLAND = Config.PlaceNames.IslandShort
local JOIN_TEXT = `🍌 Ir a la {ISLAND} 🐒`
-- Segundos que se espera la segunda pulsación de "Descartar" (para no tirar un huevo sin querer).
local DISCARD_CONFIRM_SECONDS = 3
local TABS =
	{ "Rol", "Arena", "Talentos", "Tienda", "Mascotas", "Misiones", "Estilo", "Grupo", "Diario", "Ranking", "Ajustes" }
-- Pestaña Arena: en pantallas de menos alto que esto, el equipo de la arena va compacto.
local ARENA_COMPACT_BELOW = 500

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

-- Abre la ventana de Roblox para invitar a tus amigos a este servidor del Lobby.
local function inviteFriends(player: Player)
	local ok, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if not (ok and canInvite) then
		Toast.show("No puedes enviar invitaciones desde esta cuenta o dispositivo")
		return
	end
	local options = Instance.new("ExperienceInviteOptions")
	options.PromptMessage = Config.Social.InviteMessage
	SocialService:PromptGameInvite(player, options)
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
	-- Empieza plegado para ver el naufragio al llegar; se abre con el botón o con el tablón de roles.
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(320, 240)
	sizeLimit.MaxSize = Vector2.new(700, 520)
	sizeLimit.Parent = panel

	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(8, 8)
	-- Deja sitio a la X de cerrar, arriba a la derecha.
	tabBar.Size = UDim2.new(1, -66, 0, 40)
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
	local setMenuOpen: (open: boolean, tab: string?) -> ()
	-- Fila del huevo del nido de la pestaña Mascotas, que se actualiza cada segundo (tiempo y barra).
	type NestRow = { title: TextLabel, detail: TextLabel, fill: Frame, ready: boolean }
	local nestRow: NestRow? = nil
	-- Cuenta atrás del siguiente premio del calendario en la pestaña Misiones (cada segundo).
	local calendarCountdown: TextButton? = nil
	-- Pestaña Arena: formato elegido, rol cuyo equipo se ve, ranura abierta del equipo y la línea que
	-- dice cuánto llevas en la cola (se actualiza cada segundo).
	local arenaFormat = 1
	local arenaRole: string? = nil
	local arenaSlot: string? = nil
	local arenaQueueLine: TextLabel? = nil

	for index, name in TABS do
		local button = Instance.new("TextButton")
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / #TABS, -5, 1, 0)
		button.Text = name
		button.Font = Enum.Font.BuilderSansBold
		button.TextScaled = true
		button.Parent = tabBar
		corner(button, 8)
		-- Tope común: con TextScaled, "Rol" salía enorme y "Mascotas" diminuto.
		local tabTextLimit = Instance.new("UITextSizeConstraint")
		tabTextLimit.MaxTextSize = 16
		tabTextLimit.Parent = button
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
			local names = {}
			for _, ability in role.abilities do
				table.insert(names, if ability.ultimate then `definitiva: {ability.name}` else ability.name)
			end
			row.detail.Text = `{role.passive}\nHabilidades: {table.concat(names, " · ")}`
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

	local function readEggs(): EggIncubation.EggData
		local raw = player:GetAttribute("Eggs")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
		end)
		return EggIncubation.normalize(if ok then decoded else nil)
	end

	-- Fila con dos botones: el principal (dorado, a la derecha) y "Descartar" a su izquierda.
	local function twoButtonRow(order: number): (Row, TextButton)
		local row = newRow(list, order)
		row.title.Size = UDim2.new(0.46, -10, 0, 30)
		row.detail.Size = UDim2.new(0.46, -10, 0, 34)
		row.button.Size = UDim2.new(0.25, -10, 0, 50)
		local second = Widgets.button("", row.frame)
		second.AnchorPoint = Vector2.new(1, 0.5)
		second.Position = UDim2.new(0.75, -10, 0.5, 0)
		second.Size = UDim2.new(0.27, -10, 0, 50)
		second.BackgroundColor3 = CLOSE_COLOR
		second.TextColor3 = Color3.new(1, 1, 1)
		local limit = second:FindFirstChildOfClass("UISizeConstraint")
		if limit then
			limit:Destroy()
		end
		return row, second
	end

	-- Texto del huevo del nido: lo que le falta (o listo) y cuánto lleva incubado.
	local function updateNestRow(nestEgg: EggIncubation.NestEgg)
		local row = nestRow
		if not row then
			return
		end
		local now = EggIncubation.now()
		local rarity = Rarities[nestEgg.rarity]
		local ready = EggIncubation.isReady(nestEgg, now)
		row.title.Text = if ready
			then `🐣 ¡Huevo {rarity.name} listo!`
			else `🥚 Huevo {rarity.name} · {EggIncubation.formatTime(EggIncubation.remaining(nestEgg, now))}`
		local cap = nestEgg.totalSeconds * Config.Egg.PlayCapFraction
		row.detail.Text = `Incubado {math.floor(EggIncubation.progress(nestEgg, now) * 100)} % · jugando le has `
			.. `quitado {EggIncubation.formatTime(nestEgg.playBonus)} de {EggIncubation.formatTime(cap)}`
		row.fill.Size = UDim2.fromScale(math.clamp(EggIncubation.progress(nestEgg, now), 0, 1), 1)
		if ready ~= row.ready then
			-- Acaba de quedar listo: rehace la pestaña para encender "Abrir".
			row.ready = ready
			task.defer(render)
		end
	end

	-- Nido de huevos, arriba de la pestaña Mascotas (órdenes negativos: antes que la colección).
	local function renderNest()
		local eggs = readEggs()
		nestRow = nil
		note(list, "🥚 Tu nido: solo avanza el huevo que está en él (también sin jugar)", -100)

		local nestEgg = eggs.nest
		local row = newRow(list, -99)
		if nestEgg then
			local rarity = Rarities[nestEgg.rarity]
			row.title.TextColor3 = rarity.color
			local track = Instance.new("Frame")
			track.Position = UDim2.new(0, 10, 1, -12)
			track.Size = UDim2.new(0.68, -10, 0, 6)
			track.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
			track.Parent = row.frame
			corner(track, 3)
			local fill = Instance.new("Frame")
			fill.BackgroundColor3 = EGG_BAR_COLOR
			fill.Parent = track
			corner(fill, 3)
			local ready = EggIncubation.isReady(nestEgg, EggIncubation.now())
			nestRow = { title = row.title, detail = row.detail, fill = fill, ready = ready }
			updateNestRow(nestEgg)
			setButton(row.button, if ready then "🐣 Abrir" else "Incubando", ready)
			if ready then
				row.button.MouseButton1Click:Connect(function()
					-- Se cierra el menú para ver la ceremonia en el nido.
					setMenuOpen(false)
					Remotes.HatchEgg:FireServer()
				end)
			end

			-- Lo que puede salir de esta rareza (las que ya tienes, con ✅).
			local data = Progression.read(player)
			local names = {}
			for _, petId in PetRoll.petsOfRarity(nestEgg.rarity) do
				local pet = Pets[petId]
				local owned = (data.pets[petId] or 0) > 0
				table.insert(names, `{pet.icon} {pet.name}{if owned then " ✅" else ""}`)
			end
			local options = newRow(list, -98)
			options.title.Text = `Puede salir ({rarity.name}):`
			options.title.TextColor3 = rarity.color
			options.detail.Text = table.concat(names, " · ")
			options.detail.Size = UDim2.new(1, -20, 0, 34)
			options.button.Visible = false
		else
			row.title.Text = "🥚 Nido vacío"
			row.detail.Text = if #eggs.bag + #eggs.pending > 0
				then "Pon a incubar uno de tus huevos"
				else `Defiende huevos en la {ISLAND} para conseguirlos`
			setButton(row.button, "—", false)
		end

		-- Mochila (Config.Egg.BagSize casillas) y, si no cupieron, los pendientes.
		local function eggRows(source: "bag" | "pending", stored: { EggIncubation.StoredEgg }, firstOrder: number)
			for index, egg in stored do
				local rarity = Rarities[egg.rarity]
				local eggRow, discard = twoButtonRow(firstOrder + index)
				eggRow.title.Text = `🥚 Huevo {rarity.name}`
				eggRow.title.TextColor3 = rarity.color
				eggRow.detail.Text =
					`Tarda {EggIncubation.formatTime(EggIncubation.hatchSeconds(egg.rarity))} en el nido`
				setButton(eggRow.button, "Al nido", nestEgg == nil)
				if nestEgg == nil then
					eggRow.button.MouseButton1Click:Connect(function()
						Remotes.PlaceEgg:FireServer(source, index)
					end)
				end
				local amber = EggIncubation.discardAmber(egg.rarity)
				discard.Text = `Descartar +{amber} ✨`
				local armedUntil = 0
				discard.MouseButton1Click:Connect(function()
					if os.clock() < armedUntil then
						Remotes.DiscardEgg:FireServer(source, index)
						return
					end
					armedUntil = os.clock() + DISCARD_CONFIRM_SECONDS
					discard.Text = "¿Seguro?"
					task.delay(DISCARD_CONFIRM_SECONDS, function()
						if discard.Parent then
							discard.Text = `Descartar +{amber} ✨`
						end
					end)
				end)
			end
		end
		note(list, `🎒 Mochila de huevos ({#eggs.bag}/{Config.Egg.BagSize}): esperan sin avanzar`, -90)
		eggRows("bag", eggs.bag, -90)
		for slot = #eggs.bag + 1, Config.Egg.BagSize do
			local empty = newRow(list, -90 + slot)
			empty.frame.Size = UDim2.new(1, -10, 0, 40)
			empty.title.Text = "Casilla libre"
			empty.title.TextColor3 = Color3.fromRGB(160, 150, 135)
			empty.detail.Visible = false
			empty.button.Visible = false
		end
		if #eggs.pending > 0 then
			note(list, "⚠️ Mochila llena: estos huevos esperan a que decidas", -80)
			eggRows("pending", eggs.pending, -80)
		end
	end

	local function readRetention(): { [string]: any }
		local raw = player:GetAttribute("Retention")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
		end)
		return if ok and typeof(decoded) == "table" then decoded else {}
	end

	-- Calendario de 7 días (el mismo que la ventana del CalendarController) y las provisiones.
	local function renderMissions()
		local retention = readRetention()
		local login = Daily.loginState(retention.login)
		local now = EggIncubation.now()
		local claimable = Daily.canClaim(login, now)
		note(list, "📅 Calendario: un premio por cada día que entres (si faltas, no se pierde)", 0)

		local holder = Instance.new("Frame")
		holder.LayoutOrder = 1
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -10, 0, 170)
		holder.Parent = list
		CalendarStrip.build(holder, login, now)

		local today = newRow(list, 2)
		local reward = Config.Daily.Calendar[login.step]
		today.title.Text = if claimable then `Hoy, día {login.step}:` else `Mañana, día {login.step}:`
		today.title.TextColor3 = Color3.fromRGB(255, 205, 70)
		today.detail.Text = Rewards.describe(reward)
		setButton(today.button, if claimable then "Cobrar" else "", claimable)
		if claimable then
			today.button.MouseButton1Click:Connect(function()
				setButton(today.button, "Cobrando…", false)
				Remotes.ClaimLogin:FireServer()
			end)
		else
			calendarCountdown = today.button
		end

		-- Misiones del día: se cumplen en la Isla; aquí se ve cómo van y qué dan.
		local state = Daily.missionState(retention.daily)
		note(
			list,
			`🎯 Misiones de hoy: se cumplen en la {ISLAND} (cambian en {EggIncubation.formatTime(
				Daily.secondsToReset(now)
			)})`,
			3
		)
		for index, mission in state.missions do
			local definition = Missions[mission.id]
			local row = newRow(list, 3 + index)
			row.title.Text = Daily.missionText(mission.id)
			row.title.TextColor3 = if mission.done then Color3.fromRGB(120, 230, 140) else Color3.new(1, 1, 1)
			row.detail.Text =
				`{if definition.role then "Misión de tu rol · " else ""}Premio: {Rewards.describe(definition.reward)}`
			setButton(
				row.button,
				if mission.done then "✅ Cumplida" else `{math.floor(mission.progress)}/{definition.target}`,
				false
			)
		end

		local items = Rewards.describeItems(Rewards.sanitizeItems(retention.supplies))
		local supplies = newRow(list, 10)
		supplies.title.Text = "🎒 Provisiones para tu próxima partida"
		supplies.detail.Text = if items ~= ""
			then items
			else "Ninguna por ahora: llegan con el calendario y las misiones"
		supplies.detail.Size = UDim2.new(1, -20, 0, 34)
		supplies.button.Visible = false
	end

	-- Colección de mascotas: las que tienes se pueden llevar (1 activa); las demás salen como "???".
	local function renderPets(data: Progression.ProgressData)
		local active = player:GetAttribute("ActivePet")
		renderNest()
		note(list, "🐾 Tu colección: las mascotas nacen de los huevos del nido", 0)
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

	-- Cosméticos: solo aspecto, nunca ventaja. Casi todos se compran (Robux); los "earned" se ganan
	-- jugando (el título de Superviviente, al ganar una partida).
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
			elseif cosmetic.earned then
				setButton(row.button, "Gana una partida", false)
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
		local inviteRow = newRow(list, 1)
		inviteRow.title.Text = "📨 Invitar amigos"
		inviteRow.detail.Text = "Envía una invitación a tus amigos de Roblox para que vengan a este Lobby."
		setButton(inviteRow.button, "Invitar", true)
		inviteRow.button.MouseButton1Click:Connect(function()
			inviteFriends(player)
		end)
		local order = 2
		if inParty then
			local row = newRow(list, order)
			row.title.Text = if isLeader then "Eres el líder" else `Viajáis cuando el líder pulse "{JOIN_TEXT}"`
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

	local function readJson(attribute: string): { [string]: any }?
		local raw = player:GetAttribute(attribute)
		if typeof(raw) ~= "string" then
			return nil
		end
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		return if ok and typeof(decoded) == "table" then decoded else nil
	end

	local function queueText(queue: { [string]: any }): string
		local waited = math.max(0, Workspace:GetServerTimeNow() - (tonumber(queue.since) or 0))
		return `⏳ Buscando partida {queue.format}v{queue.format}… {math.floor(waited // 60)}:{string.format(
			"%02d",
			math.floor(waited % 60)
		)}`
	end

	-- Arena de Dunas: formato y cola (ArenaQueueService), tus números y el equipo de la arena de cada rol
	-- (Shared/UI/ArenaGearPicker; se compra y se cambia igual que en la base de Dunas).
	local function renderArena()
		local queue = readJson("ArenaQueue")
		local arena = readJson("Arena") or {}
		local leaderId = player:GetAttribute("PartyLeader")
		local follower = typeof(leaderId) == "number" and leaderId ~= player.UserId

		-- Formatos y "Buscar partida".
		local formatRow = Instance.new("Frame")
		formatRow.LayoutOrder = 1
		formatRow.Size = UDim2.new(1, -10, 0, 50)
		formatRow.BackgroundTransparency = 1
		formatRow.Parent = list
		local formatLayout = Instance.new("UIListLayout")
		formatLayout.FillDirection = Enum.FillDirection.Horizontal
		formatLayout.Padding = UDim.new(0, 6)
		formatLayout.SortOrder = Enum.SortOrder.LayoutOrder
		formatLayout.Parent = formatRow
		local shownFormat = if queue then tonumber(queue.format) or arenaFormat else arenaFormat
		for format = Config.Arena.MinFormat, Config.Arena.MaxFormat do
			local button = Instance.new("TextButton")
			button.LayoutOrder = format
			button.Size = UDim2.new(0.1, -6, 1, 0)
			button.Text = `{format}v{format}`
			button.Font = Enum.Font.BuilderSansBold
			button.TextScaled = true
			local chosen = format == shownFormat
			button.BackgroundColor3 = if chosen then READY_COLOR else ROW_COLOR
			button.TextColor3 = if chosen then Color3.fromRGB(40, 25, 5) else Color3.new(1, 1, 1)
			button.AutoButtonColor = queue == nil
			button.Parent = formatRow
			corner(button, 8)
			button.MouseButton1Click:Connect(function()
				if not queue then
					arenaFormat = format
					render()
				end
			end)
		end
		local search = Widgets.button("", formatRow)
		search.LayoutOrder = 99
		search.Size = UDim2.new(0.5, -6, 1, 0)
		local searchLimit = search:FindFirstChildOfClass("UISizeConstraint")
		if searchLimit then
			searchLimit:Destroy()
		end
		if follower then
			setButton(search, "Lo elige tu líder", false)
		elseif queue then
			setButton(search, "✖ Salir de la cola", true)
			search.BackgroundColor3 = CLOSE_COLOR
			search.TextColor3 = Color3.new(1, 1, 1)
		else
			setButton(search, "⚔️ Buscar partida", true)
		end
		search.MouseButton1Click:Connect(function()
			if follower then
				return
			elseif queue then
				Remotes.ArenaQueueLeave:FireServer()
			else
				Remotes.ArenaQueueJoin:FireServer(arenaFormat)
			end
		end)

		-- En la cola: cuánto llevas. Si no: tus números de la arena y el Ámbar de hoy.
		local status = Widgets.label("", list)
		status.LayoutOrder = 2
		status.Size = UDim2.new(1, -10, 0, 24)
		status.TextColor3 = Color3.fromRGB(255, 220, 150)
		if queue then
			status.Text = queueText(queue)
			arenaQueueLine = status
		else
			local stats = if typeof(arena.stats) == "table" then arena.stats else {}
			local daily = if typeof(arena.daily) == "table"
					and arena.daily.day == Daily.today(Workspace:GetServerTimeNow())
				then arena.daily.amber or 0
				else 0
			status.Text =
				`🏆 {stats.wins or 0} victorias · 🚩 {stats.captures or 0} banderas · ✨ hoy {daily}/{Config.Arena.Amber.DailyCap} de Ámbar en la arena`
		end

		-- Rol cuyo equipo se ve (al empezar, el de la arena o el elegido en el Lobby).
		local roleId = arenaRole
			or (if typeof(arena.role) == "string" and Roles[arena.role] then arena.role else nil)
			or Progression.validRole(player:GetAttribute("SelectedRole"))
		arenaRole = roleId
		-- Tarjetas con la ventaja de cada rol en combate, las mismas que en Dunas.
		local compact = Workspace.CurrentCamera.ViewportSize.Y < ARENA_COMPACT_BELOW
		local roleCards = ArenaRoleCards.new(list, 3, 44, compact, function(id)
			arenaRole = id
			render()
		end)
		roleCards.frame.Size = UDim2.new(1, -10, 0, roleCards.frame.Size.Y.Offset)
		roleCards.update(roleId)

		-- Equipo de la arena de ese rol.
		local picker = ArenaGearPicker.new(
			list,
			4,
			function(): string
				return arenaRole or roleId
			end,
			compact,
			arenaSlot,
			function(slot)
				arenaSlot = slot
			end,
			true
		)
		picker.update()
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
		nestRow = nil
		calendarCountdown = nil
		arenaQueueLine = nil
		local data = Progression.read(player)
		if currentTab == "Rol" then
			renderRoles(data)
		elseif currentTab == "Arena" then
			renderArena()
		elseif currentTab == "Talentos" then
			renderTalents(data)
		elseif currentTab == "Tienda" then
			renderShop(data)
		elseif currentTab == "Mascotas" then
			renderPets(data)
		elseif currentTab == "Misiones" then
			renderMissions()
		elseif currentTab == "Estilo" then
			renderStyle(data)
		elseif currentTab == "Ranking" then
			renderRanking()
		elseif currentTab == "Diario" then
			Journal.fill(list, data.bestiary)
		elseif currentTab == "Ajustes" then
			SettingsPanel.build(list, "Lobby")
		else
			renderParty()
		end
	end

	-- El tiempo del huevo del nido corre solo: se actualiza cada segundo mientras se ve.
	task.spawn(function()
		while true do
			task.wait(1)
			if nestRow and panel.Visible then
				local nestEgg = readEggs().nest
				if nestEgg then
					updateNestRow(nestEgg)
				end
			end
			local queueLine = arenaQueueLine
			if queueLine and panel.Visible then
				local queue = readJson("ArenaQueue")
				if queue then
					queueLine.Text = queueText(queue)
				end
			end
			local countdown = calendarCountdown
			if countdown and panel.Visible then
				local left = Daily.secondsToReset(EggIncubation.now())
				countdown.Text = `En {EggIncubation.formatTime(left)}`
				if left <= 1 then
					-- Ha cambiado el día: ya se puede cobrar.
					task.delay(2, render)
				end
			end
		end
	end)

	player.AttributeChanged:Connect(function(attribute)
		-- El panel de Ajustes se actualiza solo al cambiar una opción (no hace falta rehacerlo).
		if attribute == "Settings" and currentTab == "Ajustes" then
			return
		end
		render()
	end)
	Players.PlayerAdded:Connect(render)
	Players.PlayerRemoving:Connect(function()
		task.defer(render)
	end)
	render()

	-- Botón de viaje (y el bote del naufragio, que hace lo mismo). Con el menú plegado va encima de la
	-- barra de objetos de Roblox, que abajo en el centro lleva las armas del rol para probarlas en la
	-- plaza; con el menú abierto la barra se esconde y el botón baja a su sitio, para no tapar el menú
	-- en un teléfono (setMenuOpen).
	local joinButton = Widgets.button(JOIN_TEXT, gui)
	joinButton.Name = "JoinIslandButton"
	joinButton.AnchorPoint = Vector2.new(0.5, 1)
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
			joinButton.Text = JOIN_TEXT
		end)
	end
	joinButton.Activated:Connect(join)

	-- Provisiones guardadas (calendario, misiones): encima del botón de viaje, que es cuando se usan.
	-- Por píxeles y no en escala: el botón mide de 48 a 80 px de alto según la pantalla.
	local suppliesLabel = Widgets.label("", gui)
	suppliesLabel.Name = "SuppliesLine"
	suppliesLabel.AnchorPoint = Vector2.new(0.5, 1)
	suppliesLabel.Size = UDim2.new(0.5, 0, 0, 26)
	suppliesLabel.TextColor3 = Color3.fromRGB(230, 220, 200)
	local function refreshSupplies()
		local raw = player:GetAttribute("Retention")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
		end)
		local items = Rewards.sanitizeItems(if ok and typeof(decoded) == "table" then decoded.supplies else nil)
		local text = Rewards.describeItems(items)
		suppliesLabel.Text = if text ~= "" then `🎒 Te llevas a la {ISLAND}: {text}` else ""
		suppliesLabel.Visible = text ~= ""
	end
	player:GetAttributeChangedSignal("Retention"):Connect(refreshSupplies)
	refreshSupplies()

	-- El menú se puede plegar para pasear por el naufragio.
	local menuButton = Widgets.button("📜 Abrir menú", gui)
	menuButton.Name = "MenuToggle"
	menuButton.AnchorPoint = Vector2.new(0, 1)
	menuButton.Position = UDim2.fromScale(0.02, 0.95)
	menuButton.Size = UDim2.fromScale(0.17, 0.07)
	-- Las casillas de habilidades y de combos (CombatClient: RoleHUD y ComboHUD, arriba a la izquierda)
	-- quedan debajo del menú abierto: se esconden mientras está abierto.
	local playerGui = player:WaitForChild("PlayerGui")
	local function showCombatHud(screen: Instance)
		if screen:IsA("ScreenGui") and COMBAT_HUDS[screen.Name] then
			screen.Enabled = not panel.Visible
		end
	end
	playerGui.ChildAdded:Connect(showCombatHud)
	function setMenuOpen(open: boolean, tab: string?)
		panel.Visible = open
		menuButton.Text = if open then "📜 Ocultar menú" else "📜 Abrir menú"
		for _, screen in playerGui:GetChildren() do
			showCombatHud(screen)
		end
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not open)
		local bottom = if open then UDim2.fromScale(0.5, 0.95) else UDim2.new(0.5, 0, 1, -HOTBAR_CLEARANCE)
		joinButton.Position = bottom
		suppliesLabel.Position = bottom + UDim2.fromOffset(0, -86)
		if tab then
			currentTab = tab
			render()
		end
	end
	menuButton.Activated:Connect(function()
		setMenuOpen(not panel.Visible)
	end)
	-- El menú empieza plegado (coloca el botón de viaje y la línea de provisiones).
	setMenuOpen(false)

	-- "X" y no "✕": BuilderSans no tiene ese signo y sale una caja vacía.
	local closeButton = Widgets.button("X", panel)
	closeButton.Name = "Close"
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
	closeButton.Activated:Connect(function()
		setMenuOpen(false)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "ZarparPrompt" then
			join()
		elseif prompt.Name == "RolesPrompt" then
			-- Tablón de roles de la proa (World/LobbyBuilder).
			setMenuOpen(true, "Rol")
		elseif prompt.Name == "NidoPrompt" then
			-- Nido de huevos de la playa (World/LobbyBuilder; el huevo lo dibuja NestController).
			setMenuOpen(true, "Mascotas")
		elseif prompt.Name == "ZarparDunasPrompt" then
			-- Velero del embarcadero de las Dunas (World/LobbyBuilder): formato y cola de la arena.
			setMenuOpen(true, "Arena")
		end
	end)

	-- Invitar amigos de Roblox (también está en la pestaña Grupo). Encima del botón del menú: abajo a
	-- la derecha está el botón de saltar en móvil.
	local inviteButton = Widgets.button("📨 Invitar amigos", gui)
	inviteButton.Name = "InviteFriends"
	inviteButton.AnchorPoint = Vector2.new(0, 1)
	inviteButton.Position = UDim2.fromScale(0.02, 0.87)
	inviteButton.Size = UDim2.fromScale(0.17, 0.07)
	inviteButton.Activated:Connect(function()
		inviteFriends(player)
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
