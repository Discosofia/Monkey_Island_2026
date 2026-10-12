--!strict
-- Barra de inventario arriba a la izquierda: cantidad de cada material.
-- Al conseguir algo, el número parpadea en amarillo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local NORMAL_COLOR = Color3.new(1, 1, 1)
local GAIN_COLOR = Color3.fromRGB(255, 220, 90)
local FLASH_SECONDS = 0.4

local InventoryHUDController = {}

local function sortedItemIds(): { string }
	local ids = {}
	for id in Items do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return Items[a].order < Items[b].order
	end)
	return ids
end

local function createSlot(bar: Frame, player: Player, itemId: string, slotWidth: number)
	local item = Items[itemId]
	local label = Widgets.label("", bar)
	label.Name = itemId
	label.LayoutOrder = item.order
	label.Size = UDim2.fromScale(slotWidth, 1)

	local shown = Inventory.count(player, itemId)
	local function refresh()
		local count = Inventory.count(player, itemId)
		label.Text = `{item.icon} {count}`
		if count > shown then
			label.TextColor3 = GAIN_COLOR
			task.delay(FLASH_SECONDS, function()
				label.TextColor3 = NORMAL_COLOR
			end)
		end
		shown = count
	end

	player:GetAttributeChangedSignal(Inventory.attributeName(itemId)):Connect(refresh)
	refresh()
end

function InventoryHUDController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("InventoryHUD", player:WaitForChild("PlayerGui"))

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	-- Arriba a la izquierda: abajo está la barra rápida de Roblox (armas y herramientas).
	bar.AnchorPoint = Vector2.new(0, 0)
	bar.Position = UDim2.fromScale(0.02, 0.02)
	bar.Size = UDim2.fromScale(0.28, 0.07)
	bar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bar.BackgroundTransparency = 0.35
	bar.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(320, 48)
	sizeLimit.Parent = bar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local itemIds = sortedItemIds()
	for _, itemId in itemIds do
		createSlot(bar, player, itemId, 1 / #itemIds)
	end
end

return InventoryHUDController
