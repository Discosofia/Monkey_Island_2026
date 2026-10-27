--!strict
-- Franja de los eventos en vivo (T4b), en los tres places y para todos los jugadores: una pastilla por
-- evento (Shared/LiveEvents) centrada en la franja de la barra de Roblox (GuiService.TopbarInset, como
-- el marcador de Dunas), con su icono, su nombre y lo que le queda ("💰 Doble Ámbar · 12:34"), o lo
-- que falta para que empiece si está programado ("⏳ 🎉 Fiesta en 4:59"). Tocarla explica el evento.
-- Con dos o más eventos, o en una pantalla baja (teléfono), solo el icono y el tiempo.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(script.Parent.Parent.Data.LiveEvents)
local LiveEvents = require(script.Parent.Parent.LiveEvents)
local Toast = require(script.Parent.Toast)
local Widgets = require(script.Parent.Widgets)

local WOOD = Color3.fromRGB(25, 20, 15)
local GOLD = Color3.fromRGB(242, 178, 36)
local NEXT = Color3.fromRGB(120, 230, 255) -- cian: "lo siguiente"
local CHIP_HEIGHT = 36
local COMPACT_HEIGHT = 500

local LiveEventsBand = {}

function LiveEventsBand.start()
	local gui = Widgets.screen("LiveEvents", Players.LocalPlayer:WaitForChild("PlayerGui"))
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Size = UDim2.fromOffset(0, CHIP_HEIGHT)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.BackgroundTransparency = 1
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	-- En el centro de la franja de la barra de Roblox (llega tarde en el teléfono: se escucha).
	local function place()
		local inset = GuiService.TopbarInset
		row.Position = UDim2.new(0.5, 0, 0, math.max(inset.Height, CHIP_HEIGHT) / 2)
	end
	place()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)

	local chips: { [string]: TextButton } = {}

	local function chip(event: LiveEvents.Event): TextButton
		local info = Catalog[event.kind]
		local button = Instance.new("TextButton")
		button.Name = event.kind
		button.AutomaticSize = Enum.AutomaticSize.X
		button.Size = UDim2.fromOffset(0, CHIP_HEIGHT)
		button.BackgroundColor3 = WOOD
		button.BackgroundTransparency = 0.15
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.BuilderSansBold
		button.TextSize = 17
		button.AutoButtonColor = true
		button.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 1.5
		stroke.Parent = button
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 12)
		padding.PaddingRight = UDim.new(0, 12)
		padding.Parent = button
		button.MouseButton1Click:Connect(function()
			local text = `{info.icon} {info.name}: {info.detail}`
			if info.place == "Lobby" then
				text ..= " (en el Lobby)"
			end
			Toast.show(text)
		end)
		return button
	end

	local function refresh()
		local now = LiveEvents.now()
		local events = {}
		for _, event in LiveEvents.list() do
			if event.endsAt > now then
				table.insert(events, event)
			end
		end
		-- Con dos o más, o en un teléfono, solo icono y tiempo: si no, en el Lobby pisa la pastilla del Ámbar.
		local small = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.Y < COMPACT_HEIGHT
		local compact = small or #events >= 2
		local alive: { [string]: boolean } = {}
		for order, event in events do
			alive[event.id] = true
			local button = chips[event.id] or chip(event)
			chips[event.id] = button
			button.LayoutOrder = order
			local info = Catalog[event.kind]
			local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
			if LiveEvents.isRunning(event, now) then
				local left = LiveEvents.clock(event.endsAt - now)
				button.Text = if compact then `{info.icon} {left}` else `{info.icon} {info.name} · {left}`
				button.TextColor3 = Color3.new(1, 1, 1)
				stroke.Color = GOLD
			else
				local wait = LiveEvents.clock(event.startsAt - now)
				button.Text = if compact then `⏳{info.icon} {wait}` else `⏳ {info.icon} {info.name} en {wait}`
				button.TextColor3 = NEXT
				stroke.Color = NEXT
			end
		end
		for id, button in chips do
			if not alive[id] then
				button:Destroy()
				chips[id] = nil
			end
		end
	end

	ReplicatedStorage:GetAttributeChangedSignal(LiveEvents.ATTRIBUTE):Connect(refresh)
	task.spawn(function()
		while true do
			refresh()
			task.wait(1)
		end
	end)
end

return LiveEventsBand
