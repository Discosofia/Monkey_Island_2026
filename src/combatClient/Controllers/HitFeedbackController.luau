--!strict
-- Confirmación de impacto del tirador (Fase 19, W3; servidor en Combat/HitFeedback). Cuando el servidor dice que
-- tu disparo ha acertado, dibuja un hitmarker de cuatro rayitas en X y suena el golpe en 2D:
--   - blanco: golpe normal; amarillo-naranja y más grande: la cabeza; gris azulado y corto: bloqueado;
--     la muerte es un «pop» blanco que crece hasta Config.HitFeedback.KillScale y se desvanece.
--   - Va en la mira si la hay (la pantalla "Mira" del Laboratorio y de Dunas) y, si no, en el centro.
-- Solo Frames, sin imágenes. Hay un pequeño grupo de marcadores que se reutilizan (nada de crear piezas por
-- aviso). Nunca rojo: el rojo es el daño recibido. Los valores están en Config.HitFeedback.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local NORMAL_COLOR = Color3.fromRGB(255, 255, 255)
local HEAD_COLOR = Color3.fromRGB(255, 190, 50)
local BLOCKED_COLOR = Color3.fromRGB(150, 170, 200)
local OUTLINE_COLOR = Color3.fromRGB(20, 20, 20)
-- El bloqueado es más pequeño y dura menos que el normal.
local BLOCKED_SCALE = 0.75
local BLOCKED_TIME = 0.7
local POOL_SIZE = 3

type Marker = {
	holder: Frame,
	scale: UIScale,
	ticks: { Frame },
	startedAt: number,
	seconds: number,
	baseScale: number,
	endScale: number,
	active: boolean,
}

local HitFeedbackController = {}

-- Dónde está la mira del tirador en pantalla (la pantalla "Mira" del Laboratorio o de Dunas), o nil.
local function crosshairCenter(playerGui: PlayerGui): Vector2?
	local gui = playerGui:FindFirstChild("Mira")
	local root = if gui and gui:IsA("ScreenGui") and gui.Enabled then gui:FindFirstChild("Crosshair") else nil
	-- Con una mira de arma (Shared/UI/Sights) la normal se esconde, pero sigue colocada donde se apunta.
	if root and root:IsA("GuiObject") and (root.Visible or gui:GetAttribute("SightCovers") == true) then
		return root.AbsolutePosition
	end
	return nil
end

function HitFeedbackController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local settings = Config.HitFeedback

	local gui = Widgets.screen("HitFeedback", playerGui)
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20

	-- Cada rayita está a "Gap" del centro por su extremo interior, en diagonal.
	local offset = (settings.Gap + settings.MarkerLength / 2) / math.sqrt(2)
	local pool: { Marker } = {}
	for _ = 1, POOL_SIZE do
		local holder = Instance.new("Frame")
		holder.Name = "Marker"
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new()
		holder.Visible = false
		holder.Parent = gui
		local scale = Instance.new("UIScale")
		scale.Parent = holder
		local ticks = {}
		for index = 1, 4 do
			local dx = if index % 2 == 0 then 1 else -1
			local dy = if index > 2 then 1 else -1
			local tick = Instance.new("Frame")
			tick.AnchorPoint = Vector2.new(0.5, 0.5)
			tick.Size = UDim2.fromOffset(settings.MarkerLength, settings.Width)
			tick.Position = UDim2.fromOffset(dx * offset, dy * offset)
			tick.Rotation = if dx * dy > 0 then 45 else -45
			tick.BorderSizePixel = 0
			tick.Parent = holder
			local stroke = Instance.new("UIStroke")
			stroke.Color = OUTLINE_COLOR
			stroke.Transparency = 0.3
			stroke.Parent = tick
			table.insert(ticks, tick)
		end
		table.insert(pool, {
			holder = holder,
			scale = scale,
			ticks = ticks,
			startedAt = 0,
			seconds = 1,
			baseScale = 1,
			endScale = 1,
			active = false,
		})
	end

	-- Anima los marcadores activos; solo está conectado mientras haya alguno.
	local connection: RBXScriptConnection? = nil
	local function step()
		local now = os.clock()
		local any = false
		for _, marker in pool do
			if marker.active then
				local t = (now - marker.startedAt) / marker.seconds
				if t >= 1 then
					marker.active = false
					marker.holder.Visible = false
				else
					any = true
					marker.scale.Scale = marker.baseScale + (marker.endScale - marker.baseScale) * t
					-- Se queda opaca un rato y se apaga al final.
					local transparency = t * t
					for _, tick in marker.ticks do
						tick.BackgroundTransparency = transparency
					end
				end
			end
		end
		if not any and connection then
			connection:Disconnect()
			connection = nil
		end
	end

	-- El marcador libre o, si todos están en uso, el que lleva más tiempo.
	local function acquire(): Marker
		local oldest = pool[1]
		for _, marker in pool do
			if not marker.active then
				return marker
			end
			if marker.startedAt < oldest.startedAt then
				oldest = marker
			end
		end
		return oldest
	end

	Remotes.HitFeedback.OnClientEvent:Connect(function(kind: any, _position: any, _weaponId: any)
		if typeof(kind) ~= "string" then
			return
		end
		local isKill = kind == "Kill"
		local isHead = kind == "Head" or kind == "Weak"
		local isBlocked = kind == "Blocked"

		local marker = acquire()
		local color = if isHead then HEAD_COLOR elseif isBlocked then BLOCKED_COLOR else NORMAL_COLOR
		for _, tick in marker.ticks do
			tick.BackgroundColor3 = color
			tick.BackgroundTransparency = 0
		end
		marker.baseScale = if isHead then settings.HeadScale elseif isBlocked then BLOCKED_SCALE else 1
		marker.endScale = marker.baseScale
		marker.seconds = settings.Seconds
		if isKill then
			marker.endScale = settings.KillScale
			marker.seconds = settings.KillSeconds
		elseif isBlocked then
			marker.seconds = settings.Seconds * BLOCKED_TIME
		end
		marker.scale.Scale = marker.baseScale
		marker.startedAt = os.clock()
		marker.active = true

		local center = crosshairCenter(playerGui) or gui.AbsoluteSize / 2
		marker.holder.Position = UDim2.fromOffset(center.X, center.Y)
		marker.holder.Visible = true
		if not connection then
			connection = RunService.RenderStepped:Connect(step)
		end

		if isKill then
			Sfx.playLocal("HitKill", settings.Volume.Kill)
		elseif isHead then
			Sfx.playLocal("HitHead", settings.Volume.Head)
		else
			Sfx.playLocal("HitBody", if isBlocked then settings.Volume.Body * 0.5 else settings.Volume.Body)
		end
	end)
end

return HitFeedbackController
