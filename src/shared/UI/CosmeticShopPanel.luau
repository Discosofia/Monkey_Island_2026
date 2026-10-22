--!strict
-- Pestaña "🎨 Cosméticos" de la ventana Tienda del Lobby (Fase 9, G10; rotación en Shared/CosmeticShop):
--   - En Ámbar: tu oferta de hoy (Config.CosmeticShop.AmberSlots), con la cuenta atrás hasta la
--     siguiente. Comprar pide un segundo toque ("¿Comprar?") para no gastar sin querer.
--   - En Robux: tu oferta de la semana (cambia el lunes). Sin id de producto sale "Próximamente"; en
--     Studio hace una compra de prueba (panel de pruebas, "FakePurchase").
--   - Siempre a la venta: los Game Passes, en tarjetas pequeñas, con su precio de Roblox.
--   - Cada tarjeta lleva la imagen 3D del cosmético (Shared/RewardModels, tu avatar con él puesto; los
--     aspectos de arma, el arma sola, Shared/WeaponTools) y el borde de su rareza; tocarla explica qué
--     es en la barra de abajo.
-- En PC las secciones van una debajo de otra; en una pantalla baja, Ámbar y Robux una al lado de la
-- otra, para que todo quepa sin desplazarse. LobbyUIController la rehace al cambiar los datos del
-- jugador y llama cada segundo a lo que devuelve "build" (las cuentas atrás).

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CosmeticShop = require(ReplicatedStorage.Shared.CosmeticShop)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local PlayerFrames = require(ReplicatedStorage.Shared.UI.PlayerFrames)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardModels = require(ReplicatedStorage.Shared.RewardModels)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local ROW_COLOR = Color3.fromRGB(45, 38, 30)
local PICKED_COLOR = Color3.fromRGB(70, 58, 44)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local BLOCKED_COLOR = Color3.fromRGB(90, 90, 90)
local NOTE_COLOR = Color3.fromRGB(255, 220, 150)
local DETAIL_COLOR = Color3.fromRGB(215, 205, 190)
-- Segundos que espera el segundo toque de "Comprar" en Ámbar.
local CONFIRM_SECONDS = 3
local HINT =
	"Toca una tarjeta para ver qué es · Solo cambian tu aspecto, nunca dan ventaja · Lo que compras se pone en el 👕 Armario"

export type Options = { compact: boolean }

local CosmeticShopPanel = {}

-- Lo tocado (se recuerda entre dibujos) y los precios de los Game Passes que ya ha dicho Roblox.
local selected: string? = nil
local passPrices: { [number]: number } = {}

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

local function setButton(button: TextButton, text: string, enabled: boolean)
	button.Text = text
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then READY_COLOR else BLOCKED_COLOR
	button.TextColor3 = if enabled then Color3.fromRGB(40, 25, 5) else Color3.fromRGB(210, 210, 210)
end

-- Botón de tarjeta: sin los topes de tamaño de Widgets.button (la tarjeta es más estrecha).
local function cardButton(parent: Instance, height: number, cap: number): TextButton
	local button = Widgets.button("", parent)
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -5)
	button.Size = UDim2.new(1, -10, 0, height)
	local limit = button:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit:Destroy()
	end
	textCap(button, cap)
	return button
end

local function readShop(): { [string]: any }?
	local raw = Players.LocalPlayer:GetAttribute("CosmeticShop")
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and typeof(decoded) == "table" then decoded else nil
end

local function owned(cosmeticId: string): boolean
	return Players.LocalPlayer:GetAttribute(`Cosmetic_{cosmeticId}`) == true
end

-- El nombre sin el tipo delante ("Título: Cazaplátanos" → "Cazaplátanos").
local function shortName(cosmetic: Cosmetics.Cosmetic): string
	return (string.gsub(cosmetic.name, "^[^:]+: ", ""))
end

local function describe(cosmeticId: string): string
	local cosmetic = Cosmetics[cosmeticId]
	local rarity = Rarities[cosmetic.rarity] or Rarities.Common
	return `{cosmetic.icon} {cosmetic.name} · {rarity.name} · {cosmetic.description}`
end

-- Imagen 3D del cosmético en "view" y, si es un título, su texto encima (los ViewportFrame no dibujan
-- carteles).
local function picture(view: ViewportFrame, cosmeticId: string, textSize: number)
	local cosmetic = Cosmetics[cosmeticId]
	-- El aspecto de un arma se ve en el arma (suelta y cruzada), no en el avatar.
	local weapon = if cosmetic.kind == "WeaponSkin" and cosmetic.role
		then WeaponTools.preview(cosmetic.role, cosmeticId)
		else nil
	if weapon then
		weapon:PivotTo(CFrame.Angles(0, math.rad(90), math.rad(-40)))
	end
	local model = weapon or RewardModels.cosmetic(Players.LocalPlayer.Character, cosmeticId)
	if model then
		RewardModels.frame(view, model, if weapon then 1.1 else 1.25)
	end
	if cosmetic.kind == "Title" then
		local label = Widgets.label(cosmetic.title or cosmetic.name, view)
		label.Size = UDim2.fromScale(1, 0.24)
		label.TextColor3 = cosmetic.color
		textCap(label, textSize)
	elseif cosmetic.kind == "Frame" then
		-- Tu nombre con el marco, como en el ranking.
		local card = Widgets.label(Players.LocalPlayer.DisplayName, view)
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(0.5, 0, 0, 6)
		card.Size = UDim2.fromScale(0.86, 0.2)
		card.BackgroundColor3 = Color3.fromRGB(45, 36, 28)
		card.BackgroundTransparency = 0.1
		card.TextColor3 = Color3.fromRGB(255, 240, 210)
		corner(card, 6)
		textCap(card, textSize)
		PlayerFrames.apply(card, cosmeticId)
	end
end

local function viewport(parent: Instance): ViewportFrame
	local view = Instance.new("ViewportFrame")
	view.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
	view.BackgroundTransparency = 0.25
	view.Parent = parent
	corner(view, 8)
	return view
end

-- Una sección: su cabecera (con la cuenta atrás, si cambia) y la fila de tarjetas.
local function section(
	parent: Instance,
	order: number,
	width: UDim,
	cardHeight: number,
	compact: boolean
): (TextLabel, Frame)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(width, UDim.new(0, 0))
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = frame
	local header = Widgets.label("", frame)
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, if compact then 18 else 28)
	header.TextColor3 = NOTE_COLOR
	header.TextXAlignment = Enum.TextXAlignment.Left
	textCap(header, if compact then 14 else 20)
	local cards = Instance.new("Frame")
	cards.LayoutOrder = 2
	cards.BackgroundTransparency = 1
	cards.Size = UDim2.new(1, 0, 0, cardHeight)
	cards.Parent = frame
	local cardsLayout = Instance.new("UIListLayout")
	cardsLayout.FillDirection = Enum.FillDirection.Horizontal
	cardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardsLayout.Padding = UDim.new(0, 6)
	cardsLayout.Parent = cards
	return header, cards
end

-- Ancho de una de "slots" tarjetas en una fila con 6 px entre ellas.
local function slotWidth(slots: number): UDim2
	return UDim2.new(1 / slots, -6 * (slots - 1) / slots, 1, 0)
end

-- Casilla de texto en el sitio de una tarjeta (la oferta vacía, lo que explica la tienda de Robux).
local function tile(parent: Instance, order: number, slots: number, text: string, compact: boolean)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = slotWidth(slots)
	frame.BackgroundColor3 = ROW_COLOR
	frame.BackgroundTransparency = 0.5
	frame.Parent = parent
	corner(frame, 10)
	local label = Widgets.label(text, frame)
	label.Position = UDim2.fromOffset(8, 8)
	label.Size = UDim2.new(1, -16, 1, -16)
	label.TextWrapped = true
	label.TextColor3 = DETAIL_COLOR
	textCap(label, if compact then 13 else 17)
end

function CosmeticShopPanel.build(list: Instance, options: Options): () -> ()
	local player = Players.LocalPlayer
	local compact = options.compact
	local shop = readShop()
	if not shop then
		local wait = Widgets.label("Abriendo la tienda…", list)
		wait.LayoutOrder = 1
		wait.Size = UDim2.new(1, -10, 0, 30)
		wait.TextColor3 = NOTE_COLOR
		return function() end
	end
	local amber = player:GetAttribute("Amber")
	local balance = if typeof(amber) == "number" then amber else 0
	local bought: { [string]: boolean } = {}
	for _, cosmeticId in if typeof(shop.bought) == "table" then shop.bought else {} do
		bought[cosmeticId] = true
	end
	local amberOffer: { string } = {}
	local robuxOffer: { string } = {}
	for _, pair in { { shop.amber, amberOffer }, { shop.robux, robuxOffer } } do
		for _, cosmeticId in if typeof(pair[1]) == "table" then pair[1] else {} do
			if typeof(cosmeticId) == "string" and Cosmetics[cosmeticId] then
				table.insert(pair[2], cosmeticId)
			end
		end
	end

	-- En una pantalla baja, sin la línea de la rareza (ya la dice el borde): así cabe todo en 844 × 390.
	local cardHeight = if compact then 112 else 196
	local nameHeight = if compact then 15 else 20
	local tagHeight = if compact then 0 else 15
	local buttonHeight = if compact then 26 else 34
	local cards: { [string]: TextButton } = {}
	local detail: TextLabel

	local function pick(cosmeticId: string)
		selected = cosmeticId
		for id, card in cards do
			card.BackgroundColor3 = if id == cosmeticId then PICKED_COLOR else ROW_COLOR
		end
		detail.Text = describe(cosmeticId)
	end

	-- Tarjeta de un cosmético de la oferta: imagen, nombre, rareza y el botón de compra (lo pone "buy").
	local function offerCard(parent: Instance, order: number, slots: number, cosmeticId: string): TextButton
		local cosmetic = Cosmetics[cosmeticId]
		local card = Instance.new("TextButton")
		card.LayoutOrder = order
		card.Size = slotWidth(slots)
		card.Text = ""
		card.AutoButtonColor = false
		card.BackgroundColor3 = if selected == cosmeticId then PICKED_COLOR else ROW_COLOR
		card.BackgroundTransparency = 0.1
		card.Parent = parent
		corner(card, 10)
		Widgets.rarityBorder(card, cosmetic.rarity)
		cards[cosmeticId] = card
		card.MouseButton1Click:Connect(function()
			pick(cosmeticId)
		end)
		local view = viewport(card)
		view.Position = UDim2.fromOffset(4, 4)
		view.Size = UDim2.new(1, -8, 1, -(nameHeight + tagHeight + buttonHeight + 18))
		picture(view, cosmeticId, if compact then 12 else 16)
		local name = Widgets.label(`{cosmetic.icon} {shortName(cosmetic)}`, card)
		name.AnchorPoint = Vector2.new(0, 1)
		name.Position = UDim2.new(0, 6, 1, -(tagHeight + buttonHeight + 10))
		name.Size = UDim2.new(1, -12, 0, nameHeight)
		name.TextColor3 = cosmetic.color
		name.TextXAlignment = Enum.TextXAlignment.Left
		textCap(name, if compact then 13 else 16)
		if tagHeight > 0 then
			local rarity = Rarities[cosmetic.rarity] or Rarities.Common
			local tag = Widgets.label(rarity.name, card)
			tag.AnchorPoint = Vector2.new(0, 1)
			tag.Position = UDim2.new(0, 6, 1, -(buttonHeight + 9))
			tag.Size = UDim2.new(1, -12, 0, tagHeight)
			tag.TextColor3 = rarity.color
			tag.TextXAlignment = Enum.TextXAlignment.Left
			textCap(tag, 13)
		end
		return card
	end

	-- Ámbar y Robux: en PC una debajo de otra; en una pantalla baja, una al lado de la otra.
	local amberSlots = Config.CosmeticShop.AmberSlots
	local robuxSlots = Config.CosmeticShop.RobuxSlots
	local amberParent, robuxParent = list, list
	local amberWidth, robuxWidth = UDim.new(1, -10), UDim.new(1, -10)
	if compact then
		local both = Instance.new("Frame")
		both.LayoutOrder = 1
		both.BackgroundTransparency = 1
		both.Size = UDim2.new(1, -10, 0, 0)
		both.AutomaticSize = Enum.AutomaticSize.Y
		both.Parent = list
		local bothLayout = Instance.new("UIListLayout")
		bothLayout.FillDirection = Enum.FillDirection.Horizontal
		bothLayout.SortOrder = Enum.SortOrder.LayoutOrder
		bothLayout.Padding = UDim.new(0, 6)
		bothLayout.Parent = both
		amberParent, robuxParent = both, both
		local total = amberSlots + robuxSlots
		amberWidth = UDim.new(amberSlots / total, -3)
		robuxWidth = UDim.new(robuxSlots / total, -3)
	end

	local amberHeader, amberCards = section(amberParent, 1, amberWidth, cardHeight, compact)
	for index, cosmeticId in amberOffer do
		local card = offerCard(amberCards, index, amberSlots, cosmeticId)
		local button = cardButton(card, buttonHeight, if compact then 13 else 15)
		local price = CosmeticShop.price(cosmeticId, "Amber") or 0
		if bought[cosmeticId] or owned(cosmeticId) then
			setButton(button, "✅ Tuyo", false)
			continue
		end
		setButton(button, `✨ {price}`, balance >= price)
		local armedUntil = 0
		button.MouseButton1Click:Connect(function()
			pick(cosmeticId)
			if not button.Active then
				return
			end
			if os.clock() < armedUntil then
				armedUntil = 0
				setButton(button, "Comprando…", false)
				Remotes.BuyCosmetic:FireServer(cosmeticId)
				return
			end
			armedUntil = os.clock() + CONFIRM_SECONDS
			button.Text = "¿Comprar?"
			task.delay(CONFIRM_SECONDS, function()
				if button.Parent and button.Active then
					button.Text = `✨ {price}`
				end
			end)
		end)
	end
	if #amberOffer == 0 then
		tile(amberCards, 1, 1, "🎉 Ya tienes todo lo de la tienda en Ámbar", compact)
	end

	-- En PC, la tienda de Robux ocupa el ancho de la de Ámbar y deja el último hueco para explicarse.
	local robuxRow = if compact then robuxSlots else math.max(robuxSlots + 1, amberSlots)
	local robuxHeader, robuxCards = section(robuxParent, 2, robuxWidth, cardHeight, compact)
	for index, cosmeticId in robuxOffer do
		local card = offerCard(robuxCards, index, robuxRow, cosmeticId)
		local button = cardButton(card, buttonHeight, if compact then 13 else 15)
		local source = Cosmetics[cosmeticId].source
		local price = source.price or 0
		if bought[cosmeticId] then
			setButton(button, "✅ Tuyo", false)
		elseif source.productId and source.productId ~= 0 then
			local productId = source.productId
			setButton(button, `R$ {price}`, true)
			button.MouseButton1Click:Connect(function()
				pick(cosmeticId)
				MarketplaceService:PromptProductPurchase(player, productId)
			end)
		elseif RunService:IsStudio() then
			setButton(button, `R$ {price} · prueba`, true)
			button.MouseButton1Click:Connect(function()
				pick(cosmeticId)
				Remotes.DebugCommand:FireServer("FakePurchase", `Cosmetic.{cosmeticId}`)
			end)
		else
			setButton(button, "Próximamente", false)
		end
	end
	if #robuxOffer == 0 then
		tile(robuxCards, 1, robuxRow, "🎉 Ya tienes todo lo de esta semana", compact)
	end
	if not compact then
		tile(
			robuxCards,
			robuxRow,
			robuxRow,
			"🗓️ Nuevos cada lunes\nSolo cambian tu aspecto: nunca dan ventaja",
			compact
		)
	end

	-- Siempre a la venta: los Game Passes en tarjetas pequeñas (imagen a la izquierda).
	local passes = CosmeticShop.fixed()
	local passHeight = if compact then 44 else 66
	local passHeader, passCards = section(list, 3, UDim.new(1, -10), passHeight, compact)
	passHeader.Text = "🎟️ Siempre a la venta"
	for index, cosmeticId in passes do
		local cosmetic = Cosmetics[cosmeticId]
		local card = Instance.new("TextButton")
		card.LayoutOrder = index
		card.Size = slotWidth(math.max(#passes, amberSlots))
		card.Text = ""
		card.AutoButtonColor = false
		card.BackgroundColor3 = if selected == cosmeticId then PICKED_COLOR else ROW_COLOR
		card.BackgroundTransparency = 0.1
		card.Parent = passCards
		corner(card, 10)
		Widgets.rarityBorder(card, cosmetic.rarity)
		cards[cosmeticId] = card
		card.MouseButton1Click:Connect(function()
			pick(cosmeticId)
		end)
		local side = passHeight - 8
		local view = viewport(card)
		view.Position = UDim2.fromOffset(4, 4)
		view.Size = UDim2.fromOffset(side, side)
		picture(view, cosmeticId, 10)
		local name = Widgets.label(`{cosmetic.icon} {shortName(cosmetic)}`, card)
		name.Position = UDim2.fromOffset(side + 10, 4)
		name.Size = UDim2.new(1, -(side + 14), 0, if compact then 14 else 22)
		name.TextColor3 = cosmetic.color
		name.TextXAlignment = Enum.TextXAlignment.Left
		textCap(name, if compact then 13 else 16)
		local button = Widgets.button("", card)
		button.AnchorPoint = Vector2.new(0, 1)
		button.Position = UDim2.new(0, side + 10, 1, -4)
		button.Size = UDim2.new(1, -(side + 14), 0, if compact then 22 else 32)
		local limit = button:FindFirstChildOfClass("UISizeConstraint")
		if limit then
			limit:Destroy()
		end
		textCap(button, if compact then 12 else 15)
		local gamePassId = cosmetic.source.gamePassId or 0
		if owned(cosmeticId) then
			setButton(button, "✅ Tuyo", false)
		elseif gamePassId == 0 then
			setButton(button, "Próximamente", false)
		else
			local known = passPrices[gamePassId]
			setButton(button, if known then `R$ {known}` else "R$ …", true)
			button.MouseButton1Click:Connect(function()
				pick(cosmeticId)
				MarketplaceService:PromptGamePassPurchase(player, gamePassId)
			end)
			if not known then
				task.spawn(function()
					local ok, info = pcall(function()
						return MarketplaceService:GetProductInfo(gamePassId, Enum.InfoType.GamePass)
					end)
					local robux = if ok and typeof(info) == "table" then info.PriceInRobux else nil
					if typeof(robux) == "number" then
						passPrices[gamePassId] = robux
						if button.Parent then
							button.Text = `R$ {robux}`
						end
					end
				end)
			end
		end
	end

	detail = Widgets.label(if selected and cards[selected] then describe(selected) else HINT, list)
	detail.LayoutOrder = 4
	detail.Size = UDim2.new(1, -10, 0, if compact then 18 else 26)
	detail.Font = Enum.Font.BuilderSans
	detail.TextColor3 = DETAIL_COLOR
	detail.TextXAlignment = Enum.TextXAlignment.Left
	textCap(detail, if compact then 12 else 15)

	-- Cabeceras con lo que falta para el cambio (se rehacen cada segundo).
	local function tick()
		local now = CosmeticShop.now()
		local amberLeft = CosmeticShop.formatLeft(CosmeticShop.secondsLeft("Amber", now))
		local robuxLeft = CosmeticShop.formatLeft(CosmeticShop.secondsLeft("Robux", now))
		amberHeader.Text = if compact then `✨ Ámbar · {amberLeft}` else `✨ En Ámbar · cambia en {amberLeft}`
		robuxHeader.Text = if compact then `💰 Robux · {robuxLeft}` else `💰 En Robux · cambia en {robuxLeft}`
	end
	tick()
	return tick
end

return CosmeticShopPanel
