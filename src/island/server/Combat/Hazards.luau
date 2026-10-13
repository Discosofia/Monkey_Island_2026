--!strict
-- Peligros de área con aviso previo en el suelo (Fase 5): rocas o lava que caen y ondas de choque.
-- Los usan los jefes (BossService) y la erupción del volcán (WeatherService). Siempre avisan antes con
-- un círculo rojo, para que se puedan esquivar. Respetan la zona segura del Basecamp.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CombatService = require(script.Parent.Parent.Services.CombatService)

local Hazards = {}

local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local result = Workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return if result then result.Position else position
end

local function marker(position: Vector3, radius: number, color: Color3, seconds: number)
	local disk = Instance.new("Part")
	disk.Name = "HazardWarning"
	disk.Shape = Enum.PartType.Cylinder
	disk.Size = Vector3.new(0.3, radius * 2, radius * 2)
	disk.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disk.Anchored = true
	disk.CanCollide = false
	disk.CanQuery = false
	disk.CanTouch = false
	disk.Material = Enum.Material.Neon
	disk.Color = color
	disk.Transparency = 0.55
	disk.Parent = Workspace
	Debris:AddItem(disk, seconds)
end

-- Jugadores vivos fuera del Basecamp a menos de "radius" de "position".
local function playersNear(position: Vector3, radius: number): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and (root.Position - position).Magnitude <= radius then
			table.insert(list, player)
		end
	end
	return list
end

-- Una roca (o bola de lava) cae en "position" tras "warnSeconds" de aviso.
function Hazards.fallingRock(position: Vector3, damage: number, radius: number, color: Color3, warnSeconds: number)
	local ground = groundAt(position)
	marker(ground, radius, Color3.fromRGB(255, 60, 40), warnSeconds + 0.4)
	task.delay(warnSeconds, function()
		local rock = Instance.new("Part")
		rock.Name = "FallingRock"
		rock.Shape = Enum.PartType.Ball
		rock.Size = Vector3.one * radius
		rock.Color = color
		rock.Material = if color.R > 0.8 then Enum.Material.Neon else Enum.Material.Slate
		rock.Anchored = true
		rock.CanCollide = false
		rock.CanQuery = false
		rock.CanTouch = false
		rock.Position = ground + Vector3.new(0, 45, 0)
		rock.Parent = Workspace
		TweenService:Create(rock, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = ground + Vector3.new(0, radius / 2, 0),
		}):Play()
		Debris:AddItem(rock, 1.2)
		task.wait(0.4)
		for _, player in playersNear(ground, radius) do
			CombatService.damagePlayer(player, damage)
		end
	end)
end

-- Onda de choque alrededor de "position": daña y aturde a quien siga dentro tras el aviso.
function Hazards.shockwave(position: Vector3, radius: number, damage: number, stunSeconds: number, warnSeconds: number)
	local ground = groundAt(position)
	marker(ground, radius, Color3.fromRGB(255, 160, 40), warnSeconds)
	task.delay(warnSeconds, function()
		for _, player in playersNear(ground, radius) do
			if CombatService.damagePlayer(player, damage) then
				player:SetAttribute("StunnedUntil", Workspace:GetServerTimeNow() + stunSeconds)
			end
		end
	end)
end

return Hazards
