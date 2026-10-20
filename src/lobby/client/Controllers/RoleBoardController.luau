--!strict
-- Cartel de los roles en la playa, frente a la proa del «Esperanza» (etiqueta
-- Config.Lobby.RoleBoardTag, lo pone World/LobbyBuilder). Cada cliente lo dibuja con lo suyo: una
-- columna por rol con tu nivel en cada uno y el que tienes elegido resaltado. Su aviso
-- ("RolesPrompt", tecla E) abre la ventana de roles (LobbyUIController).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)

local CARD_COLOR = Color3.fromRGB(45, 38, 30)
local SELECTED_COLOR = Color3.fromRGB(242, 178, 36)
local SELECTED_TEXT = Color3.fromRGB(40, 25, 5)
local LEVEL_COLOR = Color3.fromRGB(255, 215, 90)

local RoleBoardController = {}

local function text(value: string, parent: Instance, position: UDim2, size: UDim2, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = value
	label.Font = font
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = parent
	return label
end

local function corner(parent: Instance, radius: number)
	local instance = Instance.new("UICorner")
	instance.CornerRadius = UDim.new(radius, 0)
	instance.Parent = parent
end

local function roleIds(): { string }
	local ids = {}
	for roleId in Roles do
		table.insert(ids, roleId)
	end
	table.sort(ids, function(a, b)
		return Roles[a].order < Roles[b].order
	end)
	return ids
end

function RoleBoardController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local boards: { [BasePart]: SurfaceGui } = {}

	-- Una columna por rol: icono, nombre, tu nivel, la pasiva y abajo "Pulsa E" o "Elegido". El
	-- título va en la cabecera del cartel (World/LobbyBuilder).
	local function draw(gui: SurfaceGui)
		gui:ClearAllChildren()
		local data = Progression.read(player)
		local selected = Progression.validRole(player:GetAttribute("SelectedRole"))
		for index, roleId in roleIds() do
			local role = Roles[roleId]
			local isSelected = roleId == selected
			local ink = if isSelected then SELECTED_TEXT else Color3.new(1, 1, 1)
			local card = Instance.new("Frame")
			card.Position = UDim2.fromScale(0.012 + (index - 1) * 0.247, 0.04)
			card.Size = UDim2.fromScale(0.235, 0.92)
			card.BackgroundColor3 = if isSelected then SELECTED_COLOR else CARD_COLOR
			card.BackgroundTransparency = if isSelected then 0 else 0.1
			card.Parent = gui
			corner(card, 0.08)
			text(role.icon, card, UDim2.fromScale(0.15, 0.03), UDim2.fromScale(0.7, 0.26), Enum.Font.BuilderSansBold)
			local name = text(
				role.name,
				card,
				UDim2.fromScale(0.06, 0.3),
				UDim2.fromScale(0.88, 0.13),
				Enum.Font.BuilderSansBold
			)
			name.TextColor3 = ink
			local level = Progression.level(data.roleXp[roleId] or 0)
			local levelText = text(
				`Nivel {level}`,
				card,
				UDim2.fromScale(0.1, 0.43),
				UDim2.fromScale(0.8, 0.09),
				Enum.Font.BuilderSansBold
			)
			levelText.TextColor3 = if isSelected then SELECTED_TEXT else LEVEL_COLOR
			local passive = text(
				role.passive,
				card,
				UDim2.fromScale(0.07, 0.55),
				UDim2.fromScale(0.86, 0.26),
				Enum.Font.BuilderSans
			)
			passive.TextColor3 = ink
			passive.TextWrapped = true
			local badge = Instance.new("TextLabel")
			badge.AnchorPoint = Vector2.new(0.5, 0)
			badge.Position = UDim2.fromScale(0.5, 0.84)
			badge.Size = UDim2.fromScale(0.84, 0.12)
			badge.BackgroundColor3 = if isSelected then CARD_COLOR else SELECTED_COLOR
			badge.Text = if isSelected then "✔ ELEGIDO" else "Pulsa E"
			badge.TextColor3 = if isSelected then SELECTED_COLOR else SELECTED_TEXT
			badge.Font = Enum.Font.BuilderSansExtraBold
			badge.TextScaled = true
			badge.Parent = card
			corner(badge, 0.3)
			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0.12, 0)
			padding.PaddingBottom = UDim.new(0.12, 0)
			padding.Parent = badge
		end
	end

	local function add(instance: Instance)
		if not instance:IsA("BasePart") or boards[instance] then
			return
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name = "TablaRoles"
		gui.Adornee = instance
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0 -- siempre legible, también de noche
		gui.ResetOnSpawn = false
		gui.Parent = playerGui
		boards[instance] = gui
		draw(gui)
	end

	CollectionService:GetInstanceAddedSignal(Config.Lobby.RoleBoardTag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Config.Lobby.RoleBoardTag):Connect(function(instance)
		local gui = boards[instance :: BasePart]
		if gui then
			gui:Destroy()
			boards[instance :: BasePart] = nil
		end
	end)
	for _, instance in CollectionService:GetTagged(Config.Lobby.RoleBoardTag) do
		add(instance)
	end

	player.AttributeChanged:Connect(function(attribute)
		if attribute == "SelectedRole" or attribute == "Progress" then
			for _, gui in boards do
				draw(gui)
			end
		end
	end)
end

return RoleBoardController
