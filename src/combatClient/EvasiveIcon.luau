--!strict
-- Icono del Evasivo (Fase 10, C7; Combat/Evasive) en la fila de la estamina, a la derecha de la guardia
-- (CombatClient/GuardBar) o, si no se ve, de la estamina. Solo aparece cuando importa:
--   - en recarga, con una cortina oscura que baja según pasa el tiempo ("EvasiveReadyAt");
--   - atrapado (aturdido, guardia rota, inmovilizado o lanzado) y listo, latiendo con el borde azul y la
--     tecla, para que se sepa que se puede salir.
-- Al acabar la recarga da un destello y se va.
--   local update = EvasiveIcon.attach(filaDeLaEstamina, anchoDeLaEstamina + 30)
--   update() -- en cada fotograma

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatState = require(ReplicatedStorage.Shared.CombatState)
local Config = require(ReplicatedStorage.Shared.Config)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local SIZE = 24
local GAP = 6
local READY_COLOR = Color3.fromRGB(150, 210, 255)
-- Lo que dura el destello al quedar listo (s).
local READY_FLASH_SECONDS = 0.6

local EvasiveIcon = {}

-- Tecla que se enseña según el último dispositivo usado.
local function keyHint(): string
	local input = UserInputService:GetLastInputType()
	if input == Enum.UserInputType.Touch then
		return ""
	elseif input.Name:find("Gamepad") then
		return "B"
	end
	return "Q"
end

-- Pone el icono en "row" a partir de "left" (px) y devuelve la función que lo actualiza.
function EvasiveIcon.attach(row: Frame, left: number): () -> ()
	local player = Players.LocalPlayer
	local holder = Instance.new("Frame")
	holder.Name = "Evasive"
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, left + GAP, 0.5, 0)
	holder.Size = UDim2.fromOffset(SIZE, SIZE)
	holder.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	holder.BackgroundTransparency = 0.35
	holder.ClipsDescendants = true
	holder.Visible = false
	holder.Parent = row
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Color = READY_COLOR
	stroke.Thickness = 2
	stroke.Parent = holder

	local icon = Widgets.label("💨", holder)
	icon.Size = UDim2.fromScale(1, 1)

	-- Cortina de la recarga: cubre lo que falta, de arriba abajo.
	local shade = Instance.new("Frame")
	shade.Name = "Cooldown"
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.35
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 0)
	shade.Parent = holder

	local key = Widgets.label("", holder)
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(1, 1)
	key.Position = UDim2.new(1, 2, 1, 2)
	key.Size = UDim2.fromOffset(12, 12)
	key.TextStrokeTransparency = 0.2

	local wasCooling = false
	local readyFlashUntil = -math.huge

	return function()
		local wait = CombatState.evasiveWait(player)
		local trapped = CombatState.isTrapped(player)
		local clock = os.clock()
		if wasCooling and wait <= 0 then
			readyFlashUntil = clock + READY_FLASH_SECONDS
		end
		wasCooling = wait > 0
		local flashing = clock < readyFlashUntil
		holder.Visible = wait > 0 or trapped or flashing
		if not holder.Visible then
			return
		end
		-- Detrás de la guardia si se ve; si no, junto a la estamina.
		local guard = row:FindFirstChild("Guard")
		local offset = if guard
				and guard:IsA("GuiObject")
				and guard.Visible
			then guard.Position.X.Offset + guard.Size.X.Offset
			else left
		holder.Position = UDim2.new(0, offset + GAP, 0.5, 0)
		shade.Size = UDim2.fromScale(1, math.clamp(wait / Config.Evasive.CooldownSeconds, 0, 1))
		local ready = wait <= 0
		-- Atrapado y listo: late (borde y tamaño) para que se vea que se puede salir.
		local pulse = if ready and (trapped or flashing) then 0.5 + 0.5 * math.sin(clock * 12) else 0
		stroke.Transparency = if ready then 0.6 - 0.6 * pulse else 1
		icon.TextTransparency = if ready then 0 else 0.4
		key.Text = if ready and trapped then keyHint() else ""
		holder.Size = UDim2.fromOffset(SIZE + math.round(4 * pulse), SIZE + math.round(4 * pulse))
	end
end

return EvasiveIcon
