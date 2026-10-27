--!strict
-- Señales de las estaciones de la plaza del Lobby (las piezas con el atributo "StationId", que pone
-- World/LobbyBuilder: roles, ranking, Isla de dunas, pase de temporada y nido):
--   - Un icono flotante encima de cada una ("StationIcon"), visible desde lejos, que sube y baja.
--     Lleva un "!" rojo cuando hay algo para ti: puntos de talento por gastar (roles), el huevo del
--     nido listo o huevos esperando un nido vacío (nido), premios del pase por reclamar (pase), y
--     "⏳" en la Isla de dunas si estás buscando partida. Cada jugador ve los suyos.
--   - Un contorno dorado en lo que tiene el aviso a la vista (cualquier ProximityPrompt del Lobby,
--     también los botes), para que se note que se puede usar.
-- LobbyGuideController resalta el de la estación a la que lleva la guía (StationMarkers.focus).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EggIncubation = require(ReplicatedStorage.Shared.EggIncubation)
local Plot = require(ReplicatedStorage.Shared.Plot)
local Progression = require(ReplicatedStorage.Shared.Progression)
local SeasonPass = require(ReplicatedStorage.Shared.SeasonPass)

local PANEL_COLOR = Color3.fromRGB(25, 20, 15)
local GOLD = Color3.fromRGB(242, 178, 36)
local BADGE_COLOR = Color3.fromRGB(235, 70, 60)
local OUTLINE_COLOR = Color3.fromRGB(255, 215, 90)
local MARKER_SIZE = 56
local FOCUS_SIZE = 76
local MAX_DISTANCE = 160
-- Altura del icono sobre la pieza de la estación: por encima de la cabecera y los faroles de un
-- cartel, o del huevo en el nido.
local BOARD_CLEARANCE = 5.5
local NEST_CLEARANCE = 8
local BOB = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

type Marker = { gui: BillboardGui, badge: TextLabel, ring: UIStroke, id: string }

local StationMarkers = {}
-- Estación resaltada por la guía (nil = ninguna).
local focused: string? = nil
local markers: { [BasePart]: Marker } = {}

local function readJson(raw: any): { [string]: any }?
	if typeof(raw) ~= "string" then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and typeof(decoded) == "table" then decoded else nil
end

-- Qué lleva la esquina del icono de cada estación ("" = nada).
local function badgeFor(player: Player, id: string): string
	if id == "Rol" then
		local roleId = Progression.validRole(player:GetAttribute("SelectedRole"))
		return if Progression.freePoints(roleId, Progression.read(player)) > 0 then "!" else ""
	elseif id == "Mascotas" then
		local raw = player:GetAttribute("Eggs")
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(if typeof(raw) == "string" then raw else "{}")
		end)
		local eggs = EggIncubation.normalize(if ok then decoded else nil)
		-- Un huevo listo, o un hueco libre del nido con huevos esperando (Shared/Plot.incubator).
		for slot = 1, #EggIncubation.NEST_KEYS do
			local nest = EggIncubation.inSlot(eggs, slot)
			if nest and EggIncubation.isReady(nest, EggIncubation.now()) then
				return "!"
			end
		end
		local slots = Plot.incubator(Plot.of(player))
		return if EggIncubation.freeSlot(eggs, slots) and #eggs.bag + #eggs.pending > 0 then "!" else ""
	elseif id == "Arena" then
		return if readJson(player:GetAttribute("ArenaQueue")) then "⏳" else ""
	elseif id == "Pase" then
		local season = SeasonPass.info(SeasonPass.now()).season
		local state = SeasonPass.normalize(readJson(player:GetAttribute("Season")), if season then season.id else nil)
		return if SeasonPass.hasClaimable(season, state) then "!" else ""
	end
	return ""
end

local function refreshMarker(player: Player, marker: Marker)
	local badge = badgeFor(player, marker.id)
	marker.badge.Text = badge
	marker.badge.Visible = badge ~= ""
	marker.badge.BackgroundColor3 = if badge == "!" then BADGE_COLOR else PANEL_COLOR
	local isFocus = focused == marker.id
	local size = if isFocus then FOCUS_SIZE else MARKER_SIZE
	marker.gui.Size = UDim2.fromOffset(size, size)
	marker.ring.Color = if isFocus then BADGE_COLOR else GOLD
	marker.ring.Thickness = if isFocus then 4 else 2
end

-- La guía resalta (más grande y con el aro rojo) el icono de la estación "id"; nil lo quita.
function StationMarkers.focus(id: string?)
	focused = id
	local player = Players.LocalPlayer
	for _, marker in markers do
		refreshMarker(player, marker)
	end
end

local function build(player: Player, part: BasePart, id: string, icon: string): Marker
	local gui = Instance.new("BillboardGui")
	gui.Name = `Estacion_{id}`
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(MARKER_SIZE, MARKER_SIZE)
	-- Una estación puede pedir su altura ("StationIconLift": el cartel del pase lleva un volcán encima).
	local lift = part:GetAttribute("StationIconLift")
	local clearance = if typeof(lift) == "number"
		then lift
		elseif id == "Mascotas" then NEST_CLEARANCE
		else BOARD_CLEARANCE
	local offset = Vector3.new(0, part.Size.Y / 2 + clearance, 0)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	TweenService:Create(gui, BOB, { StudsOffsetWorldSpace = offset + Vector3.new(0, 0.7, 0) }):Play()

	local circle = Instance.new("TextLabel")
	circle.Size = UDim2.fromScale(1, 1)
	circle.BackgroundColor3 = PANEL_COLOR
	circle.BackgroundTransparency = 0.15
	circle.Text = icon
	circle.TextScaled = true
	circle.Font = Enum.Font.BuilderSansBold
	circle.TextColor3 = Color3.new(1, 1, 1)
	circle.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = circle
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.18, 0)
	padding.PaddingBottom = UDim.new(0.18, 0)
	padding.PaddingLeft = UDim.new(0.18, 0)
	padding.PaddingRight = UDim.new(0.18, 0)
	padding.Parent = circle
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = GOLD
	ring.Thickness = 2
	ring.Parent = circle

	local badge = Instance.new("TextLabel")
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.88, 0.12)
	badge.Size = UDim2.fromScale(0.42, 0.42)
	badge.BackgroundColor3 = BADGE_COLOR
	badge.Text = ""
	badge.TextScaled = true
	badge.Font = Enum.Font.BuilderSansExtraBold
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Visible = false
	badge.Parent = gui
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0.5, 0)
	badgeCorner.Parent = badge
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	badgeStroke.Color = Color3.new(1, 1, 1)
	badgeStroke.Thickness = 1.5
	badgeStroke.Parent = badge

	return { gui = gui, badge = badge, ring = ring, id = id }
end

-- El modelo entero de lo que lleva el aviso (el cartel con sus postes, el nido con su montículo, el
-- bote): el de más arriba dentro de la carpeta del escenario.
local function stationModel(prompt: ProximityPrompt): Instance?
	local current = prompt.Parent
	local found: Instance? = nil
	while current and current ~= Workspace do
		if current:IsA("Model") then
			found = current
		end
		current = current.Parent
	end
	return found
end

function StationMarkers:Start()
	local player = Players.LocalPlayer

	local function consider(instance: Instance)
		if not instance:IsA("BasePart") or markers[instance] then
			return
		end
		local id = instance:GetAttribute("StationId")
		local icon = instance:GetAttribute("StationIcon")
		if typeof(id) ~= "string" or typeof(icon) ~= "string" then
			return
		end
		local marker = build(player, instance, id, icon)
		markers[instance] = marker
		refreshMarker(player, marker)
		instance.AncestryChanged:Connect(function()
			if not instance:IsDescendantOf(Workspace) then
				marker.gui:Destroy()
				markers[instance] = nil
			end
		end)
	end
	for _, instance in Workspace:GetDescendants() do
		consider(instance)
	end
	Workspace.DescendantAdded:Connect(consider)

	local function refreshAll()
		for _, marker in markers do
			refreshMarker(player, marker)
		end
	end
	player.AttributeChanged:Connect(function(attribute)
		if
			attribute == "Eggs"
			or attribute == "Progress"
			or attribute == "SelectedRole"
			or attribute == "ArenaQueue"
			or attribute == "Season"
		then
			refreshAll()
		end
	end)
	-- El huevo del nido termina solo: se mira cada pocos segundos.
	task.spawn(function()
		while true do
			task.wait(5)
			refreshAll()
		end
	end)

	-- Contorno dorado en lo que tiene el aviso a la vista.
	local outlines: { [ProximityPrompt]: Highlight } = {}
	ProximityPromptService.PromptShown:Connect(function(prompt)
		local model = stationModel(prompt)
		if not model or outlines[prompt] then
			return
		end
		local outline = Instance.new("Highlight")
		outline.Name = "BrilloEstacion"
		outline.Adornee = model
		outline.FillTransparency = 1
		outline.OutlineColor = OUTLINE_COLOR
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = Workspace.CurrentCamera
		outlines[prompt] = outline
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local outline = outlines[prompt]
		if outline then
			outline:Destroy()
			outlines[prompt] = nil
		end
	end)
end

return StationMarkers
