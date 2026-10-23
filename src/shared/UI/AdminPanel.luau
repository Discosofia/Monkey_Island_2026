--!strict
-- Panel de administradores (ServerShared/Admin), en los tres places y también en el juego publicado:
-- un botón "👑 Admin" encima del de Pruebas que despliega los jugadores del servidor con "Dar todo"
-- (todos los cosméticos, emotes incluidos, las mascotas y las monturas). Solo sale si el servidor ha
-- marcado al jugador con el atributo "IsAdmin", y el servidor lo vuelve a comprobar al pedirlo.

local Players = game:GetService("Players")

local Remotes = require(script.Parent.Parent.Remotes)
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

	-- Una fila por jugador del servidor (tú el primero): su nombre y "Dar todo".
	local function render()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local title = Widgets.label("Dar todo (cosméticos, emotes, mascotas, monturas)", list)
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
			name.Size = UDim2.new(0.6, -6, 1, 0)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local button = Instance.new("TextButton")
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, -4, 0.5, 0)
			button.Size = UDim2.new(0.4, -6, 1, -8)
			button.BackgroundColor3 = Color3.fromRGB(242, 178, 36)
			button.TextColor3 = Color3.fromRGB(40, 25, 5)
			button.Font = Enum.Font.BuilderSansBold
			button.TextScaled = true
			button.Text = "🔓 Dar todo"
			button.Parent = row
			local userId = other.UserId
			button.MouseButton1Click:Connect(function()
				Remotes.AdminGiveAll:FireServer(userId)
			end)
		end
	end

	toggle.MouseButton1Click:Connect(function()
		list.Visible = not list.Visible
		if list.Visible then
			render()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if list.Visible then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function()
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
