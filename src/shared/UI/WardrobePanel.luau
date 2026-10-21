--!strict
-- Ventana Armario del Lobby (Fase 9, G9; sustituye a la de Estilo): los cosméticos por pestañas (trajes,
-- armas, efectos y títulos; mascotas, marcos y emotes llegan en G9c), con un selector de rol para los
-- trajes y las armas, y a la izquierda tu avatar en 3D que gira despacio con lo que miras puesto: el
-- traje entero (como se ve en el Lobby y en Dunas) y el arma de su rol en el nivel más alto.
--   - Pulsar una tarjeta la enseña en el avatar; su botón la equipa o la quita (si la tienes) o dice
--     cómo conseguirla (comprar, pase, ganar).
--   - Cada tarjeta lleva el borde de su rareza; la mítica, un borde que brilla y gira.
--   - Sin desplazamiento en PC: cada pestaña enseña una página de tarjetas y, si hay más, flechas.
-- LobbyUIController la rehace al cambiar los datos del jugador; la pestaña, el rol, la tarjeta y la
-- página elegidas se guardan aquí para que no se pierdan.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArmorModels = require(ReplicatedStorage.Shared.ArmorModels)
local CosmeticSlots = require(ReplicatedStorage.Shared.CosmeticSlots)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RewardModels = require(ReplicatedStorage.Shared.RewardModels)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local WeaponTools = require(ReplicatedStorage.Shared.WeaponTools)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local ROW_COLOR = Color3.fromRGB(45, 38, 30)
local READY_COLOR = Color3.fromRGB(242, 178, 36)
local BLOCKED_COLOR = Color3.fromRGB(90, 90, 90)
local TAB_COLOR = Color3.fromRGB(70, 58, 44)
local NOTE_COLOR = Color3.fromRGB(255, 220, 150)
local DETAIL_COLOR = Color3.fromRGB(215, 205, 190)
local MYTHIC_GOLD = Color3.fromRGB(255, 214, 110)
-- Vueltas por segundo del avatar de la vista previa.
local SPIN_SPEED = 0.12
-- Tamaño del arma de la vista previa respecto al de verdad.
local WEAPON_PREVIEW_SCALE = 0.7

type Tab = { id: string, label: string, kinds: { [string]: boolean }, byRole: boolean? }
local TABS: { Tab } = {
	{ id = "Outfit", label = "👕 Trajes", kinds = { Outfit = true }, byRole = true },
	{ id = "Weapon", label = "⚔️ Armas", kinds = { WeaponSkin = true }, byRole = true },
	{ id = "Effects", label = "✨ Efectos", kinds = { Trail = true, Aura = true } },
	{ id = "Titles", label = "🏷️ Títulos", kinds = { Title = true } },
}

-- "rebuild" vuelve a dibujar la ventana (LobbyUIController.render) tras elegir pestaña, rol o tarjeta.
export type Options = { compact: boolean, rebuild: () -> () }

local WardrobePanel = {}

-- Lo elegido, que sobrevive a que la ventana se rehaga.
local state = {
	tab = "Outfit",
	role = nil :: string?,
	selected = nil :: string?,
	page = 1,
	angle = 0,
}
local rebuild: () -> () = function() end

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

-- Botón pequeño de pestaña o de rol: dorado si está elegido.
local function chip(parent: Instance, text: string, chosen: boolean, order: number): TextButton
	local button = Widgets.button(text, parent)
	button.LayoutOrder = order
	local limit = button:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit:Destroy()
	end
	button.BackgroundColor3 = if chosen then READY_COLOR else TAB_COLOR
	button.TextColor3 = if chosen then Color3.fromRGB(40, 25, 5) else Color3.new(1, 1, 1)
	textCap(button, 18)
	return button
end

local function row(parent: Instance, order: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	return frame
end

-- Borde de la rareza de una tarjeta: fino y de su color; el legendario más grueso, y el mítico con un
-- degradado de su color y oro que gira.
local function rarityBorder(card: Frame, rarityId: string)
	local rarity = Rarities[rarityId] or Rarities.Common
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = rarity.color
	stroke.Thickness = if rarityId == "Mythic" then 3 elseif rarityId == "Legendary" then 2.5 else 1.5
	stroke.Parent = card
	if rarityId == "Mythic" then
		stroke.Color = Color3.new(1, 1, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarity.color),
			ColorSequenceKeypoint.new(0.5, MYTHIC_GOLD),
			ColorSequenceKeypoint.new(1, rarity.color),
		})
		gradient.Parent = stroke
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			if not card.Parent then
				connection:Disconnect()
				return
			end
			gradient.Rotation = (os.clock() * 120) % 360
		end)
	end
end

-- Cómo se consigue un cosmético que no tienes, y si el botón compra (y qué).
local function howToGet(cosmetic: Cosmetics.Cosmetic): (string, (() -> ())?)
	local source = cosmetic.source
	local player = Players.LocalPlayer
	if source.earned == "Rescue" then
		return "Gana una partida", nil
	elseif source.earned == "MasterVictory" then
		return "Gana con el nivel 4", nil
	elseif source.season then
		return "Pase de temporada", nil
	elseif source.gamePassId and source.gamePassId ~= 0 then
		local gamePassId = source.gamePassId
		return "Comprar", function()
			MarketplaceService:PromptGamePassPurchase(player, gamePassId)
		end
	elseif source.productId and source.productId ~= 0 then
		local productId = source.productId
		return if source.price then `Comprar · {source.price} R$` else "Comprar",
			function()
				MarketplaceService:PromptProductPurchase(player, productId)
			end
	elseif source.amber then
		return `{source.amber} de Ámbar`, nil
	end
	return if source.price then `Próximamente · {source.price} R$` else "Próximamente", nil
end

-- Lo que lleva puesto el avatar de la vista previa en cada tipo: lo elegido en la ventana o, si no,
-- lo equipado.
local function shown(equipped: { [string]: string }, slot: string, kind: string): string?
	local selected = state.selected
	if selected and Cosmetics[selected] and Cosmetics[selected].kind == kind then
		return if CosmeticSlots.slot(Cosmetics[selected]) == slot then selected else nil
	end
	return equipped[slot]
end

-- El arma del rol en su nivel más alto, de pie al lado derecho del avatar, con el aspecto "skinId".
local function standingWeapon(roleId: string, skinId: string?): Model?
	local weaponId = WeaponTools.roleWeapon(roleId, WeaponTools.MAX_LEVEL)
	if not weaponId then
		return nil
	end
	local tool = WeaponTools.build(weaponId, skinId)
	local model = Instance.new("Model")
	model.Name = "Weapon"
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.Parent = model
		end
	end
	tool:Destroy()
	local handle = model:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		model.PrimaryPart = handle
	end
	return model
end

-- Monta el avatar con el traje y el arma de "roleId" que tocan en el visor, centrado en el origen.
local function previewModel(roleId: string, equipped: { [string]: string }): Model?
	local player = Players.LocalPlayer
	local selected = state.selected
	local effect = if selected and Cosmetics[selected] and not Cosmetics[selected].role then selected else ""
	local avatar = RewardModels.avatar(player.Character, effect)
	if not avatar then
		return nil
	end
	local previous = avatar:FindFirstChild("ArmorPiece")
	if previous then
		previous:Destroy()
	end
	local outfitId = shown(equipped, `Outfit.{roleId}`, "Outfit")
	if outfitId and ArmorModels.hasOutfit(outfitId) then
		ArmorModels.wear(avatar, nil, roleId, outfitId, ArmorModels.MAX_GRADE)
		for _, descendant in avatar:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
	end
	local model = Instance.new("Model")
	model.Name = "Preview"
	avatar.Parent = model
	local weapon = standingWeapon(roleId, shown(equipped, `WeaponSkin.{roleId}`, "WeaponSkin"))
	if weapon then
		-- Más pequeña que en la mano (las de nivel 4 miden casi lo que el avatar) y apoyada en el suelo
		-- a su derecha, un poco inclinada hacia él.
		weapon:ScaleTo(WEAPON_PREVIEW_SCALE)
		local _, avatarSize = avatar:GetBoundingBox()
		weapon:PivotTo(CFrame.Angles(0, 0, 0.12))
		local box, size = weapon:GetBoundingBox()
		local lift = size.Y / 2 - box.Position.Y
		weapon:PivotTo(weapon:GetPivot() + Vector3.new(avatarSize.X / 2 + 0.7 - box.Position.X, lift, -box.Position.Z))
		weapon.Parent = model
	end
	return model
end

-- Visor 3D con el avatar que gira, el nombre de lo elegido y su rareza debajo.
local function buildPreview(pane: Frame, roleId: string, equipped: { [string]: string }, compact: boolean)
	local viewport = Instance.new("ViewportFrame")
	viewport.LayoutOrder = 1
	viewport.Size = UDim2.new(1, 0, 0, if compact then 190 else 330)
	viewport.BackgroundColor3 = Color3.fromRGB(32, 26, 20)
	viewport.BackgroundTransparency = 0.2
	viewport.Parent = pane
	corner(viewport, 12)
	local model = previewModel(roleId, equipped)
	if model then
		local pivot = model:GetPivot()
		RewardModels.frame(viewport, model, 1.05)
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function(dt)
			if not viewport.Parent then
				connection:Disconnect()
				return
			end
			state.angle = (state.angle + dt * SPIN_SPEED * math.pi * 2) % (math.pi * 2)
			model:PivotTo(pivot * CFrame.Angles(0, state.angle, 0))
		end)
	end
	local selected = if state.selected then Cosmetics[state.selected] else nil
	local caption =
		Widgets.label(if selected then `{selected.icon} {selected.name}` else "Elige algo para verlo puesto", pane)
	caption.LayoutOrder = 2
	caption.Size = UDim2.new(1, 0, 0, if compact then 20 else 28)
	caption.TextColor3 = if selected then selected.color else NOTE_COLOR
	textCap(caption, if compact then 14 else 20)
	if selected then
		local rarity = Rarities[selected.rarity] or Rarities.Common
		local tag = Widgets.label(rarity.name, pane)
		tag.LayoutOrder = 3
		tag.Size = UDim2.new(1, 0, 0, if compact then 16 else 22)
		tag.TextColor3 = rarity.color
		textCap(tag, if compact then 12 else 16)
	end
end

-- Construye la ventana dentro de "list" (la lista de la ventana del Lobby).
function WardrobePanel.build(list: Instance, options: Options)
	local player = Players.LocalPlayer
	local compact = options.compact
	local equipped: { [string]: string } = Progression.read(player).cosmetics
	rebuild = options.rebuild
	local roleAttribute = player:GetAttribute("Role")
	state.role = state.role or (if typeof(roleAttribute) == "string" then roleAttribute else "Guerrero")
	local roleId = state.role :: string
	local tab = TABS[1]
	for _, candidate in TABS do
		if candidate.id == state.tab then
			tab = candidate
		end
	end

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
	local function pane(order: number, width: number): Frame
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(width, -5, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Parent = holder
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.Parent = frame
		return frame
	end
	local previewPane = pane(1, 0.36)
	local cardsPane = pane(2, 0.64)

	-- Pestañas y, en trajes y armas, el rol.
	local tabs = row(cardsPane, 1, if compact then 32 else 40)
	for index, candidate in TABS do
		local button = chip(tabs, candidate.label, candidate == tab, index)
		button.Size = UDim2.new(1 / #TABS, -5, 1, 0)
		button.MouseButton1Click:Connect(function()
			state.tab = candidate.id
			state.page = 1
			state.selected = nil
			rebuild()
		end)
	end
	if tab.byRole then
		local roles = row(cardsPane, 2, if compact then 28 else 34)
		local roleIds = {}
		for id in Roles do
			table.insert(roleIds, id)
		end
		table.sort(roleIds, function(a, b)
			return Roles[a].order < Roles[b].order
		end)
		for index, id in roleIds do
			local button = chip(roles, `{Roles[id].icon} {Roles[id].name}`, id == roleId, index)
			button.Size = UDim2.new(1 / #roleIds, -5, 1, 0)
			button.MouseButton1Click:Connect(function()
				state.role = id
				state.page = 1
				state.selected = nil
				rebuild()
			end)
		end
	end

	-- Los cosméticos de la pestaña (y del rol), de más raro a menos.
	local ids = {}
	for id, cosmetic in Cosmetics do
		if tab.kinds[cosmetic.kind] and (not tab.byRole or cosmetic.role == roleId) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local ra = (Rarities[Cosmetics[a].rarity] or Rarities.Common).order
		local rb = (Rarities[Cosmetics[b].rarity] or Rarities.Common).order
		if ra ~= rb then
			return ra > rb
		end
		return Cosmetics[a].order < Cosmetics[b].order
	end)
	local perPage = if compact then 6 else 9
	local pages = math.max(1, math.ceil(#ids / perPage))
	state.page = math.clamp(state.page, 1, pages)

	local grid = Instance.new("Frame")
	grid.LayoutOrder = 3
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Parent = cardsPane
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(1 / 3, -6, 0, if compact then 86 else 112)
	gridLayout.CellPadding = UDim2.fromOffset(6, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	if #ids == 0 then
		local empty = Widgets.label(
			if tab.byRole then `Aún no hay nada de {Roles[roleId].name}: ¡pronto!` else "Aún no hay nada aquí",
			cardsPane
		)
		empty.LayoutOrder = 4
		empty.Size = UDim2.new(1, 0, 0, 30)
		empty.TextColor3 = NOTE_COLOR
		textCap(empty, 18)
	end

	for index = (state.page - 1) * perPage + 1, math.min(#ids, state.page * perPage) do
		local cosmeticId = ids[index]
		local cosmetic = Cosmetics[cosmeticId]
		local owned = player:GetAttribute(`Cosmetic_{cosmeticId}`) == true
		local isEquipped = CosmeticSlots.equippedIn(equipped, cosmeticId) ~= nil
		local card = Instance.new("TextButton")
		card.LayoutOrder = index
		card.Text = ""
		card.AutoButtonColor = false
		card.BackgroundColor3 = if state.selected == cosmeticId then Color3.fromRGB(70, 58, 44) else ROW_COLOR
		card.BackgroundTransparency = 0.1
		card.Parent = grid
		corner(card, 10)
		rarityBorder(card :: any, cosmetic.rarity)
		card.MouseButton1Click:Connect(function()
			state.selected = if state.selected == cosmeticId then nil else cosmeticId
			rebuild()
		end)

		local title = Widgets.label(`{cosmetic.icon} {(string.gsub(cosmetic.name, "^[^:]+: ", ""))}`, card)
		title.Position = UDim2.fromOffset(6, 4)
		title.Size = UDim2.new(1, -12, 0, if compact then 18 else 22)
		title.TextColor3 = cosmetic.color
		title.TextXAlignment = Enum.TextXAlignment.Left
		textCap(title, if compact then 14 else 17)
		local rarity = Rarities[cosmetic.rarity] or Rarities.Common
		local tag = Widgets.label(if isEquipped then `{rarity.name} · puesto` else rarity.name, card)
		tag.Position = UDim2.fromOffset(6, if compact then 22 else 27)
		tag.Size = UDim2.new(1, -12, 0, if compact then 14 else 16)
		tag.TextColor3 = rarity.color
		tag.TextXAlignment = Enum.TextXAlignment.Left
		textCap(tag, if compact then 11 else 13)
		if not compact then
			local detail = Widgets.label(cosmetic.description, card)
			detail.Position = UDim2.fromOffset(6, 45)
			detail.Size = UDim2.new(1, -12, 0, 26)
			detail.Font = Enum.Font.BuilderSans
			detail.TextWrapped = true
			detail.TextXAlignment = Enum.TextXAlignment.Left
			detail.TextYAlignment = Enum.TextYAlignment.Top
			detail.TextColor3 = DETAIL_COLOR
			textCap(detail, 12)
		end
		local button = Widgets.button("", card)
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.5, 0, 1, -5)
		button.Size = UDim2.new(1, -10, 0, if compact then 28 else 32)
		local limit = button:FindFirstChildOfClass("UISizeConstraint")
		if limit then
			limit:Destroy()
		end
		textCap(button, if compact then 13 else 15)
		if owned then
			setButton(button, if isEquipped then "Quitar" else "Equipar", true)
			button.MouseButton1Click:Connect(function()
				Remotes.EquipCosmetic:FireServer(cosmeticId)
			end)
		else
			local text, buy = howToGet(cosmetic)
			setButton(button, text, buy ~= nil)
			if buy then
				button.MouseButton1Click:Connect(buy)
			end
		end
	end

	if pages > 1 then
		local arrows = row(cardsPane, 5, if compact then 30 else 36)
		local previous = chip(arrows, "◀", false, 1)
		previous.Size = UDim2.new(0, 60, 1, 0)
		local pageLabel = Widgets.label(`{state.page} / {pages}`, arrows)
		pageLabel.LayoutOrder = 2
		pageLabel.Size = UDim2.new(0, 70, 1, 0)
		local nextButton = chip(arrows, "▶", false, 3)
		nextButton.Size = UDim2.new(0, 60, 1, 0)
		previous.MouseButton1Click:Connect(function()
			state.page = if state.page <= 1 then pages else state.page - 1
			rebuild()
		end)
		nextButton.MouseButton1Click:Connect(function()
			state.page = if state.page >= pages then 1 else state.page + 1
			rebuild()
		end)
	end

	buildPreview(previewPane, roleId, equipped, compact)
end

-- Rehace la ventana (lo pone LobbyUIController: la vuelve a dibujar con los datos de ahora).
function rebuild() end

return WardrobePanel
