--!strict
-- Interfaz del Lobby:
--   - Arriba, la pastilla con el Ámbar y el récord de días (en la franja de la barra de Roblox). El
--     título del juego sale al llegar y se va a los pocos segundos.
--   - Ventanas de las estaciones de la plaza: se abren con el aviso de su cartel o del nido
--     (STATION_PROMPTS, World/LobbyBuilder) y se cierran solas al alejarse:
--       Rol (cartel "ELIGE TU ROL": guerrero, cazador, mago o médico, y un atajo a sus talentos),
--       Arena (cartel de la Isla de dunas y su velero: formato 1v1…5v5 y cola, tus números y el equipo
--       de la arena de cada rol), Mascotas (el nido: el huevo que se incuba, la mochila, los
--       pendientes y qué puede salir; al lado, la colección), Ranking (las cuatro clasificaciones) y
--       Pase (el pase de temporada, UI/SeasonPassPanel; también tiene su botón en la barra).
--   - Barra del menú (MENU) con lo que se usa desde cualquier sitio: Talentos (del rol elegido, y debajo
--     sus definitivas para elegir la que lleva: Shared/RoleAbilities, T7), Tienda
--     (pestañas "✨ Mejoras", con Ámbar, y "🎨 Cosméticos", las tiendas que rotan, UI/CosmeticShopPanel),
--     Misiones (el calendario de 7 días, las misiones del día y lo que te llevas a la próxima partida), Pase, Armario (los cosméticos, UI/WardrobePanel), Emotes (no es una
--     ventana: abre la rueda de emotes, UI/EmoteWheel), Grupo (invitar a jugadores del Lobby para
--     viajar juntos), Diario
--     y Ajustes (UI/SettingsPanel). Un punto rojo avisa de lo pendiente (puntos de talento libres,
--     premio del calendario, premios del pase por reclamar). En PC va en columna a la izquierda; en táctil o en una pantalla baja, en
--     fila en la franja de la barra de Roblox.
--   - Botón "Ir a la Isla de monos" (si estás en un grupo, viaja el grupo entero cuando lo pulsa el líder);
--     el bote del naufragio ("ZarparPrompt", World/LobbyBuilder) hace lo mismo.
--   - Botón "Invitar amigos" (invitación de Roblox a tus amigos para que vengan a este Lobby), debajo
--     de la barra del menú.
--   - Ventana de invitación cuando otro jugador te invita a su grupo.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ArenaGearPicker = require(ReplicatedStorage.Shared.UI.ArenaGearPicker)
local ArenaRoleCards = require(ReplicatedStorage.Shared.UI.ArenaRoleCards)
local Config = require(ReplicatedStorage.Shared.Config)
local CosmeticShopPanel = require(ReplicatedStorage.Shared.UI.CosmeticShopPanel)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Journal = require(ReplicatedStorage.Shared.UI.Journal)
local Daily = require(ReplicatedStorage.Shared.Daily)
local Missions = require(ReplicatedStorage.Shared.Data.Missions)
local PetRoll = require(ReplicatedStorage.Shared.PetRoll)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Mounts = require(ReplicatedStorage.Shared.Data.Mounts)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local SeasonPassPanel = require(ReplicatedStorage.Shared.UI.SeasonPassPanel)
local SettingsPanel = require(ReplicatedStorage.Shared.UI.SettingsPanel)
local RoleAbilities = require(ReplicatedStorage.Shared.RoleAbilities)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Talents = require(ReplicatedStorage.Shared.Data.Talents)
local Toast = require(ReplicatedStorage.Shared.UI.Toast)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)
local CalendarStrip = require(ReplicatedStorage.Shared.UI.CalendarStrip)
local EmoteWheel = require(ReplicatedStorage.Shared.UI.EmoteWheel)
local PlayerFrames = require(ReplicatedStorage.Shared.UI.PlayerFrames)
local WardrobePanel = require(ReplicatedStorage.Shared.UI.WardrobePanel)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

-- Alto de una fila (título y una línea de detalle): lo justo para que la Tienda o las Misiones quepan
-- sin desplazarse en un PC.
local ROW_HEIGHT = 68
-- En una pantalla baja (un teléfono apaisado) todo más apretado para que quepa más: filas más bajas
-- y textos con tope. Lo decide cada dibujo (render) con la pantalla de ese momento.
local ROW_HEIGHT_COMPACT = 52
local compactUi = false
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
-- Pantallas que tapa una ventana abierta: las del combate compartido (casillas de habilidades, combos
-- y los botones táctiles de las habilidades) y los controles táctiles de Roblox (joystick y salto).
local COMBAT_HUDS = { RoleHUD = true, ComboHUD = true, ActionButtons = true, TouchGui = true }
-- Nombre de la Isla en las frases y texto del botón de viaje.
local ISLAND = Config.PlaceNames.IslandShort
local JOIN_TEXT = `🍌 Ir a la {ISLAND} 🐒`
-- Segundos que se espera la segunda pulsación de "Descartar" (para no tirar un huevo sin querer).
local DISCARD_CONFIRM_SECONDS = 3
-- Nombre de cada dificultad de las misiones del día (Data/Missions).
local DIFFICULTY_NAMES = { Facil = "Fácil", Media = "Media", Dificil = "Difícil" }
-- Pantallas de menos alto que esto (un teléfono apaisado): la arena y las mascotas, compactas.
local COMPACT_BELOW = 500
-- Ventanas. Las de las estaciones (Rol, Arena, Mascotas, Ranking) se abren con su aviso; las del menú,
-- con su botón de la barra (MENU, en ese orden). "wide": más ancha, para las que van en columnas.
-- "spread": listas largas (compartidas con la Isla) que en PC se reparten en columnas si no caben.
-- "own": se colocan ellas mismas en columnas (no se reparten).
type WindowDef = { icon: string, title: string, wide: boolean?, spread: boolean?, own: boolean? }
local WINDOWS: { [string]: WindowDef } = {
	Rol = { icon = "⚔️", title = "Elige tu rol" },
	Arena = { icon = "", title = Config.PlaceNames.Dunas, own = true },
	Mascotas = { icon = "🥚", title = "Nido y mascotas", wide = true, own = true },
	Ranking = { icon = "🏆", title = "Ranking", wide = true, own = true },
	Talentos = { icon = "🌟", title = "Talentos" },
	Tienda = { icon = "🛒", title = "Tienda" },
	Misiones = { icon = "🎯", title = "Misiones" },
	-- El pase usa el ancho de las listas largas: sus pistas se deslizan y caben más columnas.
	Pase = { icon = "🌋", title = "Pase de temporada", wide = true, spread = true, own = true },
	-- El armario se coloca solo: el avatar en 3D a la izquierda y las tarjetas a la derecha.
	Armario = { icon = "👕", title = "Armario", wide = true, own = true },
	Grupo = { icon = "👥", title = "Grupo" },
	-- No es una ventana: su botón abre la rueda de emotes (UI/EmoteWheel).
	Emotes = { icon = "😀", title = "Emotes" },
	Diario = { icon = "📖", title = "Diario", wide = true, spread = true },
	Ajustes = { icon = "⚙️", title = "Ajustes", wide = true, spread = true },
}
local MENU = { "Talentos", "Tienda", "Misiones", "Pase", "Armario", "Emotes", "Grupo", "Diario", "Ajustes" }
-- Avisos de las estaciones de la plaza (World/LobbyBuilder) y la ventana que abre cada uno.
local STATION_PROMPTS: { [string]: string } = {
	RolesPrompt = "Rol",
	NidoPrompt = "Mascotas",
	ArenaPrompt = "Arena",
	ZarparDunasPrompt = "Arena",
	RankingPrompt = "Ranking",
	PassPrompt = "Pase",
}
-- La ventana de una estación se cierra sola a estos studs más allá del alcance de su aviso.
local STATION_CLOSE_MARGIN = 6
-- Ventana: ancho (fracción de la pantalla) y topes en píxeles; arriba van el título y la X, y el
-- contenido empieza en LIST_TOP. Su alto se ajusta a lo que tiene dentro (sin desplazarse en PC).
local WINDOW_WIDTH = 0.64
local WIDE_WIDTH = 0.9
local WINDOW_MAX_WIDTH = 700
local WIDE_MAX_WIDTH = 940
local WINDOW_TOP = 8
local LIST_TOP = 56
-- En una pantalla baja la ventana ocupa todo el ancho y el alto libres, con la cabecera más baja.
local WINDOW_TOP_COMPACT = 4
local LIST_TOP_COMPACT = 44
local WINDOW_MARGIN_COMPACT = 12
-- Barra del menú en columna (PC): debajo de las casillas de las habilidades (RoleHUD, de 118 a 164 px)
-- y de los combos (ComboHUD, de 170 a 232 px). Botones con el icono y su nombre debajo.
-- Con los 9 botones (G9c, "Emotes") a 48 de alto la columna cabe en una pantalla de 793 px de alto.
local BAR_TOP = 244
local BAR_BUTTON = Vector2.new(60, 48)
local BAR_GAP = 4
local INVITE_HEIGHT = 48
-- Barra en fila (táctil o pantalla baja): solo iconos, en la franja de la barra de Roblox.
local BAR_ROW_BUTTON = 44
local SQUARE_COLOR = Color3.fromRGB(40, 34, 28)
local BADGE_COLOR = Color3.fromRGB(235, 70, 60)
-- Aura que palpita alrededor de lo que conviene pulsar ahora (el atajo a los talentos): del rojo del
-- punto de aviso de la barra, se ensancha y se apaga en bucle.
local AURA_PULSE = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
-- El título grande se va a los pocos segundos de llegar (o al abrir una ventana).
local TITLE_SECONDS = 5
-- Ranking: las cuatro clasificaciones (LeaderboardService) en dos bloques, y cuántos puestos.
local RANKING_GROUPS = {
	{
		title = "🐒 Supervivencia",
		boards = {
			{ stat = "BestDays", title = "📅 Más días" },
			{ stat = "Rescues", title = "🚁 Más rescates" },
		},
	},
	{
		title = "🎖️ Arena",
		boards = {
			{ stat = "ArenaWins", title = "🏆 Más victorias" },
			{ stat = "ArenaCaptures", title = "🚩 Más banderas" },
		},
	},
}
local RANKING_SIZE = 10
local RANKING_LINE = 24
local RANKING_LINE_COMPACT = 16
local MEDALS = { "🥇", "🥈", "🥉" }
-- Listas largas ("spread"): ventana aún más ancha, columnas como mucho y hueco entre ellas.
local SPREAD_MAX_WIDTH = 1240
local MAX_COLUMNS = 4
-- Ninguna columna más estrecha que esto (en un teléfono, como mucho dos).
local MIN_COLUMN_WIDTH = 280
local COLUMN_GAP = 10
-- Margen a cada lado de la ventana para no tapar la barra del menú en columna (12 + 60 + 12 px).
local BAR_ROOM = 84
-- Mascotas: alto de cada tarjeta de la colección.
local PET_CARD_HEIGHT = 112
local PET_CARD_HEIGHT_COMPACT = 70

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

-- Espera larga ("3 d 4 h"; si falta menos de un día, como el tiempo del huevo).
local function longWait(seconds: number): string
	local days = seconds // 86400
	if days < 1 then
		return EggIncubation.formatTime(seconds)
	end
	return `{days} d {(seconds % 86400) // 3600} h`
end

-- Tope del tamaño de un texto con TextScaled.
local function textCap(object: GuiObject, max: number)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = max
	limit.Parent = object
end

local function newRow(parent: Instance, order: number): Row
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -10, 0, if compactUi then ROW_HEIGHT_COMPACT else ROW_HEIGHT)
	frame.BackgroundColor3 = ROW_COLOR
	frame.BackgroundTransparency = 0.15
	frame.Parent = parent
	corner(frame, 10)

	local title = Widgets.label("", frame)
	title.Position = UDim2.fromOffset(10, if compactUi then 3 else 5)
	title.Size = UDim2.new(0.68, -10, 0, if compactUi then 22 else 28)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local detail = Widgets.label("", frame)
	detail.Position = UDim2.fromOffset(10, if compactUi then 26 else 34)
	detail.Size = UDim2.new(0.68, -10, 0, if compactUi then 22 else 28)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextYAlignment = Enum.TextYAlignment.Top
	detail.TextWrapped = true
	detail.Font = Enum.Font.BuilderSans
	detail.TextColor3 = Color3.fromRGB(215, 205, 190)

	local button = Widgets.button("", frame)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.new(0.3, -10, 0, if compactUi then 36 else 50)
	local limit = button:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit:Destroy()
	end
	if compactUi then
		textCap(title, 16)
		textCap(detail, 12)
		textCap(button, 15)
	end
	return { frame = frame, title = title, detail = detail, button = button }
end

-- Aura roja que palpita en el borde de "object" (se para sola al destruirlo).
local function pulseAura(object: GuiObject, thickness: number)
	local aura = Instance.new("UIStroke")
	aura.Name = "Aura"
	aura.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	aura.Color = BADGE_COLOR
	aura.Thickness = thickness
	aura.Parent = object
	TweenService:Create(aura, AURA_PULSE, { Thickness = thickness * 2.5, Transparency = 0.7 }):Play()
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
	label.Size = UDim2.new(1, -10, 0, if compactUi then 22 else 34)
	label.TextColor3 = Color3.fromRGB(255, 220, 150)
	if compactUi then
		textCap(label, 14)
	end
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
	EmoteWheel.start()

	local playerGui = player:WaitForChild("PlayerGui")
	-- Barra del menú en fila (táctil o pantalla baja) en vez de en columna; lo decide placeHud.
	local rowMode = false

	local title = Widgets.label(Config.GameName, gui)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.02)
	title.Size = UDim2.fromScale(0.8, 0.08)

	local subtitle = Widgets.label(Config.Subtitle, gui)
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.fromScale(0.5, 0.1)
	subtitle.Size = UDim2.fromScale(0.5, 0.04)
	subtitle.TextColor3 = READY_COLOR

	-- El título del juego se funde y se va: solo hace falta al llegar.
	local titleGone = false
	local function hideTitle()
		if titleGone then
			return
		end
		titleGone = true
		local fade = TweenInfo.new(0.6)
		for _, label in { title, subtitle } do
			TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		task.delay(0.7, function()
			title.Visible = false
			subtitle.Visible = false
		end)
	end
	task.delay(TITLE_SECONDS, hideTitle)

	-- Pastilla con el Ámbar y el récord: siempre a la vista (la Tienda y el equipo de la arena se pagan
	-- con Ámbar). La coloca placeHud, en la franja de la barra de Roblox.
	local pill = Instance.new("Frame")
	pill.Name = "AmberPill"
	pill.BackgroundColor3 = PANEL_COLOR
	pill.BackgroundTransparency = 0.25
	pill.Parent = gui
	corner(pill, 14)
	local header = Widgets.label("", pill)
	header.Name = "Header"
	header.Position = UDim2.fromOffset(12, 4)
	header.Size = UDim2.new(1, -24, 1, -8)
	local headerLimit = Instance.new("UITextSizeConstraint")
	headerLimit.MaxTextSize = 22
	headerLimit.Parent = header
	local function refreshHeader()
		local amber = player:GetAttribute("Amber")
		local best = player:GetAttribute("BestDays")
		local amberText = if typeof(amber) == "number" then tostring(amber) else "…"
		local bestText = if typeof(best) == "number" then tostring(best) else "0"
		header.Text = if rowMode
			then `✨ {amberText}   🏆 {bestText} días`
			else `✨ {amberText} de Ámbar   🏆 Récord: {bestText} días`
	end
	refreshHeader()

	-- Ventana: una sola a la vez, con su título y la X; el contenido lo pone su función de dibujo.
	local panel = Instance.new("Frame")
	panel.Name = "Window"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, WINDOW_TOP)
	panel.Size = UDim2.new(WINDOW_WIDTH, 0, 0, 300)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.1
	-- Empieza cerrada para ver la plaza al llegar.
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(320, 120)
	sizeLimit.MaxSize = Vector2.new(WINDOW_MAX_WIDTH, math.huge)
	sizeLimit.Parent = panel

	local windowTitle = Widgets.label("", panel)
	windowTitle.Name = "Title"
	windowTitle.Position = UDim2.fromOffset(14, 8)
	-- Deja sitio a la X de cerrar, arriba a la derecha.
	windowTitle.Size = UDim2.new(1, -80, 0, 36)
	windowTitle.TextXAlignment = Enum.TextXAlignment.Left
	local windowTitleLimit = Instance.new("UITextSizeConstraint")
	windowTitleLimit.MaxTextSize = 26
	windowTitleLimit.Parent = windowTitle

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

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(8, LIST_TOP)
	list.Size = UDim2.new(1, -16, 1, -LIST_TOP - 8)
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

	-- Ventana abierta (nil = ninguna) y, si es de una estación, el aviso que la abrió (para cerrarla al
	-- alejarse).
	local currentWindow: string? = nil
	local windowPrompt: ProximityPrompt? = nil
	-- Sube con cada dibujo: lo que se hace un instante después (repartir en columnas) mira que siga
	-- siendo el mismo.
	local renderCount = 0
	-- Se ha elegido un rol con la ventana de roles abierta (enciende el aura del atajo a los talentos
	-- hasta cerrarla).
	local rolePicked = false
	-- Lo que deja libre la ventana abajo (en una pantalla baja, casi nada).
	local function windowBottomMargin(): number
		return if compactUi then 4 else 12
	end
	local render: () -> ()
	local openWindow: (id: string?, prompt: ProximityPrompt?) -> ()
	-- Fila del huevo del nido de la ventana Mascotas, que se actualiza cada segundo (tiempo y barra).
	type NestRow = { title: TextLabel, detail: TextLabel, fill: Frame, ready: boolean }
	local nestRow: NestRow? = nil
	-- Cuenta atrás del siguiente premio del calendario en la ventana Misiones (cada segundo).
	local calendarCountdown: TextButton? = nil
	-- Pestaña de la ventana Misiones ("Hoy" o "Semana") y de la Tienda ("Mejoras" o "Cosmeticos").
	local missionsTab = "Hoy"
	local shopTab = "Mejoras"
	-- Cuentas atrás de las tiendas de cosméticos (cada segundo).
	local shopTick: (() -> ())? = nil
	-- Cuenta atrás de la temporada en la ventana del pase (cada segundo).
	local passTick: (() -> ())? = nil
	-- Ventana Arena: formato elegido, rol cuyo equipo se ve, ranura abierta del equipo y la línea que
	-- dice cuánto llevas en la cola (se actualiza cada segundo).
	local arenaFormat = 1
	local arenaRole: string? = nil
	local arenaSlot: string? = nil
	local arenaQueueLine: TextLabel? = nil

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
			-- Más alta: la pasiva y las habilidades ocupan varias líneas. En una pantalla baja, con el
			-- botón más estrecho, para que el texto no encoja hasta no leerse.
			if compactUi then
				row.frame.Size = UDim2.new(1, -10, 0, ROW_HEIGHT_COMPACT + 34)
				row.detail.Size = UDim2.new(0.72, -10, 0, 56)
				row.title.Size = UDim2.new(0.72, -10, 0, 22)
				row.button.Size = UDim2.new(0.26, -10, 0, 36)
			else
				row.frame.Size = UDim2.new(1, -10, 0, ROW_HEIGHT + 22)
				row.detail.Size = UDim2.new(0.68, -10, 0, 52)
			end
			row.title.Text = `{role.icon} {role.name} · nivel {Progression.level(xp)}`
			local names = {}
			for _, ability in RoleAbilities.of(player, roleId) do
				table.insert(names, if ability.ultimate then `definitiva: {ability.name}` else ability.name)
			end
			row.detail.Text = `{role.passive}\nHabilidades: {table.concat(names, " · ")}`
			local isSelected = roleId == selected
			setButton(row.button, if isSelected then "Elegido" else "Elegir", not isSelected)
			row.button.MouseButton1Click:Connect(function()
				Remotes.SelectRole:FireServer(roleId)
				-- Al cambiar de rol, el atajo a sus talentos se ilumina para invitar a mirarlos.
				rolePicked = true
			end)
		end
		-- Atajo a los talentos del rol elegido (también están en la barra del menú).
		local role = Roles[selected]
		local points = Progression.freePoints(selected, data)
		local talents = newRow(list, 10)
		talents.title.Text = `🌟 Talentos de {role.name}`
		talents.detail.Text = if points > 0
			then `Tienes {points} punto(s) libre(s) para aprender`
			else "Mejora tu rol con los puntos que ganas al subir de nivel"
		setButton(talents.button, if points > 0 then `Ver talentos ({points})` else "Ver talentos", true)
		talents.button.MouseButton1Click:Connect(function()
			openWindow("Talentos")
		end)
		-- Con puntos por gastar, o recién elegido el rol, el atajo palpita con un aura roja.
		if points > 0 or rolePicked then
			pulseAura(talents.frame, 2)
			pulseAura(talents.button, 2)
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
		-- La definitiva (V) que lleva con este rol (T7): una fila por cada una que puede elegir.
		local chosen = RoleAbilities.chosenUltimate(player, roleId)
		for index, ability in RoleAbilities.ultimates(roleId) do
			local row = newRow(list, 20 + index)
			local isChosen = ability.id == chosen
			row.title.Text = `⭐ V: {ability.name}`
			row.detail.Text = ability.description
			setButton(row.button, if isChosen then "Elegida" else "Elegir", not isChosen)
			row.button.MouseButton1Click:Connect(function()
				Remotes.SelectUltimate:FireServer(roleId, ability.id)
			end)
		end
	end

	local function renderUpgrades(data: Progression.ProgressData)
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
	local function twoButtonRow(parent: Instance, order: number): (Row, TextButton)
		local row = newRow(parent, order)
		local buttonHeight = if compactUi then 36 else 50
		row.title.Size = UDim2.new(0.46, -10, 0, row.title.Size.Y.Offset)
		row.detail.Size = UDim2.new(0.46, -10, 0, row.detail.Size.Y.Offset)
		row.button.Size = UDim2.new(0.25, -10, 0, buttonHeight)
		local second = Widgets.button("", row.frame)
		second.AnchorPoint = Vector2.new(1, 0.5)
		second.Position = UDim2.new(0.75, -10, 0.5, 0)
		second.Size = UDim2.new(0.27, -10, 0, buttonHeight)
		second.BackgroundColor3 = CLOSE_COLOR
		second.TextColor3 = Color3.new(1, 1, 1)
		local limit = second:FindFirstChildOfClass("UISizeConstraint")
		if limit then
			limit:Destroy()
		end
		if compactUi then
			textCap(second, 14)
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

	-- Nido de huevos, en la columna izquierda de la ventana Mascotas.
	local function renderNest(parent: Instance)
		local eggs = readEggs()
		nestRow = nil
		note(parent, "🥚 Tu nido: solo avanza el huevo que está en él (también sin jugar)", -100)

		local nestEgg = eggs.nest
		local row = newRow(parent, -99)
		if nestEgg then
			local rarity = Rarities[nestEgg.rarity]
			row.title.TextColor3 = rarity.color
			-- Más alta que una fila normal: la barra va debajo del detalle, sin taparlo.
			row.frame.Size = UDim2.new(1, -10, 0, row.frame.Size.Y.Offset + 12)
			local track = Instance.new("Frame")
			track.Position = UDim2.new(0, 10, 1, -10)
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
					-- Se cierra la ventana para ver la ceremonia en el nido.
					openWindow(nil)
					Remotes.HatchEgg:FireServer()
				end)
			end

			-- Lo que puede salir de esta rareza (las que ya tienes, con ✅). Una repetida da Ámbar.
			local data = Progression.read(player)
			local names = {}
			local missingPets, missingMounts = 0, 0
			for _, petId in PetRoll.petsOfRarity(nestEgg.rarity) do
				local pet = Pets[petId]
				local owned = (data.pets[petId] or 0) > 0
				missingPets += if owned then 0 else 1
				table.insert(names, `{pet.icon} {pet.name}{if owned then " ✅" else ""}`)
			end
			-- Y sus monturas (Fase 11), mientras no las tengas.
			for _, mountId in PetRoll.mountsOfRarity(nestEgg.rarity) do
				local mount = Mounts[mountId]
				local owned = (data.mounts[mountId] or 0) > 0
				missingMounts += if owned then 0 else 1
				table.insert(names, `{mount.icon} {mount.name} (montura){if owned then " ✅" else ""}`)
			end
			local options = newRow(parent, -98)
			options.title.Text = `Puede salir ({rarity.name}):`
			if missingPets == 0 then
				-- Ya las tiene todas: lo dice antes de abrirlo (y si aún puede salir una montura).
				local amber = Config.Egg.DuplicateAmber[nestEgg.rarity] or 0
				options.title.Text = if missingMounts > 0
					then `{rarity.name}: ya tienes todas sus mascotas (repetida: +{amber} ✨) · aún puede salir montura`
					else `{rarity.name}: ya tienes todas · te dará +{amber} ✨ Ámbar`
			end
			options.title.TextColor3 = rarity.color
			options.detail.Text = table.concat(names, " · ")
			options.detail.Size = UDim2.new(1, -20, 0, options.detail.Size.Y.Offset)
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
				local eggRow, discard = twoButtonRow(parent, firstOrder + index)
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
		note(parent, `🎒 Mochila de huevos ({#eggs.bag}/{Config.Egg.BagSize}): esperan sin avanzar`, -90)
		eggRows("bag", eggs.bag, -90)
		for slot = #eggs.bag + 1, Config.Egg.BagSize do
			local empty = newRow(parent, -90 + slot)
			empty.frame.Size = UDim2.new(1, -10, 0, if compactUi then 30 else 40)
			empty.title.Text = "Casilla libre"
			empty.title.TextColor3 = Color3.fromRGB(160, 150, 135)
			empty.detail.Visible = false
			empty.button.Visible = false
		end
		if #eggs.pending > 0 then
			note(parent, "⚠️ Mochila llena: estos huevos esperan a que decidas", -80)
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

	-- Fila de pestañas de una ventana: botones de 8 px de esquina, la elegida en dorado. Tocar otra la
	-- elige ("pick") y rehace la ventana.
	type WindowTab = { id: string, text: string }
	local function windowTabs(name: string, tabs: { WindowTab }, chosenId: string, pick: (string) -> ())
		local row = Instance.new("Frame")
		row.Name = name
		row.LayoutOrder = -1
		row.Size = UDim2.new(1, -10, 0, if compactUi then 34 else 44)
		row.BackgroundTransparency = 1
		row.Parent = list
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row
		for index, tab in tabs do
			local button = Instance.new("TextButton")
			button.Name = `Tab{tab.id}`
			button.LayoutOrder = index
			button.Size = UDim2.new(1 / #tabs, -6 * (#tabs - 1) / #tabs, 1, 0)
			button.Text = tab.text
			button.Font = Enum.Font.BuilderSansBold
			button.TextScaled = true
			local chosen = tab.id == chosenId
			button.BackgroundColor3 = if chosen then READY_COLOR else ROW_COLOR
			button.TextColor3 = if chosen then Color3.fromRGB(40, 25, 5) else Color3.new(1, 1, 1)
			button.Parent = row
			corner(button, 8)
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, 6)
			padding.PaddingBottom = UDim.new(0, 6)
			padding.Parent = button
			button.MouseButton1Click:Connect(function()
				if tab.id ~= chosenId then
					pick(tab.id)
					render()
				end
			end)
		end
	end

	-- Pestañas de la ventana Misiones: "Hoy" (calendario, misiones del día y provisiones) y "Semana".
	local function missionTabs(weeklyDone: number, weeklyTotal: number)
		windowTabs(
			"MissionTabs",
			{ { id = "Hoy", text = "📅 Hoy" }, { id = "Semana", text = `📆 Semana ({weeklyDone}/{weeklyTotal})` } },
			missionsTab,
			function(id)
				missionsTab = id
			end
		)
	end

	-- Ventana Tienda: las mejoras con Ámbar o las tiendas de cosméticos (UI/CosmeticShopPanel).
	local function renderShop(data: Progression.ProgressData)
		windowTabs(
			"ShopTabs",
			{ { id = "Mejoras", text = "✨ Mejoras" }, { id = "Cosmeticos", text = "🎨 Cosméticos" } },
			shopTab,
			function(id)
				shopTab = id
			end
		)
		if shopTab == "Cosmeticos" then
			shopTick = CosmeticShopPanel.build(list, { compact = compactUi })
		else
			renderUpgrades(data)
		end
	end

	-- Filas de misiones (del día o de la semana): lo que piden, lo que llevas, su clase y su premio, y
	-- "🔄 Cambiar" mientras quede un cambio gratis (pide un segundo toque para no gastarlo sin querer);
	-- sin cambio, el botón enseña lo que llevas.
	local function missionRows(
		scope: "daily" | "weekly",
		missions: { Daily.DailyMission },
		canReroll: boolean,
		firstOrder: number
	)
		for index, mission in missions do
			local definition = Missions[mission.id]
			local row = newRow(list, firstOrder + index)
			local progress = if mission.done
				then "✅ Cumplida"
				else `{math.floor(mission.progress)}/{definition.target}`
			row.title.Text = Daily.missionText(mission.id)
			row.title.TextColor3 = if mission.done then Color3.fromRGB(120, 230, 140) else Color3.new(1, 1, 1)
			local parts = { if mission.done then "✅" else progress }
			if not definition.weekly then
				local class = DIFFICULTY_NAMES[definition.difficulty or "Facil"]
				table.insert(parts, if definition.role then `{class} (tu rol)` else class)
			end
			table.insert(parts, Rewards.compact(definition.reward))
			row.detail.Text = table.concat(parts, " · ")
			if mission.done or not canReroll then
				setButton(row.button, progress, false)
				continue
			end
			setButton(row.button, "🔄 Cambiar", true)
			local armedUntil = 0
			row.button.MouseButton1Click:Connect(function()
				if os.clock() < armedUntil then
					armedUntil = 0
					setButton(row.button, "Cambiando…", false)
					Remotes.RerollMission:FireServer(scope, index)
					return
				end
				armedUntil = os.clock() + DISCARD_CONFIRM_SECONDS
				row.button.Text = "¿Seguro?"
				task.delay(DISCARD_CONFIRM_SECONDS, function()
					if row.button.Parent and row.button.Active then
						row.button.Text = "🔄 Cambiar"
					end
				end)
			end)
		end
	end

	-- Ventana Misiones. "Hoy": el calendario de 7 días (el mismo que la ventana del CalendarController),
	-- las misiones del día y las provisiones. "Semana": las semanales y el extra por cumplirlas todas.
	local function renderMissions()
		local retention = readRetention()
		local now = EggIncubation.now()
		local weekly = Daily.weeklyState(retention.weekly)
		local weeklyDone = 0
		for _, mission in weekly.missions do
			weeklyDone += if mission.done then 1 else 0
		end
		missionTabs(weeklyDone, #weekly.missions)

		if missionsTab == "Semana" then
			local rerolls = math.max(0, Config.Daily.WeeklyRerolls - weekly.rerolls)
			note(
				list,
				`📆 Misiones de la semana: en la {ISLAND} y en la {Config.PlaceNames.DunasShort} (cambian en {longWait(
					Daily.secondsToWeekReset(now)
				)}){if rerolls > 0 then ` · 🔄 {rerolls} cambio gratis` else ""}`,
				1
			)
			missionRows("weekly", weekly.missions, rerolls > 0, 1)
			local bonus = newRow(list, 20)
			bonus.title.Text = `🏅 Extra por cumplir las {#weekly.missions}`
			bonus.title.TextColor3 = Color3.fromRGB(255, 205, 70)
			bonus.detail.Text = `{weeklyDone}/{#weekly.missions} · {Rewards.compact(Config.Daily.WeeklyBonus)}`
			setButton(bonus.button, if weekly.bonus then "✅ Cobrado" else "Pendiente", false)
			return
		end

		local login = Daily.loginState(retention.login)
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

		-- Misiones del día: se cumplen en la Isla; aquí se ve cómo van, qué dan y se pueden cambiar.
		local state = Daily.missionState(retention.daily)
		local rerolls = math.max(0, Config.Daily.DailyRerolls - state.rerolls)
		note(
			list,
			`🎯 Misiones de hoy: se cumplen en la {ISLAND} (cambian en {EggIncubation.formatTime(
				Daily.secondsToReset(now)
			)}){if rerolls > 0 then ` · 🔄 {rerolls} cambio gratis` else ""}`,
			3
		)
		missionRows("daily", state.missions, rerolls > 0, 3)

		local items = Rewards.describeItems(Rewards.sanitizeItems(retention.supplies))
		local supplies = newRow(list, 10)
		supplies.title.Text = "🎒 Provisiones para tu próxima partida"
		supplies.detail.Text = if items ~= ""
			then items
			else "Ninguna por ahora: llegan con el calendario y las misiones"
		supplies.detail.Size = UDim2.new(1, -20, 0, 34)
		supplies.button.Visible = false
	end

	-- Columna de la ventana (crece con lo que lleva dentro).
	local function pane(parent: Instance, order: number, width: UDim): Frame
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(width, UDim.new(0, 0))
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Parent = parent
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.Parent = frame
		return frame
	end

	-- Ventana Mascotas: a la izquierda el nido y la mochila; a la derecha la colección en tarjetas (las
	-- que tienes se pueden llevar, 1 activa; las demás salen como "???"). En un teléfono, una debajo de
	-- la otra.
	local function renderPets(data: Progression.ProgressData)
		local compact = compactUi
		local holder = Instance.new("Frame")
		holder.LayoutOrder = 1
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -10, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.Parent = list
		local holderLayout = Instance.new("UIListLayout")
		holderLayout.FillDirection = Enum.FillDirection.Horizontal
		holderLayout.Padding = UDim.new(0, 10)
		holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
		holderLayout.Parent = holder
		local nestPane = pane(holder, 1, UDim.new(0.47, -5))
		local petsPane = pane(holder, 2, UDim.new(0.53, -5))

		renderNest(nestPane)
		local active = player:GetAttribute("ActivePet")
		note(petsPane, "🐾 Tu colección: las mascotas nacen de los huevos del nido", 0)
		local grid = Instance.new("Frame")
		grid.LayoutOrder = 1
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, -10, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.Parent = petsPane
		local gridLayout = Instance.new("UIGridLayout")
		-- En una pantalla baja, tres columnas de tarjetas sin la descripción (no cabría legible).
		local columns = 3
		gridLayout.CellSize =
			UDim2.new(1 / columns, -6, 0, if compact then PET_CARD_HEIGHT_COMPACT else PET_CARD_HEIGHT)
		gridLayout.CellPadding = UDim2.fromOffset(6, 6)
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.Parent = grid

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
			local isActive = active == petId
			local card = Instance.new("Frame")
			card.LayoutOrder = index
			card.BackgroundColor3 = ROW_COLOR
			card.BackgroundTransparency = 0.15
			card.Parent = grid
			corner(card, 10)
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = READY_COLOR
			stroke.Thickness = 2
			stroke.Enabled = isActive
			stroke.Parent = card
			local name = Widgets.label(if owned > 0 then `{pet.icon} {pet.name}` else "❓ ???", card)
			name.Position = UDim2.fromOffset(6, if compact then 3 else 4)
			name.Size = UDim2.new(1, -12, 0, if compact then 18 else 22)
			name.TextColor3 = rarity.color
			textCap(name, if compact then 15 else 18)
			local detail = Widgets.label(
				if owned > 0
					then `{rarity.name} · {pet.kind}{if compact then "" else "\n" .. pet.description}`
					else `{rarity.name}{if compact then "" else "\nAún no la tienes"}`,
				card
			)
			detail.Position = UDim2.fromOffset(6, if compact then 21 else 28)
			detail.Size = UDim2.new(1, -12, 0, if compact then 14 else 42)
			detail.Font = Enum.Font.BuilderSans
			detail.TextWrapped = true
			detail.TextYAlignment = Enum.TextYAlignment.Top
			detail.TextColor3 = Color3.fromRGB(215, 205, 190)
			textCap(detail, if compact then 11 else 13)
			local button = Widgets.button("", card)
			button.AnchorPoint = Vector2.new(0.5, 1)
			button.Position = UDim2.new(0.5, 0, 1, if compact then -4 else -6)
			button.Size = UDim2.new(1, -12, 0, if compact then 28 else 34)
			if compact then
				textCap(button, 14)
			end
			local limit = button:FindFirstChildOfClass("UISizeConstraint")
			if limit then
				limit:Destroy()
			end
			if owned > 0 then
				setButton(button, if isActive then "Quitar" else "Llevar", true)
				button.MouseButton1Click:Connect(function()
					Remotes.SelectPet:FireServer(if isActive then "" else petId)
				end)
			else
				setButton(button, "—", false)
			end
		end

		-- Monturas (Fase 11): una fila por montura, con su botón para llevarla (se monta con N).
		local activeMount = player:GetAttribute("ActiveMount")
		note(petsPane, "🦙 Monturas: llévala y móntala con N (o el botón Montar)", 2)
		local mountIds = {}
		for mountId in Mounts do
			table.insert(mountIds, mountId)
		end
		table.sort(mountIds, function(a, b)
			return Mounts[a].name < Mounts[b].name
		end)
		for index, mountId in mountIds do
			local mount = Mounts[mountId]
			local rarity = Rarities[mount.rarity]
			local owned = (data.mounts[mountId] or 0) > 0
			local isActive = activeMount == mountId
			local row = Instance.new("Frame")
			row.LayoutOrder = 2 + index
			row.BackgroundColor3 = ROW_COLOR
			row.BackgroundTransparency = 0.15
			row.Size = UDim2.new(1, -10, 0, if compact then 34 else 44)
			row.Parent = petsPane
			corner(row, 10)
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = READY_COLOR
			stroke.Thickness = 2
			stroke.Enabled = isActive
			stroke.Parent = row
			-- Las que no salen de los huevos normales (origin) se ven con su nombre y un candado; las demás, ocultas.
			local shortName = string.match(mount.name, "^[^,]+") or mount.name
			local name = Widgets.label(
				if owned
					then `{mount.icon} {mount.name} · {rarity.name}`
					elseif mount.origin then `🔒 {shortName} · {rarity.name}`
					else `❓ ??? · {rarity.name}`,
				row
			)
			name.Position = UDim2.fromOffset(8, 0)
			name.Size = UDim2.new(0.62, -8, 1, 0)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextColor3 = rarity.color
			textCap(name, if compact then 14 else 17)
			local button = Widgets.button("", row)
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -6, 0.5, 0)
			button.Size = UDim2.new(0.38, -6, 1, -8)
			local limit = button:FindFirstChildOfClass("UISizeConstraint")
			if limit then
				limit:Destroy()
			end
			if owned then
				setButton(button, if isActive then "Quitar" else "Llevar", true)
				button.MouseButton1Click:Connect(function()
					Remotes.SelectMount:FireServer(if isActive then "" else mountId)
				end)
			else
				setButton(button, mount.origin or "Sale de los huevos", false)
			end
		end
	end

	-- Clasificaciones globales (las publica LeaderboardService cada pocos minutos): dos bloques,
	-- supervivencia y arena, con dos columnas cada uno, y abajo tu número en cada una. El puesto exacto
	-- fuera del top no se sabe (OrderedDataStore no lo da): se enseña tu valor.
	local function renderRanking()
		local arenaRaw = player:GetAttribute("Arena")
		local okArena, arenaData = pcall(function()
			return if typeof(arenaRaw) == "string" then HttpService:JSONDecode(arenaRaw) else {}
		end)
		local arenaStats = if okArena
				and typeof(arenaData) == "table"
				and typeof(arenaData.stats) == "table"
			then arenaData.stats
			else {}
		local mine: { [string]: any } = {
			BestDays = player:GetAttribute("BestDays"),
			Rescues = player:GetAttribute("Rescues"),
			ArenaWins = arenaStats.wins,
			ArenaCaptures = arenaStats.captures,
		}
		local lineHeight = if compactUi then RANKING_LINE_COMPACT else RANKING_LINE
		local columnHeight = 24 + RANKING_SIZE * lineHeight + 26
		local holder = Instance.new("Frame")
		holder.LayoutOrder = 1
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -10, 0, 30 + columnHeight + 6)
		holder.Parent = list
		local holderLayout = Instance.new("UIListLayout")
		holderLayout.FillDirection = Enum.FillDirection.Horizontal
		holderLayout.Padding = UDim.new(0, 10)
		holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
		holderLayout.Parent = holder
		for groupIndex, group in RANKING_GROUPS do
			local block = Instance.new("Frame")
			block.LayoutOrder = groupIndex
			block.Size = UDim2.new(0.5, -5, 1, 0)
			block.BackgroundColor3 = ROW_COLOR
			block.BackgroundTransparency = 0.15
			block.Parent = holder
			corner(block, 10)
			local blockTitle = Widgets.label(group.title, block)
			blockTitle.Position = UDim2.fromOffset(8, 3)
			blockTitle.Size = UDim2.new(1, -16, 0, 24)
			blockTitle.TextColor3 = READY_COLOR
			for column, board in group.boards do
				local frame = Instance.new("Frame")
				frame.BackgroundTransparency = 1
				frame.Position = UDim2.new((column - 1) * 0.5, 8, 0, 30)
				frame.Size = UDim2.new(0.5, -12, 0, columnHeight)
				frame.Parent = block
				local boardTitle = Widgets.label(board.title, frame)
				boardTitle.Size = UDim2.new(1, 0, 0, 20)
				boardTitle.TextXAlignment = Enum.TextXAlignment.Left
				boardTitle.TextColor3 = Color3.fromRGB(255, 220, 150)
				local raw = ReplicatedStorage:GetAttribute(`Leaderboard_{board.stat}`)
				local ok, rows = pcall(function()
					return if typeof(raw) == "string" then HttpService:JSONDecode(raw) else {}
				end)
				local entries = if ok and typeof(rows) == "table" then rows else {}
				for position = 1, RANKING_SIZE do
					local entry = entries[position]
					local place = MEDALS[position] or `{position}.`
					local line = Widgets.label(
						if entry
							then `{place} {entry.name} — {entry.value}`
							elseif position == 1 then "Aún no hay datos"
							else "",
						frame
					)
					line.Position = UDim2.fromOffset(0, 24 + (position - 1) * lineHeight)
					line.Size = UDim2.new(1, 0, 0, lineHeight - 2)
					line.TextXAlignment = Enum.TextXAlignment.Left
					line.Font = Enum.Font.BuilderSans
					if entry and entry.name == player.Name then
						line.TextColor3 = READY_COLOR
						line.Font = Enum.Font.BuilderSansBold
					end
					-- El marco que lleva puesto (Shared/UI/PlayerFrames), con el nombre un poco hacia dentro.
					if entry and PlayerFrames.has(entry.frame) then
						PlayerFrames.apply(line, entry.frame)
						corner(line, 6)
						local inset = Instance.new("UIPadding")
						-- Las piezas de las esquinas no pisan la medalla.
						inset.PaddingLeft = UDim.new(0, 12)
						inset.Parent = line
					end
					textCap(line, if compactUi then 13 else 17)
				end
				local value = mine[board.stat]
				local you = Widgets.label(`Tú: {if typeof(value) == "number" then value else 0}`, frame)
				you.Position = UDim2.new(0, 0, 1, -24)
				you.Size = UDim2.new(1, 0, 0, 22)
				you.TextXAlignment = Enum.TextXAlignment.Left
				you.TextColor3 = READY_COLOR
				local youLimit = Instance.new("UITextSizeConstraint")
				youLimit.MaxTextSize = 18
				youLimit.Parent = you
			end
		end
		note(list, "Se actualiza cada pocos minutos", 2)
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
			row.title.Text = if isLeader then "Eres el líder" else `Viajan cuando el líder presione "{JOIN_TEXT}"`
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
				local frameId = other:GetAttribute("Frame")
				PlayerFrames.apply(row.frame, if typeof(frameId) == "string" then frameId else nil)
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
		local compact = compactUi

		-- En una pantalla baja, dos columnas para verlo todo a la vez (como en Dunas): a la izquierda
		-- formato, cola, tus números y los roles; a la derecha el equipo.
		local left: Instance = list
		local right: Instance = list
		if compact then
			local holder = Instance.new("Frame")
			holder.LayoutOrder = 1
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.new(1, -10, 0, 0)
			holder.AutomaticSize = Enum.AutomaticSize.Y
			holder.Parent = list
			local holderLayout = Instance.new("UIListLayout")
			holderLayout.FillDirection = Enum.FillDirection.Horizontal
			holderLayout.Padding = UDim.new(0, 10)
			holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
			holderLayout.Parent = holder
			left = pane(holder, 1, UDim.new(0.44, -5))
			right = pane(holder, 2, UDim.new(0.56, -5))
		end

		-- Formatos y "Buscar partida" (en compacto, el botón en su propia fila).
		local formatRow = Instance.new("Frame")
		formatRow.LayoutOrder = 1
		formatRow.Size = UDim2.new(1, if compact then 0 else -10, 0, if compact then 36 else 50)
		formatRow.BackgroundTransparency = 1
		formatRow.Parent = left
		local formatLayout = Instance.new("UIListLayout")
		formatLayout.FillDirection = Enum.FillDirection.Horizontal
		formatLayout.Padding = UDim.new(0, 6)
		formatLayout.SortOrder = Enum.SortOrder.LayoutOrder
		formatLayout.Parent = formatRow
		local shownFormat = if queue then tonumber(queue.format) or arenaFormat else arenaFormat
		for format = Config.Arena.MinFormat, Config.Arena.MaxFormat do
			local button = Instance.new("TextButton")
			button.LayoutOrder = format
			button.Size = UDim2.new(if compact then 0.2 else 0.1, -6, 1, 0)
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
		local search = Widgets.button("", if compact then left else formatRow)
		search.LayoutOrder = if compact then 2 else 99
		search.Size = if compact then UDim2.new(1, 0, 0, 40) else UDim2.new(0.5, -6, 1, 0)
		if compact then
			textCap(search, 18)
		end
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
		local status = Widgets.label("", left)
		status.LayoutOrder = 3
		status.Size = UDim2.new(1, if compact then 0 else -10, 0, if compact then 30 else 24)
		status.TextColor3 = Color3.fromRGB(255, 220, 150)
		status.TextWrapped = true
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
		local roleCards = ArenaRoleCards.new(left, 4, if compact then 40 else 44, compact, function(id)
			arenaRole = id
			render()
		end)
		roleCards.frame.Size = UDim2.new(1, if compact then 0 else -10, 0, roleCards.frame.Size.Y.Offset)
		roleCards.update(roleId)

		-- Equipo de la arena de ese rol.
		local picker = ArenaGearPicker.new(
			right,
			5,
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

	-- Reparte lo que hay dentro de "source" (por su orden) en las columnas justas para que quepa en
	-- "room" píxeles de alto, llenando cada una hasta su parte del total. Los altos se miden ya con el
	-- ancho de la columna (un texto estrecho ocupa más líneas), así que se espera a que Roblox los
	-- calcule; si entretanto se vuelve a dibujar la ventana, lo deja.
	local function spreadColumns(source: Instance, room: number, thisRender: number)
		local layout = source:FindFirstChildOfClass("UIListLayout")
		if not layout then
			return
		end
		local gap = layout.Padding.Offset
		local maxColumns = math.clamp(math.floor(list.AbsoluteSize.X / MIN_COLUMN_WIDTH), 1, MAX_COLUMNS)
		if maxColumns < 2 then
			return
		end
		local items: { GuiObject } = {}
		for _, child in source:GetChildren() do
			if child:IsA("GuiObject") then
				table.insert(items, child)
			end
		end
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		local panes: { Frame } = {}
		for index = 1, maxColumns do
			local column = Instance.new("Frame")
			column.Name = `Column{index}`
			column.LayoutOrder = index
			column.BackgroundTransparency = 1
			column.AutomaticSize = Enum.AutomaticSize.Y
			local columnLayout = Instance.new("UIListLayout")
			columnLayout.SortOrder = Enum.SortOrder.LayoutOrder
			columnLayout.Padding = layout.Padding
			columnLayout.Parent = column
			panes[index] = column
		end
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, COLUMN_GAP)
		local count = 2
		local heights: { number } = {}
		local total = 0
		-- Cuántas columnas hacen falta, en orden, si ninguna pasa de "limit" (reparto voraz).
		local function columnsFor(limit: number): number
			local used, filled = 1, 0
			for _, height in heights do
				if filled > 0 and filled + height > limit then
					used += 1
					filled = 0
				end
				filled += height
			end
			return used
		end
		while true do
			-- Todo en la primera columna, con el ancho que tendrá, para medirlo.
			for index, column in panes do
				column.Size = UDim2.new(1 / count, -COLUMN_GAP, 0, 0)
				column.Parent = if index <= count then source else nil
			end
			for _, item in items do
				item.Parent = panes[1]
			end
			RunService.Heartbeat:Wait()
			if thisRender ~= renderCount then
				return
			end
			total = 0
			for index, item in items do
				heights[index] = item.AbsoluteSize.Y + gap
				total += heights[index]
			end
			if columnsFor(room) <= count or count >= maxColumns then
				break
			end
			count += 1
		end
		-- El alto de columna más bajo con el que todo cabe en "count" columnas (búsqueda binaria).
		local low, high = 0, total
		for _, height in heights do
			low = math.max(low, height)
		end
		while high - low > 1 do
			local middle = (low + high) / 2
			if columnsFor(middle) <= count then
				high = middle
			else
				low = middle
			end
		end
		local index, filled = 1, 0
		for position, item in items do
			local height = heights[position]
			if filled > 0 and filled + height > high and index < count then
				index += 1
				filled = 0
			end
			item.Parent = panes[index]
			filled += height
		end
	end

	function render()
		local id = currentWindow
		if not id then
			return
		end
		local window = WINDOWS[id]
		-- Las tiendas de cosméticos van en tarjetas: más ancha y colocada por su panel.
		if id == "Tienda" and shopTab == "Cosmeticos" then
			window = { icon = window.icon, title = window.title, wide = true, own = true }
		end
		compactUi = Workspace.CurrentCamera.ViewportSize.Y < COMPACT_BELOW
		windowTitle.Text = if window.icon ~= "" then `{window.icon} {window.title}` else window.title
		-- En una pantalla baja, todo el ancho y el alto libres; si no, centrada con su ancho.
		local top = if compactUi then WINDOW_TOP_COMPACT else WINDOW_TOP
		local listTop = if compactUi then LIST_TOP_COMPACT else LIST_TOP
		panel.Position = UDim2.new(0.5, 0, 0, top)
		windowTitle.Position = UDim2.fromOffset(14, if compactUi then 6 else 8)
		windowTitle.Size = UDim2.new(1, -80, 0, if compactUi then 30 else 36)
		windowTitleLimit.MaxTextSize = if compactUi then 20 else 26
		closeButton.Size = if compactUi then UDim2.fromOffset(38, 38) else UDim2.fromOffset(44, 44)
		closeButton.Position = UDim2.new(1, -8, 0, if compactUi then 3 else 6)
		list.Position = UDim2.fromOffset(8, listTop)
		list.Size = UDim2.new(1, -16, 1, -listTop - 8)
		local widthScale = if compactUi then 1 elseif window.wide then WIDE_WIDTH else WINDOW_WIDTH
		panel.Size = UDim2.new(widthScale, 0, panel.Size.Y.Scale, panel.Size.Y.Offset)
		local maxWidth = if window.spread
			then SPREAD_MAX_WIDTH
			elseif window.wide then WIDE_MAX_WIDTH
			else WINDOW_MAX_WIDTH
		if compactUi then
			maxWidth = gui.AbsoluteSize.X - 2 * WINDOW_MARGIN_COMPACT
		elseif not rowMode then
			maxWidth = math.min(maxWidth, gui.AbsoluteSize.X - 2 * BAR_ROOM)
		end
		sizeLimit.MaxSize = Vector2.new(maxWidth, math.huge)

		renderCount += 1
		local thisRender = renderCount
		-- El pase se viste de volcán (fondo y marco); cualquier otra ventana lo quita.
		if id ~= "Pase" then
			SeasonPassPanel.close()
		end
		clearRows(list)
		listLayout.FillDirection = Enum.FillDirection.Vertical
		listLayout.Padding = UDim.new(0, 6)
		nestRow = nil
		calendarCountdown = nil
		passTick = nil
		shopTick = nil
		arenaQueueLine = nil
		local data = Progression.read(player)
		if id == "Rol" then
			renderRoles(data)
		elseif id == "Arena" then
			renderArena()
		elseif id == "Talentos" then
			renderTalents(data)
		elseif id == "Tienda" then
			renderShop(data)
		elseif id == "Mascotas" then
			renderPets(data)
		elseif id == "Misiones" then
			renderMissions()
		elseif id == "Pase" then
			passTick = SeasonPassPanel.build(list, { compact = compactUi, window = panel, title = windowTitle })
		elseif id == "Armario" then
			WardrobePanel.build(list, { compact = compactUi, rebuild = render })
		elseif id == "Ranking" then
			renderRanking()
		elseif id == "Diario" then
			Journal.fill(list, data.bestiary)
		elseif id == "Ajustes" then
			SettingsPanel.build(list, "Lobby")
		else
			renderParty()
		end

		-- Una ventana que no cabe en la pantalla se reparte en columnas cuando ya tiene su alto (un
		-- instante después: los altos automáticos aún no están calculados). Las que se colocan solas
		-- ("own") no.
		if not window.own then
			task.defer(function()
				RunService.Heartbeat:Wait()
				if thisRender ~= renderCount then
					return
				end
				local room = gui.AbsoluteSize.Y - windowBottomMargin() - top - listTop - 10
				if listLayout.AbsoluteContentSize.Y > room then
					-- Ajustes es un solo marco con sus apartados dentro: se reparten los apartados.
					local settings = list:FindFirstChild("SettingsPanel")
					spreadColumns(settings or list, room, thisRender)
				end
			end)
		end
	end

	-- Botón de viaje (y el bote del naufragio, que hace lo mismo): encima de la barra de objetos de
	-- Roblox, que abajo en el centro lleva las armas del rol para probarlas en la plaza. Con una ventana
	-- abierta se esconde, con la barra de objetos, para dejarle a la ventana todo el alto (placeJoin).
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
	-- Por píxeles y no en escala: el botón mide de 48 a 80 px de alto según la pantalla. Con una ventana
	-- abierta se esconden (quedarían debajo de ella).
	local suppliesLabel = Widgets.label("", gui)
	suppliesLabel.Name = "SuppliesLine"
	suppliesLabel.AnchorPoint = Vector2.new(0.5, 1)
	suppliesLabel.Size = UDim2.new(0.5, 0, 0, 26)
	suppliesLabel.TextColor3 = Color3.fromRGB(230, 220, 200)
	local suppliesText = ""
	local function refreshSupplies()
		local raw = player:GetAttribute("Retention")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
		end)
		local items = Rewards.sanitizeItems(if ok and typeof(decoded) == "table" then decoded.supplies else nil)
		local text = Rewards.describeItems(items)
		suppliesText = if text ~= "" then `🎒 Te llevas a la {ISLAND}: {text}` else ""
		suppliesLabel.Text = suppliesText
		suppliesLabel.Visible = suppliesText ~= "" and not panel.Visible
	end
	player:GetAttributeChangedSignal("Retention"):Connect(refreshSupplies)
	refreshSupplies()

	-- Barra del menú: un botón por ventana de MENU, con un punto rojo si hay algo pendiente.
	local bar = Instance.new("Frame")
	bar.Name = "MenuBar"
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	local barLayout = Instance.new("UIListLayout")
	barLayout.Padding = UDim.new(0, BAR_GAP)
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Parent = bar
	type BarButton = { button: TextButton, icon: TextLabel, name: TextLabel, badge: Frame }
	local barButtons: { [string]: BarButton } = {}
	for index, id in MENU do
		local window = WINDOWS[id]
		local button = Instance.new("TextButton")
		button.Name = id
		button.LayoutOrder = index
		button.Text = ""
		button.BackgroundColor3 = SQUARE_COLOR
		button.BackgroundTransparency = 0.2
		button.AutoButtonColor = true
		button.Parent = bar
		corner(button, 12)
		local icon = Widgets.label(window.icon, button)
		icon.Name = "Icon"
		local name = Widgets.label(id, button)
		name.Name = "Label"
		name.Position = UDim2.new(0, 2, 0.6, 0)
		name.Size = UDim2.new(1, -4, 0.34, 0)
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MaxTextSize = 13
		nameLimit.Parent = name
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(1, -6, 0, 6)
		badge.Size = UDim2.fromOffset(14, 14)
		badge.BackgroundColor3 = BADGE_COLOR
		badge.Visible = false
		badge.Parent = button
		corner(badge, 7)
		local badgeStroke = Instance.new("UIStroke")
		badgeStroke.Color = Color3.new(1, 1, 1)
		badgeStroke.Thickness = 1.5
		badgeStroke.Parent = badge
		button.Activated:Connect(function()
			if id == "Emotes" then
				EmoteWheel.toggle()
			else
				openWindow(if currentWindow == id then nil else id)
			end
		end)
		barButtons[id] = { button = button, icon = icon, name = name, badge = badge }
	end

	-- Puntos rojos: puntos de talento libres en el rol elegido, premio del calendario por cobrar y
	-- premios del pase por reclamar.
	local function refreshBadges()
		local data = Progression.read(player)
		local roleId = Progression.validRole(player:GetAttribute("SelectedRole"))
		barButtons.Talentos.badge.Visible = Progression.freePoints(roleId, data) > 0
		local login = Daily.loginState(readRetention().login)
		barButtons.Misiones.badge.Visible = Daily.canClaim(login, EggIncubation.now())
		local season = SeasonPass.info(SeasonPass.now()).season
		local passRaw = player:GetAttribute("Season")
		local okPass, passData = pcall(function()
			return HttpService:JSONDecode(if typeof(passRaw) == "string" then passRaw else "{}")
		end)
		barButtons.Pase.badge.Visible = season ~= nil
			and SeasonPass.hasClaimable(season, SeasonPass.normalize(if okPass then passData else nil, season.id))
	end
	refreshBadges()

	-- Invitar amigos de Roblox (también está en la ventana Grupo): debajo de la barra del menú.
	local inviteButton = Widgets.button("📨 Invitar amigos", gui)
	inviteButton.Name = "InviteFriends"
	local inviteLimit = inviteButton:FindFirstChildOfClass("UISizeConstraint")
	inviteButton.Activated:Connect(function()
		inviteFriends(player)
	end)

	-- Coloca la barra, el botón de invitar y la pastilla del Ámbar. En PC, la barra en columna a la
	-- izquierda y la pastilla en el centro de la franja de la barra de Roblox. En táctil (a la
	-- izquierda está el joystick) o si no cabe la columna, todo en esa franja: la pastilla a la
	-- izquierda, tras los botones de Roblox, y a la derecha la barra en fila, solo con iconos, y el
	-- botón de invitar como un icono más.
	local function placeHud()
		local inset = GuiService:GetGuiInset().Y
		local band = -inset / 2
		local columnHeight = #MENU * (BAR_BUTTON.Y + BAR_GAP) - BAR_GAP
		rowMode = UserInputService.TouchEnabled or gui.AbsoluteSize.Y < BAR_TOP + columnHeight + 8 + INVITE_HEIGHT + 12
		for _, item in barButtons do
			item.name.Visible = not rowMode
			item.icon.Position = if rowMode then UDim2.fromScale(0.1, 0.1) else UDim2.new(0, 4, 0.06, 0)
			item.icon.Size = if rowMode then UDim2.fromScale(0.8, 0.8) else UDim2.new(1, -8, 0.52, 0)
			item.button.Size = if rowMode
				then UDim2.fromOffset(BAR_ROW_BUTTON, BAR_ROW_BUTTON)
				else UDim2.fromOffset(BAR_BUTTON.X, BAR_BUTTON.Y)
		end
		if rowMode then
			local rowWidth = #MENU * (BAR_ROW_BUTTON + BAR_GAP) - BAR_GAP
			barLayout.FillDirection = Enum.FillDirection.Horizontal
			bar.AnchorPoint = Vector2.new(1, 0.5)
			bar.Position = UDim2.new(1, -12, 0, band)
			bar.Size = UDim2.fromOffset(rowWidth, BAR_ROW_BUTTON)
			inviteButton.Text = "📨"
			if inviteLimit then
				inviteLimit.MinSize = Vector2.new(BAR_ROW_BUTTON, BAR_ROW_BUTTON)
			end
			inviteButton.AnchorPoint = Vector2.new(1, 0.5)
			inviteButton.Position = UDim2.new(1, -12 - rowWidth - BAR_GAP * 2, 0, band)
			inviteButton.Size = UDim2.fromOffset(BAR_ROW_BUTTON, BAR_ROW_BUTTON)
			-- La pastilla, entre los botones de Roblox y el de invitar.
			local left = GuiService.TopbarInset.Min.X + 8
			local right = gui.AbsoluteSize.X - 12 - rowWidth - BAR_GAP * 2 - BAR_ROW_BUTTON - 8
			pill.AnchorPoint = Vector2.new(0, 0.5)
			pill.Position = UDim2.fromOffset(left, band)
			pill.Size = UDim2.fromOffset(math.clamp(right - left, 160, 300), 32)
		else
			barLayout.FillDirection = Enum.FillDirection.Vertical
			bar.AnchorPoint = Vector2.zero
			bar.Position = UDim2.fromOffset(12, BAR_TOP)
			bar.Size = UDim2.fromOffset(BAR_BUTTON.X, columnHeight)
			inviteButton.Text = "📨 Invitar amigos"
			if inviteLimit then
				inviteLimit.MinSize = Vector2.new(160, INVITE_HEIGHT)
			end
			inviteButton.AnchorPoint = Vector2.zero
			inviteButton.Position = UDim2.fromOffset(12, BAR_TOP + columnHeight + 8)
			inviteButton.Size = UDim2.fromOffset(200, INVITE_HEIGHT)
			pill.AnchorPoint = Vector2.new(0.5, 0.5)
			pill.Position = UDim2.new(0.5, 0, 0, band)
			pill.Size = UDim2.fromOffset(340, 34)
		end
	end

	-- El botón de viaje, las provisiones y el de invitar: solo sin ventana abierta (una ventana ancha
	-- llega hasta el de invitar; invitar también está en la ventana Grupo).
	local function placeJoin()
		local open = panel.Visible
		inviteButton.Visible = not open
		local bottom = UDim2.new(0.5, 0, 1, -HOTBAR_CLEARANCE)
		joinButton.Position = bottom
		joinButton.Visible = not open
		suppliesLabel.Position = bottom + UDim2.fromOffset(0, -86)
		suppliesLabel.Visible = suppliesText ~= "" and not open
	end

	-- El alto de la ventana, el justo para lo que tiene dentro, sin pasar del borde de abajo.
	local function fitWindow()
		if not panel.Visible then
			return
		end
		local bottom = gui.AbsoluteSize.Y - windowBottomMargin()
		local needed = list.Position.Y.Offset + listLayout.AbsoluteContentSize.Y + 10
		local height = math.max(120, math.min(needed, bottom - panel.Position.Y.Offset))
		panel.Size = UDim2.new(panel.Size.X.Scale, 0, 0, height)
	end
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitWindow)

	-- Las casillas de habilidades y de combos (CombatClient: RoleHUD y ComboHUD, arriba a la izquierda)
	-- quedan debajo de la ventana en un teléfono: se esconden mientras está abierta.
	local function showCombatHud(screen: Instance)
		if screen:IsA("ScreenGui") and COMBAT_HUDS[screen.Name] then
			screen.Enabled = not panel.Visible
		end
	end
	playerGui.ChildAdded:Connect(showCombatHud)

	function openWindow(id: string?, prompt: ProximityPrompt?)
		if id ~= "Rol" then
			rolePicked = false
		end
		currentWindow = id
		windowPrompt = if id then prompt else nil
		local open = id ~= nil
		if id ~= "Pase" then
			SeasonPassPanel.close()
		end
		panel.Visible = open
		for _, screen in playerGui:GetChildren() do
			showCombatHud(screen)
		end
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not open)
		placeJoin()
		for barId, item in barButtons do
			local active = barId == id
			item.button.BackgroundColor3 = if active then READY_COLOR else SQUARE_COLOR
			item.button.BackgroundTransparency = if active then 0 else 0.2
			item.name.TextColor3 = if active then Color3.fromRGB(40, 25, 5) else Color3.new(1, 1, 1)
		end
		if open then
			hideTitle()
			render()
			task.defer(fitWindow)
		end
	end

	local function relayout()
		placeHud()
		refreshHeader()
		placeJoin()
		render()
		task.defer(fitWindow)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	-- La franja libre de la barra de Roblox puede cambiar después de empezar (en el teléfono llega
	-- tarde): la pastilla se coloca tras sus botones.
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeHud)
	placeHud()
	refreshHeader()
	-- Empieza sin ventana (coloca el botón de viaje y la línea de provisiones).
	openWindow(nil)

	closeButton.Activated:Connect(function()
		openWindow(nil)
	end)

	-- El tiempo del huevo del nido corre solo: se actualiza cada segundo mientras se ve. Cada pocos
	-- segundos se miran también los puntos rojos (el premio del calendario llega con el cambio de día).
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(1)
			ticks += 1
			if ticks % 5 == 0 then
				refreshBadges()
			end
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
			local tick = passTick
			if tick and panel.Visible then
				tick()
			end
			local shopCountdown = shopTick
			if shopCountdown and panel.Visible then
				shopCountdown()
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

	-- La ventana de una estación se cierra sola al alejarse de su cartel o del nido.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local prompt = windowPrompt
			if not prompt then
				continue
			end
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local anchor = prompt.Parent
			local at = if anchor and anchor:IsA("BasePart")
				then anchor.Position
				elseif anchor and anchor:IsA("Attachment") then anchor.WorldPosition
				else nil
			-- Sin sitio (el cartel ya no está) o lejos de él.
			local far = at ~= nil
				and root ~= nil
				and root:IsA("BasePart")
				and (root.Position - at).Magnitude > prompt.MaxActivationDistance + STATION_CLOSE_MARGIN
			if at == nil or far then
				openWindow(nil)
			end
		end
	end)

	player.AttributeChanged:Connect(function(attribute)
		if attribute == "Amber" or attribute == "BestDays" then
			refreshHeader()
		end
		if
			attribute == "Progress"
			or attribute == "SelectedRole"
			or attribute == "Retention"
			or attribute == "Season"
		then
			refreshBadges()
		end
		-- El panel de Ajustes se actualiza solo al cambiar una opción (no hace falta rehacerlo).
		if attribute == "Settings" and currentWindow == "Ajustes" then
			return
		end
		render()
	end)
	Players.PlayerAdded:Connect(render)
	Players.PlayerRemoving:Connect(function()
		task.defer(render)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == "ZarparPrompt" then
			join()
			return
		end
		local id = STATION_PROMPTS[prompt.Name]
		if id then
			openWindow(id, prompt)
		end
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
