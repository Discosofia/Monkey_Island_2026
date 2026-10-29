--!strict
-- Espectador de quien cae en una partida por equipos (Fase 15, V10): lo comparten la arena de Dunas
-- (ArenaSpectateController) y el Laboratorio (LabSpectateController). Es un módulo, no un controlador: cada
-- place lo configura y llama a :Start() desde su controlador fino.
--   1. Killcam: los primeros killcamSeconds la cámara mira a quien lo derribó (atributo "KilledBy" del
--      jugador, Shared/Arena) y una ficha dice quién es, con qué arma ("KilledWith") y cuánta vida le queda.
--   2. Después, tercera persona sobre un candidato en pie, con ◀ ▶ para cambiar de uno (solo si hay más de
--      uno) y "Viendo a {name}".
--   3. Sin candidatos, vista fija desde arriba (cámara Scriptable) si el place da "overhead"; si no, se queda
--      como estaba. "hideCeiling" oculta (y devuelve) el techo del mapa mientras dura esa vista.
-- Sin asesino válido (caída sin crédito, se fue, ya no tiene personaje) no hay killcam. Al dejar de ser
-- espectador (wantsSpectate pasa a false: reaparece o acaba la ronda) se restaura el modo de cámara, el zoom
-- y el sujeto de la cámara. Mientras dura, "freeCursor" suelta el ratón (solo el Laboratorio lo tiene).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Widgets = require(ReplicatedStorage.Shared.UI.Widgets)

local T = Strings.t

local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local HEALTH_COLOR = Color3.fromRGB(230, 80, 80)
local BUTTON_SIZE = 48
local BAR_WIDTH = 330
-- Sobre la línea "Ctrl: soltar el ratón" del HUD (abajo en el centro, a 12 px del borde).
local BAR_BOTTOM = 44
-- La ficha de la killcam ocupa el sitio de la barra (que se esconde mientras dura).
local CARD_SIZE = Vector2.new(300, 88)
local CARD_HEALTH_HEIGHT = 20
local MAX_CARD_TEXT = 22

export type Options = {
	-- Jugadores que se pueden seguir, en pie y en un orden estable.
	candidates: () -> { Player },
	-- Vista fija sin candidatos: centro, altura y desplazamiento hacia atrás. Sin esta función no hay vista
	-- cenital (la cámara se queda donde estaba).
	overhead: (() -> (Vector3, number, number))?,
	hideCeiling: ((hidden: boolean) -> ())?,
	freeCursor: ((on: boolean) -> ())?,
	-- true mientras debe ser espectador.
	wantsSpectate: () -> boolean,
	-- Distancia de la cámara al jugador que sigue.
	distance: number,
	killcamSeconds: number,
	-- Nombre del ScreenGui (único por place).
	guiName: string?,
}

local SpectateCamera = {}
SpectateCamera.__index = SpectateCamera

export type SpectateCamera = typeof(setmetatable({} :: { options: Options }, SpectateCamera))

-- En pie: con vida y sin estar fuera de la ronda ("LabOut").
function SpectateCamera.isStanding(other: Player): boolean
	if other:GetAttribute("LabOut") == true then
		return false
	end
	local humanoid = if other.Character then other.Character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.Health > 0
end

local function sorted(list: { Player }): { Player }
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

-- Los de su equipo en pie, sin él.
function SpectateCamera.allies(player: Player): { Player }
	local list = {}
	local teamId = Arena.teamOf(player)
	if teamId then
		for _, other in Arena.membersOf(teamId) do
			if other ~= player and SpectateCamera.isStanding(other) then
				table.insert(list, other)
			end
		end
	end
	return sorted(list)
end

-- Todos los demás en pie (Todos contra todos del Laboratorio).
function SpectateCamera.everyone(player: Player): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and SpectateCamera.isStanding(other) then
			table.insert(list, other)
		end
	end
	return sorted(list)
end

local function humanoidOf(other: Player?): Humanoid?
	local character = if other then other.Character else nil
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- El nombre (traducido) del arma de la baja, o nil si no se sabe.
local function weaponName(weaponId: any): string?
	local definition = if typeof(weaponId) == "string" then Weapons[weaponId] else nil
	return if definition then T(definition.name) else nil
end

function SpectateCamera.new(options: Options): SpectateCamera
	return setmetatable({ options = options }, SpectateCamera)
end

function SpectateCamera.Start(self: SpectateCamera)
	local options = self.options
	local player = Players.LocalPlayer
	local gui = Widgets.screen(options.guiName or "Spectate", player:WaitForChild("PlayerGui"))
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
	local function arrow(text: string, name: string, anchor: number): TextButton
		local button = Widgets.button(text, bar)
		button.Name = name
		button.AnchorPoint = Vector2.new(anchor, 0.5)
		button.Position = UDim2.new(anchor, if anchor == 0 then 4 else -4, 0.5, 0)
		button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
		-- El mínimo de Widgets.button (160 × 48) no cabe en la barra.
		local limit = button:FindFirstChildOfClass("UISizeConstraint")
		if limit then
			limit.MinSize = Vector2.new(BUTTON_SIZE, BUTTON_SIZE)
		end
		return button
	end
	local previous = arrow("◀", "Previous", 0)
	local nextButton = arrow("▶", "Next", 1)
	local caption = Widgets.label("", bar)
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 0.5)
	caption.Position = UDim2.fromScale(0.5, 0.5)
	caption.Size = UDim2.new(1, -(BUTTON_SIZE + 12) * 2, 1, -12)
	caption.TextStrokeTransparency = 0.3

	-- Ficha de la killcam: quién, con qué arma y cuánta vida le queda.
	local card = Instance.new("Frame")
	card.Name = "Killcam"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -BAR_BOTTOM)
	card.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	card.BackgroundColor3 = PANEL_COLOR
	card.BackgroundTransparency = 0.25
	card.Visible = false
	card.Parent = gui
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = card
	local killerLabel = Widgets.label("", card)
	killerLabel.Name = "Killer"
	killerLabel.Position = UDim2.fromOffset(10, 6)
	killerLabel.Size = UDim2.new(1, -20, 0, 26)
	killerLabel.TextStrokeTransparency = 0.3
	local weaponLabel = Widgets.label("", card)
	weaponLabel.Name = "Weapon"
	weaponLabel.Position = UDim2.fromOffset(10, 34)
	weaponLabel.Size = UDim2.new(1, -20, 0, 20)
	weaponLabel.TextStrokeTransparency = 0.3
	for _, label in { killerLabel, weaponLabel } do
		local textLimit = Instance.new("UITextSizeConstraint")
		textLimit.MaxTextSize = MAX_CARD_TEXT
		textLimit.Parent = label
	end
	local healthBack = Instance.new("Frame")
	healthBack.Name = "Health"
	healthBack.Position = UDim2.new(0, 10, 1, -(CARD_HEALTH_HEIGHT + 8))
	healthBack.Size = UDim2.new(1, -20, 0, CARD_HEALTH_HEIGHT)
	healthBack.BackgroundColor3 = Color3.fromRGB(60, 50, 45)
	healthBack.Parent = card
	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 8)
	healthCorner.Parent = healthBack
	local healthFill = Instance.new("Frame")
	healthFill.Name = "Fill"
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.BackgroundColor3 = HEALTH_COLOR
	healthFill.Parent = healthBack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = healthFill
	local healthText = Widgets.label("", healthBack)
	healthText.Size = UDim2.fromScale(1, 1)
	healthText.TextStrokeTransparency = 0.3

	local active = false
	local target: Player? = nil
	local overhead = false
	-- true mientras el techo del mapa está oculto en local (vista cenital).
	local ceilingHidden = false
	-- La killcam de esta vez: a quién mira y cuándo empezó (nil = ya pasó o no hay).
	local killer: Player? = nil
	local killcamStart = 0
	-- Lo que había antes de ser espectador, para devolverlo.
	local savedMode: Enum.CameraMode = player.CameraMode
	local savedMinZoom = player.CameraMinZoomDistance
	local savedMaxZoom = player.CameraMaxZoomDistance

	local function setCeiling(hidden: boolean)
		if ceilingHidden == hidden then
			return
		end
		ceilingHidden = hidden
		if options.hideCeiling then
			options.hideCeiling(hidden)
		end
	end

	local function step(direction: number)
		local list = options.candidates()
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

	-- Quién lo derribó, si sigue en la partida con personaje.
	local function findKiller(): Player?
		local userId = player:GetAttribute("KilledBy")
		local found = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		if found and found ~= player and humanoidOf(found) then
			return found
		end
		return nil
	end

	local function enter()
		active = true
		savedMode = player.CameraMode
		savedMinZoom = player.CameraMinZoomDistance
		savedMaxZoom = player.CameraMaxZoomDistance
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = options.distance
		player.CameraMaxZoomDistance = options.distance
		if options.freeCursor then
			options.freeCursor(true)
		end
		killer = findKiller()
		killcamStart = os.clock()
		gui.Enabled = true
	end

	local function leave()
		active = false
		target = nil
		killer = nil
		overhead = false
		setCeiling(false)
		card.Visible = false
		gui.Enabled = false
		if options.freeCursor then
			options.freeCursor(false)
		end
		player.CameraMode = savedMode
		player.CameraMinZoomDistance = savedMinZoom
		player.CameraMaxZoomDistance = savedMaxZoom
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			local humanoid = humanoidOf(player)
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end

	-- La killcam de este cuadro. false si ya no toca (se acabó el tiempo o el asesino ya no está).
	local function killcamFrame(camera: Camera): boolean
		local watched = killer
		local humanoid = humanoidOf(watched)
		if not watched or not humanoid or os.clock() - killcamStart >= options.killcamSeconds then
			killer = nil
			return false
		end
		if camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end
		if camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end
		killerLabel.Text = T("Te derribó {name}", { name = watched.DisplayName })
		local weapon = weaponName(player:GetAttribute("KilledWith"))
		weaponLabel.Text = if weapon then T("con {weapon}", { weapon = weapon }) else ""
		weaponLabel.Visible = weapon ~= nil
		local health = math.max(0, humanoid.Health)
		healthFill.Size = UDim2.fromScale(math.clamp(health / math.max(1, humanoid.MaxHealth), 0, 1), 1)
		healthFill.Visible = health > 0
		healthText.Text = T("{hp} PV", { hp = math.floor(health + 0.5) })
		return true
	end

	RunService.RenderStepped:Connect(function()
		local wanted = options.wantsSpectate()
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

		local inKillcam = killcamFrame(camera)
		card.Visible = inKillcam
		bar.Visible = not inKillcam
		if inKillcam then
			if overhead then
				overhead = false
				setCeiling(false)
			end
			return
		end

		local list = options.candidates()
		if not target or not table.find(list, target) then
			target = list[1]
		end
		local watched = target
		local humanoid = humanoidOf(watched)
		if watched and humanoid then
			if overhead then
				overhead = false
				camera.CameraType = Enum.CameraType.Custom
				setCeiling(false)
			end
			if camera.CameraType ~= Enum.CameraType.Custom then
				camera.CameraType = Enum.CameraType.Custom
			end
			if camera.CameraSubject ~= humanoid then
				camera.CameraSubject = humanoid
			end
			caption.Text = T("Viendo a {name}", { name = watched.DisplayName })
		else
			-- Nadie en pie: vista fija desde arriba, si el place la da.
			if options.overhead then
				local center, height, back = options.overhead()
				overhead = true
				camera.CameraType = Enum.CameraType.Scriptable
				-- Justo encima (back = 0) la mirada es paralela al "arriba" por defecto: se da otro, con el
				-- norte (-Z) hacia arriba de la pantalla como en la vista inclinada.
				local up = if back == 0 then Vector3.new(0, 0, -1) else Vector3.yAxis
				camera.CFrame = CFrame.lookAt(center + Vector3.new(0, height, back), center, up)
				setCeiling(true)
			end
			caption.Text = T("Ningún compañero en pie")
		end
		previous.Visible = #list > 1
		nextButton.Visible = #list > 1
	end)
end

return SpectateCamera
