--!strict
-- Ventana del pase de temporada (Fase 9; la abre LobbyUIController: el cartel del pase de la plaza o
-- el botón 🌋 de la barra). Todo a la vista, sin desplazarse (también en un teléfono apaisado):
--   - Arriba: la temporada (día, cuánto falta, ×2 de la última semana), tu nivel con su barra y
--     "Reclamar todo".
--   - Los niveles en 3 filas de 10 casillas: arriba el premio gratis y abajo el premium. Dorado = listo
--     para reclamar, ✅ = cobrado, apagado = aún no. El siguiente nivel, en cian.
--   - Debajo, el detalle de la casilla elegida (qué da cada pista y por qué no se puede aún) con su
--     botón de reclamar, y las compras (premium, premium + 10 niveles y un nivel), que solo dan
--     aspecto. Sin id de producto salen "Próximamente"; en Studio hacen una compra de prueba.
-- Lee el atributo "Season" del jugador (ServerShared/SeasonPass) y pide con Remotes.ClaimPass.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local Seasons = require(ReplicatedStorage.Shared.Data.Seasons)
local Widgets = require(script.Parent.Widgets)

local ROW_COLOR = Color3.fromRGB(45, 38, 30)
local INFO_COLOR = Color3.fromRGB(25, 20, 15)
-- Mitad premium de cada casilla: madera más roja, del volcán.
local PREMIUM_COLOR = Color3.fromRGB(70, 38, 24)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local BLOCKED_COLOR = Color3.fromRGB(90, 90, 90)
local DONE_COLOR = Color3.fromRGB(120, 230, 140)
local NEXT_COLOR = Color3.fromRGB(120, 230, 255)
local WARN_COLOR = Color3.fromRGB(255, 170, 60)
local SECONDARY = Color3.fromRGB(215, 205, 190)
local BAR_BACK = Color3.fromRGB(20, 16, 12)
local COLUMNS = 10
local DAY = 24 * 60 * 60

-- Medidas en PC y en una pantalla baja (compact).
type Sizes = { header: number, cell: number, gap: number, detail: number, shop: number, text: number }
local NORMAL: Sizes = { header = 64, cell = 84, gap = 6, detail = 46, shop = 50, text = 20 }
-- En un teléfono apaisado (844 x 390) la ventana tiene unos 320 px de alto bajo la barra de Roblox.
local COMPACT: Sizes = { header = 36, cell = 46, gap = 4, detail = 30, shop = 32, text = 15 }

local SeasonPassPanel = {}

-- Casilla elegida (se mantiene al volver a dibujar la ventana).
local selected: number? = nil

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(0, radius)
	instance.Parent = parent
end

local function textCap(object: GuiObject, max: number)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = max
	limit.Parent = object
end

local function stroke(parent: GuiObject, color: Color3, thickness: number)
	local instance = Instance.new("UIStroke")
	instance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	instance.Color = color
	instance.Thickness = thickness
	instance.Parent = parent
end

local function box(parent: Instance, order: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -10, 0, height)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	return frame
end

-- Botón de la ventana sin el tamaño mínimo de Widgets.button (aquí van varios en una fila).
local function button(parent: Instance, text: string, enabled: boolean, maxText: number): TextButton
	local result = Widgets.button(text, parent)
	local limit = result:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit:Destroy()
	end
	result.Active = enabled
	result.AutoButtonColor = enabled
	result.BackgroundColor3 = if enabled then READY_COLOR else BLOCKED_COLOR
	result.TextColor3 = if enabled then Color3.fromRGB(40, 25, 5) else Color3.fromRGB(210, 210, 210)
	textCap(result, maxText)
	return result
end

local function formatLeft(seconds: number): string
	if seconds >= DAY then
		return `{seconds // DAY} d {(seconds % DAY) // 3600} h`
	end
	return EggIncubation.formatTime(seconds)
end

local function readState(player: Player): any
	local raw = player:GetAttribute("Season")
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
	end)
	return if ok then decoded else nil
end

-- Compra: con id, la ventana de Roblox; sin id, en Studio una compra de prueba (panel de pruebas).
local function buy(player: Player, key: string)
	local productId = Config.Shop.Products[key].productId
	if productId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, productId)
	elseif RunService:IsStudio() then
		Remotes.DebugCommand:FireServer("FakePurchase", key)
	end
end

-- Línea de una pista en el detalle: qué da y cómo está.
local function trackLine(
	season: Seasons.Season,
	state: SeasonPass.State,
	level: number,
	track: SeasonPass.Track
): string
	local reward = SeasonPass.reward(season, level, track)
	local name = if track == "Free" then "Gratis" else "🌋 Premium"
	if not reward then
		return `{name}: —`
	end
	local status
	if SeasonPass.isClaimed(state, level, track) then
		status = "✅ cobrado"
	elseif SeasonPass.unlocked(season, state, level, track) then
		status = "🎁 ¡listo!"
	elseif track == "Premium" and not state.premium then
		status = "🔒 con la premium"
	elseif track == "Free" and not SeasonPass.isCosmeticOnly(reward) and SeasonPass.level(state) >= level then
		-- Llegó con niveles comprados: lo que no es aspecto se gana jugando.
		status = `🔒 gana el nivel jugando ({SeasonPass.earnedLevel(state.xp)}/{level})`
	else
		status = `🔒 nivel {level}`
	end
	return `{name}: {Rewards.describe(reward :: any)} · {status}`
end

export type Options = { compact: boolean }

-- Dibuja la ventana en "list" (con UIListLayout vertical). Devuelve la función que la ventana llama
-- cada segundo (la cuenta atrás).
function SeasonPassPanel.build(list: Instance, options: Options): () -> ()
	local player = Players.LocalPlayer
	local size = if options.compact then COMPACT else NORMAL
	local now = SeasonPass.now()
	local info = SeasonPass.info(now)
	local season = info.season

	local header = box(list, 1, size.header)
	local title = Widgets.label("", header)
	title.Size = UDim2.fromScale(0.66, 0.5)
	title.TextXAlignment = Enum.TextXAlignment.Left
	textCap(title, size.text + 2)
	local function refreshTitle()
		local current = SeasonPass.info(SeasonPass.now())
		local name = if season then `{season.icon} {season.name}` else "🌋 Pase de temporada"
		if current.phase == "Active" then
			title.Text = `{name} · día {current.day}/{Config.Season.Days} · termina en {formatLeft(
				current.secondsLeft
			)}{if current.lastWeek then ` · 🔥 ×{current.multiplier} XP` else ""}`
		elseif current.phase == "Rest" then
			title.Text = `{name} · terminada · la siguiente en {formatLeft(current.secondsLeft)}`
		elseif season then
			title.Text = `{name} · empieza en {formatLeft(current.secondsLeft)}`
		else
			title.Text = "🌋 Pase de temporada · aún no hay ninguna prevista"
		end
		title.TextColor3 = if current.lastWeek then WARN_COLOR else Color3.new(1, 1, 1)
	end
	refreshTitle()

	if not season or info.phase == "None" then
		local note = Widgets.label("Cuando empiece una temporada, jugar en las islas te dará XP de pase.", header)
		note.Position = UDim2.fromScale(0, 0.5)
		note.Size = UDim2.fromScale(1, 0.5)
		note.TextColor3 = SECONDARY
		note.TextXAlignment = Enum.TextXAlignment.Left
		textCap(note, size.text)
		return refreshTitle
	end

	local state = SeasonPass.normalize(readState(player), season.id)
	local level = SeasonPass.level(state)
	local earned = SeasonPass.earnedLevel(state.xp)
	local progress, need = SeasonPass.progress(state)
	local claims, loops = SeasonPass.claimable(season, state)
	local claimCount = #claims + loops

	-- Nivel y barra de lo que falta para el siguiente.
	local levelText = Widgets.label("", header)
	levelText.Position = UDim2.fromScale(0, 0.52)
	levelText.Size = UDim2.fromScale(0.3, 0.44)
	levelText.TextXAlignment = Enum.TextXAlignment.Left
	levelText.TextColor3 = READY_COLOR
	textCap(levelText, size.text)
	levelText.Text = if state.xp >= Config.Season.Levels * Config.Season.LevelXp
		then `Nivel {level} · premio extra`
		else `Nivel {level}/{Config.Season.Levels}{if state.bought > 0 then ` ({state.bought} comprados)` else ""}`
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0.31, 0.6)
	bar.Size = UDim2.fromScale(0.35, 0.3)
	bar.BackgroundColor3 = BAR_BACK
	bar.Parent = header
	corner(bar, 6)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(progress / need, 0, 1), 1)
	fill.BackgroundColor3 = NEXT_COLOR
	fill.Parent = bar
	corner(fill, 6)
	local barText = Widgets.label(`{progress}/{need} XP`, bar)
	barText.Size = UDim2.fromScale(1, 1)
	textCap(barText, size.text - 4)

	local claimAll = button(
		header,
		if claimCount > 0 then `🎁 Reclamar todo ({claimCount})` else "Nada por reclamar",
		claimCount > 0,
		size.text
	)
	claimAll.AnchorPoint = Vector2.new(1, 0.5)
	claimAll.Position = UDim2.fromScale(1, 0.5)
	claimAll.Size = UDim2.new(0.32, 0, 1, -6)
	if claimCount > 0 then
		claimAll.Activated:Connect(function()
			claimAll.Active = false
			claimAll.Text = "Reclamando…"
			Remotes.ClaimPass:FireServer()
		end)
	end

	-- Casillas: 3 filas de 10.
	local rows = math.ceil(Config.Season.Levels / COLUMNS)
	local gridHeight = rows * size.cell + (rows - 1) * size.gap
	local grid = box(list, 2, gridHeight)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / COLUMNS, -size.gap, 0, size.cell)
	layout.CellPadding = UDim2.fromOffset(size.gap, size.gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local claimable: { [string]: boolean } = {}
	for _, claim in claims do
		claimable[`{claim.level}{claim.track}`] = true
	end
	-- Por defecto, el primer premio por reclamar o el siguiente nivel.
	local focus = selected
	if not focus or focus > Config.Season.Levels then
		focus = if #claims > 0 then claims[1].level else math.min(level + 1, Config.Season.Levels)
	end
	selected = focus

	local detail = box(list, 3, size.detail)
	detail.BackgroundColor3 = INFO_COLOR
	detail.BackgroundTransparency = 0.25
	corner(detail, 8)
	local detailText = Widgets.label("", detail)
	detailText.Position = UDim2.fromOffset(8, 2)
	detailText.Size = UDim2.new(0.74, -8, 1, -4)
	detailText.TextXAlignment = Enum.TextXAlignment.Left
	detailText.TextWrapped = true
	detailText.Font = Enum.Font.BuilderSans
	detailText.TextColor3 = SECONDARY
	textCap(detailText, size.text - 4)
	local detailButton = button(detail, "", false, size.text)
	detailButton.AnchorPoint = Vector2.new(1, 0.5)
	detailButton.Position = UDim2.new(1, -4, 0.5, 0)
	detailButton.Size = UDim2.new(0.25, -4, 1, -6)

	local cells: { [number]: UIStroke } = {}
	local function showDetail(chosen: number)
		selected = chosen
		for index, ring in cells do
			ring.Enabled = index == chosen
		end
		detailText.Text =
			`Nivel {chosen}: {trackLine(season, state, chosen, "Free")}\n{trackLine(season, state, chosen, "Premium")}`
		local ready = {}
		for _, track: SeasonPass.Track in { "Free", "Premium" } :: { SeasonPass.Track } do
			if claimable[`{chosen}{track}`] then
				table.insert(ready, track)
			end
		end
		detailButton.Visible = #ready > 0
		detailButton.Text = "🎁 Reclamar"
		detailButton.Active = #ready > 0
		detailButton.BackgroundColor3 = READY_COLOR
		detailButton.TextColor3 = Color3.fromRGB(40, 25, 5)
		detailButton:SetAttribute("Level", chosen)
		detailButton:SetAttribute("Tracks", table.concat(ready, ","))
	end
	detailButton.Activated:Connect(function()
		local chosen = detailButton:GetAttribute("Level")
		local tracks = detailButton:GetAttribute("Tracks")
		if typeof(chosen) ~= "number" or typeof(tracks) ~= "string" or tracks == "" then
			return
		end
		detailButton.Active = false
		detailButton.Text = "Reclamando…"
		for _, track in string.split(tracks, ",") do
			Remotes.ClaimPass:FireServer(chosen, track)
		end
	end)

	for index = 1, Config.Season.Levels do
		local cell = Instance.new("TextButton")
		cell.LayoutOrder = index
		cell.Text = ""
		cell.AutoButtonColor = true
		cell.BackgroundColor3 = ROW_COLOR
		cell.BackgroundTransparency = 0.15
		cell.Parent = grid
		corner(cell, 8)
		local ring = Instance.new("UIStroke")
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Color = Color3.new(1, 1, 1)
		ring.Thickness = 2
		ring.Enabled = false
		ring.Parent = cell
		cells[index] = ring

		-- El número: en cian el siguiente nivel que se gana jugando; en dorado los alcanzados.
		local number = Widgets.label(tostring(index), cell)
		number.Size = UDim2.fromScale(1, 0.24)
		number.TextColor3 = if index == earned + 1 then NEXT_COLOR elseif level >= index then READY_COLOR else SECONDARY
		textCap(number, size.text - 4)

		for part, track: SeasonPass.Track in { "Free", "Premium" } :: { SeasonPass.Track } do
			local reward = SeasonPass.reward(season, index, track)
			local half = Instance.new("Frame")
			half.Position = UDim2.new(0, 3, 0.24 + (part - 1) * 0.38, 0)
			half.Size = UDim2.new(1, -6, 0.36, 0)
			half.BackgroundColor3 = if track == "Premium" then PREMIUM_COLOR else INFO_COLOR
			half.BackgroundTransparency = if track == "Premium" then 0.1 else 0.35
			half.Parent = cell
			corner(half, 6)
			local claimed = SeasonPass.isClaimed(state, index, track)
			local ready = claimable[`{index}{track}`] == true
			local text = if reward then Rewards.compact(reward :: any) else ""
			if claimed then
				text = "✅"
			elseif reward and track == "Premium" and not state.premium then
				text = `🔒 {text}`
			end
			local label = Widgets.label(text, half)
			label.Size = UDim2.fromScale(1, 1)
			label.TextColor3 = if claimed then DONE_COLOR elseif ready then READY_COLOR else Color3.new(1, 1, 1)
			-- Apagado lo que aún no se puede reclamar (también lo gratis alcanzado solo con niveles comprados,
			-- que pide ganar el nivel jugando).
			label.TextTransparency = if ready or claimed then 0 else 0.45
			textCap(label, size.text - 4)
			if ready then
				stroke(half, READY_COLOR, 2)
			end
		end
		cell.Activated:Connect(function()
			showDetail(index)
		end)
	end
	showDetail(focus)

	-- Compras: solo aspecto. Con la temporada en marcha.
	if info.phase == "Active" then
		local shop = box(list, 4, size.shop)
		local shopLayout = Instance.new("UIListLayout")
		shopLayout.FillDirection = Enum.FillDirection.Horizontal
		shopLayout.Padding = UDim.new(0, size.gap)
		shopLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
		shopLayout.Parent = shop
		local products = Config.Shop.Products
		type Offer = { key: string, text: string, show: boolean }
		local offers: { Offer } = {
			{
				key = "SeasonPremium",
				text = `🌋 Premium · {products.SeasonPremium.price} R$`,
				show = not state.premium,
			},
			{
				key = "SeasonPack",
				text = `🌋 Premium + {products.SeasonPack.levels} niveles · {products.SeasonPack.price} R$`,
				show = not state.premium,
			},
			{
				key = "SeasonLevel",
				text = `⭐ +1 nivel · {products.SeasonLevel.price} R$`,
				show = level < Config.Season.Levels,
			},
		}
		local note = Widgets.label(
			if state.premium
				then "✅ Tienes la premium: sus premios solo cambian tu aspecto"
				else "Premium: solo aspecto",
			shop
		)
		note.LayoutOrder = 0
		note.Size = UDim2.fromScale(if state.premium then 0.6 else 0.22, 1)
		note.TextXAlignment = Enum.TextXAlignment.Left
		note.TextColor3 = SECONDARY
		textCap(note, size.text - 4)
		local shown = 0
		for _, offer in offers do
			if offer.show then
				shown += 1
			end
		end
		for index, offer in offers do
			if offer.show then
				local available = products[offer.key].productId ~= 0 or RunService:IsStudio()
				local offerButton = button(
					shop,
					if available then offer.text else `{offer.text} · Próximamente`,
					available,
					size.text - 2
				)
				offerButton.LayoutOrder = index
				local free = if state.premium then 0.4 else 0.78
				offerButton.Size = UDim2.new(free / shown, -size.gap, 1, -4)
				if available then
					offerButton.Activated:Connect(function()
						buy(player, offer.key)
					end)
				end
			end
		end
	end

	return refreshTitle
end

return SeasonPassPanel
