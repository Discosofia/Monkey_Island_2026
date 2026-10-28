--!strict
-- Mira configurable (Fase 15, V6) para las arenas con disparo (Laboratorio y Dunas). Se dibuja con piezas de
-- interfaz, sin imágenes, según los ajustes del jugador (Shared/Settings: crosshairStyle, crosshairColor,
-- crosshairSize, crosshairThickness y crosshairDynamic) y se repinta sola cuando cambian.
--   Crosshair.mount(parent) crea un Frame "Crosshair" de tamaño 0 anclado al centro de "parent" y devuelve:
--     root          el Frame (se puede mover: Dunas lo coloca sobre el ratón).
--     setSpread(px) separación extra de los brazos, en píxeles (la dispersión real del arma; solo con la mira
--                   dinámica). 0 es el reposo. Se suaviza sola.
--     setCooldown(f) anillo de recarga alrededor de la mira, de 0 a 1 (visible solo entre los dos).
--     setVisible(v), destroy().
-- Colores: nunca verde (curación) ni morado (veneno), para no confundirse con los números de combate.

local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.Settings)

export type Handle = {
	root: Frame,
	setSpread: (px: number) -> (),
	setCooldown: (fraction: number) -> (),
	setVisible: (visible: boolean) -> (),
	destroy: () -> (),
}

local COLORS: { [string]: Color3 } = {
	White = Color3.fromRGB(255, 255, 255),
	Yellow = Color3.fromRGB(255, 230, 80),
	Cyan = Color3.fromRGB(90, 230, 255),
	Magenta = Color3.fromRGB(255, 90, 220),
	LightRed = Color3.fromRGB(255, 120, 110),
}
local SIZE_SCALE: { [string]: number } = { Small = 0.75, Normal = 1, Large = 1.4 }
local THICKNESS: { [string]: number } = { Thin = 1, Normal = 2, Thick = 3 }
local OUTLINE_COLOR = Color3.fromRGB(20, 20, 20)
local OUTLINE_TRANSPARENCY = 0.3
-- Medidas base, en píxeles, con tamaño Normal: largo del brazo, distancia de su centro al de la mira y
-- diámetro del anillo.
local ARM_LENGTH = 9
local ARM_GAP = 11
local RING_DIAMETER = 22
-- Anillo de recarga: puntos repartidos en círculo, a esta distancia extra del extremo de la mira.
local COOLDOWN_DOTS = 36
local COOLDOWN_MARGIN = 9
local COOLDOWN_TRANSPARENCY = 0.35
-- Velocidad con que la separación sigue a la dispersión (por segundo).
local SPREAD_SPEED = 16

local Crosshair = {}

local function outline(target: GuiObject, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE_COLOR
	stroke.Transparency = OUTLINE_TRANSPARENCY
	stroke.Thickness = thickness or 1
	stroke.Parent = target
end

local function piece(parent: Instance, size: Vector2, color: Color3, round: boolean): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	end
	outline(frame)
	frame.Parent = parent
	return frame
end

type Arm = { frame: Frame, dx: number, dy: number, gap: number }

function Crosshair.mount(parent: GuiObject): Handle
	local root = Instance.new("Frame")
	root.Name = "Crosshair"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.new()
	root.Active = false
	root.Parent = parent

	local content = Instance.new("Folder")
	content.Name = "Content"
	content.Parent = root

	local arms: { Arm } = {}
	local ring: Frame? = nil
	local ringBase = 0
	local cooldownDots: { Frame } = {}
	local spreadTarget = 0
	local spreadNow = 0
	local cooldown = 0

	local function placeArms()
		for _, arm in arms do
			local distance = arm.gap + spreadNow
			arm.frame.Position = UDim2.fromOffset(arm.dx * distance, arm.dy * distance)
		end
		if ring then
			local diameter = ringBase + 2 * spreadNow
			ring.Size = UDim2.fromOffset(diameter, diameter)
		end
	end

	local function paintCooldown()
		local visible = cooldown > 0 and cooldown < 1
		for index, dot in cooldownDots do
			dot.Visible = visible and (index - 0.5) / COOLDOWN_DOTS <= cooldown
		end
	end

	local function redraw()
		content:ClearAllChildren()
		table.clear(arms)
		table.clear(cooldownDots)
		ring = nil
		local values = Settings.get()
		local color = COLORS[values.crosshairColor] or COLORS.White
		local scale = SIZE_SCALE[values.crosshairSize] or 1
		local width = THICKNESS[values.crosshairThickness] or 2
		local length = math.max(3, math.round(ARM_LENGTH * scale))
		local gap = ARM_GAP * scale
		local style = values.crosshairStyle
		-- Punto pequeño del centro y punto grande (el único de "Punto" y el de "Cruz y punto").
		local small = width + 1
		local big = math.max(4, math.round((width + 2) * scale))

		local function addArm(dx: number, dy: number, armGap: number)
			local horizontal = dx ~= 0
			local size = if horizontal then Vector2.new(length, width) else Vector2.new(width, length)
			table.insert(arms, { frame = piece(content, size, color, false), dx = dx, dy = dy, gap = armGap })
		end

		local reach = gap + length / 2
		if style == "Cross" or style == "T" or style == "CrossDot" then
			-- La "Cruz y punto" separa más los brazos para que el punto grande respire.
			local armGap = if style == "CrossDot" then gap * 1.35 else gap
			addArm(-1, 0, armGap)
			addArm(1, 0, armGap)
			addArm(0, 1, armGap)
			if style ~= "T" then
				addArm(0, -1, armGap)
			end
			reach = armGap + length / 2
			if style == "CrossDot" then
				piece(content, Vector2.new(big, big), color, true)
			else
				piece(content, Vector2.new(small, small), color, false)
			end
		elseif style == "Dot" then
			piece(content, Vector2.new(big, big), color, true)
			reach = big / 2
		else
			-- "Circle": un anillo con borde oscuro debajo y un punto en el centro.
			ringBase = math.round(RING_DIAMETER * scale)
			local shadow = Instance.new("Frame")
			shadow.Name = "Ring"
			shadow.AnchorPoint = Vector2.new(0.5, 0.5)
			shadow.BackgroundTransparency = 1
			shadow.Parent = content
			outline(shadow, width + 2)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = shadow
			local stroke = Instance.new("UIStroke")
			stroke.Color = color
			stroke.Thickness = width
			stroke.Parent = shadow
			ring = shadow
			piece(content, Vector2.new(small, small), color, true)
			reach = ringBase / 2 + width
		end

		-- Anillo de recarga: puntos desde las 12 en punto, en el sentido del reloj.
		local radius = reach + COOLDOWN_MARGIN
		local dotSize = width + 2
		for index = 1, COOLDOWN_DOTS do
			local angle = (index - 0.5) / COOLDOWN_DOTS * 2 * math.pi
			local dot = piece(content, Vector2.new(dotSize, dotSize), color, true)
			dot.Name = "Cooldown"
			dot.BackgroundTransparency = COOLDOWN_TRANSPARENCY
			dot.Position = UDim2.fromOffset(math.sin(angle) * radius, -math.cos(angle) * radius)
			table.insert(cooldownDots, dot)
		end
		placeArms()
		paintCooldown()
	end

	-- La separación a la que tiende: la dispersión pedida, o 0 si la mira dinámica está apagada.
	local rawSpread = 0
	local function retarget()
		spreadTarget = if Settings.get().crosshairDynamic then rawSpread else 0
	end
	redraw()
	local settingsConnection = Settings.onChanged(function()
		redraw()
		retarget()
	end)
	local stepConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if math.abs(spreadTarget - spreadNow) < 0.05 then
			if spreadNow ~= spreadTarget then
				spreadNow = spreadTarget
				placeArms()
			end
			return
		end
		spreadNow += (spreadTarget - spreadNow) * math.min(1, deltaTime * SPREAD_SPEED)
		placeArms()
	end)

	local handle = {} :: Handle
	handle.root = root
	handle.setSpread = function(px: number)
		rawSpread = math.max(0, px)
		retarget()
	end
	handle.setCooldown = function(fraction: number)
		local clamped = math.clamp(fraction, 0, 1)
		if clamped ~= cooldown then
			cooldown = clamped
			paintCooldown()
		end
	end
	handle.setVisible = function(visible: boolean)
		root.Visible = visible
	end
	handle.destroy = function()
		settingsConnection:Disconnect()
		stepConnection:Disconnect()
		root:Destroy()
	end
	root.Destroying:Connect(function()
		settingsConnection:Disconnect()
		stepConnection:Disconnect()
	end)
	return handle
end

return Crosshair
