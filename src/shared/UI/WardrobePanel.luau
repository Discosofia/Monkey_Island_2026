--!strict
-- Ventana Armario del Lobby (Fase 9, G9; sustituye a la de Estilo): los cosméticos por pestañas en dos
-- filas (trajes, armas, efectos y títulos; skins de mascota, marcos y emotes, G9c), con un selector de
-- rol para los trajes y las armas, y a la izquierda tu avatar en 3D que gira despacio con lo que miras
-- puesto: el traje entero (como se ve en el Lobby y en Dunas) y el arma de su rol en el nivel más alto.
-- En Mascotas el visor enseña la mascota con la skin (la activa si le vale); en Marcos, una ficha con
-- tu nombre y el marco debajo del avatar; en Emotes, el avatar haciendo el emote, y encima de las
-- tarjetas, tu rueda (UI/EmoteWheel).
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
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local PetModels = require(ReplicatedStorage.Shared.PetModels)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local PlayerFrames = require(ReplicatedStorage.Shared.UI.PlayerFrames)
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
	{ id = "Pets", label = "🐾 Mascotas", kinds = { PetSkin = true } },
	{ id = "Frames", label = "🖼️ Marcos", kinds = { Frame = true } },
	{ id = "Emotes", label = "😀 Emotes", kinds = { Emote = true } },
}
-- Pestañas por fila (dos filas: con siete en una, en un teléfono no se leían).
local TABS_PER_ROW = 4
-- Nombre de cada familia de mascotas (Data/Pets "family") en las tarjetas de sus skins.
local FAMILY_NAMES: { [string]: string } = { Felino = "felinos", Perro = "perros" }

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

-- Mascota activa del jugador, si la tiene.
local function activePet(): string?
	local petId = Players.LocalPlayer:GetAttribute("ActivePet")
	return if typeof(petId) == "string" and Pets[petId] then petId else nil
end

-- La mascota y la skin del visor de Mascotas: la skin elegida, en tu mascota activa si le vale (si no,
-- en la suya o en la primera de su familia), o tu mascota activa con la skin que lleva puesta.
local function shownPet(equipped: { [string]: string }): (string?, string?)
	local active = activePet()
	local selected = state.selected
	local cosmetic = if selected then Cosmetics[selected] else nil
	if selected and cosmetic and cosmetic.kind == "PetSkin" then
		if active and CosmeticSlots.fitsPet(cosmetic, active) then
			return active, selected
		elseif cosmetic.petId then
			return cosmetic.petId, selected
		end
		local candidates = {}
		for petId in Pets do
			if CosmeticSlots.fitsPet(cosmetic, petId) then
				table.insert(candidates, petId)
			end
		end
		table.sort(candidates)
		return candidates[1], selected
	end
	if active then
		return active, equipped[CosmeticSlots.petSkinSlot(active)]
	end
	return nil, nil
end

-- Para quién es una skin de mascota: la mascota o su familia.
local function petTarget(cosmetic: Cosmetics.Cosmetic): string
	if cosmetic.petFamily then
		return FAMILY_NAMES[cosmetic.petFamily] or cosmetic.petFamily
	end
	local pet = if cosmetic.petId then Pets[cosmetic.petId] else nil
	return if pet then `{pet.icon} {pet.name}` else ""
end

-- Monta el avatar con el traje y el arma de "roleId" que tocan en el visor, centrado en el origen
-- (sin el arma con "noWeapon": en Emotes, que tapaba los brazos).
local function previewModel(roleId: string, equipped: { [string]: string }, noWeapon: boolean?): Model?
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
	local weapon = if noWeapon
		then nil
		else standingWeapon(roleId, shown(equipped, `WeaponSkin.{roleId}`, "WeaponSkin"))
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

-- El avatar del visor hace el emote "cosmeticId" en bucle: dentro de un WorldModel (sin él, un
-- ViewportFrame no anima) y con las piezas sueltas salvo la raíz, para que las muevan sus uniones.
local function playEmote(viewport: ViewportFrame, model: Model, cosmeticId: string)
	local cosmetic = Cosmetics[cosmeticId]
	local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if not (cosmetic and cosmetic.animationId and humanoid and animator) then
		return
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	model.Parent = world
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.Anchored = false
		end
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = cosmetic.animationId
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track:Play(0)
end

-- Ficha con tu nombre y el marco que toca (el elegido o el puesto), como en el ranking y el grupo.
local function frameCard(pane: Frame, equipped: { [string]: string }, compact: boolean)
	local frameId = shown(equipped, "Frame", "Frame")
	local card = Widgets.label(Players.LocalPlayer.DisplayName, pane)
	card.LayoutOrder = 4
	card.Size = UDim2.new(0.8, 0, 0, if compact then 26 else 34)
	card.BackgroundColor3 = ROW_COLOR
	card.BackgroundTransparency = 0.1
	card.TextColor3 = READY_COLOR
	corner(card, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = card
	textCap(card, if compact then 14 else 18)
	if frameId then
		PlayerFrames.apply(card, frameId)
	else
		card.Text = `{Players.LocalPlayer.DisplayName} · sin marco`
		card.TextColor3 = DETAIL_COLOR
	end
end

-- Visor 3D con el avatar (o la mascota) que gira, el nombre de lo elegido y su rareza debajo.
local function buildPreview(pane: Frame, roleId: string, equipped: { [string]: string }, compact: boolean)
	local viewport = Instance.new("ViewportFrame")
	viewport.LayoutOrder = 1
	viewport.Size = UDim2.new(1, 0, 0, if compact then 190 else 330)
	viewport.BackgroundColor3 = Color3.fromRGB(32, 26, 20)
	viewport.BackgroundTransparency = 0.2
	viewport.Parent = pane
	corner(viewport, 12)
	local model: Model? = nil
	if state.tab == "Pets" then
		local petId, skinId = shownPet(equipped)
		model = if petId then PetModels.build(petId, skinId) else nil
		if not petId then
			local empty = Widgets.label("Pon una mascota en el nido para verla aquí", viewport)
			empty.Size = UDim2.new(1, -20, 0, 40)
			empty.Position = UDim2.new(0, 10, 0.5, -20)
			empty.TextColor3 = NOTE_COLOR
			empty.TextWrapped = true
			textCap(empty, 16)
		end
	else
		model = previewModel(roleId, equipped, state.tab == "Emotes")
	end
	if model then
		local pivot = model:GetPivot()
		-- Más lejos en Emotes (los brazos salen del encuadre de la pose quieta) y en Mascotas (el X-7 se
		-- cortaba).
		local fill = if state.tab == "Emotes" then 0.85 elseif state.tab == "Pets" then 1.1 else 1.05
		RewardModels.frame(viewport, model, fill)
		local selectedEmote = if state.selected
				and Cosmetics[state.selected]
				and Cosmetics[state.selected].kind == "Emote"
			then state.selected
			else nil
		if selectedEmote then
			playEmote(viewport, model, selectedEmote)
		end
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
	if state.tab == "Frames" then
		frameCard(pane, equipped, compact)
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

	-- Pestañas en dos filas y, en trajes y armas, el rol.
	local tabRows = {}
	for index, candidate in TABS do
		local rowIndex = math.ceil(index / TABS_PER_ROW)
		if not tabRows[rowIndex] then
			tabRows[rowIndex] = row(cardsPane, rowIndex, if compact then 30 else 36)
		end
		local button = chip(tabRows[rowIndex], candidate.label, candidate == tab, index)
		button.Size = UDim2.new(1 / TABS_PER_ROW, -5, 1, 0)
		button.MouseButton1Click:Connect(function()
			state.tab = candidate.id
			state.page = 1
			state.selected = nil
			rebuild()
		end)
	end
	if tab.byRole then
		local roles = row(cardsPane, 3, if compact then 28 else 34)
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

	-- En Emotes, tu rueda tal como sale al abrirla (vacía, los de serie).
	if tab.id == "Emotes" then
		local slots = CosmeticSlots.wheel(equipped)
		local icons = {}
		for index = 1, Config.Cosmetics.EmoteSlots do
			local cosmeticId = slots[index]
			table.insert(icons, if cosmeticId and Cosmetics[cosmeticId] then Cosmetics[cosmeticId].icon else "·")
		end
		local wheelNote = Widgets.label(`Tu rueda (tecla . o 😀): {table.concat(icons, "  ")}`, cardsPane)
		wheelNote.LayoutOrder = 3
		wheelNote.Size = UDim2.new(1, 0, 0, if compact then 22 else 28)
		wheelNote.TextColor3 = NOTE_COLOR
		wheelNote.TextXAlignment = Enum.TextXAlignment.Left
		textCap(wheelNote, if compact then 14 else 18)
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
	grid.LayoutOrder = 4
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
		empty.LayoutOrder = 5
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
		local tagText = if isEquipped then `{rarity.name} · puesto` else rarity.name
		if cosmetic.kind == "PetSkin" then
			tagText ..= ` · {petTarget(cosmetic)}`
		end
		local tag = Widgets.label(tagText, card)
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
			local equipText = if cosmetic.kind == "Emote" then "A la rueda" else "Equipar"
			setButton(button, if isEquipped then "Quitar" else equipText, true)
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
		local arrows = row(cardsPane, 6, if compact then 30 else 36)
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
