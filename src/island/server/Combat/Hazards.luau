--!strict
-- Peligros de área con aviso previo en el suelo (Fase 5): rocas que caen, bombas de lava, rayos y
-- ondas de choque. Los usan los jefes (BossService), la erupción del volcán y la tormenta
-- (WeatherService). Siempre avisan antes con un círculo en el suelo, para que se puedan esquivar.
-- Respetan la zona segura del Basecamp.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Sfx = require(ReplicatedStorage.Shared.Sfx)
local CombatService = require(script.Parent.Parent.Services.CombatService)

local SPARKS_TEXTURE = "rbxasset://textures/particles/fire_sparks_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local BOLT_COLOR = Color3.fromRGB(215, 230, 255)
local BOLT_GLOW = Color3.fromRGB(140, 170, 255)
local LAVA_COLOR = Color3.fromRGB(255, 110, 30)
local LAVA_FLIGHT_SECONDS = 1.1

local Hazards = {}

local rng = Random.new()

local function effectPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = Workspace
	return part
end

-- Chispas, humo o polvo que salen de golpe desde un punto.
local function burst(position: Vector3, texture: string, color: Color3, amount: number, speed: number, lifetime: number)
	local anchor = effectPart("Burst", Vector3.one * 0.2, CFrame.new(position), color, Enum.Material.Air)
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = if texture == SPARKS_TEXTURE then 1 else 0
	local isSpark = texture == SPARKS_TEXTURE
	emitter.Size = NumberSequence.new(if isSpark then 0.6 else 2.5, if isSpark then 0.1 else 5)
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = if texture == SPARKS_TEXTURE then Vector3.new(0, -30, 0) else Vector3.new(0, 3, 0)
	emitter.Drag = 2
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(amount)
	Debris:AddItem(anchor, lifetime + 0.5)
end

-- Bola brillante que crece y se desvanece (fogonazo de un impacto).
local function flash(position: Vector3, color: Color3, size: number, seconds: number)
	local ball = effectPart("Flash", Vector3.one, CFrame.new(position), color, Enum.Material.Neon)
	ball.Shape = Enum.PartType.Ball
	ball.Transparency = 0.2
	TweenService:Create(ball, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size,
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, seconds + 0.1)
end

-- Marca quemada en el suelo que se borra poco a poco.
local function scorch(position: Vector3, radius: number, color: Color3, material: Enum.Material, seconds: number)
	local disk = effectPart(
		"Scorch",
		Vector3.new(0.15, radius * 2, radius * 2),
		CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	disk.Shape = Enum.PartType.Cylinder
	TweenService:Create(disk, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	}):Play()
	Debris:AddItem(disk, seconds + 0.1)
	return disk
end

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

-- Daña a quien esté dentro del círculo (con daño 0, de prueba, no hace nada).
local function hurtNear(position: Vector3, radius: number, damage: number)
	if damage <= 0 then
		return
	end
	for _, player in playersNear(position, radius) do
		CombatService.damagePlayer(player, damage)
	end
end

-- Una roca cae en "position" tras "warnSeconds" de aviso.
function Hazards.fallingRock(position: Vector3, damage: number, radius: number, color: Color3, warnSeconds: number)
	local ground = groundAt(position)
	marker(ground, radius, Color3.fromRGB(255, 60, 40), warnSeconds + 0.4)
	task.delay(warnSeconds, function()
		local rock = Instance.new("Part")
		rock.Name = "FallingRock"
		rock.Shape = Enum.PartType.Ball
		rock.Size = Vector3.one * radius
		rock.Color = color
		rock.Material = Enum.Material.Slate
		rock.Anchored = true
		rock.CanCollide = false
		rock.CanQuery = false
		rock.CanTouch = false
		rock.Position = ground + Vector3.new(0, 45, 0)
		rock.Parent = Workspace
		TweenService:Create(rock, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(ground + Vector3.new(0, radius / 2, 0)) * CFrame.Angles(2.5, 1.2, 0.8),
		}):Play()
		Debris:AddItem(rock, 1.2)
		task.wait(0.4)
		Sfx.play("RockImpact", ground)
		burst(ground + Vector3.new(0, 1, 0), SMOKE_TEXTURE, Color3.fromRGB(140, 125, 105), 14, 14, 1.2)
		hurtNear(ground, radius, damage)
	end)
end

-- Rayo de la tormenta: tras el aviso cae un rayo en zigzag con ramas, un destello y chispas, y deja
-- el suelo chamuscado.
function Hazards.lightning(position: Vector3, damage: number, radius: number, warnSeconds: number)
	local ground = groundAt(position)
	marker(ground, radius, Color3.fromRGB(255, 240, 120), warnSeconds + 0.2)
	task.delay(warnSeconds, function()
		local parts: { BasePart } = {}
		local function segment(from: Vector3, to: Vector3, thickness: number)
			local length = (to - from).Magnitude
			local frame = CFrame.lookAt((from + to) / 2, to)
			local core =
				effectPart("Rayo", Vector3.new(thickness, thickness, length), frame, BOLT_COLOR, Enum.Material.Neon)
			local glow = effectPart(
				"RayoBrillo",
				Vector3.new(thickness * 3, thickness * 3, length),
				frame,
				BOLT_GLOW,
				Enum.Material.Neon
			)
			glow.Transparency = 0.75
			table.insert(parts, core)
			table.insert(parts, glow)
		end
		-- Tronco principal desde el cielo, quebrándose cada vez menos al acercarse al suelo.
		local top = ground + Vector3.new(rng:NextNumber(-12, 12), 160, rng:NextNumber(-12, 12))
		local steps = 12
		local points = { top }
		for i = 1, steps - 1 do
			local along = top:Lerp(ground, i / steps)
			local wobble = 7 * (1 - i / steps) + 1
			table.insert(
				points,
				along + Vector3.new(rng:NextNumber(-wobble, wobble), 0, rng:NextNumber(-wobble, wobble))
			)
		end
		table.insert(points, ground)
		for i = 1, #points - 1 do
			segment(points[i], points[i + 1], 0.7)
		end
		-- Dos o tres ramas que se abren hacia abajo.
		for _ = 1, rng:NextInteger(2, 3) do
			local from = points[rng:NextInteger(2, steps - 3)]
			local direction = Vector3.new(rng:NextNumber(-1, 1), -1.2, rng:NextNumber(-1, 1)).Unit
			for _ = 1, 3 do
				local to = from + direction * rng:NextNumber(7, 13)
				segment(from, to, 0.35)
				from = to
				direction = (direction + Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5))).Unit
			end
		end
		local light = effectPart(
			"RayoLuz",
			Vector3.one * 0.2,
			CFrame.new(ground + Vector3.new(0, 4, 0)),
			BOLT_COLOR,
			Enum.Material.Air
		)
		light.Transparency = 1
		local glowLight = Instance.new("PointLight")
		glowLight.Color = BOLT_COLOR
		glowLight.Range = 50
		glowLight.Brightness = 8
		glowLight.Parent = light
		TweenService:Create(glowLight, TweenInfo.new(0.6), { Brightness = 0 }):Play()
		Debris:AddItem(light, 0.7)

		Sfx.play("Thunder", ground)
		flash(ground + Vector3.new(0, 1, 0), BOLT_COLOR, radius * 2.2, 0.35)
		burst(ground + Vector3.new(0, 0.5, 0), SPARKS_TEXTURE, Color3.fromRGB(255, 240, 160), 40, 30, 0.7)
		scorch(ground, radius * 0.8, Color3.fromRGB(25, 22, 20), Enum.Material.Slate, 6)
		hurtNear(ground, radius, damage)

		-- Parpadeo: encendido, apagado, encendido y se desvanece.
		task.spawn(function()
			local function setVisible(visible: boolean)
				for _, part in parts do
					part.Transparency = if visible then (if part.Name == "Rayo" then 0 else 0.75) else 1
				end
			end
			task.wait(0.07)
			setVisible(false)
			task.wait(0.05)
			setVisible(true)
			task.wait(0.06)
			for _, part in parts do
				TweenService:Create(part, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			end
			task.wait(0.3)
			for _, part in parts do
				part:Destroy()
			end
		end)
	end)
end

-- Bomba de lava: sale de "origin" (el cráter o el jefe) en arco, dejando estela de fuego y humo, y
-- revienta en "position" al acabar el aviso, dejando un charco de lava unos segundos.
function Hazards.lavaBomb(position: Vector3, damage: number, radius: number, warnSeconds: number, origin: Vector3?)
	local ground = groundAt(position)
	marker(ground, radius, Color3.fromRGB(255, 60, 40), warnSeconds + 0.3)
	local start = origin or (ground + Vector3.new(rng:NextNumber(-30, 30), 80, rng:NextNumber(-30, 30)))
	local flight = math.min(LAVA_FLIGHT_SECONDS, warnSeconds)
	task.delay(warnSeconds - flight, function()
		local size = math.max(2.2, radius * 0.55)
		local bomb =
			effectPart("BombaDeLava", Vector3.one * size, CFrame.new(start), LAVA_COLOR, Enum.Material.CrackedLava)
		bomb.Shape = Enum.PartType.Ball
		local glow = Instance.new("PointLight")
		glow.Color = LAVA_COLOR
		glow.Range = 16
		glow.Brightness = 3
		glow.Parent = bomb
		local fire = Instance.new("Fire")
		fire.Size = size * 1.6
		fire.Heat = 0
		fire.Color = LAVA_COLOR
		fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
		fire.Parent = bomb
		local tail0 = Instance.new("Attachment")
		tail0.Position = Vector3.new(0, size * 0.4, 0)
		tail0.Parent = bomb
		local tail1 = Instance.new("Attachment")
		tail1.Position = Vector3.new(0, -size * 0.4, 0)
		tail1.Parent = bomb
		local trail = Instance.new("Trail")
		trail.Attachment0 = tail0
		trail.Attachment1 = tail1
		trail.Lifetime = 0.6
		trail.LightEmission = 0.8
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(70, 60, 55))
		trail.Transparency = NumberSequence.new(0, 1)
		trail.Parent = bomb
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = SMOKE_TEXTURE
		smoke.Color = ColorSequence.new(Color3.fromRGB(60, 55, 50))
		smoke.Size = NumberSequence.new(size * 0.8, size * 2)
		smoke.Transparency = NumberSequence.new(0.3, 1)
		smoke.Lifetime = NumberRange.new(0.8, 1.2)
		smoke.Rate = 25
		smoke.Speed = NumberRange.new(1, 2)
		smoke.Parent = bomb
		Sfx.play("LavaLaunch", start)

		-- Vuelo en arco (curva con el punto de control por encima del medio), girando.
		local landing = ground + Vector3.new(0, size / 2, 0)
		local control = (start + landing) / 2 + Vector3.new(0, 35, 0)
		local elapsed = 0
		while elapsed < flight do
			elapsed += RunService.Heartbeat:Wait()
			local t = math.min(elapsed / flight, 1)
			local point = start:Lerp(control, t):Lerp(control:Lerp(landing, t), t)
			bomb.CFrame = CFrame.new(point) * CFrame.Angles(elapsed * 6, elapsed * 4, 0)
		end
		bomb:Destroy()

		Sfx.play("LavaImpact", ground)
		flash(ground + Vector3.new(0, 1, 0), LAVA_COLOR, radius * 2, 0.45)
		burst(ground + Vector3.new(0, 1, 0), SPARKS_TEXTURE, Color3.fromRGB(255, 160, 50), 45, 35, 1)
		burst(ground + Vector3.new(0, 2, 0), SMOKE_TEXTURE, Color3.fromRGB(70, 60, 55), 12, 10, 2)
		local pool = scorch(ground, radius * 0.7, LAVA_COLOR, Enum.Material.CrackedLava, 4)
		local poolFire = Instance.new("Fire")
		poolFire.Size = radius
		poolFire.Heat = 4
		poolFire.Color = LAVA_COLOR
		poolFire.SecondaryColor = Color3.fromRGB(255, 220, 80)
		poolFire.Parent = pool
		task.delay(2.5, function()
			poolFire.Enabled = false
		end)
		hurtNear(ground, radius, damage)
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
