--!strict
-- Indicador de la cadena (Fase 10, C12): cuatro rombos pequeños a los pies del personaje (su sitio en la
-- pantalla se calcula en cada fotograma, así no choca con nada fijo del HUD en ningún dispositivo y está
-- donde se mira al pegar), mientras encadenas golpes cuerpo a cuerpo (Shared/MeleeChain) o
-- disparos de un arma con remate (Shared/RangedChain). Cada golpe dado llena uno; el cuarto, más grande y
-- dorado, es el remate, y late cuando el siguiente lo es. Cuando se pasa la ventana (o tras el remate) se
-- apaga. Lo que enseña es la predicción del cliente (WeaponController.progress), la misma que decide el
-- tajo y el destello del remate; el servidor lleva la suya con los mismos tiempos.
-- Va sobre la partida, así que es breve y no recoge toques (Active = false). Lo mismo en los tres places.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WeaponController = require(script.Parent.WeaponController)

local PIP = 14
local FINISHER_PIP = 20
local GAP = 8
local PADDING = 6
-- Studs bajo la raíz del personaje (los pies quedan a ~3).
local FEET = 3.4
local MARGIN = 12 -- px al borde de la pantalla como mucho
local BACK_COLOR = Color3.fromRGB(20, 20, 20)
local EMPTY_COLOR = Color3.fromRGB(20, 20, 20)
local DONE_COLOR = Color3.fromRGB(255, 240, 200)
local FINISHER_COLOR = Color3.fromRGB(255, 205, 60)
-- Cuánto tarda en apagarse al acabar (s).
local FADE_SECONDS = 0.25

local ChainPipsController = {}

type Pip = { frame: Frame, stroke: UIStroke }

local function makePip(parent: Instance, order: number, size: number): Pip
	-- Un cuadrado girado 45° dentro de una celda de su lado, para que la fila no cambie de ancho.
	local cell = Instance.new("Frame")
	cell.Name = `Pip{order}`
	cell.LayoutOrder = order
	cell.BackgroundTransparency = 1
	cell.Size = UDim2.fromOffset(size, size)
	cell.Parent = parent
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.72, 0.72)
	frame.Rotation = 45
	frame.BackgroundColor3 = EMPTY_COLOR
	frame.BorderSizePixel = 0
	frame.Parent = cell
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 1.5
	stroke.Parent = frame
	return { frame = frame, stroke = stroke }
end

function ChainPipsController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChainPips"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local width = 3 * PIP + FINISHER_PIP + 3 * GAP + 2 * PADDING
	local height = FINISHER_PIP + PADDING
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Active = false
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Size = UDim2.fromOffset(width, height)
	-- Una píldora oscura detrás, para que se lean sobre la arena y la hierba.
	row.BackgroundColor3 = BACK_COLOR
	row.BackgroundTransparency = 0.55
	row.Visible = false
	row.Parent = gui
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0.5, 0)
	rowCorner.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local pips: { Pip } = {}
	local built = 0
	local function build(length: number)
		if built == length then
			return
		end
		for _, pip in pips do
			(pip.frame.Parent :: Instance):Destroy()
		end
		table.clear(pips)
		for index = 1, length do
			table.insert(pips, makePip(row, index, if index == length then FINISHER_PIP else PIP))
		end
		built = length
	end

	local fadeFrom = -math.huge
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local progress = WeaponController.progress()
		local alive = progress ~= nil and now <= progress.untilTime
		if not alive then
			-- Se apaga poco a poco al acabar la ventana o tras el remate.
			if row.Visible and fadeFrom == -math.huge then
				fadeFrom = now
			end
			local alpha = (now - fadeFrom) / FADE_SECONDS
			if alpha >= 1 then
				row.Visible = false
				fadeFrom = -math.huge
				return
			end
			row.BackgroundTransparency = 0.55 + 0.45 * alpha
			for _, pip in pips do
				pip.frame.BackgroundTransparency = 0.3 + 0.7 * alpha
				pip.stroke.Transparency = alpha
			end
			return
		end
		local current = progress :: WeaponController.Progress
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local camera = Workspace.CurrentCamera
		if not (root and root:IsA("BasePart") and camera) then
			row.Visible = false
			return
		end
		-- A los pies; si quedan fuera (cámara muy cerca), pegado al borde de abajo.
		local point = camera:WorldToViewportPoint(root.Position - Vector3.new(0, FEET, 0))
		local size = camera.ViewportSize
		row.Position = UDim2.fromOffset(
			math.clamp(point.X, width / 2 + MARGIN, size.X - width / 2 - MARGIN),
			math.clamp(point.Y, MARGIN, size.Y - height - MARGIN)
		)
		fadeFrom = -math.huge
		build(current.length)
		row.BackgroundTransparency = 0.55
		row.Visible = true
		local nextIsFinisher = current.step == current.length - 1
		local pulse = 0.5 + 0.5 * math.sin(now * 14)
		for index, pip in pips do
			local finisher = index == current.length
			local done = index <= current.step
			pip.frame.BackgroundColor3 = if done
				then (if finisher then FINISHER_COLOR else DONE_COLOR)
				elseif finisher and nextIsFinisher then EMPTY_COLOR:Lerp(FINISHER_COLOR, 0.35 * pulse)
				else EMPTY_COLOR
			pip.frame.BackgroundTransparency = if done then 0 else 0.3
			pip.stroke.Color = if finisher then FINISHER_COLOR else Color3.new(1, 1, 1)
			pip.stroke.Transparency = if done or (finisher and nextIsFinisher) then 0 else 0.35
		end
	end)
end

return ChainPipsController
