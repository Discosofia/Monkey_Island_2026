--!strict
-- Ventana del pase de temporada (Fase 9; la abre LobbyUIController: el cartel del pase de la plaza o
-- el botón 🌋 de la barra), con el aspecto de haber salido del volcán:
--   - Detrás, un fondo volcánico a pantalla completa (cielo de brasas, el volcán con su cráter y
--     ríos de lava, brasas que suben y ceniza que cae). La ventana sube desde abajo al abrirse.
--   - Marco de obsidiana con borde de lava. En la cabecera, el medallón con tu nivel, la barra de XP
--     (un río de lava), lo que le queda a la temporada y "Reclamar todo".
--   - Las dos pistas en una franja que se desliza de lado (arrastrando, con la rueda o con ◀ ▶): arriba
--     la premium, abajo la gratis y en medio el camino de lava con el número de cada nivel. Cada
--     tarjeta lleva la imagen 3D del premio (Shared/RewardModels, gira al pasar el ratón), su nombre,
--     su detalle y "Reclamar", "✅ Cobrado" o el candado con el motivo. Después del último nivel, la
--     columna del premio extra en bucle. Es la única ventana del Lobby que se desliza (lo pidió el
--     usuario para el pase: las tarjetas necesitan sitio para la imagen y el texto).
--   - Abajo, con premium, el sello "PASE PREMIUM ACTIVO"; sin ella, una frase que invita y las
--     compras. Sin id de producto salen "Próximamente"; en Studio hacen una compra de prueba.
-- Al reclamar, la tarjeta celebra lo que ha dado (no sale el aviso grande: taparía la ventana).
-- Lee el atributo "Season" del jugador (ServerShared/SeasonPass) y pide con Remotes.ClaimPass.

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardModels = require(ReplicatedStorage.Shared.RewardModels)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)
local Seasons = require(ReplicatedStorage.Shared.Data.Seasons)
local Widgets = require(script.Parent.Widgets)

-- Volcán: obsidiana (premium y marco), basalto (gratis), lava y brasas.
local OBSIDIAN = Color3.fromRGB(24, 17, 16)
local OBSIDIAN_LIGHT = Color3.fromRGB(48, 28, 24)
local BASALT = Color3.fromRGB(58, 50, 46)
local BASALT_DARK = Color3.fromRGB(38, 33, 30)
local LAVA = Color3.fromRGB(255, 110, 30)
local LAVA_LIGHT = Color3.fromRGB(255, 195, 80)
local LAVA_DARK = Color3.fromRGB(150, 40, 15)
local COOLED = Color3.fromRGB(70, 45, 38)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local DARK_TEXT = Color3.fromRGB(40, 25, 5)
local BLOCKED_COLOR = Color3.fromRGB(90, 90, 90)
local DONE_COLOR = Color3.fromRGB(120, 230, 140)
local NEXT_COLOR = Color3.fromRGB(120, 230, 255)
local SECONDARY = Color3.fromRGB(215, 205, 190)
local LOCKED_TEXT = Color3.fromRGB(165, 150, 140)
local DAY = 24 * 60 * 60
-- Columna del premio extra después del último nivel.
local LOOP_COLUMN = Config.Season.Levels + 1

-- Medidas en PC y en una pantalla baja (compact; un teléfono apaisado de 844 x 390 deja unos 320 px).
type Sizes = {
	header: number,
	card: number,
	path: number,
	shop: number,
	column: number,
	view: number,
	text: number,
	labels: number,
}
local NORMAL: Sizes = { header = 76, card = 158, path = 34, shop = 54, column = 150, view = 86, text = 18, labels = 64 }
local COMPACT: Sizes = { header = 36, card = 82, path = 20, shop = 30, column = 112, view = 42, text = 13, labels = 0 }

local SeasonPassPanel = {}

-- Estado entre dibujos de la misma ventana abierta (se borra al cerrarla).
local backdrop: ScreenGui? = nil
type Styled = { window: Frame, color: Color3, transparency: number, title: TextLabel?, titleColor: Color3 }
local styled: Styled? = nil
local scrollX: number? = nil
local seenClaimed: { [string]: boolean }? = nil
local spinning: { [Model]: boolean } = {}
local spinConnection: RBXScriptConnection? = nil

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

local function stroke(parent: GuiObject, color: Color3, thickness: number): UIStroke
	local instance = Instance.new("UIStroke")
	instance.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	instance.Color = color
	instance.Thickness = thickness
	instance.Parent = parent
	return instance
end

local function gradient(parent: Instance, from: Color3, to: Color3, rotation: number): UIGradient
	local instance = Instance.new("UIGradient")
	instance.Color = ColorSequence.new(from, to)
	instance.Rotation = rotation
	instance.Parent = parent
	return instance
end

local function frame(parent: Instance, color: Color3, transparency: number?): Frame
	local result = Instance.new("Frame")
	result.BackgroundColor3 = color
	result.BackgroundTransparency = transparency or 0
	result.BorderSizePixel = 0
	result.Parent = parent
	return result
end

local function box(parent: Instance, order: number, height: number): Frame
	local result = frame(parent, OBSIDIAN, 1)
	result.LayoutOrder = order
	result.Size = UDim2.new(1, -10, 0, height)
	return result
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
	result.TextColor3 = if enabled then DARK_TEXT else Color3.fromRGB(210, 210, 210)
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

-- Nombre y detalle de un premio para su tarjeta. "short": nombres cortos para el teléfono (sin el
-- tipo delante del cosmético, y de las provisiones solo la primera y cuántas más).
local function describe(reward: Seasons.PassReward, short: boolean?): (string, string)
	local cosmetic = if reward.cosmetic then Cosmetics[reward.cosmetic] else nil
	if cosmetic then
		local extra = if reward.amber then `+ {reward.amber} Ámbar · ` else ""
		local name = if short then (string.gsub(cosmetic.name, "^[^:]*: ", "")) else cosmetic.name
		return name, `{extra}{Rarities[cosmetic.rarity].name}`
	elseif reward.egg then
		local best, bestWeight = "Rare", -1
		for rarity, weight in reward.egg do
			if weight > bestWeight then
				best, bestWeight = rarity, weight
			end
		end
		return `Huevo {Rarities[best].name}`, "Para tu nido de mascotas"
	elseif reward.amber then
		return `{reward.amber} Ámbar`, "Para mejoras y la tienda"
	elseif reward.eggSeconds then
		return `−{EggIncubation.formatTime(reward.eggSeconds)} de huevo`, "Acelera el huevo del nido"
	elseif reward.items then
		local ids = {}
		for itemId in reward.items do
			table.insert(ids, itemId)
		end
		table.sort(ids, function(a, b)
			return Items[a].order < Items[b].order
		end)
		local parts = {}
		for _, itemId in ids do
			table.insert(parts, `{Items[itemId].name} ×{reward.items[itemId]}`)
		end
		if short and #parts > 1 then
			return `{parts[1]} +{#parts - 1}`, "Para tu próxima partida"
		end
		return table.concat(parts, " · "), "Para tu próxima partida"
	end
	return "—", ""
end

-- El modelo 3D de la tarjeta (el avatar con el cosmético, o el del premio).
local function modelFor(player: Player, reward: Seasons.PassReward): Model?
	if reward.cosmetic then
		return RewardModels.avatar(player.Character, reward.cosmetic)
	end
	return RewardModels.forReward(reward :: any)
end

-- Gira despacio los modelos de las tarjetas que tienen el ratón encima.
local function spin(model: Model, on: boolean)
	spinning[model] = if on then true else nil
	if next(spinning) and not spinConnection then
		spinConnection = RunService.RenderStepped:Connect(function(delta)
			for current in spinning do
				if current.Parent then
					local center = current:GetBoundingBox().Position
					current:PivotTo(
						CFrame.new(center) * CFrame.Angles(0, delta * 1.4, 0) * CFrame.new(-center) * current:GetPivot()
					)
				else
					spinning[current] = nil
				end
			end
		end)
	elseif not next(spinning) and spinConnection then
		spinConnection:Disconnect()
		spinConnection = nil
	end
end

-- Fondo volcánico a pantalla completa, detrás de la ventana (DisplayOrder por debajo del LobbyUI).
local function buildBackdrop(playerGui: Instance): ScreenGui
	local gui = Widgets.screen("PassBackdrop", playerGui)
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -1
	local sky = frame(gui, Color3.new(1, 1, 1))
	sky.Size = UDim2.fromScale(1, 1)
	local skyGradient = Instance.new("UIGradient")
	skyGradient.Rotation = 90
	skyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 8, 8)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(70, 20, 10)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 50, 12)),
	})
	skyGradient.Parent = sky
	-- El volcán: un cuadrado girado del que solo asoma la punta, con el cráter encendido y tres ríos
	-- de lava por las laderas.
	local volcano = frame(sky, Color3.fromRGB(26, 14, 12))
	volcano.AnchorPoint = Vector2.new(0.5, 0.5)
	volcano.Position = UDim2.fromScale(0.5, 1.12)
	volcano.Size = UDim2.fromScale(0.62, 0.62)
	volcano.Rotation = 45
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.Parent = volcano
	local crater = frame(sky, LAVA)
	crater.AnchorPoint = Vector2.new(0.5, 0.5)
	crater.Position = UDim2.fromScale(0.5, 0.69)
	crater.Size = UDim2.fromScale(0.11, 0.035)
	corner(crater, 40)
	gradient(crater, LAVA_LIGHT, LAVA_DARK, 90)
	for _, river in { { x = 0.47, rotation = 30 }, { x = 0.53, rotation = -28 }, { x = 0.5, rotation = 4 } } do
		local streak = frame(sky, LAVA)
		streak.AnchorPoint = Vector2.new(0.5, 0)
		streak.Position = UDim2.fromScale(river.x, 0.69)
		streak.Size = UDim2.new(0, 6, 0.4, 0)
		streak.Rotation = river.rotation
		local fade = gradient(streak, LAVA_LIGHT, LAVA_DARK, 90)
		fade.Transparency = NumberSequence.new(0, 0.6)
	end
	-- Brillo del suelo y viñeta.
	local glow = frame(sky, LAVA)
	glow.AnchorPoint = Vector2.new(0, 1)
	glow.Position = UDim2.fromScale(0, 1)
	glow.Size = UDim2.fromScale(1, 0.25)
	local glowFade = gradient(glow, LAVA, LAVA_DARK, 90)
	glowFade.Transparency = NumberSequence.new(1, 0.55)
	local vignette = frame(sky, Color3.new(0, 0, 0))
	vignette.Size = UDim2.fromScale(1, 1)
	local vignetteFade = Instance.new("UIGradient")
	vignetteFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.2, 1),
		NumberSequenceKeypoint.new(0.8, 1),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	vignetteFade.Parent = vignette

	-- Brasas que suben y ceniza que cae, mientras el fondo exista.
	task.spawn(function()
		local rng = Random.new()
		while gui.Parent do
			local ember = rng:NextNumber() < 0.75
			local color = if not ember then SECONDARY elseif rng:NextNumber() < 0.5 then LAVA else LAVA_LIGHT
			local particle = frame(sky, color, if ember then 0 else 0.5)
			local side = if ember then rng:NextInteger(3, 7) else rng:NextInteger(2, 4)
			particle.Size = UDim2.fromOffset(side, side)
			particle.Rotation = rng:NextNumber(0, 90)
			local x = rng:NextNumber(0.02, 0.98)
			particle.Position = if ember then UDim2.fromScale(x, 1.02) else UDim2.fromScale(x, -0.02)
			local seconds = rng:NextNumber(3, 6)
			local target = if ember
				then UDim2.fromScale(x + rng:NextNumber(-0.08, 0.08), rng:NextNumber(0.1, 0.6))
				else UDim2.fromScale(x + rng:NextNumber(-0.05, 0.05), 1.02)
			TweenService:Create(
				particle,
				TweenInfo.new(seconds, Enum.EasingStyle.Linear),
				{ Position = target, BackgroundTransparency = 1, Rotation = particle.Rotation + 180 }
			):Play()
			task.delay(seconds, function()
				particle:Destroy()
			end)
			task.wait(0.12)
		end
	end)
	return gui
end

-- Marco de obsidiana con borde de lava (se deshace al cerrar, SeasonPassPanel.close).
local function styleWindow(window: Frame, title: TextLabel?, season: Seasons.Season?)
	if not styled then
		styled = {
			window = window,
			color = window.BackgroundColor3,
			transparency = window.BackgroundTransparency,
			title = title,
			titleColor = if title then title.TextColor3 else Color3.new(1, 1, 1),
		}
	end
	window.BackgroundColor3 = Color3.new(1, 1, 1)
	window.BackgroundTransparency = 0.04
	if not window:FindFirstChild("PassDecor") then
		local shade = Instance.new("UIGradient")
		shade.Name = "PassDecor"
		shade.Rotation = 90
		shade.Color = ColorSequence.new(OBSIDIAN, OBSIDIAN_LIGHT)
		shade.Parent = window
		local edge = stroke(window, LAVA, 3)
		edge.Name = "PassDecor"
		gradient(edge, LAVA_LIGHT, LAVA_DARK, 90)
		TweenService:Create(
			edge,
			TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.45 }
		):Play()
	end
	if title then
		title.TextColor3 = LAVA_LIGHT
		if season then
			title.Text = `{season.icon} {season.name}`
		end
	end
end

-- Quita el fondo y el marco del volcán (al cerrar la ventana o abrir otra). Se puede llamar siempre.
function SeasonPassPanel.close()
	local gui = backdrop
	backdrop = nil
	if gui then
		gui:Destroy()
	end
	local style = styled
	styled = nil
	if style then
		style.window.BackgroundColor3 = style.color
		style.window.BackgroundTransparency = style.transparency
		for _, child in style.window:GetChildren() do
			if child.Name == "PassDecor" then
				child:Destroy()
			end
		end
		if style.title then
			style.title.TextColor3 = style.titleColor
		end
	end
	scrollX = nil
	seenClaimed = nil
	table.clear(spinning)
	if spinConnection then
		spinConnection:Disconnect()
		spinConnection = nil
	end
end

-- Celebración en una tarjeta recién cobrada: un sello que cae y el premio que sube.
local function celebrate(card: Frame, text: string, size: Sizes)
	local stamp = Widgets.label("¡TUYO!", card)
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Position = UDim2.fromScale(0.5, 0.4)
	stamp.Size = UDim2.fromScale(0.9, 0.3)
	stamp.Rotation = -12
	stamp.TextColor3 = LAVA_LIGHT
	stamp.ZIndex = 5
	local scale = Instance.new("UIScale")
	scale.Scale = 2.2
	scale.Parent = stamp
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local floating = Widgets.label(`+ {text}`, card)
	floating.AnchorPoint = Vector2.new(0.5, 1)
	floating.Position = UDim2.fromScale(0.5, 0.2)
	floating.Size = UDim2.new(1.4, 0, 0, size.text + 4)
	floating.TextColor3 = READY_COLOR
	floating.ZIndex = 6
	TweenService:Create(
		floating,
		TweenInfo.new(1.6, Enum.EasingStyle.Quad),
		{ Position = UDim2.fromScale(0.5, -0.2), TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	task.delay(1.4, function()
		TweenService:Create(stamp, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

type CardInfo = {
	level: number,
	track: SeasonPass.Track | "Loop",
	reward: Seasons.PassReward?,
	status: "Ready" | "Claimed" | "Locked" | "Empty",
	lockText: string,
	readyCount: number?,
}

local function buildCard(
	player: Player,
	parent: Instance,
	y: number,
	info: CardInfo,
	size: Sizes,
	compact: boolean
): Frame
	local premium = info.track == "Premium"
	local card = frame(parent, if premium then OBSIDIAN else BASALT, if info.status == "Empty" then 0.75 else 0)
	card.Position = UDim2.fromOffset(5, y)
	card.Size = UDim2.new(1, -10, 0, size.card)
	corner(card, 10)
	if info.status == "Empty" then
		stroke(card, if premium then OBSIDIAN_LIGHT else BASALT_DARK, 1).Transparency = 0.5
		return card
	end
	gradient(
		card,
		Color3.new(1, 1, 1),
		if premium then Color3.fromRGB(255, 150, 110) else Color3.fromRGB(200, 195, 190),
		90
	)
	local edge = stroke(card, if premium then LAVA else BASALT_DARK, if premium then 2 else 1.5)
	if info.status == "Ready" then
		edge.Color = READY_COLOR
		edge.Thickness = 3
		TweenService:Create(
			edge,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.6 }
		):Play()
	end
	local reward = info.reward :: Seasons.PassReward
	local locked = info.status == "Locked"

	-- La imagen 3D.
	local view = Instance.new("ViewportFrame")
	view.Position = UDim2.fromOffset(4, 4)
	view.Size = UDim2.new(1, -8, 0, size.view)
	view.BackgroundTransparency = 1
	view.ImageTransparency = if locked then 0.35 else 0
	view.Parent = card
	local model = modelFor(player, reward)
	if model then
		RewardModels.frame(view, model, if reward.cosmetic then 1.25 else 1.4)
		local hold = model
		card.MouseEnter:Connect(function()
			spin(hold, true)
		end)
		card.MouseLeave:Connect(function()
			spin(hold, false)
		end)
	end
	-- El título se escribe encima del avatar (los ViewportFrame no dibujan carteles).
	local cosmetic = if reward.cosmetic then Cosmetics[reward.cosmetic] else nil
	if cosmetic and cosmetic.kind == "Title" then
		local titleText = Widgets.label(cosmetic.title or cosmetic.name, view)
		titleText.Size = UDim2.fromScale(1, 0.24)
		titleText.TextColor3 = cosmetic.color
		textCap(titleText, size.text - 2)
	end
	if locked and premium then
		local lock = Widgets.label("🔒", card)
		lock.AnchorPoint = Vector2.new(1, 0)
		lock.Position = UDim2.new(1, -4, 0, 4)
		lock.Size = UDim2.fromOffset(size.text + 6, size.text + 6)
	end

	local name, detail = describe(reward, compact)
	if info.track == "Loop" then
		name, detail = "Premio extra", `Cada {Config.Season.LoopXp} XP tras el nivel {Config.Season.Levels}`
	end
	local top = size.view + 6
	local nameLabel = Widgets.label(name, card)
	nameLabel.Position = UDim2.fromOffset(6, top)
	nameLabel.Size = UDim2.new(1, -12, 0, if compact then size.text else size.text + 2)
	nameLabel.TextColor3 = if cosmetic then cosmetic.color elseif premium then LAVA_LIGHT else Color3.new(1, 1, 1)
	textCap(nameLabel, size.text)
	-- Nunca más pequeño de lo que se lee en un teléfono: si no cabe, se corta con "…".
	local nameLimit = nameLabel:FindFirstChildOfClass("UITextSizeConstraint")
	if nameLimit then
		nameLimit.MinTextSize = 11
	end
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	top += nameLabel.Size.Y.Offset + 2
	if not compact then
		local detailLabel = Widgets.label(detail, card)
		detailLabel.Position = UDim2.fromOffset(6, top)
		detailLabel.Size = UDim2.new(1, -12, 0, size.text - 2)
		detailLabel.Font = Enum.Font.BuilderSans
		detailLabel.TextColor3 = SECONDARY
		textCap(detailLabel, size.text - 4)
		top += size.text
	end

	-- Abajo: reclamar, cobrado o el candado con el motivo.
	local bottom = size.card - top - 4
	if info.status == "Ready" then
		local claim = button(
			card,
			if info.readyCount and info.readyCount > 1 then `Reclamar ×{info.readyCount}` else "Reclamar",
			true,
			size.text
		)
		claim.Position = UDim2.fromOffset(6, top)
		claim.Size = UDim2.new(1, -12, 0, bottom)
		local padding = claim:FindFirstChildOfClass("UIPadding")
		if padding then
			padding.PaddingTop = UDim.new(0, 2)
			padding.PaddingBottom = UDim.new(0, 2)
		end
		claim.Activated:Connect(function()
			claim.Active = false
			claim.Text = "…"
			if info.track == "Loop" then
				Remotes.ClaimPass:FireServer()
			else
				Remotes.ClaimPass:FireServer(info.level, info.track)
			end
		end)
	else
		local status = Widgets.label(if info.status == "Claimed" then "✅ Cobrado" else info.lockText, card)
		status.Position = UDim2.fromOffset(6, top)
		status.Size = UDim2.new(1, -12, 0, bottom)
		status.TextColor3 = if info.status == "Claimed" then DONE_COLOR else LOCKED_TEXT
		textCap(status, size.text - 2)
	end
	return card
end

-- Nodo del camino de lava (el número del nivel) con su tramo de lava. "state": "You" (tu nivel),
-- "Next" (el siguiente que se gana jugando) o "Plain".
local function buildNode(parent: Instance, y: number, label: string, lit: boolean, state: string, size: Sizes)
	local segment = frame(parent, if lit then LAVA else COOLED)
	segment.AnchorPoint = Vector2.new(0, 0.5)
	segment.Position = UDim2.fromOffset(0, y + size.path / 2)
	segment.Size = UDim2.new(1, 0, 0, math.max(4, size.path // 6))
	if lit then
		gradient(segment, LAVA_LIGHT, LAVA, 0)
	end
	local diameter = size.path - 2
	local node = frame(parent, if lit then READY_COLOR else BASALT_DARK)
	node.AnchorPoint = Vector2.new(0.5, 0.5)
	node.Position = UDim2.new(0.5, 0, 0, y + size.path / 2)
	node.Size = UDim2.fromOffset(diameter, diameter)
	corner(node, diameter // 2)
	stroke(
		node,
		if state == "Next" then NEXT_COLOR elseif state == "You" then Color3.new(1, 1, 1) else LAVA_DARK,
		if state == "Plain" then 1.5 else 3
	)
	local number = Widgets.label(label, node)
	number.Size = UDim2.fromScale(1, 1)
	number.TextColor3 = if lit then DARK_TEXT else Color3.new(1, 1, 1)
	number.TextStrokeTransparency = if lit then 1 else 0.5
	textCap(number, math.max(11, size.text - 2))
	if state == "You" then
		local you = Widgets.label("TÚ", parent)
		you.AnchorPoint = Vector2.new(0, 0.5)
		you.Position = UDim2.new(0.5, diameter / 2 + 4, 0, y + size.path / 2)
		you.Size = UDim2.fromOffset(28, math.max(12, size.path // 2))
		you.TextColor3 = Color3.new(1, 1, 1)
		you.TextXAlignment = Enum.TextXAlignment.Left
	end
end

export type Options = { compact: boolean, window: Frame?, title: TextLabel? }

-- Dibuja la ventana en "list" (con UIListLayout vertical). Devuelve la función que la ventana llama
-- cada segundo (la cuenta atrás).
function SeasonPassPanel.build(list: Instance, options: Options): () -> ()
	local player = Players.LocalPlayer
	local compact = options.compact
	local size = if compact then COMPACT else NORMAL
	local now = SeasonPass.now()
	local info = SeasonPass.info(now)
	local season = info.season

	-- Fondo y marco del volcán; la primera vez, la ventana sube desde el cráter.
	local window = options.window
	if window then
		styleWindow(window, options.title, season)
	end
	if not backdrop then
		local gui = buildBackdrop(player:WaitForChild("PlayerGui"))
		backdrop = gui
		if window then
			local target = window.Position
			window.Position = target + UDim2.fromScale(0, 1)
			TweenService:Create(window, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Position = target }):Play()
		end
		local flash = frame(gui, LAVA_LIGHT, 0.2)
		flash.Size = UDim2.fromScale(1, 1)
		flash.ZIndex = 10
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end

	-- Cabecera: medallón del nivel, tiempo de la temporada, barra de XP y "Reclamar todo".
	local header = box(list, 1, size.header)
	local timeText = Widgets.label("", header)
	local function refreshTime()
		local current = SeasonPass.info(SeasonPass.now())
		if current.phase == "Active" then
			timeText.Text =
				`Día {current.day} de {Config.Season.Days} · termina en {formatLeft(current.secondsLeft)}{if current.lastWeek
					then ` · 🔥 ×{current.multiplier} XP`
					else ""}`
		elseif current.phase == "Rest" then
			timeText.Text = `Temporada terminada · la siguiente en {formatLeft(current.secondsLeft)}`
		elseif season then
			timeText.Text = `Empieza en {formatLeft(current.secondsLeft)}`
		else
			timeText.Text = "Aún no hay ninguna temporada prevista"
		end
		timeText.TextColor3 = if current.lastWeek then LAVA_LIGHT else SECONDARY
		-- En el teléfono no cabe la línea del tiempo: lo que queda va en el título de la ventana.
		local title = options.title
		if compact and title and season and current.phase ~= "None" then
			title.Text = `{season.icon} {season.name} · {formatLeft(current.secondsLeft)}{if current.lastWeek
				then ` · ×{current.multiplier} XP`
				else ""}`
		end
	end

	if not season or info.phase == "None" then
		timeText.Size = UDim2.fromScale(1, 1)
		textCap(timeText, size.text + 2)
		refreshTime()
		local note = box(list, 2, size.shop)
		local text = Widgets.label("Cuando empiece una temporada, jugar en las islas te dará XP de pase.", note)
		text.Size = UDim2.fromScale(1, 1)
		text.TextColor3 = LAVA_LIGHT
		textCap(text, size.text)
		return refreshTime
	end

	local state = SeasonPass.normalize(readState(player), season.id)
	local level = SeasonPass.level(state)
	local earned = SeasonPass.earnedLevel(state.xp)
	local progress, need = SeasonPass.progress(state)
	local claims, loops = SeasonPass.claimable(season, state)
	local claimCount = #claims + loops

	local medal = frame(header, OBSIDIAN)
	medal.Size = UDim2.fromOffset(size.header - 4, size.header - 4)
	medal.Position = UDim2.fromOffset(0, 2)
	corner(medal, size.header)
	stroke(medal, LAVA, if compact then 2 else 3)
	gradient(medal, OBSIDIAN_LIGHT, OBSIDIAN, 90)
	local medalNumber = Widgets.label(tostring(level), medal)
	medalNumber.Position = UDim2.fromScale(0, if compact then 0 else 0.12)
	medalNumber.Size = UDim2.fromScale(1, if compact then 1 else 0.6)
	medalNumber.TextColor3 = LAVA_LIGHT
	if not compact then
		local medalLabel = Widgets.label("NIVEL", medal)
		medalLabel.Position = UDim2.fromScale(0, 0.66)
		medalLabel.Size = UDim2.fromScale(1, 0.2)
		medalLabel.TextColor3 = SECONDARY
	end

	local left = size.header + 6
	if compact then
		timeText.Visible = false
	else
		timeText.Position = UDim2.fromOffset(left, 2)
		timeText.Size = UDim2.new(0.66, -left, 0, size.header * 0.42)
		timeText.TextXAlignment = Enum.TextXAlignment.Left
		textCap(timeText, size.text)
	end
	refreshTime()
	local bar = frame(header, Color3.fromRGB(20, 12, 10))
	bar.Position = if compact
		then UDim2.new(0, left, 0.5, -size.header * 0.3)
		else UDim2.fromOffset(left, size.header * 0.5)
	bar.Size = if compact
		then UDim2.new(0.62, -left, 0, size.header * 0.6)
		else UDim2.new(0.66, -left, 0, size.header * 0.42)
	corner(bar, 8)
	stroke(bar, LAVA_DARK, 1.5)
	local fill = frame(bar, Color3.new(1, 1, 1))
	fill.Size = UDim2.fromScale(math.clamp(progress / need, 0.02, 1), 1)
	corner(fill, 8)
	gradient(fill, LAVA, LAVA_LIGHT, 0)
	local loopsDone = state.xp >= Config.Season.Levels * Config.Season.LevelXp
	local barText = Widgets.label(
		if loopsDone
			then `{progress}/{need} XP · premio extra`
			else `{progress}/{need} XP para el nivel {math.min(earned + 1, Config.Season.Levels)}{if state.bought
					> 0
				then ` · {state.bought} comprados`
				else ""}`,
		bar
	)
	barText.Size = UDim2.fromScale(1, 1)
	textCap(barText, size.text - 2)

	local claimAll = button(
		header,
		if claimCount > 0 then `🎁 Reclamar todo ({claimCount})` else "Nada por reclamar",
		claimCount > 0,
		size.text
	)
	claimAll.AnchorPoint = Vector2.new(1, 0.5)
	claimAll.Position = UDim2.fromScale(1, 0.5)
	claimAll.Size = UDim2.new(if compact then 0.34 else 0.32, 0, 1, if compact then -2 else -12)
	if claimCount > 0 then
		claimAll.Activated:Connect(function()
			claimAll.Active = false
			claimAll.Text = "Reclamando…"
			Remotes.ClaimPass:FireServer()
		end)
	end

	-- Las dos pistas, que se deslizan juntas, con el camino de lava en medio.
	local tracksHeight = size.card * 2 + size.path + 8
	local tracks = box(list, 2, tracksHeight)
	if size.labels > 0 then
		for _, tag in
			{
				{ text = "🔥\nPREMIUM", y = 0, color = LAVA_LIGHT },
				{ text = "GRATIS", y = size.card + size.path + 8, color = SECONDARY },
			}
		do
			local label = Widgets.label(tag.text, tracks)
			label.Position = UDim2.fromOffset(0, tag.y)
			label.Size = UDim2.fromOffset(size.labels - 6, size.card)
			label.TextColor3 = tag.color
			textCap(label, 15)
		end
	end
	local scroller = Instance.new("ScrollingFrame")
	scroller.Position = UDim2.fromOffset(size.labels, 0)
	scroller.Size = UDim2.new(1, -size.labels, 1, 0)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollingDirection = Enum.ScrollingDirection.X
	scroller.ScrollBarThickness = if compact then 3 else 5
	scroller.ScrollBarImageColor3 = LAVA
	scroller.HorizontalScrollBarInset = Enum.ScrollBarInset.None
	scroller.CanvasSize = UDim2.fromOffset(LOOP_COLUMN * size.column, 0)
	scroller.Parent = tracks

	local claimable: { [string]: boolean } = {}
	for _, claim in claims do
		claimable[`{claim.level}{claim.track}`] = true
	end
	local claimedNow: { [string]: boolean } = {}
	local cardOf: { [string]: Frame } = {}
	local pathY = size.card + 4
	local freeY = pathY + size.path + 4
	for column = 1, LOOP_COLUMN do
		local holder = frame(scroller, OBSIDIAN, 1)
		holder.Position = UDim2.fromOffset((column - 1) * size.column, 0)
		holder.Size = UDim2.new(0, size.column, 1, 0)
		if column == LOOP_COLUMN then
			buildNode(holder, pathY, "∞", loopsDone, "Plain", size)
			buildCard(
				player,
				holder,
				0,
				{ level = column, track = "Loop", status = "Empty", lockText = "" },
				size,
				compact
			)
			buildCard(player, holder, freeY, {
				level = column,
				track = "Loop",
				reward = SeasonPass.loopReward(state.loops + 1) :: any,
				status = if loops > 0 then "Ready" else "Locked",
				lockText = `🔒 Tras el nivel {Config.Season.Levels}`,
				readyCount = loops,
			}, size, compact)
		else
			local nodeState = if column == level and level > 0
				then "You"
				elseif column == earned + 1 then "Next"
				else "Plain"
			buildNode(holder, pathY, tostring(column), level >= column, nodeState, size)
			for _, track: SeasonPass.Track in { "Premium", "Free" } :: { SeasonPass.Track } do
				local reward = SeasonPass.reward(season, column, track)
				local key = `{column}{track}`
				local claimed = SeasonPass.isClaimed(state, column, track)
				if claimed then
					claimedNow[key] = true
				end
				local lockText = `🔒 Nivel {column}`
				if track == "Premium" and not state.premium then
					lockText = "🔒 Solo premium"
				elseif
					track == "Free"
					and reward
					and not SeasonPass.isCosmeticOnly(reward)
					and level >= column
					and earned < column
				then
					-- Llegó con niveles comprados: lo que no es aspecto se gana jugando.
					lockText = "🔒 Gánalo jugando"
				end
				cardOf[key] = buildCard(player, holder, if track == "Premium" then 0 else freeY, {
					level = column,
					track = track,
					reward = reward,
					status = if not reward
						then "Empty"
						elseif claimed then "Claimed"
						elseif claimable[key] then "Ready"
						else "Locked",
					lockText = lockText,
				}, size, compact)
			end
		end
	end

	-- Lo recién cobrado (desde el dibujo anterior) celebra en su tarjeta.
	local previous = seenClaimed
	if previous then
		for key in claimedNow do
			local card = cardOf[key]
			if not previous[key] and card then
				local levelNumber = tonumber(string.match(key, "^%d+")) or 0
				local track: SeasonPass.Track = if string.find(key, "Premium") then "Premium" else "Free"
				local reward = SeasonPass.reward(season, levelNumber, track)
				if reward then
					local name = describe(reward)
					celebrate(card, name, size)
				end
			end
		end
	end
	seenClaimed = claimedNow

	-- Flechas: tres columnas por pulsación.
	for _, side in { -1, 1 } do
		local arrow = Widgets.button(if side < 0 then "◀" else "▶", tracks)
		local limit = arrow:FindFirstChildOfClass("UISizeConstraint")
		if limit then
			limit:Destroy()
		end
		-- La izquierda, fuera de las tarjetas: en la columna de "PREMIUM"/"GRATIS", entre las dos (en el
		-- teléfono no hay esa columna y va encima de la franja).
		local outside = side < 0 and size.labels > 0
		arrow.AnchorPoint = Vector2.new(if side < 0 and not outside then 0 else 1, 0.5)
		arrow.Position = if outside
			then UDim2.new(0, size.labels - 6, 0.5, 0)
			elseif side < 0 then UDim2.fromScale(0, 0.5)
			else UDim2.fromScale(1, 0.5)
		arrow.Size = UDim2.fromOffset(if compact then 30 else 40, if compact then 44 else 64)
		arrow.BackgroundColor3 = OBSIDIAN
		arrow.BackgroundTransparency = 0.15
		arrow.TextColor3 = LAVA_LIGHT
		arrow.ZIndex = 4
		stroke(arrow, LAVA, 1.5)
		arrow.Activated:Connect(function()
			local maxX = math.max(0, scroller.AbsoluteCanvasSize.X - scroller.AbsoluteWindowSize.X)
			local target = math.clamp(scroller.CanvasPosition.X + side * size.column * 3, 0, maxX)
			TweenService
				:Create(
					scroller,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad),
					{ CanvasPosition = Vector2.new(target, 0) }
				)
				:Play()
		end)
	end

	-- Al abrir, centrada en el primer premio por reclamar (o en el siguiente nivel); al volver a dibujar,
	-- donde estaba.
	local focus = if #claims > 0
		then claims[1].level
		elseif loops > 0 then LOOP_COLUMN
		else math.min(level + 1, LOOP_COLUMN)
	task.defer(function()
		RunService.Heartbeat:Wait()
		if not scroller.Parent then
			return
		end
		local maxX = math.max(0, scroller.AbsoluteCanvasSize.X - scroller.AbsoluteWindowSize.X)
		local x = scrollX or ((focus - 1) * size.column - (scroller.AbsoluteWindowSize.X - size.column) / 2)
		scroller.CanvasPosition = Vector2.new(math.clamp(x, 0, maxX), 0)
		scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			scrollX = scroller.CanvasPosition.X
		end)
	end)

	-- Abajo: el sello premium o la invitación, y las compras.
	local shop = box(list, 3, size.shop)
	local shopLayout = Instance.new("UIListLayout")
	shopLayout.FillDirection = Enum.FillDirection.Horizontal
	shopLayout.Padding = UDim.new(0, 6)
	shopLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
	shopLayout.Parent = shop
	if info.phase ~= "Active" then
		local ended = Widgets.label("🌋 La temporada terminó: lo que no reclamaste ya es tuyo.", shop)
		ended.Size = UDim2.fromScale(1, 1)
		ended.TextColor3 = LAVA_LIGHT
		textCap(ended, size.text)
		return refreshTime
	end
	local products = Config.Shop.Products
	type Offer = { key: string, text: string, show: boolean }
	local offers: { Offer } = {
		{ key = "SeasonPremium", text = `🌋 Premium · {products.SeasonPremium.price} R$`, show = not state.premium },
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
	local shown = 0
	for _, offer in offers do
		if offer.show then
			shown += 1
		end
	end
	local leftShare = if state.premium then 0.6 else 0.3
	if state.premium then
		-- Sello de oro y lava con un brillo que lo recorre.
		local seal = frame(shop, Color3.new(1, 1, 1))
		seal.LayoutOrder = 0
		seal.Size = UDim2.new(leftShare, -6, 1, -6)
		corner(seal, 12)
		gradient(seal, READY_COLOR, LAVA, 0)
		stroke(seal, LAVA_LIGHT, 2)
		local sealText = Widgets.label("👑 PASE PREMIUM ACTIVO 🔥", seal)
		sealText.Size = UDim2.fromScale(1, 1)
		sealText.TextColor3 = DARK_TEXT
		sealText.TextStrokeTransparency = 1
		sealText.Font = Enum.Font.BuilderSansExtraBold
		textCap(sealText, size.text + 4)
		local shine = frame(seal, Color3.new(1, 1, 1))
		shine.Size = UDim2.fromScale(1, 1)
		corner(shine, 12)
		local sweep = Instance.new("UIGradient")
		sweep.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		sweep.Rotation = 20
		sweep.Offset = Vector2.new(-1, 0)
		sweep.Parent = shine
		TweenService:Create(
			sweep,
			TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 1.8),
			{ Offset = Vector2.new(1, 0) }
		):Play()
	else
		local invite = Widgets.label(
			if compact
				then "🔥 La pista de fuego: tesoros solo de esta temporada"
				else "🔥 La pista de fuego guarda los tesoros del volcán: auras, estelas y títulos que solo existen esta temporada",
			shop
		)
		invite.LayoutOrder = 0
		invite.Size = UDim2.fromScale(leftShare, 1)
		invite.TextWrapped = true
		invite.TextXAlignment = Enum.TextXAlignment.Left
		invite.TextColor3 = LAVA_LIGHT
		textCap(invite, size.text - 2)
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
			offerButton.Size = UDim2.new((1 - leftShare) / shown, -6, 1, -4)
			if available then
				offerButton.Activated:Connect(function()
					buy(player, offer.key)
				end)
			end
		end
	end

	return refreshTime
end

return SeasonPassPanel
