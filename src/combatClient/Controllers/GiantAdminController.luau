--!strict
-- Golpes del administrador convertido en gigante (T4e, combat/Services/GiantAdminService):
-- mientras su Player lleva "AdminBoss", tres botones a la derecha de la pantalla (y las teclas I, O y
-- P, libres en todos los places) con su recarga ("GiantReadyAt_<golpe>"). Apuntan hacia donde mira la cámara.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local ATTACKS = {
	{ id = "Stomp", key = Enum.KeyCode.I, icon = "🦶", name = "Pisotón" },
	{ id = "Wave", key = Enum.KeyCode.O, icon = "🌊", name = "Ola" },
	{ id = "Roar", key = Enum.KeyCode.P, icon = "📣", name = "Rugido" },
}
local SIZE = 64
local BACK = Color3.fromRGB(25, 20, 15)
local GOLD = Color3.fromRGB(242, 178, 36)

local GiantAdminController = {}

local function aim(): Vector3
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
end

local function use(attack: string)
	Remotes.GiantAttack:FireServer(attack, aim())
end

local function build(player: Player): (ScreenGui, { [string]: TextLabel })
	local gui = Widgets.screen("GiantHUD", player:WaitForChild("PlayerGui"))
	local column = Instance.new("Frame")
	column.Name = "Attacks"
	column.AnchorPoint = Vector2.new(1, 0.5)
	column.Position = UDim2.fromScale(0.98, 0.55)
	column.Size = UDim2.fromOffset(SIZE, SIZE * 3 + 16)
	column.BackgroundTransparency = 1
	column.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = column
	local waits: { [string]: TextLabel } = {}
	for index, attack in ATTACKS do
		local button = Instance.new("TextButton")
		button.Name = attack.id
		button.LayoutOrder = index
		button.Size = UDim2.fromOffset(SIZE, SIZE)
		button.BackgroundColor3 = BACK
		button.BackgroundTransparency = 0.15
		button.Text = ""
		button.Parent = column
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = GOLD
		stroke.Thickness = 2
		stroke.Parent = button
		local icon = Widgets.label(attack.icon, button)
		icon.Size = UDim2.fromScale(1, 0.62)
		local key = Widgets.label(`{attack.key.Name} · {attack.name}`, button)
		key.Position = UDim2.fromScale(0, 0.62)
		key.Size = UDim2.fromScale(1, 0.32)
		key.TextColor3 = Color3.fromRGB(255, 220, 120)
		-- Lo que falta de recarga, encima del icono.
		local wait = Widgets.label("", button)
		wait.Name = "Wait"
		wait.Size = UDim2.fromScale(1, 1)
		wait.BackgroundColor3 = Color3.new(0, 0, 0)
		wait.BackgroundTransparency = 0.45
		wait.Visible = false
		local waitCorner = Instance.new("UICorner")
		waitCorner.CornerRadius = UDim.new(0, 14)
		waitCorner.Parent = wait
		waits[attack.id] = wait
		local id = attack.id
		button.MouseButton1Click:Connect(function()
			use(id)
		end)
	end
	return gui, waits
end

function GiantAdminController:Start()
	local player = Players.LocalPlayer
	local gui: ScreenGui? = nil
	local function refresh()
		local active = player:GetAttribute("AdminBoss") == true
		if active and not gui then
			local built, waits = build(player)
			gui = built
			for _, attack in ATTACKS do
				local id = attack.id
				ContextActionService:BindAction(`Giant{id}`, function(_, state)
					if state == Enum.UserInputState.Begin then
						use(id)
					end
					return Enum.ContextActionResult.Sink
				end, false, attack.key)
			end
			task.spawn(function()
				while gui == built do
					local now = Workspace:GetServerTimeNow()
					for id, label in waits do
						local readyAt = player:GetAttribute(`GiantReadyAt_{id}`)
						local left = if typeof(readyAt) == "number" then readyAt - now else 0
						label.Visible = left > 0
						label.Text = if left > 0 then tostring(math.ceil(left)) else ""
					end
					task.wait(0.1)
				end
			end)
		elseif not active and gui then
			gui:Destroy()
			gui = nil
			for _, attack in ATTACKS do
				ContextActionService:UnbindAction(`Giant{attack.id}`)
			end
		end
	end
	player:GetAttributeChangedSignal("AdminBoss"):Connect(refresh)
	refresh()
end

return GiantAdminController
