--!strict
-- Panel de administradores (ServerShared/Admin), en los tres places y también en el juego publicado:
-- un botón "👑 Admin" encima del de Pruebas que despliega los jugadores del servidor con "Dar todo"
-- (todos los cosméticos, emotes incluidos, las mascotas y las monturas) y "Elegir", que abre al lado el
-- listado de los huevos (por rareza), las mascotas, las monturas y los cosméticos del juego, con buscador, para darle
-- una sola cosa. Solo sale si el servidor ha marcado al jugador con el atributo "IsAdmin", y el servidor
-- lo vuelve a comprobar al pedirlo.

local Players = game:GetService("Players")

local Config = require(script.Parent.Parent.Config)
local Cosmetics = require(script.Parent.Parent.Data.Cosmetics)
local Mounts = require(script.Parent.Parent.Data.Mounts)
local Pets = require(script.Parent.Parent.Data.Pets)
local Rarities = require(script.Parent.Parent.Data.Rarities)
local Remotes = require(script.Parent.Parent.Remotes)
local Rewards = require(script.Parent.Parent.Rewards)
local Widgets = require(script.Parent.Widgets)

local AdminPanel = {}

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

	local list = Instance.new("ScrollingFrame")
	list.AnchorPoint = Vector2.new(anchorX, 1)
	list.Position = UDim2.fromScale(side, bottom - 0.07)
	list.Size = UDim2.fromScale(0.26, 0.45)
	list.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	list.BackgroundTransparency = 0.2
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Visible = false
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Listado de huevos, mascotas, monturas y cosméticos, al lado del de jugadores (hacia el centro de la pantalla).
	local picker = Instance.new("Frame")
	picker.AnchorPoint = Vector2.new(anchorX, 1)
	picker.Position = UDim2.fromScale(if place == "Lobby" then side - 0.27 else side + 0.27, bottom - 0.07)
	picker.Size = UDim2.fromScale(0.3, 0.6)
	picker.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	picker.BackgroundTransparency = 0.2
	picker.BorderSizePixel = 0
	picker.Visible = false
	picker.Parent = gui
	local pickerTitle = Widgets.label("", picker)
	pickerTitle.Position = UDim2.fromOffset(6, 4)
	pickerTitle.Size = UDim2.new(1, -44, 0, 26)
	pickerTitle.TextColor3 = Color3.fromRGB(255, 220, 150)
	pickerTitle.TextXAlignment = Enum.TextXAlignment.Left
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -4, 0, 4)
	close.Size = UDim2.fromOffset(30, 26)
	close.BackgroundColor3 = Color3.fromRGB(90, 40, 30)
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.BuilderSansBold
	close.TextScaled = true
	close.Text = "✕"
	close.Parent = picker
	local search = Instance.new("TextBox")
	search.Position = UDim2.fromOffset(6, 34)
	search.Size = UDim2.new(1, -12, 0, 30)
	search.BackgroundColor3 = Color3.fromRGB(45, 38, 30)
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
	local items = Instance.new("ScrollingFrame")
	items.Position = UDim2.fromOffset(6, 70)
	items.Size = UDim2.new(1, -12, 1, -76)
	items.BackgroundTransparency = 1
	items.BorderSizePixel = 0
	items.ScrollBarThickness = 6
	items.CanvasSize = UDim2.new()
	items.AutomaticCanvasSize = Enum.AutomaticSize.Y
	items.Parent = picker
	local itemsLayout = Instance.new("UIListLayout")
	itemsLayout.Padding = UDim.new(0, 3)
	itemsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	itemsLayout.Parent = items

	-- A quién se le da lo que se pulse en el listado.
	local targetUserId: number? = nil

	-- Todo lo que se puede elegir: los huevos (una rareza cada uno), las mascotas, las monturas y los
	-- cosméticos, en este orden. "search" junta lo que encuentra el buscador.
	type Entry = { kind: "Egg" | "Pet" | "Mount" | "Cosmetic", id: string, title: string, info: string, rarity: string }
	local entries: { Entry } = {}
	local function byRarity(a: string, b: string): boolean
		return (Rarities[a] or Rarities.Common).order < (Rarities[b] or Rarities.Common).order
	end

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

	-- Mascotas: por rareza y después por nombre.
	local petIds = {}
	for petId in Pets do
		table.insert(petIds, petId)
	end
	table.sort(petIds, function(a, b)
		if Pets[a].rarity ~= Pets[b].rarity then
			return byRarity(Pets[a].rarity, Pets[b].rarity)
		end
		return Pets[a].name < Pets[b].name
	end)
	for _, petId in petIds do
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

	-- Monturas: por rareza y después por nombre.
	local mountIds = {}
	for mountId in Mounts do
		table.insert(mountIds, mountId)
	end
	table.sort(mountIds, function(a, b)
		if Mounts[a].rarity ~= Mounts[b].rarity then
			return byRarity(Mounts[a].rarity, Mounts[b].rarity)
		end
		return Mounts[a].name < Mounts[b].name
	end)
	for _, mountId in mountIds do
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

	-- Una fila por cosa. Se hacen una vez: el buscador solo las esconde.
	local searchable: { [Frame]: string } = {}
	for index, entry in entries do
		local rarity = Rarities[entry.rarity] or Rarities.Common
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 36)
		row.BackgroundColor3 = Color3.fromRGB(45, 38, 30)
		row.BorderSizePixel = 0
		row.Parent = items
		local name = Widgets.label(entry.title, row)
		name.Position = UDim2.fromOffset(6, 1)
		name.Size = UDim2.new(0.75, -6, 0.6, 0)
		name.TextColor3 = rarity.color
		name.TextXAlignment = Enum.TextXAlignment.Left
		local info = Widgets.label(entry.info, row)
		info.Position = UDim2.new(0, 6, 0.6, 0)
		info.Size = UDim2.new(0.75, -6, 0.4, -1)
		info.TextColor3 = Color3.fromRGB(190, 180, 160)
		info.Font = Enum.Font.BuilderSans
		info.TextXAlignment = Enum.TextXAlignment.Left
		local give = Instance.new("TextButton")
		give.AnchorPoint = Vector2.new(1, 0.5)
		give.Position = UDim2.new(1, -4, 0.5, 0)
		give.Size = UDim2.new(0.25, -6, 1, -8)
		give.BackgroundColor3 = Color3.fromRGB(242, 178, 36)
		give.TextColor3 = Color3.fromRGB(40, 25, 5)
		give.Font = Enum.Font.BuilderSansBold
		give.TextScaled = true
		give.Text = "🎁 Dar"
		give.Parent = row
		give.MouseButton1Click:Connect(function()
			if targetUserId then
				Remotes.AdminGive:FireServer(targetUserId, entry.kind, entry.id)
			end
		end)
		searchable[row] = string.lower(`{entry.id} {entry.title} {entry.info}`)
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		local query = string.lower(search.Text)
		for row, text in searchable do
			row.Visible = string.find(text, query, 1, true) ~= nil
		end
	end)

	local function openPicker(other: Player)
		targetUserId = other.UserId
		pickerTitle.Text = `Dar a {other.DisplayName}`
		picker.Visible = true
	end
	close.MouseButton1Click:Connect(function()
		picker.Visible = false
	end)

	-- Una fila por jugador del servidor (tú el primero): su nombre, "Elegir" y "Dar todo".
	local function render()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local title = Widgets.label("Elegir un huevo, mascota, montura o cosmético, o dar todo", list)
		title.LayoutOrder = 0
		title.Size = UDim2.new(1, -8, 0, 26)
		title.TextColor3 = Color3.fromRGB(255, 220, 150)
		local players = Players:GetPlayers()
		table.sort(players, function(a, b)
			if a == player or b == player then
				return a == player
			end
			return a.Name:lower() < b.Name:lower()
		end)
		for index, other in players do
			local row = Instance.new("Frame")
			row.LayoutOrder = index
			row.Size = UDim2.new(1, -8, 0, 40)
			row.BackgroundColor3 = Color3.fromRGB(45, 38, 30)
			row.BorderSizePixel = 0
			row.Parent = list
			local name = Widgets.label(`{other.DisplayName} (@{other.Name})`, row)
			name.Position = UDim2.fromOffset(6, 0)
			name.Size = UDim2.new(0.44, -6, 1, 0)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local function rowButton(text: string, right: number, width: number): TextButton
				local button = Instance.new("TextButton")
				button.AnchorPoint = Vector2.new(1, 0.5)
				button.Position = UDim2.new(1 - right, -4, 0.5, 0)
				button.Size = UDim2.new(width, -6, 1, -8)
				button.BackgroundColor3 = Color3.fromRGB(242, 178, 36)
				button.TextColor3 = Color3.fromRGB(40, 25, 5)
				button.Font = Enum.Font.BuilderSansBold
				button.TextScaled = true
				button.Text = text
				button.Parent = row
				return button
			end
			local userId = other.UserId
			rowButton("🔓 Dar todo", 0, 0.3).MouseButton1Click:Connect(function()
				Remotes.AdminGiveAll:FireServer(userId)
			end)
			rowButton("🎁 Elegir", 0.3, 0.26).MouseButton1Click:Connect(function()
				openPicker(other)
			end)
		end
	end

	toggle.MouseButton1Click:Connect(function()
		list.Visible = not list.Visible
		if list.Visible then
			render()
		else
			picker.Visible = false
		end
	end)
	Players.PlayerAdded:Connect(function()
		if list.Visible then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function(other)
		if other.UserId == targetUserId then
			picker.Visible = false
		end
		if list.Visible then
			task.defer(render)
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
