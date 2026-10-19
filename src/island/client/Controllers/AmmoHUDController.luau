--!strict
-- Contador de munición: abajo en el centro, encima de la barra de objetos de Roblox. Solo se ve con un
-- arma a distancia que gasta munición en la mano ("ammoItemId" en Data/Weapons: arco → flechas,
-- honda → piedras): el icono del ítem y cuántos quedan, en rojo si no queda ninguno.
-- Si el rol rellena esa munición solo (el carcaj del cazador, "refill" en Data/Roles), una barrita
-- debajo enseña cuánto falta para la siguiente. El servidor publica cuándo llega en el atributo
-- "RefillAt" (hora del servidor, RoleService); sin él, el carcaj está lleno y la barrita no se ve.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Roles = require(ReplicatedStorage.Shared.Data.Roles)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

-- Encima de la barra de objetos de Roblox (unos 68 px de alto en PC y 56 en un teléfono). Con 92 px
-- de ancho cabe en un teléfono entre el joystick y los botones de acción.
local BOTTOM_GAP = 76
local PANEL_SIZE = Vector2.new(92, 40)
local TEXT_COLOR = Color3.new(1, 1, 1)
local EMPTY_COLOR = Color3.fromRGB(235, 70, 60)
local BAR_COLOR = Color3.fromRGB(230, 220, 200)

local AmmoHUDController = {}

function AmmoHUDController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("AmmoHUD", player:WaitForChild("PlayerGui"))

	local panel = Instance.new("Frame")
	panel.Name = "Ammo"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -BOTTOM_GAP)
	panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	panel.BackgroundTransparency = 0.3
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local label = Widgets.label("", panel)
	label.Name = "Count"
	label.Position = UDim2.fromOffset(6, 3)
	label.Size = UDim2.new(1, -12, 0, 28)
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 24
	textLimit.Parent = label

	local back = Instance.new("Frame")
	back.Name = "Refill"
	back.Position = UDim2.new(0, 10, 1, -8)
	back.Size = UDim2.new(1, -20, 0, 4)
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.5
	back.BorderSizePixel = 0
	back.Visible = false
	back.Parent = panel
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = BAR_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = back

	-- Ítem de munición del arma de la mano (nil si no gasta munición o no hay arma).
	local ammoId: string? = nil
	local countConnection: RBXScriptConnection? = nil

	local function refreshCount()
		local itemId = ammoId
		if not itemId then
			return
		end
		local count = Inventory.count(player, itemId)
		label.Text = `{Items[itemId].icon} {count}`
		label.TextColor3 = if count > 0 then TEXT_COLOR else EMPTY_COLOR
	end

	local function setAmmo(itemId: string?)
		if itemId == ammoId then
			return
		end
		if countConnection then
			countConnection:Disconnect()
			countConnection = nil
		end
		ammoId = itemId
		panel.Visible = itemId ~= nil
		if itemId then
			countConnection = player:GetAttributeChangedSignal(Inventory.attributeName(itemId)):Connect(refreshCount)
			refreshCount()
		end
	end

	local function onToolChanged()
		local character = player.Character
		local tool = if character then character:FindFirstChildOfClass("Tool") else nil
		local weaponId = if tool then tool:GetAttribute("WeaponId") else nil
		local weapon = if typeof(weaponId) == "string" then Weapons[weaponId] else nil
		setAmmo(if weapon then weapon.ammoItemId else nil)
	end

	local function onCharacter(character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				onToolChanged()
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				onToolChanged()
			end
		end)
		onToolChanged()
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	-- La barrita del carcaj avanza cada fotograma mientras se ve.
	RunService.RenderStepped:Connect(function()
		local roleId = player:GetAttribute("Role")
		local role = if typeof(roleId) == "string" then Roles[roleId] else nil
		local refill = if role and panel.Visible then role.refill else nil
		local refillAt = player:GetAttribute("RefillAt")
		if refill and refill.itemId == ammoId and typeof(refillAt) == "number" then
			local left = refillAt - Workspace:GetServerTimeNow()
			fill.Size = UDim2.fromScale(math.clamp(1 - left / refill.seconds, 0, 1), 1)
			if not back.Visible then
				back.Visible = true
			end
		elseif back.Visible then
			back.Visible = false
		end
	end)
end

return AmmoHUDController
