--!strict
-- Espectador de las Rondas del Laboratorio (docs/LABORATORIO.md §3): quien cae en plena ronda queda con
-- "LabOut" y no reaparece hasta la pausa, así que mira la ronda desde un compañero en pie.
--   - La cámara pasa a tercera persona (LocalPlayer.CameraMode = Classic, a Config.Lab.SpectateDistance) y
--     su CameraSubject es el humanoide del compañero. Abajo, en el centro: "Viendo a {name}" y ◀ ▶ para
--     cambiar de compañero (solo si hay más de uno).
--   - Sin compañeros en pie, vista fija desde arriba del centro del mapa (cámara Scriptable).
--   - El ratón va suelto mientras dura (FirstPersonController.freeCursor "Spectate") para poder pulsar ◀ ▶.
-- Al reaparecer (o al acabar la ronda) se restaura la primera persona del place (CameraMode, zoom y cámara).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local LabModes = require(ReplicatedStorage.Shared.LabModes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)
local FirstPersonController = require(script.Parent.FirstPersonController)

local T = Strings.t

local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local BUTTON_SIZE = 48
local BAR_WIDTH = 330
-- Sobre la línea "Ctrl: soltar el ratón" del HUD (abajo en el centro, a 12 px del borde).
local BAR_BOTTOM = 44
-- Vista fija sin compañeros: altura sobre el centro del mapa y cuánto se desplaza hacia atrás.
local OVERHEAD_HEIGHT = 150
local OVERHEAD_BACK = 40

local LabSpectateController = {}

local function isStanding(other: Player): boolean
	if other:GetAttribute("LabOut") == true then
		return false
	end
	local humanoid = if other.Character then other.Character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.Health > 0
end

-- Compañeros en pie, en un orden estable.
local function teammates(player: Player): { Player }
	local teamId = Arena.teamOf(player)
	local list = {}
	if teamId then
		for _, other in Arena.membersOf(teamId) do
			if other ~= player and isStanding(other) then
				table.insert(list, other)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

-- El centro del mapa: la media de sus bases (cero si aún no están).
local function mapCenter(): Vector3
	local map = Workspace:FindFirstChild("LabMap")
	local bases = if map then map:FindFirstChild("Bases") else nil
	local sum, count = Vector3.zero, 0
	if bases then
		for _, base in bases:GetChildren() do
			if base:IsA("Model") then
				sum += base:GetPivot().Position
				count += 1
			end
		end
	end
	return if count > 0 then sum / count else Vector3.zero
end

function LabSpectateController:Start()
	local player = Players.LocalPlayer
	local gui = Widgets.screen("LabSpectate", player:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 8
	gui.Enabled = false

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -BAR_BOTTOM)
	bar.Size = UDim2.fromOffset(BAR_WIDTH, BUTTON_SIZE + 8)
	bar.BackgroundColor3 = PANEL_COLOR
	bar.BackgroundTransparency = 0.25
	bar.Parent = gui
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 14)
	barCorner.Parent = bar
	local previous = Widgets.button("◀", bar)
	previous.Name = "Previous"
	previous.AnchorPoint = Vector2.new(0, 0.5)
	previous.Position = UDim2.new(0, 4, 0.5, 0)
	previous.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	local nextButton = Widgets.button("▶", bar)
	nextButton.Name = "Next"
	nextButton.AnchorPoint = Vector2.new(1, 0.5)
	nextButton.Position = UDim2.new(1, -4, 0.5, 0)
	nextButton.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	local caption = Widgets.label("", bar)
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 0.5)
	caption.Position = UDim2.fromScale(0.5, 0.5)
	caption.Size = UDim2.new(1, -(BUTTON_SIZE + 12) * 2, 1, -12)
	caption.TextStrokeTransparency = 0.3

	local active = false
	local target: Player? = nil
	local overhead = false
	-- Lo que había antes de ser espectador, para devolverlo.
	local savedMode: Enum.CameraMode = player.CameraMode
	local savedMinZoom = player.CameraMinZoomDistance
	local savedMaxZoom = player.CameraMaxZoomDistance

	local function step(direction: number)
		local list = teammates(player)
		if #list == 0 then
			return
		end
		local index = if target then table.find(list, target) else nil
		index = if index then ((index - 1 + direction) % #list) + 1 else 1
		target = list[index :: number]
	end
	previous.Activated:Connect(function()
		step(-1)
	end)
	nextButton.Activated:Connect(function()
		step(1)
	end)

	local function enter()
		active = true
		savedMode = player.CameraMode
		savedMinZoom = player.CameraMinZoomDistance
		savedMaxZoom = player.CameraMaxZoomDistance
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = Config.Lab.SpectateDistance
		player.CameraMaxZoomDistance = Config.Lab.SpectateDistance
		FirstPersonController.freeCursor("Spectate", true)
		gui.Enabled = true
	end

	local function leave()
		active = false
		target = nil
		overhead = false
		gui.Enabled = false
		FirstPersonController.freeCursor("Spectate", false)
		player.CameraMode = savedMode
		player.CameraMinZoomDistance = savedMinZoom
		player.CameraMaxZoomDistance = savedMaxZoom
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end

	RunService.RenderStepped:Connect(function()
		local wanted = LabModes.isRounds() and Arena.inBattle() and player:GetAttribute("LabOut") == true
		if wanted and not active then
			enter()
		elseif not wanted and active then
			leave()
		end
		if not active then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local list = teammates(player)
		if not target or not table.find(list, target) then
			target = list[1]
		end
		local watched = target
		local humanoid = if watched and watched.Character
			then watched.Character:FindFirstChildOfClass("Humanoid")
			else nil
		if watched and humanoid then
			if overhead then
				overhead = false
				camera.CameraType = Enum.CameraType.Custom
			end
			if camera.CameraSubject ~= humanoid then
				camera.CameraSubject = humanoid
			end
			caption.Text = T("Viendo a {name}", { name = watched.DisplayName })
		else
			-- Nadie en pie de su bando: vista fija desde arriba.
			overhead = true
			local center = mapCenter()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(center + Vector3.new(0, OVERHEAD_HEIGHT, OVERHEAD_BACK), center)
			caption.Text = T("Ningún compañero en pie")
		end
		previous.Visible = #list > 1
		nextButton.Visible = #list > 1
	end)
end

return LabSpectateController
