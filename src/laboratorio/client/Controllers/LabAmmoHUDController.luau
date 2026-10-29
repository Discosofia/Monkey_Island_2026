--!strict
-- Cargador del Laboratorio en pantalla (Fase 15, V8; estado en CombatClient/LabShooting, servidor en
-- LabAmmoService). Solo mientras se lleva en la mano un arma con cargador y se está vivo:
--   - Contador de balas "24 / 24", solo texto, con el estilo del HUD del Laboratorio (panel de madera oscura,
--     BuilderSansBold). Se pone en rojo claro con el 25 % del cargador o menos (Config.Lab.LowAmmoFraction).
--     En PC va abajo a la derecha, encima del 😀 de los emotes; en táctil, bajo el 😀 (arriba a la derecha),
--     porque abajo a la derecha están el salto y los botones de acción.
--   - Barra fina de recarga bajo la mira, con los segundos que faltan, solo mientras se recarga.
--   - La mira dinámica: cada fotograma le pone la dispersión del arma (LabShooting.spreadPixels) y el anillo
--     de espera entre disparos (solo en armas con cadencia de Config.Lab.CooldownRingMinSeconds o más).
--   - La acción "Reload": tecla R, botón X del mando y botón táctil "Recargar". Solo existe con un arma con
--     cargador en la mano (este place no carga RoleController, así que R está libre).
-- Se esconde con una ventana abierta (el ratón suelto por una ventana, como la mira) y estando muerto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local WeaponController = require(ReplicatedStorage.CombatClient.Controllers.WeaponController)
local ActionButtons = require(ReplicatedStorage.CombatClient.ActionButtons)
local LabShooting = require(ReplicatedStorage.CombatClient.LabShooting)
local FirstPersonController = require(script.Parent.FirstPersonController)

local T = Strings.t

local RELOAD_ACTION = "Reload"
local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local TEXT_COLOR = Color3.new(1, 1, 1)
-- Rojo claro de la mira (Shared/UI/Crosshair): el cargador casi vacío.
local LOW_COLOR = Color3.fromRGB(255, 120, 110)
local BAR_BACK_COLOR = Color3.fromRGB(20, 20, 20)
local BAR_FILL_COLOR = Color3.fromRGB(235, 235, 235)
local COUNTER_SIZE = Vector2.new(92, 40)
-- Hueco entre el contador y el botón 😀 de los emotes, y borde de la pantalla.
local GAP = 8
local MARGIN = 12
-- Alto del botón 😀 (EmoteWheel.button) si aún no se ha colocado.
local EMOTE_SIZE = 52
local BAR_SIZE = Vector2.new(150, 8)
-- Cuánto baja la barra de recarga desde el centro de la pantalla (bajo la mira).
local BAR_DROP = 44

local LabAmmoHUDController = {}

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function isDead(character: Model?): boolean
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid == nil or humanoid.Health <= 0
end

function LabAmmoHUDController:Start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Widgets.screen("LabAmmoHUD", playerGui)
	-- La barra de recarga va en una pantalla sin la franja de la barra de Roblox: el centro de la mira.
	local barGui = Widgets.screen("LabReloadBar", playerGui)
	barGui.IgnoreGuiInset = true
	barGui.DisplayOrder = 5

	-- Contador de balas.
	local counter = Instance.new("Frame")
	counter.Name = "Counter"
	counter.Size = UDim2.fromOffset(COUNTER_SIZE.X, COUNTER_SIZE.Y)
	counter.BackgroundColor3 = PANEL_COLOR
	counter.BackgroundTransparency = 0.25
	counter.Visible = false
	counter.Parent = gui
	corner(counter, 12)
	local counterText = Widgets.label("", counter)
	counterText.Size = UDim2.fromScale(1, 1)
	counterText.TextStrokeTransparency = 0.3
	local counterPadding = Instance.new("UIPadding")
	counterPadding.PaddingTop = UDim.new(0, 6)
	counterPadding.PaddingBottom = UDim.new(0, 6)
	counterPadding.Parent = counterText

	-- Barra de recarga.
	local bar = Instance.new("Frame")
	bar.Name = "ReloadBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0.5, BAR_DROP)
	bar.Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y + 22)
	bar.BackgroundTransparency = 1
	bar.Visible = false
	bar.Parent = barGui
	local back = Instance.new("Frame")
	back.Size = UDim2.fromOffset(BAR_SIZE.X, BAR_SIZE.Y)
	back.BackgroundColor3 = BAR_BACK_COLOR
	back.BackgroundTransparency = 0.35
	back.Parent = bar
	corner(back, 4)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = BAR_FILL_COLOR
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = back
	corner(fill, 4)
	local reloadText = Widgets.label("", bar)
	reloadText.Position = UDim2.fromOffset(0, BAR_SIZE.Y + 2)
	reloadText.Size = UDim2.fromOffset(BAR_SIZE.X, 18)
	reloadText.TextStrokeTransparency = 0.3

	-- Dónde va el contador: sigue al botón 😀 de los emotes (LabHUDController), que cambia de sitio según el dispositivo.
	local hud = playerGui:WaitForChild("LabHUD")
	local emote = hud:WaitForChild("EmoteButton") :: GuiObject
	local function placeCounter()
		local emoteHeight = if emote.Size.Y.Offset > 0 then emote.Size.Y.Offset else EMOTE_SIZE
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			-- Táctil: bajo el 😀 (arriba a la derecha), fuera del salto y los botones de acción.
			counter.AnchorPoint = Vector2.new(1, 0)
			counter.Position = UDim2.new(1, -MARGIN, 0, emote.Position.Y.Offset + emoteHeight + GAP)
		else
			-- PC: encima del 😀 (abajo a la derecha).
			counter.AnchorPoint = Vector2.new(1, 1)
			counter.Position = UDim2.new(1, -MARGIN, 1, -(MARGIN + emoteHeight + GAP))
		end
	end
	placeCounter()
	emote:GetPropertyChangedSignal("Position"):Connect(placeCounter)
	UserInputService.LastInputTypeChanged:Connect(placeCounter)

	-- La acción de recargar existe solo con un arma con cargador en la mano.
	local reloadBound = false
	local function bindReload(on: boolean)
		if on == reloadBound then
			return
		end
		reloadBound = on
		if on then
			ActionButtons.bind(RELOAD_ACTION, T("Recargar"), function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin and not FirstPersonController.needsCursor() then
					LabShooting.reload()
				end
				return Enum.ContextActionResult.Pass
			end, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
		else
			ActionButtons.unbind(RELOAD_ACTION)
		end
	end

	-- Cuándo salió el último disparo (os.clock), para el anillo de espera de la mira.
	local lastShotAt = -math.huge
	WeaponController.onShot(function()
		lastShotAt = os.clock()
	end)

	RunService.RenderStepped:Connect(function()
		local weapon = LabShooting.weapon()
		local active = weapon ~= nil and weapon.lab ~= nil and not isDead(player.Character)
		bindReload(active)
		local covered = FirstPersonController.needsCursor()
		local handle = FirstPersonController.crosshair()
		if not (active and weapon and weapon.lab) then
			counter.Visible = false
			bar.Visible = false
			if handle then
				handle.setSpread(0)
				handle.setCooldown(0)
			end
			return
		end

		-- Contador.
		local magazine = LabShooting.magazine()
		local ammo = LabShooting.ammo()
		counter.Visible = not covered
		counterText.Text = `{ammo} / {magazine}`
		counterText.TextColor3 = if ammo <= magazine * Config.Lab.LowAmmoFraction then LOW_COLOR else TEXT_COLOR

		-- Barra de recarga.
		local finish = LabShooting.reloadingUntil()
		if finish then
			local left = math.max(0, finish - Workspace:GetServerTimeNow())
			local fraction = 1 - math.clamp(left / math.max(weapon.lab.reloadSeconds, 0.01), 0, 1)
			fill.Size = UDim2.fromScale(fraction, 1)
			reloadText.Text = T("Recargando… {seconds}", { seconds = string.format("%.1f", left) })
		end
		bar.Visible = finish ~= nil and not FirstPersonController.isCursorFree()

		-- Mira dinámica.
		if handle then
			handle.setSpread(LabShooting.spreadPixels(WeaponController.isZoomed()))
			local ring = 0
			if weapon.cooldownSeconds >= Config.Lab.CooldownRingMinSeconds then
				ring = math.clamp((os.clock() - lastShotAt) / weapon.cooldownSeconds, 0, 1)
			end
			handle.setCooldown(ring)
		end
	end)
end

return LabAmmoHUDController
