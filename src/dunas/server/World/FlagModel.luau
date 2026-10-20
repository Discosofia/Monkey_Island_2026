--!strict
-- Bandera de un equipo de la arena (la mueve FlagService): mástil de madera, tela del color del
-- equipo con su emblema (🐆 / 🦜) en las dos caras, franja oscura abajo y un remate dorado que
-- brilla. Encima lleva un icono que se ve a través de las paredes, para saber siempre dónde está.
--
-- Todas las piezas van soldadas al mástil ("Pole", la PrimaryPart): para moverla basta con anclar o
-- soldar el mástil. No chocan, no las encuentran los rayos (el Parpadeo y los disparos las
-- atraviesan) y no pesan (no frenan a quien la lleva).
--
-- Se lleva a la espalda con la tela plana hacia atrás, porque quien la lleva se ve casi siempre de
-- espaldas (el resto de jugadores lo persigue o lo escolta).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local POLE_HEIGHT = 8
local CLOTH_SIZE = Vector2.new(3.4, 2.4)
local WOOD = Color3.fromRGB(95, 62, 36)
local GOLD = Color3.fromRGB(255, 200, 60)

local FlagModel = {}

FlagModel.POLE_HEIGHT = POLE_HEIGHT

local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, pole: BasePart?, parent: Model): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	if pole then
		part.CFrame = pole.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = pole
		weld.Part1 = part
		weld.Parent = part
	end
	part.Parent = parent
	return part
end

-- Emblema en una cara de la tela.
local function emblem(cloth: BasePart, face: Enum.NormalId, icon: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = cloth
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.8)
	label.Text = icon
	label.TextScaled = true
	label.Font = Enum.Font.BuilderSansBold
	label.Parent = gui
end

-- Bandera de "teamId", con el mástil centrado en el origen (su base, a POLE_HEIGHT / 2 por debajo).
function FlagModel.build(teamId: string): Model
	local team = Config.Arena.Teams[teamId]
	local model = Instance.new("Model")
	model.Name = `Bandera{teamId}`
	model:SetAttribute("Team", teamId)

	local pole = piece("Pole", Vector3.new(0.4, POLE_HEIGHT, 0.4), CFrame.new(), WOOD, nil, model)
	pole.Material = Enum.Material.Wood
	pole.CFrame = CFrame.new()
	model.PrimaryPart = pole

	local top = POLE_HEIGHT / 2
	local cloth = piece(
		"Cloth",
		Vector3.new(CLOTH_SIZE.X, CLOTH_SIZE.Y, 0.15),
		CFrame.new(CLOTH_SIZE.X / 2 + 0.2, top - CLOTH_SIZE.Y / 2 - 0.3, 0),
		team.color,
		pole,
		model
	)
	cloth.Material = Enum.Material.Fabric
	piece(
		"Stripe",
		Vector3.new(CLOTH_SIZE.X, 0.4, 0.2),
		CFrame.new(CLOTH_SIZE.X / 2 + 0.2, top - CLOTH_SIZE.Y - 0.3 + 0.2, 0),
		team.color:Lerp(Color3.new(0, 0, 0), 0.45),
		pole,
		model
	)
	emblem(cloth, Enum.NormalId.Front, team.icon)
	emblem(cloth, Enum.NormalId.Back, team.icon)

	local finial = piece(
		"Finial",
		Vector3.one * 0.7,
		CFrame.new(0, top + 0.35, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		GOLD,
		pole,
		model
	)
	finial.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color = team.color
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = cloth

	-- Icono sobre la bandera que se ve a través de las paredes.
	local marker = Instance.new("BillboardGui")
	marker.Name = "Marker"
	marker.AlwaysOnTop = true
	marker.Size = UDim2.fromOffset(36, 36)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	marker.MaxDistance = 1000
	marker.LightInfluence = 0
	marker.Adornee = finial
	marker.Parent = finial
	local badge = Instance.new("TextLabel")
	badge.Size = UDim2.fromScale(1, 1)
	badge.BackgroundColor3 = team.color
	badge.BackgroundTransparency = 0.15
	badge.Text = team.icon
	badge.TextScaled = true
	badge.Font = Enum.Font.BuilderSansBold
	badge.Parent = marker
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = badge
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = badge
	return model
end

return FlagModel
