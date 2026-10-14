--!strict
-- Materiales y botín del jugador (la mochila de Roblox solo muestra herramientas):
--   - Avisos breves a la derecha al ganar o gastar algo: "+3 🌲 Madera (12)".
--   - Panel con todos los materiales: tecla B en PC, Y en mando o el botón táctil "Bolsa".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local ActionButtons = require(script.Parent.Parent.ActionButtons)

local ACTION = "ToggleMaterials"
local GAIN_COLOR = Color3.fromRGB(150, 235, 130)
local SPEND_COLOR = Color3.fromRGB(255, 170, 110)
local FEED_SECONDS = 2.5
local FEED_MAX_ENTRIES = 4
local ROW_HEIGHT = 34

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

local function newFrame(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.25
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	return frame
end

local function newList(parent: Instance, padding: number)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	layout.Parent = parent
end

-- Columna de avisos a la derecha; cada uno desaparece a los pocos segundos.
local function createFeed(gui: ScreenGui): (text: string, color: Color3) -> ()
	local feed = Instance.new("Frame")
	feed.Name = "Feed"
	feed.BackgroundTransparency = 1
	feed.AnchorPoint = Vector2.new(1, 0.5)
	feed.Position = UDim2.fromScale(0.98, 0.45)
	feed.Size = UDim2.fromOffset(240, (ROW_HEIGHT + 4) * FEED_MAX_ENTRIES)
	feed.Parent = gui
	newList(feed, 4)

	local order = 0
	return function(text: string, color: Color3)
		order += 1
		local entry = Widgets.label(text, feed)
		entry.LayoutOrder = order
		entry.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		entry.TextColor3 = color
		entry.TextXAlignment = Enum.TextXAlignment.Right
		task.delay(FEED_SECONDS, function()
			entry:Destroy()
		end)
		-- Si hay demasiados, se va el más antiguo.
		local entries = {}
		for _, child in feed:GetChildren() do
			if child:IsA("TextLabel") then
				table.insert(entries, child)
			end
		end
		if #entries > FEED_MAX_ENTRIES then
			table.sort(entries, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			entries[1]:Destroy()
		end
	end
end

local function createPanel(gui: ScreenGui): Frame
	local panel = newFrame("MaterialsPanel", gui)
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.fromScale(0.02, 0.5)
	panel.Size = UDim2.fromOffset(230, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel
	newList(panel, 2)

	local title = Widgets.label("🎒 Materiales (B)", panel)
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	title.TextXAlignment = Enum.TextXAlignment.Left
	return panel
end

function InventoryHUDController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("InventoryHUD", player:WaitForChild("PlayerGui"))
	local addFeedEntry = createFeed(gui)
	local panel = createPanel(gui)

	for _, itemId in sortedItemIds() do
		local item = Items[itemId]
		local row = Widgets.label("", panel)
		row.Name = itemId
		row.LayoutOrder = item.order
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.TextXAlignment = Enum.TextXAlignment.Left
		-- Color según la rareza (Fase 4).
		row.TextColor3 = Rarities[item.rarity or "Common"].color

		local shown = Inventory.count(player, itemId)
		local function refresh()
			local count = Inventory.count(player, itemId)
			row.Text = `{item.icon} {item.name}: {count}`
			-- Los materiales básicos se ven siempre; el botín, cuando tienes alguno.
			row.Visible = item.alwaysShow == true or count > 0
			if count ~= shown then
				local change = count - shown
				local sign = if change > 0 then "+" else ""
				addFeedEntry(
					`{sign}{change} {item.icon} {item.name} ({count})`,
					if change > 0 then GAIN_COLOR else SPEND_COLOR
				)
			end
			shown = count
		end
		player:GetAttributeChangedSignal(Inventory.attributeName(itemId)):Connect(refresh)
		refresh()
	end

	ActionButtons.bind(ACTION, "Bolsa", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			panel.Visible = not panel.Visible
		end
		return Enum.ContextActionResult.Sink
	end, Enum.KeyCode.B, Enum.KeyCode.ButtonY)
end

return InventoryHUDController
