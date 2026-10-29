--!strict
-- Peligros de área con aviso previo en el suelo (Fase 5): rocas que caen, bombas de lava, rayos y
-- ondas de choque (las rocas, las bombas y la onda se dibujan en el cliente: Fase 16, R6). Los usan los jefes (BossService), la erupción del volcán y la tormenta
-- (WeatherService). Siempre avisan antes con un círculo en el suelo, para que se puedan esquivar.
-- Hacen daño a quien esté dentro del círculo al caer, también en el Basecamp: el círculo ya avisa.
-- "cause" (opcional, al final): quién lo lanza, para la telemetría (p. ej. "Jefe Orangutan"); sin
-- él cuenta como "Peligro".
-- No se pueden bloquear (Fase 10, C6): a quien está en guardia dentro del círculo se la rompen
-- (Combat/Guard) y entran enteros. Hay que salir del círculo o esquivar.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local CombatService = require(ServerScriptService.Combat.Services.CombatService)
local Guard = require(ServerScriptService.Combat.Guard)
local Status = require(ServerScriptService.Combat.Status)

local SPARKS_TEXTURE = "rbxasset://textures/particles/fire_sparks_main.dds"
local BOLT_COLOR = Color3.fromRGB(215, 230, 255)
local BOLT_GLOW = Color3.fromRGB(140, 170, 255)
local LAVA_FLIGHT_SECONDS = 1.1
local ROCK_FALL_SECONDS = 0.4
-- Margen en altura sobre el radio para contar a alguien dentro del círculo de un impacto.
local VERTICAL_REACH = 8

local Hazards = {}

-- Lo que cae del cielo o sale del suelo: imbloqueable (viene de todos lados).
local function unblockable(): Guard.Hit
	return { guardDamage = 0, unblockable = true, enemy = true }
end

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

-- Jugadores dentro del círculo de "radius" alrededor de "position" (el punto del suelo). Se mide en
-- horizontal, como se ve el círculo: el cuerpo está unos studs por encima del suelo y, midiendo en 3D,
-- quien pisaba el borde quedaba fuera. En vertical vale un margen por si salta o está en una cuesta.
-- Cuenta también a quien está en el Basecamp (ver la cabecera).
local function playersNear(position: Vector3, radius: number): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local offset = root.Position - position
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if flat <= radius and math.abs(offset.Y) <= radius + VERTICAL_REACH then
				table.insert(list, player)
			end
		end
	end
	return list
end

-- Daña a quien esté dentro del círculo.
local function hurtNear(position: Vector3, radius: number, damage: number, cause: string?)
	if damage <= 0 then
		return
	end
	for _, player in playersNear(position, radius) do
		CombatService.damagePlayer(player, damage, true, nil, cause, nil, unblockable())
	end
end

-- Una roca cae en "position" tras "warnSeconds" de aviso. El marcador, la roca y el polvo los dibuja cada
-- cliente (BossFx "rock", con la hora del servidor); aquí solo el sonido y el daño, que llega a la vez que
-- la roca toca el suelo. "style" es el jefe que la lanza (su firma visual).
function Hazards.fallingRock(
	position: Vector3,
	damage: number,
	radius: number,
	warnSeconds: number,
	cause: string?,
	style: string?
)
	local ground = groundAt(position)
	Remotes.BossFx:FireAllClients("rock", style or "ChimpanceCaudillo", ground, {
		warn = warnSeconds,
		flight = ROCK_FALL_SECONDS,
		radius = radius,
		serverTime = Workspace:GetServerTimeNow(),
		seed = rng:NextInteger(1, 1000000),
	})
	task.delay(warnSeconds + ROCK_FALL_SECONDS, function()
		Sfx.play("RockImpact", ground)
		hurtNear(ground, radius, damage, cause)
	end)
end

-- Rayo de la tormenta: tras el aviso cae un rayo en zigzag con ramas, un destello y chispas, y deja
-- el suelo chamuscado.
function Hazards.lightning(position: Vector3, damage: number, radius: number, warnSeconds: number, cause: string?)
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
		hurtNear(ground, radius, damage, cause)

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

-- Bomba de lava: sale de "origin" (el cráter o el jefe) en arco y revienta en "position" al acabar el aviso,
-- dejando un charco de lava unos segundos. El dibujo (marcador, bola, charco y brasas) es de cada cliente
-- (BossFx "lavaBomb"); aquí el sonido y el daño, que cae a la vez que la bomba.
function Hazards.lavaBomb(
	position: Vector3,
	damage: number,
	radius: number,
	warnSeconds: number,
	origin: Vector3?,
	cause: string?
)
	local ground = groundAt(position)
	local start = origin or (ground + Vector3.new(rng:NextNumber(-30, 30), 80, rng:NextNumber(-30, 30)))
	local flight = math.min(LAVA_FLIGHT_SECONDS, warnSeconds)
	Remotes.BossFx:FireAllClients("lavaBomb", "GorilaDeCeniza", ground, {
		warn = warnSeconds,
		flight = flight,
		radius = radius,
		origin = start,
		serverTime = Workspace:GetServerTimeNow(),
		seed = rng:NextInteger(1, 1000000),
	})
	task.delay(warnSeconds - flight, function()
		Sfx.play("LavaLaunch", start)
	end)
	task.delay(warnSeconds, function()
		Sfx.play("LavaImpact", ground)
		hurtNear(ground, radius, damage, cause)
	end)
end

-- Área con aviso para un golpe que decide otro (los del administrador gigante, T4e): marca el suelo
-- "warnSeconds" y al acabar llama a "land" con los jugadores que siguen dentro y el punto del suelo.
function Hazards.warnArea(
	position: Vector3,
	radius: number,
	color: Color3,
	warnSeconds: number,
	land: (players: { Player }, ground: Vector3) -> ()
)
	local ground = groundAt(position)
	marker(ground, radius, color, warnSeconds)
	task.delay(warnSeconds, function()
		land(playersNear(ground, radius), ground)
	end)
end

-- Onda de choque alrededor de "position": daña y aturde a quien siga dentro tras el aviso. No dibuja nada:
-- el marcador y la onda los pone cada cliente (BossFx "stomp", que lanza quien llama a esta función).
function Hazards.shockwave(
	position: Vector3,
	radius: number,
	damage: number,
	stunSeconds: number,
	warnSeconds: number,
	cause: string?
)
	local ground = groundAt(position)
	task.delay(warnSeconds, function()
		for _, player in playersNear(ground, radius) do
			if CombatService.damagePlayer(player, damage, true, nil, cause, nil, unblockable()) then
				Status.stunPlayer(player, stunSeconds, cause or "Peligro")
			end
		end
	end)
end

return Hazards
