--!strict
-- Zona segura del Basecamp (GDD §10).
-- Marca a cada jugador con el atributo "InBasecamp" (true/false) para el HUD.
-- Otros sistemas (monos, daño, construcción) usarán BasecampService.isInside(posición).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local BasecampService = {}

local zone: BasePart? = nil

local function findOrCreateZone(): BasePart
	local existing = Workspace:FindFirstChild(Config.Basecamp.ZonePartName, true)
	if existing and existing:IsA("BasePart") then
		return existing
	end

	warn(
		`[BasecampService] No hay una pieza "{Config.Basecamp.ZonePartName}" en Workspace. `
			.. "Se crea una zona por defecto en el centro del mapa (ver Config.Basecamp)."
	)
	local part = Instance.new("Part")
	part.Name = Config.Basecamp.ZonePartName
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Size = Config.Basecamp.DefaultZoneSize
	part.Position = Config.Basecamp.DefaultZoneCenter
	-- Verde muy transparente: visible desde fuera para saber dónde está la zona segura.
	part.Color = Color3.fromRGB(80, 200, 120)
	part.Transparency = 0.9
	part.Parent = Workspace
	return part
end

-- true si la posición está dentro de la zona del Basecamp (respeta la rotación de la pieza).
function BasecampService.isInside(position: Vector3): boolean
	local zonePart = zone
	if not zonePart then
		return false
	end
	local localPosition = zonePart.CFrame:PointToObjectSpace(position)
	local halfSize = zonePart.Size / 2
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

-- Centro de la zona del Basecamp (a media altura de la pieza).
function BasecampService.getCenter(): Vector3
	return if zone then zone.Position else Config.Basecamp.DefaultZoneCenter
end

function BasecampService:Init()
	zone = findOrCreateZone()
end

function BasecampService:Start()
	while true do
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local inside = false
			if root and root:IsA("BasePart") then
				inside = BasecampService.isInside(root.Position)
			end
			if player:GetAttribute("InBasecamp") ~= inside then
				player:SetAttribute("InBasecamp", inside)
			end
		end
		task.wait(Config.Basecamp.CheckIntervalSeconds)
	end
end

return BasecampService
